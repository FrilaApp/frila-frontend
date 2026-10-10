import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

private final class RelogioDeTeste: Relogio, @unchecked Sendable {
    private let trava = NSLock()
    private var _agora: Date
    init(_ agora: Date) { _agora = agora }
    var agora: Date { trava.withLock { _agora } }
    func avancar(para instante: Date) { trava.withLock { _agora = instante } }
}

private final class ColetorChaves: @unchecked Sendable {
    private let trava = NSLock()
    private var _chaves: [UUID] = []
    func adicionar(_ chave: UUID) { trava.withLock { _chaves.append(chave) } }
    var chaves: [UUID] { trava.withLock { _chaves } }
}

private let hora: TimeInterval = 3_600

private struct Montagem {
    let api: ApiClienteEmMemoria
    let relogio: RelogioDeTeste
    let agora: Date
    let vagaID: UUID
    let casaID: UUID
    let inicio: Date

    static func montar(
        posicoes: Int = 3,
        emHoras: Double = 72,
        cenario: ApiClienteEmMemoria.Cenario = .contratante
    ) async throws -> Montagem {
        let agora = Date(timeIntervalSince1970: 1_800_000_000)
        let relogio = RelogioDeTeste(agora)
        let api = ApiClienteEmMemoria(cenario: cenario, relogio: relogio)
        let casa = try #require(try await api.meusEstabelecimentos().first)
        let funcao = try #require(try await api.funcoes().first)
        let inicio = agora.addingTimeInterval(emHoras * hora)
        let vagaID = try await api.publicarVaga(PublicacaoVaga(
            estabelecimentoID: casa.id, funcaoID: funcao.id,
            periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(4 * hora)),
            local: "CLS 405, Asa Sul, Brasília - DF", regiaoAdministrativa: "Plano Piloto",
            ponto: try Coordenada(latitude: -15.8121, longitude: -47.8997), valor: Dinheiro(centavos: 12000),
            posicoes: posicoes, inclusos: Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Marina", modo: .selecao, chave: UUID()
        )).vagaID
        return Montagem(api: api, relogio: relogio, agora: agora, vagaID: vagaID, casaID: casa.id, inicio: inicio)
    }

    func painel() async throws -> Painel {
        let periodo = try Periodo(inicio: agora.addingTimeInterval(-hora), fim: agora.addingTimeInterval(240 * hora))
        return try await api.painelEstabelecimento(id: casaID, periodo: periodo)
    }

    func vagaNoPainel() async throws -> VagaNoPainel {
        let p = try await painel()
        return try #require(p.vagas.first { $0.vaga.id == vagaID })
    }
}

@MainActor
@Suite("Republicar posições restantes em urgência (D1-C, contrato 0.2.41)")
struct RepublicarPosicoesRestantesTests {

    @Test("Caminho feliz: seleção fechada com sobras republica em urgência e abre a vaga nova")
    func caminhoFeliz() async throws {
        let m = try await Montagem.montar(posicoes: 3)
        // Avança o relógio para além das 24 h antes do início (quando a seleção fecha sozinha)
        m.relogio.avancar(para: m.inicio.addingTimeInterval(-23 * hora))
        _ = await m.api.fecharSelecoes()

        let vagaAntes = try await m.vagaNoPainel()
        #expect(vagaAntes.republicavelEmUrgencia == 3)
        #expect(vagaAntes.podeRepublicarEmUrgencia == true)

        var navegouPara: UUID?
        var painelAtualizado = false
        let vm = RepublicarPosicoesRestantesViewModel(
            vagaID: m.vagaID,
            posicoesRestantes: 3,
            api: m.api,
            aoNavegarParaVaga: { navegouPara = $0 },
            atualizarPainel: { painelAtualizado = true }
        )

        await vm.executar()

        #expect(vm.erro == nil)
        #expect(vm.vagaPublicada != nil)
        #expect(vm.vagaPublicada?.posicoes.count == 3)
        #expect(navegouPara != nil)
        #expect(navegouPara == vm.vagaPublicada?.vagaID)
        #expect(painelAtualizado == true)

        // No painel, a vaga nova de urgência deve existir
        let p = try await m.painel()
        let vagaNova = try #require(p.vagas.first { $0.vaga.id == vm.vagaPublicada?.vagaID })
        #expect(vagaNova.modo == .urgencia)
        #expect(vagaNova.vaga.periodo.inicio == vagaAntes.vaga.periodo.inicio)
    }

