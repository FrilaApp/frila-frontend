import FrilaDominio
import Observation
import SwiftUI

/// Os avisos da área de ação do detalhe (candidatura que falhou, candidatura retirada).
/// Quem está no rodapé publica o aviso aqui, e o detalhe o mostra dentro da rolagem; o rodapé
/// fica com a área de ação e o preço.
@MainActor @Observable
final class AvisosDoDetalhe {
    struct Aviso: Identifiable, Equatable {
        /// É também o identificador de acessibilidade do aviso.
        let id: String
        let texto: String
        let tom: AvisoFrila.Tom
    }

    private(set) var avisos: [Aviso] = []
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

/// Detalhe da vaga (#104), no quadro "Vaga" do MidFi do Fabrício. Nunca mostra telefone nem documento: o contrato não os devolve aqui, e o
/// contato só aparece depois da confirmação (RN10). O aviso da RN10 vem no rodapé fixo antes de Aceitar turno / Candidatar-me.
public struct TelaDetalheVaga<Acao: View>: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @Environment(BloqueiosDaSessao.self) private var bloqueiosDaSessao: BloqueiosDaSessao?
    @State private var bloqueiosLocais = BloqueiosDaSessao()
    private var bloqueios: BloqueiosDaSessao { bloqueiosDaSessao ?? bloqueiosLocais }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @Bindable private var viewModel: DetalheVagaViewModel
    @State private var avisosDaAcao = AvisosDoDetalhe()
    private let acao: (Vaga) -> Acao
    private static var idDosAvisos: String { "avisos-da-acao" }

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
                EstadoCarregando()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(FrilaCor.fundo)
                    .task { await viewModel.carregar() }
            default:
                corpoPrincipal
            }
        } else {
            corpoPrincipal
        }
        #else
        corpoPrincipal
        #endif
    }

    private var corpoPrincipal: some View {
        ScrollViewReader { rolagem in
            corpo
                // O aviso novo entra na rolagem, que pode estar em outro ponto: a tela vai até ele.
                .onChange(of: avisosDaAcao.avisos) { _, avisos in
                    guard !avisos.isEmpty else { return }
                    withAnimation(FrilaMovimento.animacao(reduzir: reduzirMovimento)) {
                        rolagem.scrollTo(Self.idDosAvisos, anchor: .top)
                    }
                }
        }
    }

    private var corpo: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                switch viewModel.estado {
                case .carregando:
                    EstadoCarregando()
                case let .carregado(vaga):
                    if bloqueios.contem(vaga.estabelecimento) {
                        AvisoFrila(verbatim: TextosDoProfissional.Detalhe.naoEncontrada, tom: .alerta)
                            .accessibilityIdentifier("detalhe-nao-encontrada")
                    } else {
                        conteudo(vaga)
                    }
                case .naoEncontrada:
                    AvisoFrila(verbatim: TextosDoProfissional.Detalhe.naoEncontrada, tom: .alerta)
                        .accessibilityIdentifier("detalhe-nao-encontrada")
                case .falha(.semConexao):
                    AvisoFrila(verbatim: TextosDoProfissional.Lista.semConexaoMensagem, tom: .alerta)
                    BotaoSecundario("Tentar novamente") { Task { await viewModel.carregar() } }
                case .falha:
                    EstadoErro(verbatim: TextosDoProfissional.Detalhe.erroMensagem) { Task { await viewModel.carregar() } }
                }
            }
            .padding(FrilaEspaco.medio)
        }
        .accessibilityIdentifier("tela-detalhe-vaga")
        .modifier(BarraInferiorDoDetalhe(ativo: rodapeAtivo) {
            if case let .carregado(vaga) = viewModel.estado, !bloqueios.contem(vaga.estabelecimento) {
                VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
                    avisoRN10View(vaga)
                    acao(vaga)
                        .environment(avisosDaAcao)
                }
            }
        })
        .background(FrilaCor.fundo)
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle(Text(verbatim: TextosDoProfissional.Detalhe.titulo))
        .navigationBarTitleDisplayMode(.inline)
        .task { await medirAbertura(.detalheDaVaga, carregar: viewModel.carregar, pronto: detalheNaTela) }
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

    @ViewBuilder
    private func conteudo(_ vaga: Vaga) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: vaga.funcao.nome)
                .font(FrilaTipo.tituloGrande)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: vaga.estabelecimento.nome)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.textoSecundario)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        cartaoResumo(vaga)

        cartaoLocal(vaga)

        cartaoInclusos(vaga)

        if let api = viewModel.api {
            NavigationLink {
                TelaPerfilPublico(perfil: vaga.estabelecimento, api: api, bloqueios: bloqueios)
            } label: {
                Text(verbatim: TextosDaSeguranca.verPerfil)
                    .font(FrilaTipo.meta.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                    .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                    .padding(.horizontal, FrilaEspaco.minimo)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("abrir-perfil-estabelecimento")
        }

        cartaoReputacao(vaga.estabelecimento.reputacao)

        if !avisosDaAcao.avisos.isEmpty {
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                ForEach(avisosDaAcao.avisos) { aviso in
                    avisoLocal(aviso)
                        .accessibilityIdentifier(aviso.id)
                }
            }
            .id(Self.idDosAvisos)
        }

        if let api = viewModel.api {
            AcoesDeSeguranca(perfil: vaga.estabelecimento, api: api, bloqueios: bloqueios)
                .id(vaga.estabelecimento.id)
        }
    }

    private func cartaoResumo(_ vaga: Vaga) -> some View {
        let formatador = FormatadorFrila()
        let totalPosicoes = max(1, vaga.posicoes)
        let preenchidas = max(0, min(totalPosicoes, totalPosicoes - vaga.posicoesAbertas))

        return VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                    blocoQuando(vaga)
                    blocoHorario(vaga)
                    blocoValor(vaga, formatador: formatador)
                    blocoPosicoes(preenchidas: preenchidas, total: totalPosicoes)
                }
            } else {
                Grid(alignment: .leading, horizontalSpacing: FrilaEspaco.medio, verticalSpacing: FrilaEspaco.medio) {
                    GridRow {
                        blocoQuando(vaga)
                        blocoHorario(vaga)
                    }
                    GridRow {
                        blocoValor(vaga, formatador: formatador)
                        blocoPosicoes(preenchidas: preenchidas, total: totalPosicoes)
                    }
                }
            }

            Rectangle()
                .fill(FrilaCor.divisoria)
                .frame(height: 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                Text(verbatim: vaga.modoEfetivo(em: .now) == .urgencia
                    ? TextosDoProfissional.Detalhe.notaUrgencia
                    : TextosDoProfissional.Detalhe.notaSelecao
                )
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)

                Text(verbatim: TextosDoProfissional.Detalhe.valorIntegral)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
    }

    private func blocoQuando(_ vaga: Vaga) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
            Text(verbatim: TextosDoProfissional.Detalhe.quando)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
            Text(verbatim: formatarQuando(vaga.periodo.inicio))
                .font(FrilaTipo.resumo)
                .foregroundStyle(FrilaCor.texto)
        }
        .accessibilityElement(children: .combine)
    }

    private func blocoHorario(_ vaga: Vaga) -> some View {
        let inicio = vaga.periodo.inicio
        let fim = vaga.periodo.fim
        let cal = calendarioSp
        let cruzaDia = !cal.isDate(inicio, inSameDayAs: fim)

        return VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
            Text(verbatim: TextosDoProfissional.Detalhe.horario)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
            Text(verbatim: TextosDoProfissional.Detalhe.intervaloHorario(inicio: formatarHora(inicio), fim: formatarHora(fim)))
                .font(FrilaTipo.resumo)
                .foregroundStyle(FrilaCor.texto)
            if cruzaDia {
                Text(verbatim: TextosDoProfissional.Detalhe.horarioTermina(formatarDiaMesCurto(fim)))
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func blocoValor(_ vaga: Vaga, formatador: FormatadorFrila) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
            Text(verbatim: TextosDoProfissional.Detalhe.valor)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
            Text(verbatim: formatador.dinheiro(vaga.valor))
                .font(FrilaTipo.resumo)
                .monospacedDigit()
                .foregroundStyle(FrilaCor.texto)
            Text(verbatim: TextosDoProfissional.Detalhe.porPessoa)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
        }
        .accessibilityElement(children: .combine)
    }

    private func blocoPosicoes(preenchidas: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
            Text(verbatim: TextosDoProfissional.Detalhe.posicoes)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
            Text(verbatim: TextosDoProfissional.Detalhe.posicoesPreenchidas(preenchidas: preenchidas, total: total))
                .font(FrilaTipo.resumo)
                .foregroundStyle(FrilaCor.texto)
            HStack(spacing: FrilaEspaco.minimo) {
                ForEach(0..<total, id: \.self) { indice in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(indice < preenchidas ? FrilaCor.texto : FrilaCor.controle)
                        .frame(height: 4)
                }
            }
            .padding(.top, FrilaEspaco.fio)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private func cartaoLocal(_ vaga: Vaga) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
            VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                HStack(alignment: .top, spacing: FrilaEspaco.pequeno) {
                    Image(systemName: "mappin")
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .frame(width: 16, height: 16)
                        .accessibilityHidden(true)
                    Text(verbatim: vaga.local)
                        .font(FrilaTipo.resumo)
                        .foregroundStyle(FrilaCor.texto)
                }
                if let km = vaga.distanciaKm {
                    Text(verbatim: TextosDoProfissional.Detalhe.distanciaPontoBase(FormatadorFrila().distancia(km)))
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .padding(.leading, 24)
                }
            }
            BotaoSecundario(verbatim: TextosDoProfissional.Detalhe.abrirNoMapa) {
                abrirNoMapa(vaga.local)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
    }

    private func abrirNoMapa(_ endereco: String) {
        var componentes = URLComponents()
        componentes.scheme = "maps"
        componentes.queryItems = [URLQueryItem(name: "q", value: endereco)]
        if let url = componentes.url {
            openURL(url)
        }
    }

    private func cartaoInclusos(_ vaga: Vaga) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoProfissional.Detalhe.incluso)
                .font(FrilaTipo.microRotulo)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(FrilaCor.textoSecundario)
                .padding(.horizontal, FrilaEspaco.minimo)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                linhaIncluso(rotulo: TextosDoProfissional.Detalhe.refeicao, valor: TextosDoProfissional.simNaoCapitalizado(vaga.inclusos.refeicao))
                divisorDeLinha
                linhaIncluso(rotulo: TextosDoProfissional.Detalhe.transporte, valor: TextosDoProfissional.simNaoCapitalizado(vaga.inclusos.transporte))
                divisorDeLinha
                linhaIncluso(
                    rotulo: TextosDoProfissional.Detalhe.material,
                    valor: vaga.inclusos.exigeMaterialProprio ? TextosDoProfissional.Detalhe.precisaLevar : TextosDoProfissional.Detalhe.naoPrecisaLevar
                )
                if let traje = vaga.traje, !traje.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    divisorDeLinha
                    linhaIncluso(rotulo: TextosDoProfissional.Detalhe.traje, valor: traje)
                }
                divisorDeLinha
                linhaIncluso(rotulo: TextosDoProfissional.Detalhe.quemRecebe, valor: vaga.responsavelLocal)
                if let rateio = vaga.participaRateio {
                    divisorDeLinha
                    linhaIncluso(rotulo: TextosDoProfissional.Detalhe.rateio, valor: TextosDoProfissional.simNaoCapitalizado(rateio))
                }
                if let observacoes = vaga.observacoes, !observacoes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    divisorDeLinha
                    linhaIncluso(rotulo: TextosDoProfissional.Detalhe.observacoes, valor: observacoes)
                }
            }
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous).strokeBorder(FrilaCor.divisoria, lineWidth: 1))
        }
    }

    private func linhaIncluso(rotulo: String, valor: String) -> some View {
        HStack(alignment: .center, spacing: FrilaEspaco.compacto) {
            Text(verbatim: rotulo)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
            Spacer(minLength: FrilaEspaco.medio)
            Text(verbatim: valor)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: FrilaMetrica.alturaDoCampo)
        .padding(.horizontal, FrilaEspaco.medio)
    }

    private var divisorDeLinha: some View {
        Rectangle()
            .fill(FrilaCor.divisoria)
            .frame(height: 1)
            .padding(.leading, FrilaEspaco.medio)
            .accessibilityHidden(true)
    }

    private func cartaoReputacao(_ reputacao: Reputacao) -> some View {
        Group {
            if reputacao.semHistorico {
                Text(verbatim: TextosDoProfissional.Detalhe.semAvaliacoes)
                    .font(FrilaTipo.resumo)
                    .foregroundStyle(FrilaCor.texto)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: FrilaEspaco.medio) {
                        Text(verbatim: TextosDoProfissional.Detalhe.reputacaoContagem(positivas: reputacao.positivas, total: reputacao.total))
                            .font(FrilaTipo.secao)
                            .foregroundStyle(FrilaCor.texto)
                            .fixedSize()
                        Text(verbatim: TextosDoProfissional.Detalhe.avaliacoesTrabalhariamLaDeNovo)
                            .font(FrilaTipo.meta)
                            .foregroundStyle(FrilaCor.textoSecundario)
                    }
                    VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                        Text(verbatim: TextosDoProfissional.Detalhe.reputacaoContagem(positivas: reputacao.positivas, total: reputacao.total))
                            .font(FrilaTipo.secao)
                            .foregroundStyle(FrilaCor.texto)
                        Text(verbatim: TextosDoProfissional.Detalhe.avaliacoesTrabalhariamLaDeNovo)
                            .font(FrilaTipo.meta)
                            .foregroundStyle(FrilaCor.textoSecundario)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .cartaoFrila()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("detalhe-reputacao")
    }

    private func avisoRN10View(_ vaga: Vaga) -> some View {
        HStack(alignment: .top, spacing: FrilaEspaco.pequeno) {
            Image(systemName: "phone")
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.texto)
                .frame(width: 16, height: 16, alignment: .top)
                .accessibilityHidden(true)
            Text(verbatim: avisoRN10(vaga))
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.texto)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("aviso-rn10")
    }

    private func avisoLocal(_ aviso: AvisosDoDetalhe.Aviso) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.pequeno) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(FrilaCor.texto)
                .accessibilityHidden(true)
            Text(verbatim: aviso.texto)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
        }
        .padding(FrilaEspaco.medio)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FrilaCor.controle, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous)
                .strokeBorder(aviso.tom == .erro ? FrilaCor.texto : Color.clear, lineWidth: 2)
        )
    }

    private var calendarioSp: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .current
        cal.locale = Locale(identifier: "pt_BR")
        return cal
    }

    private func formatarQuando(_ data: Date) -> String {
        let cal = calendarioSp
        let df = DateFormatter()
        df.calendar = cal
        df.timeZone = cal.timeZone
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "EEE, dd/MM"
        let formatada = df.string(from: data).replacingOccurrences(of: ".", with: "")
        if cal.isDateInToday(data) {
            return String(format: String(localized: "Hoje, %@", bundle: bundleApresentacao), formatada)
        } else if cal.isDateInTomorrow(data) {
            return String(format: String(localized: "Amanhã, %@", bundle: bundleApresentacao), formatada)
        } else {
            return formatada.prefix(1).capitalized + formatada.dropFirst()
        }
    }

    private func formatarHora(_ data: Date) -> String {
        let cal = calendarioSp
        let minutos = cal.component(.minute, from: data)
        let df = DateFormatter()
        df.calendar = cal
        df.timeZone = cal.timeZone
        df.locale = Locale(identifier: "pt_BR")
        if minutos == 0 {
            df.dateFormat = "HH'h'"
        } else {
            df.dateFormat = "HH'h'mm"
        }
        return df.string(from: data)
    }

    private func formatarDiaMesCurto(_ data: Date) -> String {
        let df = DateFormatter()
        df.calendar = calendarioSp
        df.timeZone = calendarioSp.timeZone
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "EEE dd/MM"
        return df.string(from: data).replacingOccurrences(of: ".", with: "")
    }

    /// Na vaga de seleção o contato só é mostrado se a casa escolher a candidatura (RN10).
    private func avisoRN10(_ vaga: Vaga) -> String {
        vaga.modoEfetivo(em: .now) == .selecao
            ? TextosDoProfissional.Detalhe.avisoRN10Selecao(vaga.estabelecimento.nome)
            : TextosDoProfissional.Detalhe.avisoRN10Urgencia(vaga.estabelecimento.nome)
    }

    #if DEBUG
    private var resultadoCapturaDebug: ResultadoDaCandidatura? {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-FRILA_CAPTURA"), idx + 1 < args.count else { return nil }
        let estado = args[idx + 1]
        switch estado {
        case "preenchida":
            return .vagaPreenchida
        case "encerrada":
            return .vagaEncerrada
        default:
            return nil
        }
    }
    #endif
}

private struct BarraInferiorDoDetalhe<Rodape: View>: ViewModifier {
    let ativo: Bool
    @ViewBuilder let rodape: () -> Rodape

    func body(content: Content) -> some View {
        if ativo {
            if #available(iOS 26, *) {
                content.safeAreaBar(edge: .bottom) {
                    rodape()
                        .padding(.horizontal, FrilaEspaco.medio)
                        .padding(.vertical, FrilaEspaco.compacto)
                }
            } else {
                content.safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(FrilaCor.divisoria)
                            .frame(height: 1)
                            .accessibilityHidden(true)
                        rodape()
                            .padding(.horizontal, FrilaEspaco.medio)
                            .padding(.vertical, FrilaEspaco.compacto)
                    }
                    .background(.regularMaterial)
                }
            }
        } else {
            content
        }
    }
}

extension TelaDetalheVaga where Acao == EmptyView {
    public init(viewModel: DetalheVagaViewModel) {
        self.init(viewModel: viewModel) { _ in EmptyView() }
    }
}
