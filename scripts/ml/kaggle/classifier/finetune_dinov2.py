"""Variante B du classifieur : affinage PARTIEL de DINOv2 ViT-S/14 (derniers blocs + tête), avec augmentations.

Pourquoi : la voie A gèle DINOv2 et n'entraîne qu'une tête linéaire sur des vecteurs fixes. Ici on laisse les K derniers blocs du transformeur
(et la normalisation finale) s'adapter aux aliments, en partant EXACTEMENT de la voie A (la tête de départ est la tête A repliée : à l'époque 0 le
modèle reproduit A au logit près ; l'arrêt anticipé garde la meilleure époque, donc B ne peut pas finir pire que A sur la VALIDATION).

Principes (comme la voie A) :
  - mêmes recadrages 224 x 224 (prepare_myfoodrepo.py), mêmes classes (celles de la tête A), même normalisation (FeatureNet de ml_common.py,
    la normalisation ImageNet est DANS le graphe : l'export Core ML reste une simple image 0..255) ;
  - le TEST officiel n'est JAMAIS lu ici : seuls train (entraînement) et val (arrêt anticipé) le sont ;
  - poids de classe n^-alpha (comme train_head.py), pas de fuite (les découpes sont celles de prepare_myfoodrepo.py).

Ce que fait ce module :
  1. `finetune(...)` : boucle d'entraînement reprenable (point de sauvegarde à chaque époque), qui s'arrête proprement quand le budget de
     temps de la session ne permet plus une époque de plus ; écrit `finetuned-backbone.pt` (state_dict du DINOv2 affiné, meilleure époque).
  2. `make_derived_workdir(...)` : prépare `work/<jeu>-B/` (mêmes classes, mêmes recadrages, chemins absolus) pour que les scripts existants
     (`extract_features.py --backbone-weights`, `train_head.py`, `export_coreml.py --backbone-weights`) fonctionnent SANS changement : on
     ré-extrait les vecteurs avec le DINOv2 affiné (gelé), on ré-entraîne une tête linéaire étalonnée par température, et on exporte.

Recette v5 (2026-11-23, options ; valeurs par défaut = comportement v4) : moyenne mobile exponentielle des poids (EMA, évaluée et retenue à la place des
poids bruts), Mixup / CutMix alternés par lot, échauffement en époques, meilleure époque choisie sur l'EXACTITUDE de validation (patience en
époques), augmentation « boîte imparfaite » (voir `augment`). Mêmes données, mêmes classes, mêmes 224 x 224 : l'interface de l'app ne change pas.

Augmentations (sur le GPU, sur le lot) : zoom avant 0,72-1, translation et rotation légères (+-10 degrés), miroir horizontal, luminosité,
contraste, saturation. Pas de retournement vertical (une assiette vue de dessus est tournée, mais l'app ne retourne pas la photo).
"""
from __future__ import annotations

import csv
import json
import math
import os
import shutil
import time
from pathlib import Path

import numpy as np

# --------------------------------------------------------------------------- données


class CropDataset:
    """Recadrages 224 x 224 -> (uint8 CHW, étiquette). Le décodage JPEG se fait dans les processus du DataLoader."""

    def __init__(self, paths: list[str], labels: np.ndarray):
        self.paths, self.labels = paths, labels

    def __len__(self) -> int:
        return len(self.paths)

    def __getitem__(self, i: int):
        import torch
        from PIL import Image

        with Image.open(self.paths[i]) as im:
            im = im.convert("RGB")
            if im.size != (224, 224):
                im = im.resize((224, 224), Image.BICUBIC)
            arr = np.array(im, dtype=np.uint8)          # copie (inscriptible) : torch.from_numpy refuse les tableaux en lecture seule
        return torch.from_numpy(arr).permute(2, 0, 1).contiguous(), int(self.labels[i])


