# DESIGN.md: linguagem visual do Frila (MidFi → SwiftUI)

Fonte única de decisões visuais para as telas do primeiro TestFlight com o design do Fabrício. A referência é o protótipo MidFi (`FrilaLowPhase/docs/prototype/midfi/project/*.dc.html`). As regras de código ficam em [`../GuiaDoFabricio.md`](../GuiaDoFabricio.md), e os fluxos e estados de cada tela em [`FLUXOS.md`](FLUXOS.md).

Quando o quadro e este documento divergirem, vale este documento. Se faltar regra, quem decide é o design (Claude, depois Codex). Quem implementa não decide.

## 1. Princípios
1. **Monocromático.** Quase preto sobre cinza quente, com superfícies brancas. Não há cor de marca em fundo, botão ou texto. A terracota (`FrilaCor.marca`) não aparece nestas telas.
2. **Um CTA por tela**, preto, em pílula, na barra inferior fixa. Ações secundárias são pílula branca com contorno ou texto simples.
3. **Título grande à esquerda** abre toda tela de primeiro nível. O conteúdo se agrupa em cartões brancos, sem sombra.
4. **Estado é texto, não cor.** Erro e alerta usam ícone, peso e contorno preto de 2 pt, nunca vermelho. O vermelho (`FrilaCor.perigo`) fica só para ação destrutiva.
5. **Densidade calma.** Margem lateral de 16, respiro de 24 a 32 entre blocos, nada encostado.

