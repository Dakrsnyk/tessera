# Compositions d'accueil complètes pour les 10 styles (2026-11-14 et 15)

Complément demandé par l'utilisateur : les premières planches étaient trop vides. Ici, chaque style montre 5 écrans d'accueil d'Ardane remplis, où Nutrition, Fitness, Finances, Planning et Habitudes se voient en même temps. Rien n'est codé dans l'app.

- Images (hors dépôt) : `pub/rapports/design-2026-11-14/compositions/compo-01-saphir.png` à `compo-10-nocturne.png` (une planche de 5 téléphones et une légende par style), et `comparatif-A.jpg` à `comparatif-E.jpg` (le même écran dans les 10 styles).
- Sources : `compositions/compo-NN-nom.html`, base commune `compositions/compo-base.css` et `compo-base.js`, données `compositions/DONNEES.md`, direction `compositions/BRIEF-compositions.md`.

## La méthode
- **Une seule journée d'exemple** pour les 10 styles (jeudi 12 novembre, vue à 8 h 10, 13 h 20 et 19 h 05) : les styles se comparent à contenu égal.
- **Rien d'inventé** : le contenu de chaque carte a été relevé dans le code de l'accueil. Chaque planche dit, dans sa légende, ce qui existe déjà, ce qui est à adapter et ce qui est à développer.
- **Chaque style garde sa langue** : grille filetée pour Architecte, jauges pour Carbone, carnet pour Maison, rubriques pour Gazette, couloirs pour Stade, motifs noir et blanc pour Mono, parcelles pour Canopée, règles graduées pour Orbite, serif et champagne pour Nocturne.

## Les 5 compositions
| | Ce qu'elle montre | Mini-apps visibles | Ce que ça demanderait |
|---|---|---|---|
| A · Équilibrée (13 h 20) | la grille actuelle : Nutrition en pleine largeur, puis Séance et Habitudes, puis Planning et Budget, Top 3 dessous | les 5 | presque rien : tout existe déjà, c'est un changement d'habillage |
| B · Quotidien (19 h 05) | ce qu'il faut faire maintenant (la séance en cours), puis les mini-apps en un toucher, puis le reste de la soirée en lignes | 4 ou 5 | à adapter : mettre « Maintenant » en tête, brancher la rangée de mini-apps, le sommaire du soir |
| C · Éditoriale (8 h 10) | un grand titre, une phrase du jour, trois grands chiffres, la semaine lisible, les calories sur 7 jours | les 5 | à adapter : le trio de chiffres, le jour élargi dans la grille ; à développer : la phrase du jour (7 langues) |
| D · Compacte (13 h 20) | tout en un coup d'œil : 4 à 12 chiffres, la séance, les 3 prochains événements, le Top 3 | les 5 | à adapter : les cellules au chiffre court, la liste des prochains événements |
| E · Premium (19 h 05) | un élément dominant (le minuteur de repos), deux secondaires, une bande de chiffres | 4 ou 5 | à adapter : la carte dominante, la bande de chiffres, « Demain 10:00 » |

## Ce que les planches montrent
- **Finances** : la carte de l'accueil affiche aujourd'hui le montant à dépenser par jour, le dépensé du jour et la courbe de la semaine. « 412 $ restants » existe comme chiffre court. Le dépensé du mois et le solde d'un compte existent dans la mini-app, pas sur l'accueil : ils seraient « à adapter ».
- **Planning** : la carte actuelle est une grille de la semaine. La liste des prochains événements (14:00, 16:30, 18:30) est plus lisible dans les compositions B et D ; la donnée existe déjà, la liste serait « à adapter ».
- **Habitudes** : on ne coche pas depuis l'accueil aujourd'hui ; les maquettes ne le montrent donc pas.
- **Fitness** : il n'y a pas de série de jours de sport dans l'app ; les maquettes montrent la séance et « 2/4 séances » de la semaine.

## Avis du Chef
- **Les styles qui tiennent le mieux la densité** : Saphir, Architecte, Mono et Nocturne restent lisibles même sur l'écran compact. Architecte est le plus différent des autres : son écran D montre 12 chiffres sans paraître chargé.
- **Les styles qui gagnent le plus avec des écrans pleins** : Gazette et Maison, dont les premières planches semblaient vides, deviennent convaincants une fois remplis. Stade est fort pour la séance, moins naturel pour le budget et le planning.
- **L'organisation** : B « Quotidien » en haut de l'accueil et la grille A en dessous forment un seul écran qui défile ; c'est la proposition « Maintenant » de la recommandation précédente. D « Compacte » pourrait devenir plus tard un réglage (« affichage compact »). C et E sont les plus séduisantes à regarder, mais ce sont elles qui demandent le plus de travail.
- **La recommandation ne change pas** : Saphir le jour, Nocturne la nuit (les deux planches ont volontairement la même organisation), Architecte en alternative forte.

## Limites
- Maquettes rendues sur ordinateur, jamais vues sur un iPhone ; les polices Sitka, Bahnschrift et Segoe UI seraient remplacées par celles d'iOS (New York, SF Pro condensé ou arrondi), ce qui change un peu les largeurs.
- À 375 points de large (petits iPhone), quelques lignes passent sur deux lignes ou glissent sous la barre d'onglets ; à régler au moment de coder.
- Sur plusieurs écrans A, le Top 3 est sous la barre d'onglets : l'écran défile, comme dans l'app.
- Les grandes tailles de texte (accessibilité) et le mode sombre des styles clairs ne sont pas dessinés.
- Le message de l'utilisateur s'arrêtait au milieu de la description de la 5e composition : une suite éventuelle reste à traiter.
