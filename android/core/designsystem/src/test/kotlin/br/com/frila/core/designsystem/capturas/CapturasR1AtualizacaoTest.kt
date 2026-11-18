package br.com.frila.core.designsystem.capturas

import androidx.compose.ui.test.junit4.createComposeRule
import br.com.frila.core.designsystem.componentes.TelaAtualizacaoObrigatoria
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** Prints da tela de atualização obrigatória (lote R1 do redesign). */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasR1AtualizacaoTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `atualizacao obrigatoria - claro`() {
        compose.setContent { FrilaTheme(temaEscuro = false) { TelaAtualizacaoObrigatoria(aoAtualizar = {}) } }
        compose.capturar("r1-atualizacao-obrigatoria-claro")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `atualizacao obrigatoria - fonte do sistema em 200 por cento`() {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                TelaAtualizacaoObrigatoria(aoAtualizar = {}, mensagem = "Versão mínima 1.2.0 exigida pelo servidor.")
            }
        }
        compose.capturar("r1-atualizacao-obrigatoria-fonte-200")
    }
}
