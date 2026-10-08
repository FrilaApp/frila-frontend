#!/bin/bash
# Arquiva, assina, confere e manda o Frila ao TestFlight (#203). É o mesmo caminho na CI
# (.github/workflows/testflight.yml) e na máquina de quem precisar reproduzir o envio.
#
# Uso: Scripts/enviar-testflight.sh <Frila-Beta|Frila-Prod> <versão X.Y.Z> [--sem-envio]
#
#   --sem-envio   para depois da conferência e dos símbolos: o .ipa assinado fica em
#                 $FRILA_SAIDA/exportado e nada vai ao App Store Connect.
#
# Variáveis de ambiente:
#   ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID   chave da App Store Connect API (.p8, Key ID e Issuer
#       ID). Sem as três, o xcodebuild usa a conta logada no Xcode da máquina; na CI elas são
#       obrigatórias.
#   FRILA_NUMERO_DO_BUILD   número do build. Padrão: AAAAMMDD.HHMMSS em UTC, no início da execução.
#   FRILA_ENSAIO_FALHA=1    build de ensaio: compila o botão "Forçar falha (ensaio)" e marca o build
#       como só para teste interno (não vai a testador externo nem à App Store).
#   FRILA_MEDICAO=1         build de medição (#73): compila a medição de desempenho e de dados
#       (Docs/Desempenho.md) e marca o build como só para teste interno.
#   FRILA_SAIDA             pasta de trabalho. Padrão: $TMPDIR/frila-testflight.
#   FRILA_DERIVED_DATA      DerivedData. Padrão: o do Xcode para este projeto.
#
# Antes de rodar: Configurations/Secrets.xcconfig (Scripts/generate-supabase-secrets.sh) e o
# GoogleService-Info.plist do ambiente (Scripts/inject-firebase-config.sh). O passo a passo está em
# Docs/CI.md, seção "Mandar um build ao TestFlight".

set -euo pipefail

falhar() {
  echo "error: $*" >&2
  exit 1
}

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ $# -ge 2 ]] || falhar "uso: $0 <Frila-Beta|Frila-Prod> <versão X.Y.Z> [--sem-envio]"
ESQUEMA="$1"
VERSAO="$2"
shift 2
ENVIAR=1
for opcao in "$@"; do
  case "$opcao" in
    --sem-envio) ENVIAR=0 ;;
    *) falhar "opção desconhecida: $opcao" ;;
  esac
done

case "$ESQUEMA" in
  Frila-Beta) AMBIENTE=frila-dev; AMBIENTE_FIREBASE=Dev ;;
  Frila-Prod) AMBIENTE=frila-prod; AMBIENTE_FIREBASE=Prod ;;
  *) falhar "o esquema deve ser Frila-Beta ou Frila-Prod (recebido: $ESQUEMA)" ;;
