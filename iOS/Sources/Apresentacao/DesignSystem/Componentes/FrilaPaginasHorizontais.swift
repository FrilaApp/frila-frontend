import SwiftUI

/// Páginas lado a lado numa janela horizontal: só a atual aparece, e trocar de página desliza o conjunto inteiro, como
/// se a página nova viesse de outra seção. A janela recorta o que passa das bordas e esmaece a entrada e a saída com
/// uma máscara progressiva (um degradê de opacidade nas duas pontas), então nada corta seco.
///
/// É o par natural de um seletor de etapas (`FrilaStepSegments`): o seletor muda, e a página que ele controla anda no
/// mesmo sentido da decisão, em direção oposta ao cursor. Serve para qualquer conteúdo de mesma altura (a altura vem
/// do contêiner de fora).
///
/// - A **margem** estende a janela para fora do conteúdo (o degradê vive nela), para o conteúdo em repouso aparecer
///   inteiro e a entrada nascer na borda do contêiner de fora, por exemplo no respiro de um cartão.
/// - Cada página é posicionada pela distância ao índice atual, então ir de 0 a 2 passa pela 1 sem animação extra.
/// - Páginas inativas não recebem toque e ficam fora da acessibilidade.
/// - Com movimento reduzido, só troca a opacidade.
public struct FrilaPaginasHorizontais<Pagina: View>: View {
    private let quantidade: Int
    private let atual: Int
    private let margem: CGFloat
    private let pagina: (Int) -> Pagina

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    public init(quantidade: Int, atual: Int, margem: CGFloat = FrilaEspaco.medio, @ViewBuilder pagina: @escaping (Int) -> Pagina) {
        self.quantidade = quantidade
        self.atual = atual
        self.margem = margem
        self.pagina = pagina
    }

    public var body: some View {
        GeometryReader { geo in
            let largura = geo.size.width
            let janela = largura + 2 * margem
            ZStack {
                ForEach(0..<quantidade, id: \.self) { indice in
                    let ativa = indice == atual
                    pagina(indice)
                        .frame(width: largura, height: geo.size.height)
                        .offset(x: reduzirMovimento ? 0 : CGFloat(indice - atual) * janela)
                        .opacity(reduzirMovimento && !ativa ? 0 : 1)
                        .allowsHitTesting(ativa)
                        .accessibilityHidden(!ativa)
                }
            }
            .frame(width: janela, height: geo.size.height)
            .mask(degrade(janela: janela))
            .offset(x: -margem)
        }
        .animation(FrilaMovimento.animacao(FrilaMotion.paginasHorizontais, reduzir: reduzirMovimento), value: atual)
    }

    /// Opaco no miolo e esmaecendo nas pontas: o degradê ocupa só a margem.
    private func degrade(janela: CGFloat) -> some View {
        let ponta = janela > 0 ? min(margem / janela, 0.5) : 0
        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: ponta),
                .init(color: .black, location: 1 - ponta),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
