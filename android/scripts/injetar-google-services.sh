#!/bin/bash
# injetar-google-services.sh: Injeta google-services.json por ambiente a partir de variáveis base64.
# Cartão llLCfQ7J: Push de ponta a ponta no Android.
#
# Variáveis de ambiente suportadas:
#   - GOOGLE_SERVICES_DEV ou FRILA_GOOGLE_SERVICES_DEV_BASE64: base64 do google-services.json de DEV (debug)
#   - GOOGLE_SERVICES_PROD ou FRILA_GOOGLE_SERVICES_PROD_BASE64: base64 do google-services.json de PROD (release)
#   - FRILA_EXIGE_PROD_RELEASE: força exigência estrita de GOOGLE_SERVICES_PROD (padrão em push main e tags v*)

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
    echo "Aviso: segredo para $ambiente não configurado."
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

gerar_placeholder_sintetico_release() {
  local destino="$1"
  mkdir -p "$(dirname "$destino")"
  cat <<'EOF' > "$destino"
{
  "project_info": {
    "project_number": "000000000000",
    "project_id": "frila-placeholder.invalid",
    "storage_bucket": "frila-placeholder.invalid.appspot.com"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:000000000000:android:0000000000000000000000",
        "android_client_info": {
          "package_name": "br.com.frila.app"
        }
      },
      "oauth_client": [],
      "api_key": [
        {
          "current_key": "AIzaSyDummyPlaceholderKeyForCiAndPrValidation.invalid"
        }
      ],
      "services": {
        "appinvite_service": {
          "other_platform_oauth_client": []
        }
      }
    }
  ],
  "configuration_version": "1"
}
EOF
  chmod 600 "$destino"
  echo "google-services.json de release configurado com placeholder sintético (.invalid) para validação."
}

eh_release_distribuivel() {
  if [[ "${FRILA_EXIGE_PROD_RELEASE:-false}" == "true" ]]; then
    return 0
  fi
  local ref="${GITHUB_REF:-}"
  local event="${GITHUB_EVENT_NAME:-}"
  if [[ "$event" == "push" ]] || [[ -z "$event" && -n "$ref" ]]; then
    if [[ "$ref" == "refs/heads/main" ]] || [[ "$ref" == refs/tags/v* ]]; then
      return 0
    fi
  fi
  return 1
}

DEV_BASE64="${GOOGLE_SERVICES_DEV:-${FRILA_GOOGLE_SERVICES_DEV_BASE64:-}}"
PROD_BASE64="${GOOGLE_SERVICES_PROD:-${FRILA_GOOGLE_SERVICES_PROD_BASE64:-}}"

# 1. Injeta DEV (debug)
injetar "DEV (debug)" "$ANDROID_DIR/app/src/debug/google-services.json" "$DEV_BASE64"

# 2. Injeta PROD (release) ou aplica salvaguardas
if [[ -n "$PROD_BASE64" ]]; then
  injetar "PROD (release)" "$ANDROID_DIR/app/src/release/google-services.json" "$PROD_BASE64"
else
  if eh_release_distribuivel; then
    echo "Erro: GOOGLE_SERVICES_PROD ausente em build de release distribuível (ref: ${GITHUB_REF:-indefinida}, evento: ${GITHUB_EVENT_NAME:-indefinido})." >&2
    echo "Build de release para main ou tags v* exige o segredo GOOGLE_SERVICES_PROD configurado." >&2
    exit 1
  else
    echo "Aviso: GOOGLE_SERVICES_PROD ausente; utilizando placeholder sintético (.invalid) em release para validação de compilação sem vazar credenciais."
    gerar_placeholder_sintetico_release "$ANDROID_DIR/app/src/release/google-services.json"
  fi
fi
