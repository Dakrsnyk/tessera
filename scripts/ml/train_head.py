"""Étape 3 : tête de classification (linéaire, ou MLP à une couche cachée) sur les vecteurs DINOv2 gelés.

- classes rares écartées (--min-train), rééquilibrage par poids de classe (n^-alpha), arrêt anticipé sur la validation ;
- ÉTALONNAGE par température sur la validation (une seule valeur T : probabilités = softmax(logits / T)) ;
- évaluation sur le TEST, jamais touché avant : Top-1, Top-3 (avec intervalle de Wilson à 95 %), par classe, matrice de
  confusion des paires les plus confondues, ECE, NLL, précision selon le seuil de confiance ;
- écrit `<racine>/models/<jeu>/head-<étiquette>.pt` (poids avec la normalisation DÉJÀ intégrée, T, classes) et
  `<racine>/reports/classifier-<date>[-<jeu>].md` (+ .json ; le suffixe est le nom du jeu sauf pour `myfoodrepo`).

    python train_head.py --dataset fake
    python train_head.py --dataset myfoodrepo --head linear
    python train_head.py --dataset myfoodrepo --head mlp --hidden 768

Un jeu factice (« fake ») produit un rapport marqué FACTICE : ses chiffres ne mesurent rien.
"""
from __future__ import annotations

import argparse
import copy
import math
import sys
import time
from datetime import date, datetime
from pathlib import Path

import numpy as np

from class_matching import read_class_map
from ml_common import SCRIPT_DIR, fail, log, ml_root, models_dir, read_json, reports_dir, work_dir, write_json


# --------------------------------------------------------------------------- métriques

def softmax_np(logits: np.ndarray) -> np.ndarray:
    z = logits - logits.max(axis=1, keepdims=True)
    e = np.exp(z)
    return e / e.sum(axis=1, keepdims=True)


def ece_score(conf: np.ndarray, correct: np.ndarray, bins: int = 15) -> tuple[float, list[tuple]]:
    """ECE sur la confiance du Top-1 (15 intervalles égaux) et le tableau de fiabilité."""
    edges = np.linspace(0.0, 1.0, bins + 1)
    total, rows = 0.0, []
    for b in range(bins):
        lo, hi = edges[b], edges[b + 1]
        sel = (conf > lo) & (conf <= hi) if b else (conf >= lo) & (conf <= hi)
        n = int(sel.sum())
        if n:
            acc, avg = float(correct[sel].mean()), float(conf[sel].mean())
            total += abs(acc - avg) * n / len(conf)
            rows.append((lo, hi, n, avg, acc))
    return total, rows


def wilson(k: int, n: int, z: float = 1.96) -> tuple[float, float]:
    if n == 0:
        return (0.0, 0.0)
    p = k / n
    d = 1 + z * z / n
    centre = (p + z * z / (2 * n)) / d
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return (max(0.0, centre - half), min(1.0, centre + half))


def nll_np(probs: np.ndarray, y: np.ndarray) -> float:
    return float(-np.log(np.clip(probs[np.arange(len(y)), y], 1e-12, 1.0)).mean()) + 0.0


def fit_temperature(logits: np.ndarray, y: np.ndarray) -> float:
    """Température qui minimise la NLL de validation (recherche en échelle log puis affinage : déterministe)."""
    def nll(t):
        return nll_np(softmax_np(logits / t), y)

    grid = np.exp(np.linspace(math.log(0.05), math.log(20.0), 400))
    best = grid[int(np.argmin([nll(t) for t in grid]))]
    fine = np.exp(np.linspace(math.log(best) - 0.03, math.log(best) + 0.03, 121))
    return float(fine[int(np.argmin([nll(t) for t in fine]))])


# --------------------------------------------------------------------------- modèle

def build_head(kind: str, dim: int, classes: int, hidden: int, dropout: float):
    from torch import nn

    if kind == "linear":
        return nn.Linear(dim, classes)
    return nn.Sequential(nn.Linear(dim, hidden), nn.GELU(), nn.Dropout(dropout), nn.Linear(hidden, classes))


