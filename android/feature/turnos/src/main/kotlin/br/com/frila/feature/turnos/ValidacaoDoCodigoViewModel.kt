package br.com.frila.feature.turnos

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ResultadoRegistroDto
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** `409 codigo_bloqueado`: `temporario` (espere) ou `encerrado` (vale a confirmação manual da casa). */
enum class BloqueioDoCodigo { TEMPORARIO, ENCERRADO }

/** O que a última tentativa de confirmar a presença pelo código deixou para a tela dizer. */
sealed interface ResultadoDaValidacao {
    data object Aguardando : ResultadoDaValidacao
    data object Enviando : ResultadoDaValidacao

    /** `422 fora_do_raio`: o servidor recusou sem contar tentativa. */
    data object ForaDoRaio : ResultadoDaValidacao

    /** Acima do raio: nada foi enviado, e a tentativa continua inteira. */
    data class ChegueMaisPerto(val distanciaMetros: Int) : ResultadoDaValidacao

    /** Sem localização (nada enviado, ou `422 sem_localizacao`): orienta a pedir a confirmação manual à casa. */
    data object SemLocalizacao : ResultadoDaValidacao

    /** Não são 6 dígitos: nada foi enviado. */
    data object FormatoInvalido : ResultadoDaValidacao

    /** Presença verificada pelo código (`tipo: codigo`). */
    data class Verificado(val registro: ResultadoRegistroDto) : ResultadoDaValidacao

    /** `409 checkin_ja_confirmado`: outra leitura ou a casa chegou antes. A presença vale. */
    data object JaVerificado : ResultadoDaValidacao

    /** `422 codigo_invalido`: um motivo só, que o app não decifra. Conta como tentativa. */
    data object Invalido : ResultadoDaValidacao

    data class Bloqueado(val bloqueio: BloqueioDoCodigo) : ResultadoDaValidacao

    /** `403 sem_permissao` com `recurso_desligado`: a chave está desligada. */
    data object RecursoDesligado : ResultadoDaValidacao

    /** Sem resposta (rede ou prazo): não repete sozinho; a tentativa errada pode ter sido gravada. */
    data object RespostaPerdida : ResultadoDaValidacao

    data object Falhou : ResultadoDaValidacao
}

/**
 * O profissional digita o código da casa (`validar_codigo_checkin`, 0.2.68; paridade com
 * `ValidacaoDoCodigoViewModel.swift`). Só a distância sai do aparelho, nunca a coordenada, e o código nunca vai a log.
 *
 * - Fora do formato (6 dígitos) nada é lido nem enviado.
 * - Sem posição, ou acima de [RegraDePresenca.RAIO_DO_CODIGO_METROS], o código **não** é enviado e a tentativa
 *   não é gasta ("chegue mais perto" / "peça à casa").
 * - Nunca repete sozinho: se a resposta se perder, a tentativa errada já pode estar gravada, e repetir contaria outra
 *   e anteciparia o bloqueio (0.2.69). Um toque com outro em voo não envia nada.
 *
 * [validar] é `ServicoTurnos.validarCodigoCheckin`; [medirDistancia], a leitura no toque
 * (ex.: `MedidorDeDistancia::medir`); [aoPresencaVerificada] avisa a tela para reler o turno. Fiação: L1-7.
 */
