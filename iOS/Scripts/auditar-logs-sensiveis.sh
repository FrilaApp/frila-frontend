#!/bin/bash
# Confere somente os logs do subsistema do app, sem reproduzir o conteúdo caso haja vazamento.
# Execute após validar a entrada no simulador: Scripts/auditar-logs-sensiveis.sh [UDID|booted] [janela-em-minutos]
set -euo pipefail

DESTINO="${1:-booted}"
MINUTOS="${2:-5}"
ARQUIVO="$(mktemp -t frila-log-audit.XXXXXX)"
trap 'rm -f "$ARQUIVO"' EXIT

if ! [[ "$MINUTOS" =~ ^[1-9][0-9]*$ ]]; then
  echo "error: a janela deve ser um número inteiro positivo de minutos" >&2
  exit 2
fi

xcrun simctl spawn "$DESTINO" log show \
  --last "${MINUTOS}m" \
  --style compact \
  --predicate 'subsystem == "com.frila.org.app"' > "$ARQUIVO"

if [[ ! -s "$ARQUIVO" ]]; then
  echo "error: nenhum log do Frila foi encontrado; abra o app e repita a validação antes da auditoria" >&2
  exit 1
fi

# E-mail, bearer token, chaves Supabase e JWT. Nunca mostre a linha encontrada: ela pode ser o segredo.
PADRAO='[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}|[Bb]earer[[:space:]]+[^[:space:]]+|sb_(publishable|secret)_[^[:space:]]+|[[:alnum:]_-]{20,}\.[[:alnum:]_-]{20,}\.[[:alnum:]_-]{20,}'
if grep -Eiq "$PADRAO" "$ARQUIVO"; then
  echo "error: a auditoria encontrou um possível e-mail ou token nos logs do Frila; o valor foi omitido" >&2
  exit 1
fi

LINHAS="$(wc -l < "$ARQUIVO" | tr -d '[:space:]')"
echo "OK: ${LINHAS} linhas de log do Frila verificadas; nenhum e-mail ou token encontrado."
