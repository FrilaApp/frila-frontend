import FrilaDominio
import SwiftUI

public struct CatalogoDesignSystem: View {
    private let api: (any ApiCliente)?
    private let permitirSimulacaoDeConflito: Bool
    @State private var texto = ""
    @State private var codigo = ""
    @State private var filtro = true
    @State private var resposta: Bool?

    public init(api: (any ApiCliente)? = nil, permitirSimulacaoDeConflito: Bool = false) {
        self.api = api
        self.permitirSimulacaoDeConflito = permitirSimulacaoDeConflito
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                    secao("Botões") { BotaoPrimario("Continuar") {}; BotaoSecundario("Voltar") {} }
                    secao("Campos") { CampoFrila("E-mail", texto: $texto); CampoCodigo(codigo: $codigo) }
                    secao("Filtros e reputação") {
                        FiltroPill("Perto de mim", selecionado: filtro) { filtro.toggle() }
                        SeloReputacao(Reputacao(positivas: 18, total: 20, taxaComparecimento: 0.95, turnosConsiderados: 20, turnosRealizados: 21))
                        SeloReputacao(Reputacao(positivas: 0, total: 0, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0))
                    }
                    secao("Mensagens") { AvisoFrila("Sua ação será enviada quando a conexão voltar."); EstadoOffline(); EstadoPendente("Check-in aguardando envio") }
                    secao("Avaliação") { RespostaSimNao(resposta: $resposta) }
                    secao("Estados") { EstadoVazio("Nenhuma vaga", mensagem: "Novas oportunidades aparecerão aqui."); EstadoErro("Verifique sua conexão.") {} }
                    if let api {
                        ValidacaoClienteAPI(api: api, permitirSimulacaoDeConflito: permitirSimulacaoDeConflito)
                    }
                    secao("Vaga") { CartaoVaga(Self.vagaDeExemplo) }
                }
                .padding(FrilaEspaco.medio)
                .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
                .frame(maxWidth: .infinity)
            }
            .background(FrilaCor.fundo)
            .navigationTitle("Frila UI")
        }
    }

    private func secao<Conteudo: View>(_ titulo: LocalizedStringKey, @ViewBuilder conteudo: () -> Conteudo) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) { Text(titulo).font(.title3.bold()); conteudo() }
    }

    private static var vagaDeExemplo: VagaNaLista {
        let inicio = Date.now.addingTimeInterval(86_400)
        guard let periodo = try? Periodo(inicio: inicio, fim: inicio.addingTimeInterval(14_400)) else {
            preconditionFailure("Preview contém período inválido")
        }
        let reputacao = Reputacao(positivas: 18, total: 20, taxaComparecimento: 0.95, turnosConsiderados: 20, turnosRealizados: 21)
        return VagaNaLista(
            id: UUID(),
            funcao: Funcao(id: UUID(), nome: "Garçom", categoria: "Salão"),
            estabelecimento: PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: "Bistrô Ipê", reputacao: reputacao),
            periodo: periodo,
            local: "Centro, São Paulo", distanciaKm: 2.4, valor: Dinheiro(centavos: 12000), posicoesAbertas: 2,
            inclusos: Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false), modo: .urgencia
        )
    }
}

#Preview("Tamanho padrão") { CatalogoDesignSystem() }
#Preview("Acessibilidade") { CatalogoDesignSystem().environment(\.dynamicTypeSize, .accessibility3) }
