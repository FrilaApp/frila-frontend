import Foundation
import FrilaApresentacao
import SwiftUI
import Testing

@MainActor
@Suite("Aparência do app: abre no claro, escuro só por escolha")
struct PreferenciaDeAparenciaTests {
    private func defaultsIsolado() throws -> (UserDefaults, String) {
        let suite = "teste-aparencia-" + UUID().uuidString
        return (try #require(UserDefaults(suiteName: suite)), suite)
    }

    @Test("Instalação nova abre no claro")
    func padraoEClaro() throws {
        let (defaults, suite) = try defaultsIsolado()
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferencia = PreferenciaDeAparencia(defaults: defaults)
        #expect(preferencia.aparencia == .claro)
        #expect(preferencia.esquemaDeCor == .light)
    }

    @Test("Escolher o escuro vale na hora e fica guardado depois de reabrir")
    func escolhaSobreviveAReabertura() throws {
        let (defaults, suite) = try defaultsIsolado()
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferencia = PreferenciaDeAparencia(defaults: defaults)
        preferencia.escolher(.escuro)
        #expect(preferencia.esquemaDeCor == .dark)

        let reaberta = PreferenciaDeAparencia(defaults: try #require(UserDefaults(suiteName: suite)))
        #expect(reaberta.aparencia == .escuro)

        reaberta.escolher(.claro)
        #expect(PreferenciaDeAparencia(defaults: defaults).aparencia == .claro)
    }

    @Test("Valor guardado desconhecido volta ao claro")
    func valorDesconhecidoViraClaro() throws {
        let (defaults, suite) = try defaultsIsolado()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("automatico", forKey: PreferenciaDeAparencia.chave)
        #expect(PreferenciaDeAparencia(defaults: defaults).aparencia == .claro)
    }

    @Test("A escolha do usuário vale nos dois sentidos, sem olhar o sistema")
    func escolhaValeNosDoisSentidos() {
        #expect(PreferenciaDeAparencia.esquemaEfetivo(forcado: nil, escolhida: .claro) == .light)
        #expect(PreferenciaDeAparencia.esquemaEfetivo(forcado: nil, escolhida: .escuro) == .dark)
    }

    @Test("Argumento de teste tem prioridade sobre a escolha guardada")
    func argumentoDeTesteVence() {
        #expect(PreferenciaDeAparencia.esquemaEfetivo(forcado: .dark, escolhida: .claro) == .dark)
        #expect(PreferenciaDeAparencia.esquemaEfetivo(forcado: .light, escolhida: .escuro) == .light)
    }
}
