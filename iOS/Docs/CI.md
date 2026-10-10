# Integração contínua

O workflow `.github/workflows/ios.yml` roda em pull requests e pushes que mexem em `iOS/**` ou no próprio workflow, em dois jobs paralelos num runner `macos-26` cada, com permissão só de leitura e limite de 90 minutos por job. Um push novo cancela a execução anterior do mesmo PR ou branch.

## Duas partes

Desde 06/10/2026 (PR #147), a suíte do `Frila-Local` é dividida por uma lista só, `Tests/parte-1-da-ci.txt`:

- **Parte 1** (`parte-1`): os portões que não compilam (etapas 3 a 5 abaixo e a conferência das partes), depois os testes unitários (`FrilaTests` inteiro) e as classes de interface da lista, com `-only-testing`.
- **Parte 2** (`parte-2`): todo o resto da suíte, com `-skip-testing` da mesma lista, e os builds de Release (etapas 11 a 13), que continuam pulados em PR que só mexe em testes ou documentação. Os builds de Release vêm antes dos testes de interface: um Release quebrado reprova em minutos.

Classe ou alvo de teste novo fica fora da lista e cai sozinho na parte 2. Antes de compilar, a parte 1 roda `Scripts/partes-dos-testes.sh conferir`, com o autoteste `Scripts/teste-partes-dos-testes.sh`. A conferência reprova item da lista que não existe no código ou que aparece repetido, e imprime as classes de cada parte.

A divisão saiu dos tempos por classe da execução 37244334865 (push no `main`, 05/10). As 38 classes de interface somaram 71,0 minutos. A parte 1 ficou com 11 classes (39,2 min) e os unitários; a parte 2, com 27 classes (31,7 min) e os builds de Release. Esses builds levaram de 9m45s a 10m28s nas execuções 37241695780 e 37251084274.

Na primeira execução do desenho, a 37504092755 (06/10):
- a parte 1 levou 55m56s e a parte 2, 59m19s, 115m15s somados;
- a interface rodou 11% mais devagar que na 37244334865 na parte 1 e 22% na parte 2, cada job numa máquina;
- cada parte gastou cerca de 4 minutos entre o início do passo de testes e o primeiro teste, com o boot do simulador e a instalação.

Depois dela, `CancelamentoDoProfissionalUITests` (3,0 min) passou para a parte 1. A troca compensa as classes novas do #154 e do #155 (`PorQueReceboVagasUITests` e `EquipeDeConfiancaUITests`), que caíram sozinhas na parte 2.

Cada parte compila o seu `build-for-testing`. A alternativa medida foi compilar uma vez e repassar os produtos às partes como artefato:
- os produtos têm 218 MB, ou 56 MB zipados (medido localmente);
- o upload na CI fez 360 MB em 19 s (xcresult da 37241695780);
- a compilação levou de 2m34s a 3m51s (37244334865, 37241695780 e 37251084274).

Inferência: o artefato pouparia no máximo uma compilação por execução, menos o preparo de um terceiro job, e as partes esperariam por ele. A diferença é pequena, então ficou a opção mais simples.

**Rebalancear** quando a parte 2 passar de 65 minutos medidos numa execução completa, ou quando a parte 1 passar disso. Mova classes para a lista ou tire dela pelos tempos da execução mais recente: no log, o xcbeautify imprime `Executed N tests, ... in S seconds` ao fim de cada classe. Antes do push, confira com as enumerações do próprio xcodebuild, depois de um `build-for-testing` do `Frila-Local`:

```sh
cd iOS
for p in suite 1 2; do
  ARGS=(); [[ $p == suite ]] || while IFS= read -r a; do ARGS+=("$a"); done <<< "$(Scripts/partes-dos-testes.sh argumentos $p)"
  xcodebuild test-without-building -project Frila.xcodeproj -scheme Frila-Local -destination "id=<UDID>" \
    -enumerate-tests -test-enumeration-style flat -test-enumeration-format json \
    -test-enumeration-output-path "/tmp/partes-$p.json" "${ARGS[@]}"
done
Scripts/partes-dos-testes.sh conferir-enumeracoes /tmp/partes-suite.json /tmp/partes-1.json /tmp/partes-2.json
```

Em 06/10 essa conferência deu 1.101 testes na parte 1 e 155 na parte 2, que somam os 1.256 da suíte. Cada enumeração levou de 37 a 64 s localmente, por isso ela não roda em toda execução da CI.

## Etapas

Etapas, na ordem:

1. Seleciona o Xcode 26.6 fixado do runner.
2. Instala o XcodeGen 2.45.3 do release oficial e confere o SHA-256.
3. `Scripts/contrato-em-dia.sh`: o espelho `Contrato/openapi.yaml` bate com a soma gravada; com o secret `FRILA_DOCS_TOKEN`, também com o frila-docs.
4. `python3 Scripts/validate-fixtures.py`: cada fixture contra o schema do contrato, com tipos, formatos, enums e campos fora do contrato.
5. Falha se algum arquivo fora de `Sources/Dados` importar o Supabase.
6. `Scripts/gerar-projeto.sh` para gerar o `Frila.xcodeproj` via XcodeGen e restaurar o `Package.resolved` versionado.
7. Injeta os plists do Firebase Dev e Prod.
8. Escolhe o simulador de iPhone disponível com o iOS mais novo, sem aparelho fixo.
9. Restaura `DerivedData/SourcePackages` pelo hash do `Package.resolved` e pela versão do Xcode. Sem cache, resolve os pacotes explicitamente com `-onlyUsePackageVersionsFromResolvedFile`; com cache, a resolução automática fica desabilitada. Produtos de build nunca entram no cache.
10. `xcodebuild build-for-testing` e depois `test-without-building` do `Frila-Local`: testes unitários, de contrato e de interface, sem backend. Cada parte compila e roda a sua fatia: a parte 1, a lista; a parte 2, o resto (veja [Duas partes](#duas-partes)).
11. Gera o `Secrets.xcconfig` de Dev e compila o `Frila-Dev` (pulado se o PR só mexe em testes ou documentação).
12. Compila o `Frila-Beta` (Release apontando para o frila-dev) e confere o bundle (pulado se o PR só mexe em testes ou documentação).
13. Gera o `Secrets.xcconfig` de Prod e compila o `Frila-Prod` e confere o bundle (pulado se o PR só mexe em testes ou documentação).
14. Apaga `Secrets.xcconfig`, plists, produtos de build e temporários, mesmo quando uma etapa falha. O diretório `SourcePackages` fica só até o pós-job de cache salvar os pacotes.

Nenhuma etapa do `ios.yml` assina código (o simulador usa a assinatura local ad-hoc) nem publica artefato. As fases de script do Xcode não exportam variáveis para o log, e o GitHub mascara os segredos.

Desde 24/09 a etapa 12 compila com o `frila-prod` ([Dependências externas](ExternalSetup.md), item 9). Se um dos dois secrets de Prod faltar, ela para em `FRILA_SUPABASE_PROD_URL is not set`, de propósito: Prod sem Supabase não compila em silêncio.

Custo: o repositório é privado e cada minuto macOS consome cerca de dez vezes a cota de um minuto Linux. O orçamento de Actions da organização está em US$ 0 com bloqueio de uso adicional, então esgotar a cota interrompe a CI sem gerar cobrança.

Tempo da CI de PR: no PR #66, em 02/10/2026, a execução levou 39m45s. Os testes do `Frila-Local` tomaram 25m45s, a compilação deles 2m35s, e os builds do Dev, do Beta e do Prod, 1m59s, 4m20s e 3m44s. Nada roda duas vezes: o workflow só dispara em pull request e em push no `main`, e um push novo cancela a execução anterior do mesmo PR. O limite subiu de 45 para 70 minutos quando os testes de interface do push (#8) entraram, e para 90 minutos em 04/10/2026 após o crescimento da suíte de testes de interface (ciclo ponta a ponta e fluxos de cancelamento com motivo), evitando cancelamentos perto do fim que desperdiçam 70 minutos e voltam inteiros à fila. PRs que alteram apenas testes (`iOS/Tests/**`) ou documentação (`**/*.md`, `iOS/Docs/**`) pulam os builds de Release (`Frila-Dev`, `Frila-Beta` e `Frila-Prod`) e suas conferências, economizando cerca de 7m30s a 8m30s por execução. Separar os três builds num job paralelo encurtaria a espera, mas gastaria mais cota, porque a preparação e a compilação dos pacotes se repetiriam; não foi feito.

Em outubro de 2026 o job único chegou perto do limite: na 37244334865 (push no `main`, 05/10) ele terminou em 85m45s, 75 deles no passo de testes. A primeira tentativa do PR #147 separou a interface num job e deixou os unitários e os builds de Release em outro. O job de interface levou 81m09s na 37241695780 e foi cortado nos 90 minutos na 37251084274. Nessa execução, as 16 primeiras classes levaram 46,5 minutos, contra 38,8 na 37241695780. Daí as duas partes de hoje, com os builds de Release na parte 2 em vez de num terceiro job.

Paralelismo de testes no simulador: medido e descartado em 03/10/2026 no PR #102. Tentar rodar os testes em paralelo no xcodebuild (`-parallel-testing-enabled YES -maximum-parallel-testing-workers 2`) subiu o tempo do passo de testes de 42-53 minutos para 67m45s (estourando o limite de 70 minutos do workflow) e causou 8 falhas espúrias por lentidão extrema. O runner `macos-26` do GitHub Actions tem apenas 3 vCPUs; subir e manter dois clones de simulador concorrentes sobrecarrega a CPU (só o boot inicial levou 10m20s) e quebra a sincronização de acessibilidade do XCUITest. O simulador único sequencial é 15 a 25 minutos mais rápido e 100% determinístico. Não ligue paralelismo de simulador na CI sem runners com mais núcleos dedicados.

## Mandar um build ao TestFlight

O workflow `.github/workflows/testflight.yml` arquiva, assina, confere e manda o app ao TestFlight
(#203). Todo o trabalho fica em `Scripts/enviar-testflight.sh`, que roda igual na CI e na máquina de
quem precisar reproduzir. Ele não mexe na CI de PR.

### Quando roda

- **Tag `vX.Y.Z` num commit do `main`**: manda o esquema da tag com a versão `X.Y.Z`. Hoje o esquema
  é o `Frila-Beta` (Release apontando para o frila-dev), o que o cartão pede para o 0.4 e o 0.5. Uma
  tag fora do `main` é recusada.
- **Disparo manual** (Actions > TestFlight > Run workflow): escolhe o esquema (`Frila-Beta` ou
  `Frila-Prod`), a versão, o ensaio de falha, o build de medição e se envia. Com "Enviar ao
  TestFlight" desmarcado, o job faz o archive, a assinatura, a conferência e os símbolos e para antes
  do envio.
- **Prod como padrão da tag**: no `testflight.yml`, apague a linha `ESQUEMA_DA_TAG: Frila-Beta` e
  descomente a `# ESQUEMA_DA_TAG: Frila-Prod` logo abaixo. Faça isso quando o frila-prod tiver as
  migrações (cartão do ambiente de produção, 29/10). Até lá, um build Prod abriria contra um banco
  vazio. Os dois esquemas têm o mesmo bundle id e vão para o mesmo app no App Store Connect.

### O que o job faz

1. Confere a tag (no `main`, formato `vX.Y.Z`) ou as entradas do disparo manual, e calcula o número
   do build.
2. Seleciona o Xcode 26.6. `assinatura-local-ci.py` importa a identidade Apple Distribution num
   keychain temporário, mantém os keychains anteriores na busca e prova o acesso à chave privada
   assinando e verificando um binário descartável. Exige uma identidade válida da equipe do projeto.
   O `.p12` é apagado logo após a importação; as credenciais e a senha aleatória do keychain são
   mascaradas. Depois, restaura os pacotes SPM do cache da CI de PR, só para leitura.
3. Gera o `Secrets.xcconfig` e o `GoogleService-Info.plist` do ambiente: dev para o Beta, prod para o
   Prod.
4. Grava a chave `.p8` num arquivo temporário com permissão 600.
5. Roda o `Scripts/enviar-testflight.sh`:
   1. **Archive** com a versão e o número do build, na assinatura automática de desenvolvimento do
      projeto. Com `-allowProvisioningUpdates` e a chave, o xcodebuild cria o perfil e o certificado
      de desenvolvimento que faltarem na máquina da CI. A assinatura ad hoc não serve: o Xcode exige
      perfil para o app iOS (medido em 03/10).
   2. **Export** para o App Store Connect com assinatura automática e a identidade local importada.
      `-allowProvisioningUpdates` e a chave da API permitem ao Xcode obter ou atualizar os perfis
      automáticos. O keychain temporário fica primeiro na busca, sem alterar o keychain padrão usado
      pelo archive Development. A conferência seguinte exige o certificado importado no IPA e nos
      perfis, interrompendo o fluxo se o Xcode escolher outra identidade.
   3. **Conferência** após descompactar o IPA: `diagnosticar-assinatura.py` verifica o archive e o
      export com `codesign --verify --deep --strict`, incluindo cada framework e extensão. Registra
      requisito designado, certificado, validade, equipe e correspondência com o perfil, sem
      publicar binários ou o perfil inteiro. No IPA, exige SHA-256 igual ao certificado importado em
      cada binário; app e extensão precisam de perfil válido da equipe e do bundle, contendo esse
      certificado e `get-task-allow=false`. Assinatura inválida interrompe o fluxo antes dos
      símbolos e do upload. Depois, `conferir-release.sh` confere criptografia, privacidade,
      ganchos de Debug e `aps-environment` de produção; o script exige `get-task-allow` falso.
   4. **Símbolos**: o dSYM do app e o dos quatro frameworks vão ao Crashlytics do ambiente, com duas
      tentativas. Se não subirem, o build não vai ao TestFlight. A Apple também recebe os símbolos
      (`uploadSymbols`).
   5. **Envio**: um segundo export, com `destination: upload` e a mesma assinatura.
6. Restaura a lista anterior de keychains e apaga o keychain temporário com a identidade, mesmo
   quando uma etapa falha. Um passo separado apaga a chave da API, os segredos, o archive, o `.ipa` e
   o DerivedData.
   Nada vira artefato do Actions, porque o `.ipa` traz o plist do Firebase e a chave publicável do
   Supabase.

Regras do build:
- **Versão:** sai da tag (`v0.4.0` vira `0.4.0`). O `MARKETING_VERSION` do `project.yml` não muda.
- **Número do build:** data e hora UTC do início do job, `AAAAMMDD.HHMMSS`, sem zero à esquerda na
  segunda parte (`20261020.93015` é 09:30:15). É único e crescente entre execuções, reexecuções e
  máquinas, sem consultar o App Store Connect. O Xcode não pode trocá-lo no envio
  (`manageAppVersionAndBuildNumber` desligado).
- **Criptografia:** o `Info.plist` declara `ITSAppUsesNonExemptEncryption` como `false`, conferido
  pelo `conferir-release.sh`. Por isso o build não pede a resposta manual sobre criptografia.

### Diagnóstico do 90035 em 08/10/2026 UTC

A [execução 37714291333](https://github.com/FrilaApp/frila-frontend/actions/runs/37714291333),
`Frila-Beta` 0.4.0, provou a incompatibilidade Unicode no requisito designado da assinatura
na nuvem. A comparação de `certificate leaf[subject.CN]` usa bytes diferentes:

| Dado medido no IPA exportado | Resultado |
|---|---|
| Nome no requisito designado | `Cauê` em NFD: `65 cc 82` para `ê` |
| Comparação do CN do certificado em NFC | `c3 aa` para `ê`; `codesign -R` termina com 0 |
| Comparação do mesmo CN em NFD | `codesign -R` termina com 3 |
| Verificação estrita do app, quatro frameworks e extensão | Código válido em disco, requisito designado não satisfeito; status 3 |
| SHA-256 do certificado de distribuição na nuvem | `f65002c2bd0f9ad51df04557b3b6b9b27833803a9dc0326492a1f502c14c135f` |

O archive passa na verificação estrita com Apple Development. O export usa Apple Distribution,
equipe `8B7F7G3Y2U`, `get-task-allow=false` e `aps-environment=production` no app. Os perfis do
app e da extensão contêm o SHA-256 do certificado usado. Certificado e perfis vencem em
03/09/2027; o relógio registrado é 08/10/2026 UTC. A cadeia apresentada contém WWDR e Apple
Root CA. Esses dados separam o defeito no requisito Unicode de troca de equipe, expiração,
perfil incompatível ou export ainda assinado como Development.

A [primeira execução de diagnóstico](https://github.com/FrilaApp/frila-frontend/actions/runs/37713601140)
confirmou o archive, mas tentou ler o IPA antes de descompactá-lo e voltou a receber 90035 no
upload. A segunda corrigiu a ordem e interrompeu o envio após mostrar a assinatura inválida.
Foram duas execuções; **nenhum upload desta missão foi aceito pela Apple**.

Prova local executada: um binário descartável assinado com o certificado local de distribuição
da mesma equipe satisfaz o requisito com o CN em NFC. Reassiná-lo com o requisito em NFD
reproduz `valid on disk` seguido de `does not satisfy its designated Requirement`.
O certificado local tem SHA-256
`38e2bde028a40fd58ba637773890076dc42f7b2d50bde0f4499ff08cec5e9f28`, diferente do certificado
na nuvem. Isso prova a diferença na comparação; não prova um upload com assinatura local.

A [Apple documenta a assinatura na nuvem e a seleção de certificado local](https://developer.apple.com/help/account/certificates/cloud-managed-certificates/)
e o [fluxo com `xcodebuild -exportArchive` e chave da API](https://developer.apple.com/videos/play/wwdc2021/10204/).
**Inferência:** fornecer à CI a identidade local de distribuição que passou na prova permite
contornar a geração defeituosa do requisito pela assinatura na nuvem. A mudança agora prepara essa
identidade na CI, autorizada pelo Cauê em 07/10. O export real com a nova configuração e o upload
aceito ainda não foram executados: o teto de duas execuções foi consumido e exige nova autorização.

#### Perfis e certificado local

A mesma [execução de diagnóstico](https://github.com/FrilaApp/frila-frontend/actions/runs/37714291333)
mostrou, nos perfis exportados **do app e da extensão**, o SHA-256 local
`38e2bde028a40fd58ba637773890076dc42f7b2d50bde0f4499ff08cec5e9f28` além do certificado da nuvem.
Logo, a hipótese da retomada de que os perfis só incluíam o certificado da nuvem foi refutada pelo
log. Para esse certificado local, ambos os perfis já satisfazem o vínculo certificado/perfil.

A [Apple informa que o Xcode gerencia os perfis de distribuição no modo automático](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile/)
e que [o Xcode solicita um novo perfil quando nenhum perfil local atende aos requisitos](https://developer.apple.com/help/account/provisioning-profiles/edit-download-or-delete-profiles/).
Mantemos `signingStyle=automatic`, `teamID` e `-allowProvisioningUpdates` nos dois exports, com a
chave da API existente. Se for necessário um novo perfil, o Xcode pode criá-lo/atualizá-lo para a
identidade disponível. Não usamos `signingCertificate`: o `xcodebuild -help` do Xcode 26.6 define
essa opção para assinatura manual. Se o Xcode não obtiver um perfil compatível, o export falha;
se exportar outra identidade ou perfil incompatível, a conferência bloqueia os símbolos e o upload.

O ciclo do keychain segue o [exemplo oficial do GitHub para assinatura Xcode](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications),
com permissões de arquivo 600, desbloqueio e autorização do codesign sem interação. A busca anterior
é preservada e restaurada, e a limpeza fica registrada antes da importação, inclusive para o passo
`always()` em caso de falha.

Regressão dos scripts, sem conta Apple ou credenciais reais:

```sh
python3 iOS/Scripts/teste-diagnosticar-assinatura.py
python3 iOS/Scripts/teste-assinatura-local-ci.py
```

Os 14 testes do diagnóstico cobrem assinatura válida, requisito designado incompatível, caminho
inexistente, ausência/troca de certificado, perfis incompatíveis e extensão sem perfil. Os 9 testes
do importador simulam `security`/`codesign`: importação, preservação/restauração de keychains,
limpeza, credenciais ausentes/inválidas, equipe errada e falha de requisito designado, sem publicar
saída de subprocessos que recebem segredos. Esses testes não provam a importação real do `.p12`.

Também foi executada uma nova prova local com a chave já instalada no Mac, sem exportá-la:
`codesign --verify --strict` e o requisito Apple Distribution/equipe passaram; o diagnóstico aceitou
seu SHA-256 e bloqueou um SHA-256 diferente. O registro local é
`.workers/homem-aranha/diagnostico-testflight/prova-local-distribuicao-autorizada.log`.
Não foram executados `exportArchive`, upload nem a suíte do app iOS nesta preparação. Os binários
descartáveis foram apagados; não houve DerivedData ou `.xcresult` local.

### O que o Cauê faz uma vez

1. **Chave da App Store Connect API.** Em App Store Connect > Users and Access > Integrations > App
   Store Connect API:
   - Se a API ainda não estiver liberada, clique em Request Access (só o Account Holder pode).
   - Em **Team Keys**, clique em Generate API Key, com o nome `GitHub Actions TestFlight` e o acesso
     **Admin**.
   - Anote o **Key ID** e o **Issuer ID** e baixe o `.p8`. A Apple só deixa baixar uma vez.

   Por que Admin:
   - Na tabela de papéis da Apple, só Account Holder e Admin têm de fábrica "Upload builds" e "Create
     other cloud-managed certificate types". App Manager e Developer dependem de permissões extras,
     dadas a pessoas em Users and Access.
   - A chave de equipe só recebe o papel, não essas permissões extras. Por isso Admin é o mínimo
     documentado para uma chave de equipe.
   - Uma chave individual de alguém com papel Developer e essas permissões também serviria, mas
     prende a CI a uma pessoa.
2. **Segredos do GitHub** (Settings > Secrets and variables > Actions > New repository secret, no
   `FrilaApp/frila-frontend`):

   | Segredo | Conteúdo |
   |---|---|
   | `APP_STORE_CONNECT_API_KEY_ID` | o Key ID |
   | `APP_STORE_CONNECT_API_ISSUER_ID` | o Issuer ID |
   | `APP_STORE_CONNECT_API_KEY_P8` | o conteúdo do `.p8`, inteiro, com as linhas `BEGIN` e `END` |
   | `APPLE_DISTRIBUTION_CERT_P12_BASE64` | `.p12` da identidade local Apple Distribution, com chave privada, codificado em base64 |
   | `APPLE_DISTRIBUTION_CERT_P12_PASSWORD` | senha do `.p12` |

   O Cauê exporta a identidade local com senha e grava os dois segredos de distribuição; o agente
   não lê o `.p12`, a senha nem os valores dos segredos. A CI não altera a chave da API existente.

   O `.p8` pode ir direto do arquivo, sem passar pela tela:
   `gh secret set APP_STORE_CONNECT_API_KEY_P8 --repo FrilaApp/frila-frontend < AuthKey_XXXXXXXXXX.p8`.
   Depois, guarde o `.p8` no cofre do time ou apague-o; ele nunca entra no Git.

   O job também usa seis segredos que já existem para a CI de PR:
   - `FRILA_SUPABASE_DEV_URL` e `FRILA_SUPABASE_DEV_PUBLISHABLE_KEY`;
   - `FRILA_SUPABASE_PROD_URL` e `FRILA_SUPABASE_PROD_PUBLISHABLE_KEY`;
   - `FRILA_FIREBASE_GOOGLE_SERVICE_INFO_DEV_B64` e `FRILA_FIREBASE_GOOGLE_SERVICE_INFO_PROD_B64`.
3. **TestFlight.** Com os segredos configurados, use o workflow **App Store Connect** descrito abaixo
   para preparar o grupo interno com os cinco, com acesso a todos os builds. As notas "O que testar"
   de cada build continuam sendo escritas no App Store Connect.

### Operar a App Store Connect pela API

O `.github/workflows/app-store-connect.yml` só roda por `workflow_dispatch`, com os mesmos três
segredos da chave de equipe Admin usados pelo TestFlight. `Scripts/app-store-connect.rb` assina
um JWT ES256 em memória; nem a chave `.p8` nem o token viram arquivo ou artefato. Se faltar algum
segredo, a primeira etapa depois do checkout falha indicando os nomes, antes de acessar a API.
Esse workflow não compila nem envia o app.

Em **Actions > App Store Connect > Run workflow**, no `main`:

1. Rode primeiro `acao=conferir`, com `aplicar` desmarcado. O log mostra o app `com.frila.org.app`,
   grupos, contagem de testadores por grupo, cada `appInfo` e suas respostas de classificação.
   `conferir` sempre faz somente GET, mesmo se `aplicar` estiver marcado.
2. Para o grupo, escolha `acao=grupo-interno`, informe o nome exato (padrão `Equipe Frila`) e os
   cinco e-mails no campo `testadores`, separados por vírgula. Rode primeiro sem `aplicar` para ver
   o plano e depois com `aplicar` para executá-lo. Um grupo interno com esse nome é reutilizado;
   deve já ter `hasAccessToAllBuilds=true`. A API aceita esse atributo na criação, mas não no
   `BetaGroupUpdateRequest`; se estiver desabilitado num grupo existente, o job para sem alterações.
   Um nome externo ou duplicado também interrompe a operação.
   Ninguém é removido. O script só inclui usuários que já constam na equipe, com papel elegível e
   acesso ao app; ele não cria convites de equipe nem altera papéis ou permissões.
3. Para a classificação, escolha `acao=classificacao` e confira `verificacao_idade`: marcado
   quando a versão incluir Declared Age Range do PR 95, desmarcado caso contrário. O plano segue
   o questionário do cartão #215: conteúdo gerado pelo usuário Sim, chat Não, os demais itens Não
   ou Nenhum, fora de Made for Kids, e `ageRatingOverrideV2=EIGHTEEN_PLUS`. Para aplicar, marque
   também `sem_referencias_alcool` **depois da confirmação pessoal** exigida pelo item 5 do arquivo
   de passos. Sem essa confirmação, a consulta e o plano funcionam, mas a escrita é recusada.
   Só um `appInfo` em `PREPARE_FOR_SUBMISSION` pode ser alterado. Se não existir, o script para;
   não cria nem envia uma versão. Após o PATCH, relê e confere as respostas, mostrando antes e depois.

E-mails não entram no repositório nem no log do script. Cada resultado usa **Testador 1, 2, …**, na
ordem da lista do disparo, inclusive quando há repetição. Guarde essa ordem para identificar quem
ficou de fora. Pendência de convite, papel ou acesso inadequado e recusas individuais da Apple são
reportadas; o job termina com falha se alguém não pôde entrar, preservando as associações aceitas.
Uma repetição consulta o estado atual e não duplica grupo nem associações. As entradas do disparo
ficam no evento do GitHub Actions: não são um segredo do repositório. Restrinja o acesso ao workflow
à equipe que já pode administrá-lo; não cole esses dados em PRs, exemplos ou relatórios.

As entradas são lidas de `GITHUB_EVENT_PATH`, sem interpolação em comandos ou em `env:` que o runner
imprimiria antes do mascaramento. O script registra máscaras `::add-mask::` para chave, linhas da
chave, IDs, JWT e e-mails da entrada.
Não use depuração de shell, não imprima as variáveis e não publique o payload do evento.

Prova local sem rede e sem chave:

```sh
ruby iOS/Scripts/teste-app-store-connect.rb
```

As respostas são exemplos sintéticos em `Scripts/FixturesAppStoreConnect/respostas.json`; o
transporte e a assinatura dos testes são fictícios. A prova real permanece pendente até a chave:
autenticação e permissões, existência e editabilidade do `appInfo`, aceitação dos testadores e
distribuição de um build processado. O log lê a classificação calculada no `appInfo` e verifica
o override 18+. A apresentação **Operating Systems Earlier than Version 26** não foi encontrada
nessa resposta da API e continua exigindo conferência separada; não é inferida como 18+.

Fontes oficiais das chamadas:

- [Autenticação JWT](https://developer.apple.com/documentation/appstoreconnectapi/generating-tokens-for-api-requests)
  e [listar apps](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-apps).
- [Criar grupo](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-betagroups),
  [atributos da criação](https://developer.apple.com/documentation/appstoreconnectapi/betagroupcreaterequest/data-data.dictionary/attributes-data.dictionary),
  [limites dos atributos de atualização](https://developer.apple.com/documentation/appstoreconnectapi/betagroupupdaterequest/data-data.dictionary/attributes-data.dictionary),
  [listar grupos do app](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-apps-_id_-betagroups)
  e [listar testadores do grupo](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-betagroups-_id_-betatesters).
- [Listar usuários da equipe](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-users),
  [apps acessíveis ao usuário](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-users-_id_-visibleapps),
  [listar testadores](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-betatesters),
  [criar recurso TestFlight](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-betatesters)
  e [associar ao grupo](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-betagroups-_id_-relationships-betatesters).
- [Listar app infos](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-apps-_id_-appinfos),
  [ler declaração](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-appinfos-_id_-ageratingdeclaration),
  [alterar declaração](https://developer.apple.com/documentation/appstoreconnectapi/patch-v1-ageratingdeclarations-_id_)
  e [atributos do questionário e override 18+](https://developer.apple.com/documentation/appstoreconnectapi/ageratingdeclarationupdaterequest/data-data.dictionary/attributes-data.dictionary).

**Inferência:** `hasAccessToAllBuilds=true` corresponde à distribuição automática descrita na
[ajuda da Apple](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers).
A referência do atributo não explica essa equivalência; confirmar com o primeiro build processado.
Os documentos de `appInfos` e da declaração permitem a edição antes de submeter o app à revisão;
a ausência de exigência de build enviado nesse caminho também é inferência, a conferir no Frila.

### Mandar o 0.4 (20/10)

```sh
git switch main && git pull
git tag -a v0.4.0 -m "Build 0.4 do TestFlight"
git push origin v0.4.0
```

Acompanhe em Actions > TestFlight. O resumo do job mostra o esquema, a versão e o número do build.
Depois do envio, o App Store Connect ainda processa o build antes de ele aparecer no TestFlight.

### Ensaio de falha (critério do #203, antes de 20/10)

1. Em Actions > TestFlight > Run workflow, escolha o `main`, o `Frila-Beta`, a versão `0.4.0`, e
   marque "Ensaio de falha" e "Enviar ao TestFlight".
2. Quando o build aparecer no TestFlight do grupo interno, instale-o no iPhone e abra.
3. Toque em **Forçar falha (ensaio)**, no canto inferior esquerdo de qualquer tela. O app fecha.
4. Abra o app de novo, sem reinstalar: o relatório sai nesse segundo lançamento.
5. No Firebase, projeto do frila-dev, abra o Crashlytics. A falha "Falha forçada do ensaio do
   TestFlight" deve aparecer na versão 0.4.0, com o número do build, e com a pilha simbolizada:
   `BotaoDeFalhaDoEnsaio` em `FalhaDoEnsaio.swift`. Em 30/09, num build de Debug, a falha levou cerca
   de 2 minutos para aparecer ([Relatório de falhas](CrashReporting.md)).

O ensaio não afeta o build de produção, por quatro travas:
- O botão só compila com `FRILA_ENSAIO_FALHA`, que só o disparo manual liga; tag nunca liga.
- O build de ensaio vai marcado `testFlightInternalTestingOnly`: segundo o `xcodebuild -help`, ele
  "cannot be distributed via external TestFlight or the App Store".
- O `conferir-release.sh` reprova o botão em qualquer outro Release, inclusive nos builds da CI de PR.
- O 0.4 de verdade sai depois, pela tag, com outro número de build e sem o botão.

### Build de medição (#73)

Em Actions > TestFlight > Run workflow, escolha o `main`, o `Frila-Beta` e a versão atual, e marque
"Build de medição" e "Enviar ao TestFlight". O build compila a medição de desempenho e de dados
(`FRILA_MEDICAO`) e tem as mesmas travas do ensaio:
- só o disparo manual liga a condição;
- o build vai marcado `testFlightInternalTestingOnly`;
- o `conferir-release.sh` reprova a medição em qualquer outro Release.

O roteiro do aparelho está em [Desempenho e dados](Desempenho.md).

### Reproduzir na própria máquina

```sh
cd iOS
Scripts/generate-supabase-secrets.sh dev      # com FRILA_SUPABASE_DEV_URL e a chave publicável no ambiente
Scripts/inject-firebase-config.sh dev         # com FRILA_FIREBASE_GOOGLE_SERVICE_INFO_DEV_B64 no ambiente
ASC_KEY_PATH=~/caminho/AuthKey.p8 ASC_KEY_ID=... ASC_ISSUER_ID=... \
  Scripts/enviar-testflight.sh Frila-Beta 0.4.0 --sem-envio
```

Sem as três variáveis `ASC_*`, o script usa a conta logada no Xcode da máquina. Sem `--sem-envio`,
ele manda ao TestFlight. Com `FRILA_ENSAIO_FALHA=1`, ele monta o build de ensaio; com
`FRILA_MEDICAO=1`, o build de medição.

### Próxima validação da identidade local

As duas execuções da investigação já provaram o archive e o defeito do export na nuvem. A próxima
execução requer nova autorização de custo do Cauê, solicitada pelo Nick Fury, e confirmação de que
o Cauê gravou os dois segredos. A preparação do PR foi publicada com `[skip ci]` para não disparar
a CI de PR; nenhum workflow foi disparado nesta etapa.

Executar somente o build autorizado: `Frila-Beta`, versão `0.4.0`, `enviar=true`, sem ensaio de falha
nem medição. Essa execução deve provar:

- importação real do `.p12`, acesso à chave privada e requisito designado válido no runner;
- assinatura do app, quatro frameworks e extensão com o SHA-256 importado, e perfis automáticos
  válidos contendo esse certificado para app e extensão;
- envio dos símbolos ao Crashlytics e aceitação do upload pelo App Store Connect;
- restauração dos keychains e remoção da identidade temporária ao terminar.

Ainda podem falhar: segredo ausente/base64 ou senha incorretos; certificado expirado, revogado,
sem chave privada ou de outra equipe; ACL do keychain no runner; permissão da API ou obtenção de
perfil compatível; Crashlytics; validação/processamento da Apple. A prova local não garante esses
serviços. Se o export selecionar a identidade da nuvem novamente, o diagnóstico interrompe antes
do envio. O segundo export (`destination=upload`) continua usando a mesma identidade disponível,
mas a aceitação pela Apple só será comprovada na execução real.

### Custo

O job usa o mesmo runner `macos-26` da CI de PR e roda só por tag ou disparo manual. Ele consome a
mesma cota de minutos da organização, que tem orçamento de US$ 0 com bloqueio de uso adicional: sem
cobrança.
