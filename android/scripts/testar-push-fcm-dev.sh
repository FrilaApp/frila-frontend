#!/usr/bin/env bash
# testar-push-fcm-dev.sh: Envia um push de teste FCM v1 contra o app Frila no emulador Android (Cartão llLCfQ7J).
#
# Uso:
#   FCM_DEVICE_TOKEN="<token>" scripts/testar-push-fcm-dev.sh [tipo] [titulo] [corpo] [turno_id]
#   ou colocando o token em ~/.config/frila/android/fcm-device-token.txt
#
# Pré-requisitos:
#   - Emulador Android frila_api30 rodando com o app Frila instalado
#   - Credencial FCM de serviço em ~/.config/frila/fcm-service-account-dev.json
#   - Deno instalado

set -euo pipefail

FCM_SA="${FCM_SERVICE_ACCOUNT_PATH:-$HOME/.config/frila/fcm-service-account-dev.json}"
TIPO="${1:-vaga}"
TITULO="${2:-Nova vaga disponível}"
CORPO="${3:-Garçom no Plano Piloto hoje às 19h}"
TURNO_ID="${4:-${PUSH_TURNO_ID:-}}"

if [ ! -f "$FCM_SA" ]; then
  echo "Erro: Credencial de serviço FCM não encontrada em $FCM_SA" >&2
  exit 1
fi

if ! command -v deno >/dev/null 2>&1; then
  echo "Erro: deno não está instalado" >&2
  exit 1
fi

TOKEN="${FCM_DEVICE_TOKEN:-}"
TOKEN_FILE="${FCM_DEVICE_TOKEN_FILE:-$HOME/.config/frila/android/fcm-device-token.txt}"

if [ -z "$TOKEN" ] && [ -f "$TOKEN_FILE" ]; then
  TOKEN="$(cat "$TOKEN_FILE" | tr -d '\r\n[:space:]')"
fi

if [ -z "$TOKEN" ]; then
  echo "Erro: Token FCM do dispositivo não fornecido." >&2
  echo "Defina a variável FCM_DEVICE_TOKEN ou salve o token em $TOKEN_FILE" >&2
  exit 1
fi

export FCM_DEVICE_TOKEN="$TOKEN"
export FCM_SA_PATH="$FCM_SA"
export PUSH_TIPO="$TIPO"
export PUSH_TITULO="$TITULO"
export PUSH_CORPO="$CORPO"
export PUSH_TURNO_ID="$TURNO_ID"

deno eval --allow-read --allow-net --allow-env "
import { getAccessToken, sendFcmMessage } from '/Users/cauecarneiro/Documents/Projetos/Frila/frila-backend/supabase/functions/enviar-push/fcm.ts';

const saPath = Deno.env.get('FCM_SA_PATH');
const token = Deno.env.get('FCM_DEVICE_TOKEN');
const tipo = Deno.env.get('PUSH_TIPO') || 'vaga';
const titulo = Deno.env.get('PUSH_TITULO') || 'Notificação';
const corpo = Deno.env.get('PUSH_CORPO') || '';
const turnoId = Deno.env.get('PUSH_TURNO_ID') || '';

if (!saPath || !token) {
  console.error('Erro: Parâmetros obrigatórios ausentes.');
  Deno.exit(1);
}

const saText = await Deno.readTextFile(saPath);
const sa = JSON.parse(saText);

const accessToken = await getAccessToken(sa);

const res = await sendFcmMessage(sa.project_id, accessToken, {
  token,
  title: titulo,
  body: corpo,
  plataforma: 'android',
  data: {
    tipo,
    titulo,
    corpo,
    ...(turnoId ? { turno_id: turnoId } : {}),
  },
});

if (res.ok) {
  console.log('Push FCM enviado com sucesso! HTTP status:', res.status, 'Message ID:', res.messageId);
} else {
  console.error('Falha no envio do push FCM: status', res.status, res.error ? '(erro retornado)' : '');
  Deno.exit(1);
}
"
