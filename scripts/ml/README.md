# Chaîne d'entraînement du classifieur d'aliments (chantier 22.3, jalon A)

Objectif : entraîner NOUS-MÊMES un classifieur d'aliments (DINOv2 ViT-S/14 gelé + une petite tête) sur des recadrages de
MyFoodRepo, puis l'intégrer déjà entraîné dans l'app sous forme de modèle Core ML. Aucune API, aucune photo envoyée nulle part.
Choix et licences : `docs/scanner/Decision-technique.md` et `docs/scanner/Recherche-modeles.md`.

Rien de lourd n'est dans le dépôt : ni données, ni poids, ni vecteurs. Tout vit sous `C:\Users\Etudiant\ardane-tools\ml\`
(variable `ARDANE_ML_ROOT` pour changer d'endroit).

```
AIcrowd (MyFoodRepo, CC BY 4.0)        raw/myfoodrepo/{train,val}/  (annotations.json + images/)         --format coco
  ou copie Dataset Ninja (Supervisely)  <dossier>/meta.json + {train,val,test}/{img,ann}/             --format supervisely
  └ prepare_myfoodrepo.py  ──►  work/myfoodrepo/{crops/, crops.csv, classes.json, class_stats.csv, meta.json}
                                scripts/ml/class_map.csv   (classe MyFoodRepo -> identifiant d'aliment Ardane, À RELIRE)
  └ extract_features.py    ──►  work/myfoodrepo/features/{train,val,test}.X.npy   (DINOv2 gelé, CPU, reprise possible)
  └ train_head.py          ──►  models/myfoodrepo/head-linear.pt  +  reports/classifier-<date>.md
  └ export_coreml.py       ──►  models/myfoodrepo/export/ArdaneFoodClassifier-fp16.mlpackage  (Linux, WSL ou macOS)
  └ parity_coreml.py       ──►  écart PyTorch / Core ML (macOS seulement : runner de la CI)
```

Fichiers : `ml_common.py` (source de vérité : modèle de base, normalisation, recadrage), `class_matching.py` (appariement
des noms), `extract_archive.py` (extraction sûre d'un zip non fiable), `sly_format.py` (lecture d'un projet Supervisely), `coreml_dryrun.py` (conversion à blanc sous Windows sans natives), `make_fake_coco.py` + `selftest_fake_chain.py` (jeu FACTICE
et auto-test de bout en bout), `requirements-train.txt`, `requirements-export.txt`.

## 1. Ce que TU fais (une seule fois) : récupérer MyFoodRepo

**Voie réellement suivie le 2026-11-02 (voie C)** : AIcrowd (erreur 500) et le lien Dropbox de Dataset Ninja étant indisponibles, l'utilisateur a téléchargé la
copie Kaggle `awsaf49/food-recognition-2022-dataset` (MyFoodRepo version 2.0, COCO, 498 classes) : `archive.zip`, 2 575 509 790 octets, SHA-256
`234564b1cdb2b6782ba52e8fb31ecdb7494c26cc9e4618086986277546f42204`, posée dans `ml\data\myfoodrepo\`. Extraction sûre (empreinte vérifiée avant, chemins absolus,
`..`, lecteurs et liens refusés, CRC contrôlés ; le jeu de test public SANS annotations n'est pas extrait) :

```powershell
C:\Users\Etudiant\ardane-tools\venv\Scripts\python.exe -I scripts\ml\extract_archive.py --zip C:\Users\Etudiant\ardane-tools\ml\data\myfoodrepo\archive.zip --out C:\Users\Etudiant\ardane-tools\ml\raw\myfoodrepo --sha256 234564b1cdb2b6782ba52e8fb31ecdb7494c26cc9e4618086986277546f42204 --map public_training_set_release_2.0=train --map public_validation_set_2.0=val --skip public_test_release_2.0
```

Preuve de licence archivée à côté des données (`raw\myfoodrepo\LICENCE-2026-11-02.txt`) et dans `docs/scanner/Licences-donnees-modeles.md` (CC BY 4.0 retenue ; Kaggle et Dataset Ninja affichent CC0).

Deux autres voies, au choix (même licence retenue, même sortie) :
- **voie A, archives AIcrowd** (COCO, version 2.1, 323 classes) : étapes A à F ci-dessous ; il faut un compte AIcrowd ;
- **voie B, copie Dataset Ninja** (format Supervisely, « Food Recognition 2022 » version 2.0, 498 classes) : section 1 bis ; aucun compte AIcrowd,
  téléchargement par le paquet `dataset-tools`.
Les noms de classes sont les mêmes slugs (`bread-white`...) ; la clé stable d'une classe est son NOM, pas son numéro.

**A. Créer le compte.** <https://www.aicrowd.com> > « Sign Up » (e-mail, ou connexion GitHub/Google), puis confirmer l'e-mail.

**B. Aller sur la bonne page.** Le « Food Recognition Benchmark 2022 » :
<https://www.aicrowd.com/challenges/food-recognition-benchmark-2022>, onglet « Dataset » (adresse directe :
`.../food-recognition-benchmark-2022/dataset_files`). Il faut se connecter ; AIcrowd demande en général de cliquer sur
« Participate » (accepter les règles du concours) avant d'activer les liens de téléchargement (non vérifié : la page publique ne le dit pas).

**C. Télécharger DEUX fichiers** (version 2.1, manche 2) :

| Fichier | Contenu | À prendre ? |
|---|---|---|
| `public_training_set_release_2.1.tar.gz` | 54 392 images, 100 256 annotations, 323 classes | **oui** |
| `public_validation_set_2.1.tar.gz` | 946 images, 1 708 annotations (COCO) | **oui** (devient notre jeu de TEST) |
| `public_test_release_2.1.tar.gz` | images sans annotations publiques | non |

Taille : la page ne l'indique pas ; compter 3 à 4 Go en tout (estimation, la v2.0 fait 2,4 Go chez Dataset Ninja).
Si les noms ont changé sur la page, prendre l'entraînement et la validation en format COCO ; le script s'adapte tant que les
dossiers ont la mise en page ci-dessous.

**D. Les déposer et les extraire** dans `C:\Users\Etudiant\ardane-tools\ml\raw\myfoodrepo\` (PowerShell, depuis ce dossier) :

```powershell
mkdir train, val
tar -xzf public_training_set_release_2.1.tar.gz -C train
tar -xzf public_validation_set_2.1.tar.gz -C val
```

Résultat attendu : `train\annotations.json`, `train\images\*.jpg`, `val\annotations.json`, `val\images\*.jpg`. Si l'archive ajoute
un dossier intermédiaire, remonter son contenu pour retrouver cette forme (ou me le dire : les chemins sont réglables par
`--train-json`, `--train-images`, `--val-json`, `--val-images`).

**E. Vérifier et ARCHIVER la licence (obligatoire avant toute livraison du modèle).**
1. Sur le site, relever la licence AFFICHÉE pour ces données. Au 2026-11-02, la page « Règles du concours »
   (`.../challenge_rules`, section 1 « Competition Description ») dit que le jeu « is released under the CC BY 4.0 License » ;
   la page « Dataset » publique n'affiche aucune licence ; un catalogue tiers (Dataset Ninja) dit CC0. On retient **CC BY 4.0** (attribution obligatoire).
2. Faire une capture d'écran (ou « Imprimer en PDF ») de la page des règles ET de la page du jeu de données, avec la date visible.
3. Créer `raw\myfoodrepo\LICENCE-AAAA-MM-JJ.txt` contenant : le texte exact de la licence, l'adresse de la page, la date, le nom du compte
   AIcrowd, et l'empreinte de chaque archive : `Get-FileHash .\public_training_set_release_2.1.tar.gz -Algorithm SHA256` (idem pour la validation).
4. Mettre les captures dans le même dossier (`LICENCE-AAAA-MM-JJ-regles.png`...).
Si on ne trouve AUCUNE licence claire pour le téléchargement lui-même : ne pas livrer de modèle, écrire à AIcrowd.
Le script le rappelle (« aucun fichier LICENCE* archivé ») et le rapport d'entraînement le répète.

**F. Me dire « MyFoodRepo est en place »** : j'enchaîne la section 2.

Obligations CC BY 4.0 : afficher l'attribution (« MyFoodRepo / AIcrowd, CC BY 4.0 », avec lien vers la licence) dans l'app
(Réglages > Licences) et ne pas redistribuer les données. Le texte est écrit dans `ATTRIBUTIONS.txt` à côté du modèle exporté.

## 1 bis. Format Supervisely (copie Dataset Ninja, voie B)

**État au 2026-11-02 : le lecteur est écrit et testé sur un petit projet FABRIQUÉ au même format (`make_fake_coco.py --supervisely`), PAS sur le vrai
téléchargement** (il n'était pas encore arrivé). Au premier vrai essai, lire attentivement le résumé affiché (jeux lus, objets rejetés par raison).

Mise en page attendue du projet Supervisely (celle que produit Dataset Ninja) :

```
<dossier>/meta.json                         classes : [{"id", "title", "shape", ...}]
<dossier>/train/img/<photo>.jpg             <dossier>/train/ann/<photo>.jpg.json   {"size": {...}, "objects": [...]}
<dossier>/val/...  <dossier>/test/...       (autres dossiers, ex. unlabeled : ignorés et listés)
```

```bash
$PY prepare_myfoodrepo.py --dataset myfoodrepo --format supervisely --sly-root /c/Users/Etudiant/ardane-tools/<dossier du téléchargement> --dataset-version 2.0
```

- `--sly-root` : le dossier qui contient `meta.json`, ou un dossier parent (jusqu'à trois niveaux plus haut). Défaut : `<racine>/raw/myfoodrepo-supervisely`.
- `--sly-map "nom_du_dossier=train,autre=val"` si les dossiers ne contiennent pas les mots `train`, `val`, `test`.
- Géométries lues : `polygon` (boîte de l'extérieur), `rectangle`, `bitmap` (PNG zlib + base64, masque = canal alpha d'un PNG RGBA, sinon valeurs non nulles,
  comme Supervisely ; la boîte est celle des pixels non nuls, décalée de `origin`). Autres géométries (point, ligne...) : rejetées et comptées.
- Classes : `classTitle` (repli : `classId` via `meta.json`). Les numéros de classe internes sont ATTRIBUÉS 1..N dans l'ordre alphabétique des titres
  (reproductible) ; l'indice du modèle suit aussi l'ordre alphabétique des NOMS, comme avec le COCO : un modèle entraîné d'un côté ou de l'autre a les
  mêmes étiquettes `mfr:<nom>`.
- Découpage : si `train`, `val` ET `test` portent des annotations, c'est le découpage officiel (train -> entraînement, val -> VALIDATION, test -> TEST) ;
  si seuls `train` et `val` en ont, `val` devient le TEST (comme avec AIcrowd) ; un jeu sans aucune instance utilisable (non annoté) est ignoré.
  Dans tous les cas, une photo quasi identique à une photo d'un jeu prioritaire (test > validation > entraînement) est retirée du jeu de moindre priorité.
- Les noms lisibles (`Bread, white`) n'existent pas dans Supervisely : l'appariement part du seul slug (formulations « réduites » moins sûres,
  marquées par un score plus bas) ; relire `class_map.csv` avec encore plus d'attention.
- Licence : on retient **CC BY 4.0** (règles du concours AIcrowd, preuve datée dans `docs/scanner/Licences-donnees-modeles.md`) même si Dataset Ninja affiche
  CC0 pour sa copie. Archiver `LICENCE-AAAA-MM-JJ.txt` (et captures de la page Dataset Ninja ET de la page des règles AIcrowd) À CÔTÉ des données,
  avec l'empreinte des fichiers téléchargés : le script cherche `LICENCE*` près des données et le consigne dans `meta.json`.
- Version : la copie Dataset Ninja est la v2.0 (39 962 + 1 000 + 3 000 images, 498 classes) ; les archives AIcrowd 2.1 ont 323 classes. Ne PAS mélanger les deux
  dans un même dossier de travail : un seul jeu à la fois (`--dataset` distincts pour comparer).

## 2. Commandes (le Chef)

Environnement d'entraînement : le venv Python 3.12 de `C:\Users\Etudiant\ardane-tools\venv` suffit (torch CPU, numpy, pillow ; aucun
autre paquet). Depuis `scripts/ml` :

```bash
PY=/c/Users/Etudiant/ardane-tools/venv/Scripts/python.exe
$PY prepare_myfoodrepo.py --dataset myfoodrepo --format coco --dataset-version 2.0 --license-note "<texte relevé>"   # 5,5 min mesurées pour 78 110 recadrages
#   -> contrôler scripts/ml/class_map.csv (TOUTES les lignes automatiques sont « a_relire = oui ») ET le résumé affiché
#   (la base d'aliments évolue : `prepare_myfoodrepo.py --dataset myfoodrepo --class-map-only` rafraîchit la seule table, lignes « manuel » conservées)
$PY extract_features.py --dataset myfoodrepo                                     # 2,7 h mesurées (7,9 img/s en moyenne), reprise possible (relancer la même commande)
$PY train_head.py --dataset myfoodrepo --head linear --tag essai-a                # 20 à 70 s ; plusieurs variantes à comparer SUR LA VALIDATION
$PY train_head.py --dataset myfoodrepo --head mlp --hidden 2048 --dropout 0.5 --lr 5e-4 --wd 5e-2 --label-smoothing 0.1 --note-file <choix.md>   # variante retenue : ~7 min
```

Export Core ML : sous WSL (commande exacte en section 4) ou sur macOS :

```bash
python export_coreml.py --dataset myfoodrepo --head head-linear.pt --version 0.1.0 --int8
```

Points d'attention :
- `prepare_myfoodrepo.py` lit le COCO (polygone > boîte), exclut les « foules » (iscrowd) et les instances de moins de 32 px, découpe un
  carré centré sur la boîte avec 10 % de marge de chaque côté (réglable : `--margin`, `--min-size`), à 224 x 224.
- **Pas de fuite** : on répartit les PHOTOS, jamais les recadrages ; le jeu `val` officiel devient le TEST ; la validation est prélevée dans
  `train` par groupes ; les photos quasi identiques (empreinte dHash, distance de Hamming <= 4) restent du même côté et toute photo
  d'entraînement quasi identique à une photo de test est retirée. Le résumé dit combien. Limite : sans identifiant de repas ou d'utilisateur
  dans les données, des photos différentes d'un même repas peuvent rester des deux côtés.
- `class_map.csv` : une ligne par classe MyFoodRepo, méthode d'appariement (`exact-en`, `exact-fr`, `synonyme-app` = mêmes synonymes que
  `FoodSynonyms`, `jetons-en`, `aucun`), score approximatif, trois alternatives, et `a_relire`. **Tout est à relire** par une personne
  (cru/cuit, variante, plat composé) ; une ligne corrigée à la main doit avoir `methode` = `manuel` : elle survit aux régénérations
  (`--remap` pour tout refaire). Les identifiants sont `builtin.<id>` (table intégrée), `cnf.<Food_Code>` (FCÉN 2026) et `usda.<NDB>` : le schéma est lu dans
  `pack_meta.id_scheme` de `App/Resources/ardane-food.sqlite` (la base fait foi : la consigne écrivait `cnf:<Food_Code>` avec deux points, la base écrit
  `cnf.<Food_Code>` avec un point ; à réconcilier côté app). Sans la base, on lit la FCÉN 2026 brute du dossier `food-data`. La base était
  encore en construction le 2026-11-02 : **relancer `prepare_myfoodrepo.py --no-crops` quand elle sera finale** pour rafraîchir la table (les lignes `manuel` sont conservées).
  Les classes sans équivalent gardent un identifiant vide.
- `extract_features.py --bench 256 --bench-threads 4,8` mesure le débit sans toucher au cache. Les lots portent l'empreinte de `crops.csv` : un
  nouveau découpage ne réutilise jamais d'anciens vecteurs.
- `train_head.py` : poids de classe n^-0,5 (réglable), arrêt anticipé sur la validation, étalonnage par température sur la validation,
  rapport sur le TEST (Top-1 et Top-3 avec intervalle de Wilson, par classe, paires confondues, ECE, exactitude selon la confiance). Le rapport
  est `reports/classifier-<date>.md` (suffixe `-fake` pour le jeu factice, `-<étiquette>` si `--tag`). **Il n'y a pas de chiffre de précision
  avant que ce rapport existe sur les vraies données**, et même alors c'est la précision sur des recadrages suisses annotés, pas sur des repas de l'iPhone.

## 3. Espace disque et temps (estimations ; [mesuré] = sur CE PC)

| Élément | Taille |
|---|---|
| Archives AIcrowd (à garder pour la licence/les empreintes, effaçables ensuite) | 3 à 4 Go (estimation) |
| Images extraites | 3 à 4 Go |
| Recadrages 224 x 224 (JPEG q95), ~100 000 | 2,5 à 3 Go (estimation ; 10 Ko pièce sur le jeu factice lisse) |
| Vecteurs (768 flottants x 100 000) + lots de reprise | 0,3 Go + 0,3 Go |
| Poids DINOv2 officiel + code de torch.hub | 0,09 Go [mesuré] |
| Modèle Core ML fp16 / int8 | **RÉEL (498 classes, tête MLP 2048) : 48 613 345 octets (46,4 Mio) / 24 571 924 octets (23,4 Mio)** ; jeu factice (11 classes, tête minuscule) : 43 418 898 / 21 953 892 octets [mesurés sur de vrais `.mlpackage` écrits sous WSL, section 4] |
| **Total** | **environ 12 Go** (79 Go libres au 2026-11-02) |

Temps (CPU Intel i5-1135G7, 4 coeurs / 8 threads, sans GPU) :
- extraction DINOv2-S/14 : **9,5 à 9,9 images/s [mesuré le 2026-11-02, machine peu chargée]**, 4 threads de calcul, décodage JPEG inclus (Windows, torch 2.14.1 : 9,5 ;
  WSL, torch 2.7.0 : 9,9 ; 8 threads ne vont pas plus vite : 8,3), soit **environ 2,9 h pour 100 000 recadrages**. Quand la machine est saturée par d'autres
  traitements lourds (rendus vidéo, ffmpeg), le débit tombe à 2 à 4 images/s [mesuré] : 8 à 13 h. À lancer la nuit, sans autre traitement lourd. La reprise est automatique.
- préparation : 15 à 30 min [estimation d'après 133 empreintes/s et 450 recadrages/s mesurés] ; entraînement de la tête : 10 à 45 min [estimation].
- Alternative rapide si l'utilisateur l'autorise : exécuter `extract_features.py` sur un GPU gratuit (Kaggle) ; il faudrait y téléverser les
  recadrages (3 Go) : à décider, la licence CC BY 4.0 l'autorise mais cela sort les données de ce PC.

## 4. Export Core ML : WSL (Ubuntu) ou macOS

`coremltools` ne publie des roues natives que pour Linux et macOS : l'export écrit un vrai `.mlpackage` sous **WSL** (installé le 2026-11-02 :
distribution `Ubuntu-24.04`, WSL2, Python 3.12.3, utilisable en root sans mot de passe) ou sur macOS. La PRÉDICTION Core ML (donc la parité) n'existe que sous macOS.

Depuis PowerShell (`$env:WSL_UTF8=1` pour lire les sorties) ; installation faite une fois :

```powershell
$env:WSL_UTF8=1
wsl -d Ubuntu-24.04 -u root -- bash -lc "export DEBIAN_FRONTEND=noninteractive; apt-get update -qq; apt-get install -y -qq python3-venv python3-pip"
wsl -d Ubuntu-24.04 -u root -- bash -lc "python3 -m venv ~/ardane-ml/venv && . ~/ardane-ml/venv/bin/activate && pip install -q --upgrade pip && pip install -q torch==2.7.0 --index-url https://download.pytorch.org/whl/cpu && pip install -q -r /mnt/c/Users/Etudiant/Documents/GitHub/tessera/scripts/ml/requirements-export.txt"
```

(`torch==2.7.0` CPU : la version testée par coremltools 9.0 ; le venv est `/root/ardane-ml/venv`. Les avertissements « Failed to load _MLModelProxy ...
libcoremlpython » sont normaux sous Linux : seule la prédiction manque, la conversion et l'écriture du paquet marchent.)

Export du modèle entraîné (données sur le disque Windows, vues sous `/mnt/c`) :

```powershell
wsl -d Ubuntu-24.04 -u root -- bash -lc "cd /mnt/c/Users/Etudiant/Documents/GitHub/tessera/scripts/ml && . ~/ardane-ml/venv/bin/activate && export PYTHONDONTWRITEBYTECODE=1 ARDANE_ML_ROOT=/mnt/c/Users/Etudiant/ardane-tools/ml && python export_coreml.py --dataset myfoodrepo --head head-linear.pt --version 0.1.0 --int8"
```

Résultat : `C:\Users\Etudiant\ardane-tools\ml\models\myfoodrepo\export\` avec `ArdaneFoodClassifier-fp16.mlpackage`, `...-int8.mlpackage`,
`ArdaneFoodClassifier.classes.json`, `ATTRIBUTIONS.txt` et `ArdaneFoodClassifier.export.json` (tailles, empreinte de la tête, versions).

**Tailles mesurées** (modèle complet DINOv2-S + tête de 11 classes du jeu factice ; une tête de 323 ou 498 classes ajoute moins de 0,5 Mo) :

| Variante | `.mlpackage` | dont poids (`weight.bin`) | protobuf (`model.mlmodel`) |
|---|---|---|---|
| fp16 | 43 418 898 octets = **41,4 Mio** (43,4 Mo décimaux) | 43 285 846 | 132 435 |
| int8 (par canal, symétrique) | 21 953 892 octets = **20,9 Mio** (22,0 Mo décimaux) | 21 809 622 | 143 653 |

Contrôle fait : le paquet se relit (`ct.models.MLModel(..., skip_model_load=True)`) : spécification version 8 (iOS 17), entrée `image` 224 x 224 RGB,
sorties `probabilities` (1 x C) et `embedding` (1 x 768), métadonnées `ardane.*` présentes. **Non vérifié** : l'ouverture dans Xcode / sur un iPhone, la
prédiction, l'écart numérique PyTorch / Core ML (macOS seulement, section 5) et `--classifier`.

Sans WSL (Windows seul), `export_coreml.py` retombe sur la CONVERSION À BLANC de `coreml_dryrun.py` : conversion complète jusqu'au protobuf, taille calculée,
aucun fichier écrit. Elle avait annoncé 41,4 Mio avant l'installation de WSL, soit exactement la taille mesurée ensuite : outil de secours fiable pour la taille.

**Sortie du modèle** : entrée `image` 224 x 224 RGB (valeurs 0..255, la normalisation ImageNet est DANS le graphe), sorties `probabilities`
(softmax étalonné) et `embedding` (768 nombres, pour la mémoire personnelle) ; avec `--classifier`, un modèle « classifieur » Core ML (étiquette +
dictionnaire, lisible comme `VNClassificationObservation`), sans embedding : **variante non vérifiée de bout en bout**, à essayer sur macOS. Les étiquettes
sont `mfr:<nom de classe MyFoodRepo>` (ex. `mfr:bread-white` ; le nom est la clé stable, identique dans le COCO et dans le projet Supervisely) ;
`ArdaneFoodClassifier.classes.json` donne l'index, l'étiquette, le nom et l'identifiant Ardane de chaque classe, et les
métadonnées du modèle (`ardane.*`) portent version, licences, attribution, température, empreinte des poids de DINOv2 et liste des classes.
La correspondance vers les aliments d'Ardane vit dans `class_map.csv` : on peut la corriger sans ré-entraîner ni ré-exporter.

**Contrat d'entrée pour l'intégration dans l'app** (à reproduire À L'IDENTIQUE, sinon la précision mesurée ne vaut plus ; règle de référence : `crop_square` dans `ml_common.py`) :
1. partir de la boîte englobante du masque de l'aliment (pixels de la photo) ;
2. l'élargir de 10 % de son plus grand côté de chaque côté, la rendre CARRÉE autour de son centre (côté = plus grand côté x 1,2) ; si le carré sort de la photo, le décaler pour rester dedans ; s'il ne tient pas du tout, compléter avec du gris (124, 116, 104) ;
3. NE PAS masquer le fond : l'entraînement voit l'aliment avec son contexte (assiette, table), pas un détourage ;
4. redimensionner en 224 x 224 (bicubique), RGB, valeurs 0..255 telles quelles (pas de normalisation côté Swift : elle est dans le modèle).

## 5. Parité PyTorch / Core ML (à exécuter plus tard sur macOS ; non exécuté à ce jour)

Core ML ne prédit que sous macOS. `parity_coreml.py` compare, sur les mêmes images, le modèle PyTorch complet et le `.mlpackage` : écart
maximal des probabilités (tolérance 0,02 en fp16, 0,08 en int8), accord du Top-1 (>= 98 % en fp16, >= 93 % en int8), accord du Top-3,
cosinus des embeddings ; code de sortie non nul au-dessus des tolérances. Fonctionnement prévu sur le runner macOS de la CI (à ajouter
au workflow SEULEMENT avec l'accord de l'utilisateur, `.github` n'a pas été touché) :

```yaml
  # exemple, non ajouté : toute la chaîne factice + export réel + parité, ~10 min
  coreml-chain:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.12" }
      - run: |
          pip install torch==2.7.0 coremltools==9.0 "numpy<2.3" pillow protobuf
          export ARDANE_ML_ROOT="$RUNNER_TEMP/ml"
          python scripts/ml/selftest_fake_chain.py --int8 --parity
      - uses: actions/upload-artifact@v4
        with: { name: coreml-fake-chain, path: "${{ runner.temp }}/ml/models/fake/export" }
```

La taille réelle du `.mlpackage` est déjà mesurée sous WSL (section 4) ; ce job apporterait ce qui manque : la PARITÉ numérique. Le modèle issu du jeu factice ne doit jamais être livré (le nom de modèle et
les métadonnées le disent : « MODÈLE D'ESSAI ENTRAÎNÉ SUR UN JEU FACTICE, NE PAS LIVRER »).

## 6. Auto-test sur le jeu factice (preuve que la chaîne tourne)

```bash
python selftest_fake_chain.py --export-python /c/Users/Etudiant/ardane-tools/ml/venv-export-win/Scripts/python.exe   # Windows
python selftest_fake_chain.py --int8 --parity                                                                          # Linux/macOS
python selftest_fake_chain.py --int8 --supervisely                                                                     # + lecture d'un projet Supervisely fabriqué
# sous WSL, tout dans Ubuntu (écrit de VRAIS .mlpackage) :
wsl -d Ubuntu-24.04 -u root -- bash -lc "cd /mnt/c/Users/Etudiant/Documents/GitHub/tessera/scripts/ml && . ~/ardane-ml/venv/bin/activate && export PYTHONDONTWRITEBYTECODE=1 ARDANE_ML_ROOT=/root/ardane-ml/data && python selftest_fake_chain.py --int8 --supervisely"
```

Le jeu factice (`make_fake_coco.py`) : formes colorées, classes aux noms façon MyFoodRepo mais identifiants inventés, avec des pièges volontaires
(instance minuscule, annotation « foule », photo de test recopiée dans l'entraînement, classe sans équivalent dans la base). **Ses chiffres ne
mesurent rien** : le rapport porte un bandeau « JEU FACTICE ».

## 7. Jalon B (suite, hors de cette chaîne) : segmenteur d'instances

Un classifieur sur recadrages suppose de savoir DÉCOUPER les aliments. Le jalon B entraîne un segmenteur RF-DETR-Seg (Nano ou Small, Apache 2.0) sur les
MÊMES annotations COCO de MyFoodRepo, sur un GPU gratuit de Kaggle (T4/P100, sessions limitées à ~12 h : prévoir des reprises), puis exporte vers Core ML
(l'export de la tête de segmentation n'est pas documenté : à prouver avant tout engagement ; repli : détection RF-DETR + EdgeTAM). Il réutilise
`prepare_myfoodrepo.py` (mêmes groupes de photos, même split : le test reste intouché) et la tête de ce jalon sur les recadrages de ses masques.
Coût estimé dans `Recherche-modeles.md` (location GPU : à décider après un petit essai chiffré).

## 8. Licences

- DINOv2 (code et poids ViT-S/14) : **Apache 2.0**, Meta Platforms (`github.com/facebookresearch/dinov2`, commit épinglé `7764ea0f9...`,
  poids `dinov2_vits14_pretrain.pth`, SHA-256 `b938bf1b...` mesuré le 2026-11-02). Autres familles du dépôt (CellDINO, X-ray DINO) : non commerciales, NON utilisées.
- MyFoodRepo / AIcrowd Food Recognition Benchmark 2022 : **CC BY 4.0** (règles du concours AIcrowd, section 1 ; preuve datée du 2026-11-02 dans
  `docs/scanner/Licences-donnees-modeles.md`), attribution obligatoire. La copie Dataset Ninja affiche CC0 : on retient quand même CC BY 4.0 (la plus restrictive).
- coremltools (BSD-3), torch (BSD-3) : outils, rien n'est livré. La tête (quelques centaines de Ko) appartient à Ardane.
- Ne JAMAIS utiliser pour cette chaîne : Food-101, FoodSeg103, UECFood, FoodX, ISIA, Food2K, Recipe1M (licences non claires ou de recherche).

## 9. Dépannage

- « xFormers is not available » et « Failed to load _MLModelProxy » : avertissements normaux (CPU ; Windows sans natives).
- `FileNotFoundError ... annotations.json` : la mise en page de la section 1.D n'est pas respectée.
- Les poids téléchargés ne correspondent pas à l'empreinte : supprimer `torch_home\hub\checkpoints\dinov2_vits14_pretrain.pth` et relancer.
- Interrompu pendant l'extraction : relancer la même commande ; seuls les lots manquants sont recalculés.
- Pour repartir de zéro : supprimer `work\<jeu>\features` (ou tout `work\<jeu>`).

## 10. Résultats réels du jalon A (2026-11-03) : à lire AVANT de s'enthousiasmer

Données : MyFoodRepo v2.0 (copie Kaggle, 498 classes), 78 110 recadrages : entraînement 68 830, validation 7 460 (prélevée dans `train` par groupes de photos),
**test 1 820 (le jeu `val` OFFICIEL, 998 photos, jamais utilisé pour régler quoi que ce soit)**. 3 photos d'entraînement retirées (quasi identiques à une photo de test).
Seule mesure valable : le TEST. Rapport complet : `reports\classifier-2026-11-03.md` (+ `.json`) ; les 8 autres variantes essayées, comparées sur la validation
seule, sont dans `reports\sweep\`.

| Mesure sur le TEST (tête MLP 768-2048-498, DINOv2-S gelé) | Valeur |
|---|---|
| Top-1 | **45,8 %** (Wilson 95 % : 43,5 à 48,1) |
| Top-3 | **65,9 %** (63,7 à 68,1) |
| Rappel moyen par classe | 36,1 % (F1 moyen 33,1 %) |
| ECE (calibration, 15 intervalles) | 0,063 (0,075 avant étalonnage) : le modèle est SURCONFIANT dans le haut des probabilités (confiance 0,97 pour 86 % de justesse) |
| Exactitude quand la confiance >= 0,9 / 0,7 / 0,5 | 84,8 % (11 % du test) / 74,4 % (29 %) / 65,8 % (49 %) |

Lecture honnête : **c'est un classifieur médiocre sur 498 classes fines, pas un classifieur prêt à nommer seul un aliment.**
- 175 des 405 classes présentes dans le test (43 %) ont un rappel de 0 ; les classes fréquentes (>= 200 recadrages d'entraînement) ont un rappel moyen de 53 %, les rares (< 50) de 30 %.
- Les confusions sont surtout des quasi-synonymes de l'ontologie suisse (`espresso-with-caffeine` / `coffee-with-caffeine`, `bread-whole-wheat` / `bread-wholemeal`, `salad-leaf-salad-green` / `mixed-salad-...`) :
  une partie de ces erreurs deviendrait sans conséquence si les classes voisines menaient au même aliment d'Ardane (à mesurer APRÈS relecture de `class_map.csv`, jamais sur la table automatique).
- La validation (50,3 % de Top-1) est plus facile que le test (45,8 %) : la température d'étalonnage tirée d'elle sous-estime la surconfiance réelle. Prévoir un étalonnage sur les repas de l'utilisateur.
- Un autre découpage ou d'autres réglages donneraient quelques points de plus ou de moins : les neuf variantes essayées sont à 39-50 % de Top-1 sur la validation.
- Pistes non essayées (hors jalon A) : un DINOv2 plus gros (ViT-B), du réglage fin, des classes regroupées, un seuil de confiance dans l'app (>= 0,7 : 74 % de justesse sur 29 % des recadrages).

Fichiers : têtes `models\myfoodrepo\head-mlp.pt` (retenue) et `head-s-*.pt` (variantes) ; Core ML `models\myfoodrepo\export\ArdaneFoodClassifier-{fp16,int8}.mlpackage` +
`.classes.json` + `ATTRIBUTIONS.txt`. Parité PyTorch / Core ML non mesurée (macOS).
