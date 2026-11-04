"""Aides communes des carnets Kaggle d'Ardane (classifieur DINOv2 et segmenteur RF-DETR-Seg) : chantier 22.3.

Ce module est EMBARQUÉ dans les deux carnets par `build_notebooks.py` (avec le code de `scripts/ml/`), puis importé par eux.
Il ne dépend de rien d'autre que de la bibliothèque standard (torch n'est importé que dans `gpu_check`).

Ce qu'il apporte :
  - les chemins (`detect_env`) : données lourdes dans `/kaggle/temp` (non conservées), tout ce qui doit survivre dans `/kaggle/working` ;
  - la REPRISE (`restore_state`, `persist`, `mark_stage`, `stage_done`) : un dossier `ardane_state/` dans la sortie du carnet. Si la session
    s'arrête, la sortie de la version précédente, ajoutée comme source de données, est retrouvée et recopiée ;
  - le BUDGET de temps (`Budget`) : une session Kaggle dure 12 h au plus ; chaque étape longue regarde le temps restant et s'arrête
    PROPREMENT (point de sauvegarde écrit, sortie conservée) au lieu d'être coupée ;
  - `run_logged` (sous-processus dont la sortie est journalisée), `zip_mlpackage`, `find_myfoodrepo`, `gpu_check`.
"""
from __future__ import annotations

import fnmatch
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
import zipfile
from contextlib import contextmanager
from dataclasses import dataclass, field
from datetime import datetime, timezone
from itertools import islice
from pathlib import Path

SESSION_LIMIT_HOURS = 12.0          # durée maximale d'une session Kaggle (GPU)
STATE_DIR_NAME = "ardane_state"     # dossier de reprise, dans /kaggle/working
STAGES_FILE = "stages.json"
# Ce qui n'est PAS recopié dans l'état de reprise (lourd ou reconstructible) :
MIRROR_EXCLUDE_DIRS = ("crops", "shards-*", "torch_home", "export", "__pycache__", "*.mlpackage", "seg_data", "bench_run", "tensorboard")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def log(message: str = "") -> None:
    print(message, flush=True)


# --------------------------------------------------------------------------- budget de temps

class Budget:
    """Temps de session restant. `limit_hours` : plafond de la plateforme ; `reserve_hours` : marge gardée pour le dernier
    export, les rapports et l'écriture de la sortie (jamais entamée par une étape d'entraînement)."""

    def __init__(self, t0: float, limit_hours: float = SESSION_LIMIT_HOURS, reserve_hours: float = 1.0):
        self.t0, self.limit_hours, self.reserve_hours = t0, limit_hours, reserve_hours

    def elapsed(self) -> float:
        return time.time() - self.t0

    def remaining(self, keep_reserve: bool = True) -> float:
        """Secondes avant l'échéance (réserve déduite par défaut)."""
        return (self.limit_hours - (self.reserve_hours if keep_reserve else 0.0)) * 3600.0 - self.elapsed()

    def can_run(self, seconds_needed: float) -> bool:
        return self.remaining() >= seconds_needed

    def __repr__(self) -> str:
        return f"Budget(écoulé {self.elapsed() / 3600:.2f} h, restant {self.remaining() / 3600:.2f} h, réserve {self.reserve_hours} h)"


# --------------------------------------------------------------------------- environnement

@dataclass
class Env:
    kaggle: bool
    smoke: bool
    input_root: Path          # /kaggle/input
    out: Path                 # /kaggle/working : tout ce qui est écrit ici est conservé (onglet « Output »)
    state: Path               # out / ardane_state : reprise
    ml_root: Path             # ARDANE_ML_ROOT : données lourdes (recadrages...) et modèles, NON conservés
    code_dir: Path            # code embarqué (scripts/ml + ce module)
    logs: Path                # out / logs
    budget: Budget
    export_python: str = sys.executable
    export_env: dict = field(default_factory=dict)
    notes: list = field(default_factory=list)

    def environ(self, extra: dict | None = None) -> dict:
        """Variables d'environnement pour les sous-processus (racine ML, pas de .pyc écrits dans le code embarqué)."""
        env = dict(os.environ)
        env.update({"ARDANE_ML_ROOT": str(self.ml_root), "PYTHONDONTWRITEBYTECODE": "1", "PYTHONUNBUFFERED": "1",
                    "PYTHONIOENCODING": "utf-8", "XFORMERS_DISABLED": "1"})      # DINOv2 : attention standard, identique à la chaîne CPU
        env.update(extra or {})
        return env


