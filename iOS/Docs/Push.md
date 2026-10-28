# Push (#8)

O backend manda o push pelo FCM, que no iOS entrega pelo APNs (B17). O app registra o aparelho,
pede a permissão e abre a tela certa no toque.

## Ciclo de vida do token (#162)

O token do FCM é do aparelho, e não da pessoa. O `AparelhoDePush` (`Sources/Dados`) cuida de a
quem ele pertence no servidor:

| Momento | O que acontece |
|---|---|
| Abertura com sessão e entrada | `registrar_dispositivo`. O token que era de outra conta passa para quem entrou. Só depois da confirmação o sistema volta a entregar (`AparelhoDePush.ligar`). |
| O FCM entrega ou troca o token | O token é guardado. Com alguém dentro, o novo é registrado na hora e o antigo sai do servidor. |
| Sair da conta | O app desregistra no sistema (a entrega para neste aparelho, com ou sem rede), tenta `remover_dispositivo` antes do `signOut`, com o token guardado, e limpa a central. |
| Sessão encerrada por 401 | Não há mais sessão para chamar o servidor: o aparelho deixa de ser da conta aqui, a entrega é suspensa e a central é limpa. |
| Conta excluída | O servidor apaga os aparelhos da conta (`excluir_conta`), e o app desfaz o vínculo local, suspende a entrega e limpa a central. |

- **O que fica guardado.** O token, o vínculo (`VinculoDoAparelho`: a conta e desde quando o
  aparelho é dela) e, sem vínculo, o id da conta de quem o aparelho era por último (para a entrada
  seguinte saber se houve troca de conta), no Keychain, pelo `ArmazenamentoDoAparelhoNoKeychain`. O esquema Local usa um
  item separado (`com.frila.org.app.push.local`), para o vínculo sobreviver ao app fechado. O token
  nunca vai para log nem para `UserDefaults`.
- **O vínculo só existe com a confirmação do servidor.** Ele começa quando `registrar_dispositivo`
  responde e acaba na saída ou no encerramento da sessão. O payload do push não diz para quem ele é
  (RN15), então é pelo vínculo que o app sabe de quem é o aviso que chegou.
- **Uma operação de cada vez.** Registro, troca de token e saída entram numa fila: a saída pedida
  com um registro em voo espera o registro terminar e só então tira o token.