class ValidacaoDoCodigoViewModel(
    private val turnoId: String,
    private val validar: suspend (turnoId: String, codigo: String, distanciaMetros: Int?) -> Result<ResultadoRegistroDto>,
    private val medirDistancia: suspend () -> Int? = { null },
    private val aoPresencaVerificada: (() -> Unit)? = null,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow<ResultadoDaValidacao>(ResultadoDaValidacao.Aguardando)
    val estado: StateFlow<ResultadoDaValidacao> = _estado.asStateFlow()

    fun validar(codigo: String): Job {
        if (_estado.value == ResultadoDaValidacao.Enviando) return escopoDeTrabalho.launch { }
        if (!RegraDePresenca.formatoDoCodigoValido(codigo)) {
            _estado.value = ResultadoDaValidacao.FormatoInvalido
            return escopoDeTrabalho.launch { }
        }
        var iniciou = false
        _estado.update {
            iniciou = it != ResultadoDaValidacao.Enviando
            ResultadoDaValidacao.Enviando
        }
        if (!iniciou) return escopoDeTrabalho.launch { }
        return escopoDeTrabalho.launch {
            val distancia = try {
                medirDistancia()
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: Exception) {
                null
            }
            when (val decisao = RegraDePresenca.decisaoDoEnvioDoCodigo(distancia)) {
                RegraDePresenca.DecisaoDoEnvioDoCodigo.SemLocalizacao -> _estado.value = ResultadoDaValidacao.SemLocalizacao
                is RegraDePresenca.DecisaoDoEnvioDoCodigo.ChegueMaisPerto ->
                    _estado.value = ResultadoDaValidacao.ChegueMaisPerto(decisao.distanciaMetros)
                RegraDePresenca.DecisaoDoEnvioDoCodigo.Liberado -> enviar(codigo, distancia)
            }
        }
    }

    private suspend fun enviar(codigo: String, distanciaMetros: Int?) {
        val resultado = try {
            validar(turnoId, codigo, distanciaMetros)
        } catch (erro: CancellationException) {
            throw erro
        } catch (erro: Exception) {
            // `validar` devolve Result, mas um lançamento escapa; sem isto o botão ficaria preso em "Confirmando…".
            Result.failure(erro)
        }
        resultado
            .onSuccess { registro ->
                _estado.value = ResultadoDaValidacao.Verificado(registro)
                aoPresencaVerificada?.invoke()
            }
            .onFailure { erro ->
                val novo = resultadoPara(erro)
                _estado.value = novo
                if (novo == ResultadoDaValidacao.JaVerificado) aoPresencaVerificada?.invoke()
            }
    }

    internal companion object {
        // Estes códigos ainda não estão em `CodigoErroAPI` (13 faltam; L3-4): vale o `codigoOriginal` cru do servidor.
        private const val CODIGO_INVALIDO = "codigo_invalido"
        private const val CODIGO_BLOQUEADO = "codigo_bloqueado"
        private const val FORA_DO_RAIO = "fora_do_raio"
        private const val SEM_LOCALIZACAO = "sem_localizacao"
        private const val RECURSO_DESLIGADO = "recurso_desligado"
        private const val TEMPORARIO = "temporario"

        fun resultadoPara(erro: Throwable): ResultadoDaValidacao {
            val api = erro as? ErroDaApi ?: return ResultadoDaValidacao.RespostaPerdida
            val recursoDesligado = api.codigoOriginal == RECURSO_DESLIGADO ||
                (api.codigo == CodigoErroAPI.SEM_PERMISSAO && api.detalhes == RECURSO_DESLIGADO)
            return when {
                recursoDesligado -> ResultadoDaValidacao.RecursoDesligado
                api.codigoOriginal == FORA_DO_RAIO -> ResultadoDaValidacao.ForaDoRaio
                api.codigoOriginal == SEM_LOCALIZACAO -> ResultadoDaValidacao.SemLocalizacao
                api.codigoOriginal == CODIGO_INVALIDO -> ResultadoDaValidacao.Invalido
                // Sem `details` conhecido vale o mais restritivo, para o app não prometer tentativa que o servidor não dá.
                api.codigoOriginal == CODIGO_BLOQUEADO -> ResultadoDaValidacao.Bloqueado(
                    if (api.detalhes == TEMPORARIO) BloqueioDoCodigo.TEMPORARIO else BloqueioDoCodigo.ENCERRADO,
                )
                api.codigo == CodigoErroAPI.CHECKIN_JA_CONFIRMADO -> ResultadoDaValidacao.JaVerificado
                api.codigo == CodigoErroAPI.CAMPO_INVALIDO -> ResultadoDaValidacao.FormatoInvalido
                api.codigo == CodigoErroAPI.SEM_REDE -> ResultadoDaValidacao.RespostaPerdida
                else -> ResultadoDaValidacao.Falhou
            }
        }
    }
}
