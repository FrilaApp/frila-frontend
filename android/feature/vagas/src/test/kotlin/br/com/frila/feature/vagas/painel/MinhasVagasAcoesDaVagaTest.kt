package br.com.frila.feature.vagas.painel

import br.com.frila.core.rede.PainelDto
import br.com.frila.core.rede.PosicaoNoPainelDto
import br.com.frila.core.rede.VagaNoPainelDto
import br.com.frila.core.rede.VagaResumoDto
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** O que o painel diz que a casa pode fazer com cada vaga (L2-3): cancelar. */
class MinhasVagasAcoesDaVagaTest {

    /** Terça-feira, 10/11/2026, 12h em Brasília. */
    private val agora: Instant = Instant.parse("2026-11-10T15:00:00Z")

    private fun vaga(id: String, inicio: String, fim: String, estado: String = "publicada", republicavel: Int? = null) = VagaNoPainelDto(
        vaga = VagaResumoDto(id, "Garçom", "SQN 108", "Asa Norte", inicio, fim, 16_000),
        republicavelEmUrgencia = republicavel,
        modo = "selecao", estado = estado, oculta = false, alertaVagaVazia = false, candidatosPendentes = 0,
        posicoes = listOf(PosicaoNoPainelDto(id = "p-$id", estado = "aberta", emAtraso = false)),
    )

    private fun itens(vararg vagas: VagaNoPainelDto): Map<String, ItemMinhaVaga> {
        val vm = MinhasVagasViewModel(
            estabelecimentoId = "est-1",
            buscarPainel = { _, _, _ -> Result.success(PainelDto("est-1", vagas.toList(), emptyList())) },
            relogio = { agora },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        vm.carregar()
        return (vm.estado.value.lista as ListaMinhasVagas.Sucesso).itens.associateBy { it.id }
    }

    @Test
    fun `so a vaga que ainda nao comecou, nem cancelada nem encerrada, pode ser cancelada`() {
        val itens = itens(
            vaga("futura", "2026-11-12T21:00:00Z", "2026-11-13T03:00:00Z"),
            vaga("preenchida", "2026-11-12T21:00:00Z", "2026-11-13T03:00:00Z", estado = "preenchida"),
            vaga("em-curso", "2026-11-10T14:00:00Z", "2026-11-10T20:00:00Z"),
            vaga("cancelada", "2026-11-12T21:00:00Z", "2026-11-13T03:00:00Z", estado = "cancelada"),
            vaga("encerrada", "2026-11-12T21:00:00Z", "2026-11-13T03:00:00Z", estado = "encerrada"),
            vaga("ilegivel", "ontem", "2026-11-13T03:00:00Z"),
        )

        assertTrue(itens.getValue("futura").podeCancelar)
        assertTrue(itens.getValue("preenchida").podeCancelar)
        assertFalse(itens.getValue("em-curso").podeCancelar)
        assertFalse(itens.getValue("cancelada").podeCancelar)
        assertFalse(itens.getValue("encerrada").podeCancelar)
        assertFalse(itens.getValue("ilegivel").podeCancelar)
    }
}
