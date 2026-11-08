import FrilaDominio
import SwiftUI
import UIKit

public struct TelaEditarServicos: View {
    @State private var modelo: ServicosDoProfissionalViewModel
    public init(modelo: ServicosDoProfissionalViewModel) { _modelo = State(initialValue: modelo) }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                Text("Serviços são opcionais. Você recebe o valor integral; o Frila não desconta nada.", bundle: bundleApresentacao)
                if modelo.carregando { EstadoCarregando() }
                ForEach($modelo.rascunhos) { $rascunho in
                    EditorDeServico(rascunho: $rascunho, especialidades: modelo.especialidades[rascunho.id] ?? [],
                                    campoComErro: modelo.funcaoComErro == nil || modelo.funcaoComErro == rascunho.id ? modelo.erro?.detalhes : nil)
                }
                if let erro = modelo.erro {
                    AvisoFrila(verbatim: MensagemDoErroAPI.texto(erro), tom: .erro)
                    if !modelo.carregou {
                        BotaoSecundario("Tentar de novo") { Task { await modelo.carregar() } }
                    }
                }
                // V18: o sucesso é um aviso, e não um texto cinza solto acima do botão.
                if modelo.sucesso { AvisoFrila("Serviços salvos", tom: .informativo).accessibilityIdentifier("servicos-sucesso") }
                BotaoPrimario("Salvar alterações", carregando: modelo.salvando) {
                    // V16: com o teclado aberto, o aviso de erro ficava escondido atrás dele.
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    Task { await modelo.salvar() }
                }
                    .disabled(!modelo.carregou || modelo.carregando)
                    .accessibilityIdentifier("salvar-servicos")
            }
            .padding(FrilaEspaco.medio)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
            .frame(maxWidth: .infinity)
        }
        .font(FrilaTipo.corpo).foregroundStyle(FrilaCor.texto).background(FrilaCor.fundo)
        .navigationTitle(Text("Editar serviços", bundle: bundleApresentacao))
        .scrollDismissesKeyboard(.interactively).frilaKeyboardDismissScope()
        .disabled(modelo.salvando)
        .task { await modelo.carregar() }
        .onChange(of: modelo.rascunhos) { _, _ in modelo.limparSucesso() }
        .accessibilityIdentifier("tela-editar-servicos")
    }
}

