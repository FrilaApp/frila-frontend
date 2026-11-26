@testable import FrilaApresentacao
import Foundation
import FrilaDominio
import Testing

private actor ServidorDeConvites {
    private(set) var tokens: [String] = []
    var resposta: Result<MembroAdicionado, Error>
    var demora: Duration?

    init(_ resposta: Result<MembroAdicionado, Error>) { self.resposta = resposta }

    func trocarDemora(_ nova: Duration?) { demora = nova }

    func aceitar(_ token: String) async throws -> MembroAdicionado {
        tokens.append(token)
        if let demora { try await Task.sleep(for: demora) }
        return try resposta.get()
    }
}

/// Textos que não são um convite. Montados com interpolação: nenhum código de convite no repositório.
private let textosQueNaoSaoConvite: [String] = {
    let c = String(repeating: "ef", count: 32)
    let o = String(repeating: "ab", count: 32)
    let metade = String(repeating: "ef", count: 16)
    return [
        "",
        "   ",
        "convite",
        "zz\(c)zz",
        "zz\(c)",
        "\(c)zz",
        "\(c) \(o)",
        "\(c)\(o)",
        String(c.dropLast(1)),
        "\(c)e",
        String(repeating: "g", count: 64),
        "https://frilabr.com/app/convite#\(c)zz",
        "https://frilabr.com/app/convite#\(c)#\(o)",
        "https://frilabr.com/app/convite#\(String(c.dropLast(2)))",
        "https://frilabr.com/app/convite#\(c)ef",
        "https://frilabr.com/app/convite",
        "https://frilabr.com/app/convite#",
        "https://frilabr.com/app/outra#\(c)",
        "https://frilabr.com/app/convite/#\(c)",
        "https://frilabr.com/app/convite?x=1#\(c)",
        "https://convite#\(c)",
        "http://frilabr.com/app/convite#\(c)",
        "ftp://frilabr.com/app/convite#\(c)",
        "frilabr.com/app/convite#\(c)",
        "https:///app/convite#\(c)",
        "https://frilabr.com/app/convite#\(metade) \(metade)",
        // Rodada 3 (B-123): num texto, só vale o link de convite do nosso domínio e do nosso caminho, e um só.
        "Entre: https://frilabr.com/app/convite#\(c) e também https://frilabr.com/app/convite#\(o)",
        "Entre: https://frilabr.com/app/convite#\(c) ou https://frilabr.com/app/convite#\(c)",
        "Entre: https://frilabr.com/app/convite#\(c) ou https://frila-web-dev.frilabr.workers.dev/app/convite#\(o)",
        "Entre: https://exemplo.test/app/convite#\(c)",
        "Entre: https://frilabr.com.exemplo.org/app/convite#\(c)",
        "Entre: https://exemplofrilabr.com/app/convite#\(c)",
        "Entre: https://www.frilabr.com/app/convite#\(c)",
        "Entre: https://frilabr.com/app/convite-antigo#\(c)",
        "Entre: https://frilabr.com/app/outra#\(c)",
        "Entre: https://frilabr.com/convite#\(c)",
        "Entre: https://frilabr.com/app/convite#\(c)zz",
        "Entre: https://frilabr.com/app/convite#\(c).",
        "Entre: https://frilabr.com/app/convite#\(String(c.dropLast(2))) agora",
        "Entre: http://frilabr.com/app/convite#\(c)",
        "Entre: xhttps://frilabr.com/app/convite#\(c)",
        "Entre em https://exemplo.test/?u=https://frilabr.com/app/convite#\(c)",
        "Seu código: \(c). Abra o app e cole.",
        "Código \(c) e link https://exemplo.test/app/convite#\(o)",
    ]
}()

/// O que vale como convite: o código de 64 hexadecimais, o link inteiro do convite ou um texto com exatamente um link de
/// convite do Frila (rodada 3 do B-123). Com dois links o app não escolhe um, e um código nunca sai do miolo de um texto ou
/// de um identificador (o Android já fez as duas coisas).
@Suite("Convite da casa: link e código")
struct ConviteDaCasaTests {
    /// Montado na hora: nenhum código de convite no repositório.
    private static let codigo = String(repeating: "ef", count: 32)
    private static let outro = String(repeating: "ab", count: 32)

