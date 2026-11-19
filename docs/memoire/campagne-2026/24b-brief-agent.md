# Brief commun : monter une pub de la campagne Ardane 2026-11 (première version rendue)

Tu montes UNE pub verticale (1080x1920, 60 i/s, anglais) pour l'app iOS Ardane, de bout en bout jusqu'au fichier vidéo
rendu. Ton film : `<film>` (voir le complément du Chef). Réponds et écris tes notes en français.

## À lire d'abord (court)
- `C:/Users/Etudiant/Documents/GitHub/tessera/docs/memoire/campagne-2026/24-campagne-mini-apps.md` (la campagne, ton angle).
- `C:/Users/Etudiant/ardane-tools/film/src/irl/IrlFitness.tsx` : la pub de RÉFÉRENCE validée par l'utilisateur (structure,
  rythme, mots à l'écran, écrans d'app nus arrondis, accroche, carte finale). Reprends ce style.
- `C:/Users/Etudiant/ardane-tools/film/src/campaign/lib.tsx` : composants communs (Footage, Word, Screen, Cap, Rec, Widget, Seq, Roll).
- `C:/Users/Etudiant/Documents/GitHub/tessera/docs/memoire/campagne-2026/Faits-verifies.md` (ne montrer et ne dire que du vrai).

## Ce que l'utilisateur veut (non négociable)
- Une vraie histoire : une personne dans une situation réelle liée à la mini-app, son objectif, Ardane qui intervient (vraie
  interface), le résultat, le widget sur l'écran d'accueil quand c'est pertinent, une fin forte (carte finale Ardane).
- Les scènes réelles occupent une grande place : PAS une suite de captures d'écran. Alterner plans réels et écrans.
- Style premium (Apple, Nike), cinématographique mais naturel, montage rythmé calé sur la musique.
- 30 à 40 s (45 s maximum). Accroche dans les 2 premières secondes. Pas d'écran statique long.
- Voix off féminine anglaise naturelle (Kokoro `af_heart`, vitesse 1.0, « Ardane » prononcé ar-DAHN via `"brand"`) qui RACONTE
  l'expérience (pas une liste de fonctions). Courte : 5 à 8 phrases. Plus des mots à l'écran comme la référence (petits, en minuscules).
- Captures les plus fraîches (app du 2026-11-19, run CI 44465910005, puis le run de campagne `camp-*`) : `~/ardane-tools/film/public/campaign/kit/<nom>.png`, à afficher avec `CapC` / `WidgetC` de lib.tsx. Certaines captures du kit sont ratées (écran d'accueil au lieu de l'écran voulu, transition) : REGARDE chaque capture avant de l'utiliser. Il n'y a pas d'enregistrement vidéo de l'app : anime les écrans (entrée, poussée lente, passage d'une capture à la suivante, mise en avant d'une zone) comme la référence.
- Fidélité absolue : uniquement des captures et enregistrements de l'app ACTUELLE (catalogue
  `scripts/ad2/pub26_v2/catalogue-captures.json` avec ok: true, captures `camp-*` et widgets `camp-*` du run de campagne,
  …). Jamais une capture d'avant le 2026-11-12 (dans le doute, regarde l'image et compare
  au catalogue). Aucune fonction inventée, aucun chiffre tapé à la main qui ne vient pas d'une capture.
- Le texte français qui traînerait dans une capture : ne pas utiliser la capture (le film est en anglais).

## Plans réels (Pexels)
- Candidats : `C:/Users/Etudiant/ardane-tools/campaign/footage-candidates.txt` (lignes de ton film). Licence : commerciale
  gratuite ; RÈGLE : aucun visage reconnaissable à côté d'un téléphone ou d'un écran d'Ardane (mains, dos, silhouettes,
  plans larges, objets, ou une personne qui fait l'action sans téléphone).
