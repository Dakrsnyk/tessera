# Installer Ardane par TestFlight (compte Apple Developer, sans Mac)

La CI signe une version Release avec le compte Apple Developer et l'envoie sur TestFlight quand le message de commit contient `[testflight]`. Sur l'iPhone, Ardane s'installe alors par l'app TestFlight, avec les widgets, l'écran verrouillé, l'activité en direct et l'App Group, comme la version de l'App Store.

## Ce qui se fait une seule fois

1. **App Group** — developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → **+** → App Groups. Description `Ardane`, identifiant `group.com.dakrsnyk.tessera`.
2. **App ID de l'app** — Identifiers → **+** → App IDs → App. Description `Ardane`, Bundle ID explicite `com.dakrsnyk.ardane`. Cocher **App Groups**, enregistrer, rouvrir l'identifiant, App Groups → Configure → cocher `group.com.dakrsnyk.tessera` → Save.
3. **App ID des widgets** — pareil avec la description `Ardane Widgets` et `com.dakrsnyk.ardane.widgets`, App Groups coché et configuré sur le même groupe.
4. **Demande de certificat** — dans Git Bash, à la racine du dépôt : `bash scripts/signing/ardane_signing.sh csr`. Le fichier `Ardane.certSigningRequest` est créé dans `C:\Users\<toi>\ardane-signing`.
5. **Certificat** — Certificates → **+** → **Apple Distribution** → envoyer `Ardane.certSigningRequest` → Download. Ranger `distribution.cer` dans `ardane-signing`.
6. **Profils** — Profiles → **+** → Distribution → **App Store Connect** :
   - App ID `com.dakrsnyk.ardane`, le certificat, nom exact **`Ardane App Store`** → Generate → Download.
   - App ID `com.dakrsnyk.ardane.widgets`, le certificat, nom exact **`Ardane Widgets App Store`** → Generate → Download.
   Ranger les deux `.mobileprovision` dans `ardane-signing`.
7. **Team ID** — developer.apple.com → Account → Membership details → Team ID (10 caractères).
8. **Fiche de l'app** — appstoreconnect.apple.com → Apps → **+** → New App : iOS, nom `Ardane`, langue principale Français (Canada), Bundle ID `com.dakrsnyk.ardane`, SKU `ARDANE001`, accès complet.
9. **Clé API** — App Store Connect → Users and Access → Integrations → App Store Connect API → Team Keys → **+** : nom `GitHub CI`, accès **App Manager** → Generate → Download (une seule fois possible). Ranger `AuthKey_XXXXXXXXXX.p8` dans `ardane-signing`. Noter le **Key ID** et l'**Issuer ID** (en haut de la page).
10. **Secrets GitHub** — dans Git Bash : `bash scripts/signing/ardane_signing.sh secrets <TEAM_ID> <KEY_ID> <ISSUER_ID>`. Le script fabrique le `.p12` (mot de passe aléatoire) et enregistre les 8 secrets du dépôt avec `gh` : `APPLE_TEAM_ID`, `DIST_P12_BASE64`, `DIST_P12_PASSWORD`, `PROFILE_APP_BASE64`, `PROFILE_WIDGETS_BASE64`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`.

Garder `ardane-signing` en lieu sûr (sauvegarde) : `dist.key` va avec le certificat et ne doit jamais aller dans le dépôt.

## À chaque version

- Commit avec `[testflight]` : la CI archive en Release (numéro de build = numéro du run), signe et envoie. Le rapport `ci-report` affiche `testflight: success`.
- Apple traite la version (10 à 30 minutes), puis elle apparaît dans App Store Connect → TestFlight.
- La première fois : TestFlight → Internal Testing → **+** → groupe `Moi`, s'ajouter comme testeur, activer la distribution automatique. Installer l'app **TestFlight** sur l'iPhone, ouvrir l'invitation, **Installer**.
- Une version TestFlight expire après 90 jours ; chaque `[testflight]` en envoie une nouvelle.

## Si ça bloque

- « identifiant de groupe non disponible » à l'étape 1 : prévenir Claude, qui passe l'App Group à `group.com.dakrsnyk.ardane` dans le projet.
- `Secrets manquants` dans le rapport : refaire l'étape 10.
- « Le profil s'appelle … » : renommer le profil (Profiles → le profil → Edit → Name) ou le recréer avec le nom exact, puis refaire l'étape 10.
- Profils et certificat expirent après un an : refaire 5, 6 et 10.
- Achats Premium : dans une version TestFlight (Release), le déverrouillage de test n'existe pas. Pour tester les achats (gratuits en TestFlight), il faut l'accord « Paid Apps » (Business) et les produits `com.dakrsnyk.ardane.premium.monthly`, `.yearly` et `.lifetime` créés dans App Store Connect.
