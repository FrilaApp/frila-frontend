import FrilaDominio
import SwiftUI

/// T6c · Dizer o nome (#12, Lote 4).
/// Tela de primeiro acesso após confirmação do código, onde a pessoa informa seu nome.
/// Sem voltar: o código de entrada já foi consumido.
public struct TelaDizerNome: View {
    @State private var nome: String
    @FocusState private var focoNoNome: Bool
    private let aoSalvar: (String) -> Void

    public init(
        nomeInicial: String = "Juliana Ramos",
        aoSalvar: @escaping (String) -> Void = { _ in }
    ) {
        _nome = State(initialValue: nomeInicial)
        self.aoSalvar = aoSalvar
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                // Título da tela
                Text(verbatim: TextosLote4.qualSeuNome)
                    .font(FrilaTipo.tituloGrande)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                // Campo Nome completo
                VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                    Text(verbatim: TextosLote4.nomeCompleto)
                        .font(FrilaTipo.rotuloDoCampo)
                        .foregroundStyle(FrilaCor.textoSecundario)

                    TextField(
                        Text(verbatim: TextosLote4.nomeCompleto),
                        text: $nome
                    )
                    .font(FrilaTipo.valorDoCampo)
                    .foregroundStyle(FrilaCor.texto)
                    .focused($focoNoNome)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .padding(.horizontal, FrilaEspaco.compacto)
                    .frame(minHeight: FrilaMetrica.alturaDoCampo)
                    .background(FrilaCor.superficieDoCampo, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                            .strokeBorder(FrilaCor.bordaDoCampo, lineWidth: 1)
                    )
                    .accessibilityIdentifier("dizer-nome-campo")
                }

                // CTA Salvar nome
                BotaoPrimario(verbatim: TextosLote4.salvarNome) {
                    let nomeFinal = nome.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !nomeFinal.isEmpty else { return }
                    aoSalvar(nomeFinal)
                }
                .disabled(nome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("dizer-nome-salvar")
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.top, FrilaEspaco.grande)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(FrilaCor.fundo.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .accessibilityIdentifier("tela-dizer-nome")
    }
}
