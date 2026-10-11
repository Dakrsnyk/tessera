"""The campaign's production kit (PDF): art direction, edit breakdown of the five films, live-action
shot lists, AI-video prompts, the real screen inserts, what is still missing, captions and calendar.

    python3 kit.py <films out dir> <kit out dir>
"""
import html, os, subprocess, sys

out_films, out = sys.argv[1:3]
os.makedirs(os.path.join(out, "img"), exist_ok=True)
FILES = {"main": "main/Ardane-pub-principale-40s.mp4", "short": "short/Ardane-pub-15s.mp4", "tiny": "tiny/Ardane-pub-8s.mp4",
         "fitness": "fitness/Ardane-pub-fitness-20s.mp4", "nutrition": "nutrition/Ardane-pub-nutrition-20s.mp4"}

def frame(film, t):
    src = os.path.join(out_films, FILES[film])
    dst = os.path.join(out, "img", f"{film}-{t:05.1f}.jpg")
    if os.path.exists(src) and not os.path.exists(dst):
        subprocess.call(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", str(t), "-i", src, "-frames:v", "1",
                         "-vf", "scale=270:-1:flags=lanczos", "-q:v", "3", dst])
    return "img/" + os.path.basename(dst) if os.path.exists(dst) else None

e = html.escape

# ---------------------------------------------------------------- the five films
# (timecode, shot, real screen, text on screen, transition, sound, storyboard time)
FILMS = [
 ("main", "Film principal · 40 s", "TikTok, Reels, Shorts, publicité Meta/TikTok (9:16)",
  "100 BPM (mesure = 2,4 s) · intro pad → montée → plein régime 19,2–28,8 s → retombée → impact sur la signature à 33,6 s", [
  ("0:00–0:04.8", "Accroche", "Écran verrouillé rendu par l'app : widgets Macros + anneaux, activité en direct « Pompes · Repos 1:24 »", "Ta journée. / En un coup d'œil.", "Fond nuit ; l'iPhone s'avance en 3D, l'écran s'allume, reflet sur la vitre", "Verrouillage 0:00.35 · carillon 0:01.7 · pad seul", 2.6),
  ("0:04.8–0:09.6", "Sport", "Enregistrement Fitness : séance en cours Full body, semaine en ronds, jours touchés (Bas du corps, Full body)", "SPORT · Chaque série compte.", "Volet crème qui monte (0,55 s) ; l'activité en direct arrive de la gauche", "Whoosh 4.55 · snap 5.7 · touchers 6.5 / 8.3", 7.0),
  ("0:09.6–0:14.4", "Nutrition", "Enregistrement Nutrition : « Ajouter un aliment » → Yogourt grec → Enregistrer → 1 019 kcal restantes", "NUTRITION · Tes macros, en deux gestes.", "Le téléphone entre par la gauche ; widgets Macros et Calories en ressort", "Whoosh 9.35 · snap 10.4 · touchers 11.3 / 12.6", 12.0),
  ("0:14.4–0:19.2", "Au quotidien", "Enregistrement Mon Quotidien qui défile : nutrition, séance, habitudes, À ne pas oublier, semaine en tableau", "AU QUOTIDIEN · Toute ta journée, sur un écran.", "Le téléphone monte du bas, se redresse", "Whoosh 14.15", 17.0),
  ("0:19.2–0:24.0", "Studio", "Enregistrement Studio : thèmes, puis palettes Océan et Corail sur le widget Macros", "STUDIO · Des widgets à ton image.", "Trois widgets stylés (Néon, Luxe, Aurore) flottent à gauche", "Whoosh 18.95 · snap 20.0", 22.0),
  ("0:24.0–0:28.8", "Écrans d'accueil", "Écrans d'accueil Aurore, Jade et Océan rendus par l'app (vrais widgets)", "ÉCRANS D'ACCUEIL · Ton iPhone, réinventé.", "Trois téléphones montent en éventail, reflet en cascade", "Whoosh 23.75 · 3 snaps 24.4 / 24.7 / 25.0", 26.5),
  ("0:28.8–0:31.2", "Budget", "Enregistrement Finances : solde Mois → 3 mois → Année", "BUDGET · Ton argent, enfin clair.", "Le téléphone monte, sort par la gauche", "Whoosh 28.55", 30.0),
  ("0:31.2–0:33.6", "Icônes", "Enregistrement « Icône de l'app » : Corail, Classique, Verre classique, 16 verres", "JUSQU'À L'ICÔNE · Ardane, à ton style.", "Le téléphone pivote depuis la droite", "Whoosh 30.95", 32.6),
  ("0:33.6–0:40.0", "Signature", "Logo Ardane (deux moitiés du A)", "Ardane · Ta vie, en widgets. · Bientôt sur l'App Store", "Cercle corail qui s'ouvre, les deux moitiés glissent, le nom monte", "Impact 33.6 · carillon 35.0 · queue musicale", 37.5)]),
 ("short", "Film 15 s", "TikTok/Reels organiques, pré-roll Shorts",
  "Une mesure par plan (2,4 s), plein régime au milieu, impact à 12 s", [
  ("0:00–0:02.4", "Accroche", "Écran verrouillé rendu par l'app", "Ta journée, en widgets.", "Fond nuit, l'iPhone s'avance", "Verrouillage 0.25", 1.6),
  ("0:02.4–0:04.8", "Sport", "Fitness : jours de la semaine touchés", "SPORT · Chaque série compte.", "Volet crème ; activité en direct", "Whoosh 2.15 · snap 3.0 · toucher 3.3", 3.8),
  ("0:04.8–0:07.2", "Nutrition", "Ajout du yogourt (3 coupes)", "NUTRITION · Tes macros, sans effort.", "Entrée par la gauche ; widget Macros", "Whoosh 4.55 · toucher 5.5", 6.2),
  ("0:07.2–0:09.6", "Écrans d'accueil", "Aurore, Jade, Océan", "Ton iPhone, réinventé.", "Éventail de trois téléphones", "Whoosh 6.95 · 3 snaps", 8.6),
  ("0:09.6–0:12.0", "Studio", "Thème, palettes Océan → Corail", "STUDIO · À ton image.", "Le téléphone monte", "Whoosh 9.35", 11.0),
  ("0:12.0–0:15.0", "Signature", "Logo", "Ardane · Ta vie, en widgets.", "Cercle corail", "Impact 12.0 · carillon 13.4", 14.0)]),
 ("tiny", "Film 8 s", "Stories, bumper, publicité courte",
  "Trois plans : écrans d'accueil, Studio, signature", [
  ("0:00–0:02.4", "Écrans d'accueil", "Aurore, Jade, Océan", "Ton iPhone, à ta façon.", "Éventail sur fond crème", "3 snaps 0.4 / 0.7 / 1.0", 1.6),
  ("0:02.4–0:04.8", "Studio", "Thème, palettes Océan → Corail", "(même titre)", "Le téléphone monte du bas", "Whoosh 2.15", 3.8),
  ("0:04.8–0:08.0", "Signature", "Logo", "Ardane · Ta vie, en widgets.", "Cercle corail", "Impact 4.8 · carillon 6.2", 7.0)]),
 ("fitness", "Film Fitness · 20 s", "Ciblage sport/musculation",
  "Ambiance « salle » (fond sombre rouge), plein régime pendant la séance", [
  ("0:00–0:04.8", "Accroche", "Écran verrouillé + activité en direct agrandie (rendus de l'app)", "ÉCRAN VERROUILLÉ · Série faite ? Un geste.", "Fond salle sombre ; zoom sur l'activité en direct", "Verrouillage 0.3 · snap 2.8", 3.6),
  ("0:04.8–0:12.0", "Ta séance", "Enregistrement Fitness : séance en cours, semaine, records, jours touchés", "TA SÉANCE · Chaque série, chaque repos.", "Volet crème ; le téléphone monte", "Whoosh 4.55 · touchers 9.2 / 11.0", 8.0),
  ("0:12.0–0:14.4", "Tes widgets", "Image Fitness + widgets Prochaine série et Séance du jour", "TES WIDGETS · Ton programme, sous les yeux.", "Le téléphone entre à droite, les widgets en ressort", "Whoosh 11.8 · snaps 12.5 / 12.75", 13.5),
  ("0:14.4–0:20.0", "Signature", "Logo", "Ardane · Ton sport, en widgets.", "Cercle corail", "Impact 14.4 · carillon 15.8", 18.0)]),
 ("nutrition", "Film Nutrition · 20 s", "Ciblage nutrition/minceur/macros",
  "Ouverture nuit sur le scan, plein régime pendant l'ajout", [
  ("0:00–0:04.8", "Scan (illustration)", "AUCUN écran : étiquette de produit dessinée + carré de visée orange (le scanner réel lit les codes EAN/UPC des produits emballés)", "SCAN · Un code-barres, et c'est noté.", "L'étiquette se lève, le carré se verrouille", "Whoosh 0.2 · toucher 2.6 · carillon 2.95", 2.9),
  ("0:04.8–0:12.0", "Ton repas", "Enregistrement Nutrition : Ajouter → Yogourt grec ¾ tasse → Enregistrer → 1 019 kcal, collation dans la liste", "TON REPAS · Tes calories, en deux gestes.", "Volet crème ; le téléphone monte", "Whoosh 4.55 · touchers 6.9 / 7.7 / 9.0", 8.0),
  ("0:12.0–0:14.4", "Tes widgets", "Écran verrouillé sans activité + widget Macros + pastille Macros (rendus de l'app)", "TES WIDGETS · Tes macros, d'un regard.", "Le téléphone entre à droite, widgets en ressort", "Whoosh 11.8 · snaps 12.6 / 12.85", 13.5),
  ("0:14.4–0:20.0", "Signature", "Logo", "Ardane · Ta nutrition, en widgets.", "Cercle corail", "Impact 14.4 · carillon 15.8", 18.0)]),
]

