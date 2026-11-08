# Rapport final : audit intégral prépublication d'Ardane (chantier 24, 2026-11-07)

> Ce que ce rapport prouve et ne prouve pas.
> - Tout ce qui est marqué « CI » a été exécuté par GitHub Actions sur un simulateur iOS (Xcode 26.3).
> - Rien n'a été exécuté sur un iPhone réel : Claude n'a ni Mac ni iPhone.
> - Ce qui exige l'iPhone figure à la section G (tests manuels).
> - « Aucun défaut trouvé » ne veut pas dire « aucun défaut ».

## A. État général

| Élément | Avant (run 42409228969, commit 6fad886f) | Après les corrections (runs 42421136593 Build 363 à 42438964850 Build 367) |
|---|---|---|
| Compilation de l'app et de l'extension (simulateur et iPhone non signé) | réussie | réussie |
| Version Release (configuration App Store, simulateur) | réussie | réussie (Build 363) ; déverrouillage de test trouvé dans les binaires de l'app et de l'extension : **0** |
| Version interne signée (TestFlight, Premium débloqué) | — | Builds 364, 366 et 368 : archive, export et contrôles des binaires réussis ; « Internal Only » confirmé par l'API d'Apple |
| Tests logiques | 1 241 réussis / 1 241 | **1 370 réussis / 1 370** (+129, Build 367) |
| Tests d'interface (`[daily]` : MiniApp, Studio, Profil) | 30 réussis, 1 échec | **31 réussis / 31** (Builds 365 et 367), après correction des défauts qu'ils avaient révélés (section A.2) |
| Contrôles statiques (`check_swift.py`) et traductions | réussis | réussis ; 5 679 textes, 0 absent du catalogue, 0 non traduit, 0 inutilisé |
| Tests non exécutés | aucun test ignoré ; les tests de pub et de vidéo ne font pas partie de `[daily]` | idem |
| Couverture de code | non mesurée (la CI ne produit pas de rapport de couverture) | non mesurée |

### A.1 Équipe
Le Chef a coordonné 10 audits en parallèle :
- sécurité, confidentialité et conformité ;
- Nutrition ; Fitness et Planning ; Finances ; widgets et données ; Premium et réglages ;
- interface ; performance ; tests.

Il a ensuite lancé 7 équipes de corrections et 5 relectures indépendantes (`code-reviewer`), plus une passe de traduction. Chaque correction a été relue par un autre agent que son auteur. Les points bloquants des relectures ont été corrigés par le Chef.

### A.2 Résultats des tests après corrections
Toutes les exécutions sont sur la CI (Xcode 26.3, build 17C529, simulateur iOS 26.2). Les comptes viennent du journal complet de chaque run, pas du rapport tronqué.

| Run | Tag | Résultat | Suite donnée |
|---|---|---|---|
| 42415997352 | `[check]` | une erreur de compilation, dans un test (étiquette `identifier:` de `SKTestSession.refundTransaction`) | corrigée |
| 42416753618 | `[unit]` | 1 353 réussis, 5 échecs | corrigés sans affaiblir les tests (détail ci-dessous) |
| 42419753127 | `[daily] [release]` | erreur de compilation : le masquage des graphiques d'argent posé dans une vue sans accès à la tuile | masquage déplacé sur la vue du visuel, depuis la tuile |
| 42421136593 | `[daily] [release]` | logique 1 361 / 1 361 ; interface 29 / 31 ; Release sans déverrouillage de test | voir les 2 échecs ci-dessous |
| 42429465658 | version interne | Build 364 signé et envoyé sur TestFlight ; contrôles des binaires réussis ; « Internal Only » confirmé | installé par l'utilisateur pour les tests de la section G |
| 42430789992 | `[daily]` | logique **1 362 / 1 362** ; interface **31 / 31** | les 2 échecs ci-dessous réussissent ; le second cachait un vrai défaut, corrigé ensuite |
| 42437604175 | version interne | Build 366 (correctif « Organiser ») signé et envoyé sur TestFlight ; une identité de signature ; contrôles des binaires réussis ; « Internal Only » confirmé | à tester sur l'iPhone (section G, point 10) |
| 42438964850 | `[daily]` | logique **1 370 / 1 370**, dont les 8 nouveaux tests ; interface **31 / 31**, dont le glisser sur la carte de gauche | correctif « Organiser » confirmé ; les captures montrent un autre défaut, corrigé ensuite (point 3 ci-dessous) |
| 42444945759 | version interne | Build 368 (vue fixe en mode « Organiser ») signé et envoyé sur TestFlight ; une identité de signature ; contrôles des binaires réussis ; « Internal Only » confirmé | à tester sur l'iPhone (section G, point 10) |

