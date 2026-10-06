import Foundation

/// Textos da tela "Por que recebo vagas" (RF27). O título e o texto explicativo aprovado ficam em
/// `TextosPerfilConta`, de onde a tela sempre partiu.
public enum TextosPorQueReceboVagas {
    public static let secaoFuncao = String(localized: "Sua função", bundle: bundleApresentacao)
    public static let semFuncao = String(localized: "Nenhuma função cadastrada.", bundle: bundleApresentacao)
    public static let secaoHorarios = String(localized: "Seus horários", bundle: bundleApresentacao)
    public static let horariosExplicacao = String(localized: "A vaga só chega quando o turno inteiro cabe em um destes horários.", bundle: bundleApresentacao)
    public static let semHorarios = String(localized: "Nenhum horário cadastrado. Sem horários, nenhuma vaga chega por notificação.", bundle: bundleApresentacao)
    public static let secaoDistancia = String(localized: "Distância", bundle: bundleApresentacao)
    public static func distancia(_ km: String) -> String {
        String(localized: "Até \(km) km do seu ponto base.", bundle: bundleApresentacao)
    }
    public static let secaoEquipes = String(localized: "Equipes de confiança", bundle: bundleApresentacao)
    public static let equipesExplicacao = String(localized: "As vagas destes estabelecimentos chegam mesmo além da distância máxima, desde que a função e os horários batam.", bundle: bundleApresentacao)
    public static let semEquipes = String(localized: "Você ainda não faz parte da equipe de confiança de nenhum estabelecimento.", bundle: bundleApresentacao)
    public static let secaoFrequencia = String(localized: "Frequência", bundle: bundleApresentacao)
    public static func frequencia(_ minutos: Int) -> String {
        String(localized: "No máximo uma notificação a cada \(minutos) minutos.", bundle: bundleApresentacao)
    }
    public static let vazioTitulo = String(localized: "Nenhum critério cadastrado", bundle: bundleApresentacao)
    public static let vazioMensagem = String(localized: "Cadastre sua função e seus horários em Funções e horários para começar a receber vagas.", bundle: bundleApresentacao)
    public static let erroSemRede = String(localized: "Sem conexão. Verifique sua internet e tente novamente.", bundle: bundleApresentacao)
    public static let erroCarregar = String(localized: "Não foi possível carregar seus critérios. Tente novamente.", bundle: bundleApresentacao)

    public static let secaoContestar = String(localized: "Algo não bate?", bundle: bundleApresentacao)
    public static let contestarExplicacao = String(localized: "Se você acha que deveria ter recebido uma vaga, peça a revisão. A Equipe Frila responde por e-mail em até 5 dias úteis.", bundle: bundleApresentacao)
    public static let botaoContestar = String(localized: "Contestar", bundle: bundleApresentacao)
    public static let labelRelato = String(localized: "O que aconteceu", bundle: bundleApresentacao)
    public static let promptRelato = String(localized: "Conte qual vaga esperava receber e por quê…", bundle: bundleApresentacao)
    public static let dicaRelato = String(localized: "Mínimo de 10 caracteres.", bundle: bundleApresentacao)
    public static let botaoEnviar = String(localized: "Enviar pedido", bundle: bundleApresentacao)
    public static let cancelar = String(localized: "Cancelar", bundle: bundleApresentacao)
    public static let pedidoEnviado = String(localized: "Pedido de revisão enviado", bundle: bundleApresentacao)
    public static let protocoloNumero = String(localized: "Número do protocolo", bundle: bundleApresentacao)
    public static let protocoloData = String(localized: "Enviado em", bundle: bundleApresentacao)
    public static let prazoRespostaTitulo = String(localized: "Previsão de resposta até", bundle: bundleApresentacao)
    public static let mensagemEnviado = String(localized: "A Equipe Frila vai responder por e-mail dentro do prazo informado.", bundle: bundleApresentacao)
    public static let relatoObrigatorio = String(localized: "Conte o que aconteceu antes de enviar.", bundle: bundleApresentacao)
    public static let relatoMinimo = String(localized: "O relato deve conter pelo menos 10 caracteres.", bundle: bundleApresentacao)
    public static let contaSuspensa = String(localized: "Sua conta está suspensa. Enquanto a suspensão durar, não é possível pedir a revisão.", bundle: bundleApresentacao)
    public static let limiteExcedido = String(localized: "Muitos pedidos em pouco tempo. Aguarde alguns minutos e tente de novo.", bundle: bundleApresentacao)
    public static let erroEnviar = String(localized: "Não foi possível enviar o pedido. Tente novamente.", bundle: bundleApresentacao)
}
