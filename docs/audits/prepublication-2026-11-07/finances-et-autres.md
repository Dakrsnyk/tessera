# Audit 24.M : Finances, Placements, Mon entreprise, Sociétés cotées, Auto, Voyage, Ma vie, Apple Pay

Date : 2026-11-07. Méthode : lecture statique du code (pas de Mac, rien compilé ni exécuté). « À confirmer » : seule une exécution tranche. Aucun fichier du projet modifié.

Fichiers lus : `Shared/Domains/{Budget,ApplePayExpense,Portfolio,Business,BusinessImport,Companies,Car,Travel,Life}.swift`, `App/Intents/ApplePayIntent.swift`, `App/Services/StripeSync.swift`, `App/Screens/MiniApps/{Finances,Business,Car,Travel}/*`, `App/Screens/Spaces/{BudgetSpace,MoneySpaces,TravelCarLifeSpaces}.swift`, `App/Core/AppModel.swift`, `Shared/Support/{SharedStore,Formatting,Helpers}.swift`, `Shared/Render/Tiles/{Money,Dashboard}Tiles.swift`, `Shared/Intents/SpaceIntents.swift`, liste des tests de `Tests/ApplePayExpenseTests.swift`.

## Résumé par gravité

- Bloquant : 0
- Majeur : 7 (M-01 à M-07)
- Mineur : 19 (M-08 à M-26)
- Amélioration : 3 (M-27 à M-29)

Les 6 plus graves : M-01 budget de voyage réécrit à environ 1 dans 5 langues sur 6 ; M-02 échéance des factures du 29 au 31 décalée au 28 ; M-03 date de naissance fictive 1995-01-01 qui alimente nutrition et contrôle des mineurs ; M-04 budget fictif de 2 000 affiché comme réel ; M-05 cryptos et actions valorisées dans une autre devise que celle affichée ; M-06 synchronisation Stripe qui perd les opérations anciennes au-delà de 3 000.

---

## Majeurs

### M-01 Majeur : ouvrir le budget d'un voyage réécrit ce budget (5 langues sur 6), à confirmer (déclenchement de onChange)
- Fichier : `App/Screens/MiniApps/Travel/TravelPages.swift:194-195` et `:198-204`.
- Preuve : `.onAppear { budgetText = trip.budget.map { TF.int($0) } ?? "" }` met dans le champ un texte formaté par `Fmt.number` (milliers : « 1 235 » fr, « 1,235 » en/ja, « 1.235 » de/es/it/pt-BR). `.onChange(of: budgetText) { saveBudget() }` se déclenche ensuite et `saveBudget` fait `Double(text.replacingOccurrences(of: ",", with: ".").filter { "0123456789.".contains($0) })` : « 1,235 » et « 1.235 » donnent 1.235. En français l'espace fine est filtrée : 1235 (décimales perdues, montant conservé). Taper « 1.234,56 » donne « 1.234.56 », `Double` renvoie nil et le budget est supprimé sans message.
- Impact : un utilisateur non francophone avec un budget de voyage d'au moins 1 000 voit son budget devenir environ 1 dès qu'il ouvre la page ; la jauge affiche « Dépassé ». Corruption silencieuse.
- Reproduction : langue anglaise, voyage avec budget 2 500, ouvrir Voyage > Budget : le champ affiche 2,500 puis le budget enregistré vaut 2.5.
- Correction : remplacer par `OptionalNumberRow` (déjà utilisé, `TextField(value:format:.number.locale(Fmt.locale))`) ou parser avec `NumberFormatter` en `Fmt.locale`, et n'enregistrer que sur une saisie de l'utilisateur.
- Test : fonction extraite `TripBudgetText.parse(_:locale:)` : « 2 500,50 » (fr), « 2,500.50 » (en), « 2.500,50 » (de) donnent 2500.5 ; aller-retour format/parse de 1234.56.