Les 5 échecs du `[unit]` :
- `WeightPlanModelTests` : pendant une grossesse, le calcul automatique garde désormais le maintien (garde-fou N-04). Le test attend ce maintien.
- `LivePricesTests` : le cas « prix manuels seulement » reçoit ses prix manuels. Une position sans aucun prix est signalée (M-17).
- 3 tests StoreKit : un abonnement que l'App Store déclare expiré ou révoqué ne donne plus accès. Les tests attendent (5 s au plus) que la session de test applique le remboursement, l'expiration ou l'achat. Les vérifications restent les mêmes.

Les 2 échecs d'interface du run 42421136593 :
1. **`MiniAppUITests.testASessionKeepsItsPlaceWhenTheSheetOpens` : nouveau, causé par l'audit, corrigé.**
   - Constat : la fiche qui explique l'alerte de fin de repos (ajoutée par F-04) s'ouvrait à la première série et recouvrait la séance.
   - Cause : « Plus tard » ne retenait rien, donc la fiche serait revenue après chaque série.
   - Correction (`RestAlertOffer`, `FitnessSession.swift`) : l'offre est faite une seule fois par installation, quelle que soit la réponse. Elle n'est jamais faite si les notifications sont déjà accordées ou refusées, ni dans les captures de la version de test (pubs, vidéos, tests d'interface).
   - Test ajouté : `testRestAlertIsOfferedOnceWhateverTheAnswer`. Relu par `code-reviewer` : aucun bloquant.
   - Confirmé au run 42430789992 : le test réussit, et la capture de la séance ne montre plus la fiche. Reste à voir sur l'iPhone (section G, point 3).
2. **`ProfileUITests.testDailyEditModeMovesHeldCardsAndScrollsOnSwipe` : ancien, cause trouvée, vrai défaut de l'app, corrigé.**
   - Constat : réussi aux runs 42140979318 et 42430789992, échoué aux runs 42409228969 et 42421136593, sans aucun changement du code du geste.
   - Cause : une carte large est seule sur sa ligne, les petites vont par deux, et une petite carte qui attend sa partenaire est dessinée après la carte large qui la suit. Glisser la grande carte Nutrition sur la petite carte de **gauche** de la ligne du dessous changeait l'ordre, mais l'écran restait identique. Tant que le doigt restait dessus, l'ordre basculait en plus toutes les 0,25 s. Sur la carte de **droite**, le déplacement fonctionnait.
   - Pourquoi le test alternait : il choisissait la plus proche des deux cartes, et le balancement du mode « Organiser » décale leur « × » d'une fraction de point. Les deux échecs visent la carte de gauche (x = 14,6).
   - Même défaut pour VoiceOver : « Déplacer après » sur la carte large ne changeait rien à l'écran.
   - Correction (`DailyLayoutRules.moved(_:id:onto:isWide:)`, `DailySection.swift`) :
     - la carte lâchée prend la ligne de la carte visée ; si un simple changement de rang ne suffit pas, les deux lignes s'échangent ;
     - si aucun ordre ne peut la montrer à cette place (une petite carte seule reste après les cartes larges), rien ne change ;
     - pendant le glisser, une carte qui vient de changer de ligne n'est plus visée tant que le doigt ne l'a pas quittée. Cela évite un va-et-vient quand une carte large est moins haute que la ligne de petites cartes ; ce défaut existait déjà avec la carte de droite (vu à la relecture) ;
     - VoiceOver vise le voisin tel qu'il est vu à l'écran, ou le suivant quand la carte ne peut pas le dépasser.
   - Tests :
     - 8 tests logiques ajoutés, dont la vérification de chaque lâcher et de chaque déplacement VoiceOver dans 6 grilles mixtes ;
     - le test d'interface vise désormais toujours la carte de gauche, en appuyant sur les pages de la carte.
   - Vérifié avant l'envoi par une simulation en Python des mêmes règles : 67 200 lâchers et 28 000 déplacements VoiceOver aléatoires. La carte finit toujours dans la ligne visée, ou rien ne change. Relu par `code-reviewer`.
   - Confirmé au run 42438964850 : les 8 tests logiques et le test d'interface réussissent. Sur les captures, la grande carte passe sous la ligne visée. Reste l'iPhone (section G, point 10).
3. **Pages de la carte décalées en mode « Organiser » : vu sur les captures, vrai défaut de l'app, corrigé.**
   - Constat : sur les captures des runs 42430789992 et 42438964850, la carte maintenue pour ouvrir le menu montre sa première vue décalée de 40 points vers la gauche. La vue suivante apparaît au bord droit. 40 points, c'est l'écart entre la largeur de l'écran et celle de la carte. Hors mode « Organiser », toutes les captures sont alignées.
   - Mon explication précédente était fausse (XCUITest qui aurait fait défiler la carte) : le décalage est identique au pixel près, que le test appuie sur la première vue ou sur les pages.
   - Cause probable (impossible à observer sans Mac) : entrer dans le mode et en sortir recrée la carte, car le menu de l'appui long y est retiré. Recréée pendant la fermeture du menu, la carte avait un instant des vues plus larges qu'elle. Le retour sur la première vue, sans repère, a aligné le bord droit de cette vue, et le décalage est resté.
   - Correction (`DailyPager.swift`, `DailySection.swift`) :
     - en mode « Organiser », la carte affiche sa vue du moment, fixe, sans défilement ; elle ne se balaie pas dans ce mode ;
     - partout ailleurs, une vue choisie par l'app (vue gardée, VoiceOver) se place contre le bord gauche de la carte (`anchor: .leading`).
   - Test : le test d'interface mesure l'alignement au lancement, en mode « Organiser », après les deux glisser et après « OK ». Il échoue au-delà de 8 points et garde deux captures de plus.
   - À confirmer par la CI et sur l'iPhone (section G, point 10).

## B. Résultats par domaine

Constats, puis corrections :

| Domaine | Constats (Bloquant / Majeur / Mineur / Amél.) | Corrigés | Tests ajoutés | Rapport |
|---|---|---|---|---|
| Nutrition et scanner | 0 / 7 / 11 / 2 | N-01, 02, 05, 06, 07, 10, 13, 17, P-04 | 7 | `nutrition.md` |
| Fitness, Habitudes, Productivité, Planning, Études, Accueil | 0 / 6 / 17 / 3 | F-01 à F-08 (F-09 et F-11 partiels), F-12 | 13 | `fitness-habitudes-planning-accueil.md` |
| Finances, Placements, Entreprise, Voyage, Auto, Ma vie | 0 / 7 / 19 / 3 | M-01 à M-08, M-11, 14 à 17, 19, 20 + minuit le 1er | 9 + 11 + 8 | `finances-et-autres.md` |
| Widgets, Studio, Store, données, notifications | 0 / 6 / 11 / 2 | W-02, 03, 04, 07, 08, 09, 10, 12, 15, 16 (partiel) | 11 + 8 + 5 + 2 | `widgets-studio-donnees.md` |
| Premium, StoreKit, onboarding, réglages | 0 / 2 / 7 / 4 | K-01 à K-07, K-09, K-10 | 6 + 9 + 3 + 16 | `premium-onboarding-reglages.md` |
| Interface et accessibilité | 0 / 4 / 7 / 4 | U-01 à U-07, U-10, U-13 (partiel) | règle `check_swift.py` | `interface-accessibilite.md` |
| Performance et build Release | 0 / 4 / 3 / 4 | R-02 volontairement NON appliqué (risque de perte de données) | — | `performance-release.md` |
| Confidentialité et conformité | 3 de processus / 5 / 10 | P-04, P-05, P-06, P-07 | — | `confidentialite-conformite.md` |
| Sécurité | 0 critique / 1 élevé / 2 moyens / 7 faibles | S-05 (script), S-07, S-08, S-09 | — | hors dépôt (voir C) |

En tout : 161 constats, plus deux défauts du mode « Organiser » trouvés par les tests d'interface et leurs captures. Le nombre de tests logiques exécutés passe de 1 241 à 1 361 (+120), puis 1 362 avec le test de l'alerte de repos, puis 1 370 avec les 8 tests du déplacement des cartes (vérifié au run 42438964850).

## C. Sécurité et confidentialité

### Sécurité
Aucun secret n'a été trouvé, ni dans le code, ni dans les 491 commits, ni dans les rapports de la CI. Les vérifications suivantes sont saines :
- tout le réseau passe en HTTPS, sans exception ATS ;
- Debug et Release sont bien séparés ;
- seuls les achats vérifiés comptent.

Le rapport détaillé décrit des scénarios d'attaque. Il est gardé hors de ce dépôt public : `~/ardane-tools/audits-prives/securite-2026-11-07.md`.

Risques et suites, après les décisions de l'utilisateur du 2026-11-07 :
1. **Élevé, ouvert.** Le dépôt est public, par choix de l'utilisateur pendant les corrections. D'anciens commits de `ci-report` contiennent des versions de test avec Premium débloqué. Suite : dépôt privé (CI payante), puis purge de `ci-report` par le support GitHub.
2. **Moyen, corrigé en partie.**
   - Fait : le workflow est durci.
     - Checkout épinglé par commit (v4.4.0), sans jeton gardé dans `.git/config`.
     - Plus aucune action tierce : Xcode est choisi par `xcode-select`.
   - Reste : `contents: write` (nécessaire pour publier le rapport et les versions de test), et aucune protection de `main`.
   - Réglages GitHub proposés à l'utilisateur : ruleset « Restrict deletions » et « Block force pushes » ; actions limitées à GitHub, épinglage SHA exigé.
3. **Moyen, ouvert.** Les clés de signature sont en clair sur le PC. Il faut les chiffrer, puis les remplacer.
4. **Faibles, corrigés.**
   - L'identité de signature est retirée du rapport public et des anciens rapports `history/`. Elle reste dans les anciens commits de `ci-report`, voir le point 1.
   - Le contrôle des versions TestFlight couvre maintenant l'app et l'extension de widgets. Un binaire absent fait échouer le contrôle.
   - Les montants d'argent des widgets sont masqués quand l'iPhone est verrouillé (`.privacySensitive`). Le rappel de facture n'affiche plus de montant.

La version de test Debug (IPA, Premium débloqué) est gardée, par décision de l'utilisateur.

### Confidentialité
- Aucune photo de repas ne quitte l'iPhone : c'est prouvé par le code (Vision et Core ML locaux, aucun envoi).
- App Privacy recommandé : « Data Not Collected », sans suivi. Âge : 9+.
- Écarts corrigés :
  - l'interrupteur « Contribuer à l'amélioration », qui ne faisait rien ;
  - l'effacement incomplet ;
  - la clé Stripe qui restait après la désinstallation ;
  - les notes pour l'examinateur, qui étaient fausses.
- Politique de confidentialité publiée corrigée sur ardane.app : version 3.1 du 7 novembre 2026, en français et en anglais. Elle couvre les widgets de prix actualisés seuls et la clé Stripe effacée à la réinstallation.
- Écarts restants :
  - lancement partout, Union européenne comprise, par décision de l'utilisateur : la déclaration de « commerçant » (DSA) est obligatoire dans App Store Connect › Business ; adresse, téléphone et courriel sont affichés publiquement dans l'UE ;
  - le vendeur individuel face à la règle 5.1.1(ix), argumentée dans les notes de revue ;
  - les points pour un juriste (§5 de `confidentialite-conformite.md`).

## D. Performance
- Aucune mesure n'a été faite sur un appareil. La CI ne mesure encore ni le temps de lancement, ni la mémoire, ni la taille du binaire (R-01).
- Estimations d'après le code :
  - l'app pèse au moins 150 Mo décompressée, dont environ 75 % de modèles Core ML (118 Mo) ;
  - l'extension de widgets ne charge ni modèle ni grosse base ;
  - le travail lourd (OCR, PDF, images) est hors du fil principal ;
  - il n'y a aucun `Timer` et les observateurs sont en `[weak self]`.
- La double lecture des données au lancement (R-02) est gardée exprès : elle protège contre une perte de données quand iOS lance l'app avant le premier déverrouillage.

## E. Corrections effectuées
Chaque correction a son problème, sa cause, ses fichiers et son test : voir les rapports par domaine, sections « Corrections faites », et les relectures `revue-*.md`. Principales corrections :
1. **Perte de données (W-02, M-07, F-06).**
   - Un fichier illisible n'est plus jamais écrasé par un état vide : il est copié dans `Recovery/`.
   - Les listes sont lues élément par élément.
   - L'ancien format des habitudes, tâches et études reste lisible.
   - Les photos encore utilisées ne sont jamais effacées.
2. **Premium.** Grâce de facturation, éligibilité à l'essai revérifiée, transactions écoutées dès le lancement, messages d'erreur clairs, lien des Conditions.
3. **Limites gratuites appliquées par le modèle.** 5 habitudes, styles et fonds Premium, quota de 10 analyses conservé.
4. **Santé.** Les objectifs caloriques automatiques sont bornés (mineurs, grossesse, IMC, plancher).
5. **Calculs.**
   - Une opération à minuit le 1er ne compte plus dans deux mois.
   - Les échéances du 29 au 31 restent justes.
   - Les placements sont dans la bonne devise.
   - Le budget non défini n'est plus affiché comme réel.
   - Les valeurs nutritionnelles inconnues ne sont plus comptées comme 0.
6. **Plantages et blocages.** Plus de plantage sur une quantité énorme, plus de séance « en cours » sans fin, plus de bouton « + » sans effet.
7. **Accessibilité.** Zones tactiles de 44 pt, VoiceOver, contrastes, confirmations de suppression.
8. **Sécurité.** Clé Stripe plus stricte et effacée à une installation neuve, image plafonnée, contrôle Release plus strict.
9. **Trouvés par les tests d'interface (section A.2).**
   - La fiche de l'alerte de repos ne s'offre plus qu'une fois.
   - Une carte large glissée sur la carte de gauche de la ligne du dessous change maintenant vraiment de place.
   - En mode « Organiser », la vue d'une carte à plusieurs vues reste dans la carte, au lieu de s'arrêter 40 points entre deux vues.

## F. Restes

### Bloquants pour la soumission (hors code, action de l'utilisateur)
- Contrat Paid Apps actif : banque, formulaire fiscal américain, TPS/TVQ.
- Déclaration de commerçant (DSA), obligatoire pour l'UE : adresse, téléphone et courriel publics.
- Les 3 produits Premium créés dans App Store Connect et joints à la version 1.0.
- Questionnaires App Privacy (« Data Not Collected ») et Age Rating (9+) remplis.
- Une version publique `[testflight]` à jour, choisie dans Build, après les tests manuels de la section G. Elle n'est produite qu'avec l'accord explicite de l'utilisateur.

### Décisions de l'utilisateur du 2026-11-07, appliquées
- Montants d'argent masqués sur l'écran verrouillé, et rappel de facture sans montant : fait (commit ba3317fb, 3 tests).
- Lancement partout, UE comprise : déclaration DSA à faire (ci-dessus).
- Politique de ardane.app corrigée : fait (version 3.1, publiée).
- Dépôt laissé public le temps des corrections : à repasser en privé ensuite, puis purge de `ci-report`.
- Workflow durci, version de test Debug gardée avec Premium débloqué : fait (commit c9e83807).

### Encore ouverts
- Chiffrement et remplacement des clés de signature.
- Réglages GitHub : ruleset de `main`, actions limitées et épinglées.
- Confirmation par la CI du correctif des vues décalées en mode « Organiser » (A.2, point 3), puis des deux correctifs du mode sur l'iPhone (G, point 10).

### Facultatifs (après le lancement)
- Tests de performance en CI (R-01), budget de taille des modèles (R-04), fichier `cnf-foods.json` en double (R-03).
- Polices fixes (U-09), accents des 12 couleurs d'app (U-08, figés par `AppPaletteTests`).
- Mineurs restants des rapports, chacun listé avec sa correction proposée.

## G. Tests manuels sur iPhone (impossibles en CI)
À faire sur la version `[testflight]` finale, sans Premium débloqué :
1. **Widgets sur le vrai écran d'accueil.** Petit, moyen et grand ; écran verrouillé ; boutons (habitude, ajout rapide, série faite). Après un redémarrage de l'iPhone, les widgets doivent retrouver leurs données une fois l'iPhone déverrouillé.
2. **Live Activities.** Séance de sport (repos, série suivante, fin), puis session d'étude.
3. **Notifications.**
   - À la première série d'une première séance, une fiche explique l'alerte de fin de repos. Après « Plus tard », elle ne revient pas aux séries suivantes.
   - La fin de repos arrive quand l'app est en arrière-plan.
   - Arrêter une session de concentration annule sa fin.
   - Les rappels de compte à rebours arrivent.
   - Toucher une notification ouvre le bon écran.
4. **Permissions.** Caméra (code-barres, plat ; refus), Calendrier (widget « À venir »), Mouvement (pas), Photos (enregistrer un fond).
5. **Achats sandbox.**
   - Essai mensuel, annulation dans Réglages, achat à vie.
   - Restauration après une réinstallation.
   - Le paywall ne propose l'essai qu'une seule fois.
6. **Mode gratuit.** Limite de 3 widgets, 5 habitudes (le « + » ouvre Premium), 10 analyses, styles verrouillés, Studio (« Autres widgets »).
7. **Données.**
   - Installer la nouvelle version PAR-DESSUS l'ancienne : toutes les données restent.
   - Fermeture forcée, puis réouverture.
   - « Effacer toutes mes données » ne laisse rien. Une réinstallation n'a plus de clé Stripe.
8. **Affichage.** Mode sombre, grande taille de texte, VoiceOver (cases à cocher, graphiques), iPhone en anglais (nouveaux textes).
9. **Couleurs modifiées.** Les boutons orange de Nutrition sont en texte foncé, et les textes secondaires des thèmes Carte, Dune et Glacier sont plus foncés : valider le rendu.
10. **Mon Quotidien, mode « Organiser ».**
    - Ouvrir le mode par un appui long sur la grande carte Nutrition, puis « Organiser… » : sa vue remplit la carte, sans cercle coupé à gauche ni vue suivante au bord droit (A.2, point 3). Pareil après « OK ».
    - Maintenir la grande carte Nutrition, puis la glisser sur la petite carte de **gauche** de la ligne du dessous : elle passe sous cette ligne. Avant la correction, rien ne bougeait (A.2).
    - La remonter de la même façon.
    - Deux petites cartes côte à côte échangent leur place.
    - Un balayage rapide fait défiler sans rien déplacer.
11. **Scanner : récapitulatif.** Un aliment incertain affiche l'étiquette « Estimation » sur une ligne, avec son icône (défaut vu sur l'iPhone, corrigé dans le commit 3835af0f).

