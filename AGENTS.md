# AGENTS.md

## Cursor Cloud specific instructions

### What this repo is

BestWorld is a **Unity Package Manager (UPM) package** — a physically based
ShaderLab/HLSL shader for VRChat *world* geometry. It is not a standalone app.

- `Shaders/*.shader` — ShaderLab entry points (`BestWorld/Lit`, `Lit Cutout`, `Lit Transparent`).
- `ShaderLibrary/*.hlsl` — the shading library (BRDF/IBL/lightmap/pass/program includes).
- `Editor/BestWorldLitShaderGUI.cs` — a `ShaderGUI` inspector (references `UnityEngine`/`UnityEditor`).
- `Documentation/*.md`, `README.md`, `CHANGELOG.md` — docs (Japanese).
- `package.json` is a **Unity UPM manifest**, not npm. There is no npm/pip
  project, no test suite, no CI, and no git hooks in this repo.

### What runs headlessly (the closest thing to build/test/lint here)

The core PBR math (`ShaderLibrary/BestWorldBRDF.hlsl` + `BestWorldCommon.hlsl`)
is pure HLSL and is compiled to SPIR-V by a small committed harness:

```sh
./.shadercheck/compile_check.sh
```

It compiles the PC and Quest quality paths plus the alpha-clip / transparent
feature defines, stubbing only Unity's built-in `*.cginc` headers (which the
math does not call). It requires `glslangValidator` from `glslang-tools`
(installed by the environment update script). `.shadercheck/` starts with a dot,
so Unity's asset importer ignores it and it never ships as a package asset.
See `.shadercheck/README.md`.

### What does NOT run in this VM (needs the Unity Editor / VRChat)

There is no way to fully build, lint, or run this package headlessly on Linux:

- The full `.shader` variant matrix and the `BestWorldIBL/Inputs/Lighting/
  Lightmap/Pass/Program*.hlsl` includes call real Unity APIs (reflection probes,
  SH, lightmaps, `UNITY_*` macros, instancing) and only compile inside Unity's
  shader compiler.
- `Editor/BestWorldLitShaderGUI.cs` needs Unity's managed assemblies to compile.
- Seeing the material actually render requires **Unity Editor 2022.3.22f1 + VRChat
  SDK + a GPU**, and the shipping target (VRChat) is a separate client. None of
  these are provisioned here — do not attempt to install Unity as part of routine
  setup. Treat the `.shadercheck` compile gate as the available "build/test".

### Gotcha

Do not point the `.shadercheck` harness at the Unity-dependent includes
(IBL/Inputs/Lighting/Lightmap/Pass/Program*). The empty `stub/*.cginc` headers
only work because the core BRDF math calls no Unity API; those other files need
real Unity headers and will not compile against the stubs.
