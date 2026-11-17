#!/bin/bash
# Gera os tipos TypeScript do contrato espelhado em web/contrato/openapi.yaml.
# A versão do openapi-typescript é fixa em package.json, então a saída é reproduzível.
#
# Uso: scripts/gera-tipos.sh [arquivo-de-saida]   (padrão: src/api/contrato.d.ts)

set -euo pipefail
cd "$(dirname "$0")/.."

saida="${1:-src/api/contrato.d.ts}"
mkdir -p "$(dirname "$saida")"
./node_modules/.bin/openapi-typescript contrato/openapi.yaml -o "$saida" >/dev/null
echo "Tipos gerados em $saida"
