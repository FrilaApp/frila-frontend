import Foundation

/// Onde o `vinculo_id` do aparelho fica para a extensão de notificação ler (#253). O Keychain do
/// app é só dele; a extensão roda em outro processo, antes de o app ver o aviso, e só alcança o
/// que está no App Group. Falha ao gravar ou ao ler não derruba nada: sem o guardado, a extensão
/// troca o texto do aviso, que é o lado seguro (RN15).
public protocol ArmazenamentoDoVinculoCompartilhado: Sendable {
    func ler() -> UUID?
    /// `nil` apaga: sem sessão ou sem vínculo, a extensão não tem com o que conferir.
    func guardar(_ vinculoID: UUID?)
}

/// O `vinculo_id` no `UserDefaults` do App Group, que o app e a extensão compartilham. Só ele vai
/// para lá: o id é opaco (contrato 0.2.30), não é a conta nem o token e não identifica a pessoa
/// fora do servidor. O token e a conta continuam no Keychain do app.
public struct VinculoNoGrupoDoApp: ArmazenamentoDoVinculoCompartilhado {
    /// O App Group do app e da extensão, o mesmo dos dois entitlements.
    public static let grupo = "group.com.frila.org.app"
    private static let chave = "vinculo_id"
    private let grupo: String

    public init(grupo: String = Self.grupo) {
        self.grupo = grupo
    }

    /// `UserDefaults` não é `Sendable`: a suíte é aberta a cada uso, e o Foundation a guarda.
    private var defaults: UserDefaults? { UserDefaults(suiteName: grupo) }

    public func ler() -> UUID? {
        defaults?.string(forKey: Self.chave).flatMap(UUID.init(uuidString:))
    }

    public func guardar(_ vinculoID: UUID?) {
        if let vinculoID {
            defaults?.set(vinculoID.uuidString.lowercased(), forKey: Self.chave)
        } else {
            defaults?.removeObject(forKey: Self.chave)
        }
    }
}

/// O que a extensão de notificação recebe do sistema e devolve a ele: os textos do aviso e os
/// campos de texto do payload (os de `data`, que o FCM entrega na raiz do `userInfo`).
public struct ConteudoDoPush: Equatable, Sendable {
    public var titulo: String
    public var subtitulo: String
    public var corpo: String
    public var payload: [String: String]

    public init(titulo: String, subtitulo: String = "", corpo: String, payload: [String: String]) {
        self.titulo = titulo
        self.subtitulo = subtitulo
        self.corpo = corpo
        self.payload = payload
    }
}

/// A conferência que a extensão faz antes de o sistema mostrar o aviso, com o app fechado ou em
/// segundo plano (#253). O push de `mutable-content: 1` passa por aqui; o `vinculo_id` dele é
/// comparado ao que o app guardou no App Group ao registrar o aparelho (contrato 0.2.30).
///
/// - Sem `vinculo_id` (servidor anterior à 0.2.30): o aviso segue como veio, e vale a regra
///   antiga do cliente, pelo relógio, quando o app o receber.
/// - `vinculo_id` igual ao guardado: o aviso é de quem está no aparelho, e segue como veio.
/// - `vinculo_id` diferente, ou nada guardado (ninguém dentro): o aviso é de outra conta que
///   esteve neste aparelho. O texto vira o neutro e o payload sai, para a central e a tela de
///   bloqueio não mostrarem função, endereço ou valor de outra pessoa e o toque não abrir nada.
public enum FiltroDoPushPorVinculo {
    /// A chave do `vinculo_id` entre os dados do push, ao lado de `tipo` e dos ids do destino.
    public static let chaveDoVinculo = "vinculo_id"

    /// O texto do aviso de outra conta. Neutro de propósito: só diz que há algo no app, sem o tipo
    /// nem o destino. Pendente de Design (cartão #253): esta é a redação de exemplo da missão.
    public static let tituloNeutro = "Frila"
    public static let corpoNeutro = "Nova notificação disponível"

    public enum Decisao: Equatable, Sendable {
        case manter
        case neutralizar
    }

    /// `vinculoAtivo` é o que está no App Group: `nil` quando ninguém está dentro ou o servidor não
    /// devolveu vínculo. Um `vinculo_id` que não é UUID conta como de outra conta.
    public static func decidir(payload: [AnyHashable: Any], vinculoAtivo: UUID?) -> Decisao {
        guard let texto = payload[chaveDoVinculo] as? String else { return .manter }
        guard let vinculoDoAviso = UUID(uuidString: texto), let vinculoAtivo else { return .neutralizar }
        return vinculoDoAviso == vinculoAtivo ? .manter : .neutralizar
    }

    /// O conteúdo que o sistema mostra: o original, ou o neutro sem payload.
    public static func filtrar(_ conteudo: ConteudoDoPush, vinculoAtivo: UUID?) -> ConteudoDoPush {
        switch decidir(payload: conteudo.payload, vinculoAtivo: vinculoAtivo) {
        case .manter:
            return conteudo
        case .neutralizar:
            return ConteudoDoPush(titulo: tituloNeutro, corpo: corpoNeutro, payload: [:])
        }
    }
}
