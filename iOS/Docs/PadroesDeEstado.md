# Padrões de Estado (Cartão nliiRfQg / #85)

Este documento apresenta o **inventário sistemático dos componentes SwiftUI de estado** existentes na camada de Apresentação do Frila iOS (`frila-frontend`), cobrindo as variantes (tela inteira, lista, botão, banner/faixa e inline), onde cada componente é usado no código (`arquivo:linha`) e as **lacunas mapeadas para o Fabrício espelhar no Figma**.

---

## 1. Diretrizes Gerais do Design System

1. **Comunicação multissensorial:** Nenhum estado utiliza exclusivamente cor para transmitir status. Todo estado combina ícone SF Symbol, tipografia hierárquica e, quando aplicável, anúncio semântico para o VoiceOver (`AnunciarAoAparecer`).
2. **Acessibilidade e Dynamic Type:** Todos os componentes de estado respondem ao Dynamic Type até AX5 (`UICTContentSizeCategoryAccessibilityXXXL`), adaptando layouts para empilhamento vertical nos tamanhos de acessibilidade.
3. **Alvos de toque:** Qualquer botão de ação ou retentativa respeita a dimensão mínima de toque de **44 × 44 pt** (`FrilaMetrica.alvoMinimo`).
4. **Vocabulário controlado:** Textos alinhados ao glossário de produto (vaga, posição, turno, comparecimento, check-in, check-out, contratante, profissional, equipe de confiança).

---

## 2. Inventário de Componentes e Variantes de Estado

### 2.1 Carregando (`carregando`)

Indica processamento assíncrono em andamento (leitura de rede, gravação de dados ou consulta a sensores).

- **Variantes Implementadas:**
  1. *Esqueleto Concêntrico Padrão (Lista / Tela Inteira):* `EstadoCarregando` (`EstadosDeTela.swift:31–50`).
     - **Estrutura visual:** `VStack` vertical centralizado com padding médio (`FrilaEspaco.medio`), composto por osso de cartão com raio concêntrico (`FrilaSkeletonBone.concentric(outerRadius: 16, height: 120)`) e duas pílulas de texto simulado (`FrilaSkeletonBone.pill(width: 160, height: 16)` e `FrilaSkeletonBone.pill(width: 240, height: 12)`).
     - **Acessibilidade:** `accessibilityElement(children: .ignore)` com rótulo `"Carregando…"`.
  2. *Botão Primário com Indicador:* `BotaoPrimario(..., carregando: true)` (`Componentes.swift:81–110`).
     - **Estrutura visual:** Fundo primário (`FrilaCor.primaria`), altura mínima de 44 pt. Enquanto `carregando: true`, o texto do botão é temporariamente ocultado e substituído por `ProgressView().tint(FrilaCor.sobrePrimaria)`.
     - **Comportamento:** O botão fica desativado (`.disabled(carregando)`) prevenindo cliques duplos concorrentes. O VoiceOver anuncia o valor `"Carregando"` via `accessibilityValue`.
  3. *Processamento Inline / Sensor (Presença):* `progresso(_ texto: String)` em `SecaoDePresenca.swift:225–233`.
     - **Estrutura visual:** `HStack(spacing: FrilaEspaco.pequeno)` horizontal alinhado à esquerda com spinner nativo `ProgressView()`, texto em `FrilaTipo.meta` e cor `FrilaCor.textoSecundario`, com dimensão mínima de 44 pt (`minHeight: FrilaMetrica.alvoMinimo`). Usado nos estados `.lendo` ("Lendo sua localização…", linha 116) e `.enviando` ("Enviando…", linha 118).
  4. *Spinner Próprio de Feed (Lista de Vagas):* `estadoCarregando` em `TelaVagas.swift:145–160`.
     - **Estrutura visual:** `VStack(spacing: FrilaEspaco.medio)` vertical com `ProgressView().controlSize(.regular).tint(FrilaCor.texto)`, texto `TextosDoProfissional.Lista.carregando` em `FrilaTipo.tituloDeEstado` (`FrilaCor.texto`), com padding superior grande (`FrilaEspaco.enorme`). Implementação própria da lista para manter coerência com o cabeçalho de busca.
