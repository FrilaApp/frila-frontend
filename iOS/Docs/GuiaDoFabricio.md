# Guia de Implementação do Design System no iOS — Frila

Documento oficial de referência técnica, arquitetura e passo a passo operacional para o Fabrício (e sua IA assistente) implementar o design system do Frila diretamente no aplicativo iOS (`frila-frontend`).

- **Versão:** 1.0
- **Data:** 2026-10-19
- **Autor institucional:** Steve Rogers (Capitão América do Frila)
- **Revisão e aprovação:** Nick Fury
- **Repositório de trabalho:** `FrilaApp/frila-frontend` (`iOS/`)
- **Branch base:** `origin/main`

---

# Parte A: README de Referência

---

## 1. Para quem é e como usar (humano e IA)

Este documento foi elaborado para ser lido e executado de forma autônoma tanto por **desenvolvedor humano (Fabrício)** quanto por **agente de IA**. Ele contém todas as definições arquiteturais, restrições técnicas, convenções de código e passos de verificação necessários para que a implementação do design ocorra sem necessidade de reuniões de alinhamento ou pedidos de esclarecimento externos.

### 1.1 O que você PODE mexer
- **Exclusivamente na camada de Apresentação:** `iOS/Sources/Apresentacao/` (views SwiftUI, componentes, modificadores, estilos de botões, view models `@Observable` de apresentação e tokens em `DesignTokens.swift`).
- **Recursos visuais e catálogo de strings:** `iOS/Resources/DesignSystem.xcassets` (cores dos temas claro e escuro), `iOS/Resources/Fonts/` (fontes autorizadas) e `iOS/Resources/Localizable.xcstrings` (textos localizados em português do Brasil).
- **Testes de apresentação e catálogo:** Adicionar ou atualizar previews no `CatalogoDesignSystem.swift` e ajustar testes unitários visuais em `Tests/Unitarios/GuardaTokensDesignTests.swift` (apenas caso novos tokens semânticos sejam formalizados).

### 1.2 O que você NÃO PODE mexer
- **Domínio (`iOS/Sources/Dominio/`):** Entidades puras (`Modelos.swift`), objetos de valor (`ObjetosDeValor.swift`), portas e protocolos (`Portas.swift`, `ApiCliente.swift`, `LeitorDeLocalizacao.swift`). Regras de negócio e modelos de domínio não mudam por decisões cosméticas.
- **Dados (`iOS/Sources/Dados/`):** Implementação de cliente Supabase, dublês de teste (`ApiClienteEmMemoria.swift`), fixtures do contrato, banco de dados local SwiftData (`CacheSwiftData.swift`) e fila offline (`SincronizadorAcoes.swift`). *(Atenção: o PR 417 do João Paulo está ativo nesta pasta; qualquer edição gerará conflito de merge).*
- **Infraestrutura (`iOS/Sources/Infraestrutura/`):** Implementações de GPS CoreLocation, Firebase Crashlytics e mensageria push FCM.
- **Ciclo de vida do App (`iOS/Sources/App/FrilaApp.swift`):** Composição de dependências na raiz da aplicação. *(Também protegido pelo PR 417).*
- **Contrato da API (`iOS/Contrato/`):** O arquivo `openapi.yaml` e sua soma `openapi.yaml.sha256` são réplicas estritas do repositório `frila-docs`. Nunca altere o contrato ou as fixtures manualmente.
- **Configuração de build e CI:** `iOS/project.yml`, `iOS/Configurations/*.xcconfig` e `.github/workflows/ios.yml`.

---

## 2. Mapa de repositórios da organização FrilaApp

A organização `FrilaApp` é composta por repositórios modulares com responsabilidades estritamente delimitadas.

| Repositório | Ação | Finalidade técnica | Razão da diretriz |
|---|:---:|---|---|
| `FrilaApp/frila-frontend` | **CLONAR** | Código nativo do app iOS (`iOS/`), Android e Web. | **Seu local de trabalho.** Todo o trabalho visual é realizado dentro do diretório `iOS/`. |
| `FrilaApp/frila-docs` | **CLONAR (só leitura)** | Especificação de requisitos, casos de uso, arquitetura e contrato canônico `frila-docs/api/openapi.yaml`. | Referência normativa para regras de negócio (RN), requisitos funcionais (RF) e escopo de MVP (`frila-docs/produto/05-ESCOPO-DO-MVP.md`). |
| `FrilaApp/frila-backend` | **NÃO CLONAR** | Banco Postgres, migrações Supabase, RPCs e Edge Functions. | **Desnecessário.** Conforme decisão arquitetural de 07/10/2026 (`iOS/Docs/Environments.md:37-43`), desenvolvedores do app utilizam o cliente em memória (`ApiClienteEmMemoria`) localmente e conectam-se ao servidor hospedado `frila-dev`, dispensando Docker e setup local de banco. |
| `FrilaApp/Bancada` | **NÃO CLONAR** | Ferramental de engenharia interna de agentes e harnesses. | Não possui código de produto nem documentação consumível pela UI. |

### 2.1 Pré-requisitos da máquina de desenvolvimento
- **Sistema Operacional:** macOS 14 Sonoma ou macOS 15 Sequoia (a CI utiliza runners `macos-26`).
- **Xcode:** Xcode 16.0 ou superior (a CI utiliza Xcode 26.6 / Build 17F113).
- **XcodeGen:** Versão 2.45.3 instalada via Homebrew (`brew install xcodegen`). *(Obrigatório: o repositório não versiona arquivos `.xcodeproj` para evitar conflitos de merge).*
- **Simulador:** iPhone com iOS 17.0 ou superior disponível no sistema.

