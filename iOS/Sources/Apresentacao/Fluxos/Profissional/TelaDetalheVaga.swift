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
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @Environment(\.dynamicTypeSize) private var tamanhoDoTexto
    @Bindable private var viewModel: DetalheVagaViewModel
    @State private var avisosDaAcao = AvisosDoDetalhe()
    @State private var navegarParaPerfil = false
    @State private var rolagemDoCabecalho = RolagemDoCabecalho()
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
            VStack(spacing: 0) {
                if case let .carregado(vaga) = viewModel.estado, rodapeAtivo {
                    ReacaoDoCabecalho(rolagem: rolagemDoCabecalho) { progresso in
                        cabecalhoEstabelecimento(vaga, progresso: progresso)
                    }
                    .padding(.horizontal, FrilaEspaco.medio)
                    .padding(.vertical, FrilaEspaco.compacto)
                    .background {
                        GeometryReader { geometria in
                            Color.clear.preference(key: AlturaDoCabecalho.self, value: geometria.size.height)
                        }
                    }
                    // Presa ao bloco: acompanha a rolagem e o bounce, sem flutuar sobre o conteúdo.
                    .overlay(alignment: .bottom) {
                        BordaInferiorDoHeader()
                            .frame(height: 8)
                            .offset(y: 8)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
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
            .background {
                MarcadorDoCabecalho()
            }
            .coordinateSpace(name: "conteudo-do-detalhe")
        }
        .coordinateSpace(name: "rolagem-do-detalhe")
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rolagemDoCabecalho.largura = $0 }
        .modifier(MonitoramentoDoCabecalho(rolagem: rolagemDoCabecalho))
        .modifier(BordaNativaDaBarra(rolagem: rolagemDoCabecalho, ativa: rodapeAtivo))
        .onPreferenceChange(AlturaDoCabecalho.self) { rolagemDoCabecalho.altura = $0 }
        .accessibilityIdentifier("tela-detalhe-vaga")
        .modifier(BarraInferiorDoDetalhe(ativo: rodapeAtivo) {
            if case let .carregado(vaga) = viewModel.estado, !bloqueios.contem(vaga.estabelecimento) {
                acao(vaga)
                    .environment(avisosDaAcao)
            }
        })
        .background(FrilaCor.fundo)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            if rodapeAtivo {
                SombraDoCabecalho(rolagem: rolagemDoCabecalho)
                    .frame(height: 0)
            }
        }
        .toolbar {
            if case let .carregado(vaga) = viewModel.estado, rodapeAtivo {
                if #available(iOS 26, *) {
                    ToolbarItem(placement: .principal) { nomeCompacto(vaga) }
                        .sharedBackgroundVisibility(.hidden)
                    ToolbarItem(placement: .topBarTrailing) { reputacaoCompacta(vaga) }
                        .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .principal) { nomeCompacto(vaga) }
                    ToolbarItem(placement: .topBarTrailing) { reputacaoCompacta(vaga) }
                }
            }
        }
        .navigationDestination(isPresented: $navegarParaPerfil) {
            if let api = viewModel.api, case let .carregado(vaga) = viewModel.estado {
                TelaPerfilPublico(perfil: vaga.estabelecimento, api: api, bloqueios: bloqueios)
            }
        }
        .navigationTitle(Text(verbatim: tituloDaNavegacao))
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if case let .carregado(vaga) = viewModel.estado, rodapeAtivo {
                NomeMigranteDoDetalhe(nome: vaga.estabelecimento.nome, rolagem: rolagemDoCabecalho)
            }
        }
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

    private var migrarNome: Bool {
        !reduzirMovimento && !tamanhoDoTexto.isAccessibilitySize && rolagemDoCabecalho.podeMigrar
    }

    @ViewBuilder
    private func cabecalhoEstabelecimento(_ vaga: Vaga, progresso: CGFloat) -> some View {
        let reputacao = vaga.estabelecimento.reputacao
        let contexto = TextosDoProfissional.Detalhe.contextoDoHeader(
            funcao: vaga.funcao.nome, bairro: vaga.regiaoAdministrativa
        )
        let conteudo = VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: vaga.estabelecimento.nome)
                    .font(FrilaTipo.tituloDoDetalhe)
                    .foregroundStyle(FrilaCor.texto)
                    .opacity(migrarNome ? 0 : 1 - progresso)
                    .fixedSize(horizontal: false, vertical: true)
                    .background {
                        GeometryReader { geometria in
                            Color.clear.preference(key: NomeExpandidoDoDetalhe.self,
                                value: geometria.frame(in: .named("conteudo-do-detalhe")))
                        }
                    }
                    .onPreferenceChange(NomeExpandidoDoDetalhe.self) { rolagemDoCabecalho.nomeExpandido = $0 }
                Text(verbatim: contexto)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .opacity(max(0, 1 - progresso / 0.4))
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            reputacaoNoHeader(reputacao, progresso: progresso)
        }
        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
        .contentShape(Rectangle())
        let rotulo = [vaga.estabelecimento.nome, contexto,
                      TextosDoProfissional.reputacaoDoEstabelecimento(reputacao)].joined(separator: ". ")

        if viewModel.api != nil {
            Button {
                guard !navegarParaPerfil else { return }
                navegarParaPerfil = true
            } label: { conteudo }
            .buttonStyle(EstiloBotaoTatil(scale: 0.98))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: rotulo))
            .accessibilityHint(Text("Ver perfil público", bundle: bundleApresentacao))
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("abrir-perfil-estabelecimento")
            .accessibilityHidden(progresso >= 0.5)
        } else {
            conteudo
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: rotulo))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("abrir-perfil-estabelecimento")
            .accessibilityHidden(progresso >= 0.5)
        }
    }

    @ViewBuilder
    private func reputacaoNoHeader(_ reputacao: Reputacao, progresso: CGFloat) -> some View {
        if reputacao.semHistorico {
            Text(verbatim: TextosDoProfissional.Detalhe.semAvaliacoesNoHeader)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
                .opacity(1 - progresso)
        } else {
            let contagemEFila = HStack(spacing: FrilaEspaco.pequeno) {
                Text(verbatim: TextosDoProfissional.Detalhe.reputacaoContagem(
                    positivas: reputacao.positivas, total: reputacao.total
                ))
                .font(FrilaTipo.resumo)
                .foregroundStyle(FrilaCor.texto)
                .opacity(max(0, min(1, (1 - progresso) / 0.65)))
                FilaDeReputacaoDoDetalhe(reputacao: reputacao)
                    .opacity(max(0, min(1, (0.65 - progresso) / 0.45)))
            }
            let legenda = Text(verbatim: TextosDoProfissional.Detalhe.legendaReputacaoNoHeader)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
                .opacity(max(0, 1 - progresso / 0.4))
            ViewThatFits(in: .horizontal) {
                HStack(spacing: FrilaEspaco.compacto) {
                    contagemEFila.fixedSize()
                    Spacer(minLength: 0)
                    legenda.fixedSize()
                }
                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    contagemEFila
                    legenda
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    private func nomeCompacto(_ vaga: Vaga) -> some View {
        botaoCompacto(identificador: "abrir-perfil-compacto", vaga: vaga) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: vaga.estabelecimento.nome)
                    .font(FrilaTipo.resumo)
                    .foregroundStyle(FrilaCor.texto)
                    .lineLimit(1)
                    .background {
                        GeometryReader { geometria in
                            Color.clear.preference(key: NomeCompactoDoDetalhe.self,
                                                   value: geometria.frame(in: .global))
                        }
                    }
                    .onPreferenceChange(NomeCompactoDoDetalhe.self) { rolagemDoCabecalho.nomeCompacto = $0 }
                Text(verbatim: TextosDoProfissional.Detalhe.contextoDoHeader(
                    funcao: vaga.funcao.nome, bairro: vaga.regiaoAdministrativa))
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .lineLimit(1)
            }
            // Da borda do voltar (x=72) até 12 pt antes da reputação, que ocupa 67 pt na margem de 16 pt.
            .frame(width: rolagemDoCabecalho.largura > 0 ? rolagemDoCabecalho.largura - 167 : nil, alignment: .leading)
        }
    }

    private func reputacaoCompacta(_ vaga: Vaga) -> some View {
        let reputacao = vaga.estabelecimento.reputacao
        return botaoCompacto(identificador: "abrir-perfil-compacto-reputacao", vaga: vaga) {
            if reputacao.semHistorico {
                Text(verbatim: TextosDoProfissional.Detalhe.semAvaliacoesNoHeader)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize()
            } else {
                VStack(alignment: .trailing, spacing: FrilaEspaco.fio) {
                    FilaDeReputacaoDoDetalhe(reputacao: reputacao, escala: 0.8)
                    Text(verbatim: TextosDoProfissional.Detalhe.reputacaoContagem(
                        positivas: reputacao.positivas, total: reputacao.total))
                        .font(FrilaTipo.nota.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)
                        .lineLimit(1)
                }
                .fixedSize()
            }
        }
    }

    private func botaoCompacto<Rotulo: View>(identificador: String, vaga: Vaga,
                                             @ViewBuilder rotulo: @escaping () -> Rotulo) -> some View {
        ReacaoDoCabecalho(rolagem: rolagemDoCabecalho) { progresso in
            Button {
                guard viewModel.api != nil, !navegarParaPerfil else { return }
                navegarParaPerfil = true
            } label: {
                rotulo()
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(max(0, min(1, (progresso - 0.65) / 0.35)))
            .allowsHitTesting(progresso >= 0.5)
            .accessibilityHidden(progresso < 0.5)
            .accessibilityLabel(Text(verbatim: vaga.estabelecimento.nome + ". "
                                    + TextosDoProfissional.Detalhe.contextoDoHeader(
                                        funcao: vaga.funcao.nome, bairro: vaga.regiaoAdministrativa) + ". "
                                    + TextosDoProfissional.reputacaoDoEstabelecimento(vaga.estabelecimento.reputacao)))
            .accessibilityHint(Text("Ver perfil público", bundle: bundleApresentacao))
            .accessibilityIdentifier(identificador)
        }
    }

    private func resumoVaga(_ vaga: Vaga) -> some View {
        let formatador = FormatadorFrila()
        let totalPosicoes = max(1, vaga.posicoes)
        let preenchidas = max(0, min(totalPosicoes, totalPosicoes - vaga.posicoesAbertas))
        let inicio = vaga.periodo.inicio
        let fim = vaga.periodo.fim
        let horarioTexto = FormatoDataVaga.janela(vaga.periodo, quebraDeLinha: true)

        let valorFormatado = formatador.dinheiro(vaga.valor)
        let valorFalado = formatador.dinheiroFalado(vaga.valor, por: "pessoa")
        let distanciaTexto = vaga.distanciaKm.map { km in
            TextosDoProfissional.Detalhe.distanciaPontoBase(formatador.distancia(km))
        }

        return FrilaResumoVaga(
            quando: FormatoDataVaga.quando(inicio),
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
            .font(FrilaTipo.meta)
            .foregroundStyle(FrilaCor.textoSecundario)

            Text(verbatim: TextosDoProfissional.Detalhe.valorIntegral)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
        }
    }

    private func cartaoInclusos(_ vaga: Vaga) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoProfissional.Detalhe.incluso)
                .font(FrilaTipo.microRotulo)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(FrilaCor.textoSecundario)
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
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.texto)
                .frame(width: 16, height: 16, alignment: .top)
                .accessibilityHidden(true)
            Text(verbatim: avisoRN10(vaga))
                .font(FrilaTipo.meta)
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
                        .padding(.vertical, FrilaEspaco.pequeno)
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
                            .padding(.vertical, FrilaEspaco.pequeno)
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

