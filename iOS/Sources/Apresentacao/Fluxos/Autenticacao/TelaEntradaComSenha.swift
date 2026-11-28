import FrilaDominio
import SwiftUI

public struct TelaEntradaComSenha: View {
    @Bindable var viewModel: EntradaComSenhaViewModel
    var aoCriarConta: (String) -> Void
    var aoEsqueciSenha: (String) -> Void
    var aoConcluir: (DestinoCodigo) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var campoFocado: Campo?
    @State private var senhaFocada: Bool = false
    @State private var senhaVisivel: Bool = false
    @State private var tarefaDeEntrada: Task<Void, Never>?

    private enum Campo: Hashable {
        case email
        case senha
    }

    public init(
        viewModel: EntradaComSenhaViewModel,
        aoCriarConta: @escaping (String) -> Void,
        aoEsqueciSenha: @escaping (String) -> Void,
        aoConcluir: @escaping (DestinoCodigo) -> Void
    ) {
        self.viewModel = viewModel
        self.aoCriarConta = aoCriarConta
        self.aoEsqueciSenha = aoEsqueciSenha
        self.aoConcluir = aoConcluir
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                    RotuloDaMarca()
                        .frame(height: 32)
                        .destinoDoRotuloDaAbertura()

                    VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                        Text("Entrar com senha", bundle: bundleApresentacao)
                            .font(FrilaTipo.tituloDaTela)
                            .foregroundStyle(FrilaCor.texto)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)

                        Text("Use o e-mail da sua conta e a senha cadastrada.", bundle: bundleApresentacao)
                            .font(FrilaTipo.apoio)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                            Text("E-mail", bundle: bundleApresentacao)
                                .font(FrilaTipo.rotuloDeGrupo)
                                .foregroundStyle(FrilaCor.textoSecundario)

