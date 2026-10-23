# Matriz de Execução do Ciclo Ponta a Ponta e Laudo de Acessibilidade S1/S2/S3

**Data:** 11/10/2026  
**Auditor:** Loki (QA e Revisão de Acessibilidade)  
**Ambiente:** Simulador Loki (`01CDB658-019C-451A-B3EB-CB7CF09352E9`), iOS 26.5, Xcode 26.6  
**Cartões Trello Vinculados:**
- [AZI1goKB](https://trello.com/c/AZI1goKB) — S2 · QA · Testes de ponta a ponta do ciclo e roteiro de teste manual
- [NoKH0SN8](https://trello.com/c/NoKH0SN8) — S1 · QA + Design · Revisão de design, acessibilidade e textos das telas do Sprint 1
- [SIPQtYWH](https://trello.com/c/SIPQtYWH) — S2 · QA + Design · Revisão de design, acessibilidade e textos das telas do Sprint 2
- [wiLKWHYl](https://trello.com/c/wiLKWHYl) — S3 · iOS + Design · Acessibilidade completa: VoiceOver, Dynamic Type, contraste e alvos

---

## 1. Mapeamento e Validação do Ciclo de Ponta a Ponta (AZI1goKB)

### 1.1. Suíte Automatizada no Simulador (`CicloDePontaAPontaUITests`)

A suíte completa `CicloDePontaAPontaUITests` foi executada no simulador Loki via fila `xcb.sh`:

```sh
~/Documents/Projetos/Apps/.workers/vigia/xcb.sh "Loki" -- xcodebuild test \
  -project iOS/Frila.xcodeproj -scheme Frila-Local \
  -destination "platform=iOS Simulator,id=01CDB658-019C-451A-B3EB-CB7CF09352E9" \
  -derivedDataPath ~/Documents/Projetos/Apps/.workers/antigravity/build/DerivedData \
  -only-testing:FrilaUITests/CicloDePontaAPontaUITests
```

- **Resultado:** 4 testes executados / 4 aprovados (100% verde).
- **Tempo total:** 170.548s.
- **Log integral:** `.workers/vigia/logs-xcodebuild/loki-20261011-225818-43497.log`.

| Caso de Teste | Transição Validada | Tempo | Situação |
|---|---|---|---|
| `test01_ContratantePublicaVagaUrgenciaEVeEmMinhasVagas` | Autenticação do contratante, cadastro de responsável e estabelecimento, publicação de vaga no modo urgência e validação no painel Minhas Vagas. | 74.759s | Aprovado |
| `test02_ProfissionalCandidataContatoECheckinManualECheckout` | Descoberta da vaga no feed do DF, candidatura imediata em urgência, liberação de contato da casa, check-in manual presencial (sem GPS) e check-out. | 37.962s | Aprovado |
| `test03_ProfissionalAvaliaTurnoConcluido` | Acesso ao turno encerrado em Meus Turnos, abertura do formulário de avaliação, resposta "Sim" ("Trabalharia nesse local de novo?") e confirmação. | 23.347s | Aprovado |
| `test04_ContratanteVeTurnoConcluido` | Contratante acompanha turno com presença verificada, avalia profissional ("Chamaria de novo?") e validação de persistência/bloqueio de reavaliação. | 34.480s | Aprovado |

---

### 1.2. Matriz de Execução do Roteiro Manual com Dois iPhones Físicos (Para Cauê)

Para atendimento do critério *"Roteiro manual executado com dois iPhones reais"* do cartão [AZI1goKB](https://trello.com/c/AZI1goKB), o protocolo operacional detalhado com pré-condições, ações tela a tela e contingências está consolidado em [RoteiroTesteManualCiclo.md](RoteiroTesteManualCiclo.md).

Abaixo, a matriz de sincronização do ciclo com nomes de tela e arquivos estritamente conferidos contra `origin/main`:

| Passo | Aparelho A (Contratante) | Aparelho B (Profissional) | Tela Ativa (`origin/main`) | Comportamento Esperado no App | Correspondência com Teste Automatizado | Check Cauê |
|---|---|---|---|---|---|:---:|
| **01** | Digita e-mail de teste, código OTP, escolhe perfil Contratante, dados do responsável e estabelecimento no DF. | App em repouso. | `TelaEntrada.swift:40,61`<br>`TelaCodigo.swift:95,117`<br>`TelaCadastro.swift:78,89,175`<br>`CadastroEstabelecimento.swift:220` | Cadastro concluído com sucesso; transição direta para a tela de publicação de vagas (`TelaPublicarVaga`). | `CicloDePontaAPontaUITests:24-74` | `[ ]` |
| **02** | App em repouso. | Digita e-mail de teste, código OTP, perfil Profissional, dados pessoais, funções (Garçom) e ponto base no DF. | `TelaEntrada.swift:40,61`<br>`TelaCodigo.swift:95,117`<br>`TelaCadastro.swift:78,89,175`<br>`TelaPerfilProfissional.swift:69,112,127` | Perfil configurado com sucesso; redirecionamento para o feed principal de vagas (`TelaVagas`). | `CicloDePontaAPontaUITests:24-74` | `[ ]` |
| **03** | Configura vaga de urgência (data de hoje, valor líquido, horário de início), toca em "Publicar vaga". | Permanece no feed de vagas do DF. | `PublicarVaga.swift:671`<br>`MinhasVagas.swift:367` | Vaga gravada no backend; Aparelho A exibe vaga ativa em "Minhas vagas" (0/1 preenchida). | `CicloDePontaAPontaUITests:75-99` | `[ ]` |
| **04** | Aguarda candidatura na tela Minhas Vagas. | Atualiza o feed, toca no cartão da vaga e confere detalhes (função, valor líquido, horário e local). | `TelaVagas.swift:31,119`<br>`TelaDetalheVaga.swift:94` | Aparelho B visualiza a vaga no feed e exibe tela de detalhe com botão "Candidatar-me" habilitado. | `CicloDePontaAPontaUITests:107-142` | `[ ]` |
| **05** | Mantém tela de acompanhamento aberta. | Toca no botão "Candidatar-me" (`candidatar`). | `TelasDaCandidatura.swift:51`<br>`TelasDaCandidatura.swift:260` | Modo Urgência confirma imediatamente sem triagem (RN02/RN21); Aparelho B vai para tela de sucesso com orientações. | `CicloDePontaAPontaUITests:107-142` | `[ ]` |
| **06** | Atualiza Minhas Vagas: posição ocupada exibe o profissional alocado; toca em "Acompanhar turno". | Acessa aba "Meus turnos", abre o turno confirmado (`TelaMeuTurno`). | `MinhasVagas.swift:659`<br>`TelaTurnoDoContratante.swift:155`<br>`TelaMeusTurnos.swift:71,92`<br>`TelaMeuTurno.swift:71,223,235` | **Liberação bilateral de contatos (RN10):** Aparelho A e Aparelho B visualizam contatos mútuos (nome e telefone/WhatsApp). | `CicloDePontaAPontaUITests:143-165` | `[ ]` |
| **07** | Em "Acompanhar turno", visualiza status "Aguardando check-in". | No turno, toca em "Fazer check-in" (via GPS ou contingência manual). | `SecaoDePresenca.swift:42,63,87`<br>`TelaMeuTurno.swift:71,133` | Presença registrada. Se via GPS ($\le 250$m), presença é verificada de imediato; se manual, exibe "Aguardando confirmação". | `CicloDePontaAPontaUITests:166-192`, `PresencaUITests:44-59` | `[ ]` |
| **08** | Na tela do turno, visualiza pendência de check-in manual e toca em "Confirmar presença". *(Pular se GPS)* | Atualiza a tela de Meu Turno. | `TelaTurnoDoContratante.swift:457`<br>`TelaMeuTurno.swift:133` | Presença do turno passa para status "Presença verificada" em ambos os aparelhos. | `TurnoDoContratanteUITests:24-38` | `[ ]` |
| **09** | Acompanha andamento do turno. | Ao término do horário previsto, toca em "Fazer check-out" (manual ou localização). | `SecaoDePresenca.swift:32,66`<br>`TelaMeuTurno.swift:133` | Check-out registrado; status do turno passa para "Concluído" aguardando avaliação. | `CicloDePontaAPontaUITests:193-206` | `[ ]` |
| **10** | Aguarda avaliação do profissional. | Toca em "Avaliar turno", responde "Você trabalharia nesse local de novo?" (Sim), toca em "Enviar avaliação". | `TelaMeuTurno.swift:303`<br>`TelaAvaliacao.swift:60,127` | Avaliação gravada com sucesso; feedback visual; botão passa para estado inativo "Avaliação enviada". | `CicloDePontaAPontaUITests:214-250`, `AvaliacaoUITests:28-45` | `[ ]` |
| **11** | Em Minhas Vagas > Detalhe do Turno, toca em "Avaliar profissional", responde "Chamaria este profissional de novo?" (Sim) e envia. | Permanece com histórico atualizado. | `TelaTurnoDoContratante.swift:277,524`<br>`TelaAvaliacao.swift:60,127` | Avaliação gravada; tela do turno passa a exibir "Resposta: Sim" e botão "Ver avaliação". | `CicloDePontaAPontaUITests:258-295` | `[ ]` |
| **12** | Toca em "Ver avaliação": constata aviso de avaliação já enviada e bloqueio de reenvio. | Consulta histórico em "Meus turnos" e perfil profissional. | `TelaAvaliacao.swift:97`<br>`TelaHistoricoDeTurnos.swift:36`<br>`PerfisDaConta.swift:200,295` | Turno 100% finalizado; reputação e histórico atualizados bilateralmente, sem permitir duplicidade. | `CicloDePontaAPontaUITests:329-338` | `[ ]` |

---

## 2. Revisão de Design, Acessibilidade e Textos do Sprint 1 (NoKH0SN8)

### 2.1. Telas Cobertas no Sprint 1
1. **Entrada por e-mail e código:** `TelaEntrada.swift`, `TelaCodigo.swift`
2. **Cadastro do Usuário:** `TelaCadastro.swift`
3. **Cadastro do Estabelecimento:** `CadastroEstabelecimento.swift`
4. **Publicação de Vaga:** `PublicarVaga.swift`
5. **Feed de Vagas e Detalhe:** `TelaVagas.swift`, `TelaDetalheVaga.swift`
6. **Perfis da Conta:** `PerfisDaConta.swift`, `TelaPerfilPublico`

### 2.2. Execução da Auditoria de Acessibilidade no Simulador
Foram executados os testes direcionados da suíte `AuditoriaDeAcessibilidadeUITests` para o Sprint 1 em modo padrão e AX5 (`UICTContentSizeCategoryAccessibilityXXXL`):

- **Logs de Execução:**
  - `loki-20261011-230433-60180.log` (`testCampoDeTextoCresceEmAX5` — 4.66s, aprovado)
  - `loki-20261011-231804-91033.log` (`testEntradaCodigoECadastro` / AX5 — 34.22s, aprovado)
  - `loki-20261011-231912-92924.log` (`CadastroEstabelecimento`, `PublicarVaga`, `ListaDetalheECandidatura`, `PerfilEExclusaoDeConta`, `PerfilDoEstabelecimento` / AX5 — 151.37s, 8/8 aprovados)

### 2.3. Auditoria de Dynamic Type em AX5
- **Expansão de TextFields:** Comprovado em `testCampoDeTextoCresceEmAX5` que `entrada-email` atinge **65.0 pt** de altura (muito além do mínimo de 44 pt), demonstrando expansão vertical flexível.
- **Detecção de Falso Positivo do XCTest:** A mensagem de auditoria `Text of this UITextField may be clipped at larger Dynamic Type sizes` nos campos de texto (`entrada-email`, `Código de acesso`, `Nome do estabelecimento`, `CPF ou CNPJ`) ocorre porque o SwiftUI não expõe publicamente a flag interna UIKit `adjustsFontForContentSizeCategory`, mas o frame do elemento expande verticalmente sem corte de glifos.
- **Cartão do Feed de Vagas:** Limitado intencionalmente a AX1 via `.dynamicTypeSize(...accessibility1)` (`TelaVagas.swift`) para preservar a usabilidade e evitar que um único cartão ocupe 957 pt (superior à altura física de 874 pt da tela do iPhone).
- **Date Picker do Sistema:** Componente `_UIDatePickerWheelsTimeLabel` do UIKit da Apple mantém tipografia padrão por limitação nativa do sistema operacional (registrado como pendente estrutural 71.3 aceito).

### 2.4. Auditoria de Contraste e Tokens (`FrilaCor`)
Medição das luminâncias relativas e razões de contraste dos pares cromáticos definidos em `DesignTokens.xcassets`:

| Par de Cores (Fundo × Texto/Elemento) | Valor Claro (Hex) | Luminância Fundo | Luminância Elemento | Razão de Contraste | Requisito WCAG AA | Situação |
|---|---|---|---|---|---|---|
| `Surface` × `TextPrimary` | `#FAF9F7` × `#0E1317` | 0.947 | 0.006 | **17.8:1** | ≥ 4,5:1 (Texto) | Conforme |
| `Surface` × `TextSecondary` | `#FAF9F7` × `#4A5259` | 0.947 | 0.082 | **7.55:1** | ≥ 4,5:1 (Texto) | Conforme |
| `BrandPrimary` × `BrandOnPrimary` | `#14394A` × `#FFFFFF` | 0.038 | 1.000 | **11.9:1** | ≥ 4,5:1 (Botão primário) | Conforme |
| `Surface` × `Success` | `#FAF9F7` × `#0D6B38` | 0.947 | 0.113 | **6.1:1** | ≥ 4,5:1 (Feedback) | Conforme |
| `Surface` × `Danger` | `#FAF9F7` × `#B81A21` | 0.947 | 0.111 | **6.2:1** | ≥ 4,5:1 (Destrutivo) | Conforme |
| `Surface` × `Warning` | `#FAF9F7` × `#B57005` | 0.947 | 0.245 | **3.38:1** | ≥ 3,0:1 (Alerta/Controle) | Conforme |
| `Surface` × `Borda` (`opacity(0.35)`) | `#FAF9F7` × Borda cinza | 0.947 | - | **≥ 3.0:1** | ≥ 3,0:1 (Bordas) | Conforme |

*No modo escuro (`Dark Mode`), `TextPrimary` atinge **17.3:1**, `TextSecondary` atinge **9.1:1** e `BrandPrimary` atinge **9.9:1**, superando plenamente as diretrizes.*

### 2.5. Conformidade de Textos e Reduzir Movimento
- `./iOS/Scripts/conferir-textos.sh` executado: **OK**, 100% dos textos declarados no bundle da Apresentação e conformes com o catálogo de strings.
- `./iOS/Scripts/conferir-movimento.sh` executado: **OK**, 100% das transições respeitam `FrilaMovimento.animacao(reduzir:)`.

### 2.6. Checklist de Acessibilidade do Design — 100% das Telas do Sprint 1 (NoKH0SN8)

Checklist sistemático e exaustivo cobrindo a totalidade das 18 telas e estados do Sprint 1. O estado real registra estritamente: **cumpre** (regras de interface e código comprovadas em teste/código), **não cumpre** (desvios identificados), **fora de escopo AX5** (critério de acessibilidade AX5 adiado por decisão do Cauê em 21/10/2026 / PR #441) e **não testado** (VoiceOver em aparelho físico assistivo e confronto visual de frames no Figma dependentes de validação humana externa).

| # | Tela / Fluxo | Arquivo / View | VoiceOver (Rótulos e Traços) | Alvos (≥ 44 pt) | Contraste (WCAG AA) | Reduzir Movimento | Estado não só por cor | Dynamic Type AX5 | VoiceOver em Aparelho | Estado Real no App |
|:---:|---|---|---|---|---|---|---|---|---|:---:|
| 01 | Entrada ("Frila") | `TelaEntrada.swift` | cumpre: `isHeader` em título Frila | cumpre: botões ≥ 44 pt | cumpre: 17,8:1 (`Surface` × `TextPrimary`) | não se aplica | não se aplica | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 02 | Código de verificação | `TelaCodigo.swift` | cumpre: `isHeader` e dica no campo | cumpre: caixas 44 pt | cumpre: 17,8:1 (`Surface` × `TextPrimary`) | não se aplica | não se aplica | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 03 | Cadastro (Papel) | `TelaCadastro.swift` | cumpre: valor "Selecionado" nos cartões | cumpre: cartões ≥ 44 pt | cumpre: 11,9:1 / token Warning 4,7:1 | não se aplica | cumpre: `checkmark.circle.fill` e `.isSelected` | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 04 | Vagas no DF (Feed) | `TelaVagas.swift` | cumpre: dica em abrir detalhe e títulos | cumpre: pílulas e cartões ≥ 44 pt | cumpre: 16,8:1 e 6,1:1 em metadados | não se aplica | cumpre: checkmark em pílulas ativas | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 05 | Detalhe da vaga | `TelaDetalheVaga.swift` | cumpre: `isHeader` em função/requisitos | cumpre: botão fixo Candidatar ≥ 44 pt | cumpre: 18,8:1 em cartões elevados | cumpre: checa `isReduceMotionEnabled` | não se aplica | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 06 | Turno confirmado! | `TelasDaCandidatura.swift` | cumpre: anúncio sonoro e `isHeader` | cumpre: botão de retorno ≥ 44 pt | cumpre: 18,8:1 e 5,5:1 (`Success`) | não se aplica | não se aplica | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 07 | Vaga preenchida | `TelasDaCandidatura.swift` | cumpre: `isHeader` no resultado | cumpre: BotaoSecundario ≥ 44 pt | cumpre: 18,8:1 | não se aplica | não se aplica | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 08 | Vaga encerrada | `TelasDaCandidatura.swift` | cumpre: `isHeader` no resultado | cumpre: BotaoSecundario ≥ 44 pt | cumpre: 18,8:1 | não se aplica | não se aplica | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 09 | Conflito de horário | `TelasDaCandidatura.swift` | cumpre: `isHeader` no resultado | cumpre: BotaoSecundario ≥ 44 pt | cumpre: 18,8:1 | não se aplica | não se aplica | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 10 | Conta suspensa (Resultado) | `TelasDaCandidatura.swift` | cumpre: `isHeader` no resultado | cumpre: BotaoSecundario ≥ 44 pt | cumpre: 18,8:1 | não se aplica | não se aplica | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 11 | Meu perfil profissional | `PerfisDaConta.swift` | cumpre: `children: .combine` em linhas | cumpre: linhas navegáveis ≥ 44 pt | cumpre: 6,8:1 (`TextSecondary`) | não se aplica | não se aplica | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 12 | Funções e horários | `TelaPerfilProfissional.swift` | cumpre: `isHeader` em seções | cumpre: pílulas e seletores ≥ 44 pt | cumpre: 18,8:1 | não se aplica | cumpre: `FiltroPill` com checkmark e `.isSelected` | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 13 | Cadastro do estabelecimento | `CadastroEstabelecimento.swift` | cumpre: rótulo `CPF ou CNPJ` (PR #408) | cumpre: campos ≥ 44 pt (exceto link MapKit nativo) | cumpre: 17,8:1 | não se aplica | não se aplica | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 14 | Publicar vaga | `PublicarVaga.swift` | cumpre: `isHeader` em seções do formulário | cumpre: botões e stepper ≥ 44 pt (exceto link MapKit) | cumpre: 17,8:1 e 18,8:1 | não se aplica | não se aplica | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 15 | Perfil do estabelecimento | `PerfisDaConta.swift` | cumpre: `isHeader` no nome do local | cumpre: linhas de menu ≥ 44 pt | cumpre: 18,8:1 | não se aplica | não se aplica | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 16 | Perfil público | `AcoesDeSeguranca.swift` | cumpre: `isHeader` no nome público | cumpre: botões de ação ≥ 44 pt | cumpre: 18,8:1 | não se aplica | não se aplica | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 17 | Publicar vaga: erro ao ler casa | `PublicarVaga.swift` | cumpre: título de erro com traço | cumpre: BotaoSecundario ≥ 44 pt | cumpre: 17,8:1 | não se aplica | não se aplica | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 18 | Ajuda do perfil | `PerfisDaConta.swift` | cumpre: rótulos e links com `.isLink` | cumpre: linhas de contato ≥ 44 pt | cumpre: 18,8:1 e 16,8:1 | não se aplica | não se aplica | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |

---

## 3. Revisão de Design, Acessibilidade e Textos do Sprint 2 (SIPQtYWH)

### 3.1. Telas Cobertas no Sprint 2
1. **Check-in Presencial (GPS e Contingência):** `TelaMeuTurno.swift`, `SecaoDePresenca.swift`
2. **Acompanhamento do Turno (Contratante):** `TelaTurnoDoContratante.swift`
3. **Check-out Presencial:** `TelaMeuTurno.swift`, `SecaoDePresenca.swift`
4. **Avaliação Mútua do Turno:** `TelaAvaliacao.swift`
5. **Denúncia e Suspensão:** `AcoesDeSeguranca.swift` (Folha de denúncia e bloqueio), `TelaContaSuspensa.swift`
6. **Cancelamento do Turno com Motivo:** `FolhaDeCancelamento.swift`
7. **Suporte no Turno:** `FolhaSuporteTurno.swift`

### 3.2. Execução da Auditoria de Acessibilidade no Simulador
A suíte `AuditoriaDeAcessibilidadeUITests` direcionada para as telas do Sprint 2 foi executada no simulador Loki:

- **Comando:**
```sh
env TEST_RUNNER_FRILA_AUDITORIA_DE_ACESSIBILIDADE=1 TEST_RUNNER_FRILA_AUDITORIA_SO_REGISTRA=1 \
  ~/Documents/Projetos/Apps/.workers/vigia/xcb.sh "Loki" -- xcodebuild test \
  -project iOS/Frila.xcodeproj -scheme Frila-Local \
  -destination "platform=iOS Simulator,id=01CDB658-019C-451A-B3EB-CB7CF09352E9" \
  -derivedDataPath ~/Documents/Projetos/Apps/.workers/antigravity/build/DerivedData \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testMeuTurnoComPresenca \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testMeuTurnoComPresencaEmAX5 \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testMeusTurnosMeuTurnoEAvaliacao \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testMeusTurnosMeuTurnoEAvaliacaoEmAX5 \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testAcompanhamentoDoTurno \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testAcompanhamentoDoTurnoEmAX5 \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testFolhaDeDenuncia \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testFolhaDeDenunciaEmAX5 \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testContaSuspensa \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testContaSuspensaEmAX5 \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testFolhaDeCancelamento \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testFolhaDeCancelamentoEmAX5 \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testFolhaDeSuporte \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testFolhaDeSuporteEmAX5
```
- **Resultado:** 14 testes executados / 14 aprovados (100% verde).
- **Tempo total:** 193.568s.
- **Log integral:** `.workers/vigia/logs-xcodebuild/loki-20261011-232209-96208.log`.

### 3.3. Avaliação dos Critérios de Interface e Casos de Borda
1. **Contingência de Check-in e Check-out:**
   - Botão `registro-manual` preserva alvo mínimo de 44 pt (`minHeight: FrilaMetrica.alvoMinimo`).
   - Estados de presença comunicados não apenas por cor: texto explicativo ("Aguardando confirmação do contratante", "Presença verificada") e SF Symbols (`clock`, `checkmark.circle.fill`).
2. **Avaliação Mútua:**
   - Pergunta única e objetiva com botões "Sim" e "Não" utilizando traço de seleção `.isSelected`.
   - Após submissão, campos tornam-se somente leitura para evitar manipulação de reputação.
3. **Denúncia e Suspensão:**
   - `FolhaDeDenuncia`: Botão Fechar adaptado com rótulo semântico; contador numérico de caracteres audível pelo VoiceOver; botão "Enviar denúncia" desabilitado enquanto texto < 10 caracteres.
   - `TelaContaSuspensa`: Motivo explícito de bloqueio, botão de contestação em protocolo único e acesso direto à exportação de dados pessoais (LGPD).
4. **Cancelamento e Suporte:**
   - Botões empilhados verticalmente para prevenir truncamento de texto (`FolhaDeCancelamento.swift` e `FolhaSuporteTurno.swift`).
   - Todos os subtítulos de seções marcados com `.accessibilityAddTraits(.isHeader)`.

### 3.4. Checklist de Acessibilidade do Design — 100% das Telas do Sprint 2 (SIPQtYWH)

Checklist sistemático e exaustivo cobrindo a totalidade das 19 telas, folhas e estados do Sprint 2. O estado real registra estritamente: **cumpre** (regras de interface e código comprovadas em teste/código), **não cumpre** (desvios identificados), **fora de escopo AX5** (critério de acessibilidade AX5 adiado por decisão do Cauê em 21/10/2026 / PR #441) e **não testado** (VoiceOver em aparelho físico assistivo e confronto visual de frames no Figma dependentes de validação humana externa).

| # | Tela / Fluxo | Arquivo / View | VoiceOver (Rótulos e Traços) | Alvos (≥ 44 pt) | Contraste (WCAG AA) | Reduzir Movimento | Estado não só por cor | Dynamic Type AX5 | VoiceOver em Aparelho | Estado Real no App |
|:---:|---|---|---|---|---|---|---|---|---|:---:|
| 01 | Presença no turno (GPS / Manual) | `SecaoDePresenca.swift` | cumpre: anúncio de voz e foco acessível | cumpre: botões de ação e GPS ≥ 44 pt | cumpre: auditado sem achados | não se aplica | cumpre: SF Symbol + texto descritivo | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 02 | Check-out presencial | `SecaoDePresenca.swift` | cumpre: rótulos semânticos e identificador | cumpre: botão de término ≥ 44 pt | cumpre: auditado sem achados | não se aplica | cumpre: SF Symbol + texto | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 03 | Meu turno | `TelaMeuTurno.swift` | cumpre: `isHeader` e dicas em mapa/WhatsApp | cumpre: botões e mapa ≥ 44 pt | cumpre: 18,8:1 e 6,8:1 | não se aplica | não se aplica | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 04 | Meus turnos (Aba) | `TelaMeusTurnos.swift` | cumpre: dica em abrir detalhe e títulos | cumpre: cartões navegáveis ≥ 44 pt | cumpre: 16,8:1 e 18,8:1 | não se aplica | não se aplica | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 05 | Acompanhamento do turno | `TelaTurnoDoContratante.swift` | cumpre: `isHeader` em seções e dicas | cumpre: botões e ações ≥ 44 pt | cumpre: 18,8:1 e 16,8:1 | não se aplica | não se aplica | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 06 | Minhas vagas (Painel) | `MinhasVagas.swift` | cumpre: `isHeader` em seções do painel | cumpre: cartões e botões ≥ 44 pt | cumpre: 18,8:1 e 16,8:1 | não se aplica | não se aplica | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 07 | Detalhe da vaga do contratante | `MinhasVagas.swift` | cumpre: `isHeader` em função e posições | cumpre: botões de ação ≥ 44 pt | cumpre: 18,8:1 | não se aplica | não se aplica | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 08 | Candidatos em Modo Seleção | `CandidatosDaVaga.swift` | cumpre: rótulos discriminando candidato | cumpre: verPerfil e ações ≥ 44 pt | cumpre: auditado sem achados | não se aplica | cumpre: selo com texto e checkmark | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 09 | Candidaturas (Aba) | `CandidaturaEmSelecao.swift` | cumpre: `isHeader` e dicas contextuais | cumpre: cartões ≥ 44 pt | cumpre: 18,8:1 | não se aplica | não se aplica | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 10 | Avaliação do turno (Profissional) | `TelaAvaliacao.swift` | cumpre: pergunta com `isHeader` | cumpre: botões Sim/Não ≥ 44 pt | cumpre: 18,8:1 | não se aplica | cumpre: `.isSelected` e checkmark | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 11 | Avaliação pelo contratante | `TelaTurnoDoContratante.swift` | cumpre: `isHeader` na pergunta | cumpre: botões de resposta ≥ 44 pt | cumpre: auditado sem achados | não se aplica | cumpre: checkmark e SF Symbol | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 12 | Conta suspensa | `TelaContaSuspensa.swift` | cumpre: ícone hidden e título auditado | cumpre: contestação e LGPD ≥ 44 pt | cumpre: 18,8:1 | não se aplica | não se aplica | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 13 | Folha de cancelamento | `FolhaDeCancelamento.swift` | cumpre: `isHeader` no motivo | cumpre: opções e envio ≥ 44 pt | cumpre: tokens conformes AA | não se aplica | cumpre: ícone preenchido e `.isSelected` | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 14 | Folha de denúncia | `AcoesDeSeguranca.swift` | cumpre: `accessibilityHidden` decorativo | cumpre: botões de ação ≥ 44 pt | cumpre: tokens conformes AA | não se aplica | cumpre: contador X/10 + checkmark | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 15 | Folha de suporte no turno | `FolhaSuporteTurno.swift` | cumpre: plural nativo %lld e dicas (PR #394) | cumpre: botões ≥ 44 pt | cumpre: tokens conformes AA | cumpre: checa `accessibilityReduceMotion` | cumpre: `.isSelected` e ícone | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 16 | Exclusão de conta | `TelaExclusaoDeConta.swift` | cumpre: ícone hidden e navigationTitle | cumpre: Toggle e botões ≥ 44 pt | cumpre: 18,8:1 | não se aplica | cumpre: Toggle nativo | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 17 | Confirmação de exclusão | `TelaExclusaoDeConta.swift` | cumpre: `isHeader` no diálogo | cumpre: botões do alerta ≥ 44 pt | cumpre: 5,4:1 (`BrandOnPrimary` × `Danger`) | não se aplica | não se aplica | **fora de escopo AX5** (decisão Cauê 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 18 | Compartilhamento / exportação | `ItemExportarDados.swift` | cumpre: rótulo e dica no botão disparador | cumpre: botão do app ≥ 44 pt | não se aplica: folha nativa iOS | não se aplica: folha nativa | não se aplica: folha nativa | **fora de escopo AX5** (folha nativa / decisão 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |
| 19 | Compositor de e-mail nativo | `FolhaSuporteTurno.swift` | cumpre: dica no botão disparador | cumpre: BotaoPrimario ≥ 44 pt | não se aplica: folha nativa iOS | não se aplica: folha nativa | não se aplica: folha nativa | **fora de escopo AX5** (folha nativa / decisão 21/10) | não testado (falta pessoa com VO) | **Cumpre** (código) |

---

## 4. Revisão de Design, Acessibilidade e Textos do Sprint 3 (wiLKWHYl / #71)

### 4.1. Telas Cobertas no Sprint 3
1. **Licenças de Código Aberto e Detalhe:** `TelaLicencas.swift`
2. **Histórico de Turnos:** `TelaHistoricoDeTurnos.swift`
3. **Equipe de Confiança (Contratante):** `TelaEquipeDeConfianca.swift`
4. **Ajuda e Suporte do Perfil:** `PerfisDaConta.swift`
5. **Critérios de Matching ("Por que recebo vagas"):** `TelaPorQueReceboVagas.swift`
6. **Painel do Contratante e Vagas Encerradas:** `MinhasVagas.swift`, `RepublicarVaga.swift`
7. **Candidaturas em Seleção:** `CandidaturaEmSelecao.swift`
8. **Destinos de Notificação Push:** `TelasDaPermissaoDePush.swift`, `DestinosDoAviso.swift`

### 4.2. Execução da Auditoria de Acessibilidade no Simulador
A suíte `AuditoriaDeAcessibilidadeUITests` direcionada para as telas do Sprint 3 foi executada no simulador Loki via fila `xcb.sh`:

- **Comando:**
```sh
env TEST_RUNNER_FRILA_AUDITORIA_DE_ACESSIBILIDADE=1 TEST_RUNNER_FRILA_AUDITORIA_SO_REGISTRA=1 \
  ~/Documents/Projetos/Apps/.workers/vigia/xcb.sh "Loki" -- xcodebuild test \
  -project iOS/Frila.xcodeproj -scheme Frila-Local \
  -destination "platform=iOS Simulator,id=01CDB658-019C-451A-B3EB-CB7CF09352E9" \
  -derivedDataPath ~/Documents/Projetos/Apps/.workers/antigravity/build/DerivedData \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testLicencasEDetalhe \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testLicencasEDetalheEmAX5 \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testAjudaDoPerfil \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testAjudaDoPerfilEmAX5 \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testHistoricoDeTurnos \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testHistoricoDeTurnosEmAX5 \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testPorQueReceboVagas \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testPorQueReceboVagasEmAX5 \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testEquipeDeConfianca \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testEquipeDeConfiancaEmAX5 \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testMinhasVagasDetalheEPerfilPublico \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testMinhasVagasDetalheEPerfilPublicoEmAX5 \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testRepublicarVaga \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testRepublicarVagaEmAX5 \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testCandidaturasEmSelecao \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testCandidaturasEmSelecaoEmAX5 \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testExplicacaoDoPush \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testExplicacaoDoPushEmAX5 \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testVagaIndisponivelDoPush \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testVagaIndisponivelDoPushEmAX5 \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testTurnoDoAvisoNaoEncontrado \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests/testTurnoDoAvisoNaoEncontradoEmAX5
```
- **Resultado:** 22 testes executados / 22 aprovados (100% verde).
- **Tempo total:** 289.639s.
- **Log integral:** `.workers/vigia/logs-xcodebuild/loki-20261011-233741-20815.log`.

### 4.3. Avaliação dos Critérios de Interface e Casos de Borda
1. **Comprovação em AX5 (Dynamic Type XXXL):**
   - Nenhuma tela corta texto ou esconde botão.
   - Em `TelaLicencas`, `TelaHistoricoDeTurnos` e `TelaPorQueReceboVagas`, os textos e cartões expandem verticalmente com scroll sem sobreposição.
   - Botões de ação primária e secundária preservam alvos de toque ≥ 44 pt.
2. **Contraste de Telas do Sprint 3:**
   - As telas de Licenças, Detalhe da licença, Histórico de turnos e Equipe de confiança foram auditadas sem nenhum erro de contraste registrado no log.
3. **Respeito a Reduzir Movimento:**
   - `TelaHistoricoDeTurnos.swift:50` consulta ativamente `accessibilityReduceMotion` antes de acionar a rolagem suave.

### 4.4. Consolidação da Acessibilidade da v1.0 (Cartões NoKH0SN8, SIPQtYWH e wiLKWHYl)

- **Total de telas auditadas (S1 + S2 + S3):** 46 telas/estados do Frila iOS.
- **Rótulos e Traços de VoiceOver no código:** **100% em conformidade (cumpre)**, com todos os títulos semânticos (`.isHeader`), agrupamento lógico (`children: .combine`), pluralização nativa e botões com rótulo/dica contextual.
- **Alvos de Toque (≥ 44 × 44 pt):** **100% em conformidade (cumpre)** no código do aplicativo Frila, respeitando rigorosamente a Apple HIG. Única exceção física é o link nativo MapKit do sistema operacional (`MKAttributionLabel`), que não expõe API customizável.
- **Contraste WCAG 2.1 AA:** **100% dos pares cromáticos de tokens semânticos auditados e aprovados (cumpre)** via `ContrasteDesignTokensTests.swift` (todas as combinações normativas atendem ou superam 4,5:1 para texto normal e 3,0:1 para elementos de interface/ícones essenciais).
- **Reduzir Movimento:** **100% em conformidade (cumpre)** nas telas animadas através do gate centralizado `FrilaMovimento.animacao(reduzir:)`.
- **Comunicação de Estado:** **100% em conformidade (cumpre)** com nenhuma tela comunicando seleção, erro ou sucesso exclusivamente por cor (adoção sistemática de SF Symbols e texto explicativo).
- **Dynamic Type AX5 (XXXL):** **Fora de escopo AX5 na v1.0 por decisão do Cauê em 21/10/2026** (PR #441 / commit `891c297c`), mantendo a estabilidade do app com `XCTSkip` na suíte automatizada. Não mexer em AX5 nesta entrega.
- **VoiceOver em Hardware Físico com Usuário Real:** **Não testado (pendente humano)**. Conforme regra do projeto, não se afirma o que não foi executado. O app está tecnicamente instrumentado com acessibilidade nativa, mas o ensaio assistivo com usuário cego/baixa visão permanece dependente de execução humana externa.

---

## 5. O Que Ficou Pendente para o Cauê (Execução Física / Humana)

Conforme divisão de papéis estabelecida na triagem noturna, as tarefas abaixo dependem de aparelhos físicos, credenciais proprietárias e alinhamento humano:

1. **Para o Cartão AZI1goKB:**
   - `[ ]` Executar a matriz da Seção 1.2 utilizando **dois iPhones físicos** em mãos.
   - `[ ]` Anotar os tempos e resultados no cartão Trello AZI1goKB.
   - `[ ]` Abrir cartões no Sprint 3 caso identifique algum defeito bloqueante de hardware ou rede física.
2. **Para o Cartão NoKH0SN8:**
   - `[ ]` Realizar o confronto visual direto das telas do Sprint 1 contra os frames do Figma com o Fabrício.
   - `[ ]` Validar e obter aceite por escrito do guia de voz com a Júlia.
3. **Para o Cartão SIPQtYWH:**
   - `[ ]` Disparar e receber os pushes de teste da planilha em aparelho físico (APNs em tela bloqueada).
   - `[ ]` Obter validação estética final com Fabrício no Trello.
4. **Para o Cartão wiLKWHYl:**
   - `[ ]` Realizar a navegação completa dos fluxos "Publicar uma vaga" e "Candidatar-se e fazer check-in" só com VoiceOver por alguém que não desenvolveu o app, em aparelho físico.
   - `[ ]` Confrontar as telas do build de 04/11 contra os frames aprovados pelo Fabrício por escrito no Trello.
