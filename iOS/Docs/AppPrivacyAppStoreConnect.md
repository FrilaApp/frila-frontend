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
   - **Origem / Código:** `CadastroViewModel.swift`, `PerfilProfissional.swift`, `Contratante.swift`.

2. **Endereço de E-mail (*Email Address*):**
   - **Coletado:** Sim
   - **Vinculado ao Usuário (*Linked to User*):** Sim
   - **Usado para Rastreamento (*Tracking*):** Não
   - **Finalidade:** Funcionalidade do App (*App Functionality*) — Autenticação sem senha via OTP (código de 6 dígitos) e canal formal para comunicações da conta.
   - **Origem / Código:** `EntradaViewModel.swift`, `CodigoViewModel.swift`.

3. **Número de Telefone (*Phone Number*):**
   - **Coletado:** Sim
   - **Vinculado ao Usuário (*Linked to User*):** Sim
   - **Usado para Rastreamento (*Tracking*):** Não
   - **Finalidade:** Funcionalidade do App (*App Functionality*) — Liberação do contato direto via WhatsApp entre as partes exclusivamente após confirmação do turno.
   - **Origem / Código:** `ContatoDTO.swift`, `WhatsAppDoTurno.swift`.

4. **Endereço Físico (*Physical Address*):**
   - **Coletado:** Sim
   - **Vinculado ao Usuário (*Linked to User*):** Sim
   - **Usado para Rastreamento (*Tracking*):** Não
   - **Finalidade:** Funcionalidade do App (*App Functionality*) — Endereço do estabelecimento para execução do turno e definição do ponto base de referência do profissional para cálculo de distância das vagas (raio de 15 km no DF).
   - **Origem / Código:** `CadastroEstabelecimento.swift`, `PontoBase.swift`.

---

### 2.2 Localização (Location)

1. **Localização Precisa (*Precise Location*):**
   - **Coletado:** Sim
   - **Vinculado ao Usuário (*Linked to User*):** Sim
   - **Usado para Rastreamento (*Tracking*):** Não
   - **Finalidade:** Funcionalidade do App (*App Functionality*) — Validação presencial do check-in no local do turno por aproximação geográfica e cálculo da distância do profissional até o ponto da vaga. Não há coleta em segundo plano (*background location*).
   - **Origem / Código:** `SecaoDePresenca.swift`, `PresencaDoTurnoViewModel.swift`, `Project.yml:NSLocationWhenInUseUsageDescription`.

---

### 2.3 Identificadores (Identifiers)

1. **ID do Usuário (*User ID*):**
   - **Coletado:** Sim
   - **Vinculado ao Usuário (*Linked to User*):** Sim
   - **Usado para Rastreamento (*Tracking*):** Não
   - **Finalidade:** Funcionalidade do App (*App Functionality*) — UUID da conta gerado pelo backend para manutenção de sessão e integridade relacional.
   - **Origem / Código:** `SessaoNoKeychain.swift`, `ApiCliente.swift`.

2. **ID do Dispositivo (*Device ID*):**
   - **Coletado:** Sim
   - **Vinculado ao Usuário (*Linked to User*):** Sim
   - **Usado para Rastreamento (*Tracking*):** Não
   - **Finalidade:** Funcionalidade do App (*App Functionality*) — Token do Firebase Cloud Messaging (FCM) para envio de notificações transacionais de turnos e vagas.
   - **Origem / Código:** `AparelhoDePush.swift`, `CanalDePush.swift`.

---

### 2.4 Conteúdo do Usuário (User Content)

1. **Atendimento ao Cliente (*Customer Support*):**
   - **Coletado:** Sim
   - **Vinculado ao Usuário (*Linked to User*):** Sim
   - **Usado para Rastreamento (*Tracking*):** Não
   - **Finalidade:** Funcionalidade do App (*App Functionality*) — Relatos enviados pelo canal nativo de denúncia e contestações de suspensão.
   - **Origem / Código:** `AcoesDeSeguranca.swift`, `SegurancaViewModel.swift`, `TelaContaSuspensa.swift`.

2. **Outro Conteúdo do Usuário (*Other User Content*):**
   - **Coletado:** Sim
   - **Vinculado ao Usuário (*Linked to User*):** Sim
   - **Usado para Rastreamento (*Tracking*):** Não
   - **Finalidade:** Funcionalidade do App (*App Functionality*) — Detalhes das vagas publicadas, avaliações mútuas com notas e critérios objetivos, e histórico de turnos.
   - **Origem / Código:** `PublicarVaga.swift`, `TelaAvaliacao.swift`.

---

### 2.5 Diagnósticos (Diagnostics)

1. **Dados de Falhas (*Crash Data*):**
   - **Coletado:** Sim
   - **Vinculado ao Usuário (*Linked to User*):** **Não**
   - **Usado para Rastreamento (*Tracking*):** Não
   - **Finalidade:** Análise Interna (*Analytics / App Functionality*) — Relatórios anônimos de incidentes coletados pelo Firebase Crashlytics para garantia de estabilidade.
   - **Origem / Código:** `Crashlytics`, `PrivacyInfo.xcprivacy:108-118`.