                            TextField(text: $viewModel.email, prompt: Text("nome@exemplo.com", bundle: bundleApresentacao)) {
                                Text("E-mail", bundle: bundleApresentacao)
                            }
                            .keyboardType(.emailAddress)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.next)
                            .focused($campoFocado, equals: .email)
                            .onSubmit {
                                campoFocado = nil
                                senhaFocada = true
                            }
                            .disabled(viewModel.carregando)
                            .padding(.horizontal, FrilaEspaco.bloco)
                            .frame(height: FrilaMetrica.alturaDoCampo)
                            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                                    .strokeBorder(FrilaCor.borda, lineWidth: 1)
                            )
                            .accessibilityIdentifier("entrada-senha-email")
                        }

                        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                            Text("Senha", bundle: bundleApresentacao)
                                .font(FrilaTipo.rotuloDeGrupo)
                                .foregroundStyle(FrilaCor.textoSecundario)

                            CampoDeSenhaComVisibilidade(
                                texto: $viewModel.senha,
                                senhaVisivel: $senhaVisivel,
                                placeholder: String(localized: "Digite sua senha", bundle: bundleApresentacao),
                                rotuloAcessibilidade: String(localized: "Senha", bundle: bundleApresentacao),
                                identificadorCampo: "entrada-senha-campo",
                                identificadorBotao: "entrada-senha-alternar-visibilidade",
                                returnKeyType: .go,
                                habilitado: !viewModel.carregando,
                                estaFocado: $senhaFocada,
                                ocultarPorSeguranca: scenePhase != .active,
                                textContentType: .password,
                                revelacaoBreve: false,
                                aoSubmeter: { executarEntrada() }
                            )
                            .frilaFormField(
                                id: "entrada-senha-campo",
                                isFocused: senhaFocada,
                                onDismiss: { senhaFocada = false }
                            )
                        }

                        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                            Button {
                                cancelarEEsair { aoEsqueciSenha(viewModel.email) }
                            } label: {
                                Text("Esqueci ou ainda não tenho senha", bundle: bundleApresentacao)
                            }
                            .buttonStyle(.frilaLink)
                            .accessibilityIdentifier("entrada-senha-esqueci")

                            BotaoSecundario(verbatim: String(localized: "Criar conta", bundle: bundleApresentacao)) {
                                cancelarEEsair { aoCriarConta(viewModel.email) }
                            }
                            .disabled(viewModel.carregando)
                            .accessibilityIdentifier("entrada-senha-criar-conta")

                            if viewModel.mostrarLoginSocial {
                                Divider()
                                    .padding(.vertical, FrilaEspaco.item)

                                // Diretriz 4.8 da App Store: Apple e Google sempre juntos no iOS.
                                BotaoSecundario(verbatim: String(localized: "Continuar com a Apple", bundle: bundleApresentacao)) {
                                    executarEntradaSocial { await viewModel.entrarComApple() }
                                }
                                .disabled(viewModel.carregando)
                                .accessibilityIdentifier("entrada-social-apple")

                                BotaoSecundario(verbatim: String(localized: "Continuar com o Google", bundle: bundleApresentacao)) {
                                    executarEntradaSocial { await viewModel.entrarComGoogle() }
                                }
                                .disabled(viewModel.carregando)
                                .accessibilityIdentifier("entrada-social-google")

                                Text(
                                    "Se você usar o mesmo e-mail verificado da sua conta Frila, o acesso entra na mesma conta. Se escolher Ocultar Meu E-mail na Apple (Private Relay), pode criar uma conta separada.",
                                    bundle: bundleApresentacao
                                )
                                .font(FrilaTipo.apoio)
                                .foregroundStyle(FrilaCor.textoSecundario)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("entrada-social-aviso-vinculo")
                            }
                        }
                    }
                }
                .padding(.top, FrilaEspaco.grupo)
                .padding(.horizontal, FrilaEspaco.grupo)
                .padding(.bottom, FrilaEspaco.secao)
                .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(FrilaCor.fundo.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .rodapeAncorado {
                if let erro = viewModel.erro {
                    MensagemJuntoAoBotao(verbatim: erro)
                        .accessibilityIdentifier("entrada-senha-erro")
                }

                BotaoPrimario("Entrar com senha", carregando: viewModel.carregando) {
                    executarEntrada()
                }
                .disabled(viewModel.carregando)
                .accessibilityIdentifier("entrada-senha-confirmar")
            }
        }
        .frilaKeyboardDismissScope()
        .onChange(of: viewModel.email) { _, _ in viewModel.erro = nil }
        .onChange(of: viewModel.senha) { _, _ in viewModel.erro = nil }
        .onChange(of: scenePhase) { _, novaFase in
            if novaFase != .active {
                senhaVisivel = false
            }
        }
        .onDisappear {
            senhaVisivel = false
            senhaFocada = false
            tarefaDeEntrada?.cancel()
            viewModel.cancelarTentativaAtual()
        }
    }

    private func executarEntrada() {
        guard !viewModel.carregando else { return }
        senhaVisivel = false
        campoFocado = nil
        senhaFocada = false
        tarefaDeEntrada?.cancel()
        tarefaDeEntrada = Task {
            if let destino = await viewModel.entrar(), !Task.isCancelled {
                aoConcluir(destino)
            }
        }
    }

    private func executarEntradaSocial(_ acao: @escaping @MainActor () async -> DestinoCodigo?) {
        guard !viewModel.carregando else { return }
        senhaVisivel = false
        campoFocado = nil
        senhaFocada = false
        tarefaDeEntrada?.cancel()
        tarefaDeEntrada = Task {
            if let destino = await acao(), !Task.isCancelled {
                aoConcluir(destino)
            }
        }
    }

    private func cancelarEEsair(_ acao: () -> Void) {
        senhaVisivel = false
        senhaFocada = false
        tarefaDeEntrada?.cancel()
        viewModel.cancelarTentativaAtual()
        acao()
    }
}
