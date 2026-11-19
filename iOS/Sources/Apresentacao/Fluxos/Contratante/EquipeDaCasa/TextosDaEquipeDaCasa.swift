import Foundation

/// Os textos da equipe da casa, do convite por link e da troca de casa (pedido 18-02; contratos 0.2.73 e 0.2.103).
/// Paridade de conteúdo com a web (`contratante-membros.ts`) e com o Android.
enum TextosDaEquipeDaCasa {
    // Entradas (Conta)
    static let entradaEquipe = String(localized: "Equipe da casa", bundle: bundleApresentacao)
    static let entradaConvite = String(localized: "Tenho um convite", bundle: bundleApresentacao)
    static let entradaTrocar = String(localized: "Trocar de casa", bundle: bundleApresentacao)

    // Equipe da casa
    static let titulo = String(localized: "Equipe da casa", bundle: bundleApresentacao)
    static let explicacao = String(localized: "Quem você convidar entra com o próprio e-mail e passa a usar o Frila por esta casa, como administrador ou operador.", bundle: bundleApresentacao)
    static let soAdministrador = String(localized: "Só o administrador da casa gerencia as pessoas.", bundle: bundleApresentacao)
    static let lista = String(localized: "Quem faz parte da casa", bundle: bundleApresentacao)
    static let vazia = String(localized: "Nenhuma pessoa na lista da casa.", bundle: bundleApresentacao)
    static let voce = String(localized: "Você", bundle: bundleApresentacao)
    static let desde = String(localized: "Desde %@", bundle: bundleApresentacao)
    static let papelAdministrador = String(localized: "Administrador", bundle: bundleApresentacao)
    static let papelOperador = String(localized: "Operador", bundle: bundleApresentacao)
    static let papelDesconhecido = String(localized: "Outro papel", bundle: bundleApresentacao)

    // Convidar
    static let convidar = String(localized: "Convidar alguém", bundle: bundleApresentacao)
    static let email = String(localized: "E-mail de quem você vai convidar", bundle: bundleApresentacao)
    static let emailExemplo = String(localized: "nome@exemplo.com", bundle: bundleApresentacao)
    static let papel = String(localized: "Papel de quem entra", bundle: bundleApresentacao)
    static let gerarConvite = String(localized: "Gerar convite", bundle: bundleApresentacao)
    static let gerando = String(localized: "Gerando…", bundle: bundleApresentacao)
    static let convitePronto = String(localized: "Convite pronto. Mande o link à pessoa. Ele vale uma vez, até %@.", bundle: bundleApresentacao)
    static let conviteProntoSemPrazo = String(localized: "Convite pronto. Mande o link à pessoa. Ele vale uma vez.", bundle: bundleApresentacao)
    static let convitePara = String(localized: "Convite para %@", bundle: bundleApresentacao)
    static let linkDoConvite = String(localized: "Link do convite", bundle: bundleApresentacao)
    static let compartilhar = String(localized: "Compartilhar convite", bundle: bundleApresentacao)
    static let compartilharTitulo = String(localized: "Convite para a casa no Frila", bundle: bundleApresentacao)

    // Ações sobre a pessoa
    static let remover = String(localized: "Remover", bundle: bundleApresentacao)
    static let removerDe = String(localized: "Remover %@", bundle: bundleApresentacao)
    static let transferir = String(localized: "Tornar administrador", bundle: bundleApresentacao)
    static let transferirDe = String(localized: "Tornar %@ administrador", bundle: bundleApresentacao)
    static let confirmarRemocao = String(localized: "Remover esta pessoa?", bundle: bundleApresentacao)
    static let efeitoRemocao = String(localized: "%@ deixará de ter acesso a esta casa.", bundle: bundleApresentacao)
    static let confirmarTransferencia = String(localized: "Tornar administrador?", bundle: bundleApresentacao)
    static let efeitoTransferencia = String(localized: "%@ poderá administrar a casa. Seu acesso não é removido por esta ação.", bundle: bundleApresentacao)
    static let cancelar = String(localized: "Cancelar", bundle: bundleApresentacao)
    static let removida = String(localized: "Pessoa removida da casa.", bundle: bundleApresentacao)
    static let transferida = String(localized: "A pessoa agora é administradora da casa.", bundle: bundleApresentacao)

    // Erros
    static let emailInvalido = String(localized: "Informe um e-mail válido.", bundle: bundleApresentacao)
    static let papelInvalido = String(localized: "Escolha o papel.", bundle: bundleApresentacao)
    static let contaSuspensa = String(localized: "Sua conta está suspensa. Não é possível gerenciar as pessoas da casa agora.", bundle: bundleApresentacao)
    static let indisponivel = String(localized: "Esta casa ou pessoa não está mais disponível. Reabra a lista.", bundle: bundleApresentacao)
    static let ultimoAdministrador = String(localized: "Não é possível remover o último administrador. Torne outra pessoa administradora antes.", bundle: bundleApresentacao)
    static let sessao = String(localized: "Sua sessão expirou. Entre de novo.", bundle: bundleApresentacao)
    static let semRede = String(localized: "Sem conexão. Verifique sua internet e tente novamente.", bundle: bundleApresentacao)
    static let erro = String(localized: "Não foi possível concluir agora. Tente novamente.", bundle: bundleApresentacao)
    static let erroDaLista = String(localized: "Não foi possível ler as pessoas da casa.", bundle: bundleApresentacao)

    // Tenho um convite
    static let conviteTitulo = String(localized: "Tenho um convite", bundle: bundleApresentacao)
    static let conviteExplicacao = String(localized: "Cole aqui o link do convite que você recebeu.", bundle: bundleApresentacao)
    static let conviteCampo = String(localized: "Link ou código do convite", bundle: bundleApresentacao)
    static let conviteExemplo = String(localized: "Cole o link ou o código", bundle: bundleApresentacao)
    static let conviteAceitar = String(localized: "Aceitar convite", bundle: bundleApresentacao)
    static let conviteAceitando = String(localized: "Aceitando…", bundle: bundleApresentacao)
    static let conviteAceitoTitulo = String(localized: "Convite aceito", bundle: bundleApresentacao)
    static let conviteAceito = String(localized: "Você agora faz parte da casa como %@.", bundle: bundleApresentacao)
    static let conviteAceitoSemPapel = String(localized: "Você agora faz parte da casa.", bundle: bundleApresentacao)
    static let conviteAbrirCasa = String(localized: "Abrir a casa", bundle: bundleApresentacao)
    static let conviteFormatoInvalido = String(localized: "Link ou código inválido. Cole o link inteiro do convite, ou só o código, sem mais nada.", bundle: bundleApresentacao)
    static let conviteInvalido = String(localized: "Este convite não vale mais: já foi usado, venceu ou o código está errado. Peça um novo a quem convidou.", bundle: bundleApresentacao)
    static let convitePerfilIncompativel = String(localized: "Convites de casa são para contas de quem contrata. A sua conta é de profissional.", bundle: bundleApresentacao)
    static let conviteIncerto = String(localized: "Não foi possível confirmar agora. Tente de novo; se o convite já tiver sido aceito, a casa aparece na sua conta.", bundle: bundleApresentacao)

    // Trocar de casa
    static let trocarTitulo = String(localized: "Trocar de casa", bundle: bundleApresentacao)
    static let trocarExplicacao = String(localized: "Escolha de qual casa você quer cuidar agora.", bundle: bundleApresentacao)
    static let trocarFalha = String(localized: "Não foi possível carregar suas casas.", bundle: bundleApresentacao)
    static let tentarNovamente = String(localized: "Tentar novamente", bundle: bundleApresentacao)
}
