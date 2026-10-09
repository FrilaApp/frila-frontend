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
    /// Quanto a abertura espera por `configuracao_do_app` antes de liberar o app. Sem rede o erro
    /// chega na hora; com rede ruim (pacote perdido, Wi‑Fi cativo, 3G fraco) a URLSession só desiste
    /// aos 60 s, e até lá a pessoa veria só o indicador de carregamento.
    public static let prazoPadrao: Duration = .seconds(3)

    public private(set) var estado: EstadoDaAtualizacao = .verificando
    private let api: any ApiCliente
    private let versaoAtual: String
    private let prazo: Duration

    public init(api: any ApiCliente, versaoAtual: String, prazo: Duration = AtualizacaoObrigatoriaViewModel.prazoPadrao) {
        self.api = api
        self.versaoAtual = versaoAtual
        self.prazo = prazo
    }

    /// Libera o app quando a resposta chega, quando a chamada falha ou quando o prazo vence, o que
    /// vier primeiro. A resposta que chegar depois do prazo ainda vale: se ela bloquear, bloqueia.
    public func verificar() async {
        estado = .verificando
        let liberacaoNoPrazo = Task { [prazo] in
            try? await Task.sleep(for: prazo)
            guard !Task.isCancelled, estado == .verificando else { return }
            estado = .liberado
        }
        defer { liberacaoNoPrazo.cancel() }
        do {
            let configuracao = try await api.configuracaoDoApp()
            if Self.comparar(versaoAtual, com: configuracao.versaoMinima) == .orderedAscending {
                estado = .bloqueado(mensagem: configuracao.mensagem ?? String(localized: "Atualize o Frila para continuar.", bundle: bundleApresentacao), url: configuracao.urlDaLoja)
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
                    Image(systemName: "arrow.down.app.fill").font(.largeTitle).foregroundStyle(FrilaCor.primaria).accessibilityHidden(true)
                    Text("Atualização necessária", bundle: bundleApresentacao)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: mensagem).multilineTextAlignment(.center).foregroundStyle(FrilaCor.textoSecundario)
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
