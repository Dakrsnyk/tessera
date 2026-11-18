/* voyage.js : le JS commun du sujet « Voyage », refonte UX/UI des mini-apps, 2026-11-17.
   À charger après ../../2026-11-15-cristal/cristal.js et ../base/planches.js, avant le script de la planche.
   Il contient :
     FONCTIONS (alias FEATURES)  la liste F1…F34 de l'audit (../audit/07-voyage.md, section 4), dans son ordre, avec ses numéros.
                                 [n°, libellé court, accès 'G' | 'P' | 'G+P', ce qu'elle fait en quelques mots]
     VOY                         les données d'exemple du sujet (jeudi 12 novembre 2026, 13 h 20) et leurs calculs.
     VOY.ui                      pièces d'écran communes (sélecteur de semaine d'un autre mois, ligne du programme).
   Règles :
     - Aucun repère existant sauf celui de la mission : Lisbonne, du 12 au 19 juin 2027, budget 1 500 $, objectif d'épargne « Voyage à Lisbonne »
       de Finances (640 $ sur 1 500 $). Le reste (vols, hôtel, activités, dépenses) est fixé UNE FOIS ici : vol TP 258 YUL → LIS et Hôtel Alfama (HX4821)
       reprennent les données d'exemple de l'app (audit section 5), le reste est inventé pour la planche.
     - Chaque chiffre est calculé avec les règles du code (audit, section 5) : jours restants par jour entier, « Jour N / total », dépenses converties
       dans la devise de l'app au taux de référence, reste = budget − dépensé, reste par jour = reste ÷ jours restants (jour courant compris).
     - Les heures du programme sont écrites comme le programme les montre (24 h, sans conversion de fuseau : voir le problème 13 de l'audit).
     - Compte montré : GRATUIT. Toute la mini-app est gratuite ; Premium = 5 widgets sur 7 et le pack « Voyageur » seulement (F20 à F25).
     - Ce qui n'existe pas dans l'app est rangé sous VOY.nouveau et nulle part ailleurs : à étiqueter « Nouveau » sur les planches. */

