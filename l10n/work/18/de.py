from common import write
V = [
# 0
"Erledigt", "Geplant", "%@ des Tages vorbei", "Aufgabe", "Aufgaben", "Als Nächstes: %@", "Nichts Dringendes, genieß es", "25 Min.", "Heute Abend", "Aufgabe erledigt",
# 10
"Aufgaben erledigt", "Die Bilanz deines Tages", "Morgen früh ist nichts geplant", "Gute Nacht", "Nimm einen Regenschirm mit (%@ %% Regen)", "Schönen Tag", "Trainings diese Woche · Serie %@", "Nächstes", "übrig diesen Monat · %@/Tag", "Kein Kurs geplant",
# 20
"Lernen diese Woche", "Aus deinen Daten berechnet, auf deinem iPhone", "Erstelle dein erstes Training in Tessera im Bereich Fitness.", "Trag dein Gewicht in „Meine Infos“ ein, um die verbrannten Kalorien zu schätzen.", "Läuft · %@/%@ Sätze", "Training heute erledigt", "%@ · %@ Sätze", "%@ · %@ Sätze", "%@ · Satz %@/%@", "Pause bis %@",
# 30
"Tippe, um „%@“ zu starten", "dein Training", "Schließe einen Satz ab, um die Pause zu starten", "Pause: bereit", "diese Woche gehoben", "Letzte Woche: %@ kg (%@)", "%@ kg diese Woche", "Deine Rekorde erscheinen nach deinem ersten Training.", "%@ · %@ Wdh.", "Geschätztes 1RM: %@ kg",
# 40
"%@: %@ kg", "Ziel in Tessera festlegen", "%@ diese Woche", "Serie: %@", "Wochen", "%@/%@ Trainings · Serie %@", "heute geschätzt", "Woche: %@ kcal", "Schätzung nach Trainingsdauer und deinem Gewicht", "%@ kcal verbrannt",
# 50
"%@ Trainings · %@", "diesen Monat ausgegeben", "Monatsbudget in Tessera festlegen", "Ausgegeben %@", "über dem Budget", "also %@ pro Tag", "Ausgegeben: %@ von %@", "Erfasse deine Ausgaben in Tessera im Bereich Budget.", "%@ · %@ Kategorien", "Füge deine Rechnungen in Tessera im Bereich Budget hinzu.",
# 60
"Nächste 30 Tage: %@", "Lege in Tessera im Bereich Budget ein Sparziel an.", "%@ pro Monat bis zum %@", "Füge deine Konten und Schulden in Tessera im Bereich Budget hinzu.", "%@ in 30 Tagen", "Vermögen minus Schulden", "Vermögen %@ · Schulden %@", "Füge deine Abos in Tessera im Bereich Budget hinzu.", "%@ · %@/Jahr", "Abo",
# 70
"Abos", "Abos %@/Monat", "Lege deine üblichen Ausgaben (Kaffee, Bus …) in Tessera im Bereich Budget an.", "heute ausgegeben", "Rest des Monats: %@", "Füge deine Anlagen in Tessera im Bereich Anlagen hinzu.", "%@%@ insgesamt", "Heute: %@", "Portfolio %@", "in %@ · gesamt %@",
# 80
"Kursänderungen erscheinen bei live notierten Anlagen.", "%@ in 24 h", "Deine Position: %@", "Die Kurse erscheinen, sobald eine Verbindung besteht.", "Kurse: CoinGecko", "Die Marktdaten erscheinen, sobald eine Verbindung besteht.", "Marktkapitalisierung · %@ in 24 h", "BTC-Dominanz", "ETH-Dominanz", "CoinGecko · %@",
# 90
"Markt %@", "Erfasse deine erste Mahlzeit in Tessera im Bereich Ernährung.", "Gib dein Kalorienziel in Tessera an, um zu sehen, was dir pro Mahlzeit bleibt.", "heute gegessen", "über dem Ziel", "übrig von %@", "Gegessen: %@ kcal", "+%@ kcal", "heute · Ballaststoffe %@ g", "von %@ · Ballaststoffe %@ g",
# 100
"%@ g Eiweiß heute", "noch bis %@ g", "%@ g Eiweiß übrig", "Noch nichts erfasst", "Lebensmittel erfasst", "Lebensmittel erfasst", "Durchschnitt pro Tag", "Durchschnitt · Ziel %@", "Letzte 30 Tage: %@ kcal/Tag", "erfasse eine Mahlzeit, um fortzufahren",
# 110
"Mahlzeit heute erfasst", "Serie: %@", "Füge Favoriten in Tessera im Bereich Ernährung hinzu.", "heute · tippen zum Hinzufügen", "für %@", "davon %@ g Eiweiß", "%@: %@ kcal", "übrig für den Abend", "Wähle deine drei Prioritäten in Tessera im Bereich Produktivität.", "Tag gewonnen",
# 120
"Prioritäten erledigt", "Prioritäten %@/%@", "Lege in Tessera im Bereich Produktivität ein Projekt und seine Aufgaben an.", "%@ Aufgabe%@ übrig%@", "Füge in Tessera im Bereich Produktivität eine Fälligkeit hinzu.", "bis %@", "Endspurt", "Fokus %@ diese Woche", "Lege in Tessera im Bereich Produktivität einen Zähler an.", "noch %@",
# 130
"insgesamt", "Lege in Tessera eine Gewohnheit an, um deine Serie zu verfolgen.", "heute erledigt", "heute noch nicht erledigt", "Rekord: %@", "Lege deine Gewohnheiten in Tessera an.", "Abhakungen diese Woche", "Gewohnheiten: %@ diese Woche", "der Gewohnheiten eingehalten (%@)", "Gewohnheiten: %@ diesen Monat",
# 140
"Füge deine Kurse in Tessera im Bereich Studium hinzu.", "Aktueller Kurs", "Läuft · Ende um %@", "%@ läuft", "Füge deine Prüfungen in Tessera im Bereich Studium hinzu.", "Füge deine Abgaben in Tessera im Bereich Studium hinzu.", "abzugeben", "Alles abgegeben", "Füge deine Noten in Tessera im Bereich Studium hinzu.", "gewichteter Gesamtdurchschnitt",
# 150
"Durchschnitt %@ %%", "Gib die Daten deiner Prüfungsphase in Tessera im Bereich Studium an.", "%@ %@ übrig", "Endet am %@", "Phase %@ · %@ T", "Erstelle deine Lernkarten in Tessera im Bereich Studium.", "Auf dem neuesten Stand", "Gerade keine Karten zu wiederholen", "Nächste Wiederholung %@", "Tippe auf „Antwort“, um zu prüfen",
# 160
"Karte zu wiederholen", "Karten zu wiederholen", "%@ Karten zu wiederholen", "von %@ diese Woche", "%@ vom Ziel", "Lernen %@", "Stundenplan · %@", "gestern", "in %@ Tagen", "vor %@ Tagen",
# 170
"Heute", "%@ T", "jetzt", "in %@ Min.", "in %@", "O", "N", "NO", "NW", "W",
# 180
"S", "SO", "SW", "niedrig", "mäßig", "hoch", "sehr hoch", "extrem", "Letzter", "Trage dein Geburtsdatum in Tessera im Bereich Mein Leben ein.",
# 190
"%@ Jahre in %@ %@", "Alles Gute zum Geburtstag!", "%@ deines laufenden Jahres", "bis zu deinem %@. Geburtstag", "%@ · %@ der Woche", "Woche %@ · %@", "Keine Feiertage gefunden.", "Feiertag", "Nächster Feiertag", "beleuchtet",
# 200
"Vollmond %@", "Füge deine Reise in Tessera im Bereich Reisen hinzu.", "von %@ · gute Reise!", "%@ · Tag %@/%@", "es geht los!", "Vom %@ bis %@", "Füge deinen Flug in Tessera im Bereich Reisen hinzu.", "Terminal %@", "Gate %@", "Sitz %@",
# 210
"Füge deine Unterkunft in Tessera im Bereich Reisen hinzu.", "Check-in %@ um %@", "Check-out %@ um %@", "Buchung", "Wähle die Zielstadt im Bereich Reisen.", "Das Wetter erscheint, sobald eine Verbindung besteht.", "Jetzt vor Ort · Vorhersage für die Reise 7 Tage vorher", "Vorhersage während deiner Reise", "%@%@ Std. im Vergleich zu hier", "gleiche Uhrzeit wie hier",
# 220
"Dein Reiseziel nutzt deine Währung: nichts umzurechnen.", "Die Wechselkurse erscheinen, sobald eine Verbindung besteht.", "für %@", "EZB-Referenzkurs · %@ · Frankfurter", "letzter Tag", "Reise, Abreise %@", "Plane deine Aktivitäten in Tessera im Bereich Reisen.", "Wähle deine Stadt in Tessera, um das Wetter zu sehen.", "Die Sonnenzeiten kommen mit dem nächsten Wetter-Update.", "Sonnenaufgang · %@",
# 230
"Sonnenuntergang · %@", "Sonnenaufgang morgen", "Tageslänge: %@ · %@", "Sonnenuntergang", "Sonnenaufgang", "Die Regenwahrscheinlichkeit kommt mit dem nächsten Wetter-Update.", "Vereinzelte Schauer in den nächsten 12 Std. möglich", "Kein Regen in den nächsten 12 Std. erwartet", "Niederschlagswahrscheinlichkeit · Open-Meteo.com", "Wind %@",
# 240
"Böen %@", "UV %@ · %@", "Tageshöchstwert", "Wind %@ km/h", "Gefühlt", "UV", "Regen heute", "Gefühlt %@ · ↑%@ ↓%@", "%@ %% Regen", "Tippe, um dieses Widget freizuschalten",
# 250
"Entitlements", "keine Gruppe", "keine", "Signatur: %@ · Profil: %@", "Inaktiv", "Inaktiv (keine Gruppe)", "Aktiv (Gruppe der Installation)", "Kobalt", "Bernstein", "Flieder",
# 260
"Olive", "Schiefer", "Nacht", "Tinte", "Bordeaux", "Nebel", "Weiß", "Folgt dem hellen oder dunklen Modus", "Immer hell", "Immer dunkel",
# 270
"Schwarz, Weiß, sonst nichts", "Durchscheinend und leuchtend", "Ein Verlauf von Nachtblau zu Türkis", "Serif und goldene Reflexe", "Elegant", "Digital", "Flüssigkristallanzeige", "Warmes Papier und runde Schrift", "Futuristisch", "Cyan-Neon auf tiefer Nacht",
# 280
"Große Zahlen in Serif", "Typo", "Deine Farbe als Vollfläche", "Modern", "Klar, weich, Icon-Plaketten", "Karte", "Der Inhalt auf einer Karte", "Runde Formen, zarte Töne", "Kompakt", "Mehr Infos, weniger Platz",
# 290
"Liquid Glass", "Flüssiges Glas und Reflexe", "Graphit, Silber, feine Kante", "Deine Farbe als lebhafter Verlauf", "Rosa Leuchten auf Schwarz", "Serif, Papier und Versalien", "Magazin", "Eine große Zahl, wie ein Titelblatt", "Kleine Karten, alles auf einen Blick", "Dashboard",
# 300
"Kräftig", "Riesige Zahlen, volle Farbe", "Data", "Raster, Mono und Kurven", "Luxus", "Schwarz und Neongelb, Energie", "Marineblau, nüchtern und bündig", "Deine Farbe auf Schwarz, Bildschirmlinien", "Architektenblau und Raster", "Bauplan",
# 310
"Bonbonfarben", "Cremefarbenes Papier und Tinte", "Dicker Rand, Schwarz auf Weiß", "Brutalistisch", "Carbon", "Dunkle Faser und Relief", "Retro-futuristisches Rosa und Blau", "Vapor", "Schultafel und Kreide", "Blass, leicht, fast durchscheinend",
# 320
"Mein Widget", "Dein zuletzt in Tessera gespeichertes Widget, ganz ohne Einstellungen.", "Satz %@/%@",
]
write('de', V)
