import CoreLocation
import FrilaDominio
import MapKit
import SwiftUI

/// Prévia real do lugar e ação de mapa sob um único contorno (iteração 5, 04/11/2026).
///
/// Prévia de 102 pt (`MKMapSnapshotter` centrado no ponto da vaga, norte para cima, câmera inclinada) e botão
/// de 30 pt colado embaixo, tudo num contêiner de raio contínuo de 16 pt. A área de toque do botão se estende a
/// 44 pt (`alvoMinimoToque`), cobrindo a faixa inferior da prévia (que tem hit-testing desabilitado) para cumprir
/// o alvo mínimo de acessibilidade da Apple/WCAG sem alterar a geometria visual do card.
public struct FrilaMapaComAcao: View {
    /// Altura da prévia do mapa.
    public static let alturaPrevia: CGFloat = 102
    /// Altura visual do botão "Abrir no mapa", padding incluído.
    public static let alturaBotao: CGFloat = 30
    /// Alvo mínimo de toque para conformidade de acessibilidade (Apple HIG / WCAG).
    public static let alvoMinimoToque: CGFloat = FrilaMetrica.alvoMinimo

    public let ponto: CLLocationCoordinate2D
    public let abrirMapa: () -> Void

    public init(ponto: CLLocationCoordinate2D, abrirMapa: @escaping () -> Void) {
        self.ponto = ponto
        self.abrirMapa = abrirMapa
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            PreviaMapaReal(ponto: ponto)
                .frame(height: Self.alturaPrevia)
                .frame(maxHeight: .infinity, alignment: .top)
                .accessibilityIdentifier("previa-do-mapa")

            Button(action: abrirMapa) {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: max(0, Self.alvoMinimoToque - Self.alturaBotao))
                    HStack(spacing: FrilaEspaco.pequeno) {
                        Image(systemName: "map")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .accessibilityHidden(true)
                        Text("Abrir no mapa", bundle: bundleApresentacao)
                            .font(FrilaTipo.botaoPadrao)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.alturaBotao)
                    .foregroundStyle(FrilaColor.mapActionForeground)
                    .background(FrilaColor.mapActionBackground)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.tatil(scale: 1, alturaMinima: Self.alvoMinimoToque))
            .accessibilityIdentifier("abrir-no-mapa")
        }
        .frame(height: Self.alturaPrevia + Self.alturaBotao)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bloco-mapa-com-acao")
        .clipShape(RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous)
                .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Prévia

/// Parâmetros da câmera da prévia. A janela tem 102 pt de altura por cerca de 360 de largura.
enum CameraDaPreviaDoMapa {
    /// Inclinação da câmera, em graus. Norte sempre para cima.
    static let inclinacao: CGFloat = 30
    /// Distância da câmera ao ponto, em metros. Define a largura visível (cerca de 250 a 400 m).
    /// Com 400 m, o rótulo de rua que passa junto ao ponto (ex.: "W1 SUL") caía sob o pino e saía
    /// cortado ("W1 S"). O MapKit não deixa esconder rótulos de rua no mapa padrão; mais perto, o
    /// rótulo cabe no trecho de rua à esquerda do pino. Conferido em seis pontos do DF, claro e escuro.
    static let distancia: CLLocationDistance = 170
}

/// Imagem do snapshot e a posição do ponto da vaga dentro dela.
private struct PreviaGerada {
    let imagem: UIImage
    let ponto: CGPoint
}

/// Cache só em memória, por vaga (coordenada), aparência, tamanho e escala. Nada vai a disco: os termos da
/// Apple não permitem armazenar os blocos do mapa de forma permanente.
@MainActor
private enum CacheDaPreviaDoMapa {
    private final class Caixa {
        let previa: PreviaGerada
        init(_ previa: PreviaGerada) { self.previa = previa }
    }

    private static let cache: NSCache<NSString, Caixa> = {
        let cache = NSCache<NSString, Caixa>()
        cache.countLimit = 24
        return cache
    }()

    static func obter(_ chave: String) -> PreviaGerada? {
        cache.object(forKey: chave as NSString)?.previa
    }

    static func guardar(_ previa: PreviaGerada, para chave: String) {
        cache.setObject(Caixa(previa), forKey: chave as NSString)
    }
}

private struct PreviaMapaReal: View {
    let ponto: CLLocationCoordinate2D

    @Environment(\.colorScheme) private var esquema
    @Environment(\.displayScale) private var escala
    /// Muda quando uma prévia nova entra no cache, para redesenhar.
    @State private var versao = 0
    @State private var chaveComFalha: String?

