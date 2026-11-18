/* etudes.js : le JS commun du sujet « Études » (refonte UX/UI des mini-apps, 2026-11-17).
   À charger après ../../2026-11-15-cristal/cristal.js et ../base/planches.js, avant le script de la planche.
   Il contient :
     FONCTIONS (alias FEATURES)  la liste F1…F49 de l'audit (../audit/05-etudes.md, section 4), dans son ordre, avec ses numéros.
                                 [n°, libellé court, accès 'G' | 'P' | 'G+P', ce qu'elle fait en quelques mots]
     ETU                         les données d'exemple du sujet pour le jeudi 12 novembre 2026, 13 h 20, et quelques outils de texte.
     ETU.ui                      pièces d'écran communes (ligne de cours, ligne d'échéance, trois semaines de calendrier).
   Règles :
     - Les planches du sujet lisent ces données. Aucune planche ne recopie la liste ni ne change un chiffre.
     - Les cours et leurs plages viennent de EVENTS (cristal.js) ; l'examen de Statistiques (lundi 16 novembre, J-4) et le devoir
       « étude de cas » (vendredi 13) sont ceux de REMIND. Les moyennes, « Évalué », l'objectif de note, le temps d'étude de la semaine,
       « X révisé », « J-N » et le pourcentage de la session sortent par calcul (voir ETU.verifier() et la section 5 de l'audit).
     - Les enseignants, la salle de l'examen, les notes, les séances d'étude, les paquets et les dates de la session sont des
       exemples saisis (l'audit dit seulement qu'ils existent comme champs) : ils ne sont pas dans EVENTS.
     - Ce qui n'existe pas dans l'app est rangé sous ETU.nouveau et nulle part ailleurs : à étiqueter « Nouveau » sur les planches.
   Compte montré : GRATUIT. Seule l'importation d'horaire est Premium (F42 à F44) : elle se montre avec le badge Premium. */

