@testable import FrilaApresentacao
@testable import FrilaDados
import Foundation
import FrilaDominio
import Testing

/// O que a API de mentira recebeu da escala: a chave de cada envio, e o que ela responde a cada um.
private actor ServidorDeEscalaPorCasa {
    private(set) var chaves: [UUID] = []
    private var respostas: [Result<EscalaPublicada, Error>]

    init(_ respostas: [Result<EscalaPublicada, Error>]) { self.respostas = respostas }

    func publicar(_ escala: PublicacaoEscala) async throws -> EscalaPublicada {
        chaves.append(escala.chave)
        guard !respostas.isEmpty else { throw ErroDaApi(codigo: .desconhecido) }
        return try respostas.removeFirst().get()
    }
}

/// As guardas de dinheiro por casa (P2-1 da revisão do #1001): trocar de casa recria Minhas vagas, e a chave de uma escala com
/// resultado incerto não pode se perder na ida e volta, senão publicar de novo sai com chave nova e pode duplicar.
@MainActor
@Suite("Guardas de dinheiro por casa: trocar de casa e voltar mantém a chave da escala incerta")
struct GuardasPorCasaTests {
    private let agora = Date(timeIntervalSince1970: 1_800_000_000)
    private let garcom = Funcao(id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!, nome: "Garçom", categoria: "Salão")
    private let casaA = EstabelecimentoDaConta(id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!, nome: "Bistrô Ipê", papel: .administrador)
    private let casaB = EstabelecimentoDaConta(id: UUID(uuidString: "30000000-0000-0000-0000-000000000002")!, nome: "Cantina da Esquina", papel: .administrador)
    private let conta: Conta

    init() throws {
        conta = Conta(
            id: UUID(), perfil: .contratante, nome: "Responsável", telefone: "61988887777", email: "contratante@frila.app",
            nascimento: try DataCivil(ano: 1995, mes: 5, dia: 15), estado: .ativa
        )
    }

    private func fluxo() -> FluxoDoContratanteViewModel {
        let casas = [casaA, casaB]
        let conta = conta
        return FluxoDoContratanteViewModel(meusEstabelecimentos: { casas }, minhaConta: { conta })
    }

    /// O modelo da escala da casa, preenchido, como `DestinoDePublicarEscala` o cria.
    private func modeloDaEscala(_ casa: EstabelecimentoDaConta, _ servidor: ServidorDeEscalaPorCasa) throws -> PublicarEscalaViewModel {
        let fixo = agora
        let cadastro = Estabelecimento(
            id: casa.id, nome: casa.nome, tipo: .foodService, endereco: "CLS 405, Asa Sul, Brasília - DF",
            regiaoAdministrativa: "Plano Piloto", ponto: try Coordenada(latitude: -15.8121, longitude: -47.8997)
        )
        let vm = PublicarEscalaViewModel(estabelecimento: cadastro, funcoes: [garcom], agora: { fixo }, publicar: { try await servidor.publicar($0) })
        vm.nome = "Formatura de Direito"
        vm.atualizar(vm.vagas[0].id) { $0.funcaoID = garcom.id; $0.valorTexto = "16000"; $0.responsavelLocal = "Marina" }
        return vm
    }

    @Test("Escala sem resposta na casa A, trocar para B e voltar para A: a mesma guarda, o mesmo modelo e a MESMA chave no reenvio")
    func idaEVoltaMantemAChave() async throws {
        let servidor = ServidorDeEscalaPorCasa([.failure(ErroDaApi(codigo: .semRede)), .success(EscalaPublicada(eventoID: UUID(), vagas: []))])
        let modelo = fluxo()
        await modelo.carregar()
        #expect(modelo.estado == .vagas(casaA))

        // Casa A: a escala sai sem resposta conhecida e a pessoa cancela.
        let guardaA = modelo.guardas.escala(de: casaA.id)
        let escalaA = guardaA.obter { try! modeloDaEscala(casaA, servidor) }
        await escalaA.publicar()
        #expect(escalaA.tentativaIncerta != nil)
        guardaA.aoSair()
        #expect(guardaA.temTentativaIncerta)

        // Trocar para a casa B (o `.id` recria Minhas vagas) não leva a guarda de A, e B começa limpa.
        modelo.escolher(casaB.id)
        let guardaB = modelo.guardas.escala(de: casaB.id)
        #expect(guardaB !== guardaA)
        #expect(!guardaB.temTentativaIncerta)

        // Voltar para A: a mesma guarda, o mesmo modelo, com o aviso, e reenviar usa a mesma chave.
        modelo.escolher(casaA.id)
        let guardaDeNovo = modelo.guardas.escala(de: casaA.id)
        #expect(guardaDeNovo === guardaA)
        #expect(guardaDeNovo.temTentativaIncerta)
        let reaberta = guardaDeNovo.obter { try! modeloDaEscala(casaA, servidor) }
        #expect(reaberta === escalaA)
        #expect(reaberta.erros.geral == TextosDaEscala.Erro.incerta)
        await reaberta.publicar()
        let chaves = await servidor.chaves
        #expect(chaves.count == 2)
        #expect(chaves[0] == chaves[1], "publicar de novo na casa A leva a chave de antes: o servidor devolve a mesma escala, sem duplicar")
        #expect(reaberta.resultado != nil)
    }

