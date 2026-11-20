package br.com.frila.feature.perfil

/** Textos e mensagens de validação de Funções e Horários (Item #17 da Paridade, Lote B). */
object TextosFuncoesEHorarios {
    const val ERRO_SEM_PONTO_BASE = "Defina seu ponto base no perfil antes de salvar funções e horários."
    const val ERRO_SEM_FUNCAO = "Escolha ao menos uma função."
    const val ERRO_HORARIO_INVALIDO = "O horário de início deve ser anterior ao de término."
    const val ERRO_FORMATO_HORA = "Informe horários válidos no formato HH:mm."
    const val ERRO_CARREGAR = "Não foi possível carregar suas informações. Tente novamente."
    const val ERRO_SALVAR = "Não foi possível salvar as alterações. Tente novamente."
}
