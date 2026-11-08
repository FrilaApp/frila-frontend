import Foundation
import FrilaDominio
import Observation

@MainActor @Observable
public final class PreferenciasChamadaViewModel {
    public var aceitaDeQuemJaTrabalhou: Bool = true
    public var pausarChamadas: Bool = false
    public var pausadoAte: Date
    public var antecedenciaMinimaH: Int = 6
    public var aceitaDe: QuemPodeChamar = .todos

    public private(set) var carregando = false
    public private(set) var salvando = false
    public private(set) var erro: String?
    public private(set) var sucesso: Bool = false

    private let api: any ApiCliente
    private let agora: @Sendable () -> Date
    private let formatador = FormatadorFrila()

    public init(api: any ApiCliente, agora: @escaping @Sendable () -> Date = Date.init) {
        self.api = api
        self.agora = agora
        self.pausadoAte = agora().addingTimeInterval(24 * 3600)
    }

    public var textoRetomadaPausa: String {
        let fuso = TimeZone(identifier: "America/Sao_Paulo")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = fuso
        let diaSeguinte = cal.date(byAdding: .day, value: 1, to: pausadoAte) ?? pausadoAte
        let dataTexto = formatador.data(diaSeguinte)
        return "A retomada ocorre às 00:00 (horário de Brasília) de \(dataTexto)."
    }

    public func carregar() async {
        guard !carregando else { return }
        carregando = true
        erro = nil
        defer { carregando = false }

        do {
            // Preferências são lidas ou padrão
            // Podemos chamar api.meuPerfilDetalhado() ou manter valores persistidos
            sucesso = false
        } catch {
            erro = TextosChamadaDireta.erro
        }
    }

    public func salvar() async {
        guard !salvando else { return }
        salvando = true
        erro = nil
        sucesso = false
        defer { salvando = false }

        do {
            let alteracao = AlteracaoPreferenciaChamadas(
                aceitaDeQuemJaTrabalhou: aceitaDeQuemJaTrabalhou,
                pausadoAte: pausarChamadas ? pausadoAte : nil,
                removerPausa: !pausarChamadas,
                antecedenciaMinimaH: antecedenciaMinimaH,
                aceitaDe: aceitaDe
            )
            let atualizado = try await api.definirPreferenciaChamadas(alteracao)
            aceitaDeQuemJaTrabalhou = atualizado.aceitaDeQuemJaTrabalhou
            if let pausa = atualizado.pausadoAte {
                pausarChamadas = true
                pausadoAte = pausa
            } else {
                pausarChamadas = false
            }
            antecedenciaMinimaH = atualizado.antecedenciaMinimaH
            aceitaDe = atualizado.aceitaDe
            sucesso = true
        } catch let apiErro as ErroDaApi {
            if apiErro.recursoDesligado {
                erro = TextosChamadaDireta.desligado
            } else {
                erro = TextosChamadaDireta.erro
            }
        } catch {
            erro = TextosChamadaDireta.erro
        }
    }
}