def film_section(key, title, use, music, shots):
    strip = "".join(f'<figure><img src="{frame(key, s[6])}"><figcaption>{e(s[0])}</figcaption></figure>' for s in shots if frame(key, s[6]))
    rows = "".join(f"<tr><td class=tc>{e(a)}</td><td><b>{e(b)}</b><br><span class=muted>{e(c)}</span></td><td>{e(d)}</td><td>{e(t)}</td><td>{e(s)}</td></tr>"
                   for a, b, c, d, t, s, _ in shots)
    return f"""<section class="film"><div class=head><h2>{e(title)}</h2><p class=meta><b>Usage :</b> {e(use)}<br><b>Musique :</b> {e(music)}</p>
<div class=strip>{strip}</div></div>
<table><thead><tr><th>Temps</th><th>Plan · écran réel montré</th><th>Texte à l'écran</th><th>Transition / mouvement</th><th>Son</th></tr></thead><tbody>{rows}</tbody></table></section>"""

# ---------------------------------------------------------------- live action
SHOOTS = [
 ("A · Salle de sport", "Film Fitness en prises de vue réelles (20–30 s)", [
  ("Large, 35 mm, trépied", "Salle au petit matin, lumière latérale chaude. La personne pose son iPhone sur le banc.", "2 s", "—"),
  ("Gros plan, 85 mm, 60 i/s (ralenti)", "Mains sur la barre, dernière répétition, souffle.", "1,5 s", "—"),
  ("Insert, 50 mm macro, au-dessus du banc", "Écran verrouillé, activité en direct « Pompes · Repos » ; le pouce touche « Série faite ».", "2 s", "Filmer l'écran réel de l'app (luminosité max, Ne pas déranger)"),
  ("Plan moyen, épaule, 50 mm", "Elle/il jette un œil au téléphone, sourit, repart pour la série suivante.", "2 s", "—"),
  ("Insert écran (enregistrement iPhone)", "Fitness : semaine en ronds, records.", "3 s", "Enregistrement d'écran iOS (Centre de contrôle)"),
  ("Large, sortie de salle", "La personne quitte la salle, téléphone en main → signature Ardane.", "2 s", "Raccord sur la carte corail")]),
 ("B · Cuisine et scan", "Film Nutrition en prises de vue réelles (20–30 s)", [
  ("Plan moyen, 35 mm, lumière du matin", "Cuisine claire ; la personne sort un pot de yogourt grec emballé du frigo.", "2 s", "—"),
  ("Gros plan, 50 mm", "L'iPhone au-dessus du code-barres, le carré de visée de l'app se verrouille.", "2 s", "MANQUANT : enregistrement réel du scanner sur iPhone"),
  ("Insert écran", "Fiche aliment, quantité ¾ tasse, « Enregistrer ».", "2 s", "Enregistrement d'écran iOS"),
  ("Insert écran, macro", "L'anneau des calories restantes se met à jour.", "1,5 s", "Enregistrement d'écran iOS"),
  ("Plan moyen, table", "Bol de yogourt, le téléphone posé, écran verrouillé avec le widget Macros.", "2 s", "Widget installé sur l'écran verrouillé réel")]),
 ("C · Une journée", "Film principal en prises de vue réelles (30–45 s)", [
  ("Gros plan, table de nuit", "Réveil : l'écran verrouillé s'allume avec les widgets.", "2 s", "Écran verrouillé réel"),
  ("Plan moyen, métro ou café", "Le pouce fait défiler Mon Quotidien.", "2,5 s", "Enregistrement d'écran"),
  ("Plan serré, bureau", "Écran d'accueil avec widgets Planning et Tâches.", "2 s", "Écran d'accueil réel"),
  ("Salle de sport (voir A)", "« Série faite » sur l'écran verrouillé.", "2 s", "—"),
  ("Cuisine (voir B)", "Scan d'un produit emballé.", "2 s", "—"),
  ("Soir, canapé", "Finances : solde du mois, la personne range le téléphone, détendue.", "2 s", "Enregistrement d'écran"),
  ("Insert", "Appui long sur l'icône → « Changer d'icône » → Verre classique.", "2 s", "Écran d'accueil réel")]),
]

