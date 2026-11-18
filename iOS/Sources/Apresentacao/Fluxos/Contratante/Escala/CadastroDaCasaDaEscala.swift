import Foundation
import FrilaDominio
import Observation

public enum EstadoDoCadastroDaEscala: Equatable, Sendable {
    case carregando
    case pronta(Estabelecimento)
    case erro(mensagem: String)
}

/// Lê o cadastro da casa (endereço, região e ponto, que valem para todas as vagas da escala) para abrir a tela da escala.
/// Todo `await` de API do fluxo leva prazo e fallback: se a leitura passa do prazo, a tela mostra o erro com "Tentar de
/// novo" (e não o carregando para sempre).
@MainActor @Observable
public final class CadastroDaCasaDaEscala {
    public private(set) var estado: EstadoDoCadastroDaEscala = .carregando
    private let estabelecimentoID: UUID
    private let ler: @Sendable (UUID) async throws -> Estabelecimento
    private let prazo: Duration
    private var carregando = false

    public convenience init(api: any ApiCliente, estabelecimentoID: UUID, prazo: Duration = .seconds(15)) {
        self.init(estabelecimentoID: estabelecimentoID, prazo: prazo, ler: { try await api.meuEstabelecimento(id: $0) })
    }

    public init(estabelecimentoID: UUID, prazo: Duration = .seconds(15), ler: @escaping @Sendable (UUID) async throws -> Estabelecimento) {
        self.estabelecimentoID = estabelecimentoID
        self.prazo = prazo
        self.ler = ler
    }

    /// O que já foi lido fica guardado: abrir de novo na mesma sessão não volta à rede.
    public func carregar() async {
        if case .pronta = estado { return }
        guard !carregando else { return }
        carregando = true
        estado = .carregando
        defer { carregando = false }
        let id = estabelecimentoID
        let leitura = ler
        do {
            estado = .pronta(try await PrazoDaAbertura.esperar(prazo) { try await leitura(id) })
        } catch is CancellationError {
            // A saída da tela cancela o carregamento, sem apresentar uma falha de rede.
        } catch {
            estado = .erro(mensagem: MensagemDoErroAPI.texto(error as? ErroDaApi ?? ErroDaApi(codigo: .desconhecido)))
        }
    }
}
