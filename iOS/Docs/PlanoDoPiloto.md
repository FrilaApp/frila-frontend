# Plano de Operação do Piloto — Frila DF (13/11 a 04/12)

Documento operacional do piloto do Frila no Distrito Federal, cobrindo o período de 13/11/2026 a 04/12/2026. Alinhado aos requisitos de produto (Visão 1.2), à conformidade com a LGPD (`iOS/Docs/LGPD.md`), às diretrizes de suporte e moderação (`iOS/Docs/AjudaESuporte.md`, Diretriz 1.2 da App Store) e ao plano de métricas oficial (`iOS/Docs/PlanoDeMetricas.md`, cartão T-0017).

---

## 1. Visão Geral, Datas e Regras Operacionais

### 1.1 Calendário Operacional
- **Início da Operação:** 13/11/2026 (sexta-feira).
- **Congelamento dos Dados para Apresentação:** 01/12/2026 (congelamento das métricas para análise e consolidação final).
- **Encerramento Formal do Piloto:** 04/12/2026 (sexta-feira).
- **Duração Total:** 22 dias corridos de operação (com janelas de medição de no máximo 18 dias, conforme `PlanoDeMetricas.md:1.2`).

### 1.2 Escopo Geográfico e Segmento
- **Região:** Distrito Federal (Brasília — polos do Plano Piloto: Asa Sul e Asa Norte; Águas Claras; Taguatinga; Sudoeste).
- **Segmento:** Bares, restaurantes, hamburguerias, cafeterias e serviços de eventos gastronômicos.

### 1.3 Regras Operacionais Duras
1. **Gratuidade total:** Durante o piloto, o aplicativo é 100% gratuito. Não há cobrança de taxa de adesão, comissão ou intermediação para estabelecimentos nem para profissionais.
2. **Pagamento direto fora do app:** O pagamento do cachê/diária é acordado entre as partes e efetuado diretamente pelo contratante ao profissional no encerramento do expediente. O Frila não processa valores financeiros (`AjudaESuporte.md:72`).
3. **Maioridade estrita (18+):** Elegibilidade restrita a maiores de 18 anos (`Classificacao18ECA.md`, Art. 7º, II da LGPD). Menores não são admitidos no piloto.
4. **Sem plantão ao vivo:** O Frila não disponibiliza suporte em tempo real ou chat ao vivo (`Visão 1.2`). O canal de atendimento é assíncrono via e-mail oficial (`suporte@frila.app`).
5. **Comunicação sem grupos expostos:** Para preservar a privacidade e não expor telefones e dados pessoais entre participantes (Art. 37 da LGPD, `LGPD.md:35`), toda comunicação institucional ocorre por e-mail ou lista individual de transmissão, vedada a criação de grupos coletivos de WhatsApp.

---

## 2. Objetivos e Metas Vinculados ao Plano de Métricas

Todas as metas operacionais do piloto são vinculadas às seções e KPIs definidos em `iOS/Docs/PlanoDeMetricas.md`:

