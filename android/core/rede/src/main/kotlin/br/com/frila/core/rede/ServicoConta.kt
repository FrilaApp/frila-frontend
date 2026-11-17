package br.com.frila.core.rede

import io.ktor.client.request.get
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

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
