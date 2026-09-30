import Foundation
import FrilaDominio
import Testing
@testable import FrilaApresentacao

@MainActor
@Suite("Cadastro do estabelecimento (#99)")
struct CadastroEstabelecimentoTests {
    @Test("Máscara mantém CPF e CNPJ visualmente formatados e envia apenas dígitos")
    func mascara() {
        let vm = CadastroEstabelecimentoViewModel { _ in throw ErroDaApi(codigo: .desconhecido) }
        vm.atualizarDocumento("12345678901")
        #expect(vm.documentoFormatado == "123.456.789-01")
        vm.atualizarDocumento("12345678000199")
        #expect(vm.documentoFormatado == "12.345.678/0001-99")
        #expect(vm.documento == "12345678000199")
    }

    @Test("Cadastro bem-sucedido conclui o formulário")
    func sucesso() async throws {
        let vm = CadastroEstabelecimentoViewModel { cadastro in
            #expect(cadastro.documento == "12345678901")
            #expect(cadastro.tipo == .foodService)
            return Estabelecimento(id: UUID(), nome: cadastro.nome, documento: cadastro.documento, tipo: cadastro.tipo, endereco: cadastro.endereco, ponto: cadastro.ponto)
        }
        preencher(vm)
        await vm.salvar()
        #expect(vm.concluido)
        #expect(vm.erro == nil)
    }

    @Test("409 de documento duplicado mostra estado próprio")
    func duplicado() async {
        let vm = CadastroEstabelecimentoViewModel { _ in throw ErroDaApi(codigo: .documentoJaCadastrado) }
        preencher(vm)
        await vm.salvar()
        #expect(vm.erro == .documentoDuplicado)
    }

    @Test("422 campo obrigatório e inválido focam o campo indicado")
    func errosPorCampo() async {
        for (regra, codigo) in [(RegraCampoCadastro.obrigatorio, CodigoErroAPI.campoObrigatorio), (.invalido, .campoInvalido)] {
            let vm = CadastroEstabelecimentoViewModel { _ in throw ErroDaApi(codigo: codigo, detalhes: "documento") }
            preencher(vm)
            await vm.salvar()
            #expect(vm.erro == .campo(.documento, regra))
        }
    }

    private func preencher(_ vm: CadastroEstabelecimentoViewModel) {
        vm.nome = "Bar Frila"
        vm.atualizarDocumento("12345678901")
        vm.endereco = "Brasília, DF"
        vm.ponto = .init(latitude: -15.78, longitude: -47.93)
    }
}
