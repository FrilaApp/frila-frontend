package br.com.frila.core.notificacoes

import br.com.frila.core.rede.ServicoDispositivo
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import kotlin.coroutines.cancellation.CancellationException
import kotlin.time.Duration
import kotlin.time.Duration.Companion.seconds
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout

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
    private val escopo: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO),
    private val prazo: Duration = 15.seconds,
    /** Só o motivo, nunca o token nem a sessão (o app manda ao Log). */
    private val registrarFalha: (String) -> Unit = {},
    private val obterTokenFcm: suspend () -> String?,
) {
    /**
     * Para quem não pode esperar (abertura do app e entrada): dispara [registrar] no escopo próprio e volta na hora.
     * Tem prazo; falha de rede, do servidor ou do token vira só [registrarFalha] e nunca lança: o registro não trava
     * nem derruba a abertura nem a entrada, e tenta de novo na próxima abertura.
     */
    fun registrarEmSegundoPlano(): Job = escopo.launch {
        try {
            withTimeout(prazo) { registrar() }
        } catch (_: TimeoutCancellationException) {
            registrarFalha("registro do aparelho passou do prazo de ${prazo.inWholeSeconds} s")
        } catch (cancelado: CancellationException) {
            throw cancelado
        } catch (erro: Exception) {
            registrarFalha("registro do aparelho falhou: ${erro::class.simpleName}")
        }
    }

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
