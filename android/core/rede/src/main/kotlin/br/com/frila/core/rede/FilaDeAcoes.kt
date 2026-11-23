package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Serializable
private data class ConteudoDaFila(val pendentes: List<AcaoPendente> = emptyList(), val recusadas: List<AcaoRecusada> = emptyList())

/**
 * Fila das ações sem rede, num arquivo privado fora do backup (padrão de [RepositorioVagas]). Cada ação traz a conta
 * dona. Guardar a recusa e tirar a ação dos reenvios é uma gravação só. Não há arquivo legível, ou ele está
 * corrompido: a fila começa vazia. [limpar] apaga memória e arquivo e invalida gravações em voo.
 */
class FilaDeAcoes(private val arquivo: File?) {
    private val json = Json { encodeDefaults = true; ignoreUnknownKeys = true }
    private var conteudo: ConteudoDaFila? = null
    private val _versao = MutableStateFlow(0)

    /** Soma um a cada mudança (enfileirar, enviar, recusar, limpar): quem mostra a fila na tela relê quando ela muda. */
    val versao: StateFlow<Int> = _versao.asStateFlow()

    @Synchronized fun pendentes(): List<AcaoPendente> = ler().pendentes

    @Synchronized fun recusadas(incluirReconhecidas: Boolean = false): List<AcaoRecusada> =
        ler().recusadas.filter { incluirReconhecidas || !it.avisoReconhecido }

    @Synchronized fun enfileirar(acao: AcaoPendente) {
        val atual = ler()
        if (atual.pendentes.none { it.id == acao.id }) gravar(atual.copy(pendentes = atual.pendentes + acao))
    }

    @Synchronized fun remover(id: String) {
        val atual = ler()
        if (atual.pendentes.any { it.id == id }) gravar(atual.copy(pendentes = atual.pendentes.filterNot { it.id == id }))
    }

    /** Só age sobre ação ainda pendente: o retorno de um envio em voo não repovoa a fila depois de [limpar]. */
    @Synchronized fun recusar(acao: AcaoPendente, codigo: CodigoErroAPI) {
        val atual = ler()
        if (atual.pendentes.none { it.id == acao.id }) return
        gravar(ConteudoDaFila(
            pendentes = atual.pendentes.filterNot { it.id == acao.id },
            recusadas = atual.recusadas.filterNot { it.id == acao.id } + AcaoRecusada(acao, codigo),
        ))
    }

    /** Uma tentativa aceita encerra os avisos anteriores da mesma operação (mesmo tipo, conta e alvo). */
    @Synchronized fun resolverRecusas(acao: AcaoPendente) {
        val atual = ler()
        if (atual.pendentes.none { it.id == acao.id }) return
        val novas = AcaoRecusada(acao, CodigoErroAPI.DESCONHECIDO)
        gravar(atual.copy(recusadas = atual.recusadas.filterNot {
            it.tipo == novas.tipo && it.contaId == novas.contaId && it.turnoId == novas.turnoId && it.vagaId == novas.vagaId &&
                it.estabelecimentoId == novas.estabelecimentoId
        }))
    }

    /** Fecha só o aviso; o registro fica para a ação não voltar aos reenvios. */
    @Synchronized fun reconhecerRecusa(id: String) {
        val atual = ler()
        gravar(atual.copy(recusadas = atual.recusadas.map { if (it.id == id) it.copy(avisoReconhecido = true) else it }))
    }

    @Synchronized fun limpar() {
        conteudo = ConteudoDaFila()
        _versao.value++
        arquivo?.let { if (it.exists() && !it.delete()) throw IOException("Não foi possível apagar a fila de ações") }
    }

    private fun ler(): ConteudoDaFila = conteudo ?: lerDoDisco().also { conteudo = it }

    private fun lerDoDisco(): ConteudoDaFila = try {
        arquivo?.takeIf { it.exists() }?.readText()?.let { json.decodeFromString<ConteudoDaFila>(it) } ?: ConteudoDaFila()
    } catch (_: IOException) { ConteudoDaFila() } catch (_: SerializationException) { ConteudoDaFila() }

    private fun gravar(novo: ConteudoDaFila) {
        conteudo = novo
        _versao.value++
        val destino = arquivo?.absoluteFile ?: return
        destino.parentFile.mkdirs()
        val temporario = File.createTempFile("acoes-", ".tmp", destino.parentFile)
        try {
            temporario.writeText(json.encodeToString(novo))
            Files.move(temporario.toPath(), destino.toPath(), StandardCopyOption.REPLACE_EXISTING)
        } finally { temporario.delete() }
    }
}
