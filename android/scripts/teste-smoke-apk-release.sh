#!/usr/bin/env bash
# teste-smoke-apk-release.sh: Teste automatizado de mutação e comportamento para o script smoke-apk-release.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SMOKE_SCRIPT="$SCRIPT_DIR/smoke-apk-release.sh"

echo "==> Teste 1: Sintaxe bash do smoke-apk-release.sh"
bash -n "$SMOKE_SCRIPT"
echo "OK: Sintaxe válida."

echo "==> Teste 2: Permissão de execução"
[ -x "$SMOKE_SCRIPT" ] || { echo "FALHA: Script não é executável." >&2; exit 1; }
echo "OK: Script é executável."

echo "==> Teste 3: Falha quando o APK de release não existe"
set +e
SAIDA_SEM_APK=$("$SMOKE_SCRIPT" "/caminho/inexistente/app-release.apk" 2>&1)
CODIGO_SEM_APK=$?
set -e
[ $CODIGO_SEM_APK -ne 0 ] || { echo "FALHA: Deveria falhar na ausência do APK." >&2; exit 1; }
echo "$SAIDA_SEM_APK" | grep -q "não encontrado" || { echo "FALHA: Mensagem de erro incorreta." >&2; exit 1; }
echo "OK: Ausência de APK tratada corretamente."

# Criação de ambiente de teste com MOCK do adb
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

MOCK_APK="$TEMP_DIR/app-release.apk"
touch "$MOCK_APK"
MOCK_ADB="$TEMP_DIR/adb"

echo "==> Teste 4: Prova de detecção de crash fatal (FATAL EXCEPTION)"
cat <<'EOF' > "$MOCK_ADB"
#!/usr/bin/env bash
case "$*" in
  "logcat -c")
    exit 0
    ;;
  "install -r -d "*)
    exit 0
    ;;
  "shell am start -W -n br.com.frila.app/.MainActivity")
    echo "Starting: Intent { cmp=br.com.frila.app/.MainActivity }"
    exit 0
    ;;
  "logcat -d")
    echo "--------- beginning of main"
    echo "01-01 12:00:00.000  1000  1000 D AndroidRuntime: >>>>>> START com.android.internal.os.RuntimeInit uid 1000 <<<<<<"
    echo "01-01 12:00:01.000  1000  1000 E AndroidRuntime: FATAL EXCEPTION: main"
    echo "01-01 12:00:01.000  1000  1000 E AndroidRuntime: Process: br.com.frila.app, PID: 1234"
    echo "01-01 12:00:01.000  1000  1000 E AndroidRuntime: java.lang.RuntimeException: Crash proposital de teste de smoke"
    echo "01-01 12:00:01.000  1000  1000 E AndroidRuntime: 	at br.com.frila.app.MainActivity.onCreate(MainActivity.kt:42)"
    exit 0
    ;;
  "shell pidof br.com.frila.app")
    echo ""
    exit 1
    ;;
  *)
    exit 0
    ;;
esac
EOF
chmod +x "$MOCK_ADB"

set +e
SAIDA_CRASH=$(ADB="$MOCK_ADB" FRILA_SMOKE_SLEEP_SECONDS=0 "$SMOKE_SCRIPT" "$MOCK_APK" 2>&1)
CODIGO_CRASH=$?
set -e

[ $CODIGO_CRASH -ne 0 ] || { echo "FALHA: Script deveria falhar quando crash é detectado!" >&2; exit 1; }
echo "$SAIDA_CRASH" | grep -q "FALHA CRÍTICA: Crash detectado no APK de release" || {
  echo "FALHA: Mensagem de detecção de crash não encontrada." >&2
  exit 1
}
echo "$SAIDA_CRASH" | grep -q "Crash proposital de teste de smoke" || {
  echo "FALHA: Stacktrace do crash não exibido." >&2
  exit 1
}
echo "OK: Prova de falha do smoke passou com sucesso (crash fatal detectado e tratado com exit 1)."

echo "==> Teste 5: Sucesso quando o app inicia normalmente sem crash"
cat <<'EOF' > "$MOCK_ADB"
#!/usr/bin/env bash
case "$*" in
  "logcat -c")
    exit 0
    ;;
  "install -r -d "*)
    exit 0
    ;;
  "shell am start -W -n br.com.frila.app/.MainActivity")
    echo "Starting: Intent { cmp=br.com.frila.app/.MainActivity }"
    echo "Status: ok"
    echo "LaunchState: COLD"
    exit 0
    ;;
  "logcat -d")
    echo "01-01 12:00:00.000  1000  1000 I ActivityTaskManager: Displayed br.com.frila.app/.MainActivity: +450ms"
    exit 0
    ;;
  "shell pidof br.com.frila.app")
    echo "4321"
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
EOF
chmod +x "$MOCK_ADB"

SUMMARY_FILE="$TEMP_DIR/summary.md"
SAIDA_SUCESSO=$(ADB="$MOCK_ADB" FRILA_SMOKE_SLEEP_SECONDS=0 GITHUB_STEP_SUMMARY="$SUMMARY_FILE" "$SMOKE_SCRIPT" "$MOCK_APK")
echo "$SAIDA_SUCESSO" | grep -q "Sucesso! App ativo (PID: 4321)" || {
  echo "FALHA: Mensagem de sucesso não encontrada." >&2
  exit 1
}
[ -f "$SUMMARY_FILE" ] || { echo "FALHA: Arquivo GITHUB_STEP_SUMMARY não gerado." >&2; exit 1; }
grep -q "Smoke Test do APK de Release Minificado" "$SUMMARY_FILE" || {
  echo "FALHA: Resumo não contém cabeçalho esperado." >&2
  exit 1
}
echo "OK: Cenário de sucesso verificado perfeitamente com resumo gerado."

echo "TODOS OS 5 TESTES DO SMOKE TEST PASSARAM COM SUCESSO."
