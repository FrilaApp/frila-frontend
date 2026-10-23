# 📜 Manifesto Documental de Páginas e Telas do Simulador

> **Documento Canônico de Registro e Especificação de Telas:**
> Este documento é o manifesto oficial de todas as **29 entradas navegáveis únicas** do aplicativo do simulador Frila (iOS 26+ / macOS 14+). Ele estabelece os identificadores tipados, títulos canônicos, selos de fidelidade/status, caminhos de arquivo de destino, faixas de origem no código base (`cdba74b`), variantes suportadas e a matriz completa de estados aplicáveis.
> Em conformidade com `RULES.md`, `ORQUESTRACAO.md` e a `SPEC.md` do piloto-simulador (§2, §5, §6, §7 e §8).

---

## 1. Sumário de Contagens Derivadas

As contagens refletem rigorosamente o conjunto de entradas navegáveis registradas no catálogo unificado, sem computar tokens isolados, variantes internas ou aliases de flags:

| Ambiente | Categoria | Contagem Canônica | Copy Oficial de Apresentação |
|---|---|---|---|
| **Protótipo** (`prototype`) | Fluxos de Produto | **2 fluxos** | *"Fluxos do produto, com a fidelidade de cada um."* |
| **Sistema** (`system`) | Fundamentos | **4 páginas** | *"Fundamentos e componentes, com variantes e estados."* |
| **Sistema** (`system`) | Componentes Canônicos | **19 páginas** | *(integrado na lista plana de 23 páginas)* |
| **Laboratório** (`lab`) | Explorações Ativas | **4 explorações** | *"O que está em exploração agora."* |
| **Total Global** | **Entradas Únicas Registradas** | **29 entradas** | — |

---

## 2. Ambiente Protótipo (`prototype` — 2 Fluxos)

Os fluxos do Protótipo representam o produto real. Não contêm referências ao Sistema ou ao Laboratório em seu código interno.

### 2.1 Fluxo de Turnos (`prototype/turnos`)
- **ID Tipado (`PrototypeFlowID`):** `.turnos`
- **Rota Canônica:** `prototype/turnos`
- **Título Oficial:** `Turnos`
- **Selo de Fidelidade:** `Média fidelidade`
- **Descrição Curta:** Fluxo operacional de contratação e cumprimento de turnos imediatos no Distrito Federal.
- **Arquivo Destino:** `Sources/FrilaDesignSystem/Shifts/FrilaShiftFlowView.swift`
- **Origem na Base:** `FrilaShiftFlowView.swift` (linhas 8–279) e componentes de `Shifts/`.
- **Subtelas / Etapas:**
  1. Onboarding de disponibilidade do trabalhador (`FrilaWorkerAvailabilityView`, modo `.onboarding`).
  2. Feed de vagas disponíveis no DF (`FrilaShiftFeedView`).
  3. Lista de turnos assumidos pelo profissional (`ShiftMyShiftsView`).
  4. Perfil profissional e atalho de contratação (`ShiftProfileHomeView`).
  5. Publicação rápida de turno pelo contratante (`FrilaPublishShiftSheet`).
- **Variantes Suportadas:** Modo trabalhador (feed / onboarding) e modo contratante (publicação de turno com cálculo de horas e vagas).
- **Matriz de Estados Aplicáveis:**
  - *Claro / Escuro:* **Aplicável** (ambos suportados nativamente com `FrilaColor`).
  - *Vazio:* **Aplicável** (aba "Meus turnos" sem turnos agendados exibe mensagem e botão "Ver vagas").
  - *Carregando / Skeleton:* **Não aplicável** (o fluxo utiliza fixtures locais determinísticas; não há latência de rede simulada neste piloto).
  - *Erro:* **Aplicável** (validação de horário e campos obrigatórios no formulário de publicação).
  - *Desabilitado:* **Aplicável** (botão de publicação desabilitado enquanto campos obrigatórios estiverem incompletos).
  - *Dynamic Type:* **Aplicável** (testado em `xxxLarge` e `accessibility5`).

