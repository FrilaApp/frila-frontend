@testable import FrilaApresentacao
import Foundation
import FrilaDominio
import Testing

/// O servidor de mentira da equipe da casa: o que chegou a cada chamada e o que ele vai responder.
private actor ServidorDaEquipe {
    private var listas: [Result<[MembroDaCasa], Error>]
    private(set) var leituras = 0
    private(set) var convites: [(casa: UUID, email: String, papel: PapelMembro)] = []
    private(set) var removidos: [UUID] = []
    private(set) var transferidos: [UUID] = []
    var respostaDoConvite: Result<ConviteDeMembro, Error> = .success(ConviteDeMembro(token: String(repeating: "ef", count: 32), expiraEm: nil))
    var respostaDaAcao: Result<Void, Error> = .success(())
    /// A primeira leitura espera aqui até o teste liberar: a resposta que chega depois de outra mais nova.
    private var porteiraDaPrimeiraLeitura: Porteira?
    /// Quanto tempo a ação demora (para o prazo).
    var demoraDaAcao: Duration?
    var demoraDaLeitura: Duration?

    init(_ listas: [Result<[MembroDaCasa], Error>]) { self.listas = listas }

    func trocarRespostaDoConvite(_ resposta: Result<ConviteDeMembro, Error>) { respostaDoConvite = resposta }
    func trocarRespostaDaAcao(_ resposta: Result<Void, Error>) { respostaDaAcao = resposta }
    func trocarDemoraDaAcao(_ demora: Duration?) { demoraDaAcao = demora }
    func trocarDemoraDaLeitura(_ demora: Duration?) { demoraDaLeitura = demora }
    func segurarPrimeiraLeitura(_ porteira: Porteira) { porteiraDaPrimeiraLeitura = porteira }

    func listar() async throws -> [MembroDaCasa] {
        leituras += 1
        let numero = leituras
        // A resposta é a da vez em que a chamada chegou, mesmo que ela espere a porteira: a última se repete quando as combinadas acabam.
        let resposta = listas.count > 1 ? listas.removeFirst() : (listas.first ?? .success([]))
        if numero == 1, let porteira = porteiraDaPrimeiraLeitura { await porteira.esperar() }
        if let demoraDaLeitura { try await Task.sleep(for: demoraDaLeitura) }
        return try resposta.get()
    }

    func convidar(_ casa: UUID, _ email: String, _ papel: PapelMembro) async throws -> ConviteDeMembro {
        convites.append((casa, email, papel))
        return try respostaDoConvite.get()
    }

    func remover(_ membro: UUID) async throws {
        removidos.append(membro)
        if let demoraDaAcao { try await Task.sleep(for: demoraDaAcao) }
        try respostaDaAcao.get()
    }

    func transferir(_ membro: UUID) async throws {
        transferidos.append(membro)
        try respostaDaAcao.get()
    }
}

/// Segura uma chamada até o teste mandar seguir.
private actor Porteira {
    private var continuacao: CheckedContinuation<Void, Never>?
    private var liberada = false

    func esperar() async {
        if liberada { return }
        await withCheckedContinuation { continuacao = $0 }
    }

    func liberar() {
        liberada = true
        continuacao?.resume()
        continuacao = nil
    }
}

/// Equipe da casa (RF21, US24; contratos 0.2.73 e 0.2.103): a lista, o convite, remover e tornar administrador, com os pontos
/// que a revisão do Android (PR #998) achou e que não podem se repetir aqui: o 403 tira as capacidades, o link segue o ambiente,
/// o "você" não tem ação, o membro comum não vê ação de administrador.
@MainActor
@Suite("Equipe da casa: lista, convite, remover e transferir (0.2.73 e 0.2.103)")
struct EquipeDaCasaViewModelTests {
    private let casa = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    private let voce = MembroDaCasa(id: UUID(uuidString: "93000000-0000-0000-0000-000000000001")!, nome: "Ana Prado", papel: .administrador, desde: nil, eVoce: true)
    private let renata = MembroDaCasa(id: UUID(uuidString: "93000000-0000-0000-0000-000000000002")!, nome: "Renata Dias", papel: .administrador, desde: nil, eVoce: false)
    private let marina = MembroDaCasa(id: UUID(uuidString: "93000000-0000-0000-0000-000000000003")!, nome: "Marina Souza", papel: .operador, desde: nil, eVoce: false)
    private let paulo = MembroDaCasa(id: UUID(uuidString: "93000000-0000-0000-0000-000000000004")!, nome: "Paulo Lima", papel: .operador, desde: nil, eVoce: false)

