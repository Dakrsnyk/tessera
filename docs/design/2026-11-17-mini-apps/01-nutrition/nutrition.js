/* nutrition.js : le JS commun du sujet « Nutrition » (refonte UX/UI des mini-apps, 2026-11-17).
   À charger après ../../2026-11-15-cristal/cristal.js et ../base/planches.js, avant le script de la planche.
   Il contient :
     FONCTIONS (alias FEATURES)  la liste F1…F64 de l'audit (../audit/01-nutrition.md, section 4), dans son ordre, avec ses numéros.
                                 [n°, libellé court, accès 'G' | 'P' | 'G+P', ce qu'elle fait en quelques mots]
     NUT                         les données d'exemple du sujet pour le jeudi 12 novembre 2026, 13 h 20, et quelques outils de texte.
   Règles :
     - Les sept planches du sujet lisent ces données. Aucune planche ne recopie la liste ni ne change un chiffre.
     - Tout chiffre est possible avec les règles de calcul du code (audit, section 5). Les moyennes et les comptes sont CALCULÉS ici,
       pas tapés à la main (voir la fin du fichier : NUT.verifier()).
     - Ce qui n'existe pas dans l'app est rangé sous NUT.nouveau et nulle part ailleurs : à étiqueter « Nouveau » sur les planches.
   Trois écarts connus avec cristal.js, voulus (le code de l'app fait foi, voir CONCEPT.md, « Données d'exemple ») :
     1. Moyenne des 7 derniers jours : 2 041 kcal (7 jours notés, aujourd'hui compris : NutritionMath.stats et la carte de Mon quotidien
        comptent le jour en cours). CAL7.avg = 2 202 est la moyenne des 6 jours complets : gardée dans NUT.h7.complets, à ne pas afficher seule.
     2. « Prochain repas » à 13 h 20 : souper, environ 1 122 kcal (tout le reste : un seul repas principal reste à noter). DAY.journee.next
        dit « environ 700 kcal » : impossible avec NutritionMath.nextMealBudget.
     3. Cibles de la page « Nutriments » : fibres 31 g, sucres 55 g, gras saturés 24 g, fer 8 mg (règles du code pour 2 200 kcal, homme de 24 ans).
        La planche Cristal 03 montrait 30 g, 50 g, 20 g et 14 mg. */

