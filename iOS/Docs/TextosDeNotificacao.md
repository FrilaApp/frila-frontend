# Textos de Notificação e Permissões (Cartão VyY2SGsX)

Este documento especifica os textos, gatilhos, regras de exibição e roteamento de todas as notificações push do Frila, bem como das telas de permissão de notificações, aviso fixo de notificação desativada e telas de vaga indisponível no aplicativo iOS.

---

## 1. Regra de Partida e Geometria da Tela Bloqueada (iPhone SE 3ª Geração)

### 1.1 Aparelho e Geometria de Referência
O menor aparelho iOS suportado pelo Frila é o **iPhone SE (3ª geração)**, com display Retina de 4,7 polegadas, resolução de 750 × 1334 pixels e largura de viewport de **375 pt**.

### 1.2 Fonte da Regra e Justificativa de Engenharia
- **Fonte normativa:** Apple Human Interface Guidelines (HIG) — Seção *Notifications* (*Designing Notifications*):
  > *"Keep content brief. People scan notifications quickly... limit title to a single line and message to a few lines."*
- **Largura e densidade:** Na tela bloqueada do iOS com Dynamic Type padrão (*Large* / 100%), o banner de notificação possui margens laterais de 16 pt de cada lado, área do ícone do aplicativo e rótulo de tempo relativo. A área útil horizontal para o texto é de aproximadamente 280 a 300 pt.
- **Título (SF Pro Semibold 15–17 pt):** Uma única linha acomoda com segurança entre 35 e 40 caracteres antes de sofrer reticências (*truncation* com `...`).
  - **Regra de partida para Título:** **≤ 40 caracteres**.
- **Corpo (SF Pro Regular 15 pt):** Sem expansão manual, o banner compacto da tela bloqueada exibe até 2 linhas completas (aproximadamente 50 a 55 caracteres por linha em tipografia proporcional). A terceira linha pode ser parcialmente oculta ou truncada caso o título ocupe espaço adicional.
  - **Regra de partida para Corpo:** **≤ 110 caracteres**.

---

## 2. Resolução dos Três Conflitos do Cartão (Sprint 0 / Backlog v1.2.1)

O cartão `VyY2SGsX` registra três conflitos identificados nas auditorias de produto e requisitos. Todos foram analisados e resolvidos nas decisões do Sprint 0 (cartão Trello `8zLfn0mt`, reunião de 28/09/2026, homologada no Backlog v1.2.1 e Requisitos v1.4.0):

### Conflito 1: Ação interativa "Aceitar Turno" na notificação (US10) vs. Aviso da RN10
- **Conflito:** A história de usuário US10 previa uma ação rápida interativa diretamente no banner da notificação push (botão "Aceitar Turno"). Contudo, a Regra de Negócio RN10 determina que antes de qualquer confirmação de turno o profissional deve visualizar o endereço, horários, valor líquido e o aviso de responsabilidade/regras de cancelamento.
- **Resolução aprovada:** Nenhuma ação interativa ou botão no push na versão v1.0 (em total alinhamento também com a pendência técnica B08: sem categoria interativa e sem autorização *Time Sensitive*). O toque no push abre obrigatoriamente a tela de detalhe da vaga dentro do app (`DestinoDaVagaDoAviso` / `TelaDetalheVaga`), onde o aviso obrigatório da RN10 é exibido antes de o profissional se candidatar ou aceitar.
- **Fontes:** Cartão de Produto `8zLfn0mt` (Decisão de 28/09/2026, item 6); Backlog v1.2.1; Documento de Requisitos v1.4.0 (RN10); Arquitetura / Pendências Técnicas (B08).

### Conflito 2: Telefone de contato no lembrete (RF12) vs. Janela de 7 dias e persistência na Central (RN10 / RN15)
- **Conflito:** O Requisito Funcional RF12 previa telefone de contato no texto dos lembretes de 24h e 3h. No entanto, notificações push permanecem na Central de Notificações por tempo indeterminado e são visíveis na tela bloqueada sem autenticação, violando a RN10 (contato liberado apenas até 7 dias após o turno) e a RN15 (privacidade estrita de dados pessoais, sem PII em payloads de push ou tela bloqueada).
- **Resolução aprovada:** Nenhum push contém telefone ou e-mail. Os lembretes apenas informam o horário e local aproximado, orientando abrir o app ("Toque para ver endereço e contato"). O acesso aos dados de contato telefônico e WhatsApp é fornecido exclusivamente dentro do app pelo endpoint seguro `contato_do_turno`, que exige conta ativa e autenticada e expira automaticamente 7 dias após o encerramento do turno.
- **Fontes:** Cartão de Produto `8zLfn0mt` (Decisão de 28/09/2026, item 6); Contrato da API OpenAPI 0.2.27/0.2.38 (`/rpc/contato_do_turno`, B10); Requisitos v1.4.0 (RN10, RN15); `iOS/Docs/Push.md`.

