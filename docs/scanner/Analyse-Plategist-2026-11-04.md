---
tags: [ardane, scanner, chantier-22, analyse]
---

# Plategist face au scanner d'Ardane, et l'analyse de l'environnement de la photo (2026-11-04)

Étape 1 demandée par l'utilisateur : analyse seulement, rien n'est codé avant sa validation. Ce que fait Plategist vient uniquement de la vidéo décrite par l'utilisateur (non vérifié ailleurs). Ce que fait Ardane vient du code et de `Decision-technique.md`, `Recherche-bases-nutritionnelles.md`, `Recherche-profondeur-volume.md`.

## 1. Notre scanner aujourd'hui (build interne 323)
- **Code-barres** : VisionKit lit le code, Open Food Facts (API v3, en ligne) donne le produit ; un champ manquant reste inconnu, jamais 0.
- **Recherche texte** : table intégrée (207 aliments courants FR/EN, `FoodDatabase`) puis base embarquée `ardane-food.sqlite` (8 926 aliments : FCÉN 2026 de Santé Canada + USDA SR Legacy, une source par valeur, portions, densités, micronutriments) ; aliments perso, favoris, récents.
- **Photo** (nouveau dans le build 323) : sur l'iPhone, un segmenteur découpe l'assiette en zones, un classifieur nomme chaque zone (3 propositions, probabilités additionnées par aliment d'Ardane) ; Vision d'Apple reste le repli. Rien ne sort de l'iPhone.
- **Quantités** : encore la portion usuelle de l'aliment, ou la quantité habituelle de la personne apprise de ses corrections (`ScanLearning`) ; plats types avec composants (`DishTemplates`) ; mémoire des repas semblables (`MealMemory`). La photo ne mesure PAS encore les grammes : les fondations de calcul existent (`Shared/Domains/Scanner/` : ellipse de l'assiette, échelle, surface, volume, densité, incertitude log-normale) mais ne sont pas branchées.
- **Calcul** : toujours `valeur pour 100 g × grammes / 100` depuis la base (`FoodItem.nutrients`) ; aucun modèle ne produit de calories. Fourchette d'incertitude fixe (±5/30/40 %) par source.

Autrement dit, le principe « l'IA nomme et pèse, la base calcule » (« Looked up, not made up ») est **déjà le nôtre** (principe n° 2 de `Decision-technique.md` : aucun chiffre fabriqué). Ce qui nous manque : l'estimation des grammes par la photo, et l'écran qui rend tout ça visible.

## 2. Comparaison critère par critère
| Critère | Plategist (d'après la vidéo) | Ardane (aujourd'hui → prévu) |
|---|---|---|
| Calories et macros | base officielle (AUSNUT), jamais le modèle | base officielle (FCÉN + USDA), jamais le modèle : **égalité de principe** |
| Nommer les aliments | modèle de vision, très probablement un grand modèle en ligne : reconnaît presque tout (« green sauce ») | modèles embarqués : 77 % des 44 photos de test (un des 5 premiers bons), 85 % sur une assiette d'un seul aliment ; faibles sur desserts et plats composés. **Avantage Plategist** aujourd'hui |
| Estimer les grammes | le modèle « compare à une assiette de ~26 cm » ; précision non publiée | pas encore fait (portions usuelles) ; prévu : surface du masque × épaisseur × densité avec échelle par le contenant. **Avantage Plategist tant que ce n'est pas construit** |
| Même photo = même résultat | la base est stable, mais nom et grammes viennent d'un modèle génératif : rien ne garantit deux fois le même poids | modèles déterministes : même photo → exactement le même résultat ; erreurs explicables (surface, épaisseur, densité) |
| Produit emballé | non montré | code-barres + Open Food Facts : imbattable (valeurs de l'étiquette) |
| Assiette maison | oui | oui (photo) ; plus précis à terme grâce aux contenants enregistrés et aux corrections apprises |
| Restaurant | oui, questions sur l'huile | même besoin : questions de précision (à faire) |
| Meal prep / Tupperware | non montré | contenant + contenance standard (à faire) |
| Effort pour l'utilisateur | photo + 1 ou 2 questions | photo + confirmation des propositions ; + 1 question de contenant au début, puis plus rien avec les contenants enregistrés |
| Technique | API de vision en ligne + serveur | tout sur l'iPhone (Core ML) : hors ligne, 0 $ par photo, +54 Mo dans l'app |
| Coût par photo | non nul (API, serveur, à chaque scan) | 0 $ ; le coût est l'entraînement (Kaggle gratuit jusqu'ici) |
| Confidentialité | la photo part sur un serveur | rien ne sort de l'iPhone (argument de vente, et pas de mise à jour de la politique de confidentialité) |
| Données | AUSNUT 2023 (CC BY 3.0 AU, Australie) | FCÉN 2026 (Licence du gouvernement ouvert – Canada) + USDA (CC0) : adaptées au Québec, déjà embarquées et créditées |
| Offre payante | essai 14 jours puis abonnement | Premium déjà en place ; le scanner photo avec grammes et micronutriments peut en être le cœur, sans coût variable qui grignote la marge |

