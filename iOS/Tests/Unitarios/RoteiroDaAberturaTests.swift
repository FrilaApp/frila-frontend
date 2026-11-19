import Foundation
import Testing
@testable import FrilaApresentacao

/// O roteiro da abertura animada (brief R-18-01): UMA constante, `duracaoDaAbertura`, manda no tempo, e todo marco
/// e todo quadro-chave são proporção do roteiro original do protótipo (2,82 s). Trocar a duração reescala tudo.
@Suite("Abertura animada: o roteiro escala com a duração")
struct RoteiroDaAberturaTests {
    /// Os marcos do protótipo, em segundos de um roteiro de 2,82 s.
    private static let prototipo = (duracao: 2.82, encaixe: 1.11, saida: 2.40, reduzidoSaida: 0.6, reduzidoDuracao: 0.9)
    private static let tolerancia = 1e-9

    @Test("A constante única vale 2,8 s (o mesmo valor do Android)")
    func constanteUnica() {
        #expect(RoteiroDaAbertura.duracaoDaAbertura == 2.8)
        #expect(RoteiroDaAbertura.para(reduzirMovimento: false).duracao == RoteiroDaAbertura.duracaoDaAbertura)
    }

    @Test("Com a duração do protótipo, os marcos batem com o protótipo")
    func marcosDoPrototipo() {
        let cheio = RoteiroDaAbertura.para(reduzirMovimento: false, duracaoDaAbertura: Self.prototipo.duracao)
        #expect(abs(cheio.duracao - 2.82) < Self.tolerancia)
        #expect(abs((cheio.encaixe ?? -1) - 1.11) < Self.tolerancia)
        #expect(abs(cheio.saida - 2.40) < Self.tolerancia)
        #expect(abs(cheio.escala - 1) < Self.tolerancia)
        let reduzido = RoteiroDaAbertura.para(reduzirMovimento: true, duracaoDaAbertura: Self.prototipo.duracao)
        #expect(reduzido.encaixe == nil)
        #expect(abs(reduzido.saida - 0.6) < Self.tolerancia)
        #expect(abs(reduzido.duracao - 0.9) < Self.tolerancia)
    }

    @Test("Em qualquer duração, cada marco é a mesma fração do protótipo", arguments: [1.5, 2.8, 4.0, 10.0])
    func marcosEscalam(duracao: Double) {
        let cheio = RoteiroDaAbertura.para(reduzirMovimento: false, duracaoDaAbertura: duracao)
        #expect(abs(cheio.duracao - duracao) < Self.tolerancia)
        #expect(abs((cheio.encaixe ?? -1) / duracao - Self.prototipo.encaixe / Self.prototipo.duracao) < Self.tolerancia)
        #expect(abs(cheio.saida / duracao - Self.prototipo.saida / Self.prototipo.duracao) < Self.tolerancia)
        #expect(abs(cheio.escala - duracao / Self.prototipo.duracao) < Self.tolerancia)
        // O pulo e o assento do pulo escalam junto.
        #expect(abs(cheio.pulo / duracao - 0.25 / Self.prototipo.duracao) < Self.tolerancia)
        #expect(abs(cheio.assentoDoPulo / duracao - 0.35 / Self.prototipo.duracao) < Self.tolerancia)
    }

    @Test("O reduzido não tem encaixe e deriva da mesma constante pela mesma regra", arguments: [1.5, 2.8, 4.0])
    func reduzidoEscala(duracao: Double) {
        let reduzido = RoteiroDaAbertura.para(reduzirMovimento: true, duracaoDaAbertura: duracao)
        #expect(reduzido.reduzido)
        #expect(reduzido.encaixe == nil)
        #expect(abs(reduzido.duracao / duracao - Self.prototipo.reduzidoDuracao / Self.prototipo.duracao) < Self.tolerancia)
        #expect(abs(reduzido.saida / duracao - Self.prototipo.reduzidoSaida / Self.prototipo.duracao) < Self.tolerancia)
        // Com a constante padrão, o reduzido dura 0,9/2,82 dela.
        let padrao = RoteiroDaAbertura.para(reduzirMovimento: true)
        #expect(abs(padrao.duracao - RoteiroDaAbertura.duracaoDaAbertura * 0.9 / 2.82) < Self.tolerancia)
    }

    @Test("Os marcos estão em ordem crescente", arguments: [false, true], [1.5, 2.8])
    func marcosEmOrdem(reduzir: Bool, duracao: Double) {
        let marcos = RoteiroDaAbertura.para(reduzirMovimento: reduzir, duracaoDaAbertura: duracao).marcos
        #expect(marcos.count == (reduzir ? 2 : 3))
        #expect(marcos == marcos.sorted())
        #expect(Set(marcos).count == marcos.count)
        #expect(marcos.first ?? -1 > 0)
    }

