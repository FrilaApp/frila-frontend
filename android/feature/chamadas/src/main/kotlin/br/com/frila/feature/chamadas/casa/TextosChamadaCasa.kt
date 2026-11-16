package br.com.frila.feature.chamadas.casa

/**
 * Textos do lado da casa na chamada direta: perfil público, chamar, acompanhar e busca. Copiados do
 * `Localizable.xcstrings` do iOS (`TextosChamadaDireta.swift`, `TextosDaSeguranca.swift`,
 * `TextosApresentacaoERegioes.swift`), o desenho que o Fabrício já aprovou. O Android do repositório guarda
 * os textos em objetos Kotlin, como `TextosEquipe`; não há `strings.xml`.
 *
 * Os da busca vêm do iOS com o mesmo aviso: provisórios, até o Fabrício entregar a tela.
 */
object TextosChamadaCasa {
    // --- Chamar -----------------------------------------------------------------------------------
    const val CHAMAR_DE_NOVO = "Chamar de novo"
    const val TITULO_DA_FOLHA = "Chamar profissional"
    const val ENVIAR = "Enviar chamada"
    const val FECHAR = "Fechar"
    const val VOLTAR = "Voltar"
    const val CANCELAR = "Cancelar"
    const val TENTAR_NOVAMENTE = "Tentar novamente"
    const val CARREGANDO = "Carregando…"
    const val FUNCAO = "Função"
    const val LOCAL = "Local"
    const val INICIO = "Início"
    const val TERMINO = "Término"
    const val RESPONSAVEL = "Responsável no local"
    const val VALOR_TOTAL = "Valor total"
    const val MOEDA = "R$"
    const val VALOR_EXEMPLO = "0,00"
    const val INCLUI_REFEICAO = "Inclui refeição"
    const val INCLUI_TRANSPORTE = "Inclui transporte"
    const val EXIGE_MATERIAL_PROPRIO = "Exige material próprio"
    const val CONFIRMAR_TOTAL =
        "Confirmo que este é o valor total fechado que o profissional recebe pelo trabalho."
    const val RECADO = "Recado opcional (até 300 caracteres)"
    const val RECADO_LONGO = "O recado deve ter até 300 caracteres."

    const val FALTA_VALOR = "Para enviar, informe o valor total."
    const val FALTA_CONFIRMAR_TOTAL = "Para enviar, confirme que este é o valor total."
    const val FALTA_RESPONSAVEL = "Para enviar, informe o responsável no local."
    const val FALTA_ANTECEDENCIA = "Para enviar, o início precisa ser daqui a 2 horas ou mais."
    const val FALTA_DURACAO = "Para enviar, o turno precisa ter de 2 a 16 horas."

    const val SUCESSO = "Chamada enviada. Aguarde a resposta do profissional."
    const val RESUMO_DA_CHAMADA = "Resumo da chamada"
    const val HORARIO = "Horário"

    fun prazoDeResposta(quando: String) = "O profissional tem até $quando para responder."
    fun intervalo(inicio: String, fim: String) = "$inicio até $fim"

    const val J7_TITULO = "Confirme antes de chamar novamente"
    const val J7_MENSAGEM =
        "Esta é a terceira chamada à mesma pessoa em sete dias por uma casa de pessoa física. A contratação " +
            "frequente pode caracterizar vínculo de emprego. O Frila não substitui as obrigações trabalhistas. " +
            "Confirme que leu este aviso para continuar."
    const val J7_CONFIRMAR = "Li o aviso e confirmo a chamada"

    const val JA_ABERTA = "Você já tem uma chamada aberta para este profissional."
    const val INDISPONIVEL = "Este profissional não está disponível para esta chamada."
    const val LIMITE = "Você atingiu o limite de chamadas. Aguarde antes de tentar novamente."
    const val DESLIGADO = "A chamada direta está indisponível no momento."
    const val ERRO = "Não foi possível concluir a chamada. Verifique sua conexão e tente novamente."

    // --- Acompanhar -------------------------------------------------------------------------------
    const val ACOMPANHAR_TITULO = "Acompanhar chamadas"
    const val CHAMADAS_ENVIADAS = "Chamadas enviadas"
    const val NENHUMA_CHAMADA = "Nenhuma chamada encontrada para esta vaga."
    const val CANCELAR_CHAMADA = "Cancelar chamada"
    const val CONFIRMAR_CANCELAMENTO_TITULO = "Cancelar chamada"
    const val CONFIRMAR_CANCELAMENTO =
        "Deseja cancelar esta chamada? O profissional não poderá mais aceitá-la."
    const val CONFIRMAR_CANCELAMENTO_BOTAO = "Confirmar cancelamento"
    const val CHAMADA_JA_RESPONDIDA = "A chamada já foi respondida ou não pode mais ser cancelada."
    const val CHAMADA_CANCELADA_SUCESSO = "Chamada cancelada com sucesso."
    const val PUBLICAR_PARA_TODOS = "Publicar para todos"
    const val PUBLICAR_PARA_TODOS_EXPLICACAO =
        "As chamadas diretas foram finalizadas sem confirmação. Você pode abrir a vaga para todos os " +
            "profissionais da região."
    const val VAGA_PUBLICADA_SUCESSO = "Vaga aberta para todos os profissionais da região."
    const val VER_VAGA_ABERTA = "Ver vaga aberta"
    const val MOTIVO_ROTULO = "Motivo"

