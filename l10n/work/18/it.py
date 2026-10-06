from common import write
V = [
# 0
"Fatto", "Previsto", "%@ della giornata trascorso", "attività", "attività", "Poi: %@", "Niente di urgente, goditela", "25 min", "Stasera", "attività completata",
# 10
"attività completate", "Il bilancio della tua giornata", "Niente in programma domani mattina presto", "Buonanotte", "Prendi un ombrello (%@%% di pioggia)", "Buona giornata", "allenamenti questa settimana · serie %@", "Prossimo", "rimasti questo mese · %@/giorno", "Nessun corso in programma",
# 20
"Studio questa settimana", "Calcolato dai tuoi dati, sul tuo iPhone", "Crea il tuo primo allenamento in Tessera, nello spazio Fitness.", "Aggiungi il tuo peso in «Le mie info» per stimare le calorie bruciate.", "In corso · %@/%@ serie", "Allenamento fatto oggi", "%@ · %@ serie", "%@ · %@ serie", "%@ · serie %@/%@", "Recupero fino alle %@",
# 30
"Tocca per iniziare «%@»", "il tuo allenamento", "Completa una serie per avviare il recupero", "Recupero: pronto", "sollevati questa settimana", "Sett. scorsa: %@ kg (%@)", "%@ kg questa settimana", "I tuoi record appariranno dopo il tuo primo allenamento.", "%@ · %@ rip.", "1RM stimato: %@ kg",
# 40
"%@: %@ kg", "Obiettivo da definire in Tessera", "%@ questa settimana", "Serie: %@", "settimane", "%@/%@ allenamenti · serie %@", "stimate oggi", "Settimana: %@ kcal", "Stima in base alla durata degli allenamenti e al tuo peso", "%@ kcal bruciate",
# 50
"%@ allenamenti a %@", "spesi questo mese", "Budget mensile da definire in Tessera", "Speso %@", "oltre il budget", "cioè %@ al giorno", "Speso: %@ su %@", "Annota le tue spese in Tessera, nello spazio Budget.", "%@ · %@ categorie", "Aggiungi le tue fatture in Tessera, nello spazio Budget.",
# 60
"Prossimi 30 giorni: %@", "Crea un obiettivo di risparmio in Tessera, nello spazio Budget.", "%@ al mese fino al %@", "Aggiungi i tuoi conti e i tuoi debiti in Tessera, nello spazio Budget.", "%@ in 30 giorni", "attività meno debiti", "Attività %@ · Debiti %@", "Aggiungi i tuoi abbonamenti in Tessera, nello spazio Budget.", "%@ · %@/anno", "abbonamento",
# 70
"abbonamenti", "Abbonamenti %@/mese", "Crea le tue spese abituali (caffè, bus…) in Tessera, nello spazio Budget.", "speso oggi", "Resto del mese: %@", "Aggiungi i tuoi investimenti in Tessera, nello spazio Investimenti.", "%@%@ in totale", "Oggi: %@", "Portafoglio %@", "in %@ · totale %@",
# 80
"Le variazioni appaiono per gli investimenti quotati in tempo reale.", "%@ in 24 h", "La tua posizione: %@", "Le quotazioni appaiono appena c'è connessione.", "Quotazioni: CoinGecko", "I dati di mercato appaiono appena c'è connessione.", "capitalizzazione · %@ in 24 h", "Dominance BTC", "Dominance ETH", "CoinGecko · %@",
# 90
"Mercato %@", "Annota il tuo primo pasto in Tessera, nello spazio Nutrizione.", "Indica il tuo obiettivo calorico in Tessera per sapere cosa ti resta a ogni pasto.", "mangiate oggi", "oltre l'obiettivo", "rimaste su %@", "Mangiato: %@ kcal", "+%@ kcal", "oggi · fibre %@ g", "su %@ · fibre %@ g",
# 100
"%@ g di proteine oggi", "da assumere su %@ g", "%@ g di proteine rimaste", "Ancora niente di annotato", "alimento annotato", "alimenti annotati", "media al giorno", "media · obiettivo %@", "Ultimi 30 giorni: %@ kcal/g", "annota un pasto per continuare",
# 110
"pasto annotato oggi", "Serie: %@", "Aggiungi dei preferiti in Tessera, nello spazio Nutrizione.", "oggi · tocca per aggiungere", "per %@", "di cui %@ g di proteine", "%@: %@ kcal", "rimaste per la serata", "Scegli le tue tre priorità in Tessera, nello spazio Produttività.", "Giornata vinta",
# 120
"priorità completate", "Priorità %@/%@", "Crea un progetto e le sue attività in Tessera, nello spazio Produttività.", "%@ attività rimast%@%@", "Aggiungi una scadenza in Tessera, nello spazio Produttività.", "prima di %@", "Ultimo sforzo", "Focus %@ questa settimana", "Crea un contatore in Tessera, nello spazio Produttività.", "ancora %@",
# 130
"in totale", "Crea un'abitudine in Tessera per seguire la tua serie.", "fatto oggi", "non ancora fatto oggi", "Record: %@", "Crea le tue abitudini in Tessera.", "conferme questa settimana", "Abitudini: %@ questa settimana", "delle abitudini rispettate (%@)", "Abitudini: %@ questo mese",
# 140
"Aggiungi i tuoi corsi in Tessera, nello spazio Studi.", "Corso attuale", "In corso · fine alle %@", "%@ in corso", "Aggiungi i tuoi esami in Tessera, nello spazio Studi.", "Aggiungi i tuoi compiti da consegnare in Tessera, nello spazio Studi.", "da consegnare", "Tutto consegnato", "Aggiungi i tuoi voti in Tessera, nello spazio Studi.", "media generale ponderata",
# 150
"Media %@%%", "Indica le date della tua sessione in Tessera, nello spazio Studi.", "%@ %@ rimasti", "Fine il %@", "Sessione %@ · %@ g", "Crea le tue schede di ripasso in Tessera, nello spazio Studi.", "Al passo", "Nessuna scheda da ripassare per ora", "Prossimo ripasso %@", "Tocca «Risposta» per verificare",
# 160
"scheda da ripassare", "schede da ripassare", "%@ schede da ripassare", "su %@ questa settimana", "%@ dell'obiettivo", "Studio %@", "Orario · %@", "ieri", "tra %@ giorni", "%@ giorni fa",
# 170
"Oggi", "%@ g", "adesso", "tra %@ min", "tra %@", "E", "N", "NE", "NO", "O",
# 180
"S", "SE", "SO", "basso", "moderato", "alto", "molto alto", "estremo", "Ultimo", "Aggiungi la tua data di nascita in Tessera, nello spazio La mia vita.",
# 190
"%@ anni tra %@ %@", "Buon compleanno!", "%@ del tuo anno in corso", "ai tuoi %@ anni", "%@ · %@ della settimana", "Settimana %@ · %@", "Nessun giorno festivo trovato.", "Giorno festivo", "Prossima festività", "illuminata",
# 200
"Luna piena %@", "Aggiungi il tuo viaggio in Tessera, nello spazio Viaggio.", "su %@ · buon viaggio!", "%@ · giorno %@/%@", "si parte!", "Dal %@ al %@", "Aggiungi il tuo volo in Tessera, nello spazio Viaggio.", "Terminal %@", "Gate %@", "Posto %@",
# 210
"Aggiungi il tuo alloggio in Tessera, nello spazio Viaggio.", "Arrivo %@ alle %@", "Partenza %@ alle %@", "Prenotazione", "Scegli la città di destinazione nello spazio Viaggio.", "Il meteo appare appena c'è connessione.", "Adesso sul posto · previsioni del soggiorno 7 giorni prima", "Previsioni durante il tuo soggiorno", "%@%@ h rispetto a qui", "stessa ora di qui",
# 220
"La tua destinazione usa la tua valuta: niente da convertire.", "I tassi di cambio appaiono appena c'è connessione.", "per %@", "Tasso di riferimento BCE · %@ · Frankfurter", "ultimo giorno", "di viaggio, partenza %@", "Pianifica le tue attività in Tessera, nello spazio Viaggio.", "Scegli la tua città in Tessera per vedere il meteo.", "Gli orari del sole arrivano con il prossimo aggiornamento meteo.", "Alba · %@",
# 230
"Tramonto · %@", "Alba domani", "Durata del giorno: %@ · %@", "Tramonto", "Alba", "Il rischio di pioggia arriva con il prossimo aggiornamento meteo.", "Possibili alcuni rovesci nelle prossime 12 h", "Nessuna pioggia prevista nelle prossime 12 h", "Probabilità di precipitazioni · Open-Meteo.com", "vento %@",
# 240
"raffiche %@", "UV %@ · %@", "Massimo del giorno", "Vento %@ km/h", "Percepita", "UV", "Pioggia oggi", "Percepita %@ · ↑%@ ↓%@", "%@%% di pioggia", "Tocca per sbloccare questo widget",
# 250
"Entitlements", "nessun gruppo", "nessuno", "firma: %@ · profilo: %@", "Inattivo", "Inattivo (nessun gruppo)", "Attivo (gruppo dell'installazione)", "Cobalto", "Ambra", "Lilla",
# 260
"Oliva", "Ardesia", "Notte", "Inchiostro", "Bordeaux", "Foschia", "Bianco", "Segue la modalità chiara o scura", "Sempre luminoso", "Sempre scuro",
# 270
"Nero, bianco, nient'altro", "Traslucido e luminoso", "Una sfumatura dal blu notte al turchese", "Serif e riflessi dorati", "Elegante", "Digitale", "Display a cristalli liquidi", "Carta calda e carattere tondo", "Futuristico", "Neon ciano su notte profonda",
# 280
"Grandi numeri, in serif", "Tipografia", "Il tuo colore a tutto sfondo", "Moderno", "Pulito, morbido, icone a pastiglia", "Scheda", "Il contenuto su una scheda", "Forme tonde, toni morbidi", "Compatto", "Più info, meno spazio",
# 290
"Liquid Glass", "Vetro liquido e riflessi", "Grafite, argento, filetto sottile", "Il tuo colore in sfumatura vivace", "Bagliori rosa su sfondo nero", "Serif, carta e maiuscole", "Magazine", "Un grande numero, come una copertina", "Piccole schede, tutto a colpo d'occhio", "Dashboard",
# 300
"Audace", "Numeri enormi, colore pieno", "Data", "Griglia, mono e curve", "Lusso", "Nero e giallo fluo, energia", "Blu navy, sobrio e allineato", "Il tuo colore su nero, linee dello schermo", "Blu da architetto e griglia", "Planimetria",
# 310
"Colori confetto", "Carta crema e inchiostro", "Bordo spesso, nero su bianco", "Brutalista", "Carbonio", "Fibra scura e rilievo", "Rosa e blu retrofuturista", "Vapor", "Lavagna e gesso", "Pallido, leggero, quasi traslucido",
# 320
"Il mio widget", "L'ultimo widget salvato in Tessera, senza alcuna impostazione.", "Serie %@/%@",
]
write('it', V)
