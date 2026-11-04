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

struct CadeiaDominioTests {
    @Test func pontuacaoFormaBlocosSemRepetirPrefixo() {
        #expect(CadeiaDoDominio(restante: "mail.com").blocos.map(\.texto) == ["mail", ".com"])
        #expect(CadeiaDoDominio(restante: "ahoo.com.br").blocos.map(\.texto) == ["ahoo", ".com", ".br"])
        #expect(CadeiaDoDominio(restante: ".com.br").blocos.map(\.texto) == [".com", ".br"])
        #expect(CadeiaDoDominio(restante: "com.br").blocos.map(\.texto) == ["com", ".br"])
        #expect(CadeiaDoDominio(restante: "").blocos.isEmpty)
    }

    @Test func cadeiaAdaptaTempoEEncadeiaComIntervalosCrescentes() {
        let dois = CadeiaDoDominio(restante: "mail.com")
        let tres = CadeiaDoDominio(restante: "ahoo.com.br")
        #expect((0.350...0.420).contains(dois.duracao))
        #expect((0.450...0.520).contains(tres.duracao))
        guard dois.blocos.count == 2, tres.blocos.count == 3 else {
            Issue.record("A cadeia precisa preservar seus blocos")
            return
        }
        #expect(tres.blocos[0].duracao < dois.blocos[0].duracao)
        #expect(tres.blocos.allSatisfy { (0.160...0.220).contains($0.duracao) })
        #expect(tres.blocos[1].inicio > 0)
        #expect(tres.blocos[1].inicio < tres.blocos[2].inicio - tres.blocos[1].inicio)
        #expect(abs(tres.blocos[2].inicio + tres.blocos[2].duracao - tres.duracao) < 0.0001)
    }

    @Test func cadaBlocoSoEntraNaSuaVezETerminaInteiro() {
        let cadeia = CadeiaDoDominio(restante: "ahoo.com.br")
        #expect(!cadeia.blocos.isEmpty)
        for bloco in cadeia.blocos {
            #expect(bloco.progresso(em: bloco.inicio - 0.001) == 0)
            #expect(bloco.progresso(em: bloco.inicio + bloco.duracao + 0.001) == 1)
            #expect(bloco.progresso(em: bloco.inicio + bloco.duracao / 2) > 0.5)
        }
    }
}