### M-02 Majeur : échéance d'une facture mensuelle du 29, 30 ou 31 décalée au 28
- Fichier : `Shared/Domains/Budget.swift:70-85` (`Bill.nextDue`), utilisée par `BudgetMath.upcomingBills` (`:508-515`), les widgets de factures et `Shared/Support/SmartReminders.swift:62,71`.
- Preuve : la boucle fait `due = cal.date(byAdding: .month, value: 1, to: due)` de façon cumulative : 31 janv. donne 28 fév., puis 28 mars, 28 avril… Le 31 est perdu après un mois court. `BudgetMath.paymentDates` (`:383-393`) calcule bien `ancre + n mois` (31 mars, 30 avril) : les dépenses comptées sont au bon jour, l'échéance affichée et le rappel au 28.
- Impact : « Prochaine échéance » et rappels faux de 1 à 3 jours pour un loyer ou une assurance du 29-31 ; le rappel peut arriver après le prélèvement.
- Reproduction : ancre 2026-01-31, mensuelle, aujourd'hui 2026-03-05 : `nextDue` renvoie le 28 mars au lieu du 31. Le test existant (`Tests/DomainLogicTests.swift:65`) ne couvre que le 1er.
- Correction : calculer `ancre + k·pas` depuis l'ancre (k croissant jusqu'à ≥ aujourd'hui), comme `paymentDates`.
- Test : ancre 2026-01-31 : `nextDue(after: 2026-03-05) == 2026-03-31`, `after 2026-02-10 == 2026-02-28`, `after 2026-04-01 == 2026-04-30` ; annuel avec ancre 29 févr. 2024.

### M-03 Majeur : « Afficher mon anniversaire » invente la date du 1er janvier 1995
- Fichier : `App/Screens/Spaces/TravelCarLifeSpaces.swift:511-514` (`$0.birthday ?? Holidays.make(1995, 1, 1)`).
- Preuve : activer l'interrupteur écrit une date fictive. `life.birthday` alimente l'âge, le plan de poids, les besoins nutritionnels et le test « mineur » (`App/Core/AppModel.swift:958, 998, 1020, 1137`).
- Impact : un utilisateur qui active l'interrupteur sans régler la date reçoit un âge de 31 ans, des calories calculées sur cet âge, et un mineur contourne le contrôle. Contredit « aucune donnée fictive » (6.C).
- Reproduction : Ma vie > activer « Afficher mon anniversaire » sans toucher au sélecteur : « Âge 31,xx ans ».
- Correction : ne pas préremplir ; n'enregistrer qu'une date choisie (feuille avec « Enregistrer »).
- Test : activer l'interrupteur ne rend pas `life.birthday` non nil sans choix ; `AppModel.age` reste nil.

