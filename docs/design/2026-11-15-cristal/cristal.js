/* cristal.js : thèmes, icônes, données d'exemple et utilitaires communs aux planches « Cristal ». À charger en fin de <body>,
   puis appeler Cristal.init() en dernier.
   - THEMES : les 10 déclinaisons. Chaque thème écrit ses jetons CSS sur la classe .t-<id> (voir tokens()).
   - Données : la journée d'exemple de compositions/DONNEES.md (jeudi 12 novembre). DAY.matin / DAY.journee / DAY.soiree.
   - Déclaratif : <i data-i="fork"></i> icône · <div data-u="ring" data-p=".49" data-sw="9"></div> · data-u="meter|bars|spark|week|dots7|hab|wsel"
     · <span data-v="journee.kcal.left"></span> · <img data-w="calories-s-light"> (vrai export de widget) · <div data-pal="saphir"></div> (palette).
   - <div class="phone t-lavande" data-screen="homeA"></div> : accueil « Équilibrée » complet, généré (Screens.homeA).
   - Contrôles : ?check (texte coupé en rouge) · ?w375 · ?t=lavande (re-teinte toute la planche) · ?mode=dark (mode sombre) · ?dump (jetons et contrastes dans <pre id="boxes">). */

/* ---------- couleurs ---------- */
const C = {
  rgb: (h) => { h = h.replace('#', ''); return [0, 2, 4].map((k) => parseInt(h.slice(k, k + 2), 16)); },
  hex: (a) => '#' + a.map((v) => Math.round(Math.max(0, Math.min(255, v))).toString(16).padStart(2, '0')).join('').toUpperCase(),
  mix: (a, b, t) => { const x = C.rgb(a), y = C.rgb(b); return C.hex(x.map((v, k) => v + (y[k] - v) * t)); },
  lum: (h) => { const [r, g, b] = C.rgb(h).map((v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }); return 0.2126 * r + 0.7152 * g + 0.0722 * b; },
  cr: (a, b) => { const x = C.lum(a), y = C.lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); },
  // assombrit jusqu'à atteindre le contraste voulu sur un fond donné
  fit: (h, bg, min) => { let k = 0; while (C.cr(h, bg) < min && k++ < 40) h = C.mix(h, '#000000', 0.05); return h; },
  rgba: (h, a) => `rgba(${C.rgb(h).join(',')},${a})`,
};

/* ---------- les 10 déclinaisons ---------- */
// Catégories de référence (Cristal · Saphir). Chaque thème les ré-accorde : un peu de sa couleur principale (cat), ou de gris (gray).
const CATS0 = { nut: '#C36F25', fit: '#DF5661', pla: '#4385DB', hab: '#49961D', bud: '#1D9672', pro: '#79849A', pas: '#1E929F',
  prot: '#DF5661', gluc: '#A37F12', lip: '#4385DB', travail: '#926FE4', rdv: '#DD4DA1' };
