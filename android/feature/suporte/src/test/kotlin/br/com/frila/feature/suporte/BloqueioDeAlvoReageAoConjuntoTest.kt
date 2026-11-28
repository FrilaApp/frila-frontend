package br.com.frila.feature.suporte

import br.com.frila.core.dominio.modelo.AlvoBloqueado
import br.com.frila.core.dominio.modelo.BloqueiosDaSessao
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.rede.BloqueioDto
import br.com.frila.core.rede.ErroDaApi
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * xsZd5wZO: o bloqueio avulso da chamada recebida nasce antes de a pessoa abrir a Denúncia e bloquear por lá. Ele precisa perceber o
 * bloqueio feito depois, por outra tela, enquanto está vivo: senão a chamada seguia oferecendo "Bloquear" e responder a quem já foi bloqueado.
 */
class BloqueioDeAlvoReageAoConjuntoTest {

    private val casa = AlvoBloqueado(TipoDeAlvo.ESTABELECIMENTO, "casa-1")
    private val sessao = BloqueiosDaSessao()
    private var falhar = false

    private fun avulso() = BloqueioDeAlvoViewModel(
        alvoTipo = TipoDeAlvo.ESTABELECIMENTO,
        alvoId = "casa-1",
        bloquear = { tipo, id ->
            sessao.registrandoAposSucesso(tipo, id) {
                if (falhar) throw ErroDaApi(CodigoErroAPI.SEM_REDE, "sem_rede", null, "x")
                BloqueioDto(tipo, id, "2026-11-10T12:00:00Z")
            }
        },
        bloqueios = sessao,
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    @Test
    fun `um bloqueio feito por outra tela, depois de o view model nascer, vira bloqueado nele`() {
        val vm = avulso()
        assertFalse(vm.estado.value.bloqueado)

        sessao.registrar(casa) // o bloqueio pela tela de Denuncia

        assertTrue(vm.estado.value.bloqueado)
    }

    @Test
    fun `um desbloqueio feito por outra tela volta a oferecer o bloqueio, e a limpeza da sessao tambem`() {
        sessao.registrar(casa)
        val vm = avulso()
        assertTrue(vm.estado.value.bloqueado)

        sessao.remover(casa)
        assertFalse(vm.estado.value.bloqueado)

        sessao.registrar(casa)
        assertTrue(vm.estado.value.bloqueado)
        sessao.limpar()
        assertFalse(vm.estado.value.bloqueado)
    }

    @Test
    fun `bloquear por ele mesmo continua funcionando, e uma recusa nao marca bloqueado`() {
        val vm = avulso()
        vm.confirmar()
        assertTrue(vm.estado.value.bloqueado)

        falhar = true
        val outro = BloqueioDeAlvoViewModel(
            alvoTipo = TipoDeAlvo.PROFISSIONAL, alvoId = "p-1",
            bloquear = { tipo, id -> sessao.registrandoAposSucesso(tipo, id) { throw ErroDaApi(CodigoErroAPI.SEM_REDE, "sem_rede", null, "x") } },
            bloqueios = sessao, escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        outro.confirmar()

        assertFalse(outro.estado.value.bloqueado)
        assertNotNull(outro.estado.value.erro)
        assertEquals(setOf(casa), sessao.alvos.value)
    }

    @Test
    fun `bloquear outro alvo na sessao nao marca este`() {
        val vm = avulso()

        sessao.registrar(AlvoBloqueado(TipoDeAlvo.PROFISSIONAL, "casa-1"))
        sessao.registrar(AlvoBloqueado(TipoDeAlvo.ESTABELECIMENTO, "casa-2"))

        assertFalse(vm.estado.value.bloqueado)
    }
}
