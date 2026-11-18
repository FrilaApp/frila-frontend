import FrilaDominio
import SwiftUI

/// Entrada por e-mail (#13, T6 do redesign): a marca, o título, o campo de e-mail e, ancorados embaixo, o texto
/// legal, a mensagem do envio e o botão "Receber código". Sem Apple e Google e sem a abertura animada (fora do lote).
public struct TelaEntrada: View {
    @Bindable var viewModel: EntradaViewModel
    var aoAvancarParaCodigo: (String) -> Void

    @Environment(\.dynamicTypeSize) private var tamanhoDoTexto
    @State private var erroLocal: String?
    @State private var controleDoCampo = ControleDoCampoEmail()

    public init(viewModel: EntradaViewModel, aoAvancarParaCodigo: @escaping (String) -> Void) {
        self.viewModel = viewModel
        self.aoAvancarParaCodigo = aoAvancarParaCodigo
    }

    public var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                        RotuloDaMarca()
                            .frame(height: 32)
                        cabecalho
                        formulario
                    }

                    Spacer(minLength: FrilaEspaco.grupo)

                    VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                        // Com texto grande, o legal desce para o fim do conteúdo: ancorado, ele tomaria a tela.
                        if tamanhoDoTexto.isAccessibilitySize {
                            textoLegal
                        }

                        Text("Classificação indicativa: 18 anos", bundle: bundleApresentacao)
                            .font(FrilaTipo.legenda)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .accessibilityIdentifier("entrada-classificacao-indicativa")

                        #if FRILA_BETA
                        SeloBeta()
                        #endif
                    }
                }
                .frame(minHeight: max(0, geometry.size.height - FrilaEspaco.grupo * 2), alignment: .top)
                .padding(.top, FrilaEspaco.grupo)
                .padding(.horizontal, FrilaEspaco.grupo)
                .padding(.bottom, FrilaEspaco.grupo)
                .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
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
        .rodapeAncorado {
            // O que o toque faz fica escrito antes do botão, no mesmo grupo.
            if !tamanhoDoTexto.isAccessibilitySize {
                textoLegal
            }

            if let erro = viewModel.erro {
                MensagemJuntoAoBotao(verbatim: erro)
                    .accessibilityIdentifier("entrada-erro")
            }

            BotaoPrimario("Receber código", carregando: viewModel.carregando) {
                // Com ghost, o primeiro toque completa e o segundo envia, como no Return.
                if controleDoCampo.completarAntesDeEnviar?() == true { return }
                executarEnvio()
            }
            .disabled(viewModel.carregando)
            .accessibilityIdentifier("entrada-receber-codigo")
        }
        .frilaKeyboardDismissScope()
        #if DEBUG || FRILA_BETA
        .exemploDebugEntrada()
        #endif
    }

    private var textoLegal: some View {
        Text("Ao continuar, você aceita os [Termos de Uso](https://frilabr.com/termos) e a [Política de Privacidade](https://frilabr.com/privacidade).", bundle: bundleApresentacao)
            .font(FrilaTipo.legenda)
            .foregroundStyle(FrilaCor.textoSecundario)
            .tint(FrilaCor.texto)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text("Turnos avulsos no DF, perto de você.", bundle: bundleApresentacao)
                .font(FrilaTipo.tituloDaTela)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text("Sem senha e sem SMS: você entra com um código enviado ao seu e-mail.", bundle: bundleApresentacao)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var formulario: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text("E-mail", bundle: bundleApresentacao)
                .font(FrilaTipo.rotuloDeGrupo)
                .foregroundStyle(FrilaCor.textoSecundario)

            CampoEmailComDominio(texto: $viewModel.email, habilitado: !viewModel.carregando, aoEnviar: executarEnvio, controle: controleDoCampo)
                .frame(height: FrilaMetrica.alturaDoCampo)
                .zIndex(1)
                .overlay(
                    // O que falta no campo vira o contorno de 2 pt em tinta, como o foco: problema não tem cor.
                    RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                        .strokeBorder(erroLocal != nil ? FrilaCor.texto : Color.clear, lineWidth: erroLocal != nil ? 2 : 0)
                        .allowsHitTesting(false)
                )
                .accessibilityLabel(Text("E-mail", bundle: bundleApresentacao))
                .accessibilityIdentifier("entrada-email")

            if let erro = erroLocal {
                MensagemJuntoAoBotao(verbatim: erro)
            }
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
