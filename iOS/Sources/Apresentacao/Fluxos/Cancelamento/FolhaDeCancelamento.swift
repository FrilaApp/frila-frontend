import FrilaDominio
import SwiftUI

/// A folha que pede o motivo e avisa o efeito antes de cancelar, igual para os dois lados (#20).
/// Sem motivo, o botão não habilita. Depois da resposta, mostra o desfecho e só deixa fechar.
/// Segue o quadro "CancelarTurno" do MidFi do Fabrício: motivos num cartão agrupado, com divisórias e visto.
public struct FolhaDeCancelamento: View {
    @Bindable private var viewModel: CancelamentoViewModel
    private let fechar: () -> Void
    @FocusState private var focoNosDetalhes: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(viewModel: CancelamentoViewModel, fechar: @escaping () -> Void) {
        self.viewModel = viewModel
        self.fechar = fechar
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                FolhaFrila(verbatim: TextosDoCancelamento.titulo(lado: viewModel.lado, alvo: viewModel.alvo)) {
                    switch viewModel.estado {
                    case .pronto, .enviando, .falha:
                        formulario
                        if dynamicTypeSize.isAccessibilitySize {
                            botoesDeAcao
                        }
                    case let .concluido(desfecho):
                        desfechoView(desfecho)
                        if dynamicTypeSize.isAccessibilitySize {
                            botoesDeAcao
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                if !dynamicTypeSize.isAccessibilitySize {
                    botoesDeAcao
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        focoNosDetalhes = false
                    } label: {
                        Text(verbatim: TextosDoCancelamento.ok)
                    }
                    .accessibilityLabel(Text(verbatim: TextosDoCancelamento.recolherTeclado))
                    .accessibilityIdentifier("recolher-teclado")
                }
            }
            .background(FrilaCor.fundo.ignoresSafeArea())
        }
        .accessibilityIdentifier("folha-de-cancelamento")
        .interactiveDismissDisabled(viewModel.estado == .enviando)
    }

    @ViewBuilder private var formulario: some View {
        AvisoFrila(verbatim: viewModel.aviso, tom: viewModel.contaComoFalta ? .alerta : .informativo)
            .accessibilityIdentifier("aviso-do-cancelamento")

        Text(verbatim: TextosDoCancelamento.motivoTitulo)
            .font(FrilaTipo.rotuloDoCampo)
            .foregroundStyle(FrilaCor.textoSecundario)
            .accessibilityAddTraits(.isHeader)
        VStack(spacing: 0) {
            ForEach(Array(viewModel.motivos.enumerated()), id: \.element.id) { indice, motivo in
                if indice > 0 {
                    Rectangle()
                        .fill(FrilaCor.divisoria)
                        .frame(height: 1)
                        .padding(.leading, FrilaEspaco.medio)
                        .accessibilityHidden(true)
                }
                opcao(motivo)
            }
        }
        .background(FrilaCor.fundo, in: RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous).strokeBorder(FrilaCor.divisoria, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("motivos-do-cancelamento")

        if let motivo = viewModel.motivo {
            // O rótulo do campo é o mesmo do título: obrigatório em "Outro motivo", opcional nos demais.
            let rotulo = motivo.exigeDetalhes ? TextosDoCancelamento.detalhesObrigatorios : TextosDoCancelamento.detalhesTitulo
            let prompt = motivo.exigeDetalhes ? Text(verbatim: TextosDoCancelamento.placeholderDetalhes).foregroundStyle(FrilaCor.textoSecundario) : nil
            Text(verbatim: rotulo)
                .font(FrilaTipo.rotuloDoCampo)
                .foregroundStyle(FrilaCor.textoSecundario)
            TextField(text: $viewModel.detalhes, prompt: prompt, axis: .vertical) {
                Text(verbatim: rotulo)
            }
            .lineLimit(2...5)
            .focused($focoNosDetalhes)
            .textFieldStyle(.plain)
            .font(FrilaTipo.valorDoCampo)
            .padding(FrilaEspaco.medio)
            .frame(minHeight: FrilaMetrica.alvoMinimo)
            .background(FrilaCor.superficieDoCampo, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous).strokeBorder(FrilaCor.bordaDoCampo, lineWidth: 1))
            .accessibilityIdentifier("detalhes-do-cancelamento")
        } else {
            Text(verbatim: TextosDoCancelamento.motivoObrigatorio)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityIdentifier("motivo-obrigatorio")
        }

        if case let .falha(mensagem) = viewModel.estado {
            AvisoFrila(verbatim: mensagem, tom: .erro)
                .accessibilityIdentifier("falha-do-cancelamento")
        }
    }

