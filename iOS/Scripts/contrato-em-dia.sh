#!/bin/bash
# O contrato nasce em FrilaApp/frila-docs (api/openapi.yaml) e é espelhado em Contrato/,
# no mesmo esquema do frila-backend. Este script prova que o espelho não foi mexido e,
# quando tem acesso ao original, que não divergiu dele.
#
#   1. Integridade local: o espelho bate com Contrato/openapi.yaml.sha256. Roda sempre.
#   2. Divergência do original: exige FRILA_DOCS_TOKEN (ou GH_TOKEN) com leitura em
#      FrilaApp/frila-docs, que é privado. Sem token, avisa em voz alta em vez de passar calado.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ESPELHO="$ROOT_DIR/Contrato/openapi.yaml"
SOMA="$ROOT_DIR/Contrato/openapi.yaml.sha256"
ORIGEM="https://api.github.com/repos/FrilaApp/frila-docs/contents/api/openapi.yaml?ref=main"

versao="$(sed -n 's/^  version: *//p' "$ESPELHO" | head -1)"

if [[ ! -f "$SOMA" ]]; then
  echo "error: falta Contrato/openapi.yaml.sha256" >&2
  exit 1
fi

atual="$(shasum -a 256 "$ESPELHO" | awk '{print $1}')"
gravada="$(tr -d '[:space:]' < "$SOMA")"
if [[ "$atual" != "$gravada" ]]; then
  echo "error: o espelho do contrato mudou sem atualizar a soma (gravada $gravada, atual $atual)." >&2
  echo "Se a mudança veio do frila-docs, traga o arquivo e regrave a soma; nunca edite o espelho à mão." >&2
  exit 1
fi
echo "Espelho íntegro: contrato $versao, sha256 $atual"

token="${FRILA_DOCS_TOKEN:-${GH_TOKEN:-}}"
if [[ -z "$token" ]]; then
  echo "warning: original NÃO conferido: FrilaApp/frila-docs é privado e não há FRILA_DOCS_TOKEN." >&2
  echo "O espelho pode estar íntegro e mesmo assim atrasado em relação ao contrato publicado." >&2
  exit 0
fi

temporario="$(mktemp)"
trap 'rm -f "$temporario"' EXIT
if ! curl -fsSL -H "Authorization: Bearer $token" -H "Accept: application/vnd.github.raw" "$ORIGEM" -o "$temporario"; then
  echo "error: há token, mas o contrato em FrilaApp/frila-docs não pôde ser lido" >&2
  exit 1
fi

if cmp -s "$temporario" "$ESPELHO"; then
  echo "Espelho em dia com FrilaApp/frila-docs."
  exit 0
fi

echo "error: o espelho divergiu do contrato publicado em FrilaApp/frila-docs:" >&2
diff -u "$ESPELHO" "$temporario" | head -60 >&2 || true
echo "Traga o arquivo novo, regrave Contrato/openapi.yaml.sha256 e ajuste DTOs e fixtures no mesmo PR." >&2
exit 1