### 2.2 Comandos de preparação do workspace
```sh
# 1. Clone do repositório do frontend
git clone https://github.com/FrilaApp/frila-frontend.git
cd frila-frontend

# 2. Garanta base na main remota atualizada e crie sua branch de trabalho
git fetch origin
git switch -c feat/design-fabricio origin/main

# 3. Opcional: Clone do frila-docs em pasta paralela para consulta de requisitos
cd ..
git clone https://github.com/FrilaApp/frila-docs.git
cd frila-frontend/iOS
```

---

## 3. Mapa da pasta `iOS/` e pontos de encaixe

A arquitetura do Frila iOS segue a separação estrita em camadas concêntricas apontando para o Domínio (`Architecture.md:5-9`):

```text
Frila (App) -> FrilaApresentacao -> FrilaDominio
Frila (App) -> FrilaDados ---------> FrilaDominio
Frila (App) -> FrilaInfraestrutura -> FrilaDominio
```

### 3.1 Camadas do projeto (`iOS/Sources/`)
- `iOS/Sources/Dominio/`: Tipos fundamentais e regras centrais do negócio.
  - `Modelos.swift`: Modelos de dados imutáveis (`Vaga`, `Turno`, `Candidato`, `PerfilProfissional`, `Estabelecimento`).
  - `ObjetosDeValor.swift`: Objetos de valor tipados (`Identificador`, `CPF`, `CNPJ`, `Coordenada`, `Telefone`).
  - `Portas.swift`: Interfaces abstratas (`ApiCliente`, `LeitorDeLocalizacao`, `CacheLocal`).
- `iOS/Sources/Dados/`: Implementações de acesso a dados e rede.
  - `SupabaseApiCliente.swift`: Comunicação HTTP/RPC com o backend.
  - `ApiClienteEmMemoria.swift`: Dublê estático para desenvolvimento ágil e testes sem internet.
  - `CacheSwiftData.swift`: Persistência local criptografada para suporte offline.
- `iOS/Sources/Infraestrutura/`: Serviços de plataforma iOS.
  - `LeitorDeLocalizacaoDoSistema.swift`: GPS pontual nativo (CoreLocation).
  - `AparelhoDePush.swift`: Integração com Firebase Cloud Messaging (FCM).
- `iOS/Sources/App/`: Ponto de entrada do executável.
  - `FrilaApp.swift`: `@main` SwiftUI, injeção de dependências e cortina de privacidade.
  - `ConfiguracaoAmbiente.swift`: Leitura dos esquemas de build (`Frila-Local`, `Frila-Dev`, `Frila-Prod`).
- `iOS/Sources/Apresentacao/`: **ONDE SEU DESIGN ENTRA.**
  - `DesignTokens.swift`: Definição centralizada de todas as cores (`FrilaCor`), espaçamentos (`FrilaEspaco`), raios (`FrilaRaio`), métricas (`FrilaMetrica`), tipografia (`FrilaTipo`), movimento tátil (`FrilaMovimento`), elevação e sombras (`FrilaElevacao`) e formatação monetária acessível (`FrilaMoney`).
  - `Componentes.swift`: Biblioteca canônica de componentes atômicos (`BotaoPrimario`, `BotaoSecundario`, `CampoFrila`, `CampoCodigo`, `FiltroPill`, `SeloReputacao`, `AvisoFrila`, `CartaoVaga`, `RespostaSimNao`, `FolhaFrila`).
  - `EstadosDeTela.swift`: Componentes de estado de visualização (`EstadoCarregando`, `EstadoVazio`, `EstadoErro`, `EstadoSemRede`).
  - `CatalogoDesignSystem.swift`: Catálogo interativo navegável e testável com previews no Xcode.
  - `iOS/Sources/Apresentacao/DesignSystem/ComponentesRestantes/`: Novos componentes trazidos do FrilaLowPhase (`EditorialTag.swift`, `SearchCapsule.swift`, `ProposalBar.swift`).

### 3.2 Estrutura de Telas e Fluxos (`iOS/Sources/Apresentacao/Fluxos/`)

