import FrilaApresentacao
import FrilaDados
import FrilaDominio
import FrilaInfraestrutura
import SwiftUI

@main
struct FrilaApp: App {
    private let api: any ApiCliente
    private let versao: String

    init() {
        let ambiente = ConfiguracaoAmbiente()
        versao = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        if ambiente.modoAPI == .supabase,
           let url = ambiente.supabaseURL,
           !ambiente.chavePublicavel.isEmpty,
           !ambiente.chavePublicavel.contains("not-configured") {
            api = SupabaseApiCliente(url: url, chavePublicavel: ambiente.chavePublicavel, telemetria: TelemetriaMetricKit())
        } else {
            api = ApiClienteEmMemoria.pelosArgumentos()
        }
        ColetorMetricKit.compartilhado.iniciar()
    }

    var body: some Scene {
        WindowGroup {
            PortaoDeAtualizacao(viewModel: AtualizacaoObrigatoriaViewModel(api: api, versaoAtual: versao)) {
                #if DEBUG
                CatalogoDesignSystem()
                #else
                TelaInicialDaFundacao()
                #endif
            }
        }
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
