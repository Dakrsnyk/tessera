# Entraînement sur Kaggle (chantier 22.3) : mode d'emploi pas à pas

Deux carnets Kaggle refont sur un GPU gratuit ce que `scripts/ml/` fait sur le CPU de l'ordinateur :

| Carnet | Ce qu'il fait | Durée attendue sur un GPU T4 (estimation, voir § 5) |
|---|---|---|
| `classifier/ardane-classifier.ipynb` | recadrages, vecteurs DINOv2-S/14 gelé, tête étalonnée (**voie A**, identique à la chaîne CPU) ; puis **variante B** : derniers blocs de DINOv2 affinés avec augmentations ; rapport Top-1 / Top-3 / ECE sur le TEST officiel ; export Core ML fp16 + int8 des deux variantes | 2 à 3 h |
| `segmenter/ardane-segmenter.ipynb` | affinage de **RF-DETR-Seg Nano** (puis **Small**) sur les annotations d'instances de MyFoodRepo ; mAP de masque, IoU / Dice par aliment ; export ONNX et tentative d'export Core ML | Nano : 6 à 9 h ; Small : 10 à 12 h (hypothèses, le carnet MESURE le débit réel avant de s'engager) |

Les carnets sont **générés** à partir du code de `scripts/ml/` (`python scripts/ml/kaggle/build_notebooks.py`) : le code y est embarqué avec son empreinte SHA-256, aucun clone Git n'est nécessaire sur Kaggle. Ne pas les modifier à la main.

> **État au 2026-11-02 : jamais exécutés sur Kaggle.** Ce qui est PROUVÉ en local (CPU, jeu factice, sous WSL) : voir § 8. Les durées Kaggle de ce document sont des estimations, pas des mesures.

## 1. Vérifier le compte Kaggle par téléphone (OBLIGATOIRE)

Sans cela, **ni le GPU ni Internet ne peuvent être activés** dans un carnet (les deux sont nécessaires : le GPU pour l'entraînement, Internet pour télécharger DINOv2, RF-DETR et coremltools).

1. kaggle.com › photo de profil › **Settings** › section **Phone Verification** › « Verify » : entrer le numéro, saisir le code reçu par SMS.
2. Contrôle : dans un carnet, le menu « Session options » (ou le panneau « Settings ») doit proposer **Accelerator › GPU** et l'interrupteur **Internet**. Si ces choix sont grisés, la vérification n'est pas terminée.

## 2. Voie simple : par l'interface web (aucun outil à installer)

1. kaggle.com › **Code** › **New Notebook**.
2. Dans le carnet : **File › Import Notebook** › choisir `scripts/ml/kaggle/classifier/ardane-classifier.ipynb` (ou `segmenter/ardane-segmenter.ipynb`).
3. Panneau de droite, **Input › Add Input** (selon la version de l'interface : « Add Data ») › chercher **`food-recognition-2022-dataset`** (auteur `awsaf49`, MyFoodRepo v2.0) › **Add**.
4. **Settings › Accelerator** › **GPU T4 x2** (le P100 a été retiré par Kaggle ; le carnet n'utilise qu'un GPU). **Settings › Internet** › **On**.
5. **Save Version › Save & Run All (Commit)**. Le carnet tourne seul, sans fenêtre ouverte ; on peut fermer l'onglet.
6. Quand la version est terminée : onglet **Output** de la version › **Download All**. Déposer le contenu dans **`C:\Users\Etudiant\ardane-tools\ml\kaggle-outputs\classifier\`** (ou `...\segmenter\`). Ouvrir `RESULTS.md` (ou `RESULTS-segmenter.md`) d'abord.

Le journal du carnet (onglet Logs) montre chaque étape ; les durées réelles sont dans `RESULTS.md`.

## 3. Voie automatique (recommandée) : jeton API Kaggle

Le client `kaggle` (v2.2.5) est installé dans `C:\Users\Etudiant\ardane-tools\kaggle-venv`. Il lit le jeton dans `C:\Users\Etudiant\.kaggle\kaggle.json` ; **l'assistant ne lit, n'affiche ni ne copie jamais ce fichier**.

**Créer le jeton (une fois, à faire soi-même)** : kaggle.com › photo de profil › **Settings › API › Create New Token** › le fichier `kaggle.json` se télécharge › le placer **soi-même** dans `C:\Users\Etudiant\.kaggle\kaggle.json`. (Fait le 2026-11-02 : le client voit le compte, `kaggle quota` répond.) Le jeton donne accès au compte : ne jamais le coller dans un message, un fichier du dépôt ni un carnet.

Commandes (PowerShell ; `$K` raccourcit le chemin du client) :

```powershell
$K = "C:\Users\Etudiant\ardane-tools\kaggle-venv\Scripts\kaggle.exe"
cd C:\Users\Etudiant\Documents\GitHub\tessera\scripts\ml\kaggle

& $K quota                                           # heures de GPU restantes cette semaine (30 h par semaine)
& $K kernels push -p classifier --accelerator NvidiaTeslaT4   # envoie le carnet ET le lance (l'équivalent de « Save & Run All »)
& $K kernels status darksnyk/ardane-food-classifier  # running / complete / error
& $K kernels logs darksnyk/ardane-food-classifier    # journal du dernier passage
& $K kernels output darksnyk/ardane-food-classifier -p C:\Users\Etudiant\ardane-tools\ml\kaggle-outputs\classifier   # télécharge la sortie
# même chose pour le segmenteur : -p segmenter, darksnyk/ardane-food-segmenter, ...\kaggle-outputs\segmenter
```

Les fichiers `classifier/kernel-metadata.json` et `segmenter/kernel-metadata.json` fixent : carnet privé, GPU T4, Internet activé, jeu d'entrée `awsaf49/food-recognition-2022-dataset`, image logicielle « originale » (épinglée : les versions de torch ne changent pas d'un passage à l'autre, utile pour la reprise). Le nom d'utilisateur (`darksnyk`) est dans le champ `id` : le changer si le compte change. `--no-run` enregistre sans lancer ; `-t SECONDES` limite la durée.

## 4. Quota, durée maximale, et ce qui se passe si la session coupe

- **Quota GPU : 30 h par semaine** (constaté le 2026-11-02 avec `kaggle quota` : 30,00 h, renouvelé le 2026-11-07 à 00:00 UTC). Le compteur de Kaggle compte le temps des sessions avec accélérateur (règle de la plateforme, à confirmer en relançant `kaggle quota` avant et après un passage). Un passage du classifieur coûte environ 2 à 3 h ; le segmenteur Nano 6 à 9 h (hypothèse) : le budget d'une semaine peut contenir classifieur + Nano, pas forcément Small en plus.
- **Durée maximale d'une session : 12 h** (GPU). Les carnets s'imposent un **budget interne** de 11 h (12 h moins 1 h de réserve, réglable) : avant chaque époque, ils vérifient qu'elle tient dans le temps restant, sinon ils **s'arrêtent proprement** : le point de sauvegarde est écrit, la sortie est complète et téléchargeable, et `RESULTS.md` / `RESULTS-segmenter.md` disent « en PAUSE ». Aucune perte.
- **Si Kaggle coupait quand même la session** (panne, limite dépassée, arrêt manuel) : dans une session interactive, `/kaggle/working` reste lisible tant que la session vit ; pour un « Save & Run All » interrompu, on ne peut pas compter sur la sortie de cette version (comportement non vérifié ici). C'est pourquoi le budget interne arrête les carnets AVANT la limite, avec une sortie complète.
- **Où vivent les données** : les recadrages (≈ 3 Go) et les caches sont dans `/kaggle/temp` (non conservés, refaits en quelques minutes si besoin) ; tout ce qui doit survivre est dans `/kaggle/working` : `models/` (zips des `.mlpackage`), `reports/`, `weights/`, `logs/`, `ardane_state/` (reprise), `RESULTS*.md`, `class_map.csv`, `classes.json`.

### Reprendre après une pause ou une coupure

Les étapes terminées sont marquées dans `ardane_state/stages.json` ; le carnet relancé les saute et reprend là où il en était (classifieur : à l'époque suivante de l'affinage B ; segmenteur : depuis `last.ckpt`, avec le même nombre d'époques).

**Manœuvre (UNE fois par reprise)** : il faut que la nouvelle session voie le dossier `ardane_state/` de la précédente.

*Par l'interface* : ouvrir la version terminée du carnet › onglet **Output** › **New Dataset** (crée un jeu privé à partir de la sortie, ex. `ardane-classifier-state`) › dans le carnet, **Add Input** › ce jeu › **Save & Run All**. Le carnet cherche tout dossier `ardane_state/` sous `/kaggle/input` (jeu de données ou sortie de carnet, jusqu'à 4 niveaux) et prend le plus récent.

*Par le client* (non vérifié de bout en bout, à contrôler au premier usage : le jeu créé doit montrer `ardane_state/stages.json`) :

```powershell
& $K kernels output darksnyk/ardane-food-segmenter -p C:\Users\Etudiant\ardane-tools\ml\kaggle-outputs\segmenter
# ne garder QUE le dossier ardane_state dans un dossier d'envoi, puis :
mkdir C:\Users\Etudiant\ardane-tools\ml\kaggle-state\segmenter
robocopy C:\Users\Etudiant\ardane-tools\ml\kaggle-outputs\segmenter\ardane_state C:\Users\Etudiant\ardane-tools\ml\kaggle-state\segmenter\ardane_state /E
& $K datasets init -p C:\Users\Etudiant\ardane-tools\ml\kaggle-state\segmenter          # puis éditer dataset-metadata.json (title, id darksnyk/ardane-seg-state)
& $K datasets create -p C:\Users\Etudiant\ardane-tools\ml\kaggle-state\segmenter -r zip # privé par défaut ; « -r zip » envoie le dossier en archive
# ajouter "darksnyk/ardane-seg-state" à dataset_sources dans segmenter/kernel-metadata.json, puis : & $K kernels push -p segmenter
```

Le carnet affiche au début `[reprise] état restauré depuis ...` et la liste des étapes terminées : c'est le contrôle que la manœuvre a marché. Sans cette ligne, le carnet repart de zéro (sans danger, mais sans reprise).

## 5. Durées attendues sur un T4 (ce sont des ESTIMATIONS)

Aucun carnet n'a tourné sur Kaggle : ces chiffres viennent de calculs de débit et des mesures faites sur le CPU local (voir `scripts/ml/README.md`), pas de Kaggle. Chaque carnet écrit les durées réelles dans `RESULTS*.md`.

| Étape | Estimation T4 (4 CPU, 29 Go) | Base du calcul |
|---|---|---|
| Préparation (empreintes de 41 000 photos, ≈ 100 000 recadrages) | 15 à 30 min | 133 empreintes/s et 450 recadrages/s mesurés sur le CPU local à 8 threads, deux fois moins de coeurs |
| Vecteurs DINOv2-S gelé sur GPU (fp32) | 5 à 10 min | ≈ 12 Gflop par image, T4 à 4 Tflop/s effectifs ; contre 3 h sur le CPU local (9,7 img/s mesurées) |
| Têtes A (linéaire + MLP) et rapports | 3 à 15 min | calcul CPU, tête de 768 x 498 |
| Export Core ML A (fp16 + int8) | 5 à 10 min | 1 min mesuré sous WSL sur le jeu factice + 3 min d'installation de l'environnement d'export |
| **Affinage B** (6 blocs, 10 époques au plus, ≈ 85 000 recadrages) | 40 à 60 min | 300 à 400 img/s à l'entraînement, 3 à 5 min par époque, arrêt anticipé possible |
| Vecteurs affinés + tête + export B | 15 à 25 min | idem A |
| **Total classifieur** | **≈ 2 à 3 h** | quota : 2 à 3 h sur 30 h |
| Segmenteur Nano : une époque (≈ 33 000 images à 312 px, lot 16 + validation de 1 500 images) | 15 à 35 min | HYPOTHÈSE ; mesurée par le carnet (cellule « mesure du débit », ≈ 10 min) avant l'entraînement |
| Segmenteur Small : une époque (384 px) | 25 à 50 min | HYPOTHÈSE, idem |
| Évaluation + exports (par taille) | 20 à 40 min | 1 000 images de test, exports ONNX / Core ML |

**Budget d'heures du segmenteur** (le carnet le calcule avec la mesure réelle) : `époques = min(15, budget en secondes / (1,1 x durée mesurée d'une époque))` où `budget = temps de session restant − 45 min (évaluation + exports)`. Avec ≈ 25 min par époque, Nano tient ≈ 15 époques en ≈ 6,5 h ; Small, 8 à 12 époques par session. Une taille qui ne tient pas au moins 4 époques est SAUTÉE avec un message clair (pas de demi-entraînement inutile) : relancer alors une session consacrée à cette taille (`SIZES = ["small"]`).
**Mode mesure seule** : `BENCH_ONLY = True` (cellule 2 du segmenteur) mesure le débit et s'arrête (≈ 20 min de GPU) : recommandé avant de s'engager sur 6 h.

## 6. Ce que contient la sortie, et quoi en faire

**Classifieur** (`C:\Users\Etudiant\ardane-tools\ml\kaggle-outputs\classifier\`) :
- `RESULTS.md` : Top-1 (intervalle de Wilson), Top-3, ECE, NLL de A, A-MLP et B sur le TEST officiel ; validation (sert à CHOISIR) ; déroulement de l'affinage ; durées ; empreintes des fichiers.
- `models/*.mlpackage.zip` : `ArdaneFoodClassifier-{fp16,int8}` (A) et `ArdaneFoodClassifierB-{fp16,int8}` (B), + `models/A|B/` (`*.classes.json`, `ATTRIBUTIONS.txt`, `*.export.json`). Même interface que la chaîne CPU : entrée `image` 224 x 224 RGB 0..255, sorties `probabilities` (étalonnées) et `embedding` (768).
- `weights/` : têtes `.pt` et `fake-B-finetuned-backbone.pt` / `myfoodrepo-B-finetuned-backbone.pt` (DINOv2 affiné) pour **ré-exporter sans réentraîner** : `python export_coreml.py --dataset myfoodrepo-B --head head-linear.pt --backbone-weights <fichier>` (WSL ou macOS, voir `scripts/ml/README.md` § 4).
- `reports/` (rapports complets de `train_head.py`), `class_map.csv` + `classes.json` (indices et correspondance Ardane, **à relire** : cru/cuit, variante, plat composé), `logs/`, `ardane_state/`.

**Segmenteur** (`...\kaggle-outputs\segmenter\`) : `RESULTS-segmenter.md`, `segmenter-nano.md` (+ `.json`), `models/segmenter-nano/` (point de contrôle `rf-detr-seg-nano-myfoodrepo.pth`, `epochs.jsonl`, `export/` : ONNX, Core ML s'il a réussi, `export-report.json`).

**Ensuite, sur l'ordinateur** : (1) lire `RESULTS.md` ; (2) si B est meilleur que A **sur la validation**, retenir B ; (3) parité PyTorch / Core ML : `parity_coreml.py` ne tourne que sous macOS (runner de la CI, voir `scripts/ml/README.md` § 5, non ajouté au workflow sans accord) ; (4) intégrer dans l'app **seulement** après relecture de `class_map.csv`, mesure sur les repas pesés (chantier 22.6) et affichage de l'attribution (CC BY 4.0, Apache 2.0). Rien n'est livré par ces carnets.

## 7. Le segmenteur : licence, export Core ML (tentative), limites

- **Licence** (vérifiée le 2026-11-02, README du dépôt `roboflow/rf-detr`, branche `develop`, commit `091ab7f`, section « License » ; paquet `rfdetr` 1.11.2 publié le 2026-10-04, `License: Apache License 2.0`) : « RF-DETR-Seg, every size (Nano through 2XLarge) : **Apache 2.0** » ; le paquet `rfdetr` (entraînement, inférence, export) : Apache 2.0. **Nano** et **Small** sont donc utilisables commercialement. Les modèles « Plus » (Atto, Femto, Pico, XL, 2XL de détection, NAS) sont sous licence PML 1.0 et ne sont pas utilisés. Poids de départ : `rf-detr-seg-n-ft.pth` / `rf-detr-seg-s-ft.pth` (entraînés sur COCO, hébergés par Roboflow sur storage.googleapis.com/rfdetr) ; à mentionner : « RF-DETR (Roboflow), Apache 2.0, DINOv2 (Meta), Apache 2.0 ».
- **Export Core ML : il FONCTIONNE en essai local** (et la recherche du 2026-11-02, `Recherche-modeles.md`, qui disait « pas d'export Core ML de la tête de segmentation », est donc **dépassée**). `rfdetr` 1.11.2 propose `model.export(format="coreml")` (`torch.export` + `coremltools` 9, marqué « expérimental »). Essai fait le 2026-11-02 sous WSL (CPU, torch 2.7.0, coremltools 9.0) sur un RF-DETR-Seg **Nano** entraîné 2 époques sur le jeu FACTICE (11 classes) : ONNX **OK** (117,0 Mo) ; Core ML fp16 **OK** (58,9 Mo, 52 s) ; Core ML fp32 **OK** (117,0 Mo) ; quantification int8 des poids du fp16 **OK** (31,2 Mo). Interface du Core ML (lue dans le `.mlpackage`, sans le charger) : entrée `tensors` [1, 3, 312, 312] float32 (un TENSEUR, pas une image Core ML : normalisation ImageNet et redimensionnement à faire côté Swift) ; sorties à lire PAR POSITION : boîtes [1, 100, 4], logits de classes [1, 100, C+1] (C classes + 1 emplacement « aucun objet »), logits de masques [1, 100, 78, 78] (= 312 / 4). Le carnet refait cet essai sur Kaggle avec les 498 classes et consigne le résultat exact (réussite ou erreur précise) dans `export-report.json`. **Non prouvé** : la prédiction et la parité numérique PyTorch / Core ML (macOS seulement), la vitesse et la mémoire sur iPhone 11 Pro, l'ouverture dans Xcode, le décodage Swift des masques (à écrire), l'export de Small. Ne rien livrer avant cette mesure.
- **Mesures** : mAP de masque COCO (protocole standard, pycocotools) ; IoU et Dice moyens par aliment avec les définitions de `Tests/Support/ScanMetrics.swift` (`seg_metrics.py`, mêmes cas limites : un raté vaut 0, deux masques vides ou de tailles différentes donnent « indéfini », jamais 0 ; les valeurs de `Tests/ScanMetricsTests.swift` sont rejouées au démarrage du carnet). L'appariement aliment réel / prédiction (glouton, un pour un, IoU >= 0,1, sans tenir compte de la classe, seuil de confiance 0,30) est fixé d'avance, pas réglé sur le test.
- **Pas de fuite** : la découpe train / validation et le retrait des photos quasi identiques viennent de `prepare_myfoodrepo.py` (mêmes groupes que le classifieur). Le TEST officiel = TOUTES les images du « validation 2.0 » ; il sert uniquement à mesurer. Le meilleur point de contrôle est choisi sur la validation (mAP de masque).

## 8. Ce qui a été prouvé en local, et ce qui ne l'est pas

Essais faits le 2026-11-02 sous WSL (Ubuntu 24.04, CPU, torch 2.7.0, coremltools 9.0, `rfdetr` 1.11.2), sur le jeu **factice** de `make_fake_coco.py` (formes colorées, classes inventées : aucun chiffre n'est une précision) :

- **Classifieur** : `python smoke_run_classifier.py --work <dossier>` exécute les 12 cellules de code du `.ipynb` (préparation, vecteurs, têtes linéaire et MLP, export Core ML fp16 + int8 de A, affinage B, vecteurs affinés, tête, export de B, rapport) en **8 min 30 s** sur CPU (jeu factice : 271 recadrages) ; sortie : `RESULTS.md`, 4 zips `.mlpackage` (fp16 41,4 Mo, int8 20,9 Mo comme sur la chaîne CPU), `ardane_state/`. **Reprise** : une 2e session qui reçoit `ardane_state/` comme jeu d'entrée saute les 7 étapes et reproduit `RESULTS.md`, les zips et les poids en **6 s** ; l'affinage B interrompu par le budget puis repris donne exactement les mêmes pertes que l'exécution continue. Un `state_dict` modifié passé à `--backbone-weights` change bien les sorties du modèle (écart 16,2) et un `state_dict` incomplet est refusé. La syntaxe de tout le code embarqué est vérifiée avec Python 3.11 (image Kaggle probable), les cellules avec `python -m py_compile`, le `.ipynb` avec `nbformat`. Le mécanisme d'installation de l'environnement d'export (`pip install --target`, torch 2.7.0+cpu + coremltools 9.0) a été vérifié sous WSL : 119 s, 941 Mo, les modules de la cible passent devant ceux de l'environnement.
- **Segmenteur** : `python smoke_run_segmenter.py --work <dossier> --notebook` exécute les 7 cellules de code du `.ipynb` sur le jeu factice (CPU, RF-DETR-Seg Nano réel, poids COCO téléchargés) en **12 min** : préparation des photos, jeu au format RF-DETR, **mesure du débit** (0,12 img/s sur ce CPU : sans signification pour un GPU, mais le calcul de l'époque estimée et du nombre d'époques fonctionne), entraînement 2 époques, évaluation (mAP COCO de masque et de boîte, IoU / Dice par aliment, latence), exports ONNX + Core ML fp16 / fp32 + int8, rapports. Sans `--notebook`, le même script appelle les fonctions une à une et vérifie en plus l'**arrêt par budget** (pause après l'époque 1, `last.ckpt` écrit) puis la **reprise** (exactement 1 époque restante). Les cas de `Tests/ScanMetricsTests.swift` (IoU, Dice, Wilson, percentile) sont rejoués en Python et passent.
- **Non prouvé** : toute exécution sur Kaggle (GPU T4, Internet du carnet, image logicielle, quotas, durées, interface), la précision réelle sur MyFoodRepo (aucun chiffre de qualité n'existe encore : les rapports factices sont marqués comme tels), la parité Core ML (macOS), la manœuvre de reprise par jeu de données côté interface Kaggle (la logique de reprise est prouvée, pas le transport via Kaggle), l'installation de l'environnement d'export dans l'image Kaggle (prouvée sous WSL / Ubuntu 24.04 / Python 3.12 ; l'image Kaggle peut avoir un autre Python), les débits GPU (hypothèses du § 5).

**Rejouer les essais** (sous WSL ; `$env:WSL_UTF8=1` dans PowerShell pour lire les sorties) :

```powershell
# classifieur : venv /root/ardane-ml/venv (torch 2.7.0 CPU + coremltools 9.0, voir scripts/ml/README.md § 4) ; TORCH_HOME = cache DINOv2 déjà téléchargé
wsl -d Ubuntu-24.04 -u root -- bash -lc "cd /mnt/c/Users/Etudiant/Documents/GitHub/tessera/scripts/ml/kaggle && . /root/ardane-ml/venv/bin/activate && export TORCH_HOME=/root/ardane-ml/smoke-torch-home PYTHONDONTWRITEBYTECODE=1 && python -B smoke_run_classifier.py --work /root/ardane-ml/smoke/clf"
# segmenteur : venv /root/ardane-ml/venv-seg = torch 2.7.0 + torchvision 0.22.0 (CPU) + rfdetr[train]==1.11.2 + coremltools==9.0 + numpy<2.3 + onnx onnxsim onnxruntime onnx_graphsurgeon polygraphy
wsl -d Ubuntu-24.04 -u root -- bash -lc "cd /mnt/c/Users/Etudiant/Documents/GitHub/tessera/scripts/ml/kaggle && . /root/ardane-ml/venv-seg/bin/activate && export PYTHONDONTWRITEBYTECODE=1 RF_HOME=/root/ardane-ml/rf-home && python -B smoke_run_segmenter.py --work /root/ardane-ml/smoke/seg --notebook"
```

Ne PAS lancer ces essais pendant que la chaîne CPU de `scripts/ml/` tourne : ils occupent tous les coeurs pendant 6 à 15 minutes.

## 9. Régénérer, vérifier, dépanner

- `python scripts/ml/kaggle/build_notebooks.py` régénère les `.ipynb` après toute modification de `scripts/ml/` ; `--check` échoue si un carnet n'est plus à jour ; `--py311 <python3.11>` vérifie la syntaxe pour l'image Kaggle. Les `kernel-metadata.json` ne sont jamais réécrits.
- « Aucun GPU » : Settings › Accelerator n'est pas sur GPU, ou le compte n'est pas vérifié (§ 1). « no kernel image » : choisir « GPU T4 x2 ».
- L'export Core ML échoue : le carnet continue et le dit dans `RESULTS.md` ; refaire l'export sous WSL avec les fichiers de `weights/` (commande au § 6).
- Le jeu `food-recognition-2022-dataset` est introuvable : vérifier l'étape « Add Input » (§ 2.3) ; le carnet cherche `annotations.json` sous `/kaggle/input` dans des dossiers dont le nom contient « train » et « val ».
- Rappel : ne jamais téléverser de photo de repas de l'utilisateur sur Kaggle ; ces carnets n'utilisent que MyFoodRepo (CC BY 4.0).

## 10. Fichiers

| Fichier | Rôle |
|---|---|
| `build_notebooks.py` | génère les `.ipynb` (code de `scripts/ml/` embarqué + empreinte) |
| `kaggle_common.py` | chemins, budget de temps, reprise, journaux, export, zips (stdlib seulement) |
| `classifier/notebook_cells.py`, `finetune_dinov2.py`, `classifier_report.py` | cellules, affinage partiel de DINOv2 (variante B), rapport `RESULTS.md` |
| `segmenter/notebook_cells.py`, `seg_dataset.py`, `seg_train.py`, `seg_eval.py`, `seg_export.py`, `seg_metrics.py` | cellules, jeu au format RF-DETR, entraînement / mesure du débit / reprise, évaluation, exports, port Python de `ScanMetrics.swift` |
| `smoke_run_classifier.py`, `smoke_run_segmenter.py` | essais de fumée locaux (jeu factice) |
| `classifier/kernel-metadata.json`, `segmenter/kernel-metadata.json` | réglages `kaggle kernels push` |

Options ajoutées à `scripts/ml/` pour ces carnets (toutes facultatives, comportement par défaut inchangé) : `extract_features.py --device/--amp/--backbone-weights`, `export_coreml.py --backbone-weights`, `parity_coreml.py --backbone-weights`, `prepare_myfoodrepo.py --skip-class-map`, `ml_common.load_dinov2_backbone(weights_path=...)`, et dans `train_head.py` : métriques de validation dans le JSON du rapport et mention « AFFINÉ » dans le rapport.
