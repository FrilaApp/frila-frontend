import FrilaDominio
import SwiftUI

/// Entrada por e-mail (#13), com identidade editorial, campo e pílula do Hi-Fi.
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
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Grupo superior: hero, aviso da API se houver e formulário
                    VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                        // Identidade: bloco da marca e títulos
                        VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
                            Text("F", bundle: bundleApresentacao)
                                .font(FrilaTipo.tituloGrande)
                                .foregroundStyle(FrilaCor.sobrePrimaria)
                                .frame(width: 64, height: 64)
                                .background(FrilaCor.marca, in: RoundedRectangle(cornerRadius: FrilaRaio.cartao))
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                                Text("Frila", bundle: bundleApresentacao)
                                    .font(FrilaTipo.pergunta)
                                    .foregroundStyle(FrilaCor.texto)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityAddTraits(.isHeader)

                                Text("Turnos avulsos no DF, perto de você.", bundle: bundleApresentacao)
                                    .font(FrilaTipo.contextoDaResposta)
                                    .foregroundStyle(FrilaCor.textoSecundario)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        // Erro da API / conexão (quando presente)
                        if let erro = viewModel.erro {
                            AvisoFrila(verbatim: erro, tom: .erro)
                                .accessibilityIdentifier("entrada-erro")
                        }

                        // Formulário de e-mail
                        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                            Text("E-mail", bundle: bundleApresentacao)
                                .font(FrilaTipo.rotuloDoCampo)
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
                                    RoundedRectangle(cornerRadius: FrilaRaio.entrada)
                                        .strokeBorder(erroLocal != nil ? FrilaCor.perigo : Color.clear, lineWidth: erroLocal != nil ? 2 : 0)
                                        .allowsHitTesting(false)
                                )
                                .accessibilityLabel(Text("E-mail", bundle: bundleApresentacao))
                                .accessibilityIdentifier("entrada-email")

                            if let erro = erroLocal {
                                HStack(alignment: .top, spacing: FrilaEspaco.pequeno) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(FrilaTipo.meta)
                                        .foregroundStyle(FrilaCor.perigo)
                                        .accessibilityHidden(true)

                                    Text(verbatim: erro)
                                        .font(FrilaTipo.meta)
                                        .foregroundStyle(FrilaCor.perigo)
                                }
                            }

                            Text("Sem senha e sem SMS: você entra com um código enviado ao seu e-mail.", bundle: bundleApresentacao)
                                .font(FrilaTipo.contextoDaResposta)
                                .foregroundStyle(FrilaCor.textoSecundario)
                        }
                    }

                    Spacer(minLength: FrilaEspaco.grande)

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
                }
                .frame(minHeight: max(0, geometry.size.height - FrilaEspaco.grande * 2), alignment: .top)
                .padding(.top, FrilaEspaco.grande)
                .padding(.horizontal, FrilaEspaco.medio)
                .padding(.bottom, FrilaEspaco.grande)
                .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(FrilaCor.fundo.ignoresSafeArea())
        }
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
        #if FRILA_DESIGN
        .exemploDebugEntrada()
        #endif
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
    func barraInferiorFixa<Content: View>(@ViewBuilder conteudo: () -> Content) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(FrilaCor.divisoria)
                    .frame(height: 1)
                    .accessibilityHidden(true)
                conteudo()
            }
            .background(FrilaCor.fundo)
        }
    }
}
