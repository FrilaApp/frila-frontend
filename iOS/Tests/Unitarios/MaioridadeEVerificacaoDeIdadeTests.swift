import Foundation
import FrilaApresentacao
import FrilaDados
import FrilaDominio
import FrilaInfraestrutura
import Testing

/// Testes unitários para o fluxo de verificação de maioridade 18+, Declared Age Range e proteção de menores (Cartão lJSyGK6q).
@Suite("Verificação de Maioridade 18+ (#lJSyGK6q)")
@MainActor
struct MaioridadeEVerificacaoDeIdadeTests {

    @Test("VerificadorDeIdadeDoSistema interpreta faixas etárias corretamente")
    func interpretarFaixasDeclaredAgeRange() {
        // Adultos (18 ou mais)
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: 18, upperBound: nil) == .dezoitoOuMais)
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: 21, upperBound: 25) == .dezoitoOuMais)
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: 18, upperBound: 18) == .dezoitoOuMais)

        // Menores de 18 anos
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: nil, upperBound: 17) == .abaixoDe18)
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: 13, upperBound: 17) == .abaixoDe18)
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: 10, upperBound: 16) == .abaixoDe18)

        // Indisponível / Inconclusivo
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: nil, upperBound: nil) == .indisponivel)
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: 16, upperBound: 20) == .indisponivel)
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: nil, upperBound: 18) == .indisponivel)
    }

    @Test("VerificadorDeIdadeIndisponivel retorna .indisponivel como fallback seguro")
    func verificadorIndisponivelFallback() async {
        let verificador = VerificadorDeIdadeIndisponivel()
        let resultado = await verificador.verificarMaioridade()
        #expect(resultado == .indisponivel)
    }

    @Test("Cadastro bloqueia preventivamente no cliente quando a data de nascimento tem menos de 18 anos")
    func cadastroBloqueiaMenorPorDataDeNascimento() async {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let agora = Date(timeIntervalSince1970: 1_792_065_600) // Outubro/2026
        let relogioFixo = RelogioFixo(agora: agora)
        let vm = CadastroViewModel(api: api, email: "jovem@frila.app", relogio: relogioFixo)

        vm.nome = "Jovem Aprendiz"
        vm.telefone = "61999991111"
        // Data correspondente a menor de 18 anos em 2026
        vm.nascimentoTexto = "01/01/2012"
        vm.maiorDeIdade = true
        vm.aceitouTermos = true

        let destino = await vm.criarConta()
        #expect(destino == nil)
        #expect(vm.erro == "O Frila é exclusivo para maiores de 18 anos.")
    }

    @Test("Cadastro bloqueia quando o Declared Age Range identifica usuário abaixo de 18")
    func cadastroBloqueiaMenorPorDeclaredAgeRange() async {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let verificador = VerificadorDeIdadeSimulado(resultado: .abaixoDe18)
        let vm = CadastroViewModel(api: api, email: "menor@frila.app", verificadorDeIdade: verificador)

        vm.nome = "Candidato Menor"
        vm.telefone = "61999992222"
        vm.nascimentoTexto = "01/01/2000" // Data declarada adulta
        vm.maiorDeIdade = true
        vm.aceitouTermos = true

        let destino = await vm.criarConta()
        #expect(destino == nil)
        #expect(vm.erro == "O Frila é exclusivo para maiores de 18 anos.")
        #expect(verificador.chamadasAVerificar == 1)
    }

    @Test("Cadastro prossegue quando maior de 18 anos pela data e pelo Declared Age Range")
    func cadastroSucessoMaiorDeIdade() async {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let agora = Date(timeIntervalSince1970: 1_792_065_600) // Outubro/2026
        let relogioFixo = RelogioFixo(agora: agora)
        let verificador = VerificadorDeIdadeSimulado(resultado: .dezoitoOuMais)
        let vm = CadastroViewModel(api: api, email: "adulto@frila.app", relogio: relogioFixo, verificadorDeIdade: verificador)

        vm.nome = "Profissional Adulto"
        vm.telefone = "61999993333"
        vm.nascimentoTexto = "01/01/2000" // 26 anos
        vm.maiorDeIdade = true
        vm.aceitouTermos = true

        let destino = await vm.criarConta()
        #expect(destino == .funcoesEHorarios)
        #expect(vm.erro == nil)
        #expect(verificador.chamadasAVerificar == 1)
    }
}
