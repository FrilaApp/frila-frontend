package br.com.frila.feature.perfil.capturas

import androidx.compose.ui.test.junit4.createComposeRule
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.feature.perfil.CatalogoLicencasAndroid
import br.com.frila.feature.perfil.TelaDetalheLicenca
import br.com.frila.feature.perfil.TelaLicencas
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Prints do lote R7 (licenças de código aberto) num Pixel de 411 × 914 dp, no claro. Sem `FRILA_CAPTURAS_DIR` (na CI),
 * cada teste só confere que a tela desenha sem quebrar.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasR7Test {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `licencas - lista`() {
        compose.setContent { FrilaTheme(temaEscuro = false) { TelaLicencas(aoVoltar = {}) } }
        compose.capturar("r7-14-licencas-lista")
    }

    @Test
    fun `licencas - detalhe de pacote`() {
        val licenca = CatalogoLicencasAndroid.licencas.first { it.id == "kotlinx-coroutines" }
        compose.setContent { FrilaTheme(temaEscuro = false) { TelaDetalheLicenca(licenca = licenca, aoVoltar = {}) } }
        compose.capturar("r7-15-licencas-detalhe")
    }

    @Test
    fun `licencas - detalhe da Prodigy Sans`() {
        val licenca = CatalogoLicencasAndroid.licencas.first { it.id == "prodigy-sans" }
        compose.setContent { FrilaTheme(temaEscuro = false) { TelaDetalheLicenca(licenca = licenca, aoVoltar = {}) } }
        compose.capturar("r7-16-licencas-detalhe-prodigy-sans")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `licencas - lista com a fonte do sistema em 200 por cento`() {
        compose.setContent { FrilaTheme(temaEscuro = false) { TelaLicencas(aoVoltar = {}) } }
        compose.capturar("r7-17-licencas-lista-fonte-200")
    }
}
