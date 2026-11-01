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

## N-021 · continuação dos cartões 61 e 64

**Estado atual: parcial. Cartões com todos os critérios provados: 0.** As tabelas acima são o registro histórico da primeira fatia N-010; esta seção atualiza o estado. Nenhum N-016 foi iniciado nesta sessão. Nenhum merge, force-push, emulador ou alteração no checkout principal. ECO continuou ausente. Antes de cada cartão repeti fetch, listagem de PRs Android e histórico remoto (também `-- android`, pois o diretório é minúsculo).

O #617 continua na branch `noite/android-a-61`, commit de integração `0d682312`. O #618 continua em `noite/android-a-64`, agora **empilhado sobre `noite/android-a-61`**, para conferir cache e preferências juntos sem conflito nos nossos arquivos compartilhados. A incorporação foi por merge normal na branch de trabalho; sem reescrita de histórico. A base do PR #618 é a branch do #617, não `main`.

Comando final integrado, a partir de `android/`, JDK 17/SDK por ambiente: `./gradlew :core:rede:testDebugUnitTest :core:preferencias:testDebugUnitTest :feature:vagas:testDebugUnitTest :app:testDebugUnitTest` → **BUILD SUCCESSFUL**, 224 testes nos relatórios XML, zero falhas/erros/ignorados: rede 86 + preferências 5 + vagas 79 + app 54. Há 12 testes novos nesta continuação (6 por cartão); os módulos sem mudanças conservaram resultados que já vi verdes. Log local `/tmp/N-021-64-final.log`. O gate próprio do #617 também passou: rede 86 + vagas 77 + app 50 = 213 testes, `/tmp/N-021-61-final.log`.

### Cartão 61 · feed offline integrado · [PR #617](https://github.com/FrilaApp/frila-frontend/pull/617)

| Critério | Cumprido? | Prova: comando, saída e arquivo:linha | PR |
| --- | --- | --- | --- |
| Feed recupera disco na abertura lógica sem rede, sem ficar carregando | sim | Gate #617 acima, BUILD SUCCESSFUL/213; `android/feature/vagas/src/test/kotlin/br/com/frila/feature/vagas/feed/FeedOfflineTest.kt:60` reabre repositório com fake SEM_REDE, conclui carga em SUCESSO com os IDs salvos; `:71` prova cache antes de GPS responder e prazo de 3 segundos. `android/app/src/main/kotlin/br/com/frila/app/AppNavegacao.kt:151` inicia carga ao entrar no feed; grafo exercitado em `KoinGrafoTest.kt:110`. | #617 |
| App real abre exibindo cache sem tela branca em aparelho | parcial | Abertura lógica e renderização Compose/Robolectric passaram nos testes acima e `FeedOfflineTest.kt:91`. **Não executado em aparelho/emulador**: nenhum foi iniciado; renderização e modo avião reais não foram homologados. Não declaro esse critério integralmente fechado por teste JVM. | #617 |
| Indicador claro de dados em cache, em português | sim | Mesmo gate/213. `FeedOfflineTest.kt:91` exige aviso visível junto à vaga e sua remoção após atualização. Texto: “Exibindo vagas salvas. Os dados podem estar desatualizados.” Implementação `android/feature/vagas/src/main/kotlin/br/com/frila/feature/vagas/feed/TelaFeedVagas.kt:102`; live region para acessibilidade. | #617 |
| Testes de fallback com rede falhando | sim | Mesmo gate/213; `android/core/rede/src/test/kotlin/br/com/frila/core/rede/RepositorioVagasTest.kt:25` e `FeedOfflineTest.kt:60`. `FeedOfflineTest.kt:84` prova erro explícito sem cache. | #617 |
| Swipe-to-refresh preservado e retira indicador ao recuperar rede | sim | Mesmo gate/213, `FeedOfflineTest.kt:109`: gesto Compose no nó rolável, nova chamada, flag de cache removida e vaga ainda visível. Gesto em dispositivo físico: **não executado**. | #617 |
| Cache separado por identidade estável após renovar sessão | sim | Mesmo gate/213; `android/app/src/test/kotlin/br/com/frila/app/ArquivoCacheVagasTest.kt:22` grava, renova token/registra vínculo, reabre offline; `:33` não persiste sem identidade e separa contas sintéticas. Nome SHA-256 do `sub`, sem token/identidade em texto claro, em `noBackupFilesDir`; uso somente como namespace, sem mudar autenticação. | #617 |

