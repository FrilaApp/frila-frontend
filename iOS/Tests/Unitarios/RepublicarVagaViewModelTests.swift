import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
@testable import FrilaDominio
import Testing

private actor EspiaoRepublicacao {
    private(set) var chamadas = 0
    private(set) var chaves: [UUID] = []
    private(set) var id: UUID?
    private(set) var periodo: Periodo?
    private(set) var concluido = false

    func gravar(id: UUID, periodo: Periodo, chave: UUID) {
        chamadas += 1
        chaves.append(chave)
        self.id = id
        self.periodo = periodo
    }

    func concluir() {
        concluido = true
    }
}

@Suite("RepublicarVagaViewModelTests")
struct RepublicarVagaViewModelTests {
    private static let duasHoras: TimeInterval = 2 * 3600
    private static let quatroHoras: TimeInterval = 4 * 3600
    private static let umDia: TimeInterval = 24 * 3600

    private func criarVagaNoPainel(
        id: UUID = UUID(),
        modo: ModoPreenchimento = .urgencia,
        posicoes: Int = 2
    ) throws -> VagaNoPainel {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let periodo = try Periodo(inicio: base.addingTimeInterval(Self.duasHoras), fim: base.addingTimeInterval(Self.quatroHoras))
        let resumo = VagaResumo(
            id: id,
            funcao: "Garçom",
            local: "Bar da Praia",
            regiaoAdministrativa: "Asa Sul",
            periodo: periodo,
            valor: Dinheiro(centavos: 15000)
        )
        let listaPosicoes = (0..<posicoes).map { _ in
            PosicaoNoPainel(
                id: UUID(),
                estado: .cumprida,
                profissional: nil,
                turnoID: UUID(),
                verificacao: nil,
                emAtraso: false
            )
        }
        return VagaNoPainel(
            vaga: resumo,
            modo: modo,
            estado: .encerrada,
            alertaVagaVazia: false,
            candidatosPendentes: 0,
            posicoes: listaPosicoes
        )
    }

