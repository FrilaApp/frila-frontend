#!/usr/bin/env bash
# smoke-apk-release.sh: Instala o APK de release minificado no emulador Android e valida se abre sem crash (Cartão 7ekYEzOl).
#
# Uso:
#   scripts/smoke-apk-release.sh [caminho_apk]
#
# Pré-requisitos:
#   - Emulador Android ativo via adb
#   - APK de release minificado assinado (para smoke) gerado em app/build/outputs/apk/release/app-release.apk

set -euo pipefail

INICIO=$(date +%s)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

APK_PATH="${1:-$ANDROID_DIR/app/build/outputs/apk/release/app-release.apk}"

ADB="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"
if [ ! -x "$ADB" ]; then
  if command -v adb >/dev/null 2>&1; then
    ADB="adb"
  else
    echo "Erro: adb não encontrado" >&2
    exit 1
  fi
fi

if [ ! -f "$APK_PATH" ]; then
  echo "Erro: APK de release não encontrado em $APK_PATH" >&2
  exit 1
fi

echo "==> [Smoke Release] Limpando logcat anterior..."
"$ADB" logcat -c || true

echo "==> [Smoke Release] Instalando APK de release ($APK_PATH)..."
"$ADB" install -r -d "$APK_PATH"

echo "==> [Smoke Release] Iniciando MainActivity (am start -W)..."
"$ADB" shell am start -W -n br.com.frila.app/.MainActivity

TEMPO_ESPERA="${FRILA_SMOKE_SLEEP_SECONDS:-10}"
echo "==> [Smoke Release] Aguardando ${TEMPO_ESPERA} segundos para estabilização do app..."
sleep "$TEMPO_ESPERA"

echo "==> [Smoke Release] Verificando logs do logcat em busca de crashes..."
# Filtra apenas ocorrências de crash fatal
CRASH_DETECTADO="$("$ADB" logcat -d | grep -E -A 30 "FATAL EXCEPTION|AndroidRuntime: FATAL" || true)"

if [ -n "$CRASH_DETECTADO" ]; then
  echo "FALHA CRÍTICA: Crash detectado no APK de release durante o smoke test!" >&2
  echo "------------------- LINHAS DO CRASH -------------------" >&2
  echo "$CRASH_DETECTADO" >&2
  echo "-------------------------------------------------------" >&2
  exit 1
fi

# Confere se o processo permanece vivo
PID="$("$ADB" shell pidof br.com.frila.app || true)"
if [ -z "$PID" ]; then
  echo "FALHA: Processo br.com.frila.app não está ativo após 10 segundos." >&2
  CRASH_FALLBACK="$("$ADB" logcat -d | grep -E -A 30 "FATAL EXCEPTION|AndroidRuntime: FATAL" || true)"
  if [ -n "$CRASH_FALLBACK" ]; then
    echo "$CRASH_FALLBACK" >&2
  fi
  exit 1
fi

FIM=$(date +%s)
DURACAO=$((FIM - INICIO))

echo "==> [Smoke Release] Sucesso! App ativo (PID: $PID) sem erros fatais em ${DURACAO}s."

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  cat <<EOF >> "$GITHUB_STEP_SUMMARY"
### Smoke Test do APK de Release Minificado (Emulador)
- **Status**: ✅ Sucesso (sem crash / sem FATAL EXCEPTION)
- **Duração da etapa**: ${DURACAO}s
- **Pacote**: \`br.com.frila.app\` (PID ativo: $PID)
- **APK**: \`$(basename "$APK_PATH")\`
EOF
fi