### Conflito 3: Funcionalidade e notificação "Estou a caminho" (US14)
- **Conflito:** A história US14 previa aviso ativo emitido pelo profissional informando ao contratante que estava a caminho do estabelecimento.
- **Resolução aprovada:** Entra na v1.0 por decisão de 13/10 (escopo). O botão "Estou a caminho" fica disponível na tela Meu turno durante a janela de 3 h antes até 15 min após o início do turno, sem check-in realizado.
- **Fontes:** Escopo v1.0 do Frila (`frila-docs/produto/05-ESCOPO-DO-MVP.md`, linhas 68 e 93, decisão de 13/10/2026); Contrato da API OpenAPI 0.2.25/0.2.38 (`/rpc/avisar_a_caminho`, US14, RF12).

---

## 3. Inventário de Tipos de Notificação no Aplicativo e Backend

Todos os 19 tipos de aviso suportados pela plataforma estão mapeados e implementados nos seguintes arquivos do repositório:

| Tipo (`public.tipo_notificacao`) | Onde está declarado no app | Onde está documentado no contrato | Onde é roteado no iOS | Onde é formatado no backend |
|---|---|---|---|---|
| `vaga` | `iOS/Sources/Dominio/AvisoDePush.swift:5` | `iOS/Contrato/openapi.yaml:3804` | `iOS/Sources/Apresentacao/Fluxos/Push/RoteadorDePush.swift:20` | `supabase/functions/enviar-push/index.ts:280` |
| `vagas_agrupadas` | `iOS/Sources/Dominio/AvisoDePush.swift:6` | `iOS/Contrato/openapi.yaml:3804` | `iOS/Sources/Apresentacao/Fluxos/Push/RoteadorDePush.swift:25` | `supabase/functions/enviar-push/index.ts:309` |
| `vaga_sem_elegiveis` | `iOS/Sources/Dominio/AvisoDePush.swift:7` | `iOS/Contrato/openapi.yaml:3804` | `iOS/Sources/Apresentacao/Fluxos/Contratante/RoteadorDoContratante.swift:46` | `supabase/migrations/20260929110000_rodada_de_despacho.sql:317` |
| `confirmacao` | `iOS/Sources/Dominio/AvisoDePush.swift:8` | `iOS/Contrato/openapi.yaml:3794,3804` | `iOS/Sources/Apresentacao/Fluxos/Push/RoteadorDePush.swift:27` | `supabase/functions/enviar-push/index.ts:322` |
| `lembrete_24h` | `iOS/Sources/Dominio/AvisoDePush.swift:9` | `iOS/Contrato/openapi.yaml:3804` | `iOS/Sources/Apresentacao/Fluxos/Push/RoteadorDePush.swift:27` | `supabase/migrations/20260928230000_regiao_administrativa.sql:815` |
| `lembrete_3h` | `iOS/Sources/Dominio/AvisoDePush.swift:10` | `iOS/Contrato/openapi.yaml:3804` | `iOS/Sources/Apresentacao/Fluxos/Push/RoteadorDePush.swift:27` | `supabase/migrations/20260928230000_regiao_administrativa.sql:815` |
| `inicio_sem_checkin` | `iOS/Sources/Dominio/AvisoDePush.swift:11` | `iOS/Contrato/openapi.yaml:3805` | `iOS/Sources/Apresentacao/Fluxos/Push/RoteadorDePush.swift:27` | `supabase/functions/enviar-push/index.ts:376` |
| `atraso_15min` | `iOS/Sources/Dominio/AvisoDePush.swift:12` | `iOS/Contrato/openapi.yaml:3805` | `iOS/Sources/Apresentacao/Fluxos/Contratante/RoteadorDoContratante.swift:37` | `supabase/functions/enviar-push/index.ts:381` |
| `fim_sem_checkout` | `iOS/Sources/Dominio/AvisoDePush.swift:13` | `iOS/Contrato/openapi.yaml:3805` | `iOS/Sources/Apresentacao/Fluxos/Push/RoteadorDePush.swift:27` | `supabase/functions/enviar-push/index.ts:386` |
| `vaga_vazia` | `iOS/Sources/Dominio/AvisoDePush.swift:14` | `iOS/Contrato/openapi.yaml:3805` | `iOS/Sources/Apresentacao/Fluxos/Contratante/RoteadorDoContratante.swift:40` | `supabase/functions/enviar-push/index.ts:392` |
| `checkin` | `iOS/Sources/Dominio/AvisoDePush.swift:15` | `iOS/Contrato/openapi.yaml:3805` | `iOS/Sources/Apresentacao/Fluxos/Contratante/RoteadorDoContratante.swift:43` | `supabase/functions/enviar-push/index.ts:399` |
| `checkin_manual_pendente` | `iOS/Sources/Dominio/AvisoDePush.swift:16` | `iOS/Contrato/openapi.yaml:3806` | `iOS/Sources/Apresentacao/Fluxos/Contratante/RoteadorDoContratante.swift:34` | `supabase/functions/enviar-push/index.ts:404` |
| `cancelamento` | `iOS/Sources/Dominio/AvisoDePush.swift:17` | `iOS/Contrato/openapi.yaml:3806` | `iOS/Sources/Apresentacao/Fluxos/Push/RoteadorDePush.swift:30` | `supabase/functions/enviar-push/index.ts:409` |
| `avaliacao_disponivel` | `iOS/Sources/Dominio/AvisoDePush.swift:18` | `iOS/Contrato/openapi.yaml:3806` | `iOS/Sources/Apresentacao/Fluxos/Push/RoteadorDePush.swift:41` | `supabase/functions/enviar-push/index.ts:421` |
| `suspensao` | `iOS/Sources/Dominio/AvisoDePush.swift:19` | `iOS/Contrato/openapi.yaml:3806` | `iOS/Sources/Apresentacao/Fluxos/Push/RoteadorDePush.swift:175` | `supabase/functions/enviar-push/index.ts:426` |
| `reativacao` | `iOS/Sources/Dominio/AvisoDePush.swift:20` | `iOS/Contrato/openapi.yaml:3806` | `iOS/Sources/Apresentacao/Fluxos/Push/RoteadorDePush.swift:175` | `supabase/functions/enviar-push/index.ts:431` |
| `candidatura_recusada` | `iOS/Sources/Dominio/AvisoDePush.swift:21` | `iOS/Contrato/openapi.yaml:3795,3807` | `iOS/Sources/Apresentacao/Fluxos/Push/RoteadorDePush.swift:20` | `supabase/functions/enviar-push/index.ts:437` / contrato |
| `selecao_encerrada` | `iOS/Sources/Dominio/AvisoDePush.swift:22` | `iOS/Contrato/openapi.yaml:3796,3807` | `iOS/Sources/Apresentacao/Fluxos/Push/RoteadorDePush.swift:20` | `supabase/functions/enviar-push/index.ts:437` / contrato |
| `selecao_lembrete` | `iOS/Sources/Dominio/AvisoDePush.swift:25` | `iOS/Contrato/openapi.yaml:3798,3807` | `iOS/Sources/Apresentacao/Fluxos/Contratante/RoteadorDoContratante.swift:46` | `supabase/functions/enviar-push/index.ts:437` / contrato |

