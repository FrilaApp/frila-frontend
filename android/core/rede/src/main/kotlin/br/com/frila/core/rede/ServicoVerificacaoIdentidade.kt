package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import io.ktor.client.request.get
import io.ktor.client.request.post
import io.ktor.client.request.put
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.http.isSuccess

/** Verificação de identidade do profissional (RN14/RN15, contrato 0.2.50, UC09). */
class ServicoVerificacaoIdentidade(private val provedorDeCliente: () -> ClienteSupabase) {
    constructor(cliente: ClienteSupabase) : this({ cliente })

    /** Lido a cada chamada: após `GestorClienteKtor.recriar()` o cliente anterior está fechado. */
    private val cliente: ClienteSupabase get() = provedorDeCliente()

    /** `GET /rest/v1/rpc/minha_identidade_status`. Toda conta tem resposta (`nao_exigida` é o início). */
    suspend fun obterMinhaIdentidadeStatus(): StatusVerificacaoDto {
        val resposta = cliente.http.get(cliente.urlRpc("minha_identidade_status"))
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/solicitar_upload_verificacao`. [documentoTipo]: `rg` ou `cnh`. Devolve URLs
     * assinadas de upload válidas por 2 horas. Erros: `409 verificacao_indisponivel` (`em_analise`
     * ou `aprovada`), `422 campo_invalido`.
     */
    suspend fun solicitarUploadVerificacao(documentoTipo: String): UploadVerificacaoDto {
        val resposta = cliente.http.post(cliente.urlRpc("solicitar_upload_verificacao")) {
            contentType(ContentType.Application.Json)
            setBody(SolicitarUploadVerificacaoDto(documentoTipo = documentoTipo))
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/confirmar_envio_verificacao`. Idempotente. Erros: `422 evidencia_incompleta`
     * (`details`: a primeira parte que falta), `409 verificacao_indisponivel` (`sem_envio_solicitado`
     * ou `aprovada`).
     */
    suspend fun confirmarEnvioVerificacao(): StatusVerificacaoDto {
        val resposta = cliente.http.post(cliente.urlRpc("confirmar_envio_verificacao")) {
            contentType(ContentType.Application.Json)
            setBody("{}")
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `PUT` direto na URL assinada do Storage (opaca para o cliente, até 5 MB por arquivo), por um
     * cliente sem `apikey` nem `Authorization`: o token da URL é a única credencial. A
     * resposta do Storage não usa o envelope PostgREST: qualquer não-2xx vira [ErroDaApi] só com o
     * status, nunca com o corpo, que pode citar o caminho do arquivo (RN15). URL vencida: pedir de
     * novo com [solicitarUploadVerificacao]. Sem retry automático (PUT não é idempotente para o cliente).
     */
    suspend fun enviarEvidencia(urlUploadAssinada: String, bytes: ByteArray, mimeType: String = "image/jpeg") {
        val resposta = cliente.httpSemCredenciais.put(urlUploadAssinada) {
            contentType(ContentType.parse(mimeType))
            setBody(bytes)
        }
        if (!resposta.status.isSuccess()) {
            throw ErroDaApi(
                codigo = CodigoErroAPI.DESCONHECIDO,
                codigoOriginal = "http_${resposta.status.value}",
                detalhes = null,
                mensagemCrua = "Falha no envio da evidência (HTTP ${resposta.status.value})",
            )
        }
    }
}
