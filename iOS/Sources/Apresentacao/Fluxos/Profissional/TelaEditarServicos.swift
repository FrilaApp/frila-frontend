import FrilaDominio
import SwiftUI
import UIKit

public struct TelaEditarServicos: View {
    @State private var modelo: ServicosDoProfissionalViewModel
    public init(modelo: ServicosDoProfissionalViewModel) { _modelo = State(initialValue: modelo) }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                Text("Serviços são opcionais. Você recebe o valor integral; o Frila não desconta nada.", bundle: bundleApresentacao)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                if modelo.carregando { EstadoCarregando() }
                ForEach($modelo.rascunhos) { $rascunho in
                    EditorDeServico(rascunho: $rascunho, especialidades: modelo.especialidades[rascunho.id] ?? [],
                                    campoComErro: modelo.funcaoComErro == nil || modelo.funcaoComErro == rascunho.id ? modelo.erro?.detalhes : nil)
                }
                // Sem a lista carregada, o erro é da tela e o "tentar de novo" recarrega; com ela, o erro é do salvar e vai ao pé.
                if let erro = modelo.erro, !modelo.carregou {
                    EstadoErro(verbatim: MensagemDoErroAPI.texto(erro)) { Task { await modelo.carregar() } }
                }
            }
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.top, FrilaEspaco.bloco)
            .padding(.bottom, FrilaEspaco.grupo)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
            .frame(maxWidth: .infinity)
        }
        .font(FrilaTipo.corpo).foregroundStyle(FrilaCor.texto).background(FrilaCor.fundo)
        .navigationTitle(Text("Editar serviços", bundle: bundleApresentacao))
        .scrollDismissesKeyboard(.interactively).frilaKeyboardDismissScope()
        // O identificador da tela fica na rolagem, antes do rodapé: posto depois, ele cobria o do botão "Salvar alterações".
        .accessibilityIdentifier("tela-editar-servicos")
        .rodapeAncorado {
            if let erro = modelo.erro, modelo.carregou {
                MensagemJuntoAoBotao(verbatim: MensagemDoErroAPI.texto(erro))
            }
            // V18: o sucesso é uma mensagem junto ao botão, e não um texto cinza solto.
            if modelo.sucesso {
                MensagemJuntoAoBotao(verbatim: String(localized: "Serviços salvos", bundle: bundleApresentacao))
                    .accessibilityIdentifier("servicos-sucesso")
            }
            BotaoPrimario("Salvar alterações", carregando: modelo.salvando) {
                // V16: com o teclado aberto, o aviso de erro ficava escondido atrás dele.
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                Task { await modelo.salvar() }
            }
            .disabled(!modelo.carregou || modelo.carregando)
            .accessibilityIdentifier("salvar-servicos")
        }
        .disabled(modelo.salvando)
        .task { await modelo.carregar() }
        .onChange(of: modelo.rascunhos) { _, _ in modelo.limparSucesso() }
    }
}

