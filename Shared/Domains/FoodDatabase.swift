import Foundation

/// A small built-in food table (average values per 100 g, from public nutrition tables such as
/// Health Canada's Canadian Nutrient File and USDA FoodData Central). Works offline; packaged
/// products are searched on Open Food Facts.
enum FoodDatabase {
    private static func f(_ id: String, _ name: String, _ kcal: Double, _ protein: Double, _ carbs: Double, _ fat: Double, _ fiber: Double, _ serving: Double, _ servingName: String) -> FoodItem {
        FoodItem(id: "builtin.\(id)", name: name, brand: nil, kcal: kcal, protein: protein, carbs: carbs, fat: fat, fiber: fiber,
                 servingGrams: serving, servingName: servingName, source: .builtin, barcode: nil)
    }

    static let all: [FoodItem] = [
        // Fruits
        f("apple", "Pomme", 52, 0.3, 14, 0.2, 2.4, 180, "1 pomme moyenne"),
        f("banana", "Banane", 89, 1.1, 23, 0.3, 2.6, 120, "1 banane"),
        f("orange", "Orange", 47, 0.9, 12, 0.1, 2.4, 150, "1 orange"),
        f("strawberries", "Fraises", 32, 0.7, 7.7, 0.3, 2, 150, "1 tasse"),
        f("blueberries", "Bleuets", 57, 0.7, 14, 0.3, 2.4, 150, "1 tasse"),
        f("grapes", "Raisins", 69, 0.7, 18, 0.2, 0.9, 150, "1 tasse"),
        f("pear", "Poire", 57, 0.4, 15, 0.1, 3.1, 180, "1 poire"),
        f("kiwi", "Kiwi", 61, 1.1, 15, 0.5, 3, 75, "1 kiwi"),
        f("mango", "Mangue", 60, 0.8, 15, 0.4, 1.6, 165, "1 tasse"),
        f("pineapple", "Ananas", 50, 0.5, 13, 0.1, 1.4, 165, "1 tasse"),
        f("avocado", "Avocat", 160, 2, 8.5, 15, 6.7, 100, "½ avocat"),
        f("raisins", "Raisins secs", 299, 3.1, 79, 0.5, 3.7, 40, "1 petite boîte"),

        // Légumes
        f("broccoli", "Brocoli", 34, 2.8, 7, 0.4, 2.6, 90, "1 tasse"),
        f("carrot", "Carotte", 41, 0.9, 10, 0.2, 2.8, 60, "1 carotte"),
        f("tomato", "Tomate", 18, 0.9, 3.9, 0.2, 1.2, 120, "1 tomate"),
        f("cucumber", "Concombre", 15, 0.7, 3.6, 0.1, 0.5, 100, "½ concombre"),
        f("lettuce", "Laitue", 15, 1.4, 2.9, 0.2, 1.3, 50, "1 tasse"),
        f("spinach", "Épinards", 23, 2.9, 3.6, 0.4, 2.2, 30, "1 tasse crue"),
        f("pepper", "Poivron", 31, 1, 6, 0.3, 2.1, 120, "1 poivron"),
        f("onion", "Oignon", 40, 1.1, 9.3, 0.1, 1.7, 110, "1 oignon"),
        f("potato", "Pomme de terre cuite", 87, 1.9, 20, 0.1, 1.8, 170, "1 moyenne"),
        f("sweetpotato", "Patate douce cuite", 90, 2, 21, 0.2, 3.3, 150, "1 moyenne"),
        f("corn", "Maïs", 96, 3.4, 21, 1.5, 2.4, 100, "1 épi"),
        f("peas", "Petits pois", 81, 5.4, 14, 0.4, 5.1, 80, "½ tasse"),
        f("mushrooms", "Champignons", 22, 3.1, 3.3, 0.3, 1, 70, "1 tasse"),
        f("zucchini", "Courgette", 17, 1.2, 3.1, 0.3, 1, 120, "1 tasse"),

        // Féculents
        f("rice", "Riz blanc cuit", 130, 2.7, 28, 0.3, 0.4, 160, "1 tasse"),
        f("brownrice", "Riz brun cuit", 123, 2.7, 26, 1, 1.6, 160, "1 tasse"),
        f("pasta", "Pâtes cuites", 158, 5.8, 31, 0.9, 1.8, 140, "1 tasse"),
        f("quinoa", "Quinoa cuit", 120, 4.4, 21, 1.9, 2.8, 185, "1 tasse"),
        f("oats", "Flocons d'avoine", 379, 13, 68, 6.5, 10, 40, "½ tasse sèche"),
        f("bread", "Pain blanc", 265, 9, 49, 3.2, 2.7, 30, "1 tranche"),
        f("wholebread", "Pain de blé entier", 247, 13, 41, 3.4, 7, 35, "1 tranche"),
        f("bagel", "Bagel", 257, 10, 50, 1.6, 2.3, 100, "1 bagel"),
        f("tortilla", "Tortilla de blé", 312, 8.3, 52, 8, 3.5, 45, "1 tortilla"),
        f("croissant", "Croissant", 406, 8.2, 46, 21, 2.6, 60, "1 croissant"),
        f("cereal", "Céréales de maïs", 357, 7.5, 84, 0.4, 3.3, 30, "1 tasse"),
        f("granola", "Granola", 471, 10, 64, 20, 5, 50, "½ tasse"),
        f("couscous", "Couscous cuit", 112, 3.8, 23, 0.2, 1.4, 160, "1 tasse"),
        f("fries", "Frites", 312, 3.4, 41, 15, 3.8, 120, "1 portion moyenne"),

        // Protéines
        f("chicken", "Poitrine de poulet cuite", 165, 31, 0, 3.6, 0, 120, "1 portion"),
        f("chickenthigh", "Cuisse de poulet cuite", 209, 26, 0, 11, 0, 100, "1 cuisse"),
        f("beef", "Bœuf haché mi-maigre cuit", 250, 26, 0, 15, 0, 100, "1 portion"),
        f("steak", "Steak de surlonge cuit", 206, 29, 0, 9, 0, 150, "1 steak"),
        f("pork", "Filet de porc cuit", 143, 26, 0, 3.5, 0, 120, "1 portion"),
        f("ham", "Jambon", 145, 21, 1.5, 6, 0, 30, "1 tranche"),
        f("bacon", "Bacon cuit", 541, 37, 1.4, 42, 0, 16, "2 tranches"),
        f("salmon", "Saumon cuit", 206, 22, 0, 12, 0, 120, "1 filet"),
        f("tuna", "Thon en conserve (eau)", 116, 26, 0, 0.8, 0, 85, "1 petite boîte"),
        f("shrimp", "Crevettes cuites", 99, 24, 0.2, 0.3, 0, 85, "1 portion"),
        f("tofu", "Tofu ferme", 144, 17, 2.8, 8.7, 2.3, 100, "1 portion"),
        f("egg", "Œuf", 143, 13, 0.7, 9.5, 0, 50, "1 gros œuf"),
        f("eggwhite", "Blanc d'œuf", 52, 11, 0.7, 0.2, 0, 33, "1 blanc"),
        f("lentils", "Lentilles cuites", 116, 9, 20, 0.4, 7.9, 200, "1 tasse"),
        f("chickpeas", "Pois chiches cuits", 164, 8.9, 27, 2.6, 7.6, 165, "1 tasse"),
        f("blackbeans", "Haricots noirs cuits", 132, 8.9, 24, 0.5, 8.7, 170, "1 tasse"),
        f("whey", "Protéine en poudre (lactosérum)", 400, 80, 8, 6, 0, 30, "1 mesure"),

        // Produits laitiers
        f("milk2", "Lait 2 %", 50, 3.4, 4.8, 2, 0, 250, "1 tasse"),
        f("milkskim", "Lait écrémé", 34, 3.4, 5, 0.1, 0, 250, "1 tasse"),
        f("greekyogurt", "Yogourt grec nature 0 %", 59, 10, 3.6, 0.4, 0, 175, "¾ tasse"),
        f("yogurt", "Yogourt aux fruits", 95, 3.5, 16, 1.8, 0, 100, "1 pot"),
        f("cheddar", "Cheddar", 403, 25, 1.3, 33, 0, 30, "1 portion"),
        f("mozzarella", "Mozzarella", 280, 28, 3.1, 17, 0, 30, "1 portion"),
        f("cottage", "Fromage cottage", 98, 11, 3.4, 4.3, 0, 125, "½ tasse"),
        f("butter", "Beurre", 717, 0.9, 0.1, 81, 0, 10, "1 c. à thé"),
        f("soymilk", "Boisson de soya", 43, 3.3, 3, 1.8, 0.5, 250, "1 tasse"),
        f("almondmilk", "Boisson d'amande", 15, 0.6, 0.3, 1.2, 0.2, 250, "1 tasse"),

        // Noix et matières grasses
        f("almonds", "Amandes", 579, 21, 22, 50, 12, 28, "1 poignée"),
        f("peanutbutter", "Beurre d'arachide", 588, 25, 20, 50, 6, 32, "2 c. à soupe"),
        f("walnuts", "Noix de Grenoble", 654, 15, 14, 65, 6.7, 28, "1 poignée"),
        f("oliveoil", "Huile d'olive", 884, 0, 0, 100, 0, 14, "1 c. à soupe"),
        f("hummus", "Houmous", 166, 7.9, 14, 9.6, 6, 30, "2 c. à soupe"),

        // Plats et repas courants
        f("pizza", "Pizza fromage", 266, 11, 33, 10, 2.3, 110, "1 pointe"),
        f("burger", "Hamburger", 254, 13, 30, 9, 1.5, 200, "1 hamburger"),
        f("poutine", "Poutine", 227, 7, 22, 12, 2, 400, "1 portion moyenne"),
        f("sushi", "Sushis (maki)", 150, 5.8, 29, 0.7, 1, 150, "6 morceaux"),
        f("caesar", "Salade César", 190, 4.7, 7.5, 16, 1.5, 150, "1 portion"),
        f("soup", "Soupe aux légumes", 30, 1.2, 5, 0.6, 1.2, 250, "1 bol"),
        f("sandwich", "Sandwich jambon-fromage", 260, 14, 26, 11, 1.7, 150, "1 sandwich"),
        f("spaghetti", "Spaghetti sauce à la viande", 150, 7, 19, 5, 2, 350, "1 assiette"),
        f("chili", "Chili con carne", 120, 9, 11, 4.5, 3.5, 250, "1 bol"),
        f("burrito", "Burrito", 206, 9, 27, 7, 3, 250, "1 burrito"),

        // Collations et sucreries
        f("chocolate", "Chocolat noir 70 %", 598, 7.8, 46, 43, 11, 20, "2 carrés"),
        f("chips", "Croustilles", 536, 7, 53, 35, 4.4, 30, "1 petit sac"),
        f("cookie", "Biscuit aux brisures", 488, 5.4, 64, 24, 2.4, 15, "1 biscuit"),
        f("muffin", "Muffin", 377, 5.2, 55, 15, 1.5, 110, "1 muffin"),
        f("granolabar", "Barre granola", 471, 7.3, 66, 20, 4, 25, "1 barre"),
        f("popcorn", "Maïs soufflé nature", 387, 13, 78, 4.5, 15, 25, "3 tasses"),
        f("icecream", "Crème glacée", 207, 3.5, 24, 11, 0.7, 70, "½ tasse"),
        f("maple", "Sirop d'érable", 260, 0, 67, 0.1, 0, 20, "1 c. à soupe"),
        f("honey", "Miel", 304, 0.3, 82, 0, 0.2, 21, "1 c. à soupe"),

        // Boissons
        f("coffee", "Café noir", 1, 0.1, 0, 0, 0, 250, "1 tasse"),
        f("latte", "Café latte", 54, 3.4, 5.3, 2, 0, 350, "1 moyen"),
        f("orangejuice", "Jus d'orange", 45, 0.7, 10, 0.2, 0.2, 250, "1 verre"),
        f("cola", "Boisson gazeuse", 42, 0, 10.6, 0, 0, 355, "1 canette"),
        f("beer", "Bière", 43, 0.5, 3.6, 0, 0, 341, "1 bouteille"),
        f("wine", "Vin rouge", 85, 0.1, 2.6, 0, 0, 150, "1 verre"),
        f("smoothie", "Smoothie aux fruits", 60, 1, 14, 0.3, 1.2, 300, "1 verre"),
    ]

