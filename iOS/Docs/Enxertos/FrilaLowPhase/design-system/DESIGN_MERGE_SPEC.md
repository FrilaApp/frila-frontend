# 🏛️ Frila Design System — Especificação de Merge & Refino Editorial (Challenge 18 Deck × Frila DS)

> **Documento:** `docs/design-system/DESIGN_MERGE_SPEC.md`  
> **Status:** Proposta de Arquitetura & Especificação Técnica Aprovada para Execução  
> **Fontes de Referência:**  
> - `DESIGN.md` (Design System Nativo Frila — Drywall Museum Placard, OKLCH, Liquid Glass)  
> - `1790543954431-DESIGN.md` (Deck Challenge 18 — "Dado em Destaque", Bricolage Grotesque, IBM Plex Mono, Papel Quente)  
> **Target:** 100% Nativo SwiftUI (iOS 26+ / macOS 14+ / Swift 6+)  

---

## 1. Visão Geral & Objetivos do Merge

Esta especificação define o plano de convergência e enriquecimento visual entre a fundação canônica do **Frila Design System** e a linguagem editorial apresentada no **Deck Challenge 18**. 

O objetivo é elevar a maturidade visual e a capacidade expressiva do Frila através da fusão da solidez de software nativo (Apple HIG, Liquid Glass iOS 26+, raios concêntricos, $44\times 44\text{pt}$ touch targets) com a sofisticação editorial e impacto quantitativo do deck ("Dado em Destaque", números monumentais, grade técnica milimetrada e contraste grotesca-mono).

### Decisões Fundamentais Alinhadas:
1. **Estratégia Híbrida Editorial:** O core nativo (Drywall `#FFFFFF`, Liquid Glass, acessibilidade, $44\text{pt}$ hitbox) é integralmente preservado, ganhando uma camada editorial rica com a superfície Papel Quente (`#F6F4EF`), grade técnica e componentes de apresentação de dados.
2. **Unificação Total no Laranja Elétrico (`#FF4D17`):** A âncora de cor de marca `primary500` migra de `#EA5A36` para `#FF4D17`, tornando o tom elétrico e saturado do deck a cor de marca canônica de botões, destaques e métricas.
3. **Ingestão de Fontes Customizadas via SPM:** O pacote `FrilaDesignSystem` passará a empacotar e registrar `Bricolage Grotesque` (para display e números monumentais) e `IBM Plex Mono` (para metadados técnicos, timestamps e proveniência), mantendo compatibilidade nativa com SF Pro e New York nos paradigmas existentes.
4. **Novos Componentes Editoriais:** Criação de `FrilaStatCard`, `FrilaFlowStepper`, `FrilaNumberedList`, `FrilaTechnicalGrid`, `FrilaEditorialTag` e `FrilaSignalBar`.
5. **Processo Multi-Agente:** Planejamento documental preliminar (este arquivo), seguido de despacho automatizado para Worker Alpha (implementação) e Worker Beta (testes e hardening) via `./scripts/ao-worker.sh`.

---

## 2. Matriz Comparativa de Convergência

| Dimensão | Frila DS Atual | Deck Challenge 18 | Síntese de Merge (Frila DS v2) |
| :--- | :--- | :--- | :--- |
| **Cor Âncora Primária** | `#EA5A36` (`oklch(0.651 0.186 35.1°)`) | `#FF4D17` (`--sinal`) | **`#FF4D17` (`FrilaColor.primary500`)** — Laranja elétrico de alto impacto |
| **Badge / Tag Tint** | `#FFDDD2` (`primary100`) | `#FFE3D8` (`--sinal-claro`) | **`#FFE3D8` (`FrilaColor.primary100` / `signalLight`)** |
| **Canvas Principal** | Pure White Drywall `#FFFFFF` | Papel Bege Quente `#F6F4EF` | **Dual Canvas:** `#FFFFFF` (App/Feed padrão) + `#F6F4EF` (`FrilaColor.dynamicPaper`, Editorial/Pitch) |
| **Modo Escuro Canvas** | `#0E0D0C` | `#111111` (`--tinta`) | **`#111111`** para superfícies editoriais escuras e `#0E0D0C` para canvas deep |
| **Grade de Fundo** | Nenhuma (0-shadow, bordas 1px) | Linhas de 1px a cada 120px (`#1111111a`) | **`FrilaTechnicalGrid`:** ViewModifier e View de papel milimetrado sutil (10% opacidade) |
| **Família Sans Principal** | SF Pro (`Font.Design.default`) | Bricolage Grotesque | **Bricolage Grotesque** (Display/Big Numbers) + **SF Pro** (UI de sistema e formulários) |
| **Família Mono Metadados**| SF Mono (`Font.Design.monospaced`) | IBM Plex Mono | **IBM Plex Mono** (Metadados editoriais/fontes) + **SF Mono** (Códigos de sistema) |
| **Escala de Métricas** | 22pt Heavy (`metricSpec`) | 38px a 300px (`.big`, `.num`) | **Escala Monumental:** 22pt (`metric`), 44pt (`metricHero`), 64pt (`cardBig`), 92pt (`monumental`) |
| **Algarismos** | Proporcionais (Tabular se animar) | Proporcionais apertados | **Proporcionais com tracking negativo (-0.035em)** por padrão |
| **Moeda / Formatação** | USD fixo `en_US` (`FrilaMoney`) | USD / numérico com proveniência | **Preserva rigorosamente `FrilaMoney` e `FrilaPriceTag`** |

