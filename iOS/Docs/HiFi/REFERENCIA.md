# Referência Hi-Fi do Frila

**Estado:** referência HIFI-01 aprovada pelo usuário em 24/10/2026, com as quatro decisões da §9 incorporadas. Este documento não aprova conversão de telas, componentes ou fluxos.

## 1. Autoridade, fontes e limites

O FrilaLowPhase em `origin/main` é a referência Hi-Fi oficial e se sobrepõe ao Hi-Fi do frila-frontend onde divergir. A implementação atual do frontend é evidência do estado existente, nunca prova de conformidade.

Snapshots deste levantamento:

| Repositório | Ref consultada | Commit |
|---|---|---|
| FrilaLowPhase, fonte | `origin/main` | `cfe8a64377bb01fc18f70b8fde28d99893db0064` |
| frila-frontend, destino | `origin/main` | `4d19e74f3f1c1991f5f15d9807ca6fe161aa631e` |

As fontes são os snapshots de origin/main fixados pelos SHAs da tabela. Paths de origem abaixo são relativos à raiz de cada repositório, no respectivo SHA.

- **R:** `RULES.md`, §1, §§3.1–3.5: guardrails, acessibilidade, formulários, M1–M21, seis pilares e movimento.
- **T:** `docs/design-system/tokens.json`: papéis de cor, geometria, paradigmas e exemplos. Não transportar tecnologia web nem converter unidades de exemplos automaticamente.
- **V:** `docs/design-system/VARIANTS_MATRIX.md`, `frila_component_variants_spec.md` e `primitives_typography_variants.md`: variantes e seus custos, sem escolha automática de uma variante.
- **D:** `docs/design-system/frila_design_system_spec.md`, `DESIGN_MEMORY.md`, `DESIGN_MERGE_SPEC.md`, `DESIGN_PLAN.md` e `JOB_CREATION_FLOW_SPEC.md`: contexto, composição e propostas que contêm divergências entre si.
- **A:** `docs/design-system/MIGRACAO-APIS.md`: substituições canônicas; não ressuscitar APIs depreciadas ou o conceito de escrow.
- As primitivas Swift referenciadas nesses documentos foram consultadas pela mesma ref para verificar nomes e valores, sem executá-las. As decisões do usuário na §9 resolvem as contradições identificadas e prevalecem sobre os trechos conflitantes da fonte.

Esta é uma especificação visual/interativa. Não muda domínio, contratos, moeda, permissões, dados, navegação de produto nem Logs já aprovados. Exemplos de mercado, taxas e valores da fonte não viram funcionalidades ou conteúdo real por cópia. A governança de execução continua sendo o AGENTS.md do frila-frontend.

## 2. Guardrails e seis pilares

Síntese de R §1, §3.2, §3.4 e §3.4b:

| ID | Régua de revisão |
|---|---|
| G1 | Implementação e validação de interface exclusivamente Swift/SwiftUI nativas. Nenhum protótipo ou harness web. |
| G2 | Zero-shadow nos cartões: separação por espaço, fio e material, sem sombra. Cartão com `.subtle` é divergente, conforme decisão Q3=A. |
| G3 | SF Symbols para ícones; nenhum emoji ou glifo textual decorativo em chips, badges e ações. |
| G4 | Tipografia upright em todos os paradigmas; sem itálico. |
| G5 | Dinheiro passa por formatador central e etiqueta com leitura falada; nunca interpolação manual de moeda/unidade. No app, preservar BRL/pt-BR e o contrato real; exemplos USD da fonte não alteram o produto. |
| G6 | Botões de componente em Capsule, alturas visuais 32/44/52 pt. Controle compacto continua com toque mínimo de 44 pt. |
| G7 | Concentricidade: raio externo = raio interno + padding; raio interno nunca negativo nem maior que o externo. |
| G8 | Área interativa mínima de 44 × 44 pt; a dimensão visual não substitui a hitbox. |
| G9 | Sem segredos ou credenciais em fontes/fixtures/versionamento. |
| G10 | Sem caminhos locais absolutos em código executável, fixtures ou testes. |

