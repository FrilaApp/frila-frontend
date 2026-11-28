package br.com.frila.feature.perfil

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import java.io.File
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class EstadoExportarDados(
    val carregando: Boolean = false,
    val erro: CodigoErroAPI? = null,
    val arquivo: File? = null,
)

class ExportarDadosViewModel(
    private val exportarMeusDados: suspend () -> ByteArray,
    private val dispatcherIo: CoroutineDispatcher = Dispatchers.IO,
    private val agora: () -> Instant = Instant::now,
) : ViewModel() {
    private val _estado = MutableStateFlow(EstadoExportarDados())
    val estado = _estado.asStateFlow()

    fun exportar(diretorioCache: File) {
        if (_estado.value.carregando || _estado.value.arquivo != null) return
        // Antes do launch: dois cliques na mesma rodada não disparam duas requisições.
        _estado.value = EstadoExportarDados(carregando = true)
        viewModelScope.launch {
            var arquivo: File? = null
            try {
                val dados = exportarMeusDados()
                withContext(dispatcherIo) {
                    val pasta = File(diretorioCache, "meus-dados").apply { mkdirs() }
                    pasta.listFiles()?.filter { it.name.startsWith("frila-meus-dados-") && it.extension == "json" }
                        ?.forEach { it.delete() }
                    arquivo = File(pasta, nomeDoArquivo(agora()))
                    requireNotNull(arquivo).writeBytes(dados)
                }
                _estado.value = EstadoExportarDados(arquivo = arquivo)
            } catch (cancelamento: CancellationException) {
                arquivo?.delete()
                _estado.value = EstadoExportarDados()
                throw cancelamento
            } catch (erro: Exception) {
                arquivo?.delete()
                _estado.value = EstadoExportarDados(erro = (erro as? ErroDaApi)?.codigo ?: CodigoErroAPI.DESCONHECIDO)
            }
        }
    }

    fun compartilhamentoAberto() {
        // ACTION_SEND é assíncrono: o destinatário ainda precisa ler o arquivo pelo FileProvider.
        // O cache é privado e a próxima exportação remove os JSONs anteriores.
        _estado.value = EstadoExportarDados()
    }

    fun falhouAoCompartilhar() {
        _estado.value.arquivo?.delete()
        _estado.value = EstadoExportarDados(erro = CodigoErroAPI.DESCONHECIDO)
    }
}

/** `frila-meus-dados-2026-11-27.json`: a data é a de São Paulo, não a do aparelho (iOS `gravarArquivoTemporario`). */
internal fun nomeDoArquivo(instante: Instant): String {
    val dia = DateTimeFormatter.ofPattern("yyyy-MM-dd").withZone(ZoneId.of("America/Sao_Paulo")).format(instante)
    return "frila-meus-dados-$dia.json"
}
