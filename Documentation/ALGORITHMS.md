# BestWorld アルゴリズム導出

一次資料から組み立てた式と、BestWorld が採用した実装の対応表です。材質 BRDF は論文・仕様・Filament 公開ドキュメントから再実装しています。0.4.0 のワールド照明（距離ラフネス、ZH3、Shadowmask 三次、Volumes の L2 復帰、LTCGI の生 UV1）は出荷シェーダーを読んだうえで、公開式だけを再実装しています。ソース転載はありません。

記号: \(n\) 法線、\(v\) 視線、\(l\) 光線、\(h = \mathrm{normalize}(v+l)\)。\(\alpha\) は線形ラフネス、\(p\) は知覚ラフネス（アーティスト値）。\(\langle x \rangle = \max(x,0)\)。

## 1. レンダリング方程式

反射のみの表面では

\[
L_o(v) = L_e + \int_\Omega f(v,l)\, L_i(l)\, \langle n\cdot l\rangle\, dl
\]

\(f\) を拡散と鏡面に分けます。

\[
f = f_d + f_r
\]

点光源では積分が和になり、減衰 \(a\) を掛けます。

\[
L_o \leftarrow L_o + (f_d + f_r)\, E\, a\, \langle n\cdot l\rangle
\]

\(E\) はライトの入射照度（Unity では `_LightColor0`）。

## 2. 材質パラメータ

glTF / Filament の metallic-roughness。

- 知覚ラフネス \(p \in [0,1]\)。線形ラフネス \(\alpha = p^2\)（Burley 2012）。\(\alpha\) を直接スライダーにするとハイライト幅が知覚的に線形でない。
- 電介体 F0: Filament は reflectance \(r\)（既定 0.5）から

\[
F_{0,\mathrm{diel}} = 0.16\, r^2
\]

\(r=0.5\) で \(F_0=0.04\)。これは IOR 1.5 の空気–電介体界面に対応します。

\[
F_0 = \frac{(1-1.5)^2}{(1+1.5)^2} = 0.04
\]

- 金属: \(F_0 =\) albedo、拡散色は 0。
- 混合:

\[
c_{\mathrm{diff}} = (1-m)\, c_{\mathrm{base}},\qquad F_0 = (1-m)\, F_{0,\mathrm{diel}} + m\, c_{\mathrm{base}}
\]

ORM packed map: R=AO、G=roughness \(p\)、B=metallic \(m\)。

## 3. マイクロファセット鏡面（Cook–Torrance）

\[
f_r(v,l) = \frac{D(h)\, G(v,l)\, F(v,h)}{4\,(n\cdot v)\,(n\cdot l)}
= D(h)\, V(v,l)\, F(v,h)
\]

可視項 \(V = G / (4\,(n\cdot v)\,(n\cdot l))\) を直接持つと、後で \(\langle n\cdot l\rangle\) をレンダリング方程式側で掛けても分母と打ち消し合いません。\(V\) はすでに \(4(n\cdot v)(n\cdot l)\) を含みます。

### 3.1 D: GGX / Trowbridge–Reitz（Walter 2007）

\[
D_{\mathrm{GGX}}(h,\alpha) = \frac{\alpha^2}{\pi\bigl((n\cdot h)^2(\alpha^2-1)+1\bigr)^2}
\]

実装形（Filament と同値）:

\[
f = (n\cdot h)(\alpha^2-1)(n\cdot h)+1,\qquad D = \frac{\alpha^2}{\pi f^2}
\]

\(\alpha\to 0\) でデルタ関数に近づくので \(\alpha \ge 0.002\) にクランプします。Quest は mediump 相殺を避ける Filament 形 \(1-(n\cdot h)^2 = \|n\times h\|^2\) です。

### 3.2 V: Height-correlated Smith GGX（Heitz 2014）

\[
V = \frac{0.5}{(n\cdot l)\sqrt{(n\cdot v)^2(1-\alpha^2)+\alpha^2} + (n\cdot v)\sqrt{(n\cdot l)^2(1-\alpha^2)+\alpha^2}}
\]

