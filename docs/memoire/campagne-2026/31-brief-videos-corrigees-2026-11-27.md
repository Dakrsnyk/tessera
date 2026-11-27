# 31 · Brief : corriger et créer les vidéos et images de la campagne (2026-11-27)

À transmettre tel quel à une nouvelle session. Réponds en français. Ce brief dit **quoi modifier, quoi créer, quoi retirer**, et où se trouve ce qui a déjà été fait. Les notes viennent de la revue intégrale du 2026-11-27 : 63 vidéos et 34 images du QG, vues image par image, **sans le son**.

## 0. Pourquoi
- Avec les pubs actuelles, la pub payée (1 000 $ CA/mois) n'est remboursée qu'au **mois 6**. Ce chiffre suppose un rythme de 2 posts/jour sur TikTok et 2 sur Instagram.
- Avec des pubs corrigées, elle est remboursée au **mois 2**, et le revenu par jour est environ doublé à la fin de l'an 1 (≈ 227 $ contre ≈ 112 $).
- Source : `docs/marketing/Analyse-integrale-Ardane-et-pubs-2026-11-27.md`, sections 3 et 4.
- Le rythme visé est de **4 contenus par jour** (2 TikTok + 2 Instagram, contenus distincts), soit environ 120 par mois. Il faut donc un **stock varié**, pas 30 fois le même gabarit.

## 1. À lire avant de commencer (dans cet ordre, court)
1. `docs/marketing/Analyse-integrale-Ardane-et-pubs-2026-11-27.md` : sections 2 (Gratuit / Premium) et 3 (pubs). Les annexes B à E donnent la revue détaillée de chaque vidéo et image.
2. `docs/memoire/campagne-2026/30-brief-nuit-2026-11-22.md` : règles validées, musique, méthode.
3. `docs/memoire/campagne-2026/25-lecons-videos-apps.md` (les 32 leçons) et `28-feed-modele.md` (le feed voulu).
4. `docs/memoire/campagne-2026/27-bilan-nuit-2026-11-20.md` : ce qui existe déjà. Ne refais pas la même pub.
5. `docs/memoire/campagne-2026/Faits-verifies.md` et `Legendes-et-CTA.md` : seulement du vrai.
6. Retours de l'utilisateur, dans `C:/Users/Etudiant/.claude/projects/C--Users-Etudiant-Documents-GitHub-tessera/memory/`, le plus récent d'abord :
   - `feedback-pubs-accueil-complet-zoom-style.md`
   - `feedback-pubs-organique-20s-personnalisation.md`
   - `feedback-pubs-organique-fitness-da.md`
   - `feedback-pubs-rythme-sous-titres.md`
   - `feedback-pubs-widgets-realisables.md`
   - `feedback-pubs-mecanique-widget-couleurs.md`
   - `feedback-pubs-fluidite-voix-et-montage.md`
   - `feedback-apercus-avant-rendu.md`
   - `feedback-deposer-videos-qg.md`
   - `feedback-build-d-abord.md`
   - `feedback-limite-hebdomadaire-85.md`

## 2. Où est ce qui a déjà été fait
- **Sources Remotion** : `C:/Users/Etudiant/ardane-tools/film/src/campaign/<film>-org/`. Les composants communs sont dans `campaign/lib.tsx`. Le modèle validé est `irl/IrlFitness.tsx`.
- **Synchronisation avec le dépôt** : `scripts/ad2/film_sync.py`. Lance `import` avant tout `export`, sinon le dépôt est écrasé.
- **Captures de l'app** : `~/ardane-tools/film/public/campaign/kit/<nom>.png`, avec le catalogue `scripts/ad2/pub26_v2/catalogue-captures.json`.
  - Regarde chaque capture avant de l'utiliser.
  - Si une capture manque ou est périmée, demande un nouveau kit par la CI (`[adkit-en]`, ou `[adkit-img]` avec une ligne `only …`). Un push annule un run en cours.
