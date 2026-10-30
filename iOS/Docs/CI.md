# Integração contínua

O workflow `.github/workflows/ios.yml` roda em pull requests e pushes que mexem em `iOS/**` (ignorando alterações restritas a Markdown `!iOS/**/*.md` e `!iOS/Docs/**`) ou no próprio workflow, em dois jobs paralelos num runner `macos-26` cada, com permissão só de leitura e limite de 90 minutos por job. Um push novo cancela a execução anterior do mesmo PR ou branch. PRs que tocam apenas documentação não disparam a suíte, liberando a fila e economizando minutos de macOS.

## Duas partes

Desde 06/10/2026 (PR #147), a suíte do `Frila-Local` é dividida por uma lista só, `Tests/parte-1-da-ci.txt`:

- **Parte 1** (`parte-1`): os portões que não compilam (etapas 3 a 6 abaixo e a conferência das partes), depois os testes unitários (`FrilaTests` inteiro) e as classes de interface da lista, com `-only-testing`.
- **Parte 2** (`parte-2`): todo o resto da suíte, com `-skip-testing` da mesma lista, e os builds de Release (etapas 12 a 14), que continuam pulados em PR que só mexe em testes ou documentação. Os builds de Release vêm antes dos testes de interface: um Release quebrado reprova em minutos.

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

Em 06/10 essa conferência deu 1.101 testes na parte 1 e 155 na parte 2, que somavam os 1.256 da suíte (para a contagem vigente atualizada, consulte o log da execução da CI ou `iOS/Scripts/partes-dos-testes.sh`; em 16/10/2026, a suíte soma >1.300 testes com 1.322 `@Test` unitários). Cada enumeração levou de 37 a 64 s localmente, por isso ela não roda em toda execução da CI.

## Etapas

Etapas, na ordem:

1. Seleciona o Xcode 26.6 fixado do runner.
2. Instala o XcodeGen 2.45.3 do release oficial e confere o SHA-256.
3. `Scripts/contrato-em-dia.sh`: o espelho `Contrato/openapi.yaml` bate com a soma gravada; com o secret `FRILA_DOCS_TOKEN`, também com o frila-docs.
4. `python3 Scripts/validate-fixtures.py`: cada fixture contra o schema do contrato, com tipos, formatos, enums e campos fora do contrato.
5. Falha se algum arquivo em `Sources` (fora de `Sources/Dados`) ou em `Tests` importar o Supabase.
6. Conferência de textos, tokens e datas dos dublês, com os autotestes e portões que o workflow executa: `Scripts/teste-conferir-textos.sh` e `Scripts/conferir-textos.sh` (textos da Apresentação, bundle e tokens); `Scripts/teste-conferir-movimento.sh` e `Scripts/conferir-movimento.sh` (respeito a Reduzir Movimento); `Scripts/teste-conferir-datas-fixas.sh` e `Scripts/conferir-datas-fixas.sh` (recusa datas fixas nos dublês).
7. `Scripts/gerar-projeto.sh` para gerar o `Frila.xcodeproj` via XcodeGen e restaurar o `Package.resolved` versionado.
8. Injeta os plists do Firebase Dev e Prod.
9. Escolhe o simulador de iPhone disponível com o iOS mais novo, sem aparelho fixo.
10. Restaura `DerivedData/SourcePackages` pelo hash do `Package.resolved` e pela versão do Xcode. Sem cache, resolve os pacotes explicitamente com `-onlyUsePackageVersionsFromResolvedFile`; com cache, a resolução automática fica desabilitada. Produtos de build nunca entram no cache.
11. `xcodebuild build-for-testing` e depois `test-without-building` do `Frila-Local`: testes unitários, de contrato e de interface, sem backend. Cada parte compila e roda a sua fatia: a parte 1, a lista; a parte 2, o resto (veja [Duas partes](#duas-partes)).
12. Gera o `Secrets.xcconfig` de Dev e compila o `Frila-Dev` (pulado se o PR só mexe em testes ou documentação).
13. Compila o `Frila-Beta` (Release apontando para o frila-dev) e confere o bundle (pulado se o PR só mexe em testes ou documentação).
14. Gera o `Secrets.xcconfig` de Prod e compila o `Frila-Prod` e confere o bundle (pulado se o PR só mexe em testes ou documentação).
15. Apaga `Secrets.xcconfig`, plists, produtos de build e temporários, mesmo quando uma etapa falha. O diretório `SourcePackages` fica só até o pós-job de cache salvar os pacotes.

Nenhuma etapa do `ios.yml` assina código (o simulador usa a assinatura local ad-hoc) nem publica artefato. As fases de script do Xcode não exportam variáveis para o log, e o GitHub mascara os segredos.

Desde 24/09 a etapa 14 compila com o `frila-prod` ([Dependências externas](ExternalSetup.md), item 9). Se um dos dois secrets de Prod faltar, ela para em `FRILA_SUPABASE_PROD_URL is not set`, de propósito: Prod sem Supabase não compila em silêncio.

Custo: o repositório é privado e cada minuto macOS consome cerca de dez vezes a cota de um minuto Linux. O orçamento de Actions da organização está em US$ 0 com bloqueio de uso adicional, então esgotar a cota interrompe a CI sem gerar cobrança.

Tempo da CI de PR: no PR #66, em 02/10/2026, a execução levou 39m45s. Os testes do `Frila-Local` tomaram 25m45s, a compilação deles 2m35s, e os builds do Dev, do Beta e do Prod, 1m59s, 4m20s e 3m44s. Nada roda duas vezes: o workflow só dispara em pull request e em push no `main`, e um push novo cancela a execução anterior do mesmo PR. O limite subiu de 45 para 70 minutos quando os testes de interface do push (#8) entraram, e para 90 minutos em 04/10/2026 após o crescimento da suíte de testes de interface (ciclo ponta a ponta e fluxos de cancelamento com motivo), evitando cancelamentos perto do fim que desperdiçam 70 minutos e voltam inteiros à fila. PRs que alteram apenas documentação (`!iOS/**/*.md`, `!iOS/Docs/**`) não disparam o workflow, poupando ~100 minutos de macOS por PR; PRs que alteram apenas testes (`iOS/Tests/**`) rodam os testes, mas pulam os builds de Release (`Frila-Dev`, `Frila-Beta` e `Frila-Prod`) e suas conferências, economizando cerca de 7m30s a 8m30s por execução. Separar os três builds num job paralelo encurtaria a espera, mas gastaria mais cota, porque a preparação e a compilação dos pacotes se repetiriam; não foi feito.

Em outubro de 2026 o job único chegou perto do limite: na 37244334865 (push no `main`, 05/10) ele terminou em 85m45s, 75 deles no passo de testes. A primeira tentativa do PR #147 separou a interface num job e deixou os unitários e os builds de Release em outro. O job de interface levou 81m09s na 37241695780 e foi cortado nos 90 minutos na 37251084274. Nessa execução, as 16 primeiras classes levaram 46,5 minutos, contra 38,8 na 37241695780. Daí as duas partes de hoje, com os builds de Release na parte 2 em vez de num terceiro job.

Paralelismo de testes no simulador: medido e descartado em 03/10/2026 no PR #102. Tentar rodar os testes em paralelo no xcodebuild (`-parallel-testing-enabled YES -maximum-parallel-testing-workers 2`) subiu o tempo do passo de testes de 42-53 minutos para 67m45s (estourando o limite de 70 minutos do workflow) e causou 8 falhas espúrias por lentidão extrema. O runner `macos-26` do GitHub Actions tem apenas 3 vCPUs; subir e manter dois clones de simulador concorrentes sobrecarrega a CPU (só o boot inicial levou 10m20s) e quebra a sincronização de acessibilidade do XCUITest. O simulador único sequencial é 15 a 25 minutos mais rápido e 100% determinístico. Não ligue paralelismo de simulador na CI sem runners com mais núcleos dedicados.

## Suíte completa no main: agendada

Desde 12/10/2026, o `ios.yml` não dispara mais a cada push no `main`. A suíte completa roda agendada diariamente às 06h UTC e por disparo manual.

Motivo e números do mapa (11–12/10/2026):
- Em 29 h, de 14 pushes no `main`, apenas 2 terminaram verdes: 9 foram cancelados pelo merge seguinte (`cancel-in-progress`), desperdiçando 362 minutos de runner macOS e 399,5 minutos de fila sem validar nada; 3 falharam.
- Cada PR já passa na suíte completa antes do merge; repetir a execução a cada push congestionava os runners macOS.

Para disparar à mão no `main` (ex.: antes de tag de TestFlight):
```sh
gh workflow run ios.yml --ref main
```

## Mandar um build ao TestFlight

O workflow `.github/workflows/testflight.yml` arquiva, assina, confere e manda o app ao TestFlight
(#203). Todo o trabalho fica em `Scripts/enviar-testflight.sh`, que roda igual na CI e na máquina de
quem precisar reproduzir. Ele não mexe na CI de PR.

### Quando roda

- **Tag `vX.Y.Z` num commit do `main`**: manda o esquema da tag com a versão `X.Y.Z`. O esquema da tag
  é o `Frila-Prod` (Release apontando para o frila-prod); o frila-prod foi provisionado em 26/10/2026
  e as tags passam a mandar o Frila-Prod a partir deste PR (28/10/2026) — o 0.4 foi enviado com o
  Frila-Beta. Uma tag fora do `main` é recusada.
- **Disparo manual** (Actions > TestFlight > Run workflow): escolhe o esquema (`Frila-Beta` ou
  `Frila-Prod`), a versão, o ensaio de falha, o build de medição e se envia. Com "Enviar ao
  TestFlight" desmarcado, o job faz o archive, a assinatura, a conferência e os símbolos e para antes
  do envio.
- **Prod como padrão da tag**: no `testflight.yml`, a linha ativa é `ESQUEMA_DA_TAG: Frila-Prod`
  (frila-prod provisionado em 26/10/2026; tags passam a mandar o Frila-Prod a partir deste PR, em
  28/10/2026). Os dois esquemas têm o mesmo bundle id e vão para o mesmo app no App Store Connect.

### O que o job faz

1. Confere a tag (no `main`, formato `vX.Y.Z`) ou as entradas do disparo manual, e calcula o número
   do build.
2. Seleciona o Xcode 26.6, importa a identidade Apple Distribution e os perfis de provisionamento App
   Store dos dois alvos (`com.frila.org.app` e extensão `com.frila.org.app.notificationservice`) em
   keychain temporário e pasta de perfis descartável, provando a assinatura estrita antes do archive.
   Restaura os pacotes SPM do cache da CI de PR, só para leitura.
3. Gera o `Secrets.xcconfig` e o `GoogleService-Info.plist` do ambiente: dev para o Beta, prod para o
   Prod.
4. Grava a chave `.p8` num arquivo temporário com permissão 600.
5. Roda o `Scripts/enviar-testflight.sh`:
   1. **Archive** com a versão e o número do build, com assinatura manual estrita (`CODE_SIGN_STYLE=Manual`,
      `CODE_SIGN_IDENTITY="Apple Distribution"`, `DEVELOPMENT_TEAM=8B7F7G3Y2U` e `PROVISIONING_PROFILE_SPECIFIER`
      apontando para os perfis instalados). O uso de `-allowProvisioningUpdates` é estritamente proibido:
      em runners efêmeros, a assinatura automática criava certificados Apple Development via API em execuções de CI
      até esgotar a cota da conta (incidente de 29/10/2026, run 40931884226).
   2. **Export** para o App Store Connect com assinatura manual (`signingStyle: manual`,
      `signingCertificate: Apple Distribution` e o dicionário `provisioningProfiles` mapeando
      `com.frila.org.app` e `com.frila.org.app.notificationservice` para os perfis importados).
   3. **Conferência** do app assinado: o `conferir-release.sh` (criptografia, privacidade, ganchos de
      Debug, `aps-environment` de produção) e `get-task-allow` falso. O diagnóstico verifica a assinatura
      estrita do archive e do export (app, frameworks e extensão), o SHA-256 da identidade importada
      e a integridade dos perfis.
   4. **Símbolos**: o dSYM do app e o dos quatro frameworks vão ao Crashlytics do ambiente, com duas
      tentativas. Se não subirem, o build não vai ao TestFlight. A Apple também recebe os símbolos
      (`uploadSymbols`).
   5. **Envio**: um segundo export, com `destination: upload` autenticado pela chave API, sem recriar
      ou atualizar certificados.
6. Restaura a lista anterior de keychains e apaga a identidade temporária, os perfis instalados,
   a chave, os segredos, o archive, o `.ipa` e o DerivedData, mesmo quando uma etapa falha.
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

Além dos três segredos da API abaixo, a assinatura manual exige quatro segredos de identidade e provisionamento:
- `APPLE_DISTRIBUTION_CERT_P12_BASE64`: identidade Apple Distribution com chave privada, em base64;
- `APPLE_DISTRIBUTION_CERT_P12_PASSWORD`: senha do arquivo `.p12`;
- `APPLE_PROVISIONING_PROFILE_APP_BASE64`: perfil de provisionamento App Store para `com.frila.org.app`, em base64 (`base64 -i Frila_AppStore.mobileprovision`);
- `APPLE_PROVISIONING_PROFILE_NOTIFICATION_SERVICE_BASE64`: perfil de provisionamento App Store para `com.frila.org.app.notificationservice`, em base64 (`base64 -i FrilaNotificationService_AppStore.mobileprovision`).

Os valores ficam nos segredos do GitHub; nunca no repositório ou nos logs. O keychain temporário
recebe permissão para o codesign e é removido no passo de limpeza `always()`, assim como os arquivos
`.mobileprovision` instalados em `~/Library/MobileDevice/Provisioning Profiles/`.

#### Por que perfis via segredos Base64 (Opção B) em vez de download dinâmico via API (Opção A)

1. **Determinismo e velocidade offline:** A etapa de build e archive roda offline em relação à API de provisionamento da Apple, sem depender de chamadas à API da Apple durante a compilação.
2. **Prevenção total de criação de certificados:** Na Opção A, qualquer descompasso entre perfil e certificado em tempo de execução poderia acionar regras automáticas do Xcode que tentam gerar certificados na nuvem. A Opção B é estritamente manual: se o perfil divergir ou expirar, a CI falha localmente antes de compilar o app, sem alterar nada na conta Apple.
3. **Consistência de governança:** Segue exatamente o padrão já adotado com sucesso para a chave privada de distribuição (`APPLE_DISTRIBUTION_CERT_P12_BASE64`).

#### Inventário de certificados e política de revogação na conta Apple

A lista de certificados da conta Apple (conferida em 29/10/2026 em [developer.apple.com/account/resources/certificates/list](https://developer.apple.com/account/resources/certificates/list)) continha 16 certificados: 6 certificados de desenvolvimento com o nome pessoal do Cauê e 10 certificados do tipo `Apple Development` criados com o rótulo "Created via API" (gerados via chave de API da CI nas datas 07/10, 14/10, 21/10, 22/10 e 28/10, vários por dia), o que atingiu o teto da conta ("maximum number of certificates").

- **NUNCA REVOGAR:** O certificado `Apple Distribution` da equipe `8B7F7G3Y2U` cuja impressão digital pública SHA-256 seja `38e2bde028a40fd58ba637773890076dc42f7b2d50bde0f4499ff08cec5e9f28`. Este é o certificado de produção oficial vinculado aos segredos da CI. Revogá-lo invalida a identidade de distribuição e impede a assinatura de novos builds do TestFlight.
- **REVOGAÇÃO DE CERTIFICADOS DEVELOPMENT:** Revogar certificados do tipo `Apple Development` **não afeta** builds de TestFlight (que usam `Apple Distribution`). Contudo, revogar um certificado invalida qualquer perfil de provisionamento que o contenha. Portanto, a regra é estrita: **só revogue certificados que o inventário comprove terem sido "Created via API" e que não tenham nenhum perfil de desenvolvimento ativo em uso**. Os 10 certificados `Apple Development` "Created via API" acumulados foram revogados pelo Cauê em 29/10/2026 pelo portal da Apple, restando seis certificados Development remanescentes, além da Distribution preservada.

#### Histórico do destravamento e estado dos perfis (concluído em 29/10/2026)

1. **Limpeza comprovada:** O Cauê acessou o portal Apple em 29/10/2026 e revogou os 10 certificados `Apple Development` identificados como "Created via API" e sem perfis em uso, preservando os 6 certificados pessoais de desenvolvimento e mantendo intacto o certificado permanente `Apple Distribution` (`38e2bde028a40fd58ba637773890076dc42f7b2d50bde0f4499ff08cec5e9f28`).
2. **Perfis App Store cadastrados:** Foram criados pelo Cauê no portal da Apple em 29/10/2026:
   - `Frila_AppStore`: tipo App Store, App ID `com.frila.org.app`, push de produção habilitado, validade até 01/07/2027;
   - `FrilaNotificationService_AppStore`: tipo App Store, App ID `com.frila.org.app.notificationservice`, grupo `group.com.frila.org.app`, validade até 01/07/2027;
   - Ambos estão vinculados ao certificado oficial `Apple Distribution` da CI.
   - *Nota de flexibilidade:* O nome textual do perfil no portal Apple não precisa ser fixo (o script `assinatura-local-ci.py` inspeciona os metadados do arquivo e extrai dinamicamente o `UUID` e o `Name` para registrar a assinatura manual no Xcode).
3. **Segredos gravados no GitHub:** Os dois arquivos `.mobileprovision` foram codificados em base64 e salvos pelo Cauê em 29/10/2026 nos segredos do repositório:
   - `APPLE_PROVISIONING_PROFILE_APP_BASE64`
   - `APPLE_PROVISIONING_PROFILE_NOTIFICATION_SERVICE_BASE64`
4. **Validação:** Um teste sem envio via Actions (`Actions > TestFlight > Run workflow`, com `enviar: false`) pode ser disparado após autorização expressa do dono, validando archive manual, export manual, conferência de release e envio de dSYMs sem publicar para testadores externos.

#### Renovação de perfis

Perfis de provisionamento da App Store têm validade padrão de 1 ano (os perfis atuais vencem em 01/07/2027). Quando um perfil estiver prestes a expirar:
1. No portal Apple Developer (Profiles), gere um novo perfil App Store para o bundle ID, associando ao certificado `Apple Distribution` existente.
2. Baixe o arquivo `.mobileprovision`.
3. Codifique em base64: `base64 -i PerfilNovo.mobileprovision | pbcopy`.
4. Atualize o segredo correspondente no GitHub:
   - Para o app: `gh secret set APPLE_PROVISIONING_PROFILE_APP_BASE64 --repo FrilaApp/frila-frontend`
   - Para a extensão de notificações: `gh secret set APPLE_PROVISIONING_PROFILE_NOTIFICATION_SERVICE_BASE64 --repo FrilaApp/frila-frontend`
5. O script `assinatura-local-ci.py` confere automaticamente a validade, a equipe, o bundle ID e o vínculo com a chave de distribuição no pré-voo de cada execução.

Regressão sem credenciais reais: `python3 iOS/Scripts/teste-assinatura-local-ci.py` e
`python3 iOS/Scripts/teste-diagnosticar-assinatura.py`.

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
   | `APPLE_DISTRIBUTION_CERT_P12_BASE64` | certificado e chave privada Apple Distribution (.p12) em base64 |
   | `APPLE_DISTRIBUTION_CERT_P12_PASSWORD` | senha do arquivo .p12 |
   | `APPLE_PROVISIONING_PROFILE_APP_BASE64` | perfil App Store de com.frila.org.app em base64 |
   | `APPLE_PROVISIONING_PROFILE_NOTIFICATION_SERVICE_BASE64` | perfil App Store da extensão em base64 |

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

### Validação e próximo envio

A execução [38610555474](https://github.com/FrilaApp/frila-frontend/actions/runs/38610555474), de
14/10/2026, enviou `Frila-Beta 0.4.0 (20261014.175413)` a partir da branch do PR #163, com identidade
Apple Distribution local e cinco dSYMs enviados ao Crashlytics. A execução anterior da main,
[37683822842](https://github.com/FrilaApp/frila-frontend/actions/runs/37683822842), falhou no envio
com `Invalid Signature` no app, frameworks e extensão. A correção da assinatura vem daquele PR;
os portões, o contrato e as configurações de release atuais da main são preservados.

O ensaio manual usa `Frila-Beta`, versão `0.5.0`, `ensaio_falha=false`, `medicao=false` e
`enviar=false`. Ele prova archive, export, assinatura, conferência e símbolos no runner; a aceitação
do próximo upload depende do envio real. Depois do merge do MVP, use `0.5.0` com um novo disparo:
o build é calculado novamente em UTC, e o ensaio não ocupa esse número no App Store Connect.

Inferência: um número gerado em 21/10 será maior que o último envio comprovado
(`20261014.175413`). A consulta `conferir` do `app-store-connect.yml` lista grupos e classificação,
sem listar builds; ela não confirma envios externos ao workflow. A referência de versão é o último
envio acima e o cartão TestFlight 0.5.

### Custo

O job usa o mesmo runner `macos-26` da CI de PR e roda só por tag ou disparo manual. Ele consome a
mesma cota de minutos da organização, que tem orçamento de US$ 0 com bloqueio de uso adicional: sem
cobrança.

## Builds de loja

Política oficial decidida pelo Cauê em 28/10/2026:

- **Origem dos builds:** Todos os builds destinados ao TestFlight e à App Store saem exclusivamente da CI pelo workflow `.github/workflows/testflight.yml`.
- **Versão do Xcode da CI:** A CI utiliza o Xcode da versão fixada no workflow: versão `26.6` (definida em `.github/workflows/testflight.yml:54` como `XCODE_VERSION: "26.6"`, e conferida nas etapas das linhas 121–135; também fixada em `.github/workflows/ios.yml:39, 226`).
- **Papel do Mac de desenvolvimento:** O Xcode instalado no Mac de desenvolvimento serve para desenvolver e testar; nada é enviado à Apple diretamente a partir do Mac.
