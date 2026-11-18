import FrilaDominio
import SwiftUI
import UIKit

/// A leitura do código da casa pelo profissional (contrato 0.2.68, direção semiautomática de 10/11/2026).
/// Os 6 números digitados diretamente pelo profissional. Mede a distância no toque (apenas a distância
/// vai ao servidor, nunca a coordenada). Acima do raio configurado avisa "chegue mais perto" e não envia,
/// preservando as tentativas do profissional. Sem QR code nesta etapa.
/// Segue a composição das telas de entrada do protótipo: o rótulo, o campo de 48 pt, o botão primário ancorado no pé e,
/// junto dele, em tinta, o resultado ("Conferindo o código…", "Esse código não vale…"), sem vermelho.
public struct EntradaDoCodigo: View {
    private typealias Textos = TextosDoCheckinPorCodigo.Profissional

    public let presenca: PresencaDoTurnoViewModel
    @State private var validacao: ValidacaoDoCodigoViewModel
    @State private var codigo = ""
    @Environment(\.dismiss) private var fechar
    @Environment(\.dynamicTypeSize) private var tamanhoDoTexto
    @FocusState private var campoEmFoco: Bool

    public init(presenca: PresencaDoTurnoViewModel) {
        self.presenca = presenca
        _validacao = State(initialValue: presenca.criarValidacaoDoCodigo())
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                    Text(verbatim: Textos.explicacao)
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)

                    campo

                    Text(verbatim: Textos.casaConfirma)
                        .font(FrilaTipo.apoio)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("aviso-casa-confirma")

                    if tamanhoDoTexto.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: FrilaEspaco.item) { rodape }
                    }
                }
                .padding(.horizontal, FrilaEspaco.grupo)
                .padding(.top, FrilaEspaco.bloco)
                .padding(.bottom, FrilaEspaco.grupo)
            }
            .background(FrilaCor.fundo.ignoresSafeArea())
            .modifier(RodapeAncoradoForaDeAX { rodape })
            .navigationTitle(Textos.titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Textos.fechar) { fechar() }
                        .accessibilityIdentifier("fechar-entrada-do-codigo")
                }
            }
        }
        .presentationCornerRadius(FrilaRaio.folha)
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("entrada-do-codigo")
        .onChange(of: validacao.resultado) { _, novo in aplicar(novo) }
    }

    // MARK: Digitar

    /// O rótulo visível acima do campo, em rótulo de grupo, e o campo de 48 pt com o foco de 2 pt em tinta.
    private var campo: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(verbatim: Textos.rotuloDoCampo)
                .font(FrilaTipo.rotuloDeGrupo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityHidden(true)
            TextField("", text: $codigo, prompt: Text(verbatim: "000000").foregroundStyle(FrilaCor.textoSecundario))
                .textFieldStyle(.plain)
                .keyboardType(.numberPad)
                .font(FrilaTipo.rotuloSecundario.monospacedDigit())
                .foregroundStyle(FrilaCor.texto)
                .tracking(4)
                .multilineTextAlignment(.center)
                .focused($campoEmFoco)
                .caixaDoCampoFrila(emFoco: campoEmFoco)
                .accessibilityLabel(Text(verbatim: Textos.rotuloDoCampo))
                .accessibilityIdentifier("campo-codigo-checkin")
                .onChange(of: codigo) { _, novo in
                    let digitos = String(novo.filter { $0.isASCII && $0.isNumber }.prefix(6))
                    if digitos != novo { codigo = digitos }
                }
        }
    }

    // MARK: Resultado

    /// O resultado e o botão: ancorados no pé, ou no fim da rolagem com texto de acessibilidade.
    @ViewBuilder
    private var rodape: some View {
        mensagem
        BotaoPrimario(verbatim: Textos.confirmar, carregando: ocupado) {
            campoEmFoco = false
            Task { await validacao.validarMedindo(codigo: codigo) }
        }
        .disabled(!ValidacaoDoCodigoViewModel.formatoValido(codigo) || ocupado)
        .accessibilityIdentifier("confirmar-codigo-checkin")
    }

    private var ocupado: Bool { validacao.resultado == .enviando }

    /// O resultado do envio, em tinta e logo acima do botão que o disparou (DESIGN.md, "Mensagem junto ao botão").
    @ViewBuilder
    private var mensagem: some View {
        switch validacao.resultado {
        case .aguardando, .verificado, .jaVerificado:
            EmptyView()
        case .enviando:
            MensagemJuntoAoBotao(verbatim: Textos.enviando)
                .accessibilityIdentifier("codigo-enviando")
        case .formatoInvalido:
            MensagemJuntoAoBotao(verbatim: Textos.formatoInvalido)
                .accessibilityIdentifier("codigo-formato-invalido")
        case .invalido:
            MensagemJuntoAoBotao(verbatim: Textos.invalido)
                .accessibilityIdentifier("codigo-invalido")
        case .foraDoRaio:
            MensagemJuntoAoBotao(verbatim: Textos.foraDoRaio)
                .accessibilityIdentifier("codigo-fora-do-raio")
        case let .chegueMaisPerto(metros):
            MensagemJuntoAoBotao(verbatim: Textos.chegueMaisPerto(metros))
                .accessibilityIdentifier("chegue-mais-perto")
        case .semLocalizacao:
            MensagemJuntoAoBotao(verbatim: Textos.semLocalizacao)
                .accessibilityIdentifier("codigo-sem-localizacao")
        case .bloqueado(.temporario):
            MensagemJuntoAoBotao(verbatim: Textos.bloqueadoPorUmTempo)
                .accessibilityIdentifier("codigo-bloqueado-temporario")
        case .bloqueado(.encerrado):
            MensagemJuntoAoBotao(verbatim: Textos.encerrado)
                .accessibilityIdentifier("codigo-bloqueado-encerrado")
        case .recursoDesligado:
            MensagemJuntoAoBotao(verbatim: Textos.indisponivel)
                .accessibilityIdentifier("codigo-indisponivel")
        case .respostaPerdida:
            MensagemJuntoAoBotao(verbatim: Textos.respostaPerdida)
                .accessibilityIdentifier("codigo-resposta-perdida")
        case let .falhou(erro):
            MensagemJuntoAoBotao(verbatim: MensagemDoErroAPI.texto(erro))
                .accessibilityIdentifier("codigo-falhou")
        }
    }

    /// O que a presença do turno faz com cada resultado, e quando a folha se fecha.
    private func aplicar(_ resultado: ValidacaoDoCodigoViewModel.Resultado) {
        switch resultado {
        case let .verificado(registro):
            presenca.aoValidarOCodigo(registro)
            fechar()
        case .jaVerificado:
            presenca.aoJaVerificadoPeloCodigo()
            fechar()
        case .bloqueado(.encerrado):
            presenca.aoEncerrarOCaminhoDoCodigo()
        default:
            break
        }
    }
}