/* ================= 1. Les 49 fonctions existantes (audit, section 4) ================= */
const FONCTIONS = [
  ['F1', 'Carte du cours en cours ou du prochain cours', 'G', '« En cours » ou « Prochain cours », heures, enseignant, barre d\'avancement'],
  ['F2', 'Trois chiffres : « Moyenne », « Étude », « Fiches »', 'G', 'Moyenne générale, temps d\'étude de la semaine, fiches à réviser'],
  ['F3', 'Bloc « À remplir »', 'G', 'Carte « Examens » tant qu\'aucun examen n\'existe'],
  ['F4', 'Liste « Mes cours », les uns sous les autres', 'G', 'Couleur, nom, enseignant, prochain cours ; toucher : le cours'],
  ['F5', 'Ajouter un cours à la main', 'G', 'Nom, enseignant, crédits, couleur'],
  ['F6', 'Modifier un cours', 'G', 'Menu « ⋯ » : « Modifier le cours »'],
  ['F7', 'Supprimer un cours, avec confirmation', 'G', '« Supprimer le cours » ; ses notes, examens et devoirs restent'],
  ['F8', 'Pas de doublon de cours', 'G', 'Le cours existant est complété, pas ajouté deux fois'],
  ['F9', 'Page « Cours » : la liste avec les moyennes', 'G', 'Moyenne et heures de cours par semaine ; glisser : supprimer'],
  ['F10', 'Dates de la session et carte « Session »', 'G', '« Début », « Fin » ; « N % · fin » et barre'],
  ['F11', 'En-tête du détail d\'un cours', 'G', 'Enseignant, crédits, heures par semaine, « Moyenne », « Évalué », « Étude »'],
  ['F12', 'Objectif de note d\'un cours', 'G', '« Objectif : 80 % » et la moyenne à obtenir sur le reste'],
  ['F13', 'Plages horaires d\'un cours', 'G', 'Jours, salle, heures ; « Ajouter une plage »'],
  ['F14', 'Examens d\'un cours', 'G', 'Tous les examens du cours ; « Ajouter un examen »'],
  ['F15', 'Devoirs à rendre d\'un cours', 'G', 'Cocher, toucher ; « Ajouter un devoir »'],
  ['F16', 'Notes d\'un cours', 'G', 'Titre, « 17,0/20 · compte pour 10 % », pourcentage ; « Ajouter une note »'],
  ['F17', '« Mes examens » sur l\'écran principal', 'G', 'Nombre à venir, trois prochains, « Ajouter un examen », ligne « Examens »'],
  ['F18', 'Ajouter ou modifier un examen, relié à un cours', 'G', 'Titre, cours, date et heure, salle'],
  ['F19', 'Supprimer un examen', 'G', 'Appui long : « Supprimer », sans confirmation'],
  ['F20', 'Page « Examens »', 'G', '« À venir », « Passés », conseil de révision'],
  ['F21', 'Compte à rebours et temps révisé d\'un examen', 'G', '« J-6 » (rouge à 3 jours ou moins), « X révisé » sur 14 jours'],
  ['F22', '« À rendre » sur l\'écran principal', 'G', 'Les trois prochains devoirs à cocher, « Nouveau devoir »'],
  ['F23', 'Ajouter ou modifier un devoir', 'G', 'Titre, cours, « À rendre le », « Rendu »'],
  ['F24', 'Cocher un devoir comme rendu', 'G', 'Cercle vide ou coché, titre barré'],
  ['F25', 'Page « Devoirs »', 'G', '« En retard », « Cette semaine », « Plus tard », « Rendus »'],
  ['F26', 'Page « Notes »', 'G', '« Moyenne générale », « Par cours », « Toutes les notes »'],
  ['F27', 'Ajouter ou modifier une note', 'G', 'Cours, évaluation, note obtenue, « Sur », poids'],
  ['F28', 'Chrono d\'étude', 'G', '« Démarrer » (sans cours ou un cours), « Annuler », « Terminer et noter »'],
  ['F29', 'Chrono sur l\'écran verrouillé et la Dynamic Island', 'G', '« Annuler », « Terminer », sans déverrouiller'],
  ['F30', 'Temps d\'étude de la semaine', 'G', '« 2 h 35 sur 12 h », barre, graphique par jour'],
  ['F31', 'Ajout rapide de temps', 'G', '« +25 min », « +45 min », « +60 min »'],
  ['F32', 'Objectif d\'heures d\'étude par semaine', 'G', '« − » et « + », de 1 à 60 heures'],
  ['F33', '« 6 dernières semaines »', 'G', 'Barres en heures, ligne pointillée de l\'objectif'],
  ['F34', 'Réviser une fiche', 'G', '« Voir la réponse », « À revoir », « Je savais »'],
  ['F35', 'Paquets de fiches', 'G', 'Par paquet : « à réviser » ou « à jour », total'],
  ['F36', 'Ajouter ou modifier une fiche', 'G', 'Paquet, question ou mot, réponse'],
  ['F37', 'Horaire de la semaine en grille, et liste du jour', 'G', 'Lundi à vendredi, blocs de couleur ; le jour choisi en liste'],
  ['F38', 'Changer de semaine', 'G', 'Flèches ; toucher le titre : cette semaine'],
  ['F39', 'Ajouter ou modifier un événement de l\'horaire', 'G', 'Type, cours, répétition, heures, salle, couleur'],
  ['F40', 'Changer un seul jour d\'une série', 'G', '« Cette occurrence seulement » ou « Toute la série »'],
  ['F41', 'Supprimer un événement de l\'horaire', 'G', 'Occurrence, série ou événement'],
  ['F42', 'Importer un horaire : choisir la source', 'P', 'Caméra, photo ou PDF'],
  ['F43', 'Importer un horaire : vérifier ce qui a été lu', 'P', 'Par jour, avec « À vérifier »'],
  ['F44', 'Importer un horaire : ajouter, et créer les cours trouvés', 'P', '« Ajouter à mon horaire (N) » ou « Remplacer l\'ancien »'],
  ['F45', 'Ligne « Temps de concentration »', 'G', '« X h sur Y h cette semaine »'],
  ['F46', 'Session de concentration (compte à rebours)', 'G', '15, 25, 45, 60 ou 90 minutes ; « Arrêter »'],
  ['F47', 'Concentration de la semaine', 'G', '« X h / Y h », graphique par jour'],
  ['F48', '« Mes paramètres » d\'Études', 'G', '« Ce que tu étudies », « Ton rythme »'],
  ['F49', 'Supprimer une note ; supprimer une fiche', 'G', 'Seulement dans la liste « Planning · études », en glissant'],
];
const FEATURES = FONCTIONS;