    @Test("Idempotência: reenvio com a mesma chave devolve a mesma vaga e não cria duplicata")
    func idempotenciaMesmaChave() async throws {
        let m = try await Montagem.montar(posicoes: 2)
        m.relogio.avancar(para: m.inicio.addingTimeInterval(-20 * hora))
        _ = await m.api.fecharSelecoes()

        let chave = UUID()
        let primeira = try await m.api.republicarPosicoesRestantes(vagaID: m.vagaID, chave: chave)
        let segunda = try await m.api.republicarPosicoesRestantes(vagaID: m.vagaID, chave: chave)

        #expect(primeira.vagaID == segunda.vagaID)
        #expect(primeira.posicoes == segunda.posicoes)
        let totalChamadas = await m.api.chamadasARepublicarPosicoesRestantes
        #expect(totalChamadas == 2)

        let p = try await m.painel()
        let republicadas = p.vagas.filter { $0.vaga.id == primeira.vagaID }
        #expect(republicadas.count == 1)
    }

    @Test("Falha de rede mantém a mesma chave para o próximo toque (I3)")
    func falhaDeRedeMantemChave() async {
        let vagaID = UUID()
        let coletor = ColetorChaves()

        let vm = RepublicarPosicoesRestantesViewModel(
            vagaID: vagaID,
            posicoesRestantes: 2,
            republicarRPC: { _, chave in
                coletor.adicionar(chave)
                throw ErroDaApi(codigo: .semRede)
            }
        )

        await vm.executar()
        #expect(vm.erro == TextosRepublicarPosicoesRestantes.semRede)
        #expect(coletor.chaves.count == 1)
        let primeiraChave = vm.chaveAtual
        #expect(primeiraChave != nil)

        // Segundo toque tenta novamente
        await vm.executar()
        #expect(coletor.chaves.count == 2)
        #expect(coletor.chaves[0] == coletor.chaves[1])
        #expect(vm.chaveAtual == primeiraChave)
    }

    @Test("Recusa: nao_e_selecao quando a origem é de modo urgência")
    func recusaNaoESelecao() async throws {
        let agora = Date(timeIntervalSince1970: 1_800_000_000)
        let relogio = RelogioDeTeste(agora)
        let api = ApiClienteEmMemoria(cenario: .contratante, relogio: relogio)
        let casa = try #require(try await api.meusEstabelecimentos().first)
        let funcao = try #require(try await api.funcoes().first)
        let inicio = agora.addingTimeInterval(3 * hora)
        let vagaUrgencia = try await api.publicarVaga(PublicacaoVaga(
            estabelecimentoID: casa.id, funcaoID: funcao.id,
            periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(4 * hora)),
            local: "Local", regiaoAdministrativa: "Plano Piloto",
            ponto: try Coordenada(latitude: -15.8121, longitude: -47.8997), valor: Dinheiro(centavos: 12000),
            posicoes: 1, inclusos: Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Marina", modo: .urgencia, chave: UUID()
        )).vagaID

        var erroRecebido: ErroDaApi?
        do {
            _ = try await api.republicarPosicoesRestantes(vagaID: vagaUrgencia, chave: UUID())
        } catch let err as ErroDaApi {
            erroRecebido = err
        }

