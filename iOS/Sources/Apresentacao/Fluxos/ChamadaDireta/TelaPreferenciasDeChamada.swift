import FrilaDominio
import SwiftUI

/// Preferências de chamadas do profissional: quem pode chamar, quando e com que antecedência. Cada bloco é um grupo de
/// linhas; as escolhas únicas (antecedência e quem pode chamar) são listas com check, e o "Salvar" fica no rodapé ancorado.
public struct TelaPreferenciasDeChamada: View {
    @State private var viewModel: PreferenciasChamadaViewModel
    @Environment(\.dismiss) private var fechar

    public init(api: any ApiCliente) {
        _viewModel = State(initialValue: PreferenciasChamadaViewModel(api: api))
    }

    public init(viewModel: PreferenciasChamadaViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                // Sem a leitura, o Salvar fica desligado: só religa quando ler de novo der certo.
                if let erro = viewModel.erro, !viewModel.leituraFeita {
                    AvisoFrila(verbatim: erro, tom: .erro)
                    BotaoSecundario(verbatim: TextosChamadaDireta.tentarDeNovo) {
                        Task { await viewModel.carregar() }
                    }
                    .disabled(viewModel.carregando)
                    .accessibilityIdentifier("preferencias-tentar-de-novo")
                }

                bloco(nota: TextosChamadaDireta.receberDeQuemJaTrabalhouSubtitulo) {
                    linhaDeInterruptor(TextosChamadaDireta.receberDeQuemJaTrabalhou, ligado: $viewModel.aceitaDeQuemJaTrabalhou)
                        .accessibilityIdentifier("toggle-receber-chamadas")
                }

                if viewModel.buscaHabilitada { aceitoChamadasDiretas }

                pausa

                FrilaGrupoDeLinhas(verbatim: TextosChamadaDireta.antecedenciaMinima, linhasComIcone: false) {
                    ForEach([2, 6, 24, 48], id: \.self) { horas in
                        FrilaLinhaDeOpcao(titulo: Self.antecedencia(horas), remate: .marcada(viewModel.antecedenciaMinimaH == horas)) {
                            viewModel.antecedenciaMinimaH = horas
                        }
                        .accessibilityIdentifier("antecedencia-chamada-\(horas)h")
                    }
                }
                .accessibilityIdentifier("picker-antecedencia-chamada")

                FrilaGrupoDeLinhas(verbatim: TextosChamadaDireta.quemPodeChamar, linhasComIcone: false) {
                    FrilaLinhaDeOpcao(titulo: TextosChamadaDireta.quemTodos, remate: .marcada(viewModel.aceitaDe == .todos)) {
                        viewModel.aceitaDe = .todos
                    }
                    .accessibilityIdentifier("quem-pode-chamar-todos")
                    FrilaLinhaDeOpcao(titulo: TextosChamadaDireta.quemSoCnpj, remate: .marcada(viewModel.aceitaDe == .soCnpj)) {
                        viewModel.aceitaDe = .soCnpj
                    }
                    .accessibilityIdentifier("quem-pode-chamar-so-cnpj")
                }
                .accessibilityIdentifier("picker-quem-pode-chamar")

                Text(verbatim: TextosChamadaDireta.avisoChamadasExistentes)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.top, FrilaEspaco.bloco)
            .padding(.bottom, FrilaEspaco.grupo)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosChamadaDireta.preferenciasTitulo))
        .navigationBarTitleDisplayMode(.inline)
        .rodapeAncorado {
            // Erro de salvar e resultado: logo acima do botão, em tinta (o erro de leitura fica no corpo, com o "tentar de novo").
            if let erro = viewModel.erro, viewModel.leituraFeita {
                MensagemJuntoAoBotao(verbatim: erro)
            }
            if viewModel.sucesso {
                MensagemJuntoAoBotao(verbatim: TextosChamadaDireta.preferenciasSalvas)
            }
            BotaoPrimario(verbatim: TextosChamadaDireta.salvarPreferencias, carregando: viewModel.salvando) {
                Task { await viewModel.salvar() }
            }
            .disabled(!viewModel.podeSalvar)
            .accessibilityIdentifier("salvar-preferencias-chamada")
        }
        .task { await viewModel.carregar() }
    }

    // MARK: Blocos

    /// "Aceito chamadas diretas" (0.2.88): põe o profissional na busca. Só com a chave `busca_profissionais` ligada.
    private var aceitoChamadasDiretas: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            FrilaGrupoDeLinhas(linhasComIcone: false) {
                linhaDeInterruptor(TextosBuscaDeProfissionais.aceitoChamadas, ligado: $viewModel.aceitaChamadas)
                    .accessibilityIdentifier("toggle-aceito-chamadas-diretas")
            }
            Text(verbatim: TextosBuscaDeProfissionais.aceitoChamadasExplicacao)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
            if viewModel.apareceNaBusca {
                FrilaLinhaDeDado(icone: "checkmark") {
                    Text(verbatim: TextosBuscaDeProfissionais.apareceNaBusca)
                }
                .accessibilityIdentifier("aparece-na-busca")
            } else if viewModel.aceitaChamadas, !viewModel.pendenciasParaBusca.isEmpty {
                // Cada pendência é uma linha de dado; o ponto separa a lista do texto de cima.
                VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                    Text(verbatim: TextosBuscaDeProfissionais.paraAparecerNaBusca)
                        .font(FrilaTipo.rotuloDeGrupo)
                        .foregroundStyle(FrilaCor.textoSecundario)
                    ForEach(viewModel.pendenciasParaBusca, id: \.self) { pendencia in
                        FrilaLinhaDeDado(icone: "circle") {
                            Text(verbatim: TextosBuscaDeProfissionais.pendencia(pendencia))
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("pendencias-para-busca")
            }
        }
    }

    /// "Pausar novas chamadas" e, ligada, a data. O texto de quando as chamadas voltam fica abaixo.
    private var pausa: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            FrilaGrupoDeLinhas(linhasComIcone: false) {
                linhaDeInterruptor(TextosChamadaDireta.pausarChamadas, ligado: $viewModel.pausarChamadas)
                    .accessibilityIdentifier("toggle-pausa-chamadas")
                if viewModel.pausarChamadas {
                    DatePicker(
                        TextosChamadaDireta.pausarAteData,
                        selection: $viewModel.pausadoAte,
                        displayedComponents: .date
                    )
                    .font(FrilaTipo.rotuloSecundario)
                    .padding(.horizontal, FrilaMedidaDeLinha.margem)
                    .padding(.vertical, FrilaEspaco.item)
                    .frame(minHeight: FrilaMetrica.alvo)
                    .accessibilityIdentifier("data-pausa-chamadas")
                }
            }
            if viewModel.pausarChamadas {
                Text(verbatim: viewModel.textoRetomadaPausa)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Um grupo de linhas e, logo abaixo, a nota que o explica.
    private func bloco(nota: String, @ViewBuilder linhas: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            FrilaGrupoDeLinhas(linhasComIcone: false) { linhas() }
            Text(verbatim: nota)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// A linha de um interruptor nativo, com a margem e o alvo das linhas do sistema.
    private func linhaDeInterruptor(_ titulo: String, ligado: Binding<Bool>) -> some View {
        Toggle(isOn: ligado) {
            Text(verbatim: titulo)
                .font(FrilaTipo.rotuloSecundario)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, FrilaMedidaDeLinha.margem)
        .padding(.vertical, FrilaEspaco.item)
        .frame(minHeight: FrilaMetrica.alvo)
    }

    private static func antecedencia(_ horas: Int) -> String {
        switch horas {
        case 2: TextosChamadaDireta.antecedencia2h
        case 6: TextosChamadaDireta.antecedencia6h
        case 24: TextosChamadaDireta.antecedencia24h
        default: TextosChamadaDireta.antecedencia48h
        }
    }
}
