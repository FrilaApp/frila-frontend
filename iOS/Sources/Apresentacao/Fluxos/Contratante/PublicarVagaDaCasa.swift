import FrilaDominio
import Observation
import SwiftUI

private enum TextosPublicarVagaDaCasa {
    static let voltar = String(localized: "Voltar para Minhas vagas", bundle: bundleApresentacao)
}

public enum EstadoDaPublicacaoDaCasa: Equatable, Sendable {
    case carregando
    case pronta(Estabelecimento, telefoneResponsavel: String)
    case erro(mensagem: String)
}

/// O que a publicação de uma vaga precisa de quem já tem estabelecimento: o cadastro da casa
/// (endereço, região e ponto, que preenchem a vaga) e o telefone do responsável. O cadastro vem de
/// `meu_estabelecimento` (contrato 0.2.29), porque `meus_estabelecimentos` não traz endereço.
@MainActor @Observable
public final class PublicacaoDaCasaViewModel {
    public private(set) var estado: EstadoDaPublicacaoDaCasa = .carregando
    private let estabelecimentoID: UUID
    private let estabelecimento: @Sendable (UUID) async throws -> Estabelecimento
    private let minhaConta: @Sendable () async throws -> Conta
    private var carregando = false

    public convenience init(api: any ApiCliente, estabelecimentoID: UUID) {
        self.init(estabelecimentoID: estabelecimentoID,
                  estabelecimento: { try await api.meuEstabelecimento(id: $0) },
                  minhaConta: { try await api.minhaConta() })
    }

    public init(
        estabelecimentoID: UUID,
        estabelecimento: @escaping @Sendable (UUID) async throws -> Estabelecimento,
        minhaConta: @escaping @Sendable () async throws -> Conta
    ) {
        self.estabelecimentoID = estabelecimentoID
        self.estabelecimento = estabelecimento
        self.minhaConta = minhaConta
    }

    /// O que já foi lido fica guardado: abrir a publicação de novo na mesma sessão não volta à
    /// rede, e funciona sem ela.
    public func carregar() async {
        if case .pronta = estado { return }
        guard !carregando else { return }
        carregando = true
        estado = .carregando
        defer { carregando = false }
        do {
            let casa = try await estabelecimento(estabelecimentoID)
            let conta = try await minhaConta()
            estado = .pronta(casa, telefoneResponsavel: conta.telefone)
        } catch is CancellationError {
            // A saída da tela cancela o carregamento, sem apresentar uma falha de rede.
        } catch {
            estado = .erro(mensagem: MensagemDoErroAPI.texto(error as? ErroDaApi ?? ErroDaApi(codigo: .desconhecido)))
        }
    }
}

/// A publicação de uma vaga a partir de Minhas vagas, para quem já tem estabelecimento. Lê o
/// cadastro da casa e abre o mesmo formulário do primeiro acesso.
public struct DestinoDePublicarVaga: View {
    private let api: any ApiCliente
    private let fila: any FilaDeAcoes
    private let modelo: PublicacaoDaCasaViewModel
    private let sair: () -> Void
    private let cancelar: () -> Void
    private let aoPublicar: () -> Void

    public init(
        api: any ApiCliente, fila: any FilaDeAcoes, modelo: PublicacaoDaCasaViewModel,
        sair: @escaping () -> Void = {}, cancelar: @escaping () -> Void, aoPublicar: @escaping () -> Void
    ) {
        self.api = api
        self.fila = fila
        self.modelo = modelo
        self.sair = sair
        self.cancelar = cancelar
        self.aoPublicar = aoPublicar
    }

    public var body: some View {
        Group {
            switch modelo.estado {
            case .carregando:
                ScrollView {
                    VStack(spacing: FrilaEspaco.medio) {
                        EstadoCarregando()
                        BotaoSecundario(verbatim: TextosPublicarVagaDaCasa.voltar, acao: cancelar)
                            .accessibilityIdentifier("voltar-para-minhas-vagas")
                    }
                    .padding(FrilaEspaco.medio)
                }
            case let .pronta(estabelecimento, telefone):
                TelaPublicarVaga(
                    api: api, fila: fila, estabelecimento: estabelecimento, telefoneResponsavel: telefone,
                    sair: sair, aoPublicar: aoPublicar, aoCancelar: cancelar
                )
            case let .erro(mensagem):
                ScrollView {
                    VStack(spacing: FrilaEspaco.medio) {
                        EstadoErro(verbatim: mensagem) { Task { await modelo.carregar() } }
                            .accessibilityIdentifier("publicar-vaga-erro")
                        BotaoSecundario(verbatim: TextosPublicarVagaDaCasa.voltar, acao: cancelar)
                            .accessibilityIdentifier("voltar-para-minhas-vagas")
                    }
                    .padding(FrilaEspaco.medio)
                }
            }
        }
        .task { await modelo.carregar() }
    }
}
