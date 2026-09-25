import FrilaApresentacao
import FrilaDados
import FrilaDominio
import FrilaInfraestrutura
import OSLog
import SwiftUI

@main
struct FrilaApp: App {
    private static let logger = Logger(subsystem: "com.frila.org.app", category: "ambiente")
    private static let chaveRetornoDeAutenticacao = "frila.debug.retorno-de-autenticacao"
    private let inicializacao: Inicializacao
    private let versao: String

    init() {
        let versao = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        self.versao = versao
        do throws(ErroDeConfiguracao) {
            let ambiente = try ConfiguracaoAmbiente()
            Self.logger.notice("inicio \(ambiente.resumoParaLog, privacy: .public) versao=\(versao, privacy: .public)")
            inicializacao = .pronta(Self.cliente(para: ambiente.selecao))
        } catch {
            Self.logger.error("inicio configuracao_invalida \(error.description, privacy: .public)")
            inicializacao = .configuracaoInvalida(error)
        }
        ColetorMetricKit.compartilhado.iniciar()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch inicializacao {
                case let .pronta(api):
                    PortaoDeAtualizacao(viewModel: AtualizacaoObrigatoriaViewModel(api: api, versaoAtual: versao)) {
                        #if DEBUG
                        CatalogoDesignSystem(api: api, permitirSimulacaoDeConflito: Self.permiteSimulacaoDeConflito)
                        #else
                        TelaInicialDaFundacao()
                        #endif
                    }
                case let .configuracaoInvalida(erro):
                    TelaDeConfiguracaoInvalida(erro: erro)
                }
            }
            .onOpenURL { url in
                guard case let .pronta(api) = inicializacao,
                      let cliente = api as? SupabaseApiCliente,
                      url.scheme == "com.frila.org.app"
                else { return }

                Task {
                    do {
                        try await cliente.processarRetornoDeAutenticacao(url: url)
                        await MainActor.run {
                            UserDefaults.standard.set(true, forKey: Self.chaveRetornoDeAutenticacao)
                        }
                    } catch {
                        Self.logger.error("retorno_auth falhou codigo=\(String(reflecting: type(of: error)), privacy: .public)")
                    }
                }
            }
        }
    }

    private static func cliente(para selecao: SelecaoDeAPI) -> any ApiCliente {
        switch selecao {
        case .emMemoria:
            ApiClienteEmMemoria.pelosArgumentos()
        case let .supabase(url, chavePublicavel):
            SupabaseApiCliente(url: url, chavePublicavel: chavePublicavel, telemetria: TelemetriaMetricKit())
        }
    }

    private static var permiteSimulacaoDeConflito: Bool {
        #if LOCAL
        true
        #else
        false
        #endif
    }
}

private enum Inicializacao {
    case pronta(any ApiCliente)
    case configuracaoInvalida(ErroDeConfiguracao)
}

private struct TelaInicialDaFundacao: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "briefcase.fill").font(.largeTitle)
            Text("Frila").font(.title.bold())
        }
        .accessibilityElement(children: .combine)
    }
}

/// Dev e Prod sem Supabase param aqui, com o motivo, em vez de abrir com dados simulados.
private struct TelaDeConfiguracaoInvalida: View {
    let erro: ErroDeConfiguracao

    var body: some View {
        ContentUnavailableView {
            Label("Configuração incompleta", systemImage: "exclamationmark.triangle.fill")
        } description: {
            Text(verbatim: erro.description)
        }
        .accessibilityIdentifier("configuracao-invalida")
    }
}
