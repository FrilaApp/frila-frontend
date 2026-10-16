# Plano de Métricas — North Star, KPIs e Dicionário de Eventos (T-0017)

Documento formal do plano de métricas do aplicativo Frila, elaborado para o piloto de 18 dias no Distrito Federal (DF) e para subsidiar a apresentação de resultados da Academy em 27/11/2026. Alinhado ao contrato da API (`iOS/Contrato/openapi.yaml:3184` e `:3808`), à conformidade de privacidade (`iOS/Docs/LGPD.md`, Art. 37 da LGPD, RN15) e à implementação do banco de dados no Supabase (`metrica.funil_*`, `public.evento_app`).

---

## 1. Contexto, Objetivos e Premissas do Piloto

### 1.1 Objetivo
Definir com rigor matemático e rastreabilidade no código as métricas fundamentais do produto antes do lançamento comercial. As métricas servem para:
1. Validar a proposta de valor do Frila no piloto de 18 dias no DF (focado no setor de bares, restaurantes e eventos).
2. Subsidiar a análise de métricas da Academy em 27/11/2026.
3. Fornecer aos desenvolvedores o mapeamento exato de quais eventos de telemetria precisam ser instrumentados no cliente iOS e como eles se somam às métricas já consolidadas no servidor.

### 1.2 Premissas Duras de Medição
- **Duração do piloto:** O piloto opera com duração máxima de **18 dias**. Nenhuma métrica de produto pode depender de janelas superiores a 18 dias (métricas clássicas como D30 ou retenção mensal estão expressamente vedadas deste plano).
- **Sem metas de tempo inventadas:** As metas de tempo pré-fixadas foram retiradas das especificações porque não havia base empírica de aferição. O piloto é a ferramenta de calibração; os números obtidos serão contrastados contra as linhas de base extraídas das entrevistas qualitativas com o setor.
- **Isolamento de dados de teste (RN15 e RNF13):** Todas as consultas e consolidações excluem formalmente contas de teste/demonstração (`usuario.demonstracao = true`) e contas pertencentes ao time interno do Frila (`privado.conta_equipe`), conforme implementado nas views do schema `metrica` no Supabase (`20260930150000_views_funil_piloto.sql`).
- **Privacidade por padrão (LGPD):** A telemetria de produto não recebe, trafega nem armazena campos livres de texto, nomes, números de telefone, e-mails, documentos ou coordenadas geográficas brutas de GPS (Art. 7º, 11 e 37 da LGPD; `iOS/Docs/LGPD.md:31-45`).

---

## 2. North Star Metric

### 2.1 Definição
> **North Star:** Turnos concluídos com presença verificada por semana no Distrito Federal.

Essa métrica sintetiza o valor central da plataforma: conectar um estabelecimento que precisa de mão de obra temporária a um profissional qualificado, culminando na prestação real do serviço no local de trabalho.

### 2.2 Critérios de Conclusão e Presença
A tabela `turno` não tem coluna de status nem de profissional. O estado mora na posição (`posicao.estado`), e a presença mora no turno (`turno.verificacao`). Um turno conta para a North Star quando satisfaz cumulativamente:
1. **Concluído:** a posição terminou confirmada (`posicao.estado = 'cumprida'`). A rotina `privado.fechar_turnos_e_vagas()` (pg_cron, a cada 5 min) passa a posição de `confirmada` para `cumprida` quando `posicao.fim_em` já passou; posição cancelada nunca vira `cumprida`.
2. **Presença verificada:** `turno.verificacao = 'verificado'`. O servidor só grava esse valor em dois casos (constraint `verificacao_coerente`):
   - check-in **geolocalizado** (`turno.checkin_tipo = 'geolocalizado'`), aceito só com distância de até **200 m** do local da vaga (RN22; constraint `checkin_no_raio`, `turno.checkin_distancia_m <= 200`; no app, `RegraDePresenca.distanciaMaximaDoCheckinMetros`, `Localizacao.swift:46`). Os 100 m que aparecem no app são outra regra: a precisão horizontal máxima da leitura de GPS (`precisaoHorizontalMaximaMetros`, `Localizacao.swift:48`), e não o raio;
   - check-in **manual** confirmado pelo contratante (`checkin_tipo = 'manual'` e `checkin_confirmado_em IS NOT NULL`).

