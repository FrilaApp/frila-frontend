import CoreLocation
import FrilaDominio
import Observation
import SwiftUI

/// O que a área de ação do detalhe (o rodapé) e o detalhe combinam entre si: os avisos da ação (candidatura que
/// falhou, candidatura retirada), se a rolagem chegou ao fim e se a candidatura já foi enviada. Quem está no
/// rodapé publica aqui, e o detalhe mostra o aviso logo acima do botão, na área de ação.
@MainActor @Observable
final class AvisosDoDetalhe {
    struct Aviso: Identifiable, Equatable {
        /// É também o identificador de acessibilidade do aviso.
        let id: String
        let texto: String
        let tom: AvisoFrila.Tom
    }

    private(set) var avisos: [Aviso] = []
    /// A última linha do conteúdo já apareceu: o rodapé vira barra, com o valor ao lado do botão. Antes disso, é só o
    /// botão. Sem rolagem (conteúdo curto) ou antes do iOS 18, fica na barra.
    var noFim = true
    /// A pessoa já se candidatou a esta vaga de seleção (a candidatura espera a escolha da casa).
    var candidaturaEnviada = false
    @ObservationIgnored private var donos: [String] = []

    /// Cada dono tem no máximo um aviso; `nil` tira o dele.
    func publicar(_ aviso: Aviso?, de dono: String) {
        var novos = avisos
        if let indice = donos.firstIndex(of: dono) {
            novos.remove(at: indice)
            donos.remove(at: indice)
        }
        if let aviso {
            novos.append(aviso)
            donos.append(dono)
        }
        if novos != avisos { avisos = novos }
    }
}

/// Textos novos do detalhe, do desenho do Fabrício (T3 e T3c). Os demais vêm de `TextosDoProfissional.Detalhe`.
private enum TextosDoDetalheDaVaga {
    static let seAceitar = String(localized: "Se aceitar, o turno é seu.", bundle: bundleApresentacao)
    static let casaEscolhe = String(localized: "O estabelecimento escolhe entre os interessados.", bundle: bundleApresentacao)
    static let voceSeCandidatou = String(localized: "Você se candidatou.", bundle: bundleApresentacao)
}

