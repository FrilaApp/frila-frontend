import FrilaDominio
import SwiftUI

/// T4c · Chat de suporte (#22, Lote 5).
/// Permite ao profissional relatar problemas ou dúvidas diretamente à equipe do Frila.
public struct TelaChatSuporte: View {
    @Environment(\.dismiss) private var dismiss
    private let seloTurno: String?
    private let nomeCasa: String
    private let quandoTexto: String
    private let horarioTexto: String
    private let assuntoInicial: String?
    private let mensagensIniciais: [String]
    private let aoEnviarMensagem: ((String) -> Void)?

    @State private var mensagens: [String]
    @State private var novaMensagem: String = ""
    @FocusState private var campoFocado: Bool

    public init(
        seloTurno: String? = "Confirmado",
        nomeCasa: String = "Bar do Porto",
        quandoTexto: String = "Hoje",
        horarioTexto: String = "18:00 às 00:00",
        assunto: String? = nil,
        mensagensIniciais: [String] = [],
        aoEnviarMensagem: ((String) -> Void)? = nil
    ) {
        self.seloTurno = seloTurno
        self.nomeCasa = nomeCasa
        self.quandoTexto = quandoTexto
        self.horarioTexto = horarioTexto
        self.assuntoInicial = assunto
        self.mensagensIniciais = mensagensIniciais
        self.aoEnviarMensagem = aoEnviarMensagem
        _mensagens = State(initialValue: mensagensIniciais)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                        topoSuporte

                        secaoSobreTurno

                        if !mensagens.isEmpty {
                            conversaView
                        }
                    }
                    .padding(.horizontal, FrilaEspaco.medio)
                    .padding(.top, FrilaEspaco.pequeno)
                    .padding(.bottom, FrilaEspaco.grande)
                    .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                areaDeEnvioInferior
            }
            .background(FrilaCor.fundo.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(FrilaTipo.corpo)
                            .foregroundStyle(FrilaCor.texto)
                            .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                    }
                    .accessibilityLabel(Text("Voltar", bundle: bundleApresentacao))
                    .accessibilityIdentifier("chat-suporte-voltar")
                }
            }
            .accessibilityIdentifier("tela-chat-suporte")
        }
    }

    private var topoSuporte: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: TextosLote4.suporte)
                .font(FrilaTipo.tituloGrande)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)

            Text(verbatim: TextosLote4.suporteApoio)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
        }
    }

    private var secaoSobreTurno: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosLote4.sobreOTurno)
                .font(FrilaTipo.rotuloDoCampo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                if let seloTurno {
                    Text(verbatim: seloTurno)
                        .font(FrilaTipo.chip)
                        .foregroundStyle(FrilaCor.texto)
                        .padding(.horizontal, FrilaEspaco.pequeno)
                        .padding(.vertical, FrilaEspaco.fio)
                        .background(Capsule().strokeBorder(FrilaCor.borda, lineWidth: 1))
                }

                Text(verbatim: nomeCasa)
                    .font(FrilaTipo.secao)
                    .foregroundStyle(FrilaCor.texto)

                HStack(spacing: FrilaEspaco.compacto) {
                    Text(verbatim: quandoTexto)
                        .font(FrilaTipo.corpo.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)

                    Text(verbatim: horarioTexto)
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
            }
            .padding(FrilaEspaco.medio)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous)
                    .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
            )

            if let assunto = assuntoInicial {
                Text(verbatim: TextosLote4.assunto(assunto))
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .padding(.top, FrilaEspaco.fio)
            }
        }
    }

    private var conversaView: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
            ForEach(Array(mensagens.enumerated()), id: \.offset) { _, texto in
                HStack {
                    Spacer(minLength: 40)
                    Text(verbatim: texto)
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.texto)
                        .padding(FrilaEspaco.medio)
                        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                                .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
                        )
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: TextosLote4.conversaComSuporte))
        .accessibilityIdentifier("chat-suporte-conversa")
    }

    private var areaDeEnvioInferior: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosLote4.suaMensagem)
                .font(FrilaTipo.rotuloDoCampo)
                .foregroundStyle(FrilaCor.textoSecundario)

            TextField(Text(verbatim: TextosLote4.suaMensagem), text: $novaMensagem, axis: .vertical)
                .lineLimit(1...4)
                .font(FrilaTipo.valorDoCampo)
                .foregroundStyle(FrilaCor.texto)
                .focused($campoFocado)
                .padding(FrilaEspaco.compacto)
                .background(FrilaCor.superficieDoCampo, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                        .strokeBorder(FrilaCor.bordaDoCampo, lineWidth: 1)
                )
                .accessibilityIdentifier("chat-suporte-campo")

            BotaoPrimario(verbatim: TextosLote4.enviarMensagem) {
                let msg = novaMensagem.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !msg.isEmpty else { return }
                mensagens.append(msg)
                novaMensagem = ""
                campoFocado = false
                UIAccessibility.post(notification: .announcement, argument: TextosLote4.mensagemEnviada)
                aoEnviarMensagem?(msg)
            }
            .disabled(novaMensagem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("chat-suporte-enviar")
        }
        .padding(.horizontal, FrilaEspaco.medio)
        .padding(.vertical, FrilaEspaco.compacto)
        .background(FrilaCor.fundo)
        .overlay(
            Rectangle().frame(height: 1).foregroundStyle(FrilaCor.divisoria),
            alignment: .top
        )
    }
}
