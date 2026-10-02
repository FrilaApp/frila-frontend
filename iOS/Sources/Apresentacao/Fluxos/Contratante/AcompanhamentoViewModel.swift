import Foundation
import FrilaDominio
import Observation

/// Uma posição com profissional, vista por quem opera a casa, junto com a vaga a que pertence.
public struct TurnoAcompanhado: Identifiable, Hashable, Sendable {
    public let vaga: VagaResumo
    public let posicao: PosicaoNoPainel

    public var id: UUID { posicao.id }

    public init(vaga: VagaResumo, posicao: PosicaoNoPainel) {
        self.vaga = vaga
        self.posicao = posicao
    }
}

/// Em que pé está a chegada do profissional. Sai só do painel: quem decide atraso e verificação é
/// o servidor, nunca o relógio do aparelho.
public enum ChegadaDoProfissional: Equatable, Sendable {
    case aguardando
    case aCaminho(desde: Date)
    /// Passaram 15 minutos do início sem check-in (D06): a casa espera ou reabre.
    case emAtraso
    /// Check-in manual esperando a confirmação da casa (RN22).
    case manualPendente
    case verificada
    case naoVerificada
    case cancelada
}

public enum ResultadoDoAcompanhamento: Equatable, Sendable {
    case presencaConfirmada
    /// A falta foi registrada e a vaga ganhou uma posição nova.
    case vagaReaberta
    /// A menos de 1 hora do fim a falta é registrada, mas não há reabertura.
    case faltaSemReabertura
}

public enum FalhaDoAcompanhamento: Equatable, Sendable {
    case antesDaTolerancia
    /// O turno mudou no servidor desde a última leitura (check-in feito, posição cancelada…).
    case situacaoMudou
    case api(ErroDaApi)
}

/// Acompanhamento do turno pelo contratante (#19): confirma o check-in manual e reabre a vaga
/// quando o profissional atrasa. Lê o mesmo `painel_estabelecimento` de Minhas vagas.
@MainActor @Observable
public final class AcompanhamentoViewModel {
    public private(set) var painel: Painel?
    public private(set) var carregando = false
    public private(set) var falhouAoCarregar = false
    public private(set) var resultado: ResultadoDoAcompanhamento?
    public private(set) var falha: FalhaDoAcompanhamento?
    /// Posições com confirmação ou reabertura em voo: um segundo toque não repete a chamada.
    public private(set) var emAndamento: Set<UUID> = []
    /// O turno cuja reabertura espera a confirmação de quem tocou em "Reabrir vaga".
    public private(set) var reaberturaEmConfirmacao: TurnoAcompanhado?

    private let buscarPainel: @Sendable () async throws -> Painel
    private let confirmar: @Sendable (UUID) async throws -> ResultadoRegistro
    private let reabrir: @Sendable (UUID) async throws -> ResultadoCancelamento
    private let aoMudar: @MainActor () async -> Void

    /// `aoMudar` roda depois de cada confirmação ou reabertura, para a lista de vagas se atualizar.
    public convenience init(
        api: any ApiCliente,
        estabelecimentoID: UUID,
        agora: @escaping @Sendable () -> Date = Date.init,
        calendario: Calendar = MinhasVagasViewModel.calendarioSaoPaulo,
        aoMudar: @escaping @MainActor () async -> Void = {}
    ) {
        self.init(
            buscarPainel: {
                let instante = agora()
                guard let de = calendario.date(byAdding: .day, value: -365, to: instante),
                      let ate = calendario.date(byAdding: .day, value: 365, to: instante) else {
                    throw ErroDaApi(codigo: .campoInvalido)
                }
                return try await api.painelEstabelecimento(id: estabelecimentoID, periodo: try Periodo(inicio: de, fim: ate))
            },
            confirmar: { try await api.confirmarCheckinManual(turnoID: $0) },
            reabrir: { try await api.reabrirPorAtraso(posicaoID: $0) },
            aoMudar: aoMudar
        )
    }

