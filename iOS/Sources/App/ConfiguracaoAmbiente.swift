import Foundation

enum AmbienteApp: String, Sendable {
    case local
    case frilaDev = "frila-dev"
    case frilaProd = "frila-prod"
}

enum ModoAPI: String, Sendable { case mock, supabase }

/// O cliente que o app monta. Só o ambiente `local` chega ao dublê em memória; fora dele,
/// configuração ausente vira `ErroDeConfiguracao`, nunca um retorno silencioso ao simulado.
enum SelecaoDeAPI: Equatable, Sendable {
    case emMemoria
    case supabase(url: URL, chavePublicavel: String)
}

extension SelecaoDeAPI: CustomStringConvertible, CustomDebugStringConvertible {
    // Falha de teste e log mostram só o tipo de cliente, nunca a URL ou a chave.
    var description: String {
        switch self {
        case .emMemoria: "emMemoria"
        case .supabase: "supabase(configurado)"
        }
    }

    var debugDescription: String { description }
}

struct ErroDeConfiguracao: Error, Equatable, Sendable {
    enum Motivo: Equatable, Sendable {
        case ambienteAusente
        case ambienteDesconhecido
        case modoAusente
        case modoDesconhecido
        case simuladoForaDoLocal
        case urlAusente
        case urlInvalida
        case urlDeExemplo
        case chaveAusente
        case chaveInvalida
        case chaveDeExemplo
        case chaveSecreta
    }

    let ambiente: AmbienteApp?
    let motivo: Motivo
}

extension ErroDeConfiguracao: CustomStringConvertible {
    /// Cita o ambiente e o campo; nunca o valor recebido.
    var description: String {
        let nome = ambiente?.rawValue ?? "desconhecido"
        return switch motivo {
        case .ambienteAusente: "A configuração de build não informa o ambiente (FRILA_ENVIRONMENT)."
        case .ambienteDesconhecido: "O ambiente da configuração de build não é local, frila-dev nem frila-prod."
        case .modoAusente: "O ambiente \(nome) não informa o modo da API (FRILA_API_MODE)."
        case .modoDesconhecido: "O ambiente \(nome) usa um modo de API desconhecido; os válidos são mock e supabase."
        case .simuladoForaDoLocal: "O ambiente \(nome) exige o Supabase e não pode usar a API simulada."
        case .urlAusente: "O ambiente \(nome) exige a URL do Supabase, que não foi configurada."
        case .urlInvalida: "A URL do Supabase do ambiente \(nome) é inválida: use https, sem caminho, parâmetros ou credenciais."
        case .urlDeExemplo: "A URL do Supabase do ambiente \(nome) ainda é um valor de exemplo."
        case .chaveAusente: "O ambiente \(nome) exige a chave publicável do Supabase, que não foi configurada."
        case .chaveInvalida: "A chave publicável do Supabase do ambiente \(nome) tem formato inválido."
        case .chaveDeExemplo: "A chave publicável do Supabase do ambiente \(nome) ainda é um valor de exemplo."
        case .chaveSecreta: "A chave do ambiente \(nome) é secreta (service_role ou sb_secret) e não pode ir no app."
        }
    }
}

struct ConfiguracaoAmbiente: Sendable {
    let ambiente: AmbienteApp
    let selecao: SelecaoDeAPI
    let urlDaLoja: URL

    init(bundle: Bundle = .main) throws(ErroDeConfiguracao) {
        try self.init(infoDictionary: bundle.infoDictionary ?? [:])
    }

