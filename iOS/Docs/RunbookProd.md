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
| Credenciais SMTP (Supabase Auth) | Painel do Supabase, frila-prod | Envio de código de entrada por e-mail | **pendente** (cartão SMTP) |
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

Estado em 11/10/2026, conforme [ExternalSetup](ExternalSetup.md) item 9 e a triagem.

| Item | Cartão | Responsável | Descrição |
|---|---|---|---|
| Migrações do banco | #76 (ambiente de produção) | Backend / Cauê | As 29+ migrações do `frila-dev` precisam ser aplicadas no `frila-prod` |
| Auth (Supabase) | #76 | Backend / Cauê | Configuração do Supabase Auth com templates de e-mail, redirect URLs |
| SMTP próprio | Cartão SMTP | Cauê | SPF, DKIM e DMARC do domínio `frila.app`; configuração no painel do Supabase |
| FCM (Edge Function) | #76 | Backend | `service_role` e service account do FCM como segredo de Edge Function |
| `pg_cron` | #76 / #207 | Backend | Agendador do despacho de turnos |
| Esquema da tag → Prod | [CI](CI.md) | Cauê | No `testflight.yml`, trocar `ESQUEMA_DA_TAG: Frila-Beta` para `Frila-Prod` |
| Dados de teste | #76 | Cauê | Catálogo e duas contas de revisão, nada mais |

---

## 4. Build e deploy

### Build de Release-Prod (CI de PR)

A CI compila o `Frila-Prod` com os segredos `FRILA_SUPABASE_PROD_*` e
`FRILA_FIREBASE_GOOGLE_SERVICE_INFO_PROD_B64`. Se qualquer um faltar, a etapa falha com
`FRILA_SUPABASE_PROD_URL is not set`. O `conferir-release.sh` verifica criptografia,
privacidade, ganchos de Debug, `aps-environment = production` e ATS.

### TestFlight (Prod)

Quando o frila-prod tiver as migrações:

1. No `testflight.yml`, ative `ESQUEMA_DA_TAG: Frila-Prod`.
2. Tag no `main`: `git tag -a v1.0.0 -m "Build 1.0" && git push origin v1.0.0`.
3. Acompanhe em Actions > TestFlight. O job faz archive, assinatura, conferência, dSYMs no
   Crashlytics do frila-prod e envio ao App Store Connect.

Disparo manual: Actions > TestFlight > Run workflow, escolha `Frila-Prod`.

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

## 6. Alertas pendentes (para configurar)

O cartão #76 pede "alerta de teste chega ao time por e-mail". Opções a avaliar:

| Ferramenta | O que monitora | Como configurar |
|---|---|---|
| Firebase Crashlytics Alerts | Novas falhas, regressões, picos de erros | Firebase Console > Crashlytics > Alertas > Integrar com e-mail |
| Supabase (observabilidade) | Erros no banco, Auth, Edge Functions | Painel do Supabase > Logs / Health Reports |
| GitHub Actions | Falhas de CI | Settings > Notifications (já ativo por padrão para quem participa) |

---

## 7. Checklist antes de liberar para produção

- [ ] Migrações do `frila-dev` aplicadas no `frila-prod` (banco não está mais vazio).
- [ ] Auth configurado no frila-prod (templates, redirect URLs, SMTP próprio com SPF/DKIM).
- [ ] Edge Functions do FCM com `service_role` e service account como segredos.
- [ ] `pg_cron` ativo para o despacho.
- [ ] Catálogo e duas contas de revisão criados em produção; nenhum outro dado de teste.
- [ ] `testflight.yml`: `ESQUEMA_DA_TAG` apontando para `Frila-Prod`.
- [ ] Build Prod compilado, conferido pelo `conferir-release.sh` e enviado ao TestFlight.
- [ ] Ensaio de falha no Crashlytics do frila-prod: falha aparece simbolizada.
- [ ] Push de teste enviado pelo console FCM do frila-prod: notificação chega ao aparelho.
- [ ] Código de entrada por e-mail chega na caixa de entrada (Gmail, iCloud, Outlook).
- [ ] Alerta de teste configurado e chegando ao time por e-mail.

---

## 8. Referências

- [Environments](Environments.md) — ambientes, segredos e como o valor chega ao app.
- [ExternalSetup](ExternalSetup.md) — dependências externas e estado de cada uma.
- [CI](CI.md) — integração contínua e TestFlight.
- [CrashReporting](CrashReporting.md) — Crashlytics, dSYMs e App Privacy.
- [Push](Push.md) — push, APNs, FCM e roteiro de teste no aparelho.
- [SegurancaEPrivacidade](SegurancaEPrivacidade.md) — auditoria de segurança e rótulo de privacidade.
