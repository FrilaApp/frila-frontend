#!/bin/bash

# Confere propriedades de privacidade e remove ganchos exclusivos de Debug de
# um bundle iOS de Release. Uso: Scripts/conferir-release.sh caminho/Frila.app

set -euo pipefail

falhar() {
  echo "FALHA: $*" >&2
  exit 1
}

if [[ $# -ne 1 ]]; then
  falhar "uso: $0 caminho/Frila.app"
fi

app="$1"
[[ -d "$app" ]] || falhar "bundle .app não encontrado: $app"

info_plist="$app/Info.plist"
[[ -f "$info_plist" ]] || falhar "Info.plist não encontrado no bundle: $info_plist"

# O valor tem de ser exatamente o booleano false: procurar <false/> no XML aceitaria um array ou
# um dicionário que contivesse false, e a string "NO" não é o que o App Store Connect lê.
criptografia="$(python3 - "$info_plist" <<'PYCRIPTO'
import plistlib, sys
with open(sys.argv[1], "rb") as arquivo:
    valor = plistlib.load(arquivo).get("ITSAppUsesNonExemptEncryption", "ausente")
print("ok" if valor is False else ("ausente" if valor == "ausente" else f"{type(valor).__name__} {valor!r}"))
PYCRIPTO
)"
case "$criptografia" in
  ok) ;;
  ausente) falhar "Info.plist não define ITSAppUsesNonExemptEncryption" ;;
  *) falhar "ITSAppUsesNonExemptEncryption deve ser o booleano false (encontrado: $criptografia)" ;;
esac

chave_localizacao_sempre="$(
  plutil -convert json -o - "$info_plist" |
    awk 'match($0, /"NSLocationAlways[^"]*"/) { print substr($0, RSTART + 1, RLENGTH - 2); exit }'
)"
[[ -z "$chave_localizacao_sempre" ]] || falhar "Info.plist não pode conter $chave_localizacao_sempre"

if plutil -extract NSUserTrackingUsageDescription raw -o /dev/null "$info_plist" >/dev/null 2>&1; then
  falhar "Info.plist não pode conter NSUserTrackingUsageDescription"
fi

# O app lê a localização em uso e pede a precisão temporária no check-in: sem estes dois textos o
# sistema não mostra o pedido.
localizacao="$(python3 - "$info_plist" <<'PYLOCALIZACAO'
import plistlib, sys
with open(sys.argv[1], "rb") as arquivo:
    info = plistlib.load(arquivo)
em_uso = info.get("NSLocationWhenInUseUsageDescription")
temporaria = info.get("NSLocationTemporaryUsageDescriptionDictionary")
if not (isinstance(em_uso, str) and em_uso.strip()):
    print("NSLocationWhenInUseUsageDescription")
elif not (isinstance(temporaria, dict) and temporaria and all(isinstance(v, str) and v.strip() for v in temporaria.values())):
    print("NSLocationTemporaryUsageDescriptionDictionary")
else:
    print("ok")
PYLOCALIZACAO
)"
[[ "$localizacao" == "ok" ]] || falhar "Info.plist precisa de $localizacao com texto"

if ! familias="$(plutil -extract UIDeviceFamily json -o - "$info_plist" 2>/dev/null)"; then
  falhar "Info.plist não define UIDeviceFamily"
fi
familias_sem_espacos="$(printf '%s' "$familias" | tr -d '[:space:]')"
[[ "$familias_sem_espacos" == "[1]" ]] || falhar "UIDeviceFamily deve conter somente [1] (iPhone); encontrado: $familias_sem_espacos"

[[ -f "$app/PrivacyInfo.xcprivacy" ]] || falhar "PrivacyInfo.xcprivacy não está no bundle"

if ! nome_executavel="$(plutil -extract CFBundleExecutable raw -o - "$info_plist" 2>/dev/null)"; then
  falhar "Info.plist não define CFBundleExecutable"
fi
executavel="$app/$nome_executavel"
[[ -f "$executavel" ]] || falhar "executável do app não encontrado: $executavel"

arquivos_para_conferir=("$executavel")
if [[ -d "$app/Frameworks" ]]; then
  while IFS= read -r -d '' arquivo; do
    arquivos_para_conferir+=("$arquivo")
  done < <(find "$app/Frameworks" -type f -print0)
fi

ganchos_de_desenvolvimento=(
  '-FRILA_SCENARIO'
  '-FRILA_ABRIR_CATALOGO'
  '-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO'
  '-FRILA_ABRIR_MINHAS_VAGAS'
  '-FRILA_CADASTRO_UI_TEST'
  '-FRILA_ENTRADA'
  '-FRILA_LOCALIZACAO'
  '-FRILA_VAGA_ID'
  '-FRILA_AVISO'
  '-FRILA_PUSH'
  '-FRILA_PERMISSAO_PUSH'
  'forcar-falha-crashlytics'
)

# Strings Swift curtas podem ser materializadas diretamente nas instruções do
# processador, sem uma sequência de bytes contígua. Esses símbolos só podem
# existir em Debug; em um bundle de Release indicam um gancho de desenvolvimento.
# A TelaLicencas não entra aqui: é tela de produto (#178) e fica compilada no Release. O que se
# reprova é o atalho que a abre (o catálogo e os argumentos -FRILA_ABRIR_*).
simbolos_de_desenvolvimento=(
  'pelosArgumentos'
  'CatalogoDesignSystem'
)

for arquivo in "${arquivos_para_conferir[@]}"; do
  for gancho in "${ganchos_de_desenvolvimento[@]}"; do
    if LC_ALL=C grep -aFq -- "$gancho" "$arquivo"; then
      falhar "binário de Release contém gancho de desenvolvimento '$gancho' em $arquivo"
    else
      status_grep=$?
      [[ $status_grep -eq 1 ]] || falhar "não foi possível examinar o binário: $arquivo"
    fi
  done

  tipo_do_arquivo="$(LC_ALL=C file -b "$arquivo")"
  if [[ "$tipo_do_arquivo" == *"Mach-O"* ]]; then
    if ! simbolos="$(nm -U "$arquivo" 2>/dev/null | xcrun swift-demangle)"; then
      falhar "não foi possível examinar os símbolos do binário: $arquivo"
    fi
    for simbolo in "${simbolos_de_desenvolvimento[@]}"; do
      if [[ "$simbolos" == *"$simbolo"* ]]; then
        falhar "binário de Release contém símbolo de desenvolvimento '$simbolo' em $arquivo"
      fi
    done
  fi
done

echo "OK: bundle de Release em conformidade: $app"
