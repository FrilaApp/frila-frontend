import FrilaDominio
import SwiftUI

/// Exclusão de conta (#25): o aviso, o que acontece, os turnos futuros, a confirmação e o botão da exclusão, tudo no
/// conteúdo rolável, nessa ordem. O Fabrício não desenhou esta tela: extrapolada do sistema (ação de risco sem laranja
/// e sem vermelho; a consequência vem escrita, e o botão repete a ação).
public struct TelaExclusaoDeConta: View {
    @State private var viewModel: ExclusaoDeContaViewModel
    @State private var mostrarDialogoConfirmacao = false
    private let formatador = FormatadorFrila()

    public init(viewModel: ExclusaoDeContaViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                Text(verbatim: TextosExclusaoDeConta.titulo)
                    .font(FrilaTipo.tituloDaTela)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                avisoPrincipal
                secaoConsequencias
                secaoTurnosFuturos
                secaoConfirmacao
                acaoDeExcluir
            }
            .padding(.top, FrilaEspaco.item)
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.bottom, FrilaEspaco.secao)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
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
            VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                Text(verbatim: TextosExclusaoDeConta.dialogoTitulo)
                    .font(FrilaTipo.tituloDaTela)
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
            .padding(.top, FrilaEspaco.grupo)
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.bottom, FrilaEspaco.grupo)
        }
        .rodapeAncorado {
            BotaoSecundario(verbatim: TextosExclusaoDeConta.cancelar) {
                mostrarDialogoConfirmacao = false
            }
            .accessibilityIdentifier("botao-cancelar-exclusao-dialogo")

            Button(role: .destructive) {
                mostrarDialogoConfirmacao = false
                Task { await viewModel.confirmarExclusao() }
            } label: {
                Text(verbatim: TextosExclusaoDeConta.dialogoConfirmar)
                    .capsulaDestrutiva()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("botao-confirmar-exclusao-dialogo")
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationCornerRadius(FrilaRaio.folha)
        .presentationDragIndicator(.visible)
    }

    private var avisoPrincipal: some View {
        AvisoFrila(verbatim: TextosExclusaoDeConta.avisoConsequencias, tom: .alerta)
            .accessibilityIdentifier("aviso-consequencias-exclusao")
    }

    private var secaoConsequencias: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            rotuloDeSecao(TextosExclusaoDeConta.secaoOQueAcontece)

            FrilaLinhaDeDado(icone: "person.crop.circle.badge.minus") {
                Text(verbatim: TextosExclusaoDeConta.consequenciaAnonimizacao)
            }
            FrilaLinhaDeDado(icone: "calendar.badge.minus") {
                Text(verbatim: TextosExclusaoDeConta.consequenciaTurnos)
            }
            FrilaLinhaDeDado(icone: "clock.badge.xmark") {
                Text(verbatim: TextosExclusaoDeConta.consequenciaPrazo)
            }
        }
    }

    private func rotuloDeSecao(_ texto: String) -> some View {
        Text(verbatim: texto)
            .font(FrilaTipo.rotuloDeGrupo)
            .foregroundStyle(FrilaCor.textoSecundario)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private var secaoTurnosFuturos: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            rotuloDeSecao(TextosExclusaoDeConta.tituloTurnosFuturos)

            if viewModel.carregandoTurnos {
                HStack(spacing: FrilaEspaco.item) {
                    ProgressView()
                    Text(verbatim: TextosExclusaoDeConta.carregandoTurnos)
                        .font(FrilaTipo.apoio)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if viewModel.turnosFuturos.isEmpty && !viewModel.listaTurnosIndisponivel {
                Text(verbatim: TextosExclusaoDeConta.semTurnosFuturos)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityIdentifier("texto-sem-turnos-futuros")
            } else if !viewModel.turnosFuturos.isEmpty {
                FrilaGrupoDeLinhas(linhasComIcone: false) {
                    ForEach(viewModel.turnosFuturos) { turno in
                        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                            Text(verbatim: turno.vaga.funcao)
                                .font(FrilaTipo.nome)
                                .foregroundStyle(FrilaCor.texto)
                            Text(verbatim: turno.contraparte.nome)
                                .font(FrilaTipo.apoio)
                                .foregroundStyle(FrilaCor.textoSecundario)
                            Text(verbatim: formatador.intervalo(turno.vaga.periodo))
                                .font(FrilaTipo.apoio)
                                .foregroundStyle(FrilaCor.textoSecundario)
                            Text(verbatim: turno.vaga.local)
                                .font(FrilaTipo.apoio)
                                .foregroundStyle(FrilaCor.textoSecundario)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(FrilaMedidaDeLinha.margem)
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
    }

    private var secaoConfirmacao: some View {
        Toggle(isOn: $viewModel.confirmouConsequencias) {
            Text(verbatim: TextosExclusaoDeConta.confirmacaoCheck)
                .font(FrilaTipo.rotuloSecundario)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
        }
        .toggleStyle(.switch)
        .tint(FrilaCor.selecao)
        .frame(minHeight: FrilaMetrica.alvo)
        .accessibilityIdentifier("toggle-confirmar-consequencias")
    }

    /// A mensagem do erro e o botão, no fim do conteúdo, depois da confirmação.
    @ViewBuilder
    private var acaoDeExcluir: some View {
        VStack(spacing: FrilaEspaco.item) {
            if let erro = viewModel.mensagemErro {
                MensagemJuntoAoBotao(verbatim: erro)
                    .accessibilityIdentifier("aviso-erro-exclusao")
            }
            botaoExcluir
        }
    }

    /// Ação de risco: sem laranja e sem vermelho, no desenho do botão secundário. Desligado (sem a confirmação ou
    /// enquanto exclui), fica no lugar com o fundo de controle e o rótulo em apoio.
    private var botaoExcluir: some View {
        let habilitado = viewModel.confirmouConsequencias && !viewModel.excluindo
        let forma = FrilaForma.capsulaQueCresce()
        return Button(role: .destructive) {
            mostrarDialogoConfirmacao = true
        } label: {
            Text(verbatim: viewModel.excluindo ? TextosExclusaoDeConta.excluindo : TextosExclusaoDeConta.botaoExcluir)
                .font(FrilaTipo.rotuloSecundario)
                .multilineTextAlignment(.center)
                .foregroundStyle(habilitado ? FrilaCor.texto : FrilaCor.textoSecundario)
                .padding(.horizontal, FrilaEspaco.bloco)
                .padding(.vertical, FrilaEspaco.item)
                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
                .background(habilitado ? FrilaCor.superficie : FrilaCor.controle, in: forma)
                .overlay(forma.strokeBorder(FrilaCor.borda, lineWidth: 1))
                .contentShape(forma)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.confirmouConsequencias || viewModel.excluindo)
        .accessibilityIdentifier("botao-excluir-conta-definitivo")
    }
}
