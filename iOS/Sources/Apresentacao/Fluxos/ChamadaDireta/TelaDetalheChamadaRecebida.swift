import FrilaDominio
import SwiftUI

public struct TelaDetalheChamadaRecebida: View {
    @State private var viewModel: ChamadaRecebidaViewModel
    public var onAbrirTurno: ((UUID) -> Void)?
    @Environment(\.dismiss) private var fechar
    @Environment(BloqueiosDaSessao.self) private var bloqueiosDaSessao: BloqueiosDaSessao?
    @State private var bloqueiosLocais = BloqueiosDaSessao()
    private var bloqueios: BloqueiosDaSessao { bloqueiosDaSessao ?? bloqueiosLocais }

    public init(viewModel: ChamadaRecebidaViewModel, onAbrirTurno: ((UUID) -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.onAbrirTurno = onAbrirTurno
    }

    public var body: some View {
        Form {
            if viewModel.carregando {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let erro = viewModel.erro {
                AvisoFrila(verbatim: erro, tom: .erro)
                BotaoSecundario("Tentar novamente") {
                    Task { await viewModel.carregar() }
                }
            } else if let msg = viewModel.mensagemConcorrencia {
                AvisoFrila(verbatim: msg, tom: .alerta)
            } else if let resultado = viewModel.resultado, resultado.chamada.estado == .aceita {
                sucessoAceite(resultado)
            } else if let resultado = viewModel.resultado, resultado.chamada.estado == .recusada {
                AvisoFrila(verbatim: TextosChamadaDireta.chamadaRecusadaAviso, tom: .informativo)
            } else if let detalhe = viewModel.detalhe {
                conteudoChamada(detalhe)
            }
        }
        .font(FrilaTipo.corpo)
        .foregroundStyle(FrilaCor.texto)
        .scrollContentBackground(.hidden)
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosChamadaDireta.chamadaRecebidaTitulo))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.carregar() }
        .sheet(isPresented: $viewModel.mostrarRecusa) {
            sheetRecusa
        }
    }

    @ViewBuilder
    private func conteudoChamada(_ detalhe: ChamadaDetalhe) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(verbatim: detalhe.outraParte.nome)
                        .font(FrilaTipo.tituloDoCartao)
                        .bold()
                    Spacer()
                    if detalhe.contaNova {
                        Text(verbatim: TextosChamadaDireta.contaNovaBadge)
                            .font(FrilaTipo.nota)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(FrilaCor.alerta.opacity(0.15))
                            .foregroundStyle(FrilaCor.alerta)
                            .clipShape(Capsule())
                    }
                }

                if detalhe.contaNova {
                    Text(verbatim: TextosChamadaDireta.contaNovaAviso)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }

                Text(verbatim: detalhe.funcao.nome)
                    .font(FrilaTipo.resumo)
                    .foregroundStyle(FrilaCor.marca)

                Text(verbatim: viewModel.valorFormatado)
                    .font(FrilaTipo.secao)
                    .bold()

                Text(verbatim: viewModel.intervaloFormatado)
                    .font(FrilaTipo.corpo)

                HStack {
                    Text(verbatim: detalhe.regiaoAdministrativa)
                    if let faixa = detalhe.distanciaFaixa {
                        Text(verbatim: "•")
                        Text(verbatim: faixa.rotulo)
                    }
                }
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
            }
            .padding(.vertical, 4)
        }

        if let recado = detalhe.recado, !recado.isEmpty {
            Section(TextosChamadaDireta.recadoContratanteSecao) {
                Text(verbatim: recado)
                    .font(FrilaTipo.corpo)
            }
        }

        Section(TextosChamadaDireta.inclusosSecao) {
            if detalhe.incluiRefeicao {
                Label {
                    Text("Refeição inclusa", bundle: bundleApresentacao)
                } icon: {
                    Image(systemName: "fork.knife")
                }
            }
            if detalhe.incluiTransporte {
                Label {
                    Text("Transporte incluso", bundle: bundleApresentacao)
                } icon: {
                    Image(systemName: "car.fill")
                }
            }
            if detalhe.exigeMaterialProprio {
                Label {
                    Text("Exige material próprio", bundle: bundleApresentacao)
                } icon: {
                    Image(systemName: "wrench.and.screwdriver.fill")
                }
            }
            if !detalhe.incluiRefeicao && !detalhe.incluiTransporte && !detalhe.exigeMaterialProprio {
                Text("Nenhum benefício adicional especificado.", bundle: bundleApresentacao)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
        }

        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: viewModel.expiraEmFormatado)
                    .font(FrilaTipo.resumo)
                    .foregroundStyle(FrilaCor.alerta)
                Text(verbatim: TextosChamadaDireta.avisoSeguranca)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
            .padding(.vertical, 4)
        }

        if viewModel.podeResponder {
            Section {
                BotaoPrimario(verbatim: TextosChamadaDireta.aceitarChamada, carregando: viewModel.respondendo) {
                    Task { await viewModel.aceitar() }
                }
                .accessibilityIdentifier("aceitar-chamada")

                BotaoSecundario(verbatim: TextosChamadaDireta.recusarChamada) {
                    viewModel.mostrarRecusa = true
                }
                .disabled(viewModel.respondendo)
                .accessibilityIdentifier("recusar-chamada")
            }
        }

        // CD-RF12: denúncia e bloqueio também a partir da chamada, sobre quem chamou.
        Section {
            AcoesDeSeguranca(perfil: detalhe.outraParte, api: viewModel.api, bloqueios: bloqueios,
                             identificadorDenunciar: "denunciar-chamada", identificadorBloquear: "bloquear-chamada",
                             identificadorConfirmarBloqueio: "confirmar-bloqueio-chamada")
                .id(detalhe.outraParte.id)
        }
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func sucessoAceite(_ resultado: ResultadoChamada) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                AvisoFrila(verbatim: TextosChamadaDireta.chamadaAceitaMensagem, tom: .informativo)

                if let local = resultado.local {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Endereço do turno:", bundle: bundleApresentacao)
                            .font(FrilaTipo.nota)
                            .foregroundStyle(FrilaCor.textoSecundario)
                        Text(verbatim: local)
                            .font(FrilaTipo.corpo)
                            .bold()
                    }
                }

                if let resp = resultado.responsavelLocal {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Responsável no local:", bundle: bundleApresentacao)
                            .font(FrilaTipo.nota)
                            .foregroundStyle(FrilaCor.textoSecundario)
                        Text(verbatim: resp)
                            .font(FrilaTipo.corpo)
                    }
                }

                if let turnoID = resultado.turnoID {
                    BotaoPrimario(verbatim: TextosChamadaDireta.verTurno) {
                        if let onAbrirTurno {
                            onAbrirTurno(turnoID)
                        } else {
                            fechar()
                        }
                    }
                    .accessibilityIdentifier("ver-turno-aceito")
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var sheetRecusa: some View {
        NavigationStack {
            Form {
                Section(TextosChamadaDireta.motivoRecusaTitulo) {
                    Picker(selection: $viewModel.motivoSelecionado) {
                        Text("Nenhum motivo específico", bundle: bundleApresentacao)
                            .tag(Optional<MotivoRecusaChamada>.none)
                        Text(verbatim: TextosChamadaDireta.motivoAgenda)
                            .tag(Optional(MotivoRecusaChamada.agenda))
                        Text(verbatim: TextosChamadaDireta.motivoDistancia)
                            .tag(Optional(MotivoRecusaChamada.distancia))
                        Text(verbatim: TextosChamadaDireta.motivoValor)
                            .tag(Optional(MotivoRecusaChamada.valor))
                        Text(verbatim: TextosChamadaDireta.motivoTipoDeServico)
                            .tag(Optional(MotivoRecusaChamada.tipoDeServico))
                        Text(verbatim: TextosChamadaDireta.motivoOutro)
                            .tag(Optional(MotivoRecusaChamada.outro))
                    } label: {
                        Text("Motivo da recusa", bundle: bundleApresentacao)
                    }
                    .pickerStyle(.inline)
                }

                Section {
                    BotaoPrimario(verbatim: TextosChamadaDireta.recusarChamada, carregando: viewModel.respondendo) {
                        Task { await viewModel.recusar() }
                    }
                    .accessibilityIdentifier("confirmar-recusa-chamada")

                    Button(role: .cancel) {
                        viewModel.mostrarRecusa = false
                    } label: {
                        Text("Cancelar", bundle: bundleApresentacao)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle(Text(verbatim: TextosChamadaDireta.recusarChamada))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
