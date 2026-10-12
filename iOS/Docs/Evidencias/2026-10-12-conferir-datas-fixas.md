# Prova do portão de datas fixas — 12/10/2026

## Resultado final após a devolução

`Scripts/conferir-datas-fixas.sh` passou com exit 0; autoteste aprovado em 12 verificações. As três suítes unitárias afetadas passaram pelo `xcb.sh`: 36 testes, 0 falhas e 0 pulados. Simulador Homem-Aranha, iPhone 17, iOS 26.5 (23F77), UDID 85940BCB-553C-4145-8F8E-E83423D86431; dados extraídos do xcresult, preservados no [resumo JSON](2026-10-12-datas-fixas-unitarios-resumo.json).

Escopo do portão: literais ISO (`2025/2026-MM-DD`, com ou sem horário), `year:`, `ano:` e atribuição `.year` nos corpos de tipos Duble/Mock/Fake/Stub/Falso/Simulado ou implementações de `ApiCliente`/`ApiClienteEncaminhador`, incluindo extensões. Varredura recursiva dos arquivos Swift em `iOS/Tests`. Comentários, datas fora desses corpos, outros anos e timestamps numéricos ficam fora deste recorte.

## Fixtures corrigidas

A prova inicial identificou três datas; a devolução do Nick Fury autorizou corrigir as três no mesmo PR. Nenhuma exceção foi acrescentada ao portão.

| Arquivo / dublê | Antes | Depois |
|---|---|---|
| `ExclusaoDeContaViewModelTests.swift` / `DublePortaExclusao` | `2026-10-16` | criação em `relogio.agora`, prazo civil de São Paulo +15 dias |
| `ExportarDadosViewModelTests.swift` / `DubleApiExportar` | `2026-10-02T12:00:00Z` | `gerado_em` em ISO a partir do relógio injetado; asserção do conteúdo usa esse instante |
| `SuporteTurnoTests.swift` / `ApiDeSuporteTeste` | `2026-10-16` | criação em `relogio.agora`, prazo futuro da fixture +7 dias civis |

O prazo de suporte dessa fixture não é prova de contagem de dias úteis do servidor. O código de produto e o contrato não foram alterados.

## Execução dos scripts

```text
$ iOS/Scripts/teste-conferir-datas-fixas.sh
OK: autoteste de conferir-datas-fixas.sh (12 verificações).
exit: 0

$ iOS/Scripts/conferir-datas-fixas.sh
OK: dublês sem datas literais de 2025/2026.
exit: 0

$ iOS/Scripts/teste-conferir-textos.sh
OK: autoteste de conferir-textos.sh passou
exit: 0

$ iOS/Scripts/conferir-textos.sh
OK: textos no bundle da Apresentação e tokens em conformidade.
exit: 0

$ iOS/Scripts/teste-conferir-movimento.sh
OK: autoteste de conferir-movimento.sh passou
exit: 0

$ iOS/Scripts/conferir-movimento.sh
OK: todas as animações respeitam Reduzir Movimento via FrilaMovimento.animacao.
exit: 0
```

## Execução das suítes afetadas

Comando executado na pasta `iOS`, com caminhos absolutos normalizados abaixo para seus equivalentes relativos:

```sh
../../../vigia/xcb.sh homem-aranha -- xcodebuild test \
  -project Frila.xcodeproj -scheme Frila-Local \
  -destination 'platform=iOS Simulator,id=85940BCB-553C-4145-8F8E-E83423D86431' \
  -derivedDataPath ../../derived-datas-fixas \
  -resultBundlePath ../../datas-fixas-unitarios-validado.xcresult \
  -parallel-testing-enabled NO \
  -only-testing:FrilaTests/ExclusaoDeContaViewModelTests \
  -only-testing:FrilaTests/ExportarDadosViewModelTests \
  -only-testing:FrilaTests/SuporteTurnoTests CODE_SIGNING_ALLOWED=NO
```

```text
Test Suite 'FrilaTests.xctest' passed at 2026-10-12 06:01:39.660.
Test Suite 'Selected tests' passed at 2026-10-12 06:01:39.660.
✔ Suite "Exclusão de Conta: View Model (#50)" passed after 0.014 seconds.
✔ Suite "Exportar Meus Dados: View Model (#219)" passed after 0.125 seconds.
✔ Suite "Suporte no Turno: View Model e Montador de E-mail (#21)" passed after 0.010 seconds.
✔ Test run with 36 tests in 3 suites passed after 0.150 seconds.
** TEST SUCCEEDED **
xcodebuild terminou com 0
```

Log: `.workers/vigia/logs-xcodebuild/homem-aranha-20261012-060027-45329.log`. A compilação emitiu 33 avisos e nenhum erro. UI e suítes completas não foram executadas: o recorte da devolução exige as três suítes unitárias afetadas.

Houve um bloqueio inicial de SPM com `-onlyUsePackageVersionsFromResolvedFile` (log `homem-aranha-20261012-055858-43931.log`, exit 74): o resolver pediu a dependência transitiva `swift-issue-reporting`. A execução aprovada permitiu a resolução local, que adicionou esse pin ao projeto gerado; os estados de todos os pins anteriores permaneceram iguais. O `iOS/Package.resolved` versionado não foi alterado. Bloqueios locais ativos: 0.

## CI

Uma atualização do PR será enviada nesta devolução; sem repetição de CI. O resultado remoto será ligado no PR e no ask-back, sem novo push apenas para registrar estado.
