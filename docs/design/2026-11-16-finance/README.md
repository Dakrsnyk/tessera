# Refonte de Finance, étape 1 : conception (2026-11-16)

Demande du PDG : Finance « sans structure ni hiérarchie ». Deux étapes : d'abord la conception (5 directions en planches PNG), puis l'intégration SwiftUI, seulement après son choix. **À cette étape, aucune ligne de l'app n'est modifiée.** Style imposé : Cristal équilibré (`../2026-11-15-cristal/`), sans nouvelle identité. Rien de l'existant n'est retiré.

## Les planches
Sources HTML dans ce dossier ; images dans `pub/rapports/design-2026-11-16-finance/` (hors dépôt), avec `ecrans/` (chaque téléphone découpé) et `Ardane-Finance-refonte-etape1.pdf` (tout réuni).

| N° | Fichier | Contenu | Écrans |
|---|---|---|---|
| 0 | `00-analyse.html` | Finance aujourd'hui : 5 captures réelles de la CI annotées, 23 problèmes en 6 familles, tableau des fonctions (gratuit / Premium), ce qu'on garde | 5 captures |
| 1 | `01-minimaliste.html` | Le solde d'abord, le mois en 3 chiffres, une courbe par page, liste de pages fixe | 8 |
| 2 | `02-tableau-de-bord.html` | Le cockpit du mois : solde en verre, 4 tuiles, anneaux, cascade, calendrier des échéances | 9 |
| 3 | `03-analytique.html` | Le temps comme axe : période en tête, novembre face à octobre, habitudes, projections, constats | 8 |
| 4 | `04-quotidienne.html` | Aujourd'hui et les 14 prochains jours : « encore X $ aujourd'hui », ajout rapide, alertes, échéancier | 8 |
| 5 | `05-hybride.html` | Le meilleur des quatre : reste et « par jour », 3 tuiles, « À venir », analyse rangée dans sa page | 9 |
| C | `06-comparaison.html` | Notes sur 10 (10 critères), avantages et limites, recommandation, questions pour le PDG, lots de l'étape 2 | — |

Chaque planche finit par la table « Rien n'est retiré : où se trouve chaque fonction existante » (`F.mapNote`). Les nouveautés sont marquées dans l'écran (jeton violet « Nouveau ») et dans la légende (tag « Nouveau »).

## Notes (sur 100)
Minimaliste 77 · Tableau de bord 70 · Analytique 70 · Quotidienne 76 · **Hybride 85** (détail critère par critère dans `06-comparaison.html`). Notes de jugement, pas de tests avec des utilisateurs.

## Recommandation
La direction 5 (hybride), avec la retenue de la 1 : un seul chiffre vedette (le reste du mois et le « par jour »), revenus / dépenses / solde en trois tuiles, « À venir » en tête, une seule action « Ajouter », liste de pages fixe, Opérations et Relevé réunis, factures et montants fixes réunis en un échéancier, graphiques aux couleurs séparées (revenus en vert, dépenses en encre, mois en cours hachuré, repère du rythme). Trois nouveautés seulement : « après les factures à venir », recherche dans les opérations, constats écrits dans l'Analyse (Premium).

Questions pour le PDG : direction ; chiffre vedette (reste ou solde) ; une action « Ajouter » ou deux boutons ; pages réunies (Opérations + Relevé, Factures + Dépenses fixes) ; nouveautés à garder.

Étape 2 proposée (après son choix), en 4 lots, chacun relu, compilé par la CI et livré en version interne : (1) page principale réordonnée sans nouveauté ; (2) noter et retrouver (feuille Ajouter, fiche d'opération, Opérations + Relevé) ; (3) pages Budget et récurrents, Revenus et dépenses, Épargne ; (4) nouveautés retenues avec leurs tests.

## Fichiers communs
- `finance.css` (préfixe `fn-`) et `finance.js` (objet `F`, données `FIN`, liste `FEATURES`) : à charger après `../2026-11-15-cristal/cristal.css` et `cristal.js`. Une seule journée d'exemple, celle des planches Cristal : jeudi 12 novembre 2026, 13 h 20, budget 1 200 $, 788 $ dépensés, 412 $ restants, 21,68 $ par jour pendant 19 jours, 14,50 $ aujourd'hui, compte chèques 1 846,20 $ (départ 1 484,20 $ + 1 150 $ de salaire − 788 $). Toutes les autres données (opérations, factures, objectifs, six mois) en découlent et sont cohérentes entre les planches.
- Couleurs propres à Finance : revenus vert `#1F8A62`, dépenses encre ardoise `#45566E`, dépassement rouge `#C93A3A` (seulement), mois précédent gris `#9AA6B8`, nouveauté violet `#5B3FC4`. Jamais la couleur seule : signe, mot ou motif.
- `render.py` : copie de celui de Cristal, sortie vers `pub/rapports/design-2026-11-16-finance/`.

## Rendu
```
cd docs/design/2026-11-16-finance
~/ardane-tools/venv/Scripts/python.exe -I render.py 05-hybride.html --phones
~/ardane-tools/venv/Scripts/python.exe -I render.py 05-hybride.html --query check
~/ardane-tools/venv/Scripts/python.exe -I ../2026-11-15-cristal/make_pdf.py <sortie.pdf> 1800 <images…>
```
Les contours rouges de `--query check` sur le premier libellé des graphiques SVG et sur les rangées de puces qui défilent sont de fausses alertes.

## Limites
- Maquettes rendues sur ordinateur avec Inter ; sur iPhone, SF Pro change un peu les largeurs. Grandes tailles de texte et mode sombre non dessinés (toute planche se rend en sombre avec `--query mode=dark`, non vérifié ici).
- Les captures de la planche 0 viennent de la CI (Build 441), avec ses données de test (budget 2 400 $), pas de la journée d'exemple.
- Planche 3 : la date d'arrivée prévue d'un objectif demande de garder la date de chaque versement (l'app ne garde que le total).
