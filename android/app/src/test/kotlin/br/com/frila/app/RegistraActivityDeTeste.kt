package br.com.frila.app

import android.content.ComponentName
import androidx.activity.ComponentActivity
import org.junit.rules.ExternalResource
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf

/**
 * C0-6b: no `testReleaseUnitTest` o Robolectric lê o manifesto mesclado do release, que não declara a
 * `ComponentActivity` que a regra do Compose sobe (o `ui-test-manifest` só entra no debug, e não pode ir para
 * o APK de produção). Sem ela, o teste cai com "Unable to resolve activity ... ComponentActivity".
 *
 * Esta regra registra a Activity no PackageManager do Robolectric antes de a regra do Compose subi-la. No
 * debug, onde o manifesto já a declara, não muda nada. Use com `@get:Rule(order = 0)` e a regra do Compose
 * com `order = 1`.
 */
class RegistraActivityDeTeste : ExternalResource() {
    override fun before() {
        val app = RuntimeEnvironment.getApplication()
        shadowOf(app.packageManager).addActivityIfNotPresent(ComponentName(app, ComponentActivity::class.java))
    }
}
