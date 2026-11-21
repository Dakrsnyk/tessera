# 28 · Le feed voulu par l'utilisateur (2026-11-20)

L'utilisateur a envoyé trois exemples de « ce à quoi j'aimerais que mon feed ressemble » : la grille Instagram d'Amino (app de calories) et deux pubs Reels (motivationapp, impello.fit). Les fichiers sont privés et restent hors du dépôt.

## Ce qu'on en retient
1. **motivationapp, environ 11 s.**
   - **Plan :** un seul plan réel de nuit, sombre et d'ambiance. Par-dessus, en plein écran, l'écran verrouillé : la date, la grosse heure, et un widget de citation sous l'heure.
   - **Accroche :** « Crazy how a single widget fixes your whole mindset. » en petit texte natif.
   - **Rythme :** l'heure saute 1:11, 2:22, 3:33… 12:12, et la phrase du widget change à chaque saut (environ 0,5 s chacun).
   - **Effet :** une seule idée, aucun écran d'app, l'air d'une vidéo perso et pas d'une pub. Ça se regarde en boucle.
2. **impello.fit, carrousel.**
   - **Style :** photo de salle en noir et blanc, une carte d'interface translucide (verre) posée dessus, et un petit titre sobre (« Progressive overload, built into every session. »).
   - **Fin :** une diapo minimale, avec le logo et « DOWNLOAD IMPELLO, Available on the App Store ».
   - **Effet :** premium, monochrome, peu de texte.
3. **La grille d'Amino.**
   - **Identité :** une couleur de marque partout, et 3 posts épinglés qui présentent la marque (promesse et chiffres, trois iPhone, mascotte).
   - **Mélange :** des images fixes, des carrousels et des vidéos.
   - **Série récurrente :** « Healthy snack of the day », un produit et l'écran de l'app, revient chaque semaine.
   - **Le reste :** des posts de saison (Thanksgiving) et des phrases de motivation (« Your day is done. Your progress isn't. »).

## Ce qu'on applique à Ardane
- **Une grille cohérente :** les couleurs Ardane, et la couleur de la mini-app sur chaque post.
- **3 posts épinglés :** la promesse, Ardane sur trois iPhone, et la personnalisation (styles).
- **Des séries qui reviennent :** par exemple « Widget of the day » ou « Style of the week », sous forme de pub organique par mini-app.
- **Le format « écran verrouillé sur un plan réel » (motivationapp) :** très court (8 à 12 s), un vrai widget Ardane sous l'heure qui change à chaque saut. Bon pour Planning, Habitudes, Fitness, Études.
- **Le format minimal en noir et blanc avec une carte de verre (impello) :** carrousels et images fixes, surtout pour Fitness et Business.
- **Des images fixes (PNG) et des carrousels** en plus des vidéos.

## Ce qu'on ne copie pas (règles Ardane)
- Pas de produits ni de marques autres qu'Apple : la série « snack of the day » n'est possible qu'avec des aliments sans marque.
- Pas de visages à côté d'un écran Ardane, ni de faux témoignages.
- Pas de « 150,000+ users » ni de note tant que ce n'est pas vrai ; pas de « AI ».
- Seulement de vraies captures et de vrais exports.
- Pas de Google Play : l'app est sur iOS seulement.

## Posts épinglés v1 (2026-11-20)
- Fichiers : `pub/campagne-2026-11/epingles/`. 1 « Your whole life. One place. » avec le badge officiel (choix de l'utilisateur) ; 2 « Your day, at a glance. » (Fitness, accueil Clair, Studio ; Fitness plutôt que Nutrition pour ne pas montrer 1,672 et 1,122 côte à côte) ; 3 « Make it yours. » (Calories dans les 7 styles, mention Premium).
- Source : `~/ardane-tools/film/src/campaign/epingles/Posts.tsx` (Remotion `Still`). Déposés au QG (`post-epingle-1..3`).
- Limite : la capture Fitness a été prise avec Premium ; un compte gratuit verrait de petits badges Premium sur Exercises et Progress.

## 20 posts du feed v1 (2026-11-20 soir)
- Fichiers : `pub/campagne-2026-11/posts/01..20-*.png`, `apercu-grille.png` (3 épinglés + 20), `legendes.md` (légende anglaise + hashtags par post). Source `~/ardane-tools/film/src/campaign/posts20/Posts.tsx`. Déposés au QG (`post-feed-*`).
- Séries : Widget of the day (8), Style of the week (3, Premium), écran verrouillé (2), noir et blanc façon impello (3), motivation (2), Did you know? (2). Fond noir à la lumière de la mini-app, logo en bas à gauche, mention Premium en bas à droite.
- Mentions Premium : 02, 10, 18 (styles), 03 (« Last time »), 11 (accent rouge personnalisé), 14 (Rubis), 19 (widget Devoirs).
- À savoir : dates et heure des écrans verrouillés (06, 14) dessinées ; 09 et 13 montrent deux chiffres Business différents sur deux posts distincts.

## Section « Photos » du QG (2026-11-20)
- `ardane-hq` commit 4b389c4 (poussé) : boîte `workspace/marketing/_imports/photos/` (PNG, JPG, WebP, 30 Mo), onglet « Photos » du Marketing Hub, soumission à validation comme les vidéos importées (légende reprise de `post-feed-legendes.md`). 445 tests réussis. Les 23 posts y sont (vérifié dans le navigateur après redémarrage du QG).
- Les nouveaux posts fixes vont dans `_imports/photos/`, les vidéos restent à la racine de `_imports/`.
- Légende : le QG impose « Coming soon to the App Store » tant que `appReleased` est faux ; à revoir à la sortie de l'app.
