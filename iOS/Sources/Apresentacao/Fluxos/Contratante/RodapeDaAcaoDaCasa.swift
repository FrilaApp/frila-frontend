import SwiftUI

extension View {
    /// O grupo ancorado embaixo da tela (D-DS-09 do redesign), como o `rodapeAncorado` da fundação, mas que só existe
    /// quando há ação principal a mostrar: com `visivel` falso, não reserva espaço nem desenha o fio. Serve às telas da
    /// casa em que o botão laranja aparece conforme o estado (confirmar presença, chamar selecionados, enviar chamada).
    /// O erro da ação e o texto do que o toque faz vão dentro do grupo, antes do botão.
    func rodapeAncoradoSe<Conteudo: View>(_ visivel: Bool, @ViewBuilder _ conteudo: () -> Conteudo) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            if visivel {
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
}

/// A medida de uma linha de interruptor ou de data dentro de um `FrilaGrupoDeLinhas`: a margem do cartão dos dois lados
/// e o alvo de 48 pt.
struct LinhaDeControleDaCasa: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, FrilaMedidaDeLinha.margem)
            .padding(.vertical, FrilaEspaco.item)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvo, alignment: .leading)
    }
}

/// Uma linha de data e hora (Início, Término) de um `FrilaGrupoDeLinhas`. No tamanho padrão é o seletor compacto, com o
/// rótulo ao lado. Em texto de acessibilidade o seletor compacto (data e hora lado a lado) passa da largura da tela e
/// alarga a rolagem inteira: o rótulo vai em cima, e a data e a hora ficam uma embaixo da outra.
struct LinhaDeDataDaCasa: View {
    let rotulo: String
    @Binding var data: Date
    let faixa: ClosedRange<Date>
    @Environment(\.dynamicTypeSize) private var tamanhoDoTexto

    var body: some View {
        Group {
            if tamanhoDoTexto.isAccessibilitySize {
                VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                    Text(verbatim: rotulo).font(FrilaTipo.corpo)
                    // O seletor compacto é um controle do sistema que não quebra linha: em AX5 a data sozinha passa da
                    // largura da tela e arrasta o conteúdo inteiro para fora dela. Ele fica no maior tamanho que cabe.
                    DatePicker(selection: $data, in: faixa, displayedComponents: .date) { Text(verbatim: rotulo) }
                        .labelsHidden()
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    DatePicker(selection: $data, in: faixa, displayedComponents: .hourAndMinute) { Text(verbatim: rotulo) }
                        .labelsHidden()
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                }
            } else {
                DatePicker(selection: $data, in: faixa) { Text(verbatim: rotulo).font(FrilaTipo.corpo) }
            }
        }
        .modifier(LinhaDeControleDaCasa())
    }
}

