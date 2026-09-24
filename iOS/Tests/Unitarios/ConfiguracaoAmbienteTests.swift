@testable import Frila
import Foundation
import Testing

@Suite("Seleção do ambiente")
struct ConfiguracaoAmbienteTests {
    // Valores fictícios, só com o formato dos reais.
    static let urlValida = "https://abcdefghijklmnopqrst.supabase.co"
    static let chaveValida = "sb_publishable_ChaveFicticiaDeTeste_0123456789"

    static func info(
        ambiente: String? = "frila-dev",
        modo: String? = "supabase",
        url: String? = urlValida,
        chave: String? = chaveValida
    ) -> [String: Any] {
        var info: [String: Any] = [:]
        info["FRILA_ENVIRONMENT"] = ambiente
        info["FRILA_API_MODE"] = modo
        info["FRILA_SUPABASE_URL"] = url
        info["FRILA_SUPABASE_PUBLISHABLE_KEY"] = chave
        return info
    }

    static func jwt(papel: String) -> String {
        func segmento(_ json: String) -> String {
            Data(json.utf8).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        return [segmento(#"{"alg":"HS256","typ":"JWT"}"#), segmento(#"{"iss":"supabase","role":"\#(papel)"}"#), "assinatura"]
            .joined(separator: ".")
    }

    @Test("Local usa explicitamente o dublê em memória")
    func localUsaSimulado() throws {
        let configuracao = try ConfiguracaoAmbiente(infoDictionary: Self.info(ambiente: "local", modo: "mock", url: "http://127.0.0.1:54321", chave: nil))
        #expect(configuracao.ambiente == .local)
        #expect(configuracao.selecao == .emMemoria)
    }

    @Test("Dev e Prod montam o Supabase com a URL e a chave recebidas", arguments: [AmbienteApp.frilaDev, .frilaProd])
    func devEProdUsamSupabase(ambiente: AmbienteApp) throws {
        let configuracao = try ConfiguracaoAmbiente(infoDictionary: Self.info(ambiente: ambiente.rawValue))
        #expect(configuracao.ambiente == ambiente)
        #expect(configuracao.selecao == .supabase(url: try #require(URL(string: Self.urlValida)), chavePublicavel: Self.chaveValida))
    }

    @Test("A chave anon legada em JWT é aceita")
    func anonLegadaAceita() throws {
        let configuracao = try ConfiguracaoAmbiente(infoDictionary: Self.info(chave: Self.jwt(papel: "anon")))
        guard case .supabase = configuracao.selecao else {
            Issue.record("Esperava Supabase")
            return
        }
    }

    @Test("O ambiente local pode apontar para o supabase start por http")
    func localComSupabaseLocal() throws {
        let configuracao = try ConfiguracaoAmbiente(infoDictionary: Self.info(ambiente: "local", url: "http://127.0.0.1:54321"))
        guard case .supabase = configuracao.selecao else {
            Issue.record("Esperava Supabase")
            return
        }
    }

    struct CasoInvalido: Sendable, CustomTestStringConvertible {
        let nome: String
        let ambiente: String?
        let modo: String?
        let url: String?
        let chave: String?
        let esperado: ErroDeConfiguracao

        var testDescription: String { nome }

        init(_ nome: String, ambiente: String? = "frila-dev", modo: String? = "supabase", url: String? = ConfiguracaoAmbienteTests.urlValida, chave: String? = ConfiguracaoAmbienteTests.chaveValida, esperado: ErroDeConfiguracao) {
            self.nome = nome
            self.ambiente = ambiente
            self.modo = modo
            self.url = url
            self.chave = chave
            self.esperado = esperado
        }
    }

    static let casosInvalidos: [CasoInvalido] = [
        CasoInvalido("sem ambiente", ambiente: nil, esperado: .init(ambiente: nil, motivo: .ambienteAusente)),
        CasoInvalido("ambiente desconhecido", ambiente: "staging", esperado: .init(ambiente: nil, motivo: .ambienteDesconhecido)),
        CasoInvalido("sem modo não vira simulado", modo: nil, esperado: .init(ambiente: .frilaDev, motivo: .modoAusente)),
        CasoInvalido("modo desconhecido", modo: "graphql", esperado: .init(ambiente: .frilaDev, motivo: .modoDesconhecido)),
        CasoInvalido("dev com simulado", modo: "mock", esperado: .init(ambiente: .frilaDev, motivo: .simuladoForaDoLocal)),
        CasoInvalido("prod com simulado", ambiente: "frila-prod", modo: "mock", esperado: .init(ambiente: .frilaProd, motivo: .simuladoForaDoLocal)),
        CasoInvalido("dev sem URL", url: nil, esperado: .init(ambiente: .frilaDev, motivo: .urlAusente)),
        CasoInvalido("prod com URL vazia", ambiente: "frila-prod", url: "  ", esperado: .init(ambiente: .frilaProd, motivo: .urlAusente)),
        CasoInvalido("URL do arquivo de exemplo", url: "https://seu-projeto-dev.supabase.co", esperado: .init(ambiente: .frilaDev, motivo: .urlDeExemplo)),
        CasoInvalido("variável de build não expandida", url: "$(FRILA_SUPABASE_DEV_URL)", esperado: .init(ambiente: .frilaDev, motivo: .urlDeExemplo)),
        CasoInvalido("dev por http", url: "http://abcdefghijklmnopqrst.supabase.co", esperado: .init(ambiente: .frilaDev, motivo: .urlInvalida)),
        CasoInvalido("prod apontando para o Mac", ambiente: "frila-prod", url: "http://127.0.0.1:54321", esperado: .init(ambiente: .frilaProd, motivo: .urlInvalida)),
        CasoInvalido("URL com caminho", url: "https://abcdefghijklmnopqrst.supabase.co/rest/v1", esperado: .init(ambiente: .frilaDev, motivo: .urlInvalida)),
        CasoInvalido("URL sem host", url: "https://", esperado: .init(ambiente: .frilaDev, motivo: .urlInvalida)),
        CasoInvalido("dev sem chave", chave: nil, esperado: .init(ambiente: .frilaDev, motivo: .chaveAusente)),
        CasoInvalido("marcador antigo do Shared.xcconfig", chave: "public-key-not-configured", esperado: .init(ambiente: .frilaDev, motivo: .chaveDeExemplo)),
        CasoInvalido("chave do arquivo de exemplo", ambiente: "frila-prod", chave: "cole-a-chave-publicavel-prod-aqui", esperado: .init(ambiente: .frilaProd, motivo: .chaveDeExemplo)),
        CasoInvalido("chave com espaço", chave: "sb_publishable_abc def", esperado: .init(ambiente: .frilaDev, motivo: .chaveInvalida)),
        CasoInvalido("chave secreta nova", chave: "sb_secret_ChaveFicticiaDeTeste", esperado: .init(ambiente: .frilaDev, motivo: .chaveSecreta)),
        CasoInvalido("service_role legada", ambiente: "frila-prod", chave: ConfiguracaoAmbienteTests.jwt(papel: "service_role"), esperado: .init(ambiente: .frilaProd, motivo: .chaveSecreta)),
        CasoInvalido("JWT ilegível", chave: "eyJ.nao-e-base64.assinatura", esperado: .init(ambiente: .frilaDev, motivo: .chaveInvalida)),
    ]

    @Test("Configuração ausente ou inválida produz erro explícito", arguments: ConfiguracaoAmbienteTests.casosInvalidos)
    func configuracaoInvalida(caso: CasoInvalido) {
        #expect(throws: caso.esperado) {
            try ConfiguracaoAmbiente(infoDictionary: Self.info(ambiente: caso.ambiente, modo: caso.modo, url: caso.url, chave: caso.chave))
        }
    }

    @Test("A mensagem de erro não repete a URL nem a chave recebidas", arguments: [
        ("http://host-que-nao-pode-vazar.supabase.co", ConfiguracaoAmbienteTests.chaveValida, "host-que-nao-pode-vazar"),
        (ConfiguracaoAmbienteTests.urlValida, "sb_secret_ValorQueNaoPodeVazar", "ValorQueNaoPodeVazar"),
        (ConfiguracaoAmbienteTests.urlValida, "sb_publishable_ValorQueNaoPodeVazar com espaço", "ValorQueNaoPodeVazar"),
        (ConfiguracaoAmbienteTests.urlValida, ConfiguracaoAmbienteTests.jwt(papel: "service_role"), "assinatura"),
    ])
    func mensagemSemSegredo(url: String, chave: String, trecho: String) {
        do throws(ErroDeConfiguracao) {
            _ = try ConfiguracaoAmbiente(infoDictionary: Self.info(ambiente: "frila-prod", url: url, chave: chave))
            Issue.record("Esperava erro de configuração")
        } catch {
            #expect(!error.description.contains(trecho))
            #expect(!error.description.contains(url))
            #expect(!error.description.contains(chave))
        }
    }

    @Test("A descrição da seleção esconde a URL e a chave")
    func descricaoSemSegredo() throws {
        let selecao = SelecaoDeAPI.supabase(url: try #require(URL(string: Self.urlValida)), chavePublicavel: Self.chaveValida)
        #expect(!String(describing: selecao).contains(Self.chaveValida))
        #expect(!String(reflecting: selecao).contains("abcdefghijklmnopqrst"))
    }

    @Test("O log de inicialização mostra o ambiente e a URL, nunca a chave")
    func resumoParaLog() throws {
        let dev = try ConfiguracaoAmbiente(infoDictionary: Self.info())
        #expect(dev.resumoParaLog == "ambiente=frila-dev api=supabase url=\(Self.urlValida)")
        #expect(dev.resumoParaLog.contains(Self.chaveValida) == false)
        let local = try ConfiguracaoAmbiente(infoDictionary: Self.info(ambiente: "local", modo: "mock", url: nil, chave: nil))
        #expect(local.resumoParaLog == "ambiente=local api=mock")
    }

    @Test("O Info.plist deste build resolve para o cliente do esquema")
    func infoPlistDoBuild() throws {
        let configuracao = try ConfiguracaoAmbiente(bundle: .main)
        #if LOCAL
        #expect(configuracao.ambiente == .local)
        #expect(configuracao.selecao == .emMemoria)
        #elseif FRILA_DEV
        #expect(configuracao.ambiente == .frilaDev)
        guard case .supabase = configuracao.selecao else {
            Issue.record("Frila-Dev precisa usar Supabase")
            return
        }
        #elseif FRILA_PROD
        #expect(configuracao.ambiente == .frilaProd)
        guard case .supabase = configuracao.selecao else {
            Issue.record("Frila-Prod precisa usar Supabase")
            return
        }
        #endif
    }
}