- **Tom:** registro curto de placa de museu, sem marketing genérico. Não unir metadados com ponto médio, bullets ou travessões artificiais: usar estrutura nativa ou gramática comum.
- **Profundidade:** cartões contidos; fotografias com contorno alfa puro, preto 8% no claro e branco 10% no escuro. Não aplicar borda cinza tingida à mídia.
- **Cor:** tokens semânticos, com tema e contraste; cor nunca é o único sinal de estado. Terracota é acento funcional, não fundo de tela.
- **Tipo e números:** Swiss como padrão; SF Pro e algarismos proporcionais em preços/métricas estáticas. Tabulares somente quando animam ou precisam alinhar em coluna; nunca SF Mono para preços.
- **Geometria e toque:** ações irmãs compartilham altura e proporção; respeitar raios concêntricos e alcance do polegar.
- **Física:** molas específicas por intenção, pressão discreta, Reduzir Movimento obrigatório. Não copiar uma animação existente como autoridade.

**Informação resolvida:** preferir palavras completas e referências relativas úteis, resultados calculados em evidência e um campo por linha quando a compressão exigir abreviação. Mudar o layout antes de mutilar a informação.

## 3. Cor: correspondência e lacunas

No destino, `DS/` significa `iOS/Sources/Apresentacao/DesignSystem/`. Os aliases em português ficam em `DS/DesignTokens.swift`; `FrilaColor` existe em `DS/Primitivas/FrilaColorDesignTokens.swift`. Ter um token importado não prova que uma tela o consome.

Na tabela, valores são **claro / escuro da primitiva da fonte**, não resultado de renderização. A correspondência é por papel; paridade de pixels/contraste do app não foi executada neste levantamento. Paleta aprovada: marca EA5A36/F26643 (Q1=A) e canvas escuro 111111 (Q2=A); FF4D17 permanece proposta não adotada.

| FrilaLowPhase | Valor/papel da fonte | Nome existente no frila-frontend |
|---|---|---|
| `dynamicBrandAccent` | `#EA5A36 / #F26643`; âncora OKLCH `0.6510 0.1856 35.10°` no claro | `FrilaCor.marca` |
| `dynamicTextInk` | `#090908 / #FFFFFF`; pílula neutra principal | `FrilaCor.primaria` |
| `dynamicCanvas` | `#FFFFFF / #111111`; canvas operacional aprovado em Q2=A | `FrilaCor.fundo`; `sobrePrimaria` usa o mesmo papel |
| `dynamicBrandSolidFill` | `#C9470F` nos dois temas; seleção sólida | `FrilaCor.selecao` |
| `dynamicBrandSolidText` | Branco nos dois temas; par com seleção sólida | `FrilaCor.sobreSelecao` |
| `dynamicFormCardSurface` | `#FAFAFA / #171717`; cartão de formulário | `FrilaCor.superficie` |
| `dynamicFormFieldSurface` | `#F5F5F5 / #1C1C1C`; campo neutro | `FrilaCor.superficieDoCampo` |
| `dynamicFormFieldBorder` | `#8C8C8C / #6A6A6A`; identifica campo interativo | `FrilaCor.bordaDoCampo` |
| `dynamicTextPrimary` | `#1B1A18 / #F5F4F0` | `FrilaCor.texto` |
| `dynamicFormTextMuted` | `#6B6B6B / #A3A3A3`; apoio de formulário | `FrilaCor.textoSecundario` |
| `dynamicInputBg` | `#F2F2F0 / #23221F`; controle neutro | `FrilaCor.controle`, por papel; conferir assets no levantamento de estado |
| `dynamicHairline` | `#E5E5E3 / #2E2D29`; fio decorativo | `FrilaCor.divisoria`, por papel |
| `dynamicBorder` | `#CECECB / #44433E`; contorno de controle | `FrilaCor.borda`, por papel; não confundir com borda de campo |
| `dynamicVerified` | `#007A33 / #4ADE80`; verificação | `FrilaCor.sucesso`; não significa custódia financeira |
| `dynamicWarningText` / `dynamicError` | Alerta/erro com texto e símbolo além da cor | `FrilaCor.alerta` / `FrilaCor.perigo`, por papel |
| `primary50…primary950` | Escala tonal; não trocar matiz por aproximação | Existe em `FrilaColor`; sem escala completa em `FrilaCor` |
| `dynamicSurfaceSubtle` | `#FBFBFA / #171614`; superfície de galeria | Existe em `FrilaColor`; sem alias português específico; não é `superficie` |
| `dynamicTextMuted` | `#767571 / #9E9D97`; apoio de galeria | Existe em `FrilaColor`; não equivale a `textoSecundario` de formulário |
| `dynamicFormCardBorder` | `#D6D6D6 / #363636`; fio de formulário | Existe em `FrilaColor`; sem alias específico em `FrilaCor` |
| `dynamicBrandText` | `primary600 / primary400`; tinta de marca sobre campo | Existe em `FrilaColor`; sem alias português específico |
| `dynamicSelectionWash` | `#EDEDEB / #282826`; linha sob escolha/dedo | Existe em `FrilaColor`; sem alias em `FrilaCor` |
| `dynamicBrandChipBg/Text/Border` | Claro: primary50/primary700; escuro: primary500 a 18%/primary400, borda 32% | Existem em `FrilaColor`; sem trio equivalente em `FrilaCor` |
| `dynamicGroupGraphite*`, `dynamicGroupStone*`, `groupFieldLight` | Paletas de grupo; campo claro do grupo `#F6F6F4` | Existem em `FrilaColor`; sem aliases em português. Não substituir por `superficieDoCampo` |
| `dynamicMediaOutline`, `dynamicInkSecondary`, `dynamicRaisedSelectionLayer` | Contorno de mídia, texto sobre seleção e seleção em cartão elevado | Existem em `FrilaColor`; sem aliases dedicados em `FrilaCor` |
| Sem correspondente homônimo estabelecido neste mapa | Puxador e pontes UIKit do app | `FrilaCor.puxador`, `fundoUIKit`, `textoUIKit`; convenções locais, não novos tokens da fonte |

