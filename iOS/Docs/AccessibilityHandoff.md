# Handoff de acessibilidade iOS

Checklist obrigatório para cada fluxo entregue por Design e implementado no iOS:

- Ordem de foco e agrupamentos do VoiceOver definidos no protótipo.
- Nome, valor e dica de cada controle não textual documentados.
- Estados não dependem somente de cor e mantêm contraste WCAG AA.
- Controles têm alvo mínimo de 44 × 44 pt.
- Layout validado até Dynamic Type Accessibility 5 (AX5) sem cortar conteúdo ou ações.
- Movimento não é necessário para entender estado; respeitar Reduzir Movimento.
- Erros são anunciados e associados ao campo correspondente.
- Valores monetários, datas, horários e reputação têm leitura natural em pt-BR.

O catálogo de componentes é o ponto de validação conjunta com Design. Fluxos completos devem ser testados com VoiceOver em aparelho antes do aceite.

A auditoria automática de todas as telas da camada de Apresentação (`AuditoriaDeAcessibilidadeUITests`, tamanho padrão, AX5 e Reduzir Movimento), o inventário tela a tela e o relatório estrutural estão consolidados em [Acessibilidade](Acessibilidade.md).

---

## Tabela consolidada de acessibilidade por tela

O mapeamento de 100% das telas da v1.0 com suas respectivas Views Swift, rotas/fluxos de navegação, cobertura por testes automatizados (`AuditoriaDeAcessibilidadeUITests`), validação em AX5 e alvos de toque mínimos de 44 pt está disponível na [Tabela central de telas da v1.0](Acessibilidade.md#checklist-central-de-telas-da-v10--9-critérios-711--168).

---

## Orientações de leitura de medidas e tokens

Para garantir a fidelidade entre as especificações de design e a implementação acessível no app iOS, adote as seguintes diretrizes de leitura e aplicação:

### 1. Medidas e alvos de toque (Hit Targets)
- **Alvo mínimo interativo:** todo elemento acionável (botões, links, pílulas, cartões clicáveis) deve ter dimensões interativas de no mínimo **44 × 44 pt** (`FrilaMetrica.alvoMinimo`), conforme diretrizes Apple HIG e critérios WCAG 2.5.5 / 2.5.8.
- **Controles visualmente compactos:** ícones de ação, botões de fechar e pílulas de filtro com altura visual inferior a 44 pt devem incluir padding interno expandido ou modificador `.frame(minWidth: 44, minHeight: 44)` para manter a área de toque acessível.
- **Espaçamento sistemático:** utilizar exclusivamente a escala padronizada de espaçamentos em `FrilaEspaco` (`pequeno`, `medio`, `grande`), garantindo margens consistentes que não colapsem sob ampliação de texto.

### 2. Tipografia e Dynamic Type
- **Estilos semânticos:** nunca declarar tamanhos fixos em pontos (`.font(.system(size: ...))` é estritamente proibido). Usar apenas os estilos dinâmicos semânticos do sistema (`.largeTitle`, `.title`, `.title2`, `.title3`, `.headline`, `.subheadline`, `.body`, `.callout`, `.footnote`, `.caption`).
- **Escala até AX5:** o layout deve suportar o maior nível de acessibilidade do sistema (**AX5** / `UICTContentSizeCategoryAccessibilityXXXL`) sem truncamento de texto, sobreposição ou quebra indesejada de fluxos de ação.
- **Adaptação responsiva:**
  - Utilizar `@ScaledMetric` para dimensões que devam acompanhar a escala do texto (ex.: ícones ilustrativos, alturas dinâmicas).
  - Utilizar `ViewThatFits` ou `AnyLayout` para alternar de disposições horizontais (`HStack` ou `Grid`) para verticais (`VStack`) nos tamanhos de acessibilidade.
  - Para itens em barras de ferramentas/navegação que não escalam automaticamente pelo sistema, aplicar `.accessibilityShowsLargeContentViewer()`.

### 3. Tokens de cor e contraste
- **Tokens centralizados:** todas as cores de primeiro plano, fundo, contorno e destaque devem provir de `FrilaCor` (`iOS/Sources/Apresentacao/DesignTokens.swift`). Cores literais (`.red`, `.blue`) ou construtores soltos são proibidos.
- **Contraste mínimo:** manter contraste WCAG AA de **4,5:1** para texto normal e **3,0:1** para texto grande (≥ 18 pt ou negrito ≥ 14 pt) e controles de interface.
- **Indicação não cromática de estado:** a distinção de seleção, sucesso, erro ou alerta não pode depender exclusivamente da cor. Deve ser acompanhada de ícone representativo (SF Symbol com preenchimento distintivo, checkmark), texto explicativo e traço semântico (`.isSelected`).

### 4. VoiceOver e leitura em pt-BR
- **Estrutura e cabeçalhos:** títulos de tela e subtítulos de seções devem possuir o traço de acessibilidade `.accessibilityAddTraits(.isHeader)` para navegação eficiente por rotor.
- **Controles não textuais:** botões com ícones isolados devem receber `accessibilityLabel` claro e `accessibilityHint` orientando o resultado da ação.
- **Formatação natural:** valores monetários ("R$ 120,00"), datas, períodos de turno e pontuações de reputação devem ser apresentados com pontuação e termos que garantam leitura fluida e natural em português do Brasil via `FormatadorFrila`.
- **Agrupamento de informações:** dados correlatos apresentados em linhas ou cartões (como rótulo e valor de contato ou protocolo) devem ser agrupados utilizando `.accessibilityElement(children: .combine)`.
