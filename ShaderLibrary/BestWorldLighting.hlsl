#ifndef BESTWORLD_LIGHTING_INCLUDED
#define BESTWORLD_LIGHTING_INCLUDED

#include "BestWorldConfig.hlsl"
#include "BestWorldInputs.hlsl"
#include "BestWorldLightmap.hlsl"
#include "BestWorldIBL.hlsl"

void BestWorldVolumeSH(
    float3 worldPos,
    float3 worldNormal,
    out float3 L0,
    out float3 L1r,
    out float3 L1g,
    out float3 L1b)
{
    #if defined(BESTWORLD_HAS_VRC_LIGHT_VOLUMES)
        #if defined(BESTWORLD_LIGHTVOLUMES_V3)
            LightVolumeSH(worldPos, L0, L1r, L1g, L1b, float3(0.0, 0.0, 0.0), worldNormal);
        #else
            LightVolumeSH(worldPos, L0, L1r, L1g, L1b);
        #endif
    #else
        BestWorldExtractUnitySH(L0, L1r, L1g, L1b);
    #endif
}

void BestWorldAdditiveVolumeSH(
    float3 worldPos,
    float3 worldNormal,
    out float3 L0,
    out float3 L1r,
    out float3 L1g,
    out float3 L1b)
{
    #if defined(BESTWORLD_HAS_VRC_LIGHT_VOLUMES)
        #if defined(BESTWORLD_LIGHTVOLUMES_V3)
            LightVolumeAdditiveSH(worldPos, L0, L1r, L1g, L1b, float3(0.0, 0.0, 0.0), worldNormal);
        #else
            LightVolumeAdditiveSH(worldPos, L0, L1r, L1g, L1b);
        #endif
    #else
        L0 = 0.0;
        L1r = 0.0;
        L1g = 0.0;
        L1b = 0.0;
    #endif
}

void BestWorldLTCGI(BestWorldSurface s, float2 lightmapUV, inout float3 diffuse, inout float3 specular)
{
    #if defined(BESTWORLD_HAS_LTCGI) && defined(_LTCGI) && !defined(BESTWORLD_QUALITY_QUEST)
        half3 ltcDiff = 0;
        half3 ltcSpec = 0;
        LTCGI_Contribution(s.worldPos, s.normal, s.view, s.perceptualRoughness, lightmapUV, ltcDiff, ltcSpec);
        diffuse += (float3)ltcDiff * s.diffuseColor;
        specular += (float3)ltcSpec;
    #endif
}

BestWorldLight BestWorldMainLight(BestWorldV2F i, float3 worldPos)
{
    BestWorldLight light;
    float3 lightDir = _WorldSpaceLightPos0.xyz;
    UNITY_BRANCH
    if (_WorldSpaceLightPos0.w > 0.0)
    {
        lightDir = BestWorldSafeNormalize(_WorldSpaceLightPos0.xyz - worldPos);
    }
    light.direction = lightDir;
    #if defined(BESTWORLD_FORWARD_ADD)
        UNITY_LIGHT_ATTENUATION(atten, i, worldPos);
        light.attenuation = atten;
    #elif defined(SHADOWS_SHADOWMASK) && defined(LIGHTMAP_ON) && !defined(BESTWORLD_QUALITY_QUEST)
        float realtime = UNITY_SHADOW_ATTENUATION(i, worldPos);
        float baked = BestWorldSampleShadowMask(i.lightmapUV, worldPos);
        float fadeDist = UnityComputeShadowFadeDistance(
            worldPos, dot(worldPos - _WorldSpaceCameraPos, UNITY_MATRIX_V[2].xyz));
        light.attenuation = UnityMixRealtimeAndBakedShadows(
            realtime, baked, UnityComputeShadowFade(fadeDist));
    #else
        UNITY_LIGHT_ATTENUATION(atten, i, worldPos);
        light.attenuation = atten;
    #endif
    light.color = _LightColor0.rgb;
    return light;
}

