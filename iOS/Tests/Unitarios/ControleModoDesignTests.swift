import Foundation
import Testing
@testable import FrilaApresentacao

@Suite("Modo de design: chave de tempo de execução")
@MainActor
struct ControleModoDesignTests {
    private func padroesIsolados() -> UserDefaults {
        let nome = "ControleModoDesignTests-\(UUID().uuidString)"
        let padroes = UserDefaults(suiteName: nome)!
        padroes.removePersistentDomain(forName: nome)
        return padroes
    }

    @Test("Sem argumento e sem chave, nasce desligado")
    func desligadoPorPadrao() {
        let controle = ControleModoDesign(argumentos: ["Frila"], padroes: padroesIsolados())
        #expect(controle.ativo == false)
    }

    @Test("Os dois argumentos de lançamento ligam")
    func argumentoLiga() {
        for argumento in ["-FRILA_MODO_DESIGN", "-FRILA_DESIGN"] {
            let controle = ControleModoDesign(argumentos: ["Frila", argumento], padroes: padroesIsolados())
            #expect(controle.ativo, "\(argumento) deveria ligar o modo")
        }
    }

    @Test("A chave guardada no aparelho liga")
    func chaveNoAparelhoLiga() {
        let padroes = padroesIsolados()
        padroes.set(true, forKey: ControleModoDesign.chaveNoAparelho)
        #expect(ControleModoDesign(argumentos: [], padroes: padroes).ativo)
    }

    @Test("Alternar muda o estado e grava a chave; um controle novo lê o que foi gravado")
    func alternarGrava() {
        let padroes = padroesIsolados()
        let controle = ControleModoDesign(argumentos: [], padroes: padroes)
        controle.alternar(comHaptico: false)
        #expect(controle.ativo)
        #expect(padroes.bool(forKey: ControleModoDesign.chaveNoAparelho))
        #expect(ControleModoDesign(argumentos: [], padroes: padroes).ativo)
        controle.alternar(comHaptico: false)
        #expect(controle.ativo == false)
        #expect(ControleModoDesign(argumentos: [], padroes: padroes).ativo == false)
    }
}