Sensibilidade executada: removendo temporariamente o indicador, `./gradlew :feature:vagas:testDebugUnitTest --tests '*FeedOfflineTest'` → 4 testes, 1 falha (`/tmp/N-021-61-mutacao.log`). Os dois testes de identidade falharam antes da correção (`/tmp/N-021-61-identidade-antes.log`). Todas as alterações de prova restauradas; gate completo verde depois. Revisão independente encontrou o namespace instável, corrigi com regressão e a segunda leitura ficou sem achados.

### Cartão 64 · migração dos filtros · [PR #618](https://github.com/FrilaApp/frila-frontend/pull/618)

| Critério | Cumprido? | Prova: comando, saída e arquivo:linha | PR |
| --- | --- | --- | --- |
| Migrar os valores antigos dos filtros para DataStore sem perda | sim | Gate integrado acima, BUILD SUCCESSFUL/224. `android/app/src/test/kotlin/br/com/frila/app/MigracaoPreferenciasTest.kt:48` grava os três valores legados, resolve adaptador pelo módulo Koin real, confere valores exatos e reabre. `android/app/src/main/kotlin/br/com/frila/app/PreferenciasAndroid.kt:19` usa `SharedPreferencesMigration` com a fábrica de `:core:preferencias`. | #618 |
| Migração não duplica chaves e preserva dados novos em nova abertura | sim | Mesmo gate/224; `MigracaoPreferenciasTest.kt:72` reintroduz legado desatualizado e verifica que os três valores do DataStore prevalecem e SharedPreferences fica vazio. `:84` prova gravação, limpeza e reabertura usando só DataStore. | #618 |
| Filtros assíncronos sem sobrescrever interação durante leitura lenta | sim | Mesmo gate/224; `android/feature/vagas/src/test/kotlin/br/com/frila/feature/vagas/feed/PreferenciasFeedTest.kt:27` e `:50` provam prioridade do toque e ordem de salvar/salvar/limpar. Os três testes existentes de persistência/restauração foram adaptados para aguardar Jobs, preservando suas asserções. | #618 |
| Manter CorruptionHandler e testes com engine real | sim | Mesmo gate/224. `android/core/preferencias/src/main/kotlin/br/com/frila/core/preferencias/FabricaPreferencias.kt:24` preserva handler; cinco testes da engine continuam verdes. `MigracaoPreferenciasTest.kt:101` corrompe o arquivo da integração, volta ao padrão, grava e reabre. Arquivos reais temporários, sem mock de DataStore. | #618 |
| Migrar todas as preferências existentes, incluindo notificações | parcial | Filtros migrados e provados. Notificações permanecem como estão: **depende do #527**, por instrução expressa do Orquestrador no N-021. Não editei `ProcessadorDePush.kt` nem o teste dele, nem outros arquivos de notificações. A migração dessa parte **não foi executada**. Sessão/biometria continuam no armazenamento seguro, fora do escopo de preferências comuns. | #618; pendência #527 |

Sensibilidade executada: `./gradlew :app:testDebugUnitTest --tests '*MigracaoPreferenciasTest'`, com a migração temporariamente removida → 4 testes, **3 falhas** (`/tmp/N-021-64-mutacao.log`); restaurei e repeti o gate completo, verde. A documentação `docs/android/README.md:69` descreve a integração atual e a pendência de notificações. Dependência Android adicional `androidx.datastore:datastore-preferences:1.1.1` fornece a migração oficial, na mesma versão da engine já pedida pelo cartão; sem atualizar Kotlin/AGP, CI, contrato ou sessão. Referência primária consultada: [SharedPreferencesMigration](https://developer.android.com/reference/androidx/datastore/preferences/SharedPreferencesMigrationKt).

Revisão independente final em contexto limpo pelo agente `revisao_android`, incluindo testes de concorrência e grafo real: sem achados restantes; não rodou Gradle. Conferi `git diff --check`, verde. Ambos os PRs continuam em rascunho. Nenhum cartão movido/concluído; Trello segue com o Orquestrador. **Bancada não atualizada nesta worktree**; coordenação já avisada para consolidar. Comunicação imediata do cartão 61 enviada via [skill Maestri](/Users/cauecarneiro/.agents/skills/maestri/SKILL.md); aviso do cartão 64 e resumo N-021 enviados ao concluir.
