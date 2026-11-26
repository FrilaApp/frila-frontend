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

/// O que vale como convite: o link inteiro `<origem da web>/convite#<64 hex>`, um texto com exatamente um link assim, ou só o
/// código de 64 hexadecimais.
public enum ConviteDaCasa {
    /// Só o código: 64 caracteres hexadecimais, nada mais.
    public static func ehCodigo(_ texto: String) -> Bool {
        texto.utf8.count == 64 && texto.utf8.allSatisfy(ehHexadecimal)
    }

    /// Tira o token do que a pessoa colou. Vale **só**: (a) o código de 64 hex puro; (b) o link do convite inteiro; ou (c) um
    /// texto (a mensagem do convite inteira, por exemplo) com **exatamente um** link de convite, no formato
    /// `<origem>/convite#<token>` com uma das `origens` do app (`https://frilabr.com/app` no Prod, a prévia de dev nos outros),
    /// procurado sem diferenciar maiúsculas. O
    /// link começa no início do texto ou depois de um espaço ou quebra de linha e termina no espaço, na quebra ou no fim, sem nada
    /// colado ao código. Outro domínio, outro caminho, `http`, parente do domínio (`frilabr.com.exemplo.org`, `exemplofrilabr.com`),
    /// dois links (iguais ou não, de um ambiente ou de dois), nenhum link, hex de outro tamanho, ou código solto no meio de um
    /// texto devolvem `nil` e não chegam ao servidor: o app nunca escolhe um em silêncio. O token sai em minúsculas, como a web;
    /// o servidor continua conferindo token e e-mail.
    public static func extrairToken(de texto: String, origens: [String]) -> String? {
        let colado = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        if ehCodigo(colado) { return colado.lowercased() }

        let ocorrencias = origens.flatMap { trechos("\($0)\(caminhoDoConvite)", em: colado) }
        guard ocorrencias.count == 1, let link = ocorrencias.first else { return nil }
        if link.lowerBound > colado.startIndex, !colado[colado.index(before: link.lowerBound)].isWhitespace { return nil }
        let codigo = String(colado[link.upperBound...].prefix { !$0.isWhitespace })
        guard ehCodigo(codigo) else { return nil }
        return codigo.lowercased()
    }

    /// O que vem depois da origem e antes do código: `<origem>/convite#<token>`.
    private static let caminhoDoConvite = "/convite#"

    /// Todas as vezes em que `trecho` aparece em `texto`, **sem diferenciar maiúsculas**: o esquema e o host não diferenciam, e
    /// um segundo link escrito em maiúsculas também tem de contar (senão o app escolheria o primeiro em silêncio).
    private static func trechos(_ trecho: String, em texto: String) -> [Range<String.Index>] {
        var achados: [Range<String.Index>] = []
        var inicio = texto.startIndex
        while let achado = texto.range(of: trecho, options: .caseInsensitive, range: inicio..<texto.endIndex) {
            achados.append(achado)
            inicio = achado.upperBound
        }
        return achados
    }

    /// O link que o administrador compartilha: `<origem>/convite#<token>`, com a origem da web do ambiente do app
    /// (`https://frilabr.com/app` no Prod). `nil` se o token não é um código de 64 hex.
    public static func link(origem: String, token: String) -> String? {
        guard ehCodigo(token) else { return nil }
        var base = origem
        while base.hasSuffix("/") { base.removeLast() }
        return "\(base)\(caminhoDoConvite)\(token.lowercased())"
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

    /// `403 convite_de_outro_email` (contrato 0.2.115): o e-mail da conta que aceita não é o do convite. Sem `details`, e o
    /// convite não é consumido: a pessoa certa ainda aceita. O código chega solto, como `convite_invalido`.
    var conviteDeOutroEmail: Bool { codigoOriginal == "convite_de_outro_email" }

    /// `422 ultimo_administrador`: tentou remover o único administrador da casa.
    var ultimoAdministrador: Bool { codigoOriginal == "ultimo_administrador" }
}
