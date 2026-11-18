/* auto.js : le JS commun du sujet « Auto », refonte UX/UI des mini-apps, 2026-11-17.
   À charger après ../../2026-11-15-cristal/cristal.js et ../base/planches.js, avant le script de la planche.
   Il contient :
     FONCTIONS (alias FEATURES)  la liste F1…F20 de l'audit (../audit/08-auto.md, section 4), dans son ordre, avec ses numéros.
                                 [n°, libellé court, accès 'G' | 'P' | 'G+P', ce qu'elle fait en quelques mots]
     AUT                         les données d'exemple du sujet (jeudi 12 novembre 2026, 13 h 20) et leurs calculs.
     AUT.ui                      pièces d'écran communes (ligne de plein, entretien avec jauge, échéance).
   Règles :
     - Repères existants : jeudi 12 novembre 2026, 13 h 20 ; échéance « Assurance auto » le mardi 17 novembre, 62 $ (la même que dans « À ne pas oublier »).
       Le modèle de l'app (CarDeadline) n'a PAS de montant : le 62 $ est donc le frais fixe « Assurance » (par mois), pas un champ de l'échéance.
     - Véhicule et réservoir : ceux des données d'exemple de l'app (« Civic 2019 », 47 L, 3 entretiens, 3 échéances ; audit section 5). Le reste
       (pleins, relevés, dates, prix) est fixé UNE FOIS ici, puis tout est calculé avec les règles de CarMath (audit section 5) : consommation de plein
       complet à plein complet, autonomie, coût réel par mois, état des entretiens, km par mois. Rien n'est tapé à la main.
     - Compte montré : GRATUIT. Aucune limite ni verrou Premium dans la mini-app ; Premium = 4 widgets sur 5 seulement (F19).
     - Valeur inconnue : jamais zéro (« – »). Le journal d'un jour sans dépense n'écrit pas de total.
     - Ce qui n'existe pas dans l'app est rangé sous AUT.nouveau et nulle part ailleurs : à étiqueter « Nouveau » sur les planches. */

/* ================= 1. Les 20 fonctions existantes (audit, section 4) ================= */
const FONCTIONS = [
  ['F1', 'Compteur et kilométrage du mois', 'G', 'Plus grand kilométrage connu ; km depuis le premier relevé du mois ; « Ce mois-ci » ouvre la page « Kilométrage »'],
  ['F2', 'Autonomie estimée', 'G', 'Litres restants et km restants depuis le dernier plein complet ; sans réservoir, un bouton ouvre « Ma voiture »'],
  ['F3', 'Noter un plein', 'G', 'Litres, « Total payé », « Compteur », « Plein complet », « Date » ; créer, modifier, supprimer'],
  ['F4', 'Noter le kilométrage', 'G', 'Un champ « Compteur » ; ajoute un relevé daté de maintenant ; ni modification ni suppression'],
  ['F5', 'Journal du jour', 'G', 'Pleins, relevés, entretiens faits du jour choisi, avec le total dépensé ; « Rien noté ce jour-là. »'],
  ['F6', 'Sélecteur de semaine', 'G', '7 jours, passé et aujourd\'hui seulement, point sur les jours avec une trace'],
  ['F7', 'Consommation', 'G', 'L/100 moyen, coût aux 100 km, courbe par plein complet (dès 2 points)'],
  ['F8', 'Prix au litre', 'G', 'Courbe (dès 2 pleins), « dernier N $/L »'],
  ['F9', 'Historique des pleins', 'G', 'Date, litres, prix/L, km, « partiel », total ; toucher : modifier ou supprimer'],
  ['F10', 'Kilomètres par mois', 'G', 'Barres des 6 derniers mois ; « Moyenne » en km par mois'],
  ['F11', 'Relevés', 'G', '12 derniers points (relevés et pleins) ; lecture seule'],
  ['F12', 'Entretiens avec jauge', 'G', 'Nom, reste en km ou en jours, jauge, « dernier à N km le … » ; « Fait aujourd\'hui » ; supprimer'],
  ['F13', 'Échéances', 'G', 'Titre, icône, date, « J-N », « passée » ; créer, modifier, supprimer ; 6 icônes'],
  ['F14', 'Coût réel par mois', 'G', 'Total, barre de répartition (Frais fixes, Carburant, Entretien), coût par kilomètre'],
  ['F15', 'Frais fixes', 'G', '« Assurance », « Prêt ou location », « Stationnement », « Autres frais », « Entretien prévu » ; écrits en place'],
  ['F16', 'Nom de la voiture et réservoir', 'G', 'Nom (titre de l\'écran), réservoir en litres'],
  ['F17', 'Carte « Auto » de Mon quotidien', 'G', 'Une ligne : « ≈ N km d\'autonomie » ou « N km » ; toucher ouvre la mini-app'],
  ['F18', 'Rappel d\'échéance dans « À ne pas oublier »', 'G', 'Échéances de la voiture à 7 jours ou moins ; toucher ouvre la page « Échéances »'],
  ['F19', 'Widgets Auto (5)', 'G+P', '« Prochain entretien » gratuit ; « Coût de la voiture », « Kilométrage », « Carburant » et « Échéances auto » Premium'],
  ['F20', 'Doublon dans l\'espace Auto (Créer)', 'G', 'Mêmes actions, en liste système'],
];
const FEATURES = FONCTIONS;

