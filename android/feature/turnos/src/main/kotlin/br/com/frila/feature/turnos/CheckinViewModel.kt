package br.com.frila.feature.turnos

import br.com.frila.core.rede.EventoDeTelemetria
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.ComprovanteCheckin
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.dominio.modelo.GeradorComprovanteCheckin
import br.com.frila.core.dominio.modelo.TipoVerificacaoCheckin
import br.com.frila.core.dominio.regra.instanteDoServidor
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.AcaoPendente
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.FilaDeAcoes
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.rede.TipoAcaoPendente
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.IOException
import java.time.Instant
import kotlin.math.roundToInt

/**
 * Check-in presencial de um turno (RF13/RN06/RN22, UC05). A localização é lida **só no toque**
 * (nunca em segundo plano) e só a distância calculada no aparelho é enviada ao backend — a
 * coordenada em si nunca sai do app (RN22, minimização LGPD).
 *
 * RN06, com a chave `checkin_por_codigo` desligada: a até 200 m, o backend confirma o check-in
 * `geolocalizado`/`verificado` na hora. Com a chave ligada (global, contrato 0.2.78), o toque nunca
 * verifica sozinho pelo GPS: fica `manual`, com a presença `pendente`, e a confirmação vem pelo
 * código (`fazer_checkin` no `iOS/Contrato/openapi.yaml`). Sem localização (sem permissão, GPS
 * impreciso, sem sinal) ou acima de 200 m, também vira `manual` pendente até o contratante
 * confirmar. Nunca é tratado como erro: o profissional sempre consegue registrar o toque.
 *
 * `coordenadaDaVaga` é o ponto da vaga (`VagaResumo.ponto`, que `/rpc/meus_turnos` traz para o
 * turno confirmado), repassado pela navegação desde o C0-7. Se vier nulo, o check-in segue o
 * caminho "sem localização": `distancia_m` nulo, check-in manual pendente.
 *
 * A6.2: sem rede (`SEM_REDE`), o toque vai para a [FilaDeAcoes] com o instante do toque e a distância medida, e o estado
 * vira `NA_FILA`; o `SincronizadorDeAcoes` envia quando a rede voltar. Um segundo toque no mesmo registro não enfileira de
 * novo. A tela reabre ou a fila muda: o estado é relido da fila (enviado, ainda na fila ou recusado de vez).
 *
 * `escopo`: ver nota em `br.com.frila.feature.entrada.entrada.EntradaViewModel` sobre por que
 * testes injetam um escopo próprio em vez de depender de `viewModelScope`/`Dispatchers.Main`.
 */
