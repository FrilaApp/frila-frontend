import FrilaDominio
import Observation
import SwiftUI

/// O que a lista da equipe mostra. As mensagens já vêm em texto do Frila: a tela não decide texto de erro.
public enum ListaDaEquipe: Equatable, Sendable {
    case carregando
    /// Quem não é administrador não lê a lista: a tela só diz isso, sem botão algum.
    case soAdministrador
    case conteudo([MembroDaCasa])
    case erro(String)
}

/// O que a pessoa vai fazer com alguém da casa, atrás de uma confirmação.
public enum AcaoSobreMembro: Equatable, Sendable {
    case remover
    case transferir
}

/// Uma ação aguardando o "Confirmar". Guarda só o id e o nome, para a folha de confirmação.
public struct ConfirmacaoDeAcaoNaEquipe: Equatable, Sendable {
    public let acao: AcaoSobreMembro
    public let membroID: UUID
    public let nome: String
}

/// O convite gerado: o link, o e-mail e o papel de quem foi convidado, a casa e até quando vale (`nil` se o servidor mandou um
/// instante ilegível). O que a pessoa compartilha ou copia é a `mensagem`, não só o link (B-123, ROPA linha 31, regra 2).
public struct ConviteGerado: Equatable, Sendable {
    public let link: String
    public let email: String
    public let papel: PapelMembro
    public let nomeDaCasa: String
    public let expiraEm: Date?

    public init(link: String, email: String, papel: PapelMembro, nomeDaCasa: String, expiraEm: Date?) {
        self.link = link
        self.email = email
        self.papel = papel
        self.nomeDaCasa = nomeDaCasa
        self.expiraEm = expiraEm
    }

    /// A mensagem do convite, com o link na última linha (veja `TextosDaEquipeDaCasa.mensagemDoConvite`).
    public var mensagem: String {
        let papelEmTexto = papel.rotuloDaEquipe.lowercased(with: FormatadorFrila.locale)
        let enderecoDoConvite = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let texto = if let expiraEm {
            String(format: TextosDaEquipeDaCasa.mensagemDoConvite, nomeDaCasa, papelEmTexto, enderecoDoConvite,
                   FormatadorFrila().dataEHora(expiraEm))
        } else {
            String(format: TextosDaEquipeDaCasa.mensagemDoConviteSemPrazo, nomeDaCasa, papelEmTexto, enderecoDoConvite)
        }
        return "\(texto)\n\(link)"
    }
}

/// Equipe da casa (RF21, US24; contratos 0.2.73 e 0.2.103; paridade com a web, PRs #891 e #916, e com o Android, PR #998):
/// lista de quem faz parte, convite por link, remover e tornar administrador.
///
/// **Quem pode:** só o administrador. Com outro papel, o modelo nem pede a lista e a tela não tem botão algum; o servidor
/// continua sendo a regra. Um `403 sem_permissao` (sem `details`) em qualquer chamada, mesmo depois de a lista ter vindo,
/// quer dizer que a pessoa não é (mais) administradora: caem o papel, a lista, o convite e a confirmação aberta, e nada mais
/// chega ao servidor. Uma recusa que não é 403 (a pessoa já foi removida por outro administrador, por exemplo) relê a lista:
/// a que vale é a do servidor. Quem está na lista como "você" não tem "Remover" nem "Tornar administrador".
///
/// **Convite sem deep link:** `montarLink` monta o link da web do ambiente do app (`<origem>/convite#<token>`); a tela o
/// entrega à folha de compartilhar do sistema. O token nunca vai para log, telemetria nem mensagem de erro, e só vive aqui,
/// na memória deste modelo: nada é guardado no aparelho.
///
/// Um modelo é de uma casa só (`estabelecimentoID`): trocar de casa cria outro, e a resposta que chega depois da troca
/// volta para o modelo antigo, que já saiu da tela.
@MainActor @Observable
public final class EquipeDaCasaViewModel {
    public let estabelecimentoID: UUID
    /// O nome da casa, como a Conta o mostra: entra na mensagem do convite.
    public let nomeDaCasa: String
    /// O papel de quem abriu a tela nesta casa. Só `administrador` lê a lista, convida, remove e transfere.
    public private(set) var papel: PapelMembro?
    public private(set) var lista: ListaDaEquipe