- **Onde o app usa (arquivo:linha):**
  - `EstadosDeTela.swift:31`: Definição canônica de `EstadoCarregando`.
  - `FrilaApp.swift:356, 516`: Resolução da sessão de inicialização do app.
  - `TelaVagas.swift:145–160`: Feed de vagas no DF (variante própria com spinner e título de estado).
  - `TelaMeusTurnos.swift:145, 146`: Lista de turnos ativos do profissional.
  - `TelaDetalheVaga.swift:70, 106`: Leitura de detalhes da vaga e ações do profissional.
  - `TelaPerfilProfissional.swift:96, 545`: Perfil profissional e botão "Salvar".
  - `CandidaturaEmSelecao.swift:405, 477, 478`: Aba de candidaturas em seleção.
  - `SecaoDePresenca.swift:225–233`: Leitura de GPS e registro de presença no turno (progresso inline lendo/enviando).
  - `TelaPorQueReceboVagas.swift:47, 48, 204`: Histórico de critérios e envio de contestação.
  - `PerfisDaConta.swift:194, 405`: Perfil da conta e ajuda do perfil.
  - `AcoesDeSeguranca.swift:208, 306`: Denúncia e perfil público de segurança.
  - `PublicarVagaDaCasa.swift:87, 90`: Carregamento do fluxo de publicação do contratante.
  - `CandidatosDaVaga.swift:467, 468, 547`: Lista de candidatos inscritos e ação de escolha.
  - `FluxoDoContratante.swift:138, 139`: Inicialização do fluxo do contratante.
  - `TelaTurnoDoContratante.swift:141, 362, 538`: Turno do contratante e confirmação de presença.
  - `MinhasVagas.swift:953`: Painel de vagas do contratante.
  - `CadastroEstabelecimento.swift:459`: Botão "Salvar e publicar".
  - `RepublicarVaga.swift:499, 505`: Botões de republicação de vaga.
  - `TelaEntrada.swift:137`: Botão "Receber código".
  - `TelaCodigo.swift:253`: Botão "Entrar" com código OTP.
  - `TelaCadastro.swift:207`: Botão "Continuar" do cadastro.
  - `TelaContaSuspensa.swift:226`: Botão "Enviar contestação".
  - `TelaLicencas.swift:58, 59`: Lista de licenças de código aberto.
  - `AtualizacaoObrigatoria.swift:96`: Verificação da versão mínima do app.
  - `DestinosDoAviso.swift:90, 265`: Abertura de destino de notificação push.

---

### 2.2 Vazio (`vazio`)

Indica ausência de registros após busca, aplicação de filtros ou antes da primeira publicação/candidatura.

- **Variantes Implementadas:**
  1. *Padrão de Lista / Tela Inteira:* `EstadoVazio` (`EstadosDeTela.swift:12–29`), estruturado via `MensagemDeEstado` (`EstadosDeTela.swift:91–120`).
     - **Estrutura visual:** `VStack` vertical centralizado com padding grande (`FrilaEspaco.grande`), ícone SF Symbol `"tray"` em `FrilaTipo.tituloGrande` na cor `FrilaCor.textoSecundario`, título em `FrilaTipo.tituloDoCartao` (`FrilaCor.texto`) e mensagem em `FrilaTipo.meta` (`FrilaCor.textoSecundario`).
     - **Dimensão:** `frame(maxWidth: .infinity, minHeight: 160)`.
  2. *Variante Própria com Ícone em Círculo e Ação (Minhas Vagas):* `estadoVazio` em `MinhasVagas.swift:503–530`.
     - **Estrutura visual:** `VStack` vertical com `Image(systemName: "briefcase")` em `FrilaTipo.secao` e cor `FrilaCor.textoSecundario`, emoldurado por `Circle()` com preenchimento `FrilaCor.controle` (diâmetro `FrilaMetrica.circuloDeEstado`), título em `FrilaTipo.secao` (`TextosMinhasVagas.vaziaTitulo`), corpo em `FrilaTipo.corpo` (`TextosMinhasVagas.vaziaMensagem`) e `BotaoPrimario("Publicar vaga")` opcional quando o contratante possui a ação.
  3. *Variante Própria com Lupa e Limpar Filtros (Feed de Vagas):* `estadoVazio` em `TelaVagas.swift:162–190`.
     - **Estrutura visual:** `VStack` com `Image(systemName: "magnifyingglass")` em círculo de estado `FrilaCor.controle`, título em `FrilaTipo.tituloDeEstado` (*"Nenhuma vaga aberta"*), mensagem secundária (*"Mude os filtros ou puxe para atualizar."*) e botão secundário `BotaoSecundario("Limpar filtros")`.