## 3. Recommandation : (c) combiner, en gardant notre moteur
On garde : code-barres en premier pour l'emballé (ton intuition est juste), reconnaissance et calcul sur l'iPhone, base canadienne, apprentissage des corrections. On prend chez eux le **produit**, pas la technique : leur force est de montrer clairement d'où vient chaque chiffre et de poser la bonne question au bon moment. Une API de vision en ligne n'est pas recommandée maintenant (coût à chaque photo, serveur pour cacher les clés, photo envoyée, politique de confidentialité à refaire) ; elle pourrait devenir plus tard une option « analyse avancée » désactivée par défaut, sur décision explicite.

Ordre de priorité proposé :
1. **Grammes par le contenant** (le plus gros gain) : contenant confirmé en un geste (assiette petite / moyenne / grande, bol, boîte 500 / 750 / 1 000 ml, verre, tasse) → échelle → surface de chaque masque → grammes avec fourchette. Comparé aux repas pesés (22.6) avant de devenir la valeur par défaut.
2. **Écran de résultat** : photo avec contours et étiquettes « nom · ~grammes », grammes modifiables, contenant affiché et modifiable (tout se recalcule), tuiles protéines / glucides / lipides, kcal et kJ, micronutriments clés en % de la valeur quotidienne (Premium).
3. **Questions de précision** à choix rapides (huile / beurre / sauce, mode de cuisson, taille du contenant) ; proposer une 2e photo quand l'incertitude est trop grande.
4. **Transparence** : « estimé à partir d'une recette type » pour un aliment absent de la base (nos `DishTemplates` le permettent : sauce bolognaise, salade César…), « estimations, pas des mesures », sources et licences sous le résultat.
5. **Contenants enregistrés** avec calibration simple.
6. Plus tard : détection automatique du contenant et des couverts, échelle par ARKit, LiDAR.

