import Foundation
import FrilaDominio
import Supabase

extension SupabaseApiCliente {
    /// Habilitado apenas em DEBUG/FRILA_BETA até concluir prova DEV e configuração de release/entitlements.
    public var suportaLoginSocial: Bool {
        #if DEBUG || FRILA_BETA
        true
        #else
        false
        #endif
    }

    /// Conclui Sign in with Apple nativo via Edge Function `POST /functions/v1/autenticar-social`
    /// (`fluxo: "id_token"`, contrato 0.2.117), gravando `privado.sessoes_verificadas`, renovando JWT
    /// com `dispositivo_verificado = true` e aplicando a sessão no Keychain via `cliente.auth.setSession`.
    /// Serializado na `filaDeSessao`; nunca registra token ou nonce em log.
    public func entrarComApple(idToken: String, nonce: String) async throws -> ResultadoEntradaSocial {
        let tokenLimpo = idToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let nonceLimpo = nonce.trimmingCharacters(in: .whitespacesAndNewlines)
        guard tokenLimpo.count >= 16, !tokenLimpo.contains(where: \.isWhitespace),
              nonceLimpo.count >= 16
        else {
            throw ErroEntradaSocial.callbackInvalido
        }

        let payload = RequisicaoSocialIdToken(
            provedor: ProvedorSocial.apple.rawValue,
            fluxo: "id_token",
            plataforma: "ios",
            idToken: tokenLimpo,
            nonce: nonceLimpo
        )
        return try await executarConclusaoSocial(payload: payload, provedorEsperado: .apple)
    }

    /// Inicia transação OAuth PKCE server-side via `POST /functions/v1/autenticar-social`
    /// (`fluxo: "iniciar_pkce"`, contrato 0.2.117).
    public func iniciarLoginSocialPKCE(
        provedor: ProvedorSocial,
        redirectTo: URL,
        codeChallenge: String
    ) async throws -> InicioOAuthPKCE {
        guard codeChallenge.count == 43 else {
            throw ErroEntradaSocial.callbackInvalido
        }
        let payload = RequisicaoSocialIniciarPKCE(
            provedor: provedor.rawValue,
            fluxo: "iniciar_pkce",
            plataforma: "ios",
            codeChallenge: codeChallenge,
            redirectTo: redirectTo.absoluteString
        )
        do {
            let (dados, status) = try await enviarRequisicaoAutenticarSocial(payload: payload)
            guard (200...299).contains(status) else {
                throw Self.classificarErroHttpSocial(status: status, dados: dados)
            }
            let dto = try JSONDecoder().decode(RespostaInicioPKCE.self, from: dados)
            guard !dto.transacaoId.isEmpty, let url = URL(string: dto.urlAutorizacao) else {
                throw ErroEntradaSocial.provedorIndisponivel
            }
            return InicioOAuthPKCE(transacaoID: dto.transacaoId, urlAutorizacao: url)
        } catch is CancellationError {
            throw CancellationError()
        } catch let erroSocial as ErroEntradaSocial {
            throw erroSocial
        } catch is URLError {
            throw ErroEntradaSocial.rede
        } catch {
            throw ErroEntradaSocial.provedorIndisponivel
        }
    }

    /// Conclui OAuth PKCE via `POST /functions/v1/autenticar-social` (`fluxo: "pkce"`, contrato 0.2.117)
    /// com prova autoritativa em `auth.flow_state`, gravação de `privado.sessoes_verificadas` e renovação de JWT.
    public func concluirLoginSocialPKCE(
        provedor: ProvedorSocial,
        transacaoID: String,
        codigo: String,
        verifier: String
    ) async throws -> ResultadoEntradaSocial {
        guard !transacaoID.isEmpty,
              SegurancaOAuthSocial.ehVerifierPKCEValido(verifier),
              codigo.count >= 4, codigo.count <= 512
        else {
            throw ErroEntradaSocial.callbackInvalido
        }

        let payload = RequisicaoSocialPKCE(
            provedor: provedor.rawValue,
            fluxo: "pkce",
            plataforma: "ios",
            transacaoId: transacaoID,
            codigo: codigo,
            codeVerifier: verifier
        )
        return try await executarConclusaoSocial(payload: payload, provedorEsperado: provedor)
    }

