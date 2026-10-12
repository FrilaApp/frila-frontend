# Roteiro de Usabilidade e Folha de Registro das Sessões com Usuários

Documento oficial de planejamento, condução, registro e síntese da segunda rodada de testes de usabilidade com pessoas usuárias no TestFlight externo e builds internos.
Vinculado ao Cartão Trello [Q4ZZwnMR (T-0018)](https://trello.com/c/Q4ZZwnMR) — *S2 · Produto + Design · Testes de usabilidade com usuários no TestFlight*.

- **Sprint:** S2 · Despacho e turno (20/10 a 02/11)
- **Janela de Execução:** 23/10/2026 a 29/10/2026 (apresentação da síntese em 29/10; 30/10 e 02/11 constam como feriados na agenda do C18)
- **Responsáveis:** Júlia (condução das sessões) e Fabrício (síntese e análise)
- **Requisitos e Histórias:** RNF09 (Usabilidade para público não habituado a apps profissionais), T-0018 (Segunda rodada com usuários), RN01 (Valor integral sem descontos), RN10 (Liberação de contato pós-confirmação), RN13 (Reputação binária e comparecimento), RNF02/RNF03 (Entrega e despacho).
- **Referências Normativas:**
  - `iOS/Docs/PlanoDoPiloto.md` (Metas de despacho, piloto de 13/11 a 04/12, contingências)
  - `iOS/Docs/PlanoDeMetricas.md` (Funil de produto e eventos de telemetria)
  - `iOS/Docs/GuiaDeVoz.md` (Vocabulário oficial, garantia de valor integral sem descontos, tom direto e sem promessa)
  - `iOS/Docs/TriagemUsabilidadeERegressao.md` (Matriz de severidade: Bloqueante, Grave, Médio, Baixo)
  - `iOS/Docs/LGPD.md` e `iOS/Docs/RegistroDeTratamentoLGPD.md` (Anonimização estrita e ausência de dados pessoais)

---

## 1. Tarefas por Perfil que Medem o RNF09

O requisito **RNF09** estabelece que pessoas não habituadas a aplicativos corporativos complexos devem concluir as tarefas centrais do Frila sem treinamento formal e sem assistência técnica de terceiros.

A avaliação divide-se estritamente por build disponível:
1. **Build 0.4 (TestFlight Externo — liberado a partir de 23/10):** Validação dos fluxos de publicação para hoje, localização da vaga no mural, envio de candidatura e visualização do contato liberado da casa.
2. **Build Interno (instalado em iPhones de teste da equipe):** Validação de check-in, check-out, avaliação mútua e exclusão de conta (LGPD), restrito aos builds em que tais telas já estejam integradas.
3. **Regra de Escopo Temporal:** Conforme o cartão Q4ZZwnMR, qualquer fluxo que não esteja disponível nos builds até 29/10 não é forçado e deve constar expressamente na síntese como **"Não testado nesta rodada"**.

---

### 1.1 Perfil: Profissional de Primeira Viagem

O profissional participante simula sua primeira experiência com o aplicativo Frila no Distrito Federal, sem ter recebido instruções prévias da equipe.

#### Tarefa P1: Acesso Inicial e Definição de Ponto Base (Build 0.4)
- **Objetivo Operacional:** Realizar a entrada com e-mail e código de acesso, aceitar os termos de uso e política de privacidade, e salvar ao menos uma função e seu ponto base (bairro/região do DF).
- **Ponto de Partida:** Tela de entrada inicial (`TelaEntrada`).
- **Instrução Neutra ao Participante:**  
  > *"Imagine que você instalou o Frila pela primeira vez para encontrar turnos em bares e restaurantes no DF. Faça seu cadastro inicial e deixe o app pronto para uso."*
- **Critério de Sucesso Estrito:**
  - **Sem ajuda (Sucesso RNF09):** O profissional insere o e-mail em `TelaEntrada`, digita o código recebido em `TelaCodigo`, seleciona a opção "Quero trabalhar em turnos" (`cadastro-perfil-profissional`) em `TelaCadastro`, preenche os dados pessoais (nome, telefone com WhatsApp, data de nascimento, declaração de maioridade e termos de uso), define sua função e ponto base em `TelaPerfilProfissional` e conclui o cadastro sem perguntar ao moderador como avançar.
  - **Com ajuda (Falha RNF09):** O moderador precisa explicar o que é "ponto base", onde clicar para prosseguir ou esclarecer o código de verificação.
  - **Não concluiu:** Desistência, erro de validação sem recuperação ou travamento da tela.
- **Caminho Esperado na Interface:** `TelaEntrada` $\to$ `TelaCodigo` $\to$ `TelaCadastro` (escolha de perfil "Quero trabalhar em turnos", dados pessoais e termos) $\to$ `TelaPerfilProfissional` (funções, horários e ponto base) $\to$ `TelaVagas` (aba `Vagas`).

#### Tarefa P2: Descoberta e Candidatura sem Ajuda — *Métrica Central RNF09* (Build 0.4)
- **Objetivo Operacional:** Localizar uma vaga compatível no mural "Vagas no DF" e submeter uma candidatura sem intervenção técnica.
- **Ponto de Partida:** Aba `Vagas` (`TelaVagas`).
- **Instrução Neutra ao Participante:**  
  > *"Você tem a noite de hoje livre e deseja trabalhar como garçom (ou auxiliar). Encontre uma vaga que atenda ao seu horário e demonstre seu interesse nela."*
- **Critério de Sucesso Estrito:**
  - **Sem ajuda (Sucesso RNF09):** O participante examina a listagem em `TelaVagas`, toca no cartão da vaga, lê os detalhes em `TelaDetalheVaga` (horário, local no DF e valor fechado do turno sem descontos) e aciona o botão principal de candidatura (`candidatar`).
  - **Com ajuda (Falha RNF09):** O participante não identifica onde tocar para ver os detalhes, confunde o modo de urgência com o modo seleção, ou solicita ajuda para saber se a candidatura foi realmente registrada.
  - **Não concluiu:** Abandono da tarefa, toque repetido sem resposta ou fechamento inesperado do aplicativo.
- **Caminho Esperado na Interface:** `TelaVagas` $\to$ `TelaDetalheVaga` $\to$ Toque em "Candidatar-me" (`candidatar`) $\to$ `TelaResultadoDaCandidatura` (`resultado-confirmada`).

#### Tarefa P3: Visualização do Turno e Contato Liberado — RN10 (Build 0.4)
- **Objetivo Operacional:** Consultar o turno confirmado na aba `Meus turnos` e identificar o canal direto de comunicação com o estabelecimento contratante.
- **Ponto de Partida:** Tela de resultado de candidatura ou navegação principal.
- **Instrução Neutra ao Participante:**  
  > *"Sua presença foi confirmada para esse turno. Como você faria para ver o endereço completo e entrar em contato com o responsável pelo bar antes de ir?"*
- **Critério de Sucesso Estrito:**
  - **Sem ajuda (Sucesso RNF09):** O participante navega até a aba `Meus turnos` (`TelaMeusTurnos`), abre o cartão do turno confirmado e localiza os dados de contato do contratante em `TelaMeuTurno` (botão de WhatsApp / telefone do estabelecimento liberados após a confirmação, conforme RN10).
  - **Com ajuda (Falha RNF09):** O participante procura os dados de contato dentro da aba `Vagas` ou não compreende onde acessar seus turnos ativos.
  - **Não concluiu:** Não localiza a tela de detalhes do turno ou não identifica as informações de contato.
- **Caminho Esperado na Interface:** Aba `Meus turnos` (`TelaMeusTurnos`) $\to$ Cartão `meu-turno-*` $\to$ `TelaMeuTurno` $\to$ Cartão `contato-do-turno`.

#### Tarefa P4: Percepção de Reputação e Decisão — *Investigação Matriz CSD* (Build 0.4)
- **Objetivo Operacional:** Avaliar a compreensão do modelo de reputação binária e taxa de comparecimento do Frila, medindo a percepção de segurança sem notas por estrelas.
- **Ponto de Partida:** Tela de detalhes da vaga ou perfil do estabelecimento.
- **Instrução Neutra ao Participante:**  
  > *"Olhando para este estabelecimento na tela, você nota a informação '7 de 7 trabalhariam lá de novo'. O que essa informação significa para você? Você se sentiria seguro para aceitar o turno?"*
- **Critério de Registro:** Não se trata de aprovação/reprovação funcional, mas de registro qualitativo neutro sobre a clareza do modelo binário do Frila (RN13 / Guia de Voz).

#### Tarefas Complementares para Build Interno (Se Disponível até 29/10)
- **Tarefa P5 (Presença):** Realizar check-in presencial no início do turno (geolocalização ou contingência manual sem GPS em `TelaMeuTurno`).
- **Tarefa P6 (Avaliação):** Responder à pergunta única de encerramento do turno em `TelaAvaliacao`: *"Você trabalharia nesse local de novo? (Sim / Não)"*.
- **Tarefa P7 (Privacidade):** Localizar o botão de exclusão definitiva de conta (`TelaExclusaoDeConta`) acessado pelo menu `Perfil` (LGPD).
- *Nota:* Caso o build interno instalado no aparelho de teste não contenha estas telas até o dia da sessão, marcar formalmente como **"Não testado nesta rodada"**.

---

### 1.2 Perfil: Contratante de Primeira Viagem

O contratante participante (gerente, proprietário ou responsável por escala de bar/restaurante no DF) simula a publicação e o acompanhamento de uma demanda operacional urgente.

#### Tarefa C1: Primeiro Acesso e Cadastro do Estabelecimento (Build 0.4)
- **Objetivo Operacional:** Criar o acesso do gestor, preencher dados essenciais do estabelecimento (nome fantasia, documento e endereço no DF) e alcançar a tela principal de contratação.
- **Ponto de Partida:** Tela de entrada inicial (`TelaEntrada`).
- **Instrução Neutra ao Participante:**  
  > *"Imagine que você gerencia um restaurante na Asa Sul e precisa cadastrar seu estabelecimento para cobrir um desfalque na escala de hoje. Conclua seu cadastro inicial."*
- **Critério de Sucesso Estrito:**
  - **Sem ajuda (Sucesso RNF09):** O contratante realiza a autenticação por código em `TelaEntrada` e `TelaCodigo`, escolhe a opção "Quero contratar para o meu negócio" (`cadastro-perfil-contratante`) em `TelaCadastro`, preenche dados pessoais e termos legais, completa os dados do local em `TelaCadastroEstabelecimento` (nome fantasia, documento e endereço no DF) e atinge a aba `Minhas vagas` (`TelaMinhasVagas`) de forma autônoma.
  - **Com ajuda (Falha RNF09):** O contratante não compreende a separação entre dados pessoais e dados do estabelecimento, ou precisa de suporte para validar o endereço.
  - **Não concluiu:** Abandono ou falha de validação bloqueante.
- **Caminho Esperado na Interface:** `TelaEntrada` $\to$ `TelaCodigo` $\to$ `TelaCadastro` (escolha de perfil "Quero contratar para o meu negócio", dados pessoais e termos) $\to$ `TelaCadastroEstabelecimento` (nome fantasia, documento e endereço no DF) $\to$ `TelaMinhasVagas` (aba `Minhas vagas`).

#### Tarefa C2: Publicar uma Vaga para Hoje — *Métrica Central RNF09* (Build 0.4)
- **Objetivo Operacional:** Publicar uma vaga para a data corrente em modo urgência, informando função, horário de entrada/saída e remuneração total líquida, sem auxílio do moderador.
- **Ponto de Partida:** Aba `Minhas vagas` (`TelaMinhasVagas`) através do botão "Publicar vaga" (`publicar-vaga-entrada`).
- **Instrução Neutra ao Participante:**  
  > *"Faltou um auxiliar de cozinha para o turno de hoje à noite, das 18h às 23h. O valor fechado que você pagará ao profissional pelo turno cumprido é de R$ 140. Publique essa vaga no aplicativo."*
- **Critério de Sucesso Estrito:**
  - **Sem ajuda (Sucesso RNF09):** O contratante aciona o botão "Publicar vaga" (`publicar-vaga-entrada`) em `TelaMinhasVagas`, preenche os campos em `TelaPublicarVaga` (função, horários de início e fim, valor do turno de R$ 140,00 integral sem cobrança de taxas nem descontos) e aciona o botão de envio "Publicar vaga" (`publicar-vaga-botao`).
  - **Com ajuda (Falha RNF09):** O participante tem dúvidas sobre como configurar o horário, questiona o moderador sobre cobranças e descontos ou não encontra o botão de envio.
  - **Não concluiu:** Erro impeditivo de validação, encerramento do app ou incapacidade de finalizar o envio.
- **Caminho Esperado na Interface:** `TelaMinhasVagas` $\to$ Botão "Publicar vaga" (`publicar-vaga-entrada`) $\to$ `TelaPublicarVaga` $\to$ Preenchimento dos campos $\to$ Botão "Publicar vaga" (`publicar-vaga-botao`) $\to$ Confirmação e retorno a `TelaMinhasVagas`.

#### Tarefa C3: Acompanhamento da Vaga Publicada (Build 0.4)
- **Objetivo Operacional:** Visualizar a vaga ativa na aba `Minhas vagas`, verificando o status de preenchimento e posições em aberto.
- **Ponto de Partida:** Aba `Minhas vagas` (`TelaMinhasVagas`).
- **Instrução Neutra ao Participante:**  
  > *"A vaga foi criada. Onde você confere se ela já está visível e quantas vagas ainda faltam preencher?"*
- **Critério de Sucesso Estrito:**
  - **Sem ajuda (Sucesso RNF09):** O contratante localiza o cartão da vaga em `TelaMinhasVagas`, identifica o status de urgência e a contagem de posições restantes (ex.: "0 de 1 preenchida").
  - **Com ajuda (Falha RNF09):** O contratante navega para abas incorretas ou não compreende a sinalização de status da vaga.
  - **Não concluiu:** Não encontra a vaga publicada na listagem.

#### Tarefa C4: Decisão de Escolha e Reputação — *Investigação Matriz CSD* (Build 0.4)
- **Objetivo Operacional:** Avaliar se o contratante compreende a métrica de reputação binária e histórico de presença ao analisar um perfil de profissional (requisito explícito do cartão Q4ZZwnMR).
- **Ponto de Partida:** Tela de visualização de candidatos ou perfil de profissional simulado.
- **Instrução Neutra ao Participante:**  
  > *"Você chamaria este profissional? O que a informação '7 de 7 contratantes chamariam de novo' e '100% de presença' te diz?"*
- **Critério de Registro:** Anotar detalhadamente a percepção de segurança da decisão: o contratante sente falta de notas de 1 a 5 estrelas? A taxa de comparecimento (turnos cumpridos vs faltas) é suficiente para a contratação?

#### Tarefas Complementares para Build Interno (Se Disponível até 29/10)
- **Tarefa C5 (Acompanhamento e Avaliação):** Abrir o turno encerrado em `TelaTurnoDoContratante`, verificar confirmação de presença e submeter a avaliação do contratante em `TelaAvaliacao`: *"Chamaria este profissional de novo? (Sim / Não)"*.
- **Tarefa C6 (Privacidade):** Localizar o fluxo de exclusão de dados do estabelecimento (`TelaExclusaoDeConta`) em `Perfil`.
- *Nota:* Registrar como **"Não testado nesta rodada"** se ausente no build do aparelho.

---

## 2. Roteiro da Sessão Moderada (~20 Minutos)

O roteiro a seguir foi estruturado para sessões com duração média de 20 minutos (teto de 30 minutos em casos de atrito pontual), garantindo condução uniforme por Júlia, linguagem estritamente neutra e observação sem indução.

```
┌────────────────────────────────────────────────────────────────────────┐
│                   ESTRUTURA DA SESSÃO MODERADA (~20 min)               │
├─────────────────────┬──────────┬───────────────────────────────────────┤
│ Bloco               │ Duração  │ Foco Principal                        │
├─────────────────────┼──────────┼───────────────────────────────────────┤
│ 1. Abertura e TCLE  │ ~3 min   │ Alinhamento, consentimento e conforto │
│ 2. Contextualização │ ~2 min   │ Perfil operacional (sem dados ident.) │
│ 3. Execução Tarefas │ ~12 min  │ Observação de RNF09 e Think Aloud     │
│ 4. Fechamento       │ ~3 min   │ Percepção geral e impressão de valor  │
└─────────────────────┴──────────┴───────────────────────────────────────┘
```

### 2.1 Bloco 1: Abertura e Consentimento (~3 minutos)

- **Postura do Moderador:** Calorosa, acolhedora e desarmada. O objetivo é eliminar qualquer ansiedade de avaliação no participante.
- **Fala do Moderador (Guia Textual):**
  > *"Olá, obrigado por disponibilizar seu tempo para nos ajudar hoje. Meu nome é [Nome da Moderadora] e faço parte da equipe do Frila.*  
  > *Antes de começarmos, quero deixar algo bem claro: **estamos testando o aplicativo, e nunca você**. Não existem respostas certas ou erradas. Se você encontrar qualquer dificuldade, dúvida ou travar em alguma tela, isso significa que o aplicativo precisa ser melhorado, e não que você cometeu um erro.*  
  > *Vamos pedir que você use o aplicativo no aparelho que está aqui na mesa. Conforme você for utilizando, pedimos que você **pense em voz alta**: fale o que está procurando, o que chamou sua atenção, o que você espera que aconteça ao tocar em algo e o que te causou estranheza.*  
  > *Eu ficarei aqui principalmente ouvindo e fazendo anotações. Não poderei dar dicas durante as tarefas porque precisamos entender como o aplicativo se comporta quando a pessoa está sozinha.*  
  > *Nossa sessão levará cerca de 20 minutos. Nós não coletaremos seus documentos, nem e-mails pessoais, e todas as anotações são totalmente anônimas. Você concorda em participar?"*
- **Ação:** Coleta do consentimento verbal e assinatura do termo de consentimento (TCLE anônimo).

---

### 2.2 Bloco 2: Contextualização Breve do Participante (~2 minutos)

Perguntas curtas e neutras para contextualizar o perfil, sem coleta de dados pessoais sensíveis (obedecendo à LGPD):
1. *"Qual é a sua função principal no setor de bares, restaurantes ou eventos no DF?"*
2. *"Hoje em dia, quando você precisa pegar um turno extra ou fechar uma escala urgente, como você costuma resolver isso?"*
3. *"Você costuma utilizar muitos aplicativos no seu celular no dia a dia?"*

---

### 2.3 Bloco 3: Execução das Tarefas Centrais (~12 minutos)

O moderador introduz os cenários de forma situacional, **sem utilizar termos da interface** (como "toque na lista", "aperte o botão candidatar" ou "olhe no mural").

#### Regras de Ouro de Neutralidade para a Moderação:
1. **Nunca antecipar a ação:** Use instruções de objetivo (*"Como você faria para..."*), nunca comandos mecânicos (*"Clique aqui"*).
2. **Postura no silêncio:** Quando o participante pausar ou ficar em silêncio por mais de 5 segundos, estimule com perguntas reflexivas:  
   - *"O que você está procurando nessa tela?"*  
   - *"O que você espera encontrar ao tocar aí?"*  
   - *"O que essa tela está te dizendo agora?"*
3. **Escuta neutra sem validação emocional:**  
   - Proibido dizer: *"Muito bem!"*, *"Isso mesmo!"*, *"Perfeito!"*.  
   - Permitido dizer: *"Entendido."*, *"Compreendi."*, *"Estou anotando."*.
4. **Protocolo de Intervenção Mínima:**  
   - O moderador **só intervém** se o participante solicitar socorro explicitamente após tentar, ou permanecer travado sem saber como avançar por mais de **2 minutos contínuos**.  
   - Se o moderador precisar intervir para destravar a sessão, a tarefa deve ser classificada imediatamente na folha como **"Com ajuda"** (falha na meta do RNF09).

#### Execução por Perfil:
- **Para o Profissional:** Execução sequencial das tarefas **P1**, **P2** (candidatura sem ajuda), **P3** (dados de contato) e a pergunta reflexiva **P4** (*"Você chamaria este profissional? O que o 7 de 7 te diz?"*). Se o build interno estiver disponível, prosseguir para **P5**, **P6** e **P7**.
- **Para o Contratante:** Execução sequencial das tarefas **C1**, **C2** (publicação de vaga sem ajuda), **C3** (gestão da vaga) e a pergunta central **C4** (*"Você chamaria este profissional? O que o 7 de 7 te diz?"*). Se o build interno estiver disponível, prosseguir para **C5** e **C6**.

---

### 2.4 Bloco 4: Perguntas Pós-Tarefas e Fechamento (~3 minutos)

Perguntas abertas para extrair percepções consolidadas:
1. *"De tudo o que você viu no aplicativo hoje, o que pareceu mais simples e direto de entender?"*
2. *"Houve algum momento em que você sentiu insegurança ou ficou em dúvida sobre o que aconteceria a seguir?"*
3. *"Em relação ao valor pago pelo turno, ficou claro como funciona o pagamento e que não há descontos sobre esse valor?"* (Validação da RN01 e garantia de remuneração integral sem taxas intermediárias).
4. *"Se você precisasse usar esse aplicativo amanhã na sua rotina real de trabalho, você usaria? Por quê?"*

- **Agradecimento Final:**
  > *"Excelente. Suas observações foram muito valiosas e ajudarão diretamente a equipe a ajustar o aplicativo antes do lançamento oficial. Muito obrigado pela sua contribuição!"*

---

## 3. Folha de Registro por Sessão (Sem Dado Pessoal)

A folha de registro deve ser preenchida individualmente por sessão (5 sessões moderadas no total: 3 profissionais e 2 contratantes externos). Em respeito irrestrito à LGPD, **é proibido registrar nome pessoal, e-mail, telefone, CPF ou identificação nominal do estabelecimento**.

### 3.1 Cabeçalho Padronizado da Sessão

- **Código da Sessão:** SES-MOD-01 *(Numerar de 01 a 05)*
- **Data e Hora:** ____/10/2026 às ____:____
- **Perfil do Participante:** [ ] Profissional de primeira viagem | [ ] Contratante de primeira viagem
- **Aparelho e Sistema:** iPhone _________, iOS ______
- **Build Avaliado:** [ ] TestFlight 0.4 | [ ] Build Interno do iPhone de Teste
- **Moderador:** Júlia | **Relator/Anotador:** Fabrício

---

### 3.2 Tabela de Registro de Tarefas

| ID Tarefa | Tarefa Avaliada | Desfecho (RNF09) | Tempo (mm:ss) | Ponto de Atrito / Onde Travou | Severidade do Defeito | Comportamento / Citação Literal Anônima |
|:---|:---|:---:|:---:|:---|:---:|:---|
| **T1** | Primeiro acesso e cadastro inicial | [ ] Sem ajuda<br>[ ] Com ajuda<br>[ ] Não concluiu | __:__ | *Tela / campo onde houve dúvida:* | [ ] Nenhuma<br>[ ] Leve<br>[ ] Média<br>[ ] Grave<br>[ ] Bloqueante | *"..."* |
| **T2** | **Ação Central RNF09:**<br>Candidatura (Prof.) ou Publicação (Contr.) | [ ] Sem ajuda<br>[ ] Com ajuda<br>[ ] Não concluiu | __:__ | *Tela / botão onde houve hesitação:* | [ ] Nenhuma<br>[ ] Leve<br>[ ] Média<br>[ ] Grave<br>[ ] Bloqueante | *"..."* |
| **T3** | Visualização de Contato (Prof.) ou Conferência da Vaga (Contr.) | [ ] Sem ajuda<br>[ ] Com ajuda<br>[ ] Não concluiu | __:__ | *Dificuldade de navegação ou visualização:* | [ ] Nenhuma<br>[ ] Leve<br>[ ] Média<br>[ ] Grave<br>[ ] Bloqueante | *"..."* |
| **T4** | **Pergunta CSD:**<br>Interpretação de "7 de 7" e comparecimento | [ ] Compreendeu<br>[ ] Confuso<br>[ ] Não entendeu | __:__ | *Dúvida entre estrelas vs binário:* | [ ] Nenhuma<br>[ ] Leve<br>[ ] Média<br>[ ] Grave | *"..."* |
| **T5** | *[Build Interno]* Check-in presencial no local | [ ] Sem ajuda<br>[ ] Com ajuda<br>[ ] Não testado | __:__ | *Permissão GPS ou contingência manual:* | [ ] Nenhuma<br>[ ] Grave<br>[ ] Bloqueante | *"..."* |
| **T6** | *[Build Interno]* Check-out e avaliação mútua | [ ] Sem ajuda<br>[ ] Com ajuda<br>[ ] Não testado | __:__ | *Envio da avaliação:* | [ ] Nenhuma<br>[ ] Leve<br>[ ] Média<br>[ ] Grave | *"..."* |
| **T7** | *[Build Interno]* Fluxo de exclusão de conta (LGPD) | [ ] Sem ajuda<br>[ ] Com ajuda<br>[ ] Não testado | __:__ | *Localização do botão em Perfil:* | [ ] Nenhuma<br>[ ] Leve<br>[ ] Média | *"..."* |

---

### 3.3 Critérios de Classificação de Severidade (Conforme `TriagemUsabilidadeERegressao.md`)

- **Bloqueante (Crítico):** Impede a conclusão do fluxo principal (publicação, candidatura, check-in ou saída); causa crash do app ou prende o usuário em tela sem saída. *Zero tolerados na v1.0.*
- **Grave (Major):** Dificulta severamente a ação ou causa incerteza crítica (ex.: confusão de horários ou valor monetário), mas possui contorno ou afeta caso de borda. *Demanda cartão no Trello até 29/10.*
- **Médio (Minor):** Inconsistência de layout, rótulo confuso ou teclado cobrindo campo secundário, sem impedir a conclusão. *Triado para ajuste ou backlog.*
- **Leve (Cosmético):** Detalhe estético, espaçamento imperfeito ou microinteração ausente sem impacto cognitivo.

---

### 3.4 Consolidação da Sessão

- **Total de tarefas centrais concluídas sem ajuda:** ____ de ____
- **Atingimento do critério RNF09 nesta sessão:** [ ] Sim (100% sem ajuda) | [ ] Parcial | [ ] Não
- **Total de defeitos identificados:** ___ Bloqueantes | ___ Graves | ___ Médios | ___ Leves
- **Síntese qualitativa do relator (máx. 3 linhas):**
  > __________________________________________________________________________________________
  > __________________________________________________________________________________________

---

## 4. Modelo da Síntese do Dia 29/10

Este modelo deve ser preenchido por Fabrício e Júlia no dia **29/10/2026** para apresentação executiva à equipe do Frila. O objetivo é consolidar os resultados das 5 sessões moderadas e dos 10 formulários externos antes da virada para o Sprint 3.

---

### 4.1 Metadados da Rodada de Testes
- **Data da Apresentação:** 29/10/2026
- **Responsáveis:** Júlia (condução) e Fabrício (síntese)
- **Amostra Total:** 
  - **Sessões Moderadas:** 5 participantes (3 profissionais de primeira viagem e 2 contratantes externos)
  - **Testadores Externos (TestFlight 0.4):** 10 retornos estruturados recebidos via formulário
- **Builds Utilizados:** TestFlight 0.4 (externo) e Build Interno da equipe

---

### 4.2 Indicador de Sucesso do RNF09 (Tarefas Centrais sem Ajuda)

| Perfil | Ação Central Avaliada | Meta do RNF09 | Resultado Sessões Moderadas | Resultado Testadores Externos (N=10) | Status RNF09 |
|:---|:---|:---:|:---:|:---:|:---:|
| **Profissional** | Candidatar-se a uma vaga sem ajuda | Conclusão autônoma sem assistência | [ ___ / 3 ] sem ajuda | [ ___ % ] sem ajuda | [ ] Aprovado<br>[ ] Reprovado |
| **Contratante** | Publicar uma vaga para hoje sem ajuda | Conclusão autônoma sem assistência | [ ___ / 2 ] sem ajuda | [ ___ % ] sem ajuda | [ ] Aprovado<br>[ ] Reprovado |

- **Evolução em Relação à Rodada 1 (Protótipo de Alta Fidelidade, 06 a 09/10):**
  - *Profissional:* [Descrever se o atrito diminuiu na tela de candidatura real]
  - *Contratante:* [Descrever se a publicação para hoje no modo urgência ficou compreensível]

---

### 4.3 Investigação CSD: Percepção da Reputação "7 de 7"
- **Pergunta Avaliada:** *"Você chamaria este profissional? O que o 7 de 7 te diz?"*
- **Aderência dos Contratantes (N=2 moderados + contratantes externos):**  
  [ ] Compreensão imediata da reputação binária (chamaria de novo)  
  [ ] Confusão com sistema de notas de 1 a 5 estrelas  
  [ ] Exigência de histórico detalhado de comparecimento
- **Síntese da Percepção de Segurança:**  
  > [Resumo em até 3 linhas sobre como a ausência de notas subjetivas foi recebida pelo público]

---

### 4.4 Inventário de Defeitos e Plano de Redesenho (Sprint 3)

Conforme os critérios de aceite do cartão Q4ZZwnMR, todos os defeitos **Bloqueantes** e **Graves** encontrados devem ter cartões abertos no Trello até 29/10 e solução planejada no cartão de redesenho do Sprint 3.

| ID | Severidade | Tela / Componente | Descrição do Atrito / Causa Raiz | Impacto no Usuário | Cartão Trello Aberto (até 29/10) |
|:---|:---:|:---|:---|:---|:---:|
| **DEF-01** | Bloqueante | `TelaPublicarVaga` | Ex.: Falha no seletor de horário | Impede publicação | Link / ID |
| **DEF-02** | Grave | `TelaMeuTurno` | Ex.: Contato WhatsApp demora a liberar | Insegurança pós-aceite | Link / ID |
| **DEF-03** | Grave | `TelaDetalheVaga` | Ex.: Dúvida se o valor de R$ 140 é bruto ou líquido | Risco de conflito | Link / ID |
| **DEF-04** | Médio | `TelaCadastro` | Ex.: Toque duplo fecha modal inesperadamente | Atrito navegacional | Backlog S3 |
| **DEF-05** | Leve | `CatalogoDesignSystem` | Ex.: Rótulo desalinhado em tela compacta | Cosmético | Backlog v1.0.1 |

---

### 4.5 Funcionalidades Não Testadas nesta Rodada (Registro Formal)

Em conformidade estrita com o escopo aprovado no cartão Q4ZZwnMR:
- [ ] Check-in presencial no local: [Não testado / Testado parcialmente no iPhone de teste]
- [ ] Avaliação mútua de turno: [Não testado / Testado parcialmente no iPhone de teste]
- [ ] Exclusão de conta (LGPD): [Não testado / Testado no build interno]
- **Justificativa Registrada:** As telas não integradas no build estável até 29/10 foram postergadas para a suíte de testes de interface automatizados (`CicloDePontaAPontaUITests.swift`) e validação assistida no Piloto (13/11 a 04/12).

---

## 5. Formulário Curto para os 10 Testadores Externos

Instrumento de coleta assíncrona encaminhado aos 10 testadores externos do TestFlight (Build 0.4). O questionário foi projetado para ser respondido em **menos de 3 minutos**, garantindo alta taxa de retorno sem fadiga.

> **Aviso de Privacidade:** Este formulário não solicita seu nome, endereço de e-mail, telefone ou qualquer dado de identificação pessoal. Os dados serão utilizados exclusivamente para aprimoramento da usabilidade do aplicativo Frila.

---

### Formulário de Retorno — TestFlight Frila (Build 0.4)

#### 1. Qual perfil você utilizou durante o teste?
- [ ] **Profissional** (buscando turnos e vagas em bares/restaurantes)
- [ ] **Contratante** (publicando vagas para cobrir turnos no estabelecimento)

#### 2. Qual modelo de iPhone você utilizou?
- *(Campo aberto curto: ex.: iPhone 12, iPhone 14 Pro, etc.)*

#### 3. Você conseguiu concluir sua tarefa principal sozinho (sem ajuda)?
- [ ] **Sim, do início ao fim sem dificuldades.**
- [ ] **Sim, mas fiquei com dúvida em alguma etapa específica.**
- [ ] **Não consegui concluir a tarefa.**

#### 4. Onde você encontrou maior dificuldade ou lentidão durante o uso?
- [ ] No cadastro inicial ou confirmação de código
- [ ] Ao procurar ou entender os detalhes da vaga (horário, local, valor)
- [ ] Ao enviar a candidatura ou publicar a vaga
- [ ] Ao tentar acessar os dados de contato ou meus turnos
- [ ] Não tive nenhuma dificuldade
- [ ] Outro (especifique): ________________________________________________

#### 5. Clareza dos Valores e Regras do Turno:
*"O valor exibido na vaga ficou claro para você como o valor integral a ser pago pelo turno cumprido, sem descontos ou taxas adicionais?"*
- [ ] **Sim, totalmente claro e direto.**
- [ ] **Não, fiquei em dúvida se haveria algum desconto ou taxa.**
- [ ] Comentário: ________________________________________________________

#### 6. Interpretação da Reputação (Pergunta CSD):
*"Ao visualizar um perfil com a informação '7 de 7 chamariam de novo' (ou '100% de comparecimento'), o que essa informação transmitiu para você?"*
- [ ] Segurança total de que a pessoa é confiável e comparece aos turnos.
- [ ] Fiquei em dúvida e preferiria uma nota de 1 a 5 estrelas.
- [ ] Achei confuso e não entendi o que o número significava.
- [ ] Comentário: ________________________________________________________

#### 7. Estabilidade do Aplicativo:
*"Durante o seu teste, o aplicativo fechou sozinho (crash) ou travou em alguma tela?"*
- [ ] **Não, funcionou perfeitamente sem travar.**
- [ ] **Sim, fechou sozinho.** (Em qual momento/tela? _______________________)
- [ ] **Sim, a tela travou e não respondeu.** (Em qual tela? _______________)

#### 8. Comentário Aberto:
*"O que mais chamou sua atenção ou o que você mudaria para tornar o Frila mais fácil de usar no dia a dia?"*
- *(Campo de texto livre)*

---

## 6. Pendências e Responsabilidades (Em Aberto)

Em cumprimento às regras operacionais do Frila e alinhamento do cartão Q4ZZwnMR, as ações abaixo são de atribuição exclusiva de **Júlia** e **Fabrício**:

| Responsável | Atribuição Pendente | Prazo Limite |
|:---|:---|:---:|
| **Júlia** | Recrutamento e agendamento dos 5 participantes moderados (3 profissionais e 2 contratantes no DF) com coleta de TCLE assinado. | 23/10/2026 |
| **Júlia** | Condução das 5 sessões moderadas de 20 minutos utilizando o roteiro deste documento. | 28/10/2026 |
| **Fabrício** | Envio do link do formulário anônimo aos 10 testadores externos do TestFlight 0.4 e acompanhamento das respostas. | 27/10/2026 |
| **Fabrício & Júlia** | Consolidação dos dados na Folha de Síntese (Seção 4), abertura dos cartões de Bloqueantes/Graves no Trello e apresentação executiva ao time Frila. | 29/10/2026 |
