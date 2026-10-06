from common import write
V = [
# 0
"Done", "Planned", "%@ of the day gone", "task", "tasks", "Next: %@", "Nothing urgent, enjoy", "25 min", "Tonight", "task done",
# 10
"tasks done", "Your day in review", "Nothing planned early tomorrow", "Good night", "Take an umbrella (%@%% chance of rain)", "Have a good day", "workouts this week · streak %@", "Next", "left this month · %@/day", "No classes scheduled",
# 20
"Study this week", "Calculated from your data, on your iPhone", "Create your first workout in the Fitness space in Tessera.", "Add your weight in “My info” to estimate your calories burned.", "In progress · %@/%@ sets", "Workout done today", "%@ · %@ sets", "%@ · %@ sets", "%@ · set %@/%@", "Rest until %@",
# 30
"Tap to start “%@”", "your workout", "Complete a set to start resting", "Rest: ready", "lifted this week", "Last week: %@ kg (%@)", "%@ kg this week", "Your records will show up after your first workout.", "%@ · %@ reps", "Est. 1RM: %@ kg",
# 40
"%@: %@ kg", "Set a goal in Tessera", "%@ this week", "Streak: %@", "weeks", "%@/%@ workouts · streak %@", "estimated today", "Week: %@ kcal", "Estimate based on workout length and your weight", "%@ kcal burned",
# 50
"%@ workouts · %@", "spent this month", "Set a monthly budget in Tessera", "Spent %@", "over budget", "or %@ per day", "Spent: %@ of %@", "Log your expenses in the Budget space in Tessera.", "%@ · %@ categories", "Add your bills in the Budget space in Tessera.",
# 60
"Next 30 days: %@", "Create a savings goal in the Budget space in Tessera.", "%@ per month until %@", "Add your accounts and debts in the Budget space in Tessera.", "%@ over 30 days", "assets minus debts", "Assets %@ · Debts %@", "Add your subscriptions in the Budget space in Tessera.", "%@ · %@/yr", "subscription",
# 70
"subscriptions", "Subscriptions %@/mo", "Create your usual expenses (coffee, bus…) in the Budget space in Tessera.", "spent today", "Left this month: %@", "Add your investments in the Investments space in Tessera.", "%@%@ overall", "Today: %@", "Portfolio %@", "in %@ · total %@",
# 80
"Changes show up for investments quoted live.", "%@ over 24 h", "Your position: %@", "Prices show up as soon as a connection is available.", "Prices: CoinGecko", "Market data shows up as soon as a connection is available.", "market cap · %@ over 24 h", "BTC dominance", "ETH dominance", "CoinGecko · %@",
# 90
"Market %@", "Log your first meal in the Nutrition space in Tessera.", "Set your calorie goal in Tessera to see what's left for each meal.", "eaten today", "over goal", "left of %@", "Eaten: %@ kcal", "+%@ kcal", "today · fiber %@ g", "of %@ · fiber %@ g",
# 100
"%@ g of protein today", "to go out of %@ g", "%@ g of protein left", "Nothing logged yet", "food logged", "foods logged", "daily average", "average · goal %@", "Last 30 days: %@ kcal/day", "log a meal to continue",
# 110
"meal logged today", "Streak: %@", "Add favorites in the Nutrition space in Tessera.", "today · tap to add", "for %@", "incl. %@ g of protein", "%@: %@ kcal", "left for the evening", "Pick your three priorities in the Productivity space in Tessera.", "Day won",
# 120
"priorities done", "Priorities %@/%@", "Create a project and its tasks in the Productivity space in Tessera.", "%@ task%@ left%@", "Add a deadline in the Productivity space in Tessera.", "until %@", "Final stretch", "Focus %@ this week", "Create a counter in the Productivity space in Tessera.", "%@ to go",
# 130
"total", "Create a habit in Tessera to track your streak.", "done today", "not done yet today", "Best: %@", "Create your habits in Tessera.", "check-ins this week", "Habits: %@ this week", "of habits kept (%@)", "Habits: %@ this month",
# 140
"Add your classes in the Studies space in Tessera.", "Current class", "In progress · ends at %@", "%@ in progress", "Add your exams in the Studies space in Tessera.", "Add your assignments in the Studies space in Tessera.", "due", "Everything's handed in", "Add your grades in the Studies space in Tessera.", "weighted overall average",
# 150
"Average %@%%", "Enter your term dates in the Studies space in Tessera.", "%@ %@ left", "Ends %@", "Term %@ · %@ d", "Create your flashcards in the Studies space in Tessera.", "All caught up", "No cards to review right now", "Next review %@", "Tap “Answer” to check",
# 160
"card to review", "cards to review", "%@ cards to review", "of %@ this week", "%@ of goal", "Study %@", "Schedule · %@", "yesterday", "in %@ days", "%@ days ago",
# 170
"Today", "%@ d", "now", "in %@ min", "in %@", "E", "N", "NE", "NW", "W",
# 180
"S", "SE", "SW", "low", "moderate", "high", "very high", "extreme", "Last", "Add your birth date in the My Life space in Tessera.",
# 190
"Turning %@ in %@ %@", "Happy birthday!", "%@ of your current year", "until you turn %@", "%@ · %@ of the week", "Week %@ · %@", "No holidays found.", "Holiday", "Next holiday", "illuminated",
# 200
"Full moon %@", "Add your trip in the Travel space in Tessera.", "of %@ · bon voyage!", "%@ · day %@/%@", "time to go!", "From %@ to %@", "Add your flight in the Travel space in Tessera.", "Terminal %@", "Gate %@", "Seat %@",
# 210
"Add your accommodation in the Travel space in Tessera.", "Check-in %@ at %@", "Check-out %@ at %@", "Booking", "Choose the destination city in the Travel space.", "Weather shows up as soon as a connection is available.", "Now on site · forecast for the trip 7 days ahead", "Forecast during your trip", "%@%@ h from here", "same time as here",
# 220
"Your destination uses your currency: nothing to convert.", "Exchange rates show up as soon as a connection is available.", "for %@", "ECB reference rate · %@ · Frankfurter", "last day", "of travel, leaving %@", "Plan your activities in the Travel space in Tessera.", "Choose your city in Tessera to see the weather.", "Sun times arrive with the next weather update.", "Sunrise · %@",
# 230
"Sunset · %@", "Sunrise tomorrow", "Daylight: %@ · %@", "Sunset", "Sunrise", "Rain chances arrive with the next weather update.", "A few showers possible within 12 h", "No rain expected within 12 h", "Precipitation probability · Open-Meteo.com", "wind %@",
# 240
"gusts %@", "UV %@ · %@", "Today's max", "Wind %@ km/h", "Feels like", "UV", "Rain today", "Feels like %@ · ↑%@ ↓%@", "%@%% rain", "Tap to unlock this widget",
# 250
"Entitlements", "no group", "none", "signature: %@ · profile: %@", "Inactive", "Inactive (no group)", "Active (install group)", "Cobalt", "Amber", "Lilac",
# 260
"Olive", "Slate", "Night", "Ink", "Burgundy", "Mist", "White", "Follows light or dark mode", "Always bright", "Always dark",
# 270
"Black, white, nothing else", "Translucent and bright", "A midnight blue to turquoise gradient", "Serif and golden glints", "Elegant", "Digital", "Liquid crystal display", "Warm paper and rounded type", "Futuristic", "Cyan neon on deep night",
# 280
"Big serif numbers", "Type", "Your color, full background", "Modern", "Clean, soft, icon badges", "Card", "Content set on a card", "Round shapes, soft tones", "Compact", "More info, less space",
# 290
"Liquid Glass", "Liquid glass and reflections", "Graphite, silver, thin edge", "Your color in a vivid gradient", "Pink glows on black", "Serif, paper and caps", "Magazine", "One big number, like a front page", "Small cards, everything at a glance", "Dashboard",
# 300
"Bold", "Huge numbers, solid color", "Data", "Grid, mono and curves", "Luxe", "Black and neon yellow, energy", "Navy, clean and aligned", "Your color on black, scan lines", "Architect blue and grid", "Blueprint",
# 310
"Candy colors", "Cream paper and ink", "Thick border, black on white", "Brutalist", "Carbon", "Dark fiber and relief", "Retro-futuristic pink and blue", "Vapor", "Blackboard and chalk", "Pale, light, almost translucent",
# 320
"My widget", "Your latest widget saved in Tessera, no setup needed.", "Set %@/%@",
]
write('en', V)
