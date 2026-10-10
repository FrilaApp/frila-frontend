import FrilaDominio
import SwiftUI

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
        // Sem fundo, a barra inline deixava o texto da rolagem passar por trás do Voltar e do título.
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
                    .font(.title3.bold())
                    .foregroundStyle(FrilaCor.texto)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: TextosExclusaoDeConta.dialogoMensagem)
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
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                        .contentShape(RoundedRectangle(cornerRadius: FrilaRaio.medio))
                }
                .buttonStyle(.plain)
                .foregroundStyle(FrilaCor.sobrePrimaria)
                .background(FrilaCor.perigo, in: RoundedRectangle(cornerRadius: FrilaRaio.medio))
                .accessibilityIdentifier("botao-confirmar-exclusao-dialogo")
            }
            .padding(FrilaEspaco.medio)
            .background(FrilaCor.fundo)
        }
        .background(FrilaCor.fundo)
        .presentationDetents([.large])
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
        // Nos tamanhos de acessibilidade o ícone vai acima, e o texto fica com a largura toda.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: FrilaEspaco.minimo))
            : AnyLayout(HStackLayout(alignment: .top, spacing: FrilaEspaco.pequeno))
        return layout {
            // Decorativo: o texto ao lado diz tudo; sem isto o VoiceOver lia o nome do símbolo.
            Image(systemName: icone)
                .foregroundStyle(FrilaCor.perigo)
                .frame(width: ladoDoIcone, height: ladoDoIcone)
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
                : FrilaCor.borda,
            in: RoundedRectangle(cornerRadius: FrilaRaio.medio)
        )
        .disabled(!viewModel.confirmouConsequencias || viewModel.excluindo)
        .accessibilityIdentifier("botao-excluir-conta-definitivo")
    }
}