/* icône « flocon » (l'une des 6 icônes d'échéance de l'app) : absente de Cristal */
Object.assign(P, { snow: 'M12 3v18M4.2 7.5l15.6 9M19.8 7.5l-15.6 9M9.5 4.5L12 6.5l2.5-2M9.5 19.5l2.5-2 2.5 2' });

/* ================= 2. Les données d'exemple ================= */
const AUT = (function () {
  const MOIS = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juill.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  const MOIS_L = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
  const JC = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
  const JL = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
  const dt = (y, m, j, h = 0, mi = 0) => new Date(Date.UTC(y, m - 1, j, h, mi));          // m = 1 à 12 ; dates écrites telles qu'elles s'affichent
  const dow = (d) => (d.getUTCDay() + 6) % 7;                                              // 0 = lundi
  const jour0 = (d) => Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
  const nj = (a, b) => Math.round((jour0(b) - jour0(a)) / 864e5);                          // jours entiers de a à b
  const meme = (a, b) => nj(a, b) === 0;
  const addMois = (d, n) => dt(d.getUTCFullYear(), d.getUTCMonth() + 1 + n, d.getUTCDate());
  const dateC = (d) => JC[dow(d)] + ' ' + d.getUTCDate() + ' ' + MOIS[d.getUTCMonth()];     // « jeu. 12 nov. »
  const dateM = (d) => d.getUTCDate() + ' ' + MOIS[d.getUTCMonth()];                        // « 12 nov. »
  const dateL = (d) => JL[dow(d)][0].toUpperCase() + JL[dow(d)].slice(1) + ' ' + d.getUTCDate() + ' ' + MOIS_L[d.getUTCMonth()];   // « Jeudi 12 novembre »
  const sum = (L, f) => L.reduce((s, x) => s + f(x), 0);
  const r2 = (x) => Math.round(x * 100) / 100;
  const r1 = (x) => Math.round(x * 10) / 10;
  const AUJ = dt(2026, 11, 12, 13, 20);                                                    // jeudi 12 novembre 2026, 13 h 20

  /* ---------- la voiture : « Civic 2019 », réservoir 47 L (données d'exemple de l'app) ---------- */
  const V = { nom: 'Civic 2019', marque: 'Honda Civic', reservoir: 47 };

  /* ---------- pleins (litres et prix à la pompe saisis ; le total payé et le prix par litre en sortent) ---------- */
  const pleins = [
    { d: dt(2026, 8, 8, 9, 10), odo: 58960, l: 34.6, p: 1.689, plein: true },
    { d: dt(2026, 8, 21, 18, 5), odo: 59318, l: 26.2, p: 1.679, plein: true },
    { d: dt(2026, 9, 3, 8, 30), odo: 59689, l: 27.9, p: 1.659, plein: true },
    { d: dt(2026, 9, 16, 17, 45), odo: 60041, l: 25.0, p: 1.649, plein: true },
    { d: dt(2026, 9, 24, 12, 10), odo: 60262, l: 15.0, p: 1.669, plein: false },          // plein partiel
    { d: dt(2026, 10, 2, 8, 5), odo: 60405, l: 10.9, p: 1.689, plein: true },
    { d: dt(2026, 10, 15, 18, 20), odo: 60773, l: 27.6, p: 1.719, plein: true },
    { d: dt(2026, 10, 28, 17, 50), odo: 61131, l: 26.1, p: 1.739, plein: true },
    { d: dt(2026, 11, 5, 8, 15), odo: 61371, l: 17.6, p: 1.729, plein: true },
  ].map((f) => { const total = r2(f.l * f.p); return { ...f, total, prix: total / f.l }; });
  /* ---------- relevés du compteur (fin de mois, puis ce midi) ---------- */
  const releves = [
    { d: dt(2026, 5, 31, 20, 0), km: 57020 }, { d: dt(2026, 6, 30, 20, 0), km: 57860 }, { d: dt(2026, 7, 31, 20, 0), km: 58730 },
    { d: dt(2026, 8, 31, 20, 0), km: 59600 }, { d: dt(2026, 9, 30, 20, 0), km: 60340 }, { d: dt(2026, 10, 31, 20, 0), km: 61215 },
    { d: dt(2026, 11, 12, 12, 45), km: 61640 },
  ];
  /* ---------- entretiens : un seul « dernier » par entretien dans l'app ; coût = « Coût habituel » ---------- */
  const entretiens = [
    { nom: 'Vidange d\'huile', intKm: 8000, intMois: 6, lastKm: 57000, lastDate: dt(2026, 5, 30), cout: 89 },
    { nom: 'Rotation des pneus', intKm: 10000, intMois: 12, lastKm: 55800, lastDate: dt(2026, 4, 18), cout: 45 },
    { nom: 'Plaquettes de frein', intKm: 40000, intMois: 36, lastKm: 44800, lastDate: dt(2025, 3, 15), cout: 320 },
  ];
  /* ---------- échéances (6 icônes dans l'app : calendrier, bouclier, document, flocon, outils, carte) ---------- */
  const echeances = [
    { titre: 'Vignette de stationnement', d: dt(2026, 10, 31), i: 'calendar' },
    { titre: 'Assurance auto', d: dt(2026, 11, 17), i: 'shield' },                         // mardi 17 novembre : celle de « À ne pas oublier »
    { titre: 'Pneus d\'hiver', d: dt(2026, 12, 1), i: 'snow' },
    { titre: 'Immatriculation', d: dt(2027, 2, 28), i: 'doc' },
  ];
  const ICONES = [['calendar', 'Calendrier'], ['shield', 'Bouclier'], ['doc', 'Document'], ['snow', 'Flocon'], ['wrench', 'Outils'], ['card', 'Carte']];
  /* ---------- frais fixes : l'assurance = 62 $ par mois (le montant d'« À ne pas oublier ») ---------- */
  const fixes = { assurance: 62, pret: 190, stationnement: 45, autres: 20, entretienAn: 600 };

  /* ================= calculs (les règles de CarMath, audit section 5) ================= */
  const points = [...releves.map((r) => ({ d: r.d, km: r.km, t: 'releve' })), ...pleins.map((f) => ({ d: f.d, km: f.odo, t: 'plein' }))].filter((x) => x.d <= AUJ).sort((a, b) => a.d - b.d);
  const compteur = Math.max(...points.map((x) => x.km));                                                    // le MAXIMUM (CarMath.odometer)
  const debutMois = dt(AUJ.getUTCFullYear(), AUJ.getUTCMonth() + 1, 1);
  const avantMois = (m0) => points.filter((x) => x.d < m0).pop();
  const kmMois = (() => { const av = avantMois(debutMois), ap = points.filter((x) => x.d >= debutMois);
    const base = av || ap[0]; return base && ap.length ? Math.max(...ap.map((x) => x.km)) - base.km : null; })();
  const parOdo = pleins.slice().sort((a, b) => a.odo - b.odo);
  const iPremier = parOdo.findIndex((f) => f.plein);
  const iDernier = parOdo.map((f) => f.plein).lastIndexOf(true);
  const consommation = (iPremier >= 0 && iDernier > iPremier)
    ? sum(parOdo.slice(iPremier + 1, iDernier + 1), (f) => f.l) / (parOdo[iDernier].odo - parOdo[iPremier].odo) * 100 : null;
  const parPlein = (() => { const L = []; let last = parOdo[iPremier], acc = 0;                           // consommation de plein complet à plein complet
    parOdo.slice(iPremier + 1).forEach((f) => { acc += f.l; if (f.plein) { L.push({ d: f.d, v: acc / (f.odo - last.odo) * 100 }); last = f; acc = 0; } }); return L; })();
  const dernierPrix = parOdo.length ? parOdo[parOdo.length - 1].prix : null;
  const coutAux100 = consommation != null && dernierPrix != null ? consommation * dernierPrix : null;      // $ aux 100 km
  const carburantMois = (() => { if (!pleins.length) return 0; const premier = pleins.slice().sort((a, b) => a.d - b.d)[0].d, debut = addMois(AUJ, -3);
    const mois = Math.min(3, Math.max(1, (AUJ - premier) / (864e5 * 30.4)));                                // « les 3 derniers mois » ; à vérifier si le plus ancien plein a moins de 3 mois
    return sum(pleins.filter((f) => f.d >= debut), (f) => f.total) / mois; })();
  const fraisFixes = fixes.assurance + fixes.pret + fixes.stationnement + fixes.autres;
  const entretienMois = fixes.entretienAn / 12;
  const coutMois = fraisFixes + carburantMois + entretienMois;
  const kmParMois = (n = 6) => { const L = []; for (let k = n - 1; k >= 0; k--) { const m0 = dt(AUJ.getUTCFullYear(), AUJ.getUTCMonth() + 1 - k, 1), m1 = dt(AUJ.getUTCFullYear(), AUJ.getUTCMonth() + 2 - k, 1);
      const dans = points.filter((x) => x.d >= m0 && x.d < m1), av = avantMois(m0) || dans[0];
      L.push({ m: m0, km: dans.length && av ? Math.max(...dans.map((x) => x.km)) - av.km : null, cur: k === 0 }); } return L; };
  const kmMoisPasses = kmParMois().filter((x) => !x.cur && x.km != null);
  const moyenneKm = kmMoisPasses.length ? sum(kmMoisPasses, (x) => x.km) / kmMoisPasses.length : null;       // moyenne des mois roulés hors mois courant
  const coutParKm = moyenneKm ? coutMois / moyenneKm : null;
  const autonomie = (() => { if (!V.reservoir || consommation == null) return null; const dernierComplet = parOdo[iDernier];
    const partiels = sum(parOdo.filter((f) => !f.plein && f.odo > dernierComplet.odo), (f) => f.l);
    const litres = Math.max(0, V.reservoir - (compteur - dernierComplet.odo) * consommation / 100 + partiels);
    return { litres, km: litres / consommation * 100, depuis: dernierComplet.d }; })();
  /* état d'un entretien : reste en km, en jours, part utilisée (le plus grand des deux) ; trié du plus avancé au moins avancé */
  const statut = (s) => { const kmLeft = s.intKm ? s.intKm - (compteur - s.lastKm) : null, fin = s.intMois ? addMois(s.lastDate, s.intMois) : null, daysLeft = fin ? nj(AUJ, fin) : null;
    const uKm = s.intKm ? (compteur - s.lastKm) / s.intKm : 0, uJ = fin ? 1 - daysLeft / nj(s.lastDate, fin) : 0, used = Math.max(uKm, uJ);
    const cls = used >= 1 ? 'over' : used >= .85 ? 'warn' : 'ok';
    return { ...s, kmLeft, daysLeft, used, cls, texte: used >= 1 ? 'en retard' : `dans ${PL.n(kmLeft)} km ou d'ici ${daysLeft} j`, dernier: `dernier à ${PL.n(s.lastKm)} km le ${dateM(s.lastDate)}` }; };
  const statuts = entretiens.map(statut).sort((a, b) => b.used - a.used);
  const aVenir = echeances.filter((e) => nj(AUJ, e.d) >= 0);
  const echeance = (e) => { const n = nj(AUJ, e.d); return { ...e, n, hot: n >= 0 && n <= 14, r: n < 0 ? 'passée' : n === 0 ? 'aujourd\'hui' : 'J-' + n, dow: JC[dow(e.d)], j: e.d.getUTCDate(), l: dateL(e.d) }; };
  /* journal d'un jour : pleins, relevés, entretiens faits ; total dépensé (null s'il n'y a rien à additionner) */
  const journal = (d) => { const L = [];
    pleins.filter((f) => meme(f.d, d)).forEach((f) => L.push({ i: 'fuel', t: 'Plein', s: `${PL.n(f.l, 1)} L · ${PL.n(f.prix, 3)} $/L · ${PL.n(f.odo)} km`, r: f.total }));
    releves.filter((r) => meme(r.d, d)).forEach((r) => L.push({ i: 'gauge', t: 'Relevé', s: '', r: null, km: r.km }));
    entretiens.filter((s) => meme(s.lastDate, d)).forEach((s) => L.push({ i: 'wrench', t: s.nom, s: 'Entretien', r: s.cout }));
    const dep = sum(L, (x) => x.r || 0); return { lignes: L, total: dep > 0 ? dep : null }; };

  /* ---------- la carte « Auto » de Mon quotidien : mêmes mots que l'app (audit F17) ---------- */
  const km10 = autonomie ? Math.round(autonomie.km / 10) * 10 : null;                       // arrondi à 10 km : à confirmer (le test de l'app lit « 420 km d'autonomie »)
  const carte = { titre: 'Auto', icone: 'car', phrase: autonomie ? `≈ ${PL.n(km10)} km d'autonomie` : `${PL.n(compteur)} km` };

  const N = {
    jour: { date: 'Jeudi 12 novembre 2026', heure: '13:20' }, AUJ, V, pleins, releves, entretiens, echeances, ICONES, fixes, points,
    dt, dow, nj, dateC, dateM, dateL, r1, r2, sum,
    compteur, kmMois, consommation, parPlein, dernierPrix, coutAux100, carburantMois, fraisFixes, entretienMois, coutMois, kmParMois, moyenneKm, coutParKm,
    autonomie, km10, statuts, aVenir, echeance, journal, carte,
    pleinsRecents: pleins.slice().sort((a, b) => b.d - a.d),
    pointsRecents: (n = 12) => points.slice().reverse().slice(0, n),
    txt: {
      depart: 'Note tes pleins et ton kilométrage : consommation, autonomie, coût réel par mois, entretiens et échéances se suivent tout seuls.',    // texte de la carte de départ (audit section 3)
      sansPlein: 'À chaque plein, note les litres, le prix et le compteur : la consommation se calcule entre deux pleins complets.',                     // texte de la page « Carburant » vide (audit section 7)
      releves: 'Les relevés viennent de tes pleins et des kilométrages notés.',                                                                          // note de la page « Kilométrage » (audit F11)
      entretien: 'Glisse vers la droite quand un entretien est fait : il repart du compteur d\'aujourd\'hui.',                                           // note de la page « Entretien » (audit section 7)
    },
    /* ----- CE QUI N'EXISTE PAS dans l'app : à étiqueter « Nouveau » (jeton, légende, case de texte). Jamais ailleurs. ----- */
    nouveau: {
      /* audit section 8 (problème 5) et section 9 : « historique des entretiens » ; l'app ne garde que la DERNIÈRE fois. Date, compteur, coût réel de chaque fois. */
      historique: {
        'Vidange d\'huile': [{ d: dt(2026, 5, 30), km: 57000, cout: 89.95 }, { d: dt(2025, 11, 28), km: 51900, cout: 84.5 }, { d: dt(2025, 5, 24), km: 46600, cout: 79.95 }],
        'Rotation des pneus': [{ d: dt(2026, 4, 18), km: 55800, cout: 45 }, { d: dt(2025, 4, 10), km: 45400, cout: 40 }],
        'Plaquettes de frein': [{ d: dt(2025, 3, 15), km: 44800, cout: 320 }],
      },
      /* audit section 8 (problème 4) et section 9 : « relevés modifiables » ; un relevé n'a pas d'identifiant aujourd'hui */
      releve: { titre: 'Relevé', modifier: 'Modifier le relevé', supprimer: 'Supprimer le relevé' },
      /* audit section 8 (problème 9) et section 9 : « échéances répétées » ; pas de « fait » ni de répétition aujourd'hui */
      repete: { titre: 'Répéter chaque année', fait: 'Marquer comme fait' },
    },
  };

  /* ----- contrôle : les calculs sont justes, aucune valeur inconnue devenue zéro ----- */
  N.verifier = function () { const err = [], ok = (c, m) => { if (!c) err.push(m); };
    ok(FONCTIONS.length === 20 && FONCTIONS.every((f, i) => f[0] === 'F' + (i + 1)), 'FONCTIONS : 20 fonctions attendues, F1 à F20 dans l\'ordre');
    ok(FONCTIONS.filter((f) => f[2] !== 'G').map((f) => f[0]).join() === 'F19', 'FONCTIONS : seul F19 touche Premium');
    ok(dow(AUJ) === 3 && dow(dt(2026, 11, 17)) === 1, 'Le 12 novembre 2026 est un jeudi ; le 17 est un mardi');
    ok(points.every((x, i) => i === 0 || x.km >= points[i - 1].km), 'Les points du compteur croissent avec les dates');
    ok(compteur === 61640 && kmMois === 425, 'Compteur 61 640 km ; 425 km ce mois-ci');
    ok(parPlein.length === 7 && parPlein.every((x) => x.v > 6.5 && x.v < 8), 'Consommation par plein complet : 7 points entre 6,5 et 8 L/100');
    ok(r1(consommation) === 7.3, 'Consommation moyenne : 7,3 L/100');
    ok(Math.abs(sum(pleins.filter((f, i) => i > 0), (f) => f.l) - 176.3) < .01, 'Litres après le premier plein complet : 176,3 L');
    ok(autonomie && r1(autonomie.litres) === 27.3 && km10 === 370, 'Autonomie : environ 27 L, ≈ 370 km');
    ok(autonomie && autonomie.depuis.getTime() === pleins[8].d.getTime(), 'Autonomie calculée depuis le plein du 5 nov.');
    ok(fraisFixes === 317 && entretienMois === 50 && Math.round(carburantMois) === 99 && Math.round(coutMois) === 466, 'Coût réel : 317 + 99 + 50 = 466 $ par mois');
    ok(Math.round(moyenneKm) === 839 && r2(coutParKm) === 0.56, 'Moyenne 839 km par mois ; 0,56 $ par kilomètre');
    ok(statuts.map((s) => s.nom).join() === 'Vidange d\'huile,Rotation des pneus,Plaquettes de frein' && statuts[0].cls === 'warn' && statuts[1].cls === 'ok', 'Entretiens : la vidange (orange) passe avant la rotation et les plaquettes');
    ok(statuts[0].daysLeft === 18 && statuts[0].kmLeft === 3360, 'Vidange : dans 3 360 km ou d\'ici 18 j');
    ok(echeance(echeances[1]).r === 'J-5' && echeance(echeances[1]).hot && !echeance(echeances[2]).hot && echeance(echeances[0]).r === 'passée', 'Échéances : Assurance auto J-5 (rouge), Pneus d\'hiver J-19, la vignette est passée');
    ok(fixes.assurance === 62, 'Assurance = 62 $ par mois, comme l\'échéance de « À ne pas oublier »');
    ok(journal(AUJ).lignes.length === 1 && journal(AUJ).total === null && journal(pleins[8].d).total === pleins[8].total, 'Journal : ce midi, un relevé sans total ; le 5 nov., un plein et son total');
    ok(pointsRecentsLen() === 12, 'Relevés : 12 derniers points');
    ok(carte.phrase === '≈ 370 km d\'autonomie', 'Carte de Mon quotidien : « ≈ 370 km d\'autonomie »');
    ok(Object.values(N.nouveau.historique).every((h, i) => h[0].km === entretiens[i].lastKm && +h[0].d === +entretiens[i].lastDate), 'Historique : la première ligne de chaque entretien est sa dernière fois');
    err.forEach((m) => console.error('auto.js : ' + m));
    return err; };
  const pointsRecentsLen = () => N.pointsRecents(12).length;
  return N;
})();
AUT.verifier();

