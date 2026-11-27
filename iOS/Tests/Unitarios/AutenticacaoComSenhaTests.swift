import Foundation
import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

@Suite("Autenticação com senha")
struct AutenticacaoComSenhaTests {

    // MARK: - EntradaComSenhaViewModel

    @Test("Entrada com senha válida resolve destino de profissional e limpa a senha da memória da view model")
    @MainActor
    func entradaComSenhaProfissional() async {
        let api = ApiClienteEmMemoria(cenario: .sucesso, sessaoAtivaInicial: false)
        let vm = EntradaComSenhaViewModel(api: api, emailInicial: "  Prof@Exemplo.Test ")
        vm.senha = "SenhaSintetica#2026"

        let destino = await vm.entrar()

        #expect(destino == .destino(.profissional))
        #expect(vm.erro == nil)
        #expect(vm.carregando == false)
        #expect(vm.senha.isEmpty)
        #expect(await api.chamadasAEntrarComSenha == 1)
        #expect(await api.possuiSessao() == true)
    }

    @Test("Entrada com senha válida resolve destino de contratante")
    @MainActor
    func entradaComSenhaContratante() async {
        let api = ApiClienteEmMemoria(cenario: .contratante, sessaoAtivaInicial: false)
        let vm = EntradaComSenhaViewModel(api: api, emailInicial: "casa@exemplo.test")
        vm.senha = "SenhaSintetica#2026"

        let destino = await vm.entrar()

        #expect(destino == .destino(.contratante))
        #expect(vm.erro == nil)
    }

    @Test("Entrada com senha em conta sem cadastro na API encaminha para cadastro")
    @MainActor
    func entradaComSenhaPrimeiroAcesso() async {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso, sessaoAtivaInicial: false)
        let vm = EntradaComSenhaViewModel(api: api, emailInicial: "novo@exemplo.test")
        vm.senha = "SenhaSintetica#2026"

        let destino = await vm.entrar()

