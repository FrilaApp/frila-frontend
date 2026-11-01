#!/usr/bin/env bash
# Teste automatizado para o script do dispositivo de referência (Cartão 58).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/dispositivo-referencia.sh"

echo "==> Teste 1: Verificação de sintaxe bash (bash -n)"
bash -n "$SCRIPT"
echo "OK: Sintaxe válida."

echo "==> Teste 2: Permissão de execução"
[ -x "$SCRIPT" ] || { echo "FALHA: Script não é executável." >&2; exit 1; }
echo "OK: Script é executável."

echo "==> Teste 3: Exibição do aviso normativo de emulador vs aparelho real"
SAIDA_AVISO="$("$SCRIPT" aviso)"
echo "$SAIDA_AVISO" | grep -q "AVISO DE HOMOLOGAÇÃO: MEDIÇÃO EM EMULADOR" || {
    echo "FALHA: Aviso normativo não encontrado na saída do comando aviso." >&2
    exit 1
}
echo "$SAIDA_AVISO" | grep -q "NÃO É APARELHO FÍSICO" || {
    echo "FALHA: Advertência explícita sobre aparelho físico ausente." >&2
    exit 1
}
echo "$SAIDA_AVISO" | grep -q "atribuição de pessoa" || {
    echo "FALHA: Menção de prerrogativa de pessoa não encontrada." >&2
    exit 1
}
echo "OK: Aviso normativo validado com sucesso."

echo "==> Teste 4: Verificação de comandos na ajuda"
SAIDA_AJUDA="$("$SCRIPT" --help)"
for cmd in criar iniciar aguardar-boot medir-cold-start medir-jank status parar tudo; do
    echo "$SAIDA_AJUDA" | grep -q "$cmd" || {
        echo "FALHA: Comando '$cmd' não documentado na ajuda." >&2
        exit 1
    }
done
echo "OK: Todos os comandos documentados na ajuda."

echo "==> Teste 5: Conformidade dos parâmetros técnicos do RNF04"
grep -q "RAM_SIZE_MB=2048" "$SCRIPT" || { echo "FALHA: RAM deve ser 2048 MB." >&2; exit 1; }
grep -q "API_LEVEL=28" "$SCRIPT" || { echo "FALHA: API level deve ser 28." >&2; exit 1; }
grep -q "720" "$SCRIPT" || { echo "FALHA: Resolução 720p não configurada." >&2; exit 1; }
echo "OK: Parâmetros do RNF04 (API 28, 2048 MB, 720p) verificados."

echo "==> Todos os testes do script de dispositivo de referência passaram com sucesso!"