        #expect(erroRecebido?.codigo == .republicacaoIndisponivel)
        #expect(erroRecebido?.detalhes == MotivoRepublicacaoIndisponivel.naoESelecao.rawValue)
    }

    @Test("Recusa: selecao_em_curso quando a vaga ainda está publicada (seleção em andamento)")
    func recusaSelecaoEmCurso() async throws {
        let m = try await Montagem.montar(posicoes: 2)
        // Não avança o relógio: ainda faltam 72 h para o início (seleção em aberto)

        var erroRecebido: ErroDaApi?
        do {
            _ = try await m.api.republicarPosicoesRestantes(vagaID: m.vagaID, chave: UUID())
        } catch let err as ErroDaApi {
            erroRecebido = err
        }

        #expect(erroRecebido?.codigo == .republicacaoIndisponivel)
        #expect(erroRecebido?.detalhes == MotivoRepublicacaoIndisponivel.selecaoEmCurso.rawValue)
    }

    @Test("Recusa: vaga_cancelada quando a casa cancelou a vaga original")
    func recusaVagaCancelada() async throws {
        let m = try await Montagem.montar(posicoes: 2)
        _ = try await m.api.cancelarVaga(id: m.vagaID, motivo: "Fechou o restaurante")

        var erroRecebido: ErroDaApi?
        do {
            _ = try await m.api.republicarPosicoesRestantes(vagaID: m.vagaID, chave: UUID())
        } catch let err as ErroDaApi {
            erroRecebido = err
        }

        #expect(erroRecebido?.codigo == .republicacaoIndisponivel)
        #expect(erroRecebido?.detalhes == MotivoRepublicacaoIndisponivel.vagaCancelada.rawValue)
    }

    @Test("Recusa: ja_comecou quando o horário de início já passou")
    func recusaJaComecou() async throws {
        let m = try await Montagem.montar(posicoes: 2)
        // Avança o relógio para depois do início
        m.relogio.avancar(para: m.inicio.addingTimeInterval(1 * hora))
        _ = await m.api.fecharSelecoes()

        var erroRecebido: ErroDaApi?
        do {
            _ = try await m.api.republicarPosicoesRestantes(vagaID: m.vagaID, chave: UUID())
        } catch let err as ErroDaApi {
            erroRecebido = err
        }

        #expect(erroRecebido?.codigo == .republicacaoIndisponivel)
        #expect(erroRecebido?.detalhes == MotivoRepublicacaoIndisponivel.jaComecou.rawValue)
    }

    @Test("Recusa: sem_posicoes_restantes quando todas as posições foram preenchidas")
    func recusaSemPosicoesRestantes() async throws {
        let m = try await Montagem.montar(posicoes: 1)
        let perfilAna = PerfilPublico(
            id: UUID(uuidString: "81000000-0000-0000-0000-000000000001")!, tipo: .profissional, nome: "Ana Cunha", funcoes: ["Garçom"],
            reputacao: Reputacao(positivas: 1, total: 2, taxaComparecimento: 1, turnosConsiderados: 2, turnosRealizados: 2)
        )
        let candID = try await m.api.receberCandidatura(vagaID: m.vagaID, de: perfilAna)
        _ = try await m.api.escolherCandidato(candidaturaID: candID)

        m.relogio.avancar(para: m.inicio.addingTimeInterval(-20 * hora))
        _ = await m.api.fecharSelecoes()

        var erroRecebido: ErroDaApi?
        do {
            _ = try await m.api.republicarPosicoesRestantes(vagaID: m.vagaID, chave: UUID())
        } catch let err as ErroDaApi {
            erroRecebido = err
        }

        #expect(erroRecebido?.codigo == .republicacaoIndisponivel)
        #expect(erroRecebido?.detalhes == MotivoRepublicacaoIndisponivel.semPosicoesRestantes.rawValue)
    }

    @Test("Recusa: ja_republicada quando já existe republicação ativa, e libera quando cancelada (RR-RN05)")
    func recusaJaRepublicadaELiberacao() async throws {
        let m = try await Montagem.montar(posicoes: 2)
        m.relogio.avancar(para: m.inicio.addingTimeInterval(-20 * hora))
        _ = await m.api.fecharSelecoes()

        // Primeira republicação com sucesso
        let pub1 = try await m.api.republicarPosicoesRestantes(vagaID: m.vagaID, chave: UUID())

        // Segunda tentativa com OUTRA chave recebe ja_republicada
        var erroRecebido: ErroDaApi?
        do {
            _ = try await m.api.republicarPosicoesRestantes(vagaID: m.vagaID, chave: UUID())
        } catch let err as ErroDaApi {
            erroRecebido = err
        }

        #expect(erroRecebido?.codigo == .republicacaoIndisponivel)
        #expect(erroRecebido?.detalhes == MotivoRepublicacaoIndisponivel.jaRepublicada.rawValue)

        // Cancela a vaga republicada: liberta o índice RR-RN05
        _ = try await m.api.cancelarVaga(id: pub1.vagaID, motivo: "Cancelando republicada")

        // Agora uma nova republicação pode acontecer com sucesso
        let pub2 = try await m.api.republicarPosicoesRestantes(vagaID: m.vagaID, chave: UUID())
        #expect(pub2.vagaID != pub1.vagaID)
    }

    @Test("Recusa: vaga_oculta quando moderada pela Equipe Frila")
    func recusaVagaOculta() async throws {
        let m = try await Montagem.montar(posicoes: 2)
        m.relogio.avancar(para: m.inicio.addingTimeInterval(-20 * hora))
        _ = await m.api.fecharSelecoes()

        await m.api.moderar(vagaID: m.vagaID, oculta: true)

        var erroRecebido: ErroDaApi?
        do {
            _ = try await m.api.republicarPosicoesRestantes(vagaID: m.vagaID, chave: UUID())
        } catch let err as ErroDaApi {
            erroRecebido = err
        }
        #expect(erroRecebido?.codigo == .vagaOculta)

        let vm = RepublicarPosicoesRestantesViewModel(
            vagaID: m.vagaID,
            posicoesRestantes: 2,
            republicarRPC: { _, _ in throw ErroDaApi(codigo: .vagaOculta) }
        )

        await vm.executar()
        #expect(vm.erro == TextosRepublicarPosicoesRestantes.vagaOculta)
    }

    @Test("Recusa: perfil_incompativel para quem não é contratante")
    func recusaPerfilIncompativel() async throws {
        // Dublê com perfil profissional (cenário .sucesso)
        let apiProfissional = ApiClienteEmMemoria(cenario: .sucesso)
        var erroRecebido: ErroDaApi?
        do {
            _ = try await apiProfissional.republicarPosicoesRestantes(vagaID: UUID(), chave: UUID())
        } catch let err as ErroDaApi {
            erroRecebido = err
        }
        #expect(erroRecebido?.codigo == .perfilIncompativel)

        let vm = RepublicarPosicoesRestantesViewModel(
            vagaID: UUID(),
            posicoesRestantes: 2,
            republicarRPC: { _, _ in throw ErroDaApi(codigo: .perfilIncompativel) }
        )

        await vm.executar()
        #expect(vm.erro == TextosRepublicarPosicoesRestantes.perfilIncompativel)
    }

    @Test("Recusa: sem_permissao quando a vaga pertence a outra casa")
    func recusaOutraCasa() async throws {
        let m = try await Montagem.montar(posicoes: 2)
        m.relogio.avancar(para: m.inicio.addingTimeInterval(-20 * hora))
        _ = await m.api.fecharSelecoes()

        // Altera o estabelecimento da vaga para outra casa
        await m.api.alterarEstabelecimento(vagaID: m.vagaID, estabelecimentoID: UUID())

        var erroRecebido: ErroDaApi?
        do {
            _ = try await m.api.republicarPosicoesRestantes(vagaID: m.vagaID, chave: UUID())
        } catch let err as ErroDaApi {
            erroRecebido = err
        }
        #expect(erroRecebido?.codigo == .semPermissao)
    }

    @Test("Recusa: nao_encontrado quando o id da vaga não existe")
    func recusaNaoEncontrado() async throws {
        let api = ApiClienteEmMemoria(cenario: .contratante)
        var erroRecebido: ErroDaApi?
        do {
            _ = try await api.republicarPosicoesRestantes(vagaID: UUID(), chave: UUID())
        } catch let err as ErroDaApi {
            erroRecebido = err
        }
        #expect(erroRecebido?.codigo == .naoEncontrado)
    }

    @Test("Recusa: conta_suspensa para contratante com suspensão ativa")
    func recusaContaSuspensa() async {
        let vm = RepublicarPosicoesRestantesViewModel(
            vagaID: UUID(),
            posicoesRestantes: 2,
            republicarRPC: { _, _ in throw ErroDaApi(codigo: .semPermissao, detalhes: "conta_suspensa") }
        )

        await vm.executar()
        #expect(vm.erro == TextosRepublicarPosicoesRestantes.contaSuspensa)
    }

    @Test("Botão: visibilidade obedece exclusivamente a republicavel_em_urgencia > 0 (I2)")
    func visibilidadeDoBotao() {
        let resumo = VagaResumo(
            id: UUID(),
            funcao: "Garçom",
            local: "Bistrô",
            regiaoAdministrativa: "Plano Piloto",
            periodo: try! Periodo(inicio: Date(), fim: Date().addingTimeInterval(4 * hora)),
            valor: Dinheiro(centavos: 12000)
        )

        // 1. Quando nulo: falso
        let v1 = VagaNoPainel(
            vaga: resumo, modo: .selecao, estado: .publicada, alertaVagaVazia: false,
            candidatosPendentes: 0, posicoes: [], republicavelEmUrgencia: nil
        )
        #expect(v1.podeRepublicarEmUrgencia == false)

        // 2. Quando 0: falso
        let v2 = VagaNoPainel(
            vaga: resumo, modo: .selecao, estado: .encerrada, alertaVagaVazia: false,
            candidatosPendentes: 0, posicoes: [], republicavelEmUrgencia: 0
        )
        #expect(v2.podeRepublicarEmUrgencia == false)

        // 3. Quando > 0: verdadeiro
        let v3 = VagaNoPainel(
            vaga: resumo, modo: .selecao, estado: .encerrada, alertaVagaVazia: false,
            candidatosPendentes: 0, posicoes: [], republicavelEmUrgencia: 2
        )
        #expect(v3.podeRepublicarEmUrgencia == true)
    }

    @Test("Push: selecao_encerrada abre a vaga no contratante (I6)")
    func pushSelecaoEncerradaAbreVaga() {
        let vagaID = UUID()
        let aviso = AvisoDoContratante(tipo: "selecao_encerrada", payload: ["vaga_id": vagaID.uuidString])
        #expect(aviso == .vaga(vagaID: vagaID))

        let roteador = RoteadorDoContratante()
        roteador.abrir(aviso!)
        #expect(roteador.caminho == [.vaga(vagaID)])
    }
}
