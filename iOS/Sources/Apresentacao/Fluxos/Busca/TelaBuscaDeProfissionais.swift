// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
import FrilaDominio
import SwiftUI

/// Busca de profissionais (CD-B01 a CD-B11), só com controles nativos: filtros, lista, seleção de até 3,
/// chamar e "Publicar para todos". Atrás da chave `buscaProfissionais`.
public struct TelaBuscaDeProfissionais: View {
    /// Vem de fora: vive enquanto a busca existir (não só enquanto a folha está aberta), para um envio incerto
    /// continuar travado mesmo se a tela for fechada e aberta de novo.
    private let viewModel: BuscaDeProfissionaisViewModel
    @State private var funcoes: [Funcao] = []
    @State private var regioes: [RegiaoAdministrativa] = []
    @State private var casa: Estabelecimento?
    @State private var catalogoCarregado = false
    @State private var catalogoComErro = false
    @State private var usarHorario = false
    @State private var inicio: Date
    @State private var fim: Date
    @State private var rascunhoDaChamada: RascunhoDaChamadaDaBusca?
    @State private var bloqueiosLocais = BloqueiosDaSessao()
    @Environment(BloqueiosDaSessao.self) private var bloqueiosDaSessao: BloqueiosDaSessao?
    @Environment(\.dismiss) private var fechar

    private let api: any ApiCliente
    private let estabelecimentoID: UUID
    private let aoPublicarParaTodos: (RascunhoDeVagaDaBusca) -> Void
    private var bloqueios: BloqueiosDaSessao { bloqueiosDaSessao ?? bloqueiosLocais }

