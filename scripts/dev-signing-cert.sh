#!/usr/bin/env bash
# Create (once) a self-signed code-signing certificate so local Nab builds keep
# a STABLE signing identity across rebuilds.
#
#   scripts/dev-signing-cert.sh
#
# Why: ad-hoc signing (`codesign --sign -`) produces a different identity every
# build, so macOS treats each rebuild as a brand-new app — the keychain prompt
# ("Nab wants to use your confidential information…") reappears, "Always Allow"
# never sticks, and TCC grants (Accessibility / Screen Recording) reset.
# Signing every build with the same certificate makes those approvals stick.
#
# The script is idempotent: if the identity already exists it does nothing.
# macOS will show ONE auth dialog when the certificate's trust is registered —
# that approval is yours to give, and it happens only once.
set -euo pipefail

IDENTITY="Nab Dev Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep -q "$IDENTITY"; then
  echo "'$IDENTITY' already exists and is valid — nothing to do."
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> Generating self-signed code-signing certificate '$IDENTITY'"
openssl req -new -x509 -days 3650 -nodes -newkey rsa:2048 \
  -keyout "$WORK/key.pem" -out "$WORK/cert.pem" \
  -subj "/CN=$IDENTITY" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning" \
  -addext "basicConstraints=critical,CA:FALSE" >/dev/null 2>&1

P12PASS="nab-dev-$(date +%s)"
# macOS's `security import` uses an older PKCS12 parser that can't verify the
# SHA-256 MAC / modern ciphers OpenSSL 3.x defaults to. Force the legacy
# SHA-1 / 3DES scheme (add -legacy when the provider is available) so import
# succeeds. Both flags are harmless on OpenSSL that predates them.
P12_COMPAT=(-macalg sha1 -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES)
if openssl pkcs12 -help 2>&1 | grep -q -- "-legacy"; then
  P12_COMPAT+=(-legacy)
fi
openssl pkcs12 -export -out "$WORK/nab.p12" \
  -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
  "${P12_COMPAT[@]}" -passout "pass:$P12PASS" >/dev/null 2>&1

echo "==> Importing into the login keychain (codesign gets access)"
security import "$WORK/nab.p12" -k "$KEYCHAIN" -P "$P12PASS" \
  -T /usr/bin/codesign >/dev/null

echo "==> Registering trust for code signing (macOS will ask you to approve)"
security add-trusted-cert -p codeSign -k "$KEYCHAIN" "$WORK/cert.pem"

echo
if security find-identity -v -p codesigning "$KEYCHAIN" | grep -q "$IDENTITY"; then
  echo "Done. '$IDENTITY' is ready — package-dmg.sh will pick it up automatically."
  echo "Expect ONE 'codesign wants to sign using key…' dialog on the next build;"
  echo "click 'Always Allow' and you won't see it again."
else
  echo "warning: identity not yet valid — the trust approval may have been declined." >&2
  exit 1
fi