### M-04 Majeur : un budget mensuel de 2 000 inventé est affiché comme réel
- Fichiers : `Shared/Domains/Budget.swift:215` (`monthlyBudget = 2_000`), `App/Screens/MiniApps/Finances/FinancesApp.swift:214-247` (héros et bouton « Budget 2 000 $ »), `Shared/Render/Tiles/DashboardTiles.swift:210-216` (tuile « Argent »), `Shared/Render/Tiles/MoneyTiles.swift:207` (« Reste du mois » de la dépense rapide).
- Preuve : `budgetLeft` et `budgetRow` testent `knowsBudget` (« jamais un reste d'un budget inventé »), pas le héros de Finances, ni `DashboardTiles.money`, ni `quickExpense`.
- Impact : chiffre faux présenté comme un fait, incohérent avec le widget « Reste du mois » qui affiche « Budget mensuel à définir ».
- Reproduction : nouvel utilisateur, noter 50 $ : héros « Reste ce mois-ci 1 950 $ », « 63 $ par jour ».
- Correction : héros avec `!model.profile.knows(.monthlyBudget)` : « Dépensé ce mois-ci » et bouton « Définir mon budget » ; `knowsBudget` aussi dans `DashboardTiles.money` et `quickExpense`.
- Test : profil sans `.monthlyBudget` : tuile « Argent » sans reste ; avec budget saisi : comportement actuel.

### M-05 Majeur : cryptos et actions valorisées dans une autre devise que celle affichée
- Fichiers : `Shared/Domains/Portfolio.swift:72-86`, `:186,304`, `App/Screens/Spaces/MoneySpaces.swift:15-21,113-116`, `App/Screens/Profile/ProfileView.swift:115-120`.
- Preuve : le prix d'une crypto vient de CoinGecko dans `settings.cryptoCurrency` (défaut « usd »), les actions de Finnhub (USD pour un titre américain), alors que `value`, `costBasis` et `manualPrice` sont libellés en `settings.currencyCode`. Les deux réglages sont indépendants. Total et gain additionnent des devises différentes sous un seul symbole.
- Impact : en CAD, un achat de bitcoin de 1 000 $ CA est valorisé avec un cours USD libellé CAD : gain faux de l'ordre de 25 à 35 %.
- Reproduction : devise CAD, devise crypto USD (défaut), placement bitcoin, coût 1 000 : valeur = cours USD × quantité, libellée CAD.
- Correction : valoriser dans `currencyCode` (`vs_currency` = devise des réglages si prise en charge, sinon conversion `FXService`) et réserver `cryptoCurrency` à la liste de suivi ; pour une action en USD avec clé Finnhub, convertir ou n'utiliser que `manualPrice`. Au minimum, afficher la devise du cours.
- Test : `PortfolioMath.positions` avec `PriceBook` en USD et devise CAD : valeur convertie ou position marquée « devise différente ».

### M-06 Majeur : Stripe, au-delà de 3 000 opérations les plus anciennes sont perdues pour toujours
- Fichier : `App/Services/StripeSync.swift:112-122` (`for _ in 0..<30`) et `:152-170` (`syncedUntil`).
- Preuve : l'API renvoie de la plus récente à la plus ancienne ; la boucle s'arrête après 30 pages de 100 avec `hasMore` encore vrai, sans le signaler, puis `syncedUntil` avance à l'opération la plus récente : la fenêtre ancienne n'est plus jamais relue. La première synchronisation remonte d'un an : plus de 3 000 opérations par an (une vente donne au moins une opération) sont tronquées.
- Impact : chiffre d'affaires et bénéfice sous-estimés sans message pour une entreprise à volume ; aucun moyen de combler le trou.
- Reproduction : compte Stripe de 4 000 opérations sur 12 mois : seules les 3 000 plus récentes arrivent, `lastError` reste vide.
- Correction : continuer tant que `hasMore` (plafond plus haut ou fenêtres `created[gte]`/`created[lt]`) ; si le plafond est atteint, ne pas avancer `syncedUntil` au-delà de la plus ancienne opération lue et afficher « Synchronisation partielle ».
- Test : extraire `fetchAll(page:)` injectable ; une page factice avec `has_more = true` sans fin : `syncedUntil` n'avance pas et une erreur est posée.

### M-07 Majeur : le décodage tolérant ne protège pas les listes, une entrée illisible efface toute la liste
- Fichiers : `Shared/Support/Helpers.swift:6-8` (`value`), `Budget.swift:244-260`, `Business.swift:150-160`, `Car.swift:57-70`, `Travel.swift:97-106`, `Portfolio.swift:46-51`.
- Preuve : `expenses = c.value(.expenses, [])` fait `(try? decodeIfPresent([Expense].self…)) ?? []` : si un seul élément échoue (clé non optionnelle absente après l'ajout d'un champ, type changé), tout le tableau devient `[]`. Les structs (`Expense`, `Bill`, `Account`, `Holding`, `Trip`, `FuelFill`…) utilisent le Codable synthétisé : une propriété `var x = valeur` est quand même requise à la lecture. Au prochain enregistrement l'état vide écrase le fichier. `LossyList` (`Shared/Model/LossyList.swift`) n'est utilisé que pour les designs.
- Impact : tout futur champ non optionnel ajouté à ces structs efface dépenses, factures, ventes ou placements des utilisateurs existants. Risque latent (les champs récents sont optionnels).
- Correction : décoder ces tableaux avec `LossyList` (`(try? c.decodeIfPresent(LossyList<Expense>.self, forKey: .expenses))?.elements ?? []`).
- Test : JSON de budget avec trois dépenses dont une sans `amount` : les deux autres sont conservées ; idem Business, Car, Travel, Portfolio.

---

## Mineurs

### M-08 Mineur : ajouter une dépense efface les dépenses de plus de 400 jours (revenus : 800)
- `Shared/Domains/Budget.swift:281-291` (`add`, `addIncome`) : `removeAll { $0.date < cutoff }` à chaque ajout, sans avertir. L'historique est tronqué et, avec un « Solde de départ », le solde du graphique ne retombe plus juste (`balanceHistory` suppose toutes les opérations depuis la date de départ).
- Reproduction : dépense datée il y a 450 jours ; en ajouter une aujourd'hui : la première disparaît.
- Correction : ne pas supprimer, ou n'élaguer que ce qui précède `openingDate`, et le dire dans les réglages de données. Test : `add` ne supprime pas une dépense vieille de 450 jours.

### M-09 Mineur : aucune suppression de catégorie
- `App/Screens/Spaces/BudgetSpace.swift:464-492` (`CategoryEditor`) et `FinancesPages.swift:422-447` : ni bouton ni balayage (aucun `categories.removeAll` dans le code). Une catégorie créée par erreur reste à vie, les six par défaut aussi.
- Si une suppression est ajoutée : réaffecter les dépenses (un `categoryID` orphelin donne des « Sans catégorie » à UUID distincts, doublons dans `Chart(spends, id: \.name)` de `FinancesPages.swift:406`), les factures (`Bill.categoryID`), les règles apprises (`merchantRules`), les dépenses rapides.
- Correction : bouton « Supprimer la catégorie » qui déplace ses dépenses vers « Autre » et nettoie les références. Test : supprimer une catégorie utilisée : plus de dépense orpheline, total du mois inchangé.

### M-10 Mineur : les relevés kilométriques ne peuvent être ni corrigés ni supprimés
- `App/Screens/Spaces/TravelCarLifeSpaces.swift:440-457` (`OdometerEditor.save` ajoute toujours) ; `CarMath.odometer` (`Shared/Domains/Car.swift:96-98`) prend le maximum de tous les relevés et pleins. Un kilométrage avec un chiffre de trop gonfle compteur, km du mois, autonomie et entretiens « en retard ». Seul un plein se supprime ; une valeur inférieure est acceptée puis ignorée.
- Correction : liste des relevés avec suppression ; avertir si la valeur est inférieure au dernier relevé ou très supérieure. Test : supprimer le relevé aberrant restaure `CarMath.odometer`.

### M-11 Mineur : « Dernière fois » d'un entretien affiche aujourd'hui mais n'enregistre rien
- `App/Screens/Spaces/TravelCarLifeSpaces.swift:464` : `Binding(get: { service.lastDate ?? Date() }, set: …)` : tant que le sélecteur n'est pas touché, `lastDate` reste nil alors que le champ montre la date du jour. Un entretien « tous les 12 mois » créé ainsi n'a jamais de compte à rebours (`serviceStatus`, `daysLeft` nil).
- Correction : interrupteur « Déjà fait » ou `lastDate` initialisée à la date affichée. Test : entretien avec intervalle de mois sans toucher à la date : `daysLeft` cohérent ou champ clairement vide.

### M-12 Mineur : ventes importées négatives non modifiables, modifications écrasées par la synchronisation
- `App/Screens/Spaces/MoneySpaces.swift:224` (`canSave: sale.amount > 0`) : un remboursement importé (négatif) ne peut plus être enregistré après modification. Une entrée Stripe ou CSV modifiée garde `source` et `externalID` : `BusinessState.merge` (`BusinessImport.swift:97-110`) la remet à jour en place et écrase la correction ; supprimée à la main, elle revient tant qu'elle est dans la fenêtre relue ou si on réimporte le fichier.
- Correction : accepter un montant non nul pour une entrée avec `source` ; marquer `edited` pour que `merge` la saute ; garder la liste des `externalID` ignorés. Test : `merge` ne ressuscite pas une entrée ignorée.

### M-13 Mineur : Stripe, litiges et ajustements ignorés
- `Shared/Domains/BusinessImport.swift:765-790` (`StripeTransactions.batch`) : seuls `charge`, `payment`, `refund*`, `*fee` sont traités ; `adjustment`, litiges (`payment_reversal`) etc. tombent dans `default: batch.skipped += 1`, compteur non montré pour Stripe. Un litige perdu laisse le chiffre d'affaires surestimé.
- Correction : ventes négatives pour litiges et ajustements ; afficher le nombre d'opérations ignorées. Test : `batch` avec un type `adjustment` négatif crée une vente négative.

### M-14 Mineur : après restauration sur un autre iPhone, Stripe paraît connecté et ne synchronise rien
- `App/Services/StripeSync.swift:97-98` : `guard let key = SecretStore.read(…), let link = … else { return nil }`. La clé est en trousseau `ThisDeviceOnly`, mais `StripeLink` fait partie des données sauvegardées : sur un nouvel appareil la carte affiche l'ancien « Synchronisé le… » sans erreur ni invite à reconnecter.
- Correction : lien présent et clé absente : `lastError = « Clé absente de cet iPhone : reconnecte Stripe »`. Test : `sync` sans clé avec un lien : `lastError` non nil.

### M-15 Mineur : la croissance de Business compare à une période précédente trop longue
- `Shared/Domains/Business.swift:188-197` : `previousInterval` utilise `DateInterval(start:, duration: date - current.start)` sans plafond à la fin de la période précédente (Budget le fait avec `min(…, month.start)`). Le 31 mars (30,5 jours écoulés) l'intervalle déborde sur le 1er-3 mars et compte des ventes de mars dans « le mois précédent » ; idem le 31 d'un mois suivant un mois de 30 jours, et du 29 au 31 mars pour février.
- Impact : `growth` et `compare` faussés quelques jours par mois. Correction : `end = min(start + écoulé, current.start)`. Test : ventes le 2 mars et le 20 février ; `previousInterval(.month, containing: 31 mars 12:00)` ne contient pas le 2 mars.

### M-16 Mineur : cours crypto nul pris pour un cours réel ; cours d'une autre devise rendus hors ligne
- `Shared/Domains/Portfolio.swift:288` : `price: $0.current_price ?? 0` : CoinGecko peut renvoyer `null` ; le prix 0 est préféré à `manualPrice` et au coût (`prices.prices[symbol] ?? …` renvoie 0) : position à 0 et gain égal à moins le coût.
- `:186-205` : si `stored.currency != currency` et que le réseau échoue, les anciennes cotes (autre devise) sont quand même renvoyées et affichées dans la nouvelle devise.
- Correction : ignorer les lignes sans prix ; ne renvoyer que des cotes de la devise courante. Test : ligne `current_price: null` : pas de cote ; changement de devise hors ligne : aucune cote.

### M-17 Mineur : placement sans cours valorisé au prix payé, sans le dire
- `Shared/Domains/Portfolio.swift:82` : sans cours en direct ni `manualPrice`, la valeur retombe sur `costBasis / quantity` : gain 0 présenté comme une mesure. Pour actions et ETF (aucune clé Finnhub dans le projet : `FINNHUB_API_KEY = ""` dans `Ardane.xcodeproj/project.pbxproj:395,437`) c'est le cas par défaut ; l'écran ne montre ni l'âge du prix (`PriceBook.fetchedAt` existe) ni « prix non renseigné ».
- Correction : marquer la position « prix à renseigner » et l'exclure du gain total, ou le dire sous le total. Test : `positions` sans prix : drapeau `isEstimated` vrai ; `summary.gain` ne compte pas ces positions.

### M-18 Mineur : changer le type d'un placement garde l'ancien symbole
- `App/Screens/Spaces/MoneySpaces.swift:92-117` : passer de Crypto à ETF laisse `symbol = "bitcoin"` dans le champ ; l'inverse enregistre un symbole d'action comme identifiant CoinGecko (`onAppear` ne corrige que le vide). `saved.symbol` n'est pas mis en majuscules (seul le clavier l'est), or Finnhub attend des majuscules.
- Correction : réinitialiser `symbol` au changement de type ; `uppercased()` pour actions et ETF.