- **Travail par film** : `~/ardane-tools/campaign/<film>-org/` (stills, outils, `audio.py`). Musiques et plans réels : `music-candidates.txt` et `footage-candidates.txt` dans `~/ardane-tools/campaign/`. Le brief commun est `BRIEF-AGENT.md` dans le même dossier.
- **Livraison** : `C:/Users/Etudiant/Documents/GitHub/ardane-hq/workspace/marketing/_imports/`.
  - Une seule version par pub dans `_imports/`.
  - Les anciennes versions vont dans `_imports/_archives-variantes/`.
  - Les images sont dans `_imports/photos/`, et leurs légendes dans `photos/affiches-legendes.md`.

## 3. Les 6 corrections à appliquer à TOUT contenu (modifié ou nouveau)
1. **Accroche**
   - Gros texte qui parle au spectateur dès la 1re image, jamais un écran noir ni un logo seul.
   - App visible à 2-3 s ; ouverture de 3 s au plus.
2. **Premium honnête et lisible**
   - Tout widget, style ou fonction Premium porte une pastille « Premium » lisible : au moins 30 px de texte sur 1080 de large, en gras.
   - Modèle de la pastille : celle d'affiche-09-v2, fond `#F2D27A`, texte `#2A1E00`. Elle remplace les « With Premium » gris de 10 à 14 px.
   - Ne jamais bâtir la promesse principale sur un widget Premium sans le dire.
   - Widgets Premium souvent montrés à tort comme standard : Prochaine série / Série faite, Minuteur de repos, Macros détaillées, plus de 3 habitudes, Concentration, Devoirs, Cartes de révision.
3. **Montrer le gratuit**
   - Au moins un plan avec un style gratuit : Minimal, Clair, Sombre ou Monochrome. Les styles Premium montrés sont Néon, Aurore, Blossom, Luxe, Carbone…
   - Dire ce qui est gratuit et qui impressionne :
     - 3 widgets gratuits et 10 analyses de plat ;
     - codes-barres illimités ;
     - séance en direct sur l'écran verrouillé ;
     - tâches et habitudes cochées depuis l'accueil ;
     - dépense rapide ;
     - Mon Quotidien.
4. **Geste réel**
   - Chaque action montre le doigt ou une onde de toucher, puis l'effet.
   - Plus de valeurs qui changent seules.
5. **Carte de fin « AVAILABLE ON THE APP STORE »**, 1,5 s, lisible, à la fin de CHAQUE vidéo. C'est la décision du PDG du 2026-11-27 : les vidéos sortent après la mise en vente, donc pas de « Coming soon ».
   - Une fin sur l'icône seule ne suffit pas.
   - Jamais « free » ni « gratuit » sans nuance.
   - Un verbe (« Get Ardane ») reste une option à proposer, pas une règle.
6. **Studio et personnalisation dans chaque vidéo**
   - Montrer l'accueil complet, puis zoomer sur le widget, faire l'action, et changer le style de tout l'accueil (règle validée).
   - Montrer l'essai gratuit du Studio : un utilisateur gratuit peut appliquer n'importe quel style Premium et le voir « Sur mon écran ». Seul « Enregistrer » est bloqué. C'est un argument fort et vrai.

Durée : 20 à 30 s pour l'organique, 15 s pour les formats courts. Pas de voix off en organique ; la voix reste pour les pubs payées, sur le modèle de Main Pub v2.5.

### Règles déjà validées (rappel, ne pas réinventer)
- **Accroche** : plan réel de 1 à 1,5 s, app à 1,25 s, puis un iPhone entier qui monte sur l'écran verrouillé. L'ouverture dure 3 s au plus.
- **Mise en scène** :
  - Jamais un widget seul.
  - Ordre : accueil complet avec de vraies icônes Apple, zoom, toucher puis effet, retour à l'accueil, puis changement de style de tout l'accueil.
  - Icônes : `film/public/apple-icons/`, jamais Utilities, jamais deux fois la même.
  - Mêmes widgets d'un style à l'autre, coupes franches, aucune double image.
  - Pas de zoom puis dézoom entre deux fonctions d'une même mini-app.
