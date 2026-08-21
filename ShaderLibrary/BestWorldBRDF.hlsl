#ifndef BESTWORLD_BRDF_INCLUDED
#define BESTWORLD_BRDF_INCLUDED

#include "BestWorldCommon.hlsl"

struct BestWorldSurface
{
    float3 albedo;
    float3 diffuseColor;
    float3 f0;
    float3 f82Tint;
    float perceptualRoughness;
    float roughness;
    float metallic;
    float occlusion;
    float reflectance;
    float specularWeight;
    float3 emission;
    float3 normal;
    float3 geometricNormal;
    float3 tangent;
    float3 bitangent;
    float3 view;
    float3 worldPos;
    float alpha;
    float coatWeight;
    float coatPerceptualRoughness;
    float coatRoughness;
    float coatF0;
    float coatDarkening;
};

struct BestWorldLight
{
    float3 color;
    float3 direction;
    float attenuation;
};

struct BestWorldBRDF
{
    float NoV;
    float NoL;
    float NoH;
    float LoH;
    float VoH;
    float3 H;
};

BestWorldBRDF BestWorldGetBRDF(float3 N, float3 V, float3 L)
{
    float3 H = BestWorldSafeNormalize(V + L);
    BestWorldBRDF b;
    b.H = H;
    b.NoV = abs(dot(N, V)) + BESTWORLD_EPS;
    b.NoL = saturate(dot(N, L));
    b.NoH = saturate(dot(N, H));
    b.LoH = saturate(dot(L, H));
    b.VoH = saturate(dot(V, H));
    return b;
}

// Walter 2007 GGX. alpha is linear roughness.
float BestWorldD_GGXRef(float NoH, float a)
{
    float a2 = a * a;
    float d = (NoH * a2 - NoH) * NoH + 1.0;
    return a2 / max(BESTWORLD_PI * d * d, BESTWORLD_EPS);
}

// Filament mediump-safe D on Quest. Uses ||N×H||² = 1-NoH² so GLES3 highlights do not sparkle.
float BestWorldD_GGX(float NoH, float a, float3 N, float3 H)
{
    #if defined(BESTWORLD_QUALITY_QUEST)
        float3 NxH = cross(N, H);
        float oneMinusNoHSquared = dot(NxH, NxH);
        float aa = NoH * a;
        float k = a / max(oneMinusNoHSquared + aa * aa, BESTWORLD_EPS);
        return k * k * BESTWORLD_INV_PI;
    #else
        return BestWorldD_GGXRef(NoH, a);
    #endif
}

// Heitz 2014 height-correlated Smith GGX. Returns G / (4 NoV NoL).
float BestWorldV_SmithGGXCorrelated(float NoV, float NoL, float a)
{
    float a2 = a * a;
    float ggxV = NoL * sqrt(max(NoV * NoV * (1.0 - a2) + a2, BESTWORLD_EPS));
    float ggxL = NoV * sqrt(max(NoL * NoL * (1.0 - a2) + a2, BESTWORLD_EPS));
    return 0.5 / max(ggxV + ggxL, BESTWORLD_EPS);
}

// Hammon 2017 / Filament V_SmithGGXCorrelated_Fast. a is linear roughness.
float BestWorldV_SmithGGXFast(float NoV, float NoL, float a)
{
    return 0.5 / max(lerp(2.0 * NoL * NoV, NoL + NoV, a), BESTWORLD_EPS);
}

// Kelemen 2001. Used for clearcoat.
float BestWorldV_Kelemen(float LoH)
{
    return 0.25 / max(LoH * LoH, BESTWORLD_EPS);
}

float3 BestWorldF_Schlick(float3 f0, float3 f90, float mu)
{
    return f0 + (f90 - f0) * BestWorldPow5(1.0 - saturate(mu));
}

float BestWorldF_Schlick(float f0, float f90, float mu)
{
    return f0 + (f90 - f0) * BestWorldPow5(1.0 - saturate(mu));
}

float3 BestWorldF90(float3 f0)
{
    // Filament: saturate(dot(f0, vec3(50 * 0.33))). Typical dielectric F0=0.04 → 1.
    return saturate(dot(f0, (50.0 * 0.33).xxx)).xxx;
}

