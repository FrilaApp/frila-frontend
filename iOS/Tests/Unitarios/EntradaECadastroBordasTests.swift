import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

private struct ErroQualquer: Error {}

/// Dublê que falha onde o teste manda e espia o cadastro enviado.
private final class ApiDeEntrada: ApiClienteEncaminhador, @unchecked Sendable {
    var erroAoSolicitar: Error?
    var erroAoVerificar: Error?
    var erroAoCriar: Error?
    var erroNaConta: Error?
    private(set) var cadastroEnviado: CadastroConta?

    /// Primeiro acesso: o dublê em memória aceita o cadastro (no cenário padrão a conta já existe).
    init() {
        super.init(base: ApiClienteEmMemoria(cenario: .primeiroAcesso))
    }

    override func solicitarCodigo(email: String) async throws {
        if let erroAoSolicitar { throw erroAoSolicitar }
        try await super.solicitarCodigo(email: email)
    }

    override func verificarCodigo(email: String, codigo: String) async throws {
        if let erroAoVerificar { throw erroAoVerificar }
        try await super.verificarCodigo(email: email, codigo: codigo)
    }

    override func criarConta(_ cadastro: CadastroConta) async throws -> Conta {
        cadastroEnviado = cadastro
        if let erroAoCriar { throw erroAoCriar }
        return try await super.criarConta(cadastro)
    }

    override func minhaConta() async throws -> Conta {
        if let erroNaConta { throw erroNaConta }
        return try await super.minhaConta()
    }
}

private struct RelogioFixo: Relogio {
    let agora: Date
}

/// As bordas da entrada e do cadastro que `AutenticacaoTests` não exercita: validação de cada campo
/// pessoal, normalização do telefone e da data, erros que não são `ErroDaApi` e os destinos que
/// não são o profissional.
@MainActor
@Suite("Entrada e cadastro: validação dos dados pessoais, normalização e erros")
struct EntradaECadastroBordasTests {
    // 03/10/2026 em São Paulo.
    private let agora = Date(timeIntervalSince1970: 1_791_000_000)

    private func cadastroPreenchido(_ api: any ApiCliente) -> CadastroViewModel {
        let vm = CadastroViewModel(api: api, email: "novo@frila.app", relogio: RelogioFixo(agora: agora))
        vm.nome = "Beatriz Souza"
        vm.telefone = "(61) 98888-7777"
        vm.nascimentoTexto = "12/04/1998"
        vm.maiorDeIdade = true
        vm.aceitouTermos = true
        return vm
    }

    // MARK: Entrada

    @Test("Entrada: erro da API ao pedir o código vira a mensagem do erro, e erro desconhecido a mensagem genérica")
    func entradaComErros() async {
        let api = ApiDeEntrada()
        let vm = EntradaViewModel(api: api, emailInicial: "ana@frila.app")

        api.erroAoSolicitar = ErroDaApi(codigo: .limiteExcedido)
        #expect(await vm.solicitarCodigo() == false)
        #expect(vm.erro == MensagemDoErroAPI.texto(ErroDaApi(codigo: .limiteExcedido)))

        api.erroAoSolicitar = ErroQualquer()
        #expect(await vm.solicitarCodigo() == false)
        #expect(vm.erro == "Não foi possível enviar o código. Tente novamente.")
    }

    // MARK: Código

    @Test("Código: reenviar com erro da API ou desconhecido mostra o erro e não reinicia o temporizador")
    func reenvioComErro() async {
        let api = ApiDeEntrada()
        let vm = CodigoViewModel(api: api, email: "ana@frila.app")
        vm.segundosRestantes = 0

        api.erroAoSolicitar = ErroDaApi(codigo: .limiteExcedido)
        await vm.reenviarCodigo()
        #expect(vm.erro == MensagemDoErroAPI.texto(ErroDaApi(codigo: .limiteExcedido)))
        #expect(vm.segundosRestantes == 0)
        #expect(vm.mensagemInformativa == nil)

        api.erroAoSolicitar = ErroQualquer()
        await vm.reenviarCodigo()
        #expect(vm.erro == "Não foi possível reenviar o código. Tente novamente.")
    }

    @Test("Código: sem os 6 dígitos não chama a API e pede os números")
    func codigoIncompleto() async {
        let api = ApiDeEntrada()
        api.erroAoVerificar = ErroQualquer()
        let vm = CodigoViewModel(api: api, email: "ana@frila.app")
        vm.codigo = "123"

        #expect(await vm.confirmarCodigo() == nil)
        #expect(vm.erro == "Digite os 6 números do código.")
    }

    @Test("Código: 404 na verificação é código incorreto; erro desconhecido é a mensagem genérica")
    func verificacaoComErros() async {
        let api = ApiDeEntrada()
        let vm = CodigoViewModel(api: api, email: "ana@frila.app")
        vm.codigo = "123456"

        api.erroAoVerificar = ErroDaApi(codigo: .naoEncontrado)
        #expect(await vm.confirmarCodigo() == nil)
        #expect(vm.erro == "Código incorreto. Confira os números e tente novamente.")

        api.erroAoVerificar = ErroDaApi(codigo: .limiteExcedido)
        #expect(await vm.confirmarCodigo() == nil)
        #expect(vm.erro == MensagemDoErroAPI.texto(ErroDaApi(codigo: .limiteExcedido)))

        api.erroAoVerificar = ErroQualquer()
        #expect(await vm.confirmarCodigo() == nil)
        #expect(vm.erro == "Não foi possível confirmar o código. Tente novamente.")
    }

