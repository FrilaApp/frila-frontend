package br.com.frila.app

import android.Manifest
import android.content.pm.PackageManager
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * As permissões que o app pede, lidas do manifesto mesclado (o que vai no pacote, com o que as bibliotecas trazem).
 * O app não usa biometria; a biblioteca `androidx.biometric` ainda está no projeto e traria as duas permissões dela.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = android.app.Application::class)
class PermissoesDoAppTest {

    private val pedidas: List<String>
        get() {
            val contexto = RuntimeEnvironment.getApplication()
            return contexto.packageManager
                .getPackageInfo(contexto.packageName, PackageManager.GET_PERMISSIONS)
                .requestedPermissions.orEmpty().toList()
        }

    @Test
    fun `o app nao pede as permissoes de biometria que a biblioteca traz`() {
        assertFalse("USE_BIOMETRIC está no manifesto mesclado: $pedidas", Manifest.permission.USE_BIOMETRIC in pedidas)
        @Suppress("DEPRECATION")
        assertFalse("USE_FINGERPRINT está no manifesto mesclado: $pedidas", Manifest.permission.USE_FINGERPRINT in pedidas)
    }

    /** Garante que o teste lê o manifesto mesclado de verdade: esta permissão vem do manifesto de `:core:localizacao`. */
    @Test
    fun `a leitura enxerga as permissoes que vem dos modulos`() {
        assertTrue("faltou ACCESS_FINE_LOCATION: $pedidas", Manifest.permission.ACCESS_FINE_LOCATION in pedidas)
    }
}
