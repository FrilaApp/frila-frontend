import Foundation
import FrilaDominio

/// O token de push e o vínculo com a conta, no Keychain deste aparelho (nunca em `UserDefaults`,
/// como a sessão). O item sobrevive à reinstalação do app: o FCM entrega um token novo na primeira
/// abertura, e o `AparelhoDePush` troca o guardado por ele.
public struct ArmazenamentoDoAparelhoNoKeychain: ArmazenamentoDoAparelho {
    private static let conta = "aparelho"
    private let keychain: ArmazenamentoKeychain

    public init(servico: String = "com.frila.org.app.push") {
        keychain = ArmazenamentoKeychain(servico: servico)
    }

    public func ler() -> AparelhoGuardado? {
        guard let dados = try? keychain.ler(conta: Self.conta) else { return nil }
        return try? JSONDecoder().decode(AparelhoGuardado.self, from: dados)
    }

    public func guardar(_ aparelho: AparelhoGuardado) {
        guard let dados = try? JSONEncoder().encode(aparelho) else { return }
        try? keychain.salvar(dados, conta: Self.conta)
    }
}