esac
[[ "$VERSAO" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || falhar "a versão deve ter o formato X.Y.Z (recebido: $VERSAO)"

# Número do build: data e hora UTC do início, AAAAMMDD.HHMMSS, sem zero à esquerda na segunda parte.
# É único e crescente entre execuções, reexecuções e máquinas, sem consultar o App Store Connect, e
# diz no TestFlight e no Crashlytics quando o build foi feito.
if [[ -z "${FRILA_NUMERO_DO_BUILD:-}" ]]; then
  read -r dia hora < <(date -u '+%Y%m%d %H%M%S')
  FRILA_NUMERO_DO_BUILD="$dia.$((10#$hora))"
fi
[[ "$FRILA_NUMERO_DO_BUILD" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] ||
  falhar "o número do build deve ter de um a três inteiros separados por ponto (recebido: $FRILA_NUMERO_DO_BUILD)"

ENSAIO="${FRILA_ENSAIO_FALHA:-0}"
[[ "$ENSAIO" == 0 || "$ENSAIO" == 1 ]] || falhar "FRILA_ENSAIO_FALHA deve ser 0 ou 1 (recebido: $ENSAIO)"
MEDICAO="${FRILA_MEDICAO:-0}"
[[ "$MEDICAO" == 0 || "$MEDICAO" == 1 ]] || falhar "FRILA_MEDICAO deve ser 0 ou 1 (recebido: $MEDICAO)"

EQUIPE="$(sed -n 's/^ *DEVELOPMENT_TEAM: *//p' "$RAIZ/project.yml" | head -1)"
[[ -n "$EQUIPE" ]] || falhar "DEVELOPMENT_TEAM não encontrado no project.yml"

PLIST_FIREBASE="$RAIZ/Resources/Firebase/$AMBIENTE_FIREBASE/GoogleService-Info.plist"
[[ -f "$PLIST_FIREBASE" ]] ||
  falhar "falta o GoogleService-Info.plist de $AMBIENTE_FIREBASE: sem ele o build não tem Crashlytics. Rode Scripts/inject-firebase-config.sh"

autenticacao=(-allowProvisioningUpdates)
if [[ -n "${ASC_KEY_PATH:-}${ASC_KEY_ID:-}${ASC_ISSUER_ID:-}" ]]; then
  [[ -f "${ASC_KEY_PATH:-}" && -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]] ||
    falhar "a chave da App Store Connect API precisa das três variáveis: ASC_KEY_PATH (arquivo .p8), ASC_KEY_ID e ASC_ISSUER_ID"
  autenticacao+=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
elif [[ -n "${CI:-}" ]]; then
  falhar "na CI o envio exige a chave da App Store Connect API (ASC_KEY_PATH, ASC_KEY_ID e ASC_ISSUER_ID)"
fi

derived=()
if [[ -n "${FRILA_DERIVED_DATA:-}" ]]; then
  derived=(-derivedDataPath "$FRILA_DERIVED_DATA" -clonedSourcePackagesDirPath "$FRILA_DERIVED_DATA/SourcePackages")
fi

SAIDA="${FRILA_SAIDA:-${TMPDIR:-/tmp}/frila-testflight}"
ARCHIVE="$SAIDA/Frila.xcarchive"
EXPORTADO="$SAIDA/exportado"
IPA_ABERTO="$SAIDA/ipa"
mkdir -p "$SAIDA"
rm -rf "$ARCHIVE" "$EXPORTADO" "$IPA_ABERTO" "$SAIDA/envio"

formatar() {
  if command -v xcbeautify >/dev/null; then xcbeautify; else cat; fi
}

descricao="$ESQUEMA $VERSAO ($FRILA_NUMERO_DO_BUILD), $AMBIENTE"
[[ "$ENSAIO" == 0 ]] || descricao="$descricao, ensaio de falha"
[[ "$MEDICAO" == 0 ]] || descricao="$descricao, medição"
echo "Frila: $descricao"

# 1. Archive, com a assinatura automática de desenvolvimento do projeto. Com
# -allowProvisioningUpdates o xcodebuild cria o que faltar (perfil e certificado), pela chave da API
# ou pela conta do Xcode. A assinatura ad hoc não serve: o Xcode exige perfil para o app iOS.
# CI=1 desliga a fase do Xcode que envia os símbolos ao Crashlytics: o envio é o passo 4 deste script.
ajustes=(
  MARKETING_VERSION="$VERSAO"
  CURRENT_PROJECT_VERSION="$FRILA_NUMERO_DO_BUILD"
)
condicoes=''
[[ "$ENSAIO" == 0 ]] || condicoes+=' FRILA_ENSAIO_FALHA'
[[ "$MEDICAO" == 0 ]] || condicoes+=' FRILA_MEDICAO'
if [[ -n "$condicoes" ]]; then
  # shellcheck disable=SC2016 # $(inherited) é do Xcode, não do shell.
  ajustes+=('SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited)'"$condicoes")
fi

if [[ ! -d "$RAIZ/Frila.xcodeproj" ]]; then
  echo "Frila.xcodeproj não encontrado. Gerando com Scripts/gerar-projeto.sh..."
  "$RAIZ/Scripts/gerar-projeto.sh"
fi

CI="${CI:-1}" xcodebuild archive \
  -project "$RAIZ/Frila.xcodeproj" \
  -scheme "$ESQUEMA" \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  ${derived[@]+"${derived[@]}"} \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile \
  "${autenticacao[@]}" \
  "${ajustes[@]}" | formatar

APP_ARQUIVADO="$ARCHIVE/Products/Applications/Frila.app"
[[ -d "$APP_ARQUIVADO" ]] || falhar "o archive não contém Frila.app: $APP_ARQUIVADO"
lido() { /usr/libexec/PlistBuddy -c "Print :$1" "$APP_ARQUIVADO/Info.plist" 2>/dev/null || true; }
[[ "$(lido CFBundleShortVersionString)" == "$VERSAO" ]] || falhar "versão do archive: $(lido CFBundleShortVersionString); esperada: $VERSAO"
[[ "$(lido CFBundleVersion)" == "$FRILA_NUMERO_DO_BUILD" ]] || falhar "build do archive: $(lido CFBundleVersion); esperado: $FRILA_NUMERO_DO_BUILD"
[[ "$(lido FRILA_ENVIRONMENT)" == "$AMBIENTE" ]] || falhar "ambiente do archive: $(lido FRILA_ENVIRONMENT); esperado: $AMBIENTE"

# A extensão de notificação (#253) tem de estar no archive com a mesma versão e o mesmo build do
# app: a App Store recusa o envio em que divergem, e sem ela o push de outro vínculo sai inteiro
# na tela de bloqueio.
EXTENSAO_ARQUIVADA="$APP_ARQUIVADO/PlugIns/FrilaNotificationService.appex"
[[ -d "$EXTENSAO_ARQUIVADA" ]] || falhar "o archive não contém a extensão de notificação: $EXTENSAO_ARQUIVADA"
lido_da_extensao() { /usr/libexec/PlistBuddy -c "Print :$1" "$EXTENSAO_ARQUIVADA/Info.plist" 2>/dev/null || true; }
[[ "$(lido_da_extensao CFBundleShortVersionString)" == "$VERSAO" ]] || falhar "versão da extensão de notificação: $(lido_da_extensao CFBundleShortVersionString); esperada: $VERSAO"
[[ "$(lido_da_extensao CFBundleVersion)" == "$FRILA_NUMERO_DO_BUILD" ]] || falhar "build da extensão de notificação: $(lido_da_extensao CFBundleVersion); esperado: $FRILA_NUMERO_DO_BUILD"

opcoes_de_exportacao() {
  local destino="$1" plist="$SAIDA/ExportOptions-$1.plist" so_interno=NO
  [[ "$ENSAIO" == 0 && "$MEDICAO" == 0 ]] || so_interno=YES
  rm -f "$plist"
  plutil -create xml1 "$plist"
  plutil -insert method -string app-store-connect "$plist"
  plutil -insert destination -string "$destino" "$plist"
  plutil -insert signingStyle -string automatic "$plist"
  plutil -insert teamID -string "$EQUIPE" "$plist"
  # O número do build é o deste script; o Xcode não pode trocá-lo no envio.
  plutil -insert manageAppVersionAndBuildNumber -bool NO "$plist"
  plutil -insert uploadSymbols -bool YES "$plist"
  # Os builds de ensaio e de medição nunca chegam a testador externo nem à App Store.
  plutil -insert testFlightInternalTestingOnly -bool "$so_interno" "$plist"
  printf '%s\n' "$plist"
}

exportar() {
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$2" \
    -exportOptionsPlist "$(opcoes_de_exportacao "$1")" \
    "${autenticacao[@]}" | formatar
}

# 2. Export local, com a mesma assinatura que vai ao App Store Connect.
exportar export "$EXPORTADO"
IPA="$(find "$EXPORTADO" -maxdepth 1 -name '*.ipa' -print -quit)"
[[ -n "$IPA" ]] || falhar "o export não gerou .ipa em $EXPORTADO"

# 3. Conferência do app assinado: criptografia, privacidade, ganchos de Debug e aps-environment de
# produção vêm do conferir-release.sh; get-task-allow falso confirma a assinatura de distribuição.
ditto -x -k "$IPA" "$IPA_ABERTO"
APP_ASSINADO="$IPA_ABERTO/Payload/Frila.app"
# Diagnóstico do 90035: somente metadados públicos, antes do envio.
date -u
security find-identity -v -p codesigning
python3 "$RAIZ/Scripts/diagnosticar-assinatura.py" "$APP_ARQUIVADO" "$APP_ASSINADO"

FRILA_ENSAIO_FALHA="$ENSAIO" FRILA_MEDICAO="$MEDICAO" "$RAIZ/Scripts/conferir-release.sh" "$APP_ASSINADO"
assinatura="$(python3 - "$APP_ASSINADO" <<'PYASSINATURA'
import plistlib, subprocess, sys
saida = subprocess.run(["codesign", "-d", "--entitlements", "-", "--xml", sys.argv[1]], capture_output=True).stdout
ent = plistlib.loads(saida) if saida.strip() else {}
print("distribuicao" if ent.get("get-task-allow") is False else f"get-task-allow={ent.get('get-task-allow')!r}")
PYASSINATURA
)"
[[ "$assinatura" == distribuicao ]] || falhar "o app exportado não tem assinatura de distribuição ($assinatura)"

# 4. Símbolos ao Crashlytics: o dSYM do app e o de cada framework, porque o Crashlytics retém a falha
# enquanto falta o de qualquer binário da pilha (Docs/CrashReporting.md). Duas tentativas, como na
# fase do Xcode; se não subirem, o build não vai ao TestFlight.
if [[ -n "${FRILA_DERIVED_DATA:-}" ]]; then
  PACOTES="$FRILA_DERIVED_DATA/SourcePackages"
else
  BUILD_DIR="$(xcodebuild -project "$RAIZ/Frila.xcodeproj" -scheme "$ESQUEMA" -destination 'generic/platform=iOS' \
    -showBuildSettings 2>/dev/null | awk '$1 == "BUILD_DIR" { print $3; exit }')"
  PACOTES="${BUILD_DIR%/Build/*}/SourcePackages"
fi
ENVIAR_SIMBOLOS="$PACOTES/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols"
[[ -x "$ENVIAR_SIMBOLOS" ]] || falhar "upload-symbols do Crashlytics não encontrado: $ENVIAR_SIMBOLOS"
dsyms=()
for nome in Frila.app FrilaDominio.framework FrilaDados.framework FrilaApresentacao.framework FrilaInfraestrutura.framework; do
  [[ -d "$ARCHIVE/dSYMs/$nome.dSYM" ]] || falhar "dSYM ausente no archive: $nome.dSYM"
  dsyms+=("$ARCHIVE/dSYMs/$nome.dSYM")
done
LOG_SIMBOLOS="$SAIDA/crashlytics-upload-symbols.log"
if ! "$ENVIAR_SIMBOLOS" -gsp "$PLIST_FIREBASE" -p ios "${dsyms[@]}" > "$LOG_SIMBOLOS" 2>&1 &&
  ! "$ENVIAR_SIMBOLOS" -gsp "$PLIST_FIREBASE" -p ios "${dsyms[@]}" >> "$LOG_SIMBOLOS" 2>&1; then
  # Só as linhas de erro: o log inteiro traz identificadores do projeto Firebase.
  grep -i 'error' "$LOG_SIMBOLOS" | tail -5 >&2 || true
  falhar "o envio dos símbolos ao Crashlytics falhou duas vezes"
fi
echo "Símbolos do Crashlytics ($AMBIENTE_FIREBASE): $(grep -c 'Successfully submitted' "$LOG_SIMBOLOS") envios para ${#dsyms[@]} dSYMs"

# 5. Envio ao App Store Connect, com a mesma assinatura do passo 2.
if [[ "$ENVIAR" == 1 ]]; then
  exportar upload "$SAIDA/envio"
  echo "Enviado ao TestFlight: $descricao"
else
  echo "Sem envio (--sem-envio): .ipa assinado em $IPA"
fi
