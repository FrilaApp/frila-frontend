#!/bin/bash

set -euo pipefail
umask 077

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_ID="com.frila.org.app"

decode_base64() {
  if base64 --help 2>&1 | grep -q -- '--decode'; then
    base64 --decode
  else
    base64 -D
  fi
}

inject() {
  local environment="$1"
  local secret_name="$2"
  local destination="$ROOT_DIR/Resources/Firebase/$environment/GoogleService-Info.plist"
  local encoded="${!secret_name:-}"

  if [[ -z "$encoded" ]]; then
    echo "error: CI secret $secret_name is not configured" >&2
    return 1
  fi

  mkdir -p "$(dirname "$destination")"
  local temporary
  temporary="$(mktemp "${destination}.tmp.XXXXXX")"

  if ! printf '%s' "$encoded" | decode_base64 > "$temporary"; then
    rm -f "$temporary"
    echo "error: $secret_name is not valid base64" >&2
    return 1
  fi

  if ! plutil -lint "$temporary" >/dev/null; then
    rm -f "$temporary"
    echo "error: $secret_name does not contain a valid plist" >&2
    return 1
  fi

  local plist_bundle_id
  plist_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :BUNDLE_ID' "$temporary" 2>/dev/null || true)"
  if [[ "$plist_bundle_id" != "$BUNDLE_ID" ]]; then
    rm -f "$temporary"
    echo "error: Firebase plist for $environment uses bundle ID '$plist_bundle_id'; expected '$BUNDLE_ID'" >&2
    return 1
  fi

  mv "$temporary" "$destination"
  chmod 600 "$destination"
  echo "Firebase configuration injected for $environment."
}

case "${1:-all}" in
  Dev|dev)
    inject "Dev" "FRILA_FIREBASE_GOOGLE_SERVICE_INFO_DEV_B64"
    ;;
  Prod|prod)
    inject "Prod" "FRILA_FIREBASE_GOOGLE_SERVICE_INFO_PROD_B64"
    ;;
  all)
    inject "Dev" "FRILA_FIREBASE_GOOGLE_SERVICE_INFO_DEV_B64"
    inject "Prod" "FRILA_FIREBASE_GOOGLE_SERVICE_INFO_PROD_B64"
    ;;
  *)
    echo "usage: $0 [dev|prod|all]" >&2
    exit 64
    ;;
esac
