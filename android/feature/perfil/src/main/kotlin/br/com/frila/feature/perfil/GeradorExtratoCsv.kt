package br.com.frila.feature.perfil

import br.com.frila.core.dominio.modelo.Dinheiro
import br.com.frila.core.dominio.regra.instanteDoServidor
import br.com.frila.core.rede.TurnoDto
import java.io.File
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * Geração de extrato de turnos em CSV gerado localmente no dispositivo (Item #32 da Paridade, Lote C).
 * Colunas idênticas às usadas pelo iOS e pela API (/exportar-turnos):
 * `data,funcao,checkin,checkout,valor_acordado,contraparte,verificacao`
 */
object GeradorExtratoCsv {

    private val FUSO_BRASILIA: ZoneId = ZoneId.of("America/Sao_Paulo")
    private val FORMATO_DATA = DateTimeFormatter.ofPattern("yyyy-MM-dd")
    private val FORMATO_HORA = DateTimeFormatter.ofPattern("HH:mm")

    fun gerar(
        diretorioSaida: File,
        turnos: List<TurnoDto>,
        nomeArquivo: String,
    ): File {
        diretorioSaida.mkdirs()
        val arquivo = File(diretorioSaida, nomeArquivo)
        val cabecalho = "data,funcao,checkin,checkout,valor_acordado,contraparte,verificacao"
        val linhas = mutableListOf(cabecalho)

        val ordenados = turnos.sortedByDescending { runCatching { instanteDoServidor(it.vaga.inicioEm) }.getOrNull() }

        for (t in ordenados) {
            val dataFmt = runCatching {
                instanteDoServidor(t.vaga.inicioEm).atZone(FUSO_BRASILIA).format(FORMATO_DATA)
            }.getOrDefault("")

            val checkinFmt = t.checkinEm?.let {
                runCatching { instanteDoServidor(it).atZone(FUSO_BRASILIA).format(FORMATO_HORA) }.getOrDefault("")
            }.orEmpty()

            val checkoutFmt = t.checkoutEm?.let {
                runCatching { instanteDoServidor(it).atZone(FUSO_BRASILIA).format(FORMATO_HORA) }.getOrDefault("")
            }.orEmpty()

            val valorFmt = "\"${Dinheiro(t.valorAcordadoCentavos).formatado()}\""
            val funcaoFmt = escaparCsv(t.vaga.funcao)
            val contraparteFmt = escaparCsv(t.contraparte.nome)
            val verificacaoFmt = escaparCsv(t.verificacao)

            linhas.add("$dataFmt,$funcaoFmt,$checkinFmt,$checkoutFmt,$valorFmt,$contraparteFmt,$verificacaoFmt")
        }

        arquivo.writeText(linhas.joinToString("\n", postfix = "\n"), Charsets.UTF_8)
        return arquivo
    }

    private fun escaparCsv(valor: String): String {
        var texto = valor
        if (texto.startsWith("=") || texto.startsWith("+") || texto.startsWith("-") || texto.startsWith("@")) {
            texto = "'$texto"
        }
        return if (texto.contains(",") || texto.contains("\"") || texto.contains("\n")) {
            "\"${texto.replace("\"", "\"\"")}\""
        } else {
            texto
        }
    }
}
