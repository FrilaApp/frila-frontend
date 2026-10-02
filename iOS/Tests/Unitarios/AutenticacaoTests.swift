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
        #expect(await api.chamadasACriarConta == 0)
        await #expect(throws: ErroDaApi.self) {
            _ = try await api.minhaConta()
        }
    }

    @Test("CadastroViewModel bloqueia submissão quando maiorDeIdade é falso e não chama a API")
    func maiorDeIdadeFalsoBloqueiaSubmissaoENaoChamaAPI() async throws {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let vm = CadastroViewModel(api: api, email: "novo@frila.app")

        vm.nome = "Maria Oliveira"
        vm.telefone = "61999998888"
        vm.nascimentoTexto = "15/05/1995"
        vm.maiorDeIdade = false
        vm.aceitouTermos = true

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
        vm.maiorDeIdade = true
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
        vm.maiorDeIdade = true
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
        vm.maiorDeIdade = true
        vm.aceitouTermos = true

        #expect(vm.formularioPreenchido)
        let destino = await vm.criarConta()
        #expect(destino == .funcoesEHorarios)

        #expect(spy.chamadasACriarConta == 1)
        let cadastro = try #require(spy.ultimoCadastroRecebido)
        #expect(cadastro.versaoTermos == "2026-09-22")
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
        let api = ApiClienteEmMemoria(cenario: .sucesso)
        let vm = CodigoViewModel(api: api, email: "teste@frila.app")
        vm.codigo = "123456"

        async let primeira = vm.confirmarCodigo()
        async let segunda = vm.confirmarCodigo()
        _ = await (primeira, segunda)

        let chamadas = await api.chamadasAVerificarCodigo
        #expect(chamadas == 1)
    }

    @Test("CadastroViewModel: chamadas simultâneas a criarConta disparam a API apenas uma vez")
    func criarContaReentrada() async throws {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let vm = CadastroViewModel(api: api, email: "teste@frila.app")
        vm.nome = "Teste da Silva"
        vm.telefone = "11999998888"
        vm.nascimentoTexto = "01/01/1990"
        vm.maiorDeIdade = true
        vm.aceitouTermos = true

        async let primeira = vm.criarConta()
        async let segunda = vm.criarConta()
        _ = await (primeira, segunda)

        let chamadas = await api.chamadasACriarConta
        #expect(chamadas == 1)
    }

    // MARK: - Recuperação Offline e Saída da Conta

    @Test("DestinoDaConta: semRede com destino guardado recupera o destino")
    func destinoSemRedeComDestinoGuardado() async throws {
        DestinoGuardado.salvar(.profissional)
        defer { DestinoGuardado.limpar() }

        let api = ApiClienteEmMemoria(cenario: .semRede)
        let destino = try await DestinoDaConta.avaliarComRecuperacaoOffline(api: api)
        #expect(destino == .profissional)
    }

    @Test("DestinoDaConta: semRede sem destino guardado lança erro")
    func destinoSemRedeSemDestinoGuardado() async throws {
        DestinoGuardado.limpar()

        let api = ApiClienteEmMemoria(cenario: .semRede)
        do {
            _ = try await DestinoDaConta.avaliarComRecuperacaoOffline(api: api)
            Issue.record("Deveria ter lançado erro de rede quando não há destino guardado")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .semRede)
        }
    }

    @Test("SaidaDaConta: ao sair da conta, o destino guardado é apagado")
    func saidaDaContaLimpaDestinoGuardado() async throws {
        DestinoGuardado.salvar(.profissional)
        #expect(DestinoGuardado.obter() == .profissional)

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
        let saida = SaidaDaConta(api: api, armazenamento: local)

        await saida.sair(tokenFCM: nil)

        #expect(DestinoGuardado.obter() == nil)
        #expect(try await local.sessao() == nil)
        #expect(try await local.turnosValidos(em: instante).isEmpty)
        #expect(try await local.funcoes().isEmpty)
        #expect(try await local.pendentes().isEmpty)
    }
}

// MARK: - Dublê de teste para espionar criação de conta

private final class ApiClienteEspiaoCadastro: ApiCliente, @unchecked Sendable {
    private let base: ApiClienteEmMemoria
    private let lock = NSLock()
    private var _cadastrosRecebidos: [CadastroConta] = []