### 2.2 Fluxo de Descoberta (`prototype/descoberta`)
- **ID Tipado (`PrototypeFlowID`):** `.descoberta`
- **Rota Canônica:** `prototype/descoberta`
- **Título Oficial:** `Descoberta`
- **Selo de Fidelidade:** `Baixa fidelidade`
- **Descrição Curta:** Motor de busca curatorial de contratos de longo prazo, destaques de criadores e estúdio de vagas.
- **Arquivo Destino:** `FrilaApp/FrilaApp/Prototype/DiscoveryFlowView.swift` (extraído de `ContentView.swift`).
- **Origem na Base:** `FrilaApp/FrilaApp/ContentView.swift` (linhas 95–726, `MarketplaceShowcaseView`).
- **Subtelas / Etapas:**
  1. Feed de oportunidades com cards de placard de museu (`DiscoveryFeedView`).
  2. Cápsula de busca e folha de descoberta em 3 zonas (`FrilaSearchDiscoverySheet`).
  3. Tela monográfica de perfil do criador (`FrilaCreatorProfileHero`).
  4. Tela de detalhes completos do contrato via push (`FrilaOpportunityDetailView`).
  5. Painel do Estúdio (`StudioDashboardView`) e criação compacta de vagas (`FrilaJobCreationStudioView`).
- **Variantes Suportadas:** Persona Talento (`.talent`) e Persona Estúdio (`.studio`).
- **Matriz de Estados Aplicáveis:**
  - *Claro / Escuro:* **Aplicável** (ambos suportados integralmente).
  - *Vazio:* **Aplicável** (painel do Estúdio sem contratos criados exibe estado inicial com CTA de nova vaga).
  - *Carregando / Skeleton:* **Aplicável** (feed suporta exibição de skeletons via `FrilaOpportunityCardSkeleton`).
  - *Erro:* **Não aplicável** (a vitrine de descoberta não simula falhas de requisição externa; validações de formulário ocorrem dentro do Estúdio).
  - *Desabilitado:* **Não aplicável** (controles de navegação do feed permanecem interativos).
  - *Dynamic Type:* **Aplicável** (suporte estrito sem truncamento).

---

## 3. Ambiente Sistema: Fundamentos (`system` — 4 Páginas)

O Sistema é estruturado como uma **lista plana única**, dividida visualmente entre fundamentos e componentes.

### 3.1 Tipografia & Fundamentos (`system/typography`)
- **ID Tipado (`SystemPageID`):** `.typography`
- **Rota Canônica:** `system/typography`
- **Título Oficial:** `Tipografia & Fundamentos`
- **Selo:** Canônico (DS)
- **Descrição Curta:** Escala modular Minor Third (1.200), disciplina upright sem itálico e os 7 degraus canônicos.
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/System/TypographyShowcaseView.swift`
- **Origem na Base:** `FrilaDesignLabView.swift` (linhas 1.978–2.100).
- **Variantes Suportadas:** Os 5 paradigmas tipográficos (Swiss, Curatorial, Humanist, Archival, Glass) e as duas vozes do formulário (Bricolage Grotesque e SF Pro).
- **Matriz de Estados Aplicáveis:**
  - *Claro / Escuro:* **Aplicável** (garantido com `dynamicTextPrimary`, `dynamicTextMuted`).
  - *Vazio:* **Não aplicável** (catálogo estático de fundamentos).
  - *Carregando / Skeleton:* **Não aplicável** (tokens fundamentais não possuem estado de carga).
  - *Erro:* **Não aplicável** (não há entrada de usuário).
  - *Desabilitado:* **Não aplicável** (exibição puramente referencial).
  - *Dynamic Type:* **Aplicável** (demonstra a adaptação da escala inteira).

### 3.2 Cores & Tokens (`system/colors`)
- **ID Tipado (`SystemPageID`):** `.colors`
- **Rota Canônica:** `system/colors`
- **Título Oficial:** `Cores & Tokens`
- **Selo:** Canônico (DS)
- **Descrição Curta:** Sistema cromático OKLCH com âncora `#EA5A36`, parede de museu acromática e pastéis funcionais.
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/System/ColorsShowcaseView.swift`
- **Origem na Base:** `FrilaDesignLabView.swift` (linhas 2.102–2.184).
- **Variantes Suportadas:** Escala primária (50 a 900), acromática (canvas, surfaceSubtle, hairline, textMuted), acentos semânticos e pastéis funcionais (terracotta, sage, slate).
- **Matriz de Estados Aplicáveis:**
  - *Claro / Escuro:* **Aplicável** (demonstra a rotação espectral entre light e dark mode).
  - *Vazio / Carregando / Erro / Desabilitado:* **Não aplicável** (amostras estáticas de tokens cromáticos).
  - *Dynamic Type:* **Aplicável** (rótulos dos swatches acompanham tamanhos de acessibilidade).

### 3.3 Liquid Glass (`system/liquid-glass`)
- **ID Tipado (`SystemPageID`):** `.liquidGlass`
- **Rota Canônica:** `system/liquid-glass`
- **Título Oficial:** `Liquid Glass`
- **Selo:** Canônico (DS)
- **Descrição Curta:** Camadas translúcidas do iOS 26+ com borda óptica especular de 2 tons e refração ambiental.
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/System/LiquidGlassShowcaseView.swift`
- **Origem na Base:** `FrilaDesignLabView.swift` (linhas 2.186–2.258).
- **Variantes Suportadas:** Liquid Glass Regular, Liquid Glass Compact e fallback macOS (`ultraThinMaterial`).
- **Matriz de Estados Aplicáveis:**
  - *Claro / Escuro:* **Aplicável** (polarização da borda especular: highlight superior claro e contraste escuro).
  - *Vazio / Carregando / Erro / Desabilitado:* **Não aplicável** (amostra de material e shader).
  - *Dynamic Type:* **Aplicável** (conteúdo interno do vidro redimensiona mantendo borda especular).

