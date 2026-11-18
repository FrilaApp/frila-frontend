@testable import FrilaApresentacao
@testable import FrilaDados
import Foundation
import FrilaDominio
import Testing

/// O que a API de mentira recebeu e o que ela vai responder, na ordem das chamadas.
private actor ServidorDeEscala {
    private(set) var recebidas: [PublicacaoEscala] = []
    private var respostas: [Result<EscalaPublicada, Error>]

    init(_ respostas: [Result<EscalaPublicada, Error>]) { self.respostas = respostas }

    func publicar(_ escala: PublicacaoEscala) async throws -> EscalaPublicada {
        recebidas.append(escala)
        guard !respostas.isEmpty else { throw ErroDaApi(codigo: .desconhecido) }
        return try respostas.removeFirst().get()
    }

    var chamadas: Int { recebidas.count }
}

private func publicada(vagas: Int = 2) -> EscalaPublicada {
    EscalaPublicada(
        eventoID: UUID(),
        vagas: (0..<vagas).map { _ in VagaPublicada(vagaID: UUID(), posicoes: [UUID()]) }
    )
}

struct RecusaDaEscala: CustomTestStringConvertible, Sendable {
    let erro: ErroDaApi
    let mensagemGeral: String
    /// Onde a marca aparece: `evento` (campo) ou `vaga` (índice e campo); `nil` quando é só a mensagem geral.
    let evento: CampoDoEventoDaEscala?
    let vaga: (indice: Int, campo: CampoDaVagaDaEscala)?
    var testDescription: String { "\(erro.codigo.rawValue) \(erro.detalhes ?? "")" }
}

let recusasDoServidor: [RecusaDaEscala] = [
    RecusaDaEscala(erro: ErroDaApi(codigo: .campoInvalido, detalhes: "evento.nome"), mensagemGeral: TextosDaEscala.Erro.temErro, evento: .nome, vaga: nil),
    RecusaDaEscala(erro: ErroDaApi(codigo: .campoObrigatorio, detalhes: "evento.data"), mensagemGeral: TextosDaEscala.Erro.temErro, evento: .data, vaga: nil),
    RecusaDaEscala(erro: ErroDaApi(codigo: .campoInvalido, detalhes: "vagas[1].valor_centavos"), mensagemGeral: TextosDaEscala.Erro.temErro, evento: nil, vaga: (1, .valor)),
    RecusaDaEscala(erro: ErroDaApi(codigo: .campoObrigatorio, detalhes: "vagas[0].funcao_id"), mensagemGeral: TextosDaEscala.Erro.temErro, evento: nil, vaga: (0, .funcao)),
    RecusaDaEscala(erro: ErroDaApi(codigo: .campoInvalido, detalhes: "vagas[1].posicoes"), mensagemGeral: TextosDaEscala.Erro.temErro, evento: nil, vaga: (1, .pessoas)),
    RecusaDaEscala(erro: ErroDaApi(codigo: .horarioInvalido, detalhes: "vagas[0]"), mensagemGeral: TextosDaEscala.Erro.temErro, evento: nil, vaga: (0, .horario)),
    RecusaDaEscala(erro: ErroDaApi(codigo: .selecaoSemAntecedencia, detalhes: "vagas[1]"), mensagemGeral: TextosDaEscala.Erro.temErro, evento: nil, vaga: (1, .horario)),
    RecusaDaEscala(erro: ErroDaApi(codigo: .campoInvalido, detalhes: "vagas"), mensagemGeral: TextosDaEscala.Erro.quantidade, evento: nil, vaga: nil),
    RecusaDaEscala(erro: ErroDaApi(codigo: .campoInvalido, detalhes: "posicoes"), mensagemGeral: TextosDaEscala.Erro.somaDePessoas, evento: nil, vaga: nil),
    RecusaDaEscala(erro: ErroDaApi(codigo: .campoObrigatorio, detalhes: "evento.local"), mensagemGeral: TextosDaEscala.Erro.cadastroDaCasa, evento: nil, vaga: nil),
    RecusaDaEscala(erro: ErroDaApi(codigo: .campoInvalido, detalhes: "evento.ponto"), mensagemGeral: TextosDaEscala.Erro.cadastroDaCasa, evento: nil, vaga: nil),
    RecusaDaEscala(erro: ErroDaApi(codigo: .campoInvalido, detalhes: "vagas[9].valor_centavos"), mensagemGeral: TextosDaEscala.Erro.generico, evento: nil, vaga: nil),
    RecusaDaEscala(erro: ErroDaApi(codigo: .campoInvalido), mensagemGeral: TextosDaEscala.Erro.generico, evento: nil, vaga: nil),
    RecusaDaEscala(erro: ErroDaApi(codigo: .semPermissao), mensagemGeral: TextosDaEscala.Erro.semPermissao, evento: nil, vaga: nil),
    RecusaDaEscala(erro: ErroDaApi(codigo: .semPermissao, detalhes: "conta_suspensa"), mensagemGeral: TextosDaEscala.Erro.contaSuspensa, evento: nil, vaga: nil),
    RecusaDaEscala(erro: ErroDaApi(codigo: .perfilIncompativel), mensagemGeral: TextosDaEscala.Erro.perfilIncompativel, evento: nil, vaga: nil),
    RecusaDaEscala(erro: ErroDaApi(codigo: .limiteExcedido), mensagemGeral: MensagemDoErroAPI.texto(ErroDaApi(codigo: .limiteExcedido)), evento: nil, vaga: nil),
    RecusaDaEscala(erro: ErroDaApi(codigo: .naoAutenticado), mensagemGeral: MensagemDoErroAPI.texto(ErroDaApi(codigo: .naoAutenticado)), evento: nil, vaga: nil),
    RecusaDaEscala(erro: ErroDaApi(codigo: .desconhecido), mensagemGeral: TextosDaEscala.Erro.generico, evento: nil, vaga: nil),
]


