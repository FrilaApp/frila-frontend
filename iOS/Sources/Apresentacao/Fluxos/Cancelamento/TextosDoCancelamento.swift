// VISUAL PROVISÓRIO: o design de alta fidelidade do cancelamento ainda não chegou (#20).

import FrilaDominio
import Foundation

/// Textos da folha de cancelamento (#20). Tom neutro: dizem o efeito, nunca sugerem punição.
enum TextosDoCancelamento {
    static let tituloTurno = String(localized: "Cancelar turno", bundle: bundleApresentacao)
    static let tituloPosicao = String(localized: "Cancelar posição", bundle: bundleApresentacao)
    static let tituloVaga = String(localized: "Cancelar vaga", bundle: bundleApresentacao)
    static let motivoTitulo = String(localized: "Qual é o motivo?", bundle: bundleApresentacao)
    static let motivoObrigatorio = String(localized: "Escolha um motivo para continuar.", bundle: bundleApresentacao)
    static let detalhesTitulo = String(localized: "Quer explicar melhor? (opcional)", bundle: bundleApresentacao)
    static let detalhesObrigatorios = String(localized: "Descreva o motivo (pelo menos 3 caracteres)", bundle: bundleApresentacao)
    static let confirmar = String(localized: "Confirmar cancelamento", bundle: bundleApresentacao)
    static let voltar = String(localized: "Voltar", bundle: bundleApresentacao)
    static let fechar = String(localized: "Fechar", bundle: bundleApresentacao)
    static let ok = String(localized: "OK", bundle: bundleApresentacao)
    static let recolherTeclado = String(localized: "Recolher teclado", bundle: bundleApresentacao)
    static let enviando = String(localized: "Enviando o cancelamento…", bundle: bundleApresentacao)

    // Avisos antes do toque, pela antecedência (RN12)
    static let faltamParaOInicio = String(localized: "Faltam %@ para o início.", bundle: bundleApresentacao)
    static let menosDeUmaHora = String(localized: "menos de 1 h", bundle: bundleApresentacao)
    static let horas = String(localized: "%d h", bundle: bundleApresentacao)
    static let turnoJaComecou = String(localized: "O turno já começou.", bundle: bundleApresentacao)
    static let profissionalComFalta = String(localized: "Este cancelamento conta como falta na sua taxa de comparecimento.", bundle: bundleApresentacao)
    static let profissionalSemFalta = String(localized: "Este cancelamento não afeta sua taxa de comparecimento.", bundle: bundleApresentacao)
    static let profissionalReabre = String(localized: "A vaga volta a ser oferecida a outros profissionais.", bundle: bundleApresentacao)
    static let profissionalNaoReabre = String(localized: "A posição não será reaberta: o turno fica descoberto.", bundle: bundleApresentacao)
    static let contratanteSemFalta = String(localized: "Não conta como falta para o profissional.", bundle: bundleApresentacao)
    static let contratanteReabre = String(localized: "A posição volta a ser oferecida a outros profissionais, e quem estava confirmado será avisado.", bundle: bundleApresentacao)
    static let contratanteNaoReabre = String(localized: "A posição não será reaberta: o turno fica descoberto, e quem estava confirmado será avisado.", bundle: bundleApresentacao)
    static let vagaInteira = String(localized: "Todas as posições serão canceladas, e os profissionais confirmados serão avisados. Não conta como falta para ninguém.", bundle: bundleApresentacao)
    static let vagaInteiraComecada = String(localized: "Todas as posições serão canceladas, sem reabertura, e os profissionais confirmados serão avisados. Não conta como falta para ninguém.", bundle: bundleApresentacao)