### M-19 Mineur : supprimer un voyage laisse vols, hébergements et activités
- `Shared/Domains/Travel.swift:144-148` : `deleteTrip` retire dépenses et liste, pas `flights`, `stays`, `activities` (rattachés par fenêtre de dates, sans `tripID`) : « prochain vol » et widgets continuent d'afficher un vol d'un voyage supprimé.
- Correction : supprimer les éléments dans la fenêtre du voyage, ou le demander à la confirmation. Test : après `deleteTrip`, `nextFlight` ne renvoie plus un vol de ses dates.

### M-20 Mineur : vol saisi dans le fuseau de l'iPhone, sans contrôle de cohérence
- `App/Screens/Spaces/TravelCarLifeSpaces.swift:204-214` : aucune vérification `arrival > departure` ; l'atterrissage affiché par défaut (+7 h) n'est enregistré que si l'on touche au sélecteur (`arrival` nil sinon). Les heures se saisissent dans le fuseau du téléphone alors que l'heure d'arrivée est celle de la destination : l'utilisateur doit convertir à la main ; `Trip.timeZoneID` n'est pas utilisé pour la saisie.
- Correction : sélecteurs avec le fuseau de chaque ville ; `canSave` exige `arrival > departure` si présent. Test : `canSave` faux si l'atterrissage précède le décollage.

