# Inventário de Cores e Fontes nas Telas — Cartão #139

Este documento cumpre o critério de aceite do **Cartão #139**:
> *"Nenhuma tela do Sprint 1 define cor ou fonte fora dos tokens (revisão de código)"*

## 1. Diretriz de Design e Tokens

Todas as cores e fontes de telas e componentes visuais do Frila devem ser provenientes de tokens centralizados ou de estilos dinâmicos semânticos:
- **Cores:** Centralizadas em `FrilaCor` (`iOS/Sources/Apresentacao/DesignTokens.swift`), garantindo suporte a temas, consistência visual e previsibilidade quando o design oficial for aplicado.
- **Fontes:** Devem utilizar exclusivamente estilos de texto dinâmicos do sistema (`.largeTitle`, `.title`, `.title2`, `.title3`, `.headline`, `.subheadline`, `.body`, `.callout`, `.footnote`, `.caption`), garantindo respeito integral ao **Dynamic Type** e acessibilidade para usuários com tamanhos de texto ampliados.
- **Proibições:** É proibido o uso de `Color(red:...)`, `Color(white:...)`, `Color(uiColor:...)`, `Color("...")` solto fora de `DesignTokens.swift`, `UIColor(...)`, `.font(.system(size:...))`, `Font.system(size:...)`, `Font.custom(...)`, bem como cores literais do sistema (`.red`, `.blue`, `.orange`, `.gray` etc.) em modificadores visuais.

---

## 2. Metodologia do Inventário

Foi realizada varredura estática completa em `iOS/Sources` com busca de:
1. `Color(red:`, `Color(white:`, `Color(uiColor:`, `Color("`, `UIColor(`
2. `.font(.system(size:`, `Font.system(size:`, `Font.custom(`, `.font(.system(..., design:`
3. `.foregroundStyle(...)`, `.foregroundColor(...)`, `.tint(...)`, `.background(...)`, `.stroke(...)`, `.fill(...)`
4. Cores literais (`.red`, `.green`, `.blue`, `.orange`, `.yellow`, `.pink`, `.purple`, `.teal`, `.indigo`, `.mint`, `.cyan`, `.gray`, `.white`, `.black`, `.clear`, `.secondary`, `.primary`)

Cada ocorrência foi classificada em:
- **(a)** Precisa trocar por token (corrigida diretamente nos arquivos livres; apontada no relatório nos arquivos ocupados por PRs abertos).
- **(b)** Aceitável (uso de token sob variável tipada, estilos semânticos do sistema em telas de suporte/debug, ou materiais do sistema).
- **(c)** Falta um token (criação de token semântico no `DesignTokens.swift` quando recorrente, ou proposta para a equipe de design).

---

## 3. Tabela de Inventário e Conformidade

