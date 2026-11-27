package br.com.frila.feature.perfil

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.MidiaDto
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.getAndUpdate
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.OffsetDateTime

/** Em que ponto está o envio da foto de perfil. */
sealed interface EtapaDaFoto {
    data object Parada : EtapaDaFoto
    data object Preparando : EtapaDaFoto
    data object Enviando : EtapaDaFoto

    /** Sem rosto: a tela avisa e oferece "Enviar mesmo assim" ou "Escolher outra foto". */
    data object AvisoSemRosto : EtapaDaFoto
    data class Bloqueada(val motivo: MotivoDeBloqueioLocal) : EtapaDaFoto
    data class Enviada(val midia: MidiaDto) : EtapaDaFoto
    data class Falhou(val mensagem: String) : EtapaDaFoto
}

/**
 * O que `minhas_midias` diz da foto de perfil da conta (a mais recente que não foi removida) e o pedido de nova análise (cartão 1dRm7FAH).
 */
data class SituacaoDaFoto(
    val midia: MidiaDto? = null,
    /** Já se pediu a nova análise desta foto: o pedido vale uma vez, e o texto passa a dizer isso. */
    val novaAnaliseJaPedida: Boolean = false,
    val pedindoNovaAnalise: Boolean = false,
    /** A falha do último pedido, em texto da tela. */
    val aviso: String? = null,
    /** `409 midia_indisponivel` com `details: expurgada`: o arquivo já foi apagado, a nova análise não existe mais e só resta enviar outra foto. */
    val arquivoExpurgado: Boolean = false,
) {
    /** Uma vez por foto `recusada` ou `nao_publicada`, e só se o servidor ainda deixa (`pode_pedir_nova_analise`: o arquivo existe). */
    val podePedirNovaAnalise: Boolean
        get() = midia != null && midia.estado in ESTADOS_DE_NOVA_ANALISE && midia.podePedirNovaAnalise &&
            !novaAnaliseJaPedida && !pedindoNovaAnalise

    private companion object {
        val ESTADOS_DE_NOVA_ANALISE = setOf("recusada", "nao_publicada")
    }
}

/**
 * Escolher a foto, prepará-la, conferir no aparelho e enviar (L1-3b). O envio e, para a foto recusada ou não publicada, ver o estado e pedir a nova análise ([situacao]); ver a foto aprovada e remover são do passo seguinte.
 * As duas operações chegam por função (a ligação é do L1-7): [prepararJpeg] lê a foto escolhida (uma referência em texto) e devolve o JPEG pronto,
 * e [enviar] é o `FluxoDaFotoDePerfil.enviar`.
 */
