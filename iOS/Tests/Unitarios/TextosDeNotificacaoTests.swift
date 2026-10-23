import Foundation
import FrilaDominio
import Testing

/// Testes que guardam os textos de push e garantem conformidade com a planilha e regras do iPhone SE (#8, VyY2SGsX).
///
/// A planilha `iOS/Docs/TextosDeNotificacao.md` define os 19 tipos de aviso e as regras de partida da tela bloqueada
/// (título ≤ 40 caracteres, corpo ≤ 110 caracteres). Estes testes leem o documento em tempo de execução e validam
/// a concordância estrita com o enum `TipoDeAviso` do app e a ausência total de dados pessoais ou sensíveis.
@Suite("Textos de notificação: planilha, regras de tela bloqueada e limites do iPhone SE (#8, VyY2SGsX)")
struct TextosDeNotificacaoTests {
    private static let raiz = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private static let caminhoDoDoc = raiz.appending(path: "Docs/TextosDeNotificacao.md")
    private static let caminhoDoContrato = raiz.appending(path: "Contrato/openapi.yaml")

    /// Representação de uma linha da tabela de especificação de push (seção 4).
    struct LinhaDaTabela: Sendable {
        let numero: String
        let tipo: String
        let cenario: String
        let gatilho: String
        let quemRecebe: String
        let titulo: String
        let limiteTitulo: String
        let corpoBruto: String
        let limiteCorpo: String
        let destino: String
        let restricoes: String

        struct VarianteDeCorpo: Sendable {
            let rotulo: String
            let texto: String
        }

