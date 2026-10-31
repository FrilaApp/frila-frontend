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
    /** RF06: canal desativado pelo usuário — quem exibe não deve chamar `notify()`. */
    val silenciada: Boolean = false,
)

/**
 * Isolamento de conta em aparelho compartilhado (RN15): todo push chega com `vinculo_id`;
 * se ele não corresponder à sessão ativa deste aparelho, o conteúdo é neutralizado antes de
 * qualquer exibição — nunca o `titulo`/`corpo` originais do payload.
 */
class ProcessadorDePush(
    private val armazenamentoDeSessao: ArmazenamentoDeSessao,
    private val preferenciasNotificacao: GerenciadorPreferenciasNotificacao = GerenciadorPreferenciasNotificacaoEmMemoria(),
) {
    fun processar(payload: Map<String, String>): NotificacaoParaExibir {
        val dados = DadosDoPush.doPayload(payload)
        val sessaoAtiva = armazenamentoDeSessao.obterSessao()

        val devePermitirOriginal = ValidadorIsolamentoConta.devePermitirConteudoOriginal(
            vinculoIdDoPush = dados.vinculoId,
            vinculoIdDaSessaoAtiva = sessaoAtiva?.vinculoId,
        )

        if (!devePermitirOriginal) {
            val canal = GerenciadorDeCanais.CANAL_SISTEMA
            return NotificacaoParaExibir(
                canal = canal,
                titulo = "Frila",
                corpo = ValidadorIsolamentoConta.MENSAGEM_NEUTRALIZADA,
                vagaId = null,
                neutralizada = true,
                silenciada = !preferenciasNotificacao.estaAtivado(canal),
            )
        }

        val canal = canalParaTipo(dados.tipo)
        return NotificacaoParaExibir(
            canal = canal,
            titulo = dados.titulo ?: "Frila",
            corpo = dados.corpo ?: "",
            vagaId = dados.vagaId,
            neutralizada = false,
            silenciada = !preferenciasNotificacao.estaAtivado(canal),
        )
    }

    /**
     * Mapeamento canonico tipo -> canal conforme Contrato 0.2.46 (frila-docs #98, api/openapi.yaml:114-132).
     *
     * 16 tipos canonicos mapeados:
     * - canal_urgencia: vaga, vagas_agrupadas
     * - canal_turnos: confirmacao, lembrete_24h, lembrete_3h, inicio_sem_checkin, atraso_15min,
     *                 fim_sem_checkout, checkin, checkin_manual_pendente, cancelamento, avaliacao_disponivel
     * - canal_sistema: vaga_vazia, candidatura_recusada, suspensao, reativacao
     * - fallback (demais / futuro): canal_sistema
     */
    private fun canalParaTipo(tipo: String?): String = when (tipo) {
        // canal_urgencia (Alta importancia)
        "vaga",
        "vagas_agrupadas",
        "vaga_urgente" -> GerenciadorDeCanais.CANAL_URGENCIA // alias legado de transicao

        // canal_turnos (Importancia padrao)
        "confirmacao",
        "lembrete_24h",
        "lembrete_3h",
        "inicio_sem_checkin",
        "atraso_15min",
        "fim_sem_checkout",
        "checkin",
        "checkin_manual_pendente",
        "cancelamento",
        "avaliacao_disponivel",
        "turno", "checkout", "atraso" -> GerenciadorDeCanais.CANAL_TURNOS // aliases legados de transicao

        // canal_sistema (Importancia padrao)
        "vaga_vazia",
        "candidatura_recusada",
        "suspensao",
        "reativacao" -> GerenciadorDeCanais.CANAL_SISTEMA

        // Fallback para tipos futuros ou administrativos (ex: vaga_sem_elegiveis, selecao_encerrada, selecao_lembrete)
        else -> GerenciadorDeCanais.CANAL_SISTEMA
    }
}