/* ================= 1. Les 34 fonctions existantes (audit, section 4) ================= */
const FONCTIONS = [
  ['F1', 'Voyage en un coup d\'œil : compte à rebours ou jour du voyage, heure locale', 'G', 'Ville, « Départ dans N jours » ou « Jour N / total », dates, « Heure locale » ; lecture seule'],
  ['F2', 'Sélecteur de semaine avec marques', 'G', 'Choisir un jour, changer de semaine, « Aujourd\'hui » ; point sous les jours du programme'],
  ['F3', 'Programme du jour choisi', 'G', 'Lignes du jour : vol, arrivée ou départ d\'hébergement, activité, avec l\'heure'],
  ['F4', '« À venir » : prochain vol, hébergement, activité', 'G', 'Jusqu\'à 3 lignes ; ce que le jour choisi montre déjà est retiré'],
  ['F5', 'Programme complet jour par jour', 'G', 'Une carte par jour qui a un élément ; ajouter vol, hébergement, activité'],
  ['F6', 'Saisie d\'un voyage', 'G', 'Destination, départ, retour, devise sur place, fuseau horaire'],
  ['F7', 'Saisie d\'un vol', 'G', 'Numéro, départ, arrivée, décollage, atterrissage, terminal, porte, siège'],
  ['F8', 'Saisie d\'un hébergement', 'G', 'Nom, adresse, arrivée, départ, numéro de réservation'],
  ['F9', 'Saisie d\'une activité', 'G', 'Titre, date et heure, lieu'],
  ['F10', 'Budget du voyage : total, jauge, reste, reste par jour', 'G', '« Dépensé », jauge, « Il reste X sur Y », « Soit X par jour jusqu\'au retour »'],
  ['F11', 'Dépenses de voyage, dans la devise payée', 'G', 'Montant, devise, type, note, date ; ajouter, modifier, supprimer'],
  ['F12', 'Répartition « Par type »', 'G', 'Anneau et légende : six types avec montants'],
  ['F13', 'Tuile « Budget »', 'G', 'Total dépensé, budget, rouge si dépassé'],
  ['F14', 'Liste « À ne pas oublier » et sa tuile', 'G', 'Éléments, « N sur M prêts » ; ajouter, cocher, supprimer en glissant'],
  ['F15', '« Ajouter l\'essentiel à emporter »', 'G', '6 éléments, 3 de plus à l\'étranger, sans doublon'],
  ['F16', 'Carte « Devise » : taux et conversions', 'G', 'Taux BCE ; 10, 50 et 100 de la devise du voyage dans la devise de l\'app'],
  ['F17', 'Recherche de ville (fuseau, devise, coordonnées)', 'G', 'Résultats « Ville, Pays » ; remplit destination, fuseau, devise'],
  ['F18', 'Widget « Départ en voyage »', 'G', 'Jours avant le départ ou « Jour N » ; petit, moyen, écran verrouillé'],
  ['F19', 'Widget « Heure sur place »', 'G', 'Heure à destination, écart avec ici'],
  ['F20', 'Widget « Vol »', 'P', 'Numéro, heure ou minuteur, trajet, terminal, porte, siège'],
  ['F21', 'Widget « Hôtel »', 'P', 'Nom, adresse, arrivée ou départ, réservation'],
  ['F22', 'Widget « Devise »', 'P', 'Montant converti, trois lignes de taux'],
  ['F23', 'Widget « Avancement du voyage »', 'P', '« N/T jours », jours restants'],
  ['F24', 'Widget « Prochaine activité »', 'P', 'Titre, jour et heure, lieu, activités suivantes'],
  ['F25', 'Pack « Voyageur » (Store)', 'P', '6 widgets : départ, vol, hôtel, avancement, heure sur place, devise'],
  ['F26', 'Page de données de l\'espace : toutes les entrées', 'G', 'Voyages, vols, hébergements, activités ; créer, modifier, supprimer en glissant'],
  ['F27', 'Réglage de la devise de l\'app', 'G', '« Mes paramètres » › « Devise » : CAD, USD, EUR, GBP, CHF'],
  ['F28', 'Sauvegarde et effacement des données', 'G', 'Le fichier travel fait partie de la sauvegarde ; aucun écran propre'],
  ['F29', 'Rappel « Départ pour <ville> » dans Mon quotidien', 'G', 'Départ aujourd\'hui ou dans les 3 jours'],
  ['F30', 'Carte « Voyage » de Mon quotidien', 'G', '« <ville> · jour N » ou « <ville> · J-N » ; carte vide : « Ajoute un voyage… »'],
  ['F31', 'Carte de donnée « Voyage »', 'G', 'Bloc « À remplir » et Studio : prochaine ville et date, « Nouveau voyage », « Tout voir »'],
  ['F32', 'Bouton flottant et dialogue « Ajouter »', 'G', '« Vol », « Hébergement », « Activité », « Dépense », « Nouveau voyage »'],
  ['F33', '« Mes voyages » : liste des voyages', 'G', '« Modifier le voyage », autres voyages (4 au plus), « Nouveau voyage »'],
  ['F34', '« Montant à convertir » du widget Devise', 'G', 'Montant dans la devise de l\'app, 100 par défaut'],
];
const FEATURES = FONCTIONS;

