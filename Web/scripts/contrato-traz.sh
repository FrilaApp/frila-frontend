#!/bin/bash
# Traz o contrato do frila-docs para o espelho da web e regrava a soma.
# Uso: scripts/contrato-traz.sh <caminho do api/openapi.yaml num clone atualizado do frila-docs>

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORIGINAL="${1:?uso: scripts/contrato-traz.sh <caminho do openapi.yaml do frila-docs>}"

cp "$ORIGINAL" "$RAIZ/contrato/openapi.yaml"
if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$RAIZ/contrato/openapi.yaml"; else sha256sum "$RAIZ/contrato/openapi.yaml"; fi \
  | awk '{print $1}' > "$RAIZ/contrato/openapi.yaml.sha256"
echo "ok: espelho na versão $(sed -n 's/^  version: *//p' "$RAIZ/contrato/openapi.yaml" | head -1). Rode npm run tipos."