| Arquivo : Linha | Ocorrência | Classe | Situação | Justificativa / Ação Realizada |
|---|---|:---:|:---:|---|
| `iOS/Sources/App/FalhaDoEnsaio.swift:17` | `.tint(.red)` | **(a)** | **Corrigido** | Substituído por `.tint(FrilaCor.perigo)` com `import FrilaApresentacao`. Arquivo livre. |
| `iOS/Sources/App/RelatorioDeMedicoes.swift:20` | `.background(.thinMaterial, in: Circle())` | **(b)** | **Aceito** | Material de desfoque nativo do sistema (`.thinMaterial`) para painel técnico interno de diagnóstico em `#if DEBUG \|\| FRILA_MEDICAO`. |
| `iOS/Sources/App/RelatorioDeMedicoes.swift:57` | `.foregroundStyle(.secondary)` | **(b)** | **Aceito** | Estilo hierárquico secundário padrão do sistema em relatório técnico interno de medição de abertura. |
| `iOS/Sources/Apresentacao/TelaLicencas.swift:134` | `.foregroundStyle(cor)` | **(b)** | **Aceito** | O parâmetro `cor` tem valor padrão `FrilaCor.texto` e recebe `FrilaCor.primaria` na chamada do link (linha 106). Sempre consome `FrilaCor`. |
| `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:143` | `.foregroundStyle(situacao.cor)` | **(b)** | **Aceito** | A propriedade `cor` de `LinhaDeSituacao` só recebe `FrilaCor.alerta`, `FrilaCor.sucesso`, `FrilaCor.textoSecundario` e `FrilaCor.texto` (linhas 153, 157, 160, 162, 171, 173). |
| `iOS/Sources/Apresentacao/Fluxos/Autenticacao/TelaCadastro.swift:209` | `.stroke(... FrilaCor.textoSecundario.opacity(0.35))` | **(c)** | **Corrigido** | Substituído pelo novo token `FrilaCor.borda` criado em `DesignTokens.swift`. Arquivo livre. |
| `iOS/Sources/Apresentacao/Fluxos/Autenticacao/TelaCodigo.swift:76` | `.stroke(... FrilaCor.textoSecundario.opacity(0.35))` | **(c)** | **Corrigido** | Substituído pelo novo token `FrilaCor.borda` criado em `DesignTokens.swift`. Arquivo livre. |
| `iOS/Sources/Apresentacao/Fluxos/Conta/TelaContaSuspensa.swift:179` | `.stroke(FrilaCor.textoSecundario.opacity(0.35))` | **(c)** | **Corrigido** | Substituído pelo novo token `FrilaCor.borda` criado em `DesignTokens.swift`. Arquivo livre. |
| `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaVagas.swift:173` | `.background(ativo ? FrilaCor.primaria.opacity(0.12) : ...)` | **(c)** | **Aceito / Sugestão** | Usa token `FrilaCor.primaria` com 12% de opacidade para pílula selecionada. Sugere-se token `FrilaCor.primariaAtenuada` para o design system. |
| `iOS/Sources/Apresentacao/Componentes.swift:86` | `.stroke(FrilaCor.textoSecundario.opacity(0.35))` | **(c)** | **Ocupado pelo PR #110** | Contorno de campo em `CampoFrila`. Sugere-se adotar `FrilaCor.borda` após merge do PR #110. |
| `iOS/Sources/Apresentacao/Componentes.swift:206` | `.foregroundStyle(cor)` | **(b)** | **Ocupado pelo PR #110** | `AvisoFrila`: `cor` computada na linha 213 mapeia `tom` exclusivamente para `FrilaCor.primaria`, `FrilaCor.alerta` ou `FrilaCor.perigo`. Conforme. |
| `iOS/Sources/Apresentacao/Componentes.swift:209` | `.background(cor.opacity(0.12)...)` | **(c)** | **Ocupado pelo PR #110** | Fundo de aviso com opacidade de 12% da cor do tom. Conforme, com proposta de tokenização de atenuação. |
| `iOS/Sources/Apresentacao/Componentes.swift:330` | `Capsule().fill(FrilaCor.textoSecundario.opacity(0.4))` | **(c)** | **Ocupado pelo PR #110** | Alça do bottom sheet modal. Conforme; sugere-se token `FrilaCor.alcaModal`. |
| `iOS/Sources/Apresentacao/Fluxos/Conta/TelaExclusaoDeConta.swift:186` | `FrilaCor.textoSecundario.opacity(0.35)` | **(c)** | **Ocupado pelo PR #110** | Fundo desabilitado do botão destrutivo. Sugere-se adotar `FrilaCor.borda` após merge do PR #110. |
| `iOS/Sources/Apresentacao/Fluxos/Contratante/PublicarVaga.swift:492, 528, 543` | `.stroke(FrilaCor.textoSecundario.opacity(0.35))` | **(c)** | **Ocupado pelos PRs #73 e #103** | Contorno de caixas de formulário. Sugere-se adotar `FrilaCor.borda` após merge dos PRs. |
| `iOS/Sources/Apresentacao/Fluxos/Contratante/PublicarVaga.swift:624` | `.stroke(FrilaCor.textoSecundario.opacity(0.4))` | **(c)** | **Ocupado pelos PRs #73 e #103** | Contorno de pílula de seleção. Sugere-se unificar para `FrilaCor.borda`. |
| `iOS/Sources/Apresentacao/Fluxos/Cancelamento/FolhaDeCancelamento.swift:62` | `.stroke(FrilaCor.textoSecundario.opacity(0.35))` | **(c)** | **Ocupado pela branch #39 (Thor)** | Contorno do campo de motivo. Sugere-se adotar `FrilaCor.borda` após merge da branch #39. |

---

## 4. Auditoria de Fontes e Dynamic Type

Em todas as telas e componentes da camada `Sources/Apresentacao`:
- **Fontes fixas (`.system(size:)`):** **Zero ocorrências** no código do app.
- **Fontes customizadas (`Font.custom`):** **Zero ocorrências**.
- **Tipografia adotada:** 100% das 253 declarações de fonte utilizam os estilos de texto nativos do sistema (`.largeTitle`, `.title`, `.title2`, `.title3`, `.headline`, `.subheadline`, `.body`, `.callout`, `.footnote`, `.caption`), com variações de peso (`.bold()`, `.weight(.semibold)`, `.weight(.medium)`) ou formato (`.monospacedDigit()`).
- **Conformidade de acessibilidade:** Todos os textos respeitam a escala de tamanhos de texto do iOS (Dynamic Type), escalando proporcionalmente nos modos de acessibilidade.

---

## 5. Arquivos Ocupados por PRs Abertos

Conforme instrução expressa da missão, nenhum arquivo ocupado por PR aberto ou trabalho em andamento foi modificado. Todos constam na lista de exceções explícitas do teste de guarda `GuardaTokensDesignTests.swift` e serão esvaziados pelo Nick Fury após os respectivos merges:

