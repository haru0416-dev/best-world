#ifndef BESTWORLD_INPUTS_INCLUDED
#define BESTWORLD_INPUTS_INCLUDED

#include "BestWorldBRDF.hlsl"

UNITY_DECLARE_TEX2D(_MainTex);
UNITY_DECLARE_TEX2D_NOSAMPLER(_PackedMap);
UNITY_DECLARE_TEX2D_NOSAMPLER(_BumpMap);
UNITY_DECLARE_TEX2D_NOSAMPLER(_EmissionMap);
UNITY_DECLARE_TEX2D_NOSAMPLER(_OcclusionMap);
UNITY_DECLARE_TEX2D_NOSAMPLER(_ParallaxMap);
UNITY_DECLARE_TEX2D_NOSAMPLER(_DetailAlbedoMap);
UNITY_DECLARE_TEX2D_NOSAMPLER(_DetailNormalMap);
UNITY_DECLARE_TEX2D_NOSAMPLER(_CoatMaskMap);

float4 _MainTex_ST;
float4 _DetailAlbedoMap_ST;
float4 _Color;
float _Cutoff;
float _Metallic;
float _Glossiness;
float _Roughness;
float _OcclusionStrength;
float _BumpScale;
float _Reflectance;
float _SpecularWeight;
float _MapFormat;
float _UseVertexColor;
float _Parallax;
float4 _EmissionColor;
float _EmissionGIMultiplier;
float4 _F82Tint;
float _CoatWeight;
float _CoatRoughness;
float _BicubicLightmap;
float _BakeryMonoSH;
float _DetailAlbedoScale;
float _DetailNormalScale;
float _Cull;
float _DebugView;

