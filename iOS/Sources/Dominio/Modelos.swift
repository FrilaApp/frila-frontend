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
        publicadoEm: Date
    ) {
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
        VagaResumo(id: id, funcao: funcao.nome, local: local, regiaoAdministrativa: regiaoAdministrativa, periodo: periodo, valor: valor)
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
    public let id: UUID
    public let funcao: String
    public let local: String
    public let regiaoAdministrativa: String
    public let periodo: Periodo
    public let valor: Dinheiro

    public init(id: UUID, funcao: String, local: String, regiaoAdministrativa: String, periodo: Periodo, valor: Dinheiro) {
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
        avaliacaoInformada: Bool? = nil
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
    }

    public func contatoVisivel(em instante: Date) -> Bool { instante <= contatoVisivelAte }

    public func com(contato: Contato?) -> Turno {
        Turno(
            id: id, posicaoID: posicaoID, vaga: vaga, contraparte: contraparte, contatoVisivelAte: contatoVisivelAte,
            aCaminhoEm: aCaminhoEm, checkin: checkin, checkout: checkout, verificacao: verificacao,
            valorAcordado: valorAcordado, podeAvaliar: podeAvaliar, contato: contato,
            estado: estado, avaliacao: avaliacao, avaliacaoInformada: avaliacaoInformada
        )
    }

    public func com(aCaminhoEm: Date?) -> Turno {
        Turno(
            id: id, posicaoID: posicaoID, vaga: vaga, contraparte: contraparte, contatoVisivelAte: contatoVisivelAte,
            aCaminhoEm: aCaminhoEm, checkin: checkin, checkout: checkout, verificacao: verificacao,
            valorAcordado: valorAcordado, podeAvaliar: podeAvaliar, contato: contato,
            estado: estado, avaliacao: avaliacao, avaliacaoInformada: avaliacaoInformada
        )
    }

    public func com(avaliacao: Avaliacao) -> Turno {
        Turno(
            id: id, posicaoID: posicaoID, vaga: vaga, contraparte: contraparte, contatoVisivelAte: contatoVisivelAte,
            aCaminhoEm: aCaminhoEm, checkin: checkin, checkout: checkout, verificacao: verificacao,
            valorAcordado: valorAcordado, podeAvaliar: false, contato: contato,
            estado: estado, avaliacao: avaliacao, avaliacaoInformada: true
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

public struct PosicaoNoPainel: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let estado: EstadoPosicao
    public let profissional: PerfilPublico?
    public let turnoID: UUID?
    public let verificacao: Verificacao?
    public let emAtraso: Bool
    /// Nulo enquanto o profissional não avisou, ou se a posição ainda não tem turno (contrato 0.2.25).
    public let aCaminhoEm: Date?

    public init(
        id: UUID, estado: EstadoPosicao, profissional: PerfilPublico?, turnoID: UUID?, verificacao: Verificacao?,
        emAtraso: Bool, aCaminhoEm: Date? = nil
    ) {
        self.id = id
        self.estado = estado
        self.profissional = profissional
        self.turnoID = turnoID
        self.verificacao = verificacao
        self.emAtraso = emAtraso
        self.aCaminhoEm = aCaminhoEm
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

    public init(
        vaga: VagaResumo, modo: ModoPreenchimento, estado: EstadoVaga, oculta: Bool = false, alertaVagaVazia: Bool,
        candidatosPendentes: Int, posicoes: [PosicaoNoPainel]
    ) {
        self.vaga = vaga
        self.modo = modo
        self.estado = estado
        self.oculta = oculta
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
}

/// Registro de algo que a Equipe Frila responde por e-mail em até 5 dias úteis.
public struct Protocolo: Codable, Hashable, Sendable {
    public let ocorrenciaID: UUID
    public let tipo: TipoDeProtocolo
    public let criadaEm: Date
    public let prazoRespostaAte: DataCivil

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
