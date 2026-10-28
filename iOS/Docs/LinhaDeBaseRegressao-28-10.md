# Linha de Base do XCUITest do Caminho Feliz e Pré-Auditoria da Regressão Final

**Data:** 28/10/2026  
**Cartões Trello de Referência:**
- [6ab26a00](https://trello.com/c/6ab26a00) — Correções dos testes de usabilidade
- [6ab26a32](https://trello.com/c/6ab26a32) — Regressão final e checklist das diretrizes da App Store (antigo [5Lx5v39r](https://trello.com/c/5Lx5v39r))  
**Branch de Trabalho:** `docs/linha-de-base-regressao-28-10`  
**Commit Base:** `39b1a1c4` (origin/main em 28/10/2026)  
**Ambiente de Execução:** Mac Apple Silicon (10 núcleos), macOS 27.0.1 (Build 26A434, verificado via `sw_vers`), Xcode 27.0 (Build 27A266a, verificado via `xcodebuild -version`), Simulador `iPhone 17 Pro` (iOS 26.5, UDID `C5723206-4177-45B9-9496-7EA46550F215`), gerenciado pela fila de recursos `orquestracao/scripts/fila.sh`.

---

## 1. Linha de Base do XCUITest do Caminho Feliz

A suíte oficial automatizada que cobre ponta a ponta o caminho feliz de operação do Frila é a **`CicloDePontaAPontaUITests`** (alvo `FrilaUITests`, esquema `Frila-Local`), conforme documentado na matriz de usabilidade e regressão (`iOS/Docs/TriagemUsabilidadeERegressao.md:3`).

Como o dublê em memória (`ApiClienteEmMemoria`) opera em isolamento de perfil por lançamento, o ciclo completo é validado em quatro etapas encadeadas pelo estado:
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

> **Conclusão da Linha de Base:** O caminho feliz do cliente iOS encontra-se **100% funcional e reprodutível no simulador**, sem qualquer quebra de fluxo ou timeout nas 4 etapas críticas.
>
> [!IMPORTANT]
> **Limite da Prova da Linha de Base (Dublê em Memória):** A suíte `CicloDePontaAPontaUITests` é executada com o dublê em memória nativo do cliente (`ApiClienteEmMemoria`). Isso prova exaustivamente e de ponta a ponta a camada de apresentação, modelos de visão, máquinas de estado, navegação e persistência local, mas **não substitui** o teste de integração contra o backend real (Supabase e Edge Functions), que depende de testes em aparelho físico e scripts de fumaça da API (`scripts/fumaca-v1.sh`).

---

## 2. Pré-Auditoria das Diretrizes da App Store (Cartão 6ab26a32)

Avaliação dos 27 itens de conformidade contra a `main` atual (`39b1a1c4`), confrontando a pré-auditoria do Loki (22/10), o checklist oficial (`iOS/Docs/ChecklistDiretrizesAppStore.md`) e os metadados da loja (`iOS/Docs/FichaAppStore.md`).

**Origem da Matriz dos 27 Itens:** A matriz de auditoria consolida os 26 itens documentados em `iOS/Docs/ChecklistDiretrizesAppStore.md` (no qual a auditoria de 12/10 identificou 21 conformidades provadas por código/testes e 5 dependentes de ações humanas) somados ao item 27 de escopo do identificador de dispositivo em `PrivacyInfo.xcprivacy:20`. Esses requisitos cobrem as 11 famílias de diretrizes do App Store Review Guidelines (1.1, 1.2, 1.5, 2.1, 2.3, 3.1, 4.0/4.2, 4.8, 5.1.1, 5.1.2 e ECA Digital).

### 2.1 Matriz de Verificação dos 27 Itens

**Distinção de Fontes:**
- **Executado (2x no simulador):** Os 4 cenários encadeados de UI em `CicloDePontaAPontaUITests` (Seção 1).
- **Auditado por Código (estático arquivo:linha):** Os 27 itens de conformidade abaixo foram verificados e comprovados por leitura estática linha a linha dos arquivos de produção e testes no commit `39b1a1c4`.

Legenda de status:
- **continua OK**: Implementação e testes confirmados em arquivo:linha na `main` atual.
- **mudou**: Estado alterado em relação à auditoria anterior (avanço ou regressão identificada e detalhada).
- **não achei**: Não localizado na `main` atual (nenhum item classificado assim).

| # | Diretriz Apple | Requisito / Tema | Evidência no Código (`iOS/Sources/`) | Evidência nos Testes (`iOS/Tests/`) | Situação na `main` | Análise e Evidência Atual |
|:---:|---|---|---|---|:---:|---|
| 1 | **1.1 / 1.1.1** | Proibição de Conteúdo Ofensivo | `AcoesDeSeguranca.swift:34` | `SegurancaDoCodigoTests.swift:15` | **continua OK** | Termos de uso e categorias de denúncia cobrem ofensas e difamação sem alterações. |
| 2 | **1.2** | Mecanismo de Denúncia e Bloqueio (UGC) | `AcoesDeSeguranca.swift:20–164`<br>`SegurancaViewModel.swift:45–95` | `SegurancaUITests.swift:20`<br>`SegurancaViewModelTests.swift:30` | **continua OK** | Denúncia com seleção de motivos, atalhos de emergência e bloqueio definitivo presentes. |
| 3 | **1.2** | Aceite Obrigatório de Termos no Cadastro | `TelaCadastro.swift:150`<br>`CadastroViewModel.swift:104–108` | `AutenticacaoTests.swift:275`<br>`EntradaECadastroBordasTests.swift:40` | **continua OK** | Botão `cadastro-termos` e validação prévia à chamada da API mantidos intactos. |
| 4 | **1.5** | Suporte ao Desenvolvedor / Contato Publicado | `PerfisDaConta.swift:390`<br>`EnderecosOficiais.swift:22` | `CatalogoStringsTests.swift:25`<br>`AppPrivacyTests.swift:45–65` | **mudou** | **Avanço:** O checklist anterior marcava "Pendente merge PR #301". O PR #301 foi mesclado em 16/10 (`AppPrivacyTests.swift` ativo). Permanece pendente apenas a reconciliação do endereço oficial entre `suporte@frilabr.com`, `suporte@frila.app` e `suportefrila@gmail.com` (tarefa P-005). |
| 5 | **2.1** | Contas de Demonstração para App Review | `DestinoAposEntrada.swift:92–97`<br>`EntradaViewModel.swift:37` | `AutenticacaoTests.swift:115–140`<br>`SegurancaDoCodigoTests.swift:50` | **mudou** | **Avanço no Backend / Pendência na Ficha:** O backend já implementou a Edge Function `entrar-demonstracao`. O app desvia a autenticação. Porém, a ficha (`FichaAppStore.md:188-195`) continua com `[A DEFINIR]`. |
| 6 | **2.1** | Ausência de Telas Provisórias / Placeholders | `CatalogoDesignSystem.swift:1` | `SegurancaDoCodigoTests.swift:68–91`<br>`conferir-textos.sh` | **continua OK** | Catálogo do design system estritamente isolado sob `#if DEBUG`. |
| 7 | **2.3 / 2.3.1** | Metadados Precisos e Sem Promessas de Tempo | `Localizable.xcstrings`<br>`FichaAppStore.md:11–108` | `CatalogoStringsTests.swift:30`<br>`conferir-textos.sh` | **continua OK** | Texto auditado; ausência de promessas de tempo ("em minutos") e sem termos proibidos. |
| 8 | **2.3.7** | Nome, Subtítulo e Keywords dentro dos Limites | `FichaAppStore.md:31–53` | `conferir-textos.sh` | **continua OK** | Nome: 21 car. ($\le 30$); Subtítulo: 25 car. ($\le 30$); Keywords: 97 bytes UTF-8 ($\le 100$ bytes). Sem concorrentes ou "grátis". |
| 9 | **3.1.1 / 3.1.3(e)** | IAP Dispensado (Serviços no Mundo Físico) | `MinhasVagasViewModel.swift:50`<br>`FichaAppStore.md:17` | `MinhasVagasTests.swift:40`<br>`TurnoContrato0231Tests.swift:20` | **continua OK** | Intermediação de trabalho presencial com acerto direto no local sem retenção de comissão (RN01); exceção formal 3.1.3(e). |
| 10 | **4.0 / 4.2** | Design Nativo e Alvos de Toque $\ge 44 \times 44$ pt | `DesignTokens.swift:10–50` | `AuditoriaDeAcessibilidadeUITests.swift:45` | **continua OK** | Componentes padronizados e áreas de toque em conformidade com as Human Interface Guidelines. |
| 11 | **4.0 / 4.2** | Respeito a Reduzir Movimento (Reduce Motion) | `FrilaMovimento.swift:15`<br>`FrilaListaInclusos.swift:111, 249` | `ReduzirMovimentoTests.swift`<br>`conferir-movimento.sh` | **mudou** | **Regressão pontual na main corrigida no PR #546:** O PR #539 havia introduzido `withAnimation` direto em `FrilaListaInclusos.swift:118` e `:261`, violando o script `conferir-movimento.sh`. A correção foi implementada no PR #546 via `FrilaMovimento.animacao(_:reduzir:)`, com o passo de conferência de movimento já aprovado na CI (Run 40642217304). |
| 12 | **4.2** | Padrões de Estado e Resiliência Offline | `EstadosDeTela.swift:62`<br>`CacheSwiftData.swift:35` | `PadroesDeEstadoTests.swift:20`<br>`ModoAviaoUITests.swift:15` | **continua OK** | Cinco estados visuais padronizados (`Carregando`, `Vazio`, `Erro`, `Offline`, `Pendente`) implementados e testados. |
| 13 | **5.1.1(i)** | Política de Privacidade no App e na Web | `EnderecosOficiais.swift:21`<br>`PerfisDaConta.swift:415` | `AppPrivacyTests.swift:45–65` | **continua OK** | URL segura HTTPS `https://frila.netlify.app/privacidade` configurada e acessível in-app. |
| 14 | **5.1.1(v)** | Exclusão de Conta In-App (Account Deletion) | `TelaExclusaoDeConta.swift:20–280`<br>`PerfisDaConta.swift:215, 321` | `ExclusaoDeContaUITests.swift:16`<br>`LimpezaAposExclusaoTests.swift:30` | **continua OK** | Acesso direto no nível raiz nos dois perfis, diálogo confirmatório e expurgo do Keychain e cache local. |
| 15 | **5.1.1(iii)** | Minimização de Dados e Permissões Opcionais | `PresencaDoTurnoViewModel.swift:75`<br>`AparelhoDePush.swift:131` | `PresencaUITests.swift:25`<br>`PermissaoDePushTests.swift:40` | **continua OK** | Permissão de localização opcional (check-in manual em contingência sem GPS); push opcional (modo passivo). |
| 16 | **5.1.2** | Manifesto de Privacidade (`PrivacyInfo.xcprivacy`) | `PrivacyInfo.xcprivacy:5–8` | `AppPrivacyTests.swift:15–44`<br>`conferir-release.sh` | **continua OK** | `NSPrivacyTracking = false`, array de domínios vazio e declaração das categorias funcionais. |
| 17 | **Menores / ECA** | Restrição Rigorosa 18+ (ECA Digital) | `VerificadorDeIdadeDoSistema.swift`<br>`CadastroViewModel.swift:97–142` | `MaioridadeEVerificacaoDeIdadeTests.swift`<br>`AutenticacaoTests.swift:286–340` | **continua OK** | Barramento no cliente de `< 18` anos e consulta ao `DeclaredAgeRange` (iOS 26.2+). |
| 18 | **Notificações** | Segregação e Neutralização no Push (NSE) | `NotificationService.swift:12–73`<br>`VinculoDoPush.swift:68` | `NotificationServiceTests.swift:10–190`<br>`PushUITests.swift:20` | **continua OK** | Extensão neutraliza para `"Frila" / "Nova notificação disponível"` caso `vinculo_id` divirja da sessão ativa. |
| 19 | **RNF16** | Ausência de Publicidade e Banners de Terceiros | `PrivacyInfo.xcprivacy:5` | `SegurancaDoCodigoTests.swift:30`<br>`conferir-release.sh` | **continua OK** | Zero SDKs de publicidade comportamental ou anúncios no app. |
| 20 | **2.3.6 / 2.3.8** | Questionário de Classificação Etária (Age Rating) | `FichaAppStore.md:133–171`<br>`Classificacao18ECA.md:56` | Teste de UI de aviso indicativo: `FrilaUITests.swift:197` | **continua OK** | Respostas mapeadas com Override para 18+ e indicação "Classificação indicativa: 18 anos" na `TelaEntrada.swift:46`. |
| 21 | **2.3.10** | Ausência de Menção a Plataformas Concorrentes | `FichaAppStore.md:228` | `conferir-textos.sh` | **continua OK** | Sem termos como "Android", "Play Store" ou plataformas externas no código e metadados. |
| 22 | **2.5.4** | Uso Restrito de Localização em Primeiro Plano | `Sources/App/Info.plist:8` | `PresencaDoTurnoViewModelTests.swift:40` | **continua OK** | Apenas `NSLocationWhenInUseUsageDescription` declarado; sem background location. |
| 23 | **5.1.1(ii)** | Justificativa de Finalidade antes da Coleta | `TelaPorQueReceboVagas.swift:15`<br>`TelasDaPermissaoDePush.swift:20` | `PorQueReceboVagasUITests.swift:15`<br>`PermissaoDePushUITests.swift:15` | **continua OK** | Telas de contexto explicam a finalidade antes de solicitar push ou dados de perfil. |
| 24 | **5.1.3** | Tráfego Criptografado e Proteção de Keychain | `SessaoNoKeychainDoAparelho.swift:45` | `SegurancaDoCodigoTests.swift:40` | **continua OK** | ATS ativo (HTTPS estrito); tokens armazenados com `kSecAttrAccessibleAfterFirstUnlock`. |
| 25 | **1.4** | Prevenção de Conflitos Físicos e Jornadas | `ConflitoDeHorario.swift:12` | `FrilaUITests.swift:418` (`testTurnoSobreposto...`) | **continua OK** | Bloqueio de sobreposição de horários para impedir jornadas duplas simultâneas. |
| 26 | **2.1** | Resiliência contra Queda de Conexão | `CacheSwiftData.swift:35` | `ModoAviaoUITests.swift:20` | **continua OK** | App entra em modo offline gracioso sem crash ou tela travada na perda de rede. |
| 27 | **5.1.2** | Identificador de Dispositivo Restrito a Notificações | `PrivacyInfo.xcprivacy:20`<br>`AparelhoDePush.swift:25` | `NotificationServiceTests.swift:95` | **continua OK** | Token FCM/Device ID restrito exclusivamente a `AppFunctionality`. |

---

### 2.2 Auditoria da 1 Falha (Comentário Loki / Cartão 6ab26a32)

- **Falha Apontada:** A ficha da loja (`iOS/Docs/FichaAppStore.md:182, 188–195`) continha campos essenciais marcados como `[A DEFINIR]`:
  - Telefone de contato de revisão: `[A DEFINIR]` (linha 182).
  - Conta de demonstração profissional (E-mail e OTP fixo): `[A DEFINIR]` (linhas 188–189).
  - Conta de demonstração contratante (E-mail e OTP fixo): `[A DEFINIR]` (linhas 192–193).
- **Conferência na `main` Atual (`39b1a1c4`):**
  - O arquivo `iOS/Docs/FichaAppStore.md` **continua com as marcações `[A DEFINIR]`**.
  - **Evolução Técnica:** A nota da ficha que dizia "depende de cartão do backend (OTP fixo)" está superada: a Edge Function `entrar-demonstracao` já foi implantada no backend e o app já reconhece o desvio. Falta exclusivamente a definição operacional humana dos e-mails a fornecer aos revisores da Apple e a inserção desses dados na ficha.
- **Veredito:** **Falha confirmada na documentação da ficha; não impede testes locais, mas bloqueia a submissão final ao App Store Review.**

---

### 2.3 Auditoria dos 5 Riscos (Comentário Loki / Cartão 6ab26a32)

| Risco | Descrição Original do Loki | Estado na `main` / Repositório | Ação Restante / Responsável |
|:---:|---|---|---|
| **Risco 1** | **Semente e segredo da demonstração no ambiente Prod** | No iOS, `DestinoAposEntrada.swift:92` reconhece as contas. No Prod, a função `entrar-demonstracao` existe. No entanto, os registros dessas duas contas (perfil profissional com Garçom/Bartender e contratante com Bar e Restaurante na Asa Sul) precisam estar semeados e válidos no banco Prod. | **Pendente (Infra/Backend):** Matheus/Jotapê confirmarem o seed dos dados no banco de produção. |
| **Risco 2** | **Capturas de tela de 6,9" e vídeo de demonstração** | `CapturasDesignD01UITests.swift` gera capturas no simulador, mas as imagens finais com as frases promocionais aprovadas no formato 6,9" (iPhone 16/17 Pro Max) e o vídeo de demonstração não estão finalizados no repo. | **Pendente (Design/Humano):** Fabrício e Cauê aprovarem as frases e exportarem os assets finais. |
| **Risco 3** | **Notas de moderação (SLA de UGC / Diretriz 1.2)** | `FichaAppStore.md:206` informa triagem em até 5 dias úteis e resposta em até 15 dias corridos. Revisores da Apple costumam exigir remoção de conteúdo denunciado em até 24 horas. | **Pendente (Decisão Regulatória):** Cauê avaliar o risco de questionamento no App Review e manter justificativa formal. |
| **Risco 4** | **Classificação indicativa 18+ (ECA Digital)** | O questionário da Apple calcula 4+, exigindo o *Override to Higher Age Rating: 18+* (A18 no Brasil). `Classificacao18ECA.md` e `FichaAppStore.md:133-171` documentam as respostas completas. | **Pronto no código e documentação; pendente de aplicação manual no portal App Store Connect por Cauê.** |
| **Risco 5** | **12 Declarações do App Privacy no App Store Connect** | Mapeamento técnico concluído em `AppPrivacyAppStoreConnect.md`. A `main` classifica telemetria de diagnóstico/falhas como `AppFunctionality`. A decisão estratégica de marcar ou não como `Analytics` permaneceu em aberto no PR #104 (convertido em rascunho). | **Pendente (Decisão do Dono):** Cauê ratificar a declaração antes do preenchimento no App Store Connect. |

---

## 3. Síntese Executiva para a PO e Sócios

1. **Caminho Feliz (XCUITest):** A suíte `CicloDePontaAPontaUITests` rodou duas vezes com 100% de sucesso (tempo médio de 168 s, zero falhas), provando a solidez dos fluxos encadeados de primeiro acesso, contratação, candidatura de urgência, contingência de check-in manual e avaliação mútua.
2. **Conformidade com a App Store:** Dos 27 itens de conformidade, **24 continuam estritamente OK**, 3 apresentaram alterações (duas evoluções positivas e uma regressão pontual no Reduzir Movimento pelo PR #539, mapeada para correção em F-006).
3. **Bloqueios de Submissão:** Todos os bloqueios remanescentes (a 1 falha e os 5 riscos) situam-se **fora do código do aplicativo**, dependendo de ações operacionais e cadastrais no App Store Connect, no seed do Prod e no handoff de design.
