# Relecture des widgets — rendu du run 625 (2026-11-27)

Cinq relectures (agents) des 210 planches : 95 widgets × petit, moyen, grand × 10 dispositions. Le cadenas des planches est ignoré.

## v2:c9f710c543c2ad97b01bfd91e92bf5ab39bc0e40c0926d3a1d1b682b8e22fc92

type | taille | style (disposition) | problème | gravité
mrr | medium | jeu-lootbox (cards) | "$3,420" garbled (premier chiffre chevauche le $), "subscrib…" coupé, tuile Details vide | forte
mrr | medium | prime-cobalt (horizontal) | courbe sans axe ni repères, seul "3.4k" | moyenne
mrr | medium | pixel-ecran-ambre (data) | courbe sans repère, texte minuscule | moyenne
netWorth | medium | plaque-rivets / luxe-acier-or | ~30 barres sans aucun libellé (jours/valeurs) | forte
netWorth | medium | prime-cobalt, retro-vhs, pixel-ambre | courbe sans repère temporel | moyenne
netWorth/nutritionWeek/revenueTrend/studyHours/weeklyVolume | medium | prime-cobalt (horizontal) | sparkline sans jours ni axe (un seul label "420", "1.1k", "0") | forte
nutritionWeek/studyHours/weeklyVolume/revenueTrend | medium | pixel-ambre (data) & aura-braise (graph) | courbe sans jours (aura-braise: seulement "0→1.1k", "95→0", "3.6k→0") | forte
revenueTrend | medium | riche-gala, retro-vhs, luxe-acier-or, jeu-lootbox, aura-braise | titre/valeurs coupés : "month $12.8…", "$1…", "SALES OVE…", "month $12,84…", "(+17…" | forte
nutritionWeek | medium | retro-vhs, luxe-acier-or | "1,6… kcal/j", "LAST 7 D…" coupés | forte
subscriptions | medium | retro-vhs | "$72.…/mois" coupé; unité "/mois" en français dans un widget anglais (tous styles) | forte
spendingByCategory | medium | luxe-acier-or, pixel-ambre | titre "THIS MONTH'S SPEN…" coupé; ambre "NOVEMBER · 6…" coupé, texte minuscule | moyenne
nutritionStreak | medium | luxe-acier-or | "TRACKIN…" coupé par le bouton Scan | moyenne
nutritionStreak | medium | pixel-ambre | "6 days" chevauche "meal logged today" | moyenne
now | medium | jeu-lootbox | "Friday, November…" coupé | moyenne
myDay | medium | retro-vhs / jeu-lootbox | "Call the mecha… 6 to do" et "Call the mechanic" coupés | moyenne
nextActivity | medium | retro-vhs | nom du lieu sur 3 lignes énormes, déborde presque | moyenne
nextActivity | medium | pixel-ambre | "St. George's…" coupé | moyenne
personalRecords | medium | retro-vhs | "Romanian de…", "Dumbbell r…" coupés | moyenne
portfolio | medium | jeu-lootbox, retro-vhs, pixel-ambre | "iShares Core E…/Equ…" coupés, ambre minuscule | moyenne
quickFood | medium | pixel-ambre | "1,078 kc…" coupé, texte minuscule | moyenne
quickExpense/quickFood | medium | luxe-acier-or | boutons rapides tronqués à 2 sur 3 | moyenne
todaysWorkout | medium | pixel-ambre | libellés "ROMANIAN DEADLI…" coupés, minuscule | moyenne
revenueToday | medium | riche-gala | sous-titre sur 3 lignes, serré | moyenne
restTimer | medium | luxe-acier-or | grande zone vide, trait parasite, bouton retour absent | moyenne
revenueToday | medium | plaque-rivets | moitié de la carte vide (1 ligne "Orders") | moyenne
profit/project/nextExam/revenueGoal/savingsGoal/morning | medium | plaque-rivets (list) | grande zone vide en bas | moyenne
nextActivity/nextClass/nextExam/now/morning/myDay/personalRecords/portfolio/subscriptions/timetable/studentDashboard/revenueToday | medium | vint-sepia-gazette, prime-cobalt, aura-pulse (1 seule ligne ou 0 ligne montrée) | grande place vide alors que des lignes existent (Tram 28, Pastéis, Dentist, Netflix, iCloud…) | forte
proteinLeft/tripCountdown/tripProgress | medium | plaque-rivets (list) | anneau minuscule, "69%/70%/40%" déborde de l'anneau | moyenne
proteinLeft/project/tripCountdown/tripProgress/revenueGoal/savingsGoal/semesterProgress | medium | pixel-ambre (data) | anneau/barre minuscule, texte 6px illisible | moyenne
tasks | medium | (aucun) | RAS | -
semesterProgress | medium | luxe-acier-or | barre sans libellé dans cadre vide | moyenne
trainingStreak | medium | prime-cobalt | pas de points de jours (M T W…) alors que les autres les ont | moyenne
trainingStreak | medium | tous | valeur "4/3" bizarre (objectif 3 dépassé) | moyenne
topMover/portfolio/watchlist/revenueTrend/mrr | medium | jeu-lootbox | chiffres : le "." et la "," ressemblent à des espaces ou disparaissent ("+240%", "US$ 64,210", "$ 1 0,600"), changement de sens possible | forte
progress | medium | riche-gala, plaque-rivets, retro-vhs, ... (graph/data) | 10 cases sans légende (jour/échelle), 90% seul explique | moyenne
yearDots | medium | prime-cobalt | "9…" coupé (91%) | forte
yearDots | medium | riche-gala... tous | grille de points sans explication de ce que représente chaque point (hors "Day 331") | moyenne
worldClock | medium | riche-gala / jeu-lootbox | libellés de villes minuscules, écarts "-5 h" peu lisibles | moyenne
weekView | medium | jeu-lootbox | "November 27 · 61% of the w…" coupé; moitié vide | moyenne
weekView | medium | retro-vhs / luxe-acier-or | sous-titre sur 2 lignes serré | moyenne
workoutMonth | medium | vint-sepia-gazette, plaque-rivets, pixel-ambre, aura-pulse, aura-braise | grille de points minuscule collée en bas, pas de légende des jours, espace vide | moyenne
weeklyVolume | medium | jeu-lootbox | "Last wk: 15,211 kg ( 15%)" signe "−" perdu | moyenne
studyHours/weeklyVolume/nutritionWeek/revenueTrend | medium | aura-braise (graph) | pourcentage "−100%" et "95→0" incohérents, courbe sans jours | forte

