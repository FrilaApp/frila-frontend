# Dossiê de Privacidade da App Store — App Privacy (Cartão iWfyZwdu)

Documento normativo e laudo técnico para o preenchimento das informações de privacidade do aplicativo (**App Privacy / Nutrition Labels**) no App Store Connect, em estrita conformidade com as Diretrizes da Apple (**Diretrizes 5.1.1 e 5.1.2**), com a LGPD (Lei nº 13.709/2018), com o manifesto de privacidade (`iOS/Resources/PrivacyInfo.xcprivacy`) e com o contrato e modelagem do banco de dados do Frila.

---

## 1. Declaração Geral de Rastreamento (Tracking)

| Pergunta no App Store Connect | Resposta Oficial | Fundamentação Técnica e Evidência no Código |
|---|---|---|
| **Você ou seus parceiros terceirizados usam dados coletados deste app para rastrear usuários?** | **NÃO (*No*)** | `NSPrivacyTracking = false` declarado em `PrivacyInfo.xcprivacy:5-6`. Nenhum identificador ou dado coletado é cruzado com dados de apps de terceiros para publicidade direcionada ou medição de anúncios. O Frila não utiliza o framework `AppTrackingTransparency` nem possui SDKs de publicidade comportamental. |
| **Domínios de rastreamento de rede (Tracking Domains)** | **Nenhum (Array vazio)** | `NSPrivacyTrackingDomains = []` declarado em `PrivacyInfo.xcprivacy:7-8`. |

---

## 2. Inventário de Dados Coletados pelo App Store Connect

Todo dado coletado decorre estritamente da operação do aplicativo (**App Functionality**) ou da telemetria de integridade operacional (**Analytics / Diagnostics**).

### 2.1 Informações de Contato (Contact Info)

1. **Nome (*Name*):**
   - **Coletado:** Sim
   - **Vinculado ao Usuário (*Linked to User*):** Sim
   - **Usado para Rastreamento (*Tracking*):** Não
   - **Finalidade:** Funcionalidade do App (*App Functionality*) — Identificação do profissional e do contratante nos turnos, candidaturas e avaliações.
   - **Origem / Código:** `iOS/Sources/Apresentacao/Fluxos/Autenticacao/CadastroViewModel.swift`, `iOS/Sources/Dominio/Modelos.swift` (`PerfilProfissional`, `Estabelecimento`).

2. **Endereço de E-mail (*Email Address*):**
   - **Coletado:** Sim
   - **Vinculado ao Usuário (*Linked to User*):** Sim
   - **Usado para Rastreamento (*Tracking*):** Não
   - **Finalidade:** Funcionalidade do App (*App Functionality*) — Autenticação sem senha via OTP (código de 6 dígitos) e canal formal para comunicações da conta.
   - **Origem / Código:** `iOS/Sources/Apresentacao/Fluxos/Autenticacao/EntradaViewModel.swift`, `iOS/Sources/Apresentacao/Fluxos/Autenticacao/CodigoViewModel.swift`.

3. **Número de Telefone (*Phone Number*):**
   - **Coletado:** Sim
   - **Vinculado ao Usuário (*Linked to User*):** Sim
   - **Usado para Rastreamento (*Tracking*):** Não
   - **Finalidade:** Funcionalidade do App (*App Functionality*) — Liberação do contato direto via WhatsApp entre as partes exclusivamente após confirmação do turno.
   - **Origem / Código:** `iOS/Sources/Dominio/Portas.swift` (`ContatoDoTurnoDTO`), `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeusTurnos.swift`.

4. **Endereço Físico (*Physical Address*):**
   - **Coletado:** Sim
   - **Vinculado ao Usuário (*Linked to User*):** Sim
   - **Usado para Rastreamento (*Tracking*):** Não
   - **Finalidade:** Funcionalidade do App (*App Functionality*) — Endereço do estabelecimento para execução do turno e definição do ponto base de referência do profissional para cálculo de distância das vagas (raio de 15 km no DF).
   - **Origem / Código:** `iOS/Sources/Apresentacao/Fluxos/Contratante/CadastroEstabelecimento.swift`, `iOS/Sources/Dominio/Modelos.swift` (`Coordenada`), `iOS/Sources/Dominio/Localizacao.swift`.

