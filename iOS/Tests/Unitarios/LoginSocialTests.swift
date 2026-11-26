import Foundation
import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

@MainActor
private final class ProvedorSocialDublê: ProvedorUIAutenticacaoSocial {
    var resultadoApple: Result<CredencialAppleNativa, Error> = .success(
        CredencialAppleNativa(idToken: "id-token-apple-sintetico", email: "privado@privaterelay.appleid.com", nome: "Ana")
    )
    var resultadoWeb: ((URL, String) -> Result<URL, Error>)?
    var ultimoNonceAppleSha256: String?
    var ultimaUrlOAuth: URL?
    var ultimoEsquemaCallback: String?

    func solicitarApple(nonceSha256: String) async throws -> CredencialAppleNativa {
        ultimoNonceAppleSha256 = nonceSha256
        return try resultadoApple.get()
    }

    func abrirSessaoWebOAuth(url: URL, esquemaCallback: String) async throws -> URL {
        ultimaUrlOAuth = url
        ultimoEsquemaCallback = esquemaCallback
        if let resultadoWeb {
            return try resultadoWeb(url, esquemaCallback).get()
        }
        throw ErroEntradaSocial.cancelado
    }
}

private final class ApiSocialDublê: ApiClienteEncaminhador, @unchecked Sendable {
    var _suportaLoginSocial: Bool = true
    override var suportaLoginSocial: Bool { _suportaLoginSocial }
    var resultadoApple: Result<ResultadoEntradaSocial, Error> = .success(
        ResultadoEntradaSocial(provedor: .apple, email: "ana@frila.test")
    )
    var resultadoPKCE: Result<ResultadoEntradaSocial, Error> = .success(
        ResultadoEntradaSocial(provedor: .google, email: "ana@frila.test")
    )
    var ultimoNonceRecebido: String?
    var ultimoTransacaoIDRecebido: String?
    var ultimoVerifierRecebido: String?
    var ultimoCodigoRecebido: String?

    init(cenario: ApiClienteEmMemoria.Cenario = .sucesso) {
        super.init(base: ApiClienteEmMemoria(cenario: cenario, sessaoAtivaInicial: false))
    }

    override func entrarComApple(idToken: String, nonce: String) async throws -> ResultadoEntradaSocial {
        ultimoNonceRecebido = nonce
        return try resultadoApple.get()
    }

    override func iniciarLoginSocialPKCE(
        provedor: ProvedorSocial,
        redirectTo: URL,
        codeChallenge: String
    ) async throws -> InicioOAuthPKCE {
        var comps = URLComponents(string: "https://dev.supabase.co/auth/v1/authorize")!
        comps.queryItems = [
            URLQueryItem(name: "provider", value: provedor.rawValue),
            URLQueryItem(name: "redirect_to", value: redirectTo.absoluteString),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "s256"),
        ]
        return InicioOAuthPKCE(
            transacaoID: "33333333-3333-4333-8333-333333333333",
            urlAutorizacao: comps.url!
        )
    }

    override func concluirLoginSocialPKCE(
        provedor: ProvedorSocial,
        transacaoID: String,
        codigo: String,
        verifier: String
    ) async throws -> ResultadoEntradaSocial {
        ultimoTransacaoIDRecebido = transacaoID
        ultimoCodigoRecebido = codigo
        ultimoVerifierRecebido = verifier
        return try resultadoPKCE.get()
    }
}