---

## 4. Planilha de Textos de Notificações Push

### Regras de Restrição Estrita de Conteúdo (RN10, RN15):
1. **Nenhum telefone ou e-mail:** Proibido no push em qualquer cenário.
2. **Nenhum motivo de suspensão:** A notificação informa apenas que a conta foi suspensa; o motivo detalhado e a contestação ficam exclusivamente na área restrita da conta dentro do app.
3. **Nenhum relato ou dados de denúncia:** Proibido no push.
4. **Sem promessa vaga de tempo:** Sem expressões como "em breve", "logo", "chega logo". O texto utiliza referências temporais exatas ("amanhã às 19:00", "em 3 horas", "ao chegar ao local").

### Tabela de Especificação de Push

| # | Tipo | Cenário / Variante | Gatilho (Quando dispara) | Quem recebe | Título | Car. Tít. (≤40) | Corpo | Car. Corpo (≤110) | O que abre no toque | Regras de Dados e Restrições |
|---|---|---|---|---|---|:---:|---|:---:|---|---|
| 01 | `vaga` | Vaga única comum (rodada 1) | Motor de despacho aloca vaga ao profissional elegível | Profissional elegível | Nova vaga no Frila | 18 (OK) | {Função} em {região}. Toque para ver detalhes. *(Fallback: Nova vaga compatível com seu perfil. Toque para ver detalhes.)* | 48 (OK)<br>*(Fallback: 61)* | Detalhe da vaga (`TelaDetalheVaga`) ou vaga indisponível se já preenchida | Sem endereço com número nem dados de contato. |
| 02 | `vaga` | Vaga urgente | Vaga publicada com início em menos de 2 horas ou marcada urgente | Profissional elegível | Vaga urgente no Frila | 21 (OK) | {Função} com início próximo em {região}. Confira agora. *(Fallback: Vaga com início nas próximas 2 horas. Confira agora.)* | 57 (OK)<br>*(Fallback: 52)* | Detalhe da vaga (`TelaDetalheVaga`) ou vaga indisponível | Não promete tempo de deslocamento. |
| 03 | `vaga` | Vaga reaberta (rodada 2+) | Reposição após cancelamento ou vaga não preenchida na rodada anterior | Profissional elegível | Vaga reaberta | 13 (OK) | {Função} disponível novamente em {região}. *(Fallback: Uma vaga recente está aberta novamente para candidatura.)* | 44 (OK)<br>*(Fallback: 56)* | Detalhe da vaga (`TelaDetalheVaga`) ou vaga indisponível | Identifica reabertura sem expor quem cancelou. |
| 04 | `vagas_agrupadas` | Agrupamento por teto diário (N ≥ 2) | Janela de agrupamento da RN23 consolidou múltiplas vagas | Profissional | Vagas disponíveis | 17 (OK) | {N} vagas novas perto de você. Toque para conferir. | 49 (OK) | Lista de vagas (`TelaListaDeVagas`) | Apenas o número de vagas; sem dados sensíveis. |
| 05 | `vagas_agrupadas` | Agrupamento sem contagem (fallback) | Agrupamento da RN23 quando quantidade não pôde ser calculada | Profissional | Vagas disponíveis | 17 (OK) | Novas vagas compatíveis perto de você. Toque para conferir. | 59 (OK) | Lista de vagas (`TelaListaDeVagas`) | Fallback seguro sem número. |
| 06 | `vaga_sem_elegiveis` | Despacho sem profissionais | Motor de despacho não localizou nenhum profissional elegível na região | Contratante (membros do estabelecimento) | Nenhum profissional encontrado | 30 (OK) | Não encontramos profissionais disponíveis para a sua vaga. Toque para revisar. | 78 (OK) | A vaga em Minhas Vagas | Orienta a revisar horário/função sem culpar terceiros. |
| 07 | `confirmacao` | Modo urgência (Profissional) | Profissional aceitou a vaga e obteve a posição | Profissional confirmado | Turno confirmado | 16 (OK) | O seu turno foi confirmado. Acesse os detalhes no app. | 54 (OK) | Detalhe do turno em Meus Turnos (`TelaTurno`) | Sem dados de contato no push; contato liberado no app. |
| 08 | `confirmacao` | Modo urgência (Contratante) | Um profissional aceitou a vaga publicada | Contratante (membros do estabelecimento) | Turno confirmado | 16 (OK) | Um profissional aceitou sua vaga. Confira os detalhes no app. | 61 (OK) | Detalhe do turno no painel/Minhas Vagas | Sem nome de pessoa física nem telefone na tela bloqueada. |
| 09 | `confirmacao` | Modo seleção (Profissional escolhido) | Contratante escolheu o profissional entre os candidatos (0.2.38) | Profissional escolhido | Você foi escolhido | 18 (OK) | O estabelecimento escolheu você para o turno. Toque para ver os detalhes e o contato. | 85 (OK) | Detalhe do turno em Meus Turnos (`TelaTurno`) | Sem telefone no push; contato no app via `contato_do_turno`. |
| 10 | `lembrete_24h` | Lembrete de véspera (Profissional) | 24 horas antes do horário de início do turno confirmado | Profissional | Lembrete de turno amanhã | 24 (OK) | {Função} em {estabelecimento} ({região}) amanhã às {horário}. *(Fallback: Você tem um turno confirmado para amanhã. Confira os detalhes.)* | 48 a 72 (OK)<br>*(Fallback: 62)* | Detalhe do turno (`TelaTurno`) | Sem telefone da casa nem endereço completo com número. |
| 11 | `lembrete_24h` | Lembrete de véspera (Contratante) | 24 horas antes do horário de início do turno confirmado | Contratante (membros do estabelecimento) | Turno agendado para amanhã | 26 (OK) | Turno de {função} confirmado para amanhã às {horário}. *(Fallback: Você tem turno confirmado para amanhã. Confira no painel.)* | 48 a 60 (OK)<br>*(Fallback: 57)* | Detalhe do turno em Minhas Vagas | Sem telefone nem nome do profissional. |
| 12 | `lembrete_3h` | Lembrete pré-turno (Profissional) | 3 horas antes do horário de início do turno confirmado | Profissional | Seu turno começa em 3 horas | 27 (OK) | {Função} em {estabelecimento} ({região}) às {horário}. Planeje seu trajeto. *(Fallback: Seu turno começa em 3 horas. Toque para ver endereço e contato.)* | 62 a 85 (OK)<br>*(Fallback: 63)* | Detalhe do turno (`TelaTurno`) | Orienta trajeto sem prometer tempo; contato no app. |
| 13 | `lembrete_3h` | Lembrete pré-turno (Contratante) | 3 horas antes do horário de início do turno confirmado | Contratante (membros do estabelecimento) | Turno em 3 horas | 16 (OK) | Turno de {função} começa às {horário}. O profissional foi lembrado. *(Fallback: Turno confirmado começa em 3 horas. Acompanhe pelo app.)* | 61 a 70 (OK)<br>*(Fallback: 55)* | Detalhe do turno em Minhas Vagas | Informa que lembrete foi enviado à contraparte. |
| 14 | `inicio_sem_checkin` | Início sem presença | Horário exato de início do turno sem check-in realizado | Profissional | Horário de início do turno | 26 (OK) | O horário de início chegou. Faça seu check-in ao chegar ao local. | 65 (OK) | Detalhe do turno com o botão de check-in | Instrução objetiva de presença geolocalizada. |
| 15 | `atraso_15min` | Tolerância de atraso esgotada | 15 minutos após o início do turno sem check-in | Contratante (membros do estabelecimento) | Check-in pendente há 15 min | 27 (OK) | O profissional ainda não registrou presença. Você pode aguardar ou reabrir a vaga. | 82 (OK) | Detalhe do turno com ação "Reabrir vaga" | Dá autonomia ao gestor sem cancelar compulsoriamente. |
| 16 | `fim_sem_checkout` | Fim do turno sem encerramento (Profissional) | Horário previsto de término do turno sem check-out registrado | Profissional | Check-out pendente | 18 (OK) | O horário previsto do turno encerrou. Registre o check-out. | 59 (OK) | Detalhe do turno com o botão de check-out | Lembra encerramento para liberação de avaliação. |
| 17 | `fim_sem_checkout` | Fim do turno sem encerramento (Contratante) | Horário previsto de término do turno sem check-out registrado | Contratante (membros do estabelecimento) | Check-out pendente | 18 (OK) | O turno chegou ao horário de término. Aguardando check-out. | 59 (OK) | Detalhe do turno no painel | Alerta de encerramento de jornada. |
| 18 | `vaga_vazia` | Alerta de janela crítica | Janela crítica atingida (padrão 3h antes) com posição em aberto | Contratante (membros do estabelecimento) | Vaga ainda em aberto | 20 (OK) | A posição de {função} das {horário} ainda não foi preenchida. *(Fallback: Sua vaga ainda possui posição em aberto próxima ao horário.)* | 55 a 65 (OK)<br>*(Fallback: 59)* | A vaga em alerta em Minhas Vagas | Alerta preventivo para ação do contratante. |
| 19 | `checkin` | Check-in geolocalizado | Profissional registrou check-in com validação de GPS | Contratante (membros do estabelecimento) | Check-in realizado | 18 (OK) | O profissional realizou o check-in no turno. | 44 (OK) | Detalhe do turno no painel | Confirmação em tempo real de chegada. |
| 20 | `checkin_manual_pendente` | Check-in manual aguarda aprovação | Profissional solicitou check-in manual por indisponibilidade de GPS | Contratante (membros do estabelecimento) | Confirmação de check-in necessária | 34 (OK) | Check-in manual registrado, aguardando confirmação do contratante. | 66 (OK) | Detalhe do turno com ação "Confirmar presença" | Exige validação humana do gestor presente. |
| 21 | `cancelamento` | Turno descoberto (Profissional cancelou) | Profissional cancelou turno confirmado | Contratante (membros do estabelecimento) | Turno cancelado | 15 (OK) | O profissional cancelou a presença. A vaga foi reaberta para novos candidatos. | 78 (OK) | A vaga em Minhas Vagas | Informa reabertura imediata da posição. |
| 22 | `cancelamento` | Turno cancelado pela casa | Estabelecimento cancelou o turno do profissional | Profissional confirmado | Turno cancelado | 15 (OK) | O estabelecimento cancelou o turno. Você está livre para novas vagas. | 69 (OK) | Meus Turnos (`TelaMeusTurnos`) | Deixa claro que profissional não tem penalidade. |
| 23 | `cancelamento` | Cancelamento por atraso | Contratante reabriu a vaga aos 15 min de atraso sem check-in | Profissional em atraso | Turno cancelado por atraso | 26 (OK) | O contratante reabriu a vaga por falta de check-in. O turno foi cancelado. | 74 (OK) | Meus Turnos (`TelaMeusTurnos`) | Explica cancelamento objetivo sem ofensa ou debate. |
| 24 | `cancelamento` | Vaga recolhida pelo contratante | Contratante cancelou a vaga antes de escolher/preencher | Candidato pendente | Vaga cancelada | 14 (OK) | A vaga em que você se candidatou foi cancelada pelo estabelecimento. | 68 (OK) | Tela de vaga indisponível (`DestinoDaVagaDoAviso`) | Informa liberação da candidatura. |
| 25 | `avaliacao_disponivel` | Avaliação mútua liberada (Profissional) | Turno concluído e check-out registrado | Profissional | Avaliação disponível | 20 (OK) | O turno foi concluído. Avalie a experiência no Frila. | 53 (OK) | Tela de avaliação do turno (`TelaAvaliacao`) | Reputação binária sem notas 1 a 5. |
| 26 | `avaliacao_disponivel` | Avaliação mútua liberada (Contratante) | Turno concluído e check-out registrado | Contratante (membros do estabelecimento) | Avaliação disponível | 20 (OK) | O turno foi concluído. Avalie a experiência no Frila. | 53 (OK) | Detalhe do turno no painel | Incentivo à cultura de feedback recíproco. |
| 27 | `suspensao` | Conta suspensa | Moderação ou sistema aplicou suspensão à conta | Conta afetada (Profissional ou Contratante) | Aviso sobre sua conta | 21 (OK) | Sua conta foi suspensa. Abra o aplicativo para mais detalhes. | 61 (OK) | Tela de situação da conta (`TelaSituacaoDaConta`) | **PROIBIDO:** motivo de suspensão, denúncia ou prazo no push. |
| 28 | `reativacao` | Conta reativada | Equipe Frila acolheu contestação ou encerrou suspensão | Conta reativada (Profissional ou Contratante) | Conta reativada | 15 (OK) | Sua conta foi reativada e está pronta para uso. | 47 (OK) | Tela inicial / reavaliação da conta | Confirma liberação do acesso. |
| 29 | `candidatura_recusada` | Candidato não escolhido (Seleção) | Vaga do modo seleção encheu com outros candidatos (0.2.38) | Candidato não escolhido | Vaga preenchida | 15 (OK) | O estabelecimento escolheu outro profissional para esta vaga. Sua candidatura foi encerrada e você está livre para outras vagas. *(Texto atual do contrato = 128 car. Trunca no SE!)*<br><br>**Proposta ajustada:** A vaga foi preenchida com outro profissional. Você está livre para novas vagas. | **128 (TRUNCA)**<br><br>**Decidido: 79 (OK)** | Tela de vaga indisponível (`TelaVagaIndisponivel`) | **[DECIDIDO em 16/10/2026: Cauê, texto de 79 car., revisado pelo Nick Fury por delegação]**: o contrato prevê 128 car., que excede a regra de partida de 110 car. do SE. A troca no backend está no cartão xNIWtzuk. |
| 30 | `selecao_encerrada` | Seleção expirada (Candidato) | Prazo de escolha expirou sem que a casa selecionasse (0.2.38) | Candidato pendente | Vaga fechada sem escolha | 24 (OK) | O prazo de escolha terminou e sua candidatura foi encerrada. Você está livre para outras vagas. | 95 (OK) | Tela de vaga indisponível (`TelaVagaIndisponivel`) | Deixa claro que profissional está desimpedido. |
| 31 | `selecao_encerrada` | Seleção expirada (Contratante) | Prazo de escolha de 24h encerrou sem preenchimento total (0.2.38) | Contratante (membros do estabelecimento) | Prazo de escolha encerrado | 26 (OK) | A vaga de {função} fechou sem todas as posições preenchidas. Toque para republicar em urgência. | 93 (OK) | Detalhe da vaga em Minhas Vagas | Oferece saída direta para republicação em urgência. |
| 32 | `selecao_lembrete` | Lembrete de escolha (Contratante) | Faltando ≤ 6 horas para expirar prazo de seleção com candidatos pendentes (0.2.38) | Contratante (membros do estabelecimento) | Candidatos esperando sua escolha | 32 (OK) | {N} candidato(s) para a vaga de {função}. Escolha até {dd/mm às HH:MM}, quando a vaga fecha. | 84 a 95 (OK) | Detalhe da vaga em Minhas Vagas com aba Candidatos | Dispara uma única vez por vaga; horário no fuso de Brasília. |

