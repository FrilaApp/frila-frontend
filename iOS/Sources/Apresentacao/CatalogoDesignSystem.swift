import FrilaDominio
import SwiftUI

public struct CatalogoDesignSystem: View {
    @State private var texto = ""
    @State private var codigo = ""
    @State private var filtro = true
    @State private var resposta: Bool?

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                    secao("Botões") { BotaoPrimario("Continuar") {}; BotaoSecundario("Voltar") {} }
                    secao("Campos") { CampoFrila("E-mail", texto: $texto); CampoCodigo(codigo: $codigo) }
                    secao("Filtros e reputação") {
                        FiltroPill("Perto de mim", selecionado: filtro) { filtro.toggle() }
                        SeloReputacao(Reputacao(positivas: 18, total: 20, taxaComparecimento: 0.95, turnosConsiderados: 20))
                        SeloReputacao(Reputacao(positivas: 0, total: 0, taxaComparecimento: nil, turnosConsiderados: 0))
                    }
                    secao("Mensagens") { AvisoFrila("Sua ação será enviada quando a conexão voltar."); EstadoOffline(); EstadoPendente("Check-in aguardando envio") }
                    secao("Avaliação") { RespostaSimNao(resposta: $resposta) }
                    secao("Estados") { EstadoVazio("Nenhuma vaga", mensagem: "Novas oportunidades aparecerão aqui."); EstadoErro("Verifique sua conexão.") {} }
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

    private static var vagaDeExemplo: Vaga {
        guard let ponto = try? Coordenada(latitude: -23.5505, longitude: -46.6333) else {
            preconditionFailure("Preview contém coordenada inválida")
        }
        let inicio = Date.now.addingTimeInterval(86_400)
        guard let periodo = try? Periodo(inicio: inicio, fim: inicio.addingTimeInterval(14_400)) else {
            preconditionFailure("Preview contém período inválido")
        }
        return Vaga(
            id: UUID(),
            estabelecimento: Estabelecimento(id: UUID(), nome: "Bistrô Ipê", tipo: .foodService, endereco: "Centro, São Paulo", ponto: ponto),
            funcao: Funcao(id: UUID(), nome: "Garçom", categoria: "Salão"),
            periodo: periodo,
            local: "Centro, São Paulo", ponto: ponto, valor: Dinheiro(centavos: 12000), posicoes: 2, posicoesAbertas: 2,
            inclusos: Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false), responsavelLocal: "Marina", modo: .urgencia, estado: .publicada
        )
    }
}

#Preview("Tamanho padrão") { CatalogoDesignSystem() }
#Preview("Acessibilidade") { CatalogoDesignSystem().environment(\.dynamicTypeSize, .accessibility3) }
