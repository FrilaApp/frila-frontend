# 🧪 Arquivo e Governança do Laboratório de Design System

> **Documento Normativo de Registro e Ciclo de Vida:**
> Este documento é o repositório histórico oficial do **Laboratório de Design System** do Frila. Ele registra a governança do laboratório, os critérios de transição de status, o estado das explorações ativas e o arquivo de decisões de promoção ou arquivamento de experimentos.
> Em conformidade estrita com `RULES.md`, `ORQUESTRACAO.md` e a `SPEC.md` do piloto-simulador (§2, §5, §6, §7 e §8).

---

## 1. Princípios e Governança do Laboratório

O ambiente **Laboratório (`lab`)** é uma área isolada do app do simulador Frila destinada à ideação tátil, testes de usabilidade A/B, calibração de micro-interações de mola e validação de padrões de interface de vanguarda (iOS 26+ Liquid Glass, toque com feedback háptico).

### 1.1 Ciclo de Vida de um Experimento

Qualquer padrão ou componente no Laboratório segue um ciclo de vida rigoroso de três estados:

```
┌─────────────────────────────────┐
│         EM EXPLORAÇÃO           │  ◄── Permanece ativo na lista executável do app
└────────────────┬────────────────┘
                 │
                 ├──► DECIDIDO    ───► Promovido ao Sistema (DS) ou Protótipo (Fluxo)
                 │                     (sai da lista executável do Lab)
                 │
                 └──► ARQUIVADO   ───► Removido da árvore de código executável
                                       (preservado documentalmente neste arquivo)
```

1. **Em Exploração (`in-exploration`):** O experimento possui código ativo, tela no catálogo do Laboratório e está aberto para avaliação pela equipe e pela pessoa (Product Designer). Exibe o selo explícito `Em exploração` na interface.
2. **Decidido (`decided`):** O experimento atingiu maturidade, teve sua hipótese validada e foi aprovado pela pessoa. **Ele sai da lista ativa do Laboratório** e é integrado canonicamente ao ambiente **Sistema** (como componente ou fundamento) ou ao **Protótipo** (como etapa de fluxo de produto). Não mantém destino executável residual no Lab.
3. **Arquivado (`archived`):** O experimento foi rejeitado ou descontinuado (por baixa ergonomia, ruído visual, violação de acessibilidade ou redundância). **Seu código é completamente removido do repositório** para evitar dívida técnica e inchaço do bundle. A justificativa técnica, histórico, data e lições aprendidas são perpetuados exclusivamente nesta documentação.

### 1.2 Regra de Pureza da Lista Executável
A lista ativa do ambiente Laboratório no app exibe **estritamente experimentos com status `Em exploração`**. Não existem galerias executáveis de código descontinuado ou já promovido. Caso em algum ciclo futuro todas as explorações ativas sejam promovidas ou arquivadas, a interface do app exibe o estado vazio oficial:
> *"Nenhuma exploração ativa."*

---

## 2. Explorações Ativas no Piloto (`Em exploração`)

Na rodada atual (2026-10-06), **exatamente 4 experimentos** permanecem com status ativo `Em exploração`. Todos possuem destinos tipados registráveis no simulador:

### 2.1 Roletas Acopladas (`lab/role-picker`)
- **Identificador de Rota:** `lab/role-picker`
- **Componente Central:** `FrilaCoupledRolePicker.swift` e auxiliares (`FrilaWheelColumn.swift`, `FrilaMorphingFieldContainer.swift`, `FrilaWheelPhysics.swift`, `FrilaPendingTextEffect.swift`).
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/Experiments/RolePickerExperimentView.swift`
- **Hipótese em Teste:** Seleção de função profissional em dois eixos ortogonais acoplados (Categoria $\to$ Função) com efeito de atrito tátil, morphing concêntrico de container e teste A/B de estilos cromáticos (`.neutral`, `.stone`, `.brand`).
- **Estados Demonstrados:** 5 estados de formulário: Vazio, Navegando/Selecionando, Confirmado, Erro/Inválido, Desabilitado.
- **Critério de Decisão:** Validação da fricção em aparelhos reais e fluidez da mola de assentamento em 60/120 Hz.

### 2.2 Seletor de Nível de Experiência (`lab/experience`)
- **Identificador de Rota:** `lab/experience`
- **Componente Central:** `FrilaExperienceLevelPicker.swift` (consumindo `FrilaSelectionLayerList.swift`).
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/Experiments/ExperienceExperimentView.swift`
- **Hipótese em Teste:** Seletor ordinal de senioridade com expansão em linha (`in-place`), camada de seleção deslizante única cinza neutra (`dynamicSelectionWash`) escolha por toque ou por deslize (segurar cerca de 0,15 s e arrastar, háptico por linha) e recolhimento imediato ao concluir, sem timer.
- **Estados Demonstrados:** Fechado (valor confirmado), Aberto (navegando entre opções, por toque ou deslize), Transição com crossfade de peso tipográfico (Bricolage Grotesque Regular $\to$ Bold sem troca de glifo).
- **Critério de Decisão:** Avaliação ergonômica do deslize contra a rolagem da página e conformidade estrita WCAG AA (5,4:1 claro / 5,9:1 escuro no preenchimento de marca).

