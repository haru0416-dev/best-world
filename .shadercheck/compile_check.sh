#!/usr/bin/env bash
# Headless compile-check for the BestWorld core PBR shading math.
#
# Compiles ShaderLibrary/BestWorldBRDF.hlsl (which pulls in BestWorldCommon.hlsl)
# for every quality/feature variant using glslangValidator's HLSL front end,
# emitting SPIR-V. Only Unity's built-in cginc headers are stubbed
# (.shadercheck/stub/); the BestWorld math is compiled exactly as written.
#
# This does NOT replace a real Unity build: the full .shader variants, the IBL /
# lightmap / pipeline includes, and the C# inspector still require the Unity
# Editor. It is a fast syntax/type gate for the shading model, runnable headless.
#
# Requires: glslang-tools (provides glslangValidator).
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HARNESS_DIR/.." && pwd)"
SHADER_LIB="$REPO_ROOT/ShaderLibrary"
STUB_DIR="$HARNESS_DIR/stub"
SRC="$HARNESS_DIR/bestworld_brdf_check.hlsl"

if ! command -v glslangValidator >/dev/null 2>&1; then
  echo "ERROR: glslangValidator not found. Install it with: sudo apt-get install -y glslang-tools" >&2
  exit 127
fi

INC=(-I"$SHADER_LIB" -I"$STUB_DIR")
TMP_OUT="$(mktemp -d)"
trap 'rm -rf "$TMP_OUT"' EXIT

pass=0
fail=0

compile() {
  local label="$1"; shift   # remaining args are extra -D defines
  local out="$TMP_OUT/out.spv"
  if glslangValidator -D -e main -S frag --target-env vulkan1.1 \
        "$@" "${INC[@]}" "$SRC" -o "$out" >"$TMP_OUT/log.txt" 2>&1; then
    printf 'OK    %-34s -> %6s bytes (SPIR-V)\n' "$label" "$(wc -c <"$out" | tr -d ' ')"
    pass=$((pass+1))
  else
    printf 'FAIL  %s\n' "$label"
    sed 's/^/        /' "$TMP_OUT/log.txt"
    fail=$((fail+1))
  fi
}

echo "BestWorld shader-math compile check"
echo "  compiler : $(glslangValidator --version 2>/dev/null | head -1)"
echo "  library  : $SHADER_LIB"
echo

compile "PC / default"
compile "PC / alpha-clip (cutout)"      -DBESTWORLD_ALPHA_CLIP=1
compile "PC / transparent premult"      -DBESTWORLD_TRANSPARENT=1 -D_ALPHAPREMULTIPLY_ON=1
compile "Quest / default"               -DBESTWORLD_QUALITY_QUEST=1
compile "Quest / alpha-clip (cutout)"   -DBESTWORLD_QUALITY_QUEST=1 -DBESTWORLD_ALPHA_CLIP=1

echo
echo "Variants passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