---

### 2.2 Localização (Location)

1. **Localização Precisa (*Precise Location*):**
   - **Coletado:** Sim
   - **Vinculado ao Usuário (*Linked to User*):** Sim
   - **Usado para Rastreamento (*Tracking*):** Não
   - **Finalidade:** Funcionalidade do App (*App Functionality*) — Cadastro e alteração do ponto base do profissional (`ponto_base`) para despacho e cálculo de proximidade de vagas (a até 15 km), e cadastro da coordenada geográfica de estabelecimentos (`ponto`) pelo contratante. O check-in e check-out presenciais NÃO enviam coordenadas geográficas ao servidor: a leitura da localização do aparelho é utilizada exclusivamente no dispositivo para calcular a distância em metros até o ponto da vaga, enviando apenas o valor inteiro da distância e o instante do toque (RN22). Não há coleta de localização em segundo plano (*background location*).
   - **Origem / Código:** `iOS/Sources/Apresentacao/Fluxos/Profissional/PerfilProfissionalViewModel.swift` (`pontoBase`), `iOS/Sources/Apresentacao/Fluxos/Contratante/CadastroEstabelecimento.swift` (`ponto`), `iOS/Sources/Dados/DTOsContrato.swift` (`CadastroPerfilProfissionalDTO.ponto_base`, `CadastroEstabelecimentoDTO.ponto`), `iOS/Sources/App/Info.plist` (`NSLocationWhenInUseUsageDescription`).

---

### 2.3 Identificadores (Identifiers)

1. **ID do Usuário (*User ID*):**
   - **Coletado:** Sim
   - **Vinculado ao Usuário (*Linked to User*):** Sim
   - **Usado para Rastreamento (*Tracking*):** Não
   - **Finalidade:** Funcionalidade do App (*App Functionality*) — UUID da conta gerado pelo backend para manutenção de sessão e integridade relacional.
   - **Origem / Código:** `iOS/Sources/Dados/SessaoNoKeychainDoAparelho.swift`, `iOS/Sources/Dominio/Portas.swift` (`ObservadorDeSessao`).

2. **ID do Dispositivo (*Device ID*):**
   - **Coletado:** Sim
   - **Vinculado ao Usuário (*Linked to User*):** Sim
   - **Usado para Rastreamento (*Tracking*):** Não
   - **Finalidade:** Funcionalidade do App (*App Functionality*) — Token do Firebase Cloud Messaging (FCM) para envio de notificações transacionais de turnos e vagas.
   - **Origem / Código:** `iOS/Sources/Dados/AparelhoDePush.swift`, `iOS/Sources/Infraestrutura/CanalDePushDoAparelho.swift`.

---

### 2.4 Conteúdo do Usuário e Outros Dados (User Content & Other Data Types)

1. **Atendimento ao Cliente (*Customer Support*):**
   - **Coletado:** Sim
   - **Vinculado ao Usuário (*Linked to User*):** Sim
   - **Usado para Rastreamento (*Tracking*):** Não
   - **Finalidade:** Funcionalidade do App (*App Functionality*) — Relatos enviados pelo canal nativo de denúncia e contestações de suspensão.
   - **Origem / Código:** `iOS/Sources/Apresentacao/Fluxos/Confianca/AcoesDeSeguranca.swift`, `iOS/Sources/Apresentacao/Fluxos/Confianca/SegurancaViewModel.swift`, `iOS/Sources/Apresentacao/Fluxos/Conta/TelaContaSuspensa.swift`.

