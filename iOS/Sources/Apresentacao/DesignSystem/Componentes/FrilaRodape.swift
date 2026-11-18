import SwiftUI

public extension View {
    /// O grupo ancorado embaixo das telas de entrada e de formulário (D-DS-09 do redesign): um fio de `borda` em cima,
    /// o conteúdo e o botão primário, com 8 pt entre eles. Com o teclado aberto, sobe junto com ele.
    /// A mensagem do botão (`MensagemJuntoAoBotao`) e o texto do que o toque faz vão dentro do grupo, antes do botão.
    func rodapeAncorado<Conteudo: View>(@ViewBuilder _ conteudo: () -> Conteudo) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: FrilaEspaco.item) {
                conteudo()
            }
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.top, FrilaEspaco.bloco)
            .padding(.bottom, FrilaEspaco.item)
            .frame(maxWidth: .infinity)
            .background(FrilaCor.fundo)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(FrilaCor.divisoria)
                    .frame(height: 1)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// Mensagem junto ao botão (DESIGN.md do protótipo): o erro ou o resultado da ação, logo acima do botão que a
/// disparou. Em tinta, no corpo, sem vermelho, sem ícone e sem cartão (D-DS-13: problema não tem cor).
/// O leitor de tela anuncia a mensagem quando ela aparece ou muda.
public struct MensagemJuntoAoBotao: View {
    private let texto: String

    public init(verbatim texto: String) { self.texto = texto }

    public var body: some View {
        Text(verbatim: texto)
            .font(FrilaTipo.corpo)
            .foregroundStyle(FrilaCor.texto)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            // O mesmo anúncio dos avisos do app: não repete a fala em redesenho e fala de novo se a mensagem mudar.
            .modifier(AnunciarAoAparecer(anuncio: .init(texto: texto, tom: .informativo)))
    }
}