### M-21 Mineur : devise de voyage par défaut « EUR » codée en dur ; budget de voyage lié à la devise courante
- `Shared/Domains/Travel.swift:8` (`currencyCode = "EUR"`) : un voyage créé sans « Chercher la ville » est en EUR pour tout le monde. Le budget du voyage (`Trip.budget`) est « dans la devise maison » : changer `currencyCode` des réglages le réinterprète sans conversion (voir M-27).
- Correction : défaut = devise des réglages ; stocker la devise avec le budget.

### M-22 Mineur : SEC EDGAR, plusieurs cas non gérés
- `Shared/Domains/Companies.swift:104-140` : (1) le premier jeu d'unités du concept est pris (`units.values.first`) et affiché en « USD » par `BigNumber.compact` : une société qui rapporte dans une autre unité est mal libellée. (2) Les sociétés étrangères (20-F, ifrs-full) n'ont pas de `us-gaap` : `ServiceError.decoding`, aucune explication à l'écran. (3) Les trimestres viennent des cadres `CYxxxxQn` : le T4 manque en général (jamais déposé seul), un trou chaque année dans la série. (4) `tr("Revenues")` sert de nom de balise XBRL (`:130`) : cela marche seulement parce que le catalogue le traduit par « Revenues » dans les 7 langues ; une traduction un jour changerait la requête. (5) Aucun traitement du code 429 (limite SEC) ; le cache périmé est renvoyé sans le dire.
- Correction : littéral `"Revenues"` ; message « Cette société ne dépose pas ses états en us-gaap » ; T4 = annuel − T1 − T2 − T3 ; lire l'unité du JSON. Test : `periods` avec trois trimestres et un annuel : T4 dérivé.

