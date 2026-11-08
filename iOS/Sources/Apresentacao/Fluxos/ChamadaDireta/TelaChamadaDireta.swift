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
                        estabelecimentoID: estabelecimentoID, vagaID: vagaID), api: api)
                }
            }
    }
}

public struct TelaChamadaDireta: View {
    @State private var viewModel: ChamadaDiretaViewModel
    @Environment(\.dismiss) private var fechar
    /// Leva ao Acompanhar chamadas depois do envio (V11); sem ela, o resumo aparece sem o link.
    private let api: (any ApiCliente)?

    public init(viewModel: ChamadaDiretaViewModel, api: (any ApiCliente)? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.api = api
    }

    public var body: some View {
        Form {
            if viewModel.carregando { ProgressView() }
            if let erro = viewModel.erro {
                AvisoFrila(verbatim: erro, tom: .erro)
                if !viewModel.recursoHabilitado {
                    BotaoSecundario("Tentar novamente") { Task { await viewModel.carregar() } }
                }
            }
            if let chamada = viewModel.resultado {
                let _ = chamada
                AvisoFrila(verbatim: TextosChamadaDireta.sucesso, tom: .informativo) // MUTACAO
            } else if viewModel.recursoHabilitado {
                campos
                    .disabled(viewModel.tentativa != nil || viewModel.enviando)
                BotaoPrimario(verbatim: TextosChamadaDireta.enviar, carregando: viewModel.enviando) {
                    Task { await viewModel.enviar() }
                }
                .disabled(!viewModel.podeEnviar)
                .accessibilityIdentifier("enviar-chamada")
                .accessibilityHint(viewModel.oQueFalta.map { Text(verbatim: $0) } ?? Text(verbatim: ""))
                .alert(Text(verbatim: TextosChamadaDireta.j7Titulo), isPresented: $viewModel.mostrarJ7) {
                    Button(role: .cancel) { viewModel.mostrarJ7 = false } label: { Text("Cancelar", bundle: bundleApresentacao) }
                    Button {
                        Task { await viewModel.enviar(confirmoRecorrencia: true) }
                    } label: { Text(verbatim: TextosChamadaDireta.j7Confirmar) }
                } message: { Text(verbatim: TextosChamadaDireta.j7Mensagem) }
                if let falta = viewModel.oQueFalta {
                    Text(verbatim: falta)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true) // já é a dica do botão no VoiceOver
                        .accessibilityIdentifier("chamada-o-que-falta")
                }
            }
        }
        .font(FrilaTipo.corpo)
        .foregroundStyle(FrilaCor.texto)
        .scrollContentBackground(.hidden)
        .background(FrilaCor.fundo)
        // V12: "Chamar de novo" fica no botão de quem já trabalhou com a casa; a folha diz o que faz.
        .navigationTitle(Text(verbatim: TextosChamadaDireta.tituloDaFolha))
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
            // V10: o seletor não oferece horário que já passou nem a menos de 2 h.
            DatePicker(selection: $viewModel.inicio, in: viewModel.inicioMinimo...) { Text("Início", bundle: bundleApresentacao) }
                .accessibilityIdentifier("inicio-chamada")
            DatePicker(selection: $viewModel.fim, in: viewModel.faixaDoTermino) { Text("Término", bundle: bundleApresentacao) }
                .accessibilityIdentifier("termino-chamada")
            // V9: o Form não mostra o rótulo de um TextField, e o campo preenchido ("Bistrô Ipê",
            // "0") ficava solto. O rótulo vai acima, visível; o VoiceOver lê o rótulo no próprio campo.
            CampoRotulado(TextosChamadaDireta.responsavel) {
                TextField(text: $viewModel.responsavel) { Text(verbatim: TextosChamadaDireta.responsavel) }
                    .textInputAutocapitalization(.words)
                    // Preenchido ("Bistrô Ipê"), o campo ficava sem nome no VoiceOver.
                    .accessibilityLabel(Text(verbatim: TextosChamadaDireta.responsavel))
                    .accessibilityIdentifier("responsavel-chamada")
            }
            CampoRotulado(TextosChamadaDireta.valor) {
                HStack(spacing: FrilaEspaco.pequeno) {
                    Text(verbatim: TextosChamadaDireta.moeda).accessibilityHidden(true)
                    CampoMascara(texto: $viewModel.valorTexto, placeholder: TextosChamadaDireta.valorExemplo,
                                 rotuloAcessibilidade: TextosChamadaDireta.valor,
                                 identificadorAcessibilidade: "total-chamada-centavos", teclado: .decimalPad) { novo, _ in
                        ChamadaDiretaViewModel.valorDigitado(novo)
                    }
                }
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

/// Rótulo visível acima do campo, dentro do Form. O rótulo some do VoiceOver porque o campo já o lê.
private struct CampoRotulado<Campo: View>: View {
    let rotulo: String
    @ViewBuilder let campo: Campo

    init(_ rotulo: String, @ViewBuilder campo: () -> Campo) {
        self.rotulo = rotulo
        self.campo = campo()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: rotulo)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            campo
        }
    }
}
