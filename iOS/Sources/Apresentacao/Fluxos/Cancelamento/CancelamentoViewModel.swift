import Foundation
import FrilaDominio
import Observation

/// Quem está cancelando. Decide os motivos oferecidos e o aviso sobre a falta (RN12).
public enum LadoDoCancelamento: Equatable, Sendable {
    case profissional
    case contratante
}

/// O que o cancelamento mira: uma posição confirmada (`cancelar_posicao`) ou a vaga inteira
/// (`cancelar_vaga`, só do contratante).
public enum AlvoDoCancelamento: Equatable, Sendable {
    case posicao(id: UUID, turnoID: UUID?)
    case vaga(id: UUID)

    public var id: UUID {
        switch self {
        case let .posicao(id, _), let .vaga(id): id
        }
    }

    var tipoDaAcao: TipoAcaoPendente {
        switch self {
        case .posicao: .cancelamentoPosicao
        case .vaga: .cancelamentoVaga
        }
    }
}

/// Os motivos da folha. O texto escolhido é o `motivo` que vai ao servidor; `outro` exige o campo
/// livre. O dicionário é do app: o contrato recebe texto, não código.
public enum MotivoDeCancelamento: String, CaseIterable, Identifiable, Sendable {
    // Profissional
    case saude
    case imprevistoPessoal
    case deslocamento
    case outroCompromisso
    // Contratante
    case movimentoMenor
    case posicaoPreenchidaFora
    case mudancaDePlanos
    case problemaNoLocal
    // Os dois
    case outro

    public var id: String { rawValue }

    public static func opcoes(para lado: LadoDoCancelamento) -> [MotivoDeCancelamento] {
        switch lado {
        case .profissional: [.saude, .imprevistoPessoal, .deslocamento, .outroCompromisso, .outro]
        case .contratante: [.movimentoMenor, .posicaoPreenchidaFora, .mudancaDePlanos, .problemaNoLocal, .outro]
        }
    }

    /// `outro` não diz nada sozinho: o texto livre é obrigatório.
    public var exigeDetalhes: Bool { self == .outro }
}

/// O que a chamada devolveu, ou que ela ficou na fila para quando a rede voltar.
public enum DesfechoDoCancelamento: Equatable, Sendable {
    case posicao(ResultadoCancelamento)
    case vaga(VagaCancelada)
    case naFila
}

public enum EstadoDoCancelamento: Equatable, Sendable {
    case pronto
    case enviando
    case concluido(DesfechoDoCancelamento)
    case falha(String)
}

/// A folha de cancelamento dos dois lados (#20, RN12, UC08): pede o motivo, avisa o efeito pela
/// antecedência antes de chamar, e guarda a ação na fila quando não há rede. Quem decide falta e
/// reabertura é o servidor; o aviso é a leitura local da mesma regra, pelo relógio injetado.
@MainActor @Observable
public final class CancelamentoViewModel: Identifiable {
    /// Identidade da folha aberta, para `sheet(item:)`.
    public let id = UUID()
    public let lado: LadoDoCancelamento
    public let alvo: AlvoDoCancelamento
    public let periodo: Periodo
    public var motivo: MotivoDeCancelamento?
    public var detalhes: String = ""
    public private(set) var estado: EstadoDoCancelamento = .pronto

    private let relogio: any Relogio
    private let fila: (any FilaDeAcoes)?
    private let executar: @Sendable (String) async throws -> DesfechoDoCancelamento
    private let aoConcluir: @MainActor (DesfechoDoCancelamento) -> Void

    /// RN12: cancelamento do profissional a menos de 24 horas do início conta como falta.
    public static let antecedenciaSemFalta: TimeInterval = 24 * 60 * 60

    public init(
        lado: LadoDoCancelamento,
        alvo: AlvoDoCancelamento,
        periodo: Periodo,
        relogio: any Relogio = RelogioDoSistema(),
        fila: (any FilaDeAcoes)? = nil,
        executar: @escaping @Sendable (String) async throws -> DesfechoDoCancelamento,
        aoConcluir: @escaping @MainActor (DesfechoDoCancelamento) -> Void = { _ in }
    ) {
        self.lado = lado
        self.alvo = alvo
        self.periodo = periodo
        self.relogio = relogio
        self.fila = fila
        self.executar = executar
        self.aoConcluir = aoConcluir
    }

    /// A folha de uma posição, chamando `cancelar_posicao`.
    public convenience init(
        lado: LadoDoCancelamento,
        posicaoID: UUID,
        turnoID: UUID?,
        periodo: Periodo,
        api: any ApiCliente,
        relogio: any Relogio = RelogioDoSistema(),
        fila: (any FilaDeAcoes)? = nil,
        aoConcluir: @escaping @MainActor (DesfechoDoCancelamento) -> Void = { _ in }
    ) {
        self.init(
            lado: lado, alvo: .posicao(id: posicaoID, turnoID: turnoID), periodo: periodo, relogio: relogio, fila: fila,
            executar: { .posicao(try await api.cancelarPosicao(id: posicaoID, motivo: $0)) },
            aoConcluir: aoConcluir
        )
    }