// OpenPBR / Kutz 2021 F82-tint. White edge tint reduces to Schlick.
float3 BestWorldF_F82(float3 f0, float3 edgeTint, float mu)
{
    mu = saturate(mu);
    float3 fSchlick = BestWorldF_Schlick(f0, 1.0.xxx, mu);
    const float muBar = 1.0 / 7.0;
    float3 fSchlickBar = BestWorldF_Schlick(f0, 1.0.xxx, muBar);
    float3 fDesiredBar = edgeTint * fSchlickBar;
    float denom = muBar * BestWorldPow6(1.0 - muBar);
    float3 correction = (mu * BestWorldPow6(1.0 - mu) / max(denom, BESTWORLD_EPS)) * (fSchlickBar - fDesiredBar);
    return saturate(fSchlick - correction);
}

float BestWorldFd_Lambert()
{
    return BESTWORLD_INV_PI;
}

// Fujii FON single scatter (OpenPBR / EON paper). r in [0,1].
#define BESTWORLD_FON_C1 (0.5 - 2.0 / (3.0 * BESTWORLD_PI))
#define BESTWORLD_FON_C2 (2.0 / 3.0 - 28.0 / (15.0 * BESTWORLD_PI))

float3 BestWorldFd_FON(float3 rho, float r, float NoV, float NoL, float VoL)
{
    r = saturate(r);
    NoV = saturate(NoV);
    NoL = saturate(NoL);
    float s = VoL - NoL * NoV;
    float sovertF = s > 0.0 ? s / max(NoL, NoV) : s;
    float AF = 1.0 / (1.0 + BESTWORLD_FON_C1 * r);
    return rho * BESTWORLD_INV_PI * AF * (1.0 + r * sovertF);
}

float BestWorldE_FONApprox(float mu, float r)
{
    mu = saturate(mu);
    float mucomp = 1.0 - mu;
    float mucomp2 = mucomp * mucomp;
    float GoverPi = (0.0571085289 * mucomp + 0.491881867 * mucomp2)
        + (-0.332181442 * mucomp + 0.0714429953 * mucomp2) * mucomp2;
    return (1.0 + r * GoverPi) / (1.0 + BESTWORLD_FON_C1 * r);
}

// Portsmouth–Kutz–Hill EON (arXiv:2410.18026, OpenPBR 1.1). FON + reciprocal MS.
float3 BestWorldFd_EON(float3 rho, float r, float NoV, float NoL, float VoL)
{
    r = saturate(r);
    float3 fss = BestWorldFd_FON(rho, r, NoV, NoL, VoL);
    float AF = 1.0 / (1.0 + BESTWORLD_FON_C1 * r);
    float EFo = BestWorldE_FONApprox(saturate(NoV), r);
    float EFi = BestWorldE_FONApprox(saturate(NoL), r);
    float avgEF = AF * (1.0 + BESTWORLD_FON_C2 * r);
    float3 rhoMs = (rho * rho) * avgEF / max(1.0 - rho * (1.0 - avgEF), BESTWORLD_EPS);
    float3 fms = rhoMs * BESTWORLD_INV_PI
        * max(1.0e-7, 1.0 - EFo)
        * max(1.0e-7, 1.0 - EFi)
        / max(1.0e-7, 1.0 - avgEF);
    return fss + fms;
}

// Karis UE4 analytic DFG. Input is perceptual roughness.
float2 BestWorldEnvBRDF(float NoV, float perceptualRoughness)
{
    const float4 c0 = float4(-1.0, -0.0275, -0.572, 0.022);
    const float4 c1 = float4(1.0, 0.0425, 1.04, -0.04);
    float4 r = perceptualRoughness * c0 + c1;
    float a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;
    return float2(-1.04, 1.04) * a004 + r.zw;
}

// Lagarde/Turquin: 1 + f0 * (1/r - 1), r stored in DFG.y. Direct lights only.
float3 BestWorldEnergyCompensation(float3 f0, float2 dfg)
{
    return 1.0 + f0 * (1.0 / max(dfg.y, 0.01) - 1.0);
}

// Fdez-Agüera 2019 JCGT. IBL multiple scatter using split-sum DFG + irradiance.
void BestWorldFdezIbl(
    float3 f0,
    float3 diffuseColor,
    float specularWeight,
    float perceptualRoughness,
    float NoV,
    float2 dfg,
    float3 f82Tint,
    float metallic,
    out float3 FssEss,
    out float3 FmsEms,
    out float3 kD)
{
    float p = saturate(perceptualRoughness);
    float3 Fr = max((1.0 - p).xxx, f0) - f0;
    float3 kS = f0 + Fr * BestWorldPow5(1.0 - saturate(NoV));
    UNITY_BRANCH
    if (metallic > 0.001)
    {
        // Smooth metals: F82 dip. Rough metals keep Fdez roughness-dependent grazing.
        float3 kSmetal = BestWorldF_F82(f0, f82Tint, NoV);
        kS = lerp(kS, lerp(kSmetal, kS, p), metallic);
    }
    FssEss = (kS * dfg.x + dfg.y) * specularWeight;
    float Ess = saturate(dfg.x + dfg.y);
    float Ems = 1.0 - Ess;
    float3 Favg = f0 + (1.0 - f0) * (1.0 / 21.0);
    float3 Fms = FssEss * Favg / max(1.0 - Ems * Favg, BESTWORLD_EPS);
    FmsEms = Fms * Ems;
    kD = diffuseColor * saturate(1.0 - (FssEss + FmsEms));
}

