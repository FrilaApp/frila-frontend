# Avaliação depois do turno — cartão #22

A avaliação do profissional guarda uma resposta por conta e turno. O ID vem de
`minhaConta().sessao.usuarioID` e é passado pela entrada do app ao fluxo do profissional.
Com sessão ativa e sem rede, a identidade vem de `CacheLocal.sessao()`. Uma nova
autenticação invalida o cache da sessão anterior antes de buscar o ID da nova conta.

`UserDefaultsArmazenamentoAvaliacoes` separa as respostas pelo ID da conta e pelo ID do
turno. Na saída explícita e no encerramento observado da sessão, as respostas locais
são apagadas. A avaliação offline ainda não sincronizada se perde ao sair, para que ações e dados da conta anterior não fiquem para a próxima autenticação. Chaves antigas sem autor não são atribuídas à conta que entrar.

O `409 avaliacao_ja_registrada` bloqueia a escolha, limpa a seleção recusada e guarda
somente a informação de que já existe avaliação. Não guarda Sim ou Não. O mesmo vale
para o 409 durante o reenvio: a ação recusada sai da fila e a resposta local passa ao
estado sem resposta conhecida. Ao reabrir, a tela mostra “Esta avaliação já foi registrada.”.

Sem rede, a fila guarda também o ID da conta. A primeira avaliação por conta e turno
prevalece, inclusive entre modelos distintos. A reabertura consulta a fila mesmo
quando a resposta já está nos UserDefaults e mostra que ela está pendente. O reenvio
confere a conta atual; avaliações legadas sem autor conhecido não são reenviadas.

## Evidência dos critérios

Os nomes abaixo identificam os testes em `Tests/Unitarios/AvaliacaoTurnoViewModelTests.swift`,
`Tests/Unitarios/ArmazenamentoAvaliacoesTests.swift` e `Tests/UI/AvaliacaoUITests.swift`.

| Item | Teste que prova |
|---|---|
| Segunda resposta barrada, sem trocar a seleção | `segundaRespostaBarrada`; `reentradaComGuard` |
| Reabrir mostra a resposta dada no aparelho | `reabrirMostraRespostaDada`; `respostasPorTurnoEConta` |
| 409 neutro, sem guardar a resposta recusada | `erro409AvaliacaoJaRegistrada`; `registroNeutroPersistido`; `conflitoNoReenvio` |
| Sem resposta local e `pode_avaliar = false` | `jaRegistradaSemRespostaLocal` |
| Sem rede, fila única e reabertura pendente | `semRedeEnfileirando`; `filaNaoDuplica`; `reabrirCarregaRespostaDaFilaPendente` |
| Isolamento entre contas | `outraContaNaoVeResposta`; `respostasPorTurnoEConta`; `reenvioRespeitaAutor` |
| Saída explícita e encerramento de sessão | `saidaRemoveAvaliacoes`; `encerramentoRemoveAvaliacoes` |
| Identidade da conta online, offline e após nova entrada | `identidadeOnline`; `identidadeOfflineENovaEntrada` |
| Pergunta, Sim e Não, nesta ordem, com rótulo, valor e seleção | `testPerguntaSimNaoEmOrdemComRotuloValorESelecao` |
| Resposta guardada selecionada e botões desabilitados | `testRespostaGuardadaFicaSelecionadaSemPermitirTroca` |

O teste de interface usa a tela de avaliação de produto em uma entrada Debug exclusiva
do dublê Local, com armazenamento isolado. Consulta os elementos do XCTest e anexa a
árvore de acessibilidade como texto. As provas de rótulo, valor, seleção e ordem não
usam imagens. “Selecionado” e “Não selecionado” já existem no catálogo e são lidos com
`bundleApresentacao`.

Validação em 01/10/2026: `xcodebuild test -project iOS/Frila.xcodeproj -scheme Frila-Local
-destination 'platform=iOS Simulator,id=85940BCB-553C-4145-8F8E-E83423D86431'
-derivedDataPath iOS/DerivedData/avaliacao22 -parallel-testing-enabled NO` passou com
290 testes unitários e 43 testes de interface, sem falhas. `conferir-textos.sh` passou,
as 28 fixtures do contrato foram validadas e o projeto versionado foi gerado com XcodeGen.

## Revisão do PR #52

A recuperação offline do destino não depende da identidade da avaliação. Com destino
guardado, sem rede e sem sessão no cache (ou sem armazenamento), o app abre o fluxo
normal com `contaID = nil`; a avaliação permanece indisponível. Os testes de interface
`testSemRedeSemSessaoNoCacheAbreDestinoGuardado` e
`testSemRedeSemArmazenamentoAbreDestinoGuardado` passam pela entrada real do app,
com cache vazio isolado ou ausente, exclusivamente no dublê Local em Debug. O primeiro
reproduziu a regressão antes da correção.

Uma rota de avaliação sem identidade mostra `EstadoErro` com a mensagem de falta de
conexão e “Tentar novamente”. O botão consulta novamente a identidade; sem sucesso,
mantém esse estado e não permite responder. `testRotaSemIdentidadeMostraSemConexaoComNovaTentativa`
confere a rota e a nova tentativa. O roteador seleciona a aba da pilha que contém essa
rota. O texto antigo `respostaRegistrada`, sem uso, foi removido junto de sua tradução.

As chamadas de `minhaConta()` na abertura e no reenvio foram mantidas nesta revisão.
Reaproveitar a conta entre os dois resolvedores exige alterar a interface de resolução
do destino, além dos dois ajustes solicitados. `SaidaDaConta` e os arquivos reservados
não tiveram mudanças na revisão.

Validação da revisão: o mesmo comando da suíte completa passou com 290 testes
unitários e 46 testes de interface, sem falhas. Antes dela, passaram 29 testes
unitários e os 5 testes de interface da avaliação no teste dirigido.
`conferir-textos.sh` e `git diff --check` também passaram.

## Limite e dependência do contrato

“Reabrir mostra a resposta dada” vale somente para a mesma conta, no mesmo aparelho e
na mesma instalação, enquanto o dado local existir. A saída da conta limpa esse dado.
Após reinstalação, em outro aparelho ou sem resposta local, `pode_avaliar = false`
bloqueia a escolha e mostra o estado registrado sem afirmar qual foi a resposta.

O contrato 0.2.27 não devolve a resposta anterior em `Turno`: somente `pode_avaliar`.
Proposta para decisão do Cauê: acrescentar `avaliacao_dada: Avaliacao | null` no schema
`Turno` devolvido por `GET /rpc/meus_turnos`, com a avaliação do lado do chamador, e
`null` quando esse lado ainda não avaliou. O contrato deve mudar no `frila-docs` e ser
implementado no backend antes de chegar ao app. A exportação de dados não foi integrada.

A implementação inicial cobriu o profissional. Em 04/10/2026, a avaliação pelo contratante
foi integrada pelo PR #126 (`AcompanhamentoViewModel`, `TelaTurnoDoContratante` e
`TelaAvaliacao`), permitindo ao contratante responder com Sim ou Não à pergunta objetiva
"Chamaria este profissional de novo?" após o encerramento do turno com presença confirmada.
