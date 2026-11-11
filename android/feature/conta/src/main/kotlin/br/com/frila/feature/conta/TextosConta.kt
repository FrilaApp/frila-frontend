package br.com.frila.feature.conta

/** Textos normativos em português brasileiro (paridade com `TextosExclusaoDeConta.swift` e `TextosContaSuspensa.swift`). */
object TextosExclusaoDeConta {
    const val TITULO = "Excluir conta"
    const val ROTULO_VOLTAR = "Voltar"
    const val AVISO = "Atenção: a exclusão da sua conta é permanente e não poderá ser desfeita."
    const val SECAO_O_QUE_ACONTECE = "O que acontece ao excluir sua conta:"
    const val CONSEQUENCIA_ANONIMIZACAO = "Seus dados pessoais cadastrados serão anonimizados definitivamente."
    const val CONSEQUENCIA_TURNOS =
        "Os turnos futuros do profissional são cancelados sem falta. Para contratantes, o cancelamento " +
            "ocorre quando a conta é o único membro do estabelecimento. Turnos em andamento seguem até o fim."
    const val CONSEQUENCIA_PRAZO =
        "O prazo para a exclusão completa das cópias de backup é de até 15 dias (LGPD, art. 18, VI)."
    const val CONFIRMACAO_CHECK =
        "Estou ciente das consequências e confirmo a exclusão definitiva da minha conta"
    const val BOTAO_EXCLUIR = "Excluir minha conta definitivamente"
    const val EXCLUINDO = "Excluindo conta…"
    const val DIALOGO_TITULO = "Excluir conta definitivamente?"
    const val DIALOGO_MENSAGEM =
        "Esta ação é irreversível. Seus dados pessoais serão anonimizados. O cancelamento de turnos " +
            "segue as condições informadas acima."
    const val DIALOGO_CONFIRMAR = "Sim, excluir minha conta"
    const val CANCELAR = "Cancelar"
    const val CONCLUIDA_TITULO = "Conta excluída"
    const val ERRO_ADMIN_UNICO =
        "Você é o único administrador deste estabelecimento. Transfira a administração antes de excluir a conta."
    const val ERRO_SEM_REDE =
        "A conta não foi excluída por falta de conexão. Verifique sua internet e tente novamente."
    const val ERRO_SESSAO = "Sua sessão expirou. Entre de novo."
    const val ERRO_GENERICO = "Não foi possível concluir a exclusão da conta. Tente novamente."

    fun concluidaResumo(turnosCancelados: Int, dadosApagadosAte: String): String =
        "Turnos cancelados: $turnosCancelados. Seus dados serão apagados por completo até $dadosApagadosAte."
}

object TextosContaSuspensa {
    const val TITULO = "Conta suspensa"
    const val SUBTITULO = "Sua conta está temporariamente suspensa."
    const val AVISO_PRINCIPAL = "O acesso aos serviços do Frila está suspenso."
    const val SECAO_MOTIVO = "Informações da suspensão"
    const val MOTIVO_TITULO = "Motivo informado"
    const val DESDE_TITULO = "Suspensa desde"
    const val SECAO_SUPORTE = "Precisa de ajuda?"
    const val PRAZO_SUPORTE = "A Equipe Frila responde por e-mail em até 5 dias úteis."
    const val BOTAO_SUPORTE = "Falar com o suporte"
    const val BOTAO_SAIR = "Sair da conta"
}
