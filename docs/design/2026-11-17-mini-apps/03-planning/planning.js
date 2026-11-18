/* planning.js : le JS commun du sujet « Planning » (refonte UX/UI des mini-apps, 2026-11-17).
   À charger après ../../2026-11-15-cristal/cristal.js et ../base/planches.js, avant le script de la planche.
   Il contient :
     FONCTIONS (alias FEATURES)  la liste F1…F32 de l'audit (../audit/03-planning.md, section 4), dans son ordre, avec ses numéros.
                                 [n°, libellé court, accès 'G' | 'P' | 'G+P', ce qu'elle fait en quelques mots]
     PLA                         les données d'exemple du sujet pour le jeudi 12 novembre 2026, 13 h 20, et quelques outils de texte.
     PLA.ui                      pièces d'écran communes (ligne d'agenda, jour heure par heure, mois, année).
   Règles :
     - Les planches du sujet lisent ces données. Aucune planche ne recopie la liste ni ne change un chiffre.
     - Les événements sont ceux de EVENTS (cristal.js), le Top 3 est TOP3, « À ne pas oublier » est REMIND : rien n'est retapé.
       Le prochain événement, « dans 40 min », les compteurs de tâches, les points du mois en sortent par calcul (voir PLA.verifier()).
     - Ce qui n'existe pas dans l'app est rangé sous PLA.nouveau et nulle part ailleurs : à étiqueter « Nouveau » sur les planches.
   Compte montré : GRATUIT. Seule l'importation d'horaire est Premium (F14 à F16) : elle se montre verrouillée (PL.lockCard). */

/* ================= 1. Les 32 fonctions existantes (audit, section 4) ================= */
const FONCTIONS = [
  ['F1', 'Sélecteur de semaine', 'G', 'Titre de la semaine, 7 jours, pastille pleine ou creuse, « Aujourd\'hui »'],
  ['F2', 'Horaire de la semaine en tableau (échelle « Semaine »)', 'G', '7 colonnes, heures, blocs colorés, ligne « maintenant », bandeau sans heure'],
  ['F3', 'Vue « Jour »', 'G', 'Le jour choisi heure par heure, de 6 h à 22 h'],
  ['F4', 'Vue « Mois »', 'G', 'Grille du mois, jusqu\'à 3 points de couleur par jour'],
  ['F5', 'Vue « Année »', 'G', '12 petits mois, jours marqués s\'il s\'y passe une chose ponctuelle'],
  ['F6', 'Changer d\'échelle et de période', 'G', 'Sélecteur « Jour | Semaine | Mois | Année », pincement, balayage'],
  ['F7', 'Créer un événement en touchant une heure libre', 'G', 'Feuille « Nouvel événement » déjà remplie (jour, heure, une heure de durée)'],
  ['F8', 'Éditeur d\'événement', 'G', 'Type, nom ou cours, répétition, heures, lieu, couleur, avertissement de chevauchement'],
  ['F9', 'Série et occurrence', 'G', 'Annuler un jour, modifier ou supprimer « Cette occurrence seulement » ou « Toute la série »'],
  ['F10', 'Ouvrir un élément du calendrier', 'G', 'Événement, tâche, examen, devoir : leur feuille ; calendrier Apple : app Calendrier'],
  ['F11', 'Liste du jour choisi', 'G', 'Heure ou « Journée », barre de couleur, titre, détail, rond à cocher'],
  ['F12', 'Agenda qui réunit 7 sources', 'G', 'Calendrier Apple, horaire, examens, devoirs, tâches datées, échéances, séances'],
  ['F13', 'Calendrier Apple, en lecture', 'G', 'Donner l\'accès ; rien n\'est écrit dans le calendrier Apple'],
  ['F14', 'Import d\'horaire : choisir la source', 'P', 'Caméra, photo ou PDF'],
  ['F15', 'Import d\'horaire : vérifier et corriger', 'P', 'Ce qui a été lu, rangé par jour, avec « À vérifier »'],
  ['F16', 'Import d\'horaire : ajouter', 'P', '« Ajouter à mon horaire (N) » ou « Remplacer l\'ancien »'],
  ['F17', 'Nouvelle tâche', 'G', 'Feuille « Nouvelle tâche », échéance au jour choisi'],
  ['F18', 'Éditeur de tâche', 'G', 'Titre, priorité, échéance, heure, répétition, notes'],
  ['F19', 'Tâche répétée', 'G', 'Cocher crée la suivante à sa prochaine date'],
  ['F20', 'Top 3 du jour', 'G', 'Jusqu\'à 3 priorités, « n/3 » ; valider, retirer'],
  ['F21', 'Compteurs de tâches', 'G', '« En retard », « Aujourd\'hui », « À faire »'],
  ['F22', 'Page « Tâches »', 'G', 'Filtres, sections triées par priorité, ajout rapide, cocher, glisser pour supprimer'],
  ['F23', 'Page « Projets »', 'G', 'Tâches par projet, « Modifier le projet », « Nouveau projet »'],
  ['F24', 'Éditeur de projet', 'G', 'Nom, couleur, échéance, tâches du projet'],
  ['F25', 'Accès aux habitudes', 'G', 'Ligne « Habitudes » : « faites/total » du jour'],
  ['F26', '« À remplir »', 'G', '« x / 2 » : « Habitudes » et « Cours et horaire »'],
  ['F27', '« Mes paramètres »', 'G', '« Ton objectif du moment », « Ton rythme », « Heure sur 24 h »'],
  ['F28', '« Mes tâches réalisées » (historique du Top 3)', 'G', 'Priorités validées ; en toucher une la remet dans le Top 3'],
  ['F29', 'Échéances', 'G', 'Titre, date et heure ; vues dans le calendrier'],
  ['F30', 'Compteurs', 'G', 'Nom, valeur du jour, objectif (espace Productivité)'],
  ['F31', 'Liste simple « Tâches »', 'G', 'Ajouter, cocher, réordonner ; ouverte par le widget « Tâches »'],
  ['F32', 'Rappels de Planning', 'G', 'Cinq notifications, catégorie « Planning » du Profil › Rappels'],
];
const FEATURES = FONCTIONS;

