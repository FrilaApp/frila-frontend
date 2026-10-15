# Classificação 18+ — Conformidade ECA Digital e Declared Age Range

> **⚠️ RASCUNHO — PENDENTE DE PARECER JURÍDICO**
> Este documento é um rascunho de síntese regulatória. Os textos normativos e a análise de
> conformidade aguardam validação pelo parecer formal dos mentores da Academy antes de serem
> adotados em comunicações oficiais.

Dossiê elaborado em 11/10/2026 na branch `docs/classificacao-18-eca` a partir de `origin/main`
para atender ao cartão do Trello [lJSyGK6q](https://trello.com/c/lJSyGK6q)
(S1 · Jurídico + iOS · Maioridade: classificação 18+, ECA Digital e Declared Age Range).

> **Escopo deste documento:** síntese regulatória e textos normativos de aviso de maioridade.
> A reunião e o registro do parecer formal com os mentores da Academy são responsabilidade do
> Cauê e ficam de fora deste dossiê.

---

## 1. Por que o Frila exige classificação 18+

O Frila é uma plataforma de contratação por turno avulso. A legislação trabalhista brasileira
impõe restrições rigorosas ao trabalho de menores de 18 anos:

| Norma | Disposição relevante |
|---|---|
| **CF/88, art. 7º, XXXIII** | Proíbe trabalho noturno (22 h–5 h), perigoso ou insalubre a menores de 18 anos; proíbe qualquer trabalho a menores de 16 anos, salvo como aprendiz a partir de 14 anos. |
| **CLT, arts. 402–441** | Regulamenta o trabalho do menor: jornada máxima de 6 h (aprendiz sem ensino fundamental), vedação de horas extras sem compensação, proibição de atividades prejudiciais à moralidade, obrigação de CTPS anotada. |
| **ECA (Lei 8.069/1990), arts. 60–69** | Reforça a proibição de trabalho penoso, noturno, insalubre ou perigoso a menores de 18 anos e vincula o trabalho ao processo educativo. |
| **Decreto 6.481/2008 (Lista TIP)** | Lista as "Piores Formas de Trabalho Infantil" — inclui tipos de turno avulso em atividades noturnas, rurais insalubres e domésticas. |

Como o Frila intermedia turnos avulsos que podem incluir trabalho noturno e atividades com
grau de risco variável, **a plataforma deve ser classificada como 18+** (equivalente a "17+"
na nomenclatura Apple anterior a 2025, ou "18+" na classificação granular atual).

---

## 2. Quadro normativo — Proteção digital de menores no Brasil

### 2.1. Lei 14.811/2024

Sancionada em janeiro de 2024, tipifica o cyberbullying (reclusão de 2–4 anos e multa) e inclui
no rol de crimes hediondos condutas graves contra menores no ambiente digital. Embora o foco
seja violência escolar e abuso sexual, estabelece o alicerce para a classificação indicativa
de aplicativos.

**Fonte:** [planalto.gov.br — L14811](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2024/lei/L14811.htm)

### 2.2. Lei 15.211/2025 ("ECA Digital")

Em vigor desde 17/03/2026 (vacância de 1 ano). Principais obrigações para plataformas:

| Obrigação | Impacto no Frila |
|---|---|
| **Fim da autodeclaração simples de idade** — a plataforma não pode depender apenas de uma caixa "tenho 18+" para liberar acesso. | O Frila deve adotar mecanismo confiável de aferição de idade (ver §4). |
| **Verificação proporcional e auditável** — dados coletados para aferição servem exclusivamente a essa finalidade. | Nenhum dado de verificação de idade pode ser reutilizado para marketing ou perfilagem. |
| **Proteção por padrão** — configurações de privacidade mais restritivas ativadas por padrão para menores. | Como o app é 18+, a abordagem é bloquear o acesso, não configurar um modo restrito. |
| **Contas de menores de 16 anos vinculadas a responsável legal** (ferramentas de supervisão). | Não se aplica: o Frila não cria contas para menores de 18 anos. |
| **Fiscalização pela ANPD** — fase incisiva a partir de janeiro/2027; multa de até 10% do faturamento ou R$ 50 milhões. | O piloto (Sprint 3) deve estar em conformidade antes dessa data. |

**Fonte:** [planalto.gov.br — L15211](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2025/lei/L15211.htm)

### 2.3. LGPD (Lei 13.709/2018), art. 14

Tratamento de dados de **crianças** (até 12 anos incompletos) exige consentimento específico e
em destaque de pelo menos um responsável. Para **adolescentes** (12–18 anos), deve seguir o
princípio do "melhor interesse". O controlador deve realizar "todos os esforços razoáveis" para
verificar o consentimento.

**Impacto no Frila:** como a plataforma não admite menores de 18 anos, a obrigação se traduz em
impedir o cadastro, e não em coletar consentimento parental. Caso um menor consiga se cadastrar
indevidamente, a limpeza de dados segue o fluxo de exclusão de conta
(ver `iOS/Docs/DiretrizesAppStore.md`, diretriz 5.1.1).

### 2.4. Portaria MJSP 1.048/2025 — Classificação indicativa para aplicativos

Estende a classificação indicativa (antes restrita a audiovisual) a aplicativos e jogos
eletrônicos. Introduz a faixa "não recomendado para menores de 6 anos" e avalia interatividade
(contato com adultos desconhecidos, compras, IA). Para o Frila, a classificação resultante é
**18+** por envolver contato direto com adultos desconhecidos e intermediação de trabalho.

**Fonte:** [gov.br/mj — Portaria 1.048](https://www.gov.br/mj/pt-br/assuntos/seus-direitos/classificacao-1/legislacao/portaria-1048.pdf/view)

---

## 3. Classificação na App Store — Declared Age Range

### 3.1. Classificação etária (Age Rating)

No App Store Connect, o questionário de classificação gera a nota etária do app. O Frila deve
responder que:

- **Permite interação entre usuários adultos desconhecidos** (contato com contratantes/profissionais).
- **Não é direcionado a crianças** (não pertence à categoria Kids).
- **Não contém conteúdo violento, sexual ou de drogas**, mas intermedia trabalho com risco variável.

**Resultado esperado:** classificação **17+** (nomenclatura clássica) ou **18+** (nomenclatura
granular de 2025).

### 3.2. Declared Age Range API

Desde iOS 18 / iPadOS 18 / macOS Sequoia, a Apple oferece a API `DeclaredAgeRange` que fornece
ao app uma faixa etária declarada pelo sistema (controlada por Family Sharing / Screen Time) sem
expor a data de nascimento do usuário.

**Recomendação para o Frila:**

1. Adotar `DeclaredAgeRange` como sinal primário de aferição de idade em dispositivos Apple.
   Se a faixa retornada indicar menor de 18 anos, impedir o cadastro.
2. Para usuários sem faixa declarada (dispositivos sem Family Sharing), manter um mecanismo
   complementar de autodeclaração **registrada** (data de nascimento informada e persistida,
   não uma caixa de seleção descartável), conforme exige a Lei 15.211/2025.
3. Registrar a autodeclaração em log auditável (timestamp, hash do dado, versão do app),
   sem armazenar a data de nascimento em texto aberto fora do perfil do usuário.

> **Pendência — parecer do Cauê:** confirmar com os mentores da Academy se a autodeclaração
> registrada (item 2) é suficiente enquanto a ANPD não regulamenta os mecanismos confiáveis
> de verificação, ou se será necessário integrar um provedor de verificação de identidade
> (ex.: documento com selfie, crédito bancário) antes do lançamento público.

---

## 4. Textos normativos de aviso de maioridade

Os textos abaixo devem ser usados nas comunicações de recrutamento do piloto e nos termos de
adesão. Estão redigidos em linguagem clara, conforme exige a LGPD (art. 14, §6º) e a Lei
15.211/2025.

### 4.1. Aviso para comunicações de recrutamento

> **Requisito de maioridade**
>
> O Frila é uma plataforma de intermediação de turnos avulsos de trabalho destinada
> exclusivamente a maiores de 18 (dezoito) anos. Ao se cadastrar, você declara ter completado
> 18 anos na data do cadastro.
>
> Menores de 18 anos não podem criar conta, aceitar turnos nem prestar serviços por meio do
> Frila, conforme a Constituição Federal (art. 7º, XXXIII), a CLT (arts. 402–441), o
> Estatuto da Criança e do Adolescente (Lei 8.069/1990, arts. 60–69) e a Lei 15.211/2025
> (ECA Digital).
>
> Se você tem menos de 18 anos e recebeu esta comunicação, desconsidere-a.

### 4.2. Cláusula para termos de adesão ao piloto

> **Cláusula — Declaração de Maioridade**
>
> O PARTICIPANTE declara, sob as penas da lei, que possui 18 (dezoito) anos completos ou
> mais na data de aceite destes Termos.
>
> O FRILA reserva-se o direito de, a qualquer momento, solicitar comprovação de idade e
> suspender ou encerrar a conta do PARTICIPANTE caso se verifique que a declaração é falsa,
> sem prejuízo das medidas legais cabíveis.
>
> Fundamentação legal: Constituição Federal, art. 7º, XXXIII; CLT, arts. 402–441; ECA,
> Lei 8.069/1990, arts. 60–69; ECA Digital, Lei 15.211/2025; LGPD, Lei 13.709/2018, art. 14.

### 4.3. Aviso na tela de cadastro do app (sugestão de texto para a UI)

> Para usar o Frila, você precisa ter 18 anos ou mais. Ao continuar, você declara ter
> completado 18 anos.

---

## 5. Checklist de conformidade

| # | Requisito | Estado | Responsável / Evidência no Código |
|---|---|---|---|
| 1 | Classificação 18+ no App Store Connect (questionário de Age Rating) | **Pendente** | Cauê (ao submeter na loja) |
| 2 | Adoção da API `DeclaredAgeRange` para aferição de idade em iOS | **Conforme** | `iOS/Sources/Infraestrutura/VerificadorDeIdadeDoSistema.swift:31–59` |
| 3 | Mecanismo complementar de autodeclaração registrada (data de nascimento) | **Conforme** | `iOS/Sources/Apresentacao/Fluxos/Autenticacao/CadastroViewModel.swift:72–78` |
| 4 | Aviso de maioridade nas comunicações de recrutamento do piloto (§4.1) | **Pendente** | Cauê / Marketing |
| 5 | Cláusula de maioridade nos termos de adesão ao piloto (§4.2) | **Pendente** | Cauê / Jurídico |
| 6 | Aviso de maioridade na tela de cadastro do app (§4.3) | **Conforme** | `iOS/Sources/Apresentacao/Fluxos/Autenticacao/TelaCadastro.swift:106–130` |
| 7 | Parecer dos mentores da Academy sobre suficiência da autodeclaração registrada | **Pendente** | Cauê / João Paulo (registrado em `DECISOES.md`) |
| 8 | Log auditável da declaração de idade (timestamp, hash, versão) | **Conforme** | `CadastroConta.swift` e RPC de criação no Supabase |

---

## 6. Referências

| Norma / Documento | Link |
|---|---|
| Constituição Federal, art. 7º, XXXIII | [planalto.gov.br](https://www.planalto.gov.br/ccivil_03/constituicao/constituicao.htm) |
| CLT, arts. 402–441 | [planalto.gov.br](https://www.planalto.gov.br/ccivil_03/decreto-lei/del5452.htm) |
| ECA — Lei 8.069/1990 | [planalto.gov.br](https://www.planalto.gov.br/ccivil_03/leis/l8069.htm) |
| Lei 14.811/2024 | [planalto.gov.br](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2024/lei/L14811.htm) |
| Lei 15.211/2025 (ECA Digital) | [planalto.gov.br](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2025/lei/L15211.htm) |
| LGPD — Lei 13.709/2018 | [planalto.gov.br](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm) |
| Decreto 6.481/2008 (Lista TIP) | [planalto.gov.br](https://www.planalto.gov.br/ccivil_03/_ato2007-2010/2008/decreto/d6481.htm) |
| Portaria MJSP 1.048/2025 (Classificação Indicativa) | [gov.br/mj](https://www.gov.br/mj/pt-br/assuntos/seus-direitos/classificacao-1/legislacao/portaria-1048.pdf/view) |
| Apple — Age Ratings | [developer.apple.com](https://developer.apple.com/help/app-store-connect/reference/age-ratings/) |
| Apple — Declared Age Range | [developer.apple.com](https://developer.apple.com/documentation/deviceactivity/declaredagerange) |
| App Store Review Guidelines | [developer.apple.com](https://developer.apple.com/app-store/review/guidelines/) |
