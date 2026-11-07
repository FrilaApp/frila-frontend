import Foundation

public enum PerfilConta: String, Codable, CaseIterable, Sendable {
    case profissional
    case contratante
}

public enum EstadoConta: String, Codable, Sendable {
    case ativa
    case suspensa
}

public struct SessaoUsuario: Codable, Equatable, Sendable {
    public let usuarioID: UUID
    public let perfil: PerfilConta

    public init(usuarioID: UUID, perfil: PerfilConta) {
        self.usuarioID = usuarioID
        self.perfil = perfil
    }
}

/// Troca de contato da conta. O que vem nulo não muda.
public struct AlteracaoDeContato: Equatable, Sendable {
    public let telefone: String?
    public let email: String?

    public init(telefone: String? = nil, email: String? = nil) {
        self.telefone = telefone
        self.email = email
    }
}

/// A conta no produto (`Usuario` do contrato). Existe sessão sem conta: é o primeiro acesso.
public struct Conta: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let perfil: PerfilConta
    public let nome: String
    public let telefone: String
    public let email: String
    public let nascimento: DataCivil
    public let estado: EstadoConta

    public init(id: UUID, perfil: PerfilConta, nome: String, telefone: String, email: String, nascimento: DataCivil, estado: EstadoConta) {
        self.id = id
        self.perfil = perfil
        self.nome = nome
        self.telefone = telefone
        self.email = email
        self.nascimento = nascimento
        self.estado = estado
    }

    public var sessao: SessaoUsuario { SessaoUsuario(usuarioID: id, perfil: perfil) }
}

public enum FormatoDeTrabalho: String, Codable, Sendable {
    case turno
    case servico
}

public struct Funcao: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let nome: String
    public let categoria: String
    public let formatoPadrao: FormatoDeTrabalho?
    public let grupoBusca: String?
    public let dicaPerfil: String?
    public let exemploPerfil: String?

    public init(
        id: UUID,
        nome: String,
        categoria: String,
        formatoPadrao: FormatoDeTrabalho? = nil,
        grupoBusca: String? = nil,
        dicaPerfil: String? = nil,
        exemploPerfil: String? = nil
    ) {
        self.id = id
        self.nome = nome
        self.categoria = categoria
        self.formatoPadrao = formatoPadrao
        self.grupoBusca = grupoBusca
        self.dicaPerfil = dicaPerfil
        self.exemploPerfil = exemploPerfil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case nome
        case categoria
        case formatoPadrao = "formato_padrao"
        case grupoBusca = "grupo_busca"
        case dicaPerfil = "dica_perfil"
        case exemploPerfil = "exemplo_perfil"
    }
}

public struct RegiaoAdministrativa: Codable, Hashable, Identifiable, Sendable {
    public let id: Int
    public let numero: String
    public let nome: String
    public let ativo: Bool?

    public init(id: Int, numero: String, nome: String, ativo: Bool? = true) {
        self.id = id
        self.numero = numero
        self.nome = nome
        self.ativo = ativo
    }
}

public struct Especialidade: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let funcaoID: UUID
    public let nome: String
    public let ativo: Bool?

    public init(id: UUID, funcaoID: UUID, nome: String, ativo: Bool? = true) {
        self.id = id
        self.funcaoID = funcaoID
        self.nome = nome
        self.ativo = ativo
    }

    enum CodingKeys: String, CodingKey {
        case id
        case funcaoID = "funcao_id"
        case nome
        case ativo
    }
}

public enum UnidadePreco: String, Codable, CaseIterable, Sendable {
    case hora, diaria, evento, pacote
    case porPessoa = "por_pessoa"
    case aCombinar = "a_combinar"
}

public enum LevaMaterial: String, Codable, CaseIterable, Sendable {
    case sim, nao, depende
}

public enum ExperienciaFaixa: String, Codable, Sendable {
    case menosDe1Ano = "menos_de_1_ano"
    case de1A3Anos = "de_1_a_3_anos"
    case de3A5Anos = "de_3_a_5_anos"
    case de5A10Anos = "de_5_a_10_anos"
    case maisDe10Anos = "mais_de_10_anos"
}

public enum Idioma: String, Codable, Sendable {
    case portugues, ingles, espanhol, libras, outro
}

public struct ServicoOferecido: Codable, Hashable, Sendable {
    public var funcaoID: UUID
    public var unidade: UnidadePreco
    public var valorCentavos: Int?
    public var valorMaxCentavos: Int?
    public var horasIncluidas: Int?
    public var minimoHoras: Int?
    public var duracaoTipicaH: Int?
    public var atePessoas: Int?
    public var minimoPessoas: Int?
    public var descricaoPacote: String?
    public var levaMaterial: LevaMaterial?
    public var itensInclusos: String?
    public var especialidadeIDs: [UUID]?

    public init(funcaoID: UUID, unidade: UnidadePreco, valorCentavos: Int? = nil,
                valorMaxCentavos: Int? = nil, horasIncluidas: Int? = nil, minimoHoras: Int? = nil,
                duracaoTipicaH: Int? = nil, atePessoas: Int? = nil, minimoPessoas: Int? = nil,
                descricaoPacote: String? = nil, levaMaterial: LevaMaterial? = nil,
                itensInclusos: String? = nil, especialidadeIDs: [UUID]? = nil) {
        self.funcaoID = funcaoID; self.unidade = unidade; self.valorCentavos = valorCentavos
        self.valorMaxCentavos = valorMaxCentavos; self.horasIncluidas = horasIncluidas
        self.minimoHoras = minimoHoras; self.duracaoTipicaH = duracaoTipicaH; self.atePessoas = atePessoas
        self.minimoPessoas = minimoPessoas; self.descricaoPacote = descricaoPacote
        self.levaMaterial = levaMaterial; self.itensInclusos = itensInclusos; self.especialidadeIDs = especialidadeIDs
    }

    public func validar() throws {
        func exigir(_ condicao: Bool, _ campo: String) throws {
            if !condicao { throw ErroDaApi(codigo: .campoInvalido, detalhes: campo) }
        }
        try exigir(unidade == .aCombinar ? valorCentavos == nil : valorCentavos.map { (1000...1000000).contains($0) } == true, "valor_centavos")
        try exigir(valorMaxCentavos == nil || ([.hora, .diaria, .pacote].contains(unidade) && valorMaxCentavos.map { ((valorCentavos ?? 1000)...1000000).contains($0) } == true), "valor_max_centavos")
        try exigir(unidade == .diaria ? horasIncluidas.map { (4...12).contains($0) } == true : horasIncluidas == nil, "horas_incluidas")
        try exigir(minimoHoras == nil || (unidade == .hora && minimoHoras.map { (1...12).contains($0) } == true), "minimo_horas")
        try exigir(duracaoTipicaH == nil || (unidade == .evento && duracaoTipicaH.map { (1...24).contains($0) } == true), "duracao_tipica_h")
        try exigir(atePessoas == nil || (unidade == .evento && atePessoas.map { (1...2000).contains($0) } == true), "ate_pessoas")
        try exigir(unidade == .porPessoa ? minimoPessoas.map { (1...2000).contains($0) } == true : minimoPessoas == nil, "minimo_pessoas")
        try exigir(unidade == .pacote ? descricaoPacote.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 120 } == true : descricaoPacote == nil, "descricao_pacote")
        try exigir((itensInclusos?.count ?? 0) <= 300, "inclui")
        let ids = especialidadeIDs ?? []
        try exigir(ids.count <= 8 && Set(ids).count == ids.count, "especialidade_ids")
    }

    enum CodingKeys: String, CodingKey {
        case funcaoID = "funcao_id"
        case unidade
        case valorCentavos = "valor_centavos"
        case valorMaxCentavos = "valor_max_centavos"
        case horasIncluidas = "horas_incluidas"
        case minimoHoras = "minimo_horas"
        case duracaoTipicaH = "duracao_tipica_h"
        case atePessoas = "ate_pessoas"
        case minimoPessoas = "minimo_pessoas"
        case descricaoPacote = "descricao_pacote"
        case levaMaterial = "leva_material"
        case itensInclusos = "inclui"
        case especialidadeIDs = "especialidade_ids"
    }
}