**Estados diferentes não compartilham a mesma cor por conveniência:** wash cinza da lista aberta, chip de marca e escolha confirmada sólida são papéis distintos. M10 proíbe wash **de marca** em campo confirmado; não proíbe o wash **cinza** de M12. Nos grupos, R §3.2c prevê confirmação laranja no claro e grafite no escuro; não generalizar essa variante para toda seleção sólida.

**Contraste:** texto normal ≥4,5:1; texto grande e sinais visuais de controles ≥3:1 onde aplicável. A fonte declara 4,78:1 para branco sobre `#C9470F`. Não usar a âncora viva como texto pequeno; validar o par real e seu tema. Fio decorativo não substitui contorno perceptível de campo. As razões citadas por documentos distintos não são intercambiáveis entre superfícies.

## 4. Tipografia, números e geometria

Fonte: R §3.2b/§3.4 e primitivas referenciadas; V distingue cinco paradigmas, sem itálico em nenhum deles. Swiss é o padrão. Curatorial, Humanist, Archival e Liquid Glass são alternativas documentadas, não uma autorização para alternar famílias em toda tela.

| Papel na fonte | Correspondência atual | Régua / diferença |
|---|---|---|
| `FrilaTypography.display` | `FrilaTipo.tituloGrande` | Escala nativa: 32 pt; tracking/peso vêm da spec |
| `title` / `titleLarge` | `secao`, `tituloDeEstado` / `tituloDoDetalhe` | 22 / 26 pt; não criar degrau solto |
| `placard` | `tituloDoCartao`, `tituloDaFolha`, `subtituloDaTela` | 18 pt, upright |
| `entity`, `body`, `caption` | `resumo`, `corpo`, `nota` | 15 bold, 15 regular, 13 regular |
| Apoio de leitura | `FrilaTipo.meta` | `.subheadline` por compatibilidade do app; não é cópia numérica de todo papel da origem |
| `FrilaFormType.question` | `FrilaTipo.pergunta` | Bricolage Bold 26, tracking −0,6 |
| `answer` / `answerContext` | `respostaEscolhida` / `contextoDaResposta` | Bricolage Bold / Regular 17 |
| `input`, `support`, `fieldLabel`, `microLabel` | `valorDoCampo`, `aviso`, `rotuloDoCampo`, `microRotulo` | SF Pro 17/15/13/11; microrrótulo com tracking +0,8 e uppercase por transformação |
| `metric`, `metricCompact`, `FrilaPriceTag` | `FrilaPriceTag` e `FrilaTipo.preco` | **Divergência:** `preco` aplica `monospacedDigit()`; não atende ao padrão proporcional para preço estático |
| Métricas editoriais | Specs em `FrilaTypography` importada | `metricHeroSpec` 44 é outro papel; R limita `metricMonumentalSpec` a 38 e `metricCardBigSpec` a 34. Não importar 92/64 do documento de merge como regra vigente |
| Paradigmas alternativos | `FrilaTypographyParadigm` importado | Sem seletor equivalente em `FrilaTipo`; escolha contextual exige Log, não é lacuna de fonte a preencher por gosto |