PROMPTS = [
 ("Salle de sport, banc", "Cinematic close-up in a modern gym at early morning, warm side light, shallow depth of field. A smartphone lies on a weight bench next to a towel; a hand with chalk reaches in and taps the phone screen once, then lifts a dumbbell out of frame. The phone screen is a flat solid chroma green (#00B140) with four small white cross tracking markers near its corners, no reflections, no text, no logos. Handheld but stable, 50mm lens, 24 fps, natural skin tones."),
 ("Salle de sport, regard", "Medium shot of a 28-year-old athlete between sets in a gym, breathing, glancing down at a smartphone held at chest height, then smiling slightly and putting it in a pocket. The phone screen faces the camera at a slight angle and is a flat solid chroma green (#00B140) with four small white cross tracking markers near its corners. Soft rim light, background softly out of focus, no brand names, no text, 24 fps."),
 ("Cuisine, produit emballé", "Bright kitchen in the morning. Over-the-shoulder shot: a person holds a smartphone above a plain unbranded yogurt pot whose label shows only a generic barcode. The phone screen is a flat solid chroma green (#00B140) with four small white cross tracking markers near its corners, steady for 2 seconds, then the hand lowers the phone. No logos, no text other than the barcode, shallow depth of field, 24 fps."),
 ("Table de nuit, réveil", "Top-down shot of a wooden nightstand at dawn, blue hour light through curtains. A smartphone lies face up; its screen is a flat solid chroma green (#00B140) with four small white cross tracking markers near its corners. A hand enters and picks it up slowly. Calm, minimal, no text, no logos, 24 fps."),
 ("Métro, défilement", "Close-up of a thumb scrolling slowly on a smartphone held in one hand inside a sunlit subway car, city passing in the background bokeh. The phone screen is a flat solid chroma green (#00B140) with four small white cross tracking markers near its corners. Natural motion, 24 fps, no text, no logos."),
]

