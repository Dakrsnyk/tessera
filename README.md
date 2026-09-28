# Tessera

Application iOS de widgets personnalisables, organisée en **espaces** (mini-apps) : nutrition, sport, budget, business, placements, études, voyage, auto, productivité, habitudes, météo, ma journée.
Chaque espace contient les données, et ses widgets les affichent sur l'écran d'accueil et l'écran verrouillé.
SwiftUI + WidgetKit + App Intents + StoreKit 2, iOS 17 minimum, sans aucune dépendance externe.

---

## 1. Tester l'app sur ton iPhone sans Mac

Chaque modification poussée sur `main` est compilée automatiquement sur un Mac de GitHub. Pour économiser les minutes Mac du dépôt privé, le message de commit choisit ce qui est fait :

| Dans le message | Ce qui est fait |
|---|---|
| (rien) | Vérifications statiques, compilation simulateur et iPhone, publication de `Tessera.ipa` |
| `[check]` | Vérifications statiques et compilation simulateur seulement (le plus rapide) |
| `[place]` | Compilation simulateur et test d'ajout des widgets à l'écran d'accueil et à l'écran verrouillé |
| `[qa]` | Tous les tests automatiques, puis les captures d'écran de toutes les pages et de la galerie de widgets |
| `[release]` | En plus : compilation dans la configuration App Store et vérification que le déblocage de test en est absent |

Le rapport (erreurs, résultats des tests, captures) est publié sur la branche `ci-report`.
Le fichier à installer est publié dans **Releases** (colonne de droite du dépôt) : `Tessera.ipa`.

### Première installation (PC Windows)

1. Installe **iTunes** et **iCloud** depuis le site d'Apple (pas la version Microsoft Store).
2. Installe **Sideloadly** depuis sideloadly.io.
3. Télécharge le dernier `Tessera.ipa` dans *Releases*.
4. Branche ton iPhone en USB et touche **Se fier à cet ordinateur**.
5. Ouvre Sideloadly, glisse `Tessera.ipa` dans la fenêtre, entre ton identifiant Apple et clique sur **Start**.
6. Sur l'iPhone :
   - Réglages > Confidentialité et sécurité > **Mode développeur** : active-le (l'iPhone redémarre).
   - Réglages > Général > **VPN et gestion de l'appareil** : touche ton identifiant et **Faire confiance**.
7. Ouvre Tessera.

Avec un identifiant Apple gratuit, l'app expire au bout de **7 jours** : relance simplement Sideloadly avec le même fichier. Un compte gratuit est aussi limité à 3 apps installées de cette façon.

Cette version de test débloque automatiquement tout le Premium, sans achat. Réglages > **Développeur** > « Premium débloqué (mode test) » permet de le couper pour vérifier la version gratuite. Ce code est compilé uniquement dans les versions de test (`#if DEBUG`) : il n'existe pas dans la version App Store, qui passe toujours par StoreKit. La vérification statique du dépôt refuse toute référence à ce mode hors d'un bloc `#if DEBUG`.

### Si les widgets n'affichent pas tes données

Les widgets lisent les données de l'app dans un espace partagé (App Group). Avec un compte gratuit, certains outils d'installation ne créent pas cet espace : l'app fonctionne, mais les widgets restent sur leur contenu par défaut. Dans ce cas, active l'option « App Group » / « Keep extensions » de Sideloadly si elle est proposée, ou attends le compte Apple Developer (TestFlight règle le problème).

---

## 2. Ouvrir le projet sur un Mac

1. Ouvre `Tessera.xcodeproj` avec **Xcode 16** ou plus récent.
2. Sélectionne le projet, puis pour **chaque cible** (`Tessera` et `TesseraWidgets`) : onglet *Signing & Capabilities* > **Team** = ton compte.
3. Choisis la cible **Tessera** et un iPhone (réel ou simulateur), puis **Run** (⌘R).

Les achats fonctionnent en local grâce à `Config/Tessera.storekit` (déjà relié au schéma : *Product > Scheme > Edit Scheme > Run > Options > StoreKit Configuration*).

Dans les versions de test (Debug), le Premium est débloqué d'office ; Réglages > **Développeur** > « Premium débloqué (mode test) » le coupe. En Release (Archive pour l'App Store), seul StoreKit décide.

Les résumés rédigés par Apple Intelligence utilisent `FoundationModels` (iOS 26), lié en mode faible : l'app reste compatible iOS 17 et affiche le texte calculé quand le modèle n'est pas disponible.

---

## 3. Ce que tu dois configurer toi-même

