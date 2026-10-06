import Foundation
import FrilaDominio
import OSLog

/// Valor que chegou no formato do contrato, mas não cabe no domínio (dia da semana 9, hora 25:00…).
struct ErroDeConversao: Error, Equatable {
    let campo: String
}

/// Item de uma lista do contrato que pode não decodificar (enum com valor novo, campo fora do
/// formato). Em vez de a resposta inteira falhar, o item sai da lista e os outros seguem: um estado
/// novo numa vaga não pode esconder as demais. Quem lê conta os descartados e registra só a
/// quantidade e a rota, nunca o conteúdo.
struct ItemTolerante<Valor: Decodable>: Decodable {
    let valor: Valor?

    init(from decoder: Decoder) throws {
        valor = try? Valor(from: decoder)
    }
}

extension Array {
    /// Os itens que decodificaram e converteram; o que falhou em qualquer das duas etapas sai.
    func validos<Valor, Dominio>(_ converter: (Valor) throws -> Dominio) -> (itens: [Dominio], descartados: Int)
    where Element == ItemTolerante<Valor> {
        var descartados = 0
        let itens = compactMap { item -> Dominio? in
            guard let valor = item.valor, let dominio = try? converter(valor) else { descartados += 1; return nil }
            return dominio
        }
        return (itens, descartados)
    }
}

