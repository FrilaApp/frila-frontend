# Robustez contra crash antes do TestFlight

Auditoria de `iOS/Sources` (as cinco camadas e a extensão de notificação) feita em 04/10/2026, a
partir de `origin/main` (`d64b367`), à procura do que derruba o app com dado real do servidor, rede
ruim ou uso fora do roteiro, que os testes com o dublê não pegam. O contrato espelhado é o 0.2.34.

Gravidade: **derruba** fecha o app; **trava** deixa a pessoa sem sair de uma tela; **errado** mostra
estado ou mensagem incorreta sem fechar nem travar. Situação: **corrigido** neste PR, **pendente**
(arquivo tocado por PR aberto; só relatório) ou **ok** (conferido, sem defeito).

## Resumo

- Nenhum achado **derruba** com dado de fora. Toda força (`!`, `precondition`, `try!`) em
  `Sources` está em literal, em código só de Debug ou atrás de uma guarda que recusa o valor antes
  (tabela "Forças" abaixo).
- Dois achados **trava**, os dois de rede ruim na abertura: o portão de atualização (corrigido) e a
  avaliação da sessão (pendente, `FrilaApp.swift` é do #103).
- Achados **errado**: só `notConnectedToInternet` virava `semRede`, então rede ruim não caía no
  cache nem no destino guardado (corrigido); enum novo do contrato recusava a resposta inteira na
  maioria dos campos (corrigido); um registro ilegível no SwiftData inutiliza o cache ou a fila
  inteira (pendente, #103).
- Concorrência: o projeto já compila em Swift 6 com `SWIFT_STRICT_CONCURRENCY: complete`
  (`project.yml:33-34`); o build de `Frila-Local` tem zero avisos em `Sources` (os 17 avisos são
  dos alvos de teste). Nenhum `Task.detached`, nenhum `unowned`, nenhum observador de
  `NotificationCenter`; todos os view models são `@MainActor @Observable`.
- Tamanho e texto: cartões de vaga, turno e candidatura renderizam com texto de 2.000 caracteres,
  emoji composto, escrita RTL e nome vazio (teste novo); as listas de vagas e de turnos são
  `LazyVStack`, e a de vagas é paginada em 30.

## Achados

| # | Achado | Onde | Como dispara | Gravidade | Situação |
|---|---|---|---|---|---|
| 1 | O portão de atualização espera `configuracao_do_app` sem prazo. Sem rede o erro chega na hora, mas com rede ruim (pacote perdido, Wi‑Fi cativo) a `URLSession` só desiste aos 60 s, e até lá a abertura inteira é o indicador de carregamento. | `Apresentacao/AtualizacaoObrigatoria.swift:31-50` (antes: `verificar()` sem prazo) | Abrir o app com Wi‑Fi conectado mas sem saída para a internet. | trava | **corrigido**: prazo de 3 s libera o app; resposta tardia que bloqueia ainda bloqueia. Testes em `AtualizacaoObrigatoriaTests.swift` (`prazoLibera` e `respostaAtrasadaBloqueia` falham sem a correção). |
| 2 | A avaliação da sessão na abertura (`possuiSessao`, `minha_conta`, `situacao_da_conta`, `meu_perfil_profissional`) roda em série e sem prazo, com `carregandoDestino = true`. Com rede ruim são até quatro esperas de 60 s no indicador. | `App/FrilaApp.swift:653-677`; `Autenticacao/DestinoAposEntrada.swift:35-56` | Mesmo cenário do #1, depois do portão. | trava | **pendente** (`FrilaApp.swift` é do #103). Sugestão: prazo curto como no #1 e, vencido, cair no destino guardado quando houver. |
| 3 | Só `URLError.notConnectedToInternet` virava `semRede`; `timedOut`, `networkConnectionLost`, `cannotFindHost`, `cannotConnectToHost`, `dnsLookupFailed`, `dataNotAllowed` e `internationalRoamingOff` viravam `desconhecido`. Como só `semRede` abre o cache (`TurnosComCache.swift:29`), o destino guardado (`DestinoAposEntrada.swift:78`) e para a fila (`SincronizadorAcoes.swift:60`), quem estava em rede ruim via erro genérico em vez de Meus turnos do cache e da tela inicial guardada, e a fila tentava cada ação até estourar o tempo de cada uma. | `Dados/SupabaseApiCliente.swift` (`codigosDeRedeIndisponivel`, usado em `mapear`) | 3G fraco, Wi‑Fi cativo, túnel. | errado | **corrigido**: os oito códigos de rede indisponível da `URLSession` viram `semRede`; falha de TLS continua `desconhecido` (não é falta de rede, e escondê-la atrás do cache mascararia um problema real). Teste `RedeRuimEValorNovoTests.redeRuimEhSemRede` (8 códigos) e `tlsNaoEhSemRede`, pela `URLSession` de verdade com um `URLProtocol` que falha. |
| 4 | Um registro que não decodifica em `TurnoPersistido`, `FuncaoPersistida` ou `AcaoPendentePersistida` faz `turnosValidos`, `funcoes` e `pendentes` lançarem, e o cache ou a fila inteira deixam de funcionar até a saída da conta (`limpar`). Turno gravado por um build anterior fica no banco até 24 h depois do fim mesmo que o servidor não o devolva mais (`salvar(turnos:)` só faz upsert), então um campo novo obrigatório no `Codable` de `Turno`, `VagaResumo`, `PerfilPublico` ou `Reputacao` quebra o modo avião depois da atualização. Hoje o `Codable` desses tipos é tolerante ao que já mudou (`VagaResumo`, `Modelos.swift:379-391`; opcionais novos em `Turno`); o risco é a próxima mudança. A fila é pior: a ação que não decodifica trava as outras e nunca sai. | `Dados/CacheSwiftData.swift:123-133,151-156,184-189` | Atualizar o app com cache/fila gravados por um build anterior cujo modelo mudou. | trava (fila) / errado (cache) | **pendente** (`CacheSwiftData.swift` é do #103). Sugestão: decodificar registro a registro (`compactMap`) e apagar o que não decodifica. |
| 5 | Enum novo do contrato recusava a resposta inteira na maioria dos campos (`DecodingError` → `respostaInvalida`): `verificacao`, `contraparte.tipo`, `estado` e `modo` da vaga, `estado` da posição no painel, `estado` da candidatura, `perfil` e `estado` do usuário, `estado` da situação da conta, `tipo` do protocolo, `tipo` e `verificacao` do registro, `papel` e `tipo` do estabelecimento. Em `minha_conta` e `situacao_da_conta` isso vira a tela de erro na abertura. Já eram tolerantes: `estado` do turno, `checkin_tipo` do painel, `causa` do cancelamento (vira `outro`), campo a mais e `tipo` de push desconhecido. | `Dados/DTOsContrato.swift` (`ItemTolerante`, `PainelDTO`, `VagaNoPainelDTO`, `TurnoDTO.checkinTipo`), `Dados/SupabaseApiCliente.swift` (`lista`), `Dominio/Modelos.swift` (`init(from:)` de `Verificacao`, `TipoRegistro`, `TipoEstabelecimento`, `PapelMembro`, `TipoDeProtocolo`) | Backend publicar um valor novo de enum antes do app. | errado | **corrigido** em três regras: (a) enum com caso neutro cai nele, sempre no que menos promete: `Verificacao` → `pendente`, `TipoRegistro` → `manual`, `TipoEstabelecimento` → `outro`, `PapelMembro` → `operador`, `TipoDeProtocolo` → `denuncia` (informativo); `checkin_tipo` novo no turno fica sem valor, como no painel; (b) em lista (`meus_turnos`, `vagas_abertas`, `minhas_candidaturas`, `candidatos_da_vaga`, `meus_estabelecimentos`, vagas e posições do painel), o item com enum sem caso neutro ou com valor fora do domínio sai e os outros seguem, com a rota e a quantidade no log; (c) resposta única com `perfil` ou `estado` da conta novo continua `respostaInvalida`: o app não escolhe fluxo nem presume conta ativa, e `configuracao_do_app` pode pedir a atualização. `detalhe_vaga` e `perfil_publico` com enum novo também continuam `respostaInvalida` (resposta única). Testes: `RedeRuimEValorNovoTests` (pela rede) e `ValorNovoDoContratoTests` (DTO). |
| 6 | `Minhas vagas` desenhava o painel de ±365 dias num `VStack` dentro de `ScrollView` (não lazy): com centenas de vagas, cada abertura construía todos os cartões. | `Contratante/MinhasVagas.swift:297-310` | Casa com muitas vagas no ano. | errado (desempenho) | **corrigido**: `LazyVStack` por seção no PR #127. |

## Forças, `precondition` e índices: conferidos um a um

| Onde | O que | Por que não dispara com dado de fora |
|---|---|---|
| `Dominio/ObjetosDeValor.swift:7` | `precondition(centavos >= 0)` em `Dinheiro` | O `Codable` sintetizado não passa pelo `init`; a API passa por `ContratoAPI.dinheiro` (`DTOsContrato.swift:310-313`), que recusa `< 1` como `ErroDeConversao`; a publicação usa `Int(filter(isNumber)) ?? 0` (`PublicarVaga.swift:152`), nunca negativo. Teste existente: `ContratoTests` "Centavos fora do contrato". |
| `Dominio/ObjetosDeValor.swift:145` | `precondition((0...6).contains(diaDaSemana))` | `JanelaDTO.dominio()` recusa antes (`DTOsContrato.swift:132`); `adicionarJanela` também (`PerfilProfissionalViewModel.swift:122`). |
| `Dominio/ObjetosDeValor.swift:83-86,122-123` | `partes[0]`, `partes[1]` em `HoraDoDia` e `DataCivil` | Guardados por `partes.count`. |
| `App/ConfiguracaoAmbiente.swift:160` | `partes[1]` do JWT | Guardado por `partes.count == 3`; chave de build, não dado de fora. |
| `Autenticacao/CadastroViewModel.swift:145-155` | `partesBarra[0..1]`, `partesTraco[0..2]` | Guardados por `count`. |
| `Autenticacao/TelaCodigo.swift:152` | `index(startIndex, offsetBy:)` | Guardado por `indice < codigo.count`; o código só tem dígitos. |
| `Dominio/MedicaoDeDesempenho.swift:104-105` | índice do percentil | `guard !valores.isEmpty` e `max(posto, 1) - 1`. Só medição. |
| `Dados/DTOsContrato.swift:569` | `ChaveDinamica(stringValue:)!` | O `init?` nunca devolve `nil`. |
| `Apresentacao/EnderecosOficiais.swift:20-21`, `Confianca/AcoesDeSeguranca.swift:82-83`, `App/ConfiguracaoAmbiente.swift:109` | `URL(string:)!` | Literais válidos. |
| `Dominio/FormatadorFrila.swift:5` | `TimeZone(identifier: "America/Sao_Paulo")!` | Identificador do sistema, sempre presente. `dias[indice]` (`:57`) recebe `weekday` 1…7 do calendário gregoriano. |
| `Dados/ApiClienteEmMemoria.swift:542,1883` e `vagas[0]` | `preconditionFailure`, `try!`, índices | Dublê, só em `DEBUG`; fixture validada pela CI; `DataCivil("2026-10-16")` literal; `vagas[0]` depois de `guard let vaga = vagas.first`. |
| `Apresentacao/CatalogoDesignSystem.swift:36,72`, `App/FalhaDoEnsaio.swift:11` | `fatalError`, `preconditionFailure` | Botões de teste do Crashlytics (catálogo Debug e `FRILA_ENSAIO_FALHA`), de propósito. |
| `Infraestrutura/TelemetriaCrashlytics.swift:44` | `Crashlytics.crashlytics()` sem Firebase configurado (Local em modo `supabase`, ou build sem plist) | Conferido no fonte do SDK 12.19.2 (`FIRCrashlytics.m:269-283`, `FIRComponentType.m:23-27`): devolve `nil` e registra erro no log; a chamada vira no-op. |
| Divisão por zero, `Int(Double)`, `Dictionary(uniqueKeysWithValues:)`, `removeFirst/removeLast` sem guarda, `as!`, `unowned` | — | Não há ocorrência em `Sources` fora do dublê. `Int(ceil(...))` em `MinhasVagas.swift:218` e `Int(floor(...))` em `TextosDoCancelamento.swift:74` recebem intervalos de `Date`, finitos. |

## Concorrência

- Swift 6 e `-strict-concurrency=complete` já são o padrão do projeto (`project.yml:33-34`), então
  o que seria aviso é erro de compilação; o build de `Frila-Local` (04/10, `build-base.log`) tem 0
  avisos em `Sources` e 17 nos testes (`CatalogoStringsTests.swift:469-470`,
  `TurnoContrato0231Tests.swift:212`, `AcessibilidadeDoCatalogoUITests.swift:11-17`,
  `AjudanteDeLancamentoUITests.swift:20-22`, `AuditoriaDeAcessibilidadeUITests.swift:49-62`), todos
  de isolamento ao ator principal em código de teste.
- View models e roteadores: 36 classes, todas `@MainActor @Observable` (as outras três classes de
  `Apresentacao` são o marcador do bundle e dois armazenamentos `@unchecked Sendable` sobre
  `UserDefaults`/lock). Infraestrutura com callbacks do sistema
  (`LeitorDeLocalizacaoDoSistema`, `CanalDePushDoAparelho`, `AppDelegate`) pula para o ator
  principal antes de mexer em estado.
- Continuations: `LeitorDeLocalizacaoDoSistema.concluir` só retoma quando `leitura != nil` e a zera
  antes (sem retomada dupla); `AsyncStream` de vínculo, sessão e conexão têm `onTermination`.
- `Task` sem cancelamento em tela que some: os `.task` do SwiftUI cancelam sozinhos; os `Task {}` de
  botão continuam e só escrevem em view model `@MainActor` (sem corrida). O temporizador do código
  (`CodigoViewModel.swift:40`) usa `[weak self]` e é cancelado ao reiniciar.
- `@unchecked Sendable`: `SupabaseApiCliente` (só `let`), `CanalDePushDoAparelho`
  (`OSAllocatedUnfairLock`), `RegistroDeMedicoes` (lock), `UserDefaultsArmazenamentoAvaliacoes`
  (`UserDefaults` é thread-safe), dublês de teste.

## Ciclos de retenção

- Closures guardadas em view model (`aoAvaliar`, `aoEnfileirar`, `aoConcluir`) capturam
  `[weak self]` (`MeuTurnoViewModel.swift:119-134`, `AcompanhamentoViewModel.swift:315,327`).
- Nenhum observador de `NotificationCenter`; o push usa o delegate do `UNUserNotificationCenter`.
- `AparelhoDePush.mudancasDoVinculo` remove a continuation no `onTermination` (`[weak self]`).

## Decodificação

- Formatos de instante do Postgres (`Z`, `+00:00`, `-03:00`, 1 a 6 casas de fração) passam no
  `ContratoAPI.instante` (conferido com script local, 8 variantes).
- Campo a mais em qualquer nível: ignorado (teste `campoAMais`).
- Enum novo: ver achado #5, `ValorNovoDoContratoTests` e `RedeRuimEValorNovoTests`.
- `whatsapp_url` vazio no contato recusa o item (`URL` do `Decodable` não aceita `""`): o contrato o
  declara `format: uri`, e a fixture segue; numa lista o item sai, como no achado #5.
- Cache e Keychain: `ArmazenamentoDoAparelhoNoKeychain.ler` e `VinculoNoGrupoDoApp.ler` devolvem
  `nil` em dado ilegível; `DestinoGuardado.obter` idem. O SwiftData é o achado #4.

## Tamanho e texto

- `CartoesComDadoExtremoTests` renderiza (`ImageRenderer`) `CartaoVaga`, `CartaoMeuTurno`,
  `CartaoDaCandidatura`, `SeloReputacao` e `AvisoFrila` com texto de 2.000 caracteres, emoji
  composto (ZWJ e tom de pele), árabe e hebraico (RTL), nome vazio, reputação com `positivas > total`,
  `taxaComparecimento` negativa e `NaN`, `Int.max`, distância infinita: tudo renderiza.
- Listas: vagas e turnos em `LazyVStack`; vagas paginadas em 30 (`FeedVagasViewModel.swift:81`),
  com dedupe por `Set` (linear). `Minhas vagas` é o achado #6.

## Como foi testado

- `xcodebuild test -scheme Frila-Local` completo no simulador Capitã Marvel (resultado no PR).
- `xcodebuild build -scheme Frila-Beta -destination 'generic/platform=iOS Simulator'`.
- `Scripts/conferir-release.sh` e `Scripts/conferir-textos.sh`.
- Experimento (não versionado) de decodificação com 29 mutações das fixtures, que deu origem ao
  achado #5 e ao teste `ValorNovoDoContratoTests`.
