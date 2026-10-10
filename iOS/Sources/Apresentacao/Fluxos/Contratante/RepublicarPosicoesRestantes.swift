import FrilaDominio
import Observation
import SwiftUI

public enum TextosRepublicarPosicoesRestantes {
    public static let republicando = String(localized: "Republicando posições restantes…", bundle: bundleApresentacao)

    public static func rotuloBotao(_ posicoes: Int) -> String {
        if posicoes == 1 {
            return String(localized: "Republicar 1 posição em urgência", bundle: bundleApresentacao)
        }
        return String(format: String(localized: "Republicar %d posições em urgência", bundle: bundleApresentacao), posicoes)
    }

    // Recusas da RPC (contrato 0.2.41, RR-RN01, RR-RN03, RR-RN05)
    public static let jaRepublicada = String(localized: "As posições restantes desta vaga já foram republicadas em urgência.", bundle: bundleApresentacao)
    public static let semPosicoesRestantes = String(localized: "Todas as posições desta vaga foram preenchidas.", bundle: bundleApresentacao)
    public static let selecaoEmCurso = String(localized: "A seleção desta vaga ainda está em andamento.", bundle: bundleApresentacao)
    public static let jaComecou = String(localized: "O turno desta vaga já começou.", bundle: bundleApresentacao)
    public static let vagaCancelada = String(localized: "Esta vaga foi cancelada.", bundle: bundleApresentacao)
    public static let naoESelecao = String(localized: "Apenas vagas no modo seleção podem ser republicadas com este atalho.", bundle: bundleApresentacao)

    // Outras recusas
    public static let vagaOculta = String(localized: "Esta vaga foi ocultada pela moderação e não pode ser republicada.", bundle: bundleApresentacao)
    public static let perfilIncompativel = String(localized: "Apenas contas de contratante podem republicar vagas.", bundle: bundleApresentacao)
    public static let semPermissao = String(localized: "Você não tem permissão para republicar esta vaga.", bundle: bundleApresentacao)
    public static let contaSuspensa = String(localized: "Sua conta está suspensa e não pode republicar vagas.", bundle: bundleApresentacao)
    public static let naoEncontrado = String(localized: "A vaga original não foi encontrada.", bundle: bundleApresentacao)
    public static let semRede = String(localized: "Sem conexão com a internet. Tente novamente.", bundle: bundleApresentacao)
    public static let erroGenerico = String(localized: "Não foi possível republicar as posições restantes. Tente novamente.", bundle: bundleApresentacao)
    public static let republicacaoIndisponivelGenerico = String(localized: "A republicação desta vaga não está disponível.", bundle: bundleApresentacao)
}

@MainActor @Observable
public final class RepublicarPosicoesRestantesViewModel {
    public let vagaID: UUID
    public private(set) var posicoesRestantes: Int
    public private(set) var carregando = false
    public private(set) var erro: String?
    public private(set) var vagaPublicada: VagaPublicada?
    public private(set) var chaveAtual: UUID?

    private let republicarRPC: @Sendable (UUID, UUID) async throws -> VagaPublicada
    private let aoNavegarParaVaga: @MainActor (UUID) -> Void
    private let atualizarPainel: @MainActor () async -> Void

    public init(
        vagaID: UUID,
        posicoesRestantes: Int,
        api: any ApiCliente,
        aoNavegarParaVaga: @escaping @MainActor (UUID) -> Void = { _ in },
        atualizarPainel: @escaping @MainActor () async -> Void = {}
    ) {
        self.vagaID = vagaID
        self.posicoesRestantes = posicoesRestantes
        self.republicarRPC = { id, chave in
            try await api.republicarPosicoesRestantes(vagaID: id, chave: chave)
        }
        self.aoNavegarParaVaga = aoNavegarParaVaga
        self.atualizarPainel = atualizarPainel
    }

    public init(
        vagaID: UUID,
        posicoesRestantes: Int,
        republicarRPC: @escaping @Sendable (UUID, UUID) async throws -> VagaPublicada,
        aoNavegarParaVaga: @escaping @MainActor (UUID) -> Void = { _ in },
        atualizarPainel: @escaping @MainActor () async -> Void = {}
    ) {
        self.vagaID = vagaID
        self.posicoesRestantes = posicoesRestantes
        self.republicarRPC = republicarRPC
        self.aoNavegarParaVaga = aoNavegarParaVaga
        self.atualizarPainel = atualizarPainel
    }

    public func atualizarPosicoesRestantes(_ novas: Int) {
        guard novas > 0 else { return }
        posicoesRestantes = novas
    }

    public func executar() async {
        guard !carregando else { return }
        carregando = true
        erro = nil

        let chave = chaveAtual ?? UUID()
        chaveAtual = chave

        do {
            let resposta = try await republicarRPC(vagaID, chave)
            vagaPublicada = resposta
            chaveAtual = nil
            carregando = false
            await atualizarPainel()
            aoNavegarParaVaga(resposta.vagaID)
        } catch let erroApi as ErroDaApi {
            carregando = false
            await tratarErroApi(erroApi)
        } catch {
            carregando = false
            erro = TextosRepublicarPosicoesRestantes.semRede
        }
    }

