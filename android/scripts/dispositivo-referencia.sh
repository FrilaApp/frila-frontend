#!/usr/bin/env bash
# ==============================================================================
# Frila Android — Dispositivo de Referência (API 28, 2 GB RAM, 720p)
# Cartão 58 · RNF04 (Perfil Mínimo de Homologação)
#
# AVISO OBRIGATÓRIO:
# Este script gerencia e mede performance EXCLUSIVAMENTE em EMULADOR virtual
# (Android Virtual Device - AVD). Resultados obtidos em emulador NÃO substituem
# a homologação e medição em APARELHO REAL FÍSICO (hardware), que é atribuição
# exclusiva de pessoa conforme o Épico E6 e o documento docs/android/README.md.
# ==============================================================================

set -euo pipefail

AVD_NAME="frila_referencia_api28"
PACOTE_APP="br.com.frila.app"
ACTIVITY_PRINCIPAL="br.com.frila.app/.MainActivity"
RAM_SIZE_MB=2048
HEAP_SIZE_MB=256
API_LEVEL=28

# 1. Localização do Android SDK
SDK_DIR="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
if [ ! -d "$SDK_DIR" ]; then
    if [ -d "$HOME/Android/Sdk" ]; then
        SDK_DIR="$HOME/Android/Sdk"
    else
        echo "ERRO: Android SDK não encontrado em ANDROID_HOME nem em caminhos padrão." >&2
        echo "Defina a variável ANDROID_HOME apontando para o SDK." >&2
        exit 1
    fi
fi

ADB="$SDK_DIR/platform-tools/adb"
EMULATOR="$SDK_DIR/emulator/emulator"
CMDLINE_TOOLS_BIN="$SDK_DIR/cmdline-tools/latest/bin"
AVDMANAGER="$CMDLINE_TOOLS_BIN/avdmanager"
SDKMANAGER="$CMDLINE_TOOLS_BIN/sdkmanager"

# Fallback se cmdline-tools/latest não existir diretamente
if [ ! -x "$AVDMANAGER" ]; then
    AVDMANAGER="$(command -v avdmanager || true)"
fi
if [ ! -x "$SDKMANAGER" ]; then
    SDKMANAGER="$(command -v sdkmanager || true)"
fi
if [ ! -x "$ADB" ]; then
    ADB="$(command -v adb || true)"
fi
if [ ! -x "$EMULATOR" ]; then
    EMULATOR="$(command -v emulator || true)"
fi

exibir_aviso_normativo() {
    cat <<'EOF'
================================================================================
⚠️  AVISO DE HOMOLOGAÇÃO: MEDIÇÃO EM EMULADOR (NÃO É APARELHO FÍSICO)
Este script avalia cold start e jank em AMBIENTE VIRTUALIZADO (AVD/Emulador).
Emuladores compartilham CPU, barramento e GPU do computador hospedeiro e NÃO
reproduzem com fidelidade a contenção térmica, de I/O e de memória de um
smartphone real de baixo custo. A medição oficial e definitiva em hardware físico
(Android 9.0, 2 GB RAM, 720p) é atribuição de pessoa no Épico E6.
================================================================================
EOF
}

ajuda() {
    exibir_aviso_normativo
    echo ""
    echo "Uso: $0 [comando]"
    echo ""
    echo "Comandos disponíveis:"
    echo "  aviso                Exibe o aviso normativo de homologação"
    echo "  criar                Cria o AVD $AVD_NAME com 2 GB de RAM e API 28"
    echo "  iniciar              Inicia o emulador de referência em segundo plano"
    echo "  aguardar-boot        Aguarda a inicialização completa do sistema no emulador"
    echo "  medir-cold-start     Mede o tempo de inicialização a frio (cold start)"
    echo "  medir-jank           Mede quadros perdidos (jank frames) via dumpsys gfxinfo"
    echo "  status               Verifica se o AVD existe e se há emulador ativo"
    echo "  parar                Encerra o emulador de referência"
    echo "  tudo                 Fluxo completo: verificar, iniciar, aguardar e medir"
    echo ""
}

obter_arquitetura_host() {
    local uname_m
    uname_m="$(uname -m)"
    if [ "$uname_m" = "arm64" ] || [ "$uname_m" = "aarch64" ]; then
        echo "arm64-v8a"
    else
        echo "x86_64"
    fi
}

