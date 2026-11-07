# Rapport final : audit intégral prépublication d'Ardane (chantier 24, 2026-11-07)

> Ce que ce rapport prouve et ne prouve pas.
> - Tout ce qui est marqué « CI » a été exécuté par GitHub Actions sur un simulateur iOS (Xcode 26.3).
> - Rien n'a été exécuté sur un iPhone réel : Claude n'a ni Mac ni iPhone.
> - Ce qui exige l'iPhone figure à la section G (tests manuels).
> - « Aucun défaut trouvé » ne veut pas dire « aucun défaut ».

## A. État général

| Élément | Avant (run 42409228969, commit 6fad886f) | Après les corrections |
|---|---|---|
| Compilation de l'app et de l'extension (simulateur) | réussie | réussie : run 42415997352 (`[check]`), une seule erreur, dans un test, corrigée ensuite |
| Tests logiques | 1 241 réussis / 1 241 | voir section A.2 (run `[unit]`) |
| Tests d'interface (`[daily]` : MiniApp, Studio, Profil) | 30 réussis, 1 échec (`testDailyEditModeMovesHeldCardsAndScrollsOnSwipe`) | voir section A.2 (run `[daily]`) |
| Tests non exécutés | aucun test ignoré ; les tests de pub et de vidéo ne font pas partie de `[daily]` | idem |
| Couverture de code | non mesurée (la CI ne produit pas de rapport de couverture) | non mesurée |

### A.1 Équipe
Le Chef a coordonné 10 audits en parallèle :
- sécurité, confidentialité et conformité ;
- Nutrition ; Fitness et Planning ; Finances ; widgets et données ; Premium et réglages ;
- interface ; performance ; tests.

Il a ensuite lancé 7 équipes de corrections et 5 relectures indépendantes (`code-reviewer`), plus une passe de traduction. Chaque correction a été relue par un autre agent que son auteur. Les points bloquants des relectures ont été corrigés par le Chef.

### A.2 Résultats des tests après corrections
(complété à la fin des exécutions `[unit]` et `[daily]`)

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

En tout : 161 constats et 116 nouveaux tests logiques, dans 14 fichiers.

## C. Sécurité et confidentialité

### Sécurité
Aucun secret n'a été trouvé, ni dans le code, ni dans les 491 commits, ni dans les rapports de la CI. Les vérifications suivantes sont saines :
- tout le réseau passe en HTTPS, sans exception ATS ;
- Debug et Release sont bien séparés ;
- seuls les achats vérifiés comptent.

Le rapport détaillé décrit des scénarios d'attaque. Il est gardé hors de ce dépôt public : `~/ardane-tools/audits-prives/securite-2026-11-07.md`.

Risques restants, qui attendent toutes l'accord de l'utilisateur :
1. **Élevé.** Le dépôt est public. D'anciens commits de `ci-report` contiennent des versions de test avec Premium débloqué. Corrections : dépôt privé (CI payante), puis purge par le support GitHub.
2. **Moyen.** Le workflow a des permissions larges, des actions tierces épinglées par étiquette et aucune protection de `main`.
3. **Moyen.** Les clés de signature sont en clair sur le PC. Il faut les chiffrer, puis les remplacer.
4. **Faibles.**
   - L'identité de signature est publiée dans `ci-report`.
   - Le contrôle du binaire `[testflight]` est partiel.
   - Les widgets financiers sont visibles sur l'écran verrouillé.

### Confidentialité
- Aucune photo de repas ne quitte l'iPhone : c'est prouvé par le code (Vision et Core ML locaux, aucun envoi).
- App Privacy recommandé : « Data Not Collected », sans suivi. Âge : 9+.
- Écarts corrigés :
  - l'interrupteur « Contribuer à l'amélioration », qui ne faisait rien ;
  - l'effacement incomplet ;
  - la clé Stripe qui restait après la désinstallation ;
  - les notes pour l'examinateur, qui étaient fausses.
- Écarts restants, sur décision de l'utilisateur :
  - le texte de la politique publiée (widgets actualisés en arrière-plan, clé Stripe) ;
  - le statut de « commerçant » dans l'UE (DSA) ;
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

## F. Restes

### Bloquants pour la soumission (hors code, action de l'utilisateur)
- Contrat Paid Apps actif : banque, formulaire fiscal américain, TPS/TVQ.
- Les 3 produits Premium créés dans App Store Connect et joints à la version 1.0.
- Questionnaires App Privacy et Age Rating remplis.
- Une version publique `[testflight]` à jour, choisie dans Build, après les tests manuels de la section G.

### Importants (décision de l'utilisateur attendue)
- `.privacySensitive` sur les montants d'argent de l'écran verrouillé, et retrait du montant des factures dans les notifications.
- Lancement avec ou sans l'Union européenne (DSA).
- Correction de 2 phrases de la politique sur ardane.app.
- Dépôt privé avec CI payante, et purge de `ci-report`.
- Durcissement du workflow.
- Chiffrement et remplacement des clés de signature.

### Facultatifs (après le lancement)
- Tests de performance en CI (R-01), budget de taille des modèles (R-04), fichier `cnf-foods.json` en double (R-03).
- Polices fixes (U-09), accents des 12 couleurs d'app (U-08, figés par `AppPaletteTests`).
- Mineurs restants des rapports, chacun listé avec sa correction proposée.

## G. Tests manuels sur iPhone (impossibles en CI)
À faire sur la version `[testflight]` finale, sans Premium débloqué :
1. **Widgets sur le vrai écran d'accueil.** Petit, moyen et grand ; écran verrouillé ; boutons (habitude, ajout rapide, série faite). Après un redémarrage de l'iPhone, les widgets doivent retrouver leurs données une fois l'iPhone déverrouillé.
2. **Live Activities.** Séance de sport (repos, série suivante, fin), puis session d'étude.
3. **Notifications.**
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
- La compilation simulateur passe.
- La version Release signée (`[testflight]`) n'est produite qu'avec l'accord explicite de l'utilisateur.
- La version interne Premium (`[interne]`) suit la règle du projet, après la validation des tests.
