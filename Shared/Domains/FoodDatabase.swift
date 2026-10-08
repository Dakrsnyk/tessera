import Foundation

/// Families of the built-in foods, used to browse and to suggest ideas.
enum FoodCategory: String, CaseIterable, Identifiable {
    case fruits, vegetables, starches, proteins, dairy, fats, dishes, snacks, drinks, condiments
    var id: String { rawValue }

    var title: String {
        switch self {
        case .fruits: tr("Fruits")
        case .vegetables: tr("Légumes")
        case .starches: tr("Féculents")
        case .proteins: tr("Protéines")
        case .dairy: tr("Produits laitiers")
        case .fats: tr("Noix et graines")
        case .dishes: tr("Plats")
        case .snacks: tr("Collations")
        case .drinks: tr("Boissons")
        case .condiments: tr("Sauces et sucres")
        }
    }

    var symbol: String {
        switch self {
        case .fruits: "applelogo"
        case .vegetables: "carrot.fill"
        case .starches: "takeoutbag.and.cup.and.straw.fill"
        case .proteins: "fish.fill"
        case .dairy: "cup.and.saucer.fill"
        case .fats: "leaf.fill"
        case .dishes: "fork.knife"
        case .snacks: "birthday.cake.fill"
        case .drinks: "wineglass.fill"
        case .condiments: "drop.fill"
        }
    }
}

/// The built-in food table: average values per 100 g from public nutrition tables (Health Canada's
/// Canadian Nutrient File, USDA FoodData Central), rounded. Works offline; packaged products and
/// brands are searched on Open Food Facts. Sugars, saturated fat and sodium are given where the tables
/// have them; a value the table doesn't give stays unknown rather than zero.
enum FoodDatabase {
    private static func f(_ id: String, _ name: String, _ kcal: Double, _ protein: Double, _ carbs: Double, _ fat: Double, _ fiber: Double,
                          _ serving: Double, _ servingName: String, s: Double? = nil, sf: Double? = nil, na: Double? = nil, chol: Double? = nil) -> FoodItem {
        FoodItem(id: "builtin.\(id)", name: name, brand: nil, kcal: kcal, protein: protein, carbs: carbs, fat: fat, fiber: fiber,
                 servingGrams: serving, servingName: servingName, source: .builtin, barcode: nil,
                 sugars: s, saturatedFat: sf, sodiumMg: na, cholesterolMg: chol)
    }