2. **Outros Dados de Diagnóstico (*Other Diagnostic Data*):**
   - **Coletado:** Sim
   - **Vinculado ao Usuário (*Linked to User*):** **Não**
   - **Usado para Rastreamento (*Tracking*):** Não
   - **Finalidade:** Análise Interna (*Analytics / App Functionality*) — Medição de latência e telemetria operacional agregada de requisições.
   - **Origem / Código:** `Telemetria.swift`, `PrivacyInfo.xcprivacy:132-142`.

---

## 3. Conformidade com a Exclusão de Conta In-App (Diretriz 5.1.1)

A Apple exige que aplicativos que permitam a criação de contas ofereçam também a exclusão direta de dentro do aplicativo.

1. **Acesso Direto nos Dois Perfis (Sem Submenus Ocultos):**
   - No perfil profissional: `PerfisDaConta.swift:201–217` (`accessibilityIdentifier: "perfil-excluir-conta"`).
   - No perfil contratante: `PerfisDaConta.swift:306–321` (`accessibilityIdentifier: "estabelecimento-excluir-conta"`).
   - No painel do contratante sem estabelecimento: `PainelContratanteSemEstabelecimento.swift:66–75`.

2. **Fluxo em Duas Etapas:**
   - Explicação clara das consequências (anonimização do perfil, cancelamento de turnos futuros e irrevogabilidade da ação).
   - Toggle explícito de consentimento (`toggle-confirmar-consequencias`).
   - Diálogo modal destrutivo final (`botao-confirmar-exclusao-dialogo`).

3. **Limpeza Local Completa:**
   - Execução de `SaidaDaConta.swift`: expurgo de tokens de autenticação no Keychain, encerramento do canal de push e limpeza da base local SwiftData.
   - Redirecionamento imediato para a tela de entrada.

4. **Evidência de Testes Automatizados:**
   - Teste de interface: `iOS/Tests/UI/ExclusaoDeContaUITests.swift`.
   - Teste unitário de limpeza: `iOS/Tests/Unitarios/LimpezaAposExclusaoTests.swift`.

---

## 4. Validação dos Links Legais e Suporte

Todas as URLs oficiais foram confirmadas em produção sob protocolo seguro HTTPS e com resposta HTTP 200:

| Finalidade | URL Oficial | Consta no App (`EnderecosOficiais.swift`) | Consta na Ficha (`FichaAppStore.md`) |
|---|---|:---:|:---:|
| **Termos de Uso** | `https://frila.app/termos` | Sim (`enderecos.termosDeUso`) | Sim |
| **Política de Privacidade** | `https://frila.app/privacidade` | Sim (`enderecos.politicaDePrivacidade`) | Sim |
| **Página de Suporte** | `https://frila.app/suporte` | Sim (`enderecos.urlSuporte`) | Sim |
| **E-mail de Suporte / DPO** | `suportefrila@gmail.com` | Sim (`enderecos.emailSuporte`) | Sim |

---

## 5. Matriz de Coerência (Ficha x Manifesto x Política x Código)

| Dado / Recurso | App Privacy (Loja) | Manifesto (`PrivacyInfo.xcprivacy`) | Política de Privacidade (`/privacidade`) | Código-Fonte (`iOS/Sources`) |
|---|:---:|:---:|:---:|:---:|
| Nome e E-mail | Sim (Vinculado) | Sim (`NSPrivacyCollectedDataTypeName`, `EmailAddress`) | Sim (Seção 2.1) | `CadastroViewModel.swift` |
| Telefone | Sim (Vinculado) | Sim (`NSPrivacyCollectedDataTypePhoneNumber`) | Sim (Seção 2.1) | `ContatoDTO.swift` |
| Endereço Físico | Sim (Vinculado) | Sim (`NSPrivacyCollectedDataTypePhysicalAddress`) | Sim (Seção 2.2) | `CadastroEstabelecimento.swift` |
| Localização Precisa | Sim (Vinculado) | Sim (`NSPrivacyCollectedDataTypePreciseLocation`) | Sim (Seção 2.3) | `PresencaDoTurnoViewModel.swift` |
| Identificadores (UUID, FCM) | Sim (Vinculado) | Sim (`NSPrivacyCollectedDataTypeUserID`, `DeviceID`) | Sim (Seção 2.4) | `SessaoNoKeychain.swift`, `AparelhoDePush.swift` |
| Conteúdo do Usuário | Sim (Vinculado) | Sim (`NSPrivacyCollectedDataTypeOtherUserContent`) | Sim (Seção 2.5) | `PublicarVaga.swift`, `TelaAvaliacao.swift` |
| Relatórios de Falha | Sim (Não Vinculado) | Sim (`NSPrivacyCollectedDataTypeCrashData`) | Sim (Seção 2.6) | Firebase Crashlytics |
| Telemetria Agregada | Sim (Não Vinculado) | Sim (`NSPrivacyCollectedDataTypeOtherDiagnosticData`) | Sim (Seção 2.6) | `Telemetria.swift` |
| Rastreamento de Terceiros | **Não** | **Não (`NSPrivacyTracking = false`)** | **Não** (Sem rastreadores) | Nenhum SDK de ads |
| Exclusão In-App de Conta | Declarado | Conformidade com Diretriz 5.1.1 | Seção 5 (Direitos do Titular) | `TelaExclusaoDeConta.swift` |
