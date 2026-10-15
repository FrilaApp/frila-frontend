# Gap Analysis: App iOS vs Checklist do TestFlight 0.4 e 0.5

**Data:** 15/10/2026  
**Autor:** Trovão (iOS)  
**Cartões de Referência no Trello:**
- `0jEemYAM` — *S1 · Infra + iOS · Mandar o build 0.4 para o TestFlight (20/10)*
- `Kd0RVh9q` — *S2 · Infra + iOS · TestFlight 0.5 com push, check-in e avaliação (29/10)*  
**Contrato Base:** `0.2.42` (`iOS/Contrato/openapi.yaml`)  
**Base do Código:** `frila-frontend` (`main`)

---

## 1. Resumo Executivo e Estado Geral

O aplicativo Frila para iOS encontra-se em estágio técnico avançado de maturidade e conformidade:
1. **Build 0.4 (Marco de 20/10):** O ciclo principal sem push (entrada OTP, cadastros, publicação de vagas, lista/busca, candidatura, confirmação e contato) está **100% implementado no código**, coberto por testes unitários e de UI que existem e rodam na CI da `main`, e validado pelos portões de conformidade (`conferir-release.sh`, `conferir-textos.sh`, etc.). O pipeline de envio automatizado (`.github/workflows/testflight.yml` e `Scripts/enviar-testflight.sh`) está pronto.
2. **Build 0.5 (Marco de 29/10):** As funcionalidades de **Push Remoto (APNs/FCM)**, **Extensão de Serviço de Notificação (NSE - PR #291)**, **Check-in/Check-out Geolocalizado**, **Check-in Manual com Confirmação do Contratante**, **Avaliação Binária Pós-Turno**, **Cancelamentos com Motivo**, **Fila Offline com SwiftData**, **Telemetria de 14 Eventos (PR #292)** e **Resiliência de Rede com Retries de Leitura e Timeouts (PR #299 mergeado)** estão 100% implementadas no cliente iOS na branch `main`.

> **Conclusão Principal da Análise:** Não há funcionalidade de produto ou arquitetura de código pendente no aplicativo iOS para os marcos 0.4 e 0.5. O que separa o estado atual da liberação para os testadores externos são **estritamente bloqueios externos e operacionais** (conferência de papel da chave ASC pelo proprietário João Paulo, deploy de serviços no backend `frila-dev` via PR `frila-backend#184` e validações em iPhones físicos no DF).

---

## 2. Análise Detalhada por Eixo Funcional

### 2.1. Push (Notificações, Permissão, Destino do Toque e Registro de Aparelho)
- **Contrato / Requisitos:** US07, RF06, RF08, B08, B17; RPCs `/rpc/registrar_dispositivo`, `/rpc/remover_dispositivo`, contrato 0.2.30 (`vinculo_id`), contrato 0.2.41.
- **Implementado no App (Feito):**
  - `CanalDePushDoAparelho.swift`: integração com Firebase Messaging (`MessagingDelegate`), requisição ao APNs (`registerForRemoteNotifications`), suspensão segura no logout (`unregisterForRemoteNotifications`).
  - `AparelhoDePush.swift`: registro do token via RPC `/rpc/registrar_dispositivo` a cada abertura e troca de token; remoção via `/rpc/remover_dispositivo` antes do signOut; desvinculação em 401; isolamento de tokens no Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`); suporte a reinstalação comprovado em testes unitários (`AparelhoDePushTests.swift`).
  - `PermissaoDePushModelo.swift` / `TelasDaPermissaoDePush.swift`: pedido de permissão com modal educativo do design; ativado no momento exato (profissional após salvar funções/horários em `TelaPerfilProfissional.swift`; contratante após publicar vaga em `PublicarVaga.swift`); aviso fixo (`AvisoDePermissaoDePush`) em Vagas e Minhas Vagas com rota para Ajustes (`openNotificationSettingsURLString`); telemetria `permissao_push_negada` integrada.
  - Conformidade B08: apenas alerta e som (`[.alert, .sound]`), sem Time Sensitive, sem alerta crítico, sem autorização provisória e sem modos de segundo plano para push.
  - `RoteadorDePush.swift`: roteador central cobrindo os 19 tipos de notificação do backend; descarte de push de contas anteriores com carência de 60s; direcionamento seguro para vagas, turnos, avaliações ou vagas indisponíveis.
  - `FrilaNotificationService` (Target NSE, PR #291 mergeado): extensão no App Group `group.com.frila.org.app` filtrando notificações por `vinculo_id`; neutralização de notificações de contas inativas na tela bloqueada para "Frila / Nova notificação disponível".
  - Ferramental de teste: catálogo de fixtures `.apns` e script `simular-push.sh`.
- **O que falta:**
  - Disparo real de push via console do Firebase em `frila-dev` e `frila-prod`.
  - Homologação visual em iPhone físico com tela bloqueada.
- **Bloqueado por quê:**
  - *Bloqueio Operacional / Apple:* Criação do App Group `group.com.frila.org.app` e perfis de provisionamento associados no Apple Developer Portal pelo titular da conta (João Paulo).
  - *Bloqueio Backend:* Ativação do envio em `frila-dev`: a Edge Function `enviar-push` ainda não tem entrada em `config.toml`, portanto o gateway do Supabase recusa o agendador com 401 até que o `frila-backend#184` (`verify_jwt = false` + validação por segredo compartilhado) seja mergeado e implantado no ambiente. Além disso, é necessária a injeção de `FCM_SERVICE_ACCOUNT` e `AGENDADOR_SECRET` no `frila-dev`.
  - *Bloqueio Físico:* Teste manual em aparelho de desenvolvimento com chip/APNs no DF.

---

### 2.2. Check-in e Check-out (Presença e Geolocalização)
- **Contrato / Requisitos:** US08, RF09, RF10, RN15, RN22; RPCs `/rpc/fazer_checkin`, `/rpc/confirmar_checkin_manual`, `/rpc/fazer_checkout`.
- **Implementado no App (Feito):**
  - `SecaoDePresenca.swift` & `PresencaDoTurnoViewModel.swift`: fluxo completo de presença na tela de turno do profissional.
  - Leitura sob demanda: GPS ativado exclusivamente no toque do botão (zero rastreamento em segundo plano, respeitando B08 e RNF04).
  - Privacidade RN15: cálculo de distância medido estritamente no aparelho (`LeitorDeLocalizacaoDoSistema`); coordenadas de latitude/longitude nunca são enviadas ao backend; o payload transporta apenas `distancia_metros: Int` e `registrado_em: Date`.
  - Regra de distância: distância `<= 200m` e precisão horizontal `<= 100m` -> check-in verificado (`checkin_tipo = 'geolocalizado'`). Fora do raio ou sem GPS -> check-in manual (`checkin_tipo = 'manual'`).
  - Confirmação da Casa: contratante visualiza alerta e confirma presença manual com um toque (`confirmar_checkin_manual`) em `AcompanhamentoViewModel.swift`.
  - Check-out: registro de saída habilitado após check-in, enviando horário e distância.
  - Fila offline: falhas de conectividade durante check-in/check-out enfileiram a ação no SwiftData (`ArmazenamentoSwiftData`) para sincronização automática ao restabelecer a rede.
  - Telemetria: `checkin_tentado`, `checkin_concluido` e `checkout_concluido` instrumentados.
- **O que falta:**
  - Prova ponta a ponta em campo contra o `frila-dev` no endereço real da vaga no DF com iPhone físico.
- **Bloqueado por quê:**
  - Disponibilidade de testadores em campo e turnos de teste criados no ambiente `frila-dev`.

---

### 2.3. Avaliação de Turno
- **Contrato / Requisitos:** US10, RF12, RN14, RN15; RPC `/rpc/avaliar`.
- **Implementado no App (Feito):**
  - `TelaAvaliacao.swift` & `AvaliacaoTurnoViewModel.swift`: formulário binário simples ("Você trabalharia nesse local de novo?" -> Sim / Não).
  - Regras de liberação: bloqueado antes do término previsto do turno ou se a presença não foi verificada.
  - Idempotência: reenvio da mesma avaliação devolve o registro existente; alteração de voto rejeitada com 409 pelo backend.
  - Modo offline: avaliação salva localmente e enviada para a fila de ações offline se a requisição falhar por rede.
  - Telemetria: `avaliacao_enviada` instrumentado e testado.
- **O que falta:**
  - Avaliação executada por testador do TestFlight em turno concluído contra `frila-dev`.
- **Bloqueado por quê:**
  - Depende do cumprimento prévio de um turno no `frila-dev` para atingir o estado `pode_avaliar = true`.

---

### 2.4. Cancelamento
- **Contrato / Requisitos:** US09, RF11, RN12, RN13; RPCs `/rpc/retirar_candidatura`, `/rpc/cancelar_posicao`, `/rpc/cancelar_vaga`, `/rpc/reabrir_por_atraso`.
- **Implementado no App (Feito):**
  - `FolhaDeCancelamento.swift` & `CancelamentoViewModel.swift`: interface com advertências de impacto na reputação e campo de motivo obrigatório (`>= 3` caracteres).
  - Profissional: retirada de candidatura pendente (`retirar_candidatura`) e cancelamento de turno confirmado (`cancelar_posicao`).
  - Contratante: cancelamento de posição confirmada, cancelamento de vaga inteira (`cancelar_vaga`) e reabertura de vaga por atraso/falta após 15 minutos do início (`reabrir_por_atraso`).
  - Suporte offline e tratamento de idempotência (0.2.35): reenvio devolve o resultado original sem duplicação de penalidades.
  - Telemetria: `candidatura_retirada` instrumentado.
- **O que falta:**
  - Homologação de usabilidade em campo.
- **Bloqueado por quê:**
  - Nada bloqueia a execução no cliente.

---

### 2.5. Estados Offline e Resiliência de Rede
- **Contrato / Requisitos:** RNF02, RNF03, RNF04; PR #299 (`57hJ7FV0`, **mergeado na `main`**).
- **Implementado no App (Feito):**
  - Timeouts configurados em `SupabaseApiCliente.sessaoComPrazo` (15s timeout de requisição, 60s timeout de recurso, `waitsForConnectivity = false` para falha imediata e ativação de caches offline).
  - Retry idempotente com uma única retentativa com espera fixa de 150ms restrito a RPCs de leitura (`rpcsDeLeitura` via `executarComRetentativaSeTransiente`), incorporado pelo PR #299. Nenhuma mutação (`candidatar`, `publicar_vaga`, `fazer_checkin`) é retentada automaticamente.
  - Fila de ações offline persistida via SwiftData (`ArmazenamentoSwiftData`), sincronizada pelo `SincronizadorAcoes` na recuperação de rede.
  - Padrões visuais de feedback de desconexão e sincronização pendente (`EstadoDoFluxoContratante`, banners de offline e avisos de fila; estados exercitados nos testes de UI em `FrilaUITests`).
  - Telemetria: `acao_enfileirada_offline` instrumentada.
- **O que falta:**
  - Nada no código do cliente. O PR #299 já foi aprovado e integrado à branch `main`.
- **Bloqueado por quê:**
  - Nenhum bloqueio. Código 100% integrado.

---

### 2.6. Telemetria e Privacidade
- **Contrato / Requisitos:** T-0017, RN15, RNF08; RPC `/rpc/registrar_evento`.
- **Implementado no App (Feito):**
  - Dicionário fechado de 14 eventos (`EventoDeTelemetria`): `app_aberto`, `cadastro_concluido`, `permissao_push_negada`, `vaga_vista`, `vaga_detalhe_aberto`, `candidatura_enviada`, `candidatura_retirada`, `checkin_tentado`, `checkin_concluido`, `checkout_concluido`, `avaliacao_enviada`, `contato_aberto`, `acao_enfileirada_offline`, `atualizacao_obrigatoria_exibida`.
  - Privacidade rigorosa (RN15): apenas identificadores relacionais (`vagaID`, `turnoID`, `ocorridoEm`). Zero PII, nomes, e-mails, telefones ou coordenadas GPS.
  - Resiliência (RNF08): falhas na camada de telemetria operam de forma totalmente silenciosa sem expor erros ao usuário nem interromper navegação.
  - Suíte de testes unitários `TelemetriaTests.swift` com todos os 29 testes verdes na CI do PR #292 na `main`.
- **O que falta:**
  - Nada no app.
- **Bloqueado por quê:**
  - Nenhum bloqueio.

---

## 3. Pipeline de Release e Prontidão para o TestFlight

### 3.1. Automação GitHub Actions (`.github/workflows/testflight.yml`)
- **Gatilhos:**
  - Tag `v*` no branch `main` (ex.: `v0.4.0` ou `v0.5.0`): aciona automaticamente o pipeline de archive, assinatura e upload.
  - `workflow_dispatch`: permite disparos manuais selecionando ambiente (`Frila-Beta` ou `Frila-Prod`), versão e flags (`ensaio_falha`, `medicao`, `enviar`).
- **Segurança da Tag:**
  - O workflow confere explicitamente se o commit da tag é ancestral de `origin/main` (`git merge-base --is-ancestor`), bloqueando tags fora da branch principal.
- **Build Number:**
  - Gerado de forma estritamente determinística e crescente no formato UTC: `YYYYMMDD.HHMMSS`.

### 3.2. Script de Empacotamento (`iOS/Scripts/enviar-testflight.sh`)
- Executa:
  1. `xcodebuild archive` para o esquema selecionado com as versões ajustadas;
  2. `xcodebuild -exportArchive` gerando o `.ipa` assinado para App Store Connect com `-allowProvisioningUpdates`;
  3. Verificação do bundle com `conferir-release.sh` (garantindo `ITSAppUsesNonExemptEncryption = false`, ícone compilado, ausência de ganchos de debug, ausência de tracking e `aps-environment = production`);
  4. Extração e upload de dSYMs do app e frameworks para o Firebase Crashlytics via `upload-symbols`;
  5. Envio do artefato ao App Store Connect API via `xcodebuild -exportArchive -exportOptionsPlist ... upload`.

### 3.3. Inventário de Segredos no GitHub Actions
Conforme verificado via `gh secret list`, todos os segredos necessários para a esteira já se encontram cadastrados no repositório:

| Segredo | Finalidade | Data de Cadastro / Atualização | Status |
|---|---|:---:|:---:|
| `APP_STORE_CONNECT_API_KEY_P8` | Chave privada da App Store Connect API | 07/10/2026 | Cadastrado no repositório |
| `APP_STORE_CONNECT_API_KEY_ID` | Identificador da Chave (Key ID) | 07/10/2026 | Cadastrado no repositório |
| `APP_STORE_CONNECT_API_ISSUER_ID` | Issuer ID da conta Apple Developer | 07/10/2026 | Cadastrado no repositório |
| `APPLE_DISTRIBUTION_CERT_P12_BASE64` | Certificado Apple Distribution em base64 | 14/10/2026 | Cadastrado no repositório |
| `APPLE_DISTRIBUTION_CERT_P12_PASSWORD` | Senha do certificado P12 | 14/10/2026 | Cadastrado no repositório |
| `FRILA_FIREBASE_GOOGLE_SERVICE_INFO_DEV_B64` | Plist do Firebase Dev codificado em base64 | 23/09/2026 | Cadastrado no repositório |
| `FRILA_FIREBASE_GOOGLE_SERVICE_INFO_PROD_B64` | Plist do Firebase Prod codificado em base64 | 23/09/2026 | Cadastrado no repositório |
| `FRILA_SUPABASE_DEV_URL` | Endpoint da API Supabase Dev | 24/09/2026 | Cadastrado no repositório |
| `FRILA_SUPABASE_DEV_PUBLISHABLE_KEY` | Chave pública do Supabase Dev | 24/09/2026 | Cadastrado no repositório |
| `FRILA_SUPABASE_PROD_URL` | Endpoint da API Supabase Prod | 25/09/2026 | Cadastrado no repositório |
| `FRILA_SUPABASE_PROD_PUBLISHABLE_KEY` | Chave pública do Supabase Prod | 25/09/2026 | Cadastrado no repositório |

O que cabe ao proprietário (João Paulo) é unicamente a conferência administrativa de que a chave de API possui a função de **Admin** ou **App Manager** no portal App Store Connect para permitir a geração de perfis de provisionamento e upload de novos builds.

---

## 4. Matriz: Critérios dos Cartões x Estado x Bloqueios

### 4.1. Cartão `0jEemYAM` (Mandar build 0.4 para o TestFlight - 20/10)
| Critério do Cartão | Status no App | O que falta / Onde parou | Bloqueado por quê |
|---|---|---|---|
| **Build 0.4 processado no ASC em 20/10** | **Pronto no código** | Disparar o workflow `testflight.yml` com tag `v0.4.0` ou manualmente. | Criação da tag `v0.4.0` por João Paulo e conferência do papel da chave ASC. Segredos já presentes no GitHub Actions. |
| **Os cinco instalam pelo TestFlight e fazem publicar, candidatar, confirmado e contato** | **Pronto no código** | Fluxo coberto por testes unitários e testes de UI (`CicloDePontaAPontaUITests`, `AutenticacaoTests`), que existem e rodam na suíte de CI da `main`. | Processamento do build na Apple e distribuição ao grupo interno. |
| **Upload feito pela CI a partir de uma tag, reproduzível** | **Pronto no código** | `testflight.yml` e `enviar-testflight.sh` testados e parametrizados. | Criação da tag `v0.4.0`. |
| **O build não pede resposta manual sobre criptografia** | **100% Conforme** | `ITSAppUsesNonExemptEncryption = false` validado por portão no `conferir-release.sh`. | Nenhum bloqueio. |
| **Alguém de fora entra nos 2 perfis num iPhone limpo e vê ciclo; vídeo anexado** | **Pronto no código** | Telas e fluxos prontos. | Ação física humana (gravação do vídeo com o build instalado). |
| **Falha forçada no build de ensaio aparece simbolizada no Crashlytics** | **Pronto no código** | Flag `FRILA_ENSAIO_FALHA=1` e botão "Forçar falha (ensaio)" implementados; upload de dSYMs automático no script. | Disparo de build de ensaio (`ensaio_falha: true`) na CI. |

### 4.2. Cartão `Kd0RVh9q` (TestFlight 0.5 com push, check-in e avaliação - 29/10)
| Critério do Cartão | Status no App | O que falta / Onde parou | Bloqueado por quê |
|---|---|---|---|
| **Build 0.5 disponível para os testadores externos em 29/10** | **Pronto no código** | Disparo do workflow com tag `v0.5.0` ou `workflow_dispatch`. | Submissão e aprovação do Beta App Review no App Store Connect. |
| **Push de vaga chega a um testador de fora do time** | **Pronto no código** | Recepção, token FCM, NSE e rotas de toque 100% integrados. | Habilitação do App Group no portal Apple e deploy do backend `frila-backend#184` em `frila-dev`. |
| **Notas de versão publicadas no TestFlight** | **Pronto na documentação** | Texto completo e revisado estruturado em `iOS/Docs/NotasTestFlight05.md`. | Colagem do texto no campo "O que testar" do App Store Connect. |
| **No build 0.5, check-in por localização e avaliação funcionam contra frila-dev** | **Pronto no código** | ViewModels, geolocalização in-app, manual e avaliação implementados e testados. | Homologação em campo por testador externo com turno real no DF. |

---

## 5. Estado Atual dos Pull Requests Relacionados (S2 / TestFlight 0.5)

| PR | Título / Escopo | Status Atual | Observações |
|:---:|---|:---:|---|
| **#291** | `feat(ios): extensão de serviço de notificações (NSE)` | **Mergeado na `main`** | App Group `group.com.frila.org.app` e isolamento `vinculo_id`. |
| **#292** | `feat(telemetria): fiação completa dos 14 eventos` | **Mergeado na `main`** | 29 testes unitários verdes em `TelemetriaTests.swift`. |
| **#299** | `perf(ios): timeouts sensíveis e retry idempotente` | **Mergeado na `main`** | Timeouts sensíveis e retentativa única com espera fixa de 150ms para leituras. |
| **#304** | `docs(ios): gap analysis e prontidão TestFlight 0.5` | **Mergeado na `main`** | Diagnóstico técnico e alinhamento dos 7 apontamentos. |
| **#306** | `docs(android): proposta arquitetural e técnica v1.1` | **Mergeado na `main`** | Cartão `XTijdYVk` delimitado aos Épicos E1 e E2. |
| **#305** | `feat(ios): gate de conferência estrita de contrato` | Aberto, aprovado no head `95c40de` (CI em andamento) | Validador dinâmico OpenAPI 0.2.41 e autoteste de 10 passos. |
| **#298** | `fix(ios): acessibilidade, rótulos e Dynamic Type` | Aberto na fila de merge | Auditoria completa de acessibilidade VoiceOver. |
| **#300** | `fix(ios): unificação de padrões de estado e banners` | Aberto na fila de merge | Padronização de componentes de feedback offline e carregamento. |
| **#301** | `docs(ios): laudo de conformidade App Privacy Details` | Aberto na fila de merge | Mapeamento de dados LGPD e privacidade para a App Store. |
| **#302** | `feat(ios): consolidação de maioridade e perfil` | Aberto na fila de merge | Validação da regra RN20 (maioridade) no cadastro e perfil. |
| **#303** | `docs(ios): checklist oficial de submissão App Store` | Aberto na fila de merge | Documentação e roteiro oficial para o processo de revisão Apple. |

---

## 6. Próximos Passos Recomendados para o Time

1. **Ações Técnicas Imediatas (Trabalho Autônomo):**
   - Acompanhar a conclusão da CI do PR #305 (Gate de Contrato) e seu merge pela Rainha Marika.
   - Puxar as tarefas subsequentes de saneamento dos avisos informativos de DTOs e reprovação estrita.
2. **Ações para o Proprietário (João Paulo):**
   - Conferir permissão da chave App Store Connect API no portal Apple (Admin ou App Manager).
   - Criar o App Group `group.com.frila.org.app` no portal Apple Developer e associá-lo aos App IDs do app e da extensão de push.
   - Gerar a tag `v0.4.0` na branch `main` para acionar o primeiro upload automático ao TestFlight para o grupo interno.
   - Testar o push manual via console Firebase num iPhone físico de teste assim que o `frila-backend#184` for implantado no `frila-dev`.
