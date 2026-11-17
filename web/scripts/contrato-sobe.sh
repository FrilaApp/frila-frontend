#!/bin/bash
# Sobe o espelho do contrato: copia o openapi.yaml do backend, regrava a soma e regenera os tipos.
# Nunca edite web/contrato/openapi.yaml à mão.
#
# Uso: scripts/contrato-sobe.sh <caminho do contrato/openapi.yaml do frila-backend>

set -euo pipefail
cd "$(dirname "$0")/.."

origem="${1:?uso: scripts/contrato-sobe.sh <contrato/openapi.yaml do backend>}"
[[ -f "$origem" ]] || { echo "error: arquivo não encontrado: $origem" >&2; exit 1; }

cp "$origem" contrato/openapi.yaml
shasum -a 256 contrato/openapi.yaml | awk '{print $1}' > contrato/openapi.yaml.sha256
scripts/gera-tipos.sh
echo "Espelho agora em $(sed -n 's/^  version: *//p' contrato/openapi.yaml | head -1)"