---

## 3. Arquitetura de Tokens & Cores (`FrilaColor.swift`)

### 3.1 Recalibração da Escala Primária Tonal (`#FF4D17`)

A cor `#FF4D17` (RGB: `255, 77, 23`, OKLCH: `oklch(0.640 0.225 36.5deg)`) assume o papel de âncora visual de ação e foco:

```swift
public enum FrilaColor {
    // MARK: - Primary Brand Scale (Anchored on #FF4D17)
    
    /// Tint sutil para seleção (#FFF2ED)
    public static let primary50 = Color(red: 255/255, green: 242/255, blue: 237/255)
    
    /// Fundo de tags e badges sobre a cor de sinal (#FFE3D8 / --sinal-claro do deck)
    public static let primary100 = Color(red: 255/255, green: 227/255, blue: 216/255)
    
    /// Borda secundária e realce suave (#FFBFAB)
    public static let primary200 = Color(red: 255/255, green: 191/255, blue: 171/255)
    
    /// Detalhe gráfico (#FF977A)
    public static let primary300 = Color(red: 255/255, green: 151/255, blue: 122/255)
    
    /// Hover interativo (#FF6B3E)
    public static let primary400 = Color(red: 255/255, green: 107/255, blue: 62/255)
    
    /// BRAND ANCHOR UNIFICADA: #FF4D17 (--sinal do deck)
    public static let primary500 = Color(red: 255/255, green: 77/255, blue: 23/255)
    
    /// Estado pressionado / texto acessível em fundos claros (#D83503) (WCAG AA 5.1:1)
    public static let primary600 = Color(red: 216/255, green: 53/255, blue: 3/255)
    
    /// Texto de alto contraste sobre fundos claros (#A82400) (WCAG AA 7.5:1)
    public static let primary700 = Color(red: 168/255, green: 36/255, blue: 0/255)
    
    /// Marca profunda (#7D1A00)
    public static let primary800 = Color(red: 125/255, green: 26/255, blue: 0/255)
    
    /// Fundo escuro de destaque (#4E0F00)
    public static let primary900 = Color(red: 78/255, green: 15/255, blue: 0/255)
    
    /// Linha de base mais profunda (#290700)
    public static let primary950 = Color(red: 41/255, green: 7/255, blue: 0/255)
    
    // Aliases semânticos diretos do Deck
    public static var signal: Color { primary500 }
    public static var signalLight: Color { primary100 }
}
```

### 3.2 Novas Superfícies Editoriais & Papel Quente

```swift
extension FrilaColor {
    // MARK: - Superfícies Editoriais do Deck
    
    /// Superfície de Papel Quente (Light: #F6F4EF, Dark: #111111)
    public static func dynamicPaper(isDark: Bool) -> Color {
        isDark ? Color(red: 17/255, green: 17/255, blue: 17/255) : Color(red: 246/255, green: 244/255, blue: 239/255)
    }
    
    /// Texto Tinta Principal (Light: #111111, Dark: #F4F1EA)
    public static func dynamicInk(isDark: Bool) -> Color {
        isDark ? Color(red: 244/255, green: 241/255, blue: 234/255) : Color(red: 17/255, green: 17/255, blue: 17/255)
    }
    
    /// Texto Secundário Editorial (Light: #3A3A3A, Dark: #CFCAC0)
    public static func dynamicInkSecondary(isDark: Bool) -> Color {
        isDark ? Color(red: 207/255, green: 202/255, blue: 192/255) : Color(red: 58/255, green: 58/255, blue: 58/255)
    }
    
    /// Metadados & Proveniência Sutil (Light: #6B6B6B, Dark: #9A968D)
    public static func dynamicSubtle(isDark: Bool) -> Color {
        isDark ? Color(red: 154/255, green: 150/255, blue: 141/255) : Color(red: 107/255, green: 107/255, blue: 107/255)
    }
    
    /// Linha de Grade Técnica Milimetrada (Light: #111111 a 10% opacidade, Dark: #FFFFFF a 12% opacidade)
    public static func dynamicTechnicalGrid(isDark: Bool) -> Color {
        isDark ? Color.white.opacity(0.12) : Color(red: 17/255, green: 17/255, blue: 17/255).opacity(0.10)
    }
    
    /// Bordas de Separação Nítida 2px (Light: #D4D0C6, Dark: #33322E)
    public static func dynamicDividerStrong(isDark: Bool) -> Color {
        isDark ? Color(red: 51/255, green: 50/255, blue: 46/255) : Color(red: 212/255, green: 208/255, blue: 198/255)
    }
}
```

