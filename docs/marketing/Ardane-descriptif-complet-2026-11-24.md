# Ardane : descriptif complet (2026-11-24)

Relevé dans le code et la carte du projet (`scripts/graph_map.py`, `docs/lancement/comparatif-gratuit-premium.md`, `App/Core/AppModel.swift`, `Shared/Model/WidgetKind.swift`). Sert de base aux panels de clients fictifs et aux textes de vente. À refaire si une limite, un prix ou une mini-app change.

## L'idée en une phrase

Des widgets **utiles**, pas décoratifs : ils montrent la journée de la personne à partir de ses propres données (cours, séance, calories, budget, habitudes) sur l'écran d'accueil et l'écran verrouillé, et on agit dessus sans ouvrir l'app. Les 7 mini-apps fournissent ces données ; le Studio et le Store les rendent beaux.

## Les 7 mini-apps

**Nutrition** : anneau des calories restantes, protéines, glucides, lipides ; repas du jour ; recherche d'aliments (base intégrée FCÉN + USDA, Open Food Facts) ; scanner intelligent (code-barres lu tout seul, ou photo d'un plat analysée sur l'iPhone et proposée en estimation modifiable, flash automatique) ; besoins calculés (Mifflin-St Jeor, objectif, protéines, fibres, minéraux) avec garde-fous (mineurs, grossesse) ; nutriments détaillés (Premium) ; ajout rapide depuis un widget.

**Fitness** : programme de la semaine ; séance en direct (série, répétitions, charge, repos minuté avec pause et « passer », son ou vibration à la fin du repos) ; activité en direct sur l'écran verrouillé et la Dynamic Island avec boutons « Série faite », « Passer », « Pause », « Annuler » sans déverrouiller ; 244 exercices avec démonstration animée d'un mannequin 3D et explications en 7 langues (bibliothèque Premium ; en gratuit, ses propres exercices) ; exercice tapé à la main reconnu ; progression par groupe musculaire, records, historique ; calories actives estimées ; pas du jour.

**Planning** : calendrier jour, semaine, mois, année (toucher une heure libre crée un événement) ; tâches avec répétition, Top 3 du jour, projets, minuteur de concentration ; habitudes et séries (3 en gratuit) ; lecture du calendrier de l'iPhone sur autorisation.

**Études** : cours, examens avec compte à rebours, devoirs, notes et moyenne, fiches de révision (retournées et notées depuis le widget), chrono d'étude en activité en direct ; import d'horaire depuis une photo ou un PDF, lu sur l'iPhone (cours, quarts de travail, rendez-vous), avec écran de vérification.

**Finances** : revenus et dépenses saisis (aucune connexion bancaire), reste du mois, catégories avec limites, factures à venir, objectifs d'épargne, valeur nette, relevé, graphique du solde ; dépenses Apple Pay ajoutées automatiquement par un Raccourci ; dépense rapide depuis un widget. Espace Placements : actions, ETF, crypto avec cours en direct.

**Business** : ventes, bénéfice, revenu récurrent (MRR, ARR), indicateurs ; ventes automatiques par Stripe en lecture seule ou import CSV (Premium).

**Voyage** : programme, vols, hôtels, activités, budget en devise (taux du jour), liste.

(Auto et Photos et citations existent aussi, hors des 7 mini-apps présentées.)

## Accueil « Ma journée »

Les cartes du jour construites à partir de ce que la personne a saisi (repas, séance, planning de la semaine, habitudes, Top 3, budget, études), classées selon l'heure, réorganisables comme l'écran d'accueil d'iOS.

## Créer, Studio, Store

- **Créer** : taille (petit, moyen, grand, écran verrouillé), catégorie, puis jusqu'à 4 widgets réunis en un seul ; aperçu réel et « Sur mon écran ».
- **Studio** : 57 styles (10 gratuits), 16 thèmes, palettes, couleur libre (8 gratuites), fonds (couleur, dégradé, photo, verre), polices, bordures, ombres ; « Mes styles » réutilisables.
- **Store** : 23 écrans d'accueil complets prêts (fond, widgets, icônes, écran verrouillé), 34 packs (Étudiant, Sportif, Voyageur…), 43 fonds d'écran originaux (14 gratuits), saisons.

## Widgets

Environ 99 types (32 gratuits), petits, moyens, grands et écran verrouillé (rond, rectangle, ligne) ; boutons qui agissent sans ouvrir l'app : cocher une habitude ou une tâche, valider ou passer une série, ajouter un repas ou une dépense, retourner une fiche, lancer la concentration, compteur ; cours en direct ; modes Clair et Teinté d'iOS.

## Le reste

Rappels intelligents et encouragements (2 par jour au plus) ; sauvegarde dans un fichier ; 20 icônes d'app (Premium) et 10 styles d'app ; tutoriel en 8 étapes ; 7 langues (anglais, français, espagnol, allemand, italien, portugais du Brésil, japonais).

## Confidentialité

Pas de compte, pas de publicité, pas de suivi. Les données restent sur l'iPhone ; le réseau ne sert qu'aux codes-barres (Open Food Facts), aux cours de bourse et de change, et à Stripe si la personne le connecte.

## Prix

- **Gratuit** : 3 widgets enregistrés (photos et citations sans limite), 32 types de widgets sur 99, 10 styles, 8 couleurs, 3 habitudes, 10 analyses de plat en photo, toutes les mini-apps pour saisir ses données.
- **Premium** : tous les widgets, styles, packs et fonds, widgets et habitudes sans limite, import d'horaire, bibliothèque d'exercices complète, statistiques détaillées, nutriments détaillés, analyses de plat illimitées, Stripe, icônes. **6,99 $ par mois ou 59,99 $ par an**, 7 jours d'essai gratuit.
- Comparaison avancée par le PDG : les apps spécialisées (compteur de calories, budget) coûtent souvent 15 $ par mois ou plus pour un seul domaine.
