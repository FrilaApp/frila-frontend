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
for cmd in criar iniciar aguardar-boot medir-cold-start medir-jank medir-memoria status parar tudo; do
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

echo "==> Teste 6: 'aviso' e '--help' funcionam sem Android SDK configurado"
env -u ANDROID_HOME -u ANDROID_SDK_ROOT HOME=/nonexistent "$SCRIPT" aviso >/dev/null || {
    echo "FALHA: 'aviso' falhou quando SDK não está configurado." >&2
    exit 1
}
env -u ANDROID_HOME -u ANDROID_SDK_ROOT HOME=/nonexistent "$SCRIPT" --help >/dev/null || {
    echo "FALHA: '--help' falhou quando SDK não está configurado." >&2
    exit 1
}
echo "OK: 'aviso' e '--help' operam sem dependência de SDK configurado."

echo "==> Teste 7: Execução de 'medir-memoria' via mock ADB (dumpsys meminfo típico)"
MOCK_DIR="$(mktemp -d)"
trap 'rm -rf "$MOCK_DIR"' EXIT

cat <<'EOF' > "$MOCK_DIR/adb"
#!/usr/bin/env bash
if [ "$*" = "shell dumpsys meminfo br.com.frila.app" ]; then
    cat <<'MEM_EOF'
Applications Memory Usage (in Kilobytes):
Uptime: 1618693 Realtime: 1618693

** MEMINFO in pid 2451 [br.com.frila.app] **
                   Pss  Private  Private  SwapPss     Heap     Heap     Heap
                 Total    Dirty    Clean    Dirty     Size    Alloc     Free
                ------   ------   ------   ------   ------   ------   ------
  Native Heap    25412    25380        0        0    38912    29531     9380
  Dalvik Heap    31240    31180        0        0    42124    28450    13674
 Dalvik Other     3400     3200        0        0                           
        Stack     1024     1024        0        0                           
        TOTAL    95748    78132     9016        0    81036    57981    23054
 
 App Summary
                       Pss(KB)
                        ------
           Java Heap:    31180
         Native Heap:    25380
                Code:    16724
               Stack:     1024
            Graphics:    12000
       Private Other:     9520
              System:      920
 
           TOTAL PSS:    95748            TOTAL RSS:   128230       TOTAL SWAP PSS:        0
MEM_EOF
    exit 0
fi
exit 0
EOF
chmod +x "$MOCK_DIR/adb"

SAIDA_MEM="$(ADB="$MOCK_DIR/adb" "$SCRIPT" medir-memoria)"
echo "$SAIDA_MEM" | grep -q "Total PSS:   95748 KB" || {
    echo "FALHA: Total PSS não extraído corretamente (esperado 95748 KB). Saída:" >&2
    echo "$SAIDA_MEM" >&2
    exit 1
}
echo "$SAIDA_MEM" | grep -q "Native Heap: 25412 KB" || {
    echo "FALHA: Native Heap não extraído corretamente (esperado 25412 KB). Saída:" >&2
    echo "$SAIDA_MEM" >&2
    exit 1
}
echo "$SAIDA_MEM" | grep -q "Dalvik Heap: 31240 KB" || {
    echo "FALHA: Dalvik Heap não extraído corretamente (esperado 31240 KB). Saída:" >&2
    echo "$SAIDA_MEM" >&2
    exit 1
}
echo "$SAIDA_MEM" | grep -q "Status: CONFORME" || {
    echo "FALHA: Status CONFORME esperado para valores abaixo do teto RNF04." >&2
    echo "$SAIDA_MEM" >&2
    exit 1
}
echo "OK: 'medir-memoria' com mock ADB validado com sucesso (PSS, Native e Dalvik corretos)."

echo "==> Teste 8: Detecção de alerta em 'medir-memoria' quando excede teto RNF04"
cat <<'EOF' > "$MOCK_DIR/adb"
#!/usr/bin/env bash
if [ "$*" = "shell dumpsys meminfo br.com.frila.app" ]; then
    cat <<'MEM_EOF'
** MEMINFO in pid 2451 [br.com.frila.app] **
                   Pss  Private  Private  SwapPss     Heap     Heap     Heap
                 Total    Dirty    Clean    Dirty     Size    Alloc     Free
                ------   ------   ------   ------   ------   ------   ------
  Native Heap    50000    50000        0        0    60000    50000    10000
  Dalvik Heap   270000   270000        0        0   280000   270000    10000
        TOTAL   350000   340000        0        0   340000   320000    20000
MEM_EOF
    exit 0
fi
exit 0
EOF
chmod +x "$MOCK_DIR/adb"

SAIDA_ALERTA="$(ADB="$MOCK_DIR/adb" "$SCRIPT" medir-memoria)"
echo "$SAIDA_ALERTA" | grep -q "Status: ALERTA" || {
    echo "FALHA: Status ALERTA esperado quando consumo de memória excede o teto. Saída:" >&2
    echo "$SAIDA_ALERTA" >&2
    exit 1
}
echo "OK: Alerta por consumo acima do teto RNF04 validado."

echo "==> Teste 9: Inclusão de 'medir-memoria' no comando 'tudo'"
grep -A 15 "fluxo_completo()" "$SCRIPT" | grep -q "medir_memoria" || {
    echo "FALHA: 'medir_memoria' não encontrado em fluxo_completo (comando tudo)." >&2
    exit 1
}
echo "OK: 'medir-memoria' integrado ao comando 'tudo'."

echo "==> Teste 10: Prevenção de aborto por bash -e em 'am force-stop'"
grep -E "am force-stop.*\|\| true" "$SCRIPT" >/dev/null || {
    echo "FALHA: 'am force-stop' não possui '|| true' para prevenir aborto em bash -e." >&2
    exit 1
}
echo "OK: 'am force-stop' protegido contra falha em bash -e."

echo "==> Todos os testes do script de dispositivo de referência passaram com sucesso!"