/// A escala de evento (contrato 0.2.96, `publicar_escala`): o formulário, a conferência local, o tudo ou nada e o que
/// acontece quando a resposta não chega.
@MainActor
@Suite("Escala de evento: formulário, conferência local e publicação (publicar_escala, 0.2.96)")
struct PublicarEscalaViewModelTests {
    private let agora = Date(timeIntervalSince1970: 1_800_000_000)
    private let garcom = Funcao(id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!, nome: "Garçom", categoria: "Salão")
    private let bartender = Funcao(id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!, nome: "Bartender", categoria: "Bar")

    private func estabelecimento() throws -> Estabelecimento {
        Estabelecimento(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!, nome: "Bistrô Ipê", tipo: .foodService,
            endereco: "CLS 405, Asa Sul, Brasília - DF", regiaoAdministrativa: "Plano Piloto",
            ponto: try Coordenada(latitude: -15.8121, longitude: -47.8997)
        )
    }

    private func modelo(
        prazo: Duration = .seconds(5), _ servidor: ServidorDeEscala
    ) throws -> PublicarEscalaViewModel {
        let fixo = agora
        return PublicarEscalaViewModel(
            estabelecimento: try estabelecimento(), funcoes: [garcom, bartender], agora: { fixo }, prazo: prazo,
            publicar: { try await servidor.publicar($0) }
        )
    }

    /// O formulário preenchido: duas vagas (Garçom e Bartender) de um evento.
    private func preenchido(_ vm: PublicarEscalaViewModel) {
        vm.nome = "Formatura de Direito"
        vm.responsavelLocal = "Marina"
        let primeira = vm.vagas[0].id
        vm.atualizar(primeira) { $0.funcaoID = garcom.id; $0.valorTexto = "16000"; $0.pessoas = 6 }
        vm.adicionarVaga()
        let segunda = vm.vagas[1].id
        vm.atualizar(segunda) { $0.funcaoID = bartender.id; $0.valorTexto = "18000"; $0.pessoas = 2 }
    }

    // MARK: Conferência local

    @Test("O formulário abre com uma vaga, evento amanhã, e sem erro antes de tentar")
    func abertura() throws {
        let vm = try modelo(ServidorDeEscala([]))

        #expect(vm.vagas.count == 1)
        #expect(vm.erros.vazio)
        #expect(vm.vagas[0].inicio > agora)
        #expect(vm.vagas[0].fim > vm.vagas[0].inicio)
        #expect(vm.vagas[0].pessoas == 1)
        #expect(vm.refeicao == false && vm.transporte == false && vm.materialProprio == false)
    }

