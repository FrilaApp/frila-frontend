import FrilaDominio
import SwiftUI

/// Recuperação explícita de senha nesta primeira fatia: o app ainda não possui esquema de URL nem
/// `associated-domains` configurados, então a recuperação usa `shouldCreateUser: false` para validar
/// a titularidade pelo código de 6 dígitos na conta existente (mesmo `auth.uid()`) e em seguida
/// abre a tela de definir nova senha.
public struct TelaRecuperacaoSenha: View {
    @Bindable var viewModel: RecuperacaoSenhaViewModel
    var aoVoltar: (String) -> Void
    var aoAvancarParaCodigo: (String) -> Void

    @FocusState private var campoFocado: Bool
    @State private var tarefaDeEnvio: Task<Void, Never>?

    public init(
        viewModel: RecuperacaoSenhaViewModel,
        aoVoltar: @escaping (String) -> Void,
        aoAvancarParaCodigo: @escaping (String) -> Void
    ) {
        self.viewModel = viewModel
        self.aoVoltar = aoVoltar
        self.aoAvancarParaCodigo = aoAvancarParaCodigo
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                    VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                        Text("Recuperar acesso", bundle: bundleApresentacao)
                            .font(FrilaTipo.tituloDaTela)
                            .foregroundStyle(FrilaCor.texto)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)

                        Text("Enviaremos um código de 6 dígitos para confirmar seu e-mail. Depois de validar o código, você poderá criar uma nova senha na mesma conta.", bundle: bundleApresentacao)
                            .font(FrilaTipo.apoio)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                        Text("E-mail", bundle: bundleApresentacao)
                            .font(FrilaTipo.rotuloDeGrupo)
                            .foregroundStyle(FrilaCor.textoSecundario)

                        TextField(text: $viewModel.email, prompt: Text("nome@exemplo.com", bundle: bundleApresentacao)) {
                            Text("E-mail", bundle: bundleApresentacao)
                        }
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.send)
                        .focused($campoFocado)
                        .onSubmit { enviarCodigo() }
                        .disabled(viewModel.carregando)
                        .padding(.horizontal, FrilaEspaco.bloco)
                        .frame(height: FrilaMetrica.alturaDoCampo)
                        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                                .strokeBorder(FrilaCor.borda, lineWidth: 1)
                        )
                        .accessibilityIdentifier("recuperacao-email")

                        if let mensagemNeutra = viewModel.mensagemNeutra {
                            Text(verbatim: mensagemNeutra)
                                .font(FrilaTipo.apoio)
                                .foregroundStyle(FrilaCor.textoSecundario)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("recuperacao-estado-neutro")
                        }
                    }
                }
                .padding(.top, FrilaEspaco.item)
                .padding(.horizontal, FrilaEspaco.grupo)
                .padding(.bottom, FrilaEspaco.secao)
                .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(FrilaCor.fundo.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        cancelarESair()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(FrilaCor.texto)
                            .frame(minWidth: FrilaMetrica.alvo, minHeight: FrilaMetrica.alvo)
                    }
                    .accessibilityLabel(Text("Voltar", bundle: bundleApresentacao))
                    .accessibilityIdentifier("recuperacao-voltar")
                }
            }
            .rodapeAncorado {
                if let erro = viewModel.erro {
                    MensagemJuntoAoBotao(verbatim: erro)
                        .accessibilityIdentifier("recuperacao-erro")
                }

                BotaoPrimario("Receber código", carregando: viewModel.carregando) {
                    enviarCodigo()
                }
                .disabled(viewModel.carregando)
                .accessibilityIdentifier("recuperacao-enviar-codigo")
            }
        }
        .frilaKeyboardDismissScope()
        .onChange(of: viewModel.email) { _, _ in
            viewModel.erro = nil
            viewModel.mensagemNeutra = nil
        }
        .onDisappear {
            tarefaDeEnvio?.cancel()
            viewModel.cancelarTentativaAtual()
        }
    }

    private func enviarCodigo() {
        guard !viewModel.carregando else { return }
        campoFocado = false
        tarefaDeEnvio?.cancel()
        tarefaDeEnvio = Task {
            guard let resultado = await viewModel.solicitarRecuperacao(), !Task.isCancelled else { return }
            if case let .avancarParaCodigo(emailConfirmado) = resultado {
                aoAvancarParaCodigo(emailConfirmado)
            }
        }
    }

    private func cancelarESair() {
        tarefaDeEnvio?.cancel()
        viewModel.cancelarTentativaAtual()
        aoVoltar(viewModel.email)
    }
}
