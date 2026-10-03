import FrilaApresentacao
import FrilaDominio
import FrilaInfraestrutura
import OSLog
import UIKit
import UserNotifications

/// Os três roteadores do app. Vivem no `AppDelegate` porque o toque que abre o app chega antes de
/// qualquer tela existir: o `RoteadorDePush` guarda esse toque até a conta ser conhecida.
@MainActor
final class NavegacaoDoApp {
    let profissional = RoteadorDoProfissional()
    let contratante = RoteadorDoContratante()
    let push: RoteadorDePush

    init() {
        push = RoteadorDePush(profissional: profissional, contratante: contratante)
    }
}

/// O que o sistema entrega ao app sobre notificações (#8): o token do APNs e as notificações,
/// com o app aberto, em segundo plano ou fechado. Aqui não há regra: o token vai para o canal do
/// push, e o toque vai para o `RoteadorDePush`, que decide.
///
/// O sistema chama os dois protocolos na thread principal; a conformidade `@preconcurrency` deixa
/// os métodos no ator principal, sem troca de thread entre o toque e o roteador.
final class AppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    private static let logger = Logger(subsystem: "com.frila.org.app", category: "push")
    let navegacao = NavegacaoDoApp()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-FRILA_SCENARIO") || args.contains(where: { $0.hasPrefix("-FRILA_") }) {
            UIView.setAnimationsEnabled(false)
        }
        #endif
        // Antes de a abertura terminar: é assim que o toque que abriu o app chega ao delegate.
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        CanalDePushDoAparelho.recebeu(tokenDoAPNs: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Self.logger.error("registro_no_apns_falhou tipo=\(String(reflecting: type(of: error)), privacy: .public)")
    }

    // MARK: UNUserNotificationCenterDelegate

    /// App aberto: a notificação aparece como aparece fora dele, com faixa e som, e o toque nela
    /// cai no método de baixo. Só é mostrado o aviso que o toque abriria para a conta que está na
    /// tela; o resto (outra conta, outro perfil, antes do vínculo, sem `tipo`) não aparece.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let mostrar = navegacao.push.apresenta(payload: notification.request.content.userInfo, entregueEm: notification.date)
        completionHandler(mostrar ? [.banner, .list, .sound] : [])
    }

    /// O toque na notificação, com o app aberto, em segundo plano ou fechado. Só o toque de abrir
    /// conta: dispensar a notificação não abre nada.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            navegacao.push.tocar(payload: response.notification.request.content.userInfo, entregueEm: response.notification.date)
        }
        completionHandler()
    }
}
