# 24. Campagne 2026-11 : une pub par mini-app + vidéos générales (mission de nuit du 2026-11-19)

Brief de l'utilisateur (résumé) : une pub IRL par mini-app réelle (sauf Voiture, Photos, Citation ; Fitness = la pub IRL Fitness v3, gardée telle quelle), plus des vidéos générales à angles distincts. Personnes dans des situations réelles, vraie interface actuelle, widget sur l'écran d'accueil quand c'est pertinent, signature Ardane. 9:16, 30 s idéal, 45 s au plus. Musique choisie par pub (droits vérifiés), voix off féminine anglaise (Kokoro `af_heart`, comme les pubs précédentes), effets discrets. Premières versions rendues de TOUTES les vidéos d'abord, puis contrôle qualité ; l'amélioration se fera avec l'utilisateur, une vidéo à la fois. Interdits : dépenses, publication, suppression définitive, modifier le code de l'app pour les pubs.

## Inventaire réel (code, `App/Screens/MiniApps/MiniApp.swift`)
`nutrition, fitness, planning, studies, finances, business, travel, car, photos`. Habits est une section de Planning (`app-planning-habits`) : pub à part comme demandé, en le présentant comme « dans Planning ». Exclus : car, photos (et Citation, qui n'est pas une mini-app).

## Les vidéos
| # | Film | Mode | Durée visée | Angle | Musique (candidates) |
|---|---|---|---|---|---|
| 1 | nutrition | clair | 35 s | une journée de repas : cuisine, photo du plat, estimation, suivi de l'objectif | `nutrition` |
| 2 | finances | clair | 32 s | le budget du mois : café, achat, où va l'argent, épargne | `finances` |
| 3 | planning | clair | 30 s | une semaine chargée qui devient claire : tâches, semaine, widget | `planning` |
| 4 | studies | clair, étudiant | 35 s | le semestre : photo de l'horaire, import, cours, examens, révisions, widget | `studies` |
| 5 | habits | sombre | 32 s | routines du matin au soir, cocher, séries, widget | `habits` |
| 6 | business | clair | 30 s | la petite entreprise (café, boutique, envois) : ventes, résultats, objectif | `business` |
| 7 | travel | clair | 30 s | le voyage : valise, aéroport, programme, budget, compte à rebours | `travel` |
| 8 | general-main | mixte | 40 s | « Your life, all in one place. » : plusieurs profils, une app | `general` |
| 9 | general-widgets | sombre/couleur | 30 s | un écran d'accueil banal devient le sien : Create, Studio, styles | `general` |
| 10 | general-day | mixte | 40 s | une journée : matin (habitudes), midi (repas), après-midi (cours/travail), soir (budget, séance) | `general` |
| — | fitness | n/b | 28 s | IRL Fitness v3 (déjà faite) | phonk 620567 |

## Ressources communes
- Vidéos : `~/ardane-tools/campaign/footage-candidates.txt` (Pexels, licence et règle des visages en tête du fichier). Musique : `~/ardane-tools/campaign/music-candidates.txt` (Pixabay).
- Captures de l'app actuelle : catalogue `scripts/ad2/pub26_v2/catalogue-captures.json` (ok: true), dossier `~/ardane-tools/film/public/kit2026/en/` ; lots `camp-*` (écrans) et widgets `camp-<kind>-<s|m|l>-<style>` du run CI de campagne (voir Chantiers). Enregistrements d'écran réels (scènes jouées du kit) : `~/ardane-tools/film/public/campaign/rec/`.
- Montage : `~/ardane-tools/film/src/campaign/lib.tsx` (Footage, Word, Screen, Cap, Rec, Widget, Seq, Roll) ; chaque film = `src/campaign/<film>/` avec son propre `index.ts` (registerRoot) pour ne pas toucher `Root.tsx`. Carte finale validée : `EndCard` de `src/pub26/parts.tsx`. Écran d'accueil : `HomeBuilder` (`src/v5/part2/Home.tsx`, voir IrlFitness pour un exemple).
- Son : voix `scripts/ad2/vo.py` (spec JSON comme `vo_spec_pub26.json`), mixage `scripts/ad2/campaign_mix.py` (chemins Windows `C:/…` dans les JSON).
- Rendu : un paquet et un dossier temporaire propres à chaque film, image sans son puis ffmpeg (piège : deux rendus Remotion en même temps dans `~/ardane-tools/film`).
- Livrables : `pub/campagne-2026-11/<film>/` (vidéo `ardane-<film>-v1-1080x1920.mp4`, `notes.md` : musique et source, plans Pexels, durée, points à améliorer).
