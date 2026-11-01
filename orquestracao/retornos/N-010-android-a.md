# N-010 · Android A · retorno de 01/11/2026

**Estado: parcial. Cartões fechados por prova: nenhum.** As três primeiras entregas estão em PRs rascunho, sem merge. Responsável: Cauê; execução: OpenAI Codex (GPT-6); coordenação: Orquestrador.

Trabalho realizado somente nesta worktree, uma branch de `origin/main` por cartão. A pasta real é `android/`, em minúsculas; `git log ... -- Android` não devolveu histórico, então também conferi `-- android`. ECO: arquivo de estado ausente. Li `AGENTS.md`, `docs/android/README.md` e `BANCADA.md`. Executei `git fetch` e consultei PRs Android/histórico antes de cada cartão. O único PR anterior encontrado, #527, toca apenas notificações; não há sobreposição com estes arquivos. O swipe-to-refresh já existe na main e não foi duplicado.

Os comandos de teste abaixo partem de `android/`, com JDK 17 e SDK locais configurados por ambiente. Gradle serializado: um processo de build por vez. Nenhum simulador/emulador ligado. Fixtures novas são sintéticas. Referências a arquivos dos cartões 61/64 pertencem às respectivas branches, pois os PRs são independentes.

## Cartão 61 · cache de vagas

