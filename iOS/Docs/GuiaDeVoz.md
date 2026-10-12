# Guia de Voz, Glossário, Formatos e Mensagens de Erro

Documento oficial de referência para redação de interface (UX Writing), glossário de termos, padronização de formatos e catálogo de mensagens de erro do Frila no aplicativo iOS e demais canais do produto.

- **Sprint:** S0 · Fundação
- **Cartão Trello:** [gNlXnAYP](https://trello.com/c/gNlXnAYP)
- **Histórias e Requisitos:** RNF09 (Usabilidade para público não habituado a apps profissionais), RNF15 (Localização pt-BR, moeda em reais, fuso America/Sao_Paulo), RN01 (Valor integral sem descontos), RN10 (Liberação de contato pós-confirmação), RN13 (Suspensão e reputação), RN20 (Maioridade 18 anos), RN24 (Modo seleção e antecedência), RN25 (Perfis fixos), RF27 / C05 ("Por que recebo vagas"), US13 (Mensagem pronta de WhatsApp).
- **Referência do Contrato:** `Frila API 0.2.41` (`iOS/Contrato/openapi.yaml`).
- **Repositório:** `frila-frontend` (`iOS/Docs/GuiaDeVoz.md`).

---

## 1. Voz e Tom

A comunicação do Frila existe para dar clareza imediata e segurança prática a pessoas que dependem de trabalho pontual ou precisam cobrir turnos de operação. O tom não é burocrático, não é festivo e não trata o trabalho como jogo.

### 1.1 Três Princípios Fundamentais

1. **Direto:** Frases curtas na ordem direta (sujeito + verbo + complemento). Cada tela, aviso ou botão comunica apenas o que a pessoa precisa saber para tomar a decisão naquele instante. Sem introduções longas, rodeios ou explicações teóricas.
2. **Sem culpa:** Quando uma ação é recusada, uma vaga acaba ou um imprevisto ocorre, a interface descreve o fato operacional de forma neutra e orienta o próximo passo viável. Nunca culpar a pessoa usuária, nunca usar exclamações acusatórias e nunca tratar regras de negócio como falhas morais.
3. **Sem promessa:** O aplicativo nunca promete o que foge do controle do sistema. Não há promessas sobre tempo de resposta de outras pessoas, velocidade de contratação ou ganhos futuros. Os prazos regulamentares exibidos são apenas os compromissos institucionais da Equipe Frila (como os 5 dias úteis de resposta a suporte ou contestação previstos na legislação e nos termos).

### 1.2 O que NUNCA aparece na interface

- **Metas de tempo subjetivas:** Proibido usar termos como "em poucos minutos", "rápido", "a qualquer momento", "em instantes você resolve", "logo logo" ou "já já".
- **Número de toques:** Proibido usar expressões de facilidade superficial como "com apenas 2 toques", "a um clique de distância" ou "em poucos passos".
- **Comissão:** A palavra "comissão" é terminantemente proibida na interface do Frila. O Frila não cobra comissão sobre turnos e não atua como intermediador financeiro de trabalho avulso (RN01). O valor exibido na vaga é o valor integral que o profissional recebe da casa.
- **"Custo zero", "grátis" ou "100% gratuito":** Evitar jargão de marketing promocional. Onde for necessário reforçar a ausência de cobrança, usa-se a expressão aprovada: "O Frila não desconta do valor do turno" ou "sem cobrança para receber vagas".
- **Estrangeirismos desnecessários:** Proibido substituir termos consolidados por equivalentes em inglês (não usar *gig*, *shift*, *match*, *onboarding*, *no-show*, *dashboard*, *job* ou *feed*).

### 1.3 Adequação ao Público (RNF09)

O produto é projetado para ser imediatamente compreendido por pessoas sem familiaridade com aplicativos corporativos complexos:
- Vocabulário simples e comum do dia a dia de bares, restaurantes e eventos do Distrito Federal.
- Instruções autoexplicativas nos campos de formulário, com exemplos concretos de preenchimento.
- Rótulos de botões que indicam verbos de ação explícitos (ex.: "Salvar e começar", "Candidatar-me", "Confirmar código", "Fazer check-in").

---

## 2. Glossário da Interface

A interface adota a regra estrita de **um único termo oficial por conceito**, eliminando sinônimos concorrentes para garantir consistência e acessibilidade cognitiva.

### 2.1 Termos Oficiais

| Termo Oficial | O que significa | O que NÃO usar | Contexto de uso na tela |
|---|---|---|---|
| **Vaga** | Registro publicado por um estabelecimento contendo data, horário, função, valor, endereço e posições abertas para um turno. | Oportunidade, anúncio, oferta, trampo, bico, job | Lista principal do profissional, detalhe da vaga, tela de publicação da casa. |
| **Turno** (ou **Turno avulso**) | Uma jornada pontual de trabalho contratada para uma data e período específicos, sem vínculo continuado. É a unidade de execução do Frila. | Diária, escala, plantão, jornada, serviço, expediente | Detalhe do turno, Meus turnos, tela de presença e check-in. |
| **Posição** | Cada unidade individual preenchível dentro de uma vaga. Uma vaga para 4 garçons possui 4 posições. | Vaga (quando referente à unidade da vaga), cota, vaga individual | Publicação da vaga, seleção de candidatos, gestão de presença. |
| **Estabelecimento** | O negócio (bar, restaurante, buffet, produtora, casa de eventos) que publica vagas e contrata profissionais. | Empresa, contratante (quando referente ao local), cliente, comércio | Identificação do contratante, cabeçalho da vaga, tela de detalhes do turno. |
| **Contratante** | O perfil ou papel da pessoa que publica vagas e administra turnos em nome de um estabelecimento. | Empregador, patrão, recrutador, gestor | Seleção de perfil no cadastro, permissões de acesso, suporte. |
| **Profissional** | A pessoa cadastrada que visualiza vagas, candidata-se e cumpre turnos avulsos. | Freelancer, freela, colaborador, funcionário, candidato (após aceite) | Seleção de perfil no cadastro, lista de candidatos, meu perfil. |
| **Candidatar-se** / **Candidatura** | Ação do profissional de demonstrar interesse em uma posição aberta. No modo urgência resulta em confirmação direta; no modo seleção aguarda escolha. | Aceitar (no modo seleção), aplicar, concorrer, inscrever-se | Botão principal da vaga, aba Candidaturas. |
| **Confirmado** / **Confirmação** | Estado em que uma posição do turno foi atribuída formalmente a um profissional específico. | Fechado, contratado, aprovado, agendado | Cartão de turno confirmado, tela de presença, aviso de confirmação. |
| **Check-in** | Registro eletrônico de chegada e início do trabalho no turno. Pode ser geolocalizado (automático pelo GPS) ou manual. | Ponto, entrada, bater ponto, registro de entrada | Botão de presença na tela Meu turno. |
| **Check-out** | Registro eletrônico de término do trabalho no turno. | Saída, término, ponto de saída, bater saída | Botão de finalização do turno na tela de presença. |
| **Taxa de comparecimento** | Indicador percentual que divide os turnos cumpridos com presença pelos turnos confirmados do profissional. | Assiduidade, pontualidade, nota de presença, score | Perfil do profissional, visualização de candidatos pelo estabelecimento. |
| **Reputação binária** | Avaliação simples de resposta única ("Chamaria de novo?" ou "Trabalharia lá de novo?"), exibida como contagem sobre o total (ex.: "12 de 14"), sem média de 1 a 5. | Avaliação por estrelas, nota, pontuação, score | Perfil do profissional, perfil do estabelecimento, tela de avaliação. |
| **Equipe de confiança** | Lista de profissionais selecionados pelo estabelecimento que já cumpriram turnos no local e recebem notificações de novas vagas mesmo além de 15 km. | Favoritos, equipe VIP, lista preferencial, fixos | Aba Equipe no contratante, tela Por que recebo vagas no profissional. |
| **Despacho ativo** | Envio simultâneo de notificações de uma vaga aberta a todos os profissionais elegíveis (função compatível, horário disponível e até 15 km, mais equipe de confiança). | Disparo, levas de envio, fila de distribuição | Documentação, suporte e tela "Por que recebo vagas". |
| **Modo urgência** | Comportamento de preenchimento imediato: o primeiro profissional elegível que aceitar fica com a posição. | Primeiro que chegar, aceite direto, modo rápido | Detalhe da vaga ("Urgência: quem aceitar primeiro fica com a vaga"). |
| **Modo seleção** | Comportamento de preenchimento em que o estabelecimento escolhe entre os candidatos. Válido apenas para vagas criadas com mais de 24 horas de antecedência. | Processo seletivo, triagem, escolha manual | Detalhe da vaga ("Seleção: o estabelecimento escolhe entre os candidatos"). |
| **Janela crítica** | Período de antecedência (padrão de 3 horas antes do início) em que o estabelecimento recebe alertas caso ainda haja posições não preenchidas. | Alerta de desfalque, prazo limite de vaga | Configuração de publicação de vaga. |
| **Ponto base** | Endereço ou bairro de referência salvo pelo profissional no perfil para cálculo da distância máxima até as vagas (até 15 km). Não é rastreamento em tempo real. | Minha localização, GPS, endereço residencial | Tela Funções e horários, tela Por que recebo vagas. |
| **Protocolo** | Código alfanumérico gerado pelo sistema para acompanhamento de denúncias, chamados de suporte e contestações (formato curto de 8 caracteres). | Número do ticket, ID do chamado, comprovante | Telas de confirmação de suporte, denúncia e contestação. |
| **Falta** | Não comparecimento ao turno confirmado ou cancelamento realizado com menos de 24 horas de antecedência. | No-show, abandono, bolo | Histórico de turnos, taxa de comparecimento, cancelamento. |
| **Turno não verificado** | Turno cumprido com check-in manual que não foi confirmado pelo estabelecimento. Não pontua a favor nem contra na taxa de comparecimento. | Turno pendente, turno em aberto, turno contestado | Histórico de turnos do profissional. |
| **Contestação** | Pedido formal enviado pelo profissional ou estabelecimento à Equipe Frila para revisão de suspensão de conta ou critérios de despacho de vagas. | Recurso, apelação, reclamação, disputa | Telas Conta suspensa e Por que recebo vagas. |
| **Painel** | Painel de controle na versão web do Frila para uso exclusivo do perfil contratante/gestor. Não é ferramenta interna da equipe Frila. | Dashboard, sistema web, portal | Comunicação com estabelecimentos e documentação. |
| **Equipe Frila** | Equipe humana de atendimento, moderação e conformidade que analisa contestações, suporte e denúncias por e-mail. | Suporte técnico, moderação, administração | Mensagens de contestação, e-mails de protocolo e termos. |

### 2.2 Nomes Oficiais das Abas do Aplicativo

A navegação inferior organiza as telas do aplicativo com nomes curtos e padronizados:

- **Perfil do Profissional:**
  1. `Vagas` (lista e busca de vagas abertas no DF)
  2. `Meus turnos` (turnos confirmados, histórico e presença)
  3. `Candidaturas` (vagas em modo seleção em que o profissional aguarda resposta)
  4. `Perfil` (dados pessoais, funções, horários, ponto base e configurações)

- **Perfil do Contratante:**
  1. `Minhas vagas` (vagas publicadas pelo estabelecimento, abertas e encerradas)
  2. `Meus turnos` (turnos em andamento, presença e histórico de turnos da casa)
  3. `Equipe` (profissionais adicionados à equipe de confiança do estabelecimento)
  4. `Perfil` (dados do estabelecimento, membros de acesso e configurações)

### 2.3 Resolução da Divergência: "Vagas" × "Oportunidades"

Durante o desenvolvimento inicial e no protótipo de baixa fidelidade, surgiu uma divergência textual entre o termo "Vagas" e o termo "Oportunidades":

- **Onde o app utiliza "Vagas":**
  - No fluxo principal e na navegação do profissional: `FluxoDoProfissional.swift:219` (`AbaDoProfissional.vagas`).
  - No título da tela de listagem: `TextosDoProfissional.Lista.titulo` ("Vagas no DF").
  - No detalhe do anúncio: `TextosDoProfissional.Detalhe.titulo` ("Vaga").
  - Nos fluxos de publicação do contratante: `PublicarVaga.swift:22`.
  - No Documento de Requisitos (Seções 2, 3 e 6): o termo normativo é estritamente "Vaga".
- **Onde o app utiliza "Oportunidades":**
  - No protótipo inicial da história de usuário US08 ("aba Oportunidades").
  - No estado vazio de catálogo do design system (`CatalogoDesignSystem.swift:34`): `"Novas oportunidades aparecerão aqui."`
  - Na mensagem de recusa por conflito (`ValidacaoClienteAPI.swift:10` e `Localizable.xcstrings:1866`): `"Esta vaga acabou de ser preenchida. Escolha outra oportunidade."`

#### Recomendação Técnica do Time
Padronizar 100% da interface no termo **"Vaga"** / **"Vagas"**, eliminando o termo "Oportunidade". O público do setor operacional de food service e eventos compreende "vaga" com clareza imediata, enquanto "oportunidade" soa vago ou corporativo.

A mensagem de recusa em `ValidacaoClienteAPI.swift` deve ser ajustada para:  
`"Esta vaga acabou de ser preenchida. Volte para a lista e escolha outra vaga."`

> [!IMPORTANT]
> **Ponto para decisão e aprovação da Júlia:**  
> Homologar formalmente o descarte definitivo do termo "Oportunidade" em favor de "Vaga" em todo o aplicativo, autorizando a atualização textual em `ValidacaoClienteAPI.swift` e nos estados vazios do catálogo de design system.

---

## 3. Formatos Padronizados

Para cumprir o RNF15 e eliminar ambiguidades visuais entre telas e notificações, todos os dados numéricos, temporais e monetários seguem um formato único.

### 3.1 Valores Monetários (Moeda)

- **Regra:** Símbolo `R$` seguido de espaço não separável e valor com separador de milhar `.` e decimais `,`. Centavos são sempre explícitos (duas casas decimais).
- **Formato correto:** `R$ 1.250,00` e `R$ 140,00`.
- **Proibido:** `R$ 140` (sem centavos), `R$140` (sem espaço), `140 reais` ou centavos brutos (`14000`).

### 3.2 Horários

- **Regra:** Formato de 24 horas com dois dígitos para hora e minuto (`HH:mm`), sempre no fuso horário oficial de Brasília (`America/Sao_Paulo`).
- **Formato correto:** `18:00`, `02:00`, `08:30`, `23:00`.
- **Proibido:** `18h`, `2h`, `18h00`, `6 pm`, `02h`.

### 3.3 Intervalos de Horário no Mesmo Dia

- **Regra:** Hora inicial seguida de `" às "` e hora final. Em cartões compactos de lista, utiliza-se travessão `" – "`.
- **Formato correto:** `08:00 às 17:00` ou `08:00 – 17:00`.

### 3.4 Turnos que Cruzam a Meia-Noite (Noturnos)

- **Regra:** Quando o turno termina no dia civil seguinte ao de início, o horário de término é explicitamente acompanhado da indicação do dia seguinte ou dos dois dias da semana abreviados.
- **Exemplo obrigatório:** Turno com início às 18:00 e término às 02:00.
- **Formato em texto corrido / detalhe da vaga:**  
  `sex, 25/09, das 18:00 às 02:00 (dia seguinte)`
- **Formato em cartão de lista / intervalo compacto:**  
  `sex 18:00 – sáb 02:00`

### 3.5 Datas e Datas Relativas

- **Datas relativas:** Utilizadas para os dias mais próximos:
  - `Hoje`
  - `Amanhã`
- **Data curta com dia da semana:** Utilizada em listagens e resumos:
  - `sáb, 27/09`
  - `dom, 28/09`
- **Data completa:** Utilizada em comprovantes, relatórios e históricos:
  - `27/09/2026`
- **Data com horário:**  
  - `27/09/2026 às 18:00`

### 3.6 Distâncias

- **Regra:** Quilômetros com separador decimal `,` e sufixo `" km"`. Quando inteiro exato, exibe-se sem casa decimal; quando fracionário, exibe-se com uma casa decimal.
- **Exemplos corretos:** `0 km`, `2,5 km`, `10 km`, `12,3 km`, `até 15 km`.

### 3.7 Reputação Binária e Taxa de Comparecimento

- **Reputação do estabelecimento (vista pelo profissional):**
  - Com avaliações: `Trabalhariam lá de novo: 12 de 14`
  - Sem histórico: `Sem histórico`
- **Reputação do profissional (vista pelo estabelecimento):**
  - Com avaliações: `Chamariam de novo: 8 de 9`
  - Sem histórico: `Sem histórico`
- **Taxa de comparecimento (somente do profissional):**
  - `Comparecimento: 100%` (ou `Taxa de comparecimento: 90%`)
  - A taxa divide turnos com presença confirmada por turnos confirmados.

---

## 4. Tabela de Mensagens de Erro do Contrato

O contrato da API (`openapi.yaml`) define que o campo `message` é texto técnico para log e **nunca deve ser exibido diretamente na tela**. Cada código estável de erro (`code`) possui título, mensagem orientadora e ação sugerida para a pessoa usuária.

### 4.1 Regras de Conformidade da Tabela
- **Contagem exata:** A tabela contém **33 códigos de erro do contrato**, correspondendo linha por linha aos **33 códigos estáveis** declarados na tabela de erros de `Contrato/openapi.yaml` (linhas da tabela = 33, códigos do contrato = 33).
- **Termos do glossário:** Cada frase utiliza exclusivamente termos normatizados na Seção 2 deste guia.
- **Sem promessa de tempo:** Nenhuma mensagem inclui prazos de resolução ou suposições de rapidez.
- **Sem palavra "comissão":** Proibição total do termo.

### 4.2 Tabela Oficial dos Códigos de Erro da API

| HTTP | Código (`code`) | Título na tela | Texto na tela | Ação sugerida |
|:---:|---|---|---|---|
| 401 | `nao_autenticado` | Sessão expirada | Sua sessão expirou. Entre novamente para continuar. | Toque em Entrar e solicite um novo código por e-mail. |
| 403 | `sem_permissao` | Ação não permitida | Sua conta não tem permissão para realizar esta ação. | Verifique o perfil da sua conta ou procure o suporte. |
| 403 | `contato_expirado` | Contato encerrado | O contato direto deste turno expirou. As informações ficam disponíveis por até 7 dias após o término do turno. | Se precisar falar sobre este turno, procure a Equipe Frila pelo suporte. |
| 404 | `nao_encontrado` | Item não encontrado | Este conteúdo não foi encontrado ou não está mais visível para a sua conta. | Volte para a tela anterior e atualize a lista. |
| 409 | `posicao_ja_preenchida` | Vaga preenchida | Esta posição acabou de ser preenchida por outro profissional. No modo urgência, quem confirma primeiro fica com a vaga. | Volte para a lista de vagas e escolha outra vaga disponível. |
| 409 | `vaga_encerrada` | Vaga encerrada | Esta vaga foi encerrada, cancelada ou o horário de início já passou. | Volte para a lista de vagas e veja outras vagas abertas. |
| 409 | `checkin_pendente` | Check-in pendente | Você precisa registrar o check-in antes de realizar esta ação. | Faça o check-in na chegada ao estabelecimento para continuar. |
| 409 | `checkin_ja_confirmado` | Check-in já confirmado | O check-in deste turno já foi confirmado e verificado. | Nenhuma ação adicional é necessária. Siga com o turno. |
| 409 | `posicao_nao_cancelavel` | Cancelamento indisponível | Esta posição não pode ser cancelada, pois o turno já está em andamento, foi concluído ou não está confirmado. | Verifique o estado do turno em Meus turnos. Em caso de imprevisto, avise a outra parte. |
| 409 | `candidatura_indisponivel` | Candidatura indisponível | Esta candidatura não está mais disponível porque já foi respondida, retirada ou expirou. | Consulte suas candidaturas na aba Candidaturas ou busque outras vagas. |
| 409 | `avaliacao_ja_registrada` | Avaliação já enviada | A avaliação deste turno já foi registrada pelo seu lado. Cada lado registra uma única resposta. | Nenhuma ação adicional é necessária. O turno já está avaliado. |
| 409 | `conta_existente` | Conta já cadastrada | Já existe uma conta cadastrada com este e-mail. | Entre diretamente usando o código enviado para o seu e-mail. |
| 409 | `documento_ja_cadastrado` | Documento já cadastrado | O documento informado já está vinculado a outra conta no Frila. | Confira os dados informados ou procure a Equipe Frila. |
| 409 | `administrador_unico` | Administrador único | Você é o único administrador deste estabelecimento. Adicione outro administrador antes de excluir sua conta. | Acesse o perfil do estabelecimento e adicione outro administrador para poder prosseguir. |
| 409 | `perfil_ja_existe` | Perfil já existente | Sua conta já possui um perfil profissional ativo cadastrado. | Acesse seu perfil para visualizar ou editar suas funções e horários. |
| 409 | `contestacao_ja_aberta` | Contestação em andamento | Já existe uma contestação registrada para este caso. A resposta será enviada por e-mail pela Equipe Frila. | Aguarde a análise da Equipe Frila por e-mail antes de enviar novos pedidos. |
| 422 | `campo_obrigatorio` | Preencha os campos obrigatórios | Um ou mais campos obrigatórios não foram informados. | Preencha os campos destacados para continuar. |
| 422 | `campo_invalido` | Informação inválida | Uma das informações preenchidas não foi aceita pela regra do sistema. | Corrija o campo destacado conforme as orientações da tela. |
| 422 | `intervalo_maximo_excedido` | Período muito longo | O intervalo de datas selecionado ultrapassa o limite máximo permitido de 30 dias para exportação. | Selecione um período de até 30 dias e tente novamente. |
| 422 | `menor_de_idade` | Cadastro não permitido | O Frila é exclusivo para pessoas com 18 anos ou mais. | O cadastro não pode ser concluído para menores de 18 anos. |
| 422 | `perfil_incompativel` | Perfil incompatível | Esta ação não pode ser realizada com o perfil atual da sua conta. | Acesse a funcionalidade correspondente ao perfil da sua conta (profissional ou contratante). |
| 422 | `selecao_sem_antecedencia` | Antecedência insuficiente para seleção | O modo seleção só pode ser utilizado em vagas que começam com mais de 24 horas de antecedência. | Publique a vaga no modo urgência ou ajuste o horário de início do turno. |
| 422 | `republicacao_indisponivel` | Republicação indisponível | Não é possível republicar posições para esta vaga no momento. | Confira os detalhes da vaga ou publique uma nova vaga com as posições necessárias. |
| 422 | `vaga_oculta` | Vaga em revisão | Esta vaga está temporariamente oculta para revisão pela Equipe Frila e não aceita ações. | Aguarde a conclusão da revisão da vaga pela Equipe Frila ou veja outras vagas abertas. |
| 422 | `horario_invalido` | Horário inválido | O horário de término deve ser posterior ao horário de início e o turno não pode estar no passado. | Ajuste os horários de início e término do turno. |
| 422 | `inelegivel` | Candidatura não permitida | Você não cumpre todos os critérios necessários para se candidatar a esta vaga. | Verifique se a função bate com seu perfil, se não há choque de horários e se sua conta está ativa. |
| 422 | `avaliacao_indisponivel` | Avaliação indisponível | A avaliação só fica disponível após o término do turno e com presença confirmada. | Aguarde o término do horário do turno e a confirmação de presença para avaliar. |
| 422 | `fora_da_janela` | Fora do horário permitido | O registro só pode ser realizado durante a janela de horário autorizada para este turno. | Tente registrar novamente dentro do horário previsto para o check-in ou check-out. |
| 422 | `a_caminho_fora_da_janela` | Aviso fora do horário | O aviso a caminho só pode ser enviado de 3 horas antes até 15 minutos após o início do turno. | Envie o aviso quando estiver dentro da janela de horário permitida. |
| 422 | `registro_no_futuro` | Horário divergente | O horário informado está à frente do horário oficial do servidor. | Verifique se o relógio do seu aparelho está correto no horário de Brasília e tente novamente. |
| 422 | `reabertura_antes_da_tolerancia` | Aguarde a tolerância de atraso | A reabertura de posição por atraso só é permitida após 15 minutos do horário de início do turno. | Aguarde o término dos 15 minutos de tolerância antes de reabrir a vaga. |
| 422 | `sem_suspensao_ativa` | Conta sem suspensão | Não há suspensão ativa nesta conta para justificar uma contestação. | Sua conta está com acesso normal. Nenhuma contestação é necessária. |
| 429 | `limite_excedido` | Muitas tentativas | Você realizou muitas tentativas seguidas em um intervalo curto. | Aguarde antes de tentar novamente. |

*Nota de auditoria de contagem:*  
- Códigos estáveis catalogados na tabela de erros do contrato `Contrato/openapi.yaml`: **33 códigos**.  
- Linhas de dados na tabela de erros de interface: **33 linhas**.  
- Relação: **33 = 33 (100% de paridade)**.

---

### 4.3 Mensagens Derivadas de Motivos Específicos (`details`)

Quando a API devolve um código geral com a chave `details`, a interface exibe a mensagem específica do motivo:

#### 1. Desdobramentos de `403 sem_permissao`
- `details: conta_suspensa`:
  - **Título:** Conta suspensa
  - **Texto:** Sua conta está temporariamente suspensa e não pode realizar esta ação no momento.
  - **Ação:** Acesse a área da sua conta para ver o motivo e, se desejar, enviar uma contestação à Equipe Frila.
- `details: sem_turno_cumprido`:
  - **Título:** Turno prévio necessário
  - **Texto:** O profissional só pode ser incluído na equipe de confiança após cumprir e ter confirmado pelo menos um turno neste estabelecimento.
  - **Ação:** Confirme a realização de um turno com este profissional antes de adicioná-lo à sua equipe de confiança.

#### 2. Desdobramentos de `422 inelegivel`
- `details: turno_sobreposto`:
  - **Título:** Horário coincidente
  - **Texto:** Você já tem um turno confirmado que coincide com o horário desta vaga. Não é possível assumir dois turnos ao mesmo tempo.
  - **Ação:** Consulte seus horários em Meus turnos e escolha uma vaga em outro horário.
- `details: funcao_incompativel`:
  - **Título:** Função diferente
  - **Texto:** Esta vaga exige uma função que não está cadastrada no seu perfil profissional.
  - **Ação:** Acesse seu perfil para atualizar as funções em que você atua, se for o caso.
- `details: perfil_suspenso`:
  - **Título:** Conta suspensa
  - **Texto:** Sua conta está suspensa. Enquanto a suspensão durar, você não pode se candidatar a vagas.
  - **Ação:** Consulte a área da sua conta para enviar uma contestação à Equipe Frila.

#### 3. Desdobramentos de `422 avaliacao_indisponivel`
- `details: antes_do_fim`:
  - **Título:** Turno em andamento
  - **Texto:** A avaliação só fica disponível após o horário de término do turno.
  - **Ação:** Aguarde o encerramento do turno para registrar sua avaliação.
- `details: sem_presenca_verificada`:
  - **Título:** Presença não confirmada
  - **Texto:** A avaliação só pode ser realizada para turnos que tiveram presença confirmada por check-in.
  - **Ação:** Verifique o status de presença do turno antes de avaliar.

#### 4. Desdobramentos de `422 republicacao_indisponivel`
- `details: nao_e_selecao`: "Apenas vagas criadas no modo seleção podem ter posições republicadas em urgência."
- `details: selecao_em_curso`: "A seleção de candidatos para esta vaga ainda está em andamento."
- `details: vaga_cancelada`: "Esta vaga foi cancelada e não permite republicação de posições."
- `details: ja_comecou`: "O turno desta vaga já teve início, não sendo mais possível republicar posições."
- `details: sem_posicoes_restantes`: "Todas as posições desta vaga já foram preenchidas ou não há vagas remanescentes."
- `details: ja_republicada`: "As posições restantes desta vaga já foram republicadas anteriormente."

---

### 4.4 Estados de Conexão e Sessão no Cliente iOS

Três estados de erro ocorrem no nível de transporte do dispositivo e são apresentados com textos fixos:

| Estado do cliente | Título na tela | Texto na tela | Ação sugerida |
|---|---|---|---|
| **Sem conexão** (`sem_rede`) | Sem conexão | Sem conexão com a internet. Verifique sua rede para continuar. | Verifique se o Wi-Fi ou os dados móveis estão ativos e tente novamente. |
| **Sessão expirada** (`resposta_invalida` / `PGRST301`) | Sessão expirada | Sua sessão não pôde ser validada ou expirou. | Entre novamente com seu e-mail para receber um novo código de acesso. |
| **Erro inesperado** (`desconhecido`) | Algo deu errado | Não foi possível concluir esta ação no momento. | Tente novamente mais tarde. Se persistir, procure a Equipe Frila pelo suporte. |

---

## 5. Textos Fixos Já Decididos

Trechos de texto com redação normativa aprovada por requisitos e decisões de produto:

### 5.1 Aviso de Compartilhamento de Contato (RN10)

- **Na confirmação direta (Modo Urgência):**  
  `"Ao confirmar, seu telefone e WhatsApp serão mostrados ao [Nome do Estabelecimento] para combinar o turno."`
- **Na candidatura aguardando seleção (Modo Seleção):**  
  `"Se a sua candidatura for escolhida, seu telefone e WhatsApp serão mostrados ao [Nome do Estabelecimento] para combinar o turno."`
- **Na tela do turno confirmado (Meu Turno):**  
  `"Liberado com a confirmação. Fica visível até 7 dias depois do término do turno."`

### 5.2 Valor Integral sem Descontos (RN01)

- **No detalhe da vaga e no cartão informativo:**  
  `"O valor é integral: o Frila não desconta do valor pago pelo turno."`

### 5.3 Explicação e Revisão de Elegibilidade ("Por que recebo vagas" - C05 / RF27)

- **Texto explicativo principal:**  
  `"Você recebe notificações de vagas da sua função, a até 15 km do seu ponto base, quando o turno inteiro cabe nos horários em que você marcou disponibilidade. Todas as vagas do DF aparecem na lista."`
- **Texto de contestação / solicitação de revisão:**  
  `"Se você acha que deveria ter recebido uma vaga, peça a revisão. A Equipe Frila responde por e-mail em até 5 dias úteis."`
- **Confirmação de envio do pedido:**  
  `"Pedido de revisão enviado. A Equipe Frila vai responder por e-mail dentro do prazo informado."`

### 5.4 Mensagem Pronta de WhatsApp (US13)

- **Texto gerado no link de abertura do WhatsApp do contato do turno:**  
  `"Olá! Sou o profissional do turno de [Função] em [Data/Horário] no [Nome do Estabelecimento]."`
- **Rótulo e acessibilidade do botão:**  
  - Rótulo: `"Abrir no WhatsApp"`
  - Dica de acessibilidade: `"Abre a conversa no WhatsApp com mensagem pré-formatada"`

### 5.5 Entrada por Código e Cadastro (RN25 / RF01)

- **Tela de entrada (E-mail):**  
  - Título: `"Entrar no Frila"`
  - Orientação: `"Digite seu e-mail para receber um código de acesso de 6 dígitos."`
  - Botão: `"Enviar código"`
- **Tela de confirmação do código:**  
  - Orientação: `"Digite o código de 6 dígitos enviado para o seu e-mail."`
  - Botão primário: `"Confirmar código"`
  - Botão secundário: `"Reenviar código"`
- **Escolha de perfil (RN25):**  
  - Título: `"Como você quer usar o Frila?"`
  - Subtítulo: `"O perfil é escolhido uma vez no cadastro e não pode ser alterado depois."`
  - Opção 1: `"Quero trabalhar em turnos"` (Perfil Profissional)
  - Opção 2: `"Quero publicar vagas"` (Perfil Contratante / Estabelecimento)
- **Aviso de maioridade no cadastro do profissional (RN20):**  
  - `"O Frila é exclusivo para maiores de 18 anos."`
- **Dica do ponto base (Profissional):**  
  - `"Serve para calcular a distância até as vagas. Não é a sua localização em tempo real."`

---

## 6. Matriz de Rastreabilidade e Critérios de Aceite

| Critério de Aceite da Missão | Situação | Evidência no Documento |
|---|:---:|---|
| **Cinco partes do cartão contempladas** | Concluído | Seções 1 (Voz e tom), 2 (Glossário), 3 (Formatos), 4 (Erros) e 5 (Textos fixos). |
| **Contagem de códigos do contrato = Linhas da tabela** | Concluído | **33 códigos do contrato = 33 linhas na tabela de erros** (Seção 4.2). |
| **Exemplo de cada formato com turno 18:00 às 02:00 e valor R$ 1.250,00** | Concluído | Seção 3.1 (`R$ 1.250,00`) e Seção 3.4 (`18:00 às 02:00 (dia seguinte)`). |
| **Divergência "Vagas × Oportunidades" mapeada com recomendação e ponto para Júlia** | Concluído | Seção 2.3 com arquivos citados (`ValidacaoClienteAPI.swift`, `CatalogoDesignSystem.swift`), recomendação de padronização em "Vaga" e ponto de decisão para a Júlia. |
| **Cada texto usa só termos do glossário** | Concluído | Vocabulário auditado em todas as tabelas e exemplos. |
| **Nenhuma promessa de tempo** | Concluído | Eliminados termos como "em instantes", "rápido" ou "em poucos minutos". |
| **Nada de "comissão"** | Concluído | Termo estritamente proibido; uso de "valor integral sem desconto". |
| **Aprovação da Júlia e do Fabrício no cartão** | Pendente de pessoa | Depende da aprovação da Júlia (glossário/mensagens) e do Fabrício (voz/formatos). Listado no relatório de entrega. |