### 3.4 Superfície & Sombras (`system/shadows`)
- **ID Tipado (`SystemPageID`):** `.shadows`
- **Rota Canônica:** `system/shadows`
- **Título Oficial:** `Superfície & Sombras`
- **Selo:** Canônico (DS)
- **Descrição Curta:** Sistema Beautiful Shadows em 6 elevações coordenadas, anéis concêntricos e dispersão de sinal.
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/System/ShadowsShowcaseView.swift`
- **Origem na Base:** `FrilaDesignLabView.swift` (linhas 717–752 e 1.109–1.168).
- **Variantes Suportadas:** 6 níveis de elevação (`flat`, `low`, `medium`, `high`, `editorial`, `signal`).
- **Matriz de Estados Aplicáveis:**
  - *Claro / Escuro:* **Aplicável** (em modo escuro as sombras tornam-se anéis de contorno óptico sem blur difuso).
  - *Vazio / Carregando / Erro / Desabilitado:* **Não aplicável** (showcase comparativo de elevações).
  - *Dynamic Type:* **Aplicável** (especificações técnicas e descrições dos cartões são dinâmicas).

---

## 4. Ambiente Sistema: Componentes Canônicos (`system` — 19 Páginas)

### 4.1 Search Capsule (`system/search-capsule`)
- **ID Tipado:** `.searchCapsule`
- **Rota:** `system/search-capsule`
- **Título:** `Search Capsule`
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/System/SearchCapsuleShowcaseView.swift`
- **Origem:** `FrilaDesignLabView.swift` (linhas 1.023–1.041).
- **Variantes:** Padrão e Liquid Glass; com e sem query prévia.
- **Matriz de Estados:** Claro/Escuro: **Sim**. Vazio (placeholder): **Sim**. Carregando/Skeleton: **Sim** (via página de skeletons). Erro: **Não** (não há validação de busca direta na cápsula). Desabilitado: **Não** (cápsula sempre ativa). Dynamic Type: **Sim**.

