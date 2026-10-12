# Exclusão de conta do contratante: padrão e AX5

Recorte do [cartão #71](https://trello.com/c/wiLKWHYl), preservado no [PR 201 em rascunho](https://github.com/FrilaApp/frila-frontend/pull/201). **Parcial, não aprovado.** Somente testes e evidências; sem alteração de produção.

## Resultado da retomada em 11/10

A suíte executou **7 testes: 5 existentes passaram, 2 novos falharam, 0 pulados**, em 104,947 s. O runner iniciou normalmente. Os novos casos padrão e AX5 falharam em `ExclusaoDeContaUITests.swift:257`: o elemento do turno existe, mas `turno.staticTexts.firstMatch.exists` retorna falso. A captura padrão mostra o conteúdo do turno na tela. Inferência: o seletor pressupõe uma hierarquia de acessibilidade que o XCTest não expõe; esta falha não comprova defeito de apresentação do app.

A primeira rodada havia falhado ao exigir que o contêiner do turno fosse tocável. O ajuste para texto filho também falhou. Execuções encerradas pela regra de parar quando o mesmo problema retorna. **Um bloqueio pendente: identificação do turno nos dois testes novos. Nenhuma CI remota executada.** O PR permanece em rascunho porque não ficou verde.

Comando executado a partir de `iOS/`, após obter a vez com `vez.sh hulk --segurar 20` e aguardar `xcrun simctl bootstatus 1D91FAA0-595D-4C54-87BC-FCF91A7CA94D -b`:

```sh
~/Documents/Projetos/Apps/.workers/vigia/xcb.sh hulk -- xcodebuild test \
  -project Frila.xcodeproj -scheme Frila-Local \
  -destination 'platform=iOS Simulator,id=1D91FAA0-595D-4C54-87BC-FCF91A7CA94D' \
  -derivedDataPath ../../derived-exclusao-ax5 \
  -resultBundlePath ../../exclusao-ax5-retomada.xcresult \
  -only-testing:FrilaUITests/ExclusaoDeContaUITests \
  -parallel-testing-enabled NO -collect-test-diagnostics never
```

O projeto ignorado foi gerado com XcodeGen 2.45.3. Ambiente real em [ambiente.json](ambiente.json): Hulk, iPhone 17, iOS 26.5, Xcode 27.0 (27A266a). A vez foi devolvida ao finalizar. DerivedData e xcresult são temporários próprios, removidos após exportar as provas. O comentário do seletor foi corrigido após a execução; não houve mudança de comportamento dos testes.

## Capturas revisadas e limites da prova

Cada arquivo corresponde a uma captura independente da execução retomada; origem e identificador do teste estão no [manifesto](manifesto-capturas.json).

| Etapa alcançada | Padrão | AX5 | Resultado observado |
|---|---|---|---|
| Acesso pelo perfil | [Perfil padrão](ContratantePadraoPerfil.png) | [Perfil AX5](ContratanteAX5Perfil.png) | Botão Excluir conta tocável, alvo mínimo de 44 pt com tolerância de 0,01 pt e dentro da largura da janela |
| Abertura das consequências | [Consequências padrão](ContratantePadraoConsequencias.png) | [Consequências AX5](ContratanteAX5Consequencias.png) | Tela e aviso encontrados; em AX5 a captura cobre somente o início da tela rolável |

As cinco etapas posteriores dos dois casos novos **não foram executadas** devido à falha do seletor: rolagem/visibilidade do turno, aviso de lista incompleta, consentimento antes/depois, confirmação com geometria dos botões e cancelamento. Não há capturas nem aprovação dessas etapas nos novos casos. O teste antigo de vínculos/lista incompleta passou, assim como o cancelamento AX5 do profissional; isso não substitui a prova nova do contratante.

VoiceOver por pessoa independente, aparelho físico e demais telas estão fora do recorte e não foram executados. O cartão #71 não está encerrado.

## Provas

- Rodada retomada: [resumo-retomada.json](resumo-retomada.json) e [trecho do log](xcb-retomada-trecho.log). Log completo: `.workers/vigia/logs-xcodebuild/hulk-20261011-230259-58197.log`.
- Primeira suíte: [resumo-primeira-rodada.json](resumo-primeira-rodada.json); log `hulk-20261011-112146-51068.log`.
- Tentativa intermediária: log `hulk-20261011-113656-81124.log`, saída 65 antes dos casos por `Application failed preflight checks` / `Busy`; esse bloqueio não voltou na retomada.
- A tentativa inicial anterior às suítes parou por projeto ausente, resolvido com XcodeGen.

Próximo passo, sob nova orientação: inspecionar a árvore acessível do turno, corrigir o seletor e executar novamente a suíte local. Só depois de verde, completar as capturas e retirar o rascunho respeitando o limite de uma CI remota.
