package br.com.frila.core.seguranca

/**
 * Isolamento de conta em aparelho compartilhado por `vinculo_id` (contrato 0.2.30, RN15).
 *
 * Regra medida em `iOS/Contrato/openapi.yaml` (linhas 438-449): todo push leva o `vinculo_id`
 * do aparelho para o qual foi enviado; o app guarda o `vinculo_id` devolvido por
 * `/rpc/registrar_dispositivo` junto com a sessão. Um aviso cujo `vinculo_id` diverge do
 * guardado pertence a uma conta que já saiu desse aparelho e não pode ser mostrado com
 * conteúdo sensível.
 */
object ValidadorIsolamentoConta {

    /**
     * `true` se o push pode ser exibido com o conteúdo original; `false` se deve ser
     * neutralizado (mensagem genérica, sem dado de negócio).
     *
     * - `vinculoIdDoPush == null`: servidor anterior à 0.2.30, que não envia `vinculo_id`.
     *   Sem base para conferência, a regra antiga do cliente vale: exibe (RN15 não cobre
     *   servidor antigo).
     * - `vinculoIdDaSessaoAtiva == null`: não há sessão autenticada neste aparelho agora.
     *   Não existe "dono" do aviso a quem exibir conteúdo sensível — neutraliza.
     * - Ambos presentes: exibe só se forem iguais.
     */
    fun devePermitirConteudoOriginal(vinculoIdDoPush: String?, vinculoIdDaSessaoAtiva: String?): Boolean {
        if (vinculoIdDoPush == null) return true
        if (vinculoIdDaSessaoAtiva == null) return false
        return vinculoIdDoPush == vinculoIdDaSessaoAtiva
    }

    /** Mensagem genérica para o push neutralizado (nunca o `title`/`body` originais do payload). */
    const val MENSAGEM_NEUTRALIZADA = "Frila: Nova notificação disponível"
}
