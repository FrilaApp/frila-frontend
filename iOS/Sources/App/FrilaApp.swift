import FrilaApresentacao
import FrilaDados
import FrilaDominio
import FrilaInfraestrutura
import SwiftUI

@main
struct FrilaApp: App {
    private let inicializacao: Inicializacao
    private let versao: String

    init() {
        versao = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        do throws(ErroDeConfiguracao) {
            let ambiente = try ConfiguracaoAmbiente()
            inicializacao = .pronta(Self.cliente(para: ambiente.selecao))
        } catch {
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
                    CatalogoDesignSystem()
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
