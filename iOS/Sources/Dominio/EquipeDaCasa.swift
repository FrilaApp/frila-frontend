import Foundation

/// Uma pessoa da casa, como o administrador a vê em `membros_do_estabelecimento` (contrato 0.2.103, RF21, US24).
/// `id` é o `membro_id` do vínculo, o que `remover_membro` e `transferir_administracao` recebem; não é o id da conta.
/// Sem e-mail, telefone, documento nem `usuario_id` (minimização, LGPD). `eVoce` marca a linha de quem chama.
///
/// `papelConhecido` é falso quando o servidor mandou um papel que este app não conhece: a pessoa continua na lista, com o papel
/// de menos permissão (`operador`), mas sem ação nenhuma de administrador sobre ela (nem remover, nem promover).
public struct MembroDaCasa: Hashable, Identifiable, Sendable {
    public let id: UUID
    public let nome: String
    public let papel: PapelMembro
    public let papelConhecido: Bool
    public let desde: Date?
    public let eVoce: Bool

    public init(id: UUID, nome: String, papel: PapelMembro, papelConhecido: Bool = true, desde: Date? = nil, eVoce: Bool = false) {
        self.id = id
        self.nome = nome
        self.papel = papel
        self.papelConhecido = papelConhecido
        self.desde = desde
        self.eVoce = eVoce
    }
}

/// O convite gerado por `convidar_membro`: o token de uso único (64 caracteres hexadecimais) e até quando vale.
/// O token é segredo de quem recebe o link: nunca vai para log, telemetria nem mensagem de erro.
public struct ConviteDeMembro: Hashable, Sendable {
    public let token: String
    public let expiraEm: Date?

    public init(token: String, expiraEm: Date?) {
        self.token = token
        self.expiraEm = expiraEm
    }
}

/// O que `aceitar_convite_membro` devolve: a casa em que a conta entrou e com que papel. Os dois podem faltar.
public struct MembroAdicionado: Hashable, Sendable {
    public let estabelecimentoID: UUID?
    public let papel: PapelMembro?

    public init(estabelecimentoID: UUID?, papel: PapelMembro?) {
        self.estabelecimentoID = estabelecimentoID
        self.papel = papel
    }
}

/// O que vale como convite: o link inteiro `https://<web>/.../convite#<64 hex>` ou só o código de 64 hexadecimais.
public enum ConviteDaCasa {
    /// Só o código: 64 caracteres hexadecimais, nada mais.
    public static func ehCodigo(_ texto: String) -> Bool {
        texto.utf8.count == 64 && texto.utf8.allSatisfy(ehHexadecimal)
    }

    /// Tira o token do que a pessoa colou. Vale **só** (a) o link do convite inteiro, `https://<host>[/<caminho>]/convite#<token>`,
    /// sem nada depois do código, ou (b) o código de 64 hex puro, depois de aparar os espaços das pontas. Qualquer outra
    /// coisa devolve `nil` e não chega ao servidor: texto com mais caracteres em volta, código no miolo de um identificador
    /// maior, hex de outro tamanho e mais de um código (o app nunca escolhe um em silêncio). O token sai em minúsculas,
    /// como a web.
    public static func extrairToken(de texto: String) -> String? {
        let colado = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        if ehCodigo(colado) { return colado.lowercased() }

        let esquema = "https://"
        guard colado.hasPrefix(esquema), !colado.contains(where: { $0.isWhitespace }) else { return nil }
        let semEsquema = colado.dropFirst(esquema.count)
        let partes = semEsquema.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        guard partes.count == 2, ehCodigo(String(partes[1])) else { return nil }

        let endereco = partes[0]
        guard !endereco.contains("?") else { return nil }
        let host = endereco.prefix { $0 != "/" }
        let caminho = endereco.dropFirst(host.count)
        guard !host.isEmpty, caminho.hasSuffix("/convite") else { return nil }
        return String(partes[1]).lowercased()
    }

    /// O link que o administrador compartilha: `<origem>/convite#<token>`, com a origem da web do ambiente do app
    /// (`https://frilabr.com/app` no Prod). `nil` se o token não é um código de 64 hex.
    public static func link(origem: String, token: String) -> String? {
        guard ehCodigo(token) else { return nil }
        var base = origem
        while base.hasSuffix("/") { base.removeLast() }
        return "\(base)/convite#\(token.lowercased())"
    }

    private static func ehHexadecimal(_ byte: UInt8) -> Bool {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"), UInt8(ascii: "a")...UInt8(ascii: "f"), UInt8(ascii: "A")...UInt8(ascii: "F"): true
        default: false
        }
    }
}

public extension ErroDaApi {
    /// `403 sem_permissao` sem `details`: a pessoa não é (mais) administrador desta casa. A casa que não existe e quem não
    /// é membro recebem a mesma recusa. Com `conta_suspensa` é outra coisa.
    var recusaDeAdministrador: Bool {
        codigo == .semPermissao && detalhes != CodigoErroAPI.contaSuspensa.rawValue
    }

    /// A conta está suspensa: `403 sem_permissao` com `details: conta_suspensa` (ou o código solto).
    var contaSuspensa: Bool {
        codigo == .contaSuspensa || (codigo == .semPermissao && detalhes == CodigoErroAPI.contaSuspensa.rawValue)
    }

    /// `422 convite_invalido`: o token não existe, já foi usado ou venceu.
    var conviteInvalido: Bool { codigoOriginal == "convite_invalido" }

    /// `422 ultimo_administrador`: tentou remover o único administrador da casa.
    var ultimoAdministrador: Bool { codigoOriginal == "ultimo_administrador" }
}
