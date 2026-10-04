import Foundation
import FrilaDominio

/// Textos provisórios do cartão #39, para validação do Cauê.
enum TextosDaSeguranca {
    static let denunciar = String(localized: "Denunciar", bundle: bundleApresentacao)
    static let bloquear = String(localized: "Bloquear", bundle: bundleApresentacao)
    static let voceBloqueouProfissional = String(localized: "Você bloqueou este profissional", bundle: bundleApresentacao)
    static let voceBloqueouEstabelecimento = String(localized: "Você bloqueou este estabelecimento", bundle: bundleApresentacao)
    static let ok = String(localized: "OK", bundle: bundleApresentacao)
    static let recolherTeclado = String(localized: "Recolher teclado", bundle: bundleApresentacao)
    static let confirmarBloqueio = String(localized: "Bloquear este perfil?", bundle: bundleApresentacao)
    static let efeitoBloqueio = String(localized: "Vocês não voltam a se cruzar em notificações, listas ou candidaturas. O bloqueio vale para todo o estabelecimento.", bundle: bundleApresentacao)
    static let cancelar = String(localized: "Cancelar", bundle: bundleApresentacao)
    static let fechar = String(localized: "Fechar", bundle: bundleApresentacao)
    static let motivo = String(localized: "Motivo da denúncia", bundle: bundleApresentacao)
    static let relato = String(localized: "Relato", bundle: bundleApresentacao)
    static let relatoMinimo = String(localized: "O relato deve conter pelo menos 10 caracteres.", bundle: bundleApresentacao)
    static let enviar = String(localized: "Enviar denúncia", bundle: bundleApresentacao)
    static let emergencia = String(localized: "Em risco imediato, ligue 190 (Polícia Militar) ou 180 (Central de Atendimento à Mulher)", bundle: bundleApresentacao)
    static let policia = String(localized: "Ligar 190 — Polícia Militar", bundle: bundleApresentacao)
    static let mulher = String(localized: "Ligar 180 — Central de Atendimento à Mulher", bundle: bundleApresentacao)
    static let enviada = String(localized: "Denúncia enviada", bundle: bundleApresentacao)
    static let protocolo = String(localized: "Número do protocolo", bundle: bundleApresentacao)
    static let prazo = String(localized: "Resposta por e-mail até", bundle: bundleApresentacao)
    static let perfil = String(localized: "Perfil público", bundle: bundleApresentacao)
    static let verPerfil = String(localized: "Ver perfil público", bundle: bundleApresentacao)
    static let indisponivel = String(localized: "Perfil indisponível", bundle: bundleApresentacao)
    static let tentar = String(localized: "Tentar novamente", bundle: bundleApresentacao)
    static let erro = String(localized: "Não foi possível concluir esta ação. Tente novamente.", bundle: bundleApresentacao)
    static let semRede = String(localized: "Sem conexão. Verifique sua internet e tente novamente.", bundle: bundleApresentacao)
    static let dadosInvalidos = String(localized: "Não foi possível enviar estes dados. Confira as informações e tente novamente.", bundle: bundleApresentacao)
    static func nome(_ motivo: MotivoDenuncia) -> String {
        switch motivo {
        case .assedio: String(localized: "Assédio", bundle: bundleApresentacao)
        case .discriminacao: String(localized: "Discriminação", bundle: bundleApresentacao)
        case .riscoSeguranca: String(localized: "Risco à segurança", bundle: bundleApresentacao)
        case .outro: String(localized: "Outro", bundle: bundleApresentacao)
        }
    }
}
