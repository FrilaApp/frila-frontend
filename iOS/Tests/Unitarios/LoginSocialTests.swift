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
    @Test("SegurancaOAuthSocial gera nonce SHA-256 e PKCE S256 válidos")
    func geraNonceEPKCEValidos() {
        let nonce = SegurancaOAuthSocial.gerarNonceBruto()
        let hash = SegurancaOAuthSocial.sha256Hex(nonce)
        #expect(nonce.count == 43)
        #expect(hash.count == 64)
        #expect(hash != nonce)

        let verifier = SegurancaOAuthSocial.gerarVerifierPKCE()
        let challenge = SegurancaOAuthSocial.desafioPKCES256(verifier)
        #expect(SegurancaOAuthSocial.ehVerifierPKCEValido(verifier))
        #expect(challenge.count == 43)
        #expect(challenge != verifier)
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
}
