import Foundation
import FrilaDominio

/// Valor que chegou no formato do contrato, mas não cabe no domínio (dia da semana 9, hora 25:00…).
struct ErroDeConversao: Error, Equatable {
    let campo: String
}

/// Tipos do contrato 0.2.4 (`Contrato/openapi.yaml`), um para cada schema usado pelo app.
enum ContratoAPI {
    /// Instantes em ISO-8601 com ou sem fração de segundo, com `Z` ou `+00:00`, como o Postgres
    /// devolve. O `.iso8601` da Foundation do iOS 17 não aceita fração de segundo.
    static func decodificador() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let texto = try container.decode(String.self)
            guard let data = instante(texto) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Instante fora do ISO-8601")
            }
            return data
        }
        return decoder
    }

    static func instante(_ texto: String) -> Date? {
        FormatosDeInstante.comFracao.date(from: texto) ?? FormatosDeInstante.semFracao.date(from: texto)
    }

    static func texto(_ instante: Date) -> String {
        FormatosDeInstante.semFracao.string(from: instante)
    }

    // MARK: Conta

    struct UsuarioDTO: Decodable {
        let id: UUID
        let perfil: PerfilConta
        let nome: String
        let telefone: String
        let email: String
        let nascimento: String
        let estado: EstadoConta

        func dominio() throws -> Conta {
            guard let data = try? DataCivil(nascimento) else { throw ErroDeConversao(campo: "nascimento") }
            return Conta(id: id, perfil: perfil, nome: nome, telefone: telefone, email: email, nascimento: data, estado: estado)
        }
    }

    struct CriarConta: Encodable {
        let perfil: PerfilConta
        let nome: String
        let telefone: String
        let nascimento: String
        let termosVersao: String

        init(_ cadastro: CadastroConta) {
            perfil = cadastro.perfil
            nome = cadastro.nome
            telefone = cadastro.telefone
            nascimento = cadastro.nascimento.contrato
            termosVersao = cadastro.versaoTermos
        }

        enum CodingKeys: String, CodingKey {
            case perfil, nome, telefone, nascimento
            case termosVersao = "termos_versao"
        }
    }

    struct SessaoDTO: Decodable {
        let accessToken: String
        let refreshToken: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
        }
    }

    struct EntrarDemonstracao: Encodable {
        let email: String
        let codigo: String
    }

    // MARK: Perfil profissional

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

    struct JanelaDTO: Codable {
        let diaSemana: Int
        let horaInicio: String
        let horaFim: String

        init(_ janela: JanelaDeDisponibilidade) {
            diaSemana = janela.diaDaSemana
            horaInicio = janela.inicio.contrato
            horaFim = janela.fim.contrato
        }

        enum CodingKeys: String, CodingKey {
            case diaSemana = "dia_semana"
            case horaInicio = "hora_inicio"
            case horaFim = "hora_fim"
        }

        func dominio() throws -> JanelaDeDisponibilidade {
            guard (0...6).contains(diaSemana) else { throw ErroDeConversao(campo: "dia_semana") }
            guard let inicio = try? HoraDoDia(horaInicio), let fim = try? HoraDoDia(horaFim) else {
                throw ErroDeConversao(campo: "hora_inicio")
            }
            return JanelaDeDisponibilidade(diaDaSemana: diaSemana, inicio: inicio, fim: fim)
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
        let turnosRealizados: Int

        enum CodingKeys: String, CodingKey {
            case positivas, total
            case taxaComparecimento = "taxa_comparecimento"
            case turnosConsiderados = "turnos_considerados"
            case turnosRealizados = "turnos_realizados"
        }

        func dominio() -> Reputacao {
            Reputacao(
                positivas: positivas,
                total: total,
                taxaComparecimento: taxaComparecimento,
                turnosConsiderados: turnosConsiderados,
                turnosRealizados: turnosRealizados
            )
        }
    }

    struct PerfilPublicoDTO: Decodable {
        let id: UUID
        let tipo: TipoPerfilPublico
        let nome: String
        let funcoes: [String]?
        let reputacao: ReputacaoDTO

        func dominio() -> PerfilPublico {
            PerfilPublico(id: id, tipo: tipo, nome: nome, funcoes: funcoes ?? [], reputacao: reputacao.dominio())
        }
    }

    struct PerfilProfissionalDTO: Decodable {
        let id: UUID
        let usuarioID: UUID
        let funcoes: [FuncaoDTO]
        let pontoBase: CoordenadaDTO
        let disponibilidades: [JanelaDTO]
        let reputacao: ReputacaoDTO

        enum CodingKeys: String, CodingKey {
            case id, funcoes, disponibilidades, reputacao
            case usuarioID = "usuario_id"
            case pontoBase = "ponto_base"
        }

        func dominio() throws -> PerfilProfissional {
            try PerfilProfissional(
                id: id,
                usuarioID: usuarioID,
                funcoes: funcoes.map { $0.dominio() },
                pontoBase: pontoBase.dominio(),
                disponibilidades: disponibilidades.map { try $0.dominio() },
                reputacao: reputacao.dominio()
            )
        }
    }

    struct DadosPerfilProfissionalDTO: Encodable {
        let funcoes: [UUID]
        let pontoBase: CoordenadaDTO
        let disponibilidades: [JanelaDTO]

        init(_ dados: DadosPerfilProfissional) {
            funcoes = dados.funcoes
            pontoBase = CoordenadaDTO(dados.pontoBase)
            disponibilidades = dados.disponibilidades.map(JanelaDTO.init)
        }

        enum CodingKeys: String, CodingKey {
            case funcoes, disponibilidades
            case pontoBase = "ponto_base"
        }
    }

    struct AlteracaoPerfilProfissionalDTO: Encodable {
        let funcoes: [UUID]?
        let pontoBase: CoordenadaDTO?
        let disponibilidades: [JanelaDTO]?

        init(_ alteracao: AlteracaoPerfilProfissional) {
            funcoes = alteracao.funcoes
            pontoBase = alteracao.pontoBase.map(CoordenadaDTO.init)
            disponibilidades = alteracao.disponibilidades?.map(JanelaDTO.init)
        }

        enum CodingKeys: String, CodingKey {
            case funcoes, disponibilidades
            case pontoBase = "ponto_base"
        }
    }

    // MARK: Estabelecimento

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

    struct CadastroEstabelecimentoDTO: Encodable {
        let nome: String
        let documento: String
        let tipo: TipoEstabelecimento
        let endereco: String
        let ponto: CoordenadaDTO

        init(_ cadastro: CadastroEstabelecimento) {
            nome = cadastro.nome
            documento = cadastro.documento
            tipo = cadastro.tipo
            endereco = cadastro.endereco
            ponto = CoordenadaDTO(cadastro.ponto)
        }
    }

    struct EstabelecimentoDaContaDTO: Decodable {
        let id: UUID
        let nome: String
        let papel: PapelMembro
        let tipo: TipoEstabelecimento?
        let reputacao: ReputacaoDTO?

        func dominio() -> EstabelecimentoDaConta {
            EstabelecimentoDaConta(id: id, nome: nome, papel: papel, tipo: tipo, reputacao: reputacao?.dominio())
        }
    }

    // MARK: Vagas

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
        let estabelecimento: PerfilPublicoDTO
        let funcao: FuncaoDTO
        let inicioEm: Date
        let fimEm: Date
        let local: String
        let ponto: CoordenadaDTO
        let distanciaKm: Double?
        let valorCentavos: Int
        let posicoes: Int
        let posicoesAbertas: Int
        let inclusos: InclusosDTO
        let responsavelLocal: String
        let traje: String?
        let participaRateio: Bool?
        let observacoes: String?
        let modo: ModoPreenchimento
        let estado: EstadoVaga
        let publicadoEm: Date

        enum CodingKeys: String, CodingKey {
            case id, estabelecimento, funcao, local, ponto, posicoes, inclusos, traje, observacoes, modo, estado
            case inicioEm = "inicio_em"
            case fimEm = "fim_em"
            case distanciaKm = "distancia_km"
            case valorCentavos = "valor_centavos"
            case posicoesAbertas = "posicoes_abertas"
            case responsavelLocal = "responsavel_local"
            case participaRateio = "participa_rateio"
            case publicadoEm = "publicado_em"
        }

        func dominio() throws -> Vaga {
            try Vaga(
                id: id,
                estabelecimento: estabelecimento.dominio(),
                funcao: funcao.dominio(),
                periodo: Periodo(inicio: inicioEm, fim: fimEm),
                local: local,
                ponto: ponto.dominio(),
                distanciaKm: distanciaKm,
                valor: Dinheiro(centavos: valorCentavos),
                posicoes: posicoes,
                posicoesAbertas: posicoesAbertas,
                inclusos: inclusos.dominio(),
                responsavelLocal: responsavelLocal,
                traje: traje,
                participaRateio: participaRateio,
                observacoes: observacoes,
                modo: modo,
                estado: estado,
                publicadoEm: publicadoEm
            )
        }
    }

    struct VagaNaListaDTO: Decodable {
        let id: UUID
        let funcao: FuncaoDTO
        let estabelecimento: PerfilPublicoDTO
        let inicioEm: Date
        let fimEm: Date
        let local: String
        let distanciaKm: Double
        let valorCentavos: Int
        let posicoesAbertas: Int
        let inclusos: InclusosDTO
        let modo: ModoPreenchimento

        enum CodingKeys: String, CodingKey {
            case id, funcao, estabelecimento, local, inclusos, modo
            case inicioEm = "inicio_em"
            case fimEm = "fim_em"
            case distanciaKm = "distancia_km"
            case valorCentavos = "valor_centavos"
            case posicoesAbertas = "posicoes_abertas"
        }

        func dominio() throws -> VagaNaLista {
            try VagaNaLista(
                id: id,
                funcao: funcao.dominio(),
                estabelecimento: estabelecimento.dominio(),
                periodo: Periodo(inicio: inicioEm, fim: fimEm),
                local: local,
                distanciaKm: distanciaKm,
                valor: Dinheiro(centavos: valorCentavos),
                posicoesAbertas: posicoesAbertas,
                inclusos: inclusos.dominio(),
                modo: modo
            )
        }
    }

    struct VagaResumoDTO: Decodable {
        let id: UUID
        let funcao: String
        let local: String
        let inicioEm: Date
        let fimEm: Date
        let valorCentavos: Int

        enum CodingKeys: String, CodingKey {
            case id, funcao, local
            case inicioEm = "inicio_em"
            case fimEm = "fim_em"
            case valorCentavos = "valor_centavos"
        }

        func dominio() throws -> VagaResumo {
            try VagaResumo(id: id, funcao: funcao, local: local, periodo: Periodo(inicio: inicioEm, fim: fimEm), valor: Dinheiro(centavos: valorCentavos))
        }
    }

    struct NovaVaga: Encodable {
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
        let traje: String?
        let participaRateio: Bool?
        let observacoes: String?
        let modo: ModoPreenchimento
        let alertaAntecedenciaMin: Int?
        let chave: UUID

        init(_ publicacao: PublicacaoVaga) {
            estabelecimentoID = publicacao.estabelecimentoID
            funcaoID = publicacao.funcaoID
            inicioEm = ContratoAPI.texto(publicacao.periodo.inicio)
            fimEm = ContratoAPI.texto(publicacao.periodo.fim)
            local = publicacao.local
            ponto = CoordenadaDTO(publicacao.ponto)
            valorCentavos = publicacao.valor.centavos
            posicoes = publicacao.posicoes
            incluiRefeicao = publicacao.inclusos.refeicao
            incluiTransporte = publicacao.inclusos.transporte
            exigeMaterialProprio = publicacao.inclusos.exigeMaterialProprio
            responsavelLocal = publicacao.responsavelLocal
            traje = publicacao.traje
            participaRateio = publicacao.participaRateio
            observacoes = publicacao.observacoes
            modo = publicacao.modo
            alertaAntecedenciaMin = publicacao.alertaAntecedenciaMinutos
            chave = publicacao.chave
        }

        enum CodingKeys: String, CodingKey {
            case local, ponto, posicoes, traje, observacoes, modo, chave
            case estabelecimentoID = "estabelecimento_id"
            case funcaoID = "funcao_id"
            case inicioEm = "inicio_em"
            case fimEm = "fim_em"
            case valorCentavos = "valor_centavos"
            case incluiRefeicao = "inclui_refeicao"
            case incluiTransporte = "inclui_transporte"
            case exigeMaterialProprio = "exige_material_proprio"
            case responsavelLocal = "responsavel_local"
            case participaRateio = "participa_rateio"
            case alertaAntecedenciaMin = "alerta_antecedencia_min"
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

    struct FiltroVagasDTO: Encodable {
        let latitude: Double?
        let longitude: Double?
        let funcaoID: UUID?
        let data: String?
        let distanciaMaxKm: Double?
        let limite: Int?
        let deslocamento: Int?

        init(_ filtro: FiltroVagas) {
            latitude = filtro.referencia?.latitude
            longitude = filtro.referencia?.longitude
            funcaoID = filtro.funcaoID
            data = filtro.data?.contrato
            distanciaMaxKm = filtro.distanciaMaximaKm
            limite = filtro.limite
            deslocamento = filtro.deslocamento
        }

        enum CodingKeys: String, CodingKey {
            case latitude, longitude, data, limite, deslocamento
            case funcaoID = "funcao_id"
            case distanciaMaxKm = "distancia_max_km"
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

    // MARK: Candidatura e turno

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

    struct TurnoDTO: Decodable {
        let id: UUID
        let posicaoID: UUID
        let vaga: VagaResumoDTO
        let contraparte: PerfilPublicoDTO
        let contatoVisivelAte: Date
        let checkinEm: Date?
        let checkinTipo: TipoRegistro?
        let checkinDistanciaM: Int?
        let checkinConfirmadoEm: Date?
        let checkoutEm: Date?
        let checkoutDistanciaM: Int?
        let verificacao: Verificacao
        let valorAcordadoCentavos: Int
        let podeAvaliar: Bool

        enum CodingKeys: String, CodingKey {
            case id, vaga, contraparte, verificacao
            case posicaoID = "posicao_id"
            case contatoVisivelAte = "contato_visivel_ate"
            case checkinEm = "checkin_em"
            case checkinTipo = "checkin_tipo"
            case checkinDistanciaM = "checkin_distancia_m"
            case checkinConfirmadoEm = "checkin_confirmado_em"
            case checkoutEm = "checkout_em"
            case checkoutDistanciaM = "checkout_distancia_m"
            case valorAcordadoCentavos = "valor_acordado_centavos"
            case podeAvaliar = "pode_avaliar"
        }

        func dominio() throws -> Turno {
            try Turno(
                id: id,
                posicaoID: posicaoID,
                vaga: vaga.dominio(),
                contraparte: contraparte.dominio(),
                contatoVisivelAte: contatoVisivelAte,
                checkin: checkinEm.map {
                    Presenca(instante: $0, tipo: checkinTipo, distanciaMetros: checkinDistanciaM, confirmadaEm: checkinConfirmadoEm)
                },
                checkout: checkoutEm.map { Presenca(instante: $0, distanciaMetros: checkoutDistanciaM) },
                verificacao: verificacao,
                valorAcordado: Dinheiro(centavos: valorAcordadoCentavos),
                podeAvaliar: podeAvaliar
            )
        }
    }

    struct RegistroDePresenca: Encodable {
        let turnoID: UUID
        let distanciaMetros: Int?
        let registradoEm: String

        enum CodingKeys: String, CodingKey {
            case turnoID = "turno_id"
            case distanciaMetros = "distancia_m"
            case registradoEm = "registrado_em"
        }

        // `distancia_m` é obrigatório e aceita nulo: sem localização, ele vai como `null`, não some.
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(turnoID, forKey: .turnoID)
            try container.encode(distanciaMetros, forKey: .distanciaMetros)
            try container.encode(registradoEm, forKey: .registradoEm)
        }
    }

    struct ResultadoRegistroDTO: Decodable {
        let turnoID: UUID
        let tipo: TipoRegistro
        let verificacao: Verificacao
        let registradoEm: Date
        let distanciaMetros: Int?

        enum CodingKeys: String, CodingKey {
            case tipo, verificacao
            case turnoID = "turno_id"
            case registradoEm = "registrado_em"
            case distanciaMetros = "distancia_m"
        }

        func dominio() -> ResultadoRegistro {
            ResultadoRegistro(turnoID: turnoID, tipo: tipo, verificacao: verificacao, registradoEm: registradoEm, distanciaMetros: distanciaMetros)
        }
    }

    struct Avaliar: Encodable {
        let turnoID: UUID
        let resposta: Bool
        enum CodingKeys: String, CodingKey { case turnoID = "turno_id"; case resposta }
    }

    struct AvaliacaoDTO: Decodable {
        let turnoID: UUID
        let resposta: Bool
        let criadaEm: Date
        enum CodingKeys: String, CodingKey { case turnoID = "turno_id"; case resposta; case criadaEm = "criada_em" }
        func dominio() -> Avaliacao { Avaliacao(turnoID: turnoID, resposta: resposta, criadaEm: criadaEm) }
    }

    // MARK: Painel do estabelecimento

    struct PainelParametros: Encodable {
        let estabelecimentoID: UUID
        let de: String
        let ate: String
        enum CodingKeys: String, CodingKey { case estabelecimentoID = "estabelecimento_id"; case de, ate }
    }

    struct PosicaoNoPainelDTO: Decodable {
        let id: UUID
        let estado: EstadoPosicao
        let profissional: PerfilPublicoDTO?
        let turnoID: UUID?
        let verificacao: Verificacao?
        let emAtraso: Bool

        enum CodingKeys: String, CodingKey {
            case id, estado, profissional, verificacao
            case turnoID = "turno_id"
            case emAtraso = "em_atraso"
        }

        func dominio() -> PosicaoNoPainel {
            PosicaoNoPainel(id: id, estado: estado, profissional: profissional?.dominio(), turnoID: turnoID, verificacao: verificacao, emAtraso: emAtraso)
        }
    }

    struct VagaNoPainelDTO: Decodable {
        let vaga: VagaResumoDTO
        let modo: ModoPreenchimento
        let estado: EstadoVaga
        let alertaVagaVazia: Bool
        let candidatosPendentes: Int
        let posicoes: [PosicaoNoPainelDTO]

        enum CodingKeys: String, CodingKey {
            case vaga, modo, estado, posicoes
            case alertaVagaVazia = "alerta_vaga_vazia"
            case candidatosPendentes = "candidatos_pendentes"
        }

        func dominio() throws -> VagaNoPainel {
            try VagaNoPainel(
                vaga: vaga.dominio(),
                modo: modo,
                estado: estado,
                alertaVagaVazia: alertaVagaVazia,
                candidatosPendentes: candidatosPendentes,
                posicoes: posicoes.map { $0.dominio() }
            )
        }
    }

    struct PainelDTO: Decodable {
        let estabelecimentoID: UUID
        let vagas: [VagaNoPainelDTO]
        let checkinsPendentes: [UUID]

        enum CodingKeys: String, CodingKey {
            case vagas
            case estabelecimentoID = "estabelecimento_id"
            case checkinsPendentes = "checkins_pendentes"
        }

        func dominio() throws -> Painel {
            try Painel(estabelecimentoID: estabelecimentoID, vagas: vagas.map { try $0.dominio() }, checkinsPendentes: checkinsPendentes)
        }
    }

    // MARK: Aplicativo

    struct ConfiguracaoDoAppDTO: Decodable {
        let versaoMinima: String
        let versaoRecomendada: String
        let urlDaLoja: URL
        let mensagem: String?

        enum CodingKeys: String, CodingKey {
            case mensagem
            case versaoMinima = "versao_minima"
            case versaoRecomendada = "versao_recomendada"
            case urlDaLoja = "url_da_loja"
        }

        func dominio() -> ConfiguracaoApp {
            ConfiguracaoApp(versaoMinima: versaoMinima, versaoRecomendada: versaoRecomendada, mensagem: mensagem, urlDaLoja: urlDaLoja)
        }
    }

    struct RemocaoDTO: Decodable {
        let removido: Bool
    }
}

private enum FormatosDeInstante {
    // ISO8601DateFormatter é seguro entre threads; o compilador só não sabe disso.
    nonisolated(unsafe) static let comFracao: ISO8601DateFormatter = {
        let formatador = ISO8601DateFormatter()
        formatador.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatador
    }()

    nonisolated(unsafe) static let semFracao: ISO8601DateFormatter = {
        let formatador = ISO8601DateFormatter()
        formatador.formatOptions = [.withInternetDateTime]
        return formatador
    }()
}

private struct ChaveDinamica: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}
