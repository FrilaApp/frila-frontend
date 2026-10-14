import FrilaDominio
import SwiftUI

/// Cadastro (#12), nos quadros "Perfil" (escolha do perfil) e "Main" (campos) do MidFi do Fabrício: voltar circular, cartões de perfil e botão escuro de continuar.
public struct TelaCadastro: View {
    @Environment(\.openURL) private var openURL
    @Bindable var viewModel: CadastroViewModel
    var aoVoltar: () -> Void
    var aoConcluir: (DestinoAposEntrada) -> Void

    public init(
        viewModel: CadastroViewModel,
        aoVoltar: @escaping () -> Void,
        aoConcluir: @escaping (DestinoAposEntrada) -> Void
    ) {
        self.viewModel = viewModel
        self.aoVoltar = aoVoltar
        self.aoConcluir = aoConcluir
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                // Barra superior
                HStack {
                    Button(action: aoVoltar) {
                        Image(systemName: "chevron.left")
                            .font(FrilaTipo.corpo.weight(.semibold))
                            .foregroundStyle(FrilaCor.texto)
                            .frame(width: FrilaMetrica.alvoMinimo, height: FrilaMetrica.alvoMinimo)
                            .background(FrilaCor.superficie, in: Circle())
                            .overlay(Circle().strokeBorder(FrilaCor.divisoria, lineWidth: 1))
                    }
                    .accessibilityLabel(Text("Voltar", bundle: bundleApresentacao))
                    .accessibilityIdentifier("cadastro-voltar")

                    Text("Cadastro", bundle: bundleApresentacao)
                        .font(FrilaTipo.resumo)
                        .foregroundStyle(FrilaCor.texto)
                        .padding(.leading, FrilaEspaco.pequeno)

                    Spacer()
                }

                Text("Como você quer usar o Frila?", bundle: bundleApresentacao)
                    .font(Font.title.bold())
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityAddTraits(.isHeader)

                // Escolha de perfil
                VStack(spacing: FrilaEspaco.pequeno) {
                    cartaoPerfil(
                        perfil: .profissional,
                        titulo: String(localized: "Quero trabalhar em turnos", bundle: bundleApresentacao),
                        descricao: String(localized: "Perfil de profissional: receba vagas perto de você e candidate-se sem formulário.", bundle: bundleApresentacao),
                        identificador: "cadastro-perfil-profissional"
                    )

                    cartaoPerfil(
                        perfil: .contratante,
                        titulo: String(localized: "Quero publicar vagas", bundle: bundleApresentacao),
                        descricao: String(localized: "Perfil de contratante: publique vagas e acompanhe quem vai trabalhar.", bundle: bundleApresentacao),
                        identificador: "cadastro-perfil-contratante"
                    )
                }

                // Aviso de perfil fixo na conta (RN25)
                AvisoFrila(
                    "**O perfil fica fixo nesta conta.** Para usar o outro lado, crie outra conta, com outro e-mail. O telefone pode ser o mesmo.",
                    tom: .alerta
                )
                .accessibilityIdentifier("cadastro-aviso-fixo")

                // Campos de dados
                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    Text("Nome", bundle: bundleApresentacao)
                        .font(FrilaTipo.meta.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)

                    CampoFrila("Como você quer ser chamado", texto: $viewModel.nome)
                        .textContentType(.name)
                        .accessibilityIdentifier("cadastro-nome")
                }

                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    Text("Telefone com WhatsApp", bundle: bundleApresentacao)
                        .font(FrilaTipo.meta.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)

                    CampoFrila("(61) 9 0000-0000", texto: $viewModel.telefone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .accessibilityIdentifier("cadastro-telefone")

                    Text("A outra parte só vê o seu número depois que o turno é confirmado.", bundle: bundleApresentacao)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }

                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    Text("Data de nascimento", bundle: bundleApresentacao)
                        .font(FrilaTipo.meta.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)

