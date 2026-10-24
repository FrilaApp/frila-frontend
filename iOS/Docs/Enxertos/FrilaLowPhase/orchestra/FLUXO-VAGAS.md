---
tarefa: midfi-backend
artefato: FLUXO-VAGAS
de: Trilha
para: Rumo, CLAUDE
status: pronto
peso: profundo
risco: medio
volta: 0
atualizado: 2026-10-10
---

# F-VAGAS: filtrar a descoberta e entender indisponibilidade ou ausência de turnos

## Rastreabilidade e limites

MAPA: **C6** filtro de distância, **C7** vaga encerrada/cancelada e **C8** vazio de Meus turnos. Fontes: FONTE-telas-mvp, complementos respectivos; CONTEXTO; ESTADO, Q4 aberta; DESIGN-SOURCE-DOCUMENT §§5.3, 7 e 12. Herda taxonomia/copy de FLUXO-ESTADOS, C1/C2, e forma única de PADRAO-ESTADOS. Lições de AUDITORIA-P3 e instrução de retomada incorporadas aos critérios abaixo. Autoridade é documental, sem contrato de servidor comprovado.

Todos os quadros abaixo em `docs/prototype/midfi/project/`, L2/Goiva: Vagas.dc.html, VagasSemNotificacao.dc.html (wrapper), Vaga.dc.html, Preenchida.dc.html, MeuTurno.dc.html. Notificacao.dc.html usa destinos C7 conforme F-NOTIF, sem mudar política de emissão. TurnoHoje/TurnoProximo recebem navegação existente, sem o vazio da lista.

**Q4 bloqueia a definição final de C6:** referência da distância, opções vigentes e comportamento sem permissão de localização. Não deduzir opções dos 15 km de despacho, não usar localização atual por default, não converter exemplos do espelho em contrato. C7/C8 podem ser revisados separadamente; Q4 não os redefine.

## Tela 1: Vagas no DF, C6

**Pessoa:** reduzir a lista a oportunidades que façam sentido, sabendo o que a distância mede. **Negócio:** facilitar descoberta sem alterar despacho, elegibilidade ou garantia de deslocamento. **Entrada:** aba Vagas ou notificação agrupada; wrapper sem push mantém a lista. **Saída:** Vaga ao abrir item; abas Meus turnos/Perfil preservadas.

**Caminho feliz existente:** consulta → lista → abrir detalhe. Complemento C6: acionar Distância → escolher opção vigente → aplicar no retorno à lista → lista com filtro identificado. A referência e opções dependem de Q4; o fluxo de escolha está desenhado, sua instância final não está liberada. Função e data preservam seus controles; distância é outro filtro de busca, não configuração do raio do despacho.

**Copy final estrutural:** novo controle “Distância”; lista mantém título “Vagas no DF”; texto de apoio “O filtro de distância muda a lista de vagas. Ele não muda quais avisos você recebe.”. Após decisão Q4, o resumo da distância deve nomear a referência real em frase completa, sem prometer tempo de viagem. Não inserir “de você” se a referência for ponto declarado; não inserir “do seu ponto base” como decisão nova enquanto Q4 aberta.

