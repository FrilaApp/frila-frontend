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
    case campoInvalido = "campo_invalido"
    case foraDaJanela = "fora_da_janela"
    case registroNoFuturo = "registro_no_futuro"
    case menorDeIdade = "menor_de_idade"
    case perfilIncompativel = "perfil_incompativel"
    case selecaoSemAntecedencia = "selecao_sem_antecedencia"
    case horarioInvalido = "horario_invalido"
    case inelegivel
    case funcaoIncompativel = "funcao_incompativel"
    case avaliacaoIndisponivel = "avaliacao_indisponivel"
    case reaberturaAntesDaTolerancia = "reabertura_antes_da_tolerancia"
    case semSuspensaoAtiva = "sem_suspensao_ativa"
    case contestacaoJaAberta = "contestacao_ja_aberta"
    case limiteExcedido = "limite_excedido"
    case contaSuspensa = "conta_suspensa"
    case semRede = "sem_rede"
    case respostaInvalida = "resposta_invalida"
    case desconhecido
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
