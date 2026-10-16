---
tags: [ardane, memoire]
---

# Décisions

Les choix déjà faits, avec leur date. Retour : [[Memoire]]

## Produit
- 2026-10-08 : iPad et Apple Watch abandonnés. Chinois et coréen retirés (traductions de mauvaise qualité, récupérables avant 5ee621c) ; langues : fr, en, es, de, it, pt-BR, ja.
- 2026-10-09 : photo du repas retirée de [[Nutrition]] (récupérable avant 54d2373) ; le scan de code-barres garde son carré de visée.
- 2026-10-11 : l'app s'appelle Ardane. Projet, cibles, module, identifiants, App Group et dossier de données gardent « Tessera » (rien n'est perdu).
- 2026-10-15 : mini-app Eau retirée (`WidgetKind.retired`, `AppModel.removeRetiredFeatures`) ; les autres données restent.
- 2026-10-15 : besoins nutritionnels calculés par défaut (Mifflin-St Jeor, NASEM, OMS, Santé Canada) ; une valeur modifiée à la main devient « Personnalisé » (`customTargets`) et n'est plus jamais recalculée.
- 2026-10-15 (révisé le soir) : Premium = statistiques détaillées de chaque mini-app, toute la bibliothèque d'exercices et les données de chaque exercice (plus d'exercices offerts), tous les nutriments sauf calories/protéines/glucides/lipides, l'icône de l'app. Gratuit : séances, exercices écrits à la main, séries notées. Rien n'est effacé.
- 2026-10-15 : Business ← Stripe par une clé restreinte « Balance transactions : Read » gardée dans le trousseau, sans serveur ; jamais de clé secrète `sk_` ni de mot de passe. Shopify, QuickBooks et Stripe Connect attendent un serveur OAuth (`docs/integrations-business.md`).
- 2026-10-15 : galerie de l'écran d'accueil réduite au widget « Mes widgets » (`tessera.quick`, ne propose que les widgets créés) ; écran verrouillé : l'essentiel de chaque mini-app.
- 2026-10-15 : l'heure suit toujours le fuseau de l'appareil (`Fmt.timeZone = .autoupdatingCurrent`), jamais la langue ; une heure d'emploi du temps est en minutes depuis minuit, recalculée pour chaque jour.
- Le déverrouillage premium DEBUG n'est jamais actif en Release ([[Premium-et-abonnements]], vérifié par `scripts/check_swift.py`).

## Publicité
- Une seule publicité exceptionnelle plutôt que plusieurs ordinaires ; seulement des fonctionnalités qui existent vraiment, montrées avec de vrais éléments de l'app.
- Direction retenue : [[Concept-THE-OPENING]] (la fente du « A » d'Ardane comme lumière et comme transition).
- Les enregistrements vidéo du simulateur ne tournent qu'à 8–14 i/s : le mouvement est reconstruit à 60 i/s à partir d'images fixes réelles.
- 2026-10-11 : la campagne se fait en local sur le PC Windows (les rendus survivent à la session) ; outils hors du dépôt dans `~/ardane-tools`.
- 2026-10-11 : moteur du film = Remotion (comme le prévoit le concept), plutôt que CSS 3D + Playwright fait main : chronologie à l'image près, rendu parallèle, mixage audio, aperçu dans le navigateur. Licence gratuite jusqu'à 3 personnes.
- 2026-10-11 : pas de produit (pot de yaourt) dans la pub : « les gens savent comment ça marche ». Le scan est représenté par un code-barres seul (EAN-13 fictif, préfixe 200), imprimé sur une étiquette blanche (`Barcode.tsx`), qui vient se poser dans le carré de visée du scanner.
- 2026-10-11 : priorités du message pub : 1) l'utilité, 2) **personnaliser ses widgets à son goût** (Studio : 16 thèmes, 57 styles, 14 palettes), présent dans chaque film. Le film principal passe à 60 s (univers 10 → 6 s, Studio 6 s).
- 2026-10-11 : chaque film s'ouvre sur une accroche dite et écrite (« Organize your life / training / meals with Ardane », « Your phone. Your style. Meet Ardane. »), le texte s'ouvrant depuis la ligne de lumière.
- Voix : Kokoro-82M (licence Apache-2.0). Musique : Mixkit (licence gratuite, publicité en ligne permise). Runway n'est pas utilisé : la version gratuite (125 crédits une seule fois) met un filigrane.

