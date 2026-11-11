package br.com.frila.feature.vagas.candidatos

/** Textos da gestão de candidatos (paridade com `TextosDosCandidatos` de `CandidatosDaVaga.swift`). */
object TextosCandidatosDaVaga {
    const val TITULO = "Candidatos"
    const val ROTULO_VOLTAR = "Voltar"
    const val EXPLICACAO =
        "Você escolhe quem vai trabalhar. A vaga fecha sozinha 24 horas antes do início se ninguém for escolhido."
    const val PRAZO_DE_ESCOLHA = "Escolha até %s, quando a vaga fecha."
    const val PRAZO_PASSOU = "O prazo de escolha desta vaga já passou. O servidor decide se ainda dá para escolher."
    const val VAZIO_TITULO = "Ninguém se candidatou ainda"
    const val VAZIO_MENSAGEM = "Os candidatos aparecem aqui assim que se candidatarem. Puxe para atualizar."
    const val CARREGANDO = "Carregando candidatos…"
    const val TENTAR_NOVAMENTE = "Tentar novamente"
    const val FALHA_TITULO = "Não foi possível carregar"
    const val FALHA = "Não foi possível carregar os candidatos. Tente novamente."
    const val SEM_CONEXAO = "Sem conexão. Os candidatos aparecem quando a internet voltar."
    const val DESATUALIZADA = "Não foi possível atualizar. A lista de candidatos pode estar desatualizada."
    const val ATUALIZANDO = "Atualizando candidatos"
    const val LISTA = "Candidatos da vaga"
    const val FUNCOES = "Funções: %s"
    const val DA_EQUIPE = "Da sua equipe"
    const val SEM_AVALIACOES = "Sem avaliações ainda"
    const val AVALIACOES = "%d de %d avaliações positivas"
    const val COMPARECIMENTO = "%d%% de comparecimento"
    const val FOTO_DE = "Foto de %s"
    const val ESCOLHER = "Escolher"
    const val ESCOLHER_NOME = "Escolher %s"
    const val ESCOLHENDO = "Confirmando…"
    const val PERGUNTA_DA_ESCOLHA = "Confirmar a escolha?"
    const val AVISO_DA_ESCOLHA = "Você vai confirmar %s nesta vaga."
    const val AVISO_DA_ULTIMA_POSICAO =
        "Você vai confirmar %s nesta vaga. É a última posição: os outros candidatos serão avisados de que não foram escolhidos."
    const val CONFIRMAR = "Confirmar"
    const val CANCELAR = "Cancelar"
    const val CONFIRMADO = "Você confirmou %s."
    const val CONFIRMADO_E_VAGA_PREENCHIDA = "Você confirmou %s. Os outros candidatos foram avisados."

    const val POSICAO_JA_PREENCHIDA = "Outra pessoa da sua equipe preencheu a última posição antes. Atualizamos a lista."
    const val CANDIDATURA_INDISPONIVEL =
        "A candidatura de %s não está mais disponível: foi retirada, expirou ou já foi escolhida. Atualizamos a lista."
    const val SELECAO_ENCERRADA = "A seleção desta vaga já fechou. Não dá mais para escolher candidato."
    const val TURNO_SOBREPOSTO = "%s já tem outro turno confirmado no mesmo horário. Escolha outro candidato."
    const val INELEGIVEL = "%s não pode assumir este turno agora. Escolha outro candidato."
    const val VAGA_OCULTA =
        "A Equipe Frila ocultou esta vaga. Você vê os candidatos, mas só pode escolher depois que ela for reexibida."
    const val SEM_PERMISSAO = "Não foi possível escolher este candidato. Atualize a lista e tente de novo."
    const val PERFIL_INCOMPATIVEL = "Esta conta é de profissional. Só contratantes escolhem candidatos."
    const val CONTA_SUSPENSA = "Sua conta está suspensa. Enquanto a suspensão durar, não é possível escolher candidatos."
    const val SESSAO_EXPIRADA = "Sua sessão expirou. Entre de novo."
    const val SEM_REDE_NA_ESCOLHA = "Sem conexão. A escolha não foi enviada. Tente de novo quando a internet voltar."
    const val RESULTADO_INCERTO =
        "Não foi possível confirmar se a escolha de %s foi concluída. Atualizamos a lista; confira em Posições antes de tentar de novo."
    const val GENERICO = "Não foi possível escolher o candidato. Tente novamente."
}
