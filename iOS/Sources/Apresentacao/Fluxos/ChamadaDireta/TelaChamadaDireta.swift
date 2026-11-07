import FrilaDominio
import SwiftUI

struct BotaoChamarDeNovo: View {
    let api: any ApiCliente
    let profissionalID: UUID
    let estabelecimentoID: UUID
    var vagaID: UUID?
    @State private var aberto = false

    var body: some View {
        BotaoSecundario(verbatim: TextosChamadaDireta.titulo) { aberto = true }
            .accessibilityIdentifier("chamar-de-novo-\(profissionalID)")
            .sheet(isPresented: $aberto) {
                NavigationStack {
                    TelaChamadaDireta(viewModel: ChamadaDiretaViewModel(api: api, profissionalID: profissionalID,
                        estabelecimentoID: estabelecimentoID, vagaID: vagaID))
                }
            }
    }
}

public struct TelaChamadaDireta: View {
    @State private var viewModel: ChamadaDiretaViewModel
    @Environment(\.dismiss) private var fechar

    public init(viewModel: ChamadaDiretaViewModel) { _viewModel = State(initialValue: viewModel) }

    public var body: some View {
        Form {
            if viewModel.carregando { ProgressView() }
            if let erro = viewModel.erro {
                AvisoFrila(verbatim: erro, tom: .erro)
                if !viewModel.recursoHabilitado {
                    BotaoSecundario("Tentar novamente") { Task { await viewModel.carregar() } }
                }
            }
            if viewModel.resultado != nil {
                AvisoFrila(verbatim: TextosChamadaDireta.sucesso, tom: .informativo)
            } else if viewModel.recursoHabilitado {
                campos
                    .disabled(viewModel.tentativa != nil || viewModel.enviando)
                BotaoPrimario(verbatim: TextosChamadaDireta.enviar, carregando: viewModel.enviando) {
                    Task { await viewModel.enviar() }
                }
                .disabled(!viewModel.podeEnviar)
                .accessibilityIdentifier("enviar-chamada")
                .alert(Text(verbatim: TextosChamadaDireta.j7Titulo), isPresented: $viewModel.mostrarJ7) {
                    Button(role: .cancel) { viewModel.mostrarJ7 = false } label: { Text("Cancelar", bundle: bundleApresentacao) }
                    Button {
                        Task { await viewModel.enviar(confirmoRecorrencia: true) }
                    } label: { Text(verbatim: TextosChamadaDireta.j7Confirmar) }
                } message: { Text(verbatim: TextosChamadaDireta.j7Mensagem) }
            }
        }
        .font(FrilaTipo.corpo)
        .foregroundStyle(FrilaCor.texto)
        .scrollContentBackground(.hidden)
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosChamadaDireta.titulo))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { fechar() } label: { Text("Fechar", bundle: bundleApresentacao) }
            }
        }
        .interactiveDismissDisabled(viewModel.enviando)
        .task { await viewModel.carregar() }
    }

    private var campos: some View {
        Group {
            Picker(selection: $viewModel.funcaoID) {
                ForEach(viewModel.funcoes) { funcao in
                    Text(verbatim: funcao.nome).tag(Optional(funcao.id))
                }
            } label: { Text("Função", bundle: bundleApresentacao) }
            LabeledContent { Text(verbatim: viewModel.local) } label: { Text("Local", bundle: bundleApresentacao) }
            DatePicker(selection: $viewModel.inicio) { Text("Início", bundle: bundleApresentacao) }
            DatePicker(selection: $viewModel.fim) { Text("Término", bundle: bundleApresentacao) }
            TextField(TextosChamadaDireta.responsavel, text: $viewModel.responsavel)
                .textInputAutocapitalization(.words)
            TextField(TextosChamadaDireta.valor, value: $viewModel.valorCentavos, format: .number.grouping(.never))
                .keyboardType(.numberPad)
                .accessibilityIdentifier("total-chamada-centavos")
            if let valor = try? Dinheiro(centavos: viewModel.valorCentavos) {
                Text(verbatim: FormatadorFrila().dinheiro(valor)).font(FrilaTipo.preco)
            }
            Toggle(isOn: $viewModel.totalConfirmado) { Text(verbatim: TextosChamadaDireta.total) }
                .accessibilityIdentifier("confirmar-total-chamada")
            Toggle(isOn: $viewModel.refeicao) { Text("Inclui refeição", bundle: bundleApresentacao) }
            Toggle(isOn: $viewModel.transporte) { Text("Inclui transporte", bundle: bundleApresentacao) }
            Toggle(isOn: $viewModel.materialProprio) { Text("Exige material próprio", bundle: bundleApresentacao) }
            TextField(TextosChamadaDireta.recado, text: $viewModel.recado, axis: .vertical)
                .lineLimit(3...6)
            if viewModel.recado.count > 300 {
                Text(verbatim: TextosChamadaDireta.recadoLongo).foregroundStyle(FrilaCor.perigo)
            }
        }
    }
}