| Meta Operacional | KPI Vinculado | Seção em `PlanoDeMetricas.md` | Linha de Base (Entrevistas) | Meta Alvo do Piloto |
|---|---|---|---|---|
| **North Star do Piloto** | Turnos concluídos com presença verificada por semana no DF | Seção 2 (`PlanoDeMetricas.md#2`) | `[A DEFINIR]` (a extrair das entrevistas com bares/restaurantes) | `[A DEFINIR]` turnos verificados/semana |
| **Meta 1: Liquidez da Oferta** | Taxa de Preenchimento de Vagas (Fill Rate) | Seção 3, KPI 1 (`PlanoDeMetricas.md#3`) | `[A DEFINIR]` (cobertura relatada no WhatsApp, a extrair das entrevistas) | $\ge$ `[A DEFINIR]`% de confirmação |
| **Meta 2: Presença no Turno** | Taxa de Comparecimento (Show-up Rate) | Seção 3, KPI 3 (`PlanoDeMetricas.md#3`) | `[A DEFINIR]` (frequência de faltas relatada no WhatsApp, a extrair das entrevistas) | $\ge$ `[A DEFINIR]`% com check-in verificado |
| **Meta 3: Agilidade de Resposta** | Tempo Mediano de Confirmação | Seção 3, KPI 2 (`PlanoDeMetricas.md#3`) | `[A DEFINIR]` (tempo de resolução no WhatsApp, a extrair das entrevistas) | Mediana observada $\le$ `[A DEFINIR]` |
| **Meta 4: Satisfação de Par** | Avaliações Positivas Mútuas | Seção 3, KPI 4 (`PlanoDeMetricas.md#3`) | `[A DEFINIR]` (feedback em canais informais, a extrair das entrevistas) | $\ge$ `[A DEFINIR]`% de avaliações mútuas positivas |
| **Meta 5: Engajamento B2B** | Vagas por Estabelecimento por Semana | Seção 3, KPI 5 (`PlanoDeMetricas.md#3`) | `[A DEFINIR]` (demanda de extras por fim de semana, a extrair das entrevistas) | Média de `[A DEFINIR]` vagas/semana por casa |
| **Meta 6: Recontratação** | Retenção D7 / Recontratação pelo App | Seção 3, KPI 6 (`PlanoDeMetricas.md#3`) | `[A DEFINIR]` (recontratação informal, a extrair das entrevistas) | $\ge$ `[A DEFINIR]`% de contratantes com $\ge 2$ turnos |
| **Meta 7: SLA de Despacho** | RNF03 (Despacho $\le 30$ s da publicação) | Seção 3, KPI 7 (`PlanoDeMetricas.md#3`) | Requisito técnico RNF03 (`iOS/Contrato/openapi.yaml:1379`) | $100\%$ das vagas despachadas em $\le 30$ s |
| **Meta 8: Entrega de Push** | RNF02 (Entrega provedor $\le 60$ s) | Seção 3, KPI 8 (`PlanoDeMetricas.md#3`) | Requisito técnico RNF02 (`iOS/Contrato/openapi.yaml:2457, 2496`) | $\ge 99\%$ aceitas pelo provedor em $\le 60$ s |

---

## 3. Recrutamento e Ativação de Participantes

### 3.1 Participantes Alvo
- **Contratantes:** Meta de `[A DEFINIR]` estabelecimentos gastronômicos parceiros cadastrados e ativos no DF.
- **Profissionais:** Meta de `[A DEFINIR]` profissionais (garçons, atendentes, bartenders, ajudantes de cozinha) com perfis completos e elegíveis.

### 3.2 Canais de Recrutamento e Links de Campanha
A aquisição de participantes utiliza os links rastreáveis da App Store (`PlanoDeMetricas.md:7`):
1. **Entidades do Setor (Abrasel-DF e sindicatos patronais):** Divulgação institucional para bares associados via `ct=parceiros_abrasel_df`.
2. **Grupos de Categoria:** Divulgação direcionada a profissionais em grupos do DF via `ct=grupos_whatsapp_df`.
3. **Visitas Presenciais:** Prospecção e apresentação direta em polos gastronômicos (Asa Sul/Norte e Águas Claras) via `ct=contato_direto_bares`.
4. **Mídia Social Regional:** Divulgação no Instagram focada em trabalhadores temporários via `ct=instagram_df`.

### 3.3 Processo de Ativação (Onboarding Assistido)
- Instalação da versão do piloto do app no iOS (via TestFlight ou App Store piloto).
- Configuração de perfil: definição de funções, horários e ponto base para profissionais; endereço físico e dados operacionais para estabelecimentos.
- Concessão de permissões: verificação de ativação de notificações push (monitoramento de `permissao_push_negada`, `PlanoDeMetricas.md:5.2`).
- Esclarecimento explícito de que o suporte opera de forma assíncrona, sem garantias de atendimento presencial ou plantão em tempo real.

---

## 4. Rotina Semanal da Equipe Frila

