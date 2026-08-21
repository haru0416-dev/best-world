#ifndef BESTWORLD_CONFIG_INCLUDED
#define BESTWORLD_CONFIG_INCLUDED

// Optional VRChat lighting packages. These includes are only compiled when the
// matching scripting define is set, so the shader stays pink-free in a stock
// Unity / VRChat project.
//
// Player Settings > Scripting Define Symbols, or the BestWorld inspector:
//   BESTWORLD_HAS_VRC_LIGHT_VOLUMES
//   BESTWORLD_LIGHTVOLUMES_V3
//   BESTWORLD_HAS_LTCGI

#if defined(BESTWORLD_HAS_VRC_LIGHT_VOLUMES)
    #include "Packages/red.sim.lightvolumes/Shaders/LightVolumes.cginc"
#endif

#if defined(BESTWORLD_HAS_LTCGI) && !defined(BESTWORLD_QUALITY_QUEST)
    #include "Packages/at.pimaker.ltcgi/Shaders/LTCGI.cginc"
#endif

#endif
