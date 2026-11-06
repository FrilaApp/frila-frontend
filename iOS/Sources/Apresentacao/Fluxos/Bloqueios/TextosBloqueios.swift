import Foundation

/// Textos da tela e ações de bloqueio e desbloqueio (RF26, decisão A8 da PO, v0.2.51).
public enum TextosBloqueios {
    public static let titulo = String(localized: "Pessoas e locais bloqueados", bundle: bundleApresentacao)
    public static let explicacao = String(localized: "Pessoas e estabelecimentos que você bloqueou. Ao desbloquear, vocês voltam a se cruzar em vagas, notificações e candidaturas.", bundle: bundleApresentacao)
    public static let vazioTitulo = String(localized: "Nenhum bloqueio ativo", bundle: bundleApresentacao)
    public static let vazioMensagem = String(localized: "Quando você bloquear uma pessoa ou um estabelecimento, eles aparecerão aqui.", bundle: bundleApresentacao)
    public static let desbloquear = String(localized: "Desbloquear", bundle: bundleApresentacao)
    public static let confirmarDesbloqueio = String(localized: "Desbloquear este perfil?", bundle: bundleApresentacao)
    public static func efeitoDesbloqueio(_ nome: String) -> String {
        String(localized: "Ao desbloquear \(nome), vocês voltam a se cruzar em notificações, listas e candidaturas.", bundle: bundleApresentacao)
    }
    public static let efeitoDesbloqueioGeral = String(localized: "Vocês voltam a se cruzar em notificações, listas e candidaturas.", bundle: bundleApresentacao)
    public static let cancelar = String(localized: "Cancelar", bundle: bundleApresentacao)
    public static let tipoProfissional = String(localized: "Profissional", bundle: bundleApresentacao)
    public static let tipoEstabelecimento = String(localized: "Estabelecimento", bundle: bundleApresentacao)
    public static let semRede = String(localized: "Sem conexão. Verifique sua internet e tente novamente.", bundle: bundleApresentacao)
    public static let avisoOffline = String(localized: "Sem conexão. Mostrando os bloqueios salvos neste aparelho.", bundle: bundleApresentacao)
    public static let erroCarregar = String(localized: "Não foi possível carregar os bloqueios. Tente novamente.", bundle: bundleApresentacao)
    public static let erroDesbloquear = String(localized: "Não foi possível desfazer o bloqueio. Tente novamente.", bundle: bundleApresentacao)
}