Para manter a operação estável, garantir conformidade e acompanhar os indicadores sem sobrecarregar o time:

| Periodicidade | Horário / Momento | Atividade Operacional | Ferramenta / Fonte | Indicador Acompanhado |
|---|---|---|---|---|
| **Diária** | Manhã (até 10h) | Triagem da caixa de suporte e denúncias. | `suporte@frila.app` e RPC `situacao_da_conta`. | SLA de moderação em até 24h (Diretriz 1.2 da App Store, `AjudaESuporte.md:59`). |
| **Diária** | Fim de tarde (16h) | Verificação de vagas publicadas e integridade do despacho. | Painel Supabase e view `metrica.funil_por_dia`. | RNF03 ($\le 30$ s) e taxa de preenchimento (`PlanoDeMetricas.md:3`). |
| **Sex / Sáb / Dom** | Noite (19h às 23h) | Acompanhamento de turnos ativos e check-ins no local. | View `metrica.funil_por_vaga` (`checkins` vs `confirmacoes`). | Comparecimento (`PlanoDeMetricas.md:3`), ausência de falhas GPS e fila offline. |
| **Segunda-feira** | Manhã (10h) | Reunião semanal de métricas e alinhamento do piloto. | Views `metrica.funil_geral` e `metrica.funil_por_estabelecimento`. | North Star semanal (`PlanoDeMetricas.md:2`), retenção D7 e tempo mediano. |
| **Quarta-feira** | Tarde (15h) | Revisão de contestações, bloqueios e relatos de ocorrência. | Tabelas `public.ocorrencia` e `privado.auditoria_ciclo`. | Integridade do ciclo (RNF13) e satisfação mútua (`PlanoDeMetricas.md:3`). |

---

## 5. Critérios de Sucesso e Parada do Piloto

### 5.1 Critérios de Sucesso
1. **Liquidez sustentada:** Atingimento de $\ge$ `[A DEFINIR]`% na taxa de preenchimento e $\ge$ `[A DEFINIR]`% na taxa de comparecimento.
2. **Meta North Star atingida:** Conclusão de $\ge$ `[A DEFINIR]` turnos com presença comprovada por semana.
3. **Privacidade e Segurança:** Zero incidentes de vazamento ou exposição de dados pessoais (`LGPD.md`).
4. **Estabilidade Técnica:** Estabilidade de sessões $\ge$ `[A DEFINIR]`% livre de crashes no Crashlytics e conformidade plena com RNF02 e RNF03.

### 5.2 Critérios de Parada Imediata (Contingência / Kill Switch)
O piloto será interrompido ou pausado preventivamente caso ocorra:
1. **Incidente de segurança ou violação de dados:** Qualquer suspeita ou confirmação de vazamento de dados pessoais aciona a Fase 1 do Plano de Resposta a Incidentes (`LGPD.md:129-134`).
2. **Colapso no sistema de notificações:** Interrupção total do envio de pushes via APNs/FCM superior a 24 horas consecutivas.
3. **Instabilidade crítica do binário:** Crash contínuo no fluxo principal (candidatura ou check-in) afetando mais de `[A DEFINIR]`% dos usuários ativos sem resolução por hotfix em 12 horas.
4. **Abuso ou risco à integridade física:** Ocorrências graves que ultrapassem a capacidade de moderação e triagem da equipe.

---

## 6. Roteiro de Incidentes Operacionais

- **Incidente 1: Instabilidade do Servidor / Backend Fora do Ar:**
  - *Decisor:* `[A DEFINIR]` (Liderança Técnica).
  - *Procedimento:* Confirmar diagnóstico no Supabase; comunicar os participantes ativos por e-mail; orientar profissionais a manterem o app aberto para acionar a fila offline (`CacheSwiftData.swift:246`).
  - *Tempo limite de comunicação:* Até 1 hora após a confirmação da indisponibilidade.
