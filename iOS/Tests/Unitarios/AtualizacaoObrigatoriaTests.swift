import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

/// Servidor com rede ruim: `configuracao_do_app` só responde depois de `demora`, com o que o
/// cenário do dublê responderia.
private final class ApiLenta: ApiClienteEncaminhador, @unchecked Sendable {
    private let demora: Duration

    init(cenario: ApiClienteEmMemoria.Cenario, demora: Duration) {
        self.demora = demora
        super.init(base: ApiClienteEmMemoria(cenario: cenario))
    }

    override func configuracaoDoApp() async throws -> ConfiguracaoApp {
        try await Task.sleep(for: demora)
        return try await base.configuracaoDoApp()
    }
}

@Suite("Versão mínima") @MainActor
struct AtualizacaoObrigatoriaTests {
    /// Espera até `condicao` valer, no máximo `limite`; devolve se valeu.
    private func esperar(ate limite: Duration, _ condicao: @MainActor () -> Bool) async -> Bool {
        let relogio = ContinuousClock()
        let fim = relogio.now + limite
        while relogio.now < fim {
            if condicao() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return condicao()
    }

    @Test("Rede ruim: sem resposta no prazo, o app abre em vez de ficar no indicador até a URLSession desistir")
    func prazoLibera() async {
        let vm = AtualizacaoObrigatoriaViewModel(
            api: ApiLenta(cenario: .sucesso, demora: .seconds(30)), versaoAtual: "1.0.0", prazo: .milliseconds(100)
        )
        let verificacao = Task { await vm.verificar() }
        defer { verificacao.cancel() }
        #expect(vm.estado == .verificando)
        let liberou = await esperar(ate: .seconds(2)) { vm.estado == .liberado }
        #expect(liberou, "o prazo de 100 ms devia liberar o app; estado: \(vm.estado)")
    }

    @Test("Resposta que chega depois do prazo ainda vale: se ela bloqueia, bloqueia")
    func respostaAtrasadaBloqueia() async {
        let vm = AtualizacaoObrigatoriaViewModel(
            api: ApiLenta(cenario: .atualizacaoObrigatoria, demora: .milliseconds(300)), versaoAtual: "1.0.0", prazo: .milliseconds(50)
        )
        let verificacao = Task { await vm.verificar() }
        let liberouAntes = await esperar(ate: .seconds(2)) { vm.estado == .liberado }
        #expect(liberouAntes, "até a resposta chegar, o app fica liberado; estado: \(vm.estado)")
        await verificacao.value
        guard case .bloqueado = vm.estado else { Issue.record("Esperava bloqueio depois da resposta; estado: \(vm.estado)"); return }
    }

    @Test("Resposta dentro do prazo libera na hora, sem esperar o prazo")
    func respostaRapidaNaoEsperaOPrazo() async {
        let vm = AtualizacaoObrigatoriaViewModel(api: ApiClienteEmMemoria(), versaoAtual: "1.0.0", prazo: .seconds(30))
        let relogio = ContinuousClock()
        let inicio = relogio.now
        await vm.verificar()
        #expect(vm.estado == .liberado)
        #expect(relogio.now - inicio < .seconds(5))
    }

    @Test("Comparação semântica não compara strings lexicograficamente")
    func comparar() {
        #expect(AtualizacaoObrigatoriaViewModel.comparar("1.10.0", com: "1.9.9") == .orderedDescending)
        #expect(AtualizacaoObrigatoriaViewModel.comparar("1.2", com: "1.2.0") == .orderedSame)
    }

    @Test("Configuração mais nova bloqueia")
    func bloqueio() async {
        let vm = AtualizacaoObrigatoriaViewModel(api: ApiClienteEmMemoria(cenario: .atualizacaoObrigatoria), versaoAtual: "1.0.0")
        await vm.verificar()
        guard case .bloqueado = vm.estado else { Issue.record("Esperava bloqueio"); return }
    }

    @Test("Offline libera o app")
    func offline() async {
        let vm = AtualizacaoObrigatoriaViewModel(api: ApiClienteEmMemoria(cenario: .semRede), versaoAtual: "1.0.0")
        await vm.verificar()
        #expect(vm.estado == .liberado)
    }
}
