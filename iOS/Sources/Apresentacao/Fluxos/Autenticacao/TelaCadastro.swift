import FrilaDominio
import SwiftUI

public struct TelaCadastro: View {
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
                            .font(.body.weight(.semibold))
                            .foregroundStyle(FrilaCor.texto)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Voltar")
                    .accessibilityIdentifier("cadastro-voltar")

                    Text("Cadastro", bundle: bundleApresentacao)
                        .font(.headline)
                        .foregroundStyle(FrilaCor.texto)

                    Spacer()
                }

                Text("Como você vai usar o Frila?", bundle: bundleApresentacao)
                    .font(.title2.bold())
                    .foregroundStyle(FrilaCor.texto)

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
                        titulo: String(localized: "Quero contratar para o meu negócio", bundle: bundleApresentacao),
                        descricao: String(localized: "Perfil de contratante: publique turnos e acompanhe quem vai trabalhar.", bundle: bundleApresentacao),
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
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)

                    CampoFrila("Como você quer ser chamado", texto: $viewModel.nome)
                        .textContentType(.name)
                        .accessibilityIdentifier("cadastro-nome")
                }

                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    Text("Telefone com WhatsApp", bundle: bundleApresentacao)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)

                    CampoFrila("(61) 9 0000-0000", texto: $viewModel.telefone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .accessibilityIdentifier("cadastro-telefone")

                    Text("A outra parte só vê o seu número depois que o turno é confirmado.", bundle: bundleApresentacao)
                        .font(.footnote)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }

                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    Text("Data de nascimento", bundle: bundleApresentacao)
                        .font(.subheadline.weight(.semibold))
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
                            .font(.title3)
                            .foregroundStyle(viewModel.maiorDeIdade ? FrilaCor.primaria : FrilaCor.textoSecundario)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Tenho 18 anos ou mais")
                    .accessibilityValue(viewModel.maiorDeIdade ? "Selecionado" : "Não selecionado")
                    .accessibilityAddTraits(viewModel.maiorDeIdade ? [.isSelected] : [])
                    .accessibilityIdentifier("cadastro-maior-de-idade")

                    Text("Tenho 18 anos ou mais", bundle: bundleApresentacao)
                        .font(.subheadline)
                        .foregroundStyle(FrilaCor.texto)
                        .onTapGesture { viewModel.maiorDeIdade.toggle() }
                }

                // Checkbox Termos de uso e Política de privacidade com links
                HStack(alignment: .top, spacing: FrilaEspaco.pequeno) {
                    Button {
                        viewModel.aceitouTermos.toggle()
                    } label: {
                        Image(systemName: viewModel.aceitouTermos ? "checkmark.square.fill" : "square")
                            .font(.title3)
                            .foregroundStyle(viewModel.aceitouTermos ? FrilaCor.primaria : FrilaCor.textoSecundario)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Li e aceito os Termos de uso e a Política de privacidade")
                    .accessibilityValue(viewModel.aceitouTermos ? "Selecionado" : "Não selecionado")
                    .accessibilityAddTraits(viewModel.aceitouTermos ? [.isSelected] : [])
                    .accessibilityIdentifier("cadastro-termos")

                    Text("Li e aceito os [Termos de uso](https://frila.app/termos) e a [Política de privacidade](https://frila.app/privacidade)", bundle: bundleApresentacao)
                        .font(.subheadline)
                        .foregroundStyle(FrilaCor.texto)
                        .padding(.top, 10)
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
        }
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
            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: titulo)
                    .font(.headline)
                    .foregroundStyle(FrilaCor.texto)

                Text(verbatim: descricao)
                    .font(.footnote)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FrilaEspaco.medio)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.medio))
            .overlay(
                RoundedRectangle(cornerRadius: FrilaRaio.medio)
                    .stroke(selecionado ? FrilaCor.primaria : FrilaCor.textoSecundario.opacity(0.35), lineWidth: selecionado ? 2 : 1)
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
