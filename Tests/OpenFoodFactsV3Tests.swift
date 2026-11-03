import XCTest
@testable import Ardane

/// Open Food Facts, API v3 et Search-a-licious (chantier 22.2), sans aucun appel réseau : les réponses sont des
/// JSON écrits en dur (celles de Nutella, d'un code inconnu et d'un code invalide et d'une recherche ont été
/// relevées sur les vrais services le 2026-11-02, puis abrégées), et `lookup` reçoit un faux service.
final class OpenFoodFactsV3Tests: XCTestCase {

    // MARK: - Réponses enregistrées

    /// API v3 : produit trouvé (Nutella, 3017624010701), champs demandés seulement.
    private let nutella = #"{"code":"3017624010701","errors":[],"product":{"brands":"Ferrero","code":"3017624010701","generic_name":"","nutriments":{"added-sugars_modifier":"~","added-sugars_unit":"g","carbohydrates_100g":57.5,"energy":2228,"energy-kcal":539,"energy-kcal_100g":539,"energy-kcal_unit":"kcal","energy-kj_100g":2228,"energy_100g":2228,"fat_100g":30.9,"proteins_100g":6.3,"salt_100g":0.1075,"saturated-fat_100g":10.6,"sodium_100g":0.043,"sugars_100g":56.3},"nutrition_data":"on","product_name":"Nutella","product_name_en":"Nutella"},"result":{"id":"product_found","lc_name":"Product found","name":"Product found"},"status":"success","warnings":[]}"#

    /// API v3 : code valide absent de la base (HTTP 404).
    private let productNotFound = #"{"code":"8712345678906","errors":[{"field":{"id":"code","value":"8712345678906"},"impact":{"id":"failure","lc_name":"Failure","name":"Failure"},"message":{"id":"product_not_found","lc_name":"","name":""}}],"result":{"id":"product_not_found","lc_name":"Product not found","name":"Product not found"},"status":"failure","warnings":[]}"#

    /// API v3 : « 123 » n'est pas un code-barres (HTTP 404 aussi, avec `invalid_code` ET `product_not_found`).
    private let invalidCode = #"{"code":"00000123","errors":[{"field":{"id":"code","value":"123"},"impact":{"id":"failure","lc_name":"Failure","name":"Failure"},"message":{"id":"invalid_code","lc_name":"Invalid code","name":"Invalid code"}},{"field":{"id":"code","value":"00000123"},"impact":{"id":"failure","lc_name":"Failure","name":"Failure"},"message":{"id":"product_not_found","lc_name":"","name":""}}],"result":{"id":"product_not_found","lc_name":"Product not found","name":"Product not found"},"status":"failure","warnings":[]}"#

    /// `invalid_code` seul, avec un HTTP 400 : même réponse pour la personne.
    private let invalidCodeOnly = #"{"code":"","errors":[{"message":{"id":"invalid_code"}}],"result":{"id":"invalid_code"},"status":"failure"}"#

    /// Produit connu sans ses valeurs nutritives (deux marques, séparées par une virgule).
    private let nameOnly = #"{"code":"3000000000017","errors":[],"product":{"brands":"Maison, Autre","code":"3000000000017","nutriments":{},"product_name":"Biscuit sans valeurs"},"result":{"id":"product_found"},"status":"success"}"#

    /// Search-a-licious : deux fiches relevées (`brands` en tableau, nutriments en `*_100g`), puis trois fiches
    /// construites pour la tolérance : nom par langue et marque en texte, fiche sans nutriments, fiche illisible.
    private let searchPage = #"{"hits":[{"code":"80050698","brands":["ferrero","Nutella"],"nutriments":{"carbohydrates_100g":57.3,"energy-kcal_100g":544,"energy-kj_100g":2278,"fat_100g":31.6,"proteins_100g":6,"salt_100g":0.11,"saturated-fat_100g":11,"sodium_100g":0.044,"sugars_100g":56.8},"product_name":"Nutella","product_name_en":"Ferrero)","product_name_fr":"Nutella"},{"code":"3017624047509","brands":["Nutella","ferrero"],"nutriments":{"fiber_100g":4,"fat_100g":31,"salt_100g":0.03,"saturated-fat_100g":10,"sodium_100g":0.012,"energy-kcal_100g":530,"proteins_100g":6.8,"carbohydrates_100g":56,"sugars_100g":55},"product_name":"Nutella","product_name_fr":"Nutella"},{"code":"111","brands":"Maison","serving_quantity":"125","serving_size":"1 pot (125 g)","nutriments":{"energy-kcal_100g":60,"proteins_100g":4,"carbohydrates_100g":5,"fat_100g":3},"product_name":{"en":"Plain yogurt","fr":"Yaourt nature"}},{"code":"222","brands":["Sans valeurs"],"product_name":"Sans nutriments"},"illisible"],"aggregations":null,"facets":{},"charts":{},"page":1,"page_size":25,"page_count":1,"count":3,"is_count_exact":true,"warnings":null}"#