def _pick_heavy_dir(preferred: str) -> Path:
    """`/kaggle/temp` s'il est utilisable (espace non compté dans la sortie), sinon `/tmp`."""
    for candidate in (preferred, "/tmp"):
        try:
            Path(candidate).mkdir(parents=True, exist_ok=True)
            probe = Path(candidate) / ".ardane_probe"
            probe.write_text("x")
            probe.unlink()
            return Path(candidate)
        except OSError:
            continue
    raise RuntimeError("aucun dossier temporaire utilisable")


def detect_env(t0: float, code_dir: str | Path, smoke_dir: str | Path | None = None,
               limit_hours: float = SESSION_LIMIT_HOURS, reserve_hours: float = 1.0) -> Env:
    """Chemins du carnet. Sur Kaggle : /kaggle/input, /kaggle/working, /kaggle/temp. En essai local (`smoke_dir` donné) : tout sous ce dossier."""
    if smoke_dir:
        base = Path(smoke_dir)
        env = Env(kaggle=False, smoke=True, input_root=base / "input", out=base / "working", state=base / "working" / STATE_DIR_NAME,
                  ml_root=base / "temp" / "ardane_ml", code_dir=Path(code_dir), logs=base / "working" / "logs",
                  budget=Budget(t0, limit_hours, reserve_hours))
    else:
        on_kaggle = Path("/kaggle/working").exists()
        out = Path("/kaggle/working") if on_kaggle else Path.cwd() / "working"
        heavy = _pick_heavy_dir("/kaggle/temp") if on_kaggle else Path.cwd() / "temp"
        env = Env(kaggle=on_kaggle, smoke=False, input_root=Path("/kaggle/input"), out=out, state=out / STATE_DIR_NAME,
                  ml_root=heavy / "ardane_ml", code_dir=Path(code_dir), logs=out / "logs", budget=Budget(t0, limit_hours, reserve_hours))
    for path in (env.out, env.state, env.ml_root, env.logs):
        path.mkdir(parents=True, exist_ok=True)
    return env


def gpu_check() -> dict:
    """Décrit le GPU et vérifie qu'un vrai calcul y tourne (un GPU trop récent ou trop ancien pour la version de torch échoue ici,
    avec « no kernel image », au lieu d'échouer au milieu d'une étape longue)."""
    info: dict = {"cuda": False}
    try:
        import torch
    except Exception as exc:                       # noqa: BLE001
        return {"cuda": False, "error": f"torch indisponible : {exc}"}
    info["torch"] = torch.__version__
    if not torch.cuda.is_available():
        return info
    info.update({"cuda": True, "count": torch.cuda.device_count(), "name": torch.cuda.get_device_name(0),
                 "capability": ".".join(map(str, torch.cuda.get_device_capability(0))),
                 "memory_gb": round(torch.cuda.get_device_properties(0).total_memory / 2 ** 30, 1)})
    try:
        a = torch.randn(256, 256, device="cuda")
        b = (a @ a).sum().item()
        with torch.autocast("cuda", dtype=torch.float16):
            (a @ a).sum().item()
        info["compute_ok"] = bool(b == b)
    except Exception as exc:                       # noqa: BLE001
        info["compute_ok"] = False
        info["error"] = str(exc)[:300]
    return info


# --------------------------------------------------------------------------- jeu de données

def find_myfoodrepo(input_root: Path, max_depth: int = 5) -> dict:
    """Retrouve les annotations COCO de MyFoodRepo sous /kaggle/input, quelle que soit la mise en page exacte.

    Attendu (jeu `awsaf49/food-recognition-2022-dataset`, MyFoodRepo v2.0) :
        <...>/public_training_set_release_2.0/{images/, annotations.json}
        <...>/public_validation_set_2.0/{images/, annotations.json}       <- TEST officiel (jamais utilisé pour régler)
        <...>/public_test_release_2.0/images/                              <- sans annotations : ignoré
    Le classement se fait sur le NOM du dossier (contient « train » -> entraînement ; « val » -> TEST officiel).
    """
    found: dict[str, Path] = {}
    base_depth = len(input_root.parts)
    for root, dirs, files in os.walk(input_root):
        depth = len(Path(root).parts) - base_depth
        dirs[:] = [d for d in sorted(dirs) if d not in ("images", "img", "masks", ARDANE_STATE_SKIP)] if depth < max_depth else []
        if "annotations.json" not in files:
            continue
        name = Path(root).name.lower()
        role = "train" if "train" in name else ("val" if "val" in name else ("test" if "test" in name else None))
        if role in ("train", "val") and role not in found:
            found[role] = Path(root)
    if "train" not in found or "val" not in found:
        listing = sorted(p.name for p in input_root.iterdir()) if input_root.exists() else []
        raise FileNotFoundError(
            f"MyFoodRepo introuvable sous {input_root} (trouvé : {sorted(found)}). Contenu : {listing}. Ajouter le jeu "
            "`awsaf49/food-recognition-2022-dataset` au carnet (« Add Data »).")
    result: dict = {}
    for role, folder in found.items():
        images_dir = next((c for c in (folder / "images", folder / "data", folder)
                           if c.is_dir() and any(p.suffix.lower() in (".jpg", ".jpeg", ".png") for p in islice(c.iterdir(), 20))), None)
        if images_dir is None:
            raise FileNotFoundError(f"aucune image dans {folder}")
        result[f"{role}_json"] = folder / "annotations.json"
        result[f"{role}_images"] = images_dir
    return result