@Suite("Login social iOS — Apple e Google")
struct LoginSocialTests {
    @Test("SegurancaOAuthSocial gera nonce SHA-256 e PKCE S256 válidos e falha fechado sem fallback RNG se CSPRNG falhar")
    func geraNonceEPKCEValidos() throws {
        let nonce = try SegurancaOAuthSocial.gerarNonceBruto()
        let hash = SegurancaOAuthSocial.sha256Hex(nonce)
        #expect(nonce.count == 43)
        #expect(hash.count == 64)
        #expect(hash != nonce)

        let verifier = try SegurancaOAuthSocial.gerarVerifierPKCE()
        let challenge = SegurancaOAuthSocial.desafioPKCES256(verifier)
        #expect(SegurancaOAuthSocial.ehVerifierPKCEValido(verifier))
        #expect(challenge.count == 43)
        #expect(challenge != verifier)

        // Falha injetada do CSPRNG (SecRandomCopyBytes): falha fechado sem recorrer a UInt8.random
        #expect(throws: ErroEntradaSocial.provedorIndisponivel) {
            _ = try SegurancaOAuthSocial.gerarNonceBruto(provedorBytes: { _ in nil })
        }
        #expect(throws: ErroEntradaSocial.provedorIndisponivel) {
            _ = try SegurancaOAuthSocial.gerarVerifierPKCE(provedorBytes: { _ in Data([1, 2, 3]) })
        }
    }

    @Test("extrairCodigoDoCallback valida esquema, state, cancelamento e conflito de identidade")
    func validaCallbackOAuth() {
        let ok = SegurancaOAuthSocial.extrairCodigoDoCallback(
            url: URL(string: "frila-auth://auth/callback?code=codigo-oauth-123&state=est-1")!,
            stateEsperado: "est-1"
        )
        #expect(ok == .success("codigo-oauth-123"))

        let stateErrado = SegurancaOAuthSocial.extrairCodigoDoCallback(
            url: URL(string: "frila-auth://auth/callback?code=codigo-oauth-123&state=outro")!,
            stateEsperado: "est-1"
        )
        #expect(stateErrado == .failure(.callbackInvalido))

        let semCorrelacao = SegurancaOAuthSocial.extrairCodigoDoCallback(
            url: URL(string: "frila-auth://auth/callback?code=codigo-oauth-123")!,
            stateEsperado: "est-1"
        )
        #expect(semCorrelacao == .failure(.callbackInvalido))

        let hostErrado = SegurancaOAuthSocial.extrairCodigoDoCallback(
            url: URL(string: "frila-auth://outro/callback?code=codigo-oauth-123&tx=est-1")!,
            stateEsperado: "est-1"
        )
        #expect(hostErrado == .failure(.callbackInvalido))

        let pathErrado = SegurancaOAuthSocial.extrairCodigoDoCallback(
            url: URL(string: "frila-auth://auth/outro?code=codigo-oauth-123&tx=est-1")!,
            stateEsperado: "est-1"
        )
        #expect(pathErrado == .failure(.callbackInvalido))

        let esquemaErrado = SegurancaOAuthSocial.extrairCodigoDoCallback(
            url: URL(string: "https://evil.example/callback?code=codigo-oauth-123")!
        )
        #expect(esquemaErrado == .failure(.callbackInvalido))

        let cancelado = SegurancaOAuthSocial.extrairCodigoDoCallback(
            url: URL(string: "frila-auth://auth/callback?error=access_denied")!
        )
        #expect(cancelado == .failure(.cancelado))

        let conflito = SegurancaOAuthSocial.extrairCodigoDoCallback(
            url: URL(string: "frila-auth://auth/callback?error_code=identity_already_exists")!
        )
        #expect(conflito == .failure(.conflitoDeIdentidade))
    }

    @Test("Apple envia SHA-256 do nonce ao provedor, troca nonce bruto na API e resolve conta existente")
    @MainActor
    func entrarComAppleSucesso() async {
        let api = ApiSocialDublê(cenario: .contratante)
        let ui = ProvedorSocialDublê()
        let vm = EntradaComSenhaViewModel(api: api, provedorSocial: ui)

        let destino = await vm.entrarComApple()

        #expect(destino == .destino(.contratante))
        #expect(vm.erro == nil)
        #expect(api.ultimoNonceRecebido != nil)
        if let nonceBruto = api.ultimoNonceRecebido {
            #expect(ui.ultimoNonceAppleSha256 == SegurancaOAuthSocial.sha256Hex(nonceBruto))
        }
    }

    @Test("Apple com Hide My Email em primeiro acesso encaminha para cadastro sem erro")
    @MainActor
    func entrarComApplePrimeiroAcessoHideMyEmail() async {
        let api = ApiSocialDublê(cenario: .primeiroAcesso)
        api.resultadoApple = .success(ResultadoEntradaSocial(provedor: .apple, email: "abc@privaterelay.appleid.com"))
        let ui = ProvedorSocialDublê()
        let vm = EntradaComSenhaViewModel(api: api, provedorSocial: ui)

        let destino = await vm.entrarComApple()
        #expect(destino == .cadastro(email: "abc@privaterelay.appleid.com"))
        #expect(vm.erro == nil)
    }

    @Test("Google usa iniciar_pkce + pkce via autenticar-social com correlação tx")
    @MainActor
    func entrarComGooglePKCESucesso() async {
        let api = ApiSocialDublê(cenario: .sucesso)
        let ui = ProvedorSocialDublê()
        ui.resultadoWeb = { url, esquema in
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let redirectStr = comps?.queryItems?.first(where: { $0.name == "redirect_to" })?.value ?? ""
            let redirectComps = URLComponents(string: redirectStr)
            let tx = redirectComps?.queryItems?.first(where: { $0.name == "tx" })?.value ?? ""
            #expect(esquema == SegurancaOAuthSocial.esquemaCallbackPadrao)
            #expect(comps?.queryItems?.first(where: { $0.name == "code_challenge_method" })?.value == "s256")
            return .success(URL(string: "frila-auth://auth/callback?code=cod-google-999&tx=\(tx)")!)
        }
        let vm = EntradaComSenhaViewModel(api: api, provedorSocial: ui)

        let destino = await vm.entrarComGoogle()
        #expect(destino == .destino(.profissional))
        #expect(api.ultimoTransacaoIDRecebido == "33333333-3333-4333-8333-333333333333")
        #expect(api.ultimoCodigoRecebido == "cod-google-999")
        #expect(api.ultimoVerifierRecebido.map(SegurancaOAuthSocial.ehVerifierPKCEValido) == true)
        #expect(vm.erro == nil)
    }

    @Test("Cancelamento não exibe erro; conflito de identidade exibe orientação segura")
    @MainActor
    func cancelamentoEConflitoDeIdentidade() async {
        let api = ApiSocialDublê()
        let ui = ProvedorSocialDublê()
        ui.resultadoApple = .failure(ErroEntradaSocial.cancelado)
        let vm = EntradaComSenhaViewModel(api: api, provedorSocial: ui)

        #expect(await vm.entrarComApple() == nil)
        #expect(vm.erro == nil)

        ui.resultadoApple = .success(CredencialAppleNativa(idToken: "tok", email: "ana@frila.test"))
        api.resultadoApple = .failure(ErroEntradaSocial.conflitoDeIdentidade)
        #expect(await vm.entrarComApple() == nil)
        #expect(vm.erro?.contains("e-mail e senha") == true)
    }

    @Test("Pendência explícita precisaDefinirSenha=true em conta social encaminha para .definirSenha (nunca .cadastro)")
    @MainActor
    func contaSocialComPendenciaDeSenhaVaiParaDefinirSenha() async {
        // 1. Retorno imediato de autenticar-social com precisa_definir_senha = true
        let api = ApiSocialDublê(cenario: .contratante)
        api.resultadoApple = .success(
            ResultadoEntradaSocial(provedor: .apple, email: "ana@frila.test", precisaDefinirSenha: true)
        )
        let ui = ProvedorSocialDublê()
        let vm = EntradaComSenhaViewModel(api: api, provedorSocial: ui)

        let destino = await vm.entrarComApple()
        #expect(destino == .definirSenha(.destino(.contratante)))

        // 2. Após reinício (estado_autenticacao devolvendo precisaDefinirSenha = true -> .definirSenhaObrigatoria)
        let apiPendente = ApiSocialComEstadoPendente()
        let vmPendente = EntradaComSenhaViewModel(api: apiPendente, provedorSocial: ui)
        let destinoPendente = await vmPendente.entrarComApple()
        #expect(destinoPendente == .definirSenha(.destino(.profissional)))
    }

    @Test("URLProtocol: SupabaseApiCliente serializa iniciar_pkce, pkce, id_token e mapeia 409/410/429")
    func urlProtocolAutenticarSocial() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [UrlProtocolSocialStub.self]
        let sessao = URLSession(configuration: config)
        let cliente = SupabaseApiCliente(
            url: URL(string: "https://dev.frila.test")!,
            chavePublicavel: "anon-test-key",
            telemetria: TelemetryNula(),
            sessaoHTTP: sessao,
            armazenamentoDaSessao: ArmazenamentoDeSessaoEmMemoria()
        )

        // 1. iniciar_pkce: valida payload JSON e decodificação de transacao_id + url_autorizacao
        var corpoRecebido: [String: Any]?
        var caminhoRecebido: String?
        UrlProtocolSocialStub.manipulador = { req in
            caminhoRecebido = req.url?.path
            if let data = Self.lerBody(req) {
                corpoRecebido = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            }
            let json = """
            {"transacao_id":"33333333-3333-4333-8333-333333333333","url_autorizacao":"https://dev.frila.test/auth/v1/authorize?provider=google","expira_em":"2026-11-25T21:10:00Z"}
            """
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (resp, Data(json.utf8))
        }
        let inicio = try await cliente.iniciarLoginSocialPKCE(
            provedor: .google,
            redirectTo: URL(string: "frila-auth://auth/callback?tx=abc")!,
            codeChallenge: String(repeating: "c", count: 43)
        )
        #expect(caminhoRecebido == "/functions/v1/autenticar-social")
        #expect(corpoRecebido?["fluxo"] as? String == "iniciar_pkce")
        #expect(corpoRecebido?["provedor"] as? String == "google")
        #expect(corpoRecebido?["plataforma"] as? String == "ios")
        #expect(inicio.transacaoID == "33333333-3333-4333-8333-333333333333")

        // 2. 409 conflito_identidade -> .conflitoDeIdentidade
        UrlProtocolSocialStub.manipulador = { req in
            if let data = Self.lerBody(req) {
                corpoRecebido = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            }
            let resp = HTTPURLResponse(url: req.url!, statusCode: 409, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (resp, Data(#"{"code":"conflito_identidade","message":"Conflito"}"#.utf8))
        }
        await #expect(throws: ErroEntradaSocial.conflitoDeIdentidade) {
            _ = try await cliente.entrarComApple(idToken: "eyJhbGciOiJSUzI1NiJ9.payload.sig", nonce: "nonce-bruto-16-chars")
        }
        #expect(corpoRecebido?["fluxo"] as? String == "id_token")
        #expect(corpoRecebido?["provedor"] as? String == "apple")
        #expect(corpoRecebido?["plataforma"] as? String == "ios")

        // 3. 409 token_ja_usado e 410 desafio_expirado -> .callbackInvalido; 429 -> .limiteExcedido
        UrlProtocolSocialStub.manipulador = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 409, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (resp, Data(#"{"code":"token_ja_usado","message":"Replay"}"#.utf8))
        }
        await #expect(throws: ErroEntradaSocial.callbackInvalido) {
            _ = try await cliente.entrarComApple(idToken: "eyJhbGciOiJSUzI1NiJ9.payload.sig", nonce: "nonce-bruto-16-chars")
        }

        UrlProtocolSocialStub.manipulador = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 410, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (resp, Data(#"{"code":"desafio_expirado","message":"Expirado"}"#.utf8))
        }
        await #expect(throws: ErroEntradaSocial.callbackInvalido) {
            _ = try await cliente.concluirLoginSocialPKCE(
                provedor: .google,
                transacaoID: "33333333-3333-4333-8333-333333333333",
                codigo: "cod-1234",
                verifier: String(repeating: "v", count: 43)
            )
        }

        UrlProtocolSocialStub.manipulador = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 429, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (resp, Data(#"{"code":"limite_excedido"}"#.utf8))
        }
        await #expect(throws: ErroEntradaSocial.limiteExcedido) {
            _ = try await cliente.iniciarLoginSocialPKCE(
                provedor: .apple,
                redirectTo: URL(string: "frila-auth://auth/callback?tx=abc")!,
                codeChallenge: String(repeating: "d", count: 43)
            )
        }

        // 4. URLError de transporte -> .rede e NÃO grava sessão indevida
        let armazenamentoTransporte = ArmazenamentoDeSessaoEmMemoria()
        let clienteTransporte = SupabaseApiCliente(
            url: URL(string: "https://dev.frila.test")!,
            chavePublicavel: "anon-test-key",
            telemetria: TelemetryNula(),
            sessaoHTTP: sessao,
            armazenamentoDaSessao: armazenamentoTransporte
        )
        UrlProtocolSocialStub.manipulador = { _ in
            throw URLError(.notConnectedToInternet)
        }
        await #expect(throws: ErroEntradaSocial.rede) {
            _ = try await clienteTransporte.concluirLoginSocialPKCE(
                provedor: .google,
                transacaoID: "33333333-3333-4333-8333-333333333333",
                codigo: "cod-1234",
                verifier: String(repeating: "v", count: 43)
            )
        }
        #expect(await clienteTransporte.possuiSessao() == false)

        // 5. concluirLoginSocialPKCE 200: serializa pkce, aplica sessão no armazenamento e devolve identidade
        let jwtFake = Self.fakeJwt(email: "ana.social@frila.test")
        let armazenamentoOk = ArmazenamentoDeSessaoEmMemoria()
        let clienteOk = SupabaseApiCliente(
            url: URL(string: "https://dev.frila.test")!,
            chavePublicavel: "anon-test-key",
            telemetria: TelemetryNula(),
            sessaoHTTP: sessao,
            armazenamentoDaSessao: armazenamentoOk
        )
        UrlProtocolSocialStub.manipulador = { req in
            if req.url?.path == "/functions/v1/autenticar-social" {
                if let data = Self.lerBody(req) {
                    corpoRecebido = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                }
                let json = """
                {"sessao":{"access_token":"\(jwtFake)","refresh_token":"ref-pkce-ok","token_type":"bearer","expires_in":3600,"user":{"id":"11111111-1111-4111-8111-111111111111","email":"ana.social@frila.test"}},"provedor":"google","precisa_definir_senha":false}
                """
                let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (resp, Data(json.utf8))
            }
            // Chamada GET /auth/v1/user disparada internamente por cliente.auth.setSession
            let userJson = """
            {"id":"11111111-1111-4111-8111-111111111111","aud":"authenticated","role":"authenticated","email":"ana.social@frila.test","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z","app_metadata":{},"user_metadata":{}}
            """
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (resp, Data(userJson.utf8))
        }
        let resultadoPkce = try await clienteOk.concluirLoginSocialPKCE(
            provedor: .google,
            transacaoID: "33333333-3333-4333-8333-333333333333",
            codigo: "cod-ok-123",
            verifier: String(repeating: "v", count: 43)
        )
        #expect(corpoRecebido?["fluxo"] as? String == "pkce")
        #expect(corpoRecebido?["provedor"] as? String == "google")
        #expect(corpoRecebido?["plataforma"] as? String == "ios")
        #expect(corpoRecebido?["transacao_id"] as? String == "33333333-3333-4333-8333-333333333333")
        #expect(resultadoPkce.provedor == .google)
        #expect(resultadoPkce.email == "ana.social@frila.test")
        #expect(resultadoPkce.precisaDefinirSenha == false)
        #expect(await clienteOk.possuiSessao() == true)

        UrlProtocolSocialStub.manipulador = nil
    }

    @Test("AutenticadorSocialNativo com Task previamente cancelada lança CancellationError sem apresentar sheet")
    @MainActor
    func cancelamentoPrevioNoCoordenador() async {
        let coordenador = AutenticadorSocialNativo()
        let tarefaApple = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            return try await coordenador.solicitarApple(nonceSha256: String(repeating: "a", count: 64))
        }
        await #expect(throws: CancellationError.self) {
            _ = try await tarefaApple.value
        }

        let tarefaWeb = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            return try await coordenador.abrirSessaoWebOAuth(
                url: URL(string: "https://dev.frila.test/auth/v1/authorize")!,
                esquemaCallback: SegurancaOAuthSocial.esquemaCallbackPadrao
            )
        }
        await #expect(throws: CancellationError.self) {
            _ = try await tarefaWeb.value
        }
    }

    private static func fakeJwt(email: String) -> String {
        let header = Data(#"{"alg":"HS256","typ":"JWT"}"#.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        let exp = Int(Date().timeIntervalSince1970) + 3600
        let payload = Data(#"{"sub":"11111111-1111-4111-8111-111111111111","email":"\#(email)","exp":\#(exp)}"#.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return "\(header).\(payload).sig"
    }

    private static func lerBody(_ req: URLRequest) -> Data? {
        if let body = req.httpBody { return body }
        guard let stream = req.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var dados = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let lidos = stream.read(&buffer, maxLength: buffer.count)
            if lidos > 0 { dados.append(buffer, count: lidos) } else { break }
        }
        return dados
    }
}

private final class ApiSocialComEstadoPendente: ApiClienteEncaminhador, @unchecked Sendable {
    override var suportaLoginSocial: Bool { true }
    override func entrarComApple(idToken: String, nonce: String) async throws -> ResultadoEntradaSocial {
        ResultadoEntradaSocial(provedor: .apple, email: "ana@frila.test", precisaDefinirSenha: false)
    }
    override func estadoAutenticacao() async throws -> EstadoAutenticacao {
        EstadoAutenticacao(
            autenticado: true,
            dispositivoVerificado: true,
            precisaDefinirSenha: true,
            temConta: true
        )
    }
}

private final class UrlProtocolSocialStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var manipulador: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let manipulador = Self.manipulador else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (resp, data) = try manipulador(request)
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