    private var todos: [MembroDaCasa] { [voce, renata, marina, paulo] }
    private func recusa(_ codigo: CodigoErroAPI, detalhes: String? = nil, original: String? = nil) -> ErroDaApi {
        ErroDaApi(codigo: codigo, codigoOriginal: original, detalhes: detalhes)
    }

    private func modelo(
        _ servidor: ServidorDaEquipe, papel: PapelMembro? = .administrador, prazo: Duration = .seconds(5), origem: String = OrigemDaWeb.dev
    ) -> EquipeDaCasaViewModel {
        EquipeDaCasaViewModel(
            estabelecimentoID: casa, papel: papel, prazo: prazo,
            listar: { _ in try await servidor.listar() },
            convidar: { try await servidor.convidar($0, $1, $2) },
            remover: { _, membro in try await servidor.remover(membro) },
            transferir: { _, membro in try await servidor.transferir(membro) },
            montarLink: { ConviteDaCasa.link(origem: origem, token: $0) }
        )
    }

    // MARK: Quem pode

    @Test("O administrador lê a lista da casa e ela fica como o servidor a devolveu")
    func administradorLeALista() async {
        let servidor = ServidorDaEquipe([.success(todos)])
        let vm = modelo(servidor)
        #expect(vm.lista == .carregando)

        await vm.carregar()

        #expect(vm.lista == .conteudo(todos))
        #expect(await servidor.leituras == 1)
        #expect(vm.podeGerenciar)
    }

    @Test("Quem não é administrador não pede a lista nem tem como convidar, remover ou transferir: nada chega ao servidor")
    func membroComumNaoVeAcaoDeAdministrador() async {
        for papel in [PapelMembro.operador, nil] {
            let servidor = ServidorDaEquipe([.success(todos)])
            let vm = modelo(servidor, papel: papel)
            #expect(vm.lista == .soAdministrador)

            await vm.carregar()
            vm.email = "alguem@exemplo.com"
            await vm.gerarConvite()
            vm.pedirConfirmacao(.remover, membro: marina)
            await vm.confirmar()
            vm.pedirConfirmacao(.transferir, membro: marina)
            await vm.confirmar()

            #expect(vm.lista == .soAdministrador)
            #expect(vm.pendente == nil)
            #expect(vm.email == "")
            #expect(vm.convite == nil)
            #expect(await servidor.leituras == 0)
            #expect(await servidor.convites.isEmpty)
            #expect(await servidor.removidos.isEmpty)
            #expect(await servidor.transferidos.isEmpty)
        }
    }

    @Test("A linha de \"você\" não tem Remover nem Tornar administrador, e só um operador vira administrador")
    func voceSemAcoes() async {
        let vm = modelo(ServidorDaEquipe([.success(todos)]))
        await vm.carregar()

        vm.pedirConfirmacao(.remover, membro: voce)
        #expect(vm.pendente == nil)
        vm.pedirConfirmacao(.transferir, membro: voce)
        #expect(vm.pendente == nil)
        // Quem já é administrador não é promovido de novo.
        vm.pedirConfirmacao(.transferir, membro: renata)
        #expect(vm.pendente == nil)

        vm.pedirConfirmacao(.remover, membro: renata)
        #expect(vm.pendente == ConfirmacaoDeAcaoNaEquipe(acao: .remover, membroID: renata.id, nome: "Renata Dias"))
        vm.cancelarConfirmacao()
        vm.pedirConfirmacao(.transferir, membro: marina)
        #expect(vm.pendente == ConfirmacaoDeAcaoNaEquipe(acao: .transferir, membroID: marina.id, nome: "Marina Souza"))
    }

