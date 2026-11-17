# Compte rendu de la mission de nuit du 2026-11-17

Mission : « Missions prioritaires de la nuit et évolution fonctionnelle » (6 heures au plus). Détail technique : Chantier 37 de `docs/memoire/Chantiers.md` ; décisions : `docs/memoire/Decisions.md` (2026-11-17). Rien n'est dit « fait » ici sans preuve de la CI ; ce qui ne se vérifie que sur l'iPhone est dit tel quel.

## Versions envoyées sur TestFlight (internes, Premium débloqué)
- **Build 448** : Créer, Mon quotidien, Études, objectif partagé, inscription, tutoriel, sécurité.
- **Build 450** : la même, plus le scanner d'horaires élargi et les corrections des échanges entre mini-apps. C'est celle à essayer.
- Aucune version publique `[testflight]` n'a été envoyée.

## Missions prioritaires
1. **CI de Finance.** Cause : le commit de tests ne modifiait qu'un fichier `.md`, et la CI ignore les envois faits seulement de `.md` ; elle n'avait donc jamais démarré. Relancée sans toucher au code de Finance. Résultat (run 445) : 1 466 tests réussis, 0 échec. L'étape apparaissait quand même « en échec » parce qu'elle dépassait sa limite de 55 minutes juste après la fin des tests : limite portée à 85 minutes. `check_swift.py` prévient maintenant quand un commit ne contient que des `.md`.
2. **Créer « taille d'abord ».** La taille est le choix de la personne : ajouter, remplacer ou déplacer un widget dans l'Atelier ne la change plus. Petit = 1 widget, Moyen = 2, Grand = 4, avec une seule source pour ces limites, partagée par Créer et l'Atelier.
3. **Tests.** Les tests de la combinaison ont été réécrits pour la nouvelle règle ; 28 tests nouveaux du parcours (Petit, Moyen, Grand, limites, places, widget final, retour) ; tests d'interface du « + ». Au run 449 : tous réussis.
4. **Bouton « + ».** Avant, il agrandissait le widget tout seul (un 2e widget passait un Petit en Moyen, un 3e en Grand). Maintenant il ajoute dans la taille choisie, et quand elle est pleine il dit pourquoi et où changer la taille. Pas de doublon ; la liste et l'aperçu suivent. Vu sur capture.
5. **Anciens écrans.** `CreateStartView` et `SpacesView` supprimés après vérification qu'ils ne servaient plus ; ce qui servait encore dans ces fichiers est gardé dans `SpaceCatalog.swift` et `SpaceView.swift` ; plus aucun chemin ne mène à l'ancien parcours.
6. **Relecture par un autre agent.** Aucun point bloquant ; trois vérifications de test trop faibles renforcées.
7. **Validation.** `[check]` : vert (run 446). `[studio]` (run 447) : 1 550 tests réussis, 4 échecs, tous dus à des tests (deux tests partaient encore d'un petit widget, un test comptait des lignes sur le mauvais chapitre, un toucher arrivé trop tôt) ; corrigés et rejoués au run 449 : tous réussis. `[interne]` : Build 448, puis Build 450.
8. **Sécurité.** Audit complet : aucun secret dans le dépôt ni dans son historique ; 0 problème critique, 0 élevé, 2 moyens, 10 faibles. Corrigé : clés retirées de la machine de build dès qu'elles ont servi, envoi signé qui ne peut plus être annulé par un envoi ordinaire, ancienne version de test avec Premium plus fabriquée, contrôles automatiques renforcés, images trop grandes refusées avant décodage, photos orphelines supprimées après une restauration. Résumé : `docs/audits/securite-2026-11-17.md`.
9. **Dépôt GitHub.** Sa visibilité n'a pas été modifiée : il est toujours public. L'historique de `ci-report` n'a pas été réécrit.

## Évolutions fonctionnelles
10. **Planning et Études.** Dans Planning, les lignes « Horaire de la semaine », « Études », « Semaine », « Mois » et « Concentration » sont retirées ; tout le reste est gardé. Études est une mini-app à part : Mes cours (ajout, modification, suppression, détail), Mes examens (date, heure, cours), Concentration (la même fonction, déplacée), organisation étudiante (chrono, horaire, devoirs, notes, révisions, import d'horaire). Un cours ajouté deux fois, à la main ou par le scanner, n'est créé qu'une fois. Deux centres d'intérêt distincts ; Planning est sur l'accueil pour tous.
11. **Fitness et Nutrition.** Un seul objectif pour les deux. Le calcul suit l'objectif réel (perte de poids, sèche, maintien, prise de muscle, prise de masse, recomposition, performance) ; chiffres et sources dans `docs/nutrition-objectif-partage-2026-11-17.md`. Les valeurs réglées à la main ne sont jamais écrasées : Nutrition propose le nouveau calcul. La question grossesse / allaitement est posée quel que soit l'endroit où l'objectif est choisi. « Ton activité » ne s'affiche plus « Your business » en anglais.
12. **Inscription.** « Bonjour Mathys » est sur la 2e étape. Une information déjà donnée (objectif, âge, taille, poids, activité) n'est plus redemandée : elle s'affiche avec « Modifier ». Mon quotidien : Nutrition, Fitness, Planning, Habitudes, Top 3, puis les autres en plus petit, pour tous les comptes.
13. **Scanner d'horaires.** En plus des cours : plannings de travail et rendez-vous datés ; type et date corrigeables avant l'ajout ; une date ou une heure illisible donne une ligne décochée et signalée, jamais une valeur inventée. Mesure avec le vrai moteur de lecture d'Apple sur des documents fabriqués pour le test : horaire de travail 4 sur 4, tableau d'employés 11 sur 11, rendez-vous datés 3 sur 3, horaires de cours 167 sur 169. Aucun modèle n'a été réentraîné : ce sont des règles de lecture.
14. **Tutoriel.** 11 étapes dans le nouvel ordre, prénom à l'étape 2, contour jamais coupé. Sur les captures, trois étapes (Planning, Store, Mes widgets) n'avaient aucun élément mis en avant et la bulle le cachait : corrigé ensuite, vérification en cours (voir « Encore à vérifier »).
15. **Tests.** Dernier passage complet (run 449) : 1 631 tests réussis, 1 échec. L'échec venait de la préparation d'un test (l'ordre des cartes laissé par un test précédent), pas de l'app ; corrigé. Une dizaine de fichiers de tests nouveaux : ordre de Mon quotidien, Études, objectif partagé, scénarios (nouveau compte, profil complet, changement d'objectif, intérêts choisis, Planning sans Études, compte existant), scanner, échanges entre mini-apps, tutoriel, sécurité.

## Ce qui reste
16. **Problèmes encore présents.**
    - Tutoriel : au Store et à Mes widgets, l'élément est maintenant visible au-dessus de la bulle mais sans contour.
    - Scanner : les quarts de nuit sont proposés décochés et arrêtés à minuit ; un tableau d'employés avec les jours en lignes n'est pas reconnu ; il manque de vrais documents pour régler les seuils.
    - Les sessions de concentration ne comptent pas dans le temps d'étude de la semaine.
    - Les calories dépensées en séance ne s'ajoutent pas aux calories restantes de Nutrition (choix à faire : le niveau d'activité les compte déjà).
17. **Non terminé.**
    - Sécurité, à faire par le propriétaire : voir `docs/audits/securite-2026-11-17.md`.
    - Vérification sur l'iPhone de tout ce que la CI ne voit pas.
18. **Compilation et stabilité.** L'app compile (simulateur, iPhone et version signée). Aucun test logique en échec au dernier passage complet. Les comptes existants sont relus sans perte (tests sur d'anciens fichiers).

## Décisions prises pendant la nuit, à confirmer
- Top 3 présent par défaut pour tous.
- L'ancien centre d'intérêt « Productivité » s'appelle « Planning ».
- Le prénom est déplacé à la 2e étape dans l'inscription et dans le tutoriel.
- Chiffres du calcul par objectif (sèche −20 %, prise de masse +15 % plafonnée à 500 kcal) : estimations sourcées, à faire relire par un professionnel avant la version publique.
