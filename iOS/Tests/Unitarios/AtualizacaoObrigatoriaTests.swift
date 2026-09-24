import FrilaApresentacao
import FrilaDados
import Testing

@Suite("Versão mínima") @MainActor
struct AtualizacaoObrigatoriaTests {
    @Test("Comparação semântica não compara strings lexicograficamente")
    func comparar() {
        #expect(AtualizacaoObrigatoriaViewModel.comparar("1.10.0", com: "1.9.9") == .orderedDescending)
        #expect(AtualizacaoObrigatoriaViewModel.comparar("1.2", com: "1.2.0") == .orderedSame)
    }

    @Test("Configuração mais nova bloqueia")
    func bloqueio() async {
        let vm = AtualizacaoObrigatoriaViewModel(api: ApiClienteEmMemoria(cenario: .contaSuspensa), versaoAtual: "1.0.0")
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
