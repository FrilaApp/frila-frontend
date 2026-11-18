package br.com.frila.app.capturas.rn

import android.app.Application
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.navigation.compose.rememberNavController
import br.com.frila.app.BarraDaRaiz
import br.com.frila.app.PapelDaRaiz
import br.com.frila.app.Rotas
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.designsystem.tema.FrilaTipo
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Prints da barra de abas das telas raiz (RN), com as abas de verdade de cada papel, num Pixel de 411 × 914 dp.
 * Sem `FRILA_CAPTURAS_DIR` (na CI), cada teste só confere que a barra desenha sem quebrar.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], application = Application::class, qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasRNTest {

    @get:Rule
    val compose = createComposeRule()

    private val casa = PapelDaRaiz.Contratante(Rotas.minhasVagas("est-1", "Bar da Lia"))

    private fun raiz(papel: PapelDaRaiz, padrao: String, oQueATelaMostra: String) {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                val nav = rememberNavController()
                Scaffold(
                    containerColor = FrilaTema.cores.fundo,
                    bottomBar = { BarraDaRaiz(navController = nav, papel = papel, padraoAtual = padrao) },
                ) { recuo ->
                    Column(Modifier.padding(recuo).padding(FrilaEspacamento.grupo)) {
                        Text(text = oQueATelaMostra, style = FrilaTipo.corpo, color = FrilaTema.cores.tintaSuave)
                    }
                }
            }
        }
    }

    @Test
    fun `abas do profissional, na primeira - claro`() {
        raiz(PapelDaRaiz.Profissional, Rotas.FEED, "(lista de vagas)")
        compose.capturar("rn-01-abas-profissional-vagas")
    }

    @Test
    fun `abas do profissional, na Conta - claro`() {
        raiz(PapelDaRaiz.Profissional, Rotas.PERFIL, "(perfil)")
        compose.capturar("rn-02-abas-profissional-conta")
    }

    @Test
    fun `abas da casa - claro`() {
        raiz(casa, Rotas.MINHAS_VAGAS, "(vagas da casa)")
        compose.capturar("rn-03-abas-casa")
    }

    @Test
    @Config(sdk = [34], application = Application::class, qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `abas do profissional - fonte do sistema em 200 por cento`() {
        raiz(PapelDaRaiz.Profissional, Rotas.MEUS_TURNOS, "(meus turnos)")
        compose.capturar("rn-04-abas-profissional-fonte-200")
    }
}