ARDANE_STATE_SKIP = STATE_DIR_NAME      # ne jamais chercher le jeu dans un dossier de reprise


# --------------------------------------------------------------------------- reprise

def _read_stages(state_dir: Path) -> dict:
    path = state_dir / STAGES_FILE
    if path.exists():
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            pass
    return {"stages": {}, "updated_at": ""}


def stage_done(env: Env, name: str) -> bool:
    return bool(_read_stages(env.state)["stages"].get(name, {}).get("done"))


def stage_info(env: Env, name: str) -> dict:
    return _read_stages(env.state)["stages"].get(name, {})


def mark_stage(env: Env, name: str, done: bool = True, **info) -> None:
    data = _read_stages(env.state)
    data["stages"][name] = {"done": done, "at": now_iso(), **info}
    data["updated_at"] = now_iso()
    data["session_hours"] = round(env.budget.elapsed() / 3600, 3)
    tmp = env.state / (STAGES_FILE + ".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(tmp, env.state / STAGES_FILE)


@contextmanager
def timed(env: Env, name: str):
    """Mesure une étape : les secondes sont inscrites dans stages.json (clé `seconds_<name>`) pour le rapport final."""
    t = time.time()
    yield
    data = _read_stages(env.state)
    data.setdefault("timings", {})[name] = round(time.time() - t, 1)
    (env.state / STAGES_FILE).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    log(f"[{name}] {time.time() - t:.0f} s")


def mirror(src: Path, dst: Path, exclude_dirs=MIRROR_EXCLUDE_DIRS) -> int:
    """Copie `src` dans `dst` (fichiers nouveaux ou modifiés seulement), sans les dossiers lourds. Retourne le nombre de fichiers copiés."""
    copied = 0
    if not src.exists():
        return 0
    for root, dirs, files in os.walk(src):
        dirs[:] = [d for d in dirs if not any(fnmatch.fnmatch(d, pattern) for pattern in exclude_dirs)]
        rel = Path(root).relative_to(src)
        for name in files:
            if name.endswith((".tmp", ".tmp.npy")):
                continue
            source, target = Path(root) / name, dst / rel / name
            if target.exists() and target.stat().st_size == source.stat().st_size and target.stat().st_mtime >= source.stat().st_mtime - 2:
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
            copied += 1
    return copied


def persist(env: Env) -> None:
    """Point de sauvegarde : recopie l'essentiel de `ml_root` (classes, vecteurs, têtes, rapports, points de contrôle) dans l'état de reprise."""
    t = time.time()
    n = mirror(env.ml_root, env.state / "ml")
    n += mirror(env.out / "models", env.state / "out_models", exclude_dirs=("__pycache__",))      # zips Core ML, points de contrôle, exports déjà produits
    log(f"[reprise] état sauvegardé dans {env.state} ({n} fichiers copiés, {time.time() - t:.0f} s)")


def find_previous_state(env: Env, max_depth: int = 4) -> Path | None:
    """Cherche un `ardane_state/` laissé par une session précédente et fourni comme source de données (jeu ou sortie de carnet)."""
    best: tuple[str, Path] | None = None
    base_depth = len(env.input_root.parts)
    if not env.input_root.exists():
        return None
    for root, dirs, files in os.walk(env.input_root):
        depth = len(Path(root).parts) - base_depth
        if Path(root).name == STATE_DIR_NAME and STAGES_FILE in files:
            stamp = _read_stages(Path(root))["updated_at"]
            if best is None or stamp > best[0]:
                best = (stamp, Path(root))
            dirs[:] = []
            continue
        dirs[:] = [d for d in dirs if d not in ("images", "img")] if depth < max_depth else []
    return best[1] if best else None


def restore_state(env: Env) -> dict | None:
    """Reprend la session précédente si elle est fournie en entrée. Ne remplace jamais un état plus récent déjà présent."""
    previous = find_previous_state(env)
    if previous is None:
        log("[reprise] aucun état précédent en entrée : départ à zéro.")
        return None
    mine, theirs = _read_stages(env.state), _read_stages(previous)
    if mine["updated_at"] >= theirs["updated_at"] and mine["stages"]:
        log("[reprise] l'état déjà présent est au moins aussi récent : rien à restaurer.")
        return mine
    n = mirror(previous / "ml", env.ml_root, exclude_dirs=())
    n += mirror(previous / "out_models", env.out / "models", exclude_dirs=())      # les livrables déjà produits restent dans la sortie de cette session
    shutil.copy2(previous / STAGES_FILE, env.state / STAGES_FILE)
    done = [k for k, v in theirs["stages"].items() if v.get("done")]
    log(f"[reprise] état restauré depuis {previous} ({n} fichiers) ; étapes terminées : {', '.join(done) or 'aucune'} ; "
        f"session précédente : {theirs.get('session_hours', '?')} h.")
    return theirs


# --------------------------------------------------------------------------- sous-processus, fichiers

def run_logged(command: list[str], log_name: str, env: Env, *, cwd: Path | None = None, extra_env: dict | None = None,
               check: bool = True, python_env: bool = True) -> int:
    """Lance une commande, recopie sa sortie à l'écran ET dans `logs/<log_name>.log`. Retourne le code de sortie."""
    log_path = env.logs / f"{log_name}.log"
    log(f"$ {' '.join(str(c) for c in command)}")
    environ = env.environ(extra_env) if python_env else dict(os.environ, **(extra_env or {}))
    t = time.time()
    with open(log_path, "a", encoding="utf-8", errors="replace") as sink:
        sink.write(f"\n##### {now_iso()}  {' '.join(str(c) for c in command)}\n")
        proc = subprocess.Popen([str(c) for c in command], cwd=str(cwd or env.code_dir), env=environ, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", bufsize=1)
        assert proc.stdout is not None
        for line in proc.stdout:
            sink.write(line)                                      # le journal complet va dans logs/
            if "%|" in line and "100%" not in line:               # barres de progression (tqdm) : un affichage par barre terminée, pas des milliers de lignes
                continue
            print(line, end="", flush=True)
        code = proc.wait()
        sink.write(f"##### code de sortie {code} en {time.time() - t:.0f} s\n")
    if check and code != 0:
        raise RuntimeError(f"« {' '.join(str(c) for c in command[:3])}... » a échoué (code {code}) ; voir {log_path}")
    return code


def file_sha256(path: Path, chunk: int = 1 << 22) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while block := f.read(chunk):
            h.update(block)
    return h.hexdigest()


def dir_size(path: Path) -> int:
    return sum(p.stat().st_size for p in Path(path).rglob("*") if p.is_file())


def zip_mlpackage(package: Path, out_dir: Path) -> dict:
    """Un `.mlpackage` est un DOSSIER : on le range dans un zip (`<nom>.mlpackage.zip`) pour le télécharger d'un bloc."""
    out_dir.mkdir(parents=True, exist_ok=True)
    target = out_dir / f"{package.name}.zip"
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED, compresslevel=1) as z:
        for path in sorted(package.rglob("*")):
            z.write(path, Path(package.name) / path.relative_to(package))
    return {"zip": target.name, "zip_bytes": target.stat().st_size, "package_bytes": dir_size(package), "sha256": file_sha256(target)}


def human(n: float) -> str:
    return f"{n / 1048576:.1f} Mo"


# --------------------------------------------------------------------------- environnement d'export Core ML

EXPORT_REQUIREMENTS = ["torch==2.7.0+cpu", "coremltools==9.0", "numpy<2.3", "pillow", "protobuf"]


def start_export_env(env: Env) -> subprocess.Popen | None:
    """Installe EN ARRIÈRE-PLAN (pendant la préparation des données) l'environnement d'export validé par la chaîne CPU :
    torch 2.7.0 (CPU) + coremltools 9.0, dans un dossier à part (`pip install --target`) qui passe devant le torch du carnet via PYTHONPATH.
    Évite de dépendre de la version de torch fournie par l'image Kaggle, que coremltools 9 n'a pas testée."""
    if env.smoke:
        env.export_python, env.export_env = sys.executable, {}
        return None
    target = env.ml_root.parent / "export_env"
    env.export_python = sys.executable
    env.export_env = {"PYTHONPATH": f"{target}{os.pathsep}{os.environ.get('PYTHONPATH', '')}".rstrip(os.pathsep)}
    command = [sys.executable, "-m", "pip", "install", "-q", "--target", str(target), "--extra-index-url",
               "https://download.pytorch.org/whl/cpu", *EXPORT_REQUIREMENTS]
    sink = open(env.logs / "export-env-install.log", "w", encoding="utf-8")
    log(f"[export] installation de l'environnement d'export en arrière-plan : {' '.join(EXPORT_REQUIREMENTS)} -> {target}")
    return subprocess.Popen(command, stdout=sink, stderr=subprocess.STDOUT)


def wait_export_env(env: Env, proc: subprocess.Popen | None) -> bool:
    """Attend la fin de l'installation. Retourne False (et le dit) si elle a échoué : l'export Core ML est alors à refaire sous WSL/macOS."""
    if proc is None:
        return True
    code = proc.wait()
    if code != 0:
        tail = (env.logs / "export-env-install.log").read_text(encoding="utf-8", errors="replace")[-1500:]
        log(f"[export] ÉCHEC de l'installation de l'environnement d'export (code {code}). Fin du journal :\n{tail}")
        return False
    log("[export] environnement d'export prêt.")
    return True


# --------------------------------------------------------------------------- paquets, sorties

def ensure_imports(pairs: list[tuple[str, str]]) -> None:
    """Installe (pip) les paquets légers qui manqueraient dans l'image du carnet. Ne touche jamais à torch."""
    import importlib

    for module, package in pairs:
        try:
            importlib.import_module(module)
        except ImportError:
            log(f"[paquets] {module} absent : pip install {package}")
            subprocess.run([sys.executable, "-m", "pip", "install", "-q", package], check=True)


def collect_export(env: Env, dataset: str, variant: str, name: str = "") -> list[dict]:
    """Range les `.mlpackage` de `models/<jeu>/export` en zips dans `out/models/`, et les petits fichiers (classes, résumé, attribution) à côté.
    `name` (nom du modèle passé à export_coreml.py) : ne prendre que ses fichiers, quand deux têtes du même jeu sont exportées."""
    export_dir = env.ml_root / "models" / dataset / "export"
    results: list[dict] = []
    if not export_dir.exists():
        return results
    prefix = f"{name}-" if name else ""
    for package in sorted(export_dir.glob(f"{prefix}*.mlpackage")):
        info = zip_mlpackage(package, env.out / "models")
        info["variant"] = variant
        results.append(info)
        log(f"[export] {info['zip']} : {human(info['zip_bytes'])} (paquet {human(info['package_bytes'])})")
    side = env.out / "models" / variant
    side.mkdir(parents=True, exist_ok=True)
    for path in export_dir.iterdir():
        if path.is_file() and (not name or path.name.startswith((name + ".", prefix)) or path.name == "ATTRIBUTIONS.txt"):
            shutil.copy2(path, side / path.name)
    return results


def collect_outputs(env: Env, datasets: list[str]) -> None:
    """Copie dans la sortie ce qui doit être téléchargé : rapports d'entraînement, têtes et DINOv2 affiné, table des classes."""
    (env.out / "reports").mkdir(exist_ok=True)
    (env.out / "weights").mkdir(exist_ok=True)
    for path in sorted((env.ml_root / "reports").glob("classifier-*")):
        shutil.copy2(path, env.out / "reports" / path.name)
    for dataset in datasets:
        for path in sorted((env.ml_root / "models" / dataset).glob("head-*.pt")):
            shutil.copy2(path, env.out / "weights" / f"{dataset}-{path.name}")
        ft = env.ml_root / "work" / dataset / "ft"
        for name in ("finetuned-backbone.pt", "summary.json"):
            if (ft / name).exists():
                shutil.copy2(ft / name, env.out / "weights" / f"{dataset}-{name}")
    first = env.ml_root / "work" / datasets[0]
    for name in ("classes.json", "class_stats.csv", "meta.json"):
        if (first / name).exists():
            shutil.copy2(first / name, env.out / name)
    if (env.code_dir / "class_map.csv").exists():
        shutil.copy2(env.code_dir / "class_map.csv", env.out / "class_map.csv")


# --------------------------------------------------------------------------- rapport

def read_json(path: Path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def pct(x: float | None, digits: int = 1) -> str:
    return "-" if x is None else f"{100 * x:.{digits}f} %"