    @Test("Republicação bem-sucedida preenche resultado e conclui")
    @MainActor
    func sucessoRepublicacao() async throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let esperadoID = UUID()
        let espiao = EspiaoRepublicacao()

        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { id, periodo, chave in
                await espiao.gravar(id: id, periodo: periodo, chave: chave)
                return VagaPublicada(vagaID: esperadoID, posicoes: [UUID(), UUID()])
            },
            aoConcluir: { _ in
                await espiao.concluir()
            }
        )

        viewModel.inicio = base.addingTimeInterval(3 * 3600)
        viewModel.fim = base.addingTimeInterval(7 * 3600)

        #expect(viewModel.validar())
        await viewModel.republicar()

        #expect(viewModel.resultado?.vagaID == esperadoID)
        #expect(viewModel.resultado?.posicoes.count == 2)
        #expect(viewModel.mensagemErro == nil)
        #expect(!viewModel.camposBloqueados)
        #expect(!viewModel.enviando)
        let idGravado = await espiao.id
        let periodoGravado = await espiao.periodo
        let chaves = await espiao.chaves
        let concluido = await espiao.concluido
        #expect(idGravado == vaga.vaga.id)
        #expect(periodoGravado != nil)
        #expect(!chaves.isEmpty)
        #expect(concluido)
    }

    @Test("Validação local: início no passado")
    @MainActor
    func inicioNoPassado() throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { _, _, _ in throw ErroDaApi(codigo: .desconhecido) }
        )

        viewModel.inicio = base.addingTimeInterval(-3600)
        viewModel.fim = base.addingTimeInterval(3600)

        #expect(!viewModel.validar())
        #expect(viewModel.erros[.inicio] == TextosRepublicarVaga.inicioNoPassado)
    }

    @Test("Validação local: fim antes ou igual ao início")
    @MainActor
    func fimAntesDoInicio() throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { _, _, _ in throw ErroDaApi(codigo: .desconhecido) }
        )

        viewModel.inicio = base.addingTimeInterval(3600)
        viewModel.fim = base.addingTimeInterval(3600)

        #expect(!viewModel.validar())
        #expect(viewModel.erros[.fim] == TextosRepublicarVaga.fimAntesDoInicio)
    }

    @Test("Validação local: turno com menos de 2 horas (RN03)")
    @MainActor
    func turnoCurto() throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { _, _, _ in throw ErroDaApi(codigo: .desconhecido) }
        )

        viewModel.inicio = base.addingTimeInterval(3600)
        viewModel.fim = base.addingTimeInterval(3600 + 3600)

        #expect(!viewModel.validar())
        #expect(viewModel.erros[.fim] == TextosRepublicarVaga.turnoCurto)
    }

    @Test("Validação local: turno com mais de 16 horas (RN03)")
    @MainActor
    func turnoLongo() throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { _, _, _ in throw ErroDaApi(codigo: .desconhecido) }
        )

        viewModel.inicio = base.addingTimeInterval(3600)
        viewModel.fim = base.addingTimeInterval(3600 + 17 * 3600)

        #expect(!viewModel.validar())
        #expect(viewModel.erros[.fim] == TextosRepublicarVaga.turnoLongo)
    }

    @Test("Validação local: modo seleção com menos de 24 horas de antecedência (RN24)")
    @MainActor
    func selecaoSemAntecedenciaLocal() throws {
        let vaga = try criarVagaNoPainel(modo: .selecao)
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { _, _, _ in throw ErroDaApi(codigo: .desconhecido) }
        )

        viewModel.inicio = base.addingTimeInterval(12 * 3600)
        viewModel.fim = base.addingTimeInterval(16 * 3600)

        #expect(!viewModel.validar())
        #expect(viewModel.erros[.inicio] == TextosRepublicarVaga.selecaoSemAntecedencia)
    }

    @Test("Erro 404 nao_encontrado: mensagem correta e campos desbloqueados")
    @MainActor
    func erroNaoEncontrado() async throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { _, _, _ in throw ErroDaApi(codigo: .naoEncontrado) }
        )
        viewModel.inicio = base.addingTimeInterval(3 * 3600)
        viewModel.fim = base.addingTimeInterval(7 * 3600)

        await viewModel.republicar()

        #expect(viewModel.mensagemErro == TextosRepublicarVaga.naoEncontrado)
        #expect(!viewModel.camposBloqueados)
    }

    @Test("Erro 403 sem_permissao: mensagem correta")
    @MainActor
    func erroSemPermissao() async throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { _, _, _ in throw ErroDaApi(codigo: .semPermissao) }
        )
        viewModel.inicio = base.addingTimeInterval(3 * 3600)
        viewModel.fim = base.addingTimeInterval(7 * 3600)

        await viewModel.republicar()

        #expect(viewModel.mensagemErro == TextosRepublicarVaga.semPermissao)
        #expect(!viewModel.camposBloqueados)
    }

    @Test("Erro 422 vaga_oculta (contrato 0.2.23): mensagem correta")
    @MainActor
    func erroVagaOculta() async throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { _, _, _ in throw ErroDaApi(codigo: .vagaOculta) }
        )
        viewModel.inicio = base.addingTimeInterval(3 * 3600)
        viewModel.fim = base.addingTimeInterval(7 * 3600)

        await viewModel.republicar()

        #expect(viewModel.mensagemErro == TextosRepublicarVaga.vagaOculta)
        #expect(!viewModel.camposBloqueados)
    }

    @Test("Erro 422 perfil_incompativel: mensagem correta")
    @MainActor
    func erroPerfilIncompativel() async throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { _, _, _ in throw ErroDaApi(codigo: .perfilIncompativel) }
        )
        viewModel.inicio = base.addingTimeInterval(3 * 3600)
        viewModel.fim = base.addingTimeInterval(7 * 3600)

        await viewModel.republicar()

        #expect(viewModel.mensagemErro == TextosRepublicarVaga.perfilIncompativel)
        #expect(!viewModel.camposBloqueados)
    }

    @Test("Sem rede: trava campos, gera chave, guarda erro e permite reenviar")
    @MainActor
    func semRedeBloqueiaCamposEGuardaChave() async throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { _, _, _ in throw ErroDaApi(codigo: .semRede) }
        )
        viewModel.inicio = base.addingTimeInterval(3 * 3600)
        viewModel.fim = base.addingTimeInterval(7 * 3600)

        await viewModel.republicar()

        #expect(viewModel.camposBloqueados)
        #expect(viewModel.mensagemErro == TextosRepublicarVaga.semRede)
        #expect(viewModel.chave != nil)
    }

    @Test("Reenvio com a mesma chave após falha de rede")
    @MainActor
    func reenvioComMesmaChave() async throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let espiao = EspiaoRepublicacao()

        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { id, periodo, chave in
                await espiao.gravar(id: id, periodo: periodo, chave: chave)
                let chamadas = await espiao.chamadas
                if chamadas == 1 {
                    throw ErroDaApi(codigo: .semRede)
                }
                return VagaPublicada(vagaID: UUID(), posicoes: [UUID()])
            }
        )
        viewModel.inicio = base.addingTimeInterval(3 * 3600)
        viewModel.fim = base.addingTimeInterval(7 * 3600)

        await viewModel.republicar()
        #expect(viewModel.camposBloqueados)
        let chamadas1 = await espiao.chamadas
        #expect(chamadas1 == 1)
        let chavePrimeira = viewModel.chave
        #expect(chavePrimeira != nil)

        await viewModel.republicar()
        let chamadas2 = await espiao.chamadas
        #expect(chamadas2 == 2)
        #expect(viewModel.resultado != nil)
        #expect(!viewModel.camposBloqueados)
        let chavesUtilizadas = await espiao.chaves
        #expect(chavesUtilizadas.count == 2)
        #expect(chavesUtilizadas[0] == chavesUtilizadas[1])
        #expect(viewModel.chave == chavePrimeira)
    }

    @Test("Toque duplo enquanto enviando não chama a API duas vezes")
    @MainActor
    func toqueDuploIgnorado() async throws {
        let vaga = try criarVagaNoPainel()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let espiao = EspiaoRepublicacao()

        let viewModel = RepublicarVagaViewModel(
            vagaOriginal: vaga,
            agora: { @Sendable in base },
            republicar: { id, periodo, chave in
                await espiao.gravar(id: id, periodo: periodo, chave: chave)
                try await Task.sleep(nanoseconds: 50_000_000)
                return VagaPublicada(vagaID: UUID(), posicoes: [UUID()])
            }
        )
        viewModel.inicio = base.addingTimeInterval(3 * 3600)
        viewModel.fim = base.addingTimeInterval(7 * 3600)

        let tarefa1 = Task { await viewModel.republicar() }
        await viewModel.republicar()

        _ = await tarefa1.result
        let chamadas = await espiao.chamadas
        #expect(chamadas == 1)
    }
}
