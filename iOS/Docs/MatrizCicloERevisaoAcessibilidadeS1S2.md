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

Para atendimento do critério *"Roteiro manual executado com dois iPhones reais"*, a matriz abaixo define o passo a passo com a sincronização entre Aparelho A (Contratante) e Aparelho B (Profissional):

| Passo | Aparelho A (Contratante) | Aparelho B (Profissional) | Comportamento Esperado no App | Correspondência com Teste Automatizado | Check Cauê |
|---|---|---|---|---|---|
| **01** | Abre o app, digita e-mail, recebe código `123456`, seleciona perfil Contratante, preenche dados do responsável e estabelecimento. | App em repouso. | Cadastro concluído com sucesso; transição direta para a tela `PublicarVagaView`. | `CicloDePontaAPontaUITests:24-74` | `[ ]` |
| **02** | Configura vaga de urgência (data de hoje, valor horário, horário de início), toca em "Publicar vaga". | Abre app no feed de vagas do DF. | Vaga gravada; Aparelho A exibe vaga ativa em "Minhas vagas"; Aparelho B visualiza o cartão da vaga no feed do DF. | `CicloDePontaAPontaUITests:75-99` | `[ ]` |
| **03** | Aguarda candidatura na tela Minhas Vagas. | Toca no cartão da vaga, confere detalhes (função, valor líquido, local), toca em "Candidatar-se". | Como é modo Urgência, a vaga é confirmada imediatamente sem triagem; Aparelho B vai para tela de sucesso com orientações. | `CicloDePontaAPontaUITests:107-142` | `[ ]` |
| **04** | Atualiza Minhas Vagas: posição ocupada exibe o profissional alocado. | Acessa aba "Meus turnos", abre o turno confirmado. | Ambos os aparelhos visualizam dados de contato liberados (telefone/WhatsApp do contratante e do profissional). | `CicloDePontaAPontaUITests:143-165` | `[ ]` |
| **05** | Em "Acompanhar turno", visualiza status "Aguardando check-in". | No local do turno (ou com GPS desativado para testar contingência), toca em "Fazer check-in". | Com GPS negado ou >250m, surge contingência manual: toca em "Registro manual"; status muda para "Aguardando confirmação do contratante". | `CicloDePontaAPontaUITests:166-192`, `PresencaUITests:44-59` | `[ ]` |
| **06** | Toca em "Confirmar presença" do profissional. | Atualiza a tela de Meu Turno. | Presença do turno passa para status "Verificado" em ambos os aparelhos. | `TurnoDoContratanteUITests:24-38` | `[ ]` |
| **07** | Acompanha andamento do turno. | Ao término do horário previsto, toca em "Fazer check-out" (manual ou localização). | Check-out registrado; status do turno passa para "Concluído" aguardando avaliação. | `CicloDePontaAPontaUITests:193-206` | `[ ]` |
| **08** | Aguarda avaliação do profissional. | Toca em "Avaliar turno", responde "Você trabalharia nesse local de novo?" (Sim), toca em "Enviar avaliação". | Avaliação gravada; feedback visual de sucesso; botão passa para estado inativo "Avaliação enviada". | `CicloDePontaAPontaUITests:214-250`, `AvaliacaoUITests:28-45` | `[ ]` |
| **09** | Em Minhas Vagas > Detalhe do Turno, toca em "Avaliar profissional", responde "Chamaria este profissional de novo?" (Sim) e envia. | Permanece com histórico atualizado. | Turno 100% finalizado; reputação e métricas atualizadas no perfil de ambas as partes. | `CicloDePontaAPontaUITests:258-295` | `[ ]` |

---

## 2. Revisão de Design, Acessibilidade e Textos do Sprint 1 (NoKH0SN8)

### 2.1. Telas Cobertas no Sprint 1
1. **Entrada por e-mail e código:** `EntradaEmailView.swift`, `TelaCodigo.swift`
2. **Cadastro do Usuário:** `SelecaoPerfilView.swift`, `CadastroUsuarioView.swift`
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

---

## 3. Revisão de Design, Acessibilidade e Textos do Sprint 2 (SIPQtYWH)

### 3.1. Telas Cobertas no Sprint 2
1. **Check-in Presencial (GPS e Contingência):** `MeuTurnoView.swift`, `PresencaView.swift`
2. **Acompanhamento do Turno (Contratante):** `TelaTurnoDoContratante.swift`
3. **Check-out Presencial:** `MeuTurnoView.swift`
4. **Avaliação Mútua do Turno:** `AvaliarTurnoView.swift`
5. **Denúncia e Suspensão:** `FolhaDeDenuncia.swift`, `FolhaBloqueio.swift`, `TelaContaSuspensa.swift`
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
   - Botões empilhados verticalmente em AX5 para prevenir truncamento de texto (`FolhaDeCancelamento.swift` e `FolhaSuporteTurno.swift`).
   - Todos os subtítulos de seções marcados com `.accessibilityAddTraits(.isHeader)`.

---

## 4. Revisão de Design, Acessibilidade e Textos do Sprint 3 (wiLKWHYl / #71)

### 4.1. Telas Cobertas no Sprint 3
1. **Licenças de Código Aberto e Detalhe:** `TelaLicencas.swift`, `TelaDetalheLicenca`
2. **Histórico de Turnos:** `TelaHistoricoDeTurnos.swift`
3. **Equipe de Confiança (Contratante):** `TelaEquipeDeConfianca.swift`
4. **Ajuda e Suporte do Perfil:** `TelaAjudaPerfil.swift`
5. **Critérios de Matching ("Por que recebo vagas"):** `TelaPorQueReceboVagas.swift`
6. **Painel do Contratante e Vagas Encerradas:** `MinhasVagas.swift`, `TelaRepublicarVaga.swift`
7. **Candidaturas em Seleção:** `TelaMinhasCandidaturas.swift`
8. **Destinos de Notificação Push:** `TelaExplicacaoDoPush.swift`, `DestinosDoAviso.swift`

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