    @Test("Formulário vazio: cada campo faltante é marcado, a mensagem geral diz que nada foi publicado, e a API não é chamada")
    func vazio() async throws {
        let servidor = ServidorDeEscala([.success(publicada())])
        let vm = try modelo(servidor)

        await vm.publicar()

        #expect(vm.erros.evento[.nome] == TextosDaEscala.Erro.nome)
        #expect(vm.erros.evento[.responsavel] == TextosDaEscala.Erro.responsavel)
        let daVaga = try #require(vm.erros.vagas[vm.vagas[0].id])
        #expect(daVaga[.funcao] == TextosDaEscala.Erro.funcao)
        #expect(daVaga[.valor] == TextosDaEscala.Erro.valor)
        #expect(vm.erros.geral == TextosDaEscala.Erro.temErro)
        #expect(vm.resultado == nil && vm.tentativaIncerta == nil)
        #expect(await servidor.chamadas == 0)
    }

    @Test("O nome tem de 3 a 100 letras", arguments: [("ab", false), ("abc", true), (String(repeating: "a", count: 100), true), (String(repeating: "a", count: 101), false)])
    func tamanhoDoNome(nome: String, vale: Bool) throws {
        let vm = try modelo(ServidorDeEscala([]))
        preenchido(vm)
        vm.nome = nome

        #expect(vm.validar() == vale)
        #expect((vm.erros.evento[.nome] == nil) == vale)
    }

    @Test("Início que já passou, ou fim que não vem depois do início, marca o horário da vaga")
    func horario() throws {
        let vm = try modelo(ServidorDeEscala([]))
        preenchido(vm)
        let primeira = vm.vagas[0].id
        vm.atualizar(primeira) { $0.inicio = agora.addingTimeInterval(-60); $0.fim = agora.addingTimeInterval(3_600) }
        let segunda = vm.vagas[1].id
        vm.atualizar(segunda) { $0.fim = $0.inicio }

        #expect(vm.validar() == false)
        #expect(vm.erros.vagas[primeira]?[.horario] == TextosDaEscala.Erro.horario)
        #expect(vm.erros.vagas[segunda]?[.horario] == TextosDaEscala.Erro.horario)
    }

    @Test("Mais de 100 pessoas somando as vagas é recusado no aparelho, com a mensagem da soma")
    func somaDePessoas() async throws {
        let servidor = ServidorDeEscala([.success(publicada())])
        let vm = try modelo(servidor)
        preenchido(vm)
        vm.atualizar(vm.vagas[0].id) { $0.pessoas = 60 }
        vm.atualizar(vm.vagas[1].id) { $0.pessoas = 41 }

        await vm.publicar()

        #expect(vm.totalDePessoas == 101)
        #expect(vm.erros.geral == TextosDaEscala.Erro.somaDePessoas)
        #expect(await servidor.chamadas == 0)
    }

    @Test("Cada vaga leva de 1 a 100 pessoas: o contador não passa dos limites")
    func limitesDePessoas() throws {
        let vm = try modelo(ServidorDeEscala([]))
        let id = vm.vagas[0].id

        vm.diminuirPessoas(em: id)
        #expect(vm.vagas[0].pessoas == 1)
        vm.atualizar(id) { $0.pessoas = 500 }
        #expect(vm.vagas[0].pessoas == PublicacaoEscala.limiteDePosicoes)
        vm.aumentarPessoas(em: id)
        #expect(vm.vagas[0].pessoas == 100)
    }

    @Test("Uma escala tem de 1 a 10 vagas: a última não sai, e a décima primeira não entra")
    func quantidadeDeVagas() throws {
        let vm = try modelo(ServidorDeEscala([]))

        #expect(vm.podeRemoverVaga == false)
        vm.removerVaga(id: vm.vagas[0].id)
        #expect(vm.vagas.count == 1)

        for _ in 0..<20 { vm.adicionarVaga() }
        #expect(vm.vagas.count == PublicacaoEscala.limiteDeVagas)
        #expect(vm.podeAdicionarVaga == false)

        vm.removerVaga(id: vm.vagas[3].id)
        #expect(vm.vagas.count == 9)
        #expect(vm.podeAdicionarVaga)
    }

