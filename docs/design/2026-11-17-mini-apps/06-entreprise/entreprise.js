/* entreprise.js : le JS commun du sujet « Entreprise » (« Business » dans l'app), refonte UX/UI des mini-apps, 2026-11-17.
   À charger après ../../2026-11-15-cristal/cristal.js et ../base/planches.js, avant le script de la planche.
   Il contient :
     FONCTIONS (alias FEATURES)  la liste F1…F27 de l'audit (../audit/06-entreprise.md, section 4), dans son ordre, avec ses numéros.
                                 [n°, libellé court, accès 'G' | 'P' | 'G+P', ce qu'elle fait en quelques mots]
     ENT                         les données d'exemple du sujet pour le jeudi 12 novembre 2026, 13 h 20, et quelques outils de texte.
     ENT.ui                      pièces d'écran communes (ligne de vente, ligne de mois, pourcentage signé).
   Règles :
     - Aucun repère existant pour ce sujet : ce fichier fixe UNE FOIS l'entreprise d'exemple, « Atelier Nova » (le nom des données de
       démonstration de l'app, audit section 10), petite entreprise québécoise de vente en ligne et d'abonnements, objectif de 12 000 $ par mois.
     - Tout est en dollars canadiens. Les taxes (TPS, TVQ) ne sont PAS calculées par l'app : aucune n'apparaît ici (voir ENT.nouveau).
     - Chaque chiffre vient d'une saisie (listes ventes, depenses, mrr, suivis) par les calculs de l'audit, section 5 : chiffre d'affaires = somme des
       ventes, bénéfice = CA − dépenses, marge = bénéfice ÷ CA, panier moyen = CA ÷ commandes, période précédente coupée au même point.
       Seuls les neuf premiers mois de l'année (ENT.moisAvant) sont saisis en totaux : le journal détaillé ne montre que octobre et novembre.
     - Compte montré : GRATUIT. Saisie à la main seulement ; Stripe et l'import CSV sont Premium (badge sur les deux lignes).
     - Ce qui n'existe pas dans l'app est rangé sous ENT.nouveau et nulle part ailleurs : à étiqueter « Nouveau » sur les planches. */

/* ================= 1. Les 27 fonctions existantes (audit, section 4) ================= */
const FONCTIONS = [
  ['F1', 'Chiffre d\'affaires de la période', 'G', 'CA du début de la période au jour choisi ; variation contre la période d\'avant'],
  ['F2', 'Choix de la période', 'G', '« Jour », « Semaine », « Mois », « Année »'],
  ['F3', 'Sélecteur de semaine avec repères', 'G', 'Les 7 jours, un point sur les jours avec une opération ; jamais de jour futur'],
  ['F4', 'Objectif mensuel de chiffre d\'affaires', 'G', '« x % de l\'objectif de y $ » en « Mois »'],
  ['F5', 'Ajouter une vente', 'G', 'Montant, date, commandes, nouveaux clients, visiteurs, note'],
  ['F6', 'Ajouter une dépense', 'G', 'Montant, libellé, date'],
  ['F7', 'Modifier ou supprimer une vente ou une dépense', 'G', 'Toucher, changer, « Supprimer… », balayer'],
  ['F8', 'Indicateurs au choix (11)', 'G', 'Cocher parmi 11 ; valeur et variation ; défaut : CA, Bénéfice, Commandes, Panier moyen'],
  ['F9', 'Courbe du chiffre d\'affaires cumulé', 'G', 'Période en cours contre la précédente'],
  ['F10', 'Journal « Ventes et dépenses »', 'G', 'Ventes ou dépenses, par mois, avec le total du mois'],
  ['F11', 'Résultats : totaux de l\'année', 'G', '« Depuis le 1er janvier » : CA, bénéfice, marge'],
  ['F12', 'Résultats : analyse mois par mois', 'P', 'Graphique des 6 derniers mois ; liste « Mois par mois »'],
  ['F13', 'Revenu récurrent', 'G', 'MRR, ARR, abonnés, courbe, liste des mois ; « Mettre à jour le MRR »'],
  ['F14', 'Suivis à la main (indicateurs personnels)', 'G', 'Nom, unité, valeur, variation, objectif, courbe ; « Noter une valeur »'],
  ['F15', 'Importer un fichier CSV', 'P', 'Aperçu du fichier, « Des ventes » ou « Des dépenses », opérations non payées'],
  ['F16', 'Conversion de devise', 'P', 'Taux de la BCE ; « Réessayer », « Importer sans conversion »'],
  ['F17', 'Connecter Stripe en lecture seule', 'P', 'Clé restreinte rk_, trois étapes'],
  ['F18', 'Synchronisation Stripe', 'P', '« Synchroniser » ; seule à l\'ouverture si la dernière a plus d\'une heure'],
  ['F19', 'Déconnecter Stripe', 'G', 'Garder ou retirer les ventes venues de Stripe ; toujours possible'],
  ['F20', 'Stripe connecté, Premium arrêté', 'G', 'Les ventes déjà importées restent ; « Synchroniser » ouvre l\'offre'],
  ['F21', 'Nom, objectif, clients', 'G', 'Le nom devient le titre de l\'écran et du widget « Tableau de bord business »'],
  ['F22', 'Devise de l\'app', 'G', 'CAD, USD, EUR, GBP, CHF'],
  ['F23', 'Fusion sans doublon des opérations importées', 'P', 'Automatique ; une ligne tapée à la main n\'est jamais touchée'],
  ['F24', 'Widgets d\'entreprise', 'G+P', '7 widgets : 1 gratuit, 6 Premium'],
  ['F25', 'Carte de Mon quotidien', 'G', '« x $ ce mois », ou l\'invitation « Note tes ventes… »'],
  ['F26', 'Page de données de l\'espace : toutes les périodes d\'un coup', 'G', 'Cinq chiffres, trois boutons, 15 dernières ventes'],
  ['F27', 'Présence dans « Mes informations »', 'G', 'Pastille et ligne « Mon entreprise » : « À compléter » ou ✓'],
];
const FEATURES = FONCTIONS;