// Lagarde 2014. roughness is linear alpha.
float BestWorldSpecularAO(float NoV, float ao, float linearRoughness)
{
    return saturate(pow(max(NoV + ao, 0.0), exp2(-16.0 * linearRoughness - 1.0)) - 1.0 + ao);
}

// Jimenez 2016 multi-bounce AO.
float3 BestWorldMultiBounceAO(float ao, float3 albedo)
{
    float3 a = 2.0404 * albedo - 0.3324;
    float3 b = -4.7951 * albedo + 0.6417;
    float3 c = 2.7552 * albedo + 0.6903;
    return max(ao.xxx, ((ao * a + b) * ao + c) * ao);
}

float BestWorldHorizonOcclusion(float3 R, float3 geometricNormal)
{
    float horizon = min(1.0 + dot(R, geometricNormal), 1.0);
    return horizon * horizon;
}

// Tokuyoshi/Kaplanyan 2021 isotropic forward filter (eq. 13), same shape as
// Filament 2019. κ = 0.18 from the 2021 paper / Kaplanyan 2016 clamp.
// Geometric floor is Vlachos GDC 2015 — VR HMD pixels miss thin highlights
// on dense meshes even when the shading normal is smooth.
float BestWorldSpecularAA(float perceptualRoughness, float3 shadingNormal, float3 geometricNormal)
{
    float3 du = ddx(shadingNormal);
    float3 dv = ddy(shadingNormal);
    float variance = 0.15 * (dot(du, du) + dot(dv, dv));
    float kernel = min(2.0 * variance, 0.18);
    float alpha = BestWorldPerceptualToLinearRoughness(perceptualRoughness);
    float alpha2 = saturate(alpha * alpha + kernel);
    float p = saturate(sqrt(sqrt(alpha2)));

    float3 gdu = ddx(geometricNormal);
    float3 gdv = ddy(geometricNormal);
    float geo = pow(saturate(max(dot(gdu, gdu), dot(gdv, gdv))), 0.33333333);
    return max(p, geo);
}

float BestWorldSpecularAAQuest(float perceptualRoughness, float3 geometricNormal)
{
    float3 gdu = ddx(geometricNormal);
    float3 gdv = ddy(geometricNormal);
    float geo = pow(saturate(max(dot(gdu, gdu), dot(gdv, gdv))), 0.33333333);
    return max(saturate(perceptualRoughness), geo);
}

// OpenPBR 1.1 albedo-scaling: E_spec(ωo) ≈ F0 * DFG.x + DFG.y.
float3 BestWorldSpecularDirectionalAlbedo(float3 f0, float specularWeight, float2 dfg)
{
    return saturate((f0 * dfg.x + dfg.y) * specularWeight);
}

// OpenPBR 1.1 coat darkening (eq. 76), white coat (T² = 1).
float3 BestWorldCoatDarkening(float coatF0, float coatWeight, float coatDarkening, float3 baseAlbedo)
{
    float K = coatF0 + (1.0 - coatF0) * (1.0 / 21.0);
    float3 delta = (1.0 - K) / max(1.0 - saturate(baseAlbedo) * K, BESTWORLD_EPS);
    return lerp(1.0.xxx, saturate(delta), saturate(coatDarkening * coatWeight));
}

// Filament / Chan micro-shadowing. Does not include NoL.
float BestWorldMicroShadow(float NoL, float ao)
{
    float aperture = 2.0 * ao * ao;
    return saturate(NoL + aperture - 1.0);
}

float3 BestWorldFresnel(BestWorldSurface s, float VoH)
{
    float3 Fdielectric = BestWorldF_Schlick(s.f0, BestWorldF90(s.f0), VoH);
    float3 Fmetal = BestWorldF_F82(s.f0, s.f82Tint, VoH);
    return lerp(Fdielectric, Fmetal, s.metallic) * s.specularWeight;
}