- **Couleur de la mini-app** sur le fond de la vidéo et sur le fond d'écran :
  - Fitness : noir, rouge et gris. Le widget combiné Next set | Consistency sur fond rayé est validé.
  - Planning : cyan.
  - Finances : vert.
  - Business : lilas.
- **Écrans et texte** :
  - écrans complets d'environ 2 s, seulement ceux qui servent l'histoire ;
  - texte gros en 2 couleurs, une idée par plan ;
  - texte qui défile mot à mot sur les plans réels ;
  - dernier plan réel court avant la carte.
- **Musique** :
  - Pixabay, sans Content ID ;
  - un seul morceau d'un bout à l'autre, départ à 0,2 s ;
  - tempo mesuré, coupes sur les temps, drop sur l'arrivée de l'app ;
  - environ −14 LUFS ;
  - passages déjà pris : note 30, « Suivi de la nuit ». Ne pas les reprendre.
- **Zone sûre** : aucun texte dans les 220 px du haut, ni dans les 380 px du bas, ni dans les 140 px de droite.
- **Honnêteté** :
  - Seulement de vrais exports ou captures, jamais recolorés.
  - Une seule date d'export par mini-app, jamais deux chiffres différents d'une même mini-app.
  - « Demo data » si besoin.
  - Mots interdits : « AI », « 100% », « exact ».
  - Aucune marque autre qu'Apple : pas d'écran Voyage Program (TP 258, Pastéis de Belém), attention à la voiture « Civic ».
  - Aucun visage, aucun faux témoignage. Le téléphone en main est permis, mains seulement.
  - Écrire « Cherry blossom », pas « Blossom ».
- **`Faits-verifies.md` § 1 est périmé sur les styles** (« 10 gratuits sur 57 »). Au 2026-11-27 :
  - 4 styles gratuits (Minimal, Clair, Sombre, Monochrome) sur 504 ;
  - 29 types de widgets gratuits sur 90 ;
  - source : analyse intégrale, section 2.
- **Séries** :
  - refaire un format qui marche au moins 10 fois, même musique, sujet différent ;
  - jamais republier à l'identique ;
  - deux structures proches (POV, Oddly satisfying) jamais à la suite.

## 4. Vidéos : quoi faire, une par une
Les notes /10 viennent de la revue du 2026-11-27.

### Publier telles quelles, ou avec la seule fin corrigée (point 5)
| Vidéo | Note | Retouche |
|---|---:|---|
| pub-organique-scan-v1 | 8,5 | ajouter la fin avec verbe |
| pub-organique-nutrition-v5.1 | 8 | fin avec verbe seulement |
| pub-organique-papier-v1 | 8 | fin avec verbe seulement |
| pub-organique-planning-v2 | 8 | fin avec verbe seulement |
| pub-organique-budget-v1 | 8 | fin avec verbe ; agrandir le téléphone du début si possible |
| pub-organique-finances-v3 | 8 | appel à l'action plus gros |
| pub-organique-cours-v1 | 7,5 | couper l'image noire du début |

