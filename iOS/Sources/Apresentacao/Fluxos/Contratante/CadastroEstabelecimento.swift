import FrilaDominio
import MapKit
import Observation
import SwiftUI

private enum TextosCadastro {
    static let titulo = String(localized: "Dados do negócio", bundle: bundleApresentacao)
    static let subtitulo = String(localized: "Conta de contratante", bundle: bundleApresentacao)
    static let nome = String(localized: "Nome", bundle: bundleApresentacao)
    static let nomeCampo = String(localized: "Nome do estabelecimento", bundle: bundleApresentacao)
    static let documento = String(localized: "Documento", bundle: bundleApresentacao)
    static let documentoCampo = String(localized: "CNPJ ou CPF", bundle: bundleApresentacao)
    static let soNumeros = String(localized: "Só números", bundle: bundleApresentacao)
    static let tipo = String(localized: "Tipo", bundle: bundleApresentacao)
    static let tipoCampo = String(localized: "Tipo do estabelecimento", bundle: bundleApresentacao)
    static let endereco = String(localized: "Endereço", bundle: bundleApresentacao)
    static let buscarEndereco = String(localized: "Buscar endereço", bundle: bundleApresentacao)
    static let buscarEnderecoAjuda = String(localized: "Pesquisa o endereço digitado e atualiza o mapa", bundle: bundleApresentacao)
    static let selecionarEnderecoAjuda = String(localized: "Seleciona este endereço e ajusta o marcador no mapa", bundle: bundleApresentacao)
    static let regiaoAdministrativa = String(localized: "Região Administrativa", bundle: bundleApresentacao)
    static let selecioneRegiaoAdministrativa = String(localized: "Selecione a Região Administrativa", bundle: bundleApresentacao)
    static let selecionar = String(localized: "Selecionar", bundle: bundleApresentacao)
    static let regiaoAdministrativaAjuda = String(localized: "A Região Administrativa do DF onde o estabelecimento fica. Ex.: Plano Piloto, Águas Claras, Taguatinga.", bundle: bundleApresentacao)
    static let ponto = String(localized: "Ponto do estabelecimento", bundle: bundleApresentacao)
    static let pontoNaoMarcado = String(localized: "Ponto ainda não marcado", bundle: bundleApresentacao)
    static let mapa = String(localized: "Mapa do estabelecimento", bundle: bundleApresentacao)
    static let dicaMapa = String(localized: "Ajuste o ponto movendo o marcador no mapa.", bundle: bundleApresentacao)
    static let dicaMarcador = String(localized: "Arraste para ajustar o ponto do estabelecimento no mapa", bundle: bundleApresentacao)
    static let responsavel = String(localized: "Responsável", bundle: bundleApresentacao)
    static let salvarEPublicar = String(localized: "Salvar e publicar a primeira vaga", bundle: bundleApresentacao)
    static let continuar = String(localized: "Continuar", bundle: bundleApresentacao)
    static let publicarVaga = String(localized: "Publicar vaga", bundle: bundleApresentacao)
    static let documentoDuplicado = String(localized: "Este documento já está cadastrado.", bundle: bundleApresentacao)
    static let documentoDuplicadoMensagem = String(localized: "CNPJ ou CPF: este documento já tem um estabelecimento no Frila. Se o negócio é seu, entre com o e-mail usado nesse cadastro.", bundle: bundleApresentacao)
    static let ajudaSobCta = String(localized: "Revise o CNPJ ou CPF para seguir.", bundle: bundleApresentacao)
    static let falha = String(localized: "Não foi possível cadastrar o estabelecimento. Tente novamente.", bundle: bundleApresentacao)
    static let confiraCampo = String(localized: "Confira o campo indicado.", bundle: bundleApresentacao)
    static let campoObrigatorio = String(localized: "Preencha este campo.", bundle: bundleApresentacao)
    static let campoInvalido = String(localized: "Confira o valor informado.", bundle: bundleApresentacao)
    static let alimentacao = String(localized: "Alimentação", bundle: bundleApresentacao)
    static let evento = String(localized: "Evento", bundle: bundleApresentacao)
    static let varejo = String(localized: "Varejo", bundle: bundleApresentacao)
    static let logistica = String(localized: "Logística", bundle: bundleApresentacao)
    static let servicoDomestico = String(localized: "Serviço doméstico", bundle: bundleApresentacao)
    static let outro = String(localized: "Outro", bundle: bundleApresentacao)
}

@MainActor @Observable
public final class CadastroEstabelecimentoViewModel {
    public var nome = ""
    public var documento = ""
    public var tipo: TipoEstabelecimento = .foodService
    public var endereco = ""
    /// Região Administrativa do DF, obrigatória desde o contrato 0.2.20. Texto livre: quem informa é a casa.
    public var regiaoAdministrativa = ""
    public var ponto: CLLocationCoordinate2D?
    public private(set) var alvoDaCamera: CLLocationCoordinate2D?
    public var sugestoes: [MKMapItem] = []
    public var carregandoBusca = false
    public private(set) var enviando = false
    public private(set) var erro: ErroDeCadastroEstabelecimento?
    public private(set) var concluido = false
    public private(set) var estabelecimentoCriado: Estabelecimento?
    private let cadastrar: (CadastroEstabelecimento) async throws -> Estabelecimento

