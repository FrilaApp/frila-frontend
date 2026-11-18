import FrilaDominio
import SwiftUI

/// Folha de acionamento do suporte no turno (US22, RF23).
/// O suporte é um chamado por e-mail, não um chat (o chat da T4c do protótipo não existe no produto). Desenho do
/// sistema do Fabrício: o motivo em lista com visto, o campo de mensagem em várias linhas, a identificação do turno em
/// dados de leitura, e o único botão laranja ancorado embaixo, com o resultado da ação logo acima dele.
public struct FolhaSuporteTurno: View {
    @FocusState private var focoNoRelato: Bool
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
                VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                    avisoPrazo
                    seletorMotivo
                    if viewModel.ehRiscoSeguranca {
                        blocoSeguranca
                    }
                    blocoRelato
                    dadosTurno
                    secaoAuxiliar
                }
                .padding(.horizontal, FrilaEspaco.grupo)
                .padding(.top, FrilaEspaco.bloco)
                .padding(.bottom, FrilaEspaco.grupo)
                .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(FrilaCor.fundo)
            // O identificador da folha fica no conteúdo, antes do grupo ancorado: posto na pilha de navegação, ele
            // passava por cima dos identificadores do botão e das mensagens do rodapé.
            .accessibilityIdentifier("folha-suporte-turno")
            .rodapeAncorado { rodape }
            .navigationTitle(Text(verbatim: TextosDoSuporte.titulo))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text(verbatim: TextosDoSuporte.fechar)
                            .fixedSize()
                            .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                    }
                    .fixedSize()
                    .accessibilityShowsLargeContentViewer {
                        Text(verbatim: TextosDoSuporte.fechar)
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
        }
        .frilaKeyboardDismissScope()
    }

    /// O prazo vem em apoio, com o relógio ao lado, sem cartão: é informação, não aviso de problema.
    private var avisoPrazo: some View {
        HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.item) {
            Image(systemName: "clock")
                .font(FrilaTipo.corpo.weight(.medium))
                .foregroundStyle(FrilaCor.texto)
                .accessibilityIdentifier(reduzirMovimento ? "icone-prazo-sem-movimento" : "icone-prazo")
                .accessibilityLabel(Text(verbatim: TextosDoSuporte.rotuloIconePrazo))
            Text(verbatim: TextosDoSuporte.avisoPrazo)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("aviso-prazo-suporte")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Escolha única: lista com visto em tinta (nunca chip nem laranja).
    private var seletorMotivo: some View {
        FrilaGrupoDeLinhas(verbatim: TextosDoSuporte.secaoMotivo, linhasComIcone: false) {
            ForEach(MotivoSuporteTurno.allCases) { motivo in
                FrilaLinhaDeOpcao(titulo: motivo.rotulo, remate: .marcada(viewModel.motivo == motivo)) {
                    withAnimation(FrilaMovimento.animacao(.easeInOut(duration: 0.2), reduzir: reduzirMovimento)) {
                        viewModel.motivo = motivo
                    }
                }
                .accessibilityIdentifier("opcao-motivo-\(motivo.rawValue)")
            }
        }
    }

    /// Risco imediato: o aviso em bloco neutro e os dois atalhos de ligação em botão secundário (sem vermelho).
    private var blocoSeguranca: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            AvisoFrila(verbatim: TextosDoSuporte.avisoSeguranca, tom: .alerta)
                .accessibilityIdentifier("aviso-seguranca-suporte")
            BotaoSecundario(verbatim: TextosDoSuporte.policia) { ligar("190") }
                .accessibilityIdentifier("botao-ligar-190")
            BotaoSecundario(verbatim: TextosDoSuporte.mulher) { ligar("180") }
                .accessibilityIdentifier("botao-ligar-180")
        }
        .accessibilityElement(children: .contain)
    }

    private func ligar(_ numero: String) {
        if let url = URL(string: "tel:\(numero)") { openURL(url) }
    }

    /// Campo de mensagem: o campo de texto em várias linhas, com o rótulo visível acima, em rótulo de grupo.
    private var blocoRelato: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(verbatim: TextosDoSuporte.secaoRelato)
                .font(FrilaTipo.rotuloDeGrupo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            TextField(
                text: $viewModel.relato,
                prompt: Text(verbatim: TextosDoSuporte.promptRelato).foregroundStyle(FrilaCor.textoSecundario),
                axis: .vertical
            ) {
                Text(verbatim: TextosDoSuporte.secaoRelato)
            }
            .lineLimit(3...8)
            .textFieldStyle(.plain)
            .font(FrilaTipo.corpo)
            .foregroundStyle(FrilaCor.texto)
            // Altura mínima de 96 pt (a proposta do protótipo), crescendo com o texto.
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
            .caixaDoCampoFrila(emFoco: focoNoRelato)
            .focused($focoNoRelato)
            .accessibilityIdentifier("campo-relato-suporte")
            .accessibilityHint(Text(verbatim: TextosDoSuporte.quantidadeCaracteres(viewModel.relato.trimmingCharacters(in: .whitespacesAndNewlines).count)))
            .frilaFormField(id: "suporte-relato", isFocused: focoNoRelato, onDismiss: { focoNoRelato = false })

            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: TextosDoSuporte.dicaRelato)
                    .font(FrilaTipo.legenda)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: FrilaEspaco.item)
                Text(verbatim: "\(viewModel.relato.trimmingCharacters(in: .whitespacesAndNewlines).count)")
                    .font(FrilaTipo.legenda.monospacedDigit())
                    .foregroundStyle(viewModel.relatoValido ? FrilaCor.texto : FrilaCor.textoSecundario)
                    .accessibilityIdentifier("contador-relato-suporte")
                    .accessibilityLabel(Text(verbatim: TextosDoSuporte.quantidadeCaracteres(viewModel.relato.trimmingCharacters(in: .whitespacesAndNewlines).count)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A identificação do turno é dado de leitura: rótulo em apoio e valor em corpo, num cartão.
    private var dadosTurno: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(verbatim: TextosDoSuporte.secaoDados)
                .font(FrilaTipo.rotuloDeGrupo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                itemDado(rotulo: TextosDoSuporte.rotuloFuncao, valor: viewModel.dados.funcao)
                itemDado(rotulo: TextosDoSuporte.rotuloContratante, valor: viewModel.dados.contratante)
                itemDado(rotulo: TextosDoSuporte.rotuloProfissional, valor: viewModel.dados.profissional)
                itemDado(rotulo: TextosDoSuporte.rotuloHorario, valor: viewModel.dados.horarioFormatado)
                itemDado(rotulo: TextosDoSuporte.rotuloLocal, valor: viewModel.dados.endereco)
                itemDado(rotulo: TextosDoSuporte.rotuloID, valor: viewModel.dados.turnoID.uuidString)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartaoFrila()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("secao-dados-turno")
    }

    /// Rótulo e valor em bloco vertical com quebra de linha natural no Dynamic Type e AX5,
    /// para o leitor de tela ler o par combinado e nada ficar espremido nem cortado.
    private func itemDado(rotulo: String, valor: String) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
            Text(verbatim: "\(rotulo):")
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
            Text(verbatim: valor)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// Copiar os dados é uma ação auxiliar: botão secundário no conteúdo, com o resultado logo acima dele.
    private var secaoAuxiliar: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            if viewModel.copiadoComSucesso {
                MensagemJuntoAoBotao(verbatim: TextosDoSuporte.dadosCopiados)
                    .accessibilityIdentifier("aviso-dados-copiados")
            }

            BotaoSecundario(verbatim: TextosDoSuporte.botaoCopiarDados) {
                viewModel.copiarDadosParaTransferencia()
            }
            .accessibilityIdentifier("botao-copiar-dados-suporte")
            .accessibilityHint(Text(verbatim: TextosDoSuporte.dicaCopiarDados))

            Text(verbatim: String(format: TextosDoSuporte.emailSuporteRotulo, viewModel.emailDestino))
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .textSelection(.enabled)
                .accessibilityIdentifier("email-suporte-destino")
        }
    }

    /// O grupo ancorado: o resultado da ação (erro, falha do e-mail, protocolo) logo acima do botão primário.
    @ViewBuilder
    private var rodape: some View {
        if let erro = viewModel.mensagemDeErro {
            MensagemJuntoAoBotao(verbatim: erro)
                .accessibilityIdentifier("aviso-erro-suporte")
        }

        if let prot = viewModel.protocolo {
            MensagemJuntoAoBotao(verbatim: String(format: TextosDoSuporte.protocoloRegistrado, prot.protocoloCurto, FormatadorFrila().data(prot.prazoRespostaAte)))
                .accessibilityIdentifier("aviso-protocolo-suporte")
        }

        if viewModel.falhaAoAbrirEmail {
            MensagemJuntoAoBotao(verbatim: TextosDoSuporte.falhaAoAbrirEmail)
                .accessibilityIdentifier("aviso-falha-email-suporte")
        }

        if !viewModel.relatoValido {
            Text(verbatim: TextosDoSuporte.dicaRelatoObrigatorio)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("dica-relato-obrigatorio-suporte")
        }

        BotaoPrimario(verbatim: TextosDoSuporte.botaoEnviarEmail, carregando: viewModel.enviando) {
            Task {
                await viewModel.registrarEEnviar(abridorURL: { url in
                    openURL(url) { aceito in
                        if !aceito {
                            Task { @MainActor in
                                viewModel.registrarFalhaAoAbrirEmail()
                            }
                        }
                    }
                })
            }
        }
        .disabled(viewModel.enviando || !viewModel.relatoValido)
        .accessibilityIdentifier("botao-enviar-email-suporte")
        .accessibilityHint(Text(verbatim: viewModel.relatoValido ? TextosDoSuporte.dicaEnviarEmail : TextosDoSuporte.dicaRelatoObrigatorio))
    }
}
