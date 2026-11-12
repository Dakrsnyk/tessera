---
tags: [ardane, memoire, campagne-2026, avant-apres]
---

# 15 · Pub « Voici ton téléphone… et voici le mien » (avant / après), 2026-11-11

Statut : aperçus et brouillon 540p envoyés au PDG, **pas validée**. Rendu propre 1080 × 1920 après son accord.

- Source : `scripts/ad2/film/src/avantapres/` (entrée séparée, sans toucher au Root principal). Rendu dans `~/ardane-tools/film` :
  `npx remotion render src/avantapres/index.ts AvantApres out/aa.mp4` ; aperçus : composition `AvantApresStill` (props `which` = before | volt | glacier | marine).
- 18 s, 30 i/s, anglais (langue principale de la campagne), muet pour l'instant. Avant (vraie capture iOS) → glissement de page → Sport « Volt » → morphing des widgets (chaque widget change de taille sur place, icônes qui changent de coin) → Organisation « Glacier » → balayage de lumière → Finance « Marine » → les trois écrans côte à côte → carte « Coming soon to the App Store », mention « Some widgets and styles With Premium ».
- Écrans : Volt = todaysWorkout M, calories S, weeklyVolume M (style Sport) ; Glacier = tasks S, habits S, upNext M, habitRate S (style Glacier) ; Marine = businessDashboard L, budgetLeft S (style Business, accent blanc E9EEF5 ; l'or donnait des barres olive). Tous rendus par `[adkit-img]` le 2026-11-11, jamais montrés avant. Fonds neufs : `scripts/ad2/avant_apres/make_walls_aa.py` (wall-aa-volt, -glacier, -marine).
- Vraies icônes Apple : nouvelle étape CI `[ios-home]` (accord de l'utilisateur) qui photographie l'écran d'accueil du simulateur (iPhone 16 Pro) en clair et en sombre (`report/ios-home`). Grille iOS mesurée dessus (`GRID` de `screens.ts`). Icônes disponibles : Calendar, Photos, Reminders, News, Maps, Health, Wallet, Settings, Safari, Messages. Le simulateur n'a PAS Téléphone, Appareil photo, Musique, Horloge ni App Store.
- Règles Apple vérifiées (App Store Marketing Guidelines) : écran d'accueil permis s'il montre le widget de l'app ; barre d'état réseau, Wi-Fi et batterie pleins (pile « en charge » de la capture remplacée) ; pas d'imitation d'appareil (écrans sans coque dessinée). Limites signalées au PDG : l'écran « avant » ne montre pas de widget Ardane ; les ressources Apple Design Resources ne servent qu'aux maquettes.
- Musique (2026-11-11, demande du PDG) : `scripts/ad2/avant_apres/music_aa.py`, synthétisée en code, sans échantillon ni « ding », 120 BPM en ré majeur. Début terne, mono et filtré sur l'écran « avant », drop à 4 s (image 120) sur l'écran Sport, retombée du morphing à 8 s, impact de fin à 16 s. Le montage (`T` de `Film.tsx`) est calé sur les mesures. Brouillon v2 avec musique envoyé, pas encore validé.