/// Detalhe da vaga (T3 do protótipo), com voltar nativo e sem barra de abas. Nunca mostra telefone nem documento do
/// estabelecimento. De cima para baixo: a casa e a reputação dela, a faixa do modo (urgência ou seleção), um cartão só
/// com "dá para ir?" e "compensa?", e o que está incluso. O rodapé fixo traz a ação e os avisos dela.
public struct TelaDetalheVaga<Acao: View>: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @Environment(BloqueiosDaSessao.self) private var bloqueiosDaSessao: BloqueiosDaSessao?
    @State private var bloqueiosLocais = BloqueiosDaSessao()
    private var bloqueios: BloqueiosDaSessao { bloqueiosDaSessao ?? bloqueiosLocais }
    @Bindable private var viewModel: DetalheVagaViewModel
    @State private var avisosDaAcao = AvisosDoDetalhe()
    @State private var navegarParaPerfil = false
    private let acao: (Vaga) -> Acao

    /// `acao` monta a área de Candidatar-me (#105); sem ela, o detalhe mostra só a vaga.
    public init(viewModel: DetalheVagaViewModel, @ViewBuilder acao: @escaping (Vaga) -> Acao) {
        self.viewModel = viewModel
        self.acao = acao
    }

    public var body: some View {
        #if DEBUG
        if let resultado = resultadoCapturaDebug {
            switch viewModel.estado {
            case let .carregado(vaga):
                TelaResultadoDaCandidatura(
                    vaga: vaga,
                    resultado: resultado,
                    api: viewModel.api,
                    voltarParaLista: { dismiss() }
                )
            case .carregando:
                ScrollView {
                    estadoCarregandoView
                        .padding(FrilaEspaco.grupo)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(FrilaCor.fundo)
                .task { await viewModel.carregar() }
            default:
                corpo
            }
        } else {
            corpo
        }
        #else
        corpo
        #endif
    }

    private var corpo: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                switch viewModel.estado {
                case .carregando:
                    estadoCarregandoView
                case let .carregado(vaga):
                    if bloqueios.contem(vaga.estabelecimento) {
                        naoEncontradaView
                    } else {
                        conteudo(vaga)
                    }
                case .naoEncontrada:
                    naoEncontradaView
                case .falha(.semConexao):
                    estadoSemConexaoView
                case .falha:
                    estadoErroView
                }
            }
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.top, FrilaEspaco.item)
            .padding(.bottom, FrilaEspaco.grupo)
        }
        .background(FrilaCor.fundo)
        .modifier(MonitoramentoDoFimDaRolagem(avisos: avisosDaAcao))
        .accessibilityIdentifier("tela-detalhe-vaga")
        .modifier(RodapeDoDetalhe(ativo: rodapeAtivo, avisos: avisosDaAcao) {
            if case let .carregado(vaga) = viewModel.estado, !bloqueios.contem(vaga.estabelecimento) {
                acao(vaga)
                    .environment(avisosDaAcao)
            }
        })
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(isPresented: $navegarParaPerfil) {
            if let api = viewModel.api, case let .carregado(vaga) = viewModel.estado {
                TelaPerfilPublico(perfil: vaga.estabelecimento, api: api, bloqueios: bloqueios)
            }
        }
        .navigationTitle(Text(verbatim: tituloDaNavegacao))
        .navigationBarTitleDisplayMode(.inline)
        .task { await medirAbertura(.detalheDaVaga, carregar: viewModel.carregar, pronto: detalheNaTela) }
    }

    private var tituloDaNavegacao: String {
        switch viewModel.estado {
        case let .carregado(vaga):
            if bloqueios.contem(vaga.estabelecimento) {
                return TextosDoProfissional.Detalhe.titulo
            }
            return ""
        default:
            return TextosDoProfissional.Detalhe.titulo
        }
    }

    private var rodapeAtivo: Bool {
        if case let .carregado(vaga) = viewModel.estado, !bloqueios.contem(vaga.estabelecimento) {
            return true
        }
        return false
    }

    /// Fim da medição de abertura (#73): a vaga da API publicada.
    private var detalheNaTela: @MainActor @Sendable () -> Bool {
        let viewModel = viewModel
        return { if case .carregado = viewModel.estado { true } else { false } }
    }

    // MARK: Estados da tela

    private var estadoCarregandoView: some View {
        EstadoCarregando()
            .accessibilityLabel(Text(verbatim: TextosDoProfissional.Detalhe.carregando))
    }

    private var naoEncontradaView: some View {
        AvisoFrila(verbatim: TextosDoProfissional.Detalhe.naoEncontrada, tom: .alerta)
            .accessibilityIdentifier("detalhe-nao-encontrada")
    }

    private var estadoErroView: some View {
        EstadoVazio(
            verbatim: TextosDoProfissional.Detalhe.erroTitulo,
            mensagem: TextosDoProfissional.Detalhe.erroApoio,
            rotuloDaAcao: TextosDoProfissional.Detalhe.tentarDeNovo
        ) {
            Task { await viewModel.carregar() }
        }
        .modifier(AnunciarAoAparecer(anuncio: .init(
            texto: "\(TextosDoProfissional.Detalhe.erroTitulo) \(TextosDoProfissional.Detalhe.erroApoio)",
            tom: .erro
        )))
    }

    private var estadoSemConexaoView: some View {
        EstadoVazio(
            verbatim: TextosDoProfissional.Detalhe.semConexaoTitulo,
            mensagem: TextosDoProfissional.Detalhe.semConexaoMensagem,
            rotuloDaAcao: TextosDoProfissional.Detalhe.tentarDeNovo
        ) {
            Task { await viewModel.carregar() }
        }
        .modifier(AnunciarAoAparecer(anuncio: .init(
            texto: "\(TextosDoProfissional.Detalhe.semConexaoTitulo) \(TextosDoProfissional.Detalhe.semConexaoMensagem)",
            tom: .alerta
        )))
    }

    // MARK: Conteúdo

    @ViewBuilder
    private func conteudo(_ vaga: Vaga) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            cabecalhoDaCasa(vaga)
            reputacaoDaCasa(vaga.estabelecimento.reputacao)
        }
        faixaDoModo(vaga)
        cartaoDaVaga(vaga)
        inclusos(vaga)
    }

    /// O nome da casa em caixa alta, no topo. Toca e abre o perfil público. O leitor de tela lê o nome original, com a
    /// função e o bairro, e não a caixa alta.
    @ViewBuilder
    private func cabecalhoDaCasa(_ vaga: Vaga) -> some View {
        let nome = Text(verbatim: vaga.estabelecimento.nome.uppercased(with: Locale(identifier: "pt_BR")))
            .font(FrilaTipo.tituloDaTela)
            .foregroundStyle(FrilaCor.texto)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvo, alignment: .leading)
            .contentShape(Rectangle())
        let rotulo = vaga.estabelecimento.nome + ". " + TextosDoProfissional.Detalhe.contextoDoHeader(
            funcao: vaga.funcao.nome, bairro: vaga.regiaoAdministrativa
        )
        if viewModel.api != nil {
            Button {
                guard !navegarParaPerfil else { return }
                navegarParaPerfil = true
            } label: { nome }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: rotulo))
            .accessibilityHint(Text("Ver perfil público", bundle: bundleApresentacao))
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("abrir-perfil-estabelecimento")
        } else {
            nome
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: rotulo))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("abrir-perfil-estabelecimento")
        }
    }

    private func reputacaoDaCasa(_ reputacao: Reputacao) -> some View {
        let texto = reputacao.semHistorico
            ? TextosDoProfissional.Detalhe.semAvaliacoes
            : TextosDoProfissional.Detalhe.reputacaoContagem(positivas: reputacao.positivas, total: reputacao.total)
                + " " + TextosDoProfissional.Detalhe.avaliacoesTrabalhariamLaDeNovo
        return Text(verbatim: texto)
            .font(FrilaTipo.apoio)
            .foregroundStyle(FrilaCor.textoSecundario)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("detalhe-reputacao")
    }

    /// A faixa do modo, sobre o fundo e sem cartão: o que o toque no botão vai fazer. Depois de enviada a candidatura,
    /// o selo diz que a casa ainda não respondeu.
    private func faixaDoModo(_ vaga: Vaga) -> some View {
        let urgencia = vaga.modoEfetivo(em: .now) == .urgencia
        let enviada = !urgencia && avisosDaAcao.candidaturaEnviada
        return VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            if urgencia {
                SeloDeStatus("Urgência", estilo: .urgencia, icone: "bolt.fill")
            } else if enviada {
                SeloDeStatus("Aguardando resposta", estilo: .contorno)
            } else {
                SeloDeStatus("Por seleção", estilo: .contorno)
            }
            Text(verbatim: urgencia ? TextosDoDetalheDaVaga.seAceitar
                 : enviada ? TextosDoDetalheDaVaga.voceSeCandidatou : TextosDoDetalheDaVaga.casaEscolhe)
                .font(FrilaTipo.fraseDoModo)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: urgencia ? TextosDoProfissional.Detalhe.notaUrgencia : TextosDoProfissional.Detalhe.notaSelecao)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Um cartão só, em dois grupos separados por uma linha fina: "dá para ir?" (função, quando, onde e traje) e
    /// "compensa?" (o valor, que é o maior texto, e as posições).
    private func cartaoDaVaga(_ vaga: Vaga) -> some View {
        let formatador = FormatadorFrila()
        let totalPosicoes = max(1, vaga.posicoes)
        let preenchidas = max(0, min(totalPosicoes, totalPosicoes - vaga.posicoesAbertas))
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                FrilaLinhaDeDado(icone: "briefcase") {
                    Text(verbatim: vaga.funcao.nome)
                }
                LinhaDeQuandoDaVaga(periodo: vaga.periodo)
                // "Começa em 3 horas" (ou "Em andamento"): a contagem que o detalhe sempre teve.
                FrilaContagemTurno(inicio: vaga.periodo.inicio, fim: vaga.periodo.fim)
            }
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                FrilaMapaComAcao(
                    ponto: CLLocationCoordinate2D(latitude: vaga.ponto.latitude, longitude: vaga.ponto.longitude),
                    abrirMapa: { abrirNoMapa(vaga) }
                )
                FrilaLinhaDeDado(icone: "mappin.and.ellipse") {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: vaga.local)
                        if !vaga.regiaoAdministrativa.isEmpty {
                            Text(verbatim: vaga.regiaoAdministrativa)
                                .foregroundStyle(FrilaCor.textoSecundario)
                        }
                        if let km = vaga.distanciaKm {
                            Text(verbatim: TextosDoProfissional.Detalhe.distanciaPontoBase(formatador.distancia(km)))
                                .foregroundStyle(FrilaCor.textoSecundario)
                        }
                    }
                }
                if let traje = vaga.traje, !traje.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    FrilaLinhaDeDado(icone: "tshirt") {
                        Text(verbatim: "\(TextosDoProfissional.Detalhe.traje): \(traje)")
                    }
                }
            }
            .padding(.top, FrilaEspaco.bloco)

            FrilaDivisoria()

            VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
                Text(verbatim: formatador.dinheiro(vaga.valor))
                    .font(FrilaTipo.valorEmDestaque)
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityLabel(Text(verbatim: formatador.dinheiroFalado(vaga.valor, por: "pessoa")))
                Text(verbatim: TextosDoProfissional.Detalhe.porPessoa)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                Text(verbatim: TextosDoProfissional.Detalhe.valorIntegral)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                FrilaLinhaDeDado(icone: "person.2") {
                    Text(verbatim: TextosDoProfissional.Detalhe.posicoesPreenchidas(preenchidas: preenchidas, total: totalPosicoes))
                }
                .padding(.top, FrilaEspaco.item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
    }

    /// "O que está incluso": uma linha por item, em grupo de linhas.
    private func inclusos(_ vaga: Vaga) -> some View {
        FrilaGrupoDeLinhas(verbatim: TextosDoProfissional.Detalhe.incluso, linhasComIcone: false) {
            ForEach(itensInclusos(da: vaga)) { item in
                LinhaDeItemIncluso(item: item)
            }
        }
    }

    private func itensInclusos(da vaga: Vaga) -> [FrilaItemIncluso] {
        var itens: [FrilaItemIncluso] = []
        itens.append(FrilaItemIncluso(
            rotulo: TextosDoProfissional.Detalhe.refeicao,
            valor: TextosDoProfissional.simNaoCapitalizado(vaga.inclusos.refeicao)
        ))
        itens.append(FrilaItemIncluso(
            rotulo: TextosDoProfissional.Detalhe.transporte,
            valor: TextosDoProfissional.simNaoCapitalizado(vaga.inclusos.transporte)
        ))
        itens.append(FrilaItemIncluso(
            rotulo: TextosDoProfissional.Detalhe.material,
            valor: vaga.inclusos.exigeMaterialProprio
                ? TextosDoProfissional.Detalhe.precisaLevar
                : TextosDoProfissional.Detalhe.naoPrecisaLevar
        ))
        itens.append(FrilaItemIncluso(
            rotulo: TextosDoProfissional.Detalhe.quemRecebe,
            valor: vaga.responsavelLocal
        ))
        if let rateio = vaga.participaRateio {
            itens.append(FrilaItemIncluso(
                rotulo: TextosDoProfissional.Detalhe.rateio,
                valor: TextosDoProfissional.simNaoCapitalizado(rateio)
            ))
        }
        if let observacoes = vaga.observacoes, !observacoes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            itens.append(FrilaItemIncluso(
                rotulo: TextosDoProfissional.Detalhe.observacoes,
                valor: observacoes
            ))
        }
        return itens
    }

    private func abrirNoMapa(_ vaga: Vaga) {
        if let url = DestinoDoMapaDaVaga.url(vaga) {
            openURL(url)
        }
    }

    #if DEBUG
    private var resultadoCapturaDebug: ResultadoDaCandidatura? {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-FRILA_CAPTURA"), idx + 1 < args.count else { return nil }
        let estado = args[idx + 1]
        switch estado {
        case "confirmada":
            let turnoID = UUID(uuidString: "22000000-0000-0000-0000-000000000001")!
            return .confirmada(turnoID: turnoID)
        case "pendente":
            return .pendente(candidaturaID: UUID(uuidString: "23000000-0000-0000-0000-000000000001")!)
        case "preenchida":
            return .vagaPreenchida
        case "encerrada":
            return .vagaEncerrada
        case "conflito":
            return .inelegivel(.turnoSobreposto)
        case "funcao-incompativel":
            return .inelegivel(.funcaoIncompativel)
        case "conta-suspensa":
            return .contaSuspensa
        default:
            return nil
        }
    }
    #endif
}

