/* photos.js : le JS commun du sujet « Photos et citations », refonte UX/UI des mini-apps, 2026-11-17.
   À charger après ../../2026-11-15-cristal/cristal.js et ../base/planches.js, avant le script de la planche. CSS : photos.css (préfixe pho-).
   Il contient :
     FONCTIONS (alias FEATURES)  la liste F1…F27 de l'audit (../audit/09-photos.md, section 4), dans son ordre, avec ses numéros.
                                 [n°, libellé court, accès 'G' | 'P' | 'G+P', ce qu'elle fait en quelques mots]
     PHO                         les données d'exemple du sujet (jeudi 12 novembre 2026, 13 h 20).
     PHO.ui                      pièces d'écran communes : widget dessiné (cadres dégradés), tuile de la grille, bloc « Un par jour ».
   Règles :
     - Aucun repère existant pour ce sujet : tout est fixé UNE FOIS ici. Jamais de vraie photo : des cadres dégradés aux couleurs de la mini-app.
       Les citations sont du domaine public ou des phrases neutres inventées. Les 8 paires de couleurs ont les VRAIS NOMS de l'app (audit F13) ;
       seules « Papier » (F6F0E6 / 2B2622, audit section 5) a ses vraies teintes, les sept autres sont des teintes d'exemple.
     - Compte montré : GRATUIT. Aucune limite ni verrou Premium dans cette mini-app (audit section 4 : 0 fonction Premium).
     - Valeur inconnue : jamais zéro. Le widget vide écrit « Ta citation ici » (audit F11).
     - Ce qui n'existe pas dans l'app est rangé sous PHO.nouveau et nulle part ailleurs : à étiqueter « Nouveau » sur les planches
       (demande du PDG : « Mes textes » importés, réglage « Un par jour », « Aujourd'hui » sur la page principale). */

/* ================= 1. Les 27 fonctions existantes (audit, section 4) ================= */
const FONCTIONS = [
  ['F1', 'Créer un widget Photos', 'G', 'Bouton « Photos » ; ouvre l\'éditeur avec un widget Petit nommé « Mes photos »'],
  ['F2', 'Créer un widget Citation', 'G', 'Bouton « Citation » ; ouvre l\'éditeur avec un widget Petit nommé « Ma citation », citation vide'],
  ['F3', 'Grille « Mes widgets »', 'G', 'Aperçu réel, nom, type · taille ; tri par dernier usage ; toucher une tuile ouvre l\'éditeur'],
  ['F4', 'Compteur de widgets', 'G', 'Nombre de widgets Photos et Citation (bandeau de la page et puce de l\'accueil)'],
  ['F5', 'Choisir la taille', 'G', '« Petit », « Moyen », « Grand » ; l\'aperçu suit ; modifiable après coup'],
  ['F6', 'Choisir des photos', 'G', '« Choisir des photos » / « Ajouter des photos » ; 12 au plus ; chaque photo est copiée et réduite'],
  ['F7', 'Mise en page automatique', 'G', '1 : plein cadre ; 2 : côte à côte ; 3 : une grande et deux petites ; 4 : grille 2 × 2'],
  ['F8', 'Rotation au-delà de 4 photos', 'G', 'Le widget en montre 4 à la fois, puis les suivantes chaque heure ; pas réglable'],
  ['F9', 'Recadrer une photo', 'G', 'Feuille « Recadrer » : glisser, pincer, « Zoom » de 1 à 4, « Réinitialiser », « Annuler », « OK »'],
  ['F10', 'Ordre et retrait des photos', 'G', '« Avancer », « Reculer », « Retirer » (menu d\'appui long sur une vignette)'],
  ['F11', 'Écrire la citation', 'G', '« Ta citation » (280 caractères au plus) et « Auteur (facultatif) » ; « Ta citation ici » tant que c\'est vide'],
  ['F12', 'Typographie de la citation', 'G', '« Serif » (italique), « Arrondie », « Standard », « Mono »'],
  ['F13', 'Couleurs de la citation', 'G', '8 paires (« Papier », « Nuit », « Corail », « Océan », « Forêt », « Rose », « Sable », « Lilas ») ; « Fond » et « Texte » libres'],
  ['F14', 'Photo de fond d\'une citation', 'G', '1 photo ; « Voile pour la lisibilité » ; « Choisir une photo », « Recadrer », « Changer de photo », « Retirer »'],
  ['F15', 'Options de la citation', 'G', 'Interrupteurs « Centrée » et « Guillemets »'],
  ['F16', 'Exemple de citation', 'G', '« Essayer avec un exemple » : une citation (Saint-Exupéry), seulement si le texte est vide'],
  ['F17', 'Nommer le widget', 'G', '« Nom du widget » ; un nom vide devient « Photos » ou « Citation »'],
  ['F18', 'Aperçu en direct', 'G', 'Le widget tel qu\'il sera posé ; ne se touche pas'],
  ['F19', 'Enregistrer / Annuler', 'G', '« Enregistrer » grisé sans photo ou sans texte ; « Annuler » efface les copies inutiles'],
  ['F20', 'Supprimer un widget', 'G', '« Supprimer ce widget » puis confirmation ; efface aussi les copies de photos'],
  ['F21', 'Aide pour poser le widget', 'G', 'Note de pied : « Pour le poser : touche longuement l\'écran d\'accueil, puis + › Ardane… »'],
  ['F22', 'Photo disparue', 'G', '« Photo indisponible » dans la case ; la citation reprend ses deux couleurs'],
  ['F23', 'Modes Clair et Teinté d\'iOS', 'G', 'Photos gardées en couleur ; photo sous une citation désaturée et pâle, sans voile'],
  ['F24', 'Renouvellement du widget posé', 'G', 'Plus de 4 photos : à l\'instant présent puis 6 heures pleines ; sinon aucun ; citation : jamais'],
  ['F25', 'Toucher le widget posé', 'G', 'Ouvre l\'éditeur sur ce widget (lien tessera://design/<id>)'],
  ['F26', 'Actions de Mes widgets sur ces widgets', 'G', '« Modifier », « Dupliquer », « Créer une variante », « Favori », « Ajouter à l\'écran », « Supprimer »'],
  ['F27', 'Fusionner deux widgets', 'G', 'Mes widgets › « Sélectionner » › « Fusionner » ; rendu à vérifier sur l\'iPhone'],
];
const FEATURES = FONCTIONS;