    // MARK: - Faux service

    /// Répond selon le dernier segment de l'URL (le code demandé) et note chaque demande. Un code sans réponse
    /// prévue est « introuvable » (404).
    private final class FakeService {
        var requests: [URL] = []
        private let answers: [String: (Int, String)]

        init(_ answers: [String: (Int, String)]) { self.answers = answers }

        var codes: [String] { requests.map(\.lastPathComponent) }

        func fetch(_ url: URL) async throws -> OpenFoodFacts.Answer {
            requests.append(url)
            let (status, body) = answers[url.lastPathComponent] ?? (404, #"{"errors":[{"message":{"id":"product_not_found"}}],"result":{"id":"product_not_found"},"status":"failure"}"#)
            return (Data(body.utf8), status)
        }
    }

    private func read(_ body: String, status: Int, barcode: String = "3017624010701") throws -> OpenFoodFacts.BarcodeResult {
        try OpenFoodFacts.barcodeResult(fromResponse: Data(body.utf8), statusCode: status, barcode: barcode)
    }

    private struct NotAFood: Error {}

    private func food(_ result: OpenFoodFacts.BarcodeResult, file: StaticString = #filePath, line: UInt = #line) throws -> FoodItem {
        guard case .food(let item) = result else {
            XCTFail("Une fiche complète était attendue : \(result)", file: file, line: line)
            throw NotAFood()
        }
        return item
    }

    // MARK: - API v3 : une réponse

    func testV3ProductFoundGivesTheFood() throws {
        let item = try food(read(nutella, status: 200))
        XCTAssertEqual(item.id, "off.3017624010701")
        XCTAssertEqual(item.barcode, "3017624010701")
        XCTAssertEqual(item.source, .openFoodFacts)
        XCTAssertEqual(item.name, "Nutella")
        XCTAssertEqual(item.brand, "Ferrero")
        XCTAssertEqual(item.displayName, "Nutella · Ferrero")
        XCTAssertEqual(item.kcal, 539, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(item.knownProtein), 6.3, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(item.knownCarbs), 57.5, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(item.knownFat), 30.9, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(item.sugars), 56.3, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(item.saturatedFat), 10.6, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(item.sodiumMg), 43, accuracy: 0.001, "0,043 g de sodium = 43 mg")
        XCTAssertEqual(item.servingGrams, 100)
        XCTAssertFalse(item.hasUnknownMacros)
    }

    func testV3ProductNotFoundIs404AndUnknown() throws {
        XCTAssertEqual(try read(productNotFound, status: 404), .unknown)
    }

    func testV3NotFoundWithoutReadableBodyIsStillUnknown() throws {
        XCTAssertEqual(try read("", status: 404), .unknown)
        XCTAssertEqual(try read("<html>Not Found</html>", status: 404), .unknown)
    }

    func testV3ProductNotFoundAnswerIsUnknownWhateverTheHTTPStatus() throws {
        XCTAssertEqual(try read(productNotFound, status: 200), .unknown, "Un 200 qui dit « introuvable » reste introuvable")
    }

    func testV3InvalidCodeIsUnknown() throws {
        XCTAssertEqual(try read(invalidCode, status: 404, barcode: "123"), .unknown)
        XCTAssertEqual(try read(invalidCodeOnly, status: 400, barcode: "abc"), .unknown)
        XCTAssertEqual(try read(invalidCodeOnly, status: 200, barcode: "abc"), .unknown)
    }

    func testV3ProductWithoutNutritionIsPartial() throws {
        let result = try read(nameOnly, status: 200, barcode: "3000000000017")
        guard case .partial(let item) = result else { return XCTFail("Une fiche partielle était attendue : \(result)") }
        XCTAssertEqual(item.name, "Biscuit sans valeurs")
        XCTAssertEqual(item.brand, "Maison", "La première marque seulement")
        XCTAssertEqual(item.barcode, "3000000000017")
        XCTAssertEqual(item.source, .custom)
        XCTAssertEqual(item.kcal, 0)
    }