### 4.2 Segmented Control (`system/segmented-control`)
- **ID Tipado:** `.segmentedControl`
- **Rota:** `system/segmented-control`
- **Título:** `Segmented Control`
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/System/SegmentedControlShowcaseView.swift`
- **Origem:** `FrilaDesignLabView.swift` (linhas 1.042–1.063).
- **Variantes:** 3 segmentos com ícones SF Symbols e texto; alturas 36pt e 44pt.
- **Matriz de Estados:** Claro/Escuro: **Sim**. Vazio: **Não** (sempre possui um segmento selecionado). Carregando: **Não**. Erro: **Não**. Desabilitado: **Sim** (interação congelada com opacidade 0.6). Dynamic Type: **Sim**.

### 4.3 Opportunity Card (`system/opportunity-card`)
- **ID Tipado:** `.opportunityCard`
- **Rota:** `system/opportunity-card`
- **Título:** `Opportunity Card`
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/System/OpportunityCardShowcaseView.swift`
- **Origem:** `FrilaDesignLabView.swift` (linhas 1.064–1.108 e 1.169–1.200).
- **Variantes:** Classic, Framed, Minimal, Liquid e **Hero Placard (Trackle × VOUS)** com progresso duplo.
- **Matriz de Estados:** Claro/Escuro: **Sim**. Vazio: **Não**. Carregando/Skeleton: **Sim** (`FrilaOpportunityCardSkeleton`). Erro: **Não**. Desabilitado: **Não**. Pressionado/Interativo: **Sim** (`scale(0.96)`). Dynamic Type: **Sim**.

### 4.4 Budget Histogram (`system/budget-histogram`)
- **ID Tipado:** `.budgetHistogram`
- **Rota:** `system/budget-histogram`
- **Título:** `Budget Histogram`
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/System/BudgetHistogramShowcaseView.swift`
- **Origem:** `FrilaDesignLabView.swift` (linhas 1.201–1.214).
- **Variantes:** Histograma de 13 barras com e sem botão de commit; sliders de passo magnético.
- **Matriz de Estados:** Claro/Escuro: **Sim**. Vazio: **Não** (distribuição pré-carregada). Carregando: **Não**. Erro: **Sim** (faixa de rate invertida ou inválida). Desabilitado: **Sim** (sliders travados). Dynamic Type: **Sim**.

### 4.5 Botões & Chips de Status (`system/button`)
- **ID Tipado:** `.button`
- **Rota:** `system/button`
- **Título:** `Botões & Chips de Status`
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/System/ButtonShowcaseView.swift`
- **Origem:** `FrilaDesignLabView.swift` (linhas 1.215–1.243).
- **Variantes:** Pílulas Capsule 32pt, 44pt, 52pt; variantes primary, secondary, outline, ghost, ink; `FrilaStatusChip` (verified, warning, neutral, brand).
- **Matriz de Estados:** Claro/Escuro: **Sim**. Vazio: **Não**. Carregando (morph loading): **Sim**. Erro: **Não**. Desabilitado: **Sim** (opacidade reduzida sem feedback de toque). Dynamic Type: **Sim**.

### 4.6 Category Chip (`system/category-chip`)
- **ID Tipado:** `.categoryChip`
- **Rota:** `system/category-chip`
- **Título:** `Category Chip`
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/System/CategoryChipShowcaseView.swift`
- **Origem:** `FrilaDesignLabView.swift` (linhas 1.244–1.339).
- **Variantes:** Temas pastéis funcionais (Terracotta Soft, Sage Atelier, Slate Terminal) com ícones SF Symbols.
- **Matriz de Estados:** Claro/Escuro: **Sim**. Vazio: **Não**. Carregando: **Não**. Erro: **Não**. Desabilitado: **Sim**. Selecionado / Não Selecionado: **Sim** (borda de acento vs contorno sutil). Dynamic Type: **Sim**.

### 4.7 Filter Chip & Dinâmicas de Bounce (`system/filter-chip`)
- **ID Tipado:** `.filterChip`
- **Rota:** `system/filter-chip`
- **Título:** `Filter Chip & Dinâmicas de Bounce`
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/System/FilterChipShowcaseView.swift`
- **Origem:** `FrilaDesignLabView.swift` (linhas 1.340–1.576).
- **Variantes:** Press Bounce (0.94x), Activation Pop Overshoot (1.05x), Segmented Chip Selector, Live Heartbeat Pulse e Wrapping Flow Layout.
- **Matriz de Estados:** Claro/Escuro: **Sim**. Vazio: **Não**. Carregando: **Não**. Erro: **Não**. Desabilitado: **Sim**. Reduce Motion Ativo: **Sim** (elimina overshoot e oscilações, com suporte a binding explícito `simulateReduceMotion: Binding<Bool>` conectado ao seletor de seções da casca/raiz para fonte de verdade única). Dynamic Type: **Sim**.