class FotoDePerfilViewModel(
    private val prepararJpeg: suspend (String) -> ByteArray,
    private val enviar: suspend (jpeg: ByteArray, enviarMesmoAssim: Boolean) -> SaidaDoEnvioDaFoto,
    /** `ServicoMidia.minhasMidias`. */
    private val listarMidias: suspend () -> List<MidiaDto> = { emptyList() },
    /** `ServicoMidia.pedirNovaAnaliseMidia`. */
    private val pedirNovaAnaliseMidia: suspend (midiaId: String) -> MidiaDto = { throw IllegalStateException("não ligado") },
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope
    private val _situacao = MutableStateFlow(SituacaoDaFoto())
    val situacao: StateFlow<SituacaoDaFoto> = _situacao.asStateFlow()

    /**
     * Lê `minhas_midias` e fica com a foto de perfil mais recente da conta (sem a removida e sem a da casa). Se a leitura falha a tela
     * segue como sempre, sem foto: enviar continua possível.
     */
    fun carregar(): Job = escopoDeTrabalho.launch {
        val midias = try {
            listarMidias()
        } catch (erro: CancellationException) {
            throw erro
        } catch (_: Exception) {
            return@launch
        }
        _situacao.update { it.copy(midia = fotoDaConta(midias)) }
    }

    /**
     * Pede a nova análise da foto `recusada` ou `nao_publicada` (uma vez; o 200 a leva a `em_analise`). Um pedido por vez. Falhando, mostra
     * o aviso e relê as mídias (o servidor pode ter mudado o estado), como o iOS.
     */
    fun pedirNovaAnalise(): Job {
        val anterior = _situacao.getAndUpdate { if (it.podePedirNovaAnalise && !ocupada()) it.copy(pedindoNovaAnalise = true, aviso = null) else it }
        val midia = anterior.midia
        if (midia == null || !anterior.podePedirNovaAnalise || ocupada()) return escopoDeTrabalho.launch { }
        return escopoDeTrabalho.launch {
            try {
                val nova = pedirNovaAnaliseMidia(midia.id)
                _situacao.update { it.copy(midia = if (nova.id == it.midia?.id) nova else it.midia, novaAnaliseJaPedida = true) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: Exception) {
                _situacao.update { it.copy(aviso = mensagemDaFalha(erro)) }
                val midias = try { listarMidias() } catch (cancelado: CancellationException) { throw cancelado } catch (_: Exception) { null }
                if (midias != null) _situacao.update { it.copy(midia = fotoDaConta(midias)) }
            } finally {
                _situacao.update { it.copy(pedindoNovaAnalise = false) }
            }
        }
    }

    private fun fotoDaConta(midias: List<MidiaDto>): MidiaDto? = midias
        .filter { it.tipo == "foto_perfil" && it.estabelecimentoId == null && it.estado != "removida" }
        .maxByOrNull { instanteDaMidia(it.enviadaEm) }

    private fun instanteDaMidia(texto: String?): Instant =
        texto?.let { runCatching { OffsetDateTime.parse(it).toInstant() }.getOrNull() } ?: Instant.MIN

    private val _etapa = MutableStateFlow<EtapaDaFoto>(EtapaDaFoto.Parada)
    val etapa: StateFlow<EtapaDaFoto> = _etapa.asStateFlow()

    /** O JPEG da última foto preparada: o "enviar mesmo assim" e o "tentar de novo" mandam o mesmo, sem escolher nem preparar de novo. */
    private var jpegAtual: ByteArray? = null

    private fun ocupada(): Boolean = _etapa.value == EtapaDaFoto.Preparando || _etapa.value == EtapaDaFoto.Enviando

    /** A foto escolhida (referência em texto, como a do seletor de fotos do sistema). */
    fun escolher(referencia: String) {
        if (ocupada()) return
        jpegAtual = null
        _etapa.value = EtapaDaFoto.Preparando
        escopoDeTrabalho.launch {
            val jpeg = try {
                prepararJpeg(referencia)
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: Exception) {
                _etapa.value = EtapaDaFoto.Falhou(TextosDaFotoDePerfil.ERRO_IMAGEM_INVALIDA)
                return@launch
            }
            jpegAtual = jpeg
            despachar(jpeg, enviarMesmoAssim = false)
        }
    }

    /** Só vale no aviso de "sem rosto": manda a mesma foto, sem escolher de novo. */
    fun enviarMesmoAssim() {
        val jpeg = jpegAtual
        if (_etapa.value != EtapaDaFoto.AvisoSemRosto || jpeg == null) return
        _etapa.value = EtapaDaFoto.Enviando
        escopoDeTrabalho.launch { despachar(jpeg, enviarMesmoAssim = true) }
    }

    /** Só vale depois de uma falha: tenta de novo a mesma foto (sem foto guardada, volta ao começo para escolher). */
    fun tentarDeNovo() {
        if (_etapa.value !is EtapaDaFoto.Falhou) return
        val jpeg = jpegAtual
        if (jpeg == null) {
            _etapa.value = EtapaDaFoto.Parada
            return
        }
        _etapa.value = EtapaDaFoto.Enviando
        escopoDeTrabalho.launch { despachar(jpeg, enviarMesmoAssim = false) }
    }

    /** Descarta a foto e volta ao começo. */
    fun escolherOutra() {
        if (ocupada()) return
        jpegAtual = null
        _etapa.value = EtapaDaFoto.Parada
    }

    private suspend fun despachar(jpeg: ByteArray, enviarMesmoAssim: Boolean) {
        _etapa.value = EtapaDaFoto.Enviando
        _etapa.value = when (val saida = enviar(jpeg, enviarMesmoAssim)) {
            is SaidaDoEnvioDaFoto.Enviada -> EtapaDaFoto.Enviada(saida.midia)
            SaidaDoEnvioDaFoto.AvisoSemRosto -> EtapaDaFoto.AvisoSemRosto
            is SaidaDoEnvioDaFoto.Bloqueada -> EtapaDaFoto.Bloqueada(saida.motivo)
            is SaidaDoEnvioDaFoto.Falhou -> EtapaDaFoto.Falhou(mensagemDaFalha(saida.erro))
        }
    }

    companion object {
        /** O que a tela diz de um erro do envio (paridade com `TextosFotoDePerfil.aviso` do iOS). Nada do erro cru vai à tela nem a log. */
        fun mensagemDaFalha(erro: Throwable): String {
            if (erro !is ErroDaApi) return TextosDaFotoDePerfil.ERRO_INDISPONIVEL_AGORA
            val chave = "${erro.codigoOriginal} ${erro.detalhes.orEmpty()}".lowercase()
            return when {
                erro.codigo == CodigoErroAPI.SEM_REDE -> TextosDaFotoDePerfil.ERRO_SEM_REDE
                // O par do backend (`403 sem_permissao` + `details: recurso_desligado`): o mesmo details em outro code não vale.
                erro.codigo == CodigoErroAPI.SEM_PERMISSAO && erro.detalhesComoCodigo == CodigoErroAPI.RECURSO_DESLIGADO -> TextosDaFotoDePerfil.ERRO_RECURSO_DESLIGADO
                erro.codigo == CodigoErroAPI.CONTA_SUSPENSA || "conta_suspensa" in chave -> TextosDaFotoDePerfil.ERRO_CONTA_SUSPENSA
                erro.codigo == CodigoErroAPI.MIDIA_INVALIDA -> TextosDaFotoDePerfil.ERRO_RECUSADA_PELO_SERVIDOR
                else -> TextosDaFotoDePerfil.ERRO_INDISPONIVEL_AGORA
            }
        }
    }
}
