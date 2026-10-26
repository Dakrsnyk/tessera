# Apple : commissions, taxes, versements (consulté le 2026-10-26)

Sources officielles seulement. V = vérifié sur la page citée ; C = à confirmer.

## 1. Commissions
- V Standard 30 % (70 % au développeur la 1re année d'un abonné) ; 85 % après un an de service payé (commission 15 %), taxes déduites.
  https://developer.apple.com/app-store/subscriptions/ ; Schedule 2 v126 : https://developer.apple.com/support/downloads/terms/schedules/Schedule-2-and-3-English.pdf
- V Jours « payés » : essais gratuits exclus, offres payantes et codes inclus ; par groupe d'abonnement ; compteur repris si réabonnement sous 60 jours (page abonnements).
- V Small Business Program : 15 % sur apps payantes et achats intégrés. https://developer.apple.com/app-store/small-business-program/
  - Éligibilité : <= 1 M$ US de « proceeds » (net de commission et taxes) sur les 12 mois fiscaux de l'année civile précédente ET <= 1 M$ dans l'année en cours, comptes associés inclus (> 50 % de propriété ou contrôle).
  - Inscription : titulaire du compte, contrat Paid Apps accepté, comptes associés listés (/app-store/small-business-program/enroll/).
  - Ajustement des revenus 15 jours après la fin du mois fiscal d'approbation.
  - Dépassement du seuil en cours d'année : taux standard sur les ventes futures ; requalification l'année suivante si sous le seuil.
- C Les ventes déjà faites avant le dépassement ne sont pas dites rétroactivement retarifées (la page est muette).
- C Combinaison 15 % PME + abonnement > 1 an : la page ne dit pas que les deux se cumulent vers 10 % (le 10 % cité vise les conditions alternatives UE).

## 2. Taxes et « proceeds »
- V Proceeds = prix client - taxes applicables - commission d'Apple ; commission calculée après déduction de la TVA. https://developer.apple.com/help/app-store-connect/making-payments-to-apple/understanding-taxes ; https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-pricing-for-auto-renewable-subscriptions
- V Dans les boutiques où Apple collecte et verse la taxe, le prix client est TTC (même page « Understanding taxes »). Commission sur le prix HT.
- C La liste exacte des pays où Apple collecte (77 boutiques citées par un extrait de recherche) : à lire dans App Store Connect.
- V Canada : le développeur fournit son numéro TPS/TVH (et TVQ si au Québec). Les versements pour les ventes au Canada sont réduits de la TPS/TVH et TVQ/TPS applicables sur la commission d'Apple (taxe payée par vous, crédit de taxe possible) ; facture mensuelle « taxe sur commission » dans App Store Connect. https://developer.apple.com/help/app-store-connect/manage-tax-information/provide-tax-information/
- C Pas d'inscription TPS/TVQ (petit fournisseur < 30 000 $) : le contrat Canada prévoit une attestation de non-inscription ; démarche à confirmer avec Apple/comptable.

## 3. Devise et versement
- V Versement dans les 45 jours suivant le dernier jour du mois fiscal Apple de la transaction, sur un seul compte bancaire, un seul paiement par devise et par mois. https://developer.apple.com/help/app-store-connect/getting-paid/overview-of-receiving-payments/
- V Conversion par la banque d'Apple vers la devise du compte, généralement au taux du jour de paiement (au plus 3 jours ouvrables avant) ; frais bancaires possibles chez vous.
- V Rapports financiers du mois précédent : disponibles vers le premier vendredi du mois fiscal courant (cette page ; une autre recherche dit mercredi : C).
- V Seuil minimal : compte bancaire canadien en CAD = 0,02 USD (ligne « CAN | Canada | CAD | 0.02 »). Autres cas : 40 USD ; sous le seuil, report. https://developer.apple.com/help/app-store-connect/reference/minimum-payment-threshold/

## 4. Prix et offres
- V Abonnements : jusqu'à 800 points de prix par devise ; prix comparables proposés pour 175 boutiques, ajustables par boutique ; Apple n'ajuste pas les prix aux variations de taxe/change. (page tarification des abonnements ci-dessus)
- C 6,99 / 59,99 / 99,99 $ US : ces montants n'apparaissent pas dans les pages lues ; à vérifier dans le sélecteur de prix d'App Store Connect.
- V Offre de bienvenue : trois types (essai gratuit, « pay as you go », « pay up front »). Un offre par abonnement et par territoire ; un client n'utilise qu'une offre de bienvenue par groupe d'abonnement. https://developer.apple.com/app-store/subscriptions/ ; https://developer.apple.com/help/app-store-connect/reference/pricing-and-availability/in-app-purchase-and-subscriptions-pricing-and-availability
- V Exemple Apple de pay as you go : 1,99 $/mois pendant 3 mois pour un prix standard de 9,99 $. C : 4,99 $ x 3 mois dépend de l'existence de ce palier (voir ci-dessus).

## 5. Remboursements et facturation
- V Apple rembourse le client ; selon Schedule 2, le développeur rembourse ou crédite le prix et Apple a le droit de garder sa commission. Dans les rapports, un remboursement a des unités et un prix client négatifs. https://developer.apple.com/help/app-store-connect/reference/reporting/summary-sales-report/
- C Dans les faits Apple n'a parfois repris que les proceeds (fil de forum, non officiel) ; ne pas compter dessus.
- V Billing Grace Period : à activer dans App Store Connect, durée 3, 16 ou 28 jours ; accès conservé pendant la récupération ; si récupéré, aucune interruption des jours payés ni des revenus. (page abonnements)

## 6. Codes d'offre (Subscription Offer Codes)
- V Codes uniques (18 caractères) ou personnalisés ; limite 1 million d'utilisations par app et par trimestre ; échange via URL, App Store (iOS 14.2+) ou `offerCodeRedemption` ; pertinent pour des testeurs ou une promotion. (pages abonnements et tarification)

## 7. Documents fiscaux (développeur canadien)
- V Formulaire américain obligatoire pour le contrat Paid Apps ; hors États-Unis : W-8BEN, W-8BEN-E ou W-8ECI selon un questionnaire d'App Store Connect. Une fois soumis, modification impossible dans l'interface (contacter Apple). https://developer.apple.com/help/app-store-connect/manage-tax-information/provide-tax-information/
- V Pour recevoir un paiement : contrat Paid Apps en vigueur, coordonnées bancaires, seuil dépassé, exigences de facturation locales.
- C Quel W-8 convient (particulier W-8BEN, société W-8BEN-E) et la réduction de retenue américaine (convention Canada-États-Unis) : valider avec un comptable.
