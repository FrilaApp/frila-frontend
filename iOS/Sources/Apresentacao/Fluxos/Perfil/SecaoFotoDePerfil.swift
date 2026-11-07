import FrilaDominio
import ImageIO
import PhotosUI
import SwiftUI
import UIKit

// MARK: Ambiente

private struct FerramentasDaFotoKey: EnvironmentKey {
    static let defaultValue = FerramentasDaFoto.indisponivel
}

public extension EnvironmentValues {
    /// As peças do aparelho da foto de perfil. O app as monta na raiz; sem elas a foto não sobe.
    var ferramentasDaFoto: FerramentasDaFoto {
        get { self[FerramentasDaFotoKey.self] }
        set { self[FerramentasDaFotoKey.self] = newValue }
    }
}

// MARK: Seção

/// A foto de perfil dentro de Meu perfil: mostra a foto, em qual dos sete estados ela está e as ações
/// que cabem nesse estado. Some quando o servidor desliga o recurso e não há foto para remover.
public struct SecaoFotoDePerfil: View {
    @Environment(\.ferramentasDaFoto) private var ferramentas
    private let api: any ApiCliente

    public init(api: any ApiCliente) {
        self.api = api
    }

    public var body: some View {
        ConteudoDaFotoDePerfil(api: api, ferramentas: ferramentas)
    }
}

private struct ConteudoDaFotoDePerfil: View {
    @State private var model: FotoDePerfilViewModel
    @State private var escolhida: PhotosPickerItem?
    @State private var lendoEscolhida = false
    @State private var paraRecortar: FotoParaRecortar?
    @State private var pedirConfirmacaoDeRemocao = false
    @State private var seletorAberto = false

    init(api: any ApiCliente, ferramentas: FerramentasDaFoto) {
        _model = State(initialValue: FotoDePerfilViewModel(api: api, ferramentas: ferramentas))
    }

    var body: some View {
        Group {
            if model.secaoVisivel {
                cartao
            } else if model.falhouAoCarregar {
                EstadoErro(verbatim: TextosFotoDePerfil.aviso(.indisponivelAgora)) { Task { await model.carregar() } }
            }
        }
        .task { await model.carregar() }
        .task(id: model.estaAcompanhando) { await model.acompanhar() }
        .photosPicker(isPresented: $seletorAberto, selection: $escolhida, matching: .images, photoLibrary: .shared())
        .onChange(of: escolhida) { _, item in
            guard let item else { return }
            Task { await ler(item) }
        }
        .fullScreenCover(item: $paraRecortar) { foto in
            TelaRecorteDeFoto(dados: foto.dados) { recorte in
                paraRecortar = nil
                Task { await model.enviar(original: foto.dados, recorte: recorte) }
            } aoCancelar: {
                paraRecortar = nil
            }
        }
        .confirmationDialog(
            TextosFotoDePerfil.confirmarRemocaoTitulo, isPresented: $pedirConfirmacaoDeRemocao, titleVisibility: .visible
        ) {
            Button(role: .destructive) { Task { await model.remover() } } label: { Text(verbatim: TextosFotoDePerfil.remover) }
            Button(role: .cancel) {} label: { Text(verbatim: TextosFotoDePerfil.cancelar) }
        } message: {
            Text(verbatim: TextosFotoDePerfil.confirmarRemocaoMensagem)
        }
    }

    // MARK: Cartão