O check-out (`turno.checkout_em`) **não** entra na North Star: o servidor encerra o turno e libera a avaliação sem ele (só a presença verificada abre a avaliação). A taxa de check-out fica como indicador auxiliar (seção 3, KPI 3).

### 2.3 Fórmula Matemática e Consulta SQL
$$ \text{North Star (semana } w\text{)} = \sum_{p \in \text{Posições}} [p.\text{estado} = \text{'cumprida'} \land \text{turno}(p).\text{verificacao} = \text{'verificado'} \land \text{semana}(p.\text{fim\_em}) = w] $$

A semana é a do **fim do turno** (`posicao.fim_em`), no fuso de Brasília; `date_trunc('week', …)` começa a semana na segunda-feira.

```sql
-- North Star por semana (fuso America/Sao_Paulo), sem contas de demonstração e da equipe
SELECT date_trunc('week', p.fim_em AT TIME ZONE 'America/Sao_Paulo')::date AS semana_inicio,
       count(*) AS turnos_concluidos_com_presenca_verificada
  FROM public.turno t
  JOIN public.posicao p       ON p.id = t.posicao_id
  JOIN public.vaga v          ON v.id = p.vaga_id
  JOIN public.profissional pr ON pr.id = p.profissional_id
  JOIN public.usuario up      ON up.id = pr.usuario_id
  JOIN public.usuario uc      ON uc.id = v.publicado_por
 WHERE p.estado = 'cumprida'
   AND t.verificacao = 'verificado'
   AND NOT coalesce(up.demonstracao, false)
   AND NOT coalesce(uc.demonstracao, false)
   AND NOT EXISTS (
     SELECT 1 FROM privado.conta_equipe ce
      WHERE ce.usuario_id IN (up.id, uc.id)
   )
 GROUP BY 1
 ORDER BY 1 DESC;
```

- **Fonte do dado:** `public.turno`, `public.posicao`, `public.vaga`, `public.profissional`, `public.usuario` e `privado.conta_equipe` (esquema em `frila-backend`, `20260922150500_despacho_turno_ocorrencia.sql` e `20260922150400_vaga_e_posicao.sql`).
- **Janela de medição:** Semanal (semanas de 7 dias) e total acumulado do piloto (18 dias).
- **Estado do teste:** os nomes de tabela e coluna foram conferidos contra o `develop` do backend em 15/10/2026. A consulta ainda **não tem teste automatizado** com o seed; o pedido de uma view `metrica.north_star_semanal` com teste pgTAP está no quadro do backend (ver seção 9).

---

## 3. KPIs do Produto

