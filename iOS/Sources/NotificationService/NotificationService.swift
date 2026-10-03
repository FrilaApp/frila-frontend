import FrilaDominio
import OSLog
import UserNotifications

/// A extensão de serviço de notificação (#253). O sistema a chama para cada push com
/// `mutable-content: 1`, com o app fechado, em segundo plano ou aberto, antes de mostrar o aviso
/// na central e na tela de bloqueio. Aqui não há regra: o `vinculo_id` do payload e o guardado no
/// App Group vão ao `FiltroDoPushPorVinculo`, do domínio, que decide se o aviso segue como veio ou
/// vira o texto neutro.
///
/// O aviso sem `mutable-content` não passa por aqui, e o app o trata como antes, pelo relógio.
final class NotificationService: UNNotificationServiceExtension {
    /// Só a decisão e o `tipo` vão ao log: nem o `vinculo_id`, nem o texto do aviso.
    private static let logger = Logger(subsystem: "com.frila.org.app.notificationservice", category: "push")
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var conteudo: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        guard let conteudo = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }
        self.conteudo = conteudo
        let original = Self.conteudoDoPush(conteudo)
        let vinculoAtivo = VinculoNoGrupoDoApp().ler()
        let decisao = FiltroDoPushPorVinculo.decidir(payload: original.payload, vinculoAtivo: vinculoAtivo)
        Self.logger.info(
            "push_recebido tipo=\(original.payload["tipo"] ?? "ausente", privacy: .public) com_vinculo=\(original.payload[FiltroDoPushPorVinculo.chaveDoVinculo] != nil, privacy: .public) sessao=\(vinculoAtivo != nil, privacy: .public) decisao=\(String(describing: decisao), privacy: .public)"
        )
        let filtrado = FiltroDoPushPorVinculo.filtrar(original, vinculoAtivo: vinculoAtivo)
        if filtrado != original { Self.aplicar(filtrado, em: conteudo) }
        entregar(conteudo)
    }

    /// A decisão é local e imediata, e o tempo não acaba antes dela. Se acabar, o lado seguro é
    /// não mostrar nada que possa ser de outra conta.
    override func serviceExtensionTimeWillExpire() {
        guard let conteudo else { return }
        Self.logger.error("push_tempo_esgotado decisao=neutralizar")
        Self.aplicar(FiltroDoPushPorVinculo.filtrar(Self.conteudoDoPush(conteudo), vinculoAtivo: nil), em: conteudo)
        entregar(conteudo)
    }

    private func entregar(_ conteudo: UNNotificationContent) {
        contentHandler?(conteudo)
        contentHandler = nil
        self.conteudo = nil
    }

    /// Os textos e os campos de texto do `userInfo`: os de `data`, que o FCM entrega na raiz.
    private static func conteudoDoPush(_ conteudo: UNNotificationContent) -> ConteudoDoPush {
        let campos = conteudo.userInfo.reduce(into: [String: String]()) { campos, par in
            if let chave = par.key as? String, let valor = par.value as? String { campos[chave] = valor }
        }
        return ConteudoDoPush(titulo: conteudo.title, subtitulo: conteudo.subtitle, corpo: conteudo.body, payload: campos)
    }

    /// O que o sistema vai mostrar. Do `userInfo` original fica só o que não é campo de texto
    /// (o `aps`); os campos de `data` passam a ser os do filtrado, e o toque no aviso neutro, sem
    /// `tipo`, não abre nada no app.
    private static func aplicar(_ filtrado: ConteudoDoPush, em conteudo: UNMutableNotificationContent) {
        conteudo.title = filtrado.titulo
        conteudo.subtitle = filtrado.subtitulo
        conteudo.body = filtrado.corpo
        var userInfo = conteudo.userInfo.filter { !($0.value is String) }
        for (chave, valor) in filtrado.payload { userInfo[chave] = valor }
        conteudo.userInfo = userInfo
        conteudo.categoryIdentifier = ""
        conteudo.threadIdentifier = ""
        conteudo.attachments = []
    }
}
