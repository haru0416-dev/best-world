Shader "BestWorld/Lit Cutout"
{
    Properties
    {
        [Header(Maps)]
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo", 2D) = "white" {}
        [Enum(ORM, 0, Unity MetallicSmoothness, 1)] _MapFormat ("Packed Map Format", Float) = 0
        [NoScaleOffset] _PackedMap ("Packed Map", 2D) = "white" {}
        [NoScaleOffset] _OcclusionMap ("Occlusion (Unity format G)", 2D) = "white" {}
        [NoScaleOffset] _BumpMap ("Normal Map", 2D) = "bump" {}
        _BumpScale ("Normal Scale", Float) = 1
        [NoScaleOffset] _EmissionMap ("Emission Map", 2D) = "white" {}
        [HDR] _EmissionColor ("Emission", Color) = (0,0,0,1)
        _EmissionGIMultiplier ("Emission GI Multiplier", Float) = 1
        [NoScaleOffset] _ParallaxMap ("Height Map", 2D) = "black" {}
        _Parallax ("Height Scale", Range(0.005, 0.08)) = 0.02
        _DetailAlbedoMap ("Detail Albedo", 2D) = "gray" {}
        [NoScaleOffset] _DetailNormalMap ("Detail Normal", 2D) = "bump" {}
        _DetailAlbedoScale ("Detail Albedo Strength", Range(0, 1)) = 0
        _DetailNormalScale ("Detail Normal Strength", Range(0, 2)) = 0

        [Header(Material)]
        _Metallic ("Metallic", Range(0, 1)) = 0
        _Roughness ("Roughness (ORM multiplier)", Range(0, 1)) = 1
        _Glossiness ("Smoothness (Unity format)", Range(0, 1)) = 0.5
        _OcclusionStrength ("Occlusion Strength", Range(0, 1)) = 1
        _Reflectance ("Reflectance", Range(0, 1)) = 0.5
        _SpecularWeight ("Specular Weight", Range(0, 1)) = 1
        _F82Tint ("Metal Edge Tint (F82)", Color) = (1,1,1,1)
        _CoatWeight ("Clearcoat", Range(0, 1)) = 0
        _CoatRoughness ("Clearcoat Roughness", Range(0, 1)) = 0.1
        _CoatIOR ("Clearcoat IOR", Range(1.0, 3.0)) = 1.6
        _CoatDarkening ("Clearcoat Darkening", Range(0, 1)) = 1
        [NoScaleOffset] _CoatMaskMap ("Clearcoat Mask", 2D) = "white" {}

        [Header(Lighting)]
        [ToggleUI] _UseVertexColor ("Vertex Color Albedo", Float) = 0
        [ToggleUI] _BicubicLightmap ("Bicubic Lightmap and Shadowmask", Float) = 1
        [ToggleUI] _BakeryMonoSH ("Bakery MonoSH", Float) = 0
        [Toggle(_LTCGI)] _LTCGI ("LTCGI", Float) = 0
        [Toggle(_DETAIL_MAP)] _DETAIL_MAP ("Detail Maps", Float) = 0
        [Toggle(_PARALLAXMAP)] _PARALLAXMAP ("Parallax", Float) = 0
        [Toggle(_CLEARCOAT)] _CLEARCOAT ("Clearcoat", Float) = 0

        [Header(Alpha)]
        _Cutoff ("Cutoff", Range(0, 1)) = 0.5
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 2

        [HideInInspector] _Mode ("Mode", Float) = 1
        [HideInInspector] _SrcBlend ("Src Blend", Float) = 1
        [HideInInspector] _DstBlend ("Dst Blend", Float) = 0
        [HideInInspector] _ZWrite ("ZWrite", Float) = 1
        [Enum(Off, 0, Albedo, 1, Normal, 2, Roughness, 3, Metallic, 4, Occlusion, 5, F0, 6, Diffuse, 7, Specular, 8)] _DebugView ("Debug View", Float) = 0
    }

    CustomEditor "BestWorld.Editor.BestWorldLitShaderGUI"

    SubShader
    {
        Tags
        {
            "RenderType" = "TransparentCutout"
            "Queue" = "AlphaTest"
            "IgnoreProjector" = "True"
            "LTCGI" = "_LTCGI"
            "VRCFallback" = "Standard"
        }

        Only_Renderers d3d11 glcore metal
        Cull [_Cull]
        ZWrite On
        AlphaToMask On

        Pass
        {
            Name "FORWARD"
            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM
            #define BESTWORLD_ALPHA_CLIP
            #include "../ShaderLibrary/BestWorldProgramBase.hlsl"
            ENDCG
        }

        Pass
        {
            Name "FORWARD_DELTA"
            Tags { "LightMode" = "ForwardAdd" }
            Blend One One
            ZWrite Off
            Fog { Color (0,0,0,0) }

            CGPROGRAM
            #define BESTWORLD_ALPHA_CLIP
            #include "../ShaderLibrary/BestWorldProgramAdd.hlsl"
            ENDCG
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            Cull [_Cull]

            CGPROGRAM
            #define BESTWORLD_ALPHA_CLIP
            #include "../ShaderLibrary/BestWorldProgramShadow.hlsl"
            ENDCG
        }

        Pass
        {
            Name "META"
            Tags { "LightMode" = "Meta" }
            Cull Off

            CGPROGRAM
            #define BESTWORLD_ALPHA_CLIP
            #include "../ShaderLibrary/BestWorldProgramMeta.hlsl"
            ENDCG
        }
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "TransparentCutout"
            "Queue" = "AlphaTest"
            "IgnoreProjector" = "True"
            "VRCFallback" = "VRChat/Mobile/Lightmapped"
        }

        Only_Renderers gles3 vulkan
        Cull [_Cull]
        ZWrite On

        Pass
        {
            Name "FORWARD"
            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM
            #define BESTWORLD_QUALITY_QUEST
            #define BESTWORLD_ALPHA_CLIP
            #include "../ShaderLibrary/BestWorldProgramBase.hlsl"
            ENDCG
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            Cull [_Cull]

            CGPROGRAM
            #define BESTWORLD_QUALITY_QUEST
            #define BESTWORLD_ALPHA_CLIP
            #include "../ShaderLibrary/BestWorldProgramShadow.hlsl"
            ENDCG
        }

        Pass
        {
            Name "META"
            Tags { "LightMode" = "Meta" }
            Cull Off

            CGPROGRAM
            #define BESTWORLD_QUALITY_QUEST
            #define BESTWORLD_ALPHA_CLIP
            #include "../ShaderLibrary/BestWorldProgramMeta.hlsl"
            ENDCG
        }
    }

    FallBack "Transparent/Cutout/Diffuse"
}