| KPI | Conceito e Importância | Linha de Base (Entrevistas) | Fórmula | Fonte do Dado | Janela |
|---|---|---|---|---|---|
| **1. Taxa de Preenchimento (Fill Rate)** | Proporção de posições ofertadas pelos contratantes que foram preenchidas e confirmadas. Mede a liquidez da oferta. | No WhatsApp, estimava-se ~70% de cobertura, com 30% de vagas sem fechamento. | $\frac{\sum \text{Posições Confirmadas}}{\sum \text{Posições Ofertadas}} \times 100$ | `metrica.funil_por_vaga` (`confirmacoes` e `posicoes_ofertadas`). `confirmacoes` conta toda posição que chegou a ser confirmada, inclusive as canceladas depois; para o preenchimento efetivo, conte `posicao.estado in ('confirmada', 'cumprida')` | Diária e 18 dias |
| **2. Tempo entre Publicação e Confirmação** | Tempo decorrido desde a publicação da vaga até o aceite definitivo da vaga pelo contratante. Medido pela mediana para neutralizar distorções. | No WhatsApp variava de 2 h a mais de 24 h. Sem meta pré-fixada: calibração empírica. | $\text{Mediana}(p.\text{confirmado\_em} - v.\text{publicado\_em})$ | `metrica.funil_confirmacoes` (`duracao_confirmacao_segundos`) | Diária, por estabelecimento e 18 dias |
| **3. Taxa de Comparecimento (Show-up Rate)** | Percentual de profissionais contratados que efetivamente compareceram ao local e efetuaram check-in verificado. Auxiliar: taxa de check-out (turnos verificados com `checkout_em IS NOT NULL`). | Taxa de falta sem aviso prévio ("no-show") no WhatsApp relatada entre 20% e 35% (comparecimento de 65% a 80%). | $\frac{\sum \text{Posições cumpridas com turno verificado}}{\sum \text{Posições cumpridas}} \times 100$ (`posicao.estado = 'cumprida'`; numerador com `turno.verificacao = 'verificado'`) | Consulta direta em `public.posicao` e `public.turno`. **Atenção:** a coluna `checkins` de `metrica.funil_por_vaga` conta qualquer `checkin_em` (inclusive manual ainda sem confirmação do contratante) e `confirmacoes` inclui posições canceladas depois de confirmadas; a razão das duas é só um teto aproximado | Diária e 18 dias |
| **4. Avaliações Positivas Mútuas** | Proporção de turnos concluídos onde ambas as partes registraram avaliação positiva mútua. Mede satisfação e qualidade de par. | Inexistente no mercado informal (feedback ocorre apenas por atrito). | $\frac{\sum \text{Turnos com 2 Avaliações Positivas}}{\sum \text{Turnos com Ambas Avaliações}} \times 100$ | `public.avaliacao` (`turno_id`, `autor_id`, `resposta`) | Acumulada em 18 dias |
| **5. Vagas por Estabelecimento por Semana** | Intensidade de uso da plataforma pelos contratantes ativos. Mede engajamento B2B. | Donos de bares no DF relataram demanda de 2 a 5 extras/frilas por final de semana (sex/sáb/dom). | $\frac{\sum \text{Vagas Publicadas}}{\text{Estabelecimentos com Vagas}} \text{ por semana}$ | `metrica.funil_por_estabelecimento` (`vagas_publicadas`) | Semanal (7 dias) |
| **6. Retenção de 7 e 14 Dias e Recontratação** | Retenção D7 e D14 de usuários ativos e taxa de estabelecimentos que realizam nova contratação dentro do piloto de 18 dias. | Retenção informal baseada em listas estáticas de WhatsApp dos gerentes. | Coorte D7: Ativos em $T$ com nova ação em $[T+6, T+8]$; Coorte D14: nova ação em $[T+13, T+15]$. | `public.vaga.publicado_em`, `public.candidatura.criada_em`, `public.turno.checkin_em` | 7 e 14 dias (D30 vedada) |
| **7. SLA de Despacho de Push (RNF03)** | Envio da notificação aos elegíveis pelo agendador em até 30 segundos da publicação. | Requisito técnico de arquitetura assíncrona (`pg_cron` + `pgmq`). | $\frac{\sum \text{Vagas com Despacho} \le 30\,\text{s}}{\sum \text{Total de Vagas}} \times 100$ | `public.despacho.criado_em` vs `public.vaga.publicado_em` | Tempo real e diária |
| **8. Entrega do Provedor de Push (RNF02)** | 99% das notificações aceitas pelo provedor (FCM / APNs) em até 60 segundos do despacho. | Requisito não-funcional de entrega de notificação de alerta. | $\frac{\sum \text{Notificações Aceitas em } \le 60\,\text{s}}{\sum \text{Notificações Despachadas}} \times 100 \ge 99\%$ | Logs de despacho da Edge Function e provedor FCM/APNs | Diária |
| **9. Integridade da Trilha de Ciclo (RNF13)** | Registros imutáveis de transição de estado sem dados pessoais para auditoria de ciclo. | Requisito de auditoria e conformidade. | $100\%$ das transições de vaga, turno e avaliação auditadas sem falha de integridade. | `privado.auditoria_ciclo` | Contínua |

---

## 4. O Funil Completo do Piloto

### 4.1 Etapas do Funil
O funil de ponta a ponta do Frila compreende 6 etapas obrigatórias:

