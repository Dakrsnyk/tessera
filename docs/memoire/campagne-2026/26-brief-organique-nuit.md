# 26 · Brief des pubs organiques par mini-app (nuit du 2026-11-20)

Demande de l'utilisateur (2026-11-20, avant de dormir) : « prépare le plus de vidéos possible sur les mini-apps jusqu'à mon réveil ».
- Ne garde que l'ESSENTIEL d'une bonne vidéo. Ne présente rien d'inutile juste pour copier le modèle ou sa dynamique.
- Fais ce qui est recommandé pour la visibilité et le temps de visionnage (watch time).
- Applique les leçons de la vidéo « 1 633 vidéos d'apps » (note 25).
- Chaque vidéo est ADAPTÉE à sa mini-app : sujet, problème du spectateur, couleurs, plans réels, musique.

## À lire
- `25-lecons-videos-apps.md` : les 32 leçons, le tableau de directives et la section « Pub Fitness organique v4.3 VALIDÉE » (le modèle).
- `Faits-verifies.md` : ce qui est vrai, gratuit ou Premium, ce qui n'existe pas. Les ajouts du 2026-11-19 comptent aussi.
- `24b-brief-agent.md` : outillage (bundle, rendu, disque, Pexels, Pixabay).
- Sources des modèles :
  - `~/ardane-tools/film/src/campaign/fitness-org/Film.tsx` (Fitness v4.3, validée) ;
  - `~/ardane-tools/film/src/campaign/planning-org2/Film.tsx` (Planning v2).
  - Son : `scripts/ad2/irl_org_audio.py`.

## Ce qui fait une bonne vidéo ici (validé par l'utilisateur)
- **Accroche** : la phrase en GROS dès la première image parle du problème du spectateur. Plan réel de 1 à 1,5 s.
- **App en gros plan** à 2-3 s au plus tard.
- **Démonstration lisible** d'UNE fonction forte : on touche, puis on voit l'effet. Ce qui est montré est vrai d'après le code. Les états avant et après viennent de vraies captures.
- **Écrans complets** de la mini-app, environ 2 s chacun, seulement ceux qui servent l'histoire.
- **Texte** : 2 couleurs, gros, court, une idée par plan.
- **Musique** :
  - d'un seul tenant, sans raccord ni répétition, vérifiée sur le signal ;
  - départ à 0,2 s ;
  - tempo MESURÉ, jamais supposé ;
  - drop sur l'arrivée de l'app ;
  - toutes les coupes sur les temps ;
  - fondu sur un temps avant la carte finale.
- **Fin** : plan réel court, puis carte « AVAILABLE ON THE APP STORE » de 1,5 s.
- **Durée** : 15 à 30 s. Plus court si l'histoire tient : le temps de visionnage compte plus que la durée.
- Pas de voix off, pas de zoom avant puis arrière, pas de fondu d'un widget dans un autre.
- Mention « Some widgets and styles With Premium » dans la zone sûre quand un élément Premium est à l'écran. Zone sûre : pas dans les 220 px du haut, ni les 380 px du bas, ni les 140 px de droite.

## Interdits
- Rien d'inventé : pas de chiffre tapé à la main, pas de capture d'avant le 2026-11-12, pas de capture ratée. Regarde chaque image : certaines `camp-*` montrent le mauvais écran.
- Pas de faux témoignage, ni de visage reconnaissable à côté d'un écran Ardane.
- Pas de marques autres qu'Apple. Icônes Apple autorisées : `film/public/apple-icons/`, jamais Utilities, jamais deux fois la même app sur une page, et attention à la date de Calendar.
- Ne recolore jamais une capture. Une couleur d'app ou d'accent n'est montrée que si l'app la propose vraiment, et la mention Premium s'affiche si elle est Premium.
- Pas de git, pas de CI, pas de push. Ne modifie pas le code de l'app, ni les autres films, ni les composants partagés.
- S'il manque une capture ou un export, demande-le au Chef dans ton rapport : lignes exactes à ajouter à `scripts/ad_export.txt` ou `ad_screens.txt`, au format des lignes existantes. En attendant, fais une version sans.

## Captures
- Kit le plus récent : `~/ardane-tools/kit-1120/adkit-en/` (`shots/`, `screens/`, `export/`), copie entière du run `[adkit-en]` du 2026-11-20. Tous les écrans y sont du même jour.
- Aussi : `film/public/campaign/kit/` (`camp-*` du 2026-11-19/20) et `film/public/kit2026/en/` (regarde la date de chaque fichier).
- Copie dans `film/public/campaign/<dossier-du-film>/` les fichiers que tu utilises.

## Livraison par film
- Dossier source : `~/ardane-tools/film/src/campaign/<mini-app>-org/`. Composition `Org<MiniApp>`, avec son propre registerRoot, sur le modèle de `planning-org2/index.ts`.
- Planche d'images clés regardée et corrigée AVANT le rendu.
- Rendu : `pub/campagne-2026-11/<mini-app>/organique/ardane-<mini-app>-organique-v1-1080x1920.mp4`.
- Vérifie la durée et la loudness (environ -14 LUFS), fais la planche du rendu (une image toutes les 0,5 s) et regarde-la.
- `notes.md` dans le même dossier : 3 accroches de rechange, leçons appliquées, fichiers, ce qui n'est pas vérifié.
- Disque : `df -h /c` avant le bundle (arrêt sous 4 Go). Un seul bundle par film, supprimé à la fin avec `tmp`.

## Ordre de la nuit
Planning v2 (à finir), puis Nutrition, Habitudes, Finances, Business, Études, Voyage. Pas de Voiture, Photos ni Citation (brief de campagne).

## v3 (2026-11-20, retour de l'utilisateur : « vraiment de bonnes bases, mais… »)
- **20 s au moins**, 30 s au plus (Fitness v4.3 : 29,75 s).
- **La personnalisation dans CHAQUE pub** (« élément clé »). Le Studio, partie Style, ouvert sur le widget clé de la mini-app : captures `camp-studio-<kind>-light|dark`. Puis le widget qui change de style par coupes franches : exports `camp-<kind>-<s|m>-st-<style>`, en Clair, Sombre et Minimal (gratuits), puis Pastel, Blossom, Aurore et Néon (Premium, avec mention). Même méthode que le plan Studio de Planning v4 et de Fitness v4.3 (`StudioStyle` / `StyleCycle`).
- **Plus de fonctions essentielles** de la mini-app : 2 ou 3 écrans clés de plus, chacun avec une idée et un texte court, pas une seule démonstration.
- **On garde** l'accroche, l'app à 1,25 s, la vraie démonstration (toucher puis effet), la musique d'un seul tenant, les coupes sur les temps, l'écran d'accueil final et la carte « AVAILABLE ON THE APP STORE ».

## Études organique v3 VALIDÉE par l'utilisateur (2026-11-20, « parfait ») : modèle de la v3
`pub/campagne-2026-11/etudes/organique/ardane-etudes-organique-v3-1080x1920.mp4` (25,7 s), source `~/ardane-tools/film/src/campaign/student-org/Film.tsx`. Déroulé :
1. accroche ;
2. écran verrouillé (widget gratuit) ;
3. semaine sur l'écran d'accueil ;
4. vrai toucher sur un widget interactif (3 → 2 due), avec mention Premium ;
5. trois écrans de fonctions clés (Exams, Review avec le temps d'étude, Grades), chacun avec une idée ;
6. « Make it yours. », le Studio (partie Style) et le widget héros dans 7 styles par coupes franches ;
7. écran d'accueil final dans un style de l'univers de la mini-app ;
8. plan réel, puis carte finale.
