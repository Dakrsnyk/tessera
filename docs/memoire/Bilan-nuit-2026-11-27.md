# Bilan de la nuit du 2026-11-27 (en cours de rédaction)

Plan validé par le PDG avant de dormir : finir les widgets (graphiques expliqués, place comblée par le sujet, plus de lignes coupées), vérifier tous les widgets, remettre les tests au vert, puis faire avancer Ardane (panel de 1000 clients avec les pubs du QG, fiche App Store, audits). Budget : 25 % de la limite hebdomadaire au plus.

## Livré avant la nuit (builds internes)
- 620 : lisibilité vérifiée sur 95 widgets × 10 dispositions, Studio sans étape « Contenu », Store « Enregistrer le style / Personnaliser ».
- 621 : contenu des widgets selon la taille et fidèle au sujet (envoyé ; la vérification Apple a dépassé 25 min, la CI l'a marqué en échec, le build existe).
- 622 : sécurité Premium (aperçus Premium en données d'exemple, record/régularité/« Fait » de Série en Premium, fond libre des citations en Premium, restauration plafonnée, horloge reculée), « Commencer » gratuit sur Séance du jour, Live Activity gratuite.
- 623 : petit widget « Bras » puis exercices, chiffres en haut des cartes, titre du Store « Choisis un widget ou sauvegarde son style ».
- 624 : bouton « Modifier ou enregistrer le widget » lisible.

## Rapports écrits cette nuit
- docs/marketing/Panel-1000-clients-2026-11-27.md — panel SIMULÉ (40 archétypes, 1000 personnes) + pubs du QG.
  - Pubs : arrêt à 2 s 51 %, compréhension 65 %, envie d'installer 25 %. Meilleures : Fitness v4.3, Nutrition v5.1, avant/après v5. Pires : pov, satisfying, main v2.5 (ouverture sur un logo, texte coupé, texte trop petit).
  - Entonnoir : 29,5 % installent, 78 % posent un widget, J7 45 %, J30 23 %, 7,2 % des installés prennent Premium.
  - Prix (Van Westendorp) : 2,60–7,90 $/mois, optimum ≈ 4,99 $ ; 6,99 $/mois jugé trop cher par 50 %.
  - Freins : gratuit ailleurs, 6,99 $/mois, fatigue d'abonnements, mur à 3 widgets, pose du widget sur l'écran d'accueil peu claire.
  - À corriger : la pub montre « Série faite » alors que « Prochaine série » est Premium (pub à rendre honnête ou à refaire avec la notification de séance, gratuite).
- docs/marketing/Fiche-App-Store-ASO-2026-11-27.md — concurrence sourcée (Widgetsmith ~20 $/an, Top Widgets ~34 $/an…), nom/sous-titre/mots-clés FR et EN, 10 captures, prix recommandés (annuel 39,99 $, mensuel 4,99 $, essai 7 j ; achat à vie plus tard) — à décider par le PDG. Note : la Product Page Optimization ne teste pas le nom ni le sous-titre.
- docs/audits/Audit-confidentialite-AppReview-2026-11-27.md — rien de bloquant côté code ; liens Conditions/Confidentialité en ligne (vérifié : 200). À faire dans App Store Connect : questionnaire « App Privacy », notes de review. Mineur : clé Info.plist FinanceKit inutilisée, entrée localisation orpheline.
- docs/audits/Audit-parcours-accessibilite-2026-11-27.md — premier widget en 12 à 19 touchers ; corrections sûres confiées à un agent (contraste Créer, boutons ≥ 44 pt, carte du Store en grande police, « Atelier » → « Studio », VoiceOver, allemand).

## Suite (sera complété)
