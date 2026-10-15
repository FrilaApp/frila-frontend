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
  # antes de rodar, se o projeto ainda não foi gerado nesta pasta/branch:
  Scripts/gerar-projeto.sh  # gera o Frila.xcodeproj via XcodeGen e restaura o Package.resolved versionado

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

São números **de simulador**, de 10, 11 e 15/10/2026, num Mac compartilhado com outros builds.
Nenhum deles vale para os critérios, que pedem um iPhone antigo em 4G. Os de LTE e 3G no
simulador (Network Link Conditioner) estão em "Aberturas contra o frila-dev, com LTE e 3G", no fim
desta seção.

**Aberturas, com o dublê e sem rede** (simulador iPhone 17, iOS 26.5, Debug-Local; coleta pelo
teste `testColetaVinteAberturasDeCadaTela`). Mostram o custo do app e do instrumento, sem espera
por servidor:

| Tela | n | p50 | p95 | máx | Coleta anterior: p95 / máx |
|---|---|---|---|---|---|
| Lista de vagas (puxar para atualizar) | 20 | 1 ms | 1 ms | 1 ms | 2 ms / 2 ms |
| Detalhe da vaga | 21 | 25 ms | 28 ms | 40 ms | 40 ms / 68 ms |
| Meu turno | 20 | 23 ms | 26 ms | 43 ms | 35 ms / 42 ms |

O detalhe tem 21 medições porque a parte de Meu turno abre mais uma vaga para se candidatar.

**Tráfego de rede da sessão com dublê HTTP local**, em 11/10/2026. O teste
`MedicaoDeDesempenhoTests.bytesDaSessaoComHTTPReal` usa o cliente Supabase do app e o
`MedidorDeRede`, com um servidor em `127.0.0.1` que devolve as fixtures do contrato. A sessão
efêmera começa com cache e registro vazios: uma lista, três consultas ao detalhe da mesma vaga
da fixture e uma candidatura confirmada. As cinco rotas são verificadas, e o teste exige bytes
enviados diferentes de zero e bytes recebidos suficientes para os cinco corpos de resposta.

| Sessão | Requisições | Enviados | Recebidos | Total (contador do app) |
|---|---|---|---|---|
| Lista, três detalhes e candidatura (HTTP local) | 5 | 2.595 B | 5.365 B | 7.960 B |

Essa execução passa o limite de menos de 1.000.000 B **para estas fixtures**, pelo contador de
HTTP do app. Não mede TLS, DNS, Firebase, respostas de produção ou tráfego celular. A coleta
anterior, com o dublê em memória (`-FRILA_SCENARIO success`), deu 0 requisições e 0 B; esse zero
não comprova o orçamento de uma sessão pela rede.

Na mesma validação, passaram os 18 testes unitários das suítes `MedicaoDeDesempenhoTests` e
`ModoAviaoMeuTurnoTests` e o teste de interface `ModoAviaoUITests`: após confirmar um turno e
reabrir o app com o dublê sem rede, os dados e o contato permanecem legíveis e o check-in vai
para a fila local. São 19 testes aprovados, sem falhas nem pulos. A prova e o comando ficam em
[`evidencias/desempenho-rede-local`](../../evidencias/desempenho-rede-local).
Em 12/10/2026 (cartão 57hJ7FV0), a suíte `ModoAviaoUITests` foi re-executada e aprovada no
simulador Thor (42,3 s, 0 falhas, log `thor-20261012-201959-35668.log`), confirmando a
persistência offline do turno e enfileiramento do check-in local, e a medição de rede HTTP
(7.960 B total em 5 requisições) foi revalidada em `MedicaoDeDesempenhoTests`.

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

**Aberturas contra o frila-dev, com LTE e 3G** (simulador, 15/10/2026, Debug-Dev sem otimização,
`api=supabase`, conta de demonstração do profissional, `-FRILA_MEDICAO`). Em cada perfil do Network
Link Conditioner, Medições → Zerar e 20 aberturas por tela. O p95 é a 19ª menor medição, como
descrito acima; o máximo é a pior das 20 aberturas (na Lista em LTE, foi a primeira depois do
Zerar). O perfil LTE foi 50 Mbps de descida e 10 Mbps de
subida, com 50 ms e 65 ms de atraso e 0% de perda. O aplicativo não lê o perfil: ele foi conferido
pelo aviso de quem o ligou, e o que o sustenta é a diferença entre as duas colunas.

| Perfil | Tela | Vagas na lista | n | p50 | p95 | máx |
|---|---|---|---|---|---|---|
| LTE | Lista de vagas | 0 (vazia) | 20 | 218 ms | 311 ms | 807 ms |
| LTE | Detalhe da vaga | 1 | 3 | 275 ms | 615 ms | 615 ms |
| LTE | Meu turno | 2 turnos confirmados | 20 | 244 ms | 392 ms | 819 ms |
| 3G | Lista de vagas | 0 (vazia) | 20 | 389 ms | 780 ms | 1028 ms |
| 3G | Detalhe da vaga | sem vaga aberta | 0 | n/a | n/a | n/a |
| 3G | Meu turno | 2 turnos confirmados | 20 | 434 ms | 700 ms | 942 ms |

Nenhum p95 chegou perto de 2000 ms. O p50 usa a medição do meio (a 10ª menor de 20). A linha do
Detalhe em LTE tem três medições e não é um p95 de 20.

| Sessão | Requisições | Enviados | Recebidos | Total (contador do app) |
|---|---|---|---|---|
| LTE: sessão de consulta | 16 | 14.203 B | 15.928 B | 30.131 B |
| 3G: uma Lista e um Meu turno | 4 | 3.554 B | 4.099 B | 7.653 B |
| LTE: folha ao fim das 40 aberturas | 45 | n/d | n/d | 76.776 B |
| 3G: folha ao fim das 40 aberturas | 42 | n/d | n/d | 71.260 B |

As duas primeiras linhas não se comparam entre si: a sessão de LTE foi mais longa. Todas ficam
abaixo de 1.000.000 B (a maior é cerca de 7,7% do limite), pelo contador do app, que não vê TLS,
DNS, Firebase nem tráfego celular.

Limites desta coleta:

- **Lista vazia:** a conta de demonstração do contratante não consegue publicar vaga no frila-dev
  (cartão 266 do backend), então a lista foi medida sem vagas. Isso subestima a lista cheia, e o
  Detalhe em 20 aberturas e a candidatura ficaram sem medir. Repetir depois que o backend semear
  vagas futuras para o estabelecimento de demonstração.
- **Simulador num Mac, Debug sem otimização:** não vale para o critério do iPhone antigo em 4G
  real com o build de medição.
- **Inferência:** de LTE para 3G, o p95 da lista foi de 311 para 780 ms e o de Meu turno de 392
  para 700 ms. O aumento é coerente com o atraso maior do perfil, porque cada tela faz uma a três
  requisições pequenas e o atraso pesa mais que o conteúdo.
- **Assinatura:** compile sem `CODE_SIGNING_ALLOWED=NO`. Sem os direitos embutidos, o Keychain do
  simulador recusa gravar a sessão (erro -34018) e o supabase-swift só registra o erro em log. O
  app segue como anônimo e as respostas vêm vazias, como na CI, que usa a assinatura padrão.
