"""Toutes les combinaisons salaire + dividendes, par palier de revenus et par structure.

Usage : python finance/optimisation.py [palier_mensuel ...]   (paliers par défaut : 1000 5000 10000 50000)

Interprétation du palier : versements nets d'Apple en CAD par mois, avant dépenses (voir docs/finance/estimation-revenus.md).
Pour chaque palier on fait varier : la structure (individuelle, société au taux prudent 20,5 %, société au taux de petite
entreprise 11,2 %), la part du distribuable retirée (50 à 100 %) et le salaire annuel brut (0 $ à tout en salaire) ;
le reste du retrait est versé en dividendes. Mêmes formules que withdrawal.py (rien de nouveau côté fiscalité).

Sorties : out/optimisation.csv (toutes les lignes), out/optimisation_resume.md (meilleurs cas, lisible par l'agent comptable).
"""
import copy
import csv
import os
import sys

import model
import withdrawal as w

HERE = os.path.dirname(os.path.abspath(__file__))
PALIERS = (1000, 5000, 10000, 50000)
PARTS_RETRAIT = (0.5, 0.6, 0.7, 0.8, 0.9, 1.0)
SALAIRES = (0, 5000, 10000, 15000, None, 25000, 40000, 60000, 80000, 100000, "tout")  # None : montant personnel de base du Québec
SALAIRE_DROITS = 15000  # salaire minimal du critère « droits » (à régler avec le comptable)
REER_TAUX = 0.18  # droit de cotisation REER = 18 % du revenu gagné (plafond annuel non appliqué) : à confirmer


def societe_salaire(P, B, variant, salaire, part_retrait):
    """Société : retrait = part_retrait x distribuable ; `salaire` payé en salaire (au plus le retrait), le reste en dividendes."""
    F = P["fiscalite"]
    rate = F["corp_rate_dpe_hypothesis"] if variant == "dpe_hyp" else F["corp_rate_small_business"]
    B_soc = B - w.societe_extra_cost(P)
    R = w.reserve(P)
    D0 = max(0.0, B_soc * (1 - rate) - R)
    cible = part_retrait * D0
    sal_cible = cible if salaire == "tout" else min(float(salaire), cible)
    div_cible = cible - sal_cible

    def reste(k):
        return w._company_state(P, B_soc, rate, k * sal_cible, k * div_cible)[2]

    k = 1.0
    if reste(1.0) < R:
        lo, hi = 0.0, 1.0
        for _ in range(60):
            mid = (lo + hi) / 2
            lo, hi = (mid, hi) if reste(mid) >= R else (lo, mid)
        k = lo
    sal, div = k * sal_cible, k * div_cible
    emp, impot_soc, restant = w._company_state(P, B_soc, rate, sal, div)
    rrq_ee, rqap_ee = w.employee_deductions(F, sal)
    fed, qc = w.personal_tax(F, sal, 0.0, rrq_ee + rqap_ee, div)
    net = sal + div - rrq_ee - rqap_ee - fed - qc
    return {"salaire": sal, "dividendes": div, "impot_societe": impot_soc, "charges_employeur": emp,
            "cotisations_perso": rrq_ee + rqap_ee, "impot_perso": fed + qc, "net_personnel": net, "laisse": restant,
            "rrq_creee": w.rrq_total(F, sal), "reer_cree": REER_TAUX * sal}


