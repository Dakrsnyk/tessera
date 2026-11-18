export const meta = {
  name: 'pubs-ardane-v2-script',
  description: 'Catalogue des captures utilisables, puis texte de voix et découpage v2 des deux pubs (sans blancs, Meet Ardane, 60 s max), vérifiés',
  phases: [
    { title: 'Catalogue', detail: 'quatre lecteurs regardent les captures de l\'app actuelle, par famille', model: 'sonnet' },
    { title: 'Ecriture', detail: 'trois scénarios indépendants, trois angles' },
    { title: 'Synthese', detail: 'un juge note et fusionne' },
    { title: 'Verification', detail: 'deux relecteurs : authenticité, rythme et blancs' },
    { title: 'Version finale', detail: 'corrections et storyboard écrit dans la mémoire' },
  ],
}

const REPO = 'C:\\Users\\Etudiant\\Documents\\GitHub\\tessera'
const FILM = 'C:\\Users\\Etudiant\\ardane-tools\\film'
const KIT = FILM + '\\public\\kit2026\\en'
const KIT472 = 'C:\\Users\\Etudiant\\ardane-tools\\kit-472'

const CATALOG_SCHEMA = {
  type: 'object',
  properties: {
    captures: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name: { type: 'string', description: 'nom du fichier sans .png' },
          folder: { type: 'string', description: 'kit ou kit-472 : le dossier dont la version est la bonne' },
          appearance: { type: 'string', description: 'dark ou light' },
          shows: { type: 'string', description: 'ce que l\'écran montre réellement, en une phrase précise' },
          ok: { type: 'boolean', description: 'false si la capture est ratée (page d\'accueil à la place, transition en cours, écran vide)' },
          problem: { type: 'string' },
          adValue: { type: 'number', description: '1 à 5 : intérêt pour une pub' },
        },
        required: ['name', 'folder', 'appearance', 'shows', 'ok'],
      },
    },
    summary: { type: 'string' },
  },
  required: ['captures', 'summary'],
}

const SCRIPT_SCHEMA = {
  type: 'object',
  properties: {
    films: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string', description: 'main ou widget' },
          durationSec: { type: 'number' },
          sequences: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                name: { type: 'string' },
                startSec: { type: 'number' },
                endSec: { type: 'number' },
                shots: {
                  type: 'array',
                  items: {
                    type: 'object',
                    properties: {
                      capture: { type: 'string', description: 'nom de capture du catalogue, ou nom d\'une animation existante' },
                      shows: { type: 'string' },
                      durSec: { type: 'number' },
                      onScreenText: { type: 'string', description: 'mot-titre, étiquette ou pastille à l\'écran, en anglais' },
                    },
                    required: ['capture', 'shows', 'durSec'],
                  },
                },
                vo: {
                  type: 'array',
                  items: {
                    type: 'object',
                    properties: {
                      text: { type: 'string' },
                      startSec: { type: 'number' },
                      estDurSec: { type: 'number' },
                    },
                    required: ['text', 'startSec', 'estDurSec'],
                  },
                },
              },
              required: ['name', 'startSec', 'endSec', 'shots', 'vo'],
            },
          },
        },
        required: ['id', 'durationSec', 'sequences'],
      },
    },
    rationale: { type: 'string' },
  },
  required: ['films', 'rationale'],
}

const REVIEW_SCHEMA = {
  type: 'object',
  properties: {
    issues: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          film: { type: 'string' },
          where: { type: 'string' },
          severity: { type: 'string', description: 'bloquant, important ou mineur' },
          problem: { type: 'string' },
          fix: { type: 'string' },
        },
        required: ['film', 'where', 'severity', 'problem', 'fix'],
      },
    },
    verdict: { type: 'string' },
  },
  required: ['issues', 'verdict'],
}

const GROUPS = [
  { key: 'nutrition', re: '^(pub26-nutrition|app-nutrition|nut-|scan-|nutrition-plan|info-nutrition)', extra: '' },
  { key: 'fitness', re: '^(pub26-fitness|app-fitness|session-|lib-|ex-)', extra: ' Regarde aussi deux images de la démonstration animée du développé couché (demo-bench-press-dark-0000 et demo-bench-press-dark-0120, dossier kit seulement : 240 images exportées avant la refonte) et dis si elles restent utilisables telles quelles.' },
  { key: 'planning-accueil', re: '^(pub26-planning|app-planning|plan-|hab-|pub26-home|home-s0)', extra: '' },
  { key: 'creer-studio', re: '^(pub26-create|pub26-editor|pub26-mywidgets|spaces|editor|studio-|creator-|mywidgets|store)', extra: '' },
]

