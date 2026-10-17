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
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                    secao("Botões") { BotaoPrimario("Continuar") {}; BotaoSecundario("Voltar") {} }
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
}

#Preview("Tamanho padrão") { CatalogoDesignSystem() }
#Preview("Acessibilidade") { CatalogoDesignSystem().environment(\.dynamicTypeSize, .accessibility3) }
#endif
