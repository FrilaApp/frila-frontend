package br.com.frila.core.designsystem.abertura

import kotlin.math.max

/**
 * DURAÇÃO DA ABERTURA, em segundos: a única linha que muda o tempo total. O encaixe, a saída e todos os quadros-chave
 * derivam dela por proporção ([RoteiroDaAbertura.completo]); o valor é o que o Fabrício deixou no protótipo (o
 * roteiro dele mede 2,82 s) e o mesmo do iOS. Trocar para 1,5 s é mudar este número.
 */
const val duracaoDaAbertura: Double = 2.8

/** Duração da abertura com "reduzir movimento": o rótulo aparece parado e some num esmaecimento. */
internal const val DURACAO_REDUZIDA = 0.9

/**
 * Os marcos de tempo da abertura, em segundos desde o primeiro quadro desenhado.
 *
 * - [encaixe]: o instante do aperto de mão (nulo com movimento reduzido, que não tem aperto);
 * - [saida]: quando o pingo vira a janela e o app começa a assentar;
 * - [duracao]: quando a abertura sai da tela.
 *
 * O roteiro completo é o do protótipo (encaixe em 1,11 s, saída em 2,40 s, fim em 2,82 s) esticado ou encolhido pela
 * proporção entre a duração pedida e os 2,82 s dele: [escala].
 */
internal class RoteiroDaAbertura(
    val encaixe: Double?,
    val saida: Double,
    val duracao: Double,
    /** Quanto o tempo do roteiro do protótipo foi esticado (maior que 1) ou encolhido (menor que 1). */
    val escala: Double,
    val reduzido: Boolean,
) {
    /** Instante do roteiro do protótipo, em segundos de referência, que corresponde ao instante `t` desta abertura. */
    fun tempoDeReferencia(t: Double): Double = t / escala

    /** Com movimento reduzido, nada se desloca: o rótulo fica parado e some num esmaecimento. */
    fun opacidadeReduzida(t: Double): Double {
        if (!reduzido || t <= saida) return 1.0
        return max(0.0, 1.0 - (t - saida) / (duracao - saida))
    }

    companion object {
        private const val ENCAIXE_DE_REFERENCIA = 1.11
        private const val SAIDA_DE_REFERENCIA = 2.40
        private const val SAIDA_REDUZIDA = 0.6

        /** O roteiro cheio para uma duração total qualquer: tudo escala junto. */
        fun completo(duracao: Double = duracaoDaAbertura): RoteiroDaAbertura {
            require(duracao > 0) { "A duração da abertura precisa ser positiva." }
            val escala = duracao / CoreografiaDaAbertura.DURACAO_DE_REFERENCIA
            return RoteiroDaAbertura(
                encaixe = ENCAIXE_DE_REFERENCIA * escala,
                saida = SAIDA_DE_REFERENCIA * escala,
                duracao = duracao,
                escala = escala,
                reduzido = false,
            )
        }

        /**
         * O roteiro de "reduzir movimento": 0,9 s com a saída em 0,6 s, sem aperto e sem o app crescer. Nunca passa da
         * duração cheia pedida, para uma abertura curta não ficar mais longa com o movimento reduzido.
         */
        fun reduzido(duracaoCheia: Double = duracaoDaAbertura): RoteiroDaAbertura {
            val total = minOf(DURACAO_REDUZIDA, duracaoCheia)
            return RoteiroDaAbertura(
                encaixe = null,
                saida = SAIDA_REDUZIDA * total / DURACAO_REDUZIDA,
                duracao = total,
                escala = 1.0,
                reduzido = true,
            )
        }

        fun para(reduzirMovimento: Boolean, duracao: Double = duracaoDaAbertura): RoteiroDaAbertura =
            if (reduzirMovimento) reduzido(duracao) else completo(duracao)
    }
}