public struct ServicoNoPerfil: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID { funcao.id }
    public let funcao: Funcao
    public let servico: ServicoOferecido
    public let especialidades: [Especialidade]

    public init(funcao: Funcao, servico: ServicoOferecido, especialidades: [Especialidade] = []) {
        self.funcao = funcao; self.servico = servico; self.especialidades = especialidades
    }
}

public struct Reputacao: Codable, Hashable, Sendable {
    public let positivas: Int
    public let total: Int
    public let taxaComparecimento: Double?
    public let turnosConsiderados: Int
    public let turnosRealizados: Int

    public init(
        positivas: Int,
        total: Int,
        taxaComparecimento: Double?,
        turnosConsiderados: Int,
        turnosRealizados: Int
    ) {
        self.positivas = positivas
        self.total = total
        self.taxaComparecimento = taxaComparecimento
        self.turnosConsiderados = turnosConsiderados
        self.turnosRealizados = turnosRealizados
    }

    public var semHistorico: Bool { total == 0 }

    public func descricao() -> String {
        guard !semHistorico else { return "Sem histórico" }
        return "\(positivas) de \(total) chamariam de novo"
    }
}

public enum TipoPerfilPublico: String, Codable, Sendable {
    case profissional
    case estabelecimento
}

/// Paridade com o schema TipoDeAlvo do contrato OpenAPI.
public typealias TipoDeAlvo = TipoPerfilPublico

/// O que uma parte vê da outra: nome e reputação, nunca contato (RN10).
public struct PerfilPublico: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let tipo: TipoPerfilPublico
    public let nome: String
    public let funcoes: [String]
    public let reputacao: Reputacao
    /// Foto `aprovada` (miniatura de 320 px, URL assinada por 1 h). Só vem para quem tem vínculo de
    /// leitura e com o recurso ligado (contrato 0.2.54); ausente nos demais casos.
    public let fotoURL: URL?
    /// Identificador opaco da foto exibida: é o que `denunciar.midia_id` recebe.
    public let fotoID: UUID?

    public init(
        id: UUID, tipo: TipoPerfilPublico, nome: String, funcoes: [String] = [], reputacao: Reputacao,
        fotoURL: URL? = nil, fotoID: UUID? = nil
    ) {
        self.id = id
        self.tipo = tipo
        self.nome = nome
        self.funcoes = funcoes
        self.reputacao = reputacao
        self.fotoURL = fotoURL
        self.fotoID = fotoID
    }
}

public struct PerfilProfissional: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let usuarioID: UUID
    public let funcoes: [Funcao]
    public let pontoBase: Coordenada
    public let disponibilidades: [JanelaDeDisponibilidade]
    public let reputacao: Reputacao

    public init(
        id: UUID,
        usuarioID: UUID,
        funcoes: [Funcao],
        pontoBase: Coordenada,
        disponibilidades: [JanelaDeDisponibilidade],
        reputacao: Reputacao
    ) {
        self.id = id
        self.usuarioID = usuarioID
        self.funcoes = funcoes
        self.pontoBase = pontoBase
        self.disponibilidades = disponibilidades
        self.reputacao = reputacao
    }
}

public enum ExperienciaFaixa: String, Codable, CaseIterable, Sendable {
    case menosDe1Ano = "menos_de_1_ano"
    case de1A3Anos = "de_1_a_3_anos"
    case de3A5Anos = "de_3_a_5_anos"
    case de5A10Anos = "de_5_a_10_anos"
    case maisDe10Anos = "mais_de_10_anos"
}

public enum Idioma: String, Codable, CaseIterable, Sendable {
    case portugues
    case ingles
    case espanhol
    case libras
    case outro
}

public enum UnidadePreco: String, Codable, CaseIterable, Sendable {
    case hora, diaria, evento, pacote
    case porPessoa = "por_pessoa"
    case aCombinar = "a_combinar"
}

public enum LevaMaterial: String, Codable, CaseIterable, Sendable {
    case sim, nao, depende
}

public struct ApresentacaoDoProfissional: Codable, Hashable, Sendable {
    public var apresentacao: String?
    public var ondeTrabalhei: String?
    public var experienciaFaixa: ExperienciaFaixa?
    public var cursos: [String]?
    public var idiomas: [Idioma]?

    public init(
        apresentacao: String? = nil,
        ondeTrabalhei: String? = nil,
        experienciaFaixa: ExperienciaFaixa? = nil,
        cursos: [String]? = nil,
        idiomas: [Idioma]? = nil
    ) {
        self.apresentacao = apresentacao
        self.ondeTrabalhei = ondeTrabalhei
        self.experienciaFaixa = experienciaFaixa
        self.cursos = cursos
        self.idiomas = idiomas
    }
}

public struct RegioesAtendidas: Codable, Hashable, Sendable {
    public var regioes: [Int]
    public var atendeTodoDF: Bool

    public init(regioes: [Int] = [], atendeTodoDF: Bool = false) {
        self.regioes = regioes
        self.atendeTodoDF = atendeTodoDF
    }
}

public struct PerfilProfissionalDetalhado: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID { perfil.id }
    public let perfil: PerfilProfissional
    public let apresentacao: String?
    public let ondeTrabalhei: String?
    public let experienciaFaixa: ExperienciaFaixa?
    public let cursos: [String]
    public let idiomas: [Idioma]
    public let regioes: [RegiaoAdministrativa]
    public let atendeTodoDF: Bool

    public init(
        perfil: PerfilProfissional,
        apresentacao: String? = nil,
        ondeTrabalhei: String? = nil,
        experienciaFaixa: ExperienciaFaixa? = nil,
        cursos: [String] = [],
        idiomas: [Idioma] = [],
        regioes: [RegiaoAdministrativa] = [],
        atendeTodoDF: Bool = false
    ) {
        self.perfil = perfil
        self.apresentacao = apresentacao
        self.ondeTrabalhei = ondeTrabalhei
        self.experienciaFaixa = experienciaFaixa
        self.cursos = cursos
        self.idiomas = idiomas
        self.regioes = regioes
        self.atendeTodoDF = atendeTodoDF
    }
}

public enum TipoEstabelecimento: String, Codable, CaseIterable, Sendable {
    case foodService = "food_service"
    case evento
    case varejo
    case logistica
    case servicoDomestico = "servico_domestico"
    case outro

    /// Tipo novo do contrato cai em `outro`, que é o que ele significa para este app.
    public init(from decoder: Decoder) throws {
        let valor = try decoder.singleValueContainer().decode(String.self)
        self = TipoEstabelecimento(rawValue: valor) ?? .outro
    }
}