private struct EditorDeServico: View {
    @Binding var rascunho: ServicoEmEdicao
    let especialidades: [Especialidade]
    let campoComErro: String?

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Toggle(isOn: $rascunho.habilitado) { Text(verbatim: rascunho.funcao.nome).font(FrilaTipo.secao) }
                .frame(minHeight: 44)
            if rascunho.habilitado {
                if let dica = rascunho.funcao.dicaPerfil { Text(verbatim: dica).font(FrilaTipo.nota) }
                Picker(selection: $rascunho.dados.unidade) {
                    ForEach(UnidadePreco.allCases, id: \.self) { Text(verbatim: TextosDosServicos.unidade($0)).tag($0) }
                } label: { Text("Unidade de preço", bundle: bundleApresentacao) }
                    .labelsHidden()
                    .accessibilityIdentifier("unidade-servico")
                    .campoDeServico("Unidade de preço")
                    .onChange(of: rascunho.dados.unidade) { _, _ in rascunho.trocarUnidade() }
                if rascunho.dados.unidade == .aCombinar {
                    Text("A combinar: o total será confirmado na chamada.", bundle: bundleApresentacao)
                } else {
                    TextField(text: $rascunho.valor, prompt: Text("0,00", bundle: bundleApresentacao)) { Text("Valor em reais", bundle: bundleApresentacao) }.keyboardType(.decimalPad).accessibilityIdentifier("valor-servico").campoDeServico("Valor em reais")
                    if [.hora, .diaria, .pacote].contains(rascunho.dados.unidade) {
                        TextField(text: $rascunho.valorMaximo, prompt: Text("0,00", bundle: bundleApresentacao)) { Text("Valor máximo em reais (opcional)", bundle: bundleApresentacao) }.keyboardType(.decimalPad).campoDeServico("Valor máximo em reais (opcional)")
                    }
                    Text("De R$ 10 a R$ 10.000 por unidade.", bundle: bundleApresentacao).font(FrilaTipo.nota)
                }
                if let resumo = TextosDosServicos.resumoDaDiaria(rascunho) { Text(verbatim: resumo).font(FrilaTipo.nota) }
                camposDaUnidade
                Picker(selection: $rascunho.dados.levaMaterial) {
                    Text("Não informado", bundle: bundleApresentacao).tag(LevaMaterial?.none)
                    ForEach(LevaMaterial.allCases, id: \.self) { Text(verbatim: TextosDosServicos.material($0)).tag(Optional($0)) }
                } label: { Text("Leva material?", bundle: bundleApresentacao) }
                    .labelsHidden()
                    .accessibilityIdentifier("material-servico")
                    .campoDeServico("Leva material?")
                TextField(text: $rascunho.dados.itensInclusos.valorOuVazio, prompt: Text(verbatim: ""), axis: .vertical) {
                    Text("O que está incluído (até 300 caracteres)", bundle: bundleApresentacao)
                }
                .accessibilityIdentifier("inclui-servico").campoDeServico("O que está incluído (até 300 caracteres)")
                if campoComErro == "inclui" { erroDoCampo("inclui") }
                ForEach(especialidades) { especialidade in
                    Toggle(isOn: selecionada(especialidade.id)) { Text(verbatim: especialidade.nome) }
                        .disabled(!(rascunho.dados.especialidadeIDs ?? []).contains(especialidade.id) && (rascunho.dados.especialidadeIDs?.count ?? 0) >= 8)
                        .frame(minHeight: 44)
                }
                if !especialidades.isEmpty { Text("Escolha até 8 especialidades.", bundle: bundleApresentacao).font(FrilaTipo.nota) }
                if let campoComErro, campoComErro != "inclui" { erroDoCampo(campoComErro) }
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(FrilaEspaco.medio)
        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada))
    }

    private func erroDoCampo(_ campo: String) -> some View {
        Text(verbatim: TextosDosServicos.campo(campo)).foregroundStyle(FrilaCor.perigo)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("erro-servico-\(campo)")
    }

    @ViewBuilder private var camposDaUnidade: some View {
        switch rascunho.dados.unidade {
        case .diaria:
            TextField(value: $rascunho.dados.horasIncluidas, format: .number, prompt: Text(verbatim: "")) { Text("Horas incluídas (4 a 12)", bundle: bundleApresentacao) }.keyboardType(.numberPad).accessibilityIdentifier("horas-servico").campoDeServico("Horas incluídas (4 a 12)")
        case .hora:
            TextField(value: $rascunho.dados.minimoHoras, format: .number, prompt: Text(verbatim: "")) { Text("Mínimo de horas (opcional, 1 a 12)", bundle: bundleApresentacao) }.keyboardType(.numberPad).campoDeServico("Mínimo de horas (opcional, 1 a 12)")
        case .evento:
            TextField(value: $rascunho.dados.duracaoTipicaH, format: .number, prompt: Text(verbatim: "")) { Text("Duração em horas (opcional, 1 a 24)", bundle: bundleApresentacao) }.keyboardType(.numberPad).campoDeServico("Duração em horas (opcional, 1 a 24)")
            TextField(value: $rascunho.dados.atePessoas, format: .number, prompt: Text(verbatim: "")) { Text("Até quantas pessoas (opcional, 1 a 2.000)", bundle: bundleApresentacao) }.keyboardType(.numberPad).campoDeServico("Até quantas pessoas (opcional, 1 a 2.000)")
        case .pacote:
            TextField(text: $rascunho.dados.descricaoPacote.valorOuVazio, prompt: Text(verbatim: ""), axis: .vertical) { Text("Descrição do pacote (até 120 caracteres)", bundle: bundleApresentacao) }.campoDeServico("Descrição do pacote (até 120 caracteres)")
        case .porPessoa:
            TextField(value: $rascunho.dados.minimoPessoas, format: .number, prompt: Text(verbatim: "")) { Text("Mínimo de pessoas (1 a 2.000)", bundle: bundleApresentacao) }.keyboardType(.numberPad).campoDeServico("Mínimo de pessoas (1 a 2.000)")
        case .aCombinar: EmptyView()
        }
    }

    private func selecionada(_ id: UUID) -> Binding<Bool> {
        Binding(get: { (rascunho.dados.especialidadeIDs ?? []).contains(id) }, set: { selecionada in
            var ids = rascunho.dados.especialidadeIDs ?? []
            if selecionada, ids.count < 8, !ids.contains(id) { ids.append(id) }
            if !selecionada { ids.removeAll { $0 == id } }
            rascunho.dados.especialidadeIDs = ids
        })
    }
}

private extension Optional where Wrapped == String {
    var valorOuVazio: String {
        get { self ?? "" }
        set { self = newValue.isEmpty ? nil : newValue }
    }
}

private extension View {
    func campoDeServico(_ titulo: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            // O campo já tem o mesmo rótulo para o VoiceOver: o texto visível não é lido duas vezes.
            Text(titulo, bundle: bundleApresentacao).font(FrilaTipo.nota).accessibilityHidden(true)
            self.frame(minHeight: 44, alignment: .leading)
        }
    }
}
