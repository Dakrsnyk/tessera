import XCTest
@testable import Tessera

/// Business: files read the right way round. An expense is never counted as income, whatever the export:
/// a type column (« depense » / « revenu »), debit and credit columns, a direction column, a sign in any
/// form, or a bank file without a header. The balance is never an amount.
final class BusinessCSVTests: XCTestCase {
    private func sum(_ values: [Double]) -> Double { values.reduce(0, +) }

    // MARK: The file of the report

    /// The person's own file, as it came: BOM, « ; », unaccented types, statuses, trailing empty line.
    private let reported = "\u{FEFF}" + """
    date;type;categorie;description;montant;devise;statut;client_fournisseur;mode_paiement;recurrence
    2026-10-01;revenu;Vente;Vente produit A;1250.0;EUR;payé;Client Alpha;virement;ponctuel
    2026-10-02;depense;Logiciels;Abonnement logiciel;49.99;EUR;payé;SaaS Exemple;carte;mensuel
    2026-10-03;depense;Publicité;Campagne publicitaire test;150.0;EUR;payé;Plateforme Ads;carte;ponctuel
    2026-10-04;revenu;Prestation;Prestation de service;680.0;EUR;payé;Client Beta;virement;ponctuel
    2026-10-05;depense;Hébergement;Hébergement web;18.0;EUR;payé;Hébergeur Exemple;carte;mensuel
    2026-10-06;depense;Matériel;Accessoires de bureau;75.5;EUR;à payer;Fournisseur Gamma;virement;ponctuel
    2026-10-07;revenu;Abonnements;Abonnements clients;299.97;EUR;prévu;Clients abonnés;prélèvement;mensuel
    2026-10-08;depense;Transport;Déplacement professionnel;32.4;EUR;payé;Transport Exemple;carte;ponctuel
    2026-10-09;revenu;Vente;Vente produit B;420.0;EUR;payé;Client Delta;virement;ponctuel
    2026-10-10;depense;Frais bancaires;Frais de compte;12.0;EUR;payé;Banque Exemple;prélèvement;mensuel
    2026-10-11;depense;Marketing;Création de contenu;95.0;EUR;payé;Créatif Exemple;virement;ponctuel
    2026-10-12;revenu;Abonnements;Abonnement mensuel client;6.99;EUR;prévu;Client Epsilon;prélèvement;mensuel
    """ + "\n"

    func testTheReportedFileReadsItsExpensesAsExpenses() throws {
        let batch = try BusinessCSV.parse(reported)
        XCTAssertEqual(batch.expenses.count, 7, "« depense » lines are costs")
        XCTAssertEqual(batch.sales.count, 5, "« revenu » lines are sales")
        XCTAssertEqual(sum(batch.expenses.map(\.amount)), 432.89, accuracy: 0.001)
        XCTAssertEqual(sum(batch.sales.map(\.amount)), 2_656.96, accuracy: 0.001)
        XCTAssertEqual(batch.skipped, 0)
        XCTAssertFalse(batch.directionGuessed, "The type column says it")
        XCTAssertEqual(batch.expenses.map(\.label), ["Abonnement logiciel", "Campagne publicitaire test", "Hébergement web", "Accessoires de bureau",
                                                     "Déplacement professionnel", "Frais de compte", "Création de contenu"])
        XCTAssertEqual(batch.currencies, ["eur"])
        XCTAssertEqual(batch.foreignCurrencies(home: "CAD"), ["EUR"])
        XCTAssertEqual(batch.foreignCurrencies(home: "EUR"), [], "Already in the app's currency")

        // « à payer » and « prévu »: imported, but counted apart so the preview can leave them out.
        XCTAssertEqual(batch.pendingCount, 3)
        let paid = batch.withoutPending()
        XCTAssertEqual(paid.expenses.count, 6)
        XCTAssertEqual(paid.sales.count, 3)
        XCTAssertEqual(sum(paid.sales.map(\.amount)), 2_350, accuracy: 0.001)

        // In an app in CAD: converted line by line, still on the right side.
        let history = FXHistory(home: "CAD", rates: ["EUR": ["2026-10-01": 2, "2026-10-08": 2]])
        let converted = batch.converted(with: history)
        XCTAssertTrue(converted.unconverted.isEmpty)
        XCTAssertEqual(sum(converted.expenses.map(\.amount)), 865.78, accuracy: 0.001)
        XCTAssertEqual(sum(converted.sales.map(\.amount)), 5_313.92, accuracy: 0.001)
        XCTAssertEqual(converted.expenses.first?.original?.amount ?? 0, 49.99, accuracy: 0.001)
        XCTAssertEqual(converted.expenses.first?.original?.currency, "EUR")
    }