    @Test("A vaga nova nasce com o horário da anterior, e mudar o dia do evento leva todas as vagas junto, com as mesmas horas")
    func dia() throws {
        let vm = try modelo(ServidorDeEscala([]))
        preenchido(vm)
        let antes = vm.vagas.map { ($0.inicio, $0.fim) }
        #expect(vm.vagas[1].inicio == vm.vagas[0].inicio)

        vm.data = vm.data.addingTimeInterval(3 * 24 * 3_600)

        for (indice, vaga) in vm.vagas.enumerated() {
            #expect(vaga.inicio.timeIntervalSince(antes[indice].0) == 3 * 24 * 3_600)
            #expect(vaga.fim.timeIntervalSince(antes[indice].1) == 3 * 24 * 3_600)
        }
    }

    @Test("Mexer num campo tira a marca de erro dele, e só dele")
    func editarLimpaOErro() async throws {
        let vm = try modelo(ServidorDeEscala([]))
        await vm.publicar()
        let id = vm.vagas[0].id
        #expect(vm.erros.evento[.nome] != nil && vm.erros.vagas[id]?[.valor] != nil)

        vm.nome = "Formatura"
        vm.atualizar(id) { $0.valorTexto = "100" }

        #expect(vm.erros.evento[.nome] == nil)
        #expect(vm.erros.vagas[id]?[.valor] == nil)
        #expect(vm.erros.evento[.responsavel] != nil)
        #expect(vm.erros.vagas[id]?[.funcao] != nil)
    }

    // MARK: Publicar

    @Test("Sucesso: manda o evento no endereço da casa, o dia de Brasília, as duas vagas em urgência e uma chave só; a tela mostra as vagas publicadas")
    func sucesso() async throws {
        let servidor = ServidorDeEscala([.success(publicada(vagas: 2))])
        let vm = try modelo(servidor)
        preenchido(vm)
        vm.refeicao = true

        await vm.publicar()

        let escala = try #require(await servidor.recebidas.first)
        #expect(await servidor.chamadas == 1)
        #expect(escala.estabelecimentoID == vm.estabelecimento.id)
        #expect(escala.evento.nome == "Formatura de Direito")
        #expect(escala.evento.local == "CLS 405, Asa Sul, Brasília - DF")
        #expect(escala.evento.regiaoAdministrativa == "Plano Piloto")
        #expect(escala.evento.data == DataCivil.deSaoPaulo(vm.data))
        #expect(escala.vagas.map(\.funcaoID) == [garcom.id, bartender.id])
        #expect(escala.vagas.map(\.valor.centavos) == [16_000, 18_000])
        #expect(escala.vagas.map(\.posicoes) == [6, 2])
        #expect(escala.vagas.allSatisfy { $0.modo == .urgencia && $0.responsavelLocal == "Marina" && $0.inclusos.refeicao })
        #expect(vm.resultado != nil)
        #expect(vm.vagasPublicadas == 2)
        #expect(vm.tentativaIncerta == nil && vm.erros.vazio && vm.enviando == false)
    }

    @Test("O nome e o responsável vão sem os espaços das pontas")
    func espacos() async throws {
        let servidor = ServidorDeEscala([.success(publicada())])
        let vm = try modelo(servidor)
        preenchido(vm)
        vm.nome = "  Formatura de Direito \n"
        vm.responsavelLocal = " Marina  "

        await vm.publicar()

        let escala = try #require(await servidor.recebidas.first)
        #expect(escala.evento.nome == "Formatura de Direito")
        #expect(escala.vagas.allSatisfy { $0.responsavelLocal == "Marina" })
    }

    @Test("Publicada, a tela não publica de novo")
    func naoRepete() async throws {
        let servidor = ServidorDeEscala([.success(publicada()), .success(publicada())])
        let vm = try modelo(servidor)
        preenchido(vm)

        await vm.publicar()
        await vm.publicar()

        #expect(await servidor.chamadas == 1)
    }

    // MARK: Erro de rede

