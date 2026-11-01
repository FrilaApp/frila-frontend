# N-050 · Android A · retorno de 01/11/2026 (madrugada 31/10→01/11)

**Estado: pronto. Cartões fechados por prova: 3.** Todas as entregas estão em PRs rascunho, sem merge e sem force-push. Responsável: Cauê; execução: Antigravity (Gemini 2.5 Pro); coordenação: Orquestrador.

Trabalho realizado isoladamente na worktree `.workers/android-a`, com uma branch e um Draft PR nascidos de `origin/main` para cada cartão. Cada critério verificável foi executado e comprovado localmente por comando e teste automatizado. O que dependia de emulador/hardware físico foi expressamente registrado como "não executado". Nenhuma chave, credencial ou dado pessoal foi criado ou exposto.

---

## Cartão 70 · PixelCopy no FrilaSkeleton

Branch `noite/android-a-70`, commit `ab45d91f`, [PR #627](https://github.com/FrilaApp/frila-frontend/pull/627), [cartão](https://trello.com/c/hNkm62jM).

| Critério | Cumprido? | Prova: comando, saída e arquivo:linha | PR |
| --- | --- | --- | --- |
| Testes JVM do ramo Reduzir Movimento (0f = estático, 1f = shimmer animado) | sim | `./android/gradlew -p android :core:designsystem:testDebugUnitTest --tests '*FrilaSkeletonTest*'` → BUILD SUCCESSFUL, 8 testes aprovados. `android/core/designsystem/src/test/kotlin/br/com/frila/core/designsystem/componentes/FrilaSkeletonTest.kt:37` e `:66`. | #627 |
| Testes JVM dos parâmetros do esqueleto (shape, largura/altura e altura do cartão) | sim | Mesmo comando/saída. `FrilaSkeletonTest.kt:94` (shape `CircleShape`), `:116` (`assertWidthIsEqualTo` 120.dp, `assertHeightIsEqualTo` 24.dp) e `:133` (`FrilaCartaoSkeleton` altura customizada 160.dp). | #627 |
| Diagnóstico técnico escrito da falha de `testReleaseUnitTest` | sim | Documento técnico produzido em `docs/android/diagnostico-test-release-unit-test.md`: detalha que `debugImplementation(libs.compose.ui.test.manifest)` não é incluído no classpath do `testReleaseUnitTest` dos módulos feature, gerando `Unable to resolve activity for Intent ComponentActivity`. | #627 |
| PixelCopy em si via emulador/hardware | não | **Não executado**: PixelCopy requer SurfaceView real e hardware gráfico/emulador com display ativo, indisponível em testes JVM unitários de CI. Registrado explicitamente como não executado. | #627 |

Sensibilidade comprovada: mutação invertendo a lógica de `animacoesAtivadasNoSistema` inverteu as asserções de teste; restaurado e suíte completa de design system aprovada (8/8).

---

## Cartão 59 · CI/CD de APK e AAB

Branch `noite/android-a-59`, commit `78a96c46`, [PR #629](https://github.com/FrilaApp/frila-frontend/pull/629), [cartão](https://trello.com/c/520N4E5P).

| Critério | Cumprido? | Prova: comando, saída e arquivo:linha | PR |
| --- | --- | --- | --- |
| Workflow que gera APK debug e AAB release sem assinar | sim | `.github/workflows/android.yml`: job executa `./gradlew --no-daemon assembleDebug bundleRelease`. Build local comprovado: `./android/gradlew -p android :app:assembleDebug :app:bundleRelease` → BUILD SUCCESSFUL em 4m 4s (`app-debug.apk` 38MB, `app-release.aab` 6MB). | #629 |
| Publicação dos artefatos no GitHub Actions | sim | Steps configurados com `actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4.6.2` para `app-debug.apk` e `app-release.aab` com retenção de 30 dias. | #629 |
| Passo de assinatura lê segredos opcionais | sim | Script no workflow decodifica `FRILA_RELEASE_KEYSTORE_BASE64` para `/tmp/release.keystore` apenas se presente, mantendo build unsigned caso ausente. | #629 |
| Documentação como pendente de pessoa (keystore e secrets) | sim | `docs/android/05-ci-pipeline.md` §7 documenta detalhadamente as 4 GitHub Secrets necessárias e comandos para geração do keystore oficial. Nenhum segredo criado ou tocado. | #629 |
| Validação de sintaxe com `actionlint` | sim | `actionlint .github/workflows/*.yml` → 0 erros, 0 warnings. | #629 |

---

## Cartão 101 · limpeza segura de dados em logout/background

Branch `noite/android-a-101`, commit `c19dfc83`, [PR #633](https://github.com/FrilaApp/frila-frontend/pull/633), [cartão](https://trello.com/c/LMP101LGPD).

| Critério | Cumprido? | Prova: comando, saída e arquivo:linha | PR |
| --- | --- | --- | --- |
| Teste unitário JVM provando sessão vazia após logout | sim | `./android/gradlew -p android :app:testDebugUnitTest --tests '*LimpezaSeguraLogoutTest*'` → BUILD SUCCESSFUL. `android/app/src/test/kotlin/br/com/frila/app/seguranca/LimpezaSeguraLogoutTest.kt:105` prova `obterSessao() == null`, `!estaAutenticado()` e biometria desativada. | #633 |
| Teste unitário JVM provando cache de imagens limpo | sim | Mesmo comando/saída. `LimpezaSeguraLogoutTest.kt:111` prova expurgo completo de arquivos no `cacheDir` (fotos de ocorrências, relatórios PDF) e remoção de fotos de avatar (`avatar_perfil_*`, `.tmp`) em `filesDir`, preservando arquivos que não são imagens (DataStore). | #633 |
| Teste unitário JVM provando corrotinas canceladas | sim | Mesmo comando/saída. `LimpezaSeguraLogoutTest.kt:120` e `:160` provam cancelamento de tarefas ativas em segundo plano (`job.isCancelled == true`, `!job.isActive`). | #633 |
| Teste unitário JVM provando cliente Ktor recriado | sim | Mesmo comando/saída e `./android/gradlew -p android :core:rede:test --tests '*GestorClienteKtorTest*'`. `LimpezaSeguraLogoutTest.kt:126` prova cliente anterior fechado (`estaFechado == true`) e nova instância instanciada limpa. | #633 |
| Critérios de LGPD dependentes de decisão documentados | sim | Documentado no corpo do PR #633 e na documentação técnica: pendências para aprovação humana (PO/Cauê) sobre expurgo de preferências em DataStore e dependência de rede no desregistro de push. | #633 |

Sensibilidade comprovada: mutações no `CoordenadorDeLogout` e `GestorClienteKtor` (comentando expurgo de imagens, cancelamento de corrotinas ou fechamento do cliente HTTP) provocaram `AssertionError` imediato nos testes; código restaurado e regressão focal (`:core:rede:test`, `:feature:vagas:testDebugUnitTest`, `:app:testDebugUnitTest`) passou verde.

---

## Resumo dos PRs do Pacote N-050

- **Cartão 70**: [PR #627](https://github.com/FrilaApp/frila-frontend/pull/627) · Draft · branch `noite/android-a-70`
- **Cartão 59**: [PR #629](https://github.com/FrilaApp/frila-frontend/pull/629) · Draft · branch `noite/android-a-59`
- **Cartão 101**: [PR #633](https://github.com/FrilaApp/frila-frontend/pull/633) · Draft · branch `noite/android-a-101`
