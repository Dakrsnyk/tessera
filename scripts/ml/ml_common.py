"""Briques communes de la chaîne d'entraînement du classifieur d'aliments (chantier 22.3, jalon A).

Tout ce qui doit être IDENTIQUE entre la préparation, l'extraction des vecteurs, l'entraînement et
l'export Core ML vit ici : le modèle de base (DINOv2 ViT-S/14, figé), la normalisation des pixels,
la façon de découper un recadrage et les chemins de travail. Ce fichier est la source de vérité :
si deux scripts divergent sur ces points, le Core ML ne donnera pas les mêmes probabilités que
l'entraînement.

Aucune donnée ni aucun poids dans le dépôt : tout vit sous `ARDANE_ML_ROOT`
(par défaut `~/ardane-tools/ml`, soit `C:\\Users\\Etudiant\\ardane-tools\\ml` sous Windows).
"""
from __future__ import annotations

import csv
import hashlib
import json
import os
import sys
from pathlib import Path

# --------------------------------------------------------------------------- chemins

REPO = Path(__file__).resolve().parents[2]
SCRIPT_DIR = Path(__file__).resolve().parent


def ml_root(cli_value: str | None = None) -> Path:
    """Racine des données (jamais dans le dépôt) : option --root, sinon ARDANE_ML_ROOT, sinon ~/ardane-tools/ml."""
    value = cli_value or os.environ.get("ARDANE_ML_ROOT")
    root = Path(value).expanduser() if value else Path.home() / "ardane-tools" / "ml"
    root.mkdir(parents=True, exist_ok=True)
    return root


def work_dir(root: Path, dataset: str) -> Path:
    path = root / "work" / dataset
    path.mkdir(parents=True, exist_ok=True)
    return path


def models_dir(root: Path, dataset: str) -> Path:
    path = root / "models" / dataset
    path.mkdir(parents=True, exist_ok=True)
    return path


def reports_dir(root: Path) -> Path:
    path = root / "reports"
    path.mkdir(parents=True, exist_ok=True)
    return path


def setup_torch_home(root: Path) -> None:
    """Les poids téléchargés par torch.hub restent sous la racine ML (et pas dans le profil utilisateur)."""
    os.environ.setdefault("TORCH_HOME", str(root / "torch_home"))


# --------------------------------------------------------------------------- modèle de base

# Poids et code officiels de Meta (Apache 2.0), épinglés sur un commit pour que la chaîne soit reproductible.
HUB_REPO = "facebookresearch/dinov2"
HUB_COMMIT = "7764ea0f912e53c92e82eb78a2a1631e92725fc8"
# Variante du modèle de base, choisie par la variable d'environnement ARDANE_DINOV2 (« vits14 » par défaut : chaîne inchangée ;
# « vitb14 » : modèle plus grand, essayé le 2026-11-04 pour dépasser le plafond d'environ 50 % du ViT-S sur MyFoodRepo).
# SHA-256 mesurés sur les fichiers téléchargés des URL officielles : vits14 le 2026-11-02 (84,2 Mo), vitb14 le 2026-11-04.
DINOV2_VARIANTS = {
    "vits14": {"embed_dim": 384, "sha256": "b938bf1bc15cd2ec0feacfe3a1bb553fe8ea9ca46a7e1d8d00217f29aef60cd9"},
    "vitb14": {"embed_dim": 768, "sha256": "0b8b82f85de91b424aded121c7e1dcc2b7bc6d0adeea651bf73a13307fad8c73"},
}
DINOV2_VARIANT = os.environ.get("ARDANE_DINOV2", "vits14")
if DINOV2_VARIANT not in DINOV2_VARIANTS:
    raise ValueError(f"ARDANE_DINOV2 inconnu : {DINOV2_VARIANT} (attendu : {', '.join(DINOV2_VARIANTS)})")
HUB_MODEL = f"dinov2_{DINOV2_VARIANT}"
HUB_WEIGHTS_FILE = f"dinov2_{DINOV2_VARIANT}_pretrain.pth"
HUB_WEIGHTS_URL = f"https://dl.fbaipublicfiles.com/dinov2/dinov2_{DINOV2_VARIANT}/dinov2_{DINOV2_VARIANT}_pretrain.pth"
HUB_WEIGHTS_SHA256 = DINOV2_VARIANTS[DINOV2_VARIANT]["sha256"]
EMBED_DIM = DINOV2_VARIANTS[DINOV2_VARIANT]["embed_dim"]

IMAGE_SIZE = 224          # 16 x 16 patchs de 14 pixels
IMAGENET_MEAN = (0.485, 0.456, 0.406)
IMAGENET_STD = (0.229, 0.224, 0.225)
POOLS = {"cls_mean": 2 * EMBED_DIM, "cls": EMBED_DIM}   # dimension du vecteur selon l'agrégation (768 / 384 pour le ViT-S)

