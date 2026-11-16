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
    /// "Aceito chamadas diretas" (0.2.88): põe o profissional na busca. Só vai ao servidor depois que a pessoa mexe nele.
    public var aceitaChamadas: Bool = false {
        didSet { if aceitaChamadas != oldValue { aceitaChamadasMexido = true } }
    }
    /// O que ainda impede de aparecer na busca, como o servidor devolveu na última resposta.
    public private(set) var pendenciasParaBusca: [PendenciaParaBusca] = []
    /// A chave `busca_profissionais` do servidor: desligada, a tela não mostra "Aceito chamadas diretas".
    public private(set) var buscaHabilitada = false

    public private(set) var carregando = false
    public private(set) var salvando = false
    public private(set) var erro: String?
    public private(set) var sucesso: Bool = false

    /// A versão do texto da busca que a tela mostra ao profissional (1 a 20 caracteres, contrato 0.2.88).
    // TODO texto do Fabrício: troca a versão quando o texto da busca mudar.
    public static let versaoDoTextoDaBusca = "busca-1"

    private var aceitaChamadasMexido = false
    private let api: any ApiCliente
    private let agora: @Sendable () -> Date
    private let formatador = FormatadorFrila()

    public init(api: any ApiCliente, agora: @escaping @Sendable () -> Date = Date.init) {
        self.api = api
        self.agora = agora
        self.pausadoAte = agora().addingTimeInterval(24 * 3600)
    }

    /// Ligou "Aceito chamadas diretas" e nada falta: aparece na busca.
    public var apareceNaBusca: Bool { aceitaChamadas && pendenciasParaBusca.isEmpty }

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

        let api = api
        buscaHabilitada = (try? await PrazoDaAbertura.esperar(.seconds(15)) {
            try await api.configuracaoDoApp()
        })?.recursos.buscaProfissionais == true

        do {
            // O servidor guarda as preferências e as devolve em `meu_perfil_detalhado` (contrato 0.2.56).
            // Prazo explícito: sem ele a tela ficaria em "carregando" com a rede presa.
            let perfil = try await PrazoDaAbertura.esperar(.seconds(15)) {
                try await api.meuPerfilDetalhado()
            }
            if let salvas = perfil.preferenciaChamadas { aplicar(salvas) }
            sucesso = false
        } catch {
            erro = TextosChamadaDireta.erro
        }
    }

    /// Mostra o que o servidor tem. `aceitaChamadas` não conta como mexido pela pessoa: só vai de
    /// volta ao servidor depois que ela mexer nele.
    private func aplicar(_ preferencias: PreferenciaChamadas) {
        aceitaDeQuemJaTrabalhou = preferencias.aceitaDeQuemJaTrabalhou
        if let pausa = preferencias.pausadoAte {
            pausarChamadas = true
            pausadoAte = pausa
        } else {
            pausarChamadas = false
        }
        antecedenciaMinimaH = preferencias.antecedenciaMinimaH
        aceitaDe = preferencias.aceitaDe
        aceitaChamadas = preferencias.aceitaChamadas
        aceitaChamadasMexido = false
        pendenciasParaBusca = preferencias.pendenciasParaBusca
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
                aceitaDe: aceitaDe,
                aceitaChamadas: aceitaChamadasMexido ? aceitaChamadas : nil,
                versaoTextoBusca: aceitaChamadasMexido && aceitaChamadas ? Self.versaoDoTextoDaBusca : nil
            )
            let atualizado = try await api.definirPreferenciaChamadas(alteracao)
            aplicar(atualizado)
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
