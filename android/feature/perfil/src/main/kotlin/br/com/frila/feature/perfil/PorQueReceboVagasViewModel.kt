package br.com.frila.feature.perfil

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.CriteriosDeNotificacaoDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.JanelaDeDisponibilidadeDto
import br.com.frila.core.rede.ProtocoloDto
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/** Protocolo de contestação exibido na tela "Por que recebo vagas" (RF27). */
data class ProtocoloExibido(
    val numero: String,
    val enviadoEm: String,
    val prazoRespostaAte: String,
)

/** Estados da tela "Por que recebo vagas" (RF27, paridade com o iOS). */
sealed interface EstadoPorQueReceboVagas {
    data object Carregando : EstadoPorQueReceboVagas
    data object Vazio : EstadoPorQueReceboVagas
    data object SemRede : EstadoPorQueReceboVagas
    data class Erro(val mensagem: String? = null) : EstadoPorQueReceboVagas
    data class Conteudo(
        val criterios: CriteriosDeNotificacaoDto,
        val protocolo: ProtocoloExibido? = null,
        val contestacaoJaAberta: Boolean = false,
    ) : EstadoPorQueReceboVagas
}

/**
 * ViewModel de "Por que recebo vagas" (RF27, Item #34 da Paridade):
 * Mostra os critérios reais que o servidor devolve (`criterios_de_notificacao`: função, grade, distância, equipes)
 * e o status de contestação do despacho (protocolo existente ou botão para contestar).
 */
class PorQueReceboVagasViewModel(
    private val carregarCriterios: suspend () -> CriteriosDeNotificacaoDto,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow<EstadoPorQueReceboVagas>(EstadoPorQueReceboVagas.Carregando)
    val estado: StateFlow<EstadoPorQueReceboVagas> = _estado.asStateFlow()

    fun carregar(): Job {
        _estado.value = EstadoPorQueReceboVagas.Carregando
        return escopoDeTrabalho.launch {
            try {
                val criterios = carregarCriterios()
                if (criterios.semCriterios) {
                    _estado.value = EstadoPorQueReceboVagas.Vazio
                } else {
                    val protocolo = criterios.contestacao?.paraExibicao()
                    _estado.value = EstadoPorQueReceboVagas.Conteudo(
                        criterios = criterios,
                        protocolo = protocolo,
                        contestacaoJaAberta = protocolo != null,
                    )
                }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: Exception) {
                val erroApi = erro as? ErroDaApi
                _estado.value = when (erroApi?.codigo) {
                    CodigoErroAPI.SEM_REDE -> EstadoPorQueReceboVagas.SemRede
                    CodigoErroAPI.NAO_ENCONTRADO -> EstadoPorQueReceboVagas.Vazio
                    else -> EstadoPorQueReceboVagas.Erro(erroApi?.detalhes)
                }
            }
        }
    }

    companion object {
        private val FORMATO_DATA_BR = DateTimeFormatter.ofPattern("dd/MM/yyyy", Locale.forLanguageTag("pt-BR"))

        internal fun ProtocoloDto.paraExibicao(): ProtocoloExibido {
            val num = ocorrenciaId.replace("-", "").take(8).uppercase()
            val dataEnvio = formatarDataIso(criadaEm)
            val dataPrazo = formatarDataIso(prazoRespostaAte)
            return ProtocoloExibido(
                numero = num,
                enviadoEm = dataEnvio,
                prazoRespostaAte = dataPrazo,
            )
        }

        private fun formatarDataIso(iso: String): String {
            return runCatching {
                val parteData = iso.take(10)
                LocalDate.parse(parteData).format(FORMATO_DATA_BR)
            }.getOrDefault(iso)
        }

        fun descricaoJanela(janela: JanelaDeDisponibilidadeDto): String {
            val dia = nomeDoDiaSemana(janela.diaSemana)
            val base = "${janela.inicio} às ${janela.fim}"
            return if (janela.atravessaMeiaNoite()) {
                "$dia: $base (até o dia seguinte)"
            } else {
                "$dia: $base"
            }
        }

        fun descricaoDistancia(km: Double): String {
            return if (km % 1.0 == 0.0) {
                km.toInt().toString()
            } else {
                String.format(Locale.forLanguageTag("pt-BR"), "%.1f", km)
            }
        }
    }
}