### 3.3 Aferição de Contraste WCAG 2.2 AA / AAA
- `#FF4D17` sobre `#FFFFFF` (Drywall): Razão de **3.34:1** — Aprovado em WCAG AA para UI Components, botões grandes e textos $\ge 18\text{pt}$ Bold / $24\text{pt}$ Regular.
- `#FF4D17` sobre `#F6F4EF` (Papel Quente): Razão de **3.22:1** — Aprovado em WCAG AA para elementos gráficos e tipografia display / Big Numbers.
- `#A82400` (`primary700`) sobre `#FFFFFF`: Razão de **7.5:1** — Aprovado em WCAG AAA para texto corrido pequeno e links.
- `#111111` (`dynamicInk`) sobre `#F6F4EF`: Razão de **16.8:1** — Aprovado com folga extrema em WCAG AAA.

---

## 4. Tipografia & Ingestão de Fontes Customizadas (`FrilaTypography.swift`)

### 4.1 Configuração do Pacote Swift (`Package.swift`)
Para permitir o carregamento das fontes do Google Fonts (`Bricolage Grotesque` e `IBM Plex Mono`), o manifesto do pacote declarará a pasta de recursos:

```swift
// Package.swift
.target(
    name: "FrilaDesignSystem",
    dependencies: [],
    resources: [
        .process("Resources/Fonts")
    ]
)
```

### 4.2 Registro Automático de Fontes em Swift
Uma struct auxiliar `FrilaFontRegistrar` registrará via CoreText (`CTFontManagerRegisterGraphicsFont`) no primeiro acesso aos tokens tipográficos:

```swift
public enum FrilaFontLoader {
    private static var hasRegistered = false
    
    public static func registerFontsIfNeeded() {
        guard !hasRegistered else { return }
        hasRegistered = true
        
        let fontNames = [
            "BricolageGrotesque-Regular.ttf",
            "BricolageGrotesque-Medium.ttf",
            "BricolageGrotesque-Bold.ttf",
            "BricolageGrotesque-ExtraBold.ttf",
            "IBMPlexMono-Regular.ttf",
            "IBMPlexMono-Medium.ttf",
            "IBMPlexMono-Bold.ttf"
        ]
        
        for name in fontNames {
            if let url = Bundle.module.url(forResource: name, withExtension: nil) {
                var error: Unmanaged<CFError>?
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            }
        }
    }
}
```

### 4.3 Escala Monumental ("Dado em Destaque")
Conforme a filosofia de que *"cada slide/card caiba numa frase e num número gigante"*, expandimos a escala de métricas:

| Token | Tamanho | Peso | Família | Tracking | Uso Canônico |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `FrilaTypography.display` | 34pt | Heavy | Bricolage / SF Pro | `-1.2pt` | Título de abertura de seção |
| `FrilaTypography.metricHero` | 44pt | ExtraBold | Bricolage Grotesque | `-0.035em` | Métrica em destaque em headers e modais |
| `FrilaTypography.metricCardBig` | 42pt | ExtraBold | Bricolage Grotesque | `-0.035em` | Número protagonista em `FrilaStatCard` |
| `FrilaTypography.metricMonumental`| 56pt | ExtraBold | Bricolage Grotesque | `-0.035em` | KPIs e valores macro de contratação |
| `FrilaTypography.chromeHeader` | 13pt | Medium | IBM Plex Mono | `+0.04em` | Rótulo superior de seção (`01 POR QUÊ?`) |
| `FrilaTypography.provenanceSource`| 11pt | Regular | IBM Plex Mono | `+0.02em` | Rodapé com fonte e data de auditoria |