criar_avd() {
    exibir_aviso_normativo
    local arch
    arch="$(obter_arquitetura_host)"
    local sys_image="system-images;android-${API_LEVEL};default;${arch}"

    echo "==> Verificando imagem do sistema: $sys_image"
    if [ -x "$SDKMANAGER" ]; then
        if ! "$SDKMANAGER" --list_installed | grep -q "android-${API_LEVEL}"; then
            echo "Instalando imagem $sys_image (pode levar alguns minutos)..."
            echo "y" | "$SDKMANAGER" --install "$sys_image" || {
                echo "Aviso: sdkmanager não conseguiu baixar automaticamente. Prossiga se a imagem já existir." >&2
            }
        fi
    fi

    echo "==> Criando AVD '$AVD_NAME' com API $API_LEVEL ($arch)..."
    if [ -x "$AVDMANAGER" ]; then
        echo "no" | "$AVDMANAGER" create avd \
            -n "$AVD_NAME" \
            -k "$sys_image" \
            --force
    else
        echo "ERRO: avdmanager não encontrado em $CMDLINE_TOOLS_BIN." >&2
        exit 1
    fi

    local avd_dir="$HOME/.android/avd/${AVD_NAME}.avd"
    local config_file="$avd_dir/config.ini"

    if [ -d "$avd_dir" ]; then
        echo "==> Ajustando limites de memória e hardware em $config_file:"
        echo "    - RAM: ${RAM_SIZE_MB}MB"
        echo "    - Heap da VM: ${HEAP_SIZE_MB}MB"
        echo "    - Resolução: 720x1280 (720p)"

        sed -i '' -e '/^hw.ramSize/d' "$config_file" 2>/dev/null || sed -i -e '/^hw.ramSize/d' "$config_file" 2>/dev/null || true
        sed -i '' -e '/^vm.heapSize/d' "$config_file" 2>/dev/null || sed -i -e '/^vm.heapSize/d' "$config_file" 2>/dev/null || true
        sed -i '' -e '/^hw.lcd.width/d' "$config_file" 2>/dev/null || sed -i -e '/^hw.lcd.width/d' "$config_file" 2>/dev/null || true
        sed -i '' -e '/^hw.lcd.height/d' "$config_file" 2>/dev/null || sed -i -e '/^hw.lcd.height/d' "$config_file" 2>/dev/null || true

        cat <<EOF >> "$config_file"
hw.ramSize = ${RAM_SIZE_MB}
vm.heapSize = ${HEAP_SIZE_MB}
hw.lcd.width = 720
hw.lcd.height = 1280
hw.lcd.density = 320
EOF
        echo "AVD '$AVD_NAME' configurado com sucesso!"
    else
        echo "Aviso: Diretório $avd_dir não encontrado para ajustes finos."
    fi
}

iniciar_emulador() {
    exibir_aviso_normativo
    echo "==> Iniciando emulador $AVD_NAME..."
    if [ ! -x "$EMULATOR" ]; then
        echo "ERRO: Binário emulator não encontrado em $EMULATOR." >&2
        exit 1
    fi

    "$EMULATOR" -avd "$AVD_NAME" \
        -memory "$RAM_SIZE_MB" \
        -no-snapshot-save \
        -no-boot-anim \
        -netdelay none \
        -netspeed full \
        >/dev/null 2>&1 &

    echo "Processo do emulador lançado em background (PID: $!)."
}

aguardar_boot() {
    echo "==> Aguardando emulador inicializar (sys.boot_completed=1)..."
    local tentativas=0
    local max_tentativas=60

    if [ ! -x "$ADB" ]; then
        echo "ERRO: adb não encontrado." >&2
        exit 1
    fi

    "$ADB" wait-for-device
    while [ "$tentativas" -lt "$max_tentativas" ]; do
        local pronto
        pronto="$("$ADB" shell getprop sys.boot_completed 2>/dev/null || true)"
        pronto="$(echo "$pronto" | tr -d '\r\n')"
        if [ "$pronto" = "1" ]; then
            echo "Emulador pronto para teste!"
            return 0
        fi
        sleep 2
        tentativas=$((tentativas + 1))
    done

    echo "ERRO: Tempo limite excedido aguardando inicialização do emulador." >&2
    return 1
}