/// Tipos do contrato 0.2.27 (`Contrato/openapi.yaml`), um para cada schema usado pelo app.
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

    /// O instante em UTC com três casas de fração (`2026-11-01T02:59:59.999Z`). Arredonda para o
    /// milissegundo mais próximo antes de formatar: o `Date` guarda segundos em `Double`, e
    /// formatar direto poderia truncar .999 para .998.
    static func textoComMilissegundos(_ instante: Date) -> String {
        let milissegundos = Int64((instante.timeIntervalSince1970 * 1000).rounded())
        let segundos = Int64((Double(milissegundos) / 1000).rounded(.down))
        let fracao = milissegundos - segundos * 1000
        let texto = FormatosDeInstante.semFracao.string(from: Date(timeIntervalSince1970: TimeInterval(segundos)))
        return String(texto.dropLast()) + String(format: ".%03lldZ", fracao)
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
        let regiaoAdministrativa: String
        let ponto: CoordenadaDTO
        let papel: PapelMembro

        enum CodingKeys: String, CodingKey {
            case id, nome, documento, tipo, endereco, ponto, papel
            case regiaoAdministrativa = "regiao_administrativa"
        }

        func dominio() throws -> Estabelecimento {
            try Estabelecimento(
                id: id, nome: nome, documento: documento, tipo: tipo, endereco: endereco,
                regiaoAdministrativa: regiaoAdministrativa, ponto: ponto.dominio(), papel: papel
            )
        }
    }

    /// `MeuEstabelecimento` do contrato 0.2.29: devolve o estabelecimento sem o `documento`.
    struct MeuEstabelecimentoDTO: Codable {
        let id: UUID
        let nome: String
        let tipo: TipoEstabelecimento
        let endereco: String
        let regiaoAdministrativa: String
        let ponto: CoordenadaDTO
        let papel: PapelMembro

        enum CodingKeys: String, CodingKey {
            case id, nome, tipo, endereco, ponto, papel
            case regiaoAdministrativa = "regiao_administrativa"
        }

        func dominio() throws -> Estabelecimento {
            try Estabelecimento(
                id: id, nome: nome, documento: "", tipo: tipo, endereco: endereco,
                regiaoAdministrativa: regiaoAdministrativa, ponto: ponto.dominio(), papel: papel
            )
        }
    }

    /// `NovoEstabelecimento` do contrato: `regiao_administrativa` é obrigatória desde a 0.2.20.
    struct CadastroEstabelecimentoDTO: Encodable {
        let nome: String
        let documento: String
        let tipo: TipoEstabelecimento
        let endereco: String
        let regiaoAdministrativa: String
        let ponto: CoordenadaDTO

        init(_ cadastro: CadastroEstabelecimento) {
            nome = cadastro.nome
            documento = cadastro.documento
            tipo = cadastro.tipo
            endereco = cadastro.endereco
            regiaoAdministrativa = cadastro.regiaoAdministrativa
            ponto = CoordenadaDTO(cadastro.ponto)
        }

        enum CodingKeys: String, CodingKey {
            case nome, documento, tipo, endereco, ponto
            case regiaoAdministrativa = "regiao_administrativa"
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

    /// `Centavos` do contrato tem `minimum: 1`. O `Dinheiro` do domínio para no `precondition`
    /// com valor negativo: vindo do servidor, o valor fora do contrato é resposta inválida, e não
    /// motivo para fechar o app.
    static func dinheiro(_ centavos: Int, campo: String) throws -> Dinheiro {
        guard centavos >= 1 else { throw ErroDeConversao(campo: campo) }
        return Dinheiro(centavos: centavos)
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
        let estabelecimento: PerfilPublicoDTO
        let funcao: FuncaoDTO
        let inicioEm: Date
        let fimEm: Date
        let local: String
        let regiaoAdministrativa: String
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
        let oculta: Bool
        let publicadoEm: Date

        enum CodingKeys: String, CodingKey {
            case id, estabelecimento, funcao, local, ponto, posicoes, inclusos, traje, observacoes, modo, estado, oculta
            case inicioEm = "inicio_em"
            case fimEm = "fim_em"
            case regiaoAdministrativa = "regiao_administrativa"
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
                regiaoAdministrativa: regiaoAdministrativa,
                ponto: ponto.dominio(),
                distanciaKm: distanciaKm,
                valor: ContratoAPI.dinheiro(valorCentavos, campo: "valor_centavos"),
                posicoes: posicoes,
                posicoesAbertas: posicoesAbertas,
                inclusos: inclusos.dominio(),
                responsavelLocal: responsavelLocal,
                traje: traje,
                participaRateio: participaRateio,
                observacoes: observacoes,
                modo: modo,
                estado: estado,
                oculta: oculta,
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
        let regiaoAdministrativa: String
        let distanciaKm: Double
        let valorCentavos: Int
        let posicoesAbertas: Int
        let inclusos: InclusosDTO
        let modo: ModoPreenchimento

        enum CodingKeys: String, CodingKey {
            case id, funcao, estabelecimento, local, inclusos, modo
            case inicioEm = "inicio_em"
            case fimEm = "fim_em"
            case regiaoAdministrativa = "regiao_administrativa"
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
                regiaoAdministrativa: regiaoAdministrativa,
                distanciaKm: distanciaKm,
                valor: ContratoAPI.dinheiro(valorCentavos, campo: "valor_centavos"),
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
        let regiaoAdministrativa: String
        let inicioEm: Date
        let fimEm: Date
        let valorCentavos: Int

        enum CodingKeys: String, CodingKey {
            case id, funcao, local
            case regiaoAdministrativa = "regiao_administrativa"
            case inicioEm = "inicio_em"
            case fimEm = "fim_em"
            case valorCentavos = "valor_centavos"
        }

        func dominio() throws -> VagaResumo {
            try VagaResumo(
                id: id, funcao: funcao, local: local, regiaoAdministrativa: regiaoAdministrativa,
                periodo: Periodo(inicio: inicioEm, fim: fimEm),
                valor: ContratoAPI.dinheiro(valorCentavos, campo: "valor_centavos")
            )
        }
    }

    struct NovaVaga: Encodable {
        let estabelecimentoID: UUID
        let funcaoID: UUID
        let inicioEm: String
        let fimEm: String
        let local: String
        let regiaoAdministrativa: String
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
            regiaoAdministrativa = publicacao.regiaoAdministrativa
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
            case regiaoAdministrativa = "regiao_administrativa"
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
        /// O app abre o `whatsapp_url` como vem; por isso só passa o link do WhatsApp em https
        /// (auditoria de 03/10/2026, A5). Outro esquema ou host é trocado pelo `wa.me` montado do
        /// telefone, sem erro: `candidatar` e `escolher_candidato` já gravaram no servidor quando a
        /// resposta chega, e um erro aqui faria a ação bem-sucedida parecer falha (e a repetição, 409).
        static let hostsDoWhatsApp: Set<String> = ["wa.me", "api.whatsapp.com"]
        private static let log = Logger(subsystem: "com.frila.org.app", category: "contrato")

        func dominio() -> Contato {
            Contato(nome: nome, telefone: telefone, whatsappURL: Self.linkSeguro(whatsappURL, telefone: telefone), visivelAte: visivelAte)
        }

        /// O link como veio, se é do WhatsApp em https; senão, `https://wa.me/` + os dígitos do
        /// telefone E.164 (`+5561999990000` → `https://wa.me/5561999990000`, como no contrato).
        static func linkSeguro(_ url: URL, telefone: String) -> URL {
            if url.scheme?.lowercased() == "https", let host = url.host()?.lowercased(), hostsDoWhatsApp.contains(host) {
                return url
            }
            // Só o fato, nunca o link nem o número.
            log.notice("whatsapp_url_saneado")
            let digitos = telefone.filter(\.isNumber)
            return URL(string: "https://wa.me/\(digitos)") ?? URL(string: "https://wa.me/")!
        }
    }

    // MARK: Modo seleção (0.2.24)

    /// `Candidatura` do contrato: o que `minhas_candidaturas` lista e `retirar_candidatura` devolve.
    /// O `CandidaturaDTO` acima é outro schema, o `ResultadoCandidatura` de `candidatar`.
    struct MinhaCandidaturaDTO: Decodable {
        let id: UUID
        let vaga: VagaResumoDTO
        let estado: EstadoCandidatura
        let criadaEm: Date
        let turnoID: UUID?
        enum CodingKeys: String, CodingKey {
            case id, vaga, estado
            case criadaEm = "criada_em"
            case turnoID = "turno_id"
        }
        func dominio() throws -> Candidatura {
            Candidatura(id: id, vaga: try vaga.dominio(), estado: estado, criadaEm: criadaEm, turnoID: turnoID)
        }
    }

    /// `Candidato` do contrato, de `candidatos_da_vaga`.
    struct CandidatoDTO: Decodable {
        let candidaturaID: UUID
        let profissional: PerfilPublicoDTO
        let criadaEm: Date
        enum CodingKeys: String, CodingKey {
            case profissional
            case candidaturaID = "candidatura_id"
            case criadaEm = "criada_em"
        }
        func dominio() -> Candidato {
            Candidato(candidaturaID: candidaturaID, profissional: profissional.dominio(), criadaEm: criadaEm)
        }
    }

    /// `ResultadoConfirmacao` do contrato, de `escolher_candidato`. O `estado` é a constante
    /// `confirmada`: outro valor não é esta resposta, e a decodificação falha.
    struct ResultadoConfirmacaoDTO: Decodable {
        enum Estado: String, Decodable { case confirmada }
        let estado: Estado
        let posicaoID: UUID
        let turnoID: UUID
        let contato: ContatoDTO
        enum CodingKeys: String, CodingKey {
            case estado, contato
            case posicaoID = "posicao_id"
            case turnoID = "turno_id"
        }
        func dominio() -> ResultadoConfirmacao {
            ResultadoConfirmacao(posicaoID: posicaoID, turnoID: turnoID, contato: contato.dominio())
        }
    }

    /// O filtro de `minhas_candidaturas`. Sem estado, o campo não vai, e a função lista todas.
    struct MinhasCandidaturasParametros: Encodable {
        let estado: EstadoCandidatura?
    }

    struct CancelamentoDoTurnoDTO: Decodable {
        let causa: CausaDoCancelamento
        let falta: Bool
        let canceladaEm: Date

        enum CodingKeys: String, CodingKey {
            case causa, falta
            case canceladaEm = "cancelada_em"
        }

        func dominio() -> CancelamentoDoTurno {
            CancelamentoDoTurno(causa: causa, falta: falta, canceladaEm: canceladaEm)
        }
    }

    struct TurnoDTO: Decodable {
        let id: UUID
        let posicaoID: UUID
        let vaga: VagaResumoDTO
        let contraparte: PerfilPublicoDTO
        let contatoVisivelAte: Date
        let aCaminhoEm: Date?
        let checkinEm: Date?
        let checkinTipo: TipoRegistro?
        let checkinDistanciaM: Int?
        let checkinConfirmadoEm: Date?
        let checkoutEm: Date?
        let checkoutDistanciaM: Int?
        let verificacao: Verificacao
        let valorAcordadoCentavos: Int
        let podeAvaliar: Bool
        let estado: EstadoPosicao?
        let avaliacao: AvaliacaoDTO?
        let avaliacaoInformada: Bool
        let cancelamento: CancelamentoDoTurnoDTO?

        enum CodingKeys: String, CodingKey {
            case id, vaga, contraparte, verificacao, estado, avaliacao, cancelamento
            case posicaoID = "posicao_id"
            case contatoVisivelAte = "contato_visivel_ate"
            case aCaminhoEm = "a_caminho_em"
            case checkinEm = "checkin_em"
            case checkinTipo = "checkin_tipo"
            case checkinDistanciaM = "checkin_distancia_m"
            case checkinConfirmadoEm = "checkin_confirmado_em"
            case checkoutEm = "checkout_em"
            case checkoutDistanciaM = "checkout_distancia_m"
            case valorAcordadoCentavos = "valor_acordado_centavos"
            case podeAvaliar = "pode_avaliar"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            posicaoID = try container.decode(UUID.self, forKey: .posicaoID)
            vaga = try container.decode(VagaResumoDTO.self, forKey: .vaga)
            contraparte = try container.decode(PerfilPublicoDTO.self, forKey: .contraparte)
            contatoVisivelAte = try container.decode(Date.self, forKey: .contatoVisivelAte)
            aCaminhoEm = try container.decodeIfPresent(Date.self, forKey: .aCaminhoEm)
            checkinEm = try container.decodeIfPresent(Date.self, forKey: .checkinEm)
            // Como no painel: um tipo de check-in novo fica sem valor, e o turno segue.
            checkinTipo = try container.decodeIfPresent(String.self, forKey: .checkinTipo).flatMap(TipoRegistro.init(rawValue:))
            checkinDistanciaM = try container.decodeIfPresent(Int.self, forKey: .checkinDistanciaM)
            checkinConfirmadoEm = try container.decodeIfPresent(Date.self, forKey: .checkinConfirmadoEm)
            checkoutEm = try container.decodeIfPresent(Date.self, forKey: .checkoutEm)
            checkoutDistanciaM = try container.decodeIfPresent(Int.self, forKey: .checkoutDistanciaM)
            verificacao = try container.decode(Verificacao.self, forKey: .verificacao)
            valorAcordadoCentavos = try container.decode(Int.self, forKey: .valorAcordadoCentavos)
            podeAvaliar = try container.decode(Bool.self, forKey: .podeAvaliar)
            // Um estado novo não invalida a lista inteira. Ausente ou desconhecido fica sem estado.
            estado = try container.decodeIfPresent(String.self, forKey: .estado).flatMap(EstadoPosicao.init(rawValue:))
            avaliacaoInformada = container.contains(.avaliacao)
            avaliacao = try container.decodeIfPresent(AvaliacaoDTO.self, forKey: .avaliacao)
            cancelamento = try container.decodeIfPresent(CancelamentoDoTurnoDTO.self, forKey: .cancelamento)
        }

        func dominio() throws -> Turno {
            try Turno(
                id: id,
                posicaoID: posicaoID,
                vaga: vaga.dominio(),
                contraparte: contraparte.dominio(),
                contatoVisivelAte: contatoVisivelAte,
                aCaminhoEm: aCaminhoEm,
                checkin: checkinEm.map {
                    Presenca(instante: $0, tipo: checkinTipo, distanciaMetros: checkinDistanciaM, confirmadaEm: checkinConfirmadoEm)
                },
                checkout: checkoutEm.map { Presenca(instante: $0, distanciaMetros: checkoutDistanciaM) },
                verificacao: verificacao,
                valorAcordado: ContratoAPI.dinheiro(valorAcordadoCentavos, campo: "valor_acordado_centavos"),
                podeAvaliar: podeAvaliar,
                estado: estado,
                avaliacao: avaliacao?.dominio(),
                avaliacaoInformada: avaliacaoInformada,
                cancelamento: cancelamento?.dominio(), avaliacaoLidaEm: Date()
            )
        }
    }

    struct ResultadoACaminhoDTO: Decodable {
        let turnoID: UUID
        let aCaminhoEm: Date

        enum CodingKeys: String, CodingKey {
            case turnoID = "turno_id"
            case aCaminhoEm = "a_caminho_em"
        }

        func dominio() -> ResultadoACaminho { ResultadoACaminho(turnoID: turnoID, aCaminhoEm: aCaminhoEm) }
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

    // MARK: Cancelamento e reabertura

    struct CancelarPosicao: Encodable {
        let posicaoID: UUID
        let motivo: String
        enum CodingKeys: String, CodingKey { case posicaoID = "posicao_id"; case motivo }
    }

    struct CancelarVaga: Encodable {
        let vagaID: UUID
        let motivo: String
        enum CodingKeys: String, CodingKey { case vagaID = "vaga_id"; case motivo }
    }

    struct ResultadoCancelamentoDTO: Decodable {
        let posicaoID: UUID
        let falta: Bool
        let reaberta: Bool
        let novaPosicaoID: UUID?

        enum CodingKeys: String, CodingKey {
            case falta, reaberta
            case posicaoID = "posicao_id"
            case novaPosicaoID = "nova_posicao_id"
        }

        func dominio() -> ResultadoCancelamento {
            ResultadoCancelamento(posicaoID: posicaoID, falta: falta, reaberta: reaberta, novaPosicaoID: novaPosicaoID)
        }
    }

    struct VagaCanceladaDTO: Decodable {
        let vagaID: UUID
        let estado: EstadoVaga
        let posicoesCanceladas: Int

        enum CodingKeys: String, CodingKey {
            case estado
            case vagaID = "vaga_id"
            case posicoesCanceladas = "posicoes_canceladas"
        }

        func dominio() -> VagaCancelada {
            VagaCancelada(vagaID: vagaID, estado: estado, posicoesCanceladas: posicoesCanceladas)
        }
    }

    // MARK: Painel do estabelecimento

    struct EstabelecimentoParametros: Encodable {
        let estabelecimentoID: UUID
        enum CodingKeys: String, CodingKey { case estabelecimentoID = "estabelecimento_id" }
    }

    struct PainelParametros: Encodable {
        let estabelecimentoID: UUID
        let de: String
        let ate: String
        enum CodingKeys: String, CodingKey { case estabelecimentoID = "estabelecimento_id"; case de, ate }
    }

    struct CancelamentoDaPosicaoDTO: Decodable {
        let causa: CausaDoCancelamento
        let falta: Bool
        let motivo: String?
        let canceladaEm: Date

        enum CodingKeys: String, CodingKey {
            case causa, falta, motivo
            case canceladaEm = "cancelada_em"
        }

        func dominio() -> CancelamentoDaPosicao {
            CancelamentoDaPosicao(causa: causa, falta: falta, motivo: motivo, canceladaEm: canceladaEm)
        }
    }

    struct PosicaoNoPainelDTO: Decodable {
        let id: UUID
        let estado: EstadoPosicao
        let profissional: PerfilPublicoDTO?
        let turnoID: UUID?
        let verificacao: Verificacao?
        let emAtraso: Bool
        let aCaminhoEm: Date?
        let checkinEm: Date?
        let checkinTipo: TipoRegistro?
        let checkinConfirmadoEm: Date?
        let cancelamento: CancelamentoDaPosicaoDTO?

        enum CodingKeys: String, CodingKey {
            case id, estado, profissional, verificacao, cancelamento
            case turnoID = "turno_id"
            case emAtraso = "em_atraso"
            case aCaminhoEm = "a_caminho_em"
            case checkinEm = "checkin_em"
            case checkinTipo = "checkin_tipo"
            case checkinConfirmadoEm = "checkin_confirmado_em"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            estado = try container.decode(EstadoPosicao.self, forKey: .estado)
            profissional = try container.decodeIfPresent(PerfilPublicoDTO.self, forKey: .profissional)
            turnoID = try container.decodeIfPresent(UUID.self, forKey: .turnoID)
            verificacao = try container.decodeIfPresent(Verificacao.self, forKey: .verificacao)
            emAtraso = try container.decode(Bool.self, forKey: .emAtraso)
            aCaminhoEm = try container.decodeIfPresent(Date.self, forKey: .aCaminhoEm)
            checkinEm = try container.decodeIfPresent(Date.self, forKey: .checkinEm)
            if let tipoRaw = try container.decodeIfPresent(String.self, forKey: .checkinTipo) {
                checkinTipo = TipoRegistro(rawValue: tipoRaw)
            } else {
                checkinTipo = nil
            }
            checkinConfirmadoEm = try container.decodeIfPresent(Date.self, forKey: .checkinConfirmadoEm)
            cancelamento = try container.decodeIfPresent(CancelamentoDaPosicaoDTO.self, forKey: .cancelamento)
        }

        func dominio() -> PosicaoNoPainel {
            PosicaoNoPainel(
                id: id, estado: estado, profissional: profissional?.dominio(), turnoID: turnoID, verificacao: verificacao,
                emAtraso: emAtraso, aCaminhoEm: aCaminhoEm,
                checkinEm: checkinEm, checkinTipo: checkinTipo, checkinConfirmadoEm: checkinConfirmadoEm,
                cancelamento: cancelamento?.dominio()
            )
        }
    }

    struct VagaNoPainelDTO: Decodable {
        let vaga: VagaResumoDTO
        let modo: ModoPreenchimento
        let estado: EstadoVaga
        let oculta: Bool
        let alertaVagaVazia: Bool
        let candidatosPendentes: Int
        let posicoes: [PosicaoNoPainelDTO]
        /// Posições que vieram com valor que este app não conhece (estado novo, por exemplo) e saíram.
        let posicoesDescartadas: Int

        enum CodingKeys: String, CodingKey {
            case vaga, modo, estado, oculta, posicoes
            case alertaVagaVazia = "alerta_vaga_vazia"
            case candidatosPendentes = "candidatos_pendentes"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            vaga = try container.decode(VagaResumoDTO.self, forKey: .vaga)
            modo = try container.decode(ModoPreenchimento.self, forKey: .modo)
            estado = try container.decode(EstadoVaga.self, forKey: .estado)
            oculta = try container.decode(Bool.self, forKey: .oculta)
            alertaVagaVazia = try container.decode(Bool.self, forKey: .alertaVagaVazia)
            candidatosPendentes = try container.decode(Int.self, forKey: .candidatosPendentes)
            let lidas = try container.decode([ItemTolerante<PosicaoNoPainelDTO>].self, forKey: .posicoes)
            posicoes = lidas.compactMap(\.valor)
            posicoesDescartadas = lidas.count - posicoes.count
        }

        func dominio() throws -> VagaNoPainel {
            try VagaNoPainel(
                vaga: vaga.dominio(),
                modo: modo,
                estado: estado,
                oculta: oculta,
                alertaVagaVazia: alertaVagaVazia,
                candidatosPendentes: candidatosPendentes,
                posicoes: posicoes.map { $0.dominio() }
            )
        }
    }

    /// O painel é uma resposta só com duas listas dentro: uma vaga ou posição com valor novo do
    /// contrato sai da lista, e o resto do painel segue. `descartados` soma vagas e posições que
    /// saíram, para o cliente registrar a quantidade.
    struct PainelDTO: Decodable {
        let estabelecimentoID: UUID
        let vagas: [VagaNoPainelDTO]
        let checkinsPendentes: [UUID]
        let descartados: Int

        enum CodingKeys: String, CodingKey {
            case vagas
            case estabelecimentoID = "estabelecimento_id"
            case checkinsPendentes = "checkins_pendentes"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            estabelecimentoID = try container.decode(UUID.self, forKey: .estabelecimentoID)
            checkinsPendentes = try container.decode([UUID].self, forKey: .checkinsPendentes)
            let lidas = try container.decode([ItemTolerante<VagaNoPainelDTO>].self, forKey: .vagas)
            vagas = lidas.compactMap(\.valor)
            descartados = (lidas.count - vagas.count) + vagas.reduce(0) { $0 + $1.posicoesDescartadas }
        }

        /// A vaga cujo conteúdo não cabe no domínio (valor fora do contrato) também sai, em vez de
        /// derrubar o painel.
        func dominio() throws -> Painel {
            Painel(estabelecimentoID: estabelecimentoID, vagas: vagas.compactMap { try? $0.dominio() }, checkinsPendentes: checkinsPendentes)
        }
    }

    // MARK: Confiança e direitos

    struct Denunciar: Encodable {
        let alvoTipo: TipoPerfilPublico
        let alvoID: UUID
        let turnoID: UUID?
        let motivo: MotivoDenuncia
        let relato: String
        let chave: UUID

        init(_ denuncia: Denuncia) {
            alvoTipo = denuncia.alvo.tipo
            alvoID = denuncia.alvo.id
            turnoID = denuncia.turnoID
            motivo = denuncia.motivo
            relato = denuncia.relato
            chave = denuncia.chave
        }

        // `turno_id` é opcional no contrato: sem turno, o campo não vai.
        enum CodingKeys: String, CodingKey {
            case motivo, relato, chave
            case alvoTipo = "alvo_tipo"
            case alvoID = "alvo_id"
            case turnoID = "turno_id"
        }
    }

    struct Bloquear: Encodable {
        let alvoTipo: TipoPerfilPublico
        let alvoID: UUID

        init(_ alvo: Alvo) {
            alvoTipo = alvo.tipo
            alvoID = alvo.id
        }

        enum CodingKeys: String, CodingKey {
            case alvoTipo = "alvo_tipo"
            case alvoID = "alvo_id"
        }
    }

    struct ContestarSuspensao: Encodable {
        let relato: String
    }

    // MARK: Por que recebo vagas (RF27)

    struct PedirRevisaoDespacho: Encodable {
        let relato: String
    }

    struct CriteriosDeNotificacaoDTO: Decodable {
        struct EquipeDTO: Decodable {
            let estabelecimentoID: UUID
            let nome: String

            enum CodingKeys: String, CodingKey {
                case nome
                case estabelecimentoID = "estabelecimento_id"
            }
        }

        let funcoes: [FuncaoDTO]
        let disponibilidades: [JanelaDTO]
        let distanciaMaximaKm: Double
        let equipesDeConfianca: [EquipeDTO]
        let notificacoesNoMaximoACadaMin: Int

        enum CodingKeys: String, CodingKey {
            case funcoes, disponibilidades
            case distanciaMaximaKm = "distancia_maxima_km"
            case equipesDeConfianca = "equipes_de_confianca"
            case notificacoesNoMaximoACadaMin = "notificacoes_no_maximo_a_cada_min"
        }

        func dominio() throws -> CriteriosDeNotificacao {
            try CriteriosDeNotificacao(
                funcoes: funcoes.map { $0.dominio() },
                disponibilidades: disponibilidades.map { try $0.dominio() },
                distanciaMaximaKm: distanciaMaximaKm,
                equipesDeConfianca: equipesDeConfianca.map { EquipeDeConfiancaDoProfissional(estabelecimentoID: $0.estabelecimentoID, nome: $0.nome) },
                notificacoesNoMaximoACadaMin: notificacoesNoMaximoACadaMin
            )
        }
    }

    struct ProtocoloDTO: Decodable {
        let ocorrenciaID: UUID
        let tipo: TipoDeProtocolo
        let criadaEm: Date
        let prazoRespostaAte: String

        enum CodingKeys: String, CodingKey {
            case tipo
            case ocorrenciaID = "ocorrencia_id"
            case criadaEm = "criada_em"
            case prazoRespostaAte = "prazo_resposta_ate"
        }

        func dominio() throws -> Protocolo {
            guard let prazo = try? DataCivil(prazoRespostaAte) else { throw ErroDeConversao(campo: "prazo_resposta_ate") }
            return Protocolo(ocorrenciaID: ocorrenciaID, tipo: tipo, criadaEm: criadaEm, prazoRespostaAte: prazo)
        }
    }

    struct BloqueioDTO: Decodable {
        let alvoTipo: TipoPerfilPublico
        let alvoID: UUID
        let criadoEm: Date

        enum CodingKeys: String, CodingKey {
            case alvoTipo = "alvo_tipo"
            case alvoID = "alvo_id"
            case criadoEm = "criado_em"
        }

        func dominio() -> Bloqueio {
            Bloqueio(alvo: Alvo(tipo: alvoTipo, id: alvoID), criadoEm: criadoEm)
        }
    }

    struct SituacaoDaContaDTO: Decodable {
        struct SuspensaoDTO: Decodable {
            let motivo: String
            let desde: Date
            let contestacao: ProtocoloDTO?
        }

        let estado: EstadoConta
        let suspensao: SuspensaoDTO?

        func dominio() throws -> SituacaoDaConta {
            try SituacaoDaConta(
                estado: estado,
                suspensao: suspensao.map { Suspensao(motivo: $0.motivo, desde: $0.desde, contestacao: try $0.contestacao?.dominio()) }
            )
        }
    }

    // MARK: Exportação de turnos (contrato 0.2.32; a 0.2.33 não muda o endpoint)

    /// Corpo de `POST /exportar-turnos`. Os instantes levam milissegundos: o último é 23:59:59.999
    /// de São Paulo, e sem a fração o último segundo do período ficaria de fora. Sem estabelecimento,
    /// a chave não vai, e o servidor usa os turnos de quem chama como profissional.
    struct ExportarTurnos: Encodable {
        let de: String
        let ate: String
        let formato: FormatoExportacao
        let estabelecimentoID: UUID?

        enum CodingKeys: String, CodingKey {
            case de, ate, formato
            case estabelecimentoID = "estabelecimento_id"
        }

        init(_ pedido: PedidoExportacaoTurnos) {
            de = ContratoAPI.textoComMilissegundos(pedido.periodo.inicio)
            ate = ContratoAPI.textoComMilissegundos(pedido.periodo.fim)
            formato = pedido.formato
            estabelecimentoID = pedido.estabelecimentoID
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

    struct RegistrarDispositivo: Encodable {
        let tokenFCM: String
        let plataforma = Plataforma.ios

        enum CodingKeys: String, CodingKey {
            case plataforma
            case tokenFCM = "token_fcm"
        }
    }

    struct RemoverDispositivo: Encodable {
        let tokenFCM: String

        enum CodingKeys: String, CodingKey {
            case tokenFCM = "token_fcm"
        }
    }

    struct DispositivoDTO: Decodable {
        let plataforma: Plataforma
        let atualizadoEm: Date
        let vinculoID: UUID?

        enum CodingKeys: String, CodingKey {
            case plataforma
            case atualizadoEm = "atualizado_em"
            case vinculoID = "vinculo_id"
        }

        func dominio() -> Dispositivo {
            Dispositivo(plataforma: plataforma, atualizadoEm: atualizadoEm, vinculoID: vinculoID)
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