---

## 5. Telas de Permissão, Avisos de Notificação Desligada e Vaga Indisponível

Esta seção detalha todas as telas acessórias e modais que suportam a experiência de notificações no aplicativo iOS (`frila-frontend`), com seus respectivos textos atuais, limites e destinos.

### 5.1 Telas de Explicação de Permissão (`TelasDaPermissaoDePush.swift` / `TextosDoPush.Explicacao`)
Exibidas no máximo uma vez por sessão do app, antes de invocar o diálogo nativo do sistema operacional (`UNUserNotificationCenter.requestAuthorization`):
- **Momento do Profissional:** Imediatamente após salvar funções e janelas de horários (na criação inicial ou na edição do perfil).
- **Momento do Contratante:** Imediatamente após publicar a primeira vaga da casa.

| Perfil | Elemento | Texto no Aplicativo | Caracteres | Cabe no iPhone SE? | Comportamento / Ação |
|---|---|---|:---:|:---:|---|
| **Profissional** | Título | Ative as notificações | 22 | Sim (≤ 40) | Cabeçalho em negrito com ícone `bell.badge.fill`. |
| | Mensagem | É pela notificação que você fica sabendo de uma vaga nova perto de você, na hora em que ela é publicada. | 106 | Sim (corpo de tela) | Texto explicativo em fonte padrão do sistema. |
| | Item 1 | Vaga nova na sua função e na sua região | 39 | Sim | Marcador com ícone de confirmação. |
| | Item 2 | Confirmação e lembretes do seu turno | 37 | Sim | Marcador com ícone de confirmação. |
| | Item 3 | Aviso quando um turno seu é cancelado | 38 | Sim | Marcador com ícone de confirmação. |
| | Botão Primário | Ativar notificações | 19 | Sim | Dispara o pedido nativo do iOS. |
| | Botão Secundário | Agora não | 9 | Sim | Fecha a tela sem gastar o diálogo nativo do sistema. |
| | Rodapé | Você pode mudar isso quando quiser, nos Ajustes do iPhone. | 59 | Sim | Nota em texto secundário / footnote. |
| **Contratante** | Título | Ative as notificações | 22 | Sim (≤ 40) | Cabeçalho em negrito com ícone `bell.badge.fill`. |
| | Mensagem | É pela notificação que você fica sabendo quando alguém aceita a sua vaga e quando a pessoa chega para o turno. | 111 | Sim (corpo de tela) | Texto explicativo contextualizado à operação da casa. |
| | Item 1 | Confirmação de quem vai trabalhar | 33 | Sim | Marcador com ícone de confirmação. |
| | Item 2 | Check-in, atraso e vaga que ainda está sem ninguém | 50 | Sim | Marcador com ícone de confirmação. |
| | Item 3 | Aviso quando alguém cancela | 26 | Sim | Marcador com ícone de confirmação. |
| | Botão Primário | Ativar notificações | 19 | Sim | Dispara o pedido nativo do iOS. |
| | Botão Secundário | Agora não | 9 | Sim | Fecha a tela sem gastar o diálogo nativo do sistema. |
| | Rodapé | Você pode mudar isso quando quiser, nos Ajustes do iPhone. | 59 | Sim | Nota em texto secundário / footnote. |

