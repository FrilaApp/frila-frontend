# Frila iOS

Fundação nativa em Swift 6.3, SwiftUI e SwiftData, com alvo mínimo iOS 17 e build pelo SDK do iOS 26.

## Abrir e rodar

1. Instale o XcodeGen 2.45.3 (`brew install xcodegen`; a CI usa essa versão fixada).
2. Rode `xcodegen generate` nesta pasta. O projeto gerado é versionado e a CI falha se ele divergir do `project.yml`.
3. Abra `Frila.xcodeproj` e use `Frila-Local` no simulador. Esse esquema usa `ApiClienteEmMemoria` de forma explícita e não precisa de backend, Supabase nem Firebase.
4. Para `Frila-Dev` e `Frila-Prod`, gere `Configurations/Secrets.xcconfig` (seção abaixo) e injete os plists do Firebase.

| Esquema | Configuração | API | Exige |
|---|---|---|---|
| `Frila-Local` | `Debug-Local` | `ApiClienteEmMemoria` | nada |
| `Frila-Dev` | `Debug-Dev` | Supabase `frila-dev` | URL e chave publicável de Dev, plist Firebase Dev |
| `Frila-Prod` | `Release-Prod` | Supabase `frila-prod` | URL e chave publicável de Prod, plist Firebase Prod |

`Local.xcconfig`, `Dev.xcconfig` e `Prod.xcconfig` escolhem o ambiente sem alteração de código. As chaves `FRILA_*` chegam ao app pelo `Sources/App/Info.plist` parcial, que o Xcode mescla ao Info.plist gerado.

### Configuração ausente é erro, nunca simulado

`ConfiguracaoAmbiente` decide o cliente a partir do Info.plist e lança `ErroDeConfiguracao` em vez de cair no dublê em memória:

- `local` só aceita `mock` ou um Supabase local por `http://127.0.0.1`.
- `frila-dev` e `frila-prod` só aceitam `supabase`, com URL `https` sem caminho e chave publicável. URL ou chave ausente, valor de exemplo, `sb_secret_` ou `service_role` são recusados.
- Com erro, o app abre na tela "Configuração incompleta", que cita o ambiente e o campo, nunca a URL nem a chave.
- No build, a fase `Validate Supabase configuration` faz a mesma checagem: na CI (`CI=true`) é erro; localmente é aviso. Chave secreta é erro sempre.

### Supabase: gerar `Secrets.xcconfig`

```sh
export FRILA_SUPABASE_DEV_URL=...                  # https://<ref>.supabase.co
read -rs FRILA_SUPABASE_DEV_PUBLISHABLE_KEY && export FRILA_SUPABASE_DEV_PUBLISHABLE_KEY
Scripts/generate-supabase-secrets.sh dev           # ou prod; sem argumento exige os quatro valores
```

O script valida os valores sem imprimi-los, recusa valor de exemplo, URL fora do formato e chave secreta, grava por arquivo temporário e deixa o destino com permissão 600. O destino é ignorado pelo Git; o script se recusa a gravar se não for. `Secrets.example.xcconfig` mostra só o formato.

### Firebase

```sh
export FRILA_FIREBASE_GOOGLE_SERVICE_INFO_DEV_B64=...   # base64 do plist
Scripts/inject-firebase-config.sh dev                   # ou prod, ou all
```

O script confere o plist e o bundle ID `com.frila.org.app` e grava em `Resources/Firebase/<Dev|Prod>/`, ignorado pelo Git. A fase `Select Firebase configuration` copia para o bundle só o plist do ambiente ativo. O SDK de push (FCM) entra no Sprint 2.

## Segredos e arquivos externos

- Permitido no app: URL do projeto e chave publicável do Supabase.
- Proibido no app e no Git: `service_role`, `sb_secret_`, SMTP, conta de serviço FCM, segredo do agendador e chave APNs `.p8`.
- Nunca versionados (ver `.gitignore`): `Configurations/Secrets.xcconfig`, `Resources/Firebase/**/GoogleService-Info.plist`, `Secrets/`, `*.p8`, `DerivedData/`, `build/`, `.build/`, `xcuserdata/` e `.DS_Store`.
- As fases de script do app não exportam as variáveis de build para o log (`showEnvVars: false`), para a chave não aparecer em log local nem da CI.
- A sessão do Supabase usa o `KeychainLocalStorage` padrão do SDK e renovação automática. Nunca é gravada em `UserDefaults`.

## Testes e validação

```sh
python3 Scripts/validate-fixtures.py
xcodegen generate
xcodebuild test  -project Frila.xcodeproj -scheme Frila-Local -destination 'platform=iOS Simulator,name=<iPhone disponível>'
xcodebuild build -project Frila.xcodeproj -scheme Frila-Dev  -destination 'generic/platform=iOS Simulator'
xcodebuild build -project Frila.xcodeproj -scheme Frila-Prod -destination 'generic/platform=iOS Simulator'
```

A CI roda a mesma sequência; ver [Integração contínua](Docs/CI.md).

## Cenários simulados

No esquema local, passe `-FRILA_SCENARIO` seguido de `success`, `vaga-preenchida`, `inelegivel`, `sem-rede` ou `conta-suspensa`. Previews e UITests usam a mesma implementação em memória.

## Contrato

Os DTOs e fixtures desta fundação seguem o snapshot `0.2.0`, registrado em `Resources/Fixtures/contract-version.json`. `meusTurnos()` continua bloqueado no cliente real até o iOS ser sincronizado com o contrato publicado; o app não presume o schema. O estado do contrato está em [Dependências externas](Docs/ExternalSetup.md).

## Decisões e operação

- [Arquitetura](Docs/Architecture.md)
- [Ambientes e segredos](Docs/Environments.md)
- [Integração contínua](Docs/CI.md)
- [Design system e tokens](Docs/DesignSystem.md)
- [Handoff e acessibilidade](Docs/AccessibilityHandoff.md)
- [Relatório de falhas e privacidade](Docs/CrashReporting.md)
- [Cadastros externos pendentes](Docs/ExternalSetup.md)
