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

echo "==> Teste 3: Execução sem variáveis em PR/local (deve gerar placeholder sintético para release)"
rm -f "$TARGET_DEV" "$TARGET_PROD"
SAIDA_VAZIA="$(env -u GOOGLE_SERVICES_DEV -u GOOGLE_SERVICES_PROD -u FRILA_GOOGLE_SERVICES_DEV_BASE64 -u FRILA_GOOGLE_SERVICES_PROD_BASE64 -u GITHUB_REF -u GITHUB_EVENT_NAME -u FRILA_EXIGE_PROD_RELEASE "$SCRIPT")"
echo "$SAIDA_VAZIA" | grep -q "Aviso: segredo para DEV (debug) não configurado" || {
    echo "FALHA: Mensagem de ausência do DEV não exibida." >&2
    exit 1
}
echo "$SAIDA_VAZIA" | grep -q "placeholder sintético" || {
    echo "FALHA: Mensagem de placeholder sintético não exibida." >&2
    exit 1
}
[ -f "$TARGET_PROD" ] || { echo "FALHA: Placeholder de release não foi criado." >&2; exit 1; }
grep -q "\.invalid" "$TARGET_PROD" || { echo "FALHA: Placeholder não contém sufixo .invalid." >&2; exit 1; }
python3 -m json.tool "$TARGET_PROD" >/dev/null
echo "OK: Placeholder sintético gerado e validado."

echo "==> Teste 4: Garantia de isolamento (DEV nunca é copiado para release)"
rm -f "$TARGET_DEV" "$TARGET_PROD"
JSON_DEV_EXCLUSIVO='{"project_info":{"project_number":"111","project_id":"frila-dev-exclusivo-nunca-vai-pro-release"},"client":[]}'
DEV_EXCLUSIVO_B64="$(printf '%s' "$JSON_DEV_EXCLUSIVO" | base64)"
env -u GOOGLE_SERVICES_PROD -u FRILA_GOOGLE_SERVICES_PROD_BASE64 -u GITHUB_REF -u GITHUB_EVENT_NAME -u FRILA_EXIGE_PROD_RELEASE \
  GOOGLE_SERVICES_DEV="$DEV_EXCLUSIVO_B64" "$SCRIPT"

[ -f "$TARGET_DEV" ] || { echo "FALHA: Arquivo debug não criado." >&2; exit 1; }
[ -f "$TARGET_PROD" ] || { echo "FALHA: Arquivo release não criado." >&2; exit 1; }
grep -q "frila-dev-exclusivo-nunca-vai-pro-release" "$TARGET_DEV" || { echo "FALHA: Debug não contém dados de DEV." >&2; exit 1; }
if grep -q "frila-dev-exclusivo-nunca-vai-pro-release" "$TARGET_PROD"; then
    echo "FALHA CRÍTICA: Dados de DEV vazaram para o release!" >&2
    exit 1
fi
grep -q "\.invalid" "$TARGET_PROD" || { echo "FALHA: Release deveria conter placeholder .invalid." >&2; exit 1; }
echo "OK: Isolamento perfeito (DEV nunca copiado para release)."

echo "==> Teste 5: Rejeição estrita em release distribuível sem PROD"
set +e
SAIDA_RELEASE_ERR=$(env -u GOOGLE_SERVICES_PROD -u FRILA_GOOGLE_SERVICES_PROD_BASE64 \
  FRILA_EXIGE_PROD_RELEASE="true" "$SCRIPT" 2>&1)
CODIGO_RELEASE=$?
set -e
[ $CODIGO_RELEASE -ne 0 ] || { echo "FALHA: Deveria falhar na ausência de PROD em release distribuível." >&2; exit 1; }
echo "$SAIDA_RELEASE_ERR" | grep -q "Erro: GOOGLE_SERVICES_PROD ausente em build de release distribuível" || {
    echo "FALHA: Mensagem de erro de release distribuível não exibida." >&2
    exit 1
}
echo "OK: Falha segura garantida em build de release distribuível sem PROD."

echo "==> Teste 6: Injeção com ambos base64 válidos (DEV e PROD)"
rm -f "$TARGET_DEV" "$TARGET_PROD"
JSON_DEV='{"project_info":{"project_number":"123","project_id":"frila-dev-teste"},"client":[]}'
JSON_PROD='{"project_info":{"project_number":"456","project_id":"frila-prod-teste"},"client":[]}'
DEV_B64="$(printf '%s' "$JSON_DEV" | base64)"
PROD_B64="$(printf '%s' "$JSON_PROD" | base64)"

GOOGLE_SERVICES_DEV="$DEV_B64" GOOGLE_SERVICES_PROD="$PROD_B64" "$SCRIPT"

[ -f "$TARGET_DEV" ] || { echo "FALHA: Arquivo debug não foi criado." >&2; exit 1; }
[ -f "$TARGET_PROD" ] || { echo "FALHA: Arquivo release não foi criado." >&2; exit 1; }
grep -q "frila-dev-teste" "$TARGET_DEV" || { echo "FALHA: Debug não contém JSON de dev." >&2; exit 1; }
grep -q "frila-prod-teste" "$TARGET_PROD" || { echo "FALHA: Release não contém JSON de prod." >&2; exit 1; }
python3 -m json.tool "$TARGET_DEV" >/dev/null
python3 -m json.tool "$TARGET_PROD" >/dev/null
echo "OK: Injeção de DEV e PROD válidos concluída com sucesso."

echo "==> Teste 7: Rejeição de base64 inválido"
set +e
SAIDA_ERR=$(GOOGLE_SERVICES_DEV="isto_nao_e_base64_valido!@#" "$SCRIPT" 2>&1)
CODIGO=$?
set -e
[ $CODIGO -ne 0 ] || { echo "FALHA: Deveria falhar com base64 inválido." >&2; exit 1; }
echo "OK: Base64 inválido rejeitado com erro."

echo "==> Teste 8: Rejeição de JSON malformado"
set +e
B64_MALFORMADO=$(printf '%s' "{conteudo quebrado" | base64)
SAIDA_ERR=$(GOOGLE_SERVICES_DEV="$B64_MALFORMADO" "$SCRIPT" 2>&1)
CODIGO=$?
set -e
[ $CODIGO -ne 0 ] || { echo "FALHA: Deveria falhar com JSON quebrado." >&2; exit 1; }
echo "OK: JSON quebrado rejeitado com erro."

echo "TODOS OS 8 TESTES PASSARAM COM SUCESSO."
