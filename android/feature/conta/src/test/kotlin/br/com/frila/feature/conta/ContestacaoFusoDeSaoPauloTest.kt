package br.com.frila.feature.conta

import br.com.frila.core.rede.ProtocoloDto
import br.com.frila.core.rede.SituacaoDaContaDto
import br.com.frila.core.rede.SuspensaoDaContaDto
import java.time.Instant
import java.util.TimeZone
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test

/**
 * Cartão VzSDSOsh (item 208): `formatarDia` e `emAnalise` contam o dia no fuso de São Paulo (`FUSO_DA_CONTA`). Os instantes dos testes
 * antigos caem em 12:00Z ou 15:00Z, onde SP e UTC dão o mesmo dia, e `FUSO_DA_CONTA` virar UTC passava. Aqui os instantes ficam entre
 * 00:00Z e 03:00Z, onde os dois dias diferem; o aparelho é forçado a UTC para a máquina em SP não esconder o defeito, e nenhum teste
 * passa a zona: valem os padrões.
 */
class ContestacaoFusoDeSaoPauloTest {

    private val fusoDoAparelho = TimeZone.getDefault()

    @BeforeEach
    fun aparelhoEmUtc() = TimeZone.setDefault(TimeZone.getTimeZone("UTC"))

    @AfterEach
    fun devolveOFuso() = TimeZone.setDefault(fusoDoAparelho)

    private fun protocolo(criadaEm: String = "2026-11-18T01:30:00Z", prazo: String = "2026-11-17") =
        ProtocoloDto(ocorrenciaId = "6f1c2a4e-aaaa-4aaa-8aaa-aaaaaaaaaaaa", tipo = "contestacao", criadaEm = criadaEm, prazoRespostaAte = prazo)

    @Test
    fun `o fuso da conta e o de Sao Paulo`() {
        assertEquals("America/Sao_Paulo", FUSO_DA_CONTA.id)
    }

    @Test
    fun `criada as 01h30Z mostra o dia anterior, o de Sao Paulo`() {
        assertEquals("17/11/2026", formatarDia("2026-11-18T01:30:00Z"))
        assertEquals("17/11/2026", protocolo().paraExibicao().enviadoEm)
    }

    @Test
    fun `o dia vira so a partir das 03h00Z, meia-noite de Sao Paulo`() {
        assertEquals("17/11/2026", formatarDia("2026-11-18T02:59:59Z"))
        assertEquals("18/11/2026", formatarDia("2026-11-18T03:00:00Z"))
    }

    @Test
    fun `as 01h00Z de 18 com prazo em 17 ainda esta em analise, porque em Sao Paulo ainda e dia 17`() {
        val exibido = protocolo(prazo = "2026-11-17").paraExibicao()

        assertTrue(exibido.emAnalise(Instant.parse("2026-11-18T01:00:00Z")))
    }

    @Test
    fun `a analise acaba na meia-noite de Sao Paulo, as 03h00Z do dia seguinte ao prazo`() {
        val exibido = protocolo(prazo = "2026-11-17").paraExibicao()

        assertTrue(exibido.emAnalise(Instant.parse("2026-11-18T02:59:59Z")))
        assertFalse(exibido.emAnalise(Instant.parse("2026-11-18T03:00:00Z")))
    }

    // ---- pelos ViewModels, sem passar a zona: vale o padrão de cada um ----

    @Test
    fun `contestar o despacho mostra o dia de Sao Paulo no envio`() {
        val vm = ContestarDespachoViewModel(
            pedirRevisao = { protocolo() },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        vm.mudarRelato("Relato com mais de dez caracteres.")

        vm.contestar()

        assertEquals("17/11/2026", vm.estado.value.protocolo?.enviadoEm)
    }

    @Test
    fun `conta suspensa com contestacao em 17 ainda esta em analise as 01h00Z de 18, e mostra o envio em 17`() {
        val vm = ContaSuspensaViewModel(
            buscarSituacao = {
                SituacaoDaContaDto(
                    estado = "suspensa",
                    suspensao = SuspensaoDaContaDto(motivo = "Faltas sem aviso", desde = "2026-11-10T12:00:00Z", contestacao = protocolo(prazo = "2026-11-17")),
                )
            },
            contestar = { error("o teste não contesta") },
            aoReativar = {},
            relogio = { Instant.parse("2026-11-18T01:00:00Z") },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )

        vm.carregar()

        assertTrue(vm.estado.value.emAnalise)
        assertEquals("17/11/2026", vm.estado.value.protocolo?.enviadoEm)
    }

    @Test
    fun `conta suspensa contesta as 01h30Z e a analise vale ate o prazo em Sao Paulo`() {
        val vm = ContaSuspensaViewModel(
            buscarSituacao = { SituacaoDaContaDto(estado = "suspensa", suspensao = SuspensaoDaContaDto(motivo = "Faltas sem aviso", desde = "2026-11-10T12:00:00Z", contestacao = null)) },
            contestar = { protocolo(prazo = "2026-11-17") },
            aoReativar = {},
            relogio = { Instant.parse("2026-11-18T01:00:00Z") },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        vm.carregar()
        vm.abrirFormulario()
        vm.mudarRelato("Relato com mais de dez caracteres.")

        vm.enviarContestacao()

        assertTrue(vm.estado.value.emAnalise)
        assertEquals("17/11/2026", vm.estado.value.protocolo?.enviadoEm)
    }
}