- **Incidente 2: Falha no Despacho de Notificações (Push parado):**
  - *Decisor:* `[A DEFINIR]`.
  - *Procedimento:* Reiniciar agendador de despacho (`pg_cron`/Edge Function); orientar participantes a consultarem manualmente a aba de Vagas abertas no aplicativo.
- **Incidente 3: Impossibilidade de Check-in no Estabelecimento (Sem GPS / Sinal):**
  - *Procedimento:* O app permite acionar a confirmação manual pelo contratante (`confirmar_checkin_manual` no contrato). Se a falha persistir, o turno é documentado via suporte assíncrono para validação manual pela equipe Frila.

---

## 7. Escala Operacional da Equipe Frila (13/11 a 04/12)

Escala de responsabilidade para triagem da caixa de suporte (`suporte@frila.app`), moderação de denúncias (SLA 24h da Diretriz 1.2 da App Store) e monitoramento de infraestrutura. Cobre todos os 22 dias, incluindo fins de semana e os feriados de 20/11 (Consciência Negra) e 30/11 (Dia do Evangélico / DF):

| Data | Dia / Evento | Triagem de Suporte e Denúncias (SLA 24h) | Monitoramento Técnico e Métricas |
|---|---|---|---|
| 13/11/2026 | Sex (Início do Piloto) | `[A DEFINIR]` | `[A DEFINIR]` |
| 14/11/2026 | Sáb | `[A DEFINIR]` | `[A DEFINIR]` |
| 15/11/2026 | Dom (Fim de Semana 1) | `[A DEFINIR]` | `[A DEFINIR]` |
| 16/11/2026 | Seg (Reunião Semanal) | `[A DEFINIR]` | `[A DEFINIR]` |
| 17/11/2026 | Ter | `[A DEFINIR]` | `[A DEFINIR]` |
| 18/11/2026 | Qua | `[A DEFINIR]` | `[A DEFINIR]` |
| 19/11/2026 | Qui | `[A DEFINIR]` | `[A DEFINIR]` |
| 20/11/2026 | Sex (**Feriado Nacional - Consciência Negra**) | `[A DEFINIR]` | `[A DEFINIR]` |
| 21/11/2026 | Sáb | `[A DEFINIR]` | `[A DEFINIR]` |
| 22/11/2026 | Dom (Fim de Semana 2) | `[A DEFINIR]` | `[A DEFINIR]` |
| 23/11/2026 | Seg (Reunião Semanal) | `[A DEFINIR]` | `[A DEFINIR]` |
| 24/11/2026 | Ter | `[A DEFINIR]` | `[A DEFINIR]` |
| 25/11/2026 | Qua | `[A DEFINIR]` | `[A DEFINIR]` |
| 26/11/2026 | Qui | `[A DEFINIR]` | `[A DEFINIR]` |
| 27/11/2026 | Sex (**Apresentação Academy**) | `[A DEFINIR]` | `[A DEFINIR]` |
| 28/11/2026 | Sáb | `[A DEFINIR]` | `[A DEFINIR]` |
| 29/11/2026 | Dom (Fim de Semana 3) | `[A DEFINIR]` | `[A DEFINIR]` |
| 30/11/2026 | Seg (**Feriado DF - Dia do Evangélico**) | `[A DEFINIR]` | `[A DEFINIR]` |
| 01/12/2026 | Ter (**Congelamento dos Dados**) | `[A DEFINIR]` | `[A DEFINIR]` |
| 02/12/2026 | Qua | `[A DEFINIR]` | `[A DEFINIR]` |
| 03/12/2026 | Qui | `[A DEFINIR]` | `[A DEFINIR]` |
| 04/12/2026 | Sex (**Encerramento Oficial**) | `[A DEFINIR]` | `[A DEFINIR]` |

---

## 8. Mensagens-Modelo para Comunicação com Participantes

Modelos redigidos em português simples, sem promessa de tempo, sem dados pessoais e preparados para envio individual por e-mail ou lista de transmissão direta:

