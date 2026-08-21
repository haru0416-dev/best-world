#ifndef BESTWORLD_SHADOW_META_INCLUDED
#define BESTWORLD_SHADOW_META_INCLUDED

#include "BestWorldInputs.hlsl"
#include "UnityMetaPass.cginc"

struct BestWorldShadowAppData
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float2 uv0 : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct BestWorldShadowV2F
{
    V2F_SHADOW_CASTER;
    float2 uv : TEXCOORD1;
    UNITY_VERTEX_OUTPUT_STEREO
};

BestWorldShadowV2F BestWorldVertShadow(BestWorldShadowAppData v)
{
    UNITY_SETUP_INSTANCE_ID(v);
    BestWorldShadowV2F o;
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
    TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
    o.uv = TRANSFORM_TEX(v.uv0, _MainTex);
    return o;
}

float4 BestWorldFragShadow(BestWorldShadowV2F i) : SV_Target
{
    float alpha = UNITY_SAMPLE_TEX2D(_MainTex, i.uv).a * _Color.a;
    #if defined(BESTWORLD_ALPHA_CLIP)
        clip(alpha - _Cutoff);
    #elif defined(BESTWORLD_TRANSPARENT)
        clip(alpha - 0.3);
    #endif
    SHADOW_CASTER_FRAGMENT(i)
}

struct BestWorldMetaAppData
{
    float4 vertex : POSITION;
    float2 uv0 : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
    float2 uv2 : TEXCOORD2;
};

struct BestWorldMetaV2F
{
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
};

BestWorldMetaV2F BestWorldVertMeta(BestWorldMetaAppData v)
{
    BestWorldMetaV2F o;
    o.pos = UnityMetaVertexPosition(v.vertex, v.uv1.xy, v.uv2.xy, unity_LightmapST, unity_DynamicLightmapST);
    o.uv = TRANSFORM_TEX(v.uv0, _MainTex);
    return o;
}

float4 BestWorldFragMeta(BestWorldMetaV2F i) : SV_Target
{
    float4 albedoSample = UNITY_SAMPLE_TEX2D(_MainTex, i.uv) * _Color;
    float4 packed = UNITY_SAMPLE_TEX2D_SAMPLER(_PackedMap, _MainTex, i.uv);
    float metallic;
    float perceptualRoughness;
    UNITY_BRANCH
    if (_MapFormat < 0.5)
    {
        perceptualRoughness = packed.g * _Roughness;
        metallic = packed.b * _Metallic;
    }
    else
    {
        metallic = packed.r * _Metallic;
        perceptualRoughness = 1.0 - packed.a * _Glossiness;
    }

    float3 albedo = albedoSample.rgb;
    float3 dielectricF0 = (0.16 * _Reflectance * _Reflectance).xxx;
    float3 f0 = lerp(dielectricF0, albedo, saturate(metallic));
    float3 diffuseColor = albedo * (1.0 - saturate(metallic));
    float3 emission = UNITY_SAMPLE_TEX2D_SAMPLER(_EmissionMap, _MainTex, i.uv).rgb * _EmissionColor.rgb;

    UnityMetaInput meta;
    UNITY_INITIALIZE_OUTPUT(UnityMetaInput, meta);
    meta.Albedo = diffuseColor + f0 * perceptualRoughness * 0.5;
    meta.SpecularColor = f0;
    meta.Emission = emission * _EmissionGIMultiplier;
    return UnityMetaFragment(meta);
}

#endif
