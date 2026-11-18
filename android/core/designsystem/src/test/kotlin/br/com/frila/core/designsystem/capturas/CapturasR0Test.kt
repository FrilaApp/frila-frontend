package br.com.frila.core.designsystem.capturas

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.EstadoVazio
import br.com.frila.core.designsystem.componentes.TomAviso
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
 * Prints da fundação do redesign (R0): os componentes base num Pixel de 411 × 914 dp, no claro e no
 * escuro. Sem `FRILA_CAPTURAS_DIR` (na CI), cada teste só confere que a tela desenha sem quebrar.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasR0Test {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `componentes base - claro`() {
        compose.setContent { FrilaTheme(temaEscuro = false) { ComponentesBase() } }
        compose.capturar("r0-componentes-base-claro")
    }

    @Test
    fun `componentes base - escuro`() {
        compose.setContent { FrilaTheme(temaEscuro = true) { ComponentesBase() } }
        compose.capturar("r0-componentes-base-escuro")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `componentes base - fonte do sistema em 200 por cento`() {
        compose.setContent { FrilaTheme(temaEscuro = false) { ComponentesBase() } }
        compose.capturar("r0-componentes-base-fonte-200")
    }
}

@Composable
private fun ComponentesBase() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(FrilaTema.cores.fundo)
            .padding(FrilaEspacamento.grupo),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
    ) {
        Text("Vagas perto de você", style = MaterialTheme.typography.titleLarge, color = FrilaTema.cores.tinta)
        Text("Corpo do texto, em tinta.", style = MaterialTheme.typography.bodyLarge, color = FrilaTema.cores.tinta)
        CartaoFrila(modifier = Modifier.fillMaxWidth()) {
            Text("Bar do Zé", style = FrilaTipo.nome, color = FrilaTema.cores.tinta)
            Text("Bartender · sáb 21/11, das 18:00 às 00:00", style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave)
            Text("R$ 180", style = FrilaTipo.valorEmDestaque, color = FrilaTema.cores.tinta)
        }
        AvisoFrila(tom = TomAviso.INFORMATIVO, mensagem = "O estabelecimento escolhe entre os interessados.")
        BotaoPrimario(texto = "Receber código", aoClicar = {}, modifier = Modifier.fillMaxWidth())
        BotaoPrimario(texto = "Receber código", aoClicar = {}, habilitado = false, modifier = Modifier.fillMaxWidth())
        BotaoSecundario(texto = "Abrir no mapa", aoClicar = {}, modifier = Modifier.fillMaxWidth())
        EstadoVazio(titulo = "Nenhuma vaga por perto agora", mensagem = "Avisamos quando abrir uma.")
        EstadoErro(aoTentarNovamente = {})
    }
}
