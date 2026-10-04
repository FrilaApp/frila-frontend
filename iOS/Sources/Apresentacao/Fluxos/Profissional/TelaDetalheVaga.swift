// BAIXA FIDELIDADE DESCARTÁVEL: não é design final. Segue o protótipo low-fi "Detalhe da vaga" e
// substitui por ora a alta fidelidade do profissional (#15).

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

/// Detalhe da vaga (#104). Nunca mostra telefone nem documento: o contrato não os devolve aqui, e o
/// contato só aparece depois da confirmação (RN10). O aviso da RN10 vem antes de Candidatar-me.
public struct TelaDetalheVaga<Acao: View>: View {
    @Environment(BloqueiosDaSessao.self) private var bloqueiosDaSessao: BloqueiosDaSessao?
    @State private var bloqueiosLocais = BloqueiosDaSessao()
    private var bloqueios: BloqueiosDaSessao { bloqueiosDaSessao ?? bloqueiosLocais }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                    withAnimation { rolagem.scrollTo(Self.idDosAvisos, anchor: .top) }
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
            Text(verbatim: vaga.funcao.nome).font(.title.bold()).accessibilityAddTraits(.isHeader)
            Text(verbatim: cabecalho(vaga)).font(.subheadline).foregroundStyle(FrilaCor.textoSecundario)
        }

        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Grid(alignment: .leading, horizontalSpacing: FrilaEspaco.medio, verticalSpacing: FrilaEspaco.pequeno) {
                GridRow {
                    campo(TextosDoProfissional.Detalhe.quando, formatador.intervalo(vaga.periodo))
                    campo(TextosDoProfissional.Detalhe.valor, formatador.dinheiro(vaga.valor))
                }
                GridRow {
                    campo(TextosDoProfissional.Detalhe.posicoes, String(localized: "\(vaga.posicoesAbertas) aberta(s) de \(vaga.posicoes)", bundle: bundleApresentacao))
                    campo(modoTitulo(vaga.modo), modoDetalhe(vaga.modo))
                }
            }
            Text(verbatim: TextosDoProfissional.Detalhe.valorIntegral).font(.caption).foregroundStyle(FrilaCor.textoSecundario)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()

        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: TextosDoProfissional.Detalhe.incluso).font(.footnote.weight(.semibold)).foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)
            Text("Refeição: \(TextosDoProfissional.simNao(vaga.inclusos.refeicao))", bundle: bundleApresentacao)
            Text("Transporte: \(TextosDoProfissional.simNao(vaga.inclusos.transporte))", bundle: bundleApresentacao)
            Text("Material próprio: \(TextosDoProfissional.simNao(vaga.inclusos.exigeMaterialProprio))", bundle: bundleApresentacao)
            if let traje = vaga.traje, !traje.isEmpty { Text(verbatim: "\(TextosDoProfissional.Detalhe.traje): \(traje)") }
            Text(verbatim: "\(TextosDoProfissional.Detalhe.quemRecebe): \(vaga.responsavelLocal)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()

        if let api = viewModel.api {
            NavigationLink {
                TelaPerfilPublico(perfil: vaga.estabelecimento, api: api, bloqueios: bloqueios)
            } label: {
                Text(verbatim: TextosDaSeguranca.verPerfil).frame(minHeight: FrilaMetrica.alvoMinimo)
            }
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
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: titulo).font(.caption).foregroundStyle(FrilaCor.textoSecundario)
            Text(verbatim: valor).font(.body.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
    }

    private func cabecalho(_ vaga: Vaga) -> String {
        guard let km = vaga.distanciaKm else { return "\(vaga.estabelecimento.nome) · \(vaga.local)" }
        return "\(vaga.estabelecimento.nome) · \(vaga.local) · a \(FormatadorFrila().distancia(km))"
    }

    /// Na vaga de seleção o contato só é mostrado se a casa escolher a candidatura (RN10).
    private func avisoRN10(_ vaga: Vaga) -> String {
        vaga.modo == .selecao
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
