# Duel Sonnet contre Opus sur la phase 3 (création et production)

Fait le 2026-11-09 (chantier 25, phase 3). Script : `ardane-hq/tests/manual/duel-modeles.mjs`. Il suit le vrai chemin du QG : planification, consigne remplie avec les données de la base, mission `claude`, lecture des lignes `@@`, puis contrôle automatique. Chaque modèle a tourné dans sa propre instance temporaire du QG. Rien n'a été écrit dans `data/`.

## Ce qui a été comparé

- **Plume (fiche concept en 16 points)** : 2 idées que tu as retenues dans le Hub, « Même iPhone, autre écran » et « Pourquoi ton widget ne peut pas être transparent ».
- **Vérif (relecture)** : un concept piégé. Il passe le contrôle automatique du code, mais 7 erreurs y sont glissées exprès :
  - E1 : « know exactly what you ate », une précision promise ;
  - E2 : fréquence cardiaque, alors qu'Apple Santé n'est pas utilisé ;
  - E3 : photo de reçu, alors que Finances se remplit à la main ;
  - E4 : « Tap Set done from your Lock Screen », jamais vérifié sur l'iPhone ;
  - E5 : budget sur l'écran verrouillé, alors que les montants y sont masqués ;
  - E6 : « 100+ widgets » sans « With Premium » ;
  - E7 : « Loved by thousands of students », un faux témoignage.

## Résultats

| | Sonnet | Opus |
|---|---|---|
| Fiche concept, coût moyen | 0,15 $ | 0,33 $ (2,2 fois plus) |
| Fiche concept, durée moyenne | 28 s | 46 s |
| Fiches qui passent le contrôle automatique | 2 sur 2, aucune remarque | 2 sur 2, aucune remarque |
| Mécanique Create → widget → style → écran d'accueil | présente | présente |
| Relecture du concept piégé, coût | 0,14 $ | 0,29 $ |
| Erreurs piégées trouvées (vérifié à la main) | 7 sur 7 | 7 sur 7 |
| Relecture acceptée par le QG | oui | non, au premier essai (voir plus bas) |

Différences de qualité, lues à la main :

- **Opus** : il suit mieux la règle « question puis réponse » (« Bored of your home screen? » puis « Meet Ardane »). Ses raisons sont plus précises : 99 lignes dont 1 retirée, et le plan 6 qui frôle « sans déverrouiller ».
  - En contrepartie, il charge la carte de fin (« Coming soon to the App Store · Look With Premium »).
  - Il garde un titre français pour une vidéo anglaise.
  - Il écrit « no app can » sur la transparence, une affirmation trop large : d'autres apps imitent la transparence avec le fond d'écran.
- **Sonnet** : ses textes sont plus simples et plus sobres. Sa relecture contient une affirmation douteuse (« voiceKey null »), sans conséquence.
- **Les deux** : ils ont renvoyé un point de variété par excès de prudence, parce que l'historique des concepts n'était pas fourni à Vérif.

## Ce que le duel a révélé dans le code (corrigé)

- La relecture d'Opus a été refusée : ses raisons dépassaient 600 caractères. Désormais, les raisons sont coupées à 1 200 caractères au lieu d'être refusées, et un test le vérifie.
- Sans ce duel, le défaut serait passé inaperçu avec Sonnet, qui écrit plus court.

## Conclusion

- **Recommandation** : garder Sonnet pour Plume, Studio et Vérif. Opus coûte 2,2 fois plus et prend 1,6 fois plus de temps. Il n'attrape pas plus d'erreurs, et ses textes ne sont pas meilleurs pour une vidéo de 30 s.
- **Usage d'Opus** : comme le prévoit le plan, il reste réservé à la revue stratégique mensuelle.
- **Limite** : un seul passage par modèle, 2 concepts et 1 relecture. C'est trop peu pour mesurer la variance. Si Plume se met à produire des concepts renvoyés, refaire le duel sur 5 idées.
- **Coût total du duel** : 1,39 $ d'équivalent API, compris dans l'abonnement.
