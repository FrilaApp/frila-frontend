# Grupo externo e revisão beta pela API

As ações `grupo-externo` e `revisao-beta` do workflow **App Store Connect** usam o script existente. O padrão é `aplicar=false`, versão `0.5.1` e limite `1000`. O grupo externo tem nome fixo **Testadores Frila**; a entrada `grupo` continua exclusiva do grupo interno.

`grupo-externo` procura o build iOS mais recente pela data de upload entre os processados (`VALID`), não expirados e `APP_STORE_ELIGIBLE` da versão solicitada. Confere a versão/plataforma pela relação `preReleaseVersion`, recusa grupo interno homônimo e não remove builds ou testadores. A API não informa o esquema Xcode: antes de aplicar, confirme que o número escolhido corresponde ao envio **Frila-Beta** no workflow TestFlight. Um link criado não comprova aprovação da revisão ou instalação externa.

`revisao-beta` lista cada campo pendente sem registrar valores de contato, credenciais ou notas existentes. Prepara descrições e “o que testar” em pt-BR/en-US e usa `suporte@frilabr.com` para feedback. Preserva descrições, instruções de teste e notas já preenchidas. Com aplicação, sincroniza contato/credenciais exclusivamente pelos segredos, preenche as lacunas e cria uma submissão apenas se ainda não existe. Revisão rejeitada exige resolução pelo responsável; a ação não duplica submissões existentes. Sem os segredos ou build elegível, a aplicação para antes de escrever.

## Segredos para Nick Fury

Na consulta somente aos **nomes** dos segredos do repositório em 22/10/2026, faltavam todos os seguintes:

- `BETA_CONTATO_NOME`: nome completo, separado em `contactFirstName` e `contactLastName` apenas na aplicação.
- `BETA_CONTATO_TELEFONE`: `contactPhone`.
- `BETA_CONTATO_EMAIL`: `contactEmail`.
- `BETA_DEMO_USUARIO`: `demoAccountName`, correspondente a uma das contas de revisão reconhecidas pelo app.
- `BETA_DEMO_SENHA`: `demoAccountPassword`; para este app, o código fixo de seis dígitos de demonstração.

Cadastre diretamente em Settings > Secrets and variables > Actions. Não forneça valores em issue, PR, workflow input ou conversa. O script só relata presença/ausência no plano. Estes segredos são enviados ao processo pelo mecanismo de segredos do GitHub e nunca são incluídos no corpo do relatório. Os três segredos ASC existentes continuam necessários.

## Como o revisor entra no Frila-Beta

O fluxo existe no cliente e não depende de `DEBUG`:

1. A tela de entrada reconhece as duas contas institucionais de revisão definidas em `DemonstracaoContas` (`DestinoAposEntrada.swift:92`). `EntradaViewModel.swift:35` avança sem solicitar e-mail.
2. Na tela seguinte, o revisor informa o código fixo de seis dígitos fornecido no campo de senha da revisão. `CodigoViewModel.swift:99` chama `entrarDemonstracao`.
3. `SupabaseApiCliente.swift:85` invoca a Edge Function `entrar-demonstracao` e instala a sessão retornada pelo servidor.
4. `Configurations/Beta.xcconfig` configura `FRILA_ENVIRONMENT=frila-dev`, modo Supabase e as variáveis DEV. Portanto, contas, função e dados precisam estar funcionais nesse ambiente.

**Limite da evidência:** a leitura prova o caminho do cliente. `FichaAppStore.md`, seção 5.2, ainda registra contas/códigos como pendentes; `ChecklistDiretrizesAppStore.md`, diretriz 2.1, também não comprova provisionamento. Não foi chamado login nem consultado valor de credencial. Falta Nick Fury confirmar as duas contas com perfis/dados de teste no `frila-dev` e acesso por código fixo, com teste independente. A API da Apple não prova essa condição. A segunda conta e suas instruções também precisam estar acessíveis ao revisor por canal privado, se o ciclo completo exigir os dois perfis.

## Contrato oficial conferido

Campos e endpoints foram conferidos na [especificação OpenAPI oficial da Apple](https://developer.apple.com/sample-code/app-store-connect/app-store-connect-openapi-specification.zip), disponibilizada em 06/10/2026:

- [BetaGroupCreateRequest](https://developer.apple.com/documentation/appstoreconnectapi/betagroupcreaterequest): `isInternalGroup=false`, `publicLinkEnabled`, `publicLinkLimitEnabled`, `publicLinkLimit`, `feedbackEnabled`; `publicLink` é lido da resposta. O update aceita a configuração do link/feedback, sem transformar grupo interno em externo.
- [BetaAppReviewDetailUpdateRequest](https://developer.apple.com/documentation/appstoreconnectapi/betaappreviewdetailupdaterequest): campos de contato, `demoAccountName`, `demoAccountPassword`, `demoAccountRequired`, `notes`.
- [BetaAppLocalizationCreateRequest](https://developer.apple.com/documentation/appstoreconnectapi/betaapplocalizationcreaterequest): `locale`, `description`, `feedbackEmail`; relação `app`.
- [BetaBuildLocalizationCreateRequest](https://developer.apple.com/documentation/appstoreconnectapi/betabuildlocalizationcreaterequest): `locale`, `whatsNew`; relação `build`.
- [BetaAppReviewSubmissionCreateRequest](https://developer.apple.com/documentation/appstoreconnectapi/betaappreviewsubmissioncreaterequest): relação `build`; executada só com aplicação explícita.

## Prova local

Execute `ruby iOS/Scripts/teste-app-store-connect.rb`. O transporte de rede é bloqueado durante os testes; os cenários verificam planos sem escrita, seleção do build, idempotência, recusa de grupo interno homônimo, pré-requisitos e ausência de dados pessoais na saída. Aplicações dos testes usam somente o transporte fictício em memória.
