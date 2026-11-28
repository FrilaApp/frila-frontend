package br.com.frila.feature.chamadas.profissional

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
 * SC5jtZfS (item 199): o #1243 fez o 404 ao RECARREGAR desligar as respostas. O 404 ao RESPONDER (aceitar ou recusar) gravava só a
 * mensagem de erro: `podeResponder` seguia verdadeiro e Aceitar e Recusar ficavam na tela, e o servidor recusaria de novo. Com o
 * mesmo tratamento do recarregar, o 404 desliga as respostas, explica e mantém o que a pessoa lia (para denunciar, se quiser).
 */
class ChamadaRecebidaResponderBloqueadaTest {

    private val antesDoPrazo = Instant.parse("2026-11-17T00:00:00Z")

    private fun viewModelCom(rede: RedeDeTeste) = ChamadaRecebidaViewModel(
        chamadaId = Fixtures.CHAMADA,
        detalhar = rede.servico::detalheChamada,
        responder = rede.servico::responderChamada,
        agora = { antesDoPrazo },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    private fun redeAbertaQueRecusaA(resposta: HttpStatusCode, corpo: String) = RedeDeTeste().apply {
        ok("/rpc/detalhe_chamada", Fixtures.detalheChamadaJson())
        recusa("/rpc/responder_chamada", resposta, corpo)
    }

    private fun assertRespostasDesligadas(tela: EstadoChamadaRecebida) {
        assertFalse(tela.podeResponder, "o servidor recusaria a resposta de novo: não há botão a oferecer")
        assertEquals(TextosChamadaProfissional.INDISPONIVEL, tela.mensagemDeConcorrencia)
        assertNull(tela.erro, "não é falha de tentar de novo")
        assertFalse(tela.respondendo)
        assertFalse(tela.mostrarRecusa)
        assertNotNull(tela.detalhe, "a pessoa continua vendo quem chamou")
    }

    @Test
    fun `404 ao aceitar desliga as respostas e explica, sem apagar o detalhe`() = runBlocking {
        val vm = viewModelCom(redeAbertaQueRecusaA(HttpStatusCode.NotFound, Fixtures.erro("nao_encontrado")))
        vm.carregar().join()
        assertTrue(vm.estado.value.podeResponder)

        vm.aceitar().join()

        assertRespostasDesligadas(vm.estado.value)
    }

    @Test
    fun `404 ao recusar fecha a folha, desliga as respostas e explica`() = runBlocking {
        val vm = viewModelCom(redeAbertaQueRecusaA(HttpStatusCode.NotFound, Fixtures.erro("nao_encontrado")))
        vm.carregar().join()
        vm.abrirRecusa()
        vm.escolherMotivo("agenda")

        vm.recusar().join()

        assertRespostasDesligadas(vm.estado.value)
    }

    @Test
    fun `depois do 404 ao responder, tocar de novo em aceitar nao chama o servidor`() = runBlocking {
        val rede = redeAbertaQueRecusaA(HttpStatusCode.NotFound, Fixtures.erro("nao_encontrado"))
        val vm = viewModelCom(rede)
        vm.carregar().join()
        vm.aceitar().join()
        rede.ok("/rpc/responder_chamada", Fixtures.resultadoJson("aceita"))

        vm.aceitar().join()

        assertNull(vm.estado.value.resultado, "a segunda resposta não pode sair")
        assertEquals(TextosChamadaProfissional.INDISPONIVEL, vm.estado.value.mensagemDeConcorrencia)
    }

    @Test
    fun `conta suspensa ao responder continua sendo so o erro, com os botoes`() = runBlocking {
        // Contraprova: só o 404 (a chamada saiu do alcance) desliga as respostas; as outras recusas definitivas seguem como antes.
        val vm = viewModelCom(redeAbertaQueRecusaA(HttpStatusCode.Forbidden, Fixtures.erro("conta_suspensa")))
        vm.carregar().join()

        vm.aceitar().join()

        assertEquals(TextosChamadaProfissional.CONTA_SUSPENSA, vm.estado.value.erro)
        assertNull(vm.estado.value.mensagemDeConcorrencia)
        assertTrue(vm.estado.value.podeResponder)
    }
}