```
[1. Vaga Publicada] 
       │  Δt1: Despacho (alvo RNF03 ≤ 30 s)
       ▼
[2. Notificações Enviadas] (agrupadas, máx 3 por lote, RN23)
       │  Δt2: Visualização e Decisão de Candidatura
       ▼
[3. Candidaturas Recebidas]
       │  Δt3: Escolha e Confirmação da Posição (RN07/RN10)
       ▼
[4. Confirmação do Turno]
       │  Δt4: Comparecimento e Chegada (tolerância de check-in)
       ▼
[5. Check-in e Execução] (raio ≤ 200 m, RN22, ou manual confirmado)
       │  Δt5: Conclusão do Expediente e Envio de Feedback
       ▼
[6. Avaliação Mútua] (contratante e profissional)
```

### 4.2 Tempos entre Etapas a Medir (Sem Metas Pré-Fixadas)
- $\Delta t_1$ (Publicação $\to$ Notificação): Mede o tempo de processamento do agendador (`despacho.criado_em - vaga.publicado_em`). Meta técnica de RNF03: $\le 30$ s.
- $\Delta t_2$ (Notificação $\to$ Primeira Candidatura): Mede o tempo de reação dos profissionais ao push.
- $\Delta t_3$ (Candidatura $\to$ Confirmação): Mede a velocidade de decisão do contratante ao selecionar o candidato (`posicao.confirmado_em - candidatura.criada_em`, da candidatura do profissional confirmado). A view `metrica.funil_confirmacoes` mede outro intervalo, publicação → confirmação (`posicao.confirmado_em - vaga.publicado_em`), que é o KPI 2.
- $\Delta t_4$ (Início Previsto $\to$ Check-in Real): Mede pontualidade e atrasos no comparecimento (`turno.checkin_em - posicao.inicio_em`; o turno não tem horário próprio, ele vem da posição).
- $\Delta t_5$ (Fim do Turno $\to$ Avaliação): Mede o tempo até o envio da avaliação (`avaliacao.criada_em - posicao.fim_em`).

### 4.3 Consultas SQL Existentes no Backend
O schema `metrica` no Supabase (`frila-backend/supabase/migrations/20260930150000_views_funil_piloto.sql`) já implementa a consolidação estrutural do funil. As views têm teste pgTAP com os cenários do seed (`frila-backend/supabase/tests/490_funil_piloto.sql`, 43 verificações: permissões, números do funil, mediana de confirmação, exclusão de demonstração e equipe, notificações). Acesso só pelo `service_role`.

Duas leituras com cuidado: `checkins` conta todo turno com `checkin_em` (sem filtrar `verificacao = 'verificado'`), e `confirmacoes` conta toda posição com `confirmado_em` (inclui as canceladas depois). Para a North Star e o comparecimento, use as consultas das seções 2.3 e 3.

```sql
-- Visão consolidada do funil geral do piloto
SELECT vagas_publicadas,
       notificacoes_enviadas,
       candidaturas,
       confirmacoes,
       checkins,
       avaliacoes,
       tempo_mediano_confirmacao,
       tempo_mediano_confirmacao_segundos
  FROM metrica.funil_geral;

-- Visão diária para acompanhamento da evolução do piloto
SELECT dia,
       vagas_publicadas,
       notificacoes_enviadas,
       candidaturas,
       confirmacoes,
       checkins,
       avaliacoes,
       tempo_mediano_confirmacao_segundos
  FROM metrica.funil_por_dia
 ORDER BY dia DESC;

-- Visão por estabelecimento para análise de retenção B2B
SELECT estabelecimento_nome,
       vagas_publicadas,
       candidaturas,
       confirmacoes,
       checkins,
       tempo_mediano_confirmacao_segundos
  FROM metrica.funil_por_estabelecimento
 ORDER BY vagas_publicadas DESC;
```

---

## 5. Dicionário de Eventos de Telemetria

O dicionário é fechado e estrito, correspondente ao enum `EventoDeTelemetria` em `iOS/Contrato/openapi.yaml:3808` e `public.evento_de_telemetria` em `20260930180000_telemetria_evento_app.sql:29`.