def lignes(P, mensuel):
    revenu = 12 * mensuel
    B = revenu - model.recurring_expenses_annual(P, "individuelle", "central")  # le moteur retire lui-même le surcoût de la société
    out = []
    for ws in PARTS_RETRAIT:
        Q = copy.deepcopy(P)
        Q["retrait"]["withdraw_share"] = ws
        r = w.individual(Q, B)
        out.append({"palier_mensuel": mensuel, "structure": "individuelle", "part_retrait": ws, "salaire": 0.0, "dividendes": 0.0,
                    "impot_societe": 0.0, "charges_employeur": 0.0, "cotisations_perso": r["cotisations_perso"],
                    "impot_perso": r["impot_fed"] + r["impot_qc"], "net_personnel": r["net_personnel"],
                    "laisse": r["laisse_dans_entreprise"], "rrq_creee": r["cotisations_perso"], "reer_cree": REER_TAUX * B})
        seen = set()
        for variant in ("dpe_hyp", "petite_ent"):
            for sal in SALAIRES:
                s = P["fiscalite"]["quebec_basic_personal"] if sal is None else sal
                r = societe_salaire(Q, B, variant, s, ws)
                cle = (variant, round(r["salaire"]), round(r["dividendes"]))
                if cle in seen:
                    continue
                seen.add(cle)
                r.update({"palier_mensuel": mensuel, "structure": "societe_" + variant, "part_retrait": ws})
                out.append(r)
    for r in out:
        r["patrimoine_net"] = r["net_personnel"] + r["laisse"]
        r["bénéfice_B"] = B
    return out


COLS = ["palier_mensuel", "structure", "part_retrait", "salaire", "dividendes", "impot_societe", "charges_employeur",
        "cotisations_perso", "impot_perso", "net_personnel", "laisse", "patrimoine_net", "rrq_creee", "reer_cree", "bénéfice_B"]
NOMS = {"individuelle": "Individuelle", "societe_dpe_hyp": "Société, taux prudent 20,5 %", "societe_petite_ent": "Société, petite entreprise 11,2 %"}


def fmt(v):
    return f"{round(v):,}".replace(",", " ")


def main(argv):
    P = model.load_params()
    paliers = tuple(int(a) for a in argv) or PALIERS
    tout = [r for m in paliers for r in lignes(P, m)]
    os.makedirs(os.path.join(HERE, "out"), exist_ok=True)
    with open(os.path.join(HERE, "out", "optimisation.csv"), "w", newline="", encoding="utf-8-sig") as f:
        wr = csv.DictWriter(f, fieldnames=COLS, delimiter=";")
        wr.writeheader()
        for r in tout:
            wr.writerow({k: (round(r[k], 2) if isinstance(r[k], float) else r[k]) for k in COLS})
    md = ["# Optimisation salaire + dividendes (généré par finance/optimisation.py)", "",
          f"{len(tout)} combinaisons. CAD par an. « Net » = argent en poche après tous les impôts et cotisations ; « Laissé » = argent resté dans l'entreprise "
          "(déjà imposé en individuelle ; en société, il sera imposé à la sortie). Hypothèses et réserves : docs/finance/estimation-revenus.md.", ""]
    for m in paliers:
        md += [f"## {m:,} $/mois".replace(",", " "), "",
               "| Structure | Critère | Part retirée | Salaire | Dividendes | Net en poche | Laissé | Droits créés (RRQ / REER) |", "|---|---|---|---|---|---|---|---|"]
        for st in NOMS:
            cand = [r for r in tout if r["palier_mensuel"] == m and r["structure"] == st]
            criteres = (("Net max, retrait libre", cand),
                        ("Net max, retrait 80 % (coussin)", [r for r in cand if r["part_retrait"] == 0.8]),
                        (f"Net max, salaire ≥ {fmt(SALAIRE_DROITS)} $ (droits)", [r for r in cand if r["salaire"] >= SALAIRE_DROITS]))
            for crit, sous in criteres:
                if not sous:
                    md.append(f"| {NOMS[st]} | {crit} | – | – | – | sans objet | – | – |")
                    continue
                b = max(sous, key=lambda r: r["net_personnel"])
                md.append(f"| {NOMS[st]} | {crit} | {round(b['part_retrait'] * 100)} % | {fmt(b['salaire'])} | {fmt(b['dividendes'])} | "
                          f"{fmt(b['net_personnel'])} | {fmt(b['laisse'])} | {fmt(b['rrq_creee'])} / {fmt(b['reer_cree'])} |")
        md.append("")
    with open(os.path.join(HERE, "out", "optimisation_resume.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(md))
    print("\n".join(md))
    print(f"\n{len(tout)} lignes -> finance/out/optimisation.csv")


if __name__ == "__main__":
    main(sys.argv[1:])
