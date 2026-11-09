import Foundation

public enum CodigoErroAPI: String, Codable, CaseIterable, Sendable {
    case naoAutenticado = "nao_autenticado"
    case semPermissao = "sem_permissao"
    case contatoExpirado = "contato_expirado"
    case naoEncontrado = "nao_encontrado"
    case posicaoJaPreenchida = "posicao_ja_preenchida"
    case vagaEncerrada = "vaga_encerrada"
    case checkinPendente = "checkin_pendente"
    case checkinJaConfirmado = "checkin_ja_confirmado"
    case posicaoNaoCancelavel = "posicao_nao_cancelavel"
    case candidaturaIndisponivel = "candidatura_indisponivel"
    case avaliacaoJaRegistrada = "avaliacao_ja_registrada"
    case contaExistente = "conta_existente"
    case documentoJaCadastrado = "documento_ja_cadastrado"
    case administradorUnico = "administrador_unico"
    case perfilJaExiste = "perfil_ja_existe"
    case campoObrigatorio = "campo_obrigatorio"
    case funcaoNaoMarcada = "funcao_nao_marcada"
    case campoInvalido = "campo_invalido"
    case intervaloMaximoExcedido = "intervalo_maximo_excedido"
    case foraDaJanela = "fora_da_janela"
    case aCaminhoForaDaJanela = "a_caminho_fora_da_janela"
    case registroNoFuturo = "registro_no_futuro"
    case menorDeIdade = "menor_de_idade"
    case perfilIncompativel = "perfil_incompativel"
    case selecaoSemAntecedencia = "selecao_sem_antecedencia"
    case vagaOculta = "vaga_oculta"
    case horarioInvalido = "horario_invalido"
    case inelegivel
    case funcaoIncompativel = "funcao_incompativel"
    case avaliacaoIndisponivel = "avaliacao_indisponivel"
    case reaberturaAntesDaTolerancia = "reabertura_antes_da_tolerancia"
    case semSuspensaoAtiva = "sem_suspensao_ativa"
    case contestacaoJaAberta = "contestacao_ja_aberta"
    case limiteExcedido = "limite_excedido"
    case republicacaoIndisponivel = "republicacao_indisponivel"
    case contaSuspensa = "conta_suspensa"
    case verificacaoIndisponivel = "verificacao_indisponivel"
    case evidenciaIncompleta = "evidencia_incompleta"
    case midiaIndisponivel = "midia_indisponivel"
    case midiaInvalida = "midia_invalida"
    case chamadaJaAberta = "chamada_ja_aberta"
    case chamadaIndisponivel = "chamada_indisponivel"
    case recorrenciaNaoConfirmada = "recorrencia_nao_confirmada"
    case profissionalIndisponivel = "profissional_indisponivel"
    case limiteDeChamadas = "limite_de_chamadas"
    case recursoDesligado = "recurso_desligado"
    /// `422`, check-in por código (0.2.68): um código só, sem dizer se estava errado, vencido, de outro
    /// turno ou se a distância passou de 100 m. Cada recusa conta como tentativa errada.
    case codigoInvalido = "codigo_invalido"
    /// `409`, check-in por código (0.2.68): `details` `temporario` ou `encerrado`.
    case codigoBloqueado = "codigo_bloqueado"
    case cursorInvalido = "cursor_invalido"
    case semRede = "sem_rede"
    case respostaInvalida = "resposta_invalida"
    case desconhecido
}

/// Os 6 motivos de recusa da operação republicar_posicoes_restantes (contrato 0.2.41, RR-RN01/03/05).
public enum MotivoRepublicacaoIndisponivel: String, Codable, CaseIterable, Sendable {
    case naoESelecao = "nao_e_selecao"
    case selecaoEmCurso = "selecao_em_curso"
    case vagaCancelada = "vaga_cancelada"
    case jaComecou = "ja_comecou"
    case semPosicoesRestantes = "sem_posicoes_restantes"
    case jaRepublicada = "ja_republicada"
}

/// Quanto o caminho do código está fechado no turno (`409 codigo_bloqueado`, 0.2.68).
public enum BloqueioDoCodigo: String, Equatable, Sendable {
    /// 3 erradas: espere o tempo configurado (hoje 5 minutos).
    case temporario
    /// A sexta errada: o código fecha para o turno, sem nova espera, e vale a confirmação manual.
    case encerrado
}

public extension ErroDaApi {
    /// O bloqueio do `409 codigo_bloqueado`; `nil` em outro erro. Sem `details` conhecido, vale o mais
    /// restritivo (`encerrado`), para o app não prometer uma nova tentativa que o servidor não dá.
    var bloqueioDoCodigo: BloqueioDoCodigo? {
        guard codigo == .codigoBloqueado else { return nil }
        return detalhes.flatMap(BloqueioDoCodigo.init(rawValue:)) ?? .encerrado
    }

    /// `403 sem_permissao` com `details: recurso_desligado` (contrato 0.2.54, RN46): o recurso está
    /// desligado no servidor. O código solto `recurso_desligado` vale o mesmo.
    var recursoDesligado: Bool {
        codigo == .recursoDesligado || (codigo == .semPermissao && detalhes == CodigoErroAPI.recursoDesligado.rawValue)
    }
}

public extension CodigoErroAPI {
    /// Uma publicação com esses erros foi recusada antes de ser criada; repetir a chave não pode
    /// transformar a mesma solicitação em sucesso.
    var recusaDefinitivaDePublicacao: Bool {
        switch self {
        case .campoObrigatorio, .campoInvalido, .horarioInvalido, .funcaoIncompativel,
             .perfilIncompativel, .selecaoSemAntecedencia, .semPermissao, .contaSuspensa,
             .naoEncontrado:
            true
        default:
            false
        }
    }

    /// Esses erros recusam o cancelamento definitivamente e exigem aviso na fila.
    /// Reenvio pelo autor do cancelamento original é sucesso, não 409 (contrato 0.2.35).
    var recusaDefinitivaDeCancelamento: Bool {
        switch self {
        case .posicaoNaoCancelavel, .vagaEncerrada, .naoEncontrado, .campoObrigatorio, .campoInvalido,
             .semPermissao, .perfilIncompativel, .contaSuspensa:
            true
        default:
            false
        }
    }
}

public struct ErroDaApi: Error, Equatable, Sendable {
    public let codigo: CodigoErroAPI
    public let codigoOriginal: String
    public let detalhes: String?

    public init(codigo: CodigoErroAPI, codigoOriginal: String? = nil, detalhes: String? = nil) {
        self.codigo = codigo
        self.codigoOriginal = codigoOriginal ?? codigo.rawValue
        self.detalhes = detalhes
    }
}

public struct EnvelopeErroAPI: Codable, Equatable, Sendable {
    public let code: String
    public let message: String
    public let details: String?
    public let hint: String?

    public init(code: String, message: String, details: String?, hint: String?) {
        self.code = code
        self.message = message
        self.details = details
        self.hint = hint
    }
}