/* ================= 2. Les données d'exemple ================= */
const VOY = (function () {
  const MOIS = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juill.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  const MOIS_L = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
  const JC = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
  const JL = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
  const dt = (y, m, j, h = 0, mi = 0) => new Date(Date.UTC(y, m - 1, j, h, mi));        // m = 1 à 12 ; les dates sont écrites telles qu'elles s'affichent
  const dow = (d) => (d.getUTCDay() + 6) % 7;                                              // 0 = lundi
  const jour0 = (d) => Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
  const nj = (a, b) => Math.round((jour0(b) - jour0(a)) / 864e5);                          // jours entiers de a à b
  const meme = (a, b) => nj(a, b) === 0;
  const p2 = (n) => String(n).padStart(2, '0');
  const heure = (d) => p2(d.getUTCHours()) + ':' + p2(d.getUTCMinutes());
  const dateC = (d) => JC[dow(d)] + ' ' + d.getUTCDate() + ' ' + MOIS[d.getUTCMonth()];     // « sam. 12 juin »
  const dateL = (d) => JL[dow(d)][0].toUpperCase() + JL[dow(d)].slice(1) + ' ' + d.getUTCDate() + ' ' + MOIS_L[d.getUTCMonth()];   // « Samedi 12 juin »
  const plage = (a, b) => (a.getUTCMonth() === b.getUTCMonth() ? a.getUTCDate() + ' – ' + b.getUTCDate() + ' ' + MOIS[b.getUTCMonth()] : a.getUTCDate() + ' ' + MOIS[a.getUTCMonth()] + ' – ' + b.getUTCDate() + ' ' + MOIS[b.getUTCMonth()]) + ' ' + b.getUTCFullYear();
  const sum = (L, f) => L.reduce((s, x) => s + f(x), 0);
  const r2 = (x) => Math.round(x * 100) / 100;
  const eur = (x) => PL.n(x, Number.isInteger(x) ? 0 : 2) + NBSP + '€';

  const AUJ = dt(2026, 11, 12, 13, 20);                                                    // jeudi 12 novembre 2026, 13 h 20
  const ENV = dt(2027, 6, 14, 15, 40);                                                     // même voyage, en cours : lundi 14 juin 2027, 15 h 40 (jour 3)

  /* ---------- le voyage actif (la mission : Lisbonne, du 12 au 19 juin 2027, budget 1 500 $) ---------- */
  const T = { ville: 'Lisbonne', pays: 'Portugal', depart: dt(2027, 6, 12), retour: dt(2027, 6, 19), devise: 'EUR', fuseau: 'Europe/Lisbon', decalage: 5, budget: 1500 };
  const total = nj(T.depart, T.retour) + 1;                                                // « Jour N / total » : 8 jours
  const vols = [
    { n: 'TP 258', de: 'YUL', a: 'LIS', dep: dt(2027, 6, 12, 18, 40), arr: dt(2027, 6, 13, 6, 5), siege: '24A' },     // terminal et porte : pas encore connus (« — »)
    { n: 'TP 257', de: 'LIS', a: 'YUL', dep: dt(2027, 6, 19, 16, 20), arr: dt(2027, 6, 19, 18, 25), siege: '31C' },
  ];
  const sejours = [{ nom: 'Hôtel Alfama', adresse: 'Rua dos Remédios 62', arr: dt(2027, 6, 13, 15, 0), dep: dt(2027, 6, 19, 11, 0), conf: 'HX4821' }];
  const activites = [
    { d: dt(2027, 6, 14, 10, 0), titre: 'Visite d\'Alfama', lieu: 'Portas do Sol' },
    { d: dt(2027, 6, 14, 20, 0), titre: 'Souper avec fado', lieu: 'Bairro Alto' },
    { d: dt(2027, 6, 15, 9, 30), titre: 'Excursion à Sintra', lieu: 'Gare du Rossio' },
    { d: dt(2027, 6, 16, 14, 0), titre: 'Tour de Belém', lieu: 'Tour de Belém' },
  ];

  /* ---------- budget et dépenses : tout est converti dans la devise de l'app (CAD) au taux de référence ---------- */
  const taux = { EUR: 0.66 };                                                              // « 1 CAD = 0,660 EUR » (audit, section 3)
  const enCAD = (e) => (e.dev === 'EUR' ? e.m / taux.EUR : e.m);
  const TYPES = [
    { k: 'transport', n: 'Transport', i: 'plane', c: 'var(--c-voy)' }, { k: 'hebergement', n: 'Hébergement', i: 'bed', c: 'var(--c-lip)' },
    { k: 'repas', n: 'Repas', i: 'fork', c: 'var(--c-nut)' }, { k: 'activites', n: 'Activités', i: 'ticket', c: 'var(--c-hab)' },
    { k: 'achats', n: 'Achats', i: 'bag', c: 'var(--c-etu)' }, { k: 'autre', n: 'Autre', i: 'tag', c: 'var(--c-pro)' },
  ];
  const depenses = [                                                                       // la plus récente d'abord, comme la liste de l'app
    { d: dt(2027, 6, 14), k: 'activites', m: 6.6, dev: 'EUR', note: 'Tramway 28, carte 24 h' },
    { d: dt(2027, 6, 13), k: 'repas', m: 9.4, dev: 'EUR', note: 'Pastéis de nata' },
    { d: dt(2027, 6, 13), k: 'transport', m: 18, dev: 'EUR', note: 'Taxi de l\'aéroport' },
    { d: dt(2026, 11, 10), k: 'hebergement', m: 120, dev: 'EUR', note: 'Acompte, Hôtel Alfama' },
    { d: dt(2026, 10, 28), k: 'transport', m: 420, dev: 'CAD', note: 'Billets d\'avion' },
  ];
  const enSaisie = { d: dt(2027, 6, 14), k: 'repas', m: 12.8, dev: 'EUR', note: 'Café et sandwich' };   // la dépense que la feuille de l'écran 6 est en train d'ajouter
  const bilan = (liste, jusqua) => { const L = jusqua ? liste.filter((e) => e.d <= jusqua) : liste;
    const parType = TYPES.map((t) => ({ ...t, m: sum(L.filter((e) => e.k === t.k), enCAD) })).filter((t) => t.m > 0);
    return { liste: L, total: sum(L, enCAD), parType }; };
  const avant = bilan(depenses, AUJ), enVoy = bilan(depenses, ENV);
  const reste = (b, budget) => budget - b.total;
  const joursRestants = nj(ENV, T.retour) + 1;                                             // jour courant compris : du 14 au 19 juin = 6

  /* ---------- la liste « À ne pas oublier » (essentiels d'un voyage à l'étranger : 6 + 3, plus un élément ajouté à la main) ---------- */
  const liste = [['Passeport', 1], ['Carte bancaire', 1], ['Confirmations de réservation', 1], ['Assurance voyage', 0], ['Adaptateur de prise', 0],
    ['Chargeur de téléphone', 0], ['Médicaments', 0], ['Vêtements', 0], ['Trousse de toilette', 0], ['Crème solaire', 0]].map(([t, ok]) => ({ t, ok: !!ok }));

  /* ---------- l'objectif d'épargne de Finances : le même voyage ---------- */
  const epargne = { nom: 'Voyage à Lisbonne', actuel: 640, cible: 1500, echeance: 'juin 2027' };

  /* ---------- les voyages terminés (pour « Mes voyages ») : devise CAD, pour ne pas inventer de taux ---------- */
  const mk = (o) => ({ ...o, ...bilan(o.depenses), jours: new Set([].concat(o.vols.map((v) => jour0(v.dep)), o.sejours.flatMap((s) => [jour0(s.arr), jour0(s.dep)]), o.activites.map((a) => jour0(a.d)))).size });
  const ny = mk({ ville: 'New York', depart: dt(2026, 8, 20), retour: dt(2026, 8, 23), budget: 900, prets: [8, 8],
    vols: [{ dep: dt(2026, 8, 20, 7, 50) }, { dep: dt(2026, 8, 23, 17, 30) }], sejours: [{ arr: dt(2026, 8, 20, 15, 0), dep: dt(2026, 8, 23, 11, 0) }],
    activites: [{ d: dt(2026, 8, 21, 10, 0) }, { d: dt(2026, 8, 22, 9, 30) }],
    depenses: [{ k: 'transport', m: 178.4, dev: 'CAD' }, { k: 'hebergement', m: 389, dev: 'CAD' }, { k: 'repas', m: 214.6, dev: 'CAD' }, { k: 'achats', m: 64.3, dev: 'CAD' }] });
  const paris = mk({ ville: 'Paris', depart: dt(2025, 9, 14), retour: dt(2025, 9, 21), budget: 2200, prets: [10, 10],
    vols: [{ dep: dt(2025, 9, 14, 21, 5) }, { dep: dt(2025, 9, 21, 10, 40) }], sejours: [{ arr: dt(2025, 9, 15, 14, 0), dep: dt(2025, 9, 21, 10, 0) }],
    activites: [{ d: dt(2025, 9, 16, 10, 0) }, { d: dt(2025, 9, 18, 14, 30) }],
    depenses: [{ k: 'transport', m: 892, dev: 'CAD' }, { k: 'hebergement', m: 784.5, dev: 'CAD' }, { k: 'repas', m: 412.1, dev: 'CAD' }, { k: 'activites', m: 156, dev: 'CAD' }, { k: 'achats', m: 106.5, dev: 'CAD' }] });

  /* ---------- le programme : les lignes d'un jour (vols, arrivée et départ d'hébergement, activités), triées par heure ---------- */
  const programme = (d) => { const L = [];
    vols.filter((v) => meme(v.dep, d)).forEach((v) => L.push({ ref: v, h: heure(v.dep), t: 'Vol ' + v.n, s: v.de + ' → ' + v.a + ' · siège ' + v.siege, i: 'plane' }));
    sejours.forEach((s) => { if (meme(s.arr, d)) L.push({ ref: s, h: heure(s.arr), t: 'Arrivée · ' + s.nom, s: s.adresse, i: 'bed', c: 'var(--c-ent)' });
      if (meme(s.dep, d)) L.push({ ref: s, h: heure(s.dep), t: 'Départ · ' + s.nom, s: s.adresse, i: 'bed', c: 'var(--c-ent)' }); });
    activites.filter((a) => meme(a.d, d)).forEach((a) => L.push({ ref: a, h: heure(a.d), t: a.titre, s: a.lieu, i: 'ticket', c: 'nut' }));
    return L.sort((x, y) => x.h.localeCompare(y.h)); };
  const joursProg = []; for (let k = -1; k <= total; k++) { const d = new Date(T.depart.getTime() + k * 864e5); if (programme(d).length) joursProg.push(d); }
  /* « À venir » : prochain vol, hébergement (arrivée, ou départ si on y est), activité ; ce que le jour choisi (sel) montre déjà est retiré */
  const aVenir = (maintenant, sel) => { const vus = programme(sel).map((l) => l.ref), L = [];
    const v = vols.find((x) => x.dep >= maintenant && !vus.includes(x)); if (v) L.push({ i: 'plane', t: 'Vol ' + v.n, s: dateC(v.dep) + ' · ' + v.de + ' → ' + v.a + ' · siège ' + v.siege });
    const h = sejours.find((x) => x.dep >= maintenant && !vus.includes(x)); if (h) L.push({ i: 'bed', c: 'var(--c-ent)', t: h.nom, s: (h.arr >= maintenant ? 'Arrivée · ' + dateC(h.arr) : 'Départ · ' + dateC(h.dep)), r: h.conf });
    const a = activites.find((x) => x.d >= maintenant && !vus.includes(x)); if (a) L.push({ i: 'ticket', c: 'nut', t: a.titre, s: dateC(a.d) + ' · ' + a.lieu });
    return L; };

  const N = {
    jour: { date: 'Jeudi 12 novembre 2026', heure: '13:20' }, AUJ, ENV, T, total, taux, vols, sejours, activites, depenses, enSaisie, TYPES, liste, epargne, ny, paris,
    dt, dow, nj, dateC, dateL, plage, heure, eur, r2, programme, joursProg, aVenir, bilan,
    avant, enVoy, joursRestants,
    // chiffres du voyage vus du 12 novembre 2026 (compte à rebours) et du 14 juin 2027 (jour 3)
    avantJours: nj(AUJ, T.depart), jourN: nj(T.depart, ENV) + 1,
    heureLocale: (h) => { const [a, b] = h.split(':').map(Number); return p2((a + T.decalage) % 24) + ':' + p2(b); },
    resteAvant: reste(avant, T.budget), resteEnVoy: reste(enVoy, T.budget), parJour: reste(enVoy, T.budget) / joursRestants,
    pctAvant: avant.total / T.budget,
    epargnePct: epargne.actuel / epargne.cible,
    // la carte « Voyage » de Mon quotidien : nom, icône, couleur de la mini-app ; une phrase (audit, F30)
    carte: { titre: 'Voyage', icone: 'plane', phrase: 'Lisbonne · J-' + nj(AUJ, T.depart), phraseEnVoyage: 'Lisbonne · jour ' + (nj(T.depart, ENV) + 1) },
    txt: {
      depart: 'Ajoute un voyage : compte à rebours, heure sur place, vols, hébergements, programme, budget et liste des choses à ne pas oublier, au même endroit.',
      taux: 'Taux de référence de la BCE du ' + dateC(AUJ) + ' (Frankfurter).',
    },
    /* ----- CE QUI N'EXISTE PAS dans l'app : à étiqueter « Nouveau » (jeton, légende, case de texte). Jamais ailleurs. ----- */
    nouveau: {
      // audit section 8 (problèmes 1 à 4) et section 9 (« consulter un voyage passé », « supprimer depuis la mini-app ») : un voyage fini n'ouvre aujourd'hui que son formulaire
      mesVoyages: { titre: 'Mes voyages', supprimer: 'Supprimer le voyage' },
      // audit section 9 : « lien avec un objectif d'épargne » ; la mission §8 : mini-apps qui communiquent
      epargne: { titre: epargne.nom, sous: 'Objectif d\'épargne · Finances' },
    },
  };

  /* ----- contrôle : les calculs sont justes, aucune valeur inconnue devenue zéro ----- */
  N.verifier = function () { const err = [], ok = (c, m) => { if (!c) err.push(m); };
    ok(FONCTIONS.length === 34 && FONCTIONS.every((f, i) => f[0] === 'F' + (i + 1)), 'FONCTIONS : 34 fonctions attendues, F1 à F34 dans l\'ordre');
    ok(FONCTIONS.filter((f) => f[2] !== 'G').map((f) => f[0]).join() === 'F20,F21,F22,F23,F24,F25', 'FONCTIONS : Premium F20 à F25 seulement');
    ok(N.avantJours === 212, 'Compte à rebours : J-212 le 12 novembre 2026');
    ok(dow(T.depart) === 5 && dow(T.retour) === 5 && dow(AUJ) === 3, 'Départ et retour un samedi ; le 12 novembre 2026 est un jeudi');
    ok(total === 8 && N.jourN === 3 && joursRestants === 6, 'Voyage de 8 jours ; le 14 juin est le jour 3 ; 6 jours restants, jour courant compris');
    ok(N.heureLocale('13:20') === '18:20', 'Heure locale : 18:20 quand il est 13:20 à Montréal');
    ok(r2(avant.total) === 601.82 && r2(N.resteAvant) === 898.18 && Math.round(N.pctAvant * 100) === 40, 'Avant le départ : 601,82 $ dépensés, il reste 898,18 $ sur 1 500 $ (40 %)');
    ok(Math.abs(sum(avant.parType, (t) => r2(t.m)) - r2(avant.total)) < 0.011, 'Par type : la somme des lignes = le total');
    ok(r2(enVoy.total) === 653.33 && r2(N.resteEnVoy) === 846.67 && r2(N.parJour) === 141.11, 'En voyage (14 juin) : 653,33 $ dépensés, il reste 846,67 $, soit 141,11 $ par jour');
    ok(Math.abs(sum(enVoy.parType, (t) => r2(t.m)) - r2(enVoy.total)) < 0.011, 'Par type (en voyage) : la somme des lignes = le total');
    ok(r2(ny.total) === 846.3 && r2(ny.total - ny.budget) === -53.7 && ny.jours === 4, 'New York : 846,30 $ sur 900 $, 4 jours au programme');
    ok(r2(paris.total) === 2351.1 && r2(paris.total - paris.budget) === 151.1, 'Paris : 2 351,10 $ sur 2 200 $, dépassé de 151,10 $');
    ok(Math.round(N.epargnePct * 100) === 43 && epargne.cible === T.budget, 'Épargne : 640 $ sur 1 500 $ (43 %), la même cible que le budget');
    ok(r2(10 / taux.EUR) === 15.15 && r2(50 / taux.EUR) === 75.76 && r2(100 / taux.EUR) === 151.52, 'Devise : 10 € = 15,15 $, 50 € = 75,76 $, 100 € = 151,52 $');
    ok(liste.length === 10 && liste.filter((x) => x.ok).length === 3, 'Liste : 3 prêts sur 10');
    ok(aVenir(AUJ, T.depart).length === 3 && programme(T.depart).length === 1, '« À venir » : 3 lignes ; programme du 12 juin : le vol');
    ok(aVenir(ENV, ENV).length === 3, '« À venir » en voyage : 3 lignes');
    ok(N.carte.phrase === 'Lisbonne · J-212', 'Carte de Mon quotidien : « Lisbonne · J-212 »');
    err.forEach((m) => console.error('voyage.js : ' + m));
    return err; };
  return N;
})();
VOY.verifier();