Escala geral nativa Minor Third: 11, 13, 15, 18, 22, 26 e 32 pt. Formulário editorial usa explicitamente 26/17/15/13/11. Dynamic Type deve acompanhar cada papel; não transformar tamanhos nominais em frames fixos que cortam texto. SF Pro para dinheiro; `FrilaMoney`/`FrilaPriceTag` com VoiceOver por extenso, inclusive unidade.

| FrilaLowPhase | frila-frontend | Correspondência / ausência |
|---|---|---|
| `FrilaGeometry.space2/4/8/12/14/16/24/32` | `FrilaEspaco.fio/minimo/pequeno/compacto/faixa/medio/grande/enorme` | Mesmos passos em pt |
| `space6/10/20/48` | `FrilaGeometry` importada | Sem aliases correspondentes em `FrilaEspaco`; não fingir que 16 = 20 |
| `radiusNested` 8 | `FrilaRaio.pequeno` | Elemento aninhado |
| `radiusInput` 14 | `FrilaRaio.entrada`, `medio` | Campo |
| `radiusCard` 16 | `FrilaRaio.cartao`, `grande`, `aviso` | Cartão/aviso padrão; não conservar 20 do MidFi como Hi-Fi equivalente |
| `radiusSheet` 24 | `FrilaRaio.folha` | Folha |
| `radiusPill` | `Capsule()` | Forma; não um raio arredondado arbitrário |
| `radiusCardEditorial` 28 | `FrilaGeometry` importada | Sem alias dedicado em `FrilaRaio`; variante editorial, não raio universal |
| `buttonHeightCompact/Standard/Prominent` 32/44/52 | `alturaDoChip` 32; `alturaDoCampo` 52 | Não há alias de altura padrão 44; `alvoMinimo` 44 é hitbox, outro papel |
| `hitboxMinimum` 44 | `FrilaMetrica.alvoMinimo` | Área mínima 44 × 44 |
| `concentricInnerRadius/OuterRadius` | Mesmas funções em `FrilaGeometry` | Relação calculada; valores de raios isolados não garantem concentricidade |
| Sem papel homônimo confirmado | `circuloDeEstado` 72, `larguraMaximaDeLeitura` 680 | Convenções locais do frontend; não atribuídas à fonte Hi-Fi |

## 5. Componentes, variantes e estados

`DS/Componentes.swift` contém wrappers do app. `DS/Componentes/` contém componentes importados. Wrapper semelhante, arquivo presente e tela convertida são três afirmações diferentes; só as duas primeiras cabem neste mapa documental.

