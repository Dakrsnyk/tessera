/* fitness.js : le JS commun du sujet « Fitness » (refonte UX/UI des mini-apps, 2026-11-17).
   À charger après ../../2026-11-15-cristal/cristal.js et ../base/planches.js, avant le script de la planche.
   Il contient :
     FONCTIONS (alias FEATURES)  la liste F1…F68 de l'audit (../audit/02-fitness.md, section 4), avec ses numéros.
                                 [n°, libellé court, accès 'G' | 'P' | 'G+P', ce qu'elle fait en quelques mots]
     FIT                         les données d'exemple du sujet pour le jeudi 12 novembre 2026, et quelques outils de texte.
   Règles :
     - Les sept planches du sujet lisent ces données. Aucune planche ne recopie la liste ni ne change un chiffre.
     - Tout chiffre est possible avec les règles de calcul du code (audit, section 5). Volumes, durées estimées, calories, records,
       totaux de semaine et comptes sont CALCULÉS ici, pas tapés à la main (voir la fin du fichier : FIT.verifier()).
     - Ce qui n'existe pas dans l'app est rangé sous FIT.nouveau et nulle part ailleurs : à étiqueter « Nouveau » sur les planches.
     - Le compte d'exemple est Premium (comme la planche Cristal 04 : « La dernière fois » y est visible). Ce que voit un compte
       gratuit est dans FIT.gratuit : chaque planche le montre sur au moins un écran (voir CONCEPT.md).
   Quatre moments (data-time) : 13:20 séance prévue · 08:10 idem · 19:05 séance en cours · 19:55 séance faite.
     À 19:05 les tuiles de la semaine comptent déjà la séance en cours (FIT.semaineEnCours : 3 / 4) ; à 13:20 FIT.semaine (2 / 4) ; à 19:55 FIT.semaineApres (3 / 4).
     19:55 est propre à Fitness : la séance commence à 18:59 (chrono 6:05 à 19:05) et dure 52 min, elle finit donc à 19:51.
     La planche Cristal 04 montrait 19:50 : une minute trop tôt.
   Cinq écarts connus avec la planche Cristal 04-fitness, voulus (le code de l'app fait foi, voir CONCEPT.md, « Données d'exemple ») :
     1. « Calories » de la semaine : ≈ 220 (2 séances), ≈ 331 après la séance du jour. La planche Cristal montrait ≈ 410 et ≈ 610 :
        impossible avec CalorieModel (MET 5,0 / 3,8 / 2,0 moins 1, pour 71,6 kg : une séance d'une heure vaut 100 à 120 kcal).
     2. « La dernière fois : 57,5 kg × 10 » et record « 57,5 × 10 » (1RM ≈ 77 kg). La planche Cristal montrait 59,6 kg × 8 : la charge
        monte par pas de 2,5 kg, 59,6 ne peut pas être atteint avec − / +.
     3. Noms d'exercice = ceux de la bibliothèque : « Développé couché (barre) », « Tractions (pronation) », « Développé militaire (barre) ».
        La planche Cristal et cristal.js écrivent la forme courte (« Développé couché ») : gardée dans .court, pour la carte de Mon quotidien
        seulement (repère du guide à 19:05).
     4. « Par muscle » : comptes recalculés depuis ExerciseLibrary.swift (muscle principal) : Pectoraux 16, Dos 17. La planche Cristal
        montrait 14 et 22, marqués « à confirmer ».
     5. « Programme et séances » : « 3 séances » (le compte réel), et non « Tes séances de la semaine ».
   Une séance n'a pas d'heure dans Fitness (audit, section 9, point 3). Le « 18:30 » de cristal.js (EVENTS) est un bloc de Planning :
   aucune planche Fitness n'écrit d'heure de séance ni de compte à rebours. */

