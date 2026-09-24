import Foundation

enum ModoAPI: String { case mock, supabase }

struct ConfiguracaoAmbiente {
    let nome: String
    let modoAPI: ModoAPI
    let supabaseURL: URL?
    let chavePublicavel: String
    let urlDaLoja: URL

    init(bundle: Bundle = .main) {
        nome = bundle.object(forInfoDictionaryKey: "FRILA_ENVIRONMENT") as? String ?? "Local"
        modoAPI = ModoAPI(rawValue: bundle.object(forInfoDictionaryKey: "FRILA_API_MODE") as? String ?? "mock") ?? .mock
        chavePublicavel = bundle.object(forInfoDictionaryKey: "FRILA_SUPABASE_PUBLISHABLE_KEY") as? String ?? ""
        let url = bundle.object(forInfoDictionaryKey: "FRILA_SUPABASE_URL") as? String ?? ""
        supabaseURL = URL(string: url)
        let loja = bundle.object(forInfoDictionaryKey: "FRILA_APP_STORE_URL") as? String ?? "https://apps.apple.com/"
        urlDaLoja = URL(string: loja) ?? URL(string: "https://apps.apple.com/")!
    }
}
