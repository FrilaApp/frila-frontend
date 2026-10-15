#!/bin/bash
# Gate de deriva de contrato iOS x backend (contrato 0.2.41).
# Compara DTOs, RPCs, Enums e códigos de recusa tratados no app
# com a especificação OpenAPI espelhada em Contrato/openapi.yaml.
#
# Uso:
#   Scripts/contrato-ios-confere.sh [--silencioso] [--contrato <caminho>] [--sources <caminho>]

set -euo pipefail

SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SCRIPT_SOURCE" ]; do
  SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"
  SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
  [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/conferir-contrato-ios.py"

if [[ ! -f "$PYTHON_SCRIPT" ]]; then
  echo "error: validador python não encontrado em $PYTHON_SCRIPT" >&2
  exit 1
fi

exec python3 "$PYTHON_SCRIPT" "$@"
