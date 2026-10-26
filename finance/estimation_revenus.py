"""Estimation par palier de revenus (1 000 / 5 000 / 10 000 / 50 000 $ par mois), entreprise individuelle ou société.

Interprétation : « génère X $/mois » = versements nets d'Apple en CAD (après commission, hors taxes de vente),
avant nos dépenses. Voir docs/finance/estimation-revenus.md. Réutilise withdrawal.py (mêmes hypothèses)."""
import json
import math
import model
import withdrawal as w

NIVEAUX = (1000, 5000, 10000, 50000)
CAS = (("individuelle", None, None),
       ("societe", "dpe_hyp", "salaire"), ("societe", "dpe_hyp", "dividendes"), ("societe", "dpe_hyp", "mixte"),
       ("societe", "petite_ent", "salaire"), ("societe", "petite_ent", "dividendes"), ("societe", "petite_ent", "mixte"))


def calcul(P):
    fx = P["change"]["usd_cad"]
    sortie = []
    for m in NIVEAUX:
        revenu = 12 * m
        ligne = {"mensuel": m, "revenu_annuel": revenu, "cas": []}
        for struct, var, mode in CAS:
            depenses = model.recurring_expenses_annual(P, struct, "central")
            B = revenu - depenses
            r = w.individual(P, B) if struct == "individuelle" else w.societe(P, B, var, mode)
            perso = r["impot_fed"] + r["impot_qc"] + r["cotisations_perso"]
            ligne["cas"].append({"structure": struct, "variante": var, "mode": mode, "depenses": depenses, "benefice": B,
                                 "impot_societe": r.get("impot_societe", 0), "impot_cotis_perso": perso,
                                 "net_personnel": r["net_personnel"], "laisse": r["laisse_dans_entreprise"]})
        # abonnés actifs nécessaires (régime permanent, commission 15 % puis 30 %)
        for nom, rate in (("abonnes_15", P["commission"]["mature_rate"]), ("abonnes_30", P["commission"]["first_rate"])):
            per = model.net_per_subscriber_year_usd(P, "central", rate) * (1 - P["paiement"]["us_withholding_rate"]) * fx
            ligne[nom] = math.ceil(revenu / per)
        ligne["ventes_hors_taxes_15"] = round(m / 0.85)
        ligne["ventes_hors_taxes_30"] = round(m / 0.70)
        sortie.append(ligne)
    return sortie


if __name__ == "__main__":
    print(json.dumps(calcul(model.load_params()), ensure_ascii=False, indent=1))
