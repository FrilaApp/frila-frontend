import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

private final class ApiPublicacaoRecusada: ApiClienteEncaminhador, @unchecked Sendable {
    private let trava = NSLock()
    private var envios = 0
    var total: Int { trava.withLock { envios } }
    override func publicarVaga(_ publicacao: PublicacaoVaga) async throws -> VagaPublicada {
        trava.withLock { envios += 1 }
        throw ErroDaApi(codigo: .horarioInvalido)
    }
}

private actor FilaPublicacaoTeste: FilaDeAcoes {
    private var avisos: [AcaoRecusada] = []
    func recusar(_ acao: AcaoPendente, codigo: CodigoErroAPI) async throws {
        avisos.append(AcaoRecusada(acao: acao, codigo: codigo))
        remover(id: acao.id)
    }
    func recusadas() -> [AcaoRecusada] { avisos }

    private var itens: [AcaoPendente] = []
    func enfileirar(_ acao: AcaoPendente) { itens.removeAll { $0.id == acao.id }; itens.append(acao) }
    func pendentes() -> [AcaoPendente] { itens }
    func remover(id: UUID) { itens.removeAll { $0.id == id } }
    func limpar() { itens.removeAll() }
}

private actor FilaPublicacaoQueFalhaNaLeitura: FilaDeAcoes {
    func recusar(_ acao: AcaoPendente, codigo: CodigoErroAPI) async throws { try await remover(id: acao.id) }
    func recusadas() -> [AcaoRecusada] { [] }

    func enfileirar(_ acao: AcaoPendente) async throws {}
    func pendentes() async throws -> [AcaoPendente] { throw ErroDaApi(codigo: .desconhecido) }
    func remover(id: UUID) async throws {}
    func limpar() async throws {}
}

private struct MonitorPublicacaoTeste: MonitorDeConexao {
    let sequencia: AsyncStream<Bool>
    func estados() -> AsyncStream<Bool> { sequencia }
}

@MainActor
@Suite("Publicar vaga (#100)")
struct PublicarVagaTests {
    private let agora = Date(timeIntervalSince1970: 1_800_000_000)
    private let idEstabelecimento = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    private let funcao = Funcao(id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!, nome: "Garçom", categoria: "Salão")

    private func estabelecimento() throws -> Estabelecimento {
        Estabelecimento(
            id: idEstabelecimento, nome: "Bistrô", tipo: .foodService, endereco: "Rua das Flores, 10",
            regiaoAdministrativa: "Águas Claras", ponto: try Coordenada(latitude: -15.78, longitude: -47.93)
        )
    }

    @Test("Publicação recusada no reenvio deixa aviso no estabelecimento correspondente")
    func avisoDePublicacaoRecusada() async throws {
        let fila = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        let fixed = agora
        let model = PublicarVagaViewModel(estabelecimento: try estabelecimento(), funcoes: [funcao], fila: fila, agora: { fixed }) { _ in
            throw ErroDaApi(codigo: .semRede)
        }
        preencher(model)
        await model.publicar()
        let acao = try #require(try await fila.pendentes().first)
        #expect(model.camposBloqueados)
        let api = ApiPublicacaoRecusada()
        let sincronizador = SincronizadorAcoes(fila: fila, api: api)
        await sincronizador.sincronizar()
        await sincronizador.sincronizar()
        await model.carregarRecusaDaFila()
        #expect(api.total == 1)
        #expect(try await fila.pendentes().isEmpty)
        #expect(model.recusaDaFila == AcaoRecusada(acao: acao, codigo: .horarioInvalido))
        #expect(!model.camposBloqueados)
        let outra = Estabelecimento(id: UUID(), nome: "Outro", tipo: .foodService, endereco: "Outro endereço", regiaoAdministrativa: "Águas Claras", ponto: try Coordenada(latitude: -15.78, longitude: -47.93))
        let outroModel = PublicarVagaViewModel(estabelecimento: outra, fila: fila) { _ in throw ErroDaApi(codigo: .semRede) }
        await outroModel.carregarRecusaDaFila()
        #expect(outroModel.recusaDaFila == nil)
        await model.fecharAvisoDaFila()
        #expect(model.recusaDaFila == nil)
        #expect(try await fila.recusadas().isEmpty)
        try await fila.enfileirar(acao)
        #expect(try await fila.pendentes().isEmpty)
    }