const blob = (c, rx, ry, x, y) => `radial-gradient(${rx}px ${ry}px at ${x}px ${y}px, ${c} 0%, ${C.rgba(c, .8)} 50%, ${C.rgba(c, 0)} 100%)`;
const THEMES = [
  { id: 'saphir', name: 'Saphir', sub: 'Saphir et bleu glacier', app: 'Saphir (gratuite) + Bleu glacier', free: true,
    primary: '#245B8F', secondary: '#398FA8', accent: '#1E9EC0', bg: '#EEF3FA', na: '#BFEAF2', nb: '#C9D8FB', ink: '#0B1220', ink2: '#4E5A6B', rule: '#D6DFEB', track: '#D3DCE8',
    cat: 0, wash: (t) => [blob(t.na, 190, 190, 333, 200), blob(t.nb, 220, 220, 30, 640)] },
  { id: 'lavande', name: 'Lavande', sub: 'Lavande et violet doux', app: 'Améthyste + Orchidée',
    primary: '#6841A5', secondary: '#9854B8', accent: '#A765D6', bg: '#F4F1FA', na: '#DDD2F8', nb: '#F6D6E8', ink: '#1A1330', ink2: '#5A5270', rule: '#E1DAEE', track: '#DCD4EA',
    cat: .14, r: 28, wash: (t) => [blob(t.na, 220, 220, 50, 170), blob(t.nb, 230, 230, 390, 560)] },
  { id: 'rose', name: 'Rose poudré', sub: 'Rose poudré et corail', app: 'Rose + Rubis',
    primary: '#AD3561', secondary: '#E0705F', accent: '#DD6654', bg: '#FBF2F4', na: '#F9D2DC', nb: '#FFDDCC', ink: '#2A1420', ink2: '#6A5560', rule: '#F0DEE3', track: '#EBD8DE',
    cat: .12, r: 28, wash: (t) => [blob(t.na, 260, 200, 196, 70), blob(t.nb, 220, 220, 360, 770)] },
  { id: 'sauge', name: 'Sauge', sub: 'Vert sauge et menthe', app: 'Pistache',
    primary: '#4A6E39', secondary: '#7DB79E', accent: '#3E9E7C', bg: '#F2F6EF', na: '#D6E8CC', nb: '#D2F0E4', ink: '#152015', ink2: '#566355', rule: '#DCE6D6', track: '#D6E0CF',
    cat: .16, wash: (t) => [blob(t.na, 230, 230, 30, 300), blob(t.nb, 210, 210, 380, 640)] },
  { id: 'ocean', name: 'Océan', sub: 'Turquoise et bleu océan', app: 'Turquoise + Cobalt',
    primary: '#00727B', secondary: '#1F5FB8', accent: '#14A9B8', bg: '#ECF7F8', na: '#B5E9EC', nb: '#C5DAF8', ink: '#07191C', ink2: '#48605F', rule: '#D2E6E8', track: '#CDE0E3',
    cat: .12, wash: (t) => [blob(t.na, 340, 150, 196, 190), blob(t.nb, 230, 230, 50, 730)] },
  { id: 'sable', name: 'Sable', sub: 'Beige, sable et champagne', app: 'nouvelle teinte neutre (proche d\'Ambre)', isNew: true,
    primary: '#7B5D34', secondary: '#C8A97A', accent: '#B5813A', bg: '#F8F4EC', na: '#EFE0C4', nb: '#F6E8D6', ink: '#241C10', ink2: '#665A48', rule: '#E8DFCF', track: '#E3D9C7',
    cat: .18, panel: '#FFFDF9', chipR: '12px', wash: (t) => [blob(t.na, 230, 230, 350, 120), blob(t.nb, 210, 210, 20, 540)] },
  { id: 'graphite', name: 'Graphite', sub: 'Graphite clair et argent', app: 'nouvelle teinte neutre', isNew: true,
    primary: '#2B323D', secondary: '#5E7590', accent: '#56789F', bg: '#F1F3F6', na: '#D3DBE6', nb: '#DCE3EE', ink: '#12161C', ink2: '#545D6A', rule: '#DCE0E7', track: '#D5DAE2',
    cat: 0, gray: .05, r: 22, chipR: '10px', wash: (t) => [`linear-gradient(165deg, ${t.na} 0%, ${C.rgba(t.na, 0)} 42%)`, blob(t.nb, 250, 250, 320, 800)] },
  { id: 'peche', name: 'Pêche', sub: 'Pêche et abricot', app: 'Ambre',
    primary: '#A04C1B', secondary: '#F0A56B', accent: '#E07B32', bg: '#FCF4EC', na: '#FFDCC2', nb: '#FFE9C6', ink: '#2A170B', ink2: '#6B5747', rule: '#F1E0D0', track: '#EBDAC9',
    cat: .12, r: 28, wash: (t) => [blob(t.na, 220, 220, 330, 150), blob(t.nb, 240, 240, 80, 700)] },
  { id: 'foret', name: 'Forêt', sub: 'Vert forêt et eucalyptus', app: 'Jade',
    primary: '#1F6B5C', secondary: '#6FA898', accent: '#2B9A7C', bg: '#EEF5F2', na: '#BFE1D4', nb: '#CEE8E6', ink: '#0C1C18', ink2: '#4A5F59', rule: '#D5E4DE', track: '#CFDFD9',
    cat: .14, wash: (t) => [blob(t.na, 230, 230, 60, 180), blob(t.nb, 220, 220, 360, 700)] },
  { id: 'mono', name: 'Monochrome', sub: 'Blanc et gris', app: 'nouvelle teinte neutre', isNew: true,
    primary: '#1B1D21', secondary: '#8A8F98', accent: '#5E636C', bg: '#F5F5F6', na: '#FFFFFF', nb: '#E9EAEC', ink: '#111214', ink2: '#5A5E66', rule: '#E1E2E5', track: '#DCDDE0',
    cat: 0, gray: .82, r: 20, chipR: '10px', wash: (t) => [`linear-gradient(180deg, ${t.na} 0%, ${C.rgba(t.na, 0)} 38%)`, blob(t.nb, 260, 260, 340, 760)] },
];
// Jetons complets d'un thème (tout en HEX ou rgba calculé) : sert au CSS et aux fiches de palette.
function tokens(t) {
  const gray = C.mix(t.ink2, '#FFFFFF', .15), panel = t.panel || '#FFFFFF';
  const cat = (k) => { let c = C.mix(CATS0[k], t.primary, t.cat || 0); if (t.gray) c = C.mix(c, gray, t.gray); return C.fit(c, panel, k === 'gluc' ? 3.0 : 3.2); };
  const o = { bg: t.bg, ink: t.ink, ink2: t.ink2, rule: t.rule, rule2: C.mix(t.rule, t.ink2, .35), primary: t.primary, onPrimary: '#FFFFFF', secondary: t.secondary, accent: C.fit(t.accent, panel, 3.0),
    tint: C.mix(t.primary, '#FFFFFF', .90), tint2: C.mix(t.primary, '#FFFFFF', .86), track: t.track, grid: C.mix(t.track, '#FFFFFF', .45), go: C.mix(t.ink2, '#FFFFFF', .12), dot: C.mix(t.track, t.ink2, .22),
    panelSolid: panel, cs: {}, sheet: C.mix(panel, t.bg, .12), well: C.mix(t.bg, t.track, .35), well2: C.mix(t.bg, t.primary, .10), na: t.na, nb: t.nb, ok: C.fit('#23835F', panel, 4.5), cats: {} };
  Object.keys(CATS0).forEach((k) => { o.cats[k] = cat(k); o.cs[k] = C.fit(o.cats[k], '#FFFFFF', 4.6); });
  return o;
}
function themeCss() {
  return THEMES.map((t) => { const k = tokens(t), c = k.cats, pr = C.rgb(t.panel || '#FFFFFF').join(',');
    return `.t-${t.id}{--bg:${k.bg};--wash:${t.wash(t).join(',')};--ink:${k.ink};--ink2:${k.ink2};--rule:${k.rule};--rule2:${k.rule2};--primary:${k.primary};--on-primary:#fff;`
      + `--secondary:${k.secondary};--accent:${k.accent};--tint:${k.tint};--tint2:${k.tint2};--track:${k.track};--grid:${k.grid};--go:${k.go};--dot:${k.dot};`
      + `--card:${k.panelSolid};--glass:rgba(${pr},.55);--panel:rgba(${pr},.80);--panel2:rgba(${pr},.5);--sheet:${k.sheet};--well:${k.well};--well2:${k.well2};--sh:${C.rgb(t.primary).join(' ')};--ok:${k.ok};`
      + `--r:${t.r || 26}px;--chip-r:${t.chipR || '50%'};--chip-mix:${t.gray > .5 ? 10 : 13}%;`
      + `--c-nut:${c.nut};--c-fit:${c.fit};--c-pla:${c.pla};--c-hab:${c.hab};--c-bud:${c.bud};--c-pro:${c.pro};--c-pas:${c.pas};--c-prot:${c.prot};--c-gluc:${c.gluc};--c-lip:${c.lip};`
      + ['nut', 'fit', 'pla', 'hab', 'bud', 'pro', 'pas'].map((x) => `--cs-${x}:${k.cs[x]};`).join('')
      + `--ev-cours:${c.pla};--ev-travail:${c.travail};--ev-rdv:${c.rdv};--ev-seance:${c.fit};--ev-tache:${c.pro};}`; }).join('\n')
    + '\n' + ['nut', 'fit', 'pla', 'hab', 'bud', 'pro', 'pas', 'prot', 'gluc', 'lip'].map((k) => `[data-c="${k}"]{--c:var(--c-${k});--cs:var(--cs-${k}, var(--c-${k}))}`).join('')
    + ['cours', 'travail', 'rdv', 'seance', 'tache'].map((k) => `[data-ev="${k}"]{--c:var(--ev-${k})}`).join('');
}
/* ---------- mode sombre ----------
   Mêmes règles que l'app (Shared/Theme/AppStyle.swift) : fond = la teinte à 5,5 % de clarté, carte à 11,5 %, couleur d'action claire
   (accentDark de la teinte de l'app), encre sombre sur un bouton plein quand sa couleur est claire. Classe .dk sur .phone (ou ?mode=dark). */
