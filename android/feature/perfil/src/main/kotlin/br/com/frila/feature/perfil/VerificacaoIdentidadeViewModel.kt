package br.com.frila.feature.perfil

import android.content.Context
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.ConsentimentoBiometriaLGPD
import br.com.frila.core.dominio.modelo.TipoDocumentoIdentidade
import br.com.frila.core.dominio.modelo.TipoParteEvidencia
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.RepositorioVerificacaoIdentidade
import java.io.ByteArrayOutputStream
import java.time.Instant
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Selo voluntário "Identidade Verificada" (RN14/RN15, contrato 0.2.50). Orquestra: ler o estado,
 * registrar o consentimento de biometria, juntar as três partes e enviar via
 * [RepositorioVerificacaoIdentidade]. O servidor decide o desfecho; o app só mostra o estado.
 *
 * `escopo`: mesma razão do [PerfilViewModel] (teste injeta um escopo próprio).
 */
class VerificacaoIdentidadeViewModel(
    private val repositorio: RepositorioVerificacaoIdentidade,
    escopo: CoroutineScope? = null,
    private val agora: () -> Instant = Instant::now,
    /** Injetável para teste de JVM sem `ContentResolver`. Devolve `null` se a imagem passa do limite. */
    private val lerBytes: (Context, Uri) -> ByteArray? = ::lerImagemComLimite,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoVerificacaoIdentidade())
    val estado: StateFlow<EstadoVerificacaoIdentidade> = _estado.asStateFlow()

    /** RN15: bytes das imagens só em memória; zerados no envio com sucesso e em [onCleared]. */
    private val evidencias = mutableMapOf<TipoParteEvidencia, ByteArray>()

    /** Só lê o estado. Nada de biometria sai do aparelho antes do consentimento (ver [enviar]). */
    fun carregar(): Job {
        _estado.update { it.copy(carga = StatusCargaVerificacao.CARREGANDO, mensagemErro = null) }
        return escopoDeTrabalho.launch {
            try {
                val verificacao = repositorio.obterStatus()
                _estado.update { it.copy(carga = StatusCargaVerificacao.PRONTO, verificacao = verificacao) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.update {
                    it.copy(carga = StatusCargaVerificacao.ERRO, mensagemErro = mensagemDeErro(erro))
                }
            }
        }
    }

    /** LGPD art. 11, I: registra a manifestação específica, com a versão do termo e o instante. */
    fun confirmarConsentimento() {
        _estado.update {
            it.copy(
                consentimento = ConsentimentoBiometriaLGPD(
                    consentido = true,
                    versaoTermo = TermoBiometria.VERSAO,
                    dataHoraIso = agora().toString(),
                ),
            )
        }
    }

    fun definirDocumento(documento: TipoDocumentoIdentidade) {
        _estado.update { it.copy(documento = documento) }
    }

    /** Lê a imagem escolhida. Acima de [LIMITE_BYTES] (contrato: 5 MB) ou ilegível: recusa com aviso. */
    fun escolherParte(contexto: Context, parte: TipoParteEvidencia, uri: Uri): Job =
        escopoDeTrabalho.launch {
            val bytes = try {
                withContext(Dispatchers.IO) { lerBytes(contexto, uri) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (_: Exception) {
                null
            }
            if (bytes == null || bytes.isEmpty()) {
                _estado.update { it.copy(mensagemErro = MENSAGEM_IMAGEM_INVALIDA) }
                return@launch
            }
            evidencias[parte] = bytes
            _estado.update {
                it.copy(partesEscolhidas = it.partesEscolhidas + parte, mensagemErro = null)
            }
        }

    /**
     * Envia as três partes. Recusa sem rede se faltar consentimento, parte ou elegibilidade, e
     * ignora toque duplo durante o envio. Após erro, as imagens ficam para tentar de novo (o
     * repositório pede URLs novas, permitido pelo contrato).
     */
    fun enviar(): Job? {
        val atual = _estado.value
        if (!atual.podeEnviar) return null
        _estado.update { it.copy(envio = StatusEnvioVerificacao.ENVIANDO, mensagemErro = null) }
        val consentimento = atual.consentimento
        val documento = atual.documento
        val partes = evidencias.toMap()
        return escopoDeTrabalho.launch {
            try {
                val verificacao = repositorio.enviarEvidencias(documento, partes, consentimento)
                evidencias.clear()
                _estado.update {
                    it.copy(
                        verificacao = verificacao,
                        envio = StatusEnvioVerificacao.SUCESSO,
                        partesEscolhidas = emptySet(),
                    )
                }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.update {
                    it.copy(envio = StatusEnvioVerificacao.ERRO, mensagemErro = mensagemDeErro(erro))
                }
            }
        }
    }

    override fun onCleared() {
        evidencias.clear()
    }

    private fun mensagemDeErro(erro: ErroDaApi): String = when (erro.codigo) {
        CodigoErroAPI.VERIFICACAO_INDISPONIVEL -> when (erro.detalhes) {
            "em_analise" -> "Sua verificação já está em análise. Aguarde o resultado."
            "aprovada" -> "Sua identidade já foi verificada."
            "sem_envio_solicitado" -> "O envio não foi iniciado. Tente enviar de novo."
            else -> "A verificação não está disponível agora. Tente de novo mais tarde."
        }
        CodigoErroAPI.EVIDENCIA_INCOMPLETA ->
            "Faltou enviar ${rotuloDaParte(erro.detalhes)}. Escolha a imagem e envie de novo."
        CodigoErroAPI.CAMPO_INVALIDO -> "Os dados enviados não foram aceitos. Confira o documento e tente de novo."
        CodigoErroAPI.SEM_REDE -> "Sem conexão. Verifique sua internet e tente de novo."
        CodigoErroAPI.NAO_AUTENTICADO -> "Sua sessão expirou. Entre de novo."
        CodigoErroAPI.SEM_PERMISSAO -> "Esta conta não pode pedir a verificação."
        else -> "Não foi possível concluir a verificação. Tente de novo em instantes."
    }

    private fun rotuloDaParte(parte: String?): String = when (parte) {
        "frente" -> "a frente do documento"
        "verso" -> "o verso do documento"
        "selfie" -> "a selfie"
        else -> "uma das imagens"
    }

    companion object {
        /** Contrato `UploadVerificacao`: até 5 MB por arquivo. */
        const val LIMITE_BYTES = 5 * 1024 * 1024
        const val MENSAGEM_IMAGEM_INVALIDA =
            "Não foi possível usar esta imagem. Escolha uma foto de até 5 MB."
    }
}

/** Lê o URI sem passar de [VerificacaoIdentidadeViewModel.LIMITE_BYTES]; `null` se passar ou não abrir. */
internal fun lerImagemComLimite(contexto: Context, uri: Uri): ByteArray? {
    val limite = VerificacaoIdentidadeViewModel.LIMITE_BYTES
    contexto.contentResolver.openInputStream(uri)?.use { entrada ->
        val saida = ByteArrayOutputStream()
        val buffer = ByteArray(8 * 1024)
        while (true) {
            val lidos = entrada.read(buffer)
            if (lidos < 0) break
            if (saida.size() + lidos > limite) return null
            saida.write(buffer, 0, lidos)
        }
        return saida.toByteArray()
    }
    return null
}