const catalogPrompt = g => `Tu fais un CATALOGUE en lecture seule de captures d'écran de l'app iOS Ardane (version actuelle, interface en anglais), pour des publicités vidéo. Ne modifie aucun fichier du dépôt, ne lance aucun rendu, aucun git. Sous Windows, Python s'appelle python.

Deux dossiers de captures PNG (1206 x 2622, simulateur, barre d'état à 9:41) :
- "kit" : ${KIT} (lot du run 471, plus cinq captures pub26-* du run 472 ; c'est le dossier que les films utilisent)
- "kit-472" : ${KIT472} (lot du run 472, plus récent, 198 fichiers ; il manque la fin de la liste)

Famille à traiter : ${g.key}. Fichiers dont le nom (sans .png) correspond à l'expression ${g.re}. Liste-les dans les deux dossiers.${g.extra}

Piège connu : certaines captures sont RATÉES. Prises trop tôt, elles montrent la page d'accueil « Your evening » (cartes Nutrition, Fitness, Planning) au lieu de l'écran demandé, ou une transition en cours (deux écrans qui se chevauchent). Les captures creator-* montrent l'écran « What size for your widget? » au lieu du constructeur. Tu dois le voir de tes yeux, pas le déduire du nom.

Méthode : fabrique des planches de contact avec ffmpeg (6 à 8 captures par planche, chacune réduite à 300 px de large, par exemple -filter_complex avec scale=300:-1 puis hstack) dans un dossier temporaire à toi (par exemple %TEMP%\\catalogue-${g.key}), regarde chaque planche avec Read, et rouvre en plus grand toute capture douteuse ou intéressante. Quand une capture existe dans les deux dossiers, compare et retiens la meilleure (indique son dossier dans "folder"). Privilégie les variantes sombres (-dark) : les pubs sont en sombre.

Pour chaque capture regardée, donne : le nom, le dossier retenu, l'apparence (dark ou light), ce que l'écran montre réellement (précis : titre de la page, cartes visibles, boutons flottants, chiffres), ok (false si ratée), le problème éventuel, et son intérêt pour une pub de 1 à 5 (5 = écran riche, lisible, qui montre une vraie fonction parlante). Dans "summary", liste les 6 à 10 meilleures captures de la famille pour illustrer la mini-app ou le parcours, et ce qui manque.`

