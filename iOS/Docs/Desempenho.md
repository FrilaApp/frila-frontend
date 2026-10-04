# Desempenho e dados (#73)

Os critérios do #73 (e o p95 em 4G do #171) só se fecham num iPhone antigo com rede real. Este
documento diz o que o app mede, onde a medição existe, como coletar os números no aparelho e o
que já se mediu no simulador.

| Critério | Medida | Onde ler |
|---|---|---|
| Telas principais em menos de 2 s em 4G (p95) | abertura da lista, do detalhe e de Meu turno | botão Medições: n, p50, p95 e máximo por tela |
| Sessão de consulta e candidatura abaixo de 1 MB | bytes enviados e recebidos pelo cliente da API | botão Medições: seção Rede |
| Turno confirmado legível sem rede, com as ações na fila (RNF06) | teste de interface `ModoAviaoUITests` | CI e suíte local (ver "Modo avião") |

## O que é "abrir" uma tela

Abrir é **do toque até o conteúdo da API na tela**:

- **Início:** o `.task` da tela de destino, que o SwiftUI dispara quando ela entra, no começo da
  navegação aberta pelo toque. Na lista, também o gesto de puxar para atualizar.
- **Fim:** a mudança do view model que publica o conteúdo da API. A tela o desenha no quadro
  seguinte.
  Inferência: o que fica de fora é o intervalo entre o toque e o `.task` e o desenho desse último
  quadro, que a 60 Hz dura 16,7 ms (1000 ms / 60).

| Tela | Fim da abertura |
|---|---|
| Lista de vagas | a lista publicada (`EstadoDaLista.carregada`). A busca das funções do filtro, que vem depois, fica de fora. |
| Detalhe da vaga | a vaga publicada (`.carregado`) |
| Meu turno | a carga da API encerrada (contato e responsável local), com o contato na tela |

Regras da conta:

- Erro, falta de rede ou tela que saiu antes do conteúdo não entram na conta.
- O Observation não avisa quando o valor novo é igual ao antigo. Num puxar para atualizar sem
  vaga nova, o fim é o retorno da carga, com a lista na tela.
- **p95 pelo posto mais próximo:** o menor valor com pelo menos 95% das medições iguais ou
  abaixo dele. Com 20 medições, é a 19ª menor; uma única medição lenta não reprova sozinha, duas
  reprovam. O relatório mostra também o p50 e o máximo.
- Cada abertura também vira um intervalo `abertura` do `os_signpost`, no subsistema
  `com.frila.org.app`, categoria `medicao-de-desempenho`, para quem quiser ver no Instruments. A
  mesma categoria recebe no log do sistema uma linha por medição (`abertura tela=… ms=…`,
  `requisicao enviados=… recebidos=…`).

## Dados da sessão

- **Fonte:** as métricas da `URLSession` (`URLSessionTaskMetrics`) de cada requisição do cliente
  da API (PostgREST, Auth e Edge Functions passam pela mesma sessão).
