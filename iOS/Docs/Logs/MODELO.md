---
id: LOG-000
status: rascunho
area: componentes | telas
dependencias: nenhuma
---

# LOG-000: <título curto>

## Problema
<o que está errado ou faltando, visto pelo usuário>

## Evidência (correção de bug)
<trecho do log do aparelho, causa confirmada ou descartada e como foi reproduzido>

## Diff-log (refino visual)
<caminho do diff-log em ~/dev/frila-orquestra/diff-log/<ID>/, claro, topo/meio/fim, tabela de mudanças por token, sem números de cor>

## Resultado esperado
<o estado final em poucas linhas>

## Comportamento visual e interativo
<estados, gesto e movimento; referência: iOS/Docs/HiFi/REFERENCIA.md>

## Roteiro de interação
<5 a 8 passos com resultado esperado em cada: caminho feliz do usuário-modelo e 2 a 3 deslizes do usuário médio (toque errado, voltar no meio, repetir a ação, rolar rápido ou toque duplo); indique qual teste é o smoke>

## Componentes e tokens
<componentes e tokens usados>

## Escopo (só `iOS/Sources/Apresentacao/`)
- Dentro: <arquivos>
- Fora: <o que não muda>

## Autorização de escopo (se houver)
<exceção expressa do usuário, ex.: teste novo em iOS/Tests/Unitarios/<arquivo>; sem isso, vale a §2.2>

## Critérios de aceite
- [ ] <verificável, um por linha>

## Validação
<smoke UITest (até 2 min) + roteiro>
