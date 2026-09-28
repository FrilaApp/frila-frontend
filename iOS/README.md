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

1. No `frila-backend`, `supabase start`. O `config.toml` usa `supabase/templates/codigo-de-entrada.html`, que manda só o código: em 25/09 o e-mail local foi conferido sem link de verificação. Com o CLI 2.75, `supabase start` e `supabase db reset` param no seed `cenarios.sql`; o contorno está no `docs/ESTADO.md` do frila-backend. `supabase status` mostra a chave publicável local e a caixa de e-mail local (porta 54324).
2. Rode o esquema `Frila-Local` apontado para o Supabase local, sem gravar nada no repositório:
   `xcodebuild build -project Frila.xcodeproj -scheme Frila-Local -destination 'platform=iOS Simulator,name=<iPhone>' FRILA_API_MODE=supabase FRILA_SUPABASE_PUBLISHABLE_KEY=<chave publicável local>`
   e instale o app com `xcrun simctl install booted <caminho do Frila.app>`. O `local` só aceita `http` em `127.0.0.1`/`localhost`.
3. Na seção **Validação do cliente**, informe um e-mail de teste, toque em **Enviar código**, copie o código de seis dígitos da caixa de e-mail local e toque em **Confirmar código**. A seção passa a mostrar "Sessão ativa neste aparelho.".
4. Com a rede ligada, feche o app (`xcrun simctl terminate booted com.frila.org.app`) e abra de novo. Sem rede e com o token de acesso vencido, a renovação falha e a seção mostra "Nenhuma sessão" mesmo com a sessão guardada. A seção deve continuar mostrando "Sessão ativa neste aparelho.". Isso prova que a sessão sobreviveu ao fechamento.
5. Rode `Scripts/auditar-logs-sensiveis.sh`.