## Confidentialité
- 2026-10-11 : politique v2.0 (source `docs/legal/privacy.html`, publiée sur l'artifact de `PremiumConfiguration.privacyURL`, texte français copié dans `PRIVACY.md`). Responsable : le développeur indépendant établi au Québec (à remplacer par l'entreprise Ardane quand elle existera) ; contact `support.ardane@gmail.com` (`AppInfo.supportEmail`). Engagements à tenir : réponse sous 30 jours, courriels gardés au plus 24 mois, avis dans l'app avant un changement important. Toute nouvelle donnée ou nouveau service externe doit être ajouté à la politique et au manifeste de confidentialité.
- 2026-10-12 : identifiant de l'app `com.dakrsnyk.ardane` (widgets `.widgets`, tests `.tests`/`.uitests`) au lieu de `com.dakrsnyk.tessera` : iOS 18.1+ gardait l'icône Tessera des notifications par identifiant, même après réinstallation. Gardés : App Group `group.com.dakrsnyk.tessera`, produits in-app `com.dakrsnyk.tessera.premium…`, schéma `tessera://`, sous-système de log des widgets.
- 2026-10-15 : installation par TestFlight, signée par la CI avec un certificat Apple Distribution fait une fois (CSR par OpenSSL sous Windows) et deux profils App Store gardés en secrets GitHub ; pas de signature automatique en CI (chaque machine neuve créerait un certificat).

## Outillage
- La CI est pilotée par des tags dans le message de commit (voir `CLAUDE.md`) ; `[check]` d'abord, finir une série par `[unit]` (tests) puis `[testflight]` (version sur l'iPhone par TestFlight, depuis le 2026-10-15).
- 2026-10-12 : la carte Obsidian (`obsidian_map.py`, canvases, notes `modules/` et `code/`) est remplacée par la carte graphify (`scripts/graph_map.py`, demande de l'utilisateur) : un nœud par fichier relié par les vrais appels (graphify, analyse locale), 8 grandes catégories (ou les modules), réglages façon Obsidian (Filtres, Groupes, Affichage, Forces, Animer), mise à jour après chaque commit. Les descriptions des modules sont gardées dans `MODULES`. La mémoire passe de `docs/obsidian/memoire/` à `docs/memoire/`.
- 2026-10-15 : la photo de fond d'une citation est la 1re photo de `options.photos` (AppModel gère déjà copie et suppression) ; texte clair gardé, sinon blanc ; voile 0,15–0,75.
- 2026-10-15 : « Mes widgets » : choix par défaut `defaultResult()` = dernier widget de chaque taille, enregistré à l'ajout (`MyWidgetsChoice`, « Choisi à l'ajout ») : un widget posé ne change plus.
- 2026-10-16 : pour tester Premium avant que le contrat payant soit actif : tag CI `[interne]` (Premium débloqué, envoi « TestFlight Internal Only », réservé aux testeurs internes). Pas de déblocage « si sandbox » dans le code : App Review teste aussi en sandbox.
- 2026-10-16 : conversion Business au taux BCE du jour de chaque opération (série Frankfurter, une requête par devise), jour ouvrable précédent jusqu'à 7 jours, arrondi au cent, montant d'origine gardé (`ForeignAmount`, effacé si on retape le montant) ; sans taux, rien n'est importé sans le choix explicite de la personne, et seules les devises sans taux restent brutes.
- 2026-10-16 : variation des cours : signe et flèche selon le chiffre arrondi, avec la période (24 h pour les cryptos, jour depuis la clôture pour les actions) ; cache 5 min, rechargement 15 min ; heure du cours en moyen et grand ; l'app recharge les widgets après avoir lu les cours.
- 2026-10-16 : gratuit = 3 widgets ; photos et citations illimitées (une fusion ne compte que si une de ses parties compte) ; un pack ou un accueil enregistre ceux qui rentrent ; ceux qui en ont déjà plus gardent tout (la limite ne joue qu'à la création).
- 2026-10-16 : records de Progression triés de A à Z (plus par force), index alphabétique à gauche ; en japonais, lignes de kana.
- 2026-10-16 : Clair/Teinté : style blanc en hiérarchie d'opacités (texte 1, secondaire 0,6, formes sous texte 0,22–0,35 + contour 0,55, cartes 0,12) ; photos en couleur ; photo derrière une citation désaturée à 0,35 ; le fond du style cède au verre d'iOS.