| Estado / alternativo | Copy e saída | Aceite |
|---|---|---|
| Carregando | L1 “Carregando as vagas.” | Nenhuma contagem 0, cartão de fixture ou vazio antes de resposta |
| Atualizando | L2 “Atualizando as vagas.”, mantendo dados conhecidos | Filtros/contexto preservados; dado anterior identificado como anterior |
| Falha sem cópia | E1 “Não foi possível carregar as vagas.” E2 “Tente de novo.”; Tentar de novo | Não declarar sem vagas; retry não executa aceite nem altera filtros |
| Offline com cópia | O1 e T1 somente com carimbo conhecido | Cópia continua legível; disponibilidade não considerada atual para aceite |
| Offline sem cópia | “Sem conexão. Não há uma cópia das vagas neste aparelho.” O3 | Sem lista fictícia ou vazio legítimo |
| Consulta bem-sucedida sem vagas abertas | “Nenhuma vaga aberta agora.” “Volte mais tarde para ver novas vagas.” | Não prometer push se negado; abas seguem disponíveis |
| Consulta bem-sucedida sem resultados dos filtros | “Nenhuma vaga com esses filtros.” “Tente outros filtros para ver mais vagas.”; Limpar filtros | Não confundir com ausência geral de vagas ou falha. Limpar desfaz restrições de busca, não dados do perfil |
| Sem ponto base, estado existente | Mensagem/saída existentes para Definir ponto base | Não inventar efeito de GPS negado nem decidir Q4 com esse estado |
| Push negado | Lista permanece operável | Não pedir permissão para filtrar nem penalizar quem dispensou avisos |
| Localização negada | Efeito no filtro final reservado a Q4 | Não chamar de offline/erro de servidor nem bloquear toda a lista por suposição |

**Decisões e atrito:** abrir filtro e escolher uma opção custa uma escolha contextual; aplicar é o fechamento já adotado pelo seletor da lista. Não pedir CEP/GPS de novo sem decisão Q4. Limpar filtros custa um toque para remover a restrição, sem pré-selecionar maior distância para parecer que há vagas. Sem filtro de distância aplicado, não introduzir restrição oculta; isso é estado, não opção inventada de enum.

## Tela 2: seleção de distância, estrutura C6

Superfície de filtro da própria Vagas, seguindo o sheet de função/data existente, sem arquivo novo. **Pessoa:** entender referência e escolher alcance de busca. **Negócio:** oferecer escolha explícita com resumo verificável. **Entrada:** Distância. **Saída:** aplicar → mesma lista; fechar sem aplicar → mantém a escolha anterior.

Título “Distância”; ajuda estrutural “Escolha a distância para filtrar a lista.”; referência visível a preencher somente após Q4. Opções como lista de seleção única, com seleção ativa neutra conforme CONTEXTO. Não adicionar valores em quilômetros, intervalos, slider, opção paga ou “perto de mim” fictícios. CTA “Ver vagas”, ou contagem recebida quando realmente conhecida; ação Limpar segue a limpeza do filtro, sem apagar outros dados. Campos/valores de Q4 ficam anotados na especificação, não como textos técnicos para pessoa final.

**Estados:** seleção local não carrega servidor a cada toque; consulta resultante herda estados da lista. Fonte de opções não disponível é pendência de produto, não lista vazia de filtro. Não construir opções clicáveis inventadas. Permissão negada e escolha de referência continuam Q4. **Aceite:** fechar não muda filtro; aplicar mantém a função/data; filtro e referência exibidos coincidem com a consulta; números não são deduzidos do despacho. Estrutura pode ser revisada; C6 final só após Q4 e aprovação do anel.

## Tela 3: Vaga, C7

**Pessoa:** entender se ainda pode aceitar e o que mudou. **Negócio:** evitar compromisso falso e distinguir resultado da corrida de encerramento/cancelamento. **Entrada:** item da lista ou aviso antigo; consulta do estado atual. **Saída:** Ver outras vagas → Vagas; retorno existente à origem.

**Caminho feliz disponível:** mantém detalhe/condições e aceite elegível existente. **Alternativos:** resposta atual preenchida, encerrada ou cancelada → mensagem específica, sem Aceitar turno → saída. Indisponibilidade recebida antes ou depois de tentativa de aceite não é erro de internet. Durante Confirmando, mudança para offline/sem resposta não deve completar inevitavelmente como Confirmado por um callback local.

