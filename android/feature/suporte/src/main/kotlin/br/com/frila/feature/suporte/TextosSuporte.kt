package br.com.frila.feature.suporte

import br.com.frila.core.dominio.modelo.MotivoDenuncia

/** Textos em português brasileiro (paridade com `TextosDaSeguranca.swift`). */
object TextosSuporte {
    const val TITULO = "Denunciar"
    const val ROTULO_VOLTAR = "Voltar"
    const val EMERGENCIA = "Em risco imediato, ligue 190 (Polícia Militar) ou 180 (Central de Atendimento à Mulher)"
    const val LIGAR_190 = "Ligar 190 — Polícia Militar"
    const val LIGAR_180 = "Ligar 180 — Central de Atendimento à Mulher"
    const val SECAO_MOTIVO = "Motivo da denúncia"
    const val SECAO_RELATO = "Relato"
    const val RELATO_DICA = "Mínimo de 10 caracteres."
    const val RELATO_MINIMO = "O relato deve conter pelo menos 10 caracteres."
    const val RELATO_VALIDO = "Mínimo de caracteres atendido"
    const val ASSOCIADA_AO_TURNO = "Esta denúncia será associada ao turno."
    const val ASSOCIADA_A_CHAMADA = "Esta denúncia será associada à chamada."
    const val ENVIAR = "Enviar denúncia"
    const val ENVIANDO = "Enviando denúncia…"
    const val ENVIADA = "Denúncia enviada"
    const val PROTOCOLO = "Número do protocolo"
    const val PRAZO = "Resposta por e-mail até"
    const val CONCLUIR = "Concluir"
    const val BLOQUEAR = "Bloquear"
    const val BLOQUEANDO = "Bloqueando…"
    const val BLOQUEADO = "Você bloqueou este perfil"
    const val BLOQUEIO_CONFIRMAR = "Sim, bloquear"
    const val BLOQUEIO_TITULO = "Bloquear este perfil?"
    const val BLOQUEIO_EFEITO =
        "Vocês não voltam a se cruzar em notificações, listas ou candidaturas. " +
            "O bloqueio vale para todo o estabelecimento."
    const val CANCELAR = "Cancelar"
    const val INDISPONIVEL = "Perfil indisponível"
    const val ERRO_SEM_REDE = "Sem conexão. Verifique sua internet e tente novamente."
    const val ERRO_DADOS = "Não foi possível enviar estes dados. Confira as informações e tente novamente."
    const val ERRO_GENERICO = "Não foi possível concluir esta ação. Tente novamente."

    fun nome(motivo: MotivoDenuncia): String = when (motivo) {
        MotivoDenuncia.ASSEDIO -> "Assédio"
        MotivoDenuncia.DISCRIMINACAO -> "Discriminação"
        MotivoDenuncia.RISCO_SEGURANCA -> "Risco à segurança"
        MotivoDenuncia.OUTRO -> "Outro"
    }
}
