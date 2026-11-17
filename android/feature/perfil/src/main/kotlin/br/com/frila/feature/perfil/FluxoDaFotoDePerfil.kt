package br.com.frila.feature.perfil

import br.com.frila.core.rede.MidiaDto
import br.com.frila.core.rede.ServicoMidia
import kotlinx.coroutines.CancellationException

/** O que o envio da foto devolveu à tela. */
sealed interface SaidaDoEnvioDaFoto {
    data class Enviada(val midia: MidiaDto) : SaidaDoEnvioDaFoto

    /** Sem rosto: a tela mostra o aviso e pergunta se envia mesmo assim (volta com `enviarMesmoAssim = true`). */
    data object AvisoSemRosto : SaidaDoEnvioDaFoto

    /** Mais de um rosto ou análise indisponível: nada foi enviado, e "enviar mesmo assim" não vale. */
    data class Bloqueada(val motivo: MotivoDeBloqueioLocal) : SaidaDoEnvioDaFoto

    data class Falhou(val erro: Throwable) : SaidaDoEnvioDaFoto
}

class FluxoDaFotoDePerfil(
    private val conferidor: ConferidorDeRostoDaFoto,
    private val servicoMidia: ServicoMidia,
) {
    /**
     * Confere a foto no aparelho e, se vale, sobe: `solicitar_upload_midia` → PUT na URL assinada → `confirmar_upload_midia`.
     * [enviarMesmoAssim] só destrava o **aviso** de "sem rosto"; mais de um rosto e análise indisponível barram sempre. A conferência roda de
     * novo (milissegundos), então a decisão de bloquear nunca depende do que a tela guardou.
     */
    suspend fun enviar(jpeg: ByteArray, enviarMesmoAssim: Boolean = false): SaidaDoEnvioDaFoto =
        when (val conferencia = conferidor.conferir(jpeg)) {
            is ResultadoDaVerificacaoLocal.Bloqueada -> SaidaDoEnvioDaFoto.Bloqueada(conferencia.motivo)
            ResultadoDaVerificacaoLocal.AvisoSemRosto -> if (enviarMesmoAssim) subir(jpeg) else SaidaDoEnvioDaFoto.AvisoSemRosto
            ResultadoDaVerificacaoLocal.Liberada -> subir(jpeg)
        }

    private suspend fun subir(jpeg: ByteArray): SaidaDoEnvioDaFoto =
        try {
            val upload = servicoMidia.solicitarUploadMidia(mime = "image/jpeg", bytes = jpeg.size)
            servicoMidia.enviarFoto(upload.uploadUrl, jpeg)
            SaidaDoEnvioDaFoto.Enviada(servicoMidia.confirmarUploadMidia(upload.midiaId))
        } catch (erro: CancellationException) {
            throw erro
        } catch (erro: Exception) {
            SaidaDoEnvioDaFoto.Falhou(erro)
        }
}
