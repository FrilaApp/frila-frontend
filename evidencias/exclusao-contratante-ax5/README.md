# Exclusão de conta do contratante: padrão e AX5

Recorte do [cartão #71](https://trello.com/c/wiLKWHYl). A suíte existente cobria o cancelamento em AX5 pelo profissional; os dois novos testes percorrem o contratante com turnos futuros (`painel-contratante`).

## Execução

Estado: **parcial, não aprovado**, interrompido pela nova missão `2026-10-11-hulk-pagina-publica.md`. A primeira tentativa parou antes do build porque o `.xcodeproj` não estava gerado (saída 74); resolvido com `xcodegen generate`, versão 2.45.3. A rodada seguinte executou 7 casos: 5 existentes passaram e os 2 novos falharam por usar o contêiner do turno como alvo tocável. A captura padrão mostra o turno visível. O teste foi corrigido para consultar o texto filho; a validação desse ajuste não iniciou os testes porque o simulador recusou o runner com `Application failed preflight checks` / `Busy`. Nenhuma CI remota executada.

Comando, a partir de `iOS/`:

```sh
xcodegen generate
~/Documents/Projetos/Apps/.workers/vigia/xcb.sh hulk -- xcodebuild test \
  -project Frila.xcodeproj -scheme Frila-Local \
  -destination 'platform=iOS Simulator,id=1D91FAA0-595D-4C54-87BC-FCF91A7CA94D' \
  -derivedDataPath ../../derived-exclusao-ax5 \
  -resultBundlePath ../../exclusao-ax5-validacao.xcresult \
  -only-testing:FrilaUITests/ExclusaoDeContaUITests -parallel-testing-enabled NO -collect-test-diagnostics never
```

Os caminhos de DerivedData e xcresult são próprios do Hulk, fora do repositório, e são removidos depois da exportação das provas. O ambiente veio de `xcrun simctl list devices available -j`: [ambiente.json](ambiente.json).

## O que os testes verificam

| Etapa | Prova automatizada |
|---|---|
| Perfil do estabelecimento | Acesso à exclusão tocável, com alvo mínimo e dentro da largura da janela |
| Consequências | A tela apresenta o aviso antes da confirmação |
| Turno futuro | O vínculo da fixture está presente; o estado sem turnos não aparece |
| Lista incompleta | O aviso de limitação continua presente no fluxo do contratante |
| Consentimento | Excluir permanece desabilitado até alternar o interruptor |
| Confirmação | Cancelar e Excluir ficam tocáveis, com alvo mínimo de 44 pt e inteiros na janela |
| Cancelamento | A confirmação fecha; a tela da conta continua e o campo da entrada não aparece |

O auxiliar comum de alvo mínimo admite 0,01 pt para arredondamento do frame. Cada etapa possui uma captura independente por tamanho; os nomes começam com `ContratantePadrao` ou `ContratanteAX5`.

## Limites

Este recorte não comprova a acessibilidade de todas as telas nem encerra o cartão #71. VoiceOver por pessoa independente e aparelho físico não foram executados: estão fora desta missão, que usa o dublê local no simulador. Não há alteração de código de produção.

## Provas e retomada

- Primeira suíte: [resumo-primeira-rodada.json](resumo-primeira-rodada.json); xcb `hulk-20261011-112146-51068.log`.
- Validação do ajuste: xcb `hulk-20261011-113656-81124.log`, saída 65 antes de executar casos, falha de preflight do runner.
- Ambos os logs ficam em `.workers/vigia/logs-xcodebuild/`.
- Falta executar a suíte com o ajuste, revisar/exportar as capturas de todas as etapas e executar a única CI após o teste local passar.
- Bloqueios pendentes: 1 (runner não iniciou). A coleta longa da primeira rodada consumiu 10 minutos e foi desativada na segunda pela opção documentada do Xcode.