## 2. Tokens (já existem em `DesignTokens.swift` e `DesignSystem.xcassets`)
| Papel | MidFi | Token |
|---|---|---|
| Fundo da tela | `#F2F2F0` | `FrilaCor.fundo` |
| Cartão, campo, linha | `#FFFFFF` | `FrilaCor.superficie` |
| Texto principal, CTA | `#111110` | `FrilaCor.texto`, `FrilaCor.primaria` |
| Texto de apoio | `#5C5B57` | `FrilaCor.textoSecundario` (**ajustar o asset para #5C5B57**, hoje está #6B6A66) |
| Aviso neutro, chip, botão desabilitado | `#E8E7E3` | `FrilaCor.controle` |
| Contorno de campo e chip | `rgba(0,0,0,.14)` | `FrilaCor.borda` |
| Fio entre linhas | `rgba(0,0,0,.08)` | `FrilaCor.divisoria` |

Espaços: 4, 8, 12, 16, 24 e 32 (`FrilaEspaco`). Raios: campo e aviso 16 (`FrilaRaio.aviso`), cartão 20 (`FrilaRaio.grande`), folha 28.

## 3. Tipografia (SF Pro, estilos do sistema)
| Uso | MidFi | Token |
|---|---|---|
| Título de tela | 28–34 bold | `FrilaTipo.tituloGrande` |
| Subtítulo da tela | 17–20 regular, cor de apoio | `FrilaTipo.subtituloDaTela` |
| Cabeçalho de seção ("Abertas", "Seus dados") | 22 bold | `.title2.bold()`, novo token `FrilaTipo.secao` |
| Microrrótulo ("FUNÇÕES", "DETALHES PUBLICADOS") | 13 semibold, caixa alta, cor de apoio | `FrilaTipo.microRotulo` + `.textCase(.uppercase)` |
| Rótulo de campo | 15 semibold | `FrilaTipo.meta.weight(.semibold)` |
| Valor de campo, linha de lista | 17 | `FrilaTipo.corpo` |
| Linha de informação do cartão | 15 | `FrilaTipo.meta` |
| Ajuda abaixo do campo | 13, cor de apoio | `FrilaTipo.nota` |
| Preço | 20 bold, números tabulares | `FrilaTipo.preco` + `.monospacedDigit()` |

Bricolage Grotesque só nas perguntas do formulário de publicar vaga (decisão DP-03). Nunca itálico.

## 4. Peças de tela
- **Barra de status e topo.** Nas telas empilhadas, botão voltar em círculo branco de 44 pt com chevron, no canto superior esquerdo. Título de navegação centralizado (17 semibold) só em detalhes: "Detalhe da vaga", "Vaga preenchida". Nas telas de primeiro nível não há barra de navegação: o título grande abre a tela.
- **Barra inferior fixa.** Fundo translúcido (`.regularMaterial`) com fio superior e padding 12/16. Leva o CTA preto de 52 pt em largura total, e opcionalmente uma ajuda de 13 pt centralizada abaixo. Há duas variantes com resumo:
  - Publicar: resumo em duas linhas, total em 20 bold e CTA à direita.
  - Detalhe da vaga: aviso de contato com ícone em cima, preço à esquerda e CTA "Aceitar turno" à direita.
- **Campo.** Rótulo acima (15 semibold) e caixa branca de 52 pt, raio 16, contorno `borda` de 1 pt e ícone de apoio opcional à esquerda (18 pt, cor de apoio). O seletor leva chevron para baixo à direita. No erro, o contorno vira 2 pt `texto` e a mensagem aparece abaixo, com ícone de triângulo.
- **Botões.** O primário é pílula preta de 52 pt. O secundário é pílula branca com contorno de 1 pt. O terciário é só texto 17 semibold ("Agora não", "Trocar e-mail"). O desabilitado é pílula `controle` com texto de apoio.
- **Chip.** Altura visual de 36 pt e toque de 44. Selecionado: preto, texto branco e ✓ à esquerda. Não selecionado: branco com contorno.
- **Cartão de escolha** (Perfil: "Quero trabalhar em turnos"): cartão branco de raio 20, ícone em círculo cinza de 40 pt, título semibold, descrição de apoio e rádio à direita.
- **Lista agrupada.** Cartão branco de raio 20 com linhas de 52 pt separadas por fio. Rótulo à esquerda, valor à direita em cor de apoio e chevron quando a linha navega.
- **Cartão de vaga** (Vagas, Preenchida). Na primeira linha, função (17 semibold) e estabelecimento (15, apoio) à esquerda, preço e "por pessoa" à direita. Depois vêm as linhas com ícone: relógio para horário, pino para "3,2 km, Asa Norte", ✓ para refeição e transporte, pessoa para posições. Por último, fio e a reputação, com ícone e números em negrito: "**18 de 19** avaliações indicam que trabalhariam lá de novo".
- **Cartão de atenção** (Minhas vagas, "Precisa de atenção"): cartão branco com contorno preto de 2 pt, alerta com triângulo em cima, CTA preto e secundário dentro do cartão.
- **Progresso de posições.** Barra segmentada de 4 pt, um segmento por posição: preenchido em `texto`, vazio em `controle`.
- **Aviso.** Bloco `controle`, raio 16, ícone de 20 pt e texto 15. Título em semibold na mesma frase.
- **Barra de abas.** Cápsula flutuante translúcida com 3 itens (ícone em cima, rótulo de 11 pt). O item ativo fica numa cápsula `controle`. Contratante: Minhas vagas, Turnos, Perfil. Profissional: Vagas, Meus turnos, Perfil.
- **Folha** (Publicar): modal com puxador, "Cancelar" à esquerda e título centralizado "Nova vaga".

## 5. Critérios de gosto (o que a revisão de design cobra)
- Alinhamento: tudo começa na mesma margem de 16. Ícones de linha numa coluna fixa, para o texto começar no mesmo x.
- Hierarquia: no máximo três pesos por tela (título, rótulo, corpo). Se dois elementos competem, um deles está errado.
- Proximidade: rótulo a 8 do campo, campo a 24 do próximo rótulo, seção a 32 da anterior.
- Elementos irmãos com a mesma altura e o mesmo raio (chips de uma linha, campos lado a lado).
- Nada de sombra em cartão, gradiente ou cor decorativa.
- Texto de apoio sempre em cor de apoio. Nunca dois tons de cinza diferentes na mesma tela.
- CTA desabilitado continua visível e diz por quê, na ajuda abaixo dele ("Escolha um perfil para seguir.").