### Modifier (garder la pub, corriger le défaut nommé)
| Vidéo | Note | Correction |
|---|---:|---|
| pub-organique-voyage-v3 | 8 | retirer le plan en double ; pastille Premium lisible |
| pub-organique-battle-v1 | 7,5 | fin avec verbe |
| pub-organique-business-v4 | 7,5 | pastille Premium lisible |
| pub-organique-etudes-v3 | 7,5 | étiqueter « Study time » et « Grades » |
| pub-organique-gym-v1 | 7,5 | pastille Premium lisible |
| pub-organique-huit-v1 | 7,5 | ouverture trop lente : accroche en ≤ 3 s |
| pub-organique-liste3-v1 | 7,5 | le n° 1 est Premium : le dire, ou le remplacer par un widget gratuit |
| pub-organique-lock-v1 | 7,5 | titres trop petits |
| pub-organique-pov-v1 | 7,5 | ouverture en double |
| pub-organique-satisfying-v1 | 7,5 | fin avec verbe |
| pub-organique-top5-v1 | 7,5 | rythme (couper les plans longs) |
| voici-ton-telephone-avant-apres-v5 | 7,5 | dire ce qui est gratuit et ce qui est Premium |
| pub-organique-depart-v1 | 7 | texte lisible sur les photos (voile sombre, texte plus gros) |
| pub-organique-fitness-v4.3 | 7 | widget Premium présenté comme standard : pastille, ou widget gratuit (Séance du jour, Série d'entraînement) |
| pub-organique-inspo-v1 | 7 | accroche floue : la réécrire sur le spectateur |
| pub-organique-journee-v1 | 7 | scène Premium à marquer |
| pub-organique-main-v1 | 7 | sous-titres ; retirer les doublons |
| pub-organique-accueil-v1 | 6,5 | nom « Ardane » tôt ; mention Premium |
| pub-organique-habitudes-v3 | 6,5 | 4 habitudes = Premium (3 en gratuit) : passer à 3 ou marquer ; pastille lisible |
| pub-organique-tuto-v1 | 6,5 | le résultat montré est Premium mais vendu comme gratuit : corriger |
| pub-organique-verrou-v1 | 6,5 | trop court, texte minuscule : rallonger à 15 s, texte plus gros |
| pub-organique-affiche-03-v1, -04-v1, -06-v1 | 5,5 à 6,5 | accroche, geste, fin avec verbe ; widget qui ne masque plus l'iPhone |

### Fadein (30 vidéos de 10 s, même gabarit, notes 4 à 6)
- **Garder et refaire à 15 s** : 14, 15, 16, 20, 22, 23.
  - Ouverture sur l'accueil complet, pas sur du noir.
  - Un geste réel, un changement de style, une fin avec verbe.
- **Retirer** : 11 et 28, à déplacer dans `_archives-variantes`.
- **Les autres** (01-10, 12, 13, 17-19, 21, 24-27, 29, 30) : à archiver. Ne garde que celles qui apportent un sujet nouveau une fois refaites. Défauts précis :
  - 02 : valeur « 6/3 » impossible ;
  - 05 : widget « Day 4 » ;
  - 09 : la promesse « seven styles » n'est pas tenue à l'écran.

### Pubs principales
- **pub-principale-v5-restylee-v3** (58,9 s, note 5) et **main-pub-all-your-essentials-v2.5** (56 s, note 5,5) : trop longues pour l'organique.
- Garder la v2.5 comme pub longue payante seulement, après correction des points 2, 3 et 5.

## 5. À créer
1. **Nouvelle pub principale, 25-30 s** (organique et pub payée), à partir du modèle validé Main Pub v2.5 (voir `feedback-pubs-fluidite-voix-et-montage.md`).
   - Accroche sur le spectateur.
   - Puis 3 mini-apps maximum (scan nutrition, séance sur l'écran verrouillé, tâches cochées depuis l'accueil).
   - Puis le Studio qui restyle tout l'accueil, avec un style gratuit puis un style Premium marqué.
   - Fin avec verbe.
   - Versions TikTok et Instagram Reels : même film, textes placés hors des zones d'interface de chaque réseau.
2. **« Essaie tous les styles gratuitement »** (20 s).
   - Un utilisateur gratuit ouvre le Studio, fait défiler les 504 styles, en applique trois sur son widget et voit « Sur mon écran ».
   - Il touche « Enregistrer » et voit l'offre.
   - Rien n'est inventé : c'est le vrai parcours de l'app.
3. **« Ce que tu as gratuitement »** (20-25 s) : 3 widgets, 10 analyses de plat, codes-barres illimités, séance en direct, tâches et habitudes interactives, 4 styles. Fin : « Premium si tu veux tout ».
4. **Séance en direct sur l'écran verrouillé** (15-20 s) : fonction gratuite et spectaculaire, encore peu montrée.
5. **Variété humaine** : 4 à 6 vidéos avec des mains, des dos ou des silhouettes en situation réelle (Pexels).
   - Règle : aucun visage reconnaissable à côté d'un téléphone Ardane.
   - Aujourd'hui aucune pub ne montre de personne.
6. **Formats Instagram distincts** : carrousels (4 à 6 images), « astuce » et « avant / après », sur le modèle des meilleures images (post-feed-02 néon, post-feed-05 astuce habitudes : 8,5). Instagram et TikTok reçoivent des contenus séparés chaque jour.

Objectif de stock avant de publier à 4 par jour : environ 2 semaines d'avance.
- 28 contenus TikTok, dont au moins 20 vidéos.
- 28 contenus Instagram, dont environ 10 carrousels ou images.
- Le tout tiré des sections 4 et 5, sans répéter le même gabarit plus de 3 fois par semaine.

## 6. Images et feed (34 images)
- **Déjà corrigées le 2026-11-27** : `affiche-09-v2.png` et `post-feed-11-widget-fitness-v2.png`, avec la pastille « Premium widget ». Les originaux sont dans `_archives-variantes`.
- **À corriger** :
  - post-feed-06 : titre rogné.
  - post-feed-10 et 18 : la mention Premium est posée sur la barre de recherche ; post-feed-18 a aussi des compteurs illisibles sur le style Aurora.
  - post-feed-16 : « Habits · Habits ».
  - affiche-07 : « bon voyage! » en français dans une pub anglaise.
  - affiches 04, 05, 07, 08, 09, 11 : le widget masque l'iPhone.
  - Posts noir et blanc avec photo (03, 09, 15) : titre deux fois plus gros et assombrir la photo, ou passer au gabarit fond uni.
- **Épinglés** :
  - l'épinglé 1 montre le badge App Store avant la mise en ligne : le retirer ;
  - aucun épinglé n'a de légende : en écrire une.
- **Légendes** : un crochet distinct de l'image, et un appel à l'action cohérent avec le point 5.

## 7. Méthode et garde-fous
1. **Méthode par film** (note 30, « Méthode ») :
   - Script dans `notes.md`, critiqué contre la note 25.
   - Planche de 8 à 12 images clés, regardée et corrigée.
   - Brouillon à demi-taille, puis planche de contrôle (une image toutes les 0,5 s), regardée.
   - Rendu final en 1080x1920 ; mesurer la durée et le niveau sonore (LUFS).
   - 3 accroches de rechange.
   - Avant tout rendu propre d'une pub nouvelle ou refondue, envoyer les images clés (PNG) à l'utilisateur.
   - Ne rends jamais 30 vidéos d'un coup.
2. **Une seule version par pub** dans `_imports/`, l'ancienne dans `_archives-variantes/`. Mettre à jour `photos/affiches-legendes.md` et les légendes.
3. **Vérifier chaque rendu** (images regardées, pas de noir, durée, lisibilité de la pastille Premium) avant de le dire prêt. Aucune validation sans preuve.
4. **Pas de CI en chaîne** pour des planches. Un nouveau kit de captures seulement s'il manque un écran.
5. **Budget** : rester sous 85 % de la limite hebdomadaire. Pas d'agents coûteux en parallèle sur le même film ; un agent par film si tu délègues.
6. **Ne pas toucher au code de l'app** dans cette session. Si un écran de l'app est faux, le noter pour la session principale.
7. **Fin de session** : mettre à jour `docs/memoire/Chantiers.md` et `campagne-2026/27-bilan…` (ou un nouveau bilan 32), avec la liste des vidéos livrées, modifiées, retirées et à valider.

## 8. Ordre conseillé
1. Les 7 vidéos « telles quelles » : fin avec verbe seulement. C'est rapide et publiable tout de suite.
2. La nouvelle pub principale de 25-30 s, en brouillon puis en rendu.
3. « Essaie tous les styles gratuitement » et « Ce que tu as gratuitement ».
4. Les vidéos à modifier (section 4), les meilleures notes d'abord.
5. Les 6 fadein refaites, puis les créations 4 à 6 et les images.

## 9. Avancement (tenu par le Chef)
- 2026-11-27 : carte « AVAILABLE ON THE APP STORE » vérifiée sur la dernière image de chaque vidéo du QG. Toutes l'ont, sauf les 30 fadein, qui finissent sur le logo seul. Les 7 vidéos « telles quelles » sont donc prêtes.
- 2026-11-27 : **pub principale 28 s**, brouillon v0 envoyé au PDG pour validation. Planche : `~/ardane-tools/campaign/main28-org/planche-brouillon-v0.png` (images de Main Pub v2.5, source `~/ardane-tools/film/src/pub26/`). Déroulé :

| Temps | Plan | Voix | Note |
|---|---|---|---|
| 0-3 s | Accroche : icônes qui se multiplient | « Why manage your life in ten different apps? » | nouvelle voix Kokoro `af_heart` |
| 3-6,5 s | Accueil clair, puis sombre | « Meet Ardane. All your essentials on your home screen. » | pastille Premium lisible |
| 6,5-11 s | Nutrition : Scan / Search, puis 1 672 → 1 569 | « Scan your food, or search for it. Your day updates. » | doigt sur Scan |
| 11-15,5 s | Fitness : Set done, puis Live Activity sur l'écran verrouillé | « Track every set, even from your lock screen. » | gratuit |
| 15,5-19 s | Planning : semaine, habitudes | « Your week, your tasks, your habits. » | 3 habitudes (gratuit) ou pastille |
| 19-20,5 s | Défilé des autres mini-apps | « And much more. » | |
| 20,5-26 s | Accueil Clair (gratuit), puis Aurora | « Make it yours. Try every style before you choose. » | pastille Premium sur Aurora |
| 26-28,5 s | Carte finale | « Ardane. Your whole life. One place. » | AVAILABLE ON THE APP STORE |

- 2026-11-27 : **pub principale 28 s livrée** (v1, 26,7 s, -14,5 LUFS, crête -2,1 dBTP) : `_imports/pub-principale-28s-v1.mp4` ; l'ancienne `pub-principale-v5-restylee-v3` est dans `_archives-variantes/`. Faite en recoupant Main Pub v2.5 (images, bruitages, partition jouée d'un seul tenant jusqu'à sa vraie fin) avec les voix validées de pub26, plus une voix neuve Kokoro af_heart « Try every style before you choose. ». Pastilles or lisibles : « Premium style » (accueil bronze), « 4+ habits with Premium », « Aurora: Premium style ». Outils : `~/ardane-tools/campaign/main28-org/tools/build.py` (coupes, voix, pastilles ; `build.py 0.5|1 <sortie>`) et `k3.py`. Planche : `main28-org/controle-v1.jpg`. Écarts au déroulé : l'accroche dit « Why manage it in ten different apps? » (voix validée, accord avec le texte à l'écran) ; pas de doigt dessiné sur Scan ni sur Set done (seul le cadre de surbrillance de v2.5) ; début corrigé le même jour : l'image part sur la première icône (v2.5 image 198), la voix « Why… » reste entière. Son non écouté par le Chef, seulement mesuré.
- 2026-11-27 : **pub principale v1.1** (retour du PDG : on ne savait pas de quoi parlait « Why manage it… », plans trop rapides) : l'accroche reprend son intro (TRAINING, NUTRITION, WIDGETS, PLANNING, « Your life isn't one thing. ») ; accueil bronze retiré (1,5 s) ; accueil clair 3 s ; Nutrition d'un seul tenant (scan, recherche, quantité, 1 569) ; plus de demi-transition ; « And much more » 2 s. 30,0 s, -14,6 LUFS, crête -1,5 dBTP. Même fichier au QG (`pub-principale-28s-v1.mp4`).