def read_crops(work: Path, kept_names: list[str], classes: list[dict]):
    """{split: (chemins, étiquettes)} pour les classes de la tête A, étiquette = rang dans la tête (même ordre que `head-linear.pt`)."""
    index_of = {c["name"]: c["index"] for c in classes}
    head_pos = {index_of[name]: pos for pos, name in enumerate(kept_names)}
    out: dict[str, tuple[list[str], list[int]]] = {s: ([], []) for s in ("train", "val", "test")}
    with open(work / "crops.csv", encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            pos = head_pos.get(int(row["class_index"]))
            if pos is None:
                continue
            path = Path(row["crop"])
            out[row["split"]][0].append(str(path if path.is_absolute() else work / path))
            out[row["split"]][1].append(pos)
    return {s: (p, np.array(y, dtype=np.int64)) for s, (p, y) in out.items()}


# --------------------------------------------------------------------------- augmentations (torch pur, sur le lot)

# « Boîte imparfaite » (v5). L'app recadre sur la boîte d'un MASQUE PRÉDIT, pas sur une boîte humaine. Le réglage v4 (zoom 0,72-1, décalage 0,08 en
# coordonnées normalisées = 4 % du côté) ne couvre que les boîtes trop SERRÉES (zoom avant) et de petits décalages ; il ne montre jamais un cadrage trop
# LARGE (masque qui déborde sur le voisin, plats fusionnés) ni un décalage marqué. Le préréglage ajoute un peu de zoom arrière (jusqu'à 1,12 : la zone
# hors photo est remplie de la couleur moyenne ImageNet, comme `ml_common.crop_square`) et un décalage de 0,10 (5 % du côté). Modéré à dessein : le
# TEST officiel utilise des boîtes humaines, trop de zoom arrière y coûterait en précision. Ce préréglage n'est PAS mesurable sur ce test.
BOX_AUG_V4 = {"zoom": (0.72, 1.0), "shift": 0.08}
BOX_AUG_IMPERFECT = {"zoom": (0.68, 1.12), "shift": 0.10}
IMAGENET_MEAN_255 = (0.485 * 255.0, 0.456 * 255.0, 0.406 * 255.0)   # = ml_common.IMAGENET_MEAN * 255 (couleur de remplissage des recadrages)


def augment(x, zoom=(0.72, 1.0), rotate_deg=10.0, shift=0.08, flip=True, brightness=0.25, contrast=0.25, saturation=0.3, pad_mean=False):
    """x : (B, 3, H, W) float 0..255 sur l'appareil de calcul. Retourne un lot de même forme, même plage.
    pad_mean=False : bords réfléchis (v4, zoom <= 1 : jamais utilisés). True : zones hors image = couleur moyenne ImageNet (zoom arrière)."""
    import torch
    import torch.nn.functional as F

    b, dev = x.shape[0], x.device
    scale = torch.empty(b, device=dev).uniform_(*zoom)                       # fraction du côté conservé (zoom avant)
    angle = torch.empty(b, device=dev).uniform_(-rotate_deg, rotate_deg) * math.pi / 180.0
    tx = torch.empty(b, device=dev).uniform_(-shift, shift)
    ty = torch.empty(b, device=dev).uniform_(-shift, shift)
    sign = torch.where(torch.rand(b, device=dev) < 0.5, -1.0, 1.0) if flip else torch.ones(b, device=dev)
    cos, sin = torch.cos(angle), torch.sin(angle)
    theta = torch.stack([torch.stack([scale * cos * sign, -scale * sin, tx], 1),
                         torch.stack([scale * sin * sign, scale * cos, ty], 1)], 1)           # (B, 2, 3)
    grid = F.affine_grid(theta, list(x.shape), align_corners=False)
    if pad_mean:
        fill = torch.tensor(IMAGENET_MEAN_255, device=dev, dtype=x.dtype).view(1, 3, 1, 1)
        y = F.grid_sample(x - fill, grid, mode="bilinear", padding_mode="zeros", align_corners=False) + fill
    else:
        y = F.grid_sample(x, grid, mode="bilinear", padding_mode="reflection", align_corners=False)
    gray = (0.299 * y[:, 0:1] + 0.587 * y[:, 1:2] + 0.114 * y[:, 2:3])
    y = gray + (y - gray) * (1.0 + torch.empty(b, 1, 1, 1, device=dev).uniform_(-saturation, saturation))
    mean = y.mean(dim=(1, 2, 3), keepdim=True)
    y = (y - mean) * (1.0 + torch.empty(b, 1, 1, 1, device=dev).uniform_(-contrast, contrast)) + mean
    y = y * (1.0 + torch.empty(b, 1, 1, 1, device=dev).uniform_(-brightness, brightness))
    return y.clamp_(0.0, 255.0)


# --------------------------------------------------------------------------- modèle

def build_model(ml_root: Path, head_ck: dict, unfreeze_blocks: int, device):
    """FeatureNet (ml_common) + tête linéaire initialisée avec la tête A repliée. Seuls les K derniers blocs, la norme finale et la tête apprennent."""
    from torch import nn

    from ml_common import load_dinov2_backbone, make_feature_net

    feat = make_feature_net(load_dinov2_backbone(ml_root), head_ck["pool"])
    backbone = feat.backbone
    n_blocks = len(backbone.blocks)
    if not 1 <= unfreeze_blocks <= n_blocks:
        raise ValueError(f"unfreeze_blocks doit être entre 1 et {n_blocks}")
    for p in feat.parameters():
        p.requires_grad_(False)
    for block in backbone.blocks[n_blocks - unfreeze_blocks:]:
        for p in block.parameters():
            p.requires_grad_(True)
    for p in backbone.norm.parameters():
        p.requires_grad_(True)
    head = nn.Linear(head_ck["dim"], head_ck["n_classes"])
    if head_ck["kind"] != "linear":
        raise ValueError("la tête de départ doit être linéaire (voie A)")
    head.load_state_dict(head_ck["state_dict"])
    model = nn.ModuleDict({"feat": feat, "head": head}).to(device)
    return model


def param_groups(model, base_lr: float, head_lr: float, layer_decay: float, weight_decay: float, unfreeze_blocks: int):
    """Taux d'apprentissage décroissant avec la profondeur (dernier bloc = base_lr), décroissance des poids sauf biais et normes."""
    backbone = model["feat"].backbone
    n_blocks = len(backbone.blocks)
    groups = []

    def add(params, lr, tag):
        decay = [p for n, p in params if p.requires_grad and p.ndim > 1]
        no_decay = [p for n, p in params if p.requires_grad and p.ndim <= 1]
        if decay:
            groups.append({"params": decay, "lr": lr, "base_lr": lr, "weight_decay": weight_decay, "tag": tag})
        if no_decay:
            groups.append({"params": no_decay, "lr": lr, "base_lr": lr, "weight_decay": 0.0, "tag": tag + "-nodecay"})

    for j, block in enumerate(backbone.blocks[n_blocks - unfreeze_blocks:]):
        depth_from_end = unfreeze_blocks - 1 - j
        add(list(block.named_parameters()), base_lr * (layer_decay ** depth_from_end), f"block{n_blocks - unfreeze_blocks + j}")
    add(list(backbone.norm.named_parameters()), base_lr, "norm")
    groups.append({"params": list(model["head"].parameters()), "lr": head_lr, "base_lr": head_lr, "weight_decay": 0.0, "tag": "head"})
    return groups


def trainable_state(model) -> dict:
    """Seulement ce qui apprend (le reste est rechargé depuis les poids officiels) : points de sauvegarde petits."""
    names = {n for n, p in model.named_parameters() if p.requires_grad}
    return {k: v.detach().cpu().clone() for k, v in model.state_dict().items() if k in names}


# --------------------------------------------------------------------------- EMA, Mixup / CutMix

class Ema:
    """Moyenne mobile exponentielle des paramètres ENTRAÎNÉS (le reste est gelé, donc identique). Décroissance : `decay` plafonnée à
    1 - 1/max(10, total_steps / 4) (horizon d'au plus un quart de l'entraînement : adapté au nombre de pas) et réchauffée par (1+n)/(10+n),
    pour que les premières époques ne soient pas écrasées par les poids de départ."""

    def __init__(self, model, decay: float, total_steps: int):
        import torch

        self.names = [n for n, p in model.named_parameters() if p.requires_grad]
        params = dict(model.named_parameters())
        self.shadow = [params[n].detach().clone().float() for n in self.names]
        self.decay = min(decay, 1.0 - 1.0 / max(10.0, total_steps / 4.0))
        self.n = 0
        self._torch = torch

    def update(self, model) -> None:
        torch = self._torch
        params = dict(model.named_parameters())
        self.n += 1
        d = min(self.decay, (1.0 + self.n) / (10.0 + self.n))
        with torch.no_grad():
            torch._foreach_lerp_(self.shadow, [params[n].detach().float() for n in self.names], 1.0 - d)

    def swap_in(self, model) -> list:
        """Met les poids EMA dans le modèle ; retourne les poids bruts à remettre avec `restore`."""
        torch = self._torch
        params = dict(model.named_parameters())
        raw = [params[n].detach().clone() for n in self.names]
        with torch.no_grad():
            for n, w in zip(self.names, self.shadow):
                params[n].copy_(w)
        return raw

    def restore(self, model, raw: list) -> None:
        torch = self._torch
        params = dict(model.named_parameters())
        with torch.no_grad():
            for n, w in zip(self.names, raw):
                params[n].copy_(w)

    def state(self) -> dict:
        return {n: w.detach().cpu().clone() for n, w in zip(self.names, self.shadow)}

    def checkpoint(self) -> dict:
        return {"state": self.state(), "n": self.n}

    def load(self, ck: dict, device) -> None:
        self.shadow = [ck["state"][n].to(device).float() for n in self.names]
        self.n = ck["n"]


def mix_batch(x, y, rng, mixup_alpha: float, cutmix_alpha: float, prob: float):
    """Mixup OU CutMix (alternés, 50 / 50) sur ce lot avec la probabilité `prob`. Retourne (x, y_a, y_b, lam) : perte = lam*CE(y_a) + (1-lam)*CE(y_b)."""
    import torch

    if prob <= 0.0 or rng.random() >= prob:
        return x, y, y, 1.0
    perm = torch.randperm(x.shape[0], device=x.device)
    if rng.random() < 0.5:                                   # Mixup : combinaison convexe des deux images
        lam = float(rng.beta(mixup_alpha, mixup_alpha))
        x = lam * x + (1.0 - lam) * x[perm]
    else:                                                    # CutMix : un rectangle de l'autre image ; lam = aire réellement conservée
        lam = float(rng.beta(cutmix_alpha, cutmix_alpha))
        h, w = x.shape[2], x.shape[3]
        ch, cw = int(h * math.sqrt(1.0 - lam)), int(w * math.sqrt(1.0 - lam))
        cy, cx = int(rng.integers(0, h)), int(rng.integers(0, w))
        y0, y1, x0, x1 = max(cy - ch // 2, 0), min(cy + ch // 2, h), max(cx - cw // 2, 0), min(cx + cw // 2, w)
        x = x.clone()
        x[:, :, y0:y1, x0:x1] = x[perm][:, :, y0:y1, x0:x1]
        lam = 1.0 - ((y1 - y0) * (x1 - x0)) / float(h * w)
    return x, y, y[perm], lam


# --------------------------------------------------------------------------- boucle

def evaluate(model, loader, device, use_amp: bool):
    """(perte, exactitude) sur un jeu, sans augmentation."""
    import torch
    import torch.nn.functional as F

    model.eval()
    total, correct, loss_sum = 0, 0, 0.0
    with torch.inference_mode():
        for xb, yb in loader:
            xb, yb = xb.to(device, non_blocking=True).float(), yb.to(device, non_blocking=True)
            with torch.autocast(device_type="cuda", dtype=torch.float16, enabled=use_amp):
                logits = model["head"](model["feat"](xb))
            loss_sum += float(F.cross_entropy(logits.float(), yb, reduction="sum"))
            correct += int((logits.argmax(1) == yb).sum())
            total += len(yb)
    return loss_sum / max(total, 1), correct / max(total, 1)


def finetune(ml_root: Path, dataset: str, head_file: str, out_dir: Path, *, unfreeze_blocks: int = 6, epochs: int = 10, batch: int = 128,
             base_lr: float = 3e-5, head_lr: float = 1e-4, layer_decay: float = 0.85, weight_decay: float = 0.05,
             label_smoothing: float = 0.05, balance_alpha: float = 0.5, patience: int = 3, warmup_steps: int = 200,
             workers: int = 4, seed: int = 20261102, device: str = "auto", amp: bool = True, max_train: int = 0, max_val: int = 0,
             ema_decay: float = 0.0, mix_prob: float = 0.0, mixup_alpha: float = 0.2, cutmix_alpha: float = 1.0, select: str = "val_loss",
             box_aug: str = "v4", warmup_epochs: float = 0.0, lr_floor: float = 0.05, can_continue=None, log=print) -> dict:
    """Affine et retourne un résumé. `can_continue(seconds_next_epoch)` -> bool : demandé avant chaque époque (budget de session).

    Reprise : si `out_dir/ckpt.pt` existe, l'entraînement repart de l'époque suivante (optimiseur, calendrier, meilleur état, historique
    restaurés). Les paramètres d'apprentissage doivent être les mêmes ; sinon le point de sauvegarde est ignoré (et le dit).
    Options v5 (défauts = v4) : `ema_decay` > 0 active l'EMA (validation, point retenu et sortie = poids EMA) ; `mix_prob` > 0 active Mixup / CutMix ;
    `select` = "val_acc" choisit la meilleure époque sur l'exactitude de validation (sinon la perte) ; `box_aug` = "imperfect" élargit zoom et
    décalage ; `warmup_epochs` > 0 fixe l'échauffement en époques (sinon `warmup_steps`).
    Statut retourné : "done" (arrêt anticipé ou toutes les époques), "paused" (budget : relancer avec l'état de reprise).
    """
    import torch
    import torch.nn.functional as F
    from torch.utils.data import DataLoader

    if select not in ("val_loss", "val_acc") or box_aug not in ("v4", "imperfect"):
        raise ValueError("select : val_loss | val_acc ; box_aug : v4 | imperfect")
    t_start = time.time()
    out_dir.mkdir(parents=True, exist_ok=True)
    work = ml_root / "work" / dataset
    dev = torch.device("cuda" if (device == "auto" and torch.cuda.is_available()) or device == "cuda" else "cpu")
    use_amp = bool(amp and dev.type == "cuda")
    head_ck = torch.load(ml_root / "models" / dataset / head_file, map_location="cpu", weights_only=False)
    classes = json.loads((work / "classes.json").read_text(encoding="utf-8"))
    kept = [c["name"] for c in head_ck["classes"]]
    data = read_crops(work, kept, classes)
    n_classes = len(kept)
    train_paths, ytr = data["train"]
    val_paths, yva = data["val"]
    if max_train:
        rng = np.random.default_rng(seed)
        keep = np.sort(rng.choice(len(ytr), size=min(max_train, len(ytr)), replace=False))
        train_paths, ytr = [train_paths[i] for i in keep], ytr[keep]
    if max_val:
        val_paths, yva = val_paths[:max_val], yva[:max_val]
    if len(ytr) == 0 or len(yva) == 0:
        raise RuntimeError("entraînement ou validation vide")
    log(f"[B] {len(ytr)} recadrages d'entraînement, {len(yva)} de validation, {n_classes} classes ; appareil {dev}"
        f"{' (AMP fp16)' if use_amp else ''} ; {unfreeze_blocks} derniers blocs affinés")

    torch.manual_seed(seed)
    np.random.seed(seed)
    model = build_model(ml_root, head_ck, unfreeze_blocks, dev)
    trainable = [n for n, p in model.named_parameters() if p.requires_grad]
    n_train_params = sum(p.numel() for n, p in model.named_parameters() if p.requires_grad)
    log(f"[B] paramètres entraînés : {n_train_params / 1e6:.2f} M sur {sum(p.numel() for p in model.parameters()) / 1e6:.2f} M")
    counts = np.bincount(ytr, minlength=n_classes).astype(np.float64)
    weights = np.power(np.maximum(counts, 1.0), -balance_alpha)
    weights = weights / weights[ytr].mean()
    class_w = torch.tensor(weights, dtype=torch.float32, device=dev)

    pin = dev.type == "cuda"
    mk = lambda paths, y, shuffle, gen=None: DataLoader(  # noqa: E731
        CropDataset(paths, y), batch_size=batch, shuffle=shuffle, num_workers=workers, pin_memory=pin, drop_last=shuffle, generator=gen,
        persistent_workers=False)
    val_loader = mk(val_paths, yva, False)
    steps_per_epoch = max(1, len(ytr) // batch)
    total_steps = steps_per_epoch * epochs
    if warmup_epochs > 0:
        warmup_steps = max(warmup_steps, int(round(warmup_epochs * steps_per_epoch)))

    groups = param_groups(model, base_lr, head_lr, layer_decay, weight_decay, unfreeze_blocks)
    opt = torch.optim.AdamW(groups, betas=(0.9, 0.999))

    def lr_factor(step: int) -> float:
        if step < warmup_steps:
            return (step + 1) / warmup_steps
        progress = (step - warmup_steps) / max(1, total_steps - warmup_steps)
        return lr_floor + (1.0 - lr_floor) * 0.5 * (1.0 + math.cos(math.pi * min(1.0, progress)))

    scaler = torch.amp.GradScaler("cuda", enabled=use_amp)
    ckpt_path = out_dir / "ckpt.pt"
    hyper = {"unfreeze_blocks": unfreeze_blocks, "epochs": epochs, "batch": batch, "base_lr": base_lr, "head_lr": head_lr,
             "layer_decay": layer_decay, "weight_decay": weight_decay, "label_smoothing": label_smoothing,
             "balance_alpha": balance_alpha, "patience": patience, "warmup_steps": warmup_steps, "seed": seed,
             "n_train": int(len(ytr)), "n_val": int(len(yva)), "n_classes": n_classes}
    ema = Ema(model, ema_decay, total_steps) if ema_decay > 0 else None
    aug_kw = ({**BOX_AUG_IMPERFECT, "pad_mean": True} if box_aug == "imperfect" else {})
    if ema_decay > 0:
        hyper["ema_decay"] = ema_decay
    if mix_prob > 0:
        hyper.update({"mix_prob": mix_prob, "mixup_alpha": mixup_alpha, "cutmix_alpha": cutmix_alpha})
    if select != "val_loss":
        hyper["select"] = select
    if box_aug != "v4":
        hyper["box_aug"] = box_aug
    if warmup_epochs > 0 or lr_floor != 0.05:
        hyper.update({"warmup_epochs": warmup_epochs, "lr_floor": lr_floor})
    if ema is not None:
        log(f"[B] EMA des poids : décroissance effective {ema.decay:.5f} (demandée {ema_decay}), validation et point retenu avec les poids EMA")
    history: list[dict] = []
    best = {"val_loss": float("inf"), "val_acc": -1.0, "epoch": 0, "state": None}
    start_epoch, waited, step = 1, 0, 0
    epoch_seconds: list[float] = []

    # Époque 0 = la voie A telle quelle : référence de validation (et premier « meilleur » état)
    if ckpt_path.exists():
        ck = torch.load(ckpt_path, map_location="cpu", weights_only=False)
        if ck.get("hyper") == hyper:
            model.load_state_dict({**model.state_dict(), **ck["trainable"]})
            opt.load_state_dict(ck["opt"])
            scaler.load_state_dict(ck["scaler"])
            history, best, waited, step = ck["history"], ck["best"], ck["waited"], ck["step"]
            if ema is not None:
                ema.load(ck["ema"], dev)
            start_epoch, epoch_seconds = ck["epoch"] + 1, ck.get("epoch_seconds", [])
            log(f"[B] reprise après l'époque {ck['epoch']} (meilleure : {best['epoch']}, perte de validation {best['val_loss']:.4f}, exactitude {best.get('val_acc', -1.0):.4f})")
        else:
            log("[B] point de sauvegarde ignoré : les réglages ont changé.")
    if not history:
        v_loss, v_acc = evaluate(model, val_loader, dev, use_amp)
        history.append({"epoch": 0, "val_loss": v_loss, "val_acc": v_acc, "train_loss": None, "seconds": 0.0})
        best = {"val_loss": v_loss, "val_acc": v_acc, "epoch": 0, "state": trainable_state(model)}
        log(f"[B] époque 0 (= voie A) : perte de validation {v_loss:.4f}, exactitude {v_acc:.4f}")

    status = "done"
    images_per_second = None
    epoch = start_epoch - 1
    for epoch in range(start_epoch, epochs + 1):
        if waited >= patience:
            break
        estimate = (max(epoch_seconds) * 1.25 if epoch_seconds else 600.0)
        if can_continue is not None and not can_continue(estimate):
            status = "paused"
            log(f"[B] budget de session insuffisant pour l'époque {epoch} (estimée {estimate:.0f} s) : PAUSE, reprise possible.")
            break
        t_epoch = time.time()
        torch.manual_seed(seed * 1000 + epoch)
        gen = torch.Generator().manual_seed(seed + epoch)
        loader = mk(train_paths, ytr, True, gen)
        model.train()
        mix_rng = np.random.default_rng(seed * 1000 + epoch)
        loss_sum, seen, t_log = 0.0, 0, time.time()
        for bi, (xb, yb) in enumerate(loader):
            for g in opt.param_groups:
                g["lr"] = g["base_lr"] * lr_factor(step)
            xb, yb = xb.to(dev, non_blocking=True).float(), yb.to(dev, non_blocking=True)
            xb = augment(xb, **aug_kw)
            xb, y_a, y_b, lam = mix_batch(xb, yb, mix_rng, mixup_alpha, cutmix_alpha, mix_prob)
            opt.zero_grad(set_to_none=True)
            with torch.autocast(device_type="cuda", dtype=torch.float16, enabled=use_amp):
                logits = model["head"](model["feat"](xb))
            loss = F.cross_entropy(logits.float(), y_a, weight=class_w, label_smoothing=label_smoothing)
            if lam < 1.0:
                loss = lam * loss + (1.0 - lam) * F.cross_entropy(logits.float(), y_b, weight=class_w, label_smoothing=label_smoothing)
            scaler.scale(loss).backward()
            scaler.unscale_(opt)
            torch.nn.utils.clip_grad_norm_([p for p in model.parameters() if p.requires_grad], 1.0)
            scaler.step(opt)
            scaler.update()
            if ema is not None:
                ema.update(model)
            step += 1
            loss_sum += float(loss) * len(yb)
            seen += len(yb)
            if (bi + 1) % 100 == 0:
                log(f"    époque {epoch} lot {bi + 1}/{steps_per_epoch} : perte {loss_sum / seen:.4f} ; {100 * batch / (time.time() - t_log):.0f} img/s")
                t_log = time.time()
        train_seconds = time.time() - t_epoch
        if ema is not None:
            raw = ema.swap_in(model)
            try:
                v_loss, v_acc = evaluate(model, val_loader, dev, use_amp)
            finally:
                ema.restore(model, raw)
        else:
            v_loss, v_acc = evaluate(model, val_loader, dev, use_amp)
        seconds = time.time() - t_epoch
        epoch_seconds.append(seconds)
        images_per_second = seen / train_seconds
        history.append({"epoch": epoch, "val_loss": v_loss, "val_acc": v_acc, "train_loss": loss_sum / max(seen, 1), "seconds": round(seconds, 1)})
        if select == "val_acc":              # exactitude ; à égalité exacte, la perte la plus basse
            improved = v_acc > best.get("val_acc", -1.0) + 1e-9 or (abs(v_acc - best.get("val_acc", -1.0)) <= 1e-9 and v_loss < best["val_loss"] - 1e-5)
        else:
            improved = v_loss < best["val_loss"] - 1e-5
        if improved:
            best, waited = {"val_loss": v_loss, "val_acc": v_acc, "epoch": epoch, "state": ema.state() if ema is not None else trainable_state(model)}, 0
        else:
            waited += 1
        log(f"[B] époque {epoch}/{epochs} : perte d'entraînement {loss_sum / max(seen, 1):.4f}, perte de validation {v_loss:.4f}, "
            f"exactitude {v_acc:.4f}{' *' if improved else ''} ; {seconds:.0f} s ({images_per_second:.0f} img/s d'entraînement)")
        tmp = out_dir / "ckpt.tmp.pt"
        torch.save({"hyper": hyper, "epoch": epoch, "trainable": trainable_state(model), "opt": opt.state_dict(), "scaler": scaler.state_dict(),
                    "history": history, "best": best, "waited": waited, "step": step, "epoch_seconds": epoch_seconds,
                    **({"ema": ema.checkpoint()} if ema is not None else {})}, tmp)
        os.replace(tmp, ckpt_path)

    summary = {"status": status, "hyper": hyper, "history": history, "best_epoch": best["epoch"], "best_val_loss": best["val_loss"],
               "val_loss_voie_A": history[0]["val_loss"], "val_acc_voie_A": history[0]["val_acc"],
               "val_acc_best": next(h["val_acc"] for h in history if h["epoch"] == best["epoch"]),
               "epochs_run": len(history) - 1, "epoch_seconds": epoch_seconds, "images_per_second": images_per_second,
               "device": str(dev), "amp": use_amp, "seconds": round(time.time() - t_start, 1)}
    if status == "paused":
        (out_dir / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        return summary

    # Meilleure époque -> poids du DINOv2 affiné (state_dict du backbone seul : c'est ce que lisent extract_features / export_coreml)
    model.load_state_dict({**model.state_dict(), **best["state"]})
    weights_path = out_dir / "finetuned-backbone.pt"
    tmp = out_dir / "finetuned-backbone.tmp.pt"
    torch.save({k: v.detach().cpu() for k, v in model["feat"].backbone.state_dict().items()}, tmp)
    os.replace(tmp, weights_path)
    summary["backbone_weights"] = str(weights_path)
    summary["trained_param_names"] = trainable[:3] + ["..."] if len(trainable) > 3 else trainable
    (out_dir / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    log(f"[B] terminé : meilleure époque {best['epoch']} (perte de validation {best['val_loss']:.4f} contre {history[0]['val_loss']:.4f} pour la voie A) -> {weights_path}")
    return summary


# --------------------------------------------------------------------------- dossier de travail dérivé (B)

def make_derived_workdir(ml_root: Path, dataset: str, derived: str, code_dir: Path, note: str) -> Path:
    """`work/<derived>/` = mêmes classes et mêmes recadrages que `work/<dataset>/` (chemins ABSOLUS dans crops.csv, rien n'est copié)."""
    src, dst = ml_root / "work" / dataset, ml_root / "work" / derived
    dst.mkdir(parents=True, exist_ok=True)
    for name in ("classes.json", "class_stats.csv"):
        if (src / name).exists():
            shutil.copy2(src / name, dst / name)
    class_map = code_dir / "class_map.csv"
    if class_map.exists():
        shutil.copy2(class_map, dst / "class_map.csv")
    meta = json.loads((src / "meta.json").read_text(encoding="utf-8"))
    meta.update({"dataset": derived, "derived_from": dataset, "derived_note": note})
    (dst / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    with open(src / "crops.csv", encoding="utf-8", newline="") as f_in, open(dst / "crops.csv", "w", encoding="utf-8", newline="") as f_out:
        reader = csv.DictReader(f_in)
        writer = csv.DictWriter(f_out, fieldnames=reader.fieldnames, lineterminator="\n")
        writer.writeheader()
        for row in reader:
            row["crop"] = str(src / row["crop"])      # chemin absolu (ml_root l'est) : rien à résoudre sur le disque
            writer.writerow(row)
    return dst
