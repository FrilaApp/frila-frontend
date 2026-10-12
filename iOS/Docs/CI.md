# Integração contínua

O workflow `.github/workflows/ios.yml` roda em pull requests que mexem em `iOS/**` (ignorando alterações restritas a Markdown `!iOS/**/*.md` e `!iOS/Docs/**`) ou no próprio workflow, em dois jobs paralelos num runner `macos-26` cada, com permissão só de leitura e limite de 90 minutos por job. A suíte completa do `main` roda diariamente às 06h UTC e por `workflow_dispatch`. Um push novo cancela a execução anterior do mesmo PR; execuções agendadas e manuais têm grupos de concurrency próprios. PRs que tocam apenas documentação não disparam a suíte, liberando a fila e economizando minutos de macOS.

## Duas partes

Desde 06/10/2026 (PR #147), a suíte do `Frila-Local` é dividida por uma lista só, `Tests/parte-1-da-ci.txt`:

- **Parte 1** (`parte-1`): os portões que não compilam (etapas 3 a 5 abaixo e a conferência das partes), depois os testes unitários (`FrilaTests` inteiro) e as classes de interface da lista, com `-only-testing`.
- **Parte 2** (`parte-2`): todo o resto da suíte, com `-skip-testing` da mesma lista, e os builds de Release (etapas 11 a 13), que continuam pulados em PR que só mexe em testes ou documentação. Os builds de Release vêm antes dos testes de interface: um Release quebrado reprova em minutos.

Classe ou alvo de teste novo fica fora da lista e cai sozinho na parte 2. Antes de compilar, a parte 1 roda `Scripts/partes-dos-testes.sh conferir`, com o autoteste `Scripts/teste-partes-dos-testes.sh`. A conferência reprova item da lista que não existe no código ou que aparece repetido, e imprime as classes de cada parte.

A divisão saiu dos tempos por classe da execução 37244334865 (push no `main`, 05/10). As 38 classes de interface somaram 71,0 minutos. A parte 1 ficou com 11 classes (39,2 min) e os unitários; a parte 2, com 27 classes (31,7 min) e os builds de Release. Esses builds levaram de 9m45s a 10m28s nas execuções 37241695780 e 37251084274.

Na primeira execução do desenho, a 37504092755 (06/10):
- a parte 1 levou 55m56s e a parte 2, 59m19s, 115m15s somados;
- a interface rodou 11% mais devagar que na 37244334865 na parte 1 e 22% na parte 2, cada job numa máquina;
- cada parte gastou cerca de 4 minutos entre o início do passo de testes e o primeiro teste, com o boot do simulador e a instalação.

Depois dela, `CancelamentoDoProfissionalUITests` (3,0 min) passou para a parte 1. A troca compensa as classes novas do #154 e do #155 (`PorQueReceboVagasUITests` e `EquipeDeConfiancaUITests`), que caíram sozinhas na parte 2.

Cada parte compila o seu `build-for-testing`. A alternativa medida foi compilar uma vez e repassar os produtos às partes como artefato:
- os produtos têm 218 MB, ou 56 MB zipados (medido localmente);
- o upload na CI fez 360 MB em 19 s (xcresult da 37241695780);
- a compilação levou de 2m34s a 3m51s (37244334865, 37241695780 e 37251084274).

Inferência: o artefato pouparia no máximo uma compilação por execução, menos o preparo de um terceiro job, e as partes esperariam por ele. A diferença é pequena, então ficou a opção mais simples.

**Rebalancear** quando a parte 2 passar de 65 minutos medidos numa execução completa, ou quando a parte 1 passar disso. Mova classes para a lista ou tire dela pelos tempos da execução mais recente: no log, o xcbeautify imprime `Executed N tests, ... in S seconds` ao fim de cada classe. Antes do push, confira com as enumerações do próprio xcodebuild, depois de um `build-for-testing` do `Frila-Local`:

```sh
cd iOS
for p in suite 1 2; do
  ARGS=(); [[ $p == suite ]] || while IFS= read -r a; do ARGS+=("$a"); done <<< "$(Scripts/partes-dos-testes.sh argumentos $p)"
  xcodebuild test-without-building -project Frila.xcodeproj -scheme Frila-Local -destination "id=<UDID>" \
    -enumerate-tests -test-enumeration-style flat -test-enumeration-format json \
    -test-enumeration-output-path "/tmp/partes-$p.json" "${ARGS[@]}"
done
Scripts/partes-dos-testes.sh conferir-enumeracoes /tmp/partes-suite.json /tmp/partes-1.json /tmp/partes-2.json
```

Em 06/10 essa conferência deu 1.101 testes na parte 1 e 155 na parte 2, que somam os 1.256 da suíte. Cada enumeração levou de 37 a 64 s localmente, por isso ela não roda em toda execução da CI.

## Etapas

Etapas, na ordem:

1. Seleciona o Xcode 26.6 fixado do runner.
2. Instala o XcodeGen 2.45.3 do release oficial e confere o SHA-256.
3. `Scripts/contrato-em-dia.sh`: o espelho `Contrato/openapi.yaml` bate com a soma gravada; com o secret `FRILA_DOCS_TOKEN`, também com o frila-docs.
4. `python3 Scripts/validate-fixtures.py`: cada fixture contra o schema do contrato, com tipos, formatos, enums e campos fora do contrato.
5. Falha se algum arquivo fora de `Sources/Dados` importar o Supabase.
6. `Scripts/gerar-projeto.sh` para gerar o `Frila.xcodeproj` via XcodeGen e restaurar o `Package.resolved` versionado.
7. Injeta os plists do Firebase Dev e Prod.
8. Escolhe o simulador de iPhone disponível com o iOS mais novo, sem aparelho fixo.
9. Restaura `DerivedData/SourcePackages` pelo hash do `Package.resolved` e pela versão do Xcode. Sem cache, resolve os pacotes explicitamente com `-onlyUsePackageVersionsFromResolvedFile`; com cache, a resolução automática fica desabilitada. Produtos de build nunca entram no cache.
10. `xcodebuild build-for-testing` e depois `test-without-building` do `Frila-Local`: testes unitários, de contrato e de interface, sem backend. Cada parte compila e roda a sua fatia: a parte 1, a lista; a parte 2, o resto (veja [Duas partes](#duas-partes)).
11. Gera o `Secrets.xcconfig` de Dev e compila o `Frila-Dev` (pulado se o PR só mexe em testes ou documentação).
12. Compila o `Frila-Beta` (Release apontando para o frila-dev) e confere o bundle (pulado se o PR só mexe em testes ou documentação).
13. Gera o `Secrets.xcconfig` de Prod e compila o `Frila-Prod` e confere o bundle (pulado se o PR só mexe em testes ou documentação).
14. Apaga `Secrets.xcconfig`, plists, produtos de build e temporários, mesmo quando uma etapa falha. O diretório `SourcePackages` fica só até o pós-job de cache salvar os pacotes.

Nenhuma etapa do `ios.yml` assina código (o simulador usa a assinatura local ad-hoc) nem publica artefato. As fases de script do Xcode não exportam variáveis para o log, e o GitHub mascara os segredos.

Desde 24/09 a etapa 12 compila com o `frila-prod` ([Dependências externas](ExternalSetup.md), item 9). Se um dos dois secrets de Prod faltar, ela para em `FRILA_SUPABASE_PROD_URL is not set`, de propósito: Prod sem Supabase não compila em silêncio.

Custo: o repositório é privado e cada minuto macOS consome cerca de dez vezes a cota de um minuto Linux. O orçamento de Actions da organização está em US$ 0 com bloqueio de uso adicional, então esgotar a cota interrompe a CI sem gerar cobrança.

Tempo da CI de PR: no PR #66, em 02/10/2026, a execução levou 39m45s. Os testes do `Frila-Local` tomaram 25m45s, a compilação deles 2m35s, e os builds do Dev, do Beta e do Prod, 1m59s, 4m20s e 3m44s. Na época, o workflow disparava em pull request e em push no `main`, e um push novo cancelava a execução anterior do mesmo PR. O limite subiu de 45 para 70 minutos quando os testes de interface do push (#8) entraram, e para 90 minutos em 04/10/2026 após o crescimento da suíte de testes de interface (ciclo ponta a ponta e fluxos de cancelamento com motivo), evitando cancelamentos perto do fim que desperdiçam 70 minutos e voltam inteiros à fila. PRs que alteram apenas documentação (`!iOS/**/*.md`, `!iOS/Docs/**`) não disparam o workflow, poupando ~100 minutos de macOS por PR; PRs que alteram apenas testes (`iOS/Tests/**`) rodam os testes, mas pulam os builds de Release (`Frila-Dev`, `Frila-Beta` e `Frila-Prod`) e suas conferências, economizando cerca de 7m30s a 8m30s por execução. Separar os três builds num job paralelo encurtaria a espera, mas gastaria mais cota, porque a preparação e a compilação dos pacotes se repetiriam; não foi feito.

Em outubro de 2026 o job único chegou perto do limite: na 37244334865 (push no `main`, 05/10) ele terminou em 85m45s, 75 deles no passo de testes. A primeira tentativa do PR #147 separou a interface num job e deixou os unitários e os builds de Release em outro. O job de interface levou 81m09s na 37241695780 e foi cortado nos 90 minutos na 37251084274. Nessa execução, as 16 primeiras classes levaram 46,5 minutos, contra 38,8 na 37241695780. Daí as duas partes de hoje, com os builds de Release na parte 2 em vez de num terceiro job.

Paralelismo de testes no simulador: medido e descartado em 03/10/2026 no PR #102. Tentar rodar os testes em paralelo no xcodebuild (`-parallel-testing-enabled YES -maximum-parallel-testing-workers 2`) subiu o tempo do passo de testes de 42-53 minutos para 67m45s (estourando o limite de 70 minutos do workflow) e causou 8 falhas espúrias por lentidão extrema. O runner `macos-26` do GitHub Actions tem apenas 3 vCPUs; subir e manter dois clones de simulador concorrentes sobrecarrega a CPU (só o boot inicial levou 10m20s) e quebra a sincronização de acessibilidade do XCUITest. O simulador único sequencial é 15 a 25 minutos mais rápido e 100% determinístico. Não ligue paralelismo de simulador na CI sem runners com mais núcleos dedicados.

## Suíte completa no main: agendada

Desde 12/10/2026, o `ios.yml` não dispara mais a cada push no `main`. A suíte completa roda agendada diariamente às 06h UTC e por disparo manual.

Motivo e números do mapa (11–12/10/2026):
- Em 29 h, de 14 pushes no `main`, apenas 2 terminaram verdes: 9 foram cancelados pelo merge seguinte (`cancel-in-progress`), desperdiçando 362 minutos de runner macOS e 399,5 minutos de fila sem validar nada; 3 falharam.
- Cada PR já passa na suíte completa antes do merge; repetir a execução a cada push congestionava os runners macOS.

Para disparar à mão no `main` (ex.: antes de tag de TestFlight):
```sh
gh workflow run ios.yml --ref main
```

## Medição de PR e CI em 12/10/2026

Amostra fixa obtida por `gh run list --limit 40 --json databaseId,conclusion,createdAt,updatedAt,headBranch,event`, antes deste PR. As 40 execuções retornadas pertencem ao `ios.yml`: 18 passaram, 10 falharam e 12 foram canceladas. Dados de etapas vêm de `gh api repos/FrilaApp/frila-frontend/actions/runs/<id>/jobs?per_page=100`; tentativas anteriores vêm de `/attempts/<n>/jobs`. Os logs de falha foram lidos com `gh run view <id> --attempt <n> --log-failed`, filtrando os diagnósticos reais `##[error]`, sem contar o texto dos comandos como erro.

Inferência: relógio é `updatedAt - createdAt`, incluindo fila e espera por reexecução. Minutos de macOS são a soma de `completed_at - started_at` de cada job executado, em todas as tentativas. Jobs aprovados reapresentados na tentativa seguinte são deduplicados pelo nome e pelos horários, para não contar duas vezes o mesmo trabalho. É ocupação observada do runner, sem multiplicador de cobrança nem arredondamento por minuto. Uma execução cancelada não é uma prova de suíte completa.

| Amostra | Execuções | Mediana de relógio, min | Mediana de macOS, min |
|---|---:|---:|---:|
| Todas | 40 | 72.91 | 110.02 |
| Aprovadas, incluindo reexecuções | 18 | 112.82 | 118.12 |
| Aprovadas na primeira tentativa | 15 | 103.93 | 117.62 |

Os números de cada execução ficam abaixo. Fonte de cada linha: página da execução e metadados dos jobs dessa execução.

| Execução | Resultado | Tentativas | Relógio, min | macOS, min |
|---|---|---:|---:|---:|
| [38234482503](https://github.com/FrilaApp/frila-frontend/actions/runs/38234482503) | failure | 1 | 67.05 | 126.67 |
| [38227733237](https://github.com/FrilaApp/frila-frontend/actions/runs/38227733237) | success | 1 | 61.93 | 117.95 |
| [38226467370](https://github.com/FrilaApp/frila-frontend/actions/runs/38226467370) | failure | 1 | 68.05 | 130.17 |
| [38216257700](https://github.com/FrilaApp/frila-frontend/actions/runs/38216257700) | failure | 1 | 76.65 | 76.33 |
| [38215604811](https://github.com/FrilaApp/frila-frontend/actions/runs/38215604811) | success | 2 | 110.85 | 168.63 |
| [38215055981](https://github.com/FrilaApp/frila-frontend/actions/runs/38215055981) | failure | 1 | 69.17 | 120.70 |
| [38210713834](https://github.com/FrilaApp/frila-frontend/actions/runs/38210713834) | cancelled | 1 | 57.25 | 108.47 |
| [38209791089](https://github.com/FrilaApp/frila-frontend/actions/runs/38209791089) | cancelled | 1 | 13.38 | 24.67 |
| [38205877694](https://github.com/FrilaApp/frila-frontend/actions/runs/38205877694) | cancelled | 1 | 54.55 | 3.92 |
| [38205720848](https://github.com/FrilaApp/frila-frontend/actions/runs/38205720848) | cancelled | 1 | 2.47 | 2.85 |
| [38204793157](https://github.com/FrilaApp/frila-frontend/actions/runs/38204793157) | success | 1 | 134.93 | 122.90 |
| [38201170765](https://github.com/FrilaApp/frila-frontend/actions/runs/38201170765) | success | 1 | 135.33 | 118.32 |
| [38200440540](https://github.com/FrilaApp/frila-frontend/actions/runs/38200440540) | success | 1 | 133.88 | 106.27 |
| [38199793161](https://github.com/FrilaApp/frila-frontend/actions/runs/38199793161) | cancelled | 1 | 9.73 | 19.43 |
| [38199334771](https://github.com/FrilaApp/frila-frontend/actions/runs/38199334771) | cancelled | 1 | 95.48 | 16.40 |
| [38199224104](https://github.com/FrilaApp/frila-frontend/actions/runs/38199224104) | failure | 1 | 102.07 | 106.58 |
| [38198484847](https://github.com/FrilaApp/frila-frontend/actions/runs/38198484847) | cancelled | 1 | 13.10 | 23.73 |
| [38197917880](https://github.com/FrilaApp/frila-frontend/actions/runs/38197917880) | success | 1 | 117.72 | 96.38 |
| [38197380903](https://github.com/FrilaApp/frila-frontend/actions/runs/38197380903) | cancelled | 1 | 8.17 | 16.27 |
| [38195226860](https://github.com/FrilaApp/frila-frontend/actions/runs/38195226860) | cancelled | 1 | 91.18 | 95.45 |
| [38195190782](https://github.com/FrilaApp/frila-frontend/actions/runs/38195190782) | failure | 1 | 143.02 | 110.07 |
| [38194882234](https://github.com/FrilaApp/frila-frontend/actions/runs/38194882234) | success | 1 | 161.63 | 126.85 |
| [38194800402](https://github.com/FrilaApp/frila-frontend/actions/runs/38194800402) | cancelled | 1 | 56.97 | 57.07 |
| [38193874852](https://github.com/FrilaApp/frila-frontend/actions/runs/38193874852) | success | 1 | 82.67 | 117.62 |
| [38190911547](https://github.com/FrilaApp/frila-frontend/actions/runs/38190911547) | success | 1 | 114.80 | 118.53 |
| [38190908779](https://github.com/FrilaApp/frila-frontend/actions/runs/38190908779) | success | 1 | 59.62 | 113.88 |
| [38190829419](https://github.com/FrilaApp/frila-frontend/actions/runs/38190829419) | cancelled | 1 | 62.15 | 113.70 |
| [38175884230](https://github.com/FrilaApp/frila-frontend/actions/runs/38175884230) | success | 1 | 59.83 | 111.28 |
| [38172870868](https://github.com/FrilaApp/frila-frontend/actions/runs/38172870868) | cancelled | 1 | 44.12 | 11.02 |
| [38168810693](https://github.com/FrilaApp/frila-frontend/actions/runs/38168810693) | success | 1 | 146.35 | 111.47 |
| [38168778372](https://github.com/FrilaApp/frila-frontend/actions/runs/38168778372) | success | 2 | 386.93 | 155.20 |
| [38168644182](https://github.com/FrilaApp/frila-frontend/actions/runs/38168644182) | failure | 1 | 115.30 | 109.48 |
| [38168624486](https://github.com/FrilaApp/frila-frontend/actions/runs/38168624486) | success | 1 | 103.93 | 113.80 |
| [38168621318](https://github.com/FrilaApp/frila-frontend/actions/runs/38168621318) | success | 1 | 59.87 | 96.85 |
| [38166754146](https://github.com/FrilaApp/frila-frontend/actions/runs/38166754146) | success | 1 | 62.93 | 121.62 |
| [38162148668](https://github.com/FrilaApp/frila-frontend/actions/runs/38162148668) | success | 1 | 65.68 | 118.28 |
| [38147538344](https://github.com/FrilaApp/frila-frontend/actions/runs/38147538344) | failure | 1 | 110.78 | 108.85 |
| [38147273572](https://github.com/FrilaApp/frila-frontend/actions/runs/38147273572) | success | 2 | 270.52 | 156.87 |
| [38147187284](https://github.com/FrilaApp/frila-frontend/actions/runs/38147187284) | failure | 1 | 89.05 | 95.02 |
| [38147026271](https://github.com/FrilaApp/frila-frontend/actions/runs/38147026271) | failure | 1 | 60.03 | 109.97 |

Inferência: nas 15 execuções aprovadas na primeira tentativa, a mediana por etapa foi 3,80 min para `build-for-testing` (30 jobs), 53,17 min para os testes da parte 1 (15 jobs), 41,70 min para os testes da parte 2 (15 jobs), 1,97 min para Dev, 5,07 min para Beta e 4,30 min para Prod (11 jobs com cada build). Restaurar SPM levou 0,28 min (30 jobs). Capturas não têm etapa própria: estão incluídas na interface. Duração isolada das capturas não encontrada nos metadados de etapas, buscados nos 40 jobs e nos logs de falha; não tratar o tempo da interface como tempo de captura.

### Falhas e repetições

| Teste ou portão | Execuções com o diagnóstico | Diagnóstico lido |
|---|---|---|
| `Carregar com a contestação já aberta no servidor entra em análise e bloqueia nova contestação` | 38147026271, 38147187284, 38147538344 | `emAnalise` falso |
| `testExportarMeusDadosErroServidorMostraAvisoDeErro` | 38168644182 | Botão ausente e falha no toque |
| `testToqueComOAppAbertoEmNotificacaoDeTurnoAbreMeuTurno` | 38195190782 | Destino esperado ausente |
| `testPerguntaSimNaoEmOrdemComRotuloValorESelecao` | 38199224104 | Falha ao terminar o app |
| `testEnvioDeAvaliacaoPelaRotaDiretaMostraConfirmacao` | 38215055981 | Confirmação ausente |
| `testPerfisComESemHistoricoEmAX5` | 38216257700, 38226467370 | Perfil não inteiramente visível |
| `Conferir textos, tokens e datas dos dublês` | 38216257700 | Três datas fixas nos dublês; também houve falha de interface na parte 2 |
| `testEnderecoEQuemRecebeDoTurnoCanceladoNaoCortamEmAX5` | 38234482503 | `XCTAssertTrue` reprovou |

Além dessas dez execuções reprovadas, três execuções terminaram aprovadas depois de uma segunda tentativa no mesmo commit: 38147273572 (`testPilulaDeFiltroNaoDependeApenasDeCor`, falha ao terminar o app), 38168778372 (`testToqueComOAppFechadoAbreODestino`, destino ausente) e 38215604811 (`testCapturasDoCatalogoEmAX5`, timeout ao lançar o app). Inferência: são três repetições compatíveis com instabilidade, comprovadas pelo mesmo SHA e pela mudança de resultado; isso não prova a causa do erro. Cada uma repetiu somente a parte reprovada. Não foi encontrada outra reexecução no mesmo SHA na amostra; branches iguais com commits distintos não contam como repetição de instável.

### Mudança e alternativas

O workflow inicia o boot depois de escolher o simulador e aguarda `simctl bootstatus -b` antes dos testes. Assim o boot pode terminar durante `build-for-testing`, sem alterar os testes selecionados. `-parallel-testing-enabled NO` fica explícito nas duas partes para manter um único simulador por runner. Os portões de contrato, os builds de Release e a publicação do xcresult de falha continuam obrigatórios nas mesmas condições.

| Medida | Decisão | Ganho estimado e risco |
|---|---|---|
| Antecipar boot e esperar prontidão | Implementada | Inferência: de 0 a 3,80 min por job podem sobrepor a espera de boot, usando a mediana da compilação como limite superior da estimativa. Ganho real fica na comparação do PR. Risco: CPU dividida durante a compilação pode reduzir esse ganho. Falha de boot continua reprovando o job. |
| Cache de SPM | Mantido | Já existe e foi usado na amostra. Ganho adicional desta missão: 0 min. |
| Cache de DerivedData | Adiado | `[A DEFINIR]`: não há comparação de cache frio/quente de módulos. Produtos de build contêm configuração injetada e permanecem fora do cache. |
| Cancelar execução anterior e excluir docs e `.workers` | Mantido | Já existe. Ganho adicional: 0 min; `iOS/Contrato/**` continua disparando os portões. Não trocar por `paths-ignore` amplo. |
| Unitários separados de toda a interface | Descartado | O documento registra a tentativa anterior: interface inteira excedeu 90 min. Ganho seguro não encontrado. |
| Terceiro job só de Release | Adiado | `[A DEFINIR]`: poupa o trecho de Release no caminho crítico, mas repete preparação e pode aumentar fila/cota. Não há runner adicional garantido. |
| Quarentena | Não aplicada | Nenhum teste removido, pulado ou enfraquecido. Ainda é preciso diagnóstico e ticket específico antes de propor quarentena; falha de assert não é automaticamente instável. |
| Reexecutar automaticamente job reprovado | Adiado | `[A DEFINIR]`: três tentativas históricas já repetem somente a parte reprovada. Automação exigiria permissão de escrita em Actions e classificação de falhas; repetição incondicional pode esconder regressão. Para repetir somente jobs reprovados, usar `gh run rerun <id> --failed`. |

O limite desta missão é duas execuções de CI, confirmado pelo Nick Fury. A tabela antes/depois, o resultado dos checks e os tempos da execução deste PR serão registrados no corpo do PR, após a CI. Uma execução por desenho é evidência pontual, não uma estimativa confiável de melhora da mediana futura.

`AGENTS.md` não foi alterado. Sugestão para o Nick Fury: registrar o teto explícito de CI por missão, exigir `gh run rerun <id> --failed` ao repetir instável identificado e conservar o SHA e o motivo de cada reexecução. Os scripts locais de prova e merge foram apenas lidos. `merge-quando-verde.sh` confere conclusão e SHA; `prova-e-merge.sh` já espera o boot antes da prova local. A fila do `xcb.sh` é da máquina local e não se aplica aos runners independentes do GitHub.

## Mandar um build ao TestFlight

O workflow `.github/workflows/testflight.yml` arquiva, assina, confere e manda o app ao TestFlight
(#203). Todo o trabalho fica em `Scripts/enviar-testflight.sh`, que roda igual na CI e na máquina de
quem precisar reproduzir. Ele não mexe na CI de PR.

### Quando roda

- **Tag `vX.Y.Z` num commit do `main`**: manda o esquema da tag com a versão `X.Y.Z`. Hoje o esquema
  é o `Frila-Beta` (Release apontando para o frila-dev), o que o cartão pede para o 0.4 e o 0.5. Uma
  tag fora do `main` é recusada.
- **Disparo manual** (Actions > TestFlight > Run workflow): escolhe o esquema (`Frila-Beta` ou
  `Frila-Prod`), a versão, o ensaio de falha, o build de medição e se envia. Com "Enviar ao
  TestFlight" desmarcado, o job faz o archive, a assinatura, a conferência e os símbolos e para antes
  do envio.
- **Prod como padrão da tag**: no `testflight.yml`, apague a linha `ESQUEMA_DA_TAG: Frila-Beta` e
  descomente a `# ESQUEMA_DA_TAG: Frila-Prod` logo abaixo. Faça isso quando o frila-prod tiver as
  migrações (cartão do ambiente de produção, 29/10). Até lá, um build Prod abriria contra um banco
  vazio. Os dois esquemas têm o mesmo bundle id e vão para o mesmo app no App Store Connect.

### O que o job faz

1. Confere a tag (no `main`, formato `vX.Y.Z`) ou as entradas do disparo manual, e calcula o número
   do build.
2. Seleciona o Xcode 26.6 e restaura os pacotes SPM do cache da CI de PR, só para leitura.
3. Gera o `Secrets.xcconfig` e o `GoogleService-Info.plist` do ambiente: dev para o Beta, prod para o
   Prod.
4. Grava a chave `.p8` num arquivo temporário com permissão 600.
5. Roda o `Scripts/enviar-testflight.sh`:
   1. **Archive** com a versão e o número do build, na assinatura automática de desenvolvimento do
      projeto. Com `-allowProvisioningUpdates` e a chave, o xcodebuild cria o perfil e o certificado
      de desenvolvimento que faltarem na máquina da CI. A assinatura ad hoc não serve: o Xcode exige
      perfil para o app iOS (medido em 03/10).
   2. **Export** para o App Store Connect com assinatura automática. O Xcode cria o perfil de
      distribuição e usa um certificado gerenciado na nuvem pela Apple. O certificado de distribuição
      e a chave privada dele não ficam no repositório nem nos segredos; o único segredo novo é a
      chave da API.
   3. **Conferência** do app assinado: o `conferir-release.sh` (criptografia, privacidade, ganchos de
      Debug, `aps-environment` de produção) e `get-task-allow` falso.
   4. **Símbolos**: o dSYM do app e o dos quatro frameworks vão ao Crashlytics do ambiente, com duas
      tentativas. Se não subirem, o build não vai ao TestFlight. A Apple também recebe os símbolos
      (`uploadSymbols`).
   5. **Envio**: um segundo export, com `destination: upload` e a mesma assinatura.
6. Apaga a chave, os segredos, o archive, o `.ipa` e o DerivedData, mesmo quando uma etapa falha.
   Nada vira artefato do Actions, porque o `.ipa` traz o plist do Firebase e a chave publicável do
   Supabase.

Regras do build:
- **Versão:** sai da tag (`v0.4.0` vira `0.4.0`). O `MARKETING_VERSION` do `project.yml` não muda.
- **Número do build:** data e hora UTC do início do job, `AAAAMMDD.HHMMSS`, sem zero à esquerda na
  segunda parte (`20261020.93015` é 09:30:15). É único e crescente entre execuções, reexecuções e
  máquinas, sem consultar o App Store Connect. O Xcode não pode trocá-lo no envio
  (`manageAppVersionAndBuildNumber` desligado).
- **Criptografia:** o `Info.plist` declara `ITSAppUsesNonExemptEncryption` como `false`, conferido
  pelo `conferir-release.sh`. Por isso o build não pede a resposta manual sobre criptografia.

### O que o Cauê faz uma vez

1. **Chave da App Store Connect API.** Em App Store Connect > Users and Access > Integrations > App
   Store Connect API:
   - Se a API ainda não estiver liberada, clique em Request Access (só o Account Holder pode).
   - Em **Team Keys**, clique em Generate API Key, com o nome `GitHub Actions TestFlight` e o acesso
     **Admin**.
   - Anote o **Key ID** e o **Issuer ID** e baixe o `.p8`. A Apple só deixa baixar uma vez.

   Por que Admin:
   - Na tabela de papéis da Apple, só Account Holder e Admin têm de fábrica "Upload builds" e "Create
     other cloud-managed certificate types". App Manager e Developer dependem de permissões extras,
     dadas a pessoas em Users and Access.
   - A chave de equipe só recebe o papel, não essas permissões extras. Por isso Admin é o mínimo
     documentado para uma chave de equipe.
   - Uma chave individual de alguém com papel Developer e essas permissões também serviria, mas
     prende a CI a uma pessoa.
2. **Segredos do GitHub** (Settings > Secrets and variables > Actions > New repository secret, no
   `FrilaApp/frila-frontend`):

   | Segredo | Conteúdo |
   |---|---|
   | `APP_STORE_CONNECT_API_KEY_ID` | o Key ID |
   | `APP_STORE_CONNECT_API_ISSUER_ID` | o Issuer ID |
   | `APP_STORE_CONNECT_API_KEY_P8` | o conteúdo do `.p8`, inteiro, com as linhas `BEGIN` e `END` |

   O `.p8` pode ir direto do arquivo, sem passar pela tela:
   `gh secret set APP_STORE_CONNECT_API_KEY_P8 --repo FrilaApp/frila-frontend < AuthKey_XXXXXXXXXX.p8`.
   Depois, guarde o `.p8` no cofre do time ou apague-o; ele nunca entra no Git.

   O job também usa seis segredos que já existem para a CI de PR:
   - `FRILA_SUPABASE_DEV_URL` e `FRILA_SUPABASE_DEV_PUBLISHABLE_KEY`;
   - `FRILA_SUPABASE_PROD_URL` e `FRILA_SUPABASE_PROD_PUBLISHABLE_KEY`;
   - `FRILA_FIREBASE_GOOGLE_SERVICE_INFO_DEV_B64` e `FRILA_FIREBASE_GOOGLE_SERVICE_INFO_PROD_B64`.
3. **TestFlight.** Depois dos três segredos, use o workflow **App Store Connect** descrito abaixo
   para preparar o grupo interno com os cinco, com acesso a todos os builds. As notas "O que testar"
   de cada build continuam sendo escritas no App Store Connect.

### Operar a App Store Connect pela API

O `.github/workflows/app-store-connect.yml` só roda por `workflow_dispatch`, com os mesmos três
segredos da chave de equipe Admin usados pelo TestFlight. `Scripts/app-store-connect.rb` assina
um JWT ES256 em memória; nem a chave `.p8` nem o token viram arquivo ou artefato. Se faltar algum
segredo, a primeira etapa depois do checkout falha indicando os nomes, antes de acessar a API.
Esse workflow não compila nem envia o app.

Em **Actions > App Store Connect > Run workflow**, no `main`:

1. Rode primeiro `acao=conferir`, com `aplicar` desmarcado. O log mostra o app `com.frila.org.app`,
   grupos, contagem de testadores por grupo, cada `appInfo` e suas respostas de classificação.
   `conferir` sempre faz somente GET, mesmo se `aplicar` estiver marcado.
2. Para o grupo, escolha `acao=grupo-interno`, informe o nome exato (padrão `Equipe Frila`) e os
   cinco e-mails no campo `testadores`, separados por vírgula. Rode primeiro sem `aplicar` para ver
   o plano e depois com `aplicar` para executá-lo. Um grupo interno com esse nome é reutilizado;
   deve já ter `hasAccessToAllBuilds=true`. A API aceita esse atributo na criação, mas não no
   `BetaGroupUpdateRequest`; se estiver desabilitado num grupo existente, o job para sem alterações.
   Um nome externo ou duplicado também interrompe a operação.
   Ninguém é removido. O script só inclui usuários que já constam na equipe, com papel elegível e
   acesso ao app; ele não cria convites de equipe nem altera papéis ou permissões.
3. Para a classificação, escolha `acao=classificacao` e confira `verificacao_idade`: marcado
   quando a versão incluir Declared Age Range do PR 95, desmarcado caso contrário. O plano segue
   o questionário do cartão #215: conteúdo gerado pelo usuário Sim, chat Não, os demais itens Não
   ou Nenhum, fora de Made for Kids, e `ageRatingOverrideV2=EIGHTEEN_PLUS`. Para aplicar, marque
   também `sem_referencias_alcool` **depois da confirmação pessoal** exigida pelo item 5 do arquivo
   de passos. Sem essa confirmação, a consulta e o plano funcionam, mas a escrita é recusada.
   Só um `appInfo` em `PREPARE_FOR_SUBMISSION` pode ser alterado. Se não existir, o script para;
   não cria nem envia uma versão. Após o PATCH, relê e confere as respostas, mostrando antes e depois.

E-mails não entram no repositório nem no log do script. Cada resultado usa **Testador 1, 2, …**, na
ordem da lista do disparo, inclusive quando há repetição. Guarde essa ordem para identificar quem
ficou de fora. Pendência de convite, papel ou acesso inadequado e recusas individuais da Apple são
reportadas; o job termina com falha se alguém não pôde entrar, preservando as associações aceitas.
Uma repetição consulta o estado atual e não duplica grupo nem associações. As entradas do disparo
ficam no evento do GitHub Actions: não são um segredo do repositório. Restrinja o acesso ao workflow
à equipe que já pode administrá-lo; não cole esses dados em PRs, exemplos ou relatórios.

As entradas são lidas de `GITHUB_EVENT_PATH`, sem interpolação em comandos ou em `env:` que o runner
imprimiria antes do mascaramento. O script registra máscaras `::add-mask::` para chave, linhas da
chave, IDs, JWT e e-mails da entrada.
Não use depuração de shell, não imprima as variáveis e não publique o payload do evento.

Prova local sem rede e sem chave:

```sh
ruby iOS/Scripts/teste-app-store-connect.rb
```

As respostas são exemplos sintéticos em `Scripts/FixturesAppStoreConnect/respostas.json`; o
transporte e a assinatura dos testes são fictícios. A prova real permanece pendente até a chave:
autenticação e permissões, existência e editabilidade do `appInfo`, aceitação dos testadores e
distribuição de um build processado. O log lê a classificação calculada no `appInfo` e verifica
o override 18+. A apresentação **Operating Systems Earlier than Version 26** não foi encontrada
nessa resposta da API e continua exigindo conferência separada; não é inferida como 18+.

Fontes oficiais das chamadas:

- [Autenticação JWT](https://developer.apple.com/documentation/appstoreconnectapi/generating-tokens-for-api-requests)
  e [listar apps](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-apps).
- [Criar grupo](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-betagroups),
  [atributos da criação](https://developer.apple.com/documentation/appstoreconnectapi/betagroupcreaterequest/data-data.dictionary/attributes-data.dictionary),
  [limites dos atributos de atualização](https://developer.apple.com/documentation/appstoreconnectapi/betagroupupdaterequest/data-data.dictionary/attributes-data.dictionary),
  [listar grupos do app](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-apps-_id_-betagroups)
  e [listar testadores do grupo](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-betagroups-_id_-betatesters).
- [Listar usuários da equipe](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-users),
  [apps acessíveis ao usuário](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-users-_id_-visibleapps),
  [listar testadores](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-betatesters),
  [criar recurso TestFlight](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-betatesters)
  e [associar ao grupo](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-betagroups-_id_-relationships-betatesters).
- [Listar app infos](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-apps-_id_-appinfos),
  [ler declaração](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-appinfos-_id_-ageratingdeclaration),
  [alterar declaração](https://developer.apple.com/documentation/appstoreconnectapi/patch-v1-ageratingdeclarations-_id_)
  e [atributos do questionário e override 18+](https://developer.apple.com/documentation/appstoreconnectapi/ageratingdeclarationupdaterequest/data-data.dictionary/attributes-data.dictionary).

**Inferência:** `hasAccessToAllBuilds=true` corresponde à distribuição automática descrita na
[ajuda da Apple](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers).
A referência do atributo não explica essa equivalência; confirmar com o primeiro build processado.
Os documentos de `appInfos` e da declaração permitem a edição antes de submeter o app à revisão;
a ausência de exigência de build enviado nesse caminho também é inferência, a conferir no Frila.

### Mandar o 0.4 (20/10)

```sh
git switch main && git pull
git tag -a v0.4.0 -m "Build 0.4 do TestFlight"
git push origin v0.4.0
```

Acompanhe em Actions > TestFlight. O resumo do job mostra o esquema, a versão e o número do build.
Depois do envio, o App Store Connect ainda processa o build antes de ele aparecer no TestFlight.

### Ensaio de falha (critério do #203, antes de 20/10)

1. Em Actions > TestFlight > Run workflow, escolha o `main`, o `Frila-Beta`, a versão `0.4.0`, e
   marque "Ensaio de falha" e "Enviar ao TestFlight".
2. Quando o build aparecer no TestFlight do grupo interno, instale-o no iPhone e abra.
3. Toque em **Forçar falha (ensaio)**, no canto inferior esquerdo de qualquer tela. O app fecha.
4. Abra o app de novo, sem reinstalar: o relatório sai nesse segundo lançamento.
5. No Firebase, projeto do frila-dev, abra o Crashlytics. A falha "Falha forçada do ensaio do
   TestFlight" deve aparecer na versão 0.4.0, com o número do build, e com a pilha simbolizada:
   `BotaoDeFalhaDoEnsaio` em `FalhaDoEnsaio.swift`. Em 30/09, num build de Debug, a falha levou cerca
   de 2 minutos para aparecer ([Relatório de falhas](CrashReporting.md)).

O ensaio não afeta o build de produção, por quatro travas:
- O botão só compila com `FRILA_ENSAIO_FALHA`, que só o disparo manual liga; tag nunca liga.
- O build de ensaio vai marcado `testFlightInternalTestingOnly`: segundo o `xcodebuild -help`, ele
  "cannot be distributed via external TestFlight or the App Store".
- O `conferir-release.sh` reprova o botão em qualquer outro Release, inclusive nos builds da CI de PR.
- O 0.4 de verdade sai depois, pela tag, com outro número de build e sem o botão.

### Build de medição (#73)

Em Actions > TestFlight > Run workflow, escolha o `main`, o `Frila-Beta` e a versão atual, e marque
"Build de medição" e "Enviar ao TestFlight". O build compila a medição de desempenho e de dados
(`FRILA_MEDICAO`) e tem as mesmas travas do ensaio:
- só o disparo manual liga a condição;
- o build vai marcado `testFlightInternalTestingOnly`;
- o `conferir-release.sh` reprova a medição em qualquer outro Release.

O roteiro do aparelho está em [Desempenho e dados](Desempenho.md).

### Reproduzir na própria máquina

```sh
cd iOS
Scripts/generate-supabase-secrets.sh dev      # com FRILA_SUPABASE_DEV_URL e a chave publicável no ambiente
Scripts/inject-firebase-config.sh dev         # com FRILA_FIREBASE_GOOGLE_SERVICE_INFO_DEV_B64 no ambiente
ASC_KEY_PATH=~/caminho/AuthKey.p8 ASC_KEY_ID=... ASC_ISSUER_ID=... \
  Scripts/enviar-testflight.sh Frila-Beta 0.4.0 --sem-envio
```

Sem as três variáveis `ASC_*`, o script usa a conta logada no Xcode da máquina. Sem `--sem-envio`,
ele manda ao TestFlight. Com `FRILA_ENSAIO_FALHA=1`, ele monta o build de ensaio; com
`FRILA_MEDICAO=1`, o build de medição.

### O que a primeira execução real ainda prova

Em 03/10 o caminho rodou numa máquina do time, com `--sem-envio` e a conta do Xcode no lugar da
chave. Passaram o archive, o export, a conferência do app assinado e os símbolos no Crashlytics. A
máquina já tinha certificado de distribuição, então quatro coisas só a primeira execução no Actions
prova:
- se a chave Admin cria o que falta e assina na nuvem. O runner começa sem certificado nenhum.
  Inferência: o archive pode criar um certificado Apple Development a cada execução. Se eles se
  acumularem em Certificates, Identifiers & Profiles, revogue os antigos; o xcodebuild cria outro
  quando precisar;
- se o App Store Connect aceita o envio e o número do build;
- se o `upload-symbols` roda no runner. Ele caiu com Segmentation fault num build de simulador em
  30/09, e por isso tem duas tentativas;
- quanto tempo o job leva.

Um disparo manual com "Enviar ao TestFlight" desmarcado prova a assinatura na nuvem e os símbolos
no runner, sem mandar nada ao TestFlight.

### Custo

O job usa o mesmo runner `macos-26` da CI de PR e roda só por tag ou disparo manual. Ele consome a
mesma cota de minutos da organização, que tem orçamento de US$ 0 com bloqueio de uso adicional: sem
cobrança.
