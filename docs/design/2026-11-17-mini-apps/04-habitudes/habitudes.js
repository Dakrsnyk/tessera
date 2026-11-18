/* habitudes.js : le JS commun du sujet « Habitudes » (refonte UX/UI des mini-apps, 2026-11-17).
   À charger après ../../2026-11-15-cristal/cristal.js et ../base/planches.js, avant le script de la planche.
   Il contient :
     FONCTIONS (alias FEATURES)  la liste F1…F28 de l'audit (../audit/04-habitudes.md, section 4), dans son ordre, avec ses numéros.
                                 [n°, libellé court, accès 'G' | 'P' | 'G+P', ce qu'elle fait en quelques mots]
     HAB                         les données d'exemple du sujet pour le jeudi 12 novembre 2026, 13 h 20, et quelques outils de texte.
     HAB.ui                      pièces d'écran communes (ligne à cocher, semaine, grille des 26 semaines).
   Règles :
     - Les planches du sujet lisent ces données. Aucune planche ne recopie la liste ni ne change un chiffre.
     - Les jours cochés sont CALCULÉS : chaque habitude a un premier jour (il y a 80 jours) et la liste des jours manqués ; fait = pas manqué.
       Série, meilleure série, régularité sur 30 et 90 jours, semaine et jours complets en sortent (règles du code, audit section 5).
       Aucun chiffre n'est tapé à la main (voir HAB.verifier() à la fin).
     - Ce qui n'existe pas dans l'app est rangé sous HAB.nouveau et nulle part ailleurs : à étiqueter « Nouveau » sur les planches.
   Compte montré : PREMIUM (5 habitudes : la limite gratuite est de 3). Un compte gratuit se montre avec HAB.gratuit (les trois premières). */

/* ================= 1. Les 28 fonctions existantes (audit, section 4) ================= */
const FONCTIONS = [
  ['F1', 'Liste de ses habitudes', 'G', 'Nom, icône et couleur de chaque habitude'],
  ['F2', 'Cocher ou décocher une habitude pour le jour affiché', 'G', 'Rond de la ligne : un toucher, avec vibration'],
  ['F3', 'Changer de jour pour rattraper un oubli', 'G', 'Jour précédent ou suivant (pas de futur), « Choisir une date », retour à aujourd\'hui'],
  ['F4', 'Série en cours', 'G', '« Série de N jours » ou « Pas encore de série »'],
  ['F5', 'Régularité sur 30 jours', 'G', 'Un % à droite du nom'],
  ['F6', 'Grille des dernières semaines', 'G', '26 colonnes de 7 jours, sans dates écrites'],
  ['F7', 'Créer une habitude', 'G', 'Nom, icône, couleur, rappel ; gratuit jusqu\'à 3'],
  ['F8', 'Modifier une habitude', 'G', 'Mêmes champs ; les jours cochés sont gardés'],
  ['F9', 'Supprimer depuis la fiche, avec confirmation', 'G', '« Son historique et sa série seront effacés. »'],
  ['F10', 'Supprimer par balayage', 'G', 'Liste « Habitudes » seulement ; sans confirmation'],
  ['F11', 'Réordonner les habitudes', 'G', 'Bouton « Modifier » ; l\'ordre décide de ce que montrent la carte et les widgets'],
  ['F12', 'Rappel quotidien par habitude', 'G', 'Activer, choisir l\'heure (20:00 proposé)'],
  ['F13', 'Section « Régularité »', 'P', 'Meilleure série, 30 jours et 90 jours ; carte verrou en gratuit'],
  ['F14', 'Limite gratuite et offre', 'G+P', '3 habitudes en gratuit ; « x sur 3 habitudes en version gratuite. »'],
  ['F15', 'Ajout rapide par le nom seul', 'G', 'Champ « Ex. : méditer, lire, marcher »'],
  ['F16', 'Carte « Habitudes » de Mon quotidien', 'G', '« faites/total », série, une ligne par habitude'],
  ['F17', 'Ligne « Habitudes » de Planning', 'G', '« Séries et régularité » ; « faites/total » du jour'],
  ['F18', 'Widget « Habitudes » (petit, moyen, grand)', 'G', 'On coche sur l\'écran d\'accueil'],
  ['F19', 'Widget « Série » (petit, moyen, rond d\'écran verrouillé)', 'G', 'Série d\'une habitude ; moyen : le mois et « Record »'],
  ['F20', 'Widget « Semaine d\'habitudes » (moyen, grand)', 'P', 'Grille 7 jours × 6 habitudes au plus'],
  ['F21', 'Widget « Taux de réussite » (petit, moyen)', 'P', '% du mois en cours, anneau, une ligne par habitude'],
  ['F22', 'Ligne « Habitudes x/y » de « Ma journée » et « Maintenant » ; « Analyse productivité »', 'P', 'Dans des widgets Premium'],
  ['F23', 'Notifications intelligentes « Habitudes »', 'G', 'Il en reste N, série, nouveau record, bilan du dimanche'],
  ['F24', 'Encouragement « Belle série »', 'G', 'Aux paliers 7, 21, 30, 50, 100, 200, 365 jours'],
  ['F25', 'Page d\'espace « Habitudes » (côté Créer)', 'G', 'Widgets de l\'espace, « Mes habitudes », série par habitude'],
  ['F26', 'Compteurs d\'habitudes ailleurs', 'G', 'Tuile du Profil, « Mes informations »'],
  ['F27', 'Liens profonds', 'G', 'tessera://habits et tessera://space/habits'],
  ['F28', 'Widget « Hydratation » rangé dans la catégorie « Habitudes » de Créer', 'G', 'Ce n\'est pas une habitude ; à garder ou à déplacer'],
];
const FEATURES = FONCTIONS;