const FACTS = `## Contexte commun
Ardane est une app iOS de widgets et de mini-apps (Nutrition, Fitness, Planning, etc.). Deux publicités verticales (1080 x 1920, 60 images par seconde, voix féminine en anglais, musique) viennent d'être rendues en version 1. Le PDG les a regardées et demande une version 2.

Fichiers à lire au besoin (lecture seule) :
- Brief du PDG et ses décisions : ${REPO}\\docs\\memoire\\campagne-2026\\18-brief-pdg-2026-11-18.md
- Découpage de la version 1 : ${REPO}\\docs\\memoire\\campagne-2026\\20-storyboards-2026-11-18.md
- Minutages de la version 1 : ${FILM}\\src\\pub26\\timing26.ts ; captures et étiquettes : ${FILM}\\src\\pub26\\shots.ts ; textes de voix : ${REPO}\\scripts\\ad2\\vo_spec_pub26.json
- Code réel de l'app (pour vérifier qu'une fonction existe) : ${REPO}\\App\\Screens\\ (mini-apps dans App\\Screens\\MiniApps\\)

## Retour du PDG sur la version 1 (à respecter à la lettre)
1. Il y a trop de blancs, c'est-à-dire de moments sans voix. Il faut les combler par des commentaires sur la section mise en avant. Son exemple : pour Fitness, parler des exercices, des démonstrations, des statistiques, etc.
2. Il faut un « Meet Ardane. » entre la phrase d'accroche et le texte principal.
3. On peut ajouter des images si nécessaire. La durée maximale d'une pub passe à UNE MINUTE.
4. Au choix : accélérer la présentation là où il y a des blancs, ou les combler avec du texte, ou un mélange des deux.

## Version 1, mesurée
Main Pub (29,27 s) : accroche validée de 0 à 7,43 s (voix : 0,56–1,93 s puis 2,95–4,89 s) ; quatre écrans d'accueil un par un de 7,4 à 14,4 s avec « All your essentials on your home screen. » (7,83–9,66 s) puis 5 s sans voix ; trois mini-apps de 14,4 à 20,9 s avec un seul mot chacune (« Nutrition. » 14,63 s, « Fitness. » 16,80 s, « Planning. » 18,97 s) ; « Make everyday your own. » (21,87–23,12 s) sur un widget seul, son arrivée sur un écran d'accueil et le résultat ; carte finale validée (2,83 s) avec « Ardane. Your whole life. One place. » (26,87–29,10 s).
Widget Pub (28,83 s) : « You want your phone to look like this? » (0,50–2,13 s) sur un téléphone avant Ardane (1,5 s) puis quatre écrans d'accueil après Ardane (5,5 s, sans voix pendant 5,2 s) ; personnalisation dans l'app pendant 12 s (écran Create « What size for your widget? », Atelier chapitre Content, taille Medium, style Aurora, style Neon, palette Gold, avec des pastilles « Pick a size », « Choose what it shows », « Make it Medium », « Change the style », « Another style », « Pick your colors ») avec « With Ardane, you can customize your own widgets. » (7,33–9,89 s) et « And styles. » (13,20–14,05 s) ; résultat sur trois écrans d'accueil (7 s, sans voix : 12,4 s de blanc au total) ; carte finale avec la même phrase.

## Règles fermes
- Voix en anglais, féminine, posée, élégante, phrases COURTES qui accompagnent l'image. Débit réel de la voix de synthèse utilisée : environ 3,2 mots par seconde ; compte 0,32 s par mot plus 0,15 s par phrase, un mot seul 0,7 s, et au moins 0,2 s entre deux phrases. Jamais deux phrases qui se chevauchent, jamais de voix accélérée.
- Entre la fin de l'accroche et la phrase de la carte finale, aucun blanc de voix de plus de 1,5 s, sauf UNE respiration musicale voulue de 2 s au plus par film.
- Durée de chaque film : 60 s au plus. Viser le rythme d'une pub Apple ou Nike : dense, jamais désordonné. Chaque plan d'interface reste lisible au moins 0,9 s.
- Main Pub : l'accroche (0 à 7,43 s, images et voix) et la carte finale (2,83 s, sa phrase dure 2,23 s et commence 0,37 s après le début de la carte) restent IDENTIQUES. « Meet Ardane. » vient juste après l'accroche, avant « All your essentials on your home screen. ».
- Phrases du PDG à garder mot pour mot : Main Pub « All your essentials on your home screen. », les noms « Nutrition. », « Fitness. », « Planning. », « Make everyday your own. » ; Widget Pub « You want your phone to look like this? », « With Ardane, you can customize your own widgets. », « And styles. ». Le titre de la Widget Pub est « Your phone. Your style. Your widgets. » : il peut être dit.
- Authenticité : ne dire et ne montrer que des fonctions qui existent réellement dans l'app, illustrées par une capture du catalogue marquée ok. Pas de filtres (l'app n'en a pas). Options Premium (styles Aurora et Neon, palettes, fonds, plus de 3 widgets sur un écran) : mention « With Premium » à l'écran, pas dans la voix. Ne jamais dire que tout est gratuit.
- Écrans d'accueil : vrais écrans d'iPhone sans coque dessinée, avec seulement ces apps Apple : Calendar, Photos, Reminders, News, Maps, Health, Wallet, Settings, Safari, Messages.
- Animations déjà disponibles et réutilisables (en plus des captures) : "homes" (écrans d'accueil qui se transforment l'un en l'autre, un par un), "photoScan" (balayage d'un repas pris en photo, puis récapitulatif calories et macros), "demo-bench-press" (démonstration animée d'un exercice, 4 s en boucle), "process" (parcours de personnalisation avec pastilles), "widget-lift" (un widget seul qui vient se poser sur un écran d'accueil), "end-card" (carte finale).`

