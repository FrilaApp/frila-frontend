package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.CodigoErroAPI.*
import java.io.IOException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/** O que reenvia cada tipo de ação. Quem monta o grafo injeta os envios reais; o sincronizador só decide a ordem e o destino. */
typealias EnvioDeAcao = suspend (AcaoPendente) -> Unit

/**
 * Reenvia a [FilaDeAcoes] ao voltar a rede (espelha `SincronizadorAcoes` do iOS). Um envio por vez, em ordem, sempre com a
 * mesma chave de idempotência da ação. Sem rede: a ação fica e a passada para. Recusa definitiva do servidor: sai dos
 * reenvios e vira aviso mínimo. Qualquer outro erro: a ação fica para uma nova tentativa idempotente. Ação de outra
 * conta é descartada sem enviar; sem conhecer a conta atual, nada é enviado. [contaAtual] confirma a conta no servidor.
 *
 * A conta é relida a cada passada. Antes de cada envio, a passada confere que a fila não foi limpa desde o começo dela
 * ([FilaDeAcoes.geracao]: logout, troca de conta, expiração) e que a ação ainda está pendente; limpa, a passada para sem
 * enviar mais nada, porque a lista e a conta que ela leu são de uma sessão que já saiu.
 *
 * Check-out recusado com `fora_da_janela`: pelo contrato (0.2.83), o servidor recusa assim também o reenvio de um turno que
 * já tem o check-out gravado, depois de `fim + 60 min`. Só nesse caso o sincronizador pergunta a [checkoutJaGravado]; com a
 * saída gravada, a ação sai da fila como enviada (a tela mostra a saída registrada), e não como recusada. A leitura sem rede
 * para a passada, como o envio sem rede; qualquer outra falha dela mantém a recusa de antes, nunca vira "enviada".
 */
class SincronizadorDeAcoes(
    private val fila: FilaDeAcoes,
    private val contaAtual: suspend () -> String,
    private val envios: Map<TipoAcaoPendente, EnvioDeAcao>,
    /** O turno já tem o check-out gravado no servidor (`meus_turnos`)? Sem ela, a recusa vale como antes. */
    private val checkoutJaGravado: (suspend (turnoId: String) -> Boolean)? = null,
) {
    private val passada = Mutex()

    /** Sincroniza a cada vez que o monitor passa a CONECTADO (inclusive o estado inicial). */
    fun observar(monitor: MonitorDeConectividade, escopo: CoroutineScope): Job = escopo.launch {
        monitor.status.collect { if (it == StatusConectividade.CONECTADO) sincronizar() }
    }

    suspend fun sincronizar() = passada.withLock {
        val geracao = fila.geracao()
        if (fila.pendentes().isEmpty()) return@withLock
        val conta = try { contaAtual() } catch (erro: Exception) {
            if (erro is CancellationException) throw erro
            return@withLock
        }
        for (acao in fila.pendentes()) {
            if (fila.geracao() != geracao) return@withLock
            if (fila.pendentes().none { it.id == acao.id }) continue
            if (acao.contaId != conta) { guardando { fila.remover(acao.id) }; continue }
            val envio = envios[acao.tipo] ?: continue
            try {
                envio(acao)
                // A ação aceita sai da fila mesmo se o disco falhar ao encerrar os avisos: reenviar duplicaria o envio.
                guardando { fila.resolverRecusas(acao) }
                fila.remover(acao.id)
            } catch (erro: ErroDaApi) {
                when {
                    erro.codigo == SEM_REDE -> return@withLock
                    acao.tipo == TipoAcaoPendente.AVALIACAO && erro.codigo == AVALIACAO_JA_REGISTRADA ->
                        guardando { fila.remover(acao.id) }
                    acao.tipo == TipoAcaoPendente.CHECKOUT && erro.codigo == FORA_DA_JANELA -> when (saidaGravada(acao)) {
                        null -> return@withLock
                        true -> { guardando { fila.resolverRecusas(acao) }; guardando { fila.remover(acao.id) } }
                        false -> guardando { fila.recusar(acao, erro.codigo) }
                    }
                    recusaDefinitiva(erro.codigo, acao) -> guardando { fila.recusar(acao, erro.codigo) }
                }
            } catch (erro: Exception) {
                if (erro is CancellationException) throw erro
                // Disco falhou depois do envio, ação malformada ou erro inesperado: a ação segue na fila.
            }
        }
    }

    private inline fun guardando(bloco: () -> Unit) = try { bloco() } catch (_: IOException) { }

    /** `true` só com o servidor dizendo que a saída está gravada; `null` sem rede (a passada para); `false` em todo o resto. */
    private suspend fun saidaGravada(acao: AcaoPendente): Boolean? {
        val conferir = checkoutJaGravado ?: return false
        val turno = acao.turnoId ?: return false
        return try {
            conferir(turno)
        } catch (erro: CancellationException) {
            throw erro
        } catch (erro: ErroDaApi) {
            if (erro.codigo == SEM_REDE) null else false
        } catch (_: Exception) {
            false
        }
    }

    private fun recusaDefinitiva(codigo: CodigoErroAPI, acao: AcaoPendente): Boolean = when (acao.tipo) {
        TipoAcaoPendente.CHECKIN, TipoAcaoPendente.CHECKOUT ->
            if (acao.tipo == TipoAcaoPendente.CHECKOUT && codigo == CHECKIN_PENDENTE) {
                // O check-in pode ter falhado por rede nesta passagem; não descarta a saída dele.
                fila.pendentes().none { it.tipo == TipoAcaoPendente.CHECKIN && it.turnoId == acao.turnoId }
            } else {
                codigo in setOf(SEM_PERMISSAO, CONTA_SUSPENSA, NAO_ENCONTRADO, VAGA_ENCERRADA, CAMPO_OBRIGATORIO,
                    CAMPO_INVALIDO, FORA_DA_JANELA, REGISTRO_NO_FUTURO)
            }
        TipoAcaoPendente.AVALIACAO -> codigo in setOf(SEM_PERMISSAO, CONTA_SUSPENSA, AVALIACAO_INDISPONIVEL, CAMPO_OBRIGATORIO)
        TipoAcaoPendente.PUBLICACAO_VAGA -> codigo.recusaDefinitivaDePublicacao
        TipoAcaoPendente.REPUBLICACAO_VAGA -> codigo.recusaDefinitivaDePublicacao || codigo == VAGA_OCULTA
        TipoAcaoPendente.CANCELAMENTO_POSICAO, TipoAcaoPendente.CANCELAMENTO_VAGA -> codigo.recusaDefinitivaDeCancelamento
    }
}