    // MARK: 403 tira as capacidades

    @Test("403 sem details na lista: a pessoa não é (mais) administradora, e somem lista, convite e ações")
    func recusaNaListaTiraAsCapacidades() async {
        let servidor = ServidorDaEquipe([.success(todos), .failure(recusa(.semPermissao))])
        let vm = modelo(servidor)
        await vm.carregar()
        vm.email = "novo@exemplo.com"

        await vm.carregar()

        #expect(vm.papel == nil)
        #expect(!vm.podeGerenciar)
        #expect(vm.lista == .soAdministrador)
        #expect(vm.email == "")

        await vm.gerarConvite()
        vm.pedirConfirmacao(.remover, membro: marina)
        await vm.confirmar()
        #expect(await servidor.convites.isEmpty)
        #expect(await servidor.removidos.isEmpty)
        #expect(await servidor.leituras == 2)
    }

    @Test("403 ao gerar o convite: a lista e o convite somem e a mensagem é a do administrador")
    func recusaAoConvidar() async {
        let servidor = ServidorDaEquipe([.success(todos)])
        let vm = modelo(servidor)
        await vm.carregar()
        await servidor.trocarRespostaDoConvite(.failure(recusa(.semPermissao)))
        vm.email = "novo@exemplo.com"

        await vm.gerarConvite()

        #expect(vm.papel == nil)
        #expect(vm.lista == .soAdministrador)
        #expect(vm.convite == nil)
        #expect(vm.erroDoConvite == TextosDaEquipeDaCasa.soAdministrador)
        #expect(!vm.gerandoConvite)
        // Nenhum segundo pedido depois da recusa.
        await vm.gerarConvite()
        #expect(await servidor.convites.count == 1)
    }

    @Test("403 ao remover ou transferir: some a administração, a lista não é relida e nada mais chega ao servidor", arguments: [AcaoSobreMembro.remover, .transferir])
    func recusaAoAgir(acao: AcaoSobreMembro) async {
        let servidor = ServidorDaEquipe([.success(todos)])
        let vm = modelo(servidor)
        await vm.carregar()
        await servidor.trocarRespostaDaAcao(.failure(recusa(.semPermissao)))

        vm.pedirConfirmacao(acao, membro: marina)
        await vm.confirmar()

        #expect(vm.papel == nil)
        #expect(vm.lista == .soAdministrador)
        #expect(vm.erroDaAcao == TextosDaEquipeDaCasa.soAdministrador)
        #expect(vm.pendente == nil)
        #expect(vm.agindoEm == nil)
        #expect(await servidor.leituras == 1)
        vm.pedirConfirmacao(acao, membro: paulo)
        #expect(vm.pendente == nil)
    }

    @Test("A resposta tardia de uma leitura não devolve a lista a quem acabou de perder a administração")
    func leituraTardiaNaoRessuscitaALista() async {
        let porteira = Porteira()
        let servidor = ServidorDaEquipe([.success(todos)])
        await servidor.segurarPrimeiraLeitura(porteira)
        let vm = modelo(servidor)
        let primeira = Task { await vm.carregar() }
        while await servidor.leituras == 0 { await Task.yield() }

        await servidor.trocarRespostaDoConvite(.failure(recusa(.semPermissao)))
        vm.email = "novo@exemplo.com"
        await vm.gerarConvite()
        #expect(vm.lista == .soAdministrador)

        await porteira.liberar()
        await primeira.value
        #expect(vm.lista == .soAdministrador)
        #expect(vm.papel == nil)
    }

    @Test("Só a leitura mais nova escreve na tela: a que voltou depois, e é velha, é descartada")
    func leituraMaisVelhaNaoSobrescreve() async {
        let porteira = Porteira()
        let antiga = [voce]
        let nova = [voce, marina]
        // A primeira leitura (segurada) devolveria a lista antiga; a segunda devolve a nova.
        let servidor = ServidorDaEquipe([.success(antiga), .success(nova)])
        await servidor.segurarPrimeiraLeitura(porteira)
        let vm = modelo(servidor)
        let primeira = Task { await vm.carregar() }
        while await servidor.leituras == 0 { await Task.yield() }

        await vm.carregar()
        #expect(vm.lista == .conteudo(nova))

        await porteira.liberar()
        await primeira.value
        #expect(vm.lista == .conteudo(nova))
    }

