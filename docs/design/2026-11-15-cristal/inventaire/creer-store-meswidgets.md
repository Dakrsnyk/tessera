# Inventaire : Créer, Store, Mes widgets, Premium, Profil

Relevé du 2026-11-15, lecture seule du code (fait foi). Textes = clés `tr("…")` françaises. Captures consultées : celles du 2026-10-31 (`kit2026/fr/`), seulement pour confirmer la mise en page. Tout ce qui est noté « à vérifier » n'a pas été lu dans le code.
Barre d'onglets (`MainTabView`, `App/ArdaneApp.swift`) : Accueil (`square.grid.2x2`), Créer (`plus.square.on.square`), Store (`bag`), Mes widgets (`rectangle.stack`). Quatre onglets seulement. L'avatar de l'Accueil ouvre le Profil.

## 1. Créer, liste (`SpacesView`)

- Titre de navigation : « Créer ». Phrase d'aide : « Choisis un univers, puis la taille de ton widget. »
- Filtres (puces horizontales, 36 pt de haut, la puce active est pleine) dans cet ordre : « Tout », « Écran verrouillé » (icône cadenas, identifiant `create-lockscreen`), « Santé », « Argent », « Organisation », « Vie ».
  - Santé = Fitness, Nutrition, Habitudes. Argent = Budget, Placements, Mon entreprise, Sociétés cotées. Organisation = Productivité, Planning · études. Vie = Voyage, Auto, Ma vie (+ la carte Photos et citations).
- Ordre des cartes : d'abord les espaces des centres d'intérêt de la personne, puis les autres. « Photos et citations » arrive en dernier, dans « Tout » et dans « Vie » seulement.
- Carte (`ImmersiveSpaceCard` → `ImmersiveCard`, privée) : fond = la couleur de l'espace, éclaircie en haut à droite et assombrie vers le bas ; coins 28 pt ; pastille d'icône, « N widget(s) », « · exemple » si l'espace n'a pas de données, chevron dans un rond ; titre 28 pt gras ; une ligne de chiffre vivant ; 2 aperçus réels de widgets (3 pour Nutrition, Entreprise, Ma vie dans le catalogue d'exemples, mais `prefix(2)` n'en garde que 2). Aide VoiceOver : « Crée un widget de cet espace ». Identifiant `space-card-<rawValue>`.
- Le « sous-titre » listé ci-dessous est `Space.subtitle` ; la carte n'affiche PAS ce texte, elle affiche le chiffre vivant (colonne de droite, valeur sans donnée).

| Carte | Couleur | `Space.subtitle` (non affiché sur la carte) | Ligne vivante sans donnée |
|-|-|-|-|
| Productivité | 6B7280 | Tâches, priorités, projets, compteurs | Aucune tâche en attente |
| Habitudes | 7FA33A | Habitudes et séries | Crée une habitude |
| Nutrition | F08A24 | Repas, calories et macros | Note ton premier repas |
| Fitness | E5484D | Séances, séries et records | Crée ta séance |
| Budget | 2F8F7A | Dépenses, factures et épargne | Dépensé … ce mois-ci |
| Placements | 8C6CFF | Actions, ETF, crypto et cash | Ajoute tes placements |
| Mon entreprise | C28A12 | Chiffre d'affaires et indicateurs | Note ta première vente |
| Sociétés cotées | 3366FF | Chiffres officiels des sociétés cotées | N entreprise(s) suivie(s) |
| Planning · études | D6409F | Horaire de la semaine, cours, examens, notes et fiches | Ajoute tes cours |
| Voyage | 12A4B5 | Vols, hôtels et activités | Prépare ton prochain voyage |
| Auto | 4B5563 | Pleins, entretiens et coûts | Note ton premier plein |
| Ma vie | 5B6CFF | Anniversaire, jours fériés, profil | Anniversaire et jours fériés |
| Photos et citations (`PhotoQuotesCard`) | D9608B | (aucun) | « Tes photos et les phrases qui t'inspirent, sur ton écran d'accueil. » ; badge « N widgets » ; indice « Crée ton widget » |

Symboles SF : checklist, repeat, fork.knife, dumbbell.fill, creditcard.fill, chart.pie.fill, briefcase.fill, building.columns.fill, graduationcap.fill, airplane, car.fill, person.crop.circle ; Photos : photo.on.rectangle.angled.
Quand l'espace a des données, la ligne devient un chiffre (« 3/5 aujourd'hui », « 1 240 kcal restantes », « Reste … », « Examen dans N j »…).

