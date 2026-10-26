import Foundation

/// What an image classifier may call a food (English words, variants) and the foods of the tables to
/// look for, best first. The searches are French (the Québec words first: « croustilles », « patate »,
/// « yogourt »…), because the built-in table and the Canadian Nutrient File are searched in both
/// languages. Pure data and lookups, no Vision, so it can be tested.
enum FoodSynonyms {
    /// A label, cleaned for the lookup: lowercase, separators as spaces, apostrophes and commas dropped
    /// (« Shepherd's_Pie » → « shepherds pie »).
    static func key(for label: String) -> String {
        FoodLabelMatcher.cleaned(label)
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\u{2019}", with: "")
            .replacingOccurrences(of: ",", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
    }

    /// The searches to try, in order, for a label (empty when the label has no synonym). A plural label
    /// (« strawberries », « eggs ») is looked up as is, then without its final « s ».
    static func queries(forLabel label: String) -> [String] {
        let k = key(for: label)
        if let found = table[k] { return found }
        if k.hasSuffix("s"), let found = table[String(k.dropLast())] { return found }
        return []
    }

    /// A search written « id:builtin.muffin » is not a search: it names a food of the built-in table, for
    /// the cases where the search would rank another food first (« muffin » → « muffin anglais »).
    /// Each group: the labels that mean the same food, then the searches (best first).
    private static let groups: [(labels: [String], queries: [String])] = [
        // Dishes
        (["pizza", "pepperoni", "pepperoni pizza", "cheese pizza", "margherita", "margherita pizza", "flatbread pizza"], ["pizza"]),
        (["sandwich", "submarine sandwich", "sub sandwich", "panini", "ham sandwich", "deli sandwich", "blt", "sub"], ["sandwich"]),
        (["grilled cheese", "grilled cheese sandwich", "cheese sandwich"], ["sandwich au fromage fondant"]),
        (["club sandwich", "clubhouse"], ["club sandwich"]),
        (["hamburger", "burger", "cheeseburger", "beef burger", "veggie burger"], ["hamburger"]),
        (["hot dog", "hotdog", "corn dog", "frankfurter", "wiener"], ["hot-dog pain", "saucisse fumee"]),
        (["wrap", "chicken wrap", "tortilla wrap"], ["wrap au poulet"]),
        (["burrito"], ["burrito"]),
        (["taco", "tacos"], ["tacos"]),
        (["quesadilla"], ["quesadilla"]),
        (["nachos"], ["chips tortilla"]),
        (["falafel", "falafel wrap"], ["wrap falafel"]),
        (["shawarma", "gyro", "kebab", "doner"], ["shawarma"]),
        (["poutine"], ["poutine"]),
        (["shepherds pie", "cottage pie", "pate chinois"], ["pate chinois"]),
        (["tourtiere", "meat pie", "pork pie"], ["tourtiere"]),
        (["fries", "french fries", "chips and fries", "potato wedges"], ["frites", "pommes de terre frites"]),
        (["fish and chips", "fish n chips"], ["morue", "frites"]),
        (["chicken nuggets", "nuggets", "chicken tenders", "chicken strips"], ["croquettes de poulet"]),
        (["mac and cheese", "macaroni and cheese", "macaroni", "kraft dinner"], ["macaroni au fromage"]),
        (["spaghetti", "spaghetti bolognese", "spaghetti and meatballs"], ["spaghetti"]),
        (["lasagna", "lasagne"], ["lasagne"]),
        (["pasta", "penne", "fettuccine", "linguine", "rigatoni", "tortellini", "ravioli", "gnocchi", "noodle", "noodles", "carbonara"], ["pates cuites"]),
        (["ramen", "ramen noodles"], ["ramen"]),
        (["pho", "pho soup"], ["soupe pho"]),
        (["pad thai"], ["pad thai"]),
        (["fried rice"], ["riz frit"]),
        (["stir fry", "stir fried", "wok"], ["saute de poulet"]),
        (["chili", "chilli", "chili con carne"], ["chili con carne"]),
        (["stew", "beef stew", "ragout"], ["ragout de boeuf"]),
        (["butter chicken", "curry", "chicken curry", "tikka masala"], ["poulet au beurre"]),
        (["general tao chicken", "general tso chicken", "sweet and sour chicken"], ["poulet general tao"]),
        (["sushi", "sushi roll", "maki", "california roll", "nigiri"], ["sushi"]),
        (["poke", "poke bowl"], ["poke"]),
        (["sashimi"], ["saumon", "thon"]),
        (["soup", "vegetable soup", "chicken soup", "onion soup", "tomato soup", "minestrone", "broth", "potage"], ["soupe aux legumes"]),
        (["pea soup"], ["soupe aux pois", "soupe aux legumes"]),
        (["baked beans"], ["feves au lard", "haricots rouges"]),
        (["omelette", "omelet"], ["omelette"]),
        (["caesar salad", "caesar"], ["salade cesar"]),
        (["salad", "green salad", "garden salad", "side salad", "mixed salad", "chef salad", "greek salad", "coleslaw", "slaw"], ["salade du jardin"]),
        // Meats, fish, eggs
        (["chicken", "grilled chicken", "roast chicken", "chicken breast", "poultry"], ["poitrine de poulet", "poulet cuit"]),
        (["fried chicken", "chicken wings", "chicken wing", "chicken leg", "chicken thigh", "drumstick"], ["cuisse de poulet", "poulet cuit"]),
        (["turkey", "turkey breast"], ["poitrine de dinde"]),
        (["beef", "ground beef", "minced meat", "meatball", "meatballs", "meatloaf", "hamburger patty", "patty"], ["boeuf hache"]),
        (["steak", "beef steak", "sirloin", "roast beef", "ribeye", "brisket"], ["steak de surlonge"]),
        (["pork", "pork chop", "pork loin", "ribs", "spare ribs", "roast pork"], ["filet de porc", "porc"]),
        (["ham", "gammon"], ["jambon"]),
        (["bacon", "bacon strips"], ["bacon"]),
        (["sausage", "sausages", "bratwurst", "chorizo", "salami", "pepperoni sausage"], ["saucisse de porc"]),
        (["salmon", "grilled salmon", "smoked salmon", "lox"], ["saumon"]),
        (["fish", "fish fillet", "white fish", "cod", "haddock", "halibut", "pollock"], ["morue", "tilapia"]),
        (["tilapia"], ["tilapia"]),
        (["tuna", "tuna salad", "tuna steak"], ["thon"]),
        (["sardine", "sardines"], ["sardines"]),
        (["shrimp", "prawn", "prawns", "scampi", "seafood platter"], ["crevettes"]),
        (["egg", "eggs", "fried egg", "fried eggs", "boiled egg", "scrambled eggs", "scrambled egg", "poached egg", "eggs benedict", "sunny side up"], ["oeuf"]),
        (["tofu", "bean curd"], ["tofu"]),
        (["lentil", "lentils", "dal"], ["lentilles"]),
        (["chickpea", "chickpeas", "garbanzo"], ["pois chiches"]),
        (["black beans", "kidney beans", "beans", "bean"], ["haricots noirs", "haricots rouges"]),
        // Vegetables
        (["lettuce", "romaine", "iceberg"], ["laitue"]),
        (["tomato", "tomatoes", "cherry tomato"], ["tomate"]),
        (["cucumber", "pickle", "pickles"], ["concombre"]),
        (["carrot", "carrots", "baby carrots"], ["carotte"]),
        (["broccoli", "broccolini"], ["brocoli"]),
        (["cauliflower"], ["chou-fleur"]),
        (["spinach", "baby spinach"], ["epinards"]),
        (["kale"], ["chou frise"]),
        (["pepper", "bell pepper", "capsicum", "red pepper", "green pepper"], ["poivron"]),
        (["onion", "red onion", "green onion", "scallion"], ["oignon"]),
        (["mushroom", "mushrooms"], ["champignons"]),
        (["corn", "corn on the cob", "sweet corn"], ["mais"]),
        (["peas", "pea", "green peas"], ["petits pois"]),
        (["green beans", "string beans"], ["haricots verts"]),
        (["potato", "potatoes", "baked potato", "mashed potato", "mashed potatoes", "boiled potato", "roast potatoes"], ["pomme de terre", "pommes de terre"]),
        (["sweet potato", "yam"], ["patate douce"]),
        (["zucchini", "courgette"], ["courgette"]),
        (["eggplant", "aubergine"], ["aubergine"]),
        (["cabbage", "red cabbage"], ["id:builtin.cabbage", "chou vert"]),
        (["brussels sprouts", "brussel sprouts"], ["choux de bruxelles"]),
        (["asparagus"], ["asperges"]),
        (["celery"], ["celeri"]),
        (["beet", "beetroot", "beets"], ["betterave"]),
        (["avocado", "avocado toast"], ["avocat"]),
        (["guacamole"], ["guacamole"]),
        (["hummus", "houmous"], ["houmous"]),
        (["edamame"], ["edamame"]),
        // Fruits
        (["apple", "apples", "green apple", "red apple"], ["pomme"]),
        (["banana", "bananas"], ["banane"]),
        (["orange", "oranges", "tangerine", "mandarin", "clementine"], ["orange", "clementine"]),
        (["strawberry", "strawberries"], ["fraises"]),
        (["blueberry", "blueberries", "berries", "berry"], ["bleuets"]),
        (["raspberry", "raspberries", "blackberry", "blackberries"], ["framboises"]),
        (["grape", "grapes"], ["raisins"]),
        (["pear", "pears"], ["poire"]),
        (["peach", "nectarine", "apricot"], ["peche"]),
        (["plum"], ["prune"]),
        (["cherry", "cherries"], ["cerises"]),
        (["kiwi"], ["kiwi"]),
        (["mango"], ["mangue"]),
        (["pineapple"], ["ananas"]),
        (["watermelon"], ["melon d'eau"]),
        (["cantaloupe", "melon", "honeydew"], ["cantaloup"]),
        (["grapefruit"], ["pamplemousse"]),
        (["lemon", "lime"], ["citron"]),
        (["raisin", "raisins", "dried fruit"], ["raisins secs"]),
        (["dates", "date"], ["dattes"]),
        // Bakery, breakfast, snacks
        (["bread", "toast", "slice of bread", "loaf", "white bread", "sourdough", "rye bread"], ["pain blanc"]),
        (["whole wheat bread", "brown bread", "whole grain bread"], ["pain de ble entier"]),
        (["baguette", "french bread"], ["baguette"]),
        (["bagel"], ["bagel"]),
        (["croissant", "pastry", "danish pastry"], ["croissant"]),
        (["pita", "pita bread", "naan", "flatbread"], ["pain pita"]),
        (["english muffin"], ["muffin anglais"]),
        (["muffin", "cupcake"], ["id:builtin.muffin"]),
        (["tortilla"], ["tortilla de ble"]),
        (["pancake", "pancakes", "crepe", "crepes", "hotcake"], ["crepe epaisse"]),
        (["waffle", "waffles"], ["gaufre"]),
        (["french toast"], ["pain blanc"]),
        (["cereal", "corn flakes", "breakfast cereal"], ["cereales de mais"]),
        (["oatmeal", "porridge", "oats", "gruau"], ["gruau"]),
        (["granola", "muesli"], ["granola"]),
        (["donut", "doughnut"], ["beigne"]),
        (["cookie", "cookies", "biscuit", "biscuits"], ["biscuit aux brisures"]),
        (["brownie"], ["brownie"]),
        (["cake", "chocolate cake", "birthday cake", "layer cake", "sponge cake"], ["gateau"]),
        (["cheesecake"], ["gateau au fromage"]),
        (["pie", "apple pie", "fruit pie", "pumpkin pie", "tart"], ["tarte aux pommes"]),
        (["sugar pie"], ["tarte au sucre", "tarte aux pommes"]),
        (["ice cream", "gelato", "frozen yogurt", "sundae", "sorbet"], ["creme glacee"]),
        (["chocolate", "chocolate bar", "candy bar"], ["chocolat au lait", "chocolat noir"]),
        (["candy", "gummy", "gummies", "gummy bears", "lollipop"], ["jujubes"]),
        (["potato chips", "crisps"], ["croustilles"]),
        (["popcorn"], ["mais souffle"]),
        (["pretzel", "pretzels"], ["bretzels"]),
        (["cracker", "crackers"], ["craquelins"]),
        (["almond", "almonds", "nut", "nuts", "mixed nuts"], ["amandes"]),
        (["walnut", "walnuts"], ["noix de grenoble"]),
        (["peanut", "peanuts"], ["arachides"]),
        (["cashew", "cashews"], ["noix de cajou"]),
        (["trail mix"], ["melange montagnard"]),
        // Dairy
        (["milk", "glass of milk"], ["lait"]),
        (["cheese", "cheddar", "cheese slice", "cheese board"], ["cheddar"]),
        (["mozzarella"], ["mozzarella"]),
        (["parmesan"], ["parmesan"]),
        (["feta"], ["feta"]),
        (["cream cheese"], ["fromage a la creme"]),
        (["cottage cheese"], ["fromage cottage"]),
        (["yogurt", "yoghurt", "parfait"], ["yogourt aux fruits", "yogourt grec"]),
        (["greek yogurt"], ["yogourt grec"]),
        (["butter"], ["beurre"]),
        (["peanut butter"], ["beurre d'arachide"]),
        (["cream", "whipped cream", "sour cream"], ["creme sure", "creme 35"]),
        // Drinks
        (["coffee", "espresso", "americano", "black coffee"], ["cafe noir"]),
        (["latte", "cappuccino", "mocha", "flat white", "macchiato"], ["cafe latte"]),
        (["tea", "iced tea", "green tea", "herbal tea"], ["the sans sucre"]),
        (["orange juice", "juice"], ["jus d'orange"]),
        (["apple juice"], ["jus de pomme"]),
        (["smoothie", "milkshake", "shake"], ["smoothie"]),
        (["soda", "cola", "pop", "soft drink", "coke", "pepsi"], ["boisson gazeuse"]),
        (["lemonade"], ["limonade"]),
        (["beer", "lager", "ale", "pint"], ["biere"]),
        (["wine", "red wine", "white wine", "champagne"], ["vin rouge"]),
        (["cocktail", "whiskey", "whisky", "vodka", "rum", "gin", "liquor"], ["spiritueux"]),
        (["hot chocolate", "cocoa"], ["chocolat chaud"]),
        // Condiments
        (["ketchup"], ["ketchup"]),
        (["mustard"], ["moutarde"]),
        (["mayonnaise", "mayo"], ["mayonnaise"]),
        (["maple syrup", "syrup", "pancake syrup"], ["sirop d'erable"]),
        (["honey"], ["miel"]),
        (["jam", "jelly", "marmalade"], ["confiture"]),
        (["salsa"], ["salsa"]),
        (["soy sauce"], ["sauce soya"]),
        (["tomato sauce", "marinara", "pasta sauce"], ["sauce tomate"]),
        (["bbq sauce", "barbecue sauce"], ["sauce bbq"]),
        (["olive oil", "oil"], ["huile d'olive"]),
        (["rice", "white rice", "steamed rice", "basmati", "jasmine rice", "risotto"], ["riz blanc cuit"]),
        (["brown rice", "wild rice"], ["riz brun cuit"]),
        (["quinoa"], ["quinoa"]),
        (["couscous"], ["couscous"]),
    ]

    /// Label (cleaned) → searches. The first group that names a label wins.
    private static let table: [String: [String]] = {
        var map: [String: [String]] = [:]
        for group in groups {
            for label in group.labels {
                let k = key(for: label)
                if map[k] == nil { map[k] = group.queries }
            }
        }
        return map
    }()

    /// Every label that has a synonym (for tests).
    static var knownLabels: [String] { Array(table.keys).sorted() }
}

/// A usual dish and the foods it is made of. Seen on a photo (« sandwich », « pizza », « salad »), it is
/// proposed as editable lines, one per component, with the usual portions: never as a frozen total. An
/// optional component (a sauce, a garnish) is proposed with less confidence, for the person to keep or
/// drop. Everything stays an estimate.
struct DishTemplate: Hashable {
    struct Component: Hashable {
        /// A search in the food tables (`FoodDatabase`, then the Canadian Nutrient File in the app). Several
        /// searches can be given, separated by « | »: the first that finds a food is used.
        let foodQuery: String
        let grams: Double
        let isOptional: Bool