def fold_standardization(head, mean: np.ndarray, std: np.ndarray):
    """Intègre (x - mean) / std dans la première couche linéaire : la tête exportée prend le vecteur BRUT."""
    import torch
    from torch import nn

    folded = copy.deepcopy(head)
    first = folded if isinstance(folded, nn.Linear) else folded[0]
    with torch.no_grad():
        w = first.weight.clone()
        m = torch.from_numpy(mean).float()
        s = torch.from_numpy(std).float()
        first.weight.copy_(w / s)
        first.bias.copy_(first.bias - (w * (m / s)).sum(dim=1))
    return folded


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root")
    ap.add_argument("--dataset", default="myfoodrepo")
    ap.add_argument("--head", choices=["linear", "mlp"], default="linear")
    ap.add_argument("--hidden", type=int, default=512)
    ap.add_argument("--dropout", type=float, default=0.2, help="MLP seulement")
    ap.add_argument("--epochs", type=int, default=200)
    ap.add_argument("--batch", type=int, default=512)
    ap.add_argument("--lr", type=float, default=2e-3)
    ap.add_argument("--wd", type=float, default=1e-3)
    ap.add_argument("--patience", type=int, default=12, help="époques sans amélioration de la validation avant arrêt")
    ap.add_argument("--balance-alpha", type=float, default=0.5, help="poids de classe n^-alpha (0 = aucun, 1 = inverse de la fréquence)")
    ap.add_argument("--label-smoothing", type=float, default=0.0)
    ap.add_argument("--min-train", type=int, default=5, help="classes ayant moins de recadrages d'entraînement : écartées")
    ap.add_argument("--seed", type=int, default=20261102)
    ap.add_argument("--tag", default="", help="étiquette du modèle (défaut : linear / mlp)")
    ap.add_argument("--top-confused", type=int, default=15)
    ap.add_argument("--note-file", help="texte Markdown ajouté tel quel au rapport (ex. la façon dont les réglages ont été choisis)")
    args = ap.parse_args()

    import torch
    from torch import nn

    root = ml_root(args.root)
    out = work_dir(root, args.dataset)
    feat = out / "features"
    for split in ("train", "val", "test"):
        if not (feat / f"{split}.X.npy").exists():
            fail(f"{feat / (split + '.X.npy')} est absent : lancer d'abord extract_features.py --dataset {args.dataset}")
    meta = read_json(out / "meta.json")
    fmeta = read_json(feat / "meta.json")
    classes = read_json(out / "classes.json")
    X = {s: np.load(feat / f"{s}.X.npy") for s in ("train", "val", "test")}
    Y = {s: np.load(feat / f"{s}.y.npy").astype(np.int64) for s in ("train", "val", "test")}
    is_fake = meta["kind"] == "fake"
    if fmeta.get("limit"):
        log(f"ATTENTION : vecteurs extraits avec --limit {fmeta['limit']} : essai seulement.")

    # Classes retenues
    n_train_all = np.bincount(Y["train"], minlength=len(classes))
    keep = [c["index"] for c in classes if n_train_all[c["index"]] >= args.min_train]
    if len(keep) < 2:
        fail("moins de deux classes ont assez de recadrages d'entraînement")
    dropped = [c for c in classes if c["index"] not in set(keep)]
    to_head = {old: new for new, old in enumerate(keep)}
    head_classes = [classes[i] for i in keep]

    def restrict(split):
        mask = np.isin(Y[split], keep)
        return X[split][mask], np.array([to_head[v] for v in Y[split][mask]], dtype=np.int64), mask

    Xtr, ytr, _ = restrict("train")
    Xva, yva, _ = restrict("val")
    Xte, yte, test_mask = restrict("test")
    if len(yva) == 0:
        fail("la validation est vide : impossible d'arrêter l'entraînement ni d'étalonner")
    out_of_vocab_test = int((~test_mask).sum())
    n_classes, dim = len(keep), Xtr.shape[1]
    log(f"== Tête « {args.head} » sur « {args.dataset} » : {len(ytr)} entraînement, {len(yva)} validation, {len(yte)} test, "
        f"{n_classes} classes ({len(dropped)} écartées : < {args.min_train} recadrages), dimension {dim}")

    # Normalisation (statistiques d'entraînement seulement)
    mean = Xtr.mean(axis=0)
    std = np.maximum(Xtr.std(axis=0), 1e-6)
    norm = lambda a: ((a - mean) / std).astype(np.float32)
    tr, va, te = (torch.from_numpy(norm(a)) for a in (Xtr, Xva, Xte))
    ytr_t = torch.from_numpy(ytr)

    torch.manual_seed(args.seed)
    np.random.seed(args.seed)
    counts = np.bincount(ytr, minlength=n_classes).astype(np.float64)
    weights = np.power(np.maximum(counts, 1.0), -args.balance_alpha)
    weights = weights / (weights[ytr].mean())             # moyenne des poids des exemples = 1
    head = build_head(args.head, dim, n_classes, args.hidden, args.dropout)
    loss_fn = nn.CrossEntropyLoss(weight=torch.tensor(weights, dtype=torch.float32), label_smoothing=args.label_smoothing)
    val_loss_fn = nn.CrossEntropyLoss()
    opt = torch.optim.AdamW(head.parameters(), lr=args.lr, weight_decay=args.wd)
    sched = torch.optim.lr_scheduler.CosineAnnealingLR(opt, T_max=args.epochs)

    best_loss, best_state, best_epoch, waited = float("inf"), None, 0, 0
    history = []
    t0 = time.time()
    for epoch in range(1, args.epochs + 1):
        head.train()
        order = torch.randperm(len(tr))
        for i in range(0, len(tr), args.batch):
            idx = order[i:i + args.batch]
            opt.zero_grad()
            loss = loss_fn(head(tr[idx]), ytr_t[idx])
            loss.backward()
            opt.step()
        sched.step()
        head.eval()
        with torch.no_grad():
            v_logits = head(va)
            v_loss = float(val_loss_fn(v_logits, torch.from_numpy(yva)))
            v_acc = float((v_logits.argmax(1).numpy() == yva).mean())
        history.append((epoch, v_loss, v_acc))
        if v_loss < best_loss - 1e-5:
            best_loss, best_state, best_epoch, waited = v_loss, copy.deepcopy(head.state_dict()), epoch, 0
        else:
            waited += 1
            if waited >= args.patience:
                break
        if epoch % 10 == 0 or epoch == 1:
            log(f"  époque {epoch:3d} : perte de validation {v_loss:.4f}, exactitude de validation {v_acc:.3f}")
    head.load_state_dict(best_state)
    head.eval()
    train_seconds = time.time() - t0
    log(f"  arrêt à l'époque {epoch} ; meilleure : {best_epoch} (perte de validation {best_loss:.4f}) ; {train_seconds:.1f} s")

    with torch.no_grad():
        lv, lt = head(va).numpy().astype(np.float64), head(te).numpy().astype(np.float64)
    # Étalonnage par température sur la validation
    temperature = fit_temperature(lv, yva)
    pv_raw, pv = softmax_np(lv), softmax_np(lv / temperature)
    ece_val_raw, _ = ece_score(pv_raw.max(1), pv_raw.argmax(1) == yva)
    ece_val, _ = ece_score(pv.max(1), pv.argmax(1) == yva)
    if not 0.06 < temperature < 19.0:
        log(f"  AVERTISSEMENT : T = {temperature:.3f} est collé à une borne de la recherche [0,05 ; 20] : validation trop petite ou trop facile pour étalonner.")
    log(f"  température T = {temperature:.3f} ; NLL de validation {nll_np(pv_raw, yva):.4f} -> {nll_np(pv, yva):.4f} ; "
        f"ECE de validation {ece_val_raw:.4f} -> {ece_val:.4f}")

    val_top1 = float((pv.argmax(1) == yva).mean())
    val_top3 = float((np.argsort(-pv, axis=1)[:, :3] == yva[:, None]).any(axis=1).mean())
    log(f"  VALIDATION (sert à l'arrêt et à T : ce n'est PAS une mesure) : Top-1 {val_top1:.3f}, Top-3 {val_top3:.3f}")

    # Tête exportable : la normalisation est intégrée à la première couche
    folded = fold_standardization(head, mean, std)
    folded.eval()
    with torch.no_grad():
        raw_logits = folded(torch.from_numpy(Xva.astype(np.float32))).numpy()
    drift = float(np.abs(raw_logits - lv).max())
    if drift > 1e-2:
        fail(f"l'intégration de la normalisation change les logits (écart {drift:.2e})")
    log(f"  normalisation intégrée à la tête : écart maximal des logits {drift:.2e}")

    # Évaluation sur le test
    pt = softmax_np(lt / temperature)
    pred = pt.argmax(1)
    correct = pred == yte
    top3 = np.argsort(-pt, axis=1)[:, :3]
    top3_ok = (top3 == yte[:, None]).any(axis=1)
    n_test = len(yte)
    ece_test, reliability = ece_score(pt.max(1), correct)
    ece_test_raw, _ = ece_score(softmax_np(lt).max(1), softmax_np(lt).argmax(1) == yte)
    nll_test, nll_test_raw = nll_np(pt, yte), nll_np(softmax_np(lt), yte)
    brier = float(((pt - np.eye(n_classes)[yte]) ** 2).sum(1).mean())
    t1, t3 = wilson(int(correct.sum()), n_test), wilson(int(top3_ok.sum()), n_test)

    per_class = []
    conf_counts: dict[tuple[int, int], int] = {}
    for c in range(n_classes):
        support = int((yte == c).sum())
        predicted = int((pred == c).sum())
        tp = int(((pred == c) & (yte == c)).sum())
        precision = tp / predicted if predicted else float("nan")
        recall = tp / support if support else float("nan")
        f1 = (2 * precision * recall / (precision + recall)) if support and predicted and (precision + recall) else (0.0 if support else float("nan"))
        per_class.append({"index": c, "class": head_classes[c], "support": support, "predicted": predicted,
                          "precision": precision, "recall": recall, "f1": f1})
    for t, p in zip(yte, pred):
        if t != p:
            conf_counts[(int(t), int(p))] = conf_counts.get((int(t), int(p)), 0) + 1
    confused = sorted(conf_counts.items(), key=lambda kv: -kv[1])[:args.top_confused]
    recalls = [r["recall"] for r in per_class if r["support"]]
    f1s = [r["f1"] for r in per_class if r["support"]]
    macro_recall, macro_f1 = float(np.mean(recalls)), float(np.mean(f1s))
    thresholds = []
    for th in (0.3, 0.5, 0.7, 0.9):
        sel = pt.max(1) >= th
        thresholds.append((th, int(sel.sum()), float(sel.mean()), float(correct[sel].mean()) if sel.any() else float("nan")))

    log(f"  TEST : Top-1 {correct.mean():.3f} [{t1[0]:.3f} ; {t1[1]:.3f}], Top-3 {top3_ok.mean():.3f}, ECE {ece_test:.4f} "
        f"({n_test} recadrages dans le vocabulaire, {out_of_vocab_test} hors vocabulaire)")

    # Fichiers
    tag = args.tag or args.head
    mdir = models_dir(root, args.dataset)
    head_path = mdir / f"head-{tag}.pt"
    class_map_path = (SCRIPT_DIR / "class_map.csv") if args.dataset == "myfoodrepo" else (out / "class_map.csv")
    cmap = {r["classe"]: r for r in read_class_map(class_map_path)}      # clé stable : le nom de la classe
    torch.save({
        "format": "ardane-head-v1", "kind": args.head, "dim": dim, "n_classes": n_classes, "hidden": args.hidden if args.head == "mlp" else None,
        "state_dict": {k: v.clone() for k, v in folded.state_dict().items()},   # prend le vecteur BRUT (normalisation intégrée)
        "temperature": temperature, "pool": fmeta["pool"],
        "classes": [{"index": i, "class_id": c["class_id"], "name": c["name"], "name_readable": c["name_readable"],
                     "ardane_id": cmap.get(c["name"], {}).get("id_ardane", "")} for i, c in enumerate(head_classes)],
        "dataset": args.dataset, "dataset_kind": meta["kind"], "dataset_license": meta["license"], "dataset_attribution": meta["attribution"],
        "backbone": fmeta["backbone"], "trained_at": datetime.now().isoformat(timespec="seconds"),
        "hyper": {k: getattr(args, k) for k in ("head", "hidden", "dropout", "epochs", "batch", "lr", "wd", "patience",
                                               "balance_alpha", "label_smoothing", "min_train", "seed")},
        "metrics_test": {"top1": float(correct.mean()), "top3": float(top3_ok.mean()), "ece": ece_test, "n": n_test},
    }, head_path)

    today = date.today().isoformat()
    # « myfoodrepo » : classifier-<date>.md ; tout autre jeu (factice, essai) porte son nom, pour ne jamais écraser ni imiter le vrai rapport
    report_name = f"classifier-{today}" + ("" if args.dataset == "myfoodrepo" else f"-{args.dataset}") + (f"-{args.tag}" if args.tag else "")
    report_path = reports_dir(root) / f"{report_name}.md"
    mapped = sum(1 for c in head_classes if cmap.get(c["name"], {}).get("id_ardane"))
    L = []
    w = L.append
    w(f"# Classifieur d'aliments : rapport d'entraînement du {today}" + (" (JEU FACTICE)" if is_fake else ""))
    w("")
    if is_fake:
        w("> **JEU FACTICE.** Ces images sont des formes colorées générées par `make_fake_coco.py`. Les chiffres ci-dessous prouvent seulement "
          "que la chaîne tourne de bout en bout. Ils ne mesurent **aucune** reconnaissance d'aliments et ne doivent jamais être cités comme une précision.")
        w("")
    w("## Jeu de données")
    w(f"- Jeu : {meta['name']} (dossier de travail `{args.dataset}`, préparé le {meta['prepared_on']}, commit des scripts `{meta['git_head'][:10]}`).")
    w(f"- Licence : {meta['license']}." + (f" Texte relevé sur la page de téléchargement : « {meta['license_note_from_download_page']} »." if meta["license_note_from_download_page"] else ""))
    if not is_fake:
        w(f"- Fichiers de licence archivés : {', '.join(meta['license_files_archived']) or '**AUCUN** (à archiver avant toute livraison du modèle)'}.")
        w(f"- Attribution à afficher : « {meta['attribution']} ».")
    w(f"- Répartition : {meta['split_method']}.")
    w(f"- Photos : " + ", ".join(f"{k} {v}" for k, v in meta["photos"].items()) + ". Recadrages : " + ", ".join(f"{k} {v}" for k, v in meta["crops"].items()) + ".")
    w(f"- Recadrage : carré autour de la boîte du polygone, marge {meta['params']['margin']:.0%}, {meta['params']['crop_size']} x {meta['params']['crop_size']} px, "
      f"côté minimal {meta['params']['min_size']:g} px ; doublons (dHash, Hamming <= {meta['params']['dedup_hamming']}) gardés d'un seul côté.")
    w(f"- Classes : {meta['n_classes']} dans le jeu, **{n_classes} entraînées** (au moins {args.min_train} recadrages d'entraînement) ; "
      f"{len(dropped)} écartées ; {out_of_vocab_test} recadrages de test appartiennent à des classes écartées (comptés hors vocabulaire, absents des métriques). "
      f"{mapped}/{n_classes} classes entraînées ont un identifiant Ardane dans `class_map.csv` (à relire).")
    w(f"- Effectifs utilisés : entraînement {len(ytr)}, validation {len(yva)}, test {n_test}.")
    w("")
    w("## Modèle")
    ft_note = (f" ; **AFFINÉ par Ardane** ({fmeta['finetuned']['description']}, fichier `{fmeta['finetuned']['file']}`, SHA-256 `{fmeta['finetuned']['sha256'][:16]}...`)"
               if fmeta.get("finetuned") else "")
    w(f"- Base : DINOv2 {fmeta['backbone'].get('model', 'dinov2_vits14')} {'(poids officiels au départ)' if ft_note else 'gelé'} ({fmeta['backbone']['hub']}, poids SHA-256 `{fmeta['backbone']['weights_sha256'][:16]}...`, Apache 2.0){ft_note}, entrée 224 x 224, normalisation ImageNet, agrégation `{fmeta['pool']}` ({dim} nombres)." )
    w(f"- Tête : {'linéaire' if args.head == 'linear' else f'MLP {dim}-{args.hidden}-{n_classes} (GELU, dropout {args.dropout})'} ; AdamW (lr {args.lr}, décroissance {args.wd}), "
      f"lots de {args.batch}, poids de classe n^-{args.balance_alpha}, arrêt anticipé (patience {args.patience}) sur la perte de validation : meilleure époque {best_epoch}, arrêt à {epoch} ({train_seconds:.0f} s sur CPU).")
    w(f"- Étalonnage : température **T = {temperature:.3f}** ajustée sur la validation (NLL {nll_np(pv_raw, yva):.4f} -> {nll_np(pv, yva):.4f} ; ECE de validation {ece_val_raw:.4f} -> {ece_val:.4f}). "
      "La validation sert à la fois à l'arrêt et à T : la calibration mesurée sur le TEST ci-dessous est la seule qui compte.")
    if len(yva) < 500:
        w(f"- **Avertissement : seulement {len(yva)} recadrages de validation** pour ajuster T et arrêter l'entraînement : température et arrêt peu fiables (la comparaison « avant étalonnage » du tableau de test le montre). Une validation d'au moins quelques milliers de recadrages est visée avec les vraies données.")
    if not 0.06 < temperature < 19.0:
        w("- **Avertissement : T est collé à une borne de la recherche [0,05 ; 20]** : la validation est trop petite ou trop facile pour étalonner. Ne pas se fier à cette température.")
    w(f"- Validation ({len(yva)} recadrages ; sert à l'arrêt, à l'étalonnage et au CHOIX entre variantes, donc ce n'est PAS une mesure) : Top-1 {val_top1:.1%}, Top-3 {val_top3:.1%}.")
    w(f"- Fichier : `{head_path}` (normalisation intégrée, entrée = vecteur brut).")
    w("")
    if args.note_file:
        w("")
        w(Path(args.note_file).read_text(encoding="utf-8").rstrip())
    w("")
    w("## Résultats sur le TEST (jamais utilisé pour régler quoi que ce soit)")
    w("| Mesure | Valeur |")
    w("|---|---|")
    w(f"| Top-1 | {correct.mean():.1%} (intervalle de Wilson 95 % : {t1[0]:.1%} à {t1[1]:.1%}) |")
    w(f"| Top-3 | {top3_ok.mean():.1%} ({t3[0]:.1%} à {t3[1]:.1%}) |")
    w(f"| Rappel moyen par classe (exactitude équilibrée) | {macro_recall:.1%} |")
    w(f"| F1 moyen par classe | {macro_f1:.1%} |")
    w(f"| ECE (15 intervalles) | {ece_test:.4f} (avant étalonnage : {ece_test_raw:.4f}) |")
    w(f"| NLL | {nll_test:.4f} (avant étalonnage : {nll_test_raw:.4f}) |")
    w(f"| Brier | {brier:.4f} |")
    w(f"| Recadrages évalués | {n_test} (+ {out_of_vocab_test} hors vocabulaire) |")
    w("")
    w("## Confiance et exactitude")
    w("| Confiance du Top-1 | Recadrages | Part du test | Exactitude |")
    w("|---|---|---|---|")
    for th, n, share, acc in thresholds:
        w(f"| >= {th:.1f} | {n} | {share:.1%} | {'-' if math.isnan(acc) else f'{acc:.1%}'} |")
    w("")
    w("Fiabilité (confiance moyenne contre exactitude observée, par intervalle) :")
    w("")
    w("| Intervalle | n | Confiance moyenne | Exactitude |")
    w("|---|---|---|---|")
    for lo, hi, n, avg, acc in reliability:
        w(f"| {lo:.2f}-{hi:.2f} | {n} | {avg:.3f} | {acc:.3f} |")
    w("")
    w(f"## Paires les plus confondues (vrai -> prédit), {len(confused)} premières")
    if confused:
        w("| Vraie classe | Prédite | Fois | Part de la vraie classe |")
        w("|---|---|---|---|")
        for (t, p), n in confused:
            support = max(int((yte == t).sum()), 1)
            w(f"| {head_classes[t]['name']} | {head_classes[p]['name']} | {n} | {n / support:.0%} |")
    else:
        w("Aucune erreur sur le test.")
    w("")
    w("## Par classe (test)")
    w("| Classe | Id Ardane | Entraînement | Test | Précision | Rappel | F1 |")
    w("|---|---|---|---|---|---|---|")
    fmt = lambda v: "-" if isinstance(v, float) and math.isnan(v) else f"{v:.2f}"
    for r in sorted(per_class, key=lambda r: (-r["support"], r["class"]["name"])):
        c = r["class"]
        w(f"| {c['name']} | {cmap.get(c['name'], {}).get('id_ardane') or '-'} | {int(counts[r['index']])} | {r['support']} | {fmt(r['precision'])} | {fmt(r['recall'])} | {fmt(r['f1'])} |")
    if dropped:
        w("")
        w(f"Classes écartées (moins de {args.min_train} recadrages d'entraînement) : " + ", ".join(f"{c['name']} ({int(n_train_all[c['index']])})" for c in dropped) + ".")
    w("")
    w("## Limites à garder en tête")
    w("- Les photos MyFoodRepo sont suisses : classes, assiettes et éclairages ne sont pas ceux du Québec ; les identifiants Ardane de `class_map.csv` restent à relire (cru/cuit, variante, plat composé).")
    w("- Les recadrages viennent des masques d'annotation ; dans l'app ils viendront de la segmentation de l'iPhone : la précision réelle sur l'iPhone sera mesurée sur les repas pesés de l'utilisateur (chantier 22.6).")
    w("- Un intervalle de Wilson suppose des recadrages indépendants ; des photos du même repas non repérées par le dHash peuvent le rendre trop optimiste.")
    w("")
    w("## Reproductibilité")
    w(f"`python train_head.py --dataset {args.dataset} --head {args.head}"
      + "".join(f" --{k.replace('_', '-')} {getattr(args, k)}" for k in ("hidden", "lr", "wd", "balance_alpha", "min_train", "seed") if args.head == "mlp" or k != "hidden") + "`")
    w("")
    report_path.write_text("\n".join(L) + "\n", encoding="utf-8")
    write_json(report_path.with_suffix(".json"), {
        "dataset": args.dataset, "kind": meta["kind"], "head": args.head, "date": today, "n_classes": n_classes,
        "n": {"train": len(ytr), "val": len(yva), "test": n_test, "test_out_of_vocabulary": out_of_vocab_test},
        "temperature": temperature, "top1": float(correct.mean()), "top1_wilson95": t1, "top3": float(top3_ok.mean()),
        "macro_recall": macro_recall, "macro_f1": macro_f1, "ece": ece_test, "ece_before_calibration": ece_test_raw,
        "nll": nll_test, "brier": brier, "best_epoch": best_epoch, "model": str(head_path),
        "val_top1": val_top1, "val_top3": val_top3, "val_nll_calibrated": nll_np(pv, yva), "val_n": len(yva), "hyper": vars(args),
        # validation (prélevée dans train) : sert à CHOISIR entre deux variantes sans toucher au test
        "val": {"n": len(yva), "top1": float((pv.argmax(1) == yva).mean()), "nll": nll_np(pv, yva), "ece": ece_val,
                "nll_before_calibration": nll_np(pv_raw, yva)},
    })
    log(f"Modèle : {head_path}")
    log(f"Rapport : {report_path}")


if __name__ == "__main__":
    main()