- **Sair sem rede.** A remoção no servidor falha e não segura a saída: o token continua lá até a
  próxima entrada neste aparelho ou a limpeza dos 60 dias sem atualização. Por isso a saída não
  conta com o servidor: ela chama `unregisterForRemoteNotifications`, que a Apple indica para
  quando alguém sai de uma conta associada a push
  ([documentação](https://developer.apple.com/documentation/uikit/uiapplication/unregisterforremotenotifications()),
  lida em 02/10/2026). Inferência: a página não diz se o método faz efeito sem rede nem se ele
  continua valendo com o app fechado; quem prova são os passos 8 a 10 do roteiro. A entrega só volta com
  `registerForRemoteNotifications`, que o app chama em dois casos: o aparelho já é da conta que
  está nele, ou `registrar_dispositivo` acabou de confirmar o token para quem entrou. Se o registro
  falhar na entrada, o aparelho fica sem receber até a abertura seguinte dar certo.

## FCM e APNs

| Passo | Onde |
|---|---|
| A conta entrou e a permissão está concedida: o app pede o registro ao sistema | `CanalDePushDoAparelho.ativar()` (`Sources/Infraestrutura`) |
| O sistema entrega o token do APNs | `AppDelegate`, que o repassa ao `Messaging` |
| O FCM entrega o token dele, na abertura e a cada troca | `MessagingDelegate` no canal, que chama `AparelhoDePush.receber(token:)` |
| A notificação chega com o app aberto | `AppDelegate.userNotificationCenter(_:willPresent:)` |
| A pessoa toca na notificação (app aberto, em segundo plano ou fechado) | `AppDelegate.userNotificationCenter(_:didReceive:)`, que chama `RoteadorDePush.tocar` |

- **Sem troca de método.** `FirebaseAppDelegateProxyEnabled` é `false` no `Info.plist`: o token e o
  toque passam pelo `AppDelegate`, à vista. O app não pede o registro ao sistema antes de haver
  conta e permissão.
- **Os roteadores são do `AppDelegate`** (`NavegacaoDoApp`): o toque que abre o app chega antes de
  qualquer tela existir, e o `RoteadorDePush` o guarda até a conta ser conhecida.
- **App aberto.** A notificação aparece com faixa e som, como fora do app, mas só a que o toque
  abriria para a conta que está na tela (as regras 1 a 3 de "Push de outra conta" e os ids de que a
  tela precisa). Aviso sem `tipo`, como a mensagem de teste do console do Firebase, não aparece com
  o app aberto. Na abertura, enquanto a conta ainda não é conhecida, nada é mostrado.
- **Saída.** O app suspende a entrega no sistema, tenta tirar o token do servidor e limpa a central
  de notificações ("Sair sem rede", acima).
- **Esquema Local.** Sem `GoogleService-Info.plist` o Firebase não é configurado: o canal não fala
  com o FCM nem com o APNs e entrega um token simulado ao dublê.

### `aps-environment`

O entitlement vem do esquema, por `FRILA_APS_ENVIRONMENT` nos `.xcconfig`: `development` no Local e
no Dev, `production` no Beta e no Prod. O `conferir-release.sh` reprova o bundle de Release cujo
`aps-environment` efetivo não seja exatamente `production`, e a CI roda isso no Beta e no Prod.

O que a CI confere é a configuração declarada, no build de simulador. **No build assinado, quem
decide o valor é o perfil de provisionamento**: com assinatura automática de desenvolvimento, um
build Release-Beta declarando `production` sai assinado com `development` (testado em 02/10/2026),
e o `conferir-release.sh` o reprova: no bundle assinado ele lê a assinatura, e `get-task-allow`
não abranda a regra. No TestFlight o valor vem do perfil de distribuição. Para conferir o build
que foi para lá, rode o `conferir-release.sh` no `.app` exportado, ou:

```bash
codesign -d --entitlements :- caminho/Frila.app | grep -A1 aps-environment
```

## Permissão

O pedido do sistema só aparece uma vez na vida do app, então ele nunca sai sozinho.

| Momento | O que o app faz |
|---|---|
| O profissional salva funções e horários (na criação e na edição do perfil) | Mostra a tela de explicação, se o sistema ainda não perguntou e ela ainda não tiver aparecido nesta sessão do app. |
| O contratante publica a vaga | Idem. |
| "Ativar notificações" na explicação | Só aqui aparece o pedido do sistema. |
| "Agora não" na explicação | Fecha, e o pedido do sistema não é gasto. |
| Volta ao primeiro plano | Relê a permissão: a pessoa pode ter mudado nos Ajustes. |

- **No máximo uma vez por sessão.** A explicação só aparece sozinha uma vez por sessão do app (uma
  abertura), para não cansar. Depois de mostrada (e adiada com "Agora não" ou dispensada), ela não
  volta a aparecer automaticamente em novos salvamentos ou publicações até o app ser aberto de novo.
  O estado fica em memória (`PermissaoDePushModelo.jaMostradaNaSessao`), sem gravar em
  `UserDefaults`.
- **Aviso fixo.** Em Vagas e em Minhas vagas, `AvisoDePermissaoDePush` aparece para quem está sem
  notificação. Com a permissão **negada**, o botão leva aos Ajustes de notificação do app
  (`UIApplication.openNotificationSettingsURLString`). Se o sistema **ainda não perguntou** (a pessoa
  adiou, ou já usava o app antes de o push existir), o botão reabre a explicação quando a pessoa
  quiser, mesmo que ela já tenha aparecido nesta sessão.
- **O que é pedido.** Alerta e som (`PermissaoDePushDoSistema.opcoes`). Sem Time Sensitive, sem
  alerta crítico, sem autorização provisória, sem selo e sem modo de segundo plano (B08); um teste
  confere o código, os entitlements e o `project.yml`.
- **Sem permissão, sem registro.** Só fica registrado no servidor quem tem a permissão concedida
  (contrato de `registrar_dispositivo`: quem não recebe notificação não é alcançável para o
  despacho). Sem ela, o `AparelhoDePush` tira o token do servidor e desfaz o vínculo; quando a
  permissão vem, o registro volta.
- **Textos provisórios.** Não há texto aprovado no frila-docs. Todos os textos da explicação, do
  aviso fixo e do turno não encontrado estão em `Sources/Apresentacao/Fluxos/Push/TextosDoPush.swift`,
  e só lá.
- **No esquema Local** a permissão é simulada, e concedida, para o pedido de verdade não entrar nos
  testes de interface. `-FRILA_PERMISSAO_PUSH <nao-pedida|negada|sistema>` escolhe outro estado
  (`sistema` usa o pedido de verdade), e `-FRILA_PERMISSAO_PUSH_RESPOSTA negada` faz a pessoa recusar.

## Destino do toque

Todo toque entra por um ponto só, o `RoteadorDePush` (`Sources/Apresentacao/Fluxos/Push`). Ele lê o
payload, confere a conta e manda para o `RoteadorDoProfissional` ou para o `RoteadorDoContratante`.
Ele só abre telas: quem candidata, confirma presença ou reabre vaga é a pessoa.

### O que o payload traz

O servidor só deixa passar `tipo`, `vaga_id`, `posicao_id`, `turno_id`, `estabelecimento_id` e
`reaberta` (`privado.notificar` e `filtrarDataPayloadFcm` no frila-backend), todos como texto na raiz
do `userInfo`. Nenhum nome, telefone ou endereço, e **nada que diga de quem é o aviso** (RN15). A
tabela abaixo foi conferida nas migrações do frila-backend (`develop`, 6d96d88).

| Tipo | Quem recebe | Ids no payload | Abre para quem trabalha | Abre para quem contrata |
|---|---|---|---|---|
| `vaga` | profissional | `vaga_id` (`reaberta` só quando é verdade) | detalhe da vaga, ou vaga indisponível | nada |
| `vagas_agrupadas` | profissional | nenhum | lista de vagas | nada |
| `vaga_sem_elegiveis` | casa | `vaga_id` | nada | a vaga |
| `confirmacao` | os dois | `turno_id`, `vaga_id` | o turno | o turno |
| `lembrete_24h`, `lembrete_3h` | os dois | `turno_id` (a casa recebe também `estabelecimento_id`) | o turno | o turno |
| `inicio_sem_checkin` | profissional | `turno_id` | o turno, com o check-in | nada |
| `atraso_15min` | casa | `turno_id`, `posicao_id` | nada | o turno, com Reabrir vaga |
| `fim_sem_checkout` | os dois | `turno_id` | o turno, com o check-out | o turno |
| `vaga_vazia` | casa | `vaga_id`, `posicao_id` | nada | a vaga em alerta |
| `checkin` | casa | `turno_id`, `vaga_id` | nada | o turno |
| `checkin_manual_pendente` | casa | `turno_id`, `vaga_id` | nada | o turno, com Confirmar presença |
| `cancelamento` | a outra parte | `posicao_id`, `vaga_id`, `reaberta`; para o candidato de vaga recolhida, só `vaga_id` e `reaberta` | Meus turnos; sem `posicao_id`, vaga indisponível | a vaga |
| `avaliacao_disponivel` | os dois | `turno_id` | a avaliação do turno | o turno |
| `suspensao`, `reativacao` | a conta | nenhum | reavalia a conta | reavalia a conta |
| `candidatura_recusada` | profissional | `vaga_id` | vaga indisponível: o estabelecimento escolheu outra pessoa | nada |
| `selecao_encerrada` | os dois | `vaga_id` | vaga indisponível: a seleção foi encerrada | a vaga |
| `selecao_lembrete` | casa | `vaga_id` | nada | a vaga, com os candidatos; se a seleção já fechou, a explicação |

- **Vaga indisponível.** A vaga de um aviso que não aceita mais candidatura (preenchida, cancelada,
  encerrada, com o início já passado ou `404`) abre a tela própria, com a volta para a lista. Quem
  decide é o servidor (`estado` e `posicoes_abertas`), nunca o relógio do aparelho. Se a vaga já é
  de quem tocou, o destino é o turno dela.
- **Avisos da seleção (#10).** `candidatura_recusada` e `selecao_encerrada` só trazem a vaga. A
  tela de vaga indisponível lê a candidatura da conta naquela vaga (`minhas_candidaturas`): a
  `recusada` e a `expirada` têm explicação própria; sem essa leitura, vale o estado da vaga.
- **Lembrete da escolha (`selecao_lembrete`, contrato 0.2.38, decisão D6).** Vai a cada membro da
  casa, uma vez por vaga, a 6 h ou menos do prazo de escolha e só com candidatura pendente. O toque
  abre o detalhe da vaga em Minhas vagas, com a seção Candidatos; se a seleção já fechou, a seção
  diz isso ("fechou sem escolha", "concluída") em vez de abrir uma lista vazia. Para quem trabalha
  não abre nada. Título e corpo vêm do servidor (tabela em `TipoNotificacao` do contrato); o app
  não os reescreve: a extensão só neutraliza o aviso de outra conta.
- **Turno pelo id.** O aviso só traz o `turno_id`: a tela procura o turno entre os da conta. O que
  não está lá vira "Não encontramos este turno", e falha de leitura não vira "não encontrado".
- **Suspensão e reativação** não têm tela no payload: o app reavalia a conta, e a situação dela
  decide o que abre.
- **Aviso relê as listas.** Abrir um aviso atualiza a lista de vagas e Meus turnos, ou o painel da casa.

### Push de outra conta

Como o payload não diz o destinatário, a conferência usa o que o aparelho sabe:

1. **Sessão.** Sem sessão, nada abre. Com o app aberto pelo toque, a decisão espera a conta ser
   conhecida; se não houver sessão, o toque é descartado e não reaparece depois de uma entrada.
2. **Vínculo.** O aparelho precisa estar entregue, no servidor, à conta que está na tela
   (`VinculoDoAparelho`), e o aviso precisa ter sido **entregue depois** de o vínculo começar. O
   aviso que já estava na central de notificações quando a conta entrou era de quem estava antes.
   **Na troca de conta** (o aparelho era de outra conta, com vínculo ou com saída), o vínculo de
   quem entra só começa 60 s depois da confirmação do servidor
   (`VinculoDoAparelho.carenciaNaTrocaDeConta`): o aviso mandado à conta anterior que ainda estava
   a caminho chega nesse intervalo. A mesma conta que sai e volta, e a primeira entrada no
   aparelho, não têm carência. O esquema Local também não: o dublê não tem servidor nem aviso a
   caminho, e as contas dele se revezam no mesmo simulador.
3. **Perfil.** O tipo precisa ter destino no perfil da conta: aviso da casa não abre para quem trabalha.
4. **Dados.** A tela de destino lê tudo com a sessão de quem está no aparelho. O turno ou a vaga de
   outra conta não vem na leitura.

O que é entregue antes de o vínculo valer não aparece com o app aberto, não abre nada no toque e
sai da central de notificações (na abertura, a cada mudança do vínculo e ao fim da carência).

**O que sobra**, sem o destinatário no payload:

- **App em segundo plano ou fechado, durante a carência.** Quem mostra a notificação é o sistema,
  sem consultar o app: o aviso da conta anterior entregue logo depois da troca aparece na tela
  bloqueada até o app voltar ao primeiro plano ou, com o app ainda em execução, a carência
  acabar, quando ele sai da central. O app suspenso pelo sistema não executa esse descarte.
- **Depois da carência.** O aviso da conta anterior que o APNs entregar mais de 60 s depois da
  confirmação passa pela regra 2. Ele ainda esbarra nas regras 3 e 4. Inferência: os 60 s não vêm
  de medição da latência do FCM e do APNs; cobrem a entrega que já estava a caminho.
- **O custo da carência.** O aviso de quem entrou, entregue nos primeiros 60 s depois de uma troca
  de conta, é tratado como da conta anterior: não aparece com o app aberto e não abre no toque.
  Ele também **sai da central** no descarte: quem entra perde os próprios avisos desse primeiro
  minuto, e só os vê pelas telas do app.

### Extensão de serviço de notificação (`FrilaNotificationService`, #253, h6RoObK6)

Para fechar a janela da tela bloqueada e do app fechado, o backend manda `mutable-content: 1` e o
`vinculo_id` opaco em `data` (backend #178, contrato 0.2.30). Antes de o sistema exibir o aviso na
tela bloqueada ou na central, a extensão `FrilaNotificationService` (`Sources/NotificationService`)
intercepta a notificação e consulta o `FiltroDoPushPorVinculo` (`Sources/Dominio/VinculoDoPush.swift`),
comparando o `vinculo_id` do payload ao vínculo ativo guardado pelo app no App Group
`group.com.frila.org.app` (`VinculoNoGrupoDoApp`):

- **Conta ativa (mesmo `vinculo_id`):** o aviso pertence à conta atualmente autenticada no aparelho.
  É exibido normalmente com seu título e corpo originais, tanto com o app em primeiro plano (aberto,
  via banner do sistema) quanto com o app em segundo plano ou fechado (tela bloqueada e central de
  notificações). Todos os dados do payload são preservados para navegação correta ao toque.
- **Conta que saiu ou sem sessão ativa (`vinculo_id` divergente ou sem vínculo guardado):** o aviso
  pertence a outra conta que utilizou o iPhone anteriormente (ou a ninguém dentro). Antes de ser
  renderizado na tela bloqueada ou na central, o `FiltroDoPushPorVinculo` neutraliza o aviso: o
  título e o corpo originais são descartados e substituídos pelo **texto neutro**, e o payload de
  dados é esvaziado (`payload: [:]`). Não há exposição de detalhes de vagas, turnos, estabelecimentos
  ou valores para terceiros em posse do dispositivo. O toque no aviso neutro apenas abre o app na raiz,
  sem navegar para telas internas nem expor dados da conta que saiu.
- **Constantes de texto neutro:**
  - Título: `FiltroDoPushPorVinculo.tituloNeutro` (`"Frila"`)
  - Corpo: `FiltroDoPushPorVinculo.corpoNeutro` (`"Nova notificação disponível"`)
  - *Nota:* Texto provisório marcado como **pendente de aprovação final do time de Design**.
- **Aviso sem `vinculo_id` (servidores anteriores à 0.2.30):** segue como veio, mantendo a
  compatibilidade com o comportamento legado.
- **Privacidade e logs:** o `vinculo_id` e os dados do push **nunca são logados**. Apenas o `tipo`
  do aviso (enum público), presença de vínculo e a decisão (`manter` ou `neutralizar`) vão ao log
  (`com.frila.org.app.notificationservice`).

### Configuração no portal Apple Developer (passo a passo do João Paulo)

Os identificadores e perfis seguem o padrão dos targets existentes. Na esteira de CI e no
desenvolvimento local sem assinatura, a compilação ocorre normalmente para simulador sem perfis
reais. Para a geração de builds assinados para aparelho e TestFlight, o João Paulo precisa criar
no [Apple Developer Portal](https://developer.apple.com/account/resources):

1. **Identifiers → App Groups:**
   - Registrar o grupo: `group.com.frila.org.app`
   - Descrição sugerida: `Frila App Group`
2. **Identifiers → App IDs:**
   - App principal (`com.frila.org.app`): editar e habilitar a capability **App Groups**, marcando
     `group.com.frila.org.app`.
   - Extensão (`com.frila.org.app.notificationservice`): criar um App ID novo do tipo App (Explicit).
     - Description: `Frila Notification Service`
     - Bundle ID: `com.frila.org.app.notificationservice`
     - Capabilities: habilitar **App Groups** e associar `group.com.frila.org.app`.
     - *Atenção:* a extensão **não** precisa de *Push Notifications*.
3. **Profiles (Provisionamento Dev / Beta / Prod):**
   - **Assinatura automática:** com `CODE_SIGN_STYLE = Automatic`, Team ID `8B7F7G3Y2U` e o parâmetro
     `-allowProvisioningUpdates` utilizado no `Scripts/enviar-testflight.sh`, o Xcode registra e
     gera os perfis automaticamente assim que os App IDs e o grupo existirem no portal.
   - **Perfis manuais (se necessário):** se o provisionamento manual for configurado, os perfis
     podem ser informados via variáveis nos arquivos `.xcconfig` (em `iOS/Configurations/`):
     - `FRILA_PROVISIONING_PROFILE_APP`
     - `FRILA_PROVISIONING_PROFILE_NOTIFICATION_SERVICE`
     (declaradas em `Shared.xcconfig` e mapeadas no `project.yml`). Regenerar os perfis de
     Development e Distribution para o App principal e criar os dois perfis correspondentes para a
     extensão de notificação.

### Simular no esquema Local

`-FRILA_PUSH <tipo> -FRILA_PUSH_ID <uuid>` entrega o toque ao `RoteadorDePush` depois que a conta do
dublê registra o token simulado (o id vai como `vaga_id` e como `turno_id`). Com
`-FRILA_PUSH_DE_ANTES`, o aviso é datado de antes do vínculo e não abre nada. Só existe em Debug e só
contra o dublê; o `conferir-release.sh` reprova o binário de Release que tiver o gancho.

Para passar pelo sistema, como o push de verdade, junte `-FRILA_PERMISSAO_PUSH sistema` e
`-FRILA_PUSH_NOTIFICACAO_EM <segundos>`: o payload vai numa notificação local, e o toque nela chega
pelo `AppDelegate`, com o app aberto, em segundo plano ou fechado (`NotificacaoDePushUITests`).
O simulador também aceita um push remoto simulado, sem APNs, com a permissão já concedida.
Os payloads de fixture ficam em `Tests/Fixtures/Push/` (`vaga.apns`, `confirmacao-profissional.apns`,
`checkin-manual-contratante.apns`, `lembrete-turno.apns`, `cancelamento.apns`):

```bash
# Validar sintaxe dos payloads APNs:
Scripts/simular-push.sh --validar

# Enviar push de vaga ou turno pelo script (detecta simulador Booted):
Scripts/simular-push.sh vaga [UDID]
Scripts/simular-push.sh confirmacao [UDID]
Scripts/simular-push.sh checkin [UDID]

# Ou diretamente pelo simctl:
xcrun simctl push <UDID> com.frila.org.app Tests/Fixtures/Push/vaga.apns
```

#### Passo a passo de simulação local da extensão (NSE)

Para validar localmente a extensão de notificação e o comportamento do `FiltroDoPushPorVinculo`:

1. **Validar sintaxe das fixtures:**
   Execute a validação estática de todos os arquivos `.apns` em `Tests/Fixtures/Push/`:
   ```bash
   Scripts/simular-push.sh --validar
   ```
   O script confere se o JSON é válido, se contém o objeto `aps`, o campo `tipo` e o `Simulator Target Bundle` correto (`com.frila.org.app`).

2. **Preparação do vínculo e simulação de payloads:**
   - **Habilitação da extensão:** O campo `"mutable-content": 1` no bloco `aps` é a flag do sistema iOS que aciona a extensão `FrilaNotificationService` (`UNNotificationServiceExtension`). Se estiver ausente ou for `0`, o iOS não invoca a extensão e exibe o alerta bruto diretamente.
   - **Origem e consulta do vínculo ativo:** O `vinculo_id` vem do servidor no registro do dispositivo (`api.registrarDispositivo`) e é gravado pelo app na chave `"vinculo_id"` do App Group `group.com.frila.org.app` (`UserDefaults`).
     - *Observação técnica (a confirmar):* No simulador, o comando `defaults` pode não alcançar o container real do App Group (`UserDefaults(suiteName: "group.com.frila.org.app")`), atuando no domínio global de preferências do simulador. A forma comprovada de exercitar gravação/leitura/limpeza no grupo são os testes unitários `NotificationServiceTests` (usam `UserDefaults(suiteName:)` e `removePersistentDomain`). Alternativamente, para inspecionar o container real do grupo no disco (a confirmar), pode-se localizar o caminho com:
       ```bash
       xcrun simctl get_app_container <UDID> com.frila.org.app groups
       ```
     - Para inspeção ou teste rápido via `defaults` no simulador (a confirmar se alcança o container do grupo):
       ```bash
       # Consultar:
       xcrun simctl spawn <UDID> defaults read group.com.frila.org.app vinculo_id

       # Gravar / substituir:
       xcrun simctl spawn <UDID> defaults write group.com.frila.org.app vinculo_id "4d2f6c1a-9b3e-4e7a-8c5d-2f1b0a9e8d7c"

       # Limpar (subcomando delete):
       xcrun simctl spawn <UDID> defaults delete group.com.frila.org.app vinculo_id
       ```

   - **Cenário A — Payload com `vinculo_id` coincidente (conta ativa):**
     O payload contém `"mutable-content": 1` no `aps` e no corpo de dados o mesmo UUID configurado no App Group (`group.com.frila.org.app`):
     ```json
     {
       "Simulator Target Bundle": "com.frila.org.app",
       "aps": {
         "alert": {
           "title": "Turno confirmado",
           "body": "Seu turno de Garçom foi confirmado"
         },
         "mutable-content": 1,
         "sound": "default"
       },
       "tipo": "confirmacao",
       "vinculo_id": "4d2f6c1a-9b3e-4e7a-8c5d-2f1b0a9e8d7c",
       "turno_id": "60000000-0000-0000-0000-000000000001",
       "vaga_id": "40000000-0000-0000-0000-000000000001"
     }
     ```
     *Comportamento esperado:* O `FiltroDoPushPorVinculo` decide `.manter`. O aviso é preservado com título, corpo e dados originais, com o app aberto ou fechado.

   - **Cenário B — Payload com `vinculo_id` divergente ou sem vínculo ativo (conta que saiu):**
     O payload contém `"mutable-content": 1`, mas traz um UUID diferente do guardado no App Group (ou o App Group não possui vínculo ativo após logout):
     ```json
     {
       "Simulator Target Bundle": "com.frila.org.app",
       "aps": {
         "alert": {
           "title": "Turno confirmado",
           "body": "Seu turno de Garçom foi confirmado"
         },
         "mutable-content": 1,
         "sound": "default"
       },
       "tipo": "confirmacao",
       "vinculo_id": "00000000-0000-0000-0000-000000000000",
       "turno_id": "60000000-0000-0000-0000-000000000001",
       "vaga_id": "40000000-0000-0000-0000-000000000001"
     }
     ```
     *Comportamento esperado:* O `FiltroDoPushPorVinculo` decide `.neutralizar`. Título e corpo originais são substituídos por `"Frila"` e `"Nova notificação disponível"`, e todo o dicionário de dados (`payload`) é esvaziado.

   - **Cenário C — Payload legado (sem `vinculo_id`):**
     O payload contém `"mutable-content": 1`, mas **não** possui a chave `vinculo_id` (formato emitido por versões legadas do servidor anteriores à 0.2.30 do contrato):
     ```json
     {
       "Simulator Target Bundle": "com.frila.org.app",
       "aps": {
         "alert": {
           "title": "Turno confirmado",
           "body": "Seu turno de Garçom foi confirmado"
         },
         "mutable-content": 1,
         "sound": "default"
       },
       "tipo": "confirmacao",
       "turno_id": "60000000-0000-0000-0000-000000000001",
       "vaga_id": "40000000-0000-0000-0000-000000000001"
     }
     ```
     *Comportamento esperado:* `FiltroDoPushPorVinculo.decidir(...)` devolve `.manter`. A extensão não altera o conteúdo e o entrega como veio; o descarte de notificações de contas anteriores nesse caso fica a cargo do mecanismo legado do app principal via relógio (`AparelhoDePush.descartarAvisosDeAntesDoVinculo`) quando o app for aberto.

3. **Disparo do push no simulador:**
   Envie o arquivo customizado via script ou `simctl`:
   ```bash
   # Pelo script auxiliar:
   Scripts/simular-push.sh Tests/Fixtures/Push/meu-push.apns [UDID]

   # Diretamente via xcrun simctl:
   xcrun simctl push <UDID> com.frila.org.app Tests/Fixtures/Push/meu-push.apns
   ```

4. **Testes unitários automatizados da extensão:**
   A prova automatizada da lógica de neutralização, gravação e leitura no App Group é executada via testes unitários no alvo `FrilaTests` (esquema `Frila-Local`).

   Para compilar e rodar os testes correspondentes (`NotificationServiceTests` e `NotificationServiceXCTestCase`):
   ```bash
   # Compilar e executar os testes unitários do filtro de notificação:
   xcodebuild test -scheme Frila-Local -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:FrilaTests/NotificationServiceTests -only-testing:FrilaTests/NotificationServiceXCTestCase

   # Ou separando compilação prévia e execução (padrão do gate):
   xcodebuild build-for-testing -scheme Frila-Local -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
   xcodebuild test-without-building -scheme Frila-Local -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:FrilaTests/NotificationServiceTests -only-testing:FrilaTests/NotificationServiceXCTestCase
   ```

## Roteiro de teste no aparelho

> [!IMPORTANT]
> **Validação exclusiva em aparelho físico:** Nada que dependa de validação em aparelho físico vira "feito" sem o aparelho físico. Simulações em simulador e testes unitários comprovam a lógica interna, os modelos e os contratos de dados, mas o ciclo de vida real da entrega pelo APNs, a interceptação em segundo plano pelo iOS e a renderização da extensão na tela bloqueada só são comprovados com o teste executado no iPhone real.

O que o simulador e o dublê não provam, para rodar num iPhone com o build do TestFlight (Beta):

1. **Chegada.** Entre, aceite a permissão e confira no Supabase do ambiente que
   `registrar_dispositivo` gravou o aparelho da conta, com plataforma `ios`. Mande uma mensagem de
   teste pelo console do Firebase do projeto daquele ambiente para o token; repita no outro projeto
   com o build Prod.
2. **Tela bloqueada.** Com o iPhone bloqueado, o aviso aparece e o toque abre a tela do tipo.
3. **App aberto, em segundo plano e fechado.** O toque abre o mesmo destino nos três.
4. **Reinstalação.** Apague o app, instale de novo e entre: o token novo aparece no servidor, e o
   antigo deixa de receber.
5. **Duas contas no mesmo iPhone (filtro por vínculo na tela bloqueada - cartão h6RoObK6):**
   Valida o isolamento de notificações entre contas diferentes no mesmo aparelho físico, comprovando que pushes de uma conta anterior não expõem dados confidenciais na tela bloqueada nem na central de notificações.

   - **Separação de papéis no teste:**
     - **Destinatário (`token` do aparelho):** O token APNs/FCM retornado pelo iOS para este aparelho físico específico. Identifica o hardware destinatário da entrega.
     - **Transporte (APNs / FCM):** A infraestrutura de nuvem que entrega o push ao destinatário.
     - **Vínculo testado (`vinculo_id` no payload):** O identificador opaco da sessão vinculada à conta no backend (contrato 0.2.30), que o servidor inclui no payload de dados e que a extensão compara contra o App Group (`group.com.frila.org.app`).

   - **Origem do `vinculo_id`:**
     O `vinculo_id` é gerado pelo backend Supabase ao registrar o aparelho (`POST /v1/dispositivos`). O app o armazena no App Group na chave `"vinculo_id"` via `VinculoNoGrupoDoApp`. Ao fazer logout (`soltar`), o app apaga esse valor do App Group.

   - **Pré-requisitos:**
     - Build assinado (Beta via TestFlight ou build Development com entitlements) instalado no iPhone físico.
     - Duas contas cadastradas no backend: **Conta A** e **Conta B**.
     - Permissão de notificações concedida para o Frila no aparelho.
     - Acesso a ambiente ou ferramenta de disparo controlado com chave APNs ou console Firebase (**passo humano**).

   - **Passo 1 — Preparação da Conta A e obtenção dos identificadores (passo humano):**
     - Instalar o app no iPhone e fazer login com a **Conta A**.
     - Obter e anotar o `token` do aparelho e o `vinculo_id` gerado para a Conta A (**passo humano**):
       - Consultando o banco Supabase na tabela de dispositivos da Conta A (`select token, vinculo_id from dispositivos ...`), ou
       - Inspecionando os logs de registro no Mac via **Console.app** (filtrando por `com.frila.org.app`).
     - Bloquear o iPhone ou fechar o app.
     - Envio controlado para a Conta A: disparar push endereçado ao `token` do aparelho, contendo `"mutable-content": 1` no `aps` e `vinculo_id: <vinculo_id da Conta A>` no payload (**passo humano**).
     - **Comportamento da conta ativa (app fechado / tela bloqueada):** O aviso é exibido normalmente com seu título e corpo originais na tela bloqueada.
     - Abrir o app e repetir o envio: o aviso é exibido normalmente via banner do sistema com dados originais preservados.

   - **Passo 2 — Troca de conta (Conta A sai, Conta B entra):**
     - No app, realizar logout da Conta A. O app executa a saída e remove o `vinculo_id` do App Group.
     - Fazer login com a **Conta B** no mesmo aparelho.
     - O app registra o aparelho para a Conta B no backend, recebe um novo `vinculo_id` e o grava no App Group.
     - Aguardar a confirmação de registro e o término da janela de carência de 60 s (`carenciaNaTrocaDeConta`). O App Group agora contém ativamente o `vinculo_id` da Conta B.
     - Bloquear a tela do iPhone ou fechar o app.

   - **Passo 3 — Envio controlado para simular notificação da conta que saiu (Conta A) (passo humano):**
     - *Contexto de envio controlado:* Como a saída da Conta A solicita ao servidor a desassociação do dispositivo (`removerDispositivo`), o backend normal não envia pushes da Conta A para esse aparelho. Para exercitar o filtro de isolamento contra pushes residuais, mensagens atrasadas na rede ou disparos concorrentes, faz-se um envio controlado direcionado ao token do aparelho com os dados da conta que saiu.
     - **Execução do envio controlado (passo humano):** No Console do Firebase (Messaging) ou via `curl` na API HTTP v1 do FCM / ferramenta APNs com credenciais de envio:
       - **Destinatário:** O `token` do iPhone (obtido no Passo 1).
       - **Transporte:** APNs / Firebase.
       - **Payload:** `"mutable-content": 1` no bloco `aps`, e nos dados o `vinculo_id` antigo da **Conta A**.
     - **Comportamento esperado da conta que saiu:**
       - O APNs (transporte) entrega a notificação para o `token` do aparelho (destinatário).
       - Com `"mutable-content": 1`, o iOS aciona a extensão `FrilaNotificationService`.
       - A extensão compara o `vinculo_id` do payload (Conta A) com o `vinculo_id` ativo no App Group (Conta B).
       - Constatando a divergência, o `FiltroDoPushPorVinculo` **neutraliza** a notificação:
         - Título original e corpo original são substituídos por `"Frila"` e `"Nova notificação disponível"`.
         - O payload de dados é esvaziado (`payload: [:]`), garantindo que função, turno, endereço e valor da Conta A não sejam expostos na tela bloqueada nem na central.
         - O toque no aviso neutro apenas abre o app na raiz, sem navegar para telas da Conta A.

   - **Passo 4 — Comportamento da conta ativa (Conta B):**
     - Enviar push controlado para o `token` do aparelho com o `vinculo_id` da **Conta B** (**passo humano**).
     - **Comportamento esperado:** O vínculo coincide com o App Group; o aviso é exibido normalmente com título, corpo e dados originais, tanto na tela bloqueada quanto com o app aberto.

   - **Passo 5 — Verificação no Console.app:**
     - Conectar o iPhone ao Mac via cabo, abrir o aplicativo **Console.app** e filtrar pelo subsistema da extensão: `com.frila.org.app.notificationservice`.
     - Confirmar as entradas de telemetria emitidas pela extensão:
       - Para o push da Conta B: `push_recebido tipo=... com_vinculo=true sessao=true decisao=manter`
       - Para o push da Conta A: `push_recebido tipo=... com_vinculo=true sessao=true decisao=neutralizar`
     - Verificar que nem o `vinculo_id` nem os dados privados do push aparecem no log.

6. **Permissão negada.** Negue nos Ajustes e volte ao app: o aviso fixo aparece, e o dispositivo
   sai do servidor.
7. **Assinatura.** `Scripts/conferir-release.sh` no `.app` do build exportado passa, e
   `codesign -d --entitlements :-` mostra `aps-environment = production`.
8. **Sair sem rede.** Entre com a conta A, ponha o iPhone em modo avião, saia da conta, feche o app
   e tire o modo avião. Confira no Supabase que o aparelho ainda está registrado para a A e mande
   um aviso para ela: **não pode aparecer**, nem na tela bloqueada. É a prova de que
   `unregisterForRemoteNotifications` segura a entrega com o token ainda no servidor.
9. **Reativação.** Depois do passo 8, entre com a conta A de novo, com rede: o aviso mandado para
   ela volta a chegar. Repita entrando com a conta B: o aparelho passa a ser da B no servidor, o
   aviso para a B chega (passada a carência) e o aviso para a A não chega.
10. **Reativação sem confirmação.** Depois de sair, entre com a rede falhando no registro (por
    exemplo, cortando a rede logo depois do código de entrada): o aparelho continua sem receber.
    Abra o app de novo com rede: o registro acontece e os avisos voltam.

O simulador e o dublê provam a ordem das chamadas (suspender antes da rede, reativar só depois da
confirmação) e a carência. O efeito de `unregisterForRemoteNotifications` sobre a entrega do APNs,
e a validação do filtro da extensão na tela bloqueada, só o aparelho prova: são os passos 5 e 8 a 10.
Nada que dependa de validação em aparelho físico vira 'feito' sem o teste real no aparelho.

## Rótulo de privacidade da loja

O token de push é registrado no servidor para a conta e guardado no aparelho junto com ela: é um
identificador do aparelho vinculado à pessoa. O `PrivacyInfo.xcprivacy` declara o **Device ID** como
vinculado, para *App Functionality*, sem tracking (um teste confere). No *App Privacy* do App Store
Connect, o que muda, para o Cauê validar:

| Item | Antes | Depois |
|---|---|---|
| Identifiers → Device ID: coletado | Sim | Sim |
| Device ID: vinculado à identidade | Não | **Sim** |
| Device ID: usado para tracking | Não | Não |
| Device ID: finalidade | App Functionality | App Functionality |

Os outros tipos do rótulo não mudam ([Crash Reporting](CrashReporting.md), "App Privacy e manifesto").
