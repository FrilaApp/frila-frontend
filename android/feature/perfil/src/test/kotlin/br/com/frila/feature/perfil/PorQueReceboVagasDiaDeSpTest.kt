package br.com.frila.feature.perfil

import br.com.frila.core.rede.CriteriosDeNotificacaoDto
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.JanelaDeDisponibilidadeDto
import br.com.frila.core.rede.ProtocoloDto
import java.util.TimeZone
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/**
 * Cartão 2ilMjGt7 (item 206): o dia do envio da contestação em "Por que recebo vagas" é o dia de Brasília. Um envio às 23:30 em SP
 * chega como 02:30Z do dia seguinte; cortar o texto nos 10 primeiros caracteres mostrava esse dia seguinte. O prazo é data civil.
 */
class PorQueReceboVagasDiaDeSpTest {

    private val fusoDoAparelho = TimeZone.getDefault()

    // O aparelho em UTC: com o fuso do aparelho em vez do de SP, o teste também cai (a máquina de quem roda pode já estar em SP).
    @Before
    fun aparelhoEmUtc() = TimeZone.setDefault(TimeZone.getTimeZone("UTC"))

    @After
    fun devolveOFuso() = TimeZone.setDefault(fusoDoAparelho)

    private fun criteriosParaTeste(contestacao: ProtocoloDto) = CriteriosDeNotificacaoDto(
        funcoes = listOf(FuncaoDto(id = "f-garcom", nome = "Garçom", categoria = "Salão")),
        disponibilidades = listOf(JanelaDeDisponibilidadeDto(diaSemana = 1, inicio = "08:00", fim = "16:00")),
        distanciaMaximaKm = 15.0,
        equipesDeConfianca = emptyList(),
        notificacoesNoMaximoACadaMin = 30,
        contestacao = contestacao,
    )

    private fun enviadoEm(criadaEm: String, prazo: String = "2026-11-27"): ProtocoloExibido? = runBlocking {
        val dto = ProtocoloDto("12345678-abcd-ef01-2345-6789abcdef01", "revisao_despacho", criadaEm, prazo)
        val vm = PorQueReceboVagasViewModel(carregarCriterios = { criteriosParaTeste(dto) }, escopo = this)
        vm.carregar().join()
        (vm.estado.value as EstadoPorQueReceboVagas.Conteudo).protocolo
    }

    @Test
    fun `envio as 23h30 em SP, que chega como 02h30Z do dia seguinte, mostra o dia de SP`() {
        val protocolo = enviadoEm("2026-11-21T02:30:00Z")

        assertEquals("20/11/2026", protocolo?.enviadoEm)
    }

    @Test
    fun `o dia muda para o seguinte so a partir das 03h00Z, meia-noite de SP`() {
        assertEquals("20/11/2026", enviadoEm("2026-11-21T02:59:59Z")?.enviadoEm)
        assertEquals("21/11/2026", enviadoEm("2026-11-21T03:00:00Z")?.enviadoEm)
    }

    @Test
    fun `instante com deslocamento tambem vira o dia de SP`() {
        assertEquals("20/11/2026", enviadoEm("2026-11-21T04:30:00+02:00")?.enviadoEm)
    }

    @Test
    fun `o prazo e data civil e fica como veio, sem passar pelo fuso`() {
        assertEquals("27/11/2026", enviadoEm("2026-11-21T02:30:00Z", prazo = "2026-11-27")?.prazoRespostaAte)
    }

    @Test
    fun `o prazo nunca e deslocado pelo fuso, mesmo se vier com hora`() {
        // 02:30Z em SP ainda é o dia anterior: o prazo, data civil, segue o dia escrito.
        assertEquals("28/11/2026", enviadoEm("2026-11-21T02:30:00Z", prazo = "2026-11-28T02:30:00Z")?.prazoRespostaAte)
    }

    @Test
    fun `texto que nao e um instante cai no corte da data, sem quebrar`() {
        assertEquals("21/11/2026", enviadoEm("2026-11-21")?.enviadoEm)
    }
}
