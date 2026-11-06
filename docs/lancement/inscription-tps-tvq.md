# Numéros TPS et TVQ d'Ardane (préparé le 2026-11-06)

L'utilisateur appelle ces numéros « RNQ ». Il les demande lui-même, et il ne doit jamais écrire son NAS dans ce dépôt ni dans une conversation.

Ce qu'on obtient, en une seule démarche auprès de Revenu Québec (au Québec, elle gère aussi la TPS) :

| Numéro | Format | Rôle |
|---|---|---|
| TPS/TVH (fédéral) | 9 chiffres + `RT0001` | Les 9 chiffres forment le numéro d'entreprise (NE) fédéral |
| TVQ (Québec) | 10 chiffres + `TQ0001` | Taxe de vente du Québec |

Le NEQ (2282741356) est un autre numéro : il vient du Registraire et il est déjà reçu.

## Pourquoi maintenant
- **App Store Connect** (aide d'Apple, section *Canada*) : « *If you're based in Canada, you're required to submit your […] GST/HST number* », et le numéro TVQ si on est au Québec.
- **Retenue d'Apple :** sur les ventes au Canada, Apple retient la TPS/TVQ sur sa commission et envoie chaque mois une facture de cette taxe dans App Store Connect. Un inscrit peut récupérer cette taxe en crédit (CTI/RTI), comme celle de ses achats : compte Apple Developer, domaine, matériel.
- **Ce qu'on remplit :** les numéros donnés à Apple remplissent la partie 4 du formulaire FP-2506-V et la partie D du GST506, deux formulaires où l'on choisit Apple comme mandataire. Apple remplit sa partie et rend les formulaires téléchargeables.
- **À faire confirmer par le CPA :** qu'Apple Canada perçoit et verse alors la taxe sur les ventes faites au Canada.

## Ce que l'inscription engage (Revenu Québec, page « Petit fournisseur »)
- Ardane est un **petit fournisseur** : moins de 30 000 $ de ventes taxables dans le monde sur un trimestre civil ou sur les quatre précédents. L'inscription est donc **volontaire**.
- Une fois inscrit, il faut percevoir et verser les taxes sur chaque vente taxable (les ventes détaxées sont exclues) et produire les déclarations en ligne.
- Il faut **rester inscrit au moins un an**. S'inscrire à la TVQ inscrit aussi à la TPS.

## Comment s'inscrire
1. **Où :** la page Revenu Québec « Comment vous inscrire aux fichiers de la TPS et de la TVQ » propose le service en ligne **« Inscription d'une entreprise en démarrage »**. C'est celui à prendre quand on n'est encore inscrit à aucun fichier de Revenu Québec ; il inscrit aussi à clicSÉQUR. La version papier (formulaire **LM-1**, envoyé par la poste) est plus lente. S'inscrire **une seule fois**.
2. **Avoir sous la main :**
   - le NEQ 2282741356 ;
   - le NAS, que tu tapes toi-même ;
   - l'adresse de l'entreprise (domicile) ;
   - la date de début des activités (immatriculation : 2026-11-04 ; aucune vente encore) ;
   - l'activité : édition d'applications mobiles vendues par l'App Store.
3. **Choix probables, à garder modestes :**
   - fichiers TPS et TVQ : **oui** ;
   - retenues à la source : **non** (aucun salarié) ;
   - impôt des sociétés : **non** (ce n'est pas une société) ;
   - ventes prévues : moins de 30 000 $, donc **inscription volontaire** ;
   - période de déclaration : **annuelle** si elle est proposée ;
   - date d'effet : le jour de l'inscription, ou la date de la première vente ;
   - responsable des services électroniques (clicSÉQUR) : **toi**.
4. **Suivi :** le service **« Suivi de l'inscription d'une entreprise en démarrage »** donne le numéro d'identification, le numéro de dossier et le numéro de compte TPS. Des lettres de confirmation arrivent par la poste. Le délai de traitement n'est pas affiché sur le site (rien vérifié).

## Après
- [ ] Noter les deux numéros dans tes papiers (pas dans ce dépôt) et garder les lettres.
- [ ] App Store Connect › Business › Tax Forms › Canada : saisir le numéro TPS puis le numéro TVQ ; télécharger la copie du FP-2506-V et du GST506.
- [ ] Questions au CPA :
  - date d'effet à retenir ;
  - période annuelle ;
  - ventes hors Canada (détaxées ?) ;
  - comment déclarer les ventes App Store quand Apple est mandataire ;
  - récupérer la taxe des factures mensuelles d'Apple.

Sources : revenuquebec.ca (pages « Comment vous inscrire », « Inscription aux fichiers de la TPS et de la TVQ », « Particularités concernant le petit fournisseur »), lues le 2026-11-06 ; developer.apple.com, aide d'App Store Connect, « Provide Canada tax information ». Tout point fiscal reste à confirmer par un CPA du Québec.