    private var cartao: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosFotoDePerfil.titulo)
                .font(FrilaTipo.resumo)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
                HStack(alignment: .top, spacing: FrilaEspaco.medio) {
                    AvatarDaFoto(url: model.urlDaFoto)
                    estado
                }
                if model.enviandoAgora { andamento }
                if let aviso = model.aviso { avisoDeErro(aviso) }
                acoes
            }
            .padding(FrilaEspaco.medio)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous)
                    .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
            )
        }
        .accessibilityIdentifier("perfil-foto")
    }

    // MARK: Estado

    private var estado: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: titulo)
                .font(FrilaTipo.tituloDoCartao)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("perfil-foto-estado")
            Text(verbatim: texto)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("perfil-foto-texto")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titulo: String {
        guard let midia = model.midia else { return TextosFotoDePerfil.titulo }
        switch midia.estado {
        case .enviando: return TextosFotoDePerfil.tituloEnviando
        case .emAnalise: return TextosFotoDePerfil.tituloEmAnalise
        case .aprovada: return TextosFotoDePerfil.tituloAprovada
        case .recusada: return TextosFotoDePerfil.tituloRecusada
        case .naoPublicada: return TextosFotoDePerfil.tituloNaoPublicada
        case .ocultada: return TextosFotoDePerfil.tituloOcultada
        case .removida: return TextosFotoDePerfil.titulo
        }
    }

    private var texto: String {
        if !model.recursoLigado { return TextosFotoDePerfil.recursoDesligadoComFoto }
        guard let midia = model.midia else { return TextosFotoDePerfil.explicacao }
        switch midia.estado {
        case .enviando: return TextosFotoDePerfil.textoEnviando
        case .emAnalise: return TextosFotoDePerfil.textoEmAnalise
        case .aprovada: return TextosFotoDePerfil.textoAprovada
        case .recusada:
            return model.novaAnaliseJaPedida ? TextosFotoDePerfil.textoNovaAnaliseJaPedida : TextosFotoDePerfil.motivo(midia.motivoRecusa)
        case .naoPublicada:
            return model.novaAnaliseJaPedida ? TextosFotoDePerfil.textoNovaAnaliseJaPedida : TextosFotoDePerfil.textoNaoPublicada
        case .ocultada: return TextosFotoDePerfil.textoOcultada
        case .removida: return TextosFotoDePerfil.explicacao
        }
    }

    private var andamento: some View {
        HStack(spacing: FrilaEspaco.pequeno) {
            ProgressView()
            Text(verbatim: model.etapa == .preparando ? TextosFotoDePerfil.preparando
                 : model.etapa == .verificando ? TextosFotoDePerfil.verificando : TextosFotoDePerfil.enviando)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
        }
        .accessibilityElement(children: .combine)
    }

    private func avisoDeErro(_ aviso: FotoDePerfilViewModel.Aviso) -> some View {
        HStack(alignment: .top, spacing: FrilaEspaco.pequeno) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(FrilaCor.alerta)
                .accessibilityHidden(true)
            Text(verbatim: TextosFotoDePerfil.aviso(aviso))
                .font(FrilaTipo.aviso)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("perfil-foto-aviso")
    }

    // MARK: Ações

    @ViewBuilder
    private var acoes: some View {
        VStack(spacing: FrilaEspaco.pequeno) {
            if model.podeEscolherFoto {
                if model.midia == nil || model.midia?.estado == .aprovada {
                    BotaoPrimario(verbatim: model.midia == nil ? TextosFotoDePerfil.escolher : TextosFotoDePerfil.trocar) {
                        seletorAberto = true
                    }
                    .accessibilityIdentifier("perfil-foto-escolher")
                } else if model.midia?.estado == .recusada || model.midia?.estado == .naoPublicada || model.midia?.estado == .ocultada {
                    BotaoPrimario(verbatim: TextosFotoDePerfil.tentarOutra) { seletorAberto = true }
                        .accessibilityIdentifier("perfil-foto-tentar-outra")
                }
            }
            if model.podePedirNovaAnalise {
                BotaoSecundario(verbatim: TextosFotoDePerfil.pedirNovaAnalise) { Task { await model.pedirNovaAnalise() } }
                    .accessibilityIdentifier("perfil-foto-nova-analise")
            }
            if model.podeRemover {
                Button { pedirConfirmacaoDeRemocao = true } label: {
                    Text(verbatim: TextosFotoDePerfil.remover).capsulaDestrutiva()
                }
                .buttonStyle(.tatil)
                .accessibilityIdentifier("perfil-foto-remover")
            }
        }
        .disabled(lendoEscolhida)
    }

    // MARK: Foto escolhida

    /// Lê os bytes do seletor com prazo: a leitura é uma chamada do sistema e não pode girar sem fim.
    private func ler(_ item: PhotosPickerItem) async {
        lendoEscolhida = true
        defer { lendoEscolhida = false; escolhida = nil }
        let dados = await executarComPrazo(.seconds(30)) { try? await item.loadTransferable(type: Data.self) } ?? nil
        guard let dados, !dados.isEmpty else { return model.registrarImagemInvalida() }
        paraRecortar = FotoParaRecortar(dados: dados)
    }
}

