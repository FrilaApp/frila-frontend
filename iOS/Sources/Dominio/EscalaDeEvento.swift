import Foundation

/// O evento de uma escala (contrato 0.2.96, `publicar_escala`): o dia e o lugar valem para todas as vagas dela. O
/// endereço, a região e o ponto são os do cadastro da casa, como na vaga avulsa.
public struct EventoDaEscala: Equatable, Sendable {
    public let nome: String
    public let data: DataCivil
    public let local: String
    public let regiaoAdministrativa: String
    public let ponto: Coordenada

    public init(nome: String, data: DataCivil, local: String, regiaoAdministrativa: String, ponto: Coordenada) {
        self.nome = nome
        self.data = data
        self.local = local
        self.regiaoAdministrativa = regiaoAdministrativa
        self.ponto = ponto
    }
}

/// Uma vaga da escala: os campos de `PublicacaoVaga`, menos o estabelecimento, a chave e o endereço, que vêm da escala.
public struct VagaDaEscala: Equatable, Sendable {
    public let funcaoID: UUID
    public let periodo: Periodo
    public let valor: Dinheiro
    public let posicoes: Int
    public let inclusos: Inclusos
    public let responsavelLocal: String
    public let traje: String?
    public let participaRateio: Bool?
    public let observacoes: String?
    public let modo: ModoPreenchimento
    /// Minutos antes do início em que a casa é avisada se a vaga seguir vazia; sem valor, vale o do servidor (180).
    public let alertaAntecedenciaMinutos: Int?

    public init(
        funcaoID: UUID, periodo: Periodo, valor: Dinheiro, posicoes: Int, inclusos: Inclusos, responsavelLocal: String,
        traje: String? = nil, participaRateio: Bool? = nil, observacoes: String? = nil, modo: ModoPreenchimento = .urgencia,
        alertaAntecedenciaMinutos: Int? = nil
    ) {
        self.funcaoID = funcaoID
        self.periodo = periodo
        self.valor = valor
        self.posicoes = posicoes
        self.inclusos = inclusos
        self.responsavelLocal = responsavelLocal
        self.traje = traje
        self.participaRateio = participaRateio
        self.observacoes = observacoes
        self.modo = modo
        self.alertaAntecedenciaMinutos = alertaAntecedenciaMinutos
    }
}

/// O pedido de `publicar_escala`: um evento e de 1 a 10 vagas, tudo ou nada. A `chave` é uma só para a escala inteira,
/// gerada uma vez por publicação: reenviar com ela devolve a mesma escala, sem publicar de novo.
public struct PublicacaoEscala: Equatable, Sendable {
    /// De 1 a 10 vagas por escala.
    public static let limiteDeVagas = 10
    /// Cada vaga da escala leva de 1 a 100 pessoas, e a soma de todas também fica em 100.
    public static let limiteDePosicoes = 100

    public let estabelecimentoID: UUID
    public let evento: EventoDaEscala
    public let vagas: [VagaDaEscala]
    public let chave: UUID

    public init(estabelecimentoID: UUID, evento: EventoDaEscala, vagas: [VagaDaEscala], chave: UUID) {
        self.estabelecimentoID = estabelecimentoID
        self.evento = evento
        self.vagas = vagas
        self.chave = chave
    }
}

/// A resposta de `publicar_escala`: o evento e uma `VagaPublicada` por vaga do pedido, na mesma ordem.
public struct EscalaPublicada: Equatable, Sendable {
    public let eventoID: UUID
    public let vagas: [VagaPublicada]

    public init(eventoID: UUID, vagas: [VagaPublicada]) {
        self.eventoID = eventoID
        self.vagas = vagas
    }
}
