#!/bin/bash
# Fase de build: Dev e Prod não saem do Xcode sem Supabase configurado. Só lê as variáveis de build
# e nunca imprime valores. Na CI a falta de configuração é erro; localmente, aviso, e o app abre na
# tela de configuração incompleta em vez de usar o dublê em memória.

set -euo pipefail

case "${FRILA_ENVIRONMENT:-}" in
  local)
    exit 0
    ;;
  frila-dev|frila-prod)
    ;;
  *)
    echo "error: unknown FRILA_ENVIRONMENT; expected local, frila-dev or frila-prod" >&2
    exit 1
    ;;
esac

HINT="generate Configurations/Secrets.xcconfig with Scripts/generate-supabase-secrets.sh"

missing() {
  if [[ "${CI:-false}" == "true" ]]; then
    echo "error: $1 for ${FRILA_ENVIRONMENT}; $HINT" >&2
    exit 1
  fi
  echo "warning: $1 for ${FRILA_ENVIRONMENT}; the app will open on the configuration error screen. $HINT" >&2
  exit 0
}

has_placeholder() {
  local value
  value="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  for marker in not-configured seu-projeto cole-a-chave placeholder example changeme your- '<' '>' '$('; do
    if [[ "$value" == *"$marker"* ]]; then
      return 0
    fi
  done
  return 1
}

URL="${FRILA_SUPABASE_URL:-}"
KEY="${FRILA_SUPABASE_PUBLISHABLE_KEY:-}"

# Chave secreta nunca entra num build, nem localmente.
if [[ "$KEY" == sb_secret_* ]]; then
  echo "error: the Supabase key for ${FRILA_ENVIRONMENT} is a secret key; only the publishable key goes in the app" >&2
  exit 1
fi
if [[ "$KEY" == *.*.* ]]; then
  ROLE="$(python3 -c '
import base64, json, os
payload = os.environ["FRILA_SUPABASE_PUBLISHABLE_KEY"].split(".")[1]
payload += "=" * (-len(payload) % 4)
try:
    print(json.loads(base64.urlsafe_b64decode(payload)).get("role", ""))
except Exception:
    print("invalid")
')"
  if [[ "$ROLE" == "service_role" ]]; then
    echo "error: the Supabase key for ${FRILA_ENVIRONMENT} is a service_role key; it must never go in the app" >&2
    exit 1
  fi
fi

[[ -n "$URL" ]] || missing "Supabase URL is not configured"
if has_placeholder "$URL"; then missing "Supabase URL is still a placeholder"; fi
[[ "$URL" == https://* ]] || missing "Supabase URL must use https"
[[ -n "$KEY" ]] || missing "Supabase publishable key is not configured"
if has_placeholder "$KEY"; then missing "Supabase publishable key is still a placeholder"; fi

exit 0