- **Onde o app usa (arquivo:linha):**
  - `EstadosDeTela.swift:12`: Definição canônica de `EstadoVazio`.
  - `TelaVagas.swift:162–190`: Feed de vagas vazio (variante própria com lupa e botão de limpar filtros).
  - `MinhasVagas.swift:503–530`: Painel do contratante sem vagas (variante própria com maleta e CTA de publicar).
  - `TelaMeusTurnos.swift:149`: Lista de turnos vazia (*"Nenhum turno confirmado / Quando você tiver turnos confirmados..."*).
  - `CandidaturaEmSelecao.swift:485`: Candidaturas vazias (*"Nenhuma candidatura / As vagas a que você se candidatar..."*).
  - `CandidatosDaVaga.swift:478`: Candidatos vazios (*"Ninguém se candidatou ainda / Os candidatos aparecem aqui..."*).
  - `TelaEquipeDeConfianca.swift:66`: Equipe vazia (*"Ninguém na equipe ainda / Inclua um profissional a partir de um turno..."*).
  - `TelaPorQueReceboVagas.swift:50`: Histórico de critérios vazio (*"Nenhum registro ainda"*).
  - `CatalogoDesignSystem.swift:156`: Exibição de referência do Design System.

---

### 2.3 Erro (`erro`)

Comunica falha de operação, recusa de regra de negócio pelo servidor ou erro inesperado de sistema.

- **Variantes Implementadas:**
  1. *Tela Inteira com Retentativa:* `EstadoErro` (`EstadosDeTela.swift:52–78`).
     - **Estrutura visual:** `VStack` com ícone SF Symbol `"exclamationmark.triangle"` em `FrilaCor.textoSecundario`, título fixo `"Algo deu errado"`, mensagem dinâmica e `BotaoPrimario("Tentar novamente", acao: tentarNovamente)`.
     - **Acessibilidade:** Modificador `AnunciarAoAparecer(tom: .erro)` para leitor de tela.
  2. *Faixa / Banner Contextual:* `AvisoFrila(tom: .erro)` (`Componentes.swift:399–427`).
     - **Estrutura visual canônica no app:** Fundo neutro preenchido com `FrilaCor.controle` em todos os tons (sem tintura vermelha ou azul na implementação atual do app), raio de curvatura contínuo de **16 pt** (`FrilaRaio.aviso` em `DesignTokens.swift:78`), tipografia `FrilaTipo.aviso` e texto em `FrilaCor.texto`.
     - **Ícones:** `.erro` usa `"xmark.octagon.fill"`, `.alerta` usa `"exclamationmark.triangle.fill"` e `.informativo` usa `"info.circle.fill"`.
     - **Acessibilidade:** Prefixo dinâmico `"Erro: "` ou `"Alerta: "` gerado via `Self.prefixo(tom: tom)` para leitura do VoiceOver, combinado no anúncio semântico via `AnunciarAoAparecer`.
