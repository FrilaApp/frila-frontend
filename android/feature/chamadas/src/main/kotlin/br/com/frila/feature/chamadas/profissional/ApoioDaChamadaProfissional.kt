package br.com.frila.feature.chamadas.profissional

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.Dinheiro
import br.com.frila.core.rede.ErroDaApi
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import java.util.Locale

/** `403 sem_permissao` com `details: recurso_desligado` (RN46): o servidor desligou o recurso. */
internal val ErroDaApi.recursoDesligado: Boolean
    get() = codigo == CodigoErroAPI.SEM_PERMISSAO && detalhesComoCodigo == CodigoErroAPI.RECURSO_DESLIGADO

internal val ErroDaApi.contaSuspensa: Boolean
    get() = codigo == CodigoErroAPI.CONTA_SUSPENSA ||
        (codigo == CodigoErroAPI.SEM_PERMISSAO && detalhes == "conta_suspensa")

/** Formatos do Frila (pt-BR, fuso de Brasília), os mesmos do `FormatadorFrila` do iOS. */
internal object FormatoChamada {
    val fuso: ZoneId = ZoneId.of("America/Sao_Paulo")
    private val local = Locale("pt", "BR")
    private val hora = DateTimeFormatter.ofPattern("HH:mm", local).withZone(fuso)
    private val dataEHora = DateTimeFormatter.ofPattern("dd/MM/yyyy 'às' HH:mm", local).withZone(fuso)
    private val data = DateTimeFormatter.ofPattern("dd/MM/yyyy", local)

    /** Instante ISO 8601 do servidor; `null` se o texto não é uma data válida (a tela nunca quebra por isso). */
    fun instante(texto: String): Instant? = try {
        java.time.OffsetDateTime.parse(texto).toInstant()
    } catch (_: DateTimeParseException) {
        null
    }

    fun hora(texto: String): String = instante(texto)?.let(hora::format).orEmpty()

    fun dataEHora(texto: String): String = instante(texto)?.let(dataEHora::format).orEmpty()

    fun data(dia: LocalDate): String = data.format(dia)

    /** "R$ 1.234,56" a partir de centavos, o mesmo texto de [Dinheiro.formatado]. */
    fun dinheiro(centavos: Long): String = Dinheiro(centavos).formatado()
}
