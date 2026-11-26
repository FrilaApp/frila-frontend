package br.com.frila.feature.turnos.contratante

import androidx.lifecycle.ViewModel
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.CodigoDeCheckinDto
import br.com.frila.core.rede.ErroDaApi
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.sync.Mutex

/** O que o cartão do código de chegada tem a mostrar (paridade com `CodigoDaCasaViewModel.Estado` do iOS). */
sealed interface EstadoDoCodigoDaCasa {
    data object Carregando : EstadoDoCodigoDaCasa

    /** `409 checkin_pendente` com o check-in feito: longe do local ou há mais de 15 min. Vale a confirmação manual. */
    data object SemCodigoParaEsteCheckin : EstadoDoCodigoDaCasa

    /** Código em vigor, com zeros à esquerda preservados (ex.: `049215`). */
    data class Mostrando(val codigo: String) : EstadoDoCodigoDaCasa

    /** `422 fora_da_janela`. */
    data object ForaDaJanela : EstadoDoCodigoDaCasa

    /** `409 codigo_bloqueado`: o caminho do código fechou para o turno; vale a confirmação manual. */
    data object Encerrado : EstadoDoCodigoDaCasa

    /** `409 checkin_ja_confirmado`: a presença já valia; a tela do turno se atualiza. */
    data object JaVerificado : EstadoDoCodigoDaCasa

    /** Chave `checkin_por_codigo` desligada: o cartão não aparece. */
    data object Indisponivel : EstadoDoCodigoDaCasa

    data object Falhou : EstadoDoCodigoDaCasa
}

data class EstadoCartaoDoCodigo(
    val estado: EstadoDoCodigoDaCasa = EstadoDoCodigoDaCasa.Carregando,
    val segundosRestantes: Int = 0,
    /** O código venceu e outro está sendo gerado: a tela não mantém um código inválido. */
    val renovando: Boolean = false,
)

/**
 * O código de chegada que a casa mostra (`gerar_codigo_checkin`, 0.2.68; paridade com
 * `CodigoDaCasaViewModel.swift`). Gera ao abrir e de novo quando vence. A contagem parte de `segundos_restantes`
 * (contados pelo servidor) e anda por [relogioMs], que tem de ser monotônico: o relógio de parede, que o usuário
 * pode mudar, não interfere na validade. O código nunca vai a log.
 *
 * [gerar] é `ServicoTurnos.gerarCodigoCheckin`. Uma chamada por vez: [carregar] chamado enquanto outro está em
 * voo não faz nada. [aoConfirmar] avisa a tela do turno que a presença já foi verificada. Fiação em
 * `AppNavegacao`/`ModulosKoin`: L1-7.
 */
class CodigoDaCasaViewModel(
    private val turnoId: String,
    private val gerar: suspend (turnoId: String) -> Result<CodigoDeCheckinDto>,
    private val aoConfirmar: (() -> Unit)? = null,
    private val relogioMs: () -> Long = { System.nanoTime() / 1_000_000 },
) : ViewModel() {

    private val _estado = MutableStateFlow(EstadoCartaoDoCodigo())
    val estado: StateFlow<EstadoCartaoDoCodigo> = _estado.asStateFlow()

    private val emVoo = Mutex()
    private var venceEmMs: Long? = null

    /** Pede o código ao servidor: o mesmo se estiver na validade, um novo se venceu. */
    suspend fun carregar() = executar(ehReleitura = false)

    /** Releitura periódica (a tela chama a cada 5 s) com código ou aviso de "sem código" na tela. */
    suspend fun verificarConfirmacao() {
        when (_estado.value.estado) {
            is EstadoDoCodigoDaCasa.Mostrando, EstadoDoCodigoDaCasa.SemCodigoParaEsteCheckin -> executar(ehReleitura = true)
            else -> Unit
        }
    }

    /** Um passo da contagem (a tela chama a cada segundo): recalcula e, no zero, renova o código. */
    suspend fun passo() {
        val atual = _estado.value
        val venceEm = venceEmMs
        if (atual.estado !is EstadoDoCodigoDaCasa.Mostrando || venceEm == null) return
        val restanteMs = venceEm - relogioMs()
        // Arredonda para cima à mão: `Math.ceilDiv` só existe a partir do Java 18, e o app roda no Android 9.
        val segundos = if (restanteMs <= 0) 0 else ((restanteMs + 999) / 1000).toInt()
        _estado.update { it.copy(segundosRestantes = segundos) }
        if (segundos == 0 && !atual.renovando) {
            _estado.update { it.copy(renovando = true) }
            try {
                carregar()
            } finally {
                _estado.update { it.copy(renovando = false) }
            }
        }
    }

    suspend fun tentarDeNovo() {
        _estado.update { it.copy(estado = EstadoDoCodigoDaCasa.Carregando) }
        carregar()
    }

    private suspend fun executar(ehReleitura: Boolean) {
        if (!emVoo.tryLock()) return
        try {
            val resultado = try {
                gerar(turnoId)
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: Exception) {
                // `gerar` devolve Result, mas um lançamento escapa; sem isto o cartão ficaria preso em "Gerando…".
                Result.failure(erro)
            }
            resultado
                .onSuccess { codigo ->
                    venceEmMs = relogioMs() + codigo.segundosRestantes * 1000L
                    _estado.update {
                        it.copy(estado = EstadoDoCodigoDaCasa.Mostrando(codigo.codigo), segundosRestantes = codigo.segundosRestantes)
                    }
                }
                .onFailure { erro -> aplicarFalha(erro, ehReleitura) }
        } finally {
            emVoo.unlock()
        }
    }

    private fun aplicarFalha(erro: Throwable, ehReleitura: Boolean) {
        val novo = estadoPara(erro)
        // Na releitura em segundo plano, falha de rede ou transitória mantém a tela como está.
        if (ehReleitura && novo == EstadoDoCodigoDaCasa.Falhou) return
        venceEmMs = null
        _estado.update { it.copy(estado = novo, segundosRestantes = 0) }
        if (novo == EstadoDoCodigoDaCasa.JaVerificado) aoConfirmar?.invoke()
    }

    companion object {
        /** "M:SS" (272 vira "4:32"). */
        fun formatar(segundos: Int): String {
            val total = maxOf(0, segundos)
            return "%d:%02d".format(total / 60, total % 60)
        }

        internal fun estadoPara(erro: Throwable): EstadoDoCodigoDaCasa {
            val api = erro as? ErroDaApi ?: return EstadoDoCodigoDaCasa.Falhou
            val recursoDesligado = api.codigo == CodigoErroAPI.RECURSO_DESLIGADO ||
                (api.codigo == CodigoErroAPI.SEM_PERMISSAO && api.detalhesComoCodigo == CodigoErroAPI.RECURSO_DESLIGADO)
            return when {
                recursoDesligado -> EstadoDoCodigoDaCasa.Indisponivel
                api.codigo == CodigoErroAPI.CHECKIN_PENDENTE -> EstadoDoCodigoDaCasa.SemCodigoParaEsteCheckin
                // Qualquer bloqueio: sem `details` conhecido vale o mais restritivo (`encerrado`), como o iOS.
                api.codigo == CodigoErroAPI.CODIGO_BLOQUEADO -> EstadoDoCodigoDaCasa.Encerrado
                api.codigo == CodigoErroAPI.CHECKIN_JA_CONFIRMADO -> EstadoDoCodigoDaCasa.JaVerificado
                api.codigo == CodigoErroAPI.FORA_DA_JANELA -> EstadoDoCodigoDaCasa.ForaDaJanela
                else -> EstadoDoCodigoDaCasa.Falhou
            }
        }
    }
}
