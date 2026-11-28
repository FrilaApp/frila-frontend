package br.com.frila.feature.conta

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ExclusaoDeContaDto
import java.time.Instant
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Estado da tela de exclusão de conta. `resultado` só existe depois de o servidor aceitar o pedido. */
data class EstadoExclusaoDeConta(
    val confirmouConsequencias: Boolean = false,
    val excluindo: Boolean = false,
    val mensagemErro: String? = null,
    val resultado: ExclusaoDeContaDto? = null,
    /** Os turnos futuros que a exclusão cancelaria (só do profissional; a casa vem em outro PR). Não condiciona [podeExcluir]. */
    val turnosFuturos: TurnosFuturosDaExclusao = TurnosFuturosDaExclusao.NaoConsultados,
) {
    val podeExcluir: Boolean get() = confirmouConsequencias && !excluindo && resultado == null
}

/**
 * Exclusão definitiva de conta (RF25/RN15/RNF08, UC16, LGPD art. 18, VI). O contrato de
 * `/functions/v1/excluir-conta` só aceita `confirmar: true`; não há campo de motivo, então a tela
 * não coleta um.
 *
 * [excluir] é a chamada de rede (`ServicoPerfil.excluirConta`). [aoConcluir] roda uma vez, só
 * depois do sucesso, e é onde o chamador limpa a sessão local e navega para fora: nunca antes,
 * porque uma recusa (ex.: `409 administrador_unico`) deixa a conta de pé e a sessão precisa
 * continuar valendo.
 *
 * `escopo`: mesma razão do `PerfilViewModel` (teste injeta um escopo próprio).
 */
class ExclusaoDeContaViewModel(
    private val excluir: suspend () -> ExclusaoDeContaDto,
    private val aoConcluir: () -> Unit = {},
    /** Os turnos da conta (do profissional, ou das casas do contratante). `null`: a tela não consulta e mostra só o texto geral. */
    private val consultarTurnos: (suspend () -> ConsultaDeTurnosDaExclusao)? = null,
    private val relogio: () -> Instant = Instant::now,
    escopo: CoroutineScope? = null,
    /**
     * F4owLsLH: onde roda o PEDIDO de exclusão (e o [aoConcluir]). Sair da tela com o pedido em voo limpa o ViewModel e cancelaria o
     * `viewModelScope` no meio, com o servidor já tendo aceitado e a sessão sem ser limpa. O iOS roda o pedido numa `Task` não estruturada
     * (`TelaExclusaoDeConta.swift`), que não morre com a tela; aqui é um escopo de aplicação. Nulo: o mesmo escopo do ViewModel (os testes).
     */
    escopoDoPedido: CoroutineScope? = null,
    /** Wx0DhfEh: o pedido em voo, compartilhado entre as telas (o Koin entrega um só). Sem ele, cada ViewModel tem o seu. */
    private val emVoo: ExclusaoEmVoo = ExclusaoEmVoo(),
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope
    private val escopoDoPedido: CoroutineScope = escopoDoPedido ?: escopoDeTrabalho

    private val _estado = MutableStateFlow(EstadoExclusaoDeConta())
    val estado: StateFlow<EstadoExclusaoDeConta> = _estado.asStateFlow()

    private var leituraDosTurnos: Job? = null

    init {
        // Tela reaberta com o pedido de outra no ar: já nasce "excluindo" (botão desligado), e volta a poder pedir quando a trava solta.
        escopoDeTrabalho.launch {
            emVoo.ativa.collect { noAr -> _estado.update { if (it.excluindo == noAr) it else it.copy(excluindo = noAr) } }
        }
    }

    /**
     * Lê os turnos futuros ao abrir a tela (contrato: a exclusão cancela os turnos futuros do profissional e avisa as
     * contrapartes). Só lê e mostra: nunca exclui, e a lista indisponível não bloqueia a exclusão. Chamar de novo com a
     * leitura em voo ou já feita não lê outra vez.
     */
    fun carregarTurnos(): Job {
        val consultar = consultarTurnos ?: return escopoDeTrabalho.launch { }
        leituraDosTurnos?.let { return it }
        _estado.update { it.copy(turnosFuturos = TurnosFuturosDaExclusao.Carregando) }
        return escopoDeTrabalho.launch {
            val resultado = try {
                val agora = relogio()
                val consulta = consultar()
                TurnosFuturosDaExclusao.Lista(
                    turnos = consulta.turnos
                        .filter { turno -> turno.inicio.isAfter(agora) }
                        .sortedBy { turno -> turno.inicio },
                    limitada = consulta.limitada,
                )
            } catch (erro: CancellationException) {
                throw erro
            } catch (_: Exception) {
                // Qualquer falha (rede, sessão, corpo ilegível): a tela avisa e a exclusão segue liberada.
                TurnosFuturosDaExclusao.Indisponivel
            }
            _estado.update { it.copy(turnosFuturos = resultado) }
        }.also { leituraDosTurnos = it }
    }

    fun alterarConfirmacao(confirmou: Boolean) {
        _estado.update { if (it.excluindo || it.resultado != null) it else it.copy(confirmouConsequencias = confirmou) }
    }

    /**
     * Sem a confirmação, com pedido em curso ou já concluído, não faz nada: o segundo toque num
     * botão lento não pode disparar um segundo pedido.
     */
    fun confirmarExclusao(): Job {
        if (!_estado.value.podeExcluir) return escopoDeTrabalho.launch { }
        // Um pedido só no ar, entre todas as telas (Wx0DhfEh): a tela reaberta não manda o segundo.
        if (!emVoo.tentar()) return escopoDeTrabalho.launch { }
        _estado.update { it.copy(excluindo = true, mensagemErro = null) }
        // No escopo do pedido, e não no do ViewModel: com o pedido no ar, sair da tela não pode cancelá-lo (F4owLsLH).
        val pedido = escopoDoPedido.launch {
            try {
                val resultado = excluir()
                _estado.update { it.copy(excluindo = false, resultado = resultado) }
                aoConcluir()
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(excluindo = false, mensagemErro = mensagemDeErro(erro)) }
            } catch (_: Exception) {
                // Corpo não-JSON de gateway ou campo ausente escapam do ErroDaApi; sem isto a tela
                // ficaria em "Excluindo…" para sempre. A mensagem nunca carrega o corpo cru (RN15).
                _estado.update { it.copy(excluindo = false, mensagemErro = TextosExclusaoDeConta.ERRO_GENERICO) }
            }
        }
        // A trava solta quando o job acaba, de qualquer jeito: sucesso, recusa, exceção, cancelado no meio ou antes de começar. Sem isto, um
        // job que morresse deixaria o botão desabilitado em silêncio.
        pedido.invokeOnCompletion { emVoo.soltar() }
        return pedido
    }

    private fun mensagemDeErro(erro: ErroDaApi): String = when (erro.codigo) {
        CodigoErroAPI.ADMINISTRADOR_UNICO -> TextosExclusaoDeConta.ERRO_ADMIN_UNICO
        CodigoErroAPI.SEM_REDE -> TextosExclusaoDeConta.ERRO_SEM_REDE
        CodigoErroAPI.NAO_AUTENTICADO -> TextosExclusaoDeConta.ERRO_SESSAO
        else -> TextosExclusaoDeConta.ERRO_GENERICO
    }
}