float3 BestWorldCollectIrradiance(
    BestWorldSurface s,
    float2 lightmapUV,
    out float3 L0,
    out float3 L1r,
    out float3 L1g,
    out float3 L1b,
    out float4 dirTex,
    out float3 lightmapColor,
    out float3 lmLightDir,
    out float lmFocus)
{
    L0 = 0.0;
    L1r = 0.0;
    L1g = 0.0;
    L1b = 0.0;
    dirTex = 0.0;
    lightmapColor = 0.0;
    lmLightDir = 0.0;
    lmFocus = 0.0;

    #ifdef LIGHTMAP_ON
        float3 lm = BestWorldSampleLightmap(lightmapUV);
        lightmapColor = lm;
        float3 irradiance = lm;
        #ifdef DIRLIGHTMAP_COMBINED
            dirTex = BestWorldSampleLightmapDir(lightmapUV);
            UNITY_BRANCH
            if (_BakeryMonoSH > 0.5)
            {
                float3 nL1;
                irradiance = BestWorldMonoSH(lm, dirTex, s.normal, nL1);
                lmLightDir = nL1;
                lmFocus = saturate(length(nL1));
            }
            else
            {
                irradiance = BestWorldDirectionalLightmap(lm, dirTex, s.normal);
                lmLightDir = dirTex.xyz * 2.0 - 1.0;
                lmFocus = saturate(length(lmLightDir));
            }
        #endif
        UNITY_BRANCH
        if (BestWorldLightVolumesActive() > 0.0)
        {
            BestWorldAdditiveVolumeSH(s.worldPos, s.normal, L0, L1r, L1g, L1b);
            irradiance += BestWorldEvalL1(s.normal, L0, L1r, L1g, L1b);
        }
        return irradiance;
    #else
        UNITY_BRANCH
        if (BestWorldLightVolumesActive() > 0.0)
        {
            BestWorldVolumeSH(s.worldPos, s.normal, L0, L1r, L1g, L1b);
            return BestWorldEvalL1(s.normal, L0, L1r, L1g, L1b);
        }
        BestWorldExtractUnitySH(L0, L1r, L1g, L1b);
        return BestWorldIrradianceSH(s.normal);
    #endif
}

void BestWorldIndirectLighting(
    BestWorldSurface s,
    float3 irradiance,
    float3 L0,
    float3 L1r,
    float3 L1g,
    float3 L1b,
    float3 lightmapColor,
    float3 lmLightDir,
    float lmFocus,
    float3 aoDiffuse,
    inout float3 diffuse,
    inout float3 specular)
{
    float NoV = abs(dot(s.normal, s.view)) + BESTWORLD_EPS;
    float bakedVis = saturate(BestWorldLuma(irradiance));
    float vis = min(s.occlusion, bakedVis);
    float specAO = BestWorldSpecularAO(NoV, vis, s.roughness);

    float3 R = reflect(-s.view, s.normal);
    specAO *= BestWorldHorizonOcclusion(R, s.geometricNormal);

    float2 dfg = BestWorldEnvBRDF(NoV, s.perceptualRoughness);
    float3 FssEss, FmsEms, kD;
    BestWorldFdezIbl(
        s.f0, s.diffuseColor, s.specularWeight, s.perceptualRoughness, NoV, dfg,
        s.f82Tint, s.metallic,
        FssEss, FmsEms, kD);
    float3 ibl = BestWorldGlossyIBL(R, s.perceptualRoughness, s.worldPos);

    #if defined(_CLEARCOAT) && !defined(BESTWORLD_QUALITY_QUEST)
        UNITY_BRANCH
        if (s.coatWeight > 0.001)
        {
            float fcc = BestWorldF_Schlick(s.coatF0, 1.0, NoV) * s.coatWeight;
            float3 coatIBL = BestWorldGlossyIBL(R, s.coatPerceptualRoughness, s.worldPos);
            float3 baseAlbedo = saturate(s.diffuseColor + s.f0 * s.metallic);
            float3 dark = BestWorldCoatDarkening(s.coatF0, s.coatWeight, s.coatDarkening, baseAlbedo);
            ibl *= dark * (1.0 - fcc);
            FssEss *= dark * (1.0 - fcc);
            FmsEms *= dark * (1.0 - fcc);
            kD *= dark * (1.0 - fcc);
            specular += coatIBL * fcc * specAO;
        }
    #endif

    specular += FssEss * ibl * specAO;
    diffuse += (FmsEms + kD) * irradiance * aoDiffuse;
    specular += BestWorldSHSpecular(s, L0, L1r, L1g, L1b) * specAO;

    #if defined(LIGHTMAP_ON) && defined(DIRLIGHTMAP_COMBINED)
        float3 lmSpec = 0.0;
        BestWorldLightmappedSpecular(s, lightmapColor, lmLightDir, lmFocus, lmSpec);
        specular += lmSpec * specAO;
    #endif
}

