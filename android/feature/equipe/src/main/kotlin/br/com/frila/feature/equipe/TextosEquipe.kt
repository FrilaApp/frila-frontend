package br.com.frila.feature.equipe

/** Textos da equipe de confiança (RF18, UC11; paridade com `TextosEquipeDeConfianca.swift`). */
object TextosEquipe {
    const val TITULO = "Equipe de confiança"
    const val ROTULO_VOLTAR = "Voltar"
    const val EXPLICACAO =
        "Quem está na equipe recebe as vagas desta casa mesmo além de 15 km, desde que tenha a função " +
            "e esteja disponível. Não há exclusividade nem ordem de preferência."
    const val VAZIO_TITULO = "Ninguém na equipe ainda"
    const val VAZIO_MENSAGEM = "Inclua um profissional a partir de um turno que ele já cumpriu aqui."
    const val CARREGANDO = "Carregando a equipe…"
    const val REMOVER = "Remover"
    const val REMOVENDO = "Removendo…"
    const val CONFIRMAR_REMOCAO = "Remover da equipe?"
    const val CONFIRMAR_REMOVER = "Sim, remover"
    const val CANCELAR = "Cancelar"
    const val REMOVIDO = "Removido da equipe."
    const val SAIU = "Você saiu da equipe de confiança."
    const val TENTAR_NOVAMENTE = "Tentar novamente"
    const val SEM_AVALIACOES = "Sem avaliações ainda"

    const val SEM_TURNO_CUMPRIDO =
        "Só dá para incluir quem já cumpriu um turno com presença verificada nesta casa."
    const val SO_ADMINISTRADOR = "Só o administrador do estabelecimento altera a equipe."
    const val CONTA_SUSPENSA = "Sua conta está suspensa. Enquanto a suspensão durar, a equipe não muda."
    const val INDISPONIVEL = "Este perfil não está mais disponível."
    const val SEM_REDE = "Sem conexão. Verifique sua internet e tente novamente."
    const val ERRO_CARREGAR = "Não foi possível carregar a equipe. Tente novamente."
    const val ERRO = "Não foi possível concluir esta ação. Tente novamente."
    const val NAO_ESTA_NA_EQUIPE = "Você não faz parte da equipe desta casa."
    const val SO_PROFISSIONAL = "Só profissionais saem da equipe de confiança."

    fun efeitoRemocao(nome: String): String =
        "$nome deixa de receber as vagas desta casa além de 15 km. Sem penalidade nem aviso."

    fun rotuloRemover(nome: String): String = "$REMOVER $nome"

    fun reputacao(positivas: Int, total: Int): String =
        if (total <= 0) SEM_AVALIACOES else "$positivas de $total avaliações positivas"
}
