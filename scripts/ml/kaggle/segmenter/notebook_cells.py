"""Cellules du carnet `ardane-segmenter.ipynb` (segmenteur RF-DETR-Seg, chantier 22.3). Assemblées par `../build_notebooks.py`.

Le carnet est GÉNÉRÉ : ne pas l'éditer à la main, modifier ce fichier puis lancer `python build_notebooks.py`.
"""

TITLE = "Ardane : segmenteur d'aliments (RF-DETR-Seg) sur Kaggle"

CELLS = [
    ("md", r'''# Ardane : segmenteur d'aliments (RF-DETR-Seg) sur Kaggle

Chantier 22.3 d'Ardane, jalon B. Affinage de **RF-DETR-Seg Nano** (puis **Small** si le temps le permet) sur les annotations d'instances de MyFoodRepo
(un masque par aliment, 498 classes) ; évaluation sur le **TEST officiel** (« validation 2.0 », jamais utilisé pour régler) ; export **ONNX** et **tentative d'export Core ML**.

**Licence du modèle** (vérifiée le 2026-11-02 sur le README du dépôt officiel `roboflow/rf-detr`, branche `develop`, commit `091ab7f`, et sur la version `rfdetr` 1.11.2 publiée le 2026-10-04) :
« RF-DETR-Seg, every size (Nano through 2XLarge) : Apache 2.0 » ; le paquet `rfdetr` (entraînement, inférence, export) : Apache 2.0. Les tailles « Plus » sous licence PML 1.0
(Atto, Femto, Pico, XL et 2XL de **détection**, modèles NAS) ne sont **pas** utilisées. Poids de départ : `rf-detr-seg-{n,s}-ft.pth` (COCO), hébergés par Roboflow.
**Données** : MyFoodRepo / AIcrowd Food Recognition Benchmark 2022, **CC BY 4.0** (attribution obligatoire ; la copie Kaggle affiche CC0, on applique la plus exigeante).

**Déroulement**
1. Préparation : mêmes photos et même découpe sans fuite que le classifieur (`prepare_myfoodrepo.py --no-crops`) ; jeu au format « Roboflow COCO » (train / valid / test).
2. **Mesure réelle du débit** sur un petit sous-ensemble (quelques minutes), puis calcul du nombre d'époques qui tient dans le budget de la session.
3. Entraînement avec point de sauvegarde à chaque époque (`last.ckpt`) et arrêt propre si le budget de temps manque.
4. Évaluation : mAP de masque (COCO), IoU et Dice moyens par aliment (définitions de `Tests/Support/ScanMetrics.swift`, portées en Python), latence sur ce GPU.
5. Export ONNX et Core ML (non garanti : l'erreur exacte est consignée si ça échoue).

**Reprise** : si la session s'arrête avant la fin, relancer en ajoutant la SORTIE de la version précédente comme source de données (voir `scripts/ml/kaggle/README.md`) : le carnet retrouve `last.ckpt` et continue.
**Réglages** : cellule 2 seulement.
'''),

    ("code", r'''# =============================================================================================================
#  RÉGLAGES : la seule cellule à modifier.
# =============================================================================================================
import os, sys, time

T0 = time.time()                                   # début de session : sert au budget de temps (12 h au plus sur Kaggle)
SMOKE_DIR = os.environ.get("ARDANE_KAGGLE_SMOKE")  # essai local (toujours None sur Kaggle)

SIZES = ["nano"]              # ["nano", "small"] : Small seulement si le budget le permet ; sinon une 2e session avec SIZES = ["small"]
EPOCHS_MAX = 15               # plafond d'époques (le nombre réel dépend du débit MESURÉ et du budget de la session)
MIN_EPOCHS = 4                # sous ce nombre, la taille est sautée (pas assez de temps pour un affinage utile)
BATCH = {"nano": 16, "small": 12}   # lot par taille (T4, 16 Go) ; divisé par 2 automatiquement en cas de manque de mémoire
VALID_MAX = 1500              # images de validation (prélevées dans train) ; suffisant pour choisir le meilleur point de contrôle
BENCH_TRAIN, BENCH_VALID = 320, 64   # taille du sous-ensemble de mesure du débit
OP_THRESHOLD = 0.30           # seuil de confiance d'exploitation pour IoU / Dice par aliment (fixé d'avance, pas réglé sur le test)
CLASS_AGNOSTIC = True         # une seule classe « food » : le segmenteur TROUVE les aliments, le classifieur les nomme (passage 2, 2026-11-03)
WARM_START = "rf-detr-seg-nano-myfoodrepo.pth"   # point de départ cherché sous /kaggle/input (segmenter à 498 classes du passage 1) ; "" = poids COCO
EVAL_EXPORT_RESERVE_S = 45 * 60      # temps gardé après l'entraînement : évaluation + exports (par taille)
RFDETR_VERSION = "1.11.2"
SESSION_HOURS = 12.0          # plafond Kaggle d'une session : ne pas dépasser
RESERVE_HOURS = 1.0           # gardé pour les rapports et l'écriture de la sortie
BENCH_ONLY = False            # True : mesurer le débit et s'arrêter (≈ 20 min) pour décider du budget avant l'entraînement
LIMITS = {"train": 0, "valid": 0, "test": 0}   # 0 = tout ; sinon sous-ensembles (essais)
WORKERS = max(2, min(8, os.cpu_count() or 2))   # processus de préparation des données
TRAIN_WORKERS = WORKERS                              # processus de chargement des images pendant l'entraînement
DS = "fake" if SMOKE_DIR else "myfoodrepo"
LICENSE_NOTE = ("CC BY 4.0 (règles du concours AIcrowd 2022, section 1, relevées le 2026-11-02 ; la copie Kaggle awsaf49/food-recognition-2022-dataset "
                "affiche CC0 : on applique la plus exigeante)")
'''),

    ("code", r'''# Code embarqué : copie exacte de scripts/ml/ (dépôt Dakrsnyk/tessera) et des modules du segmenteur. Vérifiée par empreinte, extraite ici.
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

    ("code", r'''# Installation de RF-DETR (AVANT d'importer torch/numpy dans ce noyau) puis environnement, GPU et budget de temps.
import json, subprocess
sys.dont_write_bytecode = True
sys.path.insert(0, str(CODE_DIR))
import kaggle_common as kc

ENV = kc.detect_env(T0, CODE_DIR, smoke_dir=SMOKE_DIR, limit_hours=SESSION_HOURS, reserve_hours=RESERVE_HOURS)
if not SMOKE_DIR:
    kc.run_logged([sys.executable, "-m", "pip", "install", "-q", f"rfdetr[train]=={RFDETR_VERSION}", "coremltools==9.0", "pycocotools"], "00-pip-rfdetr", ENV)
    # Extras d'export ONNX : facultatifs (leur échec n'empêche ni l'entraînement ni l'export Core ML)
    kc.run_logged([sys.executable, "-m", "pip", "install", "-q", "onnx", "onnxsim", "onnxruntime", "onnx_graphsurgeon", "polygraphy"], "00-pip-onnx", ENV, check=False)
os.environ["ARDANE_ML_ROOT"] = str(ENV.ml_root)
os.environ.setdefault("RF_HOME", str(ENV.ml_root / "rf_home"))      # cache des poids de départ (non conservé)
GPU = kc.gpu_check()
print("GPU :", json.dumps(GPU, ensure_ascii=False))
if not SMOKE_DIR:
    if not GPU.get("cuda"):
        raise RuntimeError("Aucun GPU : « Settings › Accelerator › GPU T4 » (un compte vérifié par téléphone est obligatoire pour activer GPU et Internet).")
    if not GPU.get("compute_ok"):
        raise RuntimeError("Ce GPU ne peut pas exécuter ce torch (" + str(GPU.get("error")) + "). Choisir « GPU T4 x2 » dans Settings › Accelerator.")
DEVICE = "cuda" if GPU.get("cuda") else "cpu"
NOTES = []
_pkgs = subprocess.run([sys.executable, "-m", "pip", "list", "--format=freeze"], capture_output=True, text=True).stdout
PKG = {l.split("==")[0].lower(): l.split("==")[1] for l in _pkgs.splitlines() if "==" in l}
PKG_KEEP = {k: PKG.get(k) for k in ("rfdetr", "torch", "torchvision", "transformers", "coremltools", "pytorch-lightning", "onnx", "onnxruntime", "numpy", "pycocotools")}
print("paquets :", PKG_KEEP)
print(ENV.budget)
'''),

    ("code", r'''# Reprise éventuelle, localisation des données, découpe des photos (SANS fuite) et jeu au format RF-DETR.
import hashlib, shutil
PREVIOUS = kc.restore_state(ENV)
DATA = kc.find_myfoodrepo(ENV.input_root)
for _k, _v in DATA.items():
    print(f"{_k:13s} {_v}")
WORK = ENV.ml_root / "work" / DS
SEG_ROOT = ENV.ml_root / "seg"
DS_DIR = ENV.ml_root / "seg_data" / ("full-food" if CLASS_AGNOSTIC else "full")
BENCH_DIR = ENV.ml_root / "seg_data" / ("bench-food" if CLASS_AGNOSTIC else "bench")
WARM_FILE = None
if WARM_START and ENV.input_root.exists():
    for _d in sorted(p for p in ENV.input_root.iterdir() if p.is_dir() and "food-recognition" not in p.name):
        WARM_FILE = next(iter(sorted(_d.rglob(WARM_START))), None) or WARM_FILE
print("point de départ :", WARM_FILE or "poids COCO de RF-DETR")

if not (WORK / "crops.csv").exists():
    with kc.timed(ENV, "prepare"):
        kc.run_logged([sys.executable, "prepare_myfoodrepo.py", "--root", ENV.ml_root, "--dataset", DS, "--no-crops", "--skip-class-map",
                       "--train-json", DATA["train_json"], "--train-images", DATA["train_images"],
                       "--val-json", DATA["val_json"], "--val-images", DATA["val_images"], "--dataset-version", "2.0",
                       "--license-note", LICENSE_NOTE, "--workers", WORKERS], "01-prepare", ENV)
    kc.mark_stage(ENV, "prepare")
    kc.persist(ENV)
META = kc.read_json(WORK / "meta.json")
print("photos :", META["photos"], "| répartition :", META["split_method"])

import seg_dataset, seg_metrics, seg_train, seg_eval, seg_export
seg_metrics.selftest()                          # les cas de Tests/ScanMetricsTests.swift, rejoués en Python
if not (DS_DIR / "dataset_stats.json").exists():
    with kc.timed(ENV, "seg_data"):
        STATS = seg_dataset.build_rfdetr_dataset(crops_csv=WORK / "crops.csv", train_json=DATA["train_json"], train_images=DATA["train_images"],
                                                 val_json=DATA["val_json"], val_images=DATA["val_images"], out_dir=DS_DIR, valid_max=VALID_MAX,
                                                 class_agnostic=CLASS_AGNOSTIC,
                                                 limit_train=LIMITS["train"], limit_valid=LIMITS["valid"], limit_test=LIMITS["test"])
else:
    STATS = kc.read_json(DS_DIR / "dataset_stats.json")
print(json.dumps({k: v for k, v in STATS.items() if k != "out_dir"}, ensure_ascii=False))
'''),

    ("code", r'''# Fonctions des étapes : mesure du débit, plan d'époques, entraînement (reprenable), évaluation, export.
import shutil

def pick_checkpoint(run):
    """Meilleur point de contrôle sur la VALIDATION (mAP de masque), sinon le dernier."""
    for name in ("checkpoint_best_total.pth", "checkpoint_best_ema.pth", "checkpoint_best_regular.pth", "last.ckpt"):
        if (run / name).exists():
            return run / name
    return None

def bench_size(size):
    name = f"bench_{size}"
    if kc.stage_done(ENV, name):
        return kc.stage_info(ENV, name)["bench"]
    if not (BENCH_DIR / "dataset_stats.json").exists():
        seg_dataset.build_rfdetr_dataset(crops_csv=WORK / "crops.csv", train_json=DATA["train_json"], train_images=DATA["train_images"],
                                         val_json=DATA["val_json"], val_images=DATA["val_images"], out_dir=BENCH_DIR, valid_max=BENCH_VALID,
                                         limit_train=BENCH_TRAIN, limit_valid=BENCH_VALID, limit_test=1, class_agnostic=CLASS_AGNOSTIC)
    run = SEG_ROOT / size / "bench_run"
    shutil.rmtree(run, ignore_errors=True)
    with kc.timed(ENV, name):
        bench = seg_train.measure_throughput(size, BENCH_DIR, run, n_train=BENCH_TRAIN, n_valid=BENCH_VALID, full_train=STATS["train"]["images"],
                                             full_valid=STATS["valid"]["images"], batch_size=BATCH[size], num_workers=TRAIN_WORKERS,
                                             device=DEVICE)
    kc.mark_stage(ENV, name, bench=bench)
    return bench

def plan_size(size, bench):
    name = f"plan_{size}"
    if kc.stage_done(ENV, name):
        return kc.stage_info(ENV, name)["epochs"]
    budget = ENV.budget.remaining() - EVAL_EXPORT_RESERVE_S
    epochs = seg_train.plan_epochs(bench["epoch_seconds_estimate"], budget, EPOCHS_MAX)
    kc.mark_stage(ENV, name, epochs=epochs, budget_seconds=round(budget), epoch_seconds=bench["epoch_seconds_estimate"])
    print(f"[plan {size}] époque estimée {bench['epoch_seconds_estimate'] / 60:.1f} min ; budget {budget / 3600:.2f} h -> {epochs} époque(s) (plafond {EPOCHS_MAX})")
    return epochs

def train_size(size, epochs):
    name = f"train_{size}"
    run = SEG_ROOT / size / "run"
    if kc.stage_done(ENV, name) and pick_checkpoint(run):
        print(f"Étape « {name} » déjà faite.")
        return
    last = run / "last.ckpt"
    with kc.timed(ENV, name):
        out = seg_train.train(size, DS_DIR, run, epochs=epochs, batch_size=BATCH[size], num_workers=TRAIN_WORKERS, resume=last if last.exists() else None,
                              pretrain_weights=WARM_FILE if size == "nano" else None,
                              can_continue=lambda s: ENV.budget.can_run(s + EVAL_EXPORT_RESERVE_S), persist_fn=lambda: kc.persist(ENV),
                              device=DEVICE)
    kc.mark_stage(ENV, name, done=not out["paused"], paused=out["paused"], epochs=epochs, epoch_seconds=out["epoch_seconds"])
    kc.persist(ENV)
    if out["paused"]:
        NOTES.append(f"Entraînement {size} en PAUSE (budget de session) : relancer avec la sortie de cette version comme source de données pour continuer.")

def eval_and_export_size(size):
    run = SEG_ROOT / size / "run"
    checkpoint = pick_checkpoint(run)
    if checkpoint is None:
        NOTES.append(f"{size} : aucun point de contrôle, rien à évaluer.")
        return None
    target = ENV.out / "models" / f"segmenter-{size}"
    target.mkdir(parents=True, exist_ok=True)
    shutil.copy2(checkpoint, target / f"rf-detr-seg-{size}-myfoodrepo{checkpoint.suffix}")
    for extra in ("epochs.jsonl", "metrics.csv", "training_config.json"):
        if (run / extra).exists():
            shutil.copy2(run / extra, target / extra)
    if not kc.stage_done(ENV, f"eval_{size}"):
        with kc.timed(ENV, f"eval_{size}"):
            metrics = seg_eval.evaluate_checkpoint(checkpoint, DS_DIR / "test", op_threshold=OP_THRESHOLD)
        (target / f"segmenter-{size}.json").write_text(json.dumps(metrics, ensure_ascii=False, indent=2, default=lambda o: None) + "\n", encoding="utf-8")
        kc.mark_stage(ENV, f"eval_{size}", ap_mask=metrics["segm"]["AP"], mean_iou=metrics["per_food"]["mean_iou"])
    else:
        metrics = kc.read_json(target / f"segmenter-{size}.json")
    if not kc.stage_done(ENV, f"export_{size}"):
        with kc.timed(ENV, f"export_{size}"):
            exported = seg_export.export_all(checkpoint, target / "export", ("onnx", "coreml"), ("float16", "float32"))
            for package in sorted((target / "export").rglob("*.mlpackage")):      # un .mlpackage est un dossier : on le range en zip pour le télécharger d'un bloc
                kc.zip_mlpackage(package, package.parent)
                shutil.rmtree(package)
        kc.mark_stage(ENV, f"export_{size}", coreml_ok={k: v["ok"] for k, v in exported["exports"].items()})
    else:
        exported = kc.read_json(target / "export" / "export-report.json")
    kc.persist(ENV)
    extra = {"Entraînement": f"Voir `epochs.jsonl` ({len(kc.stage_info(ENV, f'train_{size}').get('epoch_seconds', []))} époque(s) dans cette session) ; débit mesuré : "
                             f"{json.dumps(kc.stage_info(ENV, f'bench_{size}').get('bench', {}), ensure_ascii=False)}.",
             "Exports (ONNX et Core ML : tentative, non garantie)": seg_export.render_markdown(exported) +
                                                                  "\n- Les `.mlpackage` sont rangés en zips (`*.mlpackage.zip`) dans `models/segmenter-<taille>/export/coreml/<précision>/`."}
    seg_eval.write_report(ENV.out / f"segmenter-{size}.md", size, metrics, extra, fake=META["kind"] == "fake")
    return metrics
'''),

    ("code", r'''# Boucle principale : une taille après l'autre (Nano d'abord). Chaque taille garde SON budget : Small n'est tentée que si Nano a laissé assez de temps.
SUMMARY = {}
for SIZE in SIZES:
    print(f"\n================ RF-DETR-Seg {SIZE} ================")
    bench = bench_size(SIZE)
    if BENCH_ONLY:
        SUMMARY[SIZE] = {"bench": bench}
        continue
    epochs = plan_size(SIZE, bench)
    if epochs < MIN_EPOCHS and not kc.stage_done(ENV, f"train_{SIZE}") and not (SEG_ROOT / SIZE / "run" / "last.ckpt").exists():
        NOTES.append(f"{SIZE} sautée : {epochs} époque(s) tiennent dans le budget restant (minimum {MIN_EPOCHS}) ; époque estimée {bench['epoch_seconds_estimate'] / 60:.0f} min. "
                     "Relancer une session avec SIZES = [\"" + SIZE + "\"].")
        print(NOTES[-1])
        continue
    train_size(SIZE, epochs)
    SUMMARY[SIZE] = {"bench": bench, "epochs": epochs, "metrics": eval_and_export_size(SIZE)}
kc.persist(ENV)
print(ENV.budget)
'''),

    ("code", r'''# Rapport final : RESULTS-segmenter.md (tout vient des rapports par taille ; aucun chiffre n'est écrit à la main).
from datetime import datetime, timezone
L = []
w = L.append
w(f"# Segmenteur RF-DETR-Seg sur Kaggle : résultats ({datetime.now(timezone.utc):%Y-%m-%d}, UTC)" + (" — JEU FACTICE" if META["kind"] == "fake" else ""))
w("")
w(f"- GPU : {GPU.get('name', 'aucun (CPU)')} ({GPU.get('memory_gb', '-')} Go) ; paquets : {PKG_KEEP}.")
w(f"- Durée de la session : {ENV.budget.elapsed() / 3600:.2f} h ; étapes : " + ", ".join(f"{k} {v / 60:.1f} min" for k, v in kc.read_json(ENV.state / kc.STAGES_FILE).get("timings", {}).items()) + ".")
w("- Licences : RF-DETR-Seg Nano / Small et paquet `rfdetr` : Apache 2.0 (vérifié le 2026-11-02, README roboflow/rf-detr) ; données MyFoodRepo : CC BY 4.0 (attribution obligatoire).")
w("")
for size, item in SUMMARY.items():
    b = item["bench"]
    w(f"## {size}")
    w(f"- Débit mesuré : {b['train_img_per_s']} img/s à l'entraînement (lot {b['batch_size']}) ; époque complète estimée à {b['epoch_seconds_estimate'] / 60:.1f} min "
      f"pour {b['full_images']['train']} images d'entraînement et {b['full_images']['valid']} de validation.")
    m = item.get("metrics")
    if m:
        f3 = lambda x: "-" if x is None else f"{x:.3f}"
        w(f"- TEST officiel ({m['images']} images) : mAP de masque {f3(m['segm']['AP'])} (AP50 {f3(m['segm']['AP50'])}), mAP de boîte {f3(m['bbox']['AP'])} ; "
          f"IoU moyen par aliment {f3(m['per_food']['mean_iou'])}, Dice {f3(m['per_food']['mean_dice'])} (seuil {m['per_food']['op_threshold']}).")
        w(f"- Rapport complet : `segmenter-{size}.md` ; modèle : `models/segmenter-{size}/`.")
    w("")
if NOTES:
    w("## Remarques")
    for n in NOTES:
        w(f"- {n}")
    w("")
w("## Ensuite")
w("1. Télécharger l'onglet « Output » dans `C:\\Users\\Etudiant\\ardane-tools\\ml\\kaggle-outputs\\`.")
w("2. L'export Core ML n'est PAS validé tant que `parity` n'a pas tourné sur macOS (Core ML ne prédit que sous macOS). Ne rien livrer avant.")
w("3. Ne pas livrer sans la mesure sur les repas pesés (chantier 22.6).")
_text = "\n".join(L) + "\n"
(ENV.out / "RESULTS-segmenter.md").write_text(_text, encoding="utf-8")
kc.persist(ENV)
print(_text)
for _p in sorted(ENV.out.iterdir()):
    _size = kc.dir_size(_p) if _p.is_dir() else _p.stat().st_size
    print(f"{_p.name:24s} {_size / 1048576:9.1f} Mo")
'''),
]
