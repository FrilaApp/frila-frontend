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
