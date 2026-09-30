import FrilaDominio
import MapKit
import Observation
import SwiftUI

private final class MarcadorCadastroEstabelecimento: NSObject {}
private let bundleCadastro = Bundle(for: MarcadorCadastroEstabelecimento.self)

private enum TextosCadastro {
    static let titulo = String(localized: "Cadastrar estabelecimento", bundle: bundleCadastro)
    static let nome = String(localized: "Nome", bundle: bundleCadastro)
    static let nomeCampo = String(localized: "Nome do estabelecimento", bundle: bundleCadastro)
    static let documento = String(localized: "Documento", bundle: bundleCadastro)
    static let documentoCampo = String(localized: "CPF ou CNPJ", bundle: bundleCadastro)
    static let tipo = String(localized: "Tipo", bundle: bundleCadastro)
    static let endereco = String(localized: "Endereço", bundle: bundleCadastro)
    static let buscarEndereco = String(localized: "Buscar endereço", bundle: bundleCadastro)
    static let ponto = String(localized: "Ponto do estabelecimento", bundle: bundleCadastro)
    static let mapa = String(localized: "Mapa do estabelecimento", bundle: bundleCadastro)
    static let dicaMapa = String(localized: "Ajuste o ponto movendo o marcador no mapa.", bundle: bundleCadastro)
    static let responsavel = String(localized: "Responsável", bundle: bundleCadastro)
    static let continuar = String(localized: "Continuar", bundle: bundleCadastro)
    static let estabelecimento = String(localized: "Estabelecimento", bundle: bundleCadastro)
    static let publicarVaga = String(localized: "Publicar vaga", bundle: bundleCadastro)
    static let documentoDuplicado = String(localized: "Este documento já está cadastrado.", bundle: bundleCadastro)
    static let falha = String(localized: "Não foi possível cadastrar o estabelecimento. Tente novamente.", bundle: bundleCadastro)
    static let confiraCampo = String(localized: "Confira o campo indicado.", bundle: bundleCadastro)
    static let campoObrigatorio = String(localized: "Preencha este campo.", bundle: bundleCadastro)
    static let campoInvalido = String(localized: "Confira o valor informado.", bundle: bundleCadastro)
    static let alimentacao = String(localized: "Alimentação", bundle: bundleCadastro)
    static let evento = String(localized: "Evento", bundle: bundleCadastro)
    static let varejo = String(localized: "Varejo", bundle: bundleCadastro)
    static let logistica = String(localized: "Logística", bundle: bundleCadastro)
    static let servicoDomestico = String(localized: "Serviço doméstico", bundle: bundleCadastro)
    static let outro = String(localized: "Outro", bundle: bundleCadastro)
}

@MainActor @Observable
public final class CadastroEstabelecimentoViewModel {
    public var nome = ""
    public var documento = ""
    public var tipo: TipoEstabelecimento = .foodService
    public var endereco = ""
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
        let digitos = String(documento.filter(\.isNumber).prefix(14))
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

    public func selecionar(_ item: MKMapItem) {
        endereco = item.name.map { "\($0), \(item.placemark.title ?? "")" } ?? (item.placemark.title ?? endereco)
        ponto = item.placemark.coordinate
        alvoDaCamera = item.placemark.coordinate
        sugestoes = []
    }

    public func salvar() async {
        guard !enviando else { return }
        erro = nil
        guard !nome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { erro = .campo(.nome, .obrigatorio); return }
        guard documento.count == 11 || documento.count == 14 else { erro = .campo(.documento, .invalido); return }
        guard !endereco.isEmpty, let ponto else { erro = .campo(.endereco, .obrigatorio); return }
        guard let coordenada = try? Coordenada(latitude: ponto.latitude, longitude: ponto.longitude) else { erro = .campo(.endereco, .invalido); return }
        enviando = true
        defer { enviando = false }
        do {
            estabelecimentoCriado = try await cadastrar(CadastroEstabelecimento(nome: nome.trimmingCharacters(in: .whitespacesAndNewlines), documento: documento, tipo: tipo, endereco: endereco, ponto: coordenada))
            concluido = true
        } catch let api as ErroDaApi {
            switch api.codigo {
            case .documentoJaCadastrado: erro = .documentoDuplicado
            case .campoObrigatorio: erro = .campo(Self.campo(api.detalhes), .obrigatorio)
            case .campoInvalido: erro = .campo(Self.campo(api.detalhes), .invalido)
            default: erro = .falha
            }
        } catch { erro = .falha }
    }