    private func executarConclusaoSocial<T: Encodable & Sendable>(
        payload: T,
        provedorEsperado: ProvedorSocial
    ) async throws -> ResultadoEntradaSocial {
        do {
            return try await filaDeSessao.executar { [self] in
                try Task.checkCancellation()
                let (dados, status) = try await enviarRequisicaoAutenticarSocial(payload: payload)
                guard (200...299).contains(status) else {
                    throw Self.classificarErroHttpSocial(status: status, dados: dados)
                }
                let resposta = try JSONDecoder().decode(RespostaConclusaoSocial.self, from: dados)
                guard !resposta.sessao.accessToken.isEmpty, !resposta.sessao.refreshToken.isEmpty else {
                    throw ErroEntradaSocial.provedorIndisponivel
                }
                _ = try await cliente.auth.setSession(
                    accessToken: resposta.sessao.accessToken,
                    refreshToken: resposta.sessao.refreshToken
                )
                return ResultadoEntradaSocial(
                    provedor: provedorEsperado,
                    email: resposta.sessao.user?.email,
                    nomeSugerido: nil,
                    precisaDefinirSenha: resposta.precisaDefinirSenha
                )
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let erroSocial as ErroEntradaSocial {
            throw erroSocial
        } catch is URLError {
            throw ErroEntradaSocial.rede
        } catch {
            throw ErroEntradaSocial.provedorIndisponivel
        }
    }

    private func enviarRequisicaoAutenticarSocial<T: Encodable>(payload: T) async throws -> (Data, Int) {
        let urlEndpoint = urlBase.appendingPathComponent("functions/v1/autenticar-social")
        var req = URLRequest(url: urlEndpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(chavePublicavel, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(chavePublicavel)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(payload)

        let (dados, resposta) = try await sessaoHTTP.data(for: req)
        guard let http = resposta as? HTTPURLResponse else {
            throw ErroEntradaSocial.provedorIndisponivel
        }
        return (dados, http.statusCode)
    }

    static func classificarErroHttpSocial(status: Int, dados: Data) -> ErroEntradaSocial {
        if status == 429 { return .limiteExcedido }
        if status == 410 { return .callbackInvalido }
        if let json = try? JSONSerialization.jsonObject(with: dados) as? [String: Any] {
            let codigo = (json["code"] as? String ?? json["error_code"] as? String ?? json["error"] as? String ?? "")
            let msg = (json["msg"] as? String ?? json["error_description"] as? String ?? "")
            let combinado = "\(codigo) \(msg)".lowercased()
            if combinado.contains("conflito_identidade")
                || combinado.contains("identity_already_exists")
                || combinado.contains("manual_linking")
                || combinado.contains("email_conflict")
                || combinado.contains("already registered")
            {
                return .conflitoDeIdentidade
            }
            if combinado.contains("token_ja_usado")
                || combinado.contains("desafio_ja_usado")
                || combinado.contains("desafio_expirado")
            {
                return .callbackInvalido
            }
        }
        if status == 409 { return .conflitoDeIdentidade }
        return .provedorIndisponivel
    }
}

private struct RequisicaoSocialIniciarPKCE: Encodable, Sendable {
    let provedor: String
    let fluxo: String
    let plataforma: String
    let codeChallenge: String
    let redirectTo: String

    enum CodingKeys: String, CodingKey {
        case provedor, fluxo, plataforma
        case codeChallenge = "code_challenge"
        case redirectTo = "redirect_to"
    }
}

private struct RequisicaoSocialPKCE: Encodable, Sendable {
    let provedor: String
    let fluxo: String
    let plataforma: String
    let transacaoId: String
    let codigo: String
    let codeVerifier: String

    enum CodingKeys: String, CodingKey {
        case provedor, fluxo, plataforma
        case transacaoId = "transacao_id"
        case codigo
        case codeVerifier = "code_verifier"
    }
}

private struct RequisicaoSocialIdToken: Encodable, Sendable {
    let provedor: String
    let fluxo: String
    let plataforma: String
    let idToken: String
    let nonce: String

    enum CodingKeys: String, CodingKey {
        case provedor, fluxo, plataforma
        case idToken = "id_token"
        case nonce
    }
}

private struct RespostaInicioPKCE: Decodable {
    let transacaoId: String
    let urlAutorizacao: String

    enum CodingKeys: String, CodingKey {
        case transacaoId = "transacao_id"
        case urlAutorizacao = "url_autorizacao"
    }
}

private struct RespostaConclusaoSocial: Decodable {
    struct Usuario: Decodable {
        let email: String?
    }

    struct SessaoDto: Decodable {
        let accessToken: String
        let refreshToken: String
        let user: Usuario?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case user
        }
    }

    let sessao: SessaoDto
    let precisaDefinirSenha: Bool

    enum CodingKeys: String, CodingKey {
        case sessao
        case precisaDefinirSenha = "precisa_definir_senha"
    }
}
