# Evidências: Barra inferior do Detalhe da vaga

Correção da quebra em duas linhas da barra inferior do Detalhe da Vaga (`AreaDeCandidatura`) quando o texto de apoio de preço é mais longo ("por pessoa, amanhã 23h30").

## Comportamento Anterior (Antes)
- A barra utilizava `ViewThatFits(in: .horizontal)` com fallback para `VStack(alignment: .leading)`.
- Com "amanhã 23h30" e o botão "Aceitar turno" / "Candidatar-me", a largura total ideal ultrapassava a largura disponível da tela em tamanho padrão, acionando o fallback vertical. O botão descia para uma segunda linha e expandia com `.frame(maxWidth: .infinity)`, ficando centralizado abaixo do preço.

## Comportamento Corrigido (Depois)
- No tamanho padrão de texto, a barra é sempre horizontal (`HStack`), com o botão alinhado à direita conforme o protótipo do design system (`FrilaLowPhase`).
- Se o espaço for restrito, o texto de apoio encolhe com `minimumScaleFactor(0.8)` e trunca com `truncationMode(.tail)` (`layoutPriority(0)`). O preço mantém prioridade (`layoutPriority(1)`), e o botão mantém prioridade alta (`layoutPriority(1)`), nunca sendo empurrado nem descendo para nova linha.
- Tamanhos de acessibilidade (`dynamicTypeSize.isAccessibilitySize`) continuam utilizando empilhamento vertical adaptado.

## Capturas
### Antes
- `antes/01-detalhe-amanha-23h30-claro.png`: Detalhe da vaga com "amanhã 23h30" no tema claro
- `antes/02-detalhe-amanha-23h30-escuro.png`: Detalhe da vaga com "amanhã 23h30" no tema escuro
- `antes/03-detalhe-hoje-18h-claro.png`: Detalhe da vaga com "hoje 18h" no tema claro
- `antes/04-detalhe-hoje-18h-escuro.png`: Detalhe da vaga com "hoje 18h" no tema escuro
- `antes/05-feed-vizinha-claro.png`: Tela vizinha (feed de vagas) no tema claro
- `antes/06-feed-vizinha-escuro.png`: Tela vizinha (feed de vagas) no tema escuro

### Depois
- `depois/01-detalhe-amanha-23h30-claro.png`: Detalhe da vaga com "amanhã 23h30" no tema claro (barra em linha única, botão à direita)
- `depois/02-detalhe-amanha-23h30-escuro.png`: Detalhe da vaga com "amanhã 23h30" no tema escuro (barra em linha única, botão à direita)
- `depois/03-detalhe-hoje-18h-claro.png`: Detalhe da vaga com "hoje 18h" no tema claro (barra em linha única, botão à direita)
- `depois/04-detalhe-hoje-18h-escuro.png`: Detalhe da vaga com "hoje 18h" no tema escuro (barra em linha única, botão à direita)
- `depois/05-feed-vizinha-claro.png`: Tela vizinha (feed de vagas) no tema claro sem regressão
- `depois/06-feed-vizinha-escuro.png`: Tela vizinha (feed de vagas) no tema escuro sem regressão
