#!/usr/bin/env bash
# teste-injetar-google-services.sh: Teste automatizado para o script injetar-google-services.sh (Cartão llLCfQ7J).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/injetar-google-services.sh"
ANDROID_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_DEV="$ANDROID_ROOT/app/src/debug/google-services.json"
TARGET_PROD="$ANDROID_ROOT/app/src/release/google-services.json"

TEMP_DEV=""
TEMP_PROD=""
if [ -f "$TARGET_DEV" ]; then
    TEMP_DEV="$(mktemp)"
    cp "$TARGET_DEV" "$TEMP_DEV"
fi
if [ -f "$TARGET_PROD" ]; then
    TEMP_PROD="$(mktemp)"
    cp "$TARGET_PROD" "$TEMP_PROD"
fi

cleanup() {
    rm -f "$TARGET_DEV" "$TARGET_PROD"
    if [ -n "$TEMP_DEV" ] && [ -f "$TEMP_DEV" ]; then
        mv "$TEMP_DEV" "$TARGET_DEV"
    fi
    if [ -n "$TEMP_PROD" ] && [ -f "$TEMP_PROD" ]; then
        mv "$TEMP_PROD" "$TARGET_PROD"
    fi
}
trap cleanup EXIT

echo "==> Teste 1: Verificação de sintaxe bash (bash -n)"
bash -n "$SCRIPT"
echo "OK: Sintaxe válida."

echo "==> Teste 2: Permissão de execução"
[ -x "$SCRIPT" ] || { echo "FALHA: Script não é executável." >&2; exit 1; }
echo "OK: Script é executável."

echo "==> Teste 3: Execução sem variáveis de ambiente (não deve falhar)"
SAIDA_VAZIA="$(env -u GOOGLE_SERVICES_DEV -u GOOGLE_SERVICES_PROD -u FRILA_GOOGLE_SERVICES_DEV_BASE64 -u FRILA_GOOGLE_SERVICES_PROD_BASE64 "$SCRIPT")"
echo "$SAIDA_VAZIA" | grep -q "Aviso: segredo para DEV (debug) não configurado" || {
    echo "FALHA: Mensagem de ausência do DEV não exibida." >&2
    exit 1
}
echo "$SAIDA_VAZIA" | grep -q "Aviso: segredo para PROD (release) não configurado" || {
    echo "FALHA: Mensagem de ausência do PROD não exibida." >&2
    exit 1
}
echo "OK: Execução limpa sem variáveis."

echo "==> Teste 4: Injeção com base64 sintético válido"
JSON_DEV='{"project_info":{"project_number":"123","project_id":"frila-dev-teste"},"client":[]}'
JSON_PROD='{"project_info":{"project_number":"456","project_id":"frila-prod-teste"},"client":[]}'
DEV_B64="$(printf '%s' "$JSON_DEV" | base64)"
PROD_B64="$(printf '%s' "$JSON_PROD" | base64)"

GOOGLE_SERVICES_DEV="$DEV_B64" GOOGLE_SERVICES_PROD="$PROD_B64" "$SCRIPT"

[ -f "$TARGET_DEV" ] || { echo "FALHA: Arquivo debug não foi criado." >&2; exit 1; }
[ -f "$TARGET_PROD" ] || { echo "FALHA: Arquivo release não foi criado." >&2; exit 1; }

python3 -m json.tool "$TARGET_DEV" >/dev/null
python3 -m json.tool "$TARGET_PROD" >/dev/null
echo "OK: Injeção de JSONs válidos concluída com sucesso."

echo "==> Teste 5: Rejeição de base64 inválido"
set +e
SAIDA_ERR=$(GOOGLE_SERVICES_DEV="isto_nao_e_base64_valido!@#" "$SCRIPT" 2>&1)
CODIGO=$?
set -e
[ $CODIGO -ne 0 ] || { echo "FALHA: Deveria falhar com base64 inválido." >&2; exit 1; }
echo "OK: Base64 inválido rejeitado com erro."

echo "==> Teste 6: Rejeição de JSON malformado"
set +e
B64_MALFORMADO=$(printf '%s' "{conteudo quebrado" | base64)
SAIDA_ERR=$(GOOGLE_SERVICES_DEV="$B64_MALFORMADO" "$SCRIPT" 2>&1)
CODIGO=$?
set -e
[ $CODIGO -ne 0 ] || { echo "FALHA: Deveria falhar com JSON quebrado." >&2; exit 1; }
echo "OK: JSON quebrado rejeitado com erro."

echo "TODOS OS TESTES PASSARAM COM SUCESSO."
