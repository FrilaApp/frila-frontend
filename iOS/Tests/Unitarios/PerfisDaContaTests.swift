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

    @Test("Reputação com avaliações mas sem turnos considerados não produz '0 de 0 turnos'")
    func reputacaoSemTurnosConsiderados() {
        let reputacao = Reputacao(positivas: 4, total: 5, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0)
        #expect(!reputacao.semHistorico)
        #expect(SeloReputacao.descricao(reputacao) == "4 de 5 chamariam de novo")
        #expect(SeloReputacao.descricaoComparecimento(reputacao) == nil)
    }

    @Test("Constante oficial reúne os endereços de Termos de uso e Política de privacidade (#54)")
    func constanteDeEnderecosOficiais() {
        let padrao = EnderecosOficiais.padrao
        #expect(padrao.termosDeUso.absoluteString == "https://frila.app/termos")
        #expect(padrao.politicaDePrivacidade.absoluteString == "https://frila.app/privacidade")
        #expect(padrao.emailSuporte == "suportefrila@gmail.com")
        #expect(padrao.urlSuporte?.absoluteString == "mailto:suportefrila@gmail.com")
        #expect(padrao.urlSuporte?.scheme == "mailto")

        let personalizado = EnderecosOficiais(
            termosDeUso: URL(string: "https://exemplo.com/termos")!,
            politicaDePrivacidade: URL(string: "https://exemplo.com/privacidade")!,
            emailSuporte: "ajuda@frila.app"
        )
        #expect(personalizado.emailSuporte == "ajuda@frila.app")
        #expect(personalizado.urlSuporte?.absoluteString == "mailto:ajuda@frila.app")
    }

    @Test("Os dois links de termos e privacidade existem em Meu perfil e apontam para a constante (#54)")
    func linksDeTermosEPrivacidadeEmMeuPerfil() {
        let api = ApiClienteEmMemoria()
        let tela = TelaMeuPerfilProfissional(api: api, sair: {})

        #expect(tela.enderecos == EnderecosOficiais.padrao)
        #expect(tela.enderecos.termosDeUso.absoluteString == "https://frila.app/termos")
        #expect(tela.enderecos.politicaDePrivacidade.absoluteString == "https://frila.app/privacidade")

        let ajuda = TelaAjudaPerfil(enderecos: tela.enderecos)
        #expect(ajuda.enderecos.termosDeUso == EnderecosOficiais.padrao.termosDeUso)
        #expect(ajuda.enderecos.politicaDePrivacidade == EnderecosOficiais.padrao.politicaDePrivacidade)
        #expect(ajuda.enderecos.emailSuporte == "suportefrila@gmail.com")
    }

    @Test("Os dois links de termos e privacidade existem em Estabelecimento e apontam para a constante (#54)")
    func linksDeTermosEPrivacidadeEmPerfilEstabelecimento() {
        let api = ApiClienteEmMemoria()
        let tela = TelaPerfilEstabelecimento(api: api, sair: {})

        #expect(tela.enderecos == EnderecosOficiais.padrao)
        #expect(tela.enderecos.termosDeUso.absoluteString == "https://frila.app/termos")
        #expect(tela.enderecos.politicaDePrivacidade.absoluteString == "https://frila.app/privacidade")

        let ajuda = TelaAjudaPerfil(enderecos: tela.enderecos)
        #expect(ajuda.enderecos.termosDeUso == EnderecosOficiais.padrao.termosDeUso)
        #expect(ajuda.enderecos.politicaDePrivacidade == EnderecosOficiais.padrao.politicaDePrivacidade)
        #expect(ajuda.enderecos.emailSuporte == "suportefrila@gmail.com")
    }

    @Test("Texto de aceite do cadastro contém os endereços da constante EnderecosOficiais (#54)")
    func cadastroContemEnderecosOficiais() throws {
        let raiz = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let caminhoCadastro = raiz.appending(path: "Sources/Apresentacao/Fluxos/Autenticacao/TelaCadastro.swift")
        let codigoCadastro = try String(contentsOf: caminhoCadastro, encoding: .utf8)
        let padrao = EnderecosOficiais.padrao
        #expect(codigoCadastro.contains(padrao.termosDeUso.absoluteString), "TelaCadastro deve conter o endereço oficial de termos")
        #expect(codigoCadastro.contains(padrao.politicaDePrivacidade.absoluteString), "TelaCadastro deve conter o endereço oficial de privacidade")

        let caminhoCatalogo = raiz.appending(path: "Resources/Localizable.xcstrings")
        let conteudoCatalogo = try String(contentsOf: caminhoCatalogo, encoding: .utf8)
        #expect(conteudoCatalogo.contains(padrao.termosDeUso.absoluteString), "Localizable.xcstrings deve conter o endereço oficial de termos")
        #expect(conteudoCatalogo.contains(padrao.politicaDePrivacidade.absoluteString), "Localizable.xcstrings deve conter o endereço oficial de privacidade")
    }

    @Test("TelaAjudaPerfil inicializa com endereços padrão e catálogo contém Licenças de terceiros (#178)")
    func ajudaContemLicencasDeTerceiros() throws {
        let ajuda = TelaAjudaPerfil()
        #expect(ajuda.enderecos == EnderecosOficiais.padrao)

        let raiz = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let caminhoCatalogo = raiz.appending(path: "Resources/Localizable.xcstrings")
        let conteudoCatalogo = try String(contentsOf: caminhoCatalogo, encoding: .utf8)
        #expect(conteudoCatalogo.contains("Licenças de terceiros"), "Localizable.xcstrings deve conter Licenças de terceiros")
    }

    @Test("Texto explicativo de 'Por que recebo vagas' corresponde à redação aprovada (#54)")
    func explicacaoPorQueReceboVagasTextoAprovado() {
        let fraseEsperada = "Você recebe notificação de vagas da sua função, perto de você, quando o turno inteiro cabe nos horários em que marcou disponibilidade. Todas as vagas do DF aparecem na lista."
        #expect(TextosPerfilConta.explicacaoVagas == fraseEsperada)
    }

    @Test("MeuPerfilProfissionalViewModel propaga erro e limpa carregando ao falhar em carregar conta")
    func meuPerfilFalhaAoCarregarConta() async {
        let vm = MeuPerfilProfissionalViewModel(
            conta: { throw ErroDaApi(codigo: .semRede) },
            perfil: { try await ApiClienteEmMemoria().meuPerfilProfissional() },
            publico: { _ in try await ApiClienteEmMemoria().perfilPublico(id: UUID()) }
        )
        await vm.carregar()

        #expect(vm.mensagemErro == TextosPerfilConta.erro)
        #expect(vm.carregando == false)
        #expect(vm.conta == nil)
        #expect(vm.perfil == nil)
        #expect(vm.perfilPublico == nil)
    }

    @Test("MeuPerfilProfissionalViewModel propaga erro ao falhar em carregar perfil público")
    func meuPerfilFalhaAoCarregarPerfilPublico() async {
        let api = ApiClienteEmMemoria()
        let vm = MeuPerfilProfissionalViewModel(
            conta: { try await api.minhaConta() },
            perfil: { try await api.meuPerfilProfissional() },
            publico: { _ in throw ErroDaApi(codigo: .naoEncontrado) }
        )
        await vm.carregar()

        #expect(vm.mensagemErro == TextosPerfilConta.erro)
        #expect(vm.carregando == false)
        #expect(vm.perfilPublico == nil)
    }

    @Test("MeuPerfilProfissionalViewModel limpa mensagem de erro em carregamento subsequente bem-sucedido")
    func meuPerfilRecuperacaoDeErro() async {
        final class Estado: @unchecked Sendable {
            var deveFalhar = true
        }
        let estado = Estado()
        let api = ApiClienteEmMemoria()
        let vm = MeuPerfilProfissionalViewModel(
            conta: {
                if estado.deveFalhar { throw ErroDaApi(codigo: .semRede) }
                return try await api.minhaConta()
            },
            perfil: { try await api.meuPerfilProfissional() },
            publico: { try await api.perfilPublico(id: $0) }
        )

        await vm.carregar()
        #expect(vm.mensagemErro == TextosPerfilConta.erro)
        #expect(vm.conta == nil)

        estado.deveFalhar = false
        await vm.carregar()
        #expect(vm.mensagemErro == nil)
        #expect(vm.carregando == false)
        #expect(vm.conta != nil)
    }

    @Test("PerfilEstabelecimentoViewModel trata conta sem estabelecimentos com encerramento precoce")
    func perfilEstabelecimentoListaVazia() async {
        let vm = PerfilEstabelecimentoViewModel(
            estabelecimentos: { [] },
            publico: { _ in
                Issue.record("não devia buscar perfil público se não há estabelecimento")
                throw ErroDaApi(codigo: .desconhecido)
            }
        )
        await vm.carregar()

        #expect(vm.estabelecimento == nil)
        #expect(vm.perfilPublico == nil)
        #expect(vm.mensagemErro == nil)
        #expect(vm.carregando == false)
    }

    @Test("PerfilEstabelecimentoViewModel propaga erro ao falhar na consulta de estabelecimentos")
    func perfilEstabelecimentoFalhaEstabelecimentos() async {
        let vm = PerfilEstabelecimentoViewModel(
            estabelecimentos: { throw ErroDaApi(codigo: .semRede) },
            publico: { _ in throw ErroDaApi(codigo: .desconhecido) }
        )
        await vm.carregar()

        #expect(vm.mensagemErro == TextosPerfilConta.erro)
        #expect(vm.carregando == false)
        #expect(vm.estabelecimento == nil)
    }

    @Test("PerfilEstabelecimentoViewModel propaga erro ao falhar na consulta de perfil público após estabelecimento")
    func perfilEstabelecimentoFalhaPerfilPublico() async throws {
        let api = ApiClienteEmMemoria()
        let estabelecimentos = try await api.meusEstabelecimentos()
        let vm = PerfilEstabelecimentoViewModel(
            estabelecimentos: { estabelecimentos },
            publico: { _ in throw ErroDaApi(codigo: .naoEncontrado) }
        )
        await vm.carregar()

        #expect(vm.mensagemErro == TextosPerfilConta.erro)
        #expect(vm.carregando == false)
        #expect(vm.estabelecimento == nil)
        #expect(vm.perfilPublico == nil)
    }
}