    @Test("Vale o código puro de 64 hexadecimais, com os espaços das pontas aparados, e sai em minúsculas")
    func codigoPuro() {
        #expect(ConviteDaCasa.extrairToken(de: Self.codigo, origens: Self.origens) == Self.codigo)
        #expect(ConviteDaCasa.extrairToken(de: "  \(Self.codigo)\n", origens: Self.origens) == Self.codigo)
        #expect(ConviteDaCasa.extrairToken(de: Self.codigo.uppercased(), origens: Self.origens) == Self.codigo)
        #expect(ConviteDaCasa.extrairToken(de: "\t\(Self.codigo.uppercased()) ", origens: Self.origens) == Self.codigo)
    }

    /// As origens que o "Tenho um convite" reconhece: a web de produção e a de dev, as mesmas de `OrigemDaWeb`.
    private static let origens = [OrigemDaWeb.producao, OrigemDaWeb.dev]

    @Test("Vale o link inteiro do convite, da web de produção ou da de dev, com o código no fragmento", arguments: [
        "https://frilabr.com/app/convite#",
        "https://frila-web-dev.frilabr.workers.dev/app/convite#",
    ])
    func linkInteiro(prefixo: String) {
        #expect(ConviteDaCasa.extrairToken(de: prefixo + Self.codigo, origens: Self.origens) == Self.codigo)
        #expect(ConviteDaCasa.extrairToken(de: "  \(prefixo)\(Self.codigo.uppercased())  ", origens: Self.origens) == Self.codigo)
    }

    @Test("Um texto com exatamente um link de convite do nosso domínio vale, em qualquer lugar do texto: sai o mesmo token que o link sozinho", arguments: [
        "https://frilabr.com/app/convite#",
        "https://frila-web-dev.frilabr.workers.dev/app/convite#",
    ])
    func linkNoMeioDeUmTexto(prefixo: String) {
        let link = prefixo + Self.codigo
        let textos = [
            "Oi! Entre pela casa: \(link)",
            "\(link) e mais texto",
            "Antes\n\(link)\nDepois",
            "Antes \(link) depois, com mais frases. Até logo!",
            "  \(prefixo)\(Self.codigo.uppercased()) \n",
            "Link:\r\n\(link)",
        ]
        for texto in textos {
            #expect(ConviteDaCasa.extrairToken(de: texto, origens: Self.origens) == Self.codigo, "\(texto.prefix(14))")
        }
    }

    @Test("A mensagem do convite inteira, com e sem prazo, entrega o mesmo token que o link sozinho (rodada 3 do B-123)")
    func mensagemInteiraDoConvite() {
        let validade = Date(timeIntervalSince1970: 1_800_000_000)
        for origem in Self.origens {
            let link = ConviteDaCasa.link(origem: origem, token: Self.codigo) ?? ""
            for prazo in [validade, nil] {
                let convite = ConviteGerado(link: link, email: "paulo.lima@exemplo.com", papel: .operador, nomeDaCasa: "Padaria do Bairro", expiraEm: prazo)
                #expect(ConviteDaCasa.extrairToken(de: convite.mensagem, origens: Self.origens) == Self.codigo)
            }
        }
    }

    @Test("Qualquer outra coisa é recusada: letra em volta, dois códigos, tamanho errado, link com texto depois ou de outro formato", arguments: textosQueNaoSaoConvite)
    func recusado(texto: String) {
        #expect(ConviteDaCasa.extrairToken(de: texto, origens: Self.origens) == nil)
    }

    @Test("O link do convite é <origem>/convite#<token>, só com um código de 64 hexadecimais")
    func montaOLink() {
        #expect(ConviteDaCasa.link(origem: "https://frilabr.com/app", token: Self.codigo) == "https://frilabr.com/app/convite#\(Self.codigo)")
        #expect(ConviteDaCasa.link(origem: "https://frilabr.com/app/", token: Self.codigo.uppercased()) == "https://frilabr.com/app/convite#\(Self.codigo)")
        #expect(ConviteDaCasa.link(origem: "https://frilabr.com/app", token: "curto") == nil)
        #expect(ConviteDaCasa.link(origem: "https://frilabr.com/app", token: Self.codigo + "ab") == nil)
        // O link montado é aceito de volta pelo "Tenho um convite".
        let link = ConviteDaCasa.link(origem: OrigemDaWeb.dev, token: Self.outro)
        #expect(link.flatMap { ConviteDaCasa.extrairToken(de: $0, origens: Self.origens) } == Self.outro)
    }