const writerPrompt = (angle, catalog) => `Tu es concepteur-rédacteur publicitaire. Tu écris la VERSION 2 du texte de voix et du découpage de deux publicités d'Ardane, en réponse au retour du PDG. Lecture seule : ne modifie aucun fichier, ne lance aucun rendu ni git.

${FACTS}

## Catalogue des captures de l'app actuelle (vérifiées à l'œil ; n'utilise que celles marquées ok: true)
${JSON.stringify(catalog)}

## Ton angle
${angle}

## Ce que tu rends
Pour chacun des deux films (id "main" puis "widget") : la durée totale, et la liste des séquences avec leurs plans (capture du catalogue ou animation existante, ce qu'on voit, durée, texte à l'écran) et leurs phrases de voix (texte anglais, début en secondes, durée estimée avec la règle de débit). Respecte toutes les règles fermes, en particulier : aucun blanc de voix de plus de 1,5 s hors accroche et carte finale, « Meet Ardane. » après l'accroche de la Main Pub, phrases du PDG mot pour mot, 60 s au plus. Pour chaque mini-app de la Main Pub, la voix commente ce que l'image montre (Fitness : exercices, démonstrations, statistiques ; fais de même pour Nutrition et Planning avec leurs vraies fonctions). Pour la Widget Pub, la voix accompagne chaque étape de la personnalisation et le résultat. Dans "rationale", explique tes choix en cinq lignes et calcule toi-même le plus long blanc de voix de chaque film.`

const ANGLES = [
  'Sobriété Apple : très peu de mots, chacun pesé, des phrases de deux à cinq mots, un rythme régulier. Tu resserres les plans là où la voix n\'a rien à dire plutôt que d\'ajouter du texte. Films plutôt courts (35 à 45 s).',
  'Bénéfice pour l\'utilisateur : chaque phrase dit ce que la personne y gagne dans sa journée (« Know what\'s left to eat », « Never miss a class »), avec des plans supplémentaires qui le prouvent. Films de 45 à 55 s.',
  'Démonstration produit rythmée, façon Nike : verbes d\'action à l\'impératif (« Scan it. Log it. », « Lift. Track. Improve. »), montage serré calé sur la musique à 120 battements par minute (un temps = 0,5 s), plusieurs plans courts par mini-app. Films de 40 à 50 s.',
]

phase('Catalogue')
const cats = (await parallel(GROUPS.map(g => () =>
  agent(catalogPrompt(g), { label: 'catalogue:' + g.key, phase: 'Catalogue', schema: CATALOG_SCHEMA, model: 'sonnet' })
))).filter(Boolean)
const catalog = cats.flatMap(c => c.captures)
const usable = catalog.filter(c => c.ok)
log(`Catalogue : ${catalog.length} captures regardées, ${usable.length} utilisables, ${catalog.length - usable.length} ratées`)
const compact = usable.map(c => ({ name: c.name, folder: c.folder, appearance: c.appearance, shows: c.shows, adValue: c.adValue }))
const summaries = cats.map(c => c.summary)

phase('Ecriture')
const drafts = (await parallel(ANGLES.map((a, i) => () =>
  agent(writerPrompt(a, compact), { label: 'scenario:' + (i + 1), phase: 'Ecriture', schema: SCRIPT_SCHEMA })
))).filter(Boolean)
log(`${drafts.length} scénarios écrits`)

phase('Synthese')
const merged = await agent(`Tu es directeur de création. Trois rédacteurs ont écrit, chacun avec un angle différent, la version 2 du texte de voix et du découpage de deux publicités d'Ardane. Note chaque proposition (respect du retour du PDG, absence de blancs, justesse et élégance de l'anglais, authenticité, rythme, clarté dès le premier visionnage), puis écris LA version finale : pars de la meilleure et greffe les meilleures idées des deux autres. Lecture seule : ne modifie aucun fichier.

${FACTS}

## Résumés du catalogue par famille
${JSON.stringify(summaries)}

## Catalogue des captures utilisables
${JSON.stringify(compact)}

## Les trois propositions
${JSON.stringify(drafts)}

Exigences pour ta version finale : toutes les règles fermes ; recalcule chaque début de phrase et chaque durée avec la règle de débit ; vérifie toi-même qu'aucun blanc de voix ne dépasse 1,5 s entre la fin de l'accroche et la carte finale (une seule respiration de 2 s au plus par film) et qu'aucune phrase n'en chevauche une autre ; n'utilise que des captures du catalogue ou les animations existantes ; chaque phrase doit correspondre à ce que le plan montre au même instant. Dans "rationale" : les notes des trois propositions, ce que tu as repris de chacune, et le tableau des blancs de voix de chaque film.`, { label: 'synthese', phase: 'Synthese', schema: SCRIPT_SCHEMA })

