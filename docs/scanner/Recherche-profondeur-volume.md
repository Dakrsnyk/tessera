---
tags: [ardane, scanner, chantier-22, recherche]
---

# Recherche : estimation des quantités (profondeur, volume, densités), 2026-11-02

Chantier 22.1, volet quantités. Légende : [documenté] = Apple ou article cité · [constaté] = lu dans le dépôt ou mesuré sur des données du dépôt · [dérivé] = calcul à partir de chiffres sourcés · [supposé] = non sourcé, à mesurer.

## Verdict
1. Le LiDAR (iPhone 12 Pro à 17 Pro) donne une profondeur métrique mais peu résolue. Aucune étude validée du LiDAR iPhone sur des aliments n'a été trouvée. L'erreur dominante sera le décalage du plan de l'assiette multiplié par l'aire de l'aliment.
2. Sans LiDAR, aucune source de profondeur métrique n'existe sur l'appareil : la disparité double caméra est « relative » selon Apple, et la profondeur monoculaire utilisable (Depth Anything V2 Small) est relative.
3. Une profondeur relative sans échelle ne donne PAS de volume en cm³. Même mise à l'échelle, son erreur (AbsRel ≈ 5 %) est de l'ordre de l'épaisseur d'un plat (1 à 4 cm à 35 cm).
4. Une erreur d'échelle se propage au cube : une assiette supposée 10 % trop petite donne ≈ 33 % d'erreur de volume si la hauteur est mise à l'échelle avec elle [dérivé].
5. Densités : la base FAO/INFOODS v2.0 ne peut pas être embarquée sans autorisation écrite. Le fichier canadien déjà embarqué (FCÉN) contient des mesures ménagères en ml avec leur masse : densités apparentes pour 2 314 aliments sur 5 596 [constaté].
6. Les meilleures erreurs publiées (12 à 19 %) viennent de conditions de laboratoire. Les humains estiment à 41–53 % d'erreur (Nutrition5k).
7. Recommandation : socle universel par référence d'assiette, puis LiDAR en option expérimentale validée sur appareil.

## 1. API Apple et appareils
| Élément | Fait | Statut |
|---|---|---|
| `ARFrame.sceneDepth` | iOS 14+, à activer par `frameSemantics` `.sceneDepth`, vérifier `supportsFrameSemantics` | [documenté] |
| `ARDepthData` | `depthMap` (mètres) + `confidenceMap` (low/medium/high) ; la précision « dépend fortement » de la confiance | [documenté] |
| `smoothedSceneDepth` | moyenne sur plusieurs images | [documenté] |
| Résolution | plus petite que l'image, même rapport d'aspect, 60 Hz ; « 256×192 » absent des pages Apple lues ; non réglable (forum) | [documenté]/[forum] |
| Portée | ≤ 5,0 m (exemple Apple) | [documenté] |
| Précision | Apple ne publie aucun chiffre ; ni distance minimale ni précision à 20–60 cm | [documenté] : absence |
| Surfaces | réfléchissantes ou absorbantes : confiance basse (WWDC20 10611) | [documenté] |
| Intrinsèques | `ARCamera.intrinsics` à mettre à l'échelle de la carte de profondeur | [documenté]/[dérivé] |
| Image haute résolution | `captureHighResolutionFrame` (iOS 16), trame avec profondeur | [documenté] |
| Plans | `ARWorldTrackingConfiguration`, `planeDetection`, classification `.table` | [documenté] |
| AVFoundation LiDAR | `builtInLiDARDepthCamera` iOS 15.4, `DepthFloat16`, sans chiffre de précision | [documenté] |
| Disparité double caméra | 1/m, précision `.relative` ; TrueDepth `.absolute` (caméra avant) | [documenté] |
| Object Capture iOS | iOS 17, détail « reduced », iPhone 12 Pro+, minutes de calcul, capture autour d'un objet | [documenté] |
| Metal | inutile (≈ 49 000 échantillons se traitent sur CPU) | [dérivé] |

iPhone avec LiDAR (Apple) : 12 Pro/Pro Max à 17 Pro/Pro Max. Part de marché : aucune source ; ordre de grandeur un tiers à la moitié des iPhone actifs [supposé]. **La voie sans LiDAR est la voie principale.**
Précision LiDAR hors alimentation : ±1 cm sur objets > 10 cm (Luetzenburg 2021) ; biais 0,9–9,3 cm à l'échelle d'une pièce (SAE 2021) ; RMSE intérieur 1,4–3,9 cm ; une revue de 2026 juge la résolution du LiDAR mobile « souvent insuffisante pour l'évaluation alimentaire ».