    func testAFileImportedTheWrongWayRoundBeforeIsSetRight() throws {
        let batch = try BusinessCSV.parse(reported)
        // What an older version did: every line a sale, with the same ids.
        var state = BusinessState()
        state.sales = batch.sales + batch.expenses.map {
            SalesEntry(date: $0.date, amount: $0.amount, orders: 1, note: $0.label, source: $0.source, externalID: $0.externalID)
        }
        let result = state.merge(batch)
        XCTAssertEqual(result.added, 0, "Nothing added twice")
        XCTAssertEqual(result.updated, 7, "The costs move to their side")
        XCTAssertEqual(state.sales.count, 5)
        XCTAssertEqual(state.expenses.count, 7)
        XCTAssertEqual(state.merge(try BusinessCSV.parse(reported)).unchanged, 12, "The same file again changes nothing")
    }

    // MARK: Amounts

    func testNegativeAmountsInEveryForm() {
        for text in ["-12.50", "\u{2212}12,50", "(12.50)", "12.50-", "- 12,50", "-$12.50", "$-12.50", "USD -12.50", "12.50 DR", "–12,50 €"] {
            XCTAssertEqual(BusinessCSV.amount(text) ?? 0, -12.5, accuracy: 0.000_1, text)
        }
        XCTAssertEqual(BusinessCSV.amount("12.50 CR"), 12.5)
        XCTAssertEqual(BusinessCSV.amount("1\u{202F}234,56"), 1_234.56, "Narrow no-break space")
        XCTAssertEqual(BusinessCSV.amount("1\u{00A0}234,56"), 1_234.56, "No-break space")
        XCTAssertEqual(BusinessCSV.amount("1 234,56"), 1_234.56)
        XCTAssertEqual(BusinessCSV.amount("1,234.56"), 1_234.56)
        XCTAssertEqual(BusinessCSV.amount("1.234,56"), 1_234.56)
        XCTAssertEqual(BusinessCSV.amount("1.234.567"), 1_234_567)
        XCTAssertEqual(BusinessCSV.amount("1'234.50"), 1_234.5)
        XCTAssertNil(BusinessCSV.amount("—"))
        XCTAssertNil(BusinessCSV.amount(""))
    }

    func testTheCurrencyOfACell() {
        XCTAssertEqual(BusinessCSV.money("USD -12.50")?.currency, "USD")
        XCTAssertEqual(BusinessCSV.money("12,50 €")?.currency, "EUR")
        XCTAssertEqual(BusinessCSV.money("CA$ 5,00")?.currency, "CAD")
        XCTAssertEqual(BusinessCSV.money("US$5")?.currency, "USD")
        XCTAssertNil(BusinessCSV.money("1 234,56 $")?.currency, "A dollar alone says nothing")
        XCTAssertNil(BusinessCSV.money("12.50 DR")?.currency)
    }

    func testATabFileWithSignsAndCurrencies() throws {
        let batch = try BusinessCSV.parse("Date\tDescription\tAmount\n2026-10-01\tVente\t$1,234.56\n2026-10-02\tAchat\t(12.50)\n2026-10-03\tFrais\tUSD -3.00\n")
        XCTAssertEqual(batch.sales.map(\.amount), [1_234.56])
        XCTAssertEqual(batch.expenses.map(\.amount), [12.5, 3])
        XCTAssertEqual(batch.entryCurrencies.values.sorted(), ["USD"], "The currency the cell says")
    }

    // MARK: Two columns

    func testDebitAndCreditColumnsOfEveryName() throws {
        for pair in [("Débit", "Crédit"), ("Debit", "Credit"), ("Retrait", "Dépôt"), ("Withdrawal", "Deposit"), ("Withdrawals", "Deposits"),
                     ("Money out", "Money in"), ("Paid out", "Paid in"), ("Sortie", "Entrée"), ("Montant débit", "Montant crédit"),
                     ("Dépenses", "Revenus"), ("Expense", "Income"), ("Debit Amount", "Credit Amount")] {
            let csv = "Date,Description,\(pair.0),\(pair.1),Balance\n2026-10-01,Vente,,100.00,100.00\n2026-10-02,Achat,30.00,,70.00\n"
            let batch = try BusinessCSV.parse(csv)
            XCTAssertEqual(batch.sales.map(\.amount), [100], pair.0)
            XCTAssertEqual(batch.expenses.map(\.amount), [30], pair.0)
            XCTAssertEqual(batch.expenses.first?.label, "Achat")
            XCTAssertFalse(batch.directionGuessed)
        }
    }