    @Test("A origem da web vem do ambiente do app: só frila-prod abre a web de produção")
    func origemPeloAmbiente() {
        #expect(OrigemDaWeb.doAmbiente("frila-prod") == "https://frilabr.com/app")
        #expect(OrigemDaWeb.doAmbiente(" frila-prod\n") == "https://frilabr.com/app")
        for outro in ["frila-dev", "local", "", "Frila-Prod", "prod", nil] {
            #expect(OrigemDaWeb.doAmbiente(outro) == "https://frila-web-dev.frilabr.workers.dev/app", "\(outro ?? "nil")")
        }
        #expect(OrigemDaWeb.producao == "https://frilabr.com/app")
    }

    @Test("Os arquivos de configuração de cada esquema dizem o ambiente que a origem espera")
    func ambientesDosEsquemas() throws {
        let pasta = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Configurations")
        func ambiente(_ arquivo: String) throws -> String {
            let texto = try String(contentsOf: pasta.appendingPathComponent(arquivo), encoding: .utf8)
            let linha = try #require(texto.split(separator: "\n").first { $0.hasPrefix("FRILA_ENVIRONMENT") })
            return linha.split(separator: "=").last.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        }
        #expect(OrigemDaWeb.doAmbiente(try ambiente("Prod.xcconfig")) == OrigemDaWeb.producao)
        #expect(OrigemDaWeb.doAmbiente(try ambiente("Dev.xcconfig")) == OrigemDaWeb.dev)
        #expect(OrigemDaWeb.doAmbiente(try ambiente("Beta.xcconfig")) == OrigemDaWeb.dev)
        #expect(OrigemDaWeb.doAmbiente(try ambiente("Local.xcconfig")) == OrigemDaWeb.dev)
    }
}

@MainActor
@Suite("Tenho um convite: aceitar_convite_membro (0.2.73)")
struct TenhoUmConviteViewModelTests {
    private let codigo = String(repeating: "ef", count: 32)
    private let casa = UUID(uuidString: "30000000-0000-0000-0000-000000000003")!

    private func modelo(_ servidor: ServidorDeConvites, prazo: Duration = .seconds(5)) -> TenhoUmConviteViewModel {
        TenhoUmConviteViewModel(prazo: prazo, aceitar: { try await servidor.aceitar($0) })
    }

    private func entrou() -> Result<MembroAdicionado, Error> {
        .success(MembroAdicionado(estabelecimentoID: casa, papel: .operador))
    }

    @Test("Aceita o código puro e o link inteiro: o servidor recebe só o token, e a pessoa vê a casa em que entrou")
    func aceitaComSucesso() async {
        for colado in [codigo, "  \(codigo)\n", "https://frilabr.com/app/convite#\(codigo)"] {
            let servidor = ServidorDeConvites(entrou())
            let vm = modelo(servidor)
            vm.texto = colado

            await vm.aceitarConvite()

            #expect(await servidor.tokens == [codigo])
            #expect(vm.aceito == ConviteAceito(estabelecimentoID: casa, papel: .operador))
            #expect(vm.erro == nil)
            #expect(!vm.enviando)
            #expect(vm.texto == "")
        }
    }

    @Test("Link ou código inválido não chega ao servidor: a mensagem é local, e editar o texto a tira")
    func formatoInvalidoNaoChamaOServidor() async {
        let invalidos = ["", "   ", "oi", "zz" + codigo + "zz", codigo + codigo, String(codigo.dropLast(2)),
                         "https://frilabr.com/app/convite#\(codigo)zz", "http://frilabr.com/app/convite#\(codigo)",
                         "https://exemplo.test/app/convite#\(codigo)"]
        for texto in invalidos {
            let servidor = ServidorDeConvites(entrou())
            let vm = modelo(servidor)
            vm.texto = texto

            await vm.aceitarConvite()

            #expect(vm.erro == TextosDaEquipeDaCasa.conviteFormatoInvalido, "texto \(texto.prefix(12))")
            #expect(vm.aceito == nil)
            #expect(await servidor.tokens.isEmpty)
            #expect(!vm.enviando)
            vm.texto = texto + "x"
            #expect(vm.erro == nil)
        }
    }