    // Desfecho
    static let turnoCanceladoReaberto = String(localized: "Turno cancelado. A vaga voltou a ser oferecida a outros profissionais.", bundle: bundleApresentacao)
    static let turnoCanceladoDescoberto = String(localized: "Turno cancelado. O turno ficou descoberto, e o estabelecimento foi avisado.", bundle: bundleApresentacao)
    static let posicaoCanceladaReaberta = String(localized: "Posição cancelada. Ela voltou a ser oferecida a outros profissionais.", bundle: bundleApresentacao)
    static let posicaoCanceladaDescoberta = String(localized: "Posição cancelada. O turno ficou descoberto: depois do início não há reabertura.", bundle: bundleApresentacao)
    static let vagaCancelada = String(localized: "Vaga cancelada. Os profissionais confirmados foram avisados.", bundle: bundleApresentacao)
    static let naFila = String(localized: "Sem conexão. O cancelamento será enviado quando a internet voltar.", bundle: bundleApresentacao)
    static let semRedeSemFila = String(localized: "Sem conexão. O cancelamento não foi enviado; tente de novo quando a internet voltar.", bundle: bundleApresentacao)
    static let falhaAoGuardar = String(localized: "Sem conexão, e não foi possível guardar o cancelamento neste aparelho. Tente de novo.", bundle: bundleApresentacao)
    static let falhaGenerica = String(localized: "Não foi possível cancelar. Tente de novo.", bundle: bundleApresentacao)
    static let posicaoNaoCancelavel = String(localized: "Esta posição não pode mais ser cancelada. Atualize a tela para ver como ela está.", bundle: bundleApresentacao)
    static let vagaJaFechada = String(localized: "Esta vaga já foi cancelada ou encerrada.", bundle: bundleApresentacao)
    // Provisório, até o texto final do #20: o filtro de termos da diretriz 1.2 recusou o motivo
    // (`422 campo_invalido`, `details: motivo`). Mandar de novo não adianta; é preciso reescrever.
    static let motivoRecusado = String(localized: "O motivo tem termos que o Frila não aceita. Reescreva com outras palavras e confirme de novo.", bundle: bundleApresentacao)

    static func titulo(lado: LadoDoCancelamento, alvo: AlvoDoCancelamento) -> String {
        switch (lado, alvo) {
        case (.profissional, _): tituloTurno
        case (.contratante, .posicao): tituloPosicao
        case (.contratante, .vaga): tituloVaga
        }
    }

    static func motivo(_ motivo: MotivoDeCancelamento) -> String {
        switch motivo {
        case .saude: String(localized: "Problema de saúde", bundle: bundleApresentacao)
        case .imprevistoPessoal: String(localized: "Imprevisto pessoal", bundle: bundleApresentacao)
        case .deslocamento: String(localized: "Não consigo chegar ao local", bundle: bundleApresentacao)
        case .outroCompromisso: String(localized: "Surgiu outro compromisso", bundle: bundleApresentacao)
        case .movimentoMenor: String(localized: "Movimento menor que o esperado", bundle: bundleApresentacao)
        case .posicaoPreenchidaFora: String(localized: "A posição foi preenchida de outra forma", bundle: bundleApresentacao)
        case .mudancaDePlanos: String(localized: "O evento ou o turno mudou", bundle: bundleApresentacao)
        case .problemaNoLocal: String(localized: "Problema no estabelecimento", bundle: bundleApresentacao)
        case .outro: String(localized: "Outro motivo", bundle: bundleApresentacao)
        }
    }

    /// Horas inteiras até o início, para baixo: a 23 h 30 min o aviso diz "23 h" junto com a falta, e
    /// nunca "24 h" (RN12). Abaixo de uma hora, "menos de 1 h".
    static func tempoAteOInicio(_ antecedencia: TimeInterval) -> String {
        guard antecedencia >= 60 * 60 else { return menosDeUmaHora }
        return String(format: horas, Int(floor(antecedencia / 3600)))
    }

    static func aviso(lado: LadoDoCancelamento, alvo: AlvoDoCancelamento, antecedencia: TimeInterval, contaComoFalta: Bool) -> String {
        let comecou = antecedencia <= 0
        let quando = comecou ? turnoJaComecou : String(format: faltamParaOInicio, tempoAteOInicio(antecedencia))
        let efeito: [String]
        switch (lado, alvo) {
        case (.profissional, _):
            efeito = [contaComoFalta ? profissionalComFalta : profissionalSemFalta, comecou ? profissionalNaoReabre : profissionalReabre]
        case (.contratante, .posicao):
            efeito = [comecou ? contratanteNaoReabre : contratanteReabre, contratanteSemFalta]
        case (.contratante, .vaga):
            efeito = [comecou ? vagaInteiraComecada : vagaInteira]
        }
        return ([quando] + efeito).joined(separator: " ")
    }

    static func desfecho(_ desfecho: DesfechoDoCancelamento, lado: LadoDoCancelamento) -> String {
        switch desfecho {
        case let .posicao(resultado):
            switch lado {
            case .profissional: resultado.reaberta ? turnoCanceladoReaberto : turnoCanceladoDescoberto
            case .contratante: resultado.reaberta ? posicaoCanceladaReaberta : posicaoCanceladaDescoberta
            }
        case .vaga: vagaCancelada
        case .naFila: naFila
        }
    }

    static func falha(_ erro: ErroDaApi) -> String {
        switch erro.codigo {
        case .posicaoNaoCancelavel: posicaoNaoCancelavel
        case .vagaEncerrada: vagaJaFechada
        case .campoInvalido where erro.detalhes == "motivo": motivoRecusado
        default: MensagemDoErroAPI.texto(erro)
        }
    }
}
