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

    /// A central de notificações do sistema, no que o descarte usa. Os testes trocam por um dublê.
    public struct CentralDoSistema: Sendable {
        public typealias Entregue = (identificador: String, data: Date)

        public var entregues: @Sendable () async -> [Entregue]
        public var remover: @Sendable ([String]) -> Void

        public init(entregues: @escaping @Sendable () async -> [Entregue], remover: @escaping @Sendable ([String]) -> Void) {
            self.entregues = entregues
            self.remover = remover
        }

        public static let doAparelho = CentralDoSistema(
            entregues: {
                await withCheckedContinuation { continuacao in
                    UNUserNotificationCenter.current().getDeliveredNotifications { entregues in
                        continuacao.resume(returning: entregues.map { (identificador: $0.request.identifier, data: $0.date) })
                    }
                }
            },
            remover: { UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: $0) }
        )
    }

    private let tokenSimulado: String?
    private let sistema: RegistroNoSistema
    private let central: CentralDoSistema
    private let aoReceberToken: @Sendable (String) async -> Void
    private let ligadoAoFirebase = OSAllocatedUnfairLock(initialState: false)

    /// `aoReceberToken` recebe o token do FCM na abertura e a cada troca. O token nunca vai para log.
    public init(tokenSimulado: String? = nil, sistema: RegistroNoSistema = .doAparelho, central: CentralDoSistema = .doAparelho,
                aoReceberToken: @escaping @Sendable (String) async -> Void) {
        self.tokenSimulado = tokenSimulado
        self.sistema = sistema
        self.central = central
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

    /// A saída não depende do servidor do Frila: o pedido é ao sistema. A Apple indica
    /// `unregisterForRemoteNotifications` para quando alguém sai de uma conta associada a push, e
    /// diz que o app volta a se registrar com `registerForRemoteNotifications`, que aqui só o
    /// `ativar()` chama
    /// (developer.apple.com/documentation/uikit/uiapplication/unregisterforremotenotifications(),
    /// lida em 02/10/2026). Inferência: a página não diz se o método faz efeito sem rede, nem se o
    /// efeito continua com o app fechado ou depois de reiniciar o iPhone; quem prova é o roteiro
    /// no aparelho (Docs/Push.md, passos 8 a 10).
    public func suspenderEntrega() async {
        await MainActor.run { sistema.desregistrar() }
    }

    /// O aviso entregue no próprio instante já é da conta do vínculo, como no `RoteadorDePush`.
    public func descartarEntregues(antesDe instante: Date) async {
        let antigas = await central.entregues().filter { $0.data < instante }.map(\.identificador)
        if !antigas.isEmpty { central.remover(antigas) }
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