Branch `noite/android-a-61`, commit `3d1b16e0`, [PR #617](https://github.com/FrilaApp/frila-frontend/pull/617), [cartão](https://trello.com/c/YRujXnfW).

| Critério | Cumprido? | Prova: comando, saída e arquivo:linha | PR |
| --- | --- | --- | --- |
| Primeira entrega: repositório com cache em memória e disco | sim | `./gradlew :core:rede:testDebugUnitTest` → BUILD SUCCESSFUL, 86 testes, zero falhas; 8 novos. `android/core/rede/src/test/kotlin/br/com/frila/core/rede/RepositorioVagasTest.kt:25` reabre instância e recupera disco; `:31` apaga disco e recupera memória. | #617 |
| Testes JVM de fallback sem rede devolvem cache | sim | Mesmo comando/saída; `RepositorioVagasTest.kt:25`, `:31` e `:77`. Sem cache ou com corrupção preserva erro (`:40`, `:47`); servidor/cancelamento não viram fallback (`:61`, `:69`). | #617 |
| App abre exibindo cache sem tela branca | não | Não executado: repositório ainda não integrado ao feed nem à injeção de dependências. `android/feature/vagas/src/main/kotlin/br/com/frila/feature/vagas/feed/FeedVagasViewModel.kt:68` continua usando o serviço. | #617 |
| Indicador visual de dados em cache offline | não | Não executado: há `ResultadoVagas.emCache`, mas nenhuma integração visual. `android/core/rede/src/main/kotlin/br/com/frila/core/rede/RepositorioVagas.kt:16`. | #617 |
| Swipe-to-refresh | parcial | Já presente na main: `android/feature/vagas/src/main/kotlin/br/com/frila/feature/vagas/feed/TelaFeedVagas.kt:89` e `FeedVagasViewModel.kt:83`. Conferido por leitura; gesto e suíte de vagas não executados nesta entrega de repositório. | Existente na main |

Sensibilidade: `./gradlew :core:rede:test --tests '*RepositorioVagasTest'`, com fallback temporariamente desativado → 8 testes, 4 falhas. Código restaurado e comando do módulo repetido → 86 verdes. Limite: antes de integrar, definir arquivo privado por sessão/consulta e limpeza no logout; não compartilhar cache entre usuários ou consultas.

## Cartão 64 · Preferences DataStore

Branch `noite/android-a-64`, commit `3752c0cb`, [PR #618](https://github.com/FrilaApp/frila-frontend/pull/618), [cartão](https://trello.com/c/cMBNEpRR).

| Critério | Cumprido? | Prova: comando, saída e arquivo:linha | PR |
| --- | --- | --- | --- |
| Primeira entrega: módulo Preferences DataStore com engine real | sim | `./gradlew :core:preferencias:testDebugUnitTest` → BUILD SUCCESSFUL, 5 testes, zero falhas. `android/core/preferencias/src/main/kotlin/br/com/frila/core/preferencias/FabricaPreferencias.kt:17`. | #618 |
| CorruptionHandler restaura arquivo corrompido para o padrão | sim | Mesmo comando/saída; `android/core/preferencias/src/test/kotlin/br/com/frila/core/preferencias/FabricaPreferenciasTest.kt:30` injeta bytes inválidos, verifica padrão vazio e reabre; `:39` grava e reabre após corrupção. | #618 |
| Testes unitários com engine DataStore | sim | Mesmo comando/saída, engine real com arquivos temporários, sem mock. `FabricaPreferenciasTest.kt:48` preserva dados válidos, `:53` não mascara erro de I/O; `:64` encerra escopos entre instâncias. | #618 |
| Migração das preferências de produção para DataStore | não | Não executado: fábrica ainda não injetada no app; filtros/notificações continuam em SharedPreferences. Limite documentado em `docs/android/README.md:81`. | #618 |

Dependência explicitamente pedida pelo cartão: `androidx.datastore:datastore-preferences-core:1.1.1`, variante JVM; build verde com Kotlin 2.0.20, sem atualizar outros componentes. Documentação oficial consultada: [DataStore](https://developer.android.com/jetpack/androidx/releases/datastore). A primeira fatia não altera sessão, dados sensíveis, API ou banco. Nenhuma variável de ambiente nova.

Sensibilidade: `./gradlew :core:preferencias:test --tests '*FabricaPreferenciasTest'`, sem handler temporariamente → 5 testes, 2 falhas por CorruptionException. Handler restaurado e comando do módulo repetido → 5 verdes.

## Cartão 65 · feedback visual e háptico

Branch `noite/android-a-65`, commit de implementação `74db49fd`, [PR #619](https://github.com/FrilaApp/frila-frontend/pull/619), [cartão](https://trello.com/c/EgAcKBQo).

| Critério | Cumprido? | Prova: comando, saída e arquivo:linha | PR |
| --- | --- | --- | --- |
| Primeira entrega: wrapper LocalHapticFeedback integrado | sim | `./gradlew :feature:turnos:testDebugUnitTest` → BUILD SUCCESSFUL, 124 testes, zero falhas; 5 novos Compose/Robolectric. `android/feature/turnos/src/main/kotlin/br/com/frila/feature/turnos/FeedbackAcaoCritica.kt:12`. | #619 |
| Háptico acionado no check-in e na confirmação de cancelamento | sim | Mesmo comando/saída. `android/feature/turnos/src/test/kotlin/br/com/frila/feature/turnos/FeedbackAcaoCriticaTest.kt:48` e `:72` verificam exatamente uma chamada no fake e execução da ação; integração em `TelaMeusTurnos.kt:436` e `:583`. Prova de despacho JVM. | #619 |
| Respeita vibração desativada | sim | Mesmo comando/saída; `FeedbackAcaoCriticaTest.kt:94` desativa a preferência com a tela aberta, confirma ação e nenhuma chamada ao fake. Wrapper consulta configuração em cada toque. | #619 |
| Feedback visual durante ações | sim | Mesmo comando/saída; `FeedbackAcaoCriticaTest.kt:48` verifica “Registrando check-in…”; `:72` verifica “Cancelando…” desabilitado. Estados de produção existentes foram preservados. | #619 |
| Ausência de crash com fake sem háptico | sim | Mesmo comando/saída; `FeedbackAcaoCriticaTest.kt:116`: fake no-op, ação concluída. `:134` também prova que botão sem motivo não emite feedback nem executa a ação. | #619 |
| Ausência de crash em aparelho físico sem motor e vibração física | parcial | Fake no-op passou, mas aparelho/emulador sem motor e vibração física **não executados**. Prova JVM não equivale a hardware. Nenhum aparelho disponível nesta sessão foi utilizado. | #619 |

Sensibilidade: `./gradlew :feature:turnos:testDebugUnitTest --tests '*FeedbackAcaoCriticaTest'`. Sem despacho háptico → 5 testes, 2 falhas; ignorando a configuração → 5 testes, 1 falha. Todas as mutações restauradas; módulo inteiro repetido → 124 verdes. Nenhuma dependência nova. Provas de TalkBack/inspeção física não executadas. O feedback sinaliza o toque, sem prometer sucesso da operação.

## Revisão, comunicação e pendências

Revisão independente em contexto limpo pelo agente `revisao_android`: cartões 61/64 e depois 65, sem achados reais por leitura; não executou Gradle nem aparelho. Resultado informado ao Orquestrador. Builds finais verdes: 86 + 5 + 124 = **215 testes**, dos quais **18 novos**. `git diff --check` verde nos diffs. Não executei suíte completa do repositório, CI, lint, APK release ou homologação em dispositivo; os comandos de prova pedidos são os dos módulos acima. Nenhum cartão fechado por inferência.

Sem conector Trello disponível nesta sessão. Enviei atualizações imediatas por Maestri após cada cartão; o Orquestrador confirmou comentários nos cartões 61 e 64 e ficou responsável pela movimentação humana. Não mesclei nada. **Não registrei na Bancada**, porque a autorização limita escrita a esta worktree; o Orquestrador foi avisado e informou que consolidará os fatos da madrugada.

Decisões seguras sem acordar o Cauê: fatias pequenas independentes, sem migração de sessão, sem integração offline incompleta, sem emulador e sem marcar prova de hardware como cumprida. Skills utilizadas: [Maestri](/Users/cauecarneiro/.agents/skills/maestri/SKILL.md) para comunicação autorizada e `interaction-design` para feedback complementar ao visual; não introduzi animações.
