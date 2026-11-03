import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

@Suite("Horários da semana: chips de 30 minutos e troca segura")
struct HorariosDaSemanaTests {
    private func hora(_ h: Int, _ m: Int = 0) throws -> HoraDoDia {
        try HoraDoDia(hora: h, minuto: m)
    }

    // MARK: - Opções

    @Test("os passos são 48, de 00:00 a 23:30, de 30 em 30 minutos")
    func passosDoDia() throws {
        let passos = OpcoesDeHorario.passos()
        #expect(passos.count == 48)
        #expect(passos.first == (try hora(0)))
        #expect(passos.last == (try hora(23, 30)))
    }

    @Test("o início oferece os 48 passos, em ordem, e não o horário do fim já escolhido")
    func opcoesDeInicio() throws {
        let todas = OpcoesDeHorario.inicio(atual: nil, excluindo: nil)
        #expect(todas.count == 48)
        #expect(todas.allSatisfy { !$0.iniciaDiaSeguinte })
        let semFim = OpcoesDeHorario.inicio(atual: nil, excluindo: try hora(2))
        #expect(semFim.count == 47)
        #expect(!semFim.map(\.hora).contains(try hora(2)))
    }

    @Test("o fim vai do resto do dia à virada da meia-noite, marca só a primeira opção do dia seguinte e nunca oferece o início")
    func opcoesDeFimAtravessandoAMeiaNoite() throws {
        let opcoes = OpcoesDeHorario.fim(apos: try hora(18), atual: nil)
        #expect(opcoes.count == 47)
        #expect(opcoes.first?.hora == (try hora(18, 30)))
        #expect(!opcoes.map(\.hora).contains(try hora(18)))
        let marcadas = opcoes.filter(\.iniciaDiaSeguinte)
        #expect(marcadas.count == 1)
        #expect(marcadas.first?.hora == (try hora(0)))
        #expect(opcoes.last?.hora == (try hora(17, 30)))
    }

    @Test("início à meia-noite não tem dia seguinte; início às 23:30 só tem")
    func fimNasPontas() throws {
        #expect(OpcoesDeHorario.fim(apos: try hora(0), atual: nil).allSatisfy { !$0.iniciaDiaSeguinte })
        let tarde = OpcoesDeHorario.fim(apos: try hora(23, 30), atual: nil)
        #expect(tarde.first?.hora == (try hora(0)))
        #expect(tarde.first?.iniciaDiaSeguinte == true)
    }

    @Test("um horário que não cai num passo (18:15) continua na fileira, no lugar certo")
    func preservaMinutosQueNaoSaoPassos() throws {
        let inicio = OpcoesDeHorario.inicio(atual: try hora(18, 15), excluindo: nil).map(\.hora)
        #expect(inicio.count == 49)
        let posicao = try #require(inicio.firstIndex(of: try hora(18, 15)))
        #expect(inicio[posicao - 1] == (try hora(18)))
        #expect(inicio[posicao + 1] == (try hora(18, 30)))

        let fim = OpcoesDeHorario.fim(apos: try hora(10), atual: try hora(17, 45)).map(\.hora)
        #expect(fim.contains(try hora(17, 45)))
    }

    // MARK: - Troca segura de horário

    @MainActor
    private func modelo(_ janelas: [JanelaDeDisponibilidade]) -> PerfilProfissionalViewModel {
        let vm = PerfilProfissionalViewModel(api: ApiClienteEmMemoria(), modo: .criacao)
        for j in janelas { vm.adicionarJanela(diaDaSemana: j.diaDaSemana, inicio: j.inicio, fim: j.fim) }
        return vm
    }

    @MainActor
    @Test("trocar o fim de uma janela mantém uma só janela, na mesma ordem")
    func trocaValida() throws {
        let antiga = JanelaDeDisponibilidade(diaDaSemana: 5, inicio: try hora(18), fim: try hora(2))
        let outra = JanelaDeDisponibilidade(diaDaSemana: 1, inicio: try hora(9), fim: try hora(12))
        let vm = modelo([antiga, outra])
        let nova = JanelaDeDisponibilidade(diaDaSemana: 5, inicio: try hora(18), fim: try hora(3))
        #expect(vm.substituirJanela(antiga, por: nova))
        #expect(vm.disponibilidades == [outra, nova])
    }

    @MainActor
    @Test("fim igual ao início é recusado e nada muda")
    func trocaInvalidaNaoMudaNada() throws {
        let antiga = JanelaDeDisponibilidade(diaDaSemana: 5, inicio: try hora(18), fim: try hora(2))
        let vm = modelo([antiga])
        let invalida = JanelaDeDisponibilidade(diaDaSemana: 5, inicio: try hora(18), fim: try hora(18))
        #expect(!vm.substituirJanela(antiga, por: invalida))
        #expect(vm.disponibilidades == [antiga])
    }

    @MainActor
    @Test("trocar uma janela que não existe não faz nada")
    func trocaDeJanelaInexistente() throws {
        let existente = JanelaDeDisponibilidade(diaDaSemana: 5, inicio: try hora(18), fim: try hora(2))
        let fantasma = JanelaDeDisponibilidade(diaDaSemana: 2, inicio: try hora(8), fim: try hora(12))
        let vm = modelo([existente])
        let nova = JanelaDeDisponibilidade(diaDaSemana: 2, inicio: try hora(8), fim: try hora(13))
        #expect(!vm.substituirJanela(fantasma, por: nova))
        #expect(vm.disponibilidades == [existente])
    }

    @MainActor
    @Test("trocar por uma janela que já existe funde as duas numa só")
    func trocaParaDuplicataFunde() throws {
        let a = JanelaDeDisponibilidade(diaDaSemana: 5, inicio: try hora(18), fim: try hora(2))
        let b = JanelaDeDisponibilidade(diaDaSemana: 5, inicio: try hora(19), fim: try hora(2))
        let vm = modelo([a, b])
        #expect(vm.substituirJanela(b, por: a))
        #expect(vm.disponibilidades == [a])
    }
}