    static let catalog: [(FoodCategory, [FoodItem])] = [
        (.fruits, [
            f("apple", tr("Pomme"), 52, 0.3, 14, 0.2, 2.4, 180, tr("1 pomme moyenne"), s: 10.4, sf: 0, na: 1),
            f("banana", tr("Banane"), 89, 1.1, 23, 0.3, 2.6, 120, tr("1 banane"), s: 12.2, sf: 0.1, na: 1),
            f("orange", tr("Orange"), 47, 0.9, 12, 0.1, 2.4, 150, tr("1 orange"), s: 9.4, sf: 0, na: 0),
            f("clementine", tr("Clémentine"), 47, 0.9, 12, 0.2, 1.7, 75, tr("1 clémentine"), s: 9.2, sf: 0, na: 1),
            f("strawberries", tr("Fraises"), 32, 0.7, 7.7, 0.3, 2, 150, tr("1 tasse"), s: 4.9, sf: 0, na: 1),
            f("blueberries", tr("Bleuets"), 57, 0.7, 14, 0.3, 2.4, 150, tr("1 tasse"), s: 10, sf: 0, na: 1),
            f("raspberries", tr("Framboises"), 52, 1.2, 12, 0.7, 6.5, 125, tr("1 tasse"), s: 4.4, sf: 0, na: 1),
            f("grapes", tr("Raisins"), 69, 0.7, 18, 0.2, 0.9, 150, tr("1 tasse"), s: 15.5, sf: 0.1, na: 2),
            f("pear", tr("Poire"), 57, 0.4, 15, 0.1, 3.1, 180, tr("1 poire"), s: 9.8, sf: 0, na: 1),
            f("peach", tr("Pêche"), 39, 0.9, 9.5, 0.3, 1.5, 150, tr("1 pêche"), s: 8.4, sf: 0, na: 0),
            f("plum", tr("Prune"), 46, 0.7, 11, 0.3, 1.4, 66, tr("1 prune"), s: 9.9, sf: 0, na: 0),
            f("cherries", tr("Cerises"), 63, 1.1, 16, 0.2, 2.1, 140, tr("1 tasse"), s: 12.8, sf: 0, na: 0),
            f("kiwi", tr("Kiwi"), 61, 1.1, 15, 0.5, 3, 75, tr("1 kiwi"), s: 9, sf: 0, na: 3),
            f("mango", tr("Mangue"), 60, 0.8, 15, 0.4, 1.6, 165, tr("1 tasse"), s: 13.7, sf: 0.1, na: 1),
            f("pineapple", tr("Ananas"), 50, 0.5, 13, 0.1, 1.4, 165, tr("1 tasse"), s: 9.9, sf: 0, na: 1),
            f("watermelon", tr("Melon d'eau"), 30, 0.6, 7.6, 0.2, 0.4, 280, tr("1 tranche"), s: 6.2, sf: 0, na: 1),
            f("cantaloupe", tr("Cantaloup"), 34, 0.8, 8.2, 0.2, 0.9, 160, tr("1 tasse"), s: 7.9, sf: 0.1, na: 16),
            f("grapefruit", tr("Pamplemousse"), 42, 0.8, 11, 0.1, 1.6, 120, tr("½ pamplemousse"), s: 6.9, sf: 0, na: 0),
            f("avocado", tr("Avocat"), 160, 2, 8.5, 15, 6.7, 100, tr("½ avocat"), s: 0.7, sf: 2.1, na: 7),
            f("applesauce", tr("Compote de pommes non sucrée"), 42, 0.2, 11, 0.1, 1.1, 110, tr("1 coupe"), s: 9.4, sf: 0, na: 2),
            f("raisins", tr("Raisins secs"), 299, 3.1, 79, 0.5, 3.7, 40, tr("1 petite boîte"), s: 59, sf: 0.1, na: 11),
            f("dates", tr("Dattes"), 282, 2.5, 75, 0.4, 8, 24, tr("3 dattes"), s: 63, sf: 0, na: 2),
        ]),
        (.vegetables, [
            f("broccoli", tr("Brocoli"), 34, 2.8, 7, 0.4, 2.6, 90, tr("1 tasse"), s: 1.7, sf: 0, na: 33),
            f("carrot", tr("Carotte"), 41, 0.9, 10, 0.2, 2.8, 60, tr("1 carotte"), s: 4.7, sf: 0, na: 69),
            f("tomato", tr("Tomate"), 18, 0.9, 3.9, 0.2, 1.2, 120, tr("1 tomate"), s: 2.6, sf: 0, na: 5),
            f("cucumber", tr("Concombre"), 15, 0.7, 3.6, 0.1, 0.5, 100, tr("½ concombre"), s: 1.7, sf: 0, na: 2),
            f("lettuce", tr("Laitue"), 15, 1.4, 2.9, 0.2, 1.3, 50, tr("1 tasse"), s: 0.8, sf: 0, na: 28),
            f("spinach", tr("Épinards"), 23, 2.9, 3.6, 0.4, 2.2, 30, tr("1 tasse crue"), s: 0.4, sf: 0.1, na: 79),
            f("kale", tr("Chou frisé (kale)"), 35, 2.9, 4.4, 1.5, 4.1, 30, tr("1 tasse crue"), s: 1, sf: 0.2, na: 53),
            f("pepper", tr("Poivron"), 31, 1, 6, 0.3, 2.1, 120, tr("1 poivron"), s: 4.2, sf: 0, na: 4),
            f("onion", tr("Oignon"), 40, 1.1, 9.3, 0.1, 1.7, 110, tr("1 oignon"), s: 4.2, sf: 0, na: 4),
            f("greenbeans", tr("Haricots verts"), 31, 1.8, 7, 0.2, 2.7, 100, tr("1 tasse"), s: 3.3, sf: 0, na: 6),
            f("cauliflower", tr("Chou-fleur"), 25, 1.9, 5, 0.3, 2, 100, tr("1 tasse"), s: 1.9, sf: 0.1, na: 30),
            f("cabbage", tr("Chou"), 25, 1.3, 5.8, 0.1, 2.5, 90, tr("1 tasse"), s: 3.2, sf: 0, na: 18),
            f("brusselssprouts", tr("Choux de Bruxelles"), 43, 3.4, 9, 0.3, 3.8, 90, tr("1 tasse"), s: 2.2, sf: 0.1, na: 25),
            f("asparagus", tr("Asperges"), 20, 2.2, 3.9, 0.1, 2.1, 90, tr("6 asperges"), s: 1.9, sf: 0, na: 2),
            f("celery", tr("Céleri"), 14, 0.7, 3, 0.2, 1.6, 40, tr("1 branche"), s: 1.3, sf: 0, na: 80),
            f("eggplant", tr("Aubergine"), 25, 1, 6, 0.2, 3, 80, tr("1 tasse"), s: 3.5, sf: 0, na: 2),
            f("beet", tr("Betterave"), 43, 1.6, 10, 0.2, 2.8, 80, tr("1 betterave"), s: 6.8, sf: 0, na: 78),
            f("mushrooms", tr("Champignons"), 22, 3.1, 3.3, 0.3, 1, 70, tr("1 tasse"), s: 2, sf: 0, na: 5),
            f("zucchini", tr("Courgette"), 17, 1.2, 3.1, 0.3, 1, 120, tr("1 tasse"), s: 2.5, sf: 0.1, na: 8),
            f("corn", tr("Maïs"), 96, 3.4, 21, 1.5, 2.4, 100, tr("1 épi"), s: 4.5, sf: 0.2, na: 1),
            f("peas", tr("Petits pois"), 81, 5.4, 14, 0.4, 5.1, 80, tr("½ tasse"), s: 5.7, sf: 0.1, na: 5),
            f("edamame", tr("Edamame"), 121, 12, 8.9, 5.2, 5.2, 80, tr("½ tasse"), s: 2.2, sf: 0.6, na: 6),
            f("potato", tr("Pomme de terre cuite"), 87, 1.9, 20, 0.1, 1.8, 170, tr("1 moyenne"), s: 0.9, sf: 0, na: 5),
            f("sweetpotato", tr("Patate douce cuite"), 90, 2, 21, 0.2, 3.3, 150, tr("1 moyenne"), s: 6.5, sf: 0, na: 36),
            f("gardensalad", tr("Salade du jardin (sans vinaigrette)"), 17, 1.2, 3.3, 0.2, 1.6, 150, tr("1 bol"), s: 1.8, sf: 0, na: 20),
        ]),
        (.starches, [
            f("rice", tr("Riz blanc cuit"), 130, 2.7, 28, 0.3, 0.4, 160, tr("1 tasse"), s: 0.1, sf: 0.1, na: 1),
            f("brownrice", tr("Riz brun cuit"), 123, 2.7, 26, 1, 1.6, 160, tr("1 tasse"), s: 0.3, sf: 0.3, na: 4),
            f("pasta", tr("Pâtes cuites"), 158, 5.8, 31, 0.9, 1.8, 140, tr("1 tasse"), s: 0.6, sf: 0.2, na: 1),
            f("wholepasta", tr("Pâtes de blé entier cuites"), 149, 6, 30, 1.7, 3.9, 140, tr("1 tasse"), s: 0.8, sf: 0.3, na: 4),
            f("ricenoodles", tr("Nouilles de riz cuites"), 108, 1.8, 24, 0.2, 1, 175, tr("1 tasse"), s: 0, sf: 0, na: 19),
            f("quinoa", tr("Quinoa cuit"), 120, 4.4, 21, 1.9, 2.8, 185, tr("1 tasse"), s: 0.9, sf: 0.2, na: 7),
            f("couscous", tr("Couscous cuit"), 112, 3.8, 23, 0.2, 1.4, 160, tr("1 tasse"), s: 0.1, sf: 0, na: 5),
            f("oats", tr("Flocons d'avoine"), 379, 13, 68, 6.5, 10, 40, tr("½ tasse sèche"), s: 1, sf: 1.1, na: 6),
            f("oatmeal", tr("Gruau cuit à l'eau"), 71, 2.5, 12, 1.5, 1.7, 250, tr("1 bol"), s: 0.3, sf: 0.3, na: 4),
            f("bread", tr("Pain blanc"), 265, 9, 49, 3.2, 2.7, 30, tr("1 tranche"), s: 5, sf: 0.7, na: 490),
            f("wholebread", tr("Pain de blé entier"), 247, 13, 41, 3.4, 7, 35, tr("1 tranche"), s: 6, sf: 0.7, na: 450),
            f("baguette", tr("Baguette"), 270, 9, 55, 1.4, 2.4, 50, tr("1 morceau"), s: 2.5, sf: 0.3, na: 600),
            f("bagel", tr("Bagel"), 257, 10, 50, 1.6, 2.3, 100, tr("1 bagel"), s: 5, sf: 0.2, na: 450),
            f("pita", tr("Pain pita"), 275, 9, 56, 1.2, 2.2, 60, tr("1 pita"), s: 1.3, sf: 0.2, na: 536),
            f("englishmuffin", tr("Muffin anglais"), 227, 8, 44, 1.8, 2.7, 57, tr("1 muffin"), s: 3.5, sf: 0.3, na: 420),
            f("tortilla", tr("Tortilla de blé"), 312, 8.3, 52, 8, 3.5, 45, tr("1 tortilla"), s: 3, sf: 3, na: 600),
            f("croissant", tr("Croissant"), 406, 8.2, 46, 21, 2.6, 60, tr("1 croissant"), s: 11, sf: 12, na: 470),
            f("pancake", tr("Crêpe épaisse (pancake)"), 227, 6.4, 28, 9.7, 0.9, 77, tr("1 crêpe"), s: 5, sf: 2.1, na: 439),
            f("waffle", tr("Gaufre"), 291, 7.9, 33, 14, 1.2, 75, tr("1 gaufre"), s: 5, sf: 2.9, na: 511),
            f("cereal", tr("Céréales de maïs"), 357, 7.5, 84, 0.4, 3.3, 30, tr("1 tasse"), s: 10, sf: 0.1, na: 730),
            f("granola", tr("Granola"), 471, 10, 64, 20, 5, 50, tr("½ tasse"), s: 24, sf: 3.5, na: 25),
            f("crackers", tr("Craquelins"), 421, 9.5, 74, 8.6, 3, 20, tr("5 craquelins"), s: 1.3, sf: 2, na: 950),
            f("fries", tr("Frites"), 312, 3.4, 41, 15, 3.8, 120, tr("1 portion moyenne"), s: 0.3, sf: 2.3, na: 210),
        ]),
        (.proteins, [
            f("chicken", tr("Poitrine de poulet cuite"), 165, 31, 0, 3.6, 0, 120, tr("1 portion"), s: 0, sf: 1, na: 74, chol: 85),
            f("chickenthigh", tr("Cuisse de poulet cuite"), 209, 26, 0, 11, 0, 100, tr("1 cuisse"), s: 0, sf: 3, na: 88, chol: 133),
            f("turkey", tr("Poitrine de dinde cuite"), 135, 30, 0, 1.5, 0, 100, tr("1 portion"), s: 0, sf: 0.4, na: 99, chol: 70),
            f("beef", tr("Bœuf haché mi-maigre cuit"), 250, 26, 0, 15, 0, 100, tr("1 portion"), s: 0, sf: 5.9, na: 72, chol: 90),
            f("steak", tr("Steak de surlonge cuit"), 206, 29, 0, 9, 0, 150, tr("1 steak"), s: 0, sf: 3.5, na: 60, chol: 89),
            f("pork", tr("Filet de porc cuit"), 143, 26, 0, 3.5, 0, 120, tr("1 portion"), s: 0, sf: 1.2, na: 57, chol: 73),
            f("ham", tr("Jambon"), 145, 21, 1.5, 6, 0, 30, tr("1 tranche"), s: 1, sf: 2, na: 1_200, chol: 53),
            f("bacon", tr("Bacon cuit"), 541, 37, 1.4, 42, 0, 16, tr("2 tranches"), s: 0, sf: 14, na: 1_700, chol: 110),
            f("sausage", tr("Saucisse de porc cuite"), 325, 18, 1, 27, 0, 75, tr("1 saucisse"), s: 1, sf: 9, na: 810, chol: 80),
            f("hotdogsausage", tr("Saucisse fumée (hot-dog)"), 290, 10, 4, 26, 0, 45, tr("1 saucisse"), s: 1.5, sf: 10, na: 1_000, chol: 50),
            f("salmon", tr("Saumon cuit"), 206, 22, 0, 12, 0, 120, tr("1 filet"), s: 0, sf: 2.5, na: 61, chol: 63),
            f("cod", tr("Morue cuite"), 105, 23, 0, 0.9, 0, 120, tr("1 filet"), s: 0, sf: 0.2, na: 78, chol: 55),
            f("tilapia", tr("Tilapia cuit"), 128, 26, 0, 2.7, 0, 120, tr("1 filet"), s: 0, sf: 0.9, na: 56, chol: 57),
            f("tuna", tr("Thon en conserve (eau)"), 116, 26, 0, 0.8, 0, 85, tr("1 petite boîte"), s: 0, sf: 0.2, na: 250, chol: 42),
            f("sardines", tr("Sardines en conserve"), 208, 25, 0, 11, 0, 90, tr("1 boîte"), s: 0, sf: 1.5, na: 307, chol: 142),
            f("shrimp", tr("Crevettes cuites"), 99, 24, 0.2, 0.3, 0, 85, tr("1 portion"), s: 0, sf: 0.1, na: 111, chol: 189),
            f("egg", tr("Œuf"), 143, 13, 0.7, 9.5, 0, 50, tr("1 gros œuf"), s: 0.4, sf: 3.1, na: 142, chol: 372),
            f("eggwhite", tr("Blanc d'œuf"), 52, 11, 0.7, 0.2, 0, 33, tr("1 blanc"), s: 0.7, sf: 0, na: 166, chol: 0),
            f("tofu", tr("Tofu ferme"), 144, 17, 2.8, 8.7, 2.3, 100, tr("1 portion"), s: 0.6, sf: 1.3, na: 14, chol: 0),
            f("lentils", tr("Lentilles cuites"), 116, 9, 20, 0.4, 7.9, 200, tr("1 tasse"), s: 1.8, sf: 0.1, na: 2, chol: 0),
            f("chickpeas", tr("Pois chiches cuits"), 164, 8.9, 27, 2.6, 7.6, 165, tr("1 tasse"), s: 4.8, sf: 0.3, na: 7, chol: 0),
            f("blackbeans", tr("Haricots noirs cuits"), 132, 8.9, 24, 0.5, 8.7, 170, tr("1 tasse"), s: 0.3, sf: 0.1, na: 1, chol: 0),
            f("kidneybeans", tr("Haricots rouges cuits"), 127, 8.7, 23, 0.5, 6.4, 177, tr("1 tasse"), s: 0.3, sf: 0.1, na: 1, chol: 0),
            f("whey", tr("Protéine en poudre (lactosérum)"), 400, 80, 8, 6, 0, 30, tr("1 mesure"), s: 5, sf: 3, na: 200),
        ]),
        (.dairy, [
            f("milk2", tr("Lait 2 %"), 50, 3.4, 4.8, 2, 0, 250, tr("1 tasse"), s: 5, sf: 1.2, na: 43, chol: 8),
            f("milk325", tr("Lait 3,25 %"), 61, 3.2, 4.8, 3.3, 0, 250, tr("1 tasse"), s: 5, sf: 1.9, na: 43, chol: 10),
            f("milkskim", tr("Lait écrémé"), 34, 3.4, 5, 0.1, 0, 250, tr("1 tasse"), s: 5, sf: 0.1, na: 42, chol: 2),
            f("chocolatemilk", tr("Lait au chocolat"), 83, 3.2, 12, 2.3, 0.6, 250, tr("1 tasse"), s: 11, sf: 1.5, na: 60, chol: 8),
            f("greekyogurt", tr("Yogourt grec nature 0 %"), 59, 10, 3.6, 0.4, 0, 175, tr("¾ tasse"), s: 3.2, sf: 0.1, na: 36, chol: 5),
            f("greekyogurt2", tr("Yogourt grec nature 2 %"), 73, 9.9, 3.9, 2, 0, 175, tr("¾ tasse"), s: 3.5, sf: 1.3, na: 35, chol: 8),
            f("yogurt", tr("Yogourt aux fruits"), 95, 3.5, 16, 1.8, 0, 100, tr("1 pot"), s: 15, sf: 1.1, na: 50, chol: 6),
            f("kefir", tr("Kéfir nature"), 41, 3.8, 4.5, 0.9, 0, 250, tr("1 tasse"), s: 4.6, sf: 0.6, na: 40, chol: 5),
            f("cheddar", tr("Cheddar"), 403, 25, 1.3, 33, 0, 30, tr("1 portion"), s: 0.5, sf: 21, na: 620, chol: 105),
            f("mozzarella", tr("Mozzarella"), 280, 28, 3.1, 17, 0, 30, tr("1 portion"), s: 1, sf: 10, na: 620, chol: 54),
            f("swiss", tr("Fromage suisse"), 380, 27, 5.4, 28, 0, 30, tr("1 portion"), s: 1.3, sf: 18, na: 190, chol: 93),
            f("feta", tr("Feta"), 264, 14, 4.1, 21, 0, 30, tr("1 portion"), s: 4.1, sf: 15, na: 1_116, chol: 89),
            f("parmesan", tr("Parmesan"), 431, 38, 4.1, 29, 0, 10, tr("1 c. à soupe"), s: 0.9, sf: 17, na: 1_529, chol: 88),
            f("cottage", tr("Fromage cottage"), 98, 11, 3.4, 4.3, 0, 125, tr("½ tasse"), s: 2.7, sf: 1.7, na: 364, chol: 17),
            f("creamcheese", tr("Fromage à la crème"), 342, 6, 5.5, 34, 0, 30, tr("2 c. à soupe"), s: 3.8, sf: 20, na: 321, chol: 110),
            f("sourcream", tr("Crème sure"), 198, 2.4, 4.6, 19, 0, 30, tr("2 c. à soupe"), s: 3.4, sf: 10, na: 31, chol: 59),
            f("cream35", tr("Crème 35 %"), 340, 2.8, 2.8, 36, 0, 15, tr("1 c. à soupe"), s: 2.9, sf: 23, na: 38, chol: 113),
            f("butter", tr("Beurre"), 717, 0.9, 0.1, 81, 0, 10, tr("1 c. à thé"), s: 0.1, sf: 51, na: 643, chol: 215),
            f("soymilk", tr("Boisson de soya"), 43, 3.3, 3, 1.8, 0.5, 250, tr("1 tasse"), s: 2.6, sf: 0.2, na: 51, chol: 0),
            f("almondmilk", tr("Boisson d'amande"), 15, 0.6, 0.3, 1.2, 0.2, 250, tr("1 tasse"), s: 0, sf: 0.1, na: 72, chol: 0),
        ]),
        (.fats, [
            f("almonds", tr("Amandes"), 579, 21, 22, 50, 12, 28, tr("1 poignée"), s: 4.4, sf: 3.8, na: 1),
            f("cashews", tr("Noix de cajou"), 553, 18, 30, 44, 3.3, 28, tr("1 poignée"), s: 5.9, sf: 7.8, na: 12),
            f("walnuts", tr("Noix de Grenoble"), 654, 15, 14, 65, 6.7, 28, tr("1 poignée"), s: 2.6, sf: 6.1, na: 2),
            f("peanuts", tr("Arachides grillées"), 585, 24, 21, 50, 8, 28, tr("1 poignée"), s: 4.2, sf: 6.9, na: 6),
            f("pistachios", tr("Pistaches"), 560, 20, 28, 45, 10.6, 28, tr("1 poignée"), s: 7.7, sf: 5.9, na: 1),
            f("sunflowerseeds", tr("Graines de tournesol"), 584, 21, 20, 51, 8.6, 30, tr("¼ tasse"), s: 2.6, sf: 4.5, na: 9),
            f("chia", tr("Graines de chia"), 486, 17, 42, 31, 34, 15, tr("1 c. à soupe"), s: 0, sf: 3.3, na: 16),
            f("flax", tr("Graines de lin moulues"), 534, 18, 29, 42, 27, 10, tr("1 c. à soupe"), s: 1.6, sf: 3.7, na: 30),
            f("peanutbutter", tr("Beurre d'arachide"), 588, 25, 20, 50, 6, 32, tr("2 c. à soupe"), s: 9, sf: 10, na: 430),
            f("almondbutter", tr("Beurre d'amande"), 614, 21, 19, 56, 10, 32, tr("2 c. à soupe"), s: 4.4, sf: 4.2, na: 7),
            f("oliveoil", tr("Huile d'olive"), 884, 0, 0, 100, 0, 14, tr("1 c. à soupe"), s: 0, sf: 14, na: 2),
            f("canolaoil", tr("Huile de canola"), 884, 0, 0, 100, 0, 14, tr("1 c. à soupe"), s: 0, sf: 7.4, na: 0),
            f("hummus", tr("Houmous"), 166, 7.9, 14, 9.6, 6, 30, tr("2 c. à soupe"), s: 0.3, sf: 1.4, na: 379),
            f("guacamole", tr("Guacamole"), 155, 2, 8.5, 14, 5, 30, tr("2 c. à soupe"), s: 1, sf: 2, na: 300),
        ]),
        (.dishes, [
            f("pizza", tr("Pizza fromage"), 266, 11, 33, 10, 2.3, 110, tr("1 pointe"), s: 3.6, sf: 4.5, na: 598),
            f("burger", tr("Hamburger"), 254, 13, 30, 9, 1.5, 200, tr("1 hamburger"), s: 5.8, sf: 3.5, na: 490),
            f("hotdog", tr("Hot-dog (pain et saucisse)"), 247, 10, 20, 14, 0.8, 100, tr("1 hot-dog"), s: 3, sf: 5, na: 700),
            f("poutine", tr("Poutine"), 227, 7, 22, 12, 2, 400, tr("1 portion moyenne"), s: 1, sf: 5, na: 500),
            f("nuggets", tr("Croquettes de poulet"), 296, 15, 16, 20, 0.9, 100, tr("6 croquettes"), s: 0.4, sf: 3.5, na: 540),
            f("sushi", tr("Sushis (maki)"), 150, 5.8, 29, 0.7, 1, 150, tr("6 morceaux"), s: 5, sf: 0.2, na: 420),
            f("poke", tr("Bol poké au saumon"), 150, 8, 19, 4.5, 1.8, 400, tr("1 bol"), s: 3, sf: 0.9, na: 380),
            f("caesar", tr("Salade César"), 190, 4.7, 7.5, 16, 1.5, 150, tr("1 portion"), s: 1.5, sf: 3, na: 430),
            f("soup", tr("Soupe aux légumes"), 30, 1.2, 5, 0.6, 1.2, 250, tr("1 bol"), s: 2, sf: 0.1, na: 330),
            f("pho", tr("Soupe pho au bœuf"), 57, 4, 7, 1.3, 0.4, 700, tr("1 grand bol"), s: 0.8, sf: 0.5, na: 290),
            f("ramen", tr("Ramen (bol)"), 85, 4.5, 10, 3, 0.6, 550, tr("1 bol"), s: 0.7, sf: 1, na: 480),
            f("sandwich", tr("Sandwich jambon-fromage"), 260, 14, 26, 11, 1.7, 150, tr("1 sandwich"), s: 3.5, sf: 5, na: 780),
            f("club", tr("Club sandwich"), 225, 12, 19, 11, 1.5, 250, tr("1 sandwich"), s: 2.6, sf: 3, na: 560),
            f("grilledcheese", tr("Sandwich au fromage fondant"), 330, 12, 28, 19, 1.5, 120, tr("1 sandwich"), s: 4, sf: 9, na: 750),
            f("chickenwrap", tr("Wrap au poulet"), 210, 12, 20, 9, 2, 250, tr("1 wrap"), s: 2, sf: 2.5, na: 520),
            f("falafelwrap", tr("Wrap falafel"), 230, 7, 28, 10, 4, 250, tr("1 wrap"), s: 2.5, sf: 1.5, na: 480),
            f("shawarma", tr("Assiette shawarma au poulet"), 165, 12, 14, 7, 1.8, 400, tr("1 assiette"), s: 1.5, sf: 1.5, na: 420),
            f("spaghetti", tr("Spaghetti sauce à la viande"), 150, 7, 19, 5, 2, 350, tr("1 assiette"), s: 3.2, sf: 1.8, na: 330),
            f("lasagna", tr("Lasagne à la viande"), 165, 10, 16, 7, 1.3, 300, tr("1 portion"), s: 3.4, sf: 3.5, na: 390),
            f("macandcheese", tr("Macaroni au fromage"), 164, 6.5, 21, 6.2, 1.1, 250, tr("1 tasse"), s: 3.2, sf: 2.4, na: 330),
            f("shepherd", tr("Pâté chinois"), 128, 7, 13, 5.5, 1.5, 300, tr("1 portion"), s: 2.5, sf: 2.5, na: 280),
            f("stew", tr("Ragoût de bœuf"), 95, 7.5, 7, 4, 1.3, 300, tr("1 bol"), s: 1.5, sf: 1.7, na: 290),
            f("chili", tr("Chili con carne"), 120, 9, 11, 4.5, 3.5, 250, tr("1 bol"), s: 2.5, sf: 1.7, na: 400),
            f("stirfry", tr("Sauté de poulet et légumes"), 112, 11, 7, 4.5, 1.6, 300, tr("1 portion"), s: 3, sf: 0.9, na: 420),
            f("butterchicken", tr("Poulet au beurre"), 150, 12, 5, 9, 1, 300, tr("1 portion"), s: 3, sf: 4, na: 420),
            f("generaltao", tr("Poulet général Tao"), 260, 13, 24, 12, 1, 250, tr("1 portion"), s: 12, sf: 2, na: 600),
            f("friedrice", tr("Riz frit"), 174, 6, 24, 6, 1.2, 250, tr("1 portion"), s: 1, sf: 1.1, na: 390),
            f("padthai", tr("Pad thaï"), 176, 8, 24, 5.5, 1.5, 350, tr("1 portion"), s: 7, sf: 1, na: 520),
            f("burrito", tr("Burrito"), 206, 9, 27, 7, 3, 250, tr("1 burrito"), s: 1.5, sf: 3, na: 490),
            f("tacos", tr("Tacos au bœuf"), 226, 10, 20, 12, 3, 170, tr("2 tacos"), s: 1.8, sf: 4.5, na: 400),
            f("quesadilla", tr("Quesadilla au fromage"), 290, 12, 28, 14, 2, 180, tr("1 quesadilla"), s: 2, sf: 7, na: 640),
            f("omelette", tr("Omelette nature"), 154, 11, 0.6, 12, 0, 120, tr("2 œufs"), s: 0.4, sf: 3.3, na: 155, chol: 356),
            f("tomatosauce", tr("Sauce tomate"), 32, 1.4, 6.5, 0.3, 1.7, 125, tr("½ tasse"), s: 4.7, sf: 0.1, na: 400),
        ]),
        (.snacks, [
            f("chocolate", tr("Chocolat noir 70 %"), 598, 7.8, 46, 43, 11, 20, tr("2 carrés"), s: 24, sf: 24, na: 20),
            f("milkchocolate", tr("Chocolat au lait"), 535, 7.7, 59, 30, 3.4, 20, tr("2 carrés"), s: 52, sf: 18.5, na: 79),
            f("chips", tr("Croustilles"), 536, 7, 53, 35, 4.4, 30, tr("1 petit sac"), s: 0.3, sf: 3.4, na: 525),
            f("tortillachips", tr("Chips tortilla"), 489, 7, 63, 23, 5, 30, tr("1 poignée"), s: 1, sf: 3, na: 410),
            f("pretzels", tr("Bretzels"), 380, 10, 80, 3, 3, 30, tr("1 poignée"), s: 2.8, sf: 0.6, na: 1_357),
            f("popcorn", tr("Maïs soufflé nature"), 387, 13, 78, 4.5, 15, 25, tr("3 tasses"), s: 0.9, sf: 0.6, na: 8),
            f("ricecake", tr("Galette de riz"), 387, 8, 82, 2.8, 4.2, 9, tr("1 galette"), s: 0.9, sf: 0.6, na: 7),
            f("trailmix", tr("Mélange montagnard"), 462, 14, 45, 29, 5, 40, tr("¼ tasse"), s: 22, sf: 5.6, na: 229),
            f("granolabar", tr("Barre granola"), 471, 7.3, 66, 20, 4, 25, tr("1 barre"), s: 30, sf: 7, na: 290),
            f("proteinbar", tr("Barre protéinée"), 360, 32, 36, 11, 6, 60, tr("1 barre"), s: 6, sf: 5, na: 300),
            f("cookie", tr("Biscuit aux brisures"), 488, 5.4, 64, 24, 2.4, 15, tr("1 biscuit"), s: 36, sf: 11, na: 350),
            f("muffin", tr("Muffin"), 377, 5.2, 55, 15, 1.5, 110, tr("1 muffin"), s: 30, sf: 3, na: 350),
            f("donut", tr("Beigne glacé"), 403, 6.4, 44, 23, 1.2, 60, tr("1 beigne"), s: 22, sf: 5.8, na: 342),
            f("brownie", tr("Brownie"), 466, 6, 64, 23, 2.4, 55, tr("1 carré"), s: 42, sf: 5.8, na: 290),
            f("applepie", tr("Tarte aux pommes"), 237, 1.9, 34, 11, 1.6, 125, tr("1 pointe"), s: 16, sf: 3.8, na: 266),
            f("cheesecake", tr("Gâteau au fromage"), 321, 5.5, 26, 22, 0.4, 110, tr("1 pointe"), s: 22, sf: 9.9, na: 438),
            f("icecream", tr("Crème glacée"), 207, 3.5, 24, 11, 0.7, 70, tr("½ tasse"), s: 21, sf: 6.8, na: 80),
            f("candy", tr("Jujubes"), 343, 6.9, 77, 0, 0, 40, tr("1 petit sac"), s: 47, sf: 0, na: 38),
        ]),
        (.drinks, [
            f("water", tr("Eau pétillante"), 0, 0, 0, 0, 0, 355, tr("1 canette"), s: 0, sf: 0, na: 5),
            f("coffee", tr("Café noir"), 1, 0.1, 0, 0, 0, 250, tr("1 tasse"), s: 0, sf: 0, na: 2),
            f("latte", tr("Café latte"), 54, 3.4, 5.3, 2, 0, 350, tr("1 moyen"), s: 4.9, sf: 1.2, na: 40),
            f("tea", tr("Thé sans sucre"), 1, 0, 0.3, 0, 0, 250, tr("1 tasse"), s: 0, sf: 0, na: 3),
            f("hotchocolate", tr("Chocolat chaud"), 77, 3.5, 11, 2.3, 1, 250, tr("1 tasse"), s: 9.6, sf: 1.4, na: 44),
            f("orangejuice", tr("Jus d'orange"), 45, 0.7, 10, 0.2, 0.2, 250, tr("1 verre"), s: 8.4, sf: 0, na: 1),
            f("applejuice", tr("Jus de pomme"), 46, 0.1, 11, 0.1, 0.2, 250, tr("1 verre"), s: 9.6, sf: 0, na: 4),
            f("smoothie", tr("Smoothie aux fruits"), 60, 1, 14, 0.3, 1.2, 300, tr("1 verre"), s: 11, sf: 0.1, na: 10),
            f("cola", tr("Boisson gazeuse"), 42, 0, 10.6, 0, 0, 355, tr("1 canette"), s: 10.6, sf: 0, na: 4),
            f("dietcola", tr("Boisson gazeuse diète"), 1, 0.1, 0, 0, 0, 355, tr("1 canette"), s: 0, sf: 0, na: 10),
            f("lemonade", tr("Limonade"), 40, 0.1, 10, 0, 0.1, 250, tr("1 verre"), s: 9.5, sf: 0, na: 4),
            f("energydrink", tr("Boisson énergisante"), 45, 0, 11, 0, 0, 250, tr("1 canette"), s: 11, sf: 0, na: 80),
            f("sportsdrink", tr("Boisson pour sportifs"), 26, 0, 6.4, 0, 0, 591, tr("1 bouteille"), s: 5.9, sf: 0, na: 40),
            f("beer", tr("Bière"), 43, 0.5, 3.6, 0, 0, 341, tr("1 bouteille"), s: 0, sf: 0, na: 4),
            f("wine", tr("Vin rouge"), 85, 0.1, 2.6, 0, 0, 150, tr("1 verre"), s: 0.6, sf: 0, na: 4),
            f("spirits", tr("Spiritueux 40 %"), 231, 0, 0, 0, 0, 44, tr("1 once et demie"), s: 0, sf: 0, na: 1),
        ]),
        (.condiments, [
            f("maple", tr("Sirop d'érable"), 260, 0, 67, 0.1, 0, 20, tr("1 c. à soupe"), s: 60, sf: 0, na: 12),
            f("honey", tr("Miel"), 304, 0.3, 82, 0, 0.2, 21, tr("1 c. à soupe"), s: 82, sf: 0, na: 4),
            f("sugar", tr("Sucre blanc"), 387, 0, 100, 0, 0, 4, tr("1 c. à thé"), s: 100, sf: 0, na: 1),
            f("jam", tr("Confiture"), 278, 0.4, 69, 0.1, 1.1, 20, tr("1 c. à soupe"), s: 49, sf: 0, na: 32),
            f("chocospread", tr("Tartinade choco-noisettes"), 539, 6.3, 58, 31, 3.4, 19, tr("1 c. à soupe"), s: 57, sf: 10.6, na: 41),
            f("ketchup", tr("Ketchup"), 101, 1, 27, 0.1, 0.3, 17, tr("1 c. à soupe"), s: 22, sf: 0, na: 907),
            f("mustard", tr("Moutarde"), 60, 3.7, 5.8, 3.3, 4, 5, tr("1 c. à thé"), s: 0.9, sf: 0.2, na: 1_120),
            f("mayo", tr("Mayonnaise"), 680, 1, 0.6, 75, 0, 15, tr("1 c. à soupe"), s: 0.6, sf: 11.7, na: 635),
            f("ranch", tr("Vinaigrette ranch"), 430, 1.3, 6, 44, 0, 30, tr("2 c. à soupe"), s: 4.7, sf: 7, na: 900),
            f("bbq", tr("Sauce BBQ"), 172, 0.8, 41, 0.6, 0.9, 17, tr("1 c. à soupe"), s: 33, sf: 0.1, na: 1_027),
            f("soysauce", tr("Sauce soya"), 53, 8, 4.9, 0.6, 0.8, 16, tr("1 c. à soupe"), s: 0.4, sf: 0.1, na: 5_493),
            f("salsa", tr("Salsa"), 36, 1.5, 7, 0.2, 1.8, 30, tr("2 c. à soupe"), s: 4, sf: 0, na: 711),
        ]),
    ]

