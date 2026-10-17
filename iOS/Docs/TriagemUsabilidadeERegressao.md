# Triagem de Usabilidade e Regressão do Caminho Feliz

Documento de referência técnica para a classificação de severidade de defeitos de usabilidade, rastreabilidade da suíte automatizada do caminho feliz (`CicloDePontaAPontaUITests.swift`) e protocolo de automação de testes de regressão antes da submissão final da v1.0 (Cartão Trello [#70 / yoV2Ak4j](https://trello.com/c/yoV2Ak4j)).

---

## 1. Matriz de Severidade de Defeitos

A classificação de severidade alinha o impacto na experiência da pessoa usuária às regras de liberação estabelecidas no cartão #70 e às definições de estabilidade de `iOS/Docs/RobustezContraCrash.md`:

| Severidade | Definição e Impacto | Critério de Liberação v1.0 (05/11) | Mapeamento com `RobustezContraCrash.md` | Exemplos no Frila |
|---|---|---|---|---|
| **Bloqueante** (Crítico) | Impede a conclusão do fluxo principal (publicação, candidatura, check-in/out, avaliação); causa crash imediato sem recuperação ou deixa o usuário preso em tela sem saída. | **Zero bloqueantes abertos na data limite (05/11).** Bloqueia o release. | **derruba** (crash com dado real/rede) ou **trava** (sem prazo de rede, indicador infinito sem escape). | App fecha ao tocar em "Publicar vaga"; tela de check-in trava sem permitir contingência manual; falha na confirmação de código de acesso sem mensagem de erro. |
| **Grave** (Major) | Prejudica gravemente uma funcionalidade central ou financeira, mas possui contorno viável ou afeta caso de borda específico. | **Corrigido até 05/11 ou aceito formalmente pela PO (Júlia) para a v1.0.1 com justificativa registrada no cartão.** | **errado** de alto impacto (dados incorretos de valores ou turnos, falha em cache essencial). | Valor líquido exibido com cálculo divergente antes da confirmação; botão de contato do contratante demora para atualizar após confirmação imediata de urgência. |
| **Médio** (Minor) | Inconsistência de interface, feedback visual confuso ou comportamento inesperado que não impede a conclusão de tarefas. | Correção recomendada para a v1.0 conforme capacidade; tolerado com registro em backlog para v1.0.1. | **errado** de baixo impacto (mensagens desalinhadas, perda transitória de filtro). | Teclado não fecha automaticamente após preenchimento do telefone em telas secundárias; rótulo de acessibilidade redundante em ícone informativo. |
| **Baixo** (Cosmético) | Detalhe estético, espaçamento imperfeito, microinteração ausente ou refinamento de texto sem prejuízo à compreensão. | Não bloqueia release; triado para refinamentos futuros (v1.0.1 ou v1.1). | Desvio estético sem quebra funcional. | Margem inferior do botão em Dynamic Type XXXL com espaçamento ligeiramente maior que o token; animação de transição menos suave em aparelhos antigos. |

---

## 2. Mapeamento do Caminho Feliz Automatizado (`CicloDePontaAPontaUITests.swift`)

A suíte `CicloDePontaAPontaUITests.swift` valida ponta a ponta o ciclo completo de operação da plataforma Frila, desde a contratação até a avaliação mútua. A matriz detalhada de execução sincronizada para testes manuais com dois iPhones físicos reais está documentada em [MatrizCicloERevisaoAcessibilidadeS1S2.md](MatrizCicloERevisaoAcessibilidadeS1S2.md) (Cartão Trello [AZI1goKB](https://trello.com/c/AZI1goKB)).

### Etapa 1: Publicação de Vaga pelo Contratante (`test01_ContratantePublicaVagaUrgenciaEVeEmMinhasVagas`)

- **Objetivo:** Contratante realiza primeiro acesso, completa cadastro pessoal e do estabelecimento, publica vaga de urgência e valida presença no painel.
- **Configuração de Lançamento:**
  - `-FRILA_ENTRADA`
  - `-FRILA_SCENARIO primeiro-acesso`
  - `-FRILA_CADASTRO_UI_TEST`
- **Passo a Passo e Telas/Componentes Envolvidos:**
  1. **Autenticação:**
     - Tela: `TelaEntrada` (`iOS/Sources/Apresentacao/Fluxos/Autenticacao/TelaEntrada.swift`) → Campo `entrada-email`, botão `entrada-receber-codigo`.
     - Tela: `TelaCodigo` (`iOS/Sources/Apresentacao/Fluxos/Autenticacao/TelaCodigo.swift`) → Campo `Código de acesso`, botão `codigo-entrar`.
  2. **Cadastro do Usuário:**
     - Tela: `TelaCadastro` (`iOS/Sources/Apresentacao/Fluxos/Autenticacao/TelaCadastro.swift`) → Botão `cadastro-perfil-contratante`, campos `cadastro-nome`, `cadastro-telefone`, `cadastro-nascimento`, botões `cadastro-termos` e `cadastro-continuar`.
  3. **Cadastro do Estabelecimento:**
     - Tela: `CadastroEstabelecimento` (`iOS/Sources/Apresentacao/Fluxos/Contratante/CadastroEstabelecimento.swift`) → Botão `continuar-cadastro`.
  4. **Publicação da Vaga:**
     - Tela: `PublicarVaga` (`iOS/Sources/Apresentacao/Fluxos/Contratante/PublicarVaga.swift`) → Modo urgência pré-selecionado, botão `publicar-vaga-botao`.
  5. **Verificação no Painel:**
     - Tela: `MinhasVagas` (`iOS/Sources/Apresentacao/Fluxos/Contratante/MinhasVagas.swift`) → Identificador `minhas-vagas`, item `vaga-contratante-*`.
- **Evidência Automatizada:** Anexo `ciclo-01-vaga-publicada-em-minhas-vagas.png`.

---

### Etapa 2: Candidatura, Contato e Presença pelo Profissional (`test02_ProfissionalCandidataContatoECheckinManualECheckout`)

- **Objetivo:** Profissional localiza vaga de urgência no DF, candidata-se com confirmação imediata, acessa dados de contato liberados, realiza check-in manual (contingência sem GPS) e registra check-out.
- **Configuração de Lançamento:**
  - `-FRILA_SCENARIO success`
  - `-FRILA_LOCALIZACAO negada`
- **Passo a Passo e Telas/Componentes Envolvidos:**
  1. **Descoberta e Seleção:**
     - Tela: `TelaVagas` (`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaVagas.swift`) → Barra `Vagas no DF`, cartão `vaga-*`.
  2. **Candidatura Imediata (Urgência):**
     - Tela: `TelaDetalheVaga` (`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaDetalheVaga.swift`) → Container `tela-detalhe-vaga`, botão `candidatar`.
     - Tela: `TelaResultadoDaCandidatura` (`iOS/Sources/Apresentacao/Fluxos/Profissional/TelasDaCandidatura.swift`) → Indicador `resultado-confirmada`, botão `voltar-para-lista`.
  3. **Acesso aos Meus Turnos:**
     - Tela: `TelaMeusTurnos` (`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeusTurnos.swift`) → Botão `abrir-meus-turnos`, cartão `meu-turno-*`.
  4. **Consulta do Turno e Contato Liberado:**
     - Tela: `TelaMeuTurno` (`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeuTurno.swift`) → Container `tela-meu-turno`, cartão `contato-do-turno`, identificador `contato-telefone` com dados da casa/bistrô.
  5. **Check-in Presencial com Contingência:**
     - Ação: Botão `fazer-checkin`.
     - Tela de Permissão: Botão `permitir-localizacao` (contingência acionada).
     - Tela de Contingência: Indicador `sem-gps`, botão `registro-manual`.
     - Status: Componente `checkin-situacao` exibindo `"Aguardando confirmação do contratante"`.
  6. **Check-out Presencial:**
     - Ação: Botão `fazer-checkout`, botão `registro-manual`.
     - Status: Componente `checkout-situacao` exibindo `"Check-out registrado"`.
- **Evidência Automatizada:** Anexo `ciclo-02-turno-com-presenca-e-checkout.png`.

---

### Etapa 3: Avaliação do Turno pelo Profissional (`test03_ProfissionalAvaliaTurnoConcluido`)

- **Objetivo:** Profissional acessa turno encerrado e verificado, responde à pergunta objetiva de avaliação e confirma gravação da resposta.
- **Configuração de Lançamento:**
  - `-FRILA_SCENARIO turno-encerrado`
- **Passo a Passo e Telas/Componentes Envolvidos:**
  1. **Navegação:**
     - Tela: `TelaMeusTurnos` (`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeusTurnos.swift`) (aba `Meus turnos`) → Cartão `meu-turno-*`.
  2. **Abertura do Formulário:**
     - Tela: `TelaMeuTurno` (`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeuTurno.swift`) → Cartão `cartao-avaliacao-turno`, botão `botao-abrir-avaliacao` (ou `Avaliar turno`).
  3. **Preenchimento e Envio:**
     - Tela: `TelaAvaliacao` (`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaAvaliacao.swift`) → Label `pergunta-avaliacao` (`"Você trabalharia nesse local de novo?"`), botão `resposta-sim`, botão `botao-enviar-avaliacao`.
  4. **Confirmação:**
     - Tela: `TelaAvaliacao` → Componente `aviso-sucesso-avaliacao`.
- **Evidência Automatizada:** Anexo `ciclo-03-avaliacao-profissional-sucesso.png`.

---

### Etapa 4: Fechamento pelo Contratante (`test04_ContratanteVeTurnoConcluido`)

- **Objetivo:** Contratante visualiza turno encerrado, confere presença verificada e avalia o profissional, garantindo idoneidade de ambas as partes.
- **Configuração de Lançamento:**
  - `-FRILA_ABRIR_MINHAS_VAGAS`
  - `-FRILA_SCENARIO ciclo-contratante-turno-concluido`
- **Passo a Passo e Telas/Componentes Envolvidos:**
  1. **Acesso à Vaga Encerrada:**
     - Tela: `MinhasVagasView` (`minhas-vagas`) → Vaga `vaga-contratante-*`.
  2. **Acompanhamento do Turno:**
     - Tela: `DetalheVagaContratanteView` → Botão `acompanhar-turno-*`.
     - Tela: `TurnoDoContratanteView` (`turno-do-contratante`) → Indicadores `presenca-verificada-*`, `detalhe-checkin-*`, `detalhe-confirmacao-*`.
  3. **Avaliação do Profissional:**
     - Tela: `TurnoDoContratanteView` → Cartão `cartao-avaliacao-turno`, botão `botao-abrir-avaliacao`.
     - Tela: `AvaliarTurnoView` → Label `pergunta-avaliacao` (`"Chamaria este profissional de novo?"`), botão `resposta-sim`, botão `botao-enviar-avaliacao`, confirmação `aviso-sucesso-avaliacao`.
  4. **Verificação de Persistência:**
     - Retorno a `TurnoDoContratanteView` → Rótulo `"Resposta: Sim"`, botão `botao-ver-avaliacao`.
     - Reabertura: Componente `aviso-ja-avaliado` (sem botão de envio ativo).
- **Evidência Automatizada:** Anexo `ciclo-04-contratante-avaliacao-concluida.png`.

---

## 3. Roteiro Técnico para Isolamento e Automação de Regressão

Quando uma não-conformidade ou defeito for identificado nas sessões de teste com usuários (cartão Trello T-0018 / Q4ZZwnMR):

### Fluxo de Trabalho Padronizado

```
Defeito Reportado em Sessão
           │
           ▼
1. Isolamento em Dublê ou Fixture (Ambiente Controlado)
           │
           ▼
2. Classificação de Severidade (Matriz Seção 1)
           │
     ┌─────┴────────────────────────┐
     ▼                              ▼
Bloqueante ou Grave          Médio ou Baixo
(Correção Imediata v1.0)     (Backlog / v1.0.1)
     │
     ▼
3. Criação de Teste de Regressão Vermelho (Unitário ou XCUITest)
     │
     ▼
4. Implementação da Correção
     │
     ▼
5. Validação Verde e Execução pelo xcb.sh
     │
     ▼
6. Fechamento e Rastreabilidade no Cartão do Trello
```

### Passos de Execução

1. **Isolamento do Cenário:**
   - Reproduzir a falha utilizando o menor escopo possível via launch arguments (`-FRILA_SCENARIO <cenario>`) ou dublê em memória (`ApiClienteEmMemoria.swift`).
   - Evitar dependência de rede externa para testes reproduzíveis.

2. **Criação do Teste de Regressão:**
   - **Regras de Negócio e Validações:** Criar teste em `iOS/Tests/Unitarios/` (Domínio ou View Models).
   - **Fluxos de Navegação ou Interação Crítica:** Criar caso específico em `iOS/Tests/UI/` utilizando identificadores de acessibilidade (`accessibilityIdentifier`), evitando busca por rótulos literais suscetíveis a tradução.
   - O teste deve falhar antes da alteração do código (comprovando que captura o defeito).

3. **Correção e Não-Regressão:**
   - Aplicar a correção mínima necessária em `iOS/Sources/`.
   - Garantir que o novo teste passa e que a suíte `CicloDePontaAPontaUITests` permanece verde.

4. **Auditoria de Textos e Design System:**
   - Rodar obrigatoriamente `iOS/Scripts/conferir-textos.sh` antes de abrir o PR para evitar literais fora do catálogo de strings ou cores fora dos tokens `FrilaCor`.

---

## 4. Notas sobre Dados e Limites de Escopo

- **Dados de Sessões Reais:** Os defeitos reais das sessões de usabilidade dependem da condução das dinâmicas com usuários previstas no cartão T-0018 / Q4ZZwnMR nas Sprints 2 e 3.
- **Governança de Backlog:** A priorização e o aceite formal de defeitos graves como dívida técnica para a versão 1.0.1 cabem exclusivamente à PO (Júlia) e ao Cauê no Trello.
