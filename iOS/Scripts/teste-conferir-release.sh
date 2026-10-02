#!/bin/bash

# Exercita o contrato público de conferir-release.sh com bundles sintéticos.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/conferir-release.sh"
TMPDIR_TESTE="$(mktemp -d "${TMPDIR:-/tmp}/frila-conformidade.XXXXXX")"

trap 'rm -rf "$TMPDIR_TESTE"' EXIT

[[ -x "$SCRIPT" ]] || {
  echo "FALHA: script de conformidade não encontrado ou não executável: $SCRIPT" >&2
  exit 1
}

novo_app_bom() {
  local nome="$1"
  local app="$TMPDIR_TESTE/$nome.app"
  local plist="$app/Info.plist"

  mkdir -p "$app"
  plutil -create xml1 "$plist"
  plutil -insert CFBundleExecutable -string Frila "$plist"
  plutil -insert ITSAppUsesNonExemptEncryption -bool NO "$plist"
  plutil -insert NSLocationWhenInUseUsageDescription -string 'localização em uso' "$plist"
  plutil -insert NSLocationTemporaryUsageDescriptionDictionary -json '{"CheckIn": "precisão no check-in"}' "$plist"
  plutil -insert UIDeviceFamily -array "$plist"
  plutil -insert UIDeviceFamily.0 -integer 1 "$plist"
  : > "$app/PrivacyInfo.xcprivacy"
  printf 'binario release limpo\n' > "$app/Frila"
  chmod +x "$app/Frila"
  printf '%s\n' "$app"
}

esperar_aprovacao() {
  local app="$1"
  local saida
  if ! saida="$("$SCRIPT" "$app" 2>&1)"; then
    echo "FALHA: o caso bom foi reprovado: $saida" >&2
    exit 1
  fi
  [[ "$saida" == *"OK: bundle de Release em conformidade"* ]] || {
    echo "FALHA: aprovação sem mensagem esperada: $saida" >&2
    exit 1
  }
}

esperar_reprovacao() {
  local descricao="$1"
  local motivo="$2"
  local app="$3"
  local saida

  if saida="$("$SCRIPT" "$app" 2>&1)"; then
    echo "FALHA: $descricao deveria reprovar" >&2
    exit 1
  fi
  [[ "$saida" == *"$motivo"* ]] || {
    echo "FALHA: $descricao reprovou pelo motivo errado: $saida" >&2
    exit 1
  }
}

app="$(novo_app_bom bom)"
esperar_aprovacao "$app"

app="$(novo_app_bom sem-criptografia)"
plutil -remove ITSAppUsesNonExemptEncryption "$app/Info.plist"
esperar_reprovacao "criptografia ausente" "ITSAppUsesNonExemptEncryption" "$app"

app="$(novo_app_bom criptografia-sim)"
plutil -replace ITSAppUsesNonExemptEncryption -bool YES "$app/Info.plist"
esperar_reprovacao "criptografia verdadeira" "booleano false" "$app"

app="$(novo_app_bom criptografia-string-no)"
plutil -replace ITSAppUsesNonExemptEncryption -string NO "$app/Info.plist"
esperar_reprovacao "criptografia como string NO" "booleano false" "$app"

app="$(novo_app_bom criptografia-array)"
plutil -replace ITSAppUsesNonExemptEncryption -json '[false]' "$app/Info.plist"
esperar_reprovacao "criptografia como array com false" "booleano false" "$app"

app="$(novo_app_bom criptografia-dicionario)"
plutil -replace ITSAppUsesNonExemptEncryption -json '{"valor": false}' "$app/Info.plist"
esperar_reprovacao "criptografia como dicionário com false" "booleano false" "$app"

app="$(novo_app_bom criptografia-string-false)"
plutil -replace ITSAppUsesNonExemptEncryption -string false "$app/Info.plist"
esperar_reprovacao "criptografia como string false" "booleano false" "$app"

app="$(novo_app_bom localizacao-sempre)"
plutil -insert NSLocationAlwaysUsageDescription -string 'localização' "$app/Info.plist"
esperar_reprovacao "localização sempre" "NSLocationAlwaysUsageDescription" "$app"

