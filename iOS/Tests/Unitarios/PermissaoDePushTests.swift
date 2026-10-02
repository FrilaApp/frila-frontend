@testable import FrilaApresentacao
import FrilaDados
import Foundation
import FrilaDominio
@testable import FrilaInfraestrutura
import Testing
import UserNotifications

@MainActor
@Suite("Permissão de notificação: explicação antes do pedido do sistema (#8)")
struct PermissaoDePushModeloTests {
    @Test("No momento certo, quem o sistema ainda não perguntou vê a explicação, e o pedido do sistema não sai sozinho")
    func ofereceAQuemNaoFoiPerguntado() async {
        let permissao = PermissaoDePushSimulada(estado: .naoPedida)
        let modelo = PermissaoDePushModelo(permissao: permissao)

        await modelo.oferecer()

        #expect(modelo.explicacaoVisivel)
        #expect(modelo.estado == .naoPedida)
        #expect(permissao.pedidos == 0)
    }

    @Test("Quem já respondeu não vê a explicação de novo", arguments: [EstadoDaPermissaoDePush.concedida, .negada])
    func naoOfereceAQuemJaRespondeu(estado: EstadoDaPermissaoDePush) async {
        let permissao = PermissaoDePushSimulada(estado: estado)
        let modelo = PermissaoDePushModelo(permissao: permissao)

        await modelo.oferecer()

        #expect(!modelo.explicacaoVisivel)
        #expect(modelo.estado == estado)
        #expect(permissao.pedidos == 0)
    }

    @Test("Ativar notificações mostra o pedido do sistema uma vez, guarda a resposta e fecha a explicação", arguments: [
        EstadoDaPermissaoDePush.concedida, .negada,
    ])
    func ativar(resposta: EstadoDaPermissaoDePush) async {
        let permissao = PermissaoDePushSimulada(estado: .naoPedida, resposta: resposta)
        let modelo = PermissaoDePushModelo(permissao: permissao)
        await modelo.oferecer()

        await modelo.ativar()

        #expect(permissao.pedidos == 1)
        #expect(modelo.estado == resposta)
        #expect(!modelo.explicacaoVisivel)
        #expect(!modelo.pedindo)
        // Depois da resposta, o momento certo não reabre a explicação.
        await modelo.oferecer()
        #expect(!modelo.explicacaoVisivel)
        #expect(permissao.pedidos == 1)
    }

    @Test("Agora não fecha a explicação sem gastar o pedido do sistema, que continua disponível")
    func agoraNao() async {
        let permissao = PermissaoDePushSimulada(estado: .naoPedida)
        let modelo = PermissaoDePushModelo(permissao: permissao)
        await modelo.oferecer()

        modelo.agoraNao()

        #expect(!modelo.explicacaoVisivel)
        #expect(permissao.pedidos == 0)
        #expect(modelo.estado == .naoPedida)
        // Na mesma sessão, não volta a aparecer sozinha:
        await modelo.oferecer()
        #expect(!modelo.explicacaoVisivel)
        // Mas pelo aviso fixo ela pode ser reaberta:
        await modelo.reabrir()
        #expect(modelo.explicacaoVisivel)
    }

    @Test("A explicação aparece no máximo uma vez por sessão: duas publicações mostram uma vez, o aviso fixo reabre e nova sessão mostra de novo (#8)")
    func explicacaoNoMaximoUmaVezPorSessao() async {
        let permissao = PermissaoDePushSimulada(estado: .naoPedida)
        let sessao1 = PermissaoDePushModelo(permissao: permissao)

        // Primeira publicação / momento certo na sessão: mostra a explicação
        await sessao1.oferecer()
        #expect(sessao1.explicacaoVisivel)
        #expect(sessao1.jaMostradaNaSessao)

        // Usuário adia com "Agora não" ou dispensa
        sessao1.agoraNao()
        #expect(!sessao1.explicacaoVisivel)

        // Segunda publicação na mesma sessão: não mostra a explicação de novo
        await sessao1.oferecer()
        #expect(!sessao1.explicacaoVisivel)

        // O aviso fixo reabre a explicação quando a pessoa quiser
        await sessao1.reabrir()
        #expect(sessao1.explicacaoVisivel)

        sessao1.agoraNao()
        #expect(!sessao1.explicacaoVisivel)

        // Nova sessão do app (uma nova abertura recria o modelo em memória): mostra de novo
        let sessao2 = PermissaoDePushModelo(permissao: permissao)
        #expect(!sessao2.jaMostradaNaSessao)
        await sessao2.oferecer()
        #expect(sessao2.explicacaoVisivel)
    }

