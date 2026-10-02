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
    private let tokenSimulado: String?
    private let aoReceberToken: @Sendable (String) async -> Void
    private let ligadoAoFirebase = OSAllocatedUnfairLock(initialState: false)

    /// `aoReceberToken` recebe o token do FCM na abertura e a cada troca. O token nunca vai para log.
    public init(tokenSimulado: String? = nil, aoReceberToken: @escaping @Sendable (String) async -> Void) {
        self.tokenSimulado = tokenSimulado
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
        await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
    }

    public func limparEntregues() async {
        let central = UNUserNotificationCenter.current()
        central.removeAllDeliveredNotifications()
        central.removeAllPendingNotificationRequests()
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
