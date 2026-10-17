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
python3 -c "
caminho = '$TMPDIR_TESTE/Contrato/openapi-rpc-faltando.yaml'
texto = open(caminho).read().replace('/rpc/abrir_suporte:', '/rpc/operacao_fantasma:\n    post:\n      summary: Fantasma\n  /rpc/abrir_suporte:')
open(caminho, 'w').write(texto)
"

esperar_reprovacao "RPC faltando no app" \
  "RPCs do contrato faltando no SupabaseApiCliente: ['operacao_fantasma']" \
  --contrato "$TMPDIR_TESTE/Contrato/openapi-rpc-faltando.yaml" \
  --sources "$TMPDIR_TESTE/Sources"

# 3. RPC extra no app inexistente no contrato
cp -R "$TMPDIR_TESTE/Sources" "$TMPDIR_TESTE/Sources-rpc-extra"
python3 -c "
caminho = '$TMPDIR_TESTE/Sources-rpc-extra/Dados/SupabaseApiCliente.swift'
texto = open(caminho).read().replace('rpc(\"minha_conta\")', 'rpc(\"minha_conta\"); _ = try await rpc(\"rota_inventada\")')
open(caminho, 'w').write(texto)
"

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

# 8. Enum novo no contrato sem mapeamento no app
cp "$TMPDIR_TESTE/Contrato/openapi.yaml" "$TMPDIR_TESTE/Contrato/openapi-enum-novo.yaml"
python3 -c "
caminho = '$TMPDIR_TESTE/Contrato/openapi-enum-novo.yaml'
bloco = '\n    NovoEnumNaoMapeado:\n      type: string\n      enum: [caso_a, caso_b]\n'
texto = open(caminho).read().replace('  schemas:', '  schemas:' + bloco)
open(caminho, 'w').write(texto)
"

esperar_reprovacao "Enum novo não mapeado" \
  "Enum NovoEnumNaoMapeado do contrato OpenAPI não encontrado em nenhum arquivo Swift" \
  --contrato "$TMPDIR_TESTE/Contrato/openapi-enum-novo.yaml" \
  --sources "$TMPDIR_TESTE/Sources"

# 9. Schema de objeto novo no contrato sem mapeamento para DTO
cp "$TMPDIR_TESTE/Contrato/openapi.yaml" "$TMPDIR_TESTE/Contrato/openapi-schema-novo.yaml"
python3 -c "
caminho = '$TMPDIR_TESTE/Contrato/openapi-schema-novo.yaml'
bloco = '\n    NovoSchemaObjeto:\n      type: object\n      properties:\n        campo: { type: string }\n'
texto = open(caminho).read().replace('  schemas:', '  schemas:' + bloco)
open(caminho, 'w').write(texto)
"

esperar_reprovacao "Schema de objeto novo não mapeado" \
  "Schema de objeto NovoSchemaObjeto do contrato OpenAPI não possui struct/DTO correspondente no app Swift" \
  --contrato "$TMPDIR_TESTE/Contrato/openapi-schema-novo.yaml" \
  --sources "$TMPDIR_TESTE/Sources"

# 10. Enum com caso extra no Swift inexistente no contrato OpenAPI
cp -R "$TMPDIR_TESTE/Sources" "$TMPDIR_TESTE/Sources-enum-extra"
python3 -c "
caminho = '$TMPDIR_TESTE/Sources-enum-extra/Dominio/Modelos.swift'
texto = open(caminho).read().replace('case cancelada', 'case cancelada\n    case casoInexistenteNoContrato = \"caso_inexistente\"')
open(caminho, 'w').write(texto)
"

esperar_reprovacao "Enum com caso extra no Swift" \
  "casos extras no Swift inexistentes no contrato: ['caso_inexistente']" \
  --contrato "$CONTRATO_OFICIAL" \
  --sources "$TMPDIR_TESTE/Sources-enum-extra"

# 11. DTO extra no Swift inexistente no contrato OpenAPI (Item 3)
cp -R "$TMPDIR_TESTE/Sources" "$TMPDIR_TESTE/Sources-dto-extra"
python3 -c "
caminho = '$TMPDIR_TESTE/Sources-dto-extra/Dados/DTOsContrato.swift'
texto = open(caminho).read() + '\nstruct DTOInexistenteExtraDTO: Decodable { let campo: String }\n'
open(caminho, 'w').write(texto)
"

esperar_reprovacao "DTO extra no Swift inexistente no contrato" \
  "DTO DTOInexistenteExtraDTO no código Swift não possui schema ou operação correspondente no contrato OpenAPI" \
  --contrato "$CONTRATO_OFICIAL" \
  --sources "$TMPDIR_TESTE/Sources-dto-extra"

# 12. Campo extra em DTO no Swift não mapeado no schema do contrato
cp -R "$TMPDIR_TESTE/Sources" "$TMPDIR_TESTE/Sources-campo-extra"
python3 -c "
caminho = '$TMPDIR_TESTE/Sources-campo-extra/Dados/DTOsContrato.swift'
texto = open(caminho).read().replace('case turnoID = \"turno_id\"', 'case turnoID = \"turno_id\"; case campoFantasma = \"campo_fantasma\"')
open(caminho, 'w').write(texto)
"

esperar_reprovacao "Campo extra em DTO no Swift" \
  "DTO AvaliacaoDTO (schema Avaliacao): campos extras no Swift não permitidos pelo contrato: ['campo_fantasma']" \
  --contrato "$CONTRATO_OFICIAL" \
  --sources "$TMPDIR_TESTE/Sources-campo-extra"

# 13. Campo opcional no contrato não mapeado no Swift e não documentado como exceção (P6)
cp "$TMPDIR_TESTE/Contrato/openapi.yaml" "$TMPDIR_TESTE/Contrato/openapi-opcional-sem-excecao.yaml"
python3 -c "
caminho = '$TMPDIR_TESTE/Contrato/openapi-opcional-sem-excecao.yaml'
texto = open(caminho).read().replace('        criada_em:\n          \$ref: \'#/components/schemas/Instante\'', '        criada_em:\n          \$ref: \'#/components/schemas/Instante\'\n        campo_opcional_novo:\n          type: string')
open(caminho, 'w').write(texto)
"

esperar_reprovacao "Campo opcional novo no contrato sem exceção documentada" \
  "DTO AvaliacaoDTO (schema Avaliacao): campo opcional 'campo_opcional_novo' não mapeado no DTO nem documentado como exceção" \
  --contrato "$TMPDIR_TESTE/Contrato/openapi-opcional-sem-excecao.yaml" \
  --sources "$TMPDIR_TESTE/Sources"

echo "OK: autoteste de contrato-ios-confere.sh (13 verificações completas com aprovação e reprovação controlada)."

