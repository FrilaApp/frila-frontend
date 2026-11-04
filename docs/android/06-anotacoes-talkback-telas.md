# 06 — Anotações de TalkBack e Semântica Android (v1.1)

**Status:** Normativo · **Cartão Trello:** `Q84ogJUr` · **Requisitos:** B03, RNF10 (Acessibilidade)  
**Telas Mapeadas:** Entrada, Cadastro e Feed / Lista de Vagas  

Este documento define formalmente os frames, nós semânticos, traits de navegação e anúncios do TalkBack
para as três telas fundamentais do aplicativo Android no Material 3 Compose, assegurando paridade com o
VoiceOver do iOS e conformidade com WCAG 2.1 AA.

---

## 1. Princípios Gerais de Acessibilidade no Android

1. **Alvo Interativo Mínimo (Touch Target):** Mínimo de 48dp x 48dp em todos os botões, ícones acionáveis,
   chips e campos de texto (`minimumInteractiveComponentSize` do Material 3).
2. **Supressão de Ruído:** Elementos decorativos (linhas divisórias, ilustrações vazias de apoio, ossos
   individuais de skeleton) utilizam `clearAndSetSemantics {}` para não poluir a leitura do TalkBack.
3. **Cabeçalhos Estruturais:** Todo título de seção possui `semantics { heading() }` para permitir
   que usuários naveguem diretamente pelo rotor de navegação por cabeçalhos do TalkBack.
4. **Anúncios Dinâmicos:** Erros de validação e avisos críticos usam `liveRegion = LiveRegionMode.Assertive`;
   mudanças assíncronas suaves utilizam `LiveRegionMode.Polite`.

---

## 2. Tela 1: Entrada (Autenticação sem Senha)

A tela de Entrada recebe o e-mail do profissional ou contratante e solicita o código de acesso temporário.

```
+--------------------------------------------------+
|  [Logo Frila] (clearAndSetSemantics)             |
|                                                  |
|  Entrar no Frila (heading)                       |
|  Informe seu e-mail para receber o código        |
|                                                  |
|  +--------------------------------------------+  |
|  | E-mail (TextField)                         |  |
|  | label: "Seu e-mail"                        |  |
|  | hint: "exemplo@dominio.com"                |  |
|  +--------------------------------------------+  |
|                                                  |
|  +--------------------------------------------+  |
|  | [ Receber código de acesso ] (Button, 48dp)|  |
|  +--------------------------------------------+  |
|                                                  |
|  Ajuda ou problemas com acesso (Link, 48dp)      |
+--------------------------------------------------+
```

### Árvore Semântica do TalkBack (Entrada):
1. **Logo / Ilustração:** `clearAndSetSemantics {}` (Oculto ao TalkBack).
2. **Título Principal:**
   - Texto: `"Entrar no Frila"`
   - Semântica: `heading()`
   - Anúncio: *"Entrar no Frila, cabeçalho."*
3. **Subtítulo / Orientação:**
   - Texto: `"Informe seu e-mail para receber o código"`
   - Anúncio: Leitura de texto informativo.
4. **Campo de E-mail (`OutlinedTextField`):**
   - Label: `"E-mail"`
   - ContentDescription: `"Digite seu e-mail"`
   - Trait: Campo de edição de texto.
   - Anúncio com foco: *"E-mail, caixa de edição, Digite seu e-mail, toque duas vezes para editar."*
   - Estado de erro: `liveRegion = LiveRegionMode.Assertive` -> *"E-mail inválido, por favor confira o endereço digitado."*
5. **Botão de Ação Primária:**
   - Label: `"Receber código de acesso"`
   - Role: `Role.Button`
   - Dimensão física: Altura 52dp (alvo mínimo >= 48dp garantido).
   - Estado desabilitado (campo vazio): *"Receber código de acesso, botão desativado."*
   - Estado ativo: *"Receber código de acesso, botão, toque duas vezes para ativar."*
6. **Link Secundário de Suporte:**
   - Label: `"Ajuda ou problemas com acesso"`
   - Role: `Role.Button`
   - Padding tátil: 48dp x 48dp.

---

## 3. Tela 2: Cadastro (Perfil Inicial)

A tela de cadastro recolhe os dados essenciais para habilitação do profissional ou estabelecimento.