private struct FotoParaRecortar: Identifiable {
    let id = UUID()
    let dados: Data
}

// MARK: Avatar

/// O círculo da foto. Sem foto (ou enquanto carrega) mostra a silhueta; não depende só de cor para dizer o estado.
struct AvatarDaFoto: View {
    let url: URL?
    private let lado: CGFloat = 72

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { fase in
                    switch fase {
                    case let .success(imagem): imagem.resizable().scaledToFill()
                    default: silhueta
                    }
                }
            } else {
                silhueta
            }
        }
        .frame(width: lado, height: lado)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(FrilaCor.divisoria, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: url == nil ? TextosFotoDePerfil.semFotoAcessibilidade : TextosFotoDePerfil.fotoAcessibilidade))
        .accessibilityAddTraits(.isImage)
        .accessibilityIdentifier("perfil-foto-imagem")
    }

    private var silhueta: some View {
        ZStack {
            FrilaCor.controle
            Image(systemName: "person.fill")
                .font(FrilaTipo.tituloGrande)
                .foregroundStyle(FrilaCor.textoSecundario)
        }
    }
}

// MARK: Recorte

/// Recorte quadrado 1:1: a imagem se arrasta e se aproxima por trás de um quadrado fixo. O resultado
/// é só `zoom` e deslocamento normalizados (`RecorteQuadrado`); quem corta de verdade é o preparador.
struct TelaRecorteDeFoto: View {
    let dados: Data
    let aoUsar: (RecorteQuadrado) -> Void
    let aoCancelar: () -> Void

    @State private var imagem: UIImage?
    @State private var zoom: Double = 1
    @State private var base: Double = 1
    @State private var deslocamento: CGSize = .zero
    @State private var deslocamentoBase: CGSize = .zero
    /// O lado do quadrado como a tela o desenhou: o deslocamento só vira fração com este lado.
    @State private var ladoDoQuadro: CGFloat = 0

    private let ladoMaximo: CGFloat = 360

