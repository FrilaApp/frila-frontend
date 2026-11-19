#!/bin/bash
# injetar-google-services.sh: Injeta google-services.json por ambiente a partir de variáveis base64.
# Cartão llLCfQ7J: Push de ponta a ponta no Android.
#
# Variáveis de ambiente suportadas:
#   - GOOGLE_SERVICES_DEV ou FRILA_GOOGLE_SERVICES_DEV_BASE64: base64 do google-services.json de DEV (debug)
#   - GOOGLE_SERVICES_PROD ou FRILA_GOOGLE_SERVICES_PROD_BASE64: base64 do google-services.json de PROD (release)

set -euo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

decode_base64() {
  if base64 --help 2>&1 | grep -q -- '--decode'; then
    base64 --decode
  else
    base64 -D
  fi
}

injetar() {
  local ambiente="$1"
  local destino="$2"
  local valor="${3:-}"

  if [[ -z "$valor" ]]; then
    echo "Aviso: segredo para $ambiente não configurado (normal em PR de fork ou Dependabot)."
    return 0
  fi

  mkdir -p "$(dirname "$destino")"
  local temporario
  temporario="$(mktemp "${destino}.tmp.XXXXXX")"

  if ! printf '%s' "$valor" | decode_base64 > "$temporario"; then
    rm -f "$temporario"
    echo "Erro: conteúdo para $ambiente não é base64 válido" >&2
    return 1
  fi

  # Valida se é JSON válido sem exibir conteúdo
  if ! python3 -m json.tool "$temporario" >/dev/null 2>&1; then
    rm -f "$temporario"
    echo "Erro: conteúdo decodificado para $ambiente não é um JSON válido" >&2
    return 1
  fi

  mv "$temporario" "$destino"
  chmod 600 "$destino"
  echo "google-services.json injetado para $ambiente em $destino."
}

DEV_BASE64="${GOOGLE_SERVICES_DEV:-${FRILA_GOOGLE_SERVICES_DEV_BASE64:-}}"
PROD_BASE64="${GOOGLE_SERVICES_PROD:-${FRILA_GOOGLE_SERVICES_PROD_BASE64:-}}"

injetar "DEV (debug)" "$ANDROID_DIR/app/src/debug/google-services.json" "$DEV_BASE64"

if [[ -n "$PROD_BASE64" ]]; then
  injetar "PROD (release)" "$ANDROID_DIR/app/src/release/google-services.json" "$PROD_BASE64"
elif [[ -n "$DEV_BASE64" ]]; then
  echo "Aviso: GOOGLE_SERVICES_PROD ausente; replicando DEV para release para evitar falha no plugin Google Services."
  injetar "PROD (fallback de DEV)" "$ANDROID_DIR/app/src/release/google-services.json" "$DEV_BASE64"
else
  injetar "PROD (release)" "$ANDROID_DIR/app/src/release/google-services.json" ""
fi
