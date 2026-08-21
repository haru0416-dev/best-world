#pragma vertex BestWorldVert
#pragma fragment BestWorldFragAdd
#pragma target 4.5
#define BESTWORLD_FORWARD_ADD
#pragma skip_variants DIRLIGHTMAP_SEPARATE DYNAMICLIGHTMAP_ON
#pragma shader_feature_local _DETAIL_MAP
#pragma shader_feature_local _PARALLAXMAP
#pragma shader_feature_local _CLEARCOAT
#if defined(BESTWORLD_TRANSPARENT)
    #pragma shader_feature_local _ALPHAPREMULTIPLY_ON
#endif
#pragma multi_compile_fwdadd_fullshadows
#pragma multi_compile_fog
#pragma multi_compile_instancing
#pragma multi_compile _ LOD_FADE_CROSSFADE
#pragma instancing_options lodfade

#include "BestWorldPass.hlsl"