    @Test("Sem rede: não se sabe se chegou. Os campos travam e o Tentar de novo manda a mesma escala, com a mesma chave, sem repetir vagas")
    func semRede() async throws {
        let servidor = ServidorDeEscala([.failure(ErroDaApi(codigo: .semRede)), .success(publicada())])
        let vm = try modelo(servidor)
        preenchido(vm)

        await vm.publicar()

        #expect(vm.resultado == nil)
        #expect(vm.tentativaIncerta != nil)
        #expect(vm.camposBloqueados)
        #expect(vm.erros.geral == TextosDaEscala.Erro.incerta)
        // Travado: mexer no formulário não muda a escala que espera.
        vm.nome = "Outro nome"
        vm.atualizar(vm.vagas[0].id) { $0.valorTexto = "1" }
        vm.adicionarVaga()
        #expect(vm.vagas.count == 2 && vm.vagas[0].valorCentavos == 16_000)
        #expect(vm.erros.geral == TextosDaEscala.Erro.incerta)

        await vm.publicar()

        let enviadas = await servidor.recebidas
        #expect(enviadas.count == 2)
        #expect(enviadas[0].chave == enviadas[1].chave)
        #expect(enviadas[0] == enviadas[1])
        #expect(vm.resultado != nil && vm.tentativaIncerta == nil)
    }

    @Test("Prazo vencido sem resposta vale o mesmo que sem rede: a chamada em voo é cortada e a escala fica guardada")
    func prazoVencido() async throws {
        let vm = PublicarEscalaViewModel(
            estabelecimento: try estabelecimento(), funcoes: [garcom, bartender], agora: { agora }, prazo: .milliseconds(50),
            publicar: { _ in
                try await Task.sleep(for: .seconds(30))
                return publicada()
            }
        )
        preenchido(vm)

        await vm.publicar()

        #expect(vm.resultado == nil)
        #expect(vm.tentativaIncerta != nil)
        #expect(vm.enviando == false)
        #expect(vm.erros.geral == TextosDaEscala.Erro.incerta)
    }

    @Test("Resposta que não dá para ler também pode ter gravado: fica guardada, como o sem rede")
    func respostaIlegivel() async throws {
        let servidor = ServidorDeEscala([.failure(ErroDaApi(codigo: .respostaInvalida))])
        let vm = try modelo(servidor)
        preenchido(vm)

        await vm.publicar()

        #expect(vm.tentativaIncerta != nil)
        #expect(vm.erros.geral == TextosDaEscala.Erro.incerta)
    }

    @Test("Erro que não é do ErroDaApi (a rede crua) também guarda a escala")
    func erroCru() async throws {
        let servidor = ServidorDeEscala([.failure(URLError(.networkConnectionLost))])
        let vm = try modelo(servidor)
        preenchido(vm)

        await vm.publicar()

        #expect(vm.tentativaIncerta != nil)
    }

    // MARK: 4xx do servidor

    @Test("4xx do servidor: nada foi publicado, o texto é o do código, e o caminho do campo marca o campo certo", arguments: recusasDoServidor)
    func recusaDoServidor(recusa: RecusaDaEscala) async throws {
        let servidor = ServidorDeEscala([.failure(recusa.erro)])
        let vm = try modelo(servidor)
        preenchido(vm)

        await vm.publicar()

        #expect(vm.resultado == nil)
        // Recusa é definitiva: não fica tentativa guardada, os campos seguem editáveis e a mensagem diz que nada saiu.
        #expect(vm.tentativaIncerta == nil)
        #expect(vm.camposBloqueados == false)
        #expect(vm.erros.geral == recusa.mensagemGeral)
        if let campo = recusa.evento {
            #expect(vm.erros.evento[campo] != nil)
        } else {
            #expect(vm.erros.evento.isEmpty)
        }
        if let (indice, campo) = recusa.vaga {
            let marcas = try #require(vm.erros.vagas[vm.vagas[indice].id])
            #expect(marcas[campo] != nil)
            #expect(marcas.count == 1)
            #expect(vm.erros.vagas.count == 1)
        } else {
            #expect(vm.erros.vagas.isEmpty)
        }
    }

