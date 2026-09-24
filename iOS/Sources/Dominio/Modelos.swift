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

/// O que uma parte vê da outra: nome e reputação, nunca contato (RN10).
public struct PerfilPublico: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let tipo: TipoPerfilPublico
    public let nome: String
    public let funcoes: [String]
    public let reputacao: Reputacao

    public init(id: UUID, tipo: TipoPerfilPublico, nome: String, funcoes: [String] = [], reputacao: Reputacao) {
        self.id = id
        self.tipo = tipo
        self.nome = nome
        self.funcoes = funcoes
        self.reputacao = reputacao
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
    public let estabelecimento: PerfilPublico
    public let funcao: Funcao
    public let periodo: Periodo
    public let local: String
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
    public let publicadoEm: Date

    public init(
        id: UUID,
        estabelecimento: PerfilPublico,
        funcao: Funcao,
        periodo: Periodo,
        local: String,
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
        publicadoEm: Date
    ) {
        self.id = id
        self.estabelecimento = estabelecimento
        self.funcao = funcao
        self.periodo = periodo
        self.local = local
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
        self.publicadoEm = publicadoEm
    }

    public var resumo: VagaResumo {
        VagaResumo(id: id, funcao: funcao.nome, local: local, periodo: periodo, valor: valor)
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

/// Item da lista de vagas abertas: sem endereço exato nem responsável, que só o detalhe traz.
public struct VagaNaLista: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let funcao: Funcao
    public let estabelecimento: PerfilPublico
    public let periodo: Periodo
    public let local: String
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
        self.distanciaKm = distanciaKm
        self.valor = valor
        self.posicoesAbertas = posicoesAbertas
        self.inclusos = inclusos
        self.modo = modo
    }
}

public struct VagaResumo: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let funcao: String
    public let local: String
    public let periodo: Periodo
    public let valor: Dinheiro

    public init(id: UUID, funcao: String, local: String, periodo: Periodo, valor: Dinheiro) {
        self.id = id
        self.funcao = funcao
        self.local = local
        self.periodo = periodo
        self.valor = valor
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

public enum TipoRegistro: String, Codable, Sendable {
    case geolocalizado
    case manual
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

public struct Turno: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let posicaoID: UUID
    public let vaga: VagaResumo
    public let contraparte: PerfilPublico
    public let contatoVisivelAte: Date
    public let checkin: Presenca?
    public let checkout: Presenca?
    public let verificacao: Verificacao
    public let valorAcordado: Dinheiro
    public let podeAvaliar: Bool
    /// O contrato não traz o contato em `meus_turnos`: o app o anexa depois de `contato_do_turno`
    /// ou da candidatura, e o esconde depois de `contatoVisivelAte` mesmo sem rede (RN10).
    public let contato: Contato?

    public init(
        id: UUID,
        posicaoID: UUID,
        vaga: VagaResumo,
        contraparte: PerfilPublico,
        contatoVisivelAte: Date,
        checkin: Presenca? = nil,
        checkout: Presenca? = nil,
        verificacao: Verificacao,
        valorAcordado: Dinheiro,
        podeAvaliar: Bool,
        contato: Contato? = nil
    ) {
        self.id = id
        self.posicaoID = posicaoID
        self.vaga = vaga
        self.contraparte = contraparte
        self.contatoVisivelAte = contatoVisivelAte
        self.checkin = checkin
        self.checkout = checkout
        self.verificacao = verificacao
        self.valorAcordado = valorAcordado
        self.podeAvaliar = podeAvaliar
        self.contato = contato
    }

    public func contatoVisivel(em instante: Date) -> Bool { instante <= contatoVisivelAte }

    public func com(contato: Contato?) -> Turno {
        Turno(
            id: id, posicaoID: posicaoID, vaga: vaga, contraparte: contraparte, contatoVisivelAte: contatoVisivelAte,
            checkin: checkin, checkout: checkout, verificacao: verificacao, valorAcordado: valorAcordado,
            podeAvaliar: podeAvaliar, contato: contato
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

public struct PosicaoNoPainel: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let estado: EstadoPosicao
    public let profissional: PerfilPublico?
    public let turnoID: UUID?
    public let verificacao: Verificacao?
    public let emAtraso: Bool

    public init(id: UUID, estado: EstadoPosicao, profissional: PerfilPublico?, turnoID: UUID?, verificacao: Verificacao?, emAtraso: Bool) {
        self.id = id
        self.estado = estado
        self.profissional = profissional
        self.turnoID = turnoID
        self.verificacao = verificacao
        self.emAtraso = emAtraso
    }
}

public struct VagaNoPainel: Codable, Hashable, Sendable {
    public let vaga: VagaResumo
    public let modo: ModoPreenchimento
    public let estado: EstadoVaga
    public let alertaVagaVazia: Bool
    public let candidatosPendentes: Int
    public let posicoes: [PosicaoNoPainel]

    public init(vaga: VagaResumo, modo: ModoPreenchimento, estado: EstadoVaga, alertaVagaVazia: Bool, candidatosPendentes: Int, posicoes: [PosicaoNoPainel]) {
        self.vaga = vaga
        self.modo = modo
        self.estado = estado
        self.alertaVagaVazia = alertaVagaVazia
        self.candidatosPendentes = candidatosPendentes
        self.posicoes = posicoes
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