/* ================= 2. Les données d'exemple : jeudi 12 novembre 2026, 13 h 20 ================= */
const ETU = (function () {
  const MOIS = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juill.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  const MOIS_L = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
  const JS = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
  const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1);
  const dt = (m, j) => new Date(2026, m - 1, j);                                        // m = 1 à 12
  const AUJ = dt(11, 12), NOW = U.min('13:20');
  const dow = (d) => (d.getDay() + 6) % 7;                                                // 0 = lundi
  const jours = (d) => Math.round((d - AUJ) / 864e5);
  const court = (d) => JS[dow(d)].slice(0, 3) + '.';                                      // « lun. »
  const dateC = (d) => d.getDate() + ' ' + MOIS[d.getMonth()];                            // « 16 nov. »
  const hhmm = (m) => String(Math.floor(m / 60)).padStart(2, '0') + ':' + String(m % 60).padStart(2, '0');
  const fin = (e) => e.e || hhmm(U.min(e.s) + 60);                                        // comme U.week : une heure quand EVENTS n'en donne pas
  const lundi = (d) => dt(d.getMonth() + 1, d.getDate() - dow(d)).getTime();

  /* ---------- cours (Course) : nom, enseignant, crédits, couleur ; plages et heures par semaine calculées depuis EVENTS ---------- */
  const cours = [
    { id: 'compta', n: 'Comptabilité', prof: 'M. Roy', cr: 3, c: 'pla' },
    { id: 'market', n: 'Marketing', prof: 'Mme Lavoie', cr: 3, c: 'nut' },
    { id: 'stats', n: 'Statistiques', prof: 'Mme Gagnon', cr: 4, c: 'hab' },
  ];
  const parId = (id) => cours.find((c) => c.id === id);
  cours.forEach((c) => { c.plages = EVENTS.filter((e) => e.ty === 'cours' && e.t === c.n);
    c.hSem = c.plages.reduce((a, e) => a + U.min(fin(e)) - U.min(e.s), 0);                  // minutes par semaine (audit : durée des plages × jours)
    c.salle = (c.plages.find((e) => e.p) || {}).p || '';
    c.jours = c.plages.map((e) => JS[e.d]); });

  /* ---------- prochaine séance (audit : première plage non finie, sur 7 jours) ---------- */
  const prochaine = (filtre) => { for (let k = 0; k <= 7; k++) { const d = (3 + k) % 7, L = EVENTS.filter((e) => e.d === d && filtre(e) && (k > 0 || U.min(fin(e)) > NOW)).sort((a, b) => U.min(a.s) - U.min(b.s));
    if (L.length) return { e: L[0], k, jour: k === 0 ? 'Aujourd\'hui' : k === 1 ? 'Demain' : cap(JS[d]) }; } return null; };
  const suivant = prochaine((e) => e.ty === 'cours');
  suivant.heure = suivant.e.s + '–' + fin(suivant.e);
  suivant.cours = cours.find((c) => c.n === suivant.e.t);
  cours.forEach((c) => { const p = prochaine((e) => e.ty === 'cours' && e.t === c.n); c.prochain = p ? p.jour + ' · ' + p.e.s : ''; });

  /* ---------- notes (Grade) : cours, titre, note, « sur », poids ; la dernière ajoutée en dernier dans la liste de saisie ---------- */
  const notesSaisies = [
    { c: 'compta', t: 'Quiz 1', n: 17, sur: 20, w: 10 }, { c: 'market', t: 'Présentation', n: 88, sur: 100, w: 20 },
    { c: 'stats', t: 'Test 1', n: 38, sur: 50, w: 15 }, { c: 'compta', t: 'Travail pratique 1', n: 82, sur: 100, w: 15 },
    { c: 'stats', t: 'Devoir 1', n: 9.5, sur: 10, w: 10 }, { c: 'market', t: 'Quiz', n: 15, sur: 20, w: 10 }, { c: 'compta', t: 'Quiz 2', n: 14, sur: 20, w: 10 },
  ];
  const notes = notesSaisies.slice().reverse();                                           // « Toutes les notes » : la dernière ajoutée d'abord
  const pointsDe = (id) => notesSaisies.filter((g) => g.c === id).reduce((a, g) => a + g.n / g.sur * g.w, 0);
  const poidsDe = (id) => notesSaisies.filter((g) => g.c === id).reduce((a, g) => a + g.w, 0);
  cours.forEach((c) => { c.points = pointsDe(c.id); c.evalue = Math.min(100, poidsDe(c.id));                              // « Évalué »
    c.moy = c.evalue ? c.points / poidsDe(c.id) * 100 : null;                                                              // somme (note ÷ sur × poids) ÷ somme des poids × 100
    c.note = (obj) => (c.evalue >= 99.5 ? null : (obj - c.points) / (100 - c.evalue) * 100); });                          // moyenne à obtenir pour un objectif
  const avecNotes = cours.filter((c) => c.moy != null);
  const moyGen = avecNotes.reduce((a, c) => a + c.moy * c.cr, 0) / avecNotes.reduce((a, c) => a + c.cr, 0);               // pondérée par les crédits
  const objectif = 80;

  /* ---------- examen, devoir, session ---------- */
  const examen = { id: 'intra', t: 'Examen intra', c: 'stats', date: dt(11, 16), h: '16:00', salle: 'C-110' };
  const devoir = { t: 'Étude de cas', c: 'market', date: dt(11, 13), h: '23:59', fait: false };
  const session = { debut: dt(9, 8), fin: dt(12, 18) };
  session.pct = Math.min(1, Math.max(0, (AUJ - session.debut) / (session.fin - session.debut)));

  /* ---------- temps d'étude (StudySession) : date, minutes, cours ---------- */
  const seances = [
    { d: dt(11, 2), min: 60, c: 'market' }, { d: dt(11, 3), min: 75, c: 'stats' }, { d: dt(11, 4), min: 40, c: 'stats' }, { d: dt(11, 5), min: 55, c: 'compta' },
    { d: dt(11, 6), min: 50, c: 'market' }, { d: dt(11, 7), min: 90, c: 'stats' }, { d: dt(11, 8), min: 45, c: 'compta' },
    { d: dt(11, 9), min: 50, c: 'compta' }, { d: dt(11, 10), min: 60, c: 'stats' }, { d: dt(11, 11), min: 45, c: 'market' },
  ];
  const sem = (d) => seances.filter((s) => lundi(s.d) === lundi(d)).reduce((a, s) => a + s.min, 0);
  const semaineMin = sem(AUJ);                                                             // 2 h 35
  const parJour = Array.from({ length: 7 }, (_, k) => seances.filter((s) => lundi(s.d) === lundi(AUJ) && dow(s.d) === k).reduce((a, s) => a + s.min, 0));
  const etudeCours = (id) => seances.filter((s) => s.c === id && lundi(s.d) === lundi(AUJ)).reduce((a, s) => a + s.min, 0);
  const revise = (id) => seances.filter((s) => s.c === id && jours(s.d) >= -13 && jours(s.d) <= 0).reduce((a, s) => a + s.min, 0);   // « X révisé » : 14 derniers jours
  const objectifH = 12;                                                                    // objectif d'heures d'étude par semaine (défaut de l'app : 10)
  const avant = [420, 540, 360, 600];                                                      // 4 semaines plus anciennes (journal gardé 200 jours), en minutes : semaines du 5, 12, 19 et 26 octobre
  const semaines = avant.concat([sem(dt(11, 2)), semaineMin]);                             // 6 dernières semaines, la dernière est en cours
  const semLabs = ['5 oct.', '12 oct.', '19 oct.', '26 oct.', '2 nov.', '9 nov.'];

  /* ---------- concentration (données de Planning : focusLog), fiches ---------- */
  const concentration = { min: 75, objectifH: 10 };
  const paquets = [{ n: 'Comptabilité', total: 18, due: 1 }, { n: 'Marketing', total: 9, due: 0 }, { n: 'Statistiques', total: 12, due: 2 }];   // noms triés
  const fiche = { paquet: 'Statistiques', q: 'Qu\'est-ce que l\'écart type ?', r: 'La racine carrée de la variance : il mesure la dispersion autour de la moyenne.' };
  const aReviser = paquets.reduce((a, p) => a + p.due, 0);

  /* ---------- échéances : examen, devoir, fin de session, triées par date ---------- */
  const echeances = [
    { k: 'devoir', t: devoir.t, c: devoir.c, date: devoir.date, h: devoir.h, jours: jours(devoir.date) },
    { k: 'examen', t: examen.t, c: examen.c, date: examen.date, h: examen.h, salle: examen.salle, jours: jours(examen.date) },
    { k: 'session', t: 'Fin de session', date: session.fin, jours: jours(session.fin) },
  ].sort((a, b) => a.date - b.date);

  /* ---------- carte de Mon quotidien : demi-largeur, « Études », une ligne (MiniAppSummary.caption) ---------- */
  const jExam = jours(examen.date);
  const ligneCarte = jExam >= 0 && jExam <= 14 ? examen.t + ' · J-' + jExam : '1 devoir à rendre';
  const lib = (d) => ({ court: court(d), jour: JS[dow(d)], num: d.getDate(), mois: MOIS[d.getMonth()], moisL: MOIS_L[d.getMonth()], dateC: dateC(d) });

  const N = {
    date: 'Jeudi 12 novembre 2026', court: 'jeu. 12 nov.', heure: '13:20',
    compte: { premium: false },
    MOIS, MOIS_L, JS, cap, dt, dow, jours, court, dateC, hhmm, fin, lundi, lib,
    cours, parId, suivant, notes, examen, devoir, session, seances, jExam,
    moyGen, objectif, nbNotes: notesSaisies.length,
    etude: { semaineMin, parJour, objectifH, etudeCours, revise, semaines, semLabs },
    concentration, paquets, fiche, aReviser, echeances,
    rappels: REMIND,
    /* ----- carte de Mon quotidien (demi-largeur) : même nom, même icône (graduation), même couleur (etu) ; chiffre vedette = « J-4 » ----- */
    quotidien: { titre: 'Études', icone: 'graduation', ligne: ligneCarte, vedette: 'J-' + jExam },
    /* ----- libellés de l'app repris de l'audit ----- */
    txt: {
      accueil: 'Ajoute tes cours : ton horaire, tes devoirs, tes examens et tes notes viendront s\'y ranger. Ardane calcule ensuite tes moyennes et ce qu\'il te reste à faire.',
      importSous: 'À partir d\'une photo ou d\'un PDF',
      importTxt: 'Premium lit ton horaire à partir d\'une photo ou d\'un PDF, sur ton iPhone. Ajouter tes cours et tes événements à la main reste gratuit.',
      pondere: 'Pondérée par les crédits de chaque cours.',
      chronoTxt: 'Lance-le quand tu t\'y mets, le temps s\'ajoute à ta semaine.',
    },
    /* ----- CE QUI N'EXISTE PAS dans l'app : à étiqueter « Nouveau » (jeton, légende, case de texte). Jamais ailleurs. ----- */
    nouveau: {
      echeances: 'Échéances',                                              // dates et échéances au même endroit (audit 9, n° 5)
      objectifExamen: { min: 480, titre: 'Préparation' },                    // objectif d'heures et avancement par examen (audit 9, n° 2)
      revisions: [{ d: dt(11, 14), h: '13:00', min: 120, c: 'stats' }, { d: dt(11, 15), h: '14:00', min: 90, c: 'stats' }],   // sessions de révision prévues (audit 9, n° 1)
      historique: 'Historique des sessions',                                // liste des sessions d'étude, avec correction et suppression (audit 9, n° 3)
    },
  };
  N.nouveau.revisionsMin = N.nouveau.revisions.reduce((a, r) => a + r.min, 0);

  /* ----- contrôle : les repères de cristal.js et du guide ne sont pas contredits ; les calculs sont justes ----- */
  N.verifier = function () { const err = [], ok = (c, m) => { if (!c) err.push(m); };
    ok(FONCTIONS.length === 49 && FONCTIONS.every((f, i) => f[0] === 'F' + (i + 1)), 'FONCTIONS : 49 fonctions attendues, F1 à F49 dans l\'ordre');
    ok(FONCTIONS.filter((f) => f[2] !== 'G').map((f) => f[0]).join() === 'F42,F43,F44', 'FONCTIONS : seules F42, F43, F44 sont Premium');
    ok(cours.map((c) => c.n + ':' + c.jours.join('+') + ':' + c.hSem).join('|') === 'Comptabilité:lundi+jeudi:120|Marketing:lundi+mercredi:120|Statistiques:mardi+vendredi:120', 'Cours : plages de EVENTS (2 h par semaine chacun)');
    ok(suivant.e.t === 'Statistiques' && suivant.jour === 'Demain' && suivant.heure === '10:00–11:00', 'Prochain cours : Statistiques, demain 10:00–11:00');
    ok(cours.map((c) => c.prochain).join('|') === 'Lundi · 09:00|Lundi · 13:00|Demain · 10:00', 'Prochain cours de chaque matière');
    ok(jExam === 4 && jours(devoir.date) === 1, 'Examen J-4, devoir demain');
    ok(ligneCarte === 'Examen intra · J-4', 'Carte de Mon quotidien : « Examen intra · J-4 »');
    ok(Math.round(moyGen) === 82 && avecNotes.length === 3 && N.nbNotes === 7, 'Moyenne générale 82 %, 7 notes');
    ok(cours.map((c) => Math.round(c.moy) + '/' + Math.round(c.evalue)).join() === '79/35,84/30,84/25', 'Moyennes et « Évalué » par cours');
    ok(Math.round(parId('stats').note(objectif)) === 79, 'Objectif 80 % en Statistiques : 79 % sur les 75 % qui restent');
    ok(semaineMin === 155 && PL.dur(semaineMin) === '2' + NBSP + 'h' + NBSP + '35', 'Étude de la semaine : 2 h 35');
    ok(revise('stats') === 265 && PL.dur(265) === '4' + NBSP + 'h' + NBSP + '25', 'Statistiques : 4 h 25 révisé sur 14 jours');
    ok(Math.round(session.pct * 100) === 64, 'Session : 64 %');
    ok(echeances.map((e) => e.k).join() === 'devoir,examen,session', 'Échéances triées par date');
    ok(aReviser === 3, 'Fiches à réviser : 3');
    ok(semaines.length === 6 && semaines[5] === 155, '6 dernières semaines, la dernière est en cours');
    ok(PL.JOUR.dow0 === 6 && AUJ.getDay() === 4, 'Jeudi 12 novembre 2026');
    ok(REMIND[1].t === 'Devoir : étude de cas' && REMIND[2].t === 'Examen : Statistiques', 'À ne pas oublier : devoir et examen de REMIND');
    err.forEach((m) => console.error('etudes.js : ' + m));
    return err; };
  return N;
})();
ETU.verifier();

