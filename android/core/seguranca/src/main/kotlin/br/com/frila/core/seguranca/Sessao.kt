package br.com.frila.core.seguranca

/**
 * Sessão de aparelho guardada localmente: tokens de autenticação mais o `vinculo_id` do
 * registro de push deste aparelho com a conta ativa (contrato 0.2.30, RN15).
 *
 * `vinculoId` é nulo antes do primeiro `/rpc/registrar_dispositivo` bem-sucedido, ou quando o
 * backend ainda não o devolve (servidor anterior à 0.2.30) — nesses casos não há conferência
 * de vínculo possível, só a de token.
 */
data class Sessao(
    val accessToken: String,
    val refreshToken: String,
    val tokenType: String,
    val expiresIn: Long,
    val vinculoId: String? = null,
)