const DARK = { saphir: '#68B5F5', lavande: '#B69AFF', rose: '#FF83B2', sauge: '#B8D987', ocean: '#45DDE0', sable: '#E3C08A', graphite: '#E6EBF2', peche: '#FFB454', foret: '#65D5BC', mono: '#F2F2F4' };
C.hsl = (hex) => { const [r, g, b] = C.rgb(hex).map((v) => v / 255), hi = Math.max(r, g, b), lo = Math.min(r, g, b), l = (hi + lo) / 2, d = hi - lo;
  if (!d) return { h: 0, s: 0, l }; const s = d / (1 - Math.abs(2 * l - 1)); let h = hi === r ? ((g - b) / d) % 6 : hi === g ? (b - r) / d + 2 : (r - g) / d + 4; h *= 60; if (h < 0) h += 360; return { h, s, l }; };
C.fromHsl = (h, s, l) => { const c = (1 - Math.abs(2 * l - 1)) * s, x = c * (1 - Math.abs((h / 60) % 2 - 1)), m = l - c / 2;
  const p = [[c, x, 0], [x, c, 0], [0, c, x], [0, x, c], [x, 0, c], [c, 0, x]][Math.floor(h / 60) % 6]; return C.hex(p.map((v) => (v + m) * 255)); };
// éclaircit jusqu'à atteindre le contraste voulu sur un fond sombre
C.lift = (h, bg, min) => { let k = 0; while (C.cr(h, bg) < min && k++ < 40) h = C.mix(h, '#FFFFFF', 0.05); return h; };
function tokensDark(t) {
  const hue = C.hsl(t.primary).h, sat = t.gray ? (t.gray > .5 ? 0 : .22) : 1;       // teintes neutres : presque sans couleur
  const bg = C.fromHsl(hue, .45 * sat, .055), card = C.fromHsl(hue, .35 * sat, .115), primary = DARK[t.id];
  const darkInk = C.fromHsl(hue, .5 * sat, .07), onPrimary = C.cr(darkInk, primary) >= C.cr('#FFFFFF', primary) ? darkInk : '#FFFFFF';
  const ink = C.mix('#FFFFFF', primary, .05), ink2 = C.mix(ink, card, .36), gray = '#9AA3B0';
  const cat = (k) => { let c = C.mix(CATS0[k], t.primary, t.cat || 0); if (t.gray) c = C.mix(c, gray, t.gray); return C.lift(C.mix(c, '#FFFFFF', .16), card, 5.0); };
  const o = { bg, card, ink, ink2, primary, onPrimary, secondary: C.lift(t.secondary, card, 4.5), accent: C.lift(t.accent, card, 4.5),
    rule: C.mix(card, '#FFFFFF', .10), rule2: C.mix(card, '#FFFFFF', .22), tint: C.mix(card, primary, .13), tint2: C.mix(card, primary, .19), track: C.mix(card, '#FFFFFF', .13), grid: C.mix(card, '#FFFFFF', .07),
    go: C.mix(ink2, card, .35), dot: C.mix(card, '#FFFFFF', .24), panelSolid: card, sheet: C.mix(card, '#FFFFFF', .03), well: C.mix(bg, '#FFFFFF', .06), well2: C.mix(bg, primary, .10),
    na: C.mix(bg, t.gray > .5 ? '#8A8F98' : t.secondary, .32), nb: C.mix(bg, t.gray > .5 ? '#5E636C' : t.primary, .46), ok: '#5FD3A0', cats: {}, cs: {} };
  Object.keys(CATS0).forEach((k) => { o.cats[k] = cat(k); o.cs[k] = o.cats[k]; });
  return o;
}
function themeCssDark() {
  return THEMES.map((t) => { const k = tokensDark(t), c = k.cats, pr = C.rgb(k.card).join(',');
    return `.dk.t-${t.id}{color-scheme:dark;--bg:${k.bg};--card:${k.card};--wash:${t.wash({ ...t, na: k.na, nb: k.nb }).join(',')};--ink:${k.ink};--ink2:${k.ink2};--rule:${k.rule};--rule2:${k.rule2};--primary:${k.primary};--on-primary:${k.onPrimary};`
      + `--secondary:${k.secondary};--accent:${k.accent};--tint:${k.tint};--tint2:${k.tint2};--track:${k.track};--grid:${k.grid};--go:${k.go};--dot:${k.dot};`
      + `--glass:rgba(255,255,255,.09);--panel:rgba(${pr},.84);--panel2:rgba(${pr},.5);--sheet:${k.sheet};--well:${k.well};--well2:${k.well2};--sh:0 0 0;--ok:${k.ok};`
      + `--c-nut:${c.nut};--c-fit:${c.fit};--c-pla:${c.pla};--c-hab:${c.hab};--c-bud:${c.bud};--c-pro:${c.pro};--c-pas:${c.pas};--c-prot:${c.prot};--c-gluc:${c.gluc};--c-lip:${c.lip};`
      + ['nut', 'fit', 'pla', 'hab', 'bud', 'pro', 'pas'].map((x) => `--cs-${x}:${k.cs[x]};`).join('')
      + `--ev-cours:${c.pla};--ev-travail:${c.travail};--ev-rdv:${c.rdv};--ev-seance:${c.fit};--ev-tache:${c.pro};}`; }).join('\n');
}
document.head.insertAdjacentHTML('beforeend', `<style id="themes">${themeCss()}\n${themeCssDark()}</style>`);

