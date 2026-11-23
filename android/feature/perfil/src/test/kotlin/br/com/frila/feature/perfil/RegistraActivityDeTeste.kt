package br.com.frila.feature.perfil

import android.content.ComponentName
import androidx.activity.ComponentActivity
import org.junit.rules.ExternalResource
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf

/** Registra o host do Compose no PackageManager do Robolectric antes de abrir a tela. */
class RegistraActivityDeTeste : ExternalResource() {
    override fun before() {
        val app = RuntimeEnvironment.getApplication()
        shadowOf(app.packageManager).addActivityIfNotPresent(ComponentName(app, ComponentActivity::class.java))
    }
}
