package br.com.frila.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.lifecycle.compose.LifecycleResumeEffect
import br.com.frila.core.dominio.regra.AtualizacaoAutomatica
import br.com.frila.core.dominio.regra.ListaAtualizavel
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/** Quando a tela fica ativa pela primeira vez, a releitura automática conta essa carga ou fica de fora? (`AtualizacaoAoAparecer` do iOS.) */
internal enum class AtualizacaoAoAparecer {
    /** A primeira vez é a carga da própria tela (conta como recarga); as seguintes relêem. */
    AO_VOLTAR,

    /** A tela já recarrega sozinha a cada aparição: a primeira não conta como carga, e só a volta do segundo plano e o push relêem. */
    NUNCA,
}

/**
 * Relê a [lista] sozinha quando o app volta do segundo plano (a tela volta a `RESUMED`) e quando chega um push da conta com a
 * lista na tela, com intervalo mínimo e uma releitura por vez ([AtualizacaoAutomatica]). Porte do modificador
 * `atualizacaoAutomatica(_:aoAparecer: .aoVoltar)` do iOS (HaRJJ0L0).
 *
 * A primeira vez que a tela fica ativa é a carga da própria tela e conta como recarga (`registrarCarga`); as seguintes relêem.
 * [recarregar] deve ser a releitura em silêncio: com dados na tela, nada de carregamento por cima, e a falha deixa a lista como
 * estava. Sair da tela (pausar) cancela a releitura em curso e libera a vez da lista.
 */
@Composable
internal fun AtualizacaoAutomaticaDaLista(
    lista: ListaAtualizavel,
    atualizacao: AtualizacaoAutomatica,
    aoAparecer: AtualizacaoAoAparecer = AtualizacaoAoAparecer.AO_VOLTAR,
    recarregar: suspend () -> Unit,
) {
    val escopo = rememberCoroutineScope()
    val recarregarAtual by rememberUpdatedState(recarregar)
    val estado = remember { EstadoDaTela(avisosVistos = atualizacao.avisos.value) }

    fun pedir() {
        if (!estado.visivel) return
        val pedido = escopo.launch { atualizacao.pedir(lista) { recarregarAtual() } }
        // Com uma releitura em voo o pedido só marca a repetição (se veio de um aviso): a tarefa que a saída da tela cancela
        // continua sendo a que está em voo.
        if (estado.tarefa?.isActive != true) estado.tarefa = pedido
    }

    LifecycleResumeEffect(lista) {
        estado.visivel = true
        if (estado.jaApareceu) pedir() else if (aoAparecer == AtualizacaoAoAparecer.AO_VOLTAR) atualizacao.registrarCarga(lista)
        estado.jaApareceu = true
        onPauseOrDispose {
            estado.visivel = false
            estado.tarefa?.cancel()
            estado.tarefa = null
        }
    }

    // Aviso de push com a lista na tela. A lista escondida atende o aviso quando reaparece.
    val avisos by atualizacao.avisos.collectAsState()
    LaunchedEffect(avisos) {
        if (avisos != estado.avisosVistos) {
            estado.avisosVistos = avisos
            pedir()
        }
    }
}

private class EstadoDaTela(var avisosVistos: Int) {
    var visivel = false
    var jaApareceu = false
    var tarefa: Job? = null
}