2. **Outro Conteúdo do Usuário (*Other User Content*):**
   - **Coletado:** Sim
   - **Vinculado ao Usuário (*Linked to User*):** Sim
   - **Usado para Rastreamento (*Tracking*):** Não
   - **Finalidade:** Funcionalidade do App (*App Functionality*) — Detalhes das vagas publicadas, avaliações mútuas com notas e critérios objetivos, e histórico de turnos.
   - **Origem / Código:** `iOS/Sources/Apresentacao/Fluxos/Contratante/PublicarVaga.swift`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaAvaliacao.swift`.

3. **Outros Tipos de Dados (*Other Data Types* — Data de Nascimento):**
   - **Coletado:** Sim
   - **Vinculado ao Usuário (*Linked to User*):** Sim
   - **Usado para Rastreamento (*Tracking*):** Não
   - **Finalidade:** Funcionalidade do App (*App Functionality*) — Verificação de maioridade 18+ (ECA Digital / regra de proteção de menores) e cálculo civil de corte no cadastro.
   - **Origem / Código:** `iOS/Sources/Infraestrutura/VerificadorDeIdadeDoSistema.swift`, `iOS/Sources/Apresentacao/Fluxos/Autenticacao/CadastroViewModel.swift`, `iOS/Sources/Dominio/Portas.swift` (`CadastroConta`). Declarado como `NSPrivacyCollectedDataTypeOtherDataTypes`.

---

### 2.5 Diagnósticos (Diagnostics)

1. **Dados de Falhas (*Crash Data*):**
   - **Coletado:** Sim
   - **Vinculado ao Usuário (*Linked to User*):** **Não**
   - **Usado para Rastreamento (*Tracking*):** Não
   - **Finalidade:** Funcionalidade do App (*App Functionality*) no manifesto atual da `main` (`iOS/Resources/PrivacyInfo.xcprivacy`).
     > **[DONO / Decisão de Privacidade]:** A documentação técnica do Firebase Crashlytics e as boas práticas de privacidade recomendam classificar como Análise Interna (*Analytics*), enquanto a `main` mantém `AppFunctionality`. A alteração de finalidade para `Analytics` no manifesto é uma decisão estratégica reservada ao proprietário do produto e ao time jurídico (`[DONO]`).
   - **Origem / Código:** `iOS/Sources/Infraestrutura/TelemetriaCrashlytics.swift`, `iOS/Resources/PrivacyInfo.xcprivacy`.

2. **Outros Dados de Diagnóstico (*Other Diagnostic Data*):**
   - **Coletado:** Sim
   - **Vinculado ao Usuário (*Linked to User*):** **Não**
   - **Usado para Rastreamento (*Tracking*):** Não
   - **Finalidade:** Funcionalidade do App (*App Functionality*) no manifesto atual da `main` (`iOS/Resources/PrivacyInfo.xcprivacy`).
     > **[DONO / Decisão de Privacidade]:** Medição anônima de latência e tempo de resposta de RPCs para observabilidade de desempenho. A alteração de finalidade para `Analytics` é uma decisão estratégica reservada ao proprietário (`[DONO]`).
   - **Origem / Código:** `iOS/Sources/Infraestrutura/TelemetriaCrashlytics.swift`, `iOS/Resources/PrivacyInfo.xcprivacy`.

---

### 2.6 Uso do App (Usage Data)

1. **Interação com o Produto (*Product Interaction*):**
   - **Coletado:** Sim
   - **Vinculado ao Usuário (*Linked to User*):** **Sim**
   - **Usado para Rastreamento (*Tracking*):** Não
   - **Finalidade:** Análise Interna (*Analytics*) — Registro de telemetria operacional com 14 eventos fechados de jornada (`app_aberto`, `vaga_vista`, `candidatura_enviada`, `checkin_concluido`, etc.). O evento é autenticado e persistido no backend com `evento_app.usuario_id`. Não há texto livre ou cruzamento de dados com terceiros.
   - **Origem / Código:** `iOS/Sources/Dominio/Telemetria.swift`, RPC `registrar_evento` (migração `20260930180000_telemetria_evento_app.sql`), `iOS/Resources/PrivacyInfo.xcprivacy` (`NSPrivacyCollectedDataTypeProductInteraction`).

---

## 3. Conformidade com a Exclusão de Conta In-App (Diretriz 5.1.1)

A Apple exige que aplicativos que permitam a criação de contas ofereçam também a exclusão direta de dentro do aplicativo.

1. **Acesso Direto nos Dois Perfis (Sem Submenus Ocultos):**
   - No perfil profissional: `iOS/Sources/Apresentacao/Fluxos/Perfil/PerfisDaConta.swift:215` (`accessibilityIdentifier: "perfil-excluir-conta"`).
   - No perfil contratante: `iOS/Sources/Apresentacao/Fluxos/Perfil/PerfisDaConta.swift:321` (`accessibilityIdentifier: "estabelecimento-excluir-conta"`).
   - No painel do contratante sem estabelecimento: `iOS/Sources/Apresentacao/Fluxos/Contratante/FluxoDoContratante.swift:96` (`accessibilityIdentifier: "contratante-sem-estabelecimento-excluir-conta"`).

2. **Fluxo em Duas Etapas:**
   - Explicação clara das consequências (anonimização do perfil, cancelamento de turnos futuros e irrevogabilidade da ação).
   - Toggle explícito de consentimento (`toggle-confirmar-consequencias`).
   - Diálogo modal destrutivo final (`botao-confirmar-exclusao-dialogo`).
   - Telas e ViewModels dedicados: `iOS/Sources/Apresentacao/Fluxos/Conta/TelaExclusaoDeConta.swift` e `iOS/Sources/Apresentacao/Fluxos/Conta/ExclusaoDeContaViewModel.swift`.

3. **Limpeza Local Completa:**
   - Execução de `iOS/Sources/Dados/SaidaDaConta.swift`: expurgo de tokens de autenticação no Keychain, encerramento do canal de push e limpeza da base local SwiftData.
   - Redirecionamento imediato para a tela de entrada.

4. **Evidência de Testes Automatizados:**
   - Teste de interface: `iOS/Tests/UI/ExclusaoDeContaUITests.swift`.
   - Teste unitário de limpeza: `iOS/Tests/Unitarios/LimpezaAposExclusaoTests.swift`.

---

## 4. Validação dos Links Legais e Suporte

Todas as URLs oficiais foram confirmadas em produção sob protocolo seguro HTTPS e com resposta HTTP 200:

| Finalidade | URL Oficial | Consta no App (`iOS/Sources/Apresentacao/EnderecosOficiais.swift`) | Consta na Ficha (`FichaAppStore.md`) |
|---|---|:---:|:---:|
| **Termos de Uso** | `https://frila.netlify.app/termos` | Sim (`enderecos.termosDeUso`) | Sim (`https://frila.app/termos` com redirect) |
| **Política de Privacidade** | `https://frila.netlify.app/privacidade` | Sim (`enderecos.politicaDePrivacidade`) | Sim (`https://frila.app/privacidade` com redirect) |
| **Página de Suporte Web** | `https://frila.app/suporte` | Não (app usa `mailto:`, via `enderecos.urlSuporte`) | Sim (`URL de Suporte`) |
| **E-mail de Suporte / DPO** | `suportefrila@gmail.com` | Sim (`enderecos.emailSuporte`) | Sim |

