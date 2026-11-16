import Foundation
import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

@Suite("Preferências de chamada: Aceito chamadas diretas (busca, 0.2.88)")
@MainActor
struct PreferenciasBuscaTests {
    @Test("A versão do texto cabe no contrato (1 a 20 caracteres)")
    func versaoDoTexto() {
        #expect((1...20).contains(PreferenciasChamadaViewModel.versaoDoTextoDaBusca.count))
    }

    @Test("Aparece na busca só com o aceite ligado e sem pendência")
    func apareceNaBusca() {
        let vm = PreferenciasChamadaViewModel(api: ApiClienteEmMemoria(cenario: .buscaDeProfissionais))
        #expect(!vm.apareceNaBusca)
        vm.aceitaChamadas = true
        #expect(vm.apareceNaBusca) // sem resposta do servidor ainda, nada pendente
    }

    @Test("Sem mexer no Aceito chamadas diretas, salvar outra preferência não manda o campo (nem com a chave desligada)")
    func naoMandaSemMexer() async {
        let vm = PreferenciasChamadaViewModel(api: ApiClienteEmMemoria(cenario: .chamadaDireta)) // busca desligada
        vm.antecedenciaMinimaH = 12
        await vm.salvar()
        #expect(vm.sucesso)
        #expect(vm.erro == nil)
        #expect(!vm.aceitaChamadas)
        #expect(vm.pendenciasParaBusca.isEmpty)
    }

    @Test("Ligar manda aceita_chamadas com a versão do texto; a resposta traz as pendências")
    func ligarComVersaoDoTexto() async {
        // O dublê recusa ligar sem a versão (campo_obrigatorio): salvar com sucesso prova que ela foi.
        let vm = PreferenciasChamadaViewModel(api: ApiClienteEmMemoria(cenario: .buscaDeProfissionais))
        vm.aceitaChamadas = true
        await vm.salvar()
        #expect(vm.sucesso)
        #expect(vm.erro == nil)
        #expect(vm.aceitaChamadas)
        #expect(vm.apareceNaBusca == vm.pendenciasParaBusca.isEmpty)
    }

    @Test("Desligar zera as pendências e tira da busca")
    func desligar() async {
        let vm = PreferenciasChamadaViewModel(api: ApiClienteEmMemoria(cenario: .buscaDeProfissionais))
        vm.aceitaChamadas = true
        await vm.salvar()
        vm.aceitaChamadas = false
        await vm.salvar()
        #expect(vm.sucesso)
        #expect(!vm.aceitaChamadas)
        #expect(vm.pendenciasParaBusca.isEmpty)
        #expect(!vm.apareceNaBusca)
    }

    @Test("Com a chave da busca desligada, ligar volta como recurso desligado")
    func chaveDesligada() async {
        let vm = PreferenciasChamadaViewModel(api: ApiClienteEmMemoria(cenario: .chamadaDireta))
        vm.aceitaChamadas = true
        await vm.salvar()
        #expect(!vm.sucesso)
        #expect(vm.erro == TextosChamadaDireta.desligado)
    }

    // F-035.11 item 1: o toggle abria desligado mesmo ligado no servidor (achado J do QA).

    @Test("Servidor com aceita_chamadas ligado: a tela abre com tudo como está salvo")
    func abreComOQueOServidorGuardou() async {
        let pausa = Date(timeIntervalSince1970: 1_800_000_000)
        let api = ApiComPreferenciasSalvas(.salvas(PreferenciaChamadas(
            aceitaDeQuemJaTrabalhou: false, pausadoAte: pausa, antecedenciaMinimaH: 24, aceitaDe: .soCnpj,
            aceitaChamadas: true, pendenciasParaBusca: [.semRegiao]
        )))
        let vm = PreferenciasChamadaViewModel(api: api)

        await vm.carregar()

        #expect(vm.erro == nil)
        #expect(!vm.carregando)
        #expect(vm.aceitaChamadas)
        #expect(!vm.aceitaDeQuemJaTrabalhou)
        #expect(vm.pausarChamadas)
        #expect(vm.pausadoAte == pausa)
        #expect(vm.antecedenciaMinimaH == 24)
        #expect(vm.aceitaDe == .soCnpj)
        #expect(vm.pendenciasParaBusca == [.semRegiao])
        #expect(!vm.apareceNaBusca)
    }

