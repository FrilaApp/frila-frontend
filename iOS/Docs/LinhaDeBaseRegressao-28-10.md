# Linha de Base do XCUITest do Caminho Feliz e Pré-Auditoria da Regressão Final

**Data:** 28/10/2026  
**Cartões Trello de Referência:**
- [6ab26a00](https://trello.com/c/6ab26a00) — Correções dos testes de usabilidade
- [6ab26a32](https://trello.com/c/6ab26a32) — Regressão final e checklist das diretrizes da App Store (antigo [5Lx5v39r](https://trello.com/c/5Lx5v39r))  
**Branch de Trabalho:** `docs/linha-de-base-regressao-28-10`  
**Commit Base:** `39b1a1c4` (origin/main em 28/10/2026)  
**Ambiente de Execução (saída literal dos comandos):**
- `$ xcodebuild -version`:
  ```text
  Xcode 27.0
  Build version 27A266a
  ```
- `$ sw_vers`:
  ```text
  ProductName:		macOS
  ProductVersion:		27.0.1
  BuildVersion:		26A434
  ```
- `$ xcrun simctl list runtimes | grep -i ios`:
  ```text
  iOS 18.4 (18.4 - 22E238) - com.apple.CoreSimulator.SimRuntime.iOS-18-4
  iOS 26.5 (26.5 - 23F77) - com.apple.CoreSimulator.SimRuntime.iOS-26-5
  ```
- **Simulador Utilizado:** `iPhone 17 Pro` (iOS 26.5, UDID `C5723206-4177-45B9-9496-7EA46550F215`), reservado sob controle da fila de recursos `orquestracao/scripts/fila.sh` (`simulador-1`).

---

## 1. Linha de Base do XCUITest do Caminho Feliz

A suíte oficial automatizada que cobre o caminho feliz de operação do Frila no cliente iOS é a **`CicloDePontaAPontaUITests`** (alvo `FrilaUITests`, esquema `Frila-Local`), conforme documentado na matriz de usabilidade e regressão (`iOS/Docs/TriagemUsabilidadeERegressao.md:3`).

O ciclo é validado exclusivamente em quatro etapas encadeadas pelo estado local:
1. **`test01_ContratantePublicaVagaUrgenciaEVeEmMinhasVagas`:** Primeiro acesso do contratante, cadastro pessoal, cadastro do estabelecimento, publicação de vaga em urgência e verificação no painel *Minhas vagas*.
2. **`test02_ProfissionalCandidataContatoECheckinManualECheckout`:** Profissional localiza vaga no DF, candidata-se com confirmação imediata de urgência, acessa *Meu turno*, consulta contato liberado, executa check-in manual (contingência sem GPS) e realiza check-out.
3. **`test03_ProfissionalAvaliaTurnoConcluido`:** Profissional avalia o turno concluído ("Você trabalharia nesse local de novo?").
4. **`test04_ContratanteVeTurnoConcluido`:** Contratante vê turno concluído com presença verificada no painel e constata o estado pós-turno.

### 1.1 Resultados das Duas Execuções Consecutivas no Simulador

Conforme exigido pelo brief F-005, a suíte foi executada **duas vezes** consecutivas no simulador sob reserva exclusiva via `fila.sh pegar simulador`:

```bash
# Execução 1
xcodebuild test \
  -scheme Frila-Local \
  -destination "platform=iOS Simulator,id=C5723206-4177-45B9-9496-7EA46550F215" \
  -only-testing:FrilaUITests/CicloDePontaAPontaUITests \
  -resultBundlePath build/Resultados/CicloDePontaAPonta-exec1.xcresult

# Execução 2
xcodebuild test \
  -scheme Frila-Local \
  -destination "platform=iOS Simulator,id=C5723206-4177-45B9-9496-7EA46550F215" \
  -only-testing:FrilaUITests/CicloDePontaAPontaUITests \
  -resultBundlePath build/Resultados/CicloDePontaAPonta-exec2.xcresult
```

| Métrica / Teste | Execução 1 (Fria / Compilação) | Execução 2 (Quente) | Veredito |
|---|:---:|:---:|:---:|
| `test01_ContratantePublicaVagaUrgenciaEVeEmMinhasVagas` | 69,833 s (passou) | 67,932 s (passou) | **PASS** |
| `test02_ProfissionalCandidataContatoECheckinManualECheckout` | 37,963 s (passou) | 37,948 s (passou) | **PASS** |
| `test03_ProfissionalAvaliaTurnoConcluido` | 25,584 s (passou) | 25,612 s (passou) | **PASS** |
| `test04_ContratanteVeTurnoConcluido` | 35,742 s (passou) | 35,670 s (passou) | **PASS** |
| **Tempo Total de Testes Executados** | **169,122 s** (~2 min 49 s) | **167,161 s** (~2 min 47 s) | **100% PASS** |
| **Tempo Total do Processo (xcodebuild elapsed)** | 173,924 s | 168,921 s | **ESTÁVEL** |
| **Resultado Consolidado** | `** TEST SUCCEEDED **` | `** TEST SUCCEEDED **` | **ZERO FALHAS** |
| **Caminho do Pacote .xcresult** | `iOS/build/Resultados/CicloDePontaAPonta-exec1.xcresult` | `iOS/build/Resultados/CicloDePontaAPonta-exec2.xcresult` | Válido |

> **Conclusão da Linha de Base:** Os 4 cenários encadeados de UI encontram-se **100% funcionais e reprodutíveis no simulador**, sem timeout ou quebra de fluxo nos quatro testes executados.
>
> [!IMPORTANT]
> **Limite do Alcance da Prova (Dublê em Memória):** A suíte `CicloDePontaAPontaUITests` é executada com o dublê em memória nativo do cliente (`ApiClienteEmMemoria`). Essa prova é estritamente de interface e apresentação: **NÃO prova o backend real (Supabase e Edge Functions), NÃO prova o ciclo integrado real entre duas contas distintas em rede e NÃO comprova implantação em ambiente de Produção**. A validação do backend real e de ponta a ponta depende de scripts de fumaça da API (`scripts/fumaca-v1.sh`) e testes em aparelhos físicos.

---

## 2. Pré-Auditoria das Diretrizes da App Store (Cartão 6ab26a32)

**Origem da Matriz dos 27 Itens:** A matriz de auditoria tem como base oficial os documentos versionados do repositório:
- As **26 linhas da matriz oficial** em `iOS/Docs/ChecklistDiretrizesAppStore.md` (onde a triagem de 12/10 identificou 21 conformidades por código/testes e 5 dependentes de ações de pessoas);
- O **27º item**: O identificador de dispositivo restrito a notificações em `PrivacyInfo.xcprivacy:120–130` e `AparelhoDePush.swift:10–133`.
Esses 27 itens cruzam as 11 famílias de diretrizes da Apple (1.1, 1.2, 1.5, 2.1, 2.3, 3.1, 4.0/4.2, 4.8, 5.1.1, 5.1.2 e ECA Digital) com os metadados em `iOS/Docs/FichaAppStore.md`.

### 2.1 Matriz de Verificação dos 27 Itens

**Distinção de Fontes:**
- **Executado (2x no simulador):** Os 4 cenários encadeados de UI em `CicloDePontaAPontaUITests` (Seção 1).
- **Auditado por Código (análise estática arquivo:linha):** Os 27 itens foram verificados e comprovados por leitura estática linha a linha dos arquivos de produção e testes no commit `39b1a1c4`. Citações não confirmadas foram marcadas como "não verificado".
- **Implantação em Produção:** Marcada explicitamente como **não verificada** (não acessível por testes locais ou leitura de código).

Legenda de status:
- **continua OK**: Implementação ou teste confirmados em arquivo:linha válido na `main` atual.
- **mudou**: Estado alterado em relação à auditoria anterior (avanço ou regressão identificada e detalhada).
- **não verificado**: Sem arquivo:linha válido ou sem possibilidade de prova local.

| # | Diretriz Apple | Requisito / Tema | Evidência no Código (`iOS/Sources/`) | Evidência nos Testes (`iOS/Tests/`) | Situação na `main` | Análise e Evidência Atual (comprovada por leitura) |
|:---:|---|---|---|---|:---:|---|
| 1 | **1.1 / 1.1.1** | Proibição de Conteúdo Ofensivo | `AcoesDeSeguranca.swift:34` | `SegurancaDoCodigoTests.swift:15` | **continua OK** | Termos de uso e categorias de denúncia cobrem ofensas e difamação sem alterações. |
| 2 | **1.2** | Mecanismo de Denúncia e Bloqueio (UGC) | `AcoesDeSeguranca.swift:20–55`<br>`SegurancaViewModel.swift:20–55` | `SegurancaUITests.swift:20`<br>`SegurancaViewModelTests.swift:30` | **continua OK** | Denúncia com seleção de motivos, atalhos de emergência e bloqueio definitivo presentes. |
| 3 | **1.2** | Aceite Obrigatório de Termos no Cadastro | `TelaCadastro.swift:150`<br>`CadastroViewModel.swift:104–108` | `AutenticacaoTests.swift:275` | **continua OK** | Botão `cadastro-termos` e validação prévia à chamada da API mantidos intactos. |
| 4 | **1.5** | Suporte ao Desenvolvedor / Contato Publicado | `PerfisDaConta.swift:390`<br>`EnderecosOficiais.swift:22` | `AppPrivacyTests.swift:45–65` | **mudou** | **Avanço:** O checklist anterior (18/10) marcava "Pendente merge PR #301". O PR #301 foi mesclado em 16/10 (`AppPrivacyTests.swift` ativo). A unificação do e-mail oficial em `suporte@frilabr.com` foi estruturada na proposta do PR #107 / #544. |
| 5 | **2.1** | Contas de Demonstração para App Review | `DestinoAposEntrada.swift:92–97`<br>`EntradaViewModel.swift:37` | `AutenticacaoTests.swift:115–140` | **mudou** | **Avanço no Backend / Pendência na Ficha:** O backend implementou a Edge Function `entrar-demonstracao`. O app reconhece o desvio. Porém, os campos de e-mail e telefone na ficha (`FichaAppStore.md:182, 188–195`) continuam como `[A DEFINIR]`. |
| 6 | **2.1** | Ausência de Telas Provisórias / Placeholders | `CatalogoDesignSystem.swift:1` | `SegurancaDoCodigoTests.swift:68–91`<br>`conferir-textos.sh` | **continua OK** | Catálogo do design system estritamente isolado sob `#if DEBUG`. |
| 7 | **2.3 / 2.3.1** | Metadados Precisos e Sem Promessas de Tempo | `Localizable.xcstrings`<br>`FichaAppStore.md:11–108` | `conferir-textos.sh` | **continua OK** | Texto auditado; ausência de promessas de tempo ("em minutos") e sem termos proibidos. |
| 8 | **2.3.7** | Nome, Subtítulo e Keywords dentro dos Limites | `FichaAppStore.md:31–53` | `conferir-textos.sh` | **continua OK** | Nome: 21 car. ($\le 30$); Subtítulo: 25 car. ($\le 30$); Keywords: 97 bytes UTF-8 ($\le 100$ bytes). Sem concorrentes ou "grátis". |
| 9 | **3.1.1 / 3.1.3(e)** | IAP Dispensado (Serviços no Mundo Físico) | `Portas.swift:312`<br>`FichaAppStore.md:17` | `PeriodoTests.swift:47` | **continua OK** | Intermediação de trabalho presencial com acerto direto no local sem retenção de comissão (RN01); enquadrado na exceção formal 3.1.3(e). |
| 10 | **4.0 / 4.2** | Design Nativo e Alvos de Toque $\ge 44 \times 44$ pt | `DesignTokens.swift:10–50` | `AuditoriaDeAcessibilidadeUITests.swift:45` | **continua OK** | Alvos mínimos padronizados via `FrilaMetrica.alturaDoCampo` (44 pt). |
| 11 | **4.0 / 4.2** | Respeito a Reduzir Movimento (Reduce Motion) | `DesignTokens.swift:169, 179`<br>`FrilaListaInclusos.swift:111, 249` | `conferir-movimento.sh` | **mudou** | **Regressão pontual na main corrigida no PR #546:** O PR #539 havia introduzido `withAnimation` direto em `FrilaListaInclusos.swift:118, 261`, violando `conferir-movimento.sh`. A correção foi feita no PR #546 via `FrilaMovimento.animacao(_:reduzir:)`, com passo de movimento verde na CI (Run 40642217304). |
| 12 | **4.2** | Padrões de Estado e Resiliência Offline | `EstadosDeTela.swift:3–48` | `ModoAviaoUITests.swift:15` | **continua OK** | Estados visuais padronizados (`EstadoCarregando`, etc.) implementados e verificados. |
| 13 | **5.1.1(i)** | Política de Privacidade no App e na Web | `EnderecosOficiais.swift:21` | `AppPrivacyTests.swift:45–65` | **continua OK** | URL segura HTTPS `https://frila.netlify.app/privacidade` configurada e acessível in-app. |
| 14 | **5.1.1(v)** | Exclusão de Conta In-App (Account Deletion) | `TelaExclusaoDeConta.swift:5–248`<br>`PerfisDaConta.swift:215, 321` | `ExclusaoDeContaUITests.swift:16`<br>`LimpezaAposExclusaoTests.swift:30` | **continua OK** | Acesso direto no nível raiz nos dois perfis, diálogo confirmatório e identificador `botao-excluir-conta-definitivo`. |
| 15 | **5.1.1(iii)** | Minimização de Dados e Permissões Opcionais | `PresencaDoTurnoViewModel.swift:9, 41, 115–118`<br>`AparelhoDePush.swift:10–133` | `PresencaUITests.swift:25` | **continua OK** | Permissão de localização opcional (check-in manual em contingência sem GPS); push opcional (registro passivo sem bloqueio). |
| 16 | **5.1.2** | Manifesto de Privacidade (`PrivacyInfo.xcprivacy`) | `PrivacyInfo.xcprivacy:5–8` | `AppPrivacyTests.swift:15–44`<br>`conferir-release.sh` | **continua OK** | `NSPrivacyTracking = false`, array de domínios vazio e categorias funcionais declaradas. |
| 17 | **5.1.2(i)** | Finalidades Declaradas dos Dados Coletados | `PrivacyInfo.xcprivacy:18–21, 126–129, 150–153` | `AppPrivacyTests.swift:15–44` | **continua OK** | Finalidades mapeadas no manifesto: dados cadastrais/diagnósticos/DeviceID com `AppFunctionality`, e `ProductInteraction` (linhas 150–153) declarado com `Analytics`. |
| 18 | **2.5.4 / 5.1.2** | Push Notifications Opcionais e com Consentimento Prévio | `AparelhoDePush.swift:13, 88–89` | `AparelhoDePushTests.swift` | **continua OK** | Sem token, nenhum registro é enviado ao servidor; aparelho opera sem push sem degradação. |
| 19 | **5.1.2** | Não Rastreamento (App Tracking Transparency dispensado) | `PrivacyInfo.xcprivacy:5–8` | `AppPrivacyTests.swift` | **continua OK** | Rastreamento explicitamente falso; dispensado o diálogo de ATT da Apple. |
| 20 | **4.8** | Login com Apple (Dispensa Justificada) | `FichaAppStore.md:120–123`<br>`ChecklistDiretrizesAppStore.md:53` | Leitura documental | **continua OK** | Autenticação exclusiva por e-mail com OTP sem provedores sociais de terceiros (Google/Facebook), dispensando SignIn with Apple conforme exceção 4.8. |
| 21 | **2.1** | Autenticação em Duas Etapas / Código de Acesso | `DestinoAposEntrada.swift:92–97`<br>`EntradaViewModel.swift:37` | `AutenticacaoTests.swift:115–140` | **continua OK** | Fluxo de código por e-mail implementado; desvio de demonstração ativo em código. |
| 22 | **2.3.6** | Classificação Indicativa 18+ (ECA Digital) | `Classificacao18ECA.md:10–80`<br>`FichaAppStore.md:133–171` | `AutenticacaoTests.swift:286–340` | **continua OK** | Sinal de idade (faixa, método e instante) integrado no cadastro; questionário para override 18+ documentado. |
| 23 | **1.2 / 5.1.1** | Moderação de Conteúdo e Prazos de Resposta | `FichaAppStore.md:206–230` | Leitura documental | **continua OK** | Canais de denúncia e prazos documentados na ficha (triagem em 5 dias úteis, resposta em 15 dias corridos; prazo de 24 h: sem fonte comprovada). |
| 24 | **2.1 / 4.2** | Integridade Cadastral (Validação de CPF e CNPJ) | `CampoMascara.swift:7`<br>`CadastroEstabelecimento.swift:12, 34–35` | `CadastroEstabelecimentoUITests.swift:363–392`<br>`CampoMascaraTests.swift` | **continua OK** | Validação sequencial de CPF/CNPJ, máscara e bloqueio de duplicidade in-app. |
| 25 | **2.1 / 4.2** | Prevenção de Conflito de Agendas (Sobreposição de Turnos) | `CandidaturaViewModel.swift:182`<br>`TelasDaCandidatura.swift:314` | `FrilaUITests.swift:420`<br>`PeriodoTests.swift:47` | **continua OK** | Tratamento do erro `inelegivel/turno_sobreposto` e verificação da mensagem `resultado-turno-sobreposto`. |
| 26 | **2.1** | Resiliência contra Queda de Conexão | `ApiClienteEmMemoria.swift:1274` | `ModoAviaoUITests.swift:15`<br>`ModoAviaoMeuTurnoTests.swift` | **continua OK** | App entra em modo offline gracioso sem crash ou tela travada na perda de rede. |
| 27 | **5.1.2** | Identificador de Dispositivo Restrito a Notificações | `PrivacyInfo.xcprivacy:120–130`<br>`AparelhoDePush.swift:10–133` | `NotificationServiceTests.swift:95`<br>`AparelhoDePushTests.swift` | **continua OK** | DeviceID (linhas 120–130 do manifesto) coletado exclusivamente para `NSPrivacyCollectedDataTypePurposeAppFunctionality`. |

---

## 2.2 Auditoria da 1 Falha (Comentário Loki / Cartão 6ab26a32)

- **Falha Apontada:** A ficha da loja (`iOS/Docs/FichaAppStore.md:182, 188–195`) continha campos essenciais marcados como `[A DEFINIR]`:
  - Telefone de contato de revisão: `[A DEFINIR]` (linha 182).
  - Conta de demonstração profissional (E-mail e OTP fixo): `[A DEFINIR]` (linhas 188–189).
  - Conta de demonstração contratante (E-mail e OTP fixo): `[A DEFINIR]` (linhas 192–193).
- **Conferência na `main` Atual (`39b1a1c4`):**
  - O arquivo `iOS/Docs/FichaAppStore.md` **continua com as marcações `[A DEFINIR]`**.
  - **Evolução Técnica:** A nota da ficha que dizia "depende de cartão do backend (OTP fixo)" está superada: a Edge Function `entrar-demonstracao` já foi implantada no backend e o app reconhece o desvio. Falta a definição cadastral dos e-mails e telefone e a inserção desses dados na ficha por Cauê.
- **Veredito:** **Falha confirmada na documentação da ficha; não impede testes locais de UI, mas bloqueia a submissão final ao App Store Review.**

---

## 2.3 Auditoria dos 5 Riscos (Comentário Loki / Cartão 6ab26a32)

| Risco | Descrição Original do Loki | Estado na `main` / Repositório | Ação Restante / Responsável |
|:---:|---|---|---|
| **Risco 1** | **Semente e segredo da demonstração no ambiente Prod** | No iOS, `DestinoAposEntrada.swift:92` reconhece as contas. No backend, a função `entrar-demonstracao` existe. No entanto, a semeadura real dessas contas em Produção **não foi verificada** nesta análise local. | **Pendente (Infra/Backend):** Matheus/Jotapê confirmarem e provarem a semeadura no banco de produção. |
| **Risco 2** | **Capturas de tela de 6,9" e vídeo de demonstração** | `CapturasDesignD01UITests.swift` gera capturas no simulador, mas as imagens finais aprovadas no formato 6,9" (iPhone 16/17 Pro Max) e o vídeo de demonstração não constam finalizados no repositório. | **Pendente (Design/Humano):** Fabrício e Cauê aprovarem as frases e exportarem os assets finais. |
| **Risco 3** | **Notas de moderação (SLA de UGC / Diretriz 1.2)** | `FichaAppStore.md:206` informa triagem em até 5 dias úteis e resposta em até 15 dias corridos. O cartão 5Lx5v39r citava tratar conteúdo em 24 h (afirmação de que revisores exigem 24 h: **sem fonte comprovada**). | **Pendente (Decisão Regulatória):** Cauê avaliar a conciliação dos prazos da ficha e manter justificativa formal. |
| **Risco 4** | **Classificação indicativa 18+ (ECA Digital)** | O questionário da Apple calcula 4+, exigindo o *Override to Higher Age Rating: 18+* (A18 no Brasil). `Classificacao18ECA.md` e `FichaAppStore.md:133-171` documentam as respostas completas. | **Pronto na documentação; pendente de aplicação manual no portal App Store Connect por Cauê.** |
| **Risco 5** | **12 Declarações do App Privacy no App Store Connect** | Mapeamento técnico concluído em `AppPrivacyAppStoreConnect.md`. A `main` classifica telemetria no manifesto como `AppFunctionality`. O PR #104 (frila-docs, rascunho) distingue o uso estrito de Crashlytics/Diagnostics de eventuais dados analíticos (`OtherDataTypes`), mantendo a declaração como decisão do Cauê antes do preenchimento no App Store Connect. | **Pendente (Decisão do Dono):** Cauê ratificar a declaração antes do preenchimento no App Store Connect. |

---

## 3. Síntese Executiva para a PO e Sócios

1. **Caminho Feliz (XCUITest no Simulador):** Os 4 cenários encadeados de UI da suíte `CicloDePontaAPontaUITests` rodaram duas vezes com 100% de sucesso (tempo médio de 168 s, zero falhas), provando a solidez dos fluxos encadeados na camada de apresentação e modelos de visão locais. Conforme ressaltado, a execução utiliza dublê em memória (`ApiClienteEmMemoria`) e **não comprova integração com backend real nem implantação em Produção**.
2. **Conformidade com a App Store:** Dos 27 itens de conformidade, **24 continuam estritamente OK**, 3 apresentaram alterações comprovadas por leitura de código (duas evoluções positivas nos itens 4 e 5, e a regressão pontual do item 11 corrigida no PR #546).
3. **Bloqueios de Submissão:** A 1 falha na documentação da ficha (`[A DEFINIR]`) e os 5 riscos dependem de ações cadastrais, operacionais e de homologação externa ao app (além da correção do Reduzir Movimento no código tratada no PR #546). A implantação e semeadura em ambiente de Produção real constam como **não verificadas** localmente.
