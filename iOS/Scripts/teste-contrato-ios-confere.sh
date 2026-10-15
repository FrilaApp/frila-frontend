#!/bin/bash
# Exercita o contrato público de contrato-ios-confere.sh com cenários sintéticos de deriva.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/contrato-ios-confere.sh"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONTRATO_OFICIAL="$ROOT_DIR/Contrato/openapi.yaml"
SOURCES_OFICIAL="$ROOT_DIR/Sources"

TMPDIR_TESTE="$(mktemp -d "${TMPDIR:-/tmp}/frila-contrato-confere.XXXXXX")"
trap 'rm -rf "$TMPDIR_TESTE"' EXIT

[[ -x "$SCRIPT" ]] || { echo "FALHA: verificador não executável: $SCRIPT" >&2; exit 1; }

esperar_aprovacao() {
  local saida
  if ! saida="$("$SCRIPT" "$@" 2>&1)"; then
    echo "FALHA: o caso conforme foi reprovado: $saida" >&2
    exit 1
  fi
  [[ "$saida" == *"OK: conformidade total com contrato"* ]] || {
    echo "FALHA: aprovação sem mensagem esperada: $saida" >&2
    exit 1
  }
}

esperar_reprovacao() {
  local descricao="$1" motivo="$2"
  shift 2
  local saida
  if saida="$("$SCRIPT" "$@" 2>&1)"; then
    echo "FALHA: $descricao deveria reprovar, mas passou: $saida" >&2
    exit 1
  fi
  [[ "$saida" == *"$motivo"* ]] || {
    echo "FALHA: $descricao reprovou pelo motivo errado: $saida (esperava conter: '$motivo')" >&2
    exit 1
  }
}

# 1. Caso base: repositório atual em conformidade
esperar_aprovacao --contrato "$CONTRATO_OFICIAL" --sources "$SOURCES_OFICIAL"

# Prepara ambiente temporário com cópia isolada para injeção de defeitos
mkdir -p "$TMPDIR_TESTE/Contrato"
cp "$CONTRATO_OFICIAL" "$TMPDIR_TESTE/Contrato/openapi.yaml"
cp -R "$SOURCES_OFICIAL" "$TMPDIR_TESTE/Sources"

# 2. RPC faltando no app
cp "$TMPDIR_TESTE/Contrato/openapi.yaml" "$TMPDIR_TESTE/Contrato/openapi-rpc-faltando.yaml"
# Injeta nova rota /rpc/operacao_fantasma no openapi
sed -i '' 's|/rpc/abrir_suporte:|/rpc/operacao_fantasma:\
    post:\
      summary: Fantasma\
  /rpc/abrir_suporte:|g' "$TMPDIR_TESTE/Contrato/openapi-rpc-faltando.yaml"

esperar_reprovacao "RPC faltando no app" \
  "RPCs do contrato faltando no SupabaseApiCliente: ['operacao_fantasma']" \
  --contrato "$TMPDIR_TESTE/Contrato/openapi-rpc-faltando.yaml" \
  --sources "$TMPDIR_TESTE/Sources"

# 3. RPC extra no app inexistente no contrato
cp -R "$TMPDIR_TESTE/Sources" "$TMPDIR_TESTE/Sources-rpc-extra"
# Injeta chamada rpc("rota_inventada") no SupabaseApiCliente
sed -i '' 's|rpc("minha_conta")|rpc("minha_conta"); _ = try await rpc("rota_inventada")|g' \
  "$TMPDIR_TESTE/Sources-rpc-extra/Dados/SupabaseApiCliente.swift"

esperar_reprovacao "RPC extra no app" \
  "RPCs extras no SupabaseApiCliente inexistentes no contrato: ['rota_inventada']" \
  --contrato "$CONTRATO_OFICIAL" \
  --sources "$TMPDIR_TESTE/Sources-rpc-extra"

# 4. Caso de Enum faltando no Swift
cp "$TMPDIR_TESTE/Contrato/openapi.yaml" "$TMPDIR_TESTE/Contrato/openapi-enum-faltando.yaml"
python3 -c "
caminho = '$TMPDIR_TESTE/Contrato/openapi-enum-faltando.yaml'
texto = open(caminho).read().replace('[publicada, preenchida, encerrada, cancelada]', '[publicada, preenchida, encerrada, cancelada, congelada]')
open(caminho, 'w').write(texto)
"

esperar_reprovacao "Enum com caso faltando no Swift" \
  "casos do contrato faltando no Swift: ['congelada']" \
  --contrato "$TMPDIR_TESTE/Contrato/openapi-enum-faltando.yaml" \
  --sources "$TMPDIR_TESTE/Sources"

# 5. Código de recusa do catálogo ausente em CodigoErroAPI
cp "$TMPDIR_TESTE/Contrato/openapi.yaml" "$TMPDIR_TESTE/Contrato/openapi-erro-faltando.yaml"
python3 -c "
caminho = '$TMPDIR_TESTE/Contrato/openapi-erro-faltando.yaml'
texto = open(caminho).read().replace('    | 429 | \`limite_excedido\` |', '    | 422 | \`fraude_detectada\` | Fraude |\n    | 429 | \`limite_excedido\` |')
open(caminho, 'w').write(texto)
"

esperar_reprovacao "Código de erro ausente em CodigoErroAPI" \
  "Códigos de recusa do catálogo OpenAPI ausentes em CodigoErroAPI: ['fraude_detectada']" \
  --contrato "$TMPDIR_TESTE/Contrato/openapi-erro-faltando.yaml" \
  --sources "$TMPDIR_TESTE/Sources"

# 6. DTO faltando campo obrigatório
cp "$TMPDIR_TESTE/Contrato/openapi.yaml" "$TMPDIR_TESTE/Contrato/openapi-dto-faltando.yaml"
python3 -c "
caminho = '$TMPDIR_TESTE/Contrato/openapi-dto-faltando.yaml'
texto = open(caminho).read().replace('required: [turno_id, resposta, criada_em]', 'required: [turno_id, resposta, criada_em, campo_novo_obrigatorio]')
open(caminho, 'w').write(texto)
"

esperar_reprovacao "DTO com campo obrigatório faltando" \
  "DTO AvaliacaoDTO (schema Avaliacao) tem campos obrigatórios faltando: ['campo_novo_obrigatorio']" \
  --contrato "$TMPDIR_TESTE/Contrato/openapi-dto-faltando.yaml" \
  --sources "$TMPDIR_TESTE/Sources"

# 7. Arquivo ausente
esperar_reprovacao "Contrato inexistente" \
  "FALHA: arquivo de contrato não encontrado" \
  --contrato "$TMPDIR_TESTE/nao-existe.yaml" \
  --sources "$TMPDIR_TESTE/Sources"

echo "OK: autoteste de contrato-ios-confere.sh (7 verificações completas com aprovação e reprovação controlada)."
