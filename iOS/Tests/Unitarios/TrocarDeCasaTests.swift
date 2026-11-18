@testable import FrilaApresentacao
import Foundation
import FrilaDominio
import Testing

/// Segura uma leitura até o teste mandar seguir.
private actor PorteiraDeLeitura {
    private var continuacao: CheckedContinuation<Void, Never>?
    private var liberada = false
    private(set) var chegou = false

    func esperar() async {
        chegou = true
        if liberada { return }
        await withCheckedContinuation { continuacao = $0 }
    }

    func liberar() {
        liberada = true
        continuacao?.resume()
        continuacao = nil
    }
}

/// Uma lista de casas que o teste troca no meio (a conta entrou ou saiu de uma casa) e conta quantas vezes foi lida.
private actor CasasDaConta {
    private var casas: [EstabelecimentoDaConta]
    private(set) var leituras = 0
    var falha: Error?

    init(_ casas: [EstabelecimentoDaConta]) { self.casas = casas }

    func trocar(_ novas: [EstabelecimentoDaConta]) { casas = novas }
    func falhar(com erro: Error?) { falha = erro }

    func ler() throws -> [EstabelecimentoDaConta] {
        leituras += 1
        if let falha { throw falha }
        return casas
    }
}

/// Trocar de casa (RF21; `meus_estabelecimentos` + `meu_estabelecimento`, sem RPC de troca) e a casa escolhida: ela só vive na
/// sessão e nada de uma casa ou de uma conta aparece em outra (o app já teve vazamento entre contas, #989).
@MainActor
@Suite("Trocar de casa e a casa escolhida")
struct TrocarDeCasaTests {
    private let bistro = EstabelecimentoDaConta(id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!, nome: "Bistrô Ipê", papel: .administrador)
    private let cantina = EstabelecimentoDaConta(id: UUID(uuidString: "30000000-0000-0000-0000-000000000002")!, nome: "Cantina da Esquina", papel: .operador)
    private let padaria = EstabelecimentoDaConta(id: UUID(uuidString: "30000000-0000-0000-0000-000000000003")!, nome: "Padaria do Bairro", papel: .operador)
    private let conta: Conta

    init() throws {
        conta = Conta(
            id: UUID(), perfil: .contratante, nome: "Responsável", telefone: "61988887777", email: "contratante@frila.app",
            nascimento: try DataCivil(ano: 1995, mes: 5, dia: 15), estado: .ativa
        )
    }

    private func fluxo(_ casas: CasasDaConta) -> FluxoDoContratanteViewModel {
        let conta = conta
        return FluxoDoContratanteViewModel(meusEstabelecimentos: { try await casas.ler() }, minhaConta: { conta })
    }

    // MARK: A casa escolhida

    @Test("Sem escolha vale a primeira casa do servidor, e as casas da conta ficam na lista")
    func primeiraCasa() async {
        let casas = CasasDaConta([bistro, cantina])
        let modelo = fluxo(casas)

        await modelo.carregar()

        #expect(modelo.estado == .vagas(bistro))
        #expect(modelo.escolhidaID == bistro.id)
        #expect(modelo.casas == [bistro, cantina])
    }

    @Test("Escolher outra casa troca o estado sem ir ao servidor, e uma casa que a conta não tem é ignorada")
    func escolhe() async {
        let casas = CasasDaConta([bistro, cantina])
        let modelo = fluxo(casas)
        await modelo.carregar()

        modelo.escolher(cantina.id)
        #expect(modelo.estado == .vagas(cantina))
        #expect(modelo.escolhidaID == cantina.id)

        modelo.escolher(padaria.id)
        #expect(modelo.estado == .vagas(cantina))
        #expect(modelo.escolhidaID == cantina.id)
        #expect(await casas.leituras == 1)
    }

    @Test("A escolha sobrevive a uma nova leitura enquanto a conta ainda é membro da casa")
    func escolhaSobrevive() async {
        let casas = CasasDaConta([bistro, cantina])
        let modelo = fluxo(casas)
        await modelo.carregar()
        modelo.escolher(cantina.id)

        await modelo.carregar()

        #expect(modelo.estado == .vagas(cantina))
    }

