@preconcurrency import FirebaseMessaging
import Foundation
import FrilaDominio
import os
import UIKit
import UserNotifications

/// O push pelo FCM, que no iOS entrega pelo APNs (B17). Pede o registro ao sistema, entrega o
/// token do APNs ao Firebase e repassa o token do FCM a quem o registra no servidor.
///
/// Sem `GoogleService-Info.plist` (esquema Local) o Firebase não é configurado, e o canal entrega
/// o `tokenSimulado`, se houver: o resto do caminho roda contra o dublê como rodaria com o FCM.
public final class CanalDePushDoAparelho: NSObject, CanalDePush, MessagingDelegate, @unchecked Sendable {
    /// O registro do app para push remoto no sistema. Os testes trocam por um dublê.
    public struct RegistroNoSistema: Sendable {
        public var registrar: @MainActor @Sendable () -> Void
        public var desregistrar: @MainActor @Sendable () -> Void

        public init(registrar: @escaping @MainActor @Sendable () -> Void, desregistrar: @escaping @MainActor @Sendable () -> Void) {
            self.registrar = registrar
            self.desregistrar = desregistrar
        }

        public static let doAparelho = RegistroNoSistema(
            registrar: { UIApplication.shared.registerForRemoteNotifications() },
            desregistrar: { UIApplication.shared.unregisterForRemoteNotifications() }
        )
    }

    private let tokenSimulado: String?
    private let sistema: RegistroNoSistema
    private let aoReceberToken: @Sendable (String) async -> Void
    private let ligadoAoFirebase = OSAllocatedUnfairLock(initialState: false)

    /// `aoReceberToken` recebe o token do FCM na abertura e a cada troca. O token nunca vai para log.
    public init(tokenSimulado: String? = nil, sistema: RegistroNoSistema = .doAparelho,
                aoReceberToken: @escaping @Sendable (String) async -> Void) {
        self.tokenSimulado = tokenSimulado
        self.sistema = sistema
        self.aoReceberToken = aoReceberToken
    }

    public func ativar() async {
        guard RelatorioDeFalhas.firebaseConfigurado else {
            if let tokenSimulado { await aoReceberToken(tokenSimulado) }
            return
        }
        ligarAoFirebase()
        // O sistema responde no `AppDelegate`, que chama `recebeu(tokenDoAPNs:)`. Pedir de novo a
        // cada abertura é o que a Apple recomenda: o token pode ter mudado.
        await MainActor.run { sistema.registrar() }
    }

    public func limparEntregues() async {
        let central = UNUserNotificationCenter.current()
        central.removeAllDeliveredNotifications()
        central.removeAllPendingNotificationRequests()
    }

    /// `unregisterForRemoteNotifications` é do próprio aparelho e não precisa de rede: o sistema
    /// para de entregar push remoto a este app até o próximo `registerForRemoteNotifications`, que
    /// só o `ativar()` chama. Vale com o app fechado e depois de reiniciar o iPhone.
    public func suspenderEntrega() async {
        await MainActor.run { sistema.desregistrar() }
    }

    public func descartarEntregues(antesDe instante: Date) async {
        let central = UNUserNotificationCenter.current()
        let antigas: [String] = await withCheckedContinuation { continuacao in
            central.getDeliveredNotifications { entregues in
                continuacao.resume(returning: entregues.filter { $0.date < instante }.map(\.request.identifier))
            }
        }
        if !antigas.isEmpty { central.removeDeliveredNotifications(withIdentifiers: antigas) }
    }

    /// O token do APNs, do `didRegisterForRemoteNotificationsWithDeviceToken`. O proxy do Firebase
    /// está desligado (`FirebaseAppDelegateProxyEnabled` no Info.plist), então a entrega é aqui, à
    /// vista, e não por troca de método em tempo de execução.
    public static func recebeu(tokenDoAPNs: Data) {
        guard RelatorioDeFalhas.firebaseConfigurado else { return }
        Messaging.messaging().apnsToken = tokenDoAPNs
    }

    private func ligarAoFirebase() {
        let primeiraVez = ligadoAoFirebase.withLock { ligado in
            defer { ligado = true }
            return !ligado
        }
        if primeiraVez { Messaging.messaging().delegate = self }
    }

    // MARK: MessagingDelegate

    public func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        let entregar = aoReceberToken
        Task { await entregar(fcmToken) }
    }
}
