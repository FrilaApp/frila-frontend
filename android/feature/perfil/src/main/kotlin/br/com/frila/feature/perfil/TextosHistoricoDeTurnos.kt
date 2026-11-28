package br.com.frila.feature.perfil

/**
 * Textos da tela de histórico de turnos e extrato (Item #32 da Paridade, Lote C).
 * Paridade com `TextosHistoricoDeTurnos.swift` do iOS.
 */
object TextosHistoricoDeTurnos {
    const val TITULO = "Histórico de turnos"
    const val EXPLICACAO = "Exporte os turnos de um período com data, função, horários registrados, valor acordado e contraparte. O valor é o combinado entre as partes, e não um pagamento feito pelo Frila. Turno não verificado sai marcado."
    const val PERIODO = "Período"
    const val ESTE_MES = "Este mês"
    const val MES_PASSADO = "Mês passado"
    const val INTERVALO = "Escolher datas"
    const val DE = "De"
    const val ATE = "Até"
    const val PERIODO_INVALIDO = "A data inicial precisa ser igual ou anterior à final, e nenhuma pode estar no futuro."
    const val INTERVALO_MAXIMO_EXCEDIDO = "Escolha um período de até 30 dias para exportar os turnos."
    const val FORMATO = "Formato"
    const val EXPORTAR = "Exportar"
    const val DICA_EXPORTAR = "Gera o arquivo do período e abre o compartilhamento do sistema."
    const val GERANDO = "Gerando o arquivo…"
    const val SEM_TURNOS = "Nenhum turno nesse período. Nenhum arquivo foi gerado."
    const val TENTAR_NOVAMENTE = "Tentar novamente"
    const val ERRO_DESCONHECIDO = "Não foi possível exportar os turnos. Tente novamente."

    // As recusas da API, com os textos do iOS (`MensagemDoErroAPI.texto`). Nunca a mensagem técnica do `ErroDaApi`.
    const val SEM_REDE = "Sem conexão. Tente novamente quando a internet voltar."
    const val SESSAO_EXPIRADA = "Sua sessão expirou. Entre novamente para continuar."
    const val SEM_PERMISSAO = "Sua conta não pode realizar esta ação."
    const val LIMITE_EXCEDIDO = "Você fez muitas tentativas. Aguarde antes de tentar novamente."

    fun resumo(de: String, ate: String): String =
        if (de == ate) "Em $de" else "De $de a $ate"
}
