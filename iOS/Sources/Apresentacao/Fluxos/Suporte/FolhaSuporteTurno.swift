import FrilaDominio
import SwiftUI

/// Folha de acionamento do suporte no turno (US22, RF23).
public struct FolhaSuporteTurno: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Bindable private var viewModel: SuporteTurnoViewModel

    public init(viewModel: SuporteTurnoViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                    avisoPrazo
                    seletorMotivo
                    if viewModel.ehRiscoSeguranca {
                        blocoSeguranca
                    }
                    blocoRelato
                    dadosTurno
                    secaoAcoes
                }
                .padding(FrilaEspaco.medio)
                .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
                .frame(maxWidth: .infinity)
            }
            .background(FrilaCor.fundo)
            .navigationTitle(Text(verbatim: TextosDoSuporte.titulo))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(TextosDoSuporte.fechar) {
                        dismiss()
                    }
                    .accessibilityIdentifier("botao-fechar-suporte")
                }
            }
            .sheet(isPresented: $viewModel.mostrandoCompositorNativo) {
                CompositorDeEmailNativo(
                    destinatarios: [viewModel.emailDestino],
                    assunto: viewModel.assuntoEmail,
                    corpo: viewModel.corpoEmail,
                    aoConcluir: { [viewModel] _ in Task { @MainActor in viewModel.compositorConcluido() } }
                )
            }
            .accessibilityIdentifier("folha-suporte-turno")
        }
    }

    private var avisoPrazo: some View {
        HStack(alignment: .top, spacing: FrilaEspaco.pequeno) {
            Image(systemName: "clock.badge.exclamationmark")
                .foregroundStyle(FrilaCor.primaria)
                .font(.title3)
            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: TextosDoSuporte.avisoPrazo)
                    .font(.subheadline)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("aviso-prazo-suporte")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
    }

    private var seletorMotivo: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoSuporte.secaoMotivo)
                .font(.footnote.bold())
                .foregroundStyle(FrilaCor.textoSecundario)

            VStack(spacing: FrilaEspaco.minimo) {
                ForEach(MotivoSuporteTurno.allCases) { motivo in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.motivo = motivo
                        }
                    } label: {
                        HStack(spacing: FrilaEspaco.pequeno) {
                            Image(systemName: viewModel.motivo == motivo ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(viewModel.motivo == motivo ? FrilaCor.primaria : FrilaCor.textoSecundario)
                                .font(.body)
                            Text(verbatim: motivo.rotulo)
                                .font(.subheadline)
                                .foregroundStyle(FrilaCor.texto)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: motivo.rotulo))
                    .accessibilityIdentifier("opcao-motivo-\(motivo.rawValue)")
                    .accessibilityAddTraits(viewModel.motivo == motivo ? .isSelected : [])
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
    }

    private var blocoSeguranca: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
            HStack(alignment: .top, spacing: FrilaEspaco.pequeno) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(FrilaCor.perigo)
                    .font(.title3)
                Text(verbatim: TextosDoSuporte.avisoSeguranca)
                    .font(.subheadline.bold())
                    .foregroundStyle(FrilaCor.perigo)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("aviso-seguranca-suporte")
            }

            VStack(spacing: FrilaEspaco.pequeno) {
                Button {
                    if let url = URL(string: "tel:190") { openURL(url) }
                } label: {
                    HStack(spacing: FrilaEspaco.pequeno) {
                        Image(systemName: "phone.fill")
                        Text(verbatim: TextosDoSuporte.policia)
                    }
                    .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                    .font(.subheadline.bold())
                    .foregroundStyle(FrilaCor.sobrePrimaria)
                    .background(FrilaCor.perigo, in: RoundedRectangle(cornerRadius: FrilaRaio.medio))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("botao-ligar-190")

                Button {
                    if let url = URL(string: "tel:180") { openURL(url) }
                } label: {
                    HStack(spacing: FrilaEspaco.pequeno) {
                        Image(systemName: "phone.fill")
                        Text(verbatim: TextosDoSuporte.mulher)
                    }
                    .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                    .font(.subheadline.bold())
                    .foregroundStyle(FrilaCor.sobrePrimaria)
                    .background(FrilaCor.perigo, in: RoundedRectangle(cornerRadius: FrilaRaio.medio))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("botao-ligar-180")
            }
        }
        .padding(FrilaEspaco.medio)
        .background(FrilaCor.perigo.opacity(0.12), in: RoundedRectangle(cornerRadius: FrilaRaio.medio))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaRaio.medio)
                .stroke(FrilaCor.perigo.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private var blocoRelato: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoSuporte.secaoRelato)
                .font(.footnote.bold())
                .foregroundStyle(FrilaCor.textoSecundario)

            TextField(
                TextosDoSuporte.promptRelato,
                text: $viewModel.relato,
                axis: .vertical
            )
            .lineLimit(3...6)
            .padding(FrilaEspaco.pequeno)
            .background(FrilaCor.fundo, in: RoundedRectangle(cornerRadius: FrilaRaio.pequeno))
            .accessibilityIdentifier("campo-relato-suporte")

            Text(verbatim: TextosDoSuporte.dicaRelato)
                .font(.caption)
                .foregroundStyle(FrilaCor.textoSecundario)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
    }

    private var dadosTurno: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoSuporte.secaoDados)
                .font(.footnote.bold())
                .foregroundStyle(FrilaCor.textoSecundario)

            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                itemDado(rotulo: TextosDoSuporte.rotuloFuncao, valor: viewModel.dados.funcao)
                itemDado(rotulo: TextosDoSuporte.rotuloContratante, valor: viewModel.dados.contratante)
                itemDado(rotulo: TextosDoSuporte.rotuloProfissional, valor: viewModel.dados.profissional)
                itemDado(rotulo: TextosDoSuporte.rotuloHorario, valor: viewModel.dados.horarioFormatado)
                itemDado(rotulo: TextosDoSuporte.rotuloLocal, valor: viewModel.dados.endereco)
                itemDado(rotulo: TextosDoSuporte.rotuloID, valor: viewModel.dados.turnoID.uuidString)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityIdentifier("secao-dados-turno")
    }

    /// Rótulo e valor lado a lado; em tamanho de acessibilidade (AX5) ou valor comprido, um
    /// embaixo do outro, para o VoiceOver ler o par inteiro e nada ficar espremido.
    private func itemDado(rotulo: String, valor: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: "\(rotulo):")
                    .font(.caption.bold())
                    .foregroundStyle(FrilaCor.textoSecundario)
                Spacer()
                Text(verbatim: valor)
                    .font(.caption)
                    .foregroundStyle(FrilaCor.texto)
                    .multilineTextAlignment(.trailing)
            }
            .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "\(rotulo):")
                    .font(.caption.bold())
                    .foregroundStyle(FrilaCor.textoSecundario)
                Text(verbatim: valor)
                    .font(.caption)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var secaoAcoes: some View {
        VStack(spacing: FrilaEspaco.medio) {
            BotaoPrimario(verbatim: TextosDoSuporte.botaoEnviarEmail) {
                if viewModel.podeEnviarEmailNativo {
                    viewModel.mostrandoCompositorNativo = true
                } else if let url = viewModel.urlMailto {
                    openURL(url)
                } else {
                    viewModel.copiarDadosParaTransferencia()
                }
            }
            .accessibilityIdentifier("botao-enviar-email-suporte")
            .accessibilityHint(Text(verbatim: TextosDoSuporte.dicaEnviarEmail))

            BotaoSecundario(verbatim: TextosDoSuporte.botaoCopiarDados) {
                viewModel.copiarDadosParaTransferencia()
            }
            .accessibilityIdentifier("botao-copiar-dados-suporte")
            .accessibilityHint(Text(verbatim: TextosDoSuporte.dicaCopiarDados))

            if viewModel.copiadoComSucesso {
                HStack(spacing: FrilaEspaco.minimo) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(FrilaCor.sucesso)
                    Text(verbatim: TextosDoSuporte.dadosCopiados)
                        .font(.footnote)
                        .foregroundStyle(FrilaCor.sucesso)
                }
                .accessibilityIdentifier("aviso-dados-copiados")
            }

            Text(verbatim: String(format: TextosDoSuporte.emailSuporteRotulo, viewModel.emailDestino))
                .font(.caption)
                .foregroundStyle(FrilaCor.textoSecundario)
        }
        .padding(.top, FrilaEspaco.pequeno)
    }
}
