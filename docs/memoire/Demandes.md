---
tags: [ardane, memoire]
---

# Demandes

Écris ici (Obsidian, VS Code ou Bloc-notes) ce que tu veux que Claude fasse ou garde en tête, puis pousse avec GitHub Desktop. Une ligne par demande ; Claude coche ce qui est fait et ajoute la date.

Retour : [[Memoire]]

## À faire

- [ ] (exemple) Nutrition : …
- [ ] Fitness : tous les exercices en Premium avec l'accès à leurs données ; section Records retirée de l'accueil de Fitness (gardée dans Progression) ; « Choisir dans la bibliothèque » et « Ajouter un exercice » juste sous le nom et les jours de la séance ; petits logos Premium partout où c'est Premium.
- [ ] Widgets : un widget créé doit être tout de suite proposé quand on l'ajoute à l'écran d'accueil (tous mes widgets, pas seulement 3).
- [ ] Bug widgets : un widget posé ne doit jamais être remplacé par un nouveau widget du même format.
- [ ] Nutrition : beaucoup plus de nutriments, tous Premium sauf calories, protéines, glucides et lipides.
- [ ] Planning : toucher l'horaire dans Mon Quotidien ouvre la mini-app Planning (c'est là qu'on crée un événement en touchant une plage horaire).
- [ ] Créer : « Photos et citations » tout en bas ; possibilité de mettre une photo derrière une citation.
- [ ] Icône de l'app : changer d'icône devient Premium.

## Idées pour plus tard

## Fait

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
