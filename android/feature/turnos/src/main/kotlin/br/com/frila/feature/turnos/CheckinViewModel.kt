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
    /** RNF04 (RN06, cartão Uu04zAt4): remove o alerta de aproximação assim que o check-in é feito. */
    private val monitorizador: MonitorizadorDeTurnosProximos? = null,
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
                registrarCheckin(distanciaMetros, coordenadaAtual)
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(status = StatusCheckin.ERRO, mensagemErro = mensagemDeErro(erro)) }
            }
        }
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
                registrarCheckin(distanciaMetros = null, coordenadaAtual = null)
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(status = StatusCheckin.ERRO, mensagemErro = mensagemDeErro(erro)) }
            }
        }
    }

    /** `onDismissRequest` do diálogo defensivo: fecha sem registrar nada. */
    fun dispensarDialogoDefensivo() {
        _estado.update { it.copy(dialogoDefensivo = null, status = StatusCheckin.OCIOSO) }
    }

    private suspend fun registrarCheckin(distanciaMetros: Int?, coordenadaAtual: Coordenada?) {
        val agora = instanteAtual()

        val resultado = servicoTurnos.fazerCheckin(
            turnoId = turnoId,
            distanciaMetros = distanciaMetros,
            registradoEm = agora.toString(),
        )

        // RNF04: o alerta de aproximação não serve mais depois do check-in confirmado. Só
        // depois do sucesso da chamada de rede — se ela falhar, o alerta não deve ser perdido
        // antes da hora (MEDIDO/ressalva do Shisui, PR #598).
        monitorizador?.removerAlerta(turnoId)

        val tipoVerificacao = mapearTipoVerificacaoCheckin(
            verificacao = resultado.verificacao,
            checkinTipo = resultado.tipo,
        )

        val comprovante = GeradorComprovanteCheckin.gerar(
            turnoId = turnoId,
            registradoEm = agora,
            tipoVerificacao = tipoVerificacao,
            coordenada = if (tipoVerificacao == TipoVerificacaoCheckin.GEOLOCALIZADO) coordenadaAtual else null,
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