    public init(viewModel: BuscaDeProfissionaisViewModel, api: any ApiCliente, estabelecimentoID: UUID,
                aoPublicarParaTodos: @escaping (RascunhoDeVagaDaBusca) -> Void) {
        self.viewModel = viewModel
        let amanha = Date.now.addingTimeInterval(24 * 3600)
        _inicio = State(initialValue: amanha)
        _fim = State(initialValue: amanha.addingTimeInterval(4 * 3600))
        self.api = api
        self.estabelecimentoID = estabelecimentoID
        self.aoPublicarParaTodos = aoPublicarParaTodos
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        return Form {
            Section(TextosBuscaDeProfissionais.filtros) {
                Picker(selection: $viewModel.funcaoID) {
                    Text(verbatim: TextosBuscaDeProfissionais.escolhaOServico).tag(UUID?.none)
                    ForEach(funcoes) { funcao in Text(verbatim: funcao.nome).tag(UUID?.some(funcao.id)) }
                } label: { Text(verbatim: TextosBuscaDeProfissionais.servico) }
                    .accessibilityIdentifier("busca-servico")
                Picker(selection: $viewModel.regiaoID) {
                    Text(verbatim: TextosBuscaDeProfissionais.regiaoDoEstabelecimento).tag(Int?.none)
                    ForEach(regioes) { regiao in Text(verbatim: regiao.nome).tag(Int?.some(regiao.id)) }
                } label: { Text(verbatim: TextosBuscaDeProfissionais.regiao) }
                    .accessibilityIdentifier("busca-regiao")
                Toggle(isOn: $usarHorario) { Text(verbatim: TextosBuscaDeProfissionais.buscarPorHorario) }
                    .accessibilityIdentifier("busca-usar-horario")
                if usarHorario {
                    DatePicker(selection: $inicio, in: Date.now...) { Text(verbatim: TextosBuscaDeProfissionais.inicio) }
                        .accessibilityIdentifier("busca-inicio")
                    DatePicker(selection: $fim, in: inicio...) { Text(verbatim: TextosBuscaDeProfissionais.termino) }
                        .accessibilityIdentifier("busca-fim")
                }
                Button { Task { await buscar() } } label: { Text(verbatim: TextosBuscaDeProfissionais.buscar) }
                    .disabled(!viewModel.podeBuscar)
                    .accessibilityIdentifier("buscar-profissionais")
            }
            if catalogoComErro && !catalogoCarregado {
                Section {
                    Text(verbatim: TextosBuscaDeProfissionais.catalogoIndisponivel)
                        .accessibilityIdentifier("busca-catalogo-erro")
                    Button { Task { await carregarCatalogo() } } label: { Text(verbatim: TextosBuscaDeProfissionais.tentarDeNovo) }
                        .accessibilityIdentifier("busca-catalogo-tentar-de-novo")
                }
            }
            if viewModel.travadoPeloIncerto {
                // Um envio que levou o trabalho ficou incerto: nada de busca nova nem de trocar a seleção até resolver.
                Section {
                    Text(verbatim: TextosBuscaDeProfissionais.envioIncerto)
                        .accessibilityIdentifier("busca-envio-incerto")
                    Button { chamarSelecionados() } label: { Text(verbatim: TextosBuscaDeProfissionais.tentarDeNovo) }
                        .disabled(!podeChamarAgora)
                        .accessibilityIdentifier("busca-tentar-de-novo")
                }
            }
            situacao
            if let aviso = viewModel.avisoDeLimiteDeSelecao {
                Section { Text(verbatim: aviso).accessibilityIdentifier("busca-aviso-limite") }
            }
            if !viewModel.resultados.isEmpty { lista }
        }
        .navigationTitle(Text(verbatim: TextosBuscaDeProfissionais.titulo))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                // Fechar e arrastar ficam livres mesmo com envio incerto (ninguém fica preso offline): a guarda segura o
                // ViewModel, e reabrir mostra o pendente com "Tentar de novo", o mesmo trabalho e as mesmas chaves.
                Button { fechar() } label: { Text(verbatim: TextosBuscaDeProfissionais.fechar) }
                    .accessibilityIdentifier("busca-fechar")
            }
        }
        .task { await carregarCatalogo() }
        .sheet(item: $rascunhoDaChamada) { rascunho in folhaDeChamada(rascunho) }
        .alert(Text(verbatim: TextosChamadaDireta.j7Titulo), isPresented: $viewModel.mostrarJ7) {
            Button(role: .cancel) { viewModel.mostrarJ7 = false } label: { Text(verbatim: TextosBuscaDeProfissionais.fechar) }
            Button { Task { await reenviarComJ7() } } label: { Text(verbatim: TextosChamadaDireta.j7Confirmar) }
                .accessibilityIdentifier("busca-j7-confirmar")
        } message: { Text(verbatim: TextosChamadaDireta.j7Mensagem) }
    }

    // MARK: Estados

    @ViewBuilder
    private var situacao: some View {
        switch viewModel.estado {
        case .ocioso, .resultados:
            EmptyView()
        case .carregando:
            Section { ProgressView { Text(verbatim: TextosBuscaDeProfissionais.buscando) } }
        case .vazio:
            Section {
                Text(verbatim: TextosBuscaDeProfissionais.nenhumEncontrado)
                    .accessibilityIdentifier("busca-vazia")
                if let rascunho = viewModel.rascunhoParaPublicarParaTodos {
                    Button { aoPublicarParaTodos(rascunho) } label: { Text(verbatim: TextosChamadaDireta.publicarParaTodos) }
                        .accessibilityIdentifier("publicar-para-todos-busca")
                }
            }
        case .indisponivel:
            Section { Text(verbatim: TextosBuscaDeProfissionais.indisponivel).accessibilityIdentifier("busca-indisponivel") }
        case let .erro(mensagem):
            Section {
                Text(verbatim: mensagem).accessibilityIdentifier("busca-erro")
                Button { Task { await buscar() } } label: { Text(verbatim: TextosBuscaDeProfissionais.tentarDeNovo) }
                    .disabled(!viewModel.podeBuscar)
            }
        }
    }

    // MARK: Lista

    private var lista: some View {
        Section {
            Button { chamarSelecionados() } label: { Text(verbatim: TextosBuscaDeProfissionais.chamarSelecionados) }
                .disabled(!podeChamarAgora)
                .accessibilityIdentifier("chamar-selecionados")
            ForEach(viewModel.resultados) { cartao in linha(cartao) }
            if viewModel.temMais {
                Color.clear.frame(height: 1)
                    .onAppear { Task { await viewModel.carregarMais() } }
                    .accessibilityHidden(true)
            }
            if viewModel.carregandoMais { ProgressView() }
            if let erro = viewModel.erroAoCarregarMais {
                Text(verbatim: erro)
                Button { Task { await viewModel.carregarMais() } } label: { Text(verbatim: TextosBuscaDeProfissionais.carregarMais) }
            }
        } header: {
            Text(verbatim: TextosBuscaDeProfissionais.profissionais)
        } footer: {
            Text(verbatim: TextosBuscaDeProfissionais.selecionados(viewModel.selecionados.count))
        }
    }

    private func linha(_ cartao: CartaoProfissional) -> some View {
        let selecionado = viewModel.estaSelecionado(cartao.id)
        return HStack {
            Button { viewModel.alternarSelecao(cartao.id) } label: {
                Image(systemName: selecionado ? "checkmark.circle.fill" : "circle")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.travadoPeloIncerto)
            .accessibilityLabel(Text(verbatim: selecionado ? TextosBuscaDeProfissionais.desmarcar(cartao.nome)
                                                             : TextosBuscaDeProfissionais.selecionar(cartao.nome)))
            .accessibilityIdentifier("selecionar-profissional-\(cartao.id)")
            NavigationLink {
                TelaPerfilPublico(perfil: Self.perfilResumido(cartao), api: api, bloqueios: bloqueios)
                    .navigationTitle(Text(verbatim: cartao.nome))
            } label: {
                VStack(alignment: .leading) {
                    Text(verbatim: cartao.nome)
                    Text(verbatim: TextosDosServicos.resumoDoServico(cartao.servico.servico) ?? cartao.servico.funcao.nome)
                    Text(verbatim: cartao.distanciaFaixa.rotulo)
                    if cartao.disponivelNoHorario == true {
                        Text(verbatim: TextosBuscaDeProfissionais.disponivelNesseHorario)
                            .accessibilityIdentifier("disponivel-\(cartao.id)")
                    }
                    if let resultado = viewModel.resultadosDaChamada[cartao.id] {
                        Text(verbatim: Self.texto(resultado))
                            .accessibilityIdentifier("resultado-chamada-\(cartao.id)")
                    }
                }
            }
            .accessibilityIdentifier("perfil-profissional-\(cartao.id)")
        }
    }

    /// Só o necessário para abrir o perfil; a tela do perfil lê o resto pelo id.
    private static func perfilResumido(_ cartao: CartaoProfissional) -> PerfilPublico {
        PerfilPublico(id: cartao.id, tipo: .profissional, nome: cartao.nome, funcoes: [cartao.servico.funcao.nome],
                      reputacao: cartao.reputacao)
    }

    private static func texto(_ resultado: ResultadoDaChamadaDaBusca) -> String {
        switch resultado {
        case .enviada: TextosBuscaDeProfissionais.resultadoEnviada
        case .pedeConfirmacaoDeRecorrencia: TextosBuscaDeProfissionais.resultadoPedeConfirmacao
        case let .erro(mensagem): mensagem
        case .naoEnviada: TextosBuscaDeProfissionais.resultadoNaoEnviada
        }
    }

    // MARK: Ações

    private func carregarCatalogo() async {
        guard !catalogoCarregado else { return }
        let api = api
        let id = estabelecimentoID
        catalogoComErro = false
        guard let dados = try? await PrazoDaAbertura.esperar(.seconds(15), {
            (try await api.funcoes(), try await api.regioesAdministrativas(), try await api.meuEstabelecimento(id: id))
        }) else {
            // Sem o catálogo o Buscar não liga: mostra o erro e deixa tentar de novo.
            catalogoComErro = true
            return
        }
        funcoes = dados.0
        regioes = dados.1.filter { $0.ativo != false }
        casa = dados.2
        if viewModel.funcaoID == nil { viewModel.funcaoID = funcoes.first?.id }
        catalogoCarregado = true
    }

    private func buscar() async {
        viewModel.horario = usarHorario ? try? Periodo(inicio: inicio, fim: fim) : nil
        await viewModel.buscar()
    }

    /// Pode chamar agora: com envio registrado o reenvio não precisa da casa nem da folha.
    private var podeChamarAgora: Bool {
        viewModel.podeChamar && (viewModel.temEnvioRegistrado || casa != nil)
    }

    /// 1º envio: abre a folha. Depois dele (pendente ou feito), reenvia o MESMO trabalho direto, sem folha nova:
    /// uma folha nova traria outro horário (agora + 24 h) e o servidor abriria uma 2ª vaga para quem ainda não foi chamado.
    private func chamarSelecionados() {
        if viewModel.temEnvioRegistrado {
            Task { await viewModel.reenviar() }
        } else {
            abrirChamada()
        }
    }

    private func abrirChamada() {
        guard let casa else { return }
        rascunhoDaChamada = RascunhoDaChamadaDaBusca(horario: usarHorario ? try? Periodo(inicio: inicio, fim: fim) : nil,
                                                      responsavel: casa.nome)
    }

    private func enviarChamadas() async {
        guard let rascunho = rascunhoDaChamada, let casa, let funcaoID = viewModel.funcaoID,
              let trabalho = rascunho.trabalho(casa: casa, funcaoID: funcaoID) else { return }
        rascunhoDaChamada = nil
        await viewModel.chamar(trabalho: trabalho, recado: rascunho.recadoOuNada)
    }

    private func reenviarComJ7() async {
        await viewModel.reenviar(confirmoRecorrencia: true)
    }

    // MARK: Folha de chamada

    private func folhaDeChamada(_ rascunhoAtual: RascunhoDaChamadaDaBusca) -> some View {
        @Bindable var rascunho = rascunhoAtual
        return NavigationStack {
            Form {
                Section { Text(verbatim: TextosBuscaDeProfissionais.folhaExplicacao) }
                Section {
                    TextField(text: $rascunho.valorTexto) { Text(verbatim: TextosChamadaDireta.valor) }
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("busca-valor-total")
                    Toggle(isOn: $rascunho.totalConfirmado) { Text(verbatim: TextosChamadaDireta.total) }
                        .accessibilityIdentifier("busca-confirmo-total")
                    DatePicker(selection: $rascunho.inicio) { Text(verbatim: TextosBuscaDeProfissionais.inicio) }
                    DatePicker(selection: $rascunho.fim) { Text(verbatim: TextosBuscaDeProfissionais.termino) }
                    TextField(text: $rascunho.responsavel) { Text(verbatim: TextosChamadaDireta.responsavel) }
                        .accessibilityIdentifier("busca-responsavel")
                    TextField(text: $rascunho.recado, axis: .vertical) { Text(verbatim: TextosChamadaDireta.recado) }
                }
                Section {
                    if let falta = rascunho.oQueFalta { Text(verbatim: falta) }
                    Button { Task { await enviarChamadas() } } label: { Text(verbatim: TextosBuscaDeProfissionais.enviarChamadas) }
                        .disabled(!rascunho.podeEnviar)
                        .accessibilityIdentifier("busca-enviar-chamadas")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text(verbatim: TextosBuscaDeProfissionais.folhaTitulo))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { rascunhoDaChamada = nil } label: { Text(verbatim: TextosBuscaDeProfissionais.fechar) }
                }
            }
        }
    }
}