/// A geometria do conteúdo não depende deste progresso: nenhum inset muda durante o scroll.
@MainActor @Observable
private final class RolagemDoCabecalho {
    var altura: CGFloat = 0
    var largura: CGFloat = 0
    var offset: CGFloat = 0
    var nomeExpandido: CGRect = .zero
    var nomeCompacto: CGRect = .zero
    var podeMigrar: Bool { !nomeExpandido.isEmpty && !nomeCompacto.isEmpty }
    var progresso: CGFloat { altura > 0 ? min(1, max(0, offset / altura)) : 0 }
}

private struct ReacaoDoCabecalho<Conteudo: View>: View {
    let rolagem: RolagemDoCabecalho
    @ViewBuilder let conteudo: (CGFloat) -> Conteudo
    var body: some View { conteudo(rolagem.progresso) }
}

private struct AlturaDoCabecalho: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct PosicaoDoCabecalho: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct MarcadorDoCabecalho: View {
    @ViewBuilder var body: some View {
        if #available(iOS 18, *) {
            Color.clear
        } else {
            GeometryReader { geometria in
                Color.clear.preference(key: PosicaoDoCabecalho.self,
                                       value: geometria.frame(in: .named("rolagem-do-detalhe")).minY)
            }
        }
    }
}

private struct MonitoramentoDoCabecalho: ViewModifier {
    let rolagem: RolagemDoCabecalho
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometria in
                geometria.contentOffset.y + geometria.contentInsets.top
            } action: { _, offset in
                rolagem.offset = offset
            }
        } else {
            content.onPreferenceChange(PosicaoDoCabecalho.self) { rolagem.offset = -$0 }
        }
    }
}