    @ViewBuilder private var botoesDeAcao: some View {
        switch viewModel.estado {
        case .pronto, .enviando, .falha:
            VStack(spacing: FrilaEspaco.pequeno) {
                Button {
                    Task { await viewModel.confirmar() }
                } label: {
                    HStack(spacing: FrilaEspaco.pequeno) {
                        if viewModel.estado == .enviando {
                            ProgressView()
                                .tint(FrilaCor.sobrePrimaria)
                                .accessibilityHidden(true)
                        }
                        Text(verbatim: TextosDoCancelamento.confirmar)
                            .font(FrilaTipo.botao)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, FrilaEspaco.grande)
                    .padding(.vertical, FrilaEspaco.pequeno)
                    .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
                    .foregroundStyle(viewModel.podeConfirmar ? FrilaCor.sobrePrimaria : FrilaCor.textoSecundario)
                    .background(viewModel.podeConfirmar ? FrilaCor.perigo : FrilaCor.controle, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.tatil)
                .disabled(!viewModel.podeConfirmar || viewModel.estado == .enviando)
                .accessibilityIdentifier("confirmar-cancelamento")
                .accessibilityLabel(Text(verbatim: TextosDoCancelamento.confirmar))
                .accessibilityValue(viewModel.estado == .enviando ? Text("Carregando", bundle: bundleApresentacao) : Text(verbatim: ""))

                BotaoSecundario(verbatim: TextosDoCancelamento.voltar, acao: fechar)
                    .disabled(viewModel.estado == .enviando)
                    .accessibilityIdentifier("voltar-do-cancelamento")
            }
            .padding(dynamicTypeSize.isAccessibilitySize ? 0 : FrilaEspaco.medio)
            .background(dynamicTypeSize.isAccessibilitySize ? Color.clear : FrilaCor.fundo)
        case .concluido:
            VStack(spacing: FrilaEspaco.pequeno) {
                BotaoPrimario(verbatim: TextosDoCancelamento.fechar, acao: fechar)
                    .accessibilityIdentifier("fechar-cancelamento")
            }
            .padding(dynamicTypeSize.isAccessibilitySize ? 0 : FrilaEspaco.medio)
            .background(dynamicTypeSize.isAccessibilitySize ? Color.clear : FrilaCor.fundo)
        }
    }

    private func opcao(_ motivo: MotivoDeCancelamento) -> some View {
        let escolhido = viewModel.motivo == motivo
        return Button {
            viewModel.motivo = motivo
        } label: {
            HStack(spacing: FrilaEspaco.compacto) {
                Text(verbatim: TextosDoCancelamento.motivo(motivo))
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                // Decorativo: o estado vai pelo traço `.isSelected` do botão.
                Image(systemName: "checkmark")
                    .font(FrilaTipo.rotuloDoCampo)
                    .foregroundStyle(FrilaCor.primaria)
                    .opacity(escolhido ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.vertical, FrilaEspaco.pequeno)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(escolhido ? [.isSelected] : [])
        .accessibilityValue(FrilaAcessibilidade.textoSelecao(selecionado: escolhido))
        .accessibilityIdentifier("motivo-\(motivo.rawValue)")
    }

    @ViewBuilder private func desfechoView(_ desfecho: DesfechoDoCancelamento) -> some View {
        AvisoFrila(verbatim: TextosDoCancelamento.desfecho(desfecho, lado: viewModel.lado), tom: .informativo)
            .accessibilityIdentifier("desfecho-do-cancelamento")
        if case let .posicao(resultado) = desfecho, viewModel.lado == .profissional {
            Text(verbatim: resultado.falta ? TextosDoProfissional.Turnos.cancelamentoComFalta : TextosDoProfissional.Turnos.cancelamentoSemFalta)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityIdentifier("falta-do-cancelamento")
        }
    }
}

/// Botão de cancelamento em cápsula destrutiva (MidFi do Fabrício) que abre a folha de cancelamento, nos dois lados.
public struct BotaoDeCancelamento: View {
    private let titulo: String
    private let acao: () -> Void

    public init(titulo: String, acao: @escaping () -> Void) {
        self.titulo = titulo
        self.acao = acao
    }

    public var body: some View {
        Button(role: .destructive, action: acao) {
            Text(verbatim: titulo)
                .capsulaDestrutiva()
        }
        .buttonStyle(.tatil)
    }
}
