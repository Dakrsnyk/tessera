// cristal_reference.js : la formule des jetons Cristal pour les 12 couleurs de l'app, telle que le code Swift doit la reproduire
// (Shared/Theme/CristalPalette.swift). Écrit Tests/CristalPaletteReference.swift, que les tests comparent au calcul Swift.
// Usage, depuis la racine du dépôt : node docs/design/2026-11-15-cristal/cristal_reference.js
//
// Règles (décidées le 2026-11-15) :
// - Chaque couleur de l'app prend la « graine » d'une déclinaison dessinée (THEMES de cristal.js) : fonds, nappes, encres, filets.
// - Teinte principale d'une déclinaison : sa couleur d'action est celle de la maquette. Teinte rattachée : son accent clair, assombri
//   jusqu'à 4,6:1 sur sa propre teinte (comme les couleurs dessinées).
// - En sombre, le fond, la carte, l'accent et l'encre sur l'accent sont ceux d'AppStyle (rien ne change pour les Live Activities).
const fs = require('fs');
const path = require('path');
const here = __dirname;
const src = fs.readFileSync(path.join(here, 'cristal.js'), 'utf8');
const doc = { head: { insertAdjacentHTML() {} }, documentElement: { style: {} }, body: { style: {} }, querySelectorAll() { return []; } };
const { THEMES, tokens, C, CATS0 } = new Function('document', 'location', src + ';return {THEMES,tokens,C,CATS0};')(doc, { search: '' });

// Les 12 couleurs de l'app (Shared/Theme/AppStyle.swift) : accent clair, accent sombre, graine, teinte principale de la graine ?
const APP = [
  ['cobalt', '244FC1', '7094FF', 'ocean', false], ['sapphire', '245B8F', '68B5F5', 'saphir', true], ['iceBlue', '398FA8', '75DDF5', 'saphir', false],
  ['aqua', '008C95', '45DDE0', 'ocean', true], ['jade', '268577', '65D5BC', 'foret', true], ['pistachio', '718C42', 'B8D987', 'sauge', true],
  ['olive', '77752B', 'C7C36A', 'sauge', false], ['amber', 'B86A13', 'FFB454', 'peche', true], ['ruby', 'C62845', 'FF6B81', 'rose', false],
  ['rose', 'C04472', 'FF83B2', 'rose', true], ['orchid', '9854B8', 'D5A0F5', 'lavande', false], ['amethyst', '6841A5', 'B69AFF', 'lavande', true],
];
const KEYS = ['nut', 'fit', 'pla', 'hab', 'bud', 'pro', 'pas', 'prot', 'gluc', 'lip', 'travail', 'rdv'];
// assombrit une couleur jusqu'à ce qu'elle se lise sur sa propre teinte (onglet actif, bouton teinté)
const fitSelf = (h) => { let k = 0; while (C.cr(h, C.mix(h, '#FFFFFF', .86)) < 4.6 && k++ < 40) h = C.mix(h, '#000000', 0.05); return h; };

