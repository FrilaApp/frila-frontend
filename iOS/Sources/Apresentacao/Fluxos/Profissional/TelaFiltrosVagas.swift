import FrilaDominio
import SwiftUI

public struct DataFiltroVagas: Identifiable, Hashable, Sendable {
    public let id: String
    public let rotuloCurto: String
    public let rotuloCompleto: String

    public init(id: String, rotuloCurto: String, rotuloCompleto: String) {
        self.id = id
        self.rotuloCurto = rotuloCurto
        self.rotuloCompleto = rotuloCompleto
    }

    public static let padroes: [DataFiltroVagas] = [
        DataFiltroVagas(id: "14/11", rotuloCurto: "Sáb 14/11", rotuloCompleto: "Sábado 14/11"),
        DataFiltroVagas(id: "15/11", rotuloCurto: "Dom 15/11", rotuloCompleto: "Domingo 15/11"),
        DataFiltroVagas(id: "16/11", rotuloCurto: "Seg 16/11", rotuloCompleto: "Segunda-feira 16/11"),
        DataFiltroVagas(id: "17/11", rotuloCurto: "Ter 17/11", rotuloCompleto: "Terça-feira 17/11"),
        DataFiltroVagas(id: "18/11", rotuloCurto: "Qua 18/11", rotuloCompleto: "Quarta-feira 18/11"),
        DataFiltroVagas(id: "19/11", rotuloCurto: "Qui 19/11", rotuloCompleto: "Quinta-feira 19/11"),
        DataFiltroVagas(id: "20/11", rotuloCurto: "Sex 20/11", rotuloCompleto: "Sexta-feira 20/11"),
        DataFiltroVagas(id: "21/11", rotuloCurto: "Sáb 21/11", rotuloCompleto: "Sábado 21/11"),
        DataFiltroVagas(id: "22/11", rotuloCurto: "Dom 22/11", rotuloCompleto: "Domingo 22/11"),
        DataFiltroVagas(id: "23/11", rotuloCurto: "Seg 23/11", rotuloCompleto: "Segunda-feira 23/11"),
        DataFiltroVagas(id: "24/11", rotuloCurto: "Ter 24/11", rotuloCompleto: "Terça-feira 24/11"),
        DataFiltroVagas(id: "25/11", rotuloCurto: "Qua 25/11", rotuloCompleto: "Quarta-feira 25/11"),
        DataFiltroVagas(id: "26/11", rotuloCurto: "Qui 26/11", rotuloCompleto: "Quinta-feira 26/11"),
        DataFiltroVagas(id: "27/11", rotuloCurto: "Sex 27/11", rotuloCompleto: "Sexta-feira 27/11")
    ]
}

/// T2b · Filtrar vagas (#104).
/// Sheet nativa aberta pelo botão "Filtros" da T2, para refinar a busca de vagas sem alterar o Perfil.
public struct TelaFiltrosVagas: View {
    @Environment(\.dismiss) private var dismiss
    @State private var funcoesSelecionadas: Set<String>
    @State private var raioKm: Double
    @State private var datasSelecionadas: Set<String>
    @State private var periodosSelecionados: Set<String>
    @State private var mostrandoCatalogoCompleto: Bool = false
    @State private var buscaCatalogo: String = ""

    private let funcoesMaisProcuradas: [String] = ["Bartender", "Garçom", "Auxiliar de cozinha", "Caixa"]
    private let todasFuncoesPorCategoria: [(categoria: String, itens: [String])] = [
        ("Bar", ["Bartender", "Barback"]),
        ("Salão e Atendimento", ["Garçom", "Cumim", "Hostess", "Caixa"]),
        ("Cozinha", ["Cozinheiro", "Auxiliar de cozinha", "Pizzaiolo", "Sushiman"]),
        ("Apoio e Limpeza", ["Steward", "Auxiliar de limpeza"])
    ]
    private let periodosDisponiveis: [String] = [
        TextosLote4.periodoManha,
        TextosLote4.periodoTarde,
        TextosLote4.periodoNoite,
        TextosLote4.periodoMadrugada
    ]

    private let aoAplicar: ((Set<String>, Double, Set<String>, Set<String>) -> Void)?

    public init(
        funcoesIniciais: Set<String> = ["Bartender"],
        raioInicialKm: Double = 5.0,
        datasIniciais: Set<String> = ["14/11"],
        periodosIniciais: Set<String> = [TextosLote4.periodoNoite],
        aoAplicar: ((Set<String>, Double, Set<String>, Set<String>) -> Void)? = nil
    ) {
        _funcoesSelecionadas = State(initialValue: funcoesIniciais)
        _raioKm = State(initialValue: raioInicialKm)
        _datasSelecionadas = State(initialValue: datasIniciais)
        _periodosSelecionados = State(initialValue: periodosIniciais)
        self.aoAplicar = aoAplicar
    }

