# Integração contínua

O workflow `.github/workflows/ios.yml` roda em pull requests e pushes que mexem em `iOS/**` ou no próprio workflow, num runner `macos-26`, com permissão só de leitura e limite de 90 minutos. Um push novo cancela a execução anterior do mesmo PR ou branch.

Etapas, na ordem:

1. Seleciona o Xcode 26.6 fixado do runner.
2. Instala o XcodeGen 2.45.3 do release oficial e confere o SHA-256.
3. `Scripts/contrato-em-dia.sh`: o espelho `Contrato/openapi.yaml` bate com a soma gravada; com o secret `FRILA_DOCS_TOKEN`, também com o frila-docs.
4. `python3 Scripts/validate-fixtures.py`: cada fixture contra o schema do contrato, com tipos, formatos, enums e campos fora do contrato.
5. Falha se algum arquivo fora de `Sources/Dados` importar o Supabase.
6. `xcodegen generate` e falha se o `Frila.xcodeproj` versionado divergir do `project.yml`.
7. Injeta os plists do Firebase Dev e Prod.
8. Escolhe o simulador de iPhone disponível com o iOS mais novo, sem aparelho fixo.
9. Restaura `DerivedData/SourcePackages` pelo `Package.resolved` e pela versão do Xcode. Sem cache, resolve os pacotes explicitamente; com cache, a resolução automática fica desabilitada. Produtos de build nunca entram no cache.
10. `xcodebuild build-for-testing` e depois `test-without-building` do `Frila-Local`: testes unitários, de contrato e de interface, sem backend.
11. Gera o `Secrets.xcconfig` de Dev e compila o `Frila-Dev` (pulado se o PR só mexe em testes ou documentação).
12. Compila o `Frila-Beta` (Release apontando para o frila-dev) e confere o bundle (pulado se o PR só mexe em testes ou documentação).
13. Gera o `Secrets.xcconfig` de Prod e compila o `Frila-Prod` e confere o bundle (pulado se o PR só mexe em testes ou documentação).
14. Apaga `Secrets.xcconfig`, plists, produtos de build e temporários, mesmo quando uma etapa falha. O diretório `SourcePackages` fica só até o pós-job de cache salvar os pacotes.

Nenhuma etapa do `ios.yml` assina código (o simulador usa a assinatura local ad-hoc) nem publica artefato. As fases de script do Xcode não exportam variáveis para o log, e o GitHub mascara os segredos.

Desde 24/09 a etapa 12 compila com o `frila-prod` ([Dependências externas](ExternalSetup.md), item 9). Se um dos dois secrets de Prod faltar, ela para em `FRILA_SUPABASE_PROD_URL is not set`, de propósito: Prod sem Supabase não compila em silêncio.

Custo: o repositório é privado e cada minuto macOS consome cerca de dez vezes a cota de um minuto Linux. O orçamento de Actions da organização está em US$ 0 com bloqueio de uso adicional, então esgotar a cota interrompe a CI sem gerar cobrança.

Tempo da CI de PR: no PR #66, em 02/10/2026, a execução levou 39m45s. Os testes do `Frila-Local` tomaram 25m45s, a compilação deles 2m35s, e os builds do Dev, do Beta e do Prod, 1m59s, 4m20s e 3m44s. Nada roda duas vezes: o workflow só dispara em pull request e em push no `main`, e um push novo cancela a execução anterior do mesmo PR. O limite subiu de 45 para 70 minutos quando os testes de interface do push (#8) entraram, e para 90 minutos em 04/10/2026 após o crescimento da suíte de testes de interface (ciclo ponta a ponta e fluxos de cancelamento com motivo), evitando cancelamentos perto do fim que desperdiçam 70 minutos e voltam inteiros à fila. PRs que alteram apenas testes (`iOS/Tests/**`) ou documentação (`**/*.md`, `iOS/Docs/**`) pulam os builds de Release (`Frila-Dev`, `Frila-Beta` e `Frila-Prod`) e suas conferências, economizando cerca de 7m30s a 8m30s por execução. Separar os três builds num job paralelo encurtaria a espera, mas gastaria mais cota, porque a preparação e a compilação dos pacotes se repetiriam; não foi feito.

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
2. Seleciona o Xcode 26.6 e restaura os pacotes SPM do cache da CI de PR, só para leitura.
3. Gera o `Secrets.xcconfig` e o `GoogleService-Info.plist` do ambiente: dev para o Beta, prod para o
   Prod.