/* ---------- icônes au trait (24 × 24) ---------- */
const P = {
  home: 'M3 11l9-8 9 8v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z', plus: 'M12 5v14M5 12h14', plusbox: 'M5 4h14a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1zM12 8.5v7M8.5 12h7',
  bag: 'M5 8h14l-1 12H6zM9 8V6a3 3 0 0 1 6 0v2', grid: 'M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z',
  fork: 'M7 3v7a2 2 0 0 0 4 0V3M9 12v9M17 3c-2 2-3 5-3 8h3v10', dumbbell: 'M3 9v6M6 6v12M18 6v12M21 9v6M6 12h12',
  repeat: 'M17 2l3 3-3 3M4 11V9a4 4 0 0 1 4-4h12M7 22l-3-3 3-3M20 13v2a4 4 0 0 1-4 4H4',
  wallet: 'M3 7a2 2 0 0 1 2-2h13v4M3 7v10a2 2 0 0 0 2 2h15V9H5a2 2 0 0 1-2-2zM16 14h.01',
  calendar: 'M4 6h16v14H4zM4 10h16M8 3v4M16 3v4', check: 'M5 12.5l4.5 4.5L19 7.5',
  list: 'M9 6h11M9 12h11M9 18h11M4.5 6h.01M4.5 12h.01M4.5 18h.01',
  steps: 'M8 3c-1.7 0-3 2-3 4.5S6 12 7.5 12 10 10 10 7.5 9.7 3 8 3zM6 15h4v1.5a2 2 0 0 1-4 0zM16 7c1.7 0 3 2 3 4.5S18 16 16.5 16 14 14 14 11.5 14.3 7 16 7zM14 19h4v.5a2 2 0 0 1-4 0z',
  scan: 'M4 8V5a1 1 0 0 1 1-1h3M16 4h3a1 1 0 0 1 1 1v3M20 16v3a1 1 0 0 1-1 1h-3M8 20H5a1 1 0 0 1-1-1v-3M7 12h10',
  chev: 'M9 6l6 6-6 6', chevl: 'M15 6l-6 6 6 6', chevd: 'M6 9l6 6 6-6', user: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21a8 8 0 0 1 16 0',
  target: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM12 11.5v1',
  pause: 'M9 6v12M15 6v12', play: 'M8 5l11 7-11 7z', timer: 'M12 9v4l2.5 1.5M9 2h6M12 5a8 8 0 1 0 0 16 8 8 0 0 0 0-16z',
  pin: 'M12 21s-6-5.5-6-11a6 6 0 0 1 12 0c0 5.5-6 11-6 11zM12 8.5a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3z',
  doc: 'M6 3h9l3 3v15H6zM9 9h6M9 13h6M9 17h4', pencil: 'M4 20l4-1 11-11-3-3L5 16zM14 6l3 3',
  book: 'M5 4h12a2 2 0 0 1 2 2v14H7a2 2 0 0 1-2-2zM5 18a2 2 0 0 1 2-2h12', car: 'M3 15H2v-3l3-1 2-4h8l3 4 4 1v3h-1M9 15h6M5 15a2 2 0 1 0 4 0 2 2 0 1 0-4 0M15 15a2 2 0 1 0 4 0 2 2 0 1 0-4 0M7.5 11H18',
  circle: 'M12 3.5a8.5 8.5 0 1 0 0 17 8.5 8.5 0 0 0 0-17z', checkc: 'M12 3.5a8.5 8.5 0 1 0 0 17 8.5 8.5 0 0 0 0-17zM8 12.2l2.8 2.8L16 9.6',
  bell: 'M6 16v-5a6 6 0 0 1 12 0v5l1.5 2h-15zM10 20.5a2 2 0 0 0 4 0', trend: 'M3 17l6-6 4 4 8-8M15 7h6v6',
  bars: 'M5 20V10M12 20V4M19 20v-7', search: 'M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM20 20l-4-4', lock: 'M6 11h12v9H6zM8 11V8a4 4 0 0 1 8 0v3',
  arrow: 'M5 12h14M13 6l6 6-6 6', dots: 'M5 12h.01M12 12h.01M19 12h.01', flag: 'M5 21V4h11l-2 4 2 4H5',
  undo: 'M9 14L4 9l5-5M4 9h10a6 6 0 0 1 0 12h-3', redo: 'M15 14l5-5-5-5M20 9H10a6 6 0 0 0 0 12h3',
  eye: 'M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12zM12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6z',
  resize: 'M4 14v6h6M4 20l7-7M14 4h6v6M20 4l-7 7', lines: 'M5 7h14M5 12h14M5 17h9',
  palette: 'M12 3a9 9 0 1 0 0 18c1.5 0 2-1 2-2s-.6-1.4-.6-2.3c0-1 .8-1.7 1.8-1.7H17a4 4 0 0 0 4-4c0-4.4-4-8-9-8zM7.5 12h.01M9.5 8h.01M14 7h.01M17 10.5h.01',
  drop: 'M12 3s6 6.5 6 11a6 6 0 0 1-12 0c0-4.5 6-11 6-11z', image: 'M4 5h16v14H4zM4 16l4.5-4.5 4 4 3-3L20 17M9 9.5h.01',
  frame: 'M5 5h14v14H5zM9 9h6v6H9z', chart: 'M4 4v16h16M8 16v-4M12 16V8M16 16v-6', density: 'M4 6h16M4 10h16M4 14h16M4 18h16',
  star: 'M12 3.5l2.6 5.4 5.9.8-4.3 4.1 1 5.8L12 16.9l-5.2 2.7 1-5.8L3.5 9.7l5.9-.8z', x: 'M6 6l12 12M18 6L6 18',
  gear: 'M12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6zM19.4 13.5a7.6 7.6 0 0 0 0-3l2-1.5-2-3.4-2.3.9a7.6 7.6 0 0 0-2.6-1.5L14 2.5h-4l-.5 2.5a7.6 7.6 0 0 0-2.6 1.5l-2.3-.9-2 3.4 2 1.5a7.6 7.6 0 0 0 0 3l-2 1.5 2 3.4 2.3-.9a7.6 7.6 0 0 0 2.6 1.5l.5 2.5h4l.5-2.5a7.6 7.6 0 0 0 2.6-1.5l2.3.9 2-3.4z',
  share: 'M12 15V3M8 7l4-4 4 4M5 12v8h14v-8', trash: 'M5 7h14M10 7V4h4v3M7 7l1 13h8l1-13', copy: 'M9 9h11v11H9zM5 15H4V4h11v1',
  flame: 'M12 3c1 3 4 4.5 4 8.5a4 4 0 0 1-8 0c0-1.5.6-2.5 1.2-3.2C9.5 10 11 9 12 3zM12 21a6 6 0 0 0 6-6', moon: 'M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z',
  bolt: 'M13 3L5 13h6l-1 8 8-10h-6z', sparkles: 'M12 4l1.6 4.4L18 10l-4.4 1.6L12 16l-1.6-4.4L6 10l4.4-1.6zM18.5 15l.7 1.8 1.8.7-1.8.7-.7 1.8-.7-1.8-1.8-.7 1.8-.7z',
  crown: 'M4 18h16M4 15l-1-8 5 4 4-6 4 6 5-4-1 8z', info: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 11v5M12 8h.01',
  camera: 'M4 8h3l2-3h6l2 3h3v11H4zM12 10.5a3 3 0 1 0 0 6 3 3 0 0 0 0-6z', barcode: 'M4 6v12M7 6v12M11 6v12M14 6v12M17 6v12M20 6v12',
  heart: 'M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.5A4 4 0 0 1 19 10c0 5.6-7 10-7 10z', trophy: 'M8 4h8v5a4 4 0 0 1-8 0zM8 6H5a3 3 0 0 0 3 4M16 6h3a3 3 0 0 1-3 4M12 13v4M8 20h8',
  clock: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 7v5l3 2', plane: 'M3 11l18-7-7 18-2.5-7.5z', card: 'M3 6h18v12H3zM3 10h18M7 15h4',
  filter: 'M4 6h16M7 12h10M10 18h4', grip: 'M9 6h.01M15 6h.01M9 12h.01M15 12h.01M9 18h.01M15 18h.01', minus: 'M5 12h14',
  up: 'M12 19V5M6 11l6-6 6 6', down: 'M12 5v14M6 13l6 6 6-6', piggy: 'M4 12a7 6 0 0 1 14-1l2 1v3h-2a7 6 0 0 1-2 2v2h-3v-1h-3v1H7v-2.5A6 6 0 0 1 4 12zM9 9h4M15.5 11h.01',
  graduation: 'M2 9l10-5 10 5-10 5zM6 11.5V16c2 2 10 2 12 0v-4.5M21 9.5V15', phone: 'M8 3h8a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1H8a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1zM11 18h2',
  layers: 'M12 3l9 5-9 5-9-5zM3 13l9 5 9-5', type: 'M5 6V4h14v2M12 4v16M9 20h6', sun: 'M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM12 2v2M12 20v2M4.2 4.2l1.4 1.4M18.4 18.4l1.4 1.4M2 12h2M20 12h2M4.2 19.8l1.4-1.4M18.4 5.6l1.4-1.4',
  hand: 'M9 11V5a1.5 1.5 0 0 1 3 0v5M12 10V4a1.5 1.5 0 0 1 3 0v6M15 10V6a1.5 1.5 0 0 1 3 0v8a7 7 0 0 1-7 7c-3 0-4.5-1.5-6-4l-2-4a1.5 1.5 0 0 1 2.6-1.5L9 14',
};