    /// A folha da vaga inteira, chamando `cancelar_vaga`. Só o contratante.
    public convenience init(
        vagaID: UUID,
        periodo: Periodo,
        api: any ApiCliente,
        relogio: any Relogio = RelogioDoSistema(),
        fila: (any FilaDeAcoes)? = nil,
        aoConcluir: @escaping @MainActor (DesfechoDoCancelamento) -> Void = { _ in }
    ) {
        self.init(
            lado: .contratante, alvo: .vaga(id: vagaID), periodo: periodo, relogio: relogio, fila: fila,
            executar: { .vaga(try await api.cancelarVaga(id: vagaID, motivo: $0)) },
            aoConcluir: aoConcluir
        )
    }

    // MARK: Antecedência

    public var motivos: [MotivoDeCancelamento] { MotivoDeCancelamento.opcoes(para: lado) }

    /// Segundos até o início; negativo depois dele.
    public var antecedencia: TimeInterval { periodo.inicio.timeIntervalSince(relogio.agora) }

    public var turnoJaComecou: Bool { antecedencia <= 0 }

    /// Só o profissional leva falta, e só a menos de 24 horas do início (RN12). O contratante
    /// nunca gera falta para ninguém, e nenhum cancelamento suspende (RN13).
    public var contaComoFalta: Bool {
        lado == .profissional && antecedencia < Self.antecedenciaSemFalta
    }

    /// Antes do início, a vaga ganha uma posição nova; depois dele, o turno fica descoberto.
    public var vaiReabrir: Bool {
        if case .vaga = alvo { return false }
        return !turnoJaComecou
    }

    /// O aviso que a folha mostra antes do toque: muda com a antecedência e com o lado.
    public var aviso: String {
        TextosDoCancelamento.aviso(lado: lado, alvo: alvo, antecedencia: antecedencia, contaComoFalta: contaComoFalta)
    }

    // MARK: Motivo

    /// O texto que vai ao servidor: o motivo escolhido e, se houver, o detalhe depois de dois pontos.
    public var motivoCompleto: String? {
        guard let motivo else { return nil }
        let detalhe = detalhes.trimmingCharacters(in: .whitespacesAndNewlines)
        if motivo.exigeDetalhes {
            return detalhe.count >= 3 ? detalhe : nil
        }
        let texto = TextosDoCancelamento.motivo(motivo)
        return detalhe.isEmpty ? texto : "\(texto): \(detalhe)"
    }

    /// Cancelar sem motivo não é possível (critério 3 do #20). Depois de uma falha, dá para tentar
    /// de novo; depois de concluído, não.
    public var podeConfirmar: Bool {
        switch estado {
        case .pronto, .falha: motivoCompleto != nil
        case .enviando, .concluido: false
        }
    }

    // MARK: Ação

    public func confirmar() async {
        guard podeConfirmar, let motivoCompleto else { return }
        estado = .enviando
        do {
            let desfecho = try await executar(motivoCompleto)
            estado = .concluido(desfecho)
            aoConcluir(desfecho)
        } catch let erro as ErroDaApi where erro.codigo == .semRede {
            await guardarNaFila(motivoCompleto)
        } catch let erro as ErroDaApi {
            estado = .falha(TextosDoCancelamento.falha(erro))
        } catch {
            estado = .falha(TextosDoCancelamento.falhaGenerica)
        }
    }

    /// Sem rede, a ação entra na fila (contrato 0.2.17) e a tela diz que o cancelamento será
    /// enviado. Sem fila, só há o aviso de que não foi enviado.
    private func guardarNaFila(_ motivoCompleto: String) async {
        guard let fila else {
            estado = .falha(TextosDoCancelamento.semRedeSemFila)
            return
        }
        var turnoID: UUID?
        if case let .posicao(_, turno) = alvo { turnoID = turno }
        let acao = AcaoPendente(
            tipo: alvo.tipoDaAcao, turnoID: turnoID, instanteDoToque: relogio.agora, chave: UUID(),
            alvoID: alvo.id, motivo: motivoCompleto
        )
        do {
            try await fila.enfileirar(acao)
        } catch {
            estado = .falha(TextosDoCancelamento.falhaAoGuardar)
            return
        }
        estado = .concluido(.naFila)
        aoConcluir(.naFila)
    }

    /// Se já há um cancelamento deste alvo esperando na fila: a tela não oferece cancelar de novo.
    public static func pendenteNaFila(_ fila: (any FilaDeAcoes)?, alvo: AlvoDoCancelamento) async -> Bool {
        guard let fila, let acoes = try? await fila.pendentes() else { return false }
        return acoes.contains { $0.tipo == alvo.tipoDaAcao && $0.alvoID == alvo.id }
    }
}
