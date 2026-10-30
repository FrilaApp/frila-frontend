import Foundation
import FrilaApresentacao
import Testing

@Suite("Hierarquia da barra Aceitar turno LOG-018")
struct BarraAceitarTurnoComposicaoTests {
    @Test("O inteiro supera o maior texto do detalhe com pelo menos 8 pt de folga")
    func valorMaiorQueTitulo() throws {
        let raiz = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fonte = try String(contentsOf: raiz.appending(path:
            "Sources/Apresentacao/Fluxos/Profissional/TelasDaCandidatura.swift"), encoding: .utf8)
        let expressao = try NSRegularExpression(pattern: #"leitura: formatador\.dinheiroFalado\(viewModel\.vaga\.valor\), tamanho: (\d+)"#)
        let resultado = try #require(expressao.firstMatch(in: fonte, range: NSRange(fonte.startIndex..., in: fonte)))
        let faixa = try #require(Range(resultado.range(at: 1), in: fonte))
        let tamanho = try #require(Double(fonte[faixa]))
        #expect(tamanho >= Double(FrilaTypeScaleStep.display.pointSize) + 8)
    }
}