```
+--------------------------------------------------+
|  <- Voltar (IconButton, 48dp)                    |
|                                                  |
|  Criar sua conta (heading)                       |
|                                                  |
|  --- Seção: Seus Dados (heading) --------------- |
|  [ Nome Completo * (TextField) ]                 |
|  [ Telefone com DDD * (TextField) ]              |
|  [ CPF ou CNPJ * (TextField) ]                   |
|                                                  |
|  --- Seção: Termos Legais (heading) ------------ |
|  [X] Li e aceito os Termos de Uso (Checkbox, 48dp)|
|  [X] Li a Política de Privacidade (Checkbox, 48dp)|
|                                                  |
|  +--------------------------------------------+  |
|  | [ Continuar Cadastro ] (Button, 52dp)      |  |
|  +--------------------------------------------+  |
+--------------------------------------------------+
```

### Árvore Semântica do TalkBack (Cadastro):
1. **Botão Navegar para Cima (Voltar):**
   - `contentDescription = "Voltar"`
   - `Role.Button`, 48dp x 48dp.
   - Anúncio: *"Voltar, botão."*
2. **Título de Seção 1:**
   - Texto: `"Seus Dados"`
   - Semântica: `heading()`
   - Anúncio: *"Seus Dados, cabeçalho."*
3. **Campos Obrigatórios:**
   - Cada campo declara explicitamente a obrigatoriedade no anúncio acessível (`"Nome completo, obrigatório, caixa de edição"`).
   - Validações de máscara (Telefone e CPF/CNPJ) anunciam caracteres digitados sem quebras abruptas de foco.
4. **Checkboxes de Termos Legais:**
   - `Role.Checkbox` com área de clique englobando o texto adjacente (largura total da linha, altura >= 48dp).
   - Anúncio do estado:
     - Não marcado: *"Li e aceito os Termos de Uso, caixa de seleção desmarcada, toque duas vezes para alternar."*
     - Marcado: *"Li e aceito os Termos de Uso, caixa de seleção marcada."*
5. **Botão Continuar:**
   - Role: `Role.Button`.
   - Se os termos não estiverem checados: desabilitado com anúncio de motivo via `semantics { disabled() }`.

---

## 4. Tela 3: Feed / Lista de Vagas Abertas

A tela central onde profissionais visualizam oportunidades disponíveis e aplicam filtros.

```
+--------------------------------------------------+
|  Vagas Abertas (heading)        [Filtro] (Button)|
|                                                  |
|  (Chips de Categoria - LazyRow, 48dp cada)       |
|  [ Todos (sel) ] [ Cozinha ] [ Salão ] [ Bar ]   |
|                                                  |
|  +--------------------------------------------+  |
|  | Cartão de Vaga (Card unificado)            |  |
|  | Garçom / Garçonete · R$ 180                |  |
|  | Bar do Lago · Sexta 18:00 às 00:00         |  |
|  | Asa Sul (5,2 km)                           |  |
|  +--------------------------------------------+  |
|                                                  |
|  (Estado Vazio se não houver vagas)              |
|  "Nenhuma vaga nesta categoria no momento"       |
+--------------------------------------------------+
```

### Árvore Semântica do TalkBack (Feed de Vagas):
1. **Cabeçalho Principal:**
   - Texto: `"Vagas Abertas"` com `heading()`.
   - Botão de Filtro Avançado: `contentDescription = "Abrir filtros de vagas"`, `Role.Button`, 48dp.
2. **Chips de Filtro de Categoria (`LazyRow`):**
   - Cada chip declara seu estado de seleção semântico:
     - Chip ativo: `selected = true` -> *"Todos, selecionado, guia 1 de 6."*
     - Chip inativo: `selected = false` -> *"Cozinha, não selecionado, guia 2 de 6, toque duas vezes para selecionar."*
3. **Cartão de Vaga (`FrilaCartaoVaga`):**
   - **Regra Crítica:** O cartão inteiro é agrupado em um único nó de acessibilidade com `semantics(mergeDescendants = true) {}`.
   - Isso evita que o TalkBack faça 6 focos separados (título, preço, local, horário, distância, botão).
   - Anúncio consolidado:
     *"Vaga para Garçom ou Garçonete, remuneração cento e oitenta reais, Bar do Lago, Sexta-feira das 18h às 00h, Asa Sul a cinco vírgula dois quilômetros. Toque duas vezes para ver detalhes da vaga."*
4. **Estado de Carregamento (Skeleton Shimmer):**
   - O grupo de esqueletos usa `clearAndSetSemantics { contentDescription = "Carregando vagas disponíveis..." }`.
   - O TalkBack anuncia apenas uma vez o carregamento, suprimindo o anúncio redundante dos ossos individuais (regra comprovada em `FeedbackEmptyStateTest.kt`).
5. **Estado Vazio (Empty State):**
   - Ilustração oculta (`clearAndSetSemantics`).
   - Título e mensagem com anúncio de LiveRegion Polite: *"Nenhuma vaga encontrada para os filtros selecionados."*
   - Botão: `"Limpar filtros"`, 48dp.
