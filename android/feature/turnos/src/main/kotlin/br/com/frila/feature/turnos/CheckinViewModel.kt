package br.com.frila.feature.turnos

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.Coordenada
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
 * RN06: a até 200 m, o backend confirma check-in `geolocalizado`/`verificado` na hora. Sem
 * localização (sem permissão, GPS impreciso, sem sinal) ou acima de 200 m, vira `manual`, com a
 * presença `pendente` até o contratante confirmar — nunca é tratado como erro: o profissional
 * sempre consegue registrar o toque.
 *
 * `coordenadaDaVaga` nula (contrato de `/rpc/meus_turnos` hoje não traz a coordenada da vaga,
 * só `local`/`regiao_administrativa` em texto — MEDIDO em `iOS/Contrato/openapi.yaml`, schema
 * `VagaResumo`, linha 4455) degrada para o mesmo caminho de "sem localização": `distancia_m`
 * nulo, check-in manual pendente.
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

    fun fazerCheckin(): Job {
        _estado.update { it.copy(status = StatusCheckin.REGISTRANDO, mensagemErro = null) }
        return escopoDeTrabalho.launch {
            try {
                val coordenadaAtual = provedorDeLocalizacao.obterCoordenadaAtual()
                val distanciaMetros = calcularDistanciaMetros(coordenadaAtual, coordenadaDaVaga)

                val resultado = servicoTurnos.fazerCheckin(
                    turnoId = turnoId,
                    distanciaMetros = distanciaMetros,
                    registradoEm = instanteAtual().toString(),
                )

                _estado.update {
                    it.copy(
                        status = if (resultado.verificacao == "verificado") {
                            StatusCheckin.VERIFICADO
                        } else {
                            StatusCheckin.MANUAL_PENDENTE
                        },
                    )
                }
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(status = StatusCheckin.ERRO, mensagemErro = mensagemDeErro(erro)) }
            }
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
    }
}
