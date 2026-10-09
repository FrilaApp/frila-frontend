import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

private let casaID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
private let anaID = UUID(uuidString: "80000000-0000-0000-0000-000000000001")!

private func perfil(_ id: UUID, _ nome: String) -> PerfilPublico {
    PerfilPublico(id: id, tipo: .profissional, nome: nome, funcoes: ["Garçom"], reputacao: Reputacao(positivas: 1, total: 1, taxaComparecimento: 1, turnosConsiderados: 1, turnosRealizados: 1))
}

private final class Contador: @unchecked Sendable {
    private let trava = NSLock()
    private var _valor = 0
    var valor: Int { trava.withLock { _valor } }
    func incrementar() { trava.withLock { _valor += 1 } }
}

private actor TravaAssincrona {
    private var iniciou = false
    private var liberado = false
    private var continuacaoInicio: CheckedContinuation<Void, Never>?
    private var continuacaoLiberacao: CheckedContinuation<Void, Never>?

    func esperar() async {
        iniciou = true
        continuacaoInicio?.resume()
        continuacaoInicio = nil
        if !liberado {
            await withCheckedContinuation { cont in
                continuacaoLiberacao = cont
            }
        }
    }

    func esperarInicio() async {
        if !iniciou {
            await withCheckedContinuation { cont in
                continuacaoInicio = cont
            }
        }
    }

    func liberar() {
        liberado = true
        continuacaoLiberacao?.resume()
        continuacaoLiberacao = nil
    }
}

@MainActor
@Suite("Equipe de confiança: View Models (#24)")
struct EquipeDeConfiancaViewModelTests {
    @Test("Lista a equipe do dublê e remove com o par certo, até o estado vazio")
    func listaERemove() async throws {
        let api = ApiClienteEmMemoria(cenario: .equipeDeConfiancaComMembro)
        let vm = EquipeDeConfiancaViewModel(estabelecimentoID: casaID, api: api)
        #expect(vm.estado == .carregando)

        await vm.carregar()
        #expect(vm.membros.map(\.id) == [anaID])

        let ana = try #require(vm.membros.first)
        await vm.remover(ana)

        #expect(vm.estado == .vazio)
        #expect(vm.aviso == TextosEquipeDeConfianca.removido)
        #expect(vm.mensagemErro == nil)
        #expect(vm.removendo == nil)
        #expect(try await api.equipeDeConfianca(estabelecimentoID: casaID).isEmpty)
    }

    @Test("Equipe vazia, sem rede e erro têm estado próprio")
    func estados() async {
        let vazia = EquipeDeConfiancaViewModel(estabelecimentoID: casaID, listar: { _ in [] }, remover: { $0 })
        await vazia.carregar()
        #expect(vazia.estado == .vazio)

        let semRede = EquipeDeConfiancaViewModel(estabelecimentoID: casaID, listar: { _ in throw ErroDaApi(codigo: .semRede) }, remover: { $0 })
        await semRede.carregar()
        #expect(semRede.estado == .semRede)

        let semPermissao = EquipeDeConfiancaViewModel(estabelecimentoID: casaID, listar: { _ in throw ErroDaApi(codigo: .semPermissao) }, remover: { $0 })
        await semPermissao.carregar()
        #expect(semPermissao.estado == .erro)
    }

    @Test("Remover um de dois conserva o outro na lista")
    func removeUmDeDois() async {
        let outro = UUID()
        let vm = EquipeDeConfiancaViewModel(estabelecimentoID: casaID, listar: { _ in [perfil(anaID, "Ana"), perfil(outro, "Bia")] }, remover: { $0 })
        await vm.carregar()
        await vm.remover(perfil(anaID, "Ana"))
        #expect(vm.membros.map(\.id) == [outro])
    }

    @Test("Cada recusa da remoção tem mensagem própria, e o membro continua na lista", arguments: [
        (ErroDaApi(codigo: .semPermissao), TextosEquipeDeConfianca.soAdministrador),
        (ErroDaApi(codigo: .semPermissao, detalhes: "conta_suspensa"), TextosEquipeDeConfianca.contaSuspensa),
        (ErroDaApi(codigo: .contaSuspensa), TextosEquipeDeConfianca.contaSuspensa),
        (ErroDaApi(codigo: .semRede), TextosEquipeDeConfianca.semRede),
        (ErroDaApi(codigo: .perfilIncompativel), TextosEquipeDeConfianca.erro),
    ])
    func recusasDaRemocao(erro: ErroDaApi, mensagem: String) async {
        let vm = EquipeDeConfiancaViewModel(estabelecimentoID: casaID, listar: { _ in [perfil(anaID, "Ana")] }, remover: { _ in throw erro })
        await vm.carregar()
        await vm.remover(perfil(anaID, "Ana"))
        #expect(vm.mensagemErro == mensagem)
        #expect(vm.membros.map(\.id) == [anaID])
        #expect(vm.aviso == nil)
    }

