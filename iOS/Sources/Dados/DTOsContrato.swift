import Foundation
import FrilaDominio

enum ContratoAPI {
    struct CriarConta: Encodable {
        let perfil: String
        let nome: String
        let telefone: String
        let nascimento: String
        let versaoTermos: String
        let aceitouEm: String

        enum CodingKeys: String, CodingKey {
            case perfil, nome, telefone, nascimento
            case versaoTermos = "versao_termos"
            case aceitouEm = "aceitou_em"
        }
    }

    struct Usuario: Decodable {
        let id: UUID
        let perfil: PerfilConta
    }

    struct CoordenadaDTO: Codable {
        let latitude: Double
        let longitude: Double

        init(_ valor: Coordenada) {
            latitude = valor.latitude
            longitude = valor.longitude
        }

        func dominio() throws -> Coordenada {
            try Coordenada(latitude: latitude, longitude: longitude)
        }
    }

    struct FuncaoDTO: Codable {
        let id: UUID
        let nome: String
        let categoria: String
        func dominio() -> Funcao { Funcao(id: id, nome: nome, categoria: categoria) }
    }

    struct ReputacaoDTO: Codable {
        let positivas: Int
        let total: Int
        let taxaComparecimento: Double?
        let turnosConsiderados: Int

        enum CodingKeys: String, CodingKey {
            case positivas, total
            case taxaComparecimento = "taxa_comparecimento"
            case turnosConsiderados = "turnos_considerados"
        }

        func dominio() -> Reputacao {
            Reputacao(
                positivas: positivas,
                total: total,
                taxaComparecimento: taxaComparecimento,
                turnosConsiderados: turnosConsiderados
            )
        }
    }

    struct PerfilPublicoDTO: Codable {
        let id: UUID
        let nome: String
        let reputacao: ReputacaoDTO
    }

    struct EstabelecimentoDTO: Codable {
        let id: UUID
        let nome: String
        let documento: String
        let tipo: TipoEstabelecimento
        let endereco: String
        let ponto: CoordenadaDTO
        let papel: PapelMembro

        func dominio() throws -> Estabelecimento {
            try Estabelecimento(id: id, nome: nome, documento: documento, tipo: tipo, endereco: endereco, ponto: ponto.dominio(), papel: papel)
        }
    }

    struct InclusosDTO: Codable {
        let incluiRefeicao: Bool
        let incluiTransporte: Bool
        let exigeMaterialProprio: Bool

        enum CodingKeys: String, CodingKey {
            case incluiRefeicao = "inclui_refeicao"
            case incluiTransporte = "inclui_transporte"
            case exigeMaterialProprio = "exige_material_proprio"
        }

        func dominio() -> Inclusos {
            Inclusos(refeicao: incluiRefeicao, transporte: incluiTransporte, exigeMaterialProprio: exigeMaterialProprio)
        }
    }

    struct VagaDTO: Decodable {
        let id: UUID
        let estabelecimento: EstabelecimentoDTO
        let funcao: FuncaoDTO
        let inicioEm: Date
        let fimEm: Date
        let local: String
        let ponto: CoordenadaDTO
        let valorCentavos: Int
        let posicoes: Int
        let posicoesAbertas: Int
        let inclusos: InclusosDTO
        let responsavelLocal: String
        let modo: ModoPreenchimento
        let estado: EstadoVaga

        enum CodingKeys: String, CodingKey {
            case id, estabelecimento, funcao, local, ponto, posicoes, inclusos, modo, estado
            case inicioEm = "inicio_em"
            case fimEm = "fim_em"
            case valorCentavos = "valor_centavos"
            case posicoesAbertas = "posicoes_abertas"
            case responsavelLocal = "responsavel_local"
        }

        func dominio() throws -> Vaga {
            try Vaga(
                id: id,
                estabelecimento: estabelecimento.dominio(),
                funcao: funcao.dominio(),
                periodo: Periodo(inicio: inicioEm, fim: fimEm),
                local: local,
                ponto: ponto.dominio(),
                valor: Dinheiro(centavos: valorCentavos),
                posicoes: posicoes,
                posicoesAbertas: posicoesAbertas,
                inclusos: inclusos.dominio(),
                responsavelLocal: responsavelLocal,
                modo: modo,
                estado: estado
            )
        }
    }

