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
- Une date d'emploi du temps calculée en ajoutant des secondes au début du jour se décale d'une heure les jours de changement d'heure : utiliser `DateMath.date(on:minute:)` (calendrier).
- Écrire un état vide par-dessus un fichier illisible (iPhone verrouillé, protection des fichiers) efface les données : `SharedStore.update` refuse d'écrire quand le fichier existe mais ne se lit pas.
- Remplacer le dernier membre d'un `struct` par un bloc de texte peut emporter son `}` final (run 188, `FitnessApp.swift`).
- Ajouter une `WidgetCategory` ou un `WidgetKind` : les `switch` exhaustifs ailleurs (`Templates.autoAccent`, `KindCatalog`, `check_swift.py`) doivent suivre.
- Nouveaux textes : `l10n_catalog.py extract` AVANT `merge` et `build`, sinon les clés nouvelles restent « not in the catalog ».
- Galerie de l'écran d'accueil : iOS ne montre qu'une entrée par taille et par type de widget ; impossible d'en montrer une par widget créé (`AppIntentRecommendation` = watchOS seulement). `defaultResult()` peut être mis en cache par iOS (FB15592256) : vérifier sur l'iPhone.
- Un contrôle iOS 18 ne peut pas ouvrir un schéma `tessera://` (`OpenURLIntent` = liens universels seulement) : `OpenFoodScannerIntent` (OpenIntent, dans les deux cibles) + `AppOpenRequests` lu par l'app.

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
- Python lit en cp1252 par défaut : `check_swift.py` se relance seul en UTF-8 et `graph_map.py` écrit en UTF-8 ; pour les autres scripts, `PYTHONUTF8=1` (variable d'environnement permanente) ou `python -X utf8`.
- Sous Windows la commande est souvent `python` ou `py`, pas `python3`.
- Git convertit les fins de ligne (LF dans le dépôt, CRLF sur le disque) : normal, ne pas « corriger » des fichiers entiers.
- Le vault Obsidian est ce même dossier : ne pas toucher à `.obsidian/` (réglages de l'utilisateur, ignoré par Git).

## iOS
- Après une mise à jour installée par-dessus (sideload), iOS peut garder l'ancienne icône dans les notifications et les Réglages : redémarrer l'iPhone vide le cache d'icônes. Renommer les jeux d'icônes (AppIcon… → ArdaneIcon…, version 177, migration dans `AppIconSwitcher.migrateRenamedIcon`) n'a PAS suffi : l'IPA 177 vérifiée ne contient que le A d'Ardane, le cache des notifications suit l'identifiant de l'app. Même la réinstallation propre + redémarrage n'a pas suffi (notification de test de la 179 : mosaïque). C'est un bug connu d'iOS 18.1+ (forums Apple 775787, 808396 : cache d'icônes des notifications de SpringBoard, par identifiant d'app ; Apple « under investigation »), que l'app ne peut pas corriger. Il ne touche que les iPhone qui ont vu l'ancienne icône (celui de l'utilisateur) : les clients de l'App Store n'auront jamais vu Tessera. Seul remède sûr côté code : changer l'identifiant de l'app, fait le 2026-10-12 (`com.dakrsnyk.ardane`), confirmé sur l'iPhone de l'utilisateur (version 180). Ne pas revenir à `com.dakrsnyk.tessera` : cet iPhone en garde la mosaïque. Ne pas renommer les icônes de nouveau sans migration.
- Accueil : une carte de Mon Quotidien qui dessine son propre fond (Nutrition) ne passe pas par `DayCard` : tout style commun (dégradé de catégorie) se met dans `CategoryTint`. Pas d'ombre ni de halo sur une carte d'un `DailyPager` : le pager rogne le débord en rectangle.
- Un bouton de widget ou d'activité en direct ne peut pas faire vibrer l'iPhone : la vue est un instantané et un retour haptique n'est joué que pour l'app au premier plan ; ne pas promettre de vibration depuis l'écran verrouillé ou la Dynamic Island (voir `ButtonFeedback`).
- Passation « arbre propre » possiblement fausse : si un agent s'arrête sur la limite d'usage après avoir écrit du code, la note dit « non commencé » alors que `git status` montre tout (2026-10-22). Vérifier `git status` avant de se fier à `docs/PASSATION.md`.
- CI : un dépôt PRIVÉ n'a pas de minutes macOS gratuites : le run échoue en 14 s avec « The job was not started because recent account payments have failed or your spending limit needs to be increased » (2026-10-22). Repasser le dépôt en public, ou régler la facturation, avant tout `[check]`.
- CI : le rapport (`ci-report`) coupe la liste des tests à 400 lignes (`head -400`) : au-delà, une défaillance serait invisible dans le rapport ; lire le journal complet : `gh run view <id> --repo Dakrsnyk/tessera --log | grep "Test Case .* failed"` et `TEST SUCCEEDED`.
- CI : un push annule le run en cours (concurrency) : ne pousser qu'une fois le run précédent fini. Un commit vide ne lance pas la CI (paths-ignore) : toucher un fichier non `.md`.
- `scripts/graph_map.py` : chaque ligne ajoutée à une liste `features` doit finir par `",` ; vérifier avec `python3 -c "import ast; ast.parse(open('scripts/graph_map.py', encoding='utf-8').read())"` (une erreur de syntaxe a passé deux commits).
- Un script Python lancé par `python3 - <<'EOF'` dans Bash avec des `\(` Swift : écrire le script dans un fichier (le scratchpad) plutôt qu'en ligne.

## GitHub Desktop et éditeurs
- Un éditeur (Obsidian par exemple) peut réécrire les fins de ligne d'une note qu'il ouvre. Si GitHub Desktop montre ces fichiers modifiés : clic droit sur **ces fichiers seulement** → « Discard changes ». **Jamais « Discard all changes » pendant ou après une session Claude locale** : ça efface aussi son travail pas encore commité (le 2026-10-11, `synth.py` et des changements de `vo.py` ont été perdus puis réécrits). Dans le doute, demander à Claude de commiter d'abord.
- Vue graphique en boule : force centrale trop forte (≈ 0,3 suffit) et filtre `tag:#ardane` oublié.
- La CI ignore les commits qui ne changent que des `.md` (`paths-ignore`) : un commit `[testflight]` ou `[unit]` doit toucher au moins un autre fichier (le 2026-10-15, un envoi TestFlight n'est pas parti).
- Version interne (Premium débloqué) : ne jamais citer le tag entre crochets dans une description, ni le mettre avec le tag TestFlight normal (la CI refuse les deux ensemble). Après l'envoi, vérifier l'étiquette « Interne » dans TestFlight (la CI la contrôle aussi par l'API et expire la version sinon).
- Les tags CI sont cherchés n'importe où dans le message de commit : ne jamais écrire un tag entre crochets dans la description (le 2026-10-15, un commit [check] qui décrivait le tag TestFlight entre crochets a lancé l'envoi TestFlight au lieu de la compilation, échec « Secrets manquants »).
- Frankfurter répond 404 pour une période entièrement future ou une devise non publiée : borner la fin à aujourd'hui.
- Mode Clair (iOS 26) et Teinté = rendu `accented` : iOS ne garde que l'opacité et remplace le fond ; une forme pleine sous du texte devient un bloc blanc qui le cache. Utiliser `style.isAccented`, `textBackdrop`, `partColor` ; une `Image` doit avoir `widgetAccentedRenderingMode` (iOS 18), sinon elle devient blanche. Le « mode clair » de l'utilisateur peut désigner ce mode des widgets, pas l'apparence claire.
- Import CSV : une colonne « type » (revenu/depense, sans accent) avec des montants positifs était ignorée et tout devenait des ventes ; un en-tête « Montant débit » était pris pour le montant. Tester avec des exports réels (Tests/BusinessCSVTests.swift).
- Notifications app ouverte : sans délégué `UNUserNotificationCenterDelegate`, aucune bannière ne s'affiche ; `NotificationPresenter` ne montre que les encouragements.
