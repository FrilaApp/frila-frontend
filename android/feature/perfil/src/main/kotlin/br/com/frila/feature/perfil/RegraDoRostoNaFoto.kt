package br.com.frila.feature.perfil

/** Por que a conferência no aparelho não deixou a foto subir (paridade com `MotivoDeBloqueioLocal` do iOS, só a parte do rosto). */
enum class MotivoDeBloqueioLocal { ROSTO_NAO_ENCONTRADO, MULTIPLOS_ROSTOS, ANALISE_INDISPONIVEL }

sealed interface ResultadoDaVerificacaoLocal {
    data object Liberada : ResultadoDaVerificacaoLocal
    data class Bloqueada(val motivo: MotivoDeBloqueioLocal) : ResultadoDaVerificacaoLocal
}

/** Um rosto achado na foto, só o tamanho da caixa em pixels: nada de pontos do rosto (nada biométrico). */
data class RostoDetectado(val largura: Int, val altura: Int)

/** Esqueleto do teste vermelho (L1-3a): sem comportamento. */
object RegraDoRostoNaFoto {
    const val AREA_MINIMA = 0.01
    const val PRAZO_MS = 30_000L

    fun decidir(rostos: List<RostoDetectado>, larguraDaImagem: Int, alturaDaImagem: Int): ResultadoDaVerificacaoLocal =
        ResultadoDaVerificacaoLocal.Liberada

    suspend fun comFalhaFechada(prazoMs: Long = PRAZO_MS, analise: suspend () -> ResultadoDaVerificacaoLocal): ResultadoDaVerificacaoLocal =
        analise()
}
