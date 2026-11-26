package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.seguranca.ArmazenamentoDeDispositivo
import br.com.frila.core.seguranca.ArmazenamentoDeDispositivoEmMemoria
import io.ktor.client.request.post
import io.ktor.client.request.put
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import java.util.Base64
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/** Corpo legado de `PUT /auth/v1/user`: mantido apenas por compatibilidade interna. */
@Serializable
internal data class AtualizarSenhaDto(
    @SerialName("password") val password: String,
)

@Serializable
internal data class IniciarLoginSocialPkceDto(
    val provedor: String,
    val fluxo: String,
    val plataforma: String,
    @SerialName("code_challenge") val codeChallenge: String,
    @SerialName("redirect_to") val redirectTo: String,
)

@Serializable
data class InicioLoginSocialPkceDto(
    @SerialName("transacao_id") val transacaoId: String,
    @SerialName("url_autorizacao") val urlAutorizacao: String,
    @SerialName("expira_em") val expiraEm: String? = null,
)

@Serializable
internal data class ConcluirLoginSocialPkceDto(
    val provedor: String,
    val fluxo: String,
    val plataforma: String,
    @SerialName("transacao_id") val transacaoId: String,
    val codigo: String,
    @SerialName("code_verifier") val codeVerifier: String,
)

@Serializable
internal data class ConcluirLoginSocialIdTokenDto(
    val provedor: String,
    val fluxo: String,
    val plataforma: String,
    @SerialName("id_token") val idToken: String,
    val nonce: String,
)

@Serializable
data class RespostaLoginSocialDto(
    val sessao: SessaoDto,
    val provedor: String,
    @SerialName("precisa_definir_senha") val precisaDefinirSenha: Boolean = false,
)

sealed interface ResultadoEntradaComSenha {
    data class Autenticado(
        val sessao: SessaoDto,
        val precisaDefinirSenha: Boolean,
    ) : ResultadoEntradaComSenha

    data class DesafioOtp(
        val desafioId: String,
        val expiraEm: String?,
    ) : ResultadoEntradaComSenha
}

sealed interface OrigemConfirmacaoDispositivoOtp {
    data class LoginDispositivo(val desafioId: String, val email: String) : OrigemConfirmacaoDispositivoOtp
    data class Cadastro(val email: String) : OrigemConfirmacaoDispositivoOtp
    data class Recuperacao(val email: String) : OrigemConfirmacaoDispositivoOtp
}

data class ResultadoConfirmacaoDispositivoOtp(
    val sessao: SessaoDto,
    val precisaDefinirSenha: Boolean,
    val dispositivoLembrado: Boolean,
)

data class ResultadoReenvioDispositivoOtp(
    val ok: Boolean,
    val desafioId: String,
    val expiraEm: String?,
    val reenviarEmSegundos: Int,
)

/**
 * Autenticação no Supabase (contrato 0.2.112):
 * - Criação de conta / OTP: `/auth/v1/otp` (`create_user: true`) + `/functions/v1/confirmar-dispositivo-otp`
 * - Recuperação / migração de conta legada OTP-only: `/auth/v1/otp` (`create_user: false`) + `/functions/v1/confirmar-dispositivo-otp`
 * - Login rotineiro por senha: `/functions/v1/autenticar-senha` (`plataforma: "android"`, `device_token`)
 * - Reenvio no desafio de dispositivo: `/functions/v1/reenviar-dispositivo-otp`
 * - Definição/atualização de senha na sessão ativa (mesmo `auth.uid`): `/functions/v1/definir-senha`
 * - Revogação global de dispositivos: `/functions/v1/revogar-dispositivos`
 * - Estado de autenticação: `/rest/v1/rpc/estado_autenticacao`
 * - Modo demonstração da Google Play: `/functions/v1/entrar-demonstracao`
 */
