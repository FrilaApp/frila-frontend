import Foundation
import FrilaApresentacao
import FrilaDados
import FrilaDominio
import FrilaInfraestrutura
import Testing

/// Testes unitários para o fluxo de verificação de maioridade 18+, Declared Age Range e proteção de menores (Cartão lJSyGK6q).
@Suite("Verificação de Maioridade 18+ (#lJSyGK6q)")
@MainActor
struct MaioridadeEVerificacaoDeIdadeTests {

    @Test("VerificadorDeIdadeDoSistema interpreta faixas etárias corretamente")
    func interpretarFaixasDeclaredAgeRange() {
        // Adultos (18 ou mais)
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: 18, upperBound: nil) == .dezoitoOuMais)
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: 21, upperBound: 25) == .dezoitoOuMais)
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: 18, upperBound: 18) == .dezoitoOuMais)

        // Menores de 18 anos
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: nil, upperBound: 17) == .abaixoDe18)
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: 13, upperBound: 17) == .abaixoDe18)
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: 10, upperBound: 16) == .abaixoDe18)

        // Indisponível / Inconclusivo
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: nil, upperBound: nil) == .indisponivel)
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: 16, upperBound: 20) == .indisponivel)
        #expect(VerificadorDeIdadeDoSistema.interpretarFaixa(lowerBound: nil, upperBound: 18) == .indisponivel)
    }

    @Test("VerificadorDeIdadeIndisponivel retorna .indisponivel como fallback seguro")
    func verificadorIndisponivelFallback() async {
        let verificador = VerificadorDeIdadeIndisponivel()
        let resultado = await verificador.verificarMaioridade()
        #expect(resultado == .indisponivel)
    }

    @Test("Cadastro bloqueia preventivamente no cliente quando a data de nascimento tem menos de 18 anos")
    func cadastroBloqueiaMenorPorDataDeNascimento() async {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let agora = Date(timeIntervalSince1970: 1_792_065_600) // Outubro/2026
        let relogioFixo = RelogioFixo(agora: agora)
        let vm = CadastroViewModel(api: api, email: "jovem@frila.app", relogio: relogioFixo)

        vm.nome = "Jovem Aprendiz"
        vm.telefone = "61999991111"
        // Data correspondente a menor de 18 anos em 2026
        vm.nascimentoTexto = "01/01/2012"
        vm.aceitouTermos = true

        let destino = await vm.criarConta()
        #expect(destino == nil)
        #expect(vm.erro == "O Frila é exclusivo para maiores de 18 anos.")
    }

    @Test("Cadastro bloqueia quando o Declared Age Range identifica usuário abaixo de 18")
    func cadastroBloqueiaMenorPorDeclaredAgeRange() async {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let verificador = VerificadorDeIdadeSimulado(resultado: .abaixoDe18)
        let vm = CadastroViewModel(api: api, email: "menor@frila.app", verificadorDeIdade: verificador)

        vm.nome = "Candidato Menor"
        vm.telefone = "61999992222"
        vm.nascimentoTexto = "01/01/2000" // Data declarada adulta
        vm.aceitouTermos = true

        let destino = await vm.criarConta()
        #expect(destino == nil)
        #expect(vm.erro == "O Frila é exclusivo para maiores de 18 anos.")
        #expect(verificador.chamadasAVerificar == 1)
    }

    @Test("Cadastro prossegue quando maior de 18 anos pela data e pelo Declared Age Range")
    func cadastroSucessoMaiorDeIdade() async {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let agora = Date(timeIntervalSince1970: 1_792_065_600) // Outubro/2026
        let relogioFixo = RelogioFixo(agora: agora)
        let verificador = VerificadorDeIdadeSimulado(resultado: .dezoitoOuMais)
        let vm = CadastroViewModel(api: api, email: "adulto@frila.app", relogio: relogioFixo, verificadorDeIdade: verificador)

        vm.nome = "Profissional Adulto"
        vm.telefone = "61999993333"
        vm.nascimentoTexto = "01/01/2000" // 26 anos
        vm.aceitouTermos = true

        let destino = await vm.criarConta()
        #expect(destino == .funcoesEHorarios)
        #expect(vm.erro == nil)
        #expect(verificador.chamadasAVerificar == 1)
    }

    @Test("Fallback: adulto com Declared Age Range indisponível ou recusado prossegue normalmente pela data de nascimento")
    func fallbackAdultoProssegueComVerificadorIndisponivelOuRecusado() async {
        let resultadosFallback: [ResultadoVerificacaoIdade] = [.indisponivel, .recusou]

        for resultado in resultadosFallback {
            let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
            let agora = Date(timeIntervalSince1970: 1_792_065_600)
            let relogioFixo = RelogioFixo(agora: agora)
            let verificador = VerificadorDeIdadeSimulado(resultado: resultado)
            let vm = CadastroViewModel(api: api, email: "adulto-\(resultado)@frila.app", relogio: relogioFixo, verificadorDeIdade: verificador)

            vm.nome = "Adulto Fallback"
            vm.telefone = "61999994444"
            vm.nascimentoTexto = "10/05/1995"
            vm.aceitouTermos = true

            let destino = await vm.criarConta()
            #expect(destino == .funcoesEHorarios, "Adulto com status \(resultado) não deve ficar sem saída")
            #expect(vm.erro == nil)
            #expect(verificador.chamadasAVerificar == 1)
        }
    }

    @Test("Fallback: menor de idade com Declared Age Range indisponível é bloqueado preventivamente pela data declarada")
    func fallbackMenorBloqueadoComVerificadorIndisponivel() async {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let agora = Date(timeIntervalSince1970: 1_792_065_600) // Outubro/2026
        let relogioFixo = RelogioFixo(agora: agora)
        let verificador = VerificadorDeIdadeSimulado(resultado: .indisponivel)
        let vm = CadastroViewModel(api: api, email: "menor-indisp@frila.app", relogio: relogioFixo, verificadorDeIdade: verificador)

        vm.nome = "Menor Fallback"
        vm.telefone = "61999995555"
        vm.nascimentoTexto = "15/10/2010" // 16 anos
        vm.aceitouTermos = true

        let destino = await vm.criarConta()
        #expect(destino == nil)
        #expect(vm.erro == "O Frila é exclusivo para maiores de 18 anos.")
    }

    @Test("Borda de aniversário de 18 anos: aniversariante de hoje passa e de amanhã é bloqueado")
    func bordaDoDiaDoAniversarioDe18Anos() async {
        // Fixa a data atual em 15/10/2026 às 12:00 UTC (horário em Brasília é 09:00 de 15/10/2026)
        let calendar = Calendar(identifier: .gregorian)
        var componentesHoje = DateComponents()
        componentesHoje.year = 2026
        componentesHoje.month = 10
        componentesHoje.day = 15
        componentesHoje.hour = 12
        componentesHoje.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        let hoje = calendar.date(from: componentesHoje)!
        let relogioHoje = RelogioFixo(agora: hoje)

        // 1. Quem nasceu em 15/10/2008 completa 18 anos hoje -> PASSOU
        do {
            let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
            let verificador = VerificadorDeIdadeSimulado(resultado: .dezoitoOuMais)
            let vm = CadastroViewModel(api: api, email: "niver-hoje@frila.app", relogio: relogioHoje, verificadorDeIdade: verificador)
            vm.nome = "Aniversariante Hoje"
            vm.telefone = "61999996666"
            vm.nascimentoTexto = "15/10/2008"
            vm.aceitouTermos = true

            let destino = await vm.criarConta()
            #expect(destino == .funcoesEHorarios, "Aniversariante do dia deve passar")
            #expect(vm.erro == nil)
        }

        // 2. Quem nasceu em 16/10/2008 completa 18 anos amanhã -> BLOQUEIA
        do {
            let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
            let verificador = VerificadorDeIdadeSimulado(resultado: .dezoitoOuMais)
            let vm = CadastroViewModel(api: api, email: "niver-amanha@frila.app", relogio: relogioHoje, verificadorDeIdade: verificador)
            vm.nome = "Aniversariante Amanhã"
            vm.telefone = "61999997777"
            vm.nascimentoTexto = "16/10/2008"
            vm.aceitouTermos = true

            let destino = await vm.criarConta()
            #expect(destino == nil, "Aniversariante de amanhã deve ser bloqueado")
            #expect(vm.erro == "O Frila é exclusivo para maiores de 18 anos.")
        }
    }

    @Test("Cadastro trata erro 422 menorDeIdade da API e exibe mensagem de maioridade")
    func erroMenorDeIdadeDaApiExibeMensagemMaioridade() async {
        let api = ApiClienteEmMemoria(cenario: .menorDeIdade)
        let vm = CadastroViewModel(api: api, email: "api-menor@frila.app")

        vm.nome = "Menor Servidor"
        vm.telefone = "61999998888"
        vm.nascimentoTexto = "01/01/1990"
        vm.aceitouTermos = true

        let destino = await vm.criarConta()
        #expect(destino == nil)
        #expect(vm.erro == "O Frila é exclusivo para maiores de 18 anos.")
    }

    @Test("Cadastro prossegue quando verificador de idade não responde e ignora cancelamento")
    func cadastroProssegueQuandoVerificadorNaoRespondeEIgnoraCancelamento() async throws {
        let api = ApiClienteEspiaoCadastroLocal()
        let agora = Date(timeIntervalSince1970: 1_792_065_600) // Outubro/2026
        let relogioFixo = RelogioFixo(agora: agora)
        let verificador = VerificadorDeIdadeSuspenso()
        let vm = CadastroViewModel(
            api: api,
            email: "adulto-timeout@frila.app",
            relogio: relogioFixo,
            verificadorDeIdade: verificador,
            prazoVerificacaoIdade: .milliseconds(50)
        )

        vm.nome = "Profissional Adulto"
        vm.telefone = "61999993333"
        vm.nascimentoTexto = "01/01/2000" // 26 anos
        vm.aceitouTermos = true

        let estado = EstadoExecucaoCadastro()

        let watchdog = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled {
                Issue.record("Watchdog: timeout de segurança excedido no teste")
                verificador.retomar(com: .abaixoDe18)
            }
        }
        defer {
            watchdog.cancel()
            verificador.retomar(com: .abaixoDe18)
        }

        let task = Task { @MainActor in
            let destino = await vm.criarConta()
            estado.destinoObtido = destino
            estado.finalizou = true
            return destino
        }

        let iniciou = await verificador.aguardarInicio()
        #expect(iniciou, "A verificação de idade deveria ter iniciado")

        // Aguarda finalização condicionada ao estado com deadline de 1s
        let deadline = ContinuousClock.now + .seconds(1)
        while !estado.finalizou && ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }

        // ANTES de liberar dublê:
        #expect(estado.finalizou, "O cadastro deveria ter finalizado pelo timeout da verificação de idade")
        #expect(estado.destinoObtido == .funcoesEHorarios, "Destino após timeout deveria ser .funcoesEHorarios")
        #expect(api.chamadasACriarConta == 1, "API deveria ter sido chamada exatamente 1 vez")
        #expect(api.ultimoCadastroRecebido?.sinalIdade == .indisponivel, "Sinal enviado deve ser .indisponivel")
        #expect(!vm.carregando, "Estado de carregando deve ser falso após término")

        // Liberar dublê com .abaixoDe18 APENAS para limpeza e provar que resposta tardia não altera caminho
        verificador.retomar(com: .abaixoDe18)

        let dubleRetornou = await verificador.aguardarRetorno()
        #expect(dubleRetornou, "O dublê deveria ter retornado após a retomada")

        // Aguarda task terminar para não vazar suspensão e dá oportunidade ao chamador processar a resposta
        _ = await task.value
        let deadlineProcessamento = ContinuousClock.now + .milliseconds(200)
        while ContinuousClock.now < deadlineProcessamento {
            await Task.yield()
        }

        // Prova que a resposta tardia não alterou caminho nem duplicou chamada à API
        #expect(estado.destinoObtido == .funcoesEHorarios)
        #expect(api.chamadasACriarConta == 1)
        #expect(api.ultimoCadastroRecebido?.sinalIdade == .indisponivel)
        #expect(!vm.carregando)
        #expect(vm.erro == nil)
        #expect(verificador.chamadasAVerificar == 1)
    }
}

