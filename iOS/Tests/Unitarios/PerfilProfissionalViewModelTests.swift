import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import MapKit
import Testing

@MainActor
@Suite("Cadastro e edição do perfil profissional (#98)")
struct PerfilProfissionalViewModelTests {
    private func criarDubleApi(
        funcoes: [Funcao] = [
            Funcao(id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!, nome: "Garçom", categoria: "Restaurante"),
            Funcao(id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!, nome: "Bartender", categoria: "Bar"),
            Funcao(id: UUID(uuidString: "20000000-0000-0000-0000-000000000003")!, nome: "Cozinheiro", categoria: "Cozinha"),
        ],
        perfilExistente: PerfilProfissional? = nil
    ) -> ApiClienteDuble {
        let api = ApiClienteDuble()
        api.funcoesRetorno = funcoes
        api.perfilRetorno = perfilExistente
        return api
    }

    @Test("Salvar com uma função, um ponto base e uma janela ativa o perfil (#98 C1)")
    func salvarComFuncaoPontoBaseEJanela() async throws {
        let api = criarDubleApi()
        let vm = PerfilProfissionalViewModel(api: api, modo: .criacao)

        await vm.carregar()
        #expect(vm.funcoesDisponiveis.count == 3)

        // Seleciona função
        let garcomID = vm.funcoesDisponiveis[0].id
        vm.alternarFuncao(garcomID)
        #expect(vm.funcoesSelecionadas.contains(garcomID))

        // Define ponto base
        let coordenada = try Coordenada(latitude: -15.8267, longitude: -47.9218)
        vm.definirPontoBase(coordenada, nome: "Guará II")
        #expect(vm.pontoBase == coordenada)

        // Adiciona janela
        let inicio = try HoraDoDia("18:00")
        let fim = try HoraDoDia("02:00")
        vm.adicionarJanela(diaDaSemana: 5, inicio: inicio, fim: fim)
        #expect(vm.disponibilidades.count == 1)

        // Salvar
        let sucesso = await vm.salvar()
        #expect(sucesso)
        #expect(vm.sucesso)
        #expect(vm.mensagemDeErro == nil)
        #expect(vm.modo == .edicao)
        #expect(vm.perfilSalvo != nil)
        #expect(api.dadosPerfilCriado?.funcoes == [garcomID])
        #expect(api.dadosPerfilCriado?.pontoBase == coordenada)
        #expect(api.dadosPerfilCriado?.disponibilidades.count == 1)
    }

    @Test("A janela 18:00–02:00 é aceita e exibida corretamente com dia seguinte (#98 C2)")
    func janelaAtravessandoMeiaNoite() throws {
        let api = criarDubleApi()
        let vm = PerfilProfissionalViewModel(api: api)

        let inicio = try HoraDoDia("18:00")
        let fim = try HoraDoDia("02:00")
        vm.adicionarJanela(diaDaSemana: 5, inicio: inicio, fim: fim)

        #expect(vm.disponibilidades.count == 1)
        let janela = vm.disponibilidades[0]
        #expect(janela.diaDaSemana == 5)
        #expect(janela.inicio == inicio)
        #expect(janela.fim == fim)
        #expect(janela.atravessaMeiaNoite)

        let formatado = vm.formatarJanela(janela)
        #expect(formatado.dia == "Sexta-feira")
        #expect(formatado.horario == "18:00 às 02:00 (dia seguinte)")
        #expect(formatado.horario.contains("18:00 às 02:00"))
        #expect(formatado.horario.contains("(dia seguinte)"))

        let descricao = vm.descricaoJanela(janela)
        #expect(descricao == "Sexta-feira: 18:00 às 02:00 (dia seguinte)")

        // Janela no mesmo dia sem sufixo
        let almoco = JanelaDeDisponibilidade(diaDaSemana: 1, inicio: try HoraDoDia("11:00"), fim: try HoraDoDia("15:00"))
        let formatadoAlmoco = vm.formatarJanela(almoco)
        #expect(formatadoAlmoco.horario == "11:00 às 15:00")
    }