private struct EditorDeServico: View {
    @Binding var rascunho: ServicoEmEdicao
    let especialidades: [Especialidade]
    let campoComErro: String?

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            Toggle(isOn: $rascunho.habilitado) { Text(verbatim: rascunho.funcao.nome).font(FrilaTipo.nome) }
                .frame(minHeight: FrilaMetrica.alvo)
            if rascunho.habilitado {
                if let dica = rascunho.funcao.dicaPerfil { Text(verbatim: dica).font(FrilaTipo.apoio).foregroundStyle(FrilaCor.textoSecundario) }
                Picker(selection: $rascunho.dados.unidade) {
                    ForEach(UnidadePreco.allCases, id: \.self) { Text(verbatim: TextosDosServicos.unidade($0)).tag($0) }
                } label: { Text("Unidade de preço", bundle: bundleApresentacao) }
                    .labelsHidden()
                    .accessibilityIdentifier("unidade-servico")
                    .seletorDeServico("Unidade de preço")
                    .onChange(of: rascunho.dados.unidade) { _, _ in rascunho.trocarUnidade() }
                if rascunho.dados.unidade == .aCombinar {
                    Text("A combinar: o total será confirmado na chamada.", bundle: bundleApresentacao).font(FrilaTipo.apoio)
                } else {
                    TextField(text: $rascunho.valor, prompt: Text("0,00", bundle: bundleApresentacao)) { Text("Valor em reais", bundle: bundleApresentacao) }.keyboardType(.decimalPad).accessibilityIdentifier("valor-servico").campoDeServico("Valor em reais")
                    if [.hora, .diaria, .pacote].contains(rascunho.dados.unidade) {
                        TextField(text: $rascunho.valorMaximo, prompt: Text("0,00", bundle: bundleApresentacao)) { Text("Valor máximo em reais (opcional)", bundle: bundleApresentacao) }.keyboardType(.decimalPad).campoDeServico("Valor máximo em reais (opcional)")
                    }
                    Text("De R$ 10 a R$ 10.000 por unidade.", bundle: bundleApresentacao).font(FrilaTipo.apoio).foregroundStyle(FrilaCor.textoSecundario)
                }
                if let resumo = TextosDosServicos.resumoDaDiaria(rascunho) { Text(verbatim: resumo).font(FrilaTipo.apoio).foregroundStyle(FrilaCor.textoSecundario) }
                camposDaUnidade
                Picker(selection: $rascunho.dados.levaMaterial) {
                    Text("Não informado", bundle: bundleApresentacao).tag(LevaMaterial?.none)
                    ForEach(LevaMaterial.allCases, id: \.self) { Text(verbatim: TextosDosServicos.material($0)).tag(Optional($0)) }
                } label: { Text("Leva material?", bundle: bundleApresentacao) }
                    .labelsHidden()
                    .accessibilityIdentifier("material-servico")
                    .seletorDeServico("Leva material?")
                TextField(text: $rascunho.dados.itensInclusos.valorOuVazio, prompt: Text(verbatim: ""), axis: .vertical) {
                    Text("O que está incluído (até 300 caracteres)", bundle: bundleApresentacao)
                }
                .accessibilityIdentifier("inclui-servico").campoDeServico("O que está incluído (até 300 caracteres)")
                if campoComErro == "inclui" { erroDoCampo("inclui") }
                ForEach(especialidades) { especialidade in
                    Toggle(isOn: selecionada(especialidade.id)) { Text(verbatim: especialidade.nome) }
                        .disabled(!(rascunho.dados.especialidadeIDs ?? []).contains(especialidade.id) && (rascunho.dados.especialidadeIDs?.count ?? 0) >= 8)
                        .frame(minHeight: FrilaMetrica.alvo)
                }
                if !especialidades.isEmpty { Text("Escolha até 8 especialidades.", bundle: bundleApresentacao).font(FrilaTipo.apoio).foregroundStyle(FrilaCor.textoSecundario) }
                if let campoComErro, campoComErro != "inclui" { erroDoCampo(campoComErro) }
            }
        }
        .cartaoFrila()
    }

    private func erroDoCampo(_ campo: String) -> some View {
        // Problema não tem cor: o texto vai em tinta e diz o que corrigir.
        Text(verbatim: TextosDosServicos.campo(campo)).font(FrilaTipo.corpo.weight(.semibold)).foregroundStyle(FrilaCor.texto)
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
    /// Campo de texto: rótulo visível acima, em rótulo de grupo, e a caixa do sistema (48 pt, fio em `bordaDoCampo`).
    func campoDeServico(_ titulo: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            // O campo já tem o mesmo rótulo para o leitor de tela: o texto visível não é lido duas vezes.
            Text(titulo, bundle: bundleApresentacao).font(FrilaTipo.rotuloDeGrupo).foregroundStyle(FrilaCor.textoSecundario).accessibilityHidden(true)
            self.textFieldStyle(.plain).font(FrilaTipo.corpo).foregroundStyle(FrilaCor.texto).caixaDoCampoFrila()
        }
    }

    /// Seletor em menu (controle nativo): o mesmo rótulo visível acima e o alvo de 48 pt.
    func seletorDeServico(_ titulo: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(titulo, bundle: bundleApresentacao).font(FrilaTipo.rotuloDeGrupo).foregroundStyle(FrilaCor.textoSecundario).accessibilityHidden(true)
            self.frame(minHeight: FrilaMetrica.alvo, alignment: .leading)
        }
    }
}
