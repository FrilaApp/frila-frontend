package br.com.frila.feature.perfil

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Test

/**
 * Mesma ressalva de `MockEngine` + escopo próprio documentada em `MeusTurnosViewModelTest` e em
 * `br.com.frila.feature.entrada.entrada.EntradaViewModel`: o teste espera o `Job` com `.join()`.
 */
class PerfilViewModelTest {

    private val perfilJson = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "usuario_id": "22222222-2222-2222-2222-222222222222",
          "funcoes": [{"id": "f1", "nome": "garçom", "categoria": "Salão"}],
          "ponto_base": {"latitude": -15.7942, "longitude": -47.8822},
          "disponibilidades": [],
          "reputacao": {
            "positivas": 7, "total": 7, "taxa_comparecimento": 0.95,
            "turnos_considerados": 8, "turnos_realizados": 8
          }
        }
    """.trimIndent()

    private fun viewModelComEngine(engine: MockEngine, armazenamento: ArmazenamentoDeSessao = mockk(relaxed = true)): PerfilViewModel {
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        return PerfilViewModel(ServicoPerfil(cliente), armazenamento, escopo = CoroutineScope(Dispatchers.Default))
    }

    @Test
    fun `carregar com sucesso resulta em status SUCESSO com o perfil`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine { respond(content = perfilJson, status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json")) },
        )

        viewModel.carregar().join()

        assertEquals(StatusPerfil.SUCESSO, viewModel.estado.value.status)
        assertEquals(7, viewModel.estado.value.perfil?.reputacao?.positivas)
        assertEquals("garçom", viewModel.estado.value.perfil?.funcoes?.first()?.nome)
    }

    @Test
    fun `aoDeslogar limpa a sessao em ArmazenamentoDeSessao`() {
        val armazenamento = mockk<ArmazenamentoDeSessao>(relaxed = true)
        val viewModel = viewModelComEngine(MockEngine { respond(content = perfilJson, status = HttpStatusCode.OK) }, armazenamento)

        viewModel.aoDeslogar()

        verify(exactly = 1) { armazenamento.limparSessao() }
    }

    @Test
    fun `carregar com erro da API resulta em status ERRO com mensagem amigavel`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = """{"code":"nao_encontrado","message":"perfil nao existe"}""",
                    status = HttpStatusCode.NotFound,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.carregar().join()

        assertEquals(StatusPerfil.ERRO, viewModel.estado.value.status)
        assertNotNull(viewModel.estado.value.mensagemErro)
    }

    @Test
    fun `status comeca CARREGANDO antes da resposta chegar`() {
        val viewModel = viewModelComEngine(MockEngine { respond(content = perfilJson, status = HttpStatusCode.OK) })

        assertEquals(StatusPerfil.CARREGANDO, viewModel.estado.value.status)
    }

    @Test
    fun `confirmarExclusao com sucesso chama a API, limpa a sessao e vai para SUCESSO`() = runBlocking {
        val armazenamento = mockk<ArmazenamentoDeSessao>(relaxed = true)
        val engine = MockEngine {
            respond(
                content = """
                    {
                      "perfil_removido_em": "2026-11-02T10:00:00Z",
                      "dados_apagados_ate": "2026-11-17",
                      "turnos_cancelados": 1
                    }
                """.trimIndent(),
                status = HttpStatusCode.Accepted,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val viewModel = viewModelComEngine(engine, armazenamento)

        viewModel.abrirDialogoExclusao()
        viewModel.confirmarExclusao().join()

        assertEquals(StatusExclusao.SUCESSO, viewModel.estado.value.statusExclusao)
        assertEquals(1, viewModel.estado.value.resultadoExclusao?.turnosCancelados)
        verify(exactly = 1) { armazenamento.limparSessao() }
    }

    @Test
    fun `cancelarExclusao volta o statusExclusao para OCIOSO sem chamar a API`() {
        val viewModel = viewModelComEngine(MockEngine { respond(content = perfilJson, status = HttpStatusCode.OK) })

        viewModel.abrirDialogoExclusao()
        assertEquals(StatusExclusao.DIALOGO_ABERTO, viewModel.estado.value.statusExclusao)

        viewModel.cancelarExclusao()

        assertEquals(StatusExclusao.OCIOSO, viewModel.estado.value.statusExclusao)
    }

    @Test
    fun `confirmarExclusao com administrador_unico mantem a sessao e define mensagem de erro`() = runBlocking {
        val armazenamento = mockk<ArmazenamentoDeSessao>(relaxed = true)
        val engine = MockEngine {
            respond(
                content = """{"code":"administrador_unico","message":"transfira a administracao antes"}""",
                status = HttpStatusCode.Conflict,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val viewModel = viewModelComEngine(engine, armazenamento)

        viewModel.abrirDialogoExclusao()
        viewModel.confirmarExclusao().join()

        assertEquals(StatusExclusao.ERRO, viewModel.estado.value.statusExclusao)
        assertNotNull(viewModel.estado.value.mensagemErroExclusao)
        verify(exactly = 0) { armazenamento.limparSessao() }
    }
}
