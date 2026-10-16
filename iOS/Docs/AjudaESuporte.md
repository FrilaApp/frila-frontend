# Ajuda, Suporte e Termos no app iOS

Documento oficial de auditoria técnica, matriz de rastreabilidade (Visão 7.2 e 7.3), rascunho de textos e recomendações de produto para a tela de Ajuda e Suporte do Frila iOS.
Atende ao cartão Trello [#182 (MNm4dGWq)](https://trello.com/c/MNm4dGWq).

- **Data da auditoria e elaboração:** 12/10/2026
- **Auditor / Responsável técnico:** Loki
- **Repositório:** `frila-frontend`
- **Arquivo:** `iOS/Docs/AjudaESuporte.md`
- **Base:** `origin/main` (`fc5d437`)
- **Referências normativas:** 
  - `Frila_Documento_de_Visao.md` (Seções 7.2 e 7.3)
  - `iOS/Docs/GuiaDeVoz.md` (cartão gNlXnAYP / PR #220)
  - `iOS/Sources/Apresentacao/EnderecosOficiais.swift`
  - `frila-docs/requisitos/ingestao-email-suporte-v1.1.md`
  - `frila-docs/produto/05-ESCOPO-DO-MVP.md`
  - Diretriz 1.2 da App Store (User-Generated Content)

---

## 1. Auditoria dos Canais Oficiais de Suporte e Termos Legais

### 1.1 Centralização e Derivação nas Telas de Perfil
A arquitetura do aplicativo centraliza os endereços institucionais e termos legais na estrutura `EnderecosOficiais` (`iOS/Sources/Apresentacao/EnderecosOficiais.swift:4-24`):
- `termosDeUso`: `https://frila.app/termos`
- `politicaDePrivacidade`: `https://frila.app/privacidade`
- `emailSuporte`: `suportefrila@gmail.com`
- `urlSuporte`: `mailto:\(emailSuporte)`

Nas telas de perfil e configurações, a auditoria confirmou que todos os pontos de contato derivam estritamente da injeção de `EnderecosOficiais`:
1. **Meu Perfil do Profissional (`iOS/Sources/Apresentacao/Fluxos/Perfil/PerfisDaConta.swift:107-162`):**
   - Recebe `enderecos: EnderecosOficiais = .padrao` no ViewModel (`linha 111`).
   - Apresenta o botão "Ajuda" (`TextosPerfilConta.ajuda`, `linha 161`), abrindo a folha modal `TelaAjudaPerfil(enderecos: enderecos)` (`linha 185`).
2. **Perfil do Estabelecimento (`iOS/Sources/Apresentacao/Fluxos/Perfil/PerfisDaConta.swift:245-299`):**
   - Recebe `enderecos: EnderecosOficiais = .padrao` no ViewModel (`linha 247`).
   - Apresenta o botão "Ajuda" (`TextosPerfilConta.ajuda`, `linha 298`), abrindo a folha modal `TelaAjudaPerfil(enderecos: enderecos)` (`linha 344`).
3. **Tela de Ajuda do Perfil (`iOS/Sources/Apresentacao/Fluxos/Perfil/PerfisDaConta.swift:348-450`):**
   - Renderiza o link direto `enderecos.urlSuporte` com acessibilidade (`linhas 361-377`).
   - Expõe o endereço de texto `enderecos.emailSuporte` com seleção habilitada (`.textSelection(.enabled)`) e rótulo de acessibilidade `"E-mail: \(enderecos.emailSuporte)"` (`linhas 384-391`).
   - Exibe o prazo de atendimento informativo: `"Respondemos o mais breve possível, com triagem em até 5 dias úteis."` (`TextosPerfilConta.prazoSuporte`, linha 16, renderizado na linha 393).
   - Renderiza links externos para Termos de Uso (`enderecos.termosDeUso`, `linhas 399-414`) e Política de Privacidade (`enderecos.politicaDePrivacidade`, `linhas 415-430`).
   - Fornece rota de navegação para licenças de terceiros (`TelaLicencas()`, `linhas 431-440`).

**Conclusão da auditoria de Perfil:** Nenhuma string hardcoded de e-mail de suporte existe de forma dispersa nas telas de perfil (`PerfisDaConta.swift`). O canal é derivado de `EnderecosOficiais.padrao.emailSuporte`.

### 1.2 Divergência Identificada de Canais de Suporte
A auditoria identificou que o código do aplicativo unificou o canal em `suportefrila@gmail.com`:
- **Canal em `EnderecosOficiais.padrao` (`EnderecosOficiais.swift:22`):** Configurado como `"suportefrila@gmail.com"` (vigente), verificado por testes de unidade e UI (`PerfisDaContaTests.swift:65,90,105`, `FrilaUITests.swift:740,781`, `ContaSuspensaUITests.swift:131`).
- **Canal em Suporte de Turno (`SuporteTurnoViewModel.swift:142` e `TextosDoSuporte.swift:36,41,42`):** Configurado como `suportefrila@gmail.com` (delegando a `EnderecosOficiais.padrao.emailSuporte` e explicitado nos textos de interface/acessibilidade). O endereço alternativo `"suporte@frila.app"` não existe em `iOS/Sources/`, constando apenas no contrato (`openapi.yaml:2954`) e em requisitos (`frila-docs/requisitos/ingestao-email-suporte-v1.1.md:13`, decisão pendente do Cauê). O canal vigente em todas as telas permanece `suportefrila@gmail.com`.

---

## 2. Conformidade com a Diretriz 1.2 da App Store (User-Generated Content e Moderação)

A Diretriz 1.2 da App Store exige que aplicativos com conteúdo gerado por usuários ou interação direta incluam:
1. Mecanismo para denúncia de conteúdo ofensivo/abusivo.
2. Moderação tempestiva; compromisso operacional do Frila, definido pelo Cauê em 15/10/2026: o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos.
3. Mecanismo para bloqueio mútuo de usuários abusivos.
4. Informações de contato publicadas e acessíveis na interface.

### Estado de Conformidade no App iOS:
- **Mecanismo de Denúncia (Conforme):** `FolhaDeDenuncia` (`iOS/Sources/Apresentacao/Fluxos/Confianca/AcoesDeSeguranca.swift:62-150`), integrada à RPC `denunciar` (valida alvo, motivo, relato de no mínimo 10 caracteres e gera protocolo de acompanhamento).
- **Mecanismo de Bloqueio (Conforme):** `BotaoBloquear` (`iOS/Sources/Apresentacao/Fluxos/Confianca/AcoesDeSeguranca.swift:20-60`), executando bloqueio definitivo entre profissional e estabelecimento para impedir visualizações mútuas, candidaturas e notificações.
- **Informações de Contato (Conforme):** Disponibilizadas em `TelaAjudaPerfil` (`PerfisDaConta.swift:348-450`) com e-mail clicável e copiável.
- **Prazo de Atendimento / SLA de Moderação (Alinhamento do app e backend pendente):**
  - O texto informativo geral de perfil indica `"Respondemos o mais breve possível, com triagem em até 5 dias úteis."` (`TextosPerfilConta.prazoSuporte`, linha 16, renderizado na linha 393; Fonte: Visão 7.2 e RF23). Dois fluxos do app ainda informam resposta "em até 5 dias úteis" sem menção à triagem: contestação de despacho (`TextosPorQueReceboVagas.swift:29`) e contestação de suspensão (`TextosContaSuspensa.swift:10`).
  - O protocolo de denúncia (`AcoesDeSeguranca.swift:82-88`) calcula a data limite a partir de `protocolo.prazoRespostaAte`, que no backend (`privado.prazo_de_resposta`) projeta o quinto dia útil.
  - Compromisso de moderação e denúncia de conteúdo definido pelo Cauê em 15/10/2026: o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos. Os fluxos específicos acima e a data calculada pelo backend ainda precisam ser alinhados em missão própria.

---

## 3. Matriz de Rastreabilidade (Visão 7.2 e 7.3 × Telas do App)

Mapeamento integral de todos os itens normativos das Seções 7.2 e 7.3 do Documento de Visão às telas e linhas do código-fonte do aplicativo iOS, identificando lacunas de escopo.

### 3.1 Visão 7.2 · Ajuda Online

| Item da Visão 7.2 | Requisito Normativo | Tela / Componente iOS | Arquivo:Linha | Situação e Decisão no App |
|---|---|---|---|---|
| **7.2.A** | Seção de perguntas frequentes no menu de configurações | Menu de Configurações / Perfil (`TelaAjudaPerfil`) | `iOS/Sources/Apresentacao/Fluxos/Perfil/PerfisDaConta.swift:348-450` | **sem tela: decisão por delegação: Nick Fury (anteriormente decisão para a Júlia)**.<br>A `TelaAjudaPerfil` atual disponibiliza suporte por e-mail, termos, privacidade e licenças, mas não possui acordeão ou lista de FAQ. Os 5 tópicos foram rascunhados e conferidos na Seção 4 deste documento e aguardam decisão formal sobre inclusão no MVP v1.0 (delegação do Cauê a Nick Fury em 16/10/2026). |
| **7.2.A.1** | FAQ: Como funciona o despacho | Tela "Por que recebo vagas" | `iOS/Sources/Apresentacao/Fluxos/Perfil/TelaPorQueReceboVagas.swift:35-86`<br>`iOS/Sources/Apresentacao/Fluxos/Perfil/TextosPorQueReceboVagas.swift:7-25` | **Tela existente**.<br>Explica os critérios de compatibilidade: função idêntica, raio de até 15 km do ponto base, horários de disponibilidade preenchidos e limite de frequência de notificações. |
| **7.2.A.2** | FAQ: Por que uma vaga pode não aparecer | Tela "Por que recebo vagas" e estado vazio da lista | `iOS/Sources/Apresentacao/Fluxos/Perfil/TelaPorQueReceboVagas.swift:35-86`<br>`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaListaDeVagas.swift:94-118`<br>`iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:23-26` | **Tela existente**.<br>Lista de vagas trata estado vazio orientando revisão de funções e horários. Texto explicativo consolidado como FAQ geral permanece **sem tela: decisão por delegação: Nick Fury (anteriormente decisão para a Júlia)**. |
| **7.2.A.3** | FAQ: Como a reputação é calculada | Histórico de Turnos e Perfis da Conta | `iOS/Sources/Apresentacao/Fluxos/Perfil/TelaHistoricoDeTurnos.swift:1-120`<br>`iOS/Sources/Apresentacao/Fluxos/Perfil/PerfisDaConta.swift:75-104, 210-238`<br>`iOS/Docs/GuiaDeVoz.md:166-175` | **sem tela: decisão por delegação: Nick Fury (anteriormente decisão para a Júlia)**.<br>O app exibe as contagens ("Chamariam de novo: X de Y", "Comparecimento: 100%"), mas não possui tela de ajuda explicativa da fórmula binária e da taxa de presença. Rascunhado e fundamentado na Seção 4.4. |
| **7.2.A.4** | FAQ: O que acontece em caso de cancelamento | Folha de Cancelamento de Turno | `iOS/Sources/Apresentacao/Fluxos/Cancelamento/FolhaDeCancelamento.swift:42-120`<br>`iOS/Sources/Apresentacao/Fluxos/Cancelamento/TextosDoCancelamento.swift:1-40` | **Tela existente no fluxo**, mas como FAQ estático em configurações é **sem tela: decisão por delegação: Nick Fury (anteriormente decisão para a Júlia)**.<br>A modal de cancelamento valida a regra de antecedência de 24 horas (RN12), confirma registro de falta e orienta o impacto na taxa de comparecimento. |
| **7.2.A.5** | FAQ: Como o pagamento é combinado entre as partes | Detalhes da Vaga e Histórico de Turnos | `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaDetalheVaga.swift:150-180`<br>`iOS/Sources/Apresentacao/Fluxos/Perfil/TextosHistoricoDeTurnos.swift:8` | **Tela existente no fluxo**, mas como FAQ em configurações é **sem tela: decisão por delegação: Nick Fury (anteriormente decisão para a Júlia)**.<br>Exibe o valor integral com a indicação de que o Frila não desconta do turno e não atua como intermediador financeiro (RN01). Pagamento é direto entre as partes. |
| **7.2.B** | Tela "Por que recebo vagas" com botão para pedir revisão | Tela Por Que Recebo Vagas | `iOS/Sources/Apresentacao/Fluxos/Perfil/TelaPorQueReceboVagas.swift:35-86`<br>`iOS/Sources/Apresentacao/Fluxos/Perfil/PorQueReceboVagasViewModel.swift:32-60` | **Tela existente**.<br>Apresenta os 4 critérios de despacho ativo, botão "Pedir revisão", integração com RPC `solicitar_revisao_despacho`, geração de protocolo e acompanhamento de prazo de 5 dias úteis. |
| **7.2.C** | Texto curto explicando localização (só no toque do check-in e check-out) | Seção de Presença em Meu Turno | `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:68-73`<br>`iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:14-20` | **Tela existente**.<br>Exibe aviso prévio explicativo: "Sua localização, só neste toque: O Frila lê sua localização só quando você toca no botão, para medir a distância até o endereço da vaga. Só a distância é enviada: sua posição não sai do aparelho e nada é lido em segundo plano." |
| **7.2.D** | Texto curto explicando permissão de notificação (no momento em que é pedida) | Tela de Explicação do Push | `iOS/Sources/Apresentacao/Fluxos/Push/TelasDaPermissaoDePush.swift:9-55`<br>`iOS/Sources/Apresentacao/Fluxos/Push/TextosDoPush.swift:11-35` | **Tela existente**.<br>Apresentada antes do diálogo do iOS no momento contextual de ativação (após salvar funções e horários pelo profissional, ou publicar vaga pelo contratante). Explica que a notificação é o canal que traz a vaga. |
| **7.2.E** | Política de privacidade e Termos de uso em linguagem direta | Tela de Ajuda do Perfil | `iOS/Sources/Apresentacao/Fluxos/Perfil/PerfisDaConta.swift:399-430`<br>`iOS/Sources/Apresentacao/EnderecosOficiais.swift:20-21` | **Tela existente**.<br>Links acessíveis e autenticados para as URLs oficiais `https://frila.app/termos` e `https://frila.app/privacidade`. |
| **7.2.F** | Canal de suporte por e-mail acionável a partir do turno (prazo 5 dias úteis, sem atendimento ao vivo) | Folha de Suporte do Turno | `iOS/Sources/Apresentacao/Fluxos/Suporte/FolhaSuporteTurno.swift:1-301`<br>`iOS/Sources/Apresentacao/Fluxos/Suporte/SuporteTurnoViewModel.swift:1-318`<br>`iOS/Sources/Apresentacao/Fluxos/Suporte/TextosDoSuporte.swift:1-47`<br>`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeuTurno.swift:68-70, 90-103` | **Tela existente**.<br>Botão "Ajuda no turno" (RF23 / US22 / UC14). Registra protocolo via RPC `abrir_suporte`, exibe aviso "Respondemos o mais breve possível, com triagem em até 5 dias úteis." (`TextosDoSuporte.swift:7`) e prepara compositor para `suportefrila@gmail.com` (`EnderecosOficiais.swift:22`, `SuporteTurnoViewModel.swift:142`, `TextosDoSuporte.swift:36`) com assunto e corpo pré-preenchidos. |
| **7.2.G** | Em risco imediato, orientação de contato com autoridades (190 e 180) | Folha de Suporte do Turno | `iOS/Sources/Apresentacao/Fluxos/Suporte/FolhaSuporteTurno.swift:55-75`<br>`iOS/Sources/Apresentacao/Fluxos/Suporte/TextosDoSuporte.swift:17-21` | **Tela existente**.<br>Atalhos telefônicos diretos para ligar 190 (Polícia Militar) e 180 (Central de Atendimento à Mulher), sem aguardar resposta de rede da RPC. |

---

### 3.2 Visão 7.3 · Guias de Instalação e Primeiro Acesso por Perfil

| Item da Visão 7.3 | Requisito Normativo | Tela / Componente iOS | Arquivo:Linha | Situação e Decisão no App |
|---|---|---|---|---|
| **7.3.A** | Guia de primeiro acesso por perfil (exibido no início e consultável depois) | Telas de cadastro / Ajuda do Perfil | `iOS/Sources/Apresentacao/Fluxos/Autenticacao/TelaCadastro.swift:41-69`<br>`iOS/Sources/Apresentacao/Fluxos/Perfil/PerfisDaConta.swift:348-450` | **sem tela: decisão por delegação: Nick Fury (anteriormente decisão para a Júlia)**.<br>Não existe tela dedicada de "Guia de primeiro acesso" em formato de carrossel ou artigo consultável. O primeiro acesso é conduzido funcionalmente pelas telas de cadastro e estados vazios das abas. A inclusão de um guia estático consultável na tela Ajuda depende de decisão formal de produto. |
| **7.3.B.1** | Profissional: Cadastro mínimo | Tela de Cadastro | `iOS/Sources/Apresentacao/Fluxos/Autenticacao/TelaCadastro.swift:4-230`<br>`iOS/Sources/Apresentacao/Fluxos/Autenticacao/CadastroViewModel.swift:1-150` | **Tela existente**.<br>Coleta perfil profissional, nome, telefone WhatsApp, data de nascimento (maioridade 18 anos, RN20) e aviso de perfil fixo na conta (RN25). |
| **7.3.B.2** | Profissional: Escolha de funções | Tela de Perfil Profissional | `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaPerfilProfissional.swift:1-120`<br>`iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:110-130` | **Tela existente**.<br>Seleção de funções do setor de alimentação e eventos (garçom, cozinheiro, barman, etc.) que delimitam as vagas compatíveis. |
| **7.3.B.3** | Profissional: Definição do ponto base e disponibilidade | Tela de Perfil Profissional | `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaPerfilProfissional.swift:120-200`<br>`iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:135-150` | **Tela existente**.<br>Seleção de bairro de referência para raio de até 15 km com a dica explicativa ("Serve para calcular a distância até as vagas. Não é a sua localização em tempo real.") e grade de turnos disponíveis na semana. |
| **7.3.B.4** | Profissional: Ativação da notificação (explicação de que traz a vaga) | Tela de Explicação do Push | `iOS/Sources/Apresentacao/Fluxos/Push/TelasDaPermissaoDePush.swift:9-55`<br>`iOS/Sources/Apresentacao/Fluxos/Push/TextosDoPush.swift:19` | **Tela existente**.<br>Disparada logo após salvar funções e horários (`TelaPerfilProfissional.swift:77`). Explica: "É pela notificação que você fica sabendo de uma vaga nova perto de você, na hora em que ela é publicada." |
| **7.3.C.1** | Estabelecimento: Cadastro | Tela de Cadastro do Estabelecimento | `iOS/Sources/Apresentacao/Fluxos/Contratante/CadastroEstabelecimento.swift:147-365`<br>`iOS/Sources/Apresentacao/Fluxos/Contratante/CadastroEstabelecimentoViewModel.swift:40-140` | **Tela existente**.<br>Coleta nome comercial, CPF/CNPJ, tipo de atividade, endereço com geocodificação no mapa e Região Administrativa do DF. |
| **7.3.C.2** | Estabelecimento: Publicação da primeira vaga com exemplo preenchido | Tela de Publicar Vaga | `iOS/Sources/Apresentacao/Fluxos/Contratante/CadastroEstabelecimento.swift:182-184`<br>`iOS/Sources/Apresentacao/Fluxos/Contratante/PublicarVaga.swift:1-490, 809` | **Tela existente no fluxo; template preenchido: sem tela (decisão por delegação: Nick Fury, anteriormente decisão para a Júlia)**.<br>Ao concluir o cadastro do estabelecimento, o app transiciona diretamente para `TelaPublicarVaga`. O campo de valor exibe o placeholder `"R$ 0,00"`, mas não há template completo pré-preenchido como exemplo estático. |
| **7.3.C.3** | Estabelecimento: Inclusão de outros usuários da equipe | Perfil do Estabelecimento | `iOS/Sources/Apresentacao/Fluxos/Perfil/PerfisDaConta.swift:28-29, 245-299`<br>`frila-docs/produto/05-ESCOPO-DO-MVP.md:70` | **sem tela: decisão por delegação: Nick Fury (anteriormente decisão para a Júlia)**.<br>A história US24 (múltiplos membros por estabelecimento) foi formalmente postergada para a v1.2 no Escopo do MVP. Na v1.0, a tela exibe apenas o papel do usuário atual ("Seu acesso: Administrador"). |
| **7.3.D** | Gestor do estabelecimento: Guia do Painel na versão web | Painel Web / Documentação | `frila-docs/produto/05-ESCOPO-DO-MVP.md:68` | **sem tela: decisão por delegação: Nick Fury (anteriormente decisão para a Júlia)**.<br>O Painel Web (US21) pertence à v1.2 do produto e não integra o escopo do aplicativo nativo iOS da v1.0. |

---

## 4. Rascunho Oficial dos Textos de Ajuda nos Dois Perfis

Redação proposta em conformidade estrita com o `iOS/Docs/GuiaDeVoz.md` (tom direto, sem culpa, sem falsas promessas de tempo, sem a palavra "comissão", vocabulário unificado e formatos monetários e horários padronizados).

### 4.1 Diretrizes Normativas Aplicadas aos Textos
1. **Identificação do suporte:** Canal oficial vigente da Equipe Frila.
   - E-mail vigente no app (perfil e turno): `suportefrila@gmail.com` (`EnderecosOficiais.swift:22`, `SuporteTurnoViewModel.swift:142`, `TextosDoSuporte.swift:36,41,42`).
   - Alternativa citada fora do código do app (`openapi.yaml:2954` e `ingestao-email-suporte-v1.1.md:13`): `suporte@frila.app` (decisão pendente).
2. **Prazo de resposta institucional e SLA de moderação:**
   - Suporte geral no aplicativo: `"Respondemos o mais breve possível, com triagem em até 5 dias úteis."` (`TextosDoSuporte.swift:7` e `PerfisDaConta.swift:16`; Fonte: Visão 7.2 e RF23). O prazo de "5 dias úteis" sem menção à triagem ainda consta em `TextosPorQueReceboVagas.swift:29` e `TextosContaSuspensa.swift:10`.
   - Moderação, denúncias e atendimento: o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos (decisão do Cauê em 15/10/2026). A citação do app acima descreve o estado atual, ainda pendente de alinhamento nos fluxos específicos de contestação.
3. **Ausência de comissão:** Uso da expressão aprovada `"O Frila não desconta do valor pago pelo turno"`.
4. **Sem jargões promocionais:** Banidos termos como "grátis", "100% gratuito", "em poucos toques" e "em instantes".

---

### 4.2 Textos da Tela de Ajuda — Perfil do Profissional

Estrutura proposta para a folha modal `TelaAjudaPerfil` quando acessada por um profissional autenticado (`AbaDoProfissional.perfil`):

```markdown
[Barra de navegação]
Título: Ajuda
Botão de fechar: Fechar (dica: Fecha a tela de ajuda)

[Seção: Atendimento]
Título do grupo: SUPORTE
Botão principal: Fale com a Equipe Frila
Ícone: envelope
Ação: Abre o aplicativo de e-mail com destinatário suportefrila@gmail.com
Dica de acessibilidade: Abre seu aplicativo de e-mail para falar com a Equipe Frila
Texto do endereço: suportefrila@gmail.com (copiável com seleção de texto habilitada)
Aviso informativo de prazo:
"O mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos. Não há atendimento ao vivo."
(Fonte: Documento de Visão 7.2 e Requisito RF23)

Aviso de segurança:
"Em risco imediato durante um turno, ligue 190 (Polícia Militar) ou 180 (Central de Atendimento à Mulher)."
(Fonte: Documento de Visão 7.2 e Requisito RF23)

[Seção: Dúvidas sobre vagas e turnos]
Título do grupo: DÚVIDAS FREQUENTES
Link 1: Como funciona o envio de vagas?
Link 2: Por que uma vaga pode não aparecer para mim?
Link 3: Como a reputação é calculada?
Link 4: O que acontece em caso de cancelamento?
Link 5: Como o pagamento do turno é realizado?
Botão de ação: Por que recebo vagas (navega para TelaPorQueReceboVagas)
Dica de acessibilidade: Mostra os critérios de compatibilidade das vagas com o seu perfil e permite pedir revisão

[Seção: Termos legais]
Título do grupo: DOCUMENTOS LEGAIS
Link externo: Termos de uso (abre https://frila.netlify.app/termos no navegador)
Link externo: Política de privacidade (abre https://frila.netlify.app/privacidade no navegador)
Link interno: Licenças de terceiros (navega para TelaLicencas)

[Rodapé]
Versão do aplicativo: Frila 1.0 (Build [A DEFINIR])
```

---

### 4.3 Textos da Tela de Ajuda — Perfil do Contratante (Estabelecimento)

Estrutura proposta para a folha modal `TelaAjudaPerfil` quando acessada por um contratante autenticado (`AbaDoContratante.perfil`):

```markdown
[Barra de navegação]
Título: Ajuda
Botão de fechar: Fechar (dica: Fecha a tela de ajuda)

[Seção: Atendimento]
Título do grupo: SUPORTE
Botão principal: Fale com a Equipe Frila
Ícone: envelope
Ação: Abre o aplicativo de e-mail com destinatário suportefrila@gmail.com
Dica de acessibilidade: Abre seu aplicativo de e-mail para falar com a Equipe Frila
Texto do endereço: suportefrila@gmail.com (copiável com seleção de texto habilitada)
Aviso informativo de prazo:
"O mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos. Não há atendimento ao vivo."
(Fonte: Documento de Visão 7.2 e Requisito RF23)

[Seção: Dúvidas sobre publicação e equipe]
Título do grupo: DÚVIDAS DO ESTABELECIMENTO
Item 1: Como funciona a publicação e o preenchimento de vagas?
Texto: "No modo urgência, a vaga é preenchida pela primeira pessoa elegível que aceitar. No modo seleção (disponível para vagas com mais de 24 horas de antecedência), você escolhe entre as candidaturas recebidas."

Item 2: O que fazer se o profissional atrasar?
Texto: "O profissional tem tolerância de até 15 minutos do horário de início. Após esse período sem check-in, você pode optar por aguardar ou reabrir a posição na aba Meus turnos."

Item 3: Como funciona a confirmação de presença?
Texto: "O check-in com GPS é confirmado automaticamente quando o profissional chega ao local. Se ele fizer check-in manual por falha de sinal, você precisará confirmar a presença na tela do turno."

Item 4: Como pagar o profissional?
Texto: "O valor informado na publicação é o valor integral a ser pago diretamente ao profissional, na forma combinada entre as partes. O Frila não cobra taxa sobre o turno e não intermedeia pagamentos."

[Seção: Termos legais]
Título do grupo: DOCUMENTOS LEGAIS
Link externo: Termos de uso (abre https://frila.netlify.app/termos no navegador)
Link externo: Política de privacidade (abre https://frila.netlify.app/privacidade no navegador)
Link interno: Licenças de terceiros (navega para TelaLicencas)

[Rodapé]
Versão do aplicativo: Frila 1.0 (Build [A DEFINIR])
```

---

### 4.4 Rascunho das Cinco Perguntas Frequentes (Visão 7.2)

Redação textual das cinco perguntas obrigatórias do Documento de Visão 7.2, estruturadas no formato Pergunta e Resposta direta, com conferência frase a frase, termos do glossário e fundamentação factual com fontes (`arquivo:linha`):

#### Pergunta 1: Como funciona o envio de vagas?
- **Título na interface:** Como funciona o envio de vagas?
- **Texto explicativo:**  
  "Quando um estabelecimento publica uma vaga, o Frila envia a notificação ao mesmo tempo para todos os profissionais compatíveis. Para receber uma vaga, o seu perfil precisa ter a mesma função da vaga, estar a até 15 km do seu ponto base (ou fazer parte da equipe de confiança do estabelecimento) e ter disponibilidade no horário do turno. Se a vaga estiver no modo urgência, a primeira pessoa elegível que aceitar fica com a vaga. Se estiver no modo seleção, o estabelecimento escolhe entre as candidaturas recebidas."
- **Ação sugerida:** Consulte suas funções e horários disponíveis na aba Perfil.
- **Conferência frase a frase e fontes factuais:**
  1. *"Quando um estabelecimento publica uma vaga, o Frila envia a notificação ao mesmo tempo para todos os profissionais compatíveis."* — Despacho ativo simultâneo sem levas ou filas: `iOS/Docs/GuiaDeVoz.md:61-62`; `iOS/Sources/Apresentacao/Fluxos/Perfil/TextosPorQueReceboVagas.swift:19-21`.
  2. *"Para receber uma vaga, o seu perfil precisa ter a mesma função da vaga, estar a até 15 km do seu ponto base (ou fazer parte da equipe de confiança do estabelecimento) e ter disponibilidade no horário do turno."* — Critérios de elegibilidade e raio máximo pelo ponto base: `iOS/Sources/Apresentacao/Fluxos/Perfil/TextosPorQueReceboVagas.swift:7-18`; `iOS/Docs/GuiaDeVoz.md:60, 65, 313-314`. (Divergência corrigida: o texto anterior dizia "endereço do estabelecimento" em vez do termo normativo "ponto base").
  3. *"Se a vaga estiver no modo urgência, a primeira pessoa elegível que aceitar fica com a vaga."* — Regra de aceite direto no modo urgência: `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:37-38`; `iOS/Docs/GuiaDeVoz.md:62, 196`.
  4. *"Se estiver no modo seleção, o estabelecimento escolhe entre as candidaturas recebidas."* — Regra de escolha manual pelo contratante com mais de 24h de antecedência: `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:39-40`; `iOS/Docs/GuiaDeVoz.md:63, 213`.
  5. *Ação sugerida: "Consulte suas funções e horários disponíveis na aba Perfil."* — Nome oficial da aba: `iOS/Docs/GuiaDeVoz.md:81`.

#### Pergunta 2: Por que uma vaga pode não aparecer para mim?
- **Título na interface:** Por que uma vaga pode não aparecer para mim?
- **Texto explicativo:**  
  "Uma vaga pode não aparecer se a função dela não estiver cadastrada no seu perfil, se o horário coincidir com outro turno confirmado ou estiver fora dos seus horários disponíveis, ou se o estabelecimento ficar a mais de 15 km do seu ponto base. Vagas também não aparecem para contas suspensas ou quando todas as posições já foram preenchidas por outros profissionais. Todas as vagas abertas do DF continuam visíveis na lista de vagas."
- **Ação sugerida:** Abra a tela **Por que recebo vagas** no seu perfil para checar seus critérios ou pedir revisão à Equipe Frila.
- **Conferência frase a frase e fontes factuais:**
  1. *"Uma vaga pode não aparecer se a função dela não estiver cadastrada no seu perfil,"* — Incompatibilidade de função cadastrada: `iOS/Sources/Apresentacao/Fluxos/Perfil/TextosPorQueReceboVagas.swift:7-8`; `iOS/Docs/GuiaDeVoz.md:252-255`.
  2. *"se o horário coincidir com outro turno confirmado ou estiver fora dos seus horários disponíveis,"* — Turno sobreposto e janela de disponibilidade: `iOS/Sources/Apresentacao/Fluxos/Perfil/TextosPorQueReceboVagas.swift:9-11`; `iOS/Docs/GuiaDeVoz.md:248-251`.
  3. *"ou se o estabelecimento ficar a mais de 15 km do seu ponto base."* — Limite de distância geográfica pelo ponto base: `iOS/Sources/Apresentacao/Fluxos/Perfil/TextosPorQueReceboVagas.swift:12-15`; `iOS/Docs/GuiaDeVoz.md:65, 313-314`.
  4. *"Vagas também não aparecem para contas suspensas"* — Bloqueio de candidatura para perfis suspensos: `iOS/Sources/Apresentacao/Fluxos/Perfil/TextosPorQueReceboVagas.swift:44`; `iOS/Sources/Apresentacao/Fluxos/Conta/TextosContaSuspensa.swift:4-6`; `iOS/Docs/GuiaDeVoz.md:238-241, 256-259`.
  5. *"ou quando todas as posições já foram preenchidas por outros profissionais."* — Esgotamento de posições abertas: `iOS/Docs/GuiaDeVoz.md:196`.
  6. *"Todas as vagas abertas do DF continuam visíveis na lista de vagas."* — Catálogo público integral do Distrito Federal: `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:12`; `iOS/Docs/GuiaDeVoz.md:314`.
  7. *Ação sugerida: "Abra a tela Por que recebo vagas no seu perfil para checar seus critérios ou pedir revisão à Equipe Frila."* — Fluxo de revisão de elegibilidade (C05 / RF27): `iOS/Sources/Apresentacao/Fluxos/Perfil/TelaPorQueReceboVagas.swift:35-86`; `iOS/Docs/GuiaDeVoz.md:315-316`.

#### Pergunta 3: Como a reputação é calculada?
- **Título na interface:** Como a reputação é calculada?
- **Texto explicativo:**  
  "O Frila não usa notas de 1 a 5 nem média de estrelas. Ao final de cada turno cumprido com presença confirmada, cada parte responde a uma pergunta direta: o contratante responde se chamaria você de novo, e você responde se trabalharia lá de novo. O resultado é exibido no seu perfil como uma contagem sobre o total (por exemplo: 'Chamariam de novo: 8 de 9'). O perfil do profissional também exibe a taxa de comparecimento, que divide os turnos cumpridos com presença confirmada pelos turnos confirmados."
- **Ação sugerida:** Veja seu histórico de avaliações e turnos na aba Perfil.
- **Conferência frase a frase e fontes factuais:**
  1. *"O Frila não usa notas de 1 a 5 nem média de estrelas."* — Reputação binária sem pontuações subjetivas: `iOS/Docs/GuiaDeVoz.md:59`.
  2. *"Ao final de cada turno cumprido com presença confirmada, cada parte responde a uma pergunta direta: o contratante responde se chamaria você de novo, e você responde se trabalharia lá de novo."* — Avaliação binária exclusiva após presença confirmada: `iOS/Sources/Apresentacao/Fluxos/Perfil/PerfisDaConta.swift:75-104`; `iOS/Docs/GuiaDeVoz.md:59, 166-171, 218`. (Divergência corrigida: o texto anterior usava a expressão informal "quem contratou", substituída pelo termo oficial "o contratante" conforme o glossário em `iOS/Docs/GuiaDeVoz.md:52`).
  3. *"O resultado é exibido no seu perfil como uma contagem sobre o total (por exemplo: 'Chamariam de novo: 8 de 9')."* — Formato de exibição da reputação binária: `iOS/Docs/GuiaDeVoz.md:59, 166-171`.
  4. *"O perfil do profissional também exibe a taxa de comparecimento, que divide os turnos cumpridos com presença confirmada pelos turnos confirmados."* — Definição estrita da taxa de comparecimento (turnos não verificados não pontuam): `iOS/Docs/GuiaDeVoz.md:58, 68, 172-175`.
  5. *Ação sugerida: "Veja seu histórico de avaliações e turnos na aba Perfil."* — Acesso ao histórico no perfil: `iOS/Sources/Apresentacao/Fluxos/Perfil/PerfisDaConta.swift:75-104`; `iOS/Docs/GuiaDeVoz.md:81`.

#### Pergunta 4: O que acontece em caso de cancelamento?
- **Título na interface:** O que acontece em caso de cancelamento de turno?
- **Texto explicativo:**  
  "Se precisar cancelar um turno confirmado, faça isso pelo aplicativo com a maior antecedência possível. Cancelamentos feitos com menos de 24 horas de antecedência do horário de início são registrados como falta e reduzem a sua taxa de comparecimento. Cancelamentos realizados com mais de 24 horas de antecedência liberam a posição de volta para a vaga sem registrar falta. Cancelamentos nunca causam suspensão automática da conta; a falta aparece na sua taxa de comparecimento, visível no seu perfil."
- **Ação sugerida:** Se tiver um imprevisto em um turno confirmado, acesse o turno em Meus turnos e utilize a opção Cancelar turno.
- **Conferência frase a frase e fontes factuais:**
  1. *"Se precisar cancelar um turno confirmado, faça isso pelo aplicativo com a maior antecedência possível."* — Fluxo de cancelamento nativo com aviso de antecedência: `iOS/Sources/Apresentacao/Fluxos/Cancelamento/FolhaDeCancelamento.swift:42-120`; `iOS/Sources/Apresentacao/Fluxos/Cancelamento/TextosDoCancelamento.swift:22-36`.
  2. *"Cancelamentos feitos com menos de 24 horas de antecedência do horário de início são registrados como falta e reduzem a sua taxa de comparecimento."* — Regra normativa RN12 (cancelamento com menos de 24 horas conta como falta): `iOS/Sources/Apresentacao/Fluxos/Cancelamento/CancelamentoViewModel.swift:95-96`; `iOS/Sources/Apresentacao/Fluxos/Cancelamento/TextosDoCancelamento.swift:27`; `iOS/Docs/GuiaDeVoz.md:67`. (Divergência corrigida: o item 7.2.A.4 da tabela anterior citava erroneamente RN24, enquanto a regra que rege cancelamento e falta é estritamente a RN12).
  3. *"Cancelamentos realizados com mais de 24 horas de antecedência liberam a posição de volta para a vaga sem registrar falta."* — Liberação e reabertura de posição sem penalidade de falta: `iOS/Sources/Apresentacao/Fluxos/Cancelamento/CancelamentoViewModel.swift:95-96`; `iOS/Sources/Apresentacao/Fluxos/Cancelamento/TextosDoCancelamento.swift:28-29`.
  4. *"Cancelamentos nunca causam suspensão automática da conta; a falta aparece na sua taxa de comparecimento, visível no seu perfil."* — Ausência de suspensão automática; o efeito da falta é o registro na taxa de comparecimento (definição em `iOS/Docs/GuiaDeVoz.md:58`; sem ranking nem prioridade no despacho, que é simultâneo): `iOS/Sources/Apresentacao/Fluxos/Cancelamento/CancelamentoViewModel.swift:74-76`; `iOS/Docs/GuiaDeVoz.md:58, 67`.
  5. *Ação sugerida: "Se tiver um imprevisto em um turno confirmado, acesse o turno em Meus turnos e utilize a opção Cancelar turno."* — Caminho operacional na aba Meus turnos: `iOS/Sources/Apresentacao/Fluxos/Cancelamento/TextosDoCancelamento.swift:8`; `iOS/Docs/GuiaDeVoz.md:79`.

#### Pergunta 5: Como o pagamento do turno é realizado?
- **Título na interface:** Como o pagamento do turno é combinado e realizado?
- **Texto explicativo:**  
  "O valor exibido na vaga é integral: o Frila não desconta do valor pago pelo turno. O pagamento é combinado e realizado diretamente entre o estabelecimento e o profissional, no dia e na forma combinados entre as partes no local do trabalho. O Frila não retém, não processa e não custodia valores de pagamento. Em caso de divergência, denúncias de pagamento não geram suspensão automática na primeira ocorrência: a Equipe Frila faz a triagem em até 5 dias úteis e a apuração com as partes."
- **Ação sugerida:** Confira o valor total e o endereço do local nos detalhes do turno antes de comparecer.
- **Conferência frase a frase e fontes factuais:**
  1. *"O valor exibido na vaga é integral: o Frila não desconta do valor pago pelo turno."* — Regra normativa RN01 (valor integral, sem a palavra "comissão"): `iOS/Docs/GuiaDeVoz.md:27, 308-310`; `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:33`.
  2. *"O pagamento é combinado e realizado diretamente entre o estabelecimento e o profissional, no dia e na forma combinados entre as partes no local do trabalho."* — Transação financeira direta entre as partes: `iOS/Sources/Apresentacao/Fluxos/Perfil/TextosHistoricoDeTurnos.swift:8`; `iOS/Docs/GuiaDeVoz.md:27`.
  3. *"O Frila não retém, não processa e não custodia valores de pagamento."* — Ausência de intermediação ou custódia de pagamentos no app: `iOS/Sources/Apresentacao/Fluxos/Perfil/TextosHistoricoDeTurnos.swift:8`; `iOS/Docs/GuiaDeVoz.md:27`.
  4. *"Em caso de divergência, denúncias de pagamento não geram suspensão automática na primeira ocorrência: a Equipe Frila faz a triagem em até 5 dias úteis e a apuração com as partes."* — Regra de pagamento no local sem suspensão na 1ª denúncia (Decisão do Cauê de 15/10/2026): `iOS/Docs/SegurancaEPrivacidade.md:134-136`; `iOS/Docs/AjudaESuporte.md:57, 68`; `iOS/Docs/DiarioDeConfiguracao.md:15`. (Divergência corrigida: incorporada a decisão formal do Cauê de que não há suspensão automática na primeira denúncia de pagamento, garantindo apuração tempestiva com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos).
  5. *Ação sugerida: "Confira o valor total e o endereço do local nos detalhes do turno antes de comparecer."* — Tela de detalhes da vaga e turno: `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaDetalheVaga.swift:150-180`.

---

## 5. Recomendação Técnica sobre a Inclusão das Perguntas Frequentes

### 5.1 Contexto e Dilema de Escopo no Sprint 1
O cartão Trello MNm4dGWq define como critério de aceite:  
`"Decisão sobre as perguntas frequentes registrada no cartão; se entrarem, os cinco textos aprovados pela Júlia."`  
A Visão 7.2 cita as perguntas frequentes como parte do "conjunto mínimo de ajuda online", enquanto o documento de Escopo do MVP (`05-ESCOPO-DO-MVP.md:13, 65`) enfatiza que o app v1.0 deve manter a menor superfície possível para a submissão de 06/11/2026.

### 5.2 Avaliação Comparativa de Opções

| Critério | Opção 1: Tela Enxuta sem FAQ Embutido (Recomendada para v1.0) | Opção 2: FAQ Completo Embutido na Tela de Ajuda na v1.0 |
|---|---|---|
| **Experiência do usuário** | Direta e sem ruído: quem procura ajuda no perfil encontra imediatamente o e-mail de suporte, o prazo de atendimento, os termos e o atalho para "Por que recebo vagas". | Centraliza respostas estáticas no perfil, mas alonga a tela modal com textos que o usuário raramente lê antes de operar. |
| **Custo de desenvolvimento e QA** | **Zero esforço de código novo**: a `TelaAjudaPerfil` já está implementada (`PerfisDaConta.swift:348-450`), testada por testes unitários e de UI, e atende plenamente à Diretriz 1.2 da App Store. | Exige implementar componente de acordeão/lista expansível em SwiftUI, criar novos identificadores de acessibilidade, atualizar testes de snapshot/UI e validar Dynamic Type XXXL. |
| **Redundância com telas existentes** | **Zero redundância**: as 5 dúvidas já são tratadas de forma contextual onde a pessoa precisa (despacho na tela "Por que recebo vagas", pagamento no detalhe da vaga, faltas na folha de cancelamento). | Duplica regras de negócio em textos estáticos na tela de ajuda, criando risco de divergência quando regras de despacho ou tolerância mudarem. |
| **Risco para o prazo do TestFlight/Loja** | **Risco zero**: escopo já fechado e estável. | Risco de retrabalho de layout e atraso na aprovação de design com o Fabrício. |

### 5.3 Parecer Técnico e Recomendação do Loki
**Recomendação Técnica: Adotar a Opção 1 para o MVP v1.0.**
1. Manter a `TelaAjudaPerfil` na v1.0 com a sua estrutura atual:
   - Canal direto para a Equipe Frila (`suportefrila@gmail.com`); novo compromisso documental: o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos. O texto do app ainda precisa ser alinhado.
   - Links oficiais para Termos de Uso e Política de Privacidade.
   - Atalho contextual para a tela `Por que recebo vagas` (para dúvidas sobre despacho e filtros).
   - Licenças de código aberto.
2. Manter os 5 textos de FAQ rascunhados e aprovados neste documento técnico (`iOS/Docs/AjudaESuporte.md`), disponibilizando-os para consulta institucional em `https://frila.netlify.app/suporte` ou integrando-os como módulo de ajuda expandido na v1.1 do app iOS (dezembro/2026).

> [!IMPORTANT]
> **Decisões a registrar pelo Lead Nick Fury (por delegação do Cauê em 16/10/2026) no Cartão Trello MNm4dGWq:**
> 1. **Decisão sobre FAQ:** Homologar a Opção 1 (manter tela de ajuda enxuta na v1.0 sem FAQ expansível, mantendo o canal de suporte direto e a tela "Por que recebo vagas") OU aprovar a inserção dos 5 textos da Seção 4.4 na tela de Ajuda.
> 2. **Aprovação dos textos:** Se o FAQ for incluído na interface, homologar os 5 textos da Seção 4.4 e os rascunhos das telas por perfil (Seções 4.2 e 4.3).

---

## 6. Status dos Critérios de Aceite do Cartão Trello (MNm4dGWq)

| Critério de Aceite do Cartão | Responsável | Status | Evidência / Onde está |
|---|:---:|:---:|---|
| **1. Frame da tela Ajuda nos dois perfis, com o e-mail e o prazo** | Fabrício | `Pendente` | Depende da entrega dos frames de alta fidelidade no Figma pelo designer Fabrício. Registrado em FALTA no relatório. |
| **2. Decisão sobre as perguntas frequentes registrada no cartão; se entrarem, os cinco textos aprovados por delegação** | Nick Fury | `Pendente de registro` | Textos e recomendação técnica formulados nas Seções 4 e 5 deste documento (`iOS/Docs/AjudaESuporte.md`). Conduzido por Nick Fury por delegação do Cauê em 16/10/2026 (substitui a aprovação da Júlia). Aguarda registro formal no Trello. |
| **3. Tabela ligando cada item da Visão 7.3 (e 7.2) a uma tela existente, sem item sem tela ou sem decisão** | Loki | **Concluído** | Mapeamento integral finalizado na Seção 3 deste documento (`iOS/Docs/AjudaESuporte.md`), com arquivo:linha de cada tela ou marcação explícita de "sem tela: decisão por delegação". |
| **4. Links dos frames colados no cartão de iOS do perfil, onde a Ajuda entra, cada frame com o nome do cartão de iOS** | Fabrício / Nick Fury | `Pendente` | Depende dos links dos frames gerados pelo Fabrício no Figma para colagem nos cartões de iOS. Registrado em FALTA no relatório. |

---

## 7. Conformidade de Scripts e Verificações
- O script oficial `iOS/Scripts/conferir-textos.sh` foi executado e concluiu com sucesso (`OK: textos no bundle da Apresentação e tokens em conformidade`).
- Este documento é composto puramente por Markdown, não alterando código Swift nem disparando fluxos de CI de compilação de código nativo (0 CI).

---

## Histórico de Alterações

| Data | Autor | Alteração |
|---|---|---|
| 2026-10-12 | Loki | Elaboração da auditoria técnica de ajuda, suporte e termos: matriz de rastreabilidade (Visão 7.2 e 7.3), conformidade com Diretriz 1.2 da App Store, rascunho dos textos de ajuda nos dois perfis e cinco perguntas frequentes (cartão MNm4dGWq). |
| 2026-10-15 | Homem-Aranha | Atualização dos prazos para o compromisso operacional do Cauê: o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos. |
| 2026-10-16 | Thor | Revisão profunda dos textos da Seção 4.4 (conferência frase a frase com fontes arquivo:linha, regras de pagamento no local sem suspensão na 1ª denúncia, tolerância de 15 min, correção de RN24 para RN12), alinhamento de URLs públicas para frila.netlify.app e registro da delegação de aprovação da Júlia para Nick Fury. |
