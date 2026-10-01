import FrilaDominio
import SwiftUI

public struct TelaEntrada: View {
    @Bindable var viewModel: EntradaViewModel
    var aoAvancarParaCodigo: (String) -> Void

    public init(viewModel: EntradaViewModel, aoAvancarParaCodigo: @escaping (String) -> Void) {
        self.viewModel = viewModel
        self.aoAvancarParaCodigo = aoAvancarParaCodigo
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                Spacer(minLength: 40)

                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    Text("Frila", bundle: bundleApresentacao)
                        .font(.largeTitle.bold())
                        .foregroundStyle(FrilaCor.texto)

                    Text("Turnos avulsos no DF, perto de você.", bundle: bundleApresentacao)
                        .font(.title3)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }

                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    Text("E-mail", bundle: bundleApresentacao)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)

                    CampoFrila("voce@exemplo.com", texto: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("entrada-email")

                    Text("Sem senha e sem SMS: você entra com um código enviado ao seu e-mail.", bundle: bundleApresentacao)
                        .font(.footnote)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }

                if let erro = viewModel.erro {
                    AvisoFrila(verbatim: erro, tom: .erro)
                        .accessibilityIdentifier("entrada-erro")
                }

                VStack(spacing: FrilaEspaco.medio) {
                    BotaoPrimario("Receber código", carregando: viewModel.carregando) {
                        Task {
                            if await viewModel.solicitarCodigo() {
                                aoAvancarParaCodigo(viewModel.email)
                            }
                        }
                    }
                    .disabled(viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.carregando)
                    .accessibilityIdentifier("entrada-receber-codigo")

                    Text("Ao continuar, você aceita os Termos de Uso e a Política de Privacidade.", bundle: bundleApresentacao)
                        .font(.footnote)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
    }
}
