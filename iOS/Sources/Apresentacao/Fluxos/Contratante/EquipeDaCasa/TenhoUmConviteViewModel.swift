import FrilaDominio
import Observation
import SwiftUI

/// A casa em que a pessoa entrou e com que papel (o servidor responde os dois; ambos podem faltar).
public struct ConviteAceito: Equatable, Sendable {
    public let estabelecimentoID: UUID?
    public let papel: PapelMembro?
}

/// "Tenho um convite" (RF21; o app não abre o link sozinho, sem deep link): a pessoa cola o link, o código ou a mensagem do
/// convite inteira e o app tira o token e chama `aceitar_convite_membro`. Só vale o código de 64 hexadecimais, o link do convite
/// do Frila ou um texto com exatamente um link assim (`ConviteDaCasa.extrairToken`): qualquer outra coisa vira "link ou código
/// inválido" **sem chamar o servidor**. Cada recusa do servidor (`convite_invalido`, `perfil_incompativel`, sessão, sem rede) vira texto do Frila.
///
/// Um convite é de uso único: depois de uma falha incerta (prazo vencido, resposta ilegível), repetir pode dar
/// `convite_invalido` se o primeiro já tiver sido aceito, e por isso a mensagem de falha incerta avisa onde conferir. O token
/// colado vive só aqui, na memória, e some quando o convite é aceito.
@MainActor @Observable
public final class TenhoUmConviteViewModel {
    public var texto = "" {
        didSet {
            guard texto != oldValue, !devolvendo else { return }
            if enviando || aceito != nil {
                // Devolver o valor dentro do `didSet` o dispara outra vez (o `@Observable` reenvia a atribuição).
                devolvendo = true
                texto = oldValue
                devolvendo = false
            } else {
                erro = nil
            }
        }
    }
    public private(set) var enviando = false
    /// A recusa em texto do Frila, junto ao botão.
    public private(set) var erro: String?
    public private(set) var aceito: ConviteAceito?

    /// Os links de convite que o app reconhece: os da web de produção e da de dev, as mesmas origens com que monta o link.
    static let origens = [OrigemDaWeb.producao, OrigemDaWeb.dev]

    private var devolvendo = false
    private let aceitar: @Sendable (String) async throws -> MembroAdicionado
    private let prazo: Duration

    public convenience init(api: any ApiCliente, prazo: Duration = .seconds(20)) {
        self.init(prazo: prazo, aceitar: { try await api.aceitarConviteDeMembro(token: $0) })
    }

    public init(prazo: Duration = .seconds(20), aceitar: @escaping @Sendable (String) async throws -> MembroAdicionado) {
        self.prazo = prazo
        self.aceitar = aceitar
    }

    /// O texto tem a forma de um convite? Só assim o botão fala com o servidor.
    public var textoTemFormaDeConvite: Bool { ConviteDaCasa.extrairToken(de: texto, origens: Self.origens) != nil }

    public func aceitarConvite() async {
        guard !enviando, aceito == nil else { return }
        guard let token = ConviteDaCasa.extrairToken(de: texto, origens: Self.origens) else {
            erro = TextosDaEquipeDaCasa.conviteFormatoInvalido
            return
        }
        enviando = true
        erro = nil
        let chamada = aceitar
        do {
            let membro = try await PrazoDaAbertura.esperar(prazo) { try await chamada(token) }
            enviando = false
            texto = ""
            aceito = ConviteAceito(estabelecimentoID: membro.estabelecimentoID, papel: membro.papel)
        } catch {
            enviando = false
            guard !Task.isCancelled else { return }
            self.erro = Self.mensagem(error)
        }
    }

    private static func mensagem(_ falha: Error) -> String {
        guard let erro = falha as? ErroDaApi else { return TextosDaEquipeDaCasa.conviteIncerto }
        if erro.conviteInvalido { return TextosDaEquipeDaCasa.conviteInvalido }
        // 403 sem `details` (contrato 0.2.115): a conta que aceita não é a do e-mail do convite. O convite segue valendo.
        if erro.conviteDeOutroEmail { return TextosDaEquipeDaCasa.conviteDeOutroEmail }
        if erro.contaSuspensa { return TextosDaEquipeDaCasa.contaSuspensa }
        switch erro.codigo {
        case .perfilIncompativel: return TextosDaEquipeDaCasa.convitePerfilIncompativel
        case .naoAutenticado: return TextosDaEquipeDaCasa.sessao
        case .semRede:
            // O prazo vencido não diz se o servidor chegou a aceitar: a mensagem avisa onde conferir.
            return erro.codigoOriginal == PrazoDaAbertura.codigoOriginal
                ? TextosDaEquipeDaCasa.conviteIncerto : TextosDaEquipeDaCasa.semRede
        default: return TextosDaEquipeDaCasa.conviteIncerto
        }
    }
}