    @Test("A conta que saiu da casa escolhida volta para a primeira: o app nunca fala de uma casa que não é dela")
    func escolhaQueDeixouDeSerDaConta() async {
        let casas = CasasDaConta([bistro, cantina])
        let modelo = fluxo(casas)
        await modelo.carregar()
        modelo.escolher(cantina.id)
        await casas.trocar([bistro])

        await modelo.carregar()

        #expect(modelo.estado == .vagas(bistro))
        #expect(modelo.escolhidaID == bistro.id)
        #expect(modelo.casas == [bistro])
    }

    @Test("Outra conta no mesmo aparelho começa sem escolha: nada da casa de uma conta aparece na outra")
    func outraContaComecaSemEscolha() async {
        let primeira = fluxo(CasasDaConta([bistro, cantina]))
        await primeira.carregar()
        primeira.escolher(cantina.id)
        #expect(primeira.escolhidaID == cantina.id)

        // Sair da conta, a sessão vencer ou entrar com outra tira o fluxo da tela, e o modelo da sessão vai junto.
        let segunda = fluxo(CasasDaConta([padaria, cantina]))
        #expect(segunda.escolhidaID == nil)
        #expect(segunda.casas.isEmpty)
        #expect(segunda.estado == .carregando)

        await segunda.carregar()

        // A outra conta também é membro da Cantina, mas a escolha da primeira não passa para ela.
        #expect(segunda.estado == .vagas(padaria))
        #expect(segunda.escolhidaID == padaria.id)
    }

    @Test("Abrir uma casa pelo convite aceito: a leitura vai direto para ela, mesmo que a escolha anterior seja outra")
    func abreACasaDoConvite() async {
        let casas = CasasDaConta([bistro])
        let modelo = fluxo(casas)
        await modelo.carregar()
        await casas.trocar([bistro, padaria])

        await modelo.carregar(preferindo: padaria.id)

        #expect(modelo.estado == .vagas(padaria))
        #expect(modelo.escolhidaID == padaria.id)
        #expect(modelo.casas == [bistro, padaria])
    }

    @Test("Quem estava no cadastro e aceitou um convite passa para Minhas vagas ao atualizar as casas")
    func atualizarSaiDoCadastro() async {
        let casas = CasasDaConta([])
        let modelo = fluxo(casas)
        await modelo.carregar()
        #expect(modelo.estado == .cadastro(conta))

        await casas.trocar([padaria])
        await modelo.atualizarCasas()

        #expect(modelo.estado == .vagas(padaria))
        #expect(modelo.casas == [padaria])
    }

    @Test("Atualizar as casas não troca a tela de quem está numa casa, só a lista de casas")
    func atualizarMantemACasa() async {
        let casas = CasasDaConta([bistro])
        let modelo = fluxo(casas)
        await modelo.carregar()
        modelo.escolher(bistro.id)
        await casas.trocar([bistro, padaria])

        await modelo.atualizarCasas()

        #expect(modelo.estado == .vagas(bistro))
        #expect(modelo.casas == [bistro, padaria])
    }

    @Test("Se a casa em uso deixou de ser da conta, atualizar recomeça a leitura inteira")
    func atualizarSemACasaEmUso() async {
        let casas = CasasDaConta([bistro, cantina])
        let modelo = fluxo(casas)
        await modelo.carregar()
        await casas.trocar([cantina])

        await modelo.atualizarCasas()

        #expect(modelo.estado == .vagas(cantina))
        #expect(modelo.casas == [cantina])
    }

    @Test("Falha ao atualizar as casas mantém tudo como está")
    func atualizarComFalha() async {
        let casas = CasasDaConta([bistro, cantina])
        let modelo = fluxo(casas)
        await modelo.carregar()
        await casas.falhar(com: ErroDaApi(codigo: .semRede))

        await modelo.atualizarCasas()

        #expect(modelo.estado == .vagas(bistro))
        #expect(modelo.casas == [bistro, cantina])
    }

    @Test("Falha ao ler as casas esvazia a lista de casas: o erro não deixa casa antiga para trás")
    func falhaEsvaziaAsCasas() async {
        let casas = CasasDaConta([bistro, cantina])
        let modelo = fluxo(casas)
        await modelo.carregar()
        await casas.falhar(com: ErroDaApi(codigo: .semRede))

        await modelo.carregar()

        #expect(modelo.estado == .offline)
        #expect(modelo.casas.isEmpty)
    }

