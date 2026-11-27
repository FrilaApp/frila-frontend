package br.com.frila.feature.conta

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ExclusaoDeContaDto
import br.com.frila.core.rede.ServicoPerfil
import java.io.IOException
import java.time.Instant
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ExclusaoDeContaViewModelTest {

    private val sucesso = ExclusaoDeContaDto(
        perfilRemovidoEm = "2026-11-10T12:00:00Z",
        dadosApagadosAte = "2026-11-25",
        turnosCancelados = 2,
    )

    private fun erro(codigo: CodigoErroAPI, original: String = codigo.name.lowercase()) =
        ErroDaApi(codigo = codigo, codigoOriginal = original, detalhes = null, mensagemCrua = original)

    private fun viewModel(
        aoConcluir: () -> Unit = {},
        excluir: suspend () -> ExclusaoDeContaDto = { sucesso },
    ) = ExclusaoDeContaViewModel(
        excluir = excluir,
        aoConcluir = aoConcluir,
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    @Test
    fun `sem a caixa marcada o pedido nao sai`() = runBlocking {
        var chamadas = 0
        val vm = viewModel(excluir = { chamadas++; sucesso })

        vm.confirmarExclusao().join()

        assertEquals(0, chamadas)
        assertFalse(vm.estado.value.podeExcluir)
    }

    @Test
    fun `com a caixa marcada exclui, guarda o resultado e avisa o chamador uma vez`() = runBlocking {
        var concluiu = 0
        val vm = viewModel(aoConcluir = { concluiu++ })

        vm.alterarConfirmacao(true)
        vm.confirmarExclusao().join()

        assertEquals(sucesso, vm.estado.value.resultado)
        assertFalse(vm.estado.value.excluindo)
        assertNull(vm.estado.value.mensagemErro)
        assertEquals(1, concluiu)
    }

    @Test
    fun `segundo toque durante o pedido nao dispara um segundo pedido`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        var chamadas = 0
        val vm = viewModel(excluir = { chamadas++; liberar.await(); sucesso })

        vm.alterarConfirmacao(true)
        val primeiro = vm.confirmarExclusao()
        assertTrue(vm.estado.value.excluindo)
        val segundo = vm.confirmarExclusao()
        liberar.complete(Unit)
        withTimeout(5_000) {
            primeiro.join()
            segundo.join()
        }

        assertEquals(1, chamadas)
    }

    @Test
    fun `depois de concluida a exclusao nao repete nem aceita desmarcar`() = runBlocking {
        var chamadas = 0
        val vm = viewModel(excluir = { chamadas++; sucesso })
        vm.alterarConfirmacao(true)
        vm.confirmarExclusao().join()

        vm.confirmarExclusao().join()
        vm.alterarConfirmacao(false)

        assertEquals(1, chamadas)
        assertTrue(vm.estado.value.confirmouConsequencias)
    }

    @Test
    fun `administrador_unico mostra a mensagem especifica, nao conclui e permite tentar de novo`() = runBlocking {
        var concluiu = 0
        var falhar = true
        val vm = viewModel(aoConcluir = { concluiu++ }, excluir = {
            if (falhar) throw erro(CodigoErroAPI.ADMINISTRADOR_UNICO) else sucesso
        })
        vm.alterarConfirmacao(true)

        vm.confirmarExclusao().join()

        assertEquals(TextosExclusaoDeConta.ERRO_ADMIN_UNICO, vm.estado.value.mensagemErro)
        assertNull(vm.estado.value.resultado)
        assertFalse(vm.estado.value.excluindo)
        assertEquals(0, concluiu)

        falhar = false
        vm.confirmarExclusao().join()

        assertNull(vm.estado.value.mensagemErro)
        assertNotNull(vm.estado.value.resultado)
        assertEquals(1, concluiu)
    }

    @Test
    fun `sem rede e sessao expirada tem mensagens proprias e o resto cai na generica`() = runBlocking {
        val casos = mapOf(
            CodigoErroAPI.SEM_REDE to TextosExclusaoDeConta.ERRO_SEM_REDE,
            CodigoErroAPI.NAO_AUTENTICADO to TextosExclusaoDeConta.ERRO_SESSAO,
            CodigoErroAPI.DESCONHECIDO to TextosExclusaoDeConta.ERRO_GENERICO,
        )
        casos.forEach { (codigo, mensagem) ->
            val vm = viewModel(excluir = { throw erro(codigo) })
            vm.alterarConfirmacao(true)
            vm.confirmarExclusao().join()
            assertEquals(mensagem, vm.estado.value.mensagemErro, codigo.name)
        }
    }

    @Test
    fun `excecao que nao e ErroDaApi nao deixa a tela travada em excluindo`() = runBlocking {
        val vm = viewModel(excluir = { throw IllegalStateException("corpo html do gateway") })
        vm.alterarConfirmacao(true)

        vm.confirmarExclusao().join()

        assertFalse(vm.estado.value.excluindo)
        assertEquals(TextosExclusaoDeConta.ERRO_GENERICO, vm.estado.value.mensagemErro)
    }

    @Test
    fun `contra o ServicoPerfil real, 202 conclui e 409 administrador_unico vira a mensagem especifica`() = runBlocking {
        fun servico(status: HttpStatusCode, corpo: String) = ServicoPerfil(
            ClienteSupabase(
                baseUrl = "https://frila.supabase.co",
                apiKey = "chave-teste",
                engine = MockEngine {
                    respond(corpo, status, headersOf(HttpHeaders.ContentType, "application/json"))
                },
            ),
        )

        val ok = servico(
            HttpStatusCode.Accepted,
            """{"perfil_removido_em":"2026-11-10T12:00:00Z","dados_apagados_ate":"2026-11-25","turnos_cancelados":0}""",
        )
        val vmOk = viewModel(excluir = { ok.excluirConta() })
        vmOk.alterarConfirmacao(true)
        vmOk.confirmarExclusao().join()
        assertEquals("2026-11-25", vmOk.estado.value.resultado?.dadosApagadosAte)

        val conflito = servico(HttpStatusCode.Conflict, """{"code":"administrador_unico","message":"transfira"}""")
        val vmErro = viewModel(excluir = { conflito.excluirConta() })
        vmErro.alterarConfirmacao(true)
        vmErro.confirmarExclusao().join()
        assertEquals(TextosExclusaoDeConta.ERRO_ADMIN_UNICO, vmErro.estado.value.mensagemErro)
    }

    // ---- 9NpQTfGG: lista os turnos futuros do profissional antes de confirmar ----

    private val agora = Instant.parse("2026-11-20T15:00:00Z")

    private fun turno(id: String, inicio: String, fim: String = "2026-12-31T23:00:00Z", funcao: String = "garçom", contraparte: String = "Bar do Zé") =
        TurnoFuturoDaExclusao(
            id = id, funcao = funcao, contraparte = contraparte,
            inicio = Instant.parse(inicio), fim = Instant.parse(fim), local = "CLS 405 Bloco $id",
        )

    private fun viewModelComTurnos(
        chamadas: MutableList<Int> = mutableListOf(),
        excluir: suspend () -> ExclusaoDeContaDto = { sucesso },
        limitada: Boolean = false,
        consultar: suspend () -> List<TurnoFuturoDaExclusao>,
    ) = ExclusaoDeContaViewModel(
        excluir = excluir,
        consultarTurnos = { chamadas += 1; ConsultaDeTurnosDaExclusao(consultar(), limitada) },
        relogio = { agora },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    private fun ExclusaoDeContaViewModel.ids(): List<String> =
        (estado.value.turnosFuturos as TurnosFuturosDaExclusao.Lista).turnos.map { it.id }

    @Test
    fun `um turno passado e dois futuros listam exatamente os dois futuros, do mais proximo ao mais distante`() = runBlocking {
        val vm = viewModelComTurnos {
            listOf(
                turno("passado", "2026-11-10T20:00:00Z", "2026-11-11T02:00:00Z"),
                turno("distante", "2026-12-20T20:00:00Z"),
                turno("proximo", "2026-11-25T20:00:00Z"),
            )
        }

        vm.carregarTurnos().join()

        assertEquals(listOf("proximo", "distante"), vm.ids())
        val primeiro = (vm.estado.value.turnosFuturos as TurnosFuturosDaExclusao.Lista).turnos.first()
        assertEquals("garçom", primeiro.funcao)
        assertEquals("Bar do Zé", primeiro.contraparte)
        assertEquals("CLS 405 Bloco proximo", primeiro.local)
        assertEquals(Instant.parse("2026-11-25T20:00:00Z"), primeiro.inicio)
    }

    @Test
    fun `turno que comeca exatamente agora ja nao e futuro`() = runBlocking {
        val vm = viewModelComTurnos {
            listOf(turno("agora", "2026-11-20T15:00:00Z"), turno("um-segundo-depois", "2026-11-20T15:00:01Z"))
        }

        vm.carregarTurnos().join()

        assertEquals(listOf("um-segundo-depois"), vm.ids())
    }

    @Test
    fun `a consulta limitada (a da casa) chega a lista, e a do profissional nao e limitada`() = runBlocking {
        val limitada = viewModelComTurnos(limitada = true) { listOf(turno("t", "2026-11-25T20:00:00Z")) }
        limitada.carregarTurnos().join()
        assertEquals(true, (limitada.estado.value.turnosFuturos as TurnosFuturosDaExclusao.Lista).limitada)

        val completa = viewModelComTurnos { listOf(turno("t", "2026-11-25T20:00:00Z")) }
        completa.carregarTurnos().join()
        assertEquals(false, (completa.estado.value.turnosFuturos as TurnosFuturosDaExclusao.Lista).limitada)
    }

    @Test
    fun `sem turnos futuros a lista e vazia, e nao indisponivel`() = runBlocking {
        val vm = viewModelComTurnos { listOf(turno("passado", "2026-11-10T20:00:00Z")) }

        vm.carregarTurnos().join()

        assertEquals(TurnosFuturosDaExclusao.Lista(emptyList()), vm.estado.value.turnosFuturos)
    }

    @Test
    fun `a leitura falhando avisa que a lista esta indisponivel e a exclusao continua liberada`() = runBlocking {
        var excluiu = 0
        for (falha in listOf<Throwable>(erro(CodigoErroAPI.SEM_REDE), erro(CodigoErroAPI.NAO_AUTENTICADO), IOException("x"), IllegalStateException("corpo ilegível"))) {
            val vm = viewModelComTurnos(excluir = { excluiu++; sucesso }) { throw falha }

            vm.carregarTurnos().join()

            assertEquals(TurnosFuturosDaExclusao.Indisponivel, vm.estado.value.turnosFuturos, falha.toString())
            vm.alterarConfirmacao(true)
            assertTrue(vm.estado.value.podeExcluir, "a lista indisponível não bloqueia a exclusão: $falha")
            vm.confirmarExclusao().join()
            assertNotNull(vm.estado.value.resultado, falha.toString())
        }
        assertEquals(4, excluiu)
    }

    @Test
    fun `carregar os turnos nao exclui nada e nao mexe na confirmacao, e abrir duas vezes le uma vez so`() = runBlocking {
        var excluiu = 0
        val leituras = mutableListOf<Int>()
        val vm = viewModelComTurnos(chamadas = leituras, excluir = { excluiu++; sucesso }) { listOf(turno("t", "2026-11-25T20:00:00Z")) }

        vm.carregarTurnos().join()
        vm.carregarTurnos().join()

        assertEquals(0, excluiu)
        assertFalse(vm.estado.value.confirmouConsequencias)
        assertFalse(vm.estado.value.podeExcluir)
        assertEquals(1, leituras.size, "a segunda abertura reaproveita a leitura")
    }

    @Test
    fun `enquanto le, mostra carregando, sem bloquear a confirmacao`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        val vm = viewModelComTurnos { liberar.await(); emptyList() }

        val job = vm.carregarTurnos()
        assertEquals(TurnosFuturosDaExclusao.Carregando, vm.estado.value.turnosFuturos)
        vm.alterarConfirmacao(true)
        assertTrue(vm.estado.value.podeExcluir)

        liberar.complete(Unit)
        job.join()
        assertEquals(TurnosFuturosDaExclusao.Lista(emptyList()), vm.estado.value.turnosFuturos)
    }

    @Test
    fun `sem consulta injetada a tela segue so com o texto geral`() = runBlocking {
        val vm = viewModel()

        vm.carregarTurnos().join()

        assertEquals(TurnosFuturosDaExclusao.NaoConsultados, vm.estado.value.turnosFuturos)
    }
}