| Família da fonte | Correspondência / lacuna atual | Anatomia de referência |
|---|---|---|
| Pílulas (`FrilaPillButtonStyle`, variantes de botão) | `BotaoPrimario`, `BotaoSecundario`, estilos táteis e componentes importados | Forma/label estáveis; primário preenchido, secundário de contorno, compacto com hitbox compensada |
| Filtros, chips, seleção | `FiltroPill`, seletores importados | Estado com texto/símbolo, wash de escolha separado da confirmação; chip passivo não finge ação |
| Cartões de oportunidade/turno | `CartaoVaga`, `.cartaoFrila()` e peças importadas | Entidade/função, condições resolvidas, preço e metadados em hierarquia; zero-shadow conforme G2 e Q3=A |
| Formulário e roletas | `CampoFrila`, `FrilaCoupledRolePicker`, `FrilaExperienceLevelPicker`, contêiner morphing | Rótulo externo, campo com superfície/borda, expansão inline, erro próximo e escolha recolhida |
| Toque fora/teclado | Modificadores importados em `DS/Componentes/` | Reuso da arbitragem de gestos; não camada por tela que bloqueie scroll |
| Dinheiro e ação persistente | `FrilaPriceTag`, `FrilaProposalBar` importados | Valor legível, unidade e ação; preservar o contrato financeiro real, sem taxas fictícias |
| Folhas, vidro, feedback | `FolhaFrila`, `.vidroFrila()`, `FrilaToast` e efeitos importados | Materiais nativos, fechamento explícito, acessibilidade e feedback que não apaga o conteúdo real |
| Histograma/perfil curatorial | `FrilaBudgetHistogram` e `FrilaCreatorProfileHero` sem arquivo correspondente no módulo central inventariado | Referências de composição; não são funcionalidades aprovadas para o app |
| Fluxos completos de turno da fonte | `DS/Turnos/` não contém todos os hosts/views da fonte | Tokens/modelos importados não equivalem a `FrilaShiftFlowView`, `FrilaShiftFeedView` ou formulário/folha completa |

A matriz V tem cinco eixos de exploração. Exemplo de nomes reais, sem selecionar vencedor:

| Família | Estrutura A | Tipo B | Densidade C | Interação D | Expressão E |
|---|---|---|---|---|---|
| OpportunityCard | Quiet Gallery | Curatorial Placard | Dense Marketplace | Tactile Stage | Liquid Glass Vitrine |
| Busca progressiva | Monolithic Whisper | Lexicon Index | Matrix Command Bar | Elastic Capsule | Refractive Lens |
| Histograma | Horizon Density | Valuation Ledger | Quant Matrix | Magnetic Dual-Pill | Luminous Prism |
| Botões | Achromatic Line | Placard Press Stamp | High-Throughput Suite | Haptic Spring Pill | Specular Glass Pill |
| Barra de proposta | Subterranean Ledger | Commitment Dock | Dynamic Breakdown | Spring-Dock Expansion | Floating Glass Dock |
| Perfil curatorial | White Monograph | Retrospective Catalog | Talent Terminal | Parallax Stage | Luminous Atelier |

Cada variante continua sujeita aos guardrails. Descrições históricas de altura 36, pressão 0,97, fontes rounded, grades ordinais ou execução web não revogam G1/G6, M9 ou as molas de R §3.5. Variante editorial não autoriza conteúdo financeiro/produto dos exemplos.

Estados a especificar por componente: repouso, pressionado, foco, desabilitado, escolhido, confirmado, carregando, vazio e erro, quando aplicáveis. Nome acessível permanece durante loading; foco visível e navegação acessível; feedback não depende só de cor. Campo ativo e campo confirmado não se confundem. No aguardo de uma escolha acoplada, manter o texto real; não substituí-lo por skeleton.

## 6. M1–M21: régua mobile condensada

Fonte R §3.3. Os IDs permitem ao levantamento de estado apontar a regra sem decretar aprovação de conversão.