/* ================= 1. Les 64 fonctions existantes (audit, section 4) ================= */
const FONCTIONS = [
  ['F1', 'Choisir le jour affiché', 'G', 'Sélecteur de semaine ; « Aujourd\'hui » ; pas de jour futur'],
  ['F2', 'Retour automatique à aujourd\'hui', 'G', 'Sans écran : la page suit le jour quand l\'app se rouvre'],
  ['F3', 'Calories du jour (anneau)', 'G', 'Reste, trop, ou mangé s\'il n\'y a pas d\'objectif'],
  ['F4', 'Protéines, glucides, lipides du jour', 'G', '« mangé / objectif g » et jauge'],
  ['F5', '« À remplir »', 'G', 'Cartes « Objectif calorique » et « Objectifs de macros »'],
  ['F6', 'Bouton « Scanner »', 'G', 'Ouvre le scanner pour le jour choisi ; absent sans caméra'],
  ['F7', 'Bouton « Rechercher » ou « Ajouter un aliment »', 'G', 'Ouvre la recherche pour le jour choisi'],
  ['F8', 'Recherche d\'aliments hors ligne', 'G', '« Suggestions » ou « Résultats », environ 8 900 aliments'],
  ['F9', 'Filtres par famille', 'G', '« Pour toi », « Fruits », « Légumes »… 11 pastilles'],
  ['F10', 'Recherche de produits emballés (Open Food Facts)', 'G', 'Sur demande seulement, jamais pendant la frappe'],
  ['F11', 'Feuille de quantité', 'G+P', 'Grammes, portions rapides, repas, apport ; autres nutriments en Premium'],
  ['F12', 'Ajout direct à un repas', 'G', '« + » d\'une ligne : le repas est déjà choisi'],
  ['F13', 'Créer un aliment perso', 'G+P', 'Nom, portion, valeurs pour 100 g ; 9 valeurs de plus en Premium'],
  ['F14', 'Reprendre un repas enregistré depuis la recherche', 'G', 'Section « Mes repas » de la recherche'],
  ['F15', 'Scanner un code-barres', 'G', 'Lecture automatique, sans limite'],
  ['F16', 'Scanner un plat par photo', 'G+P', '10 analyses gratuites au total, puis Premium ; analyse sur l\'iPhone'],
  ['F17', 'Analyser une photo déjà prise', 'G+P', 'Sélecteur de photos du système ; même quota'],
  ['F18', 'Flash du scanner', 'G', '« Flash automatique », « Flash activé », « Flash désactivé »'],
  ['F19', 'Explication avant la caméra', 'G', '« Utiliser la caméra » ou « Caméra désactivée »'],
  ['F20', 'Sorties d\'un code-barres', 'G', '« Produit introuvable », pas de connexion, « Service occupé »'],
  ['F21', 'Récapitulatif modifiable du scan', 'G', 'Aliments, étiquettes, quantités, total, « Ajouter au journal »'],
  ['F22', '« À confirmer »', 'G', 'Aliments peu sûrs ; « Huile de cuisson ? » ; rien sans accord'],
  ['F23', 'Apprentissage local du scanner', 'G', '« Ton habitude », « Comme ton repas du… »'],
  ['F24', 'Compteur d\'analyses gratuites', 'G', '« Encore 3 analyses de plat gratuites »'],
  ['F25', '« Scanner à nouveau » depuis le récapitulatif', 'G', 'Revenir à la caméra'],
  ['F26', 'Pas de doublon', 'G', '« Déjà ajouté à l\'instant »'],
  ['F27', 'Liste des quatre repas du jour', 'G', 'Déjeuner, Dîner, Souper, Collation ; aliments et kcal'],
  ['F28', 'Page d\'un repas', 'G', 'Totaux du repas et ses aliments'],
  ['F29', 'Modifier un aliment noté', 'G+P', 'Quantité, repas, « Retirer de ce repas »'],
  ['F30', 'Glisser pour supprimer un aliment noté', 'G', '« Supprimer »'],
  ['F31', 'Mettre un aliment en favori', 'G', 'Glisser, « Favori »'],
  ['F32', 'Reprendre un repas précédent', 'G', 'Les 3 derniers repas du même type'],
  ['F33', 'Reprendre un repas enregistré depuis la page repas', 'G', 'Section « Mes repas » de la page d\'un repas'],
  ['F34', '« Enregistrer ce repas »', 'G', 'Donner un nom au repas du jour'],
  ['F35', 'Page « Mes repas »', 'G', '« Ajouter à ma journée », « Supprimer ce repas »'],
  ['F36', '« Mes aliments »', 'G', 'Corriger ou supprimer un aliment perso'],
  ['F37', 'Ligne « Tous les nutriments »', 'G+P', 'Résumé fibres, sucres, sodium en Premium'],
  ['F38', 'Page « Nutriments »', 'G+P', '38 nutriments : 4 gratuits, 34 Premium'],
  ['F39', 'Carte conseil du jour', 'G', 'Un message sur quatre, selon l\'état du jour'],
  ['F40', 'Page « Idées »', 'G+P', 'Ce qui tient dans le reste ; « Riches en fibres » en Premium'],
  ['F41', '« Calories de la semaine »', 'G', '7 barres, objectif, moyenne, jours dans l\'objectif'],
  ['F42', 'Historique : choix de la période', 'G+P', '« Aujourd\'hui » et « Hier » gratuits ; le reste en Premium'],
  ['F43', 'Historique : « Bilan » ou « Moyennes »', 'G+P', 'Bilan d\'un jour gratuit, moyennes Premium'],
  ['F44', 'Historique : « Calories par jour »', 'P', 'Barres par jour et ligne « Objectif »'],
  ['F45', 'Historique : « Répartition des calories »', 'G+P', 'Barre en 3 parts ; sur une période en Premium'],
  ['F46', 'Historique : courbe « Poids »', 'P', 'Courbe, variation, moyenne sur 7 jours, ligne « Cible »'],
  ['F47', 'Historique : « Jour par jour »', 'P', 'Jusqu\'à 31 jours ; toucher un jour l\'ouvre'],
  ['F48', 'Bouton « Mes paramètres »', 'G', 'Tout en bas de la page'],
  ['F49', '« Rappel des repas »', 'G', 'Interrupteur « Repas » et heure, dans « Rappels »'],
  ['F50', '« Ton objectif » (partagé avec Fitness)', 'G', '9 choix ; « Le même pour Sport et Nutrition. »'],
  ['F51', '« Ton poids cible » et durée', 'G', '« Semaines », « Mois » ou « Date »'],
  ['F52', '« Es-tu enceinte ou allaitante ? »', 'G', 'Quatre réponses'],
  ['F53', '« Toi » : âge, taille, poids, genre', 'G', 'Le poids saisi ici nourrit la courbe de poids'],
  ['F54', '« Ton niveau d\'activité »', 'G', 'Quatre niveaux, ou suivre les séances de Fitness'],
  ['F55', 'Récapitulatif « Ton objectif de poids »', 'G', 'Plan, « Appliquer ce plan », cas refusés'],
  ['F56', '« Ajustement proposé »', 'G', '« Accepter » ou « Plus tard »'],
  ['F57', '« Nouveau calcul proposé »', 'G', '« Utiliser ce calcul » ou « Garder mes valeurs »'],
  ['F58', '« Tes besoins par jour »', 'G+P', '34 cibles : 4 gratuites, 30 Premium ; « Calculé » ou « Personnalisé »'],
  ['F59', 'Carte Nutrition de Mon quotidien', 'G', 'Trois vues : « Aujourd\'hui », « Repas », « 7 jours »'],
  ['F60', 'Widgets Nutrition', 'G+P', '2 gratuits sur 8 ; « Scanner un aliment » sur l\'écran verrouillé'],
  ['F61', 'Ajout rapide depuis un widget', 'P', 'Une touche ajoute une portion d\'un favori'],
  ['F62', 'Rappels et notifications', 'G', '« Rien de noté aujourd\'hui », « Bilan nutrition de la semaine »…'],
  ['F63', 'Espace Nutrition (côté Créer)', 'G', '« Favoris », « Moyenne sur 7 jours », « Série de suivi »'],
  ['F64', 'Mentions des sources', 'G', 'Open Food Facts (ODbL), Fichier canadien, USDA, « pas un avis médical »'],
];
const FEATURES = FONCTIONS;   // même liste, sous le nom employé pour Finance

