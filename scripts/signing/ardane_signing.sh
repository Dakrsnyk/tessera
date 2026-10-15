#!/usr/bin/env bash
# Prepares the App Store signing of Ardane without a Mac (Git Bash on Windows, or any shell with openssl).
# Everything stays in ~/ardane-signing (outside the repository): the private key never goes to Git.
#
#   bash scripts/signing/ardane_signing.sh csr
#       creates the private key and Ardane.certSigningRequest, to upload in Certificates → Apple Distribution
#   bash scripts/signing/ardane_signing.sh secrets <TEAM_ID> <KEY_ID> <ISSUER_ID>
#       reads distribution.cer, the two .mobileprovision and AuthKey_<KEY_ID>.p8 from ~/ardane-signing,
#       builds the .p12 and stores the eight GitHub secrets of the [testflight] build (gh must be logged in)
#
# Steps on developer.apple.com and appstoreconnect.apple.com: scripts/signing/README.md.
set -euo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash: keeps « /CN=… » from being turned into a Windows path
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
DIR="$HOME/ardane-signing"
REPO="Dakrsnyk/tessera"
mkdir -p "$DIR"
cd "$DIR"

case "${1:-}" in
  csr)
    if [ -f dist.key ]; then
      echo "dist.key existe déjà dans $DIR : il est réutilisé (ne pas le supprimer, il va avec le certificat)."
    else
      openssl genrsa -out dist.key 2048 2>/dev/null
    fi
    openssl req -new -key dist.key -out Ardane.certSigningRequest -subj "/CN=Ardane Distribution/O=Ardane/C=CA"
    echo
    echo "Demande de certificat prête : $DIR/Ardane.certSigningRequest"
    echo "À envoyer sur developer.apple.com → Certificates → + → Apple Distribution."
    echo "Range ensuite distribution.cer, les deux profils (.mobileprovision) et AuthKey_XXXX.p8 dans $DIR."
    ;;

  secrets)
    TEAM_ID="${2:?Team ID manquant (Membership details, 10 caractères)}"
    KEY_ID="${3:?Key ID de la clé API manquant}"
    ISSUER_ID="${4:?Issuer ID manquant (en haut de la page des clés API)}"
    command -v gh >/dev/null || { echo "gh (GitHub CLI) introuvable"; exit 1; }
    [ -f dist.key ] || { echo "dist.key introuvable dans $DIR : lance d'abord « csr »"; exit 1; }
    CER=$(ls -1 *.cer 2>/dev/null | head -1 || true)
    [ -n "$CER" ] || { echo "Aucun .cer dans $DIR (le certificat Apple Distribution téléchargé)"; exit 1; }
    P8="AuthKey_$KEY_ID.p8"
    [ -f "$P8" ] || { echo "$P8 introuvable dans $DIR"; exit 1; }

    # Certificate + private key → .p12 (3DES/SHA-1: the format macOS's keychain imports everywhere).
    openssl x509 -inform DER -in "$CER" -out dist.pem 2>/dev/null || cp "$CER" dist.pem
    openssl x509 -in dist.pem -noout -subject
    if [ "$(openssl x509 -in dist.pem -noout -modulus)" != "$(openssl rsa -in dist.key -noout -modulus 2>/dev/null)" ]; then
      echo "Ce certificat ne correspond pas à dist.key : refais-le à partir de Ardane.certSigningRequest."; exit 1
    fi
    P12_PASSWORD=$(openssl rand -hex 16)
    openssl pkcs12 -export -inkey dist.key -in dist.pem -name "Ardane Distribution" -out dist.p12 \
      -passout "pass:$P12_PASSWORD" -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1

    # Which profile is which: read the application identifier inside each one.
    APP_PROFILE=""; WIDGETS_PROFILE=""
    for f in *.mobileprovision; do
      [ -f "$f" ] || continue
      plist=$(openssl smime -inform der -verify -noverify -in "$f" 2>/dev/null || openssl cms -inform der -verify -noverify -in "$f" 2>/dev/null)
      name=$(printf '%s' "$plist" | tr -d '\r\n\t' | sed -n 's|.*<key>Name</key><string>\([^<]*\)</string>.*|\1|p')
      appid=$(printf '%s' "$plist" | tr -d '\r\n\t' | sed -n 's|.*<key>application-identifier</key><string>\([^<]*\)</string>.*|\1|p')
      echo "profil : $f → « $name » ($appid)"
      case "$appid" in
        *.com.dakrsnyk.ardane.widgets) WIDGETS_PROFILE="$f"; [ "$name" = "Ardane Widgets App Store" ] || echo "  ⚠ il doit s'appeler exactement « Ardane Widgets App Store »" ;;
        *.com.dakrsnyk.ardane) APP_PROFILE="$f"; [ "$name" = "Ardane App Store" ] || echo "  ⚠ il doit s'appeler exactement « Ardane App Store »" ;;
      esac
    done
    [ -n "$APP_PROFILE" ] || { echo "Profil de com.dakrsnyk.ardane introuvable dans $DIR"; exit 1; }
    [ -n "$WIDGETS_PROFILE" ] || { echo "Profil de com.dakrsnyk.ardane.widgets introuvable dans $DIR"; exit 1; }

    b64() { base64 -w0 "$1" 2>/dev/null || base64 "$1" | tr -d '\n'; }
    gh secret set APPLE_TEAM_ID -R "$REPO" --body "$TEAM_ID"
    gh secret set DIST_P12_BASE64 -R "$REPO" --body "$(b64 dist.p12)"
    gh secret set DIST_P12_PASSWORD -R "$REPO" --body "$P12_PASSWORD"
    gh secret set PROFILE_APP_BASE64 -R "$REPO" --body "$(b64 "$APP_PROFILE")"
    gh secret set PROFILE_WIDGETS_BASE64 -R "$REPO" --body "$(b64 "$WIDGETS_PROFILE")"
    gh secret set ASC_KEY_ID -R "$REPO" --body "$KEY_ID"
    gh secret set ASC_ISSUER_ID -R "$REPO" --body "$ISSUER_ID"
    gh secret set ASC_KEY_P8_BASE64 -R "$REPO" --body "$(b64 "$P8")"
    rm -f dist.p12 dist.pem
    echo
    echo "Les 8 secrets sont enregistrés sur GitHub. Garde $DIR en lieu sûr (sauvegarde) : dist.key va avec le certificat."
    ;;

  *)
    sed -n '2,12p' "$SELF"
    exit 1
    ;;
esac
