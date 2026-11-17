/* planches.js : boîte à outils commune des planches « Refonte UX/UI des mini-apps » (2026-11-17).
   À charger après ../../2026-11-15-cristal/cristal.js (jamais modifié) et avant le JS du sujet et le script de la planche.
   La planche appelle PL.init() en dernier : PL.init numérote les écrans, écrit les étiquettes, appelle Cristal.init(), puis contrôle (?check).
   Mode d'emploi complet : GUIDE-PLANCHES.md. Sommaire de l'objet PL :
     couleurs   PL.APPS (les 9 sujets), clés data-c ajoutées : etu, ent, voy, aut, pho (nut, fit, pla, hab existent dans cristal.js)
     texte      PL.n, PL.m, PL.pct, PL.u, PL.dur
     écran      PL.mount, PL.nv, PL.rbtn, PL.ttl, PL.wsel, PL.day, PL.month, PL.hero, PL.sect, PL.card, PL.list, PL.row, PL.kpi, PL.kpis,
                PL.strip, PL.meter, PL.ring, PL.prog, PL.bar, PL.due, PL.alert, PL.toFill, PL.lockCard, PL.prem, PL.lock, PL.nw, PL.btn,
                PL.fab, PL.fab2, PL.dock, PL.sheet, PL.field, PL.kv, PL.kvs, PL.sw, PL.stepper, PL.chips, PL.seg, PL.search, PL.quick, PL.empty,
                PL.foot, PL.settings
     graphiques PL.line, PL.bars, PL.weekBars, PL.donut, PL.stack, PL.heat, PL.cal, PL.leg
     planche    PL.app, PL.take, PL.mapTable (« Rien n'est retiré »), PL.grid (notes), PL.cards (avantages / inconvénients),
                PL.fnTable, PL.shot et PL.ribbon (analyse), PL.init, PL.lint */

if (typeof Cristal === 'undefined' || typeof THEMES === 'undefined') throw new Error('planches.js se charge après ../../2026-11-15-cristal/cristal.js');

/* ================= 1. couleurs d'accent des mini-apps =================
   cristal.js connaît nut, fit, pla, hab (et bud, pro, pas). Il manque Études, Entreprise, Voyage, Auto, Photos.
   Même règle que cristal.js (fonction tokens) et que l'app (CristalPalette.categoryHex) : une base, mêlée à la couleur principale
   de la déclinaison, assombrie jusqu'à 3,2:1 sur le panneau (--c-xxx : icônes, graphiques, nappe) puis jusqu'à 4,6:1 sur blanc
   (--cs-xxx : couleur d'action de la page, texte blanc lisible).
   Aucune teinte nouvelle quand la palette Cristal en a déjà une (toutes ses références sont à 68 % de saturation) :
     etu  = rdv      #DD4DA1  le magenta « rendez-vous » de Cristal, à 4° de teinte du HEX du modèle d'Études (D6409F)
     ent  = travail  #926FE4  le violet « travail » de Cristal, à 2° du HEX du modèle de Business (8C6CFF, saturé à 100 % : trop vif tel quel)
     voy  = pas      #1E929F  (12A4B5 : même HEX que Pas dans le modèle)
     aut  = pro      #79849A  (6B7280 : même HEX que Top 3 dans le modèle)
     pho             #D9608B  le HEX du modèle de Photos et citations, tel quel : aucune référence proche, et il est déjà doux (saturation 61 %)
   Les HEX des modèles ne changent pas (les widgets les lisent) : seule la traduction à l'écran est proposée ici (à valider, voir GUIDE-PLANCHES.md § 6). */
const PL_BASES = { etu: CATS0.rdv, ent: CATS0.travail, voy: CATS0.pas, aut: CATS0.pro, pho: '#D9608B' };
(function () {
  const keys = Object.keys(PL_BASES);
  const light = THEMES.map((t) => { const panel = t.panel || '#FFFFFF', gray = C.mix(t.ink2, '#FFFFFF', .15);
    return `.t-${t.id}{` + keys.map((k) => { let c = C.mix(PL_BASES[k], t.primary, t.cat || 0); if (t.gray) c = C.mix(c, gray, t.gray); c = C.fit(c, panel, 3.2);
      return `--c-${k}:${c};--cs-${k}:${C.fit(c, '#FFFFFF', 4.6)};`; }).join('') + '}'; }).join('\n');
  const dark = THEMES.map((t) => { const card = tokensDark(t).card;
    return `.dk.t-${t.id}{` + keys.map((k) => { let c = C.mix(PL_BASES[k], t.primary, t.cat || 0); if (t.gray) c = C.mix(c, '#9AA3B0', t.gray); c = C.lift(C.mix(c, '#FFFFFF', .16), card, 5.0);
      return `--c-${k}:${c};--cs-${k}:${c};`; }).join('') + '}'; }).join('\n');
  const sel = keys.map((k) => `[data-c="${k}"]{--c:var(--c-${k});--cs:var(--cs-${k}, var(--c-${k}))}`).join('');
  document.head.insertAdjacentHTML('beforeend', `<style id="pl-themes">${light}\n${dark}\n${sel}</style>`);
})();

/* ================= 2. icônes ajoutées à P (au trait, 24 × 24). Catalogue visible : CATALOGUE.html ================= */
Object.assign(P, {
  // reprises de finance.js et de la planche Cristal 03-nutrition
  wave: 'M8.5 9.5a4 4 0 0 1 0 5M12 7a7.5 7.5 0 0 1 0 10M15.5 4.5a11 11 0 0 1 0 15',
  plusc: 'M12 3.5a8.5 8.5 0 1 0 0 17 8.5 8.5 0 0 0 0-17zM12 8v8M8 12h8',
  bus: 'M6 4h12a2 2 0 0 1 2 2v10H4V6a2 2 0 0 1 2-2zM4 11h16M7 19v-3M17 19v-3M7.5 14h.01M16.5 14h.01',
  ticket: 'M4 7h16v3a2 2 0 0 0 0 4v3H4v-3a2 2 0 0 0 0-4zM14 7v10',
  alert: 'M12 4l9 16H3zM12 10v4M12 17h.01',
  inArrow: 'M17 7L7 17M7 9v8h8', outArrow: 'M7 17L17 7M9 7h8v8',
  bank: 'M3 9l9-5 9 5M5 10v8M9.5 10v8M14.5 10v8M19 10v8M3 20h18',
  shield: 'M12 3l8 3v6c0 4.5-3.5 7.5-8 9-4.5-1.5-8-4.5-8-9V6z', wifi: 'M2.5 9a14 14 0 0 1 19 0M5.5 12.5a9.5 9.5 0 0 1 13 0M8.8 16a4.5 4.5 0 0 1 6.4 0M12 19.5h.01',
  music: 'M9 18V5l11-2v13M9 18a3 3 0 1 1-6 0 3 3 0 0 1 6 0zM20 16a3 3 0 1 1-6 0 3 3 0 0 1 6 0z', tv: 'M3 6h18v12H3zM8 21h8M10 3l2 3 2-3',
  sliders: 'M4 7h10M18 7h2M4 17h4M12 17h8M14 5v4M8 15v4', calcheck: 'M4 6h16v14H4zM4 10h16M8 3v4M16 3v4M9 15l2 2 4-4',
  pill: 'M10.5 20.5l10-10a5 5 0 0 0-7-7l-10 10a5 5 0 0 0 7 7zM8.5 8.5l7 7',
  coffee: 'M5 8h12v6a5 5 0 0 1-5 5h-2a5 5 0 0 1-5-5zM17 10h1.5a2.5 2.5 0 0 1 0 5H17M8 3v2M12 3v2', cart: 'M3 4h2l2.5 11h11L21 7H6.2M9 20h.01M17 20h.01',
  bulb: 'M9 18h6M10 21h4M12 3a6 6 0 0 0-3.5 10.9c.6.5 1 1.2 1 2.1h5c0-.9.4-1.6 1-2.1A6 6 0 0 0 12 3z',
  swipe: 'M4 12h12M12 8l4 4-4 4M20 5v14', keypad: 'M6 5h.01M12 5h.01M18 5h.01M6 11h.01M12 11h.01M18 11h.01M6 17h.01M12 17h.01M18 17h.01',
  percent: 'M19 5L5 19M7.5 6a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3zM16.5 15a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3z',
  leaf: 'M5 19c0-8 5-13 14-14 0 9-5 14-13 14zM5 19l7-7', sunrise: 'M3 18h18M7 18a5 5 0 0 1 10 0M12 6v3M5.5 10l1.5 1.5M18.5 10L17 11.5',
  carrot: 'M14 6l4 4-8 10-6-6zM15 3c1 1 1 2 0 3M19 7c1 0 2 0 3 1', pie: 'M12 3a9 9 0 1 0 9 9h-9zM15 3.5A9 9 0 0 1 20.5 9H15z',
  // ajoutées pour les 9 sujets
  briefcase: 'M4 8h16v11H4zM9 8V5h6v3M4 13h16',
  quote: 'M5 17c2-1 3-3 3-5H5V7h5v5c0 3-2 5-5 5zM14 17c2-1 3-3 3-5h-3V7h5v5c0 3-2 5-5 5z',
  fuel: 'M5 20V5a1 1 0 0 1 1-1h7a1 1 0 0 1 1 1v15M4 20h11M7 8h5v4H7zM14 11h2a2 2 0 0 1 2 2v3a1.5 1.5 0 0 0 3 0V9l-3-3',
  wrench: 'M20 7a4.5 4.5 0 0 1-6.3 4.1L6 19l-2-2 7.9-7.7A4.5 4.5 0 0 1 17 4l-2.5 2.5 1 2 2 1z',
  gauge: 'M4.5 17a8.5 8.5 0 1 1 15 0M12 14l3.5-4.5M12 14h.01',
  map: 'M3 6l6-2 6 2 6-2v14l-6 2-6-2-6 2zM9 4v14M15 6v14', suitcase: 'M5 8h14v12H5zM9 8V4h6v4M9 12v4M15 12v4',
  bed: 'M3 18V7M3 14h18v4M21 14v-2a3 3 0 0 0-3-3h-7v5M7 11.5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3z',
  globe: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM3 12h18M12 3c2.5 2.5 3.5 5.5 3.5 9s-1 6.5-3.5 9c-2.5-2.5-3.5-5.5-3.5-9s1-6.5 3.5-9z',
  tag: 'M4 4h8l8 8-8 8-8-8zM8.5 8.5h.01', users: 'M9 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM2.5 20a6.5 6.5 0 0 1 13 0M16 4.5a3.5 3.5 0 0 1 0 6.5M18 14.5a6 6 0 0 1 3.5 5.5',
  dollar: 'M12 3v18M16.5 7.5c-1-1.5-2.5-2-4.5-2-2.5 0-4 1.2-4 3s1.5 2.7 4 3.2 4.5 1.3 4.5 3.3-1.8 3.3-4.5 3.3c-2.2 0-4-.8-5-2.3',
  receipt: 'M6 3h12v18l-3-2-3 2-3-2-3 2zM9 8h6M9 12h6',
  import: 'M12 3v12M8 11l4 4 4-4M5 17v3h14v-3', refresh: 'M20 11a8 8 0 0 0-14.5-4M4 4v4h4M4 13a8 8 0 0 0 14.5 4M20 20v-4h-4',
  history: 'M4 12a8 8 0 1 0 2.5-5.8M4 4v4h4M12 8v4l3 2', bookmark: 'M7 4h10v16l-5-4-5 4z', folder: 'M3 7V5h7l2 2h9v12H3z',
  note: 'M5 4h14v11l-5 5H5zM14 20v-5h5M8 9h8M8 13h4', clipboard: 'M9 4h6v3H9zM9 5H6v16h12V5h-3M9 14l2 2 4-4',
  scale: 'M5 4h14a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1zM8 9a5.5 5.5 0 0 1 8 0l-2.5 2.5h-3zM12 9.5V8',
  glass: 'M7 4h10l-1.5 16h-7zM7.5 9h9', video: 'M4 6h11v12H4zM15 10l5-3v10l-5-3',
  link: 'M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1',
  images: 'M7 7h13v11H7zM4 15V4h13M7 15l3.5-3.5 3 3 2.5-2.5 4 4', sort: 'M7 4v16M4 7l3-3 3 3M17 20V4M14 17l3 3 3-3',
  stop: 'M7 7h10v10H7z', skip: 'M6 5l9 7-9 7zM18 5v14', mic: 'M12 3a3 3 0 0 0-3 3v5a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3zM6 11a6 6 0 0 0 12 0M12 17v4',
});