    @Test("Depois de uma recusa a pessoa corrige e publica: a segunda tentativa leva uma chave nova e dá certo")
    func recusaECorrecao() async throws {
        let servidor = ServidorDeEscala([
            .failure(ErroDaApi(codigo: .campoInvalido, detalhes: "evento.nome")), .success(publicada()),
        ])
        let vm = try modelo(servidor)
        preenchido(vm)

        await vm.publicar()
        #expect(vm.erros.evento[.nome] != nil)
        vm.nome = "Formatura de Medicina"
        await vm.publicar()

        let enviadas = await servidor.recebidas
        #expect(enviadas.count == 2)
        #expect(enviadas[1].evento.nome == "Formatura de Medicina")
        #expect(enviadas[0].chave != enviadas[1].chave)
        #expect(vm.resultado != nil)
    }

    @Test("O caminho do campo vira índice e nome: vagas[2].valor_centavos, vagas[1], vagas, evento.nome")
    func caminhos() {
        #expect(PublicarEscalaViewModel.vaga(deCaminho: "vagas[2].valor_centavos")?.0 == 2)
        #expect(PublicarEscalaViewModel.vaga(deCaminho: "vagas[2].valor_centavos")?.1 == "valor_centavos")
        #expect(PublicarEscalaViewModel.vaga(deCaminho: "vagas[1]")?.0 == 1)
        #expect(PublicarEscalaViewModel.vaga(deCaminho: "vagas[1]")?.1 == nil)
        #expect(PublicarEscalaViewModel.vaga(deCaminho: "vagas") == nil)
        #expect(PublicarEscalaViewModel.vaga(deCaminho: "evento.nome") == nil)
        #expect(PublicarEscalaViewModel.vaga(deCaminho: "vagas[x].posicoes") == nil)
        #expect(PublicarEscalaViewModel.vaga(deCaminho: nil) == nil)
    }

    // MARK: Funções

    @Test("As funções vêm do servidor com prazo; se falham, a tela diz e dá para tentar de novo")
    func funcoes() async throws {
        let falhando = PublicarEscalaViewModel(
            estabelecimento: try estabelecimento(), agora: { agora }, prazo: .milliseconds(50),
            carregar: { throw ErroDaApi(codigo: .semRede) }, publicar: { _ in publicada() }
        )
        await falhando.carregarFuncoes()
        #expect(falhando.funcoes.isEmpty && falhando.funcoesIndisponiveis && falhando.carregandoFuncoes == false)

        let lento = PublicarEscalaViewModel(
            estabelecimento: try estabelecimento(), agora: { agora }, prazo: .milliseconds(50),
            carregar: { try await Task.sleep(for: .seconds(30)); return [garcom] }, publicar: { _ in publicada() }
        )
        await lento.carregarFuncoes()
        #expect(lento.funcoes.isEmpty && lento.funcoesIndisponiveis && lento.carregandoFuncoes == false)

        let funcionando = PublicarEscalaViewModel(
            estabelecimento: try estabelecimento(), agora: { agora },
            carregar: { [garcom, bartender] }, publicar: { _ in publicada() }
        )
        await funcionando.carregarFuncoes()
        #expect(funcionando.funcoes.map(\.nome) == ["Garçom", "Bartender"] && !funcionando.funcoesIndisponiveis)
    }

    // MARK: Contra o dublê em memória (o servidor de mentira que segue o contrato)

    @Test("Tudo ou nada: se a segunda vaga é recusada pelo servidor, nenhuma vaga é publicada, e a recusa marca a vaga certa")
    func tudoOuNada() async throws {
        let api = ApiClienteEmMemoria(cenario: .contratante)
        let casa = try await api.meuEstabelecimento(id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!)
        let catalogo = try await api.funcoes()
        let primeira = try #require(catalogo.first)
        // O servidor não conhece esta função: a recusa vem do item 1, depois do item 0, que está certo.
        let desconhecida = Funcao(id: UUID(), nome: "Mágico", categoria: "Palco")
        let vm = PublicarEscalaViewModel(estabelecimento: casa, funcoes: [primeira, desconhecida], publicar: { try await api.publicarEscala($0) })
        vm.nome = "Formatura de Direito"
        vm.responsavelLocal = "Marina"
        vm.atualizar(vm.vagas[0].id) { $0.funcaoID = primeira.id; $0.valorTexto = "16000" }
        vm.adicionarVaga()
        vm.atualizar(vm.vagas[1].id) { $0.funcaoID = desconhecida.id; $0.valorTexto = "18000" }
        let antes = await api.vagasCriadas

        await vm.publicar()

        #expect(await api.chamadasAPublicarEscala == 1)
        #expect(await api.vagasCriadas == antes, "nenhuma vaga entra se uma recusa")
        #expect(vm.resultado == nil)
        #expect(vm.erros.vagas[vm.vagas[1].id]?[.funcao] == TextosDaEscala.Erro.funcao)
        #expect(vm.erros.vagas[vm.vagas[0].id] == nil)
        #expect(vm.erros.geral == TextosDaEscala.Erro.temErro)
    }