function palette([id, light, dark, seedId, main]) {
  const seed = THEMES.find((t) => t.id === seedId), primary = main ? seed.primary : fitSelf('#' + light);
  const L = tokens({ ...seed, primary });
  const hue = C.hsl('#' + light).h, bg = C.fromHsl(hue, .45, .055), card = C.fromHsl(hue, .35, .115), dPrimary = '#' + dark;
  const darkInk = C.fromHsl(hue, .5, .07), onPrimary = C.cr(darkInk, dPrimary) >= C.cr('#FFFFFF', dPrimary) ? darkInk : '#FFFFFF';   // l'encre la plus lisible (AppStyle met du blanc sur Cobalt et Rubis : 2,8:1)
  const ink = C.mix('#FFFFFF', dPrimary, .05), ink2 = C.mix(ink, card, .36);
  const cat = (k) => C.lift(C.mix(C.mix(CATS0[k], primary, seed.cat || 0), '#FFFFFF', .16), card, 5.0);
  const D = { bg, na: C.mix(bg, seed.secondary, .32), nb: C.mix(bg, primary, .46), ink, ink2, rule: C.mix(card, '#FFFFFF', .10), rule2: C.mix(card, '#FFFFFF', .22),
    primary: dPrimary, onPrimary, secondary: C.lift(seed.secondary, card, 4.5), accent: C.lift(seed.accent, card, 4.5), tint: C.mix(card, dPrimary, .13), tint2: C.mix(card, dPrimary, .19),
    track: C.mix(card, '#FFFFFF', .13), grid: C.mix(card, '#FFFFFF', .07), go: C.mix(ink2, card, .35), dot: C.mix(card, '#FFFFFF', .24), panelSolid: card, sheet: C.mix(card, '#FFFFFF', .03),
    well: C.mix(bg, '#FFFFFF', .06), well2: C.mix(bg, dPrimary, .10), ok: '#5FD3A0', cats: {}, cs: {} };
  KEYS.forEach((k) => { D.cats[k] = cat(k); D.cs[k] = D.cats[k]; });
  const light_ = { bg: L.bg, na: L.na, nb: L.nb, ink: L.ink, ink2: L.ink2, rule: L.rule, rule2: L.rule2, primary: L.primary, onPrimary: L.onPrimary, secondary: L.secondary, accent: L.accent,
    tint: L.tint, tint2: L.tint2, track: L.track, grid: L.grid, go: L.go, dot: L.dot, panelSolid: L.panelSolid, sheet: L.sheet, well: L.well, well2: L.well2, ok: L.ok, cats: L.cats, cs: L.cs };
  return { id, seed: seedId, light: light_, dark: D };
}

const FIELDS = ['bg', 'na', 'nb', 'ink', 'ink2', 'rule', 'rule2', 'primary', 'onPrimary', 'secondary', 'accent', 'tint', 'tint2', 'track', 'grid', 'go', 'dot', 'panelSolid', 'sheet', 'well', 'well2', 'ok'];
const hx = (h) => h.replace('#', '').toUpperCase();
const row = (p) => FIELDS.map((f) => `"${f}": "${hx(p[f])}"`).concat(KEYS.map((k) => `"cat.${k}": "${hx(p.cats[k])}"`), KEYS.map((k) => `"strong.${k}": "${hx(p.cs[k])}"`)).join(', ');
const all = APP.map(palette);
const out = `// Fichier écrit par docs/design/2026-11-15-cristal/cristal_reference.js : ne pas modifier à la main.
// Les jetons Cristal attendus pour les 12 couleurs de l'app, en clair et en sombre, calculés par la formule des maquettes.
// CristalPaletteTests compare le calcul Swift (Shared/Theme/CristalPalette.swift) à cette table.

enum CristalPaletteReference {
    /// Clé : « <couleur de l'app>.<light|dark> ». Valeur : jeton → HEX sans dièse.
    static let tokens: [String: [String: String]] = [
${all.map((p) => `        "${p.id}.light": [${row(p.light)}],\n        "${p.id}.dark": [${row(p.dark)}],`).join('\n')}
    ]

    /// La graine (déclinaison dessinée) attendue pour chaque couleur de l'app.
    static let seeds: [String: String] = [${all.map((p) => `"${p.id}": "${p.seed}"`).join(', ')}]
}
`;
const dest = path.join(here, '..', '..', '..', 'Tests', 'CristalPaletteReference.swift');
if (process.argv.includes('--print')) {
  const cr = (a, b) => C.cr(a, b).toFixed(2);
  all.forEach((p) => { const l = p.light, d = p.dark;
    console.log(p.id.padEnd(10), p.seed.padEnd(8), 'clair', l.primary, 'blanc/act', cr('#FFFFFF', l.primary), 'act/teinte', cr(l.primary, l.tint2), 'encre2/fond', cr(l.ink2, l.bg),
      'min cat', Math.min(...KEYS.map((k) => +cr(l.cats[k], l.panelSolid))).toFixed(2), 'min fort', Math.min(...KEYS.map((k) => +cr(l.cs[k], '#FFFFFF'))).toFixed(2),
      '| sombre', d.primary, 'sur/act', cr(d.onPrimary, d.primary), 'encre2/carte', cr(d.ink2, d.panelSolid), 'act/carte', cr(d.primary, d.panelSolid), 'act/teinte', cr(d.primary, d.tint2),
      'min cat', Math.min(...KEYS.map((k) => +cr(d.cats[k], d.panelSolid))).toFixed(2)); });
} else {
  fs.writeFileSync(dest, out);
  console.log('écrit', dest, all.length, 'couleurs');
}