    @Test("O ponto base não aparece em nenhuma tela de outra pessoa nem em DTOs públicos (#98 C3)")
    func pontoBaseNaoApareceParaTerceiros() throws {
        // PerfilPublico é o modelo usado para contratantes e terceiros (posições no painel, lista de candidatos)
        let reputacao = Reputacao(positivas: 5, total: 5, taxaComparecimento: 1.0, turnosConsiderados: 5, turnosRealizados: 5)
        let perfilPublico = PerfilPublico(
            id: UUID(),
            tipo: .profissional,
            nome: "João Silva",
            funcoes: ["Garçom"],
            reputacao: reputacao
        )

        // Verificamos por reflexão que PerfilPublico não tem propriedade relacionada a pontoBase ou coordenadas
        let espelho = Mirror(reflecting: perfilPublico)
        let nomesPropriedades = espelho.children.compactMap(\.label)
        #expect(!nomesPropriedades.contains("pontoBase"))
        #expect(!nomesPropriedades.contains("ponto"))
        #expect(!nomesPropriedades.contains("coordenada"))
        #expect(!nomesPropriedades.contains("latitude"))
        #expect(!nomesPropriedades.contains("longitude"))

        // Verificamos que PosicaoNoPainel usa PerfilPublico e também não expõe ponto base do profissional
        let posicao = PosicaoNoPainel(
            id: UUID(),
            estado: .confirmada,
            profissional: perfilPublico,
            turnoID: UUID(),
            verificacao: .verificado,
            emAtraso: false
        )
        let espelhoPosicao = Mirror(reflecting: posicao)
        let nomesPosicao = espelhoPosicao.children.compactMap(\.label)
        #expect(!nomesPosicao.contains("pontoBase"))
    }

    @Test("Perfil sem função bloqueia o salvar com mensagem (#98)")
    func semFuncaoBloqueiaSalvar() async throws {
        let api = criarDubleApi()
        let vm = PerfilProfissionalViewModel(api: api, modo: .criacao)
        await vm.carregar()

        // Ponto base definido, mas nenhuma função selecionada
        let coordenada = try Coordenada(latitude: -15.8267, longitude: -47.9218)
        vm.definirPontoBase(coordenada)

        let sucesso = await vm.salvar()
        #expect(!sucesso)
        #expect(!vm.sucesso)
        #expect(vm.mensagemDeErro == "Selecione ao menos uma função.")
        #expect(api.dadosPerfilCriado == nil)
    }

    @Test("Perfil sem ponto base bloqueia o salvar com mensagem (#98)")
    func semPontoBaseBloqueiaSalvar() async throws {
        let api = criarDubleApi()
        let vm = PerfilProfissionalViewModel(api: api, modo: .criacao)
        await vm.carregar()

        // Função selecionada, mas sem ponto base
        vm.alternarFuncao(vm.funcoesDisponiveis[0].id)

        let sucesso = await vm.salvar()
        #expect(!sucesso)
        #expect(!vm.sucesso)
        #expect(vm.mensagemDeErro == "Informe o ponto base.")
        #expect(api.dadosPerfilCriado == nil)
    }