| Subpasta em `iOS/Sources/Apresentacao/Fluxos/` | Telas Principais | ViewModel de Referência | O que já está pronto (Pontos de Encaixe) |
|---|---|---|---|
| `iOS/Sources/Apresentacao/Fluxos/Autenticacao/` | `TelaEntrada.swift`, `TelaCodigo.swift`, `TelaCadastro.swift` | `EntradaViewModel.swift`, `CodigoViewModel.swift`, `CadastroViewModel.swift` | Entrada sem senha via e-mail OTP, digitação de 6 dígitos em caixas com foco automático, cadastro com seleção de papel (Profissional ou Contratante) fixo. |
| `iOS/Sources/Apresentacao/Fluxos/Profissional/` | `TelaVagas.swift`, `TelaDetalheVaga.swift`, `TelaMeuTurno.swift`, `TelaMeusTurnos.swift`, `TelaAvaliacao.swift`, `TelaPerfilProfissional.swift`, `CandidaturaEmSelecao.swift` | `FeedVagasViewModel.swift`, `DetalheVagaViewModel.swift`, `MeuTurnoViewModel.swift`, `MeusTurnosViewModel.swift`, `AvaliacaoTurnoViewModel.swift` | Feed com filtro de data, função e distância; detalhe com candidatura de toque único; tela do turno com check-in geolocalizado e botão "Estou a caminho"; avaliação binária ("Trabalharia lá de novo?"). |
| `iOS/Sources/Apresentacao/Fluxos/Contratante/` | `MinhasVagas.swift`, `PublicarVaga.swift`, `PublicarVagaDaCasa.swift`, `RepublicarVaga.swift`, `TelaTurnoDoContratante.swift`, `CandidatosDaVaga.swift`, `CadastroEstabelecimento.swift` | `AcompanhamentoViewModel.swift`, `CandidatosDaVagaViewModel.swift` | Gestão de vagas publicadas, formulário de publicação rápida (Urgência ou Seleção), acompanhamento de presença em tempo real, confirmação de check-in manual e avaliação do profissional. |
| `iOS/Sources/Apresentacao/Fluxos/Perfil/` | `TelaPorQueReceboVagas.swift`, `TelaHistoricoDeTurnos.swift`, `PerfisDaConta.swift` | `PorQueReceboVagasViewModel.swift`, `HistoricoDeTurnosViewModel.swift`, `ExportarDadosViewModel.swift` | Explicação transparente dos critérios de despacho com botão de contestação, histórico com filtro de períodos e exportação nativa de PDF/CSV. |
| `iOS/Sources/Apresentacao/Fluxos/Equipe/` | `TelaEquipeDeConfianca.swift` | `EquipeDeConfiancaViewModel.swift` | Listagem e gerenciamento de profissionais favoritos vinculados ao estabelecimento. |
| `iOS/Sources/Apresentacao/Fluxos/Confianca/` | `AcoesDeSeguranca.swift` | `SegurancaViewModel.swift` | Ações de denúncia com motivo obrigatório e bloqueio mútuo imediato. |
| `iOS/Sources/Apresentacao/Fluxos/Conta/` | `TelaContaSuspensa.swift`, `TelaExclusaoDeConta.swift` | `ContaSuspensaViewModel.swift`, `ExclusaoDeContaViewModel.swift` | Notificação formal de suspensão com formulário de contestação; fluxo de autoexclusão de conta conforme diretriz App Store 5.1.1(v). |
| `iOS/Sources/Apresentacao/Fluxos/Cancelamento/` | `FolhaDeCancelamento.swift` | `CancelamentoViewModel.swift` | Cancelamento com motivos predefinidos ou campo livre, com alerta de falta grave para menos de 24 horas. |
| `iOS/Sources/Apresentacao/Fluxos/Suporte/` | `FolhaSuporteTurno.swift` | `SuporteTurnoViewModel.swift` | Abertura de e-mail com identificadores do turno pré-preenchidos para suporte da Equipe Frila. |
| `iOS/Sources/Apresentacao/Fluxos/Push/` | `TelasDaPermissaoDePush.swift` | `PermissaoDePushModelo.swift` | Tela educativa prévia contextualizando o valor das notificações antes do diálogo nativo do sistema. |

---

## 4. Regras de arquitetura e implementação do projeto

Toda contribuição de interface é auditada por testes automatizados estritos e scripts de análise estática.

### 4.1 O que VALE (Padrões Obrigatórios)
1. **SwiftUI Moderno e Declarativo:** Alvo mínimo iOS 17.0. Utilizar modificadores nativos do SwiftUI, `@Environment` e ViewModels baseados em `@Observable` isolados no `@MainActor`.
2. **Tokens Centralizados:** Toda cor deve vir de `FrilaCor`, todo espaçamento de `FrilaEspaco`, todo raio de borda de `FrilaRaio` e toda tipografia de `FrilaTipo`.
3. **Dynamic Type Integral:** A interface deve escalar perfeitamente até o tamanho máximo de acessibilidade (`UICTContentSizeCategoryAccessibilityXXXL` / AX5). Em tamanhos ampliados, botões e pilhas horizontais devem converter-se em layouts verticais com quebra de linha fluida.
4. **Área de Toque Mínima (Apple HIG):** Todo elemento interativo (botões, chips, pílulas, ícones clicáveis) deve garantir área de toque de pelo menos **44 × 44 pt** (`FrilaMetrica.alvoMinimo`), mesmo quando seu tamanho visual for menor (usar `.frame(minHeight: FrilaMetrica.alvoMinimo).contentShape(Rectangle())`).
5. **Acessibilidade para VoiceOver:**
   - Todo ícone decorativo deve receber `.accessibilityHidden(true)`.
   - Elementos compostos (como cartões de vagas ou linhas de turno) devem ser agrupados com `.accessibilityElement(children: .combine)`.
   - Valores monetários devem ser formatados via `FrilaMoney.spoken(cents:por:)` no `.accessibilityLabel` para evitar pronúncias truncadas do leitor de tela (`DesignTokens.swift:227-291`).
