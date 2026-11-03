# Design system iOS

O módulo `FrilaApresentacao` concentra tokens e componentes SwiftUI em `Sources/Apresentacao/DesignSystem/`.
Desde o Hi-Fi (Fase 2, 24/10/2026) o design system do app é o do FrilaLowPhase, numa camada só e sem prefixo:
os tipos da origem mantêm os nomes canônicos (`FrilaColor`, `FrilaTypography`, `FrilaGeometry`, `FrilaMotion`,
`FrilaShadow`, `FrilaButton`, `FrilaFilterChip`…) e os tokens antigos do app (`FrilaCor`, `FrilaTipo`,
`FrilaRaio`, `FrilaMovimento`) mantêm os nomes com os valores da origem. Os documentos de design do Fabrício
ficam em `Docs/Enxertos/FrilaLowPhase/` (`DESIGN.md`, `REGRAS-DE-DESIGN.md`, `design-system/`).

## Onde mora

- `DesignSystem/DesignTokens.swift`: `FrilaCor` (xcassets), `FrilaEspaco`, `FrilaRaio`, `FrilaMetrica`, `FrilaTipo`,
  `FontesFrila`, `FrilaMovimento`, `FrilaElevacao`, `FrilaMoney.spoken`, `cartaoFrila()`, `elevacaoFrila`, `vidroFrila`.
- `DesignSystem/Primitivas/`: a origem. `FrilaColor` (escala OKLCH da marca e funções `dynamic…(isDark:)`),
  `FrilaTypography` e `FrilaFormType` (papéis, `FrilaTypeSpec`, escala 11/13/15/18/22/26/32), `FrilaGeometry`
  (raios, alturas 32/44/52, espaços), `FrilaMotion` (molas), `FrilaShadow`, vidro, desfoque, esqueleto e a
  formatação de dinheiro (`FrilaMoney.total/rate/estimate`).
- `DesignSystem/Componentes/`: componentes da origem (`FrilaButton`, `FrilaFilterChip`, `FrilaStatusChip`,
  roletas, seções de formulário, prévia, toast…) e os do app em `Componentes.swift` (`BotaoPrimario`,
  `BotaoSecundario`, `CampoFrila`, `CampoCodigo`, `FiltroPill`, `SeloReputacao`, `AvisoFrila`, `CartaoVaga`,
  `RespostaSimNao`, `FolhaFrila`). `EstadosDeTela.swift` cobre carregando, vazio, erro, offline e pendente
  ([PadroesDeEstado.md](PadroesDeEstado.md)).
- `DesignSystem/Turnos/`: modelos e tokens de turno. `DesignSystem/Recursos/Estudio.xcstrings`: textos do Estúdio.
- `Resources/DesignSystem.xcassets`: 18 cores com variante clara/escura. `Resources/Fonts`: Bricolage Grotesque
  Regular, Medium, Bold e ExtraBold (OFL 1.1; `Docs/LicencasDeTerceiros.md` 4.1).
- `CatalogoDesignSystem` (Debug): paleta, tipografia, botões e chips do Estúdio, componentes do app, estados,
  folha e licenças.

## Tokens