extension TelaDetalheVaga where Acao == EmptyView {
    public init(viewModel: DetalheVagaViewModel) {
        self.init(viewModel: viewModel) { _ in EmptyView() }
    }
}

/// Uma linha de "O que está incluso": o rótulo à esquerda e o valor à direita; com texto grande, um sobre o outro.
private struct LinhaDeItemIncluso: View {
    @Environment(\.dynamicTypeSize) private var tamanhoDoTexto
    let item: FrilaItemIncluso

    var body: some View {
        let disposicao = tamanhoDoTexto.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: FrilaEspaco.junto))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: FrilaEspaco.bloco))
        disposicao {
            Text(verbatim: item.rotulo)
                .foregroundStyle(FrilaCor.texto)
            if !tamanhoDoTexto.isAccessibilitySize { Spacer(minLength: 0) }
            Text(verbatim: item.valor)
                .foregroundStyle(FrilaCor.textoSecundario)
                .multilineTextAlignment(tamanhoDoTexto.isAccessibilitySize ? .leading : .trailing)
        }
        .font(FrilaTipo.corpo)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, FrilaMedidaDeLinha.margem)
        .padding(.vertical, FrilaEspaco.item)
        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvo, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Avisa o detalhe quando a rolagem chega ao fim (iOS 18 em diante), para o rodapé trocar de forma.