- **Soma:** cabeçalho e corpo, enviados e recebidos, como passaram pela rede; o corpo conta
  comprimido quando veio comprimido. Resposta servida pelo cache HTTP do aparelho não conta.
  Fonte: a documentação da Apple de
  [`countOfResponseBodyBytesReceived`](https://developer.apple.com/documentation/foundation/urlsessiontasktransactionmetrics/countofresponsebodybytesreceived)
  diz que o valor "includes protocol-specific framing, transfer encoding, and content encoding"
  (acesso em 03/10/2026).
- **Zerar:** também esvazia o cache HTTP (`URLCache.shared`), para a sessão começar de cache
  vazio.
- **Fica de fora:**
  - os SDKs do Firebase (Crashlytics e o token de push), que usam conexões próprias;
  - o Apple Maps, que abre por link;
  - o transporte: DNS, a negociação TLS e QUIC de cada conexão nova e os pacotes de controle.
    Os contadores são do cabeçalho e do corpo HTTP. Por isso o total é um **piso** do que passou
    pela antena.
- **O total real** é o contador de dados celulares do app nos Ajustes do iPhone. Segundo o
  [suporte da Apple](https://support.apple.com/pt-br/109323) (acesso em 03/10/2026), o caminho é
  "Abra o app Ajustes. Toque em Celular. [...] Role a tela para baixo para ver quais apps estão
  usando dados celulares", e para zerar: "Toque em Redefinir Estatísticas". Ele soma tudo o que
  o app usou, inclusive o Firebase e o transporte.
- **Medido no simulador:** com poucas requisições, o transporte pesa mais que o conteúdo (ver
  "Números do simulador"). Inferência: o custo de abrir a conexão é fixo, então numa sessão com
  conteúdo de verdade a diferença relativa cai. Só o aparelho diz quanto.

Os registros guardam só o nome da tela, a duração e os bytes: nada da pessoa, da vaga ou do turno.

## Modo avião

`ModoAviaoUITests` confirma um turno com rede (o dublê `success`), fecha o app e o abre de novo
com o dublê `sem-rede`, que recusa toda chamada:

- **Funciona sem rede:**
  - Meus turnos, com o aviso de que a lista veio do cache;
  - o turno aberto;
  - o contato do turno e o botão de abrir conversa no WhatsApp, preservados no cache local (`ArmazenamentoSwiftData`, `ContatoDoTurnoPersistido`) até o prazo de expiração da RN10 (#133);
  - o check-in, que sai manual (sem o ponto da vaga não há distância) e fica na fila, com o aviso
    de que será enviado quando a internet voltar.

## Onde a medição existe

| Build | Medição |
|---|---|
| Debug (esquemas Local e Dev) | compilada e desligada; liga com o argumento de lançamento `-FRILA_MEDICAO` |
| Build de medição (Release-Beta com a condição `FRILA_MEDICAO`) | sempre ligada; só para teste interno no TestFlight |
| Beta e Prod comuns | não existe |

O `conferir-release.sh` reprova qualquer Release sem `FRILA_MEDICAO=1` que tenha a chave
`frila-medicao-de-desempenho` ou os tipos `RegistroDeMedicoes` e `MedidorDeRede`. O autoteste
(`teste-conferir-release.sh`) cobre os dois lados.

## Roteiro do aparelho

**Antes**

1. Mande o build de medição ao TestFlight (seção "Build de medição" abaixo).
2. No iPhone antigo:
   - instale o build pelo TestFlight;
   - desligue o Wi-Fi e deixe os dados móveis em 4G;
   - entre com a conta de teste de profissional do frila-dev.
3. O cronômetro no canto inferior direito abre as Medições. "Copiar relatório" põe o resumo em
   texto na área de transferência.

**Sessão de dados (uma vez)**

1. Medições → Zerar. Isso zera os números e o cache HTTP.
2. Ajustes → Celular → Redefinir Estatísticas.
3. Feche o app pelo seletor de apps e abra de novo.
4. Espere a lista. Abra três vagas, voltando à lista entre uma e outra, e na terceira toque em
   Candidatar-me.
5. Leia os dois números:
   - Medições → o total da seção Rede: o conteúdo da API. Copie o relatório.
   - Ajustes → Celular → o número abaixo do Frila: o total real, com Firebase e transporte.
6. O critério é ficar abaixo de 1 MB. Anote os dois; se só o total real passar de 1 MB, a
   diferença é transporte e SDKs, e não a API.

**Aberturas (20 de cada tela)**

1. Medições → Zerar → Fechar.
2. **Lista:** puxe para atualizar 20 vezes, esperando a lista voltar entre uma e outra.
3. **Detalhe:** abra uma vaga e volte, 20 vezes.
4. **Meu turno:** com um turno confirmado, abra-o em Meus turnos e volte, 20 vezes.
5. Medições → Copiar relatório. O p95 de cada tela tem de ficar abaixo de 2000 ms.

**Registro:** cole os dois relatórios no cartão, com o modelo do iPhone, a versão do iOS, a
operadora e a rede (4G, barras de sinal).

## Build de medição

Em Actions > TestFlight > Run workflow: `main`, `Frila-Beta`, a versão atual, "Build de medição" e
"Enviar ao TestFlight" marcados. O build é o Release-Beta (otimizado, contra o frila-dev) com a
condição `FRILA_MEDICAO`, e vai ao TestFlight só para teste interno (`testFlightInternalTestingOnly`).
Detalhes em [Integração contínua](CI.md), "Build de medição".

O Debug não serve para os números do critério. Inferência: ele compila sem otimização (`-Onone`) e
mediria um app mais lento do que o de verdade.

## Coleta no simulador

- **Aberturas com o dublê:** um teste de interface faz 20 aberturas de cada tela e escreve o
  relatório no registro do teste (linhas `MEDICOES`). Ele fica fora da suíte e só roda com a
  variável de ambiente abaixo (o `xcodebuild` repassa ao teste, sem o prefixo, o que começa com
  `TEST_RUNNER_`):

  ```sh
  TEST_RUNNER_FRILA_COLETAR_MEDICOES=1 xcodebuild test -project Frila.xcodeproj -scheme Frila-Local \
    -destination "id=<UDID do seu simulador>" \
    -only-testing:FrilaUITests/MedicaoUITests/testColetaVinteAberturasDeCadaTela \
    -parallel-testing-enabled NO
  ```

- **Bytes contra o frila-dev:** compile o esquema Frila-Dev para o simulador e abra o app com
  `-FRILA_MEDICAO`, lendo o log da categoria:

  ```sh
  xcrun simctl launch <UDID> com.frila.org.app -FRILA_MEDICAO
  xcrun simctl spawn <UDID> log stream --style compact \
    --predicate 'subsystem == "com.frila.org.app" AND category == "medicao-de-desempenho"'
  ```

## Números do simulador

São números **de simulador**, de 03/10/2026, num Mac compartilhado com outros builds. Nenhum
deles vale para os critérios, que pedem um iPhone antigo em 4G. Os de 4G e 3G no simulador
(Network Link Conditioner) ficam para quando a ferramenta estiver instalada no Mac.

**Aberturas, com o dublê e sem rede** (simulador iPhone 17, iOS 26.5, Debug-Local; coleta pelo
teste `testColetaVinteAberturasDeCadaTela`). Mostram o custo do app e do instrumento, sem espera
por servidor:

| Tela | n | p50 | p95 | máx | Coleta anterior: p95 / máx |
|---|---|---|---|---|---|
| Lista de vagas (puxar para atualizar) | 20 | 1 ms | 2 ms | 2 ms | 1 ms / 2 ms |
| Detalhe da vaga | 21 | 29 ms | 40 ms | 68 ms | 47 ms / 58 ms |
| Meu turno | 20 | 24 ms | 35 ms | 42 ms | 35 ms / 53 ms |

O detalhe tem 21 medições porque a parte de Meu turno abre mais uma vaga para se candidatar.

**Bytes, contra o frila-dev** (simulador, Debug-Dev com `-FRILA_MEDICAO`, abertura do app sem
sessão, até a tela de entrada). O frila-dev ainda não tem todas as migrações (a
`configuracao_do_app` respondeu 404 em 03/10) nem uma conta de teste com entrada automática, então
a sessão do critério (lista, três detalhes e candidatura) não roda nele.

| Abertura | Requisições | Enviados | Recebidos | Total (contador do app) |
|---|---|---|---|---|
| 1ª | 3 | 782 B | 1.810 B | 2.592 B |
| 2ª | 3 | 913 B | 2.355 B | 3.268 B |

Na 2ª abertura, o `nettop` do macOS mediu as conexões do processo do app:

- **com o frila-dev:** 10.901 B recebidos e 6.658 B enviados, 17.559 B no total, por QUIC (UDP
  443). O endereço é o do frila-dev (`dig`), e o `whois` dá Cloudflare, Inc.
- **com o Google:** 19.115 B, que o contador do app não vê (o `whois` dá Google Argentina SRL).
  Inferência: é o Firebase (Crashlytics e Messaging), o único pacote do Google no `project.yml`.

Inferência: para três respostas pequenas, a conexão com o frila-dev levou 5,4 vezes o que o
contador do app somou (17.559 / 3.268); a diferença, 14.291 B, é transporte.