No `frila-dev` hospedado o roteiro ainda não funciona. O Supabase só deixa trocar o modelo de e-mail de projeto gratuito depois de configurado um SMTP próprio (cartão #200). Até lá, o e-mail do frila-dev leva o link padrão, e não o código que o app pede. Sem SMTP, o limite também é de cerca de 2 e-mails por hora. Depois do SMTP, o modelo a aplicar é o `codigo-de-entrada.html` do frila-backend.

**Sessão encerrada por 401 (contrato 0.2.18).** Quando uma chamada volta com prova de que a sessão não vale mais, o `SupabaseApiCliente` encerra a sessão local e a tela recebe o erro original. O 401 prova autenticação inválida, não o motivo: pode ser conta encerrada (a 0.2.18), token vencido ou token recusado.
- **O que conta como prova:** o código original `nao_autenticado` ou `PGRST301` numa RPC, ou o status 401 de uma Edge Function.
- **O que não conta:** o `42501` continua aparecendo como "não autenticado" para a tela, mas sozinho não encerra a sessão, porque com sessão válida ele é falta de privilégio.
- **Guarda contra 401 antigo:** só encerra se a sessão guardada ainda for a mesma com que a chamada saiu. Um 401 atrasado não derruba uma entrada nova.
- **Serialização:** entrada, demonstração, saída e encerramento passam por uma fila FIFO, um de cada vez.
- **Conferência:** depois do `signOut` local, o cliente lê o armazenamento de novo. No supabase-swift 2.55.2 o escopo local também chama `POST /logout`, e a falha dessa chamada não desfaz a remoção local.
- **Aviso:** o `ObservadorDeSessao` repassa o `.signedOut` do SDK, e a seção de validação confere a sessão de novo.

Limites conhecidos, que este código não cobre:
- o `.signedOut` e a leitura sem sessão **não provam** remoção persistente: o SDK engole erro ao apagar do Keychain e devolve "sem sessão" quando a leitura falha;
- a renovação automática do SDK não passa pela fila. No 2.55.2, uma falha de renovação não encerra a sessão, e uma renovação em voo pode regravá-la depois do encerramento;
- um token vencido cuja renovação falhou sai como chamada anônima, e o backend responde `42501`, que não encerra a sessão.

**Auditoria de dados sensíveis.** `Scripts/auditar-logs-sensiveis.sh` examina os últimos cinco minutos do subsistema `com.frila.org.app` e falha sem imprimir o valor caso encontre e-mail, bearer token, chave Supabase ou JWT. O código é conferido a cada `xcodebuild test` pelo `SegurancaDoCodigoTests`: nenhum `print`, `NSLog` ou `debugPrint` em `Sources/`, e nenhum log interpola e-mail, token, sessão, senha, telefone ou chave.

## Fluxo do profissional (baixa fidelidade)

As telas de `Sources/Apresentacao/Fluxos/Profissional/` são **baixa fidelidade descartável**: não são design final e substituem por ora a alta fidelidade do profissional (#15) e os padrões de estado (#172). Os textos ficam todos em `TextosDoProfissional.swift`, marcados como **provisórios** até existir o guia de voz (#186).

- **Entrada.** O esquema Local (dublê) abre direto na lista "Vagas no DF". No Dev e no Prod, a lista abre só se já houver sessão guardada; sem sessão fica a tela de antes, porque a entrada por código é de outro cartão. Quando a sessão é encerrada (401 ou saída), a entrada reavalia.
- **Limite da entrada.** `possuiSessao()` pode precisar da rede para renovar a sessão; offline, com sessão guardada, o app cai na tela de antes até a próxima abertura.
- **Depois de entrar pela validação (Debug).** No Dev sem sessão, quem entra pela seção "Validação do cliente" do catálogo continua no catálogo: o observador de sessão só avisa encerramento. A entrada confere a sessão de novo quando o app volta a ficar ativo (depois de ir para segundo plano) ou na próxima abertura, e aí abre a lista. A entrada por código de verdade é de outro cartão. Sem teste automatizado: a transição Dev + validação + segundo plano não roda no dublê e foi conferida por leitura.
- **Catálogo.** Em Debug, o catálogo de componentes abre pelo botão "Catálogo" da barra, ou direto com `-FRILA_ABRIR_CATALOGO` (usado pelos UI tests do catálogo).
- **Lista (#104).** Pede `vagas_abertas` sem coordenada, e o servidor usa o ponto base do perfil. A ordem é a do servidor. Os filtros são função, data e distância; a data vai como o dia de São Paulo (`DataCivil.deSaoPaulo`), qualquer que seja o fuso do aparelho. A lista pagina de 30 em 30 e aceita puxar para atualizar.
- **Estados da lista.** Carregando, vazia, erro, sem conexão e "sem ponto de referência" (`422 campo_obrigatorio/latitude`). Sem conexão é o `ErroDaApi.semRede`, que hoje só cobre `notConnectedToInternet`.
- **Cartão e detalhe.** Mostram o `local` do contrato como vem, sem extrair bairro. O detalhe nunca tem telefone nem documento; o aviso da RN10 aparece antes de Candidatar-me. Denunciar e Bloquear ficam reservados e desabilitados (Sprint 2).

**Candidatura (#105).** O botão Candidatar-me fica no detalhe, depois do aviso da RN10, e se desabilita enquanto a chamada está em voo.
- **Toque duplo.** Um segundo toque durante o envio não chama `candidatar` de novo; o servidor também é idempotente.
- **Resultado tipado.** O resultado vem do código do erro e dos `details`, nunca do texto:
  - `confirmada` leva ao "Meu turno" (stub do #109, só com os dados da confirmação e o contato da RN10);
  - `409 posicao_ja_preenchida` leva à tela "Vaga preenchida" (é o C2 do #53);
  - `409 vaga_encerrada` leva a uma tela própria, nunca à de vaga preenchida;
  - `422 inelegivel/turno_sobreposto` mostra o turno em conflito, achado em `meus_turnos`, com link;
  - `perfil_suspenso` ou `403 sem_permissao/conta_suspensa` levam à tela de conta suspensa, com Contestar desabilitado (S2 #41);
  - `404` e falha de rede ficam no detalhe, com nova tentativa.
- **Volta à lista.** As telas de resultado voltam para a lista e a atualizam.
- **Sessão.** A candidatura não usa a fila de sessão do cliente: um 409 não encerra a sessão.
- **Rota por vaga_id.** `-FRILA_VAGA_ID <uuid>` abre o detalhe, é a mesma entrada que o push do tipo vaga vai usar (S2 #8) e nunca candidata sozinha. Esse argumento e o `-FRILA_ABRIR_CATALOGO` só existem em Debug; um teste confere que ficam dentro de `#if DEBUG`, e o binário de Release não os contém.
- **Cenários do dublê.** `vaga-preenchida`, `vaga-encerrada`, `inelegivel` (turno sobreposto, com o turno em conflito) e `inelegivel-suspenso`.

## Cenários simulados

**Check-in e check-out no dublê.** O `ApiClienteEmMemoria` segue o `fazer_checkin` vigente do backend (`20260925233000_notificacao_para_qualquer_conta.sql`) e o `fazer_checkout` (`20260925000000_checkin_e_checkout.sql`):
- idempotência antes de qualquer validação;
- check-out sem check-in é `409 checkin_pendente`;
- distância negativa é `422 campo_invalido`;
- os 200 m valem só para o check-in, e o manual não guarda a distância;
- o check-out não tem teto de distância.

O dublê não é equivalente ao backend:
- **Futuro.** O backend tolera até 2 minutos no futuro; o dublê recusa qualquer instante no futuro.
- **Janela do turno.** O backend recusa com `fora_da_janela` o que cair fora de início − 60 min até o fim. O dublê não confere essa janela, então aceita registros que o backend recusaria.
- **Conta de demonstração.** A exceção de janela dela não é modelada.
- **Verificação.** No check-out e nas repetições, tipo e verificação vêm do check-in gravado no dublê. No backend a verificação é a atual do turno, que o `confirmar_checkin_manual` muda; essa operação não existe na porta `ApiCliente` nem no dublê. O `meusTurnos` do dublê também não reflete a verificação.


No esquema local, passe `-FRILA_SCENARIO` seguido de `success`, `primeiro-acesso`, `vaga-preenchida`, `inelegivel`, `sem-rede` ou `conta-suspensa`. Previews e UITests usam a mesma implementação em memória, que parte das fixtures do contrato e responde a todas as operações do Sprint 1.

## Contrato

O app segue o contrato `0.2.18`, espelhado byte a byte em `Contrato/openapi.yaml` a partir de `FrilaApp/frila-docs` (`api/openapi.yaml`), com a soma em `Contrato/openapi.yaml.sha256`, no mesmo esquema do frila-backend. O espelho não se edita à mão: o contrato muda no frila-docs.

- `Sources/Dados/DTOsContrato.swift` tem um tipo por schema usado pelo app; `SupabaseApiCliente` chama as operações do Sprint 1, inclusive `meus_turnos`, e mais check-in, check-out e avaliação.
- `Resources/Fixtures` guarda uma resposta ou requisição por arquivo, e `fixture-schemas.json` diz contra qual schema do contrato cada uma é validada. `ApiClienteEmMemoria` lê essas fixtures pelos mesmos DTOs do cliente real, e os testes conferem que cada requisição que o app monta é igual à fixture.
- `Scripts/validate-fixtures.py` valida tipos, formatos, enums, obrigatórios e campos fora do contrato. Palavra-chave de schema que ele não conhece é erro, não aprovação.
- `Scripts/contrato-em-dia.sh` confere a integridade do espelho e, com `FRILA_DOCS_TOKEN`, se ele ainda é igual ao do frila-docs.

Para trazer uma versão nova: copie `api/openapi.yaml` do frila-docs para `Contrato/`, regrave a soma (`shasum -a 256 Contrato/openapi.yaml | awk '{print $1}' > Contrato/openapi.yaml.sha256`), atualize `contract-version.json`, DTOs e fixtures somente quando os schemas mudarem, e rode a validação e os testes. A atualização para 0.2.11 acrescentou os códigos `checkin_pendente`, `checkin_ja_confirmado` e `posicao_nao_cancelavel`, já tipados no app. Da 0.2.12 à 0.2.17 nenhum schema, payload ou código de erro usado pelo cliente mudou; o que entrou foram regras documentadas. A que toca o app é a da 0.2.16: `configuracao_do_app` responde `404 nao_encontrado` para plataforma sem loja, e a checagem de versão mínima hoje libera o app em qualquer falha (falha aberta), o que a própria 0.2.16 aponta como problema. O comportamento não muda aqui; a decisão é do cartão #201. A 0.2.18 não traz schema, payload nem código de erro novo para o cliente: `nao_autenticado` entra na linha do 401 e já é caso de `CodigoErroAPI`. Ela fixa duas coisas que o app ainda não faz: encerrar a sessão local ao receber `401` (conta encerrada) e chamar `excluir-conta`. As duas ficam para mudanças próprias, fora desta sincronização.

O estado das funções no `frila-dev` está em [Dependências externas](Docs/ExternalSetup.md).

## Decisões e operação

- [Arquitetura](Docs/Architecture.md)
- [Ambientes e segredos](Docs/Environments.md)
- [Integração contínua](Docs/CI.md)
- [Design system e tokens](Docs/DesignSystem.md)
- [Handoff e acessibilidade](Docs/AccessibilityHandoff.md)
- [Relatório de falhas e privacidade](Docs/CrashReporting.md)
- [Cadastros externos pendentes](Docs/ExternalSetup.md)
