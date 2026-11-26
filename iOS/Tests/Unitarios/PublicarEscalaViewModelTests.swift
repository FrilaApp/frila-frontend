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
    RecusaDaEscala(erro: ErroDaApi(codigo: .selecaoSemAntecedencia, detalhes: "vagas[1]"), mensagemGeral: TextosDaEscala.Erro.temErro, evento: nil, vaga: (1, .modo)),
    RecusaDaEscala(erro: ErroDaApi(codigo: .campoObrigatorio, detalhes: "vagas[0].responsavel_local"), mensagemGeral: TextosDaEscala.Erro.temErro, evento: nil, vaga: (0, .responsavel)),
    RecusaDaEscala(erro: ErroDaApi(codigo: .campoInvalido, detalhes: "vagas[1].modo"), mensagemGeral: TextosDaEscala.Erro.temErro, evento: nil, vaga: (1, .modo)),
    RecusaDaEscala(erro: ErroDaApi(codigo: .campoInvalido, detalhes: "vagas[0].traje"), mensagemGeral: TextosDaEscala.Erro.temErro, evento: nil, vaga: (0, .traje)),
    RecusaDaEscala(erro: ErroDaApi(codigo: .campoInvalido, detalhes: "vagas"), mensagemGeral: TextosDaEscala.Erro.quantidade, evento: nil, vaga: nil),
    RecusaDaEscala(erro: ErroDaApi(codigo: .campoInvalido, detalhes: "posicoes"), mensagemGeral: TextosDaEscala.Erro.somaDePessoas, evento: nil, vaga: nil),
    RecusaDaEscala(erro: ErroDaApi(codigo: .campoObrigatorio, detalhes: "evento.local"), mensagemGeral: TextosDaEscala.Erro.cadastroDaCasa, evento: nil, vaga: nil),
    RecusaDaEscala(erro: ErroDaApi(codigo: .campoInvalido, detalhes: "evento.ponto"), mensagemGeral: TextosDaEscala.Erro.cadastroDaCasa, evento: nil, vaga: nil),
    RecusaDaEscala(erro: ErroDaApi(codigo: .campoInvalido, detalhes: "vagas[9].valor_centavos"), mensagemGeral: TextosDaEscala.Erro.generico, evento: nil, vaga: nil),
    RecusaDaEscala(erro: ErroDaApi(codigo: .campoInvalido), mensagemGeral: TextosDaEscala.Erro.generico, evento: nil, vaga: nil),
    RecusaDaEscala(erro: ErroDaApi(codigo: .funcaoIncompativel, detalhes: "vagas[1]"), mensagemGeral: TextosDaEscala.Erro.temErro, evento: nil, vaga: (1, .funcao)),
    RecusaDaEscala(erro: ErroDaApi(codigo: .naoEncontrado), mensagemGeral: TextosDaEscala.Erro.generico, evento: nil, vaga: nil),
    RecusaDaEscala(erro: ErroDaApi(codigo: .semPermissao), mensagemGeral: TextosDaEscala.Erro.semPermissao, evento: nil, vaga: nil),
    RecusaDaEscala(erro: ErroDaApi(codigo: .semPermissao, detalhes: "conta_suspensa"), mensagemGeral: TextosDaEscala.Erro.contaSuspensa, evento: nil, vaga: nil),
    RecusaDaEscala(erro: ErroDaApi(codigo: .perfilIncompativel), mensagemGeral: TextosDaEscala.Erro.perfilIncompativel, evento: nil, vaga: nil),
    RecusaDaEscala(erro: ErroDaApi(codigo: .limiteExcedido), mensagemGeral: MensagemDoErroAPI.texto(ErroDaApi(codigo: .limiteExcedido)), evento: nil, vaga: nil),
    RecusaDaEscala(erro: ErroDaApi(codigo: .naoAutenticado), mensagemGeral: MensagemDoErroAPI.texto(ErroDaApi(codigo: .naoAutenticado)), evento: nil, vaga: nil),
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

    @Test("B-124: o aviso sai só fora da faixa (as bordas não avisam), só naquela vaga, e a escala é publicada com o valor digitado", arguments: [
        ("4999", "Valor muito baixo."), ("5000", nil), ("200000", nil), ("200001", "Valor muito alto, confira."),
    ] as [(String, String?)])
    func valorForaDaFaixaSoAvisa(centavos: String, aviso: String?) async throws {
        let servidor = ServidorDeEscala([.success(publicada())])
        let vm = try modelo(servidor)
        preenchido(vm)
        vm.atualizar(vm.vagas[0].id) { $0.valorTexto = centavos }

        #expect(vm.vagas[0].avisoDoValor == aviso)
        #expect(vm.vagas[1].avisoDoValor == nil)
        #expect(!vm.camposBloqueados)
        #expect(!vm.enviando, "o botão Publicar só fica desligado durante o envio")

        await vm.publicar()

        #expect(await servidor.recebidas.map { $0.vagas.first?.valor.centavos } == [Int(centavos)])
        #expect(vm.erros.vazio)
        #expect(vm.resultado != nil)
    }

    @Test("B-124: zero não ganha aviso novo; a regra do valor obrigatório continua, e nada vai ao servidor")
    func valorZeroSemAvisoNovo() async throws {
        let servidor = ServidorDeEscala([.success(publicada())])
        let vm = try modelo(servidor)
        preenchido(vm)
        vm.atualizar(vm.vagas[0].id) { $0.valorTexto = "0" }

        #expect(vm.vagas[0].avisoDoValor == nil)

        await vm.publicar()

        #expect(await servidor.chamadas == 0)
        #expect(vm.erros.vagas[vm.vagas[0].id]?[.valor] == TextosDaEscala.Erro.valor)
        #expect(vm.resultado == nil)
    }

    /// O formulário preenchido: duas vagas (Garçom e Bartender) de um evento.
    private func preenchido(_ vm: PublicarEscalaViewModel) {
        vm.nome = "Formatura de Direito"
        let primeira = vm.vagas[0].id
        vm.atualizar(primeira) { $0.funcaoID = garcom.id; $0.valorTexto = "16000"; $0.pessoas = 6; $0.responsavelLocal = "Marina" }
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
        let vaga = vm.vagas[0]
        #expect(vaga.modo == .urgencia && vaga.responsavelLocal.isEmpty)
        #expect(vaga.refeicao == false && vaga.transporte == false && vaga.materialProprio == false)
        #expect(vaga.traje.isEmpty && vaga.observacoes.isEmpty)
    }

    @Test("Formulário vazio: cada campo faltante é marcado, a mensagem geral diz que nada foi publicado, e a API não é chamada")
    func vazio() async throws {
        let servidor = ServidorDeEscala([.success(publicada())])
        let vm = try modelo(servidor)

        await vm.publicar()

        #expect(vm.erros.evento[.nome] == TextosDaEscala.Erro.nome)
        let daVaga = try #require(vm.erros.vagas[vm.vagas[0].id])
        #expect(daVaga[.funcao] == TextosDaEscala.Erro.funcao)
        #expect(daVaga[.valor] == TextosDaEscala.Erro.valor)
        #expect(daVaga[.responsavel] == TextosDaEscala.Erro.responsavel)
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

    @Test("A marca de um campo de texto fica enquanto a pessoa digita (para o layout não pular debaixo do dedo) e sai na próxima tentativa; a escolha por toque limpa na hora")
    func editarLimpaOErro() async throws {
        let vm = try modelo(ServidorDeEscala([]))
        await vm.publicar()
        let id = vm.vagas[0].id
        #expect(vm.erros.evento[.nome] != nil && vm.erros.vagas[id]?[.valor] != nil)

        vm.nome = "Formatura"
        vm.atualizar(id) { $0.valorTexto = "100"; $0.responsavelLocal = "Marina" }
        #expect(vm.erros.evento[.nome] != nil, "texto: a marca fica")
        #expect(vm.erros.vagas[id]?[.valor] != nil, "texto: a marca fica")
        #expect(vm.erros.vagas[id]?[.responsavel] != nil, "texto: a marca fica")

        vm.atualizar(id) { $0.funcaoID = garcom.id }
        #expect(vm.erros.vagas[id]?[.funcao] == nil, "escolha por toque: limpa na hora")
        #expect(vm.erros.geral == TextosDaEscala.Erro.temErro, "a mensagem geral fica até a próxima tentativa: tirá-la em AX deslocaria o campo em edição")

        await vm.publicar()
        #expect(vm.erros.evento[.nome] == nil)
        #expect(vm.erros.vagas[id]?[.valor] == nil)
        #expect(vm.erros.vagas[id]?[.responsavel] == nil)
    }

    // MARK: Publicar

    @Test("Sucesso: manda o evento no endereço da casa, o dia de Brasília, as duas vagas em urgência e uma chave só; a tela mostra as vagas publicadas")
    func sucesso() async throws {
        let servidor = ServidorDeEscala([.success(publicada(vagas: 2))])
        let vm = try modelo(servidor)
        preenchido(vm)
        vm.atualizar(vm.vagas[0].id) { $0.refeicao = true; $0.traje = "Camisa preta"; $0.observacoes = "Entrada pela lateral" }

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
        #expect(escala.vagas.allSatisfy { $0.modo == .urgencia && $0.responsavelLocal == "Marina" })
        #expect(escala.vagas.map(\.inclusos.refeicao) == [true, false])
        #expect(escala.vagas.map(\.traje) == ["Camisa preta", nil])
        #expect(escala.vagas.map(\.observacoes) == ["Entrada pela lateral", nil])
        #expect(escala.vagas.allSatisfy { $0.participaRateio == nil }, "o rateio vai nulo, como na web e no Android")
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
        vm.atualizar(vm.vagas[0].id) { $0.responsavelLocal = " Marina  " }
        vm.atualizar(vm.vagas[1].id) { $0.responsavelLocal = "Marina\n" }

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

    @Test("Tudo que não é recusa definitiva é resultado incerto (um 502 ou 504 sem envelope vira .desconhecido): a escala fica guardada e o reenvio leva a MESMA chave", arguments: [CodigoErroAPI.desconhecido, .semRede, .respostaInvalida, .vagaEncerrada])
    func incertoParaQualquerErroQueNaoSejaRecusaDefinitiva(codigo: CodigoErroAPI) async throws {
        let servidor = ServidorDeEscala([.failure(ErroDaApi(codigo: codigo)), .success(publicada())])
        let vm = try modelo(servidor)
        preenchido(vm)

        await vm.publicar()

        #expect(vm.tentativaIncerta != nil)
        #expect(vm.camposBloqueados)
        #expect(vm.erros.geral == TextosDaEscala.Erro.incerta)

        await vm.publicar()

        let enviadas = await servidor.recebidas
        #expect(enviadas.count == 2)
        #expect(enviadas[0].chave == enviadas[1].chave)
        #expect(vm.resultado != nil)
    }

    @Test("No REENVIO de uma tentativa incerta, 429, 401, 403 e perfil NÃO soltam a chave (o servidor confere permissão e limite antes da chave): mostram a mensagem e o próximo envio reusa a mesma", arguments: [
        ErroDaApi(codigo: .limiteExcedido), ErroDaApi(codigo: .naoAutenticado), ErroDaApi(codigo: .semPermissao),
        ErroDaApi(codigo: .semPermissao, detalhes: "conta_suspensa"), ErroDaApi(codigo: .contaSuspensa), ErroDaApi(codigo: .perfilIncompativel),
        ErroDaApi(codigo: .naoEncontrado),
    ])
    func reenvioRecusadoPeloQueNaoEDoConteudoMantemAChave(recusa: ErroDaApi) async throws {
        let servidor = ServidorDeEscala([.failure(ErroDaApi(codigo: .semRede)), .failure(recusa), .success(publicada())])
        let vm = try modelo(servidor)
        preenchido(vm)

        await vm.publicar() // sem rede: incerta
        await vm.publicar() // o reenvio é recusado por permissão, limite ou sessão
        #expect(vm.tentativaIncerta != nil, "a chave segue guardada: nada prova que a primeira tentativa não gravou")
        #expect(vm.camposBloqueados, "os campos seguem travados: a escala pendente é a mesma")
        #expect(vm.erros.geral != nil && vm.erros.geral != TextosDaEscala.Erro.incerta, "mostra a mensagem da recusa")

        await vm.publicar()
        let enviadas = await servidor.recebidas
        #expect(enviadas.count == 3)
        #expect(enviadas[0].chave == enviadas[1].chave && enviadas[1].chave == enviadas[2].chave, "os três envios levam a MESMA chave")
        #expect(vm.resultado != nil)
    }

    @Test("No reenvio, a recusa do CONTEÚDO (campo, horário, seleção, função) prova que nada foi gravado: solta a chave, destrava os campos e o próximo envio leva chave nova", arguments: [
        ErroDaApi(codigo: .campoInvalido, detalhes: "evento.nome"), ErroDaApi(codigo: .campoObrigatorio, detalhes: "vagas[0].responsavel_local"),
        ErroDaApi(codigo: .horarioInvalido, detalhes: "vagas[0]"), ErroDaApi(codigo: .selecaoSemAntecedencia, detalhes: "vagas[1]"),
        ErroDaApi(codigo: .funcaoIncompativel, detalhes: "vagas[1]"),
    ])
    func reenvioRecusadoPeloConteudoSoltaAChave(recusa: ErroDaApi) async throws {
        let servidor = ServidorDeEscala([.failure(ErroDaApi(codigo: .semRede)), .failure(recusa), .success(publicada())])
        let vm = try modelo(servidor)
        preenchido(vm)

        await vm.publicar()
        await vm.publicar()
        #expect(vm.tentativaIncerta == nil)
        #expect(vm.camposBloqueados == false)

        vm.nome = "Formatura de Medicina"
        await vm.publicar()
        let enviadas = await servidor.recebidas
        #expect(enviadas.count == 3)
        #expect(enviadas[0].chave != enviadas[2].chave, "depois da recusa de conteúdo, a escala nova leva chave nova")
        #expect(vm.resultado != nil)
    }

    @Test("A mensagem do resultado incerto avisa para conferir em Minhas vagas se o app for fechado")
    func incertaAvisaDeFecharOApp() {
        #expect(TextosDaEscala.Erro.incerta.contains("Se fechar o app, confira em Minhas vagas antes de publicar de novo."))
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
        vm.atualizar(vm.vagas[0].id) { $0.funcaoID = primeira.id; $0.valorTexto = "16000"; $0.responsavelLocal = "Marina" }
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

    // MARK: Paridade com a vaga avulsa, a web e o Android (modo, responsável e inclusos por vaga)

    @Test("O modo é por vaga: a seleção só com o início a mais de 24 horas; antes disso a escolha é recusada no campo")
    func modoPorVaga() throws {
        let vm = try modelo(ServidorDeEscala([]))
        preenchido(vm)
        let primeira = vm.vagas[0].id
        let segunda = vm.vagas[1].id

        // O início padrão depende da hora do dia: o teste fixa os inícios a 10 h e a 48 h do relógio.
        vm.atualizar(primeira) { $0.inicio = agora.addingTimeInterval(10 * 3_600); $0.fim = agora.addingTimeInterval(14 * 3_600) }
        vm.atualizar(segunda) { $0.inicio = agora.addingTimeInterval(48 * 3_600); $0.fim = agora.addingTimeInterval(52 * 3_600) }
        #expect(vm.selecaoDisponivel(vm.vagas[0]) == false)
        #expect(vm.selecaoDisponivel(vm.vagas[1]))

        vm.escolherModo(.selecao, em: primeira)
        #expect(vm.vagas[0].modo == .urgencia)
        #expect(vm.erros.vagas[primeira]?[.modo] == TextosRepublicarVaga.selecaoSemAntecedencia)

        vm.escolherModo(.selecao, em: segunda)
        #expect(vm.vagas[1].modo == .selecao)
        #expect(vm.erros.vagas[segunda]?[.modo] == nil)
        #expect(vm.prazoDeEscolha(vm.vagas[1]) != nil)
        #expect(vm.prazoDeEscolha(vm.vagas[0]) == nil)

        // Mover o início da vaga de seleção para menos de 24 horas devolve a urgência.
        vm.atualizar(segunda) { $0.inicio = agora.addingTimeInterval(5 * 3_600) }
        #expect(vm.vagas[1].modo == .urgencia)
    }

    @Test("A seleção sai no pedido como o contrato escreve, e o servidor que a recusa por antecedência marca o modo da vaga")
    func modoNoPedido() async throws {
        let servidor = ServidorDeEscala([.success(publicada())])
        let vm = try modelo(servidor)
        preenchido(vm)
        vm.atualizar(vm.vagas[0].id) { $0.inicio = agora.addingTimeInterval(72 * 3_600); $0.fim = agora.addingTimeInterval(76 * 3_600) }
        vm.escolherModo(.selecao, em: vm.vagas[0].id)

        await vm.publicar()

        let escala = try #require(await servidor.recebidas.first)
        #expect(escala.vagas.map(\.modo) == [.selecao, .urgencia])
    }

    @Test("O responsável e os inclusos são por vaga, e a vaga nova nasce com o responsável da anterior")
    func responsavelEInclusosPorVaga() async throws {
        let servidor = ServidorDeEscala([.success(publicada())])
        let vm = try modelo(servidor)
        vm.nome = "Formatura de Direito"
        vm.atualizar(vm.vagas[0].id) {
            $0.funcaoID = garcom.id; $0.valorTexto = "16000"; $0.responsavelLocal = "Marina"
            $0.refeicao = true; $0.materialProprio = true
        }
        vm.adicionarVaga()
        #expect(vm.vagas[1].responsavelLocal == "Marina")
        #expect(vm.vagas[1].refeicao == false && vm.vagas[1].materialProprio == false, "os inclusos não herdam: cada vaga tem os seus")
        vm.atualizar(vm.vagas[1].id) {
            $0.funcaoID = bartender.id; $0.valorTexto = "18000"; $0.responsavelLocal = "João"; $0.transporte = true
        }

        await vm.publicar()

        let escala = try #require(await servidor.recebidas.first)
        #expect(escala.vagas.map(\.responsavelLocal) == ["Marina", "João"])
        #expect(escala.vagas.map(\.inclusos) == [
            Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: true),
            Inclusos(refeicao: false, transporte: true, exigeMaterialProprio: false),
        ])
    }

    @Test("Sem responsável numa vaga, só essa vaga é marcada")
    func responsavelObrigatorioPorVaga() throws {
        let vm = try modelo(ServidorDeEscala([]))
        preenchido(vm)
        vm.atualizar(vm.vagas[1].id) { $0.responsavelLocal = "  " }

        #expect(vm.validar() == false)
        #expect(vm.erros.vagas[vm.vagas[0].id] == nil)
        #expect(vm.erros.vagas[vm.vagas[1].id]?[.responsavel] == TextosDaEscala.Erro.responsavel)
    }

    // MARK: O aviso da ação (em AX5 a tela rola até ele)

    @Test("Cada tentativa que termina com mensagem sobe o contador do aviso, mesmo com a mesma mensagem")
    func avisoDaAcao() async throws {
        let servidor = ServidorDeEscala([.failure(ErroDaApi(codigo: .campoInvalido, detalhes: "vagas")), .failure(ErroDaApi(codigo: .campoInvalido, detalhes: "vagas"))])
        let vm = try modelo(servidor)

        #expect(vm.avisosDaAcao == 0)
        await vm.publicar()
        #expect(vm.avisosDaAcao == 1)
        await vm.publicar()
        #expect(vm.avisosDaAcao == 2, "o mesmo erro de novo ainda é um aviso novo")

        preenchido(vm)
        await vm.publicar()
        #expect(vm.avisosDaAcao == 3)
        await vm.publicar()
        #expect(vm.avisosDaAcao == 4)
    }
}