> **Nota sobre URL e canal de suporte:** A página pública web em `https://frila.app/suporte` é a URL oficial registrada na ficha da App Store (`FichaAppStore.md` e `iOS/Docs/PaginaPublica/suporte.md`). No código do aplicativo, o suporte é acionado nativamente por e-mail via `enderecos.emailSuporte` (`"suportefrila@gmail.com"`) e pela propriedade computada `enderecos.urlSuporte` (`"mailto:suportefrila@gmail.com"`), sem dependência de requisições HTTP para a rota `/suporte`. As URLs de Termos e Privacidade apontam para a infraestrutura oficial na Netlify (`frila.netlify.app`), conforme alinhado no PR #314.

---

## 5. Matriz de Coerência (Ficha x Manifesto x Política x Código)

| Dado / Recurso | App Privacy (Loja) | Manifesto (`PrivacyInfo.xcprivacy`) | Política de Privacidade (`/privacidade`) | Código-Fonte (`iOS/Sources`) |
|---|:---:|:---:|:---:|:---:|
| Nome e E-mail | Sim (Vinculado) | Sim (`NSPrivacyCollectedDataTypeName`, `EmailAddress`) | Sim (Seção 2.1) | `Apresentacao/Fluxos/Autenticacao/CadastroViewModel.swift`, `Apresentacao/Fluxos/Autenticacao/EntradaViewModel.swift` |
| Telefone | Sim (Vinculado) | Sim (`NSPrivacyCollectedDataTypePhoneNumber`) | Sim (Seção 2.1) | `Dominio/Portas.swift`, `Apresentacao/Fluxos/Profissional/TelaMeusTurnos.swift` |
| Endereço Físico | Sim (Vinculado) | Sim (`NSPrivacyCollectedDataTypePhysicalAddress`) | Sim (Seção 2.2) | `Apresentacao/Fluxos/Contratante/CadastroEstabelecimento.swift`, `Dominio/Localizacao.swift` |
| Localização Precisa | Sim (Vinculado) | Sim (`NSPrivacyCollectedDataTypePreciseLocation`) | Sim (Seção 2.2) | Ponto base (`PerfilProfissionalViewModel.swift`), ponto do estabelecimento (`CadastroEstabelecimento.swift`) e `Dados/DTOsContrato.swift` (o check-in envia apenas a distância calculada, não coordenadas) |
| Identificadores (UUID, FCM) | Sim (Vinculado) | Sim (`NSPrivacyCollectedDataTypeUserID`, `DeviceID`) | Sim (Seção 2.4) | `Dados/SessaoNoKeychainDoAparelho.swift`, `Dados/AparelhoDePush.swift` |
| Conteúdo do Usuário | Sim (Vinculado) | Sim (`NSPrivacyCollectedDataTypeOtherUserContent`) | Sim (Seção 2.5) | `Apresentacao/Fluxos/Contratante/PublicarVaga.swift`, `Apresentacao/Fluxos/Profissional/TelaAvaliacao.swift` |
| Data de Nascimento | Sim (Vinculado) | Sim (`NSPrivacyCollectedDataTypeOtherDataTypes`) | Sim (Seção 2.1 / Maioridade 18+) | `Infraestrutura/VerificadorDeIdadeDoSistema.swift`, `Apresentacao/Fluxos/Autenticacao/CadastroViewModel.swift` |
| Relatórios de Falha | Sim (Não Vinculado) | Sim (`NSPrivacyCollectedDataTypeCrashData`, AppFunctionality [main] / Decisão [DONO]) | Sim (Seção 2.6) | Firebase Crashlytics (`Infraestrutura/TelemetriaCrashlytics.swift`) |
| Diagnósticos de Rede | Sim (Não Vinculado) | Sim (`NSPrivacyCollectedDataTypeOtherDiagnosticData`, AppFunctionality [main] / Decisão [DONO]) | Sim (Seção 2.6) | Firebase Crashlytics (`Infraestrutura/TelemetriaCrashlytics.swift`) |
| Interação com o Produto | Sim (Vinculado) | Sim (`NSPrivacyCollectedDataTypeProductInteraction`, Analytics) | Sim (Seção 2.6) | `Dominio/Telemetria.swift`, RPC `registrar_evento` |
| Rastreamento de Terceiros | **Não** | **Não (`NSPrivacyTracking = false`)** | **Não** (Sem rastreadores) | Nenhum SDK de ads |
| Exclusão In-App de Conta | Declarado | Conformidade com Diretriz 5.1.1 | Seção 5 (Direitos do Titular) | `Apresentacao/Fluxos/Perfil/PerfisDaConta.swift`, `Apresentacao/Fluxos/Conta/TelaExclusaoDeConta.swift` |