### 4.8 Proposal Bar & Floating Dock (`system/proposal-bar`)
- **ID Tipado:** `.proposalBar`
- **Rota:** `system/proposal-bar`
- **Título:** `Proposal Bar & Floating Dock`
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/System/ProposalBarShowcaseView.swift`
- **Origem:** `FrilaDesignLabView.swift` (linhas 1.578–1.642).
- **Variantes:** Sticky Proposal Bar padrão (ancorada) e Floating Dock desacoplado em Liquid Glass.
- **Matriz de Estados:** Claro/Escuro: **Sim**. Vazio: **Não**. Carregando / Submetendo: **Sim** (estado de envio assíncrono). Erro: **Não**. Desabilitado: **Sim**. Salvo / Favoritado: **Sim**. Dynamic Type: **Sim**.

### 4.9 Creator Profile Hero (`system/creator-profile-hero`)
- **ID Tipado:** `.creatorProfileHero`
- **Rota:** `system/creator-profile-hero`
- **Título:** `Creator Profile Hero`
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/System/CreatorProfileHeroShowcaseView.swift`
- **Origem:** `FrilaDesignLabView.swift` (linhas 1.643–1.657).
- **Variantes:** Padrão com avatar 68x68pt, anel concêntrico, badge de verificação e métricas de retenção.
- **Matriz de Estados:** Claro/Escuro: **Sim**. Vazio: **Não**. Carregando/Skeleton: **Sim** (`FrilaCreatorProfileHeroSkeleton`). Erro: **Não**. Desabilitado: **Não**. Dynamic Type: **Sim**.

### 4.10 Price Tag & Money (`system/price-tag`)
- **ID Tipado:** `.priceTag`
- **Rota:** `system/price-tag`
- **Título:** `Price Tag & Money`
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/System/PriceTagShowcaseView.swift`
- **Origem:** `FrilaDesignLabView.swift` (linhas 1.658–1.670).
- **Variantes:** Taxa por hora com estimativa total, taxa isolada e valor total fixo sem unidade de tempo.
- **Matriz de Estados:** Claro/Escuro: **Sim**. Vazio: **Não**. Carregando: **Não**. Erro: **Não**. Desabilitado: **Não**. Dynamic Type / VoiceOver falado: **Sim** (formatação en_US protegida).

### 4.11 Toast de Notificação (`system/toast`)
- **ID Tipado:** `.toast`
- **Rota:** `system/toast`
- **Título:** `Toast de Notificação`
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/System/ToastShowcaseView.swift`
- **Origem:** `FrilaDesignLabView.swift` (linhas 1.671–1.738).
- **Variantes:** Estilos `.standard`, `.success`, `.bookmark`, `.warning` e `.neutral`.
- **Matriz de Estados:** Claro/Escuro: **Sim**. Vazio: **Não**. Carregando: **Não**. Erro: **Não**. Desabilitado: **Não**. Entrando / Saindo: **Sim** (mola tátil e drag para dispensar). Dynamic Type: **Sim**.

### 4.12 Feed Stagger & Transição de Cartão (`system/feed-stagger`)
- **ID Tipado:** `.feedStagger`
- **Rota:** `system/feed-stagger`
- **Título:** `Feed Stagger & Transição de Cartão`
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/System/FeedStaggerShowcaseView.swift`
- **Origem:** `FrilaDesignLabView.swift` (linhas 1.739–1.807).
- **Variantes:** Cascata escalonada (delay 0.04s por item) e expansão contínua com `@Namespace`.
- **Matriz de Estados:** Claro/Escuro: **Sim**. Vazio: **Não**. Carregando: **Não**. Erro: **Não**. Desabilitado: **Não**. Reanimação interativa: **Sim**. Dynamic Type: **Sim**.

### 4.13 Opportunity Detail (`system/opportunity-detail`)
- **ID Tipado:** `.opportunityDetail`
- **Rota:** `system/opportunity-detail`
- **Título:** `Opportunity Detail`
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/System/OpportunityDetailShowcaseView.swift`
- **Origem:** `FrilaDesignLabView.swift` (linhas 1.808–1.826).
- **Variantes:** Visualização completa da tela de oportunidade com tags editoriais e barra dockada.
- **Matriz de Estados:** Claro/Escuro: **Sim**. Vazio: **Não**. Carregando: **Não**. Erro: **Não**. Desabilitado: **Não**. Dynamic Type: **Sim**.

