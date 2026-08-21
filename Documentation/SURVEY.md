# 2018–2026 アルゴリズム調査

一次資料だけを見て、BestWorld が積んでいる項より新しい（または同世代でより正確な）候補を並べ、VRChat ワールド（Unity 2022.3 Built-in Forward、ライトマップ主照明、Quest SubShader）に採用するかどうかを決めた記録です。既存 VRC シェーダーのソースは見ていません。

採用した式の導出は [ALGORITHMS.md](./ALGORITHMS.md)。製品の位置づけは [RESEARCH.md](./RESEARCH.md)。

## 採用（0.2.0）

| 項 | 以前 | 今 | 理由 |
| --- | --- | --- | --- |
| PC 拡散 | Burley 2012（Filament） | **EON**（Portsmouth / Kutz / Hill 2024、OpenPBR 1.0、SIGGRAPH 2025 course） | 炉試験を通る相互的ラフ拡散。業界の交換標準。Quest は Lambert のまま |
| IBL マルチスキャタ | Turquin スケール + `(1-DFG)` | **Fdez-Agüera 2019** | 二次以降を余弦照度で閉じる。ライトマップがその照度。直接光には使わない（論文自身が狭いライトでは近似が崩れると書く） |
| Specular AA クランプ | Filament \(\kappa=0.2\) | Tokuyoshi 2021 / Kaplanyan \(\kappa=0.18\) | 等方フォワード形は 2021 式 13。ハーフベクトル版はライト数に比例するのでワールドでは使わない |

金属 Fresnel の F82-tint（OpenPBR 1.0 でも変更なし）、Heitz 相関 Smith、Karis 解析 DFG、Lagarde spec AO、Jimenez マルチバウンス AO は、2025 年のコースでも置換先が無いので残しています。

## 見たが積まない

| 候補 | 年 | 見送り理由 |
| --- | --- | --- |
| Hammon GGX+Smith 拡散 | 2017 | 同じマイクロファセットから拡散を出す点では Burley より一貫する。2024 以降の標準は EON。Quest で両方は持たない |
| Heitz 確率的マルチスキャタ GGX | 2016 | 正確だが確率評価。リアルタイム Forward に不適 |
| Kulla–Conty 追加ローブ + 複数 LUT | 2017 | パス用。リアルタイムは Turquin スケールか Fdez-Agüera |
| Belcour Fresnel 分解 | 2020 | F82 より導体曲線は良いが追加基底 / LUT。OpenPBR は F82 を選んだ |
| Hirvonen EnvBRDF | コミュニティ実装 | 公開一次資料の係数を確認できず。Karis/Lazarov を維持 |
| SH exponential glossy IBL | HPG 2025 | カスタムプローブ表現。Unity キューブマップを置換できない |
| Neural / MLP BRDF | 2025–2026 | ウェイトと学習データがワールド配布に乗らない |
| Tokuyoshi 2021 ハーフベクトル投影空間フィルタ | 2021 | ライト毎。IBL・ライトマップ・LTCGI には効かない |
| Filament bent-normal spec AO | 製品 | ベント法線ベイクが VRC の標準パイプラインに無い |
| OpenPBR coat_darkening / fuzz / iridescence / thin-film / SSS | 1.0 | ワールド全面の既定にしない。コートは既存の \((1-F_c)\) 減衰だけ |
| Charlie sheen / dual-lobe GGX / 異方性 GGX | 各種 | 布・ヘア・ブラシ金属のヒーロー用。壁床の命令数に入れない |
| GT7 トーンマップ、蛍光、ヘア Strand | SIGGRAPH 2025 | 表面 BRDF ではない、またはアバター領域 |

## いまも標準のままのもの

- **NDF**: GGX / Trowbridge–Reitz（Walter 2007）。GTR / Student-t はエンジン既定になっていない。
- **可視**: Height-correlated Smith（Heitz 2014）。Quest は Hammon 2017 Fast。
- **ラフネス**: \(\alpha=p^2\)（Burley のパラメータ化だけ残す）。
- **電媒体 F0**: \(0.16 r^2\)（Filament / glTF）。
- **エリアライト**: LTC（Heitz 2016）を LTCGI パッケージ経由。自前コピーしない。
- **ベイク**: Bakery MonoSH + Unity ライトマップ。フル SH/RNM はクラブ向けの VRAM コスト。

## 直接光と IBL でモデルを分ける理由

Fdez-Agüera は「二次散乱の入射は半球にほぼ一様」と置く。ライトマップとプローブはその仮定に近い。平行光やポイントライトは逆なので、直接鏡面は Turquin のローブスケールに留める。EON も直接拡散だけ。IBL 拡散は論文 Listing 2 の \(k_D\) で、余弦照度に乗せる。
