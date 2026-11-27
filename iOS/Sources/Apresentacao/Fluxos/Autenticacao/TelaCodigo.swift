import FrilaDominio
import SwiftUI

/// Confirmação do código (#13, T6b do redesign): título, as seis caixas, o Colar do sistema, o reenvio e, ancorados
/// embaixo, a mensagem do envio e o botão "Entrar". Sem a ilustração do Fabrício (precisaria de asset novo).
public struct TelaCodigo: View {
    @Bindable var viewModel: CodigoViewModel
    var aoVoltar: () -> Void
    var aoConcluir: (DestinoCodigo) -> Void
    @FocusState private var campoFocado: Bool
    @Environment(\.dynamicTypeSize) private var tamanhoDoTexto

    /// 56 pt: o passo da grade de 8 acima do campo de 48, para o dígito em `.title2` respirar.
    private static let alturaDaCaixa: CGFloat = 56
    /// O Colar do sistema cresce por escala (1,85 dá o alvo de 48 pt); o quadro reserva o lugar dele.
    private static let escalaDoColar: CGFloat = 1.85
    @ScaledMetric(relativeTo: .body) private var alturaDoBotaoColar: CGFloat = 26 * 1.85
    @State private var concluido = false
    @State private var codigoComErro: String?

    public init(
        viewModel: CodigoViewModel,
        aoVoltar: @escaping () -> Void,
        aoConcluir: @escaping (DestinoCodigo) -> Void
    ) {
        self.viewModel = viewModel
        self.aoVoltar = aoVoltar
        self.aoConcluir = aoConcluir
    }

    public var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        cabecalho

                        // Rótulo do campo Código
                        Text("Código de acesso", bundle: bundleApresentacao)
                            .font(FrilaTipo.rotuloDeGrupo)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .padding(.top, FrilaEspaco.grupo)

                        // Seis caixas de código
                        caixasDeCodigo
                            .padding(.top, FrilaEspaco.item)
                            .id(Self.idDasCaixas)

                        botaoColar
                            .padding(.top, FrilaEspaco.bloco)

                        // Reenvio (logo abaixo das caixas)
                        blocoReenvio
                            .padding(.top, FrilaEspaco.grupo)

                        if !DemonstracaoContas.ehEmailDeDemonstracao(viewModel.email) {
                            Toggle(isOn: $viewModel.lembrarDispositivo) {
                                Text("Lembrar este dispositivo por 30 dias", bundle: bundleApresentacao)
                                    .font(FrilaTipo.corpo)
                                    .foregroundStyle(FrilaCor.texto)
                            }
                            .tint(FrilaCor.texto)
                            .frame(minHeight: FrilaMetrica.alvo)
                            .disabled(viewModel.carregando)
                            .accessibilityIdentifier("codigo-lembrar-dispositivo")
                            .accessibilityHint(Text("Se marcado, não pediremos um código neste aparelho pelos próximos 30 dias.", bundle: bundleApresentacao))
                            .padding(.top, FrilaEspaco.bloco)
                        }