// MARK: - Dublês locais para teste de timeout e cancelamento não cooperativo

@MainActor
private final class EstadoExecucaoCadastro {
    var finalizou = false
    var destinoObtido: DestinoAposEntrada?
}

private final class ApiClienteEspiaoCadastroLocal: ApiClienteEncaminhador, @unchecked Sendable {
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

private final class VerificadorDeIdadeSuspenso: VerificadorDeIdade, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<ResultadoVerificacaoIdade, Never>?
    private var resultadoPendente: ResultadoVerificacaoIdade?
    private var retomado = false
    private var iniciou = false
    private var retornou = false
    private var _chamadasAVerificar = 0

    var chamadasAVerificar: Int {
        lock.withLock { _chamadasAVerificar }
    }

    @MainActor
    func verificarMaioridade() async -> ResultadoVerificacaoIdade {
        let resultado = await withCheckedContinuation { cont in
            var contParaRetomar: CheckedContinuation<ResultadoVerificacaoIdade, Never>?
            var resultadoImediato: ResultadoVerificacaoIdade?
            lock.withLock {
                _chamadasAVerificar += 1
                iniciou = true
                if retomado, let pendente = resultadoPendente {
                    resultadoImediato = pendente
                    contParaRetomar = cont
                } else {
                    continuation = cont
                }
            }
            if let resultadoImediato, let contParaRetomar {
                contParaRetomar.resume(returning: resultadoImediato)
            }
        }
        lock.withLock {
            retornou = true
        }
        return resultado
    }

    func aguardarInicio(timeout: Duration = .seconds(1)) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            let foiIniciado = lock.withLock { iniciou }
            if foiIniciado { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return lock.withLock { iniciou }
    }

    func aguardarRetorno(timeout: Duration = .seconds(1)) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            let jaRetornou = lock.withLock { retornou }
            if jaRetornou { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return lock.withLock { retornou }
    }

    func retomar(com resultado: ResultadoVerificacaoIdade) {
        let contParaRetomar: CheckedContinuation<ResultadoVerificacaoIdade, Never>? = lock.withLock {
            guard !retomado else { return nil }
            retomado = true
            resultadoPendente = resultado
            let cont = continuation
            continuation = nil
            return cont
        }
        contParaRetomar?.resume(returning: resultado)
    }
}
