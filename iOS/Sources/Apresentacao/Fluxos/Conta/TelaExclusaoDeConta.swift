import FrilaDominio
import SwiftUI

/// Exclusão de conta (#25): consequências em cartões Hi-Fi e confirmação destrutiva em cápsula.
public struct TelaExclusaoDeConta: View {
    @State private var viewModel: ExclusaoDeContaViewModel
    @State private var mostrarDialogoConfirmacao = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// O quadro do ícone acompanha a fonte: preso a 24 pt, o símbolo crescia e invadia o texto em AX5.
    @ScaledMetric private var ladoDoIcone: CGFloat = 24
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
        .toolbarBackground(FrilaCor.fundo, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)

        .task { await viewModel.carregar() }
        .sheet(isPresented: $mostrarDialogoConfirmacao) { confirmacaoFinal }
        .accessibilityIdentifier("tela-exclusao-de-conta")
    }

    /// Confirmação da ação irreversível. Era um `confirmationDialog` do sistema, e nos tamanhos de
    /// acessibilidade o título e a mensagem empurravam o Cancelar para fora da tela (QA de 04/10).
    /// Aqui o texto rola e os dois botões ficam presos ao rodapé, o Cancelar primeiro.
    private var confirmacaoFinal: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                Text(verbatim: TextosExclusaoDeConta.dialogoTitulo)
                    .font(FrilaTipo.tituloDeEstado)
                    .foregroundStyle(FrilaCor.texto)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: TextosExclusaoDeConta.dialogoMensagem)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FrilaEspaco.medio)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: FrilaEspaco.pequeno) {
                BotaoSecundario(verbatim: TextosExclusaoDeConta.cancelar) {
                    mostrarDialogoConfirmacao = false
                }
                .accessibilityIdentifier("botao-cancelar-exclusao-dialogo")

                Button(role: .destructive) {
                    mostrarDialogoConfirmacao = false
                    Task { await viewModel.confirmarExclusao() }
                } label: {
                    Text(verbatim: TextosExclusaoDeConta.dialogoConfirmar)
                        .font(FrilaTipo.botao)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, FrilaEspaco.pequeno)
                        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(FrilaCor.sobrePrimaria)
                .background(FrilaCor.perigo, in: Capsule())
                .accessibilityIdentifier("botao-confirmar-exclusao-dialogo")
            }
            .padding(FrilaEspaco.medio)
            .background(FrilaCor.fundo)
        }
        .background(FrilaCor.fundo)
        .presentationDetents([.large])
        .presentationCornerRadius(FrilaRaio.folha)
        .presentationDragIndicator(.visible)
    }

    private var avisoPrincipal: some View {
        AvisoFrila(verbatim: TextosExclusaoDeConta.avisoConsequencias, tom: .alerta)
            .accessibilityIdentifier("aviso-consequencias-exclusao")
    }

    private var secaoConsequencias: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosExclusaoDeConta.secaoOQueAcontece)
                .font(FrilaTipo.resumo)
                .textCase(.uppercase)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)

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
        // Nos tamanhos de acessibilidade o ícone vai acima, e o texto fica com a largura toda.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: FrilaEspaco.minimo))
            : AnyLayout(HStackLayout(alignment: .top, spacing: FrilaEspaco.pequeno))
        return layout {
            // Decorativo: o texto ao lado diz tudo; sem isto o VoiceOver lia o nome do símbolo.
            Image(systemName: icone)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
                .frame(width: ladoDoIcone, height: ladoDoIcone)
                .background(FrilaCor.controle, in: Circle())
                .accessibilityHidden(true)
            Text(verbatim: texto)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.texto)
        }
        .padding(.vertical, FrilaEspaco.minimo)
    }

    private var secaoTurnosFuturos: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosExclusaoDeConta.tituloTurnosFuturos)
                .font(FrilaTipo.resumo)
                .textCase(.uppercase)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)

            if viewModel.carregandoTurnos {
                HStack(spacing: FrilaEspaco.pequeno) {
                    ProgressView()
                    Text(verbatim: TextosExclusaoDeConta.carregandoTurnos)
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if viewModel.turnosFuturos.isEmpty && !viewModel.listaTurnosIndisponivel {
                Text(verbatim: TextosExclusaoDeConta.semTurnosFuturos)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityIdentifier("texto-sem-turnos-futuros")
            } else {
                VStack(spacing: FrilaEspaco.pequeno) {
                    ForEach(viewModel.turnosFuturos) { turno in
                        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                            Text(verbatim: turno.vaga.funcao)
                                .font(FrilaTipo.meta.bold())
                                .foregroundStyle(FrilaCor.texto)
                            Text(verbatim: turno.contraparte.nome)
                                .font(FrilaTipo.nota)
                                .foregroundStyle(FrilaCor.textoSecundario)
                            Text(verbatim: formatador.intervalo(turno.vaga.periodo))
                                .font(FrilaTipo.nota)
                                .foregroundStyle(FrilaCor.textoSecundario)
                            Text(verbatim: turno.vaga.local)
                                .font(FrilaTipo.nota)
                                .foregroundStyle(FrilaCor.textoSecundario)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(FrilaEspaco.pequeno)
                        .background(FrilaCor.controle, in: RoundedRectangle(cornerRadius: FrilaRaio.medio, style: .continuous))
                        .accessibilityElement(children: .combine)
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
                    .font(FrilaTipo.meta.bold())
                    .foregroundStyle(FrilaCor.texto)
            }
            .toggleStyle(.switch)
            .tint(FrilaCor.selecao)
            .accessibilityIdentifier("toggle-confirmar-consequencias")
        }
        .cartaoFrila()
    }

    private var botaoExcluir: some View {
        let habilitado = viewModel.confirmouConsequencias && !viewModel.excluindo
        return Button(role: .destructive) {
            mostrarDialogoConfirmacao = true
        } label: {
            HStack {
                if viewModel.excluindo {
                    ProgressView()
                        .tint(FrilaCor.textoSecundario)
                } else {
                    Text(verbatim: TextosExclusaoDeConta.botaoExcluir)
                        .font(FrilaTipo.botao)
                }
            }
            .padding(.vertical, FrilaEspaco.pequeno)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(habilitado ? FrilaCor.sobrePrimaria : FrilaCor.textoSecundario)
        .background(habilitado ? FrilaCor.perigo : FrilaCor.controle, in: Capsule())
        .disabled(!viewModel.confirmouConsequencias || viewModel.excluindo)
        .accessibilityIdentifier("botao-excluir-conta-definitivo")
    }
}
