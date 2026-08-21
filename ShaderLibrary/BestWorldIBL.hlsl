#ifndef BESTWORLD_IBL_INCLUDED
#define BESTWORLD_IBL_INCLUDED

#include "BestWorldBRDF.hlsl"

float3 BestWorldBoxProject(float3 R, float3 worldPos, float4 probePos, float4 boxMin, float4 boxMax)
{
    UNITY_BRANCH
    if (probePos.w > 0.0)
    {
        return BoxProjectedCubemapDirection(R, worldPos, probePos, boxMin, boxMax);
    }
    return R;
}

float3 BestWorldGlossyIBL(float3 R, float perceptualRoughness, float3 worldPos)
{
    // Unity_GlossyEnvironment mip remap (Lazarov/Karis cone, MM approximation).
    float p = saturate(perceptualRoughness);
    p = p * (1.7 - 0.7 * p);
    float mip = p * UNITY_SPECCUBE_LOD_STEPS;
    float3 R0 = BestWorldBoxProject(R, worldPos, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
    half4 env0 = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, R0, mip);
    float3 spec = DecodeHDR(env0, unity_SpecCube0_HDR);

    #if defined(UNITY_SPECCUBE_BLENDING) && !defined(BESTWORLD_QUALITY_QUEST)
        float blend = unity_SpecCube0_BoxMin.w;
        UNITY_BRANCH
        if (blend < 0.999)
        {
            float3 R1 = BestWorldBoxProject(R, worldPos, unity_SpecCube1_ProbePosition, unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax);
            half4 env1 = UNITY_SAMPLE_TEXCUBE_SAMPLER_LOD(unity_SpecCube1, unity_SpecCube0, R1, mip);
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

float3 BestWorldEvalL1(float3 N, float3 L0, float3 L1r, float3 L1g, float3 L1b)
{
    return max(L0 + float3(dot(L1r, N), dot(L1g, N), dot(L1b, N)), 0.0);
}

#endif