    static let all: [FoodItem] = catalog.flatMap { $0.1 }

    private static let categories: [String: FoodCategory] = {
        var map: [String: FoodCategory] = [:]
        for (category, foods) in catalog {
            for food in foods { map[food.id] = category }
        }
        return map
    }()

    /// Other names people type: English, France or Québec words, brands of everyday use.
    private static let aliases: [String: [String]] = [
        "apple": ["apple"], "banana": ["banana"], "strawberries": ["fraise", "strawberry"], "blueberries": ["myrtille", "blueberry"],
        "raspberries": ["framboise", "raspberry"], "watermelon": ["pasteque", "watermelon"], "cantaloupe": ["melon"],
        "clementine": ["mandarine"], "avocado": ["avocado"], "applesauce": ["compote"],
        "potato": ["patate", tr("pomme de terre"), "potato"], "sweetpotato": [tr("patate douce"), tr("sweet potato")], "kale": [tr("chou kale")],
        "pepper": ["poivron", tr("piment doux")], "greenbeans": ["haricots"], "gardensalad": [tr("salade verte")],
        "rice": ["riz", "rice"], "brownrice": [tr("riz complet")], "pasta": ["pates", "spaghetti", "penne", "macaroni", "pasta"],
        "wholepasta": [tr("pates completes")], "oats": ["avoine", "gruau", "porridge"], "oatmeal": ["gruau", "porridge", "avoine"],
        "bread": ["toast", "rotie", "pain"], "wholebread": ["toast", "rotie", tr("pain complet")], "pancake": ["pancake", "crepe"],
        "waffle": ["waffle"], "cereal": [tr("corn flakes"), "cereales"], "fries": ["frites", tr("patates frites")],
        "chicken": ["poulet", "chicken", tr("blanc de poulet")], "chickenthigh": ["poulet"], "turkey": ["dinde", "turkey"],
        "beef": [tr("viande hachee"), tr("steak hache"), tr("ground beef")], "steak": ["boeuf", "beef"], "pork": ["porc"],
        "sausage": ["saucisse"], "hotdogsausage": [tr("hot dog"), "saucisse"], "salmon": ["saumon"], "tuna": ["thon"],
        "shrimp": ["crevette"], "egg": ["oeuf", "oeufs", "egg"], "eggwhite": [tr("blanc d oeuf")], "tofu": ["soja", "soya"],
        "chickpeas": [tr("pois chiche"), "garbanzo"], "lentils": ["lentille"], "kidneybeans": [tr("feves rouges"), "haricots"],
        "blackbeans": [tr("feves noires"), "haricots"], "whey": ["proteine", "protein", "shake", "whey"],
        "milk2": ["lait"], "milk325": [tr("lait entier")], "milkskim": ["lait"], "chocolatemilk": [tr("lait chocolat")],
        "greekyogurt": ["yaourt", "yogurt", "skyr"], "greekyogurt2": ["yaourt", "yogurt"], "yogurt": ["yaourt", "yogurt"],
        "cheddar": ["fromage"], "mozzarella": ["fromage"], "swiss": ["fromage", "emmental"], "feta": ["fromage"],
        "parmesan": ["fromage"], "cottage": ["fromage"], "creamcheese": ["philadelphia", "fromage"], "cream35": ["creme"],
        "soymilk": [tr("lait de soya"), tr("lait de soja")], "almondmilk": [tr("lait d amande")],
        "peanuts": ["cacahuete", "cacahouete"], "peanutbutter": ["arachide", "cacahuete", "peanut"], "cashews": ["cajou"],
        "hummus": ["houmous", "hoummos"], "oliveoil": ["huile"], "canolaoil": ["huile"],
        "pizza": ["pizza"], "burger": ["hamburger", "burger"], "hotdog": [tr("hot dog")], "nuggets": ["nuggets", tr("pepites de poulet")],
        "sushi": ["maki", "sushi"], "poke": ["poke"], "caesar": ["salade"], "soup": ["soupe", "potage"],
        "sandwich": ["sandwich"], "spaghetti": ["bolognaise", "pates"], "lasagna": ["lasagne"], "macandcheese": [tr("kraft dinner"), "mac"],
        "shepherd": [tr("hachis parmentier")], "stirfry": ["saute", "wok"], "friedrice": ["riz"], "tacos": ["taco"],
        "omelette": ["oeufs", "omelet"], "chocolate": ["chocolat"], "milkchocolate": ["chocolat"], "chips": ["chips"],
        "tortillachips": ["nachos"], "popcorn": [tr("pop corn"), tr("mais souffle")], "granolabar": [tr("barre tendre")],
        "proteinbar": [tr("barre proteine")], "cookie": ["cookie", "biscuit"], "donut": ["beigne", "donut", "doughnut"],
        "icecream": ["glace", tr("ice cream")], "candy": ["bonbons", "gummies"], "coffee": ["cafe", "espresso", "expresso", "coffee"],
        "latte": [tr("cafe au lait")], "tea": ["the"], "orangejuice": ["jus"], "applejuice": ["jus"], "cola": ["soda", "coke", "pepsi", "liqueur"],
        "dietcola": ["soda", tr("coke zero"), "liqueur"], "beer": ["biere"], "wine": ["vin"], "spirits": ["vodka", "rhum", "gin", "whisky"],
        "water": ["eau"], "maple": ["erable"], "chocospread": ["nutella"], "mayo": ["mayo"], "ketchup": ["ketchup"], "soysauce": ["soja"],
    ]

