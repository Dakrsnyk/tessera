"""Rapport final du carnet classifieur : RESULTS.md (A contre B, temps, fichiers, ce qu'il reste à faire).

Lit les rapports JSON écrits par `train_head.py` (un par variante) ; ne calcule aucune métrique lui-même : tout chiffre vient d'un
rapport d'entraînement, mesuré sur le TEST officiel (MyFoodRepo « validation 2.0 », jamais utilisé pour régler).
"""
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path


def _pct(x, digits=1):
    return "-" if x is None else f"{100 * x:.{digits}f} %"


def _load(path):
    return json.loads(Path(path).read_text(encoding="utf-8")) if path and Path(path).exists() else None


def latest_report(reports_dir: Path, dataset: str, tag: str = "") -> Path | None:
    """Rapport JSON le plus récent de `train_head.py` pour ce jeu de travail et cette étiquette."""
    suffix = ("" if dataset == "myfoodrepo" else f"-{dataset}") + (f"-{tag}" if tag else "")
    found = sorted(reports_dir.glob("classifier-*.json"), key=lambda p: p.stat().st_mtime)
    exact = [p for p in found if p.stem.endswith(suffix) and (p.stem[len("classifier-"):].count("-") == 2 + suffix.count("-"))]
    return exact[-1] if exact else None