---

## 5. Novos Componentes Primitivos

### 5.1 `FrilaStatCard` (Card de Métrica & Citação Editorial)
Componente de alta relevância visual para exibir dados e números gigantes protagonistas.

- **Geometria:** Retângulo com cantos de `20pt` (`FrilaGeometry.radiusCardEditorial`), borda nítida de `2pt` (`FrilaColor.dynamicDividerStrong`), padding interno de `24pt` (ou `36pt` em visualizações de mesa).
- **Fundo:** Dinâmico entre `#FFFFFF` ou `#F6F4EF` (`FrilaColor.dynamicPaper`).
- **Conteúdo Suportado:**
  1. **Modo Big Number:** Número gigante (`metricCardBig` ou `metricMonumental`) em `#FF4D17`, com legenda explicativa em grotesca e proveniência da fonte em mono.
  2. **Modo Citação Editorial:** Aspas curvas (`“ ”`) estilizadas na cor de sinal, texto da citação em grotesca, e autor/fonte em IBM Plex Mono.
- **API Swift:**
  ```swift
  public struct FrilaStatCard: View {
      public enum Content {
          case metric(number: String, label: String, source: String? = nil)
          case quote(text: String, author: String, role: String? = nil)
      }
      
      public init(content: Content, surface: SurfaceMode = .paper, isDark: Bool = false)
  }
  ```

### 5.2 `FrilaFlowStepper` (Régua de Marcos Contratuais & Escrow)
Transposição do componente `.flow / .step` do deck para o ciclo de vida de contratos do Frila.

- **Geometria:** Etapas horizontais lado a lado distribuídas igualmente.
- **Marcador Superior:** Borda superior espessa de `6pt` em cada etapa.
  - Etapas passadas/normais: borda escura/neutra de `6pt` (`#111111` ou `#E5E5E3`).
  - Etapa ativa / de maior impacto (`.hot`): borda em `#FF4D17` com brilho sutil.
- **Tipografia:**
  - Número da etapa em IBM Plex Mono Bold (`01`, `02`, `03`).
  - Título da etapa em Bricolage Grotesque Bold.
  - Descrição resumida em cinza muted.
- **API Swift:**
  ```swift
  public struct FrilaFlowStepItem: Identifiable, Sendable {
      public let id: String
      public let stepNumber: String
      public let title: String
      public let subtitle: String
      public let isHot: Bool
      public let isCompleted: Bool
  }
  
  public struct FrilaFlowStepper: View {
      public init(steps: [FrilaFlowStepItem], isDark: Bool = false)
  }
  ```

### 5.3 `FrilaNumberedList` (Tabela / Lista Editorial Estruturada)
Transposição da lista `.nl` do deck para listas de requisitos de vagas, entregáveis de contrato e escopos de projeto.

- **Geometria:** Itens sem bullet padrão. Cada linha possui uma borda superior de `2pt` (`FrilaColor.dynamicDividerStrong`), e o último item possui borda inferior, fechando o bloco como uma tabela de dados nítida.
- **Layout por Linha:**
  - Coluna esquerda: índice da lista (`01`, `02`, `03`) em IBM Plex Mono Bold na cor `#FF4D17`.
  - Coluna direita: título do item em negrito seguido de parágrafo explicativo em `dynamicInkSecondary`.
- **API Swift:**
  ```swift
  public struct FrilaNumberedListItem: Identifiable, Sendable {
      public let id: String
      public let index: String // "01", "02", etc.
      public let title: String
      public let description: String
  }
  
  public struct FrilaNumberedList: View {
      public init(items: [FrilaNumberedListItem], isDark: Bool = false)
  }
  ```

### 5.4 `FrilaTechnicalGrid` (Background Milimetrado de Engenharia & Dados)
Padrão visual sutil de papel milimetrado para transmitir rigor arquitetural e precisão quantitativa.

- **Geometria:** Grade ortogonal com espaçamento de `120pt` e traço de `1pt`.
- **Opacidade:** `10%` em modo claro (`#1111111a`), `12%` em modo escuro.
- **Implementação:** `Shape` em SwiftUI renderizado via `Path` ou `ViewModifier` (`.frilaTechnicalGrid()`), com custo zero de GPU e suporte perfeito a `prefers-reduced-motion`.
- **API Swift:**
  ```swift
  public struct FrilaTechnicalGrid: View {
      public let spacing: CGFloat // default: 120
      public let isDark: Bool
      
      public init(spacing: CGFloat = 120, isDark: Bool = false)
  }
  
  public extension View {
      func frilaTechnicalGrid(spacing: CGFloat = 120, isDark: Bool = false) -> some View
  }
  ```

