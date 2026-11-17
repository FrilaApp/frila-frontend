package br.com.frila.feature.perfil

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.withTimeoutOrNull

/** Por que a conferência no aparelho não deixou a foto subir (paridade com `MotivoDeBloqueioLocal` do iOS, só a parte do rosto). */
enum class MotivoDeBloqueioLocal { ROSTO_NAO_ENCONTRADO, MULTIPLOS_ROSTOS, ANALISE_INDISPONIVEL }

sealed interface ResultadoDaVerificacaoLocal {
    data object Liberada : ResultadoDaVerificacaoLocal
    data class Bloqueada(val motivo: MotivoDeBloqueioLocal) : ResultadoDaVerificacaoLocal
}

/** Um rosto achado na foto, só o tamanho da caixa em pixels: nada de pontos do rosto (nada biométrico). */
data class RostoDetectado(val largura: Int, val altura: Int)

/**
 * O que o aparelho exige da foto do profissional antes de ela subir (CD-M06, camada 1; paridade com `VerificadorLocalDeFotoDoSistema` do iOS,
 * só a parte do rosto): **exatamente um** rosto, com a caixa em pelo menos 1% da área da foto. A análise falha fechada: erro ou prazo
 * estourado bloqueiam como [MotivoDeBloqueioLocal.ANALISE_INDISPONIVEL], nunca liberam. Nenhum pedido de pontos do rosto, só a caixa.
 */
object RegraDoRostoNaFoto {
    /** Área mínima da caixa do rosto em relação à foto (evita rosto minúsculo de fundo), como o iOS. */
    const val AREA_MINIMA = 0.01

    /** Prazo total da análise, com folga para aparelho lento sem travar a tela (30 s, como o iOS). */
    const val PRAZO_MS = 30_000L

    fun decidir(rostos: List<RostoDetectado>, larguraDaImagem: Int, alturaDaImagem: Int): ResultadoDaVerificacaoLocal {
        if (rostos.isEmpty()) return ResultadoDaVerificacaoLocal.Bloqueada(MotivoDeBloqueioLocal.ROSTO_NAO_ENCONTRADO)
        if (rostos.size > 1) return ResultadoDaVerificacaoLocal.Bloqueada(MotivoDeBloqueioLocal.MULTIPLOS_ROSTOS)
        val areaDaFoto = larguraDaImagem.toLong() * alturaDaImagem
        val rosto = rostos.single()
        // Inteiros, para o limite de 1% ser exato (0,01 não é exato em ponto flutuante).
        val grandeOBastante = areaDaFoto > 0 && rosto.largura.toLong() * rosto.altura * 100 >= areaDaFoto
        return if (grandeOBastante) {
            ResultadoDaVerificacaoLocal.Liberada
        } else {
            ResultadoDaVerificacaoLocal.Bloqueada(MotivoDeBloqueioLocal.ROSTO_NAO_ENCONTRADO)
        }
    }

    /**
     * Roda [analise] com prazo. Falha fechada: prazo estourado ou qualquer erro viram [MotivoDeBloqueioLocal.ANALISE_INDISPONIVEL]; só o
     * cancelamento de quem chamou (a tela fechou) propaga. Só o tipo do erro importa: nada da foto vai a log.
     */
    suspend fun comFalhaFechada(prazoMs: Long = PRAZO_MS, analise: suspend () -> ResultadoDaVerificacaoLocal): ResultadoDaVerificacaoLocal =
        try {
            withTimeoutOrNull(prazoMs) { analise() }
                ?: ResultadoDaVerificacaoLocal.Bloqueada(MotivoDeBloqueioLocal.ANALISE_INDISPONIVEL)
        } catch (erro: CancellationException) {
            throw erro
        } catch (erro: Exception) {
            ResultadoDaVerificacaoLocal.Bloqueada(MotivoDeBloqueioLocal.ANALISE_INDISPONIVEL)
        }
}
