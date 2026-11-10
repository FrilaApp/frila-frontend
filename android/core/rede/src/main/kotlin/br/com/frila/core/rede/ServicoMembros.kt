package br.com.frila.core.rede

import io.ktor.client.request.get
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType

/** Estabelecimento e sua equipe: cadastro, múltiplos membros com papel administrador ou operador (contrato 0.2.73, RF02, RF21, US24). */
class ServicoMembros(private val provedorDeCliente: () -> ClienteSupabase) {
    constructor(cliente: ClienteSupabase) : this({ cliente })

    /** Lido a cada chamada: após `GestorClienteKtor.recriar()` o cliente anterior está fechado. */
    private val cliente: ClienteSupabase get() = provedorDeCliente()

    /**
     * `GET /rest/v1/rpc/meus_estabelecimentos`, ordenado por nome, com o `papel` de quem chama em
     * cada casa. Conta de profissional recebe `422 perfil_incompativel`.
     */
    suspend fun listarMeusEstabelecimentos(): List<EstabelecimentoDaContaDto> {
        val resposta = cliente.http.get(cliente.urlRpc("meus_estabelecimentos"))
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/cadastrar_estabelecimento`: cria o estabelecimento com o chamador como
     * administrador (RF02, UC10). Erros esperados: `409 documento_ja_cadastrado`, `422 campo_obrigatorio`
     * e `422 campo_invalido` (o campo em `details`), `422 perfil_incompativel` (conta de profissional,
     * RN25), `403` para conta suspensa.
     */
    suspend fun cadastrarEstabelecimento(estabelecimento: NovoEstabelecimentoDto): EstabelecimentoDto {
        val resposta = cliente.http.post(cliente.urlRpc("cadastrar_estabelecimento")) {
            contentType(ContentType.Application.Json)
            setBody(estabelecimento)
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/convidar_membro`. Só o administrador convida. Erros esperados:
     * `403 sem_permissao`, `404 nao_encontrado`, `422 campo_obrigatorio` (`papel`) e
     * `422 campo_invalido` (`email`).
     */
    suspend fun convidarMembro(estabelecimentoId: String, email: String, papel: String): ConviteMembroDto {
        val resposta = cliente.http.post(cliente.urlRpc("convidar_membro")) {
            contentType(ContentType.Application.Json)
            setBody(ConvidarMembroDto(estabelecimentoId = estabelecimentoId, email = email, papel = papel))
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/aceitar_convite_membro`. Exige conta de contratante. Erros esperados:
     * `422 perfil_incompativel` (conta de profissional) e `422 convite_invalido` (token inexistente,
     * já usado ou vencido).
     */
    suspend fun aceitarConviteMembro(token: String): MembroAdicionadoDto {
        val resposta = cliente.http.post(cliente.urlRpc("aceitar_convite_membro")) {
            contentType(ContentType.Application.Json)
            setBody(AceitarConviteMembroDto(token = token))
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/remover_membro`. Só o administrador remove. Erros esperados:
     * `403 sem_permissao`, `404 nao_encontrado` e `422 ultimo_administrador`.
     */
    suspend fun removerMembro(estabelecimentoId: String, membroId: String): MembroRemovidoDto {
        val resposta = cliente.http.post(cliente.urlRpc("remover_membro")) {
            contentType(ContentType.Application.Json)
            setBody(RemoverMembroDto(estabelecimentoId = estabelecimentoId, membroId = membroId))
        }
        return cliente.corpoOuErro(resposta)
    }

    /** `POST /rest/v1/rpc/transferir_administracao`. Só o administrador atual promove. Erros: `403 sem_permissao`, `404 nao_encontrado`. */
    suspend fun transferirAdministracao(estabelecimentoId: String, novoAdminId: String): AdministracaoTransferidaDto {
        val resposta = cliente.http.post(cliente.urlRpc("transferir_administracao")) {
            contentType(ContentType.Application.Json)
            setBody(TransferirAdministracaoDto(estabelecimentoId = estabelecimentoId, novoAdminId = novoAdminId))
        }
        return cliente.corpoOuErro(resposta)
    }
}
