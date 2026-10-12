---
tags: [ardane, memoire]
---

# Pièges connus

Erreurs déjà rencontrées, pour ne pas les refaire. Retour : [[Memoire]]

## CI
- `concurrency: cancel-in-progress` : pousser un commit annule le run en cours. Attendre la fin d'un run utile (tests, `[adkit]`) avant de pousser.
- L'étape de tests finit par `|| true` : un job vert ne veut pas dire que les tests passent. Lire `report.txt` (« Test Case .*failed », « error: »).
- La branche `ci-report` est réécrite à chaque run : seul le dernier rapport est gardé. Copier ce dont on a besoin aussitôt.
- Les fichiers produits pendant une session cloud de Claude (rapports, PNG, vidéos) disparaissent avec la session : ce qui doit durer va dans le dépôt.

## Code et données
- Ne pas régénérer `ExerciseDemos.json` sur Windows sans vérifier (export différent, encodage cp1252 sans `PYTHONUTF8=1`).
- `python3 scripts/check_swift.py` avant chaque commit (ordre des labels d'init, catalogue de kinds, sécurité Release).

## Publicité
- Remotion : un `ThreeCanvas` ne se redessine qu'au changement d'image ; le monter seulement quand images et police sont prêtes (sinon la première image d'un morceau de rendu sort sans écran). `scene.environment` ignore `envMapIntensity` : verre du téléphone en matériau non éclairé. Plan proche de la caméra à 40 mm (sinon le corps transperce le verre).
- Une capture d'écran figée qui contient un compte à rebours (séance) ne doit jamais être nette pendant un maintien : bande de netteté sur l'élément légendé.
- Vérification de la voix par Whisper : les homophones trompent le taux d'erreur (« Your week » → « You're weak », « Ardane » seul → « are done ») ; écouter avant de régénérer.
- Détourage des captures d'iPhone : la Dynamic Island et les dernières lignes paraissent opaques ; les masquer avant de calculer l'alpha.
- Les longues tâches à plusieurs agents peuvent s'arrêter sur la limite d'utilisation : préférer un travail direct et des étapes courtes.

## Windows (sessions sur le PC de l'utilisateur)
- Kokoro ne s'installe pas sur Python 3.14 : venv en `py -3.12`. Le PyAV récent casse `faster-whisper` quand on lui passe un chemin de fichier : `vo.py` lui passe l'audio en mémoire.
- Le hook `pre-commit` (check_swift + l10n sync) est dans `.git/hooks/`, donc absent d'un nouveau clone : lancer `check_swift.py` à la main.
- Pas de Mac : rien ne se compile en local, la CI GitHub reste la seule vérification (compilation, tests, captures).
- Python lit en cp1252 par défaut : `check_swift.py` et `obsidian_map.py` se relancent seuls en UTF-8 ; pour les autres scripts, `PYTHONUTF8=1` (variable d'environnement permanente) ou `python -X utf8`.
- Sous Windows la commande est souvent `python` ou `py`, pas `python3`.
- Git convertit les fins de ligne (LF dans le dépôt, CRLF sur le disque) : normal, ne pas « corriger » des fichiers entiers.
- Le vault Obsidian est ce même dossier : ne pas toucher à `.obsidian/` (réglages de l'utilisateur, ignoré par Git).

## iOS
- Après une mise à jour installée par-dessus (sideload), iOS peut garder l'ancienne icône dans les notifications et les Réglages : redémarrer l'iPhone vide le cache d'icônes.

## Obsidian
- Obsidian réécrit un `.canvas` (ou les fins de ligne d'une note) quand on l'ouvre. Si GitHub Desktop montre ces fichiers modifiés : clic droit sur **ces fichiers seulement** → « Discard changes ». **Jamais « Discard all changes » pendant ou après une session Claude locale** : ça efface aussi son travail pas encore commité (le 2026-10-11, `synth.py` et des changements de `vo.py` ont été perdus puis réécrits). Dans le doute, demander à Claude de commiter d'abord.
- Les liens entre notes se résolvent par nom de fichier : deux notes du même nom (ou une note nommée comme un vrai fichier `.json` du dépôt) rendent le lien ambigu. Le guide est lié par `[[docs/obsidian/README|Guide]]`.
- Vue graphique en boule : force centrale trop forte (≈ 0,3 suffit) et filtre `tag:#ardane` oublié.
