/* compo-base.js : données (DONNEES.md), icônes et utilitaires communs aux 10 planches. Ne pas modifier.
   Un style s'en sert ainsi (en fin de <body>, après ses propres balises) :
   - DAY.matin / DAY.journee / DAY.soiree : les chiffres du moment (DAY.journee.kcal.left = 1122…) ; HABITS, EVENTS, TOP3,
     REMIND, CAL7, SPEND7, WEEKDAYS : listes. U.n(1122) → « 1 122 », U.money(21.68) → « 21,68 $ ».
   - U.ring(p, épaisseur) · U.meter(p) · U.bars(valeurs, {goal, max}) + U.barsLab(lettres) · U.spark(valeurs, {w, h}) ·
     U.week({from, to, focus, labels, now}) · U.dots7(faits) · U.hab(moment) : renvoient du HTML/SVG sans style propre.
   - Déclaratif : <div data-u="ring" data-p=".49" data-sw="10"> · data-u="week" data-o='{"focus":3}' · data-u="bars" data-set="cal7"
     data-m="journee" · data-u="spark" data-m="journee" data-w="140" data-h="40" · data-u="dots7" · data-u="hab" data-m="soiree".
     <span data-v="journee.kcal.left"></span> écrit le chiffre formaté. <i data-i="fork"></i> devient une icône au trait (table P).
   - Compo.legend(el, {name, intro, rows:[{k:'A', w:'…', E:[…], A:[…], D:[…]}]}) puis Compo.init() en dernier :
     barre d'état (heure du moment de figure[data-compo]), onglets, fondu, indicateur, légendes sous les téléphones.
   - Contrôles : ?check entoure en rouge tout texte coupé ou débordant ; ?w375 passe les téléphones à 375 points. */

/* ---------- icônes au trait (24 × 24, trait réglé par --sw) ---------- */
const P = {
  home: 'M3 11l9-8 9 8v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z', plus: 'M12 5v14M5 12h14',
  bag: 'M5 8h14l-1 12H6zM9 8V6a3 3 0 0 1 6 0v2', grid: 'M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z',
  fork: 'M7 3v7a2 2 0 0 0 4 0V3M9 12v9M17 3c-2 2-3 5-3 8h3v10', dumbbell: 'M3 9v6M6 6v12M18 6v12M21 9v6M6 12h12',
  repeat: 'M17 2l3 3-3 3M4 11V9a4 4 0 0 1 4-4h12M7 22l-3-3 3-3M20 13v2a4 4 0 0 1-4 4H4',
  wallet: 'M3 7a2 2 0 0 1 2-2h13v4M3 7v10a2 2 0 0 0 2 2h15V9H5a2 2 0 0 1-2-2zM16 14h.01',
  calendar: 'M4 6h16v14H4zM4 10h16M8 3v4M16 3v4', check: 'M5 12.5l4.5 4.5L19 7.5',
  list: 'M9 6h11M9 12h11M9 18h11M4.5 6h.01M4.5 12h.01M4.5 18h.01',
  steps: 'M8 3c-1.7 0-3 2-3 4.5S6 12 7.5 12 10 10 10 7.5 9.7 3 8 3zM6 15h4v1.5a2 2 0 0 1-4 0zM16 7c1.7 0 3 2 3 4.5S18 16 16.5 16 14 14 14 11.5 14.3 7 16 7zM14 19h4v.5a2 2 0 0 1-4 0z',
  scan: 'M4 8V5a1 1 0 0 1 1-1h3M16 4h3a1 1 0 0 1 1 1v3M20 16v3a1 1 0 0 1-1 1h-3M8 20H5a1 1 0 0 1-1-1v-3M7 12h10',
  chev: 'M9 6l6 6-6 6', chevl: 'M15 6l-6 6 6 6', user: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21a8 8 0 0 1 16 0',
  target: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM12 11.5v1',
  pause: 'M9 6v12M15 6v12', play: 'M8 5l11 7-11 7z', timer: 'M12 9v4l2.5 1.5M9 2h6M12 5a8 8 0 1 0 0 16 8 8 0 0 0 0-16z',
  pin: 'M12 21s-6-5.5-6-11a6 6 0 0 1 12 0c0 5.5-6 11-6 11zM12 8.5a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3z',
  doc: 'M6 3h9l3 3v15H6zM9 9h6M9 13h6M9 17h4', pencil: 'M4 20l4-1 11-11-3-3L5 16zM14 6l3 3',
  book: 'M5 4h12a2 2 0 0 1 2 2v14H7a2 2 0 0 1-2-2zM5 18a2 2 0 0 1 2-2h12', car: 'M3 15H2v-3l3-1 2-4h8l3 4 4 1v3h-1M9 15h6M5 15a2 2 0 1 0 4 0 2 2 0 1 0-4 0M15 15a2 2 0 1 0 4 0 2 2 0 1 0-4 0M7.5 11H18',
  circle: 'M12 3.5a8.5 8.5 0 1 0 0 17 8.5 8.5 0 0 0 0-17z', checkc: 'M12 3.5a8.5 8.5 0 1 0 0 17 8.5 8.5 0 0 0 0-17zM8 12.2l2.8 2.8L16 9.6',
  bell: 'M6 16v-5a6 6 0 0 1 12 0v5l1.5 2h-15zM10 20.5a2 2 0 0 0 4 0', trend: 'M3 17l6-6 4 4 8-8M15 7h6v6',
  bars: 'M5 20V10M12 20V4M19 20v-7', search: 'M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM20 20l-4-4', lock: 'M6 11h12v9H6zM8 11V8a4 4 0 0 1 8 0v3',
  arrow: 'M5 12h14M13 6l6 6-6 6', dots: 'M5 12h.01M12 12h.01M19 12h.01', flag: 'M5 21V4h11l-2 4 2 4H5',
};

