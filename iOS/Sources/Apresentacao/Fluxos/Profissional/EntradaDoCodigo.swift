import FrilaDominio
import SwiftUI
import UIKit

/// A leitura do código da casa pelo profissional (contrato 0.2.68): os 6 números digitados, ou o QR lido
/// pela câmera. Mede a distância no toque (só ela vai ao servidor, nunca a coordenada). Acima de 100 m
/// avisa "chegue mais perto" e não envia, para não gastar uma das 3 tentativas. Mantém o aviso de que a casa
/// também pode confirmar a chegada, que é a rede de segurança.
struct EntradaDoCodigo: View {
    private typealias Textos = TextosDoCheckinPorCodigo.Profissional

    let presenca: PresencaDoTurnoViewModel
    @State private var validacao: ValidacaoDoCodigoViewModel
    @State private var codigo = ""
    @State private var lendoQR = false
    @State private var semCamera = false
    @Environment(\.dismiss) private var fechar
    @FocusState private var campoEmFoco: Bool

    init(presenca: PresencaDoTurnoViewModel) {
        self.presenca = presenca
        _validacao = State(initialValue: presenca.criarValidacaoDoCodigo())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                    Text(verbatim: Textos.explicacao)
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)
                    if lendoQR {
                        leitorDoQR
                    } else {
                        campo
                    }
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
                    Button(Textos.fechar) { fechar() }.accessibilityIdentifier("fechar-entrada-do-codigo")
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
            if LeitorDeQRCode.disponivel {
                BotaoSecundario(verbatim: Textos.lerQR) { Task { await abrirCamera() } }
                    .disabled(ocupado)
                    .accessibilityIdentifier("ler-qr-checkin")
            }
            if semCamera { avisoSemCamera }
        }
    }

    // MARK: Ler o QR

    private var leitorDoQR: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: Textos.apontarParaOQR)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
            LeitorDeQRCode { lido in
                codigo = lido
                lendoQR = false
                Task { await validacao.validarMedindo(codigo: lido) }
            }
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: FrilaRaio.cartao))
            .accessibilityIdentifier("leitor-de-qr")
            BotaoSecundario(verbatim: Textos.digitar) { lendoQR = false }
                .accessibilityIdentifier("digitar-codigo-checkin")
        }
    }

    private func abrirCamera() async {
        switch await PermissaoDaCamera.pedir() {
        case .liberada:
            semCamera = false
            lendoQR = true
        case .negada, .naoPerguntada:
            semCamera = true
        }
    }

    @ViewBuilder
    private var avisoSemCamera: some View {
        Text(verbatim: Textos.semCamera)
            .font(FrilaTipo.meta)
            .foregroundStyle(FrilaCor.textoSecundario)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("sem-camera")
        if let ajustes = URL(string: UIApplication.openSettingsURLString) {
            Link(destination: ajustes) {
                Text(verbatim: Textos.abrirAjustes).font(FrilaTipo.meta.weight(.semibold)).foregroundStyle(FrilaCor.texto)
            }
            .frame(minHeight: FrilaMetrica.alvoMinimo)
            .accessibilityIdentifier("abrir-ajustes-camera")
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
                Text(verbatim: Textos.enviando).font(FrilaTipo.meta).foregroundStyle(FrilaCor.textoSecundario)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("codigo-enviando")
        case .formatoInvalido:
            AvisoFrila(verbatim: Textos.formatoInvalido, tom: .alerta).accessibilityIdentifier("codigo-formato-invalido")
        case .invalido:
            AvisoFrila(verbatim: Textos.invalido, tom: .erro).accessibilityIdentifier("codigo-invalido")
        case let .chegueMaisPerto(metros):
            AvisoFrila(verbatim: Textos.chegueMaisPerto(metros), tom: .alerta).accessibilityIdentifier("chegue-mais-perto")
        case .bloqueado(.temporario):
            AvisoFrila(verbatim: Textos.bloqueadoPorUmTempo, tom: .alerta).accessibilityIdentifier("codigo-bloqueado-temporario")
        case .bloqueado(.encerrado):
            AvisoFrila(verbatim: Textos.encerrado, tom: .alerta).accessibilityIdentifier("codigo-bloqueado-encerrado")
        case .recursoDesligado:
            AvisoFrila(verbatim: Textos.indisponivel, tom: .informativo).accessibilityIdentifier("codigo-indisponivel")
        case .respostaPerdida:
            AvisoFrila(verbatim: Textos.respostaPerdida, tom: .alerta).accessibilityIdentifier("codigo-resposta-perdida")
        case let .falhou(erro):
            AvisoFrila(verbatim: MensagemDoErroAPI.texto(erro), tom: .erro).accessibilityIdentifier("codigo-falhou")
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