### 4.14 Skeletons & Estados de Carga (`system/skeletons`)
- **ID Tipado:** `.skeletons`
- **Rota:** `system/skeletons`
- **Título:** `Skeletons & Estados de Carga`
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/System/SkeletonsShowcaseView.swift`
- **Origem:** `FrilaDesignLabView.swift` (linhas 1.828–1.976).
- **Variantes:** Card skeleton, Hero skeleton, Search skeleton, Bones playground e transição de mola (`FrilaSkeletonCrossfade`).
- **Matriz de Estados:** Claro/Escuro: **Sim**. Vazio: **Não**. Carregando (shimmer ativo): **Sim**. Erro: **Não**. Desabilitado: **Não**. Reduce Motion: **Sim** (shimmer desativado). Dynamic Type: **Sim**.

### 4.15 Stat Card (`system/stat-card`)
- **ID Tipado:** `.statCard`
- **Rota:** `system/stat-card`
- **Título:** `Stat Card`
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/System/StatCardShowcaseView.swift`
- **Origem:** `FrilaDesignLabView.swift` (linhas 754–799).
- **Variantes:** Dado em Destaque (`.metric`, padrão e monumental) e Citação Editorial (`.quote` com aspas curvas).
- **Matriz de Estados:** Claro/Escuro: **Sim**. Vazio: **Não**. Carregando: **Não**. Erro: **Não**. Desabilitado: **Não**. Dynamic Type: **Sim**.

### 4.16 Flow Stepper (`system/flow-stepper`)
- **ID Tipado:** `.flowStepper`
- **Rota:** `system/flow-stepper`
- **Título:** `Flow Stepper`
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/System/FlowStepperShowcaseView.swift`
- **Origem:** `FrilaDesignLabView.swift` (linhas 800–948).
- **Variantes:** Estilos `.activeFocused`, `.dots`, `.pill`; Dock de navegação; Modo por seção (validação linear sequencial).
- **Matriz de Estados:** Claro/Escuro: **Sim**. Vazio: **Não**. Carregando: **Não**. Erro / Fora de ordem: **Sim**. Desabilitado: **Sim** (etapas futuras bloqueadas). Dynamic Type: **Sim**.

### 4.17 Progressive Blur (`system/progressive-blur`)
- **ID Tipado:** `.progressiveBlur`
- **Rota:** `system/progressive-blur`
- **Título:** `Progressive Blur`
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/System/ProgressiveBlurShowcaseView.swift`
- **Origem:** `FrilaDesignLabView.swift` (linhas 949–987).
- **Variantes:** Desfoque progressivo em cabeçalho fixo com gradiente de opacidade e suavização óptica.
- **Matriz de Estados:** Claro/Escuro: **Sim**. Vazio / Carregando / Erro / Desabilitado: **Não aplicável** (efeito de rolagem contínua). Dynamic Type: **Sim**.

### 4.18 Numbered List (`system/numbered-list`)
- **ID Tipado:** `.numberedList`
- **Rota:** `system/numbered-list`
- **Título:** `Numbered List`
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/System/NumberedListShowcaseView.swift`
- **Origem:** `FrilaDesignLabView.swift` (linhas 988–1.017).
- **Variantes:** Estilos `.card` (com borda e sombra) e `.plain` (divisores flutuantes de 1pt).
- **Matriz de Estados:** Claro/Escuro: **Sim**. Vazio: **Não**. Carregando: **Não**. Erro: **Não**. Desabilitado: **Não**. Dynamic Type: **Sim**.

### 4.19 Editorial Tag (`system/editorial-tag`)
- **ID Tipado:** `.editorialTag`
- **Rota:** `system/editorial-tag`
- **Título:** `Editorial Tag`
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/System/EditorialTagShowcaseView.swift`
- **Origem:** `FrilaEditorialTag.swift` e promovido conforme `DECISOES.md`.
- **Variantes:** `.minimalPlacard`, `.framedAccent`, `.splitPill`, `.editorialNumber`.
- **Matriz de Estados:** Claro/Escuro: **Sim**. Vazio: **Não**. Carregando: **Não**. Erro: **Não**. Desabilitado: **Sim**. Dynamic Type: **Sim**.

---