| ID | Exigência verificável |
|---|---|
| M1 | Ação customizada não é palavra solta: pílula rotulada, secundária de contorno. |
| M2 | Commit não fica escondido em ícone dentro do campo; botão rotulado e retorno do teclado também confirmam. Desabilitado mantém forma e rótulo. |
| M3 | Nenhum ícone inicial decorativo em campo; só ícone que acrescente informação ou ação real. |
| M4 | Campo com superfície, borda, raio concêntrico e foco reconhecível; não só cursor sobre fundo nu. |
| M5 | Grupo compacto, largura útil e ritmo de 12 pt; pares com alturas/larguras coerentes, sem controles perdidos em espaço morto. |
| M6 | Significado não depende de hover/tooltip; navegação primária não se esconde em links no corpo do texto. |
| M7 | Assentar roleta/digitar é exploração. Avanço só em commit explícito; nenhum salto automático de foco/scroll. |
| M8 | Label acima, dica/erro logo abaixo; expansão inline ou folha para entrada simples. Placeholder não é o único rótulo. |
| M9 | Escala ordinal em linhas completas, ordenadas verticalmente, com nome e descrição; não grade de chips. |
| M10 | Campo/linha confirmados não usam wash de chip da marca; borda de acento ou sólido semântico. Wash cinza de lista aberta é outro estado. |
| M11 | Não repetir o mesmo glifo com quantidades crescentes para fingir hierarquia; ordem e copy a explicam. |
| M12 | Escolhas começam recolhidas. Uma camada cinza desliza sob as linhas; toque ou soltar do slide confirma e recolhe na mesma transação, sem timer/segundo aceite. Pressão de cerca de 0,15 s inicia slide, ticks por linha, cancelar não escolhe, swipe rápido rola. Peso muda com crossfade 0,3 s e blur 0,6 pt, conforme Q4=B. |
| M13 | Fechado: chevron dentro do campo. Aberto: label da seção fecha, com chevron para cima e feedback sutil. Header mantém 44 pt; não acrescentar pílula Concluir redundante. |
| M14 | Label nomeia uma vez; placeholder exemplifica conteúdo, sem repetir o label nem o modo já mostrado. |
| M15 | Mudanças de texto têm transição sem duplicar camadas; instantâneo apenas com Reduzir Movimento. Para peso, usar a primitiva com crossfade 0,3 s e blur 0,6 pt (Q4=B); a indicação antiga de blur 1,5 pt foi superada. |
| M16 | Régua de progresso pertence à tela, não a pequeno cartão transitório; neste, título/ação/campos indicam etapa. |
| M17 | Cartão transitório ancorado embaixo, 24 pt acima do indicador; cresce para cima. Controles recorrentes e confirmar ficam no terço inferior. Margem lateral 20 pt, largura como limite, não frame fixo que estoura. |
| M18 | Mostrar todas as etapas com valor atual/salvo ou “A definir”; toque salva e muda etapa. Reusar camada de seleção. Navegação segmentada é alternativa experimental, não padrão presumido. |
| M19 | Ao retornar de fluxo que preencheu campos, destacar os alterados em cascata e depois o total; borda/check transitórios e um resumo VoiceOver. Não autoavançar foco. |
| M20 | Toque fora de controle inline confirma o valor centrado/escolhido e só fecha: não ativa o controle tocado. Não bloquear rolagem; modificador compartilhado. Modal mantém scrim; VoiceOver tem fechamento explícito. |
| M21 | Toque neutro e drag fecham teclado; toque só fecha, sem ativar outro controle. Campo focado cabe na janela visível com margem; chrome dispensável cede espaço. Medir posição de campo/teclado, não julgar só por aparência. |

## 7. Movimento e feedback

R §3.5 exige reavaliar o movimento contra a referência Hi-Fi a cada refinamento. Surface, borda, raio e clip têm **um dono**; filhos sem chrome duplicado. Altura usa mola, raio tem curva própria e o recorte nunca corta cantos arredondados. Sem lift/zoom de pop-up ancorado em cima.

No destino, `FrilaMovimento` oferece quatro aliases e `animacao(_:reduzir:)`; o conjunto completo de tokens **já existe** em `DS/Primitivas/FrilaMotion.swift`. Ausência de alias português não é ausência da primitiva. Não inventar chamadas `FrilaMovimento.disclosureExpand` como se existissem.

