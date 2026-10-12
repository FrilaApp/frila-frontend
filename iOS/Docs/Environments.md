# Ambientes e segredos

| Valor | local | frila-dev | frila-prod | Local de armazenamento |
|---|---|---|---|---|
| Cliente da API | `ApiClienteEmMemoria` | Supabase | Supabase | `FRILA_API_MODE` no `.xcconfig` |
| URL Supabase | `127.0.0.1:54321` (só com `supabase`) | projeto dev | projeto prod | `Secrets.xcconfig` local e segredo da CI |
| Chave publicável | não usada no modo `mock` | dev | prod | `Secrets.xcconfig` local e segredo da CI |
| Sessão do usuário | Keychain | Keychain | Keychain | aparelho |
| `GoogleService-Info.plist` | não copiado | dev | prod | fora do Git, injetado pela CI |
| APNs `.p8` | não usado | Firebase dev | Firebase prod | console seguro, nunca no app |
| FCM service account | Supabase local | Supabase dev | Supabase prod | segredo de Edge Function |
| `service_role`, SMTP e agendador | Supabase local | Supabase dev | Supabase prod | segredo/Vault do Supabase |

## Segredos do GitHub Actions

| Segredo | Conteúdo | Estado |
|---|---|---|
| `FRILA_FIREBASE_GOOGLE_SERVICE_INFO_DEV_B64` | plist Firebase Dev em base64 | configurado |
| `FRILA_FIREBASE_GOOGLE_SERVICE_INFO_PROD_B64` | plist Firebase Prod em base64 | configurado |
| `FRILA_SUPABASE_DEV_URL` | `https://<ref>.supabase.co` do frila-dev | configurado |
| `FRILA_SUPABASE_DEV_PUBLISHABLE_KEY` | chave `sb_publishable_` do frila-dev | configurado |
| `FRILA_SUPABASE_PROD_URL` | `https://<ref>.supabase.co` do frila-prod | configurado |
| `FRILA_SUPABASE_PROD_PUBLISHABLE_KEY` | chave `sb_publishable_` do frila-prod | configurado |

Para cadastrar sem expor o valor: `read -rs VALOR && printf '%s' "$VALOR" | gh secret set NOME --repo FrilaApp/frila-frontend`.

## Como o valor chega ao app

`Shared.xcconfig` declara as quatro variáveis `FRILA_SUPABASE_*` vazias e inclui o `Secrets.xcconfig` opcional. `Dev.xcconfig` e `Prod.xcconfig` copiam o par do ambiente para `FRILA_SUPABASE_URL` e `FRILA_SUPABASE_PUBLISHABLE_KEY`. `Sources/App/Info.plist` leva essas variáveis ao Info.plist, porque `INFOPLIST_KEY_*` só aceita chaves da Apple. Até o commit `a91176c` as chaves `FRILA_*` não chegavam ao Info.plist, e Dev e Prod rodavam sempre o dublê em memória.

A configuração `Release-Beta` (esquema `Frila-Beta`) é compilada como Release e aponta para o frila-dev: é a do TestFlight antes do frila-prod existir. Ela usa os valores de Dev do `Secrets.xcconfig`, mas não inclui o `Dev.xcconfig`, para não herdar o `DEBUG`. `Release-Prod` aponta para o frila-prod (esquema `Frila-Prod`, configurado no `project.yml` para os builds de produção): as migrações de produção entram pelo cartão do ambiente de produção (#76), com a entrega contínua do #207. Cada abertura registra no log o ambiente e a URL, nunca a chave.

Sem valor, Dev, Beta e Prod não voltam ao simulado: falham na CI e, localmente, avisam no build e abrem na tela de configuração incompleta.

Rotação: gere o novo valor no provedor, rode `Scripts/generate-supabase-secrets.sh` e atualize o segredo do GitHub, valide, revogue o antigo e registre data/responsável. Nunca imprima chaves, token, e-mail, telefone ou coordenada em log.

## Decisão de arquitetura: padronização no `frila-dev` e dispensa de Docker local

Por decisão de produto e infraestrutura liderada pelo Cauê em 07/10/2026, **não há obrigatoriedade nem necessidade de subir infraestrutura local via Docker/Supabase CLI** por outros desenvolvedores do time:
1. **Servidor oficial de desenvolvimento:** O ambiente `frila-dev` é o backend centralizado e compartilhado oficial para desenvolvimento e validação integrada do app.
2. **Desenvolvimento local autônomo:** Localmente, os testes unitários e de interface rodam de forma autônoma e determinística utilizando o cliente em memória (`ApiClienteEmMemoria` com cenários `-FRILA_SCENARIO`), eliminando fricção de setup local, dependência de daemon Docker ou discrepâncias de seeds locais.
3. **Resolução do Cartão ZqmkOaHn (Critério 4):** A subida de ambiente local independente via Docker é formalmente substituída pela conexão direta ao `frila-dev` (configurado via `Configurations/Dev.xcconfig` e segredos gerenciados), permitindo que qualquer desenvolvedor clone o repositório e execute o projeto imediatamente sem passos manuais de provisionamento de containers.

O bundle ID definitivo é `com.frila.org.app`. O mesmo identificador deve ser usado no Apple Developer, App Store Connect e nos apps iOS dos projetos Firebase Dev e Prod. Os frameworks internos usam identificadores derivados (`com.frila.org.app.dominio`, `.dados`, `.apresentacao`, `.infraestrutura`).

