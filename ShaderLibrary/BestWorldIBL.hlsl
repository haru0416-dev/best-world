#ifndef BESTWORLD_IBL_INCLUDED
#define BESTWORLD_IBL_INCLUDED

#include "BestWorldBRDF.hlsl"

// HDRP GeometricTools IntersectRayAABBSimple: far-plane hit, valid when the
// shaded point is inside the probe AABB (same assumption as Unity box projection).
float BestWorldIntersectRayAABB(float3 origin, float3 dir, float3 boxMin, float3 boxMax)
{
    float3 invDir = 1.0 / dir;
    float3 tMin = (boxMin - origin) * invDir;
    float3 tMax = (boxMax - origin) * invDir;
    float3 tFar = float3(
        dir.x > 0.0 ? tMax.x : tMin.x,
        dir.y > 0.0 ? tMax.y : tMin.y,
        dir.z > 0.0 ? tMax.z : tMin.z);
    return min(min(tFar.x, tFar.y), tFar.z);
}

// Lagarde, Moving Frostbite to PBR 3.0 §4.10.2 / HDRP ComputeDistanceBaseRoughness.
// Fakes the footprint of a GGX lobe on the probe proxy by shrinking perceptual
// roughness when the reflection hits the AABB close to the shaded point.
// Smooth mirrors (p=0) stay mirrors. Applied to mip only — Fdez DFG keeps
// shading roughness so energy does not change with room size.
float BestWorldDistanceBaseRoughness(float distHit, float distCenter, float perceptualRoughness)
{
    float p = saturate(perceptualRoughness);
    float adjusted = clamp(distHit / max(distCenter, BESTWORLD_EPS) * p, 0.0, p);
    return lerp(adjusted, p, p);
}

float BestWorldGlossyMip(float perceptualRoughness)
{
    float p = saturate(perceptualRoughness);
    p = p * (1.7 - 0.7 * p);
    return p * UNITY_SPECCUBE_LOD_STEPS;
}

void BestWorldBoxProjectAndRoughness(
    float3 R,
    float perceptualRoughness,
    float3 worldPos,
    float4 probePos,
    float4 boxMin,
    float4 boxMax,
    out float3 Rproj,
    out float mipRoughness)
{
    mipRoughness = saturate(perceptualRoughness);
    Rproj = R;
    UNITY_BRANCH
    if (probePos.w > 0.0)
    {
        #if defined(BESTWORLD_QUALITY_QUEST)
            Rproj = BoxProjectedCubemapDirection(R, worldPos, probePos, boxMin, boxMax);
        #else
            float t = BestWorldIntersectRayAABB(worldPos, R, boxMin.xyz, boxMax.xyz);
            Rproj = (worldPos + t * R) - probePos.xyz;
            mipRoughness = BestWorldDistanceBaseRoughness(t, length(Rproj), mipRoughness);
            Rproj = BestWorldSafeNormalize(Rproj);
        #endif
    }
}

float3 BestWorldGlossyIBL(float3 R, float perceptualRoughness, float3 worldPos)
{
    float3 R0;
    float p0;
    BestWorldBoxProjectAndRoughness(
        R, perceptualRoughness, worldPos,
        unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax,
        R0, p0);
    half4 env0 = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, R0, BestWorldGlossyMip(p0));
    float3 spec = DecodeHDR(env0, unity_SpecCube0_HDR);

    #if defined(UNITY_SPECCUBE_BLENDING) && !defined(BESTWORLD_QUALITY_QUEST)
        float blend = unity_SpecCube0_BoxMin.w;
        UNITY_BRANCH
        if (blend < 0.999)
        {
            float3 R1;
            float p1;
            BestWorldBoxProjectAndRoughness(
                R, perceptualRoughness, worldPos,
                unity_SpecCube1_ProbePosition, unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax,
                R1, p1);
            half4 env1 = UNITY_SAMPLE_TEXCUBE_SAMPLER_LOD(
                unity_SpecCube1, unity_SpecCube0, R1, BestWorldGlossyMip(p1));
            spec = lerp(DecodeHDR(env1, unity_SpecCube1_HDR), spec, blend);
        }
    #endif

    return spec;
}

float3 BestWorldIrradianceSH(float3 N)
{
    return max(ShadeSH9(float4(N, 1.0)), 0.0);
}

void BestWorldExtractUnitySH(out float3 L0, out float3 L1r, out float3 L1g, out float3 L1b)
{
    L0 = float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
    L1r = unity_SHAr.xyz;
    L1g = unity_SHAg.xyz;
    L1b = unity_SHAb.xyz;
}

// Roughton / Sloan / Silvennoinen / Iwanicki / Shirley, ZH3, i3D 2024, §3.4.3.
// Unity and VRC Light Volumes store cosine-convolved (irradiance) L0/L1.
// The curve-fit is defined on radiance, so we deconvolve, hallucinate Y2,0
// along each channel's L1 axis, then add the cosine-convolved L2 zonal term
// (zonal scale 1/4). Per-channel axes keep RGB point lights from collapsing.
float BestWorldZH3Hallucinate(float L0, float3 L1, float3 N)
{
    const float l0ToRad = 2.0 * sqrt(BESTWORLD_PI);
    const float l1ToRad = sqrt(3.0 * BESTWORLD_PI);
    float L0r = L0 * l0ToRad;
    float3 L1r = L1 * l1ToRad;
    float l1Len = length(L1r);
    float3 axis = l1Len > BESTWORLD_EPS ? L1r / l1Len : float3(0.0, 0.0, 1.0);
    float ratio = L0r > BESTWORLD_EPS ? l1Len / L0r : 0.0;
    float zonalL2 = L0r * (0.08 * ratio + 0.6 * ratio * ratio);
    float fZ = dot(axis, N);
    float zh = sqrt(5.0 / (16.0 * BESTWORLD_PI)) * (3.0 * fZ * fZ - 1.0);
    return L0 + dot(L1, N) + 0.25 * zonalL2 * zh;
}

float3 BestWorldEvalL1(float3 N, float3 L0, float3 L1r, float3 L1g, float3 L1b)
{
    #if defined(BESTWORLD_QUALITY_QUEST)
        return max(L0 + float3(dot(L1r, N), dot(L1g, N), dot(L1b, N)), 0.0);
    #else
        return max(float3(
            BestWorldZH3Hallucinate(L0.r, L1r, N),
            BestWorldZH3Hallucinate(L0.g, L1g, N),
            BestWorldZH3Hallucinate(L0.b, L1b, N)), 0.0);
    #endif
}

float BestWorldLightVolumesActive()
{
    #if defined(BESTWORLD_HAS_VRC_LIGHT_VOLUMES)
        return _UdonLightVolumeEnabled;
    #else
        return 0.0;
    #endif
}

#endif