### 5.1 Regras de Estrutura do Evento (RPC `registrar_evento`)
Conforme o contrato em `iOS/Contrato/openapi.yaml:3184-3226`:
- `evento`: Identificador único do enum (obrigatório).
- `vaga_id`: UUID da vaga associada (opcional / nulo).
- `turno_id`: UUID do turno associado (opcional / nulo).
- `ocorrido_em`: Instante ISO-8601 em que o evento ocorreu no aparelho (permite preservar histórico quando enviado por fila offline; o servidor rejeita datas futuras com erro `422 registro_no_futuro`).
- `usuario_id`: Injetado automaticamente pelo servidor via `auth.uid()`.

### 5.2 Mapeamento Completo dos 14 Eventos

| # | Evento (`evento`) | Etapa do Funil | Quando Dispara (Gatilho no App) | Propriedades Permitidas | Revisão LGPD (`LGPD.md`) | Existe no App Hoje? (Arquivo:Linha) |
|---|---|---|---|---|---|---|
| 1 | `app_aberto` | Abertura | Quando o ciclo de vida do app passa para ativo/primeiro plano. | `ocorrido_em` | Conforme: sem identificadores pessoais além do JWT de sessão. | **Instrumentado.** `App/FrilaApp.swift:387` (`EntradaDoApp` na transição estrita `antiga != .active && nova == .active`, deduplicado na partida). |
| 2 | `cadastro_concluido` | Onboarding | Após a confirmação de criação de conta no onboarding. | `ocorrido_em` | Conforme: nenhum dado de cadastro (nome, e-mail, telefone) é anexado. | **Instrumentado.** `Apresentacao/Fluxos/Autenticacao/CadastroViewModel.swift:103` (`criarConta()`, ponto único com trava deduplicadora). |
| 3 | `permissao_push_negada` | Permissão | Quando a pessoa usuária recusa formalmente a solicitação de notificações do iOS no modal do sistema. | `ocorrido_em` | Conforme: telemetria de diagnóstico do sistema operacional (Art. 7º, IX). | **Instrumentado.** `Apresentacao/Fluxos/Push/PermissaoDePushModelo.swift:65` (`estado == .negada`). |
| 4 | `vaga_vista` | Descoberta | Quando um cartão de vaga entra na viewport visível do feed/mural do profissional. | `vaga_id`, `ocorrido_em` | Conforme: apenas o ID da vaga e timestamp. | **Instrumentado.** `Apresentacao/Fluxos/Profissional/FeedVagasViewModel.swift:69` e `TelaVagas.swift:76` (deduplicado por sessão). |
| 5 | `vaga_detalhe_aberto` | Interesse | Quando a tela de detalhes de uma vaga específica é aberta pelo profissional. | `vaga_id`, `ocorrido_em` | Conforme: apenas ID da vaga. | **Instrumentado.** `Apresentacao/Fluxos/Profissional/DetalheVagaViewModel.swift:46` (`carregar()`, deduplicado na instância). |
| 6 | `candidatura_enviada` | Candidatura | Quando o profissional submete a candidatura com sucesso. | `vaga_id`, `ocorrido_em` | Conforme: nenhum dado de contato é enviado. | **Instrumentado.** `Apresentacao/Fluxos/Profissional/CandidaturaViewModel.swift:145` (`candidatar()`). |
| 7 | `candidatura_retirada` | Candidatura | Quando o profissional cancela voluntariamente sua candidatura pendente. | `vaga_id`, `ocorrido_em` | Conforme: apenas ID da vaga. | **Instrumentado.** `Apresentacao/Fluxos/Profissional/CandidaturaEmSelecao.swift:165` (`retirar()`). |
| 8 | `checkin_tentado` | Presença | Quando o profissional aciona o botão de check-in, antes da validação do raio ou resposta do servidor. | `turno_id`, `ocorrido_em` | Conforme: a coordenada GPS de tentativa **nunca** é enviada (`LGPD.md:37`). Apenas o ID do turno. | **Instrumentado.** `Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:165` (`iniciar(.checkin)`). |
| 9 | `checkin_concluido` | Presença | Quando a resposta de `fazer_checkin` retorna com sucesso (geolocalizado com distância $\le 200$ m validada pelo servidor, RN22, ou registro manual). | `turno_id`, `ocorrido_em` | Conforme: distância em metros é mantida no registro operacional do turno, não na telemetria. | **Instrumentado.** `Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:277` (`checkin = .registrado`). |
| 10 | `checkout_concluido` | Conclusão | Quando a confirmação de encerramento do turno (`fazer_checkout`) é confirmada pelo servidor. | `turno_id`, `ocorrido_em` | Conforme: sem dados pessoais. | **Instrumentado.** `Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:283` (`checkout = .registrado`). |
| 11 | `avaliacao_enviada` | Avaliação | Quando a avaliação da contraparte é submetida com sucesso pelo usuário. | `turno_id`, `ocorrido_em` | Conforme: a nota/resposta permanece na tabela de avaliação; o evento só atesta a conclusão. | **Instrumentado.** `Apresentacao/Fluxos/Profissional/AvaliacaoTurnoViewModel.swift:320` (`salvar()`). |
| 12 | `contato_aberto` | Comunicação | Quando a pessoa clica no botão "Abrir WhatsApp" para falar com a contraparte após o turno confirmado. | `turno_id`, `ocorrido_em` | Conforme: o número de telefone e o link do WhatsApp **nunca** são transmitidos na telemetria (`LGPD.md:35`). | **Instrumentado.** Profissional: `Apresentacao/Fluxos/Profissional/MeuTurnoViewModel.swift:208` (`registrarContatoAberto()`, chamado por `TelaMeuTurno.swift:236`). Contratante: `Apresentacao/Fluxos/Contratante/MinhasVagas.swift:710`. |
| 13 | `acao_enfileirada_offline` | Resiliência | Quando uma tentativa de check-in, check-out ou cancelamento é enfileirada no cache SwiftData devido à ausência de rede. | `turno_id`, `ocorrido_em` | Conforme: diagnóstico de operação offline (Art. 7º, IX). | **Instrumentado.** Ao enfileirar: `Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:329` e `Apresentacao/Fluxos/Cancelamento/CancelamentoViewModel.swift:239`. Ao sincronizar a fila: `Dados/SincronizadorAcoes.swift:74`. |
| 14 | `atualizacao_obrigatoria_exibida` | Integridade | Quando o portão de versão mínima exibe o bloqueio impedindo o uso de versão desatualizada da API. | `ocorrido_em` | Conforme: sem dados pessoais. | **Instrumentado.** `Apresentacao/AtualizacaoObrigatoria.swift:47` (`verificar()`, bloqueio deduplicado). |