    func testDesjardinsRetraitDepotSolde() throws {
        let csv = "Date,Description,Retrait,Dépôt,Solde\n2026-10-01,Vente marché,,250.00,1250.00\n2026-10-02,Loyer,800.00,,450.00\n2026-10-03,Frais mensuels,4.95,,445.05\n"
        let batch = try BusinessCSV.parse(csv)
        XCTAssertEqual(batch.sales.map(\.amount), [250])
        XCTAssertEqual(batch.expenses.map(\.amount), [800, 4.95], "The balance is never the amount")
    }

    func testBNCMontantDebitCreditWithFrenchNumbers() throws {
        let csv = "Date;Description;Montant débit;Montant crédit;Solde\n01/10/2026;Paiement fournisseur;\"1\u{202F}234,56\";;10\u{00A0}000,00\n02/10/2026;Virement client;;\"2 500,00\";12 500,00\n"
        let batch = try BusinessCSV.parse(csv)
        XCTAssertEqual(batch.expenses.map(\.amount), [1_234.56], "« Montant débit » isn't « Montant »")
        XCTAssertEqual(batch.sales.map(\.amount), [2_500])
    }

    func testADebitWrittenNegativeIsStillACost() throws {
        let batch = try BusinessCSV.parse("Date;Libellé;Débit;Crédit;Solde\n05/10/2026;Achat matériel;-45,90;;100,00\n06/10/2026;Vente;;120,00;220,00\n")
        XCTAssertEqual(batch.expenses.map(\.amount), [45.9])
        XCTAssertEqual(batch.sales.map(\.amount), [120])
    }

    func testTDWithoutAHeader() throws {
        // TD: date, description, withdrawal, deposit, balance, no header.
        let csv = "10/15/2026,PAYROLL DEPOSIT,,1500.00,2500.00\n10/16/2026,HYDRO BILL,120.50,,2379.50\n10/17/2026,COFFEE SHOP,4.25,,2375.25\n"
        let batch = try BusinessCSV.parse(csv)
        XCTAssertEqual(batch.sales.map(\.amount), [1_500])
        XCTAssertEqual(batch.expenses.map(\.amount), [120.5, 4.25])
        XCTAssertEqual(batch.expenses.first?.label, "HYDRO BILL")
    }

    func testRBCWithItsCurrencyColumns() throws {
        let csv = """
        Account Type,Account Number,Transaction Date,Cheque Number,Description 1,Description 2,CAD$,USD$
        Chequing,123,10/15/2026,,E-TRANSFER RECEIVED,Client,500.00,
        Chequing,123,10/16/2026,,AMAZON,Achat,-89.99,
        USD,456,10/17/2026,,STRIPE,,,-12.00
        """
        let batch = try BusinessCSV.parse(csv)
        XCTAssertEqual(batch.sales.map(\.amount), [500])
        XCTAssertEqual(batch.expenses.map(\.amount), [89.99, 12])
        XCTAssertEqual(batch.expenses.last.flatMap { $0.importKey.flatMap { batch.entryCurrencies[$0] } }, "USD")
    }

    // MARK: Type and direction columns

    func testTypeValuesSayTheDirection() throws {
        let rows: [(String, Bool)] = [("DR", true), ("CR", false), ("Débit", true), ("Crédit", false), ("Expense", true), ("Income", false),
                                      ("Achat", true), ("Paiement", true), ("Purchase", true), ("Withdrawal", true), ("Vente", false),
                                      ("Sortie", true), ("Entrée", false), ("Dépense", true), ("depenses", true), ("Revenu", false),
                                      ("REVENUS", false), ("Recette", false), ("Sale", false), ("Frais", true), ("Fee", true)]
        var csv = "Date,Description,Type,Amount\n"
        for (index, row) in rows.enumerated() { csv += "2026-10-\(String(format: "%02d", index + 1)),Ligne \(index),\(row.0),\(index + 1)0.00\n" }
        let batch = try BusinessCSV.parse(csv)
        XCTAssertEqual(batch.expenses.count, rows.filter { $0.1 }.count)
        XCTAssertEqual(batch.sales.count, rows.filter { !$0.1 }.count)
        for (index, row) in rows.enumerated() {
            let label = "Ligne \(index)"
            XCTAssertEqual(batch.expenses.contains { $0.label == label }, row.1, row.0)
        }
        XCTAssertTrue(batch.sales.allSatisfy { $0.amount > 0 })
    }

