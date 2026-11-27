package br.com.frila.feature.turnos

/** Esqueleto: sem comportamento. */
class QuemRecebeDasVagas(private val ler: suspend (vagaId: String) -> String?) {
    class Lido(val valor: String?)

    fun noCache(vagaId: String): Lido? = null

    suspend fun de(vagaId: String): Lido? = null

    fun limpar() {}
}