    @Test("Se a explicação for aberta pelo aviso fixo primeiro, o momento certo não a mostra de novo na sessão")
    func avisoFixoPrimeiroMarcaSessao() async {
        let permissao = PermissaoDePushSimulada(estado: .naoPedida)
        let modelo = PermissaoDePushModelo(permissao: permissao)

        await modelo.reabrir()
        #expect(modelo.explicacaoVisivel)
        #expect(modelo.jaMostradaNaSessao)

        modelo.agoraNao()
        #expect(!modelo.explicacaoVisivel)

        await modelo.oferecer()
        #expect(!modelo.explicacaoVisivel)
    }

    @Test("Voltar dos Ajustes com a permissão mudada atualiza o estado, nos dois sentidos")
    func mudancaNosAjustes() async {
        let permissao = PermissaoDePushSimulada(estado: .negada)
        let modelo = PermissaoDePushModelo(permissao: permissao)
        #expect(modelo.estado == nil)
        await modelo.atualizar()
        #expect(modelo.estado == .negada)

        permissao.mudarNosAjustes(para: .concedida)
        await modelo.atualizar()
        #expect(modelo.estado == .concedida)

        permissao.mudarNosAjustes(para: .negada)
        await modelo.atualizar()
        #expect(modelo.estado == .negada)
    }

    @Test("O aviso de permissão negada leva aos Ajustes do sistema")
    func abrirAjustes() {
        var aberturas = 0
        let modelo = PermissaoDePushModelo(permissao: PermissaoDePushSimulada(estado: .negada), abrirAjustes: { aberturas += 1 })

        modelo.abrirAjustes()

        #expect(aberturas == 1)
    }
}

@Suite("Permissão de notificação pelo sistema: só alerta e som (#8, B08)")
struct PermissaoDePushDoSistemaTests {
    private static let raiz = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    @Test("O pedido leva alerta e som, sem Time Sensitive, alerta crítico, provisória nem selo")
    func opcoes() {
        #expect(PermissaoDePushDoSistema.opcoes == [.alert, .sound])
    }

    @Test("Cada situação do sistema vira um dos três estados do app")
    func estados() {
        #expect(PermissaoDePushDoSistema.estado(.notDetermined) == .naoPedida)
        #expect(PermissaoDePushDoSistema.estado(.denied) == .negada)
        #expect(PermissaoDePushDoSistema.estado(.authorized) == .concedida)
        #expect(PermissaoDePushDoSistema.estado(.provisional) == .concedida)
        #expect(PermissaoDePushDoSistema.estado(.ephemeral) == .concedida)
    }

    @Test("O app não declara Time Sensitive, alerta crítico nem modo de segundo plano")
    func semTimeSensitiveNemSegundoPlano() throws {
        let direitos = try String(contentsOf: Self.raiz.appending(path: "Sources/App/Frila.entitlements"), encoding: .utf8)
        #expect(!direitos.contains("time-sensitive"))
        #expect(!direitos.contains("critical-alerts"))

        let projeto = try String(contentsOf: Self.raiz.appending(path: "project.yml"), encoding: .utf8)
        let info = try String(contentsOf: Self.raiz.appending(path: "Sources/App/Info.plist"), encoding: .utf8)
        #expect(!projeto.contains("UIBackgroundModes") && !info.contains("UIBackgroundModes"))

        let proibidos = /timeSensitive|criticalAlert|\.provisional\]|providesAppNotificationSettings/
        var achados: [String] = []
        let fontes = Self.raiz.appending(path: "Sources")
        let arquivos = FileManager.default.enumerator(at: fontes, includingPropertiesForKeys: nil)
        while let arquivo = arquivos?.nextObject() as? URL {
            guard arquivo.pathExtension == "swift" else { continue }
            let texto = try String(contentsOf: arquivo, encoding: .utf8)
            if texto.contains(proibidos) { achados.append(arquivo.lastPathComponent) }
        }
        #expect(achados.isEmpty, "opção de notificação que o Frila não pede em \(achados)")
    }

    @Test("Todo texto provisório da permissão está no catálogo pt-BR")
    func textosNoCatalogo() throws {
        let fonte = try String(contentsOf: Self.raiz.appending(path: "Sources/Apresentacao/Fluxos/Push/TextosDoPush.swift"), encoding: .utf8)
        let literais = fonte.matches(of: /String\(localized: "([^"]+)", bundle: bundleApresentacao\)/).map { String($0.output.1) }
        #expect(literais.count >= 19, "os textos do push não foram encontrados na fonte")

        let catalogo = try JSONSerialization.jsonObject(
            with: Data(contentsOf: Self.raiz.appending(path: "Resources/Localizable.xcstrings"))
        ) as? [String: Any]
        let chaves = try #require(catalogo?["strings"] as? [String: Any])
        let fora = literais.filter { chaves[$0] == nil }
        #expect(fora.isEmpty, "textos fora do catálogo: \(fora)")
    }
}
