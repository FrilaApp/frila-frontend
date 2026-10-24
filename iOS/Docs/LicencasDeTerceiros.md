# Inventário de Licenças de Terceiros e Recursos Externos

**Data:** 12/10/2026  
**Auditor / Responsável:** Steve Rogers (Documentos e Inventário)  
**Repositório:** `FrilaApp/frila-frontend`  
**Referência Trello:** [6br4qElo](https://trello.com/c/6br4qElo) — *S3 · Jurídico + iOS · Licenças de terceiros, direitos de conteúdo e selo da App Store*  
**Diretrizes e Normas Vinculadas:**
- Apple App Store Review Guidelines: Diretriz 5.2 (Intellectual Property)
- Apple Developer Program License Agreement
- SPDX License List: Apache-2.0, MIT, BSD-3-Clause, Zlib

---

## 1. Visão Geral e Escopo da Auditoria

Este documento consolida o inventário formal e exaustivo de todos os componentes de software, bibliotecas, fontes tipográficas, conjuntos de ícones e recursos gráficos de terceiros incorporados ou vinculados ao build 1.0 do aplicativo **Frila** (`FrilaApp/frila-frontend`).

O objetivo é fornecer rastreabilidade jurídica completa para cumprimento das exigências de atribuição de código aberto e conformidade com a política de propriedade intelectual da Apple (Diretriz 5.2 da App Store).

### Resumo do Inventário

| Categoria | Quantidade de Itens | Origem / Mecanismo | Status de Conformidade |
|---|:---:|---|---|
| Pacotes Swift (SPM) | 20 | `iOS/Package.resolved` | 100% catalogados e atribuídos na UI |
| Fontes tipográficas de terceiros | 1 família (4 arquivos) | `iOS/Resources/Fonts` (Bricolage Grotesque, SIL OFL 1.1) | Conforme (licença junto dos arquivos; atualizado em 24/10/2026) |
| Conjuntos de ícones de terceiros | 0 | N/A (SF Symbols nativos da Apple) | Conforme (Apple Developer Agreement) |
| Código copiado / snippets externos | 0 | N/A (apenas SPM rastreado) | Conforme (zero inclusão manual) |
| Imagens/ativos de terceiros no binário | 0 | N/A (`AppIcon` e `AccentColor` próprios) | Conforme (titularidade exclusiva FrilaApp) |

---

## 2. Inventário de Dependências de Código Aberto (SPM)

Todas as dependências externas são resolvidas estritamente pelo Swift Package Manager a partir de versões e revisões (*commit hashes*) fixadas em `iOS/Package.resolved`. O catálogo binário correspondente é gerado por `iOS/Scripts/gerar-licencas.py` e integrado ao recurso de produção `iOS/Resources/Licencas.json`.

| Pacote | Identificador SPM | Versão Fixada | Revisão Git (Commit) | Licença SPDX | Arquivo Lido no Checkout | Repositório Remoto |
|---|---|:---:|:---:|:---:|:---:|---|
| **abseil-cpp-binary** | `abseil-cpp-binary` | `1.2024072200.0` | `bbe8b69694d7873315fd3a4ad41efe043e1c07c5` | Apache-2.0 | `LICENSE` | [google/abseil-cpp-binary](https://github.com/google/abseil-cpp-binary/tree/bbe8b69694d7873315fd3a4ad41efe043e1c07c5) |
| **app-check** | `app-check` | `11.3.2` | `97f7d74dd0e8f3d0fe5fc75cc8957aa73bdc948a` | Apache-2.0 | `LICENSE` | [google/app-check](https://github.com/google/app-check/tree/97f7d74dd0e8f3d0fe5fc75cc8957aa73bdc948a) |
| **firebase-ios-sdk** | `firebase-ios-sdk` | `12.19.2` | `8c29ca981990a32e626c8617544fa65d22b1834f` | Apache-2.0 | `LICENSE` | [firebase/firebase-ios-sdk](https://github.com/firebase/firebase-ios-sdk/tree/8c29ca981990a32e626c8617544fa65d22b1834f) |
| **google-ads-on-device-conversion-ios-sdk** | `google-ads-on-device-conversion-ios-sdk` | `3.7.0` | `0208e2681ec81f8a9c81084696f60fcce26cb7ee` | Apache-2.0 | `LICENSE` | [googleads/google-ads-on-device-conversion-ios-sdk](https://github.com/googleads/google-ads-on-device-conversion-ios-sdk/tree/0208e2681ec81f8a9c81084696f60fcce26cb7ee) |
| **GoogleAppMeasurement** | `googleappmeasurement` | `12.19.2` | `b8455dd2ff55cc269fda7a4f9eac6c1e3588c53f` | Apache-2.0 | `LICENSE` | [google/GoogleAppMeasurement](https://github.com/google/GoogleAppMeasurement/tree/b8455dd2ff55cc269fda7a4f9eac6c1e3588c53f) |
| **GoogleDataTransport** | `googledatatransport` | `10.1.1` | `ba3358d3c3dbae8ef230b58a46b97ad65e84e974` | Apache-2.0 | `LICENSE` | [google/GoogleDataTransport](https://github.com/google/GoogleDataTransport/tree/ba3358d3c3dbae8ef230b58a46b97ad65e84e974) |
| **GoogleUtilities** | `googleutilities` | `8.1.3` | `92c8f6dc3ac375d6febdfcb3db68bc3d10633db3` | Apache-2.0 | `LICENSE` | [google/GoogleUtilities](https://github.com/google/GoogleUtilities/tree/92c8f6dc3ac375d6febdfcb3db68bc3d10633db3) |
| **grpc-binary** | `grpc-binary` | `1.69.1` | `75b31c842f664a0f46a2e590a570e370249fd8f6` | Apache-2.0 | `LICENSE` | [google/grpc-binary](https://github.com/google/grpc-binary/tree/75b31c842f664a0f46a2e590a570e370249fd8f6) |
| **gtm-session-fetcher** | `gtm-session-fetcher` | `5.3.1` | `724a52eea6329b7e12d3ad8300d76ca9f3895fcc` | Apache-2.0 | `LICENSE` | [google/gtm-session-fetcher](https://github.com/google/gtm-session-fetcher/tree/724a52eea6329b7e12d3ad8300d76ca9f3895fcc) |
| **interop-ios-for-google-sdks** | `interop-ios-for-google-sdks` | `101.0.0` | `040d087ac2267d2ddd4cca36c757d1c6a05fdbfe` | Apache-2.0 | `LICENSE` | [google/interop-ios-for-google-sdks](https://github.com/google/interop-ios-for-google-sdks/tree/040d087ac2267d2ddd4cca36c757d1c6a05fdbfe) |
| **leveldb** | `leveldb` | `1.22.5` | `a0bc79961d7be727d258d33d5a6b2f1023270ba1` | BSD-3-Clause | `LICENSE` | [firebase/leveldb](https://github.com/firebase/leveldb/tree/a0bc79961d7be727d258d33d5a6b2f1023270ba1) |
| **nanopb** | `nanopb` | `2.30910.1` | `3851d94a41890dea16dc3db34caf60e585cb4163` | Zlib | `LICENSE.txt` | [firebase/nanopb](https://github.com/firebase/nanopb/tree/3851d94a41890dea16dc3db34caf60e585cb4163) |
| **promises** | `promises` | `2.4.1` | `f4a19a3c313dc2616c70bb49d29a799fb16be837` | Apache-2.0 | `LICENSE` | [google/promises](https://github.com/google/promises/tree/f4a19a3c313dc2616c70bb49d29a799fb16be837) |
| **supabase-swift** | `supabase-swift` | `2.55.2` | `40344fb3a7007d772218c6ddf6bca9febd8cb226` | MIT | `LICENSE` | [supabase/supabase-swift](https://github.com/supabase/supabase-swift/tree/40344fb3a7007d772218c6ddf6bca9febd8cb226) |
| **swift-asn1** | `swift-asn1` | `1.7.3` | `3b6410f7dee09eb33cdd26260c5fd47fda19b0e2` | Apache-2.0 | `LICENSE.txt` + `NOTICE.txt` | [apple/swift-asn1](https://github.com/apple/swift-asn1/tree/3b6410f7dee09eb33cdd26260c5fd47fda19b0e2) |
| **swift-clocks** | `swift-clocks` | `1.1.1` | `82440fa0a8b1c381a6d1e8e0fc7bbba53ec63204` | MIT | `LICENSE` | [pointfreeco/swift-clocks](https://github.com/pointfreeco/swift-clocks/tree/82440fa0a8b1c381a6d1e8e0fc7bbba53ec63204) |
| **swift-concurrency-extras** | `swift-concurrency-extras` | `1.4.1` | `5fa253428866f2360c3754e88537f700ed2656b5` | MIT | `LICENSE` | [pointfreeco/swift-concurrency-extras](https://github.com/pointfreeco/swift-concurrency-extras/tree/5fa253428866f2360c3754e88537f700ed2656b5) |
| **swift-crypto** | `swift-crypto` | `4.5.2` | `da9d28d69ebe3894b18376c8f2395c2f37b8448f` | Apache-2.0 | `LICENSE.txt` + `NOTICE.txt` | [apple/swift-crypto](https://github.com/apple/swift-crypto/tree/da9d28d69ebe3894b18376c8f2395c2f37b8448f) |
| **swift-http-types** | `swift-http-types` | `1.8.0` | `bff4b6903cdc99dda49649dd52f46c11cfd3ed50` | Apache-2.0 | `LICENSE.txt` + `NOTICE.txt` | [apple/swift-http-types](https://github.com/apple/swift-http-types/tree/bff4b6903cdc99dda49649dd52f46c11cfd3ed50) |
| **xctest-dynamic-overlay** | `xctest-dynamic-overlay` | `1.13.1` | `d9308ad679143c26a30dec52daefe82f54af2b82` | MIT | `LICENSE` | [pointfreeco/xctest-dynamic-overlay](https://github.com/pointfreeco/xctest-dynamic-overlay/tree/d9308ad679143c26a30dec52daefe82f54af2b82) |

---

## 3. Detalhamento dos Pacotes e Obrigações Contratuais

### 3.1 Licenças Apache License 2.0 (14 pacotes)
- **Pacotes abrangidos:** `abseil-cpp-binary`, `app-check`, `firebase-ios-sdk`, `google-ads-on-device-conversion-ios-sdk`, `GoogleAppMeasurement`, `GoogleDataTransport`, `GoogleUtilities`, `grpc-binary`, `gtm-session-fetcher`, `interop-ios-for-google-sdks`, `promises`, `swift-asn1`, `swift-crypto`, `swift-http-types`.
- **Condições obrigatórias atendidas:**
  1. *Seção 4(a):* Cópia integral do texto da licença acompanhando a distribuição binária. Cumprido através de `iOS/Resources/Licencas.json` e tela nativa `TelaLicencas.swift`.
  2. *Seção 4(c) e 4(d):* Retenção de direitos autorais e inclusão do arquivo `NOTICE` quando distribuído. Nos pacotes da Apple (`swift-asn1`, `swift-crypto`, `swift-http-types`), o arquivo `NOTICE.txt` é lido pelo script `gerar-licencas.py` e exibido na seção "Avisos do pacote" na tela de detalhes.
  3. *Seção 6:* Proibição de uso de marcas comerciais ou logotipos dos contribuidores sem autorização prévia. O aplicativo não utiliza marcas nominativas ou logotipos do Google, Firebase ou Apple associados a esses pacotes.

### 3.2 Licenças MIT (4 pacotes)
- **Pacotes abrangidos:** `supabase-swift`, `swift-clocks`, `swift-concurrency-extras`, `xctest-dynamic-overlay`.
- **Condições obrigatórias atendidas:**
  - O aviso de direitos autorais e o texto integral da permissão da licença MIT são reproduzidos integralmente na tela nativa de detalhes da licença (`TelaDetalheLicenca.swift`).

### 3.3 Licença BSD 3-Clause (1 pacote)
- **Pacote abrangido:** `leveldb` (v1.22.5).
- **Condições obrigatórias atendidas:**
  - Reprodução integral do aviso de direitos autorais do Google, lista de condições e isenção de garantia em `iOS/Resources/Licencas.json`.
  - Nenhuma utilização de nomes dos autores ou contribuidores para endossar ou promover o aplicativo.

### 3.4 Licença Zlib (1 pacote)
- **Pacote abrangido:** `nanopb` (v2.30910.1).
- **Condições obrigatórias atendidas:**
  - Reprodução do aviso de autoria de Petteri Aimonen e termos de uso. O binário não declara falsamente a autoria do software e não oculta a origem do código.

---

## 4. Recursos de Terceiros: Fontes, Ícones e Código Copiado

### 4.1 Fontes Tipográficas
- **Auditoria (24/10/2026):** Varredura em todo o repositório `frila-frontend` por arquivos de fonte (`.ttf`, `.otf`, `.ttc`, `.woff`, `.woff2`) e por registro em código (`CTFontManagerRegisterFontsForURL`).
- **Resultado:** **Uma família externa incorporada: Bricolage Grotesque** (Regular, Medium, Bold e ExtraBold), em `iOS/Resources/Fonts/BricolageGrotesque-*.ttf`, registrada no processo por `FontesFrila` (`DesignSystem/DesignTokens.swift`), sem `UIAppFonts` no `Info.plist`. Veio do design system do Fabrício (FrilaLowPhase) e é a voz dos títulos, das perguntas do Estúdio de Criação e dos papéis `display`/`placard` do Hi-Fi (`Docs/DesignSystem.md`).
- **Licença:** SIL Open Font License 1.1 (OFL), texto integral em `iOS/Resources/Fonts/BricolageGrotesque-OFL.txt`, distribuído junto dos arquivos. A OFL permite embutir a fonte no app e distribuí-la com ele; a fonte não pode ser vendida sozinha e, se for redistribuída à parte, a licença segue junto. Nome reservado: não renomeamos a família (os arquivos têm o nome original).
- **Demais textos:** o restante do app usa o sistema tipográfico nativo da Apple (San Francisco e New York) por estilos semânticos do SwiftUI, coberto pelo contrato de desenvolvimento do iOS.

### 4.2 Ícones e Elementos Gráficos
- **Auditoria:** Varredura em `iOS/Sources/Apresentacao` por ícones vetoriais de terceiros ou fontes de ícones (como FontAwesome ou Material Icons).
- **Resultado:** **Nenhum conjunto de ícones de terceiros.**
- **Conformidade:** Todos os glifos gráficos do app consomem a biblioteca de sistema **SF Symbols** via chamadas nativas `Image(systemName: "...")`. O uso dos símbolos SF Symbols cumpre integralmente os termos de licenciamento da Apple (uso restrito a softwares desenvolvidos para plataformas Apple).

### 4.3 Código Copiado e Snippets Estáticos
- **Auditoria:** Varredura em todas as subpastas de `iOS/Sources/` em busca de arquivos de código-fonte copiados manualmente ou bibliotecas *in-tree*.
- **Resultado:** **Nenhum código copiado.**
- **Conformidade:** 100% das dependências externas são consumidas via Swift Package Manager sob as revisões exatas registradas em `iOS/Package.resolved`. Não existem arquivos terceiros soltos no projeto.

### 4.4 Ativos Gráficos do Aplicativo (`App.xcassets`)
- **Auditoria:** Inspeção do catálogo de ativos `iOS/Resources/App.xcassets`.
- **Resultado:** O catálogo contém apenas:
  - `AppIcon.appiconset`: Ícone do aplicativo desenvolvido exclusivamente pelo time FrilaApp.
  - `AccentColor.colorset`: Paleta de cores semânticas da identidade visual da marca.
- **Conformidade:** Nenhum ativo visual pertencente a terceiros faz parte dos pacotes do aplicativo.

---

## 5. Arquitetura de Exibição no App e Testes Automatizados

1. **Geração Automatizada:**
   - Script oficial: `iOS/Scripts/gerar-licencas.py`.
   - Lê os checkouts derivados do Xcode (`SourcePackages/checkouts`) e o arquivo `iOS/Package.resolved`.
   - Gera o arquivo `iOS/Resources/Licencas.json` garantindo integridade e paridade com o binário real.

2. **Interface do Usuário (UI):**
   - Localização no app: **Perfil > Ajuda e suporte > Licenças de código aberto** (`TelaAjudaPerfil.swift` e `TelaLicencas.swift`).
   - Apresenta lista alfabética de todos os 20 pacotes com versão, tipo de licença e link direto para o repositório público na revisão exata.
   - Detalhe acessível (`TelaDetalheLicenca.swift`): exibe o texto integral da licença e eventuais avisos do arquivo `NOTICE`.

3. **Verificação Automatizada em Testes:**
   - `LicencasTests.swift:32` (`todoPacoteTemLicenca`): Falha imediatamente no build caso qualquer pacote adicionado ao `Package.resolved` não possua entrada correspondente na mesma revisão em `Licencas.json`, ou se houver pacote órfão.
   - `LicencasTests.swift:53` (`entradasCompletas`): Valida que todas as entradas possuem nome, versão, tipo SPDX, URL HTTPS válida e texto integral de licença.
   - `LicencasTests.swift:67` (`textosEstaoNoCatalogo`): Valida que todos os textos da tela estão traduzidos e registrados no catálogo de strings `Localizable.xcstrings`.
   - `LicencasUITests.swift`: Valida navegação visual, rolagem e acessibilidade da tela no simulador.
