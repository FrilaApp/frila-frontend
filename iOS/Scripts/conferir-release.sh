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

if ! criptografia="$(plutil -extract ITSAppUsesNonExemptEncryption raw -o - "$info_plist" 2>/dev/null)"; then
  falhar "Info.plist não define ITSAppUsesNonExemptEncryption"
fi
[[ "$criptografia" == "NO" || "$criptografia" == "false" ]] || falhar "ITSAppUsesNonExemptEncryption deve ser NO (encontrado: $criptografia)"

chave_localizacao_sempre="$(
  plutil -convert json -o - "$info_plist" |
    awk 'match($0, /"NSLocationAlways[^"]*"/) { print substr($0, RSTART + 1, RLENGTH - 2); exit }'
)"
[[ -z "$chave_localizacao_sempre" ]] || falhar "Info.plist não pode conter $chave_localizacao_sempre"

if plutil -extract NSUserTrackingUsageDescription raw -o /dev/null "$info_plist" >/dev/null 2>&1; then
  falhar "Info.plist não pode conter NSUserTrackingUsageDescription"
fi

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
  '-FRILA_ENTRADA'
  'forcar-falha-crashlytics'
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
done

echo "OK: bundle de Release em conformidade: $app"
