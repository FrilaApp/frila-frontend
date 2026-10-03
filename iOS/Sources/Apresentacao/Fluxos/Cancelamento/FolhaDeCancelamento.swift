// VISUAL PROVISÓRIO: o design de alta fidelidade do cancelamento ainda não chegou (#20).

import FrilaDominio
import SwiftUI

/// A folha que pede o motivo e avisa o efeito antes de cancelar, igual para os dois lados (#20).
/// Sem motivo, o botão não habilita. Depois da resposta, mostra o desfecho e só deixa fechar.
public struct FolhaDeCancelamento: View {
    @Bindable private var viewModel: CancelamentoViewModel
    private let fechar: () -> Void

    public init(viewModel: CancelamentoViewModel, fechar: @escaping () -> Void) {
        self.viewModel = viewModel
        self.fechar = fechar
    }

    public var body: some View {
        ScrollView {
            FolhaFrila(verbatim: TextosDoCancelamento.titulo(lado: viewModel.lado, alvo: viewModel.alvo)) {
                switch viewModel.estado {
                case .pronto, .enviando, .falha:
                    formulario
                case let .concluido(desfecho):
                    desfechoView(desfecho)
                }
            }
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
        .interactiveDismissDisabled(viewModel.estado == .enviando)
        .accessibilityIdentifier("folha-de-cancelamento")
    }

    @ViewBuilder private var formulario: some View {
        AvisoFrila(verbatim: viewModel.aviso, tom: viewModel.contaComoFalta ? .alerta : .informativo)
            .accessibilityIdentifier("aviso-do-cancelamento")

        Text(verbatim: TextosDoCancelamento.motivoTitulo)
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            ForEach(viewModel.motivos) { motivo in
                opcao(motivo)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("motivos-do-cancelamento")

        if let motivo = viewModel.motivo {
            Text(verbatim: motivo.exigeDetalhes ? TextosDoCancelamento.detalhesObrigatorios : TextosDoCancelamento.detalhesTitulo)
                .font(.subheadline)
                .foregroundStyle(FrilaCor.textoSecundario)
            TextField(text: $viewModel.detalhes, prompt: nil, axis: .vertical) {
                Text(verbatim: TextosDoCancelamento.detalhesTitulo)
            }
            .lineLimit(2...5)
            .textFieldStyle(.plain)
            .padding(FrilaEspaco.medio)
            .frame(minHeight: FrilaMetrica.alvoMinimo)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.medio))
            .overlay(RoundedRectangle(cornerRadius: FrilaRaio.medio).stroke(FrilaCor.textoSecundario.opacity(0.35)))
            .accessibilityIdentifier("detalhes-do-cancelamento")
        } else {
            Text(verbatim: TextosDoCancelamento.motivoObrigatorio)
                .font(.subheadline)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityIdentifier("motivo-obrigatorio")
        }

        if case let .falha(mensagem) = viewModel.estado {
            AvisoFrila(verbatim: mensagem, tom: .erro)
                .accessibilityIdentifier("falha-do-cancelamento")
        }

        BotaoPrimario(verbatim: TextosDoCancelamento.confirmar, carregando: viewModel.estado == .enviando) {
            Task { await viewModel.confirmar() }
        }
        .disabled(!viewModel.podeConfirmar)
        .accessibilityIdentifier("confirmar-cancelamento")

        BotaoSecundario(verbatim: TextosDoCancelamento.voltar, acao: fechar)
            .disabled(viewModel.estado == .enviando)
            .accessibilityIdentifier("voltar-do-cancelamento")
    }

    private func opcao(_ motivo: MotivoDeCancelamento) -> some View {
        let escolhido = viewModel.motivo == motivo
        return Button {
            viewModel.motivo = motivo
        } label: {
            HStack(spacing: FrilaEspaco.pequeno) {
                Image(systemName: escolhido ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(escolhido ? FrilaCor.primaria : FrilaCor.textoSecundario)
                Text(verbatim: TextosDoCancelamento.motivo(motivo))
                    .foregroundStyle(FrilaCor.texto)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.medio))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(escolhido ? [.isSelected] : [])
        .accessibilityIdentifier("motivo-\(motivo.rawValue)")
    }

    @ViewBuilder private func desfechoView(_ desfecho: DesfechoDoCancelamento) -> some View {
        AvisoFrila(verbatim: TextosDoCancelamento.desfecho(desfecho, lado: viewModel.lado), tom: .informativo)
            .accessibilityIdentifier("desfecho-do-cancelamento")
        if case let .posicao(resultado) = desfecho, viewModel.lado == .profissional {
            Text(verbatim: resultado.falta ? TextosDoProfissional.Turnos.cancelamentoComFalta : TextosDoProfissional.Turnos.cancelamentoSemFalta)
                .font(.subheadline)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityIdentifier("falta-do-cancelamento")
        }
        BotaoPrimario(verbatim: TextosDoCancelamento.fechar, acao: fechar)
            .accessibilityIdentifier("fechar-cancelamento")
    }
}

/// Botão de contorno vermelho que abre a folha de cancelamento, nos dois lados.
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
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
        }
        .buttonStyle(.plain)
        .foregroundStyle(FrilaCor.perigo)
        .overlay(RoundedRectangle(cornerRadius: FrilaRaio.medio).stroke(FrilaCor.perigo, lineWidth: 1.5))
    }
}
