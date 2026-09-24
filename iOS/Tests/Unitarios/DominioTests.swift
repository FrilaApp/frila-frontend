import Foundation
import FrilaDominio
import Testing

@Suite("Domínio puro")
struct DominioTests {
    @Test("Períodos semiabertos só sobrepõem quando compartilham tempo")
    func sobreposicao() throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let primeiro = try Periodo(inicio: base, fim: base.addingTimeInterval(3_600))
        let encostado = try Periodo(inicio: primeiro.fim, fim: primeiro.fim.addingTimeInterval(3_600))
        let sobreposto = try Periodo(inicio: base.addingTimeInterval(1_800), fim: base.addingTimeInterval(7_200))
        #expect(!primeiro.sobrepoe(encostado))
        #expect(primeiro.sobrepoe(sobreposto))
    }

    @Test("Validação da vaga cobre os invariantes locais")
    func validarVaga() throws {
        let agora = Date(timeIntervalSince1970: 1_700_000_000)
        let ponto = try Coordenada(latitude: -23.5505, longitude: -46.6333)
        let vaga = Vaga(
            id: UUID(),
            estabelecimento: Estabelecimento(id: UUID(), nome: "", tipo: .foodService, endereco: "", ponto: ponto),
            funcao: Funcao(id: UUID(), nome: "", categoria: ""),
            periodo: try Periodo(inicio: agora.addingTimeInterval(3_600), fim: agora.addingTimeInterval(7_200)),
            local: "", ponto: ponto, valor: Dinheiro(centavos: 0), posicoes: 0, posicoesAbertas: 0,
            inclusos: Inclusos(refeicao: false, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "", modo: .selecao, estado: .publicada
        )
        #expect(Set(vaga.validar(agora: agora)) == Set(ErroValidacaoVaga.allCases.filter { $0 != .horarioNoPassado }))
    }

    @Test("Distância usa coordenadas sem importar CoreLocation")
    func distancia() throws {
        let se = try Coordenada(latitude: -23.5505, longitude: -46.6333)
        let paulista = try Coordenada(latitude: -23.5614, longitude: -46.6559)
        let metros = se.distancia(emMetrosDe: paulista)
        #expect(metros > 2_000)
        #expect(metros < 3_000)
    }

    @Test("HoraDoDia mantém o formato do contrato")
    func horaDoDia() throws {
        let hora = try HoraDoDia("03:07")
        #expect(hora.contrato == "03:07")
        #expect(throws: ErroHoraDoDia.formatoInvalido) { try HoraDoDia("3:07") }
    }
}
