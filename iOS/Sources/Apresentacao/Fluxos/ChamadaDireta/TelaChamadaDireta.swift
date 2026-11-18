import FrilaDominio
import SwiftUI

struct BotaoChamarDeNovo: View {
    let api: any ApiCliente
    let profissionalID: UUID
    let estabelecimentoID: UUID
    var vagaAnterior: VagaResumo?
    @State private var aberto = false
    @Environment(BloqueiosDaSessao.self) private var bloqueiosDaSessao: BloqueiosDaSessao?
    @State private var bloqueiosLocais = BloqueiosDaSessao()
    private var bloqueios: BloqueiosDaSessao { bloqueiosDaSessao ?? bloqueiosLocais }

    var body: some View {
        if !bloqueios.contem(id: profissionalID) {
            BotaoSecundario(verbatim: TextosChamadaDireta.titulo) { aberto = true }
                .accessibilityIdentifier("chamar-de-novo-\(profissionalID)")
                .sheet(isPresented: $aberto) {
                    NavigationStack {
                        TelaChamadaDireta(viewModel: ChamadaDiretaViewModel(api: api, profissionalID: profissionalID,
                            estabelecimentoID: estabelecimentoID, vagaAnterior: vagaAnterior), api: api)
                    }
                    .presentationCornerRadius(FrilaRaio.folha)
                }
        }
    }
}

/// A folha "Chamar profissional": os termos da chamada (função, horário, responsável, valor total e inclusos) e o envio.
/// Desenho (R6): rótulo visível acima de cada campo, o aviso de "preenchido com a última vaga" no topo e, ancorados
/// embaixo, o que falta e o botão laranja "Enviar chamada" (o único da folha). O resumo da chamada enviada vem no lugar
/// do formulário.
public struct TelaChamadaDireta: View {
    private enum Campo: Hashable { case responsavel, recado }

    @State private var viewModel: ChamadaDiretaViewModel
    @FocusState private var campoEmFoco: Campo?
    @Environment(\.dismiss) private var fechar
    /// Leva ao Acompanhar chamadas depois do envio (V11); sem ela, o resumo aparece sem o link.
    private let api: (any ApiCliente)?

    public init(viewModel: ChamadaDiretaViewModel, api: (any ApiCliente)? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.api = api
    }

