# Research notes

BestWorld を組む前に、2026 年時点の VRChat ワールドシェーダーと照明スタックを外部から整理したメモです。0.4.0 で Graphlit / Mochie Standard / GeneLit / Filamented / ORL / peppermint と Light Volumes / LTCGI の実装を読み、論文に無い穴（距離ラフネス、ZH3、L2 復帰、Shadowmask 三次、LTCGI 生 UV1）を採否しました。ソース転載はしていません。

## Platform

- VRChat worlds still use Unity 2022.3 Built-in Forward.
- Custom world shaders are allowed on Android/Quest. Avatar shaders are not.
- Quest still hates GrabPass, geometry shaders, tessellation, and keyword explosions.
- Worlds should bake. Realtime lights are a seasoning, not the meal.
- GPU instancing helps props. Lightmapped static meshes prefer static batching; instancing and unique lightmap ST fight each other.

## Lighting stack that actually matters in 2026

1. **Unity lightmaps** — still the base for static world geometry.
2. **Bakery MonoSH** — best default directional bake for realistic worlds. Full SH/RNM is for neon-heavy clubs and costs VRAM.
3. **VRC Light Volumes** — voxel SH replacement for probes, plus additive volumes on lightmapped meshes. This is the current “avatars look like they belong in the world” layer.
4. **LTCGI** — realtime area lights for screens and large panels. Optional, PC-first, Quest-limited.
5. **Reflection probes + box projection** — still required. Volumes do not replace cubemaps.
6. **Shadowmask mixed lighting** — the mixed mode that does not fight PBR as hard as Subtractive.

Light Volumes documentation is explicit: lightmapped meshes should sample **additive** volumes, not replace the lightmap. Dynamic meshes replace probe SH with `LightVolumeSH`. Specular from SH should use the dominant direction for hard-surface PBR.

## Existing shaders

### Filamented (Silent)

The quality bar for “Standard, but the BRDF is not from 2015”. Filament GGX, better Fresnel, exposure occlusion, Bakery, specular AA. RED_SIM still calls it one of the best PBR options for worlds. It is a Standard-shaped product, not a world-first product.

### Graphlit (z3y)

The most complete *stack*: Filament/OpenPBR, Bakery MonoSH, Light Volumes, LTCGI (raw UV1), AreaLit, clustered lights, Frostbite probe roughness, ZH3, bicubic shadowmask. The cost is a node graph toolchain. BestWorld 0.4.0 takes the world-lighting subset without the editor or extra packages.

### Mochie Standard

World-capable Standard replacement: HDRP distance roughness, bicubic lightmap/shadowmask, Light Volumes, LTCGI (raw UV1). Also ships SSR, rain, SSS, AudioLink, AreaLit, and a 1.5× directional boost. Those extras are why it is a hero-prop shader, not a world default. BestWorld keeps the lighting subset and drops the kitchen sink.

### Poiyomi / lilToon / UnlitWF / Xiexe / ACLS

Avatar-first. They now receive Light Volumes and LTCGI so avatars can look correct *inside* a world. They are the wrong default for walls, floors, and baked furniture.

### ORL, GeneLit, Unity Shaders Plus

Good PBR or Standard-plus. Coverage of the 2025–2026 world lighting stack is package-version dependent.

### VRChat Mobile Lightmapped / Standard Lite

The honest Quest baseline. No realtime lighting on Lightmapped. Looks dated next to Filament, but it is the performance floor.

## BRDF sources used for reimplementation

- [Physically Based Rendering in Filament](https://google.github.io/filament/Filament.md.html) — GGX, Smith correlated visibility, energy compensation on punctual lights, specular AO, horizon occlusion, geometric specular AA, clearcoat Kelemen.
- [OpenPBR 1.1](https://academysoftwarefoundation.github.io/OpenPBR/) and [Kutz 2025 course notes](https://arxiv.org/abs/2512.23696) — F82-tint; EON; albedo-scaling layering; coat IOR 1.6 and coat_darkening.
- Fdez-Agüera 2019 JCGT — IBL multiple scattering from split-sum DFG + cosine irradiance.
- Vlachos, Advanced VR Rendering, GDC 2015 — centroid normals and geometric roughness floor for HMDs.
- Karis UE4 SIGGRAPH notes — analytic EnvBRDF for IBL without a DFG LUT.
- Unity Built-in GI macros — lightmaps, directional decode, shadowmask, subtractive, box-projected cubemaps, meta pass.
- Bakery wiki — MonoSH as monochrome L1 in the directional map; lightmapped specular as an approximation, not a ground truth.
- [VRC Light Volumes For Shader Developers](https://github.com/REDSIM/VRCLightVolumes/blob/main/Documentation/ForShaderDevelopers.md)
- [LTCGI For Shader Authors](https://ltcgi.dev/Advanced/Shader_Authors) — `lmuv` is raw UV1. Specular is accumulated without an extra F0 multiply.

## What “best” is not

There is no shader that is best for avatars, toon, water, grab-pass glass, and baked architecture at once. Those products exist and they leak cost into every material.

BestWorld is best only if you accept that constraint: **world geometry in the current VRChat lighting stack**. Water, mirrors, toon NPCs, and avatar shaders stay someone else’s job.
