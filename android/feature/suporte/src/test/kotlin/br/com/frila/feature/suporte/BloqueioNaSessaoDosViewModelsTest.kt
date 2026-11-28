package br.com.frila.feature.suporte

import br.com.frila.core.dominio.modelo.BloqueiosDaSessao
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.rede.BloqueioDto
import br.com.frila.core.rede.DenunciarDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ProtocoloDto
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * I1PonzKJ: o bloqueio sobrevive a sair e voltar. Quem escreve o conjunto é o `registrandoAposSucesso` que o Koin põe em volta do
 * pedido; os view models só nascem sabendo o que ele já guardou. Aqui o pedido é o mesmo `registrandoAposSucesso`, como no grafo.
 */
class BloqueioNaSessaoDosViewModelsTest {

    private val casa = "casa-1"
    private val pedidos = mutableListOf<Pair<String, String>>()
    private var falhar = false
    private val sessao = BloqueiosDaSessao()

    private val bloquear: suspend (String, String) -> BloqueioDto = { tipo, id ->
        sessao.registrandoAposSucesso(tipo, id) {
            pedidos += tipo to id
            if (falhar) throw ErroDaApi(CodigoErroAPI.SEM_REDE, "sem_rede", null, "x")
            BloqueioDto(tipo, id, "2026-11-10T12:00:00Z")
        }
    }

    private fun avulso() = BloqueioDeAlvoViewModel(
        alvoTipo = TipoDeAlvo.ESTABELECIMENTO, alvoId = casa, bloquear = bloquear, bloqueios = sessao,
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    private fun denuncia() = DenunciaViewModel(
        alvoTipo = TipoDeAlvo.ESTABELECIMENTO, alvoId = casa,
        denunciar = { _: DenunciarDto -> ProtocoloDto("6f1c2a4e-1111-2222-3333-444455556666", "denuncia", "2026-11-10T12:00:00Z", "2026-11-17") },
        bloquear = bloquear, bloqueios = sessao, escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    @Test
    fun `bloqueio avulso, depois de bloquear, uma tela nova do mesmo alvo ja nasce bloqueada e nao pede de novo`() {
        val primeira = avulso()
        primeira.confirmar()
        assertTrue(primeira.estado.value.bloqueado)

        val segunda = avulso()

        assertTrue(segunda.estado.value.bloqueado, "ao sair e voltar, o bloqueado nao pode reaparecer")
        segunda.abrirDialogo()
        segunda.confirmar()
        assertEquals(1, pedidos.size)
    }

    @Test
    fun `denuncia, depois de bloquear, uma tela nova do mesmo alvo ja nasce bloqueada`() {
        val primeira = denuncia()
        primeira.abrirDialogoBloqueio()
        primeira.confirmarBloqueio()
        assertTrue(primeira.estado.value.bloqueado)

        val segunda = denuncia()

        assertTrue(segunda.estado.value.bloqueado)
        segunda.confirmarBloqueio()
        assertEquals(1, pedidos.size)
    }

    @Test
    fun `outro alvo nao nasce bloqueado`() {
        avulso().confirmar()

        val outro = BloqueioDeAlvoViewModel(
            alvoTipo = TipoDeAlvo.PROFISSIONAL, alvoId = casa, bloquear = bloquear, bloqueios = sessao,
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )

        assertFalse(outro.estado.value.bloqueado)
    }

    @Test
    fun `se o servidor recusa, a tela nova nao nasce bloqueada`() {
        falhar = true
        val primeira = avulso()
        primeira.confirmar()
        assertFalse(primeira.estado.value.bloqueado)

        val segunda = avulso()

        assertFalse(segunda.estado.value.bloqueado)
        assertFalse(sessao.contem(TipoDeAlvo.ESTABELECIMENTO, casa))
    }

    @Test
    fun `depois de limpar a sessao, a tela nova volta a nao estar bloqueada`() {
        avulso().confirmar()
        denuncia().let { assertTrue(it.estado.value.bloqueado) }

        sessao.limpar()

        assertFalse(avulso().estado.value.bloqueado)
        assertFalse(denuncia().estado.value.bloqueado)
    }
}
