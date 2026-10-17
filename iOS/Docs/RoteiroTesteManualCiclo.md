# Roteiro de Teste Manual do Ciclo de Ponta a Ponta para Aparelhos Físicos

**Data:** 12/10/2026  
**Auditor / Responsável:** Steve Rogers (Documentos e Inventário)  
**Repositório:** `FrilaApp/frila-frontend`  
**Referência Trello:** [AZI1goKB](https://trello.com/c/AZI1goKB) — *S2 · QA · Testes de ponta a ponta do ciclo e roteiro de teste manual*  
**Requisitos Vinculados:** RN02, RN10, RN13, RN19, RN21, RN22, RN25, RNF02, RNF03, RNF09, RNF14  
**Ambiente de Execução:** Dois iPhones físicos reais (Aparelho A e Aparelho B) conectados ao ambiente de testes (`frila-dev`).

---

## 1. Visão Geral e Objetivo Operacional

Este roteiro fornece o protocolo detalhado, passo a passo, para condução de testes manuais sincronizados do ciclo operacional completo da plataforma **Frila** entre **dois iPhones físicos reais**, cobrindo o fluxo ponta a ponta desde a criação e configuração de contas até a avaliação mútua e persistência de histórico e reputação.

O teste tem por objetivo validar a integridade funcional e de sincronização em tempo real entre contratante e profissional em condições reais de rede, GPS e aparelho, em atendimento ao critério de aceite do cartão Trello `AZI1goKB`:
> *"Roteiro manual executado com dois iPhones reais, com o resultado anotado no cartão."*

---

## 2. Pré-condições dos Aparelhos Físicos

Antes de iniciar a execução do roteiro, ambos os aparelhos devem atender aos seguintes requisitos de configuração:

### 2.1 Aparelho A — Contratante
- **Hardware:** iPhone físico com iOS 17 ou superior.
- **Compilação:** Aplicativo Frila instalado via TestFlight (`Frila-Beta` / `Release-Beta`) apontando para o backend de desenvolvimento (`frila-dev`).
- **Conectividade:** Conexão ativa de dados móveis (4G/5G) ou Wi-Fi.
- **Configurações do iOS:** Serviços de Localização ativados; Notificações permitidas para o app Frila.
- **Credenciais de Teste:** [A DEFINIR: conta de teste de cada aparelho e como recebe o código]; [A DEFINIR: código OTP em aparelho real (em simulador/desenvolvimento usa-se 123456)].

### 2.2 Aparelho B — Profissional
- **Hardware:** iPhone físico com iOS 17 ou superior.
- **Compilação:** Aplicativo Frila instalado via TestFlight (`Frila-Beta` / `Release-Beta`) apontando para o backend de desenvolvimento (`frila-dev`).
- **Conectividade:** Conexão ativa de dados móveis (4G/5G) ou Wi-Fi.
- **Configurações do iOS:**
  - Serviços de Localização configurados como "Durante o Uso do App" (`authorizedWhenInUse`) com "Localização Precisa" ativada (`fullAccuracy`).
  - Notificações ativadas para validação do recebimento de avisos de vagas e confirmações de turno via APNs/FCM.
- **Credenciais de Teste:** [A DEFINIR: conta de teste de cada aparelho e como recebe o código]; [A DEFINIR: código OTP em aparelho real (em simulador/desenvolvimento usa-se 123456)].

---

## 3. Matriz Sintética do Ciclo Sincronizado

| Passo | Aparelho A (Contratante) | Aparelho B (Profissional) | Tela Ativa (origin/main) | Comportamento Esperado no App | Check Cauê |
|:---:|---|---|---|---|:---:|
| **01** | Autenticação e cadastro com perfil Contratante, dados do responsável e estabelecimento no DF. | App em repouso. | `TelaEntrada.swift:40,61`<br>`TelaCodigo.swift:95,117`<br>`TelaCadastro.swift:78,89,175`<br>`CadastroEstabelecimento.swift:220` | Cadastro concluído com sucesso; transição direta para a tela de publicação de vagas. | `[ ]` |
| **02** | App em repouso. | Autenticação e cadastro com perfil Profissional, funções (Garçom) e ponto base no DF. | `TelaEntrada.swift:40,61`<br>`TelaCodigo.swift:95,117`<br>`TelaCadastro.swift:78,89,175`<br>`TelaPerfilProfissional.swift:69,112,127` | Perfil configurado com sucesso; redirecionamento para o feed principal de vagas. | `[ ]` |
| **03** | Configura vaga de urgência (data de hoje, horário, 1 vaga, valor da diária) e publica. | Permanece no feed de vagas do DF. | `PublicarVaga.swift:671`<br>`MinhasVagas.swift:367` | Vaga gravada no backend; Aparelho A exibe vaga ativa em "Minhas vagas" (0/1 ocupada). | `[ ]` |
| **04** | Aguarda candidatura em "Minhas vagas". | Atualiza o feed de vagas, localiza a vaga da casa e abre os detalhes. | `TelaVagas.swift:31,119`<br>`TelaDetalheVaga.swift:94` | Aparelho B visualiza a vaga no feed e exibe horário, remuneração sem desconto e local em detalhes. | `[ ]` |
| **05** | Mantém tela de acompanhamento aberta. | Toca no botão "Candidatar-me" (`candidatar`). | `TelasDaCandidatura.swift:51`<br>`TelasDaCandidatura.swift:260` | Modo Urgência confirma vaga de imediato sem triagem; Aparelho B exibe tela de sucesso e confirmação. | `[ ]` |
| **06** | Atualiza "Minhas vagas": vaga agora exibe "1/1 ocupada" e abre o detalhe do turno. | Abre a aba "Meus turnos" e acessa o turno confirmado. | `MinhasVagas.swift:659`<br>`TelaTurnoDoContratante.swift:155`<br>`TelaMeusTurnos.swift:71,92`<br>`TelaMeuTurno.swift:71,223,235` | **Liberação bilateral de contatos (RN10):** Aparelho A visualiza dados do profissional; Aparelho B visualiza contato da casa. | `[ ]` |
| **07** | Acompanha turno: status indica "Aguardando check-in". | No turno, aciona "Fazer check-in" (via GPS ou registro manual de contingência). | `SecaoDePresenca.swift:42,63,87`<br>`TelaMeuTurno.swift:71,133` | Presença registrada. Se via GPS ($\le 250$m), presença é verificada de imediato; se manual, exibe "Aguardando confirmação". | `[ ]` |
| **08** | Na tela do turno, localiza pendência de check-in manual e toca em "Confirmar presença". *(Pular se GPS)* | Atualiza a tela Meu Turno. | `TelaTurnoDoContratante.swift:457`<br>`TelaMeuTurno.swift:133` | Presença do turno passa para status "Presença verificada" em ambos os aparelhos com registro de horário. | `[ ]` |
| **09** | Acompanha andamento do turno. | Ao término do horário de expediente, toca em "Fazer check-out". | `SecaoDePresenca.swift:32,66`<br>`TelaMeuTurno.swift:133` | Check-out registrado; status do turno passa para "Concluído" / "Encerrado", liberando formulário de avaliação. | `[ ]` |
| **10** | Aguarda avaliação do profissional. | Toca em "Avaliar turno", responde "Você trabalharia nesse local de novo?" (Sim) e envia. | `TelaMeuTurno.swift:303`<br>`TelaAvaliacao.swift:60,127` | Avaliação registrada com sucesso; botão de avaliação passa para inativo/enviado no Aparelho B. | `[ ]` |
| **11** | No turno em Minhas Vagas, toca em "Avaliar profissional", responde "Chamaria este profissional de novo?" (Sim) e envia. | Mantém app aberto. | `TelaTurnoDoContratante.swift:277,524`<br>`TelaAvaliacao.swift:60,127` | Avaliação do contratante registrada com sucesso; tela exibe "Resposta: Sim" e botão "Ver avaliação". | `[ ]` |
| **12** | Toca em "Ver avaliação": constata aviso de avaliação já enviada e bloqueio de reenvio. | Consulta histórico em "Meus turnos" e perfil profissional. | `TelaAvaliacao.swift:97`<br>`TelaHistoricoDeTurnos.swift:36`<br>`PerfisDaConta.swift:200,295` | Turno 100% finalizado; reputação e histórico atualizados bilateralmente, sem permitir duplicidade. | `[ ]` |

---

## 4. Detalhamento Operacional Passo a Passo

### Passo 01 — Autenticação e Cadastro do Contratante (Aparelho A)
- **Aparelho:** A (Contratante)
- **Telas e Elementos (`origin/main`):**
  - `TelaEntrada` (`iOS/Sources/Apresentacao/Fluxos/Autenticacao/TelaEntrada.swift:40` para campo `entrada-email`, `:61` para botão `entrada-receber-codigo`)
  - `TelaCodigo` (`iOS/Sources/Apresentacao/Fluxos/Autenticacao/TelaCodigo.swift:95` para campo `codigo-campo`, `:117` para botão `codigo-entrar`)
  - `TelaCadastro` (`iOS/Sources/Apresentacao/Fluxos/Autenticacao/TelaCadastro.swift:78` para `cadastro-nome`, `:89` para `cadastro-telefone`, `:153` para `cadastro-termos`, `:175` para `cadastro-continuar`)
  - `CadastroEstabelecimento` (`iOS/Sources/Apresentacao/Fluxos/Contratante/CadastroEstabelecimento.swift:202` para tipo, `:211` para RA, `:220` para `continuar-cadastro`)
- **Ações a Executar:**
  1. Abrir o app e, em `TelaEntrada`, digitar o e-mail da conta de teste do contratante no campo `entrada-email`. Tocar em "Receber código de acesso" (`entrada-receber-codigo`).
  2. Em `TelaCodigo`, inserir o código de verificação recebido (ou código padrão de teste do ambiente) e tocar em "Entrar" (`codigo-entrar`).
  3. Em `TelaCadastro`, selecionar o cartão "Quero contratar profissionais" (`cadastro-perfil-contratante`).
  4. Preencher o nome do responsável em `cadastro-nome` (ex.: "Gerente Carlos"), telefone celular com DDD em `cadastro-telefone` (ex.: "61988887777") e data de nascimento em `cadastro-nascimento` (ex.: "10/05/1990").
  5. Marcar o seletor de concordância com os termos de uso (`cadastro-termos`). A maioridade é conferida pela data de nascimento. Tocar em "Continuar" (`cadastro-continuar`).
  6. Em `CadastroEstabelecimento`, inserir nome do estabelecimento (ex.: "Café da Asa"), telefone comercial e endereço físico completo no DF. Tocar no botão "Continuar cadastro" (`continuar-cadastro`).
- **Resultado Esperado:** Conta criada no backend (`public.criar_conta('contratante')`) e estabelecimento registrado (`public.cadastrar_estabelecimento`). O aplicativo direciona imediatamente para `TelaPublicarVaga`.

---

### Passo 02 — Autenticação e Configuração do Profissional (Aparelho B)
- **Aparelho:** B (Profissional)
- **Telas e Elementos (`origin/main`):**
  - `TelaEntrada` (`iOS/Sources/Apresentacao/Fluxos/Autenticacao/TelaEntrada.swift:40` para campo `entrada-email`, `:61` para botão `entrada-receber-codigo`)
  - `TelaCodigo` (`iOS/Sources/Apresentacao/Fluxos/Autenticacao/TelaCodigo.swift:95` para campo `codigo-campo`, `:117` para botão `codigo-entrar`)
  - `TelaCadastro` (`iOS/Sources/Apresentacao/Fluxos/Autenticacao/TelaCadastro.swift:78` para `cadastro-nome`, `:89` para `cadastro-telefone`, `:153` para `cadastro-termos`, `:175` para `cadastro-continuar`)
  - `TelaPerfilProfissional` (`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaPerfilProfissional.swift:69` para `botao-salvar-perfil`, `:112` para funções, `:127` para `campo-ponto-base`)
- **Ações a Executar:**
  1. Abrir o app no Aparelho B e digitar o e-mail da conta de teste do profissional em `TelaEntrada`. Tocar em "Receber código de acesso".
  2. Inserir o código de verificação recebido (ou código padrão de teste do ambiente) em `TelaCodigo` e tocar em "Entrar".
  3. Em `TelaCadastro`, selecionar o cartão "Quero trabalhar em turnos" (`cadastro-perfil-profissional`).
  4. Preencher nome completo (ex.: "Lucas Silva"), telefone WhatsApp (ex.: "61977776666"), data de nascimento maior de 18 anos, marcar os termos de uso e tocar em "Continuar".
  5. Em `TelaPerfilProfissional`, selecionar a função correspondente ao teste (ex.: "Garçom"), definir o ponto base em bairro do DF (ex.: "Asa Sul") e salvar o perfil tocando em `botao-salvar-perfil`.
- **Resultado Esperado:** Conta criada (`public.criar_conta('profissional')`) e perfil profissional salvo com funções ativas. O app transita para a aba principal de mural de vagas no DF (`TelaVagas`).

---

### Passo 03 — Publicação de Vaga em Modo Urgência (Aparelho A)
- **Aparelho:** A (Contratante)
- **Telas e Elementos (`origin/main`):**
  - `PublicarVaga` (`iOS/Sources/Apresentacao/Fluxos/Contratante/PublicarVaga.swift:562-585` para seleção de modo e prazos, `:671` para botão `publicar-vaga-botao`)
  - `MinhasVagas` (`iOS/Sources/Apresentacao/Fluxos/Contratante/MinhasVagas.swift:367` para lista `minhas-vagas`)
- **Ações a Executar:**
  1. Na `TelaPublicarVaga`, selecionar a função ("Garçom").
  2. Manter selecionada a data de hoje (modo de urgência automático para turnos imediatos, com menos de 24 horas).
  3. Definir o horário de início (ex.: 19h00) e término (ex.: 23h00).
  4. Inserir o valor líquido total do turno (ex.: R$ 150,00) no campo `CampoValorVaga`.
  5. Rolar a tela até o rodapé e tocar no botão "Publicar vaga" (`publicar-vaga-botao`).
- **Resultado Esperado:** Vaga criada no Supabase (`public.publicar_vaga`) e despachada (SLA RNF03 $\le 30$ s). O app transita para `MinhasVagas`, onde a vaga aparece listada na seção "Hoje" com status "0/1 preenchida".

---

### Passo 04 — Descoberta e Visualização de Detalhes da Vaga (Aparelho B)
- **Aparelho:** B (Profissional)
- **Telas e Elementos (`origin/main`):**
  - `TelaVagas` (`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaVagas.swift:31` para `tela-vagas`, `:119` para cartões `vaga-*`)
  - `TelaDetalheVaga` (`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaDetalheVaga.swift:94` para `tela-detalhe-vaga`, `:174` para reputação)
- **Ações a Executar:**
  1. Na `TelaVagas`, realizar gesto de puxar para atualizar (pull-to-refresh).
  2. Localizar o cartão correspondente à vaga publicada pelo Aparelho A (exibindo função, valor integral sem descontos e distância/região).
  3. Tocar no cartão da vaga para abrir `TelaDetalheVaga`.
  4. Conferir as informações da tela: valor total garantido, horário, endereço/ponto de referência e orientações de vestimenta/requisitos.
- **Resultado Esperado:** A vaga é exibida corretamente no feed do DF e a tela de detalhe exibe o botão principal "Candidatar-me" (`candidatar`) ativo e visível.

---

### Passo 05 — Candidatura e Confirmação Imediata de Urgência (Aparelho B)
- **Aparelho:** B (Profissional)
- **Telas e Elementos (`origin/main`):**
  - `AreaDeCandidatura` (`iOS/Sources/Apresentacao/Fluxos/Profissional/TelasDaCandidatura.swift:51` para botão `candidatar`)
  - `TelaResultadoDaCandidatura` (`iOS/Sources/Apresentacao/Fluxos/Profissional/TelasDaCandidatura.swift:260` para `resultado-confirmada`, `:283` para `contato-do-turno`)
- **Ações a Executar:**
  1. Na `TelaDetalheVaga`, tocar no botão "Candidatar-me" (`candidatar`).
- **Resultado Esperado (RN02 e RN21):** Como a vaga opera em regime de Urgência (início em menos de 24 horas), a posição é confirmada imediatamente no ato do aceite sem depender de triagem pelo contratante. O app apresenta `TelaResultadoDaCandidatura` com o identificador `resultado-confirmada`, orientações sobre chegada e atalho "Ver meu turno".

---

### Passo 06 — Consulta do Turno e Liberação Bilateral de Contato (Ambos os Aparelhos)
- **Aparelhos:** A (Contratante) e B (Profissional)
- **Telas e Elementos (`origin/main`):**
  - Aparelho A: `MinhasVagas` (`MinhasVagas.swift:659` para `detalhe-vaga-contratante`, `:703` para `contato-liberado-*`, `:737` para `acompanhar-turno-*`) e `TelaTurnoDoContratante` (`TelaTurnoDoContratante.swift:155` para `turno-do-contratante`)
  - Aparelho B: `TelaMeusTurnos` (`TelaMeusTurnos.swift:71` para `tela-meus-turnos`, `:92` para `meu-turno-*`) e `TelaMeuTurno` (`TelaMeuTurno.swift:71` para `tela-meu-turno`, `:223` para `contato-telefone`, `:235` para `botao-whatsapp`)
- **Ações a Executar:**
  1. No Aparelho B, tocar em "Ver meu turno" (ou abrir a aba "Meus turnos" e tocar no cartão do turno confirmado).
  2. No Aparelho A, atualizar `MinhasVagas` (que agora exibe "1/1 preenchida"), tocar na vaga e em "Acompanhar turno" (`acompanhar-turno-*`).
- **Resultado Esperado (RN10):**
  - No Aparelho B (`TelaMeuTurno`), o cartão de contato liberado (`contato-do-turno`) exibe o nome do responsável e telefone/WhatsApp da casa, além do mapa de rota.
  - No Aparelho A (`TelaTurnoDoContratante`), o card do profissional alocado exibe o nome, telefone/WhatsApp de contato e status "Aguardando check-in".

---

### Passo 07 — Presença no Local: Check-in e Contingência (Aparelho B)
- **Aparelho:** B (Profissional)
- **Telas e Elementos (`origin/main`):**
  - `TelaMeuTurno` (`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeuTurno.swift:71` para `tela-meu-turno`, `:133` para `estado-do-turno`)
  - `SecaoDePresenca` (`iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:42` para `presenca-do-turno`, `:63` para `fazer-checkin`, `:87` para `registro-manual`)
- **Ações a Executar:**
  1. Na `TelaMeuTurno`, localizar o botão "Fazer check-in" (`fazer-checkin`).
  2. **Caminho Normal (GPS $\le 250$m do local):** Tocar em "Fazer check-in". O CoreLocation captura latitude/longitude do aparelho e valida a presença via `public.fazer_checkin_geolocalizado`.
  3. **Caminho de Contingência (Sem GPS ou distância $>250$m):** Tocar em "Fazer check-in" $\to$ tela informa impossibilidade de capturar localização precisa (`sem-gps`) $\to$ tocar no botão "Registro manual" (`registro-manual`).
- **Resultado Esperado:**
  - Se via GPS: status muda de imediato para "Presença verificada".
  - Se manual: status exibe "Aguardando confirmação do contratante" (`checkin-situacao`).

---

### Passo 08 — Confirmação Presencial do Check-in pelo Contratante (Aparelho A — se manual)
- **Aparelho:** A (Contratante)
- **Telas e Elementos (`origin/main`):**
  - `TelaTurnoDoContratante` (`iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:155` para `turno-do-contratante`)
  - `PendenciasDoContratante` (`TelaTurnoDoContratante.swift:457` para botão `confirmar-presenca-*`)
  - `TelaMeuTurno` (`TelaMeuTurno.swift:133` para status `estado-do-turno`)
- **Ações a Executar:**
  *(Executar somente se o Aparelho B tiver acionado a contingência de check-in manual)*
  1. Na `TelaTurnoDoContratante`, puxar para atualizar.
  2. Observar a seção `PendenciasDoContratante` indicando check-in pendente do profissional.
  3. Tocar no botão "Confirmar presença" (`confirmar-presenca-*`).
- **Resultado Esperado:** Chamada à RPC `confirmar_checkin_manual`. O status em ambos os aparelhos passa para "Presença verificada" com carimbo de data e hora visível.

---

### Passo 09 — Encerramento do Expediente: Check-out (Aparelho B)
- **Aparelho:** B (Profissional)
- **Telas e Elementos (`origin/main`):**
  - `TelaMeuTurno` (`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeuTurno.swift:71` para `tela-meu-turno`, `:133` para `estado-do-turno`)
  - `SecaoDePresenca` (`iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:32` para `checkout-situacao`, `:66` para botão `fazer-checkout`)
- **Ações a Executar:**
  1. Na `TelaMeuTurno`, com a presença já verificada, localizar e tocar no botão "Fazer check-out" (`fazer-checkout`).
  2. Confirmar o encerramento do turno (seja via localização ou registro manual de saída).
- **Resultado Esperado:** Registro do check-out no backend (`public.fazer_checkout`). O turno é encerrado com status "Concluído", liberando o cartão de avaliação mútua em ambos os aparelhos.

---

### Passo 10 — Avaliação do Local pelo Profissional (Aparelho B)
- **Aparelho:** B (Profissional)
- **Telas e Elementos (`origin/main`):**
  - `TelaMeuTurno` (`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeuTurno.swift:303` para `botao-abrir-avaliacao`)
  - `TelaAvaliacao` (`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaAvaliacao.swift:60` para `pergunta-avaliacao`, `:127` para `botao-enviar-avaliacao`)
- **Ações a Executar:**
  1. Na `TelaMeuTurno`, rolar até o cartão `cartao-avaliacao-turno` e tocar em "Avaliar turno" (`botao-abrir-avaliacao`).
  2. Na `TelaAvaliacao`, conferir a pergunta obrigatória: *"Você trabalharia nesse local de novo?"* (`pergunta-avaliacao`).
  3. Tocar na opção "Sim" (`resposta-sim`).
  4. Tocar no botão "Enviar avaliação" (`botao-enviar-avaliacao`).
- **Resultado Esperado (RN13):** Avaliação gravada com sucesso (`aviso-sucesso-avaliacao`). Ao retornar para `TelaMeuTurno`, o botão passa para inativo/desaparece, impedindo duplicidade.

---

### Passo 11 — Avaliação do Profissional pelo Contratante (Aparelho A)
- **Aparelho:** A (Contratante)
- **Telas e Elementos (`origin/main`):**
  - `TelaTurnoDoContratante` (`iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:277` para `botao-abrir-avaliacao`, `:261` para `botao-ver-avaliacao`, `:284` para `cartao-avaliacao-turno`)
  - `DestinoAvaliacaoDoContratante` (`TelaTurnoDoContratante.swift:524` para instanciação de `TelaAvaliacao`)
  - `TelaAvaliacao` (`TelaAvaliacao.swift:60` para `pergunta-avaliacao`, `:127` para `botao-enviar-avaliacao`)
- **Ações a Executar:**
  1. Na `TelaTurnoDoContratante`, rolar até o cartão `cartao-avaliacao-turno` e tocar em "Avaliar profissional" (`botao-abrir-avaliacao`).
  2. Na `TelaAvaliacao`, conferir a pergunta obrigatória: *"Chamaria este profissional de novo?"* (`pergunta-avaliacao`).
  3. Tocar na opção "Sim" (`resposta-sim`).
  4. Tocar no botão "Enviar avaliação" (`botao-enviar-avaliacao`).
- **Resultado Esperado (RN13):** Avaliação gravada no Supabase (`public.avaliar_turno`). A tela do turno é atualizada exibindo "Resposta: Sim" e o botão passa a exibir "Ver avaliação" (`botao-ver-avaliacao`).

---

### Passo 12 — Verificação de Imutabilidade, Histórico e Reputação (Ambos os Aparelhos)
- **Aparelhos:** A e B
- **Telas e Elementos (`origin/main`):**
  - `TelaAvaliacao` (`TelaAvaliacao.swift:97` para `aviso-ja-avaliado`)
  - `TelaHistoricoDeTurnos` (`iOS/Sources/Apresentacao/Fluxos/Perfil/TelaHistoricoDeTurnos.swift:36` para `historico-exportar`)
  - `PerfisDaConta` (`iOS/Sources/Apresentacao/Fluxos/Perfil/PerfisDaConta.swift:200` para exportar dados no perfil, `:295` para `estabelecimento-equipe-de-confianca`)
- **Ações a Executar:**
  1. No Aparelho A, tocar em "Ver avaliação": verificar que a tela abre em modo somente leitura com aviso `aviso-ja-avaliado` e sem botão de envio.
  2. No Aparelho B, abrir aba "Perfil" $\to$ "Histórico de turnos": verificar que o turno concluído aparece com carimbo de verificado e avaliação registrada.
  3. Em ambos os perfis públicos, constatar a atualização de presença e taxa de comparecimento.
- **Resultado Esperado:** Ciclo 100% íntegro, dados persistidos sem corrupção, reputação calculada e imutabilidade garantida.

---

## 5. Procedimentos de Contingência e Regras de Bloqueio

Durante o teste manual com os dois iPhones físicos, caso ocorra qualquer anormalidade:

1. **Falha de Notificação Push (Aviso não chega ao Aparelho B):**
   - *Procedimento de Teste:* O profissional deve abrir o aplicativo manualmente e atualizar o feed em `TelaVagas`.
   - *Anotação:* Se o push não foi entregue em até 60 segundos após o despacho, registrar como potencial defeito de latência RNF02 no cartão.
2. **Impossibilidade de Check-in por GPS (Distância $> 250$m ou sinal fraco):**
   - *Procedimento de Teste:* Acionar a contingência manual prevista na arquitetura (`Passo 07` e `Passo 08`).
   - *Critério:* O sistema **não pode travar nem impedir o turno**; o contratante deve conseguir validar manualmente no local.
3. **Comportamento em Falha de Conexão Temporária:**
   - As ações de check-in e avaliação devem ser enfileiradas na fila offline (`CacheSwiftData.swift:246`) e sincronizadas assim que a conexão retornar, sem crash.
4. **Classificação de Defeitos Encontrados:**
   - **Bloqueante (Impede o ciclo):** Ex.: crash em qualquer tela, falha na gravação de presença, impossibilidade de enviar avaliação. Acionar abertura imediata de cartão no Sprint 3 com logs do console.
   - **Grave (Não bloqueia, mas degrada):** Ex.: atraso de atualização superior a 10s no feed, inconsistência no texto de contato liberado.
