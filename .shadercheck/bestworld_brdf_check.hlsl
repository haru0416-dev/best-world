// Headless compile harness for the BestWorld core PBR math.
// Unity provides UNITY_BRANCH as the [branch] attribute; mirror that here so
// ShaderLibrary/BestWorldBRDF.hlsl compiles unmodified outside the Unity Editor.
#define UNITY_BRANCH [branch]

#include "BestWorldBRDF.hlsl"

struct VIn
{
    float4 uv : TEXCOORD0;
};

// Pixel-shader entry that exercises the public BestWorld math so the compiler
// type-checks and lowers every function (BestWorldSpecularAA needs ddx/ddy,
// hence a pixel-stage entry).
float4 main(VIn i) : SV_Target
{
    BestWorldSurface s = (BestWorldSurface)0;
    s.albedo = (0.5).xxx;
    s.diffuseColor = (0.5).xxx;
    s.f0 = (0.04).xxx;
    s.f82Tint = (1.0).xxx;
    s.perceptualRoughness = saturate(i.uv.x);
    s.roughness = BestWorldPerceptualToLinearRoughness(saturate(i.uv.x));
    s.metallic = saturate(i.uv.y);
    s.occlusion = 1.0;
    s.reflectance = 0.5;
    s.specularWeight = 1.0;
    s.normal = float3(0.0, 0.0, 1.0);
    s.geometricNormal = float3(0.0, 0.0, 1.0);
    s.tangent = float3(1.0, 0.0, 0.0);
    s.bitangent = float3(0.0, 1.0, 0.0);
    s.view = BestWorldSafeNormalize(float3(i.uv.xy, 1.0));
    s.worldPos = i.uv.xyz;
    s.alpha = 1.0;
    s.coatWeight = saturate(i.uv.z);
    s.coatPerceptualRoughness = 0.1;
    s.coatRoughness = BestWorldPerceptualToLinearRoughness(0.1);
    s.coatF0 = BestWorldIorToF0(1.6);
    s.coatDarkening = 1.0;

    BestWorldLight light;
    light.color = (1.0).xxx;
    light.direction = BestWorldSafeNormalize(float3(0.3, 0.5, 0.8));
    light.attenuation = 1.0;

    float3 diffuse = (0.0).xxx;
    float3 specular = (0.0).xxx;
    BestWorldDirectLighting(s, light, diffuse, specular);

    float3 sh = BestWorldSHSpecular(s, (0.5).xxx, (0.1).xxx, (0.1).xxx, (0.1).xxx);

    float2 dfg = BestWorldEnvBRDF(0.5, s.perceptualRoughness);
    float3 energy = BestWorldEnergyCompensation(s.f0, dfg);

    float3 FssEss, FmsEms, kD;
    BestWorldFdezIbl(
        s.f0, s.diffuseColor, s.specularWeight, s.perceptualRoughness,
        0.5, dfg, s.f82Tint, s.metallic, FssEss, FmsEms, kD);

    float aa = BestWorldSpecularAA(s.perceptualRoughness, s.normal, s.geometricNormal);
    float aaQuest = BestWorldSpecularAAQuest(s.perceptualRoughness, s.geometricNormal);
    float3 mb = BestWorldMultiBounceAO(s.occlusion, s.albedo);
    float sao = BestWorldSpecularAO(0.5, s.occlusion, s.roughness);
    float3 coat = BestWorldCoatDarkening(s.coatF0, s.coatWeight, s.coatDarkening, s.albedo);
    float horizon = BestWorldHorizonOcclusion(reflect(-s.view, s.normal), s.geometricNormal);
    float3 fresnel = BestWorldFresnel(s, 0.5);

    float3 total = diffuse + specular + sh + FssEss + FmsEms + kD
        + energy + mb + coat + fresnel + (aa + aaQuest + sao + horizon).xxx;
    return float4(total, s.alpha);
}
