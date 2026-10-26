"""Retrait de ~80 % des bénéfices DISTRIBUABLES : entreprise individuelle et société québécoise sans employé.

Usage : python finance/withdrawal.py

Vocabulaire (ne pas confondre) :
- taxes collectées : TPS/TVQ/TVA perçues par Apple, jamais à nous (voir model.py) ;
- chiffre d'affaires : ventes HT ; bénéfice comptable B : proceeds nets - dépenses, avant impôt ;
- impôts : société + personnel + cotisations ; trésorerie : argent réellement dans le compte ;
- distribuable D : ce qui peut sortir sans toucher à la réserve ni aux impôts de l'exercice.

Définitions :
- Réserve R = mois de réserve / 12 x dépenses récurrentes annuelles (paramètre).
- Entreprise individuelle : D = B - impôt fédéral - impôt Québec - RRQ - RQAP - R. Retrait = 80 % de D.
  Les impôts et cotisations sont mis de côté dans l'entreprise ; le net personnel est le retrait.
- Société : D0 = B_soc x (1 - taux société) - R (aucun salaire). Retrait brut cible W = 80 % de D0,
  versé en dividendes, en salaire ou moitié-moitié. Le retrait est réduit si la réserve n'est plus respectée.
  B_soc = B - surcoût annuel de la société (comptable et registre plus chers).
Tout est simplifié : voir docs/finance/modele.md pour ce qui reste à confirmer par un CPA.
"""
import csv
import os

import model

HERE = os.path.dirname(os.path.abspath(__file__))


# ---------------------------------------------------------------- impôt et cotisations
def progressive_tax(income, brackets):
    """Impôt par tranches : brackets = [[plafond ou None, taux], ...]."""
    tax, low = 0.0, 0.0
    for cap, rate in brackets:
        top = income if cap is None else min(income, cap)
        if top > low:
            tax += (top - low) * rate
        if cap is None or income <= cap:
            break
        low = cap
    return tax


def rrq_total(F, income):
    """Cotisation RRQ totale (travailleur autonome ou employé + employeur) sur un revenu/salaire."""
    base = max(0.0, min(income, F["rrq_ceiling1"]) - F["rrq_exemption"]) * F["rrq_rate_selfemployed"]
    second = max(0.0, min(income, F["rrq_ceiling2"]) - F["rrq_ceiling1"]) * F["rrq_rate2_selfemployed"]
    return base + second


def rqap_selfemployed(F, income):
    return min(income, F["rqap_ceiling"]) * F["rqap_rate_selfemployed"]


def personal_tax(F, ordinary, rrq_deduction, credit_contribs, dividends_cash=0.0):
    """Impôt personnel (fédéral net de l'abattement du Québec, Québec). Retourne (fédéral, Québec).
    Dividendes ordinaires (non déterminés) : majorés puis crédit de dividende, sur le montant majoré.
    Crédits non remboursables : montant personnel de base + cotisations créditées."""
    grossed = dividends_cash * (1 + F["dividend_grossup_noneligible"])
    taxable = max(0.0, ordinary - rrq_deduction) + grossed
    fed_gross = (progressive_tax(taxable, F["federal_brackets"])
                 - F["fed_credit_rate"] * (F["fed_basic_personal"] + credit_contribs)
                 - F["dividend_credit_fed_noneligible"] * grossed)
    qc = (progressive_tax(taxable, F["quebec_brackets"])
          - F["quebec_credit_rate"] * (F["quebec_basic_personal"] + credit_contribs)
          - F["dividend_credit_qc_noneligible"] * grossed)
    return max(0.0, fed_gross) * (1 - F["quebec_abatement"]), max(0.0, qc)


def reserve(P):
    r = P["retrait"]
    exp = model.recurring_expenses_annual(P, "individuelle", r["reserve_scenario"])
    return r["reserve_months_of_expenses"] / 12 * exp


def societe_extra_cost(P):
    sc = P["retrait"]["reserve_scenario"]
    return (model.recurring_expenses_annual(P, "societe", sc)
            - model.recurring_expenses_annual(P, "individuelle", sc))


# ---------------------------------------------------------------- entreprise individuelle
def individual(P, B):
    F = P["fiscalite"]
    rrq = rrq_total(F, B)
    rqap = rqap_selfemployed(F, B)
    half = F["rrq_deduction_share"] * rrq
    fed, qc = personal_tax(F, B, half, half + rqap)
    R = reserve(P)
    D = max(0.0, B - fed - qc - rrq - rqap - R)
    W = P["retrait"]["withdraw_share"] * D
    return {
        "structure": "individuelle", "mode": "-", "benefice_B": B, "benefice_avant_impot_structure": B,
        "impot_societe": 0.0, "cotisations_employeur": 0.0, "brut_retire": W,
        "cotisations_perso": rrq + rqap, "impot_fed": fed, "impot_qc": qc,
        "net_personnel": W,  # impôts et cotisations déjà mis de côté
        "laisse_dans_entreprise": B - fed - qc - rrq - rqap - W,
        "reserve_min": R, "distribuable": D,
    }


