# Essai colibri + LFM3-VL-2B (IA locale hors app), 2026-11-26

Règle : l'IA ne va jamais dans l'app ; c'est un outil de travail sur le PC du PDG. Essai demandé le 2026-11-25 (voir `Demandes.md`, entrée « colibri »). Aucun fichier de l'app touché ; seul ajout au dépôt : `scripts/ml/colibri_bench.py` et ce rapport.

## Verdict court

**Pas utile pour pré-étiqueter automatiquement.** Sur 100 photos, le modèle retrouve 40 à 42 % des aliments (IC 95 % 31-52 %) et 62 % de ses propositions sont fausses ; il ne localise rien (pas de masque) et ses grammes sont inutilisables. Au mieux : suggestion à relire pour des photos d'un seul aliment (8/8 sur les photos libres simples, 43 % sur 37 photos MyFoodRepo à un seul aliment), à 14 s par photo, donc sans gain réel face à un humain qui valide. Les modèles déjà entraînés (segmenteur + classifieur) restent meilleurs.

## Installation

| Élément | Valeur |
|---|---|
| Moteur | colibri v2.2.0, `colibri-v2.2.0-windows-x86_64.zip` (22 648 625 octets), GitHub JustVugg/colibri |
| SHA-256 du zip | `e0591f374bbfd95c181cf0212d494edd09660455d0677288232853f00ba063e1` = valeur de `SHA256SUMS.txt` (vérifié) |
| Extrait dans | `C:\Users\Etudiant\ardane-tools\colibri\bin\` (dossier neuf) |
| Python | 3.12.10, venv `...\colibri\venv` avec seulement `pillow` 13.0.0 et `numpy` 2.5.5 (le gateway n'utilise que la bibliothèque standard) |
| Modèle | `LFM3-VL-2B-Q4_K_M.gguf`, 1 099 627 808 o, SHA-256 `56dac2e1...f21eb` (complet : `56dac2e192ff0d9ab8507f4f1aeb4aed0463449bbbefaac79497f041c95f21eb`) |
| Tour de vision | `mmproj-LFM3-VL-2B-Q8_0.gguf`, 203 031 872 o, SHA-256 `c5c5b58d544a18da919172d2d0368090ea1a4a351b6feb7f8a326a264a5918ab` |
| Import | `coli import LFM3-VL-2B-Q4_K_M.gguf --out models\lfm3vl` (mode lien, le mmproj voisin est trouvé tout seul ; l'option `--mmproj` du README n'existe pas dans cette version) |
| Service | `coli serve --host 127.0.0.1 --port 8000`, arrière-plan, **arrêté à la fin** (`coli stop`, port vérifié fermé) |
| Licence | LFM Open License v1.0 (lue par le Chef : commercial permis sous 10 M$ de revenus annuels) ; colibri Apache-2.0. Aucune donnée ni poids dans le dépôt. |

La vision a marché du premier coup : « LFM3 vision tower (mmproj): 14 layers ... » dans le journal, réponses cohérentes avec l'image. Aucun échec moteur.

## Protocole

- Script : `scripts/ml/colibri_bench.py` (paramètres en ligne de commande, refuse tout hôte hors 127.0.0.1). Une requête par photo, sans conversation, température 0, raisonnement coupé (`enable_thinking: false`), consigne fixe : `Liste les aliments visibles, JSON strict : [{"aliment": "...", "grammes_estimes": n}]`.
- Photos réduites à 512 px (plus grand côté) avant envoi : sans cela la tour de vision sur CPU prenait 25 à 50 s par photo (essai sur 3 photos pleine taille). Un réglage de vitesse, pas de précision.
- 100 photos : les 44 photos libres de droits `Tests/Fixtures/FoodPhotos/` (vérité `manifest.json`) + 56 photos tirées au hasard (graine 0) du banc de test MyFoodRepo (1 000 photos, jamais utilisées pour entraîner, copiées en lecture seule dans `ardane-tools\colibri\bench\mfr_test`), vérité = classes COCO distinctes de la photo (noms anglais et français d'Ardane via `class_map.csv`).
- Appariement par NOM seulement (mots en commun, accents et pluriels ignorés), deux variantes : sans dictionnaire / avec petit dictionnaire anglais-français. Une correction de normalisation (« œ » = « oe ») a été faite après les 2 premières photos d'essai, avant la mesure ; aucun réglage choisi sur les résultats.
- Rappel = aliments de la vérité retrouvés / aliments de la vérité. Précision = propositions correctes / propositions. IC 95 % par bootstrap groupé par photo (2 000 tirages). Pour FoodPhotos : un aliment principal par photo (un des synonymes `expected`) ; `alternatives` comptent comme propositions correctes.
- Résultats bruts : `C:\Users\Etudiant\ardane-tools\colibri\bench\out\run1.json` (hors dépôt).

## Vitesse et mémoire (i5-1135G7, 4 coeurs / 8 fils, 16 Go, CPU seul, Vulkan non activé)

- Médiane 13,7 s par photo (moyenne 14,0 ; max 22,8 ; 100 photos en environ 23 min), dont l'essentiel dans la tour de vision sur CPU ; 229 jetons d'invite en médiane, 2,1 propositions par photo.
- RAM : processus `qwen36` 2,1 Go en régime, pic 2,26 Go ; gateway Python 0,06 Go. Aucun problème sur 16 Go.
- Sans réduction de la photo (825 morceaux d'image) : 25 à 52 s.

## Résultats (100 photos ; IC 95 % groupé par photo)

JSON illisible : 0/100.

| Ensemble | Photos | Rappel (sans dico) | Rappel (avec dico) | Précision (avec dico) |
|---|---|---|---|---|
| Tout | 100 | 55/138 = 39,9 % [31,1-48,9] | 58/138 = 42,0 % [33,5-51,5] | 81/214 = 37,9 % [31,1-45,2] |
| FoodPhotos | 44 | 21/44 = 47,7 % [31,8-63,6] | 23/44 = 52,3 % [36,4-68,2] | 45/112 = 40,2 % [31,1-51,5] |
| MyFoodRepo | 56 | 34/94 = 36,2 % [26,2-47,8] | 35/94 = 37,2 % [27,4-49,3] | 36/102 = 35,3 % [25,0-46,5] |

Par catégorie (rappel avec dico) : FoodPhotos « single » 8/8 ; « dessert » 4/7 ; « breakfast » 2/4 ; « composite » 8/20 (40 %) ; « plate » 1/5 (20 %). MyFoodRepo : 1 aliment 17/37 (46 %) ; 2 aliments 5/16 (31 %) ; 3 aliments et plus 13/41 (32 %). Les assiettes mélangées sont donc la famille faible, comme pour nos modèles.

Exemples réussis : pomme, pain, riz, frites, orange, fraise, pizza, omelette, sushi, taco (FoodPhotos) ; eau, muffin, prune, pistaches, croustilles, orange (MyFoodRepo).
Exemples ratés : hamburger -> « sandwich » ; poutine -> « pommes de terre frites » ; soupe -> « cassoulet » ; pancakes -> « pain » ; salade jardin -> « carottes, kiwi, pomme, tomates, banane » (invente) ; steak-frites -> pas de steak ; pomme-poire ; tasse de café pour de l'eau ou du lait ; « fromage » ajouté à répétition (hallucination par défaut) ; spaetzle -> « viande, pommes de terre, lait ».

Grammes : 205 valeurs, médiane 1, 195 sur 205 inférieures ou égales à 10 (le modèle recopie le gabarit « n »). Inutilisables ; aucune vérité en grammes dans ces deux bancs, donc pas de mesure d'erreur, mais l'ordre de grandeur est déjà faux.

## Comparaison avec nos chiffres (seulement ce qui est comparable)

Nos chiffres (Chantiers.md, segmenteur passage 2 + classifieur v4, 1 000 photos de test MyFoodRepo, seuil 0,30) : 73,9 % des aliments retrouvés par la découpe, Top-1 de nom 41,9 %, Top-3 58,5 %, précision 70,9 % ; classes exactes (498 classes MyFoodRepo), et la découpe localise chaque aliment (IoU).

- Pas comparable : les 73,9 % mesurent la LOCALISATION (zone avec IoU suffisant) ; colibri ne localise rien. Aucune comparaison ne doit se faire avec ce chiffre.
- Le plus proche : le Top-1 de nom (41,9 %) et la précision (70,9 %). Colibri : 37,2 % de rappel et 35,3 % de précision sur 56 photos MyFoodRepo, avec un appariement bien plus indulgent (un mot commun suffit, « fromage » = tout fromage) et 56 photos seulement (IC large : 27-49 %). Même avec cette indulgence, le rappel est au mieux comparable à notre Top-1 et la précision est à peu près moitié moindre. Pas de test apparié (McNemar) possible : les photos ne sont pas les mêmes (échantillon de 56 contre 1 000), donc je ne conclus pas « moins bon » au sens statistique, seulement « pas meilleur, et très en dessous en précision ».
- Les 44 photos FoodPhotos n'ont pas de chiffre équivalent dans nos rapports (banc différent).

## Pré-étiquetage : utile ou non ?

Non, en l'état :
1. Précision 35-40 % : environ 6 propositions sur 10 sont fausses, donc relecture de chaque photo, plus longue que d'étiqueter à la main avec la liste de classes.
2. Vocabulaire libre (français/anglais mélangés, « bois », « couvent », « bouteille de vin ») qu'il faut ramener à nos classes ; ce rapprochement est lui-même une source d'erreurs.
3. Pas de masques ni de boîtes : inutile pour le segmenteur, le goulot actuel côté données.
4. Grammes inutilisables ; 14 s par photo (CPU) ; hallucinations stables à température 0.
Limites de l'essai : 100 photos, échantillon MyFoodRepo de 56 (IC larges), appariement par mots indulgent et non validé à la main, une seule consigne (aucun essai d'autre consigne ni de réponse en anglais avec liste de classes imposée), photos réduites à 512 px, quantification Q4_K_M. Une consigne contrainte par notre liste de classes pourrait peut-être aider ; non essayé.

## Sécurité

Serveur lié à 127.0.0.1, arrêté ; téléchargements seulement depuis GitHub (release v2.2.0 et `pip` pour pillow/numpy) ; Python du banc lancé avec `-I` ; aucune photo du dépôt envoyée hors de la machine.
