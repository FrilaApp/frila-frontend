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
 *
 * Paginação (achado bloqueante do Shisui, MEDIDO em emulador: acima de ~29 turnos a tabela
 * estourava a página e o rodapé, truncando o extrato em silêncio): [dividirEmPaginas] e
 * [quebrarEmLinhas] são funções puras, sem nenhuma dependência de `android.graphics` — testáveis
 * em JVM comum, diferente do restante desta classe que só funciona com o framework Android real.
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

    // Geometria fixa do layout, em pontos — usada tanto para desenhar quanto para calcular
    // quantas linhas cabem por página (mesma aritmética dos dois lados, nunca duplicada).
    private const val Y_INICIO_CABECALHO_COMPLETO = MARGEM + 20f + 20f + 16f + 24f // título + meta + emitido + respiro
    private const val ALTURA_CAIXA_RESUMO = 90f
    private const val RESPIRO_APOS_CAIXA = 24f
    private const val Y_INICIO_TABELA_PAGINA_1 = Y_INICIO_CABECALHO_COMPLETO + ALTURA_CAIXA_RESUMO + RESPIRO_APOS_CAIXA
    private const val Y_INICIO_CABECALHO_CONTINUACAO = MARGEM + 20f + 16f + 24f // título + "continuação" + respiro
    private const val ALTURA_CABECALHO_TABELA = 22f // linha de títulos de coluna + fio
    private const val ALTURA_LINHA = 18f

    /** Reserva no fim da página para o rodapé: fio + até 3 linhas de aviso + número da página. */
    private const val RESERVA_RODAPE = 80f
    private const val LIMITE_INFERIOR_CONTEUDO = ALTURA_PAGINA - MARGEM - RESERVA_RODAPE

    /** Quantos turnos cabem na tabela da primeira página (depois do cabeçalho e da caixa-resumo). */
    internal val LINHAS_POR_PAGINA_PRIMEIRA: Int =
        ((LIMITE_INFERIOR_CONTEUDO - Y_INICIO_TABELA_PAGINA_1 - ALTURA_CABECALHO_TABELA) / ALTURA_LINHA).toInt()

    /** Quantos turnos cabem nas páginas de continuação (só cabeçalho curto, sem caixa-resumo). */
    internal val LINHAS_POR_PAGINA_CONTINUACAO: Int =
        ((LIMITE_INFERIOR_CONTEUDO - Y_INICIO_CABECALHO_CONTINUACAO - ALTURA_CABECALHO_TABELA) / ALTURA_LINHA).toInt()

    private const val MAX_CARACTERES_POR_LINHA_RODAPE = 90

    /**
     * Fatia [turnos] (já na ordem final de impressão) em páginas: a primeira com
     * [LINHAS_POR_PAGINA_PRIMEIRA] itens (cabeçalho completo + caixa-resumo ocupam espaço), as
     * demais com [LINHAS_POR_PAGINA_CONTINUACAO]. Lista vazia devolve uma página vazia — o
     * extrato sempre tem ao menos a página de cabeçalho/resumo.
     */
    internal fun dividirEmPaginas(turnos: List<TurnoDto>): List<List<TurnoDto>> {
        if (turnos.isEmpty()) return listOf(emptyList())

        val paginas = mutableListOf<List<TurnoDto>>()
        var indice = 0
        var primeiraPagina = true
        while (indice < turnos.size) {
            val tamanho = if (primeiraPagina) LINHAS_POR_PAGINA_PRIMEIRA else LINHAS_POR_PAGINA_CONTINUACAO
            paginas.add(turnos.subList(indice, minOf(indice + tamanho, turnos.size)))
            indice += tamanho
            primeiraPagina = false
        }
        return paginas
    }

    /**
     * Quebra [texto] em linhas de até [maxCaracteres], sem cortar palavras no meio — nenhuma
     * linha do rodapé estoura a largura útil da página (achado bloqueante do Shisui).
     */
    internal fun quebrarEmLinhas(texto: String, maxCaracteres: Int = MAX_CARACTERES_POR_LINHA_RODAPE): List<String> {
        if (texto.isEmpty()) return emptyList()

        val linhas = mutableListOf<String>()
        val linhaAtual = StringBuilder()
        for (palavra in texto.split(" ")) {
            val candidata = if (linhaAtual.isEmpty()) palavra else "${linhaAtual} $palavra"
            if (candidata.length > maxCaracteres && linhaAtual.isNotEmpty()) {
                linhas.add(linhaAtual.toString())
                linhaAtual.clear()
                linhaAtual.append(palavra)
            } else {
                linhaAtual.clear()
                linhaAtual.append(candidata)
            }
        }
        if (linhaAtual.isNotEmpty()) linhas.add(linhaAtual.toString())
        return linhas
    }

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

        val ordenados = turnos.sortedByDescending { runCatching { Instant.parse(it.vaga.inicioEm) }.getOrNull() }
        val paginas = dividirEmPaginas(ordenados)
        val totalPaginas = paginas.size

        val documento = PdfDocument()
        paginas.forEachIndexed { indice, itensDaPagina ->
            val numeroPagina = indice + 1
            val pagina = documento.startPage(
                PdfDocument.PageInfo.Builder(LARGURA_PAGINA, ALTURA_PAGINA, numeroPagina).create(),
            )
            val tela = pagina.canvas

            val yInicioTabela = if (numeroPagina == 1) {
                val y = desenharCabecalho(tela, nomeProfissional, instanteGeracao)
                desenharCaixaResumo(tela, y, resumo)
            } else {
                desenharCabecalhoContinuacao(tela, numeroPagina)
            }
            desenharTabelaTurnos(tela, yInicioTabela, itensDaPagina)
            desenharRodape(tela, numeroPagina, totalPaginas)

            documento.finishPage(pagina)
        }

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

    private fun desenharCabecalhoContinuacao(tela: Canvas, numeroPagina: Int): Float {
        var y = MARGEM

        val pincelFaixa = Paint().apply { color = COR_TERRACOTA }
        tela.drawRect(RectF(0f, 0f, LARGURA_PAGINA.toFloat(), MARGEM / 2), pincelFaixa)

        val pincelTitulo = Paint().apply {
            color = COR_TEXTO
            textSize = 14f
            isFakeBoldText = true
            isAntiAlias = true
        }
        y += 20f
        tela.drawText("FRILA — Extrato de Remunerações (continuação)", MARGEM, y, pincelTitulo)

        val pincelMeta = Paint().apply { color = COR_TEXTO_SECUNDARIO; textSize = 10f; isAntiAlias = true }
        y += 16f
        tela.drawText("Página $numeroPagina", MARGEM, y, pincelMeta)

        return y + 24f
    }

    private fun desenharCaixaResumo(tela: Canvas, yInicial: Float, resumo: ResumoFinanceiroPerfil): Float {
        val pincelFundo = Paint().apply { color = COR_CAIXA_RESUMO; isAntiAlias = true }
        tela.drawRoundRect(
            RectF(MARGEM, yInicial, MARGEM + LARGURA_UTIL, yInicial + ALTURA_CAIXA_RESUMO),
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

        return yInicial + ALTURA_CAIXA_RESUMO + RESPIRO_APOS_CAIXA
    }

    private fun desenharTabelaTurnos(tela: Canvas, yInicial: Float, turnos: List<TurnoDto>) {
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

        for (turno in turnos) {
            val dataFormatada = runCatching {
                Instant.parse(turno.vaga.inicioEm).atZone(FUSO_BRASILIA).format(FORMATO_LINHA)
            }.getOrDefault(turno.vaga.inicioEm)

            tela.drawText(dataFormatada, colData, y, pincelLinha)
            tela.drawText(turno.vaga.funcao, colFuncao, y, pincelLinha)
            tela.drawText(turno.contraparte.nome, colEstabelecimento, y, pincelLinha)
            tela.drawText(rotuloStatus[turno.estado] ?: (turno.estado ?: "—"), colStatus, y, pincelLinha)
            tela.drawText(Dinheiro(turno.valorAcordadoCentavos).formatado(), colValor, y, pincelLinha)
            y += ALTURA_LINHA
        }
    }

    private fun desenharRodape(tela: Canvas, numeroPagina: Int, totalPaginas: Int) {
        val pincelRodape = Paint().apply { color = COR_TEXTO_SECUNDARIO; textSize = 9f; isAntiAlias = true }
        val pincelFio = Paint().apply { color = Color.LTGRAY; strokeWidth = 1f }

        val yFio = ALTURA_PAGINA - MARGEM - RESERVA_RODAPE + 20f
        tela.drawLine(MARGEM, yFio, MARGEM + LARGURA_UTIL, yFio, pincelFio)

        val aviso = "Valores combinados diretamente com os estabelecimentos parceiros. O Frila não realiza " +
            "intermediação, retenção ou custódia de valores financeiros (RN09)."
        var y = yFio + 14f
        for (linha in quebrarEmLinhas(aviso)) {
            tela.drawText(linha, MARGEM, y, pincelRodape)
            y += 12f
        }
        tela.drawText("Página $numeroPagina de $totalPaginas", MARGEM, y, pincelRodape)
    }
}
