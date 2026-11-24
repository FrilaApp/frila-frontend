import FrilaDominio
import SwiftUI

public struct TelaDefinirSenha: View {
    @State private var viewModel: DefinirSenhaViewModel
    @Environment(\.dismiss) private var dismiss

    private let permitirPular: Bool
    private let aoConcluir: (() -> Void)?

    @FocusState private var campoFocado: Campo?

    private enum Campo: Hashable {
        case senha
        case confirmacao
    }

    public init(
        api: any ApiCliente,
        permitirPular: Bool = false,
        aoConcluir: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: DefinirSenhaViewModel(api: api))
        self.permitirPular = permitirPular
        self.aoConcluir = aoConcluir
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                    Text("Definir senha", bundle: bundleApresentacao)
                        .font(FrilaTipo.tituloDaTela)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    Text("Crie ou atualize a senha desta conta para entrar sem depender do código por e-mail. Você continua podendo usar o código quando quiser.", bundle: bundleApresentacao)
                        .font(FrilaTipo.apoio)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                    VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                        Text("Nova senha", bundle: bundleApresentacao)
                            .font(FrilaTipo.rotuloDeGrupo)
                            .foregroundStyle(FrilaCor.textoSecundario)

                        SecureField(text: $viewModel.senha, prompt: Text("Mínimo de 8 caracteres", bundle: bundleApresentacao)) {
                            Text("Nova senha", bundle: bundleApresentacao)
                        }
                        .textContentType(.newPassword)
                        .submitLabel(.next)
                        .focused($campoFocado, equals: .senha)
                        .onSubmit { campoFocado = .confirmacao }
                        .disabled(viewModel.carregando)
                        .padding(.horizontal, FrilaEspaco.bloco)
                        .frame(height: FrilaMetrica.alturaDoCampo)
                        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                                .strokeBorder(FrilaCor.borda, lineWidth: 1)
                        )
                        .accessibilityIdentifier("definir-senha-campo")
                    }

                    VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                        Text("Confirmar senha", bundle: bundleApresentacao)
                            .font(FrilaTipo.rotuloDeGrupo)
                            .foregroundStyle(FrilaCor.textoSecundario)

                        SecureField(text: $viewModel.confirmacao, prompt: Text("Repita a nova senha", bundle: bundleApresentacao)) {
                            Text("Confirmar senha", bundle: bundleApresentacao)
                        }
                        .textContentType(.newPassword)
                        .submitLabel(.done)
                        .focused($campoFocado, equals: .confirmacao)
                        .onSubmit { salvar() }
                        .disabled(viewModel.carregando)
                        .padding(.horizontal, FrilaEspaco.bloco)
                        .frame(height: FrilaMetrica.alturaDoCampo)
                        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                                .strokeBorder(FrilaCor.borda, lineWidth: 1)
                        )
                        .accessibilityIdentifier("definir-senha-confirmacao")
                    }

                    if viewModel.concluido {
                        Text("Senha salva nesta conta.", bundle: bundleApresentacao)
                            .font(FrilaTipo.apoio)
                            .foregroundStyle(FrilaCor.texto)
                            .accessibilityIdentifier("definir-senha-sucesso")
                    }
                }
            }
            .padding(.top, FrilaEspaco.bloco)
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.bottom, FrilaEspaco.secao)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(FrilaCor.fundo.ignoresSafeArea())
        .navigationTitle(Text("Senha da conta", bundle: bundleApresentacao))
        .navigationBarTitleDisplayMode(.inline)
        .rodapeAncorado {
            if let erro = viewModel.erro {
                MensagemJuntoAoBotao(verbatim: erro)
                    .accessibilityIdentifier("definir-senha-erro")
            }

            if permitirPular {
                BotaoSecundario(verbatim: String(localized: "Agora não", bundle: bundleApresentacao)) {
                    concluirOuFechar()
                }
                .disabled(viewModel.carregando)
                .accessibilityIdentifier("definir-senha-pular")
            }

            BotaoPrimario("Salvar senha", carregando: viewModel.carregando) {
                salvar()
            }
            .disabled(viewModel.carregando)
            .accessibilityIdentifier("definir-senha-salvar")
        }
        .frilaKeyboardDismissScope()
        .onChange(of: viewModel.senha) { _, _ in viewModel.erro = nil }
        .onChange(of: viewModel.confirmacao) { _, _ in viewModel.erro = nil }
    }

    private func salvar() {
        guard !viewModel.carregando else { return }
        campoFocado = nil
        Task {
            if await viewModel.salvar() {
                concluirOuFechar()
            }
        }
    }

    private func concluirOuFechar() {
        if let aoConcluir {
            aoConcluir()
        } else {
            dismiss()
        }
    }
}