/* ================= 2. Les données d'exemple ================= */
const PHO = (function () {
  const dt = (y, m, j, h = 0, mi = 0) => new Date(Date.UTC(y, m - 1, j, h, mi));
  const jour0 = (d) => Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
  const nj = (a, b) => Math.round((jour0(b) - jour0(a)) / 864e5);
  const AUJ = dt(2026, 11, 12, 13, 20);                                                    // jeudi 12 novembre 2026, 13 h 20

  /* ---------- 12 cadres dégradés (un ciel, un soleil, un sol) : jamais de vraie photo ---------- */
  const TONS = [
    ['#F6B2A0', '#E58AA6', '#7C5A86', '#FFE7B8'], ['#CFE3F2', '#F3E3D0', '#6F8F72', '#FFF3D6'], ['#2F4B6E', '#6C86B0', '#E8A9A0', '#FFE2B0'],
    ['#F4D6A0', '#F0A86E', '#8A5A44', '#FFF6DA'], ['#BFD8E6', '#9EC1A8', '#4F7A66', '#FFFFFF'], ['#EAC4D5', '#C9A6E0', '#5F4B8B', '#FFF0F6'],
    ['#FFD9B0', '#F29A7B', '#6A4A5E', '#FFF4E0'], ['#A9C8E8', '#D4B5E8', '#4C5C8A', '#FFFFFF'], ['#F7E0B5', '#D9A66A', '#5E6E4E', '#FFF8E6'],
    ['#8FB3C9', '#C9D9E3', '#3F6B5C', '#FFFFFF'], ['#F2B8B0', '#EC8FA5', '#5A4A72', '#FFE9C9'], ['#D8E6C8', '#A8CBA0', '#456B52', '#FFFBE0'],
  ];
  const cadre = (k) => { const [a, b, c, s] = TONS[k % TONS.length];
    return `radial-gradient(circle at ${24 + (k * 19) % 52}% ${26 + (k * 7) % 18}%, ${s} 0 9%, transparent 10%), linear-gradient(${k % 2 ? 172 : 188}deg, transparent 63%, ${c} 63.5%), linear-gradient(180deg, ${a}, ${b})`; };
  const photos = TONS.map((_, k) => ({ n: k + 1, bg: cadre(k) }));

  /* ---------- typographies (F12) et paires de couleurs (F13) ; seules les teintes de « Papier » sont celles de l'app ---------- */
  const polices = [
    { n: 'Serif', css: "Georgia, 'Times New Roman', serif; font-style: italic" },
    { n: 'Arrondie', css: "'Trebuchet MS', ui-rounded, 'Arial Rounded MT Bold', sans-serif; font-weight: 650" },
    { n: 'Standard', css: 'Inter, system-ui, sans-serif; font-weight: 550' },
    { n: 'Mono', css: "ui-monospace, 'SFMono-Regular', Consolas, monospace" },
  ];
  const palettes = [
    { n: 'Papier', bg: '#F6F0E6', ink: '#2B2622' }, { n: 'Nuit', bg: '#1C2437', ink: '#F1ECE2' }, { n: 'Corail', bg: '#F7A58C', ink: '#3A1A12' },
    { n: 'Océan', bg: '#21628F', ink: '#EAF4FB' }, { n: 'Forêt', bg: '#2E5A45', ink: '#EDF5E8' }, { n: 'Rose', bg: '#F4C5D2', ink: '#4B1F33' },
    { n: 'Sable', bg: '#E7D5B3', ink: '#3A2D19' }, { n: 'Lilas', bg: '#DAD2F3', ink: '#2C2452' },
  ];
  const lum = (hex) => { const n = parseInt(hex.slice(1), 16), f = (v) => { v /= 255; return v <= .03928 ? v / 12.92 : Math.pow((v + .055) / 1.055, 2.4); };
    return .2126 * f(n >> 16) + .7152 * f((n >> 8) & 255) + .0722 * f(n & 255); };

  /* ---------- le dessin d'un widget (bord à bord) ---------- */
  const RATIO = { Petit: [1, 1], Moyen: [2.14, 1], Grand: [1, 1.05] };                      // largeur : hauteur d'un widget iOS
  const dims = (taille, w) => ({ w, h: Math.round(w * RATIO[taille][1] / RATIO[taille][0]) });
  const cases = (n, taille) => { const g = taille === 'Grand';                              // mise en page automatique (F7)
    if (n <= 1) return [[0, 0, 1, 1]];
    if (n === 2) return g ? [[0, 0, 1, .5], [0, .5, 1, .5]] : [[0, 0, .5, 1], [.5, 0, .5, 1]];
    if (n === 3) return g ? [[0, 0, 1, .5], [0, .5, .5, .5], [.5, .5, .5, .5]] : [[0, 0, .5, 1], [.5, 0, .5, .5], [.5, .5, .5, .5]];
    return [[0, 0, .5, .5], [.5, 0, .5, .5], [0, .5, .5, .5], [.5, .5, .5, .5]]; };
  /* w = { type: 'photos' | 'citation', taille, p: [numéros de cadres], vis: [positions montrées], q: { texte, auteur, font, pal, fond, voile, centre, guil } } ; o.w = largeur en px */
  const widget = (w, o = {}) => { const d = dims(w.taille, o.w || 150), r = Math.round(Math.min(d.w, d.h) * .17);
    const aria = w.type === 'photos' ? `Widget photos ${w.taille}, ${w.vis.length} photo${w.vis.length > 1 ? 's' : ''} montrée${w.vis.length > 1 ? 's' : ''}` : `Widget citation ${w.taille}`;
    let inner = '';
    if (w.type === 'photos') {
      inner = cases(w.vis.length, w.taille).map(([x, y, cw, ch], k) => `<i class="pho-c" style="left:${x * 100}%;top:${y * 100}%;width:${cw * 100}%;height:${ch * 100}%;background:${photos[w.p[w.vis[k]]].bg}"></i>`).join('');
    } else {
      const q = w.q, pal = palettes.find((p) => p.n === q.pal) || palettes[0], f = polices.find((p) => p.n === (q.font || 'Serif')) || polices[0];
      const vide = !q.texte, len = (q.texte || 'Ta citation ici').length, onPhoto = q.fond != null;
      const fs = Math.round(Math.min(d.w, d.h * 1.3) * (len < 36 ? .105 : len < 64 ? .088 : .076));
      const ink = onPhoto ? (lum(pal.ink) >= .6 ? pal.ink : '#FFFFFF') : pal.ink;
      const t = vide ? 'Ta citation ici' : (q.guil === false ? q.texte : '« ' + q.texte + ' »');
      inner = (onPhoto ? `<i class="pho-c" style="inset:0;left:0;top:0;width:100%;height:100%;background:${photos[q.fond].bg};box-shadow:none"></i><i class="pho-veil" style="background:linear-gradient(180deg,rgba(0,0,0,${((q.voile || .4) * .6).toFixed(2)}),rgba(0,0,0,${(q.voile || .4).toFixed(2)}))"></i>` : '')
        + `<div class="pho-q${q.centre === false ? ' left' : ''}${onPhoto ? ' on-photo' : ''}" style="color:${ink};font-family:${f.css}"><p class="${vide ? 'ph' : ''}" style="font-size:${fs}px">${t}</p>${q.auteur ? `<small style="font-size:${Math.round(fs * .72)}px">— ${q.auteur}</small>` : ''}</div>`;
      return `<div class="pho-w" role="img" aria-label="${aria}" style="width:${d.w}px;height:${d.h}px;border-radius:${r}px;background:${onPhoto ? '#222' : pal.bg}">${inner}</div>`;
    }
    return `<div class="pho-w" role="img" aria-label="${aria}" style="width:${d.w}px;height:${d.h}px;border-radius:${r}px">${inner}</div>`; };

  /* ---------- textes neutres inventés pour « Mes textes » (jamais de texte protégé ni religieux) ---------- */
  const lignes = [
    'Commence par le plus petit pas.', 'Une chose à la fois, et bien faite.', 'Respire, puis recommence.', 'Ce qui compte se fait souvent en silence.',
    'Regarde autour de toi avant de choisir.', 'La patience est une façon d\'avancer.', 'Fais simple, fais clair.', 'Un bon repos fait partie du travail.',
    'Aujourd\'hui, juste ce qui est utile.', 'Les petites habitudes tiennent les grands projets.', 'Écoute d\'abord, parle ensuite.',
    'Une petite chose bien faite vaut mieux qu\'une grande chose reportée.', 'Garde un peu de place pour la surprise.', 'Demain commence ce soir, par un bon sommeil.',
  ];
  const debut = dt(2026, 11, 1);                                                            // un dimanche ; le 12 novembre est donc le jour 12
  const jourN = nj(debut, AUJ) + 1;                                                         // 12
  const total = 365;

  /* ---------- les trois widgets de la page (F3) : tri du plus récemment utilisé au plus ancien ---------- */
  const citationFinale = { texte: lignes[jourN - 1], auteur: '', font: 'Serif', pal: 'Nuit', fond: 0, voile: .4, centre: true, guil: true };
  const widgets = [
    { id: 'w1', nom: 'Mes textes', type: 'citation', taille: 'Moyen', jour: true, q: citationFinale },
    { id: 'w2', nom: 'Mes photos', type: 'photos', taille: 'Petit', p: [0, 1, 3, 5], vis: [0, 1, 2, 3] },
    { id: 'w3', nom: 'Balades', type: 'photos', taille: 'Petit', p: [4, 6, 7, 8, 9, 10, 11], vis: [2, 3, 4, 5] },     // 7 photos, 4 visibles à la fois (F8)
  ];
  const tuileType = (w) => (w.type === 'photos' ? 'Photos' : 'Citation');
  const UI = {
    widget,
    // tuile de la grille « Mes widgets » (F3) : aperçu, nom, « Photos · Petit », bouton « … »
    tuile: (w, o = {}) => `<div class="pho-t"><div class="pho-tv">${widget(w, { w: o.w })}</div><div class="pho-tl"><div class="tx"><b>${w.nom}</b><span>${tuileType(w)} · ${w.taille}${w.jour && o.jour !== false ? ' · Un par jour' : ''}</span></div><span class="pho-mo" role="button" aria-label="Actions de « ${w.nom} »"><i data-i="dots"></i></span></div></div>`,
    // bloc « Un par jour » (NOUVEAU) : ordre, changement à minuit, indicateur
    jour: (o) => `<div>${PL.seg(['Dans l\'ordre', 'Au hasard'], o.ordre || 0)}</div>` + PL.kvs([PL.kv('Change à minuit', o.demain), PL.kv('Aujourd\'hui', o.auj)], { st: 'margin-top:8px' }),
  };

  const N = {
    jour: { date: 'Jeudi 12 novembre 2026', heure: '13:20' }, AUJ, nj, photos, palettes, polices, widgets, lignes, debut, jourN, total, citationFinale,
    /* l'état d'une citation en cours de création, avant puis après le choix de ses couleurs et de sa photo de fond */
    nouvelle: { taille: 'Petit', type: 'citation', q: { texte: '', auteur: '', font: 'Serif', pal: 'Papier', centre: true, guil: true } },
    txt: {
      confidentialite: 'Seules les photos que tu choisis sont copiées dans Ardane : aucun accès à ta photothèque n\'est demandé.',                       // bandeau actuel (audit section 3) et aide de l'éditeur (PQA:307)
      rotation: 'Plus de 4 photos : le widget en montre 4 à la fois, puis les suivantes chaque heure.',                                                  // F8, tel quel (audit section 4)
      pose: 'Pour le poser : touche longuement l\'écran d\'accueil, puis + › Ardane › « Mes widgets », et choisis-le avec « Modifier le widget ».',      // F21, tel quel (audit section 3)
      vide: 'Une à douze photos, ou une citation : ton premier widget se crée en quelques touchers.',                                                     // texte actuel corrigé (audit section 8, points 3 et 4) : à confirmer
    },
    /* ----- CE QUI N'EXISTE PAS dans l'app : à étiqueter « Nouveau » (jeton, légende, case de texte). Jamais ailleurs. ----- */
    nouveau: {
      /* demande du PDG : importer SES textes (jamais nommés ni classés par l'app : « Mes textes », « Un texte par jour ») */
      recueil: { titre: 'Mes textes', lignes, total, nom: 'Mon recueil', paragraphes: 365 },
      /* demande du PDG : « Un par jour », pour des textes comme pour une série de photos ; l'app d'aujourd'hui ne change de photos que chaque heure (F8) */
      parJour: { titre: 'Un par jour', texte: { n: jourN, total, demain: 'texte ' + (jourN + 1) }, photos: { serie: 7, index: (jourN - 1) % 7, demain: 'photo ' + (((jourN - 1) % 7) + 2) } },
    },
  };

  /* ----- contrôle : calculs justes, aucune valeur inconnue devenue zéro ----- */
  N.verifier = function () { const err = [], ok = (c, m) => { if (!c) err.push(m); };
    ok(FONCTIONS.length === 27 && FONCTIONS.every((f, i) => f[0] === 'F' + (i + 1)), 'FONCTIONS : 27 fonctions attendues, F1 à F27 dans l\'ordre');
    ok(FONCTIONS.every((f) => f[2] === 'G'), 'FONCTIONS : aucune fonction Premium (audit section 4)');
    ok(new Date(debut).getUTCDay() === 0 && AUJ.getUTCDay() === 4 && jourN === 12, 'Le 1er novembre 2026 est un dimanche ; le jeudi 12 novembre est le jour 12');
    ok(lignes[jourN - 1].startsWith('Une petite chose bien faite') && lignes.length >= 14, 'Le texte du jour 12 est le 12e ; au moins 14 textes d\'exemple');
    ok(palettes.length === 8 && polices.length === 4 && photos.length === 12, '8 paires de couleurs, 4 typographies, 12 cadres');
    ok(widgets.length === 3 && widgets[2].p.length === 7 && widgets[2].vis.length === 4, 'Trois widgets ; Balades : 7 photos, 4 montrées');
    ok(N.nouveau.parJour.photos.index === 4 && N.nouveau.parJour.photos.demain === 'photo 6', 'Série de 7 photos : le jour 12 montre la photo 5 sur 7, demain la 6');
    ok(lum('#F1ECE2') >= .6 && lum('#2B2622') < .6, 'Texte clair sur photo : la couleur choisie ; sinon blanc');
    err.forEach((m) => console.error('photos.js : ' + m));
    return err; };
  N.ui = UI;
  return N;
})();
PHO.verifier();