| Arquivo Ocupado | Motivo / Vínculo | Estado de Cores e Fontes |
|---|---|---|
| `Componentes.swift` | PR #110 (Auditoria de Acessibilidade) | 100% tokens `FrilaCor` e estilos semânticos. |
| `TelaExclusaoDeConta.swift` | PR #110 (Auditoria de Acessibilidade) | 100% tokens `FrilaCor` e estilos semânticos. |
| `CortinaDePrivacidade.swift` | PR #112 (Auditoria de Segurança) | 100% tokens `FrilaCor`. |
| `ExportarDadosViewModel.swift` | PR #112 (Auditoria de Segurança) | Sem código de UI. |
| `TelaHistoricoDeTurnos.swift` | PR #106 (Histórico e Exportação) | 100% tokens `FrilaCor` e estilos semânticos. |
| `PerfisDaConta.swift` | PR #106 (Histórico e Exportação) | 100% tokens `FrilaCor` e estilos semânticos. |
| `HistoricoDeTurnosViewModel.swift` | PR #106 (Histórico e Exportação) | Sem código de UI. |
| `TextosHistoricoDeTurnos.swift` | PR #106 (Histórico e Exportação) | Sem código de UI. |
| `TelaMeuTurno.swift` | PR #103 e branch #39 | 100% tokens `FrilaCor` e estilos semânticos. |
| `PublicarVaga.swift` | PR #73 e PR #103 | 100% tokens `FrilaCor` e estilos semânticos. |
| `RepublicarVaga.swift` | PR #103 | 100% tokens `FrilaCor` e estilos semânticos. |
| `MeuTurnoViewModel.swift` | PR #103 e branch #39 | Sem código de UI. |
| `PresencaDoTurnoViewModel.swift` | PR #103 | Sem código de UI. |
| `TextosDaPresenca.swift` | PR #103 | Sem código de UI. |
| `MinhasVagas.swift` | PR #73 e branch #39 | 100% tokens `FrilaCor` e estilos semânticos. |
| `PublicarVagaDaCasa.swift` | PR #73 | 100% tokens `FrilaCor` e estilos semânticos. |
| `FluxoDoContratante.swift` | PR #73 | 100% tokens `FrilaCor` e estilos semânticos. |
| `FluxoDoProfissional.swift` | PR #114 e branch #39 | 100% tokens `FrilaCor` e estilos semânticos. |
| `TelasDaCandidatura.swift` | PR #114 | 100% tokens `FrilaCor` e estilos semânticos. |
| `TextosDoProfissional.swift` | PR #114 | Sem código de UI. |
| `TelaTurnoDoContratante.swift` | Branch #39 (Thor) | 100% tokens `FrilaCor` e estilos semânticos. |
| `FolhaDeCancelamento.swift` | Branch #39 (Thor) | 100% tokens `FrilaCor` e estilos semânticos. |
| `CancelamentoViewModel.swift` | Branch #39 (Thor) | Sem código de UI. |
| `TextosDoCancelamento.swift` | Branch #39 (Thor) | Sem código de UI. |
| `AcoesDeSeguranca.swift` | Branch #39 (Thor) | 100% tokens `FrilaCor` e estilos semânticos. |
| `SegurancaViewModel.swift` | Branch #39 (Thor) | Sem código de UI. |
| `AcompanhamentoViewModel.swift` | Branch #39 (Thor) | Sem código de UI. |

---

## 6. Token Criado em `DesignTokens.swift`

Atendendo ao item 3 da missão (*"crie o token em DesignTokens.swift só se for óbvio (mesmo valor usado em 2+ lugares)"*):
```swift
public enum FrilaCor {
    ...
    public static let borda = textoSecundario.opacity(0.35)
}
```
Esse token unifica o contorno de campos e caixas de seleção em toda a aplicação, mantendo exata equivalência visual e preparando o terreno para personalização temática futura.

---

## 7. Mecanismos de Guarda Automatizados

Para garantir que novas telas e alterações não introduzam cores ou fontes fora dos tokens:
1. **Teste Unitário (`GuardaTokensDesignTests.swift`):**
   - Executa no target `FrilaTests` durante o `xcodebuild test`.
   - Analisa todas as fontes de `Sources/Apresentacao` via `#filePath`.
   - Reprova na presença de `Color(red:`, `Color(white:`, `Color(uiColor:`, `Color("`, `UIColor(`, `.system(size:`, `Font.system(size:`, `Font.custom` ou cores do sistema (`.red`, `.blue`, etc.).
   - Possui lista explícita de exceções para arquivos temporariamente ocupados por outros PRs.
2. **Script de Validação na CI (`conferir-textos.sh`):**
   - Executado automaticamente a cada push e pull request.
   - Valida textos e tokens em toda a Apresentação.
   - Atualizado e coberto por testes sintéticos em `teste-conferir-textos.sh`.
