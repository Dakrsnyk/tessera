import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import model  # noqa: E402
import withdrawal as w  # noqa: E402

P = model.load_params()
F = P["fiscalite"]


class TestWithdrawal(unittest.TestCase):
    def test_progressive_tax_hand(self):
        br = [[1000, 0.10], [2000, 0.20], [None, 0.30]]
        self.assertAlmostEqual(w.progressive_tax(500, br), 50)
        self.assertAlmostEqual(w.progressive_tax(1500, br), 100 + 100)
        self.assertAlmostEqual(w.progressive_tax(2500, br), 100 + 200 + 150)
        self.assertEqual(w.progressive_tax(0, br), 0)

    def test_real_brackets_hand(self):
        self.assertAlmostEqual(w.progressive_tax(100000, F["quebec_brackets"]), 54345 * 0.14 + (100000 - 54345) * 0.19)
        self.assertAlmostEqual(w.progressive_tax(58523, F["federal_brackets"]), 58523 * 0.14)

    def test_rrq_rqap(self):
        self.assertAlmostEqual(w.rrq_total(F, 10000), 6500 * 0.126)
        self.assertAlmostEqual(w.rrq_total(F, 1000), 0)
        self.assertAlmostEqual(w.rrq_total(F, 500000), 9791, delta=1)  # maximum du fichier
        self.assertAlmostEqual(w.rqap_selfemployed(F, 500000), 103000 * 0.00764)  # 786,92

    def test_tax_monotone(self):
        last = -1
        for b in range(0, 300001, 2500):
            fed, qc = w.personal_tax(F, b, 0, 0)
            self.assertGreaterEqual(fed + qc, last - 1e-9)
            last = fed + qc
        last = -1
        for b in range(1, 300001, 5000):
            r = w.individual(P, b)
            total = r["impot_fed"] + r["impot_qc"] + r["cotisations_perso"]
            self.assertGreaterEqual(total, last - 1e-9)
            last = total

    def test_no_tax_under_basic_amount(self):
        self.assertEqual(w.personal_tax(F, 10000, 0, 0), (0.0, 0.0))

    def test_dividend_credit_lowers_tax(self):
        no_credit = dict(F, dividend_credit_fed_noneligible=0.0, dividend_credit_qc_noneligible=0.0)
        self.assertLess(sum(w.personal_tax(F, 0, 0, 0, 60000)), sum(w.personal_tax(no_credit, 0, 0, 0, 60000)))

    def test_individual_hand_case(self):
        r = w.individual(P, 10000)
        rrq, rqap = 6500 * 0.126, 10000 * 0.00764
        self.assertAlmostEqual(r["cotisations_perso"], rrq + rqap)
        self.assertEqual(r["impot_fed"] + r["impot_qc"], 0)  # sous le montant personnel de base
        R = P["retrait"]["reserve_months_of_expenses"] / 12 * model.recurring_expenses_annual(P, "individuelle", "central")
        D = 10000 - rrq - rqap - R
        self.assertAlmostEqual(r["distribuable"], D)
        self.assertAlmostEqual(r["brut_retire"], 0.8 * D)
        self.assertAlmostEqual(r["laisse_dans_entreprise"], 10000 - rrq - rqap - 0.8 * D)

    def test_withdrawal_never_exceeds_distributable(self):
        with tempfile.TemporaryDirectory() as tmp:
            for r in w.run(P, out_dir=tmp):
                self.assertLessEqual(r["brut_retire"], r["distribuable"] + 1e-6, r)
                self.assertGreaterEqual(r["laisse_dans_entreprise"], r["reserve_min"] - 1e-6, r)
                self.assertLessEqual(r["net_personnel"], r["brut_retire"] + 1e-6)

    def test_corporate_dividend_hand_case(self):
        B = 40000
        r = w.societe(P, B, "dpe_hyp", "dividendes")
        Bs = B - w.societe_extra_cost(P)
        self.assertAlmostEqual(r["impot_societe"], 0.205 * Bs)
        D0 = Bs * (1 - 0.205) - w.reserve(P)
        self.assertAlmostEqual(r["distribuable"], D0)
        self.assertAlmostEqual(r["brut_retire"], 0.8 * D0)
        self.assertAlmostEqual(r["laisse_dans_entreprise"], Bs * (1 - 0.205) - 0.8 * D0)
        self.assertEqual(r["cotisations_perso"], 0)
        fed, qc = w.personal_tax(F, 0, 0, 0, 0.8 * D0)
        self.assertAlmostEqual(r["net_personnel"], 0.8 * D0 - fed - qc)

    def test_cash_conservation_societe(self):
        # B_soc = retrait brut + charges employeur + impôt société + reste dans la société
        for B in (10000, 40000, 150000):
            for variant in ("dpe_hyp", "petite_ent"):
                for mode in ("salaire", "dividendes", "mixte"):
                    r = w.societe(P, B, variant, mode)
                    total = r["brut_retire"] + r["cotisations_employeur"] + r["impot_societe"] + r["laisse_dans_entreprise"]
                    self.assertAlmostEqual(total, r["benefice_avant_impot_structure"], places=6)

    def test_small_business_variant_pays_less_corporate_tax(self):
        a = w.societe(P, 70000, "dpe_hyp", "dividendes")
        b = w.societe(P, 70000, "petite_ent", "dividendes")
        self.assertLess(b["impot_societe"], a["impot_societe"])
        self.assertGreater(b["net_personnel"], a["net_personnel"])

    def test_salary_vs_dividend_contributions(self):
        self.assertGreater(w.societe(P, 70000, "dpe_hyp", "salaire")["cotisations_employeur"], 0)
        self.assertEqual(w.societe(P, 70000, "dpe_hyp", "dividendes")["cotisations_employeur"], 0)

    def test_reserve_binding_reduces_withdrawal(self):
        P2 = {**P, "retrait": {**P["retrait"], "withdraw_share": 1.5}}
        r = w.societe(P2, 40000, "dpe_hyp", "salaire")
        self.assertGreaterEqual(r["laisse_dans_entreprise"], r["reserve_min"] - 1e-6)
        self.assertLess(r["brut_retire"], 1.5 * r["distribuable"])

    def test_net_monotone_in_profit(self):
        for variant, mode in ((None, None), ("dpe_hyp", "dividendes"), ("dpe_hyp", "mixte")):
            last = -1
            for B in (10000, 20000, 40000, 70000, 100000, 150000):
                r = w.individual(P, B) if variant is None else w.societe(P, B, variant, mode)
                self.assertGreaterEqual(r["net_personnel"], last)
                last = r["net_personnel"]


if __name__ == "__main__":
    unittest.main()
