import Foundation
import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

@MainActor
struct AutenticacaoTests {

    // MARK: - EntradaViewModel

    @Test("EntradaViewModel valida formatos de e-mail")
    func validacaoDeEmail() {
        let api = ApiClienteEmMemoria()
        let vm = EntradaViewModel(api: api)

        vm.email = ""
        #expect(!vm.emailValido)

        vm.email = "invalido"
        #expect(!vm.emailValido)

        vm.email = "semdominio@"
        #expect(!vm.emailValido)

        vm.email = "usuario@frila"
        #expect(!vm.emailValido)

        vm.email = "usuario@frila.app"
        #expect(vm.emailValido)

        vm.email = "   usuario@frila.app   "
        #expect(vm.emailValido)
    }

    @Test("EntradaViewModel solicita código para e-mail comum")
    func solicitacaoDeCodigoSucesso() async {
        let api = ApiClienteEmMemoria()
        let vm = EntradaViewModel(api: api, emailInicial: "lucas@exemplo.com")

        let sucesso = await vm.solicitarCodigo()
        #expect(sucesso)
        #expect(vm.erro == nil)
    }

    @Test("EntradaViewModel reconhece e-mail de demonstração sem falha de rede")
    func solicitacaoDemonstracao() async {
        let api = ApiClienteEmMemoria(cenario: .semRede)
        let vm = EntradaViewModel(api: api, emailInicial: "revisao-profissional@frila.app")

        let sucesso = await vm.solicitarCodigo()
        #expect(sucesso)
        #expect(vm.erro == nil)
    }

    @Test("EntradaViewModel reporta erro com e-mail inválido")
    func solicitacaoEmailInvalido() async {
        let api = ApiClienteEmMemoria()
        let vm = EntradaViewModel(api: api, emailInicial: "invalido")

        let sucesso = await vm.solicitarCodigo()
        #expect(!sucesso)
        #expect(vm.erro == "Informe um e-mail válido.")
    }

    // MARK: - CodigoViewModel

    @Test("CodigoViewModel limita código a 6 dígitos numéricos")
    func limiteDeDigitos() {
        let api = ApiClienteEmMemoria()
        let vm = CodigoViewModel(api: api, email: "teste@frila.app")

        vm.codigo = "12ab34cd5678"
        #expect(vm.codigo == "123456")
        #expect(vm.codigoValido)
    }

    @Test("CodigoViewModel formata leitura do VoiceOver dígito a dígito")
    func leituraVoiceOverDigitoADigito() {
        let api = ApiClienteEmMemoria()
        let vm = CodigoViewModel(api: api, email: "teste@frila.app")

        vm.codigo = ""
        #expect(vm.textoAcessibilidadeCodigo == "Vazio")

        vm.codigo = "123456"
        #expect(vm.textoAcessibilidadeCodigo == "1, 2, 3, 4, 5, 6")
    }

    @Test("CodigoViewModel rejeita código errado com mensagem amigável")
    func codigoErrado() async {
        let api = ApiClienteEmMemoria(cenario: .codigoErrado)
        let vm = CodigoViewModel(api: api, email: "teste@frila.app")
        vm.codigo = "000000"

        let destino = await vm.confirmarCodigo()
        #expect(destino == nil)
        #expect(vm.erro == "Código incorreto. Confira os números e tente novamente.")
    }

    @Test("CodigoViewModel rejeita código expirado com mensagem própria")
    func codigoExpirado() async {
        let api = ApiClienteEmMemoria(cenario: .codigoExpirado)
        let vm = CodigoViewModel(api: api, email: "teste@frila.app")
        vm.codigo = "999999"

        let destino = await vm.confirmarCodigo()
        #expect(destino == nil)
        #expect(vm.erro == "Código expirado. Peça um novo código para continuar.")
    }

    @Test("CodigoViewModel: usuário novo (primeiro acesso) é direcionado para cadastro")
    func primeiroAcessoVaiParaCadastro() async {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let vm = CodigoViewModel(api: api, email: "novo@frila.app")
        vm.codigo = "123456"

        let destino = await vm.confirmarCodigo()
        #expect(destino == .cadastro(email: "novo@frila.app"))
    }

    @Test("CodigoViewModel: usuário com conta existente pula o cadastro")
    func contaExistentePulaCadastro() async {
        let api = ApiClienteEmMemoria(cenario: .sucesso)
        let vm = CodigoViewModel(api: api, email: "existente@frila.app")
        vm.codigo = "123456"

        let destino = await vm.confirmarCodigo()
        if case let .destino(.profissional(conta)) = destino {
            #expect(conta.nome == "Ana Cunha")
        } else {
            Issue.record("Esperava destino .profissional com a conta carregada, obteve \(String(describing: destino))")
        }
    }

    @Test("CodigoViewModel: conta existente sem perfil profissional vai para Funções e horários")
    func contaSemPerfilProfissionalVaiParaFuncoesEHorarios() async {
        let api = ApiClienteEmMemoria(cenario: .semPerfilProfissional)
        let vm = CodigoViewModel(api: api, email: "semperfil@frila.app")
        vm.codigo = "123456"

        let destino = await vm.confirmarCodigo()
        if case let .destino(.funcoesEHorarios(conta)) = destino {
            #expect(conta.perfil == .profissional)
        } else {
            Issue.record("Esperava destino .funcoesEHorarios, obteve \(String(describing: destino))")
        }
    }

