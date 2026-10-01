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
| `[marketing]` | Rend les 10 captures App Store (iPhone 6,9 pouces, 1320 × 2868) : scènes dessinées par l'app, vrais écrans capturés à part |

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

**Optimisation, même en Debug** : la configuration Debug est compilée optimisée (`-O`). Non optimisée, l'interface SwiftUI de Tessera dépasse la pile de 1 Mo du fil principal de l'iPhone et l'app plante au lancement sur un vrai téléphone (le simulateur a 8 Mo et ne le montre pas). Pour que les tests le voient, l'app Debug est liée avec une pile de 1 Mo, comme sur l'iPhone. Le mode CI `[stack]` compare les deux compilations.

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

**Des espaces** (onglet Créer) qui alimentent les widgets : Productivité, Habitudes, Nutrition, Fitness, Budget, Placements, Mon entreprise, Sociétés cotées, Études, Voyage, Auto, Ma vie. Ce qu'on y note s'affiche aussitôt dans les widgets.

**Neuf mini-apps, ouvertes depuis l'accueil** (Accueil → carte de « Mon Quotidien » ou « Mes mini-apps » → mini-app → sections). Elles lisent et écrivent les mêmes données que les espaces, les widgets et « Mes informations » : rien n'est dupliqué. Chacune a un tableau de bord (ce qui compte maintenant, une action principale), puis ses sections à une touche ; le retour ramène toujours là où on était. Sans données, un écran court explique quoi noter, sans grands écrans vides.
- **Nutrition** : calories, macros et tous les nutriments connus (jamais inventés), repas modifiables (quantité, repas, suppression), repas enregistrés et repas précédents à reprendre, 207 aliments courants plus Open Food Facts, scanner, idées selon ce qui reste vraiment, historique (jour, hier, 7 jours, 30 jours, période) avec le poids.
- **Fitness** : séance du jour, programme (séries, répétitions, charge, repos, tempo, notes), bibliothèque de 163 exercices (recherche par nom, synonymes, muscle ou matériel, filtres, favoris, récents, « Mes exercices »), fiche ⓘ avec démonstration animée et technique (chaque exercice a la sienne : un personnage aux vraies proportions, en 3D, sur son matériel — banc à la bonne inclinaison, barre, haltères, poulie reliée à la poignée et à la pile de charges, machines dont le levier tourne autour de l'articulation travaillée —, les phases nommées « départ → mouvement → position finale → retour », plusieurs angles de vue, muscles principaux et secondaires en couleur, pause d'un toucher ; générée par `scripts/demos`, vérifiée automatiquement : longueurs des os constantes, mains et pieds sur le matériel, rien ne traverse un banc, une machine ou le sol), « Ajouter à ma séance », séance en direct avec ⓘ sans perdre sa place, historique, progression par exercice, activité du jour (podomètre de l'iPhone).
- **Planning** : aujourd'hui en une ligne du temps (calendrier, cours, examens, devoirs, tâches, échéances, séances), Top 3, tâches avec priorité, échéance, heure et répétition, semaine, mois, projets, habitudes et séries, concentration.
- **Études** : cours en cours ou prochain, devoirs à cocher, examens (compte à rebours, temps révisé), notes et moyennes, ce qu'il faut sur le reste pour atteindre un objectif, horaire en grille, chrono d'étude, fiches de révision.
- **Finances** : reste du mois et par jour, revenus et dépenses (modifiables), catégories et limites, factures et abonnements, épargne et comptes, évolution sur 6 mois et comparaison avec le mois dernier à la même date. Aucune connexion bancaire, aucun conseil financier.
- **Business** : chiffre d'affaires comparé à la période précédente arrêtée au même moment (jour, semaine, mois, année), indicateurs choisis par la personne (bénéfice, marge, panier moyen, conversion, MRR…), indicateurs suivis à la main (abonnés, devis…), résultats par mois, revenu récurrent.
- **Voyage** : compte à rebours ou jour du voyage, heure et météo sur place, prochain vol, hébergement et activité, programme jour par jour, budget dans toutes les devises (taux de la BCE ; un montant sans taux est affiché à part, jamais deviné), liste « À ne pas oublier ».
- **Auto** : compteur, kilomètres du mois, autonomie estimée (taille du réservoir et consommation depuis le dernier plein complet), consommation et prix au litre, pleins modifiables, entretiens, échéances, coût réel par mois.
- **Météo** : maintenant, les prochaines heures (température et pluie), les jours à venir, vent, humidité, pression, UV, soleil, et la météo du voyage en cours.

« Mes mini-apps » sur l'accueil propose celles qui ont des données ou touchent un centre d'intérêt, les plus ouvertes d'abord, avec un chiffre du moment ; les autres sont dans « Toutes ».

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

**Store** : une page épurée façon magazine. En couverture, l'écran d'accueil de la semaine ; puis les écrans d'accueil, 40 combinaisons (plusieurs widgets d'une même catégorie réunis dans un moyen ou un grand), 20 packs de six widgets (dont le pack de la semaine), 12 collections, les Incontournables, l'écran verrouillé, les styles, les nouveautés et l'index des catégories. La recherche trouve aussi les écrans, les packs et les combinaisons. Ce qui touche les centres d'intérêt de la personne passe en premier ; l'ordre des Incontournables est éditorial (l'app ne compte pas les téléchargements).

**Mes widgets** : un carrousel qu'on fait tourner du doigt, le widget du milieu en grand avec Modifier, Dupliquer, Favori et Ajouter à l'écran. En bas, les catégories des widgets enregistrés (plus Tous et Favoris) filtrent le carrousel. « Sélectionner » repasse en grille pour supprimer ou fusionner plusieurs widgets.

**Écrans d'accueil** (Store) : 18 écrans complets dessinés comme sur un vrai iPhone : fond d'écran (dessiné par l'app), vrais widgets Tessera, icônes et dock assortis, et l'écran verrouillé qui va avec. Crème, Aurore, Graphite, Néon, Topographie, Minuit, Études, Jade, Dune, Pastel, Bureau, Corail, Océan, Forêt, Crépuscule, Terrazzo, Nébuleuse, Seventies. On les filtre (#minimal, #sombre, #pastel, #sport…), on les met en favoris, on ajoute tous leurs widgets d'une touche et on enregistre le fond d'écran dans Photos.

**Premier lancement personnalisé** : style de l'app, prénom et nom, centres d'intérêt (Sport, Nutrition, Finance, Budget, Business, Études, Productivité, Voyage, Automobile, Météo, Design, Bien-être), puis seulement les questions utiles pour ces thèmes. Tout est facultatif et chaque étape peut être passée.

**Tutoriel** : juste après ces questions, un petit tour de l'app en 10 étapes, sur l'app elle-même : l'onglet concerné s'ouvre, la partie expliquée s'éclaire et le reste s'assombrit (Mon Quotidien, mini-apps, Mes informations, Créer, le Studio en miniature à essayer, le Store, Mes widgets, l'ajout sur l'écran d'accueil, puis les Réglages). Chaque étape peut être passée, on peut sauter directement à une étape avec la barre de progression, ou quitter avec la croix. Il se revoit dans Réglages › Aide › Revoir le tutoriel. Les installations d'avant le tutoriel ne le voient pas d'office.

**Accueil** : un tableau de bord. « Mon Quotidien » réunit ce qui compte aujourd'hui, uniquement à partir de ce que la personne a renseigné : calories et macros (avec le bouton Scanner), séance du jour (Commencer, Série faite), cours et examens du jour, agenda, habitudes, eau, pas (capteur de mouvement de l'iPhone, sur autorisation), budget du jour, météo, « À ne pas oublier » (examens, devoirs, échéances, factures, voiture, départ). L'ordre suit le moment : météo et premier cours le matin, séance et tâches la journée, calories restantes et habitudes le soir. Rien n'est affiché sans données : au plus deux invitations discrètes. Puis « Mes informations », Mes widgets et un aperçu du Store.

**Mes informations** : le centre de toutes les données, par thème (Nutrition, Fitness, Études, Budget…) : objectifs, programme, horaire, factures, voyage, voiture, ville, calendrier… Chaque information a un seul endroit où elle est gardée et tous les widgets, « Mon Quotidien » et les statistiques la reprennent : un objectif de 2 500 kcal donné une fois sert partout. Chaque widget sait ce dont il a besoin : l'éditeur, Créer et la configuration des packs demandent exactement ces informations, au moment de créer le widget. Ce qui n'a pas été renseigné n'est jamais inventé : les widgets affichent un état neutre (« Objectif à définir »).

**Aperçus d'exemple** : dans le Store, la fiche d'un pack et l'éditeur, un widget sans données montre des données d'exemple, marquées « Exemple ». Elles ne sont jamais enregistrées et disparaissent dès que la personne donne les siennes.

**Packs et écrans d'accueil** : configurés widget par widget (« Widget 2 sur 6 »), avec ce qui est prêt et ce qui reste, un résumé, puis l'enregistrement et l'envol des widgets vers « Mes widgets ».

**Scanner depuis le widget Nutrition** : les widgets Nutrition moyens et grands ont un bouton « Scanner » qui ouvre l'app directement sur la caméra (un widget ne peut pas l'ouvrir lui-même). Sans caméra, ou si le produit est inconnu, la recherche et l'aliment perso prennent le relais.

**Icône et logo** : le « T en creux » : trois tuiles (rouge, orange, charbon) dont l'espace dessine un T, sur crème. L'icône a ses versions claire, sombre et teintée (iOS 18) ; le même logo s'anime au lancement (les tuiles glissent en place) et apparaît dans l'app (premier lancement, Premium, écrans d'accueil du Store).

**Styles de l'app** : 10 ambiances pour l'app elle-même (Tessera, Océan, Corail, Lavande, Sable, Graphite, Forêt, Rose, Minuit, Néon), chacune en clair, en sombre ou automatique. Choisies au premier lancement, modifiables dans Réglages › Apparence. Les widgets gardent leurs propres styles.

**Résumés intelligents** : calculés sur l'iPhone à partir des données de l'utilisateur. Avec Apple Intelligence (iOS 26), le texte est reformulé ; chaque nombre de la reformulation est vérifié par rapport aux données, sinon le texte calculé est gardé. Aucune donnée n'est inventée.

**Sources de données** : Open Food Facts (ODbL) et une base intégrée d'aliments courants, Open-Meteo (CC BY 4.0, cité dans la mini-app Météo), CoinGecko, SEC EDGAR (chiffres officiels, domaine public), Frankfurter (taux de la BCE), Finnhub (cours des actions, clé facultative). Les écrans de placements sont informatifs et ne donnent aucun conseil financier ; les valeurs nutritionnelles sont indicatives.

**Widget Studio** : l'éditeur de widget, avec l'aperçu toujours visible en haut qui change à chaque réglage, deux flèches (retour en arrière, retour en avant) qui annulent ou rétablissent chaque modification, et 8 sections :
- **Contenu** : nom, données du widget, options (pour un widget réuni : chaque widget à l'intérieur, son nom et ses options), et chaque élément affiché ou masqué (titre, icône, valeur, légende, graphique, boutons, chaque ligne, chaque part d'une répartition), avec la couleur de chaque ligne.
- **Thème & style** : les 16 thèmes complets (Midnight, Pure White, Ocean, Forest, Sunset, Cyber, Luxury, Minimal Black, Glass, Monochrome, Sakura, Sable, Arctique, Hacker, Stade, Cockpit) qui règlent tout d'un coup, et les 37 styles (les 12 d'origine et 25 qui changent aussi la composition : disposition, formes, texte, icônes, ombre, texture).
- **Couleurs** : la **couleur principale** repeint tout le widget (fond, cartes, texte, chiffres, icônes, graphiques, bordure, lignes) dans sa teinte, en gardant la luminosité de chaque élément pour rester lisible ; les **palettes** (14 : Jade, Océan, Corail, Lavande, Forêt, Sable, Néon, Bonbon, Or, Graphite, Couchant, Menthe, Minuit, Cerise) changent toutes les couleurs d'un coup, fond et lignes compris ; puis chaque couleur à la main (texte, secondaire, chiffres, icônes, graphiques, cartes, positif, négatif) et « Revenir aux couleurs du style ».
- **Fond** : style, couleur, dégradé automatique ou personnel, verre, photo avec voile réglable, et texture.
- **Bordure** (pleine, tirets, points, double, lumineuse, dégradé ; épaisseur, opacité, couleur).
- **Graphique**, seulement pour les widgets qui en ont un (ligne, aire, barres, histogramme, points, sparkline, évolution, comparaison, anneau, cercle, jauge, barre ; épaisseur, remplissage, valeurs, couleur), et **Densité** (aéré, équilibré, dense).
- **Mes styles** : enregistrer le look d'un widget sous un nom, l'appliquer à ce widget ou à plusieurs d'un coup, le renommer, le supprimer.

**Le même chemin partout** : sélection, puis modification dans le Studio. Dans Créer, on choisit la taille et les widgets, puis « Personnaliser » ouvre le Studio ; un widget du Store, un pack ou un écran d'accueil tout prêt s'ouvrent aussi dans le Studio. Plusieurs widgets créés ensemble s'y règlent l'un après l'autre (« 1 · Calories », « 2 · Macros »…) et partagent leur style tant que « Même style » est activé ; ils s'enregistrent ensemble.

Tout est enregistré avec le widget : on peut le modifier plus tard, le dupliquer ou « Créer une variante » (Mes widgets), changer ses données sans perdre le design et l'inverse. Ce qu'iOS ne permet pas n'est pas promis : un widget ne peut pas être vraiment transparent (le Verre et les dégradés sont dessinés), iOS dessine lui-même le contour du widget (bordures et ombres s'appliquent à l'intérieur), l'écran verrouillé est d'une seule teinte, et seules les polices système s'affichent dans les widgets. Les dispositions et graphiques s'appliquent aux widgets de données ; l'horloge, le calendrier, la météo et les autres widgets d'origine gardent leur mise en page et prennent tout le reste du look.

**Gratuit** : 30 widgets, 8 styles, 8 couleurs principales (qui repeignent tout le widget), densité, 5 widgets enregistrés, 3 habitudes. Les palettes, couleurs une à une, dégradés personnels, textures et bordures sont Premium (on peut les essayer dans le Studio).
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
- [ ] Animation du logo, style de l'app, puis les questions ; « Passer » fonctionne
- [ ] Le tutoriel suit les questions : chaque étape montre son onglet et éclaire la bonne partie ; « Passer l'étape », la barre de progression et la croix fonctionnent ; Réglages › Aide › Revoir le tutoriel le relance
- [ ] Aucune permission demandée au lancement

**Navigation**
- [ ] Onglets Accueil, Espaces, Store, Mes widgets, Réglages
- [ ] Recherche (loupe de l'accueil → Explorer), filtres Gratuits/Premium, catégories, styles

**Mini-apps**
- [ ] Chaque carte de « Mon Quotidien » ouvre sa mini-app ; le bouton retour revient à l'accueil
- [ ] Chaque mini-app : ajouter, modifier, supprimer ; la carte de l'accueil et les widgets changent aussitôt
- [ ] Fitness : ⓘ pendant une séance, puis retour à la même série
- [ ] Voyage : une dépense en devise étrangère est convertie (ou affichée à part sans taux)

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