                    CampoFrila("dd/mm/aaaa", texto: $viewModel.nascimentoTexto)
                        .keyboardType(.numbersAndPunctuation)
                        .accessibilityIdentifier("cadastro-nascimento")
                }

                // Checkbox 18+
                HStack(spacing: FrilaEspaco.pequeno) {
                    Button {
                        viewModel.maiorDeIdade.toggle()
                    } label: {
                        Image(systemName: viewModel.maiorDeIdade ? "checkmark.square.fill" : "square")
                            .font(FrilaTipo.subtituloDaTela)
                            .foregroundStyle(viewModel.maiorDeIdade ? FrilaCor.primaria : FrilaCor.textoSecundario)
                            .frame(width: FrilaMetrica.alvoMinimo, height: FrilaMetrica.alvoMinimo)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .accessibilityLabel(Text("Tenho 18 anos ou mais", bundle: bundleApresentacao))
                    .accessibilityValue(Text(viewModel.maiorDeIdade ? "Selecionado" : "Não selecionado", bundle: bundleApresentacao))
                    .accessibilityAddTraits(viewModel.maiorDeIdade ? [.isSelected] : [])
                    .accessibilityIdentifier("cadastro-maior-de-idade")

                    Text("Tenho 18 anos ou mais", bundle: bundleApresentacao)
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.texto)
                        .accessibilityHidden(true)
                        .onTapGesture { viewModel.maiorDeIdade.toggle() }
                }

                // Checkbox Termos de uso e Política de privacidade com links
                HStack(alignment: .top, spacing: FrilaEspaco.pequeno) {
                    Button {
                        viewModel.aceitouTermos.toggle()
                    } label: {
                        Image(systemName: viewModel.aceitouTermos ? "checkmark.square.fill" : "square")
                            .font(FrilaTipo.subtituloDaTela)
                            .foregroundStyle(viewModel.aceitouTermos ? FrilaCor.primaria : FrilaCor.textoSecundario)
                            .frame(width: FrilaMetrica.alvoMinimo, height: FrilaMetrica.alvoMinimo)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .accessibilityLabel(Text("Li e aceito os Termos de uso e a Política de privacidade", bundle: bundleApresentacao))
                    .accessibilityValue(Text(viewModel.aceitouTermos ? "Selecionado" : "Não selecionado", bundle: bundleApresentacao))
                    .accessibilityAddTraits(viewModel.aceitouTermos ? [.isSelected] : [])
                    .accessibilityAction(named: Text("Termos de uso", bundle: bundleApresentacao)) {
                        if let url = URL(string: "https://frila.app/termos") { openURL(url) }
                    }
                    .accessibilityAction(named: Text("Política de privacidade", bundle: bundleApresentacao)) {
                        if let url = URL(string: "https://frila.app/privacidade") { openURL(url) }
                    }
                    .accessibilityIdentifier("cadastro-termos")

                    Text("Li e aceito os [Termos de uso](https://frila.app/termos) e a [Política de privacidade](https://frila.app/privacidade)", bundle: bundleApresentacao)
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.texto)
                        .padding(.top, 10)
                        .accessibilityHidden(true)
                }

                if let erro = viewModel.erro {
                    AvisoFrila(verbatim: erro, tom: .erro)
                        .accessibilityIdentifier("cadastro-erro")
                }

                BotaoPrimario("Continuar", carregando: viewModel.carregando) {
                    Task {
                        if let destino = await viewModel.criarConta() {
                            aoConcluir(destino)
                        }
                    }
                }
                .disabled(!viewModel.formularioPreenchido || viewModel.carregando)
                .accessibilityIdentifier("cadastro-continuar")

                Spacer(minLength: 40)
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(FrilaCor.fundo.ignoresSafeArea())
    }

    @ViewBuilder
    private func cartaoPerfil(
        perfil: PerfilConta,
        titulo: String,
        descricao: String,
        identificador: String
    ) -> some View {
        let selecionado = viewModel.perfil == perfil
        Button {
            viewModel.perfil = perfil
        } label: {
            HStack(alignment: .top, spacing: FrilaEspaco.pequeno) {
                VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                    Text(verbatim: titulo)
                        .font(FrilaTipo.resumo)
                        .foregroundStyle(FrilaCor.texto)

                    Text(verbatim: descricao)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
                Spacer(minLength: FrilaEspaco.minimo)
                if selecionado {
                    Image(systemName: "checkmark.circle.fill")
                        .font(FrilaTipo.subtituloDaTela)
                        .foregroundStyle(FrilaCor.primaria)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FrilaEspaco.medio)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous)
                    .strokeBorder(selecionado ? FrilaCor.primaria : FrilaCor.divisoria, lineWidth: selecionado ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: titulo))
        .accessibilityValue(selecionado ? String(localized: "Selecionado", bundle: bundleApresentacao) : String(localized: "Não selecionado", bundle: bundleApresentacao))
        .accessibilityAddTraits(selecionado ? [.isSelected] : [])
        .accessibilityIdentifier(identificador)
    }
}