        #expect(destino == .cadastro(email: "novo@exemplo.test"))
    }

    @Test("Entrada com senha em conta suspensa devolve destino contaSuspensa")
    @MainActor
    func entradaComSenhaContaSuspensa() async {
        let api = ApiClienteEmMemoria(cenario: .contaSuspensa, sessaoAtivaInicial: false)
        let vm = EntradaComSenhaViewModel(api: api, emailInicial: "suspenso@exemplo.test")
        vm.senha = "SenhaSintetica#2026"

        let destino = await vm.entrar()

        guard case .destino(.contaSuspensa) = destino else {
            Issue.record("Esperava destino .contaSuspensa, recebeu \(String(describing: destino))")
            return
        }
    }

    @Test("Entrada com senha recusa credenciais incorretas sem abrir sessão")
    @MainActor
    func entradaComSenhaIncorreta() async {
        let api = ApiClienteEmMemoria(cenario: .senhaErrada, sessaoAtivaInicial: false)
        let vm = EntradaComSenhaViewModel(api: api, emailInicial: "prof@exemplo.test")
        vm.senha = "SenhaIncorreta#1"

        let destino = await vm.entrar()

        #expect(destino == nil)
        #expect(vm.erro != nil)
        #expect(await api.possuiSessao() == false)
    }

    @Test("Entrada com senha valida e-mail, senha vazia e conta de demonstração localmente")
    @MainActor
    func validacoesLocaisEntradaComSenha() async {
        let api = ApiClienteEmMemoria(cenario: .sucesso, sessaoAtivaInicial: false)
        let vm = EntradaComSenhaViewModel(api: api, emailInicial: "invalido")
        vm.senha = "SenhaSintetica#2026"

        #expect(await vm.entrar() == nil)
        #expect(vm.erro != nil)
        #expect(await api.chamadasAEntrarComSenha == 0)

        vm.email = "prof@exemplo.test"
        vm.senha = ""
        #expect(await vm.entrar() == nil)
        #expect(vm.erro != nil)
        #expect(await api.chamadasAEntrarComSenha == 0)

        vm.email = "revisao-profissional@frilabr.com"
        vm.senha = "SenhaSintetica#2026"
        #expect(await vm.entrar() == nil)
        #expect(vm.erro != nil)
        #expect(await api.chamadasAEntrarComSenha == 0)
    }

    @Test("Entrada com senha mapeia falta de rede e limite excedido")
    @MainActor
    func errosDeRedeELimiteEntradaComSenha() async {
        let apiSemRede = ApiClienteEmMemoria(cenario: .semRede, sessaoAtivaInicial: false)
        let vmSemRede = EntradaComSenhaViewModel(api: apiSemRede, emailInicial: "prof@exemplo.test")
        vmSemRede.senha = "SenhaSintetica#2026"
        #expect(await vmSemRede.entrar() == nil)
        #expect(vmSemRede.erro == MensagemDoErroAPI.texto(ErroDaApi(codigo: .semRede)))

        let apiLimite = ApiComErroDeSenha(erro: ErroDaApi(codigo: .limiteExcedido, codigoOriginal: "over_request_rate_limit"))
        let vmLimite = EntradaComSenhaViewModel(api: apiLimite, emailInicial: "prof@exemplo.test")
        vmLimite.senha = "SenhaSintetica#2026"
        #expect(await vmLimite.entrar() == nil)
        #expect(vmLimite.erro == MensagemDoErroAPI.texto(ErroDaApi(codigo: .limiteExcedido)))
    }

    @Test("Tentativa cancelada ou atrasada não sobrescreve erro nem entrega destino obsoleto")
    @MainActor
    func tentativaCanceladaNaoInvadeEstado() async {
        let api = ApiSenhaLentaControlada()
        let vm = EntradaComSenhaViewModel(api: api, emailInicial: "prof@exemplo.test")
        vm.senha = "SenhaSintetica#2026"

        let tarefa = Task { @MainActor in
            await vm.entrar()
        }
        await api.esperarInicioDaChamada()

        vm.cancelarTentativaAtual()
        tarefa.cancel()
        await api.concluirCom(erro: ErroDaApi(codigo: .naoAutenticado, codigoOriginal: "invalid_credentials"))

        let resultado = await tarefa.value
        #expect(resultado == nil)
        #expect(vm.erro == nil)
        #expect(vm.carregando == false)
    }

    // MARK: - DefinirSenhaViewModel

    @Test("Definir senha em sessão autenticada salva com sucesso e limpa campos")
    @MainActor
    func definirSenhaSucesso() async {
        let api = ApiClienteEmMemoria(cenario: .sucesso, sessaoAtivaInicial: true)
        let vm = DefinirSenhaViewModel(api: api)
        vm.senha = "NovaSenha#2026"
        vm.confirmacao = "NovaSenha#2026"

        let salvou = await vm.salvar()

        #expect(salvou == true)
        #expect(vm.concluido == true)
        #expect(vm.erro == nil)
        #expect(vm.senha.isEmpty)
        #expect(vm.confirmacao.isEmpty)
        #expect(await api.senhasDefinidas == 1)
    }

    @Test("Definir senha valida tamanho mínimo e confirmação antes de chamar a API")
    @MainActor
    func definirSenhaValidacaoLocal() async {
        let api = ApiClienteEmMemoria(cenario: .sucesso, sessaoAtivaInicial: true)
        let vm = DefinirSenhaViewModel(api: api)

        vm.senha = "curta"
        vm.confirmacao = "curta"
        #expect(await vm.salvar() == false)
        #expect(vm.erro != nil)
        #expect(await api.senhasDefinidas == 0)

        vm.senha = "NovaSenha#2026"
        vm.confirmacao = "OutraSenha#2026"
        #expect(await vm.salvar() == false)
        #expect(vm.erro != nil)
        #expect(await api.senhasDefinidas == 0)
    }

    @Test("Definir senha trata weak_password, same_password e reauthentication_needed")
    @MainActor
    func definirSenhaErrosDoServidor() async {
        let apiFraca = ApiClienteEmMemoria(cenario: .senhaFraca, sessaoAtivaInicial: true)
        let vmFraca = DefinirSenhaViewModel(api: apiFraca)
        vmFraca.senha = "12345678"
        vmFraca.confirmacao = "12345678"
        #expect(await vmFraca.salvar() == false)
        #expect(vmFraca.erro?.contains("forte") == true)

        let apiReauth = ApiClienteEmMemoria(cenario: .reautenticacaoNecessaria, sessaoAtivaInicial: true)
        let vmReauth = DefinirSenhaViewModel(api: apiReauth)
        vmReauth.senha = "NovaSenha#2026"
        vmReauth.confirmacao = "NovaSenha#2026"
        #expect(await vmReauth.salvar() == false)
        #expect(vmReauth.erro?.contains("código") == true)
        #expect(await apiReauth.possuiSessao() == true)

        let apiIgual = ApiComErroDeSenha(erro: ErroDaApi(codigo: .campoInvalido, codigoOriginal: "same_password", detalhes: "senha"))
        let vmIgual = DefinirSenhaViewModel(api: apiIgual)
        vmIgual.senha = "MesmaSenha#2026"
        vmIgual.confirmacao = "MesmaSenha#2026"
        #expect(await vmIgual.salvar() == false)
        #expect(vmIgual.erro?.contains("diferente") == true)
    }

    @Test("Recuperação via OTP valida sessão existente e permite definir nova senha na mesma conta")
    @MainActor
    func recuperacaoViaOtpEDefinirSenha() async {
        let api = ApiClienteEmMemoria(cenario: .sucesso, sessaoAtivaInicial: false)
        let recuperacaoVM = RecuperacaoSenhaViewModel(api: api, emailInicial: "prof@exemplo.test")
        #expect(await recuperacaoVM.solicitarRecuperacao() == .avancarParaCodigo(email: "prof@exemplo.test"))
        #expect(await api.chamadasASolicitarRecuperacao == 1)

        let codigoVM = CodigoViewModel(api: api, email: "prof@exemplo.test", modo: .recuperacao)
        codigoVM.codigo = "123456"
        let destino = await codigoVM.confirmarCodigo()
        #expect(destino == .destino(.profissional))
        #expect(await api.possuiSessao() == true)

        let senhaVM = DefinirSenhaViewModel(api: api)
        senhaVM.senha = "SenhaRecuperada#2026"
        senhaVM.confirmacao = "SenhaRecuperada#2026"
        #expect(await senhaVM.salvar() == true)
        #expect(await api.senhasDefinidas == 1)
    }

    // MARK: - RecuperacaoSenhaViewModel (recovery-only)

    @Test("Recuperação apresenta estado neutro para identidade inexistente/social-only sem avançar nem criar conta")
    @MainActor
    func recuperacaoIdentidadeInexistenteMostraEstadoNeutro() async {
        let api = ApiClienteEmMemoria(cenario: .identidadeInexistenteNaRecuperacao, sessaoAtivaInicial: false)
        let vm = RecuperacaoSenhaViewModel(api: api, emailInicial: "naoexiste@exemplo.test")

        let resultado = await vm.solicitarRecuperacao()

        #expect(resultado == .estadoNeutro)
        #expect(vm.mensagemNeutra != nil)
        #expect(vm.erro == nil)
        #expect(await api.possuiSessao() == false)
        #expect(await api.chamadasASolicitarRecuperacao == 1)
    }

    @Test("Recuperação não esconde 429 nem falta de rede e não usa fallback de demonstração")
    @MainActor
    func recuperacaoPreserva429RedeEBloqueiaDemo() async {
        let apiDemo = ApiClienteEmMemoria(cenario: .sucesso, sessaoAtivaInicial: false)
        let vmDemo = RecuperacaoSenhaViewModel(api: apiDemo, emailInicial: "revisao-profissional@frilabr.com")
        #expect(await vmDemo.solicitarRecuperacao() == nil)
        #expect(vmDemo.erro != nil)
        #expect(vmDemo.mensagemNeutra == nil)
        #expect(await apiDemo.chamadasASolicitarRecuperacao == 0)

        let apiSemRede = ApiClienteEmMemoria(cenario: .semRede, sessaoAtivaInicial: false)
        let vmSemRede = RecuperacaoSenhaViewModel(api: apiSemRede, emailInicial: "prof@exemplo.test")
        #expect(await vmSemRede.solicitarRecuperacao() == nil)
        #expect(vmSemRede.erro == MensagemDoErroAPI.texto(ErroDaApi(codigo: .semRede)))
        #expect(vmSemRede.mensagemNeutra == nil)

        let api429 = ApiComErroDeSenha(erro: ErroDaApi(codigo: .limiteExcedido, codigoOriginal: "over_email_send_rate_limit"))
        let vm429 = RecuperacaoSenhaViewModel(api: api429, emailInicial: "prof@exemplo.test")
        #expect(await vm429.solicitarRecuperacao() == nil)
        #expect(vm429.erro == MensagemDoErroAPI.texto(ErroDaApi(codigo: .limiteExcedido)))
        #expect(vm429.mensagemNeutra == nil)
    }

    @Test("Retorno tardio ou cancelado na recuperação não muta estado nem entrega avanço obsoleto")
    @MainActor
    func recuperacaoRetornoTardioNaoInvadeEstado() async {
        let api = ApiSenhaLentaControlada()
        let vm = RecuperacaoSenhaViewModel(api: api, emailInicial: "prof@exemplo.test")

        let tarefa = Task { @MainActor in
            await vm.solicitarRecuperacao()
        }
        await api.esperarInicioDaChamada()

        vm.cancelarTentativaAtual()
        tarefa.cancel()
        await api.concluirComSucesso()

        let resultado = await tarefa.value
        #expect(resultado == nil)
        #expect(vm.erro == nil)
        #expect(vm.mensagemNeutra == nil)
        #expect(vm.carregando == false)
    }

    // MARK: - SupabaseApiCliente (HTTP stub + FilaDeSessao)

    @Test("Recuperação envia create_user:false no envio e no reenvio, preservando OTP de entrada com create_user:true")
    @MainActor
    func supabaseRecuperacaoEnviaCreateUserFalseNoEnvioEReenvio() async throws {
        let roteiro = RoteiroDeSenha()
        let (cliente, _) = Self.criarClienteSupabase(roteiro: roteiro)

        // 1. Entrada/cadastro por OTP preserva create_user: true
        let entradaVM = EntradaViewModel(api: cliente, emailInicial: "novo@exemplo.test")
        #expect(await entradaVM.solicitarCodigo() == true)
        #expect(roteiro.corposDoOTP.last?["create_user"] as? Bool == true)

        // 2. Envio de recuperação envia create_user: false
        let recuperacaoVM = RecuperacaoSenhaViewModel(api: cliente, emailInicial: "prof@exemplo.test")
        #expect(await recuperacaoVM.solicitarRecuperacao() == .avancarParaCodigo(email: "prof@exemplo.test"))
        #expect(roteiro.corposDoOTP.last?["create_user"] as? Bool == false)

        // 3. Reenvio na tela de código em modo .recuperacao também envia create_user: false
        let codigoVM = CodigoViewModel(api: cliente, email: "prof@exemplo.test", modo: .recuperacao)
        codigoVM.segundosRestantes = 0
        await codigoVM.reenviarCodigo()
        #expect(roteiro.corposDoOTP.count == 3)
        #expect(roteiro.corposDoOTP.last?["create_user"] as? Bool == false)

        // 4. Quando GoTrue recusa criação (422 otp_disabled), RecuperacaoSenhaViewModel mostra estado neutro sem avançar
        roteiro.respostaOTP = .http(422, #"{"error_code":"otp_disabled","msg":"Signups not allowed for otp"}"#)
        let vmInexistente = RecuperacaoSenhaViewModel(api: cliente, emailInicial: "socialonly@exemplo.test")
        #expect(await vmInexistente.solicitarRecuperacao() == .estadoNeutro)
        #expect(vmInexistente.mensagemNeutra != nil)
        #expect(vmInexistente.erro == nil)
        #expect(cliente.haSessaoGuardada == false)

        // 5. 429 no GoTrue não é escondido pelo estado neutro
        roteiro.respostaOTP = .http(429, #"{"error_code":"over_email_send_rate_limit","msg":"Rate limit exceeded"}"#)
        let vm429 = RecuperacaoSenhaViewModel(api: cliente, emailInicial: "prof@exemplo.test")
        #expect(await vm429.solicitarRecuperacao() == nil)
        #expect(vm429.erro == MensagemDoErroAPI.texto(ErroDaApi(codigo: .limiteExcedido)))
        #expect(vm429.mensagemNeutra == nil)
    }

    @Test("SupabaseApiCliente.entrarComSenha chama autenticar-senha, guarda sessão e mapeia credenciais_invalidas")
    func supabaseEntrarComSenhaEInvalidCredentials() async throws {
        let roteiro = RoteiroDeSenha()
        let armazenamentoDispositivo = ArmazenamentoDeDeviceTokenEmMemoria()
        let (cliente, _) = Self.criarClienteSupabase(roteiro: roteiro, armazenamentoDeDispositivo: armazenamentoDispositivo)

        // 1. Credenciais inválidas (HTTP 401 credenciais_invalidas) não abrem sessão
        roteiro.respostaAutenticarSenha = .http(401, #"{"code":"credenciais_invalidas","message":"Credenciais inválidas"}"#)
        do {
            _ = try await cliente.entrarComSenha(email: "prof@exemplo.test", senha: "errada")
            Issue.record("Esperava erro de credenciais inválidas")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .naoAutenticado)
            #expect(erro.codigoOriginal == "credenciais_invalidas")
        }
        #expect(cliente.haSessaoGuardada == false)

        // 2. Credenciais válidas chamam /functions/v1/autenticar-senha com plataforma=ios e gravam a sessão
        roteiro.respostaAutenticarSenha = .http(
            200,
            #"{"status":"autenticado","sessao":\#(RoteiroDeSenha.sessao("token-senha-1")),"precisa_definir_senha":false}"#
        )
        let resultado = try await cliente.entrarComSenha(email: "prof@exemplo.test", senha: "SenhaValida#2026")
        #expect(resultado == .autenticado(precisaDefinirSenha: false))
        #expect(cliente.haSessaoGuardada == true)
        #expect(roteiro.corposAutenticarSenha.last?["plataforma"] as? String == "ios")
    }

    @Test("SupabaseApiCliente.definirSenha atualiza via Edge Function e preserva sessão em reautenticacao_necessaria")
    func supabaseDefinirSenhaPreservaSessao() async throws {
        let roteiro = RoteiroDeSenha()
        let armazenamentoDispositivo = ArmazenamentoDeDeviceTokenEmMemoria()
        try armazenamentoDispositivo.salvar(token: "dev-token-1", email: "prof@exemplo.test")
        let (cliente, _) = Self.criarClienteSupabase(roteiro: roteiro, armazenamentoDeDispositivo: armazenamentoDispositivo)

        try await cliente.verificarCodigo(email: "prof@exemplo.test", codigo: "123456")
        #expect(cliente.haSessaoGuardada == true)

        // 1. reautenticacao_necessaria (401) NÃO encerra a sessão
        roteiro.respostaDefinirSenha = .http(401, #"{"code":"reautenticacao_necessaria","message":"Reautenticação necessária"}"#)
        do {
            try await cliente.definirSenha("NovaSenha#2026", manterDispositivoAtual: false)
            Issue.record("Esperava erro reautenticacao_necessaria")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .naoAutenticado)
            #expect(erro.codigoOriginal == "reautenticacao_necessaria")
        }
        #expect(cliente.haSessaoGuardada == true)

        // 2. Sucesso em POST /functions/v1/definir-senha usa o Bearer da sessão atual e revoga token local quando manterDispositivoAtual=false
        roteiro.respostaDefinirSenha = .http(200, #"{"ok":true,"precisa_definir_senha":false,"dispositivos_revogados":1,"sessao":null}"#)
        try await cliente.definirSenha("NovaSenha#2026", manterDispositivoAtual: false)
        #expect(roteiro.autorizacoesDoDefinirSenha.last == "Bearer token-otp-1")
        #expect(cliente.haSessaoGuardada == true)
        #expect(armazenamentoDispositivo.obter(email: "prof@exemplo.test") == nil)
    }

    @Test("401 atrasado de uma sessão antiga não derruba a sessão nova criada por entrarComSenha")
    func erro401AntigoNaoDerrubaNovaSessaoComSenha() async throws {
        let roteiro = RoteiroDeSenha()
        let (cliente, _) = Self.criarClienteSupabase(roteiro: roteiro)

        // Sessão A via OTP
        try await cliente.verificarCodigo(email: "prof@exemplo.test", codigo: "123456")
        #expect(cliente.haSessaoGuardada == true)

        // Segura a RPC iniciada sob a sessão A
        roteiro.segurarRPCs()
        let tarefaRpcAntiga = Task {
            try? await cliente.minhaConta()
        }
        await roteiro.esperarChegadaDeRPC()

        // Nova entrada via senha cria Sessão B
        roteiro.respostaAutenticarSenha = .http(
            200,
            #"{"status":"autenticado","sessao":\#(RoteiroDeSenha.sessao("token-senha-nova")),"precisa_definir_senha":false}"#
        )
        _ = try await cliente.entrarComSenha(email: "prof@exemplo.test", senha: "SenhaValida#2026")

        // Agora a RPC da sessão A volta com 401/nao_autenticado
        roteiro.liberarRPCs(com: .http(401, #"{"code":"nao_autenticado","message":"nao_autenticado","details":null,"hint":null}"#))
        _ = await tarefaRpcAntiga.value

        // A sessão B precisa continuar intacta!
        #expect(cliente.haSessaoGuardada == true)
        #expect(roteiro.logouts == 0)
    }

    @Test("DispositivoNoKeychainDoAparelho isola por conta e grava com AfterFirstUnlockThisDeviceOnly")
    func dispositivoKeychainIsolamentoEProtecao() throws {
        let fake = OperacoesKeychainEmMemoria()
        let storage = DispositivoNoKeychainDoAparelho(operacoes: fake)

        try storage.salvar(token: "tok-a", email: "  Alice@Exemplo.Test ")
        try storage.salvar(token: "tok-b", email: "bob@exemplo.test")

        #expect(storage.obter(email: "alice@exemplo.test") == "tok-a")
        #expect(storage.obter(email: "bob@exemplo.test") == "tok-b")
        #expect(storage.classeDeAcesso(email: "alice@exemplo.test") == (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String))

        storage.remover(email: "alice@exemplo.test")
        #expect(storage.obter(email: "alice@exemplo.test") == nil)
        #expect(storage.obter(email: "bob@exemplo.test") == "tok-b")

        storage.removerTodos()
        #expect(storage.obter(email: "bob@exemplo.test") == nil)
    }

    @Test("Confiança 30d: desafio OTP, opt-in Keychain, logout normal preserva e revogar-dispositivos limpa")
    func fluxoCompletoDispositivo30Dias() async throws {
        let roteiro = RoteiroDeSenha()
        let armazenamentoDispositivo = ArmazenamentoDeDeviceTokenEmMemoria()
        let (cliente, _) = Self.criarClienteSupabase(roteiro: roteiro, armazenamentoDeDispositivo: armazenamentoDispositivo)

        // 1. Dispositivo novo sem token -> desafio_otp
        roteiro.respostaAutenticarSenha = .http(
            200,
            #"{"status":"desafio_otp","desafio_id":"des-1","expira_em":"2026-11-25T12:00:00Z","descartar_device_token":false}"#
        )
        let res1 = try await cliente.entrarComSenha(email: "prof@exemplo.test", senha: "SenhaValida#2026")
        #expect(res1 == .desafioOTP(desafioID: "des-1", expiraEm: ContratoAPI.instante("2026-11-25T12:00:00Z")))
        #expect(cliente.haSessaoGuardada == false)

        // 2. Reenvio mantém desafio_id
        roteiro.respostaReenviarOTP = .http(
            200,
            #"{"ok":true,"desafio_id":"des-1","expira_em":"2026-11-25T12:10:00Z","reenviar_em_segundos":45}"#
        )
        let reenvio = try await cliente.reenviarDispositivoOTP(desafioID: "des-1")
        #expect(reenvio.desafioID == "des-1")
        #expect(reenvio.reenviarEmSegundos == 45)

        // 3. Confirmação com lembrar_dispositivo=true grava device_token
        roteiro.respostaConfirmarOTP = .http(
            200,
            #"{"sessao":\#(RoteiroDeSenha.sessao("token-conf-1")),"precisa_definir_senha":false,"device_token":"tok-30d-xyz"}"#
        )
        let conf = try await cliente.confirmarDispositivoOTP(
            origem: .loginDispositivo(desafioID: "des-1"),
            codigo: "123456",
            lembrarDispositivo: true
        )
        #expect(conf == ResultadoConfirmacaoDispositivoOTP(precisaDefinirSenha: false, dispositivoLembrado: true))
        #expect(armazenamentoDispositivo.obter(email: "prof@exemplo.test") == "tok-30d-xyz")
        #expect(cliente.haSessaoGuardada == true)

        // 4. Logout normal encerra sessão local e PRESERVA device_token
        await cliente.sair(tokenFCM: nil)
        #expect(cliente.haSessaoGuardada == false)
        #expect(armazenamentoDispositivo.obter(email: "prof@exemplo.test") == "tok-30d-xyz")

        // 5. Próximo login envia device_token; se servidor mandar descartar_device_token=true, apaga do Keychain
        roteiro.respostaAutenticarSenha = .http(
            200,
            #"{"status":"desafio_otp","desafio_id":"des-2","expira_em":"2026-11-25T12:30:00Z","descartar_device_token":true}"#
        )
        _ = try await cliente.entrarComSenha(email: "prof@exemplo.test", senha: "SenhaValida#2026")
        #expect(roteiro.corposAutenticarSenha.last?["device_token"] as? String == "tok-30d-xyz")
        #expect(armazenamentoDispositivo.obter(email: "prof@exemplo.test") == nil)

        // 6. Confirmação sem lembrar não grava token; com definir-senha(manterDispositivoAtual: true) mantém token
        try armazenamentoDispositivo.salvar(token: "tok-30d-manter", email: "prof@exemplo.test")
        roteiro.respostaConfirmarOTP = .http(
            200,
            #"{"sessao":\#(RoteiroDeSenha.sessao("token-conf-2")),"precisa_definir_senha":true,"device_token":null}"#
        )
        let confSemLembrar = try await cliente.confirmarDispositivoOTP(
            origem: .recuperacao(email: "prof@exemplo.test"),
            codigo: "654321",
            lembrarDispositivo: false
        )
        #expect(confSemLembrar == ResultadoConfirmacaoDispositivoOTP(precisaDefinirSenha: true, dispositivoLembrado: false))

        roteiro.respostaDefinirSenha = .http(200, #"{"ok":true,"precisa_definir_senha":false,"dispositivos_revogados":2,"sessao":null}"#)
        try await cliente.definirSenha("NovaSenha#2026", manterDispositivoAtual: true)
        #expect(roteiro.corposDefinirSenha.last?["manter_dispositivo_atual"] as? Bool == true)
        #expect(roteiro.corposDefinirSenha.last?["device_token_atual"] as? String == "tok-30d-manter")
        #expect(armazenamentoDispositivo.obter(email: "prof@exemplo.test") == "tok-30d-manter")

        // 7. revogar-dispositivos apaga token local
        roteiro.respostaRevogarDispositivos = .http(200, #"{"ok":true,"dispositivos_revogados":2}"#)
        let revogados = try await cliente.revogarDispositivos()
        #expect(revogados == 2)
        #expect(armazenamentoDispositivo.obter(email: "prof@exemplo.test") == nil)

        // 8. estado_autenticacao decodifica precisa_definir_senha e dispositivo_verificado
        roteiro.respostaEstadoAutenticacao = .http(
            200,
            #"{"autenticado":true,"dispositivo_verificado":true,"precisa_definir_senha":true,"tem_conta":true}"#
        )
        let estado = try await cliente.estadoAutenticacao()
        #expect(estado == EstadoAutenticacao(autenticado: true, dispositivoVerificado: true, precisaDefinirSenha: true, temConta: true))
    }

    @Test("EntradaComSenhaViewModel encaminha desafio_otp e definirSenhaObrigatoria")
    @MainActor
    func viewModelEntradaComSenhaDesafioEPendencia() async throws {
        let roteiro = RoteiroDeSenha()
        let (cliente, _) = Self.criarClienteSupabase(roteiro: roteiro)

        roteiro.respostaAutenticarSenha = .http(
            200,
            #"{"status":"desafio_otp","desafio_id":"des-vm-1","expira_em":"2026-11-25T12:00:00Z","descartar_device_token":false}"#
        )
        let vm = EntradaComSenhaViewModel(api: cliente, emailInicial: "prof@exemplo.test")
        vm.senha = "SenhaValida#2026"
        let resDesafio = await vm.entrar()
        #expect(resDesafio == .desafioOTP(email: "prof@exemplo.test", desafioID: "des-vm-1"))
        #expect(vm.senha.isEmpty)

        // Agora com precisa_definir_senha=true e conta retornando profissional
        let apiComPendencia = ApiPendenciaSenha()
        let vmPendencia = EntradaComSenhaViewModel(api: apiComPendencia, emailInicial: "prof@exemplo.test")
        vmPendencia.senha = "SenhaValida#2026"
        let resPendencia = await vmPendencia.entrar()
        #expect(resPendencia == .definirSenha(.destino(.profissional)))
    }

    @Test("CodigoViewModel em loginDispositivo confirma com lembrarDispositivo, reenvia e trata desafio_expirado/usado")
    @MainActor
    func codigoViewModelLoginDispositivo() async throws {
        let roteiro = RoteiroDeSenha()
        let armazenamentoDispositivo = ArmazenamentoDeDeviceTokenEmMemoria()
        let (cliente, _) = Self.criarClienteSupabase(roteiro: roteiro, armazenamentoDeDispositivo: armazenamentoDispositivo)

        let vm = CodigoViewModel(api: cliente, email: "prof@exemplo.test", modo: .loginDispositivo(desafioID: "des-1"))
        vm.lembrarDispositivo = true
        vm.segundosRestantes = 0

        roteiro.respostaReenviarOTP = .http(
            200,
            #"{"ok":true,"desafio_id":"des-2","expira_em":"2026-11-25T12:15:00Z","reenviar_em_segundos":30}"#
        )
        await vm.reenviarCodigo()
        #expect(vm.erro == nil)
        #expect(vm.segundosRestantes == 30)
        #expect(vm.reenviosFeitos == 1)
        #expect(vm.mensagemInformativa != nil)

        vm.segundosRestantes = 0
        roteiro.respostaReenviarOTP = .http(
            429,
            #"{"code":"limite_excedido","message":"Muitas tentativas"}"#
        )
        await vm.reenviarCodigo()
        #expect(vm.erro != nil)
        #expect(vm.reenviosFeitos == 1)
        #expect(vm.segundosRestantes == 0)

        roteiro.respostaConfirmarOTP = .http(409, #"{"code":"desafio_ja_usado","message":"Já usado"}"#)
        vm.codigo = "123456"
        #expect(await vm.confirmarCodigo() == nil)
        #expect(vm.erro != nil)

        roteiro.respostaConfirmarOTP = .http(410, #"{"code":"desafio_expirado","message":"Expirado"}"#)
        #expect(await vm.confirmarCodigo() == nil)
        #expect(vm.erro != nil)

        roteiro.respostaConfirmarOTP = .http(
            200,
            #"{"sessao":\#(RoteiroDeSenha.sessao("token-conf-vm")),"precisa_definir_senha":false,"device_token":"tok-vm-30d"}"#
        )
        let apiProf = ApiConfirmacaoComPerfil(base: cliente)
        let vmOk = CodigoViewModel(api: apiProf, email: "prof@exemplo.test", modo: .loginDispositivo(desafioID: "des-2"))
        vmOk.lembrarDispositivo = true
        vmOk.codigo = "654321"
        let destino = await vmOk.confirmarCodigo()
        #expect(destino == .destino(.profissional))
        #expect(vmOk.dispositivoLembradoNaConfirmacao == true)
        #expect(armazenamentoDispositivo.obter(email: "prof@exemplo.test") == "tok-vm-30d")
    }

    private static func criarClienteSupabase(
        roteiro: RoteiroDeSenha,
        armazenamentoDeDispositivo: ArmazenamentoDeDeviceTokenEmMemoria = ArmazenamentoDeDeviceTokenEmMemoria()
    ) -> (SupabaseApiCliente, ArmazenamentoDeSessaoEmMemoria) {
        let host = "senha-\(UUID().uuidString.lowercased()).frila.test"
        StubDeAuthSenha.registrar(roteiro, host: host)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubDeAuthSenha.self]
        let sessaoHTTP = URLSession(configuration: config)
        let armazenamento = ArmazenamentoDeSessaoEmMemoria()
        let cliente = SupabaseApiCliente(
            url: URL(string: "https://\(host)")!,
            chavePublicavel: "chave-sintetica-teste",
            telemetria: TelemetryNula(),
            sessaoHTTP: sessaoHTTP,
            armazenamentoDaSessao: armazenamento,
            armazenamentoDeDispositivo: armazenamentoDeDispositivo
        )
        return (cliente, armazenamento)
    }
}

// MARK: - Dublês de suporte

private final class ApiComErroDeSenha: ApiClienteEncaminhador, @unchecked Sendable {
    private let erro: ErroDaApi
    init(erro: ErroDaApi) {
        self.erro = erro
        super.init(base: ApiClienteEmMemoria(cenario: .sucesso, sessaoAtivaInicial: true))
    }

    override func entrarComSenha(email: String, senha: String) async throws -> ResultadoEntradaComSenha {
        throw erro
    }

    override func definirSenha(_ novaSenha: String, manterDispositivoAtual: Bool) async throws {
        throw erro
    }

    override func solicitarCodigoDeRecuperacao(email: String) async throws {
        throw erro
    }
}

private final class ApiSenhaLentaControlada: ApiClienteEncaminhador, @unchecked Sendable {
    private let iniciou: AsyncStream<Void>
    private let avisarInicio: AsyncStream<Void>.Continuation
    private let trava = NSLock()
    private var continuacao: CheckedContinuation<Void, Error>?

    init() {
        (iniciou, avisarInicio) = AsyncStream<Void>.makeStream()
        super.init(base: ApiClienteEmMemoria(cenario: .sucesso, sessaoAtivaInicial: false))
    }

    override func entrarComSenha(email: String, senha: String) async throws -> ResultadoEntradaComSenha {
        try await withCheckedThrowingContinuation { cont in
            trava.withLock { continuacao = cont }
            avisarInicio.yield()
        }
        return .autenticado(precisaDefinirSenha: false)
    }

    override func solicitarCodigoDeRecuperacao(email: String) async throws {
        try await withCheckedThrowingContinuation { cont in
            trava.withLock { continuacao = cont }
            avisarInicio.yield()
        }
    }

    func esperarInicioDaChamada() async {
        for await _ in iniciou { return }
    }

    func concluirCom(erro: Error) async {
        let cont = trava.withLock { () -> CheckedContinuation<Void, Error>? in
            defer { continuacao = nil }
            return continuacao
        }
        cont?.resume(throwing: erro)
    }

    func concluirComSucesso() async {
        let cont = trava.withLock { () -> CheckedContinuation<Void, Error>? in
            defer { continuacao = nil }
            return continuacao
        }
        cont?.resume()
    }
}

private final class RoteiroDeSenha: @unchecked Sendable {
    enum Resposta: Sendable {
        case http(Int, String)
    }

    private let trava = NSLock()
    private var _respostaOTP: Resposta = .http(200, "{}")
    private var _respostaToken: Resposta = .http(200, RoteiroDeSenha.sessao("token-senha-1"))
    private var _respostaUpdateUser: Resposta = .http(200, RoteiroDeSenha.usuarioJSON)
    private var _respostaAutenticarSenha: Resposta = .http(
        200,
        #"{"status":"autenticado","sessao":\#(RoteiroDeSenha.sessao("token-senha-1")),"precisa_definir_senha":false}"#
    )
    private var _respostaConfirmarOTP: Resposta = .http(
        200,
        #"{"sessao":\#(RoteiroDeSenha.sessao("token-otp-1")),"precisa_definir_senha":false,"device_token":null}"#
    )
    private var _respostaReenviarOTP: Resposta = .http(
        200,
        #"{"ok":true,"desafio_id":"des-1","expira_em":"2026-11-25T12:10:00Z","reenviar_em_segundos":60}"#
    )
    private var _respostaDefinirSenha: Resposta = .http(200, #"{"ok":true,"precisa_definir_senha":false,"dispositivos_revogados":1,"sessao":null}"#)
    private var _respostaRevogarDispositivos: Resposta = .http(200, #"{"ok":true,"dispositivos_revogados":1}"#)
    private var _respostaEstadoAutenticacao: Resposta = .http(
        200,
        #"{"autenticado":true,"dispositivo_verificado":true,"precisa_definir_senha":false,"tem_conta":true}"#
    )
    private var _corposDoOTP: [[String: Any]] = []
    private var _corposAutenticarSenha: [[String: Any]] = []
    private var _corposDefinirSenha: [[String: Any]] = []
    private var _queriesDeToken: [String] = []
    private var _autorizacoesDoUpdateUser: [String] = []
    private var _autorizacoesDoDefinirSenha: [String] = []
    private var _logouts = 0
    private var _segurarRPC = false
    private var retidas: [URLProtocol] = []
    private let chegadasRPC: AsyncStream<Void>
    private let avisarChegadaRPC: AsyncStream<Void>.Continuation

    init() {
        (chegadasRPC, avisarChegadaRPC) = AsyncStream<Void>.makeStream()
    }

    var respostaOTP: Resposta {
        get { trava.withLock { _respostaOTP } }
        set { trava.withLock { _respostaOTP = newValue } }
    }

    var respostaToken: Resposta {
        get { trava.withLock { _respostaToken } }
        set { trava.withLock { _respostaToken = newValue } }
    }

    var respostaUpdateUser: Resposta {
        get { trava.withLock { _respostaUpdateUser } }
        set { trava.withLock { _respostaUpdateUser = newValue } }
    }

    var respostaAutenticarSenha: Resposta {
        get { trava.withLock { _respostaAutenticarSenha } }
        set { trava.withLock { _respostaAutenticarSenha = newValue } }
    }

    var respostaConfirmarOTP: Resposta {
        get { trava.withLock { _respostaConfirmarOTP } }
        set { trava.withLock { _respostaConfirmarOTP = newValue } }
    }

    var respostaReenviarOTP: Resposta {
        get { trava.withLock { _respostaReenviarOTP } }
        set { trava.withLock { _respostaReenviarOTP = newValue } }
    }

    var respostaDefinirSenha: Resposta {
        get { trava.withLock { _respostaDefinirSenha } }
        set { trava.withLock { _respostaDefinirSenha = newValue } }
    }

    var respostaRevogarDispositivos: Resposta {
        get { trava.withLock { _respostaRevogarDispositivos } }
        set { trava.withLock { _respostaRevogarDispositivos = newValue } }
    }

    var respostaEstadoAutenticacao: Resposta {
        get { trava.withLock { _respostaEstadoAutenticacao } }
        set { trava.withLock { _respostaEstadoAutenticacao = newValue } }
    }

    var corposDoOTP: [[String: Any]] { trava.withLock { _corposDoOTP } }
    func registrarCorpoDoOTP(_ dados: Data?) {
        guard let dados,
              let json = try? JSONSerialization.jsonObject(with: dados) as? [String: Any] else { return }
        trava.withLock { _corposDoOTP.append(json) }
    }

    var corposAutenticarSenha: [[String: Any]] { trava.withLock { _corposAutenticarSenha } }
    func registrarCorpoAutenticarSenha(_ dados: Data?) {
        guard let dados,
              let json = try? JSONSerialization.jsonObject(with: dados) as? [String: Any] else { return }
        trava.withLock { _corposAutenticarSenha.append(json) }
    }

    var corposDefinirSenha: [[String: Any]] { trava.withLock { _corposDefinirSenha } }
    func registrarCorpoDefinirSenha(_ dados: Data?) {
        guard let dados,
              let json = try? JSONSerialization.jsonObject(with: dados) as? [String: Any] else { return }
        trava.withLock { _corposDefinirSenha.append(json) }
    }

    var queriesDeToken: [String] { trava.withLock { _queriesDeToken } }
    func registrarQueryDeToken(_ q: String?) { trava.withLock { _queriesDeToken.append(q ?? "") } }

    var autorizacoesDoUpdateUser: [String] { trava.withLock { _autorizacoesDoUpdateUser } }
    func registrarAutorizacaoDoUpdateUser(_ valor: String?) { trava.withLock { _autorizacoesDoUpdateUser.append(valor ?? "") } }

    var autorizacoesDoDefinirSenha: [String] { trava.withLock { _autorizacoesDoDefinirSenha } }
    func registrarAutorizacaoDoDefinirSenha(_ valor: String?) { trava.withLock { _autorizacoesDoDefinirSenha.append(valor ?? "") } }

    var logouts: Int { trava.withLock { _logouts } }
    func contarLogout() { trava.withLock { _logouts += 1 } }

    func segurarRPCs() { trava.withLock { _segurarRPC = true } }

    func reter(_ protocolo: URLProtocol) -> Bool {
        let reteve = trava.withLock { () -> Bool in
            guard _segurarRPC else { return false }
            retidas.append(protocolo)
            return true
        }
        if reteve { avisarChegadaRPC.yield() }
        return reteve
    }

    func esperarChegadaDeRPC() async {
        for await _ in chegadasRPC { return }
    }

    func liberarRPCs(com resposta: Resposta) {
        let protocolos = trava.withLock { () -> [URLProtocol] in
            let todos = retidas
            retidas = []
            _segurarRPC = false
            return todos
        }
        for protocolo in protocolos { StubDeAuthSenha.responder(protocolo, com: resposta) }
    }

    static let usuarioJSON = #"{"id":"8f1d6c2e-0000-4000-8000-000000000001","email":"prof@exemplo.test","aud":"authenticated","app_metadata":{},"user_metadata":{},"created_at":"2026-09-27T00:00:00Z","updated_at":"2026-09-27T00:00:00Z"}"#

    static func sessao(_ token: String) -> String {
        let expiraEm = Int(Date().timeIntervalSince1970) + 3600
        return #"{"access_token":"\#(token)","token_type":"bearer","expires_in":3600,"expires_at":\#(expiraEm),"refresh_token":"r-\#(token)","user":\#(usuarioJSON)}"#
    }
}

private final class StubDeAuthSenha: URLProtocol {
    private static let trava = NSLock()
    nonisolated(unsafe) private static var roteiros: [String: RoteiroDeSenha] = [:]

    static func registrar(_ roteiro: RoteiroDeSenha, host: String) {
        trava.withLock { roteiros[host] = roteiro }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host,
              let roteiro = Self.trava.withLock({ Self.roteiros[host] }) else {
            Self.responder(self, com: .http(500, "{}"))
            return
        }
        switch url.path {
        case "/auth/v1/otp":
            roteiro.registrarCorpoDoOTP(Self.lerCorpo(request))
            Self.responder(self, com: roteiro.respostaOTP)
        case "/auth/v1/verify":
            Self.responder(self, com: .http(200, RoteiroDeSenha.sessao("token-otp-1")))
        case "/auth/v1/token":
            roteiro.registrarQueryDeToken(url.query)
            Self.responder(self, com: roteiro.respostaToken)
        case "/auth/v1/user":
            roteiro.registrarAutorizacaoDoUpdateUser(request.value(forHTTPHeaderField: "Authorization"))
            Self.responder(self, com: roteiro.respostaUpdateUser)
        case "/auth/v1/logout":
            roteiro.contarLogout()
            Self.responder(self, com: .http(204, ""))
        case "/functions/v1/autenticar-senha":
            roteiro.registrarCorpoAutenticarSenha(Self.lerCorpo(request))
            Self.responder(self, com: roteiro.respostaAutenticarSenha)
        case "/functions/v1/confirmar-dispositivo-otp":
            Self.responder(self, com: roteiro.respostaConfirmarOTP)
        case "/functions/v1/reenviar-dispositivo-otp":
            Self.responder(self, com: roteiro.respostaReenviarOTP)
        case "/functions/v1/definir-senha":
            roteiro.registrarAutorizacaoDoDefinirSenha(request.value(forHTTPHeaderField: "Authorization"))
            roteiro.registrarCorpoDefinirSenha(Self.lerCorpo(request))
            Self.responder(self, com: roteiro.respostaDefinirSenha)
        case "/functions/v1/revogar-dispositivos":
            Self.responder(self, com: roteiro.respostaRevogarDispositivos)
        case "/rest/v1/rpc/estado_autenticacao":
            if !roteiro.reter(self) { Self.responder(self, com: roteiro.respostaEstadoAutenticacao) }
        case let caminho where caminho.hasPrefix("/rest/v1/rpc/"):
            if !roteiro.reter(self) { Self.responder(self, com: .http(200, "{}")) }
        default:
            Self.responder(self, com: .http(500, "{}"))
        }
    }

    override func stopLoading() {}

    private static func lerCorpo(_ request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var dados = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let lidos = stream.read(&buffer, maxLength: buffer.count)
            if lidos <= 0 { break }
            dados.append(buffer, count: lidos)
        }
        return dados.isEmpty ? nil : dados
    }

    static func responder(_ protocolo: URLProtocol, com resposta: RoteiroDeSenha.Resposta) {
        switch resposta {
        case let .http(status, corpo):
            let http = HTTPURLResponse(
                url: protocolo.request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            protocolo.client?.urlProtocol(protocolo, didReceive: http, cacheStoragePolicy: .notAllowed)
            protocolo.client?.urlProtocol(protocolo, didLoad: Data(corpo.utf8))
            protocolo.client?.urlProtocolDidFinishLoading(protocolo)
        }
    }
}

private final class OperacoesKeychainEmMemoria: OperacoesDoKeychainDaSessao, @unchecked Sendable {
    private let trava = NSLock()
    private var itens: [[String: Any]] = []

    func secItemAdd(_ attributes: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        guard let dict = attributes as? [String: Any] else { return errSecParam }
        return trava.withLock {
            itens.append(dict)
            return errSecSuccess
        }
    }

    func secItemCopyMatching(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        guard let q = query as? [String: Any] else { return errSecParam }
        let servico = q[kSecAttrService as String] as? String
        let conta = q[kSecAttrAccount as String] as? String
        return trava.withLock {
            guard let item = itens.first(where: {
                ($0[kSecAttrService as String] as? String) == servico
                    && (conta == nil || ($0[kSecAttrAccount as String] as? String) == conta)
            }) else {
                return errSecItemNotFound
            }
            if (q[kSecReturnAttributes as String] as? Bool) == true {
                result?.pointee = item as CFDictionary
            } else if (q[kSecReturnData as String] as? Bool) == true {
                result?.pointee = item[kSecValueData as String] as CFTypeRef
            }
            return errSecSuccess
        }
    }

    func secItemDelete(_ query: CFDictionary) -> OSStatus {
        guard let q = query as? [String: Any] else { return errSecParam }
        let servico = q[kSecAttrService as String] as? String
        let conta = q[kSecAttrAccount as String] as? String
        return trava.withLock {
            let antes = itens.count
            itens.removeAll {
                ($0[kSecAttrService as String] as? String) == servico
                    && (conta == nil || ($0[kSecAttrAccount as String] as? String) == conta)
            }
            return itens.count < antes ? errSecSuccess : errSecItemNotFound
        }
    }
}

private final class ApiPendenciaSenha: ApiClienteEncaminhador, @unchecked Sendable {
    init() {
        super.init(base: ApiClienteEmMemoria(cenario: .sucesso, sessaoAtivaInicial: false))
    }

    override func entrarComSenha(email: String, senha: String) async throws -> ResultadoEntradaComSenha {
        .autenticado(precisaDefinirSenha: true)
    }
}

private final class ApiConfirmacaoComPerfil: ApiClienteEncaminhador, @unchecked Sendable {
    private let supabase: SupabaseApiCliente

    init(base supabase: SupabaseApiCliente) {
        self.supabase = supabase
        super.init(base: ApiClienteEmMemoria(cenario: .sucesso, sessaoAtivaInicial: true))
    }

    override func confirmarDispositivoOTP(
        origem: OrigemConfirmacaoDispositivoOTP,
        codigo: String,
        lembrarDispositivo: Bool
    ) async throws -> ResultadoConfirmacaoDispositivoOTP {
        try await supabase.confirmarDispositivoOTP(
            origem: origem,
            codigo: codigo,
            lembrarDispositivo: lembrarDispositivo
        )
    }
}

@Suite("RegraDeRevelacaoBreveDeSenha")
struct RegraDeRevelacaoBreveDeSenhaTests {
    @Test("revela apenas insercao de um grafema com selecao colapsada e suporta meio, acento composto e emoji")
    func revelaUmGrafemaFimMeioEComposto() {
        let fim = RegraDeRevelacaoBreveDeSenha.trechoRecemDigitado(
            textoAnterior: "aaaa",
            intervaloSubstituidoUTF16: NSRange(location: 4, length: 0),
            substituicao: "a",
            emComposicaoIME: false,
            emColagem: false
        )
        #expect(fim == TrechoReveladoDeSenha(intervaloUTF16: NSRange(location: 4, length: 1), caractere: "a"))

        let meio = RegraDeRevelacaoBreveDeSenha.trechoRecemDigitado(
            textoAnterior: "aaaa",
            intervaloSubstituidoUTF16: NSRange(location: 2, length: 0),
            substituicao: "b",
            emComposicaoIME: false,
            emColagem: false
        )
        #expect(meio == TrechoReveladoDeSenha(intervaloUTF16: NSRange(location: 2, length: 1), caractere: "b"))

        let emoji = "👨‍👩‍👧"
        let resEmoji = RegraDeRevelacaoBreveDeSenha.trechoRecemDigitado(
            textoAnterior: "ab",
            intervaloSubstituidoUTF16: NSRange(location: 1, length: 0),
            substituicao: emoji,
            emComposicaoIME: false,
            emColagem: false
        )
        #expect(resEmoji == TrechoReveladoDeSenha(
            intervaloUTF16: NSRange(location: 1, length: (emoji as NSString).length),
            caractere: emoji
        ))
    }

    @Test("nao revela em delecao, colagem (inclusive 1 caractere), substituicao de selecao, multi-caractere ou IME")
    func naoRevelaEmCasosProibidos() {
        #expect(RegraDeRevelacaoBreveDeSenha.trechoRecemDigitado(
            textoAnterior: "abc",
            intervaloSubstituidoUTF16: NSRange(location: 2, length: 1),
            substituicao: "",
            emComposicaoIME: false,
            emColagem: false
        ) == nil)

        #expect(RegraDeRevelacaoBreveDeSenha.trechoRecemDigitado(
            textoAnterior: "abc",
            intervaloSubstituidoUTF16: NSRange(location: 3, length: 0),
            substituicao: "x",
            emComposicaoIME: false,
            emColagem: true
        ) == nil)

        #expect(RegraDeRevelacaoBreveDeSenha.trechoRecemDigitado(
            textoAnterior: "abc",
            intervaloSubstituidoUTF16: NSRange(location: 3, length: 0),
            substituicao: "xyz",
            emComposicaoIME: false,
            emColagem: false
        ) == nil)

        #expect(RegraDeRevelacaoBreveDeSenha.trechoRecemDigitado(
            textoAnterior: "abc",
            intervaloSubstituidoUTF16: NSRange(location: 1, length: 1),
            substituicao: "z",
            emComposicaoIME: false,
            emColagem: false
        ) == nil)

        #expect(RegraDeRevelacaoBreveDeSenha.trechoRecemDigitado(
            textoAnterior: "abc",
            intervaloSubstituidoUTF16: NSRange(location: 3, length: 0),
            substituicao: "a",
            emComposicaoIME: true,
            emColagem: false
        ) == nil)
    }
}