PROBLEMES RECURRENTS PAR DISPOSITION
- centered (riche-gala) : sous-titres/lignes à 6-7px, textes sur 3 lignes qui se touchent (revenueToday, revenueTrend "month $12.8…" coupé) ; graphique sans valeur lisible ; texte ligne droite en minuscule.
- horizontal (prime-cobalt) : n'affiche qu'une ou deux lignes alors que la carte est haute (vide récurrent) ; sparkline sans jours ni axe (1 seul label) ; anneaux OK ; yearDots "9…" coupé.
- cards (jeu-lootbox) : tuile "Details" vide ou valeur répétée ; troncatures dans la première tuile ; police des nombres qui mange le "." "," et chevauche le "$"/premier chiffre.
- list (plaque-rivets) : zone vide en bas dès que le widget a moins de 4 lignes ; barres sans libellé (netWorth) ; anneau minuscule qui déborde (proteinLeft, trip*).
- minimal (retro-vhs) / split (luxe-acier-or) : titre et valeur principale tronqués ("$72.…", "1,6…", "SALES OVE…", "TRACKIN…") quand le texte long du sous-titre partage la colonne ; moitié droite vide en acier-or.
- data (pixel-ecran-ambre) : texte 6px illisible, valeurs tronquées, anneaux/barres minuscules ; courbes sans repères.
- progress / graph (aura-pulse / aura-braise) : pulse ne montre qu'une ligne (vide) ; braise : courbes sans jours et plages "a→b" au lieu d'axes, pourcentage "−100%" absurde.

Planches ouvertes : 45 sur 45 (lues via 15 planches-contact c-00..c-14, 3 planches par image).

## v2:8fb267cc099f14c885d46cf4b61e5f08797d79fbf7afa6a6cd801e7054772138

Planches ouvertes : 40/40 (toutes petit). PIL dispo, pas de recadrage nécessaire (402x1191 lisible).

