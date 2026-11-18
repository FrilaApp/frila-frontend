import FrilaDominio
import SwiftUI

/// Cadastro (#12): a escolha do lado em lista com check, os campos com o rótulo acima, o aceite dos Termos e, ancorado
/// embaixo, o botão "Continuar". O Fabrício não desenhou esta tela (T6c é só o nome): extrapolada do sistema da entrada.
///
/// Não tem botão Voltar: o código de entrada já foi usado e não vale de novo.
/// O fluxo troca de rota por `switch`, então também não existe gesto de voltar pela borda.
public struct TelaCadastro: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @FocusState private var focoNoNome: Bool
    @Environment(\.dynamicTypeSize) private var tamanhoDoTexto
    @State private var telefoneEmEdicao = false
    @State private var nascimentoEmEdicao = false
    @Bindable var viewModel: CadastroViewModel
    var aoConcluir: (DestinoAposEntrada) -> Void

    public init(
        viewModel: CadastroViewModel,
        aoConcluir: @escaping (DestinoAposEntrada) -> Void
    ) {
        self.viewModel = viewModel
        self.aoConcluir = aoConcluir
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                    cabecalho
                    escolhaDoPerfil
                    camposDeDados
                    aceiteDosTermos

                    // Com texto grande, o botão vai para o fim do conteúdo: ancorado, cobriria os campos.
                    if tamanhoDoTexto.isAccessibilitySize {
                        VStack(spacing: FrilaEspaco.item) { acaoDeContinuar(proxy) }
                    }
                }
                .padding(.top, FrilaEspaco.item)
                .padding(.horizontal, FrilaEspaco.grupo)
                .padding(.bottom, FrilaEspaco.secao)
                .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(FrilaCor.fundo.ignoresSafeArea())
            .fundoSobORelogio()
            .rodapeAncoradoQuando(!tamanhoDoTexto.isAccessibilitySize) { acaoDeContinuar(proxy) }
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
        .frilaKeyboardDismissScope()
    }

    /// A mensagem do erro e o botão, juntos: ancorados embaixo, ou no fim do conteúdo com texto grande.
    @ViewBuilder
    private func acaoDeContinuar(_ proxy: ScrollViewProxy) -> some View {
        if let erro = viewModel.erro {
            MensagemJuntoAoBotao(verbatim: erro)
                .accessibilityIdentifier("cadastro-erro")
        }

        BotaoPrimario("Continuar", carregando: viewModel.carregando) {
            continuar(rolandoCom: proxy)
        }
        .disabled(viewModel.carregando || viewModel.ehMenorDeIdade)
        .accessibilityIdentifier("cadastro-continuar")
    }

    /// Cria a conta; se um campo falhou, leva a tela até ele.
    private func continuar(rolandoCom proxy: ScrollViewProxy) {
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

    // MARK: - Partes da tela

    /// "Cadastro" fica como legenda do título: é o nome da etapa, e o título é a pergunta.
    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text("Cadastro", bundle: bundleApresentacao)
                .font(FrilaTipo.rotuloDeGrupo)
                .foregroundStyle(FrilaCor.textoSecundario)

            Text("Como você quer usar o Frila?", bundle: bundleApresentacao)
                .font(FrilaTipo.tituloDaTela)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// Escolha única: duas linhas num grupo, com o check em tinta na marcada. Sem laranja e sem cartão de borda grossa.
    private var escolhaDoPerfil: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            FrilaGrupoDeLinhas {
                linhaDePerfil(
                    perfil: .profissional,
                    icone: "person.fill",
                    titulo: String(localized: "Quero trabalhar em turnos", bundle: bundleApresentacao),
                    descricao: String(localized: "Perfil de profissional: receba vagas perto de você e candidate-se sem formulário.", bundle: bundleApresentacao),
                    identificador: "cadastro-perfil-profissional"
                )
                linhaDePerfil(
                    perfil: .contratante,
                    icone: "building.2.fill",
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
        }
    }

    private var camposDeDados: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                rotuloDoCampo("Nome")

                CampoFrila("Como você quer ser chamado", texto: $viewModel.nome, emFoco: focoNoNome)
                    .accessibilityLabel(Text("Nome", bundle: bundleApresentacao))
                    .focused($focoNoNome)
                    .frilaFormField(id: "cadastro-nome", isFocused: focoNoNome, onDismiss: { focoNoNome = false })
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("cadastro-nome")

                if viewModel.campoComErro == .nome, let erro = viewModel.erro {
                    textoDeErroDoCampo(erro, identificador: "cadastro-erro-nome")
                }
            }
            .id(CadastroViewModel.CampoCadastro.nome)

            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                rotuloDoCampo("Telefone com WhatsApp")

                CampoMascara(
                    texto: $viewModel.telefone,
                    placeholder: String(localized: "(61) 9 0000-0000", bundle: bundleApresentacao),
                    rotuloAcessibilidade: String(localized: "Telefone com WhatsApp", bundle: bundleApresentacao),
                    identificadorAcessibilidade: "cadastro-telefone",
                    teclado: .phonePad,
                    tipoConteudo: .telephoneNumber,
                    emEdicao: $telefoneEmEdicao,
                    formatar: CadastroViewModel.formatarTelefone
                )
                .caixaDoCampoFrila(emFoco: telefoneEmEdicao)
                .accessibilityLabel(Text("Telefone com WhatsApp", bundle: bundleApresentacao))
                .frilaFormField(id: "cadastro-telefone", isFocused: telefoneEmEdicao, onDismiss: { telefoneEmEdicao = false })
                .accessibilityIdentifier("cadastro-telefone")

                if viewModel.campoComErro == .telefone, let erro = viewModel.erro {
                    textoDeErroDoCampo(erro, identificador: "cadastro-erro-telefone")
                }

                Text("A outra parte só vê o seu número depois que o turno é confirmado.", bundle: bundleApresentacao)
                    .font(FrilaTipo.legenda)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .id(CadastroViewModel.CampoCadastro.telefone)

            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                rotuloDoCampo("Data de nascimento")

                CampoMascara(
                    texto: $viewModel.nascimentoTexto,
                    placeholder: String(localized: "dd/mm/aaaa", bundle: bundleApresentacao),
                    rotuloAcessibilidade: String(localized: "Data de nascimento", bundle: bundleApresentacao),
                    identificadorAcessibilidade: "cadastro-nascimento",
                    teclado: .numberPad,
                    tipoConteudo: nil,
                    emEdicao: $nascimentoEmEdicao,
                    formatar: CadastroViewModel.formatarDataNascimento
                )
                .caixaDoCampoFrila(emFoco: nascimentoEmEdicao)
                .accessibilityLabel(Text("Data de nascimento", bundle: bundleApresentacao))
                .frilaFormField(id: "cadastro-nascimento", isFocused: nascimentoEmEdicao, onDismiss: { nascimentoEmEdicao = false })
                .accessibilityIdentifier("cadastro-nascimento")

                if viewModel.ehMenorDeIdade {
                    textoDeErroDoCampo(
                        String(localized: "O Frila é exclusivo para maiores de 18 anos.", bundle: bundleApresentacao),
                        identificador: "cadastro-menor-idade-erro"
                    )
                } else if viewModel.campoComErro == .nascimento, let erro = viewModel.erro {
                    textoDeErroDoCampo(erro, identificador: "cadastro-erro-nascimento")
                } else {
                    // A maioridade (18+) é conferida só por esta data, sem caixa de autodeclaração (decisão A5 da PO).
                    Text("Conferimos sua idade pela data de nascimento. O Frila é só para maiores de 18 anos.", bundle: bundleApresentacao)
                        .font(FrilaTipo.legenda)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("cadastro-nascimento-ajuda")
                }
            }
            .id(CadastroViewModel.CampoCadastro.nascimento)
        }
    }

    /// O aceite dos Termos e da Política: a caixa (alvo de 48 pt) e o texto com os dois links. O erro vai em tinta,
    /// junto da caixa.
    private var aceiteDosTermos: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
            HStack(alignment: .top, spacing: FrilaEspaco.item) {
                Button {
                    viewModel.aceitouTermos.toggle()
                } label: {
                    Image(systemName: viewModel.aceitouTermos ? "checkmark.square.fill" : "square")
                        .font(.title2)
                        .foregroundStyle(viewModel.aceitouTermos ? FrilaCor.texto : FrilaCor.textoSecundario)
                        .frame(width: FrilaMetrica.alvo, height: FrilaMetrica.alvo)
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

                Text("Li e aceito os [Termos de uso](https://frilabr.com/termos) e a [Política de privacidade](https://frilabr.com/privacidade)", bundle: bundleApresentacao)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .tint(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, FrilaEspaco.item)
                    .accessibilityHidden(true)
            }

            if viewModel.campoComErro == .termos, let erro = viewModel.erro {
                textoDeErroDoCampo(erro, identificador: "cadastro-erro-termos")
            }
        }
        .id(CadastroViewModel.CampoCadastro.termos)
    }

    /// O rótulo visível acima do campo é da tela; o título do `CampoFrila` é a dica dentro dele.
    private func rotuloDoCampo(_ chave: LocalizedStringKey) -> some View {
        Text(chave, bundle: bundleApresentacao)
            .font(FrilaTipo.rotuloDeGrupo)
            .foregroundStyle(FrilaCor.textoSecundario)
    }

    /// O que falta no campo, junto dele, em tinta: problema não tem cor.
    private func textoDeErroDoCampo(_ erro: String, identificador: String) -> some View {
        Text(verbatim: erro)
            .font(FrilaTipo.apoio)
            .foregroundStyle(FrilaCor.texto)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(identificador)
    }

    private func linhaDePerfil(
        perfil: PerfilConta,
        icone: String,
        titulo: String,
        descricao: String,
        identificador: String
    ) -> some View {
        let selecionado = viewModel.perfil == perfil
        return FrilaLinhaDeOpcao(
            icone: icone,
            titulo: titulo,
            subtitulo: descricao,
            remate: .marcada(selecionado)
        ) {
            viewModel.perfil = perfil
        }
        .accessibilityLabel(Text(verbatim: "\(titulo). \(descricao)"))
        .accessibilityValue(selecionado ? String(localized: "Selecionado", bundle: bundleApresentacao) : String(localized: "Não selecionado", bundle: bundleApresentacao))
        .accessibilityIdentifier(identificador)
    }
}

private extension View {
    /// O rodapé ancorado só quando cabe: com texto grande a ação vai para o fim do conteúdo.
    @ViewBuilder
    func rodapeAncoradoQuando<Conteudo: View>(_ ativo: Bool, @ViewBuilder _ conteudo: () -> Conteudo) -> some View {
        if ativo {
            rodapeAncorado(conteudo)
        } else {
            self
        }
    }
}