phase('Verification')
const LENSES = [
  { key: 'authenticite', text: `Ton angle : AUTHENTICITÉ. Pour chaque phrase de voix et chaque texte à l'écran, vérifie dans le code de l'app (${REPO}\\App\\Screens\\, recherche ciblée avec Grep) que la fonction annoncée existe vraiment et fonctionne comme dit (par exemple : scan d'un repas en photo, code-barres, démonstrations animées d'exercices, statistiques de progression, tâches, habitudes, import d'horaire, styles, palettes). Vérifie que chaque capture citée figure dans le catalogue des captures utilisables, et ouvre avec Read celles qui portent une affirmation précise (dossier ${KIT} ou ${KIT472}) pour confirmer que l'image montre bien ce que la voix dit. Signale toute promesse exagérée, toute fonction Premium présentée sans la mention « With Premium », toute allusion à des filtres ou à la gratuité.` },
  { key: 'rythme', text: `Ton angle : RYTHME ET BLANCS. Recalcule tout avec la règle de débit (0,32 s par mot plus 0,15 s par phrase, un mot seul 0,7 s, 0,2 s au moins entre deux phrases). Liste chaque blanc de voix de plus de 1,5 s entre la fin de l'accroche et la carte finale, chaque chevauchement, chaque phrase qui déborde de son plan ou commence avant que son image soit à l'écran, chaque plan d'interface de moins de 0,9 s, tout dépassement de 60 s. Vérifie mot pour mot les phrases imposées par le PDG et la place de « Meet Ardane. ». Relis l'anglais comme un natif exigeant : faute, tournure lourde, répétition, phrase trop longue pour être dite posément, mot difficile pour une voix de synthèse. Vérifie que l'accroche et la carte finale ne sont pas modifiées.` },
]
const reviews = (await parallel(LENSES.map(l => () =>
  agent(`Tu es relecteur d'un scénario de publicité, chargé de trouver ses défauts avant le tournage. Sois sévère : ne laisse rien passer, mais ne signale que des défauts réels et vérifiés. Lecture seule : ne modifie aucun fichier, aucun git.

${FACTS}

## Catalogue des captures utilisables
${JSON.stringify(compact)}

## Scénario à relire
${JSON.stringify(merged)}

${l.text}

Rends la liste des défauts (film, endroit, gravité : bloquant, important ou mineur, problème, correction précise) et un verdict en deux lignes.`, { label: 'relecture:' + l.key, phase: 'Verification', schema: REVIEW_SCHEMA })
))).filter(Boolean)
const issues = reviews.flatMap(r => r.issues)
log(`${issues.length} défauts relevés par les relecteurs`)

phase('Version finale')
const final = await agent(`Tu es directeur de création. Corrige le scénario ci-dessous d'après les défauts relevés par deux relecteurs, puis écris le storyboard de la version 2 dans un fichier.

${FACTS}

## Catalogue des captures utilisables
${JSON.stringify(compact)}

## Scénario
${JSON.stringify(merged)}

## Défauts relevés
${JSON.stringify(issues)}

Travail : applique chaque correction bloquante ou importante (les mineures si elles ne coûtent rien) ; si tu en écartes une, dis pourquoi dans "rationale". Recalcule ensuite tous les débuts et durées de voix avec la règle de débit et revérifie : aucun blanc de plus de 1,5 s hors accroche et carte finale (une respiration de 2 s au plus par film), aucun chevauchement, 60 s au plus, phrases du PDG mot pour mot, « Meet Ardane. » juste après l'accroche de la Main Pub, accroche et carte finale intactes.

Écris ensuite UN SEUL fichier, ${REPO}\\docs\\memoire\\campagne-2026\\21-script-v2-2026-11-18.md (nouveau fichier, en français, texte de voix en anglais) : le retour du PDG en trois lignes, puis pour chaque film un tableau plan par plan (début, fin, ce qu'on voit, capture et dossier, texte à l'écran, phrase de voix avec son début et sa durée), le tableau des blancs de voix, et la liste des captures utilisées avec leur dossier. Ne modifie aucun autre fichier, aucun git.

Rends le scénario final dans le format demandé.`, { label: 'version-finale', phase: 'Version finale', schema: SCRIPT_SCHEMA })

return { catalogCount: catalog.length, failed: catalog.filter(c => !c.ok).map(c => c.name + ' (' + c.folder + ')'), summaries, issues, final }
