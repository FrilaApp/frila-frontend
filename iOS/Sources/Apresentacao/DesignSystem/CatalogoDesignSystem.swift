// O catálogo é ferramenta de desenvolvimento: fica fora do Release (#96).
#if DEBUG
import FrilaDominio
import SwiftUI

public struct CatalogoDesignSystem: View {
    private let api: (any ApiCliente)?
    private let permitirSimulacaoDeConflito: Bool
    @State private var texto = ""
    @State private var codigo = ""
    @State private var filtro = true
    @State private var resposta: Bool?
    @State private var exibirFolha = ProcessInfo.processInfo.arguments.contains("-FRILA_ABRIR_FOLHA_DEMO")
    @State private var chipDoEstudio = true
    // Amostras do catálogo (ferramenta de desenvolvimento): texto fixo, fora do xcstrings, como as demais.
    private let amostraPergunta = "Qual é a vaga?"
    private let amostraResposta = "Garçom"
    private let amostraContexto = "Salão"
    private let amostraSecao = "Título de seção"
    private let amostraCorpo = "Corpo em SF Pro, 17 pt, com Dynamic Type."
    private let amostraMeta = "Meta e apoio, 15 pt."
    private let amostraMicro = "O que está incluso"
    @Environment(\.colorScheme) private var colorScheme
    private let tituloCatalogo = "Frila UI"
    private let textoForcarFalha = "Forçar falha"
    private let textoAbrirFolha = "Abrir folha de exemplo"
    private let tituloFolha = "Folha com elevação"
    private let corpoFolha = "Elevação em 3 camadas coordenadas (rim, key, ambient)."
    private let subtituloTatil = "Comparação: normal vs pressionado"
    private let rotuloNormal = "Normal"
    private let rotuloPressionadoBotao = "Pressionado (0.96)"
    private let rotuloPressionadoChip = "Pressionado (0.94)"
    private let textoExemploBotao = "Exemplo"
    private let textoExemploChip = "Opção"

    private var esquemaDeCor: ColorScheme? {
        if ProcessInfo.processInfo.arguments.contains("-FRILA_MODO_ESCURO") {
            return .dark
        } else if ProcessInfo.processInfo.arguments.contains("-FRILA_MODO_CLARO") {
            return .light
        }
        return nil
    }

    public init(api: (any ApiCliente)? = nil, permitirSimulacaoDeConflito: Bool = false) {
        self.api = api
        self.permitirSimulacaoDeConflito = permitirSimulacaoDeConflito
    }

