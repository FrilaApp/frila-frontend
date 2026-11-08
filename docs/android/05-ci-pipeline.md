# 05 — Pipeline de CI (Android v1.1)

**Status:** Normativo · **Fonte:** `docs/proposta-android.md` §7; convenções medidas em `.github/workflows/ios.yml`

---

## 1. Por que Linux, e não macOS

O runner iOS (`.github/workflows/ios.yml`, MEDIDO: `runs-on: macos-26`) existe porque `xcodebuild`
só roda em macOS. Android não tem essa restrição: o Gradle toolchain roda nativamente em Linux. A
esteira Android usa **`ubuntu-latest`** — runner mais barato e mais rápido que o de macOS, e sem
necessidade de fixar versão de Xcode.

## 2. Orçamento de tempo

Alvo normativo: **3 minutos** de execução ponta a ponta para o conjunto completo de jobs
(estático + gate de contrato + testes unitários), com folga até 5 minutos antes de acionar
alerta de regressão de pipeline. Build de APK/AAB debug para emulador não entra nesse orçamento —
roda como job separado, sem bloquear o merge por tempo de boot de emulador.

## 3. Estrutura de workflow

```yaml
name: Android

on:
  pull_request:
    paths:
      - "android/**"
      - ".github/workflows/android.yml"
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: android-${{ github.event.pull_request.number || format('manual-{0}', github.run_id) }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

jobs:
  analise-estatica:
    name: "Análise estática: ktlint, detekt, lint"
    runs-on: ubuntu-latest
    timeout-minutes: 10
    defaults:
      run:
        shell: bash
        working-directory: android
    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: false
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"
      - uses: gradle/actions/setup-gradle@v4
      - run: ./gradlew ktlintCheck detekt lintDebug

  gate-contrato:
    name: "Gate de contrato: openapi.yaml"
    runs-on: ubuntu-latest
    timeout-minutes: 5
    defaults:
      run:
        shell: bash
        working-directory: android
    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: false
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"
      - uses: gradle/actions/setup-gradle@v4
      - run: ./gradlew contratoAndroidConfere

  testes-unitarios:
    name: "Testes unitários: domínio e dados"
    needs: [analise-estatica, gate-contrato]
    runs-on: ubuntu-latest
    timeout-minutes: 10
    defaults:
      run:
        shell: bash
        working-directory: android
    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: false
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"
      - uses: gradle/actions/setup-gradle@v4
      - run: ./gradlew testDebugUnitTest

  compilacao-build:
    name: "Build: APK/AAB debug"
    needs: [testes-unitarios]
    runs-on: ubuntu-latest
    timeout-minutes: 15
    defaults:
      run:
        shell: bash
        working-directory: android
    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: false
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"
      - uses: gradle/actions/setup-gradle@v4
      - run: ./gradlew assembleDebug bundleDebug
```

> **Nota de implementação.** O exemplo acima usa tags de versão simbólicas (`@v4`) para
> legibilidade normativa. A convenção já em vigor neste repositório (MEDIDO em
> `.github/workflows/ios.yml`) é **fixar cada action por SHA completo**, com a tag de versão como
> comentário (`uses: actions/checkout@<sha> # v4.x.y`). O workflow Android real, ao ser
> implementado no Épico E1, deve seguir essa mesma convenção de pinning, não as tags simbólicas
> deste documento.

## 4. Jobs, em ordem de dependência

| Job | Depende de | O que roda | Falha bloqueia merge? |
|---|---|---|---|
| `analise-estatica` | — | `ktlintCheck`, `detekt`, `lintDebug` | Sim |
| `gate-contrato` | — | `contratoAndroidConfere` (ver `03-contrato-e-api.md` §6) | Sim |
| `testes-unitarios` | `analise-estatica`, `gate-contrato` | `testDebugUnitTest` (`:core:dominio` + decodificadores de `:core:dados`) | Sim |
| `compilacao-build` | `testes-unitarios` | `assembleDebug`, `bundleDebug` | Sim, mas não conta no orçamento de 3 minutos (§2) |

`analise-estatica` e `gate-contrato` rodam em paralelo (sem dependência entre si), ambos sobre o
mesmo checkout — essa paralelização é o que mantém o orçamento de 3 minutos viável mesmo somando
quatro jobs distintos.

## 5. Cache de dependências Gradle

`gradle/actions/setup-gradle@v4` já provê cache de dependências e de build cache remoto por
padrão; nenhuma configuração de cache manual (`actions/cache` apontando para `~/.gradle`) deve ser
adicionada por cima — duplicar cache é a causa mais comum de builds mais lentos, não mais
rápidos, nesse tipo de setup.

## 6. O que fica fora deste documento

- Pipeline de distribuição direta (Play Console / internal testing track): publicação automática via Google Play API fica para o Épico E6.

## 7. Geração de Artefatos (APK/AAB) e Assinatura de Release (Cartão 59)

A esteira Android (`.github/workflows/android.yml`) gera o APK de depuração (`app-debug.apk`) e o Android App Bundle de produção (`app-release.aab`), publicando ambos como artefatos da execução com retenção de 2 dias (era 7 até 08/11/2026, quando a cota de armazenamento de artefatos da organização estourou).

### Modo Não Assinado (Padrão em PRs)
Na ausência dos segredos de release no GitHub Secrets, o Gradle (`android/app/build.gradle.kts:51`) compila o AAB no modo release com minificação R8 e redução de recursos, mas **sem signingConfig**, gerando o AAB não assinado. Isso permite validação contínua da compilação e empacotamento em PRs públicos sem expor credenciais.

### Configuração Pendente de Pessoa (Keystore Oficial)
A assinatura oficial do bundle para envio à Google Play Store depende da criação e configuração manual dos seguintes segredos no GitHub Repository Secrets (ação humana exclusiva do Cauê/sócios):

1. **`FRILA_RELEASE_KEYSTORE_BASE64`**: Conteúdo do arquivo de keystore (`.jks` ou `.keystore`) codificado em base64 (`base64 -i frila-release.jks`).
2. **`FRILA_RELEASE_KEYSTORE_PASSWORD`**: Senha do armazenamento de chaves.
3. **`FRILA_RELEASE_KEY_ALIAS`**: Alias da chave de release (ex.: `frila-release-key`).
4. **`FRILA_RELEASE_KEY_PASSWORD`**: Senha da chave privada de release.

Quando esses quatro segredos forem cadastrados, o workflow os decodificará temporariamente em tempo de execução para assinar o bundle antes do upload. **Nenhum segredo foi criado ou manipulado por agentes de IA.**

