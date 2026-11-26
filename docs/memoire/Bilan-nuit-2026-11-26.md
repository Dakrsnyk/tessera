# Bilan de la nuit du 2026-11-26

Budget utilisé : 4 % de la limite hebdomadaire (plafond fixé : 40 %), 1 % de la fenêtre de 5 h.
Seuls les rapports de la CI GitHub prouvent qu'une chose compile ou que des tests passent ; chaque ligne « vérifié » cite le run concerné.

## Fait et vérifié

- **Un seul outil « Style »** dans Créer et le Studio (Thème et Style fusionnés). Les anciens liens « theme » et « themes » ouvrent cet outil.
  - Gratuit : les 4 styles d'origine (Minimal, Clair, Sombre, Monochrome). Ils gardent la couleur choisie par la personne.
  - Premium : 500 autres styles, répartis en 20 familles.
  - Un style change tout l'aspect du widget, jamais son contenu. Les parties que la personne a masquées le restent.
  - Vérifié :
    - Tests `StyleLibraryTests` et `StyleLot2Tests`.
    - Test d'interface du Studio dans le run 598.
    - Capture `studio-theme.png` du run 598 relue : 4 styles d'origine en tête.
- **Qualité des 500 styles**
  - Règles vérifiées par `scripts/styles/library.py check` (0 erreur) :
    - Deux styles diffèrent sur au moins 3 axes sur 7.
    - Contraste du texte d'au moins 4,5:1.
  - Planche réelle, rendue par l'app elle-même (runs 593 et 594) : `docs/design/2026-11-26-500-styles/`.
  - Environ 170 styles retouchés après relecture page par page.
  - 23 accroches réécrites pour coller au nouveau rendu (run 598).
- **Moteur de rendu : nouveaux éléments**
  - Textures : guilloché, marbre, terrazzo, lin, topographie, métal brossé, rayons.
  - Bordures : ticket, couture, biseau, filet intérieur.
  - Effets : ombre longue, petites capitales.
  - Montants des dispositions Cartes et Données lisibles : couleur des chiffres du style, avec une pastille de couleur devant le nom.
- **Store** : une vitrine avec un style par famille, un style de la semaine pris parmi les styles Premium, et un toucher qui ouvre le Studio dans ce style. Vérifié par les tests du run 597.
- **Créer** : chaque catégorie démarre sur un des 4 styles gratuits, donc plus de cadenas pour un compte gratuit. Vérifié par le run 597.
- **Finances › Analyse**
  - Contenu : taux d'épargne, projection de fin de mois, catégories comparées à la moyenne des 3 derniers mois, plus grosses hausses, dépenses récurrentes, dépenses par jour de la semaine.
  - Projection : seules les dépenses notées à la main sont extrapolées ; les paiements fixes encore dus (le loyer, par exemple) sont ajoutés tels quels.
  - Vérifié par `BudgetAnalysisTests` dans le run 597.
- **Relecture des chantiers 58 à 60 corrigée** : paquets vides retirés, date de création conservée, dépenses planifiées limitées à leur fenêtre, code mort du Top 3 retiré.
- **Performances** : 9 corrections issues d'un audit, notamment :
  - cache des photos dans l'app seulement (jamais dans l'extension widget, qui a peu de mémoire) ;
  - réglages réécrits seulement quand ils changent ;
  - photos décodées hors du fil principal.

  Vérifié par `PerformanceEdgeCaseTests` et par les runs 597 et 598.
- **Traductions** : 1 018 textes traduits dans les 6 langues ; il ne reste aucun texte non traduit.
- **CI**
  - Run 592 `[check]` : vert.
  - Run 595 : build interne Premium sur TestFlight, « Internal Only » confirmé.
  - Run 596 `[unit]` : 2 échecs, tous deux corrigés.
  - Run 597 `[unit]` : 0 échec.
  - Run 598 `[studio]` : 400 tests réussis, 0 échec.
  - Build interne final : run 599, **build 599 envoyé sur TestFlight** (Premium débloqué, interne seulement).
- **Essai de colibri** (IA locale) : mesuré sur de vraies photos de repas, et **non retenu**.
  - Rappel de 42 % et précision de 38 %.
  - Environ 14 s par photo.
  - Grammes inutilisables.
  - Détails : `Essai-colibri-2026-11-26.md`.
  - Ta règle de sécurité (« l'utilisateur ne parle jamais à l'IA ») est notée dans `Decisions.md`.

## Fait, pas encore vérifié sur l'iPhone

- L'outil Style, le Store et Finances › Analyse, sur le vrai téléphone : à toi de les voir dans le build interne.

## Compromis assumés (validés par le PDG le 2026-11-26)

- Un utilisateur gratuit qui avait un ancien widget en Moderne, Carte, Doux, Compact, Sous-bois ou Glacier le voit passer en Minimal sur son écran d'accueil. L'app n'étant pas publiée, personne n'est touché.
- Les anciens thèmes Premium (Aurore, Néon, Éditorial…) ne sont plus choisissables dans le Studio. Les widgets déjà faits les gardent.

## Pas fait / à décider

- `Top3CompletedTests` et les méthodes de `ProductivityState` : on les garde ou on les retire ?
- Le widget « voiture » pour l'écran verrouillé est encore dans la galerie ; il retombe sur l'horloge.
- Version publique `[testflight]` : attend ton accord.
- **Rappel :** le dépôt GitHub est public pour la CI. Repasse-le en privé.

## Ressources utilisées

- **Agents :**
  - ios-developer (moteur et Finances) ;
  - ui-ux-designer (relecture des styles) ;
  - code-reviewer (a trouvé une collision de nom `StyleLibrary`) ;
  - audit de performances (opus) ;
  - qa-tester.
- **Outils installés :** colibri v2.2.0 (signature SHA vérifiée) et le modèle LFM, dans `~/ardane-tools/colibri`, hors du dépôt.
- **CI :** runs 591 à 598, plus le build interne final.
