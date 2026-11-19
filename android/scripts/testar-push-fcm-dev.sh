#!/usr/bin/env bash
# testar-push-fcm-dev.sh: Envia um push de teste FCM v1 contra o app Frila no emulador Android (Cartão llLCfQ7J).
#
# Uso:
#   scripts/testar-push-fcm-dev.sh [tipo] [titulo] [corpo]
#
# Pré-requisitos:
#   - Emulador Android rodando com o app Frila debug instalado e sessão ativa
#   - Credencial FCM de serviço em ~/.config/frila/fcm-service-account-dev.json
#   - Deno instalado

set -euo pipefail

FCM_SA="${FCM_SERVICE_ACCOUNT_PATH:-$HOME/.config/frila/fcm-service-account-dev.json}"
TIPO="${1:-vaga}"
TITULO="${2:-Nova vaga disponível}"
CORPO="${3:-Garçom no Plano Piloto hoje às 19h}"

if [ ! -f "$FCM_SA" ]; then
  echo "Erro: Credencial de serviço FCM não encontrada em $FCM_SA" >&2
  exit 1
fi

if ! command -v deno >/dev/null 2>&1; then
  echo "Erro: deno não está instalado" >&2
  exit 1
fi

ADB="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"
if [ ! -x "$ADB" ]; then
  if command -v adb >/dev/null 2>&1; then
    ADB="adb"
  else
    echo "Erro: adb não encontrado" >&2
    exit 1
  fi
fi

# Executa o envio via Deno sem exibir o token nem a chave privada
deno eval --allow-read --allow-net --allow-run "
import { getAccessToken, sendFcmMessage } from '/Users/cauecarneiro/Documents/Projetos/Frila/frila-backend/supabase/functions/enviar-push/fcm.ts';

const saText = await Deno.readTextFile('$FCM_SA');
const sa = JSON.parse(saText);

const cmd = new Deno.Command('$ADB', {
  args: ['logcat', '-d', '-s', 'FrilaFcmToken:V'],
});
const { stdout } = await cmd.output();
const logcatText = new TextDecoder().decode(stdout);
const match = logcatText.match(/token=([^\s\r\n]+)/);
if (!match) {
  console.error('Erro: Token FCM não encontrado no logcat do aparelho.');
  Deno.exit(1);
}
const token = match[1];

const accessToken = await getAccessToken(sa);

const res = await sendFcmMessage(sa.project_id, accessToken, {
  token,
  title: '$TITULO',
  body: '$CORPO',
  plataforma: 'android',
  data: {
    tipo: '$TIPO',
    titulo: '$TITULO',
    corpo: '$CORPO',
  },
});

if (res.ok) {
  console.log('Push FCM enviado com sucesso! HTTP status:', res.status, 'Message ID:', res.messageId);
} else {
  console.error('Falha no envio do push FCM:', res.status, res.error);
  Deno.exit(1);
}
"