    // MARK: A tela de troca

    @Test("A lista de casas é a do servidor, lida a cada abertura")
    func listaDeCasas() async {
        let casas = CasasDaConta([bistro, cantina, padaria])
        let tela = TrocarDeCasaViewModel(listar: { try await casas.ler() })
        #expect(tela.estado == .carregando)

        await tela.carregar()
        #expect(tela.estado == .conteudo([bistro, cantina, padaria]))

        await casas.trocar([bistro])
        await tela.carregar()
        #expect(tela.estado == .conteudo([bistro]))
        #expect(await casas.leituras == 2)
    }

    @Test("Falha ou prazo vencido na lista de casas viram erro com Tentar novamente, e a leitura seguinte recupera")
    func listaDeCasasComFalha() async {
        let casas = CasasDaConta([bistro, cantina])
        await casas.falhar(com: ErroDaApi(codigo: .semRede))
        let tela = TrocarDeCasaViewModel(listar: { try await casas.ler() })

        await tela.carregar()
        #expect(tela.estado == .erro)

        await casas.falhar(com: nil)
        await tela.carregar()
        #expect(tela.estado == .conteudo([bistro, cantina]))

        let lenta = TrocarDeCasaViewModel(prazo: .milliseconds(50), listar: {
            try await Task.sleep(for: .seconds(30))
            return []
        })
        await lenta.carregar()
        #expect(lenta.estado == .erro)
    }

    // MARK: O perfil da casa escolhida

    private func perfil(_ casas: CasasDaConta, porteira: PorteiraDeLeitura? = nil) -> PerfilEstabelecimentoViewModel {
        let aqui = (bistro, cantina)
        return PerfilEstabelecimentoViewModel(
            estabelecimentos: { try await casas.ler() },
            publico: { id in
                if let porteira, id == aqui.1.id { await porteira.esperar() }
                return PerfilPublico(
                    id: id, tipo: .estabelecimento, nome: id == aqui.0.id ? "Bistrô Ipê" : "Cantina da Esquina",
                    reputacao: Reputacao(positivas: 0, total: 0, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0)
                )
            }
        )
    }

    @Test("O perfil mostra a casa escolhida; sem escolha, a primeira; e uma escolha que não é mais da conta cai na primeira")
    func perfilDaCasaEscolhida() async {
        let casas = CasasDaConta([bistro, cantina])
        let modelo = perfil(casas)

        await modelo.carregar()
        #expect(modelo.estabelecimento == bistro)

        await modelo.carregar(preferindo: cantina.id)
        #expect(modelo.estabelecimento == cantina)
        #expect(modelo.perfilPublico?.nome == "Cantina da Esquina")

        await modelo.carregar(preferindo: padaria.id)
        #expect(modelo.estabelecimento == bistro)
    }

    @Test("Ao trocar de casa, nada da casa anterior fica na tela enquanto a nova carrega")
    func nadaDaCasaAnteriorNaTroca() async {
        let casas = CasasDaConta([bistro, cantina])
        let porteira = PorteiraDeLeitura()
        let modelo = perfil(casas, porteira: porteira)
        await modelo.carregar()
        #expect(modelo.estabelecimento == bistro)

        let troca = Task { await modelo.carregar(preferindo: cantina.id) }
        while await !porteira.chegou { await Task.yield() }

        // A leitura da Cantina está em voo: a tela já não mostra o Bistrô.
        #expect(modelo.estabelecimento == nil)
        #expect(modelo.perfilPublico == nil)
        #expect(modelo.carregando)

        await porteira.liberar()
        await troca.value
        #expect(modelo.estabelecimento == cantina)
        #expect(!modelo.carregando)
    }

    @Test("Conta que ficou sem casa não mostra a casa antiga no perfil")
    func contaSemCasaNoPerfil() async {
        let casas = CasasDaConta([bistro])
        let modelo = perfil(casas)
        await modelo.carregar()
        #expect(modelo.estabelecimento == bistro)

        await casas.trocar([])
        await modelo.carregar()

        #expect(modelo.estabelecimento == nil)
        #expect(modelo.perfilPublico == nil)
    }
}
