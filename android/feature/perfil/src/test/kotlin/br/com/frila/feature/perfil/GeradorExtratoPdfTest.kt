package br.com.frila.feature.perfil

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
 * [GeradorExtratoPdf] — o nome do arquivo — em JVM comum, sem tocar em `PdfDocument`.
 */
class GeradorExtratoPdfTest {

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
}
