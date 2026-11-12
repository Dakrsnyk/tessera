---
tags: [ardane, memoire, campagne-2026, principale]
---

# 17 · Pub principale V5 restylée au niveau de la pub avant / après (demande du PDG, 2026-11-11)

Demande : « refais seulement la pub principale en ajustant couleurs et styles pour se référer à la pub avant / après, plus propre et pro », puis « change les styles, n'utilise pas les mêmes que ceux de la référence », et « intègre-la dans ardane-hq ».

- Pub principale = `main-v5-final3` (58,9 s) = `FilmMainV5Short` coupée à l'image 2332 + `FilmMainV5Part2`. Nouvelle version : `pub/film2026/v5/main-v5-final4-9x16-en.mp4` (+ `-apercu`), même durée, même voix, même musique (`mix-v5short.wav`, `mix-v5part2.wav`). Rendu : `~/ardane-tools/render_main_restyle.sh`.
- Ouverture : plus de téléphone 3D avec coque (règle d'Apple) ; l'écran « Everyday » à plat s'ouvre depuis la ligne Saphir (`HomeBuilder` de `v5/part2/Home.tsx`, props `bare`, `lineOpen`, `install`).
- Mini-apps : lumière d'ambiance (l'écran affiché, flou 90 px, assombri), coins d'iPhone (165 px de capture), pastilles sobres à point d'accent. Activé seulement par la pub principale (`v5/mainLook.ts`, contexte `MainLook`) : les films de la bibliothèque qui partagent `MiniApp5` gardent leur rendu.
- Fin (écrans d'accueil) : 6 écrans neufs (`v5/part2/configsMain.ts`) avec des styles ABSENTS de la pub avant / après : Everyday (light, ivoire), Focus (dark, indigo), Planner (editorial, argile), Neon (néon, nuit), Luxury (luxury, bronze), Aurora (aurora, bleu-sarcelle). Fonds neufs procéduraux : `scripts/ad2/make_walls_main.py` → `public/mainpub/`. Pastille du nom sous l'écran, mention « Some widgets and styles With Premium », vraies apps Apple, grille iOS.
- Légende « Endless ways to make it yours. » : texte blanc gras simple (plus de bulle lumineuse).
- Gardé tel quel : accroche (0–7 s), titres des mini-apps, « And much more », Store / Studio, carte de fin « AVAILABLE ON THE APP STORE ».
- Décision du PDG (2026-11-11) : « AVAILABLE ON THE APP STORE » PARTOUT, plus jamais « Coming soon ». Fait dans le code : `lib/i18n.json` (`close.cta`, `common.comingSoon`, `common.comingSoonShort` = « Available now », `frame.s8.sub`) et la carte de fin de la pub avant / après ; voix de fin de la pub avant / après réenregistrée (« Ardane. Available on the App Store. », Kokoro par `ardane-hq/renderer/vo_hq.py`, ancienne gardée en `vo/v3-coming-soon.wav.bak`), remixée (`music_aa.py`), rendue en `pub/avant-apres/avant-apres-v4-1080x1920.mp4`. RESTE : les voix off des pubs 01 à 08 (`scripts/ad3/spec/vo_spec_en.json`, 5 phrases « Coming soon ») et des séries V4 (timing `s-*.timing.json`) disent encore « Coming soon » : à réenregistrer au prochain rendu de ces pubs.
- Planche : `pub/film2026/check/planche-pub-principale-restyle.png`.
- Livré le 2026-11-12 vers 0 h 20 : `main-v5-final4` (58,9 s, volume identique à final3) vérifié image par image (toutes les 1,5 s), aperçu envoyé au PDG, déposé dans la boîte d'import du QG (`ardane-hq/workspace/marketing/_imports/pub-principale-v5-restylee.mp4`). Pub avant / après v4 (« Available on the App Store », son identique à la v3 jusqu'à 22 s) déposée aussi (`voici-ton-telephone-avant-apres-v4.mp4`) ; la v3 reste dans la boîte. Le PDG les soumet depuis l'Approval Center.
- Limite connue : l'écran « Focus » ne reste qu'environ 0,8 s (mêmes temps de morphing qu'avant : 586, 656, 726, 796, 866 de `part2/timing.json`).
