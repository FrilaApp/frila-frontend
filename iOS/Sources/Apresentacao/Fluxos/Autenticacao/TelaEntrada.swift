import FrilaDominio
import SwiftUI

/// Entrada por e-mail (#13), no quadro "Main" do MidFi do Fabrício: título, campo de e-mail e o botão escuro de enviar o código.
public struct TelaEntrada: View {
    @Bindable var viewModel: EntradaViewModel
    var aoAvancarParaCodigo: (String) -> Void

    public init(viewModel: EntradaViewModel, aoAvancarParaCodigo: @escaping (String) -> Void) {
        self.viewModel = viewModel
        self.aoAvancarParaCodigo = aoAvancarParaCodigo
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.enorme) {
                Spacer(minLength: FrilaEspaco.enorme)

                VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                    Text("Frila", bundle: bundleApresentacao)
                        .font(FrilaTipo.tituloGrande)
                        .foregroundStyle(FrilaCor.texto)
                        .accessibilityAddTraits(.isHeader)

                    Text("Turnos avulsos no DF, perto de você.", bundle: bundleApresentacao)
                        .font(FrilaTipo.subtituloDaTela)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }

                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    Text("E-mail", bundle: bundleApresentacao)
                        .font(FrilaTipo.meta.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)

                    CampoFrila("voce@exemplo.com", texto: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel(Text("E-mail", bundle: bundleApresentacao))
                        .accessibilityIdentifier("entrada-email")

                    Text("Sem senha e sem SMS: você entra com um código enviado ao seu e-mail.", bundle: bundleApresentacao)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }

                if let erro = viewModel.erro {
                    AvisoFrila(verbatim: erro, tom: .erro)
                        .accessibilityIdentifier("entrada-erro")
                }

                VStack(spacing: FrilaEspaco.medio) {
                    BotaoPrimario("Enviar código", carregando: viewModel.carregando) {
                        Task {
                            if await viewModel.solicitarCodigo() {
                                aoAvancarParaCodigo(viewModel.email)
                            }
                        }
                    }
                    .disabled(viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.carregando)
                    .accessibilityIdentifier("entrada-receber-codigo")

                    Text("Ao continuar, você aceita os Termos de Uso e a Política de Privacidade.", bundle: bundleApresentacao)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                Spacer(minLength: FrilaEspaco.enorme)
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
            .frame(maxWidth: .infinity)
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
    }
}
