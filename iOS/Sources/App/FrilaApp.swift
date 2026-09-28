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
                    EntradaDoApp(api: api)
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

/// Decide o que o app abre. Com o dublê (esquema Local), ou com sessão guardada no Dev e no Prod, abre
/// a lista de vagas do profissional (#104). Sem sessão, fica a tela de antes: a entrada por código é de
/// outro cartão. Quando a sessão é encerrada (401 ou saída), reavalia.
/// Limite: `possuiSessao()` pode precisar da rede para renovar; offline com sessão guardada, cai na
/// tela de antes até a próxima abertura.
private struct EntradaDoApp: View {
    let api: any ApiCliente
    @State private var roteador = RoteadorDoProfissional()
    @State private var comSessao: Bool?
    #if DEBUG
    @State private var mostrandoCatalogo = false
    #endif

    var body: some View {
        Group {
            #if DEBUG
            // Os UI tests do catálogo pedem o catálogo explicitamente; sem o argumento, o Local abre na lista.
            if ProcessInfo.processInfo.arguments.contains("-FRILA_ABRIR_CATALOGO") {
                catalogo
            } else {
                fluxoOuTelaSemSessao
            }
            #else
            fluxoOuTelaSemSessao
            #endif
        }
        .task { await avaliarSessao() }
        .task {
            guard let observador = api as? any ObservadorDeSessao else { return }
            for await _ in observador.encerramentos() {
                roteador.voltarParaLista()
                await avaliarSessao()
            }
        }
    }

    @ViewBuilder
    private var fluxoOuTelaSemSessao: some View {
        switch mostrarFluxo {
        case nil:
            EstadoCarregando()
        case true?:
            #if DEBUG
            FluxoDoProfissional(api: api, roteador: roteador) {
                Button("Catálogo") { mostrandoCatalogo = true }
                    .accessibilityHint("Abre o catálogo de componentes, só em Debug")
            }
            .sheet(isPresented: $mostrandoCatalogo) { catalogo }
            #else
            FluxoDoProfissional(api: api, roteador: roteador)
            #endif
        case false?:
            #if DEBUG
            catalogo
            #else
            TelaInicialDaFundacao()
            #endif
        }
    }

    #if DEBUG
    // A simulação de conflito chama `candidatar`: só roda contra o dublê, nunca contra um Supabase de
    // verdade, para não criar candidatura real em nenhum ambiente.
    private var catalogo: some View {
        CatalogoDesignSystem(api: api, permitirSimulacaoDeConflito: api is ApiClienteEmMemoria)
    }
    #endif

    private var mostrarFluxo: Bool? {
        api is ApiClienteEmMemoria ? true : comSessao
    }

    private func avaliarSessao() async {
        guard !(api is ApiClienteEmMemoria) else { return }
        comSessao = await api.possuiSessao()
    }
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
