import SwiftUI

/// Um chip de horário da fileira.
public struct FrilaTimeChipItem: Identifiable, Hashable {
    public let id: String
    public let rotulo: String
    public let selecionado: Bool
    /// Texto curto mostrado antes deste chip, para marcar uma virada (por exemplo, "dia seguinte").
    public let marcaAntes: String?

    public init(id: String, rotulo: String, selecionado: Bool, marcaAntes: String? = nil) {
        self.id = id
        self.rotulo = rotulo
        self.selecionado = selecionado
        self.marcaAntes = marcaAntes
    }
}

/// Fileira horizontal de chips de horário em passos regulares, no lugar da roleta nativa. Rola de lado,
/// começa já posicionada em `ancora` (que não é uma escolha, só o ponto onde a lista abre) e deixa o
/// próximo chip aparecer pela borda para mostrar que há mais.
public struct FrilaTimeChipRow: View {
    private let itens: [FrilaTimeChipItem]
    private let ancora: String?
    private let aoEscolher: (String) -> Void

    public init(itens: [FrilaTimeChipItem], ancora: String?, aoEscolher: @escaping (String) -> Void) {
        self.itens = itens
        self.ancora = ancora
        self.aoEscolher = aoEscolher
    }

    public var body: some View {
        ScrollViewReader { leitor in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FrilaEspaco.pequeno) {
                    ForEach(itens) { item in
                        if let marca = item.marcaAntes {
                            Text(verbatim: marca)
                                .font(FrilaTipo.nota)
                                .foregroundStyle(FrilaCor.textoSecundario)
                                .fixedSize()
                                .padding(.horizontal, FrilaEspaco.minimo)
                        }
                        FiltroPill(verbatim: item.rotulo, selecionado: item.selecionado) {
                            aoEscolher(item.id)
                        }
                        .id(item.id)
                        .accessibilityIdentifier("chip-horario-\(item.id)")
                    }
                }
                .padding(.horizontal, FrilaEspaco.pequeno)
            }
            .onAppear {
                guard let ancora else { return }
                leitor.scrollTo(ancora, anchor: .leading)
            }
            // As bordas esmaecem: o chip cortado some em vez de ser decepado, e fica claro que a fileira rola.
            .mask(
                HStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                        .frame(width: FrilaEspaco.pequeno)
                    Rectangle().fill(.black)
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: FrilaEspaco.grande)
                }
            )
        }
    }
}