/* ================= 2. Les données d'exemple : jeudi 12 novembre 2026, 13 h 20 ================= */
const PLA = (function () {
  const hhmm = (m) => String(Math.floor(m / 60)).padStart(2, '0') + ':' + String(m % 60).padStart(2, '0');
  const maintenant = U.min('13:20');
  const TYPES = { cours: 'Cours', travail: 'Travail', rdv: 'Rendez-vous', seance: 'Séance de sport' };
  const jourSem = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];

  /* ---------- le jeudi : EVENTS de cristal.js, fin = début + 1 h quand EVENTS n'en donne pas (comme U.week) ---------- */
  const evDe = (d) => EVENTS.filter((e) => e.d === d).map((e) => ({ s: e.s, fin: e.e || hhmm(U.min(e.s) + 60), t: e.t, lieu: e.p || '', ty: e.ty, type: TYPES[e.ty] }));
  const jeudi = evDe(3), vendredi = evDe(4);
  const avenir = jeudi.filter((e) => U.min(e.s) >= maintenant);
  const prochain = avenir[0];
  const dans = U.min(prochain.s) - maintenant;                               // 40 minutes

  /* ---------- Top 3 : TOP3 de cristal.js ; la 1re est validée à 13 h 20, elle a disparu de la carte (audit F20) ---------- */
  const top3 = { liste: TOP3, validee: 0, restantes: TOP3.slice(1), n: 1 };

  /* ---------- tâches (TaskItem) : exemple ; les compteurs sont calculés (audit section 5) ---------- */
  const AUJ = 12;
  const taches = [
    { t: 'Envoyer le formulaire de bourse', due: 11, p: 'Haute', fait: false },
    { t: 'Imprimer l\'étude de cas', due: 12, p: 'Moyenne', fait: false },
    { t: 'Préparer les questions de l\'exposé', due: 12, p: 'Haute', fait: false },
    { t: 'Commander les manuels', due: 14, p: 'Moyenne', fait: false },
    { t: 'Renouveler la carte d\'étudiant', due: null, p: 'Basse', fait: false },
    { t: 'Ranger le bureau', due: null, p: 'Aucune', fait: false },
    { t: 'Réserver la salle d\'étude', due: 10, p: 'Moyenne', fait: true },
  ];
  const nonFaites = taches.filter((t) => !t.fait);
  const compteurs = { enRetard: nonFaites.filter((t) => t.due != null && t.due < AUJ).length, aujourdhui: nonFaites.filter((t) => t.due === AUJ).length, aFaire: nonFaites.length };

  /* ---------- projets (Project) ---------- */
  const projets = [
    { n: 'Rapport de marketing', faites: 2, total: 5, ech: '20 nov.' },
    { n: 'Voyage à Lisbonne', faites: 1, total: 4, ech: '12 juin 2027' },      // le même voyage que Finance et Voyage
  ];

  /* ---------- habitudes d'un compte gratuit : les 3 premières (limite gratuite = 3) ; l'état vient de cristal.js ---------- */
  const hab3 = habDone('journee').slice(0, 3);
  const habitudes = { faites: hab3.filter(Boolean).length, total: hab3.length };       // 2/3

  /* ---------- le vendredi 13 : jour choisi des vues Mois et Année (devoir, échéance de « À ne pas oublier ») ---------- */
  const facture = REMIND[0], devoir = REMIND[1];                                       // « Facture Internet » demain 45 $, « Devoir : étude de cas » vendredi
  const jour13 = [
    { h: 'Journée', t: 'Devoir : étude de cas', s: 'Devoir', k: 'devoir', ev: 'cours' },
    { h: 'Journée', t: facture.t, s: 'Échéance · 45 $', k: 'echeance', ev: 'rdv' },
  ].concat(vendredi.map((e) => ({ h: e.s, t: e.t, s: e.e ? 'Jusqu\'à ' + e.fin : (e.lieu || e.type), k: 'evt', ev: e.ty })));

  /* ---------- points du mois (jusqu'à 3 types par jour) : l'horaire se répète chaque semaine ; les rendez-vous seulement le jour même ---------- */
  const ponctuels = { 13: ['cours', 'rdv'], 16: ['seance'], 17: ['rdv'] };                // devoir (couleur cours), facture et assurance (échéances), examen (couleur séance)
  const pointsDu = (j) => { const dow = (new Date(2026, 10, j).getDay() + 6) % 7, t = [];
    EVENTS.filter((e) => e.d === dow && (e.ty !== 'rdv' || j === 12)).forEach((e) => { if (!t.includes(e.ty)) t.push(e.ty); });
    (ponctuels[j] || []).forEach((ty) => { if (!t.includes(ty)) t.push(ty); });
    return t.slice(0, 3); };

  /* ---------- vue Année : jours marqués = seulement ce qui arrive une fois (exemple) ---------- */
  const marques = { 8: [8], 9: [14, 22], 10: [12, 13, 16, 17], 11: [10, 18] };

  const N = {
    date: 'Jeudi 12 novembre 2026', court: 'jeu. 12 nov.', heure: '13:20',
    compte: { premium: false },
    TYPES, jourSem, hhmm, maintenant,
    jeudi, vendredi, avenir, prochain, dans,
    top3, taches, compteurs, projets, habitudes, jour13, pointsDu, marques,
    rappels: REMIND,
    /* ----- carte de Mon quotidien (pleine largeur) : mêmes mots, même icône (calendar), même couleur ; elle montre le tableau, pas de chiffre ----- */
    quotidien: { titre: 'Planning', icone: 'calendar', lien: 'Toute la semaine' },
    /* ----- libellés de l'app repris de l'audit ----- */
    echelles: ['Jour', 'Semaine', 'Mois', 'Année'],
    types: ['Cours', 'Travail', 'Rendez-vous', 'Autre événement'],
    importTxt: 'Premium lit ton horaire à partir d\'une photo ou d\'un PDF, sur ton iPhone. Ajouter tes cours et tes événements à la main reste gratuit.',
    noteTableau: 'Touche une heure libre pour créer un événement. Pince avec deux doigts pour voir plus ou moins de temps.',
    rappelsPlanning: ['Cours dans 30 minutes', 'Rendez-vous demain', 'Examen demain', 'Demain, une journée bien remplie', 'Tâches importantes'],

    /* ----- CE QUI N'EXISTE PAS dans l'app : à étiqueter « Nouveau » (jeton, légende, case de texte). Jamais ailleurs. ----- */
    nouveau: {
      prochain: 'Prochain événement',                    // carte en tête (audit 11, n° 15 ; Chantiers.md:280)
      nouvelEvt: 'Nouvel événement',                     // bouton de création (audit 8, n° 4 ; audit 11, n° 15)
      notes: 'Notes',                                    // information liée à un événement (audit 9, n° 2)
    },
    lib: (j) => jourSem[(new Date(2026, 10, j).getDay() + 6) % 7],
    pct: (r) => PL.pct(r),
  };

  /* ----- contrôle : les repères de cristal.js et du guide ne sont pas contredits ; les calculs sont justes ----- */
  N.verifier = function () { const err = [], ok = (c, m) => { if (!c) err.push(m); };
    ok(FONCTIONS.length === 32 && FONCTIONS.every((f, i) => f[0] === 'F' + (i + 1)), 'FONCTIONS : 32 fonctions attendues, F1 à F32 dans l\'ordre');
    ok(FONCTIONS.filter((f) => f[2] !== 'G').map((f) => f[0]).join() === 'F14,F15,F16', 'FONCTIONS : seules F14, F15, F16 sont Premium');
    ok(jeudi.length === 5 && jeudi.map((e) => e.s + ' ' + e.t).join('|') === '09:00 Comptabilité|11:30 Travail d\'équipe|14:00 Réunion projet|16:30 Dentiste|18:30 Séance Haut du corps', 'Jeudi : 5 événements de EVENTS');
    ok(prochain.t === 'Réunion projet' && prochain.s === '14:00' && dans === 40, 'Prochain événement : Réunion projet à 14:00, dans 40 min');
    ok(avenir.length === 3, '3 événements à venir à 13:20');
    ok(top3.liste.length === 3 && top3.restantes.length === 2 && top3.n === 1, 'Top 3 : 1 faite sur 3');
    ok(compteurs.enRetard === 1 && compteurs.aujourdhui === 2 && compteurs.aFaire === 6, 'Tâches : 1 en retard, 2 aujourd\'hui, 6 à faire');
    ok(habitudes.faites === 2 && habitudes.total === 3, 'Habitudes d\'un compte gratuit : 2 sur 3');
    ok(jour13.length === 4 && jour13[0].h === 'Journée', 'Vendredi 13 : 4 éléments, sans heure d\'abord');
    ok(pointsDu(12).length === 3 && pointsDu(12).join() === 'cours,rdv,seance', 'Points du jeudi 12 : cours, rendez-vous, séance');
    ok(PL.JOUR.dow0 === 6 && new Date(2026, 10, 1).getDay() === 0, 'Novembre 2026 commence un dimanche');
    err.forEach((m) => console.error('planning.js : ' + m));
    return err; };
  return N;
})();
PLA.verifier();

