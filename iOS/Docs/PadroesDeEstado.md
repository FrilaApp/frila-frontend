# Padrões de Estado (Cartão nliiRfQg)

Este documento especifica os padrões de interface e de experiência para os estados de tela do Frila no iOS (`frila-frontend`): carregando, vazio, erro, sem rede, sem permissão e sucesso. O objetivo é unificar o comportamento entre os perfis de profissional e contratante, garantindo acessibilidade, clareza e conformidade com os requisitos de operação sem conexão (RNF06 e RNF09).

---

## 1. Diretrizes Gerais de Estado

1. **Informação multissensorial:** Nenhum estado utiliza exclusivamente cor para transmitir status. Todo estado combina ícone SF Symbol, texto descritivo e, quando aplicável, anúncio semântico para o VoiceOver (`AnunciarAoAparecer`).
2. **Acessibilidade e Dynamic Type:** Todos os componentes de estado respondem ao Dynamic Type, redimensionando textos e adaptando layouts para empilhamento vertical nos tamanhos de acessibilidade (`dynamicTypeSize.isAccessibilitySize`).
3. **Área interativa mínima:** Qualquer botão de ação ou retentativa associado a um estado respeita a dimensão mínima de toque de **44 × 44 pt** (`FrilaMetrica.alvoMinimo`).
4. **Vocabulário controlado:** Todos os textos seguem estritamente o glossário oficial de requisitos (vaga, posição, turno, comparecimento, check-in, check-out, contratante, profissional, equipe de confiança).

---

## 2. Especificação por Estado

### 2.1 Carregando (`carregando`)

Indica processamento assíncrono em andamento (leitura de rede, gravação de dados ou consulta a sensores).

- **Padrão Visual:**
  - *Tela inteira / Lista:* Componente `EstadoCarregando` (`EstadosDeTela.swift:31–37`). Layout vertical centralizado (`VStack`) com espaçamento médio (16 pt), `ProgressView()` giratório nativo e `Text("Carregando…")` em cor secundária (`FrilaCor.textoSecundario`). O bloco tem `frame(maxWidth: .infinity, minHeight: 160)` e agrupa filhos para acessibilidade (`.accessibilityElement(children: .combine)`).
  - *Botão:* `BotaoPrimario` com parâmetro `carregando: true` (`Componentes.swift:23–38`). O texto do botão é temporariamente ocultado e substituído por `ProgressView().tint(FrilaCor.sobrePrimaria)`. O botão tem altura mínima de 44 pt, fundo primário, estado desativado (`.disabled(carregando)`) e anuncia valor de acessibilidade `"Carregando"` ao leitor de tela.
  - *Linha / Processamento inline:* `HStack` horizontal compacto com `ProgressView()` e legenda em estilo subheadline (`SecaoDePresenca.swift:116–124`, chamado em `75, 77`).
- **Texto-base:**
  - Tela/Lista: `"Carregando…"` (`EstadosDeTela.swift:34`).
  - Botão: Rótulo original mantido no `.accessibilityLabel` + valor `"Carregando"` no `.accessibilityValue` (`Componentes.swift:37–38`).
  - Inline: `"Lendo sua localização…"`, `"Enviando…"` (`TextosDaPresenca.swift:22–23`).
- **Ação:**
  - Passivo: Nenhuma ação interativa direta durante a carga de tela.
  - No botão: O toque é bloqueado para prevenir requisições concorrentes ou duplicadas.
- **Onde o app já usa (arquivo:linha):**
  - `iOS/Sources/Apresentacao/EstadosDeTela.swift:31`: Definição de `EstadoCarregando`.
  - `iOS/Sources/Apresentacao/Componentes.swift:24`: Indicador de progresso no `BotaoPrimario`.
  - `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaVagas.swift:108`: Carga do feed de vagas no DF.
  - `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeusTurnos.swift:90`: Carga da lista de turnos do profissional.
  - `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaDetalheVaga.swift:76`: Carga dos detalhes de uma vaga.
  - `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaPerfilProfissional.swift:34`: Carga dos dados e funções do perfil.
  - `iOS/Sources/Apresentacao/Fluxos/Profissional/CandidaturaEmSelecao.swift:475`: Carga das candidaturas no modo seleção.
  - `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:75, 77`: Carga de leitura de GPS e envio de presença.
  - `iOS/Sources/Apresentacao/Fluxos/Contratante/MinhasVagas.swift:301, 515`: Carga inicial e detalhe da vaga em Minhas Vagas.
  - `iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:133`: Carga do acompanhamento de turno.
  - `iOS/Sources/Apresentacao/Fluxos/Contratante/CandidatosDaVaga.swift:465`: Carga dos candidatos inscritos.
  - `iOS/Sources/Apresentacao/Fluxos/Equipe/TelaEquipeDeConfianca.swift:65`: Carga da equipe de confiança.
  - `iOS/Sources/Apresentacao/Fluxos/Push/DestinosDoAviso.swift:93, 244`: Resolução de destino de push.
  - `iOS/Sources/Apresentacao/Fluxos/Autenticacao/FluxoDeEntrada.swift:60, 75`: Resolução inicial de sessão.
  - `iOS/Sources/Apresentacao/AtualizacaoObrigatoria.swift:95`: Verificação de atualização obrigatória.

