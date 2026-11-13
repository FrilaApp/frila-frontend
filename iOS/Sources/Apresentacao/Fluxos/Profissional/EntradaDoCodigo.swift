import FrilaDominio
import SwiftUI
import UIKit

/// A leitura do código da casa pelo profissional (contrato 0.2.68, direção semiautomática de 10/11/2026).
/// Os 6 números digitados diretamente pelo profissional. Mede a distância no toque (apenas a distância
/// vai ao servidor, nunca a coordenada). Acima do raio configurado avisa "chegue mais perto" e não envia,
/// preservando as tentativas do profissional. Sem QR code nesta etapa.
public struct EntradaDoCodigo: View {
    private typealias Textos = TextosDoCheckinPorCodigo.Profissional

    public let presenca: PresencaDoTurnoViewModel
    @State private var validacao: ValidacaoDoCodigoViewModel
    @State private var codigo = ""
    @Environment(\.dismiss) private var fechar
    @FocusState private var campoEmFoco: Bool

    public init(presenca: PresencaDoTurnoViewModel) {
        self.presenca = presenca
        _validacao = State(initialValue: presenca.criarValidacaoDoCodigo())
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                    Text(verbatim: Textos.explicacao)
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)

                    campo

                    mensagem

                    Text(verbatim: Textos.casaConfirma)
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("aviso-casa-confirma")
                }
                .padding(FrilaEspaco.medio)
            }
            .background(FrilaCor.fundo.ignoresSafeArea())
            .navigationTitle(Textos.titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Textos.fechar) { fechar() }
                        .accessibilityIdentifier("fechar-entrada-do-codigo")
                }
            }
        }
        .accessibilityIdentifier("entrada-do-codigo")
        .onChange(of: validacao.resultado) { _, novo in aplicar(novo) }
    }

    // MARK: Digitar

    private var campo: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: Textos.rotuloDoCampo)
                .font(FrilaTipo.rotuloDoCampo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityHidden(true)
            TextField("", text: $codigo, prompt: Text(verbatim: "000000"))
                .keyboardType(.numberPad)
                .font(FrilaTipo.valorEmDestaque.monospacedDigit())
                .tracking(4)
                .multilineTextAlignment(.center)
                .focused($campoEmFoco)
                .padding(.horizontal, FrilaEspaco.medio)
                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
                .background(FrilaCor.superficieDoCampo, in: RoundedRectangle(cornerRadius: FrilaRaio.pequeno))
                .accessibilityLabel(Text(verbatim: Textos.rotuloDoCampo))
                .accessibilityIdentifier("campo-codigo-checkin")
                .onChange(of: codigo) { _, novo in
                    let digitos = String(novo.filter { $0.isASCII && $0.isNumber }.prefix(6))
                    if digitos != novo { codigo = digitos }
                }
            BotaoPrimario(verbatim: Textos.confirmar, carregando: ocupado) {
                campoEmFoco = false
                Task { await validacao.validarMedindo(codigo: codigo) }
            }
            .disabled(!ValidacaoDoCodigoViewModel.formatoValido(codigo) || ocupado)
            .accessibilityIdentifier("confirmar-codigo-checkin")
        }
    }

    // MARK: Resultado

    private var ocupado: Bool { validacao.resultado == .enviando }

    @ViewBuilder
    private var mensagem: some View {
        switch validacao.resultado {
        case .aguardando, .verificado, .jaVerificado:
            EmptyView()
        case .enviando:
            HStack(spacing: FrilaEspaco.pequeno) {
                ProgressView()
                Text(verbatim: Textos.enviando)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("codigo-enviando")
        case .formatoInvalido:
            AvisoFrila(verbatim: Textos.formatoInvalido, tom: .alerta)
                .accessibilityIdentifier("codigo-formato-invalido")
        case .invalido:
            AvisoFrila(verbatim: Textos.invalido, tom: .erro)
                .accessibilityIdentifier("codigo-invalido")
        case .foraDoRaio:
            AvisoFrila(verbatim: Textos.foraDoRaio, tom: .alerta)
                .accessibilityIdentifier("codigo-fora-do-raio")
        case let .chegueMaisPerto(metros):
            AvisoFrila(verbatim: Textos.chegueMaisPerto(metros), tom: .alerta)
                .accessibilityIdentifier("chegue-mais-perto")
        case .semLocalizacao:
            AvisoFrila(verbatim: Textos.semLocalizacao, tom: .alerta)
                .accessibilityIdentifier("codigo-sem-localizacao")
        case .bloqueado(.temporario):
            AvisoFrila(verbatim: Textos.bloqueadoPorUmTempo, tom: .alerta)
                .accessibilityIdentifier("codigo-bloqueado-temporario")
        case .bloqueado(.encerrado):
            AvisoFrila(verbatim: Textos.encerrado, tom: .alerta)
                .accessibilityIdentifier("codigo-bloqueado-encerrado")
        case .recursoDesligado:
            AvisoFrila(verbatim: Textos.indisponivel, tom: .informativo)
                .accessibilityIdentifier("codigo-indisponivel")
        case .respostaPerdida:
            AvisoFrila(verbatim: Textos.respostaPerdida, tom: .alerta)
                .accessibilityIdentifier("codigo-resposta-perdida")
        case let .falhou(erro):
            AvisoFrila(verbatim: MensagemDoErroAPI.texto(erro), tom: .erro)
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