/* ---------- la journée d'exemple : jeudi 12 novembre (DONNEES.md, section 2) ---------- */
const HABITS = [ // ordre d'affichage ; moment où l'habitude est faite (null : pas encore)
  { t: 'Boire 2 L d\'eau', at: 'soiree' }, { t: 'Lecture 20 min', at: 'journee' }, { t: 'Méditation', at: 'journee' },
  { t: 'Vitamines', at: 'matin' }, { t: 'Coucher avant 23 h', at: null }];
const MOMENTS = ['matin', 'journee', 'soiree'];
const habDone = (m) => HABITS.map((h) => h.at != null && MOMENTS.indexOf(h.at) <= MOMENTS.indexOf(m));
// d : 0 = lundi … 6 = dimanche ; jeudi = 3. Durées non fournies par DONNEES.md : 1 h par défaut (dessin seulement), sauf Travail du vendredi (13:00 à 17:00).
const EVENTS = [
  { d: 0, s: '09:00', t: 'Comptabilité', ty: 'cours' }, { d: 0, s: '13:00', t: 'Marketing', ty: 'cours' },
  { d: 1, s: '10:00', t: 'Statistiques', ty: 'cours' }, { d: 1, s: '18:00', t: 'Séance', ty: 'seance' },
  { d: 2, s: '09:00', t: 'Marketing', ty: 'cours' }, { d: 2, s: '13:00', t: 'Travail', ty: 'travail' },
  { d: 3, s: '09:00', t: 'Comptabilité', p: 'B-204', ty: 'cours' }, { d: 3, s: '11:30', t: 'Travail d\'équipe', p: 'Bibliothèque', ty: 'cours' },
  { d: 3, s: '14:00', t: 'Réunion projet', p: 'Local 3.12', ty: 'rdv' }, { d: 3, s: '16:30', t: 'Dentiste', ty: 'rdv' },
  { d: 3, s: '18:30', t: 'Séance Haut du corps', ty: 'seance' },
  { d: 4, s: '10:00', t: 'Statistiques', ty: 'cours' }, { d: 4, s: '13:00', e: '17:00', t: 'Travail', ty: 'travail' },
  { d: 5, s: '10:00', t: 'Séance Jambes', ty: 'seance' }];
