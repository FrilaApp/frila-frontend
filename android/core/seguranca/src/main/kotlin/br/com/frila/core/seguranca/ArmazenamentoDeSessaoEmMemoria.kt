package br.com.frila.core.seguranca

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.concurrent.atomic.AtomicReference

/**
 * Implementação thread-safe em memória de [ArmazenamentoDeSessao], para testes de unidade e
 * para qualquer consumidor JVM puro. O estado é mantido num [AtomicReference] (escrita e leitura
 * sempre atômicas, sem lock explícito) e espelhado num [MutableStateFlow] para quem precisa
 * observar mudanças de sessão reativamente (ex.: desligar a navegação ao deslogar).
 *
 * **Não** é a implementação de produção: não cifra nada e não sobrevive ao fim do processo.
 * A persistência real usa Android Keystore + `EncryptedSharedPreferences`
 * (`docs/android/04-seguranca-e-sessao.md`).
 */
class ArmazenamentoDeSessaoEmMemoria : ArmazenamentoDeSessao {

    private val referencia = AtomicReference<Sessao?>(null)
    private val _sessao = MutableStateFlow<Sessao?>(null)

    /** Observação reativa da sessão atual (`null` quando deslogado). */
    val sessaoObservavel: StateFlow<Sessao?> = _sessao.asStateFlow()

    override fun salvarSessao(sessao: Sessao) {
        referencia.set(sessao)
        _sessao.value = sessao
    }

    override fun obterSessao(): Sessao? = referencia.get()

    override fun limparSessao() {
        referencia.set(null)
        _sessao.value = null
    }

    override fun estaAutenticado(): Boolean = referencia.get() != null
}
