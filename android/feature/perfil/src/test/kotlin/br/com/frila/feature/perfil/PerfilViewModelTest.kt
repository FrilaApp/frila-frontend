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
}
