package br.com.frila.feature.perfil

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.pdf.PdfDocument
import br.com.frila.core.dominio.modelo.Dinheiro
import br.com.frila.core.rede.TurnoDto
import java.io.File
import java.io.FileOutputStream
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * Extrato de remunerações em PDF (RF16/RNF10), desenhado nativamente com
 * [android.graphics.pdf.PdfDocument] — sem bibliotecas terceiras, zero impacto no tamanho do APK.
 *
 * RN09 (Zero Escrow): o extrato é só uma leitura dos valores combinados diretamente entre
 * profissional e estabelecimento. O rodapé deixa isso explícito — o Frila nunca retém, custodia
 * nem intermedia o pagamento.
 */
object GeradorExtratoPdf {

    // Página A4 a 72 dpi: 595 x 842 pt, margens de 40 pt.
    private const val LARGURA_PAGINA = 595
    private const val ALTURA_PAGINA = 842
    private const val MARGEM = 40f
    private const val LARGURA_UTIL = LARGURA_PAGINA - 2 * MARGEM

    private const val COR_TERRACOTA = 0xFFEA5A36.toInt()
    private const val COR_CAIXA_RESUMO = 0xFFF2F2F0.toInt()
    private const val COR_TEXTO = 0xFF111110.toInt()
    private const val COR_TEXTO_SECUNDARIO = 0xFF5C5B57.toInt()

    private val FUSO_BRASILIA: ZoneId = ZoneId.of("America/Sao_Paulo")
    private val FORMATO_EMISSAO = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm")
    private val FORMATO_LINHA = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm")

    private val rotuloStatus = mapOf(
        "cumprida" to "Cumprido",
        "confirmada" to "Agendado",
        "cancelada" to "Cancelado",
    )

    /**
     * Gera o PDF em [diretorioSaida] (criado se não existir) e devolve o [File] resultante.
     * Nome do arquivo com timestamp para nunca colidir entre exportações (`extrato_frila_{ts}.pdf`).
     */
    fun gerar(
        diretorioSaida: File,
        resumo: ResumoFinanceiroPerfil,
        turnos: List<TurnoDto>,
        nomeProfissional: String,
        instanteGeracao: Instant = Instant.now(),
    ): File {
        diretorioSaida.mkdirs()
        val arquivo = File(diretorioSaida, nomeArquivo(instanteGeracao))

        val documento = PdfDocument()
        val pagina = documento.startPage(
            PdfDocument.PageInfo.Builder(LARGURA_PAGINA, ALTURA_PAGINA, 1).create(),
        )
        val tela = pagina.canvas

        var y = desenharCabecalho(tela, nomeProfissional, instanteGeracao)
        y = desenharCaixaResumo(tela, y, resumo)
        y = desenharTabelaTurnos(tela, y, turnos)
        desenharRodape(tela)

        documento.finishPage(pagina)

        FileOutputStream(arquivo).use { saida -> documento.writeTo(saida) }
        documento.close()

        return arquivo
    }

    /** Nome seguro e sem colisão entre exportações: `extrato_frila_{timestamp}.pdf`. */
    fun nomeArquivo(instanteGeracao: Instant): String = "extrato_frila_${instanteGeracao.epochSecond}.pdf"

    private fun desenharCabecalho(tela: Canvas, nomeProfissional: String, instanteGeracao: Instant): Float {
        var y = MARGEM

        val pincelFaixa = Paint().apply { color = COR_TERRACOTA }
        tela.drawRect(RectF(0f, 0f, LARGURA_PAGINA.toFloat(), MARGEM / 2), pincelFaixa)

        val pincelTitulo = Paint().apply {
            color = COR_TEXTO
            textSize = 18f
            isFakeBoldText = true
            isAntiAlias = true
        }
        y += 20f
        tela.drawText("FRILA — Extrato de Remunerações e Repasses", MARGEM, y, pincelTitulo)

        val pincelMeta = Paint().apply {
            color = COR_TEXTO_SECUNDARIO
            textSize = 11f
            isAntiAlias = true
        }
        y += 20f
        tela.drawText("Profissional: $nomeProfissional", MARGEM, y, pincelMeta)
        y += 16f
        val emitidoEm = instanteGeracao.atZone(FUSO_BRASILIA).format(FORMATO_EMISSAO)
        tela.drawText("Emitido em: $emitidoEm", MARGEM, y, pincelMeta)

        return y + 24f
    }

