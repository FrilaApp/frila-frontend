package br.com.frila.feature.turnos

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.ComprovanteCheckin
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.dominio.modelo.GeradorComprovanteCheckin
import br.com.frila.core.dominio.modelo.TipoVerificacaoCheckin
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ServicoTurnos
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
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
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoCheckin())
    val estado: StateFlow<EstadoCheckin> = _estado.asStateFlow()

    /** C0-7: o pedido de permissão do sistema já foi respondido; depois dele, sem permissão, vem o diálogo das Configurações. */
    private var permissaoJaPedida = false

    /**
     * RN06/RN22: antes de tocar no GPS, confere permissão e se a localização do sistema está
     * ativa. Sem permissão, o 1º toque pede ao sistema ([EstadoCheckin.pedirPermissao]); só depois da
     * recusa aparece o diálogo defensivo que leva às Configurações. GPS desligado ou leitura imprecisa
     * também viram diálogo (nunca a API direto): o profissional decide entre resolver a pendência,
     * tentar de novo ou seguir no modo manual pela ação [prosseguirCheckinManual].
     */
    fun fazerCheckin(): Job {
        _estado.update { it.copy(status = StatusCheckin.REGISTRANDO, mensagemErro = null, dialogoDefensivo = null) }
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
                registrarCheckin(distanciaMetros)
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
            iniciou = it.checkout != StatusCheckout.REGISTRANDO && it.checkout != StatusCheckout.FEITO
            if (iniciou) it.copy(checkout = StatusCheckout.REGISTRANDO, mensagemErroCheckout = null) else it
        }
        if (!iniciou) return escopoDeTrabalho.launch { }
        val toque = instanteAtual()
        return escopoDeTrabalho.launch {
            try {
                val distanciaMetros = MedidorDeDistancia(provedorDeLocalizacao, coordenadaDaVaga).medir()
                servicoTurnos.fazerCheckout(turnoId = turnoId, distanciaMetros = distanciaMetros, registradoEm = toque.toString())
                _estado.update { it.copy(checkout = StatusCheckout.FEITO, mensagemErroCheckout = null) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: Exception) {
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
        _estado.update {
            it.copy(status = StatusCheckin.REGISTRANDO, mensagemErro = null, dialogoDefensivo = null)
        }
        return escopoDeTrabalho.launch {
            try {
                registrarCheckin(distanciaMetros = null)
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(status = StatusCheckin.ERRO, mensagemErro = mensagemDeErro(erro)) }
            }
        }
    }

    /** `onDismissRequest` do diálogo defensivo: fecha sem registrar nada. */
    fun dispensarDialogoDefensivo() {
        _estado.update { it.copy(dialogoDefensivo = null, status = StatusCheckin.OCIOSO) }
    }

    private suspend fun registrarCheckin(distanciaMetros: Int?) {
        val agora = instanteAtual()

        val resultado = servicoTurnos.fazerCheckin(
            turnoId = turnoId,
            distanciaMetros = distanciaMetros,
            registradoEm = agora.toString(),
        )

        val tipoVerificacao = mapearTipoVerificacaoCheckin(
            verificacao = resultado.verificacao,
            checkinTipo = resultado.tipo,
        )

        val comprovante = GeradorComprovanteCheckin.gerar(
            turnoId = turnoId,
            registradoEm = agora,
            tipoVerificacao = tipoVerificacao,
        )

        val status = when (tipoVerificacao) {
            TipoVerificacaoCheckin.GEOLOCALIZADO,
            TipoVerificacaoCheckin.MANUAL_CONFIRMADO -> StatusCheckin.VERIFICADO
            TipoVerificacaoCheckin.MANUAL_PENDENTE -> StatusCheckin.MANUAL_PENDENTE
            TipoVerificacaoCheckin.NAO_VERIFICADO -> StatusCheckin.OCIOSO
        }

        _estado.update {
            it.copy(
                status = status,
                comprovante = comprovante,
            )
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
