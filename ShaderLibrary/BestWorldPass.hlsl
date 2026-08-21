#ifndef BESTWORLD_PASS_INCLUDED
#define BESTWORLD_PASS_INCLUDED

#include "BestWorldLighting.hlsl"

BestWorldV2F BestWorldVert(BestWorldAppData v)
{
    UNITY_SETUP_INSTANCE_ID(v);
    BestWorldV2F o;
    UNITY_INITIALIZE_OUTPUT(BestWorldV2F, o);
    UNITY_TRANSFER_INSTANCE_ID(v, o);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

    float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
    o.pos = UnityObjectToClipPos(v.vertex);
    o.uv.xy = TRANSFORM_TEX(v.uv0, _MainTex);
    o.uv.zw = v.uv0;
    o.lightmapUV = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
    o.color = v.color;

    float3 n = UnityObjectToWorldNormal(v.normal);
    float3 t = UnityObjectToWorldDir(v.tangent.xyz);
    float sign = v.tangent.w * unity_WorldTransformParams.w;
    float3 b = cross(n, t) * sign;

    o.tangentToWorld[0] = float4(t.x, b.x, n.x, worldPos.x);
    o.tangentToWorld[1] = float4(t.y, b.y, n.y, worldPos.y);
    o.tangentToWorld[2] = float4(t.z, b.z, n.z, worldPos.z);

    UNITY_TRANSFER_LIGHTING(o, v.uv1);
    UNITY_TRANSFER_FOG(o, o.pos);
#ifdef VERTEXLIGHT_ON
    o.vertexLight = Shade4PointLights(
        unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
        unity_LightColor[0].rgb, unity_LightColor[1].rgb,
        unity_LightColor[2].rgb, unity_LightColor[3].rgb,
        unity_4LightAtten0, worldPos, n);
#endif
    return o;
}

void BestWorldUnpackTBN(BestWorldV2F i, out float3 tangent, out float3 bitangent, out float3 normal, out float3 worldPos)
{
    tangent = BestWorldSafeNormalize(float3(i.tangentToWorld[0].x, i.tangentToWorld[1].x, i.tangentToWorld[2].x));
    bitangent = BestWorldSafeNormalize(float3(i.tangentToWorld[0].y, i.tangentToWorld[1].y, i.tangentToWorld[2].y));
    normal = BestWorldSafeNormalize(float3(i.tangentToWorld[0].z, i.tangentToWorld[1].z, i.tangentToWorld[2].z));
    worldPos = float3(i.tangentToWorld[0].w, i.tangentToWorld[1].w, i.tangentToWorld[2].w);
}

float4 BestWorldFragBase(BestWorldV2F i) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(i);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

    #ifdef LOD_FADE_CROSSFADE
        UnityApplyDitherCrossFade(i.pos);
    #endif

    float3 tangent, bitangent, geometricNormal, worldPos;
    BestWorldUnpackTBN(i, tangent, bitangent, geometricNormal, worldPos);
    float3 view = BestWorldSafeNormalize(_WorldSpaceCameraPos.xyz - worldPos);

    BestWorldSurface s;
    UNITY_INITIALIZE_OUTPUT(BestWorldSurface, s);
    BestWorldBuildSurface(i, geometricNormal, tangent, bitangent, view, s);

    float4 col = BestWorldShadeForwardBase(i, s);
    UNITY_APPLY_FOG(i.fogCoord, col);
    return col;
}

float4 BestWorldFragAdd(BestWorldV2F i) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(i);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

    #ifdef LOD_FADE_CROSSFADE
        UnityApplyDitherCrossFade(i.pos);
    #endif

    float3 tangent, bitangent, geometricNormal, worldPos;
    BestWorldUnpackTBN(i, tangent, bitangent, geometricNormal, worldPos);
    float3 view = BestWorldSafeNormalize(_WorldSpaceCameraPos.xyz - worldPos);

    BestWorldSurface s;
    UNITY_INITIALIZE_OUTPUT(BestWorldSurface, s);
    BestWorldBuildSurface(i, geometricNormal, tangent, bitangent, view, s);

    float4 col = BestWorldShadeForwardAdd(i, s);
    UNITY_APPLY_FOG_COLOR(i.fogCoord, col, float4(0, 0, 0, 0));
    return col;
}

#endif
