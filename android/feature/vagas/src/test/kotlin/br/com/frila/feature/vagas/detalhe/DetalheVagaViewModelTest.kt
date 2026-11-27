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
    fun `consumirNavegacaoParaConfirmada desliga o evento e mantem status CONFIRMADA contato e mensagem`() = runBlocking {
        val corpoConfirmada = """
            {
              "estado": "confirmada",
              "candidatura_id": "c1",
              "posicao_id": "p1",
              "turno_id": "t1",
              "contato": {"nome": "Bar do Zé", "telefone": "+5561999990000"}
            }
        """.trimIndent()
        val viewModel = viewModelComEngine(
            vaga = vagaDe("urgencia"),
            engine = MockEngine {
                respond(
                    content = corpoConfirmada,
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.candidatar().join()
        val contatoEsperado = ContatoDto(nome = "Bar do Zé", telefone = "+5561999990000")
        val mensagemEsperada = "Candidatura confirmada! Confira o contato abaixo."

        assertTrue(viewModel.estado.value.navegarParaConfirmada)
        assertTrue(viewModel.consumirNavegacaoParaConfirmada(), "o primeiro consumo recebe o evento")
        assertFalse(viewModel.consumirNavegacaoParaConfirmada(), "o segundo não recebe de novo")

        assertFalse(viewModel.estado.value.navegarParaConfirmada)
        assertEquals(StatusCandidatura.CONFIRMADA, viewModel.estado.value.statusCandidatura)
        assertEquals(contatoEsperado, viewModel.estado.value.contato)
        assertEquals(mensagemEsperada, viewModel.estado.value.mensagem)

        viewModel.candidatar().join()
        assertTrue(viewModel.estado.value.navegarParaConfirmada, "uma nova candidatura confirmada volta a sinalizar")
    }

    private fun validarConsumoDeErro(
        status: HttpStatusCode,
        corpo: String,
        lidoNoEstado: (EstadoDetalheVaga) -> Boolean,
        consumir: (DetalheVagaViewModel) -> Boolean,
    ) = runBlocking {
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
        val mensagem = viewModel.estado.value.mensagem

        assertTrue(lidoNoEstado(viewModel.estado.value))
        assertTrue(consumir(viewModel), "o primeiro consumo recebe o evento")
        assertFalse(consumir(viewModel), "o segundo não recebe de novo")

        assertFalse(lidoNoEstado(viewModel.estado.value))
        assertEquals(StatusCandidatura.ERRO, viewModel.estado.value.statusCandidatura)
        assertEquals(mensagem, viewModel.estado.value.mensagem)

        viewModel.candidatar().join()
        assertTrue(lidoNoEstado(viewModel.estado.value), "uma nova candidatura recusada volta a sinalizar")
    }

    @Test
    fun `consumirNavegacaoParaConflitoHorario desliga o evento e mantem o erro e a mensagem`() {
        validarConsumoDeErro(
            status = HttpStatusCode.UnprocessableEntity,
            corpo = """{"code":"inelegivel","message":"inelegivel","details":"turno_sobreposto"}""",
            lidoNoEstado = { it.ehConflitoHorario },
            consumir = { it.consumirNavegacaoParaConflitoHorario() },
        )
    }

    @Test
    fun `consumirNavegacaoParaVagaPreenchida desliga o evento e mantem o erro e a mensagem`() {
        validarConsumoDeErro(
            status = HttpStatusCode.Conflict,
            corpo = """{"code":"posicao_ja_preenchida","message":"alguém chegou antes"}""",
            lidoNoEstado = { it.ehVagaPreenchida },
            consumir = { it.consumirNavegacaoParaVagaPreenchida() },
        )
    }

    @Test
    fun `consumirNavegacaoParaVagaEncerrada desliga o evento e mantem o erro e a mensagem`() {
        validarConsumoDeErro(
            status = HttpStatusCode.Conflict,
            corpo = """{"code":"vaga_encerrada","message":"fechou 24h antes do inicio"}""",
            lidoNoEstado = { it.ehVagaEncerrada },
            consumir = { it.consumirNavegacaoParaVagaEncerrada() },
        )
    }

    @Test
    fun `consumirNavegacaoParaContaSuspensa desliga o evento e mantem o erro e a mensagem`() = runBlocking {
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
        val mensagem = viewModel.estado.value.mensagem

        assertTrue(viewModel.consumirNavegacaoParaContaSuspensa(), "o primeiro consumo recebe o evento")
        assertFalse(viewModel.consumirNavegacaoParaContaSuspensa(), "o segundo não recebe de novo")

        assertFalse(viewModel.estado.value.ehContaSuspensa)
        assertEquals(StatusCandidatura.ERRO, viewModel.estado.value.statusCandidatura)
        assertEquals(mensagem, viewModel.estado.value.mensagem)

        viewModel.candidatar().join()
        assertTrue(viewModel.estado.value.ehContaSuspensa, "uma nova candidatura recusada volta a sinalizar")
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

    // ---- Toque duplo em "Candidatar-se" (cartão LJpa8DDy): uma requisição e um evento só ----

    private val confirmadaJson =
        """{"estado":"confirmada","candidatura_id":"c1","posicao_id":"p1","turno_id":"t1","contato":{"nome":"Bar do Zé","telefone":"+5561999990000"}}"""
    private val cabecalhoJson = headersOf(HttpHeaders.ContentType, "application/json")

    @Test
    fun `dois toques seguidos em candidatar mandam uma requisicao so, um evento so e nao trocam a confirmada por erro`() = runBlocking {
        val liberar = kotlinx.coroutines.CompletableDeferred<Unit>()
        val pedidos = java.util.concurrent.atomic.AtomicInteger(0)
        val eventos = java.util.Collections.synchronizedList(mutableListOf<EventoDeTelemetria>())
        // Em urgência a vaga acaba na primeira: um segundo pedido (se saísse) voltaria 409 posicao_ja_preenchida.
        val engine = MockEngine {
            val n = pedidos.incrementAndGet()
            liberar.await()
            if (n == 1) respond(confirmadaJson, HttpStatusCode.OK, cabecalhoJson)
            else respond("""{"code":"posicao_ja_preenchida","message":"x"}""", HttpStatusCode.Conflict, cabecalhoJson)
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        // Com o detalhe já lido (aberta pelo id), a tela não faz a leitura de `detalhe_vaga`: o que se conta aqui são só as candidaturas.
        val vm = DetalheVagaViewModel(
            vagaDe("urgencia"), ServicoVagas(cliente), detalhe = vagaDoServidor(), escopo = CoroutineScope(Dispatchers.Default),
            registrarEvento = { evento, _, _ -> eventos += evento },
        )

        val primeiro = vm.candidatar()
        val segundo = vm.candidatar() // o segundo toque chega antes de a tela redesenhar e desligar o botão
        assertEquals(StatusCandidatura.ENVIANDO, vm.estado.value.statusCandidatura)
        liberar.complete(Unit)
        primeiro.join()
        segundo.join()

        assertEquals(1, pedidos.get())
        assertEquals(1, eventos.count { it == EventoDeTelemetria.CANDIDATURA_ENVIADA })
        val tela = vm.estado.value
        assertEquals(StatusCandidatura.CONFIRMADA, tela.statusCandidatura)
        assertEquals(true, tela.navegarParaConfirmada)
        assertEquals(false, tela.ehVagaPreenchida)
        assertEquals("Candidatura confirmada! Confira o contato abaixo.", tela.mensagem)
    }

    @Test
    fun `depois de uma falha o toque seguinte candidata de novo, e o evento sai so no sucesso`() = runBlocking {
        val pedidos = java.util.concurrent.atomic.AtomicInteger(0)
        val eventos = java.util.Collections.synchronizedList(mutableListOf<EventoDeTelemetria>())
        val engine = MockEngine {
            if (pedidos.incrementAndGet() == 1) respond("""{"code":"sem_rede","message":"x"}""", HttpStatusCode.InternalServerError, cabecalhoJson)
            else respond(confirmadaJson, HttpStatusCode.OK, cabecalhoJson)
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        // Com o detalhe já lido (aberta pelo id), a tela não faz a leitura de `detalhe_vaga`: o que se conta aqui são só as candidaturas.
        val vm = DetalheVagaViewModel(
            vagaDe("urgencia"), ServicoVagas(cliente), detalhe = vagaDoServidor(), escopo = CoroutineScope(Dispatchers.Default),
            registrarEvento = { evento, _, _ -> eventos += evento },
        )

        vm.candidatar().join()
        assertEquals(StatusCandidatura.ERRO, vm.estado.value.statusCandidatura)
        vm.candidatar().join()

        assertEquals(2, pedidos.get())
        assertEquals(StatusCandidatura.CONFIRMADA, vm.estado.value.statusCandidatura)
        assertEquals(1, eventos.count { it == EventoDeTelemetria.CANDIDATURA_ENVIADA })
    }

    @Test
    fun `toques simultaneos de varios threads mandam uma requisicao so (a trava e atomica)`() = runBlocking {
        repeat(60) { rodada ->
            val liberar = kotlinx.coroutines.CompletableDeferred<Unit>()
            val pedidos = java.util.concurrent.atomic.AtomicInteger(0)
            val engine = MockEngine {
                pedidos.incrementAndGet()
                liberar.await()
                respond(confirmadaJson, HttpStatusCode.OK, cabecalhoJson)
            }
            val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
            val vm = DetalheVagaViewModel(vagaDe("urgencia"), ServicoVagas(cliente), detalhe = vagaDoServidor(), escopo = CoroutineScope(Dispatchers.Default))
            val threads = 12
            val largada = java.util.concurrent.CyclicBarrier(threads)
            val jobs = java.util.Collections.synchronizedList(mutableListOf<kotlinx.coroutines.Job>())
            val pool = List(threads) { Thread { largada.await(); jobs += vm.candidatar() } }

            pool.forEach { it.start() }
            pool.forEach { it.join() }
            liberar.complete(Unit)
            jobs.toList().forEach { it.join() }

            assertEquals(1, pedidos.get(), "rodada $rodada")
        }
    }

    @Test
    fun `candidatar com funcao_incompativel marca ehFuncaoIncompativel uma vez, sem os outros destinos`() = runBlocking {
        val viewModel = viewModelComEngine(
            vaga = vagaDe("urgencia"),
            engine = MockEngine {
                respond(
                    content = """{"code":"inelegivel","message":"inelegivel","details":"funcao_incompativel"}""",
                    status = HttpStatusCode.UnprocessableEntity,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.candidatar().join()

        val estado = viewModel.estado.value
        assertEquals(StatusCandidatura.ERRO, estado.statusCandidatura)
        assertTrue(estado.ehFuncaoIncompativel)
        assertFalse(estado.ehConflitoHorario)
        assertFalse(estado.ehVagaPreenchida)
        assertFalse(estado.ehVagaEncerrada)
        assertFalse(estado.ehContaSuspensa)
        assertTrue(viewModel.consumirNavegacaoParaFuncaoIncompativel())
        assertFalse(viewModel.consumirNavegacaoParaFuncaoIncompativel(), "o evento dispara uma vez só")
        assertFalse(viewModel.estado.value.ehFuncaoIncompativel)
    }

    @Test
    fun `turno_sobreposto vai para o conflito e nao para ajustar as funcoes`() = runBlocking {
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

        assertTrue(viewModel.estado.value.ehConflitoHorario)
        assertFalse(viewModel.estado.value.ehFuncaoIncompativel)
    }

    // ── A leitura de detalhe_vaga ao abrir pelo feed (DLjTVc2e) ───────────────────────────────────────────────────────

    private fun detalheJson(responsavel: String = "Procure a gerente no balcão", rateio: Boolean? = true) =
        ClienteSupabase.jsonFrila.encodeToString(
            br.com.frila.core.rede.VagaDto.serializer(),
            vagaDoServidor().copy(responsavelLocal = responsavel, participaRateio = rateio),
        )

    @Test
    fun `aberta pelo feed le detalhe_vaga uma vez e completa o que a lista nao traz, sem trocar o que ja estava`() = runBlocking {
        val caminhos = java.util.Collections.synchronizedList(mutableListOf<String>())
        val corpos = java.util.Collections.synchronizedList(mutableListOf<String>())
        val engine = MockEngine { request ->
            caminhos += request.url.encodedPath
            corpos += (request.body as? io.ktor.http.content.TextContent)?.text.orEmpty()
            respond(detalheJson(), HttpStatusCode.OK, cabecalhoJson)
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val vaga = vagaDe("selecao")
        val vm = DetalheVagaViewModel(vaga, ServicoVagas(cliente), escopo = CoroutineScope(Dispatchers.Default))

        // Na hora, o que o feed trouxe; o detalhe chega depois.
        assertEquals(vaga, vm.estado.value.vaga)
        kotlinx.coroutines.withTimeout(5_000) { while (vm.estado.value.detalhe == null) kotlinx.coroutines.delay(5) }

        assertEquals(vaga, vm.estado.value.vaga, "a vaga do feed não é trocada")
        val detalhe = vm.estado.value.detalhe!!
        assertEquals("Procure a gerente no balcão", detalhe.responsavelLocal)
        assertEquals("Camisa preta", detalhe.traje)
        assertEquals("Chegar 15 minutos antes", detalhe.observacoes)
        assertEquals(true, detalhe.participaRateio)
        assertEquals(listOf("/rest/v1/rpc/detalhe_vaga"), caminhos.toList(), "uma leitura só")
        assertEquals(true, corpos.single().contains(vaga.id), "pede o detalhe desta vaga: ${corpos.single()}")
    }

    @Test
    fun `se a leitura do detalhe falha, fica o que veio do feed, sem erro de tela`() = runBlocking {
        // Falha de rede/servidor (um 404 agora marca a vaga como indisponível: item 160).
        val engine = MockEngine { respond("""{"code":"erro_interno","message":"x"}""", HttpStatusCode.InternalServerError, cabecalhoJson) }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val vaga = vagaDe("selecao")
        val vm = DetalheVagaViewModel(vaga, ServicoVagas(cliente), escopo = CoroutineScope(Dispatchers.Default))

        kotlinx.coroutines.delay(300)

        val estado = vm.estado.value
        assertEquals(vaga, estado.vaga)
        assertEquals(null, estado.detalhe)
        assertEquals(null, estado.mensagem)
        assertEquals(StatusCandidatura.NENHUMA, estado.statusCandidatura)
    }

    @Test
    fun `aberta pelo id, com o detalhe ja lido, nao le de novo`() = runBlocking {
        val pedidos = java.util.concurrent.atomic.AtomicInteger(0)
        val engine = MockEngine { pedidos.incrementAndGet(); respond(detalheJson("Outro"), HttpStatusCode.OK, cabecalhoJson) }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val vm = DetalheVagaViewModel(vagaDe("selecao"), ServicoVagas(cliente), detalhe = vagaDoServidor(), escopo = CoroutineScope(Dispatchers.Default))

        kotlinx.coroutines.delay(300)

        assertEquals(0, pedidos.get())
        assertEquals("Procure a gerente no balcão", vm.estado.value.detalhe!!.responsavelLocal)
    }

    // ── A vaga aberta pelo feed que já não está disponível (DLjTVc2e, item 160) ──────────────────────────────────────

    private fun viewModelQueLe(resposta: String, status: HttpStatusCode): DetalheVagaViewModel {
        val engine = MockEngine { respond(resposta, status, cabecalhoJson) }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        return DetalheVagaViewModel(vagaDe("selecao"), ServicoVagas(cliente), escopo = CoroutineScope(Dispatchers.Default))
    }

    private fun esperarALeitura(vm: DetalheVagaViewModel, pronto: (EstadoDetalheVaga) -> Boolean) = runBlocking {
        kotlinx.coroutines.withTimeout(5_000) { while (!pronto(vm.estado.value)) kotlinx.coroutines.delay(5) }
    }

    private fun vagaJson(estado: String, posicoesAbertas: Int) =
        ClienteSupabase.jsonFrila.encodeToString(br.com.frila.core.rede.VagaDto.serializer(), vagaDoServidor(estado = estado, posicoesAbertas = posicoesAbertas))

    @Test
    fun `404 de detalhe_vaga marca a vaga como indisponivel, sem trocar a vaga do feed`() {
        val vm = viewModelQueLe("""{"code":"nao_encontrado","message":"x"}""", HttpStatusCode.NotFound)
        esperarALeitura(vm) { it.indisponivel }

        assertEquals(true, vm.estado.value.indisponivel)
        assertEquals(vagaDe("selecao"), vm.estado.value.vaga)
        assertEquals(null, vm.estado.value.detalhe)
        assertEquals(null, vm.estado.value.mensagem)
    }

    @Test
    fun `200 com a vaga encerrada, preenchida ou sem posicao aberta marca como indisponivel`() {
        listOf("encerrada" to 2, "preenchida" to 0, "cancelada" to 2, "publicada" to 0).forEach { (estado, abertas) ->
            val vm = viewModelQueLe(vagaJson(estado, abertas), HttpStatusCode.OK)
            esperarALeitura(vm) { it.detalhe != null }
            assertEquals(true, vm.estado.value.indisponivel, "estado=$estado abertas=$abertas")
        }
    }

    @Test
    fun `200 com a vaga publicada e com posicao aberta segue disponivel`() {
        val vm = viewModelQueLe(vagaJson("publicada", 2), HttpStatusCode.OK)
        esperarALeitura(vm) { it.detalhe != null }
        assertEquals(false, vm.estado.value.indisponivel)
    }

    @Test
    fun `falha de rede ou erro do servidor continua silenciosa e a vaga segue disponivel`() {
        listOf(HttpStatusCode.InternalServerError, HttpStatusCode.BadGateway, HttpStatusCode.Forbidden).forEach { status ->
            val vm = viewModelQueLe("""{"code":"erro_interno","message":"x"}""", status)
            runBlocking { kotlinx.coroutines.delay(300) }
            assertEquals(false, vm.estado.value.indisponivel, "status=$status")
            assertEquals(null, vm.estado.value.detalhe, "status=$status")
        }
    }

    @Test
    fun `aberta pelo id, com o detalhe ja lido, nao marca indisponivel nem le`() {
        val engine = MockEngine { respond("""{"code":"nao_encontrado","message":"x"}""", HttpStatusCode.NotFound, cabecalhoJson) }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val vm = DetalheVagaViewModel(vagaDe("selecao"), ServicoVagas(cliente), detalhe = vagaDoServidor(), escopo = CoroutineScope(Dispatchers.Default))
        runBlocking { kotlinx.coroutines.delay(300) }
        assertEquals(false, vm.estado.value.indisponivel)
    }

    // ── A candidatura que confirma antes de detalhe_vaga voltar (item 174) ──────────────────────────────────────────

    /** O `detalhe_vaga` só responde quando o teste soltar; a candidatura responde na hora com [confirmadaJson]. */
    private fun viewModelComDetalheSegurado(
        portao: kotlinx.coroutines.CompletableDeferred<Unit>,
        modo: String = "urgencia",
        respostaDaCandidatura: String = confirmadaJson,
        detalhe: () -> Pair<String, HttpStatusCode>,
    ): DetalheVagaViewModel {
        val engine = MockEngine { request ->
            if (request.url.encodedPath.endsWith("/detalhe_vaga")) {
                portao.await()
                val (corpo, status) = detalhe()
                respond(corpo, status, cabecalhoJson)
            } else {
                respond(respostaDaCandidatura, HttpStatusCode.OK, cabecalhoJson)
            }
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        return DetalheVagaViewModel(vagaDe(modo), ServicoVagas(cliente), escopo = CoroutineScope(Dispatchers.Default))
    }

    @Test
    fun `a candidatura que confirma antes da leitura voltar com a vaga sem posicao aberta nao marca indisponivel`() = runBlocking {
        val portao = kotlinx.coroutines.CompletableDeferred<Unit>()
        val vm = viewModelComDetalheSegurado(portao) { vagaJson("publicada", 0) to HttpStatusCode.OK }

        vm.candidatar().join()
        assertEquals(StatusCandidatura.CONFIRMADA, vm.estado.value.statusCandidatura)
        portao.complete(Unit)
        esperarALeitura(vm) { it.detalhe != null }

        assertEquals(false, vm.estado.value.indisponivel, "quem acabou de conseguir o turno não vê 'não está mais disponível'")
        assertEquals(StatusCandidatura.CONFIRMADA, vm.estado.value.statusCandidatura)
    }

    @Test
    fun `a candidatura que confirma antes de um 404 do detalhe tambem nao marca indisponivel`() = runBlocking {
        val portao = kotlinx.coroutines.CompletableDeferred<Unit>()
        val vm = viewModelComDetalheSegurado(portao) { """{"code":"nao_encontrado","message":"x"}""" to HttpStatusCode.NotFound }

        vm.candidatar().join()
        portao.complete(Unit)
        kotlinx.coroutines.delay(300)

        assertEquals(false, vm.estado.value.indisponivel)
        assertEquals(StatusCandidatura.CONFIRMADA, vm.estado.value.statusCandidatura)
    }

    @Test
    fun `sem candidatura, a mesma leitura (sem posicao aberta) marca indisponivel`() = runBlocking {
        val portao = kotlinx.coroutines.CompletableDeferred<Unit>()
        val vm = viewModelComDetalheSegurado(portao) { vagaJson("publicada", 0) to HttpStatusCode.OK }

        portao.complete(Unit)
        esperarALeitura(vm) { it.detalhe != null }

        assertEquals(true, vm.estado.value.indisponivel)
    }

    @Test
    fun `a candidatura pendente por selecao antes da leitura voltar sem posicao aberta tambem nao marca indisponivel`() = runBlocking {
        val portao = kotlinx.coroutines.CompletableDeferred<Unit>()
        val pendente = """{"estado": "pendente", "candidatura_id": "c1", "posicao_id": null, "turno_id": null, "contato": null}"""
        val vm = viewModelComDetalheSegurado(portao, modo = "selecao", respostaDaCandidatura = pendente) { vagaJson("publicada", 0) to HttpStatusCode.OK }

        vm.candidatar().join()
        assertEquals(StatusCandidatura.PENDENTE, vm.estado.value.statusCandidatura)
        portao.complete(Unit)
        esperarALeitura(vm) { it.detalhe != null }

        assertEquals(false, vm.estado.value.indisponivel)
    }
}
