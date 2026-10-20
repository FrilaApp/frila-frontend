import FrilaDominio
import SwiftUI

/// Confirmação do código de 6 dígitos (#13), no quadro "Codigo" do MidFi do Fabrício:
/// retorno nativo, seis caixas com borda neutra e o CTA fixo de entrar.
public struct TelaCodigo: View {
    @Bindable var viewModel: CodigoViewModel
    var aoVoltar: () -> Void
    var aoConcluir: (DestinoCodigo) -> Void
    @FocusState private var campoFocado: Bool

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
                        // Bloco do título e subtítulo com respiro enxuto
                        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                            Text("Digite o código", bundle: bundleApresentacao)
                                .font(FrilaTipo.tituloGrande)
                                .foregroundStyle(FrilaCor.texto)
                                .accessibilityAddTraits(.isHeader)

                            (Text("Enviamos um código para", bundle: bundleApresentacao).font(FrilaTipo.corpo).foregroundStyle(FrilaCor.textoSecundario)
                             + Text(verbatim: " ")
                             + Text(verbatim: viewModel.email).font(FrilaTipo.corpo.weight(.semibold)).foregroundStyle(FrilaCor.texto)
                             + Text(verbatim: ".").font(FrilaTipo.corpo).foregroundStyle(FrilaCor.textoSecundario))
                            .fixedSize(horizontal: false, vertical: true)

                            Button(action: aoVoltar) {
                                Text("Trocar e-mail", bundle: bundleApresentacao)
                                    .font(FrilaTipo.corpo.weight(.semibold))
                                    .foregroundStyle(FrilaCor.texto)
                                    .frame(minHeight: FrilaMetrica.alvoMinimo)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }

                        // Seis caixas de código
                        caixasDeCodigo
                            .padding(.top, FrilaEspaco.compacto)

                        // Erro neutro da API / verificação
                        if let erro = viewModel.erro {
                            AvisoFrila(verbatim: erro, tom: .alerta)
                                .accessibilityIdentifier("codigo-erro")
                                .padding(.top, FrilaEspaco.compacto)
                        }

                        // Reenvio (logo abaixo das caixas ou erro)
                        blocoReenvio
                            .id("bloco-reenvio")
                            .padding(.top, FrilaEspaco.compacto)

                        // Mensagem informativa do reenvio
                        if let info = viewModel.mensagemInformativa {
                            blocoInformativo(info)
                                .padding(.top, FrilaEspaco.compacto)
                        }