### M-23 Mineur : jours fériés, exactitude et jours observés
- `Shared/Domains/Life.swift:94-160` : « Canada (fédéral) » contient « Congé civique » (pas un férié fédéral) ; « Québec » contient « Action de grâce » (non obligatoire au Québec) et à la fois Vendredi saint et Lundi de Pâques (la loi en retient un seul au choix de l'employeur) ; aucun jour observé quand le 25 déc., le 1er janv. ou le 1er juil. tombe un week-end. Contenu à valider avant publication ; `easter`, `nthWeekday` et `mondayBeforeMay25` sont corrects.
- Correction : retirer ou renommer (« Congé civique (certaines provinces) »), ajouter une note « liste indicative ». Test : `list(.canada, 2026)` sans le congé civique.

### M-24 Mineur : formats de montant, devises sans décimales et signe
- `Shared/Support/Formatting.swift:96-103` : `money` impose `minimumFractionDigits = maximumFractionDigits = decimals` (2 par défaut) : en JPY ou KRW (proposées par `FXService.currencies`) l'affichage donne « ¥1 234,00 ». `signedMoney(-0.001)` affiche « −0,00 $ ». Les montants saisis ne sont pas arrondis au centime (`ExpenseEditor.save` garde 12.345) alors que le dédoublonnage Apple Pay compare à 0.005 près.
- Correction : décimales par défaut selon la devise, arrondi au centime à l'enregistrement, `signedMoney` sans signe si l'arrondi est nul. Test : `Fmt.money(1234, currency: "JPY")` sans « .00 ».

---

## Apple Pay par Raccourcis (point 3 et ligne 6.B)

État de 6.B dans le code (lu, non exécuté) :
- Rechargement : `App/Intents/ApplePayIntent.swift:45-53` poste `.budgetSavedOutside` quand une dépense est ajoutée ; `App/Core/AppModel.swift:75-80` relit `BudgetState` depuis le disque. Le défaut décrit en 6.B (écrasement par l'app ouverte) est traité dans le code.
- Tests : `Tests/ApplePayExpenseTests.swift` couvre devise étrangère (`:467`), messages (`:502`), nom en majuscules « 7-ELEVEN #123 » (`:430-436`). Aucun test de l'observateur lui-même (notification puis rechargement de `model.budget`).
- Textes localisés : titre, « Montant », « Commerçant », « Carte » et messages du résultat sont dans le catalogue ; deux textes manquent (M-25).

### M-25 Mineur : description de l'intent et du paramètre absentes du catalogue
- `App/Intents/ApplePayIntent.swift:17-20,29` : « Note dans le budget d'Ardane un paiement mobile… » et « Le montant de la transaction… » n'existent pas comme clés dans `Shared/Localizable.xcstrings` (vérifié par script). L'application Raccourcis les affiche en français quelle que soit la langue.
- Correction : `scripts/l10n_catalog.py extract`, traduire dans `l10n/parts/`, merge, build, sync.

### M-26 Mineur : fenêtre de concurrence entre l'écriture de l'intent et l'enregistrement de l'app, à confirmer
- `App/Core/AppModel.swift:138-145` : `update(\.budget)` écrit l'état en mémoire par `store.save` sans passer par `updateLock` ni relire le disque, alors que l'intent écrit par `store.update` sur un autre fil. Si l'utilisateur enregistre une dépense dans l'app entre l'écriture de l'intent et le traitement de la notification sur le fil principal, l'état périmé écrase la dépense Apple Pay. Fenêtre très étroite.
- Correction : pour `BudgetState`, faire `store.update(T.self)` (relecture sous verrou) puis recopier en mémoire. Test : `ApplePayRecorder.record` puis `model.update(\.budget)` sans notification : la dépense est conservée.

Autres remarques Apple Pay (sans gravité) :
- Une devise explicite différente est marquée « À vérifier » avec la devise dans la note (`ApplePayIntent.swift:117-124`) mais compte à sa valeur faciale dans le budget (5 US$ comptent pour 5 $ CA). Documenté, acceptable.
- `parseSignedAmount` lit « 12,500 » comme 12 500 (`ApplePayExpense.swift:101-104`) car ambigu ; Raccourcis donne en pratique deux décimales. Un « - » après le montant suivi d'un libellé (« 12.50 $ - Tim ») n'est pas vu comme remboursement. La carte est acceptée mais jamais conservée (choix documenté).
- Doublon sous 120 s : montant au demi-centime et nom normalisé, limité aux dépenses `source == .applePay` ; une dépense saisie à la main n'est pas prise pour un doublon (voulu, testé `:263`).

---

## Améliorations

- M-27 : changer la devise des réglages ré-étiquette tous les montants sans conversion ni avertissement (`App/Core/AppModel.swift:451-472`, `updateSettings`). Proposer une confirmation « Les montants ne sont pas convertis ».
- M-28 : l'Auto n'utilise que km, L et L/100 km (`Shared/Domains/Car.swift`, `CarApp.swift:125-135`) alors que le Profil propose « Unités » (impérial). À confirmer : rien dans `Car*` ne lit `unitSystem`. Prévoir miles, gallons, mpg ou le dire dans l'écran.
- M-29 : le MRR et les abonnés (`SubscriptionSnapshot`) sont saisis à la main ; Stripe ne les alimente pas (la clé « Balance transactions » ne le permet pas). L'écran ne le dit pas : ajouter une phrase d'aide.

---

## Examiné et trouvé sain

- Budget : `fixedExpenses`/`paymentDates` calculent les paiements récurrents à la volée depuis l'ancre (`début + n pas`) : pas de doublon à chaque ouverture, 31 du mois et 29 février corrects (`Budget.swift:383-393`) ; identifiants de paiement stables (`paymentID`) ; déduplication d'un paiement noté à la main contre un paiement fixe (3 jours, même montant, même catégorie ou même note).
- « Reste à dépenser » : mini-app (`FinancesApp.swift:214-289`), widgets (`MoneyTiles.budgetLeft`, `DashboardTiles.budgetRow`) et fil du jour utilisent les mêmes `BudgetMath.remaining/perDayLeft/daysLeftInMonth` ; dernier jour du mois et reste négatif traités ; `perDayLeft` plafonné à 0.
- Changement de mois : `MonthSwitcher` borné au mois courant ; `monthToDate` et `FinancesTrendsPage.changes` plafonnent la période précédente ; moyennes sur mois complets seulement.
- Comptes : ajout, modification, suppression, instantané de valeur nette (`removeAccount` vide l'historique quand il n'y a plus de compte).
- Apple Pay : analyse du montant (espaces insécables, milliers, décimales fr/en, parenthèses, signes moins Unicode), remboursement/nul/illisible n'écrivent rien, lecture-modification-écriture atomique (`SharedStore.update`, refus si fichier illisible), doublons sous 120 s, catégorie apprise avant mots-clés, catégorie supprimée jamais ciblée, anciennes données décodées (tests `:339-367`).
- Stripe : clé `rk_` seule acceptée, trousseau `ThisDeviceOnly`, session éphémère sans cache ni cookies ; erreurs 401/403/réseau/serveur traduites ; devises sans décimales (JPY…) ; frais regroupés par jour avec identifiant stable ; conversion au taux BCE du jour, jamais de montant faux en silence ; déconnexion avec ou sans retrait des ventes.
- Import CSV : taille plafonnée à 20 Mo, UTF-16/UTF-8/CP1252, en-tête cherché dans les 15 premières lignes, lignes sans date ni montant comptées « ignorées », dédoublonnage par `source:externalID`, direction vente/coût devinée avec aperçu, Premium requis (décision du 2026-11-05).
- Voyage : conversion des dépenses au taux de référence BCE avec affichage de ce qui n'est pas converti ; hébergement avec départ après arrivée vérifié, voyage avec fin ≥ début.
- Auto : consommation plein à plein correcte, garde `distance > 0`, saisie d'un plein exigeant litres, total et compteur positifs (pas de division par zéro ni de `Int(inf)`), autonomie plafonnée au réservoir.
- Ma vie : calcul de Pâques et des jours mobiles exact, passage d'année des fériés, anniversaire du 29 février, âge décimal borné.
- Données : chaque état a un `init(from:)` tolérant champ par champ (hors listes, voir M-07) ; `SharedStore.update` refuse d'écraser un fichier illisible.
- Aucun bouton sans action, `TODO`/`FIXME` ou donnée fictive accessible en Release trouvé dans ces écrans (`SampleData` ne sert qu'au chargeur d'aperçu des widgets, à voir en 24.W ; `ScreenshotMode` est sous `#if DEBUG`).

## Tests de non-régression à ajouter (récapitulatif)
`Tests/DomainLogicTests.swift` : M-02, M-15, M-19 ; nouveau `Tests/LossyDecodingTests.swift` : M-07 ; `Tests/FinancesBusinessTests.swift` : M-06, M-12, M-13, M-14 ; `Tests/FinancesDayBudgetTests.swift` : M-04 ; `Tests/TravelCarTests.swift` : M-01, M-10, M-11, M-20 ; `Tests/LivePricesTests.swift` : M-05, M-16, M-17 ; `Tests/ProfileMatrixTests.swift` : M-03 ; `Tests/ApplePayExpenseTests.swift` : M-26 ; `Tests/FinanceStatementTests.swift` : M-08, M-24.