| Resultado recebido | Copy final | Aceite |
|---|---|---|
| Preenchida | “Esta vaga já foi preenchida.” “Outra pessoa aceitou a última posição antes. Nada muda na sua reputação.”; Ver outras vagas | Só se resposta informa preenchimento, não qualquer indisponibilidade |
| Encerrada | “Esta vaga foi encerrada.” “Ela não recebe mais aceites.”; Ver outras vagas | Não atribuir a outra pessoa, não afirmar motivo que não veio do sistema |
| Cancelada | “Esta vaga foi cancelada.” “Ela não recebe mais aceites.”; Ver outras vagas | Não marcar falta, suspensão ou alteração de reputação pelo cancelamento do anúncio |
| Consulta falha/offline | C1, “o detalhe da vaga” ou “a vaga” conforme glossário; copy E1/O1/O2 | Não trocar falha por encerrada/cancelada, não habilitar aceite offline |
| Aceite sem resposta conclusiva | Estado existente Ainda não confirmado, reconsulta antes de repetir | Sem fila de aceite C3 e sem confirmação baseada em disponibilidade de cópia |

Título de tela “Detalhe da vaga” sempre visível, mesmo quando função/local reais ainda não chegaram; dados específicos só após leitura utilizável. Contato não é liberado por carga, prévia ou simples abertura. Um toque de recuperação só consulta; nunca cancela o outro turno, envia aceite duplicado ou muda compromisso.

## Tela 4: Preenchida e variações C7

**Pessoa:** entender o resultado de indisponibilidade e voltar à descoberta. **Negócio:** evitar caminho morto e mensagens falsas de disputa. **Entrada:** resultado real da consulta/aceite, incluindo notificação antiga. **Caminho:** mensagem correspondente → Ver outras vagas → Vagas. **Saída:** mantém retorno útil, sem próximo candidato ou compromisso fictício.

Identificação compacta “Vaga indisponível” nas variantes encerrada/cancelada; “Vaga preenchida” na preenchida. Título/identificação não desaparece em carregando/erro. Usar as três mensagens C7 acima. Não escrever “Foi rápido: outra pessoa aceitou antes” nas variantes encerrada/cancelada. Outras vagas só quando realmente recebidas, não fixtures durante carga. Se o resultado já veio na resposta anterior, não inserir carga artificial para repeti-lo.

**Estados:** carga/atualização/erro/offline seguem C1; indisponibilidade não é vazio de coleção. Sem rede com cópia, indicar anterior e não garantir alternativa atual. GPS/push não exigidos. **Atrito:** uma saída de um toque; não pressionar a aceitar alternativa para compensar a perda. **Aceite:** prop de disponibilidade alterna preenchida/encerrada/cancelada mesmo depois de interação; nenhum resultado local antigo cobre a nova variante; nenhuma acusação, zero/100% de reputação ou aceite falso.

## Tela 5: Meus turnos, C8

**Pessoa:** saber que ainda não tem compromisso na lista e descobrir vagas. **Negócio:** orientar sem simular histórico ou penalizar a ausência. **Entrada:** aba Meus turnos; leitura bem-sucedida sem itens. **Caminho:** vazio → Ver vagas → Vagas. **Saída:** Perfil/abas também preservados. Não aplicar este vazio ao detalhe TurnoProximo.

Copy final: título sempre “Meus turnos”; vazio “Você ainda não tem turnos.”; apoio “Quando você aceitar uma vaga e o turno for confirmado, ele aparece aqui.”; CTA “Ver vagas”. Se existir turno na cópia, mostrar cópia com aviso, nunca este vazio por falha de atualização. Não criar aba de histórico v1.1, contar falta, sugerir castigo ou prometer confirmação pelo toque em vaga.

**Estados:** L1 “Carregando os turnos.”; L2 “Atualizando os turnos.”; E1 “Não foi possível carregar os turnos.” e Tentar de novo; O1/T1 ou O2/O3 conforme cópia. Vazio somente após consulta bem-sucedida. Localização/push negados não provam lista vazia. **Decisão/custo:** Ver vagas custa um toque e serve à intenção de buscar compromisso; não precisa completar formulário de novo. **Aceite:** alternar vazio/disponível após abrir turno ou retry não deixa cartões/status residuais; título e tab bar sempre visíveis.