        init(_ foodQuery: String, _ grams: Double, optional: Bool = false) {
            self.foodQuery = foodQuery
            self.grams = grams
            self.isOptional = optional
        }
    }

    let name: String
    /// The labels of the classifier that bring this dish to mind (cleaned with `FoodSynonyms.key`).
    let labels: [String]
    let components: [Component]

    /// The template a label brings to mind, if any.
    static func template(forLabel label: String) -> DishTemplate? {
        index[FoodSynonyms.key(for: label)]
    }

    private static let index: [String: DishTemplate] = {
        var map: [String: DishTemplate] = [:]
        for template in all {
            for label in template.labels {
                let k = FoodSynonyms.key(for: label)
                if map[k] == nil { map[k] = template }
            }
        }
        return map
    }()

    static let all: [DishTemplate] = [
        DishTemplate(name: tr("Sandwich"),
                     labels: ["sandwich", "submarine sandwich", "sub sandwich", "panini", "ham sandwich", "deli sandwich", "blt", "sub"],
                     components: [.init("pain blanc", 60), .init("jambon", 30), .init("cheddar", 20, optional: true),
                                  .init("laitue", 15, optional: true), .init("tomate", 25, optional: true),
                                  .init("mayonnaise", 10, optional: true)]),
        DishTemplate(name: tr("Club sandwich"),
                     labels: ["club sandwich", "clubhouse"],
                     components: [.init("pain blanc", 90), .init("poitrine de dinde", 60), .init("bacon", 16),
                                  .init("laitue", 15, optional: true), .init("tomate", 25, optional: true),
                                  .init("mayonnaise", 12, optional: true)]),
        DishTemplate(name: tr("Pizza"),
                     labels: ["pizza", "pepperoni", "pepperoni pizza", "cheese pizza", "margherita", "margherita pizza"],
                     components: [.init("pizza", 220)]),
        DishTemplate(name: tr("Hamburger"),
                     labels: ["hamburger", "burger", "cheeseburger", "beef burger"],
                     components: [.init("boeuf hache", 100), .init("pain blanc", 60), .init("cheddar", 20, optional: true),
                                  .init("laitue", 15, optional: true), .init("tomate", 25, optional: true),
                                  .init("ketchup", 15, optional: true)]),
        DishTemplate(name: tr("Hot-dog"),
                     labels: ["hot dog", "hotdog", "corn dog", "frankfurter"],
                     components: [.init("pain blanc", 55), .init("saucisse fumee", 45), .init("ketchup", 15, optional: true),
                                  .init("moutarde", 5, optional: true)]),
        DishTemplate(name: tr("Pâtes à la sauce"),
                     labels: ["pasta", "penne", "fettuccine", "linguine", "rigatoni", "tortellini", "ravioli", "carbonara"],
                     components: [.init("pates cuites", 200), .init("sauce tomate", 125), .init("parmesan", 10, optional: true)]),
        DishTemplate(name: tr("Spaghetti"),
                     labels: ["spaghetti", "spaghetti bolognese", "spaghetti and meatballs"],
                     components: [.init("pates cuites", 200), .init("sauce tomate", 125), .init("boeuf hache", 60),
                                  .init("parmesan", 10, optional: true)]),
        DishTemplate(name: tr("Lasagne"),
                     labels: ["lasagna", "lasagne"],
                     components: [.init("lasagne", 300)]),
        DishTemplate(name: tr("Salade composée"),
                     labels: ["salad", "green salad", "garden salad", "side salad", "mixed salad", "chef salad", "greek salad"],
                     components: [.init("salade du jardin", 150), .init("tomate", 40, optional: true),
                                  .init("concombre", 40, optional: true), .init("vinaigrette ranch", 30, optional: true)]),
        DishTemplate(name: tr("Salade César"),
                     labels: ["caesar salad", "caesar"],
                     components: [.init("salade cesar", 200), .init("poitrine de poulet", 80, optional: true)]),
        DishTemplate(name: tr("Bol de riz"),
                     labels: ["rice bowl", "burrito bowl", "bibimbap", "buddha bowl", "grain bowl"],
                     components: [.init("riz blanc cuit", 160), .init("poitrine de poulet", 100),
                                  .init("brocoli", 60, optional: true), .init("carotte", 30, optional: true)]),
        DishTemplate(name: tr("Sushis"),
                     labels: ["sushi", "sushi roll", "maki", "california roll", "nigiri"],
                     components: [.init("sushi", 150)]),
        DishTemplate(name: tr("Poutine"),
                     labels: ["poutine"],
                     components: [.init("poutine", 400)]),
        DishTemplate(name: tr("Déjeuner œufs et bacon"),
                     labels: ["bacon and eggs", "eggs and bacon", "english breakfast", "full breakfast", "american breakfast", "breakfast plate"],
                     components: [.init("oeuf", 100), .init("bacon", 32), .init("pain blanc", 30),
                                  .init("pomme de terre", 100, optional: true)]),
        DishTemplate(name: tr("Crêpes"),
                     labels: ["pancake", "pancakes", "crepe", "crepes", "hotcake"],
                     components: [.init("crepe epaisse", 154), .init("sirop d'erable", 40, optional: true),
                                  .init("beurre", 10, optional: true)]),
        DishTemplate(name: tr("Soupe"),
                     labels: ["soup", "vegetable soup", "chicken soup", "onion soup", "tomato soup", "minestrone"],
                     components: [.init("soupe aux legumes", 250)]),
        DishTemplate(name: tr("Pâté chinois"),
                     labels: ["shepherds pie", "cottage pie", "pate chinois"],
                     components: [.init("pate chinois", 300)]),
        DishTemplate(name: tr("Tourtière"),
                     labels: ["tourtiere", "meat pie", "pork pie"],
                     components: [.init("tourtiere", 180)]),
        DishTemplate(name: tr("Poisson-frites"),
                     labels: ["fish and chips", "fish n chips"],
                     components: [.init("morue", 120), .init("frites", 150), .init("mayonnaise", 15, optional: true)]),
    ]
}