- **Onde o app usa (arquivo:linha):**
  - `EstadosDeTela.swift:52`: Definição de `EstadoErro`.
  - `FrilaApp.swift:519`: Falha ao avaliar sessão na raiz do app.
  - `TelaVagas.swift:132, 138`: Erro de carregamento no feed de vagas.
  - `TelaMeusTurnos.swift:166`: Erro de carregamento na lista de turnos.
  - `FluxoDoProfissional.swift:187`: Falha de avaliação do turno no fluxo profissional.
  - `TelaPorQueReceboVagas.swift:53, 56`: Falha ao carregar critérios de vagas.
  - `PerfisDaConta.swift:195, 406`: Falha de leitura de perfil da conta e ajuda.
  - `AcoesDeSeguranca.swift:309`: Falha de perfil público.
  - `PublicarVagaDaCasa.swift:103`: Falha ao publicar vaga.
  - `FluxoDoContratante.swift:163`: Falha de carga do fluxo do contratante.
  - `TelaTurnoDoContratante.swift:606`: Falha de avaliação do contratante.
  - `Estudio/TelaEstudioDeVaga.swift:38`: Falha no estúdio de vaga.
  - `DestinosDoAviso.swift:298`: Falha ao abrir turno vindo de push.
  - `TelaEquipeDeConfianca.swift:69, 72`: Falha de carga e sem rede na equipe de confiança.
  - `CandidaturaEmSelecao.swift:496`: Falha de carregamento de candidaturas.
  - `TelaEntrada.swift:48`: Banner de e-mail inválido ou recusa de acesso.
  - `TelaCodigo.swift:99`: Banner de código expirado ou incorreto.
  - `TelaCadastro.swift:166`: Banner de erro cadastral.
  - `TelaContaSuspensa.swift:107`: Banner de erro no envio de contestação.

---

### 2.4 Sem Rede / Offline (`sem rede`)

Atende aos requisitos de robustez sem conexão (RNF06 e RNF09), informando cache local ou retenção na fila offline.

- **Variantes Implementadas:**
  1. *Banner de Dados Salvos:* `EstadoOffline` (`EstadosDeTela.swift:80–83`).
     - **Estrutura visual:** `AvisoFrila("Sem conexão. Mostrando os dados salvos neste aparelho.", tom: .alerta)`.
  2. *Banner com Retentativa:* `VStack` com `AvisoFrila(tom: .alerta)` seguido de `BotaoSecundario("Tentar novamente")` (`TelaVagas.swift:125–129`).
  3. *Estado Pendente / Fila Local:* `EstadoPendente` (`EstadosDeTela.swift:85–89`).
     - **Estrutura visual:** `AvisoFrila(mensagem, tom: .informativo)`.
  4. *Bloco de Presença Offline:* Textos explicativos na `SecaoDePresenca.swift:151, 169` com horário exato gravado na fila para envio posterior.
- **Onde o app usa (arquivo:linha):**
  - `EstadosDeTela.swift:80, 85`: Definições de `EstadoOffline` e `EstadoPendente`.
  - `CatalogoDesignSystem.swift:154`: Referência de Design System.
  - `TelaVagas.swift:126–129`: Feed de vagas sem conexão com botão de retentativa.
  - `SecaoDePresenca.swift:151, 169`: Check-in e check-out gravados na fila local.
  - `TelaMeuTurno.swift:26, 36`: Avisos de cancelamento pendente e ações na fila.
  - `TelaTurnoDoContratante.swift:409–414`: Informação de dados em cache desatualizados.
  - `MinhasVagas.swift:559–565`: Aviso de recusa retida na fila.
  - `DestinosDoAviso.swift:256`: Abertura de turno vindo de push sem conexão.

---

### 2.5 Ação Pendente / Sem Permissão (`ação pendente` e `sem permissão`)

Informa necessidade de autorização do sistema operacional ou estado transitório aguardando ação de terceiros.