/* ================= 2. Les données d'exemple : jeudi 12 novembre 2026, 13 h 20 ================= */
const NUT = (function () {
  const sum = (a, f) => a.reduce((s, x) => s + (f ? f(x) : x), 0);
  const noted = (a) => a.filter((v) => v != null && v > 0);
  const avg = (a) => Math.round(sum(noted(a)) / Math.max(noted(a).length, 1));
  const GOAL = 2200;
  const nb = (x) => String(x).replace(/\B(?=(\d{3})+(?!\d))/g, '\u00a0');                 // 1877 devient 1 877, avec une espace qui ne coupe pas
  const inGoal = (v) => v != null && v > 0 && Math.abs(v - GOAL) <= GOAL * 0.1;         // « dans l'objectif » : à ± 10 % (Nutrition.swift:995)

  /* ---------- aliments : q grammes, kcal, p protéines, g glucides, l lipides (pour la quantité notée) ----------
     c100 = ligne de la recherche, pour 100 g : [kcal, P, G, L]. src = étiquette du récapitulatif d'un scan. */
  const A = {
    pain:     { n: 'Pain de blé entier', q: 70, kcal: 175, p: 8, g: 30, l: 2, c100: [250, 11, 43, 3] },
    arachide: { n: 'Beurre d\'arachide', q: 15, kcal: 90, p: 4, g: 3, l: 8, c100: [598, 25, 20, 51] },
    yogVan:   { n: 'Yogourt grec à la vanille', q: 175, kcal: 155, p: 12, g: 19, l: 2, c100: [89, 7, 11, 1], src: 'Open Food Facts' },
    poulet:   { n: 'Poulet grillé', q: 120, kcal: 198, p: 36, g: 0, l: 5, c100: [165, 30, 0, 4] },
    riz:      { n: 'Riz basmati cuit', q: 200, kcal: 260, p: 5, g: 56, l: 1, c100: [130, 3, 28, 0] },
    brocoli:  { n: 'Brocoli à l\'huile d\'olive', q: 180, kcal: 200, p: 3, g: 13, l: 16, c100: [111, 2, 7, 9] },
    yogNat:   { n: 'Yogourt grec nature', q: 175, kcal: 128, p: 17.5, g: 7, l: 3.5, c100: [73, 10, 4, 2], fav: true },
    banane:   { n: 'Banane', q: 120, kcal: 107, p: 1, g: 27, l: 0, c100: [89, 1, 23, 0], fav: true },
    amandes:  { n: 'Amandes', q: 30, kcal: 174, p: 6, g: 7, l: 15, c100: [579, 21, 22, 50], fav: true },
    smoothie: { n: 'Smoothie protéiné maison', q: 350, kcal: 266, p: 24, g: 24, l: 5, c100: [76, 7, 7, 2], perso: true, src: 'Aliment perso' },
    barre:    { n: 'Barre maison avoine et dattes', q: 45, kcal: 176, p: 4, g: 23, l: 7, c100: [391, 9, 52, 15], perso: true, src: 'Aliment perso' },
  };
  const tot = (items) => ({ kcal: sum(items, (x) => x.kcal), p: Math.round(sum(items, (x) => x.p)), g: Math.round(sum(items, (x) => x.g)), l: Math.round(sum(items, (x) => x.l)) });

  /* ---------- le jour (13 h 20) ---------- */
  const repas = [
    { k: 'dej', n: 'Déjeuner', i: 'sunrise', h: '07:45', items: [A.pain, A.arachide, A.yogVan] },
    { k: 'din', n: 'Dîner', i: 'sun', h: '12:35', items: [A.poulet, A.riz, A.brocoli] },
    { k: 'sou', n: 'Souper', i: 'moon', h: null, items: [] },
    { k: 'col', n: 'Collation', i: 'carrot', h: null, items: [] },
  ].map((m) => ({ ...m, ...tot(m.items), nb: m.items.length, vide: !m.items.length, detail: m.items.length ? m.items.length + ' aliments' : 'Rien noté' }));
  const T = tot(repas.filter((m) => !m.vide));                       // 1 078 kcal · P 68 · G 121 · L 34
  const macro = (k, n, c, v, cible) => ({ k, n, c, v, cible, reste: cible - v, p: v / cible, txt: `${v} / ${cible} g` });
  const kcalM = { p: T.p * 4, g: T.g * 4, l: T.l * 9 }, kcalMt = kcalM.p + kcalM.g + kcalM.l;

  /* ---------- la semaine civile (lundi 9 → dimanche 15) et la précédente ---------- */
  const sem = [2140, 2310, 1980, T.kcal, null, null, null];
  const semPrec = [2180, 2235, 1940, 2205, 2250, 2480, 2050];        // lundi 2 → dimanche 8
  // repas des trois jours passés de la semaine (kcal par repas ; la somme = le total du jour)
  const jours = [
    { d: 'Lun. 9 nov.', kcal: 2140, repas: [420, 640, 690, 390], din: 'Sandwich au poulet, Crudités, Pomme', sou: 'Poulet grillé, Patate douce, Brocoli', col: 'Yogourt grec nature, Amandes, Clémentines' },
    { d: 'Mar. 10 nov.', kcal: 2310, repas: [420, 689, 759, 442], din: 'Pâtes, Sauce tomate, Fromage', sou: 'Chili con carne, Riz basmati cuit, Salade verte', col: 'Smoothie protéiné maison, Barre maison avoine et dattes' },
    { d: 'Mer. 11 nov.', kcal: 1980, repas: [420, 702, 623, 235], din: 'Saumon, Quinoa, Haricots verts', sou: 'Omelette aux légumes, Pain de blé entier, Salade verte', col: 'Yogourt grec nature, Banane' },
  ];

  /* ---------- les 7 derniers jours (vendredi 6 → jeudi 12) : kcal de cristal.js (CAL7.past) puis aujourd'hui ; macros par jour ---------- */
  const k7 = [2250, 2480, 2050, 2140, 2310, 1980, T.kcal];
  const p7 = [135, 128, 124, 136, 139, 130, T.p], g7 = [268, 305, 244, 252, 276, 227, T.g], l7 = [70, 82, 64, 66, 72, 60, T.l];
  const part = (p, g, l) => { const a = p * 4, b = g * 4, c = l * 9, t = a + b + c; const P = Math.round(a / t * 100), L = Math.round(c / t * 100); return { p: P, g: 100 - P - L, l: L }; };

  /* ---------- les 30 derniers jours (mercredi 14 octobre → jeudi 12 novembre). null = « Rien de noté » ---------- */
  const k30 = [2190, 2260, 2380, null, 2120, 2075, null, 2230, 2150, 2340, 2610, 2180, 2090, 2210, 2165, 2020, 2290, 2540, 2110, 2180, 2235, 1940, 2205].concat(k7);
  let serie = 0; for (let i = k30.length - 1; i >= 0 && k30[i] != null; i--) serie++;   // jours de suite avec au moins un aliment

  const N = {
    /* ----- le moment, le compte, la personne ----- */
    date: 'Jeudi 12 novembre 2026', court: 'jeu. 12 nov.', heure: '13:20',
    // Compte montré : GRATUIT (le cas de la plupart des gens). Une vue Premium se montre en le disant dans la légende.
    compte: { premium: false, photosGratuites: 10, photosUtilisees: 7, photosRestantes: 3, compteur: 'Encore 3 analyses de plat gratuites' },
    profil: { genre: 'Homme', age: 24, taille: 182, poids: 71.6, etape: 'Adulte', objectif: 'Perte de poids', activite: 'Modérée (4–5 séances)', activiteSuit: 'Suit tes séances de Fitness (4 par semaine)' },
    // « Comment c'est calculé » : Mifflin-St Jeor 10 × 71,6 + 6,25 × 182 − 5 × 24 + 5 = 1 738,5 ; × 1,55 = 2 695 ; plan : −495 kcal par jour
    calcul: { repos: 1739, depense: 2695, ecart: -495, kcal: GOAL, protParKg: 1.8 },
    // Récapitulatif « Ton objectif de poids » : 3,6 kg en 56 jours = 0,45 kg par semaine (0,63 % du poids, sous la limite de 1 %) ; 3,6 × 7 700 ÷ 56 = 495 kcal par jour
    plan: { depart: 73.4, departDate: '15 octobre', actuel: 71.6, cible: 68, perdu: 1.8, resteKg: 3.6, avancement: 1.8 / 5.4, duree: '8 semaines', jours: 56, rythme: -0.45, rythmePct: 0.63,
      kcal: GOAL, date: '7 janvier 2027', dateCourt: '7 janv.', surLeRythme: true, origine: 'Calculé d\'après ton plan' },
    /* ----- « Tes besoins par jour » : 4 cibles gratuites, 30 Premium. origine : 'Calculé' ou 'Personnalisé' ; reco = « Recommandé : … » ----- */
    cibles: [
      { n: 'Calories', v: GOAL, u: 'kcal', origine: 'Calculé', gratuit: true },
      { n: 'Protéines', v: 140, u: 'g', origine: 'Personnalisé', reco: 129, gratuit: true, c: 'prot' },     // 71,6 kg × 1,8 g = 129
      { n: 'Glucides', v: 250, u: 'g', origine: 'Personnalisé', reco: 268, gratuit: true, c: 'gluc' },      // (2 200 − 129 × 4 − 68 × 9) ÷ 4 = 268
      { n: 'Lipides', v: 70, u: 'g', origine: 'Personnalisé', reco: 68, gratuit: true, c: 'lip' },          // 28 % de 2 200 ÷ 9 = 68
      { n: 'Fibres', v: 31, u: 'g', origine: 'Calculé' },                                                    // 14 g par 1 000 kcal
      { n: 'Sucres', v: 55, u: 'g', origine: 'Calculé', limite: true },                                      // 10 % des calories
      { n: 'Gras saturés', v: 24, u: 'g', origine: 'Calculé', limite: true },
      { n: 'Sodium', v: 2300, u: 'mg', origine: 'Calculé', limite: true, note: 'Soit 5,8 g de sel' },
    ],

    /* ----- le jour ----- */
    jour: {
      kcal: { mange: T.kcal, objectif: GOAL, reste: GOAL - T.kcal, p: T.kcal / GOAL, mot: 'kcal restantes' },   // 1 078 · 2 200 · 1 122 · 49 %
      macros: [macro('prot', 'Protéines', 'prot', T.p, 140), macro('gluc', 'Glucides', 'gluc', T.g, 250), macro('lip', 'Lipides', 'lip', T.l, 70)],
      repas, nbRepas: repas.filter((m) => !m.vide).length,                                                       // 2 repas notés sur 4
      // « Répartition des calories » du jour : protéines × 4, glucides × 4, lipides × 9
      repartition: { p: Math.round(kcalM.p / kcalMt * 100), l: Math.round(kcalM.l / kcalMt * 100), g: 100 - Math.round(kcalM.p / kcalMt * 100) - Math.round(kcalM.l / kcalMt * 100) },
      // « Prochain repas » (calcul existant : le reste, partagé entre les repas principaux à venir sans rien de noté ; ici le souper seul)
      prochain: { repas: 'souper', kcal: GOAL - T.kcal, prot: 140 - T.p, txt: 'Prochain repas : souper, environ 1 122 kcal' },
      // Carte conseil du jour (F39) : l'état vrai à 13 h 20 (objectif connu, un aliment noté, plus de 150 kcal restantes)
      conseil: { t: 'Des idées pour la suite de ta journée', btn: 'Voir des idées', autres: ['Calcule tes besoins du jour', 'Objectif dépassé', 'Objectif atteint'] },
      // Ligne « Tous les nutriments » : résumé visible en Premium ; badge Premium sinon
      resumeNutriments: 'Fibres 11 g · sucres 28 g · sodium 1 240 mg',
      repasPropose: 'Dîner',                                                                                     // 11 h–15 h ; « + » d'une ligne : le repas de la ligne
    },

    /* ----- deux autres moments permis (cristal.js : DAY.matin, DAY.soiree). À dire dans la légende. ----- */
    matin: { heure: '08:10', mange: 420, reste: 1780, macros: [[24, 140], [52, 250], [12, 70]], nbRepas: 1, prochain: 'Prochain repas : dîner, environ 890 kcal' },   // 1 780 ÷ 2 repas principaux
    soir: { heure: '19:05', mange: 1520, reste: 680, macros: [[96, 140], [168, 250], [46, 70]], nbRepas: 3, prochain: 'Prochain repas : souper, environ 680 kcal',
      collation: { h: '16:10', kcal: 442, p: 28, g: 47, l: 12, items: [A.smoothie, A.barre] } },

    /* ----- la semaine civile (écran principal, « Calories de la semaine », gratuit) ----- */
    semaine: { titre: 'Cette semaine', lab: ['L', 'M', 'M', 'J', 'V', 'S', 'D'], kcal: sem, today: 3, objectif: GOAL, notes: [0, 1, 2, 3], dansObjectif: sem.map(inGoal),
      moyenne: avg(sem), joursNotes: noted(sem).length, joursOk: sem.filter(inGoal).length, jours },
    semainePrec: { titre: 'Semaine dernière', kcal: semPrec, moyenne: avg(semPrec), joursNotes: 7, joursOk: semPrec.filter(inGoal).length },

    /* ----- Historique « 7 jours » : les 7 derniers jours, aujourd'hui compris (Premium) ----- */
    h7: { lab: ['V', 'S', 'D', 'L', 'M', 'M', 'J'], dates: ['6', '7', '8', '9', '10', '11', '12'], kcal: k7, objectif: GOAL, joursNotes: 7, joursOk: k7.filter(inGoal).length,
      moyenne: avg(k7), prot: avg(p7), gluc: avg(g7), lip: avg(l7), repartition: part(avg(p7), avg(g7), avg(l7)),
      p7, g7, l7, phrase: null,
      complets: { n: 6, moyenne: avg(k7.slice(0, 6)), prot: avg(p7.slice(0, 6)), gluc: avg(g7.slice(0, 6)), lip: avg(l7.slice(0, 6)) } },   // = CAL7.avg et la planche Cristal 03 (repère seulement)
    /* ----- Historique « 30 jours » : 14 octobre → 12 novembre (Premium) ----- */
    h30: { du: '14 oct.', au: '12 nov.', kcal: k30, objectif: GOAL, joursNotes: noted(k30).length, joursOk: k30.filter(inGoal).length, moyenne: avg(k30),
      prot: 131, gluc: 256, lip: 68, repartition: part(131, 256, 68), phrase: null },
    serie,                                                                                                       // « Série de suivi » : 23 jours (depuis le 21 octobre)
    /* ----- « Jour par jour » (les plus récents d'abord) ----- */
    jourParJour: [['Jeu. 12 nov.', T.kcal], ['Mer. 11 nov.', 1980], ['Mar. 10 nov.', 2310], ['Lun. 9 nov.', 2140], ['Dim. 8 nov.', 2050], ['Sam. 7 nov.', 2480], ['Ven. 6 nov.', 2250]],

    /* ----- poids (Historique › « Poids », Premium ; la pesée se saisit dans « Mes paramètres » › « Toi ») ----- */
    poids: { actuel: 71.6, cible: 68, var7: -0.5, var30: -1.8, s7: [72.1, 72.0, 71.9, 71.9, 71.8, 71.7, 71.6],
      pesees30: [['15 oct.', 73.4], ['19 oct.', 73.2], ['22 oct.', 73.0], ['26 oct.', 72.8], ['29 oct.', 72.6], ['2 nov.', 72.4], ['5 nov.', 72.2], ['6 nov.', 72.1], ['7 nov.', 72.0], ['8 nov.', 71.9], ['9 nov.', 71.9], ['10 nov.', 71.8], ['11 nov.', 71.7], ['12 nov.', 71.6]] },

    /* ----- page « Nutriments » : 38 nutriments en 5 groupes (4 gratuits, 34 Premium). v = mangé ; cible ; null = « — » ; etat : 'partiel' | 'nd' (« Non disponible ») ----- */
    nutriments: [
      { t: 'Objectifs', items: [['Calories', 1078, 2200, 'kcal'], ['Protéines', 68, 140, 'g'], ['Glucides', 121, 250, 'g'], ['Lipides', 34, 70, 'g'], ['Fibres', 11, 31, 'g', 'prem']] },
      { t: 'À limiter', limite: true, items: [['Sucres', 28, 55, 'g'], ['Gras saturés', 9, 24, 'g'], ['Gras trans', 0.2, 2.4, 'g'], ['Cholestérol', 142, null, 'mg'], ['Sodium', 1240, 2300, 'mg'], ['Caféine', 95, 400, 'mg'], ['Alcool', 0, null, 'g']] },
      { t: 'Acides gras', items: [['Gras monoinsaturés', 14, null, 'g'], ['Gras polyinsaturés', 6, null, 'g'], ['Oméga-3', 0.6, 1.6, 'g', 'partiel'], ['Oméga-6', 5, 17, 'g', 'partiel']] },
      { t: 'Minéraux', items: [['Potassium', null, 3400, 'mg', 'nd'], ['Calcium', 380, 1000, 'mg', 'partiel'], ['Fer', 4, 8, 'mg'], ['Magnésium', 148, 400, 'mg'], ['Zinc', 5, 11, 'mg'], ['Phosphore', 620, 700, 'mg'], ['Sélénium', 38, 55, 'µg'], ['Cuivre', 0.4, 0.9, 'mg'], ['Manganèse', 1.4, 2.3, 'mg']] },
      { t: 'Vitamines', items: [['Vitamine A', 310, 900, 'µg'], ['Vitamine C', 96, 90, 'mg'], ['Vitamine D', 2, 15, 'µg'], ['Vitamine E', 5, 15, 'mg'], ['Vitamine K', 142, 120, 'µg'], ['Thiamine (B1)', 0.6, 1.2, 'mg'], ['Riboflavine (B2)', 0.9, 1.3, 'mg'],
        ['Niacine (B3)', 14, 16, 'mg'], ['Acide pantothénique (B5)', 2.6, 5, 'mg'], ['Vitamine B6', 1.0, 1.3, 'mg'], ['Folates (B9)', 210, 400, 'µg'], ['Vitamine B12', 1.1, 2.4, 'µg'], ['Choline', 180, 550, 'mg']] },
    ],

    /* ----- ajouter : recherche, feuille de quantité, bibliothèque ----- */
    aliments: A,
    familles: ['Pour toi', 'Fruits', 'Légumes', 'Féculents', 'Protéines', 'Produits laitiers', 'Noix et graines', 'Plats', 'Collations', 'Boissons', 'Sauces et sucres'],
    // « Suggestions » de la recherche vide : favoris, récents, aliments perso, table intégrée
    suggestions: [A.yogNat, A.banane, A.amandes, A.poulet, A.riz, A.smoothie],
    // recherche « yogourt » : « Résultats », puis la ligne « Chercher « yogourt » dans les produits emballés » (Open Food Facts, sur demande)
    recherche: { mot: 'yogourt', resultats: [A.yogNat, { n: 'Yogourt nature 2 %', c100: [61, 4, 5, 3] }, A.yogVan, { n: 'Yogourt à boire aux fraises', c100: [72, 3, 12, 1] }],
      emballes: 'Chercher « yogourt » dans les produits emballés', vide: 'Aucun produit trouvé pour « yogourt ».', erreur: 'Open Food Facts ne répond pas. Réessaie dans un instant.' },
    // feuille de quantité : l'exemple de toutes les planches (ouverte par le « + » de la ligne Collation)
    ajout: { aliment: A.yogNat, pour100: 'Pour 100 g : 73 kcal · protéines 10,0 g · glucides 4,0 g · lipides 2,0 g', q: 175, portions: ['½ portion', '1 portion', '2 portions', '100 g'], portion: 1, repas: 'Collation',
      apport: [['Calories', '128 kcal'], ['Protéines', '17,5 g'], ['Glucides', '7,0 g'], ['Lipides', '3,5 g']], apres: 'Après ajout, il te restera 994 kcal.', resteApres: GOAL - T.kcal - 128 },
    favoris: [A.yogNat, A.banane, A.amandes],                                                                    // 3 favoris : ceux du widget « Ajout rapide »
    mesAliments: [A.smoothie, A.barre],                                                                          // 2 aliments perso
    mesRepas: [
      { n: 'Déjeuner habituel', kcal: 420, p: 24, items: [A.pain, A.arachide, A.yogVan] },
      { n: 'Bol poulet et riz', kcal: 658, p: 44, items: [A.poulet, A.riz, A.brocoli] },
      { n: 'Pâtes du dimanche', kcal: 689, p: 33, items: [{ n: 'Spaghetti cuits', q: 250, kcal: 395 }, { n: 'Sauce tomate', q: 180, kcal: 94 }, { n: 'Mozzarella râpée', q: 65, kcal: 200 }] },
    ],
    // « Reprendre un … précédent » : les 3 derniers repas du même type (date, aliments, kcal)
    precedents: {
      din: [['Mer. 11 nov.', 'Saumon, Quinoa, Haricots verts', 702], ['Mar. 10 nov.', 'Pâtes, Sauce tomate, Fromage', 689], ['Lun. 9 nov.', 'Sandwich au poulet, Crudités, Pomme', 640]],
      sou: [['Mer. 11 nov.', 'Omelette aux légumes, Pain de blé entier, Salade verte', 623], ['Mar. 10 nov.', 'Chili con carne, Riz basmati cuit, Salade verte', 759], ['Lun. 9 nov.', 'Poulet grillé, Patate douce, Brocoli', 690]],
      col: [['Mer. 11 nov.', 'Yogourt grec nature, Banane', 235], ['Mar. 10 nov.', 'Smoothie protéiné maison, Barre maison avoine et dattes', 442], ['Lun. 9 nov.', 'Yogourt grec nature, Amandes, Clémentines', 390]],
    },

    /* ----- page « Idées » à 13 h 20 (repas suivant déjà choisi : Souper) ----- */
    idees: { titre: 'Il te reste environ 1 122 kcal',
      repas: [['Chili con carne', 400, 540, 36], ['Lasagne à la viande', 350, 560, 32], ['Pâté chinois', 350, 510, 27]],                    // [nom, g, kcal, protéines] : entre 45 % et 100 % du reste
      proteines: [['Poulet grillé', 120, 198, 36], ['Thon en conserve', 100, 116, 26], ['Fromage cottage 1 %', 125, 90, 15]],
      fibres: [['Lentilles cuites', 200, 232, 16], ['Framboises', 125, 65, 8], ['Pois chiches cuits', 150, 246, 11]] },                     // [nom, g, kcal, fibres] · Premium

    /* ----- scanner ----- */
    scan: {
      titre: 'Code-barres ou aliments', aide: 'Vise un code-barres ou ton assiette', flash: ['Flash automatique', 'Flash activé', 'Flash désactivé'], declencheur: 'Photographier le plat', attente: 'Analyse du plat sur ton iPhone…',
      // code-barres lu à 13 h 20 : un produit emballé trouvé sur Open Food Facts
      code: { n: 'Barre tendre avoine et miel', src: 'Open Food Facts', q: 35, portion: '1 barre (35 g)', kcal: 140, p: 2.5, g: 23, l: 4, c100: [400, 7, 66, 12], repas: 'Collation', resteApres: GOAL - T.kcal - 140 },
      // photo du souper à 19 h 05 (moment « soir » : 680 kcal restantes avant l'ajout). Estimation : fourchette, jamais une mesure.
      photo: { heure: '19:05', repas: 'Souper',
        items: [{ n: 'Saumon grillé', q: 140, kcal: 288, p: 31, g: 0, l: 17, src: 'Estimation', sur: 'assez sûr' }, { n: 'Riz basmati cuit', q: 150, kcal: 195, p: 4, g: 42, l: 1, src: 'Vérifié', sur: 'Ton habitude' },
          { n: 'Haricots verts', q: 100, kcal: 35, p: 2, g: 8, l: 0, src: 'Estimation', sur: 'assez sûr' }],
        aConfirmer: ['Huile de cuisson ?'], total: 518, fourchette: '≈ 440–600 kcal', p: 37, g: 50, l: 18, resteApres: 680 - 518 },
      sorties: { introuvable: 'Produit introuvable', actions: ['Créer cet aliment', 'Chercher dans la liste', 'Scanner à nouveau'], occupe: 'Service occupé', reessayer: 'Réessayer', fiche: 'Voir la fiche Open Food Facts', nonReconnu: 'Plat non reconnu', doublon: 'Déjà ajouté à l\'instant' },
      acces: { t: 'Utiliser la caméra', pourquoi: 'Pourquoi la caméra', reste: 'Ce qui reste sur ton iPhone', refus: 'Caméra désactivée', actions: ['Continuer', 'Plus tard', 'Ouvrir Réglages', 'Chercher ou créer l\'aliment'] },
    },

    /* ----- réglages, liens ----- */
    rappel: { t: 'Rappel des repas', heure: '20:00', actif: true },
    notifications: ['Rien de noté aujourd\'hui', 'Un dîner à noter ?', 'Ta journée en calories', 'Protéines du jour', 'Bilan nutrition de la semaine'],
    note: 'Valeurs indicatives, pas un avis médical. Aliments emballés : Open Food Facts (licence ODbL).',
    // carte de Mon quotidien (pleine largeur par défaut ; une version demi-largeur existe). Mêmes mots que la mini-app.
    quotidien: { vues: ['Aujourd\'hui', 'Repas', '7 jours'], aujourdhui: { anneau: '1 122', mot: 'kcal restantes', repas: '2 repas', bouton: 'Scanner', prochain: 'Prochain repas : souper, environ 1 122 kcal' },
      repas: { titre: 'Repas du jour', lignes: [['Déjeuner', '420'], ['Dîner', '658'], ['Souper', '—'], ['Collation', '—']], total: 'Total 1 078 / 2 200 kcal' },
      semaine: { titre: 'Calories · 7 jours', moyenne: 'Moyenne : 2 041 kcal par jour noté' } },
    widgets: { gratuits: ['Calories restantes', 'Macros'], premium: ['Protéines restantes', 'Repas du jour', 'Semaine nutrition', 'Série de suivi', 'Ajout rapide', 'Prochain repas'], verrouille: 'Scanner un aliment' },

    /* ----- CE QUI N'EXISTE PAS dans l'app : à étiqueter « Nouveau » (jeton, légende, case de texte). Jamais ailleurs. ----- */
    nouveau: {
      // Hydratation : la mini-app Eau a été retirée le 2026-10-15. Même objectif que l'habitude « Boire 2 L d'eau » de la journée d'exemple.
      eau: { objectifL: 2, buL: 1.25, verreMl: 250, verres: 5, verresObjectif: 8, p: 1.25 / 2, txt: '1,25 L sur 2 L', resteTxt: 'Encore 3 verres' },
      // Évolution des objectifs : l'app ne garde qu'une valeur (celle d'aujourd'hui). Journal daté proposé.
      objectifs: [{ d: '2 sept.', kcal: 2729, t: 'Maintien', s: 'Premier calcul' }, { d: '15 oct.', kcal: 2228, t: 'Perte de poids', s: 'Plan : 68 kg pour le 7 janvier' }, { d: '5 nov.', kcal: GOAL, t: 'Perte de poids', s: 'Ajustement accepté' }],   // exemple : 2 729 = dépense à 73,8 kg ; 2 228 = plan à 73,4 kg ; 2 200 = objectif d'aujourd'hui
      // Constats écrits (direction analytique), tirés de calculs existants
      constats: ['Protéines : 123 g en moyenne sur 7 jours, sous ton objectif de 140 g.', 'Les samedis dépassent : 2 480 et 2 540 kcal les deux derniers.', 'Tu perds 0,45 kg par semaine : c\'est le rythme de ton plan.'],
      // Comparaison de deux semaines (direction analytique)
      comparaison: { txt: 'Semaine dernière : 2 191 kcal en moyenne, 5 jours sur 7 dans l\'objectif' },
      annuler: { txt: 'Aliment retiré', btn: 'Annuler' },
    },

    /* ----- outils de texte (français du Canada) ----- */
    kc: (x) => PL.n(x) + NBSP + 'kcal',                                         // NUT.kc(1122) → « 1 122 kcal »
    gr: (x, dec = 0) => PL.n(x, dec) + NBSP + 'g',                              // NUT.gr(17.5, 1) → « 17,5 g »
    pgl: (a) => `P${NBSP}${Math.round(a.p)} · G${NBSP}${Math.round(a.g)} · L${NBSP}${Math.round(a.l)}`,           // ligne d'un aliment noté : « P 36 · G 0 · L 5 »
    ligne: (a) => `${PL.n(a.q)}${NBSP}g · ${N.pgl(a)}`,                         // « 120 g · P 36 · G 0 · L 5 »
    l100: (a) => `${a.c100[0]}${NBSP}kcal / 100${NBSP}g · P${NBSP}${a.c100[1]} · G${NBSP}${a.c100[2]} · L${NBSP}${a.c100[3]}`,   // ligne de la recherche
    // les trois jauges du héros, telles qu'elles s'affichent : NUT.jauges() ; NUT.jauges(true) : ce qu'il reste (« À adapter »)
    jauges: (reste) => N.jour.macros.map((m) => PL.meter(m.n, reste ? `reste ${m.reste}${NBSP}g` : `${m.v} / ${m.cible}${NBSP}g`, m.p, m.c)).join(''),
  };

  // phrases de l'Historique, écrites à partir des comptes
  N.h7.phrase = `${N.h7.joursOk} jours sur ${N.h7.joursNotes} à moins de 10 % de ton objectif`;
  N.h30.phrase = `${N.h30.joursOk} jours sur ${N.h30.joursNotes} à moins de 10 % de ton objectif`;
  N.semaine.phrase = `Moyenne ${nb(N.semaine.moyenne)} kcal · ${N.semaine.joursOk} jours sur ${N.semaine.joursNotes} dans l'objectif`;
  N.nouveau.comparaison.txt = `Semaine dernière : ${nb(N.semainePrec.moyenne)} kcal en moyenne, ${N.semainePrec.joursOk} jours sur 7 dans l'objectif`;

  /* ----- contrôle : les repères de cristal.js et du guide ne sont pas contredits ; les sommes sont justes ----- */
  N.verifier = function () { const err = [], ok = (c, m) => { if (!c) err.push(m); };
    ok(FONCTIONS.length === 64 && FONCTIONS.every((f, i) => f[0] === 'F' + (i + 1)), 'FONCTIONS : 64 fonctions attendues, F1 à F64 dans l\'ordre');
    ok(FONCTIONS.filter((f) => f[2] !== 'G').length === 17, 'FONCTIONS : 17 fonctions avec une part Premium attendues');
    ok(T.kcal === 1078 && T.p === 68 && T.g === 121 && T.l === 34, 'Jour : 1 078 kcal · P 68 · G 121 · L 34 attendus');
    ok(repas[0].kcal === 420 && repas[1].kcal === 658 && repas[1].p === 44 && repas[1].g === 69 && repas[1].l === 22, 'Repas : Déjeuner 420, Dîner 658 (P 44 · G 69 · L 22) attendus');
    ok(N.jour.kcal.reste === 1122 && N.ajout.resteApres === 994, 'Reste 1 122 ; 994 après le yogourt');
    ok(N.semaine.moyenne === 1877 && N.semaine.joursOk === 3 && N.semaine.joursNotes === 4, 'Semaine : moyenne 1 877, 3 jours sur 4');
    ok(N.h7.complets.moyenne === 2202 && N.h7.complets.prot === 132 && N.h7.complets.gluc === 262 && N.h7.complets.lip === 69, '6 jours complets : 2 202 kcal · 132 · 262 · 69 (planche Cristal 03)');
    ok(N.h7.moyenne === 2041 && N.h7.joursOk === 5 && N.h7.prot === 123 && N.h7.gluc === 242 && N.h7.lip === 64, '7 jours : 2 041 kcal, 5 jours sur 7, 123 · 242 · 64');
    ok(jours.every((j) => sum(j.repas) === j.kcal), 'Jours passés : la somme des repas = le total du jour');
    ok(N.mesRepas.every((m) => sum(m.items, (x) => x.kcal) === m.kcal), 'Mes repas : la somme des aliments = le total');
    ok(sum(N.soir.collation.items, (x) => x.kcal) === 442 && 1078 + 442 === N.soir.mange, 'Soir : collation 442 kcal, 1 520 kcal mangées');
    ok(sum(N.scan.photo.items, (x) => x.kcal) === N.scan.photo.total, 'Scan photo : total = somme des aliments');
    ok(N.nutriments.reduce((s, g) => s + g.items.length, 0) === 38, '38 nutriments attendus');
    ok(N.serie === 23 && N.h30.kcal.length === 30, 'Série de 23 jours ; 30 jours dans h30');
    if (typeof DAY !== 'undefined') { const d = DAY.journee;
      ok(d.kcal.eaten === T.kcal && d.kcal.left === N.jour.kcal.reste && d.kcal.goal === GOAL, 'cristal.js DAY.journee.kcal');
      ok(d.macros.p[0] === T.p && d.macros.g[0] === T.g && d.macros.l[0] === T.l, 'cristal.js DAY.journee.macros');
      ok(DAY.soiree.kcal.eaten === N.soir.mange && DAY.matin.kcal.eaten === N.matin.mange, 'cristal.js DAY.matin et DAY.soiree'); }
    if (typeof CAL7 !== 'undefined') ok(CAL7.past.every((v, i) => v === k7[i]) && CAL7.goal === GOAL, 'cristal.js CAL7.past');
    err.forEach((m) => console.error('nutrition.js : ' + m));
    return err; };
  return N;
})();
NUT.verifier();
