# 広域調査（〜2026-08）

VRChat ワールド（Unity 2022.3 Built-in Forward、ライトマップ主照明、PC / Quest 別 SubShader、GrabPass なし）に対して、一次資料と現行エンジン実装を横断して採否を決めた記録です。既存 VRC シェーダーのソースは見ていません。

採用した式は [ALGORITHMS.md](./ALGORITHMS.md)。製品の位置づけは [RESEARCH.md](./RESEARCH.md)。

調査範囲: SIGGRAPH PBS コース 2014–2025（2026 はコースなし）、OpenPBR 1.1 / MaterialX 1.39、Filament 公開ドキュメント、Frostbite / UE4 Karis / Turquin、JCGT（Fdez-Agüera、Tokuyoshi 2021）、Vlachos GDC 2015 VR、VRC Light Volumes 公式 API、LTCGI 公式 API、Bakery 公開仕様。

## 結論（0.3.0）

コアの材質モデルは 0.2.0 のままで正しい。

| 層 | 最適 | 理由 |
| --- | --- | --- |
| NDF | GGX / Trowbridge–Reitz | 2025 コースでも置換先なし。GTR / Student-t はエンジン既定になっていない |
| 可視 | Heitz 相関 Smith。Quest は Hammon Fast | Filament と同値 |
| 導体 Fresnel | OpenPBR F82-tint | Belcour 基底より安く、OpenPBR 1.1 でも変更なし |
| 誘電体拡散 PC | EON | OpenPBR 1.1 / SIGGRAPH 2025 の業界標準 |
| 誘電体拡散 Quest | **FON 単散乱**（Lambert ではない） | EON の前半。MS 項を落とすだけで PC と連続する |
| 直接鏡面エネルギー | Turquin / Karis DFG.y | 狭い解析ライトに Fdez の一様照度仮定は合わない |
| IBL エネルギー | Fdez-Agüera 2019 | ライトマップがまさにその照度 |
| レイヤ結合 | **OpenPBR 1.1 albedo-scaling** | EON は Burley と違い grazing で暗くならない。`(1-F)` ではなく `1-E_spec(ωo)` |
| コート | IOR 1.6 + **coat_darkening** | OpenPBR 既定。濡れた床・塗装に必要 |
| SAA | Tokuyoshi 2021 + **Vlachos 幾何フロア** + **centroid 法線** | ワールドは VR。HMD 画素でハイライトが点になる |
| Quest D | Filament mediump `‖N×H‖²` | GLES3 の `1-NoH²` 相殺を避ける |
| ベイク | MonoSH + **方向マップも bicubic** | 色だけ三次で方向がバイリニアだとハイライトが格子になる |
| エリアライト | LTCGI include のみ | AreaLit は有料で公開 API がパッケージ同梱前提。既定にしない |
| ボリューム | 自前 GGX dominant | `LightVolumeSpecularDominant` は Standard 互換。F82 / Turquin を通さない |

## 0.3.0 で積んだ変更

| 項 | 以前 | 今 | 根拠 |
| --- | --- | --- | --- |
| 直接拡散と鏡面の結合 | 加算（EON がフル） | `Fd *= 1 - (F0·DFG.x + DFG.y)` | OpenPBR 1.1 式 41。Fdez IBL の `kD` と揃える |
| Quest 拡散 | Lambert | FON 単散乱 | EON 論文の `f_ss`。MS は ALU を Quest に載せない |
| コート F0 | 0.04（IOR 1.5） | **IOR 1.6 → F0≈0.053** | OpenPBR `coat_ior` 既定 |
| コート内部反射 | `(1-Fc)` だけ | 式 76 の **Δ 暗化** | 塗装・濡れ。`coat_darkening=0` で相殺可能 |
| IBL 金属 | Fdez のラフネス依存 Schlick のみ | 滑らかな金属は **F82**、ラフは Fdez | LUT 無しで 82° ディップを残す |
| Specular AA | PC のみ、シェーディング法線 | 幾何フロア + Quest でも幾何 AA | Tokuyoshi 2021 が HMD 画素を明示。Vlachos 2015 |
| シルエット火花 | なし | **centroid 法線**（PC） | Vlachos Advanced VR Rendering。MSAA 外挿 |
| Quest GGX D | `1-NoH²` | `dot(N×H,N×H)` | Filament `surface_brdf.fs` mobile |
| 方向ライトマップ | バイリニア | 色と同じ **bicubic** | MonoSH / Dominant のハイライト格子 |
| ライトマップ鏡面 / SH 鏡面 | Schlick + 補償なし | F82 + Turquin | 直接光と同じローブ |
| Cutout 裏面 | `saturate(NoL)` で黒 | 弱い **wrap**（拡散のみ） | 葉・カード。鏡面はラップしない |

## 見たが積まない

機能を足すほど「ベスト」にはならない、という前提で切っています。

### 材質モデル