private struct MonitoramentoDoFimDaRolagem: ViewModifier {
    let avisos: AvisosDoDetalhe
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content.onScrollGeometryChange(for: Bool.self) { geometria in
                geometria.visibleRect.maxY >= geometria.contentSize.height - 1
            } action: { _, chegouAoFim in
                withAnimation(FrilaMovimento.animacao(.easeOut(duration: 0.24), reduzir: reduzirMovimento)) {
                    avisos.noFim = chegouAoFim
                }
            }
        } else {
            content
        }
    }
}

/// O rodapé fixo do detalhe (DESIGN.md, "Rodapé fixo"), em dois estados. Rolando, só o botão, de largura cheia, com o
/// conteúdo esmaecendo por baixo. No fim da rolagem, a barra de borda a borda, com um fio em cima e o valor junto do
/// botão. O aviso da ação (falha, retirada) vai logo acima do botão, em tinta.
private struct RodapeDoDetalhe<Rodape: View>: ViewModifier {
    let ativo: Bool
    let avisos: AvisosDoDetalhe
    @ViewBuilder let rodape: () -> Rodape

    func body(content: Content) -> some View {
        if ativo {
            content.safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                    ForEach(avisos.avisos) { aviso in
                        MensagemJuntoAoBotao(verbatim: aviso.texto)
                            .accessibilityIdentifier(aviso.id)
                    }
                    rodape()
                }
                .padding(.horizontal, FrilaEspaco.grupo)
                .padding(.top, avisos.noFim ? FrilaEspaco.bloco : FrilaEspaco.secao)
                .padding(.bottom, FrilaEspaco.item)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { fundo }
            }
        } else {
            content
        }
    }

    @ViewBuilder
    private var fundo: some View {
        if avisos.noFim {
            FrilaCor.fundo
                .overlay(alignment: .top) {
                    Rectangle().fill(FrilaCor.bordaDaNavegacao).frame(height: 1).accessibilityHidden(true)
                }
                .ignoresSafeArea(edges: .bottom)
        } else {
            // O conteúdo lê como passando por baixo do botão, não como cortado: uma rampa de 32 pt do transparente ao fundo.
            VStack(spacing: 0) {
                LinearGradient(colors: [FrilaCor.fundo.opacity(0), FrilaCor.fundo], startPoint: .top, endPoint: .bottom)
                    .frame(height: FrilaEspaco.secao)
                FrilaCor.fundo
            }
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
    }
}