| Élément | Où | Quand |
|---|---|---|
| Compte **Apple Developer** (99 $ US/an) | developer.apple.com | Avant TestFlight et l'App Store |
| **Team** de signature des 2 cibles | Xcode > Signing & Capabilities | Première ouverture sur Mac |
| Identifiants (si tu changes de préfixe) | `PRODUCT_BUNDLE_IDENTIFIER` des 2 cibles, `APP_GROUP_ID`, fichiers `Config/*.entitlements` | Si `com.dakrsnyk.tessera` est déjà pris |
| Fiche de l'app | App Store Connect > Mes apps | Avant la soumission |
| Contrats, banque, fiscalité | App Store Connect > Accords | Obligatoire pour vendre |
| **Abonnements** : groupe « Tessera Premium » avec `com.dakrsnyk.tessera.premium.monthly` (1 mois) et `…premium.yearly` (1 an, essai gratuit 1 semaine) | App Store Connect > Abonnements | Avant la soumission |
| **Achat unique** : `com.dakrsnyk.tessera.premium.lifetime` (non consommable) | App Store Connect > Achats intégrés | Avant la soumission |
| Adresse de support | `App/Premium/PremiumConfiguration.swift` (`supportEmail`) | Avant la soumission |
| Politique de confidentialité | Page « Confidentialité Tessera » (lien déjà dans l'app) : la rendre publique via son menu Partager | Avant la soumission |
| **Clé Open-Meteo** (usage commercial) | Réglage `OPEN_METEO_API_KEY` du projet | Dès que l'app est vendue : l'API gratuite est réservée à l'usage non commercial |
| Clé CoinGecko (facultative) | Réglage `COINGECKO_API_KEY` | Si la limite gratuite est atteinte |
| Clé **Finnhub** (facultative) | Réglage `FINNHUB_API_KEY` (compte gratuit sur finnhub.io) | Pour le cours en direct des actions ; sans clé, le prix saisi à la main est utilisé |
| Contact SEC EDGAR | `Shared/Domains/Companies.swift` (`supportEmail`) | Avant la soumission : la SEC exige une adresse de contact réelle dans l'en-tête des requêtes |
| Licences des données | Page « À propos » / fiche App Store | Mentionner Open Food Facts (ODbL), Open-Meteo, CoinGecko, SEC EDGAR, Frankfurter (BCE) |
| Captures d'écran App Store | App Store Connect | Avant la soumission |

Les identifiants d'abonnement sont centralisés dans `App/Premium/PremiumConfiguration.swift`. S'ils changent, mets aussi à jour `Config/Tessera.storekit`.

---

## 4. Ce que contient l'app

**Des espaces (mini-apps)** qui alimentent les widgets : Productivité, Habitudes, Nutrition, Fitness, Budget, Placements, Mon entreprise, Sociétés cotées, Études, Voyage, Auto, Ma vie. Ce qu'on y note s'affiche aussitôt dans les widgets.

**103 widgets** (30 gratuits, 73 Premium), chacun en plusieurs tailles, beaucoup aussi sur l'écran verrouillé. Dans la galerie d'iOS, ils apparaissent sous forme de 15 widgets d'origine et de 15 widgets thématiques (Nutrition, Fitness, Budget…). On choisit ensuite le widget précis avec « Modifier le widget ».

| Catégorie | Gratuits | Premium |
|---|---|---|
| Temps | Horloge, Calendrier, Progression, Compte à rebours, Anniversaire, Ma semaine, Prochain jour férié, Phase de lune | Fuseaux horaires, L'année en points, Mon âge |
| Météo | Météo, Soleil | Pluie, Vent et UV, Météo détaillée, Semaine météo |
| Productivité | Tâches, Note, Top 3 du jour, Compteur | Focus, À venir, Projet, Échéance, Travail profond |
| Habitudes | Habitudes, Hydratation, Série | Semaine d'habitudes, Taux de réussite |
| Nutrition | Calories restantes | Macros, Protéines restantes, Repas du jour, Semaine nutrition, Série de suivi, Ajout rapide, Prochain repas |
| Fitness | Séance du jour, Régularité | Prochaine série, Repos, Volume, Records, Calories brûlées, Mois d'entraînement |
| Budget | Reste du mois, Objectif d'épargne | Flux d'argent, Dépenses par catégorie, Factures, Valeur nette, Abonnements, Dépense rapide |
| Placements | Liste de suivi | Crypto, Portefeuille, Répartition, Plus forte variation, Marché crypto |
| Mon entreprise | Objectif du mois | Ventes sur 30 jours, Bénéfice, Indicateurs, MRR et ARR, Ventes du jour, Tableau de bord |
| Sociétés cotées | | Fiche entreprise, Revenus trimestriels, Action, Comparateur |
| Études | Prochain cours, Prochain examen, Session | Devoirs, Moyenne, Fiche de révision, Heures d'étude, Horaire du jour |
| Voyage | Départ en voyage, Heure sur place | Vol, Hôtel, Météo à destination, Devise, Avancement, Prochaine activité |
| Auto | Prochain entretien | Coût, Kilométrage, Carburant, Échéances |
| Tableaux de bord | | Ma journée, Maintenant, Ce matin, Fitness, Argent, Études, 4 résumés « intelligents » |

**Interactif depuis l'écran d'accueil** : cocher une tâche ou une priorité, valider une habitude, ajouter un verre d'eau, noter un aliment favori ou une dépense rapide, valider une série et passer le repos, compter (+1/−1), lancer un Focus, réviser une fiche.

**Store** : 8 packs installés d'une touche (Bien démarrer, Étudiant, Sportif, Entrepreneur, Budget serré, Voyageur, Investisseur, Minimal).

**Résumés intelligents** : calculés sur l'iPhone à partir des données de l'utilisateur. Avec Apple Intelligence (iOS 26), le texte est reformulé ; chaque nombre de la reformulation est vérifié par rapport aux données, sinon le texte calculé est gardé. Aucune donnée n'est inventée.

**Sources de données** : Open Food Facts (ODbL) et une base intégrée d'aliments courants, Open-Meteo, CoinGecko, SEC EDGAR (chiffres officiels, domaine public), Frankfurter (taux de la BCE), Finnhub (cours des actions, clé facultative). Les écrans de placements sont informatifs et ne donnent aucun conseil financier ; les valeurs nutritionnelles sont indicatives.

**12 styles** (4 gratuits, 8 Premium), couleurs d'accent, fonds (couleur, dégradé, photo), polices, alignement et affichage des détails.

**Gratuit** : 30 widgets, 4 styles, 8 couleurs, 5 widgets enregistrés, 3 habitudes.
**Premium** : tout, sans limite. Mensuel, annuel (essai 7 jours) ou à vie.

### Architecture

```
Shared/    Code commun à l'app et aux widgets
  Model/     Types de widgets, designs, contenu, réglages, modèles, villes
  Theme/     Styles, palette, résolution des couleurs
  Data/      Météo (Open-Meteo), crypto (CoinGecko), calendrier (EventKit), calculs d'argent
  Intents/   Configuration des widgets et boutons interactifs (App Intents)
  Render/    Rendu de chaque widget (utilisé aussi pour les aperçus dans l'app)
  Support/   Stockage partagé (App Group), formats, dates, liens profonds
Widgets/   Extension WidgetKit : fournisseur de timelines et déclaration des widgets
App/       Application : écrans, Premium (StoreKit 2), services, ressources
Config/    Info.plist, entitlements, configuration StoreKit locale
```

- Données : fichiers JSON dans l'App Group, un fichier par domaine pour éviter les écrasements entre l'app et les widgets.
- Réseau : seulement pour la météo (cache 30 min) et la crypto (cache 15 min), avec repli sur le cache hors connexion.
- Rafraîchissement : chaque widget a son propre rythme (à la minute pour les horloges, à minuit pour le calendrier, au changement de session pour Focus…).

---

## 5. Checklist de test

**Premier lancement**
- [ ] Animation du logo, puis présentation en 4 pages ; « Passer » fonctionne
- [ ] Aucune permission demandée au lancement

**Navigation**
- [ ] Onglets Accueil, Espaces, Store, Mes widgets, Réglages
- [ ] Recherche (loupe de l'accueil → Explorer), filtres Gratuits/Premium, catégories, styles

**Espaces (V2)**
- [ ] Chaque espace : ajouter, modifier, supprimer des éléments ; les widgets de l'espace changent aussitôt
- [ ] Nutrition : recherche (base intégrée et Open Food Facts), scan d'un code-barres, aliment personnalisé, objectifs
- [ ] Store : installer un pack, puis l'ajouter depuis « Mes widgets »

**Éditeur**
- [ ] L'aperçu change en direct (style, couleur, fond, police, titre, détails, alignement)
- [ ] Changement de taille : Petit, Moyen, Grand, écran verrouillé
- [ ] Réglages propres à chaque widget (villes, période, date, note, crypto, mode argent…)
- [ ] Enregistrer un nouveau widget ouvre le guide d'ajout

**Widgets sur l'écran d'accueil**
- [ ] Ajouter chaque type, puis « Modifier le widget » > choisir un design
- [ ] Cocher une tâche, valider une habitude, ajouter un verre, lancer/arrêter un Focus depuis le widget
- [ ] Les changements faits dans l'app apparaissent dans les widgets
- [ ] Toucher un widget ouvre le bon écran de l'app

**Gratuit / Premium**
- [ ] En gratuit : un style Premium s'essaie dans l'éditeur, l'enregistrement ouvre l'offre
- [ ] En gratuit : limite de 5 widgets et 3 habitudes
- [ ] Un widget Premium posé en gratuit affiche « Premium, touche pour débloquer »
- [ ] Achat mensuel, annuel (essai), à vie (Mac + fichier StoreKit, ou TestFlight)
- [ ] « Restaurer les achats » dans Réglages et dans l'offre
- [ ] Mode avion : le statut Premium reste actif

**Apparence et accessibilité**
- [ ] Mode sombre (app et widgets)
- [ ] Texte agrandi (Réglages iOS > Affichage > Taille du texte)
- [ ] VoiceOver sur l'accueil, l'éditeur et l'offre

**Réseau et permissions**
- [ ] Mode avion : la météo et la crypto affichent la dernière valeur connue, sinon un message clair
- [ ] Refus de la position : message et recherche de ville possible
- [ ] Refus du calendrier : le widget À venir explique comment l'activer
- [ ] Refus des notifications : les rappels expliquent qu'ils sont désactivés

**Performance**
- [ ] Plusieurs widgets posés en même temps restent fluides
- [ ] Pas de chargement permanent dans l'app