ATTRIBUTION_DINOV2 = "DINOv2 (Meta Platforms, Inc.), licence Apache 2.0 : github.com/facebookresearch/dinov2"
ATTRIBUTION_MYFOODREPO = (
    "MyFoodRepo / AIcrowd Food Recognition Benchmark 2022 (jeu de données du projet MyFoodRepo, myfoodrepo.org), "
    "licence CC BY 4.0 : creativecommons.org/licenses/by/4.0/"
)


def file_sha256(path: Path, chunk: int = 1 << 20) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while block := f.read(chunk):
            h.update(block)
    return h.hexdigest()


def load_dinov2_backbone(root: Path | None = None, verify: bool = True, weights_path: Path | str | None = None):
    """DINOv2 ViT-S/14 officiel via torch.hub (code épinglé sur HUB_COMMIT). Retourne le module en mode éval.

    `weights_path` (option, défaut None = comportement inchangé) : fichier `state_dict` d'un DINOv2 AFFINÉ par nos soins
    (voir scripts/ml/kaggle/classifier/finetune_dinov2.py), chargé par-dessus l'architecture officielle (strict).
    Les poids officiels sont d'abord téléchargés et vérifiés comme d'habitude ; l'affinage les remplace ensuite.
    """
    import torch

    if root is not None:
        setup_torch_home(root)
    model = torch.hub.load(f"{HUB_REPO}:{HUB_COMMIT}", HUB_MODEL, pretrained=True, trust_repo=True, verbose=False)
    model.eval()
    if verify:
        weights = Path(torch.hub.get_dir()) / "checkpoints" / HUB_WEIGHTS_FILE
        if weights.exists():
            digest = file_sha256(weights)
            if digest != HUB_WEIGHTS_SHA256:
                raise RuntimeError(
                    f"Les poids téléchargés ne correspondent pas à l'empreinte attendue ({digest}). "
                    "Supprimer le fichier et recommencer, ou mettre à jour HUB_WEIGHTS_SHA256 après vérification."
                )
    if weights_path is not None:
        state = torch.load(str(weights_path), map_location="cpu", weights_only=True)
        model.load_state_dict(state, strict=True)
        model.eval()
    return model