---

### 2.2 Vazio (`vazio`)

Indica ausência de registros ou resultados após uma busca, filtro ou listagem inicial.

- **Padrão Visual:**
  - *Padrão de Lista / Tela:* Componente `EstadoVazio` (`EstadosDeTela.swift:12–29`), estruturado através de `MensagemDeEstado` (`EstadosDeTela.swift:82–96`). Exibe ícone SF Symbol `"tray"` em tamanho `.largeTitle` na cor `FrilaCor.textoSecundario`, título em fonte `.headline` (negrito), e mensagem detalhada em fonte `.body` na cor `FrilaCor.textoSecundario` com alinhamento centralizado. O container possui altura mínima de 160 pt.
  - *Variante em Cartão:* Cartão Frila elevado (`.cartaoFrila()`) com preenchimento interno, texto do título em `.title3.bold()` e corpo em `.body` secundário alinhado à esquerda (`MinhasVagas.swift:303–311`).
- **Texto-base:**
  - Feed de Vagas: Título `"Nenhuma vaga aberta"`, Mensagem `"Mude os filtros ou puxe para atualizar."` (`TextosDoProfissional.swift:19–20`).
  - Meus Turnos: Título `"Nenhum turno confirmado"`, Mensagem `"Quando você tiver turnos confirmados, eles aparecerão aqui."` (`TextosDoProfissional.swift:111–112`).
  - Candidaturas em Seleção: Título `"Nenhuma candidatura"`, Mensagem `"As vagas a que você se candidatar aparecem aqui."` (`CandidaturaEmSelecao.swift:37–38`).
  - Candidatos da Vaga: Título `"Ninguém se candidatou ainda"`, Mensagem `"Os candidatos aparecem aqui assim que se candidatarem."` (`CandidatosDaVaga.swift:12–13`).
  - Minhas Vagas: Título `"Suas vagas aparecem aqui"`, Mensagem `"Publique sua primeira vaga para acompanhar posições abertas, confirmações e alertas."` (`MinhasVagas.swift:14–15`).
  - Equipe de Confiança: Título `"Ninguém na equipe ainda"`, Mensagem `"Inclua um profissional a partir de um turno que ele já cumpriu aqui."` (`TextosEquipeDeConfianca.swift:7–8`).
- **Ação:**
  - Nas listas de consumo (Vagas, Turnos, Candidatos): Atualização via gesto de arrastar para baixo (*pull-to-refresh*).
  - Em Minhas Vagas: Ação primária imediata via `BotaoPrimario("Publicar vaga")` fixo acima da área de conteúdo (`MinhasVagas.swift:283`).
- **Onde o app já usa (arquivo:linha):**
  - `iOS/Sources/Apresentacao/EstadosDeTela.swift:12`: Definição de `EstadoVazio`.
  - `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaVagas.swift:110–112`: Feed de vagas vazio.
  - `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeusTurnos.swift:93–97`: Lista de turnos do profissional vazia.
  - `iOS/Sources/Apresentacao/Fluxos/Profissional/CandidaturaEmSelecao.swift:482`: Candidaturas vazias.
  - `iOS/Sources/Apresentacao/Fluxos/Contratante/CandidatosDaVaga.swift:475`: Lista de candidatos vazia.
  - `iOS/Sources/Apresentacao/Fluxos/Equipe/TelaEquipeDeConfianca.swift:67`: Lista de equipe de confiança vazia.
  - `iOS/Sources/Apresentacao/Fluxos/Perfil/TelaPorQueReceboVagas.swift:49`: Lista de histórico de critérios vazia.

---

### 2.3 Erro (`erro`)

Comunica falha de operação, recusa de regra de negócio pelo servidor ou erro inesperado de sistema.

