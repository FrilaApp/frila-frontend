package br.com.frila.core.rede

import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType

/**
 * Fluxo OTP por e-mail (`docs/android/04-seguranca-e-sessao.md` §1):
 * solicitação em `/auth/v1/otp`, verificação em `/auth/v1/verify` (type: email).
 */
class ServicoAutenticacao(private val cliente: ClienteSupabase) {

    suspend fun solicitarOtp(email: String) {
        val resposta = cliente.http.post(cliente.urlCompleta("/auth/v1/otp")) {
            contentType(ContentType.Application.Json)
            setBody(EntrarOtpDto(email = email))
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