void BestWorldDirectLighting(
    BestWorldSurface s,
    BestWorldLight light,
    inout float3 diffuse,
    inout float3 specular)
{
    BestWorldBRDF b = BestWorldGetBRDF(s.normal, s.view, light.direction);
    float NoLspec = b.NoL;
    float NoLdiff = NoLspec;
    #if defined(BESTWORLD_ALPHA_CLIP)
        NoLdiff = saturate((dot(s.normal, light.direction) + 0.25) / 1.25);
    #endif
    float microShadow = BestWorldMicroShadow(NoLspec, s.occlusion);
    float attenSpec = light.attenuation * NoLspec * microShadow;
    float attenDiff = light.attenuation * NoLdiff * microShadow;
    if (attenSpec <= 0.0 && attenDiff <= 0.0)
    {
        return;
    }

    float3 F = BestWorldFresnel(s, b.VoH);
    float D = BestWorldD_GGX(b.NoH, s.roughness, s.normal, b.H);
    float VoL = dot(s.view, light.direction);
    #if defined(BESTWORLD_QUALITY_QUEST)
        float Vterm = BestWorldV_SmithGGXFast(b.NoV, b.NoL, s.roughness);
        float3 FdColor = BestWorldFd_FON(s.diffuseColor, s.perceptualRoughness, b.NoV, NoLdiff, VoL);
    #else
        float Vterm = BestWorldV_SmithGGXCorrelated(b.NoV, b.NoL, s.roughness);
        float3 FdColor = BestWorldFd_EON(s.diffuseColor, s.perceptualRoughness, b.NoV, NoLdiff, VoL);
    #endif

    float2 dfg = BestWorldEnvBRDF(b.NoV, s.perceptualRoughness);
    float3 energy = BestWorldEnergyCompensation(s.f0, dfg);
    float3 Fr = D * Vterm * F * energy;
    // OpenPBR 1.1 eq. 41: f = f_spec + (1 - E_spec(ωo)) f_diffuse
    FdColor *= 1.0 - BestWorldSpecularDirectionalAlbedo(s.f0, s.specularWeight, dfg);

    #if !defined(BESTWORLD_QUALITY_QUEST)
        UNITY_BRANCH
        if (s.coatWeight > 0.001)
        {
            float fcc = BestWorldF_Schlick(s.coatF0, 1.0, b.VoH) * s.coatWeight;
            float Dcc = BestWorldD_GGX(b.NoH, s.coatRoughness, s.normal, b.H);
            float Vcc = BestWorldV_Kelemen(b.LoH);
            float3 baseAlbedo = saturate(s.diffuseColor + s.f0 * s.metallic);
            float3 dark = BestWorldCoatDarkening(s.coatF0, s.coatWeight, s.coatDarkening, baseAlbedo);
            FdColor *= dark * (1.0 - fcc);
            Fr *= dark * (1.0 - fcc);
            Fr += (Dcc * Vcc * fcc).xxx;
        }
    #endif

    diffuse += FdColor * (light.color * attenDiff);
    specular += Fr * (light.color * attenSpec);
}

float3 BestWorldSHSpecular(
    BestWorldSurface s,
    float3 L0,
    float3 L1r,
    float3 L1g,
    float3 L1b)
{
    float3 l1Luma = L1r * 0.2126 + L1g * 0.7152 + L1b * 0.0722;
    float dirMag = length(l1Luma);
    float3 L = BestWorldSafeNormalize(l1Luma);
    float3 lightCol = max(L0 + float3(dot(L1r, L), dot(L1g, L), dot(L1b, L)), 0.0);
    float directionality = saturate(dirMag / max(BestWorldLuma(L0), 0.001));
    float perceptual = lerp(s.perceptualRoughness, 1.0, 1.0 - directionality * directionality);
    float a = BestWorldPerceptualToLinearRoughness(perceptual);

    BestWorldBRDF b = BestWorldGetBRDF(s.normal, s.view, L);
    float3 F = BestWorldFresnel(s, b.VoH);
    float D = BestWorldD_GGX(b.NoH, a, s.normal, b.H);
    #if defined(BESTWORLD_QUALITY_QUEST)
        float Vterm = BestWorldV_SmithGGXFast(b.NoV, b.NoL, a);
    #else
        float Vterm = BestWorldV_SmithGGXCorrelated(b.NoV, b.NoL, a);
    #endif
    float2 dfg = BestWorldEnvBRDF(b.NoV, perceptual);
    float3 energy = BestWorldEnergyCompensation(s.f0, dfg);
    return D * Vterm * F * energy * lightCol * b.NoL * directionality;
}

#endif
