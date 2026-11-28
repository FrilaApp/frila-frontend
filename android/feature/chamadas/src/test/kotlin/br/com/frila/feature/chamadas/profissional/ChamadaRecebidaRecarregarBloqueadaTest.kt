package br.com.frila.feature.chamadas.profissional

import io.ktor.client.network.sockets.ConnectTimeoutException
import io.ktor.http.HttpStatusCode
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * xsZd5wZO: depois de bloquear a casa (pela Denúncia aberta a partir da chamada), a volta recarrega `detalhe_chamada` e o servidor
 * responde 404 (RF26). O ramo de erro gravava a mensagem e mantinha o detalhe antigo "aberta", então `podeResponder` seguia verdadeiro
 * e Aceitar e Recusar ficavam na tela sem funcionar. Com a chamada já na tela, o 404 desliga as respostas.
 */
class ChamadaRecebidaRecarregarBloqueadaTest {

    private val antesDoPrazo = Instant.parse("2026-11-17T00:00:00Z")

    private fun viewModelCom(rede: RedeDeTeste) = ChamadaRecebidaViewModel(
        chamadaId = Fixtures.CHAMADA,
        detalhar = rede.servico::detalheChamada,
        responder = rede.servico::responderChamada,
        agora = { antesDoPrazo },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    private fun redeAberta() = RedeDeTeste().apply { ok("/rpc/detalhe_chamada", Fixtures.detalheChamadaJson()) }

    @Test
    fun `404 ao recarregar com a chamada na tela desliga as respostas e explica, sem apagar o que a pessoa ja lia`() = runBlocking {
        val rede = redeAberta()
        val vm = viewModelCom(rede)
        vm.carregar().join()
        assertTrue(vm.estado.value.podeResponder)

        rede.recusa("/rpc/detalhe_chamada", HttpStatusCode.NotFound, Fixtures.erro("nao_encontrado"))
        vm.carregar().join()

        val tela = vm.estado.value
        assertFalse(tela.podeResponder, "o servidor recusaria a resposta: nao ha botao a oferecer")
        assertEquals(TextosChamadaProfissional.INDISPONIVEL, tela.mensagemDeConcorrencia)
        assertNull(tela.erro)
        assertFalse(tela.mostrarRecusa)
        assertNotNull(tela.detalhe, "a pessoa continua vendo quem chamou, para denunciar se quiser")
    }

    @Test
    fun `404 ao recarregar fecha a folha de recusa que estivesse aberta`() = runBlocking {
        val rede = redeAberta()
        val vm = viewModelCom(rede)
        vm.carregar().join()
        vm.abrirRecusa()
        assertTrue(vm.estado.value.mostrarRecusa)

        rede.recusa("/rpc/detalhe_chamada", HttpStatusCode.NotFound, Fixtures.erro("nao_encontrado"))
        vm.carregar().join()

        assertFalse(vm.estado.value.mostrarRecusa)
    }

    @Test
    fun `falha de rede ao recarregar nao desliga as respostas, so mostra o erro`() = runBlocking {
        val rede = redeAberta()
        val vm = viewModelCom(rede)
        vm.carregar().join()

        rede.resposta("/rpc/detalhe_chamada") { throw ConnectTimeoutException("sem rede") }
        vm.carregar().join()

        assertEquals(TextosChamadaProfissional.ERRO, vm.estado.value.erro)
        assertNull(vm.estado.value.mensagemDeConcorrencia)
        assertTrue(vm.estado.value.podeResponder, "sem rede nao se sabe nada: os botoes continuam")
    }

    @Test
    fun `404 na primeira carga, sem detalhe, continua sendo o erro de carga`() = runBlocking {
        val rede = RedeDeTeste()
        rede.recusa("/rpc/detalhe_chamada", HttpStatusCode.NotFound, Fixtures.erro("nao_encontrado"))
        val vm = viewModelCom(rede)

        vm.carregar().join()

        assertEquals(TextosChamadaProfissional.INDISPONIVEL, vm.estado.value.erro)
        assertNull(vm.estado.value.detalhe)
        assertNull(vm.estado.value.mensagemDeConcorrencia)
    }
}
