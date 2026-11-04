"""Affinage de RF-DETR-Seg (Nano, puis Small) sur MyFoodRepo : lancement, mesure du débit, reprise, budget de temps.

API vérifiée dans le paquet `rfdetr` 1.11.2 (PyPI, 2026-10-04 ; entraînement par PyTorch Lightning) :
  - `RFDETRSegNano()` / `RFDETRSegSmall()` : poids COCO d'origine téléchargés par la bibliothèque (storage.googleapis.com/rfdetr/rf-detr-seg-{n,s}-ft.pth) ;
  - `model.train(dataset_dir=..., epochs=..., batch_size=..., grad_accum_steps=..., lr=..., output_dir=..., resume=...)` avec un `dataset_dir`
    à la mise en page Roboflow COCO (voir seg_dataset.py) ; le nombre de classes est détecté depuis train/_annotations.coco.json ;
  - points de sauvegarde dans `output_dir` : `last.ckpt` (état Lightning complet, réécrit à chaque époque : sert à REPRENDRE avec `resume=`),
    `checkpoint_best_total.pth` / `checkpoint_best_ema.pth` / `checkpoint_best_regular.pth` (meilleurs poids sur la VALIDATION, mAP de masque).

Le budget de temps : `rfdetr` n'offre pas d'arrêt par durée ; on branche un callback Lightning (`ArdaneCallback`) sur le Trainer en enveloppant
`rfdetr.training.build_trainer` pendant `train()`. À la fin de chaque époque, il (1) mesure sa durée, (2) appelle `persist_fn` (copie vers l'état de
reprise), (3) demande `can_continue(durée estimée de l'époque suivante)` et, si non, demande l'arrêt (`trainer.should_stop`) : `last.ckpt`
de cette époque est déjà écrit, la reprise se fait avec `resume=last.ckpt` (même `epochs` : le calendrier de taux d'apprentissage en dépend).
"""
from __future__ import annotations

import json
import statistics
import time
from contextlib import contextmanager
from pathlib import Path

SIZES = {
    # taille : (classe rfdetr, résolution d'entrée par défaut, lot par défaut sur GPU 16 Go)
    "nano": ("RFDETRSegNano", 312, 16),
    "small": ("RFDETRSegSmall", 384, 12),
}
LICENSE = {"nano": "Apache 2.0", "small": "Apache 2.0"}   # vérifié le 2026-11-02 : README du dépôt roboflow/rf-detr, section « License » (voir README.md)


def model_class(size: str):
    import rfdetr

    return getattr(rfdetr, SIZES[size][0])


def steady_median(times: list[float]) -> float:
    """Médiane des durées de lot SANS la chauffe : écarte les 5 premiers lots (1 seul si la série est courte)."""
    skip = 5 if len(times) >= 12 else (1 if len(times) >= 2 else 0)
    values = times[skip:] or times
    return statistics.median(values) if values else 0.0


def make_callback(can_continue=None, persist_fn=None, jsonl_path: Path | None = None, log=print, batch_size: int = 1):
    """Callback Lightning : durée des époques, débit, journal JSONL, point de sauvegarde, arrêt propre si le budget manque."""
    from pytorch_lightning.callbacks import Callback

    class ArdaneCallback(Callback):
        def __init__(self):
            super().__init__()
            self.step_times: list[float] = []
            self.epoch_seconds: list[float] = []
            self.val_seconds: list[float] = []
            self.paused = False
            self._t_epoch = self._t_last = self._t_val = 0.0

        def on_train_epoch_start(self, trainer, pl_module):
            self._t_epoch = self._t_last = time.time()

        def on_train_batch_end(self, trainer, pl_module, outputs, batch, batch_idx):
            now = time.time()
            self.step_times.append(now - self._t_last)
            self._t_last = now
            if (batch_idx + 1) % 200 == 0:
                recent = self.step_times[-200:]
                log(f"    lot {batch_idx + 1}/{trainer.num_training_batches} : {batch_size / statistics.median(recent):.1f} img/s (médiane des 200 derniers lots)")

        def on_validation_start(self, trainer, pl_module):
            self._t_val = time.time()

        def on_validation_end(self, trainer, pl_module):
            self.val_seconds.append(time.time() - self._t_val)

        def on_train_epoch_end(self, trainer, pl_module):
            seconds = time.time() - self._t_epoch
            self.epoch_seconds.append(seconds)
            entry = {"epoch": trainer.current_epoch + 1, "seconds": round(seconds, 1), "val_seconds": round(self.val_seconds[-1], 1) if self.val_seconds else None,
                     "median_step_s": round(steady_median(self.step_times), 4) if self.step_times else None}
            metrics = {k: float(v) for k, v in trainer.callback_metrics.items() if k.startswith("val/") and getattr(v, "ndim", 0) == 0}
            entry["val_metrics"] = {k: round(v, 4) for k, v in list(metrics.items())[:12]}
            log(f"[segmenteur] époque {entry['epoch']}/{trainer.max_epochs} terminée en {seconds / 60:.1f} min ; {entry['val_metrics']}")
            if jsonl_path is not None:
                with open(jsonl_path, "a", encoding="utf-8") as f:
                    f.write(json.dumps(entry, ensure_ascii=False) + "\n")
            if persist_fn is not None:
                persist_fn()
            if can_continue is not None and trainer.current_epoch + 1 < trainer.max_epochs and not can_continue(max(self.epoch_seconds) * 1.2):
                self.paused = True
                trainer.should_stop = True
                log("[segmenteur] budget de session insuffisant pour une époque de plus : PAUSE (reprise possible avec last.ckpt).")

    return ArdaneCallback()