    @Test("A linha do tempo dos quadros-chave termina nos 2,82 s do protótipo")
    func linhaDoTempoTemADuracaoDoPrototipo() {
        #expect(abs(CoreografiaDaAbertura.duracao - RoteiroDaAbertura.duracaoDoPrototipo) < Self.tolerancia)
    }

    @Test("Os quadros-chave escalam: o quadro em x da duração é o mesmo em qualquer duração", arguments: [1.5, 2.8, 5.0])
    func quadrosEscalam(duracao: Double) {
        let base = RoteiroDaAbertura.para(reduzirMovimento: false, duracaoDaAbertura: Self.prototipo.duracao)
        let outro = RoteiroDaAbertura.para(reduzirMovimento: false, duracaoDaAbertura: duracao)
        // Frações cobrindo a entrada, o bote, o encaixe, as sacudidas, a câmera, o rótulo e a saída.
        for x in stride(from: 0.0, through: 1.0, by: 0.02) {
            let esperado = CoreografiaDaAbertura.quadro(no: x * Self.prototipo.duracao, roteiro: base)
            let obtido = CoreografiaDaAbertura.quadro(no: x * duracao, roteiro: outro)
            #expect(Self.proximos(esperado, obtido), "diferença no instante \(x) da abertura, com duração \(duracao)")
        }
    }

    @Test("O rastro de movimento só existe na entrada e no bote, nos segundos do protótipo")
    func rastroEscala() {
        // O rastro existe (força > 0) na entrada e no bote, medidos nos segundos do protótipo.
        #expect(!CoreografiaDaAbertura.rastro(noInstanteDoPrototipo: 0.1).isEmpty)
        #expect(!CoreografiaDaAbertura.rastro(noInstanteDoPrototipo: 1.05).isEmpty)
        #expect(CoreografiaDaAbertura.rastro(noInstanteDoPrototipo: 0.6).isEmpty)
        #expect(CoreografiaDaAbertura.rastro(noInstanteDoPrototipo: 2.0).isEmpty)
    }

    @Test("A abertura começa fechada, termina aberta e o encaixe cai no marco", arguments: [1.5, 2.8])
    func comecoEFim(duracao: Double) {
        let roteiro = RoteiroDaAbertura.para(reduzirMovimento: false, duracaoDaAbertura: duracao)
        let inicio = CoreografiaDaAbertura.quadro(no: 0, roteiro: roteiro)
        let fim = CoreografiaDaAbertura.quadro(no: duracao, roteiro: roteiro)
        #expect(inicio.abertura == 0)
        #expect(abs(fim.abertura - 1) < Self.tolerancia)
        // No encaixe as duas letras chegam juntas ao centro; as mãos terminam de se formar logo depois (1,23 s do protótipo).
        let noEncaixe = CoreografiaDaAbertura.quadro(no: roteiro.encaixe ?? 0, roteiro: roteiro)
        #expect(abs(noEncaixe.rX) < 1e-6)
        #expect(abs(noEncaixe.iX) < 1e-6)
        #expect(noEncaixe.maos > 0 && noEncaixe.maos < 1)
        let formadas = CoreografiaDaAbertura.quadro(no: 1.23 * roteiro.escala, roteiro: roteiro)
        #expect(abs(formadas.maos - 1) < Self.tolerancia)
    }

    @Test("Reduzir Movimento: opaco até a saída, some até a duração, na mesma proporção")
    func esmaecimentoReduzido() {
        for duracao in [1.5, 2.8] {
            let reduzido = RoteiroDaAbertura.para(reduzirMovimento: true, duracaoDaAbertura: duracao)
            #expect(reduzido.opacidadeReduzida(no: 0) == 1)
            #expect(reduzido.opacidadeReduzida(no: reduzido.saida) == 1)
            #expect(abs(reduzido.opacidadeReduzida(no: (reduzido.saida + reduzido.duracao) / 2) - 0.5) < Self.tolerancia)
            #expect(reduzido.opacidadeReduzida(no: reduzido.duracao) == 0)
        }
    }

    /// Dois quadros iguais, campo a campo, a menos do ruído do ponto flutuante.
    private static func proximos(_ a: QuadroDaAbertura, _ b: QuadroDaAbertura) -> Bool {
        func valores(_ q: QuadroDaAbertura) -> [Double] {
            [q.rX, q.rY, q.rOpacidade, q.rCurva, q.rEstica, q.rBraco, q.rAlcance, q.rTorcao,
             q.iX, q.iY, q.iOpacidade, q.iCurva, q.iEstica, q.iBraco, q.iAlcance, q.iTorcao,
             q.maos, q.sacudida, q.balancoR, q.balancoI, q.aperto, q.pingoEscala, q.pingoY,
             q.zoom, q.enquadramento, q.fX, q.fOpacidade, q.lX, q.lOpacidade, q.aX, q.aOpacidade,
             q.rotuloEscala, q.rotuloOpacidade, q.abertura, q.halo]
        }
        return zip(valores(a), valores(b)).allSatisfy { abs($0 - $1) < 1e-6 }
    }
}
