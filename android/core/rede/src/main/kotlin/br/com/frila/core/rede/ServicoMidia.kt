package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import io.ktor.client.request.post
import io.ktor.client.request.put
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import kotlinx.coroutines.CancellationException

/**
 * Foto de perfil do chamador (RN14, RN15; contrato 0.2.54 a 0.2.82). O fluxo é: [solicitarUploadMidia] → [enviarFoto] →
 * [confirmarUploadMidia]; depois [minhasMidias] mostra o estado (`em_analise`, `aprovada`, `recusada`...). Cada chamada devolve o DTO e
 * lança [ErroDaApi] com o `codigo`, o `codigoOriginal` e os `detalhes` do servidor. Nenhuma é repetida sozinha (todas são POST).
 */
class ServicoMidia(private val provedorDeCliente: () -> ClienteSupabase) {
    constructor(cliente: ClienteSupabase) : this({ cliente })

    /** Lido a cada chamada: após `GestorClienteKtor.recriar()` o cliente anterior está fechado. */
    private val cliente: ClienteSupabase get() = provedorDeCliente()

    /**
     * `POST /rest/v1/rpc/solicitar_upload_midia`. Cria a mídia em `enviando` e devolve a URL de envio de uso único, válida por 2 h.
     * O app envia JPEG sem EXIF, lado maior até 1600 px e até 5 MB; [bytes] é o tamanho do arquivo. Só `foto_perfil` por ora.
     * [estabelecimentoId] só para a foto ou o logo da casa. Erros esperados: `401 nao_autenticado`, `403 sem_permissao`
     * (`recurso_desligado` ou `conta_suspensa` em `detalhes`), `422 midia_invalida` (`formato`, `tamanho` ou `tipo_indisponivel`).
     */
    suspend fun solicitarUploadMidia(
        mime: String,
        bytes: Int,
        tipo: String = "foto_perfil",
        estabelecimentoId: String? = null,
    ): UploadMidiaDto {
        val resposta = cliente.http.post(cliente.urlRpc("solicitar_upload_midia")) {
            contentType(ContentType.Application.Json)
            setBody(SolicitarUploadMidiaDto(tipo = tipo, mime = mime, bytes = bytes, estabelecimentoId = estabelecimentoId))
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `PUT` do JPEG na [urlDeUpload] (Edge Function `enviar-midia`), por um cliente sem `apikey` nem `Authorization`: o token da URL,
     * de **uso único**, é a única credencial. 2xx quer dizer gravado. A URL leva o token, então ela e o corpo da resposta **nunca** entram
     * em log nem em texto de erro: qualquer outra resposta vira [ErroDaApi] só com `http_<status>`, e falha de rede vira `sem_rede` sem
     * a mensagem do Ktor (que cita a URL). Nunca repete sozinho: para tentar de novo, peça outra URL com [solicitarUploadMidia].
     */
    suspend fun enviarFoto(urlDeUpload: String, jpeg: ByteArray) {
        val resposta = try {
            cliente.httpSemCredenciais.put(urlDeUpload) {
                contentType(ContentType.Image.JPEG)
                setBody(jpeg)
            }
        } catch (erro: CancellationException) {
            throw erro
        } catch (erro: Exception) {
            // A mensagem do Ktor cita a URL inteira, com o token: não vai adiante, nem como causa.
            throw ErroDaApi(CodigoErroAPI.SEM_REDE, "sem_rede", null, "Falha de rede no envio da foto")
        }
        if (!resposta.status.isSuccess()) {
            throw ErroDaApi(
                codigo = CodigoErroAPI.DESCONHECIDO,
                codigoOriginal = "http_${resposta.status.value}",
                detalhes = null,
                mensagemCrua = "Falha no envio da foto (HTTP ${resposta.status.value})",
            )
        }
    }

    /**
     * `POST /rest/v1/rpc/confirmar_upload_midia`: confere que o arquivo chegou, o tipo e a ausência de EXIF; passou, a mídia vai a
     * `em_analise` (a análise é enfileirada, a resposta não a espera). Idempotente. Erros esperados: `404 nao_encontrado`,
     * `422 evidencia_incompleta`, `422 midia_invalida` (`formato` ou `metadados`), `403 sem_permissao`.
     */
    suspend fun confirmarUploadMidia(midiaId: String): MidiaDto {
        val resposta = cliente.http.post(cliente.urlRpc("confirmar_upload_midia")) {
            contentType(ContentType.Application.Json)
            setBody(ConfirmarUploadMidiaDto(midiaId = midiaId))
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/remover_midia`: a mídia vai a `removida` na hora. Idempotente, e funciona mesmo com a chave de foto desligada:
     * remover o próprio dado nunca depende do interruptor. Erros esperados: `404 nao_encontrado`, `403 sem_permissao`.
     */
    suspend fun removerMidia(midiaId: String): MidiaDto {
        val resposta = cliente.http.post(cliente.urlRpc("remover_midia")) {
            contentType(ContentType.Application.Json)
            setBody(RemoverMidiaDto(midiaId = midiaId))
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/pedir_nova_analise_midia`: uma vez por foto `recusada` ou `nao_publicada`, e só enquanto o arquivo existe
     * (`pode_pedir_nova_analise`). Erros esperados: `409 midia_indisponivel` (`estado_invalido` ou `expurgada`: o app orienta enviar
     * outra foto), `404 nao_encontrado`, `403 sem_permissao`.
     */
    suspend fun pedirNovaAnaliseMidia(midiaId: String): MidiaDto {
        val resposta = cliente.http.post(cliente.urlRpc("pedir_nova_analise_midia")) {
            contentType(ContentType.Application.Json)
            setBody(PedirNovaAnaliseMidiaDto(midiaId = midiaId))
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `minhas_midias`: todas as mídias do chamador, em qualquer estado. Vai por `POST` com corpo vazio porque só assim o servidor devolve
     * a `url` (link de leitura de 1 h) da foto `aprovada`; por `GET` ela vem ausente (0.2.82). Também funciona com a chave de foto desligada.
     * Erros esperados: `401 nao_autenticado`, `403 sem_permissao`.
     */
    suspend fun minhasMidias(): List<MidiaDto> {
        val resposta = cliente.http.post(cliente.urlRpc("minhas_midias")) {
            contentType(ContentType.Application.Json)
            setBody("{}")
        }
        return cliente.corpoOuErro(resposta)
    }
}
