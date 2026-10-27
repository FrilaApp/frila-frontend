## Quem responde e qual IA ajudou

<!-- Pelo nome: o sócio que responde por este PR e, se houve, a IA (ferramenta e modelo). -->

Quem responde: 
IA: 

## Cartão

<!-- Link curto do Trello. Sem cartão, diga por quê. -->

https://trello.com/c/

## O que muda, e por quê

<!-- O porquê primeiro, em uma ou duas frases. -->

## Gate local (a partir de `iOS/`)

Rode, olhe a saída, e só então marque. A CI de iOS não bloqueia o merge, então esta é a prova.

- [ ] `Scripts/conferir-textos.sh`
- [ ] `xcodebuild build-for-testing` e `test-without-building -only-testing:` nas telas tocadas
- [ ] `Scripts/auditoria-de-acessibilidade.sh` (tela nova ou alterada)
- [ ] Mudou o contrato? `Scripts/contrato-em-dia.sh` e o espelho vem de `frila-docs/api/openapi.yaml`

<!-- Cole o resumo da saída. O que não rodou, escreva que não rodou e por quê. -->

## Risco

<!-- Faixa (verde, amarela ou vermelha, veja o AGENTS.md) e o que pode quebrar. -->

## O que ficou de fora