INSERTS = [
 ("Mon Quotidien", "testVideoMonQuotidien.mp4", "18–48 s : la journée défile de haut en bas, puis remonte"),
 ("Fitness", "testVideoFitness.mp4", "16,6–34 s : séance en cours, semaine en ronds, records, jours touchés (27,6–33 s)"),
 ("Nutrition", "testVideoNutrition.mp4", "8–35 s : écran, « Ajouter un aliment » (14,9 s), Yogourt grec (20,3 s), Enregistrer (23,5 s), résultat 1 019 kcal"),
 ("Studio", "testVideoStudio.mp4", "8–18 s : contenu puis thèmes ; 62–77 s : palettes Océan (64,9 s) et Corail (68,9 s)"),
 ("Finances", "testVideoFinances.mp4", "14–38 s : solde Mois → 3 mois (19,9 s) → Année (23,0 s) → Mois (27,4 s), catégories"),
 ("Icône de l'app", "testVideoIcons.mp4", "14–27 s : la grille des 19 icônes, défilement"),
 ("Store", "testVideoStore.mp4", "22–58 s : À la une, collection Halloween, écran Espace, À découvrir"),
 ("Planning", "testVideoPlanning.mp4", "50–53 s seulement (prise trop courte, à refaire)"),
 ("Lancement", "testVideoLaunch.mp4", "inutilisable (l'animation n'a pas été filmée)"),
]

