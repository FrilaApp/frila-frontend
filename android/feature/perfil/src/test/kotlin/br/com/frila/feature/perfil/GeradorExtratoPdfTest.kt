package br.com.frila.feature.perfil

import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.TurnoDto
import br.com.frila.core.rede.VagaResumoDto
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `android.graphics.pdf.PdfDocument.startPage` lança `IllegalStateException: document is
 * closed!` sob Robolectric nesta configuração, em qualquer `@Config(sdk=...)` ou
 * `@GraphicsMode` testados (33, 35, LEGACY, NATIVE) — MEDIDO, limitação do ambiente de testes,
 * não do código de produção (que roda normalmente em dispositivo/emulador real, API estável do
 * Android desde o nível 1). Por isso este arquivo testa só a parte pura e determinística de
 * [GeradorExtratoPdf] — nome do arquivo, divisão em páginas e quebra de linha do rodapé — em
 * JVM comum, sem tocar em `PdfDocument`.
 */
class GeradorExtratoPdfTest {

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

    @Test
    fun `nomeArquivo segue o padrao extrato_frila com timestamp e extensao pdf`() {
        val instante = Instant.parse("2026-11-01T21:00:00Z")

        val nome = GeradorExtratoPdf.nomeArquivo(instante)

        assertEquals("extrato_frila_${instante.epochSecond}.pdf", nome)
        assertTrue(nome.startsWith("extrato_frila_"))
        assertTrue(nome.endsWith(".pdf"))
    }

    @Test
    fun `nomeArquivo nunca colide entre instantes diferentes`() {
        val nome1 = GeradorExtratoPdf.nomeArquivo(Instant.parse("2026-11-01T21:00:00Z"))
        val nome2 = GeradorExtratoPdf.nomeArquivo(Instant.parse("2026-11-01T21:00:01Z"))

        assertTrue(nome1 != nome2)
    }

    @Test
    fun `dividirEmPaginas com lista vazia devolve uma pagina vazia`() {
        val paginas = GeradorExtratoPdf.dividirEmPaginas(emptyList())

        assertEquals(1, paginas.size)
        assertTrue(paginas.first().isEmpty())
    }

    @Test
    fun `dividirEmPaginas com poucos turnos cabe tudo na primeira pagina`() {
        val turnos = (1..5).map { turno("t$it") }

        val paginas = GeradorExtratoPdf.dividirEmPaginas(turnos)

        assertEquals(1, paginas.size)
        assertEquals(5, paginas.first().size)
    }

    @Test
    fun `dividirEmPaginas com 60 turnos divide em multiplas paginas sem perder nenhum item (achado Shisui)`() {
        val turnos = (1..60).map { turno("t$it") }

        val paginas = GeradorExtratoPdf.dividirEmPaginas(turnos)

        assertTrue("extrato com 60 turnos deveria exigir mais de 1 página", paginas.size > 1)
        assertEquals(60, paginas.sumOf { it.size })
        // Nenhuma página pode exceder a capacidade calculada — senão volta a estourar o rodapé.
        assertTrue(paginas.first().size <= GeradorExtratoPdf.LINHAS_POR_PAGINA_PRIMEIRA)
        paginas.drop(1).forEach { pagina ->
            assertTrue(pagina.size <= GeradorExtratoPdf.LINHAS_POR_PAGINA_CONTINUACAO)
        }
    }

    @Test
    fun `dividirEmPaginas preserva a ordem e nao duplica nem descarta turnos`() {
        val turnos = (1..60).map { turno("t$it") }

        val paginas = GeradorExtratoPdf.dividirEmPaginas(turnos)
        val reconstruido = paginas.flatten()

        assertEquals(turnos.map { it.id }, reconstruido.map { it.id })
    }

    @Test
    fun `quebrarEmLinhas nao gera nenhuma linha acima do limite de caracteres (achado Shisui)`() {
        val aviso = "Valores combinados diretamente com os estabelecimentos parceiros. O Frila não realiza " +
            "intermediação, retenção ou custódia de valores financeiros (RN09)."

        val linhas = GeradorExtratoPdf.quebrarEmLinhas(aviso, maxCaracteres = 90)

        assertTrue(linhas.size > 1)
        linhas.forEach { linha -> assertTrue("linha estourou o limite: \"$linha\"", linha.length <= 90) }
    }

    @Test
    fun `quebrarEmLinhas preserva todas as palavras do texto original`() {
        val aviso = "Valores combinados diretamente com os estabelecimentos parceiros. O Frila não realiza " +
            "intermediação, retenção ou custódia de valores financeiros (RN09)."

        val linhas = GeradorExtratoPdf.quebrarEmLinhas(aviso, maxCaracteres = 90)

        assertEquals(aviso, linhas.joinToString(" "))
    }

    @Test
    fun `quebrarEmLinhas com texto vazio devolve lista vazia`() {
        assertTrue(GeradorExtratoPdf.quebrarEmLinhas("", maxCaracteres = 90).isEmpty())
    }

    @Test
    fun `quebrarEmLinhas com texto curto devolve uma unica linha`() {
        val linhas = GeradorExtratoPdf.quebrarEmLinhas("Texto curto.", maxCaracteres = 90)

        assertEquals(listOf("Texto curto."), linhas)
    }
}
