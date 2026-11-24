# Démonstrations d'exercices

Outil Python (numpy, Pillow) qui génère `App/Resources/ExerciseDemos.json` : pour chaque exercice
de `Shared/Domains/ExerciseLibrary.swift`, un personnage 3D aux proportions fixes posé sur son
matériel, échantillonné sur la répétition, avec ses phases nommées et ses angles de vue.

- `python3 export_all.py` : régénère le JSON et liste les problèmes détectés (os trop courts pour
  atteindre leur cible, membre dans le sol ou dans le matériel, genou plié à l'envers).
- `python3 build.py [ids…]` : planches de contrôle dans `out/` (3 phases par vue).
- `python3 collisions.py [ids…]` : pénétrations réelles entre le mannequin sculpté et le matériel (cm).
- `python3 occlusion.py [ids…] [--mode app|old] [--png]` : erreurs d'ordre de dessin entre le corps et le
  matériel (cm² peints dans le mauvais ordre, par rapport à un rendu coupé très fin). L'app n'a pas de
  tampon de profondeur : elle peint du plus loin au plus près des tranches du corps et des cellules de
  matériel (`DemoRenderer.drawSculpted`, `Sculpt.pieces`). Ce script reproduit ce tri ; tout changement
  du tri dans l'app se fait ici aussi.

Les exercices sont décrits par catégorie dans `ex_*.py` ; `engine.py` contient le corps et la
caméra, `gear.py` et `machines.py` le matériel, `poses.py`, `keys.py` et `cyclic.py` les postures
et mouvements communs.
