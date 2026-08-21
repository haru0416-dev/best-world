#ifndef BESTWORLD_LIGHTMAP_INCLUDED
#define BESTWORLD_LIGHTMAP_INCLUDED

#include "BestWorldBRDF.hlsl"

#ifdef LIGHTMAP_ON

float4 BestWorldCubicWeights(float v)
{
    float4 n = float4(1.0, 2.0, 3.0, 4.0) - v;
    float4 s = n * n * n;
    float x = s.x;
    float y = s.y - 4.0 * s.x;
    float z = s.z - 4.0 * s.y + 6.0 * s.x;
    float w = 6.0 - x - y - z;
    return float4(x, y, z, w) * (1.0 / 6.0);
}

float3 BestWorldSampleLightmapBilinear(float2 uv)
{
    return DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, uv));
}

void BestWorldBicubicSetup(float2 uv, float2 size, out float2 h0, out float2 h1, out float2 g0, out float2 g1)
{
    float2 texel = 1.0 / max(size, 1.0);
    float2 coord = uv * size - 0.5;
    float2 f = frac(coord);
    coord -= f;
    float4 wx = BestWorldCubicWeights(f.x);
    float4 wy = BestWorldCubicWeights(f.y);
    g0 = float2(wx.x + wx.y, wy.x + wy.y);
    g1 = float2(wx.z + wx.w, wy.z + wy.w);
    h0 = float2(coord.x - 0.5 + wx.y / max(g0.x, BESTWORLD_EPS), coord.y - 0.5 + wy.y / max(g0.y, BESTWORLD_EPS)) * texel;
    h1 = float2(coord.x + 1.5 + wx.w / max(g1.x, BESTWORLD_EPS), coord.y + 1.5 + wy.w / max(g1.y, BESTWORLD_EPS)) * texel;
}

float3 BestWorldSampleLightmapBicubic(float2 uv)
{
    #if defined(BESTWORLD_QUALITY_QUEST)
        return BestWorldSampleLightmapBilinear(uv);
    #else
        float2 size;
        unity_Lightmap.GetDimensions(size.x, size.y);
        float2 h0, h1, g0, g1;
        BestWorldBicubicSetup(uv, size, h0, h1, g0, g1);
        float3 s00 = BestWorldSampleLightmapBilinear(h0);
        float3 s10 = BestWorldSampleLightmapBilinear(float2(h1.x, h0.y));
        float3 s01 = BestWorldSampleLightmapBilinear(float2(h0.x, h1.y));
        float3 s11 = BestWorldSampleLightmapBilinear(h1);
        return (s00 * g0.y + s01 * g1.y) * g0.x + (s10 * g0.y + s11 * g1.y) * g1.x;
    #endif
}

float3 BestWorldSampleLightmap(float2 uv)
{
    #if defined(BESTWORLD_QUALITY_QUEST)
        return BestWorldSampleLightmapBilinear(uv);
    #else
        UNITY_BRANCH
        if (_BicubicLightmap > 0.5)
        {
            return BestWorldSampleLightmapBicubic(uv);
        }
        return BestWorldSampleLightmapBilinear(uv);
    #endif
}

float4 BestWorldSampleLightmapDirBilinear(float2 uv)
{
    return UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, uv);
}

float4 BestWorldSampleLightmapDir(float2 uv)
{
    #if defined(BESTWORLD_QUALITY_QUEST)
        return BestWorldSampleLightmapDirBilinear(uv);
    #else
        UNITY_BRANCH
        if (_BicubicLightmap > 0.5)
        {
            float2 size;
            unity_Lightmap.GetDimensions(size.x, size.y);
            float2 h0, h1, g0, g1;
            BestWorldBicubicSetup(uv, size, h0, h1, g0, g1);
            float4 s00 = BestWorldSampleLightmapDirBilinear(h0);
            float4 s10 = BestWorldSampleLightmapDirBilinear(float2(h1.x, h0.y));
            float4 s01 = BestWorldSampleLightmapDirBilinear(float2(h0.x, h1.y));
            float4 s11 = BestWorldSampleLightmapDirBilinear(h1);
            return (s00 * g0.y + s01 * g1.y) * g0.x + (s10 * g0.y + s11 * g1.y) * g1.x;
        }
        return BestWorldSampleLightmapDirBilinear(uv);
    #endif
}

float3 BestWorldDirectionalLightmap(float3 color, float4 dirTex, float3 normal)
{
    return DecodeDirectionalLightmap(color, dirTex, normal);
}

// Geomerics L1 reconstruction. L1 is the colored L1 coefficient vector for one channel set.
float BestWorldSHEvalL1Geomerics(float L0, float3 L1, float3 n)
{
    float R0 = max(L0, BESTWORLD_EPS);
    float3 R1 = 0.5 * L1;
    float lenR1 = length(R1);
    float q = saturate(dot(BestWorldSafeNormalize(R1), n) * 0.5 + 0.5);
    float ratio = saturate(lenR1 / R0);
    float p = 1.0 + 2.0 * ratio;
    float a = (1.0 - ratio) / max(1.0 + ratio, BESTWORLD_EPS);
    return R0 * (a + (1.0 - a) * (p + 1.0) * pow(q, p));
}

// Bakery MonoSH: nL1 in directional map, L1 = 2 * nL1 * L0.
float3 BestWorldMonoSH(float3 L0, float4 dirTex, float3 normal, out float3 nL1)
{
    nL1 = dirTex.xyz * 2.0 - 1.0;
    float ndotl = dot(nL1, normal);
    float3 linearSH = L0 * (1.0 + 2.0 * ndotl);
    float lumaL0 = BestWorldLuma(L0);
    float3 L1luma = nL1 * lumaL0 * 2.0;
    float lumaSH = BestWorldSHEvalL1Geomerics(lumaL0, L1luma, normal);
    float regular = BestWorldLuma(linearSH);
    linearSH *= lerp(1.0, lumaSH / max(regular, BESTWORLD_EPS), saturate(regular * 16.0));
    return max(linearSH, 0.0);
}

void BestWorldLightmappedSpecular(
    BestWorldSurface s,
    float3 L0,
    float3 lightDir,
    float directionality,
    inout float3 specular)
{
    float3 L = BestWorldSafeNormalize(lightDir);
    float perceptual = lerp(s.perceptualRoughness, 1.0, 1.0 - saturate(directionality));
    float a = BestWorldPerceptualToLinearRoughness(perceptual);
    BestWorldBRDF b = BestWorldGetBRDF(s.normal, s.view, L);
    float3 F = BestWorldFresnel(s, b.VoH);
    float D = BestWorldD_GGX(b.NoH, a, s.normal, b.H);
    float Vterm = BestWorldV_SmithGGXFast(b.NoV, b.NoL, a);
    float2 dfg = BestWorldEnvBRDF(b.NoV, perceptual);
    float3 energy = BestWorldEnergyCompensation(s.f0, dfg);
    specular += D * Vterm * F * energy * L0 * b.NoL * saturate(directionality);
}

#endif

float3 BestWorldSubtractiveShadow(float3 bakedGI, float shadow, float NoL)
{
    float3 shadowColor = unity_ShadowColor.rgb;
    float attenuation = lerp(1.0, shadow, saturate(NoL));
    return lerp(bakedGI * shadowColor, bakedGI, attenuation);
}

#endif
