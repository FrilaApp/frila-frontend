@testable import FrilaApresentacao
import Testing

struct PredicaoDominioTests {
    @Test func prefixosMinimosCalculados() {
        let p = SugestaoDominio.prefixosMinimos(da: SugestaoDominio.dominios)
        for (dominio, prefixo) in [("gmail.com", "g"), ("hotmail.com", "h"), ("outlook.com", "o"), ("icloud.com", "i"), ("uol.com.br", "u"), ("yahoo.com.br", "yahoo.com.")] {
            #expect(p[dominio] == .init(prefixo: prefixo, exigeTermino: false))
        }
        #expect(p["yahoo.com"] == .init(prefixo: "yahoo.com", exigeTermino: true))
    }
    @Test func yahooPreservaOrdemEAmbiguidade() {
        #expect(SugestaoDominio.compativeis(com: "y", na: SugestaoDominio.dominios) == ["yahoo.com.br", "yahoo.com"])
        #expect(SugestaoDominio.compativeis(com: "yahoo.com.", na: SugestaoDominio.dominios) == ["yahoo.com.br"])
        #expect(SugestaoDominio.compativeis(com: "g", na: SugestaoDominio.dominios) == ["gmail.com"])
        #expect(SugestaoDominio.compativeis(com: "z", na: SugestaoDominio.dominios).isEmpty)
        #expect(SugestaoDominio.prefixosMinimos(da: ["gato.com", "galo.com"])["gato.com"]?.prefixo == "gat")
    }
    @Test func tremorNaoAtivaIntencao() {
        #expect(!LimiarDaRoda.intencional(deslocamento: 2, velocidade: 900))
        #expect(!LimiarDaRoda.intencional(deslocamento: 7, velocidade: 100))
        #expect(LimiarDaRoda.intencional(deslocamento: 8, velocidade: 0))
        #expect(LimiarDaRoda.intencional(deslocamento: -6, velocidade: -160))
        #expect(!LimiarDaRoda.intencional(deslocamento: -6, velocidade: 160))
        #expect(abs(LimiarDaRoda.resistencia(7)) < 2.5)
        #expect(LimiarDaRoda.resistencia(2) == 0)
    }
}
