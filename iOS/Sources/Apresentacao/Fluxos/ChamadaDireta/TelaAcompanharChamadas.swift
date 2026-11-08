import FrilaDominio
import SwiftUI

public struct TelaAcompanharChamadas: View {
    @State private var viewModel: AcompanharChamadasViewModel
    public var onVerVagaPublicada: ((UUID) -> Void)?
    @State private var chamadaParaCancelar: ChamadaResumo?

    public init(viewModel: AcompanharChamadasViewModel, onVerVagaPublicada: ((UUID) -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.onVerVagaPublicada = onVerVagaPublicada
    }

    public var body: some View {
        Form {
            if viewModel.carregando {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                if let erro = viewModel.erro {
                    AvisoFrila(verbatim: erro, tom: .erro)
                }
                if let sucesso = viewModel.sucessoMensagem {
                    AvisoFrila(verbatim: sucesso, tom: .informativo)
                }

                Section(TextosChamadaDireta.chamadasEnviadas) {
                    if viewModel.chamadas.isEmpty {
                        Text("Nenhuma chamada encontrada para esta vaga.", bundle: bundleApresentacao)
                            .foregroundStyle(FrilaCor.textoSecundario)
                    } else {
                        ForEach(viewModel.chamadas) { chamada in
                            cardChamada(chamada)
                        }
                    }
                }

                if viewModel.podePublicarParaTodos {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("As chamadas diretas foram finalizadas sem confirmação. Você pode abrir a vaga para todos os profissionais da região.", bundle: bundleApresentacao)
                                .font(FrilaTipo.nota)
                                .foregroundStyle(FrilaCor.textoSecundario)

                            BotaoPrimario(verbatim: TextosChamadaDireta.publicarParaTodos, carregando: viewModel.acaoEmVoo) {
                                Task { await viewModel.publicarParaTodos() }
                            }
                            .accessibilityIdentifier("publicar-para-todos-chamada")
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Aberto pela folha da chamada (V11), não há para onde levar: fica só o aviso de vaga aberta.
                if let novaVagaID = viewModel.vagaPublicadaNovaID, let onVerVagaPublicada {
                    Section {
                        BotaoSecundario("Ver vaga aberta") {
                            onVerVagaPublicada(novaVagaID)
                        }
                        .accessibilityIdentifier("ver-vaga-aberta")
                    }
                }
            }
        }
        .font(FrilaTipo.corpo)
        .foregroundStyle(FrilaCor.texto)
        .scrollContentBackground(.hidden)
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

    @ViewBuilder
    private func cardChamada(_ chamada: ChamadaResumo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(verbatim: chamada.outraParte.nome)
                    .font(FrilaTipo.resumo)
                    .bold()
                Spacer()
                Text(verbatim: viewModel.rotuloEstado(chamada.estado))
                    .font(FrilaTipo.nota)
                    .foregroundStyle(corDoEstado(chamada.estado))
            }

            Text(verbatim: chamada.funcao.nome)
                .font(FrilaTipo.corpo)

            if let motivo = chamada.motivoRecusa {
                Text(verbatim: "\(TextosChamadaDireta.motivoRotulo): \(motivo.rawValue)")
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }

            if chamada.estado == .aberta {
                Button(role: .destructive) {
                    chamadaParaCancelar = chamada
                } label: {
                    Text(verbatim: TextosChamadaDireta.cancelarChamada)
                        .font(FrilaTipo.nota)
                }
                .buttonStyle(.borderless)
                .padding(.top, 4)
                .accessibilityIdentifier("cancelar-chamada-\(chamada.id)")
            }
        }
        .padding(.vertical, 4)
    }

    private func corDoEstado(_ estado: EstadoChamada) -> Color {
        switch estado {
        case .aberta: return FrilaCor.marca
        case .aceita: return FrilaCor.sucesso
        case .recusada, .cancelada, .expirada, .encerrada: return FrilaCor.textoSecundario
        }
    }
}