| Token da fonte | Correspondência atual / parâmetro a preservar |
|---|---|
| `pressScaleButton`, `tactileSpring` | `FrilaMovimento.pressScaleBotao` 0,96 e `molaTatil` stiffness 350/damping 25 |
| `pressScaleChip`, `chipPressSpring` | `pressScaleChip` 0,94 e `molaTatilChip` stiffness 380/damping 24 |
| `disclosureExpand` / `disclosureCollapse` | `FrilaMotion` importado: 0,42 s/bounce 0,08; 0,32 s/bounce 0. Sem aliases portugueses específicos |
| `disclosureMorphExpand/Collapse` | Curva 0,32/0,72/0/1; 0,4/0,3 s; separada da mola de altura |
| `disclosureOvershootAllowance`, `disclosureDropOffset` | Folga 3 pt; assentamento para baixo 2,5 pt, sem escala do contêiner |
| `contentFadeOut` / `contentFadeIn` | Saída ease-in 0,09 s; entrada ease-out 0,2 s com atraso 0,07 s. Movimento não usa essa curva de opacidade |
| `coreSwapFadeIn` | Núcleo pesado entra 0,2 s após atraso 0,1 s; slot com altura explícita e largura estável, núcleos em overlays, sem retarget de layout durante saída |
| `selectionSlideHoldDuration`, `selectionWashSlide` | Segurar 0,15 s; wash 0,5 s/bounce 0,12, camada única. Exceção específica ao bounce geral pequeno |
| `selectionTextCrossfade`, `selectionTextCrossfadeBlur` | Transição de peso aprovada em Q4=B: crossfade 0,3 s e blur 0,6 pt, larguras casadas; Reduzir Movimento torna a troca instantânea |
| `confirmCelebrationDelayMs`, `conclusionHold` | 220 ms depois do fechamento; check por 1,2 s. Não são timers de aceitar escolha |
| `shiftCardMorph`, `shiftLandingStaggerMs` | 0,45 s/bounce 0,12; cascata de 80 ms após cartão fechar |
| `hoursHighlightDelayMs/Hold` | 380 ms / 0,9 s; destaque do resultado dependente |
| `outsideTapMaxDuration` | 0,30 s; `FrilaGeometry.outsideTapMaxMovement` 10 pt separa toque de scroll |

Princípios complementares: projeção de roleta até 50°, blur progressivo até 2,4 pt e máscara suave, sem bandas. Pending mantém texto real com fase compartilhada: ciclo 1,5 s, só aparece após espera perceptível de pelo menos 0,15 s, intensidade entra/sai gradualmente. Skeleton genérico não substitui esse padrão específico de texto pendente.

Reduzir Movimento: escala 1, sem mola expansiva, projeção, inclinação ou blur; trocas instantâneas e pending apenas atenuado estático. Toda animação do app passa pela política `FrilaMovimento.animacao(_:reduzir:)`. Opacidade pode usar curvas ease; deslocamento/tamanho usam física específica. Não usar `.default` ou easeInOut genérico para movimento só porque o wrapper aceita.

## 8. Leitura do estado e uso desta régua

- `.cartaoFrila()` atual aplica `.frilaShadow(.subtle)` sobre `FrilaCor.fundo`; é divergente do zero-shadow aprovado em Q3=A. Não declarar conformidade nem alterar o código nesta entrega documental.
- `FrilaTipo.preco` atual é tabular. O papel monetário estático da referência é proporcional; registrar a divergência sem alterar código nesta tarefa.
- `FrilaElevacao`/`FrilaShadow` e `.vidroFrila()` existem; isso não prova anatomia ou uso correto. Vidro nativo iOS 26+ deve ter fallback compatível com o deployment real do app; não copiar shaders de exemplo nem aparência manual sobre controles de sistema.
- O grupo Categoria/Função é uma exceção contextual documentada em R §3.2c: raio externo 26 = campo 14 + padding 12; claro com superfície branca elevada, campos próprios e ring; escuro com degraus tonais e ring, sem sombra. Não espalhar essa elevação pelos cartões do feed.
- Fonte de visual não equivale a adoção dos fluxos do protótipo. A ausência de um componente não autoriza recrutá-lo para produção; alternativas laboratoriais continuam exigindo decisão humana.
- HIFI-02 pode citar esta régua como **referência final aprovada**, identificando regra, arquivo e diferença; a aprovação da régua não aprova conversões. Não usar “convertido/aprovado” por presença de token ou importação de pasta.

## 9. Decisões

