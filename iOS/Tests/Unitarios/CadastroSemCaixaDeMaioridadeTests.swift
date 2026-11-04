import Foundation
import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

/// Decisão da PO sobre o relatório da 0.5.5 (A5): o cadastro mantém só a data de nascimento, e o
/// sistema confere a maioridade (18+). A caixa redundante "sou maior de idade" não volta.
@Suite("Cadastro: maioridade só pela data de nascimento (A5)")
@MainActor
struct CadastroSemCaixaDeMaioridadeTests {
    private static let raiz = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// Relógio do sistema: as datas de nascimento dos testes (1995 e 2015) não mudam de lado até 2033.
    private func viewModel() -> CadastroViewModel {
        CadastroViewModel(api: ApiClienteEmMemoria(), email: "a5@frila.app")
    }

    @Test("Para quem tem 18 anos ou mais, nome, telefone, nascimento e termos bastam: não há outra confirmação de idade")
    func adultoSoPrecisaDaData() {
        let vm = viewModel()
        vm.nome = "Maria Souza"
        vm.telefone = "61999998888"
        vm.nascimentoTexto = "15/05/1995"
        #expect(!vm.formularioPreenchido, "falta aceitar os termos")
        vm.aceitouTermos = true
        #expect(vm.formularioPreenchido)
        #expect(!vm.ehMenorDeIdade)
    }

    @Test("A mesma ficha com data de menor de 18 não libera o formulário, e o sistema decide sem pergunta")
    func menorFicaBarradoPelaData() {
        let vm = viewModel()
        vm.nome = "João Souza"
        vm.telefone = "61999998888"
        vm.nascimentoTexto = "15/05/2015"
        vm.aceitouTermos = true
        #expect(vm.ehMenorDeIdade)
        #expect(!vm.formularioPreenchido)
    }

    @Test("A tela de cadastro tem uma única caixa de seleção (os termos) e nenhuma de maioridade")
    func telaSemCaixaDeMaioridade() throws {
        let fonte = try String(
            contentsOf: Self.raiz.appendingPathComponent("Sources/Apresentacao/Fluxos/Autenticacao/TelaCadastro.swift"),
            encoding: .utf8
        )
        #expect(!fonte.contains("Toggle("), "o cadastro não usa Toggle")
        #expect(fonte.components(separatedBy: "checkmark.square.fill").count == 2, "só a caixa dos termos usa o ícone de caixa marcada")
        for trecho in ["Tenho 18", "Sou maior", "sou maior", "declaro ter", "cadastro-maioridade", "cadastro-maior-de-idade"] {
            #expect(!fonte.contains(trecho), "\(trecho) indica a caixa de maioridade que a PO mandou tirar")
        }
        #expect(fonte.contains("cadastro-nascimento"))
        #expect(fonte.contains("cadastro-termos"))
    }

    @Test("A ficha do cadastro não tem campo de confirmação de maioridade além da data")
    func viewModelSemCampoDeMaioridade() throws {
        let fonte = try String(
            contentsOf: Self.raiz.appendingPathComponent("Sources/Apresentacao/Fluxos/Autenticacao/CadastroViewModel.swift"),
            encoding: .utf8
        )
        for trecho in ["aceitouMaioridade", "confirmouMaioridade", "maiorDeIdade:", "declarouMaioridade"] {
            #expect(!fonte.contains(trecho), "\(trecho)")
        }
    }
}
