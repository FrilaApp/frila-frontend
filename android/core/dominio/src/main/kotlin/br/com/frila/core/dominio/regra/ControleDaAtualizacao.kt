package br.com.frila.core.dominio.regra

import java.time.Duration
import java.time.Instant

/**
 * As listas que se relêem sozinhas. Cada uma tem o próprio intervalo mínimo e a própria vez: a recarga de uma não segura a
 * de outra. Paridade com `ListaAtualizavel` de `AtualizacaoAutomatica.swift`.
 */
enum class ListaAtualizavel {
    VAGAS,
    MEUS_TURNOS,
    MINHAS_CANDIDATURAS,
    MINHAS_VAGAS,
    TURNO_DO_CONTRATANTE,
    EQUIPE_DE_CONFIANCA,
}

/** O que fazer com um pedido de releitura. */
sealed interface DecisaoDaAtualizacao {
    /** Reler agora. Ao terminar, quem recebeu chama [ControleDaAtualizacao.concluir]. */
    data object Recarregar : DecisaoDaAtualizacao

    /**
     * Reler depois de esperar [duracao] (o que falta do intervalo curto do push). A vez da lista fica reservada; ao fim da
     * espera, quem recebeu chama [ControleDaAtualizacao.retomar].
     */
    data class Esperar(val duracao: Duration) : DecisaoDaAtualizacao

    /** Nada a fazer. */
    data object Ignorar : DecisaoDaAtualizacao
}

/**
 * A regra da atualização automática das listas, sem Compose e sem relógio próprio: o instante vem de fora, para os testes
 * conduzirem o tempo. Porte de `ControleDaAtualizacao` (`AtualizacaoAutomatica.swift`), com a mesma regra:
 *
 * - Só com sessão: sem conta na tela, nenhum pedido passa e o aviso de push não conta.
 * - Uma recarga por lista de cada vez: o pedido que chega com outra em voo (ou esperando a vez) não abre uma segunda.
 * - Intervalo mínimo entre recargas da mesma lista ([intervaloMinimo], 30 s), contado do fim da anterior (com ou sem
 *   sucesso): alternar de app não martela o servidor.
 * - Um aviso de push que a lista ainda não atendeu passa por cima dos 30 s, mas não do intervalo curto do push
 *   ([intervaloDoAviso], 3 s): uma rajada de pushes dá no máximo uma releitura a cada 3 s. Se o aviso chega com uma recarga
 *   em voo, que pode ter saído antes da mudança, a lista é lida mais uma vez depois, respeitando os 3 s.
 *
 * Não é thread-safe: quem usa chama sempre da mesma thread (a principal), como o `@MainActor` do iOS.
 */
class ControleDaAtualizacao(
    val intervaloMinimo: Duration = INTERVALO_PADRAO,
    val intervaloDoAviso: Duration = INTERVALO_DO_AVISO_PADRAO,
) {
    var sessaoAtiva: Boolean = false
        private set

    /**
     * Quantos avisos de push da conta na tela chegaram desde a abertura do app. Só cresce: as listas observam a mudança, e
     * voltar a zero numa troca de conta pareceria um aviso novo.
     */
    var avisos: Int = 0
        private set

    private val ultimaRecarga = mutableMapOf<ListaAtualizavel, Instant>()
    private val avisosAtendidos = mutableMapOf<ListaAtualizavel, Int>()

    /** Listas com a vez reservada: recarga em voo ou esperando o intervalo curto do push. */
    private val ocupadas = mutableSetOf<ListaAtualizavel>()
    private val repetir = mutableSetOf<ListaAtualizavel>()

    /** A conta entrou ou saiu. Na troca, o que valia para a conta anterior (intervalos e avisos atendidos) é esquecido. */
    fun mudarSessao(ativa: Boolean) {
        if (ativa == sessaoAtiva) return
        sessaoAtiva = ativa
        ultimaRecarga.clear()
        avisosAtendidos.clear()
        repetir.clear()
    }

    fun avisoChegou() {
        if (!sessaoAtiva) return
        avisos += 1
    }

    /** A lista tem a vez reservada: recarga em voo ou esperando o intervalo curto do push. */
    fun emVoo(lista: ListaAtualizavel): Boolean = lista in ocupadas

    /** A própria tela acabou de carregar a lista (a primeira carga, quando aparece): conta como recarga e atende os avisos que já tinham chegado. */
    fun registrarCarga(lista: ListaAtualizavel, agora: Instant) {
        if (!sessaoAtiva) return
        ultimaRecarga[lista] = agora
        avisosAtendidos[lista] = avisos
    }

    fun pedir(lista: ListaAtualizavel, agora: Instant): DecisaoDaAtualizacao {
        if (!sessaoAtiva) return DecisaoDaAtualizacao.Ignorar
        val avisoNovo = avisos > (avisosAtendidos[lista] ?: avisos)
        if (lista in ocupadas) {
            if (avisoNovo) repetir += lista
            return DecisaoDaAtualizacao.Ignorar
        }
        val desdeAUltima = ultimaRecarga[lista]?.let { Duration.between(it, agora) }
        if (!avisoNovo && desdeAUltima != null && desdeAUltima < intervaloMinimo) return DecisaoDaAtualizacao.Ignorar
        ocupadas += lista
        return proximaVez(lista, agora)
    }

    /** Fim da espera do intervalo curto do push. */
    fun retomar(lista: ListaAtualizavel, agora: Instant): DecisaoDaAtualizacao {
        if (!sessaoAtiva) {
            ocupadas -= lista
            return DecisaoDaAtualizacao.Ignorar
        }
        return proximaVez(lista, agora)
    }

    /** Fim da recarga. Se um aviso chegou durante ela, a lista é lida de novo, depois do intervalo curto do push. */
    fun concluir(lista: ListaAtualizavel, agora: Instant): DecisaoDaAtualizacao {
        if (sessaoAtiva) ultimaRecarga[lista] = agora
        if (!sessaoAtiva || lista !in repetir) {
            ocupadas -= lista
            repetir -= lista
            return DecisaoDaAtualizacao.Ignorar
        }
        return proximaVez(lista, agora)
    }

    /** A recarga foi cancelada (a tela saiu): a vez da lista é liberada e o intervalo mínimo não conta, porque a lista não foi relida. */
    fun desistir(lista: ListaAtualizavel) {
        ocupadas -= lista
        repetir -= lista
        ultimaRecarga.remove(lista)
    }

    /** Com a vez reservada: relê agora, ou espera o que falta do intervalo curto do push. */
    private fun proximaVez(lista: ListaAtualizavel, agora: Instant): DecisaoDaAtualizacao {
        ultimaRecarga[lista]?.let { ultima ->
            val falta = intervaloDoAviso.minus(Duration.between(ultima, agora))
            if (falta > Duration.ZERO) return DecisaoDaAtualizacao.Esperar(falta)
        }
        repetir -= lista
        avisosAtendidos[lista] = avisos
        return DecisaoDaAtualizacao.Recarregar
    }

    companion object {
        val INTERVALO_PADRAO: Duration = Duration.ofSeconds(30)
        val INTERVALO_DO_AVISO_PADRAO: Duration = Duration.ofSeconds(3)
    }
}
