# Decisões da PO para a 1.0.1 (relatório de testes da 0.5.5)

A PO (Júlia) tomou quatro decisões de produto no relatório de testes da 0.5.5. Elas entram numa
futura **1.0.1**, não na 1.0.0 que está em revisão na Apple. Este documento diz, item a item, o que o
app já fazia, o que mudou e o que depende de contrato e backend.

| Item | Decisão | O app já fazia? | O que mudou no app | Depende de contrato ou backend? |
|---|---|---|---|---|
| A5 | Maioridade só pela data de nascimento, sem caixa "sou maior de idade" | Sim, desde 17/10/2026 (`9ffa92c3`) | Texto de ajuda sob a data e testes que travam a regressão | Não |
| A6 | Endereço fora do DF pode cadastrar, com aviso | Em parte: o cadastro da casa só deixava escolher Região Administrativa do DF | Aviso explícito nas duas telas de endereço; fora do DF a casa cadastra | Recomendado (ver abaixo), mas funciona com o servidor de hoje |
| A8 | Desbloquear quem foi bloqueado | Não | Tela "Pessoas e locais bloqueados" no perfil, com lista e ação "Desbloquear" (confirmação e acessibilidade), releitura de vagas ao desbloquear, alternância de "Bloquear" / "Desbloquear" no perfil público e atualização de textos de segurança | Não mais (contrato 0.2.51 e backend #408 integrados) |
| A11 | Pedir a localização precisa quando só a aproximada foi concedida | Em parte: pedia a precisa temporária no toque | Aviso antes do toque, texto no pedido e passo a passo dos Ajustes | Não |

## A5. Maioridade no cadastro

**Requisitos:** RN20 (maioridade 18+), `criar_conta` do contrato (a maioridade é verificada no banco
pela data de nascimento, "e não por um booleano enviado pela tela") e `iOS/Docs/Classificacao18ECA.md`.
O `produto/06-FUNDAMENTOS-DE-DESIGN-E-UX.md` já diz que a data de nascimento é necessária e que uma
caixa declarando maioridade sozinha não a substitui.

**Estado:** a `TelaCadastro` não tem caixa de maioridade. A única caixa é a dos Termos de uso e da
Política de privacidade. A conferência é automática, em camadas: data de nascimento no app (menor de
18 não passa, com a regra conservadora do 29 de fevereiro), Declared Age Range no iOS 26.2 ou mais
novo, e `422 menor_de_idade` no servidor.

**Mudança:** uma linha de ajuda sob o campo, "Conferimos sua idade pela data de nascimento. O Frila é
só para maiores de 18 anos.", que some quando aparece o erro de menor de idade. O texto explica por
que não há pergunta extra. `CadastroSemCaixaDeMaioridadeTests` falha se a caixa voltar.

## A6. Endereço fora do Distrito Federal

**Requisitos:** o contrato descreve `regiao_administrativa` como "Região Administrativa do Distrito
Federal" e a exige em `cadastrar_estabelecimento`; o servidor só confere que não está vazia e que
passa pelo filtro de texto (migração `20260928230000_regiao_administrativa.sql`). Não há regra de
cobertura no servidor.

**Estado:** o cadastro da casa só oferecia as 35 Regiões Administrativas do DF, e um endereço de fora
deixava o campo vazio: a casa só seguia escolhendo uma região do DF que não era a dela. O ponto base do profissional aceitava qualquer lugar,
sem aviso.

**Mudança** (`CoberturaDoDF`, `AvisoForaDoDF`, `TextosDeCobertura`):
- A conferência é local, sem rede: usa a unidade federativa que o geocodificador devolve e, sem ela,
  um retângulo que envolve o DF. O retângulo inclui um pedaço do Entorno em Goiás, então só a
  unidade federativa separa esses casos. Se o marcador do mapa é arrastado, vale só a coordenada.
- Cadastro do estabelecimento: fora do DF aparece o aviso "Este endereço fica fora do Distrito
  Federal. Você pode concluir o cadastro, mas por enquanto o foco e a cobertura do Frila são só do
  Distrito Federal." O seletor de Região Administrativa dá lugar ao aviso, e o app envia no campo a
  cidade do endereço (ou a unidade federativa, ou "Fora do Distrito Federal").
- Ponto base do profissional: o mesmo aviso, com "Você pode salvar". Salvar continua permitido.
- O aviso é só informação. Ele não bloqueia nada e não decide quem recebe vaga.

**Pendência de contrato (frila-docs, depois frila-backend):** mandar uma cidade num campo que o contrato
chama de Região Administrativa do DF funciona porque o servidor aceita texto livre, mas contraria a
descrição do campo. Para fechar: (1) o `openapi.yaml` passa a dizer que fora do DF o campo leva a
localidade; (2) decidir se o servidor guarda um indicador de cobertura (por exemplo `fora_do_df`)
para a Equipe Frila medir a demanda de fora e para o despacho não tratar a casa como do DF.

## A8. Desbloqueio

**Requisito:** RF26 (bloqueio imediato, nos dois sentidos, na casa inteira). O contrato 0.2.51 e o backend (PR #408) entregaram as RPCs `/rpc/listar_bloqueios` e `/rpc/desbloquear`.

**Estado anterior:** `ApiCliente.bloquear(_:)` existia; `BloqueiosDaSessao` guardava os bloqueios só em memória, durante a sessão. Não havia como ver nem desfazer um bloqueio.

**Mudança entregue no app:**
- Modelos e Portas: `ItemBloqueio` em `Dominio/Modelos.swift` e métodos `bloqueios() async throws -> [ItemBloqueio]` e `desbloquear(_ alvo: Alvo) async throws -> Bloqueio` na porta `ApiCliente`, com encaminhamento no `ApiClienteEncaminhador` e implementações completas em `SupabaseApiCliente` e `ApiClienteEmMemoria` (com idempotência, ordenação decrescente por `criadoEm` e restauração de visibilidade).
- DTOs do Contrato: `ContratoAPI.Desbloquear` e `ContratoAPI.ItemBloqueioDTO` integrados ao contrato 0.2.51.
- Sessão e Feed: `BloqueiosDaSessao.remover(_:)` implementado. Como `FluxoDoProfissional` observa `feed.bloqueios.alvos`, remover um bloqueio dispara a releitura imediata das vagas abertas.
- Tela "Pessoas e locais bloqueados" (`TelaBloqueios` e `BloqueiosViewModel`):
  - Acessível nas telas de perfil ("Meu perfil profissional" e perfil do estabelecimento).
  - Estados completos: carregando, lista de bloqueios, vazio ("Nenhum bloqueio ativo"), erro e offline, com suporte a tentar novamente e pull-to-refresh.
  - Ação "Desbloquear" para cada item da lista com alerta de confirmação e identificadores/rótulos para VoiceOver.
- Perfil público:
  - Botão na barra de ferramentas alterna entre "Bloquear" e "Desbloquear" com base em `model.bloqueado`. Ao tocar em desbloquear, confirmação com alerta antes da requisição.
  - Atualização do texto explicativo `efeitoBloqueio` em `TextosDaSeguranca`, explicitando que o bloqueio pode ser desfeito a qualquer momento na tela de bloqueios do perfil.
- Testes:
  - `BloqueiosViewModelTests` cobrindo todos os estados (conteúdo, vazio, erro, offline), desbloqueio e idempotência.
  - `SegurancaViewModelTests` cobrindo o ciclo de bloqueio e desbloqueio e resiliência a falhas de rede.

## A11. Localização precisa

**Requisitos:** RF13 e RN22 (presença a até 200 m), `fazer_checkin` (a distância vai ao servidor, a
coordenada não) e o README do iOS (seção Check-in e check-out).

**Estado:** o toque em "Fazer check-in" ou "Fazer check-out" já chamava
`requestTemporaryFullAccuracyAuthorization` com a chave `CheckIn` quando só a aproximada estava
concedida. Se a pessoa recusava, a tela oferecia o registro manual e o botão "Abrir Ajustes".

**Mudança:**
- Antes do toque, quando a permissão é a aproximada, a seção Presença mostra "A localização precisa
  está desligada para o Frila. Ela mede se você está a até 200 m do endereço. Ao tocar no botão, o
  iPhone vai pedir sua permissão, ou você ativa nos Ajustes." e o link para os Ajustes. A permissão
  é relida ao abrir a tela e quando o app volta dos Ajustes.
- A explicação que vem antes da pergunta do sistema ganhou a frase "Quando o iPhone perguntar,
  escolha a localização precisa: só ela mede se você está a até 200 m do endereço.", para a pessoa
  não escolher a aproximada logo no primeiro pedido.
- A mensagem de localização aproximada mantida passou a dar o caminho: Ajustes, Frila, Localização,
  Localização precisa.
- O app continua sem permissão "sempre", sem leitura em segundo plano e sem geofencing, como a RN22
  e o `Info.plist` exigem.

**Limite:** o iOS controla quando mostra o pedido temporário de precisão e pode não mostrá-lo de
novo se a pessoa recusar várias vezes. Por isso o caminho pelos Ajustes e o registro manual seguem
disponíveis.

## O que fica de fora

- Nada disto altera a versão de marketing nem o build em revisão. O PR é rascunho e não vai para a
  `main` agora.
- A8 e A11 estão implementados nesta branch/PR (A8 com contrato 0.2.51 e backend #408 integrados). A6 pede o ajuste de contrato para ficar limpo.
