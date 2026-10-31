---
tags: [ardane, memoire, campagne-2026, passation]
---

# Passation : campagne publicitaire 2026 (écrit le 2026-10-31)

Session suivante : lire ce fichier en entier, puis `docs/memoire/Demandes.md` (chantier 19), `Faits-verifies.md`, les storyboards `01-principale.md` … `08-courtes.md` et `Ressources-a-capturer.md` (même dossier). Répondre en français. Finir chaque message par « Prochaine action pour toi : … » et une ligne d'état « **Terminé.** » ou « **En cours : …** ». Ne jamais s'arrêter tant que tout n'est pas livré ; travailler en parallèle pendant les attentes de CI.

## Demande (résumé)
8 publicités Ardane : principale 30–45 s, Nutrition, Fitness, Organisation, Widgets, Finance (15–20 s), Lifestyle 30–45 s, courtes 6–10 s ×3 ; 4 formats (9:16, 1:1, 4:5, 16:9, mises en page propres à chaque format, pas de simple recadrage) ; français ET anglais ; voix féminine (anglais principal, français complet) ; musique originale ; miniatures, visuels statiques, légendes, CTA ; dossiers de livraison `01_Ad_Main`, `02_Ad_Nutrition`, `03_Ad_Fitness`, `04_Ad_Lifestyle`, `05_Ad_Widgets`, `06_Ad_Finance`, `07_Ad_Organization`, `08_Ad_Short`, `09_Static_Visuals`, `10_Source_Files`. Message : « Your whole life. One place. Your widgets. Your way. ». Les widgets personnalisables sont un sujet essentiel. Thème Saphir seul (#245B8F, #68B5F5), icône et logo Saphir actuels ; interfaces fidèles à l'app réelle ; rien d'inventé ; ne pas laisser croire que tout est gratuit.

## Décisions de l'utilisateur (2026-10-30)
- Workflow : autorisé à modifier la ligne de style de `.github/workflows/build.yml` (fait : `sapphire`) ET la variable de langue de l'étape « Ad kit » (fait : tag `[adkit-en]`). Rien d'autre dans le workflow sans nouvel accord.
- Kit : second kit en ANGLAIS (interface en anglais pour les pubs anglaises).
- Fluidité : 60 i/s PARTOUT (4 formats).
- Premium : mention « Avec Premium » sur les écrans qui montrent une fonction Premium.
- Nouvelles couleurs de l'app (faites, build 308 sur TestFlight) : roue des calories ORANGE (`FF9500`), protéines ROUGE, glucides JAUNE, lipides BLEU ; à montrer dans les pubs.
- Décisions du Chef (non contestées) : « Ardane » = ar-DAHN en anglais, ar-DANE en français ; tutoiement ; scan montré par le code-barres seul ; plans à plus de 3 widgets marqués « Avec Premium » ; carte finale « Coming soon / Bientôt », pas de prix, pas de badge App Store ; le scanner alimentaire est GRATUIT.
- Voix française : échantillon envoyé à l'utilisateur, réponse pas encore reçue (Kokoro `ff_siwis`, `scripts/ad2/vo_fr.py`, réglage de vitesse par ligne). Alternative si trop mécanique : XTTS-v2 ou Piper.

## État au moment de la passation
**Dépôt tessera** (public pour la CI ; rappeler de le repasser en privé à la fin) :
- Commit local NON POUSSÉ `a8880be [check]` : faits, scripts des 8 pubs, moteur Remotion en Saphir avec 4 formats, voix française, nouveaux écrans du kit (`scan-recap`, `scan-recap-photo`, `nutrition-plan`), variante `[adkit-en]`. Un push avec `[adkit]` ANNULE un run en cours (une seule exécution à la fois, la suivante annule la précédente).
- Run CI 309 (`[adkit]`, commit 5ccab01, kit FRANÇAIS en Saphir avec les nouvelles couleurs, SANS les nouveaux écrans) : id `41179939110`, en cours au moment de la passation. Son résultat arrive dans la branche `ci-report` (dossier `adkit/`) : `git fetch -q origin ci-report && mkdir -p /tmp/rNNN && git archive origin/ci-report | tar -x -C /tmp/rNNN`. À récupérer AVANT tout push suivant (piège noté dans Chantiers.md : copier `adkit/` dans `pub/` d'abord). Un watcher de la session précédente le suit ; en cas de doute `gh api repos/Dakrsnyk/tessera/actions/runs/41179939110 --jq '.status,.conclusion'`.
- Ordre prévu : (1) récupérer le kit du run 309 ; (2) pousser a8880be avec le message `[adkit] …` (kit français complet avec les nouveaux écrans) ; (3) récupérer ; (4) un commit `[adkit-en] …` (kit anglais, jamais avec `[adkit]` dans le même message) ; (5) récupérer. Il faut un fichier non-.md modifié pour déclencher la CI (astuce : ajouter/retirer une espace en fin de la 1re ligne de `docs/references/.gitignore`). Les commits se terminent par `Co-Authored-By: Claude <noreply@anthropic.com>` et `Claude-Session: https://claude.ai/code/session_011SGgP6YLhofhVhTasQukEx`.
- Les kits vont dans `scripts/ad2/film/public/kit2026/<fr|en>/` (voir `src/lib/kit.ts`, helper `kitSrc(name)` avec repli sur l'ancien kit et un script `check_assets` des noms manquants). `film_sync.py import` envoie le dépôt vers `~/ardane-tools/film` ; NE JAMAIS lancer `export` avant d'avoir importé (écrase le dépôt).

**Agents encore actifs dans l'ANCIENNE session au moment de la passation** (ils écrivent des fichiers locaux ; ne pas les relancer à l'aveugle : regarder d'abord `git status`, `pub/film2026/`, `pub/vo2026/`, `scripts/ad2/` pour voir ce qui existe) :
1. Compositions Remotion des 8 pubs (`scripts/ad2/film/src/**`, `render_all.py`) : scènes Finance et Organisation à créer, compositions à timing exact des storyboards, images fixes de contrôle, mesure de rendu d'un court de 8 s.
2. Audio : voix EN et FR des 10 films (`scripts/ad2/{vo,vo_fr,score,synth,mix,qc}.py`, sorties `pub/vo2026/<langue>/<film>` puis `pub/film2026/audio/<langue>/mix-<film>.wav`), musique à chaque durée, mixage −14 LUFS.
Si ces deux travaux ne sont pas terminés, les terminer (en reprenant ce qui existe) ; s'ils le sont, passer à la suite.

**Déjà prêt dans le dépôt** : moteur Remotion recoloré en Saphir (`brand.ts`), compositions de format (`formats.ts`, `FormatFrame.tsx`, `Formatted.tsx`), i18n EN/FR (`lib/i18n.json`, `i18n.tsx`), `scripts/ad2/render_all.py` (modes `still`, `video`, `scene`, options `--format`, `--lang`, `--out`, sortie `pub/film2026/<dossier>/`), spécifications de voix `scripts/ad3/spec/vo_spec_en.json` / `vo_spec_fr.json` et textes `i18n.json` (à fusionner avec `src/lib/i18n.json` si pas encore fait). Images de contrôle : `pub/film2026/check/stills/`. Mesure : ≈ 7–11 s par image fixe ; les vidéos complètes à 60 i/s prennent plusieurs heures au total (à mesurer sur un court avant de lancer le reste). Le disque est à 89 % : ≈ 27 Go libres, prévoir 2–4 Go de films.

## À faire (dans l'ordre, sans s'arrêter)
1. Kit : récupérer 309 → pousser `[adkit]` → récupérer → `[adkit-en]` → récupérer ; vérifier `done.txt`, `missed.txt`, regarder les captures `scan-recap`, `scan-recap-photo`, `nutrition-plan` ; si un écran est faux ou manque, corriger (Swift via un agent `ios-developer`, relu) et relancer. `scan-food-lock` est impossible tel quel (vue dans l'extension widget seulement) : repli écran verrouillé du Store ou retirer ce plan.
2. Placer les kits dans `public/kit2026/fr` et `en`, `film_sync.py import`, `check_assets`, finir les compositions ; images fixes de chaque pub dans les 4 formats et 2 langues, les REGARDER et corriger (débordements des textes français, chevauchements, mention « Avec Premium », roue orange, macros rouge/jaune/bleu, icône Saphir).
3. Voix et musique finalisées (voir agent audio) ; contrôle d'écoute par transcription (Whisper se trompe sur « Ardane »).
4. Rendus vidéo complets en arrière-plan, un à la fois (court d'abord pour mesurer), 60 i/s, contrôle `scripts/ad2/qc.py` (images exactes, aucune image noire, −14 LUFS), dans `pub/film2026/`.
5. Miniatures et visuels statiques pour les réseaux (`09_Static_Visuals`), légendes et textes publicitaires, propositions de CTA FR/EN (fichiers markdown), sources de montage (`10_Source_Files` : projet Remotion, spécifications, scripts).
6. Classer toute la livraison dans `pub/livraison-pubs-2026/` avec les 10 dossiers ci-dessus et un `LISEZMOI.md` ; envoyer à l'utilisateur les fichiers principaux avec SendUserFile (GIF/PNG/MP4 courts ; l'utilisateur ne peut pas ouvrir les artifacts Design).
7. Mémoire : cocher `docs/memoire/Demandes.md` (chantier 19.1 à 19.5 avec dates, fichiers, blocages), mettre à jour `Chantiers.md`, corriger `Decisions.md` (musique : partition originale synthétisée, pas Mixkit) et `Faits-verifies-campagne-v2.md` (périmé). Un commit `[check]` ou sans tag sur les changements de code ; `[interne]` seulement si l'app change.

## Règles à respecter
- `CLAUDE.md` de tessera : commits en français, `python3 scripts/check_swift.py` avant chaque commit, jamais `[testflight]` sans accord explicite, pas de secret affiché, ne pas casser l'existant.
- Les rendus restent dans `pub/` (ignoré par Git). Aucun rendu ne doit montrer une fonction inexistante ou laisser croire que tout est gratuit.
- Aucune validation n'est déclarée sans preuve (image regardée, fichier mesuré). Les rendus et l'écoute finale sont validés par l'utilisateur.
- Autres chantiers en cours dans l'ancienne session (ne pas les toucher ici) : siège 3D `ardane-hq` (chantier 18, phase 3 à venir), tutoriel/permissions/notifications (chantier 17, terminé et sur TestFlight).