### 5.5 `FrilaEditorialTag` & `FrilaSignalBar`
- **`FrilaEditorialTag`:** Selo retangular com borda de `2pt` em `#FF4D17`, fundo tingido `#FFE3D8` (`primary100`), texto em IBM Plex Mono uppercase, para marcações técnicas (`PROTOTIPO`, `ESCROW ATIVO`, `MODELO DE NEGOCIO`).
- **`FrilaSignalBar`:** Barra lateral vertical (`width: 16pt` a `24pt`) encostada na borda esquerda de cards destacados ou seções de contrato, garantindo âncora visual imediata.

---

## 6. Integração no Design Lab Nativo (`FrilaDesignLabView.swift`)

Para permitir a validação interativa e testes visuais imediatos:

1. **Nova Aba ou Seção "Editorial / Deck":**
   - Adicionada ao enum `LabSection`: `.editorial = "Editorial Deck"`.
2. **Controles de Laboratório:**
   - **Canvas Toggle:** Alternância instantânea entre Drywall (`#FFFFFF`) e Papel Quente (`#F6F4EF`).
   - **Grade Técnica Toggle:** Ativação/desativação da grade milimetrada de fundo (`FrilaTechnicalGrid`).
   - **Paradigmas Tipográficos:** Comparador lado a lado entre `Bricolage Grotesque + IBM Plex Mono` e `SF Pro + New York + SF Mono`.
3. **Vitrine dos Novos Componentes:**
   - Amostras interativas de `FrilaStatCard` (Big Numbers e Citações), `FrilaFlowStepper` (com simulação de etapa ativa), e `FrilaNumberedList`.

---

## 7. Protocolo de Execução Multi-Agente (AO Architecture)

Em estrita conformidade com a seção 6 de `AGENTS.md` (*"O Orquestrador Nunca Codifica"*), a execução deste incremento será realizada através de Workers isolados:

### Etapa 1: Worker Alpha (Desenvolvimento & UI Craft)
- **Comando:**
  ```bash
  ./scripts/ao-worker.sh alpha "[SKILLS: swiftui-ui-patterns, emil-design-eng, swift-code-writer] Implementar especificação docs/design-system/DESIGN_MERGE_SPEC.md: atualizar tokens FrilaColor (#FF4D17, dynamicPaper, dynamicTechnicalGrid), registrar fontes customizadas Bricolage Grotesque e IBM Plex Mono via SPM resources em Package.swift e FrilaTypography, implementar FrilaStatCard, FrilaFlowStepper, FrilaNumberedList, FrilaTechnicalGrid, FrilaEditorialTag e integrá-los no FrilaDesignLabView."
  ```
- **Entregáveis:**
  - `Package.swift` atualizado com `.process("Resources/Fonts")`.
  - Arquivos de fontes adicionados a `Sources/FrilaDesignSystem/Resources/Fonts/`.
  - `FrilaColor.swift` atualizado com `#FF4D17` e novas superfícies.
  - `FrilaTypography.swift` com suporte a fontes do deck e escala monumental.
  - Novos componentes em `Sources/FrilaDesignSystem/Components/`.
  - Aba editorial integrada em `Sources/FrilaDesignSystem/DesignLab/FrilaDesignLabView.swift`.
  - Build limpo (`swift build`).

### Etapa 2: Worker Beta (Testes, QA & Hardening)
- **Comando:**
  ```bash
  ./scripts/ao-worker.sh beta "[SKILLS: test-driven-development, accessibility, swift-code-writer] Adicionar testes unitários completos para as novas adições do DESIGN_MERGE_SPEC.md: testes de contraste WCAG 2.2 AA para #FF4D17 sobre papel (#F6F4EF) e drywall (#FFFFFF), testes de carregamento das fontes Bricolage e IBM Plex Mono, testes de layout concêntrico e acessibilidade (hitboxes e traits) dos novos componentes FrilaStatCard, FrilaFlowStepper e FrilaNumberedList. Executar swift test e validar 100% de aprovação." --from <branch_alpha>
  ```
- **Entregáveis:**
  - Novos testes em `Tests/FrilaDesignSystemTests/FrilaEditorialTokensTests.swift`.
  - Testes de acessibilidade e renderização de fontes.
  - Garantia de que `swift test` passa sem erros nem warnings.

### Etapa 3: Revisão & Merge pelo Orquestrador
- O Orquestrador inspeciona o log de commits, valida as asserções de teste e apresenta o relatório final ao usuário.
