# Département marketing intelligent d'Ardane : audit et plan

Demandé le 2026-11-08 (chantier 25). **Statut : plan en attente de ta validation.** Rien n'est construit, aucun compte n'est créé, aucune dépense n'est engagée.

Les prix et les règles des plateformes viennent de recherches web du 2026-11-08. Une partie n'a pas pu être lue sur les pages officielles : c'est signalé à chaque fois, et la section 19 en fait la liste.

## En bref

- **Une seule équipe, pas deux.** On étend le QG existant (`ardane-hq`) avec un module Marketing. Il a déjà les missions, les validations, le coffre des clés, les connecteurs et les plafonds de coût.
- **8 agents marketing** : 5 existent déjà, 3 sont nouveaux. Les 12 rôles demandés sont regroupés pour éviter les doublons.
- **Les agents proposent, le code exécute, tu décides.** La publication est faite par un module de code séparé, jamais par un agent. Il refuse tout contenu dont la version exacte n'a pas ton approbation.
- **Publication au départ** : Instagram, Facebook et Threads par leur API officielle. TikTok et YouTube en semi-automatique, car leurs API publient en privé tant que notre app développeur n'est pas auditée.
- **24/7** : trois niveaux. Je recommande de commencer par les tâches planifiées cloud de Claude, comprises dans l'abonnement, puis un petit serveur quand la publication automatique en dépendra.
- **Coût de fonctionnement** : environ 0 à 10 $ par mois au départ, 50 à 75 $ avec des plans vidéo IA, 150 à 250 $ en version internationale.
- **Publicité payante (boost)** : 0 $ avant la sortie sur l'App Store, puis un test de 100 à 150 $ CA. On n'augmente que si les chiffres réels le justifient (section 16).

## 1. Audit de l'existant

| Élément | État constaté le 2026-11-08 | Rôle dans le projet |
|---|---|---|
| QG `ardane-hq` | Serveur local Node 24 et SQLite, 159 tests. File de missions (2 agents à la fois), validations, coffre chiffré (DPAPI), journal d'évènements, centre documentaire, plafonds de 0,50 $ par mission et 5 $ par jour, reprise après redémarrage, accès iPhone par Tailscale | La base du système |
| Agents du QG | 15 agents réels : 8 techniques et 7 de gestion (Chef, COO, CMO, copywriter, acquisition, analyste marché, support). Postes vacants : community manager, media buyer, motion designer | 5 servent tels quels au marketing |
| Connecteurs | App Store Connect (ventes, abonnements, avis), Meta Ads et TikTok Ads (rapports des pubs payantes, lecture seule), GitHub | À compléter : publication et statistiques des publications |
| Chaîne de production | Remotion 4.0.534, gabarits de pubs (`scripts/ad4/tiktok`), voix Kokoro, sous-titres faster-whisper, FFmpeg, musique synthétisée, captures réelles de l'app par la CI | Produit déjà des pubs finales : 3 livrées aujourd'hui |
| Règles de marque | `knowledge/ardane.md` (QG), `Faits-verifies.md` et `Legendes-et-CTA.md` (campagne) | Source de vérité des agents |
| Automatisations | Aucune tâche planifiée, ni locale ni cloud (vérifié) | Tout est à créer |
| Matériel | Portable i5-1135G7, 16 Go de mémoire, carte MX450 2 Go, 12,8 Go libres sur le disque | Rendu Remotion : 1 à 2 minutes par pub. Pas de vidéo IA en local |
| Comptes sociaux d'Ardane | Inconnus | À me confirmer (section 18) |

Points faibles à corriger en premier :

