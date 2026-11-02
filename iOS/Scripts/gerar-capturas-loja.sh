#!/usr/bin/env bash
# gerar-capturas-loja.sh
# Gera e valida capturas de tela para a App Store (6,9 polegadas) em conformidade com o Cartão 33 (uwBBwwoV).
# Valida dimensões (1320x2868 ou 1290x2796) com sips e rejeita nomes/telefones/e-mails reais.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAIZ_REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
PASTA_PADRAO="$RAIZ_REPO/Documentos/Loja/capturas"
PROJECT_YML="$RAIZ_REPO/iOS/project.yml"
OCR_SWIFT="$SCRIPT_DIR/ocr-helper.swift"
OCR_BIN="/tmp/frila-ocr-helper"

UDID=""
DESTINO="$PASTA_PADRAO"
MODO_VALIDAR_APENAS=false

mostrar_ajuda() {
    cat <<EOF
Uso: $(basename "$0") [opções]

Opções:
  --simulador <UDID>    UDID do simulador iPhone de 6,9" (ex: iPhone 17 Pro Max)
  --destino <pasta>     Pasta de saída das capturas (padrão: Documentos/Loja/capturas)
  --validar-apenas      Apenas valida dimensões (sips) e rejeição de dados reais nas imagens da pasta
  --ajuda               Exibe esta mensagem de ajuda
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --simulador)
            UDID="$2"
            shift 2
            ;;
        --destino)
            DESTINO="$2"
            shift 2
            ;;
        --validar-apenas)
            MODO_VALIDAR_APENAS=true
            shift
            ;;
        --ajuda|-h)
            mostrar_ajuda
            ;;
        *)
            echo "Opção desconhecida: $1" >&2
            mostrar_ajuda
            ;;
    esac
done

garantir_ocr_helper() {
    if [[ ! -x "$OCR_BIN" || "$OCR_SWIFT" -nt "$OCR_BIN" ]]; then
        echo "Compilando auxiliar de OCR (Apple Vision)..."
        swiftc "$OCR_SWIFT" -o "$OCR_BIN"
    fi
}

validar_dados_pessoais_reais() {
    local imagem="$1"
    local texto_ocr
    texto_ocr=$("$OCR_BIN" "$imagem")

    # 1. Proibição de nomes reais do time de fundadores e sócios
    local nomes_proibidos=("Cauê" "Caue" "Fabrício" "Fabricio" "Matheus Silva" "Jotapê" "Jotape" "João Pedro" "Júlia" "Julia")
    for nome in "${nomes_proibidos[@]}"; do
        if echo "$texto_ocr" | grep -iq "$nome"; then
            echo "ERRO DE CONFORMIDADE: Nome real proibido encontrado em $imagem: '$nome'" >&2
            return 1
        fi
    done

    # 2. Proibição de e-mails pessoais reais (@gmail, @icloud, @hotmail, etc.)
    if echo "$texto_ocr" | grep -Ei "@(gmail|icloud|hotmail|outlook|yahoo)\.com" >/dev/null; then
        echo "ERRO DE CONFORMIDADE: E-mail pessoal real encontrado em $imagem" >&2
        return 1
    fi

    # 3. Proibição de telefones que não sejam os de teste padrão (61) 99999-0000
    local telefones_suspeitos
    telefones_suspeitos=$(echo "$texto_ocr" | grep -Eo "\([0-9]{2}\)\s*[0-9]{4,5}-[0-9]{4}" | grep -v "99999-0000" || true)
    if [[ -n "$telefones_suspeitos" ]]; then
        echo "ERRO DE CONFORMIDADE: Telefone não sintético detectado em $imagem: $telefones_suspeitos" >&2
        return 1
    fi

    return 0
}

validar_dimensoes_sips() {
    local imagem="$1"
    local largura altura
    largura=$(sips -g pixelWidth "$imagem" 2>/dev/null | awk '/pixelWidth/ {print $2}')
    altura=$(sips -g pixelHeight "$imagem" 2>/dev/null | awk '/pixelHeight/ {print $2}')

    # Padrão App Store para displays de 6,9" / 6,7": 1320x2868 ou 1290x2796
    if [[ ("$largura" == "1320" && "$altura" == "2868") || ("$largura" == "1290" && "$altura" == "2796") ]]; then
        echo "  [sips] Dimensão válida: ${largura}x${altura} px"
        return 0
    else
        echo "ERRO DE DIMENSÃO: $imagem possui ${largura}x${altura} px (esperado 1320x2868 ou 1290x2796)" >&2
        return 1
    fi
}