class ServicoAutenticacao(
    private val provedorDeCliente: () -> ClienteSupabase,
    private val armazenamentoDeDispositivo: ArmazenamentoDeDispositivo = ArmazenamentoDeDispositivoEmMemoria(),
) {
    constructor(
        cliente: ClienteSupabase,
        armazenamentoDeDispositivo: ArmazenamentoDeDispositivo = ArmazenamentoDeDispositivoEmMemoria(),
    ) : this({ cliente }, armazenamentoDeDispositivo)

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

    /** Login rotineiro por e-mail e senha via Edge Function (`POST /functions/v1/autenticar-senha`). */
    suspend fun entrarComSenha(email: String, senha: String): ResultadoEntradaComSenha {
        val deviceToken = armazenamentoDeDispositivo.obterToken(email)
        val resposta = cliente.http.post(cliente.urlCompleta("/functions/v1/autenticar-senha")) {
            contentType(ContentType.Application.Json)
            setBody(
                AutenticarSenhaRequisicaoDto(
                    email = email,
                    senha = senha,
                    plataforma = "android",
                    deviceToken = deviceToken,
                ),
            )
        }
        val dto = cliente.corpoOuErro<AutenticarSenhaRespostaDto>(resposta)
        return when (dto.status) {
            "autenticado" -> {
                val sessao = dto.sessao ?: throw ErroDaApi(CodigoErroAPI.RESPOSTA_INVALIDA, "resposta_invalida", null, "Sessão ausente")
                ResultadoEntradaComSenha.Autenticado(
                    sessao = sessao,
                    precisaDefinirSenha = dto.precisaDefinirSenha ?: false,
                )
            }
            "desafio_otp" -> {
                if (dto.descartarDeviceToken == true) {
                    armazenamentoDeDispositivo.removerToken(email)
                }
                val desafioId = dto.desafioId?.takeIf { it.isNotBlank() }
                    ?: throw ErroDaApi(CodigoErroAPI.RESPOSTA_INVALIDA, "resposta_invalida", null, "Desafio ausente")
                ResultadoEntradaComSenha.DesafioOtp(
                    desafioId = desafioId,
                    expiraEm = dto.expiraEm,
                )
            }
            else -> throw ErroDaApi(CodigoErroAPI.RESPOSTA_INVALIDA, "resposta_invalida", null, "Status inválido")
        }
    }

    /** Confirma o código OTP no endpoint server-side (`POST /functions/v1/confirmar-dispositivo-otp`). */
    suspend fun confirmarDispositivoOtp(
        origem: OrigemConfirmacaoDispositivoOtp,
        codigo: String,
        lembrarDispositivo: Boolean,
    ): ResultadoConfirmacaoDispositivoOtp {
        val (requisicao, emailDaConta) = when (origem) {
            is OrigemConfirmacaoDispositivoOtp.LoginDispositivo -> ConfirmarDispositivoOtpRequisicaoDto(
                tipo = "login_dispositivo",
                desafioId = origem.desafioId,
                email = null,
                codigo = codigo,
                plataforma = "android",
                lembrarDispositivo = lembrarDispositivo,
            ) to origem.email
            is OrigemConfirmacaoDispositivoOtp.Cadastro -> ConfirmarDispositivoOtpRequisicaoDto(
                tipo = "cadastro",
                desafioId = null,
                email = origem.email,
                codigo = codigo,
                plataforma = "android",
                lembrarDispositivo = lembrarDispositivo,
            ) to origem.email
            is OrigemConfirmacaoDispositivoOtp.Recuperacao -> ConfirmarDispositivoOtpRequisicaoDto(
                tipo = "recuperacao",
                desafioId = null,
                email = origem.email,
                codigo = codigo,
                plataforma = "android",
                lembrarDispositivo = lembrarDispositivo,
            ) to origem.email
        }
        val resposta = cliente.http.post(cliente.urlCompleta("/functions/v1/confirmar-dispositivo-otp")) {
            contentType(ContentType.Application.Json)
            setBody(requisicao)
        }
        val dto = cliente.corpoOuErro<ConfirmarDispositivoOtpRespostaDto>(resposta)
        val tokenRecebido = dto.deviceToken?.takeIf { it.isNotBlank() }
        val dispositivoLembrado = if (lembrarDispositivo && tokenRecebido != null && emailDaConta.isNotBlank()) {
            armazenamentoDeDispositivo.salvarToken(emailDaConta, tokenRecebido)
            true
        } else {
            false
        }
        return ResultadoConfirmacaoDispositivoOtp(
            sessao = dto.sessao,
            precisaDefinirSenha = dto.precisaDefinirSenha ?: false,
            dispositivoLembrado = dispositivoLembrado,
        )
    }

    /** Reenvia o OTP mantendo o mesmo desafio (`POST /functions/v1/reenviar-dispositivo-otp`). */
    suspend fun reenviarDispositivoOtp(desafioId: String): ResultadoReenvioDispositivoOtp {
        val resposta = cliente.http.post(cliente.urlCompleta("/functions/v1/reenviar-dispositivo-otp")) {
            contentType(ContentType.Application.Json)
            setBody(ReenviarDispositivoOtpRequisicaoDto(desafioId = desafioId))
        }
        val dto = cliente.corpoOuErro<ReenviarDispositivoOtpRespostaDto>(resposta)
        return ResultadoReenvioDispositivoOtp(
            ok = dto.ok,
            desafioId = dto.desafioId,
            expiraEm = dto.expiraEm,
            reenviarEmSegundos = (dto.reenviarEmSegundos ?: 60).coerceAtLeast(1),
        )
    }

    /**
     * Define ou atualiza a senha na sessão autenticada atual (`POST /functions/v1/definir-senha`),
     * preservando rigorosamente o mesmo `auth.uid`.
     */
    suspend fun definirSenha(
        novaSenha: String,
        manterDispositivoAtual: Boolean = false,
        emailAtual: String? = null,
        refreshToken: String? = null,
    ): DefinirSenhaRespostaDto {
        val emailNormalizado = emailAtual?.trim()?.lowercase()?.takeIf { it.isNotBlank() }
        if (manterDispositivoAtual && emailNormalizado == null) {
            // Falha fechado: não preserva dispositivo atual sem identificar a conta da sessão.
            throw ErroDaApi(
                CodigoErroAPI.NAO_AUTENTICADO,
                "nao_autenticado",
                null,
                "E-mail da sessão ausente para preservar o dispositivo atual",
            )
        }
        val deviceTokenAtual = if (manterDispositivoAtual && emailNormalizado != null) {
            armazenamentoDeDispositivo.obterToken(emailNormalizado)
        } else {
            null
        }
        val resposta = cliente.http.post(cliente.urlCompleta("/functions/v1/definir-senha")) {
            contentType(ContentType.Application.Json)
            setBody(
                DefinirSenhaRequisicaoDto(
                    novaSenha = novaSenha,
                    manterDispositivoAtual = manterDispositivoAtual,
                    deviceTokenAtual = deviceTokenAtual,
                    refreshToken = refreshToken,
                ),
            )
        }
        val dto = cliente.corpoOuErro<DefinirSenhaRespostaDto>(resposta)
        if (!manterDispositivoAtual && emailNormalizado != null) {
            // Remove apenas o token da conta atual; nunca apaga tokens de outras contas neste aparelho.
            armazenamentoDeDispositivo.removerToken(emailNormalizado)
        }
        return dto
    }

    /** Compatibilidade: mantém assinatura legada delegando para `definirSenha`. */
    suspend fun atualizarSenha(novaSenha: String) {
        definirSenha(novaSenha = novaSenha, manterDispositivoAtual = false)
    }

    /** Revoga todos os dispositivos confiáveis da conta (`POST /functions/v1/revogar-dispositivos`). */
    suspend fun revogarDispositivos(): Int {
        val resposta = cliente.http.post(cliente.urlCompleta("/functions/v1/revogar-dispositivos")) {
            contentType(ContentType.Application.Json)
            setBody(RevogarDispositivosRequisicaoDto())
        }
        val dto = cliente.corpoOuErro<RevogarDispositivosRespostaDto>(resposta)
        armazenamentoDeDispositivo.removerTodos()
        return dto.dispositivosRevogados
    }

    /** Consulta o estado autoritativo de autenticação (`POST /rest/v1/rpc/estado_autenticacao`). */
    suspend fun estadoAutenticacao(): EstadoAutenticacaoDto {
        val resposta = cliente.http.post(cliente.urlRpc("estado_autenticacao")) {
            contentType(ContentType.Application.Json)
            setBody(RevogarDispositivosRequisicaoDto())
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * Inicia transação OAuth PKCE S256 server-side via `POST /functions/v1/autenticar-social`
     * (`fluxo = "iniciar_pkce"`, contrato 0.2.117).
     */
    suspend fun iniciarLoginSocialPkce(
        provedor: ProvedorSocial,
        codeChallenge: String,
        redirectTo: String = SegurancaOAuthSocial.URL_CALLBACK,
    ): InicioLoginSocialPkceDto {
        if (codeChallenge.length != 43) {
            throw ErroDaApi(
                CodigoErroAPI.CAMPO_INVALIDO,
                "callback_invalido",
                null,
                "code_challenge PKCE inválido",
            )
        }
        val resposta = cliente.http.post(cliente.urlCompleta("/functions/v1/autenticar-social")) {
            contentType(ContentType.Application.Json)
            setBody(
                IniciarLoginSocialPkceDto(
                    provedor = provedor.valor,
                    fluxo = "iniciar_pkce",
                    plataforma = "android",
                    codeChallenge = codeChallenge,
                    redirectTo = redirectTo,
                ),
            )
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * Conclui login social PKCE via `POST /functions/v1/autenticar-social` (`fluxo = "pkce"`, contrato 0.2.117),
     * validando `auth.flow_state`, gravando `privado.sessoes_verificadas` e renovando JWT com `dispositivo_verificado=true`.
     * Nunca registra código, verifier ou tokens.
     */
    suspend fun concluirLoginSocialPkce(
        provedor: ProvedorSocial,
        transacaoId: String,
        codigo: String,
        verifier: String,
    ): RespostaLoginSocialDto {
        if (transacaoId.isBlank() ||
            !SegurancaOAuthSocial.ehCodigoValido(codigo) ||
            !SegurancaOAuthSocial.ehVerifierValido(verifier)
        ) {
            throw ErroDaApi(
                CodigoErroAPI.CAMPO_INVALIDO,
                "callback_invalido",
                null,
                "Transação, código ou verifier PKCE inválido",
            )
        }
        val resposta = cliente.http.post(cliente.urlCompleta("/functions/v1/autenticar-social")) {
            contentType(ContentType.Application.Json)
            setBody(
                ConcluirLoginSocialPkceDto(
                    provedor = provedor.valor,
                    fluxo = "pkce",
                    plataforma = "android",
                    transacaoId = transacaoId,
                    codigo = codigo,
                    codeVerifier = verifier,
                ),
            )
        }
        return cliente.corpoOuErro(resposta)
    }

    /** Conclui login social via `id_token` nativo + `nonce` bruto em `POST /functions/v1/autenticar-social`. */
    suspend fun concluirLoginSocialIdToken(
        provedor: ProvedorSocial,
        idToken: String,
        nonce: String,
    ): RespostaLoginSocialDto {
        val tokenLimpo = idToken.trim()
        val nonceLimpo = nonce.trim()
        if (tokenLimpo.length < 16 || tokenLimpo.any(Char::isWhitespace) || nonceLimpo.length < 16) {
            throw ErroDaApi(
                CodigoErroAPI.CAMPO_INVALIDO,
                "callback_invalido",
                null,
                "id_token ou nonce inválido",
            )
        }
        val resposta = cliente.http.post(cliente.urlCompleta("/functions/v1/autenticar-social")) {
            contentType(ContentType.Application.Json)
            setBody(
                ConcluirLoginSocialIdTokenDto(
                    provedor = provedor.valor,
                    fluxo = "id_token",
                    plataforma = "android",
                    idToken = tokenLimpo,
                    nonce = nonceLimpo,
                ),
            )
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

    companion object {
        fun extrairEmailDoJwt(jwt: String): String? = runCatching {
            val partes = jwt.split('.')
            if (partes.size < 2) return null
            val payloadJson = String(Base64.getUrlDecoder().decode(partes[1]), Charsets.UTF_8)
            Json.parseToJsonElement(payloadJson).jsonObject["email"]?.jsonPrimitive?.content
                ?.trim()?.lowercase()?.takeIf { it.isNotBlank() }
        }.getOrNull()
    }
}
