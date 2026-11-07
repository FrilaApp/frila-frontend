#!/bin/bash

# Confere propriedades de privacidade e remove ganchos exclusivos de Debug de
# um bundle iOS de Release. Uso: Scripts/conferir-release.sh caminho/Frila.app
# Com FRILA_ESQUEMA_ESPERADO=Frila-Beta|Frila-Prod, confere também que o bundle é o desse esquema.

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

# Testes empacotados não podem chegar ao TestFlight, mesmo vazios ou aninhados.
if [[ -d "$app/PlugIns" ]]; then
  while IFS= read -r -d '' teste; do
    falhar "bundle contém teste XCTest em $teste"
  done < <(find "$app/PlugIns" -name '*.xctest' -print0)
fi

info_plist="$app/Info.plist"
[[ -f "$info_plist" ]] || falhar "Info.plist não encontrado no bundle: $info_plist"

# O nome no plist sozinho não garante que o catálogo compilou o desenho do ícone.
icone="$(python3 - "$info_plist" <<'PYICONE'
import plistlib, sys
with open(sys.argv[1], "rb") as arquivo:
    info = plistlib.load(arquivo)
primario = info.get("CFBundleIcons", {}).get("CFBundlePrimaryIcon", {})
nome = info.get("CFBundleIconName") or primario.get("CFBundleIconName")
print(nome if isinstance(nome, str) and nome.strip() else "")
PYICONE
)"
[[ -n "$icone" ]] || falhar "bundle sem ícone: Info.plist não declara CFBundleIconName do ícone principal"
[[ -f "$app/Assets.car" ]] || falhar "bundle sem ícone: Assets.car não encontrado"
if ! catalogo="$(xcrun assetutil --info "$app/Assets.car" 2>/dev/null)"; then
  falhar "não foi possível conferir o ícone em Assets.car"
fi
if ! printf '%s' "$catalogo" | python3 -c 'import json, sys; nome = sys.argv[1]; sys.exit(0 if any(a.get("Name") == nome and a.get("AssetType") == "Icon Image" for a in json.load(sys.stdin)) else 1)' "$icone"; then
  falhar "bundle sem ícone: '$icone' não encontrado como imagem em Assets.car"
fi

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

# Auditoria de segurança (03/10/2026, A6): o app só fala HTTPS pelo ATS padrão, não expõe a pasta
# Documents no Finder/Arquivos e não registra esquema de URL (não há deep link). Qualquer uma destas
# chaves abriria uma superfície que o código não trata.
for chave in NSAppTransportSecurity UIFileSharingEnabled LSSupportsOpeningDocumentsInPlace CFBundleURLTypes; do
  if plutil -extract "$chave" raw -o /dev/null "$info_plist" >/dev/null 2>&1; then
    falhar "Info.plist não pode conter $chave"
  fi
done

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

# Os frameworks embutidos e as extensões (PlugIns, #253) são código do app: o gancho de
# desenvolvimento reprova em qualquer um deles.
arquivos_para_conferir=("$executavel")
for pasta in "$app/Frameworks" "$app/PlugIns"; do
  [[ -d "$pasta" ]] || continue
  while IFS= read -r -d '' arquivo; do
    arquivos_para_conferir+=("$arquivo")
  done < <(find "$pasta" -type f -print0)
done

ganchos_de_desenvolvimento=(
  '-FRILA_SCENARIO'
  '-FRILA_ABRIR_CATALOGO'
  '-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO'
  '-FRILA_ABRIR_MINHAS_VAGAS'
  '-FRILA_CADASTRO_UI_TEST'
  '-FRILA_BUSCA_PERFIL_UI_TEST'
  '-FRILA_CAPTURAR_URL_UI_TEST'
  '-FRILA_ENTRADA'
  '-FRILA_LOCALIZACAO'
  '-FRILA_VAGA_ID'
  '-FRILA_AVISO'
  '-FRILA_PUSH'
  '-FRILA_PERMISSAO_PUSH'
  '-FRILA_DECLARED_AGE_RANGE'
  '-FRILA_VERIFICADOR_IDADE'
  'forcar-falha-crashlytics'
)