    private static func campo(_ detalhes: String?) -> CampoCadastro {
        switch detalhes { case "nome": .nome; case "documento": .documento; case "tipo": .tipo; case "endereco", "ponto", "latitude", "longitude": .endereco; default: .endereco }
    }

    private static func mascara(_ valor: String, padroes: [(Int, String)]) -> String {
        var saida = ""
        for (indice, digito) in valor.enumerated() {
            if let separador = padroes.first(where: { $0.0 == indice })?.1 { saida += separador }
            saida.append(digito)
        }
        return saida
    }
}

public enum CampoCadastro: Equatable { case nome, documento, tipo, endereco }
public enum ErroDeCadastroEstabelecimento: Equatable {
    case documentoDuplicado, campo(CampoCadastro, RegraCampoCadastro), falha
}
public enum RegraCampoCadastro: Equatable { case obrigatorio, invalido }

public struct TelaCadastroEstabelecimento: View {
    @State private var model: CadastroEstabelecimentoViewModel
    @State private var posicaoMapa: MapCameraPosition = .automatic
    private let api: any ApiCliente
    private let responsavelNome: String
    private let responsavelTelefone: String
    private let fila: any FilaDeAcoes

    public init(api: any ApiCliente, fila: any FilaDeAcoes, responsavelNome: String, responsavelTelefone: String) {
        let model = CadastroEstabelecimentoViewModel(api: api)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-FRILA_CADASTRO_UI_TEST") {
            model.nome = "Café de teste"
            model.atualizarDocumento("12345678901")
            model.endereco = "Brasília, DF"
            model.ponto = CLLocationCoordinate2D(latitude: -15.78, longitude: -47.93)
        }
        #endif
        _model = State(initialValue: model)
        self.api = api
        self.responsavelNome = responsavelNome
        self.responsavelTelefone = responsavelTelefone
        self.fila = fila
    }

    public var body: some View {
        if model.concluido, let estabelecimento = model.estabelecimentoCriado {
            TelaPublicarVaga(api: api, fila: fila, estabelecimento: estabelecimento, telefoneResponsavel: responsavelTelefone)
        } else {
            NavigationStack { formulario }
        }
    }

    private var formulario: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(verbatim: TextosCadastro.titulo).font(.largeTitle.bold())
                campo(TextosCadastro.nome, campo: .nome) { CampoFrila(verbatim: TextosCadastro.nomeCampo, texto: $model.nome) }
                campo(TextosCadastro.documento, campo: .documento) {
                    TextField(text: Binding(get: { model.documentoFormatado }, set: { valor in model.atualizarDocumento(valor) }), prompt: Text(verbatim: TextosCadastro.documentoCampo)) { Text(verbatim: TextosCadastro.documentoCampo) }
                        .keyboardType(.numberPad).textFieldStyle(.roundedBorder).accessibilityLabel(Text(verbatim: TextosCadastro.documentoCampo))
                }
                Picker(selection: $model.tipo) {
                    ForEach(TipoEstabelecimento.allCases, id: \.self) { Text(verbatim: tipoNome($0)).tag($0) }
                } label: { Text(verbatim: TextosCadastro.tipo)
                }
                .accessibilityIdentifier("tipo-estabelecimento")
                campo(TextosCadastro.endereco, campo: .endereco) {
                    HStack { CampoFrila(verbatim: TextosCadastro.endereco, texto: $model.endereco); Button { Task { await model.buscarEndereco() } } label: { Image(systemName: "magnifyingglass") }.accessibilityLabel(Text(verbatim: TextosCadastro.buscarEndereco)) }
                }
                ForEach(Array(model.sugestoes.enumerated()), id: \.offset) { _, item in
                    Button { model.selecionar(item) } label: { Text(verbatim: item.placemark.title ?? item.name ?? "") }
                }
                if let point = model.ponto {
                    MapReader { proxy in
                        Map(position: $posicaoMapa) {
                            Annotation("", coordinate: point, anchor: .bottom) {
                                Image(systemName: "mappin.and.ellipse").font(.title).foregroundStyle(.red)
                                    .accessibilityLabel(Text(verbatim: TextosCadastro.ponto))
                                    .highPriorityGesture(DragGesture(coordinateSpace: .named("mapa")).onEnded { valor in
                                        if let novaCoordenada = proxy.convert(valor.location, from: .named("mapa")) { model.ponto = novaCoordenada }
                                    })
                            }
                        }
                        .coordinateSpace(.named("mapa"))
                        .onAppear { centralizarMapa(em: point) }
                        .onChange(of: model.alvoDaCamera?.latitude) { _, _ in
                            if let alvo = model.alvoDaCamera { centralizarMapa(em: alvo) }
                        }
                        .onChange(of: model.alvoDaCamera?.longitude) { _, _ in
                            if let alvo = model.alvoDaCamera { centralizarMapa(em: alvo) }
                        }
                    }
                    .frame(height: 220).accessibilityLabel(Text(verbatim: TextosCadastro.mapa))
                    Text(verbatim: TextosCadastro.dicaMapa).font(.caption)
                }
                VStack(alignment: .leading) {
                    Text(verbatim: TextosCadastro.responsavel).font(.headline)
                    Text(verbatim: responsavelNome); Text(verbatim: responsavelTelefone).foregroundStyle(.secondary)
                }.accessibilityIdentifier("responsavel-conta")
                if let erro = model.erro { AvisoFrila(verbatim: mensagem(erro), tom: .erro).accessibilityIdentifier("erro-cadastro") }
                BotaoPrimario(verbatim: TextosCadastro.continuar, carregando: model.enviando) { Task { await model.salvar() } }
                    .accessibilityIdentifier("continuar-cadastro")
            }.padding()
        }
        .navigationTitle(Text(verbatim: TextosCadastro.estabelecimento))
    }

    @ViewBuilder private func campo<Conteudo: View>(_ titulo: String, campo: CampoCadastro, @ViewBuilder conteudo: () -> Conteudo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: titulo).font(.headline)
            conteudo()
            if case let .campo(campoErro, regra)? = model.erro, campoErro == campo { Text(erroCampo(regra)).font(.caption).foregroundStyle(.red).accessibilityIdentifier("erro-campo-\(titulo.lowercased())") }
        }
    }

    private func mensagem(_ erro: ErroDeCadastroEstabelecimento) -> String {
        switch erro { case .documentoDuplicado: TextosCadastro.documentoDuplicado; case .falha: TextosCadastro.falha; case .campo: TextosCadastro.confiraCampo }
    }
    private func erroCampo(_ regra: RegraCampoCadastro) -> String { regra == .obrigatorio ? TextosCadastro.campoObrigatorio : TextosCadastro.campoInvalido }
    private func tipoNome(_ tipo: TipoEstabelecimento) -> String {
        switch tipo { case .foodService: TextosCadastro.alimentacao; case .evento: TextosCadastro.evento; case .varejo: TextosCadastro.varejo; case .logistica: TextosCadastro.logistica; case .servicoDomestico: TextosCadastro.servicoDomestico; case .outro: TextosCadastro.outro }
    }

    private func centralizarMapa(em coordenada: CLLocationCoordinate2D) {
        posicaoMapa = .region(MKCoordinateRegion(center: coordenada, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
    }
}
