"""Métriques de segmentation d'Ardane en Python : PORT FIDÈLE de `Tests/Support/ScanMetrics.swift` (parties masques, taux, Wilson, percentile).

Même définition, mêmes cas limites, mêmes valeurs de test que `Tests/ScanMetricsTests.swift` (rejouées dans `selftest()`) :
  - `intersection_over_union(a, b)` : None si les tailles diffèrent ou si les deux masques sont vides (union vide) ; un raté est un vrai 0 ;
  - `dice(a, b)` : 2 x intersection / (aire A + aire B), None si les tailles diffèrent ou si les deux masques sont vides ;
  - `wilson_interval(successes, total, z=1.96)` : intervalle de Wilson à 95 %, None si total <= 0, successes hors 0..total, z non fini ou <= 0 ;
  - `rate`, `mean` (valeurs finies seulement), `percentile(values, p)` (interpolation linéaire, comme PERCENTILE.INC) et `median`.
Un nombre n'est jamais inventé : toute grandeur indéfinie vaut None, jamais 0.

Le seul ajout est l'appariement `match_foods` (Swift n'apparie que des identifiants) : voir sa docstring ; il n'utilise que les fonctions ci-dessus.
Les masques sont des tableaux numpy booléens 2D (True = le pixel appartient à l'aliment).
"""
from __future__ import annotations

import math

import numpy as np


def _as_mask(a):
    arr = np.asarray(a)
    return arr if arr.dtype == bool else arr.astype(bool)


def mask_area(a) -> int:
    return int(np.count_nonzero(_as_mask(a)))


def mask_from_rows(rows: list[str]):
    """Masque dessiné en texte, une chaîne par ligne : « . » ou espace = pixel vide, tout autre caractère = pixel allumé (comme `BinaryMask(rows:)`).
    None si aucune ligne ou lignes de longueurs différentes ou nulles."""
    if not rows or not rows[0] or any(len(r) != len(rows[0]) for r in rows):
        return None
    return np.array([[c not in ". " for c in row] for row in rows], dtype=bool)


def intersection_over_union(a, b):
    a, b = _as_mask(a), _as_mask(b)
    if a.shape != b.shape or a.ndim != 2:
        return None
    union = int(np.count_nonzero(a | b))
    if union == 0:
        return None
    return int(np.count_nonzero(a & b)) / union


def dice(a, b):
    a, b = _as_mask(a), _as_mask(b)
    if a.shape != b.shape or a.ndim != 2:
        return None
    total = int(np.count_nonzero(a)) + int(np.count_nonzero(b))
    if total == 0:
        return None
    return 2.0 * int(np.count_nonzero(a & b)) / total


def wilson_interval(successes: int, total: int, z: float = 1.96):
    if total <= 0 or successes < 0 or successes > total or not math.isfinite(z) or z <= 0:
        return None
    n = float(total)
    p = successes / n
    z2 = z * z
    denominator = 1 + z2 / n
    center = (p + z2 / (2 * n)) / denominator
    half = z * math.sqrt(p * (1 - p) / n + z2 / (4 * n * n)) / denominator
    return (max(0.0, center - half), min(1.0, center + half))


def rate(flags):
    flags = list(flags)
    if not flags:
        return None
    return sum(1 for f in flags if f) / len(flags)


def mean(values):
    finite = [v for v in values if v is not None and math.isfinite(v)]
    if not finite:
        return None
    return sum(finite) / len(finite)


def percentile(values, p: float):
    srt = sorted(v for v in values if v is not None and math.isfinite(v))
    if not srt or not math.isfinite(p) or p < 0 or p > 100:
        return None
    rank = p / 100 * (len(srt) - 1)
    lower = int(math.floor(rank))
    upper = min(lower + 1, len(srt) - 1)
    return srt[lower] + (srt[upper] - srt[lower]) * (rank - lower)


def median(values):
    return percentile(values, 50)


# --------------------------------------------------------------------------- appariement aliments vrais / aliments prédits

def match_foods(gt_masks: list, pred_masks: list, pred_scores: list, min_iou: float = 0.1) -> list[dict]:
    """Un résultat par aliment RÉEL : {iou, dice, matched, pred_index}.

    Appariement glouton, UN pour UN, sans tenir compte de la classe (la segmentation est mesurée séparément de la reconnaissance) :
    les prédictions sont prises par confiance décroissante ; chacune réclame l'aliment réel encore libre avec lequel son IoU est le plus
    élevé, à condition d'atteindre `min_iou`. Un aliment réel sans prédiction appariée compte pour 0 (IoU et Dice) : « un raté est un vrai 0 ».
    Les IoU et Dice viennent exactement de `intersection_over_union` / `dice` ci-dessus (None -> 0 : tailles différentes ou masques vides).
    """
    results = [{"iou": 0.0, "dice": 0.0, "matched": False, "pred_index": None} for _ in gt_masks]
    taken: set[int] = set()
    for j in sorted(range(len(pred_masks)), key=lambda k: -pred_scores[k]):
        best, best_iou = None, min_iou
        for i, gt in enumerate(gt_masks):
            if i in taken:
                continue
            value = intersection_over_union(gt, pred_masks[j])
            if value is not None and value >= best_iou:
                best, best_iou = i, value
        if best is not None:
            taken.add(best)
            results[best] = {"iou": best_iou, "dice": dice(gt_masks[best], pred_masks[j]) or 0.0, "matched": True, "pred_index": j}
    return results