/* ---------- la journée d'exemple : jeudi 12 novembre (compositions/DONNEES.md) ---------- */
const HABITS = [{ t: 'Boire 2 L d\'eau', at: 'soiree' }, { t: 'Lecture 20 min', at: 'journee' }, { t: 'Méditation', at: 'journee' }, { t: 'Vitamines', at: 'matin' }, { t: 'Coucher avant 23 h', at: null }];
const MOMENTS = ['matin', 'journee', 'soiree'];
const habDone = (m) => HABITS.map((h) => h.at != null && MOMENTS.indexOf(h.at) <= MOMENTS.indexOf(m));
const EVENTS = [ // d : 0 = lundi … 6 = dimanche ; jeudi = 3
  { d: 0, s: '09:00', t: 'Comptabilité', ty: 'cours' }, { d: 0, s: '13:00', t: 'Marketing', ty: 'cours' },
  { d: 1, s: '10:00', t: 'Statistiques', ty: 'cours' }, { d: 1, s: '18:00', t: 'Séance', ty: 'seance' },
  { d: 2, s: '09:00', t: 'Marketing', ty: 'cours' }, { d: 2, s: '13:00', t: 'Travail', ty: 'travail' },
  { d: 3, s: '09:00', t: 'Comptabilité', p: 'B-204', ty: 'cours' }, { d: 3, s: '11:30', t: 'Travail d\'équipe', p: 'Bibliothèque', ty: 'cours' },
  { d: 3, s: '14:00', t: 'Réunion projet', p: 'Local 3.12', ty: 'rdv' }, { d: 3, s: '16:30', t: 'Dentiste', ty: 'rdv' },
  { d: 3, s: '18:30', t: 'Séance Haut du corps', ty: 'seance' },
  { d: 4, s: '10:00', t: 'Statistiques', ty: 'cours' }, { d: 4, s: '13:00', e: '17:00', t: 'Travail', ty: 'travail' },
  { d: 5, s: '10:00', t: 'Séance Jambes', ty: 'seance' }];
const TODAY = 3, WEEKDAYS = ['L', 'M', 'M', 'J', 'V', 'S', 'D'], WEEKDAYS_LONG = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'], WEEKDATES = [9, 10, 11, 12, 13, 14, 15];
const TOP3 = ['Rendre le rapport de marketing', 'Appeler la banque', 'Réviser le chapitre 4'];
const REMIND = [{ t: 'Facture Internet', due: 'Demain · 45 $', i: 'doc', c: 'bud' }, { t: 'Devoir : étude de cas', due: 'Vendredi', i: 'pencil', c: 'pla' },
  { t: 'Examen : Statistiques', due: 'Lundi', i: 'book', c: 'pla' }, { t: 'Assurance auto', due: 'Mardi · 62 $', i: 'car', c: 'bud' }];
const CAL7 = { lab: ['V', 'S', 'D', 'L', 'M', 'M', 'J'], past: [2250, 2480, 2050, 2140, 2310, 1980], goal: 2200, avg: 2202 };
const SPEND7 = { lab: ['V', 'S', 'D', 'L', 'M', 'M', 'J'], past: [32, 0, 58, 12, 41, 9] };
const STEPS7 = { lab: ['V', 'S', 'D', 'L', 'M', 'M', 'J'], past: [9120, 11340, 6480, 8210, 7650, 9980], goal: 8000 };
const WORKOUT_PLANNED = { state: 'prevue', title: 'Séance du jour', prog: 'Haut du corps', meta: '6 exercices · 18 séries', cta: 'Commencer' };
const DAY = {
  date: 'Jeudi 12 novembre', avatar: 'M', kicker: 'MON QUOTIDIEN',
  matin: { time: '08:10', title: 'Ta matinée', kcal: { eaten: 420, left: 1780, goal: 2200 }, macros: { p: [24, 140], g: [52, 250], l: [12, 70] },
    meals: [['Déjeuner', 420], ['Dîner', null], ['Souper', null], ['Collation', null]], mealsN: 1, next: 'dîner, environ 650 kcal',
    workout: { ...WORKOUT_PLANNED, badge: null }, week: { done: [0, 1], n: 2, goal: 4, left: 2 }, habits: { done: 1, total: 5, streak: 12 },
    budget: { perDay: 22.45, today: 0, left: 426.50 }, steps: { n: 1240, goal: 8000 }, top3: 0 },
  journee: { time: '13:20', title: 'Ta journée', kcal: { eaten: 1078, left: 1122, goal: 2200 }, macros: { p: [68, 140], g: [121, 250], l: [34, 70] },
    meals: [['Déjeuner', 420], ['Dîner', 658], ['Souper', null], ['Collation', null]], mealsN: 2, next: 'souper, environ 700 kcal',
    workout: { ...WORKOUT_PLANNED, badge: 'Maintenant' }, week: { done: [0, 1], n: 2, goal: 4, left: 2 }, habits: { done: 3, total: 5, streak: 12 },
    budget: { perDay: 21.68, today: 14.50, left: 412, month: 788, monthGoal: 1200 }, steps: { n: 5480, goal: 8000 }, top3: 1 },
  soiree: { time: '19:05', title: 'Ta soirée', kcal: { eaten: 1520, left: 680, goal: 2200 }, macros: { p: [96, 140], g: [168, 250], l: [46, 70] },
    meals: [['Déjeuner', 420], ['Dîner', 658], ['Souper', null], ['Collation', 442]], mealsN: 3, next: 'souper, environ 680 kcal',
    workout: { state: 'encours', title: 'Séance en cours', prog: 'Haut du corps', ex: 'Développé couché', set: 2, sets: 4, reps: '10 × 60 kg', rest: '0:45', cta: 'Série faite' },
    week: { done: [0, 1], n: 2, goal: 4, left: 2 }, habits: { done: 4, total: 5, streak: 12 },
    budget: { perDay: 21.68, today: 14.50, left: 412, month: 788, monthGoal: 1200 }, steps: { n: 7360, goal: 8000 }, top3: 2 },
};
const KIT = 'file:///C:/Users/Etudiant/ardane-tools/film/public/kit2026/fr/';