    public var email = "" {
        didSet {
            guard email != oldValue, !reiniciando else { return }
            guard podeGerenciar, !gerandoConvite else { devolver(\.email, a: oldValue); return }
            erroDoEmail = nil
            erroDoConvite = nil
        }
    }
    public var papelConvidado: PapelMembro = .operador {
        didSet {
            guard papelConvidado != oldValue, !reiniciando else { return }
            guard podeGerenciar, !gerandoConvite else { devolver(\.papelConvidado, a: oldValue); return }
            erroDoConvite = nil
        }
    }
    public private(set) var erroDoEmail: String?
    public private(set) var gerandoConvite = false
    public private(set) var convite: ConviteGerado?
    public private(set) var erroDoConvite: String?
    /// Uma pergunta de confirmação aberta.
    public private(set) var pendente: ConfirmacaoDeAcaoNaEquipe?
    /// O `membroID` cuja ação está em voo.
    public private(set) var agindoEm: UUID?
    public private(set) var aviso: String?
    public private(set) var erroDaAcao: String?

    public var podeGerenciar: Bool { papel == .administrador }
    public var ocupado: Bool { gerandoConvite || agindoEm != nil }

    private let listar: @Sendable (UUID) async throws -> [MembroDaCasa]
    private let convidar: @Sendable (UUID, String, PapelMembro) async throws -> ConviteDeMembro
    private let remover: @Sendable (UUID, UUID) async throws -> Void
    private let transferir: @Sendable (UUID, UUID) async throws -> Void
    private let montarLink: (String) -> String?
    private let prazo: Duration
    /// Cada leitura da lista leva um número; só a mais nova escreve na tela.
    private var geracaoDaLeitura = 0
    /// Ligado enquanto o modelo mesmo mexe num campo (limpar ou devolver o valor antigo): o `didSet` não age de novo. Sem isto,
    /// devolver o valor dentro do `didSet` o dispara outra vez (o `@Observable` reenvia a atribuição) e a recusa não acaba.
    private var reiniciando = false

    /// Recusa a edição: o campo volta ao valor que tinha.
    private func devolver<Valor>(_ campo: ReferenceWritableKeyPath<EquipeDaCasaViewModel, Valor>, a valor: Valor) {
        reiniciando = true
        self[keyPath: campo] = valor
        reiniciando = false
    }

    public convenience init(
        api: any ApiCliente, estabelecimentoID: UUID, nomeDaCasa: String, papel: PapelMembro?, origemDaWeb: String = OrigemDaWeb.atual,
        prazo: Duration = .seconds(20)
    ) {
        self.init(
            estabelecimentoID: estabelecimentoID, nomeDaCasa: nomeDaCasa, papel: papel, prazo: prazo,
            listar: { try await api.membrosDaCasa(estabelecimentoID: $0) },
            convidar: { try await api.convidarMembro(estabelecimentoID: $0, email: $1, papel: $2) },
            remover: { try await api.removerMembro(estabelecimentoID: $0, membroID: $1) },
            transferir: { try await api.transferirAdministracao(estabelecimentoID: $0, novoAdministradorID: $1) },
            montarLink: { ConviteDaCasa.link(origem: origemDaWeb, token: $0) }
        )
    }

    public init(
        estabelecimentoID: UUID,
        nomeDaCasa: String,
        papel: PapelMembro?,
        prazo: Duration = .seconds(20),
        listar: @escaping @Sendable (UUID) async throws -> [MembroDaCasa],
        convidar: @escaping @Sendable (UUID, String, PapelMembro) async throws -> ConviteDeMembro,
        remover: @escaping @Sendable (UUID, UUID) async throws -> Void,
        transferir: @escaping @Sendable (UUID, UUID) async throws -> Void,
        montarLink: @escaping (String) -> String?
    ) {
        self.estabelecimentoID = estabelecimentoID
        self.nomeDaCasa = nomeDaCasa
        self.papel = papel
        self.prazo = prazo
        self.listar = listar
        self.convidar = convidar
        self.remover = remover
        self.transferir = transferir
        self.montarLink = montarLink
        lista = papel == .administrador ? .carregando : .soAdministrador
    }

    // MARK: Lista

