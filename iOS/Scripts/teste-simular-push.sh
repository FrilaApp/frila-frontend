#!/bin/bash
# Autoteste do script simular-push.sh (#8).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/simular-push.sh"
TMPDIR_TESTE="$(mktemp -d "${TMPDIR:-/tmp}/frila-teste-simular-push.XXXXXX")"

trap 'rm -rf "$TMPDIR_TESTE"' EXIT

[[ -x "$SCRIPT" ]] || {
  echo "FALHA: simular-push.sh não encontrado ou não executável: $SCRIPT" >&2
  exit 1
}

# 1. Validação padrão de todos os fixtures
if ! "$SCRIPT" --validar >/dev/null 2>&1; then
  echo "FALHA: simular-push.sh --validar falhou para os fixtures do repositório" >&2
  exit 1
fi

# 2. Execução sem argumentos deve falhar com código de erro e exibir uso
if "$SCRIPT" >/dev/null 2>&1; then
  echo "FALHA: simular-push.sh sem argumentos deveria ter retornado erro" >&2
  exit 1
fi

# 3. Tipo inexistente deve falhar com erro descritivo
if saida="$("$SCRIPT" tipo_inexistente_xyz 2>&1)"; then
  echo "FALHA: simular-push.sh com tipo inexistente deveria ter retornado erro" >&2
  exit 1
fi
if [[ "$saida" != *"Tipo ou arquivo de push desconhecido"* ]]; then
  echo "FALHA: mensagem de erro inesperada para tipo desconhecido: $saida" >&2
  exit 1
fi

# 4. Arquivo com JSON quebrado deve ser reprovado
cat <<'JSON' > "$TMPDIR_TESTE/invalido.apns"
{ "aps": { "alert": "teste" }
JSON
if "$SCRIPT" "$TMPDIR_TESTE/invalido.apns" >/dev/null 2>&1; then
  echo "FALHA: arquivo com JSON malformado deveria ter sido reprovado" >&2
  exit 1
fi

# 5. Arquivo sem 'tipo' Frila deve ser reprovado
cat <<'JSON' > "$TMPDIR_TESTE/sem-tipo.apns"
{
  "Simulator Target Bundle": "com.frila.org.app",
  "aps": { "alert": { "title": "Olá" } }
}
JSON
if "$SCRIPT" "$TMPDIR_TESTE/sem-tipo.apns" >/dev/null 2>&1; then
  echo "FALHA: arquivo sem campo 'tipo' obrigatório deveria ter sido reprovado" >&2
  exit 1
fi

echo "OK: autoteste de simular-push.sh passou"