    @Test("Abrir não conta como mexer: salvar outra preferência não reenvia aceita_chamadas")
    func abrirNaoReenviaOAceite() async {
        let api = ApiComPreferenciasSalvas(.salvas(PreferenciaChamadas(aceitaChamadas: true)))
        let vm = PreferenciasChamadaViewModel(api: api)
        await vm.carregar()

        vm.antecedenciaMinimaH = 48
        await vm.salvar()

        #expect(vm.sucesso)
        #expect(api.ultimaAlteracao?.aceitaChamadas == nil)
        #expect(api.ultimaAlteracao?.versaoTextoBusca == nil)
        #expect(api.ultimaAlteracao?.antecedenciaMinimaH == 48)
    }

    @Test("Servidor sem preferencia_chamadas: a tela abre com os padrões e sem erro")
    func semPreferenciasSalvas() async {
        let vm = PreferenciasChamadaViewModel(api: ApiComPreferenciasSalvas(.semPreferencias))

        await vm.carregar()

        #expect(vm.erro == nil)
        #expect(!vm.aceitaChamadas)
        #expect(vm.aceitaDeQuemJaTrabalhou)
        #expect(!vm.pausarChamadas)
        #expect(vm.antecedenciaMinimaH == 6)
        #expect(vm.aceitaDe == .todos)
    }

    @Test("Erro ao ler as preferências mostra a mensagem e não deixa a tela carregando",
          arguments: [ErroDaApi(codigo: .semRede), ErroDaApi(codigo: .naoAutenticado), ErroDaApi(codigo: .desconhecido)])
    func erroAoLer(erro: ErroDaApi) async {
        let vm = PreferenciasChamadaViewModel(api: ApiComPreferenciasSalvas(.falha(erro)))

        await vm.carregar()

        #expect(vm.erro == TextosChamadaDireta.erro)
        #expect(!vm.carregando)
        #expect(!vm.aceitaChamadas)
    }
}

/// O servidor visto pela tela de preferências: devolve o perfil com as preferências salvas (ou um erro)
/// e guarda o último pedido de alteração. Tudo o mais vem do dublê em memória.
private final class ApiComPreferenciasSalvas: ApiClienteEncaminhador, @unchecked Sendable {
    enum Servidor {
        case salvas(PreferenciaChamadas)
        case semPreferencias
        case falha(ErroDaApi)
    }

    private let servidor: Servidor
    private let trava = NSLock()
    private var _ultimaAlteracao: AlteracaoPreferenciaChamadas?

    init(_ servidor: Servidor) {
        self.servidor = servidor
        super.init(base: ApiClienteEmMemoria(cenario: .buscaDeProfissionais))
    }

    var ultimaAlteracao: AlteracaoPreferenciaChamadas? { trava.withLock { _ultimaAlteracao } }

    override func meuPerfilDetalhado() async throws -> PerfilProfissionalDetalhado {
        // O perfil profissional vem de um dublê de profissional; o cenário da busca é de contratante.
        let perfil = try await ApiClienteEmMemoria().meuPerfilProfissional()
        switch servidor {
        case let .salvas(preferencias): return PerfilProfissionalDetalhado(perfil: perfil, preferenciaChamadas: preferencias)
        case .semPreferencias: return PerfilProfissionalDetalhado(perfil: perfil)
        case let .falha(erro): throw erro
        }
    }

    override func definirPreferenciaChamadas(_ preferencias: AlteracaoPreferenciaChamadas) async throws -> PreferenciaChamadas {
        trava.withLock { _ultimaAlteracao = preferencias }
        return PreferenciaChamadas(
            aceitaDeQuemJaTrabalhou: preferencias.aceitaDeQuemJaTrabalhou ?? true,
            antecedenciaMinimaH: preferencias.antecedenciaMinimaH ?? 6,
            aceitaChamadas: true
        )
    }
}
