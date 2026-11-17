package br.com.frila.feature.perfil

/** Textos da conferência da foto no aparelho. O aviso é o mesmo do iOS (`TextosFotoDePerfil.bloqueio`); aqui ele só avisa. */
object TextosDaFotoDePerfil {
    const val AVISO_SEM_ROSTO = "Não achei seu rosto. Tente com mais luz e de frente"
    const val ENVIAR_MESMO_ASSIM = "Enviar mesmo assim"
    const val ESCOLHER_OUTRA_FOTO = "Escolher outra foto"
    const val BLOQUEIO_MULTIPLOS_ROSTOS = "Escolha uma foto em que apareça apenas você."
    const val BLOQUEIO_ANALISE_INDISPONIVEL =
        "Não conseguimos conferir a foto neste aparelho agora. Por segurança, ela não foi enviada. Tente outra foto em instantes."

    fun bloqueio(motivo: MotivoDeBloqueioLocal): String = when (motivo) {
        MotivoDeBloqueioLocal.MULTIPLOS_ROSTOS -> BLOQUEIO_MULTIPLOS_ROSTOS
        MotivoDeBloqueioLocal.ANALISE_INDISPONIVEL -> BLOQUEIO_ANALISE_INDISPONIVEL
    }
}
