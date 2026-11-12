# Laudo Técnico: Auditoria de Exclusão de Conta nos Perfis (#50 / ABN4rvmT)

**Data:** 11/10/2026  
**Auditor:** Doutor Estranho  
**Cartão Trello:** [ABN4rvmT](https://trello.com/c/ABN4rvmT) (Critério 1: "Excluir conta fica em Meu perfil e em Estabelecimento, sem submenu, e segue os frames do design: consequências, turnos futuros listados e confirmação destrutiva")  
**Resultado da Auditoria:** Conforme (Aprovado com evidências de código, testes de UI e capturas de tela)

---

## 1. Mapeamento Analítico de Código (`arquivo:linha`)

### 1.1. Botão de Exclusão no Nível Raiz em Ambos os Perfis (Sem Submenu)
- **Perfil Profissional (`perfil-excluir-conta`):**
  - **Arquivo:** `iOS/Sources/Apresentacao/Fluxos/Perfil/PerfisDaConta.swift`
  - **Linhas:** 201 a 217
  - **Comprovação:** O `NavigationLink` direcionando para `TelaExclusaoDeConta` está posicionado no nível raiz da seção de conta do profissional, identificado por `.accessibilityIdentifier("perfil-excluir-conta")` (linha 215), com rótulo "Excluir conta" e ícone `person.crop.circle.badge.xmark`, sem nenhum submenu ou aninhamento secundário.
- **Perfil Estabelecimento / Contratante (`estabelecimento-excluir-conta`):**
  - **Arquivo:** `iOS/Sources/Apresentacao/Fluxos/Perfil/PerfisDaConta.swift`
  - **Linhas:** 306 a 321
  - **Comprovação:** O `NavigationLink` para `TelaExclusaoDeConta` está posicionado no nível raiz da seção do estabelecimento, identificado por `.accessibilityIdentifier("estabelecimento-excluir-conta")` (linha 321), com o mesmo padrão visual e acesso direto.
- **Contratante sem Estabelecimento:**
  - **Arquivo:** `iOS/Sources/Apresentacao/Fluxos/Contratante/PainelContratanteSemEstabelecimento.swift`
  - **Linhas:** 66 a 75
  - **Comprovação:** Botão `contratante-sem-estabelecimento-excluir-conta` disponível na barra superior, abrindo a tela de exclusão em folha modal.

### 1.2. Consequências com Ícones e Turnos Futuros Listados
- **Arquivo:** `iOS/Sources/Apresentacao/Fluxos/Conta/TelaExclusaoDeConta.swift`
- **Aviso Principal e Consequências com Ícones:**
  - Linhas 95 a 98: `avisoPrincipal` com `.accessibilityIdentifier("aviso-consequencias-exclusao")` (linha 97) em tom de alerta (`.alerta`).
  - Linhas 100 a 140: `secaoConsequencias` apresenta os impactos irreversíveis acompanhados de ícones dedicados em vermelho (`FrilaCor.perigo`):
    - `person.crop.circle.badge.minus`: anonimização do perfil e dados pessoais;
    - `calendar.badge.minus`: cancelamento de turnos futuros e vagas;
    - `clock.badge.xmark`: prazo e irrevogabilidade da ação.
- **Listagem de Turnos Futuros Vinculados:**
  - Linhas 142 a 196: `secaoTurnosFuturos` consulta e renderiza a lista de turnos futuros vinculados à conta.
  - Linha 181: Cada turno futuro ativo é identificado por `.accessibilityIdentifier("item-turno-futuro-\(turno.id)")`, contendo função da vaga, nome da contraparte, intervalo e localidade.
  - Linha 160: Quando não há compromissos futuros, exibe estado vazio claro via `.accessibilityIdentifier("texto-sem-turnos-futuros")`.

### 1.3. Confirmação Destrutiva em Duas Etapas (Toggle + Diálogo de Segurança)
- **Etapa 1 - Aceite Explícito via Toggle:**
  - **Arquivo:** `iOS/Sources/Apresentacao/Fluxos/Conta/TelaExclusaoDeConta.swift`, linhas 198 a 209.
  - Toggle `toggle-confirmar-consequencias` (linha 206) obriga a pessoa usuária a reconhecer as consequências.
  - Linhas 229 a 236: O botão `botao-excluir-conta-definitivo` permanece desabilitado (`.disabled(!viewModel.confirmouConsequencias || viewModel.excluindo)`) e visualmente atenuado até a ativação do toggle.
- **Etapa 2 - Diálogo de Segurança e Confirmação Destrutiva:**
  - Linhas 47 a 93: `confirmacaoFinal` apresenta folha/diálogo modal destacando a gravidade irreversível.
  - Linha 69: `botao-cancelar-exclusao-dialogo` fecha o diálogo sem executar a exclusão.
  - Linha 86: `botao-confirmar-exclusao-dialogo` com estilo destrutivo (`FrilaCor.perigo`) dispara `viewModel.confirmarExclusao()`.
  - Após a conclusão, a sessão é encerrada no Keychain e o app retorna para a tela inicial de entrada (`entrada-email`).

---

## 2. Execução dos Testes de UI (`ExclusaoDeContaUITests`)

A suíte completa `ExclusaoDeContaUITests` foi executada localmente via `xcb.sh` no simulador `Doutor Estranho` (`4E344DE6-2366-42CA-84BB-46C474E6789E`):

```sh
~/Documents/Projetos/Apps/.workers/vigia/xcb.sh "Doutor Estranho" -- xcodebuild test \
  -project iOS/Frila.xcodeproj -scheme Frila-Local \
  -destination "id=4E344DE6-2366-42CA-84BB-46C474E6789E" \
  -only-testing:FrilaUITests/ExclusaoDeContaUITests
```

### Resultado da Execução:
- **Status:** Sucesso (`xcodebuild terminou com 0`)
- **Passed tests:** 5 / 5 (100% de aprovação)
- **Tempo de teste:** 81.93s
- **Log completo:** `/Users/cauecarneiro/Documents/Projetos/Apps/.workers/vigia/logs-xcodebuild/doutor-estranho-20261011-224503-16132.log`

### Casos de Teste Aprovados:
1. `testConfirmacaoEmAX5MostraCancelarTocavelECancelarNaoExclui`: Aprovado (34.12s)
2. `testContratanteComEstabelecimentoChegaAExclusaoDeConta`: Aprovado (7.49s)
3. `testContratanteComTurnosFuturosVisualizaVinculosEListaIncompletaNaExclusao`: Aprovado (8.58s)
4. `testContratanteSemEstabelecimentoTemAcessoAExclusaoDeConta`: Aprovado (14.73s)
5. `testExclusaoDeContaPeloPerfilProfissionalVoltaParaEntrada`: Aprovado (17.01s)

---

## 3. Evidências Visuais e Capturas de Tela

As capturas de tela extraídas dos anexos do XCUITest com seus respectivos metadados (`manifest.json`) comprovam os estados da tela:

| Arquivo de Captura | Caso de Teste / Momento | Descrição da Evidência |
|---|---|---|
| `.workers/antigravity-3/evidencias/exclusao-conta/TelaExclusaoDeConta.png` | `testExclusaoDeContaPeloPerfilProfissionalVoltaParaEntrada` | Tela de exclusão aberta exibindo o aviso principal, a lista de consequências com ícones em vermelho, turnos futuros e o botão de exclusão bloqueado pelo toggle. |
| `.workers/antigravity-3/evidencias/exclusao-conta/VoltaParaEntrada.png` | `testExclusaoDeContaPeloPerfilProfissionalVoltaParaEntrada` | Retorno para a tela de entrada do aplicativo após a confirmação e purga de dados da conta. |
| `.workers/antigravity-3/evidencias/exclusao-conta/82CD60DA-05C8-4C3E-88B8-3F98BA1CE8FD.png` | `testConfirmacaoEmAX5MostraCancelarTocavelECancelarNaoExclui` | Confirmação final em Dynamic Type AX5 comprovando que os botões Cancelar e Excluir permanecem perfeitamente acessíveis e tocáveis no rodapé. |

---

## 4. Minuta para Registro no Cartão Trello ABN4rvmT

Para que o Nick Fury registre no cartão e marque o Critério 1 como concluído:

```markdown
**Auditoria de Exclusão de Conta nos Perfis (Critério 1 - ABN4rvmT): CONCLUÍDA E CONFORME**

1. **Acesso Direto sem Submenu:** Botão "Excluir conta" visível na raiz da seção de conta em ambos os perfis (`PerfisDaConta.swift:215` no profissional e `PerfisDaConta.swift:321` no estabelecimento).
2. **Frames do Design Atendidos:** `TelaExclusaoDeConta.swift` exibe aviso de alerta, consequências com ícones (`person.crop.circle.badge.minus`, `calendar.badge.minus`, `clock.badge.xmark`), listagem de turnos futuros vinculados (`item-turno-futuro-...`) e toggle mandatório de confirmação.
3. **Confirmação Destrutiva e Retorno:** Diálogo de confirmação em duas etapas com ação destrutiva destacada; exclusão limpa a sessão e retorna à tela de entrada.
4. **Testes de UI Aprovados:** Suíte `ExclusaoDeContaUITests` (5 testes) 100% verde no simulador (log `doutor-estranho-20261011-224503-16132.log`).
5. **Evidências Registradas:** Laudo em `iOS/Docs/AuditoriaExclusaoDeConta.md` e capturas em `evidencias/exclusao-conta/`.
```
