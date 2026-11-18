import Foundation

/// Onde a web do Frila mora em cada ambiente do app: o Local e o Dev (e o Beta, que fala com o servidor de dev) abrem a web
/// de dev; só o Prod abre a web de produção. O link do convite que a casa compartilha tem de abrir uma web que conheça o
/// convite: um convite do servidor de dev não existe na web de produção. Nada de endereço fixo na tela do convite.
public enum OrigemDaWeb {
    /// A prévia da web de dev (Worker `frila-web-dev`, Supabase de dev). O `basename` da web é `/app`.
    public static let dev = "https://frila-web-dev.frilabr.workers.dev/app"
    /// A web de produção (Worker `frila-web`, rotas `frilabr.com/app*`).
    public static let producao = "https://frilabr.com/app"

    /// A origem do `FRILA_ENVIRONMENT` do Info.plist do app (o mesmo valor que `ConfiguracaoAmbiente` lê). Só `frila-prod`
    /// dá a web de produção: ambiente ausente ou desconhecido cai na de dev, e um link de dev nunca aponta para o Prod.
    public static func doAmbiente(_ nome: String?) -> String {
        nome?.trimmingCharacters(in: .whitespacesAndNewlines) == "frila-prod" ? producao : dev
    }

    /// A origem do app que está rodando, pelo Info.plist do pacote principal.
    public static var atual: String {
        doAmbiente(Bundle.main.infoDictionary?["FRILA_ENVIRONMENT"] as? String)
    }
}