- Le QG ne tourne que quand le PC est allumé et n'a pas de planificateur de missions.
- Ses connecteurs Meta et TikTok lisent seulement les pubs payantes : ni publication, ni statistiques des publications normales.
- Sa phase 4 (création d'agents par le Chef) est écrite mais pas enregistrée dans git.
- Le dépôt `ardane-hq` n'existe que sur ce PC, sans copie distante : une panne de disque le ferait perdre.
- Sa base de connaissances date du 2026-10-30 : elle cite encore l'achat à vie, retiré le 2026-11-08.
- L'app n'est pas encore sur l'App Store : aucun téléchargement ne peut être mesuré avant la sortie.
- Pas de Mac : les captures réelles de l'app dépendent de la CI (dépôt public ou minutes payantes).

## 2. Architecture recommandée

Le système reste un seul programme : le QG, avec un module Marketing en plus. Aucun second orchestrateur. Les outils n8n, Temporal et BullMQ ont déjà été évalués et écartés le 2026-10-30 (`docs/OUTILS.md` du QG).

Les 9 blocs, dans l'ordre du travail :

1. **Planificateur** (nouveau) : lance les missions récurrentes et rattrape au démarrage celles manquées pendant que le PC était éteint.
2. **Mémoire marketing** (nouvelles tables SQLite) : signaux, idées, concepts, versions de contenu, approbations, publications, mesures, concurrents, marchés, idées de fonctionnalités, dépenses. L'historique n'est jamais réécrit.
3. **Agents** : des missions `claude -p` comme aujourd'hui, avec les mêmes garde-fous.
4. **Atelier de production** (code) : l'agent de production écrit une fiche technique ; ce sont des scripts qui rendent la vidéo, la voix, la musique, les sous-titres et les formats.
5. **Contrôle qualité** : des vérifications automatiques (durée, taille, son, fichiers), puis un agent relecteur qui n'est jamais l'auteur.
6. **Centre de validation** : tu vois tout, tu décides.
7. **Module de publication** (code) : le seul à détenir les jetons de publication. Il vérifie l'approbation avant chaque envoi.
8. **Collecte des mesures** (code) : relève les statistiques à dates fixes, sans jamais modifier un relevé passé.
9. **Marketing Hub** : le tableau de bord, dans l'interface du QG, lisible sur l'iPhone.

## 3. Organisation des agents

Les 12 rôles demandés tiennent en 8 agents. Regrouper évite les doublons et réduit le coût.

| Rôle demandé | Agent | État |
|---|---|---|
| Coordination, anti-doublons | Claude Chef | existe |
| Marketing Director + Creative Strategist | Échos (CMO) | existe |
| Trend Researcher + Competitor Analyst + Product Researcher | Boussole (analyste marché) | existe, mission élargie |
| Scriptwriter + légendes des publications | Plume (copywriter) | existe, passe de Haiku à Sonnet |
| Video Producer + Graphic Designer | Studio (production) | nouveau |
| Localization Agent | Babel (localisation) | nouveau |
| Growth Analyst + calendrier des publications | Radar (acquisition) | existe |
| Quality Control Agent | Vérif (contrôle qualité) | nouveau |
| Social Media Manager | Pas un agent : Plume écrit, Radar propose les créneaux, le module de publication envoie | code |

Pour la faisabilité technique d'une idée de fonctionnalité, Boussole demande un avis à Archi, l'architecte technique existant, en lecture seule.

Fiche de chaque agent :

| Agent (modèle) | Mission | Outils autorisés | Ne peut pas | Livrables | Critères de qualité |
|---|---|---|---|---|---|
| Chef (Sonnet) | Découper, déléguer, vérifier, écrire la synthèse de la semaine | Lecture | Faire le travail des spécialistes, publier, dépenser | Plans, synthèse hebdomadaire | Aucune mission en double, chaque livrable relu |
| Échos (Sonnet) | Stratégie, choix des concepts, calendrier des campagnes | Lecture, web | Publier, dépenser, écrire dans le code | Fiches concept en 16 points, plan du mois | Concepts vraiment différents (grille de variété), objectif mesurable |
| Boussole (Haiku pour la collecte, Sonnet pour l'analyse) | Tendances, concurrents, marchés, besoins des utilisateurs, idées de fonctionnalités | Lecture, web | Scraper un site qui l'interdit, contacter quelqu'un, publier | Signaux datés avec leur source, fiches concurrent, fiches marché, fiches idée produit | Chaque fait porte son URL et sa date ; rien d'inventé |
| Plume (Sonnet) | Scripts, accroches, voix off, textes à l'écran, légendes, hashtags | Lecture | Promettre une fonction absente, publier | Script minuté, légendes par plateforme | Faits conformes à la base de connaissances, ton de la marque |
| Studio (Sonnet) | Transformer un script en fiche technique de rendu, lancer les scripts de production | Lecture, écriture dans `workspace/marketing/` seulement | Toucher au code d'Ardane, utiliser une image ou une musique sans droits, dépenser sans enveloppe approuvée | Vidéo 9:16 et ses déclinaisons, miniature, visuels | Vraies captures de l'app, aucun texte coupé, « With Premium » sur les fonctions Premium |
| Babel (Sonnet) | Adapter une campagne à une langue et un marché : accroches, expressions, voix, sous-titres | Lecture | Traduire mot à mot, changer un fait, publier | Version locale complète et sa retraduction de contrôle | Naturel pour le marché, mêmes faits que l'original |
| Radar (Haiku pour la collecte, Sonnet pour l'analyse) | Lire les mesures, comparer, proposer les créneaux et les prochains tests | Lecture | Modifier un relevé, lancer une pub payante | Rapport du lundi, base « ce qu'on sait » | Taille de l'échantillon affichée, corrélation et cause jamais confondues |
| Vérif (Sonnet) | Vérifier chaque contenu avant qu'il te soit présenté | Lecture seule | Corriger lui-même, approuver à ta place | Liste de contrôle signée : réussi, renvoyé, pourquoi | Aucun contenu présenté avec un fait faux ou un fichier défectueux |

**Remontée des problèmes**, la même pour tous : l'agent termine sa mission avec un statut « bloqué » et la raison. Le Chef tranche si c'est de son ressort ; sinon une alerte apparaît dans le Hub. Un agent ne contourne jamais un blocage.

Aucun agent Opus au quotidien. Opus sert une fois par mois, pour la revue stratégique.

## 4. Outils et API

| Besoin | Choix de départ, 0 $ | Option payante | Remarque |
|---|---|---|---|
| Montage et motion design | Remotion, déjà en place | Aucune | Gratuit jusqu'à 3 personnes (page de licence lue) |
| Vraies interfaces | Captures de la CI | Aucune | Jamais d'interface inventée |
| Voix off | Kokoro : anglais, espagnol, italien, portugais du Brésil, japonais ; une seule voix française ; pas d'allemand | ElevenLabs Starter, 6 $ par mois, avec licence commerciale | ElevenLabs devient utile pour le français et l'allemand |
| Musique | Synthèse maison (`music_tiktok.py`) | Aucune recommandée | Suno et Udio : litiges avec les maisons de disques non clos |
| Sous-titres | faster-whisper et Remotion | Aucune | Déjà installés |
| Traduction et adaptation | Agent Babel | Aucune | Une retraduction de contrôle à chaque version |
| Images | Aucune au départ | Flux par API, quelques centimes l'image | Seulement pour des décors, jamais pour une interface |
| Plans vidéo IA (lifestyle) | Aucun | Kling par fal.ai, environ 0,07 $ la seconde (lu) ; Veo 3.1 Fast, environ 0,10 à 0,12 $ (non vérifié) | L'écran du téléphone est toujours remplacé par une vraie capture |
| Avatars et « UGC » IA | Non | HeyGen, Arcads : chers | Déconseillé : risque de faux témoignage |
| Stockage des médias | Disque du PC | Cloudflare R2 : 10 Go gratuits, sortie gratuite (lu) | Instagram exige une URL publique pour le fichier à publier |
| Publication | API Graph de Meta ; outils officiels de TikTok et YouTube | Service tiers à 149 $ par mois : non | Détail en section 7 |
| Statistiques | API des plateformes, App Store Connect | Appfigures, environ 10 $ par mois, plus tard | Aucun SDK de suivi dans l'app |
| Veille | Recherche web des agents, API YouTube (gratuite), bibliothèque publicitaire de Meta | Aucune | TikTok Creative Center se consulte à la main : pas d'API, pas de scraping |
| Orchestration | File SQLite du QG | Aucune | Pas de second système |

## 5. De la recherche à la publication

| Étape | Qui | Automatique ? |
|---|---|---|
| 1. Signal : une tendance, une pub concurrente, un besoin | Boussole | Oui, planifié |
| 2. Idée notée sur 8 critères | Échos | Oui |
| 3. Concept : fiche en 16 points | Échos | Oui, pour les meilleures idées |
| 4. Script et textes | Plume | Oui |
| 5. Production : vidéo, voix, musique, formats | Studio et les scripts | Oui avec les outils gratuits ; avec ton enveloppe pour les outils payants |
| 6. Versions locales | Babel | Oui |
| 7. Contrôle qualité | Scripts, puis Vérif | Oui ; un échec renvoie à l'auteur |
| 8. Validation | **Toi** | Non, jamais |
| 9. Publication | Module de publication | Oui, après ton approbation |
| 10. Mesures et leçons | Collecte, puis Radar | Oui, à dates fixes |

**Notation des idées.** Chaque idée reçoit une note de 1 à 5 par critère, avec une phrase de justification : potentiel viral, potentiel d'acquisition, originalité, coût de production, difficulté, pertinence pour Ardane, public cible, plateforme recommandée. Ces notes sont des estimations, pas des prévisions. Elles deviennent plus fiables quand nos propres résultats existent.

**Fiche concept en 16 points**, comme demandé : titre, objectif, public, idée, accroche des premières secondes, script complet, découpage, mouvements de caméra, direction artistique, textes à l'écran, voix off, musique et ambiance, formats, outils, budget, indicateurs à suivre.

**Variété garantie.** Chaque concept est classé sur 5 axes : format (démonstration, storytelling, comparatif, avant-après, humour, éducatif, UGC, lifestyle), type d'accroche, mini-app, style visuel, structure du récit. Le système refuse un concept qui reprend la même combinaison qu'un des 10 derniers. Changer une couleur ou un texte ne compte pas comme un nouveau concept.

**Vérité du produit.** Un contenu ne montre que des fonctions présentes dans l'app, avec de vraies captures. Les fonctions Premium portent « With Premium ». La promesse reste « ARDANE — Your whole life. One place. ».

**Niveau d'autonomie, réglable.** Par défaut, les étapes 1 à 7 avancent seules, avec au plus 3 productions par semaine. Toute dépense passe par une enveloppe que tu approuves. Tu peux aussi exiger ton accord dès l'étape 3.

## 6. Validation humaine

Ce que tu vois pour chaque contenu : la vidéo et ses déclinaisons, les visuels, la légende et les hashtags, les versions par langue, la plateforme et le compte, la date proposée dans ton fuseau horaire, les raisons du choix, le résultat du contrôle qualité et le coût de production.

Tes 5 actions : approuver, refuser, demander une modification, demander une nouvelle version, mettre en attente.

Règles techniques :

- Une approbation porte sur **une version précise**. Le système calcule une empreinte (SHA-256) du fichier vidéo, de la légende, des hashtags, de la plateforme, du compte et de la date.
- Si un seul de ces éléments change, l'empreinte change et l'approbation tombe. Il faut approuver de nouveau.
- Le module de publication recalcule l'empreinte juste avant l'envoi. Si elle diffère, il n'envoie rien et t'alerte.
- Approuver exige ta session ouverte dans le Hub. Un agent ne peut pas approuver : c'est déjà une règle du QG.
- Un bouton « Tout arrêter » bloque toute publication, y compris celles déjà programmées.
- **Argent** : aucune pub payante, aucun changement de budget, aucun achat sans ton accord explicite. L'accord précise le montant, la durée et la plateforme.

**Résultats prévisionnels.** Tant qu'on a moins d'une dizaine de publications mesurées, le Hub affichera « pas de prévision fiable » plutôt qu'un chiffre inventé. Ensuite, il donnera une fourchette tirée de nos propres résultats.

## 7. Publication par plateforme

| Plateforme | Au départ | Ensuite | Ce qu'il faut de toi |
|---|---|---|---|
| Instagram (Reels, images) | API officielle sur ton propre compte | Accès avancé après la revue de Meta | Compte professionnel, Page Facebook liée, app développeur Meta |
| Facebook (Page) | API officielle | Idem | La Page |
| Threads | API officielle : publier sur son propre compte comme testeur est permis sans revue (lu) | Accès avancé | Compte Threads |
| TikTok | Semi-automatique : le Hub prépare le fichier, la légende et les hashtags ; tu publies depuis TikTok Studio en une minute | Publication directe après l'audit de TikTok | Compte TikTok, puis demande d'audit |
| YouTube Shorts | Semi-automatique, par YouTube Studio | API après l'audit de Google | Chaîne YouTube, puis demande d'audit |
| Pinterest | Plus tard | À étudier | Aucune action pour l'instant |
| LinkedIn | Non : peu utile pour une app grand public | Non prévu | Aucune action |

Pourquoi TikTok et YouTube ne sont pas automatiques au départ :

- TikTok : une app développeur non auditée ne publie qu'en privé (lu sur la page officielle).
- YouTube : une vidéo envoyée par un projet non vérifié est verrouillée en privé (lu sur la page d'aide).

Règles communes :

- Une publication n'est « réussie » qu'avec la confirmation de la plateforme : son identifiant et son état. En mode semi-automatique, tu colles le lien de la publication et le Hub le vérifie.
- Le calendrier gère les fuseaux horaires, les légendes, les hashtags, les miniatures, les sous-titres, les liens et les langues.
- En mode semi-automatique, les outils officiels (Meta Business Suite, TikTok Studio, YouTube Studio) programment eux-mêmes la sortie : la publication part à l'heure même si le PC est éteint.
- Aucune protection de plateforme n'est contournée. Je ne crée pas tes comptes et je ne saisis pas tes mots de passe : c'est toi qui le fais.

## 8. Mesures et apprentissage

- **Ce qu'on relève**, quand la plateforme le donne : vues, portée, impressions, durée moyenne de visionnage, rétention, complétion, mentions J'aime, commentaires, partages, enregistrements, clics, visites du profil.
- **Quand** : 1, 3, 7 et 28 jours après la publication. Chaque relevé est ajouté, jamais modifié.
- **Téléchargements** : Ardane promet « sans suivi », donc aucun SDK publicitaire. On utilise les liens de campagne d'App Store Connect, un par plateforme ou par vidéo. Apple donne des totaux anonymes, et seulement à partir de 5 personnes.
- **Ce qu'on ne pourra pas savoir** : qui a téléchargé, ni les téléchargements faits plus tard par une recherche dans l'App Store après avoir vu une vidéo.
- **Étiquettes** : chaque contenu porte son type d'accroche, son format, sa mini-app, son style, sa durée, son marché et son heure de sortie. Radar compare les groupes et affiche toujours le nombre de publications comparées.
- **Corrélation et cause** : une différence n'est retenue comme leçon que si elle se répète, ou si un test n'a changé qu'un seul élément.
- **Base de connaissances** : un fichier « ce qu'on sait, ce qu'on suppose », mis à jour chaque semaine, que tous les agents lisent.

## 9. Tableau de bord : Ardane Marketing Hub

Une maquette de l'écran de validation accompagne ce plan. Ses chiffres sont des exemples.

| Section | Contenu | D'où viennent les données |
|---|---|---|
| Overview | Campagnes en cours, contenus à valider, publications programmées, derniers résultats, alertes | Base du QG |
| Ideas Lab | Idées notées, tendances, opportunités de marché | Missions de Boussole et d'Échos |
| Creative Studio | Scripts, storyboards, visuels, vidéos, déclinaisons, langues | Fichiers produits et leurs versions |
| Approval Center | File d'attente, aperçu, 5 actions, historique des décisions | Table des approbations |
| Publishing | Calendrier, programmées, publiées, état des connexions, erreurs | Module de publication |
| Analytics | Résultats par plateforme, campagne et marché ; comparaisons | Relevés des plateformes et d'App Store Connect |
| Competitor Intelligence | Apps suivies, nouveautés, campagnes repérées | Fiches concurrent |
| Product Ideas | Fonctionnalités proposées, priorité, valeur commerciale | Fiches idée produit |
| AI Team | Agents, missions en cours, résultats, erreurs, coût | Journal des missions |

Une source non branchée affiche « non connecté », jamais un faux chiffre. C'est déjà la règle du tableau de bord du QG.

## 10. Fonctionnement continu

Planification proposée, réglable dans le Hub :

| Mission | Fréquence | Agent |
|---|---|---|
| Collecte des tendances | Chaque jour | Boussole (Haiku) |
| Veille des concurrents | Chaque semaine | Boussole |
| Nouvelles idées notées | 2 fois par semaine | Échos |
| Concepts complets | Chaque semaine, 2 ou 3 | Échos, puis Plume |
| Production | Dès qu'un concept est retenu, 3 par semaine au plus | Studio |
| Relevé des mesures | Chaque jour | Code |
| Rapport | Le lundi matin | Radar, puis Chef |
| Idées de fonctionnalités | Chaque mois | Boussole |
| Revue stratégique | Chaque mois | Échos (Opus) |

Trois niveaux de disponibilité :

| Niveau | Ce qui tourne quand le PC est éteint | Coût en plus |
|---|---|---|
| 0. PC seul | Rien. Au démarrage, le QG rattrape les missions manquées | 0 $ |
| 1. PC + tâches cloud de Claude | La veille, les idées et les rapports tournent chez Anthropic et déposent leurs résultats dans un dépôt privé. La production et la publication attendent le PC | 0 $ : compris dans l'abonnement, dans ses limites d'usage |
| 2. Petit serveur | Tout, sauf le rendu vidéo : planification, publication à l'heure, relevé des mesures | Environ 7 à 10 $ par mois de serveur, plus une clé API Claude payée à l'usage : 5 à 70 $ par mois selon le volume |

- **Ma recommandation** : niveau 1 pendant les phases 2 à 4. Le niveau 2 se décide à la phase 7, quand la publication automatique doit partir même PC éteint.
- **Tâches cloud** : elles sont en « aperçu de recherche » chez Anthropic. Leurs limites peuvent changer.
- **Abonnement sur un serveur** : les conditions d'Anthropic réservent la connexion par abonnement à un usage individuel ordinaire. Faire tourner des agents en continu sur un serveur avec l'abonnement est une zone grise. Sur un serveur, on utilise donc une clé API avec un plafond de dépense.
- **Rendu vidéo** : il reste sur le PC, ou passe par GitHub Actions sur des machines Linux. Ce dernier point est à mesurer.
- **Fiabilité** : base persistante, historique des missions, file de tâches, reprise après redémarrage et journal existent déjà dans le QG. On ajoute le planificateur et le suivi des dépenses.

## 11. Sécurité et contrôle

- **Clés** : dans le coffre chiffré du QG. Un agent ne voit jamais une clé.
- **Séparation** : les agents de recherche lisent et cherchent sur le web, rien d'autre. Les agents de création écrivent seulement dans le dossier marketing. Seul le module de publication peut publier.
- **Jetons limités** : un jeton pour publier, un autre en lecture seule pour les statistiques.
- **Contenu du web** : ce qu'un agent lit sur un site est une donnée, jamais un ordre. Ses résultats passent par un format fixe, puis par le contrôle qualité.
- **Dépenses** : plafond par mission, par jour et par mois. Les outils payants ne fonctionnent qu'avec une enveloppe mensuelle que tu as approuvée ; elle ne se renouvelle pas seule.
- **Journal** : chaque action est tracée, avec sa date et son auteur.
- **Arrêt d'urgence** : le bouton « Tout arrêter », et une procédure pour révoquer les jetons chez chaque plateforme.
- **Comptes sociaux** : double authentification activée par toi sur chacun.
- **Code d'Ardane** : aucun agent marketing ne peut modifier l'app.
- **Contenus IA** : un visuel ou une voix réaliste générés par IA portent l'étiquette exigée par la plateforme. Aucun faux témoignage : pas de « client » inventé présenté comme réel.

## 12. International

- **Départ** : anglais (États-Unis, Canada, Royaume-Uni) et français (Québec, France).
- **Ensuite**, dans l'ordre des langues déjà traduites dans l'app : espagnol, allemand, italien, portugais du Brésil, japonais.
- **Fiche par marché**, écrite par Boussole : habitudes, plateformes dominantes, concurrents locaux, ton, différences culturelles, arguments qui portent, règles locales.
- **Adaptation, pas traduction** : Babel réécrit les accroches, les expressions, les références, la voix off et les sous-titres. Les faits et l'identité restent identiques.
- **Limite honnête** : tu ne pourras pas juger toi-même un texte allemand ou japonais. Chaque version locale est donc livrée avec sa retraduction en français. Pour un marché important, une relecture par une personne dont c'est la langue reste préférable.
- **Union européenne** : la distribution de l'app y dépend de ta déclaration DSA, encore bloquée par le justificatif de domicile.

## 13. Idées de fonctionnalités

- Un espace séparé des campagnes : la section Product Ideas du Hub.
- Chaque fiche contient les 10 points demandés : besoin, problème résolu, fonctionnalité, fonctionnement, intérêt commercial, différenciation, complexité, coût, effet sur la rétention, priorité.
- Les agents marketing recommandent et documentent. Ils ne modifient jamais le code et ne lancent aucun développement.
- Une idée n'entre dans les demandes du projet (`docs/memoire/Demandes.md`) que si tu l'acceptes.

## 14. Rapports automatiques

- **Chaque lundi** : tendances, idées, concepts prêts, contenus à valider, publications, résultats, meilleures créations, marchés, idées de fonctionnalités, problèmes, coûts, prochaines actions.
- **Chaque mois** : bilan des campagnes, leçons retenues, budget dépensé, proposition pour le mois suivant.
- **Alertes immédiates** : une décision t'attend, une publication a échoué, un plafond de dépense approche.
- Chaque chiffre d'un rapport renvoie au relevé d'où il vient.

## 15. Coûts de fonctionnement

Par mois, hors publicité payante et hors abonnement Claude, que tu as déjà.

| Palier | Ce qu'il comprend | Coût estimé | Ce qu'il produit |
|---|---|---|---|
| Départ | Tout en local, tâches cloud de Claude, Remotion, Kokoro, musique maison, Cloudflare R2 gratuit, API gratuites | 0 à 10 $ | Des pubs en motion design à partir des vraies captures, en anglais et en français |
| Croissance | En plus : ElevenLabs Starter (6 $), plans vidéo IA (environ 40 $), petit serveur (7 à 10 $), clé API (5 à 15 $) | 50 à 75 $ | En plus : environ 70 plans IA de 8 secondes, soit 15 à 20 pubs lifestyle, et de meilleures voix |
| International | En plus : davantage de vidéo IA, ElevenLabs Creator (22 $), Appfigures (environ 10 $), clé API (30 à 70 $) | 150 à 250 $ | Plusieurs langues, plus de volume, veille chiffrée des concurrents |

- Construire le système ne coûte rien de plus : le travail se fait dans nos sessions Claude Code.
- Repère réel : le premier plan complet du Chef, avec délégation, a coûté l'équivalent de 0,89 $ le 2026-10-30.
- D'après ce repère, le programme de la section 10 représente l'équivalent de 12 à 20 $ par mois. C'est une estimation. Ce montant est couvert par l'abonnement quand les agents tournent sur le PC ou en tâches cloud.

## 16. Budget de publicité payante (boost)

Ce budget s'ajoute aux coûts de la section 15. Aucune dépense ne part sans ton accord explicite.

**Avant la sortie sur l'App Store : 0 $.** Une pub payante ne peut pas encore amener de téléchargements, et les règles des pubs « Coming soon » n'ont pas pu être vérifiées.

Les options et leurs minimums :

| Option | Minimum | À savoir |
|---|---|---|
| Instagram et Facebook, bouton « Booster » | Environ 1 $ par jour ; 5 $ par jour sur 6 jours conseillés (sources secondaires) | Booster depuis le site web, pas depuis l'app iPhone : en 2024, Meta a annoncé qu'un boost payé dans l'app iOS coûte 30 % de plus (frais d'Apple). Non revérifié pour 2026 |
| TikTok Promote, dans l'app | 3 à 5 $ par jour selon des blogs, non vérifié | Payé en pièces TikTok sur iPhone, avec des frais possibles |
| TikTok Ads Manager | 50 $ par jour par campagne, 20 $ par groupe d'annonces (page officielle) | Trop élevé pour commencer |
| Apple Ads (Search Ads) | Aucun minimum. Basic : paiement à l'installation. Advanced : paiement au toucher | La seule régie qui compte les installations sans SDK dans l'app |
| Google et YouTube, campagnes d'apps | Variable | Demandent un SDK dans l'app : à éviter |

Repères de coût. Ce sont des moyennes de marché de 2025, pas des promesses :

| Marché | Apple Ads, coût médian par installation (en $ US) |
|---|---|
| États-Unis | 4,06 |
| Royaume-Uni | 2,60 |
| Canada | 2,24 |
| Allemagne | 2,14 |
| France | 1,78 |
| Espagne | 1,43 |
| Italie | 1,32 |

- Sur Meta, une installation iOS d'app à abonnement coûte plutôt 6 à 9 $ US (blogs spécialisés).
- Sans SDK, Meta et TikTok optimisent les clics, pas les installations. On mesure les téléchargements avec les liens de campagne d'App Store Connect.
- Une app gratuite avec abonnement convertit environ 2,1 % des installations en abonnés payants (médiane RevenueCat 2026, lue par une source secondaire).

Les 3 paliers proposés, en dollars canadiens. J'ai calculé les fourchettes avec 3 à 8 $ CA par installation et 2 à 5 % d'abonnés ; ce sont des hypothèses, pas des résultats.

| Palier | Budget | Répartition | Installations attendues | Abonnés payants attendus |
|---|---|---|---|---|
| Test, à la sortie | 100 à 150 $ au total, sur 2 semaines | Apple Ads au Canada, environ 60 $ ; boost Instagram depuis le web, environ 40 $ ; TikTok Promote, 30 à 40 $ | 15 à 50 | 0 à 2 |
| Démarrage | 300 à 500 $ par mois | Apple Ads 50 %, Meta 30 %, TikTok 20 % | 40 à 165 | 1 à 8 |
| Croissance | 1 000 à 1 500 $ par mois | Apple Ads 50 %, Meta 25 %, TikTok 25 % | 125 à 500 | 3 à 25 |

**Ce que ces chiffres veulent dire.** Aux taux moyens du marché, la publicité payante ne se rembourse pas tout de suite :

- Exemple : une installation à 2,24 $ US et 2,1 % d'abonnés donnent environ 107 $ US dépensés par abonné payant.
- Un abonnement annuel rapporte environ 51 $ US après la commission d'Apple de 15 %, au prix de test de 59,99 $ US, qui n'est pas confirmé.
- Le palier Test sert donc à mesurer les vrais chiffres d'Ardane, pas à gagner de l'argent.

Règles de passage :

- Passer au palier Démarrage seulement si le coût par installation reste sous 5 $ CA et si App Store Connect montre des essais.
- Passer au palier Croissance seulement si un abonné rapporte plus qu'il ne coûte à acquérir.
- Booster de préférence une publication qui marche déjà bien sans payer : le boost amplifie, il ne sauve pas une vidéo faible.

Fonctionnement dans le Hub :

- Radar prépare une fiche de boost : la publication, le public visé, le budget, la durée, le lien de campagne.
- Tu l'approuves, puis tu lances toi-même le boost et le paiement. Le système ne détient aucun moyen de paiement.
- Les dépenses réelles remontent ensuite par les connecteurs Meta Ads et TikTok Ads, qui existent déjà en lecture seule.

## 17. Plan de déploiement

Chaque phase se termine par des tests réels et une note dans la mémoire du projet. Les phases 2 et 3 peuvent avancer en parallèle après la phase 1.

| Phase | Tâches | Agents et technologies | Coût | Dépend de | Réussie si |
|---|---|---|---|---|---|
| 1. Fondations | Enregistrer la phase 4 du QG ; copie de sauvegarde privée ; mettre à jour la base de connaissances ; tables marketing ; planificateur avec rattrapage ; 3 nouveaux profils et 4 ajustés ; squelette du Hub | Session principale, relecteur de code, auditeur sécurité ; Node, SQLite | 0 $ | Ta validation de ce plan | Les tests du QG passent ; une mission planifiée part seule et survit à un redémarrage ; le Hub n'affiche que du réel |
| 2. Veille et idées | Missions de tendances et de concurrents ; notation ; anti-doublons ; sections Ideas Lab, Competitor Intelligence et Product Ideas | Boussole, Échos ; recherche web, API YouTube | 0 $ | Phase 1 | Sur 2 semaines : au moins 10 idées notées par semaine, chacune avec ses sources ; moins de 10 % de doublons |
| 3. Création et production | Fiche concept ; scripts ; fiche technique vers Remotion ; voix, musique, sous-titres, formats, miniatures ; contrôle qualité | Plume, Studio, Vérif ; Remotion, Kokoro | 0 $, ou l'enveloppe choisie | Phase 1 | 3 concepts différents deviennent 3 vidéos finales sans retouche à la main ; le contrôle qualité attrape des erreurs glissées exprès |
| 4. Validation | Approval Center lisible sur iPhone ; versions et empreintes ; 5 actions ; historique | Session principale, auditeur sécurité | 0 $ | Phase 3 | Toute modification annule l'approbation ; des tests prouvent qu'un envoi sans approbation valide est impossible |
| 5. Publication | Tes comptes ; app Meta ; stockage R2 ; module pour Instagram, Facebook et Threads ; parcours semi-automatique pour TikTok et YouTube ; calendrier ; arrêt d'urgence | Module de publication ; API Graph | 0 $ | Phase 4 et tes comptes | Une vraie publication Instagram part après ton approbation, avec son identifiant confirmé ; l'arrêt d'urgence bloque une publication programmée |
| 6. Mesures et apprentissage | Relevés à 1, 3, 7 et 28 jours ; liens de campagne ; section Analytics ; rapport du lundi ; base « ce qu'on sait » | Radar ; API des plateformes, App Store Connect | 0 $ | Phase 5 ; la sortie sur l'App Store pour les téléchargements | Chaque publication a ses relevés, jamais modifiés ; chaque chiffre du rapport se retrouve dans un relevé |
| 7. Continu et international | Tâches cloud ; décision sur le serveur ; versions françaises, puis les autres langues ; fiches marché ; test de pub payante sur ton accord | Babel, tous ; tâches cloud de Claude, serveur éventuel | 0 à 250 $ par mois selon le palier | Phases 2 à 6 | Une semaine avec le PC souvent éteint sans tâche perdue ; une campagne approuvée et publiée en 2 langues ; coûts dans le budget choisi |

## 18. Décisions attendues

1. **Le plan** : valides-tu l'architecture (QG étendu, 8 agents, publication par un module séparé) ?
2. **Budget de fonctionnement** : départ (0 à 10 $ par mois), croissance (50 à 75 $) ou international (150 à 250 $) ?
3. **Tes comptes** : lesquels existent déjà pour Ardane parmi Instagram, la Page Facebook, Threads, TikTok et YouTube ?
4. **Sauvegarde du QG** : m'autorises-tu à créer un dépôt GitHub privé pour `ardane-hq` et à y pousser le code ?
5. **Publicité payante** : es-tu d'accord pour 0 $ avant la sortie, puis le palier Test de 100 à 150 $ CA, que tu approuveras le moment venu ?

## 19. Limites et incertitudes

- Je ne peux pas créer de comptes, saisir de mots de passe ni payer à ta place.
- Les revues des plateformes (Meta, TikTok, Google) ont des délais inconnus et peuvent être refusées.
- Une note de « potentiel viral » reste une estimation. Aucun système ne garantit la viralité.
- La qualité des vidéos IA avec des personnes (mains, visage constant d'un plan à l'autre) n'a pas été vérifiée : il faut un test payant d'environ 20 $ avant d'y compter.
- Non vérifié sur une page officielle : les statistiques exactes offertes par chaque API, la publication sur son propre compte Instagram sans revue, les prix de Veo, le minimum de TikTok Promote, les frais d'Apple sur les boosts en 2026, les règles des pubs avant la sortie de l'app, les règles sur les allégations santé et finance, les obligations d'annonceur au Canada et dans l'Union européenne.
- Ces points seront revérifiés au début de la phase qui en dépend, avant d'écrire le code.

## Sources principales

- TikTok : `developers.tiktok.com/doc/content-posting-api-get-started`, `developers.tiktok.com/doc/content-sharing-guidelines`, `ads.tiktok.com/help/article/budget`
- Meta : `developers.facebook.com/docs/instagram-platform/content-publishing`, `developers.facebook.com/docs/threads/posts`, `developers.facebook.com/docs/graph-api/reference/ads_archive/`
- YouTube : `developers.google.com/youtube/v3/determine_quota_cost`, `support.google.com/youtube/answer/7300965`
- Apple : `developer.apple.com/help/app-store-connect-analytics/acquisition/campaign-links/`, `ads.apple.com/app-store/help/apple-ads-basic/0039-promote-an-app-with-basic`
- Anthropic : `code.claude.com/docs/en/routines`, `code.claude.com/docs/en/legal-and-compliance`, `claude.com/pricing`
- Outils : `fal.ai/pricing`, `elevenlabs.io/pricing`, `remotion.pro/license`, `developers.cloudflare.com/r2/pricing/`, `huggingface.co/hexgrad/Kokoro-82M`
- Repères publicitaires (sources secondaires) : `apptweak.com/en/aso-blog/apple-ads-benchmarks`, `revenuecat.com/state-of-subscription-apps-2026/`, `rocketshiphq.com/meta-cost-benchmarks-mobile-app-installs/`