        /// Extrai as variantes de corpo da célula (texto principal, fallback ou proposta ajustada).
        var variantesDeCorpo: [VarianteDeCorpo] {
            // Caso com proposta ajustada (linha 29 - candidatura_recusada)
            if corpoBruto.contains("**Proposta ajustada:**") {
                let partes = corpoBruto.components(separatedBy: "**Proposta ajustada:**")
                let contrato = partes[0]
                    .replacingOccurrences(of: #"\s*\*\(Texto.*"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let proposta = partes.count > 1 ? partes[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
                return [
                    VarianteDeCorpo(rotulo: "contrato", texto: contrato),
                    VarianteDeCorpo(rotulo: "proposta", texto: proposta)
                ]
            }

            // Caso com Fallback: *(Fallback: ...)*
            if let regex = try? Regex(#"\*\s*\(Fallback:\s*(.*?)\)\s*\*"#),
               let match = corpoBruto.firstMatch(of: regex) {
                let fallback = String(match.output[1].substring ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let principal = corpoBruto
                    .replacingOccurrences(of: #"\s*\*\s*\(Fallback:.*"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return [
                    VarianteDeCorpo(rotulo: "principal", texto: principal),
                    VarianteDeCorpo(rotulo: "fallback", texto: fallback)
                ]
            }

            return [VarianteDeCorpo(rotulo: "principal", texto: corpoBruto.trimmingCharacters(in: .whitespacesAndNewlines))]
        }

        /// Substitui placeholders `{..}` por valores realistas para aferição do tamanho do texto renderizado.
        func textoSimulado(_ texto: String) -> String {
            texto
                .replacingOccurrences(of: "{Função}", with: "Garçom")
                .replacingOccurrences(of: "{função}", with: "garçom")
                .replacingOccurrences(of: "{região}", with: "Asa Sul")
                .replacingOccurrences(of: "{estabelecimento}", with: "Restaurante do Lago")
                .replacingOccurrences(of: "{horário}", with: "19:00")
                .replacingOccurrences(of: "{N}", with: "3")
                .replacingOccurrences(of: "{dd/mm às HH:MM}", with: "15/10 às 18:00")
        }
    }

    /// Lê e extrai as 32 linhas da tabela da seção 4 de `iOS/Docs/TextosDeNotificacao.md`.
    private static func carregarTabela() throws -> [LinhaDaTabela] {
        let conteudo = try String(contentsOf: caminhoDoDoc, encoding: .utf8)
        let linhas = conteudo.components(separatedBy: .newlines)

        var linhasDeDados: [LinhaDaTabela] = []
        let regexLinha = try Regex(#"^\|\s*(\d+)\s*\|"#)

        for linha in linhas {
            let aparada = linha.trimmingCharacters(in: .whitespaces)
            guard aparada.starts(with: "|"), aparada.contains(regexLinha) else { continue }

            let colunas = aparada.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }

            // Formato Markdown: '| col1 | col2 | ... | col11 |' produz 13 elementos (com [0] e [12] vazios)
            guard colunas.count >= 12 else { continue }

            let num = colunas[1]
            let tipo = colunas[2].replacingOccurrences(of: "`", with: "")
            let cenario = colunas[3]
            let gatilho = colunas[4]
            let quemRecebe = colunas[5]
            let titulo = colunas[6]
            let limiteTitulo = colunas[7]
            let corpoBruto = colunas[8]
            let limiteCorpo = colunas[9]
            let destino = colunas[10]
            let restricoes = colunas[11]

            linhasDeDados.append(
                LinhaDaTabela(
                    numero: num,
                    tipo: tipo,
                    cenario: cenario,
                    gatilho: gatilho,
                    quemRecebe: quemRecebe,
                    titulo: titulo,
                    limiteTitulo: limiteTitulo,
                    corpoBruto: corpoBruto,
                    limiteCorpo: limiteCorpo,
                    destino: destino,
                    restricoes: restricoes
                )
            )
        }

        return linhasDeDados
    }

    @Test("A planilha cobre exatamente 19 tipos únicos que concordam 1:1 com TipoDeAviso.allCases")
    func tiposConcordamComCodigo() throws {
        let tabela = try Self.carregarTabela()
        #expect(tabela.count == 32, "A tabela da seção 4 deve conter exatamente 32 linhas de cenários")

        let tiposNaPlanilha = Set(tabela.map(\.tipo))
        let tiposNoCodigo = Set(TipoDeAviso.allCases.map(\.rawValue))

        #expect(tiposNaPlanilha.count == 19, "A planilha deve cobrir exatamente 19 tipos únicos de notificação")
        #expect(tiposNoCodigo.count == 19, "O enum TipoDeAviso deve ter exatamente 19 casos")

        let faltandoNoCodigo = tiposNaPlanilha.subtracting(tiposNoCodigo)
        let faltandoNaPlanilha = tiposNoCodigo.subtracting(tiposNaPlanilha)

        #expect(faltandoNoCodigo.isEmpty, "Tipos da planilha ausentes em TipoDeAviso: \(faltandoNoCodigo)")
        #expect(faltandoNaPlanilha.isEmpty, "Tipos de TipoDeAviso ausentes na planilha: \(faltandoNaPlanilha)")
    }

    @Test("Todo título da planilha cumpre a regra de partida de até 40 caracteres (iPhone SE)")
    func limitesDeTitulo() throws {
        let tabela = try Self.carregarTabela()
        #expect(!tabela.isEmpty, "Tabela de notificações não pode estar vazia")

        for linha in tabela {
            #expect(
                linha.titulo.count <= 40,
                "Linha \(linha.numero) (\(linha.tipo)): título '\(linha.titulo)' excede 40 caracteres (\(linha.titulo.count) car.)"
            )
            #expect(!linha.titulo.isEmpty, "Linha \(linha.numero) (\(linha.tipo)) possui título vazio")
            #expect(!linha.titulo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Linha \(linha.numero) (\(linha.tipo)) possui título composto apenas por espaços")
        }
    }

    @Test("Todo corpo na planilha cumpre o teto de 110 caracteres da tela bloqueada (iPhone SE)")
    func limitesDeCorpo() throws {
        let tabela = try Self.carregarTabela()
        #expect(!tabela.isEmpty, "Tabela de notificações não pode estar vazia")

        for linha in tabela {
            for variante in linha.variantesDeCorpo {
                // A linha 29 possui uma divergência real no contrato (128 car.), cuja proposta ajustada mede 79 car.
                if linha.numero == "29" && variante.rotulo == "contrato" {
                    continue
                }

                let textoAferido = linha.textoSimulado(variante.texto)
                #expect(
                    textoAferido.count <= 110,
                    "Linha \(linha.numero) (\(linha.tipo)) [\(variante.rotulo)]: corpo '\(textoAferido)' excede 110 caracteres (\(textoAferido.count) car.)"
                )
                #expect(!textoAferido.isEmpty, "Linha \(linha.numero) (\(linha.tipo)) possui corpo vazio")
                #expect(!textoAferido.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Linha \(linha.numero) (\(linha.tipo)) [\(variante.rotulo)] possui corpo composto apenas por espaços")
            }
        }
    }

