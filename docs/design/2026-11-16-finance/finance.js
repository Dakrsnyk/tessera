/* finance.js : données d'exemple et composants des planches « Refonte de Finance » (2026-11-16).
   À charger après ../2026-11-15-cristal/cristal.js et avant le script de la planche. Ne modifie pas cristal.js : il ajoute des icônes à P
   et un objet F (données FIN, mise en forme, graphiques SVG, lignes de liste, morceaux d'écran).
   Une seule journée d'exemple, celle des planches Cristal : jeudi 12 novembre 2026, 13 h 20, budget 1 200 $, 788 $ dépensés, 412 $ restants,
   21,68 $ par jour pendant 19 jours, 14,50 $ aujourd'hui, compte chèques 1 846,20 $. Tous les chiffres ci-dessous en découlent. */

Object.assign(P, {
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
  pill: 'M10.5 20.5l10-10a5 5 0 0 0-7-7l-10 10a5 5 0 0 0 7 7zM8.5 8.5l7 7', shirt: 'M8 3l-5 3 2 5 2-1v11h10V10l2 1 2-5-5-3a4 4 0 0 1-8 0z',
  coffee: 'M5 8h12v6a5 5 0 0 1-5 5h-2a5 5 0 0 1-5-5zM17 10h1.5a2.5 2.5 0 0 1 0 5H17M8 3v2M12 3v2', cart: 'M3 4h2l2.5 11h11L21 7H6.2M9 20h.01M17 20h.01',
  sparkle: 'M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z', bulb: 'M9 18h6M10 21h4M12 3a6 6 0 0 0-3.5 10.9c.6.5 1 1.2 1 2.1h5c0-.9.4-1.6 1-2.1A6 6 0 0 0 12 3z',
  swipe: 'M4 12h12M12 8l4 4-4 4M20 5v14', keypad: 'M6 5h.01M12 5h.01M18 5h.01M6 11h.01M12 11h.01M18 11h.01M6 17h.01M12 17h.01M18 17h.01',
  flag2: 'M5 21V4h11l-2 4 2 4H5', percent: 'M19 5L5 19M7.5 6a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3zM16.5 15a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3z',
});

const NB = ' ';
const F = {
  /* ---------- mise en forme (français du Canada) ---------- */
  n(x, dec = 0) { const s = Math.abs(x).toFixed(dec).split('.'); return s[0].replace(/\B(?=(\d{3})+(?!\d))/g, NB) + (dec ? ',' + s[1] : ''); },
  m(x, dec) { if (dec == null) dec = Number.isInteger(Math.round(x * 100) / 100) ? 0 : 2; return (x < 0 ? '−' : '') + F.n(x, dec) + NB + '$'; },
  m2: (x) => F.m(x, 2),
  out: (x, dec = 2) => '−' + F.n(x, dec) + NB + '$',
  inc: (x, dec = 2) => '+' + F.n(x, dec) + NB + '$',
  pct: (p) => Math.round(p * 100) + NB + '%',
  ico: (n) => `<i data-i="${n}"></i>`,
  col: (hex) => C.fit(hex, '#FFFFFF', 3.2),
};

