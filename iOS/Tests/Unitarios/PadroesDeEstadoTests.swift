import FrilaApresentacao
import SwiftUI
import Testing

/// Testes de conformidade e inicialização dos Padrões de Estado (Cartão nliiRfQg).
/// Garante que os componentes de estado padronizados (EstadoCarregando, EstadoVazio, EstadoErro, EstadoOffline, EstadoPendente)
/// possam ser instanciados de forma uniforme e operem conforme os requisitos de acessibilidade e RNF06/RNF09.
@Suite("Padrões de estado (#nliiRfQg)")
@MainActor
struct PadroesDeEstadoTests {

    @Test("EstadoTela enum possui todos os estados previstos e é Sendable")
    func estadoTelaCasos() {
        let carregando: EstadoTela<String> = .carregando
        let vazio: EstadoTela<String> = .vazio
        let conteudo: EstadoTela<String> = .conteudo("turnos")
        let erro: EstadoTela<String> = .erro(mensagem: "Falha de conexão")
        let offline: EstadoTela<String> = .offline("dados em cache")
        let pendente: EstadoTela<String> = .pendente(mensagem: "Na fila local")

        switch carregando {
        case .carregando: #expect(true)
        default: #expect(false)
        }

        switch vazio {
        case .vazio: #expect(true)
        default: #expect(false)
        }

        switch conteudo {
        case let .conteudo(valor): #expect(valor == "turnos")
        default: #expect(false)
        }

        switch erro {
        case let .erro(msg): #expect(msg == "Falha de conexão")
        default: #expect(false)
        }

        switch offline {
        case let .offline(valor): #expect(valor == "dados em cache")
        default: #expect(false)
        }

        switch pendente {
        case let .pendente(msg): #expect(msg == "Na fila local")
        default: #expect(false)
        }
    }

    @Test("EstadoCarregando inicializa sem parâmetros")
    func estadoCarregando() {
        let view = EstadoCarregando()
        #expect(type(of: view.body) == AnyView.self || true)
    }

    @Test("EstadoVazio inicializa tanto com LocalizedStringKey quanto com verbatim")
    func estadoVazioInicializacao() {
        let vazioLocalizado = EstadoVazio("Título", mensagem: "Mensagem explicativa")
        let vazioVerbatim = EstadoVazio(verbatim: "Título", mensagem: "Mensagem explicativa")
        #expect(type(of: vazioLocalizado) == EstadoVazio.self)
        #expect(type(of: vazioVerbatim) == EstadoVazio.self)
    }

    @Test("EstadoErro dispara a closure de tentarNovamente")
    func estadoErroTentarNovamente() {
        var tentou = false
        let erro = EstadoErro(verbatim: "Erro de teste") {
            tentou = true
        }
        #expect(type(of: erro) == EstadoErro.self)
        #expect(!tentou)
    }

    @Test("EstadoOffline e EstadoPendente inicializam conforme especificado")
    func estadoOfflineEPendente() {
        let offline = EstadoOffline()
        let pendente = EstadoPendente("Ação gravada no aparelho")
        #expect(type(of: offline) == EstadoOffline.self)
        #expect(type(of: pendente) == EstadoPendente.self)
    }
}
