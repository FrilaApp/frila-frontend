import Foundation
@testable import FrilaApresentacao
import FrilaDominio
import Testing

/// Prova no app do critério do US18 (cartão 5uYZydYW): "nenhuma média decimal de estrelas é mostrada em
/// nenhum lugar do sistema" (RN07: avaliação binária; RN08: reputação sempre com denominador).
///
/// A reputação do app é um par de inteiros (`positivas de total`) mais comparecimento (`realizados de
/// considerados`). A `taxaComparecimento` decimal vem do contrato, mas nunca vira texto. Estes testes
/// travam isso em três camadas: os formatadores de texto, o catálogo de strings e o código-fonte.
@MainActor
@Suite("Reputação sem média decimal de estrelas (US18)")
struct ReputacaoSemMediaTests {
    private static let raiz = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// Um número com casas decimais ("4,7", "4.5", "92,5"), uma estrela desenhada ou a palavra
    /// estrela/média. "1.000" (milhar) não conta: três dígitos depois do separador.
    static func trazMediaDeEstrelas(_ texto: String) -> Bool {
        let padrao = #"[0-9][.,][0-9]{1,2}(?![0-9])|[★☆⭐]|\b(estrelas?|m[eé]dia)\b"#
        return texto.range(of: padrao, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Todo texto que o app monta a partir de uma `Reputacao`.
    static func textos(_ reputacao: Reputacao) -> [String] {
        var textos = [
            reputacao.descricao(),
            SeloReputacao.descricao(reputacao),
            TextosDoProfissional.reputacaoDoEstabelecimento(reputacao)
        ]
        if let comparecimento = SeloReputacao.descricaoComparecimento(reputacao) { textos.append(comparecimento) }
        return textos
    }

    /// Reputações que cobrem: sem histórico, um só turno, taxa redonda, dízima, milhar e o máximo.
    static let reputacoes: [Reputacao] = {
        let pares: [(positivas: Int, total: Int)] = [(0, 0), (1, 1), (1, 3), (2, 3), (7, 7), (11, 12), (18, 20), (0, 5), (999, 1000), (1200, 1250)]
        let turnos: [(considerados: Int, realizados: Int)] = [(0, 0), (1, 1), (12, 11), (20, 19), (1250, 1000)]
        let taxas: [Double?] = [nil, 0, 1.0 / 3.0, 0.5, 0.92, 0.9166666666666666, 0.95, 1]
        return pares.flatMap { par in
            turnos.flatMap { turno in
                taxas.map { taxa in
                    Reputacao(
                        positivas: par.positivas,
                        total: par.total,
                        taxaComparecimento: taxa,
                        turnosConsiderados: turno.considerados,
                        turnosRealizados: turno.realizados
                    )
                }
            }
        }
    }()

    @Test("O detector reconhece média decimal, estrela e a palavra média, e deixa passar o texto real")
    func detectorNaoEVazio() {
        for texto in ["4,7", "4.5 estrelas", "Média 4,6", "★ 4,8", "★★★★☆", "⭐ 5", "nota média", "92,5% compareceram", "4,75 de 5"] {
            #expect(Self.trazMediaDeEstrelas(texto), "deveria acusar: \(texto)")
        }
        for texto in ["10 de 12 chamariam de novo", "Compareceu a 18 de 20 turnos", "Sem histórico",
                      "1.000 de 1.250 chamariam de novo", "Ainda não há turnos considerados."] {
            #expect(!Self.trazMediaDeEstrelas(texto), "não deveria acusar: \(texto)")
        }
    }

    @Test("Nenhum texto de reputação traz média decimal, estrela ou palavra média, em todas as combinações")
    func textosDeReputacaoSemMedia() {
        #expect(Self.reputacoes.count == 400)
        for reputacao in Self.reputacoes {
            for texto in Self.textos(reputacao) {
                #expect(!Self.trazMediaDeEstrelas(texto), "texto de reputação com média: \"\(texto)\" (\(reputacao))")
            }
        }
    }

    @Test("A taxa decimal do contrato nunca entra em texto: a mesma reputação com outra taxa dá o mesmo texto")
    func taxaDecimalNaoViraTexto() {
        for reputacao in Self.reputacoes {
            let semTaxa = Reputacao(
                positivas: reputacao.positivas,
                total: reputacao.total,
                taxaComparecimento: nil,
                turnosConsiderados: reputacao.turnosConsiderados,
                turnosRealizados: reputacao.turnosRealizados
            )
            #expect(Self.textos(reputacao) == Self.textos(semTaxa), "a taxa \(String(describing: reputacao.taxaComparecimento)) mudou o texto")
        }
    }

    @Test("O formato é sempre inteiro com denominador (RN08), e sem histórico nunca vira 0 de 0")
    func denominadorSempreExplicito() {
        for reputacao in Self.reputacoes {
            let selo = SeloReputacao.descricao(reputacao)
            if reputacao.semHistorico {
                #expect(selo == "Sem histórico")
            } else {
                // só os dígitos: o separador de milhar depende do idioma do ambiente de teste
                #expect(selo.filter(\.isNumber) == "\(reputacao.positivas)\(reputacao.total)")
                #expect(selo.contains(" de ") && selo.hasSuffix(" chamariam de novo"))
            }
        }
    }

    @Test("O catálogo de strings não tem estrela nem média")
    func catalogoSemEstrelaNemMedia() throws {
        let dados = try Data(contentsOf: Self.raiz.appending(path: "Resources/Localizable.xcstrings"))
        let catalogo = try #require(try JSONSerialization.jsonObject(with: dados) as? [String: Any])
        let textos = Self.todasAsStrings(em: catalogo)
        #expect(textos.count > 100)
        let padrao = #"[★☆⭐]|\b(estrelas?|m[eé]dia)\b"#
        let achados = textos.filter { $0.range(of: padrao, options: [.regularExpression, .caseInsensitive]) != nil }
        #expect(achados.isEmpty, "RN07/RN08 proíbem estrela e média na reputação; achei no catálogo: \(achados.prefix(5))")
    }

    @Test("Nenhum arquivo que fala de reputação formata número com casas decimais nem desenha estrela")
    func codigoDeReputacaoSemFormatoDecimal() throws {
        let fontes = Self.raiz.appending(path: "Sources")
        let enumerador = try #require(FileManager.default.enumerator(at: fontes, includingPropertiesForKeys: nil))
        let arquivos = enumerador.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        #expect(arquivos.count >= 100)

        let formatoDecimal = #"%\.?[0-9]*[fFgGeE]|fractionLength|FractionDigits|\.precision\(|NumberFormatter|numberStyle"#
        var achados: [String] = []
        for arquivo in arquivos {
            let texto = try String(contentsOf: arquivo, encoding: .utf8)
            if texto.range(of: #"[★☆⭐]"#, options: .regularExpression) != nil {
                achados.append("\(arquivo.lastPathComponent): desenha estrela")
            }
            if texto.range(of: "reputa", options: .caseInsensitive) != nil,
               texto.range(of: formatoDecimal, options: .regularExpression) != nil {
                achados.append("\(arquivo.lastPathComponent): fala de reputação e formata número com casas decimais")
            }
        }
        #expect(achados.isEmpty, "RN07/RN08: reputação é inteiro com denominador, sem média. \(achados)")
    }

    /// Chaves e valores de texto de um catálogo `.xcstrings`, em qualquer profundidade.
    private static func todasAsStrings(em no: Any) -> [String] {
        switch no {
        case let texto as String:
            return [texto]
        case let lista as [Any]:
            return lista.flatMap { todasAsStrings(em: $0) }
        case let dicionario as [String: Any]:
            return dicionario.flatMap { chave, valor in [chave] + todasAsStrings(em: valor) }
        default:
            return []
        }
    }
}
