import Foundation
import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

@Suite("Preferências de chamada: Aceito chamadas diretas (busca, 0.2.88)")
@MainActor
struct PreferenciasBuscaTests {
    @Test("A versão do texto cabe no contrato (1 a 20 caracteres)")
    func versaoDoTexto() {
        #expect((1...20).contains(PreferenciasChamadaViewModel.versaoDoTextoDaBusca.count))
    }

    @Test("Aparece na busca só com o aceite ligado e sem pendência")
    func apareceNaBusca() {
        let vm = PreferenciasChamadaViewModel(api: ApiClienteEmMemoria(cenario: .buscaDeProfissionais))
        #expect(!vm.apareceNaBusca)
        vm.aceitaChamadas = true
        #expect(vm.apareceNaBusca) // sem resposta do servidor ainda, nada pendente
    }

    @Test("Sem mexer no Aceito chamadas diretas, salvar outra preferência não manda o campo (nem com a chave desligada)")
    func naoMandaSemMexer() async {
        let vm = PreferenciasChamadaViewModel(api: ApiClienteEmMemoria(cenario: .chamadaDireta)) // busca desligada
        vm.antecedenciaMinimaH = 12
        await vm.salvar()
        #expect(vm.sucesso)
        #expect(vm.erro == nil)
        #expect(!vm.aceitaChamadas)
        #expect(vm.pendenciasParaBusca.isEmpty)
    }

    @Test("Ligar manda aceita_chamadas com a versão do texto; a resposta traz as pendências")
    func ligarComVersaoDoTexto() async {
        // O dublê recusa ligar sem a versão (campo_obrigatorio): salvar com sucesso prova que ela foi.
        let vm = PreferenciasChamadaViewModel(api: ApiClienteEmMemoria(cenario: .buscaDeProfissionais))
        vm.aceitaChamadas = true
        await vm.salvar()
        #expect(vm.sucesso)
        #expect(vm.erro == nil)
        #expect(vm.aceitaChamadas)
        #expect(vm.apareceNaBusca == vm.pendenciasParaBusca.isEmpty)
    }

    @Test("Desligar zera as pendências e tira da busca")
    func desligar() async {
        let vm = PreferenciasChamadaViewModel(api: ApiClienteEmMemoria(cenario: .buscaDeProfissionais))
        vm.aceitaChamadas = true
        await vm.salvar()
        vm.aceitaChamadas = false
        await vm.salvar()
        #expect(vm.sucesso)
        #expect(!vm.aceitaChamadas)
        #expect(vm.pendenciasParaBusca.isEmpty)
        #expect(!vm.apareceNaBusca)
    }

    @Test("Com a chave da busca desligada, ligar volta como recurso desligado")
    func chaveDesligada() async {
        let vm = PreferenciasChamadaViewModel(api: ApiClienteEmMemoria(cenario: .chamadaDireta))
        vm.aceitaChamadas = true
        await vm.salvar()
        #expect(!vm.sucesso)
        #expect(vm.erro == TextosChamadaDireta.desligado)
    }
}