public enum PapelMembro: String, Codable, CaseIterable, Sendable {
    case administrador
    case operador

    /// Papel novo do contrato cai em `operador`, o de menos permissão: a tela nunca libera mais do que o servidor liberaria.
    public init(from decoder: Decoder) throws {
        let valor = try decoder.singleValueContainer().decode(String.self)
        self = PapelMembro(rawValue: valor) ?? .operador
    }
}

public struct Estabelecimento: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let nome: String
    public let documento: String
    public let tipo: TipoEstabelecimento
    public let endereco: String
    /// Região Administrativa do DF (contrato 0.2.20): vai para os pushes no lugar do endereço com número.
    public let regiaoAdministrativa: String
    public let ponto: Coordenada
    public let papel: PapelMembro

    public init(
        id: UUID,
        nome: String,
        documento: String = "",
        tipo: TipoEstabelecimento,
        endereco: String,
        regiaoAdministrativa: String,
        ponto: Coordenada,
        papel: PapelMembro = .administrador
    ) {
        self.id = id
        self.nome = nome
        self.documento = documento
        self.tipo = tipo
        self.endereco = endereco
        self.regiaoAdministrativa = regiaoAdministrativa
        self.ponto = ponto
        self.papel = papel
    }
}

/// Estabelecimento que a conta opera, com o papel dela (RF21).
public struct EstabelecimentoDaConta: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let nome: String
    public let papel: PapelMembro
    public let tipo: TipoEstabelecimento?
    public let reputacao: Reputacao?

    public init(id: UUID, nome: String, papel: PapelMembro, tipo: TipoEstabelecimento? = nil, reputacao: Reputacao? = nil) {
        self.id = id
        self.nome = nome
        self.papel = papel
        self.tipo = tipo
        self.reputacao = reputacao
    }
}

public struct Inclusos: Codable, Hashable, Sendable {
    public let refeicao: Bool
    public let transporte: Bool
    public let exigeMaterialProprio: Bool

    public init(refeicao: Bool, transporte: Bool, exigeMaterialProprio: Bool) {
        self.refeicao = refeicao
        self.transporte = transporte
        self.exigeMaterialProprio = exigeMaterialProprio
    }
}

public enum ModoPreenchimento: String, Codable, Sendable {
    case urgencia
    case selecao
}

/// A regra das 24 horas do modo seleção (RN24, contrato 0.2.38). O prazo de escolha é 24 h antes
/// do início; a partir dele a vaga fecha sozinha. Uma posição que volta a ficar aberta a 24 h ou
/// menos do início (cancelamento do escolhido, reabertura por atraso) é reposta em **urgência**:
/// o primeiro elegível que se candidata é confirmado na hora (decisões D4 e D5, 07/10/2026).
///
/// O contrato não manda um campo que diga "esta posição é de urgência": a vaga de seleção ainda
/// `publicada` com posição aberta dentro das 24 h só pode ser uma reposição, porque o agendador a
/// teria fechado. É a única leitura do app que depende do relógio do aparelho, e só muda o que a
/// tela explica; quem decide a candidatura continua sendo o servidor.
public enum RegraDaSelecao {
    public static let antecedencia: TimeInterval = 24 * 60 * 60

    /// O instante em que a seleção fecha (RN24).
    public static func prazoDeEscolha(inicio: Date) -> Date {
        inicio.addingTimeInterval(-antecedencia)
    }

    /// Com 24 h ou menos para o início a posição aberta de uma vaga em seleção é reposta em urgência.
    public static func reposicaoEmUrgencia(
        modo: ModoPreenchimento, estado: EstadoVaga, posicoesAbertas: Int, inicio: Date, agora: Date
    ) -> Bool {
        modo == .selecao && estado == .publicada && posicoesAbertas > 0 && inicio.timeIntervalSince(agora) <= antecedencia
    }
}

public enum EstadoVaga: String, Codable, Sendable {
    case publicada
    case preenchida
    case encerrada
    case cancelada
}

public enum ErroValidacaoVaga: String, Error, CaseIterable, Sendable {
    case funcaoObrigatoria
    case estabelecimentoObrigatorio
    case localObrigatorio
    case responsavelObrigatorio
    case valorInvalido
    case quantidadeDePosicoesInvalida
    case horarioNoPassado
    case selecaoSemAntecedencia
}

public enum OrigemVaga: String, Codable, CaseIterable, Sendable {
    case publicacao
    case chamadaDireta = "chamada_direta"
}

public struct Vaga: Codable, Hashable, Identifiable, Sendable {
    public let origem: OrigemVaga?
    public let vagaOrigemId: UUID?
    public let id: UUID
    public let estabelecimento: PerfilPublico
    public let funcao: Funcao
    public let periodo: Periodo
    public let local: String
    public let regiaoAdministrativa: String
    public let ponto: Coordenada
    public let distanciaKm: Double?
    public let valor: Dinheiro
    public let posicoes: Int
    public let posicoesAbertas: Int
    public let inclusos: Inclusos
    public let responsavelLocal: String
    public let traje: String?
    public let participaRateio: Bool?
    public let observacoes: String?
    public let modo: ModoPreenchimento
    public let estado: EstadoVaga
    /// A moderação da Equipe Frila ocultou a vaga (contrato 0.2.23). Só chega verdadeiro a quem ocupa
    /// posição ou tem candidatura nela; o `estado` continua o do ciclo de vida.
    public let oculta: Bool
    public let publicadoEm: Date

    public init(
        id: UUID,
        estabelecimento: PerfilPublico,
        funcao: Funcao,
        periodo: Periodo,
        local: String,
        regiaoAdministrativa: String,
        ponto: Coordenada,
        distanciaKm: Double? = nil,
        valor: Dinheiro,
        posicoes: Int,
        posicoesAbertas: Int,
        inclusos: Inclusos,
        responsavelLocal: String,
        traje: String? = nil,
        participaRateio: Bool? = nil,
        observacoes: String? = nil,
        modo: ModoPreenchimento,
        estado: EstadoVaga,
        oculta: Bool = false,
        publicadoEm: Date,
        origem: OrigemVaga? = nil, vagaOrigemId: UUID? = nil
    ) {
        self.origem = origem
        self.vagaOrigemId = vagaOrigemId
        self.id = id
        self.estabelecimento = estabelecimento
        self.funcao = funcao
        self.periodo = periodo
        self.local = local
        self.regiaoAdministrativa = regiaoAdministrativa
        self.ponto = ponto
        self.distanciaKm = distanciaKm
        self.valor = valor
        self.posicoes = posicoes
        self.posicoesAbertas = posicoesAbertas
        self.inclusos = inclusos
        self.responsavelLocal = responsavelLocal
        self.traje = traje
        self.participaRateio = participaRateio
        self.observacoes = observacoes
        self.modo = modo
        self.estado = estado
        self.oculta = oculta
        self.publicadoEm = publicadoEm
    }

    public var resumo: VagaResumo {
        VagaResumo(id: id, funcao: funcao.nome, local: local, regiaoAdministrativa: regiaoAdministrativa, periodo: periodo, valor: valor, origem: origem, vagaOrigemId: vagaOrigemId)
    }