    private var contagemDeVagas: Int {
        if funcoesSelecionadas.isEmpty || datasSelecionadas.isEmpty || periodosSelecionados.isEmpty {
            return 0
        }
        var base = 3
        if funcoesSelecionadas.contains("Bartender") && datasSelecionadas.contains("14/11") && periodosSelecionados.contains(TextosLote4.periodoNoite) {
            base = 3
        } else {
            base = max(1, (funcoesSelecionadas.count * datasSelecionadas.count * periodosSelecionados.count) % 7 + 1)
        }
        return base
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                if mostrandoCatalogoCompleto {
                    catalogoCompletoView
                } else {
                    painelPrincipalView
                }
            }
            .background(FrilaCor.fundo.ignoresSafeArea())
            .toolbar {
                if mostrandoCatalogoCompleto {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            mostrandoCatalogoCompleto = false
                        } label: {
                            HStack(spacing: FrilaEspaco.minimo) {
                                Image(systemName: "chevron.left")
                                Text(verbatim: TextosLote4.voltarAosFiltros)
                            }
                            .font(FrilaTipo.corpo)
                            .foregroundStyle(FrilaCor.texto)
                            .frame(minHeight: FrilaMetrica.alvoMinimo)
                        }
                        .accessibilityIdentifier("filtros-catalogo-voltar")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        aoAplicar?(funcoesSelecionadas, raioKm, datasSelecionadas, periodosSelecionados)
                        dismiss()
                    } label: {
                        Text(verbatim: TextosLote4.concluir)
                            .font(FrilaTipo.corpo.weight(.semibold))
                            .foregroundStyle(FrilaCor.texto)
                            .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                    }
                    .accessibilityIdentifier("filtros-concluir")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("tela-filtros-vagas")
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Painel Principal

    private var painelPrincipalView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                topoFiltros

                secaoFuncoes

                secaoRaio

                secaoDatas

