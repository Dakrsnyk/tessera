# Passation de session : Ardane vers l'App Store

Écrite le 2026-10-29 par le Chef (session principale) pour la prochaine session. Lis d'abord `CLAUDE.md`, puis ce fichier, puis `docs/memoire/Demandes.md` (chantiers 12 et 13) et `docs/lancement/feuille-de-route.md`. Répondre en français. L'utilisateur est le seul décideur pour toute dépense, démarche officielle, publication ou action irréversible.

## 1. État en une minute
- **Dernier commit** : `23a0598` sur `main` (poussé). **Dernier build TestFlight interne (Premium)** : **292**, vérifié « Internal Only » par la CI (envoyé le 2026-10-27). Contient : météo retirée, essai gratuit de 7 jours, 3 widgets gratuits, renommage Tessera en Ardane, nouvelle palette de 12 couleurs.
- **Dépôt GitHub `Dakrsnyk/tessera` : PUBLIC** (l'utilisateur l'a rouvert pour la CI). Il avait été privé un moment : la CI macOS a alors refusé de démarrer (« payments failed / spending limit »). Ne pas le repasser en privé sans régler la facturation GitHub.
- **Dernière CI verte lue** : `[unit]` 859 tests sans échec (commit c36c183) et `[daily]` 888 tests sans échec (83e807d), AVANT la palette. Depuis la palette 12 couleurs (23a0598), **aucun `[unit]` ni `[check]` n'a été lu** : seul l'envoi `[interne]` a réussi (l'app compile en Release ; les tests ne sont pas compilés par ce tag). **Première chose à faire : un `[unit]`, lire le journal complet** (`gh run view <id> --log`, `grep "Test Case .* failed"`, `: error:`, `** TEST SUCCEEDED **`).
- Aucune démarche officielle n'est faite : pas d'immatriculation, pas de banque, pas de contrat Paid Apps, pas de produit dans App Store Connect, pas de soumission.

## 2. Ce qui a été fait dans cette longue session (chronologie utile)
1. **Pôle financier** (chantier 11) : `docs/finance/` (outils, structures Québec, Apple, état du lancement, modèle 36 mois, vérification, synthèse), moteur Python `finance/` (31 tests : `cd finance && python -m unittest discover -s tests`).
2. **Estimations par palier** (1 000 / 5 000 / 10 000 / 50 000 $/mois, individuelle ou société) : `docs/finance/estimation-revenus.md`, `finance/estimation_revenus.py`, `finance/optimisation.py` (376 combinaisons salaire + dividendes, sorties `finance/out/optimisation*.{csv,md}`), agent `comptable` (`.claude/agents/comptable.md`, lecture seule, non encore appelé). Bug corrigé : le surcoût de la société était compté deux fois (corrigé, commit 618e330).
3. **Chantier 12 (publication)** : feuille de route `docs/lancement/feuille-de-route.md`, audit de sécurité `audit-securite.md`, risques Apple `risques-apple.md`. Décision de l'utilisateur : **démarrer en entreprise individuelle** au Québec.
4. **Chantier 13** : (a) météo retirée totalement (écrans, widgets, service, position, clés Open-Meteo, textes, politique de confidentialité) avec décodage tolérant des anciennes données (`LossyList`, test `RemovedWeatherTests`) ; (b) un seul essai gratuit de 7 jours sur le mensuel et l'annuel (`Config/Ardane.storekit`, `PremiumStore.trialDays`, paywall) ; (c) gratuit = 3 widgets (README aligné, sans mention des styles) ; (d) renommage Tessera → Ardane.
5. **Palette de l'app** : deux tentatives écartées (accent Apple, puis thème dérivé de l'accent) puis **annulées sur demande de l'utilisateur** (« reprenons au build 284 »). Version finale = les 10 anciens styles remplacés par **12 couleurs** (Cobalt, Saphir, Bleu glacier, Aqua, Jade, Pistache, Olive, Ambre, Rubis, Rose, Orchidée, Améthyste), HEX exacts dans `Shared/Theme/AppStyle.swift`, fonds et cartes dérivés de la teinte (HSL), ancien choix converti en couleur proche (`AppStyleID.init(named:)`), grille à 4 colonnes. Test : `Tests/AppPaletteTests.swift`.
6. **Bug « Car » au lieu de « Auto »** (anglais) : « Auto » (voiture) et « Auto » (apparence automatique) partageaient une clé ; le sélecteur d'apparence et les styles de widget utilisent maintenant `tr("Auto", context: "mode")`.

