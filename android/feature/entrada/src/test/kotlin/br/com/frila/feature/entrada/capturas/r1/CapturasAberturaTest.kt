package br.com.frila.feature.entrada.capturas.r1

import androidx.compose.ui.test.junit4.createComposeRule
import br.com.frila.core.designsystem.abertura.AberturaAnimada
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.TelaEntrada
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Prints da abertura animada (pedido 18-01) sobre a T6, num Pixel de 411 x 914 dp, no claro: quadros congelados em
 * instantes do roteiro (o do protótipo e o reduzido) e a T6 com a arte em camadas. Sem `FRILA_CAPTURAS_DIR` (na CI)
 * cada teste só confere que a tela desenha sem quebrar.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasAberturaTest {

    @get:Rule
    val compose = createComposeRule()

    private fun entrada() = EntradaViewModel(
        ServicoAutenticacao(
            ClienteSupabase(
                baseUrl = "https://frila.supabase.co",
                apiKey = "chave-teste",
                engine = MockEngine {
                    respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
                },
            ),
        ),
        escopo = CoroutineScope(Dispatchers.Default),
    )

    private fun quadro(nome: String, segundos: Double, reduzido: Boolean = false) {
        val vm = entrada()
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                AberturaAnimada(ligada = true, reduzirMovimento = reduzido, tempoCongelado = segundos) {
                    TelaEntrada(vm, aoReceberCodigo = {})
                }
            }
        }
        compose.capturar(nome)
    }

    @Test
    fun `abertura - inicio, 0,3 s`() = quadro("abertura-01-inicio-t0.3", 0.3)

    @Test
    fun `abertura - encaixe, 1,2 s`() = quadro("abertura-02-encaixe-t1.2", 1.2)

    @Test
    fun `abertura - rotulo formado, 2,0 s`() = quadro("abertura-03-rotulo-t2.0", 2.0)

    @Test
    fun `abertura - o rotulo voa para a T6, 2,55 s`() = quadro("abertura-04-voo-para-a-t6-t2.55", 2.55)

    @Test
    fun `abertura - fim, 2,75 s`() = quadro("abertura-05-fim-t2.75", 2.75)

    @Test
    fun `abertura reduzida - rotulo parado, 0,3 s`() = quadro("abertura-reduzida-01-parado-t0.3", 0.3, reduzido = true)

    @Test
    fun `abertura reduzida - esmaecendo, 0,75 s`() = quadro("abertura-reduzida-02-esmaecendo-t0.75", 0.75, reduzido = true)

    @Test
    fun `T6 com a arte em camadas`() {
        val vm = entrada()
        compose.setContent { FrilaTheme(temaEscuro = false) { TelaEntrada(vm, aoReceberCodigo = {}) } }
        compose.capturar("t6-com-a-arte")
    }
}
