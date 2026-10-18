import Foundation
import FrilaApresentacao
import FrilaDados
import FrilaDominio
import FrilaInfraestrutura
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
        #expect(destino == .destino(.profissional))
    }

    @Test("CodigoViewModel: conta existente sem perfil profissional vai para Funções e horários")
    func contaSemPerfilProfissionalVaiParaFuncoesEHorarios() async {
        let api = ApiClienteEmMemoria(cenario: .semPerfilProfissional)
        let vm = CodigoViewModel(api: api, email: "semperfil@frila.app")
        vm.codigo = "123456"

        let destino = await vm.confirmarCodigo()
        #expect(destino == .destino(.funcoesEHorarios))
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

    @Test("CodigoViewModel: iniciarTemporizador redefine contagem para 60 segundos e bloqueia reenvio")
    func iniciarTemporizadorRedefineContagemParaSessentaSegundos() {
        let api = ApiClienteEmMemoria()
        let vm = CodigoViewModel(api: api, email: "teste@frila.app")
        vm.segundosRestantes = 0
        #expect(vm.podeReenviar)

        vm.iniciarTemporizador()

        #expect(vm.segundosRestantes == 60)
        #expect(!vm.podeReenviar)
    }

    @Test("CodigoViewModel: invocações consecutivas de iniciarTemporizador cancelam tarefa anterior e mantêm estado consistente")
    func iniciarTemporizadorChamadasConsecutivas() {
        let api = ApiClienteEmMemoria()
        let vm = CodigoViewModel(api: api, email: "teste@frila.app")
        vm.segundosRestantes = 10

        vm.iniciarTemporizador()
        vm.iniciarTemporizador()

        #expect(vm.segundosRestantes == 60)
        #expect(!vm.podeReenviar)
    }

    // MARK: - CadastroViewModel

    @Test("CadastroViewModel bloqueia submissão sem aceite dos termos")
    func termosSaoObrigatorios() async throws {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let vm = CadastroViewModel(api: api, email: "novo@frila.app")

        vm.nome = "Maria Oliveira"
        vm.telefone = "61999998888"
        vm.nascimentoTexto = "15/05/1995"
        vm.aceitouTermos = false

        #expect(!vm.formularioPreenchido)
        let destino = await vm.criarConta()
        #expect(destino == nil)
        #expect(vm.erro == "É necessário aceitar os Termos de uso e a Política de privacidade para continuar.")
        #expect(await api.chamadasACriarConta == 0)
        await #expect(throws: ErroDaApi.self) {
            _ = try await api.minhaConta()
        }
    }

    @Test("CadastroViewModel bloqueia submissão quando data é de menor de idade e não chama a API")
    func dataMenorDeIdadeBloqueiaSubmissaoENaoChamaAPI() async throws {
        let relogioFixo = try RelogioFixo(agora: #require(ISO8601DateFormatter().date(from: "2026-10-01T12:00:00Z")))
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso, relogio: relogioFixo)
        let vm = CadastroViewModel(api: api, email: "novo@frila.app", relogio: relogioFixo)

        vm.nome = "Maria Oliveira"
        vm.telefone = "61999998888"
        // 17 anos em 01/10/2026
        vm.nascimentoTexto = "15/10/2008"
        vm.aceitouTermos = true

        #expect(vm.ehMenorDeIdade)
        #expect(!vm.formularioPreenchido)
        let destino = await vm.criarConta()
        #expect(destino == nil)
        #expect(vm.erro == "O Frila é exclusivo para maiores de 18 anos.")
        #expect(await api.chamadasACriarConta == 0)
        await #expect(throws: ErroDaApi.self) {
            _ = try await api.minhaConta()
        }
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
        vm.aceitouTermos = true

        let destino = await vm.criarConta()
        #expect(destino == nil)
        #expect(vm.erro == "O Frila é exclusivo para maiores de 18 anos.")
        #expect(await api.chamadasACriarConta == 0)
        await #expect(throws: ErroDaApi.self) {
            _ = try await api.minhaConta()
        }
    }

    @Test("CadastroViewModel trata erro 422 menor_de_idade da API")
    func menorDeIdadeTrataErroDaAPI() async throws {
        let api = ApiClienteEmMemoria(cenario: .menorDeIdade)
        let vm = CadastroViewModel(api: api, email: "jovem@frila.app")

        vm.nome = "Menor de Idade"
        vm.telefone = "61999998888"
        vm.nascimentoTexto = "01/01/1990"
        vm.aceitouTermos = true

        let destino = await vm.criarConta()
        #expect(destino == nil)
        #expect(vm.erro == "O Frila é exclusivo para maiores de 18 anos.")
    }

    // MARK: - Declared Age Range (cartão #215, RN20)

    @Test("CadastroViewModel com Declared Age Range abaixo de 18 recusa no cliente e não chama a API")
    func cadastroComDeclaredAgeRangeAbaixoDe18RecusaENaoChamaAPI() async throws {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let verificador = VerificadorDeIdadeSimulado(resultado: .abaixoDe18)
        let vm = CadastroViewModel(api: api, email: "jovem@frila.app", verificadorDeIdade: verificador)

        vm.nome = "Candidato Jovem"
        vm.telefone = "61999998888"
        vm.nascimentoTexto = "15/05/1995"
        vm.aceitouTermos = true

        let destino = await vm.criarConta()
        #expect(destino == nil)
        #expect(vm.erro == "O Frila é exclusivo para maiores de 18 anos.")
        #expect(verificador.chamadasAVerificar == 1)
        #expect(await api.chamadasACriarConta == 0)
        await #expect(throws: ErroDaApi.self) {
            _ = try await api.minhaConta()
        }
    }

    @Test("CadastroViewModel com Declared Age Range 18 ou mais segue e chama a API")
    func cadastroComDeclaredAgeRangeDezoitoOuMaisSegueEChamaAPI() async throws {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let verificador = VerificadorDeIdadeSimulado(resultado: .dezoitoOuMais)
        let vm = CadastroViewModel(api: api, email: "adulto@frila.app", verificadorDeIdade: verificador)

        vm.nome = "Candidato Adulto"
        vm.telefone = "61999998888"
        vm.nascimentoTexto = "15/05/1995"
        vm.aceitouTermos = true

        let destino = await vm.criarConta()
        #expect(destino == .funcoesEHorarios)
        #expect(vm.erro == nil)
        #expect(verificador.chamadasAVerificar == 1)
        #expect(await api.chamadasACriarConta == 1)
    }

    @Test("CadastroViewModel com Declared Age Range recusado pela pessoa segue só com a data e chama a API")
    func cadastroComDeclaredAgeRangeRecusadoSegueEChamaAPI() async throws {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let verificador = VerificadorDeIdadeSimulado(resultado: .recusou)
        let vm = CadastroViewModel(api: api, email: "recusou@frila.app", verificadorDeIdade: verificador)

        vm.nome = "Candidato Privativo"
        vm.telefone = "61999998888"
        vm.nascimentoTexto = "15/05/1995"
        vm.aceitouTermos = true

        let destino = await vm.criarConta()
        #expect(destino == .funcoesEHorarios)
        #expect(vm.erro == nil)
        #expect(verificador.chamadasAVerificar == 1)
        #expect(await api.chamadasACriarConta == 1)
    }

    @Test("CadastroViewModel com Declared Age Range indisponível (erro ou iOS antigo) segue só com a data e chama a API")
    func cadastroComDeclaredAgeRangeIndisponivelSegueEChamaAPI() async throws {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let verificador = VerificadorDeIdadeSimulado(resultado: .indisponivel)
        let vm = CadastroViewModel(api: api, email: "legado@frila.app", verificadorDeIdade: verificador)

        vm.nome = "Candidato Sistema Antigo"
        vm.telefone = "61999998888"
        vm.nascimentoTexto = "15/05/1995"
        vm.aceitouTermos = true

        let destino = await vm.criarConta()
        #expect(destino == .funcoesEHorarios)
        #expect(vm.erro == nil)
        #expect(verificador.chamadasAVerificar == 1)
        #expect(await api.chamadasACriarConta == 1)
    }

    @Test("VerificadorDeIdadeDoSistema interpreta limites da faixa etária com corte em 18")
    func interpretacaoDeLimitesDaFaixaEtaria() {
        // 1. lowerBound >= 18 -> maior de idade (18 ou mais)
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: 18, upperBound: nil) == .dezoitoOuMais)
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: 21, upperBound: nil) == .dezoitoOuMais)
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: 18, upperBound: 25) == .dezoitoOuMais)

        // 2. upperBound presente e < 18 -> menor de idade (faixa termina em 17 ou menos)
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: nil, upperBound: 17) == .abaixoDe18)
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: 13, upperBound: 17) == .abaixoDe18)
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: nil, upperBound: 16) == .abaixoDe18)

        // 3. upperBound == 18 não é tratado como menor (< 18 estrito), vai para indisponível
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: nil, upperBound: 18) == .indisponivel)

        // 4. Ambos nulos não comprovam nada -> indisponível (segue com a data)
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: nil, upperBound: nil) == .indisponivel)

        // 5. Faixa ambígua que cruza o corte (ex: 16 a 20) -> indisponível
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: 16, upperBound: 20) == .indisponivel)
    }

    @Test("CadastroViewModel trata erro 409 conta_existente da API")
    func contaExistenteTrataErroDaAPI() async throws {
        let api = ApiClienteEmMemoria(cenario: .contaExistente)
        let vm = CadastroViewModel(api: api, email: "jaexiste@frila.app")

        vm.nome = "Conta Repetida"
        vm.telefone = "61999998888"
        vm.nascimentoTexto = "01/01/1990"
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
        vm.aceitouTermos = true

        #expect(vm.formularioPreenchido)
        let destino = await vm.criarConta()
        #expect(destino == .funcoesEHorarios)
        let conta = try await api.minhaConta()
        #expect(conta.nome == "Beatriz Souza")
        #expect(conta.perfil == .profissional)
        #expect(conta.telefone == "+5561988887777")
    }

    @Test("CadastroViewModel cria conta contratante e vai para Início do contratante")
    func criarContaContratanteComSucesso() async throws {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let vm = CadastroViewModel(api: api, email: "patrao@frila.app")

        vm.perfil = .contratante
        vm.nome = "Carlos Gerente"
        vm.telefone = "61977776666"
        vm.nascimentoTexto = "20/08/1985"
        vm.aceitouTermos = true

        let destino = await vm.criarConta()
        #expect(destino == .contratante)
        let conta = try await api.minhaConta()
        #expect(conta.nome == "Carlos Gerente")
        #expect(conta.perfil == .contratante)
    }

    @Test("CadastroViewModel envia o aceite com a versão dos termos para a API")
    func cadastroEnviaVersaoDosTermos() async throws {
        let spy = ApiClienteEspiaoCadastro()
        let vm = CadastroViewModel(api: spy, email: "novo@frila.app")

        vm.perfil = .profissional
        vm.nome = "Beatriz Souza"
        vm.telefone = "(61) 98888-7777"
        vm.nascimentoTexto = "12/04/1998"
        vm.aceitouTermos = true

        #expect(vm.formularioPreenchido)
        let destino = await vm.criarConta()
        #expect(destino == .funcoesEHorarios)

        #expect(spy.chamadasACriarConta == 1)
        let cadastro = try #require(spy.ultimoCadastroRecebido)
        #expect(cadastro.versaoTermos == "2026-10-15")
        #expect(!cadastro.versaoTermos.isEmpty)
    }

    // MARK: - DestinoDaConta

    @Test("DestinoDaConta: profissional com perfil vai para .profissional")
    func destinoProfissionalComPerfil() async throws {
        let api = ApiClienteEmMemoria(cenario: .sucesso)
        let destino = try await DestinoDaConta.avaliar(api: api)
        #expect(destino == .profissional)
    }

    @Test("DestinoDaConta: profissional sem perfil profissional vai para .funcoesEHorarios")
    func destinoProfissionalSemPerfil() async throws {
        let api = ApiClienteEmMemoria(cenario: .semPerfilProfissional)
        let destino = try await DestinoDaConta.avaliar(api: api)
        #expect(destino == .funcoesEHorarios)
    }

    @Test("DestinoDaConta: contratante vai para .contratante")
    func destinoContratante() async throws {
        let api = ApiClienteEmMemoria(cenario: .contratante)
        let destino = try await DestinoDaConta.avaliar(api: api)
        #expect(destino == .contratante)
    }

    @Test("DestinoDaConta: primeiro acesso (404 naoEncontrado) vai para .cadastro")
    func destinoPrimeiroAcessoVaiParaCadastro() async throws {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let destino = try await DestinoDaConta.avaliar(api: api, emailParaCadastro: "novo@frila.app")
        #expect(destino == .cadastro(email: "novo@frila.app"))
    }

    @Test("DestinoDaConta: erro de rede em minhaConta não vai para cadastro e lança erro")
    func destinoErroDeRedeMinhaConta() async throws {
        let api = ApiClienteEmMemoria(cenario: .semRede)
        do {
            _ = try await DestinoDaConta.avaliar(api: api)
            Issue.record("Deveria ter lançado erro de rede")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .semRede)
        }
    }

    @Test("DestinoDaConta: erro de rede em meuPerfilProfissional não vai para funcoesEHorarios e lança erro")
    func destinoErroDeRedePerfilProfissional() async throws {
        let api = ApiClienteEmMemoria(cenario: .perfilProfissionalComErroDeRede)
        do {
            _ = try await DestinoDaConta.avaliar(api: api)
            Issue.record("Deveria ter lançado erro de rede")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .semRede)
        }
    }

    @Test("DestinoDaConta: conta suspensa vai para .contaSuspensa (RF24, RN13)")
    func destinoContaSuspensa() async throws {
        let api = ApiClienteEmMemoria(cenario: .contaSuspensa)
        let destino = try await DestinoDaConta.avaliar(api: api)
        guard case let .contaSuspensa(situacao) = destino else {
            Issue.record("Deveria ser .contaSuspensa")
            return
        }
        #expect(situacao.estado == .suspensa)
        #expect(situacao.suspensao?.motivo == "Denúncia grave confirmada pela Equipe Frila")
    }

    @Test("DestinoDaConta: conta reativada volta às telas normais na próxima abertura (Critério 3)")
    func destinoContaReativadaVoltaAoPerfil() async throws {
        let api = ApiClienteEmMemoria(cenario: .contaSuspensa)
        await api.reativarConta()
        let destino = try await DestinoDaConta.avaliar(api: api)
        #expect(destino == .profissional)
    }

    private func criarUserDefaultsIsolado() -> (UserDefaults, String) {
        let nome = "AutenticacaoTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: nome)!
        return (defaults, nome)
    }

    @Test("DestinoDaConta: sem rede na abertura mantém destino guardado prévio (Critério 5)")
    func destinoSemRedeComContaSuspensaMantemDestinoGuardado() async throws {
        let (defaults, suiteName) = criarUserDefaultsIsolado()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        DestinoGuardado.salvar(.profissional, em: defaults)
        let api = ApiClienteEmMemoria(cenario: .semRede)
        let destino = try await DestinoDaConta.avaliarComRecuperacaoOffline(api: api, defaults: defaults)
        #expect(destino == .profissional)
    }

    @Test("DemonstracaoContas aceita apenas os e-mails oficiais de revisão")
    func demonstracaoContasFiltro() {
        #expect(DemonstracaoContas.ehEmailDeDemonstracao("revisao-profissional@frila.app"))
        #expect(DemonstracaoContas.ehEmailDeDemonstracao("revisao-contratante@frila.app"))
        #expect(DemonstracaoContas.ehEmailDeDemonstracao("   revisao-profissional@frila.app  "))
        #expect(!DemonstracaoContas.ehEmailDeDemonstracao("demo@example.com"))
        #expect(!DemonstracaoContas.ehEmailDeDemonstracao("outro@frila.app"))
    }

    @Test("CodigoViewModel: falha de rede ao confirmar código exibe erro e não direciona para cadastro")
    func confirmarCodigoComErroDeRede() async {
        let api = ApiClienteEmMemoria(cenario: .semRede)
        let vm = CodigoViewModel(api: api, email: "teste@frila.app")
        vm.codigo = "123456"

        let destino = await vm.confirmarCodigo()
        #expect(destino == nil)
        #expect(vm.erro != nil)
        #expect(vm.erro?.contains("Sem conexão") == true)
    }

    @Test("CodigoViewModel: chamadas simultâneas a confirmarCodigo disparam a API apenas uma vez")
    func confirmarCodigoReentrada() async throws {
        let api = ApiDubleReentradaCodigo()
        let vm = CodigoViewModel(api: api, email: "teste@frila.app")
        vm.codigo = "123456"

        let primeira = Task { await vm.confirmarCodigo() }
        await api.esperarEntrada()

        #expect(vm.carregando)
        let segunda = await vm.confirmarCodigo()
        #expect(segunda == nil)

        api.liberar()
        let destinoPrimeira = await primeira.value

        #expect(destinoPrimeira != nil)
        let chamadas = await api.base.chamadasAVerificarCodigo
        #expect(chamadas == 1)
    }

    @Test("CadastroViewModel: chamadas simultâneas a criarConta disparam a API apenas uma vez")
    func criarContaReentrada() async throws {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let vm = CadastroViewModel(api: api, email: "teste@frila.app")
        vm.nome = "Teste da Silva"
        vm.telefone = "11999998888"
        vm.nascimentoTexto = "01/01/1990"
        vm.aceitouTermos = true

        async let primeira = vm.criarConta()
        async let segunda = vm.criarConta()
        _ = await (primeira, segunda)

        let chamadas = await api.chamadasACriarConta
        #expect(chamadas == 1)
    }

    // MARK: - Missão UX-01: Máscaras, Validações e Maioridade

    @Test("CadastroViewModel: máscara progressiva de data de nascimento insere barras nas posições 2 e 5")
    func mascaraDataNascimentoProgressiva() {
        #expect(CadastroViewModel.formatarDataNascimento("1") == "1")
        #expect(CadastroViewModel.formatarDataNascimento("17", textoAnterior: "1") == "17/")
        #expect(CadastroViewModel.formatarDataNascimento("17/1", textoAnterior: "17/") == "17/1")
        #expect(CadastroViewModel.formatarDataNascimento("17/10", textoAnterior: "17/1") == "17/10/")
        #expect(CadastroViewModel.formatarDataNascimento("17/10/2", textoAnterior: "17/10/") == "17/10/2")
        #expect(CadastroViewModel.formatarDataNascimento("17/10/2000", textoAnterior: "17/10/200") == "17/10/2000")
        // Limita a 8 dígitos (máximo dd/mm/aaaa)
        #expect(CadastroViewModel.formatarDataNascimento("17/10/20009", textoAnterior: "17/10/2000") == "17/10/2000")
    }

    @Test("CadastroViewModel: apagar na máscara de data remove dígito anterior à barra")
    func mascaraDataNascimentoApagar() {
        // Usuário está em "17/" e aperta backspace (ficando "17")
        #expect(CadastroViewModel.formatarDataNascimento("17", textoAnterior: "17/") == "1")
        // Usuário está em "17/10/" e aperta backspace (ficando "17/10")
        #expect(CadastroViewModel.formatarDataNascimento("17/10", textoAnterior: "17/10/") == "17/1")
    }

    @Test("CadastroViewModel: colar data com ou sem barras formata corretamente")
    func mascaraDataNascimentoColar() {
        #expect(CadastroViewModel.formatarDataNascimento("17102000") == "17/10/2000")
        #expect(CadastroViewModel.formatarDataNascimento("17/10/2000") == "17/10/2000")
        #expect(CadastroViewModel.formatarDataNascimento("01011990") == "01/01/1990")
    }

    @Test("CadastroViewModel: digitação com barras manuais não duplica barras nem corrompe a máscara")
    func mascaraDataNascimentoDigitarComBarras() {
        #expect(CadastroViewModel.formatarDataNascimento("17//", textoAnterior: "17/") == "17/")
        #expect(CadastroViewModel.formatarDataNascimento("17/10//", textoAnterior: "17/10/") == "17/10/")
        #expect(CadastroViewModel.formatarDataNascimento("17/", textoAnterior: "17") == "17/")
        #expect(CadastroViewModel.formatarDataNascimento("17/10/", textoAnterior: "17/10") == "17/10/")
        #expect(CadastroViewModel.formatarDataNascimento("17/10/2000/", textoAnterior: "17/10/2000") == "17/10/2000")
    }

    @Test("CadastroViewModel: máscara de telefone formata 10 e 11 dígitos no padrão brasileiro")
    func mascaraTelefoneFormatacao() {
        #expect(CadastroViewModel.formatarTelefone("6") == "(6")
        #expect(CadastroViewModel.formatarTelefone("61", textoAnterior: "6") == "(61) ")
        #expect(CadastroViewModel.formatarTelefone("619", textoAnterior: "(61) ") == "(61) 9")
        // 10 dígitos (fixo): (DD) XXXX-XXXX
        #expect(CadastroViewModel.formatarTelefone("6133334444") == "(61) 3333-4444")
        // 11 dígitos (móvel): (DD) 9XXXX-XXXX
        #expect(CadastroViewModel.formatarTelefone("61988887777") == "(61) 98888-7777")
        // Colagem com código +55
        #expect(CadastroViewModel.formatarTelefone("+5561988887777") == "(61) 98888-7777")
        #expect(CadastroViewModel.formatarTelefone("5561988887777") == "(61) 98888-7777")
    }

    @Test("CadastroViewModel: apagar na máscara de telefone remove caracteres de controle e dígitos correspondentes")
    func mascaraTelefoneApagar() {
        #expect(CadastroViewModel.formatarTelefone("(61)", textoAnterior: "(61) ") == "(6")
        #expect(CadastroViewModel.formatarTelefone("(61) 9888", textoAnterior: "(61) 9888-") == "(61) 988")
    }

    @Test("CadastroViewModel: ao tocar em Continuar com campo pendente, indica o campo com erro")
    func validacaoAoTocarContinuarIndicaCampo() async {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let vm = CadastroViewModel(api: api, email: "teste@frila.app")

        // 1. Nome vazio
        var destino = await vm.criarConta()
        #expect(destino == nil)
        #expect(vm.campoComErro == .nome)
        #expect(vm.erro == "Informe seu nome completo.")

        // 2. Preenche nome, telefone vazio
        vm.nome = "Carlos Silva"
        destino = await vm.criarConta()
        #expect(destino == nil)
        #expect(vm.campoComErro == .telefone)
        #expect(vm.erro == "Informe um telefone válido com DDD.")

        // 3. Preenche telefone, nascimento vazio
        vm.telefone = "61988887777"
        destino = await vm.criarConta()
        #expect(destino == nil)
        #expect(vm.campoComErro == .nascimento)
        #expect(vm.erro == "Informe a data de nascimento no formato dd/mm/aaaa.")

        // 4. Preenche nascimento válido (maior de 18), termos desmarcados
        vm.nascimentoTexto = "15/05/1995"
        destino = await vm.criarConta()
        #expect(destino == nil)
        #expect(vm.campoComErro == .termos)
        #expect(vm.erro == "É necessário aceitar os Termos de uso e a Política de privacidade para continuar.")

        // 5. Aceita termos: tudo válido
        vm.aceitouTermos = true
        destino = await vm.criarConta()
        #expect(destino == .funcoesEHorarios)
        #expect(vm.campoComErro == nil)
        #expect(vm.erro == nil)
    }

    @Test("CadastroViewModel: data completa de menor de 18 ativa ehMenorDeIdade e bloqueia submissão")
    func dataMenorDeIdadeCalculada() {
        let relogioFixo = RelogioFixo(agora: ISO8601DateFormatter().date(from: "2026-10-01T12:00:00Z")!)
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso, relogio: relogioFixo)
        let vm = CadastroViewModel(api: api, email: "jovem@frila.app", relogio: relogioFixo)

        vm.nome = "Jovem Menor"
        vm.telefone = "61988887777"
        vm.aceitouTermos = true

        // Data incompleta: ehMenorDeIdade ainda falso
        vm.nascimentoTexto = "02/10"
        #expect(!vm.ehMenorDeIdade)

        // 17 anos (nasceu em 02/10/2008, hoje é 01/10/2026): ehMenorDeIdade verdadeiro
        vm.nascimentoTexto = "02/10/2008"
        #expect(vm.ehMenorDeIdade)
        #expect(!vm.formularioPreenchido)

        // 18 anos completos (nasceu em 01/10/2008): ehMenorDeIdade falso
        vm.nascimentoTexto = "01/10/2008"
        #expect(!vm.ehMenorDeIdade)
        #expect(vm.formularioPreenchido)
    }

    @Test("CadastroViewModel: nascido em 29/02 atinge maioridade em 01/03 no ano não bissexto")
    func maioridadeNascidosEm29Fevereiro() async {
        let iso = ISO8601DateFormatter()
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)

        // 1. Nascido em 29/02/2012 (ano bissexto), 18 anos em 2030 (não bissexto)
        // 28/02/2030: ainda menor de 18
        let relogio20300228 = RelogioFixo(agora: iso.date(from: "2030-02-28T12:00:00Z")!)
        let vm2030Menor = CadastroViewModel(api: api, email: "bissexto@frila.app", relogio: relogio20300228)
        vm2030Menor.nome = "Jovem Bissexto"
        vm2030Menor.telefone = "61988887777"
        vm2030Menor.aceitouTermos = true
        vm2030Menor.nascimentoTexto = "29/02/2012"
        #expect(vm2030Menor.ehMenorDeIdade)
        #expect(!vm2030Menor.formularioPreenchido)
        let destinoBloqueado = await vm2030Menor.criarConta()
        #expect(destinoBloqueado == nil)
        #expect(vm2030Menor.campoComErro == .nascimento)
        #expect(vm2030Menor.erro == "O Frila é exclusivo para maiores de 18 anos.")

        // 01/03/2030: completa 18 anos (adulto)
        let relogio20300301 = RelogioFixo(agora: iso.date(from: "2030-03-01T12:00:00Z")!)
        let vm2030Adulto = CadastroViewModel(api: api, email: "bissexto@frila.app", relogio: relogio20300301)
        vm2030Adulto.nome = "Jovem Bissexto"
        vm2030Adulto.telefone = "61988887777"
        vm2030Adulto.aceitouTermos = true
        vm2030Adulto.nascimentoTexto = "29/02/2012"
        #expect(!vm2030Adulto.ehMenorDeIdade)
        #expect(vm2030Adulto.formularioPreenchido)

        // 2. Nascido em 29/02/2008 (ano bissexto), 18 anos em 2026 (não bissexto)
        // 28/02/2026: menor
        let relogio20260228 = RelogioFixo(agora: iso.date(from: "2026-02-28T12:00:00Z")!)
        let vm2026Menor = CadastroViewModel(api: api, email: "bissexto2008@frila.app", relogio: relogio20260228)
        vm2026Menor.nascimentoTexto = "29/02/2008"
        #expect(vm2026Menor.ehMenorDeIdade)

        // 01/03/2026: completa 18 anos (adulto)
        let relogio20260301 = RelogioFixo(agora: iso.date(from: "2026-03-01T12:00:00Z")!)
        let vm2026Adulto = CadastroViewModel(api: api, email: "bissexto2008@frila.app", relogio: relogio20260301)
        vm2026Adulto.nome = "Adulto Bissexto"
        vm2026Adulto.telefone = "61988887777"
        vm2026Adulto.aceitouTermos = true
        vm2026Adulto.nascimentoTexto = "29/02/2008"
        #expect(!vm2026Adulto.ehMenorDeIdade)
        #expect(vm2026Adulto.formularioPreenchido)
    }

    // MARK: - Recuperação Offline e Saída da Conta

    @Test("DestinoDaConta: semRede com destino guardado recupera o destino")
    func destinoSemRedeComDestinoGuardado() async throws {
        let (defaults, suiteName) = criarUserDefaultsIsolado()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        DestinoGuardado.salvar(.profissional, em: defaults)

        let api = ApiClienteEmMemoria(cenario: .semRede)
        let destino = try await DestinoDaConta.avaliarComRecuperacaoOffline(api: api, defaults: defaults)
        #expect(destino == .profissional)
    }

    @Test("DestinoDaConta: rede ruim (servidor que não responde) vence o prazo e abre o destino guardado, como sem rede")
    func destinoComRedeRuimAbreODestinoGuardado() async throws {
        let (defaults, suiteName) = criarUserDefaultsIsolado()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        DestinoGuardado.salvar(.contratante, em: defaults)

        let relogio = ContinuousClock()
        let inicio = relogio.now
        let destino = try await DestinoDaConta.avaliarComRecuperacaoOffline(
            api: ApiQueNaoResponde(), defaults: defaults, prazo: .milliseconds(150)
        )
        #expect(destino == .contratante)
        #expect(relogio.now - inicio < .seconds(5), "a abertura não pode esperar a URLSession desistir")
    }

    @Test("DestinoDaConta: rede ruim sem destino guardado vira semRede (com o código do prazo), e não fica no indicador")
    func destinoComRedeRuimSemGuardadoEhSemRede() async throws {
        let (defaults, suiteName) = criarUserDefaultsIsolado()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        DestinoGuardado.limpar(em: defaults)

        let erro = await #expect(throws: ErroDaApi.self) {
            _ = try await DestinoDaConta.avaliarComRecuperacaoOffline(api: ApiQueNaoResponde(), defaults: defaults, prazo: .milliseconds(150))
        }
        #expect(erro?.codigo == .semRede)
        #expect(erro?.codigoOriginal == PrazoDaAbertura.codigoOriginal)
    }

    @Test("IdentidadeDaAvaliacao: rede ruim vence o prazo e usa a sessão do cache")
    func identidadeComRedeRuimUsaOCache() async throws {
        let contaID = UUID()
        let cache = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        try await cache.salvar(sessao: SessaoUsuario(usuarioID: contaID, perfil: .profissional))
        #expect(try await IdentidadeDaAvaliacao.obter(api: ApiQueNaoResponde(), cache: cache, prazo: .milliseconds(150)) == contaID)
    }

    @Test("PrazoDaAbertura: a resposta que chega antes do prazo passa, e o prazo não espera")
    func prazoNaoAtrasaRespostaRapida() async throws {
        let relogio = ContinuousClock()
        let inicio = relogio.now
        let valor = try await PrazoDaAbertura.esperar(.seconds(30)) { 42 }
        #expect(valor == 42)
        #expect(relogio.now - inicio < .seconds(5))
    }

    @Test("DestinoDaConta: semRede sem destino guardado lança erro")
    func destinoSemRedeSemDestinoGuardado() async throws {
        let (defaults, suiteName) = criarUserDefaultsIsolado()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        DestinoGuardado.limpar(em: defaults)

        let api = ApiClienteEmMemoria(cenario: .semRede)
        do {
            _ = try await DestinoDaConta.avaliarComRecuperacaoOffline(api: api, defaults: defaults)
            Issue.record("Deveria ter lançado erro de rede quando não há destino guardado")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .semRede)
        }
    }

    @Test("SaidaDaConta: ao sair da conta, o destino guardado é apagado")
    func saidaDaContaLimpaDestinoGuardado() async throws {
        let (defaults, suiteName) = criarUserDefaultsIsolado()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        DestinoGuardado.salvar(.profissional, em: defaults)
        #expect(DestinoGuardado.obter(de: defaults) == .profissional)

        let container = try PersistenciaFrila.criarContainer(emMemoria: true)
        let local = ArmazenamentoSwiftData(modelContainer: container)
        let api = ApiClienteEmMemoria()
        let usuarioID = UUID()
        let instante = Date(timeIntervalSince1970: 1_800_000_000)
        let inicio = instante.addingTimeInterval(3_600)
        let fim = inicio.addingTimeInterval(3_600)
        let resumo = VagaResumo(
            id: UUID(), funcao: "Garçom", local: "Asa Sul", regiaoAdministrativa: "Plano Piloto",
            periodo: try Periodo(inicio: inicio, fim: fim), valor: Dinheiro(centavos: 12_000)
        )
        let reputacao = Reputacao(positivas: 1, total: 1, taxaComparecimento: 1, turnosConsiderados: 1, turnosRealizados: 1)
        let visivelAte = fim.addingTimeInterval(7 * 24 * 3_600)
        let contato = Contato(nome: "Bistrô", telefone: "+5561999990000", whatsappURL: try #require(URL(string: "https://wa.me/5561999990000")), visivelAte: visivelAte)
        let turno = Turno(
            id: UUID(), posicaoID: UUID(), vaga: resumo,
            contraparte: PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: "Bistrô", reputacao: reputacao),
            contatoVisivelAte: visivelAte, verificacao: .pendente, valorAcordado: resumo.valor, podeAvaliar: false,
            contato: contato
        )
        try await local.salvar(sessao: SessaoUsuario(usuarioID: usuarioID, perfil: .profissional))
        try await local.salvar(turnos: [turno], em: instante)
        try await local.salvar(funcoes: [Funcao(id: UUID(), nome: "Garçom", categoria: "Restaurante")])
        try await local.enfileirar(AcaoPendente(tipo: .checkin, turnoID: turno.id, instanteDoToque: instante, chave: UUID(), distanciaMetros: 20))
        #expect(try await local.turnosValidos(em: instante).first?.contato?.telefone == "+5561999990000")
        #expect(try await local.pendentes().count == 1)
        let saida = SaidaDaConta(
            api: api,
            armazenamento: local,
            limparDestino: {
                if let defs = UserDefaults(suiteName: suiteName) {
                    DestinoGuardado.limpar(em: defs)
                }
            }
        )

        await saida.sair(tokenFCM: nil)

        #expect(DestinoGuardado.obter(de: defaults) == nil)
        #expect(try await local.sessao() == nil)
        #expect(try await local.turnosValidos(em: instante).isEmpty)
        #expect(try await local.funcoes().isEmpty)
        #expect(try await local.pendentes().isEmpty)
    }
}

