# Matriz de Conformidade com as Diretrizes da App Store

Documento elaborado em 11/10/2026 sobre a branch `docs/ios-checklist-diretrizes-app-store-82` a partir de `origin/main` para atender ao critério de aceite do cartão do Trello [#82 (5Lx5v39r)](https://trello.com/c/5Lx5v39r) ("Checklist 100% marcada, com evidência... de cada item").

Este documento mapeia o estado de conformidade do app iOS às **Diretrizes de Revisão da App Store (App Store Review Guidelines)**. Diretrizes cujos fluxos de produção, homologação em backend ou artefatos de código ainda estão em ciclo de entrega pelo time estão classificadas como **Pendente**.

---

## 1. Resumo Executivo de Conformidade

| Diretriz | Tema | Requisito Apple | Onde no Código (`iOS/Sources/`) | Onde nos Testes (`iOS/Tests/`) | Estado |
|---|---|---|---|---|---|
| **1.2** | Segurança / UGC | Mecanismos de denúncia e bloqueio, canal de suporte publicado e moderação com triagem em até 5 dias úteis; resposta formal em até 15 dias corridos | `iOS/Sources/Apresentacao/Fluxos/Confianca/AcoesDeSeguranca.swift`, `iOS/Sources/Apresentacao/EnderecosOficiais.swift` | `iOS/Tests/UI/SegurancaUITests.swift`, `iOS/Tests/Unitarios/SegurancaViewModelTests.swift` | **Pendente** |
| **2.1** | Completude do App | Credenciais de revisão da Apple funcionais e ausência de telas em desenvolvimento/placeholders | `iOS/Sources/Apresentacao/Fluxos/Autenticacao/DestinoAposEntrada.swift`, `iOS/Sources/Apresentacao/Fluxos/Autenticacao/EntradaViewModel.swift` | `iOS/Tests/Unitarios/AutenticacaoTests.swift`, `iOS/Tests/Unitarios/SegurancaDoCodigoTests.swift` | **Pendente** |
| **2.3** | Metadados Precisos | Coerência entre telas, textos e descrições de permissão declaradas | `iOS/Resources/Localizable.xcstrings`, `iOS/Project.yml` | `iOS/Tests/Unitarios/CatalogoStringsTests.swift`, `iOS/Scripts/conferir-textos.sh` | **Pendente** |
| **4.2** | Funcionalidade Mínima | Interface nativa rica em SwiftUI, persistência local, operação offline e sem dependência estrita do DF | `iOS/Sources/App/FrilaApp.swift`, `iOS/Sources/Dados/CacheSwiftData.swift`, `iOS/Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift` | `iOS/Tests/Unitarios/OfflineTests.swift`, `iOS/Tests/Unitarios/PresencaDoTurnoViewModelTests.swift` | **Pendente** |
| **5.1.1** | Privacidade e Exclusão de Conta | Fluxo nativo completo de exclusão de conta e revogação de dados pessoais | `iOS/Sources/Apresentacao/Fluxos/Conta/TelaExclusaoDeConta.swift`, `iOS/Sources/Dados/SaidaDaConta.swift` | `iOS/Tests/UI/ExclusaoDeContaUITests.swift`, `iOS/Tests/Unitarios/LimpezaAposExclusaoTests.swift` | **Pendente** |
| **5.1.2** | Uso de Dados | Alinhamento estrito com o manifesto `PrivacyInfo.xcprivacy` e APIs com motivo | `iOS/Resources/PrivacyInfo.xcprivacy`, `iOS/Resources/Frameworks/PrivacyInfo.xcprivacy` | `iOS/Tests/Unitarios/SegurancaDoCodigoTests.swift`, `iOS/Scripts/conferir-release.sh` | **Pendente** |

---

## 2. Detalhamento por Diretriz

### Diretriz 1.2 — Segurança e Conteúdo Gerado pelo Usuário (User Generated Content)
- **Status:** **Pendente** (aguarda homologação do procedimento operacional pela equipe e integração completa de moderação no backend). Compromisso definido pelo Cauê em 15/10/2026: triagem em até 5 dias úteis; resposta formal em até 15 dias corridos.
- **Mapeamento de Código:**
  - `iOS/Sources/Apresentacao/Fluxos/Confianca/AcoesDeSeguranca.swift`: folha nativa de denúncia com seleção de motivos, atalhos de emergência (`tel:190`, `tel:180`) e confirmação de bloqueio;
  - `iOS/Sources/Apresentacao/Fluxos/Confianca/SegurancaViewModel.swift`: regras de validação do relato e gerenciamento dos bloqueios da sessão;
  - `iOS/Sources/Apresentacao/EnderecosOficiais.swift`: publicação oficial de canais de suporte e páginas institucionais de termos e privacidade.
- **Mapeamento de Testes:**
  - `iOS/Tests/UI/SegurancaUITests.swift`: validação de fluxo de denúncia e bloqueio na interface;
  - `iOS/Tests/Unitarios/SegurancaViewModelTests.swift`: validação de envio de denúncia e isolamento de perfis bloqueados.

### Diretriz 2.1 — Completude do App (App Completeness)
- **Status:** **Pendente** (aguarda validação final das contas de demonstração nos ambientes de homologação e produção da loja).
- **Mapeamento de Código:**
  - `iOS/Sources/Apresentacao/Fluxos/Autenticacao/DestinoAposEntrada.swift`: enum `DemonstracaoContas` identificando credenciais de revisão;
  - `iOS/Sources/Apresentacao/Fluxos/Autenticacao/EntradaViewModel.swift` e `CodigoViewModel.swift`: desvio do fluxo de envio de e-mail OTP para permitir autenticação direta pelo revisor;
  - `iOS/Sources/Apresentacao/CatalogoDesignSystem.swift`: isolamento de ferramentas de desenvolvimento sob `#if DEBUG`.
- **Mapeamento de Testes:**
  - `iOS/Tests/Unitarios/AutenticacaoTests.swift`: reconhecimento das contas de demonstração;
  - `iOS/Tests/Unitarios/SegurancaDoCodigoTests.swift`: conferência de ausência de argumentos de teste fora de `#if DEBUG`.

### Diretriz 2.3 — Metadados Precisos (Accurate Metadata)
- **Status:** **Pendente** (aguarda conferência final da ficha da App Store, capturas de tela e textos de divulgação aprovados pelo marketing).
- **Mapeamento de Código:**
  - `iOS/Resources/Localizable.xcstrings`: catálogo centralizado de strings no idioma pt-BR;
  - `iOS/Project.yml`: declarações de uso de recursos de hardware (`NSLocationWhenInUseUsageDescription` e precisão temporária para check-in);
  - `iOS/Scripts/conferir-textos.sh`: ferramenta de auditoria de conformidade textual do código.
- **Mapeamento de Testes:**
  - `iOS/Tests/Unitarios/CatalogoStringsTests.swift`: validação estática de chaves e traduções;
  - `iOS/Tests/Unitarios/PresencaDoTurnoViewModelTests.swift`: verificação de conformidade das declarações de localização.

### Diretriz 4.2 — Funcionalidade Mínima (Minimum Functionality)
- **Status:** **Pendente** (aguarda validação de desempenho sob condições de rede real 4G no aparelho de entrada conforme RNF04).
- **Mapeamento de Código:**
  - `iOS/Sources/App/FrilaApp.swift`: interface construída inteiramente em SwiftUI nativo;
  - `iOS/Sources/Dados/CacheSwiftData.swift`: persistência local de dados e fila offline de sincronização;
  - `iOS/Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift`: alternativa de check-in manual para operação fora do Distrito Federal ou na ausência de sinal de GPS.
- **Mapeamento de Testes:**
  - `iOS/Tests/Unitarios/OfflineTests.swift`: comportamento e leitura de cache sem conexão de rede;
  - `iOS/Tests/Unitarios/PresencaDoTurnoViewModelTests.swift`: fallback para registro manual de presença.

### Diretriz 5.1.1 — Coleta e Armazenamento de Dados / Privacidade e Exclusão de Conta
- **Status:** **Pendente** (aguarda conclusão da validação de ponta a ponta do cancelamento de turnos e anonimização de dados no servidor).
- **Mapeamento de Código:**
  - `iOS/Sources/Apresentacao/Fluxos/Conta/TelaExclusaoDeConta.swift`: interface nativa de exclusão de conta com aviso de consequências e confirmação destrutiva;
  - `iOS/Sources/Apresentacao/Fluxos/Conta/ExclusaoDeContaViewModel.swift`: levantamento de turnos futuros e acionamento da exclusão;
  - `iOS/Sources/Dados/SaidaDaConta.swift`: rotina de limpeza local completa do dispositivo após confirmação.
- **Mapeamento de Testes:**
  - `iOS/Tests/UI/ExclusaoDeContaUITests.swift`: fluxo nativo de exclusão de conta via interface;
  - `iOS/Tests/Unitarios/LimpezaAposExclusaoTests.swift`: garantia de exclusão de resíduos locais no aparelho.

### Diretriz 5.1.2 — Uso de Dados e Manifesto de Privacidade (Privacy Manifest & Data Use)
- **Status:** **Pendente** (aguarda geração do relatório de privacidade oficial consolidado pelo Xcode para arquivamento).
- **Mapeamento de Código:**
  - `iOS/Resources/PrivacyInfo.xcprivacy`: manifesto do app com declaração de não-rastreamento (`NSPrivacyTracking = false`) e tipos de dados funcionais;
  - `iOS/Resources/Frameworks/PrivacyInfo.xcprivacy`: manifesto do framework `FrilaDominio` com declaração de motivo para uso de `UserDefaults`;
  - `iOS/Scripts/conferir-release.sh`: validação automatizada da presença do manifesto e ausência de declarações indevidas no bundle.
- **Mapeamento de Testes:**
  - `iOS/Tests/Unitarios/SegurancaDoCodigoTests.swift`: conferência de proteção de arquivos gravados e ausência de dados sensíveis em logs.

---

## 3. Matriz de Rastreabilidade Técnica

| Diretriz Apple | Requisito Específico | Arquivo de Implementação no Repositório | Arquivo de Teste no Repositório | Estado |
|---|---|---|---|---|
| **1.2** | Mecanismo de Denúncia | `iOS/Sources/Apresentacao/Fluxos/Confianca/AcoesDeSeguranca.swift`<br>`iOS/Sources/Apresentacao/Fluxos/Confianca/SegurancaViewModel.swift` | `iOS/Tests/UI/SegurancaUITests.swift`<br>`iOS/Tests/Unitarios/SegurancaViewModelTests.swift` | **Pendente** |
| **1.2** | Bloqueio de Usuários | `iOS/Sources/Apresentacao/Fluxos/Confianca/AcoesDeSeguranca.swift`<br>`iOS/Sources/Apresentacao/Fluxos/Confianca/SegurancaViewModel.swift` | `iOS/Tests/UI/SegurancaUITests.swift`<br>`iOS/Tests/Unitarios/SegurancaViewModelTests.swift` | **Pendente** |
| **1.2** | Canais de Suporte e Contato | `iOS/Sources/Apresentacao/EnderecosOficiais.swift` | `iOS/Tests/Unitarios/CatalogoStringsTests.swift` | **Pendente** |
| **2.1** | Contas de Revisão Apple | `iOS/Sources/Apresentacao/Fluxos/Autenticacao/DestinoAposEntrada.swift`<br>`iOS/Sources/Apresentacao/Fluxos/Autenticacao/EntradaViewModel.swift` | `iOS/Tests/Unitarios/AutenticacaoTests.swift` | **Pendente** |
| **2.1** | Ausência de Telas Placeholder | `iOS/Sources/Apresentacao/CatalogoDesignSystem.swift`<br>`iOS/Scripts/conferir-release.sh` | `iOS/Tests/Unitarios/SegurancaDoCodigoTests.swift` | **Pendente** |
| **2.3** | Textos no Catálogo pt-BR | `iOS/Resources/Localizable.xcstrings`<br>`iOS/Scripts/conferir-textos.sh` | `iOS/Tests/Unitarios/CatalogoStringsTests.swift` | **Pendente** |
| **2.3** | Declarações de Permissão | `iOS/Project.yml` | `iOS/Tests/Unitarios/PresencaDoTurnoViewModelTests.swift` | **Pendente** |
| **4.2** | Interface Nativa SwiftUI | `iOS/Sources/App/FrilaApp.swift` | `iOS/Tests/UI/AuditoriaDeAcessibilidadeUITests.swift` | **Pendente** |
| **4.2** | Cache e Resiliência Geográfica | `iOS/Sources/Dados/CacheSwiftData.swift`<br>`iOS/Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift` | `iOS/Tests/Unitarios/OfflineTests.swift`<br>`iOS/Tests/Unitarios/PresencaDoTurnoViewModelTests.swift` | **Pendente** |
| **5.1.1** | Fluxo de Exclusão de Conta | `iOS/Sources/Apresentacao/Fluxos/Conta/TelaExclusaoDeConta.swift`<br>`iOS/Sources/Apresentacao/Fluxos/Conta/ExclusaoDeContaViewModel.swift` | `iOS/Tests/UI/ExclusaoDeContaUITests.swift` | **Pendente** |
| **5.1.1** | Limpeza de Dados do Aparelho | `iOS/Sources/Dados/SaidaDaConta.swift` | `iOS/Tests/Unitarios/LimpezaAposExclusaoTests.swift` | **Pendente** |
| **5.1.2** | Manifesto de Privacidade | `iOS/Resources/PrivacyInfo.xcprivacy`<br>`iOS/Resources/Frameworks/PrivacyInfo.xcprivacy` | `iOS/Scripts/conferir-release.sh` | **Pendente** |

---

## 4. Como Repetir e Verificar

```sh
# 1. Conferência estática de catálogo de textos e tokens do design system
iOS/Scripts/conferir-textos.sh

# 2. Conferência de conformidade do bundle compilado (ATS, ganchos e PrivacyInfo)
iOS/Scripts/conferir-release.sh build/beta/Build/Products/Release-Beta-iphonesimulator/Frila.app
```