/* ================= 2. Les données d'exemple : jeudi 12 novembre 2026, 13 h 20 ================= */
const HAB = (function () {
  const MOIS = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juill.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  const JS = ['dim.', 'lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.'];
  const dt = (o) => new Date(2026, 10, 12 - o);                                   // o = nombre de jours avant aujourd'hui (0 = jeudi 12 novembre)
  const lib = (o) => JS[dt(o).getDay()] + ' ' + dt(o).getDate() + ' ' + MOIS[dt(o).getMonth()];
  const pc = (r) => Math.round(r * 100);

  /* ---------- les 5 habitudes (mêmes noms et même état à 13 h 20 que HABITS et DAY de cristal.js) ----------
     c : la couleur de l'habitude (une des 8 de l'app : Jade, Cobalt, Corail, Ambre, Lilas, Rose, Olive, Ardoise) ; rappel : heure du rappel quotidien ou null ;
     manques : jours (en jours avant aujourd'hui) où elle n'a PAS été faite ; debut : son premier jour coché (il y a 80 jours). */
  const mk = (id, n, i, c, cn, rappel, fait, manques) => ({ id, n, i, c, cn, rappel, fait, manques, debut: 80 });
  const habits = [
    mk('eau', 'Boire 2 L d\'eau', 'drop', 'var(--c-pla)', 'Cobalt', '15:00', false, [5, 6, 11, 12, 13, 19, 24, 27, 33, 40, 41, 52, 60, 75]),
    mk('lec', 'Lecture 20 min', 'book', 'var(--c-ent)', 'Lilas', '20:00', true, [12, 20, 26, 38, 47, 66]),
    mk('med', 'Méditation', 'leaf', 'var(--c-bud)', 'Jade', null, true, [9, 16, 17, 23, 29, 35, 44, 58, 70]),
    mk('vit', 'Vitamines', 'pill', 'var(--c-nut)', 'Ambre', '08:00', true, [7, 14, 21, 28, 36, 45, 61]),
    mk('cou', 'Coucher avant 23 h', 'moon', 'var(--c-pro)', 'Ardoise', '21:30', false, [4, 5, 9, 10, 15, 18, 22, 25, 28, 34, 46, 53, 67]),
  ];
  const faitLe = (h, o) => o >= 0 && o <= h.debut && !h.manques.includes(o) && (o > 0 || h.fait);
  const serie = (h) => { let o = faitLe(h, 0) ? 0 : 1, n = 0; while (faitLe(h, o)) { n++; o++; } return n; };   // jusqu'à aujourd'hui ; si aujourd'hui n'est pas fait, jusqu'à hier
  const meilleure = (h) => { let b = 0, n = 0; for (let o = 0; o <= h.debut; o++) { n = faitLe(h, o) ? n + 1 : 0; b = Math.max(b, n); } return b; };
  const taux = (h, N) => { const j = Math.min(N, h.debut + 1); let f = 0; for (let o = 0; o < j; o++) if (faitLe(h, o)) f++; return f / j; };   // jours faits ÷ jours écoulés, sans remonter avant le premier jour coché
  habits.forEach((h) => { h.serie = serie(h); h.meilleure = meilleure(h); h.t30 = taux(h, 30); h.t90 = taux(h, 90); });
  const par = {}; habits.forEach((h) => { par[h.id] = h; });
  const serieTxt = (h) => (h.serie > 0 ? 'Série de ' + h.serie + (h.serie === 1 ? ' jour' : ' jours') : 'Pas encore de série');
  const faites = habits.filter((h) => h.fait), afaire = habits.filter((h) => !h.fait);
  const longue = habits.reduce((a, b) => (b.serie > a.serie ? b : a));            // la carte de Mon quotidien montre la série la plus longue

  /* ---------- la semaine civile (lundi 9 → dimanche 15 novembre) : offsets 3, 2, 1, 0 puis le futur (non dessiné) ---------- */
  const semOff = [3, 2, 1, 0, -1, -2, -3];
  const coches = habits.reduce((s, h) => s + semOff.filter((o) => o >= 0 && faitLe(h, o)).length, 0);
  const ecoules = semOff.filter((o) => o >= 0).length;                           // 4 jours écoulés
  /* semaine k avant celle-ci (k = 0 : la semaine en cours, 4 jours écoulés) : part des coches sur (jours écoulés × habitudes) */
  const semaineTaux = (k) => { const offs = k === 0 ? [3, 2, 1, 0] : [3, 2, 1, 0, -1, -2, -3].map((o) => o + 7 * k); let f = 0; offs.forEach((o) => habits.forEach((h) => { if (faitLe(h, o)) f++; })); return f / (offs.length * habits.length); };
  const semaines = [7, 6, 5, 4, 3, 2, 1, 0].map((k) => ({ k, taux: semaineTaux(k), lundi: dt(3 + 7 * k).getDate(), cur: k === 0 }));

  /* ---------- tous les jours des 30 derniers : jours où TOUT est fait (aujourd'hui compte comme non complet : « Boire 2 L d'eau » reste à faire) ---------- */
  let complets = 0; for (let o = 0; o < 30; o++) if (habits.every((h) => faitLe(h, o))) complets++;
  const total30 = habits.reduce((s, h) => s + Math.round(h.t30 * 30), 0);

  /* ---------- un compte gratuit : la limite est de 3 ; les trois premières habitudes restent ---------- */
  const gratuit = { limite: 3, habits: habits.slice(0, 3) }; gratuit.faites = gratuit.habits.filter((h) => h.fait).length;

  const N = {
    date: 'Jeudi 12 novembre 2026', court: 'jeu. 12 nov.', heure: '13:20',
    compte: { premium: true, limiteGratuite: 3 },
    habits, par, faites, afaire, longue, nbFaites: faites.length, total: habits.length, p: faites.length / habits.length,   // 3 sur 5, 60 %
    serieMax: longue.serie,                                                                                                // « Série de 12 jours »
    gratuit,
    /* ----- carte de Mon quotidien (pleine largeur) : mêmes mots, même chiffre, même icône (repeat) ----- */
    quotidien: { titre: 'Habitudes', icone: 'repeat', chiffre: faites.length + '/' + habits.length, mot: 'faites aujourd\'hui', serie: 'Série de ' + longue.serie + ' jours' },
    semaine: { off: semOff, coches, ecoules, total: ecoules * habits.length, taux: coches / (ecoules * habits.length), lab: ['L', 'M', 'M', 'J', 'V', 'S', 'D'] },
    semaines,
    bilan: { t30: total30 / (habits.length * 30), complets, jours: 30 },
    mois: { titre: 'Novembre 2026' },
    /* ----- fiche « Habitude » ----- */
    icones: ['repeat', 'book', 'drop', 'moon', 'flame', 'pill', 'steps', 'dumbbell', 'fork', 'leaf', 'coffee', 'sun', 'bed', 'bulb', 'pencil', 'music', 'star', 'target', 'bell', 'timer'],
    couleurs: [['Jade', 'var(--c-bud)'], ['Cobalt', 'var(--c-pla)'], ['Corail', 'var(--c-fit)'], ['Ambre', 'var(--c-nut)'], ['Lilas', 'var(--c-ent)'], ['Rose', 'var(--c-pho)'], ['Olive', 'var(--c-hab)'], ['Ardoise', 'var(--c-pro)']],
    notif: { texte: 'C\'est le moment de valider ton habitude du jour.', defaut: '20:00' },
    intelligents: 'Les habitudes qu\'il te reste à faire, ta série, un record battu et le bilan de la semaine.',
    vide: { t: 'Tes habitudes', p: 'Lire, marcher, méditer… Coche-les chaque jour et regarde ta série grandir.', btn: 'Ajouter une habitude', champ: 'Ex. : méditer, lire, marcher' },
    limiteTxt: (n) => n + ' sur 3 habitudes en version gratuite.',

    /* ----- CE QUI N'EXISTE PAS dans l'app : à étiqueter « Nouveau » (jeton, légende, case de texte). Jamais ailleurs. ----- */
    nouveau: {
      groupes: ['À faire', 'Faites'],                                               // séparation « réalisées » / « à accomplir » (MISSION, partie E ; audit 9, n° 8)
      detail: { mois: 'Novembre 2026', fait: 'Faite aujourd\'hui' },                // page de détail, calendrier du mois (audit 9, n° 4, 5)
      bilan: 'Bilan',                                                               // taux global, semaines, jours complets (audit 9, n° 6)
      frequence: { t: 'Fréquence', choix: ['Chaque jour', 'Certains jours'], jours: ['L', 'M', 'M', 'J', 'V', 'S', 'D'], choisis: [0, 2, 4] },   // habitudes hebdomadaires (audit 9, n° 2)
      miniapp: 'Mes paramètres',                                                    // Habitudes devient une mini-app à part (audit 9, n° 1)
    },

    /* ----- outils de texte (français du Canada) ----- */
    lib, faitLe, pct: (r) => PL.pct(r), jours: (n) => n + ' jour' + (n > 1 ? 's' : ''),
    serieTxt,
  };

  /* ----- contrôle : les repères de cristal.js et du guide ne sont pas contredits ; les calculs sont justes ----- */
  N.verifier = function () { const err = [], ok = (c, m) => { if (!c) err.push(m); };
    ok(FONCTIONS.length === 28 && FONCTIONS.every((f, i) => f[0] === 'F' + (i + 1)), 'FONCTIONS : 28 fonctions attendues, F1 à F28 dans l\'ordre');
    ok(FONCTIONS.filter((f) => f[2] !== 'G').length === 5, 'FONCTIONS : 5 fonctions avec une part Premium attendues (F13, F14, F20, F21, F22)');
    ok(habits.length === 5 && habits.length > N.compte.limiteGratuite, '5 habitudes, au-dessus de la limite gratuite : compte Premium');
    ok(faites.length === 3 && faites.map((h) => h.n).join('|') === 'Lecture 20 min|Méditation|Vitamines', '3 faites sur 5 à 13:20 : Lecture, Méditation, Vitamines');
    ok(N.serieMax === 12, 'Série la plus longue : 12 jours');
    ok(habits.every((h) => h.serie <= 12), 'Aucune série au-dessus de 12 jours');
    ok(!par.eau.fait && !par.cou.fait && par.eau.serie === 4 && par.cou.serie === 3, 'Les deux à faire gardent la série d\'hier');
    ok(habits.every((h) => h.t30 > 0 && h.t30 < 1), 'Régularités entre 0 et 100 %');
    if (typeof HABITS !== 'undefined') ok(HABITS.length === habits.length && HABITS.every((h, i) => h.t === habits[i].n), 'cristal.js HABITS : mêmes noms, même ordre');
    if (typeof DAY !== 'undefined') { const d = DAY.journee.habits; ok(d.done === faites.length && d.total === habits.length && d.streak === N.serieMax, 'cristal.js DAY.journee.habits'); }
    err.forEach((m) => console.error('habitudes.js : ' + m));
    return err; };
  return N;
})();
HAB.verifier();

