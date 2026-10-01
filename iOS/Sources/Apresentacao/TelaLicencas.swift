import SwiftUI

/// Licença de um pacote do build, como sai de `Scripts/gerar-licencas.py`.
public struct LicencaDePacote: Decodable, Identifiable, Equatable, Sendable {
    /// Identidade do pacote no Package.resolved.
    public let id: String
    public let nome: String
    public let versao: String
    public let revisao: String
    public let url: URL
    /// Identificador SPDX, como `Apache-2.0`.
    public let tipo: String
    public let texto: String
    /// Conteúdo do arquivo NOTICE do pacote, quando ele traz um.
    public let aviso: String?
}

public enum Licencas {
    public enum Erro: Error { case recursoAusente }

    /// Lê `Licencas.json` do bundle do FrilaApresentacao. O arquivo é gerado: não se edita à mão.
    public static func carregar() throws -> [LicencaDePacote] {
        guard let url = bundleApresentacao.url(forResource: "Licencas", withExtension: "json") else {
            throw Erro.recursoAusente
        }
        return try JSONDecoder().decode([LicencaDePacote].self, from: Data(contentsOf: url))
    }
}

/// Textos provisórios, como a interface desta tela (#178).
enum TextosDeLicencas {
    static let titulo = String(localized: "Licenças de código aberto", bundle: bundleApresentacao)
    static let versao = String(localized: "Versão", bundle: bundleApresentacao)
    static let licenca = String(localized: "Licença", bundle: bundleApresentacao)
    static let repositorio = String(localized: "Repositório", bundle: bundleApresentacao)
    static let aviso = String(localized: "Avisos do pacote", bundle: bundleApresentacao)
    static let falha = String(localized: "Não foi possível carregar as licenças.", bundle: bundleApresentacao)
    static let dicaAbrir = String(localized: "Abre o texto da licença", bundle: bundleApresentacao)
}

/// Lista das dependências do build com a licença de cada uma. Interface provisória: precisa estar
/// dentro de um `NavigationStack`, que é quem abre o detalhe.
public struct TelaLicencas: View {
    private enum Estado {
        case carregando
        case carregada([LicencaDePacote])
        case falha
    }

    @State private var estado = Estado.carregando

    public init() {}

    public var body: some View {
        Group {
            switch estado {
            case .carregando:
                EstadoCarregando()
            case let .carregada(licencas):
                List(licencas) { licenca in
                    NavigationLink { TelaDetalheDaLicenca(licenca) } label: { linha(licenca) }
                        .listRowBackground(FrilaCor.superficie)
                        .accessibilityIdentifier("licenca-\(licenca.id)")
                        .accessibilityHint(TextosDeLicencas.dicaAbrir)
                }
                .scrollContentBackground(.hidden)
            case .falha:
                AvisoFrila(verbatim: TextosDeLicencas.falha, tom: .erro)
                    .padding(FrilaEspaco.medio)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .accessibilityIdentifier("licencas-erro")
            }
        }
        .background(FrilaCor.fundo)
        .navigationTitle(TextosDeLicencas.titulo)
        .navigationBarTitleDisplayMode(.inline)
        // O JSON é lido uma vez, quando a tela aparece: o destino de um NavigationLink é criado
        // junto com a tela de origem, e ler no init repetiria a leitura a cada redesenho dela.
        .task {
            guard case .carregando = estado else { return }
            estado = (try? Licencas.carregar()).map(Estado.carregada) ?? .falha
        }
    }

    private func linha(_ licenca: LicencaDePacote) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: licenca.nome).font(.headline).foregroundStyle(FrilaCor.texto)
            Text(verbatim: "\(licenca.versao) · \(licenca.tipo)").font(.subheadline).foregroundStyle(FrilaCor.textoSecundario)
        }
        .frame(minHeight: FrilaMetrica.alvoMinimo)
    }
}

struct TelaDetalheDaLicenca: View {
    private let licenca: LicencaDePacote

    init(_ licenca: LicencaDePacote) { self.licenca = licenca }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    campo(TextosDeLicencas.versao, licenca.versao)
                    campo(TextosDeLicencas.licenca, licenca.tipo)
                    Link(destination: licenca.url) {
                        campo(TextosDeLicencas.repositorio, licenca.url.absoluteString, cor: FrilaCor.primaria)
                            .frame(minHeight: FrilaMetrica.alvoMinimo)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("repositorio-da-licenca")
                }
                .cartaoFrila()

                texto(licenca.texto).accessibilityIdentifier("texto-da-licenca")

                if let aviso = licenca.aviso {
                    Text(verbatim: TextosDeLicencas.aviso).font(.headline).foregroundStyle(FrilaCor.texto)
                        .accessibilityAddTraits(.isHeader)
                    texto(aviso).accessibilityIdentifier("aviso-da-licenca")
                }
            }
            .padding(FrilaEspaco.medio)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(licenca.nome)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func campo(_ titulo: String, _ valor: String, cor: Color = FrilaCor.texto) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: titulo).font(.caption).foregroundStyle(FrilaCor.textoSecundario)
            Text(verbatim: valor).font(.body).foregroundStyle(cor).multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // O texto da licença entra como veio do pacote, com as quebras de linha originais.
    private func texto(_ conteudo: String) -> some View {
        Text(verbatim: conteudo).font(.footnote).foregroundStyle(FrilaCor.texto)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }
}

#Preview("Lista") { NavigationStack { TelaLicencas() } }