    public init(
        buscarPainel: @escaping @Sendable () async throws -> Painel,
        confirmar: @escaping @Sendable (UUID) async throws -> ResultadoRegistro,
        reabrir: @escaping @Sendable (UUID) async throws -> ResultadoCancelamento,
        aoMudar: @escaping @MainActor () async -> Void = {}
    ) {
        self.buscarPainel = buscarPainel
        self.confirmar = confirmar
        self.reabrir = reabrir
        self.aoMudar = aoMudar
    }

    // MARK: Leitura

    private var turnos: [TurnoAcompanhado] {
        (painel?.vagas ?? []).flatMap { vaga in
            vaga.posicoes.filter { $0.turnoID != nil }.map { TurnoAcompanhado(vaga: vaga.vaga, posicao: $0) }
        }
    }

    /// Check-ins manuais esperando confirmação, na ordem em que o painel os traz.
    public var pendentes: [TurnoAcompanhado] {
        let todos = turnos
        return (painel?.checkinsPendentes ?? []).compactMap { turnoID in todos.first { $0.posicao.turnoID == turnoID } }
    }

    /// Posições em atraso, da vaga que começou primeiro para a que começou depois.
    public var emAtraso: [TurnoAcompanhado] {
        turnos.filter { $0.posicao.estado == .confirmada && $0.posicao.emAtraso }
            .sorted { $0.vaga.periodo.inicio < $1.vaga.periodo.inicio }
    }

    public func turno(turnoID: UUID) -> TurnoAcompanhado? {
        turnos.first { $0.posicao.turnoID == turnoID }
    }

    public func vaga(id: UUID) -> VagaNoPainel? {
        painel?.vagas.first { $0.vaga.id == id }
    }

    private func pendenteNoPainel(_ turno: TurnoAcompanhado) -> Bool {
        guard let turnoID = turno.posicao.turnoID else { return false }
        return painel?.checkinsPendentes.contains(turnoID) ?? false
    }

    /// O check-in manual está pendente no painel, e o servidor não recusou este turno desde a
    /// última leitura.
    public func podeConfirmar(_ turno: TurnoAcompanhado) -> Bool {
        pendenteNoPainel(turno) && !recusadas.contains(turno.id)
    }

    /// Só o `em_atraso` do painel libera a reabertura: antes dos 15 minutos o botão não existe. Depois
    /// de uma recusa do servidor, também não, até o painel ser relido.
    public func podeReabrir(_ turno: TurnoAcompanhado) -> Bool {
        turno.posicao.estado == .confirmada && turno.posicao.emAtraso && !recusadas.contains(turno.id)
    }

    public func chegada(_ turno: TurnoAcompanhado) -> ChegadaDoProfissional {
        let posicao = turno.posicao
        if posicao.estado == .cancelada { return .cancelada }
        if pendenteNoPainel(turno) { return .manualPendente }
        if posicao.verificacao == .verificado { return .verificada }
        if posicao.verificacao == .naoVerificado { return .naoVerificada }
        if posicao.emAtraso { return .emAtraso }
        if let desde = posicao.aCaminhoEm { return .aCaminho(desde: desde) }
        return .aguardando
    }

    // MARK: Ações

    public func carregar() async {
        guard !carregando else { return }
        carregando = true
        defer { carregando = false }
        await lerPainel(registrandoFalha: true)
    }

    /// Lê o painel e só o aplica se nenhuma ação respondeu enquanto a leitura estava em voo. Uma
    /// leitura que saiu antes da confirmação pode chegar depois dela com o estado antigo, e traria
    /// de volta a pendência que a tela acabou de tirar; nesse caso a resposta é descartada e o
    /// painel é lido de novo.
    @discardableResult
    private func lerPainel(registrandoFalha: Bool) async -> Bool {
        while true {
            let geracaoDaLeitura = geracao
            do {
                let novo = try await buscarPainel()
                guard geracaoDaLeitura == geracao else { continue }
                painel = novo
                falhouAoCarregar = false
                recusadas = []
                return true
            } catch {
                guard geracaoDaLeitura == geracao else { continue }
                if registrandoFalha { falhouAoCarregar = true }
                return false
            }
        }
    }

