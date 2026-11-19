import FrilaDominio
import SwiftUI

/// Acompanhar chamadas (CD-RF09): as chamadas diretas de uma vaga, o estado de cada uma, cancelar a que está aberta e,
/// quando ninguém aceitou, publicar para todos. Desenho (R6): lista de cartões de status sem etapas, com o selo do
/// estado em cima, e um botão laranja só, "Publicar para todos", quando existe.
public struct TelaAcompanharChamadas: View {
    @State private var viewModel: AcompanharChamadasViewModel
    public var onVerVagaPublicada: ((UUID) -> Void)?
    @State private var chamadaParaCancelar: ChamadaResumo?

    public init(viewModel: AcompanharChamadasViewModel, onVerVagaPublicada: ((UUID) -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.onVerVagaPublicada = onVerVagaPublicada
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                if viewModel.carregando {
                    EstadoCarregando()
                } else {
                    avisos
                    listaDeChamadas
                    publicarParaTodos
                    verVagaAberta
                }
            }
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.top, FrilaEspaco.item)
            .padding(.bottom, FrilaEspaco.grupo)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosChamadaDireta.acompanharTitulo))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.carregar() }
        .alert(Text("Cancelar chamada", bundle: bundleApresentacao), isPresented: Binding(
            get: { chamadaParaCancelar != nil },
            set: { if !$0 { chamadaParaCancelar = nil } }
        )) {
            Button(role: .cancel) { chamadaParaCancelar = nil } label: {
                Text("Voltar", bundle: bundleApresentacao)
            }
            Button(role: .destructive) {
                if let ch = chamadaParaCancelar {
                    chamadaParaCancelar = nil
                    Task { await viewModel.cancelar(chamadaID: ch.id) }
                }
            } label: {
                Text("Confirmar cancelamento", bundle: bundleApresentacao)
            }
        } message: {
            Text(verbatim: TextosChamadaDireta.confirmarCancelamento)
        }
    }

    // MARK: Blocos

    @ViewBuilder
    private var avisos: some View {
        if viewModel.erro != nil || viewModel.sucessoMensagem != nil {
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                if let erro = viewModel.erro {
                    AvisoFrila(verbatim: erro, tom: .erro)
                }
                if let sucesso = viewModel.sucessoMensagem {
                    AvisoFrila(verbatim: sucesso, tom: .informativo)
                }
            }
        }
    }

    private var listaDeChamadas: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(verbatim: TextosChamadaDireta.chamadasEnviadas)
                .font(FrilaTipo.rotuloDeGrupo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)
            if viewModel.chamadas.isEmpty {
                Text("Nenhuma chamada encontrada para esta vaga.", bundle: bundleApresentacao)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.top, FrilaEspaco.respiro)
            } else {
                VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                    ForEach(viewModel.chamadas) { chamada in
                        cartaoDaChamada(chamada)
                    }
                }
            }
        }
    }

    /// Só quando ninguém aceitou: a vaga abre para todos. É a decisão da tela, então é o botão laranja.
    @ViewBuilder
    private var publicarParaTodos: some View {
        if viewModel.podePublicarParaTodos {
            VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                Text("As chamadas diretas foram finalizadas sem confirmação. Você pode abrir a vaga para todos os profissionais da região.", bundle: bundleApresentacao)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                BotaoPrimario(verbatim: TextosChamadaDireta.publicarParaTodos, carregando: viewModel.acaoEmVoo) {
                    Task { await viewModel.publicarParaTodos() }
                }
                .accessibilityIdentifier("publicar-para-todos-chamada")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartaoFrila()
        }
    }

    /// Aberto pela folha da chamada (V11), não há para onde levar: fica só o aviso de vaga aberta.
    @ViewBuilder
    private var verVagaAberta: some View {
        if let novaVagaID = viewModel.vagaPublicadaNovaID, let onVerVagaPublicada {
            BotaoSecundario("Ver vaga aberta") {
                onVerVagaPublicada(novaVagaID)
            }
            .accessibilityIdentifier("ver-vaga-aberta")
        }
    }

    /// O cartão de uma chamada: o selo do estado em cima, quem é, a função, o motivo da recusa quando há, e "Cancelar
    /// chamada" como ação discreta no fim do cartão (só enquanto a chamada está aberta).
    private func cartaoDaChamada(_ chamada: ChamadaResumo) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            SeloDeStatus(verbatim: viewModel.rotuloEstado(chamada.estado), estilo: estiloDoSelo(chamada.estado),
                         icone: chamada.estado == .aceita ? "checkmark" : nil)
            Text(verbatim: chamada.outraParte.nome)
                .font(FrilaTipo.nome)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: chamada.funcao.nome)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
            if let motivo = chamada.motivoRecusa {
                Text(verbatim: "\(TextosChamadaDireta.motivoRotulo): \(TextosChamadaDireta.motivo(motivo))")
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if chamada.estado == .aberta {
                Button { chamadaParaCancelar = chamada } label: {
                    Text(verbatim: TextosChamadaDireta.cancelarChamada)
                }
                .buttonStyle(.frilaAcaoDiscreta)
                .accessibilityIdentifier("cancelar-chamada-\(chamada.id)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .contain)
    }

    /// Aguardando: contorno; aceita: o amarelo do que está confirmado; o resto (recusada, expirada, cancelada,
    /// encerrada) já terminou: tinta suave. Nenhum vermelho nem verde.
    private func estiloDoSelo(_ estado: EstadoChamada) -> SeloDeStatus.Estilo {
        switch estado {
        case .aberta: .contorno
        case .aceita: .destaque
        case .recusada, .cancelada, .expirada, .encerrada: .encerrado
        }
    }
}
