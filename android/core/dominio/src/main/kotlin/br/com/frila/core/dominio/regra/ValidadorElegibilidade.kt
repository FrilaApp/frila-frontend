package br.com.frila.core.dominio.regra

import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.dominio.modelo.Turno

/**
 * Elegibilidade de um profissional para uma vaga, por distância (RN06) e por
 * não sobreposição de horário com turnos já confirmados (RN21).
 */
object ValidadorElegibilidade {

    /** Distância máxima aceita entre o profissional e o local da vaga, em km (RN06/RN21). */
    const val DISTANCIA_MAXIMA_KM = 15.0

    fun distanciaDentroDoLimite(profissional: Coordenada, vaga: Coordenada): Boolean =
        profissional.distanciaKmAte(vaga) <= DISTANCIA_MAXIMA_KM

    /** `true` se [novoTurno] não sobrepõe nenhum turno já confirmado do profissional (RN21). */
    fun semSobreposicaoDeHorario(turnosConfirmados: List<Turno>, novoTurno: Turno): Boolean =
        turnosConfirmados.none { it.sobrepoeCom(novoTurno) }

    /**
     * Elegibilidade completa: dentro da distância máxima E sem sobreposição com os turnos
     * já confirmados do profissional.
     */
    fun elegivel(
        profissional: Coordenada,
        vaga: Coordenada,
        turnosConfirmados: List<Turno>,
        novoTurno: Turno,
    ): Boolean =
        distanciaDentroDoLimite(profissional, vaga) &&
            semSobreposicaoDeHorario(turnosConfirmados, novoTurno)
}