6. **Reduzir Movimento:** Animações e molas táteis devem sempre consultar a preferência do usuário via `FrilaMovimento.animacao(..., reduzir: reduceMotion)` (`DesignTokens.swift:125-138`).
7. **Padrões de Estado:** Toda lista e fluxo deve contemplar explicitamente os cinco estados padronizados em `PadroesDeEstado.md`: Carregando (`EstadoCarregando`), Vazio (`EstadoVazio`), Erro com botão de retentativa (`EstadoErro`), Sem conexão (`EstadoSemRede`) e Sucesso.
8. **Guia de Voz e Localização (`GuiaDeVoz.md`):**
   - Idioma oficial: Português do Brasil com acentuação rigorosa (`pt-BR`).
   - Tom: Direto, sem rodeios, sem culpa ao usuário em erros e sem promessas não programáticas.
   - Glossário oficial estrito: **Vaga** (nunca oportunidade, bico ou trampo); **Turno** (nunca diária ou plantão); **Posição** (unidade preenchível de uma vaga); **Estabelecimento** (o negócio); **Contratante** (o papel de quem publica); **Profissional** (quem cumpre o turno, nunca freelancer ou colaborador); **Candidatar-se** (ação na vaga); **Check-in** e **Check-out** (presença); **Taxa de comparecimento**; **Reputação binária** ("Chamaria de novo? X de Y").
   - **Termo PROIBIDO:** A palavra **"comissão"** é terminantemente proibida na interface. O Frila não cobra taxa de comissão sobre o valor do turno (RN01).

### 4.2 O que é TERMINANTEMENTE PROIBIDO
- ❌ **Cores literais ou customizadas soltas:** Proibido usar `.red`, `.blue`, `.orange`, `.gray`, `.green` ou inicializadores `Color(red:...)`, `Color(white:...)`, `Color(uiColor:...)`, `Color("...")` fora de `DesignTokens.swift`. *(A guarda `GuardaTokensDesignTests.swift` quebra o build).*
- ❌ **Fontes fixas ou customizadas soltas:** Proibido usar `.font(.system(size:...))`, `Font.system(size:...)` ou `Font.custom(...)` fora de `DesignTokens.swift`.
- ❌ **Itálico (`.italic()`):** Terminantemente proibido na interface. Toda tipografia editorial deve ser vertical/ereta (upright).
- ❌ **Strings mágicas soltas na View:** Proibido usar `Text(verbatim: "texto em português")` ou textos não registrados no catálogo `Resources/Localizable.xcstrings`. *(O script `conferir-textos.sh` reprova a CI).*
- ❌ **Edição de arquivos fora da Apresentação:** Proibido modificar arquivos em `iOS/Sources/Dominio/`, `iOS/Sources/Dados/`, `iOS/Sources/Infraestrutura/`, `iOS/Sources/App/` ou `iOS/Contrato/`.
- ❌ **Versionamento do projeto Xcode:** Proibido commitar `Frila.xcodeproj/`, pastas de `build/DerivedData/` ou arquivos `.xcresult`.

---

## 5. Tradução do Design (FrilaLowPhase) para o App Real

O repositório `Frila/FrilaLowPhase` representa a exploração visual criada pelo Fabrício. Abaixo está a correspondência exata entre o protótipo e o código do aplicativo real.

### 5.1 Tabela de Correspondência de Tokens

| Token / Conceito no FrilaLowPhase | Equivalente no App Real (`frila-frontend`) | Implementação Técnica no Código | Fonte / Decisão |
|---|---|---|---|
| Brand Anchor (`#EA5A36`, OKLCH) | `FrilaCor.marca` | `Color("BrandAccent", bundle: recursos)` | `DesignTokens.swift:33`; Acento pontual, nunca fundo de tela. |
| Primary Action / CTA Dark Pill | `FrilaCor.primaria` | `Color("BrandPrimary", bundle: recursos)` | `DesignTokens.swift:16`; Escuro no modo claro, claro no modo escuro. |
| On-Primary Contrast Text | `FrilaCor.sobrePrimaria` | `Color("BrandOnPrimary", bundle: recursos)` | `DesignTokens.swift:17`; Branco puro ou quase preto. |
| Gallery Canvas Background | `FrilaCor.fundo` | `Color("Surface", bundle: recursos)` | `DesignTokens.swift:19`; Fundo agrupado cinza claro / cinza escuro. |
| Grouped Card Surface | `FrilaCor.superficie` | `Color("SurfaceElevated", bundle: recursos)` | `DesignTokens.swift:23`; Superfície branca / cinza escuro elevado. |
| Hairline Divider (1 pt) | `FrilaCor.divisoria` | `Color("Hairline", bundle: recursos)` | `DesignTokens.swift:37`; Linha divisória de 1 pt. |
| Control Border | `FrilaCor.borda` | `Color("ControlBorder", bundle: recursos)` | `DesignTokens.swift:39`; Borda sutil de chips inativos e inputs. |
| Corner Radius Scale (8, 12, 16, 20, 28) | `FrilaRaio` | `.pequeno` (8), `.medio` (12), `.aviso` (16), `.grande` (20), `.folha` (28) | `DesignTokens.swift:58-67`; Raios contínuos nativos. |
| Spacing Scale (2, 4, 8, 12, 14, 16, 24, 32) | `FrilaEspaco` | `.fio` (2), `.minimo` (4), `.pequeno` (8), `.compacto` (12), `.faixa` (14), `.medio` (16), `.grande` (24), `.enorme` (32) | `DesignTokens.swift:44-56`; Grade espacial consistente. |
| Spring Touch Feedback (350/25) | `FrilaMovimento.molaTatil` | `.interpolatingSpring(stiffness: 350, damping: 25)` | `DesignTokens.swift:131`; Mola canônica para botões. |
| Spring Touch Feedback (380/24) | `FrilaMovimento.molaTatilChip` | `.interpolatingSpring(stiffness: 380, damping: 24)` | `DesignTokens.swift:133`; Mola ultrarrápida para chips. |
| Beautiful Shadows (3 camadas) | `FrilaElevacao` | `.nenhuma` (cartões zero-shadow), `.sutil`, `.folha` | `DesignTokens.swift:157-200`; Coordenadas de rim, key e ambient. |
| Bricolage Grotesque Display | `FrilaTipo.pergunta`, `.respostaEscolhida` | Bricolage registrada via CoreText no bundle | `DesignTokens.swift:98-111`; Exclusiva para fluxo de publicar vaga. |

