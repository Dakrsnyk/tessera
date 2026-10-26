import os
import sys
import unittest
from copy import deepcopy

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import model  # noqa: E402

BASE = model.load_params()


def simple(sc=None, **over):
    """Paramètres de test : un seul scénario t, sans taxe, change 1, aucun remboursement."""
    P = deepcopy(BASE)
    P["change"]["usd_cad"] = 1.0
    P["taxes_apple"].update(share_inclusive=0.0, share_exclusive=0.0)
    P["paiement"].update(lag_months=0, opening_cash_cad=0, us_withholding_rate=0.0)
    s = deepcopy(P["scenarios"]["central"])
    s.update(downloads_m1=1000, growth_monthly=0.0, downloads_cap=1e9, conversion=0.01,
             mix_monthly=1.0, mix_annual=0.0, mix_lifetime=0.0, welcome_share=0.0,
             churn_monthly=0.5, annual_renewal=1.0, refund_rate=0.0,
             inactive_months=0, marketing_monthly_cad=0)
    s.update(sc or {})
    P["scenarios"]["t"] = s
    for k, v in over.items():
        P[k].update(v)
    return P


class TestModel(unittest.TestCase):
    def test_hand_case_first_months(self):
        rows = model.simulate(simple(), "t")
        # 10 nouveaux payants par mois, churn 50 % : mois 1 = 10 payants, mois 2 = 5 + 10
        self.assertAlmostEqual(rows[0]["payants_mensuels"], 10)
        self.assertAlmostEqual(rows[1]["payants_mensuels"], 15)
        self.assertAlmostEqual(rows[1]["resilies_mensuels"], 5)
        # mois 1 : 10 x 6,99 = 69,90 ; commission 30 % = 20,97 ; proceeds 48,93
        self.assertAlmostEqual(rows[0]["chiffre_affaires_ht_usd"], 69.9)
        self.assertAlmostEqual(rows[0]["commission_apple_usd"], 20.97)
        self.assertAlmostEqual(rows[0]["proceeds_usd"], 48.93)

    def test_commission_30_then_15_monthly_anniversary(self):
        rows = model.simulate(simple(), "t")
        t = 13
        # Recalcul indépendant : la cohorte c paie son k-ième mois ; k >= 13 => 15 %
        exp = 0.0
        for c in range(1, t + 1):
            k = t - c + 1
            n = 10 * 0.5 ** (k - 1)
            exp += n * 6.99 * (0.15 if k >= 13 else 0.30)
        self.assertAlmostEqual(rows[t - 1]["commission_apple_usd"], exp, places=9)
        # le mois 12 n'a aucune vente à 15 %
        exp12 = sum(10 * 0.5 ** (12 - c) * 6.99 * 0.30 for c in range(1, 13))
        self.assertAlmostEqual(rows[11]["commission_apple_usd"], exp12, places=9)

    def test_annual_commission_30_then_15_at_renewal(self):
        P = simple(sc=dict(growth_monthly=-1.0, mix_monthly=0.0, mix_annual=1.0, annual_renewal=0.6))
        rows = model.simulate(P, "t")
        ht1 = 10 * 59.99
        self.assertAlmostEqual(rows[0]["commission_apple_usd"], 0.30 * ht1)
        self.assertAlmostEqual(rows[12]["commission_apple_usd"], 0.15 * ht1 * 0.6)
        self.assertAlmostEqual(rows[24]["commission_apple_usd"], 0.15 * ht1 * 0.36)
        self.assertAlmostEqual(rows[12]["annuels_renouveles"], 6)
        self.assertAlmostEqual(rows[12]["annuels_perdus"], 4)
        self.assertEqual(rows[5]["commission_apple_usd"], 0)  # aucun paiement entre-temps

    def test_cohort_sums(self):
        # churn 0 : payants mensuels = somme des nouveaux ; renouvellement 100 % : actifs annuels = tous les achats
        P = simple(sc=dict(churn_monthly=0.0, mix_monthly=0.5, mix_annual=0.5, annual_renewal=1.0))
        rows = model.simulate(P, "t")
        for t in (1, 5, 12, 13, 30):
            self.assertAlmostEqual(rows[t - 1]["payants_mensuels"], sum(r["nouveaux_mensuels"] for r in rows[:t]))
            self.assertAlmostEqual(rows[t - 1]["abonnes_annuels_actifs"], sum(r["nouveaux_annuels"] for r in rows[:t]))
        # renouvellement 0 % : actifs = ventes des 12 derniers mois
        rows0 = model.simulate(simple(sc=dict(mix_monthly=0.5, mix_annual=0.5, annual_renewal=0.0)), "t")
        for t in (5, 12, 13, 30):
            lo = max(0, t - 12)
            self.assertAlmostEqual(rows0[t - 1]["abonnes_annuels_actifs"], sum(r["nouveaux_annuels"] for r in rows0[lo:t]))
        # Avec résiliation : actifs(t) = actifs(t-1) + nouveaux - résiliés
        rows = model.simulate(simple(), "t")
        for t in range(2, 36):
            self.assertAlmostEqual(rows[t]["payants_mensuels"],
                                   rows[t - 1]["payants_mensuels"] + rows[t]["nouveaux_mensuels"] - rows[t]["resilies_mensuels"])

    def test_welcome_offer_price(self):
        rows = model.simulate(simple(sc=dict(welcome_share=1.0)), "t")
        self.assertAlmostEqual(rows[0]["chiffre_affaires_ht_usd"], 10 * 4.99)
        # mois 4 : cohorte 1 (k=4) au plein prix, cohortes 2 à 4 (k <= 3) à 4,99
        n = lambda k: 10 * 0.5 ** (k - 1)
        self.assertAlmostEqual(rows[3]["chiffre_affaires_ht_usd"], n(4) * 6.99 + (n(3) + n(2) + n(1)) * 4.99)

    def test_taxes_separated_from_revenue(self):
        P = simple()
        P["taxes_apple"].update(share_inclusive=0.4, rate_inclusive=0.2, share_exclusive=0.3, rate_exclusive=0.1)
        for r in model.simulate(P, "t"):
            self.assertAlmostEqual(r["ventes_ttc_client_usd"], r["chiffre_affaires_ht_usd"] + r["taxes_collectees_apple_usd"])
            self.assertAlmostEqual(r["proceeds_usd"], r["chiffre_affaires_ht_usd"] - r["commission_apple_usd"])
        # Taxe ajoutée : changer son taux ne change ni le HT ni les proceeds
        A = simple()
        A["taxes_apple"].update(share_exclusive=0.5, rate_exclusive=0.0)
        B = simple()
        B["taxes_apple"].update(share_exclusive=0.5, rate_exclusive=0.25)
        ra, rb = model.simulate(A, "t"), model.simulate(B, "t")
        self.assertAlmostEqual(ra[5]["proceeds_usd"], rb[5]["proceeds_usd"])
        self.assertGreater(rb[5]["taxes_collectees_apple_usd"], ra[5]["taxes_collectees_apple_usd"])
        # Prix TTC : 6,99 TTC à 20 % => HT = 5,825
        C = simple()
        C["taxes_apple"].update(share_inclusive=1.0, rate_inclusive=0.2)
        r = model.simulate(C, "t")[0]
        self.assertAlmostEqual(r["chiffre_affaires_ht_usd"], 69.9 / 1.2)
        self.assertAlmostEqual(r["ventes_ttc_client_usd"], 69.9)

    def test_no_double_counting(self):
        P = simple(sc=dict(marketing_monthly_cad=50))
        for r in model.simulate(P, "t"):
            self.assertNotIn("commission", " ".join(r["depenses_detail"]))
            self.assertAlmostEqual(r["depenses_cad"], sum(r["depenses_detail"].values()))
            self.assertAlmostEqual(r["benefice_avant_impot_cad"], r["revenus_nets_cad"] - r["depenses_cad"])
            self.assertAlmostEqual(r["revenus_nets_usd"], r["proceeds_usd"] - r["remboursements_usd"] - r["retenue_usa_usd"])

    def test_refunds(self):
        P = simple(sc=dict(refund_rate=0.1), remboursements={"commission_kept_by_apple": True})
        r = model.simulate(P, "t")[0]
        self.assertAlmostEqual(r["remboursements_usd"], 0.1 * r["chiffre_affaires_ht_usd"])
        self.assertAlmostEqual(r["revenus_nets_usd"], r["proceeds_usd"] - 0.1 * 69.9)
        P["remboursements"]["commission_kept_by_apple"] = False
        r = model.simulate(P, "t")[0]
        self.assertAlmostEqual(r["remboursements_usd"], 0.1 * r["proceeds_usd"])

    def test_cash_is_sum_of_flows(self):
        P = simple(paiement={"lag_months": 2, "opening_cash_cad": 500})
        rows = model.simulate(P, "t")
        cash_in = sum(r["encaissement_apple_cad"] for r in rows)
        self.assertAlmostEqual(rows[-1]["tresorerie_cad"], 500 + cash_in - sum(r["depenses_cad"] for r in rows))
        # les 2 derniers mois ne sont pas encore encaissés
        self.assertAlmostEqual(cash_in, sum(r["revenus_nets_cad"] for r in rows[:-2]))
        self.assertAlmostEqual(rows[-1]["benefice_cumule_cad"], sum(r["benefice_avant_impot_cad"] for r in rows))
        self.assertEqual(rows[0]["encaissement_apple_cad"], 0)

    def test_fx(self):
        P = simple()
        P["change"]["usd_cad"] = 1.5
        r = model.simulate(P, "t")[3]
        self.assertAlmostEqual(r["revenus_nets_cad"], 1.5 * r["revenus_nets_usd"])

    def test_small_business_variant(self):
        P = simple(sc=dict(mix_monthly=0.4, mix_annual=0.4, mix_lifetime=0.2))
        r = model.simulate(P, "t", mode="small_business")
        for x in r:
            self.assertAlmostEqual(x["commission_apple_usd"], 0.15 * x["chiffre_affaires_ht_usd"])
        std = model.simulate(P, "t")
        self.assertGreater(sum(x["revenus_nets_cad"] for x in r), sum(x["revenus_nets_cad"] for x in std))

    def test_inactive_months(self):
        P = simple(sc=dict(inactive_start_month=3, inactive_months=2, marketing_monthly_cad=100))
        rows = model.simulate(P, "t")
        self.assertEqual([r["nouveaux_mensuels"] for r in rows[2:4]], [0, 0])
        self.assertGreater(rows[1]["nouveaux_mensuels"], 0)
        self.assertGreater(rows[4]["nouveaux_mensuels"], 0)
        self.assertEqual(rows[2]["depenses_detail"]["marketing"], 0)
        self.assertEqual(rows[1]["depenses_detail"]["marketing"], 100)

    def test_expenses_calendar(self):
        P = simple()
        rows = model.simulate(P, "t")
        d = P["depenses"]["individuelle"]
        self.assertEqual(rows[0]["depenses_detail"]["creation"], d["creation_cad"])
        self.assertEqual(rows[12]["depenses_detail"]["registre"], d["registry_annual_cad"])
        self.assertEqual(rows[24]["depenses_detail"]["registre"], d["registry_annual_cad"])
        self.assertEqual(sum(r["depenses_detail"]["creation"] for r in rows), d["creation_cad"])

    def test_subs_needed_hand_calc(self):
        P = simple(sc=dict(mix_monthly=1.0, mix_annual=0.0, refund_rate=0.0))
        exp = model.recurring_expenses_annual(P, "individuelle", "t")
        per_sub = 12 * 6.99 * 0.85
        self.assertEqual(model.subs_needed(P, "t", 12000), int(-(-(12000 + exp) // per_sub)))
        self.assertGreater(model.subs_needed(P, "t", 12000, rate=0.30), model.subs_needed(P, "t", 12000, rate=0.15))
        last = 0
        for target in (12000, 30000, 60000, 100000):
            n = model.subs_needed(P, "t", target)
            self.assertGreater(n, last)
            last = n

    def test_break_even(self):
        rows = model.simulate(simple(sc=dict(downloads_m1=20000)), "t")
        cum, op = model.break_even(rows)
        self.assertIsNotNone(cum)
        self.assertGreaterEqual(rows[cum - 1]["benefice_cumule_cad"], 0)
        if cum > 1:
            self.assertLess(rows[cum - 2]["benefice_cumule_cad"], 0)
        self.assertTrue(all(r["benefice_cumule_cad"] >= 0 for r in rows[cum - 1:]))
        self.assertGreater(rows[op - 1]["benefice_avant_impot_cad"], 0)

    def test_yearly_matches_monthly(self):
        rows = model.simulate(BASE, "central")
        y = model.yearly(rows)
        self.assertEqual(len(y), 3)
        self.assertAlmostEqual(sum(v["benefice_avant_impot_cad"] for v in y), rows[-1]["benefice_cumule_cad"])

    def test_scenarios_ordered(self):
        tot = {n: model.simulate(BASE, n)[-1]["benefice_cumule_cad"] for n in ("prudent", "central", "optimiste")}
        self.assertLess(tot["prudent"], tot["central"])
        self.assertLess(tot["central"], tot["optimiste"])


if __name__ == "__main__":
    unittest.main()