    var body: some View {
        NavigationStack {
            VStack(spacing: FrilaEspaco.grande) {
                Text(verbatim: TextosFotoDePerfil.recorteInstrucao)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                GeometryReader { geometria in
                    let lado = min(geometria.size.width, ladoMaximo)
                    quadro(lado: lado)
                        .frame(width: lado, height: lado)
                        .frame(maxWidth: .infinity)
                        .onAppear { ladoDoQuadro = lado }
                        .onChange(of: lado) { _, novo in ladoDoQuadro = novo }
                }
                .frame(maxHeight: ladoMaximo)

                controlesDeZoom

                BotaoPrimario(verbatim: TextosFotoDePerfil.recorteUsar) { aoUsar(recorteAtual) }
                    .disabled(imagem == nil)
                    .accessibilityIdentifier("perfil-foto-recorte-usar")
            }
            .padding(FrilaEspaco.medio)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(FrilaCor.fundo)
            .navigationTitle(Text(verbatim: TextosFotoDePerfil.recorteTitulo))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: aoCancelar) { Text(verbatim: TextosFotoDePerfil.cancelar) }
                        .accessibilityIdentifier("perfil-foto-recorte-cancelar")
                }
            }
        }
        .task { imagem = await Self.imagemParaExibir(dados) }
    }

    private func quadro(lado: CGFloat) -> some View {
        ZStack {
            FrilaCor.controle
            if let imagem {
                let escala = Self.escalaBase(imagem: imagem, lado: lado) * zoom
                let limite = Self.limites(imagem: imagem, lado: lado, zoom: zoom)
                Image(uiImage: imagem)
                    .resizable()
                    .frame(width: imagem.size.width * escala, height: imagem.size.height * escala)
                    .offset(x: min(max(deslocamento.width, -limite.width), limite.width),
                            y: min(max(deslocamento.height, -limite.height), limite.height))
            } else {
                ProgressView()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: FrilaRaio.pequeno, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: FrilaRaio.pequeno, style: .continuous).strokeBorder(FrilaCor.borda, lineWidth: 2))
        .contentShape(Rectangle())
        .gesture(arrastar(lado: lado).simultaneously(with: aproximar(lado: lado)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: TextosFotoDePerfil.recorteArea))
        .accessibilityHint(Text(verbatim: TextosFotoDePerfil.recorteInstrucao))
        .accessibilityAdjustableAction { direcao in
            switch direcao {
            case .increment: mudarZoom(0.25)
            case .decrement: mudarZoom(-0.25)
            @unknown default: break
            }
        }
        .accessibilityIdentifier("perfil-foto-recorte-area")
    }

    private var controlesDeZoom: some View {
        HStack(spacing: FrilaEspaco.medio) {
            BotaoSecundario(verbatim: TextosFotoDePerfil.recorteAfastar) { mudarZoom(-0.25) }
                .disabled(zoom <= 1)
            BotaoSecundario(verbatim: TextosFotoDePerfil.recorteAproximar) { mudarZoom(0.25) }
                .disabled(zoom >= 4)
        }
    }

    private func mudarZoom(_ passo: Double) {
        zoom = min(max(zoom + passo, 1), 4)
        base = zoom
    }

    private func arrastar(lado: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { valor in
                deslocamento = CGSize(
                    width: deslocamentoBase.width + valor.translation.width,
                    height: deslocamentoBase.height + valor.translation.height
                )
            }
            .onEnded { _ in
                guard let imagem else { return }
                let limite = Self.limites(imagem: imagem, lado: lado, zoom: zoom)
                deslocamento = CGSize(
                    width: min(max(deslocamento.width, -limite.width), limite.width),
                    height: min(max(deslocamento.height, -limite.height), limite.height)
                )
                deslocamentoBase = deslocamento
            }
    }

    private func aproximar(lado: CGFloat) -> some Gesture {
        MagnifyGesture()
            .onChanged { valor in zoom = min(max(base * valor.magnification, 1), 4) }
            .onEnded { _ in base = zoom }
    }

    /// O recorte em frações: a imagem arrastada para a esquerda mostra a direita (deslocamento do recorte é o oposto).
    private var recorteAtual: RecorteQuadrado {
        guard let imagem, ladoDoQuadro > 0 else { return .centralizado }
        let lado = ladoDoQuadro
        let limite = Self.limites(imagem: imagem, lado: lado, zoom: zoom)
        let dx = limite.width > 0 ? -Double(min(max(deslocamento.width, -limite.width), limite.width) / limite.width) : 0
        let dy = limite.height > 0 ? -Double(min(max(deslocamento.height, -limite.height), limite.height) / limite.height) : 0
        return RecorteQuadrado(zoom: zoom, deslocamentoX: dx, deslocamentoY: dy)
    }

    /// Escala em que o lado menor da imagem preenche o quadrado.
    static func escalaBase(imagem: UIImage, lado: CGFloat) -> CGFloat {
        let menor = min(imagem.size.width, imagem.size.height)
        return menor > 0 ? lado / menor : 1
    }

    /// Quanto a imagem pode andar para cada lado sem deixar o quadrado vazio.
    static func limites(imagem: UIImage, lado: CGFloat, zoom: Double) -> CGSize {
        let escala = escalaBase(imagem: imagem, lado: lado) * zoom
        return CGSize(
            width: max(0, (imagem.size.width * escala - lado) / 2),
            height: max(0, (imagem.size.height * escala - lado) / 2)
        )
    }

    /// Versão reduzida e já girada para mostrar na tela, sem segurar a foto inteira (até 48 MP) na memória.
    private static func imagemParaExibir(_ dados: Data) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let fonte = CGImageSourceCreateWithData(dados as CFData, nil) else { return nil }
            let opcoes: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: 1600,
            ]
            return CGImageSourceCreateThumbnailAtIndex(fonte, 0, opcoes as CFDictionary).map { UIImage(cgImage: $0) }
        }.value
    }
}
