# Runbook do ambiente de produção (frila-prod)

Referência operacional para o Cauê manter o frila-prod em funcionamento.
Segredos aparecem **só pelo nome**; os valores ficam no cofre do time (`Frila-Team.kdbx`) e nos
secrets do GitHub. Para a arquitetura dos ambientes, veja [Environments](Environments.md).

---

## 1. Inventário de segredos

| Segredo | Onde fica | Para que serve | Estado |
|---|---|---|---|
| `FRILA_SUPABASE_PROD_URL` | GitHub Actions + `Secrets.xcconfig` local | URL do projeto Supabase frila-prod | configurado |
| `FRILA_SUPABASE_PROD_PUBLISHABLE_KEY` | GitHub Actions + `Secrets.xcconfig` local | Chave publicável do frila-prod | configurado |
| `FRILA_FIREBASE_GOOGLE_SERVICE_INFO_PROD_B64` | GitHub Actions | plist Firebase Prod em base64 | configurado |
| `APP_STORE_CONNECT_API_KEY_ID` | GitHub Actions | Key ID da chave Admin da App Store Connect API | configurado |
| `APP_STORE_CONNECT_API_ISSUER_ID` | GitHub Actions | Issuer ID da chave Admin | configurado |
| `APP_STORE_CONNECT_API_KEY_P8` | GitHub Actions | Conteúdo da `.p8` da chave Admin | configurado |
| Chave APNs `.p8` (ID `89CNDKBL96`) | Cofre KeePassXC do time + console FCM de frila-dev e frila-prod | Entrega de push pelo Firebase Messaging | configurado no FCM |
| `GoogleService-Info.plist` (Prod) | Cofre KeePassXC; injetado pela CI com `inject-firebase-config.sh` | Crashlytics e FCM do projeto Firebase `frila-prod` | configurado |
| `service_role` do frila-prod | Vault/segredo do Supabase, acessível pelo painel | Operações administrativas do backend, Edge Functions | **backend** |
| Credenciais SMTP (Supabase Auth) | Painel do Supabase, frila-prod | Envio de código de entrada por e-mail | **feito em 20/10** (Resend, remetente `verificacao@frilabr.com`) |
| `pg_cron` / Agendador | Painel do Supabase, frila-prod | Despacho e tarefas recorrentes | **pendente** (cartão #76 / entrega contínua #207) |

### Rotação de segredos

1. Gere o novo valor no provedor (Supabase Dashboard / Firebase Console / App Store Connect).
2. `Scripts/generate-supabase-secrets.sh` para o `Secrets.xcconfig` local.
3. Atualize o secret do GitHub: `read -rs VALOR && printf '%s' "$VALOR" | gh secret set NOME --repo FrilaApp/frila-frontend`.
4. Valide: dispare a CI ou um build manual e confira que ele compila com o novo valor.
5. Revogue o valor antigo no provedor.
6. Registre data e responsável no cofre do time.
7. Nunca imprima chaves, tokens ou valores de segredo em log, PR ou chat.

---

## 2. Projetos e contas

| Serviço | Projeto | Região | Conta / Organização |
|---|---|---|---|
| Supabase | `frila-prod` | `sa-east-1` | Organização `Frila'orgs` |
| Firebase | `frila-prod` | — | Conta de proprietário do Cauê |
| Apple Developer | Team `8B7F7G3Y2U` | — | Conta do Cauê |
| App Store Connect | App `Frila: Turnos e Vagas`, Apple ID `6815311991`, bundle `com.frila.org.app` | — | Conta do Cauê |
| GitHub | `FrilaApp/frila-frontend` (privado) | — | Organização `FrilaApp` |

**Supabase gratuito:** projeto sem uso por uma semana é pausado automaticamente. Reativar exige
Owner ou Admin da organização `Frila'orgs`.

---

## 3. O que falta para o frila-prod funcionar ponta a ponta

Atualizado em 28/10/2026 com base em comandos locais e execuções da CI (o estado preliminar de 11/10/2026 descrevia o ambiente vazio; a data de provisionamento em 26/10 é proposta no PR #540, ainda aberto: não verificado).

| Item | Cartão / Origem | Responsável | Estado em 28/10/2026 | Evidência / Como verificar |
|---|---|---|---|---|
| Migrações do banco | #76 (ambiente de produção) | Backend / Matheus / Cauê | **não verificado** (a probe `saude` respondeu HTTP 200 via curl em 28/10, o que não prova migrações nem tabelas no banco de produção). | `curl -s -i "$FRILA_SUPABASE_PROD_URL/functions/v1/saude"` respondeu `HTTP/2 200` com `{"ok":true,"status":"saudavel"}`; migrações aplicadas no banco de produção: **não verificado** (depende de conferência no banco de dados por Matheus/Cauê). |
| Funções publicadas | RunbookProd §5 e §6 | Backend / Matheus | **não verificado** em produção (funções essenciais do contrato estão implementadas no repositório; `saude` respondeu HTTP 200, mas a execução das demais RPCs e Edge Functions em produção não foi verificada). | Resposta HTTP 200 na probe `saude`. As demais funções (`configuracao_do_app`, `meus_turnos`, `registrar_dispositivo`, `remover_dispositivo`, `despachar`, `enviar-push`) dependem de sessão e chamadas autenticadas em produção (depende de Matheus/Jotapê). |
| Auth (Supabase) | #76 | Backend / Cauê | **não verificado** (templates, redirect URLs e envio real de OTP em produção dependem de teste no painel/aparelho por Cauê; SMTP próprio com Resend e remetente `verificacao@frilabr.com` registrado em 20/10 no Inventário §1). | Entrega real de e-mails em caixas de entrada no ambiente de produção: **não verificado** (depende de teste manual no painel/aparelho por Cauê). |
| SMTP próprio | Cartão SMTP | Cauê | **não verificado** em produção (configuração registrada em 20/10/2026 com Resend, remetente `verificacao@frilabr.com`, no Inventário de Segredos §1). | Disparo e entrega contínua em produção: **não verificado** (depende de Cauê). |
| FCM (Edge Function) | #76 | Backend / Cauê | **não verificado** (funções `registrar_dispositivo`, `remover_dispositivo` e `enviar-push` implementadas no repositório; segredos de produção e entrega real de push não verificados). | Entrega real de push a partir do console FCM do `frila-prod` a token de aparelho físico: **não verificado** (depende de envio por Cauê). |
| `pg_cron` | #76 / #207 | Backend / Matheus | **não verificado** (job `reprocessar_despacho` e extensão `pg_cron` no banco de produção não verificados). | Ativação e histórico de execuções no painel SQL do Supabase de produção: **não verificado** (depende de Matheus/Cauê). |
| Esquema da tag → Prod | [CI](CI.md) / PR #540 | Cauê | **Concluído neste PR**: `ESQUEMA_DA_TAG: Frila-Prod` ativo no `testflight.yml` (envio manual com esquema Frila-Prod já validado na CI run 40632099918; tags passam a mandar Frila-Prod). | `gh run view 40632099918 -R FrilaApp/frila-frontend`: `workflow_dispatch` manual executado em 28/10/2026 enviou `Frila-Prod 0.5.3 (20261028.42414)` ao TestFlight. PR #540 na branch `ci/testflight-prod`. |
| Dados de teste / Demonstração | #76 / Cartões 5boVdM0t, RzllRo3o | Backend / Cauê | **não verificado** (o script `semear-vagas-demonstracao.sh` está implementado no repositório, mas sua execução em dev/prod não foi verificada e as variáveis `EMAIL_CONTRATANTE` e `ESTABELECIMENTO_BAR_DA_REVISAO` precisam existir no ambiente; o script `renovar-demonstracao.sh` descarta a saída de erro e não prova renovação remota). | Presença e execução real dos scripts com dados e contas no `frila-prod`: **não verificado** (depende de confirmação em produção por Cauê/Matheus). |

---

## 4. Build e deploy

### Build de Release-Prod (CI de PR)

A CI compila o `Frila-Prod` com os segredos `FRILA_SUPABASE_PROD_*` e
`FRILA_FIREBASE_GOOGLE_SERVICE_INFO_PROD_B64`. Se qualquer um faltar, a etapa falha com
`FRILA_SUPABASE_PROD_URL is not set`. O `conferir-release.sh` verifica criptografia,
privacidade, ganchos de Debug, `aps-environment = production` e ATS.

### TestFlight (Prod)

O envio manual com o esquema `Frila-Prod` foi realizado com sucesso em 28/10/2026 (run 40632099918, versão 0.5.3). Com este PR (#540):

1. No `testflight.yml`, a linha ativa é `ESQUEMA_DA_TAG: Frila-Prod` (tags passam a mandar o Frila-Prod).
2. Tag no `main`: `git tag -a v1.0.0 -m "Build 1.0" && git push origin v1.0.0`.
3. Acompanhe em Actions > TestFlight. O job faz archive, assinatura, conferência, dSYMs no
   Crashlytics do frila-prod e envio ao App Store Connect.

Disparo manual: Actions > TestFlight > Run workflow, escolha `Frila-Prod` (já validado na run 40632099918).

### Reproduzir localmente

```sh
cd iOS
Scripts/generate-supabase-secrets.sh prod
Scripts/inject-firebase-config.sh prod
ASC_KEY_PATH=~/caminho/AuthKey.p8 ASC_KEY_ID=... ASC_ISSUER_ID=... \
  Scripts/enviar-testflight.sh Frila-Prod 1.0.0 --sem-envio
```

---

## 5. Monitoramento

### Crashlytics (Firebase, projeto frila-prod)

- Painel: [Firebase Console](https://console.firebase.google.com/) > projeto `frila-prod` > Crashlytics.
- Falhas fatais retidas sem dSYM: a falha não aparece enquanto faltar o dSYM de qualquer binário
  da pilha. Os dSYMs são enviados pelo `enviar-testflight.sh` (app + 4 frameworks).
- Erros não fatais: domínio `frila.api.<codigo>`, uma issue por código.
- Dados nos eventos: apenas `codigo`, `rpc` e `duracao_ns`. Sem `setUserID`, sem dados pessoais.
- Para validar: faça o ensaio de falha pelo TestFlight ([CI](CI.md#ensaio-de-falha-critério-do-203-antes-de-2010))
  com o `Frila-Prod` e confirme que a falha aparece simbolizada no painel do frila-prod.

### Supabase (painel do frila-prod)

- **Auth:** verificar que os códigos de entrada (OTP) estão chegando; monitorar falhas de envio
  no log do Auth.
- **Database:** conferir que as RPCs respondem (ex.: `configuracao_do_app`, `meus_turnos`).
- **Edge Functions:** log do FCM / push; conferir que `registrar_dispositivo` e `remover_dispositivo`
  funcionam.
- **Projeto pausado:** se o frila-prod ficar sem uso por 7 dias no plano gratuito, o Supabase
  pausa o projeto. O Owner/Admin da org `Frila'orgs` precisa reativar manualmente.

### CI / GitHub Actions

- Workflow `ios.yml`: CI de PR. Parte 1 + Parte 2. Limite de 90 min por job.
- Workflow `testflight.yml`: build de release. Só por tag `vX.Y.Z` no `main` ou disparo manual.
- Workflow `app-store-connect.yml`: operações na App Store Connect API (grupo interno,
  classificação). Só por disparo manual.
- Custo: orçamento de US$ 0 com bloqueio. Esgotar a cota interrompe a CI sem gerar cobrança.

### Push (APNs / FCM)

- Conferir que o console FCM do frila-prod consegue enviar mensagem de teste a um token.
- No build Prod: `codesign -d --entitlements :- Frila.app | grep -A1 aps-environment` deve
  mostrar `production`.
- Roteiro completo de teste no aparelho: [Push](Push.md#roteiro-de-teste-no-aparelho).

---

## 6. Checagem diária do piloto (10 min)

Roteiro operacional de 10 minutos para execução diária durante o piloto, cobrindo
a saúde dos serviços no Supabase, Firebase e limites da infraestrutura.

### Passo 1: Alertas emitidos nas últimas 24 h (~2 min)

- **Onde ver:** Painel do Supabase > **SQL Editor** ou caixa de e-mail de alertas da equipe.
- **SQL:**
  ```sql
  select codigo, ultimo_em, suprimidos
    from privado.alerta_emitido
   where ultimo_em > now() - interval '24 hours'
   order by ultimo_em desc;
  ```
- **Ação por código:**
  | Código de alerta | Significado | Ação recomendada |
  |---|---|---|
  | `job_despacho_parado` | Job `reprocessar_despacho` ausente ou inativo no pg_cron | Verificar `cron.job` e reativar o agendamento |
  | `fila_despacho_antiga` | Mensagens retidas há mais de 15 min em `pgmq.q_despacho` | Investigar Edge Function `despachar` e conectividade |
  | `fila_email_antiga` | Mensagens retidas há mais de 15 min em `pgmq.q_email` | Conferir worker/cron de envio e serviço SMTP |
  | `job_cron_falhou` | Falhas nos últimos 15 min em `cron.job_run_details` | Consultar: `select * from cron.job_run_details where status = 'failed' order by end_time desc limit 10;` |
  | `notificacao_push_falhou` | Notificações com `estado_entrega = 'falhou'` na última hora | Conferir motivo em `public.notificacao` e logs da Edge Function `enviar-push` |
  | `fcm_configuracao_suspeita` | Erros `NOT_FOUND` no FCM (project_id ou URL incorreta) | Conferir secret `FCM_SERVICE_ACCOUNT` da Edge Function |
  | `despacho_esperando_alem_do_teto` | Despachos retidos além do teto da RN23 (> 45 min) em vagas ativas | Investigar bloqueio de profissional ou falha no agrupamento |
  | `falha_execucao_edge_function` | Edge Functions registraram falha técnica recente | Consultar `privado.falha_execucao` (Passo 2) |

### Passo 2: Falhas de execução recentes (~1 min)

- **Onde ver:** Painel do Supabase > **SQL Editor** e **Edge Functions** > Logs.
- **SQL:**
  ```sql
  select origem, codigo, detalhes, criada_em
    from privado.falha_execucao
   where criada_em > now() - interval '24 hours'
   order by criada_em desc
   limit 50;
  ```
- **Ação:** Se houver recorrência para uma mesma origem e código, inspecionar logs da Edge Function correspondente no painel do Supabase.

### Passo 3: Notificações com falha (~1 min)

- **Onde ver:** Painel do Supabase > **SQL Editor**.
- **SQL:**
  ```sql
  select tipo, motivo_falha, count(*) as total
    from public.notificacao
   where estado_entrega = 'falhou'
     and enviada_em > now() - interval '24 hours'
   group by tipo, motivo_falha
   order by total desc;
  ```
- **Ação:** Avaliar se a causa é pontual (ex.: token APNs/FCM expirado/desinstalado) ou sistêmica (credencial inválida ou falha no provedor de push).

### Passo 4: Fila do despacho (~1 min)

- **Onde ver:** Painel do Supabase > **SQL Editor**.
- **SQL:**
  ```sql
  select count(*) as total_mensagens,
         now() - min(enqueued_at) as idade_mais_velha
    from pgmq.q_despacho;
  ```
- **Ação:** Idade superior a 15 minutos é anormal e indica represamento (dispara alerta `fila_despacho_antiga`). Verificar se o pg_cron está ativo e se a Edge Function `despachar` está respondendo.

### Passo 5: Falhas do app no Crashlytics (~2 min)

- **Onde ver:** [Firebase Console](https://console.firebase.google.com/) > projeto `frila-prod` > **Crashlytics**.
- **O que checar:**
  - Taxa de usuários sem falhas (*crash-free users*).
  - Novas falhas fatais (*crashes*): confirmar presença de dSYM e stack trace simbolizado.
  - Erros não fatais agrupados pelo domínio `frila.api.<codigo>`.

### Passo 6: E-mails não entregues (~1 min)

- **Onde ver:** Painel do Supabase > **Authentication** > **Logs** (ou painel do provedor SMTP Resend).
- **Estado atual:** Feito em 20/10 (Resend, remetente `verificacao@frilabr.com`).
- **Rotina com SMTP próprio ativo:**
  - Conferir rejeições (*bounces*) e falhas de entrega de OTP no painel do provedor (Resend).
  - Conferir a fila `pgmq.q_email`:
    ```sql
    select count(*) as total_mensagens,
           now() - min(enqueued_at) as idade_mais_velha
      from pgmq.q_email;
    ```

### Passo 7: Limites do plano gratuito do Supabase (~1 min)

- **Onde ver:** Painel do Supabase > projeto `frila-prod` > **Settings** > **Usage** (ou aba **Reports**).
- **O que checar:**
  - **Database Size:** conferir consumo em relação ao limite de 500 MB.
  - **Monthly Active Users (MAU):** conferir consumo em relação a 50.000 usuários ativos/mês.
  - **Edge Function Invocations:** conferir volume em relação a 500.000 chamadas/mês.
  - **Inatividade:** confirmar tráfego recente (projetos sem atividade por 7 dias são pausados automaticamente no plano gratuito).

### Passo 8: Registro do dia (~1 min)

- **O que registrar:**
  - **Sem incidente:** anotar data, hora e confirmação de que todos os itens estão verdes.
  - **Com incidente:** registrar horário de detecção, sintoma/código, causa provável e ação de contenção/correção (ou número do cartão/issue aberta).
- **Onde registrar:** a definir pelo Cauê (ex.: issue no repositório, canal da operação ou documento de acompanhamento).

---

## 7. Alertas pendentes (para configurar)

O cartão #76 pede "alerta de teste chega ao time por e-mail". Opções a avaliar:

| Ferramenta | O que monitora | Como configurar |
|---|---|---|
| Firebase Crashlytics Alerts | Novas falhas, regressões, picos de erros | Firebase Console > Crashlytics > Alertas > Integrar com e-mail |
| Supabase (observabilidade) | Erros no banco, Auth, Edge Functions | Painel do Supabase > Logs / Health Reports |
| GitHub Actions | Falhas de CI | Settings > Notifications (já ativo por padrão para quem participa) |

---

## 8. Checklist antes de liberar para produção

- [ ] Migrações do `frila-dev` aplicadas no `frila-prod` (a probe `saude` respondeu `HTTP/2 200` em 28/10 via `curl -s -i "$FRILA_SUPABASE_PROD_URL/functions/v1/saude"`, mas a aplicação efetiva de migrações e tabelas em produção é **não verificado** — depende de Matheus/Cauê).
- [ ] Auth configurado no frila-prod (templates e redirect URLs; SMTP configurado em 20/10 com Resend, mas entrega real de OTP em produção é **não verificado** — depende de Cauê).
- [ ] Edge Functions do FCM com `service_role` e service account como segredos (funções implementadas no repositório; envio de push em produção é **não verificado** — depende de Cauê com aparelho físico).
- [ ] `pg_cron` ativo para o despacho (agendamento no banco de produção é **não verificado** — depende de Cauê/Matheus no painel SQL do Supabase).
- [ ] Catálogo e duas contas de revisão criados em produção (scripts implementados no repositório, mas execução em dev/prod é **não verificado** — depende de Cauê/Matheus).
- [x] `testflight.yml`: `ESQUEMA_DA_TAG` apontando para `Frila-Prod`.
- [x] Build Prod compilado e enviado ao TestFlight (comprovado por disparo manual no run 40632099918 em 28/10/2026: `Frila-Prod 0.5.3` enviado com sucesso ao App Store Connect; a execução do `conferir-release.sh` é invocada por `enviar-testflight.sh:202` antes do envio e o passo terminou em sucesso, embora o log da CI não imprima a conferência de forma destacada).
- [ ] Ensaio de falha no Crashlytics do frila-prod: falha aparece simbolizada (não verificado — depende de ensaio no TestFlight por Cauê).
- [ ] Push de teste enviado pelo console FCM do frila-prod: notificação chega ao aparelho (não verificado — depende de aparelho físico com Cauê).
- [ ] Código de entrada por e-mail chega na caixa de entrada (Gmail, iCloud, Outlook) (não verificado — depende de Cauê).
- [ ] Alerta de teste configurado e chegando ao time por e-mail (não verificado — depende de Cauê).

---

## 9. Referências

- [Environments](Environments.md) — ambientes, segredos e como o valor chega ao app.
- [ExternalSetup](ExternalSetup.md) — dependências externas e estado de cada uma.
- [CI](CI.md) — integração contínua e TestFlight.
- [CrashReporting](CrashReporting.md) — Crashlytics, dSYMs e App Privacy.
- [Push](Push.md) — push, APNs, FCM e roteiro de teste no aparelho.
- [SegurancaEPrivacidade](SegurancaEPrivacidade.md) — auditoria de segurança e rótulo de privacidade.