    @Test("Recusas do servidor: convite que não vale, conta de profissional, suspensa, sessão e sem rede, cada uma na sua frase")
    func recusasDoServidor() async {
        let casos: [(ErroDaApi, String)] = [
            (ErroDaApi(codigo: .desconhecido, codigoOriginal: "convite_invalido"), TextosDaEquipeDaCasa.conviteInvalido),
            (ErroDaApi(codigo: .desconhecido, codigoOriginal: "convite_de_outro_email"), TextosDaEquipeDaCasa.conviteDeOutroEmail),
            (ErroDaApi(codigo: .perfilIncompativel), TextosDaEquipeDaCasa.convitePerfilIncompativel),
            (ErroDaApi(codigo: .semPermissao, detalhes: "conta_suspensa"), TextosDaEquipeDaCasa.contaSuspensa),
            (ErroDaApi(codigo: .naoAutenticado), TextosDaEquipeDaCasa.sessao),
            (ErroDaApi(codigo: .semRede), TextosDaEquipeDaCasa.semRede),
            (ErroDaApi(codigo: .desconhecido), TextosDaEquipeDaCasa.conviteIncerto),
            (ErroDaApi(codigo: .respostaInvalida), TextosDaEquipeDaCasa.conviteIncerto),
            (ErroDaApi(codigo: .semPermissao), TextosDaEquipeDaCasa.conviteIncerto),
        ]
        for (falha, mensagem) in casos {
            let servidor = ServidorDeConvites(.failure(falha))
            let vm = modelo(servidor)
            vm.texto = codigo

            await vm.aceitarConvite()

            #expect(vm.erro == mensagem, "\(falha.codigoOriginal) \(falha.detalhes ?? "")")
            #expect(vm.aceito == nil)
            #expect(!vm.enviando)
            // A pessoa pode tentar de novo com o mesmo texto.
            #expect(vm.texto == codigo)
        }
    }

    @Test("Resposta ilegível ou prazo vencido: a mensagem avisa onde conferir, porque o convite pode ter sido aceito")
    func falhaIncerta() async {
        let servidor = ServidorDeConvites(.failure(URLError(.cannotParseResponse)))
        let vm = modelo(servidor)
        vm.texto = codigo
        await vm.aceitarConvite()
        #expect(vm.erro == TextosDaEquipeDaCasa.conviteIncerto)
        #expect(!vm.enviando)

        let lento = ServidorDeConvites(entrou())
        await lento.trocarDemora(.seconds(30))
        let vmLento = modelo(lento, prazo: .milliseconds(50))
        vmLento.texto = codigo
        await vmLento.aceitarConvite()
        #expect(vmLento.erro == TextosDaEquipeDaCasa.conviteIncerto)
        #expect(vmLento.aceito == nil)
        #expect(!vmLento.enviando)
    }

    @Test("Dois toques em Aceitar mandam um pedido só, e o texto não muda enquanto o pedido está em voo")
    func toqueDuplo() async {
        let servidor = ServidorDeConvites(entrou())
        let vm = modelo(servidor)
        vm.texto = codigo

        async let primeiro: Void = vm.aceitarConvite()
        async let segundo: Void = vm.aceitarConvite()
        _ = await (primeiro, segundo)

        #expect(await servidor.tokens.count == 1)
        // Depois de aceito, o texto não volta a ser editado e o convite não é enviado de novo.
        vm.texto = "outro"
        #expect(vm.texto == "")
        await vm.aceitarConvite()
        #expect(await servidor.tokens.count == 1)
    }

    @Test("Convite aceito sem a casa ou sem o papel na resposta ainda vale: os dois são opcionais")
    func respostaSemCasaNemPapel() async {
        let servidor = ServidorDeConvites(.success(MembroAdicionado(estabelecimentoID: nil, papel: nil)))
        let vm = modelo(servidor)
        vm.texto = codigo

        await vm.aceitarConvite()

        #expect(vm.aceito == ConviteAceito(estabelecimentoID: nil, papel: nil))
    }
}