const TODAY = 3, WEEKDAYS = ['L', 'M', 'M', 'J', 'V', 'S', 'D'], WEEKDAYS_LONG = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
const TOP3 = ['Rendre le rapport de marketing', 'Appeler la banque', 'Réviser le chapitre 4'];
const REMIND = [ // « À ne pas oublier » (c : catégorie pour la couleur de l'icône)
  { t: 'Facture Internet', due: 'Demain · 45 $', i: 'doc', c: 'bud' }, { t: 'Devoir : étude de cas', due: 'Vendredi', i: 'pencil', c: 'pla' },
  { t: 'Examen : Statistiques', due: 'Lundi', i: 'book', c: 'pla' }, { t: 'Assurance auto', due: 'Mardi · 62 $', i: 'car', c: 'bud' }];
const CAL7 = { lab: ['V', 'S', 'D', 'L', 'M', 'M', 'J'], past: [2250, 2480, 2050, 2140, 2310, 1980], goal: 2200, avg: 2202 }; // + aujourd'hui (kcal.eaten)
const SPEND7 = { lab: ['V', 'S', 'D', 'L', 'M', 'M', 'J'], past: [32, 0, 58, 12, 41, 9] }; // + aujourd'hui (budget.today)
const SOLDE = { t: 'Compte chèques', v: 1846.20 }; // À adapter
const SHORT = { // chiffre court par mini-app (rangée « Mes mini-apps », À adapter)
  nut: (m) => `${U.n(DAY[m].kcal.eaten)} kcal aujourd'hui`, fit: (m) => m === 'soiree' ? 'Séance en cours' : '2 séances cette semaine',
  pla: (m) => m === 'soiree' ? '3 tâches aujourd\'hui' : 'Réunion projet à 14:00', bud: () => '412 $ restants' };

const WORKOUT_PLANNED = { state: 'prevue', title: 'Séance du jour', prog: 'Haut du corps', meta: '6 exercices · 18 séries', cta: 'Commencer' };
const DAY = {
  date: 'Jeudi 12 novembre', avatar: 'M', kicker: 'MON QUOTIDIEN',
  matin: { time: '08:10', label: 'Jeudi 12 novembre · 8 h 10', title: 'Ta matinée',
    kcal: { eaten: 420, left: 1780, goal: 2200 }, macros: { p: [24, 140], g: [52, 250], l: [12, 70] },
    meals: [['Déjeuner', 420], ['Dîner', null], ['Souper', null], ['Collation', null]], mealsN: 1, next: 'dîner, environ 650 kcal',
    workout: { ...WORKOUT_PLANNED, badge: null }, week: { done: [0, 1], n: 2, goal: 4, left: 2 },
    habits: { done: 1, total: 5, streak: 12 }, budget: { perDay: 22.45, today: 0, left: 426.50 },
    steps: { n: 1240, goal: 8000 }, top3: 0 },
  journee: { time: '13:20', label: 'Jeudi 12 novembre · 13 h 20', title: 'Ta journée',
    kcal: { eaten: 1078, left: 1122, goal: 2200 }, macros: { p: [68, 140], g: [121, 250], l: [34, 70] },
    meals: [['Déjeuner', 420], ['Dîner', 658], ['Souper', null], ['Collation', null]], mealsN: 2, next: 'souper, environ 700 kcal',
    workout: { ...WORKOUT_PLANNED, badge: 'Maintenant' }, week: { done: [0, 1], n: 2, goal: 4, left: 2 },
    habits: { done: 3, total: 5, streak: 12 }, budget: { perDay: 21.68, today: 14.50, left: 412, month: 788, monthGoal: 1200 },
    steps: { n: 5480, goal: 8000 }, top3: 1 },
  soiree: { time: '19:05', label: 'Jeudi 12 novembre · 19 h 05', title: 'Ta soirée',
    kcal: { eaten: 1520, left: 680, goal: 2200 }, macros: { p: [96, 140], g: [168, 250], l: [46, 70] },
    meals: [['Déjeuner', 420], ['Dîner', 658], ['Souper', null], ['Collation', 442]], mealsN: 3, next: 'souper, environ 680 kcal',
    workout: { state: 'encours', title: 'Séance en cours', prog: 'Haut du corps', ex: 'Développé couché', set: 2, sets: 4, reps: '10 × 60 kg', rest: '0:45', cta: 'Série faite' },
    week: { done: [0, 1], n: 2, goal: 4, left: 2 },
    habits: { done: 4, total: 5, streak: 12 }, budget: { perDay: 21.68, today: 14.50, left: 412, month: 788, monthGoal: 1200 },
    steps: { n: 7360, goal: 8000 }, top3: 2 },
};
const COMPOS = { A: ['Équilibrée', 'journee'], B: ['Quotidien', 'soiree'], C: ['Éditoriale', 'matin'], D: ['Compacte', 'journee'], E: ['Premium', 'soiree'] };