Quest では Hammon 2017 の一次近似（Filament `V_SmithGGXCorrelated_Fast`）:

\[
V_{\mathrm{fast}} = \frac{0.5}{(1-\alpha)\,2(n\cdot l)(n\cdot v) + \alpha\bigl((n\cdot l)+(n\cdot v)\bigr)}
\]

つまり `lerp(2 NoL NoV, NoL+NoV, α)` の逆数の半分。これは \(G/(4\,NoV\,NoL)\) です。Schlick G1 の積を 4 で割っただけの形は、分子の \(NoV\,NoL\) が残るので **誤り** です。初版の `G1*G1/4` はここで直し済みです。

### 3.3 F: Schlick（1994）と F82-tint（OpenPBR / Kutz 2021）

Schlick:

\[
F(\mu) = F_0 + (F_{90}-F_0)(1-\mu)^5,\qquad \mu = h\cdot v
\]

Filament は \(F_{90}=\mathrm{saturate}(\langle F_0,\,(50\cdot 0.33,50\cdot 0.33,50\cdot 0.33)\rangle)\) を電介体ローブに使います。輝度近似で、典型的な \(F_0=0.04\) では \(F_{90}=1\) になります。\(F_0\) が極端に暗い（スペキュラオクルージョンを F0 に焼いた）面では grazing も落ちます。金属ローブは OpenPBR の F82-tint で、その中の Schlick は \(F_{90}=1\) です。

導体のシルエット付近（約 82°、\(\bar\mu=1/7\)）は Schlick より反射が落ちます。OpenPBR:

\[
F_{82}(\mu)=F_{\mathrm{Schlick}}(\mu)-\frac{\mu(1-\mu)^6}{\bar\mu(1-\bar\mu)^6}\bigl(F_{\mathrm{Schlick}}(\bar\mu)-F(\bar\mu)\bigr)
\]

\[
F(\bar\mu)=\mathtt{specular\_color}\, F_{\mathrm{Schlick}}(\bar\mu)
\]

`specular_color = 1` なら補正項は 0 で Schlick に戻ります。電介体ローブには掛けず、金属側だけ使います。

## 4. 拡散

Lambert（参照のみ。Quest では使わない）:

\[
f_d = \frac{c_{\mathrm{diff}}}{\pi}
\]

Quest は Fujii FON の単散乱（EON の \(f_{\mathrm{ss}}\)）。PC は OpenPBR 1.1 の **EON**（Portsmouth, Kutz, Hill 2024/2025）。Fujii の FON 単散乱に、Kulla–Conty 型の相互的マルチスキャタを足します。ラフネス \(r\in[0,1]\) は OpenPBR の `base_diffuse_roughness`。ワールドではスライダー1本なので知覚ラフネス \(p\) を入れます（OpenPBR の既定 0 にはしない。理由は SURVEY）。

\[
A = \frac{1}{1+c_1 r},\qquad
s = l\cdot v - (n\cdot l)(n\cdot v),\qquad
\frac{s}{t} = \begin{cases}s/\max(n\cdot l,\,n\cdot v) & s>0\\ s & \text{otherwise}\end{cases}
\]

\[
f_{\mathrm{ss}} = \frac{\rho}{\pi} A\bigl(1 + r\,\tfrac{s}{t}\bigr)
\]

Quest はここで止めます。PC はマルチスキャタを足します。

\[
f_{\mathrm{ms}} = \frac{\rho_{\mathrm{ms}}}{\pi}\frac{(1-\hat E_i)(1-\hat E_o)}{1-\langle\hat E\rangle},\qquad
\rho_{\mathrm{ms}} = \frac{\rho^2\langle\hat E\rangle}{1-\rho(1-\langle\hat E\rangle)}
\]

\(\hat E\) は論文 Listing 1 の \(E_{\mathrm{FON}}\) 近似（誤差 < 0.1%、`acos` なし）。\(r\to 0\) で Lambert に戻ります。金属は \(\rho=0\) なので拡散は消えます。

Burley 2012 は Filament の既定でしたが、炉試験でエネルギーを失い、OpenPBR / SIGGRAPH 2025 の業界標準は EON です。