## 5. Ambiente Laboratório (`lab` — 4 Explorações)

### 5.1 Roletas Acopladas (`lab/role-picker`)
- **ID Tipado (`ExperimentID`):** `.rolePicker`
- **Rota:** `lab/role-picker`
- **Título:** `Roletas Acopladas`
- **Status:** `Em exploração`
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/Experiments/RolePickerExperimentView.swift`
- **Origem:** `FrilaDesignLabView.swift` (linhas 2.412–2.725).
- **Variantes:** Eixos vertical e horizontal; estilos de agrupamento (`.neutral`, `.stone`, `.brand`); estilos de confirmação (`.solid`, `.outline`, `.subtle`).
- **Matriz de Estados:** Claro/Escuro: **Sim**. Vazio: **Sim**. Navegando: **Sim**. Confirmado: **Sim**. Erro: **Sim**. Desabilitado: **Sim**. Dynamic Type: **Sim**.

### 5.2 Seletor de Experiência (`lab/experience`)
- **ID Tipado (`ExperimentID`):** `.experience`
- **Rota:** `lab/experience`
- **Título:** `Seletor de Experiência`
- **Status:** `Em exploração`
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/Experiments/ExperienceExperimentView.swift`
- **Origem:** `FrilaDesignLabView.swift` (linhas 2.782–2.812).
- **Variantes:** Expansão in-place, escolha por toque ou por deslize (segurar e arrastar), recolhimento imediato ao concluir e conferência de contraste WCAG AA.
- **Matriz de Estados:** Claro/Escuro: **Sim**. Vazio / Não selecionado: **Não** (inicia com nível default). Aberto: **Sim**. Confirmado: **Sim**. Transição: **Sim**. Desabilitado: **Sim**. Dynamic Type: **Sim**.

### 5.3 Studio Lab (`lab/studio`)
- **ID Tipado (`ExperimentID`):** `.studio`
- **Rota:** `lab/studio`
- **Título:** `Studio Lab`
- **Status:** `Em exploração`
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/Experiments/StudioExperimentView.swift`
- **Origem:** `FrilaDesignLabView.swift` (linhas 508–713).
- **Variantes:** Rascunhos Vazio, Parcial e Completo; Notificação em Lock Screen; Celebração.
- **Matriz de Estados:** Claro/Escuro: **Sim**. Vazio: **Sim**. Preenchido: **Sim**. Modal / Sheet aberto: **Sim**. Erro de validação: **Sim**. Dynamic Type: **Sim**.

### 5.4 Controles de Turnos (`lab/shift-controls`)
- **ID Tipado (`ExperimentID`):** `.shiftControls`
- **Rota:** `lab/shift-controls`
- **Título:** `Controles de Turnos`
- **Status:** `Em exploração`
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/Experiments/ShiftControlsExperimentView.swift`
- **Origem:** `FrilaDesignLabView.swift` (linhas 427–506).
- **Variantes:** Demonstração dos controles atômicos de horários, dias e steppers de vagas e remuneração.
- **Matriz de Estados:** Claro/Escuro: **Sim**. Padrão: **Sim**. Limites operacionais (mínimo/máximo): **Sim**. Desabilitado: **Sim**. Dynamic Type: **Sim**.

---

## 6. Tabela Completa de Mapeamento Técnico de Código