---

## 6. Conformidade com a LGPD e Proteção de Dados

### 6.1 Revisão Estrita contra o Dossiê de Privacidade
Conforme detalhado no ROPA do Frila (`iOS/Docs/LGPD.md:14-45`) e na regra RN15:
1. **Sem texto livre:** Nenhum dos eventos aceita campos abertos (`mensagem`, `observacao`, `erro`). Isso elimina a possibilidade de desenvolvedores incluírem nomes, comentários ou dados sensíveis em tempo de execução.
2. **Sem dados de contato:** Números de telefone (usados apenas no WhatsApp do turno confirmado, `ContatoDTO.dominio()`), e-mails e nomes são terminantemente proibidos na carga dos eventos.
3. **Sem coordenadas de GPS na telemetria:** nenhum evento leva latitude ou longitude. No check-in e no check-out, a leitura de GPS (`PresencaDoTurnoViewModel.swift:244`) fica no aparelho: o app calcula a distância e envia ao servidor só a distância em metros (`fazer_checkin(turno, distancia_m, registrado_em)`), gravada no turno (`checkin_distancia_m`), fora da telemetria. Coordenada existe no servidor em outro tratamento, fora deste plano: o ponto de referência do cadastro e o ponto da vaga (`vaga.ponto`), descritos em `LGPD.md`.
4. **Pseudônimos, não anônimos:** o evento não leva nome, telefone nem e-mail, mas o servidor grava o `usuario_id` (de `auth.uid()`). O evento é ligado à conta: é dado pessoal pseudonimizado, tratado com a mesma base e retenção da telemetria descritas em `LGPD.md`.
5. **Ciclo de vida e retenção:** os eventos de `public.evento_app` com mais de 90 dias são apagados pela rotina diária `privado.executar_retencao_diaria()` (pg_cron), que chama `privado.limpar_eventos_app(90)` (`20260930180000_telemetria_evento_app.sql:151`). A tabela tem RLS: o app só grava pela RPC `registrar_evento` e não lê; a leitura é só do `service_role` e das views do schema `metrica`.

