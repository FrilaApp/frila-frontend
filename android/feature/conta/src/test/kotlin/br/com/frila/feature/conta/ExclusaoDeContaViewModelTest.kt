package br.com.frila.feature.conta

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ExclusaoDeContaDto
import br.com.frila.core.rede.ServicoPerfil
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
}
