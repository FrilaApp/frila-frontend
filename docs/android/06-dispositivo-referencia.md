# 06 — Dispositivo de Referência e Medição de Performance (RNF04)

**Cartão Trello:** Cartão 58 (`Dispositivo de referência: emulador API 28 com 2 GB, cold start e jank`)  
**Status:** Especificação normativa e ferramental de aferição  
**Requisito de origem:** RNF04 (Perfil mínimo de homologação) e Épico E6 (Homologação e Performance)

---

## ⚠️ Aviso Normativo Fundamental

> [!IMPORTANT]
> **ESTE SCRIPT E SUAS FERRAMENTAS OPERAM EXCLUSIVAMENTE EM EMULADOR (AVD).**  
> Medições obtidas em ambiente virtualizado servem apenas para detectar regressões grosseiras durante o ciclo de desenvolvimento local e em pipelines de CI.
> **Resultados em emulador NÃO substituem a homologação em aparelho físico real** (smartphone físico com Android 9.0, 2 GB de RAM e tela 720p). A homologação e a medição em hardware físico real são atribuição e responsabilidade de **pessoa humana**, conforme previsto no Épico E6 (`docs/android/README.md` § Requisito não funcional de referência (RNF04)).

---

## 1. Perfil Mínimo de Homologação (RNF04)

O requisito não funcional **RNF04** estabelece a linha de base para que o aplicativo do Frila funcione de maneira fluida e estável mesmo nos aparelhos mais restritos do mercado brasileiro:

| Parâmetro | Alvo Normativo | Justificativa |
|---|---|---|
| **Versão do SO** | Android 9.0 (API 28) | Mínimo suportado pelo `minSdk = 28` |
| **Memória RAM** | 2048 MB (2 GB) | Faixa típica de aparelhos de entrada (ex.: Moto E, Galaxy A0x) |
| **Resolução de Tela** | 720 x 1280 (720p HD) | Resolução predominante na faixa de entrada |
| **Densidade** | 320 dpi (xhdpi) | Densidade de referência para cálculo de densidade de pixels |
| **Heap da JVM** | 256 MB (`vm.heapSize`) | Limite de memória por processo para evitar `OutOfMemoryError` |

---

## 2. Ferramental: `android/scripts/dispositivo-referencia.sh`

O script `android/scripts/dispositivo-referencia.sh` automatiza o provisionamento e a medição no emulador:

### 2.1 Comandos Disponíveis

```bash
# Exibe o aviso normativo de emulador vs aparelho real
./android/scripts/dispositivo-referencia.sh aviso

# Cria o AVD 'frila_referencia_api28' com 2 GB de RAM e tela 720p
./android/scripts/dispositivo-referencia.sh criar

# Inicia o emulador em segundo plano
./android/scripts/dispositivo-referencia.sh iniciar

# Aguarda o boot completo do Android (sys.boot_completed=1)
./android/scripts/dispositivo-referencia.sh aguardar-boot

# Mede o tempo de inicialização a frio (cold start) do aplicativo
./android/scripts/dispositivo-referencia.sh medir-cold-start

# Mede a perda de quadros (jank frames) durante rolagem via dumpsys gfxinfo
./android/scripts/dispositivo-referencia.sh medir-jank

# Exibe o status do SDK, AVDs instalados e dispositivos ADB conectados
./android/scripts/dispositivo-referencia.sh status

# Encerra o emulador em execução
./android/scripts/dispositivo-referencia.sh parar

# Executa o fluxo completo ponta a ponta
./android/scripts/dispositivo-referencia.sh tudo
```

---

## 3. Metodologia de Medição

### 3.1 Cold Start (Inicialização a Frio)
- **Mecanismo:** Execução do comando `adb shell am start-W -n br.com.frila.app/.MainActivity` após encerramento forçado do processo via `am force-stop br.com.frila.app`.
- **Métricas avaliadas:**
  - `TotalTime`: tempo total entre o disparo da intenção pelo sistema e o primeiro quadro desenhado pela `MainActivity`.
  - `WaitTime`: tempo total do ponto de vista do inicializador.
- **Critério de Aceite (RNF04):** `TotalTime <= 2000 ms` no primeiro arranque após boot.

### 3.2 Jank (Perda de Quadros / Fluidez)
- **Mecanismo:** Coleta via `adb shell dumpsys gfxinfo br.com.frila.app` combinada com rolagem programática (`input swipe`) ao longo do feed de vagas.
- **Métricas avaliadas:**
  - Total de frames renderizados (`Total frames rendered`).
  - Quadros com atraso perceptível (`Janky frames`).
  - Percentis de latência de quadro (50th, 90th, 95th e 99th percentile).
- **Critério de Aceite (RNF04):** Taxa de quadros com jank inferior a 5% em rolagem contínua.

---

## 4. Roteiro de Homologação em Aparelho Físico (Épico E6 - Humano)

Para a medição oficial em hardware físico, o operador humano deve seguir os passos:
1. Conectar um smartphone físico com Android 9.0 e 2 GB de RAM via cabo USB com depuração ativada.
2. Certificar-se de que nenhum outro app em segundo plano consome recursos intensivos.
3. Instalar o APK de release (ou build não minificado de profiling):
   ```bash
   adb install -r app/build/outputs/apk/release/app-release-unsigned.apk
   ```
4. Executar os comandos de medição apontando para o dispositivo conectado:
   ```bash
   ./android/scripts/dispositivo-referencia.sh medir-cold-start
   ./android/scripts/dispositivo-referencia.sh medir-jank
   ```
5. Registrar as métricas no cartão de homologação com foto/evidência do aparelho físico.