/// O efeito nativo da barra só entra quando há conteúdo sob ela; antes disso, a borda é a do bloco.
private struct BordaNativaDaBarra: ViewModifier {
    let rolagem: RolagemDoCabecalho
    let ativa: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.scrollEdgeEffectHidden(ativa && rolagem.progresso < 1, for: .top)
        } else {
            content
        }
    }
}

private struct SombraDoCabecalho: View {
    let rolagem: RolagemDoCabecalho
    var body: some View {
        Color.clear.frame(height: 0)
            .overlay(alignment: .top) {
                // Só assume a borda quando o bloco, com a própria sombra, chega à barra.
                BordaInferiorDoHeader()
                    .frame(height: 8)
                    .opacity(rolagem.altura > 0 && rolagem.offset >= rolagem.altura ? 1 : 0)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct NomeExpandidoDoDetalhe: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

private struct NomeCompactoDoDetalhe: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

/// Apenas tinta: botões e gesto continuam no ScrollView e na toolbar nativa.
private struct NomeMigranteDoDetalhe: View {
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @Environment(\.dynamicTypeSize) private var tamanhoDoTexto
    let nome: String
    let rolagem: RolagemDoCabecalho

    var body: some View {
        GeometryReader { geometria in
            if rolagem.podeMigrar, !reduzirMovimento, !tamanhoDoTexto.isAccessibilitySize {
                let p = rolagem.progresso
                // Chega antes de revelar a contagem: a troca de fonte ocorre no mesmo frame.
                let trajeto = min(1, p / 0.65)
                let origem = rolagem.nomeExpandido
                let destino = rolagem.nomeCompacto.offsetBy(dx: -geometria.frame(in: .global).minX,
                                                          dy: -geometria.frame(in: .global).minY)
                let escala = 1 + (destino.height / origem.height - 1) * trajeto
                // O avanço horizontal termina antes da subida, para não cruzar o voltar.
                let avanco = min(1, trajeto / 0.6)
                // No bounce do topo, o conteúdo desce e o nome acompanha.
                let bounce = max(0, -rolagem.offset)
                Text(verbatim: nome)
                    .font(FrilaTipo.tituloDoDetalhe)
                    .foregroundStyle(FrilaCor.texto)
                    .frame(width: origem.width, height: origem.height, alignment: .leading)
                    .scaleEffect(escala)
                    .position(x: origem.midX + (destino.midX - origem.midX) * avanco,
                              y: origem.midY + (destino.midY - origem.midY) * trajeto + bounce)
                    .opacity(1 - max(0, min(1, (p - 0.65) / 0.35)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Beautiful sm restrito à borda: o emissor fica acima do recorte, sem sombrear os textos.
private struct BordaInferiorDoHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    // Neutro da referência aprovada, privado a este único uso.
    private let contato = Color(.sRGB, red: 25.0 / 255, green: 28.0 / 255, blue: 33.0 / 255)

    var body: some View {
        GeometryReader { geometria in
            ZStack(alignment: .topLeading) {
                if colorScheme == .dark {
                    Rectangle().fill(FrilaCor.divisoria).frame(height: 1)
                } else {
                    // Spread −1 pt: emissor recuado nas laterais e com base em y=−1.
                    Rectangle().fill(.black)
                        .frame(width: max(0, geometria.size.width - 2), height: 16)
                        .shadow(color: .black.opacity(0.1), radius: 1.5, x: 0, y: 2)
                        .offset(x: 1, y: -17)
                    // Contato sem blur (y=1) e porção inferior do anel de 1 pt.
                    Rectangle().fill(contato.opacity(0.02)).frame(height: 1)
                    Rectangle().fill(contato.opacity(0.08)).frame(height: 1)
                }
            }
            .frame(width: geometria.size.width, height: geometria.size.height, alignment: .topLeading)
            .clipped()
        }
    }
}

/// Cinco posições mostram a proporção binária; a contagem preserva o tamanho da amostra.
private struct FilaDeReputacaoDoDetalhe: View {
    let reputacao: Reputacao
    var escala: CGFloat = 1
    private let diametros: [CGFloat] = [24, 22, 20, 18, 16]

    var body: some View {
        let proporcao = reputacao.total > 0
            ? min(1, max(0, Double(reputacao.positivas) / Double(reputacao.total))) : 0
        HStack(spacing: -FrilaEspaco.minimo * escala) {
            ForEach(diametros.indices, id: \.self) { indice in
                let diametro = diametros[indice] * escala
                let carga = min(1, max(0, proporcao * 5 - Double(indice)))
                ZStack {
                    Circle().stroke(lineWidth: 4).blendMode(.destinationOut)
                    Circle().fill(FrilaCor.superficie)
                    Circle().fill(FrilaCor.texto.opacity(0.3))
                        .mask(alignment: .leading) {
                            Rectangle().frame(width: diametro * carga)
                        }
                    Image(systemName: carga == 0 ? "hand.thumbsup" : "hand.thumbsup.fill")
                        .font(FrilaTipo.microRotulo)
                        .foregroundStyle(FrilaCor.texto)
                        .scaleEffect(escala)
                }
                .frame(width: diametro, height: diametro)
                .zIndex(Double(diametros.count - indice))
            }
        }
        .compositingGroup()
        .accessibilityHidden(true)
    }
}