    @Test("Edição posterior pelo perfil funciona sem novo login e usa meuPerfilProfissional (#98)")
    func edicaoPosteriorCarregaPerfil() async throws {
        let funcao1 = Funcao(id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!, nome: "Garçom", categoria: "Restaurante")
        let funcao2 = Funcao(id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!, nome: "Bartender", categoria: "Bar")
        let coordOriginal = try Coordenada(latitude: -15.8267, longitude: -47.9218)
        let janelaOriginal = JanelaDeDisponibilidade(diaDaSemana: 5, inicio: try HoraDoDia("18:00"), fim: try HoraDoDia("02:00"))

        let perfilExistente = PerfilProfissional(
            id: UUID(),
            usuarioID: UUID(),
            funcoes: [funcao1],
            pontoBase: coordOriginal,
            disponibilidades: [janelaOriginal],
            reputacao: Reputacao(positivas: 10, total: 10, taxaComparecimento: 1.0, turnosConsiderados: 10, turnosRealizados: 10)
        )

        let api = criarDubleApi(funcoes: [funcao1, funcao2], perfilExistente: perfilExistente)
        let vm = PerfilProfissionalViewModel(api: api, modo: .edicao)

        await vm.carregar()

        #expect(vm.modo == .edicao)
        #expect(vm.funcoesSelecionadas.contains(funcao1.id))
        #expect(!vm.funcoesSelecionadas.contains(funcao2.id))
        #expect(vm.pontoBase == coordOriginal)
        #expect(vm.disponibilidades == [janelaOriginal])
        #expect(vm.enderecoTexto.isEmpty)
        #expect(vm.descricaoPontoBase == TextosDoProfissional.Perfil.pontoBaseSalvo)

        // Usuário adiciona a segunda função
        vm.alternarFuncao(funcao2.id)

        // Adiciona novo horário no sábado
        let janelaSabado = JanelaDeDisponibilidade(diaDaSemana: 6, inicio: try HoraDoDia("19:00"), fim: try HoraDoDia("03:00"))
        vm.adicionarJanela(diaDaSemana: 6, inicio: try HoraDoDia("19:00"), fim: try HoraDoDia("03:00"))

        let salvou = await vm.salvar()
        #expect(salvou)
        #expect(vm.sucesso)
        #expect(api.alteracaoPerfilEnviada != nil)
        #expect(api.alteracaoPerfilEnviada?.funcoes?.contains(funcao1.id) == true)
        #expect(api.alteracaoPerfilEnviada?.funcoes?.contains(funcao2.id) == true)
        #expect(api.alteracaoPerfilEnviada?.disponibilidades?.contains(janelaSabado) == true)
    }

    @Test("Adicionar e remover janelas mantém ordenação por dia e início")
    func adicionarERemoverJanelas() throws {
        let api = criarDubleApi()
        let vm = PerfilProfissionalViewModel(api: api)

        let sexta = JanelaDeDisponibilidade(diaDaSemana: 5, inicio: try HoraDoDia("18:00"), fim: try HoraDoDia("02:00"))
        let domingo = JanelaDeDisponibilidade(diaDaSemana: 0, inicio: try HoraDoDia("11:00"), fim: try HoraDoDia("23:00"))
        let sabado = JanelaDeDisponibilidade(diaDaSemana: 6, inicio: try HoraDoDia("18:00"), fim: try HoraDoDia("03:00"))

        vm.adicionarJanela(diaDaSemana: 5, inicio: try HoraDoDia("18:00"), fim: try HoraDoDia("02:00"))
        vm.adicionarJanela(diaDaSemana: 0, inicio: try HoraDoDia("11:00"), fim: try HoraDoDia("23:00"))
        vm.adicionarJanela(diaDaSemana: 6, inicio: try HoraDoDia("18:00"), fim: try HoraDoDia("03:00"))

        #expect(vm.disponibilidades.count == 3)
        // Domingo (0) deve ser o primeiro, depois Sexta (5), depois Sábado (6)
        #expect(vm.disponibilidades[0] == domingo)
        #expect(vm.disponibilidades[1] == sexta)
        #expect(vm.disponibilidades[2] == sabado)

        // Remover Sexta
        vm.removerJanela(sexta)
        #expect(vm.disponibilidades.count == 2)
        #expect(vm.disponibilidades == [domingo, sabado])
    }

    @Test("Tratamento de erro da API ao salvar perfil")
    func erroApiAoSalvar() async throws {
        let api = criarDubleApi()
        api.erroAoSalvar = ErroDaApi(codigo: .perfilIncompativel)

        let vm = PerfilProfissionalViewModel(api: api, modo: .criacao)
        await vm.carregar()

        vm.alternarFuncao(vm.funcoesDisponiveis[0].id)
        vm.definirPontoBase(try Coordenada(latitude: -15.8, longitude: -47.9))

        let sucesso = await vm.salvar()
        #expect(!sucesso)
        #expect(!vm.sucesso)
        #expect(vm.mensagemDeErro != nil)
    }

