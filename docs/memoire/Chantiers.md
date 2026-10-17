---
tags: [ardane, memoire]
---

# Chantiers

Retour : [[Memoire]] · Décisions : [[Decisions]]

## 2026-10-11 : passage à l'app Claude Desktop sur le PC Windows de l'utilisateur

Les sessions se font désormais en local, dans le dossier `tessera` : les notes écrites ici sont tout de suite sur le disque, sans Pull. Faire un Pull avant de commencer si une session cloud a poussé entre-temps. Particularités Windows : voir [[Pieges-connus]].

Terminé juste avant : la carte Obsidian (vue graphique en grappes, canvas au format d'Obsidian) et cette mémoire.

## En cours : campagne publicitaire v2 (reprise le 2026-10-11, en local sur le PC Windows)

Demande : une publicité de niveau Apple / Nike en motion design sur la vraie interface, voix off anglaise féminine, 1080 × 1920 à 60 i/s, 7 formats (principal 45–60 s, 30 s, 15 s, 6–10 s, Fitness, Nutrition, Personnalisation). « Une seule publicité exceptionnelle plutôt que plusieurs ordinaires. »

- Brief complet : [[Brief-campagne-v2]] · ce qui existe vraiment dans l'app : [[Faits-verifies-campagne-v2]] · direction retenue : [[Concept-THE-OPENING]].
- Fait :
  - Kit d'éléments réels : export DEBUG `AdExport` ([[AdExport (swift)]]), scènes [[AdShotsUITests (swift)]], listes `scripts/ad_export.txt` et `scripts/ad_screens.txt`. Le tag de commit `[adkit]` relance l'export en CI (PNG sans perte des widgets dans tous les styles, écrans, activité en direct, démos d'exercices image par image).
  - Voix off : script et minutage dans [`scripts/ad2/vo_spec.json`](../../../scripts/ad2/vo_spec.json), génération par [`scripts/ad2/vo.py`](../../../scripts/ad2/vo.py) (Kokoro-82M, voix af_heart, « Ardane » prononcé ar-DAHN, vérification par reconnaissance vocale). 2026-10-11 : films `main` (17 lignes, 29 s, toutes dans leur créneau) et `s8` générés dans `pub/vo/` ; écoute à valider par l'utilisateur (« Your week », « Ardane » seul).
  - Outils installés sur le PC (2026-10-11) : `~/ardane-tools` (venv Python 3.12 : torch CPU, Kokoro, faster-whisper ; Playwright + Chromium ; ffmpeg par winget). Procédure : [`scripts/ad2/README.md`](../../../scripts/ad2/README.md). Rendu Chromium 1080 × 1920 : ~130 ms par image (≈ 8 min pour 60 s à 60 i/s sur une scène simple).
  - Moteur (2026-10-11) : Remotion 4.0.534 dans `~/ardane-tools/film`, sources dans `scripts/ad2/film/` (`film_sync.py`). Fait : la ligne, le logo, le texte qui s'ouvre depuis la ligne, le grain, la scène `Close` (plans 24–25, 53–58 s, signature sonore D5 · silence · A5 par `scripts/ad2/synth.py`) ; rendu `pub/film/close.mp4` (5 s en 1 min 34). Voix des 7 films générée.
  - 2026-10-11 (suite) : téléphone 3D (`Phone3D`), scènes `Opening` (plans 1-3), `LockScreen` (11-13), `Daylight` (14 : une étiquette à code-barres seule dans la lumière, pas de produit), `Close` (24-25) ; partition complète `scripts/ad2/score.py` (58 s) et mixage final `scripts/ad2/mix.py` (−14 LUFS, voix 8 à 19 dB au-dessus de la musique) → `pub/film/`. Run `[adkit]` 169 lancé (accueils héros sur 6 décors via `rows=`, écrans et scènes en sombre, démos sombres) : **récupérer `adkit/` de ci-report dans `pub/kit/` dès qu'il finit, avant tout push**.
  - Piège Remotion : un `ThreeCanvas` ne se redessine qu'au changement d'image ; ne le monter qu'une fois images et police prêtes. Verre du téléphone en matériau non éclairé (l'environnement de scène ignore `envMapIntensity`).
- 2026-10-11 (soir) : **film principal 58 s terminé** (`pub/film/ardane-main-58s.mp4`, contrôlé : 3 480 images, aucune image figée en mouvement ni noire). Déclinaisons montées depuis `film/src/films/cuts.json` (segments de scènes + remappage du temps : caméra accélérable, interface toujours à 1×) avec leur propre musique (`score.py`, sections) et mixage (`mix.py cut <film>`, bruitages recalés par l'inverse du remappage) : 30 s, 15 s (Mon Quotidien recollé par `stitch.py`), 8 s (la ligne qui s'ouvre), Fitness 20 s, Personnalisation 24 s, Nutrition 20 s (apparence claire, attend `home-hero-light`, `lock-etudes`, `quickFood` du run 172).
- 2026-10-11 (nuit) : **sept films livrés** dans `pub/film/` (contrôlés par `scripts/ad2/qc.py` : images exactes, aucune image noire, −14 LUFS) : `ardane-principal-60s`, `ardane-30s`, `ardane-15s`, `ardane-08s`, `ardane-fitness-20s`, `ardane-nutrition-20s`, `ardane-personnalisation-24s`. Chacun s'ouvre sur une accroche et montre la personnalisation des widgets (Studio).
- Reste éventuel : Studio en apparence sombre dans le film principal (run 173 : captures `studio-*-dark`), styles de l'ajout rapide pour le film Nutrition (même run) ; écoute de l'utilisateur (« with Ardane » transcrit « with our Don »).
- Rendus dans `pub/` (ignoré par Git) : ils restent sur le disque, contrairement à une session cloud.

## Carte du projet (graphify) — 2026-10-12

- Fait : la carte Obsidian est remplacée par `scripts/graph_map.py` (graphify + visionneuse `scripts/graph/viewer.html`) : un nœud par fichier, 8 catégories ou les modules, Filtres / Groupes / Affichage / Forces / Animer, recherche, fiche au clic. Ouvrir `graphify-out/index.html`, ou le serveur « graphe » (mise à jour en direct).
- Version téléphone (claude.ai, privée) : https://claude.ai/artifact/FQBb8SpokSP57Hu12asBmV ; c'est un instantané, à republier après les gros changements (`--artifact`).
- Mise à jour après chaque commit par le hook git post-commit (installé sur ce PC ; sur un nouveau clone : `python3 scripts/graph_map.py --install-hook`).

## TestFlight — 2026-10-15

- L'utilisateur a acheté le compte Apple Developer. Préparé : tag CI `[testflight]` (Release signée, envoi TestFlight), signature manuelle en Release, `scripts/signing/ardane_signing.sh` et `scripts/signing/README.md`.
- Fait par l'utilisateur le 2026-10-15 : identifiants, certificat, profils, fiche App Store Connect, clé API (Key ID `YPPQ3U2GKY`), les 8 secrets GitHub (Team ID `WD538Z3CL9`). Premier envoi réussi le même jour : build 186 (version 1.0) envoyé sur App Store Connect (certificat « Apple Distribution: Mathys Lecointre (WD538Z3CL9) », profils valides jusqu'au 2027-10-15).
- « Test Information » de TestFlight (description, courriel de retour, infos pour la revue bêta) : seulement pour les testeurs externes ; pas nécessaire pour l'utilisateur, testeur interne (2026-10-15).