/* ================= 1. Les 68 fonctions existantes (audit, section 4) ================= */
const FONCTIONS = [
  // A. Écran principal
  ['F1', 'Sélecteur de semaine', 'G', '7 jours, point plein (fait), point creux (prévu), futur permis, « Aujourd\'hui »'],
  ['F2', 'Séance du jour choisi, 9 états', 'G', 'Libellé, nom, détail ; barre si la séance est en cours'],
  ['F3', 'Action principale flottante', 'G', '« Commencer », « Reprendre la séance », « Créer une séance », « Rattraper… »'],
  ['F4', 'Rattraper une séance manquée', 'G', '« Séance rattrapée », pastille « Rattrapée » ; le jour manqué est marqué'],
  ['F5', '« Faire une séance quand même »', 'G', 'Un jour de repos : la liste des séances du programme'],
  ['F6', 'Aperçu de la séance prévue', 'G', '4 premiers exercices « 4 × 10 · 60 kg », « + n autres »'],
  ['F7', 'Totaux de la semaine choisie', 'G', '« Durée », « Volume », « Calories » (≈), « Séances » (faites / objectif)'],
  ['F8', '« À remplir »', 'G', '« Programme d\'entraînement », « Séances par semaine », « Poids », « Objectif de pas »'],
  ['F9', 'Raccourcis des exercices favoris', 'G+P', 'Jusqu\'à 6 favoris ; la fiche demande Premium'],
  ['F10', 'Carte des pas du jour', 'G', 'Anneau, pas, objectif, distance, étages ; ouvre « Activité »'],
  ['F11', 'Fermeture d\'une séance oubliée', 'G', 'Sans écran : close après 3 h sans série'],
  ['F12', 'Supprimer une séance faite', 'G', 'Menu « … », appui long, glissement, bouton du détail ; confirmé'],
  // B. Séance en direct
  ['F13', 'Démarrer une séance', 'G', 'Depuis l\'écran principal, le choix d\'une séance, Mon quotidien, un widget'],
  ['F14', '« Séance libre »', 'G', 'Séance vide, puis bibliothèque (Premium) ou saisie à la main'],
  ['F15', 'En-tête de la séance', 'G', 'Nom, chrono, « n/m séries », barre'],
  ['F16', 'Carte de l\'exercice en cours', 'G', '« Série n sur m », nom, bouton ⓘ (fiche : Premium)'],
  ['F17', '« La dernière fois : charge × répétitions »', 'P', 'Meilleure série de la dernière séance d\'un autre jour'],
  ['F18', 'Régler répétitions et charge', 'G', '− / + : 1 répétition, 2,5 kg ou 5 lb ; « Corps » si 0'],
  ['F19', '« Série faite »', 'G', 'Note la série, lance le repos ; la charge faite devient le plan des suivantes'],
  ['F20', 'Repos minuté', 'G', 'Compte à rebours, « Prêt », pause, « Reprendre », « Passer le repos »'],
  ['F21', 'Alerte de fin de repos par notification', 'G', '« Repos terminé » ; proposée une fois, au premier repos'],
  ['F22', '« Passer la série »', 'G', 'Pastille « Passée » ; ni faite ni comptée, pas de repos'],
  ['F23', '« Annuler la dernière série »', 'G', 'Défait une série ; rouvre une séance finie (1 h, même jour)'],
  ['F24', '« Passer cet exercice »', 'G', 'Exercice suivant, sans noter les séries restantes'],
  ['F25', 'Liste « La séance »', 'G', 'Chaque exercice : fait, en cours, à venir ; plan ; pastilles des séries'],
  ['F26', 'Modifier ou supprimer une série faite', 'G', 'Répétitions, charge, « Supprimer cette série » ; aussi dans l\'historique'],
  ['F27', 'Ajouter un exercice de la bibliothèque en séance', 'P', '« Choisir dans la bibliothèque » ; charge de la dernière fois'],
  ['F28', 'Ajouter un exercice écrit à la main en séance', 'G', 'Nom ou « Mes exercices », séries, répétitions, charge, repos'],
  ['F29', '« Terminer la séance »', 'G', 'Confirmation « Terminer et enregistrer »'],
  ['F30', '« Annuler la séance »', 'G', 'Confirmation ; la séance n\'est jamais comptée'],
  ['F31', 'Fin automatique à la dernière série', 'G', 'Sans geste : la page passe au choix d\'une séance'],
  // C. Programme
  ['F32', '« Ma semaine »', 'G', 'Lundi à dimanche : la séance ou « Repos » ; menu à coches par jour'],
  ['F33', '« Mes séances »', 'G', 'Modifier, « Nouvelle séance », glisser pour supprimer (confirmé)'],
  ['F34', 'Objectif de séances par semaine', 'G', '« n séances / semaine », − / + de 1 à 7'],
  ['F35', 'Éditeur de séance', 'G', 'Nom, jours, exercices : séries, répétitions, charge, repos, tempo, notes'],
  ['F36', 'Ajouter un exercice à une séance du programme', 'G+P', '« Ajouter un exercice » gratuit, « Choisir dans la bibliothèque » Premium'],
  ['F37', 'Suggestions pendant la saisie du nom', 'P', '3 exercices au plus, dès 2 lettres'],
  ['F38', 'Durée estimée d\'une séance', 'G', '« environ n min » : 40 s par série + repos'],
  // D. Bibliothèque et fiches
  ['F39', 'Bibliothèque de 163 exercices', 'G+P', 'Liste visible par tous ; chaque exercice s\'ouvre avec Premium'],
  ['F40', 'Recherche au fil de la frappe', 'G+P', 'Nom, muscle, équipement ; sans accents aussi'],
  ['F41', 'Filtres', 'G+P', '« Muscle », « Équipement », « Type », « Niveau », « Effacer »'],
  ['F42', 'Raccourcis de la bibliothèque', 'G+P', '« Favoris », « Récents », « Les plus faits », « Par muscle »'],
  ['F43', 'Favoris', 'G+P', 'Glisser une ligne (tous) ; étoile de la fiche (Premium)'],
  ['F44', '« Mes exercices »', 'G', '« Créer un exercice », glisser pour supprimer'],
  ['F45', 'Démonstration animée', 'P', 'Personnage, phases nommées, pause, choix de la vue'],
  ['F46', 'Identité de l\'exercice', 'P', 'Muscles principaux et secondaires, type, niveau, équipement'],
  ['F47', 'Technique', 'P', '« Position de départ », « Exécution », « Points importants », « À éviter »'],
  ['F48', '« Mes performances »', 'P', 'Dernière séance, « Record », 1RM ≈, « Volume », « Fréquence », courbe'],
  ['F49', '« Alternatives »', 'P', '5 au plus : « Variante » ou « Mêmes muscles »'],
  ['F50', 'Ajouter l\'exercice à une séance', 'P', '« Ajouter à ma séance » ou « Ajouter à une séance »'],
  ['F51', 'Fiche ouverte par-dessus l\'écran en cours', 'P', 'Bouton ⓘ ; « Fermer » ramène où on était'],
  // E. Historique
  ['F52', 'Liste des séances faites', 'G', 'Par mois : nom, « Rattrapée », date, « n min · n séries · volume »'],
  ['F53', 'Détail d\'une séance', 'G', 'Date, durée, volume, séries par exercice avec l\'heure ; modifier, supprimer'],
  // F. Progression
  ['F54', '« Volume par semaine »', 'P', 'Barres des 8 dernières semaines'],
  ['F55', '« Records »', 'P', 'Un record par exercice, A à Z, « +n kg depuis le début · n séances »'],
  // G. Pas
  ['F56', 'Page « Activité »', 'G', 'Pas, distance, étages, calories actives, « 7 derniers jours »'],
  // H. Réglages
  ['F57', '« Mes paramètres »', 'G', '« Rappel de séance », objectif, niveau, séances par semaine, « Toi », objectif de pas'],
  ['F58', 'Unités kg ou lb', 'G', 'Réglage général de l\'app ; valeurs gardées en kg'],
  // I. Hors de la mini-app
  ['F59', 'Carte Fitness de Mon quotidien, page « Séance »', 'G', '« Commencer », « Série faite », pause du repos, « Supprimer la séance »'],
  ['F60', 'Carte Fitness de Mon quotidien, page « Semaine »', 'G', '« n/objectif séances », 7 ronds, « Encore n séances »'],
  ['F61', 'Carte « Pas » de Mon quotidien', 'G', 'Pas / objectif ; 7 jours et moyenne ; ouvre « Activité »'],
  ['F62', 'Activité en direct', 'G', 'Écran verrouillé et Dynamic Island : « Série faite », « Passer », pause'],
  ['F63', 'Widgets Fitness', 'G+P', '9 widgets : 3 gratuits, 6 Premium'],
  ['F64', 'Rappels et encouragements', 'G', '« Ta séance t\'attend », « Séance demain », « Bilan sportif de la semaine »…'],
  ['F65', 'Séances prévues dans l\'agenda de Planning', 'G', 'Nom, « Séance · environ n min », sans heure'],
  ['F66', 'Données Fitness dans Créer', 'G', '« Séance », « Mes séances », « Suivi » (« Meilleur record » : Premium)'],
  ['F67', 'Objectif et activité partagés avec Nutrition', 'G', '« Le même pour Sport et Nutrition. »'],
  ['F68', 'Pastille Fitness de l\'accueil', 'G', '« Séance en cours » ou « n séance(s) cette semaine »'],
];
const FEATURES = FONCTIONS;   // même liste, sous le nom employé pour Finance