    /// Lê a lista. Sem efeito para quem não é administrador. `silencioso` relê com a lista antiga na tela (depois de uma ação).
    public func carregar(silencioso: Bool = false) async {
        guard podeGerenciar else { return }
        geracaoDaLeitura += 1
        let minha = geracaoDaLeitura
        if !silencioso { lista = .carregando }
        let leitura = listar
        let casa = estabelecimentoID
        do {
            let membros = try await PrazoDaAbertura.esperar(prazo) { try await leitura(casa) }
            // Uma leitura mais nova já saiu, ou um 403 tirou a administração enquanto esta voltava.
            guard minha == geracaoDaLeitura, podeGerenciar else { return }
            lista = .conteudo(membros)
        } catch {
            guard !Task.isCancelled, minha == geracaoDaLeitura else { return }
            aplicarFalhaDaLeitura(error, silencioso: silencioso)
        }
    }

    private func aplicarFalhaDaLeitura(_ falha: Error, silencioso: Bool) {
        let comListaNaTela: Bool = if case .conteudo = lista { true } else { false }
        guard let erro = falha as? ErroDaApi else {
            // Corpo ilegível ou campo ausente escapam do `ErroDaApi`; sem isto a tela ficaria em "carregando".
            if !(silencioso && comListaNaTela) { lista = .erro(TextosDaEquipeDaCasa.erroDaLista) }
            return
        }
        if erro.recusaDeAdministrador {
            // 403 sem `details`: a pessoa não é (mais) administradora. Somem a lista e as ações.
            semAcessoDeAdministrador()
        } else if erro.contaSuspensa {
            // Conta suspensa: nada da casa se administra agora; a lista antiga não fica na tela.
            lista = .erro(TextosDaEquipeDaCasa.contaSuspensa)
        } else if !(silencioso && comListaNaTela) {
            // Com a lista antiga na tela, a falha da releitura não a apaga.
            lista = .erro(Self.mensagemDaLista(erro))
        }
    }

    // MARK: Convidar

    /// Valida o e-mail e gera o convite. Sem efeito para quem não é administrador e durante outra chamada.
    public func gerarConvite() async {
        guard podeGerenciar, !ocupado else { return }
        let limpo = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.emailValido(limpo) else {
            erroDoEmail = TextosDaEquipeDaCasa.emailInvalido
            erroDoConvite = nil
            return
        }
        let convidado = papelConvidado
        gerandoConvite = true
        erroDoEmail = nil
        erroDoConvite = nil
        aviso = nil
        erroDaAcao = nil
        convite = nil
        let chamada = convidar
        let casa = estabelecimentoID
        do {
            let gerado = try await PrazoDaAbertura.esperar(prazo) { try await chamada(casa, limpo, convidado) }
            guard podeGerenciar else { return }
            // O link só sai se o token tem o formato do contrato (64 hexadecimais).
            guard let link = montarLink(gerado.token) else {
                gerandoConvite = false
                erroDoConvite = TextosDaEquipeDaCasa.erro
                return
            }
            gerandoConvite = false
            email = ""
            convite = ConviteGerado(link: link, email: limpo, papel: convidado, nomeDaCasa: nomeDaCasa, expiraEm: gerado.expiraEm)
        } catch {
            guard !Task.isCancelled else { gerandoConvite = false; return }
            if let erro = error as? ErroDaApi, erro.recusaDeAdministrador {
                semAcessoDeAdministrador(erroDoConvite: TextosDaEquipeDaCasa.soAdministrador)
            } else if let erro = error as? ErroDaApi {
                gerandoConvite = false
                aplicarErroDoConvite(erro)
            } else {
                gerandoConvite = false
                erroDoConvite = TextosDaEquipeDaCasa.erro
            }
        }
    }

    private func aplicarErroDoConvite(_ erro: ErroDaApi) {
        if erro.codigo == .campoInvalido, erro.detalhes == "email" {
            erroDoEmail = TextosDaEquipeDaCasa.emailInvalido
        } else if erro.codigo == .campoObrigatorio || erro.codigo == .campoInvalido, erro.detalhes == "papel" {
            erroDoConvite = TextosDaEquipeDaCasa.papelInvalido
        } else {
            erroDoConvite = Self.mensagemDaAcao(erro)
        }
    }

    // MARK: Remover e tornar administrador

    /// Abre a confirmação. Remover e transferir não valem para a linha de "você" nem para quem tem um papel que o app não conhece,
    /// e só um operador vira administrador.
    public func pedirConfirmacao(_ acao: AcaoSobreMembro, membro: MembroDaCasa) {
        guard podeGerenciar, !ocupado, !membro.eVoce, membro.papelConhecido else { return }
        if acao == .transferir, membro.papel == .administrador { return }
        pendente = ConfirmacaoDeAcaoNaEquipe(acao: acao, membroID: membro.id, nome: membro.nome)
        erroDaAcao = nil
    }