## Série de 13 demandes — 2026-10-15

- Fait (détail dans [[Demandes]]) : besoins nutritionnels calculés, « Mes infos » dans chaque mini-app, ordre de Fitness et ajout direct à la séance, Premium (statistiques détaillées et bibliothèque complète), Planning (création au toucher, pincement jour/semaine/mois/année), Business (Stripe en lecture seule et import CSV), mini-app Photos et citations, retrait de l'Eau, langue et fuseau horaire indépendants, boutons de l'activité en direct iPhone verrouillé, galerie de widgets réduite à « Mes widgets ».
- Tests : run 191 (commit 84b1fe4), 200 tests logiques réussis, 0 échec (dont 22 de `OctoberRequestsTests` et 5 de `LanguageTimeZoneTests`) ; build 192 (version 1.0) envoyé sur TestFlight (run 192). UITests et captures non relancés pour cette série.
- Suite (même jour) : carte Planning de Mon Quotidien touchable, exercices récents masqués, carte « Photos et citations » dans Créer ; run 193 compile, run 194 : 200 tests réussis, puis envoi TestFlight.
- Série du soir (Premium Fitness et Nutrition, widgets posés stables, scan sur l'écran verrouillé, icône Premium, photo derrière une citation, Mon Quotidien) : run 196 compile, run 197 : 229 tests réussis, 0 échec ; puis envoi TestFlight. À vérifier sur l'iPhone : un widget posé ne change plus quand on en crée un autre de même taille (défaut `defaultResult()`), le contrôle « Scanner un aliment » (iOS 18).
- À vérifier sur l'iPhone (impossible en CI) : boutons de l'activité en direct iPhone verrouillé ; galerie des widgets (les anciens widgets posés d'un autre type que « Mes widgets » disparaissent de l'écran d'accueil : les reposer par « Mes widgets ») ; pincement du calendrier ; Stripe avec une clé `rk_test_` puis `rk_live_`.
- Reste à faire par l'utilisateur : produits in-app dans App Store Connect (`com.dakrsnyk.tessera.premium.monthly/yearly/lifetime`) et contrat « Paid Applications » pour tester Premium par TestFlight ; la politique v2.1 (Photos et Stripe) est republiée sur l'artifact de `PremiumConfiguration.privacyURL`, mais cette page est privée : la partager « toute personne disposant du lien » (menu Partager) avant la soumission à l'App Store.
- Plus tard : Shopify, QuickBooks, Stripe Connect par un petit serveur OAuth (architecture dans `docs/integrations-business.md`).

## Premium en test — 2026-10-16

- 2026-10-16 : version interne Premium débloqué (build 200, tag `[interne]`, « Internal Only » vérifié par l'API). L'utilisateur veut un nom de vendeur différent et une entreprise : plan dans `docs/entreprise-et-nom-vendeur.md` (société par actions, D-U-N-S, migration du compte). Ne pas envoyer les formulaires fiscaux ni la banque du compte individuel en attendant.
- Guide pas à pas : `docs/guide-premium-testflight.md` (contrat Paid Apps, impôts, banque, création des 3 produits, test perso, testeurs externes, message pour les amis). En attente de l'utilisateur.

## Série du 2026-10-16 : devises, cours, 3 widgets gratuits, alphabet, salle, mode Clair

- Fait (détail dans [[Demandes]]) : run 201 compile la vague 1, run 202 les corrections et le mode Clair/Teinté ; run 203 : 278 tests logiques réussis, 0 échec (48 nouveaux : `CurrencyConversionTests`, `LivePricesTests`, `FreeWidgetLimitTests`, `SectionIndexTests`, `ScheduleRoomTests`, `AccentedRenderingTests`) ; build 204 (version 1.0) envoyé sur TestFlight (run 204, version normale, Premium non débloqué). Puis build 205 interne, Premium débloqué (run 205, « Internal Only » vérifié par l'API) : c'est lui qui s'installe ; le 204 reste dans TestFlight › Versions précédentes pour tester la version gratuite.
- À vérifier sur l'iPhone : widgets en Clair (clair et sombre) et Teinté (grand « Horaire de la semaine », Habitudes, Focus, Photos, Citation) ; import d'un CSV en USD (aperçu converti ; en mode avion : erreur et « Importer sans conversion ») ; widget Crypto qui avance seul ; Liste de suivi en petit sur un petit iPhone.
- Hypothèse annoncée à l'utilisateur : les citations sont illimitées comme les photos.
- Connu, à traiter à part : en mode En veille de jour (fond retiré, en couleur), les palettes à texte foncé (Jade, Sable…) s'affichent en texte foncé sur noir.

## Série du 2026-10-17 : retour en arrière Fitness, chrono d'étude en direct, encouragements, CSV

- Fait (détail dans [[Demandes]]) : run 208 compile ; run 209 : 323 tests logiques réussis, 0 échec (dont `WorkoutUndoTests`, `StudyLiveActivityTests`, `EncouragementsTests`, `BusinessCSVTests` avec le fichier de l'utilisateur) ; build 210 envoyé sur TestFlight (version normale), puis build 211 interne Premium débloqué (« Internal Only » vérifié).
- À vérifier sur l'iPhone : flèche retour et croix sur l'écran verrouillé et la Dynamic Island ; activité en direct du chrono d'étude ; encouragements (réglage dans Profil › Rappels, notifications autorisées) ; réimport du CSV de test (7 dépenses, 5 revenus).

## Suite du 2026-10-17 : relevé Finances, suppression d'une séance

- Run 214 compile ; run 216 : 331 tests réussis, 0 échec (le run 215 avait perdu le réseau à l'envoi du rapport, puis un test du relevé attendait un mauvais solde) ; build 217 sur TestFlight (normal), puis build 218 interne Premium (« Internal Only » vérifié).
- À vérifier sur l'iPhone : toucher le solde (relevé), ligne « Dépenses fixes », Mes infos de Finances allégé, suppression d'une séance puis la refaire.

## À ne pas oublier

- Le dépôt est public pour la CI : le repasser en privé.