# O botão do ensaio de falha (#203) só pode estar no build de ensaio, que o enviar-testflight.sh
# compila com FRILA_ENSAIO_FALHA=1 e manda ao TestFlight só para teste interno. Em qualquer outro
# Release ele reprova.
if [[ "${FRILA_ENSAIO_FALHA:-}" != "1" ]]; then
  ganchos_de_desenvolvimento+=('ensaio-forcar-falha')
fi

# Strings Swift curtas podem ser materializadas diretamente nas instruções do
# processador, sem uma sequência de bytes contígua. Esses símbolos só podem
# existir em Debug; em um bundle de Release indicam um gancho de desenvolvimento.
# A TelaLicencas não entra aqui: é tela de produto (#178) e fica compilada no Release. O que se
# reprova é o atalho que a abre (o catálogo e os argumentos -FRILA_ABRIR_*).
simbolos_de_desenvolvimento=(
  'pelosArgumentos'
  'CatalogoDesignSystem'
  'AbridorDeURLParaTeste'
  'CapturaDeAberturaDeURLParaTeste'
)

# A medição de desempenho (#73) só pode estar no build de medição, que o enviar-testflight.sh
# compila com FRILA_MEDICAO=1 e manda ao TestFlight só para teste interno. Em qualquer outro
# Release reprovam a chave das medições, o argumento que as liga, o botão e os tipos que medem.
if [[ "${FRILA_MEDICAO:-}" != "1" ]]; then
  ganchos_de_desenvolvimento+=('frila-medicao-de-desempenho' '-FRILA_MEDICAO' 'medicoes-abrir')
  simbolos_de_desenvolvimento+=('RegistroDeMedicoes' 'MedidorDeRede' 'BotaoDeMedicoes')
fi

# Trava do esquema (CI e enviar-testflight.sh): com FRILA_ESQUEMA_ESPERADO o bundle compilado tem de
# ser o do esquema pedido, para um build Beta nunca seguir como se fosse o da loja. Sem a variável a
# conferência é só a de Release acima e abaixo.
#   Frila-Beta: ambiente frila-dev, nome "Frila Beta" e o selo "BETA · servidor de teste" no binário.
#   Frila-Prod: ambiente frila-prod, nome "Frila", e nada do modo de design nem do selo Beta.
esquema_esperado="${FRILA_ESQUEMA_ESPERADO:-}"
marcas_do_beta=(
  'servidor de teste'
  '-FRILA_MODO_DESIGN'
  '-FRILA_DEMO_ENTRADA'
  'frila_modo_design_ativo'
  '-FRILA_DESIGN'
  'ModoDebugDesign'
  'ContextoDebugDesign'
  'RegistroDebugDesign'
  'ControleModoDesign'
  'SeloBeta'
)
case "$esquema_esperado" in
  "") ;;
  Frila-Beta|Frila-Prod)
    if [[ "$esquema_esperado" == "Frila-Beta" ]]; then
      ambiente_esperado=frila-dev
      nome_esperado="Frila Beta"
    else
      ambiente_esperado=frila-prod
      nome_esperado="Frila"
    fi
    ambiente_do_app="$(plutil -extract FRILA_ENVIRONMENT raw -o - "$info_plist" 2>/dev/null || true)"
    [[ "$ambiente_do_app" == "$ambiente_esperado" ]] ||
      falhar "o app compilado não é o do esquema $esquema_esperado: FRILA_ENVIRONMENT=${ambiente_do_app:-ausente}, esperado $ambiente_esperado. Não envie este build."

    # O nome que o aparelho mostra vem do Info.plist e de cada InfoPlist.strings; todos têm de bater.
    nomes_do_app="$(python3 - "$app" <<'PYNOME'
import glob, plistlib, sys
app = sys.argv[1]
nomes = set()
with open(app + "/Info.plist", "rb") as arquivo:
    nomes.add(plistlib.load(arquivo).get("CFBundleDisplayName", "ausente"))
for caminho in glob.glob(app + "/*.lproj/InfoPlist.strings"):
    try:
        with open(caminho, "rb") as arquivo:
            nome = plistlib.load(arquivo).get("CFBundleDisplayName")
    except Exception:
        nome = "ilegivel"
    if nome is not None:
        nomes.add(nome)
