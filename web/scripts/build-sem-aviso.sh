#!/bin/bash
# Roda o build e falha se a saída tiver aviso (critério do cartão kOeZLcTF:
# "npm run build sem aviso de console").
set -euo pipefail
cd "$(dirname "$0")/.."

saida="$(mktemp)"
trap 'rm -f "$saida"' EXIT

npm run build 2>&1 | tee "$saida"

if grep -iE 'warn|\(!\)|deprecat' "$saida" >/dev/null; then
  echo "error: o build emitiu aviso (linhas acima)." >&2
  exit 1
fi
