package br.com.frila.core.rede

import io.ktor.client.request.post
import io.ktor.client.request.put
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Corpo de `POST /auth/v1/token?grant_type=password`: entrada com e-mail e senha (Supabase Auth / GoTrue). */
@Serializable
internal data class EntrarComSenhaDto(
    @SerialName("email") val email: String,
    @SerialName("password") val password: String,
)

/** Corpo de `PUT /auth/v1/user`: definição/atualização de senha na sessão ativa (preserva `auth.uid`). */
@Serializable
internal data class AtualizarSenhaDto(
    @SerialName("password") val password: String,
)

/**
 * Autenticação no Supabase Auth (`docs/android/04-seguranca-e-sessao.md`):
 * - Criação de conta / OTP: `/auth/v1/otp` (`create_user: true`) + `/auth/v1/verify` (`type: email`)
 * - Recuperação / migração de conta legada OTP-only: `/auth/v1/otp` (`create_user: false`) + `/auth/v1/verify`
 * - Login rotineiro por senha: `/auth/v1/token?grant_type=password`
 * - Definição/atualização de senha na sessão ativa (mesmo `auth.uid`): `PUT /auth/v1/user`
 * - Modo demonstração da Google Play: `/functions/v1/entrar-demonstracao`
 */
class ServicoAutenticacao(private val provedorDeCliente: () -> ClienteSupabase) {
    constructor(cliente: ClienteSupabase) : this({ cliente })

    /** Lido a cada chamada: após `GestorClienteKtor.recriar()` o cliente anterior está fechado. */
    private val cliente: ClienteSupabase get() = provedorDeCliente()

    /** Solicita OTP para criação de conta / entrada com permissão de criar usuário (`create_user: true`). */
    suspend fun solicitarOtp(email: String) {
        val resposta = cliente.http.post(cliente.urlCompleta("/auth/v1/otp")) {
            contentType(ContentType.Application.Json)
            setBody(EntrarOtpDto(email = email, createUser = true))
        }
        cliente.corpoOuErro<Unit>(resposta)
    }

    /**
     * Solicita OTP exclusivamente para recuperação/migração de conta existente (`create_user: false`).
     * Nunca cria usuário novo no Supabase Auth.
     */
    suspend fun solicitarOtpRecuperacao(email: String) {
        val resposta = cliente.http.post(cliente.urlCompleta("/auth/v1/otp")) {
            contentType(ContentType.Application.Json)
            setBody(EntrarOtpDto(email = email, createUser = false))
        }
        cliente.corpoOuErro<Unit>(resposta)
    }

    suspend fun verificarOtp(email: String, codigo: String): SessaoDto {
        val resposta = cliente.http.post(cliente.urlCompleta("/auth/v1/verify")) {
            contentType(ContentType.Application.Json)
            setBody(VerificarOtpDto(email = email, codigo = codigo))
        }
        return cliente.corpoOuErro(resposta)
    }

    /** Login rotineiro por e-mail e senha (`POST /auth/v1/token?grant_type=password`). */
    suspend fun entrarComSenha(email: String, senha: String): SessaoDto {
        val resposta = cliente.http.post(cliente.urlCompleta("/auth/v1/token?grant_type=password")) {
            contentType(ContentType.Application.Json)
            setBody(EntrarComSenhaDto(email = email, password = senha))
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * Define ou atualiza a senha na sessão autenticada atual (`PUT /auth/v1/user`),
     * preservando rigorosamente o mesmo `auth.uid`.
     */
    suspend fun atualizarSenha(novaSenha: String) {
        val resposta = cliente.http.put(cliente.urlCompleta("/auth/v1/user")) {
            contentType(ContentType.Application.Json)
            setBody(AtualizarSenhaDto(password = novaSenha))
        }
        cliente.corpoOuErro<Unit>(resposta)
    }

    /**
     * Modo demonstração da Google Play (`docs/android/04-seguranca-e-sessao.md` §3):
     * permite que o revisor da Play Store entre sem acesso a caixa de e-mail real.
     * `codigo` aqui é o código fixo de demonstração, não o OTP de 6 dígitos do fluxo normal.
     */
    suspend fun entrarDemonstracao(email: String, codigo: String): SessaoDto {
        val resposta = cliente.http.post(cliente.urlCompleta("/functions/v1/entrar-demonstracao")) {
            contentType(ContentType.Application.Json)
            setBody(EntrarDemonstracaoDto(email = email, codigo = codigo))
        }
        return cliente.corpoOuErro(resposta)
    }
}
