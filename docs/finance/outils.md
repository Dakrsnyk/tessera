# Trois dépôts de skills finance : évaluation

Date de consultation : 2026-10-26 (date demandée ; l'environnement indiquait 2026-10-25).
Lecture seule : aucune installation, aucun script exécuté.

URLs consultées :
- https://github.com/EveryInc/charlie-cfo-skill
- https://github.com/openaccountant/skills
- https://github.com/torlyai/financial-model-artifact
- API GitHub (métadonnées, licence, contenus, arbre, commits, archive) pour ces trois dépôts

## Tableau comparatif

| Critère | charlie-cfo-skill | openaccountant/skills | financial-model-artifact |
|---|---|---|---|
| (1) Licence | MIT : usage commercial et personnel permis | MIT : idem | MIT : idem |
| Contenu | 1 SKILL.md + 2 références (md) | 44 SKILL.md (12 personnel, 18 business, 14 shared) + paperclip | 1 PROMPT.md + 1 SKILL.md |
| (3) Installation officielle | `npx skills add EveryInc/charlie-cfo-skill` | `npx skills add openaccountant/skills` ; ou `git clone` dans `~/.openaccountant/skills` | Copie de `skills/financial-model` dans `~/.claude/skills/`, ou coller PROMPT.md |
| Dépendances | Aucune | CLI Wilson (dépôt séparé, non audité) pour les outils ; sinon fallback manuel | Aucune ; l'artifact HTML est autonome |
| (4) Prévisions | Modèle MRR, scénarios 13 semaines (cadre) | cash-flow-forecast (moyenne mobile 3 mois) | Modèle 36 mois complet |
| (4) Trésorerie | Runway, burn multiple, BFR (cadre) | runway-calculator, cash-flow-forecast | Flux de trésorerie (méthode indirecte), runway |
| (4) Compte de résultat | Non | profit-loss | Feuille P&L mensuelle |
| (4) Rentabilité | LTV:CAC, délai de récupération CAC, Rule of 40 | client-profitability, break-even-calc, pricing-optimizer | LTV:CAC, burn multiple, analyse et verdict |
| (4) Prix / abonnements | Non (remise annuelle seulement) | subscription-audit, expense-optimizer | Revenus pilotés par drivers, pas d'audit d'abonnements |
| (5) Hypothèses fiscales codées | Aucune loi fiscale ; repères et études de cas américains (Mailchimp, Zapier, Basecamp, etc.) | Très forte : IRS, Schedule C, 1099, 1040-ES, formulaires 2210/4562/8829, états américains, USD, banques et PayPal/Venmo/Stripe américains | Défauts britanniques : GBP, IS 19 %/25 %, TVA 20 %, cotisations employeur 1,13 ; à « ajuster selon la juridiction » |
| Adapté au Québec | Non (cadre générique, benchmarks US) | Non (fiscalité US) | Non en l'état (UK) ; adaptable : TPS/TVQ, impôts fédéral et québécois à définir |
| (6) Doublons avec la session | Aucun | Partiel avec xlsx (tableurs) ; aucun avec docx/pdf | Utilise artifact-design (déjà présent) ; partiel avec dataviz pour les graphiques |
| (7) Code exécuté | Non (markdown seul) | Non (markdown et yml seuls) | Non (génère du HTML/JS inline, sans réseau) |
| (7) Appels réseau | Aucun dans le dépôt | Aucun dans les fichiers ; `bank-sync` passe par Plaid (licence Wilson Pro) | Aucun dans l'artifact ; TorlyAI (service payant) propose la persistance |
| (7) Données envoyées | Aucune par le dépôt | Relevés et transactions traités par l'agent ; bank-sync envoie les identifiants bancaires à Plaid | Données saisies dans l'artifact ; persistance optionnelle chez un tiers |
| (7) Dernier commit | 2026-01-29 | 2026-04-09 | 2026-07-18 |
| (7) Étoiles | 327 | 97 | 3 |

## Verdicts

### charlie-cfo-skill : installer en partie
Raison : cadre utile pour raisonner sur runway, unités économiques et scénarios, mais sans calcul fiscal et avec des repères américains.
Procédure sûre : copier à la main `SKILL.md` et `references/metrics-benchmarks.md` dans un dossier de skill, sans `npx`.

### openaccountant/skills : installer en partie
Raison : bons modules généraux (prévisions, runway, P&L, abonnements), mais la moitié des skills est fiscalité américaine et plusieurs supposent le CLI Wilson et Plaid.
À retenir seulement, sans Wilson : cash-flow-forecast, runway-calculator, profit-loss, subscription-audit, break-even-calc.
À ne pas installer : tous les modules fiscaux US (tax-prep, quarterly-taxes, state-tax-estimator, sales-tax-nexus, tax-penalty-calc, home-office-deduction, depreciation-schedule, mileage-tracker), bank-sync, et les imports de plateformes non utilisées.
Le CLI Wilson n'a pas été audité ; ne pas le lancer sans revue.

### financial-model-artifact : installer en partie (comme prompt, pas comme outil)
Raison : bon modèle à 36 mois avec contrôle de bilan à chaque mois, sans code ni réseau. Mais la base est britannique, le projet est récent (3 étoiles) et la persistance passe par un service payant.
Avant usage : remplacer les défauts par des valeurs québécoises (devise CAD, TPS 5 % et TVQ 9,975 %, impôts fédéral et provincial à vérifier), ne pas utiliser TorlyAI pour des données réelles sans accord.

## Constats transversaux

- Aucun des trois dépôts ne contient de code exécutable (.py, .js, .sh) : seuls du markdown, des images et des fichiers de configuration.
- Le risque principal n'est pas le code du dépôt mais les données : relevés, transactions, identifiants bancaires (Plaid).
- `npx skills add` installe un paquet npm tiers : préférer une copie manuelle dans `~/.claude/skills/`.
- Aucun module ne traite la fiscalité québécoise (TPS/TVQ, impôt du Québec, acomptes provisionnels).
- Les benchmarks (charlie, openaccountant) sont américains ou génériques ; à recouper avant d'en tirer des décisions.
- Aucune installation n'a été faite ; ce document est la seule écriture.
