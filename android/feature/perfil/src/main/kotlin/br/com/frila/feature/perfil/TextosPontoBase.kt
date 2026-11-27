package br.com.frila.feature.perfil

/** Textos do ponto base. Os que o iOS já tem (`TextosDoProfissional.Perfil`) vêm iguais. */
object TextosPontoBase {
    const val TITULO = "Ponto base"
    const val DICA = "Para calcular a distância até as vagas. Não é sua localização em tempo real."
    const val ESCOLHA_A_REGIAO = "Escolha a região onde você fica"
    const val PONTO_BASE_SALVO = "Ponto base salvo"

    /** Igual a `TextosDeCobertura.profissional` do iOS (`AvisoForaDoDF.swift`, decisão A6 da PO). */
    const val AVISO_FORA_DO_DF =
        "Este endereço fica fora do Distrito Federal. Você pode salvar, mas por enquanto o foco e a cobertura do Frila são só do Distrito Federal."
    const val FUNCOES = "Funções"
    const val FUNCOES_DICA = "Selecione ao menos uma função para criar o seu perfil."
    const val SALVAR = "Salvar"
    const val SALVANDO = "Salvando…"
    const val CARREGANDO = "Carregando…"
    const val VOLTAR = "Voltar"

    // Busca na lista de regiões (a T1c do desenho: o campo de busca e o "sem resultado", sem botão).
    const val BUSCAR_REGIAO = "Buscar região"
    const val SEM_RESULTADO_DICA = "Tente outra busca."

    fun semResultado(termo: String) = "Nenhuma região com “$termo”."

    const val ERRO_SEM_PONTO_BASE = "Informe o ponto base."
    const val ERRO_SEM_FUNCAO = "Selecione ao menos uma função."
    const val ERRO_SALVAR = "Não foi possível salvar o perfil."
    const val ERRO_CARREGAR = "Não foi possível carregar o seu perfil."
    const val ERRO_SEM_REDE = "Sem conexão. Verifique sua internet e tente de novo."
}
