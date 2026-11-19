import FrilaApresentacao
import SwiftUI

/// A abertura animada por cima do app (D-DS-15 e D-DS-21 do redesign).
///
/// É só uma camada: o app monta, lê a sessão e faz as primeiras chamadas por baixo, sem esperar por ela. Toca uma
/// vez por processo, na abertura a frio: voltar do segundo plano, sair e trocar de conta não recriam esta raiz, e
/// a marca estática cobre o caso de o sistema remontar a cena no mesmo processo.
struct AberturaAFrio: ViewModifier {
    @MainActor private static var jaTocou = false

    private let ajuste = AjusteDaAbertura.doLancamento
    @State private var cobrindo = AjusteDaAbertura.doLancamento.ligada && !AberturaAFrio.jaTocou
    /// Onde o rótulo da abertura pousa: o rótulo da tela de entrada, quando ela está na tela. Sem ele (com sessão),
    /// a abertura faz a saída simples.
    @State private var destinoDoRotulo: CGRect?
    @State private var escalaDoApp: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .scaleEffect(escalaDoApp)
            .environment(\.aberturaCobrindo, cobrindo)
            .onPreferenceChange(DestinoDoRotuloDaAbertura.self) { destinoDoRotulo = $0 }
            .overlay {
                if cobrindo {
                    AberturaAnimada(
                        destinoDoRotulo: destinoDoRotulo,
                        escalaDoApp: $escalaDoApp,
                        duracaoDaAbertura: ajuste.duracao,
                        tempoCongelado: ajuste.tempoCongelado
                    ) {
                        cobrindo = false
                    }
                    .accessibilityIdentifier("abertura-animada")
                    .onAppear { Self.jaTocou = true }
                }
            }
    }
}

extension View {
    /// Põe a abertura animada por cima desta raiz, só na abertura a frio do processo.
    func aberturaAFrio() -> some View {
        modifier(AberturaAFrio())
    }
}

/// O que o lançamento pede da abertura. Em produção é sempre a abertura ligada, com a duração de
/// `RoteiroDaAbertura.duracaoDaAbertura`. Só em Debug, três argumentos de teste mudam isso:
/// - `-FRILA_SEM_ABERTURA`: desliga (todo teste de interface passa, pelo `AjudanteDeLancamentoUITests`);
/// - `-FRILA_ABERTURA_DURACAO <segundos>`: uma abertura lenta, para o teste conferir o que acontece por baixo e o toque;
/// - `-FRILA_ABERTURA_CONGELADA <segundos>`: a abertura parada naquele instante do roteiro, para as capturas.
struct AjusteDaAbertura {
    var ligada = true
    var duracao: TimeInterval = RoteiroDaAbertura.duracaoDaAbertura
    var tempoCongelado: TimeInterval?

    static let doLancamento: AjusteDaAbertura = {
        var ajuste = AjusteDaAbertura()
        #if DEBUG
        let argumentos = ProcessInfo.processInfo.arguments
        func segundos(_ nome: String) -> TimeInterval? {
            guard let indice = argumentos.firstIndex(of: nome), argumentos.indices.contains(indice + 1) else { return nil }
            return TimeInterval(argumentos[indice + 1])
        }
        ajuste.ligada = !argumentos.contains("-FRILA_SEM_ABERTURA")
        if let duracao = segundos("-FRILA_ABERTURA_DURACAO"), duracao > 0 {
            ajuste.duracao = duracao
        }
        ajuste.tempoCongelado = segundos("-FRILA_ABERTURA_CONGELADA")
        #endif
        return ajuste
    }()
}
