package br.com.frila.core.notificacoes

import br.com.frila.core.rede.ServicoDispositivo
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import kotlin.coroutines.cancellation.CancellationException

/**
 * Lógica pura de `onNewToken` (RF06/RN15/RNF02), separada do
 * [FrilaFirebaseMessagingService] para ficar testável em JVM pura, sem instrumentação:
 * registra o token FCM (com `versao_app`, contrato 0.2.56) e, se houver sessão ativa e o backend devolver
 * `vinculo_id`, atualiza a sessão guardada com o novo vínculo — é esse valor que [ProcessadorDePush] compara
 * contra o `vinculo_id` de cada push recebido depois.
 */
suspend fun sincronizarNovoToken(
    token: String,
    servicoDispositivo: ServicoDispositivo,
    armazenamentoDeSessao: ArmazenamentoDeSessao,
    versaoApp: String? = null,
) {
    val dispositivo = servicoDispositivo.registrarDispositivo(tokenFcm = token, versaoApp = versaoApp)
    val sessaoAtiva = armazenamentoDeSessao.obterSessao()

    if (sessaoAtiva != null && dispositivo.vinculoId != null) {
        armazenamentoDeSessao.salvarSessao(sessaoAtiva.copy(vinculoId = dispositivo.vinculoId))
    }
}

/**
 * O registro do aparelho numa função só (C0-10): chamada ao abrir o app com sessão e logo depois de entrar
 * ([registrar]), e quando o FCM troca o token ([registrarComToken]). O contrato manda registrar a cada abertura;
 * o mesmo token reenviado só atualiza a data. `obterTokenFcm` é o `FirebaseMessaging.getInstance().token` no app
 * (injetável para o teste); sem token (nulo, sem Play Services ou sem rede) nada sai e nada lança.
 */
class RegistradorDeDispositivo(
    private val servicoDispositivo: ServicoDispositivo,
    private val armazenamentoDeSessao: ArmazenamentoDeSessao,
    private val versaoApp: String?,
    private val obterTokenFcm: suspend () -> String?,
) {
    /** Ao abrir com sessão e depois de entrar. Sem sessão o servidor recusaria (401): não chama. */
    suspend fun registrar() {
        if (armazenamentoDeSessao.obterSessao() == null) return
        val token = try {
            obterTokenFcm()
        } catch (cancelado: CancellationException) {
            throw cancelado
        } catch (_: Exception) {
            null
        } ?: return
        registrarComToken(token)
    }

    /** O token novo do FCM (`onNewToken`) ou o lido em [registrar]. */
    suspend fun registrarComToken(token: String) {
        sincronizarNovoToken(token, servicoDispositivo, armazenamentoDeSessao, versaoApp)
    }
}
