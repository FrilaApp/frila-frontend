package br.com.frila.feature.chamadas.casa

import br.com.frila.core.rede.ChamarProfissionalDto

/**
 * Tudo o que o [BuscaDeProfissionaisViewModel] precisa para continuar um envio pendente do ponto em que a pessoa saiu da tela: o estado e as
 * estruturas privadas que seguram a chave de idempotência de cada pedido, o trabalho da busca e as vagas já abertas.
 */
internal class BuscaGuardada(
    val estado: EstadoBusca,
    val tentativas: Map<Pair<String, ChaveDoTrabalho>, ChamarProfissionalDto>,
    val vagasPorTrabalho: Map<ChaveDoTrabalho, String>,
    val enviadosPorBusca: Map<BuscaFeita, Pair<TrabalhoDaChamada, String?>>,
    val ultimoEnvio: Pair<TrabalhoDaChamada, String?>?,
    val confirmacaoDosTermos: ConfirmacaoDosTermos?,
    val proximoCursor: String?,
    val recursoConfirmado: Boolean,
)

/**
 * O envio pendente da busca de cada casa, guardado acima da tela (paridade com `GuardaDaBuscaDeProfissionais` do iOS e irmã da
 * `GuardaDaEscala`).
 *
 * O [BuscaDeProfissionaisViewModel] nasce a cada visita à tela e some com ela. Se a pessoa sai com um envio em voo, incerto, a reenviar ou à espera de
 * confirmação, a chave de idempotência de cada pedido e o trabalho da busca morreriam junto: a visita seguinte mandaria outro trabalho completo
 * com chave nova, e o servidor, sem reconhecer a chave, poderia abrir uma 2ª vaga (dinheiro). Sem pendência, nada é guardado e a busca recomeça limpa.
 *
 * O logout, a troca de conta e a expiração da sessão esvaziam tudo ([limpar]). Cada [limpar] muda a [geracao]: um view model que nasceu antes
 * não consegue guardar depois, e a tela da conta que saiu, ao ser fechada, não devolve à guarda o que acabou de ser apagado.
 */
class GuardaDaBusca {
    private val porCasa = HashMap<String, BuscaGuardada>()
    private var geracaoAtual = 0

    /** A geração de agora: o view model a lê ao nascer e a devolve ao guardar. */
    internal fun geracao(): Int = synchronized(this) { geracaoAtual }

    internal fun obter(casaId: String): BuscaGuardada? = synchronized(this) { porCasa[casaId] }

    /** Só guarda se nenhum [limpar] aconteceu desde que o view model nasceu ([geracaoDaVisita]). */
    internal fun guardar(casaId: String, guardada: BuscaGuardada, geracaoDaVisita: Int) {
        synchronized(this) {
            if (geracaoDaVisita == geracaoAtual) porCasa[casaId] = guardada
        }
    }

    internal fun remover(casaId: String) {
        synchronized(this) { porCasa.remove(casaId) }
    }

    /** Esvazia todas as casas: o envio pendente é da conta que saiu. */
    fun limpar() {
        synchronized(this) {
            porCasa.clear()
            geracaoAtual++
        }
    }
}
