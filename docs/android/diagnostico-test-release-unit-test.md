# Diagnóstico Técnico: Falha de `testReleaseUnitTest` em Módulos Compose

**Data:** 01/11/2026  
**Contexto:** Cartão 70 (Design System: Teste instrumentado com PixelCopy para FrilaSkeleton e Reduzir Movimento)  
**Autor:** Android A (Antigravity · Google DeepMind)

---

## 1. Descrição do Problema

Ao executar a task `./gradlew testReleaseUnitTest` (ou a suíte geral `testReleaseUnitTest`) nos módulos Android com Compose UI, múltiplos testes unitários falham com a seguinte exceção:

```text
java.lang.RuntimeException: Unable to resolve activity for Intent { act=android.intent.action.MAIN cat=[android.intent.category.LAUNCHER] cmp=br.com.frila.feature.<modulo>.test/androidx.activity.ComponentActivity } -- see https://github.com/robolectric/robolectric/pull/4736 for details
	at org.robolectric.android.internal.RoboMonitoringInstrumentation.startActivitySyncInternal(RoboMonitoringInstrumentation.java:101)
	at org.robolectric.android.internal.LocalActivityInvoker.startActivity(LocalActivityInvoker.java:36)
	at androidx.test.core.app.ActivityScenario.launchInternal(ActivityScenario.java:362)
	at androidx.compose.ui.test.junit4.AndroidComposeTestRule$apply$1.evaluate(AndroidComposeTestRule.android.kt:271)
```

Essa falha ocorre sistematicamente em módulos como `:feature:entrada`, `:feature:perfil`, `:feature:turnos` e `:feature:vagas`, enquanto os mesmos testes passam com 100% de sucesso quando executados via `./gradlew testDebugUnitTest`.

---

## 2. Causa Raiz

1. **Escopo de `ui-test-manifest`:**
   A biblioteca oficial do Jetpack Compose requer que uma Activity seja registrada no manifesto para hospedar os composables durante os testes de UI (`createComposeRule()` ou `createAndroidComposeRule<ComponentActivity>()`). O artefato `androidx.compose.ui:ui-test-manifest` injeta a `ComponentActivity` no manifesto da aplicação para esse fim.

2. **Diferença entre variantes `debug` e `release` no AGP:**
   Nos arquivos `build.gradle.kts` dos módulos de feature, a dependência está declarada como:
   ```kotlin
   debugImplementation(libs.compose.ui.test.manifest)
   ```
   Conforme a modelagem de variantes do Android Gradle Plugin (AGP), a configuração `debugImplementation` só entra no classpath e no manifesto das variantes `debug` (e, consequentemente, em `testDebugUnitTest`). A variante `releaseUnitTest` compila contra a variante de release da biblioteca, onde `debugImplementation` é propositalmente excluído para não vazar código de teste no APK de produção.

3. **Comportamento do Robolectric:**
   Durante a execução de `testReleaseUnitTest`, o `RoboMonitoringInstrumentation` tenta resolver a `ComponentActivity` no manifesto mesclado de teste da variante release. Como ela não foi injetada, a resolução de Intent falha com `RuntimeException`.

---

## 3. Por que `:core:designsystem` não falha

No módulo `:core:designsystem/build.gradle.kts`, essa questão já havia sido identificada e corrigida:

```kotlin
// android/core/designsystem/build.gradle.kts:61-64
testImplementation(libs.compose.ui.test.manifest)
```

Ao declarar `testImplementation(libs.compose.ui.test.manifest)`, a dependência é incorporada ao classpath de testes de todas as variantes unitárias (`testDebugUnitTest` e `testReleaseUnitTest`), permitindo que a `ComponentActivity` seja resolvida com sucesso em ambas.

---

## 4. Solução e Recomendações

1. **Gate Normativo do Projeto:**
   O pipeline oficial de CI (`.github/workflows/android.yml` e `docs/android/05-ci-pipeline.md`) executa expressamente:
   ```bash
   ./gradlew testDebugUnitTest
   ```
   Essa é a convenção padrão recomendada pela equipe do Android Jetpack para testes unitários com Robolectric e Compose.

2. **Solução Comprovada para Execução em Release:**
   Para permitir a execução de `testReleaseUnitTest` sem falhas de resolução de `ComponentActivity`, a solução é declarar a dependência no escopo de teste unitário:
   ```kotlin
   testImplementation(libs.compose.ui.test.manifest)
   ```
   Essa configuração garante que o manifesto de teste contenha a `ComponentActivity` em qualquer variante unitária (`debug` ou `release`), sem vazar código ou manifesto de teste para os APKs ou AABs finais de produção (já que `testImplementation` atua exclusivamente no source set de teste unitário).

   > [!NOTE]
   > A propriedade `android { testBuildType = "debug" }` configura a variante de build utilizada para **testes instrumentados** (`connectedAndroidTest`), não alterando o classpath nem o manifesto dos testes unitários JVM da variante `release` (`testReleaseUnitTest`). Portanto, ela não soluciona a ausência de manifesto em testes unitários de release.

   A dependência `testImplementation(libs.compose.ui.test.manifest)` foi aplicada aos módulos de feature (`:feature:turnos`, `:feature:entrada`, `:feature:perfil`, `:feature:vagas`), permitindo que a suíte `testReleaseUnitTest` execute com 100% de sucesso.

---

## 5. Nota sobre PixelCopy e Testes Instrumentados

O teste visual via `PixelCopy` (`PixelCopy.request(surface, bitmap, callback, handler)`):
- Requer uma superfície acelerada por hardware (SurfaceView ou Window) e uma RenderThread ativa do sistema operacional Android.
- Em ambiente JVM puro (Robolectric / Headless), chamadas a `PixelCopy` lançam erro ou não executam a captura de frames de hardware.
- Portanto, conforme especificado no cartão 70, os testes unitários na JVM cobrem a decisão condicional do ramo de Reduzir Movimento (via leitura de `Settings.Global.ANIMATOR_DURATION_SCALE` e da propriedade semântica `FrilaSkeletonAnimado`) e os parâmetros estruturais do esqueleto (dimensões e formato). A comprovação a nível de pixels desenhados e recorte por hardware via `PixelCopy` permanece classificada como **não executada** nesta etapa por requerer emulador com aceleração gráfica ou aparelho físico.
