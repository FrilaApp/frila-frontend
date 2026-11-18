package br.com.frila.feature.perfil.capturas.r8

import android.content.Context
import android.net.Uri
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.TipoParteEvidencia
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.RepositorioVerificacaoIdentidade
import br.com.frila.core.rede.ServicoVerificacaoIdentidade
import br.com.frila.feature.perfil.StatusCargaVerificacao
import br.com.frila.feature.perfil.StatusEnvioVerificacao
import br.com.frila.feature.perfil.TelaConsentimentoSelo
import br.com.frila.feature.perfil.TelaVerificacaoDocumento
import br.com.frila.feature.perfil.VerificacaoIdentidadeViewModel
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.mockk
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Prints do lote R8 (selo de confiança: consentimento e verificação do documento) num Pixel de 411 × 914 dp, no
 * claro. Sem `FRILA_CAPTURAS_DIR` (na CI), cada teste só confere que a tela desenha sem quebrar.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasR8Test {

    @get:Rule
    val compose = createComposeRule()

    private val contexto = mockk<Context>(relaxed = true)
    private val uri = mockk<Uri>(relaxed = true)

    private fun statusJson(valor: String, motivo: String? = null) =
        """{"status_verificacao":"$valor","motivo":${motivo?.let { "\"$it\"" } ?: "null"},""" +
            """"prazo_envio_ate":null,"identidade_verificada":${valor == "aprovada"}}"""

    /**
     * [travarDepoisDoStatus]: só a leitura do estado responde; o resto (o envio) fica pendurado, para o print do
     * "Enviando". [travarTudo]: nem a leitura responde, para o print do carregando.
     */
    private fun criarViewModel(
        statusHttp: HttpStatusCode = HttpStatusCode.OK,
        corpo: String,
        travarDepoisDoStatus: Boolean = false,
        travarTudo: Boolean = false,
        imagemValida: Boolean = true,
    ): VerificacaoIdentidadeViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine { request ->
                if (travarTudo) awaitCancellation()
                if (travarDepoisDoStatus && !request.url.encodedPath.endsWith("minha_identidade_status")) awaitCancellation()
                respond(corpo, statusHttp, headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )
        return VerificacaoIdentidadeViewModel(
            repositorio = RepositorioVerificacaoIdentidade(ServicoVerificacaoIdentidade(cliente)),
            escopo = CoroutineScope(Dispatchers.Default),
            lerBytes = { _, _ -> if (imagemValida) byteArrayOf(1, 2, 3) else null },
        )
    }

    private fun mostrar(vm: VerificacaoIdentidadeViewModel, esperarCarga: Boolean = true) {
        compose.setContent { FrilaTheme(temaEscuro = false) { TelaVerificacaoDocumento(viewModel = vm, aoVoltar = {}) } }
        if (esperarCarga) compose.waitUntil(5_000) { vm.estado.value.carga != StatusCargaVerificacao.CARREGANDO }
        compose.waitForIdle()
    }

    private fun escolher(vm: VerificacaoIdentidadeViewModel, vararg partes: TipoParteEvidencia) {
        runBlocking { partes.forEach { vm.escolherParte(contexto, it, uri).join() } }
        compose.waitForIdle()
    }

    @Test
    fun `consentimento - caixa desmarcada`() {
        compose.setContent { FrilaTheme(temaEscuro = false) { TelaConsentimentoSelo(aoConfirmar = {}, aoVoltar = {}) } }
        compose.capturar("r8-01-consentimento-desmarcado")
    }

    @Test
    fun `consentimento - caixa marcada`() {
        compose.setContent { FrilaTheme(temaEscuro = false) { TelaConsentimentoSelo(aoConfirmar = {}, aoVoltar = {}) } }
        compose.onNodeWithTag("consentimento-checkbox").performClick()
        compose.capturar("r8-02-consentimento-marcado")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `consentimento - fonte do sistema em 200 por cento`() {
        compose.setContent { FrilaTheme(temaEscuro = false) { TelaConsentimentoSelo(aoConfirmar = {}, aoVoltar = {}) } }
        compose.onNodeWithTag("consentimento-checkbox").performClick()
        compose.capturar("r8-03-consentimento-fonte-200")
    }

    @Test
    fun `verificacao - carregando`() {
        val vm = criarViewModel(corpo = statusJson("nao_exigida"), travarTudo = true)
        mostrar(vm, esperarCarga = false)
        compose.capturar("r8-04-verificacao-carregando")
    }

    @Test
    fun `verificacao - erro ao carregar`() {
        val vm = criarViewModel(
            statusHttp = HttpStatusCode.Unauthorized,
            corpo = """{"code":"nao_autenticado","message":"x"}""",
        )
        mostrar(vm)
        compose.capturar("r8-05-verificacao-erro")
    }

    @Test
    fun `verificacao - formulario vazio`() {
        val vm = criarViewModel(corpo = statusJson("nao_exigida"))
        vm.confirmarConsentimento()
        mostrar(vm)
        compose.capturar("r8-06-verificacao-formulario-vazio")
    }

    @Test
    fun `verificacao - formulario com duas fotos e CNH`() {
        val vm = criarViewModel(corpo = statusJson("nao_exigida"))
        vm.confirmarConsentimento()
        vm.definirDocumento(br.com.frila.core.dominio.modelo.TipoDocumentoIdentidade.CNH)
        mostrar(vm)
        escolher(vm, TipoParteEvidencia.FRENTE, TipoParteEvidencia.VERSO)
        compose.capturar("r8-07-verificacao-formulario-duas-fotos")
    }

    @Test
    fun `verificacao - formulario completo com o botao ligado`() {
        val vm = criarViewModel(corpo = statusJson("nao_exigida"))
        vm.confirmarConsentimento()
        mostrar(vm)
        escolher(vm, *TipoParteEvidencia.entries.toTypedArray())
        compose.capturar("r8-08-verificacao-formulario-completo")
    }

    @Test
    fun `verificacao - erro de foto junto ao botao`() {
        val vm = criarViewModel(corpo = statusJson("nao_exigida"), imagemValida = false)
        vm.confirmarConsentimento()
        mostrar(vm)
        escolher(vm, TipoParteEvidencia.FRENTE)
        compose.capturar("r8-09-verificacao-erro-de-foto")
    }

    @Test
    fun `verificacao - enviando`() {
        val vm = criarViewModel(corpo = statusJson("nao_exigida"), travarDepoisDoStatus = true)
        vm.confirmarConsentimento()
        mostrar(vm)
        escolher(vm, *TipoParteEvidencia.entries.toTypedArray())
        vm.enviar()
        compose.waitUntil(5_000) { vm.estado.value.envio == StatusEnvioVerificacao.ENVIANDO }
        compose.capturar("r8-10-verificacao-enviando")
    }

    @Test
    fun `verificacao - rejeitada com motivo`() {
        val vm = criarViewModel(corpo = statusJson("rejeitada", "Foto ilegível"))
        vm.confirmarConsentimento()
        mostrar(vm)
        compose.capturar("r8-11-verificacao-rejeitada")
    }

    @Test
    fun `verificacao - em analise`() {
        val vm = criarViewModel(corpo = statusJson("em_analise"))
        mostrar(vm)
        compose.capturar("r8-12-verificacao-em-analise")
    }

    @Test
    fun `verificacao - aprovada`() {
        val vm = criarViewModel(corpo = statusJson("aprovada"))
        mostrar(vm)
        compose.capturar("r8-13-verificacao-aprovada")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `verificacao - formulario com a fonte do sistema em 200 por cento`() {
        val vm = criarViewModel(corpo = statusJson("nao_exigida"))
        vm.confirmarConsentimento()
        mostrar(vm)
        escolher(vm, TipoParteEvidencia.FRENTE)
        compose.capturar("r8-14-verificacao-formulario-fonte-200")
    }
}