    @Test("Divergência real documentada na linha 29 (candidatura_recusada): contrato excede 110 caracteres e proposta ajustada cumpre o limite")
    func divergenciaDocumentadaLinha29() throws {
        let tabela = try Self.carregarTabela()
        let linha29 = try #require(tabela.first(where: { $0.numero == "29" }))

        #expect(linha29.tipo == "candidatura_recusada")
        #expect(linha29.limiteCorpo.contains("128 (TRUNCA)"))
        #expect(linha29.limiteCorpo.contains("79 (OK)") || linha29.limiteCorpo.contains("Proposta"))

        let variantes = linha29.variantesDeCorpo
        let contrato = try #require(variantes.first(where: { $0.rotulo == "contrato" }))
        let proposta = try #require(variantes.first(where: { $0.rotulo == "proposta" }))

        #expect(contrato.texto.count == 128, "Texto do contrato de candidatura_recusada deve ter exatamente 128 car.")
        #expect(contrato.texto.count > 110, "Texto do contrato ultrapassa o limite de 110 car. do iPhone SE")
        #expect(proposta.texto.count == 79)
        #expect(proposta.texto.count <= 110, "Proposta ajustada deve cumprir o limite de 110 car.")
    }

    @Test("Nenhum texto de push contém telefone, e-mail, motivo de suspensão nem relato de denúncia (RN10, RN15)")
    func semDadosPessoaisOuSensiveis() throws {
        let tabela = try Self.carregarTabela()
        #expect(!tabela.isEmpty, "Tabela de notificações não pode estar vazia")

        let padraoEmail = try Regex(#"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#)
        let padraoTelefone = try Regex(#"(?:\+?\d{1,3}[\s-]?)?(?:\(?\d{2,4}\)?[\s-]?)?(?:9\s*)?\d{4,5}[-\s]?\d{4}"#)
        let padraoMotivoSuspensao = try Regex(#"(?:motivo|justificativa|razão|razao)\s*(?:d[aeo]\s*)?suspens[ãa]o|suspenso\s*por"#).ignoresCase()
        let padraoRelatoDenuncia = try Regex(#"(?:relato|motivo|justificativa|razão|razao)\s*(?:d[aeo]\s*)?denúncia|denuncia|denunciad[oa]\s*por"#).ignoresCase()
        let padraoTermosProibidos = try Regex(#"(?:suspens[ãa]o|den[uú]ncia|fraude|bloquead[oa])"#).ignoresCase()

        for linha in tabela {
            let textosParaValidar = [linha.titulo] + linha.variantesDeCorpo.map(\.texto)

            for texto in textosParaValidar {
                #expect(!texto.contains(padraoEmail), "Linha \(linha.numero) (\(linha.tipo)): contém e-mail pessoal: '\(texto)'")
                #expect(!texto.contains(padraoTelefone), "Linha \(linha.numero) (\(linha.tipo)): contém número de telefone: '\(texto)'")
                #expect(!texto.contains(padraoMotivoSuspensao), "Linha \(linha.numero) (\(linha.tipo)): contém motivo de suspensão: '\(texto)'")
                #expect(!texto.contains(padraoRelatoDenuncia), "Linha \(linha.numero) (\(linha.tipo)): contém relato de denúncia: '\(texto)'")
                #expect(!texto.contains(padraoTermosProibidos), "Linha \(linha.numero) (\(linha.tipo)): contém termo proibido: '\(texto)'")
            }
        }
    }

    @Test("Payload de AvisoDePush não contém dados sensíveis nem chaves além dos identificadores (RN10, RN15)")
    func payloadAvisoDePushSemCamposSensiveis() {
        let chavesPermitidas: Set<String> = ["tipo", "vaga_id", "turno_id", "posicao_id"]
        for tipo in TipoDeAviso.allCases {
            let aviso = AvisoDePush(tipo: tipo, vagaID: UUID(), turnoID: UUID(), posicaoID: UUID())
            let chavesDoPayload = Set(aviso.payload.keys)
            #expect(chavesDoPayload.isSubset(of: chavesPermitidas), "Payload de \(tipo) traz chaves além das permitidas: \(chavesDoPayload)")
        }
    }

    @Test("O contrato OpenAPI (iOS/Contrato/openapi.yaml) concorda com os 19 tipos de TipoDeAviso")
    func tiposConcordamComContratoOpenAPI() throws {
        let conteudo = try String(contentsOf: Self.caminhoDoContrato, encoding: .utf8)
        let regex = try Regex(#"TipoNotificacao:[\s\S]*?enum:\s*\[([\s\S]*?)\]"#)
        let match = try #require(conteudo.firstMatch(of: regex))

        let rawEnums = String(match.output[1].substring ?? "")
        let tiposOpenAPI = Set(
            rawEnums
                .replacingOccurrences(of: "\n", with: "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )

        let tiposNoCodigo = Set(TipoDeAviso.allCases.map(\.rawValue))

        #expect(tiposOpenAPI.count == 19, "O contrato OpenAPI deve conter exatamente 19 tipos em TipoNotificacao")
        #expect(tiposOpenAPI == tiposNoCodigo, "Divergência entre TipoNotificacao do openapi.yaml e TipoDeAviso do código")
    }

    @Test("A tabela de inventário da seção 3 contém exatamente 19 linhas correspondentes a TipoDeAviso.allCases")
    func inventarioSecao3Tem19Linhas() throws {
        let conteudo = try String(contentsOf: Self.caminhoDoDoc, encoding: .utf8)
        let linhas = conteudo.components(separatedBy: .newlines)

        var tiposSecao3: [String] = []
        var emSecao3 = false

        for linha in linhas {
            if linha.contains("## 3. Inventário de Tipos de Notificação") {
                emSecao3 = true
                continue
            }
            if emSecao3 && linha.starts(with: "## 4.") {
                break
            }
            if emSecao3 && linha.starts(with: "| `") {
                let partes = linha.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                if !partes.isEmpty {
                    let tipo = partes[0].replacingOccurrences(of: "`", with: "")
                    tiposSecao3.append(tipo)
                }
            }
        }

        #expect(tiposSecao3.count == 19, "A tabela da seção 3 deve ter exatamente 19 linhas")
        let tiposNoCodigo = Set(TipoDeAviso.allCases.map(\.rawValue))
        #expect(Set(tiposSecao3) == tiposNoCodigo, "Tipos da seção 3 devem ser idênticos a TipoDeAviso.allCases")
    }

    @Test("Planilha segue as decisões do Backlog v1.2.1 sobre US10, US14 e RF12 com link de decisão (#VyY2SGsX)")
    func decisoesBacklogV121() throws {
        let conteudo = try String(contentsOf: Self.caminhoDoDoc, encoding: .utf8)

        #expect(conteudo.contains("## 2. Resolução dos Três Conflitos do Cartão (Sprint 0 / Backlog v1.2.1)"), "Doc deve conter a seção de resolução dos conflitos do Backlog v1.2.1")
        #expect(conteudo.contains("Conflito 1: Ação interativa \"Aceitar Turno\" na notificação (US10) vs. Aviso da RN10"), "Deve registrar a resolução de US10")
        #expect(conteudo.contains("Conflito 2: Telefone de contato no lembrete (RF12) vs. Janela de 7 dias e persistência na Central (RN10 / RN15)"), "Deve registrar a resolução de RF12")
        #expect(conteudo.contains("Conflito 3: Funcionalidade e notificação \"Estou a caminho\" (US14)"), "Deve registrar a resolução de US14")
        #expect(conteudo.contains("8zLfn0mt"), "Deve citar o link do cartão de decisão 8zLfn0mt")

        // Valida que nenhum push traz ação de aceitar direto no banner (US10)
        let tabela = try Self.carregarTabela()
        for linha in tabela {
            #expect(!linha.corpoBruto.localizedCaseInsensitiveContains("Aceitar Turno"), "Nenhum push pode sugerir ação interativa 'Aceitar Turno' no banner")
        }
    }
}

