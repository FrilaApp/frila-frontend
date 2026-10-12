#!/bin/bash
# simular-push.sh: Envia push simulado via `xcrun simctl push` para o iOS Simulator (#8).
#
# Uso:
#   Scripts/simular-push.sh <tipo|arquivo.apns> [UDID]
#   Scripts/simular-push.sh --validar
#
# Tipos pré-definidos (em Tests/Fixtures/Push/):
#   - vaga: Notificação de nova vaga aberta
#   - confirmacao: Notificação de turno confirmado para o profissional
#   - checkin: Notificação de check-in manual pendente para o contratante
#   - lembrete: Lembrete de turno iminente (3h)
#   - cancelamento: Aviso de cancelamento de turno
#
# Se o UDID não for passado, usa o primeiro simulador com status Booted.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/../Tests/Fixtures/Push"
BUNDLE_ID="com.frila.org.app"

falhar() {
  echo "ERRO: $*" >&2
  exit 1
}

validar_arquivo_apns() {
  local arq="$1"
  [[ -f "$arq" ]] || falhar "Arquivo não encontrado: $arq"
  
  python3 - "$arq" <<'PY'
import json, sys
caminho = sys.argv[1]
try:
    with open(caminho, 'r', encoding='utf-8') as f:
        dados = json.load(f)
except Exception as e:
    sys.exit(f"JSON inválido em {caminho}: {e}")

if not isinstance(dados, dict):
    sys.exit(f"Payload deve ser um objeto JSON: {caminho}")

if "aps" not in dados or not isinstance(dados["aps"], dict):
    sys.exit(f"Falta objeto 'aps' obrigatório: {caminho}")

if "tipo" not in dados or not isinstance(dados["tipo"], str):
    sys.exit(f"Falta string 'tipo' obrigatória no payload Frila: {caminho}")

target_bundle = dados.get("Simulator Target Bundle")
if target_bundle and target_bundle != "com.frila.org.app":
    sys.exit(f"Simulator Target Bundle inválido ({target_bundle}): {caminho}")
PY
}

validar_todos() {
  echo "Validando fixtures de push em $FIXTURES_DIR..."
  local count=0
  for arq in "$FIXTURES_DIR"/*.apns; do
    [[ -f "$arq" ]] || continue
    validar_arquivo_apns "$arq"
    echo "  OK: $(basename "$arq")"
    count=$((count + 1))
  done
  [[ $count -gt 0 ]] || falhar "Nenhum arquivo .apns encontrado em $FIXTURES_DIR"
  echo "Todos os $count arquivos .apns estão válidos."
}

if [[ "${1:-}" == "--validar" ]]; then
  validar_todos
  exit 0
fi

if [[ $# -lt 1 ]]; then
  echo "uso: $0 <tipo|arquivo.apns> [UDID]" >&2
  echo "      $0 --validar" >&2
  exit 1
fi

ALVO="$1"
UDID="${2:-}"

# Mapeia tipo para arquivo de fixture
ARQUIVO_PAYLOAD=""
case "$ALVO" in
  vaga) ARQUIVO_PAYLOAD="$FIXTURES_DIR/vaga.apns" ;;
  confirmacao) ARQUIVO_PAYLOAD="$FIXTURES_DIR/confirmacao-profissional.apns" ;;
  checkin) ARQUIVO_PAYLOAD="$FIXTURES_DIR/checkin-manual-contratante.apns" ;;
  lembrete) ARQUIVO_PAYLOAD="$FIXTURES_DIR/lembrete-turno.apns" ;;
  cancelamento) ARQUIVO_PAYLOAD="$FIXTURES_DIR/cancelamento.apns" ;;
  *)
    if [[ -f "$ALVO" ]]; then
      ARQUIVO_PAYLOAD="$ALVO"
    elif [[ -f "$FIXTURES_DIR/$ALVO.apns" ]]; then
      ARQUIVO_PAYLOAD="$FIXTURES_DIR/$ALVO.apns"
    else
      falhar "Tipo ou arquivo de push desconhecido: '$ALVO'. Tipos suportados: vaga, confirmacao, checkin, lembrete, cancelamento."
    fi
    ;;
esac

validar_arquivo_apns "$ARQUIVO_PAYLOAD"

if [[ -z "$UDID" ]]; then
  # Procura simulador ligado
  UDID="$(xcrun simctl list devices | grep "(Booted)" | head -n 1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/' || true)"
  if [[ -z "$UDID" ]]; then
    falhar "Nenhum simulador com status Booted encontrado. Informe o UDID explicitamente ou ligue o simulador."
  fi
fi

echo "Disparando push para simulador $UDID com $(basename "$ARQUIVO_PAYLOAD")..."
xcrun simctl push "$UDID" "$BUNDLE_ID" "$ARQUIVO_PAYLOAD"
echo "Push enviado com sucesso."