4. Grava a chave `.p8` num arquivo temporário com permissão 600.
5. Roda o `Scripts/enviar-testflight.sh`:
   1. **Archive** com a versão e o número do build, na assinatura automática de desenvolvimento do
      projeto. Com `-allowProvisioningUpdates` e a chave, o xcodebuild cria o perfil e o certificado
      de desenvolvimento que faltarem na máquina da CI. A assinatura ad hoc não serve: o Xcode exige
      perfil para o app iOS (medido em 03/10).
   2. **Export** para o App Store Connect com assinatura automática. O Xcode cria o perfil de
      distribuição e usa um certificado gerenciado na nuvem pela Apple. O certificado de distribuição
      e a chave privada dele não ficam no repositório nem nos segredos; o único segredo novo é a
      chave da API.
   3. **Conferência** do app assinado: o `conferir-release.sh` (criptografia, privacidade, ganchos de
      Debug, `aps-environment` de produção) e `get-task-allow` falso.
   4. **Símbolos**: o dSYM do app e o dos quatro frameworks vão ao Crashlytics do ambiente, com duas
      tentativas. Se não subirem, o build não vai ao TestFlight. A Apple também recebe os símbolos
      (`uploadSymbols`).
   5. **Envio**: um segundo export, com `destination: upload` e a mesma assinatura.
6. Apaga a chave, os segredos, o archive, o `.ipa` e o DerivedData, mesmo quando uma etapa falha.
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

   O `.p8` pode ir direto do arquivo, sem passar pela tela:
   `gh secret set APP_STORE_CONNECT_API_KEY_P8 --repo FrilaApp/frila-frontend < AuthKey_XXXXXXXXXX.p8`.
   Depois, guarde o `.p8` no cofre do time ou apague-o; ele nunca entra no Git.

   O job também usa seis segredos que já existem para a CI de PR:
   - `FRILA_SUPABASE_DEV_URL` e `FRILA_SUPABASE_DEV_PUBLISHABLE_KEY`;
   - `FRILA_SUPABASE_PROD_URL` e `FRILA_SUPABASE_PROD_PUBLISHABLE_KEY`;
   - `FRILA_FIREBASE_GOOGLE_SERVICE_INFO_DEV_B64` e `FRILA_FIREBASE_GOOGLE_SERVICE_INFO_PROD_B64`.
3. **TestFlight.** No app `com.frila.org.app`, crie o grupo interno com os cinco e ligue a
   distribuição automática. Assim cada build processado chega ao grupo sem outro passo. As notas "O
   que testar" de cada build também são escritas no App Store Connect.

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

### O que a primeira execução real ainda prova

Em 03/10 o caminho rodou numa máquina do time, com `--sem-envio` e a conta do Xcode no lugar da
chave. Passaram o archive, o export, a conferência do app assinado e os símbolos no Crashlytics. A
máquina já tinha certificado de distribuição, então quatro coisas só a primeira execução no Actions
prova:
- se a chave Admin cria o que falta e assina na nuvem. O runner começa sem certificado nenhum.
  Inferência: o archive pode criar um certificado Apple Development a cada execução. Se eles se
  acumularem em Certificates, Identifiers & Profiles, revogue os antigos; o xcodebuild cria outro
  quando precisar;
- se o App Store Connect aceita o envio e o número do build;
- se o `upload-symbols` roda no runner. Ele caiu com Segmentation fault num build de simulador em
  30/09, e por isso tem duas tentativas;
- quanto tempo o job leva.

Um disparo manual com "Enviar ao TestFlight" desmarcado prova a assinatura na nuvem e os símbolos
no runner, sem mandar nada ao TestFlight.

### Custo

O job usa o mesmo runner `macos-26` da CI de PR e roda só por tag ou disparo manual. Ele consome a
mesma cota de minutos da organização, que tem orçamento de US$ 0 com bloqueio de uso adicional: sem
cobrança.
