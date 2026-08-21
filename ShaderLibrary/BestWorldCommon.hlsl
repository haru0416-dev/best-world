#ifndef BESTWORLD_COMMON_INCLUDED
#define BESTWORLD_COMMON_INCLUDED

#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
#include "UnityStandardUtils.cginc"
#include "UnityImageBasedLighting.cginc"

#define BESTWORLD_PI            3.14159265358979323846
#define BESTWORLD_INV_PI        0.31830988618379067154
#define BESTWORLD_EPS           1e-5
#define BESTWORLD_MIN_ROUGHNESS 0.002

float BestWorldPow5(float x)
{
    float x2 = x * x;
    return x2 * x2 * x;
}

float BestWorldPow6(float x)
{
    float x2 = x * x;
    return x2 * x2 * x2;
}

float BestWorldSqr(float x)
{
    return x * x;
}

float BestWorldLuma(float3 c)
{
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

float BestWorldPerceptualToLinearRoughness(float perceptual)
{
    return max(perceptual * perceptual, BESTWORLD_MIN_ROUGHNESS);
}

float3 BestWorldSafeNormalize(float3 v)
{
    float len2 = dot(v, v);
    return len2 > BESTWORLD_EPS ? v * rsqrt(len2) : float3(0.0, 0.0, 1.0);
}

float BestWorldOneMinusReflectivity(float3 f0)
{
    return 1.0 - max(max(f0.r, f0.g), f0.b);
}

#endif
