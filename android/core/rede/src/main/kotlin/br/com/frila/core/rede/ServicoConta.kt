package br.com.frila.core.rede

import io.ktor.client.request.get
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject

/**
 * Conta do chamador (`GET /rest/v1/rpc/minha_conta`, schema `Usuario`). `perfil` é `profissional` ou
 * `contratante` e não muda depois (RN25); fica como texto para um valor novo do servidor não derrubar a leitura.
 */
@Serializable
data class UsuarioDto(
    @SerialName("id") val id: String,
    @SerialName("perfil") val perfil: String,
    @SerialName("nome") val nome: String,
    @SerialName("telefone") val telefone: String,
    @SerialName("email") val email: String,
    @SerialName("nascimento") val nascimento: String,
    @SerialName("estado") val estado: String,
)

/** Quem é a conta que acabou de entrar (RF01, UC09, UC10). */
class ServicoConta(private val provedorDeCliente: () -> ClienteSupabase) {
    constructor(cliente: ClienteSupabase) : this({ cliente })

    /** Lido a cada chamada: após `GestorClienteKtor.recriar()` o cliente anterior está fechado. */
    private val cliente: ClienteSupabase get() = provedorDeCliente()

    /**
     * `situacao_da_conta` (RF24, RN13): o estado da conta e, se suspensa, o motivo, a data e o protocolo da
     * contestação já aberta. Vai em POST com corpo vazio, como no iOS. Conta suspensa lê normalmente: é a tela
     * "Conta suspensa" que chama. Erro esperado: `401 nao_autenticado`.
     */
    suspend fun situacaoDaConta(): SituacaoDaContaDto {
        val resposta = cliente.http.post(cliente.urlRpc("situacao_da_conta")) {
            contentType(ContentType.Application.Json)
            setBody(JsonObject(emptyMap()))
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/contestar_suspensao` (RN13): vai à Equipe Frila, com resposta em até 5 dias úteis. Uma
     * contestação por suspensão pelo app (0.2.36). Erros esperados: `409 contestacao_ja_aberta` (em análise ou já
     * respondida), `422 sem_suspensao_ativa`, `422 campo_obrigatorio` (relato vazio) e `422 campo_invalido` (menos
     * de 10 caracteres), os dois com `details: relato`, `401 nao_autenticado`.
     */
    suspend fun contestarSuspensao(relato: String): ProtocoloDto {
        val resposta = cliente.http.post(cliente.urlRpc("contestar_suspensao")) {
            contentType(ContentType.Application.Json)
            setBody(ContestarSuspensaoDto(relato = relato))
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/pedir_revisao_despacho` (RF27): o "Contestar" da tela "Por que recebo vagas". Uma
     * contestação por despacho pelo app (0.2.37). Erros esperados: `409 contestacao_ja_aberta`,
     * `422 campo_obrigatorio` e `422 campo_invalido` (`details: relato`), `403 sem_permissao`
     * (`details: conta_suspensa`), `401 nao_autenticado`.
     */
    suspend fun pedirRevisaoDespacho(relato: String): ProtocoloDto {
        val resposta = cliente.http.post(cliente.urlRpc("pedir_revisao_despacho")) {
            contentType(ContentType.Application.Json)
            setBody(PedirRevisaoDespachoDto(relato = relato))
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `GET /rest/v1/rpc/minha_conta`. Depois do código existe sessão e pode não existir conta:
     * `404 nao_encontrado` é como o app sabe que a pessoa precisa do cadastro.
     */
    suspend fun minhaConta(): UsuarioDto {
        val resposta = cliente.http.get(cliente.urlRpc("minha_conta"))
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/criar_conta`, autenticado pela sessão do código. Recusas: `422`
     * (`campo_obrigatorio`, `campo_invalido`, `menor_de_idade`), `409` (`conta_existente`,
     * `perfil_ja_existe`) e `401`. O perfil gravado aqui não muda depois (RN25).
     */
    suspend fun criarConta(dados: CriarContaDto): UsuarioDto {
        val resposta = cliente.http.post(cliente.urlRpc("criar_conta")) {
            contentType(ContentType.Application.Json)
            setBody(dados)
        }
        return cliente.corpoOuErro(resposta)
    }
}
