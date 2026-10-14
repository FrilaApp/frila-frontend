import FrilaDominio
import Observation
import SwiftUI

/// Os avisos da área de ação do detalhe (candidatura que falhou, candidatura retirada). Nos
/// tamanhos de acessibilidade a área de ação fica presa ao rodapé, sem rolagem: um aviso longo
/// ali é cortado e esconde a vaga. Por isso, nesses tamanhos, quem está no rodapé publica o aviso
/// aqui, e o detalhe o mostra dentro da rolagem; o rodapé fica só com os botões.
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
/// contato só aparece depois da confirmação (RN10). O aviso da RN10 vem antes de Candidatar-me.
public struct TelaDetalheVaga<Acao: View>: View {
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
                    } else { conteudo(vaga) }
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
        .safeAreaInset(edge: .bottom) {
            if dynamicTypeSize.isAccessibilitySize, case let .carregado(vaga) = viewModel.estado, !bloqueios.contem(vaga.estabelecimento) {
                acao(vaga)
                    .environment(avisosDaAcao)
                    .padding(FrilaEspaco.medio)
                    .background(FrilaCor.fundo)
            }
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosDoProfissional.Detalhe.titulo))
        .navigationBarTitleDisplayMode(.inline)
        .task { await medirAbertura(.detalheDaVaga, carregar: viewModel.carregar, pronto: detalheNaTela) }
    }

    /// Fim da medição de abertura (#73): a vaga da API publicada.
    private var detalheNaTela: @MainActor @Sendable () -> Bool {
        let viewModel = viewModel
        return { if case .carregado = viewModel.estado { true } else { false } }
    }

    @ViewBuilder
    private func conteudo(_ vaga: Vaga) -> some View {
        let formatador = FormatadorFrila()
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: vaga.funcao.nome)
                .font(FrilaTipo.tituloGrande)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: cabecalho(vaga)).font(FrilaTipo.corpo).foregroundStyle(FrilaCor.textoSecundario)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, FrilaEspaco.minimo)

        VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
            if dynamicTypeSize.isAccessibilitySize {
                // Na meia coluna do Grid o valor quebrava no meio do número ("R$ 120,0" / "0") em AX5.
                campo(TextosDoProfissional.Detalhe.quando, formatador.intervalo(vaga.periodo))
                campo(TextosDoProfissional.Detalhe.valor, formatador.dinheiro(vaga.valor))
                campo(TextosDoProfissional.Detalhe.posicoes, String(localized: "\(vaga.posicoesAbertas) aberta(s) de \(vaga.posicoes)", bundle: bundleApresentacao))
            } else {
                Grid(alignment: .leading, horizontalSpacing: FrilaEspaco.medio, verticalSpacing: FrilaEspaco.medio) {
                    GridRow {
                        campo(TextosDoProfissional.Detalhe.quando, formatador.intervalo(vaga.periodo))
                        campo(TextosDoProfissional.Detalhe.valor, formatador.dinheiro(vaga.valor))
                    }
                    GridRow {
                        campo(TextosDoProfissional.Detalhe.posicoes, String(localized: "\(vaga.posicoesAbertas) aberta(s) de \(vaga.posicoes)", bundle: bundleApresentacao))
                    }
                }
            }
            // O modo é uma frase: na meia coluna do Grid ela partia palavras a partir do AX1
            // ("estabeleci-mento"), e a auditoria do XCTest a dava como texto cortado.
            // A vaga de seleção com posição aberta a 24 h ou menos do início está em reposição por
            // urgência (0.2.38, D4 e D5): o primeiro que aceitar é confirmado na hora.
            campo(modoTitulo(vaga.modoEfetivo(em: .now)), modoDetalhe(vaga.modoEfetivo(em: .now)))
            Divider().overlay(FrilaCor.divisoria)
            Text(verbatim: TextosDoProfissional.Detalhe.valorIntegral).font(FrilaTipo.nota).foregroundStyle(FrilaCor.textoSecundario)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()

        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoProfissional.Detalhe.incluso)
                .font(FrilaTipo.microRotulo)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)
            Text("Refeição: \(TextosDoProfissional.simNao(vaga.inclusos.refeicao))", bundle: bundleApresentacao)
            Text("Transporte: \(TextosDoProfissional.simNao(vaga.inclusos.transporte))", bundle: bundleApresentacao)
            Text("Material próprio: \(TextosDoProfissional.simNao(vaga.inclusos.exigeMaterialProprio))", bundle: bundleApresentacao)
            if let traje = vaga.traje, !traje.isEmpty { Text(verbatim: "\(TextosDoProfissional.Detalhe.traje): \(traje)") }
            Text(verbatim: "\(TextosDoProfissional.Detalhe.quemRecebe): \(vaga.responsavelLocal)")
        }
        .font(FrilaTipo.corpo)
        .foregroundStyle(FrilaCor.texto)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()

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

        SeloReputacao(vaga.estabelecimento.reputacao)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartaoFrila()
            .accessibilityIdentifier("detalhe-reputacao")

        AvisoFrila(verbatim: avisoRN10(vaga), tom: .alerta)
            .accessibilityIdentifier("aviso-rn10")

        if !dynamicTypeSize.isAccessibilitySize {
            acao(vaga)
        } else if !avisosDaAcao.avisos.isEmpty {
            // Os avisos de quem está no rodapé: aqui cabem inteiros, e a vaga continua legível.
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                ForEach(avisosDaAcao.avisos) { aviso in
                    AvisoFrila(verbatim: aviso.texto, tom: aviso.tom)
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

    private func campo(_ titulo: String, _ valor: String) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
            Text(verbatim: titulo).font(FrilaTipo.nota).foregroundStyle(FrilaCor.textoSecundario)
            Text(verbatim: valor).font(FrilaTipo.rotuloDoCampo).foregroundStyle(FrilaCor.texto)
        }
        .accessibilityElement(children: .combine)
    }

    private func cabecalho(_ vaga: Vaga) -> String {
        guard let km = vaga.distanciaKm else { return "\(vaga.estabelecimento.nome) · \(vaga.local)" }
        return "\(vaga.estabelecimento.nome) · \(vaga.local) · a \(FormatadorFrila().distancia(km))"
    }

    /// Na vaga de seleção o contato só é mostrado se a casa escolher a candidatura (RN10).
    private func avisoRN10(_ vaga: Vaga) -> String {
        vaga.modoEfetivo(em: .now) == .selecao
            ? String(format: TextosDaCandidaturaEmSelecao.avisoRN10, vaga.estabelecimento.nome)
            : TextosDoProfissional.Detalhe.avisoRN10(vaga.estabelecimento.nome)
    }

    private func modoTitulo(_ modo: ModoPreenchimento) -> String {
        modo == .urgencia ? TextosDoProfissional.Detalhe.urgencia : TextosDoProfissional.Detalhe.selecao
    }

    private func modoDetalhe(_ modo: ModoPreenchimento) -> String {
        modo == .urgencia ? TextosDoProfissional.Detalhe.urgenciaDetalhe : TextosDoProfissional.Detalhe.selecaoDetalhe
    }
}

extension TelaDetalheVaga where Acao == EmptyView {
    public init(viewModel: DetalheVagaViewModel) {
        self.init(viewModel: viewModel) { _ in EmptyView() }
    }
}
