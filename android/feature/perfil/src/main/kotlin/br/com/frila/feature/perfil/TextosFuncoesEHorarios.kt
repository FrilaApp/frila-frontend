package br.com.frila.feature.perfil

/** Textos e mensagens de validação de Funções e Horários (Item #17 da Paridade, Lote B). */
object TextosFuncoesEHorarios {
    const val TITULO = "Funções e horários"
    const val ERRO_SEM_PONTO_BASE = "Defina seu ponto base no perfil antes de salvar funções e horários."
    const val ERRO_SEM_FUNCAO = "Escolha ao menos uma função."
    const val ERRO_HORARIOS_IGUAIS = "O horário de início e término não podem ser iguais."
    const val ERRO_FORMATO_HORA = "Informe horários válidos no formato HH:mm."
    const val ERRO_DIA_INVALIDO = "Dia da semana inválido."
    const val ERRO_JANELA_DUPLICADA = "Esta faixa de horário já foi adicionada."
    const val ERRO_CARREGAR = "Não foi possível carregar suas informações. Tente novamente."
    const val ERRO_SALVAR = "Não foi possível salvar as alterações. Tente novamente."
}