/* ================= 3. Pièces d'écran communes aux planches d'Habitudes (HAB.ui) ================= */
HAB.ui = {
  // anneau du jour : « 3/5 » et « faites » (le grand chiffre de la carte de Mon quotidien)
  ring: (o = {}) => PL.ring(HAB.p, { s: 96, sw: 9, b: HAB.nbFaites + '/' + HAB.total, small: 'faites', aria: HAB.nbFaites + ' habitudes faites sur ' + HAB.total + ' aujourd\'hui', ...o }),
  // ligne d'une habitude : rond à cocher (44 points), icône à sa couleur, nom, série, régularité sur 30 jours, chevron.
  // VoiceOver : « Valider <nom> » ou « Marquer <nom> comme non fait ».
  ligne: (h) => `<div class="li"><span class="hab-ck${h.fait ? ' ok' : ''}" role="button" aria-label="${h.fait ? 'Marquer ' + h.n + ' comme non fait' : 'Valider ' + h.n}"><u>${h.fait ? '<i data-i="check"></i>' : ''}</u></span>`
    + `<div class="tx"><b class="hab-nm"><i data-i="${h.i}" style="color:${h.c}"></i><span>${h.n}</span></b><span class="s">${HAB.serieTxt(h)}</span></div>`
    + `<div class="pl-r"><b>${PL.pct(h.t30)}</b></div><i class="go" data-i="chev"></i></div>`,
  // « Cette semaine » : une rangée par habitude, 7 jours (futur en pointillés)
  semaine: () => { const S = HAB.semaine;
    return `<div class="hab-wk" role="img" aria-label="Cette semaine : ${S.coches} validations sur ${S.total}">`
      + '<span></span>' + S.lab.map((d, k) => `<span class="d${S.off[k] === 0 ? ' t' : ''}">${d}</span>`).join('')
      + HAB.habits.map((h) => `<span class="n"><i data-i="${h.i}" style="color:${h.c}"></i>${h.n}</span>` + S.off.map((o) => (o < 0 ? '<span class="c f"></span>' : HAB.faitLe(h, o) ? '<span class="c on"><i data-i="check"></i></span>' : '<span class="c"></span>')).join('')).join('')
      + '</div>'; },
  // grille des 26 dernières semaines d'une habitude : colonnes du lundi au dimanche, la dernière est la semaine en cours
  grille: (h) => { let s = '', f = 0;
    for (let c = 0; c < 26; c++) for (let r = 0; r < 7; r++) { const o = (25 - c) * 7 + (3 - r);
      if (o < 0) s += '<s class="f"></s>'; else if (o > h.debut) s += '<s class="pre"></s>'; else { const d = h.manques.includes(o) || (o === 0 && !h.fait) ? '' : 'on'; if (d) f++; s += `<s class="${d}"></s>`; } }
    return `<div class="hab-gr" role="img" aria-label="Les 26 dernières semaines : ${f} jours faits depuis le premier jour coché">${s}</div>`; },
  // jours faits de novembre (numéros du mois), pour PL.cal
  novembre: (h) => { const a = []; for (let o = 0; o <= 11; o++) if (HAB.faitLe(h, o)) a.push(12 - o); return a; },
};
