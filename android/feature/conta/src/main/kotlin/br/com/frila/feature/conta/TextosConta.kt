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
    const val TITULO_TURNOS_FUTUROS = "Turnos futuros vinculados à conta"
    const val CARREGANDO_TURNOS = "Verificando turnos futuros…"

    /** Só os turnos como profissional: a consulta da casa (turnos do estabelecimento) é outra etapa. */
    const val SEM_TURNOS_FUTUROS = "Nenhum turno futuro como profissional encontrado na consulta."
    const val LISTA_TURNOS_INDISPONIVEL =
        "A lista de turnos está indisponível ou desatualizada. Você pode continuar com a exclusão."
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

    // Contestação da suspensão (paridade com `TextosContaSuspensa.swift`)
    const val CARREGANDO = "Carregando a situação da conta."
    const val PRAZO_ANALISE = "A Equipe Frila responde contestações em até 5 dias úteis."
    const val SECAO_CONTESTACAO = "Contestação"
    const val BOTAO_CONTESTAR = "Contestar suspensão"
    const val ROTULO_RELATO = "Motivos da contestação"
    const val DICA_RELATO = "Mínimo de 10 caracteres."
    const val BOTAO_ENVIAR = "Enviar contestação"
    const val ENVIANDO = "Enviando contestação…"
    const val CANCELAR = "Cancelar"
    const val EM_ANALISE = "Em análise"
    const val PROTOCOLO_TITULO = "Protocolo de contestação"
    const val PROTOCOLO_NUMERO = "Número do protocolo"
    const val PROTOCOLO_DATA = "Enviado em"
    const val PRAZO_RESPOSTA = "Previsão de resposta até"
    const val MENSAGEM_EM_ANALISE =
        "Sua contestação foi enviada e está em análise pela Equipe Frila. Você receberá uma notificação e resposta por e-mail dentro do prazo informado."
    const val MENSAGEM_APOS_PRAZO = "A resposta da Equipe Frila é enviada por e-mail. Para qualquer recurso adicional, escreva para %s."
    const val CONTESTACAO_JA_EXISTE = "Já existe uma contestação para esta suspensão."
    const val RELATO_MINIMO = "O relato deve conter pelo menos 10 caracteres."
    const val RELATO_OBRIGATORIO = "Informe o motivo da contestação antes de enviar."
    const val CONTA_REATIVADA = "Sua conta foi reativada."
    const val ERRO_SEM_REDE = "Sem conexão. Verifique sua internet e tente novamente."
    const val ERRO_SESSAO = "Sua sessão expirou. Entre de novo."
    const val ERRO_GENERICO = "Não foi possível concluir esta ação. Tente novamente."
}

/** Textos de contestar o despacho (paridade com a parte de contestação de `TextosPorQueReceboVagas.swift`). */
object TextosContestarDespacho {
    const val TITULO = "Algo não bate?"
    const val EXPLICACAO = "Se você acha que deveria ter recebido uma vaga, peça a revisão. A Equipe Frila responde por e-mail em até 5 dias úteis."
    const val ROTULO_RELATO = "O que aconteceu"
    const val DICA_RELATO = "Mínimo de 10 caracteres."
    const val BOTAO_ENVIAR = "Enviar pedido"
    const val ENVIANDO = "Enviando pedido…"
    const val VOLTAR = "Voltar"
    const val PEDIDO_ENVIADO = "Pedido de revisão enviado"
    const val PROTOCOLO_NUMERO = "Número do protocolo"
    const val PROTOCOLO_DATA = "Enviado em"
    const val PRAZO_RESPOSTA = "Previsão de resposta até"
    const val MENSAGEM_ENVIADO = "A Equipe Frila vai responder por e-mail dentro do prazo informado."
    const val CONTESTACAO_JA_ABERTA =
        "Já existe uma contestação deste despacho. A resposta da Equipe Frila vai por e-mail. Qualquer recurso adicional deve ser enviado por e-mail."
    const val RELATO_OBRIGATORIO = "Conte o que aconteceu antes de enviar."
    const val RELATO_MINIMO = "O relato deve conter pelo menos 10 caracteres."
    const val CONTA_SUSPENSA = "Sua conta está suspensa. Enquanto a suspensão durar, não é possível pedir a revisão."
    const val LIMITE_EXCEDIDO = "Muitos pedidos em pouco tempo. Aguarde antes de tentar novamente."
    const val ERRO_SEM_REDE = "Sem conexão. Verifique sua internet e tente novamente."
    const val ERRO_SESSAO = "Sua sessão expirou. Entre de novo."
    const val ERRO_ENVIAR = "Não foi possível enviar o pedido. Tente novamente."
}
