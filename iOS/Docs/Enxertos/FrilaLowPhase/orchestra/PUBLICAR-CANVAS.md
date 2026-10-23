---
tarefa: midfi-backend
artefato: PUBLICAR-CANVAS
de: CLAUDE
para: CLAUDE (sessões futuras)
status: pronto
atualizado: 2026-10-16
---

# Publicar o canvas MidFi no claude.ai

Só o CLAUDE publica o canvas e atualiza `docs/prototype/midfi/VERSAO.md` (`PROTOCOLO.md`). Este arquivo é o passo a passo, escrito depois das publicações das versões 64 e 65. O script de apoio é `.orchestra/midfi-backend/verificar-canvas.py`; ele só lê arquivos e git e nunca executa um quadro.

## Onde está o canvas

- Artefato: `https://claude.ai/artifact/27750a8e-fd19-4fb0-8161-a26d06976b32` (o link do `VERSAO.md`). Publicar nele devolveu `https://claude.ai/artifact/5sbZTTpkH2zm2boENtKi5f`; os dois apontam para o mesmo artefato e qualquer um serve como `url`.
- A página vem de um tipo de artefato e não se altera: só os arquivos de `project/` e o `canvas.json` mudam.
- O espelho no repositório é `docs/prototype/midfi/project/`: um `*.dc.html` por quadro (390×844) e o `canvas.json`, que guarda `boards` (título, posição, tamanho) e `order`.

## Antes de publicar

1. Tudo o que vai ao canvas já está na `main` ou na branch da missão, integrado e auditado. Não se publica quadro que ninguém auditou.
2. Conferir quadros e índice, da raiz do repositório:

   ```sh
   python3 -I .orchestra/midfi-backend/verificar-canvas.py
   ```

   Sai com código 1 se houver quadro fora do `canvas.json`, entrada sem arquivo, posição repetida ou `href` fixo para quadro inexistente. Construtores criam envelopes novos e **não** os registram no `canvas.json`: isso é do maestro.
3. Se faltar quadro no índice: `verificar-canvas.py --aplicar`. Ele acrescenta os que faltam numa fileira nova (colunas de 470 px, fileiras de 1680 px, até 19 por fileira) e usa o `<title>` de cada quadro como título. **Revise os títulos:** os envelopes costumam ter títulos genéricos ("Mapa do local") e ficam melhores com o contexto ("Mapa do turno (Buffet Primavera)").
4. O que mudou: `verificar-canvas.py --resumo <commit da versão publicada>`. Lista quadros novos (com o quadro-base e as props que importam), quadros alterados com `+/-` linhas e os `href` que entraram e saíram. Cabe em poucos KB. O artefato não é meu, então a regra de não distribuir o que não vi continua valendo: leia o resumo e abra só os quadros que ele indicar como suspeitos. O script não enxerga `href` dinâmico (`{{ link }}`) nem o conteúdo de condições.

## Publicar

1. Copiar os quadros alterados para o scratchpad. A pasta do worktree da missão fica fora do diretório de trabalho da ferramenta, e passá-la em `root` é recusado:

   ```sh
   python3 -I .orchestra/midfi-backend/verificar-canvas.py --preparar <SCRATCHPAD>/pubN <commit da versão publicada>
   ```

   O comando copia os alterados e o `canvas.json` para `<SCRATCHPAD>/pubN/project/` e imprime o mapa JSON para o parâmetro `files`.
2. Chamar a ferramenta Artifact (publicar) com:
   - `url`: o artefato acima;
   - `root`: `<SCRATCHPAD>/pubN`;
   - `file_path`: `<SCRATCHPAD>/pubN/project/canvas.json`;
   - `files`: o mapa impresso no passo anterior (arquivos não enviados são mantidos no artefato);
   - `label`: o nome da rodada, por exemplo "Correção dos 13 defeitos médios".
3. O resultado traz a versão e o id (por exemplo "Version 65, 1792136457-47b4"). Anote os dois.

## Depois de publicar

1. Atualizar `docs/prototype/midfi/VERSAO.md`: versão e id, data, número de quadros (`verificar-canvas.py` imprime a contagem) e uma linha na tabela de histórico com a rodada, os quadros novos e as decisões da pessoa que valem.
2. Commit com `docs(prototype): ...`, push, PR e merge só pelo CLAUDE, e só depois do pedido da pessoa. Sem trailer de IA. Enquanto o CI do GitHub estiver parado (A01 em `docs/workflow/ATENCAO.md`), rodar `swift build`, `swift test --parallel` e `swift format lint --recursive Sources Tests` localmente e registrar o resultado no PR.
3. Dizer à pessoa o que olhar primeiro. A conferência dos quadros é só estática: a primeira navegação de verdade é a revisão dela no canvas.

## Limites

- O espelho nunca roda localmente (`AGENTS.md` do Frila, seção 2): nada aqui executa componentes, abre navegador ou sobe servidor.
- `verificar-canvas.py` prova que o índice e os destinos fixos estão consistentes. Não prova que a lógica dos quadros está certa.