    // MARK: Lista com falha

    @Test("Sem rede, erro do servidor e resposta ilegível na lista viram mensagem com Tentar de novo, e a leitura seguinte recupera")
    func falhaNaLista() async {
        let casos: [(Error, String)] = [
            (recusa(.semRede), TextosDaEquipeDaCasa.semRede),
            (recusa(.naoAutenticado), TextosDaEquipeDaCasa.sessao),
            (recusa(.desconhecido), TextosDaEquipeDaCasa.erroDaLista),
            (recusa(.respostaInvalida), TextosDaEquipeDaCasa.erroDaLista),
            (URLError(.cannotParseResponse), TextosDaEquipeDaCasa.erroDaLista),
        ]
        for (falha, mensagem) in casos {
            let servidor = ServidorDaEquipe([.failure(falha), .success(todos)])
            let vm = modelo(servidor)
            await vm.carregar()
            #expect(vm.lista == .erro(mensagem))
            #expect(vm.podeGerenciar)
            await vm.carregar()
            #expect(vm.lista == .conteudo(todos))
        }
    }

    @Test("Conta suspensa na lista: mensagem da suspensão, a administração fica e a lista antiga não")
    func listaComContaSuspensa() async {
        let servidor = ServidorDaEquipe([.success(todos), .failure(recusa(.semPermissao, detalhes: "conta_suspensa"))])
        let vm = modelo(servidor)
        await vm.carregar()

        await vm.carregar(silencioso: true)

        #expect(vm.lista == .erro(TextosDaEquipeDaCasa.contaSuspensa))
        #expect(vm.podeGerenciar)
    }

    @Test("Prazo vencido na lista: mensagem de sem conexão em vez de carregar para sempre")
    func prazoNaLista() async {
        let servidor = ServidorDaEquipe([.success(todos)])
        await servidor.trocarDemoraDaLeitura(.seconds(30))
        let vm = modelo(servidor, prazo: .milliseconds(50))

        await vm.carregar()

        #expect(vm.lista == .erro(TextosDaEquipeDaCasa.semRede))
    }

    @Test("Releitura silenciosa que falha não apaga a lista que já está na tela")
    func releituraQueFalhaMantemALista() async {
        let servidor = ServidorDaEquipe([.success(todos), .failure(recusa(.semRede))])
        let vm = modelo(servidor)
        await vm.carregar()

        await vm.carregar(silencioso: true)

        #expect(vm.lista == .conteudo(todos))
    }

    // MARK: Convidar

    @Test("Convite gerado: e-mail aparado e papel certos no servidor, link do ambiente com o token no fragmento, campo limpo")
    func convidaComSucesso() async {
        let token = String(repeating: "ab", count: 32)
        let servidor = ServidorDaEquipe([.success(todos)])
        let vencimento = Date(timeIntervalSince1970: 1_800_000_000)
        await servidor.trocarRespostaDoConvite(.success(ConviteDeMembro(token: token, expiraEm: vencimento)))
        let vm = modelo(servidor, origem: "https://exemplo.test/app")
        await vm.carregar()
        vm.email = "  paulo.lima@exemplo.com  "
        vm.papelConvidado = .administrador

        await vm.gerarConvite()

        let recebido = await servidor.convites
        #expect(recebido.count == 1)
        #expect(recebido[0].casa == casa)
        #expect(recebido[0].email == "paulo.lima@exemplo.com")
        #expect(recebido[0].papel == .administrador)
        #expect(vm.convite == ConviteGerado(link: "https://exemplo.test/app/convite#\(token)", email: "paulo.lima@exemplo.com", expiraEm: vencimento))
        #expect(vm.email == "")
        #expect(!vm.gerandoConvite)
        #expect(vm.erroDoConvite == nil)
    }