    @Test("Aviso antigo não esconde a recusa da publicação atual")
    func duasRecusasDesbloqueiamAtual() async throws {
        let fila = FilaPublicacaoTeste()
        let fixed = agora
        let model = PublicarVagaViewModel(estabelecimento: try estabelecimento(), funcoes: [funcao], fila: fila, agora: { fixed }) { _ in
            throw ErroDaApi(codigo: .semRede)
        }
        preencher(model)
        await model.publicar()
        let anterior = try #require(await fila.pendentes().first)
        try await fila.recusar(anterior, codigo: .horarioInvalido)
        await model.carregarRecusaDaFila()
        await model.publicar()
        let atual = try #require(await fila.pendentes().first)
        try await fila.recusar(atual, codigo: .semPermissao)
        await model.carregarRecusaDaFila()
        #expect(model.recusaDaFila?.id == atual.id)
        #expect(!model.camposBloqueados)
    }

    private func modelo() throws -> PublicarVagaViewModel {
        let fila = FilaPublicacaoTeste()
        let estabelecimento = try estabelecimento()
        let fixed = agora
        let vm = PublicarVagaViewModel(estabelecimento: estabelecimento, funcoes: [funcao], fila: fila, agora: { fixed }) { _ in
            throw ErroDaApi(codigo: .desconhecido)
        }
        preencher(vm)
        return vm
    }

    private func preencher(_ vm: PublicarVagaViewModel) {
        vm.funcaoID = funcao.id
        vm.inicio = agora.addingTimeInterval(4 * 3_600)
        vm.fim = agora.addingTimeInterval(7 * 3_600)
        vm.local = "Rua das Flores, 10"
        vm.valorTexto = "14000"
        vm.posicoesTexto = "2"
        vm.responsavelLocal = "Renata no balcão"
    }

    @Test("validar aponta cada campo obrigatório antes de chamar a API", arguments: [
        .estabelecimento, .funcao, .inicio, .fim, .local, .ponto, .valor, .posicoes, .responsavel,
    ] as [CampoPublicacaoVaga])
    func validarCampoObrigatorio(campo: CampoPublicacaoVaga) throws {
        let vm = try modelo()
        switch campo {
        case .estabelecimento, .ponto: vm.estabelecimento = nil
        case .funcao: vm.funcaoID = nil
        case .inicio: vm.inicio = agora
        case .fim: vm.fim = vm.inicio
        case .local: vm.local = "  "
        case .valor: vm.valorTexto = "0"
        case .posicoes: vm.posicoesTexto = "0"
        case .responsavel: vm.responsavelLocal = ""
        case .inclusos, .traje, .rateio, .observacoes, .modo: break
        }
        #expect(!vm.validar())
        #expect(vm.erros[campo] != nil)
    }

    @Test("Publicar não chama a rede se RN02 encontrar campo faltando")
    func semChamadaAntesDaValidacao() async throws {
        let api = ApiClienteEmMemoria()
        let fixed = agora
        let vm = PublicarVagaViewModel(estabelecimento: try estabelecimento(), funcoes: [funcao], fila: FilaPublicacaoTeste(), agora: { fixed }) { try await api.publicarVaga($0) }
        vm.funcaoID = funcao.id
        await vm.publicar()
        #expect(await api.chamadasAPublicarVaga == 0)
        #expect(vm.erros[.valor] != nil)
    }

    @Test("Fila reenvia a mesma chave após a resposta perdida, e a API simulada cria uma vaga")
    func repeteChaveSemDuplicarVaga() async throws {
        let api = ApiClienteEmMemoria(cenario: .respostaPerdidaPublicacao)
        let fila = FilaPublicacaoTeste()
        let fixed = agora
        let vm = PublicarVagaViewModel(estabelecimento: try estabelecimento(), funcoes: [funcao], fila: fila, agora: { fixed }) { try await api.publicarVaga($0) }
        preencher(vm)

        await vm.publicar()
        let chavePrimeiraTentativa = try #require(vm.publicacaoPendente?.chave)
        #expect(await fila.pendentes().count == 1)
        await vm.publicar()

        #expect(await api.chamadasAPublicarVaga == 2)
        #expect(await api.chavesPublicacaoRecebidas == [chavePrimeiraTentativa, chavePrimeiraTentativa])
        #expect(await api.vagasCriadas == 1)
        #expect(await fila.pendentes().isEmpty)
        #expect(vm.resultado != nil)
    }

    @Test("Uma resposta inválida após gravar mantém a chave e não duplica na tentativa seguinte")
    func respostaInvalidaRepeteMesmaChave() async throws {
        let api = ApiClienteEmMemoria(cenario: .respostaInvalidaPublicacao)
        let fila = FilaPublicacaoTeste()
        let fixed = agora
        let vm = PublicarVagaViewModel(estabelecimento: try estabelecimento(), funcoes: [funcao], fila: fila, agora: { fixed }) { try await api.publicarVaga($0) }
        preencher(vm)

        await vm.publicar()
        let chaveOriginal = try #require(vm.publicacaoPendente?.chave)
        #expect(await fila.pendentes().count == 1)
        await vm.publicar()

        #expect(await api.chavesPublicacaoRecebidas == [chaveOriginal, chaveOriginal])
        #expect(await api.vagasCriadas == 1)
        #expect(await fila.pendentes().isEmpty)
        #expect(vm.resultado != nil)
    }

