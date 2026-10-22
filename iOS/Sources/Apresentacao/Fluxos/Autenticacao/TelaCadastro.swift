import FrilaDominio
import SwiftUI

/// Cadastro (#12), nos quadros "Perfil" (escolha do perfil) e "Main" (campos) do MidFi do Fabrício: voltar circular, cartões de perfil e botão escuro de continuar.
public struct TelaCadastro: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
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
            ScrollViewReader { proxy in
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
                        .font(FrilaTipo.secao)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)
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
                            .accessibilityLabel(Text("Nome", bundle: bundleApresentacao))
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .accessibilityIdentifier("cadastro-nome")

                        if viewModel.campoComErro == .nome, let erro = viewModel.erro {
                            Text(verbatim: erro)
                                .font(FrilaTipo.nota)
                                .foregroundStyle(FrilaCor.perigo)
                                .accessibilityIdentifier("cadastro-erro-nome")
                        }
                    }
                    .id(CadastroViewModel.CampoCadastro.nome)

                    VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                        Text("Telefone com WhatsApp", bundle: bundleApresentacao)
                            .font(FrilaTipo.meta.weight(.semibold))
                            .foregroundStyle(FrilaCor.texto)

                        CampoMascara(
                            texto: $viewModel.telefone,
                            placeholder: String(localized: "(61) 9 0000-0000", bundle: bundleApresentacao),
                            rotuloAcessibilidade: String(localized: "Telefone com WhatsApp", bundle: bundleApresentacao),
                            identificadorAcessibilidade: "cadastro-telefone",
                            teclado: .phonePad,
                            tipoConteudo: .telephoneNumber,
                            formatar: CadastroViewModel.formatarTelefone
                        )
                        .caixaDoCampoFrila()
                        .accessibilityLabel(Text("Telefone com WhatsApp", bundle: bundleApresentacao))
                        .accessibilityIdentifier("cadastro-telefone")

                        if viewModel.campoComErro == .telefone, let erro = viewModel.erro {
                            Text(verbatim: erro)
                                .font(FrilaTipo.nota)
                                .foregroundStyle(FrilaCor.perigo)
                                .accessibilityIdentifier("cadastro-erro-telefone")
                        }

                        Text("A outra parte só vê o seu número depois que o turno é confirmado.", bundle: bundleApresentacao)
                            .font(FrilaTipo.nota)
                            .foregroundStyle(FrilaCor.textoSecundario)
                    }
                    .id(CadastroViewModel.CampoCadastro.telefone)

                    VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                        Text("Data de nascimento", bundle: bundleApresentacao)
                            .font(FrilaTipo.meta.weight(.semibold))
                            .foregroundStyle(FrilaCor.texto)

                        CampoMascara(
                            texto: $viewModel.nascimentoTexto,
                            placeholder: String(localized: "dd/mm/aaaa", bundle: bundleApresentacao),
                            rotuloAcessibilidade: String(localized: "Data de nascimento", bundle: bundleApresentacao),
                            identificadorAcessibilidade: "cadastro-nascimento",
                            teclado: .numberPad,
                            tipoConteudo: nil,
                            formatar: CadastroViewModel.formatarDataNascimento
                        )
                        .caixaDoCampoFrila()
                        .accessibilityLabel(Text("Data de nascimento", bundle: bundleApresentacao))
                        .accessibilityIdentifier("cadastro-nascimento")

                        if viewModel.ehMenorDeIdade {
                            Text("O Frila é exclusivo para maiores de 18 anos.", bundle: bundleApresentacao)
                                .font(FrilaTipo.nota)
                                .foregroundStyle(FrilaCor.perigo)
                                .accessibilityIdentifier("cadastro-menor-idade-erro")
                        } else if viewModel.campoComErro == .nascimento, let erro = viewModel.erro {
                            Text(verbatim: erro)
                                .font(FrilaTipo.nota)
                                .foregroundStyle(FrilaCor.perigo)
                                .accessibilityIdentifier("cadastro-erro-nascimento")
                        }
                    }
                    .id(CadastroViewModel.CampoCadastro.nascimento)

                    // Checkbox Termos de uso e Política de privacidade com links
                    VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
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
                            .accessibilityAddTraits(viewModel.aceitouTermos ? [.isSelected, .isButton] : [.isButton])
                            .accessibilityAction(named: Text("Termos de uso", bundle: bundleApresentacao)) {
                                openURL(EnderecosOficiais.padrao.termosDeUso)
                            }
                            .accessibilityAction(named: Text("Política de privacidade", bundle: bundleApresentacao)) {
                                openURL(EnderecosOficiais.padrao.politicaDePrivacidade)
                            }
                            .accessibilityIdentifier("cadastro-termos")

                            Text("Li e aceito os [Termos de uso](https://frila.netlify.app/termos) e a [Política de privacidade](https://frila.netlify.app/privacidade)", bundle: bundleApresentacao)
                                .font(FrilaTipo.meta)
                                .foregroundStyle(FrilaCor.texto)
                                .padding(.top, 10)
                                .accessibilityHidden(true)
                        }

                        if viewModel.campoComErro == .termos, let erro = viewModel.erro {
                            Text(verbatim: erro)
                                .font(FrilaTipo.nota)
                                .foregroundStyle(FrilaCor.perigo)
                                .accessibilityIdentifier("cadastro-erro-termos")
                        }
                    }
                    .id(CadastroViewModel.CampoCadastro.termos)

                    if let erro = viewModel.erro {
                        AvisoFrila(verbatim: erro, tom: .erro)
                            .accessibilityIdentifier("cadastro-erro")
                    }

                    BotaoPrimario("Continuar", carregando: viewModel.carregando) {
                        Task {
                            if let destino = await viewModel.criarConta() {
                                aoConcluir(destino)
                            } else if let campo = viewModel.campoComErro {
                                withAnimation(FrilaMovimento.animacao(reduzir: reduzirMovimento)) {
                                    proxy.scrollTo(campo, anchor: .center)
                                }
                            }
                        }
                    }
                    .disabled(viewModel.carregando || viewModel.ehMenorDeIdade)
                    .accessibilityIdentifier("cadastro-continuar")

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, FrilaEspaco.medio)
                .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
                .frame(maxWidth: .infinity)
            }
        }
        .onChange(of: viewModel.nome) { _, _ in
            if viewModel.campoComErro == .nome {
                viewModel.campoComErro = nil
                viewModel.erro = nil
            }
        }
        .onChange(of: viewModel.telefone) { _, _ in
            if viewModel.campoComErro == .telefone {
                viewModel.campoComErro = nil
                viewModel.erro = nil
            }
        }
        .onChange(of: viewModel.nascimentoTexto) { _, _ in
            if viewModel.campoComErro == .nascimento {
                viewModel.campoComErro = nil
                viewModel.erro = nil
            }
        }
        .onChange(of: viewModel.aceitouTermos) { _, _ in
            if viewModel.campoComErro == .termos {
                viewModel.campoComErro = nil
                viewModel.erro = nil
            }
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
            HStack(alignment: .top, spacing: FrilaEspaco.compacto) {
                Image(systemName: perfil == .profissional ? "person.fill" : "building.2.fill")
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.texto)
                    .frame(width: 40, height: 40)
                    .background(FrilaCor.controle, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                    Text(verbatim: titulo)
                        .font(FrilaTipo.resumo)
                        .foregroundStyle(FrilaCor.texto)

                    Text(verbatim: descricao)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: FrilaEspaco.minimo)
                Image(systemName: selecionado ? "checkmark.circle.fill" : "circle")
                    .font(FrilaTipo.subtituloDaTela)
                    .foregroundStyle(selecionado ? FrilaCor.primaria : FrilaCor.borda)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FrilaEspaco.medio)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous)
                    .strokeBorder(selecionado ? FrilaCor.primaria : FrilaCor.divisoria, lineWidth: selecionado ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: titulo))
        .accessibilityValue(selecionado ? String(localized: "Selecionado", bundle: bundleApresentacao) : String(localized: "Não selecionado", bundle: bundleApresentacao))
        .accessibilityAddTraits(selecionado ? [.isSelected] : [])
        .accessibilityIdentifier(identificador)
    }
}