    public func validar(agora: Date) -> [ErroValidacaoVaga] {
        var erros: [ErroValidacaoVaga] = []
        if funcao.nome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { erros.append(.funcaoObrigatoria) }
        if estabelecimento.nome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { erros.append(.estabelecimentoObrigatorio) }
        if local.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { erros.append(.localObrigatorio) }
        if responsavelLocal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { erros.append(.responsavelObrigatorio) }
        if valor.centavos < 1 { erros.append(.valorInvalido) }
        if !(1...200).contains(posicoes) { erros.append(.quantidadeDePosicoesInvalida) }
        if periodo.inicio <= agora { erros.append(.horarioNoPassado) }
        // Como o servidor: o início tem de estar a mais de 24 h; com 24 h exatas é recusa (RN24).
        if modo == .selecao, periodo.inicio.timeIntervalSince(agora) <= 24 * 60 * 60 {
            erros.append(.selecaoSemAntecedencia)
        }
        return erros
    }
}

extension Vaga {
    /// Como esta vaga é preenchida **agora**: a de seleção com posição aberta a 24 h ou menos do
    /// início está em reposição por urgência (`RegraDaSelecao`), e é isso que a tela de quem
    /// trabalha explica, em vez de "o estabelecimento escolhe entre os candidatos".
    public func modoEfetivo(em agora: Date) -> ModoPreenchimento {
        RegraDaSelecao.reposicaoEmUrgencia(modo: modo, estado: estado, posicoesAbertas: posicoesAbertas, inicio: periodo.inicio, agora: agora)
            ? .urgencia : modo
    }
}

/// Item da lista de vagas abertas: sem endereço exato nem responsável, que só o detalhe traz.
public struct VagaNaLista: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let funcao: Funcao
    public let estabelecimento: PerfilPublico
    public let periodo: Periodo
    public let local: String
    public let regiaoAdministrativa: String
    public let distanciaKm: Double
    public let valor: Dinheiro
    public let posicoesAbertas: Int
    public let inclusos: Inclusos
    public let modo: ModoPreenchimento

    public init(
        id: UUID,
        funcao: Funcao,
        estabelecimento: PerfilPublico,
        periodo: Periodo,
        local: String,
        regiaoAdministrativa: String,
        distanciaKm: Double,
        valor: Dinheiro,
        posicoesAbertas: Int,
        inclusos: Inclusos,
        modo: ModoPreenchimento
    ) {
        self.id = id
        self.funcao = funcao
        self.estabelecimento = estabelecimento
        self.periodo = periodo
        self.local = local
        self.regiaoAdministrativa = regiaoAdministrativa
        self.distanciaKm = distanciaKm
        self.valor = valor
        self.posicoesAbertas = posicoesAbertas
        self.inclusos = inclusos
        self.modo = modo
    }
}

public struct VagaResumo: Codable, Hashable, Identifiable, Sendable {
    public let origem: OrigemVaga?
    public let vagaOrigemId: UUID?
    public let id: UUID
    public let funcao: String
    public let local: String
    public let regiaoAdministrativa: String
    public let periodo: Periodo
    public let valor: Dinheiro

    public init(id: UUID, funcao: String, local: String, regiaoAdministrativa: String, periodo: Periodo, valor: Dinheiro, origem: OrigemVaga? = nil, vagaOrigemId: UUID? = nil) {
        self.origem = origem
        self.vagaOrigemId = vagaOrigemId
        self.id = id
        self.funcao = funcao
        self.local = local
        self.regiaoAdministrativa = regiaoAdministrativa
        self.periodo = periodo
        self.valor = valor
    }

    /// O `Codable` do domínio é o formato do cache do aparelho (`TurnoPersistido`), não o da API.
    /// Turno guardado por um build anterior ao contrato 0.2.20 não tem a região: continua legível,
    /// com a região vazia, até a próxima leitura com rede regravar o cache. Sem isto, Meus turnos
    /// deixaria de abrir em modo avião logo depois da atualização do app.
    public init(from decoder: any Decoder) throws {
        let campos = try decoder.container(keyedBy: CodingKeys.self)
        origem = try campos.decodeIfPresent(OrigemVaga.self, forKey: .origem)
        vagaOrigemId = try campos.decodeIfPresent(UUID.self, forKey: .vagaOrigemId)
        id = try campos.decode(UUID.self, forKey: .id)
        funcao = try campos.decode(String.self, forKey: .funcao)
        local = try campos.decode(String.self, forKey: .local)
        regiaoAdministrativa = try campos.decodeIfPresent(String.self, forKey: .regiaoAdministrativa) ?? ""
        periodo = try campos.decode(Periodo.self, forKey: .periodo)
        valor = try campos.decode(Dinheiro.self, forKey: .valor)
    }
}

public enum EstadoPosicao: String, Codable, Sendable {
    case aberta
    case confirmada
    case cumprida
    case cancelada
}

public struct Posicao: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let vagaID: UUID
    public let estado: EstadoPosicao
    public let profissionalID: UUID?

    public init(id: UUID, vagaID: UUID, estado: EstadoPosicao, profissionalID: UUID?) {
        self.id = id
        self.vagaID = vagaID
        self.estado = estado
        self.profissionalID = profissionalID
    }
}

public enum Verificacao: String, Codable, Sendable {
    case pendente
    case verificado
    case naoVerificado = "nao_verificado"

    /// Verificação nova do contrato cai em `pendente`: a tela não afirma nem nega a presença.
    public init(from decoder: Decoder) throws {
        let valor = try decoder.singleValueContainer().decode(String.self)
        self = Verificacao(rawValue: valor) ?? .pendente
    }
}

public enum TipoRegistro: String, Codable, Sendable {
    case geolocalizado
    case manual

    /// Tipo novo de registro cai em `manual`, o que menos afirma: a tela o trata como registro que ainda espera confirmação.
    public init(from decoder: Decoder) throws {
        let valor = try decoder.singleValueContainer().decode(String.self)
        self = TipoRegistro(rawValue: valor) ?? .manual
    }
}

public struct Contato: Codable, Hashable, Sendable {
    public let nome: String
    public let telefone: String
    public let whatsappURL: URL
    public let visivelAte: Date

    public init(nome: String, telefone: String, whatsappURL: URL, visivelAte: Date) {
        self.nome = nome
        self.telefone = telefone
        self.whatsappURL = whatsappURL
        self.visivelAte = visivelAte
    }

    public func estaVisivel(em instante: Date) -> Bool { instante <= visivelAte }
}

/// O ciclo da candidatura (`EstadoCandidatura` do contrato). No modo seleção ela nasce `pendente`
/// e só a escolha a leva a `aceita`; no modo urgência já nasce `aceita`.
public enum EstadoCandidatura: String, Codable, CaseIterable, Sendable {
    /// Candidatou-se e espera a escolha.
    case pendente
    case aceita
    /// A vaga encheu com outros escolhidos.
    case recusada
    /// O profissional desistiu antes da escolha, sem penalidade (RN24).
    case retirada
    /// A vaga fechou sem escolhê-la: 24 h antes do início, cancelada ou encerrada.
    case expirada
}

/// A candidatura como o profissional a vê em `minhas_candidaturas` (`Candidatura` do contrato).
/// Traz o `turnoID` (0.2.32) quando a candidatura for aceita.
public struct Candidatura: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let vaga: VagaResumo
    public let estado: EstadoCandidatura
    public let criadaEm: Date
    public let turnoID: UUID?

    public init(id: UUID, vaga: VagaResumo, estado: EstadoCandidatura, criadaEm: Date, turnoID: UUID? = nil) {
        self.id = id
        self.vaga = vaga
        self.estado = estado
        self.criadaEm = criadaEm
        self.turnoID = turnoID
    }
}