# ---------------------------------------------------------------- société
def employer_costs(F, salary):
    rrq_half = rrq_total(F, salary) / 2
    return (rrq_half + F["rqap_rate_employer"] * min(salary, F["rqap_ceiling"])
            + (F["fss_rate"] + F["cnesst_rate"]) * salary)


def employee_deductions(F, salary):
    """(RRQ part employé, RQAP part employé)."""
    return rrq_total(F, salary) / 2, F["rqap_rate_employee"] * min(salary, F["rqap_ceiling"])


def _company_state(P, B_soc, rate, salary, dividend):
    F = P["fiscalite"]
    emp = employer_costs(F, salary) if salary > 0 else 0.0
    taxable = max(0.0, B_soc - salary - emp)
    corp_tax = rate * taxable
    remaining = B_soc - salary - emp - corp_tax - dividend
    return emp, corp_tax, remaining


def societe(P, B, variant, mode):
    """variant : 'dpe_hyp' (20,5 %) ou 'petite_ent' (11,2 %). mode : salaire, dividendes, mixte."""
    F = P["fiscalite"]
    rate = F["corp_rate_dpe_hypothesis"] if variant == "dpe_hyp" else F["corp_rate_small_business"]
    B_soc = B - societe_extra_cost(P)
    R = reserve(P)
    D0 = max(0.0, B_soc * (1 - rate) - R)
    W_target = P["retrait"]["withdraw_share"] * D0
    s_share = {"salaire": 1.0, "dividendes": 0.0, "mixte": P["retrait"]["mixed_salary_share"]}[mode]

    def remaining_for(k):
        return _company_state(P, B_soc, rate, k * W_target * s_share, k * W_target * (1 - s_share))[2]

    k = 1.0
    if remaining_for(1.0) < R:  # la réserve ne tient plus : on réduit le retrait (bisection)
        lo, hi = 0.0, 1.0
        for _ in range(60):
            mid = (lo + hi) / 2
            if remaining_for(mid) >= R:
                lo = mid
            else:
                hi = mid
        k = lo
    salary, dividend = k * W_target * s_share, k * W_target * (1 - s_share)
    emp, corp_tax, remaining = _company_state(P, B_soc, rate, salary, dividend)
    rrq_ee, rqap_ee = employee_deductions(F, salary)
    # Employé : crédit de 14 % sur ses cotisations (pas de déduction, simplification)
    fed, qc = personal_tax(F, salary, 0.0, rrq_ee + rqap_ee, dividend)
    net = salary + dividend - rrq_ee - rqap_ee - fed - qc
    return {
        "structure": "societe_" + variant, "mode": mode, "benefice_B": B, "benefice_avant_impot_structure": B_soc,
        "impot_societe": corp_tax, "cotisations_employeur": emp, "brut_retire": salary + dividend,
        "cotisations_perso": rrq_ee + rqap_ee, "impot_fed": fed, "impot_qc": qc,
        "net_personnel": net, "laisse_dans_entreprise": remaining,
        "reserve_min": R, "distribuable": D0,
    }


# ---------------------------------------------------------------- sortie
def run(P, out_dir=None):
    rows = []
    for B in P["retrait"]["benefits_cad"]:
        rows.append(individual(P, B))
        for variant in ("dpe_hyp", "petite_ent"):
            for mode in ("salaire", "dividendes", "mixte"):
                rows.append(societe(P, B, variant, mode))
    for r in rows:
        B = r["benefice_B"]
        r["retrait_sur_B_pct"] = 100 * r["brut_retire"] / B
        r["net_personnel_sur_B_pct"] = 100 * r["net_personnel"] / B
        r["distribuable_sur_B_pct"] = 100 * r["distribuable"] / B
        r["80pct_de_B_atteint"] = "oui" if r["net_personnel"] >= 0.8 * B else "non"
    out_dir = out_dir or os.path.join(HERE, "out")
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, "retrait.csv"), "w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]), delimiter=";")
        w.writeheader()
        for r in rows:
            w.writerow({k: (round(v, 2) if isinstance(v, float) else v) for k, v in r.items()})
    return rows


def main():
    P = model.load_params()
    rows = run(P)
    print("B ; structure ; mode ; brut retiré ; net perso ; impôt société ; impôt perso ; laissé ; distribuable")
    for r in rows:
        print(f"{r['benefice_B']:>7.0f} {r['structure']:<20} {r['mode']:<10} brut {r['brut_retire']:>8.0f} "
              f"net {r['net_personnel']:>8.0f} soc {r['impot_societe']:>7.0f} "
              f"perso {r['impot_fed'] + r['impot_qc'] + r['cotisations_perso']:>7.0f} "
              f"laissé {r['laisse_dans_entreprise']:>8.0f} distr {r['distribuable']:>8.0f}")


if __name__ == "__main__":
    main()
