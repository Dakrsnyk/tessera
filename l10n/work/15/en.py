from common import write
T = [
# 0
"Keep your hips on the floor.",
"Gently push through your hands to lift your chest.",
"Breathe in as you rise, out as you lower.",
"Until you feel a comfortable stretch in your abs, with no lower back pain.",
"Elbows slightly bent.",
"Shoulders down, away from your ears.",
"Lifting your hips.",
"Forcing the arch.",
"Fruits", "Vegetables",
# 10
"Starches", "Dairy", "Nuts and seeds", "Dishes", "Snacks", "Drinks", "Sauces and sugars",
"1 medium apple", "Apple", "1 banana",
# 20
"Banana", "1 orange", "Orange", "1 clementine", "Clementine", "1 cup", "Strawberries", "Blueberries", "Raspberries", "Grapes",
# 30
"1 pear", "Pear", "1 peach", "Peach", "1 plum", "Plum", "Cherries", "1 kiwi", "Kiwi", "Mango",
# 40
"Pineapple", "1 slice", "Watermelon", "Cantaloupe", "Grapefruit", "½ grapefruit", "Avocado", "½ avocado", "1 cup", "Unsweetened applesauce",
# 50
"1 small box", "Raisins", "3 dates", "Dates", "Broccoli", "1 carrot", "Carrot", "1 tomato", "Tomato", "Cucumber",
# 60
"½ cucumber", "Lettuce", "1 cup raw", "Spinach", "Kale", "1 bell pepper", "Bell pepper", "1 onion", "Onion", "Green beans",
# 70
"Cauliflower", "Cabbage", "Brussels sprouts", "6 asparagus spears", "Asparagus", "1 stalk", "Celery", "Eggplant", "1 beet", "Beet",
# 80
"Mushrooms", "Zucchini", "1 ear", "Corn", "Peas", "½ cup", "Edamame", "1 medium", "Cooked potato", "Cooked sweet potato",
# 90
"1 bowl", "Garden salad (no dressing)", "Cooked white rice", "Cooked brown rice", "Cooked pasta", "Cooked whole wheat pasta", "Cooked rice noodles", "Cooked quinoa", "Cooked couscous", "Rolled oats",
# 100
"½ cup dry", "Oatmeal made with water", "White bread", "Whole wheat bread", "1 piece", "Baguette", "1 bagel", "Bagel", "1 pita", "Pita bread",
# 110
"1 muffin", "English muffin", "1 tortilla", "Flour tortilla", "1 croissant", "Croissant", "1 pancake", "Pancake", "1 waffle", "Waffle",
# 120
"Corn cereal", "Granola", "5 crackers", "Crackers", "1 medium serving", "French fries", "Cooked chicken breast", "1 thigh", "Cooked chicken thigh", "Cooked turkey breast",
# 130
"Cooked ground beef (medium-lean)", "1 steak", "Cooked sirloin steak", "Cooked pork tenderloin", "Ham", "2 slices", "Cooked bacon", "1 sausage", "Cooked pork sausage", "Smoked sausage (hot dog)",
# 140
"1 fillet", "Cooked salmon", "Cooked cod", "Cooked tilapia", "Canned tuna (in water)", "1 can", "Canned sardines", "Cooked shrimp", "1 large egg", "Egg",
# 150
"1 white", "Egg white", "Firm tofu", "Cooked lentils", "Cooked chickpeas", "Cooked black beans", "Cooked kidney beans", "1 scoop", "Whey protein powder", "2% milk",
# 160
"3.25% milk", "Skim milk", "Chocolate milk", "Plain Greek yogurt 0%", "¾ cup", "Plain Greek yogurt 2%", "1 container", "Fruit yogurt", "Plain kefir", "Cheddar",
# 170
"Mozzarella", "Swiss cheese", "Feta", "1 tbsp", "Parmesan", "Cottage cheese", "2 tbsp", "Cream cheese", "Sour cream", "Heavy cream 35%",
# 180
"1 tsp", "Butter", "Soy milk", "Almond milk", "1 handful", "Almonds", "Cashews", "Walnuts", "Roasted peanuts", "Pistachios",
# 190
"Sunflower seeds", "¼ cup", "Chia seeds", "Ground flaxseed", "Peanut butter", "Almond butter", "Olive oil", "Canola oil", "Hummus", "Guacamole",
# 200
"1 slice", "Cheese pizza", "1 hamburger", "Hamburger", "1 hot dog", "Hot dog (bun and sausage)", "Poutine", "6 nuggets", "Chicken nuggets", "6 pieces",
# 210
"Sushi (maki)", "Salmon poke bowl", "Caesar salad", "Vegetable soup", "1 large bowl", "Beef pho", "Ramen (bowl)", "1 sandwich", "Ham and cheese sandwich", "Club sandwich",
# 220
"Grilled cheese sandwich", "1 wrap", "Chicken wrap", "Falafel wrap", "1 plate", "Chicken shawarma plate", "Spaghetti with meat sauce", "Meat lasagna", "Mac and cheese", "Shepherd's pie",
# 230
"Beef stew", "Chili con carne", "Chicken and vegetable stir-fry", "Butter chicken", "General Tso's chicken", "Fried rice", "Pad thai", "1 burrito", "Burrito", "2 tacos",
# 240
"Beef tacos", "1 quesadilla", "Cheese quesadilla", "2 eggs", "Plain omelet", "Tomato sauce", "2 squares", "70% dark chocolate", "Milk chocolate", "1 small bag",
# 250
"Potato chips", "Tortilla chips", "Pretzels", "3 cups", "Plain popcorn", "1 rice cake", "Rice cake", "Trail mix", "1 bar", "Granola bar",
# 260
"Protein bar", "1 cookie", "Chocolate chip cookie", "Muffin", "1 donut", "Glazed donut", "1 square", "Brownie", "Apple pie", "Cheesecake",
# 270
"Ice cream", "Gummy candies", "1 can", "Sparkling water", "Black coffee", "1 medium", "Latte", "Unsweetened tea", "Hot chocolate", "1 glass",
# 280
"Orange juice", "Apple juice", "Fruit smoothie", "Soda", "Diet soda", "Lemonade", "Energy drink", "1 bottle", "Sports drink", "Beer",
# 290
"Red wine", "1.5 oz", "Spirits 40%", "Maple syrup", "Honey", "White sugar", "Jam", "Chocolate hazelnut spread", "Ketchup", "Mustard",
# 300
"Mayonnaise", "Ranch dressing", "BBQ sauce", "Soy sauce", "Salsa",
# 305 search aliases
"kale", "sweet potato", "potato", "yam", "bell pepper", "green salad", "brown rice", "whole wheat pasta", "whole wheat bread", "cornflakes",
# 315
"french fries", "chicken breast", "hamburger meat", "beef patty", "minced meat", "hotdog", "egg white", "kidney beans", "chickpea", "black beans",
# 325
"chocolate milk", "whole milk", "almond milk", "soy milk", "soya milk", "chicken nuggets", "mac and cheese", "shepherd's pie", "granola bar", "puffed corn",
# 335
"popcorn", "protein bar", "gelato", "latte", "zero cola",
# 340
"Québec", "Canada (federal)", "France", "United States", "New Year's Day", "Good Friday", "Easter Monday", "National Patriots' Day", "Québec National Day", "Canada Day",
# 350
"Labour Day", "Thanksgiving", "Christmas", "Victoria Day", "Civic Holiday", "Truth and Reconciliation Day", "Remembrance Day", "Boxing Day", "Victory Day 1945", "Ascension Day",
# 360
"Whit Monday", "National Day", "Assumption", "All Saints' Day", "Armistice 1918", "New Year's Day", "Martin Luther King Jr. Day", "Presidents' Day", "Memorial Day", "Juneteenth",
# 370
"Independence Day", "Labor Day", "Columbus Day", "Veterans Day", "Thanksgiving", "Christmas Day", "Waxing gibbous", "New moon", "Waxing crescent", "First quarter",
# 380
"Waning crescent", "Last quarter", "Waning gibbous", "Breakfast", "Lunch", "Dinner", "Snack", "My meal", "Female", "Male",
# 390
"Average of both", "Sedentary", "Light (1–3 workouts)", "Moderate (3–5 workouts)", "High (6–7 workouts)", "Lose weight slowly", "Maintain", "Build muscle", "Stocks", "ETF",
# 400
"Finance", "Automotive", "Design",
"For Fitness widgets at your level, and calories burned estimated from your weight.",
"Your goals for the day: Nutrition widgets count what's left.",
"Your budget and savings, used by the Budget and Finances widgets.",
"Your activity and goal, tracked by Business widgets.",
"What you want to accomplish, for widgets that keep you on track.",
"Your program and work rhythm.",
"Your car and its mileage, to track fill-ups and maintenance.",
# 410
"Your city, for the weather in your widgets.",
"Your water goal and a first habit to track.",
"Bulking", "Weight loss", "Cutting", "Performance", "Maintenance", "Strength", "Endurance", "Lose weight",
# 420
"Non-binary", "Prefer not to say", "Finish the Tessera project", "Shopping", "Bank card", "Phone charger", "Booking confirmations", "Medications", "Toiletry bag", "Clothes",
# 430
"Plug adapter", "Travel insurance", "Passport", "gate %@", "seat %@", "Arrival · %@", "Departure · %@", "%@ · template", "Choose a widget",
"Shows a widget you created in Tessera, or a template from the catalog.",
# 440
"Widget", "Check off a task", "Complete a habit", "Add a glass of water", "Glasses", "Start a Focus session", "Minutes", "Stop the Focus session", "Session complete", "%@ minutes of focus. Take a break.",
# 450
"Complete set", "Food", "Count", "Check off a priority", "Check off a project task", "Flip the card", "Rate the card", "Check off an assignment", "%@ × %@ kg", "Ready",
# 460
"Small", "Medium", "Large", "Combo · %@ widgets", "A small widget shows a single widget.", "%@ isn't available in small.", "Choose 1 widget, or 2 to combine.",
"%@ isn't available in medium: add a 2nd widget to combine them.",
"To combine 2 widgets, each must be available in small.",
"A medium widget combines 2 widgets at most.",
# 470
"Choose 1 to 4 widgets.",
"%@ isn't available in large: add more widgets, up to 4.",
"For 2 widgets in large, each must be available in medium: add a 3rd or 4th widget.",
"For 3 widgets, one of them must be available in medium.",
"These widgets don't fit together in large.",
"To combine 4 widgets, each must be available in small.",
"A large widget combines 4 widgets at most.",
"Low", "High", "Never",
# 480
"Every day", "Weekdays", "Every week", "per day", "per week", "every 2 weeks", "per year", "Days until", "Days since", "Net balance",
# 490
"Vacation",
]
write('en', T)