### 4.1 レイヤ結合（OpenPBR 1.1 式 41）

Glossy-diffuse は電介体界面の上に拡散基板です。Albedo-scaling:

\[
f = f_{\mathrm{spec}} + \bigl(1-E_{\mathrm{spec}}(\omega_o)\bigr)\, f_{\mathrm{diffuse}}
\]

\(E_{\mathrm{spec}}(\omega_o)\) は Karis DFG で \(F_0\cdot\mathrm{DFG}_x+\mathrm{DFG}_y\)。マイクロファセット Fresnel \(F(h\cdot v)\) ではありません。EON は grazing で明るくなるので、Burley 向けに \((1-F)\) を省略した Filament の慣習はここでは誤りです。IBL の \(k_D\) と同じ量です。

## 5. マルチスキャタ補償

単散乱 GGX はラフな面でエネルギーを失います。

**直接光**は Turquin / Lagarde 2018（Filament）。狭い解析ライトには Fdez-Agüera の「残りは拡散照度」近似が合いません。

\[
f = f_{ss}\Bigl(1 + F_0\bigl(\tfrac{1}{r}-1\bigr)\Bigr)
\]

LUT がないので Karis の解析 DFG を \(r \approx \mathrm{DFG}_y\) として使います。\(b\) が小さいと \(1/b\) が発散するので下限を切ります。

**IBL**は Fdez-Agüera 2019。ワールドの主照明はライトマップ照度なので、ここの近似が本領です。式は §8。

## 6. 幾何スペキュラ AA（Tokuyoshi–Kaplanyan 2021 + Vlachos 2015）

スクリーン空間の法線微分から NDF をぼかします。2021 の等方フォワード形（式 13）は Filament 2019 と同じ形で、クランプ \(\kappa=0.18\) です。ワールドは IBL / ライトマップが主なので、ライト毎のハーフベクトルフィルタより法線ベースが合います。

\[
\mathrm{var} = \sigma^2\bigl(\|\partial_x n\|^2 + \|\partial_y n\|^2\bigr)
\]

\[
\alpha'^2 = \mathrm{saturate}(\alpha^2 + \min(2\,\mathrm{var},\,\kappa))
\]