    /// O turno como o painel o traz agora: o que a tela guardou pode ser de antes de uma leitura.
    private func atual(_ turno: TurnoAcompanhado) -> TurnoAcompanhado? {
        turnos.first { $0.id == turno.id }
    }

    /// Um toque: o turno sai dos pendentes e a presença fica verificada assim que o servidor responde.
    /// Só envia se o check-in ainda está pendente no painel de agora.
    public func confirmarPresenca(_ turno: TurnoAcompanhado) async {
        guard let turno = atual(turno), podeConfirmar(turno), let turnoID = turno.posicao.turnoID,
              !emAndamento.contains(turno.id) else { return }
        emAndamento.insert(turno.id)
        defer { emAndamento.remove(turno.id) }
        resultado = nil
        falha = nil
        do {
            let registro = try await confirmar(turnoID)
            geracao += 1
            aplicar(verificacao: registro.verificacao, aoTurno: turnoID, confirmadoEm: registro.registradoEm)
            resultado = .presencaConfirmada
            await aoMudar()
        } catch let erro as ErroDaApi where erro.codigo == .checkinJaConfirmado || erro.codigo == .checkinPendente {
            // O painel estava velho: o check-in já nasceu verificado, ou deixou de existir.
            await relerDepoisDaRecusa(de: turno, falha: .situacaoMudou)
        } catch {
            falha = .api(error as? ErroDaApi ?? ErroDaApi(codigo: .desconhecido))
        }
    }

    /// Reabrir conta como falta e não tem volta: a tela pergunta antes.
    public func pedirReabertura(_ turno: TurnoAcompanhado) {
        guard let turno = atual(turno), podeReabrir(turno), !emAndamento.contains(turno.id) else { return }
        reaberturaEmConfirmacao = turno
    }

    public func desistirDaReabertura() {
        reaberturaEmConfirmacao = nil
    }

    /// Só reabre o turno que passou por `pedirReabertura` e que continua em atraso no painel de
    /// agora. O pedido é lido aqui, na hora do toque, e não dentro da tarefa: o alerta, ao fechar,
    /// chama `desistirDaReabertura` antes de a tarefa começar, e a reabertura confirmada se perderia.
    @discardableResult
    public func confirmarReabertura() -> Task<Void, Never>? {
        guard let pedido = reaberturaEmConfirmacao else { return nil }
        reaberturaEmConfirmacao = nil
        guard let turno = atual(pedido), podeReabrir(turno), !emAndamento.contains(turno.id) else { return nil }
        emAndamento.insert(turno.id)
        return Task { await reabrirConfirmado(turno) }
    }

    private func reabrirConfirmado(_ turno: TurnoAcompanhado) async {
        defer { emAndamento.remove(turno.id) }
        resultado = nil
        falha = nil
        do {
            let cancelamento = try await reabrir(turno.posicao.id)
            geracao += 1
            aplicar(cancelamento)
            resultado = cancelamento.reaberta ? .vagaReaberta : .faltaSemReabertura
            // A leitura nova só confirma o que a tela já mostra; se falhar, o estado aplicado vale.
            await lerPainel(registrandoFalha: false)
            await aoMudar()
        } catch let erro as ErroDaApi where erro.codigo == .reaberturaAntesDaTolerancia {
            await relerDepoisDaRecusa(de: turno, falha: .antesDaTolerancia)
        } catch let erro as ErroDaApi where erro.codigo == .posicaoNaoCancelavel {
            await relerDepoisDaRecusa(de: turno, falha: .situacaoMudou)
        } catch {
            falha = .api(error as? ErroDaApi ?? ErroDaApi(codigo: .desconhecido))
        }
    }

    // MARK: Estado local

    /// Sobe a cada resposta do servidor a uma ação, aceita ou recusada: as leituras que saíram antes
    /// dela não valem mais.
    private var geracao = 0
    /// Posições cuja ação o servidor recusou e que ainda não foram relidas: o painel da tela está
    /// velho para elas, e a ação não é oferecida de novo até a próxima leitura que der certo.
    private var recusadas: Set<UUID> = []