/// Quem espera a escolha numa vaga de seleção, como a casa vê em `candidatos_da_vaga` (`Candidato`
/// do contrato): o perfil público, com a reputação e o denominador (RN08), e nunca o contato (RN10).
public struct Candidato: Codable, Hashable, Identifiable, Sendable {
    public let candidaturaID: UUID
    public let profissional: PerfilPublico
    public let criadaEm: Date
    /// `da_equipe` (contrato 0.2.38, decisão D7): o profissional está na equipe de confiança da
    /// casa. Serve só ao selo "da sua equipe"; a lista continua em ordem de chegada (RN06).
    /// Ausente na resposta vale `false`.
    public let daEquipe: Bool

    public init(candidaturaID: UUID, profissional: PerfilPublico, criadaEm: Date, daEquipe: Bool = false) {
        self.candidaturaID = candidaturaID
        self.profissional = profissional
        self.criadaEm = criadaEm
        self.daEquipe = daEquipe
    }

    public var id: UUID { candidaturaID }
}

/// Check-in ou check-out de um turno. A coordenada nunca sai do aparelho, só a distância (RN22).
public struct Presenca: Codable, Hashable, Sendable {
    public let instante: Date
    public let tipo: TipoRegistro?
    public let distanciaMetros: Int?
    public let confirmadaEm: Date?

    public init(instante: Date, tipo: TipoRegistro? = nil, distanciaMetros: Int?, confirmadaEm: Date? = nil) {
        self.instante = instante
        self.tipo = tipo
        self.distanciaMetros = distanciaMetros
        self.confirmadaEm = confirmadaEm
    }
}

/// Registro que as duas partes leem na 0.2.32. Não contém o motivo privado do painel.
public struct CancelamentoDoTurno: Codable, Hashable, Sendable {
    public let causa: CausaDoCancelamento
    public let falta: Bool
    public let canceladaEm: Date

    public init(causa: CausaDoCancelamento, falta: Bool, canceladaEm: Date) {
        self.causa = causa
        self.falta = falta
        self.canceladaEm = canceladaEm
    }
}

public struct Turno: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let posicaoID: UUID
    public let vaga: VagaResumo
    public let contraparte: PerfilPublico
    public let contatoVisivelAte: Date
    /// Quando o profissional avisou que está a caminho (contrato 0.2.25). Não é presença: o
    /// check-in continua sendo o registro que vale.
    public let aCaminhoEm: Date?
    public let checkin: Presenca?
    public let checkout: Presenca?
    public let verificacao: Verificacao
    public let valorAcordado: Dinheiro
    public let podeAvaliar: Bool
    /// Ausente no servidor anterior à 0.2.31; não presume confirmação.
    public let estado: EstadoPosicao?
    /// Avaliação deste lado do turno, nunca o voto recebido da contraparte.
    public let avaliacao: Avaliacao?
    /// `nil` preserva caches antigos. `true` distingue resposta nula de campo ausente.
    public let avaliacaoInformada: Bool?
    /// Instante local da leitura da API; o cache conserva a data, sem renovar um nulo antigo.
    public let avaliacaoLidaEm: Date?
    public let cancelamento: CancelamentoDoTurno?
    public var servidorInformaAvaliacao: Bool { avaliacaoInformada == true || avaliacao != nil }
    public var cancelado: Bool { estado == .cancelada }
    /// O contrato não traz o contato em `meus_turnos`: o app o anexa depois de `contato_do_turno`
    /// ou da candidatura, e o esconde depois de `contatoVisivelAte` mesmo sem rede (RN10).
    public let contato: Contato?

    public init(
        id: UUID,
        posicaoID: UUID,
        vaga: VagaResumo,
        contraparte: PerfilPublico,
        contatoVisivelAte: Date,
        aCaminhoEm: Date? = nil,
        checkin: Presenca? = nil,
        checkout: Presenca? = nil,
        verificacao: Verificacao,
        valorAcordado: Dinheiro,
        podeAvaliar: Bool,
        contato: Contato? = nil,
        estado: EstadoPosicao? = nil,
        avaliacao: Avaliacao? = nil,
        avaliacaoInformada: Bool? = nil,
        cancelamento: CancelamentoDoTurno? = nil,
        avaliacaoLidaEm: Date? = nil
    ) {
        self.id = id
        self.posicaoID = posicaoID
        self.vaga = vaga
        self.contraparte = contraparte
        self.contatoVisivelAte = contatoVisivelAte
        self.aCaminhoEm = aCaminhoEm
        self.checkin = checkin
        self.checkout = checkout
        self.verificacao = verificacao
        self.valorAcordado = valorAcordado
        self.podeAvaliar = podeAvaliar
        self.contato = contato
        self.estado = estado
        self.avaliacao = avaliacao
        self.avaliacaoInformada = avaliacaoInformada
        self.cancelamento = cancelamento
        self.avaliacaoLidaEm = avaliacaoLidaEm
    }

    // A data da leitura é metadado do cache, não muda a identidade nem o conteúdo do turno.
    public static func == (lhs: Turno, rhs: Turno) -> Bool {
        lhs.id == rhs.id && lhs.posicaoID == rhs.posicaoID && lhs.vaga == rhs.vaga &&
        lhs.contraparte == rhs.contraparte && lhs.contatoVisivelAte == rhs.contatoVisivelAte &&
        lhs.aCaminhoEm == rhs.aCaminhoEm && lhs.checkin == rhs.checkin && lhs.checkout == rhs.checkout &&
        lhs.verificacao == rhs.verificacao && lhs.valorAcordado == rhs.valorAcordado &&
        lhs.podeAvaliar == rhs.podeAvaliar && lhs.contato == rhs.contato && lhs.estado == rhs.estado &&
        lhs.avaliacao == rhs.avaliacao && lhs.avaliacaoInformada == rhs.avaliacaoInformada &&
        lhs.cancelamento == rhs.cancelamento
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public func contatoVisivel(em instante: Date) -> Bool { instante <= contatoVisivelAte }

    public func com(contato: Contato?) -> Turno {
        Turno(
            id: id, posicaoID: posicaoID, vaga: vaga, contraparte: contraparte, contatoVisivelAte: contatoVisivelAte,
            aCaminhoEm: aCaminhoEm, checkin: checkin, checkout: checkout, verificacao: verificacao,
            valorAcordado: valorAcordado, podeAvaliar: podeAvaliar, contato: contato,
            estado: estado, avaliacao: avaliacao, avaliacaoInformada: avaliacaoInformada,
            cancelamento: cancelamento, avaliacaoLidaEm: avaliacaoLidaEm
        )
    }

    public func com(aCaminhoEm: Date?) -> Turno {
        Turno(
            id: id, posicaoID: posicaoID, vaga: vaga, contraparte: contraparte, contatoVisivelAte: contatoVisivelAte,
            aCaminhoEm: aCaminhoEm, checkin: checkin, checkout: checkout, verificacao: verificacao,
            valorAcordado: valorAcordado, podeAvaliar: podeAvaliar, contato: contato,
            estado: estado, avaliacao: avaliacao, avaliacaoInformada: avaliacaoInformada,
            cancelamento: cancelamento, avaliacaoLidaEm: avaliacaoLidaEm
        )
    }

    public func com(avaliacao: Avaliacao) -> Turno {
        Turno(
            id: id, posicaoID: posicaoID, vaga: vaga, contraparte: contraparte, contatoVisivelAte: contatoVisivelAte,
            aCaminhoEm: aCaminhoEm, checkin: checkin, checkout: checkout, verificacao: verificacao,
            valorAcordado: valorAcordado, podeAvaliar: false, contato: contato,
            estado: estado, avaliacao: avaliacao, avaliacaoInformada: true,
            cancelamento: cancelamento, avaliacaoLidaEm: avaliacaoLidaEm
        )
    }

}