/// A guarda mantém a escala com resultado incerto (e a chave) quando a pessoa cancela e reabre a tela.
@MainActor
@Suite("Escala de evento: a guarda da tentativa incerta (cancelar e reabrir não troca a chave)")
struct GuardaDaEscalaTests {
    private let agora = Date(timeIntervalSince1970: 1_800_000_000)
    private let garcom = Funcao(id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!, nome: "Garçom", categoria: "Salão")

    private func modelo(_ servidor: ServidorDeEscala) -> PublicarEscalaViewModel {
        let fixo = agora
        let casa = Estabelecimento(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!, nome: "Bistrô Ipê", tipo: .foodService,
            endereco: "CLS 405, Asa Sul, Brasília - DF", regiaoAdministrativa: "Plano Piloto",
            ponto: try! Coordenada(latitude: -15.8121, longitude: -47.8997)
        )
        let vm = PublicarEscalaViewModel(estabelecimento: casa, funcoes: [garcom], agora: { fixo }, publicar: { try await servidor.publicar($0) })
        vm.nome = "Formatura de Direito"
        vm.atualizar(vm.vagas[0].id) { $0.funcaoID = garcom.id; $0.valorTexto = "16000"; $0.responsavelLocal = "Marina" }
        return vm
    }

    @Test("Com tentativa incerta, cancelar e reabrir devolve o mesmo modelo: o rascunho, o aviso e a MESMA chave; reenviar não duplica")
    func incertaSobreviveAoCancelar() async throws {
        let servidor = ServidorDeEscala([.failure(ErroDaApi(codigo: .semRede)), .success(publicada())])
        let guarda = GuardaDaEscala()
        let primeiro = guarda.obter { modelo(servidor) }
        await primeiro.publicar()
        #expect(primeiro.tentativaIncerta != nil)

        guarda.aoSair() // Cancelar
        #expect(guarda.temTentativaIncerta)
        let reaberto = guarda.obter { modelo(servidor) }

        #expect(reaberto === primeiro)
        #expect(reaberto.nome == "Formatura de Direito")
        #expect(reaberto.erros.geral == TextosDaEscala.Erro.incerta, "a tela reaberta avisa que a última tentativa pode ter publicado")
        await reaberto.publicar()
        let enviadas = await servidor.recebidas
        #expect(enviadas.count == 2)
        #expect(enviadas[0].chave == enviadas[1].chave)
        #expect(reaberto.resultado != nil)

        guarda.aoSair() // Concluiu
        #expect(guarda.temTentativaIncerta == false)
        #expect(guarda.obter { modelo(servidor) } !== reaberto, "depois do sucesso a próxima escala começa limpa")
    }