def make_feature_net(backbone, pool: str = "cls_mean"):
    """Enveloppe `FeatureNet` : image 0..255 (RGB, NCHW) -> vecteur. Voir la classe pour les détails."""
    import torch
    from torch import nn

    if pool not in POOLS:
        raise ValueError(f"agrégation inconnue : {pool}")

    class FeatureNet(nn.Module):
        """Pixels 0..255 -> normalisation ImageNet -> DINOv2 -> vecteur (CLS, ou CLS + moyenne des patchs).

        Deux choix qui rendent l'export Core ML exact :
        - la normalisation est faite ICI (opérations du graphe), donc l'entrée Core ML est une simple image 0..255
          sans échelle ni biais par canal ;
        - l'encodage de position est calculé UNE fois pour 224 x 224 (par la fonction d'origine de DINOv2) puis figé :
          on évite l'interpolation bicubique dynamique, qui se convertit mal et ne sert à rien pour une taille fixe.
        """

        def __init__(self, backbone, pool):
            super().__init__()
            self.backbone = backbone
            self.pool = pool
            self.register_buffer("mean", torch.tensor(IMAGENET_MEAN).view(1, 3, 1, 1) * 255.0)
            self.register_buffer("std", torch.tensor(IMAGENET_STD).view(1, 3, 1, 1) * 255.0)
            n_patches = (IMAGE_SIZE // backbone.patch_size) ** 2
            with torch.no_grad():
                dummy = torch.zeros(1, n_patches + 1, backbone.embed_dim)
                fixed = backbone.interpolate_pos_encoding(dummy, IMAGE_SIZE, IMAGE_SIZE).detach().clone()
            self.register_buffer("fixed_pos_embed", fixed, persistent=False)
            backbone.interpolate_pos_encoding = lambda x, w, h: self.fixed_pos_embed.to(x.dtype)

        def forward(self, pixels):
            x = (pixels - self.mean) / self.std
            out = self.backbone.forward_features(x)
            cls_token = out["x_norm_clstoken"]
            if self.pool == "cls":
                return cls_token
            return torch.cat([cls_token, out["x_norm_patchtokens"].mean(dim=1)], dim=1)

    return FeatureNet(backbone, pool).eval()


def class_label(cls: dict) -> str:
    """Étiquette Core ML d'une classe : `mfr:<nom de classe MyFoodRepo>` (le NOM est la clé stable, identique dans le COCO
    d'AIcrowd et dans le projet Supervisely de Dataset Ninja ; les numéros de classe, eux, diffèrent d'un format à l'autre)."""
    return f"mfr:{cls['name']}"


def rebuild_head(ck: dict):
    """Reconstruit la tête (linéaire ou MLP) depuis un fichier `head-*.pt` ; la normalisation y est déjà intégrée."""
    from torch import nn

    dim, n = ck["dim"], ck["n_classes"]
    head = nn.Linear(dim, n) if ck["kind"] == "linear" else nn.Sequential(
        nn.Linear(dim, ck["hidden"]), nn.GELU(), nn.Dropout(0.0), nn.Linear(ck["hidden"], n))
    head.load_state_dict(ck["state_dict"])
    return head.eval()


def make_full_net(feat, head, temperature: float, with_embedding: bool = True):
    """Modèle complet exporté : pixels 0..255 -> (probabilités étalonnées[, embedding]). Partagé par l'export et la parité."""
    import torch
    from torch import nn

    class FullNet(nn.Module):
        def __init__(self):
            super().__init__()
            self.feat, self.head, self.with_embedding = feat, head, with_embedding
            self.register_buffer("inv_t", torch.tensor(1.0 / temperature))

        def forward(self, image):
            embedding = self.feat(image)
            probabilities = torch.softmax(self.head(embedding) * self.inv_t, dim=1)
            return (probabilities, embedding) if self.with_embedding else probabilities

    return FullNet().eval()


# --------------------------------------------------------------------------- recadrages

def square_crop_box(bbox, image_size, margin: float):
    """Boîte carrée centrée sur la boîte de l'instance, agrandie de `margin` de chaque côté.

    bbox = (x, y, w, h) en pixels ; image_size = (W, H). Retourne (x0, y0, x1, y1) flottants, éventuellement
    débordant de l'image si le carré ne tient pas (le recadrage complète alors avec du gris).
    """
    x, y, w, h = bbox
    cx, cy = x + w / 2.0, y + h / 2.0
    side = max(w, h) * (1.0 + 2.0 * margin)
    side = max(side, 8.0)
    x0, y0 = cx - side / 2.0, cy - side / 2.0
    width, height = image_size
    if side <= min(width, height):
        # le carré tient dans l'image : on le décale pour ne pas sortir (plus de contexte réel, pas de gris)
        x0 = min(max(x0, 0.0), width - side)
        y0 = min(max(y0, 0.0), height - side)
    return (x0, y0, x0 + side, y0 + side)


def crop_square(image, bbox, margin: float, out_size: int = IMAGE_SIZE):
    """Recadrage carré `out_size` x `out_size` de l'instance (PIL.Image RGB). Règle unique, aussi pour l'app plus tard."""
    from PIL import Image

    box = square_crop_box(bbox, image.size, margin)
    side = box[2] - box[0]
    pad_color = tuple(int(round(m * 255)) for m in IMAGENET_MEAN)
    x0, y0, x1, y1 = box
    if x0 >= 0 and y0 >= 0 and x1 <= image.size[0] and y1 <= image.size[1]:
        patch = image.crop((int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))))
    else:
        canvas = Image.new("RGB", (int(round(side)), int(round(side))), pad_color)
        src = image.crop((max(int(round(x0)), 0), max(int(round(y0)), 0),
                          min(int(round(x1)), image.size[0]), min(int(round(y1)), image.size[1])))
        canvas.paste(src, (max(int(round(-x0)), 0), max(int(round(-y0)), 0)))
        patch = canvas
    return patch.resize((out_size, out_size), Image.BICUBIC)


def dhash(image, hash_size: int = 8) -> int:
    """Empreinte de différence 64 bits : sert à repérer les photos quasi identiques (fuite entre découpes)."""
    from PIL import Image

    small = image.convert("L").resize((hash_size + 1, hash_size), Image.LANCZOS)
    pixels = list(small.getdata())
    bits = 0
    for row in range(hash_size):
        for col in range(hash_size):
            bits = (bits << 1) | (1 if pixels[row * (hash_size + 1) + col] > pixels[row * (hash_size + 1) + col + 1] else 0)
    return bits


# --------------------------------------------------------------------------- petits utilitaires

def read_json(path: Path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def write_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def read_csv(path: Path) -> list[dict]:
    with open(path, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def write_csv(path: Path, rows: list[dict], fields: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def log(message: str) -> None:
    print(message, flush=True)


def fail(message: str) -> None:
    print(f"ERREUR : {message}", file=sys.stderr, flush=True)
    raise SystemExit(1)
