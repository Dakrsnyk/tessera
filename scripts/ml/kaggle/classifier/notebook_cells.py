"""Cellules du carnet `ardane-classifier.ipynb` (classifieur d'aliments, chantier 22.3). Assemblées par `../build_notebooks.py`.

Chaque entrée : ("md" | "code", texte). Le texte « {{...}} » est remplacé à la construction (code embarqué, empreintes).
Le carnet est GÉNÉRÉ : ne pas l'éditer à la main, modifier ce fichier puis lancer `python build_notebooks.py`.
"""

TITLE = "Ardane : classifieur d'aliments (DINOv2) sur Kaggle"

CELLS = [
    ("md", r'''# Ardane : classifieur d'aliments (DINOv2-S/14) sur Kaggle

Chantier 22.3 d'Ardane. Ce carnet refait sur GPU la chaîne du dossier `scripts/ml/` du dépôt (voie **A**, identique à la chaîne CPU de l'ordinateur,
pour comparer), puis une variante **B** plus précise (affinage partiel de DINOv2 avec augmentations) :

1. **Préparation** : recadrages carrés 224 x 224 des instances MyFoodRepo, photos réparties sans fuite (`prepare_myfoodrepo.py`) ; le jeu officiel « validation 2.0 » est le **TEST**, jamais utilisé pour régler.
2. **Voie A** : vecteurs DINOv2-S/14 gelé sur GPU (`extract_features.py`), tête linéaire étalonnée par température (`train_head.py`), export **Core ML** fp16 + int8 (`export_coreml.py`).
3. **Variante B** : les derniers blocs de DINOv2 sont affinés (augmentations, arrêt anticipé sur la validation prélevée dans train), puis tête linéaire étalonnée sur les vecteurs affinés, export Core ML fp16 + int8.
4. **Rapport** : `RESULTS.md` (Top-1, Top-3, ECE de A et de B sur le TEST officiel), modèles `.mlpackage` zippés, journaux, points de sauvegarde.

**Réglages** : cellule 2 seulement. **Durée attendue** : environ 2 à 3 h avec un GPU T4 (estimation, à confirmer par le premier passage ; le rapport donne les durées réelles). **Quota** : un passage consomme environ 2 à 4 h de GPU sur les 30 h de la semaine.
**Reprise** : si la session s'arrête, relancer en ajoutant la SORTIE de la version précédente comme source de données (voir `scripts/ml/kaggle/README.md`) ; les étapes terminées sont sautées.

Licences : DINOv2 (Meta) Apache 2.0 ; données MyFoodRepo / AIcrowd Food Recognition Benchmark 2022 sous **CC BY 4.0** (attribution obligatoire ; la copie Kaggle affiche CC0, on applique la plus exigeante).
Code embarqué ci-dessous : copie exacte de `scripts/ml/` du dépôt `Dakrsnyk/tessera` (empreintes affichées), pour ne dépendre d'aucun clone.
'''),

    ("code", r'''# =============================================================================================================
#  RÉGLAGES : la seule cellule à modifier.
# =============================================================================================================
import os, sys, time

T0 = time.time()                                   # début de session : sert au budget de temps (12 h au plus sur Kaggle)
SMOKE_DIR = os.environ.get("ARDANE_KAGGLE_SMOKE")  # essai local sur un jeu factice (toujours None sur Kaggle)

BACKBONE = "vitb14"           # v4 (2026-11-04) : DINOv2 ViT-B/14 (« vits14 » = passages 1 à 3, plafond vers 50 % Top-1)
os.environ["ARDANE_DINOV2"] = BACKBONE        # lu par ml_common à l'import : AVANT tout import du code embarqué
ARDANE_LEVEL = True           # v4 : classes MyFoodRepo fusionnées par aliment d'Ardane (derive_ardane_labels.py)
QUEBEC_DATASET = "ardane-quebec-crops"        # jeu Kaggle privé des recadrages de plats québécois libres de droits (vide = sans)
RUN_B = True                  # variante B (affinage de DINOv2) après la voie A
A_ALSO_MLP = True             # voie A : en plus de la tête linéaire, une tête MLP (rapport seulement, pas exportée)
B_ALSO_MLP = True             # variante B : en plus de la tête linéaire, une tête MLP sur les vecteurs affinés (exportée aussi)
# Tête MLP : meilleur réglage du balayage CPU du 2026-11-03 (9 variantes, choix sur la VALIDATION, voir scripts/ml/README.md § 10)
HEAD_MLP_ARGS = ["--hidden", "2048", "--dropout", "0.5", "--lr", "5e-4", "--wd", "0.05", "--balance-alpha", "0.5", "--label-smoothing", "0.1"]
B_UNFREEZE_BLOCKS = 9         # derniers blocs de DINOv2 affinés (sur 12) ; passage 2 : 6 blocs progressaient encore à la 10e époque
B_EPOCHS = 12                 # époques au plus (arrêt anticipé sur la validation) ; ViT-B : environ 3,5 fois plus lent par époque que le ViT-S
B_BATCH = 64 if BACKBONE == "vitb14" else 128   # ViT-B : lot réduit pour tenir dans les 16 Go du T4
B_BASE_LR = 3e-5              # taux du dernier bloc ; décroît de 0,85 par bloc vers l'entrée
B_HEAD_LR = 1e-4
B_PATIENCE = 3                # époques sans amélioration de la perte de validation avant l'arrêt
B_MAX_TRAIN = 0               # 0 = tout ; un nombre = sous-ensemble (essais)
B_MAX_VAL = 0
EXTRACT_BATCH = 256           # lot d'extraction des vecteurs (GPU)
SESSION_HOURS = 12.0          # plafond Kaggle d'une session : ne pas dépasser
RESERVE_HOURS = 1.0           # gardé pour les exports, les rapports et l'écriture de la sortie
B_POST_SECONDS = 4200         # temps à garder après l'affinage B : vecteurs affinés + tête + export (estimation prudente : 40 min)
VERSION_A, VERSION_B = ("0.3.0", "0.4.0") if ARDANE_LEVEL else ("0.1.0", "0.2.0")
EXTRACT_EXTRA = []            # arguments supplémentaires de extract_features.py (essai local)
WORKERS = max(2, min(8, os.cpu_count() or 2))

DS_SRC = "fake" if SMOKE_DIR else "myfoodrepo"       # recadrages préparés (« fake » : essai local, rapports marqués FACTICES)
DS = DS_SRC + "-ardane" if ARDANE_LEVEL else DS_SRC  # jeu d'entraînement (classes fusionnées par aliment d'Ardane + plats québécois)
DS_B = DS + "-B"
LICENSE_NOTE = ("CC BY 4.0 (règles du concours AIcrowd 2022, section 1, relevées le 2026-11-02 ; la copie Kaggle awsaf49/food-recognition-2022-dataset "
                "affiche CC0 : on applique la plus exigeante)")
'''),

    ("code", r'''# Code embarqué : copie exacte de scripts/ml/ (dépôt Dakrsnyk/tessera) et du module kaggle_common. Vérifiée par empreinte, extraite ici.
import base64, hashlib, io, pathlib, zipfile

PAYLOAD_SHA256 = "{{PAYLOAD_SHA256}}"
PAYLOAD_SOURCE = "{{PAYLOAD_SOURCE}}"
PAYLOAD_B64 = """
{{PAYLOAD_B64}}
"""

_blob = base64.b64decode("".join(PAYLOAD_B64.split()))
assert hashlib.sha256(_blob).hexdigest() == PAYLOAD_SHA256, "le code embarqué est corrompu"
CODE_DIR = pathlib.Path(SMOKE_DIR or "/kaggle/working") / "ardane_code"
CODE_DIR.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(io.BytesIO(_blob)) as _z:
    _z.extractall(CODE_DIR)
    for _info in _z.infolist():
        print(f"{_info.filename:28s} {_info.file_size:8d} octets")
print("code embarqué :", PAYLOAD_SOURCE, "->", CODE_DIR)
''', {"hidden": True}),

    ("code", r'''# Environnement : chemins, GPU, budget de temps, et installation (en arrière-plan) de l'environnement d'export Core ML.
import json, subprocess
sys.dont_write_bytecode = True
sys.path.insert(0, str(CODE_DIR))
import kaggle_common as kc

ENV = kc.detect_env(T0, CODE_DIR, smoke_dir=SMOKE_DIR, limit_hours=SESSION_HOURS, reserve_hours=RESERVE_HOURS)
os.environ["ARDANE_ML_ROOT"] = str(ENV.ml_root)
os.environ.setdefault("TORCH_HOME", str(ENV.ml_root / "torch_home"))
os.environ["XFORMERS_DISABLED"] = "1"          # DINOv2 : attention standard (comme sur le CPU) ; évite tout conflit de version avec xformers
GPU = kc.gpu_check()
print("GPU :", json.dumps(GPU, ensure_ascii=False))
if not SMOKE_DIR:
    if not GPU.get("cuda"):
        raise RuntimeError("Aucun GPU : « Settings › Accelerator › GPU T4 » (un compte vérifié par téléphone est obligatoire pour activer GPU et Internet).")
    if not GPU.get("compute_ok"):
        raise RuntimeError("Ce GPU ne peut pas exécuter ce torch (" + str(GPU.get("error")) + "). Choisir « GPU T4 x2 » dans Settings › Accelerator.")
DEVICE = "cuda" if GPU.get("cuda") else "cpu"
kc.ensure_imports([("numpy", "numpy"), ("PIL", "pillow")])
NOTES = []
EXPORT_PROC = kc.start_export_env(ENV)          # torch 2.7.0 CPU + coremltools 9.0, validés par la chaîne CPU ; dure ~3 min, en parallèle
print("dossiers : entrée", ENV.input_root, "| sortie", ENV.out, "| données lourdes (non conservées)", ENV.ml_root)
print(ENV.budget)
'''),

    ("code", r'''# Reprise éventuelle et localisation des données.
PREVIOUS = kc.restore_state(ENV)
DATA = kc.find_myfoodrepo(ENV.input_root)
for _k, _v in DATA.items():
    print(f"{_k:13s} {_v}")
WORK_SRC = ENV.ml_root / "work" / DS_SRC
WORK = ENV.ml_root / "work" / DS
QUEBEC_DIR = None
if QUEBEC_DATASET and not SMOKE_DIR:
    _hits = sorted(ENV.input_root.rglob("quebec_crops.csv"))
    if not _hits:
        raise RuntimeError(f"Jeu {QUEBEC_DATASET} introuvable sous {ENV.input_root} : l'ajouter en entrée (dataset_sources) ou vider QUEBEC_DATASET.")
    QUEBEC_DIR = _hits[0].parent
    print("plats québécois :", QUEBEC_DIR)
# Preuve de licence rangée à côté des données (la preuve datée complète est dans docs/scanner/Licences-donnees-modeles.md du dépôt)
_lic = ENV.ml_root / "raw" / "myfoodrepo"
_lic.mkdir(parents=True, exist_ok=True)
(_lic / "LICENCE-2026-11-02-kaggle.txt").write_text(
    "Données : MyFoodRepo / AIcrowd Food Recognition Benchmark 2022, copie Kaggle awsaf49/food-recognition-2022-dataset (v2.0).\n"
    "Licence retenue : CC BY 4.0 (règles du concours AIcrowd, section 1 « Competition Description », relevées le 2026-11-02).\n"
    "La copie Kaggle affiche CC0 ; la plus exigeante est appliquée (attribution : MyFoodRepo / AIcrowd, CC BY 4.0).\n"
    "Ce fichier est un pointeur : la preuve datée complète est dans docs/scanner/Licences-donnees-modeles.md du dépôt Ardane.\n", encoding="utf-8")
'''),

    ("code", r'''# 1. PRÉPARATION : recadrages carrés, répartition des photos sans fuite (reprenable : relancer refait seulement ce qui manque).
def crops_present():
    folder = WORK_SRC / "crops" / "train"
    return folder.exists() and any(folder.glob("*.jpg"))

def run_prepare():
    kc.run_logged([sys.executable, "prepare_myfoodrepo.py", "--root", ENV.ml_root, "--dataset", DS_SRC,
                   "--train-json", DATA["train_json"], "--train-images", DATA["train_images"],
                   "--val-json", DATA["val_json"], "--val-images", DATA["val_images"],
                   "--dataset-version", "2.0", "--license-note", LICENSE_NOTE, "--skip-class-map", "--workers", WORKERS], "01-prepare", ENV)

def ensure_crops():
    """Les recadrages ne sont pas conservés d'une session à l'autre (3 Go) : on les refait à la demande (déterministe, quelques minutes)."""
    if not (WORK_SRC / "crops.csv").exists() or not crops_present():
        with kc.timed(ENV, "prepare"):
            run_prepare()
        kc.mark_stage(ENV, "prepare")
        kc.persist(ENV)
    if ARDANE_LEVEL and (not (WORK / "crops.csv").exists() or not (WORK / "meta.json").exists()):
        kc.run_logged([sys.executable, "derive_ardane_labels.py", "derive", "--root", ENV.ml_root, "--src", DS_SRC, "--dst", DS,
                       *(["--quebec", QUEBEC_DIR] if QUEBEC_DIR else [])], "01b-derive", ENV)

if kc.stage_done(ENV, "prepare") and (WORK / "crops.csv").exists() and (WORK / "meta.json").exists() and crops_present():
    print("Étape « prepare » déjà faite (les recadrages seront refaits seulement si une étape suivante en a besoin).")
else:
    ensure_crops()
META = kc.read_json(WORK / "meta.json")
print("photos :", META["photos"], "| recadrages :", META["crops"], "| classes :", META["n_classes"])
print("répartition :", META["split_method"])
'''),

    ("code", r'''# 2. VOIE A, vecteurs : DINOv2-S/14 GELÉ sur GPU, fp32 comme sur le CPU (comparable), lots enregistrés.
import hashlib

def features_ready(work):
    feat = work / "features"
    need = [feat / f"{s}.{k}.npy" for s in ("train", "val", "test") for k in ("X", "y", "ann_id")] + [feat / "meta.json"]
    if not all(p.exists() for p in need):
        return False
    meta = kc.read_json(feat / "meta.json")
    return meta.get("crops_csv_sha256_12") == hashlib.sha256((work / "crops.csv").read_bytes()).hexdigest()[:12] and not meta.get("limit")

if features_ready(WORK):
    print("Étape « extract_A » déjà faite.")
else:
    ensure_crops()
    with kc.timed(ENV, "extract_A"):
        kc.run_logged([sys.executable, "extract_features.py", "--root", ENV.ml_root, "--dataset", DS, "--device", DEVICE,
                       "--batch", EXTRACT_BATCH, "--workers", WORKERS, "--shard", 4096, *EXTRACT_EXTRA], "02-extract-A", ENV)
    kc.mark_stage(ENV, "extract_A")
    kc.persist(ENV)
'''),

    ("code", r'''# 3. VOIE A, têtes : linéaire (celle qu'on exporte) et MLP (pour comparer). Étalonnage par température sur la validation, rapport sur le TEST.
import classifier_report as cr
REPORTS = ENV.ml_root / "reports"

def train_head(head, tag="", extra=()):
    kc.run_logged([sys.executable, "train_head.py", "--root", ENV.ml_root, "--dataset", DS, "--head", head,
                   *(["--tag", tag] if tag else []), *extra], f"03-train-{tag or head}", ENV)

if kc.stage_done(ENV, "heads_A") and (ENV.ml_root / "models" / DS / "head-linear.pt").exists():
    print("Étape « heads_A » déjà faite.")
else:
    with kc.timed(ENV, "heads_A"):
        train_head("linear")
        if A_ALSO_MLP:
            train_head("mlp", "mlp", HEAD_MLP_ARGS)
    kc.mark_stage(ENV, "heads_A")
    kc.persist(ENV)
A = cr.latest_report(REPORTS, DS, "")
print("rapport A :", A)
'''),

    ("code", r'''# 4. VOIE A, export Core ML (fp16 + int8) dans l'environnement d'export, puis zip des .mlpackage.
EXPORTS = []

def ensure_export_env():
    global EXPORT_PROC
    if EXPORT_PROC is not None:
        ok = kc.wait_export_env(ENV, EXPORT_PROC)
        EXPORT_PROC = None
        if not ok:
            NOTES.append("Environnement d'export Core ML non installé : tentative avec le torch du carnet (non testé par coremltools 9).")
            kc.run_logged([sys.executable, "-m", "pip", "install", "-q", "coremltools==9.0"], "04-export-env-fallback", ENV, check=False)
            ENV.export_python, ENV.export_env = sys.executable, {}

def export_variant(dataset, head, name, version, variant, extra=()):
    ensure_export_env()
    try:
        kc.run_logged([ENV.export_python, "export_coreml.py", "--root", ENV.ml_root, "--dataset", dataset, "--head", head, "--name", name,
                       "--version", version, "--int8", *extra], f"04-export-{variant}", ENV, extra_env=ENV.export_env)
        EXPORTS.extend(kc.collect_export(ENV, dataset, variant, name))
    except Exception as exc:                                    # l'export ne doit jamais faire perdre l'entraînement
        NOTES.append(f"Export Core ML de {variant} en échec : {str(exc)[:300]} (voir logs/04-export-{variant}.log ; refaire sous WSL avec export_coreml.py).")
        print("ÉCHEC de l'export", variant, ":", exc)

if kc.stage_done(ENV, "export_A"):
    print("Étape « export_A » déjà faite.")
    EXPORTS.extend(kc.stage_info(ENV, "export_A").get("exports", []))
else:
    with kc.timed(ENV, "export_A"):
        export_variant(DS, "head-linear.pt", "ArdaneFoodClassifier", VERSION_A, "A")
    kc.mark_stage(ENV, "export_A", done=any(e["variant"] == "A" for e in EXPORTS), exports=[e for e in EXPORTS if e["variant"] == "A"])
    kc.persist(ENV)
'''),

    ("code", r'''# 5. VARIANTE B, affinage : les derniers blocs de DINOv2 apprennent (augmentations sur GPU, arrêt anticipé sur la validation).
#    Part de la voie A à l'époque 0 : B ne peut pas finir pire que A sur la validation. S'arrête PROPREMENT si le budget de session manque.
FT, B_READY = None, False
FT_DIR = ENV.ml_root / "work" / DS_B / "ft"
if not RUN_B:
    print("Variante B désactivée (RUN_B = False).")
else:
    import finetune_dinov2 as ft
    if kc.stage_done(ENV, "B_finetune") and (FT_DIR / "finetuned-backbone.pt").exists():
        FT = kc.read_json(FT_DIR / "summary.json")
        print("Étape « B_finetune » déjà faite : meilleure époque", FT["best_epoch"])
    else:
        ensure_crops()
        with kc.timed(ENV, "B_finetune"):
            FT = ft.finetune(ENV.ml_root, DS, "head-linear.pt", FT_DIR, unfreeze_blocks=B_UNFREEZE_BLOCKS, epochs=B_EPOCHS, batch=B_BATCH,
                             base_lr=B_BASE_LR, head_lr=B_HEAD_LR, patience=B_PATIENCE, workers=0 if SMOKE_DIR else min(4, WORKERS),
                             device=DEVICE, amp=True, max_train=B_MAX_TRAIN, max_val=B_MAX_VAL,
                             can_continue=lambda seconds: ENV.budget.can_run(seconds + B_POST_SECONDS))
        kc.mark_stage(ENV, "B_finetune", done=(FT["status"] == "done"), status=FT["status"], best_epoch=FT["best_epoch"])
        kc.persist(ENV)
    B_READY = FT["status"] == "done"
    if not B_READY:
        NOTES.append("Affinage B en PAUSE (budget de session atteint) : relancer avec la sortie de cette version comme source de données pour continuer.")
        print("B en pause : voir les remarques en fin de carnet.")
'''),

    ("code", r'''# 6. VARIANTE B, vecteurs affinés (DINOv2 affiné, gelé) + tête linéaire étalonnée + rapport : mêmes scripts que la voie A, sans changement.
if RUN_B and B_READY:
    if kc.stage_done(ENV, "B_head") and (ENV.ml_root / "models" / DS_B / "head-linear.pt").exists():
        print("Étape « B_head » déjà faite.")
    else:
        ensure_crops()
        with kc.timed(ENV, "B_head"):
            ft.make_derived_workdir(ENV.ml_root, DS, DS_B, ENV.code_dir, "DINOv2 affiné par finetune_dinov2.py ; mêmes classes et recadrages que " + DS)
            kc.run_logged([sys.executable, "extract_features.py", "--root", ENV.ml_root, "--dataset", DS_B, "--device", DEVICE,
                           "--backbone-weights", FT_DIR / "finetuned-backbone.pt", "--batch", EXTRACT_BATCH, "--workers", WORKERS,
                           "--shard", 4096, *EXTRACT_EXTRA], "05-extract-B", ENV)
            kc.run_logged([sys.executable, "train_head.py", "--root", ENV.ml_root, "--dataset", DS_B, "--head", "linear"], "06-train-B", ENV)
            if B_ALSO_MLP:
                kc.run_logged([sys.executable, "train_head.py", "--root", ENV.ml_root, "--dataset", DS_B, "--head", "mlp", "--tag", "mlp",
                               *HEAD_MLP_ARGS], "06-train-B-mlp", ENV)
        kc.mark_stage(ENV, "B_head")
        kc.persist(ENV)
    print("rapport B :", cr.latest_report(REPORTS, DS_B, ""))
    if B_ALSO_MLP:
        print("rapport B-MLP :", cr.latest_report(REPORTS, DS_B, "mlp"))
else:
    print("Variante B non disponible dans cette session.")
'''),

    ("code", r'''# 7. VARIANTE B, export Core ML (fp16 + int8) avec le DINOv2 affiné.
if RUN_B and B_READY:
    if kc.stage_done(ENV, "export_B"):
        print("Étape « export_B » déjà faite.")
        EXPORTS.extend(kc.stage_info(ENV, "export_B").get("exports", []))
    else:
        with kc.timed(ENV, "export_B"):
            export_variant(DS_B, "head-linear.pt", "ArdaneFoodClassifierB", VERSION_B, "B", ["--backbone-weights", FT_DIR / "finetuned-backbone.pt"])
            if B_ALSO_MLP and (ENV.ml_root / "models" / DS_B / "head-mlp.pt").exists():
                export_variant(DS_B, "head-mlp.pt", "ArdaneFoodClassifierBM", VERSION_B, "B-MLP",
                               ["--backbone-weights", FT_DIR / "finetuned-backbone.pt"])
        kc.mark_stage(ENV, "export_B", done=any(e["variant"] == "B" for e in EXPORTS),
                      exports=[e for e in EXPORTS if e["variant"] in ("B", "B-MLP")])
        kc.persist(ENV)
else:
    print("Rien à exporter pour B.")
'''),

    ("code", r'''# 8. RAPPORT FINAL : RESULTS.md (A contre B), copie des rapports, têtes, DINOv2 affiné, table des classes dans la sortie.
import shutil
def _load(path):
    return json.loads(path.read_text(encoding="utf-8")) if path else None

VARIANTS = {"A": _load(cr.latest_report(REPORTS, DS, "")),
            "A-MLP": _load(cr.latest_report(REPORTS, DS, "mlp")) if A_ALSO_MLP else None,
            "B": _load(cr.latest_report(REPORTS, DS_B, "")) if RUN_B and B_READY else None,
            "B-MLP": _load(cr.latest_report(REPORTS, DS_B, "mlp")) if RUN_B and B_READY and B_ALSO_MLP else None}
kc.collect_outputs(ENV, [DS, DS_B])
_stages = kc.read_json(ENV.state / kc.STAGES_FILE)
_n = META["crops"]
_dataset_note = (f"- Source : {META['name']}.\n- Licence : {META['license']}. Attribution : « {META['attribution'] or '(jeu factice)'} ».\n"
                 f"- Répartition : {META['split_method']}.\n- Photos : {META['photos']} ; recadrages : {_n} ; classes : {META['n_classes']}.")
_text = cr.write_results(ENV.out / "RESULTS.md", fake=META["kind"] == "fake", gpu=GPU, variants=VARIANTS, timings=_stages.get("timings", {}),
                         session_hours=ENV.budget.elapsed() / 3600, exports=EXPORTS, finetune=FT, notes=NOTES, dataset_note=_dataset_note)
kc.persist(ENV)
print(_text)
print("--- contenu de la sortie ---")
for _p in sorted(ENV.out.iterdir()):
    _size = kc.dir_size(_p) if _p.is_dir() else _p.stat().st_size
    print(f"{_p.name:24s} {_size / 1048576:9.1f} Mo")
print(ENV.budget)
'''),
]
