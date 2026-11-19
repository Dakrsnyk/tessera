# 23. Pub « IRL » Fitness — 2026-11-18

Nouveau type de contenu demandé par l'utilisateur : une pub « vraie vie », sur le modèle d'un Reel de partenariat (application de suivi de musculation : montre, salle, téléphone en gros plan, un mot à l'écran par plan, coupes d'environ 1 s, boucle). Une pub par mini-app : Fitness d'abord, puis Nutrition (repas scannés, cuisine), etc.

## Décisions de l'utilisateur (2026-11-18)
- Carte blanche, et **aucun autre outil que Claude** : pas de Higgsfield (compte gratuit, 10 crédits, sans usage commercial), pas d'Arcads.
- Claude ne génère pas de vidéo réaliste de personnes. L'utilisateur a choisi la voie **vidéos libres de droits (Pexels)** plutôt que de filmer lui-même. Cela lève, pour ce projet, la règle « pas de recherche d'images » du CLAUDE.md.

## Licence Pexels (à respecter pour toutes les pubs IRL)
- Usage commercial gratuit, sans attribution obligatoire, modification permise.
- Interdit : laisser croire qu'une personne filmée recommande le produit. Donc **jamais un visage reconnaissable à côté d'un téléphone ou d'un écran d'Ardane** ; les plans de personnes sont des plans de sport (dos, silhouettes, mains, contre-jour). Le plan 6390157 (homme qui regarde son téléphone) a été écarté pour cette raison.
- Les vidéos restent HORS du dépôt (dépôt public) : `~/ardane-tools/irl-fitness/raw/` (originaux 1080x1920), extraits dans `~/ardane-tools/film/public/irl/fitness/`.
- Téléchargement : `https://www.pexels.com/download/video/<id>/?h=1920&w=1080` (redirige vers le fichier 1080x1920). Recherche : `pexels.com/search/videos/<mots>/?orientation=portrait` (le navigateur intégré passe, `curl` aussi pour les fichiers).

| Extrait | Pexels | Plan |
|---|---|---|
| bg-hook | 6389061 | râtelier d'haltères (flou, fond de l'accroche) |
| b1 | 34583337 | tractions, silhouette en contre-jour |
| b2 | 29569378 | développé haltères, contre-plongée |
| b3 | 34901598 | développé couché, noir et blanc |
| b5 | 29546694 | développé couché vu de dessus |
| b6 | 30234651 | développé couché, veste rouge |
| b7 | 35585829 | mains sur la poulie |
| b8 | 18941354 | cordes ondulatoires, fumée |
| b9 | 34583329 | silhouette debout, contre-jour |
| bg-screen | 35757588 | salle (flou, fond des écrans) |
| bg-make | 7986045 | râtelier (flou, fond de la création du widget) |

## Le film
- `~/ardane-tools/film/src/irl/IrlFitness.tsx` (copie dans le dépôt : `scripts/ad2/film/src/irl/`), composition `IrlFitness` enregistrée dans le `Root.tsx` de `~/ardane-tools/film` seulement. 1080x1920, 60 i/s, 1640 images = 27,3 s, anglais.
- Étalonnage commun pour fondre des sources différentes : désaturé, rouge dans les tons moyens (calque `#C3162B` en mode « color »), noirs écrasés, vignette, grain. Couleurs de Fitness : rouge, noir, gris.
- Grille : 120 BPM, un temps = 30 images. Découpage : accroche Live Activity (« set done. », tap sur « Set done ») 2 s · trois plans de salle (« discipline », « every set », « every rep ») · séance `session-0-dark` (« tracked. ») · trois plans · programme `pub26-fitness-dark` (« your program. ») · cordes (« getting stronger ») · mécanique du widget : `pub26-create-dark` (« create. »), `creator-fitness-medium` (« choose. »), widget Next set en Clair, Luxe, Néon (« style. »), écran d'accueil fond rubis avec Volume, Next set, Rest timer en Néon (« on your home screen. ») · silhouette (« every day. ») · carte finale validée (`EndCard`).
- Écrans : captures actuelles (runs 471/472). Exception connue : les widgets exportés (`nextSet-s-*`, `weeklyVolume-m-neon`, `restTimer-s-neon`) datent d'avant la refonte du 2026-11-12, comme dans la Main Pub v2.3 validée ; à refaire avec `[adkit-img]`.
- Son : `scripts/ad2/irl_audio.py` (lancer avec `~/ardane-tools/venv/Scripts/python.exe`, qui a pyloudnorm) : beat trap / phonk en ré mineur synthétisé, tap et coche sur « Set done », souffles aux changements d'écran, coupure puis signature Ardane (ré5, la5) sur la carte finale. Sortie `public/irl/fitness/mix.wav`, environ -15 LUFS, crête -1 dBFS. Pas de voix off (comme la référence).
- Rendu : `npx remotion render IrlFitness out/irl/irl-fitness.mp4 --crf=16 > out/irl/render.log 2>&1` dans `~/ardane-tools/film` (rediriger la sortie vers un fichier : un `| tail` fait planter le rendu avec « write EOF »).