/* ---------- utilitaires ---------- */
const U = {
  n: (x) => Math.round(x).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' '),
  money: (x) => (Number.isInteger(x) ? U.n(x) : x.toFixed(2).replace('.', ',').replace(/\B(?=(\d{3})+(?!\d),)/g, ' ')) + ' $',
  ico: (n) => `<i data-i="${n}"></i>`,
  get: (path) => path.split('.').reduce((o, k) => (o == null ? o : o[k]), DAY),
  min: (hhmm) => { const [h, m] = hhmm.split(':').map(Number); return h * 60 + m; },
  ring(p, sw = 10) { const r = 50 - sw / 2, c = 2 * Math.PI * r;
    return `<svg class="u-ring" viewBox="0 0 100 100"><circle class="t" cx="50" cy="50" r="${r}" stroke-width="${sw}"/>`
      + (p > 0 ? `<circle class="v" cx="50" cy="50" r="${r}" stroke-width="${sw}" stroke-dasharray="${(c * Math.min(p, 1)).toFixed(1)} ${c.toFixed(1)}"/>` : '') + '</svg>'; },
  meter: (p) => `<span class="u-meter"><i style="width:${(Math.min(p, 1) * 100).toFixed(1)}%"></i></span>`,
  bars(vals, o = {}) { const max = o.max || Math.max(...vals, o.goal || 0) * 1.08, today = o.today ?? vals.length - 1;
    const goal = o.goal ? `<span class="goal" style="bottom:${(o.goal / max * 100).toFixed(1)}%"></span>` : '';
    return `<div class="u-bars">${goal}${vals.map((v, k) => `<span class="b${k === today ? ' is-today' : ''}"><i style="height:${Math.max(v / max * 100, v ? 2 : 0).toFixed(1)}%"></i></span>`).join('')}</div>`; },
  barsLab: (lab, today = lab.length - 1) => `<div class="u-bars-lab">${lab.map((l, k) => `<span class="${k === today ? 'is-today' : ''}">${l}</span>`).join('')}</div>`,
  spark(vals, o = {}) { const w = o.w || 140, h = o.h || 40, pad = 4, max = Math.max(...vals) || 1, step = (w - 2 * pad) / (vals.length - 1);
    const pts = vals.map((v, k) => [pad + k * step, h - pad - v / max * (h - 2 * pad)]), d = pts.map((p, k) => (k ? 'L' : 'M') + p[0].toFixed(1) + ' ' + p[1].toFixed(1)).join(' ');
    const last = pts[pts.length - 1];
    return `<svg class="u-spark" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><path class="a" d="${d} L${last[0].toFixed(1)} ${h} L${pad} ${h} Z"/><path class="l" d="${d}"/><circle class="d" cx="${last[0].toFixed(1)}" cy="${last[1].toFixed(1)}" r="3.5"/></svg>`; },
  // Grille de la semaine. o.from/o.to (heures), o.every, o.focus (jour élargi), o.labels 'all'|'focus'|'none', o.time, o.sub, o.now ('13:20'), o.long.
  week(o = {}) { const from = o.from ?? 8, to = o.to ?? 20, span = (to - from) * 60, every = o.every ?? 2, labels = o.labels ?? 'all';
    const y = (t) => ((U.min(t) - from * 60) / span * 100).toFixed(2);
    const cols = o.focus != null ? Array.from({ length: 7 }, (_, k) => k === o.focus ? `${o.fw || 2.6}fr` : '1fr').join(' ') : 'repeat(7, 1fr)';
    let h = `<div class="u-week" style="--wk-cols:${cols}"><span></span>`;
    h += (o.long ? WEEKDAYS_LONG : WEEKDAYS).map((d, k) => `<span class="hd${k === TODAY ? ' is-today' : ''}">${d}</span>`).join('');
    h += `<div class="gut">${Array.from({ length: Math.floor((to - from) / every) + 1 }, (_, k) => from + k * every).filter((x) => x < to).map((x) => `<span style="top:${y(String(x).padStart(2, '0') + ':00')}%">${x}</span>`).join('')}</div>`;
    for (let d = 0; d < 7; d++) { h += `<div class="col${d === TODAY ? ' is-today' : ''}">`;
      for (let x = from; x <= to; x += every) h += `<span class="ln" style="top:${y(String(x).padStart(2, '0') + ':00')}%"></span>`;
      EVENTS.filter((e) => e.d === d).forEach((e) => { const end = e.e || (String(Math.floor(U.min(e.s) / 60) + 1).padStart(2, '0') + e.s.slice(2));
        const show = labels === 'all' || (labels === 'focus' && d === o.focus);
        h += `<div class="ev" data-ev="${e.ty}" style="top:${y(e.s)}%;height:calc(${(y(end) - y(e.s)).toFixed(2)}% - 1px)">`
          + (show ? `<b>${o.time ? e.s + ' ' : ''}${e.t}</b>${o.sub ? `<small>${e.s}${e.e ? '–' + e.e : ''}${e.p ? ' · ' + e.p : ''}</small>` : ''}` : '') + '</div>'; });
      if (o.now && d === TODAY) h += `<span class="now" style="top:${y(o.now)}%"></span>`;
      h += '</div>'; }
    return h + '</div>'; },
  dots7: (done = [0, 1], letters = true) => `<div class="u-dots">${WEEKDAYS.map((d, k) => `<span class="${done.includes(k) ? 'is-done' : ''}${k === TODAY ? ' is-today' : ''}"><i>${done.includes(k) ? U.ico('check') : ''}</i>${letters ? d : ''}</span>`).join('')}</div>`,
  hab: (m) => `<div class="u-hab">${habDone(m).map((d) => `<span class="${d ? 'is-done' : ''}">${d ? U.ico('check') : ''}</span>`).join('')}</div>`,
  // Sélecteur de semaine de l'app. o.sel = jour choisi (0 à 6), o.title, o.marks = jours portant un repère (fait, prévu).
  wsel(o = {}) { const sel = o.sel ?? TODAY, marks = o.marks || [];
    return `<div class="wsel ${o.cls || 'gl'}"><div class="wh">${U.ico('chevl')}<span>${o.title || 'Cette semaine'}</span>${U.ico('chev')}</div><div class="wd">${WEEKDAYS.map((d, k) =>
      `<span class="d ${k === sel ? 'on' : k === TODAY ? 'today' : k < TODAY ? 'past' : 'next'}${marks.includes(k) ? ' mk' : ''}">${d}<b>${WEEKDATES[k]}</b><u></u></span>`).join('')}</div></div>`; },
  upcoming: (m, n = 5) => { const t = U.min(DAY[m].time); return EVENTS.filter((e) => e.d === TODAY && U.min(e.s) >= t).concat(EVENTS.filter((e) => e.d === TODAY + 1)).slice(0, n); },
};