/* ================= 2. Les données d'exemple : jeudi 12 novembre 2026, 13 h 20 ================= */
const ENT = (function () {
  const MOIS = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juill.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  const MOIS_L = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
  const JS = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
  const dt = (m, j) => new Date(2026, m - 1, j);                                          // m = 1 à 12
  const AUJ = dt(11, 12);
  const dow = (d) => (d.getDay() + 6) % 7;                                                // 0 = lundi
  const dateC = (d) => JS[dow(d)] + ' ' + d.getDate() + ' ' + MOIS[d.getMonth()];         // « jeu. 12 nov. »
  const sum = (L, f) => L.reduce((s, x) => s + f(x), 0);
  const ent = (L, a, b) => L.filter((x) => x.d >= a && x.d <= b);
  const plur = (n, un, plus) => n + NBSP + (n > 1 ? plus : un);
  const sg = (p, dec = 1) => (p >= 0 ? '+' : '−') + PL.n(Math.abs(p * 100), dec) + NBSP + '%';  // +24,9 %

  /* ---------- ventes saisies (SalesEntry) : date, montant, commandes, nouveaux clients, visiteurs, note ----------
     Octobre 1–12 et novembre 1–11 : saisis jour par jour. Octobre 13–31 : seuls les totaux du jour comptent (commandes déduites du montant). */
  const V = (m, j, a, o, n, v, note) => ({ d: dt(m, j), a, o, n, v, note: note || '' });
  const A = (j, a) => { const o = Math.max(1, Math.round(a / 110)); return V(10, j, a, o, Math.floor(o / 3), o * 30); };
  const ventes = [
    V(10, 1, 402, 4, 1, 118), V(10, 2, 515, 5, 1, 135), V(10, 3, 198, 2, 0, 84), V(10, 5, 560, 5, 2, 140), V(10, 6, 447, 4, 1, 121),
    V(10, 7, 331, 3, 1, 102), V(10, 8, 612, 5, 2, 160), V(10, 9, 376, 3, 1, 109), V(10, 10, 211, 2, 0, 78), V(10, 12, 237, 2, 1, 81),
    A(13, 331), A(14, 402), A(15, 455), A(16, 389), A(17, 212), A(19, 418), A(20, 471), A(21, 366), A(22, 527), A(23, 440),
    A(24, 183), A(26, 412), A(27, 484), A(28, 390), A(29, 479), A(30, 402), A(31, 168),
    V(11, 2, 412, 4, 1, 130), V(11, 3, 689, 6, 2, 168), V(11, 4, 359, 3, 1, 112), V(11, 5, 845, 7, 3, 190, 'Commande groupée'), V(11, 6, 532, 5, 1, 151),
    V(11, 7, 227, 2, 0, 96, 'Marché du samedi'), V(11, 9, 615, 5, 2, 144), V(11, 10, 478, 4, 1, 127), V(11, 11, 702, 6, 2, 173),
  ];
  /* ---------- dépenses saisies (BusinessExpense) : date, montant, libellé (pas de catégorie) ---------- */
  const X = (m, j, a, l) => ({ d: dt(m, j), a, l });
  const depenses = [
    X(10, 1, 29, 'Hébergement'), X(10, 2, 240, 'Publicité'), X(10, 5, 89, 'Logiciels'), X(10, 8, 450, 'Sous-traitance'), X(10, 9, 112, 'Frais de paiement'), X(10, 11, 189, 'Matériel'),
    X(10, 15, 260, 'Publicité'), X(10, 18, 340, 'Matériel'), X(10, 20, 450, 'Sous-traitance'), X(10, 27, 220, 'Publicité'), X(10, 31, 296, 'Frais de paiement'),
    X(11, 3, 240, 'Publicité'), X(11, 4, 29, 'Hébergement'), X(11, 6, 450, 'Sous-traitance'), X(11, 9, 312, 'Matériel'), X(11, 10, 89, 'Logiciels'),
  ];

  /* ---------- BusinessMath : une période = ventes et dépenses entre deux dates ---------- */
  const per = (a, b) => { const v = ent(ventes, a, b), d = ent(depenses, a, b), ca = sum(v, (x) => x.a), dep = sum(d, (x) => x.a), cmd = sum(v, (x) => x.o);
    return { ca, dep, benef: ca - dep, marge: ca ? (ca - dep) / ca : null, cmd, nouv: sum(v, (x) => x.n), vis: sum(v, (x) => x.v), panier: cmd ? ca / cmd : null, conv: sum(v, (x) => x.v) ? cmd / sum(v, (x) => x.v) : null, nV: v.length, nD: d.length, v, d }; };
  const vari = (a, b) => (b ? (a - b) / b : null);                                        // variation nulle si la période d'avant vaut 0
  const mois = per(dt(11, 1), AUJ), avant = per(dt(10, 1), dt(10, 12)), octobre = per(dt(10, 1), dt(10, 31));
  const objectif = 12000, jRestants = 30 - AUJ.getDate();
  const reste = objectif - mois.ca;
  const cumul = (m, nj, jusque) => { let s = 0; const r = []; for (let j = 1; j <= nj; j++) { if (j > jusque) { r.push(null); continue; } s += sum(ventes.filter((x) => x.d.getMonth() === m - 1 && x.d.getDate() === j), (x) => x.a); r.push(s); } return r; };

  /* ---------- les 9 premiers mois de l'année : totaux saisis (janvier à septembre) ---------- */
  const moisAvant = [['janvier', 6840, 2310], ['février', 7120, 2480], ['mars', 7960, 2690], ['avril', 7540, 2540], ['mai', 8410, 2760], ['juin', 8230, 2710], ['juillet', 7880, 2640], ['août', 8650, 2890], ['septembre', 9380, 3050]];
  const annee = { ca: sum(moisAvant, (m) => m[1]) + octobre.ca + mois.ca, dep: sum(moisAvant, (m) => m[2]) + octobre.dep + mois.dep };
  annee.benef = annee.ca - annee.dep; annee.marge = annee.benef / annee.ca;
  const six = moisAvant.slice(3).map((m) => ({ n: m[0], ca: m[1], dep: m[2] })).concat([{ n: 'octobre', ca: octobre.ca, dep: octobre.dep }, { n: 'novembre', ca: mois.ca, dep: mois.dep }]).slice(-6);

  /* ---------- revenu récurrent (SubscriptionSnapshot) : mois, MRR, abonnés ---------- */
  const mrr = [['juin', 2100, 60], ['juillet', 2380, 66], ['août', 2660, 73], ['septembre', 2905, 79], ['octobre', 3180, 85], ['novembre', 3420, 90]].map(([m, v, s]) => ({ m, mrr: v, abonnes: s, parAbonne: v / s }));
  const dMrr = mrr[mrr.length - 1], pMrr = mrr[mrr.length - 2];

  /* ---------- suivis à la main (CustomMetric) : nom, objectif, valeurs (une par jour) ---------- */
  const suivi = (n, obj, vals, u) => { const d = vals[vals.length - 1], p = vals[vals.length - 2];
    return { n, u: u || '', obj, vals: vals.map((x) => x[1]), dern: d[1], date: d[0], prec: p[1], vari: vari(d[1], p[1]), atteint: d[1] / obj }; };
  const suivis = [
    suivi('Abonnés Instagram', 2500, [['29 oct.', 1712], ['2 nov.', 1738], ['5 nov.', 1785], ['11 nov.', 1842]]),
    suivi('Devis envoyés', 10, [['27 oct.', 4], ['30 oct.', 5], ['3 nov.', 5], ['10 nov.', 7]]),
  ];

  /* ---------- le sélecteur de semaine : jours repérés (une vente ou une dépense), lundi 9 → dimanche 15 ---------- */
  const marks = [0, 1, 2, 3, 4, 5, 6].filter((k) => ventes.concat(depenses).some((x) => x.d.getTime() === dt(11, 9 + k).getTime()));

  const N = {
    date: 'Jeudi 12 novembre 2026', court: 'jeu. 12 nov.', heure: '13:20',
    compte: { premium: false },
    MOIS, MOIS_L, JS, dt, dateC, plur, sg, vari,
    profil: { nom: 'Atelier Nova', objectif, clients: 38, devise: 'CAD' },
    ventes, depenses, mrr, suivis, six, moisAvant, annee, marks,
    /* ----- « Mois » : du 1er au 12 novembre contre du 1er au 12 octobre (le jour choisi est aujourd'hui) ----- */
    mois, avant, octobre,
    periode: { texte: 'Du 1er au 12 nov.', texteLong: 'Du 1er au 12 novembre', avant: 'Du 1er au 12 oct.' },
    hero: { ca: mois.ca, vari: vari(mois.ca, avant.ca), phrase: 'par rapport au mois dernier à la même date' },
    // « x % de l'objectif de y $ » : CA du mois ÷ objectif (le mois entier, ici le même chiffre : rien n'est noté après aujourd'hui)
    objectifMois: { p: mois.ca / objectif, pct: Math.round(mois.ca / objectif * 100), obj: objectif, reste, jRestants, parJour: Math.round(reste / jRestants) },
    kpis: { benef: { v: mois.benef, vari: vari(mois.benef, avant.benef) }, cmd: { v: mois.cmd, vari: vari(mois.cmd, avant.cmd) }, panier: { v: mois.panier, vari: vari(mois.panier, avant.panier) } },
    cumul: { nov: cumul(11, 30, 12), oct: cumul(10, 31, 31) },
    /* ----- les 11 indicateurs au choix (Business.swift:50-68), cochés par défaut : les quatre premiers du groupe « coches » ----- */
    indicateurs: { coches: ['Chiffre d\'affaires', 'Bénéfice', 'Commandes', 'Panier moyen'], autres: ['Dépenses', 'Marge', 'Nouveaux clients', 'Visiteurs', 'Conversion', 'MRR', 'Abonnés'] },
    recurrent: { mrr: dMrr.mrr, arr: dMrr.mrr * 12, abonnes: dMrr.abonnes, parAbonne: dMrr.parAbonne, croissance: vari(dMrr.mrr, pMrr.mrr) },
    /* ----- Mon quotidien : carte « Business » (demi-largeur), icône mallette, violet ; chiffre vedette = le chiffre d'affaires du mois ----- */
    quotidien: { titre: 'Business', icone: 'briefcase', vedette: PL.m(mois.ca), ligne: PL.m(mois.ca) + ' ce mois', vide: 'Note tes ventes : ton chiffre d\'affaires du mois apparaîtra ici.' },
    /* ----- libellés de l'app repris de l'audit ----- */
    txt: {
      depart: 'Ton activité, chiffres à l\'appui',
      stripe: 'Les données vont directement de ton iPhone à Stripe, sans passer par Ardane.',
      verrou: 'L\'analyse mois par mois est dans Premium',
    },
    /* ----- CE QUI N'EXISTE PAS dans l'app : à étiqueter « Nouveau » (jeton, légende, case de texte). Jamais ailleurs. ----- */
    nouveau: {
      // audit section 9 : « Rappels de saisie » ; problème 27 : aucun rappel alors que l'usage repose sur une saisie régulière
      rappel: { titre: 'Rappel de saisie', heure: '17:00', texte: 'Si rien n\'est noté de la journée' },
      // audit section 9 : « ordre des tuiles » ; problème 21 : l'ordre est celui des coches, sans moyen de le changer
      ordre: { titre: 'Affichés', glisser: 'Glisser pour changer l\'ordre' },
    },
    /* ----- outils de texte (français du Canada) ----- */
    m: (x) => PL.m(x), pct: (p) => PL.pct(p),
    ligneVente: (e) => [plur(e.o, 'commande', 'commandes'), e.n ? plur(e.n, 'nouveau client', 'nouveaux clients') : '', e.note].filter(Boolean).join(' · '),
  };

  /* ----- contrôle : les calculs sont justes, aucun zéro inventé ----- */
  N.verifier = function () { const err = [], ok = (c, m) => { if (!c) err.push(m); };
    ok(FONCTIONS.length === 27 && FONCTIONS.every((f, i) => f[0] === 'F' + (i + 1)), 'FONCTIONS : 27 fonctions attendues, F1 à F27 dans l\'ordre');
    ok(FONCTIONS.filter((f) => f[2] !== 'G').map((f) => f[0]).join() === 'F12,F15,F16,F17,F18,F23,F24', 'FONCTIONS : Premium F12, F15, F16, F17, F18, F23 et la part de F24');
    ok(mois.ca === 4859 && mois.dep === 1120 && mois.benef === 3739 && mois.cmd === 42 && mois.nV === 9 && mois.nD === 5, 'Novembre au 12 : CA 4 859, dépenses 1 120, bénéfice 3 739, 42 commandes');
    ok(avant.ca === 3889 && avant.dep === 1109 && avant.cmd === 35, 'Octobre au 12 : CA 3 889, dépenses 1 109, 35 commandes');
    ok(Math.round(N.hero.vari * 1000) === 249, 'Variation du CA : +24,9 %');
    ok(N.objectifMois.pct === 40 && N.objectifMois.parJour === 397 && reste === 7141, 'Objectif : 40 %, il reste 7 141 $, environ 397 $ par jour');
    ok(Math.round(mois.panier) === 116 && Math.round(avant.panier) === 111, 'Panier moyen 116 $ contre 111 $');
    ok(octobre.ca === 10418 && octobre.dep === 2675, 'Octobre : CA 10 418, dépenses 2 675');
    ok(annee.ca === 87287 && annee.dep === 27865 && annee.benef === 59422 && Math.round(annee.marge * 100) === 68, 'Année : CA 87 287, dépenses 27 865, bénéfice 59 422, marge 68 %');
    ok(N.cumul.nov[11] === mois.ca && N.cumul.nov[12] === null && N.cumul.oct[30] === octobre.ca, 'Courbes : le dernier point = le total de la période');
    ok(N.recurrent.arr === 41040 && Math.round(N.recurrent.croissance * 1000) === 75 && N.recurrent.parAbonne === 38, 'MRR 3 420, ARR 41 040, +7,5 %, 38 $ par abonné');
    ok(marks.join() === '0,1,2' && JS[dow(AUJ)] === 'jeu.' && AUJ.getDay() === 4, 'Jours repérés : lundi à mercredi ; jeudi 12 novembre 2026');
    ok(Math.round(suivis[0].atteint * 100) === 74 && Math.round(suivis[1].atteint * 100) === 70, 'Suivis : 74 % et 70 % de l\'objectif');
    err.forEach((m) => console.error('entreprise.js : ' + m));
    return err; };
  return N;
})();
ENT.verifier();

/* ================= 3. Pièces d'écran communes aux planches d'Entreprise (ENT.ui) ================= */
ENT.ui = {
  // variation signée, avec son signe (jamais la couleur seule) : « +24,9 % »
  vari: (p) => `<b class="ent-v${p < 0 ? ' neg' : ''}">${ENT.sg(p)}</b>`,
  // ligne du journal des ventes : date, « 4 commandes · 1 nouveau client », montant
  vente: (e) => PL.row('', ENT.dateC(e.d), ENT.ligneVente(e), { r: PL.m(e.a), chev: false }),
  // ligne du journal des dépenses : libellé, date, montant
  depense: (e) => PL.row('', e.l, ENT.dateC(e.d), { r: PL.m(e.a), chev: false }),
};
