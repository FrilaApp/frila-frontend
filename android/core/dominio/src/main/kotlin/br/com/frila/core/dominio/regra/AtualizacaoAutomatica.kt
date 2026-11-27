package br.com.frila.core.dominio.regra

import java.time.Duration
import java.time.Instant
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * O ponto central da atualização automática das listas (porte de `AtualizacaoAutomatica` de `AtualizacaoAutomatica.swift`): une a
 * regra ([ControleDaAtualizacao]) ao relógio, à espera do intervalo curto do push e à sessão. Sem timer e sem Realtime: a lista só é
 * relida quando a tela volta a ficar ativa e quando chega um aviso de push da conta que está na tela.
 *
 * [relogio] e [esperar] são injetáveis para os testes conduzirem o tempo, como no iOS. [sessao] devolve a chave da conta ativa (o
 * `vinculo_id`), ou `null` sem conta: trocar de conta, ou sair, esquece o que valia para a anterior.
 *
 * O aviso chega do serviço de push, fora da thread principal; as chamadas à regra são serializadas por [travaDaRegra].
 */
class AtualizacaoAutomatica(
    private val sessao: () -> String?,
    intervaloMinimo: Duration = ControleDaAtualizacao.INTERVALO_PADRAO,
    intervaloDoAviso: Duration = ControleDaAtualizacao.INTERVALO_DO_AVISO_PADRAO,
    private val relogio: () -> Instant = Instant::now,
    private val esperar: suspend (Duration) -> Unit = { delay(it.toMillis()) },
) {
    private val controle = ControleDaAtualizacao(intervaloMinimo, intervaloDoAviso)
    private val travaDaRegra = Any()
    private var chaveDaSessao: String? = null

    private val _avisos = MutableStateFlow(0)

    /** Sobe a cada aviso de push da conta na tela: as listas visíveis observam este número. */
    val avisos: StateFlow<Int> = _avisos.asStateFlow()

    /** Um push da conta que está na tela chegou com o app aberto. Pode ser chamado de qualquer thread. */
    fun avisoChegou() {
        synchronized(travaDaRegra) {
            acompanharSessao()
            controle.avisoChegou()
            _avisos.value = controle.avisos
        }
    }

    /** A própria tela acabou de carregar a lista: conta como recarga e atende os avisos que já tinham chegado. */
    fun registrarCarga(lista: ListaAtualizavel) {
        synchronized(travaDaRegra) {
            acompanharSessao()
            controle.registrarCarga(lista, relogio())
        }
    }

    fun emVoo(lista: ListaAtualizavel): Boolean = synchronized(travaDaRegra) { controle.emVoo(lista) }

    /**
     * Relê a lista se a regra deixar. [recarregar] é a releitura em silêncio da tela: não troca a lista por carregamento e, se
     * falhar, deixa o que está na tela. Se quem chamou for cancelado (a tela saiu), a vez da lista é liberada e o intervalo
     * mínimo não conta, porque a lista não foi relida.
     */
    suspend fun pedir(lista: ListaAtualizavel, recarregar: suspend () -> Unit) {
        var decisao = sincronizado { acompanharSessao(); controle.pedir(lista, relogio()) }
        while (true) {
            when (val atual = decisao) {
                DecisaoDaAtualizacao.Ignorar -> return
                is DecisaoDaAtualizacao.Esperar -> {
                    liberandoSeFalhar(lista) { esperar(atual.duracao) }
                    decisao = sincronizado { controle.retomar(lista, relogio()) }
                }
                DecisaoDaAtualizacao.Recarregar -> {
                    liberandoSeFalhar(lista) { recarregar() }
                    decisao = sincronizado { controle.concluir(lista, relogio()) }
                }
            }
        }
    }

    private suspend fun liberandoSeFalhar(lista: ListaAtualizavel, bloco: suspend () -> Unit) {
        try {
            bloco()
        } catch (erro: CancellationException) {
            sincronizado { controle.desistir(lista) }
            throw erro
        } catch (erro: Exception) {
            sincronizado { controle.desistir(lista) }
            throw erro
        }
    }

    /** Na troca de conta, o que valia para a anterior (intervalos e avisos atendidos) é esquecido; sem conta, nenhum pedido passa. */
    private fun acompanharSessao() {
        val chave = sessao()
        if (chave == chaveDaSessao) return
        chaveDaSessao = chave
        controle.mudarSessao(ativa = false)
        controle.mudarSessao(ativa = chave != null)
    }

    private inline fun <T> sincronizado(bloco: () -> T): T = synchronized(travaDaRegra, bloco)
}