# --- Modo Somente Validação ---
if [ "$MODO_VALIDAR_APENAS" = true ]; then
    garantir_ocr_helper
    echo "Validando imagens em $DESTINO..."
    total=0
    for img in "$DESTINO"/*.png; do
        [[ -f "$img" ]] || continue
        echo "Verificando $(basename "$img")..."
        validar_dimensoes_sips "$img"
        validar_dados_pessoais_reais "$img"
        total=$((total + 1))
    done
    if [ "$total" -eq 0 ]; then
        echo "Nenhuma imagem PNG encontrada em $DESTINO para validar." >&2
        exit 1
    fi
    echo "OK: $total capturas validadas com sucesso (dimensões e privacidade)."
    exit 0
fi

# --- Modo Geração Completa ---
mkdir -p "$DESTINO"
garantir_ocr_helper

# Obter versão do build de project.yml
VERSAO_APP=$(grep "MARKETING_VERSION:" "$PROJECT_YML" | head -n 1 | awk -F '"' '{print $2}')
BUILD_NUMERO=$(grep "CURRENT_PROJECT_VERSION:" "$PROJECT_YML" | head -n 1 | awk -F '"' '{print $2}')
VERSAO_APP="${VERSAO_APP:-1.0.0}"
BUILD_NUMERO="${BUILD_NUMERO:-1}"

echo "Configuração da build detectada: Frila v$VERSAO_APP (build $BUILD_NUMERO)"

# Detectar simulador de 6,9" caso não informado
if [[ -z "$UDID" ]]; then
    # Procura iPhone 17 Pro Max ou iPhone 16 Pro Max
    UDID=$(xcrun simctl list devices available | grep -E "iPhone 17 Pro Max|iPhone 16 Pro Max" | head -n 1 | grep -Eo "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}" || true)
    if [[ -z "$UDID" ]]; then
        echo "ERRO: Nenhum simulador de 6,9\" (iPhone 17 Pro Max / 16 Pro Max) encontrado." >&2
        exit 1
    fi
fi

NOME_SIMULADOR=$(xcrun simctl list devices | grep "$UDID" | head -n 1 | sed 's/ (Shutdown)//' | sed 's/ (Booted)//' | xargs)
echo "Usando simulador: $NOME_SIMULADOR ($UDID)"

# Garantir que o simulador está bootado
ESTADO_SIMULADOR=$(xcrun simctl list devices | grep "$UDID" | grep -o "Booted" || true)
if [[ "$ESTADO_SIMULADOR" != "Booted" ]]; then
    echo "Inicializando simulador $UDID..."
    xcrun simctl boot "$UDID"
fi

BUNDLE_ID="com.frila.org.app"

# Verificar se o app está instalado; caso contrário, procura em DerivedData
if ! xcrun simctl listapps "$UDID" | grep -q "$BUNDLE_ID"; then
    echo "App $BUNDLE_ID não encontrado no simulador. Procurando build compilada..."
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Frila.app" -type d 2>/dev/null | grep "Debug-Local-iphonesimulator" | head -n 1 || true)
    if [[ -z "$APP_PATH" ]]; then
        echo "ERRO: Frila.app não encontrado em DerivedData. Execute o build prévio do app." >&2
        exit 1
    fi
    echo "Instalando $APP_PATH no simulador..."
    xcrun simctl install "$UDID" "$APP_PATH"
fi

# Lista ordenada de capturas (5 a 8 telas, cobrindo ambos os perfis com dados sintéticos de demonstração)
declare -a TELAS=(
    "01_profissional_vagas_feed|Feed de Vagas no DF|-FRILA_SCENARIO success -FRILA_SEM_ANIMACOES|Lista de oportunidades de turnos com remuneração e localização claras"
    "02_profissional_detalhe_vaga|Detalhe da Vaga|-FRILA_SCENARIO success -FRILA_VAGA_ID 40000000-0000-0000-0000-000000000001 -FRILA_SEM_ANIMACOES|Informações completas do turno com valor fechado e sem taxas"
    "03_profissional_avaliacao_turno|Avaliação Mútua|-FRILA_ABRIR_AVALIACAO_UI_TEST -FRILA_SEM_ANIMACOES|Avaliação confidencial de pontualidade e ambiente de trabalho"
    "04_contratante_minhas_vagas|Painel Minhas Vagas|-FRILA_ABRIR_MINHAS_VAGAS -FRILA_SCENARIO painel-contratante -FRILA_SEM_ANIMACOES|Painel de acompanhamento de vagas abertas e candidatos do estabelecimento"
    "05_contratante_detalhe_vaga|Gestão de Vaga do Estabelecimento|-FRILA_ABRIR_MINHAS_VAGAS -FRILA_AVISO vaga_vazia -FRILA_AVISO_ID 40000000-0000-0000-0000-000000000001 -FRILA_SCENARIO painel-contratante -FRILA_SEM_ANIMACOES|Gestão de posições preenchidas e acompanhamento da equipe"
    "06_contratante_cadastro_estabelecimento|Cadastro do Negócio|-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO -FRILA_CADASTRO_UI_TEST -FRILA_SEM_ANIMACOES|Cadastro simples e síncrono para início rápido de publicação"
    "07_geral_suporte_turno|Suporte e Segurança|-FRILA_ABRIR_SUPORTE_TURNO -FRILA_SEM_ANIMACOES|Canal integrado de ajuda para ocorrências e suporte durante o turno"
    "08_geral_entrada_autenticacao|Autenticação Sem Senha|-FRILA_ENTRADA -FRILA_SCENARIO primeiro-acesso -FRILA_SEM_ANIMACOES|Acesso seguro e sem atritos por código de verificação no e-mail"
)

MANIFESTO_JSON="$DESTINO/manifesto.json"
echo "{" > "$MANIFESTO_JSON"
echo "  \"app\": \"Frila\"," >> "$MANIFESTO_JSON"
echo "  \"versao\": \"$VERSAO_APP\"," >> "$MANIFESTO_JSON"
echo "  \"build\": \"$BUILD_NUMERO\"," >> "$MANIFESTO_JSON"
echo "  \"data_geracao\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"," >> "$MANIFESTO_JSON"
echo "  \"dispositivo\": \"$NOME_SIMULADOR\"," >> "$MANIFESTO_JSON"
echo "  \"udid\": \"$UDID\"," >> "$MANIFESTO_JSON"
echo "  \"dimensoes_esperadas\": [\"1320x2868\", \"1290x2796\"]," >> "$MANIFESTO_JSON"
echo "  \"capturas\": [" >> "$MANIFESTO_JSON"

PRIMEIRO=true

for item in "${TELAS[@]}"; do
    IFS="|" read -r id titulo args descricao <<< "$item"
    ARQUIVO_PNG="$DESTINO/${id}.png"
    echo ""
    echo "Capturando [$id] $titulo..."

    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    # shellcheck disable=SC2086
    xcrun simctl launch "$UDID" "$BUNDLE_ID" $args >/dev/null
    sleep 2

    xcrun simctl io "$UDID" screenshot "$ARQUIVO_PNG"

    validar_dimensoes_sips "$ARQUIVO_PNG"
    validar_dados_pessoais_reais "$ARQUIVO_PNG"

    HASH=$(shasum -a 256 "$ARQUIVO_PNG" | awk '{print $1}')
    LARGURA=$(sips -g pixelWidth "$ARQUIVO_PNG" | awk '/pixelWidth/ {print $2}')
    ALTURA=$(sips -g pixelHeight "$ARQUIVO_PNG" | awk '/pixelHeight/ {print $2}')

    if [ "$PRIMEIRO" = true ]; then
        PRIMEIRO=false
    else
        echo "    ," >> "$MANIFESTO_JSON"
    fi

    cat <<ENTRY >> "$MANIFESTO_JSON"
    {
      "id": "${id}.png",
      "titulo": "$titulo",
      "descricao": "$descricao",
      "largura_px": $LARGURA,
      "altura_px": $ALTURA,
      "sha256": "$HASH",
      "privacidade_conforme": true
    }
ENTRY
done

echo "  ]" >> "$MANIFESTO_JSON"
echo "}" >> "$MANIFESTO_JSON"

xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true

echo ""
echo "Sucesso! 8 capturas da App Store geradas e validadas em: $DESTINO"
echo "Manifesto com metadados do build 1.0 gerado em: $MANIFESTO_JSON"
