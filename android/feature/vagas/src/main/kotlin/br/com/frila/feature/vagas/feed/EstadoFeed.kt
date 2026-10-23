package br.com.frila.feature.vagas.feed

/** Status da tela do feed de vagas abertas. */
enum class StatusFeed { CARREGANDO, SUCESSO, VAZIO, ERRO }

/** Filtro de distância máxima do profissional até a vaga (sem relação com o limite de 15km de RN06/RN21 — este é escolhido pelo usuário na busca, não uma regra de elegibilidade). */
enum class FiltroDistancia(val limiteKm: Double?, val rotulo: String) {
    QUALQUER(limiteKm = null, rotulo = "Qualquer"),
    CINCO_KM(limiteKm = 5.0, rotulo = "5 km"),
    DEZ_KM(limiteKm = 10.0, rotulo = "10 km"),
    QUINZE_KM(limiteKm = 15.0, rotulo = "15 km"),
}

/** Período do dia calculado pelo horário de início da vaga em Brasília. */
enum class FiltroPeriodo(val rotulo: String) {
    QUALQUER("Qualquer"),
    MANHA("Manhã"),
    TARDE("Tarde"),
    NOITE("Noite"),
}

/** Piso de remuneração escolhido pelo profissional no feed. */
enum class FiltroRemuneracao(val minimoCentavos: Long?, val rotulo: String) {
    QUALQUER(null, "Qualquer"),
    CEM(10_000L, "R$ 100+"),
    CENTO_E_CINQUENTA(15_000L, "R$ 150+"),
    DUZENTOS(20_000L, "R$ 200+"),
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
    val filtroDistancia: FiltroDistancia = FiltroDistancia.QUALQUER,
    val filtroFuncao: String? = null,
    val filtroRemuneracao: FiltroRemuneracao = FiltroRemuneracao.QUALQUER,
    val filtroPeriodo: FiltroPeriodo = FiltroPeriodo.QUALQUER,
    val exibindoFiltrosAvancados: Boolean = false,
    val mensagemErro: String? = null,
)