    init(infoDictionary info: [String: Any]) throws(ErroDeConfiguracao) {
        func valor(_ chave: String) -> String {
            (info[chave] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let nomeDoAmbiente = valor("FRILA_ENVIRONMENT")
        guard !nomeDoAmbiente.isEmpty else { throw ErroDeConfiguracao(ambiente: nil, motivo: .ambienteAusente) }
        guard let ambiente = AmbienteApp(rawValue: nomeDoAmbiente) else {
            throw ErroDeConfiguracao(ambiente: nil, motivo: .ambienteDesconhecido)
        }

        let nomeDoModo = valor("FRILA_API_MODE")
        guard !nomeDoModo.isEmpty else { throw ErroDeConfiguracao(ambiente: ambiente, motivo: .modoAusente) }
        guard let modo = ModoAPI(rawValue: nomeDoModo) else {
            throw ErroDeConfiguracao(ambiente: ambiente, motivo: .modoDesconhecido)
        }

        switch modo {
        case .mock:
            guard ambiente == .local else { throw ErroDeConfiguracao(ambiente: ambiente, motivo: .simuladoForaDoLocal) }
            selecao = .emMemoria
        case .supabase:
            let url = try Self.validarURL(valor("FRILA_SUPABASE_URL"), ambiente: ambiente)
            let chave = try Self.validarChave(valor("FRILA_SUPABASE_PUBLISHABLE_KEY"), ambiente: ambiente)
            selecao = .supabase(url: url, chavePublicavel: chave)
        }

        self.ambiente = ambiente
        let loja = valor("FRILA_APP_STORE_URL")
        urlDaLoja = URL(string: loja) ?? URL(string: "https://apps.apple.com/")!
    }

    /// Linha do log de inicialização: para onde o app aponta, com a URL do projeto e nunca com a chave.
    var resumoParaLog: String {
        switch selecao {
        case .emMemoria: "ambiente=\(ambiente.rawValue) api=mock"
        case let .supabase(url, _): "ambiente=\(ambiente.rawValue) api=supabase url=\(url.absoluteString)"
        }
    }

    /// Marcadores dos arquivos de exemplo e de variável de build não expandida.
    static let marcadoresDeExemplo = ["not-configured", "seu-projeto", "cole-a-chave", "placeholder", "example", "changeme", "your-", "<", ">", "$("]

    private static func contemMarcador(_ texto: String) -> Bool {
        let minusculo = texto.lowercased()
        return marcadoresDeExemplo.contains { minusculo.contains($0) }
    }

    private static func validarURL(_ texto: String, ambiente: AmbienteApp) throws(ErroDeConfiguracao) -> URL {
        guard !texto.isEmpty else { throw ErroDeConfiguracao(ambiente: ambiente, motivo: .urlAusente) }
        guard !contemMarcador(texto) else { throw ErroDeConfiguracao(ambiente: ambiente, motivo: .urlDeExemplo) }
        guard let componentes = URLComponents(string: texto),
              let esquema = componentes.scheme?.lowercased(),
              let host = componentes.host?.lowercased(), !host.isEmpty,
              componentes.user == nil, componentes.password == nil,
              componentes.query == nil, componentes.fragment == nil,
              componentes.path.isEmpty || componentes.path == "/",
              let url = componentes.url else {
            throw ErroDeConfiguracao(ambiente: ambiente, motivo: .urlInvalida)
        }
        // Só o ambiente local aceita http, e só no próprio Mac (supabase start).
        let loopback = ["127.0.0.1", "localhost", "::1", "[::1]"].contains(host)
        guard esquema == "https" || (esquema == "http" && ambiente == .local && loopback) else {
            throw ErroDeConfiguracao(ambiente: ambiente, motivo: .urlInvalida)
        }
        return url
    }

    private static func validarChave(_ chave: String, ambiente: AmbienteApp) throws(ErroDeConfiguracao) -> String {
        guard !chave.isEmpty else { throw ErroDeConfiguracao(ambiente: ambiente, motivo: .chaveAusente) }
        guard !contemMarcador(chave) else { throw ErroDeConfiguracao(ambiente: ambiente, motivo: .chaveDeExemplo) }
        let permitidos = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        guard chave.unicodeScalars.allSatisfy(permitidos.contains) else {
            throw ErroDeConfiguracao(ambiente: ambiente, motivo: .chaveInvalida)
        }
        guard !chave.hasPrefix("sb_secret_") else { throw ErroDeConfiguracao(ambiente: ambiente, motivo: .chaveSecreta) }

        let partes = chave.split(separator: ".", omittingEmptySubsequences: false)
        if partes.count == 3 {
            // Chave legada em JWT: a anon pode ir no app; a service_role, nunca.
            guard let papel = papelDoJWT(String(partes[1])) else {
                throw ErroDeConfiguracao(ambiente: ambiente, motivo: .chaveInvalida)
            }
            guard papel != "service_role" else { throw ErroDeConfiguracao(ambiente: ambiente, motivo: .chaveSecreta) }
        }
        return chave
    }

    private static func papelDoJWT(_ segmento: String) -> String? {
        var base64 = segmento.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let dados = Data(base64Encoded: base64),
              let objeto = try? JSONSerialization.jsonObject(with: dados) as? [String: Any] else { return nil }
        return objeto["role"] as? String
    }
}