    const val STATUS_ABERTA = "Aguardando resposta"
    const val STATUS_ACEITA = "Aceita"
    const val STATUS_RECUSADA = "Recusada"
    const val STATUS_EXPIRADA = "Expirada"
    const val STATUS_CANCELADA = "Cancelada"
    const val STATUS_ENCERRADA = "Encerrada"

    const val MOTIVO_AGENDA = "Conflito de agenda"
    const val MOTIVO_DISTANCIA = "Distância ou transporte"
    const val MOTIVO_VALOR = "Valor proposto"
    const val MOTIVO_TIPO_DE_SERVICO = "Tipo de serviço"
    const val MOTIVO_OUTRO = "Outro motivo"

    // --- Perfil público ---------------------------------------------------------------------------
    const val PERFIL_TITULO = "Perfil público"
    const val PERFIL_INDISPONIVEL = "Perfil indisponível"
    const val SEM_REDE = "Sem conexão. Verifique sua internet e tente novamente."
    const val ERRO_GENERICO = "Não foi possível concluir esta ação. Tente novamente."
    const val SERVICOS_OFERECIDOS = "Serviços oferecidos"
    const val SOBRE_MIM = "Sobre mim"
    const val EXPERIENCIA = "Tempo de experiência"
    const val CURSOS = "Cursos e certificados"
    const val IDIOMAS = "Idiomas"
    const val ONDE_ATENDO = "Onde atendo"
    const val TODO_O_DF = "Atender em todo o DF"
    const val SEM_HISTORICO = "Sem histórico"
    const val AINDA_SEM_TURNOS = "Ainda não há turnos considerados."

    fun reputacao(positivas: Int, total: Int) =
        if (total <= 0) SEM_HISTORICO else "$positivas de $total chamariam de novo"

    fun comparecimento(realizados: Int, considerados: Int): String? = when {
        considerados <= 0 -> null
        considerados == 1 -> "Compareceu a $realizados de $considerados turno"
        else -> "Compareceu a $realizados de $considerados turnos"
    }

    fun experiencia(faixa: String): String = when (faixa) {
        "menos_de_1_ano" -> "Menos de 1 ano"
        "de_1_a_3_anos" -> "1 a 3 anos"
        "de_3_a_5_anos" -> "3 a 5 anos"
        "de_5_a_10_anos" -> "5 a 10 anos"
        "mais_de_10_anos" -> "Mais de 10 anos"
        else -> faixa
    }

    fun idioma(idioma: String): String = when (idioma) {
        "portugues" -> "Português"
        "ingles" -> "Inglês"
        "espanhol" -> "Espanhol"
        "libras" -> "Libras"
        "outro" -> "Outro"
        else -> idioma
    }

    fun unidadeDoServico(unidade: String): String = when (unidade) {
        "hora" -> "Hora"
        "diaria" -> "Diária"
        "evento" -> "Evento"
        "pacote" -> "Pacote"
        "por_pessoa" -> "Por pessoa"
        "a_combinar" -> "A combinar"
        else -> unidade
    }

    // --- Busca (provisórios: TODO texto do Fabrício, como no iOS) -------------------------------------
    const val BUSCA_LIMITE_DE_BUSCAS = "Você fez muitas buscas em pouco tempo. Aguarde um pouco e tente de novo."
    const val BUSCA_INDISPONIVEL = "A busca de profissionais está indisponível no momento."
    const val BUSCA_ERRO = "Não foi possível buscar agora. Verifique sua conexão e tente novamente."
    const val BUSCA_ERRO_AO_CARREGAR_MAIS = "Não foi possível carregar mais profissionais. Tente novamente."
    const val BUSCA_LIMITE_DE_SELECAO = "Você pode chamar até 3 profissionais de uma vez."
    const val BUSCA_HORARIO_INVALIDO = "O término precisa ser depois do início."
    const val BUSCA_TITULO = "Encontrar profissional"
    const val BUSCA_FUNCAO = "Serviço"
    const val BUSCA_ESCOLHA_FUNCAO = "Escolha o serviço"
    const val BUSCA_REGIAO = "Região (opcional)"
    const val BUSCA_QUALQUER_REGIAO = "Qualquer região"
    const val BUSCA_FILTRAR_HORARIO = "Filtrar por horário"
    const val BUSCA_INICIO = "Início (dd/mm/aaaa hh:mm)"
    const val BUSCA_TERMINO = "Término (dd/mm/aaaa hh:mm)"
    const val BUSCA_DATA_INVALIDA = "Use o formato dd/mm/aaaa hh:mm."
    const val BUSCA_BUSCAR = "Buscar"
    const val BUSCA_VAZIO = "Nenhum profissional encontrado com esses filtros."
    const val BUSCA_DISPONIVEL = "Disponível nesse horário"
    const val BUSCA_CARREGAR_MAIS = "Carregar mais"
    const val BUSCA_CATALOGO_ERRO = "Não foi possível carregar os filtros. Verifique sua conexão e tente novamente."
    const val BUSCA_SEM_CASA = "Não foi possível carregar os dados da casa para chamar."
    const val BUSCA_FOLHA_TITULO = "Chamar selecionados"
    const val BUSCA_FOLHA_ENVIAR = "Enviar chamadas"
    const val BUSCA_RESULTADO_ENVIADA = "Chamada enviada"
    const val BUSCA_RESULTADO_J7 = "Aguardando a sua confirmação do aviso"

    fun buscaChamar(quantos: Int) = "Chamar ($quantos)"
    fun buscaSelecionados(quantos: Int) = if (quantos == 1) "1 selecionado de 3" else "$quantos selecionados de 3"
}
