package br.com.frila.feature.vagas.detalhe

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ContatoDto
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.InclusosDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.VagaAbertaDto
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** Ver nota em `FeedVagasViewModelTest` sobre por que o teste faz `job.join()`. */
class DetalheVagaViewModelTest {

    private fun vagaDe(modo: String) = VagaAbertaDto(
        id = "11111111-1111-1111-1111-111111111111",
        funcao = FuncaoDto(id = "f1", nome = "garçom", categoria = "Salão"),
        estabelecimento = PerfilPublicoDto(
            id = "e1",
            tipo = "estabelecimento",
            nome = "Bar do Zé",
            reputacao = ReputacaoDto(positivas = 7, total = 7, taxaComparecimento = 1.0, turnosConsiderados = 7, turnosRealizados = 7),
        ),
        inicioEm = "2026-11-01T21:00:00Z",
        fimEm = "2026-11-02T03:00:00Z",
        local = "SQN 108",
        regiaoAdministrativa = "Asa Norte",
        distanciaKm = 4.2,
        valorCentavos = 16_000,
        posicoesAbertas = 2,
        inclusos = InclusosDto(incluiRefeicao = true, incluiTransporte = false, exigeMaterialProprio = false),
        modo = modo,
    )

    private fun viewModelComEngine(vaga: VagaAbertaDto, engine: MockEngine): DetalheVagaViewModel {
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        return DetalheVagaViewModel(vaga, ServicoVagas(cliente), escopo = CoroutineScope(Dispatchers.Default))
    }

    @Test
    fun `candidatar no modo urgencia confirma e expoe o contato`() = runBlocking {
        val viewModel = viewModelComEngine(
            vaga = vagaDe("urgencia"),
            engine = MockEngine {
                respond(
                    content = """
                        {
                          "estado": "confirmada",
                          "candidatura_id": "c1",
                          "posicao_id": "p1",
                          "turno_id": "t1",
                          "contato": {"nome": "Bar do Zé", "telefone": "+5561999990000"}
                        }
                    """.trimIndent(),
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.candidatar().join()

        assertEquals(StatusCandidatura.CONFIRMADA, viewModel.estado.value.statusCandidatura)
        assertEquals(ContatoDto(nome = "Bar do Zé", telefone = "+5561999990000"), viewModel.estado.value.contato)
    }

    @Test
    fun `candidatar no modo selecao fica pendente sem contato`() = runBlocking {
        val viewModel = viewModelComEngine(
            vaga = vagaDe("selecao"),
            engine = MockEngine {
                respond(
                    content = """{"estado":"pendente","candidatura_id":"c1","posicao_id":null,"turno_id":null,"contato":null}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.candidatar().join()

        assertEquals(StatusCandidatura.PENDENTE, viewModel.estado.value.statusCandidatura)
        assertNull(viewModel.estado.value.contato)
    }

    @Test
    fun `candidatar com posicao_ja_preenchida mostra a mensagem de pena`() = runBlocking {
        val viewModel = viewModelComEngine(
            vaga = vagaDe("urgencia"),
            engine = MockEngine {
                respond(
                    content = """{"code":"posicao_ja_preenchida","message":"alguém chegou antes"}""",
                    status = HttpStatusCode.Conflict,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.candidatar().join()

        assertEquals(StatusCandidatura.ERRO, viewModel.estado.value.statusCandidatura)
        assertEquals("Que pena, a vaga acabou de ser preenchida.", viewModel.estado.value.mensagem)
    }

    @Test
    fun `candidatar com inelegivel mostra a mensagem de elegibilidade`() = runBlocking {
        val viewModel = viewModelComEngine(
            vaga = vagaDe("urgencia"),
            engine = MockEngine {
                respond(
                    content = """{"code":"inelegivel","message":"turno_sobreposto"}""",
                    status = HttpStatusCode.UnprocessableEntity,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.candidatar().join()

        assertEquals(StatusCandidatura.ERRO, viewModel.estado.value.statusCandidatura)
        assertEquals("Você não está elegível para este turno.", viewModel.estado.value.mensagem)
    }

    @Test
    fun `candidatar com vaga_encerrada mostra a mensagem de encerramento`() = runBlocking {
        val viewModel = viewModelComEngine(
            vaga = vagaDe("selecao"),
            engine = MockEngine {
                respond(
                    content = """{"code":"vaga_encerrada","message":"fechou 24h antes do inicio"}""",
                    status = HttpStatusCode.Conflict,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.candidatar().join()

        assertEquals(StatusCandidatura.ERRO, viewModel.estado.value.statusCandidatura)
        assertEquals("Esta vaga foi encerrada.", viewModel.estado.value.mensagem)
    }

    @Test
    fun `ehModoUrgencia reflete o modo da vaga`() {
        val viewModelUrgencia = viewModelComEngine(vagaDe("urgencia"), MockEngine { respond("{}", HttpStatusCode.OK) })
        val viewModelSelecao = viewModelComEngine(vagaDe("selecao"), MockEngine { respond("{}", HttpStatusCode.OK) })

        assertTrue(viewModelUrgencia.estado.value.ehModoUrgencia)
        assertFalse(viewModelSelecao.estado.value.ehModoUrgencia)
    }
}
