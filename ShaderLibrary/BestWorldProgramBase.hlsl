#pragma vertex BestWorldVert
#pragma fragment BestWorldFragBase

#if defined(BESTWORLD_QUALITY_QUEST)
    #pragma target 3.5
    #pragma skip_variants SHADOWS_SOFT SHADOWS_CUBE SHADOWS_SHADOWMASK DIRLIGHTMAP_SEPARATE DYNAMICLIGHTMAP_ON
#else
    #pragma target 4.5
    #pragma skip_variants DIRLIGHTMAP_SEPARATE DYNAMICLIGHTMAP_ON
    #pragma shader_feature_local _DETAIL_MAP
    #pragma shader_feature_local _PARALLAXMAP
    #pragma shader_feature_local _CLEARCOAT
    #pragma shader_feature_local _LTCGI
#endif

#if defined(BESTWORLD_TRANSPARENT)
    #pragma shader_feature_local _ALPHAPREMULTIPLY_ON
#endif

#pragma multi_compile_fwdbase
#pragma multi_compile_fog
#pragma multi_compile_instancing
#pragma multi_compile _ LOD_FADE_CROSSFADE
#pragma instancing_options lodfade

#include "BestWorldPass.hlsl"