    public init(api: any ApiCliente) {
        cadastrar = { try await api.cadastrarEstabelecimento($0) }
    }

    public init(cadastrar: @escaping (CadastroEstabelecimento) async throws -> Estabelecimento) {
        self.cadastrar = cadastrar
    }

    public var documentoFormatado: String {
        get { Self.formatarDocumento(documento) }
        set { atualizarDocumento(newValue) }
    }

    static func formatarDocumento(_ texto: String) -> String {
        let digitos = String(texto.filter(\.isNumber).prefix(14))
        if digitos.count <= 11 {
            return Self.mascara(digitos, padroes: [(3, "."), (6, "."), (9, "-")])
        }
        return Self.mascara(digitos, padroes: [(2, "."), (5, "."), (8, "/"), (12, "-")])
    }

    public func atualizarDocumento(_ texto: String) { documento = String(texto.filter(\.isNumber).prefix(14)) }

    public func buscarEndereco() async {
        guard !endereco.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        carregandoBusca = true
        defer { carregandoBusca = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = endereco
        do { sugestoes = try await MKLocalSearch(request: request).start().mapItems }
        catch { sugestoes = [] }
    }

    /// As 35 Regiões Administrativas oficiais do Distrito Federal (fonte oficial GDF / SEGOV: https://segov.df.gov.br/category/administracoes-regionais).
    public static let regioesAdministrativas: [String] = [
        "Água Quente",
        "Águas Claras",
        "Arapoanga",
        "Arniqueira",
        "Brazlândia",
        "Candangolândia",
        "Ceilândia",
        "Cruzeiro",
        "Fercal",
        "Gama",
        "Guará",
        "Itapoã",
        "Jardim Botânico",
        "Lago Norte",
        "Lago Sul",
        "Núcleo Bandeirante",
        "Paranoá",
        "Park Way",
        "Planaltina",
        "Plano Piloto",
        "Recanto das Emas",
        "Riacho Fundo",
        "Riacho Fundo II",
        "Samambaia",
        "Santa Maria",
        "São Sebastião",
        "SCIA / Estrutural",
        "SIA",
        "Sobradinho",
        "Sobradinho II",
        "Sol Nascente/Pôr do Sol",
        "Sudoeste/Octogonal",
        "Taguatinga",
        "Varjão",
        "Vicente Pires"
    ]

    private struct RegraCasamentoRA {
        let regex: NSRegularExpression
        let regiao: String

        init?(padrao: String, regiao: String) {
            guard let regex = try? NSRegularExpression(pattern: padrao, options: [.caseInsensitive]) else { return nil }
            self.regex = regex
            self.regiao = regiao
        }
    }

    private static let regrasDeCasamento: [RegraCasamentoRA] = [
        RegraCasamentoRA(padrao: #"\b(riacho\s+fundo\s+(ii|2))\b"#, regiao: "Riacho Fundo II"),
        RegraCasamentoRA(padrao: #"\b(sobradinho\s+(ii|2))\b"#, regiao: "Sobradinho II"),
        RegraCasamentoRA(padrao: #"\briacho\s+fundo\b"#, regiao: "Riacho Fundo"),
        RegraCasamentoRA(padrao: #"\bsobradinho\b"#, regiao: "Sobradinho"),
        RegraCasamentoRA(padrao: #"\bagua\s+quente\b"#, regiao: "Água Quente"),
        RegraCasamentoRA(padrao: #"\baguas\s+claras\b"#, regiao: "Águas Claras"),
        RegraCasamentoRA(padrao: #"\barapoanga\b"#, regiao: "Arapoanga"),
        RegraCasamentoRA(padrao: #"\barniqueira(s)?\b"#, regiao: "Arniqueira"),
        RegraCasamentoRA(padrao: #"\bbrazlandia\b"#, regiao: "Brazlândia"),
        RegraCasamentoRA(padrao: #"\bcandangolandia\b"#, regiao: "Candangolândia"),
        RegraCasamentoRA(padrao: #"\bceilandia\b"#, regiao: "Ceilândia"),
        RegraCasamentoRA(padrao: #"\bcruzeiro\b"#, regiao: "Cruzeiro"),
        RegraCasamentoRA(padrao: #"\bfercal\b"#, regiao: "Fercal"),
        RegraCasamentoRA(padrao: #"\bgama\b"#, regiao: "Gama"),
        RegraCasamentoRA(padrao: #"\bguara\b"#, regiao: "Guará"),
        RegraCasamentoRA(padrao: #"\bitapoa\b"#, regiao: "Itapoã"),
        RegraCasamentoRA(padrao: #"\bjardim\s+botanico\b"#, regiao: "Jardim Botânico"),
        RegraCasamentoRA(padrao: #"\blago\s+norte\b"#, regiao: "Lago Norte"),
        RegraCasamentoRA(padrao: #"\blago\s+sul\b"#, regiao: "Lago Sul"),
        RegraCasamentoRA(padrao: #"\bnucleo\s+bandeirante\b"#, regiao: "Núcleo Bandeirante"),
        RegraCasamentoRA(padrao: #"\bparanoa\b"#, regiao: "Paranoá"),
        RegraCasamentoRA(padrao: #"\bpark\s+way\b"#, regiao: "Park Way"),
        RegraCasamentoRA(padrao: #"\bplanaltina\b"#, regiao: "Planaltina"),
        RegraCasamentoRA(padrao: #"\b(plano\s+piloto|asa\s+sul|asa\s+norte|noroeste|vila\s+planalto)\b"#, regiao: "Plano Piloto"),
        RegraCasamentoRA(padrao: #"\brecanto\s+das\s+emas\b"#, regiao: "Recanto das Emas"),
        RegraCasamentoRA(padrao: #"\bsamambaia\b"#, regiao: "Samambaia"),
        RegraCasamentoRA(padrao: #"\bsanta\s+maria\b"#, regiao: "Santa Maria"),
        RegraCasamentoRA(padrao: #"\bsao\s+sebastiao\b"#, regiao: "São Sebastião"),
        RegraCasamentoRA(padrao: #"\b(scia|estrutural|cidade\s+estrutural)\b"#, regiao: "SCIA / Estrutural"),
        RegraCasamentoRA(padrao: #"\b(sia|setor\s+de\s+industria\s+e\s+abastecimento)\b"#, regiao: "SIA"),
        RegraCasamentoRA(padrao: #"\b(sol\s+nascente|por\s+do\s+sol)\b"#, regiao: "Sol Nascente/Pôr do Sol"),
        RegraCasamentoRA(padrao: #"\b(sudoeste|octogonal)\b"#, regiao: "Sudoeste/Octogonal"),
        RegraCasamentoRA(padrao: #"\btaguatinga\b"#, regiao: "Taguatinga"),
        RegraCasamentoRA(padrao: #"\bvarjao\b"#, regiao: "Varjão"),
        RegraCasamentoRA(padrao: #"\bvicente\s+pires\b"#, regiao: "Vicente Pires")
    ].compactMap { $0 }

    public static func casarRegiaoAdministrativa(noTexto texto: String) -> String? {
        let normalizado = texto
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .lowercased()
        let range = NSRange(normalizado.startIndex..<normalizado.endIndex, in: normalizado)
        for regra in regrasDeCasamento {
            if regra.regex.firstMatch(in: normalizado, options: [], range: range) != nil {
                return regra.regiao
            }
        }
        return nil
    }

    public static func inferirRegiaoAdministrativa(de item: MKMapItem) -> String? {
        let placemark = item.placemark
        if let subLocality = placemark.subLocality, let casada = casarRegiaoAdministrativa(noTexto: subLocality) {
            return casada
        }
        if let subAdmin = placemark.subAdministrativeArea, let casada = casarRegiaoAdministrativa(noTexto: subAdmin) {
            return casada
        }
        if let title = placemark.title, let casada = casarRegiaoAdministrativa(noTexto: title) {
            return casada
        }
        if let name = placemark.name, let casada = casarRegiaoAdministrativa(noTexto: name) {
            return casada
        }
        if let itemName = item.name, let casada = casarRegiaoAdministrativa(noTexto: itemName) {
            return casada
        }
        return nil
    }

    public func selecionar(_ item: MKMapItem) {
        endereco = item.name.map { "\($0), \(item.placemark.title ?? "")" } ?? (item.placemark.title ?? endereco)
        ponto = item.placemark.coordinate
        alvoDaCamera = item.placemark.coordinate
        if let ra = Self.inferirRegiaoAdministrativa(de: item) {
            regiaoAdministrativa = ra
        } else {
            regiaoAdministrativa = ""
        }
        sugestoes = []
    }

    public func salvar() async {
        guard !enviando else { return }
        erro = nil
        guard !nome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { erro = .campo(.nome, .obrigatorio); return }
        guard documento.count == 11 || documento.count == 14 else { erro = .campo(.documento, .invalido); return }
        guard !endereco.isEmpty, let ponto else { erro = .campo(.endereco, .obrigatorio); return }
        guard let coordenada = try? Coordenada(latitude: ponto.latitude, longitude: ponto.longitude) else { erro = .campo(.endereco, .invalido); return }
        let regiao = regiaoAdministrativa.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !regiao.isEmpty else { erro = .campo(.regiaoAdministrativa, .obrigatorio); return }
        enviando = true
        defer { enviando = false }
        do {
            estabelecimentoCriado = try await cadastrar(CadastroEstabelecimento(nome: nome.trimmingCharacters(in: .whitespacesAndNewlines), documento: documento, tipo: tipo, endereco: endereco, regiaoAdministrativa: regiao, ponto: coordenada))
            concluido = true
        } catch let api as ErroDaApi {
            switch api.codigo {
            case .documentoJaCadastrado: erro = .documentoDuplicado
            case .campoObrigatorio: erro = .campo(Self.campo(api.detalhes), .obrigatorio)
            case .campoInvalido: erro = .campo(Self.campo(api.detalhes), .invalido)
            case .semRede: erro = .semRede
            default: erro = .falha
            }
        } catch { erro = .falha }
    }

    private static func campo(_ detalhes: String?) -> CampoCadastro {
        switch detalhes { case "nome": .nome; case "documento": .documento; case "tipo": .tipo; case "regiao_administrativa": .regiaoAdministrativa; case "endereco", "ponto", "latitude", "longitude": .endereco; default: .endereco }
    }

    private static func mascara(_ valor: String, padroes: [(Int, String)]) -> String {
        var saida = ""
        for (indice, digito) in valor.enumerated() {
            if let separador = padroes.first(where: { $0.0 == indice })?.1 { saida += separador }
            saida.append(digito)
        }
        return saida
    }

    public func mensagem(_ erro: ErroDeCadastroEstabelecimento) -> String {
        switch erro {
        case .documentoDuplicado: TextosCadastro.documentoDuplicado
        case .falha: TextosCadastro.falha
        case .campo: TextosCadastro.confiraCampo
        case .semRede: MensagemDoErroAPI.texto(ErroDaApi(codigo: .semRede))
        }
    }
}

public enum CampoCadastro: Equatable { case nome, documento, tipo, endereco, regiaoAdministrativa }
public enum ErroDeCadastroEstabelecimento: Equatable {
    case documentoDuplicado, campo(CampoCadastro, RegraCampoCadastro), falha, semRede
}
public enum RegraCampoCadastro: Equatable { case obrigatorio, invalido }

private enum IDScroll: Hashable {
    case avisoGlobal
    case nome
    case documento
    case tipo
    case endereco
    case regiaoAdministrativa
    case responsavel
}

/// Cadastro do estabelecimento no primeiro acesso do contratante, no quadro "Estabelecimento" do MidFi do Fabrício:
/// campos contornados, mapa com raio e o responsável da conta em cartão.
public struct TelaCadastroEstabelecimento: View {
    @State private var mostrarConfirmacaoDeSaida = false
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @State private var model: CadastroEstabelecimentoViewModel
    @State private var posicaoMapa: MapCameraPosition = .automatic
    @State private var posicaoMarcador: CGPoint?
    @State private var tentativaDeEnvio = 0
    #if DEBUG
    @State private var regiaoMapa: MKCoordinateRegion?
    #endif
    private let api: any ApiCliente
    private let responsavelNome: String
    private let responsavelTelefone: String
    private let fila: (any FilaDeAcoes)?
    private let sair: () -> Void
    private let excluirConta: (() -> Void)?
    private let aoPublicarPrimeiraVaga: () -> Void

    public init(api: any ApiCliente, fila: (any FilaDeAcoes)? = nil, responsavelNome: String, responsavelTelefone: String, sair: @escaping () -> Void = {}, excluirConta: (() -> Void)? = nil, aoPublicarPrimeiraVaga: @escaping () -> Void = {}) {
        let model = CadastroEstabelecimentoViewModel(api: api)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-FRILA_CADASTRO_UI_TEST") {
            model.nome = "Café de teste"
            model.atualizarDocumento("12345678901")
            model.endereco = "Brasília, DF"
            model.regiaoAdministrativa = "Plano Piloto"
            model.ponto = CLLocationCoordinate2D(latitude: -15.78, longitude: -47.93)
        }
        #endif
        _model = State(initialValue: model)
        self.api = api
        self.responsavelNome = responsavelNome
        self.responsavelTelefone = responsavelTelefone
        self.fila = fila
        self.sair = sair
        self.excluirConta = excluirConta
        self.aoPublicarPrimeiraVaga = aoPublicarPrimeiraVaga
    }

    public var body: some View {
        conteudoDaTela
            .sheet(isPresented: $mostrarConfirmacaoDeSaida) { confirmacaoDeSaida }
    }

    @ViewBuilder
    private var conteudoDaTela: some View {
        if model.concluido, let estabelecimento = model.estabelecimentoCriado {
            if let fila {
                // Primeiro acesso: o Estúdio de Criação sem o X (não há para onde voltar) e com o perfil da casa na barra.
                TelaEstudioDeVaga(api: api, fila: fila, estabelecimento: estabelecimento, sair: sair, aoPublicar: aoPublicarPrimeiraVaga)
            } else {
                Color.clear.task { aoPublicarPrimeiraVaga() }
            }
        } else {
            NavigationStack {
                formulario
                    .toolbar {
                        if let excluirConta {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(role: .destructive, action: excluirConta) {
                                    Text("Excluir conta", bundle: bundleApresentacao)
                                }
                                .accessibilityIdentifier("contratante-sem-estabelecimento-excluir-conta")
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { mostrarConfirmacaoDeSaida = true } label: {
                                Text("Sair", bundle: bundleApresentacao)
                            }
                            .accessibilityIdentifier("sair-fluxo-contratante")
                        }
                    }
            }
        }
    }

    private var formulario: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                    cabecalho
                    bannerDeErroGlobal
                    secaoNome
                        .id(IDScroll.nome)
                    secaoTipo
                        .id(IDScroll.tipo)
                    secaoDocumento
                        .id(IDScroll.documento)
                    secaoEndereco
                        .id(IDScroll.endereco)
                    secaoRegiaoAdministrativa
                        .id(IDScroll.regiaoAdministrativa)
                    secaoDoMapa
                    secaoResponsavel
                        .id(IDScroll.responsavel)
                }
                .padding(.horizontal, FrilaEspaco.medio)
                .padding(.top, FrilaEspaco.medio)
                .padding(.bottom, FrilaEspaco.enorme)
            }
            .background(FrilaCor.fundo.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .barraInferiorFixa {
                barraInferiorCta
            }
            .onChange(of: tentativaDeEnvio) { _, _ in
                rolarParaErro(proxy: proxy)
            }
            #if DEBUG
            .task {
                let args = ProcessInfo.processInfo.arguments
                let modoCaptura: String? = {
                    if let idx = args.firstIndex(of: "-FRILA_CAPTURA"), idx + 1 < args.count {
                        return args[idx + 1]
                    }
                    for arg in args where arg.hasPrefix("-FRILA_CAPTURA=") {
                        return String(arg.dropFirst("-FRILA_CAPTURA=".count))
                    }
                    return nil
                }()
                guard let modoCaptura else { return }
                if modoCaptura == "rodape" {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    proxy.scrollTo(IDScroll.responsavel, anchor: .bottom)
                } else if modoCaptura == "erro-nome" {
                    model.nome = ""
                    await model.salvar()
                    tentativaDeEnvio += 1
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    proxy.scrollTo(IDScroll.nome, anchor: .top)
                }
            }
            #endif
        }
    }

    private func rolarParaErro(proxy: ScrollViewProxy) {
        guard let erro = model.erro else { return }
        let id = idDoErro(erro)
        withAnimation(FrilaMovimento.animacao(.easeInOut(duration: 0.3), reduzir: reduzirMovimento)) {
            proxy.scrollTo(id, anchor: .top)
        }
    }

    private func idDoErro(_ erro: ErroDeCadastroEstabelecimento) -> IDScroll {
        switch erro {
        case .campo(let campo, _):
            switch campo {
            case .nome: return .nome
            case .documento: return .documento
            case .tipo: return .tipo
            case .endereco: return .endereco
            case .regiaoAdministrativa: return .regiaoAdministrativa
            }
        case .documentoDuplicado:
            return .documento
        case .falha, .semRede:
            return .avisoGlobal
        }
    }

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: TextosCadastro.titulo)
                .font(FrilaTipo.tituloGrande)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: TextosCadastro.subtitulo)
                .font(FrilaTipo.subtituloDaTela)
                .foregroundStyle(FrilaCor.textoSecundario)
        }
    }

    private var barraInferiorCta: some View {
        VStack(spacing: FrilaEspaco.pequeno) {
            BotaoPrimario(verbatim: TextosCadastro.salvarEPublicar, carregando: model.enviando) {
                Task {
                    await model.salvar()
                    tentativaDeEnvio += 1
                }
            }
            .accessibilityIdentifier("continuar-cadastro")

            if model.erro == .documentoDuplicado {
                Text(verbatim: TextosCadastro.ajudaSobCta)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, FrilaEspaco.medio)
        .padding(.vertical, FrilaEspaco.compacto)
    }

    @ViewBuilder
    private var secaoNome: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosCadastro.nomeCampo)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)

            TextField(
                text: $model.nome,
                prompt: Text(verbatim: TextosCadastro.nomeCampo).foregroundStyle(FrilaCor.textoSecundario)
            ) {
                Text(verbatim: TextosCadastro.nomeCampo)
            }
            .textFieldStyle(.plain)
            .font(FrilaTipo.corpo)
            .foregroundStyle(FrilaCor.texto)
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.vertical, FrilaEspaco.pequeno)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
            .overlay(bordaDoCampo(.nome))
            .accessibilityLabel(Text(verbatim: TextosCadastro.nomeCampo))

            mensagemDeErroAbaixo(do: .nome)
        }
    }

    @ViewBuilder
    private var secaoTipo: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosCadastro.tipoCampo)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)

            Menu {
                ForEach(TipoEstabelecimento.allCases, id: \.self) { tipo in
                    Button {
                        model.tipo = tipo
                    } label: {
                        if model.tipo == tipo {
                            Label(tipoNome(tipo), systemImage: "checkmark")
                        } else {
                            Text(verbatim: tipoNome(tipo))
                        }
                    }
                }
            } label: {
                HStack {
                    Text(verbatim: tipoNome(model.tipo))
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.texto)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
                .padding(.horizontal, FrilaEspaco.medio)
                .padding(.vertical, FrilaEspaco.pequeno)
                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo, alignment: .leading)
                .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
                .overlay(bordaDoCampo(.tipo))
            }
            .accessibilityLabel(Text(verbatim: TextosCadastro.tipo))
            .accessibilityValue(Text(verbatim: tipoNome(model.tipo)))
            .accessibilityIdentifier("tipo-estabelecimento")

            mensagemDeErroAbaixo(do: .tipo)
        }
    }

    @ViewBuilder
    private var secaoDocumento: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosCadastro.documentoCampo)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)

            CampoMascara(
                texto: $model.documentoFormatado,
                placeholder: TextosCadastro.soNumeros,
                rotuloAcessibilidade: TextosCadastro.documentoCampo,
                formatar: { texto, _ in CadastroEstabelecimentoViewModel.formatarDocumento(texto) }
            )
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.vertical, FrilaEspaco.pequeno)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo, alignment: .leading)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
            .overlay(bordaDoCampo(.documento))

            mensagemDeErroAbaixo(do: .documento)
        }
    }

    @ViewBuilder
    private var secaoEndereco: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosCadastro.endereco)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)

            HStack(spacing: FrilaEspaco.compacto) {
                Image(systemName: "mappin")
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityHidden(true)

                TextField(
                    text: $model.endereco,
                    prompt: Text(verbatim: TextosCadastro.endereco).foregroundStyle(FrilaCor.textoSecundario)
                ) {
                    Text(verbatim: TextosCadastro.endereco)
                }
                .textFieldStyle(.plain)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
                .submitLabel(.search)
                .onSubmit {
                    Task { await model.buscarEndereco() }
                }

                Button {
                    Task { await model.buscarEndereco() }
                } label: {
                    if model.carregandoBusca {
                        ProgressView()
                            .tint(FrilaCor.textoSecundario)
                            .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .accessibilityHidden(true)
                            .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                            .contentShape(Rectangle())
                    }
                }
                .foregroundStyle(FrilaCor.texto)
                .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                .accessibilityLabel(Text(verbatim: TextosCadastro.buscarEndereco))
                .accessibilityHint(Text(verbatim: TextosCadastro.buscarEnderecoAjuda))
                .accessibilityIdentifier("buscar-endereco-botao")
            }
            .padding(.leading, FrilaEspaco.medio)
            .padding(.trailing, FrilaEspaco.pequeno)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
            .overlay(bordaDoCampo(.endereco))

            mensagemDeErroAbaixo(do: .endereco)

            secaoSugestoes
        }
    }

    @ViewBuilder
    private var secaoSugestoes: some View {
        if !model.sugestoes.isEmpty {
            VStack(spacing: FrilaEspaco.pequeno) {
                ForEach(Array(model.sugestoes.enumerated()), id: \.offset) { _, item in
                    Button {
                        model.selecionar(item)
                    } label: {
                        Text(verbatim: item.placemark.title ?? item.name ?? "")
                            .font(FrilaTipo.corpo)
                            .foregroundStyle(FrilaCor.texto)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, FrilaEspaco.medio)
                            .padding(.vertical, FrilaEspaco.pequeno)
                            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo, alignment: .leading)
                            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous).strokeBorder(FrilaCor.borda, lineWidth: 1))
                            .contentShape(Rectangle())
                    }
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
                    .accessibilityHint(Text(verbatim: TextosCadastro.selecionarEnderecoAjuda))
                }
            }
        }
    }

    @ViewBuilder
    private var secaoRegiaoAdministrativa: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosCadastro.regiaoAdministrativa)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)

            Menu {
                Button {
                    model.regiaoAdministrativa = ""
                } label: {
                    if model.regiaoAdministrativa.isEmpty {
                        Label(TextosCadastro.selecionar, systemImage: "checkmark")
                    } else {
                        Text(verbatim: TextosCadastro.selecionar)
                    }
                }
                ForEach(CadastroEstabelecimentoViewModel.regioesAdministrativas, id: \.self) { regiao in
                    Button {
                        model.regiaoAdministrativa = regiao
                    } label: {
                        if model.regiaoAdministrativa == regiao {
                            Label(regiao, systemImage: "checkmark")
                        } else {
                            Text(verbatim: regiao)
                        }
                    }
                }
            } label: {
                HStack {
                    Text(verbatim: model.regiaoAdministrativa.isEmpty ? TextosCadastro.selecionar : model.regiaoAdministrativa)
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(model.regiaoAdministrativa.isEmpty ? FrilaCor.textoSecundario : FrilaCor.texto)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
                .padding(.horizontal, FrilaEspaco.medio)
                .padding(.vertical, FrilaEspaco.pequeno)
                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo, alignment: .leading)
                .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
                .overlay(bordaDoCampo(.regiaoAdministrativa))
            }
            .accessibilityLabel(Text(verbatim: TextosCadastro.regiaoAdministrativa))
            .accessibilityValue(Text(verbatim: model.regiaoAdministrativa.isEmpty ? TextosCadastro.selecionar : model.regiaoAdministrativa))
            .accessibilityHint(Text(verbatim: TextosCadastro.regiaoAdministrativaAjuda))
            .accessibilityIdentifier("regiao-administrativa")

            mensagemDeErroAbaixo(do: .regiaoAdministrativa)
        }
    }

    @ViewBuilder
    private var secaoDoMapa: some View {
        if let ponto = model.ponto {
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                MapReader { proxy in
                    Map(position: $posicaoMapa) {}
                        .accessibilityIdentifier("mapa-estabelecimento")
                        .accessibilityLabel(Text(verbatim: TextosCadastro.mapa))
                        #if DEBUG
                        .accessibilityValue(Text(verbatim: regiaoMapa.map {
                            String(format: "%.6f,%.6f,%.6f,%.6f", locale: Locale(identifier: "en_US_POSIX"), $0.center.latitude, $0.center.longitude, $0.span.latitudeDelta, $0.span.longitudeDelta)
                        } ?? ""))
                        #endif
                        .onMapCameraChange(frequency: .continuous) { contexto in
                            posicaoMarcador = proxy.convert(ponto, to: .named("mapa"))
                            #if DEBUG
                            regiaoMapa = contexto.region
                            #endif
                        }
                        .overlay(alignment: .topLeading) {
                            GeometryReader { geometria in
                                if let posicaoMarcador,
                                   CGRect(origin: .zero, size: geometria.size).contains(posicaoMarcador) {
                                    marcadorMapa(proxy: proxy, ponto: ponto, posicao: posicaoMarcador)
                                }
                            }
                        }
                        .clipped()
                        .contentShape(Rectangle())
                        .coordinateSpace(.named("mapa"))
                        .onChange(of: model.ponto?.latitude) { _, _ in
                            posicaoMarcador = proxy.convert(ponto, to: .named("mapa"))
                        }
                        .onChange(of: model.ponto?.longitude) { _, _ in
                            posicaoMarcador = proxy.convert(ponto, to: .named("mapa"))
                        }
                        .onAppear { centralizarMapa(em: ponto) }
                        .onChange(of: model.alvoDaCamera?.latitude) { _, _ in
                            if let alvo = model.alvoDaCamera { centralizarMapa(em: alvo) }
                        }
                        .onChange(of: model.alvoDaCamera?.longitude) { _, _ in
                            if let alvo = model.alvoDaCamera { centralizarMapa(em: alvo) }
                        }
                }
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous).strokeBorder(FrilaCor.borda, lineWidth: 1))

                Text(verbatim: TextosCadastro.dicaMapa)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
        } else {
            VStack(spacing: FrilaEspaco.pequeno) {
                Image(systemName: "map")
                    .font(.title2)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityHidden(true)
                Text(verbatim: TextosCadastro.pontoNaoMarcado)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(FrilaCor.controle, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous).strokeBorder(FrilaCor.borda, lineWidth: 1))
            .accessibilityIdentifier("mapa-estabelecimento")
            .accessibilityLabel(Text(verbatim: TextosCadastro.pontoNaoMarcado))
        }
    }

    @ViewBuilder
    private func marcadorMapa(proxy: MapProxy, ponto: CLLocationCoordinate2D, posicao: CGPoint) -> some View {
        Image(systemName: "mappin.circle.fill")
            .font(.title)
            .foregroundStyle(FrilaCor.texto, FrilaCor.superficie)
            .frame(width: FrilaMetrica.alvoMinimo, height: FrilaMetrica.alvoMinimo)
            .contentShape(Rectangle())
            .accessibilityLabel(Text(verbatim: TextosCadastro.ponto))
            .accessibilityIdentifier("marcador-mapa")
            .accessibilityHint(Text(verbatim: TextosCadastro.dicaMarcador))
            .accessibilityAddTraits(.allowsDirectInteraction)
            .accessibilityValue(Text(verbatim: String(format: "%.6f,%.6f", locale: Locale(identifier: "en_US_POSIX"), ponto.latitude, ponto.longitude)))
            .position(x: posicao.x, y: posicao.y - 15)
            .highPriorityGesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .named("mapa"))
                    .onChanged { valor in
                        if let coordenada = proxy.convert(valor.location, from: .named("mapa")) {
                            model.ponto = coordenada
                            self.posicaoMarcador = valor.location
                        }
                    }
                    .onEnded { valor in
                        if let coordenada = proxy.convert(valor.location, from: .named("mapa")) {
                            model.ponto = coordenada
                            self.posicaoMarcador = valor.location
                        }
                    }
            )
    }

    @ViewBuilder
    private var secaoResponsavel: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosCadastro.responsavel)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)

            HStack {
                Text(verbatim: responsavelNome)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                Spacer()
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo, alignment: .leading)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous).strokeBorder(FrilaCor.borda, lineWidth: 1))

            Text(verbatim: formatarTelefoneResponsavel(responsavelTelefone))
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("responsavel-conta")
    }

    private func formatarTelefoneResponsavel(_ texto: String) -> String {
        let digitos = Array(texto.filter(\.isNumber))
        var corpo = digitos
        if (corpo.count == 12 || corpo.count == 13), corpo.prefix(2) == ["5", "5"] {
            corpo = Array(corpo.dropFirst(2))
        }
        if corpo.count == 11 {
            let ddd = String(corpo[0..<2])
            let parte1 = String(corpo[2..<7])
            let parte2 = String(corpo[7..<11])
            return "(\(ddd)) \(parte1)-\(parte2)"
        }
        if corpo.count == 10 {
            let ddd = String(corpo[0..<2])
            let parte1 = String(corpo[2..<6])
            let parte2 = String(corpo[6..<10])
            return "(\(ddd)) \(parte1)-\(parte2)"
        }
        return texto
    }

    @ViewBuilder
    private var bannerDeErroGlobal: some View {
        if let erro = model.erro, erro == .falha || erro == .semRede {
            HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.pequeno) {
                Image(systemName: erro == .semRede ? "wifi.slash" : "exclamationmark.triangle")
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityHidden(true)
                Text(verbatim: mensagem(erro))
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.texto)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FrilaEspaco.medio)
            .background(FrilaCor.controle, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("erro-cadastro")
            .id(IDScroll.avisoGlobal)
        }
    }

    private func temErroNoCampo(_ campo: CampoCadastro) -> Bool {
        if case let .campo(campoErro, _)? = model.erro, campoErro == campo {
            return true
        }
        if campo == .documento, model.erro == .documentoDuplicado {
            return true
        }
        return false
    }

    private func bordaDoCampo(_ campo: CampoCadastro) -> some View {
        let temErro = temErroNoCampo(campo)
        return RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
            .strokeBorder(temErro ? FrilaCor.texto : FrilaCor.borda, lineWidth: temErro ? 2 : 1)
    }

    @ViewBuilder
    private func mensagemDeErroAbaixo(do campo: CampoCadastro) -> some View {
        if campo == .documento, model.erro == .documentoDuplicado {
            HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.pequeno) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityHidden(true)
                Text(verbatim: TextosCadastro.documentoDuplicadoMensagem)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.texto)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("erro-campo-documento")
        } else if case let .campo(campoErro, regra)? = model.erro, campoErro == campo {
            HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.pequeno) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityHidden(true)
                Text(verbatim: erroCampo(regra))
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.texto)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(identificadorDeErro(campo))
        }
    }

    private func identificadorDeErro(_ campo: CampoCadastro) -> String {
        switch campo {
        case .nome: "erro-campo-nome"
        case .documento: "erro-campo-documento"
        case .tipo: "erro-campo-tipo"
        case .endereco: "erro-campo-endereco"
        case .regiaoAdministrativa: "erro-campo-regiao-administrativa"
        }
    }

    private func mensagem(_ erro: ErroDeCadastroEstabelecimento) -> String {
        model.mensagem(erro)
    }

    private func erroCampo(_ regra: RegraCampoCadastro) -> String {
        regra == .obrigatorio ? TextosCadastro.campoObrigatorio : TextosCadastro.campoInvalido
    }

    private func tipoNome(_ tipo: TipoEstabelecimento) -> String {
        switch tipo {
        case .foodService: TextosCadastro.alimentacao
        case .evento: TextosCadastro.evento
        case .varejo: TextosCadastro.varejo
        case .logistica: TextosCadastro.logistica
        case .servicoDomestico: TextosCadastro.servicoDomestico
        case .outro: TextosCadastro.outro
        }
    }

    private func centralizarMapa(em coordenada: CLLocationCoordinate2D) {
        posicaoMapa = .region(MKCoordinateRegion(center: coordenada, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
    }

    /// Mesmo padrão da exclusão de conta: título rolável e ações fixas, Cancelar primeiro.
    private var confirmacaoDeSaida: some View {
        ScrollView {
            Text("Sair da conta?", bundle: bundleApresentacao)
                .font(FrilaTipo.tituloDeEstado)
                .foregroundStyle(FrilaCor.texto)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(FrilaEspaco.medio)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: FrilaEspaco.pequeno) {
                BotaoSecundario(verbatim: String(localized: "Cancelar", bundle: bundleApresentacao)) {
                    mostrarConfirmacaoDeSaida = false
                }
                .accessibilityIdentifier("botao-cancelar-saida-dialogo")
                Button(role: .destructive) {
                    mostrarConfirmacaoDeSaida = false
                    sair()
                } label: {
                    Text("Sair", bundle: bundleApresentacao)
                        .font(FrilaTipo.botao)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, FrilaEspaco.pequeno)
                        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(FrilaCor.sobrePrimaria)
                .background(FrilaCor.perigo, in: Capsule())
                .accessibilityIdentifier("botao-confirmar-saida-dialogo")
            }
            .padding(FrilaEspaco.medio)
            .background(FrilaCor.fundo)
        }
        .background(FrilaCor.fundo)
        .presentationDetents([.large])
        .presentationCornerRadius(FrilaRaio.folha)
        .presentationDragIndicator(.visible)
    }
}

private extension View {
    @ViewBuilder
    func barraInferiorFixa<Content: View>(@ViewBuilder conteudo: () -> Content) -> some View {
        if #available(iOS 26, *) {
            safeAreaBar(edge: .bottom) {
                conteudo()
            }
        } else {
            safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(FrilaCor.divisoria)
                        .frame(height: 1)
                        .accessibilityHidden(true)

                    conteudo()
                }
                .background(.regularMaterial)
            }
        }
    }
}