public struct ResultadoRegistro: Codable, Hashable, Sendable {
    public let turnoID: UUID
    public let tipo: TipoRegistro
    public let verificacao: Verificacao
    public let registradoEm: Date
    public let distanciaMetros: Int?

    public init(turnoID: UUID, tipo: TipoRegistro, verificacao: Verificacao, registradoEm: Date, distanciaMetros: Int?) {
        self.turnoID = turnoID
        self.tipo = tipo
        self.verificacao = verificacao
        self.registradoEm = registradoEm
        self.distanciaMetros = distanciaMetros
    }
}

/// Resposta de `avisar_a_caminho` (contrato 0.2.25): o instante que ficou gravado no turno.
public struct ResultadoACaminho: Codable, Hashable, Sendable {
    public let turnoID: UUID
    public let aCaminhoEm: Date

    public init(turnoID: UUID, aCaminhoEm: Date) {
        self.turnoID = turnoID
        self.aCaminhoEm = aCaminhoEm
    }
}

public struct Avaliacao: Codable, Hashable, Sendable {
    public let turnoID: UUID
    public let resposta: Bool
    public let criadaEm: Date

    public init(turnoID: UUID, resposta: Bool, criadaEm: Date) {
        self.turnoID = turnoID
        self.resposta = resposta
        self.criadaEm = criadaEm
    }
}

/// Resposta de `cancelar_posicao` e de `reabrir_por_atraso`. A posição cancelada não volta a ficar
/// aberta: quando a vaga reabre, é uma posição nova, e é ela que `novaPosicaoID` traz (RN12).
public struct ResultadoCancelamento: Codable, Hashable, Sendable {
    public let posicaoID: UUID
    /// Conta como falta do profissional: cancelamento dele a menos de 24 h do início, ou reabertura
    /// por atraso.
    public let falta: Bool
    /// Falso quando o turno ficou descoberto, sem posição nova para preencher.
    public let reaberta: Bool
    public let novaPosicaoID: UUID?

    public init(posicaoID: UUID, falta: Bool, reaberta: Bool, novaPosicaoID: UUID?) {
        self.posicaoID = posicaoID
        self.falta = falta
        self.reaberta = reaberta
        self.novaPosicaoID = novaPosicaoID
    }
}

/// Resposta de `cancelar_vaga`: a vaga inteira cancelada, com as posições abertas e as confirmadas.
public struct VagaCancelada: Codable, Hashable, Sendable {
    public let vagaID: UUID
    public let estado: EstadoVaga
    public let posicoesCanceladas: Int

    public init(vagaID: UUID, estado: EstadoVaga, posicoesCanceladas: Int) {
        self.vagaID = vagaID
        self.estado = estado
        self.posicoesCanceladas = posicoesCanceladas
    }
}

public enum CausaDoCancelamento: String, Codable, CaseIterable, Hashable, Sendable {
    case profissional
    case estabelecimento
    case reaberturaPorAtraso = "reabertura_por_atraso"
    case noShowSemCheckin = "no_show_sem_checkin"
    case outro

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = CausaDoCancelamento(rawValue: rawValue) ?? .outro
    }
}

public struct CancelamentoDaPosicao: Codable, Hashable, Sendable {
    public let causa: CausaDoCancelamento
    public let falta: Bool
    public let motivo: String?
    public let canceladaEm: Date

    public init(causa: CausaDoCancelamento, falta: Bool, motivo: String?, canceladaEm: Date) {
        self.causa = causa
        self.falta = falta
        self.motivo = motivo
        self.canceladaEm = canceladaEm
    }
}

public struct PosicaoNoPainel: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let estado: EstadoPosicao
    public let profissional: PerfilPublico?
    public let turnoID: UUID?
    public let verificacao: Verificacao?
    public let emAtraso: Bool
    /// Nulo enquanto o profissional não avisou, ou se a posição ainda não tem turno (contrato 0.2.25).
    public let aCaminhoEm: Date?
    /// Hora do toque no check-in (contrato 0.2.31). Opcional: o servidor anterior à 0.2.31 não manda.
    public let checkinEm: Date?
    /// Tipo do check-in (contrato 0.2.31). Opcional.
    public let checkinTipo: TipoRegistro?
    /// Quando o contratante confirmou o check-in manual (contrato 0.2.31). Opcional.
    public let checkinConfirmadoEm: Date?
    /// Por que a posição foi cancelada (contrato 0.2.31, RN12). Opcional.
    public let cancelamento: CancelamentoDaPosicao?

    public init(
        id: UUID, estado: EstadoPosicao, profissional: PerfilPublico?, turnoID: UUID?, verificacao: Verificacao?,
        emAtraso: Bool, aCaminhoEm: Date? = nil, checkinEm: Date? = nil, checkinTipo: TipoRegistro? = nil,
        checkinConfirmadoEm: Date? = nil, cancelamento: CancelamentoDaPosicao? = nil
    ) {
        self.id = id
        self.estado = estado
        self.profissional = profissional
        self.turnoID = turnoID
        self.verificacao = verificacao
        self.emAtraso = emAtraso
        self.aCaminhoEm = aCaminhoEm
        self.checkinEm = checkinEm
        self.checkinTipo = checkinTipo
        self.checkinConfirmadoEm = checkinConfirmadoEm
        self.cancelamento = cancelamento
    }
}

public struct VagaNoPainel: Codable, Hashable, Sendable {
    public let vaga: VagaResumo
    public let modo: ModoPreenchimento
    public let estado: EstadoVaga
    /// "Oculta pela Equipe" (contrato 0.2.23): fora da vitrine e do despacho, sem escolha de
    /// candidato e sem republicação, até a Equipe Frila reexibi-la. O `estado` não muda.
    public let oculta: Bool
    public let alertaVagaVazia: Bool
    public let candidatosPendentes: Int
    public let posicoes: [PosicaoNoPainel]
    /// 0.2.41: Quantas posições republicar_posicoes_restantes republicaria agora, ou nulo quando a
    /// vaga não é republicável por esse caminho. O botão só aparece quando for > 0.
    public let republicavelEmUrgencia: Int?

    public init(
        vaga: VagaResumo, modo: ModoPreenchimento, estado: EstadoVaga, oculta: Bool = false, alertaVagaVazia: Bool,
        candidatosPendentes: Int, posicoes: [PosicaoNoPainel], republicavelEmUrgencia: Int? = nil
    ) {
        self.vaga = vaga
        self.modo = modo
        self.estado = estado
        self.oculta = oculta
        self.alertaVagaVazia = alertaVagaVazia
        self.candidatosPendentes = candidatosPendentes
        self.posicoes = posicoes
        self.republicavelEmUrgencia = republicavelEmUrgencia
    }
}