app="$(novo_app_bom localizacao-sempre-e-em-uso)"
plutil -insert NSLocationAlwaysAndWhenInUseUsageDescription -string 'localização' "$app/Info.plist"
esperar_reprovacao "localização sempre e em uso" "NSLocationAlwaysAndWhenInUseUsageDescription" "$app"

app="$(novo_app_bom localizacao-sempre-futura)"
plutil -insert NSLocationAlwaysFutureUsageDescription -string 'localização' "$app/Info.plist"
esperar_reprovacao "qualquer chave de localização sempre" "NSLocationAlwaysFutureUsageDescription" "$app"

app="$(novo_app_bom rastreamento)"
plutil -insert NSUserTrackingUsageDescription -string 'rastreamento' "$app/Info.plist"
esperar_reprovacao "rastreamento" "NSUserTrackingUsageDescription" "$app"

app="$(novo_app_bom sem-localizacao-em-uso)"
plutil -remove NSLocationWhenInUseUsageDescription "$app/Info.plist"
esperar_reprovacao "texto de localização em uso ausente" "NSLocationWhenInUseUsageDescription" "$app"

app="$(novo_app_bom localizacao-em-uso-vazia)"
plutil -replace NSLocationWhenInUseUsageDescription -string '' "$app/Info.plist"
esperar_reprovacao "texto de localização em uso vazio" "NSLocationWhenInUseUsageDescription" "$app"

app="$(novo_app_bom sem-precisao-temporaria)"
plutil -remove NSLocationTemporaryUsageDescriptionDictionary "$app/Info.plist"
esperar_reprovacao "precisão temporária ausente" "NSLocationTemporaryUsageDescriptionDictionary" "$app"

app="$(novo_app_bom precisao-temporaria-vazia)"
plutil -replace NSLocationTemporaryUsageDescriptionDictionary -json '{}' "$app/Info.plist"
esperar_reprovacao "precisão temporária sem motivo" "NSLocationTemporaryUsageDescriptionDictionary" "$app"

app="$(novo_app_bom ipad)"
plutil -insert UIDeviceFamily.1 -integer 2 "$app/Info.plist"
esperar_reprovacao "iPad em UIDeviceFamily" "UIDeviceFamily deve conter somente [1]" "$app"

app="$(novo_app_bom sem-privacidade)"
rm "$app/PrivacyInfo.xcprivacy"
esperar_reprovacao "manifesto de privacidade ausente" "PrivacyInfo.xcprivacy" "$app"

for gancho in '-FRILA_SCENARIO' '-FRILA_ABRIR_CATALOGO' '-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO' '-FRILA_ABRIR_MINHAS_VAGAS' '-FRILA_CADASTRO_UI_TEST' '-FRILA_ENTRADA' '-FRILA_LOCALIZACAO' '-FRILA_VAGA_ID' '-FRILA_AVISO' '-FRILA_PUSH' '-FRILA_PERMISSAO_PUSH' 'forcar-falha-crashlytics'; do
  app="$(novo_app_bom "gancho-$RANDOM")"
  printf '\n%s\n' "$gancho" >> "$app/Frila"
  esperar_reprovacao "gancho no executável: $gancho" "$gancho" "$app"
done

app="$(novo_app_bom gancho-framework)"
mkdir -p "$app/Frameworks/Teste.framework"
printf 'binario com -FRILA_SCENARIO\n' > "$app/Frameworks/Teste.framework/Teste"
chmod +x "$app/Frameworks/Teste.framework/Teste"
esperar_reprovacao "gancho em framework embutido" "-FRILA_SCENARIO" "$app"

for simbolo in pelosArgumentos CatalogoDesignSystem; do
  app="$(novo_app_bom "simbolo-$RANDOM")"
  printf 'int %s(void) { return 0; }\nint main(void) { return %s(); }\n' "$simbolo" "$simbolo" |
    xcrun clang -x c -o "$app/Frila" -
  esperar_reprovacao "símbolo no executável: $simbolo" "$simbolo" "$app"
done

# A tela de licenças é de produto (#178): o símbolo dela no Release não reprova.
app="$(novo_app_bom simbolo-de-produto)"
printf 'int TelaLicencas(void) { return 0; }\nint main(void) { return TelaLicencas(); }\n' |
  xcrun clang -x c -o "$app/Frila" -
esperar_aprovacao "$app"

echo "OK: autoteste de conferir-release.sh passou"
