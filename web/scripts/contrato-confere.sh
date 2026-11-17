#!/bin/bash
# Gate de deriva do contrato no web/. Três conferências, nesta ordem:
#
#   1. Integridade: contrato/openapi.yaml bate com contrato/openapi.yaml.sha256.
#   2. Tipos em dia: src/api/contrato.d.ts commitado é idêntico ao gerado agora.
#   3. Origem: o espelho é idêntico ao contrato/openapi.yaml da develop do frila-backend
#      (repositório privado; exige FRILA_BACKEND_TOKEN ou GH_TOKEN com leitura).
#
# Sem token a conferência 3 NÃO acontece. Por padrão isso é erro (saída 3), para não passar
# calado. --local aceita a ausência, com aviso, e só deve ser usado onde não há token.
#
# Uso: scripts/contrato-confere.sh [--local] [--origem <arquivo>]
#   --origem <arquivo>  compara com um arquivo local em vez de buscar no GitHub (testes).
#   FRILA_BACKEND_REF   ref do backend a comparar (padrão: develop).
#
# Para subir o espelho: scripts/contrato-sobe.sh <contrato/openapi.yaml do backend>.

set -euo pipefail
cd "$(dirname "$0")/.."

local_apenas=0
origem_arquivo=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --local) local_apenas=1; shift ;;
    --origem) origem_arquivo="${2:?--origem exige um caminho}"; shift 2 ;;
    *) echo "error: argumento desconhecido: $1" >&2; exit 64 ;;
  esac
done

espelho="contrato/openapi.yaml"
soma="contrato/openapi.yaml.sha256"
tipos="src/api/contrato.d.ts"
versao="$(sed -n 's/^  version: *//p' "$espelho" | head -1)"

[[ -f "$soma" ]] || { echo "error: falta $soma" >&2; exit 1; }

atual="$(shasum -a 256 "$espelho" | awk '{print $1}')"
gravada="$(tr -d '[:space:]' < "$soma")"
if [[ "$atual" != "$gravada" ]]; then
  echo "error: o espelho mudou sem atualizar a soma (gravada $gravada, atual $atual)." >&2
  echo "Não edite o espelho à mão: scripts/contrato-sobe.sh <contrato do backend>." >&2
  exit 1
fi
echo "Espelho íntegro: contrato $versao, sha256 $atual"

gerado="$(mktemp)"
temporario="$(mktemp)"
trap 'rm -f "$gerado" "$temporario"' EXIT

scripts/gera-tipos.sh "$gerado" >/dev/null
if ! cmp -s "$gerado" "$tipos"; then
  echo "error: $tipos difere do gerado a partir do espelho. Rode scripts/gera-tipos.sh e commite." >&2
  exit 1
fi
echo "Tipos em dia com o espelho."

if [[ -n "$origem_arquivo" ]]; then
  cp "$origem_arquivo" "$temporario"
else
  token="${FRILA_BACKEND_TOKEN:-${GH_TOKEN:-}}"
  if [[ -z "$token" ]]; then
    if [[ "$local_apenas" -eq 1 ]]; then
      echo "warning: origem NÃO conferida: frila-backend é privado e não há FRILA_BACKEND_TOKEN." >&2
      echo "O espelho pode estar íntegro e mesmo assim atrasado em relação ao backend." >&2
      exit 0
    fi
    echo "error: origem NÃO conferida (sem FRILA_BACKEND_TOKEN). Use --local para aceitar isso." >&2
    exit 3
  fi
  ref="${FRILA_BACKEND_REF:-develop}"
  url="https://api.github.com/repos/FrilaApp/frila-backend/contents/contrato/openapi.yaml?ref=$ref"
  if ! curl -fsSL -H "Authorization: Bearer $token" -H "Accept: application/vnd.github.raw" "$url" -o "$temporario"; then
    echo "error: não consegui ler contrato/openapi.yaml de frila-backend@$ref" >&2
    exit 1
  fi
fi

if ! cmp -s "$temporario" "$espelho"; then
  versao_origem="$(sed -n 's/^  version: *//p' "$temporario" | head -1)"
  echo "error: o espelho ($versao) difere do backend (${versao_origem:-versão ilegível}), sha256 $(shasum -a 256 "$temporario" | awk '{print $1}')." >&2
  echo "Suba o espelho: scripts/contrato-sobe.sh <contrato/openapi.yaml do backend>." >&2
  exit 1
fi
echo "Espelho em dia com o backend."
