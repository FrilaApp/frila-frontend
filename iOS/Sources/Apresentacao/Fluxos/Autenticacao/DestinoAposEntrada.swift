import Foundation
import FrilaDominio

public enum DestinoAposEntrada: Equatable, Sendable {
    case profissional
    case funcoesEHorarios
    case contratante
    case contaSuspensa(SituacaoDaConta)
}

public enum DestinoDaConta: Equatable, Sendable {
    case cadastro(email: String?)
    case profissional
    case funcoesEHorarios
    case contratante
    case contaSuspensa(SituacaoDaConta)

    public var tipoGuardavel: TipoDestinoConta? {
        switch self {
        case .profissional: return .profissional
        case .funcoesEHorarios: return .funcoesEHorarios
        case .contratante: return .contratante
        case .cadastro, .contaSuspensa: return nil
        }
    }

    public init(tipo: TipoDestinoConta) {
        switch tipo {
        case .profissional: self = .profissional
        case .funcoesEHorarios: self = .funcoesEHorarios
        case .contratante: self = .contratante
        }
    }

    public static func avaliar(api: any ApiCliente, emailParaCadastro: String? = nil) async throws -> DestinoDaConta {
        let conta: Conta
        do {
            conta = try await api.minhaConta()
        } catch let erroApi as ErroDaApi where erroApi.codigo == .naoEncontrado {
            return .cadastro(email: emailParaCadastro)
        }

        let situacao = try await api.situacaoDaConta()
        if situacao.estado == .suspensa {
            return .contaSuspensa(situacao)
        }

        switch conta.perfil {
        case .profissional:
            do {
                _ = try await api.meuPerfilProfissional()
                return .profissional
            } catch let erroApi as ErroDaApi where erroApi.codigo == .naoEncontrado {
                return .funcoesEHorarios
            }
        case .contratante:
            return .contratante
        }
    }

    /// Com rede ruim a avaliação (até três RPCs em série) não falha nem volta: a `URLSession` só
    /// desiste aos 60 s. Vencido o prazo, vale a mesma regra de sem rede: o destino guardado abre o
    /// app, e sem ele a tela diz que está sem conexão, com "Tentar novamente".
    @MainActor
    public static func avaliarComRecuperacaoOffline(
        api: any ApiCliente, defaults: UserDefaults = .standard, prazo: Duration = PrazoDaAbertura.padrao
    ) async throws -> DestinoDaConta {
        do {
            let destino = try await PrazoDaAbertura.esperar(prazo) { try await avaliar(api: api) }
            switch destino {
            case .cadastro:
                DestinoGuardado.limpar(em: defaults)
            case .contaSuspensa:
                // Não altera o destino guardado: sem rede na abertura futura,
                // mantém o comportamento do destino guardado prévio (RF24, RN13).
                break
            default:
                if let tipo = destino.tipoGuardavel {
                    DestinoGuardado.salvar(tipo, em: defaults)
                }
            }
            return destino
        } catch let erroApi as ErroDaApi where erroApi.codigo == .semRede {
            if let guardado = DestinoGuardado.obter(de: defaults) {
                return DestinoDaConta(tipo: guardado)
            }
            throw erroApi
        }
    }
}

public enum DemonstracaoContas {
    public static func ehEmailDeDemonstracao(_ email: String) -> Bool {
        let limpo = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return limpo == "revisao-profissional@frila.app" || limpo == "revisao-contratante@frila.app"
    }
}

/// O quanto a abertura espera pela rede antes de seguir pelo caminho de sem rede (cache, destino
/// guardado). Sem rede o erro chega na hora; com rede ruim (pacote perdido, Wi‑Fi cativo, 3G fraco)
/// a `URLSession` só desiste aos 60 s, e até lá a pessoa veria só o indicador de carregamento.
public enum PrazoDaAbertura {
    public static let padrao: Duration = .seconds(8)
    /// O `codigoOriginal` do `semRede` que vem do prazo, para o diagnóstico distinguir os dois.
    public static let codigoOriginal = "prazo_da_abertura"

    /// Devolve o resultado de `operacao`, ou lança `ErroDaApi(codigo: .semRede)` se o prazo vencer
    /// antes; a operação em voo é cancelada (a `URLSession` encerra o pedido).
    public static func esperar<Valor: Sendable>(
        _ prazo: Duration, _ operacao: @escaping @Sendable () async throws -> Valor
    ) async throws -> Valor {
        try await withThrowingTaskGroup(of: Valor.self) { grupo in
            grupo.addTask { try await operacao() }
            grupo.addTask {
                try await Task.sleep(for: prazo)
                throw ErroDaApi(codigo: .semRede, codigoOriginal: codigoOriginal)
            }
            defer { grupo.cancelAll() }
            guard let primeiro = try await grupo.next() else { throw ErroDaApi(codigo: .semRede, codigoOriginal: codigoOriginal) }
            return primeiro
        }
    }
}