    public func cancelarConfirmacao() {
        pendente = nil
    }

    /// Executa a ação confirmada. Depois do sucesso a lista é relida; a recusa do servidor vira mensagem.
    public func confirmar() async {
        guard let acao = pendente, podeGerenciar, !ocupado else { return }
        pendente = nil
        agindoEm = acao.membroID
        aviso = nil
        erroDaAcao = nil
        let removerDaCasa = remover
        let transferirNaCasa = transferir
        let casa = estabelecimentoID
        do {
            try await PrazoDaAbertura.esperar(prazo) {
                switch acao.acao {
                case .remover: try await removerDaCasa(casa, acao.membroID)
                case .transferir: try await transferirNaCasa(casa, acao.membroID)
                }
            }
            guard podeGerenciar else { return }
            agindoEm = nil
            aviso = acao.acao == .remover ? TextosDaEquipeDaCasa.removida : TextosDaEquipeDaCasa.transferida
            await carregar(silencioso: true)
        } catch {
            guard !Task.isCancelled else { agindoEm = nil; return }
            if let erro = error as? ErroDaApi, erro.recusaDeAdministrador {
                semAcessoDeAdministrador(erroDaAcao: TextosDaEquipeDaCasa.soAdministrador)
                return
            }
            agindoEm = nil
            erroDaAcao = (error as? ErroDaApi).map(Self.mensagemDaAcao) ?? TextosDaEquipeDaCasa.erro
            // A ação recusada, ou de resultado incerto, pode ter perdido o sentido (quem foi removido por outro
            // administrador, por exemplo): a lista que vale é a do servidor.
            await carregar(silencioso: true)
        }
    }

    // MARK: Perda da administração

    /// Depois de um 403 a tela deixa de se comportar como administradora: o papel que ela tinha cai, a lista, o convite e a
    /// confirmação aberta somem, e nenhuma ação chega mais ao servidor. A mensagem certa é a do "só o administrador".
    private func semAcessoDeAdministrador(erroDoConvite: String? = nil, erroDaAcao: String? = nil) {
        papel = nil
        lista = .soAdministrador
        reiniciando = true
        email = ""
        reiniciando = false
        erroDoEmail = nil
        gerandoConvite = false
        convite = nil
        pendente = nil
        agindoEm = nil
        aviso = nil
        self.erroDoConvite = erroDoConvite
        self.erroDaAcao = erroDaAcao
        geracaoDaLeitura += 1
    }

    // MARK: Mensagens

    private static func mensagemDaLista(_ erro: ErroDaApi) -> String {
        if erro.contaSuspensa { return TextosDaEquipeDaCasa.contaSuspensa }
        if erro.codigo == .naoAutenticado { return TextosDaEquipeDaCasa.sessao }
        if erro.codigo == .semRede { return TextosDaEquipeDaCasa.semRede }
        return TextosDaEquipeDaCasa.erroDaLista
    }

    /// As recusas de convidar, remover e transferir, em texto do Frila. `403 sem_permissao` sem `details` é "não é administrador".
    private static func mensagemDaAcao(_ erro: ErroDaApi) -> String {
        if erro.contaSuspensa { return TextosDaEquipeDaCasa.contaSuspensa }
        if erro.codigo == .semPermissao { return TextosDaEquipeDaCasa.soAdministrador }
        if erro.ultimoAdministrador { return TextosDaEquipeDaCasa.ultimoAdministrador }
        if erro.codigo == .naoEncontrado { return TextosDaEquipeDaCasa.indisponivel }
        if erro.codigo == .naoAutenticado { return TextosDaEquipeDaCasa.sessao }
        if erro.codigo == .semRede { return TextosDaEquipeDaCasa.semRede }
        return TextosDaEquipeDaCasa.erro
    }

    /// Formato de e-mail que o servidor também confere: `algo@algo.algo`, sem espaço.
    static func emailValido(_ texto: String) -> Bool {
        let partes = texto.split(separator: "@", omittingEmptySubsequences: false)
        guard partes.count == 2, !partes[0].isEmpty, !texto.contains(where: \.isWhitespace) else { return false }
        let dominio = partes[1].split(separator: ".", omittingEmptySubsequences: false)
        return dominio.count >= 2 && dominio.allSatisfy { !$0.isEmpty }
    }
}
