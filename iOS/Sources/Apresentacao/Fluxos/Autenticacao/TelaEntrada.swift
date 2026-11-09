import FrilaDominio
import SwiftUI

/// Entrada por e-mail (T6 do protótipo): ilustração doodle, título em Prodigy Sans,
/// subtítulo em apoio, campo de e-mail profissional, botão primário "Receber código"
/// no fluxo e termos legais logo abaixo.
public struct TelaEntrada: View {
    @Bindable var viewModel: EntradaViewModel
    var aoAvancarParaCodigo: (String) -> Void

    @State private var erroLocal: String?
    @State private var controleDoCampo = ControleDoCampoEmail()

    public init(viewModel: EntradaViewModel, aoAvancarParaCodigo: @escaping (String) -> Void) {
        self.viewModel = viewModel
        self.aoAvancarParaCodigo = aoAvancarParaCodigo
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                // Ilustração doodle de cabeçalho (342×112)
                DoodleEspacoReservado()
                    .accessibilityIdentifier("ilustracao-entrada")

                // Título e apoio editorial
                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    Text("Turnos rápidos perto de você, sem burocracia.", bundle: bundleApresentacao)
                        .font(FrilaTipo.titulo)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    Text("Entre com seu e-mail. A gente manda um código.", bundle: bundleApresentacao)
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Erro da API se houver
                if let erro = viewModel.erro {
                    AvisoFrila(verbatim: erro, tom: .erro)
                        .accessibilityIdentifier("entrada-erro")
                }

                // Formulário: Rótulo, Campo e Botão no fluxo
                VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                    VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                        Text("Seu e-mail profissional", bundle: bundleApresentacao)
                            .font(FrilaTipo.rotuloDoCampo)
                            .foregroundStyle(FrilaCor.texto)

                        CampoEmailComDominio(
                            texto: $viewModel.email,
                            habilitado: !viewModel.carregando,
                            aoEnviar: executarEnvio,
                            controle: controleDoCampo
                        )
                        .frame(height: FrilaMetrica.alturaDoCampo)
                        .zIndex(1)
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
                    }

                    BotaoPrimario("Receber código", carregando: viewModel.carregando) {
                        if controleDoCampo.completarAntesDeEnviar?() == true { return }
                        executarEnvio()
                    }
                    .disabled(viewModel.carregando)
                    .accessibilityIdentifier("entrada-receber-codigo")
                }

                // Textos legais logo abaixo do botão
                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    Text("Ao pedir o código, você aceita os [Termos de uso](https://frilabr.com/termos) e a [Política de privacidade](https://frilabr.com/privacidade).", bundle: bundleApresentacao)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .tint(FrilaCor.texto)
                        .multilineTextAlignment(.leading)

                    Text("Classificação indicativa: 18 anos", bundle: bundleApresentacao)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .multilineTextAlignment(.leading)
                        .accessibilityIdentifier("entrada-classificacao-indicativa")

                    #if FRILA_BETA
                    SeloBeta()
                    #endif
                }
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.top, FrilaEspaco.compacto)
            .padding(.bottom, FrilaEspaco.enorme)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(FrilaCor.fundo.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .onChange(of: viewModel.email) { _, _ in
            if erroLocal != nil { erroLocal = nil }
            if viewModel.erro != nil { viewModel.erro = nil }
        }
        .frilaKeyboardDismissScope()
        #if DEBUG || FRILA_BETA
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

        guard ValidacaoEmail.ehValido(emailLimpo) else {
            erroLocal = String(localized: "E-mail inválido. Confira se digitou corretamente.", bundle: bundleApresentacao)
            return
        }

        erroLocal = nil
        Task {
            let resultado = await viewModel.enviarCodigo(para: emailLimpo)
            if resultado {
                aoAvancarParaCodigo(emailLimpo)
            }
        }
    }
}