    @Test("View model novo restaura a publicação pendente e tenta com a mesma chave")
    func restauraPublicacaoPendenteAoReabrir() async throws {
        let api = ApiClienteEmMemoria(cenario: .respostaPerdidaPublicacao)
        let fila = FilaPublicacaoTeste()
        let fixed = agora
        let estabelecimento = try estabelecimento()
        let primeiro = PublicarVagaViewModel(estabelecimento: estabelecimento, funcoes: [funcao], fila: fila, agora: { fixed }) { try await api.publicarVaga($0) }
        preencher(primeiro)
        await primeiro.publicar()
        let chaveOriginal = try #require(primeiro.publicacaoPendente?.chave)

        let reaberto = PublicarVagaViewModel(estabelecimento: estabelecimento, funcoes: [funcao], fila: fila, agora: { fixed }) { try await api.publicarVaga($0) }
        await reaberto.restaurarPublicacaoPendente()
        #expect(reaberto.publicacaoPendente?.chave == chaveOriginal)
        #expect(reaberto.camposBloqueados)
        await reaberto.publicar()

        #expect(await api.chavesPublicacaoRecebidas == [chaveOriginal, chaveOriginal])
        #expect(await api.vagasCriadas == 1)
        #expect(await fila.pendentes().isEmpty)
        #expect(reaberto.resultado != nil)
    }

    @Test("Falha ao ler a fila encerra o estado de restauração")
    func leituraFalhaDestravaPublicar() async throws {
        let fila = FilaPublicacaoQueFalhaNaLeitura()
        let fixed = agora
        let vm = PublicarVagaViewModel(estabelecimento: try estabelecimento(), funcoes: [funcao], fila: fila, agora: { fixed }) { _ in
            throw ErroDaApi(codigo: .desconhecido)
        }

        await vm.restaurarPublicacaoPendente()

        #expect(!vm.restaurandoPublicacao)
        #expect(vm.mensagemErro != nil)
    }

