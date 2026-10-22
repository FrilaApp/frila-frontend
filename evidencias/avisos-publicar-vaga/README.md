# Prova: Avisos de validação do Publicar vaga somem ao corrigir o campo

Missão de 22/10/2026: `2026-10-22-thor-avisos-de-validacao-publicar-vaga.md` (observação 1 do ciclo da Capitã Marvel, `missoes/evidencias-e2e-0-5-1-22-10/README.md`).

## Problema
No formulário de Publicar vaga, após uma tentativa de publicação com campos vazios ou inválidos, os avisos de validação continuavam na tela mesmo após o usuário preencher o campo com valor válido, só sumindo na tentativa seguinte de tocar em Publicar.

## Correção
Adicionado `didSet` e validação reativa nos campos correspondentes em `PublicarVagaViewModel`. Quando um campo com erro atinge valor válido, o erro específico é removido de `erros` imediatamente, limpando a mensagem de aviso e a borda de destaque na interface sem necessidade de tocar em Publicar. Campos ainda inválidos mantêm o aviso, e outros avisos não são alterados.

## Evidências
- `01-aviso-na-tela.png`: aviso de validação exibido após tentativa de publicação com campo obrigatório vazio.
- `02-aviso-sumido-apos-corrigir-campo.png`: aviso de validação removido imediatamente após preenchimento do campo com valor válido, sem tocar em Publicar.

## Testes executados
- `FrilaTests` inteiro via `xcb.sh` no simulador Thor (`CEF93014-23BF-4F01-B535-6C1777ED08C9`):
  - Resultado: Passed · passou 1560 · falhou 0 · pulou 0
  - Log: `thor-20261022-174350-85184.log`
- `PublicarVagaEmMinhasVagasUITests` via `xcb.sh`:
  - Resultado: Passed · passou 10 · falhou 0 · pulou 1 (AX5 adiado por desenho)
  - Log: `thor-20261022-174907-4655.log`
- `conferir-movimento.sh` e `conferir-textos.sh`: OK
