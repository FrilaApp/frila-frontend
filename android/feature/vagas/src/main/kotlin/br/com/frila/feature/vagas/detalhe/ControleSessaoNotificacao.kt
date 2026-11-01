package br.com.frila.feature.vagas.detalhe

/**
 * Controla a oferta da permissão de notificações em runtime durante a sessão do usuário.
 * Garante que o diálogo contextual de permissão só seja ofertado uma única vez por sessão
 * (após a primeira confirmação de vaga), mesmo se o profissional navegar entre diferentes
 * vagas ou instâncias de [TelaDetalheVaga].
 */
object ControleSessaoNotificacao {
    @Volatile
    var jaPediuNaSessao: Boolean = false

    fun marcarComoPedida() {
        jaPediuNaSessao = true
    }

    fun resetarParaTestes() {
        jaPediuNaSessao = false
    }
}
