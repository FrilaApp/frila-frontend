package br.com.frila.core.localizacao

import br.com.frila.core.dominio.modelo.Coordenada

/**
 * Leitura de localização para o check-in presencial (RF13/RN06/RN22). A leitura é sempre sob
 * demanda, no instante do toque — nunca em segundo plano (RN22, minimização LGPD): o app não
 * guarda um histórico de posições, só a coordenada do momento exato do check-in, e só para
 * calcular a distância; a coordenada em si nunca sai do aparelho.
 */
interface ProvedorDeLocalizacao {

    /**
     * Uma leitura para o check-in, com a precisão e a origem. Termina sozinha: devolve `null` sem
     * lançar quando não há permissão ou quando a posição não chega dentro do prazo
     * ([TEMPO_LIMITE_DA_LEITURA_MS], o mesmo do iOS). Quem decide se a precisão serve é o chamador.
     *
     * A implementação padrão existe para dublês de teste: usa [obterCoordenadaAtual] e trata a
     * leitura como exata.
     */
    suspend fun lerParaCheckin(): LeituraDeLocalizacao? =
        obterCoordenadaAtual()?.let { LeituraDeLocalizacao(coordenada = it, precisaoMetros = 0f, simulada = false) }

    /**
     * Lê a coordenada atual. Retorna `null` sem lançar exceção quando não há permissão, o GPS
     * está desativado ou a localização não pôde ser obtida a tempo — o check-in continua
     * possível nesses casos, só que no modo `manual` (RN06).
     */
    suspend fun obterCoordenadaAtual(): Coordenada?

    /** Verdadeiro se ao menos uma das permissões de localização (fina ou aproximada) foi concedida. */
    fun temPermissaoDeLocalizacao(): Boolean

    /**
     * Verdadeiro se o sistema tem ao menos um provedor de localização ativo (GPS ou rede).
     * Independe de permissão: o app pode ter permissão concedida e o usuário ainda assim manter
     * a localização do aparelho desligada (RN22) — tratamento defensivo, nunca lança exceção.
     */
    fun isGpsAtivado(): Boolean
}

/**
 * Leitura de posição do toque do check-in. A coordenada só serve para medir a distância até a vaga
 * e nunca sai do aparelho (RN22).
 */
data class LeituraDeLocalizacao(
    val coordenada: Coordenada,
    /** Raio de erro da leitura, em metros. Sem precisão informada pelo sistema, vem infinito. */
    val precisaoMetros: Float,
    /** A posição veio de app de localização falsa. */
    val simulada: Boolean,
)

/** Prazo de uma leitura para o check-in: 10 s, igual a `RegraDePresenca.tempoLimiteDaLeitura` do iOS. */
const val TEMPO_LIMITE_DA_LEITURA_MS = 10_000L