### 5.2 Tabela de Correspondência de Componentes

| Componente no FrilaLowPhase | Componente no App Real (`frila-frontend`) | Arquivo no Código Real | Status / Observações |
|---|---|---|---|
| `PrimaryPillButton` / `FrilaCTA` | `BotaoPrimario` | `iOS/Sources/Apresentacao/Componentes.swift:77` | Pronto. Suporta estado de carregamento nativo (`carregando: true`). |
| `OutlinedButton` / Secondary CTA | `BotaoSecundario` | `iOS/Sources/Apresentacao/Componentes.swift:116` | Pronto. Contorno em `FrilaCor.borda` e texto em `FrilaCor.texto`. |
| `FrilaShiftCard` / `OpportunityCard` | `CartaoVaga` & `.cartaoFrila()` | `iOS/Sources/Apresentacao/Componentes.swift:413` | Pronto. Adota padrão canônico: superfície elevada, raio 20, fio de 1 pt, zero sombra. |
| `FrilaFilterChip` | `FiltroPill` | `iOS/Sources/Apresentacao/Componentes.swift:258` | Pronto. Suporta estados ativo/inativo, feedback tátil e alvo mínimo 44 pt. |
| `FrilaSplitFieldLayout` | `CampoFrila` | `iOS/Sources/Apresentacao/Componentes.swift:162` | Pronto. Campo acessível com rótulo, foco automático e tratamento de erro inline. |
| `SearchDiscoverySheet` | `FolhaFrila` | `iOS/Sources/Apresentacao/Componentes.swift:587` | Pronto. Modal nativo com puxador e layout adaptável a Dynamic Type. |
| `FrilaEditorialTag` | `EditorialTag` | `iOS/Sources/Apresentacao/DesignSystem/ComponentesRestantes/EditorialTag.swift:10` | Pronto. Geometria Capsule para protocolos e selos técnicos. |
| `FrilaSearchCapsule` | `SearchCapsule` | `iOS/Sources/Apresentacao/DesignSystem/ComponentesRestantes/SearchCapsule.swift:59` | Em adaptação. Barra de pesquisa por cápsula com suporte a filtros rápidos. |
| `FrilaProposalBar` | `ProposalBar` | `iOS/Sources/Apresentacao/DesignSystem/ComponentesRestantes/ProposalBar.swift:8` | Em adaptação. Ver decisão pendente DP-01 abaixo. |

### 5.3 Matriz de Decisões Pendentes (Conflitos entre Design e Produto)

Onde o protótipo do Fabrício divergiu de regras de negócio, acessibilidade ou escopo da v1.0, o comportamento foi catalogado como **Decisão Pendente** para ser tratado formalmente, sem alterações unilaterais.

| ID | Tema do Conflito | O que o FrilaLowPhase propõe | O que o App Real / Regras exigem | Decisão / Encaminhamento Técnico |
|---|---|---|---|---|
| **DP-01** | Taxa de Serviço e Comissão | `FrilaProposalBar` exibe "Taxa de Serviço da Plataforma (5%)" e "Repasse Líquido". | **RN01 & Guia de Voz:** O Frila NÃO cobra comissão do profissional, NÃO atua como intermediador financeiro e a palavra "comissão" é proibida na UI. | **Decisão Pendente:** Remover o disclosure de taxas da barra. O valor exibido na vaga é 100% integral e repassado diretamente pelo contratante ao profissional. |
| **DP-02** | Shaders de Liquid Glass | Efeitos complexos de refração e especularidade baseados em Metal shaders para iOS 26+. | O projeto real possui **Deployment Target iOS 17.0** (`project.yml:5`). Shaders exclusivos do iOS 26 causam quebra ou falha silenciosa no iOS 17 e 18. | **Decisão Pendente:** Usar materiais nativos do SwiftUI (`.regularMaterial`, `.thinMaterial`) como fallback seguro para iOS 17+. |
| **DP-03** | Múltiplos Paradigmas Tipográficos | Uso de New York (serifa editorial), SF Mono (arquival) e SF Pro em 4 ou 5 paradigmas alternados. | Decisão do time de 14/10/2026 (`memory/design-provisorio.md:15`): **Tema Neutro**. 100% da interface, números e dinheiro em SF Pro; Bricolage Grotesque exclusivamente no formulário de publicar vaga. Proibido itálico. | **Decisão Pendente:** Padronizar todas as telas em SF Pro nativo com Dynamic Type, mantendo Bricolage Grotesque apenas nas perguntas de publicação. |
| **DP-04** | Vocabulário e Termos em Inglês | Termos como *gig*, *shift*, *marketplace*, *escrow*, *creator profile*, *budget*, *seniority*. | `GuiaDeVoz.md:23-30`: Proibição estrita de estrangeirismos desnecessários. Vocabulário oficial em pt-BR (*vaga*, *turno*, *posição*, *estabelecimento*). | **Decisão Pendente:** Adequar todos os componentes para o vocabulário oficial em português do Brasil aprovado no Guia de Voz. |
| **DP-05** | Escopo de Telas além do MVP | Telas de portfólio de criadores (`CreatorProfileHero`), testes de estúdio (`StudioExperiment`) e histograma de orçamento. | `05-ESCOPO-DO-MVP.md:30-55`: A v1.0 cobre exclusivamente o ciclo de turnos avulsos presenciais em bares, restaurantes e eventos no DF. | **Decisão Pendente:** Telas de criadores e estúdios ficam fora do binário da v1.0 (não implementar nos fluxos de produção). |
| **DP-06** | Custódia Financeira (Escrow) | Selo e badges de "Escrow Verified" sugerindo retenção de fundos pelo app. | O Frila v1.0 não processa pagamentos nem retém valores financeiros em custódia (RN09). | **Decisão Pendente:** Substituir qualquer alusão a custódia/escrow por confirmação de presença e reputação verificada pós-turno. |