## 4. L'analyse de l'environnement de la photo
| Élément | Faisable de façon fiable aujourd'hui ? | Gain / effort | Version |
|---|---|---|---|
| Contenant choisi ou confirmé en un geste (taille, contenance) | oui | **gain maximal pour un effort minimal** : c'est l'échelle de toute la photo | V1 |
| Contenants enregistrés (« mon bol bleu », « mon Tupperware 750 ml ») + calibration une fois (mesure à la règle, ou photo avec une carte bancaire) | oui | très bon pour les repas répétés à la maison ; c'est là qu'on peut battre l'hypothèse fixe de Plategist | V1 (saisie) puis V2 (reconnaissance automatique du contenant enregistré par l'empreinte visuelle déjà utilisée par `MealMemory`) |
| Angle de prise de vue (ellipse du bord de l'assiette, gravité de l'iPhone) | oui pour une assiette ronde bien visible ; code déjà écrit (`ScannerGeometry`) | moyen ; corrige la surface vue de biais | V1 (assiette ronde) |
| Bol, assiette creuse : volume par profondeur et niveau de remplissage | partiel : la profondeur ne se voit pas ; question « plein / à moitié / un fond » + contenance | bon avec la question, mauvais sans | V1 (question) |
| Boîtes rectangulaires, compartiments | contenance + part de la surface occupée : oui ; profondeur cachée : par question | bon pour le meal prep | V1 (question), compartiments en V2 |
| Détection automatique du type de contenant | partielle : un modèle COCO (Apache 2.0) sait trouver bol, tasse, verre, bouteille, couverts, téléphone ; **pas d'« assiette »** dans COCO | moyen ; il faut l'entraîner ou l'ajuster et le mesurer | V2 |
| Objets de référence (fourchette, couteau, carte, canette) | détection : partielle (couverts dans COCO, carte non) ; une fourchette de biais est une mauvaise règle | faible à moyen, surtout en recoupement | V2 |
| Échelle par ARKit (plan de la table, mouvement de l'iPhone), même sans LiDAR | possible sur ton iPhone 11 Pro, mais demande une prise en direct de quelques secondes (pas une photo de la photothèque) ; précision à courte distance non sourcée | potentiellement fort, à mesurer | V2 expérimental |
| LiDAR (iPhone Pro 12 et suivants) | métrique mais peu résolu ; aucune étude sur des aliments ; **non vérifiable sur ton iPhone 11 Pro** | à mesurer par un possesseur d'iPhone Pro | V3 |
| Aliments cachés ou empilés (sauce sous la viande, riz au fond du bol) | non (invisible) | seulement par question | V1 (question) |
| Contexte maison / restaurant / fast-food | détection automatique peu fiable | une question « fait maison ou resto ? » oriente l'huile et la portion | V1 (question) ; automatique trop ambitieux |
| Fourchette et niveau de confiance par aliment | oui (loi log-normale déjà codée) ; les écarts-types initiaux sont des hypothèses tant qu'il n'y a pas de repas pesés | indispensable pour l'honnêteté | V1 |

Trop ambitieux pour une première version : reconnaître seul n'importe quel contenant et sa contenance, mesurer la profondeur d'un bol sur une seule photo, deviner le contexte restaurant, les aliments cachés, la photogrammétrie multi-vues.

**Avantage face à Plategist ?** Oui, mais seulement s'il est mesuré. Une hypothèse fixe de 26 cm se trompe dès qu'on mange dans un bol, une boîte ou une petite assiette ; le contenant confirmé ou enregistré corrige l'échelle de tout le repas. L'avantage se prouve sur les repas pesés (22.6) : sans ces mesures, ce n'est qu'un argument.

## 5. Base nutritionnelle de référence
- **FCÉN 2026 (Santé Canada) en pivot** : 5 993 aliments FR/EN, valeurs canadiennes (enrichissements propres au Canada), modes de préparation dans les libellés (cru, bouilli, rôti…), 173 nutriments. Licence du gouvernement ouvert – Canada 2.0 : usage commercial permis, **attribution obligatoire** (« Contient des renseignements licenciés en vertu de la Licence du gouvernement ouvert – Canada »), ne pas modifier les valeurs, ne pas se présenter comme version officielle ni approuvée par Santé Canada. Déjà embarquée et créditée.
- **USDA FoodData Central en complément** (SR Legacy déjà embarquée ; FNDDS pour les plats composés à ajouter) : CC0 (domaine public), crédit demandé. Noms anglais seulement : noms français à relire à la main.
- **CIQUAL (ANSES, France)** plus tard pour les plats français, si la licence 2025 est confirmée ; attention, ses glucides excluent les fibres (sémantique différente).
- **Valeurs quotidiennes** pour les % : tableau de Santé Canada (étiquetage nutritionnel), à vérifier ligne par ligne à l'implémentation.
- Règle déjà en place : ne jamais mélanger les valeurs de deux sources ; une valeur manquante est inconnue, jamais 0.

## 6. Risques
| Risque | Parade |
|---|---|
| Grammes peu fiables (épaisseur et densité mal connues) | fourchette affichée, mode expérimental, valeur par défaut seulement après mesure sur repas pesés |
| Contenant mal reconnu | toujours affiché et corrigeable en un geste, tout se recalcule |
| Aliment absent de la base | « recette type » marquée, ou proposition suivante ; jamais un chiffre inventé |
| Reconnaissance encore moyenne (desserts, plats composés) | 3 propositions, correction rapide, apprentissage des corrections, nouveaux entraînements |
| Trop de questions = abandon | au plus 1 ou 2 questions, seulement quand la réponse change beaucoup le total |
| Coût d'une API en ligne | évité (tout sur l'iPhone) ; option future seulement sur décision |
| Taille de l'app (+54 Mo) et temps de la première analyse | modèles int8, préchargement à l'ouverture du scanner ; mesurer sur l'iPhone 11 Pro |
| Mentions légales | « estimations, pas des mesures », « outil de référence, pas un avis médical », attributions FCÉN/USDA/MyFoodRepo ; aucune promesse de précision chiffrée avant mesure |
| Données de santé | rien ne sort de l'iPhone ; si une option en ligne arrive un jour : consentement, politique de confidentialité, manifeste |