    @Test("Seleção de MKMapItem define ponto base e endereço")
    func selecaoDeMapItem() throws {
        let api = criarDubleApi()
        let vm = PerfilProfissionalViewModel(api: api)

        let coord = CLLocationCoordinate2D(latitude: -15.83, longitude: -47.91)
        let placemark = MKPlacemark(coordinate: coord)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = "Guará"

        vm.selecionarSugestao(mapItem)

        #expect(vm.pontoBase?.latitude == -15.83)
        #expect(vm.pontoBase?.longitude == -47.91)
        #expect(vm.enderecoTexto.contains("Guará"))
        #expect(vm.sugestoes.isEmpty)
    }

    @Test("Janela com início igual ao fim é rejeitada com mensagem de erro (#98 ajuste 1)")
    func janelaComInicioIgualAoFimRejeitada() throws {
        let api = criarDubleApi()
        let vm = PerfilProfissionalViewModel(api: api)

        let hora = try HoraDoDia("14:00")
        vm.adicionarJanela(diaDaSemana: 1, inicio: hora, fim: hora)

        #expect(vm.disponibilidades.isEmpty)
        #expect(vm.mensagemDeErro == TextosDoProfissional.Perfil.erroJanelaDuracaoZero)
    }

    @Test("Chamadas simultâneas a salvar executam a API apenas uma vez (#98 ajuste 2)")
    func chamadasSimultaneasAoSalvarExecutamApenasUmaVez() async throws {
        let api = criarDubleApi()
        api.pausaAoCriarMs = 50
        let vm = PerfilProfissionalViewModel(api: api)
        await vm.carregar()

        let funcaoID = vm.funcoesDisponiveis[0].id
        vm.alternarFuncao(funcaoID)
        let coord = try Coordenada(latitude: -15.8267, longitude: -47.9218)
        vm.definirPontoBase(coord, nome: "Guará")

        async let chamada1 = vm.salvar()
        async let chamada2 = vm.salvar()

        let (r1, r2) = await (chamada1, chamada2)
        #expect((r1 && !r2) || (!r1 && r2))
        #expect(api.chamadasCriarPerfil == 1)
    }
}

// MARK: - Dublê de testes

@MainActor
private final class ApiClienteDuble: ApiCliente, @unchecked Sendable {
    private let base = ApiClienteEmMemoria()
    var funcoesRetorno: [Funcao]?
    var perfilRetorno: PerfilProfissional?
    var dadosPerfilCriado: DadosPerfilProfissional?
    var alteracaoPerfilEnviada: AlteracaoPerfilProfissional?
    var erroAoSalvar: Error?
    var chamadasCriarPerfil: Int = 0
    var chamadasAtualizarPerfil: Int = 0
    var pausaAoCriarMs: UInt64 = 0

    func funcoes() async throws -> [Funcao] {
        if let funcoesRetorno { return funcoesRetorno }
        return try await base.funcoes()
    }

    func meuPerfilProfissional() async throws -> PerfilProfissional {
        if let perfilRetorno { return perfilRetorno }
        return try await base.meuPerfilProfissional()
    }

    func criarPerfilProfissional(_ dados: DadosPerfilProfissional) async throws -> PerfilProfissional {
        chamadasCriarPerfil += 1
        if pausaAoCriarMs > 0 {
            try? await Task.sleep(nanoseconds: pausaAoCriarMs * 1_000_000)
        }
        if let erroAoSalvar { throw erroAoSalvar }
        dadosPerfilCriado = dados
        let funcs: [Funcao]
        if let funcoesRetorno {
            funcs = funcoesRetorno
        } else {
            funcs = try await base.funcoes()
        }
        let perfil = PerfilProfissional(
            id: UUID(),
            usuarioID: UUID(),
            funcoes: funcs.filter { dados.funcoes.contains($0.id) },
            pontoBase: dados.pontoBase,
            disponibilidades: dados.disponibilidades,
            reputacao: Reputacao(positivas: 0, total: 0, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0)
        )
        perfilRetorno = perfil
        return perfil
    }