## Reste / idées
- Retour de l'utilisateur sur la v1.
- Mêmes pubs pour Nutrition (cuisine, assiette ; écrans du scanner), Planning, etc. : même gabarit, changer les extraits, les écrans et la couleur.
- Formats 4:5 et 1:1 non faits.

## v2 (2026-11-19) — demandes de l'utilisateur
- « Pas de filtre rouge » : plans de salle en **noir et blanc contrasté** (choix entre couleurs d'origine et noir et blanc ; les sources mélangent bleu, vert, orange). Seuls les écrans d'Ardane restent en couleur.
- « Je n'aime pas du tout la musique » (le beat synthétisé de v1) : morceaux réels de **Pixabay Music** (licence Pixabay : usage commercial gratuit, sans attribution ; certains morceaux sont inscrits à Content ID, une réclamation reste possible sur YouTube, à lever depuis la page du morceau). Les sites qui analysent la vidéo pour proposer une musique (Epidemic Sound Soundmatch, environ 49 $/mois en commercial ; Freebeat, qui compose d'après la vidéo) ont été écartés : payants ou envoi de la pub à un tiers.
- `scripts/ad2/irl_music.py <morceau> <bpm> <sortie.wav> [drop_s]` : ramène le morceau à 120 BPM (atempo, hauteur gardée), cale son drop sur la fin de l'accroche (2,0 s), garde les sons d'interface d'`irl_audio.py`, -14 LUFS. Tempo mesuré par un filtre en peigne sur les attaques (pas de librosa installé).
- Trois propositions (morceaux hors du dépôt, `~/ardane-tools/irl-fitness/music/`) :

| Version | Pixabay | Tempo | Drop dans le morceau | Étirement |
|---|---|---|---|---|
| A phonk de salle | /music/phonk-gym-phonk-620567/ | 124 | 17,25 s (après un silence) | -3 % |
| B phonk dur | /music/phonk-phonk-hard-624946/ | 113,3 | 11,27 s | +6 % |
| C rock énergique | /music/rock-uplifting-action-sport-energetic-rock-619094/ | 107 | 8,07 s | +12 % |

- Une fois le morceau choisi, possibilité de refaire la grille du montage à son tempo exact (au lieu de l'étirer).

## v4 (2026-11-19) — retour de l'utilisateur sur v3
- Refusé : l'écran d'accueil final en Noir mat (boutons et cases carrés), jugé irréalisable avec Ardane. Retenu : le style **Carbone** (noir, accent rouge E5383B, fond rayé), qui clôt désormais la série « your colors. » (cinq coloris, le Noir mat retiré).
- Écran d'accueil final : widgets Carbone (combiné Next set + Consistency, Records en petit, Volume en moyen ; le minuteur Carbone affichait 0:00, écarté) et **vraies apps iPhone** dans les cases libres (Santé, Plans, Calendrier, Rappels) et le Dock. Fond `wall-irl-apps.png` (`irl_wall.py --sans-halteres` : l'haltère serait cachée par les icônes).
- Exports : `irl-restTimer-s-carbon`, `irl-personalRecords-s-carbon`, `irl-weeklyVolume-m-carbon` (`[adkit-img]`, run 44525767850).
- Planche : `pub/campagne-2026-11/fitness/v4/planche-v4.png` ; vidéo : `pub/campagne-2026-11/fitness/ardane-fitness-v4-1080x1920.mp4`. Même musique et même grille que v3.