/* ================= 3. Pièces d'écran communes (AUT.ui) ================= */
AUT.ui = {
  // ligne de plein (page « Carburant ») : date, litres · prix/L · km, « partiel », total
  plein: (f, o = {}) => PL.row('', AUT.dateC(f.d), `${PL.n(f.l, 1)} L · ${PL.n(f.prix, 3)} $/L · ${PL.n(f.odo)} km`, { r: PL.m(f.total), r2: f.plein ? '' : 'partiel', chev: o.chev !== false }),
  // entretien avec jauge : nom, part utilisée, « dans N km ou d'ici N j », jauge (bleu, orange dès 85 %, rouge dès 100 %)
  entretien: (s, o = {}) => PL.prog({ i: o.i === false ? '' : 'wrench', t: s.nom, r: `<b>${PL.pct(Math.min(1, s.used))}</b>`, p: Math.min(1, s.used), over: s.cls === 'over',
    c: s.cls === 'warn' ? 'var(--pl-warn)' : 'var(--c-pla)', sub: s.texte + (o.dernier ? '<br>' + s.dernier : '') }),
  // échéance : bloc date, titre, date longue, « J-N » (rouge à 14 jours ou moins)
  echeance: (e, o = {}) => PL.due({ dow: e.dow, d: e.j, t: e.titre, s: e.l, r: e.r, hot: e.hot, rc: e.n < 0 ? 'over' : '', chev: o.chev, nw: o.nw }),
  // ligne du journal
  journal: (x) => PL.row(x.i, x.t, x.s, { c: 'var(--c)', r: x.km != null ? PL.n(x.km) + NBSP + 'km' : PL.m(x.r), chev: x.t !== 'Relevé' }),
};
