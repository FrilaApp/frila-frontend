import FrilaDominio
#if DEBUG || FRILA_MEDICAO
import Observation
#endif

#if DEBUG || FRILA_MEDICAO
/// Mede a abertura de uma tela (#73, RNF01) enquanto `carregar` roda.
///
/// - Começa quando a tela de destino começa a carregar, no mesmo ciclo do toque que a abriu (ou do
///   gesto de atualizar).
/// - Termina na primeira mudança do view model em que `pronto` passa a ser verdadeiro: o conteúdo da
///   API publicado, que a tela desenha no quadro seguinte.
/// - Quando a resposta é igual ao que já estava na tela (puxar para atualizar sem novidade), o
///   Observation não avisa a mudança, e o fim é o retorno de `carregar`, com `pronto` verdadeiro.
/// - Com erro, sem rede ou com a carga abandonada (a tela saiu antes), nada é registrado.
///
/// Sem registro (Debug sem `-FRILA_MEDICAO`), só carrega.
@MainActor
public func medirAbertura(
    _ tela: TelaMedida,
    registro: RegistroDeMedicoes? = RegistroDeMedicoes.ativo ? .compartilhado : nil,
    carregar: () async -> Void,
    pronto: @escaping @MainActor @Sendable () -> Bool
) async {
    guard let registro else {
        await carregar()
        return
    }
    let sinalizador = RegistroDeMedicoes.sinalizador
    let intervalo = sinalizador.beginInterval("abertura", id: sinalizador.makeSignpostID(), "\(tela.rawValue, privacy: .public)")
    let inicio = ContinuousClock.now
    let marco = MarcoDaAbertura()
    observar(pronto, marco: marco)
    await carregar()
    // A mudança que fecha a carga chega a `observar` numa tarefa já na fila do MainActor: a vez
    // cedida aqui deixa essa tarefa rodar antes de encerrar.
    await Task.yield()
    marco.encerrado = true
    // O Observation não avisa quando o valor novo é igual ao antigo.
    if marco.fim == nil, !Task.isCancelled, pronto() {
        marco.fim = ContinuousClock.now
    }
    sinalizador.endInterval("abertura", intervalo)
    guard let fim = marco.fim else { return }
    let duracao = fim - inicio
    let milissegundos = Double(duracao.components.seconds) * 1000 + Double(duracao.components.attoseconds) / 1e15
    registro.registrar(tela, milissegundos: milissegundos)
}

@MainActor
private final class MarcoDaAbertura {
    var fim: ContinuousClock.Instant?
    var encerrado = false
}

/// Observa só as mudanças: o estado de antes (a lista já na tela, num puxar para atualizar) não conta.
/// O `onChange` vem antes de o valor novo ser gravado: o instante é tomado ali, e `pronto` é lido
/// depois, numa tarefa no MainActor, já com o valor novo.
@MainActor
private func observar(_ pronto: @escaping @MainActor @Sendable () -> Bool, marco: MarcoDaAbertura) {
    withObservationTracking {
        _ = pronto()
    } onChange: {
        let instante = ContinuousClock.now
        Task { @MainActor in
            guard !marco.encerrado, marco.fim == nil else { return }
            if pronto() {
                marco.fim = instante
            } else {
                observar(pronto, marco: marco)
            }
        }
    }
}
#else
/// Build de produção: a medição de abertura (#73) não existe, e a tela só carrega.
@MainActor
public func medirAbertura(
    _ tela: TelaMedida,
    carregar: () async -> Void,
    pronto: @escaping @MainActor @Sendable () -> Bool
) async {
    await carregar()
}
#endif
