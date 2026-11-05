# Checklist Oficial de Conformidade com as Diretrizes da App Store

**Data da Auditoria:** 05/11/2026  
**Versão do App:** 1.0.0 (Build 1.0) · Distribuição exclusiva para iPhone  
**Cartões Trello de Referência:**
- [5Lx5v39r / 6ab26a325b574b873f968793](https://trello.com/c/5Lx5v39r) (S3 · QA · Regressão final e checklist das diretrizes da App Store)
- [PFWvegZa](https://trello.com/c/PFWvegZa) (T-0019 / Cartão 78: Ficha da App Store)
- [6ab26a3454f64a126c893fae](https://trello.com/c/6ab26a3454f64a126c893fae) (S3 · Infra · Submeter à App Store em 06/11 e responder à revisão)
- [6ab26a2d](https://trello.com/c/6ab26a2d) (S3 · Jurídico + Infra · App Privacy)

---

## 1. Resumo Executivo e Contagem por Status

Esta checklist consolida a auditoria técnica e documental das **Diretrizes de Revisão da App Store (App Store Review Guidelines)** contra o código-fonte (`iOS/Sources/`), testes automatizados (`iOS/Tests/`), pacotes de submissão e matriz de privacidade (`frila-docs/operacao/pacote-submissao-app-store.md`, `frila-docs/juridico/matriz-app-privacy.md`) e URLs públicas em produção.

A classificação adota estritamente os 4 status normativos estabelecidos para a homologação pré-submissão:

| Status Normativo | Definição Operacional | Quantidade |
|---|---|:---:|
| **atendido com evidência** | Verificado integralmente no código, teste automatizado, URLs ativas (HTTP 200 via `curl`) ou documento normativo. | **10** |
| **atendido sem evidência de aparelho** | Implementado no código e comprovado por testes automatizados (unitários/UI/Dublê), mas a comprovação final depende de validação em aparelho físico ou conferência visual humana. | **10** |
| **depende de teste no iPhone** | Requer execução em hardware iPhone físico ou validação das credenciais de demonstração/semeadura no ambiente de Produção (`frila-prod`). | **2** |
| **não atendido** | Requisito não implementado, ausente ou desconforme. | **0** |
| **TOTAL DE ITENS AUDITADOS** | | **22** |

---

## 2. Verificação de URLs Públicas e Contato Oficial (`curl -sIL`)

Todas as páginas obrigatórias foram consultadas em 05/11/2026 utilizando `curl -sIL` (seguindo redirecionamentos). Todas responderam com status **HTTP 200** e exibem publicamente o canal oficial de contato `suporte@frilabr.com`:

| URL Oficial | Código HTTP | Redirecionamento | Presença de `suporte@frilabr.com` | Finalidade Normativa |
|---|:---:|:---:|:---:|---|
| `https://frila.netlify.app/termos` | **200** | 301 (`/termos` $\to$ `/termos/`) | **Confirmado** | Termos de Serviço / EULA (Diretriz 1.2) |
| `https://frila.netlify.app/privacidade` | **200** | 301 (`/privacidade` $\to$ `/privacidade/`) | **Confirmado** | Política de Privacidade / LGPD (Diretriz 5.1.1(i)) |
| `https://frila.netlify.app/suporte` | **200** | 301 (`/suporte` $\to$ `/suporte/`) | **Confirmado** | URL de Suporte / Help Desk (Diretriz 1.5) |
| `https://frilabr.com/` | **200** | Direto (HTTP/2 200) | **Confirmado** | URL de Marketing / Institucional (Diretriz 2.3) |

---

## 3. Matriz Completa de Conformidade por Diretriz

| # | Diretriz Apple | Tema / Requisito | Status | Evidência Objetiva (Código, Testes, URLs e Políticas) | O que falta e quem faz |
|---|---|---|:---:|---|---|
| 1 | **1.1 / 1.1.1** | Conteúdo Impróprio e Ofensivo | **atendido com evidência** | **Código:** Proibição contratual e bloqueio nos termos.<br>**Testes:** `iOS/Tests/Unitarios/SegurancaDoCodigoTests.swift`<br>**Política:** `frila-docs/juridico/termos.md:40-60` e `GuiaDeVoz.md` proíbem linguagem ofensiva, difamatória e discriminação. | Nenhuma pendência de código ou documentação. |
| 2 | **1.2** | UGC: Filtro de Texto Ofensivo | **atendido sem evidência de aparelho** | **Código:** `CadastroEstabelecimento.swift:250`, `PublicarVaga.swift:551-553`, `TextosDoCancelamento.swift:112` tratam retorno `campoInvalido` (`campo_invalido`) emitido pelo servidor.<br>**Backend:** Migrações `20260923200000_filtro_de_texto_ofensivo.sql` e `20261018190000_sinal_idade_criar_conta.sql` aplicam `privado.contem_termo_ofensivo` em nome, endereço, traje, observações e relatos.<br>**Testes:** `CadastroEstabelecimentoTests.swift:248-257` e `CancelamentoViewModelTests.swift:225`. | Testar reação visual e mensagens em aparelho físico na sessão interna de QA (Cauê). |
| 3 | **1.2** | UGC: Denúncia em 1 Toque e Moderação em 24h | **atendido sem evidência de aparelho** | **Código:** `AcoesDeSeguranca.swift:20-65` (botão `denunciar`), `SegurancaViewModel.swift:45-95` (`denunciar()`), `FolhaSuporteTurno.swift`.<br>**Testes:** `SegurancaViewModelTests.swift:70-143`, `SegurancaUITests.swift`.<br>**Política/SLA:** `frila-docs/operacao/pacote-submissao-app-store.md:18, 218, 319` formaliza compromisso de triagem diária e moderação em até 24 horas úteis. | Cumprimento operacional do SLA no painel administrativo após submissão (Equipe de Suporte / Cauê). |
| 4 | **1.2** | UGC: Bloqueio Mútuo Imediato de Usuários | **atendido sem evidência de aparelho** | **Código:** `AcoesDeSeguranca.swift:30-65`, `SegurancaViewModel.swift:60-70`, `BloqueiosDaSessao:10-25` (filtra e oculta na hora vagas e perfis da parte bloqueada).<br>**Testes:** `SegurancaViewModelTests.swift`, `SegurancaUITests.swift`, `RpcsDaSprint2EmMemoriaTests.swift:473-480`. | Validação de ponta a ponta entre dois iPhones físicos em produção (Cauê). |
| 5 | **1.2** | UGC: Termos de Serviço Aceitos no Cadastro | **atendido com evidência** | **Código:** `TelaCadastro.swift:188-210`, `CadastroViewModel.swift:104-142` (trava de aceite obrigatório antes de acionar API; envio da versão dos termos).<br>**Testes:** `AutenticacaoTests.swift:275`, `EntradaECadastroBordasTests.swift`.<br>**URL:** `https://frila.netlify.app/termos` respondendo HTTP 200 via `curl -sIL`. | Nenhuma pendência técnica. |
| 6 | **1.5** | Suporte ao Desenvolvedor e Contato Publicado | **atendido com evidência** | **Código:** `EnderecosOficiais.swift:22` (`emailSuporte: "suporte@frilabr.com"`), `PerfisDaConta.swift:732-765` (`perfil-suporte-email`), `FolhaSuporteTurno.swift:317`.<br>**Testes:** `AppPrivacyTests.swift:100-115`, `CatalogoStringsTests.swift`, `SuporteTurnoViewModelTests.swift`.<br>**URLs:** `https://frila.netlify.app/suporte` e `https://frilabr.com/` com HTTP 200 e e-mail publicado. | Nenhuma pendência técnica. |
| 7 | **2.1** | Contas de Demonstração para App Review (Bypass OTP) | **depende de teste no iPhone** | **Código:** `DestinoAposEntrada.swift:92-97` (`DemonstracaoContas`), `CodigoViewModel.swift:99-100`, `SupabaseApiCliente.swift:85-92` (`entrarDemonstracao`).<br>**Backend:** Edge Function `/functions/entrar-demonstracao`.<br>**Testes:** `AutenticacaoTests.swift:48, 528-534`, `ApiEmMemoriaTests.swift:60`.<br>**Nota de Atenção:** O código iOS aceita `revisao-profissional@frila.app` e `revisao-contratante@frila.app`; o pacote de submissão cita `revisor.contratante@frila.app` e `revisor.profissional@frila.app`. | Conciliar os e-mails exatos no App Store Connect e testar login real das duas contas sem receber e-mail no iPhone em Produção (Cauê). |
| 8 | **2.1** | Semeadura de Dados e Backend Ativo para Revisão | **depende de teste no iPhone** | **Backend/Scripts:** `frila-backend/scripts/semear-vagas-demonstracao.sh`, `renovar-demonstracao.sh`, migração `20261004160000_renovacao_dados_demonstracao.sql`.<br>**Pacote:** `pacote-submissao-app-store.md:365` registra que a semeadura em Produção deve ocorrer antes de 06/11. | Executar semeadura no banco de Produção (`frila-prod`) e conferir vagas ativas na conta de demonstração (Cauê). |
| 9 | **2.1** | Ausência de Telas Provisórias / Placeholders | **atendido com evidência** | **Código:** `CatalogoDesignSystem.swift` restrito a `#if DEBUG`. Ausência de textos como "em breve" ou "próxima versão".<br>**Scripts e Testes:** `iOS/Scripts/conferir-textos.sh` e `conferir-datas-fixas.sh` executados com código 0; `SegurancaDoCodigoTests.swift:68-91`. | Nenhuma pendência técnica. |
| 10 | **2.3 / 2.3.1** | Metadados Precisos e Sem Superlativos | **atendido com evidência** | **Ficha:** `frila-docs/operacao/pacote-submissao-app-store.md:27-126` e `FichaAppStore.md`. Descrição com 2.480 caracteres (limite 4.000), promocional com 155 caracteres (limite 170).<br>**Auditoria:** `conferir-textos.sh` e `CatalogoStringsTests.swift`. Sem menção a cobrança de taxa ou promessas inverificáveis. | Preenchimento dos campos no portal App Store Connect pelo titular da conta (Cauê). |
| 11 | **2.3 / 2.3.1** | Coerência de Telas e Capturas (Screenshots 6,9") | **atendido sem evidência de aparelho** | **Mídia:** 8 capturas técnicas na resolução nativa de 6,9" (1320 × 2868 px) geradas via automação no PR #634.<br>**Especificação:** `pacote-submissao-app-store.md:378-381` documenta aderência das telas aos fluxos reais do app. | Aprovação visual humana do enquadramento e da sequência de imagens no App Store Connect (Fabrício e Júlia). |
| 12 | **2.3.7** | Nome, Subtítulo e Palavras-chave | **atendido com evidência** | **Ficha:** Nome `Frila: Turnos e Vagas` (21 caracteres, limite 30); Subtítulo `Turnos em bares e eventos` (25 caracteres, limite 30); Palavras-chave com 97 bytes em UTF-8 (limite 100 bytes).<br>**Regras:** Sem palavras proibidas ("grátis", "free"), sem marcas de concorrentes (pós-PR #312), sem vírgulas com espaço. | Inserção dos valores validados no App Store Connect (Cauê). |
| 13 | **3.1.1 / 3.1.3(e)** | Isenção de IAP (Serviços no Mundo Físico) | **atendido com evidência** | **Código:** App 100% gratuito (R$ 0), sem importação de `StoreKit` ou SDKs de cobrança.<br>**Regra de Negócio:** Pagamento de diárias feito diretamente entre estabelecimento e profissional no local do turno (RN01), enquadrado na exceção expressa da Diretriz 3.1.3(e).<br>**Testes:** `SegurancaDoCodigoTests.swift`, `TurnoContrato0231Tests.swift`. | Nenhuma pendência técnica. |
| 14 | **4.0 / 4.2** | Design Nativo, Acessibilidade e Alvo de Toque | **atendido sem evidência de aparelho** | **Código:** Interface nativa em SwiftUI com Dynamic Type, suporte a Reduzir Movimento, alvos de toque $\ge 44 \times 44$ pt (`DesignTokens.swift`).<br>**Testes:** `AcessibilidadeEstadoECorTests.swift`, `AuditoriaDeAcessibilidadeUITests.swift`, `CadastroEstabelecimentoUITests.swift:363-392`. | Teste manual exploratório com VoiceOver ativo em iPhone físico (conforme `Acessibilidade.md` / Cauê). |
| 15 | **4.2** | Resiliência Geográfica (Revisor Fora do DF) | **atendido sem evidência de aparelho** | **Código:** `FeedVagasViewModel.swift:113-114` (fallback para ponto base/DF sem GPS); `PresencaDoTurnoViewModel.swift:100-140` implementa fluxo de contingência assistida (check-in fora dos 200m é gravado como "manual/pendente" e aprovado pelo contratante).<br>**Testes:** `PadroesDeEstadoTests.swift`, `ModoAviaoUITests.swift`.<br>**Instruções ao Revisor:** `pacote-submissao-app-store.md:203-213, 250-256`. | Validação do fluxo de check-in manual assistido no iPhone fora do DF (Cauê). |
| 16 | **5.1.1(i)** | Política de Privacidade no App e na Web | **atendido com evidência** | **Código:** Links nativos em `EnderecosOficiais.swift:21`, `PerfisDaConta.swift:730-760`, `TelaCadastro.swift:195`, `TelaEntrada.swift:92`.<br>**Testes:** `AppPrivacyTests.swift:45-65`.<br>**URL:** `https://frila.netlify.app/privacidade` respondendo HTTP 200 via `curl -sIL` e contendo e-mail oficial. | Nenhuma pendência técnica. |
| 17 | **5.1.1(v)** | Exclusão de Conta In-App (Account Deletion) | **atendido sem evidência de aparelho** | **Código:** `TelaExclusaoDeConta.swift`, `PerfisDaConta.swift:201, 306`, `SaidaDaConta.swift`.<br>**Backend:** Edge Function `/functions/v1/excluir-conta` (exclusão imediata em `auth.users` e dados pessoais) e migração `20261002090000_ordem_de_travas_excluir_conta.sql`.<br>**Testes:** `ExclusaoDeContaUITests.swift`, `LimpezaAposExclusaoTests.swift`, `AuditoriaExclusaoDeConta.md`. | Execução do teste de exclusão em produção no iPhone descartando conta de teste (Cauê). |
| 18 | **5.1.1(iii)** | Minimização de Dados e Permissões Opcionais | **atendido sem evidência de aparelho** | **Código:** Push e Localização solicitados no momento contextual, com alternativas completas em caso de recusa (`LeitorDeLocalizacaoDoSistema.swift`, `AparelhoDePush.swift`, `CadastroViewModel.swift:115-142`).<br>**Testes:** `PermissaoDePushTests.swift`, `PresencaUITests.swift`, `ContratoDoClienteSupabaseTests.swift:178-203`. | Conferência dos diálogos nativos de permissão do sistema no iPhone físico (Cauê). |
| 19 | **5.1.2** | Manifesto de Privacidade e Sem Rastreamento | **atendido com evidência** | **Código:** `iOS/Resources/PrivacyInfo.xcprivacy` com `NSPrivacyTracking = false`, domínios vazios e 11 tipos funcionais declarados.<br>**Auditoria de SDKs:** `frila-docs/juridico/matriz-app-privacy.md:71-102` confirmou conformidade dos manifestos do Firebase Crashlytics e Messaging.<br>**Testes:** `AppPrivacyTests.swift:15-44`. | Preenchimento do questionário App Privacy no portal App Store Connect conforme a matriz (Cauê). |
| 20 | **Menores / ECA** | Restrição Rigorosa 18+ (ECA Digital) | **atendido sem evidência de aparelho** | **Código:** `VerificadorDeIdadeDoSistema.swift`, `CadastroViewModel.swift:97-142` (bloqueio do menor antes da chamada à API).<br>**Backend:** `20261018190000_sinal_idade_criar_conta.sql` grava faixa, método e instante de aferição.<br>**Testes:** `MaioridadeEVerificacaoDeIdadeTests.swift`, `AutenticacaoTests.swift:286-340`, `ContratoDoClienteSupabaseTests.swift:178-203`. | Teste de tentativa de cadastro com menor de idade em aparelho físico (Cauê). |
| 21 | **Push** | Segregação e Neutralização no Push | **atendido sem evidência de aparelho** | **Código:** `NotificationService.swift`, `VinculoDoPush.swift:68` (`FiltroDoPushPorVinculo` neutraliza alertas de sessões anteriores).<br>**Testes:** `NotificationServiceTests.swift`, `PushUITests.swift`.<br>**Infra:** Configuração do App Group `group.com.frila.org.app`. | Habilitação do App Group no Apple Developer Portal e teste de recebimento de push em aparelho físico (Cauê / João Paulo). |
| 22 | **RNF16** | Ausência de Publicidade e Banners Pagos | **atendido com evidência** | **Código:** Zero SDKs de publicidade (sem AdSupport, sem Google Mobile Ads). Zero banners patrocinados.<br>**Testes:** `SegurancaDoCodigoTests.swift`, `conferir-release.sh`.<br>**Política:** `privacidade.md:42` e `SegurancaEPrivacidade.md:160`. | Nenhuma pendência técnica. |

---

## 4. Ações Não-Programáticas e Pendências de Pessoa

As ações pendentes não indicam defeito no código-fonte, mas dependem de hardware físico, credenciais privativas ou acesso ao App Store Connect:

1. **Sessão Interna de Teste no iPhone (Cauê):**
   - Executar login com as duas contas de demonstração em Produção sem depender de recebimento de e-mail;
   - Validar fluxo de contingência de presença geográfica fora de Brasília;
   - Realizar teste de exclusão de conta em produção;
   - Validar navegação básica com VoiceOver ativo (Diretriz 4.0).
2. **Aprovação Visual das Capturas de Tela (Fabrício e Júlia):**
   - Aprovar a sequência das 8 imagens exportadas na resolução 6,9" (1320 × 2868 px) geradas no PR #634 antes do upload.
3. **Preenchimento e Submissão no App Store Connect (Cauê):**
   - Copiar metadados textuais (`pacote-submissao-app-store.md:27-126`);
   - Preencher questionário de classificação 18+ (CLT Art. 404 / ECA Digital);
   - Preencher questionário de App Privacy conforme a matriz (`matriz-app-privacy.md:129-146`);
   - Inserir Notas de Revisão com as credenciais de demonstração e instruções de contingência geográfica;
   - Fazer upload do Build 1.0 (Release) e submeter para revisão da Apple em 06/11/2026.
4. **Alinhamento dos E-mails de Revisão:**
   - **Ponto de Atenção:** O código iOS em `DestinoAposEntrada.swift:95` reconhece `revisao-profissional@frila.app` e `revisao-contratante@frila.app`. Certificar-se de cadastrar exatamente esses endereços no App Store Connect e no backend de produção para garantir o funcionamento do bypass.

---

## 5. Conclusão da Auditoria Técnica

O aplicativo iOS (`frila-frontend`) atende satisfatoriamente a todos os requisitos programáticos e normativos exigidos pelas Diretrizes da App Store para a versão 1.0.0. Inexistem itens classificados como **não atendido**. As pendências remanescentes estão devidamente mapeadas e circunscritas a testes em aparelho físico e configurações administrativas no App Store Connect a serem conduzidas em 06/11/2026.
