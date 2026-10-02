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

entitlements() {
  printf '<plist version="1.0">\n<dict>\n\t<key>aps-environment</key>\n\t<string>%s</string>\n</dict>\n</plist>' "$1"
}

# Compila um executável de verdade com os entitlements na seção em que o Xcode os põe no simulador.
compilar_com_entitlements() {
  local destino="$1"
  entitlements production > "$TMPDIR_TESTE/entitlements.plist"
  xcrun clang -x c -Wl,-sectcreate,__TEXT,__entitlements,"$TMPDIR_TESTE/entitlements.plist" -o "$destino" -
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
  printf 'binario release limpo\n%s\n' "$(entitlements production)" > "$app/Frila"
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

for gancho in '-FRILA_SCENARIO' '-FRILA_ABRIR_CATALOGO' '-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO' '-FRILA_ABRIR_MINHAS_VAGAS' '-FRILA_CADASTRO_UI_TEST' '-FRILA_BUSCA_PERFIL_UI_TEST' '-FRILA_ENTRADA' '-FRILA_LOCALIZACAO' '-FRILA_VAGA_ID' '-FRILA_AVISO' '-FRILA_PUSH' '-FRILA_PERMISSAO_PUSH' 'forcar-falha-crashlytics'; do
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
    compilar_com_entitlements "$app/Frila"
  esperar_reprovacao "símbolo no executável: $simbolo" "$simbolo" "$app"
done

# A tela de licenças é de produto (#178): o símbolo dela no Release não reprova.
app="$(novo_app_bom simbolo-de-produto)"
printf 'int TelaLicencas(void) { return 0; }\nint main(void) { return TelaLicencas(); }\n' |
  compilar_com_entitlements "$app/Frila"
esperar_aprovacao "$app"

# Push (#8): o Release declara aps-environment = production.
app="$(novo_app_bom aps-de-desenvolvimento)"
printf 'binario release limpo\n%s\n' "$(entitlements development)" > "$app/Frila"
esperar_reprovacao "aps-environment de desenvolvimento" "aps-environment deve ser production" "$app"

app="$(novo_app_bom sem-aps)"
printf 'binario release limpo\n' > "$app/Frila"
esperar_reprovacao "aps-environment ausente" "não declara aps-environment" "$app"

# No build assinado vale o que está na assinatura, e não o declarado: só production passa, com ou
# sem get-task-allow (a assinatura de desenvolvimento não abranda a regra).
assinar_com() {
  local app="$1" aps="$2" get_task_allow="$3"
  printf 'int main(void) { return 0; }\n' | compilar_com_entitlements "$app/Frila"
  plutil -insert CFBundleIdentifier -string com.frila.org.app.teste "$app/Info.plist"
  printf '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0">\n<dict>\n\t<key>aps-environment</key>\n\t<string>%s</string>\n\t<key>get-task-allow</key>\n\t<%s/>\n</dict>\n</plist>\n' \
    "$aps" "$get_task_allow" > "$TMPDIR_TESTE/assinatura.plist"
  codesign --force --sign - --entitlements "$TMPDIR_TESTE/assinatura.plist" "$app" 2>/dev/null
}

for get_task_allow in true false; do
  app="$(novo_app_bom "assinado-production-$get_task_allow")"
  assinar_com "$app" production "$get_task_allow"
  esperar_aprovacao "$app"

  for aps in development valor-invalido; do
    app="$(novo_app_bom "assinado-$aps-$get_task_allow")"
    assinar_com "$app" "$aps" "$get_task_allow"
    esperar_reprovacao "assinatura com aps-environment $aps e get-task-allow $get_task_allow" \
      "aps-environment deve ser production no Release (encontrado: $aps" "$app"
  done
done

echo "OK: autoteste de conferir-release.sh passou"
