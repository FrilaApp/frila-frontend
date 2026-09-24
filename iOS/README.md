# Frila iOS

Fundação nativa em Swift 6.3, SwiftUI e SwiftData, com alvo mínimo iOS 17 e build pelo SDK do iOS 26.

## Abrir e rodar

1. Instale o XcodeGen (`brew install xcodegen`).
2. Copie `Configurations/Secrets.example.xcconfig` para `Configurations/Secrets.xcconfig` e preencha somente as URLs e chaves publicáveis dos ambientes disponíveis.
3. Rode `xcodegen generate` nesta pasta.
4. Abra `Frila.xcodeproj` e use `Frila-Local` no simulador. Esse esquema usa `ApiClienteEmMemoria` e não precisa de backend.
5. Use `Frila-Dev` para `frila-dev` e `Frila-Prod` somente para archive de produção.

`Local.xcconfig`, `Dev.xcconfig` e `Prod.xcconfig` escolhem o ambiente sem alteração de código. URLs reais podem ser sobrescritas no arquivo ignorado `Secrets.xcconfig`.

## Segredos e arquivos externos

- Permitido no app: URL do projeto e chave publicável do Supabase.
- Proibido no app e no Git: `service_role`, SMTP, conta de serviço FCM, segredo do agendador e chave APNs `.p8`.
- `GoogleService-Info.plist` fica em `Resources/Firebase/<ambiente>/`, é ignorado e deve ser injetado pela CI com `Scripts/inject-firebase-config.sh`. A fase de build inclui somente o arquivo do ambiente ativo.
- A sessão do Supabase usa o `KeychainLocalStorage` padrão do SDK e renovação automática. Nunca é gravada em `UserDefaults`.

## Cenários simulados

No esquema local, passe `-FRILA_SCENARIO` seguido de `success`, `vaga-preenchida`, `inelegivel`, `sem-rede` ou `conta-suspensa`. Previews e UITests usam a mesma implementação em memória.

## Contrato

O contrato externo disponível em `Frila/Documentos/API/openapi.yaml` ainda é `0.2.0`. Os DTOs e fixtures desta fundação registram essa versão em `Resources/Fixtures/contract-version.json`; as adições previstas no cartão `0.2.1` ficam isoladas em `ConfiguracaoApp` e nas portas, sem alterar o repositório de backend.

## Decisões e operação

- [Arquitetura](Docs/Architecture.md)
- [Ambientes e segredos](Docs/Environments.md)
- [Design system e tokens](Docs/DesignSystem.md)
- [Handoff e acessibilidade](Docs/AccessibilityHandoff.md)
- [Relatório de falhas e privacidade](Docs/CrashReporting.md)
- [Cadastros externos pendentes](Docs/ExternalSetup.md)
