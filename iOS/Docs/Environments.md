# Ambientes e segredos

| Valor | local | frila-dev | frila-prod | Local de armazenamento |
|---|---|---|---|---|
| URL Supabase | `127.0.0.1:54321` | projeto dev | projeto prod | `.xcconfig` |
| Chave publicável | local/dev | dev | prod | `Secrets.xcconfig` ou segredo da CI |
| Sessão do usuário | Keychain | Keychain | Keychain | aparelho |
| `GoogleService-Info.plist` | opcional | dev | prod | fora do Git, injetado pela CI |
| APNs `.p8` | não usado | Firebase dev | Firebase prod | console seguro, nunca no app |
| FCM service account | Supabase local | Supabase dev | Supabase prod | segredo de Edge Function |
| `service_role`, SMTP e agendador | Supabase local | Supabase dev | Supabase prod | segredo/Vault do Supabase |

Rotação: gere o novo valor no provedor, atualize o ambiente de destino, valide, revogue o antigo e registre data/responsável. Nunca imprima chaves, token, e-mail, telefone ou coordenada em log.

O bundle ID definitivo é `com.frila.org.app`. O mesmo identificador deve ser usado no Apple Developer, App Store Connect e nos apps iOS dos projetos Firebase Dev e Prod.
