---
tags: [ardane, memoire]
---

# Demandes

Exécution autonome : réaliser TOUS les lots ci-dessous, dans cet ordre, sans attendre mon accord entre deux lots :
1. Harmonisation des mini-apps (§2)
2. Planning et widget Planning (§3)
3. Habitudes, puis Productivité dans Mon Quotidien (§10, §12)
4. Store : fonds d'écran (§4)
5. Nutrition : sources de données (§5) : rapport de licences d'abord, puis intégrer seulement les sources dont la licence commerciale est claire ; les autres sont laissées de côté et signalées
6. Fitness : calcul des calories (§7)
7. Permissions iOS et réactivité (§8, §9)
8. Nutrition : scanner alimentaire intelligent (§5), en deux étapes décrites plus bas

Pour chaque lot : découper en tâches pour les agents, relire avec code-reviewer, corriger les bloquants, lancer python3 scripts/check_swift.py, puis commit local avec [check], puis [unit] pour les tests. Autorisé sans me redemander : commits et push de [check] et de [unit]. Après chaque lot : cocher la ligne dans « À faire » avec la date, mettre à jour docs/memoire/Chantiers.md (état et reste à faire, pour pouvoir reprendre après une interruption), et noter les captures à vérifier.

Règles :
- Fonctionnalités existantes préservées ; accueil, barre du bas, date et personnalisation de Mon Quotidien inchangés.
- Références visuelles dans docs/references/ (voir son README) ; les fonds sont des créations originales, jamais une copie de Pinterest.
- Si un lot est bloqué (licence, service externe, test qui échoue sans cause trouvée) : le noter, passer au lot suivant, et ouvrir le rapport final par ce blocage.
- Ne jamais effacer de données de l'utilisateur ni casser les anciennes données sauvegardées.
- [testflight] puis [interne] : une seule fois, après le dernier lot, seulement si tous les [unit] sont verts.
- Rapport final : changements par lot, tests, blocages, services externes nécessaires, ce qui reste à vérifier sur l'iPhone.

