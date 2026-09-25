import FrilaApresentacao
import FrilaDados
import FrilaDominio
import FrilaInfraestrutura
import OSLog
import SwiftUI

@main
struct FrilaApp: App {
    private static let logger = Logger(subsystem: "com.frila.org.app", category: "ambiente")
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
            switch inicializacao {
            case let .pronta(api):
                PortaoDeAtualizacao(viewModel: AtualizacaoObrigatoriaViewModel(api: api, versaoAtual: versao)) {
                    #if DEBUG
                    // A simulação de conflito chama `candidatar`: só roda contra o dublê, nunca contra um
                    // Supabase de verdade, para não criar candidatura real em nenhum ambiente.
                    CatalogoDesignSystem(api: api, permitirSimulacaoDeConflito: api is ApiClienteEmMemoria)
                    #else
                    TelaInicialDaFundacao()
                    #endif
                }
            case let .configuracaoInvalida(erro):
                TelaDeConfiguracaoInvalida(erro: erro)
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