    static func item(_ id: String) -> FoodItem? {
        all.first { $0.id == id }
    }

    static func search(_ query: String) -> [FoodItem] {
        let q = normalized(query)
        guard !q.isEmpty else { return all }
        return all.filter { normalized($0.name).contains(q) }
    }

    static func normalized(_ text: String) -> String {
        text.trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Fmt.locale)
    }
}

/// Packaged products from Open Food Facts (open database, ODbL licence), by name or barcode.
enum OpenFoodFacts {
    private static func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(AppInfo.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    /// Numbers in Open Food Facts are sometimes sent as text.
    private struct Flexible: Decodable {
        let value: Double?
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let number = try? c.decode(Double.self) {
                value = number
            } else if let text = try? c.decode(String.self) {
                value = Double(text.replacingOccurrences(of: ",", with: "."))
            } else {
                value = nil
            }
        }
    }

    private struct Product: Decodable {
        let code: String?
        let product_name: String?
        let product_name_fr: String?
        let brands: String?
        let serving_quantity: Flexible?
        let serving_size: String?
        let nutriments: [String: Flexible]?

        func item(barcode: String? = nil) -> FoodItem? {
            let name = (product_name_fr?.trimmed.nonEmpty ?? product_name?.trimmed.nonEmpty)
            guard let name, let nutriments else { return nil }
            func value(_ key: String) -> Double? { nutriments[key]?.value }
            guard let kcal = value("energy-kcal_100g") ?? value("energy_100g").map({ $0 / 4.184 }) else { return nil }
            let code = barcode ?? self.code ?? UUID().uuidString
            let serving = serving_quantity?.value ?? 100
            return FoodItem(
                id: "off.\(code)",
                name: name,
                brand: brands?.split(separator: ",").first.map { String($0).trimmed },
                kcal: kcal,
                protein: value("proteins_100g") ?? 0,
                carbs: value("carbohydrates_100g") ?? 0,
                fat: value("fat_100g") ?? 0,
                fiber: value("fiber_100g") ?? 0,
                servingGrams: serving > 0 ? serving : 100,
                servingName: serving_size?.trimmed.nonEmpty ?? "\(Int(safely: serving)) g",
                source: .openFoodFacts,
                barcode: code
            )
        }
    }

    static let fields = "code,product_name,product_name_fr,brands,serving_quantity,serving_size,nutriments"

    static func search(_ query: String) async throws -> [FoodItem] {
        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "25"),
            URLQueryItem(name: "fields", value: fields),
        ]
        let (data, response) = try await URLSession.shared.data(for: request(components.url!))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw WeatherError.badResponse }
        struct Page: Decodable { let products: [Product]? }
        let page = try JSONDecoder().decode(Page.self, from: data)
        return (page.products ?? []).compactMap { $0.item() }
    }

    static func product(barcode: String) async throws -> FoodItem? {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json?fields=\(fields)") else { return nil }
        let (data, response) = try await URLSession.shared.data(for: request(url))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        struct Envelope: Decodable {
            let status: Int?
            let product: Product?
        }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        return envelope.product?.item(barcode: barcode)
    }
}
