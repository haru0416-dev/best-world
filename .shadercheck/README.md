# .shadercheck — headless compile gate

A fast, headless syntax/type check for the BestWorld **core shading math**
(`ShaderLibrary/BestWorldBRDF.hlsl` + `ShaderLibrary/BestWorldCommon.hlsl`).

It compiles the math to SPIR-V with `glslangValidator`'s HLSL front end across
the PC / Quest quality paths and the alpha-clip / transparent feature defines.
Only Unity's built-in `*.cginc` headers are stubbed (`stub/`); the BestWorld
functions are compiled exactly as written.

```sh
sudo apt-get install -y glslang-tools   # one-time: provides glslangValidator
./.shadercheck/compile_check.sh
```

The folder name starts with `.` so Unity's asset importer ignores it — these
files never ship as package assets.

## What this does NOT cover

This is a shader-math gate, not a full build. The following still require the
**Unity Editor 2022.3 (+ VRChat SDK)** and are not reproducible in a headless
Linux environment:

- The full `Shaders/*.shader` ShaderLab variants and the `#pragma` variant matrix.
- `BestWorldIBL.hlsl`, `BestWorldInputs.hlsl`, `BestWorldLighting.hlsl`,
  `BestWorldLightmap.hlsl`, `BestWorldPass.hlsl`, and the `BestWorldProgram*.hlsl`
  entry files, which call real Unity APIs (probes, SH, lightmaps, instancing).
- The `Editor/BestWorldLitShaderGUI.cs` inspector, which references
  `UnityEngine` / `UnityEditor`.
- Rendering the result in Unity or VRChat.