def summarize_foods(per_food: list[dict], n_predictions: int) -> dict:
    """Résumé sur tous les aliments réels : IoU et Dice moyens (ratés = 0), moyennes sur les aliments appariés seulement,
    rappel à IoU >= 0,5 avec intervalle de Wilson, précision des prédictions (part des prédictions appariées)."""
    n = len(per_food)
    matched = [f for f in per_food if f["matched"]]
    hit50 = sum(1 for f in per_food if f["iou"] >= 0.5)
    return {
        "foods": n, "predictions": n_predictions, "matched": len(matched),
        "mean_iou": mean([f["iou"] for f in per_food]), "mean_dice": mean([f["dice"] for f in per_food]),
        "mean_iou_matched": mean([f["iou"] for f in matched]), "mean_dice_matched": mean([f["dice"] for f in matched]),
        "recall_iou50": rate([f["iou"] >= 0.5 for f in per_food]), "recall_iou50_wilson95": wilson_interval(hit50, n) if n else None,
        "precision_matched": (len(matched) / n_predictions) if n_predictions else None,
        "median_iou": median([f["iou"] for f in per_food]),
    }


# --------------------------------------------------------------------------- auto-test = cas de Tests/ScanMetricsTests.swift

def selftest() -> None:
    close = lambda x, y, tol=1e-9: abs(x - y) <= tol  # noqa: E731
    a = mask_from_rows(["##..", "##.."])
    b = mask_from_rows([".##.", ".##."])
    assert close(intersection_over_union(a, b), 2 / 6) and close(dice(a, b), 2 * 2 / 8)                     # testIoUAndDiceOfPartiallyOverlappingMasks
    assert intersection_over_union(a, b) == intersection_over_union(b, a)
    far = mask_from_rows(["..##", "..##"])
    assert close(intersection_over_union(a, a), 1) and close(dice(a, a), 1)                                  # identiques, disjoints, imbriqués
    assert close(intersection_over_union(a, far), 0) and close(dice(a, far), 0)
    small = mask_from_rows(["#...", "...."])
    assert close(intersection_over_union(a, small), 0.25) and close(dice(a, small), 0.4)
    empty, lit, other = mask_from_rows(["....", "...."]), mask_from_rows(["#...", "...."]), mask_from_rows(["#..", "..."])
    assert intersection_over_union(empty, empty) is None and dice(empty, empty) is None                        # testIoUAndDiceAreNotDefined...
    assert close(intersection_over_union(empty, lit), 0, 1e-9)
    assert intersection_over_union(lit, other) is None and dice(lit, other) is None
    assert mask_from_rows([]) is None and mask_from_rows(["##", "#"]) is None
    w = wilson_interval(5, 10)                                                                                # testWilson...
    assert close(w[0], 0.2366, 1e-4) and close(w[1], 0.7634, 1e-4)
    none, allw = wilson_interval(0, 10), wilson_interval(10, 10)
    assert close(none[0], 0) and close(none[1], 0.2775, 1e-4) and close(allw[0], 0.7225, 1e-4) and close(allw[1], 1)
    s30, s300 = wilson_interval(15, 30), wilson_interval(150, 300)
    assert (s300[1] - s300[0]) < (s30[1] - s30[0]) and close(s30[0] + s30[1], 1)
    assert wilson_interval(0, 0) is None and wilson_interval(11, 10) is None and wilson_interval(-1, 10) is None and wilson_interval(5, 10, 0) is None
    assert close(rate([True, False, True, True]), 0.75) and close(rate([False, False]), 0) and rate([]) is None
    assert close(percentile([1, 2, 3, 4, 5], 50), 3) and close(percentile([1, 2, 3, 4, 5], 95), 4.8) and percentile([], 50) is None
    assert percentile([1, 2], 101) is None and mean([float("nan"), 2.0, None]) == 2.0 and mean([]) is None
    # appariement : deux aliments, une prédiction parfaite + une prédiction fausse
    gt = [a, far]
    res = match_foods(gt, [a.copy(), mask_from_rows(["....", "#..."])], [0.9, 0.8])
    assert res[0]["matched"] and close(res[0]["iou"], 1) and not res[1]["matched"] and res[1]["iou"] == 0.0
    summary = summarize_foods(res, 2)
    assert close(summary["mean_iou"], 0.5) and summary["matched"] == 1 and close(summary["precision_matched"], 0.5)


if __name__ == "__main__":
    selftest()
    print("seg_metrics : auto-test OK (cas de Tests/ScanMetricsTests.swift rejoués)")