/* ---------- les données ---------- */
const FIN = {
  day: 12, month: 'Novembre 2026', monthS: 'novembre', days: 30, dow0: 6,      // 1er novembre 2026 = dimanche (index 6 dans L…D)
  budget: 1200, spent: 788, left: 412, perDay: 21.68, daysLeft: 19, today: 14.5, income: 1150, kept: 362,
  balance: 1846.2, opening: 1484.2, prevSameDate: 884,
  billsSoon: 193.98, afterBills: 218.02, perDayAfterBills: 11.47,            // NOUVEAU : 412 − 193,98 de factures d'ici le 26 ; ÷ 19 jours
  // catégories : couleurs réelles de l'app (BudgetState.defaultCategories) ; v = novembre au 12 ; prev = octobre au 12 ; m6 = juin → novembre (au 12)
  cats: [
    { k: 'epi', n: 'Épicerie', i: 'cart', hex: '#1E9E75', v: 295, lim: 500, prev: 318, m6: [402, 455, 418, 371, 436, 295] },
    { k: 'mai', n: 'Maison', i: 'home', hex: '#B7791F', v: 120, lim: 150, prev: 160, m6: [140, 210, 130, 96, 188, 120] },
    { k: 'res', n: 'Restos', i: 'fork', hex: '#F06A3C', v: 118, lim: 200, prev: 96, m6: [168, 190, 175, 152, 171, 118] },
    { k: 'tra', n: 'Transport', i: 'bus', hex: '#3366FF', v: 106, lim: 150, prev: 106, m6: [131, 128, 140, 126, 133, 106] },
    { k: 'aut', n: 'Autre', i: 'grid', hex: '#64748B', v: 75, lim: 0, prev: 84, m6: [118, 96, 210, 175, 112, 75] },
    { k: 'sor', n: 'Sorties', i: 'ticket', hex: '#8C6CFF', v: 74, lim: 150, prev: 120, m6: [161, 181, 107, 170, 170, 74] },
  ],
  // dépenses par jour du 1er au 12 novembre (somme 788) et cumul ; octobre cumulé (31 jours, 884 au 12, 1 210 à la fin)
  daily: [200, 130.5, 88, 63, 140, 32, 0, 58, 12, 41, 9, 14.5],
  octCum: [150, 290, 380, 450, 590, 640, 700, 760, 790, 830, 860, 884, 905, 930, 960, 980, 1000, 1030, 1050, 1070, 1090, 1110, 1120, 1135, 1150, 1160, 1175, 1185, 1195, 1205, 1210],
  // opérations (les plus récentes d'abord). a < 0 = dépense, a > 0 = revenu. d = jour de novembre.
  ops: [
    { d: 12, t: 'Café et sandwich', c: 'res', a: -14.5, ap: true, rev: true, h: '12:41' },
    { d: 11, t: 'Billet d\'autobus', c: 'tra', a: -9 },
    { d: 10, t: 'IGA', c: 'epi', a: -41, ap: true },
    { d: 9, t: 'Cinéma', c: 'sor', a: -12 },
    { d: 8, t: 'Quincaillerie', c: 'mai', a: -58 },
    { d: 6, t: 'Bar avec Léa', c: 'sor', a: -32, ap: true },
    { d: 5, t: 'Salaire', a: 1150, fixed: true },
    { d: 5, t: 'Metro', c: 'epi', a: -87, ap: true },
    { d: 5, t: 'Vêtements', c: 'aut', a: -53 },
    { d: 4, t: 'Restaurant', c: 'res', a: -41 },
    { d: 4, t: 'Pharmacie', c: 'aut', a: -22 },
    { d: 3, t: 'Sushi', c: 'res', a: -58 },
    { d: 3, t: 'Spectacle', c: 'sor', a: -30 },
    { d: 2, t: 'IGA', c: 'epi', a: -64 },
    { d: 2, t: 'Ikea', c: 'mai', a: -62 },
    { d: 2, t: 'Café', c: 'res', a: -4.5 },
    { d: 1, t: 'Passe d\'autobus', c: 'tra', a: -97, fixed: true },
    { d: 1, t: 'Costco', c: 'epi', a: -103 },
  ],
  // factures et abonnements (Bill) : prochaines échéances après le 12 novembre ; 6 factures = 210,97 $ par mois, abonnements 68,97 $
  bills: [
    { t: 'Internet', i: 'wifi', a: 45, due: 13, when: 'Demain', dow: 'ven.' },
    { t: 'Assurance auto', i: 'shield', a: 62, due: 17, when: 'Dans 5 jours', dow: 'mar.' },
    { t: 'Forfait cellulaire', i: 'phone', a: 35, due: 20, when: 'Dans 8 jours', dow: 'ven.' },
    { t: 'Spotify', i: 'music', a: 11.99, due: 22, when: 'Dans 10 jours', dow: 'dim.', sub: true },
    { t: 'Salle de sport', i: 'dumbbell', a: 39.99, due: 25, when: 'Dans 13 jours', dow: 'mer.', sub: true },
    { t: 'Netflix', i: 'tv', a: 16.99, due: 3, mo: 'déc.', when: 'Dans 21 jours', dow: 'jeu.', sub: true },
  ],
  billsMonthly: 210.97, subsMonthly: 68.97,
  // revenus et dépenses fixes (MoneyItem, page « Revenus et dépenses fixes »)
  fixed: [{ t: 'Salaire', a: 1150, per: 'par mois · le 5', inc: true, i: 'bank' }, { t: 'Passe d\'autobus', a: 97, per: 'par mois · le 1er', i: 'bus' }],
  quick: [{ t: 'Café', a: 4.5, c: 'res', i: 'coffee' }, { t: 'Autobus', a: 3.75, c: 'tra', i: 'bus' }, { t: 'Lunch', a: 14, c: 'res', i: 'fork' }],
  // épargne : objectifs (SavingsGoal), comptes saisis à la main (Account), valeur nette (netWorthHistory)
  goals: [{ t: 'Voyage à Lisbonne', s: 640, g: 1500, dl: 'juin 2027', per: 123 }, { t: 'Fonds d\'urgence', s: 1120, g: 3000 }],
  savedGoals: 1760, savingsTarget: 300,                                       // « Épargne visée » 300 $ par mois (Mes informations)
  accounts: [{ t: 'Compte chèques', a: 1846.2, i: 'wallet' }, { t: 'Compte épargne', a: 1120, i: 'piggy' }, { t: 'Carte de crédit', a: -215.4, i: 'card', debt: true }],
  netWorth: 2750.8, nw6: [1980, 2090, 2150, 2310, 2520, 2750.8],
  // six mois (Évolution, Premium) : juin → novembre (novembre en cours, au 12)
  months: [{ l: 'juin', i: 1720, o: 1120 }, { l: 'juil.', i: 1760, o: 1260 }, { l: 'août', i: 1700, o: 1180 }, { l: 'sept.', i: 1810, o: 1090 }, { l: 'oct.', i: 1780, o: 1210 }, { l: 'nov.', i: 1150, o: 788, cur: true }],
  avg: { o: 1172, i: 1754, kept: 582, rate: .33 },
  week: { lab: ['L', 'M', 'M', 'J', 'V', 'S', 'D'], cur: [12, 41, 9, 14.5, null, null, null], prev: [130.5, 88, 63, 140, 32, 0, 58], curTot: 76.5, prevTot: 511.5 },
};
FIN.cats.forEach((c) => { c.col = F.col(c.hex); });
FIN.cat = (k) => FIN.cats.find((c) => c.k === k);
FIN.cum = FIN.daily.reduce((a, v) => (a.push((a[a.length - 1] || 0) + v), a), []);
FIN.rem = FIN.cum.map((v) => FIN.budget - v);
FIN.bal = (() => { let b = FIN.opening; return FIN.daily.map((v, k) => (b += (k === 4 ? FIN.income : 0) - v)); })();   // 1 846,20 au 12
FIN.dayLong = (d) => { const n = ['dimanche', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'][d % 7]; return n[0].toUpperCase() + n.slice(1) + ' ' + d + ' novembre'; };
FIN.dayTot = (d) => FIN.ops.filter((o) => o.d === d && o.a < 0).reduce((s, o) => s - o.a, 0);

/* ---------- morceaux d'écran ---------- */
Object.assign(F, {
  nv: (t = 'Finances', right) => `<div class="nv"><span class="rb gl" role="button" aria-label="Retour"><i data-i="chevl"></i></span><span class="sp"></span><span class="t">${t}</span><span class="sp"></span>${right || '<span style="width:44px"></span>'}</div>`,
  rbtn: (i, label, cls = 'gl') => `<span class="rb ${cls}" role="button" aria-label="${label}"><i data-i="${i}"></i></span>`,
  sect: (t, d, a) => `<div class="sect"><b>${t}</b>${d ? `<span>${d}</span>` : ''}${a ? `<a>${a}</a>` : ''}</div>`,
  nw: (t = 'Nouveau') => `<span class="fn-new">${t}</span>`,
  prem: () => `<span class="prem"><i data-i="crown"></i>Premium</span>`,
  lock: (t) => `<span class="fn-lock">${t}<i data-i="lock"></i></span>`,
  fab: (t = 'Ajouter', i = 'plus') => `<div class="fab"><i data-i="${i}"></i>${t}</div>`,
  fab2: () => `<div class="fn-fab2"><div class="p"><i data-i="minus"></i>Dépense</div><div class="g"><i data-i="plus"></i>Revenu</div></div>`,
  month: (t = FIN.month, locked = true) => `<div class="gl fn-month"><i data-i="${locked ? 'lock' : 'chevl'}" class="${locked ? 'lk' : ''}"></i><span>${t}</span><i data-i="chev" style="opacity:.35"></i></div>`,
  wsel: (o = {}) => U.wsel({ marks: [0, 1, 2, 3], ...o }),
  catIco: (c, cls = 'lg') => `<span class="ico ${cls}" style="--c:${c.col}"><i data-i="${c.i}"></i></span>`,
  gIco: (i, col, cls = 'lg sq') => `<span class="ico ${cls}"${col ? ` style="--c:${col}"` : ''}><i data-i="${i}"></i></span>`,
  // une opération : icône de catégorie (ou flèche verte du revenu), titre, détail, montant signé
  op(o, x = {}) { const c = o.c ? FIN.cat(o.c) : null, inc = o.a > 0;
    const ic = inc ? `<span class="ico lg" style="--c:var(--fn-in)"><i data-i="inArrow"></i></span>` : F.catIco(c);
    const sub = x.sub ?? [inc ? (o.fixed ? 'Revenu fixe' : 'Revenu') : (o.fixed ? 'Dépense fixe · ' + c.n : c.n), x.when].filter(Boolean).join(' · ');
    const marks = (o.ap ? ` · <span class="fn-mk"><i data-i="wave"></i>Apple Pay</span>` : '') + (o.rev ? '<span class="fn-rev">À vérifier</span>' : '');
    return `<div class="li${x.cls ? ' ' + x.cls : ''}">${ic}<div class="tx"><b>${o.t}</b><span class="s">${sub}${marks}</span></div><div class="fn-amtR"><b class="${inc ? 'in' : ''}">${inc ? F.inc(o.a) : F.out(-o.a)}</b>${x.right ? `<span>${x.right}</span>` : ''}</div>${x.chev ? '<i class="go" data-i="chev"></i>' : ''}</div>`; },
  bill(b, x = {}) { const hot = b.due === 13 && !b.mo;
    return `<div class="li">${F.gIco(b.i, hot ? 'var(--fn-over)' : null)}<div class="tx"><b>${b.t}</b><span class="s">${x.sub ?? ((b.sub ? 'Abonnement · ' : '') + b.when)}</span></div><div class="fn-amtR"><b>${F.m2(b.a)}</b></div></div>`; },
  due(b, x = {}) { const hot = b.due === 13 && !b.mo;
    return `<div class="fn-due${hot ? ' hot' : ''}"><div class="d"><small>${b.mo ? b.mo : b.dow}</small><b>${b.due}</b></div><div class="tx"><b>${b.t}</b><span class="s">${x.sub ?? ((b.sub ? 'Abonnement · ' : 'Facture · ') + b.when)}</span></div><div class="fn-amtR"><b>${F.m2(b.a)}</b></div></div>`; },
  // une catégorie du mois : barre jusqu'à sa limite ; o.pace = repère « où tu devrais en être » (12/30 de la limite)
  cat(c, o = {}) { const lim = c.lim, p = o.share ? c.v / Math.max(...FIN.cats.map((x) => x.v)) : lim ? Math.min(1, c.v / lim) : 0, over = !o.share && lim && c.v > lim;
    const right = o.right ?? (lim ? `<b>${F.m(c.v)}</b> / ${F.m(lim)}` : `<b>${F.m(c.v)}</b> · sans limite`);
    const pace = o.pace && lim ? `<u style="left:${(FIN.day / FIN.days * 100).toFixed(1)}%"></u>` : '';
    return `<div class="fn-cat" style="--c:${over ? 'var(--fn-over)' : c.col}">${F.catIco(c)}<div class="tx"><div class="l"><span>${c.n}</span><em>${right}</em></div>`
      + (lim || o.share ? `<div class="fn-bar"><i style="width:${(p * 100).toFixed(1)}%"></i>${pace}</div>` : '<div class="fn-bar" style="background:none;border-top:1.5px dashed var(--rule2);height:0;margin:3px 0"></div>')
      + (o.sub ? `<div class="s2">${typeof o.sub === 'function' ? o.sub(c) : o.sub}</div>` : '') + '</div></div>'; },
  goal(g, x = {}) { const p = g.s / g.g;
    return `<div style="padding:${x.pad || '6px 0'}"><div style="display:flex;justify-content:space-between;align-items:baseline;gap:8px"><b style="font-size:15px;font-weight:650">${g.t}</b><b class="fn-tn" style="font-size:14px;color:var(--fn-in)">${F.pct(p)}</b></div>
      <div class="fn-bar" style="margin:8px 0 6px;--c:var(--fn-in)"><i style="width:${(p * 100).toFixed(1)}%"></i></div>
      <div class="s">${F.m(g.s)} sur ${F.m(g.g)}${g.per ? ` · ${F.m(g.per)} / mois d'ici ${g.dl}` : ''}</div>${x.more || ''}</div>`; },
  acct: (a) => `<div class="li">${F.gIco(a.i, a.debt ? 'var(--fn-over)' : null)}<div class="tx"><b>${a.t}</b>${a.debt ? '<span class="s">Dette</span>' : ''}</div><div class="fn-amtR"><b>${a.debt ? F.out(-a.a) : F.m2(a.a)}</b></div></div>`,
  row: (i, t, s, x = {}) => `<div class="li">${F.gIco(i, x.col)}<div class="tx"><b>${t}</b>${s ? `<span class="s">${s}</span>` : ''}</div>${x.r ? `<div class="fn-amtR">${x.r}</div>` : ''}${x.chev === false ? '' : '<i class="go" data-i="chev"></i>'}</div>`,
  pace(o = {}) { const p = FIN.spent / FIN.budget, t = FIN.day / FIN.days;
    return `<div class="fn-pace" role="img" aria-label="788 $ dépensés sur 1 200 $ ; repère du 12 novembre à 40 %"><i style="width:${(p * 100).toFixed(1)}%"></i><u style="left:${(t * 100).toFixed(1)}%"></u></div>`
      + (o.labels === false ? '' : `<div class="fn-pace-l"><span><b>${F.m(FIN.spent)}</b> dépensés · ${F.pct(p)}</span><span>${o.right || 'budget ' + F.m(FIN.budget)}</span></div>`); },
  kpi: (h, v, s, x = {}) => `<div class="pn fn-kpi"${x.st ? ` style="${x.st}"` : ''}><div class="h">${x.i ? `<i data-i="${x.i}" style="color:${x.ic || 'currentColor'}"></i>` : ''}${h}${x.tag || ''}</div><div class="fn-num${x.sm ? ' sm' : ''}"${x.vc ? ` style="color:${x.vc}"` : ''}>${v}</div>${s ? `<div class="s">${s}</div>` : ''}</div>`,
  leg: (items) => `<div class="fn-leg">${items.map(([c, t, k]) => `<span><u class="${k || ''}" style="--c:${c}"></u>${t}</span>`).join('')}</div>`,
  sheet: (body, t, o = {}) => `<div class="dim"></div><div class="sheet"${o.st ? ` style="${o.st}"` : ''}><div class="grab"></div>${t ? `<div class="nv" style="position:relative"><span class="rb" role="button" aria-label="Fermer"><i data-i="x"></i></span><span class="sp"></span><span class="t" style="position:absolute;left:0;right:0;text-align:center">${t}</span><span class="sp"></span>${o.right || '<span style="width:44px"></span>'}</div>` : ''}${body}</div>`,
  mount(id, html, after = '') { document.getElementById(id).innerHTML = `<div class="scr">${html}</div>${after}`; },
});

/* ---------- les fonctions existantes (relevé dans le code le 2026-11-16) : chaque planche dit où elles se trouvent ---------- */
const FEATURES = [
  ['sel', 'Sélecteur de semaine : les chiffres du mois à la fin du jour choisi', 'G'],
  ['reste', 'Reste du mois, dépensé, « par jour pendant N jours »', 'G'],
  ['budget', 'Budget du mois (modifier)', 'G'],
  ['cmp', 'Comparaison au mois dernier à la même date (total)', 'G'],
  ['add', 'Ajouter, modifier, supprimer une dépense ou un revenu', 'G'],
  ['day', 'Jour choisi : dépenses, revenus et opérations du jour', 'G'],
  ['applepay', 'Dépenses Apple Pay automatiques, règles de commerçants, « À vérifier »', 'G'],
  ['solde', 'Solde du compte, sa courbe, solde de départ', 'G · 3 mois et Année : P'],
  ['releve', 'Relevé : solde après chaque opération', 'G (mois en cours) · plus ancien : P'],
  ['ops', 'Opérations mois par mois, Dépenses / Revenus, filtre de catégorie', 'G (mois en cours) · mois passés : P'],
  ['cats', 'Catégories : anneau, limites, créer, renommer, icône, couleur', 'G (mois en cours) · mois passés : P'],
  ['bills', 'Factures et abonnements : échéances, total, rappel la veille', 'G'],
  ['fixed', 'Revenus et dépenses fixes', 'G'],
  ['goals', 'Objectifs d\'épargne : versements, date limite, mensualité', 'G'],
  ['accounts', 'Comptes et dettes saisis à la main, valeur nette et sa courbe', 'G'],
  ['trends', 'Évolution : 6 mois, moyennes, comparaison par catégorie', 'P'],
  ['quick', 'Dépenses rapides (widget Dépense rapide)', 'G'],
  ['settings', 'Mes paramètres : devise, Mes informations, rappel des factures', 'G'],
  ['tofill', '« À remplir » : budget à définir', 'G'],
];
F.mapNote = (id, where) => { document.getElementById(id).innerHTML = `<h4>Rien n'est retiré : où se trouve chaque fonction existante</h4>
  <p style="color:#4E5A6B">G = gratuite ; P = Premium (sans Premium : le mois en cours et les 7 derniers jours). Règles Premium inchangées dans toutes les directions.</p>
  <div style="display:grid;grid-template-columns:1fr 1fr;gap:0 34px;margin-top:10px">${FEATURES.map(([k, t, pl]) => `<div style="display:grid;grid-template-columns:minmax(0,1fr) 112px minmax(0,1.2fr);gap:10px;padding:6px 0;border-top:1px solid #E3E7EE;font-size:12.5px;line-height:1.35">
    <b style="font-weight:650">${t}</b><span style="font-weight:700;color:${pl === 'P' ? '#6B4E0A' : /P/.test(pl) ? '#35435A' : '#1E5B34'}">${pl}</span><span style="color:#35435A">${where[k] || '—'}</span></div>`).join('')}</div>`; };

/* ---------- graphiques (SVG, lisibles sans couleur : légende écrite, valeur finale marquée) ---------- */
Object.assign(F, {
  /* Courbes. o.series = [{ v:[…], c:couleur, w:épaisseur, dash:true, area:true, dot:true, n:nombre de points de l'axe X }],
     o.w, o.h, o.max, o.min, o.yt = [valeurs de graduation], o.yf = format, o.xl = [[index, texte]], o.n = longueur de l'axe X,
     o.ref = { v, t } ligne horizontale (budget), o.tip = { i, s, t } bulle sur un point, o.aria */
  line(o) { const W = o.w || 321, H = o.h || 120, pr = o.yt ? 44 : 4, pw = W - pr, n = o.n || Math.max(...o.series.map((s) => s.v.length)), min = o.min || 0, max = o.max;
    const X = (k) => (n === 1 ? 0 : k / (n - 1) * pw), Y = (v) => H - (v - min) / (max - min) * H;
    let g = '';
    (o.yt || []).forEach((v) => { g += `<line x1="0" x2="${pw}" y1="${Y(v).toFixed(1)}" y2="${Y(v).toFixed(1)}" stroke="var(--grid)" stroke-width="1"/><text x="${pw + 6}" y="${(Y(v) + 3.5).toFixed(1)}">${(o.yf || F.m)(v)}</text>`; });
    if (o.ref) g += `<line x1="0" x2="${pw}" y1="${Y(o.ref.v).toFixed(1)}" y2="${Y(o.ref.v).toFixed(1)}" stroke="var(--ink)" stroke-width="1.4" stroke-dasharray="5 4" opacity=".55"/>${o.ref.t ? `<text class="b" x="2" y="${(Y(o.ref.v) - 5).toFixed(1)}">${o.ref.t}</text>` : ''}`;
    o.series.forEach((s) => { const pts = s.v.map((v, k) => (v == null ? null : [X(k), Y(v)])).filter(Boolean);
      const d = pts.map((p, k) => (k ? 'L' : 'M') + p[0].toFixed(1) + ' ' + p[1].toFixed(1)).join(' '), last = pts[pts.length - 1];
      if (s.area) g += `<path d="${d} L${last[0].toFixed(1)} ${H} L${pts[0][0].toFixed(1)} ${H} Z" fill="${s.c}" opacity="${s.ao || .12}"/>`;
      g += `<path d="${d}" fill="none" stroke="${s.c}" stroke-width="${s.w || 2.4}" stroke-linecap="round" stroke-linejoin="round"${s.dash ? ' stroke-dasharray="4 4"' : ''}/>`;
      if (s.dot) g += `<circle cx="${last[0].toFixed(1)}" cy="${last[1].toFixed(1)}" r="4.5" fill="var(--card)" stroke="${s.c}" stroke-width="2.4"/>`; });
    if (o.tip) { const x = X(o.tip.i), y = Y(o.tip.v), tw = o.tip.w || 92, tx = Math.min(Math.max(x - tw / 2, 0), pw - tw);
      g += `<line x1="${x.toFixed(1)}" x2="${x.toFixed(1)}" y1="${(y + 6).toFixed(1)}" y2="${H}" stroke="var(--ink)" stroke-width="1" opacity=".25"/>`
        + `<g transform="translate(${tx.toFixed(1)} ${(y - 40).toFixed(1)})"><rect width="${tw}" height="30" rx="9" fill="var(--ink)"/><text x="${tw / 2}" y="13" text-anchor="middle" style="fill:#fff;font-weight:700;font-size:11px">${o.tip.t}</text><text x="${tw / 2}" y="24.5" text-anchor="middle" style="fill:rgba(255,255,255,.75);font-size:9.5px">${o.tip.s}</text></g>`; }
    (o.xl || []).forEach(([k, t]) => { const x = X(k); g += `<text x="${x.toFixed(1)}" y="${H + 15}" text-anchor="${k === 0 ? 'start' : k >= n - 1 ? 'end' : 'middle'}">${t}</text>`; });
    return `<div class="fn-ch" role="img" aria-label="${o.aria || ''}"><svg width="${W}" height="${H + (o.xl ? 19 : 2)}" viewBox="0 0 ${W} ${H + (o.xl ? 19 : 2)}">${g}</svg></div>`; },

  /* Barres groupées. o.g = [{ l, v:[a, b…], cur }], o.c = [couleurs], o.max, o.yt, o.w, o.h, o.cur = hachures sur le groupe en cours, o.vals = valeurs écrites */
  bars(o) { const W = o.w || 321, H = o.h || 130, pr = o.yt ? 44 : 0, pw = W - pr, n = o.g.length, gw = pw / n, k = o.g[0].v.length, bw = Math.min(o.bw || 14, (gw - 10) / k), gap = o.bg ?? 3;
    const Y = (v) => H - v / o.max * H; let s = '<defs><pattern id="hat" width="5" height="5" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="2.2" height="5" fill="currentColor"/></pattern></defs>';
    (o.yt || []).forEach((v) => { s += `<line x1="0" x2="${pw}" y1="${Y(v).toFixed(1)}" y2="${Y(v).toFixed(1)}" stroke="var(--grid)"/><text x="${pw + 6}" y="${(Y(v) + 3.5).toFixed(1)}">${(o.yf || F.m)(v)}</text>`; });
    if (o.ref) s += `<line x1="0" x2="${pw}" y1="${Y(o.ref.v).toFixed(1)}" y2="${Y(o.ref.v).toFixed(1)}" stroke="var(--ink)" stroke-width="1.3" stroke-dasharray="5 4" opacity=".55"/>${o.ref.t ? `<text class="b" x="${pw}" y="${(Y(o.ref.v) - 5).toFixed(1)}" text-anchor="end">${o.ref.t}</text>` : ''}`;
    o.g.forEach((gr, gi) => { const x0 = gi * gw + (gw - (k * bw + (k - 1) * gap)) / 2;
      gr.v.forEach((v, j) => { if (v == null) return; const x = x0 + j * (bw + gap), y = Y(v), h = Math.max(H - y, v ? 2 : 0), c = (gr.c || o.c)[j], r = Math.min(4, bw / 2);
        const path = `M${x.toFixed(1)} ${H} V${(y + r).toFixed(1)} Q${x.toFixed(1)} ${y.toFixed(1)} ${(x + r).toFixed(1)} ${y.toFixed(1)} H${(x + bw - r).toFixed(1)} Q${(x + bw).toFixed(1)} ${y.toFixed(1)} ${(x + bw).toFixed(1)} ${(y + r).toFixed(1)} V${H} Z`;
        s += gr.cur && o.cur !== false ? `<path d="${path}" fill="${c}" opacity=".22"/><path d="${path}" fill="url(#hat)" style="color:${c}"/><path d="${path}" fill="none" stroke="${c}" stroke-width="1.2"/>` : `<path d="${path}" fill="${c}"${gr.dim ? ' opacity=".35"' : ''}/>`;
        if (o.vals && v) s += `<text x="${(x + bw / 2).toFixed(1)}" y="${(y - 5).toFixed(1)}" text-anchor="middle" class="${gr.hl ? 'b' : ''}" style="font-size:9.5px">${(o.vf || ((z) => F.n(z)))(v)}</text>`; });
      s += `<text x="${(gi * gw + gw / 2).toFixed(1)}" y="${H + 15}" text-anchor="middle" class="${gr.hl ? 'b' : ''}">${gr.l}</text>`; });
    s += `<line x1="0" x2="${pw}" y1="${H}" y2="${H}" stroke="var(--rule2)"/>`;
    return `<div class="fn-ch" role="img" aria-label="${o.aria || ''}"><svg width="${W}" height="${H + 19}" viewBox="0 0 ${W} ${H + 19}">${s}</svg></div>`; },

  /* Anneau des catégories : items [{ v, c }], o.s taille, o.sw épaisseur, o.in = HTML du centre */
  donut(items, o = {}) { const S = o.s || 150, sw = o.sw || 16, r = (S - sw) / 2, cx = S / 2, tot = items.reduce((a, b) => a + b.v, 0), gapA = o.gap ?? 0.035;
    let a0 = -Math.PI / 2, s = `<circle cx="${cx}" cy="${cx}" r="${r}" fill="none" stroke="var(--track)" stroke-width="${sw}" opacity="${o.track ? 1 : 0}"/>`;
    items.forEach((it) => { const a1 = a0 + it.v / tot * Math.PI * 2, b0 = a0 + gapA / 2, b1 = a1 - gapA / 2, large = b1 - b0 > Math.PI ? 1 : 0;
      s += `<path d="M${(cx + r * Math.cos(b0)).toFixed(2)} ${(cx + r * Math.sin(b0)).toFixed(2)} A${r} ${r} 0 ${large} 1 ${(cx + r * Math.cos(b1)).toFixed(2)} ${(cx + r * Math.sin(b1)).toFixed(2)}" fill="none" stroke="${it.c}" stroke-width="${sw}" stroke-linecap="${o.cap || 'butt'}"/>`; a0 = a1; });
    return `<div class="fn-donut" style="width:${S}px;height:${S}px" role="img" aria-label="${o.aria || ''}"><svg width="${S}" height="${S}" viewBox="0 0 ${S} ${S}">${s}</svg>${o.in ? `<div class="in">${o.in}</div>` : ''}</div>`; },

  /* Barre empilée 100 % (répartition) */
  stack: (items, h = 14) => `<div class="fn-stack" style="height:${h}px">${items.map((it) => `<i style="--c:${it.c};width:${(it.v / items.reduce((a, b) => a + b.v, 0) * 100).toFixed(2)}%"></i>`).join('')}</div>`,

  /* Calendrier du mois coloré par dépense du jour (habitudes). vals[jour-1] ; aujourd'hui entouré ; jours à venir en pointillés */
  heat(o = {}) { const vals = o.vals || FIN.daily, max = o.max || 200, col = o.c || 'var(--fn-out)';
    let h = ['L', 'M', 'M', 'J', 'V', 'S', 'D'].map((d) => `<span class="h">${d}</span>`).join('') + '<span></span>'.repeat(FIN.dow0);
    for (let d = 1; d <= FIN.days; d++) { const v = vals[d - 1];
      if (d > FIN.day) h += `<span class="f">${d}</span>`;
      else { const p = v / max, bg = v ? `color-mix(in srgb, ${col} ${Math.round(12 + 70 * Math.min(1, p))}%, var(--card))` : 'var(--well)';
        h += `<span class="${d === FIN.day ? 't' : ''}" style="background:${bg};color:${p > .45 ? '#fff' : 'var(--ink)'}">${d}</span>`; } }
    return `<div class="fn-heat" role="img" aria-label="${o.aria || 'Dépenses de chaque jour de novembre'}">${h}</div>`; },

  /* Cascade du mois : départ, revenus, dépenses, arrivée */
  fall(o = {}) { const W = o.w || 321, H = o.h || 130, steps = o.steps, max = o.max, Y = (v) => H - v / max * H, n = steps.length, gw = W / n, bw = Math.min(46, gw - 18);
    let s = '', run = 0;
    steps.forEach((st, k) => { let y0, y1, c;
      if (st.k === 'start' || st.k === 'end') { y0 = 0; y1 = st.v; run = st.v; c = st.k === 'end' ? 'var(--ink)' : 'var(--fn-prev)'; }
      else if (st.k === 'in') { y0 = run; y1 = run + st.v; run = y1; c = 'var(--fn-in)'; }
      else { y0 = run - st.v; y1 = run; run = y0; c = 'var(--fn-out)'; }
      const x = k * gw + (gw - bw) / 2;
      s += `<rect x="${x.toFixed(1)}" y="${Y(y1).toFixed(1)}" width="${bw}" height="${Math.max(2, Y(y0) - Y(y1)).toFixed(1)}" rx="5" fill="${c}"/>`
        + `<text x="${(x + bw / 2).toFixed(1)}" y="${(Y(y1) - 6).toFixed(1)}" text-anchor="middle" class="b">${st.t}</text>`
        + `<text x="${(x + bw / 2).toFixed(1)}" y="${H + 15}" text-anchor="middle">${st.l}</text>`;
      if (k < n - 1) s += `<line x1="${(x + bw).toFixed(1)}" x2="${((k + 1) * gw + (gw - bw) / 2).toFixed(1)}" y1="${Y(run).toFixed(1)}" y2="${Y(run).toFixed(1)}" stroke="var(--ink2)" stroke-dasharray="3 3" opacity=".6"/>`; });
    return `<div class="fn-ch" role="img" aria-label="${o.aria || ''}"><svg width="${W}" height="${H + 19}" viewBox="0 0 ${W} ${H + 19}">${s}<line x1="0" x2="${W}" y1="${H}" y2="${H}" stroke="var(--rule2)"/></svg></div>`; },
});
