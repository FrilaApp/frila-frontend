package br.com.frila.feature.perfil

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.regra.instanteDoServidor
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.rede.TurnoDto
import java.io.File
import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

enum class AtalhoHistorico {
    ESTE_MES,
    MES_PASSADO,
    INTERVALO,
}

enum class FormatoExportacao(val extensao: String) {
    CSV("csv"),
    PDF("pdf"),
}

sealed interface EstadoHistorico {
    data object Ocioso : EstadoHistorico
    data object Carregando : EstadoHistorico
    data object SemTurnos : EstadoHistorico
    data class Erro(val mensagem: String, val repetivel: Boolean = true) : EstadoHistorico
}

data class PeriodoDeExportacao(
    val de: LocalDate,
    val ate: LocalDate,
) {
    init {
        require(!de.isAfter(ate)) { "A data inicial não pode ser posterior à final." }
    }

    val dias: Long get() = ChronoUnit.DAYS.between(de, ate) + 1
    val excedeLimite: Boolean get() = dias > 30

    companion object {
        fun esteMes(hoje: LocalDate): PeriodoDeExportacao =
            PeriodoDeExportacao(de = hoje.withDayOfMonth(1), ate = hoje)

        fun mesPassado(hoje: LocalDate): PeriodoDeExportacao {
            val mesAnterior = hoje.minusMonths(1)
            return PeriodoDeExportacao(
                de = mesAnterior.withDayOfMonth(1),
                ate = mesAnterior.withDayOfMonth(mesAnterior.lengthOfMonth()),
            )
        }
    }
}

object RegraDeLimites {
    fun ajustarAoMudarInicio(inicio: LocalDate, fimAtual: LocalDate, hoje: LocalDate): Pair<LocalDate, LocalDate> {
        val novoInicio = if (inicio.isAfter(hoje)) hoje else inicio
        val novoFim = if (fimAtual.isBefore(novoInicio)) novoInicio else if (fimAtual.isAfter(hoje)) hoje else fimAtual
        return Pair(novoInicio, novoFim)
    }

    fun ajustarAoMudarFim(fim: LocalDate, inicioAtual: LocalDate, hoje: LocalDate): Pair<LocalDate, LocalDate> {
        val novoFim = if (fim.isAfter(hoje)) hoje else fim
        val novoInicio = if (inicioAtual.isAfter(novoFim)) novoFim else if (inicioAtual.isAfter(hoje)) hoje else inicioAtual
        return Pair(novoInicio, novoFim)
    }
}

data class EstadoTelaHistorico(
    val atalho: AtalhoHistorico = AtalhoHistorico.ESTE_MES,
    val formato: FormatoExportacao = FormatoExportacao.CSV,
    val inicioEscolhido: LocalDate,
    val fimEscolhido: LocalDate,
    val estado: EstadoHistorico = EstadoHistorico.Ocioso,
    val arquivoParaCompartilhar: File? = null,
    val hoje: LocalDate,
) {
    val periodoEscolhido: PeriodoDeExportacao?
        get() = when (atalho) {
            AtalhoHistorico.ESTE_MES -> PeriodoDeExportacao.esteMes(hoje)
            AtalhoHistorico.MES_PASSADO -> PeriodoDeExportacao.mesPassado(hoje)
            AtalhoHistorico.INTERVALO -> {
                if (inicioEscolhido.isAfter(fimEscolhido) || fimEscolhido.isAfter(hoje)) null
                else runCatching { PeriodoDeExportacao(inicioEscolhido, fimEscolhido) }.getOrNull()
            }
        }

    val excedeLimite: Boolean get() = periodoEscolhido?.excedeLimite == true
    val periodoValido: Boolean get() = periodoEscolhido != null && !excedeLimite
}

