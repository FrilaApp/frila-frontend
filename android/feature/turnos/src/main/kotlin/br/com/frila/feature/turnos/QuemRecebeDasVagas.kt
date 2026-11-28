package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred

/**
 * Quem recebe o profissional no local de cada vaga (`Vaga.responsavel_local`), lido do `detalhe_vaga` e guardado em memória por `vaga_id`
 * durante a sessão. `meus_turnos` não traz o campo (`VagaResumo` não o tem), então cada vaga agendada custa uma leitura; o cache faz com
 * que a atualização automática e o puxar para atualizar não repitam essas leituras (cartão QpgRwPFM, decisão A).
 *
 * [ler] devolve o responsável da vaga (ou lança). Nunca lança daqui: toda falha é silenciosa, e a tela cai no nome da casa, como o iOS.
 * - Resposta lida: guardada, e em branco vale como "sem responsável".
 * - Recusa definitiva (404 da vaga direta de quem não tem turno nela, 403, 422): guardada como "sem responsável", para não repetir a cada releitura.
 * - Falha passageira (sem rede, 5xx, limite, sessão): NÃO é guardada, a próxima releitura tenta de novo.
 * Duas leituras da mesma vaga ao mesmo tempo viram uma. [limpar] (logout, troca de conta, sessão expirada) esvazia tudo, e uma leitura que
 * estava em voo nesse momento não guarda o dado da conta que saiu.
 */
class QuemRecebeDasVagas(private val ler: suspend (vagaId: String) -> String?) {

    /** O que se sabe de uma vaga: o responsável, ou `null` quando ela não tem (em branco, ou o servidor não a mostra a este profissional). */
    class Lido(val valor: String?)

    private val guardados = ConcurrentHashMap<String, Lido>()
    private val emVoo = ConcurrentHashMap<String, CompletableDeferred<Lido?>>()
    private val geracao = AtomicInteger(0)

    /** O que já se sabe da vaga, sem rede; `null` se ainda não se sabe (ou se a última tentativa foi passageira). */
    fun noCache(vagaId: String): Lido? = guardados[vagaId]

    /** Lê a vaga se ainda não se sabe; `null` se a leitura falhou agora sem ser definitivo. */
    suspend fun de(vagaId: String): Lido? {
        guardados[vagaId]?.let { return it }
        val minha = CompletableDeferred<Lido?>()
        emVoo.putIfAbsent(vagaId, minha)?.let { return it.await() }
        var resultado: Lido? = null
        val daGeracao = geracao.get()
        try {
            resultado = try {
                Lido(ler(vagaId)?.trim()?.takeIf { it.isNotEmpty() })
            } catch (cancelada: CancellationException) {
                throw cancelada
            } catch (erro: ErroDaApi) {
                if (erro.codigo in RECUSAS_DEFINITIVAS) Lido(null) else null
            } catch (_: Exception) {
                null
            }
            if (resultado != null && geracao.get() == daGeracao) guardados[vagaId] = resultado
            return resultado
        } finally {
            minha.complete(resultado)
            emVoo.remove(vagaId, minha)
        }
    }

    /** Esvazia o cache: o que se leu é da conta que estava na sessão. */
    fun limpar() {
        geracao.incrementAndGet()
        guardados.clear()
    }

    private companion object {
        /** Respostas que não mudam a cada releitura: repetir a leitura só gastaria rede. */
        val RECUSAS_DEFINITIVAS = setOf(
            CodigoErroAPI.NAO_ENCONTRADO, CodigoErroAPI.SEM_PERMISSAO, CodigoErroAPI.PERFIL_INCOMPATIVEL, CodigoErroAPI.CONTA_SUSPENSA,
        )
    }
}