/* ---------- écrans générés ---------- */
const Screens = {
  // Accueil « Équilibrée » (référence validée par l'utilisateur : Cristal, composition A, 13 h 20).
  homeA(m = 'journee') { const d = DAY[m], k = d.kcal, mc = d.macros, w = d.workout, pc = (a) => (a[0] / a[1]).toFixed(3);
    const seance = w.state === 'encours'
      ? `<article class="gl mn" data-c="fit"><header class="ch"><span class="ico">${U.ico('dumbbell')}</span><span class="nb" style="margin-left:auto">Maintenant</span></header>
          <div class="s" style="margin-top:4px;font-weight:600">${w.title}</div><div class="h3" style="margin-top:1px">${w.ex}</div><div class="s tn">Série ${w.set}/${w.sets} · ${w.reps}</div>
          <div class="btnP">${U.ico('check')}${w.cta}</div></article>`
      : `<article class="${w.badge ? 'gl' : 'pn'} mn" data-c="fit"><header class="ch"><span class="ico">${U.ico('dumbbell')}</span>${w.badge ? `<span class="nb" style="margin-left:auto">${w.badge}</span>` : `<b>Séance</b><i class="go" data-i="chev"></i>`}</header>
          <div class="s" style="margin-top:4px;font-weight:600">${w.title}</div><div class="h3" style="margin-top:1px">${w.prog}</div><div class="s">${w.meta}</div>
          <div class="btnP">${U.ico('play')}${w.cta}</div></article>`;
    return `<div class="x-top gl"><span class="x-date">${DAY.date}</span><span class="x-ava">${DAY.avatar}</span></div>
      <div class="x-kick">${DAY.kicker}</div><div class="x-title">${d.title}</div>
      <div class="x-stack" style="margin-top:10px">
        <article class="pn cd" data-c="nut">
          <header class="ch"><span class="ico">${U.ico('fork')}</span><b>Nutrition</b><span class="pg"><i class="on"></i><i></i><i></i></span><i class="go" data-i="chev"></i></header>
          <div style="display:grid;grid-template-columns:90px 1fr;gap:18px;align-items:center;margin:6px 0 10px">
            <div class="rgw" style="width:90px;height:90px">${U.ring(k.eaten / k.goal, 9)}<div class="in"><b>${U.n(k.left)}</b><small>kcal<br>restantes</small></div></div>
            <div class="mac">
              <div data-c="prot"><span>Protéines</span><em>${mc.p[0]}/${mc.p[1]} g</em>${U.meter(pc(mc.p))}</div>
              <div data-c="gluc"><span>Glucides</span><em>${mc.g[0]}/${mc.g[1]} g</em>${U.meter(pc(mc.g))}</div>
              <div data-c="lip"><span>Lipides</span><em>${mc.l[0]}/${mc.l[1]} g</em>${U.meter(pc(mc.l))}</div>
            </div></div>
          <div style="display:grid;grid-template-columns:1fr auto;gap:10px;align-items:center"><div class="btnT">${U.ico('scan')}Scanner</div>
            <span class="s" style="font-weight:650;color:var(--ink);padding-right:6px">${d.mealsN} repas</span></div>
        </article>
        <div class="g2" style="height:168px">${seance}
          <article class="pn hc" data-c="hab"><header class="ch"><span class="ico">${U.ico('repeat')}</span><b>Habitudes</b><i class="go" data-i="chev"></i></header>
            <div style="margin-top:8px">${U.hab(m)}</div><div class="big" style="margin-top:8px">${d.habits.done}<small>/${d.habits.total}</small></div>
            <div class="s">faites aujourd'hui</div><div class="s" style="margin-top:auto;font-weight:600;color:var(--ink)">Série de ${d.habits.streak} jours</div></article>
        </div>
        <div class="g2" style="height:180px">
          <article class="pn hc" data-c="pla"><header class="ch"><span class="ico">${U.ico('calendar')}</span><b>Planning</b><i class="go" data-i="chev"></i></header>
            <div class="wk0" style="--wk-h:82px;--wk-gap:2px;--wk-head:16px;margin:6px 0">${U.week({ labels: 'none', now: d.time, every: 2 })}</div>
            <span class="link" style="margin-top:auto">Toute la semaine</span></article>
          <article class="pn hc" data-c="bud"><header class="ch"><span class="ico">${U.ico('wallet')}</span><b>Budget</b><i class="go" data-i="chev"></i></header>
            <div class="big" style="margin-top:8px">${U.money(d.budget.perDay)}</div><div class="s">à dépenser par jour d'ici la fin du mois</div>
            <div style="margin-top:auto">${U.spark(SPEND7.past.concat(d.budget.today), { w: 140, h: 40 })}</div></article>
        </div>
      </div>`; },
};

/* ---------- fiche de palette d'un thème ---------- */
function paletteHtml(id, mode) { const t = THEMES.find((x) => x.id === id), k = tokens(t), sw = (c, l) => `<div class="sw"><u style="background:${c}"></u>${l}<code>${c}</code></div>`;
  const main = sw(k.primary, 'Principale') + sw(k.secondary, 'Secondaire') + sw(k.accent, 'Accentuation') + sw(k.bg, 'Arrière-plan') + sw(k.na, 'Nappe 1') + sw(k.nb, 'Nappe 2') + sw(k.panelSolid, 'Panneau');
  if (mode === 'short') return `<div class="sws">${main}</div>`;
  return `<div class="sws">${main}${sw(k.ink, 'Encre')}${sw(k.ink2, 'Encre secondaire')}${sw(k.rule, 'Filet')}${sw(k.track, 'Piste des jauges')}`
    + sw(k.cats.nut, 'Nutrition') + sw(k.cats.fit, 'Fitness') + sw(k.cats.pla, 'Planning') + sw(k.cats.hab, 'Habitudes') + sw(k.cats.bud, 'Finances') + sw(k.cats.pro, 'Top 3') + sw(k.cats.pas, 'Pas')
    + sw(k.cats.prot, 'Protéines') + sw(k.cats.gluc, 'Glucides') + sw(k.cats.lip, 'Lipides') + '</div>'; }