Problèmes (type | taille | style (disposition) | problème | gravité)
aiFinance, aiNutrition, aiProductivity, aiSummary | petit | TOUS les 10 styles | phrase IA tronquée ("$408...", "53% of your goa...") et moitié basse du widget vide ; aiSummary "Team meeting à 10:41" = français mélangé | forte
calendar | petit | riche-gala (centered) | dernière ligne (30) absente/coupée, grille collée au bord bas | forte
flashcard | petit | retro-vhs (minimal) | "All caught up" sur 3 lignes énormes, sous-titre tronqué | forte
flashcard | petit | riche-gala, prime-cobalt | titre sur 2 lignes, sous-titre tronqué (Gala) | moyenne
deadline | petit | riche-gala, jeu-lootbox, retro-vhs | date tronquée ("Sunday, November 29...") ; "2 j 10 h" en français (j au lieu d'ang. d) dans tous les styles | forte (j) / moyenne (troncature)
habitRate | petit | riche-gala, prime-cobalt, retro-vhs, aura-pulse | "of habits kept (novem..." tronqué | moyenne
gradeAverage | petit | riche-gala, prime-cobalt, retro-vhs | "weighted overall aver..." tronqué | moyenne
businessKPIs | petit | plaque/luxe/aura (list, split, progress, graph) | titre "MONTHLY INDICA..." tronqué ; retro-vhs "average basket $80..." tronqué | moyenne
allocation | petit | retro-vhs | "in crypto · total $..." tronqué ; riche-gala texte collé aux bords | moyenne
allocation | petit | gazette, cobalt, steel, pulse | "52%" sans répartition alors que place libre (Crypto/ETF/Stocks existent) | moyenne
assignments | petit | gazette, steel, pulse, cobalt | 1 seule ligne (ou aucune) alors que 3 devoirs et place libre | moyenne
assignments | petit | retro-vhs | "Lab report · in 2 d..." tronqué | moyenne
billsUpcoming | petit | gazette, steel, pulse, cobalt | 1 facture seulement, place vide (Rent, Netflix existent) | moyenne
currency | petit | gazette, steel, pulse, cobalt | 1 ligne ou aucune, place vide (conversions inverses disponibles) | moyenne
flight | petit | riche-gala, retro-vhs | "YUL → LIS · Tue, De..." tronqué ; cobalt wrap OK | moyenne
flight | petit | gazette, steel, pulse | 1 ligne seulement (Arrival, Gate dispo) | moyenne
companyStock | petit | prime-cobalt | "· day" orphelin sur 2e ligne ; retro-vhs tronqué "· day..." | moyenne
companyStock | petit | gazette, steel, pulse, ember, plaque | moitié basse vide, pas de courbe ni market cap | moyenne
companySnapshot | petit | prime-cobalt | "revenue 2025 · EX..." tronqué ; plaque "Net income" sur 2 lignes | moyenne
companyRevenue / companySnapshot / mrr | petit | gazette, plaque, steel, pulse (barres) | barres sans libellé de période (companyRevenue : aucune étiquette ; snapshot/mrr OK) | forte (companyRevenue)
companyRevenue / companySnapshot / mrr / balance / caloriesBurned | petit | prime-cobalt, aura-braise (graph) | courbe sans repère (pas de dates/valeurs/axes) | forte
companyRevenue | petit | jeu-lootbox | "+154%" sans point décimal visible + "(T4 2024)" français ("T4" au lieu de Q4) ; "36.5 GUS$" format étrange | moyenne
mrr | petit | prime-cobalt, retro-vhs, riche-gala | "ARR $41,040 ·..." / "110 su..." tronqué ; Loot "$3420" avec glyphes chevauchés | moyenne
balance | petit | luxe-acier-or (split) | barres sans jours | forte
balance | petit | vint-sepia-gazette, aura-pulse, aura-braise | courbe sans repère | moyenne
balance | petit | pixel-ecran-ambre | "START OF MON..." tronqué ; plaque "−$0" signe incohérent | moyenne
caloriesBurned | petit | aura-braise | courbe sans jours ni repère ; cobalt idem | forte
ageProgress | petit | vint-sepia-gazette | arc sans valeur/label (71% absent), grand vide ; retro-vhs "Turning 29 in 107 d..." tronqué | forte (arc) / moyenne
birthday | petit | vint-sepia-gazette | arc sans valeur | forte
budgetLeft | petit | vint-sepia-gazette, plaque? (non) ; luxe/ember | arc sans valeur (gazette) ; barre de progression sans légende (steel, ember) ; cobalt/pulse 32% non expliqué | forte (gazette) / moyenne
caloriesLeft | petit | vint-sepia-gazette | arc sans valeur | forte
gradeAverage / habitRate | petit | vint-sepia-gazette | arc sans valeur | forte
habits | petit | tous | carrés d'historique sans jours (pas de repère) | moyenne
habitStreak | petit | gazette, plaque, steel, pulse, ember, loot, amber | rangée de coches sans jours | moyenne
holiday | petit | jeu-lootbox, pixel-ecran-ambre | ligne "National Patriots' Day" tronquée "Mo..." / "NATIONAL PAT..." ; "New Year's D..." ; wrap sur 2 lignes (plaque, ember, steel) | moyenne
hotel | petit | riche-gala, retro-vhs, pixel-ecran-ambre | adresse tronquée "Rue de São Miguel 12..." | moyenne
macros | petit | riche-gala, retro-vhs | "of 2,200 · fiber 12 g" tronqué/collé aux bords ; ember n'affiche que 2 de 3 macros (Fat absent) | moyenne
marketOverview | petit | riche-gala, retro-vhs, jeu-lootbox | "market cap · ▲ +1.80..." tronqué ; Loot "24 TUS$" (point manquant) ; "TUS$" unité étrange | moyenne
mealsToday | petit | vint-sepia-gazette, steel, pulse | 1 repas seul, place vide | moyenne
moneyFlow | petit | tous | gros vide au milieu entre solde et lignes du bas ; Loot "+$ 755.70" glyphes décalés | moyenne
moonPhase | petit | retro-vhs | "9... illuminated" valeur tronquée (le chiffre disparaît) | forte
moonPhase | petit | plaque | "New moon" sur 2 lignes | moyenne
Chevauchement ombre/texte | petit | plaque-rivets (list) | unité "years/kcal/days/ /3" mangée par l'ombre portée du grand nombre (ageProgress, caloriesBurned, habitStreak, counter) | moyenne

Problèmes RÉCURRENTS par disposition
- centered (riche-gala) : sous-titre tronqué en "..." (aiX, deadline, flight, gradeAverage, habitRate, mrr, marketOverview, hotel) ; texte collé aux bords ; calendrier sans la ligne du 30 ; titre long wrap 2 lignes (flashcard, hotel). Prévoir lineLimit 2 + minimumScaleFactor et marge latérale.
- vertical (vint-sepia-gazette) : arc sans valeur ni légende (ageProgress, birthday, budgetLeft, caloriesLeft, gradeAverage, habitRate) ; une seule ligne affichée avec grand vide dessous (assignments, bills, currency, flight, mealsToday) ; barres companyRevenue sans libellés.
- horizontal (prime-cobalt) : sous-titre tronqué/wrap avec orphelin ("· day", "EX...", "$41,040 ·...") ; anneau % sans explication (budgetLeft 32%, birthday 71%) ; courbes sans repère ; aucune liste malgré place libre (assignments, bills, currency).
- cards (jeu-lootbox) : lignes et valeurs tronquées ("National Patriots' Day Mo...", "Sunday, November 29 à...") ; glyphes de police décoratifs avec "$"/"." mal rendus (US$18640, +154%, $3420, 24 TUS$, +$ 755.70) ; "T4"/"j" non traduits.
- list (plaque-rivets) : ombre qui écrase l'unité du grand nombre ; libellés qui wrap sur 2 lignes (Net income, New moon, Easter Monday) ; "−$0".
- minimal (retro-vhs) : grand nombre + sous-titre tronqué "..." quasi systématique (VHS = police monospace large) ; flashcard sur 3 lignes ; moonPhase "9...".
- split (luxe-acier-or) : barres sans jours (balance), 1 ligne seulement avec place libre (flight, bills, assignments, mealsToday, currency).
- data (pixel-ecran-ambre) : libellés en capitales tronqués ("START OF MON...", "NATIONAL PAT...", "RUE DE SÃO MIGUEL 12, LISB...").
- progress / graph (aura-pulse, aura-braise) : barres de progression et courbes sans légende/jours ; ember montre souvent 2 lignes sur 3 ; aiX tronqués.
- Transversal : widgets de type ai* (finance, nutrition, productivity, summary) cassés dans les 10 styles (phrase tronquée + vide) ; textes français résiduels en anglais ("j" pour days, "T4", "à 10:41", "à 17:00") ; unités "GUS$/TUS$" bizarres.

## v2:9169b1e4395b7db605a73bcf93bdc37e44c01db9e9f1e80ffc04998ffba1f6de

Tableau (type | taille | style id (disposition) | problème | gravité). Tout en small ; "tronqué" = texte coupé par "…".

netWorth | small | prime-cobalt (horizontal) | "+$1,102 over 30 d…" tronqué | moyenne
netWorth | small | pixel-ecran-ambre (data) | "Debts $10…" tronqué | moyenne
netWorth | small | plaque-rivets/luxe-acier-or (list/split) | barres sans légende ni repère | moyenne
nextActivity | small | pixel-ecran-ambre (data) | "PASTÉIS DE BE…" tronqué, 2 dates serrées | moyenne
nextActivity | small | prime-cobalt (horizontal) / retro-vhs (minimal) / riche-gala (centered) | vide en bas alors que Tram 28 / Pastéis existent | moyenne
nextClass | small | prime-cobalt, retro-vhs, riche-gala | vide, Biology/English non montrés | moyenne
nextExam | small | prime-cobalt, retro-vhs, riche-gala | vide, "Math final exam" non montré | moyenne
now | small | prime-cobalt, retro-vhs, riche-gala | vide, Team meeting / tâches non montrés | moyenne
now | small | pixel-ecran-ambre (data) | tâches absentes malgré la place | moyenne
nutritionWeek | small | aura-braise (graph) | courbe sans jours ni repère | forte
nutritionWeek | small | prime-cobalt (horizontal) | mini-courbe sans jours ni repère | moyenne
nutritionWeek | small | pixel-ecran-ambre (data) | "kcal/d…" tronqué | moyenne
nutritionStreak / trainingStreak / weekView | small | aura-braise (graph) | pastilles sans légende (jours ni texte) | moyenne
personalRecords | small | pixel-ecran-ambre (data) | "ROMANIAN DEA…" tronqué | moyenne
personalRecords / todaysWorkout | small | jeu-lootbox (cards) | ligne 3e minuscule illisible ("3 × 8 · 7…") | moyenne
portfolio | small | retro-vhs (minimal) | "· d…" tronqué | moyenne
portfolio | small | jeu-lootbox (cards) | "iShares Core Equity $3.8…" tronqué | moyenne
portfolio | small | pixel-ecran-ambre (data) | "ISHARES COR…" tronqué | moyenne
portfolio | small | luxe-acier-or, aura-pulse, vint-sepia-gazette | 1 seule ligne affichée, place libre | moyenne
profit | small | vint-sepia-gazette (vertical) | arc sans valeur ni repère ; titre "THIS MONTH'S P…" tronqué | forte
profit | small | aura-braise (graph) | barre seule, sans valeur ni "margin 74%" | forte
profit | small | luxe-acier-or, pixel-ecran-ambre, aura-pulse, aura-braise | titre tronqué | moyenne
project / savingsGoal / proteinLeft / tripCountdown / tripProgress / todaysWorkout / semesterProgress | small | vint-sepia-gazette (vertical) | arc sans pourcentage ni repère | moyenne
project | small | retro-vhs (minimal) | "3 tasks left · in 1…" tronqué | moyenne
todaysWorkout | small | aura-braise (graph) | barre seule, aucun texte ni valeur | forte
todaysWorkout | small | retro-vhs (minimal) | "In progress · 3/10…" tronqué | moyenne
revenueGoal | small | vint-sepia-gazette, luxe-acier-or, aura-pulse, aura-braise | titre "GOAL FOR THE MO…" tronqué | moyenne
revenueGoal | small | plaque-rivets / vint-sepia-gazette / aura-braise | anneau/arc à 107% sans lecture claire (anneau plein, pas de dépassement) | moyenne
revenueToday | small | riche-gala, jeu-lootbox, retro-vhs, pixel-ecran-ambre | "vs $0 last friday, same…" tronqué | moyenne
revenueTrend | small | vint-sepia-gazette, plaque-rivets, luxe-acier-or, aura-pulse (barres) | 30 barres sans repère (ni jours ni échelle) | forte
revenueTrend | small | aura-braise (graph), prime-cobalt (horizontal) | courbe sans repère | forte
revenueTrend | small | riche-gala, jeu-lootbox, retro-vhs, prime-cobalt, pixel-ecran-ambre | "Week $2,720 · month…" tronqué | moyenne
spendingByCategory | small | tous sauf aura-pulse/luxe/gazette | titre "THIS MONTH'S SPEND…" tronqué | moyenne
spendingByCategory | small | retro-vhs | "6 catego…" tronqué | moyenne
spendingByCategory | small | vint-sepia-gazette, luxe-acier-or, aura-pulse | aucune catégorie montrée, place libre | moyenne
spendingByCategory | small | prime-cobalt (horizontal) | vide, pas de lignes | moyenne
studyHours / weeklyVolume | small | aura-braise (graph), prime-cobalt (horizontal) | courbe sans jours ni repère | forte
studyHours / weeklyVolume | small | vint-sepia-gazette, luxe-acier-or, plaque-rivets | jour mis en évidence (F vs S) incohérent entre styles | moyenne
subscriptions | small | riche-gala, retro-vhs | "$87…" / "$…" tronqué | moyenne
subscriptions | small | tous | "/mois" en français dans un texte anglais | moyenne
subscriptions | small | vint-sepia-gazette, luxe-acier-or, aura-pulse | 1 seule ligne, place libre | moyenne
tasks | small | pixel-ecran-ambre (data) | "Call the mechan…" tronqué | moyenne
timetable | small | vint-sepia-gazette, aura-pulse, aura-braise | titre "TODAY'S SCHED…" tronqué | moyenne
timetable | small | prime-cobalt, retro-vhs | pas de lignes malgré 3 cours | moyenne
timetable | small | vint-sepia-gazette, luxe-acier-or, aura-pulse | 1 ligne seulement, place libre | moyenne
topMover | small | jeu-lootbox | "+240%" au lieu de "+2.40%" (point effacé) | forte
watchlist | small | retro-vhs (minimal) | "· 24…" tronqué | moyenne
watchlist | small | vint-sepia-gazette, luxe-acier-or, aura-pulse | 1 ligne (BTC) seulement | moyenne
watchlist | small | jeu-lootbox | "US$64,210" et lignes minuscules, "+240%", "1.20%" (signe/point altérés) | forte
weekView | small | riche-gala, jeu-lootbox, retro-vhs | "61% of…" tronqué | moyenne
weeklyVolume | small | jeu-lootbox (cards) | "Last wk: 15,211 kg ( 15%)" signe moins perdu | moyenne
worldClock | small | jeu-lootbox (cards) | "5 h" (signe − perdu au lieu de "−5 h") | moyenne
yearDots | small | tous | grille coupée/estompée en bas, aucune légende de couleur (passé/futur/aujourd'hui) | moyenne
workoutMonth | small | tous (grilles de points) | points sans jours ni repère, derniers points hors grille | moyenne
workoutMonth | small | prime-cobalt (horizontal) | aucune grille, vide en bas | moyenne
quickFood | small | tous sauf plaque-rivets | deux boutons "+" identiques sans libellé | moyenne

Problèmes récurrents par disposition (moteur) :
- centered (riche-gala) : ligne sous-titre tronquée ("same…", "month…", "61% of…", "$87…") ; les lignes de contenu (cours, examens, tâches) jamais montrées malgré la place. Il faut wrap sur 2 lignes ou réduire la taille.
- vertical (vint-sepia-gazette) : arcs sans valeur ni repère, barres sans repère (revenueTrend) ; une seule ligne montrée alors que de la place reste (watchlist, subscriptions, timetable, spending) ; titre tronqué dès que >18 caractères.
- horizontal (prime-cobalt) : mini-courbe sans repère, texte à gauche tronqué ("over 30 d…"), pas de lignes de contenu : grand vide en bas (nextClass, nextExam, now, spending, timetable, workoutMonth).
- cards (jeu-lootbox) : polices minuscules et caractères altérés (point ou signe − perdu : "+240%", "5 h", "( 15%)"), lignes de détail tronquées ou illisibles.
- list/split (plaque-rivets, luxe-acier-or) : titre tronqué ; split affiche 1 seule ligne avec de la place libre ; barres sans repère.
- minimal (retro-vhs) : sous-titre toujours tronqué ("· d…", "in 1…", "month…") ; vide au-dessus du grand chiffre ; contenu secondaire absent.
- data (pixel-ecran-ambre) : libellés majuscules coupés ("ISHARES COR…", "ROMANIAN DEA…", "Debts $10…", "kcal/d…") ; 2 colonnes trop étroites.
- progress (aura-pulse) : titre tronqué ; une seule ligne affichée quand plus existent.
- graph (aura-braise) : courbes et barres sans aucun texte ni repère (nutritionWeek, revenueTrend, studyHours, weeklyVolume, profit, todaysWorkout) ; titre tronqué. Règle à ajouter : toujours un libellé de valeur ou des jours.

Planches ouvertes : 41 sur 41 (taille small uniquement ; la liste g2.txt ne contient que ces 41).

## v2:66b3d87dfc45adafa59cd2102aa0a21149455d3b3fd4d942a4bc143245526fbf

Je ne peux détailler que 27 planches sur 45, de companyRevenue à moonPhase. Les 18 premières (ageProgress à companyCompare, plus les deux autres que mon outil de lecture a supprimées du contexte) ne sont plus consultables. Je ne les ai pas revues, donc je ne les commente pas.

| type | taille | style (disposition) | problème | gravité |
|---|---|---|---|---|
| moonPhase | moyen | retro-vhs (minimal) | valeur "93%" coupée, affiche "C illuminated" | forte |
| companyRevenue | moyen | riche-gala (centered) | valeur tronquée "36.5…" | forte |
| companyRevenue | moyen | retro-vhs (minimal) | valeur tronquée "36…" | forte |
| companyRevenue | moyen | prime-cobalt (horizontal) | courbe sans repères, étiquette "36503.1M" qui déborde en haut à droite | forte |
| companyRevenue | moyen | luxe-acier-or (split) | titre "EXAMPL…" coupé, étiquettes de barres coupées | forte |
| companyRevenue | moyen | pixel-ecran-ambre (data) | "(T4 202…" coupé, courbe sans repère | forte |
| companySnapshot | moyen | prime-cobalt (horizontal) | courbe sans repères, "129028.6M" qui déborde | forte |
| companySnapshot | moyen | pixel-ecran-ambre (data) | courbe sans repère | moyenne |
| companySnapshot | moyen | aura-braise (graph) | "+57%" alors que les autres styles affichent +12% (incohérent) | moyenne |
| habitWeek | moyen | vint-sepia-gazette (vertical) | "Today: 3/4" chevauche "Meditate", dernière ligne "No screens in bed" coupée | forte |
| habitWeek | moyen | plaque-rivets (list) | même chevauchement et même ligne coupée | forte |
| habitWeek | moyen | aura-pulse (progress) | même chevauchement et même ligne coupée | forte |
| habitWeek | moyen | riche-gala (centered) | noms tronqués "Me…", "Fit…" | moyenne |
| habitWeek | moyen | retro-vhs (minimal) | noms tronqués "Media…", "No scr…" | moyenne |
| habitWeek | moyen | luxe-acier-or (split) | nom tronqué "No scre…" | moyenne |
| habitWeek | moyen | prime-cobalt (horizontal) | grande zone vide, aucune grille alors que 4 lignes existent | moyenne |
| habitWeek | moyen | jeu-lootbox (cards) | grande zone vide, aucune grille alors que 4 lignes existent | moyenne |
| crypto | moyen | jeu-lootbox (cards) | prix haut/bas ("US$66,801", "US$63,410") qui se chevauchent avec la courbe | moyenne |
| crypto | moyen | riche-gala (centered) | prix haut/bas collés à la courbe, mal lisibles | moyenne |
| holiday | moyen | retro-vhs (minimal) | "New Year's…", "National P…" tronqués | moyenne |
| holiday | moyen | luxe-acier-or (split) | "Easter Mond…", "National Patr…" tronqués | moyenne |
| holiday | moyen | jeu-lootbox (cards) | "National Patriots'…" tronqué | moyenne |
| holiday | moyen | tous | le titre dit "Christmas, 28 jours" mais la liste commence au 1er janvier (contenu infidèle) | moyenne |
| holiday | moyen | prime-cobalt (horizontal) | 1 seule ligne affichée, espace vide | moyenne |
| hotel | moyen | pixel-ecran-ambre (data) | "Hotel Al…" et adresse "RUA DE SÃO MI…" tronqués | forte |
| hotel | moyen | prime-cobalt (horizontal) | 1 seule ligne (Arrival), espace vide | moyenne |
| flight | moyen | pixel-ecran-ambre (data) | "YUL → LIS · TUE, DE…" tronqué | forte |
| flight | moyen | aura-braise (graph) | ligne Seat absente alors qu'il reste de la place | moyenne |
| flight | moyen | prime-cobalt (horizontal) | 1 seule ligne, espace vide | moyenne |
| marketOverview | moyen | jeu-lootbox (cards) | "24 TUS$" et "market cap · ▲ +1.80% over…" tronqués | forte |
| marketOverview | moyen | pixel-ecran-ambre (data) | "▲ +1.8…" tronqué | forte |
| marketOverview | moyen | prime-cobalt (horizontal) | liste de dominance absente, espace vide | moyenne |
| marketOverview | moyen | aura-pulse (progress) | liste de dominance absente, espace vide | moyenne |
| marketOverview | moyen | retro-vhs (minimal) | libellé de capitalisation sur 3 lignes | moyenne |
| mealsToday | moyen | luxe-acier-or (split) | titre "TODAY'S…" tronqué | moyenne |
| mealsToday | moyen | plaque-rivets (list) | texte du déjeuner collé au bord droit | moyenne |
| mealsToday | moyen | aura-braise (graph) | Snack absent alors qu'il y a de la place | moyenne |
| mealsToday | moyen | prime-cobalt (horizontal) | 1 seule ligne (Breakfast), espace vide | moyenne |
| macros | moyen | pixel-ecran-ambre (data) | "OF 2,200 · FI…" tronqué, valeurs serrées | moyenne |
| macros | moyen | prime-cobalt (horizontal) | seulement Protein affiché (Carbs et Fat absents) | moyenne |
| moneyDashboard | moyen | pixel-ecran-ambre (data) | barre sans explication, "LEFT THIS MON…" tronqué | forte |
| moneyDashboard | moyen | aura-braise (graph) | barre sans étiquette | moyenne |
| moneyDashboard | moyen | prime-cobalt (horizontal) | anneau 32% là où d'autres styles affichent 43% (autre métrique, non expliquée) | moyenne |
| moneyFlow | moyen | aura-braise (graph) | "NET BALANCE" chevauche la valeur | forte |
| deepWork | moyen | prime-cobalt (horizontal) | courbe sans jours ni repère | forte |
| deepWork | moyen | pixel-ecran-ambre (data) | courbe sans repère | forte |
| fitnessDashboard | moyen | pixel-ecran-ambre (data) | points sans explication, "WORKOUTS THIS…" tronqué | forte |
| gradeAverage | moyen | pixel-ecran-ambre (data) | "WEIGHTED OVER…" tronqué, anneau minuscule, English absent | moyenne |
| gradeAverage | moyen | riche-gala (centered) | English absent (3 matières sur 4) | moyenne |
| habitRate | moyen | pixel-ecran-ambre (data) | "OF HABITS KEP…" tronqué, anneau minuscule | moyenne |
| counter | moyen | luxe-acier-or (split) | grande zone vide à gauche | moyenne |
| counter | moyen | pixel-ecran-ambre (data) | boutons −1/+1 absents | moyenne |
| currency | moyen | pixel-ecran-ambre (data) | 4 colonnes serrées, étiquettes minuscules et illisibles | moyenne |
| deadline, countdown, flashcard | moyen | tous | "2 j 10 h" et "à 17:00" sont en français, et non en anglais | moyenne |
| habitStreak | moyen | vint-sepia-gazette (vertical) | grille de points minuscule dans un grand vide | moyenne |
| habitStreak | moyen | plaque-rivets (list) | grille de points minuscule dans un grand vide | moyenne |
| habitStreak | moyen | aura-pulse (progress) | grille de points minuscule dans un grand vide | moyenne |

Problèmes récurrents par disposition, à corriger dans le moteur :
- **data (pixel-ecran-ambre)** : c'est la pire. Les libellés en petites capitales sont tronqués ("…") dans presque chaque planche. Les 4 colonnes sont serrées. Les courbes et barres n'ont ni axe, ni jours, ni valeur. Il faut limiter à 2 ou 3 colonnes, autoriser un retour à la ligne et ajouter un repère à chaque graphique.
- **horizontal (prime-cobalt)** : une seule ligne est affichée alors que la place permet plusieurs lignes (flight, hotel, meals, macros, holiday, habitWeek). La courbe n'a pas d'axe, et l'étiquette de valeur déborde (companyRevenue, companySnapshot). Il faut remplir la place avec les lignes du sujet et brider ou repositionner l'étiquette.
- **vertical (vint-sepia-gazette), list (plaque-rivets) et progress (aura-pulse)** : quand il y a une grille (habitWeek), le sous-titre chevauche la première ligne et la dernière ligne est coupée en bas. Il faut calculer le nombre de lignes à partir de la hauteur disponible. Les grilles de points (habitStreak) restent minuscules dans un grand vide.
- **split (luxe-acier-or) et minimal (retro-vhs)** : les noms et titres dans la colonne étroite sont tronqués (holiday, habitWeek, mealsToday, companyRevenue). Une valeur est coupée ou corrompue, dont "93%" qui devient "C illuminated" en minimal (moonPhase). Les colonnes ont besoin d'une largeur minimale ou d'un retour à la ligne, et la valeur principale ne doit jamais être rognée.
- **centered (riche-gala)** : noms tronqués ("Me…", "Fit…") et valeur "36.5…" coupée. Les repères de courbe (crypto) et les étiquettes de barres sont trop petits ou chevauchent le tracé. Il manque aussi des lignes (English dans gradeAverage).
- **graph (aura-braise) et cards (jeu-lootbox)** : chevauchement du titre sur la valeur (moneyFlow en graph) et des étiquettes sur la courbe (crypto en cards). Certaines lignes sont absentes (Seat, Snack) malgré la place. Les valeurs diffèrent d'un style à l'autre pour un même widget (+57% contre +12%, 32% contre 43%).

Planches ouvertes : 45 sur 45. Détail utilisable pour 27 d'entre elles, de companyRevenue à moonPhase.

## v2:d62759676abe494642d5a6ebabeb7c7e7dc72173ea15e378e25dedb1c6f1797f

Planches ouvertes : 38/38 (recadrées en c-*.png, 2 colonnes x 5 styles). Ordre de lecture : colonne gauche haut en bas = gala, gazette, cobalt, lootbox, plaque ; colonne droite = VHS, acier-or, ambre, pulse, braise. Les textes en français dans une planche en anglais ("/mois", "kcal/j", "T4 25", "EXMP") ne sont pas relevés, sauf subscriptions, nutritionWeek et companyRevenue qui sont signalés plus bas.

TABLEAU (type | taille | style (disposition) | problème | gravité)
businessDashboard | grand | retro-vhs (centered) | valeur héros tronquée "$12,8…" | forte
businessKPIs | grand | retro-vhs (centered) | héros "…orders" : le "160" est mangé par la troncature | forte
companyRevenue | grand | retro-vhs (centered) | héros "36.5…" tronqué (unité GUS$) | forte
companyRevenue | grand | riche-gala (centered) | héros "36.5 GU…" tronqué | forte
companyRevenue | grand | luxe-acier-or (split) | colonne droite très étroite : libellés "T4 20…" et montants "36.5 GU…" tronqués ; l'histogramme est trop large pour la place | forte
nutritionWeek | grand | retro-vhs (centered) | héros "…kcal/j" : valeur tronquée | forte
portfolio | grand | retro-vhs (centered) | héros "$17,1…" tronqué | forte
portfolio | grand | luxe-acier-or / retro-vhs | noms "iShares Core E…" tronqués | moyenne
revenueTrend | grand | retro-vhs (centered) | héros "$14,4…" tronqué | forte
revenueTrend | grand | luxe-acier-or (split) | colonne droite écrasée : "Avera ge p…" coupé sur 3 lignes, "Nov…" tronqué | forte
revenueTrend | grand | aura-braise (graph) | sous-titre "Week $2,720 · month $12,84…" tronqué | moyenne
subscriptions | grand | retro-vhs (centered) | héros "$…/mois" : montant tronqué, et "/mois" en français | forte
watchlist | grand | riche-gala (centered) | héros "US$64,2…" tronqué | forte
watchlist | grand | retro-vhs (centered) | héros "US$64…" tronqué ; libellés "+2.40% · 2…" coupés dans la liste | forte
weeklyVolume | grand | retro-vhs (centered) | héros "12,8…kg" tronqué | forte
mealsToday | grand | retro-vhs (centered) | héros "1,…kcal" tronqué ; noms d'aliments "Rolled oat…" coupés | forte
studentDashboard | grand | retro-vhs / luxe-acier-or (centered / split) | "Study this w…" et "Group pre…" tronqués | moyenne
fitnessDashboard | grand | retro-vhs (centered) | "Calories b…" tronqué | moyenne
workoutMonth | grand | retro-vhs (centered) | héros réduit à "workouts" : le "19" a disparu | forte
workoutMonth | grand | luxe-acier-or (split) | grille de points sans légende de jours, trou énorme sous le héros | moyenne
habitWeek | grand | riche-gala / retro-vhs (centered) | noms d'habitudes coupés ("Me…", "Fit…", "Medit…", "No sc…") dans une colonne minuscule ; ~60 % de la planche vide | forte
habitWeek | grand | luxe-acier-or (split) | "No scr…" tronqué ; moitié basse vide | moyenne
timetable | grand | riche-gala (centered) | mini-grille horaire illisible, textes des blocs coupés verticalement, jours "M T W…" minuscules | forte
timetable | grand | retro-vhs / luxe-acier-or (centered / split) | idem : blocs de 3 à 4 lettres par ligne ("Mat h…"), illisibles | forte
timetable | grand | prime-cobalt / jeu-lootbox / plaque-rivets | texte des blocs de l'après-midi qui se chevauche ("History A-110" sur "15:00") | moyenne
businessDashboard | grand | prime-cobalt (horizontal) | étiquette "420" de la courbe en collision avec le dernier point et la courbe | moyenne
businessDashboard | grand | pixel-ecran-ambre (data) | étiquette "42…" coupée au bord droit de la courbe | moyenne
companyRevenue | grand | pixel-ecran-ambre (data) | étiquette "36503.1M" coupée au bord droit | moyenne
nutritionWeek | grand | pixel-ecran-ambre (data) | étiquette "1.1k" coupée au bord droit | moyenne
revenueTrend | grand | pixel-ecran-ambre (data) | étiquette "420" coupée au bord droit | moyenne
spendingByCategory | grand | vint-sepia-gazette (vertical) | légende de la barre empilée (5 lignes) qui chevauche la liste détaillée : "Home" collé à "Groceries over $500" | forte
spendingByCategory | grand | aura-pulse (progress) | même chevauchement légende/liste ("Home 8%" sur "Groceries") | forte
spendingByCategory | grand | jeu-lootbox (cards) | "November · 6 categories" en collision avec la barre ; légende collée aux cartes ; "$769" coupé en haut | forte
spendingByCategory | grand | luxe-acier-or (split) | histogramme d'étiquettes illisibles ("Groce…", "Trans…") sans montants, gros vide dessous | moyenne
spendingByCategory | grand | pixel-ecran-ambre (data) | barre et légende empilées sous la grille, serrées, "Other" non listé | moyenne
spendingByCategory | grand | aura-braise (graph) | barre + légende (5 lignes) puis grand trou, puis 3 lignes seulement (Restaurants en bas) | moyenne
weeklyVolume | grand | prime-cobalt (horizontal) | courbe minuscule + 70 % de la planche vide ; aucun repère de jours | forte
weeklyVolume | grand | pixel-ecran-ambre (data) | courbe sans aucun repère (ni jours ni valeurs) | forte
weeklyVolume | grand | aura-braise (graph) | courbe sans jours ; "-100% 3.6k → 0" trompeur | forte
studyHours | grand | prime-cobalt / pixel-ecran-ambre / aura-braise | courbe sans jours ; "-100% 95 → 0" trompeur | forte
deepWork | grand | prime-cobalt / pixel-ecran-ambre / aura-braise | courbe sans jours ; "-100%  75 → 0" trompeur | forte
deepWork | grand | riche-gala / retro-vhs (centered) | les 7 jours disparaissent, barre de progression seule, grand vide | moyenne
gradeAverage | grand | aura-braise (graph) | anneau énorme sans info utile ; 2 matières (English) coupées de la liste | moyenne
businessDashboard | grand | aura-braise (graph) | courbe énorme sans repère de jours, "+2% 412 → 420" ; 3 lignes seulement sur 6 | moyenne
balance | grand | aura-braise (graph) | courbe énorme sans repère de jours ; 3 lignes sur 4 | moyenne
balance | grand | plaque-rivets (list) | aucun graphique et 55 % de la planche vide | moyenne
balance | grand | jeu-lootbox (cards) | "$0" et "-$0" : valeur incohérente ("Start of month") | moyenne
balance | grand | luxe-acier-or (split) | barres sans valeur ni jours ; colonne droite sans graphique mais vide dessous | moyenne
moneyDashboard | grand | pixel-ecran-ambre (data) | 6 valeurs seulement sur 9 lignes, la barre de progression "32%" sans libellé ni valeur | moyenne
moneyDashboard | grand | luxe-acier-or (split) | barre de progression à gauche sans valeur ni titre | moyenne
moneyDashboard | grand | aura-braise (graph) | 3 lignes seulement et ~55 % de vide au milieu | forte
moneyDashboard | grand | riche-gala (centered) | liste de droite serrée, "Spent this mo…" tronqué | moyenne
personalRecords | grand | riche-gala / retro-vhs (centered) | noms "Romania…", "Overhea…", "Dumbbe…" tronqués, 1RM coupés ("1RM = 115…") | moyenne
personalRecords | grand | pixel-ecran-ambre (data) | "1RM" absent, noms de lignes sans valeur d'1RM | moyenne
project | grand | luxe-acier-or (split) | anneau 63% sans légende, colonne droite avec 3 lignes et vide | moyenne
project | grand | aura-braise (graph) | anneau énorme au centre, 3 lignes minuscules en bas | moyenne
project | grand | plaque-rivets (list) | 3 lignes seulement, 70 % de la planche vide | moyenne
todaysWorkout | grand | vint-sepia-gazette (vertical) | anneau 30% sans libellé de quoi (séries) | moyenne
todaysWorkout | grand | aura-braise (graph) | 60 % de vide noir entre l'en-tête et la barre | forte
todaysWorkout | grand | luxe-acier-or (split) | barre 3/10 sans libellé "séries", moitié droite vide | moyenne
upNext | grand | tous les styles | 3 événements, ~45–65 % de la planche vide dans chaque style | moyenne
tasks | grand | tous les styles | 4 tâches, 50–60 % de vide partout ; aucun graphique | moyenne
note | grand | tous les styles | 1 phrase, 60–80 % vide (normal pour une note, mais rien d'autre dans la place libre) | moyenne
aiSummary | grand | tous les styles | 3 puces, 55–70 % de vide ; format héros absent | moyenne
assignments | grand | jeu-lootbox (cards) | cartes "2 d", "5 d" sans le libellé complet visible ("Lab report" minuscule) ; pas de colonne d'échéance explicite | moyenne
assignments | grand | pixel-ecran-ambre (data) | contenu infidèle : "3 due" et "Lab report · in 2 days" en titre, puis "2 d / 5 d / 9 d" sans titre clair ; ordre brouillé | forte
assignments | grand | prime-cobalt / vint-sepia-gazette / plaque-rivets / aura-braise | 3 lignes seulement, 40–60 % vide | moyenne
billsUpcoming | grand | jeu-lootbox (cards) | 5 factures sur 7 ; "Spotify" et "Gym" absents | moyenne
billsUpcoming | grand | prime-cobalt (horizontal) / vint-sepia-gazette | 6 ou 5 factures sur 7 (Gym coupée) alors que la place libre existe | moyenne
billsUpcoming | grand | pixel-ecran-ambre (data) | 6 valeurs sur 7, 40 % de vide en bas | moyenne
habits | grand | tous les styles | grille de points illisible (aucun libellé de jours/mois), titres seuls "Meditate / Fitness / Reading" ; "4 83%" ambigu (flamme + %) | moyenne
yearDots | grand | tous les styles | aucune légende (jours restants, mois) ; 4 lignes de points assombris sans explication | moyenne
yearDots | grand | vint-sepia-gazette / luxe-acier-or | cadre du widget : "331/365" haut, pied "91% of the year" collé à la dernière ligne de points | moyenne
moneyFlow | grand | riche-gala (vertical-like) | colonne de chiffres décalée à droite, libellés et montants peu alignés | moyenne
moneyFlow | grand | retro-vhs / pixel-ecran-ambre | texte très petit "Since November 15, 2026", barre sans libellé | moyenne
calendar | grand | riche-gala | numéros du bas peu lisibles sur le fond étoilé (jours 24, 25, 26 grisés) | moyenne
mealsToday | grand | pixel-ecran-ambre (data) | "Dinner —" : tiret sans explication ; 60 % de vide | moyenne
fitnessDashboard | grand | pixel-ecran-ambre (data) | texte de grille minuscule (mots de 4 px) et gros trou entre les valeurs et la rangée des jours | moyenne
fitnessDashboard | grand | jeu-lootbox (cards) | cartes du bas minuscules, grand vide au milieu | moyenne
morning | grand | pixel-ecran-ambre (data) | 4 lignes sur 9 affichées ; 55 % de vide en bas | forte
myDay | grand | pixel-ecran-ambre (data) | 5 valeurs/6 lignes, "Habits 3/4" sans barre, 45 % de vide | moyenne
now | grand | pixel-ecran-ambre (data) | 4 lignes sur 9 ; 55 % de vide | forte
subscriptions | grand | retro-vhs (centered) / luxe-acier-or | "/mois" non traduit (français dans la planche anglaise) | moyenne
nutritionWeek | grand | riche-gala / retro-vhs / luxe-acier-or | "kcal/j" : unité en français | moyenne
nutritionWeek | grand | vint-sepia-gazette (vertical) | 3 jours seulement sur 7 sous le graphique, 20 % de vide | moyenne
nutritionWeek | grand | aura-braise (graph) | courbe énorme sans jours, "+0% 0 → 1.1k" incohérent ; 3 jours sur 7 | forte
companyCompare | grand | luxe-acier-or (split) | descriptions "+12.0% year over…" tronquées, colonne gauche vide (juste "EXMP · DEMO · TEST") | forte
companyCompare | grand | jeu-lootbox (cards) | "129 GUS$", "68.2 GUS$" coupés au bord droit | forte
companyCompare | grand | pixel-ecran-ambre (data) | barres de comparaison absentes ; valeurs seules, 55 % de vide | moyenne
companyCompare | grand | prime-cobalt (horizontal) | titre "EXMP · DEMO · TEST" flottant sans sens, vide haut et bas | moyenne
companyRevenue | grand | prime-cobalt (horizontal) | étiquette "36503.1M" au-dessus de la courbe coupée à droite, unité mélangée (M / GUS$) | moyenne
companyRevenue | grand | jeu-lootbox (cards) | "GUS$" en police rustique illisible ("GUS:") | moyenne
businessKPIs | grand | tous styles sauf centrés | 5 KPIs, 30–60 % de vide ; héros "160 orders" sans lien avec le titre "Monthly indicators" | moyenne
calendar | grand | aura-pulse / retro-vhs | pas de problème bloquant, bon remplissage (rien à corriger) | -

RÉCURRENTS PAR DISPOSITION (à corriger dans le moteur)
- centered (Focus : riche-gala, retro-vhs) : la valeur héros est tronquée dès qu'elle dépasse la demi-largeur ("$12,8…", "36.5…", "US$64…", "1,…kcal", "…kcal/j") ; il manque une réduction automatique (minimumScaleFactor) ou un héros sur 2 lignes. Les libellés de lignes à droite sont aussi coupés ("Romania…", "Medit…", "Me…"). Pour les widgets sans liste (note, habitWeek, timetable, workoutMonth), le héros occupe toute la demi-planche et la grille voisine est illisible.
- split (luxe-acier-or) : colonne droite trop étroite pour les montants et sous-titres (revenueTrend, companyRevenue, companyCompare) ; histogrammes ou anneaux à gauche sans valeurs ni jours ; la moitié basse reste vide (aiSummary, tasks, habitWeek, upNext).
- horizontal (prime-cobalt) : le haut de la planche est vide (~30 %), la liste tient dans la moitié basse, et le bas laisse encore du vide ; courbes minuscules sans repère de jours (weeklyVolume, studyHours, deepWork, balance) et étiquette de dernier point en collision avec la courbe (businessDashboard, revenueTrend).
- data (pixel-ecran-ambre) : n'affiche que 4–6 valeurs sur 7–9 lignes (morning, now, billsUpcoming, moneyDashboard) et laisse 40–60 % de vide ; courbes sans repère de jours ; étiquette finale coupée au bord droit ; libellés de grille d'un corps minuscule (fitness, assignments).
- graph (aura-braise) : la courbe ou l'anneau géant avale la place et ne laisse que 2–3 lignes en bas (businessDashboard, moneyDashboard, nutritionWeek, balance, gradeAverage) ; courbe sans jours, avec "−100 %" ou "+0 %" trompeur quand le dernier point vaut 0 (weeklyVolume, studyHours, deepWork) ; vide noir au milieu (todaysWorkout, moneyDashboard).
- vertical / progress / list / cards / minimal en général : jusqu'à 50–70 % de vide sur les widgets à 3–4 lignes (tasks, upNext, note, aiSummary, assignments, project, subscriptions) — le moteur ne remplit pas la place libre (lignes de détail, graphique de repli). Cartes (jeu-lootbox) : la dernière carte pleine largeur isolée et les titres de cartes à 5 px ; la barre empilée de spendingByCategory chevauche sa légende (gazette, pulse, lootbox).

