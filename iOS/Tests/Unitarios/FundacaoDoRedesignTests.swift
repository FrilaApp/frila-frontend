@testable import FrilaApresentacao
import SwiftUI
import UIKit
import Testing

/// R0 do redesign: os tokens e os estados do botão seguem o sistema do Fabrício
/// (`Tokens.swift` e `Botoes.swift` do `frila-frontend-redesign`; D-DS-03 e D-DS-06 do `docs/03` dele).
@Suite("Fundação do redesign: tokens e botões do sistema do Fabrício")
@MainActor
struct FundacaoDoRedesignTests {
    @Test("Os raios são os nominais: 24 no cartão, 16 no elemento interno e no campo, 8 no selo")
    func raiosNominais() {
        #expect(FrilaRaio.cartao == 24)
        #expect(FrilaRaio.interno == 16)
        #expect(FrilaRaio.entrada == 16)
        #expect(FrilaRaio.selo == 8)
        #expect(FrilaRaio.folha == 24)
    }

    @Test("Os seis espaços têm os nomes e os valores da D-DS-06")
    func espacos() {
        #expect(FrilaEspaco.junto == 4)
        #expect(FrilaEspaco.item == 8)
        #expect(FrilaEspaco.bloco == 16)
        #expect(FrilaEspaco.grupo == 24)
        #expect(FrilaEspaco.secao == 32)
        #expect(FrilaEspaco.respiro == 48)
    }

    @Test("Alturas: botão e campo 48, presença 64, chip 36 num alvo de 48, selo 28")
    func alturas() {
        #expect(FrilaMetrica.alturaDoCampo == 48)
        #expect(FrilaMetrica.alturaDoBotaoDePresenca == 64)
        #expect(FrilaMetrica.alturaDoChip == 36)
        #expect(FrilaMetrica.alvo == 48)
        #expect(FrilaMetrica.alturaDoSelo == 28)
        #expect(FrilaMetrica.alvo >= FrilaMetrica.alvoMinimo)
    }

    @Test("O primário é laranja com rótulo branco, e pressionado escurece sem trocar o rótulo")
    func primarioHabilitado() {
        let solto = EstiloDoBotaoFrila.cores(papel: .primario, emConferencia: false, pressionado: false)
        #expect(solto.fundo == FrilaCor.acao)
        #expect(solto.rotulo == FrilaCor.sobreAcao)
        #expect(solto.borda == nil)

        let pressionado = EstiloDoBotaoFrila.cores(papel: .primario, emConferencia: false, pressionado: true)
        #expect(pressionado.fundo == FrilaCor.acaoPressionada)
        #expect(pressionado.rotulo == FrilaCor.sobreAcao)
    }

    @Test("O primário em conferência fica em borda e texto secundário, pressionado ou não")
    func primarioEmConferencia() {
        for pressionado in [false, true] {
            let cores = EstiloDoBotaoFrila.cores(papel: .primario, emConferencia: true, pressionado: pressionado)
            #expect(cores.fundo == FrilaCor.borda)
            #expect(cores.rotulo == FrilaCor.textoSecundario)
            #expect(cores.borda == nil)
        }
    }

    @Test("O secundário é superfície com fio em borda e rótulo em tinta; pressionado usa a superfície pressionada")
    func secundario() {
        let solto = EstiloDoBotaoFrila.cores(papel: .secundario, emConferencia: false, pressionado: false)
        #expect(solto.fundo == FrilaCor.superficie)
        #expect(solto.rotulo == FrilaCor.texto)
        #expect(solto.borda == FrilaCor.borda)

        let pressionado = EstiloDoBotaoFrila.cores(papel: .secundario, emConferencia: false, pressionado: true)
        #expect(pressionado.fundo == FrilaCor.superficiePressionada)
        #expect(pressionado.rotulo == FrilaCor.texto)
    }

    @Test("O laranja pressionado é #DD5C00 e a superfície pressionada é #EFECEA no claro e #2A2826 no escuro")
    func coresPressionadas() {
        #expect(Self.hex(FrilaCor.acaoPressionada, estilo: .light) == 0xDD5C00)
        #expect(Self.hex(FrilaCor.acaoPressionada, estilo: .dark) == 0xDD5C00)
        #expect(Self.hex(FrilaCor.superficiePressionada, estilo: .light) == 0xEFECEA)
        #expect(Self.hex(FrilaCor.superficiePressionada, estilo: .dark) == 0x2A2826)
    }

    private static func hex(_ cor: Color, estilo: UIUserInterfaceStyle) -> Int {
        let resolvida = UIColor(cor).resolvedColor(with: UITraitCollection(userInterfaceStyle: estilo))
        var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        resolvida.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Int((r * 255).rounded()) << 16) | (Int((g * 255).rounded()) << 8) | Int((b * 255).rounded())
    }
}
