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
    @State private var tituloNavegacaoVisivel = false
    @State private var navegarParaPerfil = false
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
                ScrollView {
                    estadoCarregandoView
                        .padding(FrilaEspaco.medio)
                }
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
                    estadoCarregandoView
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
                    estadoSemConexaoView
                case .falha:
                    estadoErroView
                }
            }
            .padding(FrilaEspaco.medio)
        }
        .coordinateSpace(name: "rolagemDetalhe")
        .onPreferenceChange(VisibilidadePlacaPreferenceKey.self) { saiuDeVista in
            if tituloNavegacaoVisivel != saiuDeVista {
                tituloNavegacaoVisivel = saiuDeVista
            }
        }
        .accessibilityIdentifier("tela-detalhe-vaga")
        .modifier(BarraInferiorDoDetalhe(ativo: rodapeAtivo) {
            if case let .carregado(vaga) = viewModel.estado, !bloqueios.contem(vaga.estabelecimento) {
                acao(vaga)
                    .environment(avisosDaAcao)
            }
        })
        .background(FrilaCor.fundo)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if case let .carregado(vaga) = viewModel.estado, !bloqueios.contem(vaga.estabelecimento) {
                    FrilaTituloNavegacaoVaga(
                        funcao: vaga.funcao.nome,
                        estabelecimento: vaga.estabelecimento.nome,
                        visivel: tituloNavegacaoVisivel
                    )
                }
            }
        }
        .navigationDestination(isPresented: $navegarParaPerfil) {
            if let api = viewModel.api, case let .carregado(vaga) = viewModel.estado {
                TelaPerfilPublico(perfil: vaga.estabelecimento, api: api, bloqueios: bloqueios)
            }
        }
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

    private var cabecalhoDetalhe: some View {
        Text(verbatim: TextosDoProfissional.Detalhe.titulo)
            .font(FrilaTipo.tituloGrande)
            .foregroundStyle(FrilaCor.texto)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var estadoCarregandoView: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
            cabecalhoDetalhe

            VStack(spacing: FrilaEspaco.medio) {
                ProgressView()
                    .controlSize(.regular)
                    .tint(FrilaCor.texto)
                    .frame(width: FrilaMetrica.circuloDeEstado, height: FrilaMetrica.circuloDeEstado)
                    .background(FrilaCor.controle, in: Circle())
                    .accessibilityHidden(true)

                Text(verbatim: TextosDoProfissional.Detalhe.carregando)
                    .font(FrilaTipo.tituloDeEstado)
                    .foregroundStyle(FrilaCor.texto)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, FrilaEspaco.grande)
            .accessibilityElement(children: .combine)
        }
    }

    private var estadoErroView: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
            cabecalhoDetalhe

            VStack(spacing: FrilaEspaco.medio) {
                Image(systemName: "exclamationmark.circle")
                    .font(FrilaTipo.secao)
                    .foregroundStyle(FrilaCor.texto)
                    .frame(width: FrilaMetrica.circuloDeEstado, height: FrilaMetrica.circuloDeEstado)
                    .background(FrilaCor.controle, in: Circle())
                    .accessibilityHidden(true)

                VStack(spacing: FrilaEspaco.minimo) {
                    Text(verbatim: TextosDoProfissional.Detalhe.erroTitulo)
                        .font(FrilaTipo.tituloDeEstado)
                        .foregroundStyle(FrilaCor.texto)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(verbatim: TextosDoProfissional.Detalhe.erroApoio)
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .modifier(AnunciarAoAparecer(anuncio: .init(
                    texto: "\(TextosDoProfissional.Detalhe.erroTitulo) \(TextosDoProfissional.Detalhe.erroApoio)",
                    tom: .erro
                )))

                BotaoPrimario(verbatim: TextosDoProfissional.Detalhe.tentarDeNovo) {
                    Task { await viewModel.carregar() }
                }
                .padding(.top, FrilaEspaco.pequeno)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, FrilaEspaco.grande)
        }
    }

    private var estadoSemConexaoView: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
            cabecalhoDetalhe

            VStack(spacing: FrilaEspaco.medio) {
                Image(systemName: "wifi.slash")
                    .font(FrilaTipo.secao)
                    .foregroundStyle(FrilaCor.texto)
                    .frame(width: FrilaMetrica.circuloDeEstado, height: FrilaMetrica.circuloDeEstado)
                    .background(FrilaCor.controle, in: Circle())
                    .accessibilityHidden(true)

                VStack(spacing: FrilaEspaco.minimo) {
                    Text(verbatim: TextosDoProfissional.Detalhe.semConexaoTitulo)
                        .font(FrilaTipo.tituloDeEstado)
                        .foregroundStyle(FrilaCor.texto)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(verbatim: TextosDoProfissional.Detalhe.semConexaoMensagem)
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .modifier(AnunciarAoAparecer(anuncio: .init(
                    texto: "\(TextosDoProfissional.Detalhe.semConexaoTitulo) \(TextosDoProfissional.Detalhe.semConexaoMensagem)",
                    tom: .alerta
                )))

                BotaoPrimario(verbatim: TextosDoProfissional.Detalhe.tentarDeNovo) {
                    Task { await viewModel.carregar() }
                }
                .padding(.top, FrilaEspaco.pequeno)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, FrilaEspaco.grande)
        }
    }

    @ViewBuilder
    private func conteudo(_ vaga: Vaga) -> some View {
        placaVaga(vaga)

        cabecalhoEstabelecimento(vaga)

        resumoVaga(vaga)

        notasResumo(vaga)

        cartaoInclusos(vaga)

        cartaoReputacao(vaga.estabelecimento.reputacao)

        avisoRN10View(vaga)

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

    private func placaVaga(_ vaga: Vaga) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: vaga.estabelecimento.nome)
                .font(FrilaTipo.resumo)
                .textCase(.uppercase)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityLabel(Text(verbatim: vaga.estabelecimento.nome))
            Text(verbatim: vaga.funcao.nome)
                .font(FrilaTipo.tituloDoDetalhe)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: VisibilidadePlacaPreferenceKey.self,
                    value: geo.frame(in: .named("rolagemDetalhe")).maxY < 0
                )
            }
        )
    }

    @ViewBuilder
    private func cabecalhoEstabelecimento(_ vaga: Vaga) -> some View {
        let reputacao = vaga.estabelecimento.reputacao
        let avaliacao: String? = reputacao.semHistorico
            ? nil
            : TextosDoProfissional.Detalhe.reputacaoContagem(positivas: reputacao.positivas, total: reputacao.total)
        let localizacao = vaga.regiaoAdministrativa.isEmpty ? nil : vaga.regiaoAdministrativa

        if viewModel.api != nil {
            FrilaCabecalhoEstabelecimento(
                nome: vaga.estabelecimento.nome,
                localizacao: localizacao,
                avaliacao: avaliacao,
                acao: { navegarParaPerfil = true }
            )
            .accessibilityIdentifier("abrir-perfil-estabelecimento")
        } else {
            FrilaCabecalhoEstabelecimento(
                nome: vaga.estabelecimento.nome,
                localizacao: localizacao,
                avaliacao: avaliacao,
                acao: nil
            )
        }
    }

    private func resumoVaga(_ vaga: Vaga) -> some View {
        let formatador = FormatadorFrila()
        let totalPosicoes = max(1, vaga.posicoes)
        let preenchidas = max(0, min(totalPosicoes, totalPosicoes - vaga.posicoesAbertas))
        let inicio = vaga.periodo.inicio
        let fim = vaga.periodo.fim
        let cruzaDia = !calendarioSp.isDate(inicio, inSameDayAs: fim)
        let intervalo = TextosDoProfissional.Detalhe.intervaloHorario(inicio: formatarHora(inicio), fim: formatarHora(fim))
        let horarioTexto = cruzaDia
            ? "\(intervalo)\n\(TextosDoProfissional.Detalhe.horarioTermina(formatarDiaMesCurto(fim)))"
            : intervalo

        let valorFormatado = formatador.dinheiro(vaga.valor)
        let valorFalado = formatador.dinheiroFalado(vaga.valor, por: "pessoa")
        let distanciaTexto = vaga.distanciaKm.map { km in
            TextosDoProfissional.Detalhe.distanciaPontoBase(formatador.distancia(km))
        }

        return FrilaResumoVaga(
            quando: formatarQuando(inicio),
            horario: horarioTexto,
            valor: valorFormatado,
            valorAcessibilidade: valorFalado,
            local: vaga.local,
            distancia: distanciaTexto,
            preenchidas: preenchidas,
            total: totalPosicoes,
            inicio: inicio,
            fim: fim,
            abrirMapa: { abrirNoMapa(vaga.local) }
        )
    }

    private func notasResumo(_ vaga: Vaga) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoProfissional.Detalhe.porPessoa)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)

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
        .padding(.horizontal, FrilaEspaco.minimo)
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

            FrilaListaInclusos(itens: itensInclusos(da: vaga))
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
        if let traje = vaga.traje, !traje.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            itens.append(FrilaItemIncluso(
                rotulo: TextosDoProfissional.Detalhe.traje,
                valor: traje
            ))
        }
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

    private func abrirNoMapa(_ endereco: String) {
        var componentes = URLComponents()
        componentes.scheme = "maps"
        componentes.queryItems = [URLQueryItem(name: "q", value: endereco)]
        if let url = componentes.url {
            openURL(url)
        }
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
        .padding(FrilaEspaco.medio)
        .background(FrilaCor.fundo, in: RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous)
                .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
        )
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

private struct VisibilidadePlacaPreferenceKey: PreferenceKey {
    static let defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
}