    @Test("No dublê, a escala inteira entra de uma vez, e reenviar a mesma chave devolve a mesma escala, sem vagas repetidas")
    func idempotencia() async throws {
        let api = ApiClienteEmMemoria(cenario: .contratante)
        let casa = try await api.meuEstabelecimento(id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!)
        let catalogo = try await api.funcoes()
        let primeira = try #require(catalogo.first)
        let inicio = Date().addingTimeInterval(2 * 24 * 3_600)
        let item = VagaDaEscala(
            funcaoID: primeira.id, periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(5 * 3_600)),
            valor: Dinheiro(centavos: 15_000), posicoes: 3, inclusos: Inclusos(refeicao: false, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Marina"
        )
        let escala = PublicacaoEscala(
            estabelecimentoID: casa.id,
            evento: EventoDaEscala(
                nome: "Formatura de Direito", data: try #require(DataCivil.deSaoPaulo(inicio)), local: casa.endereco,
                regiaoAdministrativa: casa.regiaoAdministrativa, ponto: casa.ponto
            ),
            vagas: [item, item], chave: UUID()
        )
        let antes = await api.vagasCriadas

        let primeiraResposta = try await api.publicarEscala(escala)
        let segundaResposta = try await api.publicarEscala(escala)

        #expect(primeiraResposta == segundaResposta)
        #expect(primeiraResposta.vagas.count == 2)
        #expect(primeiraResposta.vagas.map(\.posicoes.count) == [3, 3])
        #expect(await api.vagasCriadas == antes + 2)
    }

    @Test("O dublê recusa o que o servidor recusa: quem não é da casa, 11 vagas e soma acima de 100")
    func recusasDoDuble() async throws {
        let api = ApiClienteEmMemoria(cenario: .contratante)
        let casa = try await api.meuEstabelecimento(id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!)
        let primeira = try #require(try await api.funcoes().first)
        let inicio = Date().addingTimeInterval(2 * 24 * 3_600)
        func item(posicoes: Int) throws -> VagaDaEscala {
            VagaDaEscala(
                funcaoID: primeira.id, periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(5 * 3_600)),
                valor: Dinheiro(centavos: 15_000), posicoes: posicoes,
                inclusos: Inclusos(refeicao: false, transporte: false, exigeMaterialProprio: false), responsavelLocal: "Marina"
            )
        }
        func escala(casaID: UUID, vagas: [VagaDaEscala]) throws -> PublicacaoEscala {
            PublicacaoEscala(
                estabelecimentoID: casaID,
                evento: EventoDaEscala(
                    nome: "Formatura", data: try #require(DataCivil.deSaoPaulo(inicio)), local: casa.endereco,
                    regiaoAdministrativa: casa.regiaoAdministrativa, ponto: casa.ponto
                ),
                vagas: vagas, chave: UUID()
            )
        }
        func recusa(_ pedido: PublicacaoEscala) async -> ErroDaApi? {
            do { _ = try await api.publicarEscala(pedido); return nil } catch { return error as? ErroDaApi }
        }

        #expect(await recusa(try escala(casaID: UUID(), vagas: [try item(posicoes: 1)]))?.codigo == .semPermissao)
        let onze = try escala(casaID: casa.id, vagas: try (0..<11).map { _ in try item(posicoes: 1) })
        #expect(await recusa(onze)?.codigo == .campoInvalido)
        #expect(await recusa(onze)?.detalhes == "vagas")
        let soma = try escala(casaID: casa.id, vagas: [try item(posicoes: 60), try item(posicoes: 41)])
        #expect(await recusa(soma)?.detalhes == "posicoes")
        let vazia = try escala(casaID: casa.id, vagas: [])
        #expect(await recusa(vazia)?.detalhes == "vagas")
    }
}
