package br.com.frila.feature.estabelecimento

/**
 * Tipo do estabelecimento (schema `TipoEstabelecimento`, RF02). `chave` é o valor de fio. O tipo serve
 * para leitura e filtro, nunca para barrar ninguém.
 */
enum class TipoEstabelecimento(val chave: String, val rotulo: String) {
    ALIMENTACAO("food_service", "Alimentação"),
    EVENTO("evento", "Evento"),
    VAREJO("varejo", "Varejo"),
    LOGISTICA("logistica", "Logística"),
    SERVICO_DOMESTICO("servico_domestico", "Serviço doméstico"),
    OUTRO("outro", "Outro"),
}

/**
 * As 35 Regiões Administrativas oficiais do Distrito Federal (mesma lista de
 * `CadastroEstabelecimentoViewModel.regioesAdministrativas`, no iOS; fonte GDF / SEGOV). O contrato
 * pede o texto da região; o cadastro só aceita uma destas.
 */
val REGIOES_ADMINISTRATIVAS_DF: List<String> = listOf(
    "Água Quente", "Águas Claras", "Arapoanga", "Arniqueira", "Brazlândia", "Candangolândia",
    "Ceilândia", "Cruzeiro", "Fercal", "Gama", "Guará", "Itapoã", "Jardim Botânico", "Lago Norte",
    "Lago Sul", "Núcleo Bandeirante", "Paranoá", "Park Way", "Planaltina", "Plano Piloto",
    "Recanto das Emas", "Riacho Fundo", "Riacho Fundo II", "Samambaia", "Santa Maria", "São Sebastião",
    "SCIA / Estrutural", "SIA", "Sobradinho", "Sobradinho II", "Sol Nascente/Pôr do Sol",
    "Sudoeste/Octogonal", "Taguatinga", "Varjão", "Vicente Pires",
)
