import SwiftUI

public extension View {
    /// Fundo na área do relógio e da bateria, para telas sem barra de navegação (o cadastro, a conta suspensa, o
    /// cadastro da casa): com a rolagem, o conteúdo passava por trás do relógio e se misturava com ele. Só o fundo da
    /// tela (`FrilaCor.fundo`), sem sombra e sem fio. Vai no `ScrollView`, antes do rodapé ancorado.
    ///
    /// O conteúdo de altura zero preso ao topo não ocupa espaço nem muda a rolagem; o fundo dele, como todo fundo,
    /// se estende pela área segura de cima e cobre o que rola por baixo.
    func fundoSobORelogio() -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            Color.clear
                .frame(height: 0)
                .background(FrilaCor.fundo)
        }
    }
}
