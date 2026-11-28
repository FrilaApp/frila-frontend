package br.com.frila.core.dominio.modelo

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/** Quem foi bloqueado: o par `PerfilPublico.tipo` + `PerfilPublico.id`, como chegou à tela (RN10), nunca o id de conta. */
data class AlvoBloqueado(val tipo: TipoDeAlvo, val id: String) {
    companion object {
        /** `null` para um tipo que este app não conhece: o bloqueio vale no servidor, e a sessão só não o espelha. */
        fun deChaves(tipo: String, id: String): AlvoBloqueado? =
            TipoDeAlvo.entries.firstOrNull { it.chave == tipo }?.let { AlvoBloqueado(it, id) }
    }
}

/**
 * Quem a pessoa bloqueou **nesta sessão do app** (`BloqueiosDaSessao` do iOS). Só espelha o que o servidor confirmou, e vive na
 * memória: nunca é gravado, e o ponto único de limpeza da sessão (logout, troca de conta, expiração) o esvazia. Não é hidratado de
 * `listar_bloqueios`: depois de reiniciar o app o conjunto nasce vazio e quem filtra é o servidor, como no iOS.
 *
 * As telas que mostram o perfil de outra parte leem [alvos] para não oferecer de novo quem foi bloqueado enquanto o que elas
 * mostram ainda é de antes do bloqueio.
 */
class BloqueiosDaSessao {
    private val _alvos = MutableStateFlow<Set<AlvoBloqueado>>(emptySet())
    val alvos: StateFlow<Set<AlvoBloqueado>> = _alvos.asStateFlow()

    /**
     * Sobe a cada [limpar]. Um pedido em voo quando a sessão termina (logout, troca de conta, expiração) volta depois do `limpar`: se
     * ele registrasse ou removesse, o bloqueio da conta que saiu apareceria na seguinte. Quem espera o servidor só mexe no conjunto
     * se a geração é a mesma de quando partiu.
     */
    private var geracao = 0

    fun contem(tipo: TipoDeAlvo, id: String): Boolean = AlvoBloqueado(tipo, id) in _alvos.value
    fun contem(alvo: AlvoBloqueado): Boolean = alvo in _alvos.value

    fun registrar(alvo: AlvoBloqueado) {
        _alvos.update { it + alvo }
    }

    fun remover(alvo: AlvoBloqueado) {
        _alvos.update { it - alvo }
    }

    fun limpar() {
        synchronized(this) {
            geracao++
            _alvos.value = emptySet()
        }
    }

    /**
     * Roda [acao] (o pedido de bloqueio ao servidor) e **só depois** de ela voltar sem falha registra o alvo. Falha, recusa do servidor
     * e cancelamento sobem sem registrar: o conjunto nunca diz "bloqueado" por um bloqueio que o servidor não confirmou. Se a sessão
     * terminou enquanto o pedido estava em voo, o alvo não é registrado (ver [geracao]).
     */
    suspend fun <T> registrandoAposSucesso(alvoTipo: String, alvoId: String, acao: suspend () -> T): T {
        val daPartida = synchronized(this) { geracao }
        val resultado = acao()
        AlvoBloqueado.deChaves(alvoTipo, alvoId)?.let { alvo ->
            synchronized(this) { if (geracao == daPartida) registrar(alvo) }
        }
        return resultado
    }

    /** O desbloqueio, com a mesma regra: o alvo só sai do conjunto depois de o servidor confirmar, e na mesma sessão em que partiu. */
    suspend fun <T> removendoAposSucesso(alvoTipo: String, alvoId: String, acao: suspend () -> T): T {
        val daPartida = synchronized(this) { geracao }
        val resultado = acao()
        AlvoBloqueado.deChaves(alvoTipo, alvoId)?.let { alvo ->
            synchronized(this) { if (geracao == daPartida) remover(alvo) }
        }
        return resultado
    }
}