    func testASensColumnWithLetters() throws {
        let batch = try BusinessCSV.parse("Date;Libellé;Montant;Sens\n01/10/2026;Vente;100,00;C\n02/10/2026;Loyer;500,00;D\n")
        XCTAssertEqual(batch.sales.map(\.amount), [100])
        XCTAssertEqual(batch.expenses.map(\.amount), [500])
    }

    func testANegativeAmountWithAnUnknownTypeIsACost() throws {
        let batch = try BusinessCSV.parse("Date;Catégorie;Libellé;Montant\n01/10/2026;Alimentation;Épicerie;-54,20\n02/10/2026;Ventes;Marché;300,00\n")
        XCTAssertEqual(batch.expenses.map(\.amount), [54.2], "Before, a category made it a negative sale")
        XCTAssertEqual(batch.sales.map(\.amount), [300])
    }

    // MARK: Services

    func testAStripeBalanceExport() throws {
        let csv = """
        id,Type,Source,Amount,Fee,Net,Currency,Created (UTC),Description
        txn_1,charge,ch_1,100.00,3.20,96.80,cad,2026-10-01 10:00,Abonnement
        txn_2,refund,re_1,-20.00,0.00,-20.00,cad,2026-10-02 10:00,Remb
        txn_3,stripe_fee,,-5.00,0.00,-5.00,cad,2026-10-03 10:00,Radar
        txn_4,payout,po_1,-75.00,0.00,-75.00,cad,2026-10-04 10:00,Virement
        txn_5,adjustment,,-2.00,0.00,-2.00,cad,2026-10-05 10:00,Litige
        """
        let batch = try BusinessCSV.parse(csv)
        XCTAssertEqual(batch.sales.map(\.amount), [100, -20], "A payment, then its refund")
        XCTAssertEqual(batch.expenses.map(\.amount), [3.2, 5, 2], "The payment's fee, Stripe's fee, a negative adjustment")
        XCTAssertEqual(batch.skipped, 1, "A payout moves money already counted")
    }

    func testAPayPalExport() throws {
        let csv = """
        "Date","Time","TimeZone","Name","Type","Status","Currency","Gross","Fee","Net","From Email Address","Transaction ID","Item Title","Balance","Balance Impact"
        "10/15/2026","10:00:00","EDT","Client A","Express Checkout Payment","Completed","USD","50.00","-1.75","48.25","a@x.com","1AA","Affiche","48.25","Credit"
        "10/16/2026","10:00:00","EDT","Fournisseur","Express Checkout Payment","Completed","USD","-30.00","0.00","-30.00","me@x.com","2BB","Encre","18.25","Debit"
        "10/17/2026","10:00:00","EDT","","General Withdrawal","Completed","USD","-18.25","0.00","-18.25","","3CC","","0.00","Debit"
        "10/18/2026","10:00:00","EDT","Client A","Payment Refund","Completed","USD","-10.00","0.00","-10.00","","4DD","Affiche","-10.00","Debit"
        "10/19/2026","10:00:00","EDT","","General Authorization","Pending","USD","-5.00","0.00","-5.00","","5EE","","-10.00","Memo"
        """
        let batch = try BusinessCSV.parse(csv)
        XCTAssertEqual(batch.sales.map(\.amount), [50, -10], "The payment received, then its refund")
        XCTAssertEqual(batch.expenses.map(\.amount).sorted(), [1.75, 30], "PayPal's fee and the payment sent")
        XCTAssertEqual(batch.skipped, 2, "The withdrawal to the bank and the memo")
        XCTAssertEqual(batch.sales.first?.externalID, "1AA", "« Transaction ID », not the customer's name")
    }