## H. Checklist App Store Connect
Voir `confidentialite-conformite.md` §8 (champ par champ) et `docs/lancement/fiche-app-store.md`.
- Déjà prêt :
  - fiche en anglais et en français ;
  - bannières Header et Search Results ;
  - notes pour l'examinateur, version corrigée ;
  - URL d'assistance et de confidentialité, copyright ;
  - réponses App Privacy et âge recommandées.
- À faire :
  - contrat Paid Apps ;
  - 3 produits Premium ;
  - prix et pays (UE ou non) ;
  - questionnaires ;
  - captures en français (facultatives) ;
  - choix du build ;
  - « Manually release this version ».

## I. Build Release
- Vérifiée en CI (run 42421136593, Build 363) : la version Release, en configuration App Store, compile pour le simulateur. Les binaires de l'app et de l'extension ne contiennent ni le déverrouillage de test ni les écrans de capture : 0 trouvé.
- La version Release signée et envoyée sur TestFlight (`[testflight]`) n'est produite qu'avec l'accord explicite de l'utilisateur. Elle sera la version à choisir dans App Store Connect › Build.
- La version interne Premium (`[interne]`) suit la règle du projet : elle est envoyée après chaque série de corrections, pour les tests sur l'iPhone. Apple la bloque pour l'App Store et les testeurs externes.
- Dernière version interne vérifiée : Build 368 (run 42444945759, vue fixe en mode « Organiser »), comme les Builds 366 (run 42437604175) et 364 (run 42429465658) avant elle, signée avec une seule identité. Archive, export et contrôles des binaires de l'app et de l'extension réussis ; étiquette « Internal Only » confirmée par l'API d'Apple. Le rapport public de la CI ne contient ni l'identité de signature ni l'identifiant des profils.
