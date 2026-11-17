#!/bin/bash
# O contrato nasce em FrilaApp/frila-docs (api/openapi.yaml) e é espelhado em Web/contrato/,
# no mesmo esquema do iOS e do backend. Este script prova que o espelho não foi mexido e,
# quando tem acesso ao original, que não divergiu dele.
#
#   1. Integridade local: o espelho bate com contrato/openapi.yaml.sha256. Roda sempre.
#   2. Divergência do original: exige FRILA_DOCS_TOKEN (ou GH_TOKEN) com leitura em
#      FrilaApp/frila-docs, que é privado. Sem token, avisa em voz alta em vez de passar calado.
#
# Os tipos (app/contrato/tipos.gerado.ts) não entram no git: saem do espelho em `npm run tipos`.

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ESPELHO="$RAIZ/contrato/openapi.yaml"
SOMA="$RAIZ/contrato/openapi.yaml.sha256"
ORIGEM="https://api.github.com/repos/FrilaApp/frila-docs/contents/api/openapi.yaml?ref=main"

soma_de() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1"; else sha256sum "$1"; fi | awk '{print $1}'; }

if [[ ! -f "$ESPELHO" || ! -f "$SOMA" ]]; then
  echo "error: falta contrato/openapi.yaml ou contrato/openapi.yaml.sha256" >&2
  exit 1
fi

versao="$(sed -n 's/^  version: *//p' "$ESPELHO" | head -1)"
atual="$(soma_de "$ESPELHO")"
gravada="$(tr -d '[:space:]' < "$SOMA")"
if [[ "$atual" != "$gravada" ]]; then
  echo "error: o espelho do contrato mudou sem atualizar a soma (gravada $gravada, atual $atual)." >&2
  echo "Se a mudança veio do frila-docs, traga o arquivo com scripts/contrato-traz.sh; nunca edite o espelho à mão." >&2
  exit 1
fi
echo "ok: espelho do contrato íntegro (versão $versao)."

TOKEN="${FRILA_DOCS_TOKEN:-${GH_TOKEN:-}}"
if [[ -z "$TOKEN" ]]; then
  echo "AVISO: sem FRILA_DOCS_TOKEN nem GH_TOKEN: NÃO foi conferido se o espelho ainda é igual ao original do frila-docs."
  exit 0
fi

original="$(mktemp)"
trap 'rm -f "$original"' EXIT
if ! curl -fsSL -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github.raw+json" "$ORIGEM" -o "$original"; then
  echo "AVISO: não consegui baixar o original do frila-docs (token sem acesso?): divergência NÃO conferida."
  exit 0
fi
if [[ "$(soma_de "$original")" != "$atual" ]]; then
  echo "error: o espelho (versão $versao) está diferente do original do frila-docs. Rode scripts/contrato-traz.sh." >&2
  exit 1
fi
echo "ok: espelho igual ao original do frila-docs."