    @Test("O link do convite segue o ambiente do app: web de dev no Local, no Dev e no Beta, web de produção só no Prod")
    func linkSegueOAmbiente() async {
        let token = String(repeating: "cd", count: 32)
        let casos: [(String?, String)] = [
            ("frila-prod", "https://frilabr.com/app/convite#\(token)"),
            ("frila-dev", "https://frila-web-dev.frilabr.workers.dev/app/convite#\(token)"),
            ("local", "https://frila-web-dev.frilabr.workers.dev/app/convite#\(token)"),
            (nil, "https://frila-web-dev.frilabr.workers.dev/app/convite#\(token)"),
            ("", "https://frila-web-dev.frilabr.workers.dev/app/convite#\(token)"),
            ("qualquer-outro", "https://frila-web-dev.frilabr.workers.dev/app/convite#\(token)"),
        ]
        for (ambiente, esperado) in casos {
            let servidor = ServidorDaEquipe([.success(todos)])
            await servidor.trocarRespostaDoConvite(.success(ConviteDeMembro(token: token, expiraEm: nil)))
            let vm = modelo(servidor, origem: OrigemDaWeb.doAmbiente(ambiente))
            vm.email = "alguem@exemplo.com"
            await vm.gerarConvite()
            #expect(vm.convite?.link == esperado, "ambiente \(ambiente ?? "nil")")
        }
    }

    @Test("E-mail inválido não chega ao servidor e marca o campo", arguments: ["", "   ", "sem-arroba", "a@b", "a b@c.com", "@c.com", "a@@c.com", "a@c..com", "a@c."])
    func emailInvalido(texto: String) async {
        let servidor = ServidorDaEquipe([.success(todos)])
        let vm = modelo(servidor)
        vm.email = texto

        await vm.gerarConvite()

        #expect(vm.erroDoEmail == TextosDaEquipeDaCasa.emailInvalido)
        #expect(vm.convite == nil)
        #expect(await servidor.convites.isEmpty)
        // Editar o campo tira a marca do erro.
        vm.email = "a@c.com"
        #expect(vm.erroDoEmail == nil)
    }

    @Test("Token fora do formato do contrato não vira link: nenhum convite compartilhável, só a mensagem")
    func tokenForaDoFormato() async {
        let servidor = ServidorDaEquipe([.success(todos)])
        await servidor.trocarRespostaDoConvite(.success(ConviteDeMembro(token: "curto", expiraEm: nil)))
        let vm = modelo(servidor)
        vm.email = "alguem@exemplo.com"

        await vm.gerarConvite()

        #expect(vm.convite == nil)
        #expect(vm.erroDoConvite == TextosDaEquipeDaCasa.erro)
        #expect(!vm.gerandoConvite)
    }

    @Test("Recusas do convite: o campo certo, a mensagem certa, e o botão volta a funcionar")
    func recusasDoConvite() async {
        let casos: [(ErroDaApi, KeyPath<EquipeDaCasaViewModel, String?>, String)] = [
            (recusa(.campoInvalido, detalhes: "email"), \.erroDoEmail, TextosDaEquipeDaCasa.emailInvalido),
            (recusa(.campoObrigatorio, detalhes: "papel"), \.erroDoConvite, TextosDaEquipeDaCasa.papelInvalido),
            (recusa(.campoInvalido, detalhes: "papel"), \.erroDoConvite, TextosDaEquipeDaCasa.papelInvalido),
            (recusa(.semPermissao, detalhes: "conta_suspensa"), \.erroDoConvite, TextosDaEquipeDaCasa.contaSuspensa),
            (recusa(.naoAutenticado), \.erroDoConvite, TextosDaEquipeDaCasa.sessao),
            (recusa(.semRede), \.erroDoConvite, TextosDaEquipeDaCasa.semRede),
            (recusa(.desconhecido), \.erroDoConvite, TextosDaEquipeDaCasa.erro),
            (recusa(.naoEncontrado), \.erroDoConvite, TextosDaEquipeDaCasa.indisponivel),
        ]
        for (falha, campo, mensagem) in casos {
            let servidor = ServidorDaEquipe([.success(todos)])
            await servidor.trocarRespostaDoConvite(.failure(falha))
            let vm = modelo(servidor)
            vm.email = "alguem@exemplo.com"

            await vm.gerarConvite()

            #expect(vm[keyPath: campo] == mensagem, "\(falha.codigo) \(falha.detalhes ?? "")")
            #expect(vm.convite == nil)
            #expect(!vm.gerandoConvite)
            #expect(vm.podeGerenciar)
            // O e-mail digitado fica para a pessoa corrigir.
            #expect(vm.email == "alguem@exemplo.com")
        }
    }

