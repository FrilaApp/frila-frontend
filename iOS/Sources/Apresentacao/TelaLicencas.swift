import SwiftUI

/// Licença de um pacote ou fonte embutida do build, como sai de `Scripts/gerar-licencas.py`.
public struct LicencaDePacote: Decodable, Identifiable, Hashable, Sendable {
    /// Identidade do pacote no Package.resolved ou da fonte em FONTES_EMBUTIDAS.
    public let id: String
    public let nome: String
    public let versao: String
    /// Commit do SPM ou `sha256:<hash>` do binário da fonte embutida.
    public let revisao: String
    public let url: URL
    /// Identificador SPDX, como `Apache-2.0`.
    public let tipo: String
    public let texto: String
    /// Conteúdo do arquivo NOTICE do pacote, quando ele traz um.
    public let aviso: String?

    public init(id: String, nome: String, versao: String, revisao: String, url: URL, tipo: String, texto: String, aviso: String? = nil) {
        self.id = id
        self.nome = nome
        self.versao = versao
        self.revisao = revisao
        self.url = url
        self.tipo = tipo
        self.texto = texto
        self.aviso = aviso
    }
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

/// Textos da tela de licenças (#178).
enum TextosDeLicencas {
    static let titulo = String(localized: "Licenças de código aberto", bundle: bundleApresentacao)
    static let versao = String(localized: "Versão", bundle: bundleApresentacao)
    static let licenca = String(localized: "Licença", bundle: bundleApresentacao)
    static let repositorio = String(localized: "Repositório", bundle: bundleApresentacao)
    static let aviso = String(localized: "Avisos do pacote", bundle: bundleApresentacao)
    static let falha = String(localized: "Não foi possível carregar as licenças.", bundle: bundleApresentacao)
    static let dicaAbrir = String(localized: "Abre o texto da licença", bundle: bundleApresentacao)
}

/// Lista das dependências do build com a licença de cada uma, num grupo de linhas do sistema do Fabrício (nome e
/// "versão · licença", com a seta de quem abre outra tela). Tela de leitura, sem laranja. Precisa estar dentro de um
/// `NavigationStack`, que é quem abre o detalhe.
public struct TelaLicencas: View {
    private enum Estado {
        case carregando
        case carregada([LicencaDePacote])
        case falha
    }

    @State private var estado = Estado.carregando
    @State private var aberta: LicencaDePacote?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                switch estado {
                case .carregando:
                    EstadoCarregando()
                case let .carregada(licencas):
                    FrilaGrupoDeLinhas(linhasComIcone: false) {
                        ForEach(licencas) { licenca in
                            FrilaLinhaDeOpcao(
                                titulo: licenca.nome,
                                subtitulo: "\(licenca.versao) · \(licenca.tipo)",
                                remate: .navega
                            ) {
                                aberta = licenca
                            }
                            .accessibilityIdentifier("licenca-\(licenca.id)")
                            .accessibilityHint(TextosDeLicencas.dicaAbrir)
                        }
                    }
                case .falha:
                    AvisoFrila(verbatim: TextosDeLicencas.falha, tom: .erro)
                        .accessibilityIdentifier("licencas-erro")
                }
            }
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.vertical, FrilaEspaco.bloco)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(TextosDeLicencas.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $aberta) { licenca in
            TelaDetalheDaLicenca(licenca)
        }
        // O JSON é lido uma vez, quando a tela aparece: o destino de um NavigationLink é criado
        // junto com a tela de origem, e ler no init repetiria a leitura a cada redesenho dela.
        .task {
            guard case .carregando = estado else { return }
            estado = (try? Licencas.carregar()).map(Estado.carregada) ?? .falha
        }
    }
}

public struct TelaDetalheDaLicenca: View {
    private let licenca: LicencaDePacote

    public init(_ licenca: LicencaDePacote) { self.licenca = licenca }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                    campo(TextosDeLicencas.versao, licenca.versao)
                    campo(TextosDeLicencas.licenca, licenca.tipo)
                    Link(destination: licenca.url) {
                        campo(TextosDeLicencas.repositorio, licenca.url.absoluteString, sublinhado: true)
                            .frame(minHeight: FrilaMetrica.alvoMinimo)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("repositorio-da-licenca")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cartaoFrila()

                texto(licenca.texto).accessibilityIdentifier("texto-da-licenca")

                if let aviso = licenca.aviso {
                    VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                        Text(verbatim: TextosDeLicencas.aviso)
                            .font(FrilaTipo.rotuloDeGrupo)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .accessibilityAddTraits(.isHeader)
                        texto(aviso).accessibilityIdentifier("aviso-da-licenca")
                    }
                }
            }
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.vertical, FrilaEspaco.bloco)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(licenca.nome)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("tela-detalhe-da-licenca")
    }

    private func campo(_ titulo: String, _ valor: String, sublinhado: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
            Text(verbatim: titulo).font(FrilaTipo.apoio).foregroundStyle(FrilaCor.textoSecundario)
            Text(verbatim: valor).font(FrilaTipo.corpo).foregroundStyle(FrilaCor.texto)
                .underline(sublinhado)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // O texto da licença entra como veio do pacote, com as quebras de linha originais.
    private func texto(_ conteudo: String) -> some View {
        Text(verbatim: conteudo).font(FrilaTipo.legenda).foregroundStyle(FrilaCor.texto)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .cartaoFrila()
    }
}

#Preview("Lista") { NavigationStack { TelaLicencas() } }
