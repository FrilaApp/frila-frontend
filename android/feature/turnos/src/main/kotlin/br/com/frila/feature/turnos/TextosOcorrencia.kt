package br.com.frila.feature.turnos

/** Textos do e-mail de suporte do relato de ocorrência (paridade com `FolhaSuporteTurno.swift`, que também não anexa foto). */
object TextosOcorrencia {
    const val ROTULO_RELATO = "Relato (vai só no e-mail de suporte)"
    const val CONFIRMACAO = "Agora envie seu relato por e-mail para que a Equipe Frila possa ajudar. O e-mail abre com ele já escrito."
    const val ABRIR_EMAIL = "Abrir e-mail de suporte"

    /** `403 sem_permissao` com `details: conta_suspensa` (paridade com `TextosDoSuporte.contaSuspensa` do iOS; o canal da conta suspensa é a contestação ou o e-mail). */
    const val CONTA_SUSPENSA = "Sua conta está suspensa. Acesse a contestação ou escreva para o suporte."

    /** `%s` = e-mail de suporte, `%s` = protocolo curto. */
    const val FALHA_AO_ABRIR_EMAIL =
        "Não foi possível abrir um app de e-mail. Escreva para %s e informe o protocolo #%s. O relato está logo abaixo, para copiar."
    const val RELATO_PARA_COPIAR = "Seu relato"
    const val RELATO_VAZIO = "Nenhum relato adicional informado."

    /** O relato vai no corpo do e-mail (extra do intent, não na URL), e clientes de e-mail recusam texto grande demais. */
    const val LIMITE_DO_RELATO = 2000

    fun assuntoDoEmail(protocoloCurto: String): String = "Ocorrência no turno · protocolo #$protocoloCurto"
}

/** O que a tela sabe para escrever o e-mail: o protocolo do chamado, o motivo escolhido e o relato digitado. */
data class PedidoDeEmailDeSuporte(
    val protocoloCurto: String,
    val motivo: br.com.frila.core.dominio.modelo.MotivoOcorrencia?,
    val relato: String,
)

/** Corpo do e-mail no formato do iOS (`corpoEmail`): turno, protocolo, motivo e relato. Só ids e o que a pessoa escreveu. */
fun corpoDoEmailDeSuporte(turnoId: String, pedido: PedidoDeEmailDeSuporte): String {
    val relato = pedido.relato.trim().ifEmpty { TextosOcorrencia.RELATO_VAZIO }
    return listOf(
        "Identificação do turno:",
        "- ID: $turnoId",
        "- Protocolo: #${pedido.protocoloCurto}",
        "",
        "Motivo do chamado:",
        pedido.motivo?.descricao ?: "Não informado",
        "",
        "Relato:",
        relato,
    ).joinToString("\n")
}