    @Test("Erro que não é da API vira o erro genérico")
    func erroDesconhecido() async {
        struct Falha: Error {}
        let vm = EquipeDeConfiancaViewModel(estabelecimentoID: casaID, listar: { _ in [perfil(anaID, "Ana")] }, remover: { _ in throw Falha() })
        await vm.carregar()
        await vm.remover(perfil(anaID, "Ana"))
        #expect(vm.mensagemErro == TextosEquipeDeConfianca.erro)
    }

    // MARK: Incluir na equipe

    @Test("Fora da equipe, incluir pelo dublê passa o profissional do turno verificado para a equipe")
    func incluirPeloDuble() async throws {
        let api = ApiClienteEmMemoria(cenario: .painelContratante)
        let membro = MembroDaEquipe(estabelecimentoID: casaID, profissionalID: anaID)
        let vm = IncluirNaEquipeViewModel(membro: membro, api: api)
        #expect(vm.situacao == .desconhecida)

        await vm.carregar()
        #expect(vm.situacao == .foraDaEquipe)

        await vm.incluir()
        #expect(vm.situacao == .naEquipe)
        #expect(vm.mensagemErro == nil)
        #expect(!vm.incluindo)
        #expect(try await api.equipeDeConfianca(estabelecimentoID: casaID).map(\.id) == [anaID])

        // Já na equipe, incluir de novo não chama a API.
        await vm.incluir()
        #expect(vm.situacao == .naEquipe)
    }

    @Test("Quem já está na equipe aparece como na equipe ao carregar")
    func jaNaEquipe() async {
        let vm = IncluirNaEquipeViewModel(membro: MembroDaEquipe(estabelecimentoID: casaID, profissionalID: anaID), api: ApiClienteEmMemoria(cenario: .equipeDeConfiancaComMembro))
        await vm.carregar()
        #expect(vm.situacao == .naEquipe)
    }

    @Test("Se a leitura da equipe falha, o botão fica disponível e o servidor decide")
    func leituraFalha() async {
        let vm = IncluirNaEquipeViewModel(
            membro: MembroDaEquipe(estabelecimentoID: casaID, profissionalID: anaID),
            listar: { _ in throw ErroDaApi(codigo: .semRede) }, incluir: { $0 }
        )
        await vm.carregar()
        #expect(vm.situacao == .foraDaEquipe)
    }

    @Test("Cada recusa da inclusão tem mensagem própria: sem turno cumprido, só administrador, suspensa, indisponível, rede", arguments: [
        (ErroDaApi(codigo: .semPermissao, detalhes: "sem_turno_cumprido"), TextosEquipeDeConfianca.semTurnoCumprido),
        (ErroDaApi(codigo: .semPermissao), TextosEquipeDeConfianca.soAdministrador),
        (ErroDaApi(codigo: .semPermissao, detalhes: "conta_suspensa"), TextosEquipeDeConfianca.contaSuspensa),
        (ErroDaApi(codigo: .naoEncontrado), TextosEquipeDeConfianca.indisponivel),
        (ErroDaApi(codigo: .semRede), TextosEquipeDeConfianca.semRede),
        (ErroDaApi(codigo: .perfilIncompativel), TextosEquipeDeConfianca.erro),
    ])
    func recusasDaInclusao(erro: ErroDaApi, mensagem: String) async {
        let vm = IncluirNaEquipeViewModel(
            membro: MembroDaEquipe(estabelecimentoID: casaID, profissionalID: anaID),
            listar: { _ in [] }, incluir: { _ in throw erro }
        )
        await vm.carregar()
        await vm.incluir()
        #expect(vm.mensagemErro == mensagem)
        #expect(vm.situacao == .foraDaEquipe)
        #expect(!vm.incluindo)
    }

    @Test("Sem turno cumprido no dublê, a mensagem é a do servidor")
    func semTurnoCumpridoNoDuble() async {
        let vm = IncluirNaEquipeViewModel(membro: MembroDaEquipe(estabelecimentoID: casaID, profissionalID: anaID), api: ApiClienteEmMemoria(cenario: .contratante))
        await vm.carregar()
        await vm.incluir()
        #expect(vm.mensagemErro == TextosEquipeDeConfianca.semTurnoCumprido)
        #expect(vm.situacao == .foraDaEquipe)
    }