    func atualizarPerfilProfissional(_ alteracao: AlteracaoPerfilProfissional) async throws -> PerfilProfissional {
        chamadasAtualizarPerfil += 1
        if let erroAoSalvar { throw erroAoSalvar }
        alteracaoPerfilEnviada = alteracao
        let atual = try await meuPerfilProfissional()
        let funcs: [Funcao]
        if let funcoesRetorno {
            funcs = funcoesRetorno
        } else {
            funcs = try await base.funcoes()
        }
        let novasFuncoes: [Funcao]
        if let ids = alteracao.funcoes {
            novasFuncoes = funcs.filter { ids.contains($0.id) }
        } else {
            novasFuncoes = atual.funcoes
        }
        let perfil = PerfilProfissional(
            id: atual.id,
            usuarioID: atual.usuarioID,
            funcoes: novasFuncoes,
            pontoBase: alteracao.pontoBase ?? atual.pontoBase,
            disponibilidades: alteracao.disponibilidades ?? atual.disponibilidades,
            reputacao: atual.reputacao
        )
        perfilRetorno = perfil
        return perfil
    }

    // Delegação para base
    func solicitarCodigo(email: String) async throws { try await base.solicitarCodigo(email: email) }
    func verificarCodigo(email: String, codigo: String) async throws { try await base.verificarCodigo(email: email, codigo: codigo) }
    func entrarDemonstracao(email: String, codigo: String) async throws { try await base.entrarDemonstracao(email: email, codigo: codigo) }
    func possuiSessao() async -> Bool { await base.possuiSessao() }
    func minhaConta() async throws -> Conta { try await base.minhaConta() }
    func criarConta(_ cadastro: CadastroConta) async throws -> Conta { try await base.criarConta(cadastro) }
    func cadastrarEstabelecimento(_ cadastro: CadastroEstabelecimento) async throws -> Estabelecimento { try await base.cadastrarEstabelecimento(cadastro) }
    func meusEstabelecimentos() async throws -> [EstabelecimentoDaConta] { try await base.meusEstabelecimentos() }
    func painelEstabelecimento(id: UUID, periodo: Periodo) async throws -> Painel { try await base.painelEstabelecimento(id: id, periodo: periodo) }
    func publicarVaga(_ publicacao: PublicacaoVaga) async throws -> VagaPublicada { try await base.publicarVaga(publicacao) }
    func republicarVaga(id: UUID, periodo: Periodo, chave: UUID) async throws -> VagaPublicada { try await base.republicarVaga(id: id, periodo: periodo, chave: chave) }
    func vagasAbertas(_ filtro: FiltroVagas) async throws -> [VagaNaLista] { try await base.vagasAbertas(filtro) }
    func detalheDaVaga(id: UUID) async throws -> Vaga { try await base.detalheDaVaga(id: id) }
    func candidatar(vagaID: UUID) async throws -> ResultadoCandidatura { try await base.candidatar(vagaID: vagaID) }
    func perfilPublico(id: UUID) async throws -> PerfilPublico { try await base.perfilPublico(id: id) }
    func meusTurnos() async throws -> [Turno] { try await base.meusTurnos() }
    func contatoDoTurno(id: UUID) async throws -> Contato { try await base.contatoDoTurno(id: id) }
    func fazerCheckin(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro { try await base.fazerCheckin(turnoID: turnoID, distanciaMetros: distanciaMetros, registradoEm: registradoEm) }
    func fazerCheckout(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro { try await base.fazerCheckout(turnoID: turnoID, distanciaMetros: distanciaMetros, registradoEm: registradoEm) }
    func avaliar(turnoID: UUID, resposta: Bool) async throws -> Avaliacao { try await base.avaliar(turnoID: turnoID, resposta: resposta) }
    func configuracaoDoApp() async throws -> ConfiguracaoApp { try await base.configuracaoDoApp() }
    func removerDispositivo(tokenFCM: String) async throws { try await base.removerDispositivo(tokenFCM: tokenFCM) }
    func sair(tokenFCM: String?) async { await base.sair(tokenFCM: tokenFCM) }
}
