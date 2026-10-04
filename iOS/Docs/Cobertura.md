# Cobertura de testes onde a regra de negócio mora

Medição de 04/10/2026 sobre o `main` (`f2dd64c`), antes do TestFlight (#203). Pergunta: onde o app
não tem teste para regra que, se quebrar, dá prejuízo a quem usa. Os números vêm do `xccov`
(`xcodebuild test … -enableCodeCoverage YES` do `Frila-Local`, só o alvo `FrilaTests`, no simulador);
são linhas executáveis cobertas, por arquivo, em `Sources/Dominio`, `Sources/Dados` e os
`*ViewModel*.swift` de `Sources/Apresentacao`. Fora da conta: dublês e simulados
(`ApiClienteEmMemoria`, `*Simulado*`, `FixturesDoContrato`, `MedidorDeRede`, `MedicaoDeDesempenho`).

## Antes → depois, por camada

| Camada | Linhas | Antes | Depois |
|---|---|---|---|
| Dominio | 787 | 95,2 % | **97,8 %** |
| Dados | 1 520 | 84,8 % | **96,2 %** |
| ViewModels | 2 536 | 90,3 % | **96,5 %** |

`FrilaTests`: 808 testes em 81 suítes → **884 testes em 92 suítes**, 8 s de execução nos dois casos.
Nenhum arquivo de `Sources/` foi alterado: tudo é teste em `iOS/Tests/Unitarios`.

### Dominio

| Arquivo | Linhas | Antes | Depois |
|---|---|---|---|
| `ExportacaoDeTurnos.swift` | 50 | 92% | 92% |
| `ErrosDaAPI.swift` | 31 | 97% | 97% |
| `Modelos.swift` | 345 | 97% | 97% |
| `ObjetosDeValor.swift` | 92 | 95% | 98% |
| `Cache.swift` | 27 | 81% | 100% |
| `FormatadorFrila.swift` | 53 | 75% | 100% |
| demais 9 arquivos | 189 | 100% | 100% |

### Dados

| Arquivo | Linhas | Antes | Depois |
|---|---|---|---|
| `ExclusaoDeContaDTO.swift` | 18 | 0% | 72% |
| `SupabaseApiCliente.swift` | 563 | 69% | 95% |
| `AparelhoDePush.swift` | 179 | 96% | 96% |
| `SincronizadorAcoes.swift` | 78 | 96% | 96% |
| `DecodificadorErroAPI.swift` | 32 | 97% | 97% |
| `CacheSwiftData.swift` | 166 | 97% | 97% |
| `DTOsContrato.swift` | 394 | 96% | 98% |
| `SaidaDaConta.swift` | 57 | 98% | 98% |
| `TurnosComCache.swift` | 18 | 83% | 100% |
| `ReenvioAoReconectar.swift` | 15 | 100% | 100% |

### ViewModels

| Arquivo | Linhas | Antes | Depois |
|---|---|---|---|
| `ExportarDadosViewModel.swift` | 80 | 85% | 85% |
| `CandidaturaViewModel.swift` | 101 | 82% | 87% |
| `PerfilProfissionalViewModel.swift` | 218 | 83% | 88% |
| `CodigoViewModel.swift` | 129 | 82% | 95% |
| `AcompanhamentoViewModel.swift` | 389 | 96% | 96% |
| `MeusTurnosViewModel.swift` | 26 | 96% | 96% |
| `ContaSuspensaViewModel.swift` | 127 | 84% | 97% |
| `MeuTurnoViewModel.swift` | 214 | 90% | 98% |
| `HistoricoDeTurnosViewModel.swift` | 114 | 89% | 98% |
| `CancelamentoViewModel.swift` | 120 | 89% | 98% |
| `ExclusaoDeContaViewModel.swift` | 172 | 90% | 99% |
| `PresencaDoTurnoViewModel.swift` | 194 | 96% | 99% |
| `AvaliacaoTurnoViewModel.swift` | 278 | 94% | 100% |
| `EntradaViewModel.swift` | 40 | 85% | 100% |
| `CadastroViewModel.swift` | 144 | 83% | 100% |
| `DetalheVagaViewModel`, `FeedVagasViewModel`, `SegurancaViewModel` | 190 | 100% | 100% |

## Os buracos, classificados

(R) regra de negócio ou do contrato, coberta nesta missão; (I) infraestrutura que só roda no
aparelho, anotada; (V) vista pura, anotada (a auditoria de interface já passa por ela).

| Onde (antes) | O que não tinha teste | Classe | Suíte nova |
|---|---|---|---|
| `SupabaseApiCliente` (69 %) | 23 chamadas sem teste de contrato pela rede: `fazer_checkin`/`fazer_checkout` (corpo com `distancia_m` nulo e `registrado_em`), `avaliar`, `avisar_a_caminho`, `contato_do_turno`, `criar_conta` (dados pessoais em E.164 e `aaaa-mm-dd`), `criar_perfil_profissional`, `atualizar_perfil_profissional` (só funções), `meus_turnos`, `vagas_abertas` (sem a posição do aparelho), `detalhe_vaga`, `perfil_publico`, `meus_estabelecimentos`, `painel_estabelecimento`, `republicar_vaga`, `configuracao_do_app`, `excluir-conta` (202, data inválida, 409 `administrador_unico`), `exportar-meus-dados`, `possuiSessao`, `sair` | R | `ContratoDoClienteSupabaseTests` (20) |
| `ExclusaoDeContaDTO` (0 %) | A resposta da exclusão virando domínio e a recusa de `dados_apagados_ate` fora do formato | R | idem |
| `TurnosComCache.meusTurnos` (0 %) | A porta `TurnoRepositorio` que o app usa; cache que recusa gravar; cache vazio sem rede | R | `TurnosComCacheTests` (4) |
| `FormatadorFrila` (75 %) | `janelaParaContrato` (dia 0–6 e `HH:mm`), `hora`, `dataEHora` no fuso de São Paulo | R | `RegrasDeValorTests` (4) |
| `Dinheiro.<`, `TurnoEmCache` | Comparação de centavos e o registro do cache | R | idem |
| `MeuTurnoViewModel` (90 %) | RN10 nas bordas: servidor devolve contato já vencido; sem rede com o guardado vencido; outro erro com o guardado vencido; `contato_expirado`; atalho do mapa; quem recebe | R, **prioridade alta (contato)** | `ContatoDoTurnoNaTelaTests` (7) |
| `CadastroViewModel` (83 %), `CodigoViewModel` (82 %), `EntradaViewModel` (85 %) | Validação de nome, telefone e data; telefone em E.164 (`+55` só com DDD brasileiro); data `aaaa-mm-dd`; erros que não são `ErroDaApi`; 404 e expirado na verificação; destinos contratante e conta suspensa | R, **dados pessoais** | `EntradaECadastroBordasTests` (10) |
| `ContaSuspensaViewModel` (84 %) | Situação que não carrega (sem rede, API, desconhecido); contestação já aberta ao carregar; `campo_invalido`, `campo_obrigatorio`, `sem_rede` ao contestar; `executarSair` | R, **bloqueio** | `ContaSuspensaBordasTests` (5) |
| `ExclusaoDeContaViewModel` (90 %) | `buscarTurnosContratante` com posição sem perfil; cliente sem porta de exclusão; busca injetada; sem confirmar | R | `ExclusaoDeContaBordasTests` (4) |
| `AvaliacaoTurnoViewModel` (94 %) | Sem resposta; `URLError` cru; sem rede sem fila; fila que recusa; 409 com resposta conhecida; `avaliacao_indisponivel`; erro genérico | R | `AvaliacaoBordasTests` (7) |
| `PresencaDoTurnoViewModel` (96 %) | `cancelar` na etapa sem GPS; fila que recusa guardar; sem fila; erro desconhecido | R, **falta** | `PresencaBordasTests` (4) |
| `CancelamentoViewModel` (89 %) | As folhas montadas pela API (`cancelar_posicao` e `cancelar_vaga` com o motivo); erro desconhecido; `id` do motivo | R, **falta/cancelamento** | `CancelamentoPelaApiTests` (4) |
| `CandidaturaViewModel`, `PerfilProfissionalViewModel`, `HistoricoDeTurnosViewModel` | `recomecar` e erro desconhecido; `carregarMeuPerfil`, janelas, erros ao carregar/salvar; 401/403 não repetíveis, erro desconhecido, atividade concluída | R | `TelasDoProfissionalBordasTests` (7) |
| `PerfilProfissionalViewModel.buscarEndereco`, `selecionarSugestao`, `CadastroEstabelecimento` | `MKLocalSearch` e `MKMapItem` do sistema | **I** | — |
| `SupabaseApiCliente.encerramentos()` público, `init` de conveniência com `.shared` | O fluxo de `authStateChanges` do SDK e a `URLSession` real; a variante interna é testada em `EncerramentoDeSessaoTests` | **I** | — |
| `AparelhoDePush`, `SincronizadorAcoes`, `CanalDePushDoAparelho` | APNs, FCM e `UNUserNotificationCenter` reais; a regra está coberta pelos dublês | **I** | — |
| `ExportarDadosViewModel.itemCompartilhamento`, `ItemCompartilhamento` | Só embrulha a URL para a `UIActivityViewController` | **V** | — |
| Closures de argumento padrão (`AcompanhamentoViewModel`, `ContaSuspensaViewModel`, `CancelamentoViewModel`), `implicit closure` de `??` e `hash(into:)` | Não há regra: são o valor padrão de um parâmetro que todo teste injeta | — | — |

Nenhum (R) de prioridade alta (contato, dinheiro, falta, bloqueio, dados pessoais) ficou sem teste.

## Defeitos achados pelos testes novos

Nenhum. Todas as falhas durante a escrita foram do próprio teste (nome de RPC, cenário do dublê,
UUID em maiúsculas no corpo). Nenhum `withKnownIssue` foi necessário.

Dois comportamentos que valem registro, sem serem defeito:

- `CadastroViewModel.normalizarTelefone`: 10 ou 11 dígitos sem `+` ganham `+55`; um número
  estrangeiro digitado sem `+` e com 11 dígitos (ex.: `1 415 555 2671`) vira `+5514155552671`. É a
  regra desenhada para o DDD brasileiro; o teste a documenta.
- `Foundation` codifica `UUID` em maiúsculas no JSON (`chave`, `vaga_id`); o Postgres aceita os
  dois. Os testes de contrato comparam sem distinguir caixa.

## Suíte completa e estabilidade

- As 11 suítes novas rodaram 3 vezes seguidas (`test-without-building`): 76 testes verdes nas três,
  0,2–0,3 s cada.
- `Frila-Local` completa, no simulador, em 04/10/2026 (01:12–01:53): `FrilaTests` 884 testes verdes;
  `FrilaUITests` 204 testes, 30 pulados, 1 falha que não é desta missão:
  `AcessibilidadeDoContratanteUITests.testPublicarVagaAlvosNoTamanhoPadrao` (#110) comparava
  `frame.height` (`43,999999…`) com `44` sem tolerância. Corrigido aqui com `44 - 0.01`, só nessa
  linha; as outras 26 asserções iguais em `Tests/UI` não falharam nesta rodada, mas têm a mesma
  exposição e valem uma passada de quem cuida da auditoria de acessibilidade.

## Cobertura na CI

A instrumentação não pesa: os mesmos 808 testes rodaram em 8,3 s com `-enableCodeCoverage YES` e
em 4–8 s sem (medições desta sessão, simulador local sob carga de outros builds; o custo fica na
compilação e no `.xcresult`, ~100 MB). Proposta, sem mexer no workflow agora: ligar
`-enableCodeCoverage YES` no passo `test-without-building` do `Frila-Local` e publicar o
`xccov view --report` como artefato, para o número desta tabela sair a cada PR em vez de uma vez.

## Como repetir

```sh
cd iOS
xcodebuild test -project Frila.xcodeproj -scheme Frila-Local \
  -destination 'platform=iOS Simulator,id=<UDID>' -only-testing:FrilaTests \
  -enableCodeCoverage YES -resultBundlePath /tmp/cobertura.xcresult
xcrun xccov view --report --json /tmp/cobertura.xcresult > /tmp/cobertura.json
# por arquivo, com as linhas sem cobertura:
xcrun xccov view --archive --file "$PWD/Sources/Dados/TurnosComCache.swift" /tmp/cobertura.xcresult
```
