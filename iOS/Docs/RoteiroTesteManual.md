# Roteiro de Teste Manual Ponta a Ponta em Aparelhos Físicos

**Data:** 18/10/2026  
**Responsável:** Steve Rogers (Manutenção, Inventário e Planejamento Operacional)  
**Repositório:** `FrilaApp/frila-frontend`  
**Referência Trello:** [AZI1goKB](https://trello.com/c/AZI1goKB) — *S2 · QA · Testes de ponta a ponta do ciclo e roteiro de teste manual*  
**Bases Técnicas:**  
- Teste de interface do ciclo em dublê: [`CicloDePontaAPontaUITests.swift`](../Tests/UI/CicloDePontaAPontaUITests.swift)  
- Runbook do ambiente de produção: [`RunbookProd.md`](RunbookProd.md)  
- Arquitetura de notificações e ciclo de vida: [`Push.md`](Push.md)  

---

## 1. Objetivo Operacional

Este roteiro estabelece o procedimento operacional padrão para validação manual do ciclo de ponta a ponta da plataforma Frila entre **dois iPhones físicos reais**, cobrindo todas as etapas de interação: **publicação de vaga**, **entrega de notificação push**, **candidatura**, **confirmação imediata**, **liberação bilateral de contatos**, **registro de check-in / check-out** e **avaliação mútua**.

O procedimento visa comprovar o funcionamento coordenado entre dois aparelhos sob condições reais de rede móvel (4G/5G), permissões do iOS (Notificações e CoreLocation) e serviços de backend (Supabase e Firebase Cloud Messaging / APNs), atendendo ao critério de aceite do cartão `AZI1goKB`.

---

## 2. Preparação dos Aparelhos Físicos

Antes de iniciar o roteiro, configure os dois aparelhos conforme a tabela abaixo. Nenhuma credencial pessoal ou segredo de infraestrutura é utilizado:

| Requisito | Aparelho 1 (Contratante) | Aparelho 2 (Profissional) |
|---|---|---|
| **Dispositivo** | iPhone físico com iOS 17 ou superior | iPhone físico com iOS 17 ou superior |
| **Instalação** | Build do TestFlight (`Frila-Beta` ou `Frila-Prod`) | Build do TestFlight (`Frila-Beta` ou `Frila-Prod`) |
| **Conta de Teste** | E-mail de teste: `contratante.teste@frila.app` | E-mail de teste: `profissional.teste@frila.app` |
| **Perfil no App** | Estabelecimento cadastrado no Distrito Federal | Profissional com função "Garçom" e ponto base no DF |
| **Notificações** | Permitidas nos Ajustes do iOS (Alerta e Som) | Permitidas nos Ajustes do iOS (Alerta e Som) |
| **Localização** | Permitida ("Durante o Uso do App") | Permitida com "Localização Precisa" ativada |
| **Conexão** | Rede móvel celular (4G/5G) ou Wi-Fi ativa | Rede móvel celular (4G/5G) ou Wi-Fi ativa |

> **Nota de Segurança:** As contas de teste devem estar previamente cadastradas no ambiente Supabase correspondente. Códigos de acesso OTP são entregues via e-mail corporativo de homologação ou código padrão configurado no ambiente de teste do backend, sem exposição de senhas.

---

## 3. Roteiro Passo a Passo

Cada passo descreve estritamente: **quem faz**, **o que toca** e **o que deve aparecer**.

### Fase 1: Entrada e Prontidão das Contas

#### Passo 01 — Entrada do Contratante
- **Quem faz:** Contratante (Aparelho 1).
- **O que toca:**
  1. Abre o app Frila.
  2. No campo `entrada-email`, digita o e-mail de teste (`contratante.teste@frila.app`).
  3. Toca no botão "Receber código de acesso" (`entrada-receber-codigo`).
  4. Na tela `TelaCodigo`, insere o código de acesso recebido e toca no botão "Entrar" (`codigo-entrar`).
- **O que deve aparecer:** O app autentica a sessão e exibe o painel "Minhas vagas" (`minhas-vagas`) com as abas inferiores e o botão de publicação de vaga.

#### Passo 02 — Entrada e Disponibilidade do Profissional
- **Quem faz:** Profissional (Aparelho 2).
- **O que toca:**
  1. Abre o app Frila.
  2. No campo `entrada-email`, digita o e-mail de teste (`profissional.teste@frila.app`).
  3. Toca em "Receber código de acesso" (`entrada-receber-codigo`).
  4. Insere o código em `TelaCodigo` e toca em "Entrar" (`codigo-entrar`).
  5. Se solicitado pelo sistema ou tela de explicação, toca em "Ativar notificações" para autorizar push (`CanalDePushDoAparelho.ativar()`).
  6. Pressiona o botão Início ou desliza para colocar o app em segundo plano (ou bloqueia a tela) para testar o recebimento do push.
- **O que deve aparecer:** App autenticado com perfil de profissional ativo, função "Garçom" habilitada, pronto para receber despachos de vagas compatíveis no DF.

---

### Fase 2: Publicação da Vaga e Notificação Push

#### Passo 03 — Publicação da Vaga de Urgência
- **Quem faz:** Contratante (Aparelho 1).
- **O que toca:**
  1. Em "Minhas vagas", toca no botão para publicar vaga (ou botão flutuante "+").
  2. Na tela `PublicarVaga`:
     - Seleciona a função "Garçom".
     - Define a data para o dia atual (regime de Urgência, início em menos de 24 horas).
     - Define o horário de início (ex.: 19h00) e término (ex.: 23h00).
     - Preenche o valor do turno (ex.: R$ 150,00) no campo de remuneração integral.
     - Confere que o endereço de realização é o do estabelecimento no DF.
  3. Rola até o final e toca no botão "Publicar vaga" (`publicar-vaga-botao`).
- **O que deve aparecer:**
  - No Aparelho 1: Indicador de carregamento breve, fechamento da folha de publicação e exibição da nova vaga listada em "Minhas vagas" (`vaga-contratante-*`) com status "0/1 ocupada" e badge de modo Urgência.
  - No backend: Registro em `public.vaga` e enfileiramento da mensagem de despacho no `pgmq.q_despacho`.

#### Passo 04 — Chegada da Notificação Push no Aparelho do Profissional
- **Quem faz:** Profissional (Aparelho 2) — observação passiva.
- **O que toca:** Nenhuma ação imediata (aparelho com tela bloqueada ou em segundo plano).
- **O que deve aparecer:**
  - No Aparelho 2: Notificação push entregue via APNs/FCM em até 30 segundos (SLA RNF03).
  - Título da notificação: anúncio de nova vaga de Garçom compatível no Distrito Federal.
  - Corpo da notificação: informações neutras do turno (função, data, horário e remuneração sem desconto).

---

### Fase 3: Candidatura e Confirmação Imediata

#### Passo 05 — Abertura da Vaga pelo Push
- **Quem faz:** Profissional (Aparelho 2).
- **O que toca:** Toca na faixa da notificação push recebida na Central de Notificações ou tela bloqueada.
- **O que deve aparecer:** O app Frila abre diretamente na tela de detalhe da vaga (`tela-detalhe-vaga`), sem passar por telas intermediárias (`RoteadorDePush.tocar`), apresentando todos os dados operacionais: função ("Garçom"), horário, endereço e valor integral do turno (R$ 150,00).

#### Passo 06 — Candidatura em Modo Urgência
- **Quem faz:** Profissional (Aparelho 2).
- **O que toca:** Na tela de detalhe da vaga, toca no botão "Candidatar-me" (`candidatar`).
- **O que deve aparecer:**
  - Como a vaga é em regime de Urgência (início < 24h), a confirmação ocorre imediatamente sem triagem (RN02).
  - A tela transita para `resultado-confirmada`, com mensagem confirmando o preenchimento da vaga e orientações de pontualidade.
  - Um botão "Ver meu turno" ou "Meus turnos" é disponibilizado na tela.

#### Passo 07 — Notificação de Vaga Preenchida para o Contratante
- **Quem faz:** Contratante (Aparelho 1) — observação e conferência.
- **O que toca:** Toca na notificação push recebida no Aparelho 1 ("Vaga preenchida") ou, com o app aberto em "Minhas vagas", realiza gesto de puxar para atualizar (pull-to-refresh).
- **O que deve aparecer:**
  - A vaga no Aparelho 1 passa a indicar "1/1 ocupada".
  - Ao tocar no cartão da vaga (`vaga-contratante-*`), a tela de detalhe da vaga do contratante exibe a posição com status "Confirmado" e o botão "Acompanhar turno" (`acompanhar-turno-*`).

#### Passo 08 — Liberação Bilateral de Contato
- **Quem faz:** Ambos os aparelhos (Aparelho 1 e Aparelho 2).
- **O que toca:**
  - No Aparelho 2: Toca em "Ver meu turno" (ou navega para aba "Meus turnos" $\to$ seleciona o turno confirmado `meu-turno-*`).
  - No Aparelho 1: Toca em "Acompanhar turno" (`acompanhar-turno-*`).
- **O que deve aparecer:**
  - No Aparelho 2 (`tela-meu-turno`): Cartão de contato da casa (`contato-do-turno`), exibindo nome do estabelecimento, telefone do responsável e botão para ligação/WhatsApp (`contato-telefone`).
  - No Aparelho 1 (`turno-do-contratante`): Cartão do profissional alocado, exibindo nome completo do trabalhador, telefone de contato e status inicial "Aguardando check-in".
  - Ambos os contatos permanecem visíveis até o encerramento do turno (RN10).

---

### Fase 4: Execução do Turno — Check-in e Presença

#### Passo 09 — Registro de Check-in pelo Profissional
- **Quem faz:** Profissional (Aparelho 2).
- **O que toca:**
  1. Na tela `tela-meu-turno`, localiza a seção de presença (`presenca-do-turno`).
  2. Toca no botão "Fazer check-in" (`fazer-checkin`).
  3. **Cenário A (com GPS a até 250m do local do turno):** O app obtém a coordenada precisa e valida a geolocalização automaticamente.
  4. **Cenário B (sem sinal de GPS ou distância > 250m - contingência):** O app exibe aviso `sem-gps`; toca no botão "Registro manual" (`registro-manual`).
- **O que deve aparecer:**
  - No Cenário A: O status na tela do profissional atualiza imediatamente para "Presença verificada" com carimbo de horário.
  - No Cenário B: O status exibe "Aguardando confirmação do contratante" (`checkin-situacao`).

#### Passo 10 — Notificação de Check-in para o Contratante
- **Quem faz:** Contratante (Aparelho 1) — observação.
- **O que toca:** Toca na notificação recebida ("Profissional realizou check-in") ou abre a tela de acompanhamento do turno (`turno-do-contratante`).
- **O que deve aparecer:**
  - Se Cenário A (GPS): A tela exibe o indicador "Presença verificada." (`presenca-verificada-*`) com horário do check-in geolocalizado.
  - Se Cenário B (Manual): A tela exibe alerta de pendência com o botão "Confirmar presença" (`confirmar-presenca-*`).

#### Passo 11 — Confirmação de Presença Manual (se aplicável ao Cenário B)
- **Quem faz:** Contratante (Aparelho 1) — *apenas se o check-in foi manual*.
- **O que toca:** Na tela `turno-do-contratante`, toca no botão "Confirmar presença" (`confirmar-presenca-*`).
- **O que deve aparecer:**
  - No Aparelho 1: O status muda para "Presença verificada." com indicação de confirmação presencial pelo contratante.
  - No Aparelho 2: Ao atualizar `tela-meu-turno`, a situação do check-in passa de "Aguardando confirmação" para "Presença verificada".

#### Passo 12 — Registro de Check-out pelo Profissional
- **Quem faz:** Profissional (Aparelho 2).
- **O que toca:**
  1. Ao término do expediente contratado, na tela `tela-meu-turno`, toca no botão "Fazer check-out" (`fazer-checkout`).
  2. Se solicitado, confirma o encerramento do turno no diálogo de confirmação.
- **O que deve aparecer:**
  - No Aparelho 2: Mensagem "Check-out registrado" (`checkout-situacao`). O turno passa ao estado encerrado/concluído e o cartão de avaliação (`cartao-avaliacao-turno`) torna-se visível.
  - No Aparelho 1: Acompanhamento exibe o horário de encerramento do turno e libera o cartão de avaliação do profissional.

---

### Fase 5: Avaliação Mútua e Encerramento

#### Passo 13 — Notificação de Avaliação Disponível
- **Quem faz:** Ambos os aparelhos (Aparelho 1 e Aparelho 2).
- **O que toca:** Toca na notificação push recebida ("Avalie seu turno") ou permanece na tela do turno concluído.
- **O que deve aparecer:** Em ambos os aparelhos, a notificação direciona para o respectivo turno concluído com o cartão de avaliação ativo (`cartao-avaliacao-turno`).

#### Passo 14 — Avaliação do Local pelo Profissional
- **Quem faz:** Profissional (Aparelho 2).
- **O que toca:**
  1. Na tela `tela-meu-turno`, rola até `cartao-avaliacao-turno` e toca no botão "Avaliar turno" (`botao-abrir-avaliacao`).
  2. Na tela de avaliação (`Avaliar turno`), confere a pergunta obrigatória: *"Você trabalharia nesse local de novo?"* (`pergunta-avaliacao`).
  3. Toca na opção "Sim" (`resposta-sim`).
  4. Toca no botão "Enviar avaliação" (`botao-enviar-avaliacao`).
- **O que deve aparecer:**
  - Exibição de confirmação de envio (`aviso-sucesso-avaliacao`).
  - Ao retornar para `tela-meu-turno`, o cartão de avaliação é atualizado para estado já respondido, impedindo novo envio.

#### Passo 15 — Avaliação do Profissional pelo Contratante
- **Quem faz:** Contratante (Aparelho 1).
- **O que toca:**
  1. Na tela `turno-do-contratante`, rola até `cartao-avaliacao-turno` e toca no botão "Avaliar turno" / "Avaliar profissional" (`botao-abrir-avaliacao`).
  2. Na tela de avaliação (`Avaliar turno`), confere a pergunta obrigatória: *"Chamaria este profissional de novo?"* (`pergunta-avaliacao`).
  3. Toca na opção "Sim" (`resposta-sim`).
  4. Toca no botão "Enviar avaliação" (`botao-enviar-avaliacao`).
- **O que deve aparecer:**
  - Exibição de confirmação de envio (`aviso-sucesso-avaliacao`).
  - A tela `turno-do-contratante` atualiza, exibindo "Resposta: Sim" e o botão "Ver avaliação" (`botao-ver-avaliacao`).

#### Passo 16 — Conferência de Imutabilidade e Bloqueio de Reenvio
- **Quem faz:** Ambos os aparelhos (Aparelho 1 e Aparelho 2).
- **O que toca:**
  - No Aparelho 1: Toca no botão "Ver avaliação" (`botao-ver-avaliacao`).
  - No Aparelho 2: Abre a tela de avaliação a partir do histórico ou turno concluído.
- **O que deve aparecer:**
  - A tela abre em modo somente leitura com o aviso de avaliação já registrada (`aviso-ja-avaliado`).
  - O botão "Enviar avaliação" (`botao-enviar-avaliacao`) não existe na tela, garantindo imutabilidade e unicidade da avaliação (RN13).

---

## 4. Matriz Resumo de Execução

| # | Fase | Aparelho / Ator | Ação (O que toca) | Resultado Esperado (O que deve aparecer) | Status |
|:---:|---|---|---|---|:---:|
| **01** | Entrada | Aparelho 1 (Contratante) | Digita e-mail, código OTP e toca "Entrar" | Painel "Minhas vagas" aberto e autenticado | `[ ]` |
| **02** | Entrada | Aparelho 2 (Profissional) | Digita e-mail, código OTP e ativa push | App pronto com funções ativas no DF | `[ ]` |
| **03** | Publicação | Aparelho 1 (Contratante) | Preenche turno de urgência e toca "Publicar vaga" | Vaga listada como "0/1 ocupada" em Minhas vagas | `[ ]` |
| **04** | Notificação | Aparelho 2 (Profissional) | Em repouso / tela bloqueada | Push APNs/FCM recebido em até 30 s com dados do turno | `[ ]` |
| **05** | Abertura | Aparelho 2 (Profissional) | Toca na notificação push | Abertura direta na tela de detalhe da vaga | `[ ]` |
| **06** | Candidatura | Aparelho 2 (Profissional) | Toca no botão "Candidatar-me" | Vaga confirmada imediatamente (Urgência) | `[ ]` |
| **07** | Confirmação | Aparelho 1 (Contratante) | Toca no push ou atualiza "Minhas vagas" | Vaga passa para "1/1 ocupada"; "Acompanhar turno" disponível | `[ ]` |
| **08** | Contato | Ambos os aparelhos | Acessam o turno confirmado | Contato telefônico/WhatsApp liberado bilateralmente | `[ ]` |
| **09** | Check-in | Aparelho 2 (Profissional) | Toca "Fazer check-in" (GPS ou manual) | Presença registrada (verificada ou pendente de aceite) | `[ ]` |
| **10** | Alerta Presença | Aparelho 1 (Contratante) | Toca no push ou atualiza o turno | Presença verificada (GPS) ou pendência exibida (manual) | `[ ]` |
| **11** | Aceite Manual | Aparelho 1 (Contratante) | Toca "Confirmar presença" *(se manual)* | Presença verificada com carimbo de horário nos 2 aparelhos | `[ ]` |
| **12** | Check-out | Aparelho 2 (Profissional) | Toca "Fazer check-out" ao fim do turno | Turno concluído; cartões de avaliação liberados | `[ ]` |
| **13** | Alerta Avaliação | Ambos os aparelhos | Notificação de avaliação recebida | Push direciona para tela com cartão de avaliação | `[ ]` |
| **14** | Avaliação Prof. | Aparelho 2 (Profissional) | Responde "Sim" à pergunta e envia | Avaliação gravada; botão desabilitado para reenvio | `[ ]` |
| **15** | Avaliação Casa | Aparelho 1 (Contratante) | Responde "Sim" à pergunta e envia | Avaliação gravada; exibe "Resposta: Sim" e "Ver avaliação" | `[ ]` |
| **16** | Imutabilidade | Ambos os aparelhos | Tocam em "Ver avaliação" | Tela em modo leitura (`aviso-ja-avaliado`), sem reenvio | `[ ]` |

---

## 5. Critérios de Aceite e Verificação Pós-Teste

Ao término da execução do roteiro manual com os dois iPhones físicos, confira:

1. **Integridade Funcional:** Todos os 16 passos executados sem falha impeditiva ou travamento de interface.
2. **Notificações Push:** Entrega das notificações de despacho, confirmação e avaliação confirmada nos aparelhos físicos dentro dos prazos operacionais.
3. **Observabilidade (conforme `RunbookProd.md`):**
   - No painel do Supabase, conferir que as notificações possuem `estado_entrega = 'entregue'` ou foram enviadas pelo FCM sem erro persistente.
   - No Firebase Crashlytics do ambiente correspondente, constatar ausência de crashes fatais gerados durante a sessão de testes.
4. **Sem dados sensíveis:** Nenhuma senha, token ou chave privada foi registrada em tela, log ou anotação de cartão.