    var body: some View {
        GeometryReader { geo in
            let tamanho = CGSize(width: geo.size.width.rounded(), height: geo.size.height.rounded())
            let chave = chave(para: tamanho)
            let _ = versao

            conteudo(chave: chave, tamanho: tamanho)
                .frame(width: geo.size.width, height: geo.size.height)
                .task(id: chave) { await gerar(chave: chave, tamanho: tamanho) }
        }
        .clipped()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func conteudo(chave: String, tamanho: CGSize) -> some View {
        if let previa = CacheDaPreviaDoMapa.obter(chave) {
            ZStack(alignment: .topLeading) {
                Image(uiImage: previa.imagem)
                    .frame(width: tamanho.width, height: tamanho.height)
                PinoDaVaga()
                    .position(
                        x: previa.ponto.x,
                        y: previa.ponto.y - PinoDaVaga.altura / 2
                    )
            }
            .accessibilityHidden(true)
        } else if chaveComFalha == chave {
            ZStack {
                Rectangle().fill(FrilaCor.controle)
                Text("Prévia indisponível", bundle: bundleApresentacao)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
        } else {
            Rectangle()
                .fill(FrilaCor.controle)
                .accessibilityHidden(true)
        }
    }

    private func chave(para tamanho: CGSize) -> String {
        String(
            format: "%.6f,%.6f|%.0fx%.0f|%@|%.1f",
            locale: Locale(identifier: "en_US_POSIX"),
            ponto.latitude, ponto.longitude, tamanho.width, tamanho.height,
            esquema == .dark ? "escuro" : "claro", escala
        )
    }

    private func gerar(chave: String, tamanho: CGSize) async {
        guard tamanho.width > 0, tamanho.height > 0 else { return }
        if CacheDaPreviaDoMapa.obter(chave) != nil { return }

        let opcoes = MKMapSnapshotter.Options()
        opcoes.size = tamanho
        opcoes.traitCollection = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: esquema == .dark ? .dark : .light),
            UITraitCollection(displayScale: escala)
        ])
        opcoes.camera = MKMapCamera(
            lookingAtCenter: ponto,
            fromDistance: CameraDaPreviaDoMapa.distancia,
            pitch: CameraDaPreviaDoMapa.inclinacao,
            heading: 0
        )
        let configuracao = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .muted)
        configuracao.pointOfInterestFilter = .excludingAll
        opcoes.preferredConfiguration = configuracao

        do {
            let snapshot = try await MKMapSnapshotter(options: opcoes).start()
            guard !Task.isCancelled else { return }
            CacheDaPreviaDoMapa.guardar(
                PreviaGerada(imagem: snapshot.image, ponto: snapshot.point(for: ponto)),
                para: chave
            )
            chaveComFalha = nil
            versao += 1
        } catch {
            guard !Task.isCancelled else { return }
            chaveComFalha = chave
        }
    }
}

// MARK: - Pino

/// Pino próprio da marca (Quente), com núcleo branco e sombra curta. Sem halo nem pulso. A ponta fica
/// na base do quadro, que é onde cai a coordenada projetada.
private struct PinoDaVaga: View {
    static let largura: CGFloat = 20
    static let altura: CGFloat = 26

    var body: some View {
        ZStack(alignment: .top) {
            FormaDoPino()
                .fill(FrilaCor.quente)
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
                .padding(.top, (Self.largura - 8) / 2)
        }
        .frame(width: Self.largura, height: Self.altura)
        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
        .accessibilityHidden(true)
    }
}

/// Gota: cabeça circular e ponta embaixo, no centro.
private struct FormaDoPino: Shape {
    func path(in rect: CGRect) -> Path {
        let raio = rect.width / 2
        let centro = CGPoint(x: rect.midX, y: rect.minY + raio)
        var caminho = Path()
        caminho.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        caminho.addCurve(
            to: CGPoint(x: rect.minX, y: centro.y),
            control1: CGPoint(x: rect.midX - raio * 0.15, y: rect.maxY - raio * 0.7),
            control2: CGPoint(x: rect.minX, y: centro.y + raio * 0.6)
        )
        caminho.addArc(center: centro, radius: raio, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        caminho.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: centro.y + raio * 0.6),
            control2: CGPoint(x: rect.midX + raio * 0.15, y: rect.maxY - raio * 0.7)
        )
        caminho.closeSubpath()
        return caminho
    }
}

/// Destino do botão "Abrir no mapa": o Apple Maps na coordenada da prévia, com o nome do estabelecimento e o
/// endereço como rótulo do ponto. Prévia e destino usam o mesmo ponto.
enum DestinoDoMapaDaVaga {
    static func url(_ vaga: Vaga) -> URL? {
        url(nome: vaga.estabelecimento.nome, endereco: vaga.local, latitude: vaga.ponto.latitude, longitude: vaga.ponto.longitude)
    }

    static func url(nome: String, endereco: String, latitude: Double, longitude: Double) -> URL? {
        let coordenada = String(format: "%.6f,%.6f", locale: Locale(identifier: "en_US_POSIX"), latitude, longitude)
        var componentes = URLComponents(string: "https://maps.apple.com/")
        componentes?.queryItems = [
            URLQueryItem(name: "ll", value: coordenada),
            URLQueryItem(name: "q", value: "\(nome), \(endereco)")
        ]
        return componentes?.url
    }
}
