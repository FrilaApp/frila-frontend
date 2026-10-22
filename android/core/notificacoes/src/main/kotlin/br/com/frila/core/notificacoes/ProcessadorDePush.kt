package br.com.frila.core.notificacoes

import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.ValidadorIsolamentoConta

/** Campos extraídos do payload de dados do push (nunca de `notification.payload` — RN15). */
data class DadosDoPush(
    val vinculoId: String?,
    val tipo: String?,
    val vagaId: String?,
    val titulo: String?,
    val corpo: String?,
) {
    companion object {
        private const val CHAVE_VINCULO_ID = "vinculo_id"
        private const val CHAVE_TIPO = "tipo"
        private const val CHAVE_VAGA_ID = "vaga_id"
        private const val CHAVE_TITULO = "titulo"
        private const val CHAVE_CORPO = "corpo"

        fun doPayload(payload: Map<String, String>): DadosDoPush = DadosDoPush(
            vinculoId = payload[CHAVE_VINCULO_ID],
            tipo = payload[CHAVE_TIPO],
            vagaId = payload[CHAVE_VAGA_ID],
            titulo = payload[CHAVE_TITULO],
            corpo = payload[CHAVE_CORPO],
        )
    }
}

/** Resultado pronto para a camada de UI/sistema transformar em notificação de verdade. */
data class NotificacaoParaExibir(
    val canal: String,
    val titulo: String,
    val corpo: String,
    val vagaId: String?,
    /** `true` quando o conteúdo original foi trocado pela mensagem genérica (RN15). */
    val neutralizada: Boolean,
)

/**
 * Isolamento de conta em aparelho compartilhado (RN15): todo push chega com `vinculo_id`;
 * se ele não corresponder à sessão ativa deste aparelho, o conteúdo é neutralizado antes de
 * qualquer exibição — nunca o `titulo`/`corpo` originais do payload.
 */
class ProcessadorDePush(
    private val armazenamentoDeSessao: ArmazenamentoDeSessao,
) {
    fun processar(payload: Map<String, String>): NotificacaoParaExibir {
        val dados = DadosDoPush.doPayload(payload)
        val sessaoAtiva = armazenamentoDeSessao.obterSessao()

        val devePermitirOriginal = ValidadorIsolamentoConta.devePermitirConteudoOriginal(
            vinculoIdDoPush = dados.vinculoId,
            vinculoIdDaSessaoAtiva = sessaoAtiva?.vinculoId,
        )

        if (!devePermitirOriginal) {
            return NotificacaoParaExibir(
                canal = GerenciadorDeCanais.CANAL_SISTEMA,
                titulo = "Frila",
                corpo = ValidadorIsolamentoConta.MENSAGEM_NEUTRALIZADA,
                vagaId = null,
                neutralizada = true,
            )
        }

        return NotificacaoParaExibir(
            canal = canalParaTipo(dados.tipo),
            titulo = dados.titulo ?: "Frila",
            corpo = dados.corpo ?: "",
            vagaId = dados.vagaId,
            neutralizada = false,
        )
    }

    private fun canalParaTipo(tipo: String?): String = when (tipo) {
        "vaga_urgente", "confirmacao" -> GerenciadorDeCanais.CANAL_URGENCIA
        "turno", "checkin", "checkout", "atraso" -> GerenciadorDeCanais.CANAL_TURNOS
        else -> GerenciadorDeCanais.CANAL_SISTEMA
    }
}