    struct PublicarVaga: Encodable {
        let estabelecimentoID: UUID
        let funcaoID: UUID
        let inicioEm: String
        let fimEm: String
        let local: String
        let ponto: CoordenadaDTO
        let valorCentavos: Int
        let posicoes: Int
        let incluiRefeicao: Bool
        let incluiTransporte: Bool
        let exigeMaterialProprio: Bool
        let responsavelLocal: String
        let modo: ModoPreenchimento
        let chave: UUID

        enum CodingKeys: String, CodingKey {
            case local, ponto, posicoes, modo, chave
            case estabelecimentoID = "estabelecimento_id"
            case funcaoID = "funcao_id"
            case inicioEm = "inicio_em"
            case fimEm = "fim_em"
            case valorCentavos = "valor_centavos"
            case incluiRefeicao = "inclui_refeicao"
            case incluiTransporte = "inclui_transporte"
            case exigeMaterialProprio = "exige_material_proprio"
            case responsavelLocal = "responsavel_local"
        }
    }

    struct VagaPublicadaDTO: Decodable {
        let vagaID: UUID
        let posicoes: [UUID]
        enum CodingKeys: String, CodingKey { case vagaID = "vaga_id"; case posicoes }
        func dominio() -> VagaPublicada { VagaPublicada(vagaID: vagaID, posicoes: posicoes) }
    }

    struct RepublicarVaga: Encodable {
        let vagaID: UUID
        let inicioEm: String
        let fimEm: String
        let chave: UUID
        enum CodingKeys: String, CodingKey {
            case vagaID = "vaga_id"; case inicioEm = "inicio_em"; case fimEm = "fim_em"; case chave
        }
    }

    struct ID: Encodable {
        let id: UUID
        init(_ nome: String, _ id: UUID) { self.id = id; self.nome = nome }
        private let nome: String
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: ChaveDinamica.self)
            try container.encode(id, forKey: ChaveDinamica(stringValue: nome)!)
        }
    }

    struct CandidaturaDTO: Decodable {
        let estado: ResultadoCandidatura.Estado
        let candidaturaID: UUID
        let posicaoID: UUID?
        let turnoID: UUID?
        let contato: ContatoDTO?
        enum CodingKeys: String, CodingKey {
            case estado, contato
            case candidaturaID = "candidatura_id"
            case posicaoID = "posicao_id"
            case turnoID = "turno_id"
        }
        func dominio() -> ResultadoCandidatura {
            ResultadoCandidatura(
                estado: estado,
                candidaturaID: candidaturaID,
                posicaoID: posicaoID,
                turnoID: turnoID,
                contato: contato?.dominio()
            )
        }
    }

    struct ContatoDTO: Codable {
        let nome: String
        let telefone: String
        let whatsappURL: URL
        let visivelAte: Date
        enum CodingKeys: String, CodingKey {
            case nome, telefone
            case whatsappURL = "whatsapp_url"
            case visivelAte = "visivel_ate"
        }
        func dominio() -> Contato { Contato(nome: nome, telefone: telefone, whatsappURL: whatsappURL, visivelAte: visivelAte) }
    }

    struct RegistroPresenca: Encodable {
        let turnoID: UUID
        let distanciaMetros: Int?
        let registradoEm: String
        let chave: UUID
        enum CodingKeys: String, CodingKey {
            case turnoID = "turno_id"
            case distanciaMetros = "distancia_m"
            case registradoEm = "registrado_em"
            case chave
        }
    }

    struct Avaliar: Encodable {
        let turnoID: UUID
        let resposta: Bool
        let chave: UUID
        enum CodingKeys: String, CodingKey { case turnoID = "turno_id"; case resposta, chave }
    }

    struct AvaliacaoDTO: Decodable {
        let turnoID: UUID
        let resposta: Bool
        let criadaEm: Date
        enum CodingKeys: String, CodingKey { case turnoID = "turno_id"; case resposta; case criadaEm = "criada_em" }
        func dominio() -> Avaliacao { Avaliacao(turnoID: turnoID, resposta: resposta, criadaEm: criadaEm) }
    }

    struct ConfiguracaoDTO: Decodable {
        let versaoMinimaIOS: String
        let mensagem: String
        let linkDaLoja: URL
        enum CodingKeys: String, CodingKey {
            case versaoMinimaIOS = "versao_minima_ios"
            case mensagem
            case linkDaLoja = "link_da_loja"
        }
        func dominio() -> ConfiguracaoApp {
            ConfiguracaoApp(versaoMinimaIOS: versaoMinimaIOS, mensagem: mensagem, urlDaLoja: linkDaLoja)
        }
    }
}

private struct ChaveDinamica: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}