class HistoricoDeTurnosViewModel(
    private val servicoTurnos: ServicoTurnos,
    private val relogio: Clock = Clock.system(ZoneId.of("America/Sao_Paulo")),
    private val geradorPdf: (File, ResumoFinanceiroPerfil, List<TurnoDto>, String, Instant, String?) -> File =
        GeradorExtratoPdf::gerar,
) : ViewModel() {

    companion object {
        const val PREFIXO_ARQUIVO = "frila-turnos-"
        val FUSO_SAO_PAULO: ZoneId = ZoneId.of("America/Sao_Paulo")

        fun nomeDoArquivo(periodo: PeriodoDeExportacao, formato: FormatoExportacao): String =
            "$PREFIXO_ARQUIVO${periodo.de}_${periodo.ate}.${formato.extensao}"
    }

    private fun hoje(): LocalDate = LocalDate.now(relogio)

    private val _estado = MutableStateFlow(
        EstadoTelaHistorico(
            inicioEscolhido = PeriodoDeExportacao.esteMes(hoje()).de,
            fimEscolhido = hoje(),
            hoje = hoje(),
        ),
    )
    val estado: StateFlow<EstadoTelaHistorico> = _estado.asStateFlow()

    fun escolher(atalho: AtalhoHistorico) {
        _estado.update {
            it.copy(
                atalho = atalho,
                hoje = hoje(),
                estado = if (it.estado is EstadoHistorico.SemTurnos || it.estado is EstadoHistorico.Erro) EstadoHistorico.Ocioso else it.estado,
            )
        }
    }

    fun escolher(formato: FormatoExportacao) {
        _estado.update {
            it.copy(
                formato = formato,
                estado = if (it.estado is EstadoHistorico.SemTurnos || it.estado is EstadoHistorico.Erro) EstadoHistorico.Ocioso else it.estado,
            )
        }
    }

    fun escolherInicio(novoInicio: LocalDate) {
        val ajustado = RegraDeLimites.ajustarAoMudarInicio(novoInicio, _estado.value.fimEscolhido, hoje())
        _estado.update {
            it.copy(
                inicioEscolhido = ajustado.first,
                fimEscolhido = ajustado.second,
                hoje = hoje(),
                estado = if (it.estado is EstadoHistorico.SemTurnos || it.estado is EstadoHistorico.Erro) EstadoHistorico.Ocioso else it.estado,
            )
        }
    }

    fun escolherFim(novoFim: LocalDate) {
        val ajustado = RegraDeLimites.ajustarAoMudarFim(novoFim, _estado.value.inicioEscolhido, hoje())
        _estado.update {
            it.copy(
                inicioEscolhido = ajustado.first,
                fimEscolhido = ajustado.second,
                hoje = hoje(),
                estado = if (it.estado is EstadoHistorico.SemTurnos || it.estado is EstadoHistorico.Erro) EstadoHistorico.Ocioso else it.estado,
            )
        }
    }

    fun limparArquivoParaCompartilhar() {
        _estado.update { it.copy(arquivoParaCompartilhar = null) }
    }

    internal fun limparArquivosAntigos(diretorio: File) {
        if (!diretorio.exists()) return
        diretorio.listFiles()?.forEach { arquivo ->
            if (arquivo.name.startsWith(PREFIXO_ARQUIVO) && (arquivo.extension == "csv" || arquivo.extension == "pdf")) {
                arquivo.delete()
            }
        }
    }

    fun exportar(diretorioTemporario: File, nomeProfissional: String = "Profissional") {
        val periodo = _estado.value.periodoEscolhido ?: return
        if (_estado.value.excedeLimite || _estado.value.estado is EstadoHistorico.Carregando) return

        viewModelScope.launch {
            _estado.update { it.copy(estado = EstadoHistorico.Carregando) }
            try {
                val todosTurnos = servicoTurnos.listarMeusTurnos()
                val turnosDoPeriodo = todosTurnos.filter { turno ->
                    if (turno.estado != "cumprida" && turno.estado != "confirmada") return@filter false
                    val dataTurno = runCatching {
                        instanteDoServidor(turno.vaga.inicioEm).atZone(FUSO_SAO_PAULO).toLocalDate()
                    }.getOrNull() ?: return@filter false
                    !dataTurno.isBefore(periodo.de) && !dataTurno.isAfter(periodo.ate)
                }

                if (turnosDoPeriodo.isEmpty()) {
                    _estado.update { it.copy(estado = EstadoHistorico.SemTurnos) }
                    return@launch
                }

                val pasta = File(diretorioTemporario, "extratos").apply { mkdirs() }
                limparArquivosAntigos(pasta)

                val formato = _estado.value.formato
                val nomeArquivo = nomeDoArquivo(periodo, formato)

                val arquivo = when (formato) {
                    FormatoExportacao.CSV -> {
                        GeradorExtratoCsv.gerar(pasta, turnosDoPeriodo, nomeArquivo)
                    }
                    FormatoExportacao.PDF -> {
                        val cumpridos = turnosDoPeriodo.filter { it.estado == "cumprida" }
                        val confirmados = turnosDoPeriodo.filter { it.estado == "confirmada" }
                        val resumo = ResumoFinanceiroPerfil(
                            totalConcluidoCentavos = cumpridos.sumOf { it.valorAcordadoCentavos },
                            totalPendenteCentavos = confirmados.sumOf { it.valorAcordadoCentavos },
                            turnosCumpridosQtd = cumpridos.size,
                            turnosAgendadosQtd = confirmados.size,
                        )
                        geradorPdf(
                            pasta,
                            resumo,
                            turnosDoPeriodo,
                            nomeProfissional,
                            relogio.instant(),
                            nomeArquivo,
                        )
                    }
                }

                _estado.update { it.copy(estado = EstadoHistorico.Ocioso, arquivoParaCompartilhar = arquivo) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                val repetivel = erro.codigoOriginal != "nao_autenticado" &&
                    erro.codigoOriginal != "sem_permissao" &&
                    erro.codigoOriginal != "intervalo_maximo_excedido"
                val mensagem = if (erro.codigoOriginal == "intervalo_maximo_excedido") {
                    TextosHistoricoDeTurnos.INTERVALO_MAXIMO_EXCEDIDO
                } else {
                    // O `message` do ErroDaApi é o texto de depuração (`ErroDaApi(codigo=..., codigoOriginal=...)`): não vai à tela.
                    when (erro.codigo) {
                        CodigoErroAPI.SEM_REDE -> TextosHistoricoDeTurnos.SEM_REDE
                        CodigoErroAPI.NAO_AUTENTICADO -> TextosHistoricoDeTurnos.SESSAO_EXPIRADA
                        CodigoErroAPI.SEM_PERMISSAO, CodigoErroAPI.PERFIL_INCOMPATIVEL -> TextosHistoricoDeTurnos.SEM_PERMISSAO
                        CodigoErroAPI.LIMITE_EXCEDIDO -> TextosHistoricoDeTurnos.LIMITE_EXCEDIDO
                        else -> TextosHistoricoDeTurnos.ERRO_DESCONHECIDO
                    }
                }
                _estado.update { it.copy(estado = EstadoHistorico.Erro(mensagem, repetivel)) }
            } catch (_: Exception) {
                _estado.update { it.copy(estado = EstadoHistorico.Erro(TextosHistoricoDeTurnos.ERRO_DESCONHECIDO, repetivel = true)) }
            }
        }
    }
}
