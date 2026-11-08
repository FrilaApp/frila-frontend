package br.com.frila.core.dominio.modelo

import java.time.LocalDate
import java.time.Period
import java.time.ZoneId

/** Data de calendário (sem hora), sempre interpretada no fuso de Brasília para regras civis (ex.: RN20). */
data class DataCivil(val data: LocalDate) {

    fun idadeEm(referencia: DataCivil): Int = Period.between(data, referencia.data).years

    operator fun compareTo(outra: DataCivil): Int = data.compareTo(outra.data)

    companion object {
        val FUSO_BRASILIA: ZoneId = ZoneId.of("America/Sao_Paulo")

        fun hoje(): DataCivil = DataCivil(LocalDate.now(FUSO_BRASILIA))

        fun de(ano: Int, mes: Int, dia: Int): DataCivil = DataCivil(LocalDate.of(ano, mes, dia))
    }
}