- **Padrão Visual:**
  - *Tela Inteira:* Componente `EstadoErro` (`EstadosDeTela.swift:40–69`). Ícone SF Symbol `"exclamationmark.triangle"` em tamanho `.largeTitle` (`FrilaCor.textoSecundario`), título fixo `"Algo deu errado"` em `.headline`, mensagem explicativa em `.body` secundário e botão `BotaoPrimario("Tentar novamente", acao: tentarNovamente)` com altura mínima de 44 pt. Emite anúncio semântico via `AnunciarAoAparecer(tom: .erro)`.
  - *Faixa / Banner:* Componente `AvisoFrila(tom: .erro)` (`Componentes.swift:215–280`). Faixa com fundo preenchido na cor `FrilaCor.perigo` com 12% de opacidade, bordas arredondadas (raio 12 pt), texto em estilo `.callout`, ícone `"xmark.octagon.fill"` e prefixo de acessibilidade `"Erro: "`.
- **Texto-base:**
  - Título fixo de tela: `"Algo deu errado"` (`EstadosDeTela.swift:60`).
  - Botão de retry: `"Tentar novamente"` (`EstadosDeTela.swift:65`).
  - Falha genérica de feed: `"Não foi possível carregar as vagas."` (`TextosDoProfissional.swift:21`).
  - Falha ao carregar vagas (Contratante): `"Não foi possível carregar suas vagas. Tente novamente."` (`MinhasVagas.swift:17`).
  - Falha ao carregar turno (Contratante): `"Não foi possível carregar o turno. Tente novamente."` (`TelaTurnoDoContratante.swift:30`).
  - Falha de turno em push: `"Não foi possível abrir este turno."` (`TextosDoPush.swift:71`).
  - Falha de presença no turno: Mensagens de recusa da API repassadas via `AvisoFrila(tom: .erro)`.
- **Ação:**
  - Retentativa explícita: `BotaoSecundario("Tentar novamente")` disparando nova tentativa assíncrona.
  - Fechamento/Descarte: Banners contextuais podem incluir botão secundário de dispensa.
- **Onde o app já usa (arquivo:linha):**
  - `iOS/Sources/Apresentacao/EstadosDeTela.swift:40`: Definição de `EstadoErro`.
  - `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaVagas.swift:132, 138`: Erro sem ponto de referência e erro geral no feed.
  - `iOS/Sources/Apresentacao/Fluxos/Equipe/TelaEquipeDeConfianca.swift:70, 73`: Falha de carregamento da equipe.
  - `iOS/Sources/Apresentacao/Fluxos/Push/DestinosDoAviso.swift:259`: Falha ao carregar turno vindo de push.
  - `iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:405, 530`: Falha de ação no acompanhamento e avaliação.
  - `iOS/Sources/Apresentacao/Fluxos/Contratante/MinhasVagas.swift:291, 502, 717`: Falhas de carregamento e ações.
  - `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:35`: Mensagem de erro no registro de presença.
  - `iOS/Sources/Apresentacao/Fluxos/Autenticacao/TelaEntrada.swift:48`, `TelaCodigo.swift:99`, `TelaCadastro.swift:166`: Banners de erro na autenticação.
  - `iOS/Sources/Apresentacao/Fluxos/Conta/TelaContaSuspensa.swift:107`: Falha no envio de contestação.

---

### 2.4 Sem Rede / Offline (`sem rede`)

Atende ao RNF06 e RNF09, garantindo leitura de dados em cache (modo avião) e feedback imediato de ações retidas na fila local.

- **Padrão Visual:**
  - *Banner Offline Informativo:* Componente `EstadoOffline` (`EstadosDeTela.swift:71–74`). Implementado com `AvisoFrila(tom: .alerta)`, ícone `"exclamationmark.triangle.fill"`, cor `FrilaCor.alerta` (amarelo) e fundo com 12% de opacidade.
  - *Banner com Retentativa:* `VStack` com `AvisoFrila(tom: .alerta)` seguido de `BotaoSecundario("Tentar novamente")` (`TelaVagas.swift:125–129`).
  - *Estado Pendente / Fila Local:* Componente `EstadoPendente` (`EstadosDeTela.swift:76–80`). Implementado com `AvisoFrila(tom: .informativo)`, ícone `"info.circle.fill"`.
  - *Feedback de Presença Offline:* Texto detalhado na seção de presença informando que o check-in/check-out foi salvo localmente com o horário exato do toque (`SecaoDePresenca.swift:28–33`).
