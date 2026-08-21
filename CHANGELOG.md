# BestWorld 0.3.0

- Broader 2018–2026 survey (OpenPBR 1.1, SIGGRAPH 2025 PBS, Filament mobile D, Vlachos VR, Light Volumes API).
- Direct diffuse uses OpenPBR albedo-scaling (`1 - E_spec`) so EON/FON no longer double-count with GGX.
- Quest diffuse is FON single-scatter, not Lambert. Geometric specular AA is on.
- Clearcoat defaults to OpenPBR IOR 1.6 plus coat darkening.
- Smooth-metal IBL uses F82; lightmapped/SH specular uses the same F82 + Turquin path as punctual lights.
- Bicubic filtering applies to directional / MonoSH maps, not just color.
- PC silhouette sparkle uses centroid geometric normals (Vlachos). Cutout cards get a weak diffuse wrap.

# BestWorld 0.2.0

- Surveyed 2018–2026 shading papers in parallel with the 0.1.1 re-derivation.
- PC diffuse is OpenPBR EON (Portsmouth/Kutz/Hill 2024), not Burley.
- IBL multiple scatter is Fdez-Agüera 2019, using lightmap/SH irradiance.
- Specular AA clamp follows Tokuyoshi 2021 (κ = 0.18).
- Direct GGX still uses Turquin compensation; Fdez-Agüera is IBL-only.

# BestWorld 0.1.1

- Re-derived every shading term from primary papers and specs.
- Fixed Quest visibility (Hammon correlated-Smith, not Schlick G/4).
- Burley and specular AO now take linear roughness.
- Geometric specular AA matches Tokuyoshi/Filament (α² + kernel).
- Unity IBL mip uses the 1.7-0.7 remap.
- Bakery MonoSH uses L1 scale 2 and Geomerics luma reconstruction.
- Indirect diffuse subtracts split-sum specular energy; baked luma drives Lagarde spec AO.
- Direct diffuse matches Filament: Burley/Lambert is not also multiplied by (1-F).
- Dielectric F90 uses Filament's luminance heuristic as a float3 (HLSL-safe).

# BestWorld 0.1.0

- World-first PBR for VRChat Built-in Forward.
- Filament GGX / Burley, OpenPBR F82-tint, IBL energy compensation.
- Lightmaps, directional, Bakery MonoSH, lightmapped specular, bicubic filtering.
- Optional VRC Light Volumes and LTCGI via scripting defines.
- PC and Quest SubShaders with explicit feature stripping.
- Opaque, cutout, and transparent shaders plus a material inspector.
