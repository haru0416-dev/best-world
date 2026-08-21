# BestWorld

VRChat **world geometry** 向けの PBR シェーダーです。アバター用の全部入りシェーダーではありません。

「ベスト」は機能数ではなく、2026 年時点のワールド照明スタックに対して **正しい材質・正しいベイク・正しいフォールバック・Quest で落ちない負荷** を固定した、という意味です。

## 何が違うか

既存の定番はどれも強いですが、ワールド専用としては欠けがあります。

| シェーダー | 強い点 | ワールド専用として足りない点 |
| --- | --- | --- |
| Unity Standard / Standard Lite | 互換、Quest 公式 | 2015 年の BRDF。金属の Fresnel が強すぎる。Light Volumes / LTCGI 非対応 |
| Filamented | Filament 品質、Bakery、Specular AO | ワールド専用の製品切り分けが弱い。Quest 経路が Standard 互換の巨大バリアント |
| Graphlit | Filament + OpenPBR + Light Volumes + LTCGI + Bakery | ノードエディタ前提。ワールド作家が「この1本」として使うには重い |
| Mochie / Poiyomi | 機能が多い | アバター寄りの全部入り。ワールド全面に敷くとバリアントと命令数が膨らむ |
| ORL / GeneLit | 良い PBR | 照明スタックの揃い方が時期依存 |

BestWorld が固定した優先順位:

1. OpenPBR 1.1 の glossy-diffuse（EON + `1-E_spec`）+ Filament GGX + Fdez-Agüera IBL
2. OpenPBR F82-tint（金属のエッジ）。滑らかな金属の IBL にも使う
3. Lightmap / Directional / Bakery MonoSH / Lightmapped Specular / 色と方向の Bicubic
4. VRC Light Volumes（additive をライトマップ静的物に足す）
5. プローブ IBL（box projection、露出オクルージョン、ホライゾンオクルージョン）
6. オプトインのコート（IOR 1.6 + 暗化）と LTCGI（PC）
7. PC と Quest を **別 SubShader** で切る。Quest は FON・幾何 AA・mediump D
8. GrabPass・アウトライン・AudioLink・Toon は入れない

使っている式は `Documentation/ALGORITHMS.md` に一次資料から導出してあります。2018–2026 の広域採否は `Documentation/SURVEY.md`。

## シェーダー

- `BestWorld/Lit` — 不透明
- `BestWorld/Lit Cutout` — 切り抜き（PC は AlphaToMask）
- `BestWorld/Lit Transparent` — フェード / Premultiply

Quest / Android ビルドでは自動で軽量 SubShader に落ちます。ForwardAdd、EON マルチスキャタ、Clearcoat、Parallax、Detail、Bicubic、LTCGI は Quest から外れます。FON 単散乱と幾何スペキュラ AA は残します。

## 導入

VRChat の Unity 2022.3 ワールドプロジェクトへ入れます。

```sh
git clone https://github.com/haru0416-dev/best-world.git Packages/dev.haru.bestworld
```

zip を展開する場合も、置き場所は `Packages/dev.haru.bestworld/` です。`Assets` 配下に置いても動きます。

1. Color Space が Linear であること
2. マテリアルを `BestWorld/Lit` に差し替える
3. Packed Map を ORM で入れる（Substance / glTF の既定）
4. GPU Instancing をオン（インスペクタが強制します）
5. Light Volumes や LTCGI を使うならインスペクタの Enable ボタンで scripting define を足す

Unity がパッケージファイルを見つけられない状態で define だけ足すと、シェーダーがピンクになります。先に VPM でパッケージを入れてください。

### 任意パッケージ

- [VRC Light Volumes](https://github.com/REDSIM/VRCLightVolumes) — `BESTWORLD_HAS_VRC_LIGHT_VOLUMES`（v3 なら `BESTWORLD_LIGHTVOLUMES_V3` も）
- [LTCGI](https://github.com/PiMaker/ltcgi) — `BESTWORLD_HAS_LTCGI` とマテリアルの LTCGI トグル

未導入なら Unity のライトマップとプローブにフォールバックします。

## Packed Map

既定は glTF ORM です。

| チャンネル | ORM | Unity MetallicSmoothness |
| --- | --- | --- |
| R | Occlusion | Metallic |
| G | Roughness | unused（Occlusion マップの G を使用） |
| B | Metallic | unused |
| A | unused | Smoothness |

## ベイク

- Progressive なら Directional を推奨
- Bakery なら **MonoSH** を推奨し、マテリアルの Bakery MonoSH をオン
- 静的メッシュは Lightmap Static
- Reflection Probe は box projection
- Mixed は Shadowmask が BestWorld と相性が良い。Subtractive も扱う
- Meta pass があるので、見た目の metallic / roughness / emission がベイクに乗る

詳細は `Documentation/LIGHTING.md`。調査メモは `Documentation/RESEARCH.md`。各項の式は `Documentation/ALGORITHMS.md`。新しい論文の採否は `Documentation/SURVEY.md`。

## やらないこと

- アバター向け Toon / Outline / AudioLink
- GrabPass 屈折
- URP / HDRP
- 既存シェーダーのソース転載（数式は公開論文・Filament ドキュメント・OpenPBR 仕様から再実装）

## ライセンス

MIT。Filament の理論は Apache-2.0 の公開ドキュメント、OpenPBR F82 は Academy Software Foundation の仕様、EnvBRDF 近似は Karis / UE4 コースノートに依拠します。LTCGI と Light Volumes はそれぞれのパッケージを include するだけで、このリポジトリにはコピーしていません。