@contextmanager
def patched_trainer(callback):
    """Pendant `train()`, ajoute `callback` au Trainer construit par rfdetr (`rfdetr.training.build_trainer`, importé à l'appel)."""
    import rfdetr.training as training

    original = training.build_trainer

    def build(*args, **kwargs):
        trainer = original(*args, **kwargs)
        trainer.callbacks.append(callback)
        return trainer

    training.build_trainer = build
    try:
        yield
    finally:
        training.build_trainer = original


def train(size: str, dataset_dir: Path, run_dir: Path, *, epochs: int, batch_size: int | None = None, grad_accum: int = 1, lr: float | None = None,
          lr_encoder: float | None = None, num_workers: int = 4, resume: Path | None = None, can_continue=None, persist_fn=None,
          device: str | None = None, seed: int = 20261102, log=print, extra: dict | None = None, pretrain_weights: Path | None = None) -> dict:
    """Entraîne (ou reprend) un segmenteur. Retourne {paused, epoch_seconds, ...}. Sur manque de mémoire GPU : relance avec lot / 2 et accumulation x 2.

    `pretrain_weights` : point de départ autre que les poids COCO (ex. le segmenteur à 498 classes déjà affiné sur MyFoodRepo) ; RF-DETR
    charge tout et réajuste la tête de classes au nombre de classes du jeu (`rfdetr.models.weights.load_pretrain_weights`)."""
    run_dir.mkdir(parents=True, exist_ok=True)
    batch_size = batch_size or SIZES[size][2]
    attempt = 0
    while True:
        callback = make_callback(can_continue, persist_fn, run_dir / "epochs.jsonl", log, batch_size)
        kwargs = dict(dataset_dir=str(dataset_dir), epochs=epochs, batch_size=batch_size, grad_accum_steps=grad_accum, output_dir=str(run_dir),
                      num_workers=num_workers, checkpoint_interval=1000, tensorboard=False, seed=seed, progress_bar=None)
        if lr is not None:
            kwargs["lr"] = lr
        if lr_encoder is not None:
            kwargs["lr_encoder"] = lr_encoder
        if device:
            kwargs["device"] = device
        if resume is not None and Path(resume).exists():
            kwargs["resume"] = str(resume)
        kwargs.update(extra or {})
        model = model_class(size)(pretrain_weights=str(pretrain_weights)) if pretrain_weights else model_class(size)()
        t0 = time.time()
        try:
            with patched_trainer(callback):
                model.train(**kwargs)
        except RuntimeError as exc:
            if "out of memory" in str(exc).lower() and batch_size > 1 and attempt < 3:
                attempt += 1
                batch_size, grad_accum = max(1, batch_size // 2), grad_accum * 2
                log(f"[segmenteur] manque de mémoire GPU : nouvel essai avec lot {batch_size} et accumulation {grad_accum}")
                import gc
                import torch

                del model
                gc.collect()
                torch.cuda.empty_cache()
                continue
            raise
        return {"paused": callback.paused, "epoch_seconds": callback.epoch_seconds, "val_seconds": callback.val_seconds, "batch_size": batch_size,
                "grad_accum": grad_accum, "seconds": round(time.time() - t0, 1), "median_step_s": steady_median(callback.step_times)}


def measure_throughput(size: str, small_dataset_dir: Path, run_dir: Path, *, n_train: int, n_valid: int, full_train: int, full_valid: int,
                       batch_size: int | None = None, num_workers: int = 4, device: str | None = None, log=print) -> dict:
    """MESURE RÉELLE du débit : une époque sur un petit sous-ensemble, puis extrapolation à l'époque complète.

    Retourne {train_img_per_s, val_img_per_s, epoch_seconds_estimate, ...}. Les 5 premiers lots (chauffe, mise en cache) sont exclus.
    L'estimation inclut la validation (calcul des mAP de masque) et 20 s de surcoût fixe par époque.
    """
    batch_size = batch_size or SIZES[size][2]
    result = train(size, small_dataset_dir, run_dir, epochs=1, batch_size=batch_size, num_workers=num_workers, device=device, log=log,
                   extra={"eval_interval": 1})
    step = result["median_step_s"]
    if not step:
        raise RuntimeError("débit non mesurable (aucun lot terminé)")
    train_rate = result["batch_size"] / step
    val_rate = (n_valid / result["val_seconds"][-1]) if result["val_seconds"] and result["val_seconds"][-1] > 0 else None
    estimate = full_train / train_rate + (full_valid / val_rate if val_rate else 0.0) + 20.0
    out = {"size": size, "batch_size": result["batch_size"], "median_step_s": step, "train_img_per_s": round(train_rate, 2),
           "val_img_per_s": round(val_rate, 2) if val_rate else None, "epoch_seconds_estimate": round(estimate, 1),
           "bench_images": {"train": n_train, "valid": n_valid}, "full_images": {"train": full_train, "valid": full_valid}}
    (run_dir.parent / f"bench-{size}.json").write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    log(f"[segmenteur] débit mesuré ({size}) : {train_rate:.1f} img/s à l'entraînement ; époque complète estimée à {estimate / 60:.1f} min")
    return out


def plan_epochs(epoch_seconds: float, budget_seconds: float, epochs_max: int) -> int:
    """Nombre d'époques qui tient dans le budget (marge 10 % sur la durée mesurée), au plus `epochs_max`, au moins 0."""
    return max(0, min(epochs_max, int(budget_seconds // (epoch_seconds * 1.1))))
