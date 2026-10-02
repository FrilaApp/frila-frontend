# Push (#8)

O backend manda o push pelo FCM, que no iOS entrega pelo APNs (B17). O app registra o aparelho,
pede a permissão e abre a tela certa no toque.

## Ciclo de vida do token (#162)

O token do FCM é do aparelho, e não da pessoa. O `AparelhoDePush` (`Sources/Dados`) cuida de a
quem ele pertence no servidor:

| Momento | O que acontece |
|---|---|
| Abertura com sessão e entrada | `registrar_dispositivo`. O token que era de outra conta passa para quem entrou. |
| O FCM entrega ou troca o token | O token é guardado. Com alguém dentro, o novo é registrado na hora e o antigo sai do servidor. |
| Sair da conta | `remover_dispositivo` antes do `signOut`, com o token guardado. |
| Sessão encerrada por 401 | Não há mais sessão para chamar o servidor: o aparelho só deixa de ser da conta aqui. |
| Conta excluída | O servidor apaga os aparelhos da conta (`excluir_conta`), e o app desfaz o vínculo local. |

- **O que fica guardado.** O token e o vínculo (`VinculoDoAparelho`: a conta e desde quando o
  aparelho é dela), no Keychain, pelo `ArmazenamentoDoAparelhoNoKeychain`. No esquema Local fica em
  memória. O token nunca vai para log nem para `UserDefaults`.
- **O vínculo só existe com a confirmação do servidor.** Ele começa quando `registrar_dispositivo`
  responde e acaba na saída ou no encerramento da sessão. O payload do push não diz para quem ele é
  (RN15), então é pelo vínculo que o app sabe de quem é o aviso que chegou.
- **Uma operação de cada vez.** Registro, troca de token e saída entram numa fila: a saída pedida
  com um registro em voo espera o registro terminar e só então tira o token.
- **Limite conhecido.** Quem sai sem rede não consegue tirar o token do servidor. O aparelho deixa
  de ser da conta no app, e o servidor só passa o token adiante na próxima entrada neste aparelho ou
  na limpeza dos 60 dias sem atualização.

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
3. **Perfil.** O tipo precisa ter destino no perfil da conta: aviso da casa não abre para quem trabalha.
4. **Dados.** A tela de destino lê tudo com a sessão de quem está no aparelho. O turno ou a vaga de
   outra conta não vem na leitura.

Limite conhecido: o aviso da conta anterior que o servidor mandou antes da troca e o APNs entregou
depois dela passa pela regra 2. Ele ainda esbarra nas regras 3 e 4, mas só um identificador opaco do
destinatário no payload fecharia essa janela, e isso é mudança de contrato.

### Simular no esquema Local

`-FRILA_PUSH <tipo> -FRILA_PUSH_ID <uuid>` entrega o toque ao `RoteadorDePush` depois que a conta do
dublê registra um token simulado (o id vai como `vaga_id` e como `turno_id`). Com
`-FRILA_PUSH_DE_ANTES`, o aviso é datado de antes do vínculo e não abre nada. Só existe em Debug e só
contra o dublê; o `conferir-release.sh` reprova o binário de Release que tiver o gancho.
