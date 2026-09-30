import Foundation
@testable import FrilaApresentacao
import FrilaDominio
import Testing

@Suite("Catálogo de strings de interface (pt-BR)")
struct CatalogoStringsTests {
    private static let raiz = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static func carregarCatalogo() throws -> (chaves: Set<String>, traducoes: [String: String]) {
        let url = raiz.appending(path: "Resources/Localizable.xcstrings")
        let dados = try Data(contentsOf: url)

        struct CatalogoJSON: Decodable {
            struct Entrada: Decodable {
                struct Localizacao: Decodable {
                    struct Unidade: Decodable {
                        let state: String?
                        let value: String?
                    }
                    struct Variacoes: Decodable {
                        struct Plural: Decodable {
                            struct Regra: Decodable {
                                let stringUnit: Unidade?
                            }
                            let one: Regra?
                            let other: Regra?
                            let zero: Regra?
                        }
                        let plural: Plural?
                    }
                    let stringUnit: Unidade?
                    let variations: Variacoes?
                }
                struct Localizacoes: Decodable {
                    let ptBR: Localizacao?

                    enum CodingKeys: String, CodingKey {
                        case ptBR = "pt-BR"
                    }
                }
                let localizations: Localizacoes?
            }
            let sourceLanguage: String
            let strings: [String: Entrada]
        }

        let decodificado = try JSONDecoder().decode(CatalogoJSON.self, from: dados)
        #expect(decodificado.sourceLanguage == "pt-BR", "o idioma de origem deve ser pt-BR")

        var traducoes: [String: String] = [:]
        for (chave, entrada) in decodificado.strings {
            if let valor = entrada.localizations?.ptBR?.stringUnit?.value {
                traducoes[chave] = valor
            } else if let valorOther = entrada.localizations?.ptBR?.variations?.plural?.other?.stringUnit?.value {
                traducoes[chave] = valorOther
            }
        }
        return (Set(decodificado.strings.keys), traducoes)
    }

    @Test("Catálogo Localizable.xcstrings possui idioma pt-BR e todas as chaves têm tradução válida")
    func catalogoValido() throws {
        let (chaves, traducoes) = try Self.carregarCatalogo()
        #expect(chaves.count >= 90, "esperava pelo menos 90 chaves no catálogo, encontrou \(chaves.count)")

        var chavesSemTraducao: [String] = []
        for chave in chaves {
            if let traducao = traducoes[chave], !traducao.isEmpty {
                continue
            }
            chavesSemTraducao.append(chave)
        }
        #expect(chavesSemTraducao.isEmpty, "chaves sem tradução pt-BR: \(chavesSemTraducao)")
    }

    @Test("Todas as constantes de TextosDoProfissional existem no catálogo pt-BR")
    func textosDoProfissional() throws {
        let (chaves, _) = try Self.carregarCatalogo()

        let stringsDaLista = [
            TextosDoProfissional.Lista.titulo,
            TextosDoProfissional.Lista.qualquerFuncao,
            TextosDoProfissional.Lista.qualquerData,
            TextosDoProfissional.Lista.hoje,
            TextosDoProfissional.Lista.amanha,
            TextosDoProfissional.Lista.qualquerDistancia,
            TextosDoProfissional.Lista.vazioTitulo,
            TextosDoProfissional.Lista.vazioMensagem,
            TextosDoProfissional.Lista.erroMensagem,
            TextosDoProfissional.Lista.semPontoDeReferencia,
            TextosDoProfissional.Lista.perfilIncompativel,
            TextosDoProfissional.Lista.semConexaoMensagem,
        ]

        let stringsDoDetalhe = [
            TextosDoProfissional.Detalhe.titulo,
            TextosDoProfissional.Detalhe.quando,
            TextosDoProfissional.Detalhe.horario,
            TextosDoProfissional.Detalhe.valor,
            TextosDoProfissional.Detalhe.posicoes,
            TextosDoProfissional.Detalhe.valorIntegral,
            TextosDoProfissional.Detalhe.incluso,
            TextosDoProfissional.Detalhe.quemRecebe,
            TextosDoProfissional.Detalhe.traje,
            TextosDoProfissional.Detalhe.urgencia,
            TextosDoProfissional.Detalhe.urgenciaDetalhe,
            TextosDoProfissional.Detalhe.selecao,
            TextosDoProfissional.Detalhe.selecaoDetalhe,
            TextosDoProfissional.Detalhe.candidatar,
            TextosDoProfissional.Detalhe.denunciar,
            TextosDoProfissional.Detalhe.bloquear,
            TextosDoProfissional.Detalhe.erroMensagem,
            TextosDoProfissional.Detalhe.naoEncontrada,
        ]

        let stringsDaCandidatura = [
            TextosDoProfissional.Candidatura.enviando,
            TextosDoProfissional.Candidatura.voltarParaLista,
            TextosDoProfissional.Candidatura.confirmadoTitulo,
            TextosDoProfissional.Candidatura.contato,
            TextosDoProfissional.Candidatura.contatoLiberado,
            TextosDoProfissional.Candidatura.abrirWhatsApp,
            TextosDoProfissional.Candidatura.preenchidaTitulo,
            TextosDoProfissional.Candidatura.preenchidaMensagem,
            TextosDoProfissional.Candidatura.encerradaTitulo,
            TextosDoProfissional.Candidatura.encerradaMensagem,
            TextosDoProfissional.Candidatura.sobrepostoTitulo,
            TextosDoProfissional.Candidatura.sobrepostoMensagem,
            TextosDoProfissional.Candidatura.funcaoTitulo,
            TextosDoProfissional.Candidatura.funcaoMensagem,
            TextosDoProfissional.Candidatura.inelegivelTitulo,
            TextosDoProfissional.Candidatura.inelegivelMensagem,
            TextosDoProfissional.Candidatura.suspensaTitulo,
            TextosDoProfissional.Candidatura.suspensaMensagem,
            TextosDoProfissional.Candidatura.contestar,
            TextosDoProfissional.Candidatura.contestarEmBreve,
            TextosDoProfissional.Candidatura.naoEncontrada,
            TextosDoProfissional.Candidatura.falha,
            TextosDoProfissional.Candidatura.semConexao,
        ]

        let todasConstantes = stringsDaLista + stringsDoDetalhe + stringsDaCandidatura + [
            TextosDoProfissional.simNao(true),
            TextosDoProfissional.simNao(false),
            "Sem histórico",
        ]

        var faltantes: [String] = []
        for texto in todasConstantes {
            if !chaves.contains(texto) {
                faltantes.append(texto)
            }
        }
        #expect(faltantes.isEmpty, "constantes de TextosDoProfissional fora do catálogo: \(faltantes)")

        // Padrões com interpolação
        let padroesInterpolados = [
            "Até %lld km",
            "Ao confirmar, seu telefone e WhatsApp serão mostrados ao %@ para combinar o turno.",
            "Trabalhariam lá de novo: %lld de %lld",
        ]
        for padrao in padroesInterpolados {
            #expect(chaves.contains(padrao), "padrão interpolado fora do catálogo: \(padrao)")
        }
    }