MISSING = [
 ("Personnes et lieux réels", "Aucune personne réelle n'a été filmée : les films livrés sont des films produit (motion design + vrais écrans). Les séquences salle / cuisine / quotidien sont décrites dans ce kit, à tourner (ou à générer en IA puis composer avec les vrais écrans)."),
 ("Scanner de code-barres en vrai", "Le simulateur de la CI n'a pas de caméra : le plan « Scan » du film Nutrition est une illustration (étiquette dessinée, carré de visée). À remplacer par un enregistrement d'écran sur iPhone scannant un produit emballé (EAN/UPC)."),
 ("Activité en direct sur un vrai écran verrouillé", "L'écran verrouillé et l'activité en direct sont rendus par l'app (vue Marketing, mêmes composants), pas capturés par iOS. À refilmer sur iPhone ; sans compte Apple Developer, les activités en direct peuvent ne pas marcher en sideload."),
 ("Widgets sur un vrai écran d'accueil", "Les écrans Aurore, Jade, Océan sont dessinés par l'app avec les vrais widgets, mais ce ne sont pas des captures de l'écran d'accueil iOS. À refaire sur un iPhone avec les widgets installés."),
 ("Moments manqués par la CI", "« Série faite » dans la séance (le test a changé de jour avant), les touches sur les thèmes du Studio (seules les palettes ont été filmées), l'animation de lancement et le Planning. Corrigeables dans PromoVideoUITests puis un nouveau passage [video]."),
 ("Musique sous licence / son tendance", "La musique est une composition originale synthétisée ici, libre de droits, sans voix. Sur TikTok, un son de la Commercial Music Library (seule bibliothèque autorisée pour un compte entreprise et les publicités) peut améliorer la portée : utiliser la version « sans musique » et ajouter le son dans l'app."),
 ("Badge App Store officiel", "Les films disent « Bientôt sur l'App Store ». Le badge Apple « Télécharger dans l'App Store » et le lien ne s'utilisent qu'une fois l'app publiée (compte Apple Developer requis)."),
 ("Version anglaise", "Les enregistrements sont en français. Pour une version EN : relancer la CI [video] avec l'app en anglais, puis traduire les titres dans films.js."),
 ("Voix off", "Aucune voix off. Script optionnel : « Ta journée tient sur un écran. Ta séance, tes repas, ton budget… en widgets. Ardane. »"),
]

