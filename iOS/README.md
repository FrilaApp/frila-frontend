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
| `Frila-Beta` | `Release-Beta` | Supabase `frila-dev`, compilado como Release | o mesmo do Dev; é o archive dos builds 0.4 e 0.5 do TestFlight |
| `Frila-Prod` | `Release-Prod` | Supabase `frila-prod` | URL e chave publicável de Prod, plist Firebase Prod |

`Local.xcconfig`, `Dev.xcconfig` e `Prod.xcconfig` escolhem o ambiente sem alteração de código. As chaves `FRILA_*` chegam ao app pelo `Sources/App/Info.plist` parcial, que o Xcode mescla ao Info.plist gerado.

### Configuração ausente é erro, nunca simulado

`ConfiguracaoAmbiente` decide o cliente a partir do Info.plist e lança `ErroDeConfiguracao` em vez de cair no dublê em memória:

- `local` só aceita `mock` ou um Supabase local por `http://127.0.0.1`.
- `frila-dev` e `frila-prod` só aceitam `supabase`, com URL `https` sem caminho e chave publicável. URL ou chave ausente, valor de exemplo, `sb_secret_` ou `service_role` são recusados.
- Com erro, o app abre na tela "Configuração incompleta", que cita o ambiente e o campo, nunca a URL nem a chave.
- No build, a fase `Validate Supabase configuration` faz a mesma checagem: na CI (`CI=true`) é erro; localmente é aviso. Chave secreta é erro sempre.
- Na abertura, o app registra para onde aponta, no subsistema `com.frila.org.app`, categoria `ambiente`: `inicio ambiente=frila-dev api=supabase url=https://… versao=0.1.0`, ou `inicio configuracao_invalida …`. A URL aparece; a chave nunca. Para conferir no simulador: `xcrun simctl spawn booted log show --last 1m --predicate 'subsystem == "com.frila.org.app" AND category == "ambiente"'`.

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
Scripts/contrato-em-dia.sh
xcodebuild test  -project Frila.xcodeproj -scheme Frila-Local -destination 'platform=iOS Simulator,name=<iPhone disponível>'
xcodebuild build -project Frila.xcodeproj -scheme Frila-Dev  -destination 'generic/platform=iOS Simulator'
xcodebuild build -project Frila.xcodeproj -scheme Frila-Prod -destination 'generic/platform=iOS Simulator'
```

A CI roda a mesma sequência; ver [Integração contínua](Docs/CI.md).

### Validação manual do cliente da API (#53)

Em builds Debug, o catálogo traz a seção **Validação do cliente**. A entrada é só por código de seis dígitos, como o contrato define em `/otp`: o modelo de e-mail do Supabase leva `{{ .Token }}`, sem link. O app não registra esquema de URL nem trata retorno de autenticação.

- **Sessão.** Ao abrir, a seção diz "Sessão ativa neste aparelho." ou "Nenhuma sessão neste aparelho.", sem mostrar e-mail nem token. A sessão fica no Keychain, que é o armazenamento padrão do supabase-swift no iOS, e é renovada pelo SDK.
- **Conflito.** O botão **Simular vaga preenchida** só aparece quando a API é o dublê em memória (`ApiClienteEmMemoria`), porque ele chama `candidatar`. Contra um Supabase de verdade ele não aparece e não cria dado. Para conferir: `Frila-Local` com `-FRILA_SCENARIO vaga-preenchida`; a mensagem esperada é "Esta vaga acabou de ser preenchida. Escolha outra oportunidade.".

Roteiro do critério 1 com o Supabase local, sem o limite de e-mails do projeto hospedado:

1. No `frila-backend`, `supabase start`. O `config.toml` usa `supabase/templates/codigo-de-entrada.html`, que manda só o código. `supabase status` mostra a chave publicável local e a URL do Inbucket (porta 54324).
2. Rode o esquema `Frila-Local` apontado para o Supabase local, sem gravar nada no repositório:
   `xcodebuild build -project Frila.xcodeproj -scheme Frila-Local -destination 'platform=iOS Simulator,name=<iPhone>' FRILA_API_MODE=supabase FRILA_SUPABASE_PUBLISHABLE_KEY=<chave publicável local>`
   e instale o app com `xcrun simctl install booted <caminho do Frila.app>`. O `local` só aceita `http` em `127.0.0.1`/`localhost`.
3. Na seção **Validação do cliente**, informe um e-mail de teste, toque em **Enviar código**, copie o código de seis dígitos do Inbucket e toque em **Confirmar código**. A seção passa a mostrar "Sessão ativa neste aparelho.".
4. Feche o app (`xcrun simctl terminate booted com.frila.org.app`) e abra de novo. A seção deve continuar mostrando "Sessão ativa neste aparelho.". Isso prova que a sessão sobreviveu ao fechamento.
5. Rode `Scripts/auditar-logs-sensiveis.sh`.

O mesmo roteiro vale para o `frila-dev` com o esquema `Frila-Dev`, desde que o modelo de e-mail do projeto hospedado mande `{{ .Token }}`. Sem SMTP próprio, o Supabase hospedado envia só cerca de 2 e-mails por hora.

**Auditoria de dados sensíveis.** `Scripts/auditar-logs-sensiveis.sh` examina os últimos cinco minutos do subsistema `com.frila.org.app` e falha sem imprimir o valor caso encontre e-mail, bearer token, chave Supabase ou JWT. O código é conferido a cada `xcodebuild test` pelo `SegurancaDoCodigoTests`: nenhum `print`, `NSLog` ou `debugPrint` em `Sources/`, e nenhum log interpola e-mail, token, sessão, senha, telefone ou chave.

## Cenários simulados

No esquema local, passe `-FRILA_SCENARIO` seguido de `success`, `primeiro-acesso`, `vaga-preenchida`, `inelegivel`, `sem-rede` ou `conta-suspensa`. Previews e UITests usam a mesma implementação em memória, que parte das fixtures do contrato e responde a todas as operações do Sprint 1.

## Contrato

O app segue o contrato `0.2.17`, espelhado byte a byte em `Contrato/openapi.yaml` a partir de `FrilaApp/frila-docs` (`api/openapi.yaml`), com a soma em `Contrato/openapi.yaml.sha256`, no mesmo esquema do frila-backend. O espelho não se edita à mão: o contrato muda no frila-docs.

- `Sources/Dados/DTOsContrato.swift` tem um tipo por schema usado pelo app; `SupabaseApiCliente` chama as operações do Sprint 1, inclusive `meus_turnos`, e mais check-in, check-out e avaliação.
- `Resources/Fixtures` guarda uma resposta ou requisição por arquivo, e `fixture-schemas.json` diz contra qual schema do contrato cada uma é validada. `ApiClienteEmMemoria` lê essas fixtures pelos mesmos DTOs do cliente real, e os testes conferem que cada requisição que o app monta é igual à fixture.
- `Scripts/validate-fixtures.py` valida tipos, formatos, enums, obrigatórios e campos fora do contrato. Palavra-chave de schema que ele não conhece é erro, não aprovação.
- `Scripts/contrato-em-dia.sh` confere a integridade do espelho e, com `FRILA_DOCS_TOKEN`, se ele ainda é igual ao do frila-docs.

Para trazer uma versão nova: copie `api/openapi.yaml` do frila-docs para `Contrato/`, regrave a soma (`shasum -a 256 Contrato/openapi.yaml | awk '{print $1}' > Contrato/openapi.yaml.sha256`), atualize `contract-version.json`, DTOs e fixtures somente quando os schemas mudarem, e rode a validação e os testes. A atualização para 0.2.11 acrescentou os códigos `checkin_pendente`, `checkin_ja_confirmado` e `posicao_nao_cancelavel`, já tipados no app. Da 0.2.12 à 0.2.17 nenhum schema, payload ou código de erro usado pelo cliente mudou; o que entrou foram regras documentadas. A que toca o app é a da 0.2.16: `configuracao_do_app` responde `404 nao_encontrado` para plataforma sem loja, e a checagem de versão mínima hoje libera o app em qualquer falha (falha aberta), o que a própria 0.2.16 aponta como problema. O comportamento não muda aqui; a decisão é do cartão #201.

O estado das funções no `frila-dev` está em [Dependências externas](Docs/ExternalSetup.md).

## Decisões e operação

- [Arquitetura](Docs/Architecture.md)
- [Ambientes e segredos](Docs/Environments.md)
- [Integração contínua](Docs/CI.md)
- [Design system e tokens](Docs/DesignSystem.md)
- [Handoff e acessibilidade](Docs/AccessibilityHandoff.md)
- [Relatório de falhas e privacidade](Docs/CrashReporting.md)
- [Cadastros externos pendentes](Docs/ExternalSetup.md)
