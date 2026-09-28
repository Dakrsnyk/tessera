# Tessera

Application iOS de widgets personnalisables : temps, productivité, météo, finances et bien-être.
SwiftUI + WidgetKit + App Intents + StoreKit 2, iOS 17 minimum, sans aucune dépendance externe.

---

## 1. Tester l'app sur ton iPhone sans Mac

Chaque modification poussée sur `main` est compilée automatiquement sur un Mac de GitHub.
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

Cette version de test contient, dans Réglages, une section **Développeur** avec l'interrupteur « Premium (mode test) » : il débloque tout sans achat, pour vérifier les deux modes. Elle n'existe pas dans la version App Store.

### Si les widgets n'affichent pas tes données

Les widgets lisent les données de l'app dans un espace partagé (App Group). Avec un compte gratuit, certains outils d'installation ne créent pas cet espace : l'app fonctionne, mais les widgets restent sur leur contenu par défaut. Dans ce cas, active l'option « App Group » / « Keep extensions » de Sideloadly si elle est proposée, ou attends le compte Apple Developer (TestFlight règle le problème).

---

## 2. Ouvrir le projet sur un Mac

1. Ouvre `Tessera.xcodeproj` avec **Xcode 16** ou plus récent.
2. Sélectionne le projet, puis pour **chaque cible** (`Tessera` et `TesseraWidgets`) : onglet *Signing & Capabilities* > **Team** = ton compte.
3. Choisis la cible **Tessera** et un iPhone (réel ou simulateur), puis **Run** (⌘R).

Les achats fonctionnent en local grâce à `Config/Tessera.storekit` (déjà relié au schéma : *Product > Scheme > Edit Scheme > Run > Options > StoreKit Configuration*).

Dans les versions de test (Debug), Réglages > **Développeur** > « Premium (mode test) » permet de vérifier l'app en mode Premium sans achat.

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
| Politique de confidentialité | `PRIVACY.md` (lien déjà dans l'app) ; à héberger ailleurs si tu préfères | Avant la soumission |
| **Clé Open-Meteo** (usage commercial) | Réglage `OPEN_METEO_API_KEY` du projet | Dès que l'app est vendue : l'API gratuite est réservée à l'usage non commercial |
| Clé CoinGecko (facultative) | Réglage `COINGECKO_API_KEY` | Si la limite gratuite est atteinte |
| Captures d'écran App Store | App Store Connect | Avant la soumission |

Les identifiants d'abonnement sont centralisés dans `App/Premium/PremiumConfiguration.swift`. S'ils changent, mets aussi à jour `Config/Tessera.storekit`.

---

## 4. Ce que contient l'app

**15 widgets réels** (WidgetKit), chacun en plusieurs tailles, certains aussi sur l'écran verrouillé :

| Catégorie | Gratuits | Premium |
|---|---|---|
| Temps | Horloge, Calendrier, Progression (jour/semaine/mois/année), Compte à rebours (avant/depuis) | Fuseaux horaires, L'année en points |
| Productivité | Tâches (cochables depuis l'écran d'accueil), Habitudes (validables d'une touche), Note | Focus (minuteur en direct), À venir (calendrier) |
| Météo | Météo (actuelle, heure par heure, 5 jours) | |
| Finances | | Crypto (cours + courbe 7 jours), Flux d'argent (revenus/dépenses au fil du jour) |
| Bien-être | Hydratation (+1 verre depuis le widget) | |

**12 styles** (4 gratuits : Minimal, Clair, Sombre, Monochrome ; 8 Premium : Verre, Aurore, Élégant, Digital, Rétro, Futuriste, Typo, Couleur), couleurs d'accent, fonds (couleur, dégradé, photo), polices, alignement et affichage des détails.

**Fonctionnement** : on crée un design dans l'éditeur (aperçu en direct, rendu identique au vrai widget), puis on l'ajoute à l'écran d'accueil et on le choisit via « Modifier le widget ».

**Gratuit** : 9 widgets, 4 styles, 8 couleurs, 5 widgets enregistrés, 3 habitudes.
**Premium** : tout, sans limite. Mensuel, annuel (essai 7 jours) ou à vie. Un design Premium peut être essayé dans l'éditeur ; il est demandé à l'enregistrement.

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
- [ ] Onglets Accueil, Explorer, Mes widgets, Réglages
- [ ] Recherche (loupe de l'accueil → Explorer), filtres Gratuits/Premium, catégories, styles

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
