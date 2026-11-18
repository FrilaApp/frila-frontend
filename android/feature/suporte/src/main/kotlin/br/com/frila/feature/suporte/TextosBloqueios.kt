package br.com.frila.feature.suporte

/** Textos de "Pessoas e locais bloqueados" (RF26, decisão A8; paridade com `TextosBloqueios.swift`). */
object TextosBloqueios {
    const val TITULO = "Pessoas e locais bloqueados"
    const val ROTULO_VOLTAR = "Voltar"
    const val EXPLICACAO =
        "Pessoas e estabelecimentos que você bloqueou. Ao desbloquear, vocês voltam a se cruzar em vagas, " +
            "notificações e candidaturas."
    const val CARREGANDO = "Carregando os bloqueios…"
    const val VAZIO_TITULO = "Nenhum bloqueio ativo"
    const val VAZIO_MENSAGEM = "Quando você bloquear uma pessoa ou um estabelecimento, eles aparecerão aqui."
    const val DESBLOQUEAR = "Desbloquear"
    const val DESBLOQUEANDO = "Desbloqueando…"
    const val CONFIRMAR_DESBLOQUEIO = "Desbloquear este perfil?"
    const val CANCELAR = "Cancelar"
    const val TENTAR_NOVAMENTE = "Tentar novamente"
    const val TIPO_PROFISSIONAL = "Profissional"
    const val TIPO_ESTABELECIMENTO = "Estabelecimento"

    const val SEM_REDE = "Sem conexão. Verifique sua internet e tente novamente."
    const val CONTA_SUSPENSA = "Sua conta está suspensa. Enquanto a suspensão durar, os bloqueios não mudam."
    const val ERRO_CARREGAR = "Não foi possível carregar os bloqueios. Tente novamente."
    const val ERRO_DESBLOQUEAR = "Não foi possível desfazer o bloqueio. Tente novamente."

    fun efeitoDesbloqueio(nome: String): String =
        "Ao desbloquear $nome, vocês voltam a se cruzar em notificações, listas e candidaturas."

    fun rotuloDesbloquear(nome: String): String = "$DESBLOQUEAR $nome"

    fun rotuloDoTipo(alvoTipo: String): String = if (alvoTipo == "estabelecimento") TIPO_ESTABELECIMENTO else TIPO_PROFISSIONAL
}