def write_results(out_path: Path, *, fake: bool, gpu: dict, variants: dict, timings: dict, session_hours: float, exports: list[dict],
                  finetune: dict | None, notes: list[str], dataset_note: str) -> str:
    """`variants` : {"A": json, "A-MLP": json|None, "B": json|None} (rapports de train_head). Retourne le texte écrit."""
    L: list[str] = []
    w = L.append
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    w(f"# Classifieur d'aliments : résultats de l'entraînement sur Kaggle ({today}, UTC)" + (" — JEU FACTICE" if fake else ""))
    w("")
    if fake:
        w("> **JEU FACTICE (essai de fumée).** Formes colorées générées, classes inventées. Ces chiffres prouvent seulement que le code tourne de bout en bout. "
          "Ils ne mesurent aucune reconnaissance d'aliments.")
        w("")
    w("> Ce que ces chiffres sont : la reconnaissance d'un recadrage dont la boîte vient d'une annotation humaine, sur des photos suisses "
      "(MyFoodRepo), mesurée sur le **TEST officiel** (jamais utilisé pour régler quoi que ce soit). Ce n'est **pas** la précision d'Ardane sur "
      "l'iPhone : elle sera mesurée sur les repas pesés de l'utilisateur (chantier 22.6).")
    w("")
    w("## Machine et temps")
    w(f"- GPU : {gpu.get('name', 'aucun (CPU)')} (capacité {gpu.get('capability', '-')}, {gpu.get('memory_gb', '-')} Go) ; torch {gpu.get('torch', '?')}.")
    w(f"- Durée de la session : {session_hours:.2f} h.")
    if timings:
        w("- Étapes : " + ", ".join(f"{k} {v / 60:.1f} min" for k, v in timings.items()) + ".")
    w("")
    w("## Jeu de données")
    w(dataset_note)
    w("")
    w("## Comparaison sur le TEST officiel")
    cols = [(k, v) for k, v in variants.items() if v]
    head = "| Mesure | " + " | ".join(
        {"A": "A : tête linéaire, DINOv2 gelé", "A-MLP": "A-MLP : tête MLP, DINOv2 gelé", "B": "B : derniers blocs affinés + tête linéaire",
         "B-MLP": "B-MLP : derniers blocs affinés + tête MLP"}.get(k, k)
        for k, _ in cols) + " |"
    w(head)
    w("|---|" + "---|" * len(cols))

    def row(label, fn):
        w(f"| {label} | " + " | ".join(fn(v) for _, v in cols) + " |")

    row("Classes / recadrages de test", lambda v: f"{v['n_classes']} / {v['n']['test']}")
    row("Top-1 (Wilson 95 %)", lambda v: f"{_pct(v['top1'])} ({_pct(v['top1_wilson95'][0])} à {_pct(v['top1_wilson95'][1])})")
    row("Top-3", lambda v: _pct(v["top3"]))
    row("Rappel moyen par classe", lambda v: _pct(v["macro_recall"]))
    row("ECE (calibration, plus bas = mieux)", lambda v: f"{v['ece']:.4f} (avant étalonnage {v['ece_before_calibration']:.4f})")
    row("NLL", lambda v: f"{v['nll']:.4f}")
    row("Température T (étalonnage sur la validation)", lambda v: f"{v['temperature']:.3f}")
    w("")
    w("### Validation (prélevée dans train : sert à CHOISIR entre variantes, sans toucher au test)")
    w("| Variante | Exactitude (Top-1) | NLL |")
    w("|---|---|---|")
    for k, v in cols:
        val = v.get("val")
        val_top1 = _pct(val["top1"]) if val else "-"
        val_nll = "{:.4f}".format(val["nll"]) if val else "-"
        w(f"| {k} | {val_top1} | {val_nll} |")
    candidates = [(k, v) for k, v in cols if v.get("val")]
    if len(candidates) > 1:
        better = min(candidates, key=lambda kv: kv[1]["val"]["nll"])[0]          # à égalité, le premier (le plus simple) l'emporte
        w("")
        w(f"Choix recommandé **sur la validation** (NLL la plus basse) : **{better}**. "
          f"Comparer ensuite le test pour confirmer, pas pour choisir : choisir sur le test serait un biais optimiste (léger avec {len(candidates)} candidats, mais réel). "
          "La mesure qui compte reste celle des repas pesés.")
    w("")
    if finetune:
        w("## Affinage B : déroulement")
        h = finetune["hyper"]
        w(f"- {h['unfreeze_blocks']} derniers blocs sur 12 affinés (+ norme finale + tête), taux {h['base_lr']} (décroissance par couche {h['layer_decay']}), tête {h['head_lr']}, "
          f"lots de {h['batch']}, poids de classe n^-{h['balance_alpha']}, lissage {h['label_smoothing']}, arrêt anticipé (patience {h['patience']}) sur la perte de validation.")
        w(f"- Appareil : {finetune['device']}{' (AMP fp16)' if finetune.get('amp') else ''} ; "
          + (f"{finetune['images_per_second']:.0f} images/s à l'entraînement ; " if finetune.get("images_per_second") else "")
          + f"{finetune['epochs_run']} époque(s) ; meilleure époque : **{finetune['best_epoch']}** (0 = la voie A).")
        if finetune["best_epoch"] == 0:
            w("- **L'affinage n'a pas amélioré la perte de validation : la meilleure époque est la 0, donc B reproduit A** (même DINOv2). Essayer moins de blocs affinés, "
              "un taux plus bas (`B_BASE_LR`) ou plus d'augmentations avant de conclure que B n'apporte rien.")
        w("")
        w("| Époque | Perte d'entraînement | Perte de validation | Exactitude de validation | Secondes |")
        w("|---|---|---|---|---|")
        for e in finetune["history"]:
            label = "{}{}".format(e["epoch"], " (voie A)" if e["epoch"] == 0 else "")
            train_loss = "-" if e["train_loss"] is None else "{:.4f}".format(e["train_loss"])
            w("| {} | {} | {:.4f} | {} | {:.0f} |".format(label, train_loss, e["val_loss"], _pct(e["val_acc"], 2), e["seconds"]))
        w("")
    w("## Fichiers (onglet « Output », dossier `models/`)")
    if exports:
        w("| Fichier | Variante | Taille du zip | Taille du paquet | SHA-256 |")
        w("|---|---|---|---|---|")
        for e in exports:
            w(f"| `{e['zip']}` | {e['variant']} | {e['zip_bytes'] / 1048576:.1f} Mo | {e['package_bytes'] / 1048576:.1f} Mo | `{e['sha256'][:16]}...` |")
    else:
        w("Aucun `.mlpackage` produit dans cette session (voir les journaux dans `logs/` ; l'export se refait sous WSL ou macOS avec `export_coreml.py`, "
          "commandes dans `scripts/ml/kaggle/README.md`).")
    w("")
    w("Autres fichiers : `reports/` (rapports d'entraînement complets par variante), `models/*/` (classes.json, ATTRIBUTIONS.txt, export.json), "
      "`weights/` (têtes `.pt` et DINOv2 affiné `finetuned-backbone.pt` pour ré-exporter sans réentraîner), `logs/`, `ardane_state/` (reprise).")
    w("")
    w("## Licences et attribution (à reproduire dans l'app si un de ces modèles est livré)")
    w("- DINOv2 : Meta Platforms, Apache 2.0 (github.com/facebookresearch/dinov2).")
    w("- Données : MyFoodRepo / AIcrowd Food Recognition Benchmark 2022, **CC BY 4.0** (attribution obligatoire ; la copie Kaggle affiche CC0, on applique la plus exigeante).")
    w("- Les poids de la tête et du DINOv2 affiné sont à Ardane. Aucune donnée d'entraînement n'est redistribuée.")
    w("")
    if notes:
        w("## Remarques de la session")
        for n in notes:
            w(f"- {n}")
        w("")
    w("## Ensuite")
    w("1. Télécharger l'onglet « Output » dans `C:\\Users\\Etudiant\\ardane-tools\\ml\\kaggle-outputs\\`.")
    w("2. Ne PAS livrer de modèle sans : (a) relecture de `class_map.csv`, (b) parité Core ML sur macOS (`parity_coreml.py`, CI), (c) mesure sur les repas pesés.")
    text = "\n".join(L) + "\n"
    out_path.write_text(text, encoding="utf-8")
    return text