                        // Contexto da conta
                        Text("Quem já tem conta entra do mesmo jeito. Cada e-mail é uma conta.", bundle: bundleApresentacao)
                            .font(FrilaTipo.legenda)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, FrilaEspaco.bloco)

                        // Com texto grande, o botão vai para o fim do conteúdo: ancorado, cobriria as caixas.
                        if tamanhoDoTexto.isAccessibilitySize {
                            VStack(spacing: FrilaEspaco.item) {
                                if !temResultado { oQueFaltaParaEntrar }
                                botaoEntrar
                            }
                            .padding(.top, FrilaEspaco.grupo)
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
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button {
                            campoFocado = false
                        } label: {
                            Text("OK", bundle: bundleApresentacao)
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: aoVoltar) {
                            Image(systemName: "chevron.left")
                                .foregroundStyle(FrilaCor.texto)
                                .frame(minWidth: FrilaMetrica.alvo, minHeight: FrilaMetrica.alvo)
                        }
                        .accessibilityLabel(Text("Voltar", bundle: bundleApresentacao))
                        .accessibilityIdentifier("codigo-voltar")
                    }
                }
                .navigationBarBackButtonHidden(true)
                // O erro, o aviso da colagem e o resultado do reenvio ficam junto do botão; sem nenhum deles, enquanto
                // faltam números, o que falta para entrar.
                .rodapeAncoradoQuando(!tamanhoDoTexto.isAccessibilitySize) { rodape }
                // Com texto grande o botão sai do rodapé ancorado e vai para o fim da rolagem, atrás do teclado; o
                // resultado não pode ir junto. Fica preso no alto da tela, fora da rolagem: à vista com o teclado aberto,
                // em qualquer posição da rolagem, e com as caixas livres para a pessoa digitar de novo.
                .safeAreaInset(edge: .top, spacing: 0) {
                    if tamanhoDoTexto.isAccessibilitySize, temResultado {
                        mensagemDoResultado
                            // A mensagem presa no alto empurra o conteúdo para baixo: as caixas voltam para cima do teclado.
                            .task(id: viewModel.erro) { await manterAsCaixasNaTela(proxy) }
                            .padding(.horizontal, FrilaEspaco.grupo)
                            .padding(.vertical, FrilaEspaco.item)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(FrilaCor.fundo)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(FrilaCor.divisoria).frame(height: 1).accessibilityHidden(true)
                            }
                    }
                }
                .onAppear {
                    campoFocado = true
                    #if DEBUG
                    aplicarEstadoCapturaSeNecessario()
                    #endif
                }
                .onChange(of: viewModel.erro) { _, novoErro in
                    if novoErro != nil {
                        codigoComErro = viewModel.codigo
                    }
                }
            }
        }
        .frilaKeyboardDismissScope()
        .onChange(of: viewModel.codigo) { _, novoCodigo in
            viewModel.avisoDeColagem = nil
            if codigoComErro != nil && novoCodigo != codigoComErro {
                codigoComErro = nil
            }
            #if DEBUG
            if deveBloquearEnvioAutomaticoEmCaptura {
                return
            }
            #endif
            if novoCodigo.count == 6 && viewModel.codigoValido && novoCodigo != codigoComErro {
                confirmar()
            }
        }
    }

    /// T6b: o título, para onde o código foi e o caminho de volta para trocar o e-mail.
    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            if case .loginDispositivo = viewModel.modo {
                Text("Confirme este dispositivo", bundle: bundleApresentacao)
                    .font(FrilaTipo.tituloDaTela)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(String(format: String(localized: "Enviamos um código de 6 dígitos para %@ para confirmar este dispositivo.", bundle: bundleApresentacao), viewModel.email))
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Confira seu e-mail", bundle: bundleApresentacao)
                    .font(FrilaTipo.tituloDaTela)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(String(format: String(localized: "Digite o código de 6 dígitos enviado para %@.", bundle: bundleApresentacao), viewModel.email))
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: aoVoltar) {
                Text("Trocar e-mail", bundle: bundleApresentacao)
            }
            .buttonStyle(.frilaLink)
        }
    }

    private var temErroNoCodigo: Bool {
        codigoComErro != nil && codigoComErro == viewModel.codigo && viewModel.erro != nil
    }

    private var caixasDeCodigo: some View {
        ZStack {
            // Campo invisível para captura de teclado e colagem
            TextField(text: $viewModel.codigo, prompt: Text("Código de acesso", bundle: bundleApresentacao)) {
                Text("Código de acesso", bundle: bundleApresentacao)
            }
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($campoFocado)
            .opacity(0.01)
            .frame(maxWidth: .infinity, minHeight: Self.alturaDaCaixa)
            .accessibilityLabel(Text("Código de acesso", bundle: bundleApresentacao))
            .accessibilityValue(viewModel.textoAcessibilidadeCodigo)
            .accessibilityHint(Text("Digite os seis números enviados para seu e-mail", bundle: bundleApresentacao))
            .accessibilityIdentifier("codigo-campo")

            // Seis caixas de código: a da vez tem o contorno de 2 pt em tinta, como o foco dos campos; com erro, todas.
            HStack(spacing: FrilaEspaco.item) {
                ForEach(0..<6, id: \.self) { indice in
                    let caractere = caractereNoIndice(indice)
                    let estaAtiva = campoFocado && indice == viewModel.codigo.count
                    let destacada = temErroNoCodigo || estaAtiva

                    Text(verbatim: caractere)
                        .font(Font.title2.weight(.semibold).monospacedDigit())
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                        .foregroundStyle(FrilaCor.texto)
                        .frame(maxWidth: .infinity, minHeight: Self.alturaDaCaixa)
                        .background(FrilaCor.superficieDoCampo, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                                .strokeBorder(destacada ? FrilaCor.texto : FrilaCor.bordaDoCampo, lineWidth: destacada ? 2 : 1)
                        )
                        .accessibilityHidden(true)
                }
            }
            .accessibilityHidden(true)
            .contentShape(Rectangle())
            .onTapGesture {
                campoFocado = true
            }
        }
        .frilaFormField(id: "codigo-acesso", isFocused: campoFocado, onDismiss: { campoFocado = false })
    }

    /// Controle nativo: cola sem o aviso "Permitir colar" e sem ler a área de transferência por baixo dos panos.
    /// O sistema só aceita tinta, forma e rótulo; o tamanho vem da escala, a partir da borda esquerda, e o quadro reserva
    /// o lugar dele (valor padrão da chave "Tamanho do Colar" do Laboratório do Fabrício: alvo, 1,85). Com texto grande
    /// ele fica no tamanho do sistema, que já passa do alvo.
    private var botaoColar: some View {
        PasteButton(payloadType: String.self) { textos in
            viewModel.colar(textos)
        }
        .labelStyle(.titleAndIcon)
        .buttonBorderShape(.capsule)
        .tint(FrilaCor.texto)
        // Com texto grande o próprio controle já cresce (e passa dos 48 pt): sem a escala extra, ele cabe na largura.
        .scaleEffect(tamanhoDoTexto.isAccessibilitySize ? 1 : Self.escalaDoColar, anchor: .leading)
        .frame(height: tamanhoDoTexto.isAccessibilitySize ? nil : alturaDoBotaoColar, alignment: .leading)
        .accessibilityLabel(Text("Colar código", bundle: bundleApresentacao))
        .accessibilityIdentifier("codigo-colar")
    }

    private func caractereNoIndice(_ indice: Int) -> String {
        guard indice < viewModel.codigo.count else { return "" }
        let index = viewModel.codigo.index(viewModel.codigo.startIndex, offsetBy: indice)
        return String(viewModel.codigo[index])
    }

    private var textoContagemReenvio: String {
        let minutos = viewModel.segundosRestantes / 60
        let segundos = viewModel.segundosRestantes % 60
        return String(format: "%d:%02d", minutos, segundos)
    }

    @ViewBuilder
    private var blocoReenvio: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
            Text("Não chegou? Veja a caixa de spam.", bundle: bundleApresentacao)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)

            if viewModel.atingiuLimiteReenvios {
                Text("Limite de reenvios atingido. Tente entrar novamente mais tarde.", bundle: bundleApresentacao)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(minHeight: FrilaMetrica.alvo, alignment: .leading)
                    .accessibilityIdentifier("codigo-reenviar-limite")
            } else if viewModel.segundosRestantes > 0 {
                Text("Reenviar código em \(textoContagemReenvio)", bundle: bundleApresentacao)
                    .font(FrilaTipo.corpo)
                    .monospacedDigit()
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(minHeight: FrilaMetrica.alvo, alignment: .leading)
                    .accessibilityIdentifier("codigo-reenviar-aguarde")
            } else {
                Button(action: reenviar) {
                    Text("Reenviar código", bundle: bundleApresentacao)
                }
                .buttonStyle(.frilaLink)
                .disabled(viewModel.carregando)
                .accessibilityIdentifier("codigo-reenviar")
            }
        }
    }

    /// Junto do botão: o resultado da última ação; sem nenhum, enquanto faltam números, o que falta para entrar.
    /// É o rodapé ancorado do tamanho padrão. Com texto grande as partes vão para o conteúdo (ver `body`).
    @ViewBuilder
    private var rodape: some View {
        if temResultado { mensagemDoResultado } else { oQueFaltaParaEntrar }
        botaoEntrar
    }

    private var temResultado: Bool {
        viewModel.erro != nil || viewModel.avisoDeColagem != nil || viewModel.mensagemInformativa != nil
    }

    /// O erro, o aviso da colagem ou o resultado do reenvio: um só, nessa ordem.
    @ViewBuilder
    private var mensagemDoResultado: some View {
        if let erro = viewModel.erro {
            MensagemJuntoAoBotao(verbatim: erro)
                .accessibilityLabel(Text(verbatim: AvisoFrila.rotuloAcessibilidade(texto: erro, tom: .alerta)))
                .accessibilityIdentifier("codigo-erro")
        } else if let aviso = viewModel.avisoDeColagem {
            MensagemJuntoAoBotao(verbatim: aviso)
                .accessibilityIdentifier("codigo-colar-aviso")
        } else if let info = viewModel.mensagemInformativa {
            MensagemJuntoAoBotao(verbatim: info)
                .accessibilityIdentifier("codigo-info")
        }
    }

    @ViewBuilder
    private var oQueFaltaParaEntrar: some View {
        if !viewModel.codigoValido {
            Text("Digite os 6 números para entrar.", bundle: bundleApresentacao)
                .font(FrilaTipo.legenda)
                .foregroundStyle(FrilaCor.textoSecundario)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var botaoEntrar: some View {
        BotaoPrimario("Entrar", carregando: viewModel.carregando, acao: confirmar)
            .disabled(!viewModel.codigoValido || viewModel.carregando || viewModel.codigo == codigoComErro)
            .accessibilityIdentifier("codigo-entrar")
    }

    private static let idDasCaixas = "caixas-do-codigo"

    @MainActor
    private func manterAsCaixasNaTela(_ proxy: ScrollViewProxy) async {
        guard campoFocado else { return }
        // Um instante para a tela assentar com a mensagem já presa no alto.
        try? await Task.sleep(for: .milliseconds(150))
        guard !Task.isCancelled else { return }
        proxy.scrollTo(Self.idDasCaixas, anchor: .bottom)
    }

    private func reenviar() {
        Task {
            await viewModel.reenviarCodigo()
            if let anuncio = viewModel.anuncioDoReenvio {
                UIAccessibility.post(notification: .announcement, argument: anuncio)
            }
        }
    }

    private func confirmar() {
        #if DEBUG
        if deveBloquearEnvioAutomaticoEmCaptura {
            return
        }
        #endif
        guard !viewModel.carregando, viewModel.codigoValido, viewModel.codigo != codigoComErro, !concluido else { return }
        Task {
            if let destino = await viewModel.confirmarCodigo() {
                guard !concluido else { return }
                concluido = true
                aoConcluir(destino)
            }
        }
    }

    #if DEBUG
    private var deveBloquearEnvioAutomaticoEmCaptura: Bool {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-FRILA_CAPTURA"), idx + 1 < args.count {
            let est = args[idx + 1]
            return ["erro", "expirado", "sem-conexao", "sem-rede"].contains(est)
        }
        return false
    }

    private func aplicarEstadoCapturaSeNecessario() {
        guard let indice = ProcessInfo.processInfo.arguments.firstIndex(of: "-FRILA_CAPTURA"),
              indice + 1 < ProcessInfo.processInfo.arguments.count else { return }
        let estado = ProcessInfo.processInfo.arguments[indice + 1]
        switch estado {
        case "normal":
            break
        case "erro":
            viewModel.codigo = "123456"
            viewModel.erro = String(localized: "Código incorreto. Confira os números e tente novamente.", bundle: bundleApresentacao)
            codigoComErro = "123456"
        case "expirado":
            viewModel.codigo = "123456"
            viewModel.segundosRestantes = 0
            viewModel.erro = String(localized: "Código expirado. Peça um novo código para continuar.", bundle: bundleApresentacao)
            codigoComErro = "123456"
        case "sem-conexao", "sem-rede":
            viewModel.codigo = "123456"
            viewModel.erro = String(localized: "Sem conexão com a internet. Tente novamente.", bundle: bundleApresentacao)
        case "reenvio":
            viewModel.segundosRestantes = 0
        case "info":
            viewModel.mensagemInformativa = String(localized: "Novo código enviado para seu e-mail.", bundle: bundleApresentacao)
        case "sem-teclado":
            campoFocado = false
        default:
            break
        }
    }
    #endif
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
