# Prova da correção de rolagem dos perfis em AX5 — 12/10/2026

## Diagnóstico (5 linhas)

1. O teste falhava ao tornar inteiramente visível o botão de Carla depois de voltar do perfil de Bruno (`Tests/UI/ReputacaoDosPerfisPublicosUITests.swift:36`, `:41`, helper original `:74–84`).
2. O helper original usava swipes completos; a reprodução local alternou `Swipe up`/`Swipe down` entre 29,31 s e 55,79 s e esgotou as 12 tentativas, reproduzindo a falha das quatro CIs indicadas abaixo.
3. Inferência: o swipe ultrapassa a faixa permitida em AX5 e a correção oposta ultrapassa novamente; a posição inicial pode variar, mas a falha foi reproduzida nesta máquina, sem depender de espera maior (`ReputacaoDosPerfisPublicosUITests.swift:74`).
4. A ordem do dublê é determinística por data e UUID (`Sources/Dados/ApiClienteEmMemoria.swift:1345`); Carla é a candidatura `70000000-0000-0000-0000-000000000003` em `Resources/Fixtures/candidatos.json`.
5. Os candidatos estão em `ScrollView`, sem altura fixa para a lista (`Sources/Apresentacao/Fluxos/Contratante/MinhasVagas.swift:550`, `:615`); os três resultados abaixo demonstram que os mesmos limites de visibilidade, toque, largura e alvo mínimo passam com arrastos limitados (`ReputacaoDosPerfisPublicosUITests.swift:80`, `:95`).

A correção usa a posição do elemento, inclusive quando não aceita toque, para determinar o sentido e a distância de arrastos lentos. Cada arrasto é limitado a 35% da altura da janela. Mantém 12 tentativas, margens verticais de 100/40 pontos, todos os asserts, os tempos de espera e ambos os testes.

## Reprodução antes da correção

`testPerfisComESemHistoricoEmAX5` → falha em 59,148 s, `Elemento não ficou inteiramente visível: perfil-do-candidato-70000000-0000-0000-0000-000000000003`.

Log: `/Users/cauecarneiro/Documents/Projetos/Apps/.workers/vigia/logs-xcodebuild/homem-aranha-20261012-162558-4488.log:15346` e `:15355` (alternância) e `:15443` (falha).
Capturas exportadas: `/Users/cauecarneiro/Documents/Projetos/Apps/.workers/homem-aranha/perfis-ax5-antes-capturas`.
As quatro CIs tinham a mesma mensagem: [38226467370](https://github.com/FrilaApp/frila-frontend/actions/runs/38226467370), [38215055981](https://github.com/FrilaApp/frila-frontend/actions/runs/38215055981), [38216257700](https://github.com/FrilaApp/frila-frontend/actions/runs/38216257700) e [38288434353](https://github.com/FrilaApp/frila-frontend/actions/runs/38288434353).

## Três execuções consecutivas da classe inteira

Comando comum, em `iOS/`: `xcb.sh 'Homem-Aranha' -- xcodebuild <ação> -project Frila.xcodeproj -scheme Frila-Local -destination 'platform=iOS Simulator,id=85940BCB-553C-4145-8F8E-E83423D86431' -derivedDataPath <pasta própria> -resultBundlePath <resultado próprio> -only-testing:FrilaUITests/ReputacaoDosPerfisPublicosUITests -parallel-testing-enabled NO`.

O wrapper usado foi `/Users/cauecarneiro/Documents/Projetos/Apps/.workers/vigia/xcb.sh`. A primeira ação foi `test`; as seguintes, `test-without-building`, usando o mesmo binário. O simulador foi ligado e desligado pelo wrapper em cada execução. Resumos copiados das saídas:

```text
status: success
summary:
  errors: 0
  warnings: 1
  failed_tests: 0
  linker_errors: 0
  passed_tests: 2
  test_time: 70.032s
xcodebuild terminou com 0 · log inteiro: /Users/cauecarneiro/Documents/Projetos/Apps/.workers/vigia/logs-xcodebuild/homem-aranha-20261012-163330-22469.log
```

```text
status: success
summary:
  errors: 0
  warnings: 0
  failed_tests: 0
  linker_errors: 0
  passed_tests: 2
  test_time: 69.144s
xcodebuild terminou com 0 · log inteiro: /Users/cauecarneiro/Documents/Projetos/Apps/.workers/vigia/logs-xcodebuild/homem-aranha-20261012-163525-26311.log
```

```text
status: success
summary:
  errors: 0
  warnings: 0
  failed_tests: 0
  linker_errors: 0
  passed_tests: 2
  test_time: 69.783s
xcodebuild terminou com 0 · log inteiro: /Users/cauecarneiro/Documents/Projetos/Apps/.workers/vigia/logs-xcodebuild/homem-aranha-20261012-163710-28696.log
```

Capturas da terceira execução: `/Users/cauecarneiro/Documents/Projetos/Apps/.workers/homem-aranha/perfis-ax5-verde-3-capturas` (nomes e arquivos no `manifest.json`).
O aviso da primeira execução é o envio de símbolos do Crashlytics sem configuração Firebase no build local. `bash iOS/Scripts/conferir-textos.sh` → OK. `git diff --check` → OK. Não houve edição de SwiftUI nem mudança em workflow, contrato ou política.

## Fora do escopo (somente leitura)

`testEnderecoEQuemRecebeDoTurnoCanceladoNaoCortamEmAX5`: mesma causa não comprovada; falha em asserts de toque após até seis swipes lentos para cima, sem o helper que alterna os sentidos (`AcessibilidadeDoProfissionalUITests.swift:270–275`, CI 38234482503); não executado localmente.
`testEnvioDeAvaliacaoPelaRotaDiretaMostraConfirmacao`: não evidencia esta mesma causa; a confirmação `aviso-sucesso-avaliacao` não aparece após enviar, sem rolagem neste passo (`AvaliacaoUITests.swift:56–66`, CI 38215055981); não executado localmente.

## PR 216: tempos por passo (3 linhas)

1. Inferência por diferença dos passos: na Parte 2, o boot caiu de 44 s para 9 s (35 s ganhos); os dois runs usaram cache SPM e pularam a resolução, sem ganho nessa etapa (fontes: `gh run view 38226467370/38288434353 --json jobs`).
2. Inferência por soma e diferença: compilação dos testes + Dev/Beta/Prod subiu de 14,57 para 26,10 min (+11,53); a etapa de testes subiu de 44,70 para 49,42 min (+4,72), encobrindo o ganho do boot; os builds de Release continuaram executados.
3. Inferência: o cache só de `SourcePackages` não reaproveita produtos de build (`ios.yml:115`, `:206–209` no head `1c063e0`); as durações totais medidas foram 62,32 min no main 38226467370 e 79,18 min no PR 216; 67–69 min não encontrado nas execuções inspecionadas (outro main, 38215055981: 64,90 min), e os tempos não provam a causa da compilação mais lenta.

CI do PR: acompanhar a única execução após a publicação e registrar o resultado na entrega por ask-back. Nenhuma suíte foi pulada dentro da classe; os dois testes fora do escopo e a suíte completa local não foram executados, conforme o recorte da missão.
