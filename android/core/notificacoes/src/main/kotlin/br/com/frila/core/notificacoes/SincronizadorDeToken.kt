package br.com.frila.core.notificacoes

import br.com.frila.core.rede.ServicoDispositivo
import br.com.frila.core.seguranca.ArmazenamentoDeSessao

/**
 * Lógica pura de `onNewToken` (RF06/RN15/RNF02), separada do
 * [FrilaFirebaseMessagingService] para ficar testável em JVM pura, sem instrumentação:
 * registra o token FCM e, se houver sessão ativa e o backend devolver `vinculo_id`, atualiza
 * a sessão guardada com o novo vínculo — é esse valor que [ProcessadorDePush] compara contra
 * o `vinculo_id` de cada push recebido depois.
 */
suspend fun sincronizarNovoToken(
    token: String,
    servicoDispositivo: ServicoDispositivo,
    armazenamentoDeSessao: ArmazenamentoDeSessao,
) {
    val dispositivo = servicoDispositivo.registrarDispositivo(tokenFcm = token)
    val sessaoAtiva = armazenamentoDeSessao.obterSessao()

    if (sessaoAtiva != null && dispositivo.vinculoId != null) {
        armazenamentoDeSessao.salvarSessao(sessaoAtiva.copy(vinculoId = dispositivo.vinculoId))
    }
}