    @Test("O sincronizador mantém publicação quando a API retorna resposta inválida")
    func sincronizadorMantemChaveEmRespostaInvalida() async throws {
        let api = ApiClienteEmMemoria(cenario: .respostaInvalidaPublicacao)
        let fila = FilaPublicacaoTeste()
        let periodo = try Periodo(inicio: agora.addingTimeInterval(4 * 3_600), fim: agora.addingTimeInterval(7 * 3_600))
        let publicacao = PublicacaoVaga(
            estabelecimentoID: idEstabelecimento, funcaoID: funcao.id, periodo: periodo,
            local: "Rua das Flores, 10", regiaoAdministrativa: "Águas Claras", ponto: try Coordenada(latitude: -15.78, longitude: -47.93),
            valor: Dinheiro(centavos: 14_000), posicoes: 2,
            inclusos: Inclusos(refeicao: false, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Renata no balcão", modo: .urgencia, alertaAntecedenciaMinutos: 180, chave: UUID()
        )
        let acao = AcaoPendente(tipo: .publicacaoVaga, instanteDoToque: agora, chave: publicacao.chave, publicacao: publicacao)
        await fila.enfileirar(acao)

        await SincronizadorAcoes(fila: fila, api: api).sincronizar()

        #expect(await fila.pendentes().first?.chave == publicacao.chave)
        #expect(await api.vagasCriadas == 1)
    }

    @Test("O sincronizador reenvia a publicação persistida usando a mesma chave após resposta perdida")
    func sincronizadorRepeteChaveDaFila() async throws {
        let api = ApiClienteEmMemoria(cenario: .respostaPerdidaPublicacao)
        let fila = FilaPublicacaoTeste()
        let fixed = agora
        let periodo = try Periodo(inicio: agora.addingTimeInterval(4 * 3_600), fim: agora.addingTimeInterval(7 * 3_600))
        let publicacao = PublicacaoVaga(
            estabelecimentoID: idEstabelecimento, funcaoID: funcao.id, periodo: periodo,
            local: "Rua das Flores, 10", regiaoAdministrativa: "Águas Claras", ponto: try Coordenada(latitude: -15.78, longitude: -47.93),
            valor: Dinheiro(centavos: 14_000), posicoes: 2,
            inclusos: Inclusos(refeicao: false, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Renata no balcão", modo: .urgencia, alertaAntecedenciaMinutos: 180, chave: UUID()
        )
        await fila.enfileirar(AcaoPendente(tipo: .publicacaoVaga, instanteDoToque: fixed, chave: publicacao.chave, publicacao: publicacao))
        let sincronizador = SincronizadorAcoes(fila: fila, api: api)
        let estados = AsyncStream<Bool> { continuacao in
            continuacao.yield(true)
            continuacao.yield(false)
            continuacao.yield(true)
            continuacao.finish()
        }
        await ReenvioAoReconectar(monitor: MonitorPublicacaoTeste(sequencia: estados), sincronizador: sincronizador).acompanhar()

        #expect(await api.chamadasAPublicarVaga == 2)
        #expect(await api.chavesPublicacaoRecebidas == [publicacao.chave, publicacao.chave])
        #expect(await api.vagasCriadas == 1)
        #expect(await fila.pendentes().isEmpty)
        #expect(await api.publicacoesRecebidas.allSatisfy { $0.modo == .urgencia && $0.alertaAntecedenciaMinutos == 180 })
    }

    @Test("O payload fixa modo urgência e alerta padrão de três horas")
    func padroesDaPublicacao() async throws {
        let api = ApiClienteEmMemoria()
        let fixed = agora
        let vm = PublicarVagaViewModel(estabelecimento: try estabelecimento(), funcoes: [funcao], fila: FilaPublicacaoTeste(), agora: { fixed }) { try await api.publicarVaga($0) }
        preencher(vm)
        await vm.publicar()
        #expect(vm.resultado != nil)
        #expect(vm.publicacaoPendente == nil)
        #expect(await api.publicacoesRecebidas.last?.modo == .urgencia)
        #expect(await api.publicacoesRecebidas.last?.alertaAntecedenciaMinutos == 180)
        #expect(await api.publicacoesRecebidas.last?.inclusos == Inclusos(refeicao: false, transporte: false, exigeMaterialProprio: false))
    }

    @Test("A publicação leva a região administrativa do estabelecimento (contrato 0.2.20)")
    func regiaoAdministrativaDoEstabelecimento() async throws {
        let api = ApiClienteEmMemoria()
        let fixed = agora
        let vm = PublicarVagaViewModel(estabelecimento: try estabelecimento(), funcoes: [funcao], fila: FilaPublicacaoTeste(), agora: { fixed }) { try await api.publicarVaga($0) }
        preencher(vm)
        await vm.publicar()
        let vagaID = try #require(vm.resultado?.vagaID)
        #expect(await api.publicacoesRecebidas.last?.regiaoAdministrativa == "Águas Claras")
        #expect(try await api.detalheDaVaga(id: vagaID).regiaoAdministrativa == "Águas Claras")
    }

    @Test("Rótulo de fechamento e aviso informativo nos três estados: nada enviado, na fila e publicado")
    func rotuloEAvisoNosTresEstados() async throws {
        final class EstadoRede: @unchecked Sendable {
            var semRede = false
        }
        let rede = EstadoRede()
        let api = ApiClienteEmMemoria()
        let fila = FilaPublicacaoTeste()
        let fixed = agora
        let vm = PublicarVagaViewModel(estabelecimento: try estabelecimento(), funcoes: [funcao], fila: fila, agora: { fixed }) { publicacao in
            if rede.semRede {
                throw ErroDaApi(codigo: .semRede)
            }
            return try await api.publicarVaga(publicacao)
        }
        preencher(vm)

        // 1. Nada enviado: botão é "Cancelar" e aviso informativo não aparece
        #expect(vm.publicacaoPendente == nil)
        #expect(vm.resultado == nil)
        #expect(vm.textoAoFechar == "Cancelar")
        #expect(!vm.mostraAvisoPublicacaoContinua)

        // 2. Na fila (após envio sem rede): botão passa a "Voltar" e aviso informativo aparece
        rede.semRede = true
        await vm.publicar()
        #expect(vm.publicacaoPendente != nil)
        #expect(vm.resultado == nil)
        #expect(vm.textoAoFechar == "Voltar")
        #expect(vm.mostraAvisoPublicacaoContinua)

        // 3. Publicado com sucesso: botão continua "Voltar" e aviso informativo desaparece
        rede.semRede = false
        await vm.publicar()
        #expect(vm.resultado != nil)
        #expect(vm.publicacaoPendente == nil)
        #expect(vm.textoAoFechar == "Voltar")
        #expect(!vm.mostraAvisoPublicacaoContinua)
    }
}