---

### 5.2 Avisos Fixos de Notificação Desligada (`TelasDaPermissaoDePush.swift` / `TextosDoPush.Aviso`)
Banners fixos contextuais exibidos no topo da tela de listagem de vagas (`Vagas` no perfil profissional e `Minhas Vagas` no perfil contratante):

| Perfil | Estado da Permissão | Texto do Aviso | Caracteres | Rótulo do Botão | Ação do Botão |
|---|---|---|:---:|---|---|
| **Profissional** | **Negada** (nos Ajustes do iOS) | As notificações estão desativadas. Você não recebe o aviso de vaga nova nem os lembretes dos seus turnos. | 112 | Abrir os Ajustes | Abre a central de ajustes do Frila no iOS (`UIApplication.openNotificationSettingsURLString`). |
| **Profissional** | **Não pedida / Adiada** ("Agora não") | Ative as notificações para saber de uma vaga nova na hora. | 57 | Ativar notificações | Reabre a tela de explicação do profissional. |
| **Contratante** | **Negada** (nos Ajustes do iOS) | As notificações estão desativadas. Você não recebe o aviso de quem aceitou a vaga, de check-in nem de atraso. | 108 | Abrir os Ajustes | Abre a central de ajustes do Frila no iOS (`UIApplication.openNotificationSettingsURLString`). |
| **Contratante** | **Não pedida / Adiada** ("Agora não") | Ative as notificações para saber quando alguém aceita a sua vaga. | 64 | Ativar notificações | Reabre a tela de explicação do contratante. |