| 候補 | 年 | 見送り理由 |
| --- | --- | --- |
| OpenPBR `base_diffuse_roughness` 独立スライダー（既定 0） | 1.1 | ワールドの壁は ORM のラフネス1本で石膏感を出したい。既定 0 にすると Lambert に戻り、0.2.0 より退化する。意識的に知覚ラフネスへ結合 |
| Hammon 2017 GGX 拡散 | 2017 | 同一マイクロファセットから拡散を出す点では一貫する。2025 の標準は EON。Quest は FON で足りる |
| Chan 2018 CoD WWII 拡散 | 2018 | 製品固有。炉試験と OpenPBR 交換が EON より弱い |
| Disney 2012 Burley | 2012 | Filament 既定だが炉試験でエネルギーを失う。0.2.0 で置換済み |
| Heitz 確率的マルチスキャタ | 2016 | Forward 1spp に不適 |
| Kulla–Conty 追加ローブ + LUT | 2017 | パス用。リアルタイムは Turquin / Fdez |
| Belcour Fresnel 基底 | 2020 | F82 より導体曲線は良いが基底 / LUT。OpenPBR 1.1 は F82 のまま |
| Knarkowicz 多項式 DFG | 2014 | Karis/Lazarov より当てはまりは良いが gloss 再マップ前提。Fdez が `(scale,bias)` を要求するので Karis を維持 |
| 128×32 FGD LUT（HDRP） | 2018 | ワールド配布でサンプラを1つ消費。Quest で痛い |
| OpenPBR fuzz / Charlie sheen | 1.1 | 布ヒーロー用。壁床の命令数に入れない |
| OpenPBR iridescence / thin-film | 1.1 | 油膜・シャボン。全面既定にしない |
| OpenPBR SSS / subsurface_weight | 1.1 | スキン・蠟。ワールド全面に入れない。葉は wrap で足りる |
| Dual-lobe GGX / 異方性 GGX | 各種 | ヘア・ブラシ金属。TBN 品質がワールド資産で揃わない |
| Substrate / UE5 層グラフ | 2023– | BIRP Forward に載らない |
| Neural / MLP BRDF | 2025–2026 | SIGGRAPH 2025 Weidlich。ウェイトがワールドに乗らない |
| GT7 トーンマップ、蛍光、Strand | SIGGRAPH 2025 | ポスト or ヘア。表面 BRDF ではない |
| Hazy specular / retro-reflection | OpenPBR 予定 | 1.1 時点で未仕様 |

### アンチエイリアス / IBL

| 候補 | 年 | 見送り理由 |
| --- | --- | --- |
| Tokuyoshi 2021 ハーフベクトル投影空間 | 2021 | ライト毎。IBL・ライトマップ・LTCGI に効かない。ワールドの主照明がそこ |
| LEADR / CLEAN / Toksvig マップ | 2013– | 前処理アセットが VRC パイプラインに無い |
| Filament bent-normal spec AO | 製品 | ベント法線ベイクが標準に無い。ライトマップ輝度で代用 |
| Parallax-corrected cubemap beyond Unity box | Lagarde 2012 | Unity が既に box projection を渡す。自前プロキシ幾何は作家作業を増やす |
| SH exponential glossy probes（HPG 2025） | 2025 | Unity キューブマップを置換できない |
| 自前 LTC / エリアライト | Heitz 2016 | LTCGI が既にある。コピーしない |

### VRChat スタック

| 候補 | 見送り理由 |
| --- | --- |
| AreaLit | Booth 有料。include パスがプロジェクト依存。LTCGI が無料のエリアライト層 |
| Bakery フル SH / RNM 既定 | VRAM。クラブは作家が専用シェーダーを選べばよい。既定は MonoSH |
| Graphlit Clustered BIRP | 追加ライトをリアルタイムの主照明にすると Quest が死ぬ。ワールドはベイクが主 |
| `LightVolumeSpecular` 3 色 | アバター向け。ハードサーフェスは dominant 1 ローブ。式はこちらの GGX に固定 |
| GrabPass / SSR / GTAO | Quest とミラーと相性が悪い。AO はベイク |
| AudioLink / Toon / Outline | アバター領域 |
| Unity APV / Enlighten RTGI | VRC 2022.3 ワールドの主経路ではない |
| Khronos PBR Neutral / AgX | カメラ側。シェーダーに焼かない |

## 直接光と IBL でモデルを分ける理由（再掲）

Fdez-Agüera は「二次散乱の入射は半球にほぼ一様」と置く。ライトマップとプローブはその仮定に近い。平行光やポイントライトは逆なので、直接鏡面は Turquin のローブスケールに留める。

拡散のレイヤ結合は逆で、**直接光にも IBL と同じ `E_spec(ωo)`** を掛ける。0.2.0 は Filament+Burley の慣習で `(1-F)` を避けたが、EON/FON は grazing で明るくなるため、OpenPBR の glossy-diffuse 式 41 が必要になる。

## OpenPBR 1.1 で意識的に外した既定

OpenPBR の `base_diffuse_roughness` 既定は 0（Lambert 基板）。BestWorld はワールド幾何用に **知覚ラフネスを EON/FON の r に入れる**。壁・コンクリートの ORM が「スペキュラを殺す」と同時に「拡散がざらつく」方が、VRC のベイク空間では正しく見える。独立スライダーは足さない。

コートだけは OpenPBR に合わせる（IOR 1.6、暗化既定 1）。クリアコートはオプトインなので、乗せる面は塗装として振る舞うべき。
