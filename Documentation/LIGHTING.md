# Lighting a world for BestWorld

## Material setup

- Albedo is sRGB. Packed ORM is linear.
- Dielectrics: metallic 0, reflectance 0.5 (F0 ≈ 0.04).
- Metals: metallic 1, albedo is the F0 color, F82 tint stays white unless the metal needs a darker edge.
- Clearcoat is opt-in. Default IOR is 1.6 (OpenPBR). Coat Darkening 1 is the physical wet/paint look; 0 keeps the base albedo.
- Roughness is roughness, not smoothness, in ORM mode.
- Emission uses the GI multiplier in the meta pass. Bake after setting it.

## Scene setup

1. Linear color space.
2. Lightmap static on architecture.
3. Directional lightmaps (Progressive) or Bakery MonoSH.
4. At least one reflection probe per distinct lighting volume. Enable box projection. BestWorld sharpens nearby reflections from the probe AABB (Frostbite distance roughness); it does not need extra Udon.
5. Mixed lighting: Shadowmask. Keep **Bicubic Lightmap and Shadowmask** on for architecture.
6. Keep realtime extra lights to props and hero animated sources.

## Light Volumes

Install `red.sim.lightvolumes`, then press **Enable Light Volumes compile** on a BestWorld material.

- Dynamic / non-lightmapped meshes sample full volumes (probe replacement). PC reconstructs L1 with ZH3.
- Lightmapped meshes sample additive volumes only, on top of the bake.
- If the compile define is on but the scene has no volumes, BestWorld uses Unity `ShadeSH9` (L2). It does not keep the package's L1-only probe fallback.
- Place the official attribution prefab or a world description line. That is how avatars know they can use volume-aware shaders.

## LTCGI

Install `at.pimaker.ltcgi`, enable the compile define, then toggle LTCGI on nearby materials only. Screens and large emissive quads are the use case. Do not enable it on every wall.

## Quest

Android uses the second SubShader:

- No ForwardAdd
- No clearcoat / parallax / detail / bicubic / LTCGI / ZH3 / distance roughness
- FON single-scatter (not Lambert), Filament mediump D, geometric specular AA
- Lightmaps, probes, and Fdez-Agüera IBL energy remain

Test the Android build. A PC-only hero material can stay `BestWorld/Lit` with expensive toggles off; the SubShader still drops features on Quest.

## Performance defaults

| Surface | Shader | Notes |
| --- | --- | --- |
| Walls, floors, baked furniture | `BestWorld/Lit` | ORM, bicubic on, MonoSH if Bakery |
| Foliage cards | `BestWorld/Lit Cutout` | Cull Off, keep parallax off |
| Glass / thin fade | `BestWorld/Lit Transparent` | Premultiply for colored glass |
| Quest-wide filler | same materials | SubShader strips the expensive path |

Avoid unique materials per mesh. Atlas. Do not enable detail, parallax, clearcoat, or LTCGI as a project-wide default.
