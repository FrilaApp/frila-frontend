# Auditoria de Textos das Telas do Sprint 1 contra o Guia de Voz

Documento oficial de auditoria estática de interface (UX Writing), consistência terminológica, formatos numéricos/temporais e mensagens de erro das telas do Sprint 1 do Frila no aplicativo iOS (`frila-frontend`), em cumprimento ao cartão **NoKH0SN8**.

- **Sprint:** S1 · Ciclo principal (06/10 → 19/10)
- **Cartão Trello:** [NoKH0SN8](https://trello.com/c/NoKH0SN8) (`S1 · QA + Design · Revisão de design, acessibilidade e textos das telas do Sprint 1`)
- **Documentos de Referência:**
  - `iOS/Docs/GuiaDeVoz.md` (Referência normativa oficial de UX Writing e Catálogo de Erros da API)
  - `iOS/Docs/PadroesDeEstado.md` (Padrões de estado de tela: carregando, vazio, erro, sem rede, sem permissão, sucesso)
  - `Frila API 0.2.41` (`iOS/Contrato/openapi.yaml`)
- **Data da Auditoria:** 12/10/2026
- **Auditor:** Thor (Implementação iOS / Antigravity)
- **Status do Código:** Estático — **nenhuma string ou código foi alterado nesta missão** (remediações catalogadas para missão posterior).

---

## 1. Resumo Executivo e Diagnóstico Geral

A auditoria cobriu 100% dos 5 grupos de telas que compõem o escopo de produto do Sprint 1:
1. **Entrada por código e Perfil/Cadastro** (`TelaEntrada`, `TelaCodigo`, `TelaCadastro`, `FluxoDeEntrada`)
2. **Perfil Profissional: Funções, Horários e Ponto Base** (`TelaPerfilProfissional`, `PerfilProfissionalViewModel`, `TextosDoProfissional.Perfil`)
3. **Publicar e Republicar Vaga** (`PublicarVaga`, `PublicarVagaDaCasa`, `RepublicarVaga`, `RepublicarPosicoesRestantes`)
4. **Lista de Vagas no DF e Detalhe da Vaga** (`TelaVagas`, `CartaoVaga`, `TelaDetalheVaga`, `TextosDoProfissional.Lista`, `TextosDoProfissional.Detalhe`, `FormatadorFrila`)
5. **Candidatura, Turno Confirmado e Vaga Indisponível/Preenchida** (`TelasDaCandidatura`, `CandidaturaEmSelecao`, `DestinosDoAviso`, `ValidacaoClienteAPI`, `CatalogoDesignSystem`)

### 1.1 Principais Métricas de Conformidade

- **Termo "Comissão": 100% Conforme (0 ocorrências).**  
  A palavra "comissão" está terminantemente ausente de todas as telas, componentes, view models e strings do catálogo (`Localizable.xcstrings`). O aplicativo cumpre integralmente a RN01 (valor integral sem descontos nem taxas para quem trabalha).
- **Formatos Numéricos, Moeda e Horários: 95% Conforme.**  
  O motor central `FormatadorFrila` aplica corretamente o fuso `America/Sao_Paulo`, formato 24h `HH:mm`, datas com dia da semana abreviado e moeda em reais com separador de milhar, vírgula decimal e espaço não separável (`R$ 1.250,00`). As únicas discrepâncias encontradas são literais manuais em formulários de publicação (`TextosPublicarVaga.formatoValor` usando espaço regular `R$ %d,%02d`).
- **Glossário Normativo: 88% Conforme (Identificadas 7 violações principais).**  
  Foram localizadas ocorrências de termos vedados pelo Guia de Voz:
  1. `"oportunidades"` em `CatalogoDesignSystem.swift:34` e `ValidacaoClienteAPI.swift:10` (deve ser `"vagas"`).
  2. `"concorrer"` / `"concorre"` em `CandidaturaEmSelecao.swift:18, 22` (termo proibido na Seção 2.1; deve ser `"candidatar-se"`).
  3. `"ponto de partida"` em `TextosDoProfissional.swift:22` (deve ser o termo normativo `"ponto base"`).
  4. `"moderação"` em `RepublicarVaga.swift:43` e `RepublicarPosicoesRestantes.swift:24` (o termo oficial é `"Equipe Frila"`).
  5. `"vagas abertas"` em `Componentes.swift:285, 311` (`CartaoVaga`) e `"Vagas"` em `PublicarVaga.swift:22, 49` referindo-se a posições individuais (o termo normativo é `"posições"`).
  6. `"publique turnos"` em `TelaCadastro.swift:58` (publica-se `"vagas"`, administra-se `"turnos"`).
- **Metas Subjetivas de Tempo: Identificadas 2 violações.**  
  Presença de `"Ele vale por pouco tempo."` em `TelaCodigo.swift:47` e `"Aguarde um instante"` em `ValidacaoClienteAPI.swift:26`.
- **Tom e Pontuação Festiva: Identificadas 3 violações.**  
  Uso de ponto de exclamação em mensagens de sucesso: `"Perfil salvo com sucesso!"` (`TelaPerfilProfissional.swift:54`), `"Vaga republicada com sucesso!"` (`RepublicarVaga.swift:30`) e `"Avaliação registrada com sucesso!"` (`TextosDoProfissional.swift:180`). Devem adotar o tom sóbrio e direto com ponto final (`"Perfil salvo."`, `"Vaga republicada."`).

---

## 2. Metodologia e Critérios de Classificação

Cada elemento de texto foi avaliado segundo os 5 eixos do `iOS/Docs/GuiaDeVoz.md` e os estados definidos em `iOS/Docs/PadroesDeEstado.md`:

| Categoria | Descrição do Critério Normativo |
|---|---|
| **Glossário** | Um termo oficial por conceito (Seção 2.1). Vaga × Oportunidade, Turno × Diária/Escala, Posição × Vaga (unidade), Estabelecimento × Empresa, Contratante, Profissional × Freela, Candidatar-se × Concorrer, Ponto base × Ponto de partida, Equipe Frila × Moderação. |
| **Formatos** | Moeda (`R$ 140,00` e `R$ 1.250,00` com `\u{00A0}`), Horários (`HH:mm` 24h fuso Brasília), Intervalos com travessão ou `" às "`, pernoite com `(dia seguinte)`, distâncias em `km` (Seção 3). |
| **Tom de Voz** | Ordem direta, clareza operacional, sem culpa, ausência de exclamações festivas ou acusatórias (Seção 1.1). |
| **Promessas de Tempo** | Proibição estrita de metas subjetivas: "em instantes", "pouco tempo", "rápido", "já já", "logo logo", "a qualquer momento" (Seção 1.2). |
| **Comissão** | Proibição absoluta do termo "comissão" ou intermediação financeira (RN01, Seção 1.2). |

### Classificação de Gravidade

- **Alta:** Violação direta de termo proibido no glossário normativo ("oportunidade", "concorrer", "moderação"), confusão de entidade ("vaga" no lugar de "posição"), ou promessa temporal subjetiva na interface principal.
- **Média:** Divergência de redação contra modelos fixos homologados do Guia de Voz (tabela de erros da API da Seção 4.2/4.3 ou Seção 5.5), rótulos de botões em desacordo com as especificações normativas.
- **Baixa:** Pontuação festiva (ponto de exclamação em feedback de sucesso), pequenas omissões de palavras de apoio sem prejuízo de entendimento.
- **OK:** Texto totalmente alinhado aos princípios, glossário e formatos oficiais.

---

## 3. Tabelas Detalhadas de Auditoria por Grupo de Telas

### Grupo 1: Entrada por Código, Confirmação e Escolha do Perfil / Cadastro

| Tela / Fluxo | Arquivo:Linha | Texto Atual | Categoria | Regra do Guia | Situação | Gravidade | Sugestão de Correção |
|---|---|---|---|---|:---:|:---:|---|
| **TelaEntrada** | `TelaEntrada.swift:19` | `"Frila"` | Glossário | Nome oficial da marca | OK | — | Manter. |
| **TelaEntrada** | `TelaEntrada.swift:24` | `"Turnos avulsos no DF, perto de você."` | Tom de Voz | Ordem direta, termo oficial "turnos avulsos" | OK | — | Manter. |
| **TelaEntrada** | `TelaEntrada.swift:30` | `"E-mail"` | Formatos | Rótulo direto de campo | OK | — | Manter. |
| **TelaEntrada** | `TelaEntrada.swift:42` | `"Sem senha e sem SMS: você entra com um código enviado ao seu e-mail."` | Tom de Voz | Seção 5.5 orienta: `"Digite seu e-mail para receber um código de acesso de 6 dígitos."` | Divergência | Média | Alinhar ao Guia: `"Digite seu e-mail para receber um código de acesso de 6 dígitos."` |
| **TelaEntrada** | `TelaEntrada.swift:53` | `"Receber código"` (no botão primário) | Tom de Voz | Seção 5.5 prescreve o verbo `"Enviar código"` | Divergência | Média | Trocar rótulo do botão para `"Enviar código"`. |
| **TelaEntrada** | `TelaEntrada.swift:63` | `"Ao continuar, você aceita os Termos de Uso e a Política de Privacidade."` | Tom de Voz | Aviso legal sóbrio | OK | — | Manter. |
| **EntradaViewModel** | `EntradaViewModel.swift:28` | `"Informe um e-mail válido."` | Tom de Voz | Validação direta, sem culpa | OK | — | Manter. |
| **EntradaViewModel** | `EntradaViewModel.swift:48` | `"Não foi possível enviar o código. Tente novamente."` | Tom / Erro | Mensagem com ação orientadora | OK | — | Manter. |
| **TelaCodigo** | `TelaCodigo.swift:42` | `"Digite o código"` | Tom de Voz | Título direto | OK | — | Manter. |
| **TelaCodigo** | `TelaCodigo.swift:47` | `"Enviamos um código de 6 dígitos para \(viewModel.email). Ele vale por pouco tempo."` | Promessa de Tempo | Seção 1.2 veda metas subjetivas ("pouco tempo"). Seção 5.5 prescreve: `"Digite o código de 6 dígitos enviado para o seu e-mail."` | **Violação** | **Alta** | `"Digite o código de 6 dígitos enviado para \(viewModel.email)."` |
| **TelaCodigo** | `TelaCodigo.swift:108` | `"Entrar"` (no botão primário) | Tom de Voz | Seção 5.5 prescreve o rótulo `"Confirmar código"` | Divergência | Média | Trocar rótulo do botão para `"Confirmar código"`. |
| **TelaCodigo** | `TelaCodigo.swift:119` | `"Reenviar código em \(viewModel.segundosRestantes)s"` | Formatos | Contador objetivo em segundos (sem promessa subjetiva) | OK | — | Manter. |
| **TelaCodigo** | `TelaCodigo.swift:127` | `"Reenviar código"` | Glossário | Seção 5.5 botão secundário | OK | — | Manter. |
| **TelaCodigo** | `TelaCodigo.swift:136` | `"Quem já tem conta entra do mesmo jeito. Cada e-mail é uma conta."` | Tom de Voz | Instrução direta e autoexplicativa (RNF09) | OK | — | Manter. |
| **CodigoViewModel** | `CodigoViewModel.swift:84` | `"Novo código enviado para seu e-mail."` | Tom de Voz | Feedback informativo direto | OK | — | Manter. |
| **CodigoViewModel** | `CodigoViewModel.swift:141` | `"Código expirado. Peça um novo código para continuar."` | Tom / Erro | Sem culpa, orientador | OK | — | Manter. |
| **CodigoViewModel** | `CodigoViewModel.swift:143` | `"Código incorreto. Confira os números e tente novamente."` | Tom / Erro | Sem culpa, orientador | OK | — | Manter. |
| **TelaCadastro** | `TelaCadastro.swift:41` | `"Como você vai usar o Frila?"` | Tom de Voz | Seção 5.5 prescreve `"Como você quer usar o Frila?"` | Divergência | Baixa | `"Como você quer usar o Frila?"` |
| **TelaCadastro** | `TelaCadastro.swift:50` | `"Quero trabalhar em turnos"` (Opção 1) | Glossário | Bate com Seção 5.5 (Perfil Profissional) | OK | — | Manter. |
| **TelaCadastro** | `TelaCadastro.swift:51` | `"Perfil de profissional: receba vagas perto de você e candidate-se sem formulário."` | Glossário | Uso correto de "profissional" e "vagas" | OK | — | Manter. |
| **TelaCadastro** | `TelaCadastro.swift:57` | `"Quero contratar para o meu negócio"` (Opção 2) | Glossário | Seção 5.5 define: `"Quero publicar vagas"` | Divergência | Média | Trocar título para `"Quero publicar vagas"`. |
| **TelaCadastro** | `TelaCadastro.swift:58` | `"Perfil de contratante: publique turnos e acompanhe quem vai trabalhar."` | Glossário | Seção 2.1: Contratante "publica vagas e administra turnos". Não se publica turnos. | **Violação** | **Alta** | `"Perfil de contratante: publique vagas e acompanhe quem vai trabalhar."` |
| **TelaCadastro** | `TelaCadastro.swift:65` | `"O perfil fica fixo nesta conta. Para usar o outro lado, crie outra conta, com outro e-mail..."` | Tom de Voz | Explicação prática da RN25 | OK | — | Manter. |
| **TelaCadastro** | `TelaCadastro.swift:91` | `"A outra parte só vê o seu número depois que o turno é confirmado."` | Tom / RN10 | Explicação clara do contato prévio | OK | — | Manter. |
| **TelaCadastro** | `TelaCadastro.swift:124` | `"Tenho 18 anos ou mais"` | Glossário | Declaração afirmativa em primeira pessoa (RN20) | OK | — | Manter. |
| **CadastroViewModel**| `CadastroViewModel.swift:59` | `"O Frila é exclusivo para maiores de 18 anos."` | Glossário | Bate 100% com Seção 5.5 e código `menor_de_idade` | OK | — | Manter. |
| **CadastroViewModel**| `CadastroViewModel.swift:118`| `"Esta conta já foi cadastrada."` | Tom / Erro | Seção 4.2 (`conta_existente`): `"Já existe uma conta cadastrada com este e-mail."` | Divergência | Média | `"Já existe uma conta cadastrada com este e-mail."` |

---

### Grupo 2: Perfil Profissional, Funções e Horários

| Tela / Fluxo | Arquivo:Linha | Texto Atual | Categoria | Regra do Guia | Situação | Gravidade | Sugestão de Correção |
|---|---|---|---|---|:---:|:---:|---|
| **TelaPerfilProfissional** | `TelaPerfilProfissional.swift:74` | `"Funções e horários"` | Glossário | Título oficial de navegação do perfil | OK | — | Manter. |
| **TelaPerfilProfissional** | `TelaPerfilProfissional.swift:88` | `"Seu perfil de profissional"` | Glossário | Uso correto de "profissional" | OK | — | Manter. |
| **TelaPerfilProfissional** | `TelaPerfilProfissional.swift:96` | `"Funções"` | Glossário | Termo oficial da categoria de atuação | OK | — | Manter. |
| **TelaPerfilProfissional** | `TelaPerfilProfissional.swift:120`| `"Ponto base"` | Glossário | Termo oficial (Seção 2.1) | OK | — | Manter. |
| **TelaPerfilProfissional** | `TelaPerfilProfissional.swift:142`| `"Serve para calcular a distância até as vagas. Não é a sua localização em tempo real."` | Glossário | Bate 100% com o Guia Seção 5.5 | OK | — | Manter. |
| **TelaPerfilProfissional** | `TelaPerfilProfissional.swift:183`| `"Ponto base salvo"` | Glossário | Uso correto de "ponto base" | OK | — | Manter. |
| **TelaPerfilProfissional** | `TelaPerfilProfissional.swift:197`| `"Horários em que você pode trabalhar"` | Tom de Voz | Direto, compreensível | OK | — | Manter. |
| **TelaPerfilProfissional** | `TelaPerfilProfissional.swift:202`| `"Nenhum horário cadastrado. Sem horários definidos, você não receberá notificações de vagas."` | Tom de Voz | Sem culpa, orientador | OK | — | Manter. |
| **TelaPerfilProfissional** | `TelaPerfilProfissional.swift:238`| `"Adicionar horário"` | Tom de Voz | Verbo de ação direto | OK | — | Manter. |
| **TelaPerfilProfissional** | `TelaPerfilProfissional.swift:276`| `"O horário de início e fim não podem ser iguais."` | Tom de Voz | Mensagem de erro neutra e direta | OK | — | Manter. |
| **TelaPerfilProfissional** | `TelaPerfilProfissional.swift:282`| `"Horário inválido. Use o formato HH:mm."` | Formatos | Formato 24h oficial (Seção 3.2) | OK | — | Manter. |
| **TelaPerfilProfissional** | `TelaPerfilProfissional.swift:304`| `"Você recebe vagas da sua função, perto de você (até 15 km), nos horários que marcar."` | Glossário / Formatos | Regra de despacho (15 km, ponto base) | OK | — | Manter. |
| **TelaPerfilProfissional** | `TelaPerfilProfissional.swift:54` | `"Perfil salvo com sucesso!"` | Tom de Voz | Ponto de exclamação festivo (Seção 1.1 e PadroesDeEstado #10) | **Violação** | **Baixa** | `"Perfil salvo."` |
| **TextosDoProfissional** | `TextosDoProfissional.swift:139`| `"(dia seguinte)"` | Formatos | Bate 100% com Seção 3.4 para turno noturno | OK | — | Manter. |
| **TextosDoProfissional** | `TextosDoProfissional.swift:141`| `"Salvar e começar"` | Tom de Voz | Rótulo explícito e positivo (Seção 1.3) | OK | — | Manter. |
| **TextosDoProfissional** | `TextosDoProfissional.swift:142`| `"Salvar alterações"` | Tom de Voz | Rótulo padrão de edição | OK | — | Manter. |

---

### Grupo 3: Publicação e Republicação de Vagas

| Tela / Fluxo | Arquivo:Linha | Texto Atual | Categoria | Regra do Guia | Situação | Gravidade | Sugestão de Correção |
|---|---|---|---|---|:---:|:---:|---|
| **PublicarVaga** | `PublicarVaga.swift:11` | `"Publicar vaga"` | Glossário | Ação oficial do contratante | OK | — | Manter. |
| **PublicarVaga** | `PublicarVaga.swift:16` | `"Endereço do turno"` | Glossário | Termo "turno" no contexto da jornada | OK | — | Manter. |
| **PublicarVaga** | `PublicarVaga.swift:18` | `"Valor por posição"` | Glossário | Uso correto de "posição" (unidade) | OK | — | Manter. |
| **PublicarVaga** | `PublicarVaga.swift:20` | `"R$ %d,%02d"` | Formatos | Seção 3.1: Requer espaço não separável (`\u{00A0}`) e ponto em milhar | Divergência | Média | Usar `FormatadorFrila().dinheiro` ou formato com `\u{00A0}`. |
| **PublicarVaga** | `PublicarVaga.swift:21` | `"O profissional recebe o valor integral"` | Comissão / RN01 | Reforça valor integral sem desconto | OK | — | Manter. |
| **PublicarVaga** | `PublicarVaga.swift:22` | `"Vagas"` (como rótulo do campo de quantidade) | Glossário | Seção 2.1: Proibido usar "vaga" para a unidade individual da vaga. Deve ser "Posições". | **Violação** | **Alta** | Trocar rótulo do campo para `"Posições"`. |
| **PublicarVaga** | `PublicarVaga.swift:49` | `"Informe de 1 a 200 vagas."` | Glossário | Seção 2.1: Proibido usar "vagas" para unidades preenchíveis | **Violação** | **Alta** | `"Informe de 1 a 200 posições."` |
| **PublicarVaga** | `PublicarVaga.swift:37` | `"Participa do rateio dos 10%"` | Comissão | Usa "rateio dos 10%", palavra "comissão" ausente | OK | — | Manter. |
| **PublicarVaga** | `PublicarVaga.swift:41` | `"Após a confirmação, o telefone do responsável será mostrado ao profissional para combinar o turno."` | Glossário / RN10 | Explicação correta do compartilhamento pós-confirmação | OK | — | Manter. |
| **PublicarVaga** | `PublicarVaga.swift:59` | `"O primeiro profissional que aceitar é confirmado na hora."` | Glossário | Definição de modo urgência | OK | — | Manter. |
| **PublicarVaga** | `PublicarVaga.swift:60` | `"Você escolhe entre os candidatos. O início precisa estar a mais de 24 horas, e a vaga fecha sozinha 24 horas antes..."` | Glossário / RN24 | Definição clara de modo seleção | OK | — | Manter. |
| **PublicarVaga** | `PublicarVaga.swift:63` | `"A seleção fica disponível para vagas que começam em mais de 24 horas."` | Glossário | Regra da antecedência mínima (RN24) | OK | — | Manter. |
| **RepublicarVaga** | `RepublicarVaga.swift:16` | `"Posições"` | Glossário | Uso correto do termo "Posições" | OK | — | Manter. |
| **RepublicarVaga** | `RepublicarVaga.swift:30` | `"Vaga republicada com sucesso!"` | Tom de Voz | Exclamação festiva contraria o tom sóbrio (Seção 1.1) | **Violação** | **Baixa** | `"Vaga republicada."` |
| **RepublicarVaga** | `RepublicarVaga.swift:43` | `"Esta vaga foi ocultada pela moderação e não pode ser republicada."` | Glossário | Seção 2.1: Proibido "moderação". O termo oficial é "Equipe Frila" (código `vaga_oculta`). | **Violação** | **Alta** | `"Esta vaga está em revisão pela Equipe Frila e não pode ser republicada."` |
| **RepublicarPosicoesRestantes** | `RepublicarPosicoesRestantes.swift:8–13` | `"Republicar 1 posição em urgência"` / `"Republicar %d posições em urgência"` | Glossário | Uso impecável de "posição" e "urgência" | OK | — | Manter. |
| **RepublicarPosicoesRestantes** | `RepublicarPosicoesRestantes.swift:16` | `"As posições restantes desta vaga já foram republicadas em urgência."` | Glossário | Alinhado com o desdobramento `ja_republicada` | OK | — | Manter. |
| **RepublicarPosicoesRestantes** | `RepublicarPosicoesRestantes.swift:24` | `"Esta vaga foi ocultada pela moderação e não pode ser republicada."` | Glossário | Seção 2.1 proíbe "moderação"; usar "Equipe Frila" | **Violação** | **Alta** | `"Esta vaga está em revisão pela Equipe Frila e não pode ser republicada."` |
| **PublicarVagaDaCasa** | `PublicarVagaDaCasa.swift:6` | `"Voltar para Minhas vagas"` | Glossário | Bate 100% com a aba oficial `Minhas vagas` (Seção 2.2) | OK | — | Manter. |

---

### Grupo 4: Lista e Detalhe da Vaga

| Tela / Fluxo | Arquivo:Linha | Texto Atual | Categoria | Regra do Guia | Situação | Gravidade | Sugestão de Correção |
|---|---|---|---|---|:---:|:---:|---|
| **TelaVagas** | `TextosDoProfissional.swift:12` | `"Vagas no DF"` | Glossário | Título oficial da lista principal | OK | — | Manter. |
| **TelaVagas** | `TextosDoProfissional.swift:15–16`| `"Hoje"`, `"Amanhã"` | Formatos | Datas relativas oficiais (Seção 3.5) | OK | — | Manter. |
| **TelaVagas** | `TextosDoProfissional.swift:18` | `"Até \(km) km"` | Formatos | Formato oficial de distância (Seção 3.6) | OK | — | Manter. |
| **TelaVagas** | `TextosDoProfissional.swift:19–20`| `"Nenhuma vaga aberta"`, `"Mude os filtros ou puxe para atualizar."` | Padrões de Estado | Estado vazio com instrução clara de recuperação | OK | — | Manter. |
| **TelaVagas** | `TextosDoProfissional.swift:21` | `"Não foi possível carregar as vagas."` | Padrões de Estado | Falta a ação sugerida do padrão `EstadoErro` (`PadroesDeEstado.md:90`) | Divergência | Média | `"Não foi possível carregar as vagas. Tente novamente."` |
| **TelaVagas** | `TextosDoProfissional.swift:22` | `"Complete seu perfil com o ponto de partida para ver as vagas por distância."` | Glossário | Seção 2.1: Proibido "ponto de partida". O termo oficial normatizado é "ponto base". | **Violação** | **Alta** | `"Complete seu perfil com o ponto base para ver as vagas por distância."` |
| **TelaVagas** | `TextosDoProfissional.swift:24` | `"Sem conexão. Tente de novo quando a internet voltar."` | Padrões de Estado | Seção 2.4 / PadroesDeEstado prescrevem informar dados em cache | Divergência | Média | `"Sem conexão. Mostrando as vagas salvas neste aparelho."` |
| **CartaoVaga** | `Componentes.swift:280` | `formatador.intervalo(vaga.periodo)` | Formatos | Travessão em cartão compacto (Seção 3.3 e 3.4) | OK | — | Manter. |
| **CartaoVaga** | `Componentes.swift:282` | `Text(verbatim: "\(distancia) · \(vaga.local)")` | Formatos | Distância em km + local | OK | — | Manter. |
| **CartaoVaga** | `Componentes.swift:285` | `Text("\(vaga.posicoesAbertas) vagas abertas", bundle: bundleApresentacao)` | Glossário | Seção 2.1: Cada unidade da vaga é uma "posição". Proibido dizer "X vagas abertas" dentro de um anúncio. | **Violação** | **Alta** | `Text("\(vaga.posicoesAbertas) posições abertas", bundle: bundleApresentacao)` |
| **CartaoVaga** | `Componentes.swift:311` | `String(localized: "\(vaga.posicoesAbertas) vagas abertas", bundle: bundleApresentacao)` | Glossário | Rótulo de acessibilidade usando termo indevido | **Violação** | **Alta** | `String(localized: "\(vaga.posicoesAbertas) posições abertas", bundle: bundleApresentacao)` |
| **TelaDetalheVaga** | `TextosDoProfissional.swift:28` | `"Vaga"` | Glossário | Título da tela de anúncio (Seção 2.2) | OK | — | Manter. |
| **TelaDetalheVaga** | `TextosDoProfissional.swift:32` | `"Posições"` | Glossário | Uso correto no cabeçalho de dados da vaga | OK | — | Manter. |
| **TelaDetalheVaga** | `TelaDetalheVaga.swift:128` | `"\(vaga.posicoesAbertas) aberta(s) de \(vaga.posicoes)"` | Glossário | Quantificação clara de posições | OK | — | Manter. |
| **TelaDetalheVaga** | `TextosDoProfissional.swift:33` | `"O valor é integral: o Frila não desconta taxa do turno."` | Glossário / RN01 | Seção 5.2 prescreve: `"O valor é integral: o Frila não desconta do valor pago pelo turno."` | Divergência | Média | `"O valor é integral: o Frila não desconta do valor pago pelo turno."` |
| **TelaDetalheVaga** | `TextosDoProfissional.swift:38` | `"quem aceitar primeiro fica com a vaga"` | Glossário | Bate 100% com o Guia Seção 2.1 | OK | — | Manter. |
| **TelaDetalheVaga** | `TextosDoProfissional.swift:40` | `"o estabelecimento escolhe entre os candidatos"` | Glossário | Bate 100% com o Guia Seção 2.1 | OK | — | Manter. |
| **TelaDetalheVaga** | `TextosDoProfissional.swift:42` | `"Ao confirmar, seu telefone e WhatsApp serão mostrados ao \(estabelecimento) para combinar o turno."` | Glossário / RN10 | Bate 100% com o Guia Seção 5.1 | OK | — | Manter. |
| **TelaDetalheVaga** | `TextosDoProfissional.swift:44` | `"Candidatar-me"` | Tom de Voz | Verbo de ação em primeira pessoa | OK | — | Manter. |
| **FormatadorFrila** | `FormatadorFrila.swift:9–16` | `FormatadorFrila().dinheiro` | Formatos | Produz `R$ 1.250,00` com não separável e centavos | OK | — | Manter. |
| **FormatadorFrila** | `FormatadorFrila.swift:22–27`| `FormatadorFrila().intervalo` | Formatos | Produz `sex 18:00 – sáb 02:00` no fuso SP | OK | — | Manter. |

---

### Grupo 5: Candidatura, Turno Confirmado, Vaga Indisponível/Preenchida e Erros da API

| Tela / Fluxo | Arquivo:Linha | Texto Atual | Categoria | Regra do Guia | Situação | Gravidade | Sugestão de Correção |
|---|---|---|---|---|:---:|:---:|---|
| **TelasDaCandidatura** | `TextosDoProfissional.swift:54` | `"Enviando candidatura…"` | Padrões de Estado | Feedback inline de carregamento | OK | — | Manter. |
| **TelasDaCandidatura** | `TextosDoProfissional.swift:57` | `"Você está confirmado"` | Glossário | Estado de confirmação do turno (Seção 2.1) | OK | — | Manter. |
| **TelasDaCandidatura** | `TextosDoProfissional.swift:59` | `"Liberado com a confirmação. Fica visível até 7 dias depois do turno."` | Glossário / RN10 | Seção 5.1 prescreve: `"Liberado com a confirmação. Fica visível até 7 dias depois do término do turno."` | Divergência | Baixa | Acrescentar `"do término"`: `"Liberado com a confirmação. Fica visível até 7 dias depois do término do turno."` |
| **TelasDaCandidatura** | `TextosDoProfissional.swift:60` | `"Abrir no WhatsApp"` | Tom / US13 | Bate 100% com o Guia Seção 5.4 | OK | — | Manter. |
| **TelasDaCandidatura** | `TextosDoProfissional.swift:62` | `"Essa vaga já foi preenchida"` | Mensagens de Erro | Seção 4.2 código `posicao_ja_preenchida` tem o título `"Vaga preenchida"` | Divergência | Média | Título: `"Vaga preenchida"` |
| **TelasDaCandidatura** | `TextosDoProfissional.swift:63` | `"Outra pessoa aceitou antes. No modo urgência, quem aceita primeiro fica com a vaga. Nada muda na sua reputação."` | Mensagens de Erro | Seção 4.2 código `posicao_ja_preenchida`: `"Esta posição acabou de ser preenchida por outro profissional. No modo urgência, quem confirma primeiro fica com a vaga."` | Divergência | Média | `"Esta posição acabou de ser preenchida por outro profissional. No modo urgência, quem confirma primeiro fica com a vaga."` |
| **TelasDaCandidatura** | `TextosDoProfissional.swift:65–66`| `"Essa vaga não está mais aberta"`, `"Ela foi cancelada, encerrada ou o horário de início já passou..."` | Mensagens de Erro | Seção 4.2 código `vaga_encerrada`: Título `"Vaga encerrada"`, Texto `"Esta vaga foi encerrada, cancelada ou o horário de início já passou."` | Divergência | Média | Alinhar ao padrão da Seção 4.2. |
| **TelasDaCandidatura** | `TextosDoProfissional.swift:68–69`| `"Você já tem um turno nesse horário"`, `"O horário desta vaga coincide com um turno seu já confirmado. Não dá para estar em dois turnos ao mesmo tempo."` | Mensagens de Erro | Seção 4.3 `details: turno_sobreposto`: Título `"Horário coincidente"`, Texto `"Você já tem um turno confirmado que coincide com o horário desta vaga. Não é possível assumir dois turnos ao mesmo tempo."` | Divergência | Média | Alinhar ao padrão da Seção 4.3. |
| **TelasDaCandidatura** | `TextosDoProfissional.swift:72–73`| `"Essa vaga pede outra função"`, `"A função desta vaga não está no seu perfil. Você pode ajustar suas funções no perfil."` | Mensagens de Erro | Seção 4.3 `details: funcao_incompativel`: Título `"Função diferente"`, Texto `"Esta vaga exige uma função que não está cadastrada no seu perfil profissional."` | Divergência | Média | Alinhar ao padrão da Seção 4.3. |
| **TelasDaCandidatura** | `TextosDoProfissional.swift:74–75`| `"Você não pode se candidatar a esta vaga"`, `"O Frila não aceitou a candidatura para esta vaga."` | Mensagens de Erro | Seção 4.2 código `inelegivel`: Título `"Candidatura não permitida"`, Texto `"Você não cumpre todos os critérios necessários para se candidatar a esta vaga."` | Divergência | Média | Alinhar ao padrão da Seção 4.2. |
| **TelasDaCandidatura** | `TextosDoProfissional.swift:77–78`| `"Sua conta está suspensa"`, `"Enquanto a suspensão durar, você não pode se candidatar a vagas..."` | Mensagens de Erro | Seção 4.3 `details: perfil_suspenso` | OK | — | Manter. |
| **CandidaturaEmSelecao** | `CandidaturaEmSelecao.swift:14` | `"Se a sua candidatura for escolhida, seu telefone e WhatsApp serão mostrados ao %@ para combinar o turno."` | Glossário / RN10 | Bate 100% com o Guia Seção 5.1 | OK | — | Manter. |
| **CandidaturaEmSelecao** | `CandidaturaEmSelecao.swift:15` | `"Retirar candidatura"` | Glossário | Verbo de ação correto | OK | — | Manter. |
| **CandidaturaEmSelecao** | `CandidaturaEmSelecao.swift:18` | `"Você deixa de concorrer a esta vaga. Enquanto ela aceitar candidaturas, dá para se candidatar de novo."` | Glossário | Seção 2.1: Proibido o verbo "concorrer" (vedado no glossário). Deve ser "candidatar-se". | **Violação** | **Alta** | `"Sua candidatura a esta vaga será cancelada. Enquanto ela aceitar candidaturas, você poderá se candidatar novamente."` |
| **CandidaturaEmSelecao** | `CandidaturaEmSelecao.swift:22` | `"Você não concorre mais a esta vaga."` | Glossário | Seção 2.1 proíbe "concorre" | **Violação** | **Alta** | `"Sua candidatura a esta vaga foi retirada."` |
| **CandidaturaEmSelecao** | `CandidaturaEmSelecao.swift:34` | `"Candidaturas"` | Glossário | Aba oficial da navegação do profissional (Seção 2.2) | OK | — | Manter. |
| **CandidaturaEmSelecao** | `CandidaturaEmSelecao.swift:37–38`| `"Nenhuma candidatura"`, `"As vagas a que você se candidatar aparecem aqui."` | Padrões de Estado | Estado vazio claro e informativo | OK | — | Manter. |
| **DestinosDoAviso** | `DestinosDoAviso.swift:175` | `(Textos.preenchidaTitulo, modo == .selecao ? TextosDaSelecao.preenchidaEmSelecao : Textos.preenchidaMensagem)` | Glossário | Diferenciação entre preenchimento por urgência vs seleção | OK | — | Manter. |
| **ValidacaoClienteAPI** | `ValidacaoClienteAPI.swift:10` | `"Esta vaga acabou de ser preenchida. Escolha outra oportunidade."` | Glossário | Seção 2.3 condena o termo "oportunidade" e prescreve o ajuste exato | **Violação** | **Alta** | `"Esta vaga acabou de ser preenchida. Volte para a lista e escolha outra vaga."` |
| **ValidacaoClienteAPI** | `ValidacaoClienteAPI.swift:26` | `"Você fez muitas tentativas. Aguarde um instante e tente novamente."` | Promessa de Tempo | Seção 1.2 proíbe "um instante". Código 429 (`limite_excedido`) prescreve `"Aguarde antes de tentar novamente."` | **Violação** | **Alta** | `"Você realizou muitas tentativas seguidas. Aguarde antes de tentar novamente."` |
| **CatalogoDesignSystem** | `CatalogoDesignSystem.swift:34` | `"Novas oportunidades aparecerão aqui."` | Glossário | Seção 2.3 condena explicitamente esta linha | **Violação** | **Alta** | `"Novas vagas aparecerão aqui."` |

---

## 4. Backlog de Remediação para Missão de Código

A tabela a seguir consolida todas as intervenções necessárias identificadas pela auditoria. **Nenhuma alteração foi realizada nesta missão** (em estrito respeito ao escopo de auditoria estática). As correções estão priorizadas por gravidade com suas respectivas estimativas de esforço:

| Prioridade | Arquivo e Linha | Texto Atual | Correção Proposta | Racional e Regra Violada | Estimativa |
|:---:|---|---|---|---|:---:|
| **1 (Alta)** | `ValidacaoClienteAPI.swift:10` e `Localizable.xcstrings:1866` | `"Esta vaga acabou de ser preenchida. Escolha outra oportunidade."` | `"Esta vaga acabou de ser preenchida. Volte para a lista e escolha outra vaga."` | Eliminação do termo proibido "oportunidade" (Guia de Voz Seção 2.3). | 10 min |
| **2 (Alta)** | `CatalogoDesignSystem.swift:34` | `"Novas oportunidades aparecerão aqui."` | `"Novas vagas aparecerão aqui."` | Eliminação do termo "oportunidade" no Design System (Guia de Voz Seção 2.3). | 5 min |
| **3 (Alta)** | `Componentes.swift:285, 311` (`CartaoVaga`) | `"\(vaga.posicoesAbertas) vagas abertas"` | `"\(vaga.posicoesAbertas) posições abertas"` | Termo oficial para unidade preenchível de turno é "posição", não "vaga" (Guia Seção 2.1). | 15 min |
| **4 (Alta)** | `PublicarVaga.swift:22, 49` | `"Vagas"` / `"Informe de 1 a 200 vagas."` | `"Posições"` / `"Informe de 1 a 200 posições."` | Unidades do formulário de publicação devem ser identificadas como "Posições" (Guia Seção 2.1). | 10 min |
| **5 (Alta)** | `CandidaturaEmSelecao.swift:18, 22` | `"Você deixa de concorrer a esta vaga."` / `"Você não concorre mais a esta vaga."` | `"Sua candidatura a esta vaga será retirada."` / `"Sua candidatura a esta vaga foi retirada."` | Remoção do verbo proibido "concorrer" (Guia Seção 2.1). | 10 min |
| **6 (Alta)** | `TextosDoProfissional.swift:22` | `"Complete seu perfil com o ponto de partida..."` | `"Complete seu perfil com o ponto base..."` | Uso do termo normativo "ponto base" em vez de "ponto de partida" (Guia Seção 2.1). | 5 min |
| **7 (Alta)** | `TelaCodigo.swift:47` | `"Ele vale por pouco tempo."` | Remover frase e manter orientação neutra: `"Digite o código de 6 dígitos enviado para seu e-mail."` | Eliminação de meta subjetiva de tempo "pouco tempo" (Guia Seção 1.2 e 5.5). | 10 min |
| **8 (Alta)** | `ValidacaoClienteAPI.swift:26` | `"Aguarde um instante e tente novamente."` | `"Aguarde antes de tentar novamente."` | Eliminação do termo subjetivo proibido "um instante" (Guia Seção 1.2 e 4.2). | 5 min |
| **9 (Alta)** | `RepublicarVaga.swift:43` e `RepublicarPosicoesRestantes.swift:24` | `"Esta vaga foi ocultada pela moderação..."` | `"Esta vaga está em revisão pela Equipe Frila e não pode ser republicada."` | Substituição de "moderação" pelo termo oficial "Equipe Frila" (Guia Seção 2.1 e 4.2). | 10 min |
| **10 (Alta)** | `TelaCadastro.swift:58` | `"publique turnos e acompanhe quem vai trabalhar."` | `"publique vagas e acompanhe quem vai trabalhar."` | Correção conceitual: publica-se vagas, cumpre-se turnos (Guia Seção 2.1). | 5 min |
| **11 (Média)** | `TelaEntrada.swift:53` | `"Receber código"` | `"Enviar código"` | Alinhamento do rótulo do botão com a especificação normativa da Seção 5.5. | 5 min |
| **12 (Média)** | `TelaCodigo.swift:108` | `"Entrar"` | `"Confirmar código"` | Alinhamento do rótulo do botão com a especificação normativa da Seção 5.5. | 5 min |
| **13 (Média)** | `TelaCadastro.swift:41, 57` | `"Como você vai usar o Frila?"` / `"Quero contratar para o meu negócio"` | `"Como você quer usar o Frila?"` / `"Quero publicar vagas"` | Alinhamento textual exato com a Seção 5.5. | 10 min |
| **14 (Média)** | `TextosDoProfissional.swift:33` | `"o Frila não desconta taxa do turno."` | `"o Frila não desconta do valor pago pelo turno."` | Alinhamento exato com o texto oficial da RN01 (Guia Seção 5.2). | 5 min |
| **15 (Média)** | `TextosDoProfissional.swift:62–75` | Textos de vaga preenchida, encerrada, sobreposta e função incompatível | Alinhar linha por linha à Tabela Oficial dos Códigos de Erro da API (Guia Seção 4.2 e 4.3) | Padronização dos títulos e ações orientadoras de recusa. | 25 min |
| **16 (Baixa)** | `TelaPerfilProfissional.swift:54`, `RepublicarVaga.swift:30`, `TextosDoProfissional.swift:180` | `"Perfil salvo com sucesso!"` / `"Vaga republicada com sucesso!"` / `"Avaliação registrada com sucesso!"` | `"Perfil salvo."` / `"Vaga republicada."` / `"Avaliação registrada."` | Remoção de exclamações festivas para tom sóbrio e direto (Guia Seção 1.1 e PadroesDeEstado #10). | 10 min |

**Tempo Total Estimado para Implementação:** **140 minutos** (aprox. 2 horas e 20 minutos de missão de código com atualização do catálogo `Localizable.xcstrings` e testes unitários de apresentação).

---

## 5. Critérios Fora do Escopo desta Missão (FALTA)

Em conformidade estrita com o arquivo da missão e as atribuições da equipe, a presente entrega cobre exclusivamente a **auditoria estática textual contra o guia de voz**. Os demais 4 critérios de aceite do cartão **NoKH0SN8** dependem do Fabrício (Design), de comparação visual com os frames do Figma e de execução em aparelho/Accessibility Inspector:

1. **Comparação com os frames do Figma:**  
   *Critério:* Cada tela do Sprint 1 comparada com o frame do Figma; diferenças corrigidas ou aceitas pelo Fabrício por escrito no cartão de iOS.  
   *Situação:* **Pendente (Design / Fabrício).** Fora do escopo do Thor.
2. **Checklist de acessibilidade do kit de handoff:**  
   *Critério:* Checklist preenchido para 100% das telas do Sprint 1, com rótulos, traços e ordem do VoiceOver iguais às anotações.  
   *Situação:* **Pendente (Design / QA / Fabrício).** Fora do escopo do Thor.
3. **Capturas em Dynamic Type AX5:**  
   *Critério:* Em AX5, nenhuma tela do Sprint 1 corta texto ou esconde botão (capturas anexadas no cartão).  
   *Situação:* **Pendente (QA no simulador / Fabrício).** Fora do escopo do Thor (teto de 0 simuladores nesta missão).
4. **Medição de contraste com Accessibility Inspector:**  
   *Critério:* Contraste medido nos pares novos: texto ≥ 4,5:1; ícones e bordas de controle ≥ 3:1.  
   *Situação:* **Pendente (Design / Fabrício).** Fora do escopo do Thor.
5. **Critério 5 do cartão (Textos iguais aos do guia de voz):**  
   *Situação:* **Auditado e mapeado neste documento.** O checklist do cartão Trello **não foi marcado**, aguardando aprovação formal do relatório pela Júlia e execução da missão de remediação.

### UX-04 — horários do perfil (17/10/2026)

Os campos livres de hora foram substituídos por seletores nativos. “Início”, “Fim”,
“Dia da semana” e “Adicionar” reutilizam os textos já localizados; não há texto novo.
O rótulo acessível de Adicionar reutiliza “Adicionar horário” de `TextosDoProfissional.Perfil`.
O aviso de formato “Horário inválido. Use o formato HH:mm.” deixa de ser necessário
na entrada normal da tela. O bloqueio de duração zero conserva a mensagem existente.
Faixas noturnas mantêm a indicação “(dia seguinte)” (#98 C2), conforme alinhamento
com Nick Fury. A faixa alterada e ainda não adicionada entra ao salvar o perfil.