    @Test("CodigoViewModel: reenvio reinicia o temporizador e exibe confirmação")
    func reenviarCodigoReiniciaTemporizador() async {
        let api = ApiClienteEmMemoria()
        let vm = CodigoViewModel(api: api, email: "teste@frila.app")
        vm.segundosRestantes = 0
        #expect(vm.podeReenviar)

        await vm.reenviarCodigo()
        #expect(vm.segundosRestantes == 60)
        #expect(vm.mensagemInformativa == "Novo código enviado para seu e-mail.")
    }

    // MARK: - CadastroViewModel

    @Test("CadastroViewModel bloqueia submissão sem aceite dos termos")
    func termosSaoObrigatorios() async throws {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let vm = CadastroViewModel(api: api, email: "novo@frila.app")

        vm.nome = "Maria Oliveira"
        vm.telefone = "61999998888"
        vm.nascimentoTexto = "15/05/1995"
        vm.maiorDeIdade = true
        vm.aceitouTermos = false

        #expect(!vm.formularioPreenchido)
        let destino = await vm.criarConta()
        #expect(destino == nil)
        #expect(vm.erro == "É necessário aceitar os Termos de uso e a Política de privacidade para continuar.")
    }

    @Test("CadastroViewModel recusa menor de idade no cliente e não chama a API")
    func menorDeIdadeRecusaNoCliente() async throws {
        let relogioFixo = try RelogioFixo(agora: #require(ISO8601DateFormatter().date(from: "2026-10-01T12:00:00Z")))
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso, relogio: relogioFixo)
        let vm = CadastroViewModel(api: api, email: "jovem@frila.app", relogio: relogioFixo)

        vm.nome = "Menor de Idade"
        vm.telefone = "61999998888"
        // 17 anos em 01/10/2026
        vm.nascimentoTexto = "02/10/2008"
        vm.maiorDeIdade = true
        vm.aceitouTermos = true

        let destino = await vm.criarConta()
        #expect(destino == nil)
        #expect(vm.erro == "O Frila é exclusivo para maiores de 18 anos.")
    }

    @Test("CadastroViewModel trata erro 422 menor_de_idade da API")
    func menorDeIdadeTrataErroDaAPI() async throws {
        let api = ApiClienteEmMemoria(cenario: .menorDeIdade)
        let vm = CadastroViewModel(api: api, email: "jovem@frila.app")

        vm.nome = "Menor de Idade"
        vm.telefone = "61999998888"
        vm.nascimentoTexto = "01/01/1990"
        vm.maiorDeIdade = true
        vm.aceitouTermos = true

        let destino = await vm.criarConta()
        #expect(destino == nil)
        #expect(vm.erro == "O Frila é exclusivo para maiores de 18 anos.")
    }

    @Test("CadastroViewModel trata erro 409 conta_existente da API")
    func contaExistenteTrataErroDaAPI() async throws {
        let api = ApiClienteEmMemoria(cenario: .contaExistente)
        let vm = CadastroViewModel(api: api, email: "jaexiste@frila.app")

        vm.nome = "Conta Repetida"
        vm.telefone = "61999998888"
        vm.nascimentoTexto = "01/01/1990"
        vm.maiorDeIdade = true
        vm.aceitouTermos = true

        let destino = await vm.criarConta()
        #expect(destino == nil)
        #expect(vm.erro == "Esta conta já foi cadastrada.")
    }

    @Test("CadastroViewModel cria conta profissional e vai para Funções e horários")
    func criarContaProfissionalComSucesso() async throws {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let vm = CadastroViewModel(api: api, email: "nova@frila.app")

        vm.perfil = .profissional
        vm.nome = "Beatriz Souza"
        vm.telefone = "(61) 98888-7777"
        vm.nascimentoTexto = "12/04/1998"
        vm.maiorDeIdade = true
        vm.aceitouTermos = true

        #expect(vm.formularioPreenchido)
        let destino = await vm.criarConta()
        if case let .funcoesEHorarios(conta) = destino {
            #expect(conta.nome == "Beatriz Souza")
            #expect(conta.perfil == .profissional)
            #expect(conta.telefone == "+5561988887777")
        } else {
            Issue.record("Esperava destino .funcoesEHorarios, obteve \(String(describing: destino))")
        }
    }

    @Test("CadastroViewModel cria conta contratante e vai para Início do contratante")
    func criarContaContratanteComSucesso() async throws {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let vm = CadastroViewModel(api: api, email: "patrao@frila.app")

        vm.perfil = .contratante
        vm.nome = "Carlos Gerente"
        vm.telefone = "61977776666"
        vm.nascimentoTexto = "20/08/1985"
        vm.maiorDeIdade = true
        vm.aceitouTermos = true

        let destino = await vm.criarConta()
        if case let .contratante(conta) = destino {
            #expect(conta.nome == "Carlos Gerente")
            #expect(conta.perfil == .contratante)
        } else {
            Issue.record("Esperava destino .contratante, obteve \(String(describing: destino))")
        }
    }
}
