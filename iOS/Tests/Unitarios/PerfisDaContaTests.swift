import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

@MainActor
@Suite("Perfis e reputação (#54)")
struct PerfisDaContaTests {
    @Test("Meu perfil combina os dados da conta e do perfil profissional com a reputação pública")
    func meuPerfil() async {
        let api = ApiClienteEmMemoria()
        let model = MeuPerfilProfissionalViewModel(api: api)
        await model.carregar()

        #expect(model.conta?.nome == "Ana Cunha")
        #expect(model.perfil?.funcoes.isEmpty == false)
        #expect(model.perfilPublico?.reputacao.total == 7)
        #expect(model.perfilPublico?.reputacao.positivas == 7)
        #expect(model.perfilPublico?.reputacao.turnosConsiderados == 7)
        #expect(model.mensagemErro == nil)
    }

    @Test("Perfil do estabelecimento carrega dados da conta e reputação pública")
    func perfilEstabelecimento() async {
        let api = ApiClienteEmMemoria()
        let model = PerfilEstabelecimentoViewModel(api: api)
        await model.carregar()

        #expect(model.estabelecimento?.nome == "Bistrô Ipê")
        #expect(model.estabelecimento?.tipo != nil)
        #expect(model.perfilPublico?.reputacao.total == 20)
        #expect(model.perfilPublico?.reputacao.positivas == 18)
        #expect(model.mensagemErro == nil)
    }

    @Test("Reputação sem avaliação não produz percentual nem 0 de 0")
    func reputacaoSemHistorico() {
        let reputacao = Reputacao(positivas: 0, total: 0, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0)
        #expect(reputacao.semHistorico)
        #expect(reputacao.descricao() == "Sem histórico")
        #expect(SeloReputacao.descricao(reputacao) == "Sem histórico")
        #expect(!SeloReputacao.descricao(reputacao).contains("0 de 0"))
        #expect(SeloReputacao.descricaoComparecimento(reputacao) == nil)
    }

    @Test("O selo mostra comparecimento com numerador, denominador e plural correto")
    func reputacaoComHistorico() {
        let reputacao = Reputacao(positivas: 11, total: 12, taxaComparecimento: 0.92, turnosConsiderados: 12, turnosRealizados: 11)
        #expect(SeloReputacao.descricao(reputacao) == "11 de 12 chamariam de novo")
        #expect(SeloReputacao.descricaoComparecimento(reputacao) == "Compareceu a 11 de 12 turnos")
    }

    @Test("O selo usa o singular para um turno")
    func compareceuUmTurno() {
        let reputacao = Reputacao(positivas: 1, total: 1, taxaComparecimento: 1, turnosConsiderados: 1, turnosRealizados: 1)
        #expect(SeloReputacao.descricaoComparecimento(reputacao) == "Compareceu a 1 de 1 turno")
    }
}