## Critérios compartilhados, PADRAO-ESTADOS e lições da E3

1. Erro sem cópia/offline sem cópia/vazio usam bloco central definido por PADRAO-ESTADOS (Vagas:37); erro com cópia/offline com cópia usam faixa persistente acima do conteúdo, sem esmaecer dados. L1/L2 discretos, sem skeleton; Reduzir Movimento sem pulsação. T1 somente com marca conhecida. Neutros, SF Pro, cápsulas/alvo 44 e barras dentro de 844, sem encobrir título ou CTA.
2. Estado de leitura e disponibilidade alternáveis por prop **depois de interação**. Exercitar erro → retry → carregando, disponível → aceite em curso → offline, conflito → carregando e resultado → outra disponibilidade. Resultado local/overlay/timer obsoleto não pode vencer a nova prop. Não apagar um resultado autoritativo real; distinguir conhecido de simulação residual.
3. Retry sem chamada dupla: guarda no handler, além de desabilitação/ocupado acessível; duas ativações seguidas iniciam no máximo uma tentativa. Cancelar callbacks obsoletos ao trocar cenário/sair. Retry falho permanece falho; sucesso precisa de conteúdo novo explicitamente representado, não timer que fabrica sucesso.
4. Identificação da tela sempre visível. Foco só quando há **conteúdo novo**: após primeira resposta útil ou retry explícito bem-sucedido, foco no conteúdo; retry que continua em erro não desloca foco para fixture oculta. Reconexão automática anuncia sem mover foco. A chegada por push usa título do destino, sem confundir navegação com novo resultado. Nenhum foco em alvo não montado.
5. Defaults honestos, divulgação progressiva e uma escolha de filtro por vez. Urgência somente da data/hora real do turno; sem escassez falsa, culpa por não ter turno, bloqueio por push negado ou promessa de deslocamento. Sem nova exceção de design.

## O que o canvas não demonstra e vai à especificação nativa

Props/quadros demonstram a taxonomia e caminhos de copy, não disponibilidade real, consulta/deduplicação de servidor, aceite atômico, sessão, push, GPS/permissão, distância calculada, atualização/reconexão real ou persistência de filtros entre remontagens. Origem de uma notificação e retorno contextual entre arquivos podem ser representados, mas não provam continuidade nativa. Foco/VoiceOver real, timers cancelados pelo lifecycle e comparação do dado salvo com resposta atual exigem validação na frente App, sem implementação App neste pacote. Enquanto Q4 aberta, nem a medida nem opções/distância selecionada são demonstradas como contrato final. O relatório de telas deve separar representação estática/interação local destas garantias, sem alegar E4 como teste de backend.

## Perguntas e handoff

Q4 aberta bloqueia C6 final. Q1 resolvida não cria entrada de Candidata em Vagas ou VagaAberta; Q2 não inclui aceite; Q3/Q5/Q7 conservam seus escopos. C7/C8 não dependem de escolher opções de distância.

**Aviso ao CLAUDE por este arquivo:** F-VAGAS pronto na E2, com Q4 explícita. Próxima estação Rumo para `anel/DOC-VAGAS.md`, depois Lupa/Fiel. C7/C8 podem ser revisados sem fechar C6; E3 de cada escopo exige `anel/CONTRA-VAGAS.md` aprovado e ausência de pergunta aplicável aberta. Máximo duas voltas. Nenhuma mudança em ESTADO/MAPA ou telas de outros donos.

Verificação: leitura estática das cinco bases/wrapper, MAPA, fontes, PADRAO e lições de auditoria. Critérios para alternância/retry/foco descritos, sem executar canvas ou App. Nenhum `.dc.html` criado/editado, build, teste ou simulador nesta entrega documental.
