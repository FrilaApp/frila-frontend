import Foundation

/// Textos da equipe de confiança do estabelecimento (RF18, UC11, cartão #24).
public enum TextosEquipeDeConfianca {
    public static let titulo = String(localized: "Equipe de confiança", bundle: bundleApresentacao)
    public static let explicacao = String(localized: "Quem está na equipe recebe as vagas desta casa mesmo além de 15 km, desde que tenha a função e esteja disponível. Não há exclusividade nem ordem de preferência.", bundle: bundleApresentacao)
    public static let vazioTitulo = String(localized: "Ninguém na equipe ainda", bundle: bundleApresentacao)
    public static let vazioMensagem = String(localized: "Inclua um profissional a partir de um turno que ele já cumpriu aqui.", bundle: bundleApresentacao)
    public static let remover = String(localized: "Remover", bundle: bundleApresentacao)
    public static let confirmarRemocao = String(localized: "Remover da equipe?", bundle: bundleApresentacao)
    public static func efeitoRemocao(_ nome: String) -> String {
        String(localized: "\(nome) deixa de receber as vagas desta casa além de 15 km. Sem penalidade nem aviso.", bundle: bundleApresentacao)
    }
    public static let cancelar = String(localized: "Cancelar", bundle: bundleApresentacao)
    public static let removido = String(localized: "Removido da equipe.", bundle: bundleApresentacao)
    public static let incluir = String(localized: "Incluir na equipe", bundle: bundleApresentacao)
    public static let naEquipe = String(localized: "Na equipe de confiança", bundle: bundleApresentacao)
    public static let semTurnoCumprido = String(localized: "Só dá para incluir quem já cumpriu um turno com presença verificada nesta casa.", bundle: bundleApresentacao)
    public static let soAdministrador = String(localized: "Só o administrador do estabelecimento altera a equipe.", bundle: bundleApresentacao)
    public static let contaSuspensa = String(localized: "Sua conta está suspensa. Enquanto a suspensão durar, a equipe não muda.", bundle: bundleApresentacao)
    public static let indisponivel = String(localized: "Este perfil não está mais disponível.", bundle: bundleApresentacao)
    public static let semRede = String(localized: "Sem conexão. Verifique sua internet e tente novamente.", bundle: bundleApresentacao)
    public static let erroCarregar = String(localized: "Não foi possível carregar a equipe. Tente novamente.", bundle: bundleApresentacao)
    public static let erro = String(localized: "Não foi possível concluir esta ação. Tente novamente.", bundle: bundleApresentacao)
}