    @Test("Sem tentativa incerta, sair descarta o modelo: a próxima abertura começa limpa")
    func semIncertaDescarta() async throws {
        let servidor = ServidorDeEscala([])
        let guarda = GuardaDaEscala()
        let primeiro = guarda.obter { modelo(servidor) }
        #expect(guarda.obter { modelo(servidor) } === primeiro)

        guarda.aoSair()

        #expect(guarda.obter { modelo(servidor) } !== primeiro)
    }

    @Test("Recusa definitiva solta a chave: depois dela, cancelar descarta, e a próxima escala leva chave nova")
    func recusaDefinitivaSolta() async throws {
        let servidor = ServidorDeEscala([.failure(ErroDaApi(codigo: .campoInvalido, detalhes: "evento.nome"))])
        let guarda = GuardaDaEscala()
        let vm = guarda.obter { modelo(servidor) }

        await vm.publicar()
        #expect(vm.tentativaIncerta == nil)
        guarda.aoSair()

        #expect(guarda.obter { modelo(servidor) } !== vm)
    }
}

/// O cadastro da casa lido com prazo: a entrada da escala não fica em "carregando" para sempre.
@MainActor
@Suite("Escala de evento: leitura do cadastro da casa com prazo")
struct CadastroDaCasaDaEscalaTests {
    private let casa = Estabelecimento(
        id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!, nome: "Bistrô Ipê", tipo: .foodService,
        endereco: "CLS 405, Asa Sul, Brasília - DF", regiaoAdministrativa: "Plano Piloto",
        ponto: try! Coordenada(latitude: -15.8121, longitude: -47.8997)
    )