extension VagaNoPainel {
    /// O botão "Republicar N posições em urgência" só aparece quando maior que zero (0.2.41, D1-C).
    public var podeRepublicarEmUrgencia: Bool {
        guard let republicavelEmUrgencia else { return false }
        return republicavelEmUrgencia > 0
    }

    /// Quantas posições ainda esperam alguém.
    public var posicoesAbertas: Int { posicoes.count { $0.estado == .aberta } }

    /// A vaga de seleção com posição aberta a 24 h ou menos do início: a posição é reposta em
    /// urgência (`RegraDaSelecao`), e a casa não escolhe candidato nela.
    public func reposicaoEmUrgencia(em agora: Date) -> Bool {
        RegraDaSelecao.reposicaoEmUrgencia(modo: modo, estado: estado, posicoesAbertas: posicoesAbertas, inicio: vaga.periodo.inicio, agora: agora)
    }
}

public struct Painel: Codable, Hashable, Sendable {
    public let estabelecimentoID: UUID
    public let vagas: [VagaNoPainel]
    public let checkinsPendentes: [UUID]

    public init(estabelecimentoID: UUID, vagas: [VagaNoPainel], checkinsPendentes: [UUID]) {
        self.estabelecimentoID = estabelecimentoID
        self.vagas = vagas
        self.checkinsPendentes = checkinsPendentes
    }
}

// MARK: Confiança e direitos

public enum MotivoDenuncia: String, Codable, CaseIterable, Sendable {
    case assedio
    case discriminacao
    case riscoSeguranca = "risco_seguranca"
    /// Fraude e documento falso chegam por aqui, com o relato (decisão de produto de 30/09).
    case outro
}

/// Quem a denúncia ou o bloqueio aponta: o par `alvo_tipo` + `alvo_id` do contrato. São o `tipo` e
/// o `id` do `PerfilPublico` que já está na tela; o servidor resolve a conta a partir deles, e o
/// app nunca vê o id de conta da outra parte (RN10).
public struct Alvo: Codable, Hashable, Sendable {
    public let tipo: TipoPerfilPublico
    public let id: UUID

    public init(tipo: TipoPerfilPublico, id: UUID) {
        self.tipo = tipo
        self.id = id
    }

    public init(_ perfil: PerfilPublico) {
        self.init(tipo: perfil.tipo, id: perfil.id)
    }
}

public enum TipoDeProtocolo: String, Codable, Sendable {
    case denuncia
    case contestacao
    case revisaoDespacho = "revisao_despacho"
    case suporte

    /// Tipo novo de protocolo cai em `denuncia`: o tipo é informativo, nenhuma tela decide nada por ele; o número e o prazo é que importam.
    public init(from decoder: Decoder) throws {
        let valor = try decoder.singleValueContainer().decode(String.self)
        self = TipoDeProtocolo(rawValue: valor) ?? .denuncia
    }
}

/// Categoria do chamado de suporte no turno (contrato 0.2.40, UC14).
public enum CategoriaSuporte: String, CaseIterable, Codable, Sendable {
    case endereco
    case atraso
    case conduta
    case seguranca
    case outro

    public init(from decoder: Decoder) throws {
        let valor = try decoder.singleValueContainer().decode(String.self)
        self = CategoriaSuporte(rawValue: valor) ?? .outro
    }
}

/// Registro de algo que a Equipe Frila responde por e-mail em até 5 dias úteis.
public struct Protocolo: Codable, Hashable, Sendable {
    public let ocorrenciaID: UUID
    public let tipo: TipoDeProtocolo
    public let criadaEm: Date
    public let prazoRespostaAte: DataCivil

    /// Os 8 primeiros caracteres hexadecimais de `ocorrenciaID` sem hifens, em maiúsculas (contrato 0.2.40).
    public var protocoloCurto: String {
        Self.calcularProtocoloCurto(ocorrenciaID)
    }

    public static func calcularProtocoloCurto(_ id: UUID) -> String {
        String(id.uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).uppercased()
    }

    public init(ocorrenciaID: UUID, tipo: TipoDeProtocolo, criadaEm: Date, prazoRespostaAte: DataCivil) {
        self.ocorrenciaID = ocorrenciaID
        self.tipo = tipo
        self.criadaEm = criadaEm
        self.prazoRespostaAte = prazoRespostaAte
    }
}

/// Bloqueio em vigor. Vale nos dois sentidos e, para membro de estabelecimento, na casa inteira (RF26).
public struct Bloqueio: Codable, Hashable, Sendable {
    public let alvo: Alvo
    public let criadoEm: Date

    public init(alvo: Alvo, criadoEm: Date) {
        self.alvo = alvo
        self.criadoEm = criadoEm
    }
}

public struct Suspensao: Codable, Hashable, Sendable {
    public let motivo: String
    public let desde: Date
    /// A contestação em análise, se houver. Nula não garante que dá para contestar: o servidor
    /// recusa com `contestacao_ja_aberta` se já houve contestação desta suspensão, mesmo resolvida,
    /// e a contestação resolvida não aparece aqui.
    public let contestacao: Protocolo?

    public init(motivo: String, desde: Date, contestacao: Protocolo?) {
        self.motivo = motivo
        self.desde = desde
        self.contestacao = contestacao
    }
}

/// O que o titular vê da própria conta: o estado e, quando suspensa, o motivo, a data e a
/// contestação em andamento (RF24, RN13).
public struct SituacaoDaConta: Codable, Hashable, Sendable {
    public let estado: EstadoConta
    public let suspensao: Suspensao?

    public init(estado: EstadoConta, suspensao: Suspensao?) {
        self.estado = estado
        self.suspensao = suspensao
    }
}

/// O par que entra e sai da equipe de confiança de um estabelecimento (RF18, UC11). É o corpo de
/// `incluir_na_equipe` e `remover_da_equipe`, e o que as duas devolvem.
public struct MembroDaEquipe: Codable, Hashable, Sendable {
    public let estabelecimentoID: UUID
    public let profissionalID: UUID

    public init(estabelecimentoID: UUID, profissionalID: UUID) {
        self.estabelecimentoID = estabelecimentoID
        self.profissionalID = profissionalID
    }
}

/// Um estabelecimento cuja equipe de confiança inclui o profissional (RF18): as vagas dele chegam
/// mesmo além da distância máxima, desde que a função e a grade batam.
public struct EquipeDeConfiancaDoProfissional: Codable, Hashable, Identifiable, Sendable {
    public let estabelecimentoID: UUID
    public let nome: String

    public var id: UUID { estabelecimentoID }

    public init(estabelecimentoID: UUID, nome: String) {
        self.estabelecimentoID = estabelecimentoID
        self.nome = nome
    }
}

/// O que decide se o profissional recebe a notificação de uma vaga (RF27, LGPD art. 20): função,
/// grade semanal de disponibilidade, distância do ponto base e as equipes de confiança de que faz
/// parte. O texto da tela "Por que recebo vagas" é do app; aqui só os dados em vigor.
public struct CriteriosDeNotificacao: Codable, Hashable, Sendable {
    public let funcoes: [Funcao]
    public let disponibilidades: [JanelaDeDisponibilidade]
    /// Parâmetro do sistema; hoje, 15 km (RN05).
    public let distanciaMaximaKm: Double
    public let equipesDeConfianca: [EquipeDeConfiancaDoProfissional]
    /// Teto de RN23; hoje, 30 minutos.
    public let notificacoesNoMaximoACadaMin: Int

