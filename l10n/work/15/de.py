from common import write
T = [
# 0
"Lass die Hüften am Boden.",
"Drück dich sanft mit den Händen hoch, um die Brust anzuheben.",
"Atme beim Hochgehen ein und beim Runtergehen aus.",
"Bis du eine angenehme Spannung im Bauch spürst, ohne Rückenschmerzen.",
"Ellbogen leicht gebeugt.",
"Schultern unten, weg von den Ohren.",
"Die Hüften abheben.",
"Das Hohlkreuz erzwingen.",
"Obst", "Gemüse",
# 10
"Stärkehaltiges", "Milchprodukte", "Nüsse und Samen", "Gerichte", "Snacks", "Getränke", "Saucen und Zucker",
"1 mittelgroßer Apfel", "Apfel", "1 Banane",
# 20
"Banane", "1 Orange", "Orange", "1 Clementine", "Clementine", "1 Tasse", "Erdbeeren", "Heidelbeeren", "Himbeeren", "Trauben",
# 30
"1 Birne", "Birne", "1 Pfirsich", "Pfirsich", "1 Pflaume", "Pflaume", "Kirschen", "1 Kiwi", "Kiwi", "Mango",
# 40
"Ananas", "1 Scheibe", "Wassermelone", "Cantaloupe-Melone", "Grapefruit", "½ Grapefruit", "Avocado", "½ Avocado", "1 Schälchen", "Apfelmus ungesüßt",
# 50
"1 kleine Schachtel", "Rosinen", "3 Datteln", "Datteln", "Brokkoli", "1 Karotte", "Karotte", "1 Tomate", "Tomate", "Gurke",
# 60
"½ Gurke", "Kopfsalat", "1 Tasse roh", "Spinat", "Grünkohl (Kale)", "1 Paprika", "Paprika", "1 Zwiebel", "Zwiebel", "Grüne Bohnen",
# 70
"Blumenkohl", "Kohl", "Rosenkohl", "6 Spargelstangen", "Spargel", "1 Stange", "Staudensellerie", "Aubergine", "1 Rote Bete", "Rote Bete",
# 80
"Champignons", "Zucchini", "1 Kolben", "Mais", "Erbsen", "½ Tasse", "Edamame", "1 mittelgroße", "Gekochte Kartoffel", "Gekochte Süßkartoffel",
# 90
"1 Schüssel", "Gartensalat (ohne Dressing)", "Weißer Reis, gekocht", "Brauner Reis, gekocht", "Nudeln, gekocht", "Vollkornnudeln, gekocht", "Reisnudeln, gekocht", "Quinoa, gekocht", "Couscous, gekocht", "Haferflocken",
# 100
"½ Tasse trocken", "Haferbrei mit Wasser gekocht", "Weißbrot", "Vollkornbrot", "1 Stück", "Baguette", "1 Bagel", "Bagel", "1 Pita", "Pitabrot",
# 110
"1 Muffin", "English Muffin", "1 Tortilla", "Weizentortilla", "1 Croissant", "Croissant", "1 Pancake", "Pancake", "1 Waffel", "Waffel",
# 120
"Cornflakes", "Granola", "5 Cracker", "Cracker", "1 mittlere Portion", "Pommes frites", "Hähnchenbrust, gekocht", "1 Keule", "Hähnchenkeule, gekocht", "Putenbrust, gekocht",
# 130
"Rinderhack (halbmager), gekocht", "1 Steak", "Hüftsteak, gekocht", "Schweinefilet, gekocht", "Schinken", "2 Scheiben", "Speck, gebraten", "1 Wurst", "Schweinswurst, gekocht", "Räucherwurst (Hotdog)",
# 140
"1 Filet", "Lachs, gegart", "Kabeljau, gegart", "Tilapia, gegart", "Thunfisch aus der Dose (in Wasser)", "1 Dose", "Sardinen aus der Dose", "Garnelen, gekocht", "1 großes Ei", "Ei",
# 150
"1 Eiweiß", "Eiweiß", "Fester Tofu", "Linsen, gekocht", "Kichererbsen, gekocht", "Schwarze Bohnen, gekocht", "Kidneybohnen, gekocht", "1 Messlöffel", "Proteinpulver (Molke)", "Milch 2 %",
# 160
"Milch 3,25 %", "Magermilch", "Schokomilch", "Griechischer Joghurt natur 0 %", "¾ Tasse", "Griechischer Joghurt natur 2 %", "1 Becher", "Fruchtjoghurt", "Kefir natur", "Cheddar",
# 170
"Mozzarella", "Schweizer Käse", "Feta", "1 EL", "Parmesan", "Hüttenkäse", "2 EL", "Frischkäse", "Saure Sahne", "Sahne 35 %",
# 180
"1 TL", "Butter", "Sojadrink", "Mandeldrink", "1 Handvoll", "Mandeln", "Cashewkerne", "Walnüsse", "Geröstete Erdnüsse", "Pistazien",
# 190
"Sonnenblumenkerne", "¼ Tasse", "Chiasamen", "Geschrotete Leinsamen", "Erdnussbutter", "Mandelmus", "Olivenöl", "Rapsöl", "Hummus", "Guacamole",
# 200
"1 Stück", "Käsepizza", "1 Hamburger", "Hamburger", "1 Hotdog", "Hotdog (Brötchen und Wurst)", "Poutine", "6 Nuggets", "Chicken Nuggets", "6 Stück",
# 210
"Sushi (Maki)", "Lachs-Poke-Bowl", "Caesar Salad", "Gemüsesuppe", "1 große Schüssel", "Pho mit Rindfleisch", "Ramen (Schüssel)", "1 Sandwich", "Schinken-Käse-Sandwich", "Club Sandwich",
# 220
"Käsetoast", "1 Wrap", "Hähnchen-Wrap", "Falafel-Wrap", "1 Teller", "Hähnchen-Shawarma-Teller", "Spaghetti mit Fleischsauce", "Lasagne mit Fleisch", "Makkaroni mit Käse", "Shepherd's Pie",
# 230
"Rindereintopf", "Chili con Carne", "Hähnchen-Gemüse-Pfanne", "Butter Chicken", "General Tso's Chicken", "Gebratener Reis", "Pad Thai", "1 Burrito", "Burrito", "2 Tacos",
# 240
"Rindfleisch-Tacos", "1 Quesadilla", "Käse-Quesadilla", "2 Eier", "Omelett natur", "Tomatensauce", "2 Stückchen", "Zartbitterschokolade 70 %", "Vollmilchschokolade", "1 kleine Tüte",
# 250
"Kartoffelchips", "Tortillachips", "Brezeln", "3 Tassen", "Popcorn natur", "1 Reiswaffel", "Reiswaffel", "Studentenfutter", "1 Riegel", "Müsliriegel",
# 260
"Proteinriegel", "1 Keks", "Keks mit Schokostückchen", "Muffin", "1 Donut", "Donut mit Glasur", "1 Stück", "Brownie", "Apfelkuchen", "Käsekuchen",
# 270
"Eiscreme", "Fruchtgummi", "1 Dose", "Sprudelwasser", "Schwarzer Kaffee", "1 mittlerer", "Latte", "Tee ohne Zucker", "Heiße Schokolade", "1 Glas",
# 280
"Orangensaft", "Apfelsaft", "Frucht-Smoothie", "Limonade", "Light-Limonade", "Zitronenlimonade", "Energydrink", "1 Flasche", "Sportgetränk", "Bier",
# 290
"Rotwein", "1,5 oz", "Spirituosen 40 %", "Ahornsirup", "Honig", "Weißer Zucker", "Marmelade", "Nuss-Nougat-Creme", "Ketchup", "Senf",
# 300
"Mayonnaise", "Ranch-Dressing", "BBQ-Sauce", "Sojasauce", "Salsa",
# 305 aliases
"grunkohl", "susskartoffel", "kartoffel", "batate", "paprika", "gruner salat", "naturreis", "vollkornnudeln", "vollkornbrot", "cornflakes",
# 315
"pommes", "hahnchenbrust", "hackfleisch", "hacksteak", "faschiertes", "hotdog", "eiweiss", "kidneybohnen", "kichererbse", "schwarze bohnen",
# 325
"schokomilch", "vollmilch", "mandelmilch", "sojamilch", "sojadrink", "chicken nuggets", "kasemakkaroni", "kartoffelauflauf", "muesliriegel", "puffmais",
# 335
"popcorn", "proteinriegel", "eis", "milchkaffee", "cola zero",
# 340
"Québec", "Kanada (bundesweit)", "Frankreich", "USA", "Neujahr", "Karfreitag", "Ostermontag", "Nationaler Patriotentag", "Nationalfeiertag von Québec", "Kanadatag",
# 350
"Tag der Arbeit", "Thanksgiving", "Weihnachten", "Victoria Day", "Civic Holiday", "Tag der Wahrheit und Versöhnung", "Remembrance Day", "2. Weihnachtstag", "Tag des Sieges 1945", "Christi Himmelfahrt",
# 360
"Pfingstmontag", "Nationalfeiertag", "Mariä Himmelfahrt", "Allerheiligen", "Waffenstillstand 1918", "Neujahr", "Martin Luther King Jr. Day", "Presidents' Day", "Memorial Day", "Juneteenth",
# 370
"Unabhängigkeitstag", "Tag der Arbeit", "Columbus Day", "Veterans Day", "Thanksgiving", "Weihnachten", "Zunehmender Mond", "Neumond", "Zunehmende Sichel", "Erstes Viertel",
# 380
"Abnehmende Sichel", "Letztes Viertel", "Abnehmender Mond", "Frühstück", "Mittagessen", "Abendessen", "Snack", "Meine Mahlzeit", "Weiblich", "Männlich",
# 390
"Durchschnitt aus beiden", "Sitzend", "Leicht (1–3 Trainings)", "Mäßig (3–5 Trainings)", "Hoch (6–7 Trainings)", "Langsam abnehmen", "Gewicht halten", "Muskeln aufbauen", "Aktien", "ETF",
# 400
"Finanzen", "Auto", "Design",
"Für Fitness-Widgets auf deinem Niveau und verbrannte Kalorien, geschätzt mit deinem Gewicht.",
"Deine Tagesziele: Die Ernährungs-Widgets zählen, was dir noch bleibt.",
"Dein Budget und deine Ersparnisse, genutzt von den Budget- und Finanzen-Widgets.",
"Deine Aktivität und dein Ziel, verfolgt von den Business-Widgets.",
"Was du erreichen willst, für Widgets, die dich daran erinnern.",
"Dein Studiengang und dein Arbeitsrhythmus.",
"Dein Auto und sein Kilometerstand, um Tankstopps und Wartung zu verfolgen.",
# 410
"Deine Stadt, für das Wetter in deinen Widgets.",
"Dein Wasserziel und eine erste Gewohnheit zum Verfolgen.",
"Muskelaufbau", "Gewichtsverlust", "Definition", "Leistung", "Gewicht halten", "Kraft", "Ausdauer", "Abnehmen",
# 420
"Nicht-binär", "Keine Angabe", "Das Tessera-Projekt fertigstellen", "Einkäufe", "Bankkarte", "Handy-Ladegerät", "Buchungsbestätigungen", "Medikamente", "Kulturbeutel", "Kleidung",
# 430
"Steckdosenadapter", "Reiseversicherung", "Reisepass", "Gate %@", "Sitz %@", "Ankunft · %@", "Abflug · %@", "%@ · Vorlage", "Widget auswählen",
"Zeigt ein Widget, das du in Tessera erstellt hast, oder eine Vorlage aus dem Katalog.",
# 440
"Widget", "Aufgabe abhaken", "Gewohnheit abschließen", "Ein Glas Wasser hinzufügen", "Gläser", "Focus-Sitzung starten", "Minuten", "Focus-Sitzung beenden", "Sitzung beendet", "%@ Minuten Konzentration. Mach eine Pause.",
# 450
"Satz abschließen", "Lebensmittel", "Zählen", "Priorität abhaken", "Projektaufgabe abhaken", "Karte umdrehen", "Karte bewerten", "Hausaufgabe abhaken", "%@ × %@ kg", "Bereit",
# 460
"Klein", "Mittel", "Groß", "Kombi · %@ Widgets", "Ein kleines Widget zeigt nur ein Widget.", "%@ gibt es nicht in Klein.", "Wähle 1 Widget oder 2 zum Kombinieren.",
"%@ gibt es nicht in Mittel: Füge ein 2. Widget hinzu, um sie zu kombinieren.",
"Um 2 Widgets zu kombinieren, muss jedes in Klein verfügbar sein.",
"Ein mittleres Widget kombiniert höchstens 2 Widgets.",
# 470
"Wähle 1 bis 4 Widgets.",
"%@ gibt es nicht in Groß: Füge weitere Widgets hinzu, bis zu 4.",
"Für 2 Widgets in Groß muss jedes in Mittel verfügbar sein: Füge ein 3. oder 4. Widget hinzu.",
"Bei 3 Widgets muss eines davon in Mittel verfügbar sein.",
"Diese Widgets passen in Groß nicht zusammen.",
"Um 4 Widgets zu kombinieren, muss jedes in Klein verfügbar sein.",
"Ein großes Widget kombiniert höchstens 4 Widgets.",
"Niedrig", "Hoch", "Nie",
# 480
"Jeden Tag", "Werktags", "Jede Woche", "pro Tag", "pro Woche", "alle 2 Wochen", "pro Jahr", "Tage bis", "Tage seit", "Nettosaldo",
# 490
"Urlaub",
]
write('de', T)