    @Test("A tentativa incerta de uma casa não aparece na outra, e cada casa tem a sua busca")
    func cadaCasaTemAsSuas() async throws {
        let servidor = ServidorDeEscalaPorCasa([.failure(ErroDaApi(codigo: .semRede))])
        let guardas = GuardasPorCasa()
        let escalaA = guardas.escala(de: casaA.id).obter { try! modeloDaEscala(casaA, servidor) }
        await escalaA.publicar()
        guardas.escala(de: casaA.id).aoSair()

        #expect(guardas.escala(de: casaA.id).temTentativaIncerta)
        #expect(!guardas.escala(de: casaB.id).temTentativaIncerta)

        var criadas = 0
        let api = ApiClienteEmMemoria()
        let buscaA = guardas.busca(de: casaA.id) { criadas += 1; return BuscaDeProfissionaisViewModel(api: api, estabelecimentoID: casaA.id) }
        let buscaDeNovo = guardas.busca(de: casaA.id) { criadas += 1; return BuscaDeProfissionaisViewModel(api: api, estabelecimentoID: casaA.id) }
        let buscaB = guardas.busca(de: casaB.id) { criadas += 1; return BuscaDeProfissionaisViewModel(api: api, estabelecimentoID: casaB.id) }
        #expect(buscaDeNovo === buscaA)
        #expect(buscaB !== buscaA)
        #expect(buscaA.aoAbrir() === buscaA.aoAbrir())
        #expect(buscaB.aoAbrir() !== buscaA.aoAbrir(), "cada casa tem o seu modelo de busca")
        // O modelo só é criado quando a busca abre, e uma vez por casa.
        #expect(criadas == 2)
    }

    @Test("Sair da conta apaga todas as guardas junto com a casa escolhida: a sessão seguinte começa sem chave nenhuma")
    func sairDaContaApagaTudo() async throws {
        let servidor = ServidorDeEscalaPorCasa([.failure(ErroDaApi(codigo: .semRede))])
        let modelo = fluxo()
        await modelo.carregar()
        modelo.escolher(casaB.id)
        let escalaB = modelo.guardas.escala(de: casaB.id).obter { try! modeloDaEscala(casaB, servidor) }
        await escalaB.publicar()
        modelo.guardas.escala(de: casaB.id).aoSair()
        #expect(modelo.guardas.escala(de: casaB.id).temTentativaIncerta)
        #expect(!modelo.guardas.vazia)

        modelo.encerrarSessao()

        #expect(modelo.escolhidaID == nil)
        #expect(modelo.casas.isEmpty)
        #expect(modelo.guardas.vazia)
        #expect(!modelo.guardas.escala(de: casaB.id).temTentativaIncerta, "a guarda de antes não volta")
    }

    @Test("Outra conta no mesmo aparelho começa com as guardas vazias, mesmo que seja membro da mesma casa")
    func outraContaComecaSemGuardas() async throws {
        let servidor = ServidorDeEscalaPorCasa([.failure(ErroDaApi(codigo: .semRede))])
        let primeira = fluxo()
        await primeira.carregar()
        let escala = primeira.guardas.escala(de: casaA.id).obter { try! modeloDaEscala(casaA, servidor) }
        await escala.publicar()
        primeira.guardas.escala(de: casaA.id).aoSair()
        #expect(primeira.guardas.escala(de: casaA.id).temTentativaIncerta)

        // O fluxo da primeira conta saiu da tela, e o modelo dela com ele; a segunda cria o seu.
        let segunda = fluxo()
        await segunda.carregar()

        #expect(segunda.guardas.vazia)
        #expect(segunda.guardas !== primeira.guardas)
        #expect(!segunda.guardas.escala(de: casaA.id).temTentativaIncerta)
    }
}