    private fun desenharCaixaResumo(tela: Canvas, yInicial: Float, resumo: ResumoFinanceiroPerfil): Float {
        val alturaCaixa = 90f
        val pincelFundo = Paint().apply { color = COR_CAIXA_RESUMO; isAntiAlias = true }
        tela.drawRoundRect(
            RectF(MARGEM, yInicial, MARGEM + LARGURA_UTIL, yInicial + alturaCaixa),
            8f,
            8f,
            pincelFundo,
        )

        val pincelTexto = Paint().apply { color = COR_TEXTO; textSize = 12f; isAntiAlias = true }
        val pincelNegrito = Paint().apply {
            color = COR_TEXTO
            textSize = 13f
            isFakeBoldText = true
            isAntiAlias = true
        }

        var y = yInicial + 24f
        tela.drawText(
            "Concluído: ${resumo.totalConcluidoFormatado} (${resumo.turnosCumpridosQtd} turnos)",
            MARGEM + 16f,
            y,
            pincelTexto,
        )
        y += 22f
        tela.drawText(
            "Pendente: ${resumo.totalPendenteFormatado} (${resumo.turnosAgendadosQtd} turnos)",
            MARGEM + 16f,
            y,
            pincelTexto,
        )
        y += 24f
        tela.drawText("Total Acumulado: ${resumo.totalGeralFormatado}", MARGEM + 16f, y, pincelNegrito)

        return yInicial + alturaCaixa + 24f
    }

    private fun desenharTabelaTurnos(tela: Canvas, yInicial: Float, turnos: List<TurnoDto>): Float {
        val pincelCabecalho = Paint().apply {
            color = COR_TEXTO
            textSize = 11f
            isFakeBoldText = true
            isAntiAlias = true
        }
        val pincelLinha = Paint().apply { color = COR_TEXTO; textSize = 10f; isAntiAlias = true }
        val pincelFio = Paint().apply { color = Color.LTGRAY; strokeWidth = 1f }

        val colData = MARGEM
        val colFuncao = MARGEM + 100f
        val colEstabelecimento = MARGEM + 190f
        val colStatus = MARGEM + 330f
        val colValor = MARGEM + 410f

        var y = yInicial
        tela.drawText("Data/Horário", colData, y, pincelCabecalho)
        tela.drawText("Função", colFuncao, y, pincelCabecalho)
        tela.drawText("Estabelecimento", colEstabelecimento, y, pincelCabecalho)
        tela.drawText("Status", colStatus, y, pincelCabecalho)
        tela.drawText("Valor Acordado", colValor, y, pincelCabecalho)
        y += 6f
        tela.drawLine(MARGEM, y, MARGEM + LARGURA_UTIL, y, pincelFio)
        y += 16f

        val ordenados = turnos.sortedByDescending { runCatching { Instant.parse(it.vaga.inicioEm) }.getOrNull() }
        for (turno in ordenados) {
            val dataFormatada = runCatching {
                Instant.parse(turno.vaga.inicioEm).atZone(FUSO_BRASILIA).format(FORMATO_LINHA)
            }.getOrDefault(turno.vaga.inicioEm)

            tela.drawText(dataFormatada, colData, y, pincelLinha)
            tela.drawText(turno.vaga.funcao, colFuncao, y, pincelLinha)
            tela.drawText(turno.contraparte.nome, colEstabelecimento, y, pincelLinha)
            tela.drawText(rotuloStatus[turno.estado] ?: (turno.estado ?: "—"), colStatus, y, pincelLinha)
            tela.drawText(Dinheiro(turno.valorAcordadoCentavos).formatado(), colValor, y, pincelLinha)
            y += 18f
        }

        return y + 16f
    }

    private fun desenharRodape(tela: Canvas) {
        val pincelRodape = Paint().apply { color = COR_TEXTO_SECUNDARIO; textSize = 9f; isAntiAlias = true }
        val pincelFio = Paint().apply { color = Color.LTGRAY; strokeWidth = 1f }

        val yFio = ALTURA_PAGINA - MARGEM - 40f
        tela.drawLine(MARGEM, yFio, MARGEM + LARGURA_UTIL, yFio, pincelFio)

        val aviso = "Valores combinados diretamente com os estabelecimentos parceiros. O Frila não realiza " +
            "intermediação, retenção ou custódia de valores financeiros (RN09)."
        tela.drawText(aviso, MARGEM, yFio + 16f, pincelRodape)
        tela.drawText("Página 1", MARGEM, yFio + 30f, pincelRodape)
    }
}