- Cor (`FrilaCor` ↔ `FrilaColor`): cada token do xcassets é o mesmo RGB de uma função da origem;
  `ParidadeDeCoresDesignTests` prova a igualdade. `fundo` = `dynamicCanvas` (#FFFFFF / #111111);
  `superficie` = `dynamicFormCardSurface` (#FAFAFA / #171717); `superficieDoCampo` = `dynamicFormFieldSurface`;
  `controle` = `dynamicInputBg`; `texto` = `dynamicTextPrimary` (#1B1A18 / #F5F4F0);
  `textoSecundario` = `dynamicFormTextMuted` (#6B6B6B / #A3A3A3); `primaria` = `dynamicTextInk`
  (#090908 / #FFFFFF) com `sobrePrimaria` = `dynamicCanvas`; `selecao` = `primarySelection` (#C9470F) com
  `sobreSelecao` branco; `marca` = `dynamicBrandAccent` (#EA5A36 / #F26643); `sucesso` = `dynamicVerified`;
  `alerta` = `dynamicWarningText`; `perigo` = `dynamicError`; `divisoria` = `dynamicHairline`;
  `borda` = `dynamicBorder`; `bordaDoCampo` = `dynamicFormFieldBorder`; `puxador` decorativo.
- Espaçamento (`FrilaEspaco`): 2, 4, 8, 12, 14, 16, 24 e 32 pt (`FrilaGeometry.space…`).
- Raios (`FrilaRaio` ↔ `FrilaGeometry`): 8 aninhado, 14 campo (`entrada`), 16 cartão e aviso (`cartao`),
  24 folha. Botões, chips e pílulas são sempre `Capsule` (G6), com 32/44/52 pt de altura.
- Alvo interativo mínimo: 44 × 44 pt (`FrilaMetrica.alvoMinimo`, `FrilaGeometry.hitboxMinimum`).
- Tipografia (`FrilaTipo` ↔ `FrilaTypography`/`FrilaFormType`): SF Pro pelos estilos semânticos, com Dynamic Type.
  Bricolage Grotesque só nas perguntas e respostas dos formulários (`pergunta`, `respostaEscolhida`,
  `contextoDaResposta`); números e dinheiro sempre em SF Pro (`FrilaTypography.metric`). Rótulo do botão
  grande: SF Pro Bold 18 (`botao`); padrão e chips: Semibold 15 (`botaoPadrao`).
- Movimento (`FrilaMovimento` ↔ `FrilaMotion`): compressão 0,96 (botão) e 0,94 (chip), molas 350/25 e 380/24;
  tudo passa por `FrilaMovimento.animacao(_:reduzir:)` (Reduzir Movimento).
- Elevação (`FrilaElevacao`): zero-shadow nos cartões com fio de 1 pt; três camadas (rim, key, ambient) em
  folhas e docas.
- Moeda: `FrilaMoney.spoken` para VoiceOver; `FrilaMoney.total/rate/estimate` para o visual (pt-BR fixo).

## Regras herdadas da origem

`Docs/Enxertos/FrilaLowPhase/REGRAS-DE-DESIGN.md`: zero emojis na UI (G3), pílulas 100% redondas (G6), alvo
mínimo 44 pt (G8), nenhum texto solto como botão (M1), controle expandido fecha com toque fora (M20).

## Antipadrões

Decididos pelo Fabrício (02/11/2026). Valem para qualquer tela nova e para revisão de código. **O accent strip e o ponto médio ("dot segment") são marcas de design genérico de IA**: o Fabrício os ratificou antecipadamente, então nunca proponha, copie de uma referência nem implemente nenhum dos dois, em nenhuma tela ou estado.

- **Accent strip:** nenhum filete vertical colorido ao lado de texto, cartão ou linha para marcar ênfase, estado ou próximo passo. Ênfase vem de tipografia, posição, preenchimento ou do próprio componente.
- **Ponto médio entre rótulos ("dot segment"):** nunca separar rótulos ou palavras com "·", marcador ou travessão artificial; use linha própria, gramática comum ou espaço.
- **Chips de hora pré-definidos:** nenhuma fileira ou grade de botões de hora ("18:00", "18:30"...) para escolher um horário. A hora se escolhe na roleta, personalizada, com segmentos de início e fim e uma seta que avança. Banido pelo Fabrício em 03/11/2026, depois do teste no aparelho. Chips seguem válidos para filtros e categorias.
- **Menu flutuante nativo (`Menu`, `Picker` em menu) em tela de alta fidelidade:** não usar nem propor. Banido na tela "Funções e horários" pelo Fabrício em 02/11/2026, nesta fase de alta fidelidade; a escolha vira controle desenhado no próprio fluxo. Usos antigos em outras telas não foram tocados e viram correção quando a tela for refeita.
- **Estado inicial que repreende:** uma tela vazia no primeiro passo convida ("Escolher funções"), não anuncia ausência ("Nenhuma função selecionada"). O erro só aparece depois da tentativa.

## Alinhamento de formulário

Duas bordas, sem exceção (tela "Funções e horários", 02/11/2026):

- **Borda externa, 16 pt da tela:** título, rótulos de seção, textos de ajuda e a borda de todo contêiner.
- **Borda interna, 16 pt de dentro do contêiner (32 pt da tela):** todo texto e ícone dentro de cartão, campo ou botão. Quando um filho é recuado (campo de busca dentro de cartão, linha com realce), o recuo do filho mais o interno dele soma os mesmos 16 pt (`FrilaSearchBar(recuoInicial:)`).
- Rótulo de seção não leva `padding(.horizontal)` extra: ele já está dentro da margem da tela.
- Espaço agrupa: 4 pt entre campo e ajuda, 8 pt entre rótulo e controle, 24 pt entre seções (pelo menos 2x o espaço de dentro do grupo).
- Texto de apoio fixo na tela fica a uma frase curta. O que explica a regra do produto vai atrás de um botão de informação, não em parágrafo.

## Horários da semana (tela "Funções e horários")

Componentes: `FrilaWeekStrip` (faixa fixa de sete dias, não é calendário corrido), `FrilaLensSegments` (segmentos Início e Fim com o valor vivo e uma cápsula que desliza) e `SecaoDeHorarios` (a composição). O desenho segue o contrato do fluxo de turno da publicação de vaga (`FrilaJobShiftFlowCard`):

- **Uma etapa por vez, um controle só:** a roleta nativa (`Picker(.wheel)`) com a tipografia tabular do Estúdio, em passos de 30 minutos. Um horário salvo fora do passo (18:15) continua na roleta, no lugar certo.
- **O cursor dos segmentos também se arrasta com o dedo**, com o movimento da rail de copiar contato, refinado: viajando (por toque ou por arrasto), ele vira uma lente de vidro (cresce 28 por 14 pt além da trilha, o preenchimento cai para 40% e entra o vidro nativo `glassEffect` clear com véu de 10%). O corpo tem duas bordas que animam em molas diferentes: a da frente chega em 0,26 s e a de trás em 0,36 s com 25 ms de atraso, então a bolha se alonga na viagem e se recolhe ao chegar. Os bounces são de no máximo 0,10 (a mola dá a affordance de que algo assentou, não é efeito de brinquedo). **Tensão na margem:** arrastar além do primeiro ou do último segmento estica a bolha com resistência crescente (no máximo 12% de um segmento, para caber no cartão) e ela afina 10% na altura; soltar devolve com um elástico firme. **Dois hápticos:** um pulso rígido (0,45) quando o cursor vira de lado (na metade do arrasto, ou no toque) e um toque suave (0,55) quando a lente assenta, 0,14 s depois de chegar. **Zona medial:** o cursor só vira de lado depois de passar de 65% do caminho (e só volta ao passar de 35%), uma histerese de 30% do segmento medida a partir do segmento em vigor; um empurrão curto não troca. Soltar escolhe o segmento em vigor. **Toque simples:** uma trajetória única de 440 ms (`TrajetoriaDoToque`), desenhada à mão e renderizada por relógio (`TimelineView`), sem mola nem `delay`, com a curva quíntica Q(u) = 6u⁵ − 15u⁴ + 10u³ em cada trecho (velocidade e aceleração zero nas junções). Parte das bordas apresentadas, então um toque no meio da viagem continua de onde o cursor está. **Transporte:** a borda da frente chega ao destino aos 220 ms e a de trás aos 240 ms (alongamento curto de viagem, sem oscilação própria). **Reação à inércia, fixa:** o corpo do cursor (as duas bordas juntas, fio incluso) passa 2 pt do destino aos 220 ms, recua 0,75 pt aos 310 ms e assenta aos 440 ms. Os rótulos Início e Fim ficam parados: rótulos que tremem dessincronizam a leitura (teste no aparelho, 03/11/2026). A reação começa aos 160 ms, nos últimos 60 ms do transporte, para não parecer uma segunda ação depois da chegada. Largura e altura não mudam; a trilha e o cartão ficam parados, porque a trilha parada é a referência que faz o movimento ler como inércia (o contraste do cursor em relação à trilha torna o deslocamento perceptível sem mexer no resto). O orçamento é o recuo de 4 pt da trilha: fio de 1 pt, excesso de 2 pt e 1 pt livre, então o cursor nunca passa das margens da trilha. A bolha do vão (centro nominal atravessando o vão, 0 sobre uma célula e 1 no meio, +8 por 5 pt) fecha em 160 ms e não renasce. **Sem vidro e sem véu no toque:** o preenchimento fica em 100%; o vidro claro subindo sobre os rótulos era a origem do flash branco (confirmado no aparelho). O vidro nativo (`glassEffect`) fica só no arraste. O háptico de assentamento toca aos 220 ms. Decisão: planejamento e revisão cruzada dos dois Codex (candidato 1 do ranking, cursor inteiro com paralaxe de rótulos e fundo fixo) em `frila-orquestra/briefs/conta-profissional/horarios/`, 03/11/2026. **Soltar depois de arrastar:** a lente assenta e a bolha comprime a 97% em escala proporcional (nos dois eixos, 110 ms) e volta numa mola macia (0,46 s, bounce 0,25, dentro do 0,1 a 0,3 que se aceita em UI), passando de leve de 100%; um háptico leve (0,35) toca quando ela começa a voltar. Press e arrasto mantêm o movimento completo. O toque que o botão dispara colado no fim de um arraste é ignorado. As cores são as do cursor de sempre. Tokens `FrilaMotion.segmento*`.
- **A roleta de Início e Fim são duas páginas de uma janela horizontal (`FrilaPaginasHorizontais`).** Trocar de etapa desliza o conjunto inteiro a distância da janela, em sentido oposto ao do cursor: de Início para Fim a roleta nova vem da direita e a antiga sai pela esquerda, como se a escolha viesse de outra seção, e o contrário de Fim para Início. A janela recorta o que passa e esmaece as pontas com uma máscara progressiva (degradê de opacidade que vive só na margem de 16 pt, no respiro do cartão), então a roleta em repouso aparece inteira e a entrada nasce na borda do cartão, sem corte seco. Mola de 0,34 s com bounce 0,05 (`FrilaMotion.paginasHorizontais`): a distância longa pede mais tempo que os 0,28 s do "Copiado" da tela de Conta, de onde veio a ideia (a primeira versão copiava o offset de 20 pt e o desfoque de lá e passava rápido demais, parecendo um erro de alinhamento). O componente é genérico (quantidade, índice atual, margem e uma página por índice) e serve para qualquer conteúdo de mesma altura. Páginas inativas não recebem toque nem entram na acessibilidade; com movimento reduzido, só a opacidade.
- **A seta avança e vira o visto:** a seta Quente leva do Início ao Fim e, no Fim, concluir grava. Tocar num segmento salta para a etapa. "Cancelar" fecha sem gravar.
- **Nada entra antes do visto:** a roleta abre em 18:00 e o fim sugerido é seis horas depois, mas isso é só o ponto de partida. Nenhum valor entra em `disponibilidades` até o "Concluir", e o salvar da tela avisa se há um horário aberto no editor. Editar um horário salvo troca por `substituirJanela`, que valida a nova janela antes de tirar a antiga.
- **Repouso:** domingo selecionado e uma linha "Escolher horário" com seta. Dia vazio abre o editor no Início; dia com horário só destaca (o nome do dia fica em texto principal). Segundo horário no dia: "Adicionar horário".
- **Fim antes do início** atravessa a meia-noite; o editor mostra "Termina no dia seguinte" e a linha salva traz a nota "dia seguinte".
- **Cor:** o dia selecionado tem contorno de 2 pt por dentro no Quente (o mesmo do botão "Escolher funções"); o dia com horário tem fundo neutro do campo. Nenhum tom alaranjado esmaecido em contêiner.
- **Movimento** (`FrilaMotion.horario*`): o contêiner cresce em 240 ms, a linha nasce em 180 ms com 40 ms de atraso, o destaque leva 160 ms e a remoção 200 ms, com curva ease-out forte. Ao abrir o editor, a tela rola até o rodapé dele para o botão fixo não o cobrir.

## Decisões da Fase 2

- Botão principal e pílula neutra ativa continuam na tinta (`.ink` da origem), não na terracota viva: o rótulo
  em 15 pt sobre #EA5A36 fica em 3,5:1, abaixo do AA para texto normal. A terracota viva é acento e botão de
  destaque do Estúdio (texto grande, 18 pt bold). Filtro ativo e escolha confirmada usam a terracota de seleção
  (#C9470F, 4,8:1 com branco).
- `TextSecondary` é o `dynamicFormTextMuted` (#6B6B6B), não o `dynamicTextMuted` (#767571, 4,4:1 sobre o cartão).

> A especificação exaustiva de cada token gerada de `DesignTokens.swift` (cartão Trello `iUIipiiN`) está em
> [GuiaDoFabricio.md (Seção 5.1.1)](GuiaDoFabricio.md#511-tabela-canônica-de-todos-os-tokens-do-app-designtokensswift--cartão-iuiipiin).

---

## Tabela canônica de contraste WCAG 2.1 AA

Valores calculados pela fórmula do W3C (1.4.3 texto, 1.4.11 componentes) a partir de `DesignSystem.xcassets`,
na Fase 2 do Hi-Fi (24/10/2026). `ContrasteDesignTokensTests` recalcula a cada execução.

| Par (frente sobre fundo) | Uso | Requisito | Claro | Situação | Escuro | Situação |
|---|---|---|:---:|:---:|:---:|:---:|
| `TextPrimary` sobre `Surface` | Títulos e textos sobre a tela | Texto normal (≥ 4,5:1) | 17,39:1 | Aprovado | 17,16:1 | Aprovado |
| `TextPrimary` sobre `SurfaceElevated` | Títulos de cartões e folhas | Texto normal (≥ 4,5:1) | 16,66:1 | Aprovado | 16,29:1 | Aprovado |
| `TextPrimary` sobre `ControlFill` | Texto em `AvisoFrila` e pílulas neutras | Texto normal (≥ 4,5:1) | 15,51:1 | Aprovado | 14,45:1 | Aprovado |
| `TextPrimary` sobre `FieldSurface` | Valor digitado nos campos | Texto normal (≥ 4,5:1) | 15,95:1 | Aprovado | 15,48:1 | Aprovado |
| `TextSecondary` sobre `Surface` | Apoio e metadados sobre a tela | Texto normal (≥ 4,5:1) | 5,33:1 | Aprovado | 7,49:1 | Aprovado |
| `TextSecondary` sobre `SurfaceElevated` | Apoio em cartões, placeholders | Texto normal (≥ 4,5:1) | 5,11:1 | Aprovado | 7,11:1 | Aprovado |
| `TextSecondary` sobre `ControlFill` | Metadados em chips neutros | Texto normal (≥ 4,5:1) | 4,75:1 | Aprovado | 6,31:1 | Aprovado |
| `TextSecondary` sobre `FieldSurface` | Placeholder e apoio nos campos | Texto normal (≥ 4,5:1) | 4,89:1 | Aprovado | 6,76:1 | Aprovado |
| `BrandOnPrimary` sobre `BrandPrimary` | Rótulo do `BotaoPrimario` | Texto normal (≥ 4,5:1) | 19,92:1 | Aprovado | 18,88:1 | Aprovado |
| `BrandOnPrimary` sobre `Danger` | Exclusão definitiva de conta | Texto normal (≥ 4,5:1) | 5,06:1 | Aprovado | 6,83:1 | Aprovado |
| `BrandPrimary` sobre `Surface` | Ações de texto sobre a tela | Texto normal (≥ 4,5:1) | 19,92:1 | Aprovado | 18,88:1 | Aprovado |
| `BrandPrimary` sobre `SurfaceElevated` | Ações dentro de cartões | Texto normal (≥ 4,5:1) | 19,09:1 | Aprovado | 17,93:1 | Aprovado |
| `BrandOnSelection` sobre `BrandSelection` | `FiltroPill` ativa, `RespostaSimNao` escolhida | Texto normal (≥ 4,5:1) | 4,78:1 | Aprovado | 4,78:1 | Aprovado |
| `Success` sobre `Surface` | Confirmações sobre a tela | Texto normal (≥ 4,5:1) | 5,48:1 | Aprovado | 10,84:1 | Aprovado |
| `Success` sobre `SurfaceElevated` | Selos de reputação em cartões | Texto normal (≥ 4,5:1) | 5,25:1 | Aprovado | 10,29:1 | Aprovado |
| `Warning` sobre `Surface` | Pendências sobre a tela | Texto normal (≥ 4,5:1) | 5,27:1 | Aprovado | 11,31:1 | Aprovado |
| `Warning` sobre `SurfaceElevated` | Avisos em cartões | Texto normal (≥ 4,5:1) | 5,05:1 | Aprovado | 10,74:1 | Aprovado |
| `Danger` sobre `Surface` | Erros sobre a tela | Texto normal (≥ 4,5:1) | 5,06:1 | Aprovado | 6,83:1 | Aprovado |
| `Danger` sobre `SurfaceElevated` | `capsulaDestrutiva`, erros de campo | Texto normal (≥ 4,5:1) | 4,85:1 | Aprovado | 6,48:1 | Aprovado |
| `BrandAccent` sobre `Surface` | Ícone e marca terracota | Componente / ícone (≥ 3,0:1) | 3,49:1 | Aprovado | 6,08:1 | Aprovado |
| `BrandAccent` sobre `SurfaceElevated` | Acento em cartões | Componente / ícone (≥ 3,0:1) | 3,35:1 | Aprovado | 5,77:1 | Aprovado |
| `BrandOnPrimary` sobre `BrandAccent` | Glifo sobre pílula terracota (`SearchCapsule`, botão `.primary` do Estúdio) | Componente / ícone (≥ 3,0:1) | 3,49:1 | Aprovado | 6,08:1 | Aprovado |
| `FieldBorder` sobre `Surface` | Fio do campo sobre a tela | Componente / ícone (≥ 3,0:1) | 3,36:1 | Aprovado | 3,49:1 | Aprovado |
| `FieldBorder` sobre `SurfaceElevated` | Fio do campo em cartões | Componente / ícone (≥ 3,0:1) | 3,22:1 | Aprovado | 3,31:1 | Aprovado |
| `FieldBorder` sobre `FieldSurface` | Fio contra o preenchimento do campo | Componente / ícone (≥ 3,0:1) | 3,08:1 | Aprovado | 3,15:1 | Aprovado |
| `BrandSelection` sobre `Surface` | Pílula ativa sobre a tela | Componente / ícone (≥ 3,0:1) | 4,78:1 | Aprovado | 3,95:1 | Aprovado |
| `BrandSelection` sobre `SurfaceElevated` | Pílula ativa em cartões | Componente / ícone (≥ 3,0:1) | 4,58:1 | Aprovado | 3,75:1 | Aprovado |
| `SheetGrabber` sobre `SurfaceElevated` | Puxador das folhas | Decorativo (isento, 1.4.11) | 1,48:1 | Isento | 1,99:1 | Isento |

### Exceções e restrições

1. **`BrandAccent` (`FrilaCor.marca`, #EA5A36)**: 3,49:1 sobre `Surface` no claro. Aprovado para ícone, componente
   e texto grande; reprovado para texto corrido. O teste `guardaDeExcecoesERestricoesDeDesign` registra os dois lados.
2. **`SheetGrabber` (`FrilaCor.puxador`)**: decorativo, `.accessibilityHidden(true)` em `FolhaFrila`; isento (1.4.11).
3. **`ControlBorder` e `Hairline`**: fios de 1 pt de cartões e chips inativos, sem exigência de 3:1 porque não
   delimitam sozinhos um controle (o campo usa `FieldBorder`, que passa).

### Cobertura por teste

- `ContrasteDesignTokensTests`: 18 tokens, pares de texto ≥ 4,5:1, componentes ≥ 3,0:1, exceções documentadas.
- `ParidadeDeCoresDesignTests`: cada token do xcassets igual à função correspondente do `FrilaColor`.
- `GuardaTokensDesignTests`: literal de cor ou fonte só em arquivos `*DesignTokens.swift`.