---

## 7. Rastreamento de Campanhas na App Store (Canais de Aquisição)

Para avaliar os canais de aquisição durante os 18 dias de piloto sem ferir a privacidade nem exigir SDKs invasivos de terceiros, o Frila utiliza os parâmetros de campanha nativos do **App Store Connect Campaign Links**:

| Canal | Público-Alvo no DF | Formato do Link de Campanha | Parâmetro `ct` |
|---|---|---|---|
| **1. Grupos de WhatsApp** | Grupos regionais de garçons, bartenders e cozinheiros (Plano Piloto, Taguatinga, Águas Claras). | `https://apps.apple.com/app/id[APP_ID]?pt=[PROVIDER]&ct=grupos_whatsapp_df&mt=8` | `grupos_whatsapp_df` |
| **2. Instagram Orgânico e Anúncios** | Profissionais e estabelecimentos atingidos por campanhas locais no feed/stories. | `https://apps.apple.com/app/id[APP_ID]?pt=[PROVIDER]&ct=instagram_df&mt=8` | `instagram_df` |
| **3. Entidades Parceiras (Abrasel-DF / Sindicatos)** | Bares e restaurantes associados contatados via parcerias institucionais. | `https://apps.apple.com/app/id[APP_ID]?pt=[PROVIDER]&ct=parceiros_abrasel_df&mt=8` | `parceiros_abrasel_df` |
| **4. Prospecção Direta Presencial** | Visitas presenciais do time Frila aos estabelecimentos comerciais em polos gastronômicos. | `https://apps.apple.com/app/id[APP_ID]?pt=[PROVIDER]&ct=contato_direto_bares&mt=8` | `contato_direto_bares` |

*Privacidade:* A atribuição ocorre de forma agregada no painel de App Analytics da Apple, sem qualquer coleta de identificadores de publicidade (IDFA), sem ATT e em conformidade estrita com as diretrizes da Apple e a LGPD.

---

## 8. Diagnóstico: O que Falta Instrumentar para Haver Número em 27/11

### 8.1 O Que o Servidor Já Mede Sozinho
O backend no Supabase já é autossuficiente para medir todas as transações de ciclo gravadas no banco de dados. Através das views em `metrica.funil_*`:
- Vagas publicadas e posições ofertadas (`public.vaga`).
- Notificações enviadas aos elegíveis (`public.notificacao` e `public.despacho`).
- Candidaturas registradas (`public.candidatura`).
- Posições confirmadas e tempo de confirmação (`public.posicao.confirmado_em`).
- Check-ins e check-outs realizados (`public.turno`).
- Avaliações submetidas (`public.avaliacao`).
- Desempenho e SLA do servidor (RNF02, RNF03 e auditoria imutável RNF13).

### 8.2 O Que Depende da Instrumentação do App iOS
Situação em 15/10/2026: os 14 eventos estão ligados no app desde 14/10 (contrato 0.2.41), pelo `RegistradorDeTelemetria`, que chama a RPC `registrar_evento` e nunca quebra o fluxo do usuário quando falha. O dicionário foi aprovado em 15/10 (seção 9).

Falta uma coisa: o registrador ainda **não guarda o evento quando o aparelho está sem rede**, e o evento que falha se perde. A correção (fila persistente por conta, reenvio com o `ocorrido_em` original) está em PR próprio do frontend (`fix/ios-telemetria-fila-offline`). Sem ela, os números abaixo saem subcontados quando há falta de sinal.

Os números que só existem por causa da instrumentação do app são:
1. **Taxa de Conversão do Feed (CTR):** Saber quantas vagas foram efetivamente visualizadas no mural (`vaga_vista`) e quantas tiveram o detalhe aberto (`vaga_detalhe_aberto`). Sem isso, não há como distinguir se a falta de candidaturas decorre de desinteresse ou de vagas que não apareceram na tela.
2. **Gargalo de Notificações Negadas:** Medir quantas pessoas recusaram o push no iOS (`permissao_push_negada`), impossibilitando o recebimento de despachos da vaga.
3. **Atrito de Check-in no Local:** Medir tentativas frustradas de check-in (`checkin_tentado` vs `checkin_concluido`), diagnosticando se profissionais tiveram dificuldades com sinal ou precisão de GPS no raio do bar.
4. **Uso de Comunicação Externa:** Medir a frequência de uso do botão do WhatsApp (`contato_aberto`).
5. **Comportamento em Instabilidade de Rede:** Medir ações que entraram na fila offline (`acao_enfileirada_offline`).