/* ================= 3. Pièces d'écran communes (VOY.ui) ================= */
VOY.ui = {
  /* sélecteur de semaine d'un autre mois que novembre : sel = jour choisi, auj = aujourd'hui (repère rond), marques = jours du programme.
     Mêmes classes que U.wsel de Cristal (qui, lui, ne sait écrire que la semaine du 9 au 15 novembre). */
  wsel(sel, auj) { const lun = new Date(sel.getTime() - VOY.dow(sel) * 864e5), jours = [0, 1, 2, 3, 4, 5, 6].map((k) => new Date(lun.getTime() + k * 864e5));
    const fin = jours[6], titre = lun.getUTCDate() + ' – ' + fin.getUTCDate() + ' ' + VOY.dateC(fin).split(' ')[2];
    return `<div class="wsel gl"><div class="wh">${U.ico('chevl')}<span>${titre}</span>${U.ico('chev')}</div><div class="wd">${jours.map((d, k) => {
      const on = VOY.nj(sel, d) === 0, today = VOY.nj(auj, d) === 0, past = VOY.nj(auj, d) < 0, mk = VOY.programme(d).length > 0;
      return `<span class="d ${on ? 'on' : today ? 'today' : past ? 'past' : ''}${mk ? ' mk' : ''}">${WEEKDAYS[k]}<b>${d.getUTCDate()}</b><u></u></span>`; }).join('')}</div></div>`; },
  // ligne du programme ou de « À venir » : icône carrée, titre, détail, heure ou valeur à droite
  ligne: (l, o = {}) => PL.row(l.i, l.t, l.s, { c: l.c, sq: !o.compact, r: l.h || l.r, chev: o.chev !== false, ...o.x }),
};