---

## 6. Como rodar, compilar e testar

O projeto adota uma esteira de validação rigorosa antes de qualquer pull request.

### 6.1 Geração do Projeto Xcode
Toda vez que clonar, atualizar a branch ou puxar novos commits, regenere o projeto:
```sh
cd iOS
./Scripts/gerar-projeto.sh
```
*O que o script faz:* Executa o XcodeGen a partir de `project.yml`, gera `Frila.xcodeproj` e restaura o `Package.resolved` com as dependências fixadas (Supabase 2.55.2 e Firebase 12.19.2).

### 6.2 Executando no Simulador
1. Abra `Frila.xcodeproj` no Xcode.
2. Selecione o esquema **`Frila-Local`**.
3. Escolha um simulador de iPhone (ex: iPhone 16 com iOS 17+).
4. Pressione `Cmd + R`.
*Nota:* O esquema `Frila-Local` utiliza o dublê em memória (`ApiClienteEmMemoria`). Ele não requer internet, chaves secretas nem backend rodando.

### 6.3 Suíte de Testes e Portões Estáticos
Antes de entregar, execute a suíte completa de testes e conferências:
```sh
cd iOS

# 1. Conferência estática de catálogo de textos e ausência de fontes/cores literais
./Scripts/conferir-textos.sh

# 2. Conferência de ausência de datas fixas nos testes
./Scripts/conferir-datas-fixas.sh

# 3. Validação das fixtures de teste contra o contrato OpenAPI
python3 ./Scripts/validate-fixtures.py

# 4. Execução dos testes unitários e de integração visual no simulador
xcodebuild test \
  -project Frila.xcodeproj \
  -scheme Frila-Local \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath build/DerivedData
```

### 6.4 Cobertura de Testes e Requisitos da CI
- **Metas de Cobertura (`Docs/Cobertura.md`):** As linhas executáveis da camada de Apresentação (especialmente ViewModels) devem manter cobertura superior a **90%** (a média atual é de 96,5%).
- **Funcionamento da CI (`Docs/CI.md`):** O workflow do GitHub Actions executa dois jobs em paralelo (`parte-1` e `parte-2`) em runners macOS. A Parte 1 valida integridade de contrato, catálogo de textos, testes unitários e metade da UI; a Parte 2 valida o restante da UI e os builds de Release. PRs que quebram testes ou violam o catálogo de textos são reprovados automaticamente.

---

## 7. Fluxo de entrega e governança

O fluxo de código na org `FrilaApp` é protegido para garantir a estabilidade do produto que irá para a App Store.

1. **Branch de Trabalho:** Toda branch deve partir de `origin/main` atualizada:
   `git fetch origin && git switch -c feat/design-<sua-feature> origin/main`
2. **Commits Atômicos:** Mensagens de commit em português do Brasil, claras e descrevendo o que mudou e por quê.
3. **Pull Request:** O trabalho deve ser submetido exclusivamente via Pull Request apontando para a branch `main` de `FrilaApp/frila-frontend`.
4. **Quem Revisa:** O **Nick Fury** audita o código e faz o merge final. O **Loki** realiza a verificação de QA e acessibilidade no simulador. Nunca faça merge do seu próprio PR.
5. **Segredos e Credenciais:** Nunca inclua chaves, tokens, e-mails reais ou senhas no código ou em documentos. O arquivo `Configurations/Secrets.xcconfig` é ignorado pelo Git e nunca deve ser versionado.

---

# Parte B: Passo a Passo Numerado de Implementação

Siga a sequência abaixo para implementar as alterações visuais de ponta a ponta com segurança.

---

### Passo 1: Preparar o ambiente e clonar o repositório
- **Ação:** Instale o XcodeGen e clone o repositório do frontend.
  ```sh
  brew install xcodegen
  git clone https://github.com/FrilaApp/frila-frontend.git
  cd frila-frontend
  ```
- **Resultado Esperado:** Repositório clonado com a pasta `iOS/` contendo `project.yml`.
- **Como conferir:** Execute `xcodegen --version` (deve retornar 2.45.3 ou compatível) e `ls iOS/project.yml`.

### Passo 2: Criar a branch de trabalho a partir da `main` remota
- **Ação:** Obtenha os commits mais recentes e abra sua branch de feature.
  ```sh
  git fetch origin
  git switch -c feat/design-fabricio origin/main
  ```
- **Resultado Esperado:** Branch criada com sucesso rastreando a ponta de `origin/main`.
- **Como conferir:** Execute `git status` e confira a linha `On branch feat/design-fabricio`.

