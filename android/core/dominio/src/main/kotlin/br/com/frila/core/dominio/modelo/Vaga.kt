package br.com.frila.core.dominio.modelo

import java.time.LocalDateTime

/**
 * Vaga publicada por um estabelecimento. Entidade imutável do domínio — nenhuma camada de
 * dados ou de apresentação deve construir uma `Vaga` diretamente a partir de JSON.
 */
data class Vaga(
    val id: String,
    val funcao: String,
    val local: Coordenada,
    val valorHora: Dinheiro,
    val inicio: LocalDateTime,
    val fim: LocalDateTime,
    val posicoesTotais: Int,
    val posicoesPreenchidas: Int,
    val estado: EstadoVaga,
) {
    init {
        require(posicoesTotais > 0) { "posicoesTotais deve ser positivo: $posicoesTotais" }
        require(posicoesPreenchidas in 0..posicoesTotais) {
            "posicoesPreenchidas ($posicoesPreenchidas) fora do intervalo [0, $posicoesTotais]"
        }
        require(!fim.isBefore(inicio)) { "fim ($fim) não pode ser anterior a inicio ($inicio)" }
    }

    val possuiPosicoesRestantes: Boolean
        get() = posicoesPreenchidas < posicoesTotais

    /** Sobrepõe outro turno/vaga se os intervalos [inicio, fim) se cruzam. */
    fun sobrepoeComHorario(inicio: LocalDateTime, fim: LocalDateTime): Boolean =
        this.inicio.isBefore(fim) && inicio.isBefore(this.fim)
}
