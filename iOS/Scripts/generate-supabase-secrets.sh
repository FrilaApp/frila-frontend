#!/bin/bash
# Gera Configurations/Secrets.xcconfig a partir de variáveis de ambiente, sem imprimir os valores.
#
#   FRILA_SUPABASE_DEV_URL, FRILA_SUPABASE_DEV_PUBLISHABLE_KEY
#   FRILA_SUPABASE_PROD_URL, FRILA_SUPABASE_PROD_PUBLISHABLE_KEY
#
# Uso: Scripts/generate-supabase-secrets.sh [all|dev|prod]   (padrão: all, que exige os quatro)

set -euo pipefail
umask 077

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINATION="$ROOT_DIR/Configurations/Secrets.xcconfig"
TEMPORARY=""

cleanup() {
  if [[ -n "$TEMPORARY" && -e "$TEMPORARY" ]]; then
    rm -f "$TEMPORARY"
  fi
}
trap cleanup EXIT

fail() {
  echo "error: $*" >&2
  exit 1
}

PLACEHOLDERS=(not-configured seu-projeto cole-a-chave placeholder example changeme your- '<' '>' '$(')

contains_placeholder() {
  local value marker
  value="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  for marker in "${PLACEHOLDERS[@]}"; do
    if [[ "$value" == *"$marker"* ]]; then
      return 0
    fi
  done
  return 1
}

validate_url() {
  local name="$1"
  local value="${!name:-}"
  [[ -n "$value" ]] || fail "$name is not set"
  if contains_placeholder "$value"; then fail "$name still holds a placeholder"; fi
  [[ "$value" =~ ^https://[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?(:[0-9]{1,5})?/?$ ]] \
    || fail "$name must be https://<host>, without path, query or credentials"
}

validate_key() {
  local name="$1"
  local value="${!name:-}"
  [[ -n "$value" ]] || fail "$name is not set"
  if contains_placeholder "$value"; then fail "$name still holds a placeholder"; fi
  [[ "$value" =~ ^[A-Za-z0-9._-]+$ ]] || fail "$name has characters outside [A-Za-z0-9._-]"
  if [[ "$value" == sb_secret_* ]]; then
    fail "$name is a secret key; only the publishable key goes in the app"
  fi
  if [[ "$value" == *.*.* ]]; then
    # Chave legada em JWT: lida pelo nome da variável, nunca passada como argumento.
    local role
    role="$(python3 -c '
import base64, json, os, sys
payload = os.environ[sys.argv[1]].split(".")[1]
payload += "=" * (-len(payload) % 4)
try:
    print(json.loads(base64.urlsafe_b64decode(payload)).get("role", ""))
except Exception:
    print("invalid")
' "$name")"
    case "$role" in
      anon) ;;
      service_role) fail "$name is a service_role key; it must never go in the app" ;;
      *) fail "$name is not a valid anon JWT" ;;
    esac
  fi
}

case "${1:-all}" in
  all) ENVIRONMENTS=(DEV PROD) ;;
  dev|Dev) ENVIRONMENTS=(DEV) ;;
  prod|Prod) ENVIRONMENTS=(PROD) ;;
  *)
    echo "usage: $0 [all|dev|prod]" >&2
    exit 64
    ;;
esac

for environment in "${ENVIRONMENTS[@]}"; do
  validate_url "FRILA_SUPABASE_${environment}_URL"
  validate_key "FRILA_SUPABASE_${environment}_PUBLISHABLE_KEY"
done

if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$ROOT_DIR" check-ignore -q "$DESTINATION" \
    || fail "Configurations/Secrets.xcconfig is not ignored by Git; refusing to write it"
fi

TEMPORARY="$(mktemp "${DESTINATION}.tmp.XXXXXX")"
{
  echo "// Gerado por Scripts/generate-supabase-secrets.sh. Ignorado pelo Git: não edite nem versione."
  for environment in "${ENVIRONMENTS[@]}"; do
    url_name="FRILA_SUPABASE_${environment}_URL"
    key_name="FRILA_SUPABASE_${environment}_PUBLISHABLE_KEY"
    host="${!url_name#https://}"
    host="${host%/}"
    # Em .xcconfig, "//" abre comentário; "$()" separa as barras sem alterar o valor.
    printf '%s = https:/$()/%s\n' "$url_name" "$host"
    printf '%s = %s\n' "$key_name" "${!key_name}"
  done
} > "$TEMPORARY"
chmod 600 "$TEMPORARY"
mv -f "$TEMPORARY" "$DESTINATION"
TEMPORARY=""
chmod 600 "$DESTINATION"

echo "Configurations/Secrets.xcconfig written for: $(echo "${ENVIRONMENTS[*]}" | tr '[:upper:]' '[:lower:]')"
