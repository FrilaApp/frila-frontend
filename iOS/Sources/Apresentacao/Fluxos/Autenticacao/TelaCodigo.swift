import FrilaDominio
import SwiftUI

public struct TelaCodigo: View {
    @Bindable var viewModel: CodigoViewModel
    var aoVoltar: () -> Void
    var aoConcluir: (DestinoCodigo) -> Void
    @FocusState private var campoFocado: Bool

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
                            .font(.body.weight(.semibold))
                            .foregroundStyle(FrilaCor.texto)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(Text("Voltar", bundle: bundleApresentacao))
                    .accessibilityIdentifier("codigo-voltar")

                    Text("Entrar", bundle: bundleApresentacao)
                        .font(.headline)
                        .foregroundStyle(FrilaCor.texto)

                    Spacer()
                }

                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    Text("Digite o código", bundle: bundleApresentacao)
                        .font(.title.bold())
                        .foregroundStyle(FrilaCor.texto)

                    Text("Enviamos um código de 6 dígitos para \(viewModel.email). Ele vale por pouco tempo.", bundle: bundleApresentacao)
                        .font(.body)
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
                            .frame(maxWidth: .infinity, minHeight: 56)

                        // 6 caixas visuais
                        HStack(spacing: FrilaEspaco.pequeno) {
                            ForEach(0..<6, id: \.self) { indice in
                                let caractere = caractereNoIndice(indice)
                                Text(verbatim: caractere)
                                    .font(.title.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(FrilaCor.texto)
                                    .frame(maxWidth: .infinity, minHeight: 56)
                                    .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.pequeno))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: FrilaRaio.pequeno)
                                            .stroke(
                                                indice == viewModel.codigo.count ? FrilaCor.primaria : FrilaCor.textoSecundario.opacity(0.35),
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
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("Código de acesso", bundle: bundleApresentacao))
                    .accessibilityValue(viewModel.textoAcessibilidadeCodigo)
                    .accessibilityHint(Text("Digite os seis números enviados para seu e-mail", bundle: bundleApresentacao))
                    .accessibilityIdentifier("codigo-campo")
                }

                if let erro = viewModel.erro {
                    AvisoFrila(verbatim: erro, tom: .erro)
                        .accessibilityIdentifier("codigo-erro")
                }

                if let info = viewModel.mensagemInformativa {
                    AvisoFrila(verbatim: info, tom: .informativo)
                        .accessibilityIdentifier("codigo-info")
                }

                VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                    BotaoPrimario("Entrar", carregando: viewModel.carregando) {
                        Task {
                            if let destino = await viewModel.confirmarCodigo() {
                                aoConcluir(destino)
                            }
                        }
                    }
                    .disabled(!viewModel.codigoValido || viewModel.carregando)
                    .accessibilityIdentifier("codigo-entrar")

                    if viewModel.segundosRestantes > 0 {
                        Text("Reenviar código em \(viewModel.segundosRestantes)s", bundle: bundleApresentacao)
                            .font(.subheadline)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .accessibilityIdentifier("codigo-reenviar-aguarde")
                    } else {
                        Button(action: {
                            Task { await viewModel.reenviarCodigo() }
                        }) {
                            Text("Reenviar código", bundle: bundleApresentacao)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(FrilaCor.texto)
                                .underline()
                        }
                        .disabled(viewModel.carregando)
                        .accessibilityIdentifier("codigo-reenviar")
                    }

                    Text("Quem já tem conta entra do mesmo jeito. Cada e-mail é uma conta.", bundle: bundleApresentacao)
                        .font(.footnote)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
        .onAppear {
            campoFocado = true
        }
    }

    private func caractereNoIndice(_ indice: Int) -> String {
        guard indice < viewModel.codigo.count else { return "" }
        let index = viewModel.codigo.index(viewModel.codigo.startIndex, offsetBy: indice)
        return String(viewModel.codigo[index])
    }
}
