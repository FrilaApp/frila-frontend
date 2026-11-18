package br.com.frila.feature.conta

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ProtocoloDto
import br.com.frila.core.rede.SituacaoDaContaDto
import br.com.frila.core.rede.SuspensaoDaContaDto
import java.time.Instant
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** Um protocolo como o servidor o devolve, para os testes de contestação. Prazo: 24/11/2026. */
internal fun protocoloDoServidor(tipo: String = "contestacao", prazo: String = "2026-11-24") =
    ProtocoloDto(ocorrenciaId = "6f1c2a4e-aaaa-4aaa-8aaa-aaaaaaaaaaaa", tipo = tipo, criadaEm = "2026-11-17T12:00:00Z", prazoRespostaAte = prazo)

class ContaSuspensaViewModelTest {

    /** Terça-feira, 17/11/2026, 12h em Brasília. */
    private val agora: Instant = Instant.parse("2026-11-17T15:00:00Z")
    private val relato = "Não reconheço a falta do turno de sábado."

    private var leituras = 0
    private val relatosEnviados = mutableListOf<String>()
    private var reativacoes = 0

    private fun erro(codigo: CodigoErroAPI, detalhes: String? = null) = ErroDaApi(codigo, codigo.name.lowercase(), detalhes, "x")

    private fun suspensa(contestacao: ProtocoloDto? = null) = SituacaoDaContaDto(
        estado = "suspensa",
        suspensao = SuspensaoDaContaDto(motivo = "Faltas sem aviso", desde = "2026-11-10T12:00:00Z", contestacao = contestacao),
    )

