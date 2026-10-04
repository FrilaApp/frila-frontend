#!/bin/bash
# Roda a auditoria automática de acessibilidade (AuditoriaDeAcessibilidadeUITests) nas três
# passadas que o #71 pede: tamanho padrão e AX5 (os dois já estão na suíte) e Reduzir Movimento,
# que é a mesma suíte com a preferência ligada no simulador, porque o XCTest não tem argumento
# de lançamento para ela. A preferência volta ao que era no fim, mesmo com falha.
#
# A suíte é opcional (XCTSkip na suíte normal e na CI): este script a liga com
# TEST_RUNNER_FRILA_AUDITORIA_DE_ACESSIBILIDADE=1. Cada passada leva cerca de 9 minutos.
#
# Uso: Scripts/auditoria-de-acessibilidade.sh <UDID do simulador> [pasta-de-saida]
#   Com FRILA_AUDITORIA_SO_REGISTRA=1, a suíte só registra os achados (linhas `AUDITORIA|…` no
#   log), sem falhar: é o modo para levantar o relatório de Docs/Acessibilidade.md.
set -euo pipefail

UDID="${1:?informe o UDID do simulador}"
SAIDA="${2:-$(mktemp -d -t frila-auditoria)}"
cd "$(dirname "$0")/.."
mkdir -p "$SAIDA"

PREFERENCIA_ANTES="$(xcrun simctl spawn "$UDID" defaults read com.apple.Accessibility ReduceMotionEnabled 2>/dev/null || echo 0)"
restaurar() {
  xcrun simctl spawn "$UDID" defaults write com.apple.Accessibility ReduceMotionEnabled -bool "$([[ "$PREFERENCIA_ANTES" == 1 ]] && echo true || echo false)"
}
trap restaurar EXIT

rodar() {
  local passada="$1"
  echo "== auditoria: $passada"
  env TEST_RUNNER_FRILA_AUDITORIA_DE_ACESSIBILIDADE=1 \
    TEST_RUNNER_FRILA_AUDITORIA_SO_REGISTRA="${FRILA_AUDITORIA_SO_REGISTRA:-0}" \
    xcodebuild test -project Frila.xcodeproj -scheme Frila-Local \
    -destination "platform=iOS Simulator,id=$UDID" \
    -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests \
    -resultBundlePath "$SAIDA/$passada.xcresult" \
    | tee "$SAIDA/$passada.log" | grep -E '^AUDITORIA\||Test Case .* (passed|failed)|\*\* TEST' || true
}

xcrun simctl spawn "$UDID" defaults write com.apple.Accessibility ReduceMotionEnabled -bool false
rodar "padrao-e-ax5"

xcrun simctl spawn "$UDID" defaults write com.apple.Accessibility ReduceMotionEnabled -bool true
rodar "reduzir-movimento"

echo "Logs e result bundles em $SAIDA"
