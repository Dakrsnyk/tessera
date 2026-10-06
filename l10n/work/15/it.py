from common import write
T = [
# 0
"Tieni i fianchi a terra.",
"Spingi dolcemente sulle mani per sollevare il petto.",
"Inspira mentre sali, espira mentre scendi.",
"Fino a sentire una piacevole tensione nell'addome, senza dolore alla schiena.",
"Gomiti leggermente flessi.",
"Spalle basse, lontane dalle orecchie.",
"Staccare i fianchi.",
"Forzare l'inarcamento.",
"Frutta", "Verdura",
# 10
"Carboidrati", "Latticini", "Frutta secca e semi", "Piatti", "Snack", "Bevande", "Salse e zuccheri",
"1 mela media", "Mela", "1 banana",
# 20
"Banana", "1 arancia", "Arancia", "1 clementina", "Clementina", "1 tazza", "Fragole", "Mirtilli", "Lamponi", "Uva",
# 30
"1 pera", "Pera", "1 pesca", "Pesca", "1 prugna", "Prugna", "Ciliegie", "1 kiwi", "Kiwi", "Mango",
# 40
"Ananas", "1 fetta", "Anguria", "Melone cantalupo", "Pompelmo", "½ pompelmo", "Avocado", "½ avocado", "1 coppetta", "Composta di mele non zuccherata",
# 50
"1 scatoletta", "Uvetta", "3 datteri", "Datteri", "Broccoli", "1 carota", "Carota", "1 pomodoro", "Pomodoro", "Cetriolo",
# 60
"½ cetriolo", "Lattuga", "1 tazza cruda", "Spinaci", "Cavolo riccio (kale)", "1 peperone", "Peperone", "1 cipolla", "Cipolla", "Fagiolini",
# 70
"Cavolfiore", "Cavolo", "Cavolini di Bruxelles", "6 asparagi", "Asparagi", "1 gambo", "Sedano", "Melanzana", "1 barbabietola", "Barbabietola",
# 80
"Funghi", "Zucchina", "1 pannocchia", "Mais", "Piselli", "½ tazza", "Edamame", "1 media", "Patata cotta", "Patata dolce cotta",
# 90
"1 ciotola", "Insalata mista (senza condimento)", "Riso bianco cotto", "Riso integrale cotto", "Pasta cotta", "Pasta integrale cotta", "Spaghetti di riso cotti", "Quinoa cotta", "Couscous cotto", "Fiocchi d'avena",
# 100
"½ tazza a secco", "Porridge d'avena cotto in acqua", "Pane bianco", "Pane integrale", "1 pezzo", "Baguette", "1 bagel", "Bagel", "1 pita", "Pane pita",
# 110
"1 muffin", "Muffin inglese", "1 tortilla", "Tortilla di grano", "1 croissant", "Croissant", "1 pancake", "Pancake", "1 waffle", "Waffle",
# 120
"Cereali di mais", "Granola", "5 cracker", "Cracker", "1 porzione media", "Patatine fritte", "Petto di pollo cotto", "1 coscia", "Coscia di pollo cotta", "Petto di tacchino cotto",
# 130
"Macinato di manzo semi-magro cotto", "1 bistecca", "Bistecca di controfiletto cotta", "Filetto di maiale cotto", "Prosciutto", "2 fette", "Bacon cotto", "1 salsiccia", "Salsiccia di maiale cotta", "Wurstel affumicato (hot dog)",
# 140
"1 filetto", "Salmone cotto", "Merluzzo cotto", "Tilapia cotta", "Tonno in scatola (al naturale)", "1 scatola", "Sardine in scatola", "Gamberi cotti", "1 uovo grande", "Uovo",
# 150
"1 albume", "Albume", "Tofu compatto", "Lenticchie cotte", "Ceci cotti", "Fagioli neri cotti", "Fagioli rossi cotti", "1 misurino", "Proteine in polvere (siero del latte)", "Latte 2%",
# 160
"Latte 3,25%", "Latte scremato", "Latte al cioccolato", "Yogurt greco naturale 0%", "¾ tazza", "Yogurt greco naturale 2%", "1 vasetto", "Yogurt alla frutta", "Kefir naturale", "Cheddar",
# 170
"Mozzarella", "Formaggio svizzero", "Feta", "1 cucchiaio", "Parmigiano", "Fiocchi di latte", "2 cucchiai", "Formaggio spalmabile", "Panna acida", "Panna 35%",
# 180
"1 cucchiaino", "Burro", "Bevanda di soia", "Bevanda di mandorla", "1 manciata", "Mandorle", "Anacardi", "Noci", "Arachidi tostate", "Pistacchi",
# 190
"Semi di girasole", "¼ tazza", "Semi di chia", "Semi di lino macinati", "Burro di arachidi", "Burro di mandorle", "Olio d'oliva", "Olio di canola", "Hummus", "Guacamole",
# 200
"1 trancio", "Pizza ai formaggi", "1 hamburger", "Hamburger", "1 hot dog", "Hot dog (pane e wurstel)", "Poutine", "6 crocchette", "Crocchette di pollo", "6 pezzi",
# 210
"Sushi (maki)", "Poke bowl al salmone", "Insalata Caesar", "Zuppa di verdure", "1 ciotola grande", "Pho di manzo", "Ramen (ciotola)", "1 panino", "Panino prosciutto e formaggio", "Club sandwich",
# 220
"Toast al formaggio fuso", "1 wrap", "Wrap al pollo", "Wrap di falafel", "1 piatto", "Piatto di shawarma di pollo", "Spaghetti al ragù", "Lasagne alla carne", "Maccheroni al formaggio", "Pasticcio di carne e patate",
# 230
"Spezzatino di manzo", "Chili con carne", "Pollo e verdure saltati", "Pollo al burro", "Pollo General Tso", "Riso fritto", "Pad thai", "1 burrito", "Burrito", "2 tacos",
# 240
"Tacos di manzo", "1 quesadilla", "Quesadilla al formaggio", "2 uova", "Omelette semplice", "Salsa di pomodoro", "2 quadretti", "Cioccolato fondente 70%", "Cioccolato al latte", "1 sacchetto piccolo",
# 250
"Patatine", "Tortilla chips", "Pretzel", "3 tazze", "Popcorn semplici", "1 galletta di riso", "Gallette di riso", "Mix di frutta secca", "1 barretta", "Barretta ai cereali",
# 260
"Barretta proteica", "1 biscotto", "Biscotto con gocce di cioccolato", "Muffin", "1 ciambella", "Ciambella glassata", "1 quadrato", "Brownie", "Torta di mele", "Cheesecake",
# 270
"Gelato", "Caramelle gommose", "1 lattina", "Acqua frizzante", "Caffè nero", "1 medio", "Caffellatte", "Tè non zuccherato", "Cioccolata calda", "1 bicchiere",
# 280
"Succo d'arancia", "Succo di mela", "Frullato di frutta", "Bibita gassata", "Bibita gassata dietetica", "Limonata", "Bevanda energetica", "1 bottiglia", "Bevanda per sportivi", "Birra",
# 290
"Vino rosso", "1,5 oz", "Superalcolico 40%", "Sciroppo d'acero", "Miele", "Zucchero bianco", "Marmellata", "Crema alle nocciole e cacao", "Ketchup", "Senape",
# 300
"Maionese", "Salsa ranch", "Salsa BBQ", "Salsa di soia", "Salsa",
# 305 aliases
"cavolo riccio", "patata dolce", "patata", "patata americana", "peperone", "insalata verde", "riso integrale", "pasta integrale", "pane integrale", "corn flakes",
# 315
"patatine fritte", "petto di pollo", "macinato", "hamburger di manzo", "carne macinata", "hot dog", "albume", "fagioli rossi", "ceci", "fagioli neri",
# 325
"latte al cioccolato", "latte intero", "latte di mandorla", "latte di soia", "bevanda di soia", "crocchette di pollo", "maccheroni al formaggio", "pasticcio di patate", "barretta ai cereali", "mais soffiato",
# 335
"popcorn", "barretta proteica", "gelato", "caffellatte", "coca zero",
# 340
"Québec", "Canada (federale)", "Francia", "Stati Uniti", "Capodanno", "Venerdì Santo", "Lunedì dell'Angelo", "Giornata nazionale dei Patrioti", "Festa nazionale del Québec", "Giorno del Canada",
# 350
"Festa del Lavoro", "Giorno del Ringraziamento", "Natale", "Victoria Day", "Festa civica", "Verità e Riconciliazione", "Giorno del Ricordo", "Santo Stefano", "Vittoria 1945", "Ascensione",
# 360
"Lunedì di Pentecoste", "Festa nazionale", "Assunzione", "Ognissanti", "Armistizio 1918", "Capodanno", "Martin Luther King Jr. Day", "Giornata dei Presidenti", "Memorial Day", "Juneteenth",
# 370
"Giorno dell'Indipendenza", "Festa del Lavoro", "Columbus Day", "Giornata dei Veterani", "Giorno del Ringraziamento", "Natale", "Gibbosa crescente", "Luna nuova", "Falce crescente", "Primo quarto",
# 380
"Falce calante", "Ultimo quarto", "Gibbosa calante", "Colazione", "Pranzo", "Cena", "Spuntino", "Il mio pasto", "Donna", "Uomo",
# 390
"Media dei due", "Sedentario", "Leggera (1–3 allenamenti)", "Moderata (3–5 allenamenti)", "Elevata (6–7 allenamenti)", "Perdere peso piano piano", "Mantenere", "Mettere massa", "Azioni", "ETF",
# 400
"Finanza", "Auto", "Design",
"Per widget Fitness adatti al tuo livello e calorie bruciate stimate in base al tuo peso.",
"I tuoi obiettivi del giorno: i widget Nutrizione contano quello che ti resta.",
"Il tuo budget e i tuoi risparmi, usati dai widget Budget e Finanze.",
"La tua attività e il tuo obiettivo, seguiti dai widget Business.",
"Quello che vuoi realizzare, per widget che ti ci riportano.",
"Il tuo programma e il tuo ritmo di lavoro.",
"La tua auto e i suoi chilometri, per seguire i rifornimenti e la manutenzione.",
# 410
"La tua città, per il meteo dei tuoi widget.",
"Il tuo obiettivo d'acqua e una prima abitudine da seguire.",
"Aumento di massa", "Perdita di peso", "Definizione", "Prestazioni", "Mantenimento", "Forza", "Resistenza", "Perdere peso",
# 420
"Non binario", "Preferisco non rispondere", "Finire il progetto Tessera", "Acquisti", "Carta di credito", "Caricabatterie del telefono", "Conferme di prenotazione", "Farmaci", "Beauty case", "Vestiti",
# 430
"Adattatore di corrente", "Assicurazione di viaggio", "Passaporto", "gate %@", "posto %@", "Arrivo · %@", "Partenza · %@", "%@ · modello", "Scegli un widget",
"Mostra un widget che hai creato in Tessera o un modello del catalogo.",
# 440
"Widget", "Spunta un'attività", "Completa un'abitudine", "Aggiungi un bicchiere d'acqua", "Bicchieri", "Avvia una sessione Focus", "Minuti", "Interrompi la sessione Focus", "Sessione terminata", "%@ minuti di concentrazione. Fai una pausa.",
# 450
"Completa la serie", "Alimento", "Conta", "Spunta una priorità", "Spunta un'attività del progetto", "Gira la scheda", "Valuta la scheda", "Spunta un compito", "%@ × %@ kg", "Pronto",
# 460
"Piccolo", "Medio", "Grande", "Combinato · %@ widget", "Un widget piccolo mostra un solo widget.", "%@ non esiste in piccolo.", "Scegli 1 widget, o 2 da unire.",
"%@ non esiste in medio: aggiungi un 2º widget per unirli.",
"Per unire 2 widget, ognuno deve esistere in piccolo.",
"Un widget medio unisce al massimo 2 widget.",
# 470
"Scegli da 1 a 4 widget.",
"%@ non esiste in grande: aggiungi altri widget, fino a 4.",
"Per 2 widget in grande, ognuno deve esistere in medio: aggiungi un 3º o un 4º widget.",
"Per 3 widget, uno di loro deve esistere in medio.",
"Questi widget non stanno insieme in grande.",
"Per unire 4 widget, ognuno deve esistere in piccolo.",
"Un widget grande unisce al massimo 4 widget.",
"Bassa", "Alta", "Mai",
# 480
"Ogni giorno", "Nei giorni feriali", "Ogni settimana", "al giorno", "a settimana", "ogni 2 settimane", "all'anno", "Giorni mancanti", "Giorni trascorsi", "Saldo netto",
# 490
"Vacanze",
]
write('it', T)