    private fun viewModel(
        situacao: suspend () -> SituacaoDaContaDto = { suspensa() },
        contestar: suspend () -> ProtocoloDto = { protocoloDoServidor() },
    ) = ContaSuspensaViewModel(
        buscarSituacao = { leituras++; situacao() },
        contestar = { texto -> relatosEnviados += texto; contestar() },
        aoReativar = { reativacoes++ },
        relogio = { agora },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    @Test
    fun `carregar mostra o motivo e o dia da suspensao, e deixa contestar`() {
        val vm = viewModel()

        vm.carregar()

        val estado = vm.estado.value
        assertEquals("Faltas sem aviso", estado.motivo)
        assertEquals("10/11/2026", estado.desde)
        assertNull(estado.protocolo)
        assertTrue(estado.podeContestar)
        assertFalse(estado.carregando)
    }

    @Test
    fun `suspensao ja contestada mostra o protocolo curto, as datas e se ainda esta em analise, e nao oferece outra`() {
        val noPrazo = viewModel(situacao = { suspensa(protocoloDoServidor(prazo = "2026-11-17")) }).apply { carregar() }.estado.value
        val vencido = viewModel(situacao = { suspensa(protocoloDoServidor(prazo = "2026-11-16")) }).apply { carregar() }.estado.value

        assertEquals("6F1C2A4E", noPrazo.protocolo!!.numero)
        assertEquals("17/11/2026", noPrazo.protocolo!!.enviadoEm)
        assertEquals("17/11/2026", noPrazo.protocolo!!.prazoRespostaAte)
        assertTrue(noPrazo.emAnalise, "o último dia do prazo ainda conta")
        assertFalse(noPrazo.podeContestar)
        assertFalse(vencido.emAnalise)
        assertFalse(vencido.podeContestar)
    }

    @Test
    fun `se a conta voltou a ficar ativa, a tela avisa quem abriu e nao oferece contestar`() {
        val vm = viewModel(situacao = { SituacaoDaContaDto(estado = "ativa") })

        vm.carregar()

        assertTrue(vm.estado.value.contaReativada)
        assertFalse(vm.estado.value.podeContestar)
        assertEquals(1, reativacoes)
    }

    @Test
    fun `falha ao ler a situacao vira texto do Frila e nao impede de contestar`() {
        val casos = listOf(
            erro(CodigoErroAPI.SEM_REDE) to TextosContaSuspensa.ERRO_SEM_REDE,
            erro(CodigoErroAPI.NAO_AUTENTICADO) to TextosContaSuspensa.ERRO_SESSAO,
            erro(CodigoErroAPI.DESCONHECIDO) to TextosContaSuspensa.ERRO_GENERICO,
            IllegalStateException("corpo que não é JSON") to TextosContaSuspensa.ERRO_GENERICO,
        )
        for ((falha, texto) in casos) {
            val estado = viewModel(situacao = { throw falha }).apply { carregar() }.estado.value

            assertEquals(texto, estado.mensagemErro, falha.toString())
            assertFalse(estado.carregando)
            assertTrue(estado.podeContestar)
        }
    }

    @Test
    fun `relato vazio ou curto nao vai ao servidor e a tela diz por que`() {
        val vm = viewModel()
        vm.abrirFormulario()

        vm.mudarRelato("   ")
        assertNull(vm.enviarContestacao())
        val vazio = vm.estado.value.mensagemErro
        vm.mudarRelato(" curto ")
        assertNull(vm.enviarContestacao())

        assertEquals(TextosContaSuspensa.RELATO_OBRIGATORIO, vazio)
        assertEquals(TextosContaSuspensa.RELATO_MINIMO, vm.estado.value.mensagemErro)
        assertFalse(vm.estado.value.relatoValido)
        assertTrue(relatosEnviados.isEmpty())
    }

    @Test
    fun `contestar manda o relato sem espacos nas pontas, guarda o protocolo, fecha o formulario e nao envia de novo`() {
        val vm = viewModel()
        vm.abrirFormulario()
        vm.mudarRelato("  $relato  ")

        vm.enviarContestacao()

        val estado = vm.estado.value
        assertEquals(listOf(relato), relatosEnviados)
        assertEquals("6F1C2A4E", estado.protocolo!!.numero)
        assertEquals("24/11/2026", estado.protocolo!!.prazoRespostaAte)
        assertTrue(estado.emAnalise)
        assertFalse(estado.formularioAberto)
        assertFalse(estado.podeContestar)
        assertNull(vm.enviarContestacao())
        assertEquals(1, relatosEnviados.size)
    }

    @Test
    fun `dois toques seguidos mandam uma contestacao so`() {
        val resposta = CompletableDeferred<ProtocoloDto>()
        val vm = viewModel(contestar = { resposta.await() })
        vm.abrirFormulario()
        vm.mudarRelato(relato)

        vm.enviarContestacao()
        assertTrue(vm.estado.value.enviando)
        assertNull(vm.enviarContestacao())
        resposta.complete(protocoloDoServidor())

        assertEquals(1, relatosEnviados.size)
        assertFalse(vm.estado.value.enviando)
    }

    @Test
    fun `contestacao que ja existe - a tela avisa, fecha o formulario e busca o protocolo na situacao da conta`() {
        var situacao = suspensa()
        val vm = viewModel(situacao = { situacao }, contestar = { throw erro(CodigoErroAPI.CONTESTACAO_JA_ABERTA) })
        vm.carregar()
        vm.abrirFormulario()
        vm.mudarRelato(relato)
        situacao = suspensa(protocoloDoServidor())

        vm.enviarContestacao()

        val estado = vm.estado.value
        assertTrue(estado.contestacaoJaExiste)
        assertFalse(estado.formularioAberto)
        assertFalse(estado.podeContestar)
        assertEquals("6F1C2A4E", estado.protocolo!!.numero)
        assertEquals(2, leituras)
    }

    @Test
    fun `sem suspensao ativa ao contestar, a conta voltou - avisa quem abriu`() {
        val vm = viewModel(contestar = { throw erro(CodigoErroAPI.SEM_SUSPENSAO_ATIVA) })
        vm.abrirFormulario()
        vm.mudarRelato(relato)

        vm.enviarContestacao()

        assertTrue(vm.estado.value.contaReativada)
        assertFalse(vm.estado.value.enviando)
        assertEquals(1, reativacoes)
    }

    @Test
    fun `as outras recusas da contestacao viram texto do Frila e deixam tentar de novo`() {
        val casos = listOf(
            erro(CodigoErroAPI.CAMPO_INVALIDO, "relato") to TextosContaSuspensa.RELATO_MINIMO,
            erro(CodigoErroAPI.CAMPO_OBRIGATORIO, "relato") to TextosContaSuspensa.RELATO_OBRIGATORIO,
            erro(CodigoErroAPI.SEM_REDE) to TextosContaSuspensa.ERRO_SEM_REDE,
            erro(CodigoErroAPI.NAO_AUTENTICADO) to TextosContaSuspensa.ERRO_SESSAO,
            erro(CodigoErroAPI.DESCONHECIDO) to TextosContaSuspensa.ERRO_GENERICO,
            IllegalStateException("corpo que não é JSON") to TextosContaSuspensa.ERRO_GENERICO,
        )
        for ((falha, texto) in casos) {
            val vm = viewModel(contestar = { throw falha })
            vm.abrirFormulario()
            vm.mudarRelato(relato)

            vm.enviarContestacao()

            val estado = vm.estado.value
            assertEquals(texto, estado.mensagemErro, falha.toString())
            assertTrue(estado.formularioAberto)
            assertTrue(estado.podeContestar)
            assertFalse(estado.enviando)
        }
    }

    @Test
    fun `cancelar fecha o formulario e limpa o erro, e mexer no relato limpa o erro`() {
        val vm = viewModel()
        vm.abrirFormulario()
        vm.enviarContestacao()
        assertEquals(TextosContaSuspensa.RELATO_OBRIGATORIO, vm.estado.value.mensagemErro)

        vm.mudarRelato("a")
        assertNull(vm.estado.value.mensagemErro)
        vm.enviarContestacao()
        vm.cancelarFormulario()

        assertFalse(vm.estado.value.formularioAberto)
        assertNull(vm.estado.value.mensagemErro)
    }

    @Test
    fun `prazo com data ilegivel aparece como veio e nao afirma que esta em analise`() {
        val estado = viewModel(situacao = { suspensa(protocoloDoServidor(prazo = "em breve")) }).apply { carregar() }.estado.value

        assertEquals("em breve", estado.protocolo!!.prazoRespostaAte)
        assertFalse(estado.emAnalise)
    }
}