    /// O servidor recusou porque o painel da tela estava velho. Só a releitura conserta a tela; se
    /// ela falhar, `falhouAoCarregar` avisa que o que aparece está desatualizado.
    private func relerDepoisDaRecusa(de turno: TurnoAcompanhado, falha: FalhaDoAcompanhamento) async {
        geracao += 1
        recusadas.insert(turno.id)
        self.falha = falha
        await lerPainel(registrandoFalha: true)
    }

    private func aplicar(verificacao: Verificacao, aoTurno turnoID: UUID, confirmadoEm: Date? = nil) {
        guard let atual = painel else { return }
        painel = Painel(
            estabelecimentoID: atual.estabelecimentoID,
            vagas: atual.vagas.map { vaga in
                Self.copia(vaga, posicoes: vaga.posicoes.map { posicao in
                    posicao.turnoID == turnoID
                        ? Self.copia(posicao, verificacao: verificacao, checkinConfirmadoEm: confirmadoEm ?? posicao.checkinConfirmadoEm)
                        : posicao
                })
            },
            checkinsPendentes: atual.checkinsPendentes.filter { $0 != turnoID }
        )
    }

    private func aplicar(_ cancelamento: ResultadoCancelamento) {
        guard let atual = painel else { return }
        painel = Painel(
            estabelecimentoID: atual.estabelecimentoID,
            vagas: atual.vagas.map { vaga in
                guard vaga.posicoes.contains(where: { $0.id == cancelamento.posicaoID }) else { return vaga }
                var posicoes = vaga.posicoes.map { posicao in
                    posicao.id == cancelamento.posicaoID
                        ? Self.copia(
                            posicao,
                            estado: .cancelada,
                            emAtraso: false,
                            cancelamento: CancelamentoDaPosicao(
                                causa: .reaberturaPorAtraso,
                                falta: cancelamento.falta,
                                motivo: nil,
                                canceladaEm: Date()
                            )
                        )
                        : posicao
                }
                if let nova = cancelamento.novaPosicaoID {
                    posicoes.append(PosicaoNoPainel(id: nova, estado: .aberta, profissional: nil, turnoID: nil, verificacao: nil, emAtraso: false))
                }
                return Self.copia(vaga, posicoes: posicoes)
            },
            checkinsPendentes: atual.checkinsPendentes
        )
    }

    private static func copia(_ vaga: VagaNoPainel, posicoes: [PosicaoNoPainel]) -> VagaNoPainel {
        VagaNoPainel(
            vaga: vaga.vaga, modo: vaga.modo, estado: vaga.estado, oculta: vaga.oculta, alertaVagaVazia: vaga.alertaVagaVazia,
            candidatosPendentes: vaga.candidatosPendentes, posicoes: posicoes
        )
    }

    private static func copia(
        _ posicao: PosicaoNoPainel,
        estado: EstadoPosicao? = nil,
        verificacao: Verificacao? = nil,
        emAtraso: Bool? = nil,
        checkinEm: Date? = nil,
        checkinTipo: TipoRegistro? = nil,
        checkinConfirmadoEm: Date? = nil,
        cancelamento: CancelamentoDaPosicao? = nil
    ) -> PosicaoNoPainel {
        PosicaoNoPainel(
            id: posicao.id,
            estado: estado ?? posicao.estado,
            profissional: posicao.profissional,
            turnoID: posicao.turnoID,
            verificacao: verificacao ?? posicao.verificacao,
            emAtraso: emAtraso ?? posicao.emAtraso,
            aCaminhoEm: posicao.aCaminhoEm,
            checkinEm: checkinEm ?? posicao.checkinEm,
            checkinTipo: checkinTipo ?? posicao.checkinTipo,
            checkinConfirmadoEm: checkinConfirmadoEm ?? posicao.checkinConfirmadoEm,
            cancelamento: cancelamento ?? posicao.cancelamento
        )
    }
}
