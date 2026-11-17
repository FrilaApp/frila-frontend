package br.com.frila.feature.turnos.contratante

import androidx.lifecycle.ViewModel
import br.com.frila.core.rede.CodigoDeCheckinDto
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** O que o cartão do código de chegada tem a mostrar (paridade com `CodigoDaCasaViewModel.Estado` do iOS). */
sealed interface EstadoDoCodigoDaCasa {
    data object Carregando : EstadoDoCodigoDaCasa
    data object SemCodigoParaEsteCheckin : EstadoDoCodigoDaCasa
    data class Mostrando(val codigo: String) : EstadoDoCodigoDaCasa
    data object ForaDaJanela : EstadoDoCodigoDaCasa
    data object Encerrado : EstadoDoCodigoDaCasa
    data object JaVerificado : EstadoDoCodigoDaCasa
    data object Indisponivel : EstadoDoCodigoDaCasa
    data object Falhou : EstadoDoCodigoDaCasa
}

data class EstadoCartaoDoCodigo(
    val estado: EstadoDoCodigoDaCasa = EstadoDoCodigoDaCasa.Carregando,
    val segundosRestantes: Int = 0,
    val renovando: Boolean = false,
)

/** Esqueleto do teste vermelho (L1-5): sem comportamento. */
class CodigoDaCasaViewModel(
    private val turnoId: String,
    private val gerar: suspend (turnoId: String) -> Result<CodigoDeCheckinDto>,
    private val aoConfirmar: (() -> Unit)? = null,
    private val relogioMs: () -> Long = { System.nanoTime() / 1_000_000 },
) : ViewModel() {

    private val _estado = MutableStateFlow(EstadoCartaoDoCodigo())
    val estado: StateFlow<EstadoCartaoDoCodigo> = _estado.asStateFlow()

    suspend fun carregar() = Unit
    suspend fun passo() = Unit
    suspend fun verificarConfirmacao() = Unit
    suspend fun tentarDeNovo() = Unit

    companion object {
        fun formatar(segundos: Int): String = ""
    }
}
