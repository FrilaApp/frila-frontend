package br.com.frila.core.dominio.modelo

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** I1PonzKJ: o conjunto dos bloqueados da sessão. Só reflete o que o servidor confirmou, e só vive na memória da sessão. */
class BloqueiosDaSessaoTest {

    private val casa = AlvoBloqueado(TipoDeAlvo.ESTABELECIMENTO, "id-1")

    @Test
    fun `registrar e remover mudam o conjunto, e registrar de novo e idempotente`() {
        val bloqueios = BloqueiosDaSessao()

        bloqueios.registrar(casa)
        bloqueios.registrar(casa)

        assertTrue(bloqueios.contem(casa))
        assertTrue(bloqueios.contem(TipoDeAlvo.ESTABELECIMENTO, "id-1"))
        assertEquals(setOf(casa), bloqueios.alvos.value)

        bloqueios.remover(casa)

        assertFalse(bloqueios.contem(casa))
        assertTrue(bloqueios.alvos.value.isEmpty())
    }

    @Test
    fun `o mesmo id com outro tipo nao e o mesmo alvo`() {
        val bloqueios = BloqueiosDaSessao()

        bloqueios.registrar(casa)

        assertFalse(bloqueios.contem(TipoDeAlvo.PROFISSIONAL, "id-1"))
        assertTrue(bloqueios.contem(TipoDeAlvo.ESTABELECIMENTO, "id-1"))
        assertFalse(bloqueios.contem(TipoDeAlvo.ESTABELECIMENTO, "id-2"))
    }

    @Test
    fun `limpar esvazia o conjunto`() {
        val bloqueios = BloqueiosDaSessao()
        bloqueios.registrar(casa)
        bloqueios.registrar(AlvoBloqueado(TipoDeAlvo.PROFISSIONAL, "p-1"))

        bloqueios.limpar()

        assertTrue(bloqueios.alvos.value.isEmpty())
        assertFalse(bloqueios.contem(casa))
    }

    @Test
    fun `deChaves entende os dois tipos do contrato e devolve nulo para um desconhecido`() {
        assertEquals(AlvoBloqueado(TipoDeAlvo.PROFISSIONAL, "x"), AlvoBloqueado.deChaves("profissional", "x"))
        assertEquals(AlvoBloqueado(TipoDeAlvo.ESTABELECIMENTO, "x"), AlvoBloqueado.deChaves("estabelecimento", "x"))
        assertNull(AlvoBloqueado.deChaves("equipe", "x"))
    }

    @Test
    fun `registrandoAposSucesso registra depois da acao, nao antes, e devolve o resultado`() = runBlocking {
        val bloqueios = BloqueiosDaSessao()
        var registradoDuranteAAcao: Boolean? = null

        val resultado = bloqueios.registrandoAposSucesso("estabelecimento", "id-1") {
            registradoDuranteAAcao = bloqueios.contem(casa)
            "resposta do servidor"
        }

        assertEquals("resposta do servidor", resultado)
        assertEquals(false, registradoDuranteAAcao)
        assertTrue(bloqueios.contem(casa))
    }

    @Test
    fun `se o servidor recusa, a falha sobe e nada e registrado`() = runBlocking {
        val bloqueios = BloqueiosDaSessao()

        val erro = assertThrows(IllegalStateException::class.java) {
            runBlocking { bloqueios.registrandoAposSucesso("estabelecimento", "id-1") { throw IllegalStateException("422") } }
        }

        assertEquals("422", erro.message)
        assertFalse(bloqueios.contem(casa))
        assertTrue(bloqueios.alvos.value.isEmpty())
    }

    @Test
    fun `se o pedido e cancelado no meio, nada e registrado`() = runBlocking {
        val bloqueios = BloqueiosDaSessao()
        val portao = CompletableDeferred<Unit>()

        val trabalho = async(start = CoroutineStart.UNDISPATCHED) {
            bloqueios.registrandoAposSucesso("estabelecimento", "id-1") { portao.await() }
        }
        trabalho.cancel(CancellationException("fora"))
        runCatching { trabalho.await() }

        assertFalse(bloqueios.contem(casa))
    }

    @Test
    fun `tipo desconhecido roda a acao e nao registra nada`() = runBlocking {
        val bloqueios = BloqueiosDaSessao()
        var rodou = false

        bloqueios.registrandoAposSucesso("equipe", "id-1") { rodou = true }

        assertTrue(rodou)
        assertTrue(bloqueios.alvos.value.isEmpty())
    }

    @Test
    fun `removendoAposSucesso remove depois da acao, e a falha deixa o bloqueado onde estava`() = runBlocking {
        val bloqueios = BloqueiosDaSessao()
        bloqueios.registrar(casa)

        assertThrows(IllegalStateException::class.java) {
            runBlocking { bloqueios.removendoAposSucesso("estabelecimento", "id-1") { throw IllegalStateException("rede") } }
        }
        assertTrue(bloqueios.contem(casa), "a falha do desbloqueio nao pode soltar o bloqueado")

        var aindaBloqueadoDuranteAAcao: Boolean? = null
        bloqueios.removendoAposSucesso("estabelecimento", "id-1") { aindaBloqueadoDuranteAAcao = bloqueios.contem(casa) }

        assertEquals(true, aindaBloqueadoDuranteAAcao)
        assertFalse(bloqueios.contem(casa))
    }

    @Test
    fun `um bloqueio em voo quando a sessao termina nao entra no conjunto da conta seguinte`() = runBlocking {
        val bloqueios = BloqueiosDaSessao()
        val portao = CompletableDeferred<Unit>()
        val noAr = CompletableDeferred<Unit>()

        val trabalho = async(start = CoroutineStart.UNDISPATCHED) {
            bloqueios.registrandoAposSucesso("estabelecimento", "id-1") { noAr.complete(Unit); portao.await() }
        }
        noAr.await()
        bloqueios.limpar() // logout, troca de conta ou expiracao com o pedido ainda em voo
        portao.complete(Unit)
        trabalho.await()

        assertFalse(bloqueios.contem(casa), "o servidor confirmou, mas a conta que bloqueou ja saiu")
        assertTrue(bloqueios.alvos.value.isEmpty())
    }

    @Test
    fun `um desbloqueio em voo quando a sessao termina nao mexe no conjunto da conta seguinte`() = runBlocking {
        val bloqueios = BloqueiosDaSessao()
        bloqueios.registrar(casa)
        val portao = CompletableDeferred<Unit>()
        val noAr = CompletableDeferred<Unit>()

        val trabalho = async(start = CoroutineStart.UNDISPATCHED) {
            bloqueios.removendoAposSucesso("estabelecimento", "id-1") { noAr.complete(Unit); portao.await() }
        }
        noAr.await()
        bloqueios.limpar()
        bloqueios.registrar(casa) // a conta seguinte bloqueou a mesma casa por conta propria
        portao.complete(Unit)
        trabalho.await()

        assertTrue(bloqueios.contem(casa), "o desbloqueio da conta anterior nao pode soltar o bloqueio da nova")
    }

    @Test
    fun `depois de limpar, o conjunto volta a aceitar registros normais`() = runBlocking {
        val bloqueios = BloqueiosDaSessao()
        bloqueios.limpar()

        bloqueios.registrandoAposSucesso("estabelecimento", "id-1") { }

        assertTrue(bloqueios.contem(casa))
    }
}