    @Test("Falha que não é do contrato ao gerar o convite vira mensagem, e a tela não fica presa")
    func falhaIlegivelNoConvite() async {
        let servidor = ServidorDaEquipe([.success(todos)])
        await servidor.trocarRespostaDoConvite(.failure(URLError(.cannotParseResponse)))
        let vm = modelo(servidor)
        vm.email = "alguem@exemplo.com"

        await vm.gerarConvite()

        #expect(vm.erroDoConvite == TextosDaEquipeDaCasa.erro)
        #expect(!vm.gerandoConvite)
    }

    @Test("Dois toques em Gerar convite mandam um pedido só")
    func toqueDuploNoConvite() async {
        let servidor = ServidorDaEquipe([.success(todos)])
        let vm = modelo(servidor)
        vm.email = "alguem@exemplo.com"

        async let primeiro: Void = vm.gerarConvite()
        async let segundo: Void = vm.gerarConvite()
        _ = await (primeiro, segundo)

        #expect(await servidor.convites.count == 1)
    }

    @Test("Enquanto o convite está sendo gerado, o e-mail e o papel não mudam")
    func camposTravadosEnquantoGera() async {
        let servidor = ServidorDaEquipe([.success(todos)])
        let vm = modelo(servidor)
        vm.email = "alguem@exemplo.com"
        let tarefa = Task { await vm.gerarConvite() }
        while !vm.gerandoConvite { await Task.yield() }

        vm.email = "outro@exemplo.com"
        vm.papelConvidado = .administrador
        #expect(vm.email == "alguem@exemplo.com")
        #expect(vm.papelConvidado == .operador)
        await tarefa.value
    }

    // MARK: Remover e tornar administrador

    @Test("Remover: pede confirmação, só chama o servidor ao confirmar, mostra o aviso e relê a lista do servidor")
    func removeComSucesso() async {
        let servidor = ServidorDaEquipe([.success(todos), .success([voce, renata, paulo])])
        let vm = modelo(servidor)
        await vm.carregar()

        vm.pedirConfirmacao(.remover, membro: marina)
        #expect(await servidor.removidos.isEmpty)
        #expect(vm.pendente?.nome == "Marina Souza")

        await vm.confirmar()

        #expect(await servidor.removidos == [marina.id])
        #expect(vm.aviso == TextosDaEquipeDaCasa.removida)
        #expect(vm.erroDaAcao == nil)
        #expect(vm.pendente == nil)
        #expect(vm.agindoEm == nil)
        #expect(vm.lista == .conteudo([voce, renata, paulo]))
        #expect(await servidor.leituras == 2)
    }

    @Test("Tornar administrador: chama transferir com o membro certo, mostra o aviso e relê a lista")
    func transfereComSucesso() async {
        let promovido = MembroDaCasa(id: marina.id, nome: marina.nome, papel: .administrador, desde: nil, eVoce: false)
        let servidor = ServidorDaEquipe([.success(todos), .success([voce, renata, promovido, paulo])])
        let vm = modelo(servidor)
        await vm.carregar()

        vm.pedirConfirmacao(.transferir, membro: marina)
        await vm.confirmar()

        #expect(await servidor.transferidos == [marina.id])
        #expect(vm.aviso == TextosDaEquipeDaCasa.transferida)
        #expect(vm.lista == .conteudo([voce, renata, promovido, paulo]))
    }