    static func category(of food: FoodItem) -> FoodCategory? { categories[food.id] }

    static func foods(in category: FoodCategory) -> [FoodItem] {
        catalog.first { $0.0 == category }?.1 ?? []
    }

    static func item(_ id: String) -> FoodItem? {
        all.first { $0.id == id }
    }

    /// Every word of the query must start a word of the name or of an other name. Names starting with
    /// the query come first, then names containing it, then other names.
    static func search(_ query: String) -> [FoodItem] {
        let q = normalized(query)
        guard !q.isEmpty else { return all }
        let tokens = q.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "'" }).map(String.init)
        func words(_ text: String) -> [String] {
            normalized(text).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        }
        var ranked: [(Int, Int, FoodItem)] = []
        for (index, food) in all.enumerated() {
            let name = normalized(food.name)
            let nameWords = words(food.name)
            let aliasWords = (aliases[String(food.id.dropFirst("builtin.".count))] ?? []).flatMap(words)
            let matchesName = tokens.allSatisfy { token in nameWords.contains { $0.hasPrefix(token) } }
            let matchesAll = tokens.allSatisfy { token in (nameWords + aliasWords).contains { $0.hasPrefix(token) } }
            let rank: Int
            if name.hasPrefix(q) { rank = 0 }
            else if matchesName { rank = 1 }
            else if name.contains(q) { rank = 2 }
            else if matchesAll { rank = 3 }
            else { continue }
            ranked.append((rank, index, food))
        }
        return ranked.sorted { ($0.0, $0.1) < ($1.0, $1.1) }.map { $0.2 }
    }

    static func normalized(_ text: String) -> String {
        text.trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Fmt.locale)
            .replacingOccurrences(of: "œ", with: "oe")
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
        let product_name_en: String?
        let generic_name: String?
        let brands: String?
        let serving_quantity: Flexible?
        let serving_size: String?
        let nutriments: [String: Flexible]?

        var name: String? {
            product_name_fr?.trimmed.nonEmpty ?? product_name?.trimmed.nonEmpty
                ?? product_name_en?.trimmed.nonEmpty ?? generic_name?.trimmed.nonEmpty
        }

        var brand: String? { brands?.split(separator: ",").first.map { String($0).trimmed } }

        func item(barcode: String? = nil) -> FoodItem? {
            guard let name, let nutriments else { return nil }
            func value(_ key: String) -> Double? { nutriments[key]?.value }
            let servingGrams = serving_quantity?.value ?? 0
            /// Per 100 g, or computed from the value per serving when only that one is on the label.
            func per100(_ key: String) -> Double? {
                value("\(key)_100g") ?? (servingGrams > 0 ? value("\(key)_serving").map { $0 / servingGrams * 100 } : nil)
            }
            let protein = per100("proteins"), carbs = per100("carbohydrates"), fat = per100("fat")
            let fromMacros: Double? = protein == nil && carbs == nil && fat == nil
                ? nil : (protein ?? 0) * 4 + (carbs ?? 0) * 4 + (fat ?? 0) * 9
            // Energy in kcal, else in kJ (« energy » is in kJ), else from the macros.
            guard let kcal = per100("energy-kcal") ?? per100("energy-kj").map({ $0 / 4.184 })
                    ?? per100("energy").map({ $0 / 4.184 }) ?? fromMacros else { return nil }
            let code = barcode ?? self.code ?? UUID().uuidString
            let serving = servingGrams > 0 ? servingGrams : 100
            return FoodItem(
                id: "off.\(code)",
                name: name,
                brand: brand,
                kcal: kcal,
                protein: protein ?? 0,
                carbs: carbs ?? 0,
                fat: fat ?? 0,
                fiber: per100("fiber") ?? 0,
                servingGrams: serving,
                servingName: serving_size?.trimmed.nonEmpty ?? "\(Int(safely: serving)) g",
                source: .openFoodFacts,
                barcode: code,
                sugars: per100("sugars"),
                saturatedFat: per100("saturated-fat"),
                // Open Food Facts gives sodium and cholesterol in grams.
                sodiumMg: per100("sodium").map { $0 * 1_000 } ?? per100("salt").map { $0 * 400 },
                cholesterolMg: per100("cholesterol").map { $0 * 1_000 }
            )
        }
    }

    static let fields = "code,product_name,product_name_fr,product_name_en,generic_name,brands,serving_quantity,serving_size,nutriments"

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

    /// What a scanned barcode gives.
    enum BarcodeResult {
        /// A food ready to log.
        case food(FoodItem)
        /// A product known without its nutrition: its name, brand and barcode prefill a custom food.
        case partial(FoodItem)
        case unknown
    }

    /// Looks a barcode up under each of its forms (a UPC-A is also filed as an EAN-13 with a leading 0,
    /// a UPC-E is the short form of a UPC-A). Throws when Open Food Facts can't be reached.
    static func lookup(barcode: String) async throws -> BarcodeResult {
        struct Envelope: Decodable {
            let product: Product?
        }
        var partial: FoodItem?
        for code in barcodeForms(barcode) {
            guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(code).json?fields=\(fields)") else { continue }
            let (data, response) = try await URLSession.shared.data(for: request(url))
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 404 { continue }
            guard status == 200 else { throw WeatherError.badResponse }
            guard let product = (try? JSONDecoder().decode(Envelope.self, from: data))?.product else { continue }
            if let food = product.item(barcode: barcode) { return .food(food) }
            if partial == nil, let name = product.name {
                partial = FoodItem(id: "off.\(barcode)", name: name, brand: product.brand, kcal: 0, protein: 0, carbs: 0, fat: 0, fiber: 0,
                                   servingGrams: 100, servingName: "100 g", source: .custom, barcode: barcode)
            }
        }
        return partial.map(BarcodeResult.partial) ?? .unknown
    }

    /// The forms a retail barcode may be filed under in Open Food Facts.
    static func barcodeForms(_ code: String) -> [String] {
        var forms = [code]
        if code.count == 13, code.hasPrefix("0") { forms.append(String(code.dropFirst())) }
        if code.count == 12 { forms.append("0" + code) }
        if code.count == 8, let upcA = upcEToUPCA(code) { forms += [upcA, "0" + upcA] }
        var seen = Set<String>()
        return forms.filter { seen.insert($0).inserted }
    }

    /// Expands an 8-digit UPC-E to the 12-digit UPC-A it stands for.
    static func upcEToUPCA(_ code: String) -> String? {
        let d = code.map(String.init)
        guard d.count == 8, code.allSatisfy(\.isNumber), d[0] == "0" || d[0] == "1" else { return nil }
        let m = Array(d[1...6])
        let body: String
        switch m[5] {
        case "0", "1", "2": body = m[0] + m[1] + m[5] + "0000" + m[2] + m[3] + m[4]
        case "3": body = m[0] + m[1] + m[2] + "00000" + m[3] + m[4]
        case "4": body = m[0] + m[1] + m[2] + m[3] + "00000" + m[4]
        default: body = m[0] + m[1] + m[2] + m[3] + m[4] + "0000" + m[5]
        }
        return d[0] + body + d[7]
    }
}