/* ---------- montage ---------- */
const Cristal = {
  init() {
    const q = new URLSearchParams(location.search);
    if (q.get('y')) { document.documentElement.style.overflow = 'hidden'; document.body.style.marginTop = (-q.get('y')) + 'px'; }   // rendu par bandes (render.py)
    if (q.get('t')) document.querySelectorAll('.phone, body, main, .col, .row').forEach((el) => { el.className = el.className.split(' ').map((c) => (/^t-[a-z]+$/.test(c) ? 't-' + q.get('t') : c)).join(' '); });
    if (q.get('mode') === 'dark') document.querySelectorAll('.phone, .spec').forEach((el) => el.classList.add('dk'));
    document.querySelectorAll('[data-screen]').forEach((ph) => { const [fn, arg] = ph.dataset.screen.split(':');
      ph.innerHTML = `<div class="scr">${Screens[fn](arg)}</div>`; if (!ph.dataset.time && arg) ph.dataset.time = DAY[arg].time; if (!ph.dataset.time) ph.dataset.time = DAY.journee.time; });
    document.querySelectorAll('[data-pal]').forEach((el) => { el.innerHTML = paletteHtml(el.dataset.pal, el.dataset.mode); });
    document.querySelectorAll('.phone').forEach((ph) => { if (q.has('w375')) ph.classList.add('w375');
      ph.insertAdjacentHTML('afterbegin', `<div class="sb"><span>${ph.dataset.time || '9:41'}</span><div class="isl"></div><span class="rt"><span class="sig"><span style="height:4px"></span><span style="height:6px"></span><span style="height:8px"></span><span style="height:11px"></span></span><span class="bat"></span></span></div>`);
      const on = ph.dataset.tab == null ? 0 : ph.dataset.tab;
      const tabs = [['home', 'Accueil'], ['plusbox', 'Créer'], ['bag', 'Store'], ['grid', 'Mes widgets']].map(([i, l], k) => `<div class="ti${String(k) === String(on) ? ' on' : ''}">${U.ico(i)}<span>${l}</span></div>`).join('');
      ph.insertAdjacentHTML('beforeend', `${on === 'none' ? '' : `<div class="edge"></div><nav class="tabbar">${tabs}</nav>`}<div class="hi"></div>`); });
    document.querySelectorAll('[data-u]').forEach((el) => { const d = el.dataset, m = d.m || 'journee', o = d.o ? JSON.parse(d.o) : {};
      if (d.u === 'ring') el.innerHTML = U.ring(+d.p, +(d.sw || 10));
      else if (d.u === 'meter') el.innerHTML = U.meter(+d.p);
      else if (d.u === 'week') el.innerHTML = U.week(o);
      else if (d.u === 'wsel') el.outerHTML = U.wsel(o);
      else if (d.u === 'dots7') el.innerHTML = U.dots7(o.done || DAY[m].week.done, d.letters !== 'no');
      else if (d.u === 'hab') el.innerHTML = U.hab(m);
      else if (d.u === 'bars') { const s = { spend7: SPEND7, steps7: STEPS7, cal7: CAL7 }[d.set || 'cal7'];
        const v = d.vals ? JSON.parse(d.vals) : s.past.concat(d.set === 'spend7' ? DAY[m].budget.today : d.set === 'steps7' ? DAY[m].steps.n : DAY[m].kcal.eaten);
        el.innerHTML = U.bars(v, { goal: d.vals ? 0 : (s.goal || 0), ...o }) + (d.lab === 'no' ? '' : U.barsLab(o.lab || s.lab)); }
      else if (d.u === 'spark') el.innerHTML = U.spark(d.vals ? JSON.parse(d.vals) : SPEND7.past.concat(DAY[m].budget.today), { w: +(d.w || 140), h: +(d.h || 40) }); });
    document.querySelectorAll('[data-v]').forEach((el) => { const v = U.get(el.dataset.v); el.textContent = typeof v === 'number' ? (/budget|money/.test(el.dataset.v) ? U.money(v) : U.n(v)) : v; });
    document.querySelectorAll('img[data-w]').forEach((im) => { im.src = KIT + im.dataset.w + '.png'; });
    document.querySelectorAll('.flow').forEach((f) => { if (!f.innerHTML) f.innerHTML = '<svg viewBox="0 0 40 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12h32M26 4l9 8-9 8"/></svg>'; });
    document.querySelectorAll('i[data-i]').forEach((e) => { e.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round"><path d="${P[e.dataset.i] || ''}"/></svg>`; });
    if (q.has('check')) document.fonts.ready.then(() => document.querySelectorAll('.scr *, .sheet *').forEach((el) => { const cs = getComputedStyle(el);
      if (cs.display === 'inline' || !el.textContent.trim()) return; const host = el.closest('.scr, .sheet').getBoundingClientRect(), r = el.getBoundingClientRect();
      const cut = el.scrollWidth > el.clientWidth + 1 && (cs.overflow !== 'visible' || el.children.length === 0);
      const box = el.closest('.pn, .gl'), out = box && r.right > box.getBoundingClientRect().right + 1;
      if (cut || out || (r.right > host.right + 1 && !el.closest('.chips, .tools, .thumbs'))) el.style.outline = '2px solid red'; }));
    if (q.has('boxes') || q.has('dump')) { const o = { w: document.documentElement.scrollWidth, h: document.documentElement.scrollHeight, phones: [...document.querySelectorAll('.phone')].map((p, k) => { const r = p.getBoundingClientRect();
        return { k, id: p.dataset.id || '', x: Math.round(r.left + scrollX), y: Math.round(r.top + scrollY), w: Math.round(r.width), h: Math.round(r.height) }; }) };
      if (q.has('dump')) o.themes = THEMES.map((t) => { const k = tokens(t); return { id: t.id, name: t.name, sub: t.sub, app: t.app, isNew: !!t.isNew, free: !!t.free, ...k,
        cr: { blancSurPrincipale: +C.cr('#FFFFFF', k.primary).toFixed(2), encreSurPanneau: +C.cr(k.ink, k.panelSolid).toFixed(2), encre2SurPanneau: +C.cr(k.ink2, k.panelSolid).toFixed(2), encre2SurFond: +C.cr(k.ink2, k.bg).toFixed(2), principaleSurPanneau: +C.cr(k.primary, k.panelSolid).toFixed(2), principaleSurTeinte: +C.cr(k.primary, k.tint2).toFixed(2), accentSurPanneau: +C.cr(k.accent, k.panelSolid).toFixed(2) } }; });
      document.body.insertAdjacentHTML('beforeend', `<pre id="boxes" style="display:none">${JSON.stringify(o)}</pre>`); }
  },
};