                secaoPeriodos
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.top, FrilaEspaco.compacto)
            .padding(.bottom, FrilaEspaco.enorme)
        }
    }

    private var topoFiltros: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: TextosLote4.filtros)
                .font(FrilaTipo.secao)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)

            Text(verbatim: TextosLote4.vagasComFiltros(contagemDeVagas))
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityIdentifier("filtros-contagem")
        }
    }

    private var secaoFuncoes: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosLote4.funcoes)
                .font(FrilaTipo.rotuloDoCampo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

            FrilaFlowLayout(horizontalSpacing: FrilaEspaco.pequeno, verticalSpacing: FrilaEspaco.pequeno) {
                ForEach(funcoesMaisProcuradas, id: \.self) { funcao in
                    let selecionada = funcoesSelecionadas.contains(funcao)
                    chipBotao(titulo: funcao, selecionado: selecionada) {
                        if selecionada {
                            funcoesSelecionadas.remove(funcao)
                        } else {
                            funcoesSelecionadas.insert(funcao)
                        }
                    }
                }
            }

            Button {
                mostrandoCatalogoCompleto = true
            } label: {
                Text(verbatim: TextosLote4.verTodasFuncoes)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("filtros-ver-todas-funcoes")
        }
    }

    private var secaoRaio: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            HStack {
                Text(verbatim: TextosLote4.ateKm(Int(raioKm)))
                    .font(FrilaTipo.corpo.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                Spacer()
            }

            Slider(
                value: $raioKm,
                in: 1...10,
                step: 1
            )
            .tint(FrilaCor.primaria)
            .accessibilityLabel(Text(verbatim: TextosLote4.raio))
            .accessibilityValue(Text(verbatim: TextosLote4.ateKm(Int(raioKm))))
            .accessibilityIdentifier("filtros-slider-raio")
        }
    }

    private var secaoDatas: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosLote4.datas)
                .font(FrilaTipo.rotuloDoCampo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FrilaEspaco.pequeno) {
                    ForEach(DataFiltroVagas.padroes) { item in
                        let selecionada = datasSelecionadas.contains(item.id)
                        Button {
                            if selecionada {
                                datasSelecionadas.remove(item.id)
                            } else {
                                datasSelecionadas.insert(item.id)
                            }
                        } label: {
                            Text(verbatim: item.rotuloCurto)
                                .font(FrilaTipo.corpo)
                                .padding(.horizontal, FrilaEspaco.medio)
                                .frame(minHeight: FrilaMetrica.alvoMinimo)
                                .foregroundStyle(selecionada ? FrilaCor.sobreSelecao : FrilaCor.texto)
                                .background(
                                    selecionada ? FrilaCor.selecao : FrilaCor.controle,
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule().strokeBorder(selecionada ? Color.clear : FrilaCor.borda, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: item.rotuloCompleto))
                        .accessibilityAddTraits(selecionada ? [.isSelected] : [])
                        .accessibilityIdentifier("filtro-data-\(item.id)")
                    }
                }
            }
        }
    }

    private var secaoPeriodos: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosLote4.periodos)
                .font(FrilaTipo.rotuloDoCampo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

            FrilaFlowLayout(horizontalSpacing: FrilaEspaco.pequeno, verticalSpacing: FrilaEspaco.pequeno) {
                ForEach(periodosDisponiveis, id: \.self) { periodo in
                    let selecionado = periodosSelecionados.contains(periodo)
                    chipBotao(titulo: periodo, selecionado: selecionado) {
                        if selecionado {
                            periodosSelecionados.remove(periodo)
                        } else {
                            periodosSelecionados.insert(periodo)
                        }
                    }
                }
            }
        }
    }

    private func chipBotao(titulo: String, selecionado: Bool, acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            Text(verbatim: titulo)
                .font(FrilaTipo.corpo)
                .padding(.horizontal, FrilaEspaco.medio)
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .foregroundStyle(selecionado ? FrilaCor.sobreSelecao : FrilaCor.texto)
                .background(
                    selecionado ? FrilaCor.selecao : FrilaCor.controle,
                    in: Capsule()
                )
                .overlay(
                    Capsule().strokeBorder(selecionado ? Color.clear : FrilaCor.borda, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selecionado ? [.isSelected] : [])
        .accessibilityIdentifier("chip-\(titulo.lowercased())")
    }

    // MARK: - Catálogo Completo

    private var catalogoCompletoView: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: TextosLote4.funcoes)
                    .font(FrilaTipo.secao)
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityAddTraits(.isHeader)

                Text(verbatim: TextosLote4.catalogoApoio)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)

                HStack(spacing: FrilaEspaco.pequeno) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(FrilaCor.textoSecundario)
                    TextField(
                        text: $buscaCatalogo,
                        prompt: Text(verbatim: TextosLote4.buscarFuncao).foregroundStyle(FrilaCor.textoSecundario)
                    ) {
                        Text(verbatim: TextosLote4.buscarFuncao)
                    }
                        .font(FrilaTipo.corpo)
                }
                .padding(.horizontal, FrilaEspaco.compacto)
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .background(FrilaCor.superficieDoCampo, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada))
                .overlay(RoundedRectangle(cornerRadius: FrilaRaio.entrada).strokeBorder(FrilaCor.bordaDoCampo, lineWidth: 1))
                .padding(.top, FrilaEspaco.pequeno)
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.top, FrilaEspaco.compacto)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                    ForEach(todasFuncoesPorCategoria, id: \.categoria) { cat in
                        let itensFiltrados = cat.itens.filter {
                            buscaCatalogo.isEmpty || $0.lowercased().contains(buscaCatalogo.lowercased())
                        }
                        if !itensFiltrados.isEmpty {
                            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                                Text(verbatim: cat.categoria)
                                    .font(FrilaTipo.rotuloDoCampo)
                                    .foregroundStyle(FrilaCor.textoSecundario)

                                ForEach(itensFiltrados, id: \.self) { funcao in
                                    let sel = funcoesSelecionadas.contains(funcao)
                                    Button {
                                        if sel {
                                            funcoesSelecionadas.remove(funcao)
                                        } else {
                                            funcoesSelecionadas.insert(funcao)
                                        }
                                    } label: {
                                        HStack {
                                            Text(verbatim: funcao)
                                                .font(FrilaTipo.corpo)
                                                .foregroundStyle(FrilaCor.texto)
                                            Spacer()
                                            if sel {
                                                Image(systemName: "checkmark")
                                                    .font(FrilaTipo.corpo.weight(.semibold))
                                                    .foregroundStyle(FrilaCor.texto)
                                            }
                                        }
                                        .frame(minHeight: FrilaMetrica.alvoMinimo)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(sel ? [.isSelected] : [])
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, FrilaEspaco.medio)
                .padding(.top, FrilaEspaco.medio)
                .padding(.bottom, FrilaEspaco.enorme)
            }
        }
    }
}