    @Test("Todas as mensagens de erro de API (MensagemDoErroAPI) existem no catálogo pt-BR")
    func errosAPIEstaoNoCatalogo() throws {
        let (chaves, _) = try Self.carregarCatalogo()

        let codigos: [CodigoErroAPI] = [
            .posicaoJaPreenchida,
            .vagaEncerrada,
            .checkinPendente,
            .checkinJaConfirmado,
            .posicaoNaoCancelavel,
            .semRede,
            .naoAutenticado,
            .semPermissao,
            .perfilIncompativel,
            .limiteExcedido,
            .desconhecido,
        ]

        var faltantes: [String] = []
        for codigo in codigos {
            let msg = MensagemDoErroAPI.texto(ErroDaApi(codigo: codigo))
            if !chaves.contains(msg) {
                faltantes.append("\(codigo): \(msg)")
            }
        }
        #expect(faltantes.isEmpty, "mensagens de erro da API fora do catálogo: \(faltantes)")
    }

    @Test("Literais de interface do app de Release estão no catálogo pt-BR")
    func literaisDeInterfaceEstaoNoCatalogo() throws {
        let (chaves, _) = try Self.carregarCatalogo()

        let literaisEsperados = [
            "Carregando",
            "Carregando…",
            "Código de acesso",
            "Digite os seis números enviados para seu e-mail",
            "%lld vagas abertas",
            "Vaga de %@",
            "Refeição",
            "Transporte",
            "Sim",
            "Não",
            "Chamaria de novo?",
            "Algo deu errado",
            "Tentar novamente",
            "Sem conexão. Mostrando os dados salvos neste aparelho.",
            "Atualize o Frila para continuar.",
            "Atualização necessária",
            "Atualizar agora",
            "Abre o detalhe da vaga",
            "filtro ativo",
            "%lld aberta(s) de %lld",
            "Refeição: %@",
            "Transporte: %@",
            "Material próprio: %@",
        ]

        var faltantes: [String] = []
        for literal in literaisEsperados {
            if !chaves.contains(literal) {
                faltantes.append(literal)
            }
        }
        #expect(faltantes.isEmpty, "literais de interface fora do catálogo: \(faltantes)")
    }

    @Test("Variação de plural para '%lld vagas abertas' está definida no catálogo pt-BR com one e other")
    func pluralVagasAbertas() throws {
        let url = Self.raiz.appending(path: "Resources/Localizable.xcstrings")
        let dados = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: dados) as? [String: Any]
        let strings = json?["strings"] as? [String: Any]
        let entrada = strings?["%lld vagas abertas"] as? [String: Any]
        let localizations = entrada?["localizations"] as? [String: Any]
        let ptBR = localizations?["pt-BR"] as? [String: Any]
        let variations = ptBR?["variations"] as? [String: Any]
        let plural = variations?["plural"] as? [String: Any]

        let one = plural?["one"] as? [String: Any]
        let oneUnit = one?["stringUnit"] as? [String: Any]
        let oneValue = oneUnit?["value"] as? String

        let other = plural?["other"] as? [String: Any]
        let otherUnit = other?["stringUnit"] as? [String: Any]
        let otherValue = otherUnit?["value"] as? String

        #expect(oneValue == "%lld vaga aberta")
        #expect(otherValue == "%lld vagas abertas")
    }
}