- Télécharge des aperçus (`?h=640&w=360`) dans `C:/Users/Etudiant/ardane-tools/campaign/<film>/preview/`, fais des planches
  (ffmpeg tile) et REGARDE-les (outil Read sur l'image) avant de choisir. Puis les choisis en 1080x1920
  (`?h=1920&w=1080`), découpés et réencodés : `ffmpeg -ss <s> -t <d> -i in.mp4 -an -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,fps=30" -c:v libx264 -crf 18 -preset fast -pix_fmt yuv420p out.mp4`
  vers `C:/Users/Etudiant/ardane-tools/film/public/campaign/<film>/`. Note la provenance (id Pexels) dans tes notes.
- Cohérence : même lumière, même époque de la journée par scène ; une seule personne principale si possible (même tenue,
  plans de dos ou de mains sinon). Étalonnage adapté au mode (clair : naturel lumineux ; sombre : `dark`).

## Musique (Pixabay)
- Candidates : `C:/Users/Etudiant/ardane-tools/campaign/music-candidates.txt` (lignes de ton film, licence en tête).
  Télécharge 3 ou 4 morceaux dans `C:/Users/Etudiant/ardane-tools/campaign/<film>/music/`. Tu ne peux pas écouter : choisis par
  tempo, énergie et structure (montée, drop) mesurés (voir `scripts/ad2/irl_music.py` : `find_drop`, et la méthode de tempo en
  peigne de la mission Fitness dans `docs/memoire/campagne-2026/23-pub-irl-fitness.md`). Place la partie la plus forte sur le
  cœur du film. Les coupes tombent sur les temps (un temps = 3600/BPM images à 60 i/s).

## Voix off
- Spec JSON comme `scripts/ad2/vo_spec_pub26.json` (`voice`, `speed`, `brand`, `films.<id>.chunks`), puis :
  `export ARDANE_HF_CACHE=~/ardane-tools/hf_cache; ~/ardane-tools/venv/Scripts/python.exe -I -X utf8 scripts/ad2/vo.py <spec> <id> <dossier>`
  (depuis `C:/Users/Etudiant/Documents/GitHub/tessera`) : un WAV par ligne et une vérification par reconnaissance vocale.
- Mixage : `~/ardane-tools/venv/Scripts/python.exe scripts/ad2/campaign_mix.py <config.json>` (format en tête du script ;
  CHEMINS WINDOWS `C:/...` dans le JSON). Sortie obligatoire : `C:/Users/Etudiant/ardane-tools/film/public/campaign/<film>/mix.wav`.
  Sons : tap au toucher d'un bouton, whoosh aux passages d'écran, logo sur la carte finale.

## Montage (Remotion, `C:/Users/Etudiant/ardane-tools/film`)
- Crée `src/campaign/<film>/Film.tsx` (composition) et `src/campaign/<film>/index.ts` :
  `import { registerRoot, Composition } ...` avec UNE composition d'id `Camp<Film>` (1080x1920, 60 i/s). Ne modifie PAS
  `src/Root.tsx`, `src/campaign/lib.tsx`, ni rien d'un autre film (copie un composant dans ton dossier si tu dois le changer).
- Au début du composant : `setKitLang("en")` et `<LangContext.Provider value="en">` (sinon les captures sortent en français).
- Écrans : `Screen` + `Cap` (capture) ou `Rec` (enregistrement mp4). Écran nu arrondi avec ombre, JAMAIS de coque dessinée.
- Écran d'accueil final : `HomeBuilder` comme dans IrlFitness (config `Config` avec `wall`, `slots` en px de capture
  1206x2622 : M(y)=[57,y,1092,510], SL(y)=[57,y,510,510], SR(y)=[638,y,510,510], rangées y=204, 813, 1422 ; `noFill: true`
  pour ne pas mettre d'icônes). Fonds : `public/kit2026/en/wall-*.png`, `public/mainpub/wall-mp-*.png`.
- Fin : `EndCard` de `src/pub26/parts.tsx` (170 images, carte validée).
- Vérifie le typage : `cd ~/ardane-tools/film && npx tsc --noEmit -p . 2>&1 | grep campaign/<film>`.
- Aperçus : `npx remotion bundle src/campaign/<film>/index.ts --out-dir=out/campaign/<film>/bundle` une fois, puis
  `npx remotion still out/campaign/<film>/bundle Camp<Film> out/campaign/<film>/s-<f>.jpg --frame=<f> --scale=0.3`
  pour 6 à 10 images clés ; assemble-les en planche et REGARDE-la. Corrige ce qui cloche (texte qui chevauche, écran en
  français, plan hors sujet, visage + téléphone).
- Rendu final : `bash /c/Users/Etudiant/Documents/GitHub/tessera/scripts/ad2/campaign_render.sh <film> Camp<Film>` (il
  attend une place libre, ~15 à 25 min ; lance-le avec run_in_background et attends la notification). Regarde la planche
  `pub/campagne-2026-11/<film>/planche-v1.jpg`. Vérifie durée, son (`ffmpeg -i <mp4> -af ebur128 -f null -` : ~-14 LUFS).
- Sortie de commandes longues : toujours rediriger vers un fichier (un `| tail` sur un rendu Remotion le fait planter).

## Interdits
- Ne modifie aucun fichier de l'app (Swift, projet Xcode), ne fais aucun commit, aucun push, aucune dépense, aucun compte.
- N'utilise pas le navigateur (la recherche est faite ; les téléchargements directs marchent avec curl).
- Ne supprime rien d'existant hors de ton dossier de travail.

## Livrables (dans `C:/Users/Etudiant/Documents/GitHub/tessera/pub/campagne-2026-11/<film>/`)
- `ardane-<film>-v1-1080x1920.mp4` (par le script de rendu) et `planche-v1.jpg`.
- `notes.md` : scénario en 6 lignes, texte de la voix off, musique (page Pixabay, licence), plans Pexels (id et rôle),
  captures utilisées, durée, ce qui reste à améliorer (honnête).
- Rapport final au Chef (court) : état (rendu ou non, pourquoi), chemin, durée, musique, problèmes.