## 2. Sans LiDAR
| Modèle | Sortie | Licence | Taille / vitesse | Remarque |
|---|---|---|---|---|
| Depth Anything V2 Small (Core ML d'Apple) | profondeur inverse relative, invariante à l'affine | Apache-2.0 | 24,8 M param., 49,8 Mo F16 ; 31–34 ms sur Neural Engine | AbsRel 0,053 sur NYU après alignement |
| DA V2 Base/Large/Giant | relative | CC-BY-NC-4.0 | | exclus (commercial) |
| DA V2 « metric » | métrique, entraînée en synthétique | non précisée | | fragile hors domaine |
| Depth Pro (Apple) | métrique | licence « sample code » Apple, muette sur le commerce | ~1 Md param., 0,7–1,8 Go | trop lourd |
| Depth Anything 3 | DA3-Small/Base Apache-2.0 ; DA3METRIC-LARGE Apache-2.0 | | | à surveiller, non validé sur nourriture |
| MiDaS | relative | MIT | | |
| ZoeDepth | métrique | MIT | | dépôt archivé |
| Metric3D v2 | métrique | code BSD-2, poids non précisés | | |
| UniDepth | métrique | CC BY-NC 4.0 | | exclu |

La profondeur relative DA V2 a échelle ET décalage inconnus : il faut DEUX contraintes métriques. Aucune validation d'un modèle monoculaire sur un plat à 30–50 cm.
Fixer l'échelle : mouvement ARKit (précision à courte distance non sourcée) ; carte bancaire ou pièce (GoCARB : carte + 2 images) ; diamètre d'assiette choisi (≈ 10,7 % contre 6,7 % avec marqueur, Jia 2021, à recouper) ; vaisselle enregistrée une fois (meilleure option [supposé]) ; la main : aucune source solide.
Multi-vues : VolE (1–3 % mais vidéo 360°, COLMAP, 5–9 min sur RTX 3090 : impossible sur l'appareil) ; Object Capture : hors sujet ; SfM maison : à écarter.

## 3. Volume et précisions publiées
Méthodes : carte de hauteur sur le plan de l'assiette ; maillage/voxels ; enveloppe convexe (surestime) ; régression apprise des grammes.
- **Nutrition5k** (CVPR 2021, CC BY 4.0, 5 066 assiettes pesées à ±1 g, cafétérias californiennes, montage fixe au-dessus) : erreur moyenne en % — RGB calories 26,1 / masse 18,8 ; RGB-D 18,8 / 18,9 ; RGB + volume par profondeur 16,5 / 13,7 ; composition par gramme seule 9,5. Nutritionnistes 41 %, non-nutritionnistes 53 %.
- **Herzig 2020** (iPhone X, lumière structurée, 48 repas / 128 aliments pesés) : masse 14,0 %, énergie 12,7 %, glucides 14,8 %, lipides 12,3 %, protéines 13,0 %, 22,9 s.
- **Vinod 2024** (référence physique, 45 aliments) : 17,67 % en kcal.
- **GoCARB** : volume 9,4 % ; glucides comparables aux diététistes ; difficultés riz, pâtes, pommes de terre.
- LiDAR iPhone sur tas réguliers (pas de nourriture) : 0,6–1,9 %, 4,5 % sable irrégulier [secondaire]. **Aucune étude LiDAR iPhone sur repas** trouvée.
- Densité : poids USDA contre mesurés : calories significativement différentes pour une part importante des aliments (Partridge 2018).
Limites géométriques : surplombs (surestimation), parties derrière un tas (sous-estimation), sauces dans les creux, liquides et verre brillant, huiles et ingrédients cachés : invisibles.

## 4. Densités
- FAO/INFOODS v2.0 (638 entrées, surtout boissons, poudres, plats mixtes) : « tous droits réservés », usage commercial soumis à accord : **ne pas embarquer sans accord écrit** (copyright@fao.org).
- **FCÉN embarqué** [constaté] : 2 314 aliments avec mesure en ml et masse (ex. spaghetti cuit 0,59 g/ml ; riz blanc vapeur cuit 0,56 ; mesclun 0,25 ; bœuf haché émietté 0,49–0,52 ; purée 0,89). Valeurs aberrantes (0,02 et 18,36) : bornes et filtres obligatoires (0,15–2,0 g/ml proposé). Licence gouvernement ouvert Canada.
- USDA FoodData Central : domaine public / CC0 ; poids de portion par tasse [supposé : fichier exact à vérifier].
- USDA Table of Cooking Yields (2014) : viandes et volailles seulement ; une assiette servie est déjà cuite : choisir l'entrée cuite.
- Sans densité fiable : loi log-normale large (σ_log ≈ 0,25–0,35 [supposé]), jamais une valeur ponctuelle ; remplacée par la valeur personnelle dès correction.

## 5. Comparaison
| Méthode | Erreur attendue | Vitesse | Appareils | Complexité | Expérience |
|---|---|---|---|---|---|
| Portion usuelle (existant) | ±30–40 % posé à la main, jamais mesuré ; humains 41–53 % | instantané | tous | faible | simple |
| Assiette choisie + aire du masque + épaisseur type | [supposé] 35–50 % ; erreur d'aire ≈ 2 × erreur de diamètre | ~1 s | tous | moyenne | 1 réglage mémorisé |
| Monoculaire + référence | labo 17,7 % (Vinod), 18,8 % (Nutrition5k RGB) ; hors domaine inconnu | ~1 s | tous | haute | carte à poser |
| Multi-vues | labo 1–3 %, GPU, minutes | minutes | non faisable sur l'appareil | très haute | 360° |
| Deux images + carte (GoCARB) | volume 9,4 % | quelques s | tous | haute | carte, 2 prises |
| LiDAR (carte de hauteur) | iPhone X lumière structurée 12,7–14 % (Herzig) ; LiDAR sur repas non publié, [supposé] 15–30 % | 2–3 s | iPhone Pro | moyenne | tenir 1–2 s |
Plancher d'erreur [dérivé] : volume 12 %, densité 15 %, composition 10 % en quadrature ≈ 22 % pour l'énergie, plus en vie réelle.

## Options et recommandation
- **B. Assiette/référence + aire du masque + épaisseur type + calibrage personnel (tous iPhone)** : SOCLE UNIVERSEL. Couvre tous les appareils, erreurs explicables, réutilise Vision et `ScanLearning`, aucune dépendance. Effort moyen.
- **A. LiDAR en carte de hauteur (iPhone Pro)** : seule mesure métrique native, sans modèle, local ; résolution faible, non validé sur nourriture, minorité d'appareils. MODE EXPÉRIMENTAL désactivé, activé seulement après mesure instrumentée (objets de volume connu, puis 20–30 repas pesés). Effort élevé.
- **C. Profondeur monoculaire (DA V2 Small)** : écartée comme source de volume (relative, erreur de l'ordre de l'épaisseur d'un plat, aucune validation sur plats). Éventuellement plus tard comme indice de forme (plat ou tas), seulement si une mesure montre un gain.

## Algorithme recommandé
**A. LiDAR (expérimental, derrière un interrupteur)**
1. `supportsFrameSemantics(.smoothedSceneDepth)` ; `ARWorldTrackingConfiguration` alignée gravité, `planeDetection = [.horizontal]`, `frameSemantics = [.smoothedSceneDepth]`.
2. Pose stable ; moyenne de 10–20 cartes ; `captureHighResolutionFrame` pour le RGB.
3. Dépliage P = z · ((u − cx)/fx, (v − cy)/fy, 1), intrinsèques à l'échelle de la carte ; confiances moyenne/haute seulement ; repère monde.
4. Plan : normale = gravité (±5°), décalage par médiane des hauteurs de l'anneau d'assiette hors aliments.
5. Carte de hauteur (cellules 2–3 mm), V_k = Σ max(h − h0, 0) · ΔA sur le masque de chaque aliment.
6. m_k = V_k · ρ_k, ρ_k log-normale.
7. σ_V² ≈ (A_k · σ_plan)² + (A_k · σ_bruit / √n)² + (V_k · σ_bord)² (valeurs initiales fixées par mesure, jamais inventées).
8. kcal déterministe ; s² = s_V² + s_ρ² ; intervalle à 90 % = [m · e^(−1,645 s), m · e^(+1,645 s)] ; recalage par prédiction conforme sur repas pesés (Angelopoulos & Bates, arXiv 2107.07511).
9. Repli sur B si confiance faible, assiette non trouvée, hauteur < 3 mm, liquide/verre, fond non plan.

**B. Sans LiDAR**
1. Photo + inclinaison (CoreMotion) + focale (EXIF ou intrinsèques).
2. Redressement par homographie de rotation H = K R K⁻¹ vers une vue verticale (valable pour tout le plan) ; échelle uniforme.
3. Échelle : ellipse de l'assiette ; distance = f · D / D_px avec D = diamètre choisi (20/24/27 cm mémorisé) ou carte/pièce/vaisselle enregistrée.
4. Aire A_k = N_px · (distance/f)² ; erreur relative d'aire = 2 × erreur du diamètre.
5. Épaisseur type h_k par aliment et état (log-normale), valeurs initiales prudentes marquées « à mesurer », puis apprises par correction (facteur personnel avec rétrécissement vers 1).
6. m_k = A_k · h_k · ρ_k ; s² = (2 s_D)² + s_h² + s_ρ² ; intervalle comme en A, recalé sur repas pesés.
7. Bols et soupes : ne pas prétendre mesurer ; demander la taille du bol et le niveau de remplissage.

**C. Repli** : portions Petite/Moyenne/Grande (mesures de la FCÉN), médiane des corrections (`ScanLearning`), fourchette large, message honnête sur ce qui est hors portée (huiles, sauces, ingrédients cachés).

## Ce qui ne peut pas marcher
Profondeur relative sans échelle = pas de cm³ ; une seule contrainte métrique ne suffit pas ; disparité double caméra relative ; volume ∝ échelle³ ; précision LiDAR à 20–60 cm non documentée ; Nutrition5k non démontré sur iPhone tenu à la main ; géométrie seule = jamais les huiles, sauces, sucre ou ingrédients cachés ; photogrammétrie trop lente ; modèles non commerciaux exclus.

## Sources
Apple : documentation ARKit (`sceneDepth`, `ARDepthData`, `ARConfidenceLevel`, `smoothedSceneDepth`, `ARCamera.intrinsics`, « Displaying a point cloud using scene depth », `captureHighResolutionFrame`, `ARWorldTrackingConfiguration`, `ARPlaneAnchor.Classification`), AVFoundation (`builtInLiDARDepthCamera`, « Capturing depth using the LiDAR camera », `AVDepthData`, accuracy, « Capturing photos with depth », `AVCaptureDepthDataOutput`), RealityKit (`PhotogrammetrySession`), WWDC17 507, WWDC20 10611, WWDC23 10191, forum 650321, page « Models with a LiDAR Scanner ».
Modèles : huggingface.co/apple/coreml-depth-anything-v2-small ; github.com/DepthAnything/Depth-Anything-V2 ; arxiv.org/html/2406.09414 ; github.com/apple/ml-depth-pro ; github.com/ByteDance-Seed/Depth-Anything-3 ; github.com/isl-org/MiDaS ; github.com/isl-org/ZoeDepth ; github.com/YvanYin/Metric3D ; github.com/lpiccinelli-eth/UniDepth.
Précisions : arXiv 2103.03375 (Nutrition5k) et github.com/google-research-datasets/nutrition5k ; Herzig 2020 (opus.bibliothek.uni-augsburg.de) ; arXiv 2404.12257 ; arXiv 2505.10205 ; Frontiers in Nutrition 2025 (10.3389/fnut.2025.1501946) ; PMC6024682 (GoCARB) ; arXiv 2602.05078 ; arXiv 2310.14437.
LiDAR hors alimentation : pub.geus.dk (iPhone 12 Pro LiDAR) ; SAE 2021-01-0891 ; Geodetski vestnik 68/2.
Densités : fao.org/docrep/017/ap815e/ap815e.pdf ; fao.org/infoods ; fdc.nal.usda.gov ; USDA Cooking Yields Meat & Poultry ; Nutrients 10(8):973 (Partridge 2018) ; arXiv 2107.07511.

## Incertitudes
Précision réelle du LiDAR iPhone à 30–50 cm sur nourriture : aucune étude ; distance minimale non documentée. Échelle ARKit sans LiDAR à courte distance : non sourcée. Parts d'appareils LiDAR : aucun chiffre fiable. Licences à valider : Depth Pro, poids de Metric3D, DA V2 « metric ». Chiffres « goFOOD 27–31 % » et « Jia 10,73 % » à recouper. Les écarts-types initiaux (densité, épaisseur, plan) sont des hypothèses à remplacer par des mesures.
