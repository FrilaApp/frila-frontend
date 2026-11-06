package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.ConsentimentoBiometriaLGPD
import br.com.frila.core.dominio.modelo.StatusVerificacaoIdentidade
import br.com.frila.core.dominio.modelo.TipoDocumentoIdentidade
import br.com.frila.core.dominio.modelo.TipoParteEvidencia
import br.com.frila.core.dominio.modelo.VerificacaoIdentidade
import br.com.frila.core.dominio.regra.RegraSeloConfianca

/** Orquestra o fluxo da verificação de identidade (RN14): consentimento, upload e confirmação. */
class RepositorioVerificacaoIdentidade(private val servico: ServicoVerificacaoIdentidade) {

    suspend fun obterStatus(): VerificacaoIdentidade = servico.obterMinhaIdentidadeStatus().paraDominio()

    /**
     * Pede as URLs, envia cada parte devolvida e confirma o envio. Ordem de segurança (RN15):
     * sem consentimento de biometria nada sai do aparelho, e o upload só começa depois de conferir
     * que há bytes para todas as partes que o servidor pediu. Erros do serviço propagam sem
     * mascaramento; um upload parcial não é confirmado.
     */
    suspend fun enviarEvidencias(
        documento: TipoDocumentoIdentidade,
        evidencias: Map<TipoParteEvidencia, ByteArray>,
        consentimento: ConsentimentoBiometriaLGPD?,
        mimeType: String = "image/jpeg",
    ): VerificacaoIdentidade {
        check(!RegraSeloConfianca.precisaConsentimentoLgpd(consentimento)) {
            "Consentimento LGPD de biometria ausente"
        }
        val upload = servico.solicitarUploadVerificacao(documento.paraFio())
        val envios = upload.partes.map { parte ->
            val tipoParte = TipoParteEvidencia.entries.firstOrNull { it.paraFio() == parte.parte }
            val bytes = tipoParte?.let(evidencias::get)
                ?: throw ErroDaApi(
                    codigo = CodigoErroAPI.EVIDENCIA_INCOMPLETA,
                    codigoOriginal = "evidencia_incompleta",
                    detalhes = parte.parte,
                    mensagemCrua = "Sem imagem para a parte pedida pelo servidor",
                )
            Triple(parte.url, bytes, mimeType)
        }
        envios.forEach { (url, bytes, tipo) -> servico.enviarEvidencia(url, bytes, tipo) }
        return servico.confirmarEnvioVerificacao().paraDominio()
    }
}

private fun TipoDocumentoIdentidade.paraFio(): String = name.lowercase()

private fun TipoParteEvidencia.paraFio(): String = name.lowercase()

/** Status desconhecido é contrato quebrado: falha alto, em vez de inventar um estado para a tela. */
internal fun StatusVerificacaoDto.paraDominio(): VerificacaoIdentidade {
    val status = StatusVerificacaoIdentidade.entries.firstOrNull { it.name.lowercase() == statusVerificacao }
        ?: throw ErroDaApi(
            codigo = CodigoErroAPI.RESPOSTA_INVALIDA,
            codigoOriginal = "resposta_invalida",
            detalhes = statusVerificacao,
            mensagemCrua = "status_verificacao desconhecido",
        )
    return VerificacaoIdentidade(
        status = status,
        motivo = motivo,
        prazoEnvioAte = prazoEnvioAte,
        identidadeVerificada = identidadeVerificada,
    )
}
