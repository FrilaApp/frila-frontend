import Foundation

public enum PerfilConta: String, Codable, CaseIterable, Sendable {
    case profissional
    case contratante
}

public struct SessaoUsuario: Codable, Equatable, Sendable {
    public let usuarioID: UUID
    public let perfil: PerfilConta

    public init(usuarioID: UUID, perfil: PerfilConta) {
        self.usuarioID = usuarioID
        self.perfil = perfil
    }
}

public struct Funcao: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let nome: String
    public let categoria: String

    public init(id: UUID, nome: String, categoria: String) {
        self.id = id
        self.nome = nome
        self.categoria = categoria
    }
}

public struct Reputacao: Codable, Hashable, Sendable {
    public let positivas: Int
    public let total: Int
    public let taxaComparecimento: Double?
    public let turnosConsiderados: Int

    public init(
        positivas: Int,
        total: Int,
        taxaComparecimento: Double?,
        turnosConsiderados: Int
    ) {
        self.positivas = positivas
        self.total = total
        self.taxaComparecimento = taxaComparecimento
        self.turnosConsiderados = turnosConsiderados
    }

    public var semHistorico: Bool { total == 0 }

    public func descricao() -> String {
        guard !semHistorico else { return "Sem histórico" }
        return "\(positivas) de \(total) chamariam de novo"
    }
}

public struct Profissional: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let nome: String
    public let funcoes: [Funcao]
    public let pontoBase: Coordenada
    public let disponibilidades: [JanelaDeDisponibilidade]
    public let reputacao: Reputacao

    public init(
        id: UUID,
        nome: String,
        funcoes: [Funcao],
        pontoBase: Coordenada,
        disponibilidades: [JanelaDeDisponibilidade],
        reputacao: Reputacao
    ) {
        self.id = id
        self.nome = nome
        self.funcoes = funcoes
        self.pontoBase = pontoBase
        self.disponibilidades = disponibilidades
        self.reputacao = reputacao
    }
}

public enum TipoEstabelecimento: String, Codable, CaseIterable, Sendable {
    case foodService = "food_service"
    case evento
    case varejo
    case logistica
    case servicoDomestico = "servico_domestico"
    case outro
}

public enum PapelMembro: String, Codable, CaseIterable, Sendable {
    case administrador
    case operador
}

public struct Estabelecimento: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let nome: String
    public let documento: String
    public let tipo: TipoEstabelecimento
    public let endereco: String
    public let ponto: Coordenada
    public let papel: PapelMembro

    public init(
        id: UUID,
        nome: String,
        documento: String = "",
        tipo: TipoEstabelecimento,
        endereco: String,
        ponto: Coordenada,
        papel: PapelMembro = .administrador
    ) {
        self.id = id
        self.nome = nome
        self.documento = documento
        self.tipo = tipo
        self.endereco = endereco
        self.ponto = ponto
        self.papel = papel
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

public struct Vaga: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let estabelecimento: Estabelecimento
    public let funcao: Funcao
    public let periodo: Periodo
    public let local: String
    public let ponto: Coordenada
    public let valor: Dinheiro
    public let posicoes: Int
    public let posicoesAbertas: Int
    public let inclusos: Inclusos
    public let responsavelLocal: String
    public let modo: ModoPreenchimento
    public let estado: EstadoVaga

    public init(
        id: UUID,
        estabelecimento: Estabelecimento,
        funcao: Funcao,
        periodo: Periodo,
        local: String,
        ponto: Coordenada,
        valor: Dinheiro,
        posicoes: Int,
        posicoesAbertas: Int,
        inclusos: Inclusos,
        responsavelLocal: String,
        modo: ModoPreenchimento,
        estado: EstadoVaga
    ) {
        self.id = id
        self.estabelecimento = estabelecimento
        self.funcao = funcao
        self.periodo = periodo
        self.local = local
        self.ponto = ponto
        self.valor = valor
        self.posicoes = posicoes
        self.posicoesAbertas = posicoesAbertas
        self.inclusos = inclusos
        self.responsavelLocal = responsavelLocal
        self.modo = modo
        self.estado = estado
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
        if modo == .selecao, periodo.inicio.timeIntervalSince(agora) < 24 * 60 * 60 {
            erros.append(.selecaoSemAntecedencia)
        }
        return erros
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

public struct Turno: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let posicaoID: UUID
    public let vaga: Vaga
    public let verificacao: Verificacao
    public let valorAcordado: Dinheiro
    public let contato: Contato?

    public init(
        id: UUID,
        posicaoID: UUID,
        vaga: Vaga,
        verificacao: Verificacao,
        valorAcordado: Dinheiro,
        contato: Contato?
    ) {
        self.id = id
        self.posicaoID = posicaoID
        self.vaga = vaga
        self.verificacao = verificacao
        self.valorAcordado = valorAcordado
        self.contato = contato
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