    public var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                        secao("Paleta") { paleta }
                        secao("Tipografia") { tipografia }
                        secao("Botões") { BotaoPrimario("Continuar") {}; BotaoSecundario("Voltar") {} }
                        secao("Botões do Estúdio") { botoesDoEstudio }
                        secao("Chips do Estúdio") { chipsDoEstudio }
                        secao("Toque tátil") {
                            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                                Text(verbatim: subtituloTatil)
                                    .font(FrilaTipo.nota)
                                    .foregroundStyle(FrilaCor.textoSecundario)
                                HStack(spacing: FrilaEspaco.medio) {
                                    VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                                        Text(verbatim: rotuloNormal)
                                            .font(FrilaTipo.nota)
                                            .foregroundStyle(FrilaCor.textoSecundario)
                                        BotaoPrimario(verbatim: textoExemploBotao) {}
                                    }
                                    VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                                        Text(verbatim: rotuloPressionadoBotao)
                                            .font(FrilaTipo.nota)
                                            .foregroundStyle(FrilaCor.textoSecundario)
                                        BotaoPrimario(verbatim: textoExemploBotao) {}
                                            .scaleEffect(FrilaMovimento.pressScaleBotao)
                                            .opacity(0.92)
                                    }
                                }
                                HStack(spacing: FrilaEspaco.medio) {
                                    VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                                        Text(verbatim: rotuloNormal)
                                            .font(FrilaTipo.nota)
                                            .foregroundStyle(FrilaCor.textoSecundario)
                                        FiltroPill(verbatim: textoExemploChip, selecionado: true) {}
                                    }
                                    VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                                        Text(verbatim: rotuloPressionadoChip)
                                            .font(FrilaTipo.nota)
                                            .foregroundStyle(FrilaCor.textoSecundario)
                                        FiltroPill(verbatim: textoExemploChip, selecionado: true) {}
                                            .scaleEffect(FrilaMovimento.pressScaleChip)
                                            .opacity(0.92)
                                    }
                                }
                            }
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("secao-toque-tatil")
                        }
                        secao("Campos") { CampoFrila("E-mail", texto: $texto); CampoCodigo(codigo: $codigo) }
                        secao("Filtros e reputação") {
                            FiltroPill("Perto de mim", selecionado: filtro) { filtro.toggle() }
                            SeloReputacao(Reputacao(positivas: 18, total: 20, taxaComparecimento: 0.95, turnosConsiderados: 20, turnosRealizados: 19))
                            SeloReputacao(Reputacao(positivas: 0, total: 0, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0))
                        }
                        secao("Mensagens") { AvisoFrila("Sua ação será enviada quando a conexão voltar."); EstadoOffline(); EstadoPendente("Check-in aguardando envio") }
                        secao("Avaliação") { RespostaSimNao(resposta: $resposta) }
                        secao("Estados") { EstadoVazio("Nenhuma vaga", mensagem: "Novas vagas aparecerão aqui."); EstadoErro("Verifique sua conexão.") {} }
                        secao("Diagnóstico") {
                            Button { fatalError("Falha de teste do Crashlytics") } label: {
                                Text(verbatim: textoForcarFalha)
                            }
                            .accessibilityIdentifier("forcar-falha-crashlytics")
                        }
                        if let api {
                            ValidacaoClienteAPI(api: api, permitirSimulacaoDeConflito: permitirSimulacaoDeConflito)
                        }
                        secao("Folha") {
                            Button(action: { exibirFolha = true }) {
                                Text(verbatim: textoAbrirFolha)
                                    .font(FrilaTipo.botao)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, FrilaEspaco.grande)
                                    .padding(.vertical, FrilaEspaco.pequeno)
                                    .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
                                    .foregroundStyle(FrilaCor.texto)
                                    .background(FrilaCor.superficie, in: Capsule())
                                    .overlay(Capsule().strokeBorder(FrilaCor.borda, lineWidth: 1))
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.tatil)
                            .accessibilityIdentifier("abrir-folha-exemplo")
                        }
                        secao("Vaga") { CartaoVaga(Self.vagaDeExemplo) }
                        secao("Cartão de vaga: sem avaliações") { CartaoVaga(Self.vagaSemAvaliacoes) }
                            .id("catalogo-cartao-sem-avaliacoes")
                        // Entrada provisória da tela de licenças (#178): sai daqui quando existir a Ajuda.
                        NavigationLink { TelaLicencas() } label: {
                            Text(verbatim: TextosDeLicencas.titulo).font(.headline).multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                                .contentShape(RoundedRectangle(cornerRadius: FrilaRaio.medio))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(FrilaCor.primaria)
                        .overlay(RoundedRectangle(cornerRadius: FrilaRaio.medio).stroke(FrilaCor.primaria, lineWidth: 1.5))
                        .accessibilityIdentifier("abrir-licencas")
                    }
                    .padding(FrilaEspaco.medio)
                    .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
                    .frame(maxWidth: .infinity)
                }
                .task {
                    if ProcessInfo.processInfo.arguments.contains("-FRILA_CATALOGO_SEM_AVALIACOES") {
                        await Task.yield()
                        proxy.scrollTo("catalogo-cartao-sem-avaliacoes", anchor: .top)
                    }
                }
            }
            .sheet(isPresented: $exibirFolha) {
                FolhaFrila(verbatim: tituloFolha) {
                    Text(verbatim: corpoFolha)
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.texto)
                }
                .presentationDetents([.medium, .large])
            }
            .background(FrilaCor.fundo)
            .navigationTitle(Text(verbatim: tituloCatalogo))
        }
        .preferredColorScheme(esquemaDeCor)
    }

    // MARK: - Hi-Fi (Fase 2): paleta, tipografia e peças da origem

    private var escuro: Bool { colorScheme == .dark }

    /// Cada amostra mostra o token do app, a função da origem e os hex claro/escuro (`ParidadeDeCoresDesignTests`).
    private static let amostras: [(nome: String, origem: String, cor: Color, hex: String)] = [
        // nome: token do app (`FrilaCor.<nome>`); origem: função do `FrilaColor`.
        ("fundo", "dynamicCanvas", FrilaCor.fundo, "#FFFFFF · #111111"),
        ("superficie", "dynamicFormCardSurface", FrilaCor.superficie, "#FAFAFA · #171717"),
        ("superficieDoCampo", "dynamicFormFieldSurface", FrilaCor.superficieDoCampo, "#F5F5F5 · #1C1C1C"),
        ("controle", "dynamicInputBg", FrilaCor.controle, "#F2F2F0 · #23221F"),
        ("texto", "dynamicTextPrimary", FrilaCor.texto, "#1B1A18 · #F5F4F0"),
        ("textoSecundario", "dynamicFormTextMuted", FrilaCor.textoSecundario, "#6B6B6B · #A3A3A3"),
        ("primaria", "dynamicTextInk", FrilaCor.primaria, "#090908 · #FFFFFF"),
        ("selecao", "primarySelection", FrilaCor.selecao, "#C9470F"),
        ("marca", "dynamicBrandAccent", FrilaCor.marca, "#EA5A36 · #F26643"),
        ("sucesso", "dynamicVerified", FrilaCor.sucesso, "#007A33 · #4ADE80"),
        ("alerta", "dynamicWarningText", FrilaCor.alerta, "#9E5C00 · #FBBF24"),
        ("perigo", "dynamicError", FrilaCor.perigo, "#D82020 · #F87171"),
        ("divisoria", "dynamicHairline", FrilaCor.divisoria, "#E5E5E3 · #2E2D29"),
        ("borda", "dynamicBorder", FrilaCor.borda, "#CECECB · #44433E"),
        ("bordaDoCampo", "dynamicFormFieldBorder", FrilaCor.bordaDoCampo, "#8C8C8C · #6A6A6A")
    ]

    private var paleta: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            ForEach(Self.amostras, id: \.nome) { amostra in
                HStack(spacing: FrilaEspaco.compacto) {
                    RoundedRectangle(cornerRadius: FrilaRaio.pequeno, style: .continuous)
                        .fill(amostra.cor)
                        .frame(width: 44, height: 32)
                        .overlay(RoundedRectangle(cornerRadius: FrilaRaio.pequeno, style: .continuous).strokeBorder(FrilaCor.divisoria, lineWidth: 1))
                    VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                        Text(verbatim: amostra.nome).font(FrilaTipo.meta.weight(.semibold)).foregroundStyle(FrilaCor.texto)
                        Text(verbatim: amostra.origem).font(FrilaTipo.nota).foregroundStyle(FrilaCor.textoSecundario)
                        Text(verbatim: amostra.hex).font(FrilaTipo.nota.monospacedDigit()).foregroundStyle(FrilaCor.textoSecundario)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .accessibilityIdentifier("secao-paleta")
    }

    private var tipografia: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
            Text(verbatim: amostraPergunta).font(FrilaTipo.pergunta).foregroundStyle(FrilaCor.texto)
            Text(verbatim: amostraResposta).font(FrilaTipo.respostaEscolhida).foregroundStyle(FrilaCor.texto)
            Text(verbatim: amostraContexto).font(FrilaTipo.contextoDaResposta).foregroundStyle(FrilaCor.textoSecundario)
            Text(verbatim: amostraSecao).font(FrilaTipo.secao).foregroundStyle(FrilaCor.texto)
            Text(verbatim: amostraCorpo).font(FrilaTipo.corpo).foregroundStyle(FrilaCor.texto)
            Text(verbatim: amostraMeta).font(FrilaTipo.meta).foregroundStyle(FrilaCor.textoSecundario)
            Text(verbatim: amostraMicro).font(FrilaTipo.microRotulo).textCase(.uppercase).tracking(0.8).foregroundStyle(FrilaCor.textoSecundario)
            Text(verbatim: FrilaMoney.rate(160, per: .hour)).font(FrilaTypography.metric).foregroundStyle(FrilaCor.texto)
        }
        .accessibilityIdentifier("secao-tipografia")
    }

    private var botoesDoEstudio: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
            FrilaButton("Publicar vaga", icon: "paperplane.fill", variant: .primary, size: .prominent, isDark: escuro, isFullWidth: true)
            FrilaButton("Continuar", variant: .secondary, size: .standard, isDark: escuro, isFullWidth: true)
            HStack(spacing: FrilaEspaco.pequeno) {
                FrilaButton("Contorno", variant: .outline, size: .standard, isDark: escuro)
                FrilaButton("Discreto", variant: .ghost, size: .standard, isDark: escuro)
                FrilaButton("Compacto", variant: .outline, size: .compact, isDark: escuro)
            }
        }
        .accessibilityIdentifier("secao-botoes-estudio")
    }

    private var chipsDoEstudio: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
            HStack(spacing: FrilaEspaco.pequeno) {
                FrilaFilterChip("Perto de mim", isSelected: chipDoEstudio, systemImage: "location.fill", isDark: escuro) { chipDoEstudio.toggle() }
                FrilaFilterChip("Hoje", isSelected: !chipDoEstudio, isDark: escuro) { chipDoEstudio.toggle() }
            }
            HStack(spacing: FrilaEspaco.pequeno) {
                FrilaStatusChip("Verificado", style: .verified, systemImage: "checkmark.seal.fill", isDark: escuro)
                FrilaStatusChip("Pendente", style: .warning, systemImage: "clock", isDark: escuro)
                FrilaStatusChip("Neutro", style: .neutral, isDark: escuro)
            }
        }
        .accessibilityIdentifier("secao-chips-estudio")
    }

    private func secao<Conteudo: View>(_ titulo: LocalizedStringKey, @ViewBuilder conteudo: () -> Conteudo) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) { Text(titulo, bundle: bundleApresentacao).font(.title3.bold()); conteudo() }
    }

    private static var vagaDeExemplo: VagaNaLista {
        let inicio = Date.now.addingTimeInterval(86_400)
        guard let periodo = try? Periodo(inicio: inicio, fim: inicio.addingTimeInterval(14_400)) else {
            preconditionFailure("Preview contém período inválido")
        }
        let reputacao = Reputacao(positivas: 18, total: 20, taxaComparecimento: 0.95, turnosConsiderados: 20, turnosRealizados: 19)
        return VagaNaLista(
            id: UUID(),
            funcao: Funcao(id: UUID(), nome: "Garçom", categoria: "Salão"),
            estabelecimento: PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: "Bistrô Ipê", reputacao: reputacao),
            periodo: periodo,
            local: "CLS 405, Asa Sul, Brasília - DF", regiaoAdministrativa: "Plano Piloto", distanciaKm: 2.4,
            valor: Dinheiro(centavos: 12000), posicoesAbertas: 2,
            inclusos: Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false), modo: .urgencia
        )
    }

    private static var vagaSemAvaliacoes: VagaNaLista {
        let base = Self.vagaDeExemplo
        let reputacao = Reputacao(positivas: 0, total: 0, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0)
        let estabelecimento = PerfilPublico(
            id: base.estabelecimento.id,
            tipo: base.estabelecimento.tipo,
            nome: base.estabelecimento.nome,
            reputacao: reputacao
        )
        return VagaNaLista(
            id: UUID(),
            funcao: base.funcao,
            estabelecimento: estabelecimento,
            periodo: base.periodo,
            local: base.local,
            regiaoAdministrativa: base.regiaoAdministrativa,
            distanciaKm: base.distanciaKm,
            valor: base.valor,
            posicoesAbertas: base.posicoesAbertas,
            inclusos: base.inclusos,
            modo: base.modo
        )
    }
}

#Preview("Tamanho padrão") { CatalogoDesignSystem() }
#Preview("Acessibilidade") { CatalogoDesignSystem().environment(\.dynamicTypeSize, .accessibility3) }
#endif
