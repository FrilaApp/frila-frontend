# Ficha da App Store — Metadados e Rascunho Oficial (T-0019)

Documento normativo e rascunho completo dos metadados do Frila para publicação na App Store da Apple. Atende ao cartão Trello [PFWvegZa](https://trello.com/c/PFWvegZa) (T-0019; critérios originais de metadados do cartão #78: nenhuma promessa de tempo de fechamento, nenhuma menção a comissão e todas as URLs sob HTTPS), em conformidade estrita com as diretrizes do *App Store Review Guidelines* (especialmente Diretriz 2.3 — *Accurate Metadata*, Diretriz 2.3.7 — *Keywords & Naming*, Diretriz 1.2 — *User-Generated Content* e Diretriz 5.1 — *Privacy*), com o Guia de Voz (`iOS/Docs/GuiaDeVoz.md`) e com o contrato da API (`iOS/Contrato/openapi.yaml: 0.2.43`).

---

## 1. Informações Gerais da Ficha

| Campo do App Store Connect | Valor Configurado | Limite / Regra da Apple | Observações e Conformidade |
|---|---|---|---|
| **Nome do App (App Name)** | `Frila: Turnos e Vagas` | Até 30 caracteres | 21 caracteres. Sem preço, sem "grátis" (Diretriz 2.3.7). Nome já cadastrado no App Store Connect. |
| **Subtítulo (Subtitle)** | `Turnos em bares e eventos` | Até 30 caracteres | 25 caracteres. Sem superlativos ou promessa de tempo. |
| **Idioma Principal** | Português (Brasil) — `pt-BR` | — | Alinhado a RNF15 e fuso `America/Sao_Paulo`. |
| **Categoria Primária** | Negócios (*Business*) | Obrigatório escolher | Classificação comercial para gestão de turnos e contratação. |
| **Categoria Secundária** | Produtividade (*Productivity*) | Opcional | Gestão operacional de jornada e presença. |
| **Preço** | Grátis (*Free*) | — | O download do app e o uso na versão 1.0 são gratuitos. |
| **Compras no App (IAP)** | Nenhuma | — | Sem compras internas ou assinaturas no app. |
| **Territórios / Disponibilidade** | Apenas Brasil | — | Distribuição restrita à loja brasileira da App Store. |
| **Copyright** | `© 2026 Cauê Carneiro Crillanovick` | Até 4.000 caracteres | Titular pessoa física e responsável pelo projeto de estudantes, conforme decisão do Cauê em 15/10/2026. |

> **Fonte dos limites de identificação:** Apple App Store Review Guidelines, Diretriz 2.3.7 — "App names must be limited to 30 characters"; subtítulo segue o mesmo limite de 30 caracteres ([App Store Connect Help — App information](https://developer.apple.com/help/app-store-connect/reference/app-information)).
>
> **Fonte das categorias:** Diretriz 2.3.5 e [App Store Category Definitions](https://developer.apple.com/app-store/categories/).

---

## 2. Metadados Textuais da Loja

Todos os campos foram redigidos segundo as diretrizes de UX Writing do Frila (`GuiaDeVoz.md:13-37`): frases na ordem direta, termos consolidados no glossário, ausência de termos promocionais vulgares, sem promessas de tempo, sem promessas de toques e sem uso do termo "comissão".

### 2.1 Nome do Aplicativo
- **Texto:** `Frila: Turnos e Vagas`
- **Contagem de caracteres:** **21 caracteres**
- **Limite oficial da Apple:** **30 caracteres**
- **Checagem de regras:** Sem termos de preço ou "grátis" (Diretriz 2.3.7). Alinhado ao nome cadastrado no App Store Connect (`DiarioDeConfiguracao.md:63`) e à Tabela 1. Contém a marca registrada ("Frila") e os dois conceitos centrais do produto ("Turnos" e "Vagas").

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

Enquanto não houver domínio próprio (ver `DiarioDeConfiguracao.md`, linha 4), as URLs públicas em HTTPS ficam em `frila.netlify.app`. Os textos correspondentes estão em `iOS/Docs/PaginaPublica/`:

| Campo no App Store Connect | URL Oficial | Arquivo Fonte no Repositório | Descrição do Conteúdo |
|---|---|---|---|
| **URL de Suporte (*Support URL*)** | `https://frila.netlify.app/suporte` | `iOS/Docs/PaginaPublica/suporte.md` | Canal de ajuda, e-mail oficial de contato (`suporte@frilabr.com`), procedimentos de denúncia e FAQ (página pública confirmada e mesclada no PR 215). |
| **URL de Marketing (*Marketing URL*)** | `https://frila.netlify.app` | Página inicial do site (sem arquivo próprio no repositório) | Página institucional de apresentação do aplicativo e funcionalidades para o DF. |
| **URL de Privacidade (*Privacy Policy URL*)** | `https://frila.netlify.app/privacidade` | `iOS/Docs/PaginaPublica/privacidade.md` | Política formal de privacidade em conformidade com o Art. 37 da LGPD (Lei nº 13.709/2018). |
| **Termos de Uso (*Terms of Use / EULA*)** | `https://frila.netlify.app/termos` | `iOS/Docs/PaginaPublica/termos.md` | Termos de serviço, declaração de maioridade 18+, ausência de vínculo e regras operacionais. |

> **Conferência com o código-fonte:** [`EnderecosOficiais.swift`](../Sources/Apresentacao/EnderecosOficiais.swift), linhas 19–23 (`termosDeUso`, `politicaDePrivacidade`, `emailSuporte` e propriedade computada `urlSuporte`).
>
> **Nota sobre a URL de Suporte:** A propriedade computada `urlSuporte` (`EnderecosOficiais.swift:10`) gera um endereço `mailto:`, usado dentro do app. A URL web de suporte da loja é a página do Netlify; o canal de atendimento é `suporte@frilabr.com`. Os endereços do app ainda precisam ser alinhados em missão própria.

---

## 4. Classificação Etária e Conformidade Regulatória

Fonte das respostas: parecer de maioridade de 15/10/2026 (Nick Fury), com base na Portaria MJSP nº 1.048/2025, na Lei nº 15.211/2025 (ECA Digital), no Decreto nº 12.880/2026 e nas páginas da Apple sobre Age Rating. Detalhes e gatilhos de revisão em [`Classificacao18ECA.md`](Classificacao18ECA.md).

### 4.1 Respostas ao Questionário de Age Rating (Diretriz 2.3.6)

A ordem segue a documentação da Apple. Conferir na tela real da App Store Connect; se a redação mudar, o conteúdo das respostas continua valendo.

| Grupo | Pergunta (Apple) | Resposta | Justificativa no produto |
|---|---|---|---|
| In-App Controls | Parental Controls | Não | Não há ferramentas para pais; o público é só adulto. |
| In-App Controls | Age Assurance | **Sim** | O cadastro confere a data de nascimento (app e servidor) e consulta a faixa etária da Apple (Declared Age Range, iOS 26.2+). |
| Capabilities | Unrestricted Web Access | Não | Sem navegador embutido; termos e privacidade abrem no Safari. |
| Capabilities | User-Generated Content | **Sim** | Vagas, avaliações e relatos são vistos por outros usuários; há filtro de texto ofensivo, denúncia e bloqueio (Diretriz 1.2). |
| Capabilities | Social Media | Não | Não há feed. |
| Capabilities | Social media disabled for users under 13 ("Redes sociais desativadas para usuários menores de 13 anos") | Não | Pergunta extra que a tela mostrou em 15/10/2026. Não se aplica: não há rede social e não há usuário abaixo de 18 anos. |
| Capabilities | Messaging and Chat | Não | Não há chat; o contato do turno confirmado abre o WhatsApp, externo (`ContatoDTO.dominio()`). |
| Capabilities | Advertising | Não | Sem anúncios. |
| Mature Themes | Profanity or Crude Humor | Nenhum | O texto de usuários passa pelo filtro de texto ofensivo do servidor. |
| Mature Themes | Horror/Fear Themes | Nenhum | — |
| Mature Themes | Alcohol, Tobacco, or Drug Use or References | Nenhum | Vagas de bar e evento citam o local de trabalho, não o consumo. Se a revisão da Apple discordar, mudar para *Infrequent/Mild* não altera a faixa final (o override é 18+). |
| Medical or Wellness | Medical / Health or Wellness | Nenhum | — |
| Sexuality or Nudity | Todas | Nenhum | Conteúdo estritamente profissional. |
| Violence | Todas (inclusive armas) | Nenhum | — |
| Chance-Based Activities | Gambling / Loot Boxes | Não | — |
| Chance-Based Activities | Simulated Gambling / Contests | Nenhum | Não há sorteio nem competição entre usuários. |
| Additional Information | Age Categories and Override | **Override to Higher Age Rating: 18+** | Não marcar *Made for Kids*. Os termos exigem 18 anos; a Apple pede override quando o contrato tem idade mínima acima da calculada. |
| Additional Information | Age Suitability URL | Em branco por ora | Opcional. Preencher com `https://frila.netlify.app/termos` quando a página dos termos com a classificação estiver no ar. |

### 4.2 Classificação Etária Resultante
- **Calculada pelas respostas:** 4+ (nenhum tema sensível).
- **Na App Store, com o override:** **18+**. As faixas atuais da Apple são 4+, 9+, 13+, 16+ e 18+; a antiga 17+ não existe mais.
- **No Brasil:** **A18** ("Maiores de 18 anos"), conferido na App Store Connect em 15/10/2026.
- **Salvo na App Store Connect em 15/10/2026, como rascunho e sem envio:** **18+** em 173 países ou regiões, **A18** no Brasil e **19+** na Coreia do Sul (a faixa adulta de lá é 19 anos). A reabertura do questionário confirmou as respostas acima.
- **No app:** a tela de entrada mostra "Classificação indicativa: 18 anos" (Portaria MJSP 1.048/2025, art. 50), e os termos trazem a classificação na seção 3 (art. 55).
- **Bloqueio de menores:** o app recusa data de nascimento abaixo de 18 anos e faixa etária `.abaixoDe18` vinda do aparelho; o servidor recusa com `422 menor_de_idade` (RN20).

### 4.3 Texto para a ficha
> O Frila é exclusivo para maiores de 18 anos. Ele conecta estabelecimentos a profissionais autônomos para turnos pagos, inclusive à noite e em locais com venda de bebida alcoólica. Menores de 18 anos não podem criar conta. Classificação indicativa: 18 anos.

> **Fonte da obrigação:** Diretriz 2.3.6 — "Answer the age rating questions in App Store Connect honestly so that your app aligns properly with parental controls."
> A classificação 18+ vem da vedação legal ao trabalho noturno e em local com bebida para menores (CLT arts. 404 e 405; ECA art. 67), não de conteúdo do app.

---

## 5. Informações para a Revisão do App (*App Review Information*)

Dados obrigatórios inseridos no App Store Connect para permitir a validação completa do fluxo pelos revisores da Apple:

### 5.1 Contato da Equipe de Revisão
- **Nome:** `Cauê`
- **Sobrenome:** `Carneiro Crillanovick`
- **E-mail de contato:** `suporte@frilabr.com`
- **Telefone:** `[A DEFINIR]`

### 5.2 Contas de Demonstração para Testes (*Demo Accounts*)
Como o Frila utiliza autenticação sem senha baseada em código de 6 dígitos via e-mail (OTP), o backend implementou um mecanismo de demonstração dedicado para a revisão da App Store (superando a dependência preliminar de "cartão do backend (OTP fixo)"):

- **Edge Function `entrar-demonstracao` (`frila-backend/supabase/functions/entrar-demonstracao/index.ts:1–320`):**
  Porta de entrada HTTP que recebe `{ email, codigo }` e atende exclusivamente às contas declaradas para a revisão da Apple (`DEMONSTRACAO_EMAILS`, linhas 88–93), comparando em tempo constante (`igualEmTempoConstante`, linhas 79–80) contra o código mantido em segredo (`DEMONSTRACAO_CODIGO`, com teto de 10 tentativas em 10 minutos por IP/e-mail, linhas 47–48). Quando válido e dentro da janela ativa configurada na variável de ambiente `DEMONSTRACAO_ATIVA_ATE` (linhas 212–215, com fail-closed se ausente ou expirada), gera a sessão autenticada do Supabase Auth via `POST /auth/v1/admin/generate_link` com a chave `service_role` e `POST /auth/v1/verify` (linhas 13–24), devolvendo ao app exatamente a mesma estrutura de `Sessao` do fluxo normal (`access_token`, `refresh_token`, `user`).
- **Script de Semeadura de Vagas (`frila-backend/scripts/semear-vagas-demonstracao.sh:1–182`):**
  O script está implementado para semear vagas abertas e futuras pós-06/11 para o perfil contratante demo (`Bar da Revisão` / `revisao-contratante`) com posições e quantidade configuráveis, sendo idempotente por `chave_cliente` (RF04). A execução nos ambientes `dev` e `prod` é **não verificada**; o script requer que as variáveis de ambiente `EMAIL_CONTRATANTE` e `ESTABELECIMENTO_BAR_DA_REVISAO` estejam previamente definidas no ambiente (linhas 112, 117, 127 e 149, com `set -u`, a confirmar antes de executar remotamente).
- **Script de Renovação de Dados (`frila-backend/scripts/renovar-demonstracao.sh:1–90`):**
  O script está implementado para invocar `privado.renovar_dados_demonstracao()` visando manter datas à frente do relógio, restaurar turnos para pendente de check-in e zerar o teto de tentativas. A execução no ambiente remoto descarta a saída do comando (`>/dev/null`) e utiliza `curl -s` sem `-f`, de modo que a mensagem de sucesso não comprova a efetiva renovação no banco; a execução remota em dev/prod é **não verificada**.

Os identificadores e códigos fixos são mantidos confidenciais e cadastrados diretamente no App Store Connect:

1. **Conta de Demonstração 1 — Perfil Profissional:**
   - E-mail: `[A DEFINIR: e-mail oficial declarado no App Store Connect]`
   - Código OTP fixo: `[A DEFINIR: código mantido em segredo de ambiente]`
   - Perfil pré-configurado: Garçom / Bartender, Brasília-DF.
2. **Conta de Demonstração 2 — Perfil Estabelecimento (Contratante):**
   - E-mail: `[A DEFINIR: e-mail oficial declarado no App Store Connect]`
   - Código OTP fixo: `[A DEFINIR: código mantido em segredo de ambiente]`
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
> 4. Conteúdo Gerado por Usuários (Diretriz 1.2): O aplicativo inclui moderação ativa, botão nativo de denúncia de irregularidades e bloqueio mútuo definitivo de usuários acessível nos detalhes do turno e do perfil. A moderação de denúncias é realizada o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos.
> 5. Para qualquer dúvida durante a revisão, estamos à disposição pelo e-mail suporte@frilabr.com.

---

## 6. Checagem de Conformidade (Auditoria de Diretrizes)

| Item Verificado | Regra / Diretriz | Status | Evidência e Fundamentação |
|---|---|:---:|---|
| **Nome do App $\le$ 30 caracteres** | Diretriz 2.3.7 da Apple | Conforme | Contagem rigorosa de 21 caracteres (`Frila: Turnos e Vagas`), sem termos de preço ou "grátis", alinhado à Tabela 1 e ao App Store Connect. |
| **Subtítulo $\le$ 30 caracteres** | Diretriz 2.3.7 da Apple | Conforme | Contagem rigorosa de 25 caracteres (`Turnos em bares e eventos`), sem superlativos ou promessa de tempo. |
| **Palavras-chave $\le$ 100 caracteres/bytes** | Diretriz 2.3.7 da Apple | Conforme | Contagem rigorosa de 97 caracteres / 97 bytes UTF-8, separadas por vírgula sem espaço, sem nome do app e sem concorrentes. |
| **Texto Promocional $\le$ 170 caracteres** | App Store Connect Help | Conforme | Contagem rigorosa de 155 caracteres, sem promessas de tempo, destacando atuação no Distrito Federal. |
| **Descrição Completa $\le$ 4.000 caracteres** | Diretriz 2.3 da Apple | Conforme | Contagem rigorosa de 1.866 caracteres, destacando atuação no Brasil (DF), regras de valor integral sem desconto e exclusividade para maiores de 18 anos. |
| **Novidades da Versão $\le$ 4.000 caracteres** | Diretriz 2.3 da Apple | Conforme | Contagem rigorosa de 415 caracteres para a versão 1.0.0 inicial. |
| **Sem promessas de tempo** | `GuiaDeVoz.md:25` | Conforme | Ausência de termos como "em minutos", "rápido", "em instantes" ou "logo logo". |
| **Sem contagem de toques** | `GuiaDeVoz.md:26` | Conforme | Ausência de termos como "em 2 cliques", "com apenas um toque" ou "a um toque de distância". |
| **Sem a palavra "comissão"** | `GuiaDeVoz.md:27` e RN01 | Conforme | A palavra "comissão" foi terminantemente excluída. Substituída por "valor integral sem desconto". |
| **Sem "grátis" no nome/subtítulo** | Diretriz 2.3.7 da Apple | Conforme | O nome e o subtítulo não contêm termos como "grátis", "free", preços ou símbolos de moeda. |
| **Precisão de funcionalidades** | Diretriz 2.3.1 da Apple | Conforme | Todas as funcionalidades descritas existem no código (`iOS/Sources/`): urgência, seleção, check-in, equipe de confiança e bloqueio. |
| **Diretriz 1.2 (Moderação e UGC)** | Diretriz 1.2 da Apple | Alinhamento operacional pendente | Descrição inclui botão de denúncia e bloqueio mútuo (`AcoesDeSeguranca.swift:20-164`). Moderação de denúncias: o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos (decisão do Cauê em 15/10/2026). O perfil e o suporte de turno já utilizam a redação da triagem (`PerfisDaConta.swift:16` e `TextosDoSuporte.swift:7`); os fluxos de contestação de despacho (`TextosPorQueReceboVagas.swift:29`) e suspensão (`TextosContaSuspensa.swift:10`) ainda informam "em até 5 dias úteis" (alinhamento pendente em missão própria). |
| **Privacidade e LGPD** | Diretriz 5.1 e `LGPD.md` | Conforme (piloto) | Textos públicos com canal oficial do titular; URLs em HTTPS no Netlify (`frila.netlify.app`), domínio próprio fica para quando o produto crescer. |
| **Sem plataformas concorrentes** | Diretriz 2.3.10 da Apple | Conforme | Ausência de menção a plataformas concorrentes (Android, Google Play). |
| **Sem preços na descrição** | Diretriz 2.3 da Apple | Conforme | Ausência de preços ou valores monetários na descrição geral. |
| **Sem afirmações inverificáveis** | Diretriz 2.3 da Apple | Conforme | Ausência de afirmações superlativas ou inverificáveis ("o melhor", "número 1"). |

---

## 7. Pendências e Responsabilidades (Em Aberto)

Os pontos abaixo dependem de validação de pessoas específicas e permanecem em aberto:

| Pendência | Responsável | Ação Necessária |
|---|---|---|
| **Aprovação dos Textos da Ficha** | Nick Fury e Fabrício | Revisão final e aprovação dos textos de descrição, subtítulo e palavras-chave conduzida por Nick Fury, por delegação do Cauê em 16/10/2026 (substitui a aprovação da Júlia); alinhamento visual de design com o Fabrício. |
| **Definição das Frases das Capturas** | Fabrício e Nick Fury | Redação das frases informativas sobre as capturas de tela (Screenshots) até 29/10 (Sprint 2/3). |
| **Configuração das Contas Demo** | Lead Técnico / Cauê | Mecanismo implementado no backend (`entrar-demonstracao`, `semear-vagas-demonstracao.sh`, `renovar-demonstracao.sh`); credenciais oficiais, variáveis de ambiente necessárias e execução efetiva no `frila-prod` e no App Store Connect pendentes de confirmação em produção por Cauê. |
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
| 2026-10-12 | Doutor Estranho | Ajustes de devolução (PR 223): e-mail oficial atualizado para `suporte@frilabr.com` (`EnderecosOficiais.swift:22`), remoção do prazo de 24h na descrição em favor do prazo oficial do app ("Respondemos em até 5 dias úteis.", `TextosPerfilConta.prazoSuporte`) e confirmação da página pública de suporte mesclada no PR 215. |
| 2026-10-13 | Thor | Unificação da ficha da loja (T23): consolidação de fontes oficiais, notas técnicas e auditoria da Diretriz 2.3 migradas do documento preliminar de metadados (apagado) para `FichaAppStore.md`, conforme decisão do Cauê. |
| 2026-10-15 | Homem-Aranha | Atualização da identificação para pessoa física e dos prazos por decisão do Cauê: o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos. Substitui a decisão anterior de 12/10/2026 sobre moderação. Contas demo e URLs públicas seguem pendentes. |
| 2026-10-15 | Nick Fury | Seção 4 refeita pelo parecer de maioridade: respostas do Age Rating atual (Age Assurance Sim; linguagem e álcool Nenhum), faixa 18+ por override (17+ não existe mais), A18 esperado no Brasil, aviso na tela de entrada e texto curto para a ficha. |
| 2026-10-16 | Thor | Revisão profunda de textos e metadados: alinhamento do Nome do App na Seção 2.1 para "Frila: Turnos e Vagas" (21 caracteres), auditoria de contagem de todos os campos contra limites da Apple e atualização de responsabilidade de aprovação delegada a Nick Fury. |