---

### 5.3 Telas de Vaga Indisponível ao Abrir por Notificação (`DestinosDoAviso.swift` / `TelaVagaIndisponivel`)
Exibidas quando o profissional toca em uma notificação de vaga que não aceita mais candidaturas:

| Cenário de Indisponibilidade | Título da Tela | Car. | Mensagem Explicativa | Car. | Botão de Retorno |
|---|---|:---:|---|:---:|---|
| **Vaga preenchida (Modo Urgência)** | Essa vaga já foi preenchida | 27 | Outra pessoa aceitou antes. No modo urgência, quem aceita primeiro fica com a vaga. Nada muda na sua reputação. | 112 | Ver outras vagas perto de você |
| **Vaga preenchida (Modo Seleção - candidato não escolhido)** | O estabelecimento escolheu outra pessoa | 39 | A vaga foi preenchida, e a sua candidatura não foi escolhida. | 60 | Ver outras vagas perto de você |
| **Vaga preenchida (Modo Seleção - sem candidatura)** | Essa vaga já foi preenchida | 27 | O estabelecimento já escolheu quem vai trabalhar nesta vaga. | 61 | Ver outras vagas perto de você |
| **Seleção encerrada sem escolha** | A seleção desta vaga foi encerrada | 34 | A vaga fechou sem que a sua candidatura fosse escolhida. | 57 | Ver outras vagas perto de você |
| **Vaga cancelada pela casa (com candidatura)** | O estabelecimento cancelou esta vaga | 36 | A sua candidatura foi encerrada junto com a vaga. | 49 | Ver outras vagas perto de você |
| **Vaga cancelada ou encerrada (geral)** | Essa vaga não está mais aberta | 29 | Ela foi cancelada, encerrada ou o horário de início já passou. Nada muda na sua reputação. | 94 | Ver outras vagas perto de você |
| **Vaga não encontrada (HTTP 404)** | Essa vaga não está mais aberta | 29 | Esta vaga não está mais disponível. Volte para a lista e escolha outra. | 70 | Ver outras vagas perto de você |

