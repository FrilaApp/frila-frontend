import FrilaDominio
import MapKit
import Observation
import SwiftUI

private final class MarcadorCadastroEstabelecimento: NSObject {}
private let bundleCadastro = Bundle(for: MarcadorCadastroEstabelecimento.self)

@MainActor @Observable
public final class CadastroEstabelecimentoViewModel {
    public var nome = ""
    public var documento = ""
    public var tipo: TipoEstabelecimento = .foodService
    public var endereco = ""
    public var ponto: CLLocationCoordinate2D?
    public var sugestoes: [MKMapItem] = []
    public var carregandoBusca = false
    public private(set) var enviando = false
    public private(set) var erro: ErroDeCadastroEstabelecimento?
    public private(set) var concluido = false
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
            _ = try await cadastrar(CadastroEstabelecimento(nome: nome.trimmingCharacters(in: .whitespacesAndNewlines), documento: documento, tipo: tipo, endereco: endereco, ponto: coordenada))
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
    private let responsavelNome: String
    private let responsavelTelefone: String

    public init(api: any ApiCliente, responsavelNome: String, responsavelTelefone: String) {
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
        self.responsavelNome = responsavelNome
        self.responsavelTelefone = responsavelTelefone
    }

    public var body: some View {
        NavigationStack {
            if model.concluido { publicarVaga }
            else { formulario }
        }
    }

    private var formulario: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(verbatim: t("Cadastrar estabelecimento")).font(.largeTitle.bold())
                campo("Nome", campo: .nome) { CampoFrila(t("Nome do estabelecimento"), texto: $model.nome) }
                campo("Documento", campo: .documento) {
                    TextField(text: Binding(get: { model.documentoFormatado }, set: { valor in model.atualizarDocumento(valor) }), prompt: Text(verbatim: t("CPF ou CNPJ"))) { Text(verbatim: t("CPF ou CNPJ")) }
                        .keyboardType(.numberPad).textFieldStyle(.roundedBorder).accessibilityLabel(Text(verbatim: t("CPF ou CNPJ")))
                }
                Picker(selection: $model.tipo) {
                    ForEach(TipoEstabelecimento.allCases, id: \.self) { Text(verbatim: tipoNome($0)).tag($0) }
                } label: { Text(verbatim: t("Tipo"))
                }
                .accessibilityIdentifier("tipo-estabelecimento")
                campo("Endereço", campo: .endereco) {
                    HStack { CampoFrila(t("Endereço"), texto: $model.endereco); Button { Task { await model.buscarEndereco() } } label: { Image(systemName: "magnifyingglass") }.accessibilityLabel(Text(verbatim: t("Buscar endereço"))) }
                }
                ForEach(Array(model.sugestoes.enumerated()), id: \.offset) { _, item in
                    Button { model.selecionar(item) } label: { Text(verbatim: item.placemark.title ?? item.name ?? "") }
                }
                if let point = model.ponto {
                    MapReader { proxy in
                        Map(initialPosition: .region(MKCoordinateRegion(center: point, span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01))))
                            .overlay {
                                Image(systemName: "mappin.and.ellipse").font(.title).foregroundStyle(.red)
                                    .accessibilityLabel(Text(verbatim: t("Ponto do estabelecimento")))
                                    .highPriorityGesture(DragGesture(minimumDistance: 0).onEnded { toque in
                                        if let novaCoordenada = proxy.convert(toque.location, from: .local) { model.ponto = novaCoordenada }
                                    })
                            }
                    }
                    .frame(height: 220).accessibilityLabel(Text(verbatim: t("Mapa do estabelecimento")))
                    Text(verbatim: t("Ajuste o ponto movendo o marcador no mapa.")).font(.caption)
                }
                VStack(alignment: .leading) {
                    Text(verbatim: t("Responsável")).font(.headline)
                    Text(verbatim: responsavelNome); Text(verbatim: responsavelTelefone).foregroundStyle(.secondary)
                }.accessibilityIdentifier("responsavel-conta")
                if let erro = model.erro { AvisoFrila(verbatim: mensagem(erro), tom: .erro).accessibilityIdentifier("erro-cadastro") }
                BotaoPrimario(t("Continuar"), carregando: model.enviando) { Task { await model.salvar() } }
                    .accessibilityIdentifier("continuar-cadastro")
            }.padding()
        }
        .navigationTitle(Text(verbatim: t("Estabelecimento")))
    }

    private var publicarVaga: some View {
        VStack(spacing: 16) {
            Text(verbatim: t("Publicar vaga")).font(.largeTitle.bold())
            Text(verbatim: t("Esta etapa estará disponível em breve.")).foregroundStyle(.secondary)
        }.accessibilityIdentifier("publicar-vaga-provisorio")
    }

    @ViewBuilder private func campo<Conteudo: View>(_ titulo: String, campo: CampoCadastro, @ViewBuilder conteudo: () -> Conteudo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: t(titulo)).font(.headline)
            conteudo()
            if case let .campo(campoErro, regra)? = model.erro, campoErro == campo { Text(erroCampo(regra)).font(.caption).foregroundStyle(.red).accessibilityIdentifier("erro-campo-\(titulo.lowercased())") }
        }
    }

    private func mensagem(_ erro: ErroDeCadastroEstabelecimento) -> String {
        switch erro { case .documentoDuplicado: t("Este documento já está cadastrado."); case .falha: t("Não foi possível cadastrar o estabelecimento. Tente novamente."); case .campo: t("Confira o campo indicado.") }
    }
    private func erroCampo(_ regra: RegraCampoCadastro) -> String { regra == .obrigatorio ? t("Preencha este campo.") : t("Confira o valor informado.") }
    private func tipoNome(_ tipo: TipoEstabelecimento) -> String {
        switch tipo { case .foodService: t("Alimentação"); case .evento: t("Evento"); case .varejo: t("Varejo"); case .logistica: t("Logística"); case .servicoDomestico: t("Serviço doméstico"); case .outro: t("Outro") }
    }
    private func t(_ value: String) -> String { String(localized: String.LocalizationValue(value), bundle: bundleCadastro) }
}