    public init(
        funcoes: [Funcao],
        disponibilidades: [JanelaDeDisponibilidade],
        distanciaMaximaKm: Double,
        equipesDeConfianca: [EquipeDeConfiancaDoProfissional],
        notificacoesNoMaximoACadaMin: Int
    ) {
        self.funcoes = funcoes
        self.disponibilidades = disponibilidades
        self.distanciaMaximaKm = distanciaMaximaKm
        self.equipesDeConfianca = equipesDeConfianca
        self.notificacoesNoMaximoACadaMin = notificacoesNoMaximoACadaMin
    }

    /// Sem função, sem grade e sem equipe: nenhuma vaga chega por notificação, e a tela diz isso em
    /// vez de mostrar três seções vazias.
    public var semCriterios: Bool { funcoes.isEmpty && disponibilidades.isEmpty && equipesDeConfianca.isEmpty }
}

// MARK: - Telemetria (RN15, RNF08, contrato 0.2.41)

/// Dicionário estrito e fechado de eventos de telemetria do app (contrato 0.2.41, RN15, RNF08, T-0017).
/// Não aceita texto livre nem parâmetros arbitrários.
public enum EventoDeTelemetria: String, Codable, CaseIterable, Sendable {
    case appAberto = "app_aberto"
    case cadastroConcluido = "cadastro_concluido"
    case permissaoPushNegada = "permissao_push_negada"
    case vagaVista = "vaga_vista"
    case vagaDetalheAberto = "vaga_detalhe_aberto"
    case candidaturaEnviada = "candidatura_enviada"
    case candidaturaRetirada = "candidatura_retirada"
    case checkinTentado = "checkin_tentado"
    case checkinConcluido = "checkin_concluido"
    case checkoutConcluido = "checkout_concluido"
    case avaliacaoEnviada = "avaliacao_enviada"
    case contatoAberto = "contato_aberto"
    case acaoEnfileiradaOffline = "acao_enfileirada_offline"
    case atualizacaoObrigatoriaExibida = "atualizacao_obrigatoria_exibida"
}

/// Registro de evento de telemetria com identificadores relacionais opcionais e instante de ocorrência.
public struct RegistroDeEvento: Codable, Equatable, Sendable {
    public let evento: EventoDeTelemetria
    public let vagaID: UUID?
    public let turnoID: UUID?
    public let ocorridoEm: Date?

    public init(
        evento: EventoDeTelemetria,
        vagaID: UUID? = nil,
        turnoID: UUID? = nil,
        ocorridoEm: Date? = nil
    ) {
        self.evento = evento
        self.vagaID = vagaID
        self.turnoID = turnoID
        self.ocorridoEm = ocorridoEm
    }
}


// MARK: Foto de perfil (contrato 0.2.54, RN37 e RN46)

/// Tipos de mídia do contrato. Nesta versão só `fotoPerfil` está disponível; os outros três são
/// reservados para a v1.2 e o servidor os recusa com `422 midia_invalida` (`tipo_indisponivel`).
public enum TipoMidia: String, Codable, CaseIterable, Sendable {
    case fotoPerfil = "foto_perfil"
    case fotoTrabalho = "foto_trabalho"
    case fotoLocal = "foto_local"
    case curriculo
}

/// `enviando` → `em_analise` → `aprovada`, `recusada` ou `nao_publicada` (a análise falhou 4 vezes);
/// `aprovada` → `ocultada` (duas denúncias) ou `removida` (pelo dono). Só `aprovada` aparece para outra conta.
public enum EstadoMidia: String, Codable, CaseIterable, Sendable {
    case enviando
    case emAnalise = "em_analise"
    case aprovada
    case recusada
    case naoPublicada = "nao_publicada"
    case ocultada
    case removida
}

/// Motivo genérico da recusa, que a tela traduz em texto amigável. O código fino do modelo nunca sai da API.
public enum MotivoRecusaMidia: String, Codable, CaseIterable, Sendable {
    case fotoInadequada = "foto_inadequada"
    case textoOuDadoPessoal = "texto_ou_dado_pessoal"
    case naoEPessoaOuServico = "nao_e_pessoa_ou_servico"
    case naoAnalisada = "nao_analisada"
}

/// A mídia como o dono a vê. Nunca traz o caminho no Storage, o código fino do motivo nem o hash.
public struct Midia: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let tipo: TipoMidia
    public let estado: EstadoMidia
    public let motivoRecusa: MotivoRecusaMidia?
    /// `true` só com a mídia `recusada` ou `nao_publicada`, a nova análise ainda não pedida e o
    /// arquivo ainda não expurgado.
    public let podePedirNovaAnalise: Bool
    /// URL assinada por 1 h, só com a mídia `aprovada`.
    public let url: URL?
    public let estabelecimentoID: UUID?
    public let enviadaEm: Date?
    public let decididaEm: Date?

    public init(
        id: UUID,
        tipo: TipoMidia = .fotoPerfil,
        estado: EstadoMidia,
        motivoRecusa: MotivoRecusaMidia? = nil,
        podePedirNovaAnalise: Bool = false,
        url: URL? = nil,
        estabelecimentoID: UUID? = nil,
        enviadaEm: Date? = nil,
        decididaEm: Date? = nil
    ) {
        self.id = id
        self.tipo = tipo
        self.estado = estado
        self.motivoRecusa = motivoRecusa
        self.podePedirNovaAnalise = podePedirNovaAnalise
        self.url = url
        self.estabelecimentoID = estabelecimentoID
        self.enviadaEm = enviadaEm
        self.decididaEm = decididaEm
    }
}

/// O pedido de URL de upload: a mídia nasce em `enviando` e o app envia o JPEG para `uploadURL`.
public struct UploadDeMidia: Equatable, Sendable {
    public let midiaID: UUID
    public let uploadURL: URL
    /// Presente no contrato, mas o app não a usa: a miniatura deriva do servidor (CD-M04b).
    public let uploadURLMiniatura: URL?
    public let expiraEm: Date

    public init(midiaID: UUID, uploadURL: URL, uploadURLMiniatura: URL? = nil, expiraEm: Date) {
        self.midiaID = midiaID
        self.uploadURL = uploadURL
        self.uploadURLMiniatura = uploadURLMiniatura
        self.expiraEm = expiraEm
    }
}

/// Pedido de `solicitar_upload_midia`.
public struct PedidoDeUploadDeMidia: Equatable, Sendable {
    public let tipo: TipoMidia
    public let mime: String
    public let bytes: Int
    public let estabelecimentoID: UUID?

    public init(tipo: TipoMidia = .fotoPerfil, mime: String = "image/jpeg", bytes: Int, estabelecimentoID: UUID? = nil) {
        self.tipo = tipo
        self.mime = mime
        self.bytes = bytes
        self.estabelecimentoID = estabelecimentoID
    }
}

/// Interruptores do servidor (`ConfiguracaoDoApp.recursos`). Ausente vale desligado: no Prod nascem desligados.
public struct RecursosDoApp: Codable, Equatable, Sendable {
    public let fotoDePerfil: Bool
    public let chamadaDireta: Bool
    public let perfilRico: Bool

    public init(fotoDePerfil: Bool = false, chamadaDireta: Bool = false, perfilRico: Bool = false) {
        self.fotoDePerfil = fotoDePerfil
        self.chamadaDireta = chamadaDireta
        self.perfilRico = perfilRico
    }

    public static let desligados = RecursosDoApp()
}