### 2.3 Studio Lab de Criação de Vagas (`lab/studio`)
- **Identificador de Rota:** `lab/studio`
- **Componentes Centrais:** `FrilaJobCreationStudioView.swift`, `FrilaJobFormSections.swift`, `CuratorialPresetArtwork`.
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/Experiments/StudioExperimentView.swift`
- **Hipótese em Teste:** Experimento integrado de preenchimento rápido de rascunhos de contratação (Vazio, Parcial, Completo), integração com roletas de funções, simulação de notificação iOS na tela de bloqueio (`FrilaLockScreenNotificationView`) e celebração com mola tátil (`JobCreationCelebrationSheet`).
- **Estados Demonstrados:** Rascunhos em 3 níveis de preenchimento, formulário expandido, prévia do anúncio em sheet.
- **Critério de Decisão:** Fluidez do fluxo de ponta a ponta e viabilidade de unificação definitiva com a persona Studio do fluxo Descoberta.

### 2.4 Controles de Turnos (`lab/shift-controls`)
- **Identificador de Rota:** `lab/shift-controls`
- **Componentes Centrais:** `FrilaPositionsStepper`, `FrilaShiftDayPicker`, `FrilaTimeField`, `FrilaRateStepper`, `FrilaShiftCard`.
- **Arquivo Destino:** `Sources/FrilaDesignSystem/DesignLab/Experiments/ShiftControlsExperimentView.swift`
- **Hipótese em Teste:** Controles atômicos isolados do fluxo de contratação de turnos imediatos (DF), permitindo testes de granularidade de horário, seleção de dias da semana e steppers de remuneração por hora com VoiceOver falado.
- **Estados Demonstrados:** Valores padrão, limites mínimos/máximos, tema claro e escuro.
- **Critério de Decisão:** Estabilidade dos controles individuais antes de qualquer refatoração na sheet principal de publicação.

---

## 3. Registro Histórico de Decisões de Promoção (`Decidido`)

A tabela a seguir consolida as promoções formais aprovadas pela autoridade de design (Product Designer) na rodada de 2026-10-06. Nenhum dos itens abaixo permanece no Laboratório; todos foram promovidos a cidadãos de primeira classe do ecossistema Frila:

| Data | Componente / Elemento Promovido | Origem Histórica | Destino Canônico | Motivo da Decisão e Racional Técnico |
|---|---|---|---|---|
| **2026-10-06** | **Vitrine do Marketplace** (`MarketplaceShowcaseView`) | Ramo legado ativado por `--showcase` | **Protótipo:** `prototype/descoberta` (*Baixa fidelidade*) | A vitrine foi validada como o núcleo essencial da Descoberta de contratos de longo prazo e do Estúdio de criação. O termo `legacy` foi completamente eliminado do vocabulário e do código. |
| **2026-10-06** | **FrilaStatCard** | Seção Editorial & Deck (Challenge 18) | **Sistema:** `system/stat-card` | Padrão quantitativo de alto impacto aprovado (números gigantes em cor de sinal `#EA5A36`, tracking condensado -0.035em e citação editorial com aspas curvas). Rótulo "Challenge 18" removido. |
| **2026-10-06** | **FrilaNumberedList** | Seção Editorial & Deck (Challenge 18) | **Sistema:** `system/numbered-list` | Lista numerada curatorial aprovada para exibição de escopos técnicos e diretivas, com divisores de 1pt e voz Bricolage + SF Pro. Rótulo histórico removido. |
| **2026-10-06** | **FrilaEditorialTag** | Seção Editorial & Deck / Oportunidade | **Sistema:** `system/editorial-tag` | Tag tipográfica e estrutural de competências consolidada para uso em detalhes de oportunidades e briefings de contratação. |
| **2026-10-06** | **Superfície & Elevações de Sombra** | Seção Editorial & Deck / Beautiful Shadows | **Sistema:** `system/shadows` | Sistema Beautiful Shadows em 6 elevações (`flat`, `low`, `medium`, `high`, `editorial`, `signal`) aprovado como fundamento canônico de elevação sem sombras pretas difusas da web (G2). |
| **2026-10-06** | **HeroPlacardOpportunityCard** | Seção Editorial & Deck / Opportunity Variants | **Sistema:** `system/opportunity-card` *(variante Hero Placard)* | Card de oportunidade com barra dupla de progresso (orçamento vs prazo) e avatares sobrepostos integrado como variante canônica do `FrilaOpportunityCard`. |
| **2026-10-06** | **FrilaFlowStepper** | Seção Editorial & Deck / Studio Form | **Sistema:** `system/flow-stepper` | Régua canônica de etapas do formulário aprovada (estilos activeFocused, dots, pill), com dock de navegação e validação linear por seção. |
| **2026-10-06** | **FrilaProgressiveBlur** | Seção Editorial & Deck | **Sistema:** `system/progressive-blur` | Mecanismo de desfoque progressivo com transição contínua aprovado como primitiva de cabeçalhos fixos. |