    @Test("Dois botões do mesmo estabelecimento fazem uma só leitura; nova leitura ocorre após incluir e após remover")
    func leituraUnicaEInvalidacaoAoIncluirERemover() async throws {
        let contador = Contador()
        let biaID = UUID(uuidString: "80000000-0000-0000-0000-000000000002")!
        let cache = CacheEquipeDeConfianca()

        let listar: @Sendable (UUID) async throws -> [PerfilPublico] = { _ in
            contador.incrementar()
            return [perfil(anaID, "Ana")]
        }

        let vm1 = IncluirNaEquipeViewModel(
            membro: MembroDaEquipe(estabelecimentoID: casaID, profissionalID: anaID),
            cache: cache,
            listar: listar,
            incluir: { $0 }
        )
        let vm2 = IncluirNaEquipeViewModel(
            membro: MembroDaEquipe(estabelecimentoID: casaID, profissionalID: biaID),
            cache: cache,
            listar: listar,
            incluir: { $0 }
        )

        // Dois botões do mesmo estabelecimento:
        await vm1.carregar()
        await vm2.carregar()

        #expect(vm1.situacao == .naEquipe)
        #expect(vm2.situacao == .foraDaEquipe)
        #expect(contador.valor == 1, "dois botões do mesmo estabelecimento devem fazer apenas uma leitura")

        // Incluir invalida o cache, disparando nova leitura:
        await vm2.incluir()
        #expect(vm2.situacao == .naEquipe)
        await vm2.carregar()
        #expect(contador.valor == 2, "após incluir, deve ocorrer nova leitura na próxima consulta")

        // Remover da equipe invalida o cache, disparando nova leitura:
        let vmEquipe = EquipeDeConfiancaViewModel(
            estabelecimentoID: casaID,
            cache: cache,
            listar: listar,
            remover: { $0 }
        )
        await vmEquipe.remover(perfil(anaID, "Ana"))
        await vm1.carregar()
        #expect(contador.valor == 3, "após remover, deve ocorrer nova leitura na próxima consulta")
    }

    @Test("Dois botões do mesmo estabelecimento concorrentes deduplicam a requisição em voo")
    func leituraConcorrenteDeduplica() async throws {
        let contador = Contador()
        let biaID = UUID(uuidString: "80000000-0000-0000-0000-000000000002")!
        let cache = CacheEquipeDeConfianca()

        let listar: @Sendable (UUID) async throws -> [PerfilPublico] = { _ in
            try await Task.sleep(nanoseconds: 30_000_000)
            contador.incrementar()
            return [perfil(anaID, "Ana")]
        }

        let vm1 = IncluirNaEquipeViewModel(
            membro: MembroDaEquipe(estabelecimentoID: casaID, profissionalID: anaID),
            cache: cache,
            listar: listar,
            incluir: { $0 }
        )
        let vm2 = IncluirNaEquipeViewModel(
            membro: MembroDaEquipe(estabelecimentoID: casaID, profissionalID: biaID),
            cache: cache,
            listar: listar,
            incluir: { $0 }
        )

        async let c1: () = vm1.carregar()
        async let c2: () = vm2.carregar()
        _ = await (c1, c2)

        #expect(contador.valor == 1)
        #expect(vm1.situacao == .naEquipe)
        #expect(vm2.situacao == .foraDaEquipe)
    }

    @Test("Abrir N turnos do mesmo estabelecimento no dublê faz apenas uma chamada à API com cache compartilhado")
    func contagemDeChamadasAoAbrirNTurnos() async throws {
        final class ApiClienteComContagem: ApiClienteEncaminhador, @unchecked Sendable {
            let contador = Contador()
            var chamadasEquipe: Int { contador.valor }
            override func equipeDeConfianca(estabelecimentoID: UUID) async throws -> [PerfilPublico] {
                contador.incrementar()
                return try await super.equipeDeConfianca(estabelecimentoID: estabelecimentoID)
            }
        }

        let api = ApiClienteComContagem(base: ApiClienteEmMemoria(cenario: .painelContratante))
        let cache = CacheEquipeDeConfianca()

        // Abrir 3 turnos do mesmo estabelecimento:
        for _ in 0..<3 {
            let vm = IncluirNaEquipeViewModel(
                membro: MembroDaEquipe(estabelecimentoID: casaID, profissionalID: anaID),
                api: api,
                cache: cache
            )
            await vm.carregar()
        }
        #expect(api.chamadasEquipe == 1, "ao abrir 3 turnos com cache, apenas 1 chamada a equipeDeConfianca deve ocorrer")

        // Abrir mais 7 turnos (total 10 turnos) do mesmo estabelecimento:
        for _ in 3..<10 {
            let vm = IncluirNaEquipeViewModel(
                membro: MembroDaEquipe(estabelecimentoID: casaID, profissionalID: anaID),
                api: api,
                cache: cache
            )
            await vm.carregar()
        }
        #expect(api.chamadasEquipe == 1, "ao abrir 10 turnos com cache, continua sendo apenas 1 chamada a equipeDeConfianca")
    }