    func testAQuickBooksTransactionList() throws {
        let csv = """
        Date,Transaction Type,Num,Name,Memo/Description,Account,Split,Amount
        10/01/2026,Invoice,1001,Client A,Site web,Accounts Receivable,Sales,1200.00
        10/02/2026,Expense,,Bureau Plus,Papier,Chequing,Office Supplies,45.00
        10/03/2026,Bill,,Hydro,Électricité,Accounts Payable,Utilities,80.00
        10/04/2026,Sales Receipt,1002,Client A,Atelier,Undeposited Funds,Sales,300.00
        """
        let batch = try BusinessCSV.parse(csv)
        XCTAssertEqual(batch.sales.map(\.amount), [1_200, 300])
        XCTAssertEqual(batch.expenses.map(\.amount), [45, 80])
        XCTAssertEqual(batch.expenses.first?.label, "Papier")
    }

    func testAWaveExportCountsEachEntryOnce() throws {
        let csv = """
        Transaction ID,Transaction Date,Account Name,Transaction Description,Amount (One column),Debit Amount (Two Column Approach),Credit Amount (Two Column Approach),Account Group
        w1,2026-10-01,Sales,Vente atelier,250.00,,250.00,Income
        w1,2026-10-01,Chequing,Vente atelier,250.00,250.00,,Assets
        w2,2026-10-02,Office,Papier,-40.00,40.00,,Expense
        w2,2026-10-02,Chequing,Papier,-40.00,,40.00,Assets
        """
        let batch = try BusinessCSV.parse(csv)
        XCTAssertEqual(batch.sales.map(\.amount), [250])
        XCTAssertEqual(batch.expenses.map(\.amount), [40])
        XCTAssertEqual(batch.skipped, 2, "The bank's side of each entry")
    }

    func testAShopifyExportIsStillSales() throws {
        let csv = "Name,Financial Status,Paid at,Total,Lineitem name,Currency\n#1001,paid,2026-10-01 10:12:13 -0400,59.90,T-shirt,CAD\n#1001,,,,Casquette,\n"
        let batch = try BusinessCSV.parse(csv)
        XCTAssertEqual(batch.sales.map(\.externalID), ["#1001"])
        XCTAssertFalse(batch.directionGuessed, "A sales export says what it holds")
    }

    // MARK: Layout

    func testAccountLinesAboveTheHeaderAndExcelSeparator() throws {
        let csv = "sep=;\nCompte;12345\n\nDate;Libellé;Montant (€);Solde\n01/10/2026;Achat;12,50-;100,00\n02/10/2026;Vente;\"1.234,56 €\";1 334,56\n"
        let batch = try BusinessCSV.parse(csv)
        XCTAssertEqual(batch.expenses.map(\.amount), [12.5], "A trailing minus")
        XCTAssertEqual(batch.sales.map(\.amount), [1_234.56])
        XCTAssertEqual(batch.currencies, ["eur"])
    }

    func testABalanceIsNeverAnAmount() {
        XCTAssertThrowsError(try BusinessCSV.parse("Date,Description,Balance\n2026-10-01,A,10.00\n2026-10-02,B,20.00\n")) { error in
            XCTAssertEqual(error as? BusinessCSV.ImportError, .missingColumns)
        }
        XCTAssertThrowsError(try BusinessCSV.parse("Date;Libellé;Solde\n01/10/2026;A;10,00\n02/10/2026;B;20,00\n"))
    }

    func testAFileThatDoesntSayIsAskedAbout() throws {
        let batch = try BusinessCSV.parse("Date,Description,Amount\n2026-10-01,Encre,10.00\n2026-10-02,Papier,20.00\n")
        XCTAssertTrue(batch.directionGuessed, "Positive amounts, no type: the preview asks")
        XCTAssertEqual(batch.sales.count, 2, "Read as sales until the person says")
        let costs = batch.asExpenses()
        XCTAssertTrue(costs.sales.isEmpty)
        XCTAssertEqual(costs.expenses.map(\.amount), [10, 20])
        XCTAssertEqual(costs.expenses.map(\.label), ["Encre", "Papier"])
        XCTAssertEqual(costs.expenses.map(\.importKey), batch.sales.map(\.importKey), "Same ids: importing again adds nothing")

        XCTAssertFalse(try BusinessCSV.parse("Date,Amount\n2026-10-01,10.00\n2026-10-02,-5.00\n").directionGuessed, "A sign says it")
    }
}
