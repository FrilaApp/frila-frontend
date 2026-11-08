#!/bin/bash
# Exercita o portão de contrato Android (conferir-contrato-android.py) com mutações sintéticas.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/conferir-contrato-android.py"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONTRATO_OFICIAL="$REPO_ROOT/iOS/Contrato/openapi.yaml"
ANDROID_DIR="$REPO_ROOT/android"

TMPDIR_TESTE="$(mktemp -d "${TMPDIR:-/tmp}/frila-contrato-android-teste.XXXXXX")"
trap 'rm -rf "$TMPDIR_TESTE"' EXIT

[[ -x "$SCRIPT" ]] || { echo "FALHA: validador não executável: $SCRIPT" >&2; exit 1; }

esperar_aprovacao() {
  local saida
  if ! saida="$(python3 "$SCRIPT" "$@" 2>&1)"; then
    echo "FALHA: o caso conforme foi reprovado: $saida" >&2
    exit 1
  fi
  [[ "$saida" == *"OK: conformidade total de DTOs Android com contrato OpenAPI"* ]] || {
    echo "FALHA: aprovação sem mensagem esperada: $saida" >&2
    exit 1
  }
}

esperar_reprovacao() {
  local descricao="$1" motivo="$2"
  shift 2
  local saida
  if saida="$(python3 "$SCRIPT" "$@" 2>&1)"; then
    echo "FALHA: $descricao deveria reprovar, mas passou: $saida" >&2
    exit 1
  fi
  [[ "$saida" == *"$motivo"* ]] || {
    echo "FALHA: $descricao reprovou pelo motivo errado: $saida (esperava conter: '$motivo')" >&2
    exit 1
  }
}

# 1. Caso base: repositório atual em conformidade
esperar_aprovacao --contrato "$CONTRATO_OFICIAL" --android-dir "$ANDROID_DIR"

# Prepara ambiente temporário para mutações
mkdir -p "$TMPDIR_TESTE/android/core/rede/src/main/kotlin/br/com/frila/core/rede"
DTOS_FILE="$TMPDIR_TESTE/android/core/rede/src/main/kotlin/br/com/frila/core/rede/Dtos.kt"
cp "$ANDROID_DIR/core/rede/src/main/kotlin/br/com/frila/core/rede/Dtos.kt" "$DTOS_FILE"

# 2. Mutação 1: Campo obrigatório do Turno ausente (ex: id removido)
python3 -c "
with open('$DTOS_FILE', 'r', encoding='utf-8') as f:
    c = f.read().replace('@SerialName(\"id\") val id: String,\n', '')
with open('$DTOS_FILE', 'w', encoding='utf-8') as f:
    f.write(c)
"
esperar_reprovacao "TurnoDto sem id obrigatório" "não mapeia campos obrigatórios (required) do schema 'Turno': ['id']" --contrato "$CONTRATO_OFICIAL" --android-dir "$TMPDIR_TESTE/android"

# Restaura
cp "$ANDROID_DIR/core/rede/src/main/kotlin/br/com/frila/core/rede/Dtos.kt" "$DTOS_FILE"

# 3. Mutação 2: Campo inventado no TurnoDto (ex: turno_id na raiz)
python3 -c "
with open('$DTOS_FILE', 'r', encoding='utf-8') as f:
    c = f.read().replace('@SerialName(\"id\") val id: String,', '@SerialName(\"id\") val id: String,\n    @SerialName(\"turno_id\") val turnoId: String,')
with open('$DTOS_FILE', 'w', encoding='utf-8') as f:
    f.write(c)
"
esperar_reprovacao "TurnoDto com campo inventado turno_id" "possui campos inventados ausentes no schema 'Turno': ['turno_id']" --contrato "$CONTRATO_OFICIAL" --android-dir "$TMPDIR_TESTE/android"

echo "OK: todos os testes de mutação do portão Android passaram com sucesso!"
