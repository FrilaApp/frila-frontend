@testable import FrilaDados
import Foundation
import FrilaDominio
import Testing

/// #98: o ponto base é do profissional e serve só para o despacho. Nada do que uma pessoa recebe
/// sobre a outra (perfil público, posições do painel do contratante, contato liberado) carrega
/// coordenada; o único lugar com o ponto base é o próprio perfil (`meu_perfil_profissional`).
@Suite("Ponto base do profissional fica fora das telas de outra pessoa (#98)")
struct PontoBasePrivadoTests {
    /// Todas as coordenadas alcançáveis a partir de `valor`, descendo pelas propriedades.
    private func coordenadas(em valor: Any) -> [Coordenada] {
        if let coordenada = valor as? Coordenada { return [coordenada] }
        return Mirror(reflecting: valor).children.flatMap { coordenadas(em: $0.value) }
    }

    private func chaves(emJSON objeto: Any) -> Set<String> {
        switch objeto {
        case let dicionario as [String: Any]:
            dicionario.reduce(into: Set(dicionario.keys)) { $0.formUnion(chaves(emJSON: $1.value)) }
        case let lista as [Any]:
            lista.reduce(into: Set<String>()) { $0.formUnion(chaves(emJSON: $1)) }
        default:
            []
        }
    }

    private func jsonDaFixture(_ nome: String) throws -> Any {
        try JSONSerialization.jsonObject(with: FixturesDoContrato.dados(nome))
    }

    @Test("O próprio perfil tem o ponto base, e é por ele que o teste sabe o que procurar")
    func proprioPerfilTemPontoBase() throws {
        let perfil = try FixturesDoContrato.carregar("perfil-profissional", como: ContratoAPI.PerfilProfissionalDTO.self).dominio()
        #expect(coordenadas(em: perfil) == [perfil.pontoBase])
        #expect(chaves(emJSON: try jsonDaFixture("perfil-profissional")).contains("ponto_base"))
    }

    @Test("Perfil público do profissional: sem coordenada no modelo e sem ponto_base no contrato")
    func perfilPublicoSemPonto() throws {
        let publico = try FixturesDoContrato.carregar("perfil-publico", como: ContratoAPI.PerfilPublicoDTO.self).dominio()
        #expect(publico.tipo == .profissional)
        #expect(coordenadas(em: publico).isEmpty)
        #expect(!chaves(emJSON: try jsonDaFixture("perfil-publico")).contains("ponto_base"))
    }

    @Test("Painel do contratante: as posições mostram o profissional sem coordenada")
    func painelSemPontoDoProfissional() throws {
        let painel = try FixturesDoContrato.carregar("painel", como: ContratoAPI.PainelDTO.self).dominio()
        let posicoes = painel.vagas.flatMap(\.posicoes)
        #expect(posicoes.contains { $0.profissional != nil })
        for posicao in posicoes {
            #expect(coordenadas(em: posicao).isEmpty)
        }
        #expect(!chaves(emJSON: try jsonDaFixture("painel")).contains("ponto_base"))
    }

    @Test("Contato liberado depois da confirmação: nome, telefone e WhatsApp, sem coordenada")
    func contatoSemPonto() throws {
        let contato = try FixturesDoContrato.carregar("contato", como: ContratoAPI.ContatoDTO.self).dominio()
        #expect(coordenadas(em: contato).isEmpty)
        #expect(!chaves(emJSON: try jsonDaFixture("contato")).contains("ponto_base"))
    }
}