CAPTIONS = [
 ("Film principal 40 s", "Ta journée entière, en widgets. Séance, repas, budget, planning… et ton iPhone à ton style. Ardane arrive bientôt sur l'App Store.",
  "Your whole day, in widgets. Workouts, meals, budget, planning… and an iPhone that looks like you. Ardane, coming soon to the App Store.",
  "#widgets #iphone #ecrandaccueil #productivite #ios", "#iphonewidgets #homescreen #iossetup #productivity #ios"),
 ("Film 15 s", "Ton iPhone, réinventé en 15 secondes. 📱", "Your iPhone, reinvented in 15 seconds. 📱",
  "#iphone #widgets #personnalisation #aesthetic", "#iphone #widgets #aesthetichomescreen #iphonetips"),
 ("Film 8 s", "Ton écran d'accueil, à ta façon.", "Your Home Screen, your way.", "#ecrandaccueil #widgets #iphone", "#homescreen #widgets #iphone"),
 ("Fitness 20 s", "Série faite ? Un geste sur l'écran verrouillé. Ta séance, tes repos, tes records : tout est là.",
  "Set done? One tap on the Lock Screen. Your workout, your rest, your records, all there.",
  "#musculation #fitness #salledesport #workout #iphone", "#gymtok #fitnessapp #workout #liftinglife #iphone"),
 ("Nutrition 20 s", "Tes calories en deux gestes, tes macros d'un regard. Scanne un produit emballé, c'est noté.",
  "Calories in two taps, macros at a glance. Scan a packaged food and it's logged.",
  "#nutrition #macros #compteurdecalories #reequilibragealimentaire", "#macros #caloriecounter #nutrition #mealprep"),
]

CALENDAR = [
 ("Lun S1", "Film principal 40 s", "TikTok + Reels", "19 h–21 h"),
 ("Mer S1", "Fitness 20 s", "TikTok + Reels", "7 h–8 h ou 18 h"),
 ("Ven S1", "Nutrition 20 s", "TikTok + Reels", "12 h–13 h"),
 ("Dim S1", "Film 15 s", "Shorts + Reels", "18 h–20 h"),
 ("Mar S2", "Film 8 s", "Stories Instagram + TikTok", "12 h"),
 ("Jeu S2", "Coulisses : écran d'accueil réel avant/après (tourné au téléphone)", "TikTok", "19 h"),
 ("Sam S2", "Meilleur des cinq relancé (version sans musique + son tendance)", "TikTok", "11 h"),
]

def table(head, rows):
    return "<table><thead><tr>" + "".join(f"<th>{e(h)}</th>" for h in head) + "</tr></thead><tbody>" + \
        "".join("<tr>" + "".join(f"<td>{e(c)}</td>" for c in r) + "</tr>" for r in rows) + "</tbody></table>"