struct BestWorldV2F
{
    float4 pos : SV_POSITION;
    float4 uv : TEXCOORD0;
    float4 tangentToWorld[3] : TEXCOORD1;
    centroid float2 lightmapUV : TEXCOORD4;
    UNITY_LIGHTING_COORDS(5, 6)
    UNITY_FOG_COORDS(7)
#ifdef VERTEXLIGHT_ON
    float3 vertexLight : TEXCOORD8;
#endif
    float4 color : COLOR;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

struct BestWorldAppData
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv0 : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
    float4 color : COLOR;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

float2 BestWorldTransformUV(float2 uv, float4 st)
{
    return uv * st.xy + st.zw;
}

float2 BestWorldParallaxOffset(float2 uv, float3 viewTS, float scale)
{
    #if defined(BESTWORLD_QUALITY_QUEST)
        return uv;
    #else
        float height = UNITY_SAMPLE_TEX2D_SAMPLER(_ParallaxMap, _MainTex, uv).r;
        height = (height - 0.5) * scale;
        float3 v = BestWorldSafeNormalize(viewTS);
        return uv + v.xy * height;
    #endif
}

float3 BestWorldDetailAlbedo(float3 albedo, float2 uv)
{
    float3 detail = UNITY_SAMPLE_TEX2D_SAMPLER(_DetailAlbedoMap, _MainTex, uv).rgb;
    float3 overlay = albedo * detail * 2.0;
    return lerp(albedo, overlay, _DetailAlbedoScale);
}

float3 BestWorldWhiteoutNormal(float3 n1, float3 n2)
{
    return BestWorldSafeNormalize(float3(n1.xy + n2.xy, n1.z * n2.z));
}

void BestWorldBuildSurface(
    BestWorldV2F i,
    float3 geometricNormal,
    float3 tangent,
    float3 bitangent,
    float3 view,
    inout BestWorldSurface s)
{
    float2 uv = i.uv.xy;

    #if !defined(BESTWORLD_QUALITY_QUEST) && defined(_PARALLAXMAP)
        float3 viewTS = float3(dot(view, tangent), dot(view, bitangent), dot(view, geometricNormal));
        uv = BestWorldParallaxOffset(uv, viewTS, _Parallax);
    #endif

    float4 albedoSample = UNITY_SAMPLE_TEX2D(_MainTex, uv) * _Color;
    if (_UseVertexColor > 0.5)
    {
        albedoSample *= i.color;
    }

    float4 packed = UNITY_SAMPLE_TEX2D_SAMPLER(_PackedMap, _MainTex, uv);
    float metallic;
    float perceptualRoughness;
    float occlusion;

    UNITY_BRANCH
    if (_MapFormat < 0.5)
    {
        occlusion = packed.r;
        perceptualRoughness = packed.g * _Roughness;
        metallic = packed.b * _Metallic;
    }
    else
    {
        metallic = packed.r * _Metallic;
        perceptualRoughness = (1.0 - packed.a * _Glossiness);
        occlusion = UNITY_SAMPLE_TEX2D_SAMPLER(_OcclusionMap, _MainTex, uv).g;
    }

    occlusion = lerp(1.0, occlusion, _OcclusionStrength);

    float3 albedo = albedoSample.rgb;
    float alpha = albedoSample.a;

    #if defined(_DETAIL_MAP) && !defined(BESTWORLD_QUALITY_QUEST)
        float2 detailUV = BestWorldTransformUV(i.uv.xy, _DetailAlbedoMap_ST);
        albedo = BestWorldDetailAlbedo(albedo, detailUV);
    #endif

    #if defined(BESTWORLD_ALPHA_CLIP)
        clip(alpha - _Cutoff);
    #endif

    float3 mapNormal = UnpackScaleNormal(UNITY_SAMPLE_TEX2D_SAMPLER(_BumpMap, _MainTex, uv), _BumpScale);
    #if defined(_DETAIL_MAP) && !defined(BESTWORLD_QUALITY_QUEST)
        float3 detailN = UnpackScaleNormal(
            UNITY_SAMPLE_TEX2D_SAMPLER(_DetailNormalMap, _MainTex, BestWorldTransformUV(i.uv.xy, _DetailAlbedoMap_ST)),
            _DetailNormalScale);
        mapNormal = BestWorldWhiteoutNormal(mapNormal, detailN);
    #endif

    float3 N = BestWorldSafeNormalize(
        tangent * mapNormal.x + bitangent * mapNormal.y + geometricNormal * mapNormal.z);

    #if !defined(BESTWORLD_QUALITY_QUEST)
        float perceptualAA = BestWorldSpecularAA(saturate(perceptualRoughness), N);
    #else
        float perceptualAA = saturate(perceptualRoughness);
    #endif

    float reflectance = saturate(_Reflectance);
    float3 dielectricF0 = (0.16 * reflectance * reflectance).xxx;
    float3 f0 = lerp(dielectricF0, albedo, saturate(metallic));

    s.albedo = albedo;
    s.metallic = saturate(metallic);
    s.diffuseColor = albedo * (1.0 - s.metallic);
    s.f0 = f0;
    s.f82Tint = saturate(_F82Tint.rgb);
    s.perceptualRoughness = perceptualAA;
    s.roughness = BestWorldPerceptualToLinearRoughness(perceptualAA);
    s.occlusion = saturate(occlusion);
    s.reflectance = reflectance;
    s.specularWeight = saturate(_SpecularWeight);
    s.emission = UNITY_SAMPLE_TEX2D_SAMPLER(_EmissionMap, _MainTex, uv).rgb * _EmissionColor.rgb;
    s.normal = N;
    s.geometricNormal = geometricNormal;
    s.tangent = tangent;
    s.bitangent = bitangent;
    s.view = view;
    s.worldPos = float3(i.tangentToWorld[0].w, i.tangentToWorld[1].w, i.tangentToWorld[2].w);
    s.alpha = alpha;
    s.coatWeight = 0.0;
    s.coatPerceptualRoughness = 0.1;
    s.coatRoughness = BestWorldPerceptualToLinearRoughness(0.1);

    #if defined(_CLEARCOAT) && !defined(BESTWORLD_QUALITY_QUEST)
        float coatMask = UNITY_SAMPLE_TEX2D_SAMPLER(_CoatMaskMap, _MainTex, uv).r;
        s.coatWeight = saturate(_CoatWeight * coatMask);
        s.coatPerceptualRoughness = saturate(_CoatRoughness);
        s.coatRoughness = BestWorldPerceptualToLinearRoughness(s.coatPerceptualRoughness);
    #endif

    #if defined(BESTWORLD_TRANSPARENT) && defined(_ALPHAPREMULTIPLY_ON)
        s.diffuseColor *= s.alpha;
        s.f0 *= s.alpha;
        s.alpha = 1.0 - BestWorldOneMinusReflectivity(s.f0) * (1.0 - s.alpha);
    #endif
}

#endif