    private func tratarErroApi(_ erroApi: ErroDaApi) async {
        switch erroApi.codigo {
        case .republicacaoIndisponivel:
            let motivo = erroApi.detalhes.flatMap(MotivoRepublicacaoIndisponivel.init(rawValue:))
            switch motivo {
            case .jaRepublicada:
                erro = TextosRepublicarPosicoesRestantes.jaRepublicada
            case .semPosicoesRestantes:
                erro = TextosRepublicarPosicoesRestantes.semPosicoesRestantes
            case .selecaoEmCurso:
                erro = TextosRepublicarPosicoesRestantes.selecaoEmCurso
            case .jaComecou:
                erro = TextosRepublicarPosicoesRestantes.jaComecou
            case .vagaCancelada:
                erro = TextosRepublicarPosicoesRestantes.vagaCancelada
            case .naoESelecao:
                erro = TextosRepublicarPosicoesRestantes.naoESelecao
            case nil:
                erro = TextosRepublicarPosicoesRestantes.republicacaoIndisponivelGenerico
            }
            await atualizarPainel()
        case .vagaOculta:
            erro = TextosRepublicarPosicoesRestantes.vagaOculta
        case .semPermissao:
            if erroApi.detalhes == "conta_suspensa" {
                erro = TextosRepublicarPosicoesRestantes.contaSuspensa
            } else {
                erro = TextosRepublicarPosicoesRestantes.semPermissao
            }
        case .naoEncontrado:
            erro = TextosRepublicarPosicoesRestantes.naoEncontrado
        case .perfilIncompativel:
            erro = TextosRepublicarPosicoesRestantes.perfilIncompativel
        case .semRede:
            erro = TextosRepublicarPosicoesRestantes.semRede
        default:
            erro = TextosRepublicarPosicoesRestantes.erroGenerico
        }
    }
}

public struct BotaoRepublicarPosicoesRestantes: View {
    @State private var viewModel: RepublicarPosicoesRestantesViewModel
    private let podeRepublicar: Bool
    private let posicoesRestantes: Int
    var idAcessibilidade: String

    public init(
        viewModel: RepublicarPosicoesRestantesViewModel,
        podeRepublicar: Bool = true,
        idAcessibilidade: String = "botao-republicar-posicoes-restantes"
    ) {
        _viewModel = State(initialValue: viewModel)
        self.podeRepublicar = podeRepublicar
        self.posicoesRestantes = viewModel.posicoesRestantes
        self.idAcessibilidade = idAcessibilidade
    }

    public init(
        vagaID: UUID,
        posicoesRestantes: Int,
        api: any ApiCliente,
        podeRepublicar: Bool = true,
        aoNavegarParaVaga: @escaping @MainActor (UUID) -> Void = { _ in },
        atualizarPainel: @escaping @MainActor () async -> Void = {},
        idAcessibilidade: String = "botao-republicar-posicoes-restantes"
    ) {
        _viewModel = State(initialValue: RepublicarPosicoesRestantesViewModel(
            vagaID: vagaID,
            posicoesRestantes: posicoesRestantes,
            api: api,
            aoNavegarParaVaga: aoNavegarParaVaga,
            atualizarPainel: atualizarPainel
        ))
        self.podeRepublicar = podeRepublicar
        self.posicoesRestantes = posicoesRestantes
        self.idAcessibilidade = idAcessibilidade
    }

    public init(
        vagaID: UUID,
        posicoesRestantes: Int,
        podeRepublicar: Bool = true,
        republicarRPC: @escaping @Sendable (UUID, UUID) async throws -> VagaPublicada,
        aoNavegarParaVaga: @escaping @MainActor (UUID) -> Void = { _ in },
        atualizarPainel: @escaping @MainActor () async -> Void = {},
        idAcessibilidade: String = "botao-republicar-posicoes-restantes"
    ) {
        _viewModel = State(initialValue: RepublicarPosicoesRestantesViewModel(
            vagaID: vagaID,
            posicoesRestantes: posicoesRestantes,
            republicarRPC: republicarRPC,
            aoNavegarParaVaga: aoNavegarParaVaga,
            atualizarPainel: atualizarPainel
        ))
        self.podeRepublicar = podeRepublicar
        self.posicoesRestantes = posicoesRestantes
        self.idAcessibilidade = idAcessibilidade
    }

    public var body: some View {
        if podeRepublicar || viewModel.erro != nil {
            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                if podeRepublicar {
                    Button {
                        Task { await viewModel.executar() }
                    } label: {
                        HStack(spacing: FrilaEspaco.pequeno) {
                            if viewModel.carregando {
                                ProgressView()
                                    .tint(FrilaCor.sobrePrimaria)
                                Text(verbatim: TextosRepublicarPosicoesRestantes.republicando)
                            } else {
                                Image(systemName: "bolt.fill")
                                    .accessibilityHidden(true)
                                Text(verbatim: TextosRepublicarPosicoesRestantes.rotuloBotao(viewModel.posicoesRestantes))
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FrilaCor.primaria)
                    .disabled(viewModel.carregando)
                    .accessibilityIdentifier(idAcessibilidade)
                }

                if let erro = viewModel.erro {
                    AvisoFrila(verbatim: erro, tom: .alerta)
                        .accessibilityIdentifier("\(idAcessibilidade)-erro")
                }
            }
            .onChange(of: posicoesRestantes) { _, novas in
                viewModel.atualizarPosicoesRestantes(novas)
            }
        }
    }
}