    init(base: ApiClienteEmMemoria = ApiClienteEmMemoria(cenario: .primeiroAcesso)) {
        self.base = base
    }

    var chamadasACriarConta: Int {
        lock.withLock { _cadastrosRecebidos.count }
    }

    var ultimoCadastroRecebido: CadastroConta? {
        lock.withLock { _cadastrosRecebidos.last }
    }

    func criarConta(_ cadastro: CadastroConta) async throws -> Conta {
        lock.withLock { _cadastrosRecebidos.append(cadastro) }
        return try await base.criarConta(cadastro)
    }

    // Encaminhamentos padrão
    func solicitarCodigo(email: String) async throws { try await base.solicitarCodigo(email: email) }
    func verificarCodigo(email: String, codigo: String) async throws { try await base.verificarCodigo(email: email, codigo: codigo) }
    func entrarDemonstracao(email: String, codigo: String) async throws { try await base.entrarDemonstracao(email: email, codigo: codigo) }
    func possuiSessao() async -> Bool { await base.possuiSessao() }
    func minhaConta() async throws -> Conta { try await base.minhaConta() }
    func criarPerfilProfissional(_ dados: DadosPerfilProfissional) async throws -> PerfilProfissional { try await base.criarPerfilProfissional(dados) }
    func meuPerfilProfissional() async throws -> PerfilProfissional { try await base.meuPerfilProfissional() }
    func atualizarPerfilProfissional(_ alteracao: AlteracaoPerfilProfissional) async throws -> PerfilProfissional { try await base.atualizarPerfilProfissional(alteracao) }
    func cadastrarEstabelecimento(_ cadastro: CadastroEstabelecimento) async throws -> Estabelecimento { try await base.cadastrarEstabelecimento(cadastro) }
    func meusEstabelecimentos() async throws -> [EstabelecimentoDaConta] { try await base.meusEstabelecimentos() }
    func painelEstabelecimento(id: UUID, periodo: Periodo) async throws -> Painel { try await base.painelEstabelecimento(id: id, periodo: periodo) }
    func funcoes() async throws -> [Funcao] { try await base.funcoes() }
    func publicarVaga(_ publicacao: PublicacaoVaga) async throws -> VagaPublicada { try await base.publicarVaga(publicacao) }
    func republicarVaga(id: UUID, periodo: Periodo, chave: UUID) async throws -> VagaPublicada { try await base.republicarVaga(id: id, periodo: periodo, chave: chave) }
    func vagasAbertas(_ filtro: FiltroVagas) async throws -> [VagaNaLista] { try await base.vagasAbertas(filtro) }
    func detalheDaVaga(id: UUID) async throws -> Vaga { try await base.detalheDaVaga(id: id) }
    func candidatar(vagaID: UUID) async throws -> ResultadoCandidatura { try await base.candidatar(vagaID: vagaID) }
    func perfilPublico(id: UUID) async throws -> PerfilPublico { try await base.perfilPublico(id: id) }
    func meusTurnos() async throws -> [Turno] { try await base.meusTurnos() }
    func contatoDoTurno(id: UUID) async throws -> Contato { try await base.contatoDoTurno(id: id) }
    func avisarACaminho(turnoID: UUID) async throws -> ResultadoACaminho { try await base.avisarACaminho(turnoID: turnoID) }
    func fazerCheckin(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro { try await base.fazerCheckin(turnoID: turnoID, distanciaMetros: distanciaMetros, registradoEm: registradoEm) }
    func fazerCheckout(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro { try await base.fazerCheckout(turnoID: turnoID, distanciaMetros: distanciaMetros, registradoEm: registradoEm) }
    func avaliar(turnoID: UUID, resposta: Bool) async throws -> Avaliacao { try await base.avaliar(turnoID: turnoID, resposta: resposta) }
    func configuracaoDoApp() async throws -> ConfiguracaoApp { try await base.configuracaoDoApp() }
    func removerDispositivo(tokenFCM: String) async throws { try await base.removerDispositivo(tokenFCM: tokenFCM) }
    func sair(tokenFCM: String?) async { await base.sair(tokenFCM: tokenFCM) }
}