- Toucher une carte d'espace : feuille `SpaceBuilderView` (constructeur, section 2). Toucher « Photos et citations » : boîte de dialogue « Créer un widget » avec « Photos » / « Citation » ; ouvre `PhotoQuoteEditor` (éditeur propre, pas le Studio ; ces widgets ne comptent pas dans la limite gratuite). Si la limite est atteinte, paywall `designLimit`.
- Une catégorie touchée sur l'Accueil ouvre directement le constructeur (`router.requestedCreator`).
- Filtre « Écran verrouillé » : remplace la liste par `LockScreenCreator` (section 5).
- `SpaceView` (page « Mes données » d'un espace, `SpacesView.swift` l.535) s'atteint par « Mes données » du constructeur ou depuis l'Accueil ; hors périmètre du relevé, elle montre aussi une rangée de widgets de l'espace (aperçu 128 pt, titre, `PremiumBadge` compact si Premium) qui ouvre le Studio directement.

## 2. Constructeur (`SpaceBuilderView`, feuille)

- Barre de navigation (titre = nom de l'espace, inline) : « Annuler » à gauche ; à droite « Mes données » (icône `square.and.pencil`, pousse `SpaceView`, identifiant `space-data`).
- En-tête : pastille d'icône (couleur de l'espace), titre « Crée ton widget », sous-titre « Choisis une taille et tes widgets, puis personnalise-les dans le Studio. »
- Taille : contrôle segmenté « Taille » : « Petit », « Moyen », « Grand » (3 seulement ; pas d'écran verrouillé ici). Phrase d'aide qui change :
  - Petit : « L'essentiel en un coup d'œil. Choisis-en plusieurs pour créer plusieurs petits widgets. »
  - Moyen : « Plus d'informations : un widget dans sa version moyenne, ou 2 widgets réunis côte à côte. »
  - Grand : « Un tableau de bord de l'espace : un widget en grand, ou jusqu'à 4 widgets réunis. »
- Aperçu : cadre en dégradé gris clair/foncé (coins 24), widget à ses vraies proportions (petit 170 pt de large ; moyen/grand jusqu'à 364 pt), pastille « Exemple » (haut gauche) tant que les données ne sont pas saisies. Petit avec plusieurs widgets : rangée défilante de 128 pt. Combiné : légende « Réunit : A · B ». Sélection impossible : cadre pointillé avec le message du `Composer` (ex. « Choisis 1 widget, ou 2 à réunir. », « Un petit widget montre un seul widget. », « X n'existe pas en petit. », « Pour réunir 2 widgets, chacun doit exister en petit. », « Un widget moyen réunit 2 widgets au plus. », « Choisis de 1 à 4 widgets. », « Pour 3 widgets, l'un d'eux doit exister en moyen. »).
- Section « Widgets » (détail à droite : « N sélectionné(s) » ; hors Petit : « … · 2 au plus » en moyen, « … · 4 au plus » en grand). Maximum en petit : 12.
  - Interrupteur « Seulement les widgets interactifs » (avec badge main `hand.tap.fill`, seulement si l'espace a un widget interactif ; identifiant `builder-interactive-filter`).
  - Grille de 3 colonnes. Cellule = aperçu du widget (petit si existe, sinon moyen), anneau accent 3 pt si choisi, pastille en haut à droite : cercle vide ; coché (`checkmark.circle.fill`) en petit ; numéro d'ordre (`1.circle.fill`…) en moyen/grand (l'ordre = la mise en page). Titre (2 lignes max) ; badge « Interactif » (icône seule) ; cadenas `lock.fill` (couleur `premiumInk`) si Premium et non abonné ; si pas de petit : tailles « Moyen · Grand » en légende. Une cellule n'est jamais désactivée : si le widget n'existe pas à la taille courante, la taille bascule vers la plus petite qui l'a et la sélection repart de ce widget (opacité 0,6 en attendant). Au moins 1 widget reste toujours choisi.
  - Note : « Interactif : s'utilise depuis l'écran d'accueil, sans ouvrir l'app (valider, cocher, ajouter, scanner). »
  - Règle Moyen : 2 widgets réunis, chacun doit avoir un petit ; un widget sans petit reste seul. Règle Grand : 1 à 4 ; 2 = deux lignes moyennes ; 3 = une ligne pleine + 2 moitiés ; 4 = quatre petits.
  - Présélections par taille (`SpaceCatalog.preset`) : ex. Nutrition moyen = Calories restantes + Macros ; grand = + Repas du jour.
- Barre d'action (en bas, `.bar`, 50 pt) : « Personnaliser le widget » (icône `paintbrush.pointed`), ou « Personnaliser les N widgets » (petit, plusieurs). Identifiant `creator-continue`. Pousse le Studio (`WidgetStudio`, `isPushed: true`, `isNew: true`). Le constructeur n'a PAS de bouton Enregistrer.
- Le style de départ (thème, couleur) = celui du premier widget de l'espace ; tous les widgets créés ensemble le partagent.
- Aucun nouveau design (maquette) ne doit supposer un choix de widget caché : aujourd'hui Créer ne saute pas le choix.

## 3. Studio (`WidgetStudio` dans `EditorView.swift` ; ouvert dans `EditorView` quand il vient du Store, de Mes widgets ou de l'écran verrouillé, poussé quand il vient du constructeur ou d'un pack)

### Barre du haut et pied
- Titre inline : « Nouveau widget » / « Nouveaux widgets » (plusieurs) ; « Studio » pour un widget existant.
- « Annuler » (haut gauche) seulement quand le Studio est en feuille (pas poussé : le bouton retour sert). Sur un widget existant modifié : confirmation « Abandonner les modifications ? » → « Abandonner ». Glissement de la feuille interdit tant qu'il y a des changements sur un widget existant.
- Haut droite : deux boutons icône : annuler `arrow.uturn.backward` (« Retour en arrière », `studio-undo`) et rétablir `arrow.uturn.forward` (« Retour en avant », `studio-redo`). 80 pas d'historique ; un curseur ou une saisie compte pour un seul pas (0,6 s).
- Pied (`saveBar`, `.bar`) : bouton plein 50 pt, voir « Enregistrement » plus bas. Désactivé sans changement (jamais pour un nouveau widget).
- Avis Premium (carte jaune `premiumFill`, en tête du contenu) : « Ce widget utilise Premium » + liste « Style X · Fond dégradé · Couleur personnalisée… » + bouton « Débloquer » ; ou avis de limite : « Plus de 3 widgets » + « Sans Premium, les widgets marqués d'un cadenas ne seront pas enregistrés. ».

### Scène d'aperçu (`StudioStage`), toujours visible au-dessus des outils
- Fond : dégradé gris clair/foncé (coins 24) ; pour un widget d'écran verrouillé : dégradé bleu nuit/violet (1F2A44 → 3B2F5C) et légende « Écran verrouillé : iOS affiche les widgets d'une seule teinte. » Pas d'aperçu « sur mon écran » ni de fond d'écran réel.
- Largeur de l'aperçu : petit 150, moyen 318, grand 196 (réduit), accessoires 1,3× leur taille.
- Pastille « Exemple » (haut gauche) si les données ne sont pas saisies.
- Rangée de puces de taille sous l'aperçu (si le widget a plusieurs tailles) : « Petit », « Moyen », « Grand », « Rond », « Rectangle », « En ligne » (les accessoires avec icône `lock.iphone`). C'est un simple choix d'affichage de l'aperçu, la taille créée reste `design.format`.
- Plusieurs widgets (créés ensemble) : rangée de puces « 1 · Nom », « 2 · Nom » (cadenas si au-delà de la limite gratuite) + puce « Même style » (icône chaîne ; le thème, les couleurs, le fond et la bordure vont à tous).
- Réserve : le fond d'aperçu ne suit pas l'apparence du widget ; il existe une capture de composition « écran d'accueil » seulement dans le Store (`HomeSetupSheet`), pas dans le Studio.

### Onglets d'outils (`StudioSectionBar`, puces 36 pt, défilement horizontal, dans cet ordre)
1. Contenu (`square.text.square`) 2. Thème (`sparkles`) 3. Style (`swatchpalette`) 4. Couleurs (`paintpalette`) 5. Fond (`photo`) 6. Bordure (`square.dashed`) 7. Graphique (`chart.bar.xaxis`, SEULEMENT si le widget dessine un graphique) 8. Densité (`rectangle.compress.vertical`) 9. Mes styles (`bookmark`). Identifiants `studio-<content|theme|style|colors|background|border|chart|density|myStyles>`. Il n'y a PAS d'onglet Police (voir plus bas), ni de réglage séparé de forme, texte, icône, ombre : ils viennent du Style/Thème.

**Contenu** (gratuit sauf ce qui est propre au widget)
- « Nom » : champ « Nom du widget ».
- « Tes données » (`WidgetDataSection`) : « Tout est renseigné » / « N à renseigner » + lignes de données à renseigner (pas de Premium) ; note « Renseignées une fois, elles servent à tous tes widgets et à « Mon Quotidien ». » Texte d'aperçu d'exemple : « Aperçu avec des données d'exemple. Renseigne tes données ci-dessous : ton widget affichera les tiennes. »
- Réglages propres au widget (`KindOptionsSection`) : Horloge (« Afficher la date ») ; Fuseaux (« Villes N sur 4 », « Ajouter une ville ») ; Progression (« Période » segmenté) ; Compte à rebours (« Nom de l'événement », Mode, « Date », « Me rappeler le jour J ») ; Décompte (« Nom de l'événement », « Date », « Chaque année ») ; Tâches (« Garder les tâches cochées aujourd'hui », « Gérer mes tâches ») ; Habitudes (« Gérer mes habitudes ») ; Focus (texte 15/25/50 min) ; À venir (accès calendrier) ; Note (« Titre (facultatif) », « Ta note » 180 car.) ; Crypto (actif, « Devise ») ; Flux d'argent (« Afficher », « Mes revenus et dépenses ») ; autres widgets d'espace (`SpaceOptionsSection`) : sélecteur de cible (Habitude, Compteur, Projet, Échéance, Objectif, Entreprise ; valeur « Automatique »), lien « Données de l'espace X », note (indicatif / pas un avis médical / pas un conseil financier / Apple Intelligence pour les analyses).
- Widget combiné : « Widgets réunis » (« Règle chacun ») : une ligne par widget, « Régler » → `ComboPartSettingsView` (aperçu, Nom, Tes données, réglages propres).
- « Éléments affichés » (interrupteurs, selon le widget) : « Titre », « Icône », « Valeur principale », « Légende », « Détails », « Graphique », « Boutons », « Source », « Lignes ». Puis « Lignes » (N, interrupteur + sélecteur de couleur par ligne) et « Répartition » (N segments, couleur par segment).
- « Supprimer ce widget » (rouge, seulement widget existant, seul) → « Supprimer ce widget ? » / « Les widgets qui l'affichent reviendront au modèle par défaut. »

**Thème** (`StudioThemePanel`, ouvert par défaut pour « Créer une variante »)
- Note : « Un thème règle tout d'un coup : style, couleurs, fond et bordure. Ensuite, la couleur principale ou une palette (Couleurs) repeint tout le widget. »
- Grille d'aperçus réels (2 colonnes en moyen, 3 sinon) de 16 thèmes complets (`StylePreset.all`) avec leur résumé : Midnight (Bleu nuit, chiffres fins, lueur discrète), Pure White (Blanc pur, noir net, rien de trop), Ocean (Du turquoise au bleu profond), Forest (Vert forêt, texture papier), Sunset (Orange, rose et violet du soir), Cyber (Magenta et cyan, bord lumineux), Luxury (Noir profond et or), Minimal Black (Noir total, une seule couleur), Glass (Verre dépoli et reflets), Monochrome (Gris doux, chiffres noirs), Sakura (Rose poudré et prune), Sable (Beige chaud, serif élégant), Arctique (Bleu glacier et blanc), Hacker (Vert sur noir, lignes de balayage), Stade (Noir et jaune fluo, gros chiffres), Cockpit (Petites cartes sur ardoise). Cadenas si Premium (un thème est Premium dès qu'il utilise un fond non-« Thème », une bordure, une ombre, une texture, un dégradé perso, un style Premium, une couleur hors des 8 gratuites). Gratuit en pratique : probablement aucun ou presque (à vérifier : Pure White/Midnight utilisent fond couleur ou dégradé donc Premium).

**Style** (`StudioStylePanel`)
- Note : « Un style change l'apparence et la composition : disposition, formes, texte, icônes, ombre. Tes couleurs restent. »
- 57 styles (`ThemeCatalog.all`), grille d'aperçus ; sous-titre « Gratuit » pour les 10 gratuits, cadenas pour les 47 autres.
  - Gratuits : Minimal, Clair, Sombre, Monochrome, Moderne, Carte, Doux, Compact, Sous-bois, Glacier.
  - Premium : Verre, Aurore, Élégant, Digital, Rétro, Futuriste, Typo, Couleur, Liquid Glass, Premium, Dégradé, Néon, Éditorial, Magazine, Tableau de bord, Audacieux, Data, Luxe, Sport, Business, Terminal, Plan, Pastel, Papier, Brutaliste, Carbone, Vapor, Ardoise, Brume, Aube, Lagon, Cerisier, Noir mat, Dune, Synthwave, Espace, Mars, Nature, Botanique, Océan, Héroïque, Justicier, Toile, Farceur, Citrouille, Noël, Nuit de neige.
- Bouton « Revenir aux réglages du style » (désactivé si rien n'a changé).

**Couleurs** (`StudioColorsPanel`)
- « Couleur principale » (détail = nom courant) : « Elle repeint tout le widget : fond, cartes, texte, chiffres, icônes, graphiques et bordure. » 8 pastilles gratuites 44 pt : Jade 2F8F7A, Cobalt 3366FF, Corail FF6B57, Ambre F2A33A, Lilas 8C6CFF, Rose F2588F, Olive 7FA33A, Ardoise 6B7280 ; + sélecteur « Couleur personnalisée » (Premium). « Revenir aux couleurs du style » si modifié.
- « Palettes » (« Tout change d'un coup », Premium) : 14 puces avec 3 pastilles : Jade, Océan, Corail, Lavande, Forêt, Sable, Néon, Bonbon, Or, Graphite, Couchant, Menthe, Minuit, Cerise.
- « Chaque couleur » (Premium) : Texte, Texte secondaire, Chiffres, Icônes, Graphiques, Cartes et surfaces (chacune : « Celle du style » / « Personnalisée », bouton de retour, sélecteur).
- « Hausse et baisse » (Premium) : Positif (« Gains, progression »), Négatif (« Pertes, dépassement »).
- Note si lignes : « La couleur de chaque ligne (protéines, glucides, catégories…) se règle aussi dans Contenu. »

**Fond** (`backgroundSection` + `textureSection`, Premium)
- Contrôle segmenté « Fond » : « Style », « Couleur », « Dégradé », « Verre », « Photo ».
  - Style : « Le fond du style choisi, clair ou sombre selon le style. » (seul gratuit)
  - Couleur : 10 pastilles : Nuit 111318, Encre 1B2340, Forêt 163A30, Bordeaux 4A1628, Sable E9DFCC, Brume DDE3EA, Menthe CFEBDD, Pêche F9D5C5, Blanc FFFFFF, Noir 000000 ; « Autre couleur ».
  - Dégradé : interrupteur « Mon propre dégradé » ; « Couleur 1 », « Couleur 2 » ; 5 directions : « Vers le bas », « En diagonale », « De gauche à droite », « Vers le haut », « Depuis le centre » ; curseur « Intensité » ; 10 idées de dégradés (pastilles). Sinon : « Le dégradé suit la couleur principale. »
  - Verre : « Du verre dépoli teinté de la couleur principale, avec ses reflets. Change la couleur principale pour le teinter. »
  - Photo : « Choisir une photo » / « Changer de photo » (sélecteur Photos) ; curseur « Voile pour la lisibilité » ; note « La photo est réduite pour tenir dans la mémoire limitée des widgets. »
- « Texture » (Premium) : « Aucune », « Grain », « Papier », « Points », « Grille », « Lignes », « Rayures », « Bruit », « Étoiles », « Neige », « Vagues », « Toile », « Feuillage » ; curseur « Intensité ».
- Note : « iOS ne laisse pas un widget montrer le fond d'écran à travers lui : une vraie transparence n'est pas possible. Ardane propose le Verre (givre et reflets dessinés), les dégradés doux et ta photo. Les apparences « Teinté » ou transparentes d'iOS (Personnaliser l'écran d'accueil) s'appliquent aussi aux widgets Ardane. »

**Bordure** (`StudioBorderPanel`, Premium) : 7 choix : « Aucune », « Pleine », « Tirets », « Points », « Double », « Lumineuse », « Dégradé » ; si une bordure : curseurs « Épaisseur » (0,5 à 6 pt), « Opacité », ligne « Couleur ». Note : « La bordure suit exactement le contour du widget, que iOS dessine lui-même. »

**Graphique** (`StudioChartPanel`, seulement si le widget a un graphique) : grille d'aperçus selon la famille de données : séries = Auto, Ligne, Aire, Barres, Histogramme, Points, Sparkline, Évolution, Comparaison ; progression = Auto, Anneau, Cercle, Jauge, Barre, Comparaison ; répartition = Auto, Barre, Anneau, Cercle, Barres. Puis « Apparence du graphique » : curseur « Épaisseur » (×0,5 à ×2,5), interrupteurs « Remplissage », « Afficher les valeurs », ligne « Couleur ». Pas de marque Premium sur ce panneau.

**Densité** (`StudioDensityPanel`) : 3 aperçus : « Aéré », « Équilibré », « Dense » ; note = « Peu d'informations, très lisible. » / « Équilibre entre informations et espace. » / « Plus d'informations dans le même widget. » + « Les marges, l'espacement et le nombre de lignes s'adaptent. » Gratuit.

**Mes styles** (`StudioMyStylesPanel`) : looks enregistrés par la personne, réutilisables.
- « Enregistrer ce look » : « Garde les couleurs, le fond, la bordure, le texte, les icônes et la disposition de ce widget sous un nom, pour les donner à d'autres widgets. » Champ « Mon thème » + bouton « Enregistrer » (`style-save`).
- Vide : « Tes styles apparaîtront ici. Un même style sur la nutrition, le budget et la forme donne un écran d'accueil cohérent. » (icône bookmark)
- Liste « Mes styles » (N) : aperçu 64/110 pt, nom, « <Style> · réglages du style / personnalisé », menu « … » (Renommer, Supprimer), boutons « Appliquer » (devient « Appliqué »), « Autres widgets » (feuille « Appliquer « nom » » : liste à cocher de ses widgets, « Appliquer (N) », pied : le contenu ne change pas, seuls couleurs, fond, bordure, texte, icônes et disposition ; Premium → paywall avec aperçu). Aucun plafond Premium visible dans le code lu (à vérifier dans `model.saveStyle`).

**Police** : pas d'onglet. `FontChoice` = Thème, Standard, Arrondie, Serif (Premium), Mono (Premium) est porté par le thème/Style ; la capture `studio-font.png` est périmée. Mention Premium « Police Serif » possible dans l'avis Premium.

### Enregistrement
- Bouton du pied : « Enregistrer » (widget existant) ; « Enregistrer le widget » (nouveau) ; « Enregistrer les N widgets » (plusieurs) ; « Débloquer et enregistrer » (Premium utilisé ou aucune place → paywall `designs`/`designLimit` sans rien sauver).
- Nouveau widget : `model.install`, célébration (demande de note possible), puis `SaveFlightOverlay` : la feuille se ferme, les widgets (4 max) restent à leur place, se groupent en pile (rotations ±7°) si plusieurs, se soulèvent (1,06×) si un seul, puis volent en arc (0,5 s) vers l'onglet « Mes widgets » (dernier des 4 onglets), 0,12× et fondu ; vibration légère à la fin ; sous « Réduire les animations » les translations sont supprimées, mais la bascule d'échelle/fondu a lieu. Total ≈ 1,1 s. Overlay non interactif, masqué à VoiceOver.
- Après : ouvert depuis le Store/Mes widgets (feuille, 1 widget) : 1,4 s après la fin du vol, feuille `AddToHomeScreenGuide` (section 6). Depuis le constructeur ou un pack (Studio poussé) : la feuille du constructeur se ferme, on revient sur l'onglet d'origine (Créer) et il n'y a PAS de guide automatique. L'onglet n'est pas changé : l'arrivée est suggérée par le vol seulement (à vérifier : aucun `router.tab = .mine` repéré).
- Widget existant : `model.save` pour chacun, fermeture simple.

## 4. Catalogue des widgets (`Shared/Model/KindCatalog.swift`, 95 widgets proposés)

Légende : S/M/L = Petit/Moyen/Grand ; verrouillé : rond (`accessoryCircular`) / rect (`accessoryRectangular`) / ligne (`accessoryInline`) ; I = interactif (inclut les widgets Nutrition à bouton Scanner : caloriesLeft, macros, proteinLeft, mealsToday, nextMeal, nutritionWeek, nutritionStreak) ; P = Premium (cadenas) ; sans P = gratuit. Gratuits : 32, Premium : 63. « Hydratation » (`hydration`) est retiré. Photos (`photos`) et Citation (`quote`) : S M L, gratuits, jamais comptés dans la limite, créés dans « Photos et citations » (`PhotoQuoteEditor`).

Format : Nom `kind` tailles · verrouillé · I · P

- **Productivité** (8) : Tâches `tasks` S M L ·rect ·I ; Focus `focus` S M ·rond/rect ·I ·P ; Top 3 du jour `priorities` S M ·rect ·I ; Projet `project` S M L ·I ·P ; Échéance `deadline` S M ·rond/rect ·P ; Travail profond `deepWork` S M L ·P ; Compteur `counter` S M ·rond ·I ; Analyse productivité `aiProductivity` S M ·P
- **Habitudes** (4) : Habitudes `habits` S M L ·I ; Série `habitStreak` S M ·rond ; Semaine d'habitudes `habitWeek` M L ·P ; Taux de réussite `habitRate` S M ·P
- **Nutrition** (9) : Calories restantes `caloriesLeft` S M ·rond/rect/ligne ·I ; Macros `macros` S M ·rect ·I ; Protéines restantes `proteinLeft` S M ·rond ·I ·P ; Repas du jour `mealsToday` S M L ·I ·P ; Semaine nutrition `nutritionWeek` S M L ·I ·P ; Série de suivi `nutritionStreak` S M ·I ·P ; Ajout rapide `quickFood` S M ·I ·P ; Prochain repas `nextMeal` S M ·I ·P ; Conseil nutrition `aiNutrition` S M ·P
- **Fitness** (8) : Séance du jour `todaysWorkout` S M L ; Prochaine série `nextSet` S M ·rect ·I ; Repos `restTimer` S M ·rond/rect ·I ·P ; Volume de la semaine `weeklyVolume` S M L ·P ; Records `personalRecords` S M L ·P ; Régularité `trainingStreak` S M ·rond ; Calories brûlées `caloriesBurned` S M ·P ; Mois d'entraînement `workoutMonth` S M L ·P
- **Budget** (9) : Flux d'argent `moneyFlow` S M L ·P ; Reste du mois `budgetLeft` S M ·rect/ligne ; Dépenses par catégorie `spendingByCategory` S M L ·P ; Factures à venir `billsUpcoming` S M L ·rect ·P ; Objectif d'épargne `savingsGoal` S M ·rond ; Valeur nette `netWorth` S M ·P ; Abonnements `subscriptions` S M L ·P ; Dépense rapide `quickExpense` S M ·I ; Analyse des dépenses `aiFinance` S M ·P
- **Placements** (4) : Portefeuille `portfolio` S M L ·rect ·P ; Répartition `allocation` S M ·P ; Plus forte variation `topMover` S M ·P ; Liste de suivi `watchlist` S M L
- **Mon entreprise** (7) : Objectif du mois `revenueGoal` S M ·rond/rect ; Ventes sur 30 jours `revenueTrend` S M L ·P ; Bénéfice `profit` S M ·P ; Indicateurs `businessKPIs` S M L ·P ; MRR et ARR `mrr` S M ·rect ·P ; Ventes du jour `revenueToday` S M ·rect/ligne ·P ; Tableau de bord business `businessDashboard` M L ·P
- **Sociétés cotées** (4) : Fiche entreprise `companySnapshot` S M ·P ; Revenus trimestriels `companyRevenue` S M L ·P ; Action `companyStock` S M ·rect ·P ; Comparateur `companyCompare` M L ·P
- **Planning · études** (8) : Prochain cours `nextClass` S M ·rect/ligne ; Prochain examen `nextExam` S M ·rond/rect/ligne ; Devoirs `assignments` S M L ·rect ·I ·P ; Moyenne `gradeAverage` S M L ·P ; Session `semesterProgress` S M ·rond/ligne ; Fiche de révision `flashcard` S M ·I ·P ; Heures d'étude `studyHours` S M L ·P ; Horaire `timetable` S M L ·rect/ligne
- **Voyage** (7) : Départ en voyage `tripCountdown` S M ·rond/rect/ligne ; Vol `flight` S M ·rect ·P ; Hôtel `hotel` S M ·P ; Heure sur place `localTime` S M ·ligne ; Devise `currency` S M ·P ; Avancement du voyage `tripProgress` S M ·rond ·P ; Prochaine activité `nextActivity` S M ·rect ·P
- **Auto** (5) : Coût de la voiture `carCost` S M L ·P ; Prochain entretien `nextService` S M ·rect ; Kilométrage `mileage` S M ·P ; Carburant `fuelStats` S M ·P ; Échéances auto `carDeadlines` S M L ·P
- **Ma vie** (3) : Mon âge `ageProgress` S M ·P ; Décompte `birthday` S M ·rond/ligne ; Prochain jour férié `holiday` S M ·rect/ligne
- **Hors espace** (19, absents de Créer ; accessibles par le Store, les packs, les combinés) : Horloge `clock` S M ; Calendrier `calendar` S M L ; Fuseaux horaires `worldClock` S M ·P ; Progression `progress` S M ·rond/rect/ligne ; Compte à rebours `countdown` S M ·rond/rect/ligne ; L'année en points `yearDots` S M L ·P ; Ma semaine `weekView` S M ; Phase de lune `moonPhase` S M ·rond ; À venir `upNext` S M L ·rect ; Note `note` S M L ; Crypto `crypto` S M ·rect ·P ; Marché crypto `marketOverview` S M ·P ; Ma journée `myDay` M L ·P ; Maintenant `now` S M L ·P ; Ce matin `morning` M L ·P ; Tableau fitness `fitnessDashboard` M L ·P ; Tableau argent `moneyDashboard` M L ·P ; Tableau études `studentDashboard` M L ·P ; Résumé intelligent `aiSummary` S M L ·rect ·P
- Catégories du Store / de « Mes widgets » (`WidgetCategory`, 14) : Tableaux de bord, Temps, Productivité, Habitudes, Nutrition, Fitness, Budget, Placements, Mon entreprise, Sociétés cotées, Planning · études, Voyage, Auto, Photos et citations.
- Précision : le tableau ne montre que `families` du catalogue ; « L » du Studio = `.systemLarge`. Un widget « M L » seulement n'a pas de petit (légende « Moyen · Grand » dans le constructeur).

## 5. Écran verrouillé (`LockScreenCreator`, dans Créer, filtre « Écran verrouillé »)

Parcours : puce « Écran verrouillé » → (1) carte d'intro « Sous l'heure, sans déverrouiller » + « Choisis un widget, règle-le, puis ajoute-le depuis l'écran verrouillé de ton iPhone. Ceux marqués [main] s'utilisent directement : valider une série, cocher une habitude, ajouter un verre… » + lien « Comment l'ajouter » (`lock-guide`, feuille `LockScreenGuide`) ; (2) « Pendant une séance » + badge « Interactif » + aperçu fixe de la séance en direct (`WorkoutActivityView`, fond dégradé 1C2566 → 4A1628) et texte « Dès ta première série validée, ta séance s'affiche sur l'écran verrouillé et dans la Dynamic Island : l'exercice, la série, le repos qui défile. « Série faite » et « Passer » marchent sans déverrouiller. » ; (3) interrupteur « Seulement les widgets interactifs » ; (4) une rangée horizontale par groupe : les 12 espaces (dans l'ordre de l'enum) puis « Général », seulement ceux qui ont des widgets verrouillables ; carte = `LockShowcaseCard` (nom du widget + « Rond » / « Rectangle » / « En ligne », style Minimal, couleur de l'espace). Toucher une carte : ouvre directement le Studio (feuille) sur ce widget, nouveau, au format accessoire (Rectangle de préférence, sinon Rond, sinon En ligne). Pas de choix de taille ici ; on change de forme dans les puces de taille du Studio.
- Limites : une seule teinte (iOS) ; widgets interactifs et séance en direct demandent iOS 17 ; certaines actions peuvent demander Face ID.
- `LockScreenGuide` (« Écran verrouillé », bouton « OK », détentes moyen/grand) : étapes : « Sur l'écran verrouillé, touche et maintiens un espace vide, puis « Personnaliser ». » ; « Choisis « Écran verrouillé », puis touche la zone sous l'heure. » ; « Dans la liste, choisis Ardane, puis le widget voulu. » ; « Touche le widget ajouté pour choisir lequel de tes widgets Ardane il affiche. » ; note « Les widgets interactifs et la séance en direct demandent iOS 17. Si une action ne répond pas, déverrouille ton iPhone : iOS peut demander Face ID pour certaines actions. »
- Nombre de widgets verrouillables : 39 (ceux avec rond / rect / ligne dans le tableau). Aperçu dans le Store : rangée « Écran verrouillé » (`StoreShowcase.lockScreen`).

## 6. Guide « Ajouter un widget » (`AddToHomeScreenGuide`, feuille « Ajouter un widget », bouton « Compris », détente large)

- Ouvertures : après un enregistrement depuis le Store/Mes widgets (auto, 1 widget) ; « Mes widgets » : bouton `questionmark.circle` (« Comment ajouter un widget ») et action « Ajouter à l'écran » (marque le widget comme utilisé) ; Profil › Aide › « Ajouter un widget à l'écran d'accueil » ; fiche d'un écran/pack du Store (« Voir comment les ajouter à l'écran »).
- Titre de contenu : si un widget vient d'être enregistré : « « Nom » est prêt » (icône coche). Sélecteur segmenté « Emplacement » : « Écran d'accueil » / « Écran verrouillé ».
- Écran d'accueil, 5 étapes (icône, numéro) :
  1. « Appuie longuement sur un espace vide de l'écran d'accueil »
  2. « Touche « Modifier » en haut, puis « Ajouter un widget » »
  3. (le widget est le dernier de sa taille) « Cherche « Ardane », puis « Mes widgets », et fais défiler jusqu'à la taille X : « Nom » y est » ; sinon « Cherche « Ardane », puis « Mes widgets » : chaque taille montre ton dernier widget de cette taille »
  4. « Ajoute-le : il garde ce widget, même quand tu en crées d'autres »
  5. (pas dans la galerie) « Une fois ajouté, touche le widget pendant que les icônes bougent et choisis « Nom » » ; sinon « Une fois ajouté, touche le widget pendant que les icônes bougent pour choisir un autre de tes widgets »
- Écran verrouillé, 4 étapes : « Sur l'écran verrouillé, appuie longuement puis touche « Personnaliser » » ; « Choisis « Écran verrouillé » et touche la zone des widgets » ; « Ajoute l'essentiel d'une mini-app Ardane (Nutrition, Fitness, Planning, Finances…) » ; « Touche-le pour choisir ton design ».
- Notes : « Pour changer le contenu d'un widget déjà posé : appui long sur le widget, puis « Modifier le widget ». » ; (verrouillé) « Pour scanner un aliment d'un geste, ajoute « Scanner un aliment » à côté de Nutrition, ou à la place d'un bouton en bas de l'écran verrouillé (iOS 18). Ardane s'ouvre sur le scanner une fois ton iPhone déverrouillé. »
- Carte des étapes : `AddStepRow` (numéro + symbole + texte) dans `.card(padding: 20)`.

## 7. Mes widgets (`MyWidgetsView`, `WidgetCarousel.swift`, `FusionViews.swift`)

- Titre « Mes widgets » (grand). Barre : à gauche « Sélectionner » (si au moins un widget) ; à droite `questionmark.circle` (« Comment ajouter un widget » → guide générique) et `plus` (« Créer un widget » → ouvre le Store, pas Créer).
- État vide (`EmptyStateView`, icône `rectangle.stack.badge.plus`) : titre « Aucun widget pour l'instant », message « Choisis un modèle dans le Store, personnalise-le et enregistre-le. Il apparaîtra ici. », bouton « Ouvrir le Store ».
- Avec widgets, de haut en bas :
  1. « N widget(s) · glisse pour les faire tourner » ;
  2. Carrousel (`WidgetCarousel`, scène 250 pt, page = 60 % de la largeur max 300, les voisins plus petits, inclinés, estompés, qui dépassent) : toucher le widget central ouvre le Studio ; toucher un voisin le ramène au centre ; menu contextuel (appui long) = « Modifier », « Dupliquer », « Créer une variante » (copie puis Studio sur l'onglet Thème), « Favori » / « Retirer des favoris », « Supprimer » (confirmation « Supprimer « nom » ? » / « Les widgets qui l'affichent sur ton écran d'accueil reviendront au modèle par défaut. ») ;
  3. Nom du widget central (title3 gras) + « Catégorie · Taille · i sur N » (un combiné affiche « Combiné · N widgets ») ;
  4. 4 actions rondes 50 pt : « Modifier » (plein, `carousel-edit`), « Dupliquer » (`carousel-duplicate`), « Favori » (cœur plein si favori, `carousel-favorite`), « Ajouter à l'écran » (`carousel-place`, ouvre le guide) ;
  5. « Trouver un widget » + bande de catégories rondes (`CategoryStrip`) : « Tous » (compte), « Favoris » (si ≥ 1), puis les catégories qui ont des widgets, chacune avec pastille de compte ; une catégorie vidée revient à « Tous » ;
  6. Pour un compte gratuit : carte limite « N sur 3 widgets gratuits » + barre de progression + « Photos et citations illimitées » + bouton « Illimité » (paywall `designLimit`).
- Il n'existe pas de « renommer » dans la page : le nom se change dans le Studio (Contenu › Nom). Plusieurs widgets : pas de réorganisation manuelle ; tri = plus récemment utilisé/modifié d'abord.
- Mode sélection (« Sélectionner ») : barre d'onglets masquée ; titre « Sélection » / « N sélectionné(s) » ; « Tout sélectionner » / « Tout désélectionner » à gauche, « OK » à droite ; grille des widgets (petits par deux, moyens/grands pleine largeur) avec rond de coche ; barre du bas : « Touche les widgets à supprimer ou à fusionner », étiquette « Fusion en widget moyen/grand » quand c'est possible, boutons « Fusionner » (plein) et « Supprimer » (rouge) ; confirmation « Supprimer ce widget ? » / « Supprimer ces N widgets ? » → « Supprimer le widget » / « Supprimer les N widgets ».
- Fusion (`FusionSheet`, « Fusionner ») : seulement dans une même catégorie/espace, pas de contenu en double, tailles qui remplissent un moyen ou un grand ; l'ordre de sélection = l'ordre dans le widget ; feuille : « Un widget moyen/grand », « Un vrai widget … pour ton écran d'accueil : dans la galerie de widgets, choisis la taille … », « Contient » (N widgets, « Moitié de ligne » / « Ligne entière »), interrupteur « Garder aussi les widgets d'origine », « Aucune information n'est perdue : chaque widget garde tout son contenu. Le widget fusionné reste personnalisable dans l'éditeur (style, couleur, fond, police). » ; animation `FusionOverlay` (les cartes se rassemblent). Premium requis si le résultat utilise du Premium ou dépasse la limite.
- Limite gratuite : 3 widgets (`freeDesignLimit`), photos et citations exclus ; qui en a déjà plus les garde tous.
- Habitudes : limite gratuite 5 (`freeHabitLimit`).

## 8. Store (`ExploreView`, onglet « Store »)

- Titre « Store » ; barre de recherche (`searchable`) : placeholder « Écrans, packs, lune, bitcoin… ».
- En haut : rangée de puces d'allées (`aisleBar`, icône + titre, scroll vers l'allée) ; puis 8 allées l'une sous l'autre, chacune avec un en-tête (`AisleHeader`, couleur de l'allée, titre + phrase + « Tout voir » si dispo) et une ou deux rangées défilantes. Allées dans l'ordre (titre, couleur, phrase) :
  1. « À la une » (F2A33A) : « La sélection de la semaine : un écran, un style et des widgets à découvrir. » ; contenu : collection de saison si elle existe (`SeasonalCollection`), date en majuscules, héros « écran de la semaine » (`WeeklySetupHero`), style de la semaine (`WeeklyStyleFeature`), rangée « À découvrir cette semaine ».
  2. « Écrans d'accueil » (3366FF) : « Des écrans d'accueil complets : widgets et fond d'écran assortis. » ; une rangée de `SetupCard` (150 pt, coeur favori, cadenas) ; « Tout voir » → `HomeSetupsView` (« Écrans d'accueil », filtres « Tous » / « Favoris », intro « Des écrans complets : fond d'écran, widgets et écran verrouillé assortis. Touche-en un pour l'installer. », vide « Aucun favori » / « Touche le cœur sous un écran pour le retrouver ici. » ou « Aucun écran » / « Essaie un autre filtre. » + « Tout afficher »). Toucher un écran : feuille `HomeSetupSheet` (nom, sélecteur « Écran » Accueil/Verrouillé, « N widgets inclus », « Aussi pour l'écran verrouillé : … », « Fond d'écran · … » avec « Enregistrer dans Photos » ; bouton « Ajouter les N widgets » / « Débloquer avec Premium » / « Voir comment les ajouter à l'écran » ; « Widgets ajoutés à Mes widgets » ; « Fermer »).
  3. « Fonds d'écran » (0F9BB0) : « Des fonds d'écran dessinés pour Ardane : mer, noir et blanc, dégradés, nuit, forêt et cosmos. » ; `WallpaperStoreSection` : humeurs Mer et vagues, Noir et blanc, Dégradés doux, Nuit et orage, Forêt et brume, Cosmos ; miniature en forme d'écran, badge Premium sur environ deux tiers (1/3 gratuit). Enregistre dans Photos.
  4. « Widgets » (2F8F7A) : « Un widget à la fois, rangé par thème : temps, santé, argent… » ; rangées « Incontournables » (6 widgets de 6 catégories) et « Écran verrouillé » (cartes verrouillées). Toucher : Studio, widget neuf.
  5. « Combinés » (6D4AE8) : « Plusieurs widgets réunis en un seul, prêts à poser. » ; 2 rangées (moyens à 140 pt, grands à 250 pt) de `ComboCard` ; « Tout voir » → `StoreCombosView`. Toucher : Studio.
  6. « Packs » (E5484D) : « Des ensembles de widgets pour un usage : études, sport, voyage… » ; 2 rangées de `PackCard`, pack de la semaine d'abord ; « Tout voir » → `StorePacksView` ; toucher : feuille `PackSheet` (nom, accroche, grille de widgets, « Les widgets marqués « Exemple » montrent des données d'exemple. Tu donneras les tiennes dans le Studio, widget par widget. », bouton « Personnaliser et ajouter » ou « Débloquer avec Premium », « Fermer ») qui pousse le Studio pour tous les widgets.
  7. « Packs thématiques » (1E88C8) : « Un univers par pack : espace, Mars, nature, plantes et océan, avec son écran d'accueil assorti. » ; packs thématiques + rangée « Les écrans d'accueil assortis ».
  8. « Styles » (D6409F) : « Le même widget dans chaque style : choisis l'allure qui te plaît. » ; « Touche un style pour voir tous ses widgets. » ; grille 2 lignes de 57 `ThemeSwatch` (76 pt, « Aa » dans la police du style, cadenas si Premium) ; toucher = filtre par style.
- Recherche / filtres (`isFiltering` : texte, accès, style ou catégorie) : la liste d'allées est remplacée par des résultats : rangée de filtres « Tous », « Gratuits », « Premium » | puce du style actif (croix) | puce de catégorie (croix) | autres catégories (14) ; sections « Écrans d'accueil » (par mots seulement), « Combinaisons », « Packs », « Widgets » (grille à 2 colonnes). Vide : icône `magnifyingglass`, « Aucun résultat », « Essaie un autre mot, ou retire un filtre. », « Tout afficher ».
- Premium : cadenas / badge sur les cartes (widgets, combinés, packs, écrans, styles, fonds) ; l'action Premium (packs, écrans) mène au paywall avec contexte. Un widget gratuit à style Premium s'ouvre quand même dans le Studio (avis jaune, blocage à l'enregistrement).
- Pas d'état vide hors recherche/filtre. Pas de prix affichés dans le Store.
- Nombre d'écrans, packs, combinés : non compté (à vérifier : `HomeSetupCatalog`, `PackCatalog` 33 occurrences `WidgetPack(`, `StoreComboCatalog`).

## 9. Premium (`App/Premium/PaywallView.swift`, `PaywallContext.swift`, `PremiumConfiguration.swift`, `PremiumStore.swift`, `PremiumLock.swift`)

- Feuille `PaywallView` (bouton fermer `xmark` en haut gauche, étiquette « Fermer »). Sans contexte :
  - Héros : `ArdaneMark` 56 pt, « Ardane Premium » (largeTitle), « Tous les widgets, tous les styles, sans limite. » ; rangée de 5 aperçus de widgets (focus-futuristic, money-net, world-futuristic, dots-glass, calendar-elegant, 130 pt, masqués à VoiceOver).
  - Avec contexte (`PaywallContext`) : petite marque + « Ardane Premium », icône dans un carré `premiumFill`, titre du contexte, détail, aperçu du/des widgets tels qu'ils seront, puis « Et avec Premium, tout le reste : ».
- Avantages (carte, 7 lignes ; celle du contexte est remontée en tête sur fond `premiumFill`) :
  1. « Tous les widgets des espaces » — Records, volume, bénéfice, MRR, devoirs, vol, carburant…
  2. « Widgets intelligents » — « Maintenant » change selon le moment, et les analyses résument ta journée
  3. « Tous les packs » — Packs thématiques, collections Halloween et Noël, Étudiant, Sportif, Voyageur…
  4. « 47 styles en plus » (calculé) — Les 11 autres couleurs de l'app, Espace, Mars, Océan, Aurore, Élégant, Synthwave…
  5. « Statistiques détaillées » — Historique et tendances de tes repas, progression de tes charges, évolution de tes finances et de ton entreprise, régularité de tes habitudes
  6. « Toute la bibliothèque d'exercices » — N exercices avec démonstration, technique et alternatives
  7. « Fonds photo, couleurs libres » — Et les polices Serif et Mono
- Offres (`PlanCard`, 3 produits possibles, sélection par défaut = annuel) : mensuel `com.dakrsnyk.ardane.premium.monthly`, annuel `…yearly`, à vie `…lifetime` (l'achat à vie n'est montré que si l'App Store le propose ; aucun au lancement, décision du 2026-11-08). Nom = `displayName` StoreKit. Pastille : « Essai gratuit » si essai ; sinon annuel « −N % » ; à vie « Paiement unique ». Sous-titre : essai « N jour(s) gratuit(s), puis 6,99 $ par mois » (format `periodText` : « … par mois / par an / par semaine / par période ») ; annuel « 59,99 $ pour 12 mois, soit X par mois » ; mensuel « X par mois » ; à vie « X, une seule fois, sans abonnement ». Les prix viennent de `Product.displayPrice` (les montants 6,99 / 59,99 $ ne sont que des exemples du code, pas des constantes ; à vérifier dans App Store Connect).
- États de chargement : « Chargement des offres… » (spinner) ; échec : icône `wifi.exclamationmark`, message, « Réessayer ».
- Barre d'achat fixe (`.bar`) : texte d'avertissement du plan choisi (`terms`) ; bouton plein 52 pt « Essayer N jours gratuits » (si essai) ou « Continuer » ; « Restaurer mes achats » (« Restauration… » pendant l'opération) ; alerte « Achat » (« Bienvenue dans Ardane Premium ! », ou « Ton achat est en attente d'approbation. Premium s'activera dès qu'il sera validé. »).
  - Terms essai : « … Rien n'est débité pendant l'essai. Renouvellement automatique chaque année/chaque mois, annulable à tout moment. L'essai gratuit ne vaut qu'une fois par compte Apple. » ; sans essai annuel : « X débités aujourd'hui pour 12 mois. Renouvellement automatique chaque année au même prix, annulable à tout moment. »
- Tableau « Gratuit » / « Premium » : Types de widgets (gratuits calculés : 32 / 95), Couleurs de l'app (1 / 12), Styles (10 / 57), Widgets enregistrés (3 / ∞), Photos et citations (∞ / ∞), Habitudes (5 / ∞), Exercices (— / N), Statistiques détaillées (— / ✓), Couleurs (8 / ∞), Fonds et polices (— / ✓).
- Mentions légales (bas de page) : paragraphe « Les abonnements se renouvellent automatiquement, sauf annulation au moins 24 h avant la fin de la période en cours. Le paiement est débité sur ton compte Apple. Tu peux gérer ou annuler l'abonnement dans les réglages de ton compte App Store. L'essai gratuit s'applique une seule fois par compte ; s'il n'est pas annulé au moins 24 h avant sa fin, l'abonnement est débité au prix normal. » (+ « L'achat à vie est un paiement unique, sans renouvellement. » si l'offre existe) ; liens « Conditions » et « Confidentialité ».
- État déverrouillé : plus de barre d'achat ni de plans ; carte « Tu profites de Premium » + « Merci ! Tous les widgets et tous les styles sont débloqués. » (icône `checkmark.seal.fill`).
- Contextes (`PaywallContext`) : designs (« Débloque ce widget » / « Débloque ces widgets »), designLimit (« Plus de 3 widgets »), habitLimit (« Plus de 5 habitudes »), scheduleImport (« Importer mon horaire »), photoScanLimit (« Analyses de plat illimitées »), financesHistory (« Tes mois passés »), exerciseLibrary, fitnessProgress (« La progression est dans Premium »), setup (« L'accueil « … » »), pack (« Le pack « … » »), + couleurs de l'app (« Toutes les couleurs de l'app » — « Avec Premium, choisis la couleur d'Ardane parmi 12 et change-la quand tu veux. Saphir reste gratuit. »).
- D'où elle s'ouvre : bannière `PremiumBanner` de l'Accueil (titre « Ardane Premium », « N widgets en plus, N styles, analyses et fonds photo. », visible tant que non abonné), Profil (« Passer à Premium »), Studio (« Débloquer », pied « Débloquer et enregistrer »), cartes verrouillées de mini-apps (`PremiumLockCard` : « Découvrir Premium »), fiches de packs/écrans du Store, grille des couleurs de l'app, sélecteur d'icône, limite de widgets/habitudes (18 appels `showPaywall`/`isPaywallPresented`).
- Marqueurs : `PremiumBadge` (capsule `premiumFill` F6E7B8 clair / 4A3B12 sombre, texte `premiumInk` 7A5500 / F2D27A, icône `sparkles` + « Premium » ; `compact` = icône seule) ; cadenas `lock.fill` couleur `premiumInk` dans les grilles (Builder, Studio, Store). Le badge disparaît une fois Premium. Les versions de test : Premium débloqué par défaut (`INTERNAL_PREMIUM` / DEBUG) : voir captures avec soin (aucun badge).

## 10. Profil (feuille `ProfileView`, ouverte par l'avatar de l'Accueil ; `Form` groupé, titre « Profil » inline, « OK »)

De haut en bas :
1. En-tête (sans fond) : `ProfileAvatar` 78 pt (initiales ou `person.fill`, dégradé accent), nom (« Ton profil » si vide), « Ardane Premium » (sparkles, `premiumInk`) ou « Version gratuite » (person) ; trois tuiles : N widget(s), N habitude(s), N « espaces actifs ».
2. « Mon profil » : « Prénom » (« Facultatif »), « Nom », « Anniversaire » (sélecteur ou « Ajouter mon anniversaire »), « Centres d'intérêt » (lien : grille ; « Aucun » / N choisis), « Jours fériés » (région). Pied : « Ton nom, ton anniversaire et tes centres d'intérêt restent sur ton iPhone. Tes autres informations (poids, objectifs, budget…) se modifient dans « Mes informations », sur l'accueil. »
3. Premium : abonné : « Premium actif » + détail (« Accès à vie », « Renouvellement le … », « Abonnement actif », « Débloqué en mode test ») + « Gérer l'abonnement » (si abonnement) ; non abonné : « Passer à Premium » / « Tous les widgets et tous les styles » → paywall. Dans les deux cas : « Restaurer les achats » (spinner).
4. « Apparence » : grille de 12 couleurs d'app (4 colonnes, pastilles 48 pt, `AppStyleGrid`), puis contrôle segmenté « Mode » : « Auto » (clé `Auto [mode]`), « Clair », « Sombre » (`AppearancePicker`). Pied : « <Nom> — <accroche>. Tes widgets gardent chacun leur propre style. »
   - 12 couleurs : Cobalt, Saphir, Bleu glacier, Aqua, Jade, Pistache, Olive, Ambre, Rubis, Rose, Orchidée, Améthyste. Gratuite : SAPHIR seulement (défaut) ; les 11 autres Premium (cadenas, paywall « Toutes les couleurs de l'app »). Un compte gratuit voit Saphir même si une autre est enregistrée. Rubis, Rose, Orchidée utilisent une police arrondie. Accroches : Cobalt « Bleu profond, net et franc », Saphir « Bleu acier, sobre et élégant », Bleu glacier « Frais et lumineux », Aqua « Turquoise vif, comme l'eau claire », Jade « Vert jade, l'original », Pistache « Vert tendre et naturel », Olive « Vert doré, terreux et calme », Ambre « Chaud, comme un soir d'été », Rubis « Rouge intense, plein de vie », Rose « Tendre et affirmé », Orchidée « Doux et raffiné », Améthyste « Violet profond, pour les couche-tard ».
5. « Préférences » : « Icône de l'app » (+ `PremiumBadge` si gratuit ; `AppIconPicker`), « Heure sur 24 h », « Unités », « Devise (flux d'argent) », « Devise (crypto) ».
6. « Notifications » : « Autorisation » (Autorisée / Refusée / Pas encore demandée), « Rappels intelligents », « Rappels d'habitudes », « Ouvrir les réglages de l'iPhone » (si refusée). Pied sur les autorisations.
7. « Tes données » : Tâches, Habitudes, Revenus et dépenses, Calendrier, Autorisations.
8. « Aide » : « Ajouter un widget à l'écran d'accueil » (guide, section 6), « Revoir le tutoriel » (ferme le profil puis relance), « Noter Ardane », « Me proposer de noter Ardane » (interrupteur), « Contacter le support » (copie l'e-mail, « Copiée »).
9. « À propos » : « Confidentialité », « Conditions d'utilisation » ; pied « Ardane <version> (<build>) », « Cours crypto : CoinGecko. », « Tes données restent sur ton iPhone. Aucun compte, aucun suivi publicitaire. »
10. « Sources des données alimentaires » : Open Food Facts (ODbL, DbCL), Fichier canadien sur les éléments nutritifs, USDA FoodData Central, « Reconnaissance des aliments » (CC BY 4.0).
11. « Sauvegarde » : « Exporter mes données », « Restaurer une sauvegarde » (confirmation « Remplacer tes données par cette sauvegarde ? »).
12. « Effacer toutes mes données » (rouge, confirmation « Effacer toutes tes données ? » → « Tout effacer »).
13. DEBUG seulement, jamais Release : section « Développeur ».
- Le Profil ne contient pas la fiche des cibles nutritionnelles ; `profile-targets.png` montre l'écran Nutrition, pas le Profil (la capture est mal nommée). `NutritionTargetsCard`, `ProfileTopics`, `SmartRemindersView`, `PermissionsSettingsView` sont des sous-pages.

## 11. Fichiers et vues pour l'intégration

| Écran | Fichier | Vue (struct) |
|-|-|-|
| Onglets | `App/ArdaneApp.swift` | `MainTabView`, `RootView` (feuilles Studio, paywall, profil, guide) |
| Créer, liste | `App/Screens/Spaces/SpacesView.swift` | `SpacesView`, `ImmersiveSpaceCard`, `PhotoQuotesCard`, `ImmersiveCard` (privée), `SpaceView`, enum `SpaceUniverse`, `SpaceCatalog` |
| Constructeur | `App/Screens/Spaces/SpaceBuilderView.swift` | `SpaceBuilderView`, `BuilderSelection` |
| Composition S/M/L | `Shared/Model/Combo.swift` | `WidgetFormat`, `Composer`, `Fusion` |
| Écran verrouillé | `App/Screens/Spaces/LockScreenCreator.swift` | `LockScreenCreator`, `LockScreenGuide` ; `LockShowcaseCard` dans `Explore/StoreShowcase.swift` |
| Données d'un espace | `App/Screens/Spaces/SpaceSheets.swift` (+ `*Space.swift`) | `SpaceSheets` |
| Studio | `App/Screens/Editor/EditorView.swift` | `EditorView`, `WidgetStudio`, `ComboPartSettingsView`, `EditorSection`, `ColorDot`, `BackgroundKind` |
| Studio, barre et scène | `App/Screens/Editor/StudioComponents.swift` | `StudioSection`, `StudioSectionBar`, `StudioStage`, `StudioGroup`, `StudioNote`, `StudioChoices`, `StudioSlider`, `StudioColorRow`, `StudioPreviewTile` |
| Studio, panneaux | `App/Screens/Editor/StudioPanels.swift` | `StudioElementsPanel`, `StudioThemePanel`, `StudioStylePanel`, `StudioColorsPanel`, `StudioBorderPanel`, `StudioChartPanel`, `StudioDensityPanel`, `StudioMyStylesPanel`, `ApplyStyleSheet`, `StudioPreviewGrid` |
| Studio, réglages par widget | `KindOptionsSection.swift`, `SpaceOptionsSection.swift` | `KindOptionsSection`, `SpaceOptionsSection`, `CityPickerView`, `CalendarAccessRow` |
| Vol d'enregistrement | `App/Components/SaveFlight.swift` | `SaveFlight`, `SaveFlightOverlay` |
| Guide d'ajout | `App/Screens/Editor/AddToHomeScreenGuide.swift` | `AddToHomeScreenGuide` (`AddStepRow` à localiser) |
| Photos et citations | `App/Screens/MiniApps/Photos/PhotoQuotesApp.swift` | `PhotoQuoteEditor` |
| Mes widgets | `App/Screens/MyWidgets/MyWidgetsView.swift`, `WidgetCarousel.swift`, `FusionViews.swift` | `MyWidgetsView`, `WidgetCarousel`, `CarouselAction`, `CategoryStrip`, `FusionSheet`, `FusionOverlay` |
| Store | `App/Screens/Explore/ExploreView.swift` | `ExploreView` (+ `StoreAisle`, `AisleHeader`, `ThemeSwatch`, `PackSheet`, `FilterChip`) |
| Store, détails | `HomeSetupViews.swift`, `StoreMagazine.swift`, `StoreCombos.swift`, `StoreShowcase.swift`, `WallpaperCollection.swift`, `HomeSetups.swift`, `SetupWallpapers.swift` | `SetupCard`, `HomeSetupsView`, `HomeSetupSheet`, `WeeklySetupHero`, `WeeklyStyleFeature`, `SeasonalCollection`, `PackCard`, `StorePacksView`, `StoreCollectionsView`, `ComboCard`, `StoreCombosView`, `WallpaperStoreSection` |
| Premium | `App/Premium/PaywallView.swift` | `PaywallView`, `PlanCard` (privée) |
| Contextes d'offre | `App/Premium/PaywallContext.swift`, `PremiumConfiguration.swift`, `PremiumStore.swift`, `PremiumLock.swift` | `PaywallContext`, `PaywallPerk`, `PremiumStore`, `PremiumLockCard` |
| Marqueurs Premium | `App/Components/UIComponents.swift` | `PremiumBadge`, `Color.premiumFill/premiumInk`, `InteractiveBadge`, `ExampleBadge` (`DataItemViews.swift`), `EmptyStateView`, `TemplateCard`, `CardBackground` (`.card()`) |
| Bannière Premium | `App/Screens/Home/HomeView.swift` | `PremiumBanner` |
| Profil | `App/Screens/Profile/ProfileView.swift` | `ProfileView`, `ProfileAvatar` |
| Couleurs et mode de l'app | `App/Components/StylePicker.swift`, `Shared/Theme/AppStyle.swift`, `Shared/Model/Settings.swift` | `AppStyleGrid`, `AppStyleSwatch`, `AppearancePicker`, `AppStyle`, `AppStyleID`, `AppearanceMode` |
| Icône de l'app | `App/Screens/Profile/AppIconPicker.swift` | `AppIconPicker` |
| Catalogue, thèmes, styles | `Shared/Model/KindCatalog.swift`, `WidgetKind.swift`, `Shared/Theme/Theme.swift`, `Palette.swift`, `Shared/Model/WidgetStyle.swift`, `StyleColors.swift`, `WidgetDesign.swift` | `Space`, `KindCatalog`, `ThemeCatalog`, `Palette`, `StylePreset`, `ColorPalette`, `ChartKind`, `Density`, `BorderKind`, `TextureKind`, `FontChoice` |
| Limite gratuite | `App/Core/AppModel.swift` | `AppModel.freeDesignLimit` = 3, `freeHabitLimit` = 5 |

## 12. Constats utiles au design

- Créer n'entre aujourd'hui pas dans le Studio : liste (13 cartes) → constructeur (taille + choix de widgets) → Studio poussé. Pour arriver dans le Studio avec un widget choisi, le plus proche est `router.openEditor(design, isNew: true)` (feuille `EditorView`, utilisé par l'écran verrouillé et le Store) ; il perd la composition Moyen/Grand de plusieurs widgets (réservée au constructeur, `Composer`).
- 9 outils réels (8 si pas de graphique) : Contenu, Thème, Style, Couleurs, Fond, Bordure, Graphique, Densité, Mes styles. Aucun outil Police, Forme, Texte, Icône, Ombre séparé : ces choix vivent dans les 57 styles et 16 thèmes. Les maquettes ne doivent pas en inventer.
- La scène du Studio est un cadre gris-bleu avec l'aperçu et des puces de taille (Petit/Moyen/Grand + Rond/Rectangle/En ligne) ; il n'y a pas d'aperçu sur fond d'écran, ni de zoom.
- Gratuit réel : 32 widgets, 10 styles, 8 couleurs principales, fond « Style », densité et graphique (réglages d'apparence), contenu, noms, 3 widgets enregistrés, 1 couleur d'app (Saphir). Premium : Fond (Couleur, Dégradé, Verre, Photo), Texture, Bordure, Palettes, Chaque couleur, couleur libre, 47 styles, 11 couleurs d'app, icône d'app, polices Serif/Mono, 63 widgets, packs/écrans/fonds Premium, bibliothèque d'exercices, historique.
- Le Store a 8 allées sans prix ; les achats ne passent que par le paywall.