### Passo 3: Gerar o projeto Xcode e compilar
- **Ação:** Execute o script de geração e abra o Xcode.
  ```sh
  cd iOS
  ./Scripts/gerar-projeto.sh
  open Frila.xcodeproj
  ```
- **Resultado Esperado:** O arquivo `Frila.xcodeproj` é gerado e o pacote `Package.resolved` é restaurado na workspace.
- **Como conferir:** No terminal, confira a mensagem `Package.resolved restaurado em...`. No Xcode, selecione o esquema `Frila-Local` e aperte `Cmd + B` (o build deve suceder sem erros).

### Passo 4: Explorar o Catálogo de Design System
- **Ação:** Execute o app no simulador com o catálogo ativado.
  ```sh
  xcodebuild build -project Frila.xcodeproj -scheme Frila-Local -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath build
  xcrun simctl install booted build/Build/Products/Debug-Local-iphonesimulator/Frila.app
  xcrun simctl launch booted com.frila.org.app -FRILA_ABRIR_CATALOGO
  ```
- **Resultado Esperado:** O simulador abre diretamente na tela `CatalogoDesignSystem`, exibindo botões, campos, chips, cartões e paletas de cores.
- **Como conferir:** Interaja com os componentes na tela do simulador para observar os estados visuais vigentes.

### Passo 5: Atualizar paleta de cores e tokens em `DesignTokens.swift`
- **Ação:** Edite `iOS/Resources/DesignSystem.xcassets` (para ajustes finos de RGB/Hex claro/escuro) e ajuste `iOS/Sources/Apresentacao/DesignTokens.swift` para refletir os tokens semânticos necessários.
- **Resultado Esperado:** Cores e métricas atualizadas sem quebrar tipos já existentes.
- **Como conferir:** Execute `./Scripts/conferir-textos.sh` para validar que nenhum token inválido foi introduzido.

### Passo 6: Ajustar componentes básicos em `Componentes.swift`
- **Ação:** Refine o layout, paddings e feedback tátil dos blocos fundamentais em `iOS/Sources/Apresentacao/Componentes.swift` (`BotaoPrimario`, `BotaoSecundario`, `CampoFrila`, `FiltroPill`, `CartaoVaga`).
- **Resultado Esperado:** Componentes aderentes ao estilo Gallery/Artsy (raio contínuo de 20 pt nos cartões, borda de 1 pt em `FrilaCor.divisoria`, sem sombras pesadas).
- **Como conferir:** Abra o arquivo `CatalogoDesignSystem.swift` no Canvas do Xcode (`Option + Cmd + Return`) e confira o preview interativo em modo claro e escuro.

### Passo 7: Incorporar componentes restantes do FrilaLowPhase
- **Ação:** Revise os arquivos em `iOS/Sources/Apresentacao/DesignSystem/ComponentesRestantes/` (`EditorialTag.swift`, `SearchCapsule.swift`, `ProposalBar.swift`). Adequar textos e comportamento às regras do Guia de Voz e às decisões pendentes (DP-01 e DP-04).
- **Resultado Esperado:** Componentes integrados e consumíveis pelas telas principais.
- **Como conferir:** Execute os testes unitários da camada de apresentação:
  ```sh
  xcodebuild test -project Frila.xcodeproj -scheme Frila-Local -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:FrilaTests/GuardaTokensDesignTests
  ```

### Passo 8: Aplicar o design tela por tela (Ordem recomendada)
Aplique os novos componentes e estilos tela a tela, respeitando os ViewModels existentes:
1. **Feed de Vagas:** `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaVagas.swift` (cabeçalho, barra de busca/cápsula, filtros de função/data e cartões de vaga agrupados).
2. **Detalhe da Vaga:** `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaDetalheVaga.swift` (tipografia editorial, aviso de privacidade da RN10 e botão fixo "Candidatar-me").
3. **Publicação de Vaga:** `iOS/Sources/Apresentacao/Fluxos/Contratante/PublicarVaga.swift` (perguntas de formulário em Bricolage Grotesque, seletor de urgência/seleção, botões táteis).
4. **Minhas Vagas do Contratante:** `iOS/Sources/Apresentacao/Fluxos/Contratante/MinhasVagas.swift` e `CandidatosDaVaga.swift` (acompanhamento de candidatos com selo de reputação e equipe de confiança).
5. **Turno Ativo e Presença:** `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeuTurno.swift`, `SecaoDePresenca.swift` e `TelaTurnoDoContratante.swift` (botões de check-in, badges de presença verificada e canal de WhatsApp pós-confirmação).
6. **Avaliação:** `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaAvaliacao.swift` (pergunta binária limpa com botões Sim e Não).
7. **Autenticação:** `iOS/Sources/Apresentacao/Fluxos/Autenticacao/TelaEntrada.swift`, `TelaCodigo.swift` e `TelaCadastro.swift` (campos de foco automático e seleção de perfil).
8. **Perfis e Apoio:** `TelaPerfilProfissional.swift`, `TelaHistoricoDeTurnos.swift` e `TelaPorQueReceboVagas.swift`.
- **Resultado Esperado:** Telas atualizadas consumindo exclusivamente `FrilaCor`, `FrilaTipo` e componentes padronizados.
- **Como conferir:** Navegue por cada fluxo completo no simulador executando o esquema `Frila-Local`.

