/* creation.js : outils communs aux planches 20 à 26 (parcours de création de widgets).
   À charger APRÈS cristal.js et AVANT le script de la planche ; appeler Cristal.init() en dernier.
   Tout ce qui est produit ici vient de vrais exports de l'app (dossier KIT de cristal.js). */

/* icônes en plus : n'écrase jamais une icône de cristal.js */
for (const [k, v] of Object.entries({
  swap: 'M7 4v16M3 8l4-4 4 4M17 20V4M13 16l4 4 4-4',
  wand: 'M5 19L16 8M14 6l4 4M18 3v3M21 6h-3M6 4v2M7 5H5',
  lockscreen: 'M7 3h10a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2zM9.5 13h5v4h-5zM10.5 13v-1.5a1.5 1.5 0 0 1 3 0V13',
  rows: 'M4 5h16v6H4zM4 14h7v5H4zM13 14h7v5h-7z', cols: 'M4 5h7v14H4zM13 5h7v14h-7z', quad: 'M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z', one: 'M4 5h16v14H4z',
  back: 'M15 5l-7 7 7 7', more: 'M5 12h.01M12 12h.01M19 12h.01',
})) if (!P[k]) P[k] = v;

const CR = {
  // Noms français (ceux de l'app) des widgets dont un export existe.
  NAMES: { calories: 'Calories restantes', quickFood: 'Ajout rapide', macros: 'Macros', nextSet: 'Prochaine série', restTimer: 'Repos', trainingStreak: 'Régularité', todaysWorkout: 'Séance du jour', weeklyVolume: 'Volume de la semaine',
    budgetLeft: 'Reste du mois', savingsGoal: 'Objectif d\'épargne', quickExpense: 'Dépense rapide', spendingByCategory: 'Dépenses par catégorie', moneyDashboard: 'Tableau argent',
    tasks: 'Tâches', priorities: 'Top 3 du jour', counter: 'Compteur', habits: 'Habitudes', habitStreak: 'Série', upNext: 'À venir', weekView: 'Ma semaine', timetable: 'Horaire', yearDots: 'L\'année en points', clock: 'Horloge' },
  name: (p) => CR.NAMES[String(p).split('-')[0]] || p,
  ico: (n) => `<i data-i="${n}"></i>`,

  /* Widget combiné, monté comme le fait l'app (ComboLayout) : une ligne = 1 widget moyen ou 2 petits ; 1 ligne = Moyen, 2 lignes = Grand.
     parts : 'nextSet-s', 'todaysWorkout-m', null (emplacement vide, petit), '+m' (emplacement vide, ligne entière).
     o.w largeur en px (300) · o.st style de l'export ('light') · o.sel index choisi · o.num pastilles 1, 2, 3… · o.dim [index estompés] · o.lock [index Premium]
     o.x [index avec croix de retrait] · o.dark approximation du style Sombre
     o.hue rotation de teinte en degrés pour montrer une autre couleur principale (0 = vert d'origine, 58 = bleu, 110 = violet, -133 = ambre, -160 = corail) · o.cls classes en plus · o.add texte des emplacements vides ('Ajouter') */
  combo(parts, o = {}) {
    const st = o.st || 'light', rows = []; let wait = null;
    parts.forEach((p, k) => { const wide = p === '+m' || (p && /-m$/.test(p));
      if (wide) rows.push([[p, k]]); else if (wait != null) { rows[wait].push([p, k]); wait = null; } else { rows.push([[p, k]]); wait = rows.length - 1; } });
    if (wait != null && !o.single) rows[wait].push(['', -1]);
    const cell = ([p, k]) => { const cl = [], in_ = [];
      if (p === null || p === '+m' || p === '') { cl.push('empty'); in_.push(`<b>${CR.ico('plus')}${o.add === '' ? '' : (o.add || 'Ajouter')}</b>`); }
      else in_.push(`<img data-w="${p}-${st}" alt="">`);
      if (o.sel === k) cl.push('sel'); if ((o.dim || []).includes(k)) cl.push('dim');
      if (o.num && p && p !== '+m') in_.push(`<span class="n">${k + 1}</span>`);
      if ((o.x || []).includes(k)) in_.push(`<span class="x">${CR.ico('x')}</span>`);
      if ((o.lock || []).includes(k)) in_.push(`<span class="lk">${CR.ico('lock')}</span>`);
      return `<div class="ce ${cl.join(' ')}">${in_.join('')}</div>`; };
    const fmt = o.fmt || (rows.length > 1 ? 'l' : 'm');
    const fx = o.dark ? `;filter:invert(1) hue-rotate(${180 + (o.hue || 0)}deg) saturate(1.15)` : o.hue ? `;filter:hue-rotate(${o.hue}deg)` : '';
    return `<div class="cr-cw ${fmt} ${o.cls || ''}" style="--w:${o.w || 300}px${fx}">${rows.map((r) => `<div class="rw">${r.map(cell).join('')}</div>`).join('')}</div>`; },

  /* Un seul widget (vrai export) : CR.w('calories-s-light', 150). */
  w: (name, w = 150, style = '') => `<img data-w="${name}" style="width:${w}px;border-radius:${/-s-/.test(name) ? '22%' : /-l-/.test(name) ? '6.6%' : '6.6%/14.2%'};display:block;box-shadow:0 2px 4px rgb(var(--sh) / .08),0 14px 30px rgb(var(--sh) / .20);${style}" alt="">`,

  /* Tuile de choix d'un widget (grille). o.on choisi · o.n numéro d'ordre affiché dans la pastille · o.lock Premium · o.off estompé · o.sub petite ligne · o.hand interactif */
  tile(name, o = {}) { const wide = /-m-/.test(name);
    return `<div class="cr-tile${o.on ? ' on' : ''}${o.off ? ' off' : ''}${wide ? ' w' : ''}"><img data-w="${name}" alt=""><span class="ck">${o.on ? (o.n || CR.ico('check')) : ''}</span>
      <div class="lb"><span>${o.t || CR.name(name)}</span>${o.hand ? CR.ico('hand') : ''}${o.lock ? CR.ico('lock') : ''}</div>${o.sub ? `<small>${o.sub}</small>` : ''}</div>`; },

  /* Écran d'accueil d'iPhone (à mettre dans <div class="phone cr-hs" data-tab="none">, à la place de .scr).
     o.widget : HTML du widget (CR.combo(..., {w:338}) ou <img data-w>) · o.fmt 's' | 'm' | 'l' · o.wall fond ('pastel') · o.icons jeu d'icônes ('creme')
     o.rows nombre de rangées d'icônes sous le widget (1) · o.label nom sous le widget ('Ardane') · o.ring anneau autour du widget · o.extra HTML en plus (annotations)
     o.second : HTML d'un 2e widget petit posé à côté des icônes (facultatif) */
  home(o = {}) { const set = o.icons || 'creme', lab = ['Photos', 'Appareil photo', 'Plans', 'Météo', 'Téléphone', 'Messages', 'Safari', 'Musique'];
    const app = (k) => `<div class="cr-app"><img src="${KIT}icons-${set}-${k}.png" alt=""><span>${lab[k]}</span></div>`;
    const fmt = o.fmt || 's', wd = `<div class="cr-wd ${fmt}${o.ring ? ' ring' : ''}">${o.widget || ''}<span>${o.label || 'Ardane'}</span></div>`;
    let grid = wd;
    if (fmt === 's') grid += app(0) + app(1) + app(2) + app(3);
    else for (let r = 0; r < (o.rows ?? 1); r++) grid += [0, 1, 2, 3].map(app).join('');
    return `<div class="cr-wall" style="background-image:url('${KIT}wall-${o.wall || 'pastel'}.png')"></div><div class="cr-grid">${grid}</div>
      <span class="cr-search">${CR.ico('search')}Rechercher</span>
      <div class="cr-dock">${[4, 5, 6, 7].map((k) => `<img src="${KIT}icons-${set}-${k}.png" alt="">`).join('')}</div>${o.extra || ''}`; },

  /* Écran verrouillé : o.widgets = ['lock-caloriesLeft-circular', 'lock-nextSet-rect'] (vrais exports), fond de nuit. */
  lock(o = {}) { return `<div class="cr-wall" style="background:linear-gradient(160deg,#1F2A44,#3B2F5C)"></div><div class="cr-lock"><div class="dt">jeudi 12 novembre</div><div class="hr">${o.time || '13:20'}</div>
      <div class="wr">${(o.widgets || []).map((w) => `<img data-w="${w}" alt="">`).join('')}</div></div>${o.extra || ''}`; },

  /* Annotations, en absolu dans .phone (coordonnées en px depuis le coin haut gauche du téléphone, 393 × 852). */
  pin: (n, x, y) => `<span class="cr-pin" style="left:${x}px;top:${y}px">${n}</span>`,
  tip: (n, text, x, y, o = {}) => `<span class="cr-tip${n ? '' : ' nob'}" style="left:${x}px;top:${y}px${o.w ? `;max-width:${o.w}px` : ''}">${n ? `<b>${n}</b>` : ''}<span>${text}</span></span>`,
  tap: (x, y) => `<span class="cr-tap" style="left:${x}px;top:${y}px"></span>`,
  /* Flèche courbe d'un point à un autre (geste de glisser, déplacement). o.bend courbure (40) · o.dash pointillés · o.pri couleur d'action */
  arrow(x1, y1, x2, y2, o = {}) { const mx = (x1 + x2) / 2, my = (y1 + y2) / 2, dx = x2 - x1, dy = y2 - y1, len = Math.hypot(dx, dy) || 1, b = o.bend ?? 40;
    const cx = mx - dy / len * b, cy = my + dx / len * b, a = Math.atan2(y2 - cy, x2 - cx), h = 9;
    const p = (ang) => `${(x2 - h * Math.cos(a + ang)).toFixed(1)} ${(y2 - h * Math.sin(a + ang)).toFixed(1)}`;
    const cl = (o.dash ? 'd ' : '') + (o.pri ? 'p' : '');
    return `<svg class="cr-svg" width="393" height="852" viewBox="0 0 393 852"><path class="${cl}" d="M${x1} ${y1} Q${cx.toFixed(1)} ${cy.toFixed(1)} ${x2} ${y2}"/><path class="${o.pri ? 'p' : ''}" d="M${p(0.5)} L${x2} ${y2} L${p(-0.5)}"/></svg>`; },
  /* Pièce soulevée par le doigt (réordonner) : CR.lift('nextSet-s-light', x, y, largeur). */
  lift: (name, x, y, w = 120) => `<div class="cr-lift" style="left:${x}px;top:${y}px;width:${w}px"><img data-w="${name}" alt=""></div>`,
  steps: (n, on) => `<div class="cr-steps">${Array.from({ length: n }, (_, k) => `<span${k < on ? ' class="on"' : ''}></span>`).join('')}</div>`,

  /* Vignette de remplacement d'un widget sans export (Records, Calories brûlées…) : cadre en pointillés + icône. */
  ph(icon, t, o = {}) { return `<div class="cr-tile${o.off ? ' off' : ''}"><div class="cr-ph">${CR.ico(icon)}</div><span class="ck"></span>
      <div class="lb"><span>${t}</span>${o.hand ? CR.ico('hand') : ''}${o.lock ? CR.ico('lock') : ''}</div>${o.sub ? `<small>${o.sub}</small>` : ''}</div>`; },

  /* ----- Studio « C1 Atelier » (mêmes formes que la planche 8) ----- */
  TOOLS: [['resize', 'Taille'], ['lines', 'Contenu'], ['sparkles', 'Thème'], ['layers', 'Style'], ['palette', 'Couleurs'], ['image', 'Fond'], ['frame', 'Bordure'], ['chart', 'Graphique'], ['density', 'Densité'], ['star', 'Mes styles']],
  /* Rangée d'outils. on = index de l'outil ouvert · shift = nombre d'outils défilés vers la gauche · list = autre liste [[icône, nom], …] */
  tools: (on, shift = 0, list) => `<div class="tools" style="margin-top:10px">${(list || CR.TOOLS).map(([i, l], k) => `<div${k === on ? ' class="on"' : ''}${k === 0 && shift ? ` style="margin-left:-${shift * 72}px"` : ''}>${CR.ico(i)}${l}</div>`).join('')}</div>`,
  /* En-tête : grand titre + annuler / rétablir (o.undo actif). o.back = bouton retour rond à gauche · o.small = petit titre · o.right = HTML à droite à la place d'annuler / rétablir */
  head: (title = 'Créer', o = {}) => `<div class="cr-nv">${o.back ? `<span class="rb gl">${CR.ico('chevl')}</span>` : ''}<span class="cr-ttl${o.small ? ' sm' : ''}">${title}</span><span class="sp"></span>${o.right != null ? o.right : `<span class="rb gl ${o.undo ? 'pr' : 'off'}">${CR.ico('undo')}</span><span class="rb gl off">${CR.ico('redo')}</span>`}</div>`,
  /* Scène d'aperçu. inner = HTML du widget (CR.w, CR.combo) · o.h hauteur (218) · o.left / o.right = pastilles du bas (par défaut « Changer de widget » et l'œil ; '' pour aucune) · o.lab étiquette en haut à gauche · o.mt décalage vertical du widget */
  stage(inner, o = {}) { const l = o.left === undefined ? `<span class="pill gl">${CR.ico('grid')}Changer de widget</span>` : o.left, r = o.right === undefined ? `<span class="pill ic gl">${CR.ico('eye')}</span>` : o.right;
    return `<div class="stage cr-stage" style="height:${o.h || 218}px">${o.lab ? `<span class="cr-lab gl">${o.lab}</span>` : ''}<div class="cr-stin" style="margin-top:${o.mt ?? (l || r ? -44 : 0)}px">${inner}</div>${l || r ? `<div class="ctl">${l || '<span></span>'}${r || ''}</div>` : ''}</div>`; },
  /* Panneau d'outil sous la rangée : hauteur visible h (le bas s'efface, comme un défilement). */
  panel: (h, html) => `<div class="cr-wrap" style="height:${h}px"><article class="pn cr-pan">${html}</article></div>`,
  hd: (t, r) => `<div class="cr-hd"><span class="h3">${t}</span><span class="m">${r || ''}</span></div>`,
  /* Choix de taille : sel = 0 Petit, 1 Moyen, 2 Grand, -1 aucun. */
  sizes(sel) { const u = (w, h, r) => `<u style="width:${w}px;height:${h}px${r ? `;border-radius:${r}px` : ''}"></u>`;
    return `<div class="cr-sizes"><div${sel === 0 ? ' class="on"' : ''}>${u(44, 44)}<b>Petit</b></div><div${sel === 1 ? ' class="on"' : ''}>${u(72, 34)}<b>Moyen</b></div><div${sel === 2 ? ' class="on"' : ''}>${u(60, 60)}<b>Grand</b></div></div>`; },
  lockSizes(sel) { const u = (w, h, r) => `<u style="width:${w}px;height:${h}px;border-radius:${r}px"></u>`;
    return `<div class="x-lab" style="margin-top:14px">Écran verrouillé</div><div class="cr-sizes" style="margin-top:8px"><div${sel === 0 ? ' class="on"' : ''}>${u(44, 44, 22)}<b>Rond</b></div><div${sel === 1 ? ' class="on"' : ''}>${u(66, 30, 9)}<b>Rectangle</b></div><div${sel === 2 ? ' class="on"' : ''}>${u(66, 18, 9)}<b>En ligne</b></div></div>`; },
  /* Ligne d'une partie du widget : vignette + nom + actions à droite (HTML, ex. <span class="act">Remplacer</span><span class="act ic"><i data-i="x"></i></span>). o.n numéro · o.grip poignée · o.sub petite ligne */
  part: (name, o = {}) => `<div class="cr-part">${o.grip ? `<span class="gr">${CR.ico('grip')}</span>` : ''}<img data-w="${name}" alt=""><span class="tx"><b>${o.t || CR.name(name)}</b>${o.sub ? `<span class="s">${o.sub}</span>` : ''}</span>${o.right || ''}${o.n ? `<span class="nn">${o.n}</span>` : ''}</div>`,
  /* Schéma d'une disposition : rows = [['1','2'], ['3']] (une case par widget). o.on choisi · o.t légende */
  layout(rows, o = {}) { return `<div class="cr-lay${o.on ? ' on' : ''}"><div class="sc ${rows.length > 1 ? 'l' : 'm'}">${rows.map((r) => `<div>${r.map((c) => `<span>${c}</span>`).join('')}</div>`).join('')}</div>${o.t ? `<b>${o.t}</b>` : ''}</div>`; },
  dot: (hex, on) => `<u style="background:#${hex}" class="${on ? 'on' : ''}">${on ? CR.ico('check') : ''}</u>`,
  toggle: (t, on) => `<div class="cr-row"><span>${t}</span><span class="cr-tg${on ? ' on' : ''}"></span></div>`,
};