/* ================= 2. Les données d'exemple : jeudi 12 novembre 2026 ================= */
const FIT = (function () {
  const sum = (a, f) => a.reduce((s, x) => s + (f ? f(x) : x), 0);
  const nb = (x, dec = 0) => PL.n(x, dec);
  const kgTxt = (x) => nb(x, Number.isInteger(x) ? 0 : 1) + NBSP + 'kg';                   // 60 kg · 57,5 kg
  const POIDS = 71.6, OBJECTIF = 4, PAS_KG = 2.5;

  /* ---------- exercices employés (noms, muscles, équipement, niveau : ExerciseLibrary.swift) ---------- */
  const X = {
    dc:    { id: 'bench-press', n: 'Développé couché (barre)', court: 'Développé couché', muscle: 'Pectoraux', second: ['Triceps', 'Épaules'], equip: ['Barre', 'Banc'], type: 'Musculation', niveau: 'Intermédiaire' },
    trac:  { id: 'pull-up', n: 'Tractions (pronation)', court: 'Tractions', muscle: 'Dos', second: ['Biceps', 'Avant-bras'], equip: ['Barre de traction'], type: 'Musculation', niveau: 'Intermédiaire' },
    dm:    { id: 'ohp', n: 'Développé militaire (barre)', court: 'Développé militaire', muscle: 'Épaules', second: ['Triceps', 'Trapèzes'], equip: ['Barre'], type: 'Musculation', niveau: 'Intermédiaire' },
    pompes: { id: 'push-up', n: 'Pompes', court: 'Pompes', muscle: 'Pectoraux', second: ['Triceps', 'Épaules', 'Abdominaux'], equip: ['Poids du corps'], type: 'Musculation', niveau: 'Débutant' },
    curl:  { id: 'db-curl', n: 'Curl haltères', court: 'Curl haltères', muscle: 'Biceps', second: ['Avant-bras'], equip: ['Haltères'], type: 'Musculation', niveau: 'Débutant' },
    tri:   { id: 'pushdown', n: 'Extension triceps à la poulie', court: 'Extension triceps', muscle: 'Triceps', second: [], equip: ['Poulie'], type: 'Musculation', niveau: 'Débutant' },
    squat: { id: 'back-squat', n: 'Squat (barre)', court: 'Squat', muscle: 'Quadriceps', second: ['Fessiers', 'Ischio-jambiers', 'Lombaires'], equip: ['Barre'], type: 'Musculation', niveau: 'Intermédiaire' },
    sdt:   { id: 'rdl', n: 'Soulevé de terre roumain', court: 'Soulevé de terre roumain', muscle: 'Ischio-jambiers', second: ['Fessiers', 'Lombaires'], equip: ['Barre'], type: 'Musculation', niveau: 'Intermédiaire' },
    fentes: { id: 'reverse-lunge', n: 'Fentes arrière', court: 'Fentes arrière', muscle: 'Quadriceps', second: ['Fessiers'], equip: ['Poids du corps', 'Haltères'], type: 'Musculation', niveau: 'Débutant' },
    lc:    { id: 'seated-leg-curl', n: 'Leg curl assis', court: 'Leg curl assis', muscle: 'Ischio-jambiers', second: [], equip: ['Machine'], type: 'Musculation', niveau: 'Débutant' },
    mollets: { id: 'standing-calf', n: 'Mollets debout', court: 'Mollets debout', muscle: 'Mollets', second: [], equip: ['Machine', 'Poids du corps'], type: 'Musculation', niveau: 'Débutant' },
    airsq: { id: 'air-squat', n: 'Squat au poids du corps', court: 'Squat au poids du corps', muscle: 'Quadriceps', second: ['Fessiers'], equip: ['Poids du corps'], type: 'Musculation', niveau: 'Débutant' },
    crunch: { id: 'crunch', n: 'Crunch', court: 'Crunch', muscle: 'Abdominaux', second: [], equip: ['Poids du corps'], type: 'Musculation', niveau: 'Débutant' },
  };
  Object.keys(X).forEach((k) => { X[k].k = k; X[k].ligne = `${X[k].muscle} · ${X[k].equip[0]} · ${X[k].niveau}`; });   // ligne de la bibliothèque : « muscles · équipement · niveau »

  /* ---------- textes d'une ligne d'exercice, tels que l'app les écrit ---------- */
  const mmss = (s) => Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');           // 180 → « 3:00 »
  const plan = (e) => `${e.s}${NBSP}×${NBSP}${e.r}` + (e.kg > 0 ? ` · ${kgTxt(e.kg)}` : '');   // « 4 × 10 · 60 kg » ; au poids du corps : « 3 × 8 »
  const serie = (kg, r) => (kg > 0 ? `${nb(kg, Number.isInteger(kg) ? 0 : 1)}${NBSP}×${NBSP}${r}` : `Corps${NBSP}×${NBSP}${r}`);   // pastille d'une série faite : « 60 × 10 »
  const charge = (kg) => (kg > 0 ? kgTxt(kg) : 'Corps');                                     // réglette « Charge » : « Corps » si 0
  const epley = (kg, r) => kg * (1 + r / 30);                                                // 1RM estimé (Fitness.swift:650)

  /* ---------- le programme : une semaine type, trois séances ----------
     e : x exercice · s séries · r répétitions · kg charge (0 = poids du corps) · repos en secondes (pas de 15) · tempo et notes (saisis dans l'éditeur) */
  const E = (x, s, r, kg, repos, tempo, notes) => ({ x, ...X[x], s, r, kg, repos, tempo: tempo || '', notes: notes || '' });
  const mk = (k, n, jours, exos) => { const series = sum(exos, (e) => e.s), secondes = sum(exos, (e) => e.s * (40 + e.repos));   // durée estimée : 40 s par série + repos (FitnessApp.swift:528)
    const o = { k, n, jours, exos, nbEx: exos.length, series, dureeEst: Math.max(5, Math.round(secondes / 60)), volumePlan: sum(exos, (e) => e.s * e.r * e.kg) };
    exos.forEach((e) => { e.plan = plan(e); e.reposTxt = mmss(e.repos); e.chargeTxt = charge(e.kg); });
    o.detail = `${o.nbEx} exercices · ${o.series} séries · environ ${o.dureeEst}${NBSP}min`;      // ligne du héros, séance prévue
    o.court = `${o.nbEx} exercices · environ ${o.dureeEst}${NBSP}min`;                           // « Mes séances », choix d'une séance
    o.quotidien = `${o.nbEx} exercices · ${o.series} séries`;                                   // carte de Mon quotidien
    o.apercu = exos.slice(0, 4); o.autres = Math.max(0, exos.length - 4);                      // F6 : 4 premiers, « + n autres »
    return o; };
  const haut = mk('haut', 'Haut du corps', [0, 3], [
    E('dc', 4, 10, 60, 180, '2-0-1', 'Omoplates serrées, pieds à plat.'), E('trac', 3, 8, 0, 150, '', 'Menton au-dessus de la barre.'), E('dm', 3, 10, 35, 150),
    E('pompes', 3, 12, 0, 120), E('curl', 3, 12, 12.5, 120, '2-0-2'), E('tri', 2, 12, 17.5, 120)]);
  const jambes = mk('jambes', 'Jambes', [1, 5], [
    E('squat', 4, 8, 70, 180, '3-0-1', 'Descendre sous la parallèle.'), E('sdt', 3, 10, 50, 180), E('fentes', 3, 10, 0, 120), E('lc', 2, 10, 25, 120), E('mollets', 3, 15, 0, 60)]);
  const maison = mk('maison', 'Maison, sans matériel', [], [E('pompes', 3, 12, 0, 60), E('airsq', 3, 15, 0, 60), E('fentes', 3, 10, 0, 60), E('crunch', 3, 15, 0, 60)]);
  const SEANCES = [haut, jambes, maison], S = { haut, jambes, maison };
  const JOURS = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'], JC = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  const semaineType = JOURS.map((j, d) => { const s = SEANCES.filter((q) => q.jours.includes(d)); return { j, d, seance: s[0] || null, txt: s.length ? s.map((q) => q.n).join(' + ') : 'Repos' }; });

  /* ---------- calories actives d'une séance (CalorieModel.swift:59-104) ----------
     travail d'une série = 3,5 s par répétition + 15 s, entre 25 et 90 s ; MET 5,0 avec charge, 3,8 au poids du corps, repos 2,0 ; moins 1 MET ; × poids */
  const kcal = (series, minutes) => { let work = 0, net = 0;
    series.forEach((q) => { const w = Math.min(90, Math.max(25, q.r * 3.5 + 15)); work += w; net += ((q.kg > 0 ? 5.0 : 3.8) - 1) * w; });
    net += (2.0 - 1) * Math.max(0, minutes * 60 - work); return net / 3600 * POIDS; };

  /* ---------- l'historique : 23 séances faites depuis le lundi 28 septembre ; la 24e est celle du jour ----------
     [date ISO, séance, minutes, charges du jour {exercice: kg}, jour rattrapé] ; les répétitions sont celles du plan */
  const H0 = [
    ['2026-09-28', 'haut', 57, { dc: 50, dm: 30, curl: 10, tri: 15 }], ['2026-09-29', 'jambes', 49, { squat: 60, sdt: 40, lc: 20 }], ['2026-10-01', 'haut', 55, { dc: 50, dm: 30, curl: 10, tri: 15 }],
    ['2026-10-05', 'haut', 58, { dc: 52.5, dm: 30, curl: 10, tri: 15 }], ['2026-10-06', 'jambes', 47, { squat: 60, sdt: 40, lc: 20 }], ['2026-10-10', 'jambes', 50, { squat: 62.5, sdt: 42.5, lc: 20 }],
    ['2026-10-12', 'haut', 56, { dc: 52.5, dm: 32.5, curl: 10, tri: 15 }], ['2026-10-13', 'jambes', 51, { squat: 62.5, sdt: 42.5, lc: 20 }], ['2026-10-15', 'haut', 54, { dc: 52.5, dm: 32.5, curl: 10, tri: 15 }], ['2026-10-17', 'jambes', 52, { squat: 65, sdt: 45, lc: 22.5 }],
    ['2026-10-19', 'haut', 60, { dc: 55, dm: 32.5, curl: 12.5, tri: 15 }], ['2026-10-20', 'jambes', 48, { squat: 65, sdt: 45, lc: 22.5 }], ['2026-10-22', 'haut', 57, { dc: 55, dm: 32.5, curl: 12.5, tri: 15 }],
    ['2026-10-26', 'haut', 58, { dc: 55, dm: 32.5, curl: 12.5, tri: 17.5 }], ['2026-10-27', 'jambes', 50, { squat: 67.5, sdt: 47.5, lc: 22.5 }], ['2026-10-29', 'haut', 55, { dc: 55, dm: 35, curl: 12.5, tri: 17.5 }], ['2026-10-31', 'jambes', 54, { squat: 67.5, sdt: 47.5, lc: 25 }],
    ['2026-11-02', 'haut', 56, { dc: 57.5, dm: 35, curl: 12.5, tri: 17.5 }], ['2026-11-03', 'jambes', 51, { squat: 70, sdt: 47.5, lc: 25 }], ['2026-11-06', 'haut', 58, { dc: 57.5, dm: 35, curl: 12.5, tri: 17.5 }, '2026-11-05'], ['2026-11-07', 'jambes', 52, { squat: 70, sdt: 50, lc: 25 }],
    ['2026-11-09', 'haut', 59, { dc: 57.5, dm: 35, curl: 12.5, tri: 17.5 }], ['2026-11-10', 'jambes', 53, { squat: 70, sdt: 50, lc: 25 }],
  ];
  const MOIS = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juill.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'], MOISL = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
  const JS3 = ['Dim.', 'Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.'], JSL = ['dimanche', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'];
  const dt = (iso) => new Date(iso + 'T12:00:00');
  const dCourt = (iso) => { const d = dt(iso); return `${JS3[d.getDay()]} ${d.getDate()} ${MOIS[d.getMonth()]}`; };           // « Lun. 9 nov. »
  const dLong = (iso) => { const d = dt(iso); return `${JSL[d.getDay()]} ${d.getDate()} ${MOISL[d.getMonth()]}`; };          // « lundi 9 novembre »
  const lundi = (iso) => { const d = dt(iso); d.setDate(d.getDate() - ((d.getDay() + 6) % 7)); return d.toISOString().slice(0, 10); };
  const faite = (iso, k, min, kgs, rattrape) => { const q = S[k], series = [];
    q.exos.forEach((e) => { const kg = e.kg > 0 ? (kgs[e.x] ?? e.kg) : 0; for (let i = 0; i < e.s; i++) series.push({ x: e.x, n: e.n, r: e.r, kg, txt: serie(kg, e.r) }); });
    const volume = sum(series, (z) => z.r * z.kg);
    return { iso, k, nom: q.n, min, series, nbSeries: series.length, volume, kcal: kcal(series, min), rattrape: rattrape || null, date: dCourt(iso), dateLongue: dLong(iso), jour: dt(iso).getDate(), mois: dt(iso).getMonth(), sem: lundi(iso),
      resume: `${min}${NBSP}min · ${series.length} séries · ${nb(volume)}${NBSP}kg`,                       // ligne de l'historique
      hero: `${series.length} séries · ${min}${NBSP}min · ${nb(volume)}${NBSP}kg soulevés` }; };         // ligne du héros, séance faite
  const HIST = H0.map((h) => faite(...h));
  const AUJ = faite('2026-11-12', 'haut', 52, {});                                                    // la séance du jour, une fois faite (19:55) : 18 séries · 52 min · 4 320 kg

  /* ---------- semaines (lundi → dimanche) ---------- */
  const LUNDIS = ['2026-09-21', '2026-09-28', '2026-10-05', '2026-10-12', '2026-10-19', '2026-10-26', '2026-11-02', '2026-11-09'];   // les 8 dernières semaines
  const sem = (lun, extra = []) => { const l = HIST.concat(extra).filter((h) => h.sem === lun), d = dt(lun);
    return { lun, lab: `${d.getDate()} ${MOIS[d.getMonth()]}`, seances: l, n: new Set(l.map((h) => h.iso)).size, min: sum(l, (h) => h.min), volume: sum(l, (h) => h.volume), kcal: Math.round(sum(l, (h) => h.kcal)) }; };
  const S8 = LUNDIS.map((l) => sem(l)), CETTE = S8[7], APRES = sem('2026-11-09', [AUJ]), PREC = S8[6];
  let serieSem = 0; for (let i = 6; i >= 0 && S8[i].n >= OBJECTIF; i--) serieSem++;                    // semaines de suite à l'objectif, avant la semaine en cours (Fitness.swift:591)
  const tuiles = (w) => [['Durée', PL.dur(w.min)], ['Volume', nb(w.volume) + NBSP + 'kg'], ['Calories', '≈' + NBSP + nb(w.kcal)], ['Séances', `${w.n} / ${OBJECTIF}`]];
  const encore = (n) => (OBJECTIF - n <= 0 ? 'Objectif de la semaine atteint' : `Encore ${OBJECTIF - n} séance${OBJECTIF - n > 1 ? 's' : ''}`);

  /* ---------- records et courbes (Premium) : un record par exercice chargé, meilleur 1RM estimé (Epley) ---------- */
  const parExo = (x, liste = HIST) => liste.filter((h) => h.series.some((z) => z.x === x)).map((h) => { const z = h.series.filter((q) => q.x === x); return { iso: h.iso, date: h.date, kg: Math.max(...z.map((q) => q.kg)), r: z[0].r, volume: sum(z, (q) => q.r * q.kg), n: z.length }; });
  const record = (x, liste = HIST) => { const p = parExo(x, liste), best = p.reduce((a, b) => (epley(b.kg, b.r) > epley(a.kg, a.r) ? b : a), p[0]), gain = best.kg - p[0].kg;
    return { x, n: X[x].n, kg: best.kg, r: best.r, txt: serie(best.kg, best.r), rm: Math.round(epley(best.kg, best.r)), rmTxt: `1RM${NBSP}≈${NBSP}${nb(Math.round(epley(best.kg, best.r)))}${NBSP}kg`, gain, seances: p.length,
      detail: `+${nb(gain, Number.isInteger(gain) ? 0 : 1)}${NBSP}kg depuis le début · ${p.length} séances` }; };
  const CHARGES = ['dc', 'dm', 'curl', 'tri', 'squat', 'sdt', 'lc'];                                   // les 7 exercices avec une charge
  const records = CHARGES.map((x) => record(x)).sort((a, b) => a.n.localeCompare(b.n, 'fr'));          // A à Z, comme la page « Progression »
  const il30 = (iso) => { const d = (dt('2026-11-12') - dt(iso)) / 864e5; return d >= 0 && d < 30; };
  const perfs = (x) => { const p = parExo(x), last = p[p.length - 1], r = record(x);
    return { exo: X[x], courbe: p.map((q) => q.kg), dates: p.map((q) => q.date), derniere: { date: last.date, txt: `${last.n} séries · meilleure ${serie(last.kg, last.r)}`, kg: last.kg, r: last.r }, record: r,
      volume: last.volume, volumeTxt: nb(last.volume) + NBSP + 'kg', frequence: p.filter((q) => il30(q.iso)).length, frequenceTxt: `${p.filter((q) => il30(q.iso)).length} séances en 30 jours`,
      laDerniereFois: `La dernière fois : ${kgTxt(last.kg)}${NBSP}×${NBSP}${last.r}` }; };                // F17, Premium

  /* ---------- la séance en cours à 19:05 (repère du guide : Développé couché, série 2 sur 4, 10 × 60 kg, repos 0:45) ---------- */
  const enCours = { debut: '18:59', chrono: '6:05', faites: 1, total: haut.series, compte: `1/${haut.series} séries`, p: 1 / haut.series,
    exo: haut.exos[0], serie: 2, series: 4, serieTxt: 'Série 2 sur 4', reps: 10, kg: 60, chargeTxt: kgTxt(60), repsTxt: `10${NBSP}×${NBSP}${kgTxt(60)}`,
    repos: '0:45', reposTotal: '3:00', reposP: 45 / 180, laDerniereFois: perfs('dc').laDerniereFois,
    hero: 'Développé couché (barre) · série 2 sur 4',                                                // ligne du héros, séance en cours
    quotidien: { ex: 'Développé couché', ligne: `Série 2/4 · 10${NBSP}×${NBSP}${kgTxt(60)}`, repos: '0:45', cta: 'Série faite' },   // carte de Mon quotidien (forme courte de cristal.js)
    liste: haut.exos.map((e, i) => ({ ...e, etat: i === 0 ? 'en cours' : 'à venir', faites: i === 0 ? [serie(60, 10)] : [] })),    // liste « La séance »
    suivant: haut.exos[1] };

  /* ---------- détail d'une séance faite (lundi 9 novembre) : séries par exercice avec l'heure ---------- */
  const detail = (h, debut) => { const [H, M] = debut.split(':').map(Number), pas = h.min / h.nbSeries; let i = 0;
    const exos = S[h.k].exos.map((e) => ({ n: e.n, x: e.x, series: h.series.filter((z) => z.x === e.x).map((z) => { i++; const t = H * 60 + M + Math.round(i * pas); return { txt: z.txt, heure: Math.floor(t / 60) + ':' + String(t % 60).padStart(2, '0') }; }) }));
    return { nom: h.nom, date: h.dateLongue, duree: PL.dur(h.min), volume: nb(h.volume) + NBSP + 'kg', kcal: Math.round(h.kcal), exos, debut }; };

  /* ---------- pas (StepCounter ; repères de cristal.js : STEPS7, DAY) ---------- */
  const P7 = [9120, 11340, 6480, 8210, 7650, 9980, 5480], PGOAL = 8000;
  const pasKcal = (n, minSeance = 0) => Math.round(Math.max(0, n - Math.round(minSeance * 30)) * (0.04 / 70) * POIDS);   // CalorieModel.swift:118

  /* ---------- bibliothèque (ExerciseLibrary.swift) ---------- */
  const parMuscle = [['Pectoraux', 16], ['Dos', 17], ['Épaules', 18], ['Biceps', 9], ['Triceps', 10], ['Avant-bras', 4], ['Quadriceps', 20], ['Ischio-jambiers', 10], ['Fessiers', 13], ['Mollets', 5], ['Abdominaux', 16], ['Lombaires', 6], ['Full body', 13]];
  const plusFaits = Object.keys(X).map((x) => ({ ...X[x], seances: HIST.filter((h) => h.series.some((z) => z.x === x)).length })).filter((e) => e.seances).sort((a, b) => b.seances - a.seances);

  const N = {
    compte: 'Premium', poids: POIDS, objectif: OBJECTIF, pasCharge: PAS_KG, unite: 'kg',
    profil: { genre: 'Homme', age: 24, taille: 182, poids: POIDS, objectif: 'Perte de poids', niveau: 'Intermédiaire', seancesParSemaine: OBJECTIF, rappel: '18:00', objectifPas: PGOAL },   // mêmes réponses que nutrition.js
    exos: X, seances: SEANCES, haut, jambes, maison, semaineType,
    programme: { ligne: `${SEANCES.length} séances`, objectifTxt: `${OBJECTIF} séances / semaine`,
      dureeSemaine: sum(semaineType, (j) => (j.seance ? j.seance.dureeEst : 0)), joursPrevus: semaineType.filter((j) => j.seance).length },   // 198 min par semaine prévues (55 + 44 + 55 + 44) : « À adapter », somme de F38

    /* le sélecteur de semaine du 9 au 15 novembre : 0 = lundi */
    selecteur: { titre: 'Cette semaine', sel: 3, faits: [0, 1], prevus: [3, 5], apres: { faits: [0, 1, 3], prevus: [5] } },

    /* les trois moments du jeudi */
    jour: {
      prevue: { heure: '13:20', lab: 'Séance du jour', nom: haut.n, detail: haut.detail, action: 'Commencer', seance: haut, apercu: haut.apercu, autres: `+ ${haut.autres} autres` },
      enCours: { heure: '19:05', lab: 'Séance en cours', nom: haut.n, detail: enCours.hero, action: 'Reprendre la séance', ...enCours },
      faite: { heure: '19:55', lab: 'Séance faite', nom: haut.n, detail: AUJ.hero, lien: 'Voir le détail', seance: AUJ, kcal: Math.round(AUJ.kcal), fin: '19:51',
        record: record('dc', HIST.concat([AUJ])) },                                                   // après la séance : 60 × 10, 1RM ≈ 80 kg, +10 kg depuis le début · 13 séances
    },
    /* les neuf états de la séance du jour (audit, section 3), avec l'exemple à dessiner pour chacun */
    etats: [
      { k: 'enCours', ou: 'jeudi 12, 19:05', lab: 'Séance en cours', nom: haut.n, detail: enCours.hero, action: 'Reprendre la séance' },
      { k: 'faite', ou: 'jeudi 12, 19:55', lab: 'Séance faite', nom: haut.n, detail: AUJ.hero, action: null, suite: 'Voir le détail' },
      { k: 'prevue', ou: 'jeudi 12, 13:20', lab: 'Séance du jour', nom: haut.n, detail: haut.detail, action: 'Commencer' },
      { k: 'repos', ou: 'hors journée d\'exemple : le texte d\'un vendredi 13 vu le jour même', lab: 'Repos aujourd\'hui', nom: 'Repos', detail: 'Prochaine séance : Jambes, demain', action: null, suite: 'Faire une séance quand même' },
      { k: 'vide', ou: 'premier jour, aucun programme', lab: 'Aujourd\'hui', nom: 'Ton programme', detail: 'Crée tes séances (exercices, séries, charges, repos) et choisis leurs jours : Ardane te propose chaque jour la bonne.', action: 'Créer une séance' },
      { k: 'autreFaite', ou: 'lundi 9 novembre', lab: '1 séance faite', nom: haut.n, detail: HIST[21].hero, action: null, suite: 'Voir le détail' },
      { k: 'rattrapee', ou: 'jeudi 5 novembre (semaine dernière)', lab: 'Séance rattrapée', nom: haut.n, detail: 'Faite le vendredi 6 novembre à la place.', action: null, suite: 'Voir le détail' },
      { k: 'autrePrevue', ou: 'samedi 14 novembre', lab: 'Prévu', nom: jambes.n, detail: jambes.detail, action: null,
        passe: { ou: 'samedi 24 octobre', lab: 'Prévu, pas fait', nom: jambes.n, detail: jambes.detail, action: 'Rattraper la séance' } },
      { k: 'rien', ou: 'vendredi 13 novembre', lab: 'Vendredi 13 novembre', nom: 'Repos', detail: 'Aucune séance prévue ce jour-là.', action: null, passe: { ou: 'mercredi 11 novembre', lab: 'Mercredi 11 novembre', detail: 'Aucune séance ce jour-là.' } },
    ],

    /* la semaine : tuiles « Cette semaine » (F7), avant et après la séance du jour */
    semaine: { ...CETTE, tuiles: tuiles(CETTE), dureeTxt: PL.dur(CETTE.min), volumeTxt: nb(CETTE.volume) + NBSP + 'kg', kcalTxt: '≈' + NBSP + nb(CETTE.kcal), seancesTxt: `${CETTE.n} / ${OBJECTIF}`, encore: encore(CETTE.n), p: CETTE.n / OBJECTIF,
      jours: semaineType.map((j, d) => ({ ...j, c: JC[d], date: 9 + d, etat: d < 2 ? 'fait' : d === 3 ? 'aujourd\'hui' : j.seance ? 'prévu' : 'repos' })) },
    semaineApres: { ...APRES, tuiles: tuiles(APRES), dureeTxt: PL.dur(APRES.min), volumeTxt: nb(APRES.volume) + NBSP + 'kg', kcalTxt: '≈' + NBSP + nb(APRES.kcal), seancesTxt: `${APRES.n} / ${OBJECTIF}`, encore: encore(APRES.n), p: APRES.n / OBJECTIF },
    semainePrec: { ...PREC, dureeTxt: PL.dur(PREC.min), volumeTxt: nb(PREC.volume) + NBSP + 'kg' },
    /* à 19:05 : la séance en cours compte dès sa première série dans les quatre tuiles (FitnessMath.sessions, Fitness.swift:571-575) :
       3 / 4, + 6 min (durée depuis le début : à vérifier dans le code), + 600 kg (la série 60 × 10), + 8 kcal. La carte de Mon quotidien, elle, dit encore « 2/4 » (audit, problème 15). */
    semaineEnCours: (function () { const w = { n: CETTE.n + 1, min: CETTE.min + 6, volume: CETTE.volume + 600, kcal: Math.round(sum(CETTE.seances, (h) => h.kcal) + kcal([{ r: 10, kg: 60 }], 230 / 60)) };
      return { ...w, tuiles: tuiles(w), dureeTxt: PL.dur(w.min), volumeTxt: nb(w.volume) + NBSP + 'kg', kcalTxt: '≈' + NBSP + nb(w.kcal), seancesTxt: `${w.n} / ${OBJECTIF}`, encore: encore(w.n), p: w.n / OBJECTIF }; })(),

    /* historique (F52) : le plus récent d'abord ; total « Séances faites » = 23 (24 après la séance du jour) */
    historique: { total: HIST.length, totalApres: HIST.length + 1, liste: HIST.slice().reverse(),
      mois: [{ m: 'Novembre 2026', l: HIST.filter((h) => h.mois === 10).reverse() }, { m: 'Octobre 2026', l: HIST.filter((h) => h.mois === 9).reverse() }, { m: 'Septembre 2026', l: HIST.filter((h) => h.mois === 8).reverse() }],
      rattrapee: HIST.find((h) => h.rattrape), manquee: { iso: '2026-10-24', date: 'Sam. 24 oct.', nom: jambes.n } },
    detail: detail(HIST[21], '18:02'),                                                               // lundi 9 novembre, Haut du corps : 59 min · 4 220 kg

    /* progression (Premium) : « Volume par semaine » (8 barres) et « Records » */
    progression: { semaines: S8, volumes: S8.map((w) => w.volume), lab: S8.map((w) => w.lab), nSeances: S8.map((w) => w.n), enCours: 7, records,
      meilleur: records.reduce((a, b) => (b.rm > a.rm ? b : a)) },                                   // « Meilleur record » de Créer (Premium)
    perfs: { dc: perfs('dc'), squat: perfs('squat'), dm: perfs('dm') },                              // « Mes performances » d'une fiche (Premium)

    /* fiche d'exercice (Premium) : Développé couché (barre). Textes de ExerciseLibrary.swift:185-190 */
    fiche: { exo: X.dc, vues: ['Profil', '3/4'], principaux: ['Pectoraux'], secondaires: ['Triceps', 'Épaules'], pastilles: ['Musculation', 'Intermédiaire', 'Barre', 'Banc'],
      depart: 'Allongé sur le banc, yeux sous la charge, pieds à plat au sol, omoplates serrées et abaissées.',
      execution: ['Saisis la charge un peu plus large que les épaules.', 'Descends lentement vers le bas de la poitrine, coudes à environ 45° du corps.', 'Pousse jusqu\'aux bras tendus, sans verrouiller brutalement les coudes.'],
      amplitude: 'Descends jusqu\'à effleurer la poitrine, sans rebond.', respiration: 'Inspire en descendant, expire en poussant.',
      points: ['Garde les fesses sur le banc et les pieds ancrés.', 'Poignets droits, au-dessus des coudes.'], aEviter: ['Coudes écartés à 90°, qui chargent les épaules.', 'Rebondir sur la poitrine.', 'Décoller les fesses du banc.'],
      alternatives: [['Développé couché haltères', 'Variante'], ['Développé incliné (barre)', 'Variante'], ['Développé décliné', 'Variante'], ['Pompes', 'Mêmes muscles'], ['Pec deck (butterfly)', 'Mêmes muscles']],
      ajout: { enSeance: 'Ajouter à ma séance', sinon: 'Ajouter à une séance', fait: 'Ajouté à « Haut du corps »' } },

    /* bibliothèque (F39 à F44) */
    biblio: { total: 163, ligne: '163 exercices, fiches et démonstrations', types: [['Musculation', 124], ['Cardio', 21], ['Étirement', 10], ['Mobilité', 8]], niveaux: [['Débutant', 102], ['Intermédiaire', 54], ['Avancé', 7]],
      filtres: ['Muscle', 'Équipement', 'Type', 'Niveau'], equipements: ['Poids du corps', 'Haltères', 'Barre', 'Machine', 'Poulie', 'Kettlebell', 'Élastique', 'Banc', 'Barre de traction', 'Autre'],
      parMuscle, favoris: [X.dc, X.trac, X.squat], plusFaits: plusFaits.slice(0, 5), recents: [X.squat, X.sdt, X.lc, X.dc, X.trac],
      mesExercices: [{ n: 'Tirage élastique maison', ligne: 'Dos · Élastique', notes: 'Élastique vert, accroché à la porte.' }],
      recherche: { q: 'développé', n: 12, resultats: ['Développé couché (barre)', 'Développé couché haltères', 'Développé couché prise serrée', 'Développé décliné', 'Développé incliné (barre)', 'Développé incliné haltères'] },
      vide: 'Aucun exercice ne correspond. Essaie un autre mot ou retire un filtre.' },

    /* pas (F10, F56, F61) */
    pas: { n: 5480, objectif: PGOAL, p: 5480 / PGOAL, km: '3,9 km', etages: '6 étages', ligne: 'objectif 8 000 · 3,9 km · 6 étages', kcal: pasKcal(5480), kcalTxt: '~' + NBSP + nb(pasKcal(5480)) + NBSP + 'kcal',
      j7: P7, lab7: ['V', 'S', 'D', 'L', 'M', 'M', 'J'], moyenne: Math.round(sum(P7) / 7), soir: 7360 },

    /* Mon quotidien : la carte Fitness (pleine largeur, 2e, deux pages) et la carte Pas (demi-largeur) */
    quotidien: {
      seance: { prevue: { titre: 'Séance du jour', nom: haut.n, ligne: haut.quotidien, cta: 'Commencer', pastille: 'Maintenant' }, enCours: enCours.quotidien, faite: { nom: haut.n, ligne: `Faite · ${AUJ.nbSeries} séries`, volume: nb(AUJ.volume) + NBSP + 'kg soulevés' } },
      semaine: { titre: `${CETTE.n}/${OBJECTIF} séances`, ronds: [1, 1, 0, 0, 0, 0, 0], ligne: encore(CETTE.n) },
      vide: 'Crée ton programme : ta séance du jour apparaîtra ici.', pastilleAccueil: `${CETTE.n} séances cette semaine` },

    /* ce que voit un compte gratuit (audit, section 7) */
    gratuit: { biblioCarte: ['Toute la bibliothèque d\'exercices', 'Démonstrations, techniques, alternatives et tes performances sur chaque exercice. Tes propres exercices restent gratuits.'],
      progressionCarte: ['La progression est dans Premium', 'Ton volume semaine après semaine, l\'évolution de tes charges et tous tes records, exercice par exercice. Tes séances restent enregistrées : tout s\'affiche dès que tu passes à Premium.', 'Découvrir Premium'],
      ficheCarte: 'Cet exercice est dans Premium', masque: ['« La dernière fois »', '« Choisir dans la bibliothèque »', 'les suggestions de nom', 'la fiche derrière le bouton ⓘ', '« Meilleur record »', '6 widgets sur 9'] },

    /* widgets (F63), rappels (F64) : pour les légendes et la planche de cohérence */
    widgets: [['Séance du jour', 'G'], ['Prochaine série', 'G'], ['Régularité', 'G'], ['Repos', 'P'], ['Volume de la semaine', 'P'], ['Records', 'P'], ['Calories brûlées', 'P'], ['Mois d\'entraînement', 'P'], ['Tableau fitness', 'P']],
    rappels: ['Ta séance t\'attend', 'Ta semaine sportive', 'Un petit tour ?', 'Séance demain', 'Bilan sportif de la semaine', 'Nouvelle semaine', 'Repos terminé', 'Séance terminée', 'Belle progression', 'Objectif de la semaine atteint'],
    textes: { note: 'Calories et volumes estimés à partir de tes séances et de ton poids : des repères, pas des mesures.', terminer: 'Terminer la séance ?', terminerOk: 'Terminer et enregistrer', annuler: 'Annuler la séance ? Elle ne sera pas comptée.',
      supprimer: 'Supprimer cette séance ? Elle ne sera plus comptée et tu pourras la refaire.', choix: 'Choisis la séance à faire.', libre: ['Séance libre', 'Ajoute les exercices au fur et à mesure'], historiqueVide: 'Aucune séance pour l\'instant. Commence celle du jour depuis Fitness : elle s\'enregistre ici.',
      progressionVide: ['Pas encore de progression', 'Fais quelques séances : tes charges, ton volume et tes records apparaîtront ici.'], actions: ['Passer le repos', 'Passer la série', 'Passer cet exercice', 'Annuler la dernière série', 'Choisir dans la bibliothèque', 'Ajouter un exercice', 'Terminer la séance', 'Annuler la séance'] },
    aRemplir: [['Programme d\'entraînement', 'Tes séances et les jours où tu les fais.'], ['Séances par semaine', 'Pour suivre ta régularité semaine après semaine.'], ['Poids', 'Pour estimer les calories brûlées.'], ['Objectif de pas', '6 000 · 8 000 · 10 000 · 12 000 pas']],

    /* ---------- CE QUI N'EXISTE PAS DANS L'APP : à étiqueter « Nouveau » partout où c'est dessiné ----------
       Même nom, même forme, mêmes chiffres dans toutes les directions qui l'emploient (CONCEPT.md, « Nouveautés communes »). */
    nouveau: {
      recap: { id: 'N1', nom: 'Récapitulatif de fin de séance', titre: 'Séance terminée', lignes: [['Durée', PL.dur(AUJ.min)], ['Séries', String(AUJ.nbSeries)], ['Volume', nb(AUJ.volume) + NBSP + 'kg'], ['Calories', '≈' + NBSP + nb(Math.round(AUJ.kcal)) + NBSP + 'kcal']],
        record: 'Nouveau record : Développé couché (barre), 60 × 10', semaine: `${APRES.n} / ${OBJECTIF} séances · ${encore(APRES.n)}`, boutons: ['Voir le détail', 'Annuler la dernière série'], pourquoi: 'Audit, problème 6 et section 9, point 7.' },
      repos15: { id: 'N2', nom: 'Régler le repos pendant le repos', boutons: ['− 15 s', '+ 15 s'], pourquoi: 'Audit, problème 10 et section 9, point 4. Le repos ne se règle aujourd\'hui que dans l\'éditeur.' },
      clavier: { id: 'N3', nom: 'Taper la charge avant de valider', titre: 'Charge', propositions: [kgTxt(57.5), kgTxt(60), kgTxt(62.5)], pourquoi: 'Audit, problème 9 : seulement − / + par 2,5 kg avant de valider.' },
      serieSemaines: { id: 'N4', nom: 'Série de semaines dans la mini-app', n: serieSem, txt: `${serieSem} semaines de suite à l'objectif`, pourquoi: 'Audit, problème 28 : le calcul existe (widget « Régularité »), pas son affichage dans la mini-app.' },
      calendrier: { id: 'N5', nom: 'Calendrier du mois dans la mini-app', mois: 'Novembre 2026', faits: HIST.filter((h) => h.mois === 10).map((h) => h.jour), rattrape: [5], prevus: [12, 14, 16, 17, 19, 21, 23, 24, 26, 28, 30],
        txt: `${HIST.filter((h) => h.mois === 10).length} séances en novembre`, pourquoi: 'Section 9, points 2 et 6 : existe seulement dans le widget « Mois d\'entraînement » (Premium).' },
      ecart: { id: 'N6', nom: 'Comparer avec la semaine d\'avant', prec: `Semaine dernière : ${PREC.n} séances · ${PL.dur(PREC.min)} · ${nb(PREC.volume)}${NBSP}kg`, pourquoi: 'Audit, problème 28 : l\'écart existe dans le widget « Volume de la semaine » (Premium).' },
      tempoNotes: { id: 'N7', nom: 'Tempo et notes affichés pendant la séance', ex: `Tempo ${haut.exos[0].tempo} · ${haut.exos[0].notes}`, pourquoi: 'Audit, problème 11 : saisis dans l\'éditeur, jamais relus.' },
      ordre: { id: 'N8', nom: 'Changer l\'ordre et retirer un exercice précis', pourquoi: 'Audit, problème 12 : seulement « Retirer le dernier exercice ».' },
      parMuscle: { id: 'N9', nom: 'Volume par groupe de muscles', periode: 'Cette semaine', pourquoi: 'Section 9, point 2 : aucune statistique par muscle aujourd\'hui.' },
      filtreHisto: { id: 'N10', nom: 'Filtrer l\'historique par séance', puces: ['Toutes', haut.n, jambes.n], comptes: [HIST.length, HIST.filter((h) => h.k === 'haut').length, HIST.filter((h) => h.k === 'jambes').length], pourquoi: 'Section 9, point 6 : ni recherche ni filtre.' },
    },

    /* outils de texte */
    plan, serie, charge, mmss, kg: kgTxt, epley, dCourt, dLong, encore,
    exoLigne: (e) => `${e.n} · ${e.plan}`,                                                           // « Développé couché (barre) · 4 × 10 · 60 kg »
  };

  /* volume par groupe de muscles, cette semaine (N9, Nouveau) : chaque série va au muscle principal de son exercice */
  N.nouveau.parMuscle.groupes = (function () { const g = {}; CETTE.seances.forEach((h) => h.series.forEach((z) => { const m = X[z.x].muscle; g[m] = g[m] || { m, series: 0, volume: 0 }; g[m].series++; g[m].volume += z.r * z.kg; }));
    return Object.values(g).sort((a, b) => b.series - a.series); })();

  /* ----- contrôle : les repères du guide et de cristal.js ne sont pas contredits ; les sommes sont justes ----- */
  N.verifier = function () { const err = [], ok = (c, m) => { if (!c) err.push(m); };
    ok(FONCTIONS.length === 68 && FONCTIONS.every((f, i) => f[0] === 'F' + (i + 1)), 'FONCTIONS : 68 fonctions attendues, F1 à F68 dans l\'ordre');
    ok(FONCTIONS.filter((f) => f[2] === 'P').length === 12 && FONCTIONS.filter((f) => f[2] === 'G+P').length === 8, 'FONCTIONS : 12 Premium et 8 mixtes attendues');
    ok(haut.nbEx === 6 && haut.series === 18 && haut.dureeEst === 55 && haut.volumePlan === 4320, 'Haut du corps : 6 exercices · 18 séries · environ 55 min · 4 320 kg au plan');
    ok(jambes.nbEx === 5 && jambes.series === 15 && jambes.dureeEst === 44, 'Jambes : 5 exercices · 15 séries · environ 44 min');
    ok(AUJ.nbSeries === 18 && AUJ.min === 52 && AUJ.volume === 4320, 'Séance du jour faite : 18 séries · 52 min · 4 320 kg (repère du guide)');
    ok(HIST.length === 23, 'Historique : 23 séances faites avant celle du jour');
    ok(CETTE.n === 2 && CETTE.min === 112 && CETTE.volume === 8460, 'Cette semaine : 2 séances · 1 h 52 · 8 460 kg (planche Cristal 04)');
    ok(APRES.n === 3 && APRES.min === 164 && APRES.volume === 12780, 'Après la séance : 3 séances · 2 h 44 · 12 780 kg (planche Cristal 04)');
    ok(N.semaineEnCours.n === 3 && N.semaineEnCours.volume === 9060 && N.semaineEnCours.min === 118, 'À 19:05 : 3 / 4 · 1 h 58 · 9 060 kg');
    ok(sum(S8, (w) => w.n) === 23 && sum(S8, (w) => w.volume) === sum(HIST, (h) => h.volume), 'Les 8 semaines contiennent les 23 séances');
    ok(N.perfs.dc.courbe.length === 12 && N.perfs.dc.record.txt.replace(/\s/g, '') === '57,5×10' && N.perfs.dc.record.rm === 77 && N.perfs.dc.record.gain === 7.5 && N.perfs.dc.frequence === 8, 'Développé couché : 12 séances, record 57,5 × 10, 1RM ≈ 77, +7,5 kg, 8 séances en 30 jours');
    ok(N.jour.faite.record.rm === 80 && N.jour.faite.record.gain === 10 && N.jour.faite.record.seances === 13, 'Après la séance : record 60 × 10, 1RM ≈ 80, +10 kg, 13 séances');
    ok(records.length === 7 && N.nouveau.serieSemaines.n === 2, '7 records ; 2 semaines de suite à l\'objectif');
    ok(N.pas.moyenne === 8323 && N.pas.kcal === 224, 'Pas : moyenne 8 323 sur 7 jours, ~ 224 kcal');
    ok(parMuscle.length === 13 && sum(parMuscle, (m) => m[1]) === 157 && sum(N.biblio.types, (t) => t[1]) === 163 && sum(N.biblio.niveaux, (t) => t[1]) === 163, 'Bibliothèque : 163 exercices par type et par niveau ; 13 groupes de muscles (157 : le cardio pur est hors groupe)');
    ok(N.programme.dureeSemaine === 198, 'Programme : 198 min prévues par semaine');
    if (typeof DAY !== 'undefined') { const d = DAY.journee, s = DAY.soiree.workout;
      ok(d.workout.prog === haut.n && d.workout.meta === haut.quotidien, 'cristal.js DAY.journee.workout');
      ok(d.week.n === CETTE.n && d.week.goal === OBJECTIF && d.week.left === OBJECTIF - CETTE.n, 'cristal.js DAY.journee.week');
      ok(s.ex === enCours.quotidien.ex && s.set === enCours.serie && s.sets === enCours.series && s.rest === enCours.repos, 'cristal.js DAY.soiree.workout');
      ok(d.steps.n === N.pas.n && d.steps.goal === PGOAL && DAY.soiree.steps.n === N.pas.soir, 'cristal.js DAY.*.steps'); }
    if (typeof STEPS7 !== 'undefined') ok(STEPS7.past.every((v, i) => v === P7[i]) && STEPS7.goal === PGOAL, 'cristal.js STEPS7');
    err.forEach((m) => console.error('fitness.js : ' + m));
    return err; };
  return N;
})();
FIT.verifier();
