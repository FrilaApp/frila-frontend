package br.com.frila.feature.perfil

/** Textos da conferência da foto no aparelho. O aviso é o mesmo do iOS (`TextosFotoDePerfil.bloqueio`); aqui ele só avisa. */
object TextosDaFotoDePerfil {
    const val AVISO_SEM_ROSTO = "Não achei seu rosto. Tente com mais luz e de frente"
    const val ENVIAR_MESMO_ASSIM = "Enviar mesmo assim"
    const val ESCOLHER_OUTRA_FOTO = "Escolher outra foto"
    const val BLOQUEIO_MULTIPLOS_ROSTOS = "Escolha uma foto em que apareça apenas você."
    const val BLOQUEIO_ANALISE_INDISPONIVEL =
        "Não conseguimos conferir a foto neste aparelho agora. Por segurança, ela não foi enviada. Tente outra foto em instantes."

    // Tela da foto de perfil (mesmos textos do iOS, `TextosFotoDePerfil`).
    const val TITULO = "Foto de perfil"
    const val EXPLICACAO =
        "Use uma foto sua, com o rosto visível, sem texto nem dados pessoais. Ela só aparece para quem tem vínculo com você, depois de aprovada."
    const val ESCOLHER_FOTO = "Escolher foto"
    const val TENTAR_OUTRA_FOTO = "Tentar outra foto"
    const val TENTAR_DE_NOVO = "Tentar de novo"
    const val PREPARANDO = "Preparando a foto…"
    const val ENVIANDO = "Conferindo e enviando a foto…"
    const val TITULO_EM_ANALISE = "Foto em análise"
    const val TEXTO_EM_ANALISE = "Estamos conferindo sua foto. Ela só aparece para outras pessoas depois de aprovada."
    const val PEDIR_NOVA_ANALISE = "Pedir nova análise"
    const val TITULO_NAO_PUBLICADA = "Foto não publicada"
    const val TEXTO_NAO_PUBLICADA = "Não conseguimos analisar sua foto agora. Peça uma nova análise ou tente outra foto."
    const val TEXTO_NOVA_ANALISE_JA_PEDIDA = "A nova análise já foi pedida. Se a foto continuar sem aparecer, tente outra foto."
    const val ERRO_EXPURGADA = "O arquivo dessa foto já foi apagado. Envie outra foto."
    const val ERRO_IMAGEM_INVALIDA = "Não conseguimos abrir essa foto. Tente outra."
    const val ERRO_SEM_REDE = "Sem conexão. Verifique sua internet e tente novamente."
    const val ERRO_RECUSADA_PELO_SERVIDOR = "Essa foto não pôde ser enviada. Tente outra foto."
    const val ERRO_RECURSO_DESLIGADO = "Fotos de perfil estão indisponíveis por enquanto. Quando voltarem, você poderá enviar a sua."
    const val ERRO_CONTA_SUSPENSA = "Sua conta está suspensa. Enquanto a suspensão durar, não é possível mudar a foto."
    const val ERRO_INDISPONIVEL_AGORA = "Não foi possível concluir agora. Tente novamente em instantes."

    /** O motivo genérico da recusa (`motivo_recusa`, contrato 0.2.54) em texto de quem ajuda; sem motivo conhecido, o conselho geral do iOS. */
    fun motivoDaRecusa(motivo: String?): String = when (motivo) {
        "foto_inadequada" -> "Use uma foto sua, com o rosto visível."
        "texto_ou_dado_pessoal" -> "Use uma foto sem texto, telefone, Pix, QR code ou documento."
        "nao_e_pessoa_ou_servico" -> "A foto precisa mostrar você. Logos, desenhos e paisagens não servem como foto de perfil."
        "nao_analisada" -> "Não conseguimos analisar agora. Tente de novo."
        else -> "Tente outra foto, com seu rosto visível e sem texto nem dados pessoais."
    }

    fun bloqueio(motivo: MotivoDeBloqueioLocal): String = when (motivo) {
        MotivoDeBloqueioLocal.MULTIPLOS_ROSTOS -> BLOQUEIO_MULTIPLOS_ROSTOS
        MotivoDeBloqueioLocal.ANALISE_INDISPONIVEL -> BLOQUEIO_ANALISE_INDISPONIVEL
    }
}