- **Texto-base:**
  - Padrão geral de dados salvos: `"Sem conexão. Mostrando os dados salvos neste aparelho."` (`EstadosDeTela.swift:73`).
  - Feed de vagas sem conexão: `"Sem conexão. Tente de novo quando a internet voltar."` (`TextosDoProfissional.swift:24`).
  - Check-in salvo offline na fila (RNF06): `"Sem conexão. O check-in das \(hora) está guardado neste aparelho e será enviado quando a internet voltar, com esse horário."` (`TextosDaPresenca.swift:55`).
  - Check-in manual salvo offline: `"Sem conexão. O check-in manual das \(hora) está guardado neste aparelho e será enviado quando a internet voltar, com esse horário. Depois ele aguarda a confirmação do contratante."` (`TextosDaPresenca.swift:54`).
  - Check-out salvo offline: `"Sem conexão. O check-out das \(hora) está guardado neste aparelho e será enviado quando a internet voltar, com esse horário."` (`TextosDaPresenca.swift:62`).
  - Cancelamento na fila: `"Sem conexão. O cancelamento será enviado quando a internet voltar."` (`TextosDoCancelamento.swift:43`, exibido em `TelaMeuTurno.swift:36`).
  - Cache desatualizado (Contratante): `"Não foi possível atualizar. O que aparece aqui pode estar desatualizado."` (`TelaTurnoDoContratante.swift:28`).
- **Ação:**
  - Enfileiramento automático: A ação é persistida localmente (Keychain/SQLite/fila offline) e a interface libera o fluxo na hora.
  - Retentativa manual: Botão `"Tentar novamente"` para forçar reconexão.
- **Onde o app já usa (arquivo:linha):**
  - `iOS/Sources/Apresentacao/EstadosDeTela.swift:71, 76`: Definições de `EstadoOffline` e `EstadoPendente`.
  - `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaVagas.swift:126–129`: Feed de vagas sem conexão.
  - `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:151, 169` (textos em `TextosDaPresenca.swift:52–63`): Check-in e check-out gravados offline.
  - `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeuTurno.swift:26, 36`: Avisos de ações na fila e cancelamento pendente.
  - `iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:409–414`: Dados de acompanhamento desatualizados.
  - `iOS/Sources/Apresentacao/Fluxos/Contratante/MinhasVagas.swift:559–565`: Avisos de recusas retidas na fila.
  - `iOS/Sources/Apresentacao/Fluxos/Push/DestinosDoAviso.swift:256`: Abertura de turno vindo de push sem rede.

---

### 2.5 Sem Permissão (`sem permissão`)

Informa a necessidade de autorizações do sistema operacional (notificações push e localização/GPS) com clareza de propósito e caminhos de recuperação.

- **Padrão Visual:**
  - *Tela de Explicação (Pré-permissão):* `TelaExplicacaoDoPush` (`TelasDaPermissaoDePush.swift:9–58`). Tela completa com ícone temático (`bell.badge.fill`), título em `.largeTitle.bold()`, corpo explicativo, cartão com lista de itens acompanhados de marcadores (`checkmark.circle.fill` em `FrilaCor.sucesso`), `BotaoPrimario("Ativar notificações")`, `BotaoSecundario("Agora não")` e nota de rodapé.
  - *Aviso Fixo de Notificações Negadas:* `AvisoDePermissaoDePush` (`TelasDaPermissaoDePush.swift:63–98`). Banner `AvisoFrila(tom: .alerta)` seguido de `BotaoSecundario("Abrir Ajustes")`.
  - *Aviso Fixo de Notificações Não Pedidas:* `AvisoFrila(tom: .informativo)` seguido de `BotaoSecundario("Ativar notificações")`.
  - *Localização Negada no Check-in:* Bloco explicativo dentro de `SecaoDePresenca` (`SecaoDePresenca.swift:78–99`) com título `"Localização não confirmada"`, mensagem de motivo, `BotaoPrimario("Fazer check-in manual")`, `BotaoSecundario("Tentar o GPS de novo")`, link para Ajustes (`Link(destination: UIApplication.openSettingsURLString)`) com `"Abrir Ajustes"` e `BotaoSecundario("Agora não")`.