    func testV3SuccessWithoutProductIsUnknown() throws {
        XCTAssertEqual(try read(#"{"status":"success","result":{"id":"product_found"}}"#, status: 200), .unknown)
        XCTAssertEqual(try read(#"{"status":"failure"}"#, status: 200), .unknown)
    }

    func testV3EnvelopeToleratesOddTypes() throws {
        // `status` en nombre, `errors` en texte, `result` en tableau : rien de tout cela ne doit faire échouer la lecture.
        let body = #"{"status":1,"errors":"aucune","result":[],"product":{"product_name":"Pain","nutriments":{"energy-kcal_100g":250}}}"#
        let item = try food(read(body, status: 200, barcode: "123"))
        XCTAssertEqual(item.name, "Pain")
        XCTAssertEqual(item.kcal, 250, accuracy: 0.001)
    }

    func testV3Busy429And503AreNotOffline() {
        for (status, body) in [(429, "<html><body>Too Many Requests</body></html>"), (429, ""),
                               (503, "<html><body>Service Unavailable</body></html>"), (503, #"{"status":"failure"}"#)] {
            XCTAssertThrowsError(try read(body, status: status), "HTTP \(status)") { error in
                XCTAssertEqual(error as? OpenFoodFacts.Failure, .busy, "HTTP \(status)")
            }
        }
    }

    func testV3OtherFailuresAreBadResponses() {
        XCTAssertThrowsError(try read("<html>Erreur</html>", status: 500)) { error in
            XCTAssertNil(error as? OpenFoodFacts.Failure, "Un 500 n'est pas « service occupé »")
            XCTAssertNotNil(error as? ServiceError)
        }
        XCTAssertThrowsError(try read("pas du json", status: 200)) { error in
            XCTAssertNotNil(error as? ServiceError, "Un 200 illisible (page d'un portail Wi-Fi) n'est pas « introuvable »")
        }
        XCTAssertThrowsError(try read(#"{"status":"failure"}"#, status: 502))
    }

    // MARK: - API v3 : les demandes

    func testV3ProductURL() throws {
        let url = try XCTUnwrap(OpenFoodFacts.productURL("3017624010701"))
        XCTAssertEqual(url.absoluteString, "https://world.openfoodfacts.org/api/v3/product/3017624010701?fields=\(OpenFoodFacts.fields)")
        XCTAssertFalse(url.absoluteString.contains("/api/v2/"))
        XCTAssertFalse(url.absoluteString.contains(".json"))
        XCTAssertTrue(OpenFoodFacts.fields.hasPrefix("code,product_name,product_name_fr,product_name_en,generic_name,brands,"))
    }

    func testProductURLRefusesWhatIsNotDigits() {
        for code in ["", "abc", "30176 24", "../etc", "3017624010701?x=1", "３０１７"] {
            XCTAssertNil(OpenFoodFacts.productURL(code), code)
        }
    }

    func testEAN13AndUPCAAreOneRequestEach() async throws {
        for code in ["3017624010701", "0012345678905", "012345678905", "8712345678906", "0000000000017"] {
            XCTAssertEqual(OpenFoodFacts.lookupForms(code), [code], "\(code) : une seule forme")
        }
        let service = FakeService(["3017624010701": (200, nutella)])
        let result = try await OpenFoodFacts.lookup(barcode: "3017624010701", fetch: service.fetch)
        XCTAssertEqual(service.codes, ["3017624010701"])
        XCTAssertEqual(try food(result).name, "Nutella")
    }

    func testUnknownEAN13StopsAfterOneRequest() async throws {
        let service = FakeService([:])
        let result = try await OpenFoodFacts.lookup(barcode: "8712345678906", fetch: service.fetch)
        XCTAssertEqual(result, .unknown)
        XCTAssertEqual(service.codes, ["8712345678906"], "Plus de formes en série : introuvable après une demande")
    }

    func testUPCEIsAskedAsItIsThenAsUPCA() {
        XCTAssertEqual(OpenFoodFacts.upcEToUPCA("01234565"), "012345000065")
        XCTAssertEqual(OpenFoodFacts.lookupForms("01234565"), ["01234565", "012345000065"])
        // Un EAN-8 (8 chiffres qui ne se développent pas) n'a qu'une forme.
        XCTAssertEqual(OpenFoodFacts.lookupForms("80050698"), ["80050698"])
        XCTAssertEqual(OpenFoodFacts.lookupForms("20123457"), ["20123457"])
    }

    func testUPCEFoundOnTheUPCAForm() async throws {
        let body = nutella.replacingOccurrences(of: "3017624010701", with: "012345000065")
        let service = FakeService(["012345000065": (200, body)])
        let result = try await OpenFoodFacts.lookup(barcode: "01234565", fetch: service.fetch)
        XCTAssertEqual(service.codes, ["01234565", "012345000065"], "La forme telle quelle d'abord, puis l'UPC-A développé")
        let item = try food(result)
        XCTAssertEqual(item.barcode, "01234565", "La fiche garde le code scanné")
        XCTAssertEqual(item.id, "off.01234565")
    }

    func testUPCEFoundAsItIsAsksOnce() async throws {
        let body = nutella.replacingOccurrences(of: "3017624010701", with: "01234565")
        let service = FakeService(["01234565": (200, body)])
        let result = try await OpenFoodFacts.lookup(barcode: "01234565", fetch: service.fetch)
        XCTAssertEqual(service.codes, ["01234565"])
        _ = try food(result)
    }

    func testUPCEUnknownInBothFormsIsUnknown() async throws {
        let service = FakeService([:])
        let result = try await OpenFoodFacts.lookup(barcode: "01234565", fetch: service.fetch)
        XCTAssertEqual(result, .unknown)
        XCTAssertEqual(service.codes, ["01234565", "012345000065"])
    }

    func testUPCEPartialThenFullKeepsTheFullFood() async throws {
        let partial = nameOnly.replacingOccurrences(of: "3000000000017", with: "01234565")
        let full = nutella.replacingOccurrences(of: "3017624010701", with: "012345000065")
        let service = FakeService(["01234565": (200, partial), "012345000065": (200, full)])
        let result = try await OpenFoodFacts.lookup(barcode: "01234565", fetch: service.fetch)
        XCTAssertEqual(try food(result).name, "Nutella")
        // Fiche partielle seulement : elle est rendue, après avoir essayé l'autre forme.
        let onlyPartial = FakeService(["01234565": (200, partial)])
        let kept = try await OpenFoodFacts.lookup(barcode: "01234565", fetch: onlyPartial.fetch)
        guard case .partial(let item) = kept else { return XCTFail("Une fiche partielle était attendue : \(kept)") }
        XCTAssertEqual(item.name, "Biscuit sans valeurs")
        XCTAssertEqual(onlyPartial.codes, ["01234565", "012345000065"])
    }

    func testLookupBusyStopsAtOnceAndIsNotOffline() async {
        let service = FakeService(["01234565": (429, "Too Many Requests")])
        do {
            _ = try await OpenFoodFacts.lookup(barcode: "01234565", fetch: service.fetch)
            XCTFail("429 devait lancer « service occupé »")
        } catch OpenFoodFacts.Failure.busy {
            XCTAssertEqual(service.codes, ["01234565"], "Pas de seconde demande quand le service est occupé")
        } catch {
            XCTFail("Une autre erreur que « service occupé » : \(error)")
        }
        let overloaded = FakeService(["3017624010701": (503, "Service Unavailable")])
        do {
            _ = try await OpenFoodFacts.lookup(barcode: "3017624010701", fetch: overloaded.fetch)
            XCTFail("503 devait lancer « service occupé »")
        } catch OpenFoodFacts.Failure.busy {
        } catch {
            XCTFail("Une autre erreur que « service occupé » : \(error)")
        }
    }

    func testLookupLetsConnectionErrorsThrough() async {
        struct Offline: Error {}
        do {
            _ = try await OpenFoodFacts.lookup(barcode: "3017624010701") { _ in throw Offline() }
            XCTFail("Une erreur réseau devait remonter")
        } catch is Offline {
        } catch {
            XCTFail("Une autre erreur que celle du réseau : \(error)")
        }
    }

    func testBarcodeFormsStillMatchTheOwnFoods() {
        // Servent encore à retrouver les aliments de la personne sans réseau, jamais à interroger Open Food Facts.
        XCTAssertTrue(OpenFoodFacts.barcodeForms("012345678905").contains("0012345678905"))
        XCTAssertTrue(OpenFoodFacts.barcodeForms("0012345678905").contains("012345678905"))
        XCTAssertTrue(OpenFoodFacts.barcodeForms("01234565").contains("012345000065"))
    }

    // MARK: - Search-a-licious

    func testSearchURL() throws {
        let url = try XCTUnwrap(OpenFoodFacts.searchURL("yaourt nature"))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.host, "search.openfoodfacts.org")
        XCTAssertEqual(components.path, "/search")
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(items["q"], "yaourt nature")
        XCTAssertEqual(items["langs"], "fr")
        XCTAssertEqual(items["page_size"], "25")
        XCTAssertEqual(items["fields"], "code,product_name,product_name_fr,product_name_en,brands,serving_quantity,serving_size,nutriments")
        XCTAssertFalse(url.absoluteString.contains("cgi/search.pl"))
    }

    func testSearchTextKeepsTheWordsOnly() {
        XCTAssertEqual(OpenFoodFacts.searchText("  yaourt   nature "), "yaourt nature")
        XCTAssertEqual(OpenFoodFacts.searchText("lait:2"), "lait 2", "Un mot suivi de deux-points serait lu comme un nom de champ")
        XCTAssertEqual(OpenFoodFacts.searchText("\"yaourt nature"), "yaourt nature")
        XCTAssertEqual(OpenFoodFacts.searchText("coca-cola"), "coca-cola")
        XCTAssertEqual(OpenFoodFacts.searchText("crème brûlée"), "crème brûlée")
        XCTAssertEqual(OpenFoodFacts.searchText(" : \" \\ "), "")
    }

    func testSearchWithoutWordsAsksNothing() async throws {
        // Aucun mot lisible : la liste est vide avant toute demande (ce test n'a donc pas besoin du réseau).
        let found = try await OpenFoodFacts.search(" : ")
        XCTAssertTrue(found.isEmpty)
    }

    func testSearchHitsBecomeFoods() throws {
        let foods = try OpenFoodFacts.searchResults(fromResponse: Data(searchPage.utf8), statusCode: 200)
        XCTAssertEqual(foods.map(\.id), ["off.80050698", "off.3017624047509", "off.111"],
                       "Les fiches sans nutriments et la fiche illisible sont écartées, les autres gardent l'ordre du service")
        let first = foods[0]
        XCTAssertEqual(first.name, "Nutella", "Le nom français d'abord")
        XCTAssertEqual(first.brand, "ferrero", "`brands` est un tableau : la première marque")
        XCTAssertEqual(first.barcode, "80050698")
        XCTAssertEqual(first.source, .openFoodFacts)
        XCTAssertEqual(first.kcal, 544, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(first.knownProtein), 6, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(first.knownCarbs), 57.3, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(first.knownFat), 31.6, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(first.sodiumMg), 44, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(first.sugars), 56.8, accuracy: 0.001)
        XCTAssertEqual(first.fiber, 0, "Les fibres absentes ne sont pas inventées")
        XCTAssertEqual(foods[1].fiber, 4, accuracy: 0.001)
        XCTAssertEqual(foods[1].brand, "Nutella")
    }

    func testSearchHitToleratesNamesPerLanguageAndABrandText() throws {
        let foods = try OpenFoodFacts.searchResults(fromResponse: Data(searchPage.utf8), statusCode: 200)
        let yogurt = try XCTUnwrap(foods.last)
        XCTAssertEqual(yogurt.name, "Yaourt nature", "Nom par langue : le français d'abord")
        XCTAssertEqual(yogurt.brand, "Maison")
        XCTAssertEqual(yogurt.servingGrams, 125)
        XCTAssertEqual(yogurt.servingName, "1 pot (125 g)")
    }

    func testSearchWithNoHitsIsEmpty() throws {
        XCTAssertTrue(try OpenFoodFacts.searchResults(fromResponse: Data(#"{"hits":[],"count":0}"#.utf8), statusCode: 200).isEmpty)
        XCTAssertTrue(try OpenFoodFacts.searchResults(fromResponse: Data(#"{"count":0}"#.utf8), statusCode: 200).isEmpty)
    }

    func testSearchBusyAndFailures() {
        for status in [429, 503] {
            XCTAssertThrowsError(try OpenFoodFacts.searchResults(fromResponse: Data("<html>Occupé</html>".utf8), statusCode: status)) { error in
                XCTAssertEqual(error as? OpenFoodFacts.Failure, .busy, "HTTP \(status)")
            }
        }
        XCTAssertThrowsError(try OpenFoodFacts.searchResults(fromResponse: Data(searchPage.utf8), statusCode: 500)) { error in
            XCTAssertNotNil(error as? ServiceError)
        }
        XCTAssertThrowsError(try OpenFoodFacts.searchResults(fromResponse: Data("pas du json".utf8), statusCode: 200))
    }

    // MARK: - User-Agent

    func testUserAgentCarriesTheRealVersionAndTheSupportAddress() {
        XCTAssertEqual(AppInfo.makeUserAgent(version: "2.3"), "Ardane/2.3 (support.ardane@gmail.com)")
        let bundleVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?.trimmed.nonEmpty
        XCTAssertEqual(AppInfo.appVersion, bundleVersion ?? "1.0")
        XCTAssertEqual(AppInfo.userAgent, "Ardane/\(AppInfo.appVersion) (\(AppInfo.supportEmail))")
        XCTAssertTrue(AppInfo.userAgent.hasPrefix("Ardane/"))
        XCTAssertTrue(AppInfo.userAgent.hasSuffix(" (support.ardane@gmail.com)"))
    }
}