medir_cold_start() {
    exibir_aviso_normativo
    echo "==> Medindo Cold Start (App: $PACOTE_APP)..."
    if [ ! -x "$ADB" ]; then
        echo "ERRO: adb não encontrado." >&2
        exit 1
    fi

    # Garante encerramento completo de qualquer processo anterior
    "$ADB" shell am force-stop "$PACOTE_APP"
    sleep 2

    echo "Disparando inicialização a frio..."
    local resultado
    resultado="$("$ADB" shell am start-W -n "$ACTIVITY_PRINCIPAL" 2>&1)"
    echo "$resultado"

    local total_time
    total_time="$(echo "$resultado" | grep -i "TotalTime:" | awk '{print $2}' | tr -d '\r\n' || true)"
    local wait_time
    wait_time="$(echo "$resultado" | grep -i "WaitTime:" | awk '{print $2}' | tr -d '\r\n' || true)"

    echo "--------------------------------------------------------------------------------"
    echo "Resultado Cold Start (EMULADOR API 28, 2 GB RAM):"
    if [ -n "$total_time" ]; then
        echo "  - TotalTime: ${total_time} ms"
        echo "  - WaitTime:  ${wait_time} ms"
    else
        echo "  - Não foi possível extrair tempo numérico. Verifique se o app está instalado."
    fi
    echo "--------------------------------------------------------------------------------"
    echo "Nota: O limite aceitável de cold start para homologação inicial é <= 2000 ms."
}

medir_jank() {
    exibir_aviso_normativo
    echo "==> Medindo Jank (Perda de Quadros) via gfxinfo..."
    if [ ! -x "$ADB" ]; then
        echo "ERRO: adb não encontrado." >&2
        exit 1
    fi

    # Limpa contadores de renderização
    "$ADB" shell dumpsys gfxinfo "$PACOTE_APP" reset >/dev/null 2>&1 || true

    echo "Exercitando rolagem na interface por 5 segundos..."
    # Simula alguns swipes de rolagem na tela
    "$ADB" shell input swipe 360 800 360 300 200 2>/dev/null || true
    sleep 1
    "$ADB" shell input swipe 360 300 360 800 200 2>/dev/null || true
    sleep 1

    echo "Coletando estatísticas do Pipeline Gráfico:"
    local gfx_out
    gfx_out="$("$ADB" shell dumpsys gfxinfo "$PACOTE_APP" 2>&1)"

    echo "--------------------------------------------------------------------------------"
    echo "Métricas de Jank (EMULADOR API 28, 2 GB RAM):"
    echo "$gfx_out" | grep -E "Total frames rendered|Janky frames|50th percentile|90th percentile|95th percentile|99th percentile" || {
        echo "Dados brutos do dumpsys gfxinfo:"
        echo "$gfx_out" | head -n 30
    }
    echo "--------------------------------------------------------------------------------"
    echo "Nota: Em aparelho real (RNF04), a taxa esperada é < 5% de quadros com jank."
}

status_ambiente() {
    exibir_aviso_normativo
    echo "==> Verificando status do ambiente:"
    echo "  - Android SDK: $SDK_DIR"
    if [ -x "$AVDMANAGER" ]; then
        echo "  - AVDs instalados:"
        "$AVDMANAGER" list avd | grep "Name:" || echo "    (nenhum AVD encontrado)"
    fi
    if [ -x "$ADB" ]; then
        echo "  - Dispositivos ADB ativos:"
        "$ADB" devices
    fi
}

parar_emulador() {
    echo "==> Encerrando emulador..."
    if [ -x "$ADB" ]; then
        "$ADB" emu kill 2>/dev/null || true
    fi
    echo "Comando de encerramento enviado."
}

fluxo_completo() {
    exibir_aviso_normativo
    status_ambiente
    criar_avd
    iniciar_emulador
    aguardar_boot
    medir_cold_start
    medir_jank
    echo "Fluxo concluído."
}

case "${1:-ajuda}" in
    aviso)
        exibir_aviso_normativo
        ;;
    criar)
        criar_avd
        ;;
    iniciar)
        iniciar_emulador
        ;;
    aguardar-boot)
        aguardar_boot
        ;;
    medir-cold-start)
        medir_cold_start
        ;;
    medir-jank)
        medir_jank
        ;;
    status)
        status_ambiente
        ;;
    parar)
        parar_emulador
        ;;
    tudo)
        fluxo_completo
        ;;
    ajuda|--help|-h)
        ajuda
        ;;
    *)
        echo "Comando desconhecido: $1" >&2
        ajuda
        exit 1
        ;;
esac
