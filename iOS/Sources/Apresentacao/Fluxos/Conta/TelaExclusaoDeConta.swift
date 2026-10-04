import FrilaDominio
import SwiftUI

public struct TelaExclusaoDeConta: View {
    @State private var viewModel: ExclusaoDeContaViewModel
    @State private var mostrarDialogoConfirmacao = false
    private let formatador = FormatadorFrila()

    public init(viewModel: ExclusaoDeContaViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                avisoPrincipal
                secaoConsequencias
                secaoTurnosFuturos
                secaoConfirmacao

                if let erro = viewModel.mensagemErro {
                    AvisoFrila(verbatim: erro, tom: .erro)
                        .accessibilityIdentifier("aviso-erro-exclusao")
                }

                botaoExcluir
            }
            .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosExclusaoDeConta.titulo))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.carregar() }
        .confirmationDialog(
            Text(verbatim: TextosExclusaoDeConta.dialogoTitulo),
            isPresented: $mostrarDialogoConfirmacao,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                Task { await viewModel.confirmarExclusao() }
            } label: {
                Text(verbatim: TextosExclusaoDeConta.dialogoConfirmar)
            }
            .accessibilityIdentifier("botao-confirmar-exclusao-dialogo")

            Button(role: .cancel) {} label: {
                Text(verbatim: TextosExclusaoDeConta.cancelar)
            }
        } message: {
            Text(verbatim: TextosExclusaoDeConta.dialogoMensagem)
        }
        .accessibilityIdentifier("tela-exclusao-de-conta")
    }

    private var avisoPrincipal: some View {
        AvisoFrila(verbatim: TextosExclusaoDeConta.avisoConsequencias, tom: .alerta)
            .accessibilityIdentifier("aviso-consequencias-exclusao")
    }

    private var secaoConsequencias: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosExclusaoDeConta.secaoOQueAcontece)
                .font(.headline)
                .foregroundStyle(FrilaCor.texto)

            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                itemConsequencia(
                    icone: "person.crop.circle.badge.minus",
                    texto: TextosExclusaoDeConta.consequenciaAnonimizacao
                )
                itemConsequencia(
                    icone: "calendar.badge.minus",
                    texto: TextosExclusaoDeConta.consequenciaTurnos
                )
                itemConsequencia(
                    icone: "clock.badge.xmark",
                    texto: TextosExclusaoDeConta.consequenciaPrazo
                )
            }
        }
        .cartaoFrila()
    }

    private func itemConsequencia(icone: String, texto: String) -> some View {
        HStack(alignment: .top, spacing: FrilaEspaco.pequeno) {
            // Decorativo: o texto ao lado diz tudo; sem isto o VoiceOver lia o nome do símbolo.
            Image(systemName: icone)
                .foregroundStyle(FrilaCor.perigo)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            Text(verbatim: texto)
                .font(.subheadline)
                .foregroundStyle(FrilaCor.texto)
        }
        .padding(.vertical, 2)
    }

    private var secaoTurnosFuturos: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosExclusaoDeConta.tituloTurnosFuturos)
                .font(.headline)
                .foregroundStyle(FrilaCor.texto)

            if viewModel.carregandoTurnos {
                HStack(spacing: FrilaEspaco.pequeno) {
                    ProgressView()
                    Text(verbatim: TextosExclusaoDeConta.carregandoTurnos)
                        .font(.subheadline)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if viewModel.turnosFuturos.isEmpty && !viewModel.listaTurnosIndisponivel {
                Text(verbatim: TextosExclusaoDeConta.semTurnosFuturos)
                    .font(.subheadline)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityIdentifier("texto-sem-turnos-futuros")
            } else {
                VStack(spacing: FrilaEspaco.pequeno) {
                    ForEach(viewModel.turnosFuturos) { turno in
                        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                            Text(verbatim: turno.vaga.funcao)
                                .font(.subheadline.bold())
                                .foregroundStyle(FrilaCor.texto)
                            Text(verbatim: turno.contraparte.nome)
                                .font(.caption)
                                .foregroundStyle(FrilaCor.textoSecundario)
                            Text(verbatim: formatador.intervalo(turno.vaga.periodo))
                                .font(.caption)
                                .foregroundStyle(FrilaCor.textoSecundario)
                            Text(verbatim: turno.vaga.local)
                                .font(.caption)
                                .foregroundStyle(FrilaCor.textoSecundario)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(FrilaEspaco.pequeno)
                        .background(FrilaCor.fundo, in: RoundedRectangle(cornerRadius: FrilaRaio.pequeno))
                        .accessibilityIdentifier("item-turno-futuro-\(turno.id)")
                    }
                }
            }
            if let aviso = viewModel.avisoListaTurnos {
                AvisoFrila(verbatim: aviso, tom: .informativo)
                    .accessibilityIdentifier("aviso-lista-turnos-exclusao")
                if viewModel.listaTurnosIndisponivel {
                    BotaoSecundario(verbatim: TextosExclusaoDeConta.tentarNovamente) {
                        Task { await viewModel.carregar() }
                    }
                }
            }
        }
        .cartaoFrila()
    }

    private var secaoConfirmacao: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Toggle(isOn: $viewModel.confirmouConsequencias) {
                Text(verbatim: TextosExclusaoDeConta.confirmacaoCheck)
                    .font(.subheadline.bold())
                    .foregroundStyle(FrilaCor.texto)
            }
            .toggleStyle(.switch)
            .accessibilityIdentifier("toggle-confirmar-consequencias")
        }
        .cartaoFrila()
    }

    private var botaoExcluir: some View {
        Button(role: .destructive) {
            mostrarDialogoConfirmacao = true
        } label: {
            HStack {
                if viewModel.excluindo {
                    ProgressView()
                        .tint(FrilaCor.sobrePrimaria)
                } else {
                    Text(verbatim: TextosExclusaoDeConta.botaoExcluir)
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
            .contentShape(RoundedRectangle(cornerRadius: FrilaRaio.medio))
        }
        .buttonStyle(.plain)
        .foregroundStyle(FrilaCor.sobrePrimaria)
        .background(
            viewModel.confirmouConsequencias && !viewModel.excluindo
                ? FrilaCor.perigo
                : FrilaCor.textoSecundario.opacity(0.35),
            in: RoundedRectangle(cornerRadius: FrilaRaio.medio)
        )
        .disabled(!viewModel.confirmouConsequencias || viewModel.excluindo)
        .accessibilityIdentifier("botao-excluir-conta-definitivo")
    }
}