À faire avec les agents (demandé le 2026-10-23) :
- [x] **Widget Anniversaire → Décompte** (fait le 2026-10-23, à vérifier sur l'iPhone). Généraliser le widget « Anniversaire » : une fois choisi dans l'éditeur, la personne choisit directement la date et le nom (plus seulement un anniversaire). Le widget s'appelle « Décompte » ; nom et date personnalisables (par défaut : « Anniversaire » et la date de naissance du profil quand elle est connue) ; option « chaque année » pour que l'ancien comportement d'anniversaire reste possible. Les widgets déjà posés et les designs sauvegardés (`WidgetKind.birthday`) restent lisibles et gardent leur rendu. Même rendu dans les tailles actuelles (petit, moyen, rond, ligne) et dans l'éditeur ; le widget « Compte à rebours » existant (`countdown`) ne doit pas être cassé : dire dans le rapport s'il double le nouveau, sans le supprimer. Traductions (6 langues) pour les textes nouveaux.
- [x] **Widget « Semaine d'habitudes » indisponible → le rendre disponible** (fait le 2026-10-23, cause : grisé en taille Petit dans le créateur d'espace). Dans la section Habitudes (galerie, éditeur, Mes widgets), le widget « Semaine d'habitudes » (`habitWeek`) n'est pas disponible. Trouver pourquoi (verrou Premium, tailles, aperçu vide, absent d'un écran de la galerie, rendu manquant) et faire en sorte qu'il puisse être choisi, prévisualisé et posé comme les autres widgets d'Habitudes.

Scanner (lot 8) :
- Étape A, à réaliser entièrement : détection automatique code-barres ou plat sans choix du mode ; code-barres lu sur l'appareil, produit cherché dans Open Food Facts (licence et attribution vérifiées) et dans les bases locales de l'app ; photo d'un plat analysée sur l'appareil (Vision d'Apple), avec ingrédients et quantités proposés comme ESTIMATIONS ; récapitulatif modifiable (ajouter, supprimer, remplacer un aliment, ajuster les portions) avant validation ; valeurs vérifiées distinguées des estimations, incertitudes signalées, jamais de donnée inventée présentée comme exacte ; enregistrement dans le journal sans doublon, calories, macros et objectifs mis à jour ; solution de secours quand le produit est introuvable ou l'analyse échoue ; permission caméra expliquée avant la demande système.
- Étape B, préparée mais DÉSACTIVÉE : analyse de photo par une IA en ligne. Prévoir l'interface (un fournisseur d'analyse remplaçable) et ne rien envoyer hors de l'appareil. Elle ne s'active qu'après ma décision sur le service, le coût, le serveur et la politique de confidentialité. Aucune clé ni secret dans l'app ou sur GitHub.

Retour : [[Memoire]]

## À faire

- [ ] Premium Nutrition : « Faire mes repas » sous le compteur calorique (questionnaire de goûts, budget, magasin, liste de courses d'un seul magasin, provenance et date des prix) (§6).

## Idées pour plus tard

## Fait

- [x] **Toutes les mini-apps : même structure, avec le sélecteur de semaine** (demandé le 2026-10-22). Pour les agents : appliquer à CHAQUE mini-app (Nutrition, Fitness, Planning, Finances, Business, Voyage, Auto, Météo ; Photos et citations n'a aucun contenu daté : sans sélecteur, ses blocs suivent le même ordre) l'ordre suivant, de haut en bas :
  1. **Sélecteur de semaine** (composant partagé `WeekSelector`) : les 7 jours côte à côte, initiale du jour et date dans un cercle ; jour sélectionné sur un fond arrondi de la couleur d'accent de la mini-app ; jours passés, jour sélectionné, aujourd'hui et jours à venir visuellement différents ; toucher un jour le sélectionne ; navigation entre les semaines (flèches et balayage) ; dates calculées d'après le vrai calendrier. UN SEUL sélecteur de dates par écran.
  2. **Informations essentielles** tout de suite après : le contenu prioritaire du jour sélectionné (Fitness : la séance ; Nutrition : calories et macros ; Finances : solde et dépenses…).
  3. **Contenu complémentaire** : statistiques, historiques, objectifs, fonctions secondaires, par ordre d'importance.
  4. **Autres catégories et réglages en dernier** : options avancées, « Mes infos », paramètres.
  **Règle impérative : aucun doublon.** Chaque information, carte, indicateur, bouton ou section n'apparaît qu'une fois par écran (sauf si la répétition est indispensable au fonctionnement) : pas de double sélecteur de dates, pas de résumé répété, pas la même information dans plusieurs cartes. Réutiliser les composants existants (`MiniStyle`, `.miniCard()`, `MiniSectionTitle`, `MiniRowsCard`, `MiniStat`, `MiniFootnote`, `MiniActionButton`) plutôt que d'en recréer. Conserver les fonctionnalités, le style d'Ardane et les `accessibilityIdentifier` des UITests ; aucun texte visible nouveau sans traduction (`l10n`). L'image de référence du sélecteur n'était pas jointe à la demande : le dessin suit la description ci-dessus ; l'ajuster si l'utilisateur renvoie l'image.
  Fait le 2026-10-22 (compilé : run 232 ; tests : run 233, 445 réussis, 0 échec). Le dessin du sélecteur suit l'image de référence reçue (initiales grises, cercles pleins pour les jours qui ont du contenu et pointillés sinon, chiffres atténués à venir, fond arrondi teinté du jour choisi). Résultat par écran : voir `Chantiers.md`.

Programme des 8 lots du 2026-10-22 (code écrit et relu, jamais compilé : CI bloquée par la facturation GitHub) :
- [x] Mini-apps : même organisation partout (sélecteur de jours en haut, bloc principal, bloc secondaire, paramètres et infos en bas), composants harmonisés, doublons retirés (§2). (écrit le 2026-10-22 ; compilation et tests non vérifiés : CI bloquée)
- [x] Planning : présentation façon Calendrier Apple, vues semaine / mois / année (pincement si fiable, sinon contrôle explicite) ; widget Planning qui remplit toute sa surface (§3). (écrit le 2026-10-22 ; compilation et tests non vérifiés : CI bloquée)
- [x] Store : grande collection de fonds d'écran originaux (gratuits, les meilleurs en Premium), sous les écrans d'accueil personnalisés ; nouveaux packs et styles ; droits vérifiés (§4). (écrit le 2026-10-22 ; compilation et tests non vérifiés : CI bloquée)
- [x] Nutrition : sources USDA, FCÉN, BEDCA, UniTools World Recipes, ForkRecipe (licences d'abord, provenance gardée, pas de doublons, recettes calculées sans inventer) (§5). (écrit le 2026-10-22 ; compilation et tests non vérifiés : CI bloquée)
- [x] Nutrition : scanner alimentaire intelligent, lot 8 (§5) : étape A complète (code-barres et plat estimé sur l'appareil, récapitulatif modifiable, sans doublon) ; étape B (IA en ligne) préparée mais désactivée. (écrit le 2026-10-22 ; compilation et tests non vérifiés : CI bloquée)
- [x] Fitness : revoir le calcul des calories (MET, durée, poids, intensité, repos), éviter les doubles comptes avec Santé, tests (§7). (écrit le 2026-10-22 ; compilation et tests non vérifiés : CI bloquée)
- [x] Permissions iOS : seulement le nécessaire, explication avant la demande système, refus respectés (§8). (écrit le 2026-10-22 ; compilation et tests non vérifiés : CI bloquée)
- [x] Réactivité : retour immédiat sur chaque bouton, pas de double action, haptique là où iOS le permet (§9). (écrit le 2026-10-22 ; compilation et tests non vérifiés : CI bloquée)
- [x] Habitudes : refonte visuelle d'après les images jointes, sans toucher aux autres sections (§10). (écrit le 2026-10-22 ; compilation et tests non vérifiés : CI bloquée)
- [x] Mon Quotidien : ajouter Productivité (prendre l'habitude d'une tâche rapide) (§12). (écrit le 2026-10-22 ; compilation et tests non vérifiés : CI bloquée)

Accueil, maquette D choisie le 2026-10-22 (compilée en CI, run 221 ; à vérifier sur l'iPhone par TestFlight) :
- [x] Accueil : mixte des maquettes A et C (dégradé léger par catégorie d'après « Séance du jour », sans image de fond ; séance « Maintenant » en tête l'après-midi ; habitudes en anneaux avec la série de jours ; courbe des 7 derniers jours dans Budget). Barre du bas, date et personnalisation de Mon Quotidien inchangées (fait le 2026-10-22).

Série du 2026-10-22 (compilée en CI, run 219 ; à vérifier sur l'iPhone par TestFlight) :
- [x] Fitness : vrai « Skip » de la série en cours (ignorée, jamais comptée, sans repos), sans double incrément ; « Annuler » défait aussi un « Passer » ; boutons de l'écran verrouillé, de la Dynamic Island, des widgets et de l'app ; retour haptique léger seulement si le bouton est accepté et l'app au premier plan (un widget ne peut pas faire vibrer l'iPhone seul) ; ajout rapide Nutrition sans doublon (fait le 2026-10-22).

Suite du 2026-10-17 :
- [x] Finances : toucher le solde ouvre un relevé façon compte bancaire (tous les mouvements par date, solde après chacun) ; « Chaque mois » et « Tes principales dépenses » retirés de Mes infos de Finances ; ligne « Dépenses fixes » sous « Évolution » (fait le 2026-10-17).
- [x] Fitness : supprimer une séance enregistrée (historique, détail, carte du jour, Mon Quotidien) ; elle ne compte plus et peut être refaite (fait le 2026-10-17).

Série du 2026-10-17 (à vérifier sur l'iPhone par TestFlight) :
- [x] Fitness : petite flèche retour (écran verrouillé, Dynamic Island, widgets, app) pour annuler la dernière série ; sans série, une croix annule la séance lancée par erreur ; une séance annulée n'est jamais comptée (fait le 2026-10-17).
- [x] Études : le chrono d'étude crée une activité en direct du même style que Fitness (temps qui défile, total de la semaine, Terminer, Annuler) (fait le 2026-10-17).
- [x] Encouragements : repas (reste de calories, glucides/protéines), séance terminée, record, longue étude, objectifs de la semaine, séries d'habitudes ; 2 par jour au plus, 3 h d'écart, jamais entre 22 h et 8 h ; réglable dans Profil › Rappels (fait le 2026-10-17).
- [x] Business : le CSV de l'utilisateur (colonne « type » revenu/depense, montants positifs) est lu correctement : 7 dépenses, 5 revenus ; débit/crédit, retrait/dépôt, DR/CR, signes et exports de banques, PayPal, Stripe… ; réimporter le fichier corrige l'import erroné ; opérations « à payer »/« prévu » incluses par défaut avec un interrupteur (fait le 2026-10-17).

Série du 2026-10-16 (à vérifier sur l'iPhone par TestFlight) :
- [x] Business : conversion automatique dans la devise de l'app à l'import d'un fichier et à la synchro Stripe, au taux de référence de la BCE du jour de chaque opération ; montant d'origine gardé ; sans taux, rien n'est importé sans ton choix (« Importer / Synchroniser sans conversion ») (fait le 2026-10-16).
- [x] Widgets cryptos, actions, Liste de suivi, Portefeuille : variation « ▲ +1,45 % · 24 h » (cryptos) ou « · jour » (actions, depuis la clôture), heure du cours, rechargement toutes les 15 min environ (le rythme réel est décidé par iOS) (fait le 2026-10-16).
- [x] Gratuit : 3 widgets ; photos et citations illimitées (elles ne comptent pas) ; un pack de plus de 3 widgets enregistre ceux qui rentrent, les autres portent un cadenas (fait le 2026-10-16).
- [x] Fitness, Progression : exercices de A à Z avec un alphabet à gauche, à toucher ou glisser (fait le 2026-10-16).
- [x] Planning : la salle du cours sur le grand horaire de la semaine (app, Mon Quotidien et widget) quand le bloc a la place (fait le 2026-10-16).
- [x] Mode Clair (iOS 26) et Teinté : tous les widgets dessinés sans couleurs par opacités, formes sous le texte légères et contournées (fini les blocs blancs), photos en couleur. À vérifier sur l'iPhone en Clair clair/sombre et en Teinté (fait le 2026-10-16).

- [x] Fitness : toute la bibliothèque d'exercices et les données de chaque exercice en Premium ; gratuit : séances, exercices écrits à la main, séries notées ; Records retirés de l'accueil (dans Progression) ; « Choisir dans la bibliothèque » et « Ajouter un exercice » sous le nom et les jours de la séance ; logos Premium (fait le 2026-10-15).
- [x] Nutrition : 18 nutriments de plus (gras trans, oméga-3 et 6, zinc, phosphore, sélénium, cuivre, manganèse, vitamines E, K, B1, B2, B3, B5, B6, choline, caféine, alcool) ; tout sauf calories, protéines, glucides et lipides est Premium (fait le 2026-10-15).
- [x] Widgets : un widget posé garde le widget choisi à l'ajout ; la galerie montre, pour chaque taille, ton dernier widget de cette taille ; « Modifier le widget » les liste tous. Une entrée par widget créé dans la galerie est impossible sous iOS (une entrée par taille). À vérifier sur l'iPhone (fait le 2026-10-15).
- [x] Planning : toucher la carte Planning de Mon Quotidien ouvre la mini-app Planning, où l'on crée un événement en touchant une heure libre (fait le 2026-10-15).
- [x] Créer : « Photos et citations » en dernier ; photo de fond derrière une citation (cadrage, voile réglable) (fait le 2026-10-15).
- [x] Icône de l'app en Premium (l'icône en place et Corail restent) (fait le 2026-10-15).
- [x] Nutrition : widget d'écran verrouillé « Scanner un aliment » et contrôle iOS 18 (fait le 2026-10-15).
- [x] Mon Quotidien : « Mes données » retiré en haut ; bouton « + » pour arranger les cartes (fait le 2026-10-15).

- [x] Quotidien : toucher une heure libre de la carte Planning (pleine largeur) crée un événement, toucher un bloc l'ouvre ; même chose dans la page Semaine ; en demi-largeur, la carte ouvre la semaine (fait le 2026-10-15).
- [x] Fitness : les exercices récents ne sont plus affichés (page Fitness et bibliothèque) ; seuls les favoris restent ; « Récents » reste seulement dans le sélecteur d'exercice d'une séance (fait le 2026-10-15).
- [x] Créer : carte « Photos et citations » en deuxième position dans « Tout » et en premier dans « Vie » ; elle demande Photos ou Citation puis ouvre la création (fait le 2026-10-15).

Série du 2026-10-15 (13 demandes, compilée en CI puis testée par `[unit]` ; à vérifier sur l'iPhone par TestFlight) :
- [x] Nutrition : besoins calculés automatiquement à partir de l'âge, la taille, le poids, le genre, l'objectif et l'activité (Mifflin-St Jeor, protéines en g/kg, fibres 14 g/1 000 kcal, sucres et gras saturés < 10 % OMS, sodium < 2 300 mg, minéraux et vitamines DRI) ; chaque valeur « Calculé » ou « Personnalisé », modifiable à tout moment, jamais écrasée en silence ; nutriments détaillés seulement quand l'aliment les fournit (fait le 2026-10-15).
- [x] « Mes infos » en tête de chaque mini-app à la place de « Modifier les paramètres » / « Mes paramètres » ; doublons retirés (objectifs Nutrition, séances par semaine de Fitness…) (fait le 2026-10-15).
- [x] Fitness : ordre aperçu, semaine, programme et séances, exercices, progression et statistiques, records en bas ; ajouter un exercice pendant une séance l'ajoute directement à la séance en cours (fait le 2026-10-15).
- [x] Premium : statistiques détaillées de chaque mini-app et bibliothèque complète d'exercices (aperçu gratuit, 39 exercices offerts, ceux déjà faits restent ouverts), cadenas clair et paywall ; aucune donnée gratuite effacée (fait le 2026-10-15).
- [x] Planning : toucher une heure libre crée un événement prérempli (titre, durée, lieu…, modifier, supprimer, chevauchements signalés) ; pincement jour ↔ semaine ↔ mois ↔ année en gardant la position, sans création accidentelle, avec sélecteur de secours (fait le 2026-10-15).
- [x] Finances Business : audit des intégrations (`docs/integrations-business.md`), Stripe en lecture seule par clé restreinte (trousseau, synchronisation sans doublon, dernière synchronisation et erreurs), import CSV (Stripe, Shopify, banque, tableur) ; Shopify, QuickBooks et Stripe Connect demandent un serveur (architecture documentée). Pas encore essayé avec un vrai compte Stripe (fait le 2026-10-15).
- [x] Nouvelle mini-app Photos et citations : taille d'abord, sélecteur de photos système (aucun accès à la photothèque), mises en page 1 à 4 photos, au-delà rotation chaque heure (12 au plus), recadrage gardé, aperçu, modification, photo supprimée signalée ; citation avec auteur, typographie, couleurs et fond (fait le 2026-10-15).
- [x] Mini-app Eau retirée partout (widgets, Mon Quotidien, rappels, intents), les autres données intactes (fait le 2026-10-15).
- [x] Langue et fuseau horaire indépendants ; heures justes aux changements d'heure (bug corrigé dans l'emploi du temps) ; tests fr → en → fr sans changement des heures (fait le 2026-10-15).
- [x] Activité en direct : boutons (pause, série suivante…) utilisables sans déverrouiller l'iPhone (à confirmer sur l'iPhone) (fait le 2026-10-15).
- [x] Galerie des widgets : écran d'accueil = seulement « Mes widgets » (tes widgets) ; écran verrouillé = l'essentiel de chaque mini-app (fait le 2026-10-15).
- [x] Réponse : tester Premium par TestFlight (achats du bac à sable, gratuits) une fois les produits créés dans App Store Connect (fait le 2026-10-15).

- [x] Politique de confidentialité conforme (Loi 25, LPRPDE, RGPD, LGPD, APPI, CCPA/CPRA), en français et en anglais ; adresse de support réelle dans l'app (fait le 2026-10-11).
- [x] Notifications avec l'ancien logo Tessera : rien dans le code (icône principale Ardane depuis la version de test 157) ; cache d'icônes d'iOS → redémarrer l'iPhone (diagnostic du 2026-10-11). Toujours là après redémarrage : jeux d'icônes renommés AppIcon… → ArdaneIcon… (2026-10-11) pour qu'iOS oublie l'icône en cache. Sans effet (2026-10-12) : rien de l'ancien logo dans l'app ni dans l'IPA (vérifié) ; il faut supprimer et réinstaller l'app (sauvegarde puis restauration). Réinstallation faite, toujours la mosaïque (test de la 179) : bug d'iOS 18.1+ connu d'Apple, propre à cet iPhone ; pistes données à l'utilisateur (redémarrage forcé, changement de langue), changement d'identifiant proposé, accepté : `com.dakrsnyk.ardane` (2026-10-12). Vérifié par l'utilisateur sur la 180 : notification au A d'Ardane ; bouton de test retiré.

- [x] Pub : montrer dans tous les films (principal compris) qu'on peut personnaliser son widget à son goût — le point le plus important après l'utilité (fait le 2026-10-11 : séquence Studio, styles qui changent sur les widgets soulevés).
- [x] Pub : commencer chaque film par une phrase d'accroche (« Organize your life with Ardane », etc.) (fait le 2026-10-11).

- [x] Pub : pas de pot de yaourt généré ; le scan est représenté par un code-barres seul (fait le 2026-10-11).
