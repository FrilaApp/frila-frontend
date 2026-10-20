import FrilaDominio
import SwiftUI

/// Entrada por e-mail (#13), no quadro "Main" do MidFi do Fabrício:
/// identidade, campo de e-mail com placeholder cinza e o CTA fixo de receber o código.
public struct TelaEntrada: View {
    @Bindable var viewModel: EntradaViewModel
    var aoAvancarParaCodigo: (String) -> Void

    @FocusState private var campoFocado: Bool
    @State private var erroLocal: String?

    /// O endereço de exemplo é sintaxe técnica de placeholder, não texto traduzível de produto.
    /// É mantido como constante para preservar o contrato do conferir-textos.sh e alimentar
    /// CampoFrila(verbatim:), impedindo que o SwiftUI interprete o e-mail como link azul.
    private let exemploDeEmail = "nome@exemplo.com"

    public init(viewModel: EntradaViewModel, aoAvancarParaCodigo: @escaping (String) -> Void) {
        self.viewModel = viewModel
        self.aoAvancarParaCodigo = aoAvancarParaCodigo
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.enorme) {
                // Identidade: bloco da marca e títulos
                VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                    Text("F", bundle: bundleApresentacao)
                        .font(FrilaTipo.tituloGrande)
                        .foregroundStyle(FrilaCor.sobrePrimaria)
                        .frame(width: 64, height: 64)
                        .background(FrilaCor.primaria, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                        Text("Frila", bundle: bundleApresentacao)
                            .font(FrilaTipo.tituloGrande)
                            .foregroundStyle(FrilaCor.texto)
                            .accessibilityAddTraits(.isHeader)

                        Text("Turnos avulsos no DF, perto de você.", bundle: bundleApresentacao)
                            .font(FrilaTipo.subtituloDaTela)
                            .foregroundStyle(FrilaCor.textoSecundario)
                    }
                }

                // Erro neutro da API / conexão (quando presente)
                if let erro = viewModel.erro {
                    HStack(alignment: .top, spacing: FrilaEspaco.compacto) {
                        Image(systemName: "exclamationmark.circle")
                            .font(FrilaTipo.meta)
                            .foregroundStyle(FrilaCor.texto)
                            .accessibilityHidden(true)

                        Text(verbatim: erro)
                            .font(FrilaTipo.meta)
                            .foregroundStyle(FrilaCor.texto)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, FrilaEspaco.medio)
                    .padding(.vertical, FrilaEspaco.faixa)
                    .background(FrilaCor.controle, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
                    .accessibilityIdentifier("entrada-erro")
                }

                // Agrupamento sob gap16 (FrilaEspaco.medio): formulário de e-mail e textos legais
                VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                    // Formulário de e-mail
                    VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                        Text("E-mail", bundle: bundleApresentacao)
                            .font(FrilaTipo.meta.weight(.semibold))
                            .foregroundStyle(FrilaCor.texto)

                        CampoFrila(verbatim: exemploDeEmail, texto: $viewModel.email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.send)
                            .focused($campoFocado)
                            .disabled(viewModel.carregando)
                            .onSubmit {
                                executarEnvio()
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous)
                                    .strokeBorder(erroLocal != nil ? FrilaCor.texto : Color.clear, lineWidth: erroLocal != nil ? 2 : 0)
                                    .allowsHitTesting(false)
                            )
                            .accessibilityLabel(Text("E-mail", bundle: bundleApresentacao))
                            .accessibilityIdentifier("entrada-email")

                        if let erro = erroLocal {
                            HStack(alignment: .top, spacing: FrilaEspaco.pequeno) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(FrilaTipo.meta)
                                    .foregroundStyle(FrilaCor.texto)
                                    .accessibilityHidden(true)

                                Text(verbatim: erro)
                                    .font(FrilaTipo.meta)
                                    .foregroundStyle(FrilaCor.texto)
                            }
                            .padding(.horizontal, FrilaEspaco.minimo)
                        }

                        Text("Sem senha e sem SMS: você entra com um código enviado ao seu e-mail.", bundle: bundleApresentacao)
                            .font(FrilaTipo.nota)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .padding(.horizontal, FrilaEspaco.minimo)
                    }

                    // Textos legais discretos fora da barra fixa
                    VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                        Text("Ao continuar, você aceita os [Termos de Uso](https://frila.netlify.app/termos) e a [Política de Privacidade](https://frila.netlify.app/privacidade).", bundle: bundleApresentacao)
                            .font(FrilaTipo.nota)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .tint(FrilaCor.texto)
                            .multilineTextAlignment(.leading)

                        Text("Classificação indicativa: 18 anos", bundle: bundleApresentacao)
                            .font(FrilaTipo.nota)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .multilineTextAlignment(.leading)
                            .accessibilityIdentifier("entrada-classificacao-indicativa")
                    }
                    .padding(.horizontal, FrilaEspaco.minimo)
                }
            }
            .padding(.top, FrilaEspaco.enorme + FrilaEspaco.enorme + FrilaEspaco.pequeno)
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.bottom, FrilaEspaco.enorme * 3)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .onChange(of: viewModel.email) { _, _ in
            if erroLocal != nil {
                erroLocal = nil
            }
            if viewModel.erro != nil {
                viewModel.erro = nil
            }
        }
        .barraInferiorFixa {
            BotaoPrimario("Receber código", carregando: viewModel.carregando) {
                executarEnvio()
            }
            .disabled(viewModel.carregando)
            .accessibilityIdentifier("entrada-receber-codigo")
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.vertical, FrilaEspaco.compacto)
        }
    }

    private func executarEnvio() {
        guard !viewModel.carregando else { return }

        let emailLimpo = viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines)
        if emailLimpo.isEmpty {
            erroLocal = String(localized: "Digite seu e-mail para receber o código.", bundle: bundleApresentacao)
            return
        }

        guard viewModel.emailValido else {
            erroLocal = String(localized: "Confira o e-mail. Use um endereço como nome@exemplo.com.", bundle: bundleApresentacao)
            return
        }

        erroLocal = nil
        Task {
            if await viewModel.solicitarCodigo() {
                aoAvancarParaCodigo(viewModel.email)
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func barraInferiorFixa<Content: View>(@ViewBuilder conteudo: () -> Content) -> some View {
        if #available(iOS 26, *) {
            safeAreaBar(edge: .bottom) {
                conteudo()
            }
        } else {
            safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(FrilaCor.divisoria)
                        .frame(height: 1)

                    conteudo()
                }
                .background(.regularMaterial)
            }
        }
    }
}