                        // Contexto da conta
                        Text("Quem já tem conta entra do mesmo jeito. Cada e-mail é uma conta.", bundle: bundleApresentacao)
                            .font(FrilaTipo.nota)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, FrilaEspaco.compacto)
                    }
                    .padding(.top, FrilaEspaco.pequeno)
                    .padding(.horizontal, FrilaEspaco.medio)
                    .padding(.bottom, FrilaEspaco.enorme * 3)
                    .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(FrilaCor.fundo.ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: aoVoltar) {
                            Image(systemName: "chevron.left")
                                .foregroundStyle(FrilaCor.texto)
                        }
                        .accessibilityLabel(Text("Voltar", bundle: bundleApresentacao))
                        .accessibilityIdentifier("codigo-voltar")
                    }
                }
                .navigationBarBackButtonHidden(true)
                .barraInferiorFixa {
                    botaoEntrar
                }
                .onAppear {
                    campoFocado = true
                    #if DEBUG
                    aplicarEstadoCapturaSeNecessario(proxy: proxy)
                    #endif
                }
                .onChange(of: viewModel.erro) { _, novoErro in
                    if novoErro != nil {
                        codigoComErro = viewModel.codigo
                        Task { @MainActor in
                            await Task.yield()
                            proxy.scrollTo("bloco-reenvio", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .onChange(of: viewModel.codigo) { _, novoCodigo in
            if codigoComErro != nil && novoCodigo != codigoComErro {
                codigoComErro = nil
            }
            #if DEBUG
            if deveBloquearEnvioAutomaticoEmCaptura {
                return
            }
            #endif
            if novoCodigo.count == 6 && viewModel.codigoValido {
                confirmar()
            }
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
            .frame(maxWidth: .infinity, minHeight: 60)
            .accessibilityLabel(Text("Código de acesso", bundle: bundleApresentacao))
            .accessibilityValue(viewModel.textoAcessibilidadeCodigo)
            .accessibilityHint(Text("Digite os seis números enviados para seu e-mail", bundle: bundleApresentacao))
            .accessibilityIdentifier("codigo-campo")

            // 6 caixas visuais
            HStack(spacing: FrilaEspaco.pequeno) {
                ForEach(0..<6, id: \.self) { indice in
                    let caractere = caractereNoIndice(indice)
                    let estaAtiva = campoFocado && indice == viewModel.codigo.count
                    let bordaCor = temErroNoCodigo ? FrilaCor.texto : (estaAtiva ? FrilaCor.texto : FrilaCor.borda)
                    let bordaLargura: CGFloat = (temErroNoCodigo || estaAtiva) ? 2 : 1

                    Text(verbatim: caractere)
                        .font(FrilaTipo.secao.monospacedDigit())
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                        .foregroundStyle(FrilaCor.texto)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous)
                                .strokeBorder(bordaCor, lineWidth: bordaLargura)
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
    }

    private var textoContagemReenvio: String {
        let minutos = viewModel.segundosRestantes / 60
        let segundos = viewModel.segundosRestantes % 60
        return String(format: "%d:%02d", minutos, segundos)
    }

    @ViewBuilder
    private var blocoReenvio: some View {
        if viewModel.segundosRestantes > 0 {
            HStack {
                Text("Reenviar código em \(textoContagemReenvio)", bundle: bundleApresentacao)
                    .font(FrilaTipo.meta.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                    .accessibilityIdentifier("codigo-reenviar-aguarde")
                Spacer()
            }
        } else {
            Button(action: {
                Task { await viewModel.reenviarCodigo() }
            }) {
                HStack(spacing: FrilaEspaco.pequeno) {
                    if viewModel.carregando {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("Reenviar código", bundle: bundleApresentacao)
                        .font(FrilaTipo.corpo.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)
                }
                .frame(minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.carregando)
            .accessibilityIdentifier("codigo-reenviar")
        }
    }

    private func blocoInformativo(_ info: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.compacto) {
            Image(systemName: "checkmark")
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityHidden(true)

            Text(verbatim: info)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.texto)
        }
        .padding(FrilaEspaco.medio)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FrilaCor.controle, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
        .accessibilityIdentifier("codigo-info")
    }

    private var botaoEntrar: some View {
        VStack(spacing: FrilaEspaco.minimo) {
            let habilitado = viewModel.codigoValido && !viewModel.carregando
            Button(action: confirmar) {
                Group {
                    if viewModel.carregando {
                        ProgressView()
                            .tint(habilitado ? FrilaCor.sobrePrimaria : FrilaCor.textoSecundario)
                    } else {
                        Text("Entrar", bundle: bundleApresentacao)
                            .font(FrilaTipo.botao)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, FrilaEspaco.grande)
                .padding(.vertical, FrilaEspaco.pequeno)
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(habilitado ? FrilaCor.sobrePrimaria : FrilaCor.textoSecundario)
                .background(habilitado ? FrilaCor.primaria : FrilaCor.controle, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.tatil)
            .disabled(!habilitado)
            .accessibilityIdentifier("codigo-entrar")
            .accessibilityLabel(Text("Entrar", bundle: bundleApresentacao))
            .accessibilityValue(viewModel.carregando ? Text("Carregando", bundle: bundleApresentacao) : Text(verbatim: ""))

            if !viewModel.codigoValido {
                Text("Digite os 6 números para entrar.", bundle: bundleApresentacao)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, FrilaEspaco.medio)
        .padding(.vertical, FrilaEspaco.compacto)
    }

    private func confirmar() {
        #if DEBUG
        if deveBloquearEnvioAutomaticoEmCaptura {
            return
        }
        #endif
        guard !viewModel.carregando, viewModel.codigoValido, !concluido else { return }
        Task {
            if let destino = await viewModel.confirmarCodigo() {
                guard !concluido else { return }
                concluido = true
                aoConcluir(destino)
            }
        }
    }

    private func caractereNoIndice(_ indice: Int) -> String {
        guard indice < viewModel.codigo.count else { return "" }
        let index = viewModel.codigo.index(viewModel.codigo.startIndex, offsetBy: indice)
        return String(viewModel.codigo[index])
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

    private func aplicarEstadoCapturaSeNecessario(proxy: ScrollViewProxy) {
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
            Task { @MainActor in
                await Task.yield()
                proxy.scrollTo("bloco-reenvio", anchor: .bottom)
            }
        case "expirado":
            viewModel.codigo = "123456"
            viewModel.segundosRestantes = 0
            viewModel.erro = String(localized: "Código expirado. Peça um novo código para continuar.", bundle: bundleApresentacao)
            codigoComErro = "123456"
            Task { @MainActor in
                await Task.yield()
                proxy.scrollTo("bloco-reenvio", anchor: .bottom)
            }
        case "sem-conexao", "sem-rede":
            viewModel.codigo = "123456"
            viewModel.erro = String(localized: "Sem conexão com a internet. Tente novamente.", bundle: bundleApresentacao)
            Task { @MainActor in
                await Task.yield()
                proxy.scrollTo("bloco-reenvio", anchor: .bottom)
            }
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
    @ViewBuilder
    func barraInferiorFixa<Content: View>(@ViewBuilder conteudo: () -> Content) -> some View {
        if #available(iOS 26, *) {
            safeAreaBar(edge: .bottom) {
                conteudo()
            }
        } else {
            safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(FrilaCor.divisoria)
                        .frame(height: 1)

                    conteudo()
                }
                .background(.regularMaterial)
            }
        }
    }
}