- **Variantes Implementadas:**
  1. *Tela Cheia de Pré-permissão:* `TelaExplicacaoDoPush` (`TelasDaPermissaoDePush.swift:9–58`).
     - **Estrutura:** Ícone de sino, título em `.largeTitle.bold()`, lista de benefícios com checkmarks, `BotaoPrimario("Ativar notificações")` e `BotaoSecundario("Agora não")`.
  2. *Aviso Fixo de Permissão Negada:* `AvisoDePermissaoDePush` (`TelasDaPermissaoDePush.swift:63–98`).
     - **Estrutura:** `AvisoFrila(tom: .alerta)` com `BotaoSecundario("Abrir Ajustes")`.
  3. *Localização Pendente no Check-in (Contingência GPS):* `SecaoDePresenca.swift:119–153`.
     - **Estrutura:** Bloco de contingência no estado `.semGPS(registro, motivo)` com aviso `Textos.semGPSTitulo` e explicações específicas para check-in ou check-out, botão ativo de registro manual (`botaoPresencaAtivo`, linhas 124–129), botão de retentativa de GPS (`botaoPresencaInativo`, linhas 130–135), link direto para Ajustes do sistema via `UIApplication.openSettingsURLString` (linhas 136–147) quando a permissão for negada ou localização for aproximada, e botão de cancelamento (linhas 148–152).
- **Onde o app usa (arquivo:linha):**
  - `TelasDaPermissaoDePush.swift:9, 65`: Tela e banner de permissão de push.
  - `SecaoDePresenca.swift:119–153`: Contingência de GPS e check-in manual.
  - `TelaVagas.swift:21`: Banner de permissão injetado no topo do feed.
  - `MinhasVagas.swift:287`: Banner de permissão injetado em Minhas Vagas.

---

## 3. Matriz de Lacunas para o Fabrício Espelhar no Figma

| # | Componente / Estado | Situação no Código SwiftUI | Lacuna para o Figma (Design) | Prioridade |
|---|---|---|---|:---:|
| 01 | **EstadoCarregando (Esqueleto)** | Utiliza `FrilaSkeletonBone.concentric` (cartão raio 16 pt, alt 120 pt) + 2 pílulas (`EstadosDeTela.swift:39–43`). | Criar componente de esqueleto concêntrico com tokens de cor claro/escuro (`ControlFill` e `Surface`) espelhando as dimensões exatas do código. | **Alta** |
| 02 | **EstadoVazio (Variantes e Slots de Ação)** | `EstadoVazio` exibe apenas ícone `"tray"`, título e texto (`EstadosDeTela.swift:27`). No app, `TelaVagas.swift:162` e `MinhasVagas.swift:503` implementam variantes próprias com círculos de estado e botões de ação ("Limpar filtros" e "Publicar vaga"). | No Figma, unificar e documentar as variantes com slot de botão de ação (CTA) para telas com filtros e ações de primeiro uso. | **Média** |
| 03 | **EstadoOffline e EstadoPendente** | Definidos em `EstadosDeTela.swift:80,85`, consumindo `AvisoFrila` diretamente com fundo `FrilaCor.controle` e raio 16 pt (`FrilaRaio.aviso`). | Padronizar no Figma os tokens e ícones de banner persistente para "Modo Avião / Dados em cache" (`.alerta`) e "Na fila local" (`.informativo`). | **Alta** |
| 04 | **AvisoFrila — Proposta Visual vs Código** | O código atual (`Componentes.swift:425`) usa `FrilaCor.controle` (fundo cinza neutro) e raio 16 pt para todos os tons. | Avaliar se o Figma introduzirá fundos tintados (ex.: vermelho perigo a 12% ou azul informativo) ou se preserva o fundo neutro de controle atual. | **Média** |
| 05 | **BotaoPrimario com Carregando** | Texto é ocultado e substituído por `ProgressView().tint(FrilaCor.sobrePrimaria)`. | Espelhar no Figma a variante do botão com o spinner centralizado sobre a cor primária (altura 44 pt / 52 pt). | **Baixa** |
| 06 | **Contingência de GPS / Localização** | `SecaoDePresenca.swift:119–153` usa layout com botões empilhados para check-in manual, retentativa e link Ajustes. | Alinhar no Figma o frame da folha de presença quando o GPS estiver desligado ou em modo aproximado. | **Média** |

---

## 4. Como Validar e Testar

Testes unitários de integridade dos padrões de estado rodam na suíte:
```bash
xcodebuild test-without-building -scheme Frila-Local \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FrilaTests/PadroesDeEstadoTests
```