## 7. Serveur central, données collectées, coût d'une IA en ligne (question du 2026-11-04)
- **Coût d'une analyse par API** (photo ramenée à 1 024 px ≈ 1 050 jetons d'image chez Claude, formule ⌈l/28⌉ × ⌈h/28⌉ ; + ~700 jetons de consignes ; ~800 jetons de sortie, réflexion comprise) : Claude Haiku 5.5 ≈ 0,06 ¢, Claude Sonnet 5.5 ≈ 1,2 ¢, Claude Opus 5.5 ≈ 2,3 ¢ par photo (tarifs de l'API au 2026-10-06 : 0,10 / 0,50 ; 2 / 10 ; 4 / 20 $ par million de jetons). Gemini 2.5 Flash-Lite / Flash : 0,10 / 0,40 et 0,30 / 2,50 $ par million selon des agrégateurs (page officielle de Google non vérifiée). Pour 1 000 utilisateurs actifs × 3 photos par jour : ≈ 54 $ par mois avec Haiku, ≈ 1 000 $ avec Sonnet, ≈ 2 000 $ avec Opus. Lot (batch) −50 % mais inutilisable en direct.
- **« 80 % juste sur toute l'assiette »** : aucune API ne le garantit et aucun banc d'essai publié ne mesure ce critère pour les modèles actuels. Étude de référence (Fridolfsson et al., Current Developments in Nutrition, 2025, 52 photos standardisées) : erreur absolue moyenne de 36 % sur le poids et de 36 % sur les kcal pour ChatGPT-4o et Claude 3.5 Sonnet, 64-65 % pour Gemini 1.5 Pro ; sous-estimation des grandes portions ; identification non mesurée car « difficile à définir » sur un plat mélangé. Les modèles de 2026 sont meilleurs, sans chiffre publié : à mesurer nous-mêmes (50 à 100 photos avec poids réels, quelques dollars d'API).
- **Serveur à faible coût** : Cloudflare Workers (gratuit jusqu'à 100 000 requêtes par jour, 5 $/mois au-delà pour 10 M de requêtes) comme relais qui garde la clé d'API hors de l'app, + base (Cloudflare D1 ou Supabase) + stockage des photos consenties (Cloudflare R2) + App Attest et quotas par compte. Coût fixe 0 à ~30 $/mois au début ; le coût variable est l'IA.
- **Ce que collectent les concurrents** (politiques publiques) : MyFitnessPal : journal alimentaire, poids, mensurations, activité, appareils connectés, identifiants d'appareil et publicitaires, adresse IP, cookies, partage avec des partenaires marketing et publicitaires. Cal AI : habitudes alimentaires, mensurations, objectifs, photos de progrès, identifiants d'appareil et publicitaires, IP, localisation générale (pays, code postal), données HealthKit sur autorisation ; partage avec prestataires, analytique, réseaux publicitaires ; usage pour l'apprentissage automatique ; fournisseur d'IA non nommé.
- **Recommandation** : hybride. Analyse sur l'iPhone par défaut (gratuite, instantanée, privée) ; analyse en ligne seulement quand la confiance locale est faible ou sur demande (Premium, avec quota) ; collecte minimale et facultative (photos et corrections avec consentement explicite, aucun identifiant publicitaire, aucune revente), qui sert à entraîner nos modèles. Obligations : Loi 25 (Québec) et LPRPDE, évaluation des facteurs relatifs à la vie privée avant tout transfert hors Québec, politique de confidentialité, étiquettes App Store ; la mention actuelle « Aucun compte, aucun suivi publicitaire » du profil devra changer si on centralise.
- **IA gratuites** (vérifié le 2026-11-04, sources secondaires pour les limites) : offre gratuite de l'API Gemini (quelques centaines à ~1 500 requêtes par jour et par modèle selon les sources ; le contenu envoyé peut servir à améliorer les produits de Google), 10 000 « neurones » gratuits par jour chez Cloudflare Workers AI (partagés entre les modèles, puis 0,011 $ les 1 000), modèles ouverts (Qwen3-VL, Apache 2.0 pour la plupart des tailles ; Gemma ; Llama 3.2 Vision) gratuits à télécharger mais à faire tourner sur un serveur à GPU payant, trop lourds pour l'iPhone 11 Pro. Utiles pour le test comparatif à coût nul, pas pour la production : limites, données réutilisées par le fournisseur, conditions changeantes. La seule IA gratuite à grande échelle est celle qui tourne sur l'iPhone.
