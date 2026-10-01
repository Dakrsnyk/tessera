# Démonstrations d'exercices

Outil Python (numpy, Pillow) qui génère `App/Resources/ExerciseDemos.json` : pour chaque exercice
de `Shared/Domains/ExerciseLibrary.swift`, un personnage 3D aux proportions fixes posé sur son
matériel, échantillonné sur la répétition, avec ses phases nommées et ses angles de vue.

- `python3 export_all.py` : régénère le JSON et liste les problèmes détectés (os trop courts pour
  atteindre leur cible, membre dans le sol ou dans le matériel, genou plié à l'envers).
- `python3 build.py [ids…]` : planches de contrôle dans `out/` (3 phases par vue).

Les exercices sont décrits par catégorie dans `ex_*.py` ; `engine.py` contient le corps et la
caméra, `gear.py` et `machines.py` le matériel, `poses.py`, `keys.py` et `cyclic.py` les postures
et mouvements communs.