### 8.1 Mensagem de Convite
> **Assunto:** Participe do piloto do Frila em Brasília
>
> Olá!
>
> Estamos iniciando o piloto do Frila no Distrito Federal para conectar bares, restaurantes e eventos a profissionais para turnos extras de trabalho.
>
> O uso do aplicativo é totalmente gratuito durante o piloto. As vagas e confirmações ocorrem dentro da plataforma, e o pagamento da diária é feito diretamente pelo contratante ao término do expediente.
>
> Para instalar a versão do piloto no seu iPhone, acesse o link oficial:
> `https://frila.app/piloto`
>
> Em caso de dúvidas, nossa equipe atende pelo e-mail suporte@frila.app.

### 8.2 Mensagem de Boas-Vindas e Primeiros Passos
> **Assunto:** Boas-vindas ao piloto do Frila
>
> Olá!
>
> Seu cadastro no piloto do Frila foi concluído.
>
> Para começar a usar:
> 1. Mantenha as notificações ativadas no seu iPhone para receber avisos de vagas e confirmações de turnos.
> 2. Se você é profissional: confira as funções cadastradas e a distância máxima no seu perfil.
> 3. Se você é contratante: publique as vagas com antecedência com horário, função e valor da diária.
>
> O Frila conecta estabelecimentos e profissionais; a combinação de trabalho e o acerto de valores ocorrem diretamente entre as partes.
>
> Nosso canal oficial de ajuda é suporte@frila.app.

### 8.3 Mensagem de Lembrete Operacional de Turno
> **Assunto:** Lembrete do seu turno confirmado no Frila
>
> Olá!
>
> Lembramos que você tem um turno de trabalho confirmado pelo Frila:
> - Planeje sua chegada com antecedência e confirme o endereço do local.
> - Ao chegar ao estabelecimento, abra o aplicativo e registre o check-in na tela do turno.
> - Se houver imprevisto ou necessidade de cancelamento, cancele pelo aplicativo com a maior antecedência possível para liberar a vaga para outro profissional.
>
> Tenha um excelente turno de trabalho!

### 8.4 Mensagem de Encerramento e Agradecimento
> **Assunto:** Encerramento do piloto do Frila — obrigado pela participação
>
> Olá!
>
> Encerramos hoje o período do piloto do Frila em Brasília.
>
> Agradecemos muito a sua participação e o tempo dedicado ao uso do aplicativo. Seu retorno e a utilização no dia a dia foram essenciais para aperfeiçoarmos a plataforma antes do lançamento oficial.
>
> Avisaremos em breve sobre a disponibilidade do Frila na App Store.
>
> Um abraço,
> Equipe Frila (suporte@frila.app)

---

## 9. Pendências e Responsabilidades (Em Aberto)

Os itens abaixo dependem de definições nominais e aprovação dos responsáveis e constam como pendências abertas:

| Pendência | Responsável | Ação Necessária |
|---|---|---|
| **Aprovação do Plano pelos Sócios** | Júlia, Cauê, Fabrício e demais sócios | Aprovação formal dos cinco sócios do Frila até 06/11 (Critério Trello jffFlUZ9). |
| **Definição Nominal da Escala** | Júlia e Cauê | Substituir os marcadores `[A DEFINIR]` pelos nomes dos membros da equipe na escala de 13/11 a 04/12. |
| **Extração de Linhas de Base e Calibração de Metas** | Júlia e Cauê | Extrair das entrevistas qualitativas as linhas de base (frequência de faltas, tempo no WhatsApp) e definir os valores numéricos `[A DEFINIR]` das metas e critérios. |
| **Inclusão no Deck da Review 2** | Júlia e Cauê | Citar o resumo das datas, metas e escala operacional no deck da Review 2 da Academy. |

---

## Histórico de Alterações

| Data | Autor | Alteração |
|---|---|---|
| 2026-10-12 | Doutor Estranho | Elaboração do plano de operação do piloto: calendário 13/11 a 04/12, metas vinculadas ao PlanoDeMetricas.md, rotina semanal, critérios de parada, escala com [A DEFINIR], mensagens-modelo e contingência (cartão jffFlUZ9, S3). |