    @Test("Limpar o cache faz a leitura seguinte ir de novo à API")
    func limparCacheForcaNovaLeitura() async {
        let contador = Contador()
        let cache = CacheEquipeDeConfianca()
        let listar: @Sendable (UUID) async throws -> [PerfilPublico] = { _ in
            contador.incrementar()
            return [perfil(anaID, "Ana")]
        }
        let vm = IncluirNaEquipeViewModel(
            membro: MembroDaEquipe(estabelecimentoID: casaID, profissionalID: anaID),
            cache: cache,
            listar: listar,
            incluir: { $0 }
        )

        await vm.carregar()
        #expect(contador.valor == 1)
        await vm.carregar()
        #expect(contador.valor == 1)

        cache.limpar()
        await vm.carregar()
        #expect(contador.valor == 2, "após limpar o cache, a leitura seguinte deve ir de novo à API")
    }

    @Test("Tela da equipe atualiza o cache com o que leu, e o botão do turno responde pelo cache com a lista nova")
    func carregarTelaEquipeAtualizaCacheParaBotao() async {
        let contador = Contador()
        let cache = CacheEquipeDeConfianca()
        let biaID = UUID(uuidString: "80000000-0000-0000-0000-000000000002")!

        let vmEquipe = EquipeDeConfiancaViewModel(
            estabelecimentoID: casaID,
            cache: cache,
            listar: { _ in
                contador.incrementar()
                return [perfil(anaID, "Ana"), perfil(biaID, "Bia")]
            },
            remover: { $0 }
        )
        await vmEquipe.carregar()
        #expect(contador.valor == 1)

        // Botão do turno para Bia agora consulta pelo cache: não deve gerar nova leitura à API e deve achar Bia na equipe
        let vmBotao = IncluirNaEquipeViewModel(
            membro: MembroDaEquipe(estabelecimentoID: casaID, profissionalID: biaID),
            cache: cache,
            listar: { _ in
                contador.incrementar()
                return []
            },
            incluir: { $0 }
        )
        await vmBotao.carregar()
        #expect(contador.valor == 1, "o botão deve responder pelo cache atualizado pela tela de equipe, sem nova leitura")
        #expect(vmBotao.situacao == .naEquipe, "o botão deve ver a lista nova populada pela tela de equipe")
    }

    @Test("Invalidar durante leitura em voo impede que o resultado desatualizado entre no cache")
    func invalidarDuranteLeituraEmVooDescartaResultadoDoCache() async {
        let contador = Contador()
        let cache = CacheEquipeDeConfianca()
        let trava = TravaAssincrona()

        let vm1 = IncluirNaEquipeViewModel(
            membro: MembroDaEquipe(estabelecimentoID: casaID, profissionalID: anaID),
            cache: cache,
            listar: { _ in
                contador.incrementar()
                await trava.esperar()
                return [perfil(anaID, "Ana")]
            },
            incluir: { $0 }
        )

        let tarefaCarregamento = Task {
            await vm1.carregar()
        }

        await trava.esperarInicio()
        #expect(contador.valor == 1)

        cache.invalidar(estabelecimentoID: casaID)

        await trava.liberar()
        _ = await tarefaCarregamento.value

        let vm2 = IncluirNaEquipeViewModel(
            membro: MembroDaEquipe(estabelecimentoID: casaID, profissionalID: anaID),
            cache: cache,
            listar: { _ in
                contador.incrementar()
                return [perfil(anaID, "Ana")]
            },
            incluir: { $0 }
        )
        await vm2.carregar()
        #expect(contador.valor == 2, "a próxima chamada deve ir à API porque a leitura em voo foi invalidada")
    }
}