### 3.1 Preservação de Tokens Editoriais Compartilhados
Conforme determinação explícita de `DECISOES.md`, todos os tokens criados durante os experimentos editoriais **permanecem ativos e intocados em seus valores numéricos e matemáticos**, tendo apenas seus comentários históricos ("Challenge 18 Merge") substituídos por descrições canônicas de design system:
- `FrilaGeometry.radiusCardEditorial = 28`
- `FrilaGeometry.flowStepBarHeight = 6` (e altura uniforme de 4pt no modo seção)
- `FrilaColor.dynamicInk`, `FrilaColor.dynamicInkSecondary`, `FrilaColor.dynamicSubtle`, `FrilaColor.dynamicDividerStrong`
- `FrilaShadowElevation.editorial`

---

## 4. Registro de Itens Arquivados (`Arquivado`)

> **Certificação de Integridade (SPEC §8, Critério 7):**
> **Nenhum experimento do Laboratório foi arquivado nesta rodada.** Todos os 4 experimentos em curso permanecem ativos com status `Em exploração`, e os elementos da seção Editorial foram 100% promovidos ao Sistema canônico. Não há descarte de código nem invenção de registros fictícios de arquivamento.

| Data | Nome do Experimento | Identificador de Rota | Motivo do Arquivamento | Lições Aprendidas e Alternativa Adotada |
|---|---|---|---|---|
| *(Nenhum item arquivado no piloto atual)* | — | — | — | — |

---

## 5. Template para Futuras Rodadas de Arquivamento ou Promoção

Quando uma exploração for encerrada em ciclos subsequentes de orquestração, a entrada correspondente deve ser adicionada a este documento seguindo o modelo abaixo:

```markdown
### [YYYY-MM-DD] Nome do Experimento (`lab/<id>`)
- **Status Final:** `Decidido (Promovido)` | `Arquivado (Descontinuado)`
- **Destino Canônico (se promovido):** `system/<page-id>` ou `prototype/<flow-id>`
- **Commits / PR Relacionado:** #PR
- **Racional da Decisão:** Explicação sucinta do motivo pelo qual a hipótese foi validada ou refutada.
- **Impacto no Código Executável:** Arquivo Swift correspondente removido de `Sources/FrilaDesignSystem/DesignLab/Experiments/` ou movido para `System/`.
- **Lições Aprendidas:** O que a medição no simulador e os testes revelaram sobre interação, performance ou acessibilidade.
```
