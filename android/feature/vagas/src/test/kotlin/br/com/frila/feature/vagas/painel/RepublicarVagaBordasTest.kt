package br.com.frila.feature.vagas.painel

import br.com.frila.core.rede.VagaPublicadaDto
import java.time.Duration
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

/**
 * Cartão hl9Nriq4 (item 236): as bordas da validação local da republicação (`RepublicarVagaViewModel.validar`): início depois de agora
 * (igual a agora não vale), duração de 2 a 16 horas (2 h e 16 h valem, um segundo a menos ou a mais não), e 24 horas de antecedência
 * na seleção (exatas não valem). O teste antigo só usava 1 h, 17 h e início 60 s no passado, e `<` virar `<=`, `>` virar `>=` e
 * `!isAfter` virar `isBefore` passavam.
 */
class RepublicarVagaBordasTest {

    private val agora: Instant = Instant.parse("2026-11-10T15:00:30Z")
    private val pedidos = mutableListOf<Pair<Instant, Instant>>()

    private fun tentar(inicio: Instant, duracao: Duration, selecao: Boolean = false): EstadoRepublicarVaga {
        pedidos.clear()
        val vm = RepublicarVagaViewModel(
            vagaId = "v1",
            selecao = selecao,
            duracaoOriginal = Duration.ofHours(6),
            republicar = { _, i, f, _ -> pedidos += i to f; VagaPublicadaDto("nova", listOf("p1")) },
            relogio = { agora },
            novaChave = { "chave" },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        vm.mudarInicio(inicio)
        vm.mudarFim(inicio.plus(duracao))
        vm.republicar()
        return vm.estado.value
    }

    private fun EstadoRepublicarVaga.aceita() = pedidos.size == 1 && erroInicio == null && erroFim == null

    // ---- início depois de agora ----

    @Test
    fun `inicio igual a agora e recusado e um segundo depois vale`() {
        val igual = tentar(agora, Duration.ofHours(6))
        assertEquals(TextosRepublicarVaga.INICIO_NO_PASSADO, igual.erroInicio)
        assertEquals(0, pedidos.size)

        assertEquals(true, tentar(agora.plusSeconds(1), Duration.ofHours(6)).aceita())
    }

    @Test
    fun `um segundo antes de agora tambem e recusado`() {
        assertEquals(TextosRepublicarVaga.INICIO_NO_PASSADO, tentar(agora.minusSeconds(1), Duration.ofHours(6)).erroInicio)
        assertEquals(0, pedidos.size)
    }

    // ---- duração de 2 a 16 horas ----

    @Test
    fun `exatamente 2 horas valem e um segundo a menos e turno curto`() {
        val inicio = agora.plusSeconds(3600)
        assertEquals(true, tentar(inicio, Duration.ofHours(2)).aceita())

        val curto = tentar(inicio, Duration.ofHours(2).minusSeconds(1))
        assertEquals(TextosRepublicarVaga.TURNO_CURTO, curto.erroFim)
        assertEquals(0, pedidos.size)
    }

    @Test
    fun `exatamente 16 horas valem e um segundo a mais e turno longo`() {
        val inicio = agora.plusSeconds(3600)
        assertEquals(true, tentar(inicio, Duration.ofHours(16)).aceita())

        val longo = tentar(inicio, Duration.ofHours(16).plusSeconds(1))
        assertEquals(TextosRepublicarVaga.TURNO_LONGO, longo.erroFim)
        assertEquals(0, pedidos.size)
    }

    @Test
    fun `duracao zero e negativa dizem que o fim e antes do inicio, nao que o turno e curto`() {
        val inicio = agora.plusSeconds(3600)
        assertEquals(TextosRepublicarVaga.FIM_ANTES_DO_INICIO, tentar(inicio, Duration.ZERO).erroFim)
        assertEquals(TextosRepublicarVaga.FIM_ANTES_DO_INICIO, tentar(inicio, Duration.ofSeconds(-1)).erroFim)
        assertEquals(TextosRepublicarVaga.TURNO_CURTO, tentar(inicio, Duration.ofSeconds(1)).erroFim)
    }

    // ---- 24 horas de antecedência na seleção ----

    @Test
    fun `na selecao, inicio a 24 horas exatas e recusado e um segundo a mais vale`() {
        val exato = tentar(agora.plus(Duration.ofHours(24)), Duration.ofHours(6), selecao = true)
        assertEquals(TextosRepublicarVaga.SELECAO_SEM_ANTECEDENCIA, exato.erroInicio)
        assertEquals(0, pedidos.size)

        assertEquals(true, tentar(agora.plus(Duration.ofHours(24)).plusSeconds(1), Duration.ofHours(6), selecao = true).aceita())
    }

    @Test
    fun `na urgencia as 24 horas nao se aplicam`() {
        assertEquals(true, tentar(agora.plus(Duration.ofHours(1)), Duration.ofHours(6), selecao = false).aceita())
        assertNull(tentar(agora.plus(Duration.ofHours(24)), Duration.ofHours(6), selecao = false).erroInicio)
    }

    @Test
    fun `recusa de inicio e de duracao aparecem juntas, cada uma no seu campo`() {
        val estado = tentar(agora, Duration.ofHours(1))

        assertEquals(TextosRepublicarVaga.INICIO_NO_PASSADO, estado.erroInicio)
        assertEquals(TextosRepublicarVaga.TURNO_CURTO, estado.erroFim)
        assertEquals(0, pedidos.size)
    }
}