float4 BestWorldShadeForwardBase(BestWorldV2F i, BestWorldSurface s)
{
    float3 L0, L1r, L1g, L1b;
    float4 dirTex;
    float3 lightmapColor;
    float3 lmLightDir;
    float lmFocus;
    float3 irradiance = BestWorldCollectIrradiance(
        s, i.lightmapUV, L0, L1r, L1g, L1b, dirTex, lightmapColor, lmLightDir, lmFocus);
    float3 aoDiffuse = BestWorldMultiBounceAO(s.occlusion, s.diffuseColor);

    BestWorldLight mainLight = BestWorldMainLight(i, s.worldPos);
    float NoL = saturate(dot(s.normal, mainLight.direction));

    float3 diffuse = 0.0;
    float3 specular = 0.0;

    #if defined(LIGHTMAP_ON) && defined(LIGHTMAP_SHADOW_MIXING) && !defined(SHADOWS_SHADOWMASK)
        irradiance = BestWorldSubtractiveShadow(irradiance, mainLight.attenuation, NoL);
    #else
        BestWorldDirectLighting(s, mainLight, diffuse, specular);
    #endif

    BestWorldIndirectLighting(
        s, irradiance, L0, L1r, L1g, L1b, lightmapColor, lmLightDir, lmFocus, aoDiffuse,
        diffuse, specular);
#ifdef VERTEXLIGHT_ON
    diffuse += s.diffuseColor * i.vertexLight * s.occlusion;
#endif
    BestWorldLTCGI(s, i.lightmapUV, diffuse, specular);

    float3 color = diffuse + specular + s.emission;

    #if defined(UNITY_EDITOR)
        UNITY_BRANCH
        if (_DebugView > 0.5)
        {
            if (_DebugView < 1.5) return float4(s.albedo, 1.0);
            if (_DebugView < 2.5) return float4(s.normal * 0.5 + 0.5, 1.0);
            if (_DebugView < 3.5) return float4(s.perceptualRoughness.xxx, 1.0);
            if (_DebugView < 4.5) return float4(s.metallic.xxx, 1.0);
            if (_DebugView < 5.5) return float4(s.occlusion.xxx, 1.0);
            if (_DebugView < 6.5) return float4(s.f0, 1.0);
            if (_DebugView < 7.5) return float4(diffuse, 1.0);
            if (_DebugView < 8.5) return float4(specular, 1.0);
        }
    #endif

    return float4(color, s.alpha);
}

float4 BestWorldShadeForwardAdd(BestWorldV2F i, BestWorldSurface s)
{
    float3 diffuse = 0.0;
    float3 specular = 0.0;
    BestWorldLight light = BestWorldMainLight(i, s.worldPos);
    BestWorldDirectLighting(s, light, diffuse, specular);
    return float4(diffuse + specular, 0.0);
}

#endif