### Passo 9: Validação visual de acessibilidade e Dynamic Type
- **Ação:** Teste as telas no simulador no tamanho padrão e no maior tamanho de texto acessível (AX5 / Accessibility XXXL).
  ```sh
  # Ativar tamanho máximo de acessibilidade no simulador:
  xcrun simctl ui booted content-size-category accessibility-extra-extra-extra-large
  ```
- **Resultado Esperado:** Nenhum texto truncado ou sobreposto; botões horizontais reorganizados em pilhas verticais; campos de texto expandindo confortavelmente; áreas de toque com mínimo de 44 pt mantidas.
- **Como conferir:** Restaure o tamanho normal após a validação:
  ```sh
  xcrun simctl ui booted content-size-category L
  ```

### Passo 10: Executar a bateria de testes e portões locais
- **Ação:** Rode todos os scripts de validação e a suíte completa no terminal:
  ```sh
  ./Scripts/conferir-textos.sh
  ./Scripts/conferir-datas-fixas.sh
  python3 ./Scripts/validate-fixtures.py
  xcodebuild test -project Frila.xcodeproj -scheme Frila-Local -destination 'platform=iOS Simulator,name=iPhone 16'
  ```
- **Resultado Esperado:** 100% dos testes e verificações estáticas aprovados com sucesso (zero falhas e zero violações de catálogo/tokens).
- **Como conferir:** O terminal deve exibir `** TEST SUCCEEDED **` e os scripts devem sair com código 0.

### Passo 11: Abrir o Pull Request contra `main`
- **Ação:** Faça o commit das alterações, envie a branch para o remoto e abra o PR pelo GitHub CLI ou interface web.
  ```sh
  git add iOS/Sources/Apresentacao/ iOS/Resources/
  git commit -m "feat(design): implementa tokens e componentes do design system no iOS"
  git push -u origin feat/design-fabricio
  gh pr create --base main --title "feat(design): implementacao do design system no iOS" --body "Implementacao do design system conforme GuiaDoFabricio.md"
  ```
- **Resultado Esperado:** PR aberto apontando para a branch `main` de `FrilaApp/frila-frontend`.
- **Como conferir:** Verifique a página do PR no GitHub e confirme que os checks da CI (`ios / parte-1` e `ios / parte-2`) foram disparados.

---

## 8. Checklist de entrega

Antes de submeter seu Pull Request para revisão do Nick Fury, confirme que todos os itens abaixo estão cumpridos:

- [ ] **Apenas camada de Apresentação:** Nenhuma modificação foi feita em `iOS/Sources/Dominio/`, `iOS/Sources/Dados/`, `iOS/Sources/Infraestrutura/`, `iOS/Sources/App/FrilaApp.swift` ou `iOS/Contrato/`.
- [ ] **Zero cores literais:** Nenhuma chamada a `.red`, `.blue`, `Color(red:...)` ou `UIColor` fora de `DesignTokens.swift`.
- [ ] **Zero fontes fixas:** Nenhuma chamada a `.font(.system(size:...))` ou `Font.custom` solta fora de `DesignTokens.swift`.
- [ ] **Zero itálico:** Nenhuma utilização de `.italic()`.
- [ ] **Alvos de toque ≥ 44 pt:** Todos os botões, chips e elementos interativos possuem área de toque mínima de 44 × 44 pt.
- [ ] **Dynamic Type AX5 aprovado:** As telas foram inspecionadas visualmente no tamanho máximo de texto acessível sem cortes ou sobreposições.
- [ ] **Sem a palavra "comissão":** Textos e interfaces respeitam o Guia de Voz e não contêm a palavra "comissão".
- [ ] **Vocabulário oficial em pt-BR:** Termos padronizados (*vaga*, *turno*, *posição*, *estabelecimento*, *profissional*, *comparecimento*).
- [ ] **`./Scripts/conferir-textos.sh` aprovado:** Script executado localmente sem acusar falhas de strings ou tokens.
- [ ] **`xcodebuild test` aprovado:** Suíte completa do esquema `Frila-Local` passando 100% verde.
- [ ] **Sem arquivos espúrios:** O arquivo `Frila.xcodeproj`, arquivos `.DS_Store` ou arquivos de `build/DerivedData` não estão no stage do Git (`git status`).

---

## 9. O que fazer quando travar (Resolução de Bloqueios)

Se encontrar uma inconsistência técnica, falha de compilação ou dúvida de regra de negócio que impeça o avanço do trabalho:

1. **A quem perguntar:**
   - Reporte diretamente ao **Nick Fury** (diretor técnico do projeto e responsável pela arquitetura e merges).
2. **O que levar na mensagem de bloqueio:**
   - **Arquivo e Linha:** Caminho exato onde ocorreu a dúvida ou falha (ex.: `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaDetalheVaga.swift:142`).
   - **Comando Executado:** A linha de comando completa que resultou no erro (ex.: `./Scripts/conferir-textos.sh` ou comando do `xcodebuild`).
   - **Mensagem de Erro Real:** O trecho exato do log do compilador ou script (sem parafrasear).
   - **Dilema ou Hipótese:** Explique de forma concisa qual o conflito (ex.: *"O design prevê campo de texto livre para endereço, mas o contrato da API exige coordenada geográfica obrigatória e região administrativa separada"*).
3. **Não decida em silêncio:**
   - Em caso de divergência entre o design e o contrato da API ou regras de segurança/acessibilidade, **nunca invente campos na API e nunca ignore testes vigentes**. Registre o item na tabela de decisões pendentes e consulte o Nick Fury antes de prosseguir.
