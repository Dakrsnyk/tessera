/* parcours.js : nouveau départ de la création (demande du PDG, 2026-11-15).
   Ordre imposé : 1 Taille (Petit / Moyen / Grand) → 2 Catégorie → 3 Widget(s) de la catégorie → 4 Personnalisation → 5 Aperçu et enregistrement.
   Toujours UN SEUL widget à la fin : Petit = 1 widget ; Moyen = 1 widget, ou 2 réunis ; Grand = 1 widget, ou jusqu'à 4 réunis.
   À charger après cristal.js et creation.js (objet CR), avant le script de la planche. */

Object.assign(CR, {
  /* Silhouette d'un widget iOS à sa proportion réelle, avec ses emplacements.
     fmt 's' | 'm' | 'l' · o.k échelle (0.42) · o.fill nombre d'emplacements pleins · o.plus « + » dans les vides */
  sil(fmt, o = {}) { const n = { s: 1, m: 2, l: 4 }[fmt];
    return `<div class="pc-sil ${fmt}" style="--k:${o.k || .42}">${Array.from({ length: n }, (_, k) => `<u class="${k < (o.fill || 0) ? 'f' : ''}">${o.plus === false || k < (o.fill || 0) ? '' : CR.ico('plus')}</u>`).join('')}</div>`; },

  SIZES: {
    s: { t: 'Petit', p: 'L\'essentiel en un coup d\'œil.', n: '1 widget', ic: 'La place de 4 icônes' },
    m: { t: 'Moyen', p: 'Plus d\'informations : un widget dans sa version moyenne, ou 2 widgets réunis côte à côte.', n: '1 ou 2 widgets', ic: 'La place de 8 icônes' },
    l: { t: 'Grand', p: 'Un tableau de bord de l\'espace : un widget en grand, ou jusqu\'à 4 widgets réunis.', n: '1 à 4 widgets', ic: 'La place de 16 icônes' },
  },
  /* Page 1 : les trois tailles, et rien d'autre ; en bas, un lien discret vers l'écran verrouillé (choix du PDG, 2026-11-15).
     o.on taille touchée · o.k échelle des silhouettes · o.q / o.sub textes · o.lock false = sans le lien */
  sizePage(o = {}) { return `<div class="pc-q">${o.q || 'Quelle taille pour ton widget ?'}</div><div class="pc-sub">${o.sub || 'Tu pourras y réunir plusieurs widgets d\'une même catégorie.'}</div>`
    + ['s', 'm', 'l'].map((f) => { const z = CR.SIZES[f];
      return `<div class="pn pc-size${o.on === f ? ' on' : ''}"><div class="vis">${CR.sil(f, { k: o.k || (f === 'l' ? .4 : .42) })}</div>
        <div class="tx"><b>${z.t}</b><p>${z.p}</p><span class="cap2">${CR.ico('grid')}${z.n}</span><span class="pc-ic4">${z.ic}</span></div>${CR.ico('chev')}</div>`; }).join('')
    + (o.lock === false ? '' : `<div class="pc-lockl">${CR.ico('lockscreen')}Widget d'écran verrouillé${CR.ico('chev')}</div>`); },

  /* Rappel de la taille choisie, en tête des pages 2 et 3. */
  chosen(fmt, o = {}) { const z = CR.SIZES[fmt];
    return `<div class="pn pc-chosen">${CR.sil(fmt, { k: .16, plus: false, fill: o.fill })}<span><b>${z.t}</b> · ${o.t || z.n}</span>${o.ch === false ? '' : '<span class="ch">Changer</span>'}</div>`; },

  /* Catégories de Créer (vérifiées dans le code le 2026-11-15). n = [widgets en Petit, en Moyen ou Grand] ; c = couleur de l'espace (Space.colorHex).
     « Heure et date » = les widgets sans espace de Fusion.category « time » (absents de Créer aujourd'hui : À adapter). Météo : aucun widget (retiré du code). */
  CATS: [
    { t: 'Heure et date', i: 'clock', c: '#5B6CFF', n: [8, 8] },
    { t: 'Planning · études', i: 'graduation', c: '#D6409F', n: [8, 8] },
    { t: 'Météo', i: 'sun', c: '#9AA3B2', soon: 1 },
    { t: 'Nutrition', i: 'fork', c: '#F08A24', n: [9, 9] },
    { t: 'Fitness', i: 'dumbbell', c: '#E5484D', n: [8, 8] },
    { t: 'Budget', i: 'wallet', c: '#2F8F7A', n: [9, 9] },
    { t: 'Habitudes', i: 'repeat', c: '#7FA33A', n: [3, 4] },
    { t: 'Photos et citations', i: 'image', c: '#EC4899', n: [2, 2] },
    { t: 'Productivité', i: 'list', c: '#6B7280', n: [8, 8] },
    { t: 'Placements', i: 'trend', c: '#8C6CFF', n: [4, 4] },
    { t: 'Mon entreprise', i: 'bars', c: '#C28A12', n: [6, 7] },
    { t: 'Sociétés cotées', i: 'chart', c: '#3366FF', n: [3, 4] },
    { t: 'Voyage', i: 'plane', c: '#12A4B5', n: [7, 7] },
    { t: 'Auto', i: 'car', c: '#4B5563', n: [5, 5] },
    { t: 'Ma vie', i: 'heart', c: '#5B6CFF', n: [3, 3] },
  ],
  /* Page 2 : la grille des catégories. fmt taille choisie · o.on nom de la catégorie touchée · o.only noms à montrer */
  catPage(fmt, o = {}) { const k = fmt === 's' ? 0 : 1;
    const list = (o.only ? CR.CATS.filter((c) => o.only.includes(c.t)) : CR.CATS);
    return `<div class="pc-cats">${list.map((c) => { const soon = c.soon;
      const sub = soon ? '<span class="tg">À DÉVELOPPER</span>' : `<span>${c.n[k]} widget${c.n[k] > 1 ? 's' : ''}</span>`;
      return `<div class="pn pc-cat${o.on === c.t ? ' on' : ''}${soon ? ' soon' : ''}"><span class="ic" style="background:${c.c}">${CR.ico(c.i)}</span><span class="tx"><b>${c.t}</b>${sub}</span></div>`; }).join('')}</div>`; },

  /* Carte des emplacements : fmt 's' | 'm' | 'l' · items = export ('nextSet-s'), {ph:'icône', t:'nom'}, ou null (emplacement vide)
     o.w largeur (270) · o.lock [index Premium] · o.add texte des vides ('Ajouter') */
  slots(fmt, items, o = {}) { const n = { s: 1, m: 2, l: 4 }[fmt]; const cells = [];
    for (let i = 0; i < n; i++) { const it = items[i];
      const tag = it ? `<span class="n">${i + 1}</span>${(o.lock || []).includes(i) ? `<span class="lk">${CR.ico('lock')}</span>` : ''}` : '';
      let inner, cl = '';
      if (!it) { inner = `<b>${CR.ico('plus')}${o.add ?? 'Ajouter'}</b>`; cl = 'e'; }
      else if (typeof it === 'object') { inner = `<b>${CR.ico(it.ph)}${it.t}</b>`; cl = 'ph'; }
      else inner = `<img data-w="${it}-light" alt="">`;
      cells.push(`<div class="${cl}">${inner}${tag}</div>`); }
    return `<div class="pc-slots ${fmt}" style="--sw2:${o.w || 270}px">${cells.join('')}</div>`; },

  /* Zone de composition (page 3) : la carte des emplacements, le compteur, « simple » ou « combiné », et le résultat.
     fmt · items (comme CR.slots) · o.res phrase « Résultat » · o.msg phrase sous le compteur · o.w · o.lock */
  build(fmt, items, o = {}) { const max = { s: 1, m: 2, l: 4 }[fmt], used = items.filter(Boolean).length, left = max - used;
    const kind = used > 1 ? `<span class="pc-kind combo">${CR.ico('layers')}Combiné · ${used} widgets</span>` : `<span class="pc-kind simple">${CR.ico('one')}Widget simple</span>`;
    const msg = o.msg ?? (fmt === 's' ? '' : left > 0 ? `Tu peux encore ajouter ${left} widget${left > 1 ? 's' : ''}.` : (fmt === 'm' ? 'Un widget moyen réunit 2 widgets au plus.' : 'Un grand widget réunit 4 widgets au plus.'));
    return `<div class="pn pc-build ${o.cls || ''}">${CR.slots(fmt, items, o)}<div class="pc-cnt"><span class="dots">${Array.from({ length: max }, (_, k) => `<u class="${k < used ? 'f' : ''}"></u>`).join('')}</span><b>${used} sur ${max}</b>${o.kind === false ? '' : kind}</div>
      ${msg ? `<div class="pc-cnt" style="margin-top:3px"><span>${msg}</span></div>` : ''}${o.res ? `<div class="pc-res">${o.res}</div>` : ''}</div>`; },

  /* Bouton du bas de la page 3 (au-dessus de la barre d'onglets). */
  go: (t, s) => `<div class="pc-go"><div class="btnP">${t}</div>${s ? `<div class="s">${s}</div>` : ''}</div>`,

  /* Bandeau commun aux cinq planches : un seul widget à la fin, simple ou combiné. */
  rule() { const ex = (html, t, s, cls = '') => `<div class="pc-ex ${cls}">${html}<div class="lb"><b>${t}</b><span>${s}</span></div></div>`;
    return `<div class="pn pc-rule"><div class="lead"><h3>Une création = un seul widget</h3><p>On choisit une taille, puis ce qu'on y met. Plusieurs widgets d'une même catégorie peuvent être <b>réunis dans ce widget</b> ; on ne crée jamais plusieurs widgets séparés d'un coup.</p></div>
      ${ex(CR.w('nextSet-s-light', 100), 'Petit', 'Widget simple · 1')}<span class="pc-sep"></span>
      ${ex(CR.w('todaysWorkout-m-light', 214), 'Moyen simple', '1 widget, version moyenne')}
      ${ex(CR.combo(['nextSet-s', 'trainingStreak-s'], { w: 214 }), 'Moyen combiné', 'Combiné · 2 widgets (2 au plus)')}<span class="pc-sep"></span>
      ${ex(CR.w('timetable-l-light', 128), 'Grand simple', '1 widget, version grande')}
      ${ex(CR.combo(['todaysWorkout-m', 'nextSet-s', 'trainingStreak-s'], { w: 128, fmt: 'l' }), 'Grand combiné', 'Combiné · 3 widgets (4 au plus)')}<span class="pc-sep"></span>
      ${ex(`<div class="pair">${CR.w('nextSet-s-light', 74)}${CR.w('trainingStreak-s-light', 74)}</div><span class="bar"></span>`, 'Plus possible', '2 widgets Petit séparés d\'un coup', 'no')}</div>`; },
});
