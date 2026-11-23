package br.com.frila.feature.vagas.detalhe

import br.com.frila.core.rede.EventoDeTelemetria
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
import java.net.UnknownHostException
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
    fun `telemetria emite abertura e candidatura confirmada com identificadores`() = runBlocking {
        val eventos = mutableListOf<Triple<EventoDeTelemetria, String?, String?>>()
        val vaga = vagaDe("selecao")
        val cliente = ClienteSupabase("https://sintetico.supabase.invalid", "chave-sintetica", engine = MockEngine {
            respond("""{"estado":"pendente","candidatura_id":"c1","posicao_id":null,"turno_id":null,"contato":null}""",
                headers = headersOf(HttpHeaders.ContentType, "application/json"))
        })
        cliente.use {
            val vm = DetalheVagaViewModel(vaga, ServicoVagas(it), escopo = CoroutineScope(Dispatchers.Default),
                registrarEvento = { evento, id, turno -> eventos += Triple(evento, id, turno) })
            vm.candidatar().join()
            assertEquals(listOf(Triple(EventoDeTelemetria.VAGA_DETALHE_ABERTO, vaga.id, null),
                Triple(EventoDeTelemetria.CANDIDATURA_ENVIADA, vaga.id, null)), eventos)
        }
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

    private fun mensagemAposErro(status: HttpStatusCode, corpo: String): String? = runBlocking {
        val viewModel = viewModelComEngine(
            vaga = vagaDe("urgencia"),
            engine = MockEngine {
                respond(
                    content = corpo,
                    status = status,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.candidatar().join()
        assertEquals(StatusCandidatura.ERRO, viewModel.estado.value.statusCandidatura)
        viewModel.estado.value.mensagem
    }

    private val mensagemSuspensao =
        "Enquanto a suspensão durar, você não pode se candidatar a vagas. " +
            "O motivo e o caminho para contestar ficam na área da sua conta."

    @Test
    fun `candidatar com inelegivel por turno_sobreposto explica o conflito de horario`() {
        val mensagem = mensagemAposErro(
            HttpStatusCode.UnprocessableEntity,
            """{"code":"inelegivel","message":"inelegivel","details":"turno_sobreposto"}""",
        )

        assertEquals(
            "Você já tem um turno confirmado que coincide com o horário desta vaga. " +
                "Não é possível assumir dois turnos ao mesmo tempo.",
            mensagem,
        )
    }

    @Test
    fun `candidatar com turno_sobreposto marca ehConflitoHorario como verdadeiro`() = runBlocking {
        val viewModel = viewModelComEngine(
            vaga = vagaDe("urgencia"),
            engine = MockEngine {
                respond(
                    content = """{"code":"inelegivel","message":"inelegivel","details":"turno_sobreposto"}""",
                    status = HttpStatusCode.UnprocessableEntity,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.candidatar().join()
        assertEquals(StatusCandidatura.ERRO, viewModel.estado.value.statusCandidatura)
        assertTrue(viewModel.estado.value.ehConflitoHorario)
    }

    @Test
    fun `candidatar com posicao_ja_preenchida marca ehVagaPreenchida como verdadeiro`() = runBlocking {
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
        assertTrue(viewModel.estado.value.ehVagaPreenchida)
        assertFalse(viewModel.estado.value.ehConflitoHorario)
        assertFalse(viewModel.estado.value.ehVagaEncerrada)
        assertFalse(viewModel.estado.value.ehContaSuspensa)
    }

    @Test
    fun `candidatar com vaga_encerrada marca ehVagaEncerrada como verdadeiro`() = runBlocking {
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
        assertTrue(viewModel.estado.value.ehVagaEncerrada)
        assertFalse(viewModel.estado.value.ehVagaPreenchida)
        assertFalse(viewModel.estado.value.ehConflitoHorario)
        assertFalse(viewModel.estado.value.ehContaSuspensa)
    }

    @Test
    fun `candidatar com conta_suspensa marca ehContaSuspensa como verdadeiro`() = runBlocking {
        val viewModel = viewModelComEngine(
            vaga = vagaDe("urgencia"),
            engine = MockEngine {
                respond(
                    content = """{"code":"conta_suspensa","message":"conta suspensa"}""",
                    status = HttpStatusCode.Forbidden,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.candidatar().join()
        assertEquals(StatusCandidatura.ERRO, viewModel.estado.value.statusCandidatura)
        assertTrue(viewModel.estado.value.ehContaSuspensa)
        assertFalse(viewModel.estado.value.ehVagaPreenchida)
        assertFalse(viewModel.estado.value.ehVagaEncerrada)
        assertFalse(viewModel.estado.value.ehConflitoHorario)
    }

    @Test
    fun `candidatar com sem_permissao conta_suspensa marca ehContaSuspensa como verdadeiro`() = runBlocking {
        val viewModel = viewModelComEngine(
            vaga = vagaDe("urgencia"),
            engine = MockEngine {
                respond(
                    content = """{"code":"sem_permissao","message":"sem permissao","details":"conta_suspensa"}""",
                    status = HttpStatusCode.Forbidden,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.candidatar().join()
        assertEquals(StatusCandidatura.ERRO, viewModel.estado.value.statusCandidatura)
        assertTrue(viewModel.estado.value.ehContaSuspensa)
    }

    @Test
    fun `candidatar com inelegivel perfil_suspenso marca ehContaSuspensa como verdadeiro`() = runBlocking {
        val viewModel = viewModelComEngine(
            vaga = vagaDe("urgencia"),
            engine = MockEngine {
                respond(
                    content = """{"code":"inelegivel","message":"inelegivel","details":"perfil_suspenso"}""",
                    status = HttpStatusCode.UnprocessableEntity,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.candidatar().join()
        assertEquals(StatusCandidatura.ERRO, viewModel.estado.value.statusCandidatura)
        assertTrue(viewModel.estado.value.ehContaSuspensa)
    }

    @Test
    fun `candidatar com inelegivel por perfil_suspenso explica a suspensao`() {
        val mensagem = mensagemAposErro(
            HttpStatusCode.UnprocessableEntity,
            """{"code":"inelegivel","message":"inelegivel","details":"perfil_suspenso"}""",
        )

        assertEquals(mensagemSuspensao, mensagem)
    }

    @Test
    fun `candidatar com conta_suspensa explica a suspensao`() {
        val mensagem = mensagemAposErro(
            HttpStatusCode.Forbidden,
            """{"code":"conta_suspensa","message":"conta suspensa"}""",
        )

        assertEquals(mensagemSuspensao, mensagem)
    }

    @Test
    fun `candidatar com inelegivel por funcao_incompativel aponta a funcao do perfil`() {
        val mensagem = mensagemAposErro(
            HttpStatusCode.UnprocessableEntity,
            """{"code":"inelegivel","message":"inelegivel","details":"funcao_incompativel"}""",
        )

        assertEquals("Esta vaga exige uma função que não está cadastrada no seu perfil profissional.", mensagem)
    }

    @Test
    fun `candidatar com inelegivel de outro detalhe usa a mensagem generica de elegibilidade`() {
        val mensagem = mensagemAposErro(
            HttpStatusCode.UnprocessableEntity,
            """{"code":"inelegivel","message":"inelegivel","details":"outro_motivo"}""",
        )

        assertEquals("Você não está elegível para este turno.", mensagem)
    }

    @Test
    fun `candidatar com nao_encontrado manda voltar para a lista`() {
        val mensagem = mensagemAposErro(
            HttpStatusCode.NotFound,
            """{"code":"nao_encontrado","message":"vaga inexistente"}""",
        )

        assertEquals("Esta vaga não está mais disponível. Volte para a lista e escolha outra.", mensagem)
    }

    @Test
    fun `candidatar sem rede pede para tentar quando a conexao voltar`() = runBlocking {
        val viewModel = viewModelComEngine(
            vaga = vagaDe("urgencia"),
            engine = MockEngine { throw UnknownHostException("sem rede") },
        )

        viewModel.candidatar().join()

        assertEquals(StatusCandidatura.ERRO, viewModel.estado.value.statusCandidatura)
        assertEquals(
            "Não foi possível confirmar o envio. Tente de novo quando a conexão voltar.",
            viewModel.estado.value.mensagem,
        )
    }

    @Test
    fun `candidatar com codigo sem mapeamento usa a mensagem padrao`() {
        val mensagem = mensagemAposErro(
            HttpStatusCode.InternalServerError,
            """{"code":"codigo_que_nao_existe","message":"erro"}""",
        )

        assertEquals("Não foi possível enviar sua candidatura. Tente de novo em instantes.", mensagem)
    }

    @Test
    fun `ehModoUrgencia reflete o modo da vaga`() {
        val viewModelUrgencia = viewModelComEngine(vagaDe("urgencia"), MockEngine { respond("{}", HttpStatusCode.OK) })
        val viewModelSelecao = viewModelComEngine(vagaDe("selecao"), MockEngine { respond("{}", HttpStatusCode.OK) })

        assertTrue(viewModelUrgencia.estado.value.ehModoUrgencia)
        assertFalse(viewModelSelecao.estado.value.ehModoUrgencia)
    }

    @Test
    fun `candidatar com resposta 200 ilegivel sai de enviando com mensagem de erro`() = runBlocking {
        val viewModel = viewModelComEngine(
            vaga = vagaDe("urgencia"),
            engine = MockEngine {
                respond(
                    content = "<html>portal</html>",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "text/html"),
                )
            },
        )

        viewModel.candidatar().join()

        assertEquals(StatusCandidatura.ERRO, viewModel.estado.value.statusCandidatura)
        assertTrue(viewModel.estado.value.mensagem != null)
    }
}