font = "file:///usr/share/fonts/opentype/inter/"
page = f"""<!doctype html><html lang="fr"><head><meta charset="utf-8"><title>Ardane — kit de campagne</title><style>
@font-face{{font-family:Disp;src:url({font}InterDisplay-Bold.otf)}}
@font-face{{font-family:Text;src:url({font}Inter-Regular.otf)}}
@font-face{{font-family:TextB;src:url({font}Inter-SemiBold.otf)}}
@page{{size:A4;margin:14mm 13mm}}
body{{font-family:Text;font-size:9.6pt;color:#1A1516;line-height:1.45}}
h1{{font-family:Disp;font-size:30pt;letter-spacing:-.5pt;margin:0 0 4pt}}
h2{{font-family:Disp;font-size:17pt;margin:18pt 0 6pt;color:#1A1516}}
h3{{font-family:TextB;font-size:11pt;margin:12pt 0 4pt}}
b,th{{font-family:TextB;font-weight:normal}}
.cover{{background:linear-gradient(160deg,#FF7A59,#D9246A);color:#fff;border-radius:14pt;padding:26pt 24pt;margin-bottom:12pt}}
.cover p{{font-size:11pt;margin:4pt 0}}
.muted{{color:#6B6460}} .meta{{margin:0 0 8pt}}
table{{width:100%;border-collapse:collapse;margin:6pt 0 10pt;font-size:8.6pt}}
th{{text-align:left;background:#F3EEE7;padding:5pt 6pt}} td{{padding:5pt 6pt;border-bottom:.6pt solid #E6DED3;vertical-align:top}}
td.tc{{white-space:nowrap;font-family:TextB}}
.head{{break-inside:avoid}} .strip{{display:flex;gap:6pt;margin:6pt 0}} .strip figure{{margin:0;flex:0 1 80pt;text-align:center}}
.strip img{{width:100%;border-radius:6pt;display:block}} .strip figcaption{{font-size:7.5pt;color:#6B6460;margin-top:2pt}}
h2,h3{{break-after:avoid}} .strip,tr{{break-inside:avoid}} .break{{break-before:page}}
.swatch{{display:inline-block;width:12pt;height:12pt;border-radius:3pt;vertical-align:-2pt;margin-right:4pt}}
code{{font-size:8.4pt;background:#F3EEE7;padding:1pt 3pt;border-radius:3pt}}
.note{{background:#FFF4EE;border-left:3pt solid #FF7A59;padding:6pt 9pt;border-radius:4pt;margin:8pt 0}}
</style></head><body>
<div class="cover"><h1>Ardane — campagne vidéo</h1><p>Kit de production · 5 films 9:16 · octobre 2026</p>
<p>Ce qui est livré : des films produit finis (motion design + vrais écrans de l'app), avec et sans musique, plus ce kit pour tourner les scènes avec des personnes réelles.</p></div>

<div class="note"><b>Honnêteté du contenu.</b> Chaque écran montré vient de l'app : enregistrements du simulateur iPhone (CI, données de démonstration) ou rendus que l'app dessine elle-même (écran verrouillé, écrans d'accueil, widgets). Aucune interface inventée, aucune fausse reconnaissance. Seule exception, signalée : le plan « Scan » du film Nutrition est une illustration graphique, à remplacer par une vraie capture du scanner.</div>

<h2>Fichiers livrés</h2>
{table(["Fichier", "Contenu"], [
 ("Ardane-pub-principale-40s.mp4", "Film principal, musique + bruitages"),
 ("Ardane-pub-15s.mp4 · Ardane-pub-8s.mp4", "Versions courtes"),
 ("Ardane-pub-fitness-20s.mp4 · Ardane-pub-nutrition-20s.mp4", "Versions ciblées"),
 ("…-sans-musique.mp4", "Bruitages seuls, pour poser un son tendance sur TikTok/Instagram"),
 ("…-apercu.gif", "Aperçus légers"),
 ("Sources (dépôt, scripts/ads/)", "prep.py (clips et détourage), engine/ (moteur de rendu, films.js = montage), audio/synth.py (musique et bruitages), make.py (assemblage), kit/"),
])}
<p class="muted">Format : 1080 × 1920, 30 i/s, H.264 High, AAC 48 kHz 192 kb/s, environ −16,5 LUFS. Zones sûres TikTok/Reels respectées pour les titres (haut 190 px, rien d'important à droite au-delà de 940 px).</p>

<h2>Direction artistique</h2>
<p><span class="swatch" style="background:linear-gradient(160deg,#FF7A59,#D9246A)"></span><b>Corail Ardane</b> #FF7A59 → #D9246A (signature, icône) ·
<span class="swatch" style="background:#F7F4EF;border:.6pt solid #ddd"></span><b>Crème</b> #F7F4EF (fond des plans produit) ·
<span class="swatch" style="background:#0B0A10"></span><b>Nuit</b> #0B0A10 avec halos corail (accroches) ·
couleur d'accent par univers : Sport #E5484D, Nutrition #F08A24, Quotidien #3366FF, Studio #8A3CFF, Budget #1E9E75.</p>
<p><b>Typo :</b> Inter Display Bold pour les titres (96 px, interlignage serré), Inter SemiBold pour les surtitres en capitales espacées. <b>Rythme :</b> 100 BPM, une mesure = 2,4 s ; chaque coupe tombe sur une mesure. <b>Mouvement :</b> iPhone en 3D qui s'avance et se redresse, titres révélés ligne par ligne derrière un masque, widgets réels qui arrivent avec un léger rebond, reflet qui balaie la vitre. <b>Son :</b> musique originale (kick, basse, clap, arpèges, pad), bruitages calés sur les vrais touchers de l'enregistrement.</p>

<div class="break"></div><h2>Découpage des films</h2>
{"".join(film_section(*f) for f in FILMS)}

<div class="break"></div><h2>Tournage en prises de vue réelles</h2>
<p>Le plus crédible : filmer de vraies personnes avec l'app installée sur un vrai iPhone (l'IPA de test), et enregistrer l'écran en parallèle (Centre de contrôle → Enregistrement de l'écran) pour les inserts. Réglages : mode Ne pas déranger, luminosité max, True Tone désactivé, 4K 24 ou 30 i/s, ralentis en 60 i/s. Autorisations : droit à l'image signé par chaque personne, accord écrit de la salle de sport.</p>
{"".join(f"<h3>{e(t)} — <span class=muted>{e(s)}</span></h3>" + table(["Cadre", "Action", "Durée", "Écran"], rows) for t, s, rows in SHOOTS)}

<h2>Prompts vidéo IA (écran vert à remplacer)</h2>
<p>Pour Veo, Sora, Kling ou Runway. L'écran du téléphone est généré en vert uni avec quatre repères de suivi : on y incruste ensuite le vrai enregistrement (DaVinci Resolve gratuit : Planar Tracker + Incrustation ; ou After Effects + Mocha ; CapCut ordinateur en dépannage). Ne jamais laisser l'IA dessiner l'interface. Les personnes générées sont fictives : cocher « Contenu généré par IA » sur TikTok et Instagram.</p>
<p class="muted">Négatif conseillé : <code>text, logos, brand names, user interface, app screens, extra fingers, distorted hands, reflections on screen</code></p>
{table(["Scène", "Prompt (anglais, meilleur rendu)"], PROMPTS)}

<div class="break"></div><h2>Inserts d'écran réels fournis</h2>
<p>Enregistrements de la CI (simulateur iPhone, 1206 × 2622, français, données de démonstration), dans le rapport CI <code>videos/</code> :</p>
{table(["Scène", "Fichier", "Moments utiles"], INSERTS)}
<p>Rendus par l'app (<code>videos/assets</code>) : écran verrouillé avec et sans activité en direct, 5 écrans d'accueil (Aurore, Crème, Jade, Minuit, Océan), 14 widgets détourés (Macros, Calories, Prochaine série, Séance du jour, Régularité, Méditer, Budget, Semaine, Aujourd'hui…), activité en direct, pastille Macros, Dynamic Island.</p>

<h2>Éléments réels manquants</h2>
{table(["Élément", "Pourquoi et comment le compléter"], MISSING)}

<div class="break"></div><h2>Légendes et hashtags</h2>
{table(["Film", "Français", "English", "Hashtags FR", "Hashtags EN"], CAPTIONS)}
<p class="muted">3 à 5 hashtags suffisent. Première ligne = l'accroche, visible sans « plus ». Répondre aux commentaires dans la première heure.</p>

<h2>Calendrier de publication (2 semaines)</h2>
{table(["Jour", "Film", "Où", "Heure (locale)"], CALENDAR)}
<p class="muted">Ensuite : garder le film qui retient le mieux (taux de visionnage complet, partages) et le décliner (nouvelle accroche, autre son). Publicités : commencer par le film 15 s et le Fitness, petits budgets, 3 à 5 jours par test.</p>
</body></html>"""
open(os.path.join(out, "kit.html"), "w").write(page)
pdf = os.path.join(out, "Ardane-kit-campagne.pdf")
subprocess.check_call(["node", "-e", f"""
const {{ chromium }} = require('/opt/node-tools/node_modules/playwright');
(async () => {{ const b = await chromium.launch({{ executablePath: '/opt/pw-browsers/chromium', args: ['--allow-file-access-from-files'] }});
const p = await b.newPage(); await p.goto('file://{os.path.abspath(os.path.join(out, "kit.html"))}'); await p.evaluate(() => document.fonts.ready);
await p.pdf({{ path: '{os.path.abspath(pdf)}', format: 'A4', printBackground: true, margin: {{ top: '14mm', bottom: '14mm', left: '13mm', right: '13mm' }} }});
await b.close(); }})();"""])
print(pdf)
