package br.com.frila.feature.perfil

/** Textos da apresentação e das regiões do profissional (paridade com `TextosApresentacaoERegioes.swift`; tela provisória). */
object TextosApresentacaoERegioes {
    const val TITULO = "Apresentação e regiões"
    const val SOBRE_MIM = "Sobre mim"
    const val SOBRE_MIM_DICA = "Conte há quanto tempo trabalha, onde já trabalhou e no que você é bom."
    const val EXPERIENCIA = "Tempo de experiência"
    const val EXPERIENCIA_DICA = "Selecione a faixa que melhor descreve sua trajetória."
    const val NAO_INFORMADO = "Não informado"
    const val ONDE_TRABALHEI = "Onde já trabalhei"
    const val ONDE_TRABALHEI_DICA =
        "Pode citar tipos de lugar ('buffet de casamento', 'bar no Sudoeste'). Evite nome e telefone de outras pessoas."
    const val CURSOS = "Cursos e certificados"
    const val CURSO_ROTULO = "Curso ou certificado"
    const val ADICIONAR_CURSO = "Adicionar curso"
    const val REMOVER_CURSO = "Remover curso"
    const val IDIOMAS = "Idiomas"
    const val IDIOMAS_DICA = "Selecione os idiomas em que você se comunica."
    const val REGIOES = "Onde atendo"
    const val REGIOES_DICA = "Marque só onde você consegue chegar no horário."
    const val TODO_O_DF = "Atender em todo o DF"
    const val AVISO_PONTO_BASE =
        "A seleção de regiões define onde você quer atender, mas não altera o ponto base do seu cadastro nem o raio de 15 km do despacho de vagas normais."
    const val SALVAR = "Salvar"
    const val SALVANDO = "Salvando…"
    const val CARREGANDO = "Carregando…"
    const val SUCESSO = "Apresentação atualizada com sucesso."
    const val VOLTAR = "Voltar"

    const val ERRO_ANTI_CONTATO =
        "Tire telefone, e-mail, link ou Pix do texto. O Frila não troca contato entre as partes; depois do aceite, o turno mostra endereço e quem recebe."
    const val LIMITE_SOBRE_MIM = "O texto de Sobre mim não pode passar de 600 caracteres."
    const val LIMITE_ONDE_TRABALHEI = "O texto de Onde já trabalhei não pode passar de 400 caracteres."
    const val LIMITE_CURSOS = "Você pode cadastrar no máximo 5 cursos."
    const val CURSO_MUITO_LONGO = "O nome do curso não pode passar de 80 caracteres."
    const val ERRO_REGIOES = "Confira as regiões selecionadas."
    const val ERRO_SEM_REDE = "Sem conexão com a internet. O rascunho continua salvo para tentar novamente."
    const val ERRO_SALVAR = "Não foi possível salvar a apresentação. Verifique sua conexão e tente novamente."
    const val ERRO_CARREGAR = "Não foi possível carregar sua apresentação."

    fun experiencia(faixa: String): String = when (faixa) {
        "menos_de_1_ano" -> "Menos de 1 ano"
        "de_1_a_3_anos" -> "1 a 3 anos"
        "de_3_a_5_anos" -> "3 a 5 anos"
        "de_5_a_10_anos" -> "5 a 10 anos"
        "mais_de_10_anos" -> "Mais de 10 anos"
        else -> faixa
    }

    fun idioma(id: String): String = when (id) {
        "portugues" -> "Português"
        "ingles" -> "Inglês"
        "espanhol" -> "Espanhol"
        "libras" -> "Libras"
        "outro" -> "Outro"
        else -> id
    }
}
