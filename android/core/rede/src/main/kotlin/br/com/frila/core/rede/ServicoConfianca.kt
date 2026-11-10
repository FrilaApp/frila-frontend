package br.com.frila.core.rede

import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType

/** Denúncia, bloqueio e saída da equipe de confiança (RF26/RF18/RN16/RN13, UC17/UC11). */
class ServicoConfianca(private val provedorDeCliente: () -> ClienteSupabase) {
    constructor(cliente: ClienteSupabase) : this({ cliente })

    /** Lido a cada chamada: após `GestorClienteKtor.recriar()` o cliente anterior está fechado. */
    private val cliente: ClienteSupabase get() = provedorDeCliente()

    /**
     * `POST /rest/v1/rpc/denunciar`. Idempotente pela `chave`. Erros esperados: `422 campo_obrigatorio`
     * e `422 campo_invalido` (o campo em `details`, inclusive `chamada_id` inexistente ou de
     * terceiros), `404 nao_encontrado`, `403 conta_suspensa`.
     */
    suspend fun denunciar(denuncia: DenunciarDto): ProtocoloDto {
        val resposta = cliente.http.post(cliente.urlRpc("denunciar")) {
            contentType(ContentType.Application.Json)
            setBody(denuncia)
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/bloquear`. Imediato e idempotente; vale nos dois sentidos e, quando uma
     * das partes é membro de estabelecimento, para o estabelecimento inteiro. Erros esperados:
     * `422 campo_invalido` (`details`: `alvo_tipo`, `alvo_id` ou tentativa de bloquear a si mesmo),
     * `404 nao_encontrado`, `403 conta_suspensa`.
     */
    suspend fun bloquear(alvoTipo: String, alvoId: String): BloqueioDto {
        val resposta = cliente.http.post(cliente.urlRpc("bloquear")) {
            contentType(ContentType.Application.Json)
            setBody(BloquearDto(alvoTipo = alvoTipo, alvoId = alvoId))
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/sair_da_equipe` (0.2.72). O profissional sai por vontade própria da
     * equipe de confiança de um estabelecimento, sem penalidade nem aviso a ele. Erros esperados:
     * `403 sem_permissao` (chamador não é profissional), `422 campo_invalido` (`details:
     * estabelecimento_id`, quando não faz parte da equipe daquela casa).
     */
    suspend fun sairDaEquipe(estabelecimentoId: String) {
        val resposta = cliente.http.post(cliente.urlRpc("sair_da_equipe")) {
            contentType(ContentType.Application.Json)
            setBody(SairDaEquipeDto(estabelecimentoId = estabelecimentoId))
        }
        cliente.corpoOuErro<Unit>(resposta)
    }
}