// MARK: - Dublê de teste para espionar criação de conta

private final class ApiClienteEspiaoCadastro: ApiClienteEncaminhador, @unchecked Sendable {
    private let lock = NSLock()
    private var _cadastrosRecebidos: [CadastroConta] = []

    override init(base: ApiClienteEmMemoria = ApiClienteEmMemoria(cenario: .primeiroAcesso)) {
        super.init(base: base)
    }

    var chamadasACriarConta: Int {
        lock.withLock { _cadastrosRecebidos.count }
    }

    var ultimoCadastroRecebido: CadastroConta? {
        lock.withLock { _cadastrosRecebidos.last }
    }

    override func criarConta(_ cadastro: CadastroConta) async throws -> Conta {
        lock.withLock { _cadastrosRecebidos.append(cadastro) }
        return try await base.criarConta(cadastro)
    }
}

// MARK: - Dublê para teste determinístico de reentrada do código

private final class ApiDubleReentradaCodigo: ApiClienteEncaminhador, @unchecked Sendable {
    private let lock = NSLock()
    private var emVooContinuation: CheckedContinuation<Void, Never>?
    private var liberarContinuation: CheckedContinuation<Void, Never>?
    private var entrou = false

    override init(base: ApiClienteEmMemoria = ApiClienteEmMemoria(cenario: .sucesso)) {
        super.init(base: base)
    }

    func esperarEntrada() async {
        let jaEntrou: Bool = lock.withLock { entrou }
        if jaEntrou { return }
        await withCheckedContinuation { cont in
            lock.withLock {
                if entrou {
                    cont.resume()
                } else {
                    emVooContinuation = cont
                }
            }
        }
    }

    func liberar() {
        lock.withLock {
            liberarContinuation?.resume()
            liberarContinuation = nil
        }
    }

    override func verificarCodigo(email: String, codigo: String) async throws {
        try await super.verificarCodigo(email: email, codigo: codigo)
        await withCheckedContinuation { cont in
            lock.withLock {
                entrou = true
                emVooContinuation?.resume()
                emVooContinuation = nil
                liberarContinuation = cont
            }
        }
    }
}


// MARK: - Dublê de rede ruim: a chamada nunca volta (até ser cancelada)

private final class ApiQueNaoResponde: ApiClienteEncaminhador, @unchecked Sendable {
    private func esperarParaSempre() async throws {
        try await Task.sleep(for: .seconds(60))
    }

    override func minhaConta() async throws -> Conta {
        try await esperarParaSempre()
        return try await base.minhaConta()
    }
}
