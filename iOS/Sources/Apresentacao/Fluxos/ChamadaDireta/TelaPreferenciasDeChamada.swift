// TELA PROVISÓRIA (a seção "Aceito chamadas diretas"): substituir pelo high-fi do Fabrício
import FrilaDominio
import SwiftUI

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
        Form {
            if let erro = viewModel.erro {
                AvisoFrila(verbatim: erro, tom: .erro)
            }
            if viewModel.sucesso {
                AvisoFrila(verbatim: TextosChamadaDireta.preferenciasSalvas, tom: .informativo)
            }

            Section {
                Toggle(TextosChamadaDireta.receberDeQuemJaTrabalhou, isOn: $viewModel.aceitaDeQuemJaTrabalhou)
                    .accessibilityIdentifier("toggle-receber-chamadas")
                Text(verbatim: TextosChamadaDireta.receberDeQuemJaTrabalhouSubtitulo)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }

            if viewModel.buscaHabilitada { aceitoChamadasDiretas }

            Section {
                Toggle(TextosChamadaDireta.pausarChamadas, isOn: $viewModel.pausarChamadas)
                    .accessibilityIdentifier("toggle-pausa-chamadas")

                if viewModel.pausarChamadas {
                    DatePicker(
                        TextosChamadaDireta.pausarAteData,
                        selection: $viewModel.pausadoAte,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("data-pausa-chamadas")

                    Text(verbatim: viewModel.textoRetomadaPausa)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
            }

            Section(TextosChamadaDireta.antecedenciaMinima) {
                Picker(TextosChamadaDireta.antecedenciaMinima, selection: $viewModel.antecedenciaMinimaH) {
                    Text(verbatim: TextosChamadaDireta.antecedencia2h).tag(2)
                    Text(verbatim: TextosChamadaDireta.antecedencia6h).tag(6)
                    Text(verbatim: TextosChamadaDireta.antecedencia24h).tag(24)
                    Text(verbatim: TextosChamadaDireta.antecedencia48h).tag(48)
                }
                .accessibilityIdentifier("picker-antecedencia-chamada")
            }

            Section(TextosChamadaDireta.quemPodeChamar) {
                Picker(TextosChamadaDireta.quemPodeChamar, selection: $viewModel.aceitaDe) {
                    Text(verbatim: TextosChamadaDireta.quemTodos).tag(QuemPodeChamar.todos)
                    Text(verbatim: TextosChamadaDireta.quemSoCnpj).tag(QuemPodeChamar.soCnpj)
                }
                .accessibilityIdentifier("picker-quem-pode-chamar")
            }

            Section {
                Text(verbatim: TextosChamadaDireta.avisoChamadasExistentes)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)

                BotaoPrimario(verbatim: TextosChamadaDireta.salvarPreferencias, carregando: viewModel.salvando) {
                    Task { await viewModel.salvar() }
                }
                .accessibilityIdentifier("salvar-preferencias-chamada")
            }
        }
        .font(FrilaTipo.corpo)
        .foregroundStyle(FrilaCor.texto)
        .scrollContentBackground(.hidden)
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosChamadaDireta.preferenciasTitulo))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.carregar() }
    }

    /// "Aceito chamadas diretas" (0.2.88): põe o profissional na busca. Só com a chave `busca_profissionais` ligada.
    private var aceitoChamadasDiretas: some View {
        Section {
            Toggle(TextosBuscaDeProfissionais.aceitoChamadas, isOn: $viewModel.aceitaChamadas)
                .accessibilityIdentifier("toggle-aceito-chamadas-diretas")
            Text(verbatim: TextosBuscaDeProfissionais.aceitoChamadasExplicacao)
            if viewModel.apareceNaBusca {
                Text(verbatim: TextosBuscaDeProfissionais.apareceNaBusca)
                    .accessibilityIdentifier("aparece-na-busca")
            } else if viewModel.aceitaChamadas, !viewModel.pendenciasParaBusca.isEmpty {
                Text(verbatim: TextosBuscaDeProfissionais.paraAparecerNaBusca)
                ForEach(viewModel.pendenciasParaBusca, id: \.self) { pendencia in
                    Text(verbatim: TextosBuscaDeProfissionais.pendencia(pendencia))
                }
                .accessibilityIdentifier("pendencias-para-busca")
            }
        }
    }
}
