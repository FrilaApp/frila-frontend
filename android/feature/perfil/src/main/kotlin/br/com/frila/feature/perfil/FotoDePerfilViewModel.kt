package br.com.frila.feature.perfil

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.MidiaDto
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

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
 * Escolher a foto, prepará-la, conferir no aparelho e enviar (L1-3b). Só o envio: ver a foto atual, remover e pedir nova análise são do passo seguinte.
 * As duas operações chegam por função (a ligação é do L1-7): [prepararJpeg] lê a foto escolhida (uma referência em texto) e devolve o JPEG pronto,
 * e [enviar] é o `FluxoDaFotoDePerfil.enviar`.
 */
class FotoDePerfilViewModel(
    private val prepararJpeg: suspend (String) -> ByteArray,
    private val enviar: suspend (jpeg: ByteArray, enviarMesmoAssim: Boolean) -> SaidaDoEnvioDaFoto,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope
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
                "recurso_desligado" in chave -> TextosDaFotoDePerfil.ERRO_RECURSO_DESLIGADO
                erro.codigo == CodigoErroAPI.CONTA_SUSPENSA || "conta_suspensa" in chave -> TextosDaFotoDePerfil.ERRO_CONTA_SUSPENSA
                "midia_invalida" in chave -> TextosDaFotoDePerfil.ERRO_RECUSADA_PELO_SERVIDOR
                else -> TextosDaFotoDePerfil.ERRO_INDISPONIVEL_AGORA
            }
        }
    }
}
