# Classificação 18+ — ECA Digital, Portaria 1.048 e Declared Age Range

Documento do cartão [lJSyGK6q](https://trello.com/c/lJSyGK6q) (Maioridade: classificação 18+,
ECA Digital e Declared Age Range). Versão de 15/10/2026, a partir do parecer de maioridade do
Nick Fury, por delegação do Cauê (responsável pessoa física, sem CNPJ). Substitui o rascunho de
11/10/2026, que esperava parecer dos mentores: a decisão foi delegada e está tomada.

> Parecer técnico, não peça de advogado. O ponto de maior incerteza está na seção 3.2.

---

## 1. Decisão

1. **Classificação 18+** na App Store, com *Override to Higher Age Rating* no questionário.
   No Brasil, a App Store Connect mostra **A18** (conferido em 15/10/2026).
2. **Aferição de idade em camadas, sem pedir documento na v1.0** (RN14 mantida):

   | Camada | O que faz | Onde |
   |---|---|---|
   | 1. App Store | Desde 24/02/2026, bloqueia no Brasil o download de app 18+ por quem não foi confirmado adulto. | Apple |
   | 2. Declared Age Range | Em iOS 26.2 ou mais novo, consulta a faixa etária do aparelho no cadastro. `.abaixoDe18` bloqueia. | `iOS/Sources/Infraestrutura/VerificadorDeIdadeDoSistema.swift` |
   | 3. Data de nascimento | Menos de 18 anos é recusado no app e no servidor (`422 menor_de_idade`, CHECK no banco). No app, a idade é calculada da data digitada (`dd/mm/aaaa`); menor de 18 vê a mensagem inline "O Frila é exclusivo para maiores de 18 anos." e o botão Continuar fica bloqueado. Nascido em 29 de fevereiro cujo 18º aniversário cai em ano não bissexto completa a maioridade em 1º de março (regra conservadora). | `CadastroViewModel.swift`; RPC `criar_conta` (RN20) |
   | 4. Termos | Aceite dos termos (com a classificação indicativa e a declaração de maioridade na seção 3). Não há caixa de seleção separada "Tenho 18 anos ou mais": a autodeclaração registrada é a data de nascimento calculada + o aceite dos Termos (Lei 15.211/2025). | `TelaCadastro.swift`; `PaginaPublica/termos.md`, seção 3 |

3. **Divergência:** se o aparelho disser menor e a data disser adulto, vale a mais protetiva e o
   cadastro é bloqueado (Decreto 12.880, art. 25 §4º). Teste:
   `MaioridadeEVerificacaoDeIdadeTests.swift`.
4. **Falha aberta na v1.0:** `.recusou` e `.indisponivel` não bloqueiam; valem a data e a
   declaração. Motivos: quem recusa compartilhar não é, por isso, menor; a camada 1 já bloqueia o
   download; a Declared Age Range não existe em iOS 17 a 26.1 (alvo mínimo do app é iOS 17.0);
   há relatos (fórum, não oficiais) de `isEligibleForAgeFeatures` falso no Brasil. Se a ANPD ou a
   Apple definirem padrão mais rígido, passa a falha fechada, com meio de contestar.
5. **Risco residual aceito:** as camadas 3 e 4 são autodeclaração, que a ANPD chama de baixa
   confiabilidade. Documento, selfie ou prova de vida própria ficam fora da v1.0 e só entram por
   gatilho (seção 6).

---

## 2. O que a lei pede e como o Frila atende

### 2.1 Por que 18+

O que a lei veda a menores é o trabalho, não o app:

| Norma | Disposição |
|---|---|
| CF/88, art. 7º, XXXIII | Proíbe trabalho noturno, perigoso ou insalubre a menores de 18 anos. |
| CLT, art. 404 | Proíbe ao menor de 18 anos o trabalho noturno (22h às 5h). |
| CLT, art. 405, §3º, "d" | Proíbe ao menor a venda a varejo de bebidas alcoólicas. |
| ECA, art. 67 | Veda ao adolescente trabalho noturno, perigoso, insalubre ou penoso. |
| ECA, art. 243 | Veda servir bebida alcoólica a criança ou adolescente. |
| Decreto 6.481/2008 | Lista das piores formas de trabalho infantil. |

Bar, restaurante noturno e evento são o centro do Frila. Por isso a regra é 18+ (RN20).

### 2.2 Portaria MJSP nº 1.048/2025 (classificação indicativa de aplicativos)