### 8.3 Plano de Ação para Engenharia iOS
| Passo | Estado em 15/10/2026 |
|---|---|
| 1. DTO `RegistrarEvento` e chamada RPC `registrar_evento` no `ApiCliente` | Feito (contrato 0.2.41). |
| 2. `RegistradorDeTelemetria` assíncrono e tolerante a falha | Feito. |
| 3. Os 14 gatilhos nos pontos da seção 5.2 | Feito em 14/10 (Trovão). |
| 4. Fila offline da telemetria (guardar e reenviar com o `ocorrido_em` original) | Em PR (`fix/ios-telemetria-fila-offline`). |
| 5. Conferir no frila-dev que os eventos do TestFlight aparecem em `metrica.eventos_app_por_dia` | Depois do próximo TestFlight. |
| 6. View `metrica.north_star_semanal` com teste pgTAP, e filtro de verificação em `checkins` | Pedido ao backend por cartão no Trello. |

---

## 9. Aprovações e Pendências

| Item | Responsável | Estado |
|---|---|---|
| **Fórmulas da North Star e dos KPIs** | Nick Fury (dev iOS do Cauê, por delegação dele) | **Aprovado em 15/10/2026**, com as correções deste documento: raio de 200 m (RN22), North Star por `posicao.estado = 'cumprida'` e `turno.verificacao = 'verificado'`, nomes de coluna conferidos no `develop` do backend. |
| **Dicionário de eventos (iOS e backend)** | Nick Fury | **Aprovado em 15/10/2026.** Os 14 nomes batem em três lugares (este plano, `openapi.yaml` e o enum SQL). Única objeção, do iOS: fila offline, corrigida em PR próprio. |
| **Revisão de dado pessoal** | Nick Fury, no lugar da Júlia, por decisão do Cauê em 15/10/2026 | **Aprovado.** O evento leva só `evento`, `vaga_id`, `turno_id` e `ocorrido_em`; sem GPS, sem texto livre, sem contato. É pseudônimo (`usuario_id` pelo login), com retenção de 90 dias. O responsável pelo tratamento é pessoa física (Cauê Carneiro Kilanovic), sem DPO nomeado. |
| **Consulta da North Star testada com o seed** | Backend (por cartão) | As views do funil têm teste (`490_funil_piloto.sql`). A consulta da seção 2.3 vai virar a view `metrica.north_star_semanal` com teste pgTAP, pedida ao backend. |
| **Configuração de Campanhas App Store** | Cauê | Criar os links de campanha no App Store Connect antes do início do piloto. |
| **Aprovação executiva do plano** | Fabrício / Sócios | Validação para a apresentação na Academy em 27/11. |

---

## Histórico de Alterações

| Data | Autor | Alteração |
|---|---|---|
| 2026-10-12 | Doutor Estranho | Criação do plano de métricas: North Star, KPIs de até 18 dias, funil do piloto, dicionário de 14 eventos com mapeamento no código, conformidade LGPD e diagnóstico para 27/11 (cartão qorNKAlB, T-0017). |
| 2026-10-14 | Trovão | Fiação dos 14 eventos de telemetria nas telas e ViewModels (T-0017, contrato 0.2.41, RN15, RNF08). |
| 2026-10-15 | Nick Fury | Fórmulas conferidas contra o esquema real do backend: raio de 200 m (RN22) no lugar de 100 m; North Star por posição cumprida e turno verificado (sem `turno.status` nem `turno.profissional_id`, que não existem); show-up com a ressalva das views; nomes de coluna dos Δt corrigidos; GPS, pseudônimos e retenção reescritos; estado da instrumentação e aprovações atualizados (cartão qorNKAlB, critérios 1 a 5). |