class CheckinViewModel(
    private val turnoId: String,
    private val coordenadaDaVaga: Coordenada?,
    private val servicoTurnos: ServicoTurnos,
    private val provedorDeLocalizacao: ProvedorDeLocalizacao,
    private val instanteAtual: () -> Instant = Instant::now,
    escopo: CoroutineScope? = null,
    private val registrarEvento: (EventoDeTelemetria, String?, String?) -> Unit = { _, _, _ -> },
    private val filaDeAcoes: FilaDeAcoes? = null,
    /** A conta dona do toque (o `sub` da sessão); sem ela nada é enfileirado. */
    private val contaAtual: () -> String? = { null },
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoCheckin())
    val estado: StateFlow<EstadoCheckin> = _estado.asStateFlow()

    /** C0-7: o pedido de permissão do sistema já foi respondido; depois dele, sem permissão, vem o diálogo das Configurações. */
    private var permissaoJaPedida = false
    private var checkinConcluidoEmitido = false
    private var enfileiramentoEmitido = false

    init {
        if (filaDeAcoes != null) {
            reconciliarComAFila()
            escopoDeTrabalho.launch { filaDeAcoes.versao.collect { reconciliarComAFila() } }
        }
    }

    /**
     * RN06/RN22: antes de tocar no GPS, confere permissão e se a localização do sistema está
     * ativa. Sem permissão, o 1º toque pede ao sistema ([EstadoCheckin.pedirPermissao]); só depois da
     * recusa aparece o diálogo defensivo que leva às Configurações. GPS desligado ou leitura imprecisa
     * também viram diálogo (nunca a API direto): o profissional decide entre resolver a pendência,
     * tentar de novo ou seguir no modo manual pela ação [prosseguirCheckinManual].
     */
    fun fazerCheckin(): Job {
        if (_estado.value.status == StatusCheckin.NA_FILA) return escopoDeTrabalho.launch { }
        registrarEvento(EventoDeTelemetria.CHECKIN_TENTADO, null, turnoId)
        reconhecerRecusas(TipoAcaoPendente.CHECKIN)
        val toque = instanteAtual()
        _estado.update { it.copy(status = StatusCheckin.REGISTRANDO, mensagemErro = null, dialogoDefensivo = null, avisoCheckin = null) }
        return escopoDeTrabalho.launch {
            if (!provedorDeLocalizacao.temPermissaoDeLocalizacao()) {
                _estado.update {
                    if (permissaoJaPedida) {
                        it.copy(status = StatusCheckin.OCIOSO, dialogoDefensivo = DialogoDefensivoLocalizacao.PERMISSAO_NEGADA)
                    } else {
                        it.copy(status = StatusCheckin.OCIOSO, pedirPermissao = true)
                    }
                }
                return@launch
            }
            if (!provedorDeLocalizacao.isGpsAtivado()) {
                _estado.update {
                    it.copy(status = StatusCheckin.OCIOSO, dialogoDefensivo = DialogoDefensivoLocalizacao.GPS_DESLIGADO)
                }
                return@launch
            }

            try {
                val leitura = provedorDeLocalizacao.lerParaCheckin()
                // Leitura com erro acima de 100 m não prova presença. Como no iOS (`.semGPS(.imprecisa)`),
                // a tela diz o motivo e nada sai até a pessoa escolher tentar de novo ou o check-in manual.
                if (leitura != null && leitura.precisaoMetros > PRECISAO_MAXIMA_METROS) {
                    _estado.update {
                        it.copy(status = StatusCheckin.OCIOSO, dialogoDefensivo = DialogoDefensivoLocalizacao.LEITURA_IMPRECISA)
                    }
                    return@launch
                }
                // Sem leitura no prazo (sem sinal): segue como "sem localização", check-in manual (RN06).
                val coordenadaAtual = leitura?.coordenada
                val distanciaMetros = calcularDistanciaMetros(coordenadaAtual, coordenadaDaVaga)
                registrarCheckin(distanciaMetros, toque)
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(status = StatusCheckin.ERRO, mensagemErro = mensagemDeErro(erro)) }
            }
        }
    }

    /**
     * L1-4: check-out (RF13/RN11/RN22). Lê a localização só no toque e manda só a distância; sem permissão,
     * sem GPS ou com leitura imprecisa segue com `distancia_m` nulo (o servidor aceita no check-out), sem diálogo:
     * o profissional nunca fica sem poder encerrar o turno. Um toque com outro em voo, ou depois de feito, não
     * envia nada. O estado do check-in não muda.
     */
    fun fazerCheckout(): Job {
        var iniciou = false
        _estado.update {
            iniciou = it.checkout != StatusCheckout.REGISTRANDO && it.checkout != StatusCheckout.FEITO &&
                it.checkout != StatusCheckout.NA_FILA
            if (iniciou) it.copy(checkout = StatusCheckout.REGISTRANDO, mensagemErroCheckout = null, avisoCheckout = null) else it
        }
        if (!iniciou) return escopoDeTrabalho.launch { }
        reconhecerRecusas(TipoAcaoPendente.CHECKOUT)
        val toque = instanteAtual()
        return escopoDeTrabalho.launch {
            var distanciaMetros: Int? = null
            try {
                distanciaMetros = MedidorDeDistancia(provedorDeLocalizacao, coordenadaDaVaga).medir()
                servicoTurnos.fazerCheckout(turnoId = turnoId, distanciaMetros = distanciaMetros, registradoEm = toque.toString())
                registrarEvento(EventoDeTelemetria.CHECKOUT_CONCLUIDO, null, turnoId)
                _estado.update { it.copy(checkout = StatusCheckout.FEITO, mensagemErroCheckout = null) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: Exception) {
                if (erro is ErroDaApi && erro.codigo == CodigoErroAPI.SEM_REDE) {
                    guardarNaFila(TipoAcaoPendente.CHECKOUT, distanciaMetros, toque)?.let { registro ->
                        _estado.update { it.copy(checkout = StatusCheckout.NA_FILA, checkoutNaFila = registro, mensagemErroCheckout = null) }
                        return@launch
                    }
                }
                // Também a resposta que não é JSON: sem isto o botão ficaria preso em "Registrando…" (R2 da A-001).
                _estado.update { it.copy(checkout = StatusCheckout.ERRO, mensagemErroCheckout = mensagemDeErroDoCheckout(erro)) }
            }
        }
    }

    private fun mensagemDeErroDoCheckout(erro: Exception): String = when ((erro as? ErroDaApi)?.codigo) {
        CodigoErroAPI.CHECKIN_PENDENTE -> TextosCheckoutECodigo.CHECKOUT_SEM_CHECKIN
        CodigoErroAPI.FORA_DA_JANELA -> TextosCheckoutECodigo.CHECKOUT_FORA_DA_JANELA
        CodigoErroAPI.REGISTRO_NO_FUTURO -> TextosCheckoutECodigo.CHECKOUT_HORARIO_ERRADO
        CodigoErroAPI.NAO_ENCONTRADO -> TextosCheckoutECodigo.CHECKOUT_NAO_ENCONTRADO
        CodigoErroAPI.SEM_REDE -> TextosCheckoutECodigo.CHECKOUT_SEM_REDE
        else -> TextosCheckoutECodigo.CHECKOUT_ERRO_PADRAO
    }

    /** A tela abriu o pedido de permissão do sistema: não abre de novo a cada recomposição. */
    fun pedidoDePermissaoAberto() {
        _estado.update { it.copy(pedirPermissao = false) }
    }

    /**
     * Resposta do pedido de permissão do sistema. Concedida, o check-in segue pelo GPS; recusada, aparece
     * o diálogo que leva às Configurações (e o próximo toque já vai direto a ele).
     */
    fun respostaDaPermissao(concedida: Boolean): Job {
        permissaoJaPedida = true
        _estado.update { it.copy(pedirPermissao = false) }
        if (concedida) return fazerCheckin()
        _estado.update { it.copy(status = StatusCheckin.OCIOSO, dialogoDefensivo = DialogoDefensivoLocalizacao.PERMISSAO_NEGADA) }
        return escopoDeTrabalho.launch { }
    }

    /**
     * Ação do diálogo defensivo: o profissional opta por seguir sem GPS. Pula a leitura de
     * coordenada e envia `distancia_m` nulo direto — o backend degrada para `manual`/`pendente`
     * (RN06), igual ao caminho de falha silenciosa de [obterCoordenadaAtual].
     */
    fun prosseguirCheckinManual(): Job {
        if (_estado.value.status == StatusCheckin.NA_FILA) return escopoDeTrabalho.launch { }
        val toque = instanteAtual()
        _estado.update {
            it.copy(status = StatusCheckin.REGISTRANDO, mensagemErro = null, dialogoDefensivo = null, avisoCheckin = null)
        }
        return escopoDeTrabalho.launch {
            try {
                registrarCheckin(distanciaMetros = null, toque = toque)
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(status = StatusCheckin.ERRO, mensagemErro = mensagemDeErro(erro)) }
            }
        }
    }

    /** `onDismissRequest` do diálogo defensivo: fecha sem registrar nada. */
    fun dispensarDialogoDefensivo() {
        _estado.update { it.copy(dialogoDefensivo = null, status = StatusCheckin.OCIOSO) }
    }

    private suspend fun registrarCheckin(distanciaMetros: Int?, toque: Instant) {
        val agora = toque

        val resultado = try {
            servicoTurnos.fazerCheckin(turnoId = turnoId, distanciaMetros = distanciaMetros, registradoEm = agora.toString())
        } catch (erro: ErroDaApi) {
            if (erro.codigo == CodigoErroAPI.SEM_REDE) {
                guardarNaFila(TipoAcaoPendente.CHECKIN, distanciaMetros, agora)?.let { registro ->
                    _estado.update { it.copy(status = StatusCheckin.NA_FILA, checkinNaFila = registro, mensagemErro = null) }
                    return
                }
            }
            throw erro
        }

        if (!checkinConcluidoEmitido) {
            checkinConcluidoEmitido = true
            registrarEvento(EventoDeTelemetria.CHECKIN_CONCLUIDO, null, turnoId)
        }
        val tipoVerificacao = mapearTipoVerificacaoCheckin(
            verificacao = resultado.verificacao,
            checkinTipo = resultado.tipo,
        )

        val comprovante = GeradorComprovanteCheckin.gerar(
            turnoId = turnoId,
            registradoEm = agora,
            tipoVerificacao = tipoVerificacao,
        )

        _estado.update { it.copy(status = statusDoCheckin(tipoVerificacao), comprovante = comprovante, checkinNaFila = null) }
    }

    private fun statusDoCheckin(tipoVerificacao: TipoVerificacaoCheckin): StatusCheckin = when (tipoVerificacao) {
        TipoVerificacaoCheckin.GEOLOCALIZADO,
        TipoVerificacaoCheckin.MANUAL_CONFIRMADO -> StatusCheckin.VERIFICADO
        TipoVerificacaoCheckin.MANUAL_PENDENTE -> StatusCheckin.MANUAL_PENDENTE
        TipoVerificacaoCheckin.NAO_VERIFICADO -> StatusCheckin.OCIOSO
    }

    /**
     * Guarda o toque na fila e devolve o que a tela mostra, ou `null` se não deu (sem fila, sem conta, disco): aí vale o
     * erro de sem conexão de antes. Já haver o mesmo registro na fila não enfileira de novo; o evento sai uma vez.
     */
    private fun guardarNaFila(tipo: TipoAcaoPendente, distanciaMetros: Int?, toque: Instant): RegistroNaFila? {
        val fila = filaDeAcoes ?: return null
        val conta = contaAtual() ?: return null
        val acao = try {
            fila.pendentes().firstOrNull { it.tipo == tipo && it.turnoId == turnoId && it.contaId == conta }
                ?: AcaoPendente(tipo, conta, toque.toString(), turnoId = turnoId, distanciaMetros = distanciaMetros)
                    .also { fila.enfileirar(it) }
        } catch (_: IOException) {
            return null
        }
        if (!enfileiramentoEmitido) {
            enfileiramentoEmitido = true
            registrarEvento(EventoDeTelemetria.ACAO_ENFILEIRADA_OFFLINE, null, turnoId)
        }
        return acao.registroNaFila()
    }

    private fun AcaoPendente.registroNaFila() =
        RegistroNaFila(runCatching { instanteDoServidor(instanteDoToque) }.getOrDefault(instanteAtual()), manual = distanciaMetros == null)

    /** Quem toca de novo depois de uma recusa de vez fecha o aviso dela; o registro fica para o envio não voltar. */
    private fun reconhecerRecusas(tipo: TipoAcaoPendente) {
        val fila = filaDeAcoes ?: return
        runCatching { fila.recusadas().filter { it.tipo == tipo && it.turnoId == turnoId }.forEach { fila.reconhecerRecusa(it.id) } }
    }

    /**
     * Relê a fila (ao abrir a tela e a cada mudança dela): o que está pendente vira `NA_FILA`; o que saiu da fila foi
     * recusado de vez (aviso) ou enviado (o servidor diz o que ficou gravado). Só conta o que é desta conta e deste turno.
     */
    private fun reconciliarComAFila() {
        val fila = filaDeAcoes ?: return
        val conta = contaAtual() ?: return
        val pendentes = fila.pendentes().filter { it.turnoId == turnoId && it.contaId == conta }
        val recusadas = fila.recusadas().filter { it.turnoId == turnoId && it.contaId == conta }
        val entrada = pendentes.firstOrNull { it.tipo == TipoAcaoPendente.CHECKIN }
        val saida = pendentes.firstOrNull { it.tipo == TipoAcaoPendente.CHECKOUT }
        val recusouEntrada = recusadas.any { it.tipo == TipoAcaoPendente.CHECKIN }
        val recusouSaida = recusadas.any { it.tipo == TipoAcaoPendente.CHECKOUT }
        var entradaEnviadaEm: Instant? = null
        var saidaEnviada = false
        _estado.update { e ->
            entradaEnviadaEm = null
            saidaEnviada = false
            var novo = e
            val livreEntrada = e.status == StatusCheckin.OCIOSO || e.status == StatusCheckin.ERRO
            when {
                entrada != null && livreEntrada ->
                    novo = novo.copy(status = StatusCheckin.NA_FILA, checkinNaFila = entrada.registroNaFila(), mensagemErro = null, avisoCheckin = null)
                entrada == null && e.status == StatusCheckin.NA_FILA && recusouEntrada ->
                    novo = novo.copy(status = StatusCheckin.OCIOSO, checkinNaFila = null, avisoCheckin = TextosDaFilaDePresenca.CHECKIN_RECUSADO)
                entrada == null && e.status == StatusCheckin.NA_FILA -> {
                    entradaEnviadaEm = e.checkinNaFila?.instante ?: instanteAtual()
                    novo = novo.copy(status = StatusCheckin.REGISTRANDO, checkinNaFila = null)
                }
                entrada == null && recusouEntrada && e.status == StatusCheckin.OCIOSO && e.comprovante == null && e.avisoCheckin == null ->
                    novo = novo.copy(avisoCheckin = TextosDaFilaDePresenca.CHECKIN_RECUSADO)
            }
            val livreSaida = e.checkout == StatusCheckout.OCIOSO || e.checkout == StatusCheckout.ERRO
            when {
                saida != null && livreSaida ->
                    novo = novo.copy(checkout = StatusCheckout.NA_FILA, checkoutNaFila = saida.registroNaFila(), mensagemErroCheckout = null, avisoCheckout = null)
                saida == null && e.checkout == StatusCheckout.NA_FILA && recusouSaida ->
                    novo = novo.copy(checkout = StatusCheckout.OCIOSO, checkoutNaFila = null, avisoCheckout = TextosDaFilaDePresenca.CHECKOUT_RECUSADO)
                saida == null && e.checkout == StatusCheckout.NA_FILA -> {
                    saidaEnviada = true
                    novo = novo.copy(checkout = StatusCheckout.FEITO, checkoutNaFila = null)
                }
                saida == null && recusouSaida && e.checkout == StatusCheckout.OCIOSO && e.avisoCheckout == null ->
                    novo = novo.copy(avisoCheckout = TextosDaFilaDePresenca.CHECKOUT_RECUSADO)
            }
            novo
        }
        if (saidaEnviada) registrarEvento(EventoDeTelemetria.CHECKOUT_CONCLUIDO, null, turnoId)
        entradaEnviadaEm?.let { confirmarEntradaEnviada(it) }
    }

    /** O check-in saiu da fila e o servidor o aceitou: ele diz se ficou verificado ou à espera da casa; sem resposta, o mais prudente. */
    private fun confirmarEntradaEnviada(toque: Instant) {
        escopoDeTrabalho.launch {
            val doServidor = try {
                servicoTurnos.listarMeusTurnos().firstOrNull { it.id == turnoId }?.paraItem()?.comprovante
            } catch (erro: CancellationException) {
                throw erro
            } catch (_: Exception) {
                null
            }
            val comprovante = doServidor ?: GeradorComprovanteCheckin.gerar(turnoId, toque, TipoVerificacaoCheckin.MANUAL_PENDENTE)
            if (!checkinConcluidoEmitido) {
                checkinConcluidoEmitido = true
                registrarEvento(EventoDeTelemetria.CHECKIN_CONCLUIDO, null, turnoId)
            }
            _estado.update { it.copy(status = statusDoCheckin(comprovante.tipoVerificacao), comprovante = comprovante) }
        }
    }

    private fun mensagemDeErro(erro: ErroDaApi): String = when (erro.codigo) {
        CodigoErroAPI.FORA_DA_JANELA -> "Fora do horário permitido para check-in deste turno."
        CodigoErroAPI.REGISTRO_NO_FUTURO -> "O horário do aparelho está incorreto. Ajuste e tente de novo."
        CodigoErroAPI.VAGA_ENCERRADA -> "Esta posição foi encerrada."
        CodigoErroAPI.SEM_REDE -> "Sem conexão. Verifique sua internet e tente de novo."
        else -> "Não foi possível registrar o check-in. Tente de novo."
    }

    companion object {
        /** Distância em metros, arredondada; `null` se faltar qualquer uma das duas coordenadas. */
        fun calcularDistanciaMetros(atual: Coordenada?, daVaga: Coordenada?): Int? {
            if (atual == null || daVaga == null) return null
            return (atual.distanciaKmAte(daVaga) * 1000).roundToInt()
        }

        /** RN06: limite para o backend confirmar o check-in geolocalizado na hora. */
        const val LIMITE_METROS = 200

        /** Raio de erro máximo de uma leitura que vale como prova, igual ao iOS (100 m). */
        const val PRECISAO_MAXIMA_METROS = 100f
    }
}
