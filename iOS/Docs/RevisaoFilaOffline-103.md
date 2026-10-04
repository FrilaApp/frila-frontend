# Revisão da fila offline após o PR #103

Conferência dos achados do Loki em 04/10/2026, com as decisões do Nick Fury para 3A e 3B. O contrato consultado é o espelho [openapi.yaml](../Contrato/openapi.yaml), versão 0.2.32. Nenhuma mudança no contrato.

| Achado | Veredito | Correção ou fundamento |
|---|---|---|
| 1 — check-out após check-in manual | Não procede | `checkin_pendente` significa que nunca houve check-in; não significa confirmação manual pendente. Contrato, linhas 72 e 721. |
| 2 — presença aceita volta a “Não feito” | Procede | A ausência na fila deixa de significar recusa. O modelo consulta o turno e restaura a presença aceita; só remove o estado pendente diante de recusa confirmada. Sem confirmação, conserva a indicação local. |
| 3A — login/saída perde avaliação offline | Comportamento previsto | A política de privacidade limpa os dados da conta anterior. Mantida por decisão do Nick, documentada em [AvaliacaoTurno-22.md](AvaliacaoTurno-22.md). Sem novo aviso na saída. |
| 3B — ação de outra conta é despachada | Procede | Novas ações recebem o autor da sessão na gravação; o sincronizador mantém na fila ações de autor diferente. Regravar o mesmo ID conserva o autor original. Legados sem autor conservam o comportamento anterior, sem identidade atribuída por leitura ou migração; avaliações legadas continuam sem reenvio. |
| 4 — aviso de recusa nunca encerra | Procede | “Fechar” reconhece apenas o aviso escolhido, com persistência. Sucesso posterior na mesma operação, alvo e conta reconhece os avisos anteriores. O registro terminal permanece para impedir que o mesmo ID seja reenfileirado; a saída limpa também esses registros. |
| 5 — reserva mostra avaliação antes do callback | Procede em parte | A segunda notificação já corrigia o estado; havia inconsistência na primeira leitura. Meu turno agora ignora imediatamente a reserva recusada. A reconciliação e o callback continuam vendo a recusa após fechar o aviso. |
| 6 — avaliação reaberta sem explicação | Procede em parte | Meu turno já tinha aviso, mas o modelo novo da avaliação perdia a associação com o ID anterior. Agora recupera por autor/turno e mostra o texto existente. Reler o aviso não apaga uma nova seleção. |
| 7 — avaliação recebe 404/campo_invalido | Não procede no contrato atual | `/rpc/avaliar` declara 200/401/403/409/422. Turno inexistente ou alheio recebe `403 sem_permissao`, já terminal; os parâmetros são UUID e booleano. Não há ramo contratual 404 ou campo_invalido para acrescentar. Contrato, linhas 2521–2572; implementação `public.avaliar(uuid, boolean)` na migração backend `20260926060100_exigir_conta_ativa_escrita.sql`, linhas 76–180. |
| 8 — segunda recusa mantém formulário bloqueado | Procede | Publicação e republicação procuram primeiro a recusa do ID da tentativa atual; deixam de depender da ordem de leitura do armazenamento. |

Fontes de implementação: [CacheSwiftData.swift](../Sources/Dados/CacheSwiftData.swift), [SincronizadorAcoes.swift](../Sources/Dados/SincronizadorAcoes.swift), [PresencaDoTurnoViewModel.swift](../Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift), [IdentidadeDaAvaliacao.swift](../Sources/Apresentacao/Fluxos/Profissional/IdentidadeDaAvaliacao.swift), [MeuTurnoViewModel.swift](../Sources/Apresentacao/Fluxos/Profissional/MeuTurnoViewModel.swift), [AvaliacaoTurnoViewModel.swift](../Sources/Apresentacao/Fluxos/Profissional/AvaliacaoTurnoViewModel.swift), [PublicarVaga.swift](../Sources/Apresentacao/Fluxos/Contratante/PublicarVaga.swift) e [RepublicarVaga.swift](../Sources/Apresentacao/Fluxos/Contratante/RepublicarVaga.swift).

## Provas das correções

| Comportamento | Testes |
|---|---|
| Presença aceita com outra ação recusada | `DependenciaDaFilaTests.entradaAceitaSaidaRecusada` |
| Autor, sete tipos de ação, legado e regravação | `SincronizadorRecusasTests.outroAutor`, `autorNaGravacao`, `legadoSemAutor`, `regravacaoConservaAutor` |
| Fechar aviso persiste sem permitir reenvio | `AvisosDaFilaTests.fecharAvisoConservaRecusaTerminal`; interface `testFecharAvisoDeRecusaNaoVoltaAoReabrirTurnoCancelado` |
| Reserva recusada, reabertura, nova resposta | `AvaliacaoTurnoViewModelTests.recusaAntesDaLimpezaDaReserva`, `reabrirRecusaESuperarAviso`, `fecharRecusaNaoRestauraResposta` |
| Duas recusas destravam a tentativa atual | `PublicarVagaTests.duasRecusasDesbloqueiamAtual`; `RepublicarVagaViewModelTests.duasRecusasDesbloqueiamAtual` |

As regressões iniciais falharam antes das correções: seis testes na primeira rodada, um teste de republicação separado e dois testes para reconhecimento persistente de aviso. Os resultados estão em `evidencias/revisao-loki/antes*.xcresult` no worktree do Homem-Aranha.

Após integrar o main com #134 e #135, a rodada unitária dirigida passou com 113/113 testes (`dirigido-integrado.xcresult`). A rodada anterior com interface passou com 112 unitários e dois testes de interface, 114/114 (`avisos-validado.xcresult`). Todo xcodebuild passou pela fila `vez.sh`, no simulador exclusivo Homem-Aranha, com `-parallel-testing-enabled NO`.

Validação final da suíte e do Release: pendente de conclusão; atualizar antes do PR.
