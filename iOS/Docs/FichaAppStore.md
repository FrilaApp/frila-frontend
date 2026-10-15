# Ficha da App Store — Metadados e Rascunho Oficial (T-0019)

Documento normativo e rascunho completo dos metadados do Frila para publicação na App Store da Apple. Atende ao cartão Trello [PFWvegZa](https://trello.com/c/PFWvegZa) (T-0019; critérios originais de metadados do cartão #78: nenhuma promessa de tempo de fechamento, nenhuma menção a comissão e todas as URLs sob HTTPS), em conformidade estrita com as diretrizes do *App Store Review Guidelines* (especialmente Diretriz 2.3 — *Accurate Metadata*, Diretriz 2.3.7 — *Keywords & Naming*, Diretriz 1.2 — *User-Generated Content* e Diretriz 5.1 — *Privacy*), com o Guia de Voz (`iOS/Docs/GuiaDeVoz.md`) e com o contrato da API (`iOS/Contrato/openapi.yaml: 0.2.41`).

---

## 1. Informações Gerais da Ficha

| Campo do App Store Connect | Valor Configurado | Limite / Regra da Apple | Observações e Conformidade |
|---|---|---|---|
| **Nome do App (App Name)** | `Frila: Vagas e Turnos Extras` | Até 30 caracteres | 28 caracteres. Sem preço, sem "grátis" (Diretriz 2.3.7). |
| **Subtítulo (Subtitle)** | `Turnos em bares e eventos` | Até 30 caracteres | 25 caracteres. Sem superlativos ou promessa de tempo. |
| **Idioma Principal** | Português (Brasil) — `pt-BR` | — | Alinhado a RNF15 e fuso `America/Sao_Paulo`. |
| **Categoria Primária** | Negócios (*Business*) | Obrigatório escolher | Classificação comercial para gestão de turnos e contratação. |
| **Categoria Secundária** | Produtividade (*Productivity*) | Opcional | Gestão operacional de jornada e presença. |
| **Preço** | Grátis (*Free*) | — | O download do app e o uso na versão 1.0 são gratuitos. |
| **Compras no App (IAP)** | Nenhuma | — | Sem compras internas ou assinaturas no app. |
| **Territórios / Disponibilidade** | Apenas Brasil | — | Distribuição restrita à loja brasileira da App Store. |
| **Copyright** | `© 2026 Cauê Carneiro Kilanovic` | Até 4.000 caracteres | Titular pessoa física e responsável pelo projeto de estudantes, conforme decisão do Cauê em 15/10/2026. |

> **Fonte dos limites de identificação:** Apple App Store Review Guidelines, Diretriz 2.3.7 — "App names must be limited to 30 characters"; subtítulo segue o mesmo limite de 30 caracteres ([App Store Connect Help — App information](https://developer.apple.com/help/app-store-connect/reference/app-information)).
>
> **Fonte das categorias:** Diretriz 2.3.5 e [App Store Category Definitions](https://developer.apple.com/app-store/categories/).

---

## 2. Metadados Textuais da Loja

Todos os campos foram redigidos segundo as diretrizes de UX Writing do Frila (`GuiaDeVoz.md:13-37`): frases na ordem direta, termos consolidados no glossário, ausência de termos promocionais vulgares, sem promessas de tempo, sem promessas de toques e sem uso do termo "comissão".

### 2.1 Nome do Aplicativo
- **Texto:** `Frila: Vagas e Turnos Extras`
- **Contagem de caracteres:** **28 caracteres**
- **Limite oficial da Apple:** **30 caracteres**
- **Checagem de regras:** Sem termos de preço ou "grátis" (Diretriz 2.3.7). Contém a marca registrada ("Frila") e os dois conceitos centrais do produto ("Vagas" e "Turnos").

### 2.2 Subtítulo
- **Texto:** `Turnos em bares e eventos`
- **Contagem de caracteres:** **25 caracteres**
- **Limite oficial da Apple:** **30 caracteres**
- **Checagem de regras:** Sintetiza o propósito imediato da plataforma sem promessas temporais ("rápido", "em minutos") e sem termos proibidos.

### 2.3 Palavras-chave (*Keywords*)
- **Texto:** `garcom,bartender,cozinha,restaurante,bar,evento,turno,vaga,trabalho,temporario,atendente,brasilia`
- **Contagem de caracteres / bytes:** **97 caracteres** (97 bytes em codificação UTF-8)
- **Limite oficial da Apple:** **100 caracteres / 100 bytes**
- **Checagem de regras:**
  - Separadas estritamente por vírgulas sem espaços para otimizar espaço, conforme recomendação da Apple.
  - O campo de palavras-chave do App Store Connect é limitado a **100 bytes** (não caracteres), o que é relevante quando há acentos (cada acento em UTF-8 ocupa 2 bytes). Fonte: [Apple App Store Connect Help](https://developer.apple.com/help/app-store-connect/reference/app-information); confirmação empírica em diversas referências de ASO.
  - Não inclui o nome do próprio aplicativo ("Frila"), já indexado automaticamente pelo título, pois a Apple combina automaticamente os três campos na indexação (Fonte: [Apple — Choosing keywords](https://developer.apple.com/app-store/search/)).
  - Não inclui nomes de aplicativos concorrentes ou marcas comerciais de terceiros (Diretriz 2.3.7).
  - Termos de busca orgânica específicos do ecossistema de food service do DF.

### 2.4 Texto Promocional (*Promotional Text*)
- **Texto:**
  > Conecte estabelecimentos a profissionais para turnos extras em bares, restaurantes e eventos no Distrito Federal. Vagas claras e pagamento direto no local.
- **Contagem de caracteres:** **155 caracteres**
- **Limite oficial da Apple:** **170 caracteres**
- **Checagem de regras:** Visível no topo da página do produto antes da descrição; pode ser alterado a qualquer momento sem necessidade de submissão de nova versão binária. Sem promessas de tempo. Não indexado para busca (Fonte: [App Store Connect Help](https://developer.apple.com/help/app-store-connect/reference/app-information)). Sem promessas de tempo.

### 2.5 Descrição Completa (*Description*)
- **Limite oficial da Apple:** **4.000 caracteres**
- **Contagem de caracteres deste texto:** **1.866 caracteres**
- **Texto completo:**

```text
O Frila conecta estabelecimentos do setor de alimentação e hospitalidade a profissionais para turnos pontuais de trabalho no Distrito Federal.

SE VOCÊ É UM ESTABELECIMENTO (CONTRATANTE):
Publique vagas e encontre profissionais disponíveis para cobrir turnos em bares, restaurantes, lanchonetes e eventos.
• Defina a função, a data, o horário de início e término e o valor do turno.
• Escolha o modo de preenchimento: Urgência (para confirmação da primeira pessoa elegível que aceitar) ou Seleção (para escolher entre os candidatos com mais de 24 horas de antecedência).
• Acompanhe a chegada da equipe com check-in geolocalizado no local do turno.
• Crie sua equipe de confiança com profissionais que já trabalharam na sua casa para notificá-los com prioridade.

SE VOCÊ É UM PROFISSIONAL:
Encontre turnos de trabalho extras compatíveis com suas funções e disponibilidade de horários.
• Receba notificações de vagas abertas da sua função a até 15 km do seu ponto base de referência.
• Veja todas as informações antes de se candidatar: função, horários, endereço e o valor a ser pago.
• Registre seu check-in e check-out no aplicativo ao chegar e ao sair do turno.
• Construa seu histórico profissional com taxa de comparecimento transparente e avaliações dos estabelecimentos.

TRANSPARÊNCIA E VALOR INTEGRAL:
O Frila não desconta do valor pago pelo turno (RN01). Todo valor informado na vaga é o valor integral que o profissional recebe da casa. O acerto é realizado diretamente entre as partes ao término do turno.

SEGURANÇA E CONFIANÇA:
• Exclusivo para maiores de 18 anos.
• Confirmação de presença no local do estabelecimento por aproximação geográfica.
• Ferramentas de proteção: bloqueio mútuo e canal de denúncia de irregularidades.
• Avaliações mútuas ao término de cada turno confirmado.

Atuação no Distrito Federal (Brasília e regiões administrativas).
```

### 2.6 Texto de Novidades da Versão (*What's New in This Version*)
- **Versão:** `1.0.0`
- **Limite oficial da Apple:** **4.000 caracteres**
- **Contagem de caracteres deste texto:** **415 caracteres**
- **Texto completo:**

```text
Versão inicial do Frila no Distrito Federal:
• Conexão entre estabelecimentos e profissionais para turnos de trabalho em bares, restaurantes e eventos.
• Publicação e busca de vagas por função, horário e distância.
• Modos de preenchimento por urgência e por seleção de candidatos.
• Confirmação de presença com check-in e check-out no local do turno.
• Histórico de turnos, avaliações mútuas e equipe de confiança.
```

---

## 3. URLs Oficiais (Página Pública)

As URLs públicas em HTTPS dependem de domínio aprovado pelo Cauê antes do preenchimento no App Store Connect. Os textos correspondentes estão em `iOS/Docs/PaginaPublica/`:

| Campo no App Store Connect | URL Oficial | Arquivo Fonte no Repositório | Descrição do Conteúdo |
|---|---|---|---|
| **URL de Suporte (*Support URL*)** | `[A DEFINIR: URL pública de suporte]` | `iOS/Docs/PaginaPublica/suporte.md` | Canal de ajuda, e-mail oficial de contato (`suportefrila@gmail.com`), procedimentos de denúncia e FAQ (página pública confirmada e mesclada no PR 215). |
| **URL de Marketing (*Marketing URL*)** | `[A DEFINIR: URL pública de marketing]` | `[A DEFINIR: URL pública de marketing]` | Página institucional de apresentação do aplicativo e funcionalidades para o DF. |
| **URL de Privacidade (*Privacy Policy URL*)** | `[A DEFINIR: URL pública de privacidade]` | `iOS/Docs/PaginaPublica/privacidade.md` | Política formal de privacidade em conformidade com o Art. 37 da LGPD (Lei nº 13.709/2018). |
| **Termos de Uso (*Terms of Use / EULA*)** | `[A DEFINIR: URL pública dos termos]` | `iOS/Docs/PaginaPublica/termos.md` | Termos de serviço, declaração de maioridade 18+, ausência de vínculo e regras operacionais. |

> **Conferência com o código-fonte:** [`EnderecosOficiais.swift`](../Sources/Apresentacao/EnderecosOficiais.swift), linhas 19–23 (`termosDeUso`, `politicaDePrivacidade`, `emailSuporte` e propriedade computada `urlSuporte`).
>
> **Nota sobre a URL de Suporte:** A propriedade computada `urlSuporte` (`EnderecosOficiais.swift:10`) gera um endereço `mailto:`, usado dentro do app. A URL web de suporte da loja depende de domínio público aprovado; o canal de atendimento é `suportefrila@gmail.com`. Os endereços do app ainda precisam ser alinhados em missão própria.

---

## 4. Classificação Etária e Conformidade Regulatória

### 4.1 Respostas ao Questionário de Conteúdo da Apple (Diretriz 2.3.6)

| Pergunta de Classificação (Apple Content Rating) | Resposta Oficial | Justificativa Técnica no Produto |
|---|---|---|
| **Violência (realística, desenho ou fantasia)** | Nenhuma (*None*) | Aplicativo de produtividade e trabalho; não contém jogos ou violência. |
| **Conteúdo sexual e nudez** | Nenhuma (*None*) | Conteúdo estritamente profissional. |
| **Linguagem obscena ou humor vulgar** | Raro / Leve (*Infrequent/Mild*) | Devido a conteúdo gerado por usuários (avaliações e relatos de denúncia, Diretriz 1.2). |
| **Álcool, tabaco ou drogas** | Raro / Leve (*Infrequent/Mild*) | Vagas operacionais em bares, cervejarias e restaurantes que manipulam e servem bebidas alcoólicas. |
| **Apostas e jogos de azar simulados** | Nenhuma (*None*) | Não aplicável. |
| **Acesso a navegador web aberto** | Não (*No*) | Todos os links abrem páginas oficiais específicas em Safari externo; sem navegador interno irrestrito. |
| **Concurso ou sorteio integrado** | Não (*No*) | Não há premiações financeiras ou sorteios. |
| **Conteúdo Gerado por Usuários (UGC)** | **Sim (*Yes*)** | Profissionais e estabelecimentos registram relatos e avaliações mútuas após turnos. |
| **Chat integrado ou mensagens abertas** | **Não (*No*)** | O app **não possui chat em tempo real**. A comunicação ocorre via link externo para WhatsApp do contato do turno confirmado (`ContatoDTO.dominio()`). |

### 4.2 Classificação Etária Resultante
- **Idade na App Store:** **17+** (classificação máxima atribuível devido a UGC e restrição legal de trabalho).
- **Declaração de Faixa Etária (ECA Digital / Brasil):** **Restrito a maiores de 18 anos** (`Classificacao18ECA.md`, `termos.md:37-43`, RN20). Menores de idade são bloqueados pelo backend com erro `422 menor_de_idade`.

> **Fonte da obrigação:** Diretriz 2.3.6 — "Answer the age rating questions in App Store Connect honestly so that your app aligns properly with parental controls."
> A classificação 18+ reflete o fato de o app mediar contratação de trabalho por turno com troca de dados pessoais (telefone, endereço, presença) e relação financeira, o que não é adequado para menores.

---

## 5. Informações para a Revisão do App (*App Review Information*)

Dados obrigatórios inseridos no App Store Connect para permitir a validação completa do fluxo pelos revisores da Apple:

### 5.1 Contato da Equipe de Revisão
- **Nome:** `Cauê`
- **Sobrenome:** `Carneiro Kilanovic`
- **E-mail de contato:** `suportefrila@gmail.com`
- **Telefone:** `[A DEFINIR: Telefone de contato do Cauê]`

### 5.2 Contas de Demonstração para Testes (*Demo Accounts*)
Como o Frila utiliza autenticação sem senha baseada em código de 6 dígitos via e-mail (OTP), as contas de demonstração continuam pendentes: **depende de cartão do backend (OTP fixo)**.

1. **Conta de Demonstração 1 — Perfil Profissional:**
   - E-mail: `[A DEFINIR: E-mail da conta de demonstração profissional]`
   - Código OTP fixo: `[A DEFINIR: Código OTP fixo da conta]`
   - Perfil pré-configurado: Garçom / Bartender, Brasília-DF.
2. **Conta de Demonstração 2 — Perfil Estabelecimento (Contratante):**
   - E-mail: `[A DEFINIR: E-mail da conta de demonstração contratante]`
   - Código OTP fixo: `[A DEFINIR: Código OTP fixo da conta]`
   - Perfil pré-configurado: Bar e Restaurante Demo, Asa Sul, Brasília-DF.

### 5.3 Notas de Revisão (*Review Notes*)
> **Texto a colar no campo "Notas" para o revisor da Apple:**
>
> Prezado revisor da Apple,
>
> O Frila é um aplicativo brasileiro que conecta estabelecimentos de alimentação a profissionais para turnos de trabalho no Distrito Federal.
>
> 1. Autenticação: O aplicativo utiliza autenticação segura sem senha via código de 6 dígitos (OTP). Para testar, utilize as duas contas de demonstração fornecidas acima com o código de teste informado.
> 2. Perfis do App: Uma conta atua como Contratante (publica vagas) e a outra como Profissional (candidata-se e registra check-in).
> 3. Geolocalização: O check-in do profissional requer proximidade física com o endereço do estabelecimento. Para testar o check-in no simulador, configure a localização simulada para as coordenadas do estabelecimento demo (Asa Sul, Brasília: Latitude -15.8080, Longitude -47.8890).
> 4. Conteúdo Gerado por Usuários (Diretriz 1.2): O aplicativo inclui moderação ativa, botão nativo de denúncia de irregularidades e bloqueio mútuo definitivo de usuários acessível nos detalhes do turno e do perfil. A moderação de denúncias conta com triagem em até 5 dias úteis; resposta formal em até 15 dias corridos.
> 5. Para qualquer dúvida durante a revisão, estamos à disposição pelo e-mail suportefrila@gmail.com.

---

## 6. Checagem de Conformidade (Auditoria de Diretrizes)

| Item Verificado | Regra / Diretriz | Status | Evidência e Fundamentação |
|---|---|:---:|---|
| **Sem promessas de tempo** | `GuiaDeVoz.md:25` | Conforme | Ausência de termos como "em minutos", "rápido", "em instantes" ou "logo logo". |
| **Sem contagem de toques** | `GuiaDeVoz.md:26` | Conforme | Ausência de termos como "em 2 cliques", "com apenas um toque" ou "a um toque de distância". |
| **Sem a palavra "comissão"** | `GuiaDeVoz.md:27` e RN01 | Conforme | A palavra "comissão" foi terminantemente excluída. Substituída por "valor integral sem desconto". |
| **Sem "grátis" no nome/subtítulo** | Diretriz 2.3.7 da Apple | Conforme | O nome e o subtítulo não contêm termos como "grátis", "free", preços ou símbolos de moeda. |
| **Palavras-chave $\le$ 100 caracteres** | Diretriz 2.3.7 da Apple | Conforme | Contagem rigorosa de 97 caracteres / 97 bytes, sem concorrentes e sem espaços supérfluos. |
| **Precisão de funcionalidades** | Diretriz 2.3.1 da Apple | Conforme | Todas as funcionalidades descritas existem no código (`iOS/Sources/`): urgência, seleção, check-in, equipe de confiança e bloqueio. |
| **Diretriz 1.2 (Moderação e UGC)** | Diretriz 1.2 da Apple | Alinhamento operacional pendente | Descrição inclui botão de denúncia e bloqueio mútuo (`AcoesDeSeguranca.swift:20-150`). Moderação de denúncias: triagem em até 5 dias úteis; resposta formal em até 15 dias corridos (decisão do Cauê em 15/10/2026). O app ainda informa "Respondemos em até 5 dias úteis." (`TextosPerfilConta.prazoSuporte`); alinhamento pendente em missão própria. |
| **Privacidade e LGPD** | Diretriz 5.1 e `LGPD.md` | URLs a confirmar | Textos públicos com canal oficial do titular; domínio e URLs em HTTPS dependem de aprovação. |
| **Sem plataformas concorrentes** | Diretriz 2.3.10 da Apple | Conforme | Ausência de menção a plataformas concorrentes (Android, Google Play). |
| **Sem preços na descrição** | Diretriz 2.3 da Apple | Conforme | Ausência de preços ou valores monetários na descrição geral. |
| **Sem afirmações inverificáveis** | Diretriz 2.3 da Apple | Conforme | Ausência de afirmações superlativas ou inverificáveis ("o melhor", "número 1"). |

---

## 7. Pendências e Responsabilidades (Em Aberto)

Os pontos abaixo dependem de validação de pessoas específicas e permanecem em aberto:

| Pendência | Responsável | Ação Necessária |
|---|---|---|
| **Aprovação dos Textos da Ficha** | Júlia e Fabrício | Revisão final e aprovação conjunta dos textos de descrição, subtítulo e palavras-chave. |
| **Definição das Frases das Capturas** | Fabrício e Júlia | Redação das frases informativas sobre as capturas de tela (Screenshots) até 29/10 (Sprint 2/3). |
| **Configuração das Contas Demo** | Lead Técnico / Cauê | E-mails e códigos continuam `[A DEFINIR]`; depende de cartão do backend (OTP fixo). |
| **Inserção no App Store Connect** | Cauê | Preenchimento dos campos cadastrados no painel oficial do App Store Connect quando o binário for submetido. |

---

## 8. Fontes Normativas e Documentação de Referência

1. [Apple App Store Review Guidelines — 2.3 Accurate Metadata](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata)
2. [Apple App Store Connect Help — App information](https://developer.apple.com/help/app-store-connect/reference/app-information)
3. [Apple — Choosing keywords](https://developer.apple.com/app-store/search/)
4. [App Store Category Definitions](https://developer.apple.com/app-store/categories/)
5. [`EnderecosOficiais.swift`](../Sources/Apresentacao/EnderecosOficiais.swift) — URLs oficiais do app
6. [`SegurancaEPrivacidade.md`](SegurancaEPrivacidade.md) — auditoria de segurança e privacidade do app

---

## Histórico de Alterações

| Data | Autor | Alteração |
|---|---|---|
| 2026-10-12 | Doutor Estranho | Elaboração da ficha completa da App Store: nome, subtítulo, palavras-chave com contagem exata, descrição auditada, What's New, URLs públicas, classificação 17+/18+, dados para revisão e checklist contra Diretrizes 2.3 e Guia de Voz (cartão PFWvegZa, T-0019). |
| 2026-10-12 | Doutor Estranho | Ajustes de devolução (PR 223): e-mail oficial atualizado para `suportefrila@gmail.com` (`EnderecosOficiais.swift:22`), remoção do prazo de 24h na descrição em favor do prazo oficial do app ("Respondemos em até 5 dias úteis.", `TextosPerfilConta.prazoSuporte`) e confirmação da página pública de suporte mesclada no PR 215. |
| 2026-10-13 | Thor | Unificação da ficha da loja (T23): consolidação de fontes oficiais, notas técnicas e auditoria da Diretriz 2.3 migradas do documento preliminar de metadados (apagado) para `FichaAppStore.md`, conforme decisão do Cauê. |
| 2026-10-15 | Homem-Aranha | Atualização da identificação para pessoa física e dos prazos por decisão do Cauê: triagem em até 5 dias úteis; resposta formal em até 15 dias corridos. Substitui a decisão anterior de 12/10/2026 sobre moderação. Contas demo e URLs públicas seguem pendentes. |