/* ---------- utilitaires sans style ---------- */
const U = {
  n: (x) => Math.round(x).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' '),
  money: (x) => (Number.isInteger(x) ? U.n(x) : x.toFixed(2).replace('.', ',').replace(/\B(?=(\d{3})+(?!\d),)/g, ' ')) + ' $',
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
  // Grille de la semaine. o.from/o.to (heures), o.every (pas des lignes), o.focus (indice du jour élargi : À adapter),
  // o.labels 'all' | 'focus' | 'none', o.time (heure devant le nom), o.sub (ligne « heure · lieu » sous le nom),
  // o.now ('13:20' : trait de l'heure), o.long (Lun, Mar…). Hauteur de la grille : --wk-h (prévoir ~26 px par heure pour o.sub).
  week(o = {}) { const from = o.from ?? 8, to = o.to ?? 20, span = (to - from) * 60, every = o.every ?? 2, labels = o.labels ?? 'all';
    const y = (t) => ((U.min(t) - from * 60) / span * 100).toFixed(2);
    const cols = o.focus != null ? Array.from({ length: 7 }, (_, k) => k === o.focus ? `${o.fw || 2.6}fr` : '1fr').join(' ') : 'repeat(7, 1fr)';
    let h = `<div class="u-week" style="--wk-cols:${cols}"><span></span>`;
    h += (o.long ? WEEKDAYS_LONG : WEEKDAYS).map((d, k) => `<span class="hd${k === TODAY ? ' is-today' : ''}">${d}</span>`).join('');
    h += `<div class="gut">${Array.from({ length: Math.floor((to - from) / every) + 1 }, (_, k) => from + k * every).filter((x) => x < to).map((x) => `<span style="top:${y(String(x).padStart(2, '0') + ':00')}%">${x}</span>`).join('')}</div>`;
    for (let d = 0; d < 7; d++) {
      h += `<div class="col${d === TODAY ? ' is-today' : ''}">`;
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
  upcoming: (m, n = 5) => { const t = U.min(DAY[m].time); return EVENTS.filter((e) => e.d === TODAY && U.min(e.s) >= t).concat(EVENTS.filter((e) => e.d === TODAY + 1)).slice(0, n); },
};

/* ---------- montage ---------- */
const Compo = {
  legend(el, o) { const row = (r) => `<div class="lg-row"><div><span class="k">${r.k}</span><span class="n">${COMPOS[r.k][0]}</span></div><p class="w">${r.w}</p><ul>`
      + ['E', 'A', 'D'].map((t) => (r[t] || []).map((x) => `<li><span class="tag ${t.toLowerCase()}">${{ E: 'Existe', A: 'À adapter', D: 'À développer' }[t]}</span><span>${x}</span></li>`).join('')).join('') + '</ul></div>';
    el.innerHTML = `<div class="lg-h">${o.name}</div><p class="lg-p">${o.intro}</p>` + o.rows.map(row).join('') + (o.foot ? `<p class="lg-p" style="margin-top:8px">${o.foot}</p>` : ''); },
  init() {
    const q = new URLSearchParams(location.search);
    document.querySelectorAll('.cb-cell[data-compo]').forEach((c) => { const [name, m] = COMPOS[c.dataset.compo], ph = c.querySelector('.phone');
      if (ph && !ph.dataset.time) ph.dataset.time = DAY[m].time;
      if (!c.querySelector('.cb-cap')) c.insertAdjacentHTML('beforeend', `<figcaption class="cb-cap"><b>${c.dataset.compo}</b><span>${name}</span><em>${DAY[m].label}</em></figcaption>`); });
    document.querySelectorAll('.phone').forEach((ph) => { if (q.has('w375')) ph.classList.add('w375');
      ph.insertAdjacentHTML('afterbegin', `<div class="sb"><span>${ph.dataset.time || '9:41'}</span><div class="isl"></div><span class="rt"><span class="sig"><span style="height:4px"></span><span style="height:6px"></span><span style="height:8px"></span><span style="height:11px"></span></span><span class="bat"></span></span></div>`);
      const tabs = [['home', 'Accueil'], ['plus', 'Créer'], ['bag', 'Store'], ['grid', 'Mes widgets']].map(([i, l], k) => `<div class="ti${k === 0 ? ' on' : ''}">${U.ico(i)}<span>${l}</span></div>`).join('');
      ph.insertAdjacentHTML('beforeend', `<div class="edge"></div>${ph.dataset.tab === 'none' ? '' : `<nav class="tabbar">${tabs}</nav>`}<div class="hi"></div>`); });
    document.querySelectorAll('[data-u]').forEach((el) => { const d = el.dataset, m = d.m || 'journee', o = d.o ? JSON.parse(d.o) : {};
      if (d.u === 'ring') el.innerHTML = U.ring(+d.p, +(d.sw || 10));
      else if (d.u === 'meter') el.innerHTML = U.meter(+d.p);
      else if (d.u === 'week') el.innerHTML = U.week(o);
      else if (d.u === 'dots7') el.innerHTML = U.dots7(DAY[m].week.done, d.letters !== 'no');
      else if (d.u === 'hab') el.innerHTML = U.hab(m);
      else if (d.u === 'bars') { const s = d.set === 'spend7' ? SPEND7 : CAL7, v = s.past.concat(d.set === 'spend7' ? DAY[m].budget.today : DAY[m].kcal.eaten);
        el.innerHTML = U.bars(v, { goal: d.set === 'spend7' ? 0 : CAL7.goal, ...o }); }
      else if (d.u === 'spark') el.innerHTML = U.spark(SPEND7.past.concat(DAY[m].budget.today), { w: +(d.w || 140), h: +(d.h || 40) }); });
    document.querySelectorAll('[data-v]').forEach((el) => { const v = U.get(el.dataset.v); el.textContent = typeof v === 'number' ? (/budget|money/.test(el.dataset.v) ? U.money(v) : U.n(v)) : v; });
    document.querySelectorAll('i[data-i]').forEach((e) => { e.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round"><path d="${P[e.dataset.i] || ''}"/></svg>`; });
    if (q.has('check')) document.fonts.ready.then(() => document.querySelectorAll('.scr *, .cb-legend *').forEach((el) => { const cs = getComputedStyle(el);
      if (cs.display === 'inline' || !el.textContent.trim()) return;
      const cut = el.scrollWidth > el.clientWidth + 1 && (cs.overflow !== 'visible' || el.children.length === 0);
      const box = el.parentElement.getBoundingClientRect(), r = el.getBoundingClientRect(), out = el.closest('.card,.cell') && (r.right > el.closest('.card,.cell').getBoundingClientRect().right + 1);
      if (cut || out || r.right > el.closest('.scr, .cb-legend').getBoundingClientRect().right + 1) el.style.outline = '2px solid red'; }));
    // ?measure : écrit dans <pre id="measure"> le bas de chaque bloc (en points depuis le haut de l'écran) et le haut de la barre d'onglets.
    if (q.has('measure')) { const out = []; document.querySelectorAll('.cb-cell').forEach((c) => { const scr = c.querySelector('.scr'), t = scr.getBoundingClientRect().top, tb = c.querySelector('.tabbar');
      out.push(`${c.dataset.compo} onglets=${tb ? Math.round(tb.getBoundingClientRect().top - t) : '-'}`);
      scr.querySelectorAll(':scope > *, :scope > .stack > *, :scope > * > .card, .li, .band > *').forEach((el) => { const r = el.getBoundingClientRect();
        out.push(`  ${(el.className || el.tagName).toString().slice(0, 24).padEnd(24)} ${Math.round(r.top - t)}–${Math.round(r.bottom - t)}`); }); });
      document.body.insertAdjacentHTML('beforeend', `<pre id="measure" style="position:absolute;z-index:99;top:0;left:0;width:1400px;columns:3;background:#fff;color:#000;font:13px/1.25 Consolas,monospace;padding:12px">${out.join('\n')}</pre>`); }
  },
};
