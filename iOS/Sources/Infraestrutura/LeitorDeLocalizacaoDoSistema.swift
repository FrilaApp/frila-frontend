import CoreLocation
import Foundation
import FrilaDominio

/// CoreLocation como `LeitorDeLocalizacao`. Só pede a permissão "ao usar" e só lê enquanto
/// `lerUmaVez` está em curso: não há atualização em segundo plano, região monitorada nem pedido da
/// permissão "sempre" (RN22).
@MainActor
public final class LeitorDeLocalizacaoDoSistema: NSObject, LeitorDeLocalizacao {
    private struct LeituraEmCurso {
        let continuacao: CheckedContinuation<Result<LeituraDeLocalizacao, ErroDeLocalizacao>, Never>
        let precisaoSuficienteMetros: Double
        let inicio: Date
        var melhor: LeituraDeLocalizacao?
        /// A leitura anterior do mesmo toque, para o salto de posição.
        var anterior: (coordenada: Coordenada, precisaoMetros: Double, instante: Date)?
        /// Alguma leitura do toque veio simulada por software (0.2.68).
        var simulada = false
        var saltou = false

        /// A leitura com os sinais do toque inteiro, e não só os da hora em que ela chegou.
        func comSinais(_ leitura: LeituraDeLocalizacao) -> LeituraDeLocalizacao {
            LeituraDeLocalizacao(
                coordenada: leitura.coordenada, precisaoHorizontalMetros: leitura.precisaoHorizontalMetros,
                simulada: simulada, saltoDePosicao: saltou
            )
        }
    }

    private let gerenciador = CLLocationManager()
    private var esperandoPermissao: [CheckedContinuation<Void, Never>] = []
    private var leitura: LeituraEmCurso?
    private var prazo: Task<Void, Never>?

    public override init() {
        super.init()
        gerenciador.delegate = self
        gerenciador.desiredAccuracy = kCLLocationAccuracyBest
    }

    public func permissao() async -> PermissaoDeLocalizacao { permissaoAtual }

    public func pedirPermissao() async -> PermissaoDeLocalizacao {
        guard gerenciador.authorizationStatus == .notDetermined else { return permissaoAtual }
        await withCheckedContinuation { continuacao in
            esperandoPermissao.append(continuacao)
            gerenciador.requestWhenInUseAuthorization()
        }
        return permissaoAtual
    }

    public func pedirPrecisaoTemporaria(chave: String) async -> PermissaoDeLocalizacao {
        guard permissaoAtual == .aoUsarAproximada else { return permissaoAtual }
        try? await gerenciador.requestTemporaryFullAccuracyAuthorization(withPurposeKey: chave)
        return permissaoAtual
    }

    public func lerUmaVez(tempoLimite: Duration, precisaoSuficienteMetros: Double) async throws(ErroDeLocalizacao) -> LeituraDeLocalizacao {
        guard leitura == nil else { throw .semSinal }
        guard permissaoAtual == .aoUsarPrecisa || permissaoAtual == .aoUsarAproximada else { throw .permissaoNegada }
        let resultado = await withTaskCancellationHandler {
            await withCheckedContinuation { continuacao in
                leitura = LeituraEmCurso(continuacao: continuacao, precisaoSuficienteMetros: precisaoSuficienteMetros, inicio: .now)
                gerenciador.startUpdatingLocation()
                prazo = Task { [weak self] in
                    try? await Task.sleep(for: tempoLimite)
                    guard !Task.isCancelled else { return }
                    self?.encerrarNoPrazo()
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.concluir(.failure(.semSinal)) }
        }
        return try resultado.get()
    }

    private var permissaoAtual: PermissaoDeLocalizacao {
        switch gerenciador.authorizationStatus {
        case .notDetermined:
            .naoDeterminada
        case .authorizedWhenInUse, .authorizedAlways:
            gerenciador.accuracyAuthorization == .fullAccuracy ? .aoUsarPrecisa : .aoUsarAproximada
        default:
            .negada
        }
    }

    private func encerrarNoPrazo() {
        guard let leitura else { return }
        concluir(leitura.melhor.map { .success(leitura.comSinais($0)) } ?? .failure(.tempoEsgotado))
    }

    /// Sempre para o GPS antes de devolver: a leitura não sobrevive ao toque que a pediu.
    private func concluir(_ resultado: Result<LeituraDeLocalizacao, ErroDeLocalizacao>) {
        guard let emCurso = leitura else { return }
        leitura = nil
        prazo?.cancel()
        prazo = nil
        gerenciador.stopUpdatingLocation()
        emCurso.continuacao.resume(returning: resultado)
    }

    private func recebeu(latitude: Double, longitude: Double, precisao: Double, instante: Date, simulada: Bool) {
        guard var emCurso = leitura else { return }
        // Os sinais do check-in por código valem para o toque inteiro: uma leitura simulada marca a leitura
        // final mesmo que ela seja descartada abaixo (precisão inválida, posição guardada) ou não seja a melhor.
        if simulada, !emCurso.simulada {
            emCurso.simulada = true
            leitura = emCurso
        }
        // Precisão negativa é posição inválida; posição anterior ao toque é a guardada pelo sistema.
        guard precisao >= 0, instante >= emCurso.inicio.addingTimeInterval(-5),
              let coordenada = try? Coordenada(latitude: latitude, longitude: longitude) else { return }
        let atual = (coordenada: coordenada, precisaoMetros: precisao, instante: instante)
        if let anterior = emCurso.anterior, SaltoDePosicao.houve(de: anterior, para: atual) { emCurso.saltou = true }
        emCurso.anterior = atual
        let nova = LeituraDeLocalizacao(coordenada: coordenada, precisaoHorizontalMetros: precisao)
        if emCurso.melhor.map({ precisao < $0.precisaoHorizontalMetros }) ?? true { emCurso.melhor = nova }
        leitura = emCurso
        if precisao <= emCurso.precisaoSuficienteMetros { concluir(.success(emCurso.comSinais(nova))) }
    }

    private func falhou(negada: Bool, semPosicaoAinda: Bool) {
        // `locationUnknown` é passageiro: o CoreLocation continua tentando até o prazo.
        if semPosicaoAinda { return }
        concluir(.failure(negada ? .permissaoNegada : .semSinal))
    }

    private func permissaoMudou() {
        guard gerenciador.authorizationStatus != .notDetermined else { return }
        let espera = esperandoPermissao
        esperandoPermissao = []
        espera.forEach { $0.resume() }
    }
}

extension LeitorDeLocalizacaoDoSistema: CLLocationManagerDelegate {
    public nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.permissaoMudou() }
    }

    public nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let ultima = locations.last else { return }
        let (latitude, longitude) = (ultima.coordinate.latitude, ultima.coordinate.longitude)
        let (precisao, instante) = (ultima.horizontalAccuracy, ultima.timestamp)
        // Qualquer leitura do lote simulada marca o toque, e não só a última.
        let simulada = locations.contains { $0.sourceInformation?.isSimulatedBySoftware == true }
        Task { @MainActor in
            self.recebeu(latitude: latitude, longitude: longitude, precisao: precisao, instante: instante, simulada: simulada)
        }
    }

    public nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        let codigo = (error as? CLError)?.code
        Task { @MainActor in self.falhou(negada: codigo == .denied, semPosicaoAinda: codigo == .locationUnknown) }
    }
}