戻す知覚ラフネスは \(\sqrt{\alpha'}\)（\(\alpha'=\sqrt{\alpha'^2}\) のあと \(p=\sqrt{\alpha}\)）。\(\sigma^2=0.15\)、\(\kappa=0.18\)。

VR では画素立体角が大きく、密メッシュは法線マップが無くても火花が出ます（Tokuyoshi 2021 が HMD を明示）。幾何法線に Vlachos GDC 2015 のフロアを足します。

\[
p \leftarrow \max\bigl(p,\; \mathrm{saturate}(\max(\|\partial_x n_g\|^2,\|\partial_y n_g\|^2))^{1/3}\bigr)
\]

Quest はこの幾何フロアだけです。PC はさらに、MSAA がシルエットで法線を外挿するのを避けるため **centroid 補間の幾何法線** に切り替えます（長さ² ≥ 1.01）。

## 7. オクルージョン

### 7.1 Specular AO（Lagarde, Moving Frostbite to PBR, 2014）

\[
\mathrm{specAO} = \mathrm{saturate}\bigl((n\cdot v + vis)^{2^{-16\alpha-1}} - 1 + vis\bigr)
\]

実装は `pow(NoV + vis, exp2(-16 α - 1))`。指数は \(2^{-16\alpha-1}\) であり、底を \(NoV+vis\) にした \(-16\alpha-1\) 乗ではない。

\(\alpha\) は線形ラフネス。AO マップと、ベイク照度の輝度を visibility の代理にします（暗いライトマップは IBL を殺す。Filamented の exposure occlusion と同じ目的）。

### 7.2 Multi-bounce AO（Jimenez 2016）

\[
\mathrm{GTAO}(vis, c) = \max\bigl(vis,\; ((vis\, a + b)vis + c)vis\bigr)
\]

係数 \(a,b,c\) は論文の RGB 二次フィット。\(c\) には拡散色を入れます。

### 7.3 Horizon occlusion（Lagarde / Frostbite）

幾何法線の下半球へ向かう反射は地面に吸われます。

\[
h = \min(1 + R\cdot n_g, 1),\qquad \mathrm{IBL}\times h^2
\]

### 7.4 Micro-shadowing（Chan / Filament）

AO を小さな開口と見なし、入射が開口の外なら消します。

\[
\mathrm{micro} = \mathrm{saturate}(n\cdot l + 2\,vis^2 - 1)
\]

そのあと \(E\, a\, (n\cdot l)\, \mathrm{micro}\) を掛けます。`micro` は \(n\cdot l\) を含まないので、\(n\cdot l\) との積は二重ではありません。

## 8. IBL（Karis split-sum + Fdez-Agüera 2019）

単散乱は Karis の split-sum です。

\[
\int f_r L_i \langle n\cdot l\rangle \approx \underbrace{\int L_i D_{\mathrm{GGX}}\,dl}_{\text{prefiltered cubemap}} \cdot \underbrace{\int f_r\langle n\cdot l\rangle dl}_{\mathrm{DFG}(p,n\cdot v)}
\]

Karis 解析 DFG: \(\mathrm{EnvBRDF}(p, n\cdot v) \approx (s, b)\)。IBL のフレネルは Fdez-Agüera Listing 2 のラフネス依存 Schlick です。

\[
k_S = F_0 + \bigl(\max(1-p, F_0)-F_0\bigr)(1-n\cdot v)^5
\]

\[
F_{ss}E_{ss} = k_S s + b
\]

マルチスキャタは二次以降を余弦照度（ライトマップ / SH）で近似します。狭い点光源には使いません。

\[
E_{ss}=s+b,\quad E_{ms}=1-E_{ss},\quad F_{\mathrm{avg}}=F_0+\tfrac{1-F_0}{21}
\]

\[
F_{ms}=\frac{F_{ss}E_{ss}\,F_{\mathrm{avg}}}{1-E_{ms}F_{\mathrm{avg}}}
\]

\[
L = F_{ss}E_{ss}\,L_{\mathrm{cube}} + (F_{ms}E_{ms}+k_D)\,E_{\mathrm{irradiance}}
\]

\[
k_D = c_{\mathrm{diff}}\bigl(1-(F_{ss}E_{ss}+F_{ms}E_{ms})\bigr)
\]

炉試験で金属・電介体ともエネルギーが保たれます。滑らかな金属の IBL は F82（\(n\cdot v\)）、ラフな金属は Fdez のラフネス依存 grazing に戻します。DFG LUT が無いので、完全な F82 スプリットサムではありません。

Unity のキューブマップは BIRP のフィルタに合わせてミップを切ります。`Unity_GlossyEnvironment` は線形 \(p\cdot\mathrm{LOD}\) ではなく

\[
p' = p(1.7-0.7p),\qquad \mathrm{mip} = p'\cdot \mathrm{UNITY\_SPECCUBE\_LOD\_STEPS}
\]

です。Box projection は Unity `BoxProjectedCubemapDirection`。

PC ではさらに Frostbite / HDRP の距離ラフネスを **ミップだけ** に掛けます（Lagarde 2014 §4.10.2）。AABB との交点まで距離 \(t\)、交点からプローブ中心まで \(d\) として

\[
p_{\mathrm{mip}} = \mathrm{lerp}\bigl(\mathrm{clamp}(\tfrac{t}{d}\,p,\,0,\,p),\, p,\, p\bigr)
\]

\(p=0\) の鏡面は鏡のままです。Fdez の DFG / \(k_D\) はシェーディングラフネスのままなので、部屋の大きさでエネルギーが変わりません。ブレンドする 2 プローブはそれぞれ自分の \(t,d\) とミップを持ちます。Quest は Unity のボックス投影だけです。

## 9. Clearcoat

OpenPBR の既定 IOR は **1.6**。

\[
F_{0,c}=\left(\frac{1-1.6}{1+1.6}\right)^2 \approx 0.053
\]

可視は Kelemen 2001:

\[
V_c = \frac{1}{4\,(l\cdot h)^2}
\]

ベースは albedo-scaling \((1-F_c)\) で減衰し、コート GGX を足します。加えて内部反射の暗化（OpenPBR 1.1 式 76、白いコート \(T^2=1\)）:

\[
K = F_{0,c}+\frac{1-F_{0,c}}{21},\qquad
\Delta=\frac{1-K}{1-E_b K},\qquad
\mathrm{base}\times\mathrm{lerp}(1,\Delta,\,\delta\,w_c)
\]

\(\delta=\) `coat_darkening`（既定 1）。0 にすると暗化だけ相殺し、\((1-F_c)\) は残ります。IBL も同じ \(F_c(n\cdot v)\) と \(\Delta\)。

## 10. SH / プローブ

Unity の L0/L1:

\[
L_0 = (\mathtt{SHAr}.w,\;\mathtt{SHAg}.w,\;\mathtt{SHAb}.w)
\]

\[
L_{1r}=\mathtt{SHAr}.xyz,\quad \text{irradiance}_r = L_{0r} + L_{1r}\cdot n
\]

L2 は `ShadeSH9` が含むので、**ボリュームが無い**動的メッシュの拡散は `ShadeSH9`、スペキュラ用の優勢方向だけ L1 を使います。ZH3 を Unity プローブに重ねないのは、本物の L2 があるからです。

Light Volumes は L1 までです。PC では線形評価の代わりに ZH3 hallucination（Roughton et al., i3D 2024 §3.4.3）を使います。Unity / ボリュームの係数は余弦畳み込み済み（照度）なので、一度放射輝度へ戻してから曲線フィットし、L2 帯域の余弦スケール \(1/4\) を足します。

\[
L_{0}^{\mathrm{rad}} = 2\sqrt{\pi}\, L_0,\qquad L_{1}^{\mathrm{rad}} = \sqrt{3\pi}\, L_1
\]

\[
r = \frac{\|L_1^{\mathrm{rad}}\}{L_0^{\mathrm{rad}}},\qquad
c_2 = L_0^{\mathrm{rad}}\bigl(0.08\, r + 0.6\, r^2\bigr)
\]

\[
Y_2^0(z) = \sqrt{\frac{5}{16\pi}}(3z^2-1),\qquad z = \hat L_1\cdot n
\]

\[
E = L_0 + L_1\cdot n + \tfrac14 c_2\, Y_2^0(z)
\]

軸は RGB 別です。クラブのポイントライトはチャンネルで方向が違うので、論文の輝度軸よりこちらが合います。Quest は線形のままです。Geomerics は MonoSH 専用に残します（論文 Fig.6: 照度を盛りすぎる）。

## 11. ライトマップ

`DecodeLightmap` が RGBM / dLDR / HDR を線形に戻します。

### 11.1 Unity Dominant Direction

`DecodeDirectionalLightmap`:

\[
\mathrm{halfLambert} = n\cdot (d_{xyz}-0.5) + 0.5,\qquad E = E_0\cdot \frac{\mathrm{halfLambert}}{\max(d_w,\varepsilon)}
\]

\(d_w\) はベイク時の「平坦」ハーフランバートで、エネルギーを保存します。

### 11.2 Bakery MonoSH

追加マップ 1 枚に **単色 L1** を詰め、`unity_LightmapInd` 経由で送ります。標準シェーダーの Dominant Direction デコードではコントラストが合いません。

公開されている SH の復元（Bakery がフル SH で使うのと同じスケール）:

\[
nL_1 = 2d_{xyz}-1,\qquad L_1 = 2\, nL_1\, L_0
\]

線形:

\[
E = L_0 + (L_1\cdot n) = L_0\bigl(1 + 2\, nL_1\cdot n\bigr)
\]

初版の \(L_0(1+nL_1\cdot n)\) は係数 2 が欠けていました。

コントラストは Geomerics「Reconstructing Diffuse Lighting from Spherical Harmonic Data」の非線形 L1（輝度だけ評価して線形カラーに比を掛ける）。スペキュラの優勢方向は \(nL_1\)、フォーカスは \(\|nL_1\|\)。方向性が低いテクセルはラフネスを上げて面光源に近づけます。

### 11.3 Bicubic

Keys / GPU Gems 系の 4 タップ三次。**色マップと方向マップと Shadowmask** に掛けます。色だけ三次だと MonoSH のハイライトと Mixed の影縁がテクセル格子に戻ります。Quest ではバイリニアのままです。Shadowmask の三次は PC ForwardBase だけです（Add は距離減衰を Unity マクロに残す）。

Cutout の拡散だけ、弱い wrap \(\mathrm{saturate}((n\cdot l + 0.25)/1.25)\) を使います。葉カードの裏面用で、鏡面とシャドウは `saturate(n·l)` のままです。

## 12. Mixed lighting

- **Baked Indirect / Shadowmask**: リアルタイム主光 + ライトマップ GI。Shadowmask なら `min(realtime, bakedOcclusion)`。
- **Subtractive**: 直接光はベイク済み。リアルタイム影でライトマップを `unity_ShadowColor` へ混ぜ、主光 BRDF は足しません。

## 13. VRC Light Volumes

ボクセル L1 SH。API はパッケージ側。Point Light Volumes は `LightVolumeSH` / `LightVolumeAdditiveSH` が内部で足すので、こちらから二重に呼びません。

- ライトマップ無しかつ `_UdonLightVolumeEnabled>0`: `LightVolumeSH` がプローブの代わり。PC は ZH3 で評価。
- ライトマップ有りかつ有効: `LightVolumeAdditiveSH` だけを **加算**。ライトマップを置換しない。
- define はあるがシーンで無効: **`ShadeSH9`（L2 込み）**。`LightVolumeSH` のプローブ復帰は L1 だけなので使わない。

v3 をコンパイルしているときは `worldNormal` を渡します（ポイントライトの法線マスク）。

スペキュラは優勢 L1 方向でこちらの GGX / F82 / Turquin を使います。公式 `LightVolumeSpecularDominant` は Standard のフレネル前提なので呼びません。3 色 `LightVolumeSpecular` はアバター向けです。

Quest の GGX \(D\) は Filament の mediump 形 \(\|n\times h\|^2 = 1-(n\cdot h)^2\) です。`1-NoH^2` は GLES3 ハイライトで相殺します。

## 14. LTCGI

Heitz et al. 2016, Linearly Transformed Cosines。矩形ポリゴンのエリアライトを、クランプされた余弦ローブの線形変換で解析積分します。実装は `LTCGI.cginc` を include するだけです（ライセンス上コピーしない）。

`LTCGI_Contribution` の `lmuv` は **メッシュの生 UV1** です（PiMaker、Graphlit、Mochie）。`unity_LightmapST` で変換した座標を渡すと、アトラスされたライトマップでスクリーンのオクルージョンがずれます。拡散は照度として `diffuseColor` を掛けます。鏡面に F0 は掛けません。VRC のスクリーンは電介体 4% 反射ではなく、面光源として見えることが契約です。

## 15. 初版からの修正

| 箇所 | 問題 | 根拠 |
| --- | --- | --- |
| Quest 可視項 | Schlick G を 4 で割っただけ | Hammon / Filament `V_SmithGGXCorrelated_Fast` |
| Burley | 知覚ラフネスを渡していた | Filament は線形 \(\alpha\) |
| Specular AO | 知覚ラフネスを渡していた | Frostbite / Filament は線形 \(\alpha\) |
| Specular AA | \(p^2+k\) の平方根 | Tokuyoshi: \(\alpha^2+k\) |
| IBL mip | \(p\cdot\mathrm{LOD}\) | Unity `p(1.7-0.7p)` |
| MonoSH | \(1+n\cdot L_1\) | SH スケール \(1+2 n\cdot nL_1\) |
| 拡散 IBL | 鏡面 DFG を引いていなかった | split-sum のエネルギー |
| 露出オクルージョン | アドホック多項式 | Lagarde specAO + ベイク輝度 |
| 直接拡散 | Burley に \((1-F)\) を掛けていた | Filament: Burley が grazing を担う |
| 電介体 \(F_{90}\) | スカラー `dot(f0, 16.5)` | Filament: `dot(f0, vec3(50·0.33))` |
| PC 拡散（0.2.0） | Burley 2012 | OpenPBR EON 2024 |
| IBL エネルギー（0.2.0） | Turquin スケール + \((1-\mathrm{DFG})\) | Fdez-Agüera 2019 + ライトマップ照度 |
| Specular AA \(\kappa\) | 0.2 | Tokuyoshi 2021 / Kaplanyan 0.18 |
| 直接拡散（0.3.0） | EON を鏡面に加算 | OpenPBR 式 41: \(1-E_{\mathrm{spec}}(\omega_o)\) |
| Quest 拡散（0.3.0） | Lambert | FON 単散乱 |
| コート（0.3.0） | IOR 1.5、暗化なし | IOR 1.6 + \(\Delta\) |
| SAA（0.3.0） | PC シェーディング法線のみ | 幾何フロア + centroid + Quest 幾何 |
| 方向ライトマップ（0.3.0） | バイリニア | 色と同じ bicubic |
| IBL ボックス（0.4.0） | Unity 投影のみ | Frostbite 距離ラフネス（ミップ） |
| Volume L1（0.4.0） | 線形 | PC ZH3 hallucination |
| Volumes 無効フォールバック（0.4.0） | L1 プローブ | ShadeSH9 L2 |
| Shadowmask（0.4.0） | バイリニア | ライトマップと同じ bicubic |
| LTCGI UV（0.4.0） | 変換済み lightmap UV | 生 UV1（PiMaker 契約） |

## 16. 出典

- Walter et al. 2007, Microfacet Models for Refraction through Rough Surfaces
- Burley 2012, Physically-Based Shading at Disney（ラフネスの二乗。拡散ローブは EON に置換）
- Heitz 2014, Understanding the Masking-Shadowing Function
- Lagarde & de Rousiers 2014, Moving Frostbite to Physically Based Rendering
- Karis 2013, Real Shading in Unreal Engine 4
- Hammon 2017, PBR Diffuse Lighting for GGX+Smith Microsurfaces（可視項の高速形）
- Kulla & Conty 2017; Lagarde & Golubev 2018, energy compensation（直接光）
- Fdez-Agüera 2019, A Multiple-Scattering Microfacet Model for Real-Time IBL
- Jimenez et al. 2016, Practical Realtime Strategies for Accurate Indirect Occlusion
- Tokuyoshi & Kaplanyan 2019/2021, Geometric Specular Antialiasing
- Vlachos 2015, Advanced VR Rendering（centroid 法線、幾何ラフネスフロア）
- Kutz et al. 2021 / OpenPBR 1.1, F82-tint, coat_darkening, albedo-scaling
- Portsmouth, Kutz, Hill 2024/2025, EON: A practical energy-preserving rough diffuse BRDF
- Kutz 2025, OpenPBR: Novel Features and Implementation Details (arXiv:2512.23696)
- Heitz et al. 2016, Real-Time Polygonal-Light Shading with Linearly Transformed Cosines
- Geomerics, Reconstructing Diffuse Lighting from Spherical Harmonic Data
- Roughton, Sloan, Silvennoinen, Iwanicki, Shirley 2024, ZH3: Quadratic Zonal Harmonics (i3D)
- Lagarde & de Rousiers 2014, Moving Frostbite to PBR §4.10.2（距離ラフネス）
- Unity HDRP `ComputeDistanceBaseRoughness` / `IntersectRayAABBSimple`
- Google Filament PBR document and `surface_brdf.fs` / `surface_ambient_occlusion.fs` / `surface_shading_lit.fs`
- Unity `UnityImageBasedLighting.cginc`, `DecodeDirectionalLightmap`
- Bakery wiki (MonoSH) and published SH reconstruction scale
- RED_SIM, VRC Light Volumes For Shader Developers
- PiMaker, LTCGI For Shader Authors
