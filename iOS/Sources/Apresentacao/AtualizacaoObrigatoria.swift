import FrilaDominio
import Observation
import SwiftUI

public enum EstadoDaAtualizacao: Equatable, Sendable {
    case verificando
    case liberado
    case bloqueado(mensagem: String, url: URL)
}

@MainActor @Observable
public final class AtualizacaoObrigatoriaViewModel {
    public private(set) var estado: EstadoDaAtualizacao = .verificando
    private let api: any ApiCliente
    private let versaoAtual: String

    public init(api: any ApiCliente, versaoAtual: String) {
        self.api = api
        self.versaoAtual = versaoAtual
    }

    public func verificar() async {
        estado = .verificando
        do {
            let configuracao = try await api.configuracaoDoApp()
            if Self.comparar(versaoAtual, com: configuracao.versaoMinimaIOS) == .orderedAscending {
                estado = .bloqueado(mensagem: configuracao.mensagem, url: configuracao.urlDaLoja)
            } else {
                estado = .liberado
            }
        } catch {
            // Falha/offline nunca impede o acesso: a checagem volta na próxima abertura.
            estado = .liberado
        }
    }

    public static func comparar(_ atual: String, com minima: String) -> ComparisonResult {
        let esquerda = componentes(atual)
        let direita = componentes(minima)
        for indice in 0..<max(esquerda.count, direita.count) {
            let a = indice < esquerda.count ? esquerda[indice] : 0
            let b = indice < direita.count ? direita[indice] : 0
            if a < b { return .orderedAscending }
            if a > b { return .orderedDescending }
        }
        return .orderedSame
    }

    private static func componentes(_ versao: String) -> [Int] {
        versao.split(separator: ".").map { parte in Int(parte.prefix { $0.isNumber }) ?? 0 }
    }
}

public struct PortaoDeAtualizacao<Conteudo: View>: View {
    @State private var viewModel: AtualizacaoObrigatoriaViewModel
    @Environment(\.openURL) private var abrirURL
    private let conteudo: () -> Conteudo

    public init(viewModel: AtualizacaoObrigatoriaViewModel, @ViewBuilder conteudo: @escaping () -> Conteudo) {
        _viewModel = State(initialValue: viewModel)
        self.conteudo = conteudo
    }

    public var body: some View {
        Group {
            switch viewModel.estado {
            case .verificando:
                EstadoCarregando()
            case .liberado:
                conteudo()
            case let .bloqueado(mensagem, url):
                VStack(spacing: FrilaEspaco.grande) {
                    Image(systemName: "arrow.down.app.fill").font(.system(size: 52)).foregroundStyle(FrilaCor.primaria).accessibilityHidden(true)
                    Text("Atualização necessária").font(.title.bold()).multilineTextAlignment(.center)
                    Text(mensagem).multilineTextAlignment(.center).foregroundStyle(FrilaCor.textoSecundario)
                    BotaoPrimario("Atualizar agora") { abrirURL(url) }
                }
                .padding(FrilaEspaco.grande)
                .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
                .accessibilityElement(children: .contain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FrilaCor.fundo.ignoresSafeArea())
        .task { await viewModel.verificar() }
    }
}