print("|".join(sorted(nomes)))
PYNOME
    )"
    [[ "$nomes_do_app" == "$nome_esperado" ]] ||
      falhar "o nome do app na tela inicial deve ser '$nome_esperado' no esquema $esquema_esperado (encontrado: ${nomes_do_app:-ausente})"

    achadas=()
    for arquivo in "${arquivos_para_conferir[@]}"; do
      for marca in "${marcas_do_beta[@]}"; do
        if LC_ALL=C grep -aFq -- "$marca" "$arquivo"; then
          achadas+=("$marca")
        else
          status_grep=$?
          [[ $status_grep -eq 1 ]] || falhar "não foi possível examinar o binário: $arquivo"
        fi
      done
    done
    if [[ "$esquema_esperado" == "Frila-Prod" ]]; then
      if ((${#achadas[@]})); then
        falhar "o build do Frila-Prod contém o modo de design ou o selo Beta: $(printf '%s\n' "${achadas[@]}" | sort -u | tr '\n' ' ')"
      fi
    else
      printf '%s\n' "${achadas[@]-}" | grep -Fxq 'servidor de teste' ||
        falhar "o build do Frila-Beta não traz o selo 'BETA · servidor de teste'; sem ele ninguém reconhece o build de teste"
    fi
    ;;
  *) falhar "FRILA_ESQUEMA_ESPERADO deve ser Frila-Beta ou Frila-Prod (recebido: $esquema_esperado)" ;;
esac

for arquivo in "${arquivos_para_conferir[@]}"; do
  # O prefixo seco sb_secret_ existe na guarda do app; só uma chave completa reprova.
  for tipo in JWT sb_secret; do
    case "$tipo" in
      JWT) padrao='eyJ[A-Za-z0-9_-]{20,}\.' ;;
      sb_secret) padrao='sb_secret_[A-Za-z0-9_-]{20,}' ;;
    esac
    if LC_ALL=C grep -aEq -- "$padrao" "$arquivo"; then
      falhar "binário de Release contém segredo $tipo em $arquivo"
    else
      status_grep=$?
      [[ $status_grep -eq 1 ]] || falhar "não foi possível examinar o binário: $arquivo"
    fi
  done

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

# Push de produção (#8): o aps-environment efetivo do Release é production, e nada além disso
# passa. No build de simulador o Xcode embute os entitlements declarados na seção
# __TEXT,__entitlements do executável. No build assinado eles ficam na assinatura, e ali quem
# decide o valor é o perfil de provisionamento, não o arquivo de entitlements: o Release assinado
# com perfil de desenvolvimento sai com development e é reprovado, porque não é o build que vai
# para o TestFlight.
aps="$(python3 - "$app" "$executavel" <<'PYAPS'
import plistlib, re, subprocess, sys
app, executavel = sys.argv[1], sys.argv[2]
try:
    saida = subprocess.run(["codesign", "-d", "--entitlements", "-", "--xml", app], capture_output=True).stdout
    assinatura = plistlib.loads(saida) if saida.strip() else {}
except Exception:
    assinatura = {}
if "aps-environment" in assinatura:
    origem = "assinatura de desenvolvimento" if assinatura.get("get-task-allow") is True else "assinatura"
    print(f"{assinatura['aps-environment']}|{origem}")
else:
    with open(executavel, "rb") as arquivo:
        valores = set(re.findall(rb"<key>aps-environment</key>\s*<string>([^<]*)</string>", arquivo.read()))
    print((",".join(sorted(valor.decode() for valor in valores)) or "ausente") + "|declarado")
PYAPS
)"
origem_do_aps="${aps#*|}"
aps="${aps%%|*}"
case "$aps" in
  production) ;;
  ausente) falhar "o bundle não declara aps-environment: sem ele o app não recebe push" ;;
  *) falhar "aps-environment deve ser production no Release (encontrado: $aps, $origem_do_aps)" ;;
esac

echo "OK: bundle de Release em conformidade: $app"