## 3. Règles que l'utilisateur a données (à respecter)
- **À chaque modification terminée** : commit `[interne]` (build Premium sur son TestFlight) sans qu'il le redemande ; la vérification sans Premium (`[unit]` / `[daily]` / `[apps]`) vient après ; **`[testflight]` (version publique) seulement sur son accord explicite**. (Mémoire : `testflight-apres-chaque-modification`.)
- **Fin de chaque étape** : dire directement la prochaine action (ce qu'il doit faire lui-même, puis ce que Claude enchaîne). (Mémoire : `prochaine-action-apres-chaque-etape`.)
- **Ne toucher à rien d'autre que ce qui est demandé** (il a annulé deux fois un changement trop large). Ne pas élargir le périmètre, ne pas « améliorer » au passage.
- Garder « Tessera » seulement pour les essentiels : App Group `group.com.dakrsnyk.tessera`, schéma d'URL `tessera://`, clés internes `tessera.*`, dossier de données `Tessera/`, dépôt GitHub. Tout le reste s'appelle Ardane.
- Garde-fous : aucun paiement ni abonnement payant, aucune démarche officielle (REQ, banque, App Store Connect), aucun changement de workflow GitHub ou de secret sans accord explicite dans la conversation ; ne jamais afficher un secret.
- Un build `[interne]` n'est jamais soumis (Premium débloqué). `[interne]` et `[testflight]` jamais dans le même message.

## 4. Pièges techniques découverts
- **Un commit vide ne déclenche pas la CI** (`paths-ignore: **.md`). Pour lancer un run : modifier un fichier non `.md` (astuce : ajouter/retirer une espace en fin de la première ligne de `docs/references/.gitignore`).
- Un push **annule le run en cours** (`concurrency`). Ne pas empiler.
- `Tests/` : une classe qui appelle du code `@MainActor` doit être `@MainActor` (erreur déjà vue).
- Une erreur dans les heredocs shell avec apostrophes : écrire les scripts Python dans un fichier avec l'outil Write.
- Pipeline l10n : `extract` AVANT `merge` → `build` → `check` → `sync` (sinon les nouvelles clés ne sont pas vues). Traductions dans `l10n/parts/NN.<langue>.json` (dernier utilisé : 53).
- CI : l'étape de tests finit par `|| true`, le job est vert même si des tests échouent : toujours lire le journal complet. La vérification « Internal Only » peut expirer alors que l'envoi a réussi.
- Reconnaissance d'aliments (Vision) non mesurable en CI (simulateur) : le test saute.
- Les prints de tests ne sont pas visibles en CI : utiliser `XCTAttachment(string:)` avec `lifetime = .keepAlways`.

## 5. Ce qui reste à faire, par priorité
**Pour la session (Claude) :**
1. `[unit]` sur la palette 12 couleurs, lire le journal ; corriger. Puis `[daily]` (captures de l'onboarding et de Profil changées) ; relire 1 à 3 captures.
2. **Passe de tests en mode gratuit** (reportée par l'utilisateur, à faire avant toute version publique) : Réglages › Développeur › couper « Premium débloqué » ; limite de 3 widgets, paywall (« Essayer 7 jours gratuits »), restauration, aucune donnée effacée.
3. Chantier 12 : 12.C (corrections de sécurité restantes), 12.P (conformité : CGU propres ou EULA Apple ; politique de confidentialité à héberger sur URL publique stable ; réponses « App Privacy » ; relire la définition d'Apple de « collecter »), 12.E (pack entreprise individuelle), 12.A (pack App Store Connect : produits `com.dakrsnyk.ardane.premium.{monthly,yearly,lifetime}`, localisations FR/EN, fiche, mots-clés, classification, captures, notes de revue, test sandbox), 12.T (soumission, seulement sur accord), 12.M (lancement).
4. Corrections de sécurité de l'audit (voir `audit-securite.md`) : **constat 1** (IPA Debug avec Premium débloqué publiées dans les Releases GitHub d'un dépôt public : supprimer les Releases `build-*` et arrêter de publier les IPA, **après accord de l'utilisateur**) ; constats 5, 6, 9 = modifications du workflow (accord requis) ; constat 4 clés d'API (vides aujourd'hui ; ne jamais les mettre dans `pbxproj`).
5. Petits restes : localisation allemande de « Rose » = « Rosé » (à corriger si l'utilisateur le veut) ; `Config/App-Info.plist` garde des clés d'API vides (Open-Meteo supprimée) ; `CLAUDE.md` à jour ; `scripts/graph_map.py` à actualiser si l'architecture change.

**Pour l'utilisateur (Claude prépare, lui exécute) :**
1. Tester le build 292 sur l'iPhone : 12 couleurs en clair/sombre, fonds, sélecteur Auto/Clair/Sombre en anglais, paywall, 3 widgets gratuits, plus de météo, données conservées.
2. **Décisions en attente** : supprimer les Releases GitHub à Premium débloqué et arrêter leur publication ? · `familyShareable` (Partage familial) sur les 3 produits ? · nom du groupe d'abonnement (« Ardane Premium ») · CGU propres ou EULA Apple.
3. **Démarches** (dans cet ordre, rien n'est fait) : immatriculation de l'entreprise individuelle au Registraire (41 $) ; rendez-vous avec un CPA du Québec (TPS/TVQ sur les ventes App Store, W-8BEN, seuil d'incorporation, taux de petite entreprise) ; banque ; contrat Paid Apps et formulaires fiscaux dans App Store Connect ; création des produits ; soumission.
4. Hébergement public stable de la politique de confidentialité (`docs/legal/privacy.html`) à reporter dans `App/Premium/PremiumConfiguration.swift:14` et App Store Connect.

## 6. Repères rapides
- CI : `gh api "repos/Dakrsnyk/tessera/actions/runs?per_page=3"` ; journal : `gh run view <id> --log > /tmp/r.log`.
- Avant chaque commit : `python3 scripts/check_swift.py`. Commits terminés par `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- Agents (`.claude/agents/`) : ios-developer, ui-ux-designer, qa-tester, github-ci, security-reviewer (opus, lecture seule), research-architect, code-reviewer, comptable. Un seul agent écrit dans un fichier ; toute modification de code relue par code-reviewer.
- Données financières : tout est hypothèse ou estimation tant qu'un CPA du Québec n'a pas validé ; ne jamais appliquer de règle américaine ou britannique au Québec.
- Prix : mensuel 6,99 $, annuel 59,99 $, à vie 99,99 $ (USD, à confirmer dans le sélecteur d'App Store Connect) ; commission Apple 30 % la 1re année d'un abonné puis 15 %, ou 15 % avec le Small Business Program.
- Cartes du projet : `docs/PASSATION.md` (ancienne), `HANDOFF.md` (état de la localisation), `graphify-out/` (non versionné).

## 7. Décisions de l'utilisateur du 2026-10-29
- **Partage familial : NON** sur les 3 produits (`familyShareable: false` dans `Config/Ardane.storekit` ; à ne pas activer dans App Store Connect à la création des produits).
- **Conditions d'utilisation : l'EULA standard d'Apple** (lien déjà dans le paywall, `PremiumConfiguration.termsURL`). Des mentions « pas un avis médical » / « pas un conseil financier » existent déjà dans l'app.
- **Nom du groupe d'abonnement : « Ardane Premium »** (aligné avec le paywall).
- **Domaine acheté : `ardane.app`** (expire le 2027-10-29). Sert à héberger la politique de confidentialité, l'adresse de support et plus tard un courriel au domaine. Le TLD `.app` exige HTTPS (GitHub Pages le fournit). Plan : petit dépôt public séparé + GitHub Pages + domaine personnalisé (enregistrements DNS à créer par l'utilisateur chez son registraire). Création du dépôt public = publication : accord explicite de l'utilisateur requis.
- **Entreprise individuelle** : déclaration au Registraire remplie (nom « Ardane », CAE 2851, établissement au domicile) ; l'utilisateur paie le vendredi 2026-10-30 (délai de 10 jours après transmission) ; NEQ à noter après paiement.
