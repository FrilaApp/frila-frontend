import Foundation
import FrilaDominio
import UserNotifications

/// A permissão de notificação pelo `UNUserNotificationCenter`.
public struct PermissaoDePushDoSistema: PermissaoDePush {
    /// Alerta e som, e mais nada (B08): sem Time Sensitive, sem alerta crítico e sem autorização
    /// provisória. O backend não manda contador, então o app também não pede o selo no ícone.
    public static let opcoes: UNAuthorizationOptions = [.alert, .sound]

    public init() {}

    public func estado() async -> EstadoDaPermissaoDePush {
        Self.estado(await UNUserNotificationCenter.current().notificationSettings().authorizationStatus)
    }

    public func pedir() async -> EstadoDaPermissaoDePush {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: Self.opcoes)
        return await estado()
    }

    static func estado(_ situacao: UNAuthorizationStatus) -> EstadoDaPermissaoDePush {
        switch situacao {
        case .notDetermined: .naoPedida
        case .denied: .negada
        case .authorized, .provisional, .ephemeral: .concedida
        @unknown default: .negada
        }
    }
}
