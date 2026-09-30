// BAIXA FIDELIDADE DESCARTÁVEL: não é design final. Segue o protótipo low-fi "Detalhe da vaga" e
// substitui por ora a alta fidelidade do profissional (#15).

import FrilaDominio
import SwiftUI

/// Detalhe da vaga (#104). Nunca mostra telefone nem documento: o contrato não os devolve aqui, e o
/// contato só aparece depois da confirmação (RN10). O aviso da RN10 vem antes de Candidatar-me.
public struct TelaDetalheVaga<Acao: View>: View {
    @Bindable private var viewModel: DetalheVagaViewModel
    private let acao: (Vaga) -> Acao

    /// `acao` monta a área de Candidatar-me (#105); sem ela, o detalhe mostra só a vaga.
    public init(viewModel: DetalheVagaViewModel, @ViewBuilder acao: @escaping (Vaga) -> Acao) {
        self.viewModel = viewModel
        self.acao = acao
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                switch viewModel.estado {
                case .carregando:
                    EstadoCarregando()
                case let .carregado(vaga):
                    conteudo(vaga)
                case .naoEncontrada:
                    AvisoFrila(LocalizedStringKey(TextosDoProfissional.Detalhe.naoEncontrada), tom: .alerta)
                        .accessibilityIdentifier("detalhe-nao-encontrada")
                case .falha(.semConexao):
                    AvisoFrila(LocalizedStringKey(TextosDoProfissional.Lista.semConexaoMensagem), tom: .alerta)
                    BotaoSecundario("Tentar novamente") { Task { await viewModel.carregar() } }
                case .falha:
                    EstadoErro(LocalizedStringKey(TextosDoProfissional.Detalhe.erroMensagem)) { Task { await viewModel.carregar() } }
                }
            }
            .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(TextosDoProfissional.Detalhe.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.carregar() }
        .accessibilityIdentifier("tela-detalhe-vaga")
    }

    @ViewBuilder
    private func conteudo(_ vaga: Vaga) -> some View {
        let formatador = FormatadorFrila()
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(vaga.funcao.nome).font(.title.bold()).accessibilityAddTraits(.isHeader)
            Text(cabecalho(vaga)).font(.subheadline).foregroundStyle(FrilaCor.textoSecundario)
        }

        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Grid(alignment: .leading, horizontalSpacing: FrilaEspaco.medio, verticalSpacing: FrilaEspaco.pequeno) {
                GridRow {
                    campo(TextosDoProfissional.Detalhe.quando, formatador.intervalo(vaga.periodo))
                    campo(TextosDoProfissional.Detalhe.valor, formatador.dinheiro(vaga.valor))
                }
                GridRow {
                    campo(TextosDoProfissional.Detalhe.posicoes, "\(vaga.posicoesAbertas) aberta(s) de \(vaga.posicoes)")
                    campo(modoTitulo(vaga.modo), modoDetalhe(vaga.modo))
                }
            }
            Text(TextosDoProfissional.Detalhe.valorIntegral).font(.caption).foregroundStyle(FrilaCor.textoSecundario)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()

        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(TextosDoProfissional.Detalhe.incluso).font(.footnote.weight(.semibold)).foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)
            Text("Refeição: \(TextosDoProfissional.simNao(vaga.inclusos.refeicao))")
            Text("Transporte: \(TextosDoProfissional.simNao(vaga.inclusos.transporte))")
            Text("Material próprio: \(TextosDoProfissional.simNao(vaga.inclusos.exigeMaterialProprio))")
            if let traje = vaga.traje, !traje.isEmpty { Text("\(TextosDoProfissional.Detalhe.traje): \(traje)") }
            Text("\(TextosDoProfissional.Detalhe.quemRecebe): \(vaga.responsavelLocal)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()

        Label(TextosDoProfissional.reputacaoDoEstabelecimento(vaga.estabelecimento.reputacao), systemImage: "hand.thumbsup")
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartaoFrila()
            .accessibilityIdentifier("detalhe-reputacao")

        AvisoFrila(TextosDoProfissional.Detalhe.avisoRN10(vaga.estabelecimento.nome), tom: .alerta)
            .accessibilityIdentifier("aviso-rn10")

        acao(vaga)

        // Reservado para o Sprint 2 (Denunciar e Bloquear): ocupa o espaço e fica desabilitado.
        HStack(spacing: FrilaEspaco.grande) {
            Button(TextosDoProfissional.Detalhe.denunciar) {}.disabled(true)
            Button(TextosDoProfissional.Detalhe.bloquear) {}.disabled(true)
        }
        .frame(minHeight: FrilaMetrica.alvoMinimo)
    }

    private func campo(_ titulo: String, _ valor: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo).font(.caption).foregroundStyle(FrilaCor.textoSecundario)
            Text(valor).font(.body.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
    }

    private func cabecalho(_ vaga: Vaga) -> String {
        guard let km = vaga.distanciaKm else { return "\(vaga.estabelecimento.nome) · \(vaga.local)" }
        return "\(vaga.estabelecimento.nome) · \(vaga.local) · a \(FormatadorFrila().distancia(km))"
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
