package br.com.frila.feature.entrada.capturas.r1

import androidx.compose.ui.test.junit4.createComposeRule
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.DataCivil
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.feature.entrada.cadastro.CadastroViewModel
import br.com.frila.feature.entrada.cadastro.TelaCadastro
import br.com.frila.feature.entrada.codigo.CodigoViewModel
import br.com.frila.feature.entrada.codigo.TelaCodigo
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.TelaEntrada
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Prints do lote R1 (entrada, código e cadastro) num Pixel de 411 x 914 dp, no claro. Sem `FRILA_CAPTURAS_DIR`
 * (na CI), cada teste só confere que a tela desenha sem quebrar.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasR1EntradaTest {

    @get:Rule
    val compose = createComposeRule()

    private fun cliente(status: HttpStatusCode = HttpStatusCode.OK) = ClienteSupabase(
        baseUrl = "https://frila.supabase.co",
        apiKey = "chave-teste",
        engine = MockEngine { respond("{}", status, headersOf(HttpHeaders.ContentType, "application/json")) },
    )

    private fun entrada(status: HttpStatusCode = HttpStatusCode.OK) =
        EntradaViewModel(ServicoAutenticacao(cliente(status)), escopo = CoroutineScope(Dispatchers.Default))

    private fun codigo(esperaVencida: Boolean): CodigoViewModel {
        var relogio = Instant.parse("2026-11-16T12:00:00Z")
        val vm = CodigoViewModel(
            email = "ana@exemplo.com",
            servicoAutenticacao = ServicoAutenticacao(cliente()),
            armazenamentoDeSessao = ArmazenamentoDeSessaoEmMemoria(),
            escopo = CoroutineScope(Dispatchers.Default),
            agora = { relogio },
        )
        if (esperaVencida) relogio = relogio.plusSeconds(60) else relogio = relogio.plusSeconds(17)
        return vm
    }

    @Test
    fun `01 entrada - claro`() {
        val vm = entrada()
        compose.setContent { FrilaTheme(temaEscuro = false) { TelaEntrada(vm, aoReceberCodigo = {}) } }
        compose.capturar("r1-01-entrada-claro")
    }

    @Test
    fun `02 entrada - e-mail invalido junto do campo`() {
        val vm = entrada()
        vm.aoMudarEmail("ana@exemplo")
        vm.solicitarCodigo()
        compose.setContent { FrilaTheme(temaEscuro = false) { TelaEntrada(vm, aoReceberCodigo = {}) } }
        compose.capturar("r1-02-entrada-email-invalido")
    }

    @Test
    fun `03 entrada - erro da acao junto do botao`() {
        val vm = entrada(HttpStatusCode.InternalServerError)
        vm.aoMudarEmail("ana@exemplo.com")
        runBlocking { vm.solicitarCodigo()?.join() }
        compose.setContent { FrilaTheme(temaEscuro = false) { TelaEntrada(vm, aoReceberCodigo = {}) } }
        compose.capturar("r1-03-entrada-erro-da-acao")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `04 entrada - fonte em 200 por cento`() {
        val vm = entrada()
        vm.aoMudarEmail("ana@exemplo.com")
        compose.setContent { FrilaTheme(temaEscuro = false) { TelaEntrada(vm, aoReceberCodigo = {}) } }
        compose.capturar("r1-04-entrada-fonte-200")
    }

    @Test
    fun `05 codigo - contagem para reenviar`() {
        val vm = codigo(esperaVencida = false)
        vm.aoMudarCodigo("123")
        compose.setContent {
            FrilaTheme(temaEscuro = false) { TelaCodigo(vm, aoAutenticar = {}, aoTrocarEmail = {}) }
        }
        compose.capturar("r1-05-codigo-contagem")
    }

    @Test
    fun `06 codigo - erro e reenviar liberado`() {
        val vm = codigo(esperaVencida = true)
        vm.aoMudarCodigo("123")
        vm.confirmarCodigo()
        compose.setContent {
            FrilaTheme(temaEscuro = false) { TelaCodigo(vm, aoAutenticar = {}, aoTrocarEmail = {}) }
        }
        compose.capturar("r1-06-codigo-erro")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `07 codigo - fonte em 200 por cento`() {
        val vm = codigo(esperaVencida = false)
        vm.aoMudarCodigo("12345")
        compose.setContent {
            FrilaTheme(temaEscuro = false) { TelaCodigo(vm, aoAutenticar = {}, aoTrocarEmail = {}) }
        }
        compose.capturar("r1-07-codigo-fonte-200")
    }

    @Test
    fun `08 cadastro - vazio`() {
        val vm = CadastroViewModel()
        compose.setContent { FrilaTheme(temaEscuro = false) { TelaCadastro(vm, aoConcluir = {}) } }
        compose.capturar("r1-08-cadastro-vazio")
    }

    @Test
    fun `09 cadastro - cpf invalido e menor de idade junto dos campos`() {
        val vm = CadastroViewModel()
        vm.aoMudarNome("Ana Souza")
        vm.aoMudarCpf("11111111111")
        compose.setContent { FrilaTheme(temaEscuro = false) { TelaCadastro(vm, aoConcluir = {}) } }
        compose.capturar("r1-09-cadastro-cpf-invalido")
    }

    @Test
    fun `10 cadastro - aceite dos termos junto do botao`() {
        val vm = CadastroViewModel()
        vm.aoMudarNome("Ana Souza")
        vm.aoMudarCpf("52998224725")
        vm.aoMudarTelefone("61999998888")
        vm.aoMudarNascimento(DataCivil.de(1990, 5, 10))
        vm.concluirCadastro()
        compose.setContent { FrilaTheme(temaEscuro = false) { TelaCadastro(vm, aoConcluir = {}) } }
        compose.capturar("r1-10-cadastro-termos")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `11 cadastro - fonte em 200 por cento`() {
        val vm = CadastroViewModel()
        vm.aoMudarNome("Ana Souza")
        compose.setContent { FrilaTheme(temaEscuro = false) { TelaCadastro(vm, aoConcluir = {}) } }
        compose.capturar("r1-11-cadastro-fonte-200")
    }
}