    /// O formulário está na tela: o recurso está ligado e a chamada ainda não saiu.
    private var formularioVisivel: Bool { viewModel.resultado == nil && viewModel.recursoHabilitado }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                if viewModel.carregando { EstadoCarregando() }
                if let chamada = viewModel.resultado {
                    ResumoDaChamadaEnviada(chamada: chamada, valorCentavos: viewModel.valorCentavos,
                                           inicio: viewModel.inicio, fim: viewModel.fim,
                                           responsavel: viewModel.responsavel, api: api)
                } else if viewModel.recursoHabilitado {
                    campos
                        .disabled(viewModel.tentativa != nil || viewModel.enviando)
                }
                // Sem o formulário na tela, não há botão de envio para levar a mensagem: ela vem em aviso de bloco.
                if let erro = viewModel.erro, !formularioVisivel {
                    VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                        AvisoFrila(verbatim: erro, tom: .erro)
                        if !viewModel.recursoHabilitado {
                            BotaoSecundario("Tentar novamente") { Task { await viewModel.carregar() } }
                        }
                    }
                }
            }
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.top, FrilaEspaco.item)
            .padding(.bottom, FrilaEspaco.grupo)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(FrilaCor.fundo)
        // V12: "Chamar de novo" fica no botão de quem já trabalhou com a casa; a folha diz o que faz.
        .navigationTitle(Text(verbatim: TextosChamadaDireta.tituloDaFolha))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { fechar() } label: { Text("Fechar", bundle: bundleApresentacao) }
            }
        }
        .rodapeAncoradoSe(formularioVisivel) { rodape }
        .alert(Text(verbatim: TextosChamadaDireta.j7Titulo), isPresented: $viewModel.mostrarJ7) {
            Button(role: .cancel) { viewModel.mostrarJ7 = false } label: { Text("Cancelar", bundle: bundleApresentacao) }
            Button {
                Task { await viewModel.enviar(confirmoRecorrencia: true) }
            } label: { Text(verbatim: TextosChamadaDireta.j7Confirmar) }
        } message: { Text(verbatim: TextosChamadaDireta.j7Mensagem) }
        .interactiveDismissDisabled(viewModel.enviando)
        .task { await viewModel.carregar() }
    }

    /// O que o toque em "Enviar chamada" faz e o que falta para ele valer ficam logo acima do botão.
    @ViewBuilder
    private var rodape: some View {
        // O erro da ação fica logo acima do botão que a disparou (D-DS-13).
        if let erro = viewModel.erro {
            MensagemJuntoAoBotao(verbatim: erro)
        }
        if let falta = viewModel.oQueFalta {
            Text(verbatim: falta)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true) // já é a dica do botão no VoiceOver
                .accessibilityIdentifier("chamada-o-que-falta")
        }
        BotaoPrimario(verbatim: TextosChamadaDireta.enviar, carregando: viewModel.enviando) {
            Task { await viewModel.enviar() }
        }
        .disabled(!viewModel.podeEnviar)
        .accessibilityIdentifier("enviar-chamada")
        .accessibilityHint(viewModel.oQueFalta.map { Text(verbatim: $0) } ?? Text(verbatim: ""))
    }

    private var campos: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
            if viewModel.preenchidoPelaVagaAnterior {
                Text(verbatim: TextosChamadaDireta.preenchidoComUltimaVaga)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("aviso-preenchido-vaga-anterior")
            }
            campoDeEscolha(Text("Função", bundle: bundleApresentacao)) {
                Picker(selection: $viewModel.funcaoID) {
                    ForEach(viewModel.funcoes) { funcao in
                        Text(verbatim: funcao.nome).tag(Optional(funcao.id))
                    }
                } label: { Text("Função", bundle: bundleApresentacao) }
            }
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                rotulo(Text("Local", bundle: bundleApresentacao))
                Text(verbatim: viewModel.local)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            // V10: o seletor não oferece horário que já passou nem a menos de 2 h.
            FrilaGrupoDeLinhas(linhasComIcone: false) {
                DatePicker(selection: $viewModel.inicio, in: viewModel.inicioMinimo...) {
                    Text("Início", bundle: bundleApresentacao).font(FrilaTipo.corpo)
                }
                .accessibilityIdentifier("inicio-chamada")
                .modifier(LinhaDeControleDaCasa())
                DatePicker(selection: $viewModel.fim, in: viewModel.faixaDoTermino) {
                    Text("Término", bundle: bundleApresentacao).font(FrilaTipo.corpo)
                }
                .accessibilityIdentifier("termino-chamada")
                .modifier(LinhaDeControleDaCasa())
            }
            // V9: o rótulo vai acima, visível; o leitor de tela lê o rótulo no próprio campo.
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                rotulo(Text(verbatim: TextosChamadaDireta.responsavel))
                CampoFrila(verbatim: TextosChamadaDireta.responsavel, texto: $viewModel.responsavel,
                           emFoco: campoEmFoco == .responsavel)
                    .focused($campoEmFoco, equals: .responsavel)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("responsavel-chamada")
            }
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                rotulo(Text(verbatim: TextosChamadaDireta.valor))
                HStack(spacing: FrilaEspaco.item) {
                    Text(verbatim: TextosChamadaDireta.moeda)
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.texto)
                        .accessibilityHidden(true)
                    CampoMascara(texto: $viewModel.valorTexto, placeholder: TextosChamadaDireta.valorExemplo,
                                 rotuloAcessibilidade: TextosChamadaDireta.valor,
                                 identificadorAcessibilidade: "total-chamada-centavos", teclado: .decimalPad) { novo, anterior in
                        ChamadaDiretaViewModel.valorDigitado(novo, anterior: anterior)
                    }
                }
                .caixaDoCampoFrila()
            }
            FrilaGrupoDeLinhas(linhasComIcone: false) {
                Toggle(isOn: $viewModel.totalConfirmado) {
                    Text(verbatim: TextosChamadaDireta.total).font(FrilaTipo.corpo)
                }
                .accessibilityIdentifier("confirmar-total-chamada")
                .modifier(LinhaDeControleDaCasa())
            }
            FrilaGrupoDeLinhas(verbatim: TextosChamadaDireta.inclusosSecao, linhasComIcone: false) {
                Toggle(isOn: $viewModel.refeicao) { Text("Inclui refeição", bundle: bundleApresentacao).font(FrilaTipo.corpo) }
                    .modifier(LinhaDeControleDaCasa())
                Toggle(isOn: $viewModel.transporte) { Text("Inclui transporte", bundle: bundleApresentacao).font(FrilaTipo.corpo) }
                    .modifier(LinhaDeControleDaCasa())
                Toggle(isOn: $viewModel.materialProprio) { Text("Exige material próprio", bundle: bundleApresentacao).font(FrilaTipo.corpo) }
                    .modifier(LinhaDeControleDaCasa())
            }
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                rotulo(Text(verbatim: TextosChamadaDireta.recado))
                TextField(text: $viewModel.recado, axis: .vertical) { Text(verbatim: TextosChamadaDireta.recado) }
                    .textFieldStyle(.plain)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .lineLimit(3...6)
                    .focused($campoEmFoco, equals: .recado)
                    .caixaDoCampoFrila(emFoco: campoEmFoco == .recado)
                if viewModel.recado.count > 300 {
                    Text(verbatim: TextosChamadaDireta.recadoLongo)
                        .font(FrilaTipo.apoio)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// O rótulo visível acima do campo, em rótulo de grupo. O campo já se anuncia pelo próprio nome.
    private func rotulo(_ texto: Text) -> some View {
        texto
            .font(FrilaTipo.rotuloDeGrupo)
            .foregroundStyle(FrilaCor.textoSecundario)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityHidden(true)
    }

    /// Escolha única por menu, na caixa do campo (a lista de funções é curta; o menu é o do sistema).
    private func campoDeEscolha<Conteudo: View>(_ nome: Text, @ViewBuilder _ conteudo: () -> Conteudo) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            rotulo(nome)
            conteudo()
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(FrilaCor.texto)
                .frame(maxWidth: .infinity, alignment: .leading)
                .caixaDoCampoFrila()
        }
    }
}