    @Test("Código: erro desconhecido ao avaliar a conta depois do código mostra a mensagem genérica")
    func erroDesconhecidoAoAvaliarConta() async {
        let api = ApiDeEntrada()
        api.erroNaConta = ErroQualquer()
        let vm = CodigoViewModel(api: api, email: "ana@frila.app")
        vm.codigo = "123456"

        #expect(await vm.confirmarCodigo() == nil)
        #expect(vm.erro == "Não foi possível confirmar o código. Tente novamente.")
    }

    @Test("Código: contratante vai para o início do contratante e guarda o destino; conta suspensa vai para a tela da suspensão")
    func destinosContratanteESuspensa() async throws {
        DestinoGuardado.limpar()
        let contratante = CodigoViewModel(api: ApiClienteEmMemoria(cenario: .contratante), email: "casa@frila.app")
        contratante.codigo = "123456"
        #expect(await contratante.confirmarCodigo() == .destino(.contratante))
        #expect(DestinoGuardado.obter() == .contratante)

        let api = ApiClienteEmMemoria(cenario: .contaSuspensa)
        let suspensa = CodigoViewModel(api: api, email: "suspensa@frila.app")
        suspensa.codigo = "123456"
        let situacao = try await api.situacaoDaConta()
        #expect(await suspensa.confirmarCodigo() == .destino(.contaSuspensa(situacao)))
        DestinoGuardado.limpar()
    }

    // MARK: Cadastro: validação campo a campo

    @Test("Cadastro: nome com menos de 2 letras, telefone sem DDD e data fora do formato são recusados antes da API")
    func validacaoDosCampos() async {
        let api = ApiDeEntrada()
        api.erroAoCriar = ErroQualquer()

        let semNome = cadastroPreenchido(api)
        semNome.nome = " B "
        #expect(await semNome.criarConta() == nil)
        #expect(semNome.erro == "Informe seu nome completo.")

        let semDDD = cadastroPreenchido(api)
        semDDD.telefone = "98888-777"
        #expect(await semDDD.criarConta() == nil)
        #expect(semDDD.erro == "Informe um telefone válido com DDD.")

        let dataErrada = cadastroPreenchido(api)
        dataErrada.nascimentoTexto = "12.04.1998"
        #expect(await dataErrada.criarConta() == nil)
        #expect(dataErrada.erro == "Informe a data de nascimento no formato dd/mm/aaaa.")

        let diaInexistente = cadastroPreenchido(api)
        diaInexistente.nascimentoTexto = "31/02/1998"
        #expect(await diaInexistente.criarConta() == nil)
        #expect(diaInexistente.erro == "Informe a data de nascimento no formato dd/mm/aaaa.")

        #expect(api.cadastroEnviado == nil)
    }

    @Test("Cadastro: o telefone vai em E.164 — DDD brasileiro ganha +55; com + ou com o 55 na frente fica como veio",
          arguments: [
              ("(61) 98888-7777", "+5561988887777"),
              ("6133334444", "+556133334444"),
              ("+351 912 345 678", "+351912345678"),
              ("55 61 98888 7777", "+5561988887777"),
          ])
    func normalizacaoDoTelefone(digitado: String, esperado: String) async throws {
        let api = ApiDeEntrada()
        let vm = cadastroPreenchido(api)
        vm.telefone = digitado

        #expect(await vm.criarConta() != nil)
        #expect(try #require(api.cadastroEnviado).telefone == esperado)
    }

    @Test("Cadastro: a data de nascimento aceita dd/mm/aaaa e aaaa-mm-dd, e vai ao contrato como aaaa-mm-dd")
    func normalizacaoDaData() async throws {
        let api = ApiDeEntrada()
        let barra = cadastroPreenchido(api)
        barra.nascimentoTexto = " 12/04/1998 "
        #expect(await barra.criarConta() != nil)
        #expect(try #require(api.cadastroEnviado).nascimento.contrato == "1998-04-12")

        // Dublê novo: no anterior a conta já existe depois do primeiro cadastro.
        let apiTraco = ApiDeEntrada()
        let traco = cadastroPreenchido(apiTraco)
        traco.nascimentoTexto = "1998-04-12"
        #expect(await traco.criarConta() != nil)
        #expect(try #require(apiTraco.cadastroEnviado).nascimento.contrato == "1998-04-12")
    }

    @Test("Cadastro: erro da API que não é de idade nem de conta existente mostra a mensagem do erro; erro desconhecido a genérica")
    func errosDaCriacao() async {
        let api = ApiDeEntrada()

        api.erroAoCriar = ErroDaApi(codigo: .semRede)
        let semRede = cadastroPreenchido(api)
        #expect(await semRede.criarConta() == nil)
        #expect(semRede.erro == MensagemDoErroAPI.texto(ErroDaApi(codigo: .semRede)))

        api.erroAoCriar = ErroQualquer()
        let desconhecido = cadastroPreenchido(api)
        #expect(await desconhecido.criarConta() == nil)
        #expect(desconhecido.erro == "Não foi possível criar sua conta. Tente novamente.")
        #expect(!desconhecido.carregando)
    }
}