/* ================= 3. l'objet PL ================= */
const NBSP = ' ';
const PL = {
  /* les 9 sujets de la mission (clé data-c, nom affiché, icône, HEX du modèle). « app » = libellé de l'app s'il diffère du nom du sujet. */
  APPS: {
    nut: { nom: 'Nutrition', i: 'fork', hex: 'F08A24' },
    fit: { nom: 'Fitness', i: 'dumbbell', hex: 'E5484D' },
    pla: { nom: 'Planning', i: 'calendar', hex: '3366FF' },
    hab: { nom: 'Habitudes', i: 'repeat', hex: '7FA33A' },
    etu: { nom: 'Études', i: 'graduation', hex: 'D6409F' },
    ent: { nom: 'Entreprise', app: 'Business', i: 'briefcase', hex: '8C6CFF' },
    voy: { nom: 'Voyage', i: 'plane', hex: '12A4B5' },
    aut: { nom: 'Auto', i: 'car', hex: '6B7280' },
    pho: { nom: 'Photos et citations', i: 'images', hex: 'D9608B' },
  },
  /* les 10 critères de la mission (section 6), dans l'ordre et avec ses mots : les mêmes sur les 9 planches de comparaison */
  CRITERES: [
    ['Lisibilité', 'Lire sans effort'],
    ['Simplicité d\'utilisation', 'Peu de choses à comprendre'],
    ['Hiérarchie des informations', 'L\'essentiel avant le reste'],
    ['Rapidité d\'accès aux fonctionnalités', 'Nombre de touchers pour deux gestes courants'],
    ['Qualité de l\'expérience quotidienne', 'L\'usage de tous les jours'],
    ['Richesse fonctionnelle', 'Ce qu\'on peut faire et savoir'],
    ['Cohérence avec Ardane', 'Cristal, règles communes, Mon quotidien'],
    ['Qualité esthétique', 'Proche d\'un produit fini'],
    ['Facilité de compréhension pour un nouvel utilisateur', 'Dès la première ouverture'],
    ['Potentiel d\'évolution', 'De la place pour la suite'],
  ],
  /* la journée d'exemple commune (planches Cristal) : repères à ne pas contredire. Le détail est dans cristal.js (DAY, EVENTS, HABITS, TOP3, REMIND). */
  JOUR: { date: 'Jeudi 12 novembre 2026', court: 'jeu. 12 nov.', heure: '13:20', mois: 'Novembre 2026', jour: 12, jours: 30, dow0: 6, avatar: 'M' },
  /* dossier des images rendues, vu depuis une planche de docs/design/2026-11-17-mini-apps/<dossier>/ */
  pub: '../../../../pub/rapports/design-2026-11-17-mini-apps/',
  dossier: decodeURIComponent(location.pathname).replace(/\/[^/]*$/, '').split('/').pop(),

  /* ---------- texte (français du Canada) ---------- */
  n(x, dec = 0) { const s = Math.abs(x).toFixed(dec).split('.'); return (x < 0 ? '−' : '') + s[0].replace(/\B(?=(\d{3})+(?!\d))/g, NBSP) + (dec ? ',' + s[1] : ''); },
  m(x, dec) { if (dec == null) dec = Number.isInteger(Math.round(x * 100) / 100) ? 0 : 2; return PL.n(x, dec) + NBSP + '$'; },
  pct: (p) => Math.round(p * 100) + NBSP + '%',
  u: (x, unit, dec = 0) => PL.n(x, dec) + NBSP + unit,                                  // PL.u(71.6, 'kg', 1) → « 71,6 kg »
  dur: (min) => (min < 60 ? min + NBSP + 'min' : Math.floor(min / 60) + NBSP + 'h' + (min % 60 ? NBSP + String(min % 60).padStart(2, '0') : '')),
  ico: (n) => `<i data-i="${n}"></i>`,
  _c: (c) => (!c || c === 'var(--c)' ? '' : /^[a-z]{3,7}$/.test(c) ? ` data-c="${c}"` : ` style="--c:${c}"`),   // clé data-c (nut, prot…) ou couleur CSS (HEX, var(--c-fit)…)
  _cv: (c) => (!c || c === 'var(--c)' ? '' : /^[a-z]{3,7}$/.test(c) ? `var(--c-${c})` : c),                              // la même, en valeur CSS

  /* ---------- écran : cadre ---------- */
  // PL.mount('d1p1', contenu de .scr, ce qui flotte hors de .scr : action flottante, feuille)
  mount(id, html, after = '') { const el = document.getElementById(id); if (!el) throw new Error('PL.mount : pas de téléphone #' + id); el.innerHTML = `<div class="scr">${html}</div>${after}`; },
  // barre de navigation : retour rond en verre, titre centré, bouton(s) à droite. o.back = false : pas de retour ; o.back = 'x' : croix
  nv(t = '', right = '', o = {}) { const b = o.back === false ? '<span style="width:44px"></span>' : `<span class="rb gl" role="button" aria-label="Retour"><i data-i="${o.back === 'x' ? 'x' : 'chevl'}"></i></span>`;
    return `<div class="nv">${b}<span class="t">${t}</span>${right || '<span style="width:44px"></span>'}</div>`; },
  rbtn: (i, label, cls = 'gl') => `<span class="rb ${cls}" role="button" aria-label="${label}"><i data-i="${i}"></i></span>`,
  ttl: (t, sub) => `<div class="pl-ttl">${t}</div>${sub ? `<div class="x-sub">${sub}</div>` : ''}`,
  // sélecteur de semaine (WeekSelector). o.sel jour choisi (0 lundi … 6), o.marks jours repérés, o.title
  wsel: (o = {}) => U.wsel({ marks: [0, 1, 2, 3], ...o }),
  // sélecteur de jour des pages secondaires (DaySwitcher) et sélecteur de mois
  day: (t = 'Aujourd\'hui · jeu. 12 nov.', o = {}) => `<div class="gl pl-switch"><i data-i="chevl"></i><span>${t}</span><i data-i="chev" class="${o.next ? '' : 'off'}"></i></div>`,
  month: (t = 'Novembre 2026', o = {}) => `<div class="gl pl-switch"><i data-i="${o.locked ? 'lock' : 'chevl'}" class="${o.locked ? 'lk' : ''}"></i><span>${t}</span><i data-i="chev" class="${o.next ? '' : 'off'}"></i></div>`,
  // figure essentielle sur verre (MiniHero) : étiquette, grand chiffre, une ligne. o.right : lien ou bouton à droite de l'étiquette ; o.body : HTML sous la ligne
  hero(o = {}) { return `<article class="gl pl-hero${o.cls ? ' ' + o.cls : ''}"${o.st ? ` style="${o.st}"` : ''}><div class="top"><span class="pl-lab">${o.lab || ''}</span>${o.right || ''}</div>`
    + (o.fig != null ? `<div class="pl-fig${o.size ? ' ' + o.size : ''}">${o.fig}${o.unit ? `<small>${o.unit}</small>` : ''}</div>` : '') + (o.line ? `<div class="line">${o.line}</div>` : '') + (o.body || '') + '</article>'; },
  // titre de section (MiniSectionTitle) : titre, détail à droite, lien à droite. o.nw / o.prem : jeton à côté du titre
  sect: (t, d, a, o = {}) => `<div class="sect"${o.st ? ` style="${o.st}"` : ''}><b>${t}</b>${o.nw ? PL.nw() : ''}${o.prem ? PL.prem() : ''}${d ? `<span>${d}</span>` : ''}${a ? `<a>${a}</a>` : ''}</div>`,
  // carte (panneau). o.t titre, o.right détail à droite du titre, o.i icône, o.nw : carte nouvelle (contour pointillé et jeton), o.st style
  card(body, o = {}) { const head = o.t ? `<header class="ch">${o.i ? `<span class="ico"${PL._c(o.c)}><i data-i="${o.i}"></i></span>` : ''}<b>${o.t}</b>${o.nw ? PL.nw() : ''}${o.prem ? PL.prem() : ''}${o.right ? `<span class="s" style="margin-left:auto">${o.right}</span>` : ''}${o.chev ? '<i class="go" data-i="chev"></i>' : ''}</header>` : '';
    return `<article class="pn cd${o.nw ? ' pl-newbox' : ''}${o.cls ? ' ' + o.cls : ''}"${o.st ? ` style="${o.st}"` : ''}>${head}${body}</article>`; },
  // carte de lignes (MiniRowsCard) : PL.list([PL.row(…), PL.row(…)])
  list: (rows, o = {}) => `<article class="pn ls${o.nw ? ' pl-newbox' : ''}${o.cls ? ' ' + o.cls : ''}"${o.st ? ` style="${o.st}"` : ''}>${[].concat(rows).join('')}</article>`,
  /* ligne (MiniRow) : icône, titre, détail, valeur, chevron.
     x.c couleur de l'icône (clé data-c ou couleur CSS) · x.sq pastille carrée · x.r valeur à droite · x.r2 seconde ligne à droite · x.rc classe de la valeur (ok, over)
     x.chev = false : pas de chevron · x.prem badge Premium · x.lock cadenas · x.nw jeton Nouveau · x.plus rond « + » · x.chk 'ok' ou 'todo' (coche) · x.done titre barré
     i = '' : pas d'icône */
  row(i, t, s, x = {}) { const ic = x.chk ? `<i class="chk${x.chk === 'ok' ? ' ok' : ''}" data-i="${x.chk === 'ok' ? 'checkc' : 'circle'}"></i>` : i ? `<span class="ico lg${x.sq ? ' sq' : ''}"${PL._c(x.c)}><i data-i="${i}"></i></span>` : '';
    const right = x.r != null || x.r2 ? `<div class="pl-r"><b class="${x.rc || ''}">${x.r ?? ''}</b>${x.r2 ? `<span>${x.r2}</span>` : ''}</div>` : '';
    return `<div class="li${x.done ? ' done' : ''}${x.cls ? ' ' + x.cls : ''}">${ic}<div class="tx"><b>${t}${x.nw ? ' ' + PL.nw() : ''}</b>${s ? `<span class="s">${s}</span>` : ''}</div>${x.prem ? PL.prem() : ''}${right}${x.lock ? '<i class="go" data-i="lock"></i>' : ''}${x.chev === false ? '' : '<i class="go" data-i="chev"></i>'}${x.plus ? `<span class="pl-plus" role="button" aria-label="Ajouter"><u><i data-i="plus"></i></u></span>` : ''}</div>`; },
  // tuile de chiffre (MiniStat) : PL.kpis([PL.kpi('Calories', '1 078', 'sur 2 200 kcal'), …], 3)
  kpi: (h, v, s, x = {}) => `<div class="pn pl-kpi${x.nw ? ' pl-newbox' : ''}"${x.st ? ` style="${x.st}"` : ''}>${x.nw ? PL.nw('Nouveau', 'corner') : ''}<div class="h">${x.i ? `<i data-i="${x.i}" style="color:${x.ic || 'var(--c, currentColor)'}"></i>` : ''}${h}${x.prem ? '<i data-i="lock" style="margin-left:auto;font-size:12px"></i>' : ''}</div><div class="pl-num${x.sm ? ' sm' : ''}"${x.vc ? ` style="color:${x.vc}"` : ''}>${v}${x.unit ? `<small>${x.unit}</small>` : ''}</div>${s ? `<div class="s">${s}</div>` : ''}</div>`,
  kpis: (items, cols = items.length, st) => `<div class="pl-kpis k${cols}"${st ? ` style="${st}"` : ''}>${items.join('')}</div>`,
  // bande de 2 à 4 chiffres dans un seul panneau : PL.strip([['658', 'kcal'], ['44 g', 'Protéines']])
  strip: (items, o = {}) => `<article class="pn pl-strip"${o.st ? ` style="${o.st}"` : ''}>${items.map(([v, l]) => `<div><b>${v}</b><span>${l}</span></div>`).join('')}</article>`,
  // jauge libellée : PL.meter('Protéines', '68 / 140 g', .486, 'prot')
  meter: (lab, val, p, c) => `<div class="pl-meter"${PL._c(c)}><span>${lab}</span><em>${val}</em>${U.meter(p)}</div>`,
  // anneau avec texte au centre : PL.ring(.49, { s: 112, sw: 9, b: '1 122', small: 'kcal<br>restantes', c: 'nut' })
  ring(p, o = {}) { const s = o.s || 112, key = o.c && /^[a-z]{3,7}$/.test(o.c);
    return `<div class="pl-ring"${key ? ` data-c="${o.c}"` : ''} style="width:${s}px;height:${s}px${o.c && !key && o.c !== 'var(--c)' ? ';--c:' + o.c : ''}" role="img" aria-label="${o.aria || ''}">${U.ring(p, o.sw || 9)}`
    + `<div class="in">${o.b != null ? `<b style="font-size:${o.bs || Math.round(s * .23)}px">${o.b}</b>` : ''}${o.small ? `<small style="font-size:${o.ss || Math.max(10.5, Math.round(s * .1))}px">${o.small}</small>` : ''}${o.in || ''}</div></div>`; },
  // barre de progression. o.pace : repère (0 à 1) ; o.lg : épaisse ; o.c couleur
  bar: (p, o = {}) => `<div class="pl-bar${o.lg ? ' lg' : ''}"${PL._cv(o.c) ? ` style="--c:${PL._cv(o.c)}"` : ''}><i style="width:${(Math.max(0, Math.min(1, p)) * 100).toFixed(1)}%"></i>${o.pace != null ? `<u style="left:${(o.pace * 100).toFixed(1)}%"></u>` : ''}</div>`,
  // progression libellée : PL.prog({ i: 'cart', t: 'Épicerie', r: '<b>295 $</b> / 500 $', p: .59, pace: .4, sub: '…', c: '#1E9E75' })
  prog(o) { const col = o.over ? 'var(--pl-over)' : PL._cv(o.c);
    return `<div class="pl-prog"${col ? ` style="--c:${col}"` : ''}>${o.i ? `<span class="ico lg"><i data-i="${o.i}"></i></span>` : ''}<div class="tx"><div class="l"><span>${o.t}${o.nw ? ' ' + PL.nw() : ''}</span><em>${o.r || ''}</em></div>`
      + (o.p == null ? '<div class="pl-bar" style="background:none;border-top:1.5px dashed var(--rule2);height:0;margin:3px 0"></div>' : PL.bar(o.p, { pace: o.pace })) + (o.sub ? `<div class="s2">${o.sub}</div>` : '') + '</div></div>'; },
  // ligne datée : PL.due({ dow: 'lun.', d: 16, t: 'Examen : Statistiques', s: 'Dans 4 jours · 9:00', r: 'J-4', hot: true })
  due: (o) => `<div class="pl-due${o.hot ? ' hot' : ''}"><div class="d"><small>${o.dow || ''}</small><b>${o.d}</b></div><div class="tx"><b>${o.t}${o.nw ? ' ' + PL.nw() : ''}</b>${o.s ? `<span class="s">${o.s}</span>` : ''}</div>${o.r != null ? `<div class="pl-r"><b class="${o.rc || ''}">${o.r}</b>${o.r2 ? `<span>${o.r2}</span>` : ''}</div>` : ''}${o.chev ? '<i class="go" data-i="chev"></i>' : ''}</div>`,
  // bandeau dans la page : PL.alert('info', 'Titre', 'détail', { act: 'Voir', c: 'var(--pl-warn)' })
  alert: (i, t, s, o = {}) => `<div class="pl-alert pn${o.nw ? ' pl-newbox' : ''}"${o.st ? ` style="${o.st}"` : ''}><span class="ico"${PL._c(o.c)}><i data-i="${i}"></i></span><div><b>${t}${o.nw ? ' ' + PL.nw() : ''}</b>${s ? `<div class="s">${s}</div>` : ''}</div>${o.act ? `<span class="act">${o.act}</span>` : ''}</div>`,
  // « À remplir » (MiniAppToFillSection) : PL.toFill([{ i: 'flame', t: 'Objectif calorique', s: 'Pour savoir…', btn: 'Calculer mes besoins' }], '0 / 2')
  toFill: (items, count) => PL.sect('À remplir', count) + `<div class="x-stack" style="gap:10px">${items.map((x) => `<article class="pn pl-fill"><div class="hd"><span class="ico sq lg"><i data-i="${x.i}"></i></span><div style="flex:1;min-width:0"><b>${x.t}</b><span class="s">${x.s || ''}</span></div><span class="todo">À renseigner</span></div><div class="btnP">${x.bi ? `<i data-i="${x.bi}"></i>` : ''}${x.btn}</div></article>`).join('')}</div>`,
  // carte « … est dans Premium » (PremiumLockCard)
  lockCard: (t, p, btn = 'Découvrir Premium') => `<article class="pn pl-lockcard"><div class="hd"><u><i data-i="lock"></i></u><b>${t}</b></div><p>${p}</p><div class="btnP"><i data-i="crown"></i>${btn}</div></article>`,
  prem: (t = 'Premium', i = 'crown') => `<span class="prem"><i data-i="${i}"></i>${t}</span>`,
  lock: (t) => `<span class="pl-lock">${t}<i data-i="lock"></i></span>`,
  nw: (t = 'Nouveau', cls = '') => `<span class="pl-new${cls ? ' ' + cls : ''}">${t}</span>`,
  // boutons : k = 'P' plein (action principale), 'T' teinté, 'G' verre, 'O' contour ; o.lg : 52 points ; o.i icône
  btn: (t, o = {}) => `<div class="btn${o.k || 'P'}${o.lg ? ' lg' : ''}"${o.st ? ` style="${o.st}"` : ''} role="button">${o.i ? `<i data-i="${o.i}"></i>` : ''}${t}${o.ir ? `<i data-i="${o.ir}"></i>` : ''}</div>`,
  // action flottante (MiniFloatingAction), à passer en 3e argument de PL.mount
  fab: (t = 'Ajouter', i = 'plus') => `<div class="fab" role="button"><i data-i="${i}"></i>${t}</div>`,
  fab2: (a, b) => `<div class="pl-fab2"><div class="p" role="button"><i data-i="${a[1]}"></i>${a[0]}</div><div class="g" role="button"><i data-i="${b[1]}"></i>${b[0]}</div></div>`,
  // barre d'action fixe en bas d'une page sans barre d'onglets (data-tab="none"), à passer en 3e argument de PL.mount
  dock: (html) => `<div class="pl-dock">${html}</div>`,
  /* feuille, à passer en 3e argument de PL.mount (le téléphone prend data-tab="none"). t titre ;
     o.left 'x' (croix, par défaut) ou un mot (« Annuler ») ; o.right HTML à droite (PL.sheetBtn('Enregistrer')) ; o.st style ; o.full : presque plein écran */
  sheet(body, t, o = {}) { const left = o.left && o.left !== 'x' ? `<span class="rb txt" style="padding:0 4px;color:var(--ink2)" role="button">${o.left}</span>` : '<span class="rb" role="button" aria-label="Fermer"><i data-i="x"></i></span>';
    return `<div class="dim"></div><div class="sheet${o.full ? ' pl-sheet-full' : ''}"${o.st ? ` style="${o.st}"` : ''}><div class="grab"></div>${t ? `<div class="nv">${left}<span class="t">${t}</span>${o.right || '<span style="width:44px"></span>'}</div>` : ''}${body}</div>`; },
  sheetBtn: (t) => `<span class="rb txt" style="padding:0 4px" role="button">${t}</span>`,
  // champ de formulaire, paire libellé / valeur, interrupteur, pas à pas
  field: (lab, val, o = {}) => `<div class="pl-field${o.ph ? ' ph' : ''}"><span class="x-lab">${lab}</span><span>${o.i ? `<i data-i="${o.i}"></i>` : ''}${val}${o.chev ? '<i data-i="chevd" style="color:var(--go);font-size:14px"></i>' : ''}</span></div>`,
  kv: (k, v, o = {}) => `<div class="pl-kv"><span>${k}${o.nw ? ' ' + PL.nw() : ''}</span><span>${v}${o.chev ? '<i data-i="chev" style="color:var(--go);font-size:14px"></i>' : ''}</span></div>`,
  sw: (on = true) => `<span class="pl-sw${on ? ' on' : ''}" role="switch" aria-checked="${on}"></span>`,
  kvs: (rows, o = {}) => `<div class="pl-kvs"${o.st ? ` style="${o.st}"` : ''}>${[].concat(rows).join('')}</div>`,
  stepper: (v) => `<span class="pl-stepper"><u role="button" aria-label="Moins"><i data-i="minus"></i></u><b>${v}</b><u role="button" aria-label="Plus"><i data-i="plus"></i></u></span>`,
  // puces : PL.chips(['Tout', 'Dépenses'], 0) ; un élément peut être [texte, icône] ; o.wrap : sur plusieurs lignes ; o.fit : se partagent la largeur (4 au plus) ; sinon la rangée défile vers la droite
  chips: (items, on = 0, o = {}) => `<div class="${o.wrap ? 'pl-wrap' : o.fit ? 'chips fit' : 'chips'}"${o.st ? ` style="${o.st}"` : ''}>${items.map((x, k) => { const [t, i] = [].concat(x); return `<span class="chip${k === on ? ' on' : ''}">${i ? `<i data-i="${i}"></i>` : ''}${t}</span>`; }).join('')}</div>`,
  seg: (items, on = 0, o = {}) => `<div class="seg"${o.st ? ` style="${o.st}"` : ''}>${items.map((t, k) => `<span class="${k === on ? 'on' : ''}">${t}</span>`).join('')}</div>`,
  search: (ph = 'Rechercher', right = '') => `<div class="gl pl-search"><i data-i="search"></i><span style="flex:1">${ph}</span>${right}</div>`,
  // raccourcis en capsules : PL.quick([{ t: 'Café', v: '4,50 $', i: 'coffee', c: '#F06A3C' }])
  quick: (items) => `<div class="pl-quick" data-scroll>${items.map((q) => `<span><span class="ico"${PL._c(q.c)}><i data-i="${q.i}"></i></span>${q.t}${q.v ? `<em>${q.v}</em>` : ''}</span>`).join('')}</div>`,
  // état vide (cadre en pointillés, jamais de faux chiffre), note de fin d'écran, bouton « Mes paramètres »
  empty: (i, t, p, btn) => `<div class="empty"><span class="ico lg"><i data-i="${i}"></i></span><b>${t}</b><p>${p}</p>${btn ? `<div class="btnT">${btn}</div>` : ''}</div>`,
  foot: (t) => `<div class="foot">${t}</div>`,
  settings: (t = 'Mes paramètres') => `<div class="btnO" style="margin-top:10px" role="button"><i data-i="gear"></i>${t}</div>`,

  /* ---------- graphiques ---------- */
  // légende écrite d'un graphique : PL.leg([[couleur, texte, forme]]) ; forme : '' carré, 'ln' trait, 'dsh' pointillé, 'hat' hachures, 'dot' rond
  leg: (items) => `<div class="pl-leg">${items.map(([c, t, k]) => `<span><u class="${k || ''}" style="color:${PL._cv(c) || 'var(--c, var(--primary))'}"></u>${t}</span>`).join('')}</div>`,
  /* Courbes. o.series = [{ v:[…], c:couleur, w:épaisseur, dash:true, area:true, dot:true }], o.w (319 = largeur utile d'une carte), o.h, o.max, o.min,
     o.yt = [graduations], o.yf = format, o.xl = [[index, texte]], o.n = longueur de l'axe X, o.ref = { v, t } ligne horizontale (objectif),
     o.tip = { i, v, t, s, w } bulle sur un point, o.aria = phrase qui dit le graphique */
  line(o) { const W = o.w || 319, H = o.h || 120, pr = o.yt ? 44 : 4, pw = W - pr, n = o.n || Math.max(...o.series.map((s) => s.v.length)), min = o.min || 0, max = o.max || Math.max(...o.series.flatMap((s) => s.v.filter((v) => v != null))) * 1.1;
    const X = (k) => (n === 1 ? 0 : k / (n - 1) * pw), Y = (v) => H - (v - min) / (max - min) * H, yf = o.yf || ((v) => PL.n(v));
    let g = '';
    (o.yt || []).forEach((v) => { g += `<line x1="0" x2="${pw}" y1="${Y(v).toFixed(1)}" y2="${Y(v).toFixed(1)}" stroke="var(--grid)" stroke-width="1"/><text x="${pw + 6}" y="${(Y(v) + 3.5).toFixed(1)}">${yf(v)}</text>`; });
    if (o.ref) g += `<line x1="0" x2="${pw}" y1="${Y(o.ref.v).toFixed(1)}" y2="${Y(o.ref.v).toFixed(1)}" stroke="var(--ink)" stroke-width="1.4" stroke-dasharray="5 4" opacity=".55"/>${o.ref.t ? `<text class="b" x="2" y="${(Y(o.ref.v) - 5).toFixed(1)}">${o.ref.t}</text>` : ''}`;
    o.series.forEach((s) => { const pts = s.v.map((v, k) => (v == null ? null : [X(k), Y(v)])).filter(Boolean); if (!pts.length) return;
      const d = pts.map((p, k) => (k ? 'L' : 'M') + p[0].toFixed(1) + ' ' + p[1].toFixed(1)).join(' '), last = pts[pts.length - 1];
      if (s.area) g += `<path d="${d} L${last[0].toFixed(1)} ${H} L${pts[0][0].toFixed(1)} ${H} Z" fill="${s.c}" opacity="${s.ao || .12}"/>`;
      g += `<path d="${d}" fill="none" stroke="${s.c}" stroke-width="${s.w || 2.4}" stroke-linecap="round" stroke-linejoin="round"${s.dash ? ' stroke-dasharray="4 4"' : ''}/>`;
      if (s.dots) pts.forEach((p) => { g += `<circle cx="${p[0].toFixed(1)}" cy="${p[1].toFixed(1)}" r="2.6" fill="${s.c}"/>`; });
      if (s.dot) g += `<circle cx="${last[0].toFixed(1)}" cy="${last[1].toFixed(1)}" r="4.5" fill="var(--card)" stroke="${s.c}" stroke-width="2.4"/>`; });
    if (o.tip) { const x = X(o.tip.i), y = Y(o.tip.v), tw = o.tip.w || 92, tx = Math.min(Math.max(x - tw / 2, 0), pw - tw);
      g += `<line x1="${x.toFixed(1)}" x2="${x.toFixed(1)}" y1="${(y + 6).toFixed(1)}" y2="${H}" stroke="var(--ink)" stroke-width="1" opacity=".25"/>`
        + `<g transform="translate(${tx.toFixed(1)} ${(y - 40).toFixed(1)})"><rect width="${tw}" height="30" rx="9" fill="var(--ink)"/><text x="${tw / 2}" y="13" text-anchor="middle" style="fill:#fff;font-weight:700;font-size:11px">${o.tip.t}</text><text x="${tw / 2}" y="24.5" text-anchor="middle" style="fill:rgba(255,255,255,.75);font-size:9.5px">${o.tip.s || ''}</text></g>`; }
    (o.xl || []).forEach(([k, t]) => { const x = X(k); g += `<text x="${x.toFixed(1)}" y="${H + 15}" text-anchor="${k === 0 ? 'start' : k >= n - 1 ? 'end' : 'middle'}">${t}</text>`; });
    return `<div class="pl-ch" role="img" aria-label="${o.aria || ''}"><svg width="${W}" height="${H + (o.xl ? 19 : 2)}" viewBox="0 0 ${W} ${H + (o.xl ? 19 : 2)}">${g}</svg></div>`; },
  /* Barres groupées. o.g = [{ l, v:[a, b…], cur, hl, dim }], o.c = [couleurs], o.max, o.yt, o.yf, o.w, o.h, o.bw largeur d'une barre,
     groupe « cur » = période en cours : hachures (o.cur = false pour les retirer), o.vals = valeurs écrites, o.ref = { v, t } */
  bars(o) { const W = o.w || 319, H = o.h || 130, pr = o.yt ? 44 : 0, pw = W - pr, n = o.g.length, gw = pw / n, k = o.g[0].v.length, bw = Math.min(o.bw || 14, (gw - 10) / k), gap = o.bg ?? 3;
    const max = o.max || Math.max(...o.g.flatMap((x) => x.v.filter((v) => v != null))) * 1.12, Y = (v) => H - v / max * H, yf = o.yf || ((v) => PL.n(v)), id = 'plhat' + (PL._hat = (PL._hat || 0) + 1);
    let s = '', defs = '';
    (o.yt || []).forEach((v) => { s += `<line x1="0" x2="${pw}" y1="${Y(v).toFixed(1)}" y2="${Y(v).toFixed(1)}" stroke="var(--grid)"/><text x="${pw + 6}" y="${(Y(v) + 3.5).toFixed(1)}">${yf(v)}</text>`; });
    if (o.ref) s += `<line x1="0" x2="${pw}" y1="${Y(o.ref.v).toFixed(1)}" y2="${Y(o.ref.v).toFixed(1)}" stroke="var(--ink)" stroke-width="1.3" stroke-dasharray="5 4" opacity=".55"/>${o.ref.t ? `<text class="b" x="${pw}" y="${(Y(o.ref.v) - 5).toFixed(1)}" text-anchor="end">${o.ref.t}</text>` : ''}`;
    o.g.forEach((gr, gi) => { const x0 = gi * gw + (gw - (k * bw + (k - 1) * gap)) / 2;
      gr.v.forEach((v, j) => { if (v == null) return; const x = x0 + j * (bw + gap), y = Y(v), c = (gr.c || o.c || ['var(--c, var(--primary))'])[j], r = Math.min(4, bw / 2);
        const path = `M${x.toFixed(1)} ${H} V${(y + r).toFixed(1)} Q${x.toFixed(1)} ${y.toFixed(1)} ${(x + r).toFixed(1)} ${y.toFixed(1)} H${(x + bw - r).toFixed(1)} Q${(x + bw).toFixed(1)} ${y.toFixed(1)} ${(x + bw).toFixed(1)} ${(y + r).toFixed(1)} V${H} Z`;
        if (gr.cur && o.cur !== false) { defs += `<pattern id="${id}-${gi}-${j}" width="5" height="5" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="2.2" height="5" fill="${c}"/></pattern>`;
          s += `<path d="${path}" fill="${c}" opacity=".22"/><path d="${path}" fill="url(#${id}-${gi}-${j})"/><path d="${path}" fill="none" stroke="${c}" stroke-width="1.2"/>`; }
        else s += `<path d="${path}" fill="${c}"${gr.dim ? ' opacity=".35"' : ''}/>`;
        if (o.vals && v) s += `<text x="${(x + bw / 2).toFixed(1)}" y="${(y - 5).toFixed(1)}" text-anchor="middle" class="${gr.hl ? 'b' : ''}" style="font-size:9.5px">${(o.vf || ((z) => PL.n(z)))(v)}</text>`; });
      s += `<text x="${(gi * gw + gw / 2).toFixed(1)}" y="${H + 15}" text-anchor="middle" class="${gr.hl ? 'b' : ''}">${gr.l}</text>`; });
    s += `<line x1="0" x2="${pw}" y1="${H}" y2="${H}" stroke="var(--rule2)"/>`;
    return `<div class="pl-ch" role="img" aria-label="${o.aria || ''}"><svg width="${W}" height="${H + 19}" viewBox="0 0 ${W} ${H + 19}"><defs>${defs}</defs>${s}</svg></div>`; },
  // 7 barres simples de Cristal avec leurs lettres : PL.weekBars([2140, 2310, 1980, 1078, 0, 0, 0], { goal: 2200, today: 3, h: 56 })
  weekBars: (vals, o = {}) => `<div style="height:${o.h || 56}px">${U.bars(vals, { goal: o.goal, today: o.today, max: o.max })}</div>${U.barsLab(o.lab || WEEKDAYS, o.today ?? vals.length - 1)}`,
  // Anneau en parts : items [{ v, c }], o.s taille, o.sw épaisseur, o.in = HTML du centre, o.gap = 0 pour un anneau de progression
  donut(items, o = {}) { const S = o.s || 150, sw = o.sw || 16, r = (S - sw) / 2, cx = S / 2, tot = items.reduce((a, b) => a + b.v, 0), gapA = o.gap ?? 0.035;
    let a0 = -Math.PI / 2, s = '';
    items.forEach((it) => { if (it.v <= 0) return; const a1 = a0 + it.v / tot * Math.PI * 2 - (items.length === 1 ? 0.0001 : 0), b0 = a0 + gapA / 2, b1 = a1 - gapA / 2, large = b1 - b0 > Math.PI ? 1 : 0;
      s += `<path d="M${(cx + r * Math.cos(b0)).toFixed(2)} ${(cx + r * Math.sin(b0)).toFixed(2)} A${r} ${r} 0 ${large} 1 ${(cx + r * Math.cos(b1)).toFixed(2)} ${(cx + r * Math.sin(b1)).toFixed(2)}" fill="none" stroke="${it.c}" stroke-width="${sw}" stroke-linecap="${o.cap || 'butt'}"/>`; a0 = a1; });
    return `<div class="pl-donut" style="width:${S}px;height:${S}px" role="img" aria-label="${o.aria || ''}"><svg width="${S}" height="${S}" viewBox="0 0 ${S} ${S}">${s}</svg>${o.in ? `<div class="in">${o.in}</div>` : ''}</div>`; },
  // Barre empilée 100 % (répartition) : PL.stack([{ v: 24, c: 'var(--c-prot)' }, …])
  stack: (items, h = 14) => { const tot = items.reduce((a, b) => a + b.v, 0); return `<div class="pl-stack" style="height:${h}px">${items.map((it) => `<i style="background:${PL._cv(it.c) || 'var(--c, var(--primary))'};width:${(it.v / tot * 100).toFixed(2)}%"></i>`).join('')}</div>`; },
  // Calendrier du mois par intensité : o.vals[jour − 1], o.max, o.c ; aujourd'hui entouré ; jours à venir en pointillés. Novembre 2026 par défaut (le 1er est un dimanche).
  heat(o = {}) { const J = PL.JOUR, vals = o.vals || [], days = o.days || J.jours, today = o.today || J.jour, dow0 = o.dow0 ?? J.dow0, max = o.max || Math.max(...vals, 1), col = o.c || 'var(--c, var(--primary))';
    let h = WEEKDAYS.map((d) => `<span class="h">${d}</span>`).join('') + '<span class="h"></span>'.repeat(dow0);
    for (let d = 1; d <= days; d++) { const v = vals[d - 1] || 0;
      if (d > today) h += `<span class="f">${d}</span>`;
      else { const p = v / max, bg = v ? `color-mix(in srgb, ${col} ${Math.round(12 + 70 * Math.min(1, p))}%, var(--card))` : 'var(--well)';
        h += `<span class="${d === today ? 't' : ''}" style="background:${bg};color:${p > .45 ? '#fff' : 'var(--ink)'}">${d}</span>`; } }
    return `<div class="pl-heat" role="img" aria-label="${o.aria || ''}">${h}</div>`; },
  // Calendrier du mois par état : o.done = [jours faits] (coche sur fond plein), les autres jours passés sont « non faits » (fond creux), l'avenir en pointillés
  cal(o = {}) { const J = PL.JOUR, days = o.days || J.jours, today = o.today || J.jour, dow0 = o.dow0 ?? J.dow0, done = o.done || [];
    let h = WEEKDAYS.map((d) => `<span class="h">${d}</span>`).join('') + '<span class="h"></span>'.repeat(dow0);
    for (let d = 1; d <= days; d++) h += d > today ? `<span class="f">${d}</span>` : done.includes(d) ? `<span class="on${d === today ? ' t' : ''}" aria-label="${d} : fait"><i data-i="check"></i></span>` : `<span class="off${d === today ? ' t' : ''}">${d}</span>`;
    return `<div class="pl-heat round" role="img" aria-label="${o.aria || ''}"${o.c ? ` style="--c:${o.c}"` : ''}>${h}</div>`; },

  /* ---------- planche ---------- */
  // pastille de la mini-app (icône et nom à sa couleur) : PL.app('nut')
  app: (k) => { const a = PL.APPS[k] || { nom: k, i: 'grid' }; return `<span class="pl-app" data-c="${k}"><i data-i="${a.i}"></i>${a.nom}</span>`; },
  // paires « titre · texte » d'une case de texte : PL.take([['Gardé', '…'], ['Laissé de côté', '…']])
  take: (pairs) => `<div class="pl-take">${pairs.map(([b, t]) => `<b>${b}</b><span>${t}</span>`).join('')}</div>`,

  /* Table de fin « Rien n'est retiré : où se trouve chaque fonction existante ».
     PL.mapTable(id, FONCTIONS, OU, o)
       FONCTIONS = la liste F1…Fn de l'audit du sujet : [['F1', 'Choisir le jour affiché', 'G'], …]   accès : 'G', 'P' ou 'G+P'
       OU        = { F1: [1, 'Sélecteur en tête'],          sur l'écran 1 de la planche
                     F3: [[1, 4], 'Anneau ; détail'],       sur les écrans 1 et 4
                     F62: ['=', 'Notifications : inchangées, réglées dans « Rappels »'] }    gardée à sa place actuelle, non dessinée ici
     Une fonction absente de OU, sans numéro d'écran, ou « = » sans explication, sort EN ROUGE, comptée en tête de table. */
  mapTable(id, features, where = {}, o = {}) { const el = document.getElementById(id); if (!el) throw new Error('PL.mapTable : pas de bloc #' + id);
    const nPhones = document.querySelectorAll('.col > .phone').length, keys = features.map((f) => f[0]);
    const unknown = Object.keys(where).filter((k) => !keys.includes(k)), dup = keys.filter((k, i) => keys.indexOf(k) !== i);
    let onScreen = 0, kept = 0; const miss = [], badRef = [];
    const rows = features.map(([k, t, ac = 'G']) => { const w = where[k]; let scr = [], txt = '', eq = false, why = '';
      if (typeof w === 'number') scr = [w];
      else if (Array.isArray(w)) { if (w[0] === '=') eq = true; else scr = [].concat(w[0]).filter((x) => typeof x === 'number'); txt = w[1] || ''; }
      else if (typeof w === 'string' && w.trim()) { txt = w; why = 'écran non indiqué'; }
      if (!w) why = 'non placée'; else if (eq && !txt.trim()) why = '« = » sans explication'; else if (!eq && !scr.length && !why) why = 'écran non indiqué';
      const bad = scr.filter((x) => x < 1 || x > nPhones); if (bad.length) badRef.push(`${k} → écran ${bad.join(', ')}`);
      if (why) miss.push(k); else if (eq) kept++; else onScreen++;
      const acc = ac === 'P' ? 'p' : /\+/.test(ac) ? 'gp' : 'g';
      const chips = eq ? '<i class="eq">Inchangé</i>' : scr.map((x) => `<i class="${bad.includes(x) ? 'bad' : ''}">${x}</i>`).join('');
      return `<div class="r${why ? ' miss' : ''}"><span class="k">${k}</span><span class="t">${t}</span><span class="ac ${acc}">${ac}</span><span class="w">${why ? `NON PLACÉE${why === 'non placée' ? '' : ' (' + why + ')'}${txt ? ' · ' + txt : ''}` : chips + txt}</span></div>`; });
    const cols = o.cols || (features.length > 26 ? 3 : 2), problems = [];
    if (miss.length) problems.push(`${miss.length} fonction${miss.length > 1 ? 's' : ''} non placée${miss.length > 1 ? 's' : ''} : ${miss.join(', ')}`);
    if (unknown.length) problems.push(`clé${unknown.length > 1 ? 's' : ''} absente${unknown.length > 1 ? 's' : ''} de la liste du sujet : ${unknown.join(', ')}`);
    if (dup.length) problems.push(`numéro${dup.length > 1 ? 's' : ''} en double dans la liste : ${[...new Set(dup)].join(', ')}`);
    if (badRef.length) problems.push(`écran absent de la planche : ${badRef.join(' ; ')}`);
    PL._map = { total: features.length, onScreen, kept, miss, unknown, dup, badRef, problems };
    el.classList.add('pl-map');
    el.innerHTML = `<h4>Rien n'est retiré : où se trouve chaque fonction existante</h4>
      <p class="lg">${o.note || 'Liste des fonctions relevées dans le code par l\'audit du sujet. <b>G</b> = gratuite ; <b>P</b> = Premium ; <b>G+P</b> = gratuite avec une part Premium. Les règles Premium ne changent dans aucune direction. Le numéro noir renvoie à l\'écran de cette planche ; « Inchangé » = la fonction garde sa place actuelle et n\'est pas redessinée ici.'}</p>
      <div class="sum"><span><b>${features.length}</b> fonctions existantes</span><span><b>${onScreen}</b> sur les écrans de la planche</span><span><b>${kept}</b> gardées à leur place actuelle</span><span class="${miss.length ? 'ko' : 'ok'}"><b>${miss.length}</b> non placée${miss.length > 1 ? 's' : ''}</span></div>
      ${problems.length ? `<div class="bad">À corriger avant de livrer : ${problems.join(' · ')}.</div>` : ''}
      <div class="rows${cols === 3 ? ' c3' : ''}">${rows.join('')}</div>`; },

  /* Grille de comparaison : 5 directions × 10 critères (PL.CRITERES, ceux de la mission), notes sur 10, total sur 100.
     PL.grid(id, { dirs: ['Minimaliste', 'Tableau de bord', …5 noms], notes: [ 10 lignes de 5 cases [note, 'raison en quelques mots'] ],
                   rec: 4 (index de la direction conseillée, de 0 à 4), acces: 'Noter un repas · ouvrir l\'historique' (les deux gestes comptés) })
     La meilleure note de chaque ligne est cerclée ; le meilleur total est agrandi et couronné ; la colonne conseillée est teintée.
     Une grille incomplète (pas 10 × 5, note hors de 0 à 10) n'est pas dessinée : un message rouge la remplace. */
  grid(id, o) { const el = document.getElementById(id), D = o.dirs || [], N = o.notes || [], errs = [];
    if (D.length !== 5) errs.push(`il faut 5 directions (reçu : ${D.length})`);
    if (N.length !== PL.CRITERES.length) errs.push(`il faut ${PL.CRITERES.length} lignes de notes, une par critère (reçu : ${N.length})`);
    N.forEach((r, i) => { if (!Array.isArray(r) || r.length !== D.length) errs.push(`critère ${i + 1} : ${Array.isArray(r) ? r.length : 0} cases au lieu de ${D.length}`);
      else r.forEach((c, j) => { if (!Array.isArray(c) || !Number.isInteger(c[0]) || c[0] < 0 || c[0] > 10) errs.push(`critère ${i + 1}, direction ${j + 1} : note invalide`); else if (!c[1]) errs.push(`critère ${i + 1}, direction ${j + 1} : raison manquante`); }); });
    if (o.rec == null || o.rec < 0 || o.rec > 4) errs.push('direction conseillée (rec) manquante');
    if (errs.length) { el.outerHTML = `<div class="pl-err" id="${id}">Grille de comparaison incomplète : ${errs.slice(0, 8).join(' · ')}.</div>`; PL._grid = { errs }; return; }
    const cls = (n) => (n >= 9 ? 'a' : n >= 7 ? 'b' : n >= 5 ? 'm' : 'l'), tot = D.map((_, j) => N.reduce((a, r) => a + r[j][0], 0)), best = Math.max(...tot), R = o.rec;
    let h = `<tr><th></th>${D.map((t, j) => `<th class="${j === R ? 'rec' : ''}"><small>Direction ${j + 1}${j === R ? ' · conseillée' : ''}</small>${t}</th>`).join('')}</tr>`;
    N.forEach((r, i) => { const top = Math.max(...r.map((c) => c[0])), [c, s] = PL.CRITERES[i];
      h += `<tr><td class="c">${c}<small>${i === 3 && o.acces ? o.acces : s}</small></td>${r.map(([n, w], j) => `<td class="${j === R ? 'rec' : ''}"><div class="cell"><span class="n ${cls(n)}${n === top ? ' top' : ''}">${n}</span><span class="w">${w}</span></div></td>`).join('')}</tr>`; });
    h += `<tr class="tot"><td>Total</td>${tot.map((t, j) => `<td class="${j === R ? 'rec' : ''}${t === best ? ' best' : ''}"><b>${t}</b> <small>sur 100</small>${t === best ? '<span class="crown">Meilleur total</span>' : ''}</td>`).join('')}</tr>`;
    const bestIdx = tot.map((t, j) => (t === best ? j : -1)).filter((j) => j >= 0);
    el.outerHTML = `<table class="pl-grid" id="${id}">${h}</table>
      <div class="pl-gleg"><span><span class="pl-n10 a">9</span>très bon (9 ou 10)</span><span><span class="pl-n10 b">7</span>bon (7 ou 8)</span><span><span class="pl-n10 m">5</span>moyen (5 ou 6)</span><span><span class="pl-n10 l">4</span>faible (4 ou moins)</span><span><span class="pl-n10 b top">8</span>meilleure note du critère</span><span style="margin-left:auto">Notes de jugement, à partir des planches et de l'audit : pas de tests avec des utilisateurs.</span></div>`
      + (bestIdx.includes(R) ? '' : `<div class="pl-gnote">La direction conseillée (${R + 1} · ${D[R]}, ${tot[R]} sur 100) n'a pas le meilleur total (${bestIdx.map((j) => `${j + 1} · ${D[j]}`).join(', ')} : ${best} sur 100). La raison est donnée dans la recommandation.</div>`);
    PL._grid = { tot, best, rec: R }; },

  /* Une carte par direction : vignette du premier écran, avantages, inconvénients, pour qui.
     PL.cards(id, [{ shot: '01-minimaliste', t: 'Minimaliste', plus: ['…'], minus: ['…'], who: '…' } × 5], { rec: 4 })
     La vignette est ecrans/<shot>-01.png du dossier rendu du sujet (PL.pub + PL.dossier) : rendre les 5 directions avec --phones d'abord. */
  cards(id, list, o = {}) { const base = o.base || (PL.pub + PL.dossier + '/ecrans/');
    document.getElementById(id).innerHTML = list.map((d, i) => `<div class="pl-card${i === o.rec ? ' rec' : ''}"><img src="${base}${d.shot}-${d.n || '01'}.png" alt="" onerror="this.outerHTML='&lt;div class=&quot;noimg&quot;&gt;Vignette absente : rendre ${d.shot}.html avec --phones&lt;/div&gt;'">
      <div class="k">Direction ${i + 1}${i === o.rec ? ' · conseillée' : ''}</div><h5>${d.t}</h5>
      <h6>Avantages</h6><ul class="p">${d.plus.map((x) => `<li>${x}</li>`).join('')}</ul><h6>Inconvénients</h6><ul class="m">${d.minus.map((x) => `<li>${x}</li>`).join('')}</ul>${d.who ? `<div class="who">${d.who}</div>` : ''}</div>`).join(''); },

  /* Analyse : la table des fonctions existantes, à partir de la même liste FONCTIONS que la table de fin (un 4e élément facultatif = ce qu'elle fait, en quelques mots).
     PL.fnTable(id, FONCTIONS, { cols: 3 }) : remplit le bloc #id de 3 tables côte à côte (N° · Fonction · Accès). */
  fnTable(id, features, o = {}) { const cols = o.cols || 3, per = Math.ceil(features.length / cols), lab = { g: 'Gratuit', p: 'Premium', gp: 'Gratuit + Premium' }; let h = '';
    for (let c = 0; c < cols; c++) h += '<div class="pl-box"><table class="pl-t"><tr><th>N°</th><th>Fonction</th><th>Accès</th></tr>'
      + features.slice(c * per, (c + 1) * per).map(([k, t, ac = 'G', note]) => { const a = ac === 'P' ? 'p' : /\+/.test(ac) ? 'gp' : 'g'; return `<tr><td>${k}</td><td>${t}${note ? `<small>${note}</small>` : ''}</td><td class="${a}">${lab[a]}</td></tr>`; }).join('') + '</table></div>';
    const el = document.getElementById(id); el.className = cols === 2 ? 'pl-2' : 'pl-3 eq'; el.innerHTML = h; },

  /* Analyse : une capture réelle annotée. PL.shot('chemin.png', [[78, 35, 1], [50, 65, 4]]) : pastilles rouges [x %, y %, numéro du problème].
     Capture absente : un cadre en pointillés la remplace et le dit (jamais de fausse capture). */
  shot: (src, pins = [], o = {}) => `<div class="pl-shot"><img src="${src}" alt="${o.alt || ''}" onerror="this.outerHTML='&lt;div class=&quot;noimg&quot;&gt;&lt;span&gt;&lt;b&gt;Capture à venir&lt;/b&gt;${(o.name || src.split('/').pop())}&lt;/span&gt;&lt;/div&gt;'">${pins.map(([x, y, n]) => `<b class="k" style="left:${x}%;top:${y}%">${n}</b>`).join('')}</div>`,
  /* Analyse : le ruban de l'écran principal. PL.ribbon(id, [['Sélecteur de semaine', 100, 'key'], ['Liens', 150, ''], ['Historique', 60, 'hot']], { k: .36, screen: 700 })
     hauteurs en points ; 'key' = visible en ouvrant ; 'hot' = important mais tard ; un repère pointillé tous les « screen » points. */
  ribbon(id, items, o = {}) { const K = o.k || .36, S = o.screen || 700, tot = items.reduce((a, b) => a + b[1], 0); let h = items.map(([t, v, c]) => `<div class="${c || ''}" style="height:${Math.max(14, v * K - 4).toFixed(0)}px">${t}</div>`).join('');
    h += '<span class="scr-l" style="top:10px;border-color:transparent"><span>écran 1</span></span>';
    for (let k = 1; k * S < tot; k++) h += `<span class="scr-l" style="top:${(10 + k * S * K).toFixed(0)}px"><span>écran ${k + 1}</span></span>`;
    const el = document.getElementById(id); el.classList.add('rb0'); el.innerHTML = h; },

  /* ---------- montage et contrôle ---------- */
  /* PL.init() : à appeler en dernier (à la place de Cristal.init()).
     1. pastille de la mini-app dans .pl-kick, heure 13:20 sur tout téléphone sans data-time ; 2. numérote les écrans dans l'ordre du document (1 à n : le même numéro que ecrans/<planche>-NN.png) ;
     3. écrit les étiquettes vides (.tag.e Existe, .tag.a À adapter, .tag.n Nouveau, .tag.g → Écran N) et les priorités (<li data-p="1">) ;
     4. appelle Cristal.init() ; 5. avec ?check : retire les fausses alertes connues et ajoute le panneau des remarques (PL.lint). */
  init() { const main = document.querySelector('main.bd'), q = new URLSearchParams(location.search);
    const key = main && main.dataset.c;
    document.querySelectorAll('.pl-kick').forEach((k) => { if (key && !k.querySelector('.pl-app')) k.insertAdjacentHTML('afterbegin', PL.app(key)); });
    const cols = [...document.querySelectorAll('.col')].filter((c) => c.querySelector(':scope > .phone'));
    document.querySelectorAll('.phone').forEach((ph) => { if (!ph.dataset.time) ph.dataset.time = PL.JOUR.heure; });   // 13:20 par défaut (Cristal seul mettrait 9:41)
    cols.forEach((c, i) => { c.dataset.n = i + 1; c.querySelector(':scope > .phone').dataset.n = i + 1; const nm = c.querySelector(':scope > .nm');
      if (nm) nm.innerHTML = `<b class="pl-n">${i + 1}</b><span>${nm.innerHTML.replace(/^\s*\d+\s*·\s*/, '')}</span>`; });
    const LAB = { e: 'Existe', a: 'À adapter', n: 'Nouveau', d: 'Nouveau' };
    document.querySelectorAll('.tag').forEach((t) => { if (t.textContent.trim()) return;
      if (t.classList.contains('g')) t.textContent = '→ Écran ' + (t.dataset.to || '?'); else for (const k in LAB) if (t.classList.contains(k)) { t.textContent = LAB[k]; break; } });
    document.querySelectorAll('.pl-rule li[data-p]').forEach((li) => { if (!li.querySelector('.p')) li.insertAdjacentHTML('afterbegin', `<b class="p p${li.dataset.p}">P${li.dataset.p}</b>`); });
    Cristal.init();
    if (q.has('check')) document.fonts.ready.then(() => setTimeout(() => {
      // fausses alertes connues du contrôle de Cristal : textes des graphiques SVG, rangées qui défilent sur le côté
      document.querySelectorAll('svg, svg *, [data-scroll], [data-scroll] *, .pl-quick, .pl-quick *, .chips:not(.fit), .chips:not(.fit) *, .tools, .tools *, .thumbs, .thumbs *').forEach((el) => { if (el.style && el.style.outline) el.style.outline = ''; });
      document.querySelectorAll('img').forEach((im) => { if (im.complete && !im.naturalWidth && im.onerror) im.onerror(); });   // image absente : son cadre de remplacement, tout de suite
      const L = PL.lint(), n = L.filter((x) => x.lvl === 'e').length;
      main.insertAdjacentHTML('beforeend', `<div class="pl-lint${L.length ? '' : ' ok'}"><h4>Contrôle de la planche : ${L.length ? `${n} erreur${n > 1 ? 's' : ''}, ${L.length - n} remarque${L.length - n > 1 ? 's' : ''}` : 'rien à signaler'}</h4><ul>${L.map((x) => `<li class="${x.lvl}">${x.msg}</li>`).join('')}</ul></div>`);
    }, 0)); },

  /* Contrôle de la planche. Renvoie [{ lvl: 'e' (erreur) | 'w' (remarque), msg }]. main.bd porte data-kind="direction" | "analyse" | "comparaison". */
  lint() { const L = [], e = (m) => L.push({ lvl: 'e', msg: m }), w = (m) => L.push({ lvl: 'w', msg: m });
    const main = document.querySelector('main.bd'), kind = (main && main.dataset.kind) || '', cols = [...document.querySelectorAll('.col')].filter((c) => c.querySelector(':scope > .phone'));
    if (!main || !main.dataset.c) e('main.bd sans data-c : la couleur de la mini-app n\'est pas posée sur la planche.');
    if (!kind) w('main.bd sans data-kind (direction, analyse ou comparaison).');
    if (!document.querySelector('.bd-head h1')) e('En-tête de planche absent (.bd-head avec numéro, titre, sous-titre, badge).');
    cols.forEach((c) => { const n = c.dataset.n, ph = c.querySelector(':scope > .phone'), cap = c.querySelector(':scope > .cap'), scr = ph.querySelector(':scope > .scr');
      if (!ph.dataset.c) e(`Écran ${n} : téléphone sans data-c.`);
      if (!/\bt-[a-z]+\b/.test(ph.className)) e(`Écran ${n} : téléphone sans thème (t-saphir).`);
      if (!scr || !scr.textContent.trim()) e(`Écran ${n} : écran vide.`);
      if (!cap || !cap.querySelector('h4') || !cap.querySelector('p')) e(`Écran ${n} : légende incomplète (titre et texte).`);
      else if (!cap.querySelector('.tag.e, .tag.a, .tag.n, .tag.d')) e(`Écran ${n} : légende sans étiquette « Existe », « À adapter » ou « Nouveau ».`);
      const newIn = ph.querySelector('.pl-new, .pl-newbox'), newCap = cap && cap.querySelector('.tag.n, .tag.d');
      if (newIn && !newCap) e(`Écran ${n} : un jeton « Nouveau » est dans l'écran mais pas dans la légende.`);
      if (!newIn && newCap) e(`Écran ${n} : la légende annonce du « Nouveau » qui n'est pas marqué dans l'écran.`);
      if (cap) cap.querySelectorAll('.tag.g').forEach((g) => { const to = +g.dataset.to; if (!to || to < 1 || to > cols.length) e(`Écran ${n} : passage vers l'écran « ${g.dataset.to || '?'} », qui n'existe pas sur la planche.`); });
      if (scr) { const hid = scr.scrollHeight - scr.clientHeight; if (hid > 320) { w(`Écran ${n} : ${hid} points de contenu sous le bas de l'écran. Couper en « suite » ou alléger (sauf longue liste voulue).`); } }
      ph.querySelectorAll(':scope > .sheet').forEach((s) => { if (s.getBoundingClientRect().top < ph.getBoundingClientRect().top + 44) { e(`Écran ${n} : la feuille monte jusqu'à la barre d'état (trop de contenu).`); s.classList.add('pl-over-mark'); } });
      ph.querySelectorAll('.pl-ch svg').forEach((s) => { const box = s.closest('.pn, .gl, .sheet, .scr'); if (box && s.getBoundingClientRect().right > box.getBoundingClientRect().right - 8) { w(`Écran ${n} : un graphique touche ou dépasse le bord de sa carte (régler o.w).`); s.classList.add('pl-over-mark'); } });
      const red = [...ph.querySelectorAll('*')].filter((x) => x.style && /red/.test(x.style.outline)).length; if (red) e(`Écran ${n} : ${red} texte${red > 1 ? 's' : ''} coupé${red > 1 ? 's' : ''} ou débordant${red > 1 ? 's' : ''} (entouré${red > 1 ? 's' : ''} de rouge).`); });
    if (kind === 'direction') {
      if (cols.length < 6 || cols.length > 9) e(`Une planche de direction montre de 6 à 9 écrans (ici : ${cols.length}).`);
      const rule = document.querySelector('.pl-rule'); if (!rule) e('Bloc « La logique » absent (.pl-rule).'); else if (rule.children.length !== 4) e('« La logique » doit avoir 4 colonnes.');
      if (!document.querySelector('.flow')) w('Aucune flèche de passage (.flow) entre les écrans.');
      if (!document.querySelector('.cap .tag.g')) w('Aucun passage écrit en légende (« → Écran N »).');
      if (!PL._map) e('Table de fin « Rien n\'est retiré » absente (PL.mapTable).'); else PL._map.problems.forEach((p) => e('Table de fin : ' + p + '.'));
    }
    if (kind === 'comparaison') { if (!PL._grid) e('Grille de notes absente (PL.grid).'); else if (PL._grid.errs) e('Grille de notes incomplète.');
      if (!document.querySelector('.pl-card')) e('Cartes avantages / inconvénients absentes (PL.cards).'); else if (document.querySelector('.pl-card .noimg')) w('Vignette d\'une direction absente : rendre les 5 directions avec --phones avant la comparaison.');
      if (!document.querySelector('.pl-rec')) e('Bloc recommandation absent (.pl-rec).'); if (!document.querySelector('.pl-q')) e('Questions pour le PDG absentes (.pl-q).'); }
    if (kind === 'analyse') { if (document.querySelector('.pl-shot .noimg')) w('Au moins une capture réelle manque (cadre en pointillés).'); }
    document.querySelectorAll('img').forEach((im) => { if (im.complete && !im.naturalWidth) w('Image introuvable : ' + (im.getAttribute('src') || im.dataset.w || '')); });
    return L; },
};
