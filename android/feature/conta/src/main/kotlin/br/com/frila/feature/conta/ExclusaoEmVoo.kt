package br.com.frila.feature.conta

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Wx0DhfEh (item 222): o pedido de exclusão de conta em voo, compartilhado entre as telas. O pedido roda num escopo de aplicação e sobrevive à tela;
 * reabrir a tela cria outro ViewModel com `excluindo = false`, e um segundo toque mandaria um segundo pedido. Quem tem o pedido no ar segura esta
 * trava; as outras telas a enxergam como "excluindo".
 *
 * A trava é solta quando o job do pedido termina, de qualquer jeito (sucesso, recusa, exceção, cancelamento, ou cancelado antes de começar): uma
 * trava que ninguém solta deixaria o botão desabilitado em silêncio. O pedido tem limite de tempo (`ClienteSupabase`), então ela nunca fica presa
 * além dele. A trava é do processo, não da conta: com um pedido da conta anterior ainda no ar, a tela da conta nova espera o fim dele.
 */
class ExclusaoEmVoo {
    private val _ativa = MutableStateFlow(false)
    val ativa: StateFlow<Boolean> = _ativa.asStateFlow()

    /** `true` se pegou a trava; `false` se outro pedido já a tem. */
    fun tentar(): Boolean = _ativa.compareAndSet(false, true)

    fun soltar() {
        _ativa.value = false
    }
}
