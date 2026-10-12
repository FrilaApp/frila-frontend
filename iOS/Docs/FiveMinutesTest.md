# Preparo do GA Five Minutes Test da Academy (27/10) — Roteiro, Checklist e Folha de Resposta (T-0018)

Documento normativo e operacional de preparação, execução e triagem do teste de primeira impressão (*Five Minutes Test*) do Frila na atividade presencial da Academy em 27/10/2026. Atende ao cartão Trello [h1WOL50F](https://trello.com/c/h1WOL50F) (T-0018 / Agenda da Academy), em conformidade estrita com as diretrizes do Guia de Voz (`iOS/Docs/GuiaDeVoz.md`), da Ficha da App Store (`iOS/Docs/FichaAppStore.md`), do Plano de Métricas (`iOS/Docs/PlanoDeMetricas.md`) e da privacidade por padrão da LGPD (`iOS/Docs/LGPD.md`).

---

## 1. Contexto e Objetivo da Atividade

### 1.1 Por que o Five Minutes Test existe
Na dinâmica da Academy em 27/10/2026, participantes externos (pessoas que nunca viram o produto) terão contato direto com o aplicativo por exatamente cinco minutos e relatarão o que compreenderam. Trata-se de um teste de primeira impressão e clareza cognitiva:
- Se participantes não entenderem o que o Frila faz e para quem se destina em 5 minutos de navegação autônoma, a ficha da loja na App Store (`FichaAppStore.md`) e a primeira tela do aplicativo precisam de intervenção imediata antes do lançamento comercial.
- A atividade ocorre de forma paralela aos testes formais de usabilidade com usuários convidados no TestFlight (`h1WOL50F: "Em paralelo com: S2 · Produto + Design · Testes de usabilidade com usuários no TestFlight (T-0018)"`).

### 1.2 Responsáveis e Papéis na Atividade
Conforme definido no cartão Trello `h1WOL50F`:
- **Responsáveis sugeridos:** Júlia e Fabrício, com o apoio do time.
- **Papel da facilitação:** Conduzir as sessões individuais de 5 minutos de forma neutra, sem induzir respostas e registrando observações na folha de resposta.

---

## 2. Checklist de Véspera dos Aparelhos (26/10)

A preparação dos aparelhos deve ser concluída e testada na véspera da atividade (26/10/2026), atendendo ao primeiro critério de aceite do cartão `h1WOL50F` (*"Aparelhos preparados e testados na véspera"*).

| Item | Requisito Técnico e Operacional | Fonte / Referência | Validação na Véspera (26/10) |
|---|---|---|:---:|
| **Aparelhos Físicos** | Exatamente dois iPhones físicos dedicados para o teste, um configurado em cada perfil do produto (Aparelho A: Perfil Profissional; Aparelho B: Perfil Contratante / Estabelecimento). | Cartão `h1WOL50F`: *"em dois iPhones, um em cada perfil"* | [ ] |
| **Versão / Build** | Build 0.4 (ou o build mais recente disponibilizado no TestFlight externo até 26/10). Não inventar numeração de release. Compilado no esquema `Frila-Beta` com apontamento para ambiente de homologação (`frila-dev`). | Cartão `h1WOL50F`: *"Levar o build 0.4 (ou o mais recente) do TestFlight"* | [ ] |
| **Contas de Teste (Isolamento)** | Utilizar contas de demonstração pré-configuradas com flag institucional `usuario.demonstracao = true`. Essas contas excluem dados das views de métricas reais (`metrica.funil_*`, `PlanoDeMetricas.md:18`).<br>• **Aparelho A (Profissional):** Conta demo de profissional (`demo-profissional@frila.app`, `FichaAppStore.md:156`), com funções operacionais (Garçom, Bartender) e ponto base no DF (ex.: Asa Sul, Brasília).<br>• **Aparelho B (Contratante):** Conta demo de estabelecimento (`demo-contratante@frila.app`, `FichaAppStore.md:160`), com dados de bar/restaurante demo cadastrados no DF.<br>• **Regra rígida:** Proibido utilizar e-mails pessoais de membros da equipe ou de participantes. | `FichaAppStore.md:152-163` e `PlanoDeMetricas.md:18` | [ ] |
| **Conectividade e Rede** | Validar a conexão Wi-Fi do espaço da Academy. Como contingência mandatória para oscilações, ambos os iPhones devem estar com rede celular móvel (4G/5G) ativa ou conectados a um roteador móvel / ponto de acesso portátil testado previamente. | Boas práticas de teste presencial | [ ] |
| **Bateria e Acessórios** | Carga de bateria em 100% em ambos os iPhones ao final da véspera (26/10). Levar na mochila do evento: carregadores de tomada compatíveis, dois cabos de recarga (Lightning / USB-C) e um carregador portátil (*powerbank*) com carga completa. | Boas práticas de bancada | [ ] |
| **Modo de Foco / Não Perturbe** | Ativar o *Modo Não Perturbe* ou criar um *Modo de Foco ("Pesquisa/Teste")* dedicado em ambos os iPhones. Isso bloqueia chamadas telefônicas, mensagens pessoais de WhatsApp, notificações de redes sociais e banners pop-up durante o manuseio pelo participante. | RNF09 (Usabilidade sem distrações) | [ ] |
| **Idioma, Região e Fuso** | Configurações do iOS em ambos os aparelhos:<br>• **Idioma:** Português (Brasil) — `pt-BR`.<br>• **Região:** Brasil.<br>• **Fuso Horário:** Horário de Brasília (`America/Sao_Paulo`).<br>• **Formato de Moeda:** Real (`R$`), garantindo exibição de centavos conforme regra de UX (`R$ 140,00`, `GuiaDeVoz.md:120-125`). | RNF15, `GuiaDeVoz.md:7` e `FichaAppStore.md:13` | [ ] |
| **Estado Inicial das Telas** | O aplicativo deve ser deixado aberto e já autenticado na tela inicial correspondente, com cache carregado e sem modais de erro ou telas intermediárias:<br>• Aparelho A: Aba `Vagas` aberta, exibindo a lista "Vagas no DF".<br>• Aparelho B: Aba `Minhas vagas` aberta, com botão visível para publicação. | Cartão `h1WOL50F` e `GuiaDeVoz.md:78-87` | [ ] |

---

## 3. Roteiro de 5 Minutos (Dinâmica Presencial)

### 3.1 Estrutura Temporal dos 5 Minutos
Cada sessão individual dura rigorosamente cinco minutos:

```
[0:00 - 0:30] Acolhimento, consentimento verbal neutro e entrega do aparelho
      │
      ▼
[0:30 - 3:00] Exploração livre e silenciosa pelo participante (2 min e 30 s)
      │
      ▼
[3:00 - 4:45] Perguntas abertas de saída (3 a 5 perguntas objetivas)
      │
      ▼
[4:45 - 5:00] Agradecimento e encerramento da sessão
```

### 3.2 O que Mostrar (Telas em Foco)
O teste foca a experiência de descoberta e as três superfícies críticas delimitadas no cartão `h1WOL50F`:
1. **"Vagas no DF" (Lista Principal do Profissional):**
   - Apresentada no Aparelho A.
   - Elementos em avaliação: cartões de vaga, função requerida (ex.: Garçom, Bartender), horários do turno, distância em relação ao ponto base e valor a ser pago em reais (`R$`).
2. **"Detalhe da Vaga" (Tela de Informações do Turno):**
   - Acessada ao tocar em um cartão no Aparelho A.
   - Elementos em avaliação: endereço no DF, descrição do turno, política de valor integral sem descontos (`RN01`, `GuiaDeVoz.md:79`), modo de preenchimento (urgência vs seleção) e botão de candidatura (`"Candidatar-me"`).
3. **"Publicar Vaga" e "Minhas Vagas" (Fluxo do Contratante):**
   - Apresentada no Aparelho B.
   - Elementos em avaliação: campos de publicação (função, data, horário de início e término, valor por posição), distinção entre modo urgência e modo seleção (`RN24`) e clareza da gestão da vaga.

### 3.3 O que NÃO Explicar (Regras Estritas para os Facilitadores)
Para garantir a validade ecológica do teste de primeira impressão, a pessoa facilitadora (Júlia / Fabrício) deve manter postura de escuta ativa e observar as seguintes restrições:

- **NÃO explicar o que o Frila faz:** O participante deve deduzir o propósito do app exclusivamente pelos elementos gráficos e textuais da tela. Se o participante perguntar *"O que é esse app?"*, responder de forma neutra: *"Queremos justamente saber o que ele parece ser para você"*.
- **NÃO orientar onde tocar ou o que olhar:** Não apontar o dedo na tela, não guiar o olhar do participante e não indicar botões, abas ou menus (ex.: nunca dizer *"Clica ali em Detalhe"* ou *"Olha aquele valor"*).
- **NÃO justificar limitações ou escolhas de design:** Nunca justificar comportamentos da tela dizendo frases como *"Isso ainda está em desenvolvimento"*, *"Nessa versão demo é assim mesmo"* ou *"A gente fez assim por causa de regra de negócio"*.
- **NÃO corrigir a interpretação do participante:** Se o participante interpretar que se trata de uma vaga CLT com carteira assinada, de um aplicativo de entregas ou de uma rede social de eventos, **não o corrija**. Anote a interpretação literal na folha de resposta. O equívoco do usuário é uma falha de comunicação do produto, não do participante.
- **NÃO usar termos proibidos na interação verbal:** A pessoa facilitadora não deve utilizar termos proibidos pelo `GuiaDeVoz.md:25-30` durante a condução (não falar *"bico"*, *"trampo"*, *"comissão"*, *"em poucos minutos"*, *"a um clique"* ou estrangeirismos como *"job"*, *"match"* ou *"gig"*).
- **NÃO fazer perguntas indutoras:** Evitar perguntas fechadas ou tendenciosas como *"Você achou fácil achar uma vaga?"* ou *"A tela de publicar ficou clara?"*.

### 3.4 As Perguntas Abertas de Saída (3 a 5 Perguntas)
Após os 2 minutos e 30 segundos de observação livre, a pessoa facilitadora aplica as seguintes perguntas abertas, alinhadas às diretrizes do cartão `h1WOL50F`:

1. **Pergunta 1 (Propósito do Produto):**  
   > *"Em suas palavras, o que este aplicativo faz?"*  
   *(Fonte: cartão `h1WOL50F: "o que o app faz"`. Avalia se o conceito de conexão para turnos extras em alimentação e eventos é imediatamente assimilado).*

2. **Pergunta 2 (Público-Alvo):**  
   > *"Para quem você acha que este aplicativo foi feito?"*  
   *(Fonte: cartão `h1WOL50F: "para quem é"`. Avalia se a pessoa identifica com clareza os dois lados da plataforma: estabelecimentos/bares e profissionais operacionais).*

3. **Pergunta 3 (Primeira Ação / Hierarquia Visual):**  
   > *"Olhando para esta tela, o que você faria primeiro?"*  
   *(Fonte: cartão `h1WOL50F: "o que você faria primeiro"`. Avalia a clareza da hierarquia visual e se a chamada primária para ação — CTA — é intuitiva).*

4. **Pergunta 4 (Compreensão de Informações Operacionais):**  
   > *"O que você entendeu sobre os horários e o valor exibidos aqui?"*  
   *(Avalia a clareza dos formatos de turno do `GuiaDeVoz.md:120-145`, turnos noturnos que cruzam a meia-noite e a percepção de valor integral sem desconto).*

5. **Pergunta 5 (Ruídos, Atritos e Dúvidas):**  
   > *"Teve alguma palavra, botão ou informação nesta tela que pareceu confusa ou estranha para você?"*  
   *(Identifica fricções cognitivas de UX Writing, termos do glossário que geraram dúvida e pontos cegos de usabilidade).*

---

## 4. Folha de Resposta (Instrumento de Coleta Presencial)

### 4.1 Conformidade com a LGPD e Privacidade
Em conformidade com os princípios de minimização e privacidade por padrão da LGPD (Art. 7º e 37; `iOS/Docs/LGPD.md:14-45` e `PlanoDeMetricas.md:19`):
- **Anonimização total:** A folha de resposta não coleta nem armazena nenhum dado pessoal do participante (proibido registrar nome completo, e-mail, telefone, CPF ou fotografia do rosto).
- **Identificador anônimo:** Cada participante é identificado unicamente por um código sequencial de sessão (`P01`, `P02`, `P03`, ...).
- **Registro de perfil testado:** Registro técnico apenas do aparelho/perfil utilizado (`Aparelho A - Profissional` ou `Aparelho B - Contratante`).

### 4.2 Modelo de Folha de Resposta Individual (Template)

```markdown
# Folha de Resposta — Five Minutes Test (Academy 27/10)

- **Código da Sessão:** P___ (ex.: P01)
- **Data e Horário:** 27/10/2026 às ___:___
- **Aparelho / Perfil Testado:** [ ] Aparelho A (Profissional)   [ ] Aparelho B (Contratante)
- **Facilitador(a):** [ ] Júlia   [ ] Fabrício   [ ] Outro membro do time: _____________

---

### 1. Observações da Navegação Livre (Primeiros 2m30s)
- **Primeiro elemento tocado na tela:** _____________________________________________
- **Hesitações visuais ou travamentos observados:** _________________________________
- **Expressões espontâneas / reações do participante:** ____________________________

---

### 2. Respostas às Perguntas Abertas de Saída

**Pergunta 1: Em suas palavras, o que este aplicativo faz?**
> Transcrição literal da fala do participante:
> _________________________________________________________________________________
> _________________________________________________________________________________

**Pergunta 2: Para quem você acha que este aplicativo foi feito?**
> Transcrição literal da fala do participante:
> _________________________________________________________________________________
> _________________________________________________________________________________

**Pergunta 3: Olhando para esta tela, o que você faria primeiro?**
> Transcrição literal da fala do participante:
> _________________________________________________________________________________
> _________________________________________________________________________________

**Pergunta 4: O que você entendeu sobre os horários e o valor exibidos aqui?**
> Transcrição literal da fala do participante:
> _________________________________________________________________________________
> _________________________________________________________________________________

**Pergunta 5: Teve alguma palavra, botão ou informação que pareceu confusa?**
> Transcrição literal da fala do participante:
> _________________________________________________________________________________
> _________________________________________________________________________________

---

### 3. Síntese do Facilitador
- **O participante compreendeu o conceito central em 5 min?** [ ] Sim   [ ] Parcial   [ ] Não
- **Termo específico que gerou dúvida (se houver):** _______________________________
- **Recomendação imediata de ajuste:** [ ] Ficha da Loja   [ ] Correção de UI (S3)   [ ] Nenhuma
```

### 4.3 Procedimento de Registro no Vault no Mesmo Dia (27/10)
Conforme o segundo critério de aceite do cartão `h1WOL50F` (*"Respostas registradas no vault no mesmo dia"*):
1. **Destino no Vault:** As notas individuais e a síntese consolidada das respostas devem ser salvas no vault do projeto na pasta:  
   `01 - CBL/Desafios/C18/Pesquisa/2026-10-27-Sintese-Five-Minutes-Test.md`
2. **Prazo estrito:** Conclusão do upload e consolidação das anotações até as 23:59 do próprio dia 27/10/2026.
3. **Estrutura da síntese no vault:**
   - Total de participantes atendidos (contagem de sessões realizadas).
   - Proporção de participantes que compreenderam o propósito de primeira (taxa de clareza imediata).
   - Lista consolidada de dúvidas recorrentes e termos que geraram hesitação.
   - Apontamento das ações necessárias para a Ficha da App Store e para o Sprint 3.

---

## 5. Como Transformar Respostas em Mudanças

Atendendo ao terceiro critério de aceite do cartão `h1WOL50F` (*"Mudanças decorrentes anotadas no cartão de correções do Sprint 3 ou, se forem da ficha, no cartão da ficha da App Store (Sprint 2)"*), o time deve aplicar a seguinte matriz de triagem objetiva para rotear os aprendizados colhidos:

```
                          [Resposta / Fricção Coletada]
                                        │
           ┌────────────────────────────┴────────────────────────────┐
           ▼                                                         ▼
[Problema de Primeira Impressão]                           [Problema de Navegação / UI]
(Participante não entendeu o que é,                         (Participante não sabe onde tocar,
para quem serve ou o modelo do app)                         botão confuso, termo ambíguo na tela)
           │                                                         │
           ▼                                                         ▼
[Ficha da App Store — Sprint 2]                            [Cartão de Correções — Sprint 3]
(Cartão PFWvegZa / FichaAppStore.md)                       (Cartão de Usabilidade S3)
```

### 5.1 O que vai à Ficha da App Store (Sprint 2 · Cartão PFWvegZa)
Se os participantes demonstrarem confusão conceitual sobre o propósito ou público do Frila, as mudanças devem ser direcionadas aos metadados da loja em `iOS/Docs/FichaAppStore.md` (Cartão Trello [PFWvegZa](https://trello.com/c/PFWvegZa)):

| Sintoma Observado no Five Minutes Test | Campo da Ficha a Ajustar | Ação Corretiva Concreta | Limite e Regra |
|---|---|---|---|
| Participante achou que o app é para contratação CLT fixa ou empregos de longo prazo. | **Subtítulo (*Subtitle*)** | Reforçar explicitamente o caráter de turnos pontuais e extras (ex.: refinar os 25 caracteres vigentes de `Turnos em bares e eventos`). | Máximo 30 caracteres (`FichaAppStore.md:12`). |
| Participante achou que o app cobra taxas/comissões abusivas do profissional. | **Texto Promocional (*Promotional Text*)** | Enfatizar no texto inicial que o valor é integral e sem descontos (RN01), pago direto pela casa. | Máximo 170 caracteres (`FichaAppStore.md:53`). |
| Participantes usaram termos espontâneos do setor não contemplados na indexação. | **Palavras-chave (*Keywords*)** | Adicionar os novos termos identificados (ex.: termos regionais de alimentação do DF) na lista de keywords. | Máximo 100 caracteres / 100 bytes (`FichaAppStore.md:42`). |
| Participante não compreendeu quem pode publicar ou quem pode trabalhar. | **Descrição Completa (*Description*)** | Ajustar os tópicos em destaque nas seções *"SE VOCÊ É UM ESTABELECIMENTO"* e *"SE VOCÊ É UM PROFISSIONAL"*. | Máximo 4.000 caracteres (`FichaAppStore.md:57`). |
| Participante não entendeu o fluxo visual pelas imagens da tela. | **Frases das Capturas (*Screenshots*)** | Revisar as legendas informativas sobrepostas aos prints da loja para destacar a ação central de cada tela. | Pendência sob responsabilidade de Fabrício e Júlia até 29/10 (`FichaAppStore.md:201`). |

### 5.2 O que vai ao Cartão de Correções do Sprint 3 (S3 · Usabilidade e Ajustes de Código)
Se os participantes entenderem o conceito geral, mas travarem na operação prática da interface ou hesitarem diante de elementos visuais, os apontamentos devem ser cadastrados no cartão de correções do Sprint 3:

| Sintoma Observado no Five Minutes Test | Componente / Arquivo Afetado | Ação Corretiva no Código iOS | Rastreabilidade no Guia de Voz |
|---|---|---|---|
| Participante não soube como se candidatar ou não viu o botão de candidatura. | `DetalheVagaView.swift` | Aumentar o destaque visual do botão primário de ação (`"Candidatar-me"`), posicionamento fixo na base da tela (*sticky footer*). | `GuiaDeVoz.md:36` (Rótulos com verbos explícitos). |
| Confusão sobre horários de turnos que terminam na madrugada do dia seguinte. | `DetalheVagaView.swift` e cartões de lista | Reforçar a indicação textual de turnos noturnos (`"das 18:00 às 02:00 (dia seguinte)"` ou `"sex 18:00 – sáb 02:00"`). | `GuiaDeVoz.md:137-145` (Turnos que cruzam a meia-noite). |
| Dúvida sobre o valor financeiro exibido na vaga (se tem desconto ou taxa oculta). | `CartaoVagaView.swift` e `DetalheVagaView.swift` | Inserir ou destacar o texto de garantia de transparência: *"O valor é integral: o Frila não desconta do valor pago pelo turno"* (RN01). | `GuiaDeVoz.md:308-310` (Valor integral sem descontos). |
| Termo da interface que causou estranheza ou incompreensão. | `Localizable.xcstrings` | Ajustar a redação da string no catálogo e padronizar o termo estritamente no vocabulário oficial, descartando sinônimos ambíguos. | `GuiaDeVoz.md:44-72` (Glossário oficial de termos). |
| Participante hesitou na tela de publicação entre Modo Urgência e Modo Seleção. | `PublicarVaga.swift` | Refinar o texto explicativo auxiliar abaixo do seletor de modo, deixando evidente a regra de antecedência de 24h (`RN24`). | `GuiaDeVoz.md:62-63` (Modo urgência vs seleção). |

### 5.3 Procedimento Operacional de Triagem pós-Academy
1. **Reunião de Triagem Expressa (30 min):** Realizada por Júlia, Fabrício e o time técnico no próprio dia 27/10 ou na manhã de 28/10.
2. **Classificação de Severidade:** Cada apontamento classificado segundo a matriz de severidade de `iOS/Docs/TriagemUsabilidadeERegressao.md:11-16` (Bloqueante, Grave, Médio ou Baixo).
3. **Abertura de Tarefas:**
   - Itens de metadados: atualização direta em `FichaAppStore.md` e comentário de registro no cartão `PFWvegZa` (S2).
   - Itens de código e interface: criação de cartões ou checklist no cartão consolidado de correções do Sprint 3 (S3).

---

## 6. Pendências e Responsabilidades (Em Aberto)

Os itens abaixo dependem de validação e execução presencial por pessoas específicas e permanecem sob responsabilidade de seus respectivos titulares:

| Pendência | Responsável | Ação Necessária | Prazo |
|---|---|---|:---:|
| **Aprovação do Roteiro e Folha de Resposta** | Júlia e Fabrício | Revisão final e aprovação formal do roteiro de 5 minutos, das 5 perguntas abertas e do formato da folha de resposta. | 26/10 |
| **Preparação e Teste dos Aparelhos Físicos** | Fabrício e time | Execução completa do checklist de véspera nos dois iPhones (build TestFlight, contas demo, rede, bateria e modo de foco). | 26/10 |
| **Condução das Sessões Presenciais** | Júlia e Fabrício (com o time) | Aplicação do roteiro com participantes externos na atividade da Academy. | 27/10 |
| **Registro das Respostas no Vault** | Júlia e Fabrício | Consolidação das anotações e upload da síntese no diretório do vault (`01 - CBL/Desafios/C18/Pesquisa/`). | 27/10 |
| **Triagem e Anotação nos Cartões do S2 e S3** | Júlia e Fabrício (com o time) | Distribuição das mudanças decorrentes entre o cartão da Ficha da App Store (S2 / `PFWvegZa`) e o cartão de correções do Sprint 3. | 28/10 |

---

## Histórico de Alterações

| Data | Autor | Alteração |
|---|---|---|
| 2026-10-12 | Doutor Estranho | Elaboração do documento completo de preparo do GA Five Minutes Test da Academy de 27/10: checklist de véspera dos aparelhos, roteiro de 5 minutos (o que mostrar, o que não explicar e 5 perguntas abertas), folha de resposta anônima em conformidade com a LGPD, matriz de desdobramento de mudanças (Ficha da App Store S2 vs Correções S3) e mapeamento de pendências (cartão h1WOL50F, T-0018). |