| Artigo | Exige | Como o Frila atende |
|---|---|---|
| Art. 45 e 48 | App em loja é autoclassificado pelo questionário da loja (IARC); vale também para quem apresenta serviços ofertados por usuários (art. 48, III). | Questionário de Age Rating com override 18+ (`FichaAppStore.md`, seção 4). |
| Art. 50 | Mostrar a indicação etária nas páginas de instalação, login e inicialização. | Instalação: a App Store mostra. Login: a tela de entrada mostra "Classificação indicativa: 18 anos" (`TelaEntrada.swift`, identificador `entrada-classificacao-indicativa`, teste de UI `testEntradaMostraAClassificacaoIndicativaDe18Anos`). Inicialização: veja a nota abaixo. |
| Art. 55 | Os termos de uso informam a indicação etária. | `PaginaPublica/termos.md`, seção 3 (versão dos termos 2026-10-15). |
| Art. 57 | A classificação final considera ferramentas de aferição de idade e políticas que proíbam menores. | Camadas da seção 1. |

> **Nota sobre a inicialização:** a abertura do Frila (`EstadoCarregando`, em `FrilaApp.swift`) é
> uma tela de carregamento curta que leva direto à tela de entrada, onde a classificação aparece.
> Decidimos não colocar o aviso nela: ninguém conseguiria ler, e a tela de entrada cumpre o
> objetivo. Se o MJSP ou a revisão da Apple pedirem, o mesmo texto entra ali.
> Sem a arte oficial do símbolo A18, usamos texto.

### 2.3 Lei nº 15.211/2025 (ECA Digital) e Decreto nº 12.880/2026

Em vigor desde 17/03/2026. A fiscalização é da ANPD.