    @Test("Lê o cadastro e fica guardado: abrir de novo não volta à rede")
    func le() async throws {
        let chamadas = Contador()
        let modelo = CadastroDaCasaDaEscala(estabelecimentoID: casa.id) { [casa] _ in await chamadas.somar(); return casa }

        await modelo.carregar()
        await modelo.carregar()

        #expect(modelo.estado == .pronta(casa))
        #expect(await chamadas.total == 1)
    }

    @Test("Passou do prazo: erro com o texto de sem conexão, não carregando para sempre, e dá para tentar de novo")
    func prazoVencido() async throws {
        let tentativas = Contador()
        let modelo = CadastroDaCasaDaEscala(estabelecimentoID: casa.id, prazo: .milliseconds(50)) { [casa] _ in
            if await tentativas.somar() == 1 { try await Task.sleep(for: .seconds(30)) }
            return casa
        }

        await modelo.carregar()
        #expect(modelo.estado == .erro(mensagem: MensagemDoErroAPI.texto(ErroDaApi(codigo: .semRede))))

        await modelo.carregar()
        #expect(modelo.estado == .pronta(casa))
    }

    @Test("Erro do servidor vira a mensagem do código")
    func recusa() async throws {
        let modelo = CadastroDaCasaDaEscala(estabelecimentoID: casa.id) { _ in throw ErroDaApi(codigo: .semPermissao) }

        await modelo.carregar()

        #expect(modelo.estado == .erro(mensagem: MensagemDoErroAPI.texto(ErroDaApi(codigo: .semPermissao))))
    }
}

private actor Contador {
    private(set) var total = 0
    @discardableResult func somar() -> Int { total += 1; return total }
}
