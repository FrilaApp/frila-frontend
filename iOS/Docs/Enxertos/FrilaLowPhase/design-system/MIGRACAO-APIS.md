# Registro de Migração de APIs Depreciadas e Limpeza Histórica (P4)

Este documento registra a erradicação de APIs legadas/depreciadas, substituições canônicas API a API, e a remoção de rótulos históricos em cumprimento à SPEC §6, §8 (P4) e §9 (Critério 5).

---

## 1. Tabela de Substituição API a API

Todas as APIs com anotação `@available(*, deprecated, ...)` foram removidas após verificação de zero chamadores nos componentes, fluxos e testes.

| Símbolo Removido | Local de Origem | Substituição Canônica | Justificativa / Comportamento Preservado |
| :--- | :--- | :--- | :--- |
| `FrilaColor.escrow` | `Primitives/FrilaColor.swift` | `FrilaColor.verified` | Cor esmeralda `#007A33` (WCAG AA ≥ 4.5:1). Nome unificado do pilar de conformidade. |
| `FrilaColor.escrowBg` | `Primitives/FrilaColor.swift` | `FrilaColor.verifiedBg` | Superfície sutil `#EBF7EE`. |
| `FrilaColor.dynamicEscrow(isDark:)` | `Primitives/FrilaColor.swift` | `FrilaColor.dynamicVerified(isDark:)` | Dinâmico: Light `#007A33` / Dark `#4ADE80`. |
| `FrilaColor.dynamicEscrowBg(isDark:)` | `Primitives/FrilaColor.swift` | `FrilaColor.dynamicVerifiedBg(isDark:)` | Dinâmico: Light `#EBF7EE` / Dark `#0F2B1A`. |
| `FrilaStatusChip.ChipStyle.escrow` | `Components/FrilaButton.swift` | `FrilaStatusChip.ChipStyle.verified` | Estilo canônico de chip passivo de verificação. Cores idênticas. |
| `FrilaTypography.metric(size:weight:design:)` | `Primitives/FrilaTypography.swift` | `FrilaTypography.metric(size:weight:)` ou `FrilaTypography.metricTabular(size:weight:)` | Métrica numérica sempre SF Pro (Pilar 4). Elimina escape de design `.monospaced` em métricas. |
| `FrilaMetricModifier.init(size:weight:design:)` | `Primitives/FrilaTypography.swift` | `FrilaMetricModifier.init(size:weight:digits:)` | Inicializador estruturado com SF Pro e dígitos proporcionais ou tabulares. |
| `View.frilaMetric(size:weight:design:)` | `Primitives/FrilaTypography.swift` | `View.frilaMetric(size:weight:digits:)` | Modificador de view sem parâmetro `design:`. |
| `FrilaFlowStepper.init(currentStep:totalSteps:isDark:showDots:...)` | `Components/FrilaFlowStepper.swift` | `FrilaFlowStepper.init(currentStep:totalSteps:isDark:style:dock:)` ou `FrilaFlowStepper.init(currentStep:steps:...)` | Inicializador canônico com enum `Style` (`.dots`, `.activeFocused`, `.editorial`) e `DockConfiguration`. |
| `FrilaFluidProgressIndicator` (typealias) | `Components/FrilaFlowStepper.swift` | `FrilaFlowStepper` | Tipo canônico unificado do stepper. |
| `FrilaFluidProgressDots` (typealias) | `Components/FrilaFlowStepper.swift` | `FrilaFlowStepper.Dots` | Componente de pontos unificado dentro do namespace do stepper. |

---

## 2. Prova de Zero Consumidores

Após a varredura e limpeza da base de código:
- **`Sources/`**: 0 referências a símbolos depreciados; 0 anotações `@available(*, deprecated, ...)`.
- **`FrilaApp/`**: 0 referências a símbolos depreciados.
- **`Tests/`**: 0 referências a símbolos depreciados fora dos testes de guardrail estático. A allowlist `allowedDeprecatedMetricCalls` em `FrilaDesignGuardrailTests` foi reduzida a zero (`[]`).

---

## 3. Limpeza de Rótulos Históricos

Conforme o Critério 5 da SPEC §9 ("Zero legacy/Legacy/Challenge/antigo/antiga em Sources/FrilaApp; zero rótulo histórico Merge nas demos/tokens"):

1. **`Sources/FrilaDesignSystem/DesignLab/System/StatCardShowcaseView.swift`**:
   - `role: "Design Lead, Challenge 18"` $\to$ `role: "Design Lead"`.
2. **`Sources/FrilaDesignSystem/Components/FrilaStatCard.swift`**:
   - `source: "Challenge 18 Report"` $\to$ `source: "Relatório de Auditoria"`.
3. **`Sources/FrilaDesignSystem/Primitives/FrilaTypography.swift`**:
   - `// MARK: - Monumental Metric Scale (Deck Challenge 18 / "Dado em Destaque")` $\to$ `// MARK: - Monumental Metric Scale ("Dado em Destaque")`.
4. **`Sources/FrilaDesignSystem/Primitives/FrilaGeometry.swift`**:
   - `// MARK: - Editorial Geometry Tokens (Challenge 18 Merge)` $\to$ `// MARK: - Editorial Geometry Tokens`.
5. **`Sources/FrilaDesignSystem/Primitives/FrilaColor.swift`**:
   - `// MARK: - Editorial Ink & Dividers (Deck Challenge 18)` $\to$ `// MARK: - Editorial Ink & Dividers`.
6. **`Sources/FrilaDesignSystem/Components/FrilaFlowStepper.swift`**:
   - Removido comentário `// MARK: - Deprecated Legacy Compatibility Wrappers` e referência a "legada".
7. **`Sources/FrilaDesignSystem/Shifts/FrilaShiftFlowView.swift`**:
   - Removida linha `Design System` e navegação para `FrilaDesignLabView` no perfil, atendendo também ao Critério 6 da SPEC §9 (fluxos de produto sem referências a DesignLab/Sistema/Laboratório).

---

## 4. Preservação de Invariantes e Valores Numéricos

Nenhum valor de token de design foi modificado:
- `radiusCardEditorial` = `28pt`
- `flowStepBarHeight` = `6pt`
- `dynamicInk` (Light: `#111111`, Dark: `#F4F1EA`)
- `dynamicInkSecondary` (Light: `#3A3A3A`, Dark: `#CFCAC0`)
- `dynamicSubtle` (Light: `#6B6B6B`, Dark: `#9A968D`)
- `dynamicDividerStrong` (Light: `#D4D0C6`, Dark: `#33322E`)
- `FrilaShadowElevation.editorial`
- Escala Monumental: `metricHeroSpec` (44pt), `metricMonumentalSpec` (38pt), `metricCardBigSpec` (34pt).
