package br.com.frila.feature.vagas.feed

/** Status da tela do feed de vagas abertas. */
enum class StatusFeed { CARREGANDO, SUCESSO, VAZIO, ERRO }

/** Filtro de distância máxima do profissional até a vaga (sem relação com o limite de 15km de RN06/RN21 — este é escolhido pelo usuário na busca, não uma regra de elegibilidade). */
enum class FiltroDistancia(val limiteKm: Double?, val rotulo: String) {
    QUALQUER(limiteKm = null, rotulo = "Qualquer"),
    CINCO_KM(limiteKm = 5.0, rotulo = "5 km"),
    DEZ_KM(limiteKm = 10.0, rotulo = "10 km"),
    QUINZE_KM(limiteKm = 15.0, rotulo = "15 km"),
    VINTE_E_CINCO_KM(limiteKm = 25.0, rotulo = "25 km"),
    CINQUENTA_KM(limiteKm = 50.0, rotulo = "50 km"),
}

/** Período do dia calculado pelo horário de início da vaga em Brasília. */
enum class FiltroPeriodo(val rotulo: String) {
    QUALQUER("Qualquer"),
    MANHA("Manhã"),
    TARDE("Tarde"),
    NOITE("Noite"),
}

/** Piso de remuneração escolhido pelo profissional no feed (valor total do turno). */
enum class FiltroRemuneracao(val minimoCentavos: Long?, val rotulo: String) {
    QUALQUER(null, "Qualquer"),
    CEM(10_000L, "R$ 100+"),
    CENTO_E_CINQUENTA(15_000L, "R$ 150+"),
    DUZENTOS(20_000L, "R$ 200+"),
}

/**
 * Faixa de remuneração líquida por hora (RF05/RN01).
 * Representa os limites em R$/h selecionados pelo profissional através do RangeSlider.
 */
data class FaixaRemuneracaoHora(
    val minima: Float = LIMITE_MINIMO,
    val maxima: Float = LIMITE_MAXIMO,
    val ativa: Boolean = false,
) {
    val intervalo: ClosedFloatingPointRange<Float>
        get() = minima..maxima

    companion object {
        const val LIMITE_MINIMO = 20f
        const val LIMITE_MAXIMO = 150f
        val PADRAO = FaixaRemuneracaoHora(minima = 25f, maxima = 100f, ativa = false)
    }
}

/** Item já formatado para exibição no cartão do feed. */
data class ItemVaga(
    val id: String,
    val funcaoNome: String,
    val estabelecimentoNome: String,
    val horarioFormatado: String,
    val valorFormatado: String,
    val distanciaKm: Double,
    val modo: String,
)

/** Estado da tela de feed: vagas já filtradas e ordenadas, prontas para a lista. */
data class EstadoFeed(
    val status: StatusFeed = StatusFeed.CARREGANDO,
    val vagas: List<ItemVaga> = emptyList(),
    val funcoesDisponiveis: List<String> = emptyList(),
    val textoBusca: String = "",
    val filtroDistancia: FiltroDistancia = FiltroDistancia.QUALQUER,
    val filtroFuncao: String? = null,
    val filtroRemuneracao: FiltroRemuneracao = FiltroRemuneracao.QUALQUER,
    val filtroPeriodo: FiltroPeriodo = FiltroPeriodo.QUALQUER,
    val faixaRemuneracaoHora: FaixaRemuneracaoHora = FaixaRemuneracaoHora.PADRAO,
    val exibindoFiltrosAvancados: Boolean = false,
    val mensagemErro: String? = null,
    val atualizando: Boolean = false,
)
