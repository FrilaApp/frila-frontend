import FrilaDominio
import SwiftUI

/// Confirmação do código de 6 dígitos (#13), no quadro "Codigo" do MidFi do Fabrício: voltar circular, seis caixas e o botão escuro de confirmar.
public struct TelaCodigo: View {
    @Bindable var viewModel: CodigoViewModel
    var aoVoltar: () -> Void
    var aoConcluir: (DestinoCodigo) -> Void
    @FocusState private var campoFocado: Bool

    @State private var concluido = false

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
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                // Barra superior com voltar
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
                    .accessibilityIdentifier("codigo-voltar")

                    Text("Entrar", bundle: bundleApresentacao)
                        .font(FrilaTipo.resumo)
                        .foregroundStyle(FrilaCor.texto)
                        .padding(.leading, FrilaEspaco.pequeno)

                    Spacer()
                }

                VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                    Text("Digite o código", bundle: bundleApresentacao)
                        .font(.title.bold())
                        .foregroundStyle(FrilaCor.texto)
                        .accessibilityAddTraits(.isHeader)

                    Text("Digite o código de 6 dígitos enviado para \(viewModel.email).", bundle: bundleApresentacao)
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }

                // Entrada dos 6 dígitos
                VStack(spacing: FrilaEspaco.pequeno) {
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
                                Text(verbatim: caractere)
                                    .font(.title.weight(.semibold).monospacedDigit())
                                    .minimumScaleFactor(0.8)
                                    .lineLimit(1)
                                    .foregroundStyle(FrilaCor.texto)
                                    .frame(maxWidth: .infinity, minHeight: 60)
                                    .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous)
                                            .strokeBorder(
                                                indice == viewModel.codigo.count ? FrilaCor.primaria : FrilaCor.borda,
                                                lineWidth: indice == viewModel.codigo.count ? 2 : 1
                                            )
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

                if let erro = viewModel.erro {
                    AvisoFrila(verbatim: erro, tom: .erro, anunciar: true)
                        .accessibilityIdentifier("codigo-erro")
                }

                if let info = viewModel.mensagemInformativa {
                    AvisoFrila(verbatim: info, tom: .informativo, anunciar: true)
                        .accessibilityIdentifier("codigo-info")
                }

                VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                    BotaoPrimario("Confirmar código", carregando: viewModel.carregando) {
                        confirmar()
                    }
                    .disabled(!viewModel.codigoValido || viewModel.carregando)
                    .accessibilityIdentifier("codigo-entrar")

                    if viewModel.segundosRestantes > 0 {
                        Text("Reenviar código em \(viewModel.segundosRestantes)s", bundle: bundleApresentacao)
                            .font(FrilaTipo.meta)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                            .accessibilityIdentifier("codigo-reenviar-aguarde")
                    } else {
                        Button(action: {
                            Task { await viewModel.reenviarCodigo() }
                        }) {
                            Text("Reenviar código", bundle: bundleApresentacao)
                                .font(FrilaTipo.meta.weight(.semibold))
                                .foregroundStyle(FrilaCor.texto)
                                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                                .contentShape(Rectangle())
                        }
                        .disabled(viewModel.carregando)
                        .accessibilityIdentifier("codigo-reenviar")
                    }

                    Text("Quem já tem conta entra do mesmo jeito. Cada e-mail é uma conta.", bundle: bundleApresentacao)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }

                Spacer(minLength: FrilaEspaco.enorme)
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
            .frame(maxWidth: .infinity)
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
        .onAppear {
            campoFocado = true
        }
        .onChange(of: viewModel.codigo) { _, novoCodigo in
            if novoCodigo.count == 6 && viewModel.codigoValido {
                confirmar()
            }
        }
    }

    private func confirmar() {
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
}