| ID Canônico | Ambiente | Tipo | Arquivo Destino Proposto | Faixa de Origem (`cdba74b`) |
|---|---|---|---|---|
| `prototype/turnos` | Protótipo | Fluxo | `Shifts/FrilaShiftFlowView.swift` | `Shifts/FrilaShiftFlowView.swift:8–279` |
| `prototype/descoberta` | Protótipo | Fluxo | `FrilaApp/Prototype/DiscoveryFlowView.swift` | `ContentView.swift:95–726` |
| `system/typography` | Sistema | Fundamento | `DesignLab/System/TypographyShowcaseView.swift` | `FrilaDesignLabView.swift:1978–2100` |
| `system/colors` | Sistema | Fundamento | `DesignLab/System/ColorsShowcaseView.swift` | `FrilaDesignLabView.swift:2102–2184` |
| `system/liquid-glass` | Sistema | Fundamento | `DesignLab/System/LiquidGlassShowcaseView.swift` | `FrilaDesignLabView.swift:2186–2258` |
| `system/shadows` | Sistema | Fundamento | `DesignLab/System/ShadowsShowcaseView.swift` | `FrilaDesignLabView.swift:717–752, 1109–1168` |
| `system/search-capsule` | Sistema | Componente | `DesignLab/System/SearchCapsuleShowcaseView.swift` | `FrilaDesignLabView.swift:1023–1041` |
| `system/segmented-control`| Sistema | Componente | `DesignLab/System/SegmentedControlShowcaseView.swift` | `FrilaDesignLabView.swift:1042–1063` |
| `system/opportunity-card` | Sistema | Componente | `DesignLab/System/OpportunityCardShowcaseView.swift` | `FrilaDesignLabView.swift:1064–1108, 1169–1200` |
| `system/budget-histogram` | Sistema | Componente | `DesignLab/System/BudgetHistogramShowcaseView.swift` | `FrilaDesignLabView.swift:1201–1214` |
| `system/button` | Sistema | Componente | `DesignLab/System/ButtonShowcaseView.swift` | `FrilaDesignLabView.swift:1215–1243` |
| `system/category-chip` | Sistema | Componente | `DesignLab/System/CategoryChipShowcaseView.swift` | `FrilaDesignLabView.swift:1244–1339` |
| `system/filter-chip` | Sistema | Componente | `DesignLab/System/FilterChipShowcaseView.swift` | `FrilaDesignLabView.swift:1340–1576` |
| `system/proposal-bar` | Sistema | Componente | `DesignLab/System/ProposalBarShowcaseView.swift` | `FrilaDesignLabView.swift:1578–1642` |
| `system/creator-profile-hero` | Sistema | Componente | `DesignLab/System/CreatorProfileHeroShowcaseView.swift` | `FrilaDesignLabView.swift:1643–1657` |
| `system/price-tag` | Sistema | Componente | `DesignLab/System/PriceTagShowcaseView.swift` | `FrilaDesignLabView.swift:1658–1670` |
| `system/toast` | Sistema | Componente | `DesignLab/System/ToastShowcaseView.swift` | `FrilaDesignLabView.swift:1671–1738` |
| `system/feed-stagger` | Sistema | Componente | `DesignLab/System/FeedStaggerShowcaseView.swift` | `FrilaDesignLabView.swift:1739–1807` |
| `system/opportunity-detail` | Sistema | Componente | `DesignLab/System/OpportunityDetailShowcaseView.swift` | `FrilaDesignLabView.swift:1808–1826` |
| `system/skeletons` | Sistema | Componente | `DesignLab/System/SkeletonsShowcaseView.swift` | `FrilaDesignLabView.swift:1828–1976` |
| `system/stat-card` | Sistema | Componente | `DesignLab/System/StatCardShowcaseView.swift` | `FrilaDesignLabView.swift:754–799` |
| `system/flow-stepper` | Sistema | Componente | `DesignLab/System/FlowStepperShowcaseView.swift` | `FrilaDesignLabView.swift:800–948` |
| `system/progressive-blur` | Sistema | Componente | `DesignLab/System/ProgressiveBlurShowcaseView.swift` | `FrilaDesignLabView.swift:949–987` |
| `system/numbered-list` | Sistema | Componente | `DesignLab/System/NumberedListShowcaseView.swift` | `FrilaDesignLabView.swift:988–1017` |
| `system/editorial-tag` | Sistema | Componente | `DesignLab/System/EditorialTagShowcaseView.swift` | `FrilaEditorialTag.swift` |
| `lab/role-picker` | Laboratório | Experimento | `DesignLab/Experiments/RolePickerExperimentView.swift` | `FrilaDesignLabView.swift:2412–2725` |
| `lab/experience` | Laboratório | Experimento | `DesignLab/Experiments/ExperienceExperimentView.swift` | `FrilaDesignLabView.swift:2782–2812` |
| `lab/studio` | Laboratório | Experimento | `DesignLab/Experiments/StudioExperimentView.swift` | `FrilaDesignLabView.swift:508–713` |
| `lab/shift-controls` | Laboratório | Experimento | `DesignLab/Experiments/ShiftControlsExperimentView.swift` | `FrilaDesignLabView.swift:427–506` |
