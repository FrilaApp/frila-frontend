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
  conta com o servidor: ela chama `unregisterForRemoteNotifications`, que é do próprio aparelho, e
  o sistema para de entregar push a este app, mesmo com ele fechado. A entrega só volta com
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
| O profissional salva funções e horários (na criação e na edição do perfil) | Mostra a tela de explicação, se o sistema ainda não perguntou. |
| O contratante publica a vaga | Idem. |
| "Ativar notificações" na explicação | Só aqui aparece o pedido do sistema. |
| "Agora não" na explicação | Fecha, e o pedido do sistema não é gasto. |
| Volta ao primeiro plano | Relê a permissão: a pessoa pode ter mudado nos Ajustes. |

- **Aviso fixo.** Em Vagas e em Minhas vagas, `AvisoDePermissaoDePush` aparece para quem está sem
  notificação. Com a permissão **negada**, o botão leva aos Ajustes de notificação do app
  (`UIApplication.openNotificationSettingsURLString`). Se o sistema **ainda não perguntou** (a pessoa
  adiou, ou já usava o app antes de o push existir), o botão abre a explicação.
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
| `candidatura_recusada` | profissional | `vaga_id` | vaga indisponível | nada |
| `selecao_encerrada` | os dois | `vaga_id` | vaga indisponível | a vaga |

- **Vaga indisponível.** A vaga de um aviso que não aceita mais candidatura (preenchida, cancelada,
  encerrada, com o início já passado ou `404`) abre a tela própria, com a volta para a lista. Quem
  decide é o servidor (`estado` e `posicoes_abertas`), nunca o relógio do aparelho. Se a vaga já é
  de quem tocou, o destino é o turno dela.
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
   aparelho, não têm carência.
3. **Perfil.** O tipo precisa ter destino no perfil da conta: aviso da casa não abre para quem trabalha.
4. **Dados.** A tela de destino lê tudo com a sessão de quem está no aparelho. O turno ou a vaga de
   outra conta não vem na leitura.

O que é entregue antes de o vínculo valer não aparece com o app aberto, não abre nada no toque e
sai da central de notificações (na abertura, a cada mudança do vínculo e ao fim da carência).

**O que sobra**, sem o destinatário no payload:

- **App em segundo plano ou fechado, durante a carência.** Quem mostra a notificação é o sistema,
  sem consultar o app: o aviso da conta anterior entregue logo depois da troca aparece na tela
  bloqueada até o app voltar ao primeiro plano ou a carência acabar, quando ele sai da central.
- **Depois da carência.** O aviso da conta anterior que o APNs entregar mais de 60 s depois da
  confirmação passa pela regra 2. Ele ainda esbarra nas regras 3 e 4. Inferência: os 60 s não vêm
  de medição da latência do FCM e do APNs; cobrem a entrega que já estava a caminho.
- **O custo da carência.** O aviso de quem entrou, entregue nos primeiros 60 s depois de uma troca
  de conta, é tratado como da conta anterior: não aparece com o app aberto e não abre no toque.

Só um identificador opaco do destinatário no payload fecha essa janela, com o app conferindo o
aviso antes de mostrar e de abrir. Isso é mudança de contrato (frila-docs, frila-backend e este
app, nessa ordem) e decisão do Cauê.

### Simular no esquema Local

`-FRILA_PUSH <tipo> -FRILA_PUSH_ID <uuid>` entrega o toque ao `RoteadorDePush` depois que a conta do
dublê registra o token simulado (o id vai como `vaga_id` e como `turno_id`). Com
`-FRILA_PUSH_DE_ANTES`, o aviso é datado de antes do vínculo e não abre nada. Só existe em Debug e só
contra o dublê; o `conferir-release.sh` reprova o binário de Release que tiver o gancho.

Para passar pelo sistema, como o push de verdade, junte `-FRILA_PERMISSAO_PUSH sistema` e
`-FRILA_PUSH_NOTIFICACAO_EM <segundos>`: o payload vai numa notificação local, e o toque nela chega
pelo `AppDelegate`, com o app aberto, em segundo plano ou fechado (`NotificacaoDePushUITests`).
O simulador também aceita um push remoto simulado, sem APNs, com a permissão já concedida:

```bash
xcrun simctl push <UDID> com.frila.org.app aviso.apns
# aviso.apns: {"aps":{"alert":{"title":"Frila","body":"Vaga nova"}},"tipo":"vaga","vaga_id":"<uuid>"}
```

## Roteiro de teste no aparelho

O que o simulador e o dublê não provam, para rodar num iPhone com o build do TestFlight (Beta):

1. **Chegada.** Entre, aceite a permissão e confira no Supabase do ambiente que
   `registrar_dispositivo` gravou o aparelho da conta, com plataforma `ios`. Mande uma mensagem de
   teste pelo console do Firebase do projeto daquele ambiente para o token; repita no outro projeto
   com o build Prod.
2. **Tela bloqueada.** Com o iPhone bloqueado, o aviso aparece e o toque abre a tela do tipo.
3. **App aberto, em segundo plano e fechado.** O toque abre o mesmo destino nos três.
4. **Reinstalação.** Apague o app, instale de novo e entre: o token novo aparece no servidor, e o
   antigo deixa de receber.
5. **Duas contas no mesmo iPhone.** Saia da conta A, entre na B e mande um aviso para a A: ele não
   chega. Mande para a B: chega e abre. Um aviso para a B nos primeiros 60 s depois da entrada não
   aparece com o app aberto nem abre no toque (carência da troca de conta); depois disso, sim.
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
confirmação) e a carência. O efeito de `unregisterForRemoteNotifications` sobre a entrega do APNs, e
a volta dela, só o aparelho prova: são os passos 8 a 10.

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
