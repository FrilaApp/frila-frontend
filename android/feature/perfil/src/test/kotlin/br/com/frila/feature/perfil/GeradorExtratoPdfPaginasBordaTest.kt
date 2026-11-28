package br.com.frila.feature.perfil

import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.TurnoDto
import br.com.frila.core.rede.VagaResumoDto
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

/**
 * Cartão T6uRN84B (item 288): as bordas da paginação do extrato. O teste antigo usa só 0, 5 e 60 turnos; com `<` virando `<=` (uma página
 * vazia com exatamente a capacidade da primeira, ou da primeira mais a da continuação) nada ficava vermelho. Fora: o histórico de turnos e
 * o PDF da casa.
 */
class GeradorExtratoPdfPaginasBordaTest {

    private fun turno(id: String) = TurnoDto(
        id = id,
        posicaoId = "posicao-$id",
        vaga = VagaResumoDto(
            id = "vaga-$id",
            funcao = "garçom",
            local = "SQN 108",
            regiaoAdministrativa = "Asa Norte",
            inicioEm = "2026-11-01T21:00:00Z",
            fimEm = "2026-11-02T03:00:00Z",
            valorCentavos = 16_000L,
        ),
        contraparte = PerfilPublicoDto(
            id = "e1",
            tipo = "estabelecimento",
            nome = "Bar do Zé",
            reputacao = ReputacaoDto(positivas = 1, total = 1, turnosConsiderados = 1, turnosRealizados = 1),
        ),
        contatoVisivelAte = "2026-11-09T03:00:00Z",
        verificacao = "pendente",
        valorAcordadoCentavos = 16_000L,
        podeAvaliar = false,
        estado = "cumprida",
    )

    private val primeira = GeradorExtratoPdf.LINHAS_POR_PAGINA_PRIMEIRA
    private val continuacao = GeradorExtratoPdf.LINHAS_POR_PAGINA_CONTINUACAO

    private fun tamanhos(quantos: Int) = GeradorExtratoPdf.dividirEmPaginas((1..quantos).map { turno("t$it") }).map { it.size }

    @Test
    fun `a capacidade das paginas e a medida da geometria, 25 na primeira e 33 nas seguintes`() {
        assertEquals(25, primeira)
        assertEquals(33, continuacao)
    }

    @Test
    fun `exatamente a capacidade da primeira pagina e uma pagina so, sem pagina vazia atras`() {
        assertEquals(listOf(primeira), tamanhos(primeira))
    }

    @Test
    fun `um turno acima da capacidade da primeira abre a segunda com esse turno`() {
        assertEquals(listOf(primeira, 1), tamanhos(primeira + 1))
    }

    @Test
    fun `primeira mais a continuacao cabem em duas paginas, sem terceira vazia`() {
        assertEquals(listOf(primeira, continuacao), tamanhos(primeira + continuacao))
    }

    @Test
    fun `um turno acima de primeira mais continuacao abre a terceira com esse turno`() {
        assertEquals(listOf(primeira, continuacao, 1), tamanhos(primeira + continuacao + 1))
    }

    @Test
    fun `um turno a menos que a capacidade da primeira cabe numa pagina`() {
        assertEquals(listOf(primeira - 1), tamanhos(primeira - 1))
        assertEquals(listOf(1), tamanhos(1))
    }

    @Test
    fun `nenhuma pagina fica vazia em nenhuma quantidade de 1 a 200 e a ordem e preservada`() {
        for (quantos in 1..200) {
            val turnos = (1..quantos).map { turno("t$it") }
            val paginas = GeradorExtratoPdf.dividirEmPaginas(turnos)

            assertFalse("$quantos turnos: página vazia em ${paginas.map { it.size }}", paginas.any { it.isEmpty() })
            assertEquals("$quantos turnos: ordem", turnos.map { it.id }, paginas.flatten().map { it.id })
            assertEquals("$quantos turnos: primeira", minOf(quantos, primeira), paginas.first().size)
            paginas.drop(1).dropLast(1).forEach { assertEquals("$quantos turnos: miolo cheio", continuacao, it.size) }
        }
    }

    @Test
    fun `sem turnos continua uma pagina vazia, a do cabecalho e do resumo`() {
        assertEquals(listOf(0), tamanhos(0))
    }
}