| Ponto | Exige | Situação |
|---|---|---|
| Lei, art. 9º | Impedir o acesso de menores a serviço impróprio, inadequado ou proibido, por meio eficaz; §1º veda a autodeclaração. | Camadas 1 e 2 não são autodeclaração; camadas 3 e 4 são. Risco aceito (seção 1, item 5). |
| Lei, art. 14; Decreto, art. 26 §3º | O fornecedor recebe o sinal da loja e mantém mecanismos próprios; o sinal não o isenta. | Camadas 2 a 4. |
| Decreto, art. 12 §4º | Termos informam a classificação em português. | Termos, seção 3. |
| Decreto, art. 24 §3º | Guardar só a idade ou a faixa; não reutilizar para outra finalidade. | O app recebe só a faixa. O registro no servidor depende do backend ([cartão #268](https://trello.com/c/LQlwDaYZ)). |
| Decreto, art. 25 §4º | Na divergência com o sinal da loja, adotar a alternativa mais protetiva. | Seção 1, item 3. |
| Decreto, art. 27 | Meio de contestar a idade aferida. | Termos, seção 3: `suporte@frilabr.com`. |
| Lei, art. 35 | Sanções: advertência; multa de até 10% do faturamento ou, sem faturamento, de R$ 10 a R$ 1.000 por usuário, limitada a R$ 50 milhões por infração. | — |

"A cada acesso" (Lei, art. 9º §1º): conferir a idade em todo login é desproporcional, e a ANPD
recomenda evitar coleta repetida. A idade fica atrelada à conta, verificada no cadastro.

### 2.4 LGPD, art. 14

Como o Frila não admite menores, a obrigação vira impedir o cadastro, não colher consentimento
dos pais. Conta de menor descoberta depois é suspensa e apagada pelo fluxo de exclusão.

---

## 3. Questionário de Age Rating

### 3.1 Respostas

As respostas completas, com justificativa, estão em [`FichaAppStore.md`](FichaAppStore.md),
seção 4.1. Resumo:

- In-App Controls: Parental Controls **Não**; Age Assurance **Sim**.
- Capabilities: User-Generated Content **Sim**; Unrestricted Web, Social Media, Messaging e
  Advertising **Não**.
- Temas maduros, médicos, sexuais, violência e jogos de azar: **Nenhum** ou **Não**.
- Override to Higher Age Rating: **18+**. Age Suitability URL: em branco por ora.
- Faixa calculada 4+; final **18+**. A antiga faixa 17+ não existe mais (as atuais são 4+, 9+,
  13+, 16+ e 18+).

### 3.2 Dúvida de interpretação: "proibido" ou "impróprio"?

O Decreto chama de "proibido" o que a lei veda expressamente (art. 2º, II) e inclui "quaisquer
outros produtos ou serviços que tenham vedação legal" (art. 15 §1º, XI).

- **Leitura A (adotada como base):** o Frila é um serviço de TI 18+, "impróprio ou inadequado"
  (Decreto, art. 14). Basta autoclassificar, informar e usar o sinal da loja.
- **Leitura B:** como o trabalho é vedado ao menor, o serviço seria "proibido" e exigiria
  verificação de alto grau de confiabilidade (Decreto, art. 15).

Tratamos como 18+ e atendemos o possível da leitura B em camadas. Se a ANPD adotar a leitura B
para plataformas de trabalho, verificação por documento ou prova de vida passa a ser necessária.

---

## 4. Textos

### 4.1 Ficha da App Store

> O Frila é exclusivo para maiores de 18 anos. Ele conecta estabelecimentos a profissionais
> autônomos para turnos pagos, inclusive à noite e em locais com venda de bebida alcoólica.
> Menores de 18 anos não podem criar conta. Classificação indicativa: 18 anos.

### 4.2 Tela de entrada do app

> Classificação indicativa: 18 anos

### 4.3 Termos de uso

Texto em `PaginaPublica/termos.md`, seção 3 ("Classificação indicativa: 18 anos" e "Como a
idade é verificada").

### 4.4 Recrutamento do piloto

> O Frila é exclusivo para maiores de 18 anos. Menores de 18 anos não podem criar conta, aceitar
> turnos nem prestar serviços pelo Frila (Constituição, art. 7º, XXXIII; CLT, arts. 404 e 405;
> ECA, art. 67; Lei 15.211/2025). Se você tem menos de 18 anos e recebeu esta mensagem,
> desconsidere-a.

---

## 5. Checklist

| # | Requisito | Estado | Evidência |
|---|---|---|---|
| 1 | Questionário de Age Rating com override 18+ | Feito em 15/10/2026: salvo como rascunho, sem enviar; 18+ em 173 países ou regiões, A18 no Brasil, 19+ na Coreia do Sul | `FichaAppStore.md`, seção 4 |
| 2 | Declared Age Range no cadastro | Feito | `VerificadorDeIdadeDoSistema.swift` (cartão #215) |
| 3 | Data de nascimento conferida no app e no servidor | Feito | `CadastroViewModel.swift`; RPC `criar_conta` |
| 4 | Divergência bloqueia | Feito e testado | `MaioridadeEVerificacaoDeIdadeTests.swift` |
| 5 | Classificação na tela de entrada (Portaria, art. 50) | Feito e testado | `TelaEntrada.swift`; `FrilaUITests.swift` |
| 6 | Classificação e contestação nos termos (Portaria, art. 55; Decreto, arts. 12 e 27) | Feito | `termos.md`, seção 3; versão 2026-10-15 |
| 7 | Ficha da loja sem 17+ e com as respostas atuais | Feito | `FichaAppStore.md`, seção 4 |
| 8 | Servidor grava o resultado do sinal de idade, o método e a data do aceite 18+, guardando só a faixa | Com o backend ([cartão #268](https://trello.com/c/LQlwDaYZ)) | Hoje o servidor grava `nascimento`, `termos_versao` e `termos_aceite_em`. Se não sair até 06/11, o app vai sem esse registro; o risco é só de prova. |
| 9 | Página dos termos no ar para a Age Suitability URL | Depende da página pública | `frila.netlify.app/termos` |

---

## 6. Gatilhos para revisar

- Orientação definitiva da ANPD sobre mecanismos de aferição de idade.
- Ato da ANPD que inclua plataformas de trabalho ou intermediação na fiscalização.
- Regra da Apple sobre entitlement ou comportamento na recusa da Declared Age Range.
- Qualquer notificação, denúncia ou relato de menor no app.
- Pergunta ou recusa da revisão da Apple sobre idade.

---

## 7. Fontes (acesso em 15/10/2026)

| Norma ou documento | Link |
|---|---|
| Portaria MJSP 1.048/2025 | [gov.br/mj](https://www.gov.br/mj/pt-br/assuntos/seus-direitos/classificacao-1/legislacao/portaria-1048.pdf/view) |
| Lei 15.211/2025 (ECA Digital) | [planalto.gov.br](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2025/lei/L15211.htm) |
| Decreto 12.880/2026 | [planalto.gov.br](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2026/decreto/D12880.htm) |
| ANPD, orientações preliminares sobre aferição de idade (mar/2026) | [gov.br/anpd](https://www.gov.br/anpd/pt-br/assuntos/eca-digital/mecanismos-confiaveis-de-afericao-de-idade-orientacoes-preliminares.pdf) |
| Constituição Federal | [planalto.gov.br](https://www.planalto.gov.br/ccivil_03/constituicao/constituicao.htm) |
| CLT | [planalto.gov.br](https://www.planalto.gov.br/ccivil_03/decreto-lei/del5452.htm) |
| ECA — Lei 8.069/1990 | [planalto.gov.br](https://www.planalto.gov.br/ccivil_03/leis/l8069.htm) |
| LGPD — Lei 13.709/2018 | [planalto.gov.br](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm) |
| Decreto 6.481/2008 | [planalto.gov.br](https://www.planalto.gov.br/ccivil_03/_ato2007-2010/2008/decreto/d6481.htm) |
| Apple, exigências de idade no Brasil (24/02/2026) | [developer.apple.com](https://developer.apple.com/news/?id=f5zj08ey) |
| Apple, Age assurance | [developer.apple.com](https://developer.apple.com/support/age-assurance/) |
| Apple, valores do Age Rating | [developer.apple.com](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/) |
| Apple, como definir o Age Rating | [developer.apple.com](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/) |
| App Store Review Guidelines | [developer.apple.com](https://developer.apple.com/app-store/review/guidelines/) |
