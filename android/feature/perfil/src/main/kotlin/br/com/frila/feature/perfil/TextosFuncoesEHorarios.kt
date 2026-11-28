package br.com.frila.feature.perfil

/**
 * Textos e mensagens de validação de Funções e Horários (Item #17 da Paridade, Lote B). As três mensagens de validação são as do iOS por extenso
 * (`TextosDoProfissional.swift:317,319,333`, item 303).
 */
object TextosFuncoesEHorarios {
    const val TITULO = "Funções e horários"
    const val ERRO_SEM_PONTO_BASE = "Defina seu ponto base no perfil antes de salvar funções e horários."
    const val ERRO_SEM_FUNCAO = "Selecione ao menos uma função."
    const val ERRO_HORARIOS_IGUAIS = "O horário de início e fim não podem ser iguais."
    const val ERRO_FORMATO_HORA = "Horário inválido. Use o formato HH:mm."
    const val ERRO_DIA_INVALIDO = "Dia da semana inválido."
    const val ERRO_JANELA_DUPLICADA = "Esta faixa de horário já foi adicionada."
    const val ERRO_CARREGAR = "Não foi possível carregar suas informações. Tente novamente."
    const val ERRO_SALVAR = "Não foi possível salvar as alterações. Tente novamente."

    // Erros do servidor: os mesmos textos fixos do iOS (`MensagemDoErroAPI.texto`). O campo do contrato e a mensagem técnica
    // que vêm na recusa nunca vão para a tela.
    const val ERRO_SEM_REDE = "Sem conexão. Tente novamente quando a internet voltar."
    const val ERRO_SESSAO = "Sua sessão expirou. Entre novamente para continuar."
    const val ERRO_SEM_PERMISSAO = "Sua conta não pode realizar esta ação."
    const val ERRO_LIMITE = "Você fez muitas tentativas. Aguarde antes de tentar novamente."
    const val ERRO_GENERICO = "Não foi possível concluir esta ação. Tente novamente."
}