    @Test("Cancelar a confirmação não chama o servidor")
    func cancelaConfirmacao() async {
        let servidor = ServidorDaEquipe([.success(todos)])
        let vm = modelo(servidor)
        await vm.carregar()

        vm.pedirConfirmacao(.remover, membro: marina)
        vm.cancelarConfirmacao()
        await vm.confirmar()

        #expect(vm.pendente == nil)
        #expect(await servidor.removidos.isEmpty)
        #expect(await servidor.leituras == 1)
    }

    @Test("Recusa que não é 403 (a pessoa já saiu, último administrador, conta suspensa, sem rede): mensagem certa e a lista é relida")
    func recusaDeRemoverRelaALista() async {
        let casos: [(ErroDaApi, String)] = [
            (recusa(.naoEncontrado), TextosDaEquipeDaCasa.indisponivel),
            (recusa(.desconhecido, original: "ultimo_administrador"), TextosDaEquipeDaCasa.ultimoAdministrador),
            (recusa(.semPermissao, detalhes: "conta_suspensa"), TextosDaEquipeDaCasa.contaSuspensa),
            (recusa(.naoAutenticado), TextosDaEquipeDaCasa.sessao),
            (recusa(.semRede), TextosDaEquipeDaCasa.semRede),
            (recusa(.desconhecido), TextosDaEquipeDaCasa.erro),
        ]
        for (falha, mensagem) in casos {
            let servidor = ServidorDaEquipe([.success(todos), .success([voce, renata, paulo])])
            let vm = modelo(servidor)
            await vm.carregar()
            await servidor.trocarRespostaDaAcao(.failure(falha))

            vm.pedirConfirmacao(.remover, membro: marina)
            await vm.confirmar()

            #expect(vm.erroDaAcao == mensagem, "\(falha.codigoOriginal)")
            #expect(vm.aviso == nil)
            #expect(vm.agindoEm == nil)
            #expect(await servidor.leituras == 2, "a lista que vale é a do servidor: \(falha.codigoOriginal)")
            #expect(vm.lista == .conteudo([voce, renata, paulo]))
            #expect(vm.podeGerenciar)
        }
    }

    @Test("Resposta que não é do contrato ao remover vira mensagem e relê a lista, sem deixar a tela presa")
    func falhaIlegivelAoRemover() async {
        let servidor = ServidorDaEquipe([.success(todos)])
        let vm = modelo(servidor)
        await vm.carregar()
        await servidor.trocarRespostaDaAcao(.failure(URLError(.cannotParseResponse)))

        vm.pedirConfirmacao(.remover, membro: marina)
        await vm.confirmar()

        #expect(vm.erroDaAcao == TextosDaEquipeDaCasa.erro)
        #expect(vm.agindoEm == nil)
        #expect(await servidor.leituras == 2)
    }

    @Test("Prazo vencido ao remover: sem resultado conhecido, a lista é relida do servidor e a tela não fica presa")
    func prazoAoRemover() async {
        let servidor = ServidorDaEquipe([.success(todos), .success([voce, renata, paulo])])
        let vm = modelo(servidor, prazo: .milliseconds(100))
        await vm.carregar()
        await servidor.trocarDemoraDaAcao(.seconds(30))

        vm.pedirConfirmacao(.remover, membro: marina)
        await vm.confirmar()

        #expect(vm.erroDaAcao == TextosDaEquipeDaCasa.semRede)
        #expect(vm.agindoEm == nil)
        #expect(await servidor.leituras == 2)
        #expect(vm.lista == .conteudo([voce, renata, paulo]))
    }

    @Test("Toque duplo em Confirmar remove uma vez só")
    func toqueDuploNaConfirmacao() async {
        let servidor = ServidorDaEquipe([.success(todos)])
        let vm = modelo(servidor)
        await vm.carregar()
        vm.pedirConfirmacao(.remover, membro: marina)

        async let primeiro: Void = vm.confirmar()
        async let segundo: Void = vm.confirmar()
        _ = await (primeiro, segundo)

        #expect(await servidor.removidos.count == 1)
    }
}