---

### 5.4 Tela de Turno Não Encontrado (`DestinoDoTurnoDoAviso` / `TextosDoPush.Turno`)
Exibida quando a notificação traz um identificador de turno que não pertence à conta autenticada no aparelho (ou de outra conta anterior):
- **Título:** "Não encontramos este turno" (26 car.)
- **Mensagem:** "Ele não está entre os turnos desta conta." (42 car.)
- **Ação:** Botão "Ver meus turnos" (15 car.) que direciona para `TelaMeusTurnos`.

---

## 6. Verificação de Diretrizes e Critérios de Aceite

| Critério de Aceite | Status | Verificação Realizada |
|---|:---:|---|
| Todos os tipos de notificação mapeados sem omissões | **Atendido** | 19 tipos do contrato OpenAPI / `TipoDeAviso` e 32 cenários/variantes detalhados com seus respectivos arquivos de código. |
| Nenhum push com telefone ou e-mail | **Atendido** | 0 ocorrências de contato direto em texto de push. Dados pessoais protegidos pela RN10/RN15. |
| Nenhum push com motivo de suspensão | **Atendido** | Push de suspensão contém mensagem neutra e genérica ("Aviso sobre sua conta / Sua conta foi suspensa. Abra o aplicativo para mais detalhes."). |
| Nenhum push com relato de denúncia | **Atendido** | Denúncias e relatos são restritos ao canal interno da Equipe Frila e e-mail operacional. |
| Sem promessa vaga de tempo | **Atendido** | Prazos baseados exclusivamente em marcos objetivos ("às 19:00", "em 3 horas", "ao chegar ao local"). |
| Contagem de caracteres e compatibilidade com iPhone SE | **Atendido** | Todos os títulos ≤ 40 caracteres (13 a 34 car.). Todos os corpos ≤ 110 caracteres (44 a 95 car.), com exceção pontual documentada em `candidatura_recusada` (128 car. no contrato). |

---

## 7. Decisões Marcadas para Produto e Design

1. **Aprovação Formal dos Textos:**
   - **Responsável:** Júlia (Produto / Conteúdo).
   - **Ação:** Validar e aprovar a redação definitiva de todos os 32 cenários descritos na tabela da Seção 4.
2. **Ajuste de Caracteres em `candidatura_recusada`:**
   - **Responsável:** Júlia.
   - **Decisão:** O contrato OpenAPI 0.2.38 fixou o corpo em 128 caracteres (*"O estabelecimento escolheu outro profissional para esta vaga. Sua candidatura foi encerrada e você está livre para outras vagas."*), ultrapassando o limite visual de 110 caracteres da tela bloqueada do iPhone SE. Proposta recomendada: encurtar para *"A vaga foi preenchida com outro profissional. Você está livre para novas vagas."* (79 car., decidido em 16/10/2026; cartão xNIWtzuk do backend).
3. **Handoff dos Frames de Alta Fidelidade:**
   - **Responsável:** Fabrício (Design).
   - **Ação:** Entregar os links dos frames no Figma para as telas de explicação de permissão, aviso fixo e vaga indisponível no cartão `VyY2SGsX`.