/* ================= 3. Pièces d'écran communes aux planches de Planning (PLA.ui) ================= */
PLA.ui = {
  // tableau de la semaine (WeekTimetable) : 8 h à 20 h, ligne « maintenant » ; la colonne d'un jour est élargie et seule nommée (U.week, focus)
  semaine: (o = {}) => U.week({ from: 8, to: 20, every: 2, now: '13:20', focus: 3, fw: 6.2, labels: 'focus', ...o }),
  // ligne de la liste du jour : heure ou « Journée », barre de couleur du type, titre, détail, rond à cocher ou chevron
  ligne: (x) => `<div class="li"><span class="pla-hr">${x.h}</span><span class="pla-bar" data-ev="${x.ev}"></span>`
    + `<div class="tx"><b>${x.t}</b><span class="s">${x.s}</span></div>`
    + (x.k === 'devoir' ? '<i class="chk" data-i="circle" role="button" aria-label="Marquer le devoir comme rendu"></i>' : '<i class="go" data-i="chev"></i>') + '</div>',
  // vue « Jour » : heures de h0 à h1, hh points par heure ; blocs de EVENTS ; ligne « maintenant »
  jour: (o = {}) => { const h0 = o.h0 ?? 9, h1 = o.h1 ?? 20, hh = o.hh ?? 30, y = (m) => ((m - h0 * 60) / 60 * hh).toFixed(1);
    let s = `<div class="pla-day" role="img" aria-label="Jeudi 12 novembre, de ${h0} h à ${h1} h : ${PLA.jeudi.map((e) => e.t + ' à ' + e.s).join(', ')}" style="height:${(h1 - h0) * hh}px;--hh:${hh}px">`;
    for (let h = h0; h <= h1; h++) s += `<span class="ln" style="top:${y(h * 60)}px"></span>` + (h < h1 ? `<span class="hr" style="top:${y(h * 60)}px">${h}</span>` : '');
    PLA.jeudi.forEach((e) => { const a = U.min(e.s), b = U.min(e.fin);
      s += `<div class="ev" data-ev="${e.ty}" style="top:${y(a)}px;height:${((b - a) / 60 * hh - 2).toFixed(1)}px"><b>${e.t}</b>${e.lieu ? `<small>${e.lieu}</small>` : ''}</div>`; });
    s += `<span class="now" style="top:${y(PLA.maintenant)}px"></span></div>`;
    return s; },
  // vue « Mois » : novembre 2026, lundi en premier ; jour choisi plein, aujourd'hui cerclé, jusqu'à 3 points, jours des mois voisins en gris
  mois: (sel = 13) => { const J = PL.JOUR; let s = '<div class="pla-mo" role="img" aria-label="Novembre 2026 : le jour choisi est le vendredi ' + sel + '">' + WEEKDAYS.map((d) => `<span class="h">${d}</span>`).join('');
    for (let k = 0; k < 6; k++) s += `<span class="d o"><b>${26 + k}</b></span>`;                  // 26 au 31 octobre
    for (let j = 1; j <= J.jours; j++) s += `<span class="d${j === J.jour ? ' t' : ''}${j === sel ? ' on' : ''}"><b>${j}</b><u>${PLA.pointsDu(j).map((ty) => `<i data-ev="${ty}"></i>`).join('')}</u></span>`;
    for (let k = 1; k <= 42 - 6 - J.jours; k++) s += `<span class="d o"><b>${k}</b></span>`;       // 1 au 6 décembre
    return s + '</div>'; },
  // vue « Année » : 12 petits mois, jours marqués (une chose ponctuelle), aujourd'hui cerclé, mois en cours teinté
  annee: () => { const NOMS = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juill.', 'août', 'sept.', 'oct.', 'nov.', 'déc.']; let s = '<div class="pla-yr">';
    for (let m = 0; m < 12; m++) { const nb = new Date(2026, m + 1, 0).getDate(), off = (new Date(2026, m, 1).getDay() + 6) % 7, mk = PLA.marques[m] || [], cur = m === 10;
      s += `<div class="m${cur ? ' cur' : ''}" role="img" aria-label="${NOMS[m]} 2026 : ${mk.length ? mk.length + (mk.length > 1 ? ' jours marqués' : ' jour marqué') : 'aucun jour marqué'}"><h6>${NOMS[m]}</h6><div class="g">` + '<s></s>'.repeat(off);
      for (let j = 1; j <= nb; j++) s += `<s class="${mk.includes(j) ? 'k' : ''}${cur && j === 12 ? ' t' : ''}"></s>`;
      s += '</div></div>'; }
    return s + '</div>'; },
};