Aprovadas pelo usuário em 24/10/2026. As quatro questões estão encerradas, sem perguntas abertas.

- **Q1=A — Marca:** família EA5A36/F26643 aprovada. FF4D17, embora descrito em DESIGN_MERGE_SPEC, permanece proposta não adotada. Validar os pares de contraste por papel, sem transportar razões de outra paleta.
- **Q2=A — Canvas escuro:** `#111111` aprovado, conforme `dynamicCanvas` e `FrilaCor.fundo`. As menções a 090908/0E0D0C como canvas não prevalecem; tinta e superfícies continuam papéis distintos.
- **Q3=A — Cartões:** zero-shadow aprovado. Cartão com `.subtle` é divergente; elevação fica restrita a grupos, folhas e docks explicitamente especificados, sem generalizar a exceção para cartões.
- **Q4=B — Peso do texto:** transição da primitiva aprovada, com larguras casadas, crossfade 0,3 s e blur 0,6 pt. A troca sem animação prescrita em M12 e o blur 1,5 pt citado em M15 ficam superados. Reduzir Movimento mantém troca instantânea.

## 10. Evidência da referência

A régua foi destilada de `FrilaLowPhase@cfe8a64377bb01fc18f70b8fde28d99893db0064`: `RULES.md` §1 e §§3.1–3.5, os documentos de `docs/design-system/` citados na §1 e as primitivas Swift que eles referenciam. A correspondência no app foi conferida em `frila-frontend@4d19e74f3f1c1991f5f15d9807ca6fe161aa631e`, nos arquivos de `iOS/Sources/Apresentacao/DesignSystem/` identificados nas §§3–7. O estado de aplicação é documentado separadamente em [ESTADO.md](ESTADO.md). Esta entrega é documental, sem compilação, testes, captura ou implementação; aprova a régua e as decisões da §9, sem aprovar conversões.

## 11. Regras permanentes de refinamento

Decisões de refinamento visual (LOG-010, LOG-011, LOG-012) aprovadas pelo usuário como regras permanentes de design:

- **Terracota em ação principal e estados ativos:** Decisão aplicada no LOG-011 (piloto): a cor terracota (`FrilaCor.marca`) aplica-se ao CTA principal e a estados ativos (ex.: turno "Em andamento", círculos preenchidos de lotação, pin); monograma, cabeçalho de estabelecimento e contagem futura permanecem neutros (`FrilaCor.texto`, `FrilaCor.textoSecundario`). O LOG-013 define a distribuição e o papel de acento por tela.
- **Escaneabilidade, Gestalt e colunas estreitas:** Proibido o uso de ponto médio ("·") e de divisores artificiais excessivos; a separação visual apoia-se em whitespace e agrupamento de Gestalt. Colunas estreitas empilham verticalmente via `ViewThatFits` sem permitir quebra de palavras ou hifenização indevida. Proibida compensação óptica arbitrária baseada apenas em posição.
- **Lista longa e rolagem:** A lista longa adota rolagem livre mantendo amostra de metade do próximo item visível como affordance de continuidade; fade suave nas margens superior e inferior; sombra neutra em camadas sob "Ver tudo (N)"; indicador de rolagem com recuo vertical das bordas (`.contentMargins(.vertical, ..., for: .scrollIndicators)`) para não colidir com o raio dos cantos. Rolagem aninhada preserva o comportamento e a inércia nativos.
- **Tratamento de dado ausente:** Dado ausente é omitido, sem texto genérico de ausência e sem dado inventado (a palavra "Nenhum" não é proibida como termo legítimo de domínio ou cópia intencional).
- **Centralização de movimento:** Toda animação no aplicativo passa pela política central `FrilaMovimento.animacao(_:reduzir:)`; o uso de `withAnimation` é permitido quando envolver `FrilaMovimento.animacao`. Curvas adicionais são permitidas desde que respeitem as primitivas e tokens do design system.

> **Ressalva de escopo e generalização:** Regras validadas em uma tela piloto não devem ser generalizadas presumidamente para outras superfícies sem validação humana; o **LOG-013** define formalmente o papel da cor de marca e do acento por tela.