/* ================= 3. Pièces d'écran communes aux planches d'Études (ETU.ui) ================= */
ETU.ui = {
  // pastille de compte à rebours : « J-4 », rouge à 3 jours ou moins (audit F21)
  jour: (n) => `<span class="etu-j${n <= 3 ? ' hot' : ''}" aria-label="${n <= 0 ? 'Aujourd\'hui' : 'Dans ' + n + ' jours'}">${n <= 0 ? 'Auj.' : 'J-' + n}</span>`,
  // ligne de la liste « Mes cours » : barre de couleur, nom, enseignant et prochain cours, menu « ⋯ » (44 points)
  cours: (c) => `<div class="li"><span class="etu-bar" data-c="${c.c}"></span><div class="tx"><b>${c.n}</b><span class="s">${c.prof} · ${c.prochain}</span></div><span class="etu-more" role="button" aria-label="Actions du cours ${c.n}"><i data-i="dots"></i></span></div>`,
  // ligne de la page « Cours » : barre, nom, enseignant et heures par semaine, moyenne, chevron
  coursMoy: (c) => `<div class="li"><span class="etu-bar" data-c="${c.c}"></span><div class="tx"><b>${c.n}</b><span class="s">${c.prof} · ${PL.dur(c.hSem)} par semaine</span></div><div class="pl-r"><b>${PL.pct(c.moy / 100)}</b></div><i class="go" data-i="chev"></i></div>`,
  // ligne d'échéance : date, titre, détail, puis « J-N » (examen), rond à cocher (devoir) ou rien (session)
  echeance: (e) => { const L = ETU.lib(e.date), c = e.c ? ETU.parId(e.c).n : '';
    const s = e.k === 'devoir' ? `Devoir · ${c} · ${e.jours === 1 ? 'demain' : L.court} ${e.h}` : e.k === 'examen' ? `${c} · ${e.h} · ${e.salle}` : `${L.num} ${L.moisL} · ${PL.pct(ETU.session.pct)} de la session`;
    const r = e.k === 'examen' ? ETU.ui.jour(e.jours) : e.k === 'devoir' ? '<i class="chk" data-i="circle" role="button" aria-label="Marquer le devoir comme rendu"></i>' : '';
    return PL.due({ dow: e.k === 'session' ? L.mois : L.court, d: L.num, t: e.t, s, r, hot: e.k !== 'session' && e.jours <= 3 && e.k === 'examen' }); },
  // trois semaines de calendrier (9 au 29 novembre), lundi en premier : aujourd'hui cerclé, devoir en carré, examen en rond
  semaines: () => { const marq = { [ETU.devoir.date.getDate()]: 'dv', [ETU.examen.date.getDate()]: 'ex' };
    let s = '<div class="etu-mo" role="img" aria-label="Du 9 au 29 novembre 2026 : devoir à rendre le vendredi 13, examen le lundi 16, aujourd\'hui jeudi 12">' + WEEKDAYS.map((d) => `<span class="h">${d}</span>`).join('');
    for (let j = 9; j <= 29; j++) s += `<span class="d${j === 12 ? ' t' : ''}${j < 12 ? ' p' : ''}"><b>${j}</b>${marq[j] ? `<i class="${marq[j]}"></i>` : ''}</span>`;
    return s + '</div>'; },
};
