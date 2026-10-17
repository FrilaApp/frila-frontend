import FrilaDominio
import SwiftUI

/// Folha de acionamento do suporte no turno (US22, RF23).
/// Segue os quadros "AlertaAtraso" e "Denuncia" do MidFi do Fabrício: seções em cartões agrupados,
/// microrrótulos em caixa alta, motivos em lista com visto, avisos neutros e botões em cápsula.
public struct FolhaSuporteTurno: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var sistemaReduzirMovimento
    private var reduzirMovimento: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-UIAccessibilityReduceMotionEnabled") {
            return true
        }
        #endif
        return sistemaReduzirMovimento
    }
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
                    .accessibilityShowsLargeContentViewer {
                        Text(verbatim: TextosDoSuporte.fechar)
                    }
                    .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
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
                .foregroundStyle(FrilaCor.textoSecundario)
                .font(FrilaTipo.subtituloDaTela)
                .accessibilityIdentifier(reduzirMovimento ? "icone-prazo-sem-movimento" : "icone-prazo")
                .accessibilityLabel(Text(verbatim: TextosDoSuporte.rotuloIconePrazo))
            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: TextosDoSuporte.avisoPrazo)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("aviso-prazo-suporte")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FrilaEspaco.medio)
        .background(FrilaCor.controle, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
    }

    private var seletorMotivo: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoSuporte.secaoMotivo)
                .font(FrilaTipo.microRotulo)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                ForEach(Array(MotivoSuporteTurno.allCases.enumerated()), id: \.element.id) { indice, motivo in
                    if indice > 0 {
                        Rectangle()
                            .fill(FrilaCor.divisoria)
                            .frame(height: 1)
                            .accessibilityHidden(true)
                    }
                    Button {
                        withAnimation(FrilaMovimento.animacao(.easeInOut(duration: 0.2), reduzir: reduzirMovimento)) {
                            viewModel.motivo = motivo
                        }
                    } label: {
                        HStack(spacing: FrilaEspaco.pequeno) {
                            Text(verbatim: motivo.rotulo)
                                .font(FrilaTipo.meta)
                                .foregroundStyle(FrilaCor.texto)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            // Decorativo: o estado vai pelo traço `.isSelected` do botão.
                            Image(systemName: "checkmark")
                                .font(FrilaTipo.rotuloDoCampo)
                                .foregroundStyle(FrilaCor.primaria)
                                .opacity(viewModel.motivo == motivo ? 1 : 0)
                                .accessibilityHidden(true)
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
                    .font(FrilaTipo.subtituloDaTela)
                    .accessibilityHidden(true)
                Text(verbatim: TextosDoSuporte.avisoSeguranca)
                    .font(FrilaTipo.meta.bold())
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("aviso-seguranca-suporte")
            }

            VStack(spacing: FrilaEspaco.pequeno) {
                botaoDeLigacao(texto: TextosDoSuporte.policia, numero: "190")
                    .accessibilityIdentifier("botao-ligar-190")
                botaoDeLigacao(texto: TextosDoSuporte.mulher, numero: "180")
                    .accessibilityIdentifier("botao-ligar-180")
            }
        }
        .padding(FrilaEspaco.medio)
        .background(FrilaCor.controle, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    /// Cápsula de contorno vermelho, como o botão de ligar de emergência do MidFi.
    private func botaoDeLigacao(texto: String, numero: String) -> some View {
        Button {
            if let url = URL(string: "tel:\(numero)") { openURL(url) }
        } label: {
            HStack(spacing: FrilaEspaco.pequeno) {
                Image(systemName: "phone.fill").accessibilityHidden(true)
                Text(verbatim: texto)
            }
            .capsulaDestrutiva()
        }
        .buttonStyle(.plain)
    }

    private var blocoRelato: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoSuporte.secaoRelato)
                .font(FrilaTipo.microRotulo)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

            TextField(
                TextosDoSuporte.promptRelato,
                text: $viewModel.relato,
                axis: .vertical
            )
            .lineLimit(3...6)
            .font(FrilaTipo.valorDoCampo)
            .padding(FrilaEspaco.compacto)
            .frame(minHeight: FrilaMetrica.alvoMinimo)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous).strokeBorder(FrilaCor.borda, lineWidth: 1))
            .accessibilityIdentifier("campo-relato-suporte")
            .accessibilityHint(Text(verbatim: "\(viewModel.relato.trimmingCharacters(in: .whitespacesAndNewlines).count) \(TextosDoSuporte.caracteres)"))

            HStack {
                Text(verbatim: TextosDoSuporte.dicaRelato)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
                Spacer()
                Text(verbatim: "\(viewModel.relato.trimmingCharacters(in: .whitespacesAndNewlines).count)")
                    .font(FrilaTipo.nota.monospacedDigit())
                    .foregroundStyle(viewModel.relatoValido ? FrilaCor.texto : FrilaCor.textoSecundario)
                    .accessibilityIdentifier("contador-relato-suporte")
                    .accessibilityLabel(Text(verbatim: "\(viewModel.relato.trimmingCharacters(in: .whitespacesAndNewlines).count) \(TextosDoSuporte.caracteres)"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
    }

    private var dadosTurno: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoSuporte.secaoDados)
                .font(FrilaTipo.microRotulo)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

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

    /// Rótulo e valor em bloco vertical com quebra de linha natural no Dynamic Type e AX5,
    /// para o VoiceOver ler o par combinado e nada ficar espremido nem cortado.
    private func itemDado(rotulo: String, valor: String) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
            Text(verbatim: "\(rotulo):")
                .font(FrilaTipo.nota.bold())
                .foregroundStyle(FrilaCor.textoSecundario)
            Text(verbatim: valor)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, FrilaEspaco.fio)
        .accessibilityElement(children: .combine)
    }

    private var secaoAcoes: some View {
        VStack(spacing: FrilaEspaco.medio) {
            if let erro = viewModel.mensagemDeErro {
                AvisoFrila(verbatim: erro, tom: .alerta)
                    .accessibilityIdentifier("aviso-erro-suporte")
            }

            if let prot = viewModel.protocolo {
                HStack(alignment: .top, spacing: FrilaEspaco.pequeno) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(FrilaCor.sucesso)
                        .accessibilityHidden(true)
                    Text(verbatim: String(format: TextosDoSuporte.protocoloRegistrado, prot.protocoloCurto, FormatadorFrila().data(prot.prazoRespostaAte)))
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.texto)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("aviso-protocolo-suporte")
            }

            if viewModel.falhaAoAbrirEmail {
                AvisoFrila(verbatim: TextosDoSuporte.falhaAoAbrirEmail, tom: .alerta)
                    .accessibilityIdentifier("aviso-falha-email-suporte")
            }

            BotaoPrimario(verbatim: TextosDoSuporte.botaoEnviarEmail) {
                Task {
                    await viewModel.registrarEEnviar(abridorURL: { url in
                        openURL(url) { aceito in
                            if !aceito {
                                viewModel.registrarFalhaAoAbrirEmail()
                            }
                        }
                    })
                }
            }
            .disabled(viewModel.enviando || !viewModel.relatoValido)
            .accessibilityIdentifier("botao-enviar-email-suporte")
            .accessibilityHint(Text(verbatim: TextosDoSuporte.dicaEnviarEmail))

            BotaoSecundario(verbatim: TextosDoSuporte.botaoCopiarDados) {
                viewModel.copiarDadosParaTransferencia()
            }
            .accessibilityIdentifier("botao-copiar-dados-suporte")
            .accessibilityHint(Text(verbatim: TextosDoSuporte.dicaCopiarDados))

            if viewModel.copiadoComSucesso {
                HStack(spacing: FrilaEspaco.pequeno) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(FrilaCor.sucesso)
                        .accessibilityHidden(true)
                    Text(verbatim: TextosDoSuporte.dadosCopiados)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.texto)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("aviso-dados-copiados")
            }

            Text(verbatim: String(format: TextosDoSuporte.emailSuporteRotulo, viewModel.emailDestino))
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
        }
        .padding(.top, FrilaEspaco.pequeno)
    }
}
