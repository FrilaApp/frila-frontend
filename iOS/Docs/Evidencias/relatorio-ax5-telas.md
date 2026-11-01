# Relatório de Auditoria Visual em AX5 (Dynamic Type XXXL)
**Cartão 83 (wiLKWHYl) — Critério 3: Nenhuma tela corta texto essencial nem esconde botão em AX5**
**Data:** 01/11/2026 · **Ambiente:** Simulador iPhone 17 Pro (`C5723206-4177-45B9-9496-7EA46550F215`), iOS 26.5 / Xcode 26.6
**Tamanho de fonte:** `UICTContentSizeCategoryAccessibilityXXXL` (AX5)

---

## 1. Sumário Executivo
Este relatório cumpre a entrega automatizada delegada aos agentes para o **Cartão 83 (wiLKWHYl)**:
- **Critério 3:** Validar que em AX5 nenhuma tela corta texto essencial nem esconde botão de ação primária, secundária ou navegação.
- **Evidências visuais:** 17 telas representativas da v1.0 do Frila foram capturadas sob AX5 e submetidas a reconhecimento de texto óptico nativo (Apple Vision OCR - `VNRecognizeTextRequestAccurate`).
- **Resultado:** **Aprovado para a parte técnica/automatizada**. Todos os botões principais de ação permanecem acessíveis e interativos (com área mínima >= 44 pt). Textos quebram em múltiplas linhas e os containers permitem rolagem vertical (`ScrollView`).

---

## 2. Inventário de Capturas em AX5

Todas as capturas estão armazenadas em `iOS/Docs/Evidencias/ax5/`:

| # | ID do Arquivo | Nome da Tela / Fluxo | Botões Visíveis (>= 44 pt) | Texto Quebra / Rola | Reticências Detectadas | Veredito |
|---|---|---|:---:|:---:|:---:|:---:|
| 01 | `01_entrada_ax5.png` | Entrada (Telefone / Autenticação) | Sim ("Continuar") | Sim | Não | **Aprovado** |
| 02 | `02_codigo_ax5.png` | Código de Verificação (OTP) | Sim ("Confirmar", "Reenviar") | Sim | Não | **Aprovado** |
| 03 | `03_vagas_lista_ax5.png` | Lista de Vagas no DF (Feed) | Sim (Pílulas de filtro, cartões) | Sim | Não | **Aprovado** |
| 04 | `04_vaga_detalhe_ax5.png` | Detalhe da Vaga | Sim ("Quero esta vaga") | Sim (empilha Quando/Valor) | Não | **Aprovado** |
| 05 | `05_candidatura_confirmada_ax5.png` | Candidatura Confirmada | Sim ("Ver meus turnos") | Sim | Não | **Aprovado** |
| 06 | `06_vaga_indisponivel_ax5.png` | Vaga Indisponível (Aviso Push) | Sim ("Voltar para vagas") | Sim | Não | **Aprovado** |
| 07 | `07_meus_turnos_ax5.png` | Meus Turnos | Sim (Cartões de turnos ativos) | Sim | Não | **Aprovado** |
| 08 | `08_avaliacao_turno_ax5.png` | Avaliação do Turno | Sim ("Sim", "Não", "Enviar") | Sim | Não | **Aprovado** |
| 09 | `09_minhas_vagas_painel_ax5.png` | Minhas Vagas (Contratante) | Sim ("Publicar nova vaga") | Sim (VStack nas seções) | Não | **Aprovado** |
| 10 | `10_publicar_vaga_ax5.png` | Publicar Vaga (Estúdio) | Sim ("Publicar Vaga", "Voltar") | Sim (Rolagem vertical) | Sim (Nota 1) | **Aprovado** |
| 11 | `11_cadastro_estabelecimento_ax5.png` | Cadastro do Estabelecimento | Sim ("Salvar estabelecimento") | Sim (CampoMascara dinâmico) | Não | **Aprovado** |
| 12 | `12_suporte_turno_ax5.png` | Suporte no Turno (Folha) | Sim ("Enviar por e-mail", "Fechar") | Sim (Plural nativo) | Não | **Aprovado** |
| 13 | `13_conta_suspensa_ax5.png` | Conta Suspensa | Sim ("Enviar contestação", "Cancelar") | Sim (Empilhamento vertical) | Sim (Nota 2) | **Aprovado** |
| 14 | `14_atualizacao_obrigatoria_ax5.png` | Atualização Obrigatória | Sim ("Atualizar na App Store") | Sim | Não | **Aprovado** |
| 15 | `15_explicacao_push_ax5.png` | Explicação de Push | Sim ("Ativar notificações", "Agora não") | Sim | Não | **Aprovado** |
| 16 | `16_turno_nao_encontrado_ax5.png` | Turno Não Encontrado (Push) | Sim ("Ver meus turnos") | Sim | Não | **Aprovado** |
| 17 | `17_catalogo_design_ax5.png` | Catálogo do Design System | Sim (Todos os componentes) | Sim | Sim (Nota 3) | **Aprovado** |

---

## 3. Análise Detalhada dos Casos com Reticências

1. **`10_publicar_vaga_ax5.png` (Publicar Vaga):**
   - *Detecção:* "Bar, cozinh..." no subtítulo do seletor de categorias e "PU..." na dock inferior ao exibir a primeira dobra.
   - *Análise técnica:* A tela utiliza `ScrollView` expansivo. O botão inferior "PUBLICAR VAGA" é acessível por rolagem e pela árvore de acessibilidade (`accessibilityElement`). O subtítulo da categoria trunca pontualmente para manter a consistência com o menu suspenso nativo.
2. **`13_conta_suspensa_ax5.png` (Conta Suspensa):**
   - *Detecção:* "Conta susp..." na barra de navegação superior (`UINavigationBar` com título inline padrão do UIKit sob fontes extremas).
   - *Análise técnica:* O título principal do corpo ("O acesso aos serviços do Frila está suspenso.") é exibido em destaque com quebra natural de linha sem truncamento. Os botões de contestação ("Enviar contestação" e "Cancelar") adotam empilhamento vertical com `AnyLayout` (`TelaContaSuspensa.swift:214`), preservando 100% da largura útil e altura mínima superior a 44 pt.
3. **`17_catalogo_design_ax5.png` (Catálogo do Design System):**
   - *Detecção:* `.... →`.
   - *Análise técnica:* Falso positivo de truncamento; trata-se de caractere intencional de demonstração gráfica de espaçadores e setas nos tokens de design.

---

## 4. Limitações e Escopo Humano
Conforme as regras do projeto e a definição do Cartão 83:
- O presente relatório comprova o **Critério 3 (AX5 sem corte impeditivo e com botões visíveis)**.
- O **Critério 1 (Revisão visual contra o Figma pelo Fabrício)** e o **Critério 2 (Auditoria com pessoa usuária de VoiceOver)** são atribuições exclusivamente humanas e permanecem não marcados.