- **Texto-base:**
  - Push Desativado (Profissional): `"As notificações estão desativadas. Você não recebe o aviso de vaga nova nem os lembretes dos seus turnos."` (`TextosDoPush.swift:49`).
  - Push Desativado (Contratante): `"As notificações estão desativadas. Você não recebe o aviso de quem aceitou a vaga, de check-in nem de atraso."` (`TextosDoPush.swift:51`).
  - Push Não Pedido (Profissional): `"Ative as notificações para saber de uma vaga nova na hora."` (`TextosDoPush.swift:59`).
  - Push Não Pedido (Contratante): `"Ative as notificações para saber quando alguém aceita a sua vaga."` (`TextosDoPush.swift:61`).
  - Localização Negada: `"O Frila está sem permissão para usar a localização. Você pode liberar nos Ajustes."` (`TextosDaPresenca.swift:26`).
  - Localização Aproximada: `"A localização precisa está desligada para o Frila, e a aproximada não mede a distância até o endereço."` (`TextosDaPresenca.swift:27`).
- **Ação:**
  - Redirecionamento aos Ajustes do iOS: `UIApplication.openNotificationSettingsURLString` ou `UIApplication.openSettingsURLString`.
  - Reabertura da explicação: `modelo.reabrir()`.
  - Fallback operacional (GPS): Opção de check-in manual imediato (`"Fazer check-in manual"`), assegurando que o profissional não seja bloqueado por falha de GPS.
- **Onde o app já usa (arquivo:linha):**
  - `iOS/Sources/Apresentacao/Fluxos/Push/TelasDaPermissaoDePush.swift:9`: Tela de explicação de push.
  - `iOS/Sources/Apresentacao/Fluxos/Push/TelasDaPermissaoDePush.swift:65`: Aviso fixo de permissão de push.
  - `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:68, 78`: Explicação e tratamento de falta de permissão de GPS.
  - `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaVagas.swift:21`: Injeção do banner de push na lista de vagas.
  - `iOS/Sources/Apresentacao/Fluxos/Contratante/MinhasVagas.swift:287`: Injeção do banner de push em Minhas Vagas.

---

### 2.6 Sucesso (`sucesso`)

Confirma a conclusão de uma ação iniciada pelo usuário (salvar perfil, registrar avaliação, confirmar presença ou republicar vaga).

- **Padrão Visual:**
  - *Banner Informativo:* Componente `AvisoFrila(tom: .informativo)` (`Componentes.swift:215–280`). Faixa com fundo preenchido na cor primária (`FrilaCor.primaria`) com 12% de opacidade, cantos arredondados de 12 pt, texto em `.callout` e ícone `"info.circle.fill"`.
  - *Marcadores de Confirmação:* Ícones SF Symbol `"checkmark.circle.fill"` com a cor verde de sucesso (`FrilaCor.sucesso` / `Color("Success")`) em listas e itens concluídos.
  - *Navegação de Avanço:* Conclusão com transição direta para a tela de destino (ex.: detalhe do turno após confirmação) ou fechamento da modal.
- **Texto-base:**
  - Perfil salvo: `"Perfil salvo."` (`TextosDoProfissional.swift:163`).
  - Avaliação enviada: `"Avaliação registrada."` (`TextosDoProfissional.swift:180`).
  - Vaga republicada: `"Vaga republicada."` (`RepublicarVaga.swift:30`).
  - Presença confirmada: `"Presença confirmada."` (`TelaTurnoDoContratante.swift:22`).
  - Check-in verificado: `"Check-in verificado às \(hora), a \(metros) m do endereço."` (`TextosDaPresenca.swift:44`).
- **Ação:**
  - Dispensa manual ou automática do aviso.
  - Navegação de volta para a lista ou avanço de fluxo.
- **Onde o app já usa (arquivo:linha):**
  - `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaPerfilProfissional.swift:55`: Confirmação de salvamento do perfil.
  - `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaAvaliacao.swift:101`: Confirmação de envio de avaliação.
  - `iOS/Sources/Apresentacao/Fluxos/Contratante/MinhasVagas.swift:277, 555`: Confirmação de republicação de vaga.
  - `iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:401`: Confirmação de presença e reabertura.
  - `iOS/Sources/Apresentacao/ValidacaoClienteAPI.swift:92`: Confirmação de sucesso em chamadas de teste da API.

---

## 3. Matriz de Divergências Encontradas no Código

Mapeamento de discrepâncias entre o padrão ideal de design system e as implementações atuais nas telas do aplicativo:

| # | Estado | Componente Esperado | Implementação Encontrada | Arquivo e Linha | Divergência e Impacto |
|---|---|---|---|---|---|
| 01 | **Carregando** | `EstadoCarregando` | `ProgressView()` solto | `MinhasVagas.swift:723` | O carregamento de contato em Minhas Vagas usa um spinner genérico sem texto e sem o container padronizado de 160 pt de `EstadoCarregando` (a lista inicial na linha 301 já utiliza `EstadoCarregando`). |
| 02 | **Carregando** | Esqueleto nas listas | Spinner central | `TelaVagas.swift:108`, `MinhasVagas.swift:515` | O cartão `nliiRfQg` sugere esqueleto (*skeleton screen*) nas listas; o app utiliza spinner centralizado simples. |
| 03 | **Vazio** | `EstadoVazio` | `VStack` com `.cartaoFrila()` | `MinhasVagas.swift:303–311` | Minhas Vagas monta um card customizado sem o ícone `"tray"`, divergindo visualmente de `TelaVagas` e `TelaMeusTurnos`. |
| 04 | **Vazio** | `EstadoVazio` com CTA | `EstadoVazio` sem botão | `TelaVagas.swift:110–112` | `EstadoVazio` não possui slot para botão de ação integrado (ex.: limpar filtros ou ver outras regiões). |
| 05 | **Erro** | `EstadoErro` | Unificado em `EstadoErro` | `TelaMeusTurnos.swift:109–114` | Em Meus Turnos, o erro de carga foi unificado com `EstadoErro(verbatim: mensagem)`, mas a mensagem genérica ainda mascara a distinção entre erro de rede e erro do servidor. |
| 06 | **Sem Rede** | `EstadoOffline` com timestamp | `EstadoOffline` genérico | `TelaVagas.swift:125–129`, `EstadosDeTela.swift:73` | O aviso de offline não inclui o horário da última sincronização, previsto no RNF06 e no cartão `nliiRfQg`. |
| 07 | **Sem Rede** | `EstadoOffline` específico | `case let .falha(mensagem)` | `TelaMeusTurnos.swift:109–114` | Falha de rede em Meus Turnos cai na mesma cláusula de erro geral de servidor, sem feedback explícito de modo offline. |
| 08 | **Sem Permissão**| Botão padronizado | `BotaoSecundario` vs. `Link` | `TelasDaPermissaoDePush.swift:77` vs. `SecaoDePresenca.swift:92` | Push usa `BotaoSecundario` para ir aos Ajustes; GPS usa um `Link` textual simples sem borda. |
| 09 | **Sucesso** | `AvisoFrila(tom: .sucesso)` | `AvisoFrila(tom: .informativo)` | `TelaPerfilProfissional.swift:55`, `MinhasVagas.swift:277` | `AvisoFrila` não possui a variante `.sucesso`. Mensagens de sucesso são exibidas na cor primária (azul) em vez do verde de sucesso. |
| 10 | **Sucesso** | Pontuação sóbria consistente | Ponto final nas mensagens de sucesso | `TextosDoProfissional.swift:163` vs. `TelaTurnoDoContratante.swift:22` | Corrigido em 16/10/2026: textos usam ponto final (*"Perfil salvo."*, *"Avaliação registrada."*, *"Vaga republicada."* e *"Presença confirmada."*). |

---

## 4. Decisões Pendentes Marcadas para Produto e Design

1. **Aprovação do Tom `.sucesso` no Design System:**
   - **Responsável:** Fabrício (Design) e Júlia (Produto).
   - **Ponto em aberto:** Definir se `AvisoFrila` deve incluir a variante `.sucesso` com `FrilaCor.sucesso` (verde) para todas as confirmações operacionais, ou se a cor primária (`.informativo`) permanece como padrão.
2. **Handoff dos Frames de Modo Avião e Fila Offline:**
   - **Responsável:** Fabrício (Design).
   - **Ponto em aberto:** Elaboração e entrega dos frames no Figma para `Meus turnos em modo avião` e `Check-in pendente sem rede` com a indicação visual de horário de atualização (critério de aceite do cartão `nliiRfQg`).
3. **Decisão sobre Esqueleto (*Skeleton*) vs. Spinner:**
   - **Responsável:** Fabrício (Design).
   - **Ponto em aberto:** Avaliar se a substituição de `EstadoCarregando()` por esqueleto (.redacted) é prioritária para a v1.0 ou se fica como melhoria para a v1.1.
4. **Alinhamento do Tom de Voz dos Estados Vazios e de Sucesso:**
   - **Responsável:** Júlia (Produto / Conteúdo).
   - **Ponto em aberto:** Homologação final da redação dos estados vazios e remoção de pontos de exclamação para manter tom sóbrio e profissional no aplicativo.
