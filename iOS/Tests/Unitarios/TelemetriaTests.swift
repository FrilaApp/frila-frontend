import Foundation
import MapKit
import SwiftUI
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

private struct RelogioFixo: Relogio {
    let agora: Date
}

@Suite("Telemetria: contrato 0.2.41, RN15, RNF08 e resiliência")
struct TelemetriaTests {
    // MARK: - Dicionário fechado e fixtures de contrato

    @Test("Os 14 eventos do contrato 0.2.41 correspondem aos valores estritos do enum")
    func dicionarioDeEventos() {
        let mapeamentoEsperado: [EventoDeTelemetria: String] = [
            .appAberto: "app_aberto",
            .cadastroConcluido: "cadastro_concluido",
            .permissaoPushNegada: "permissao_push_negada",
            .vagaVista: "vaga_vista",
            .vagaDetalheAberto: "vaga_detalhe_aberto",
            .candidaturaEnviada: "candidatura_enviada",
            .candidaturaRetirada: "candidatura_retirada",
            .checkinTentado: "checkin_tentado",
            .checkinConcluido: "checkin_concluido",
            .checkoutConcluido: "checkout_concluido",
            .avaliacaoEnviada: "avaliacao_enviada",
            .contatoAberto: "contato_aberto",
            .acaoEnfileiradaOffline: "acao_enfileirada_offline",
            .atualizacaoObrigatoriaExibida: "atualizacao_obrigatoria_exibida",
        ]

        #expect(EventoDeTelemetria.allCases.count == 14)
        for (evento, valor) in mapeamentoEsperado {
            #expect(evento.rawValue == valor)
        }
    }

    @Test("Fixture registrar-evento.json decodifica com registrado = true")
    func decodificaFixtureResposta() throws {
        let resposta = try FixturesDoContrato.carregar(
            "registrar-evento",
            como: ContratoAPI.RegistrarEventoRespostaDTO.self
        )
        #expect(resposta.registrado == true)
    }

    @Test("Fixture requisicao-registrar-evento.json possui estrutura estrita do contrato")
    func decodificaFixtureRequisicao() throws {
        let dados = try FixturesDoContrato.dados("requisicao-registrar-evento")
        let json = try #require(JSONSerialization.jsonObject(with: dados) as? [String: Any])

        #expect(json["evento"] as? String == "app_aberto")
        #expect(json["vaga_id"] as? String == "11111111-1111-4111-8111-111111111111")
        #expect(json["turno_id"] as? String == "22222222-2222-4222-8222-222222222222")
        #expect(json["ocorrido_em"] as? String == "2026-10-14T14:30:00Z")
    }

    // MARK: - ApiClienteEmMemoria

    @Test("ApiClienteEmMemoria registra evento com sucesso quando autenticado")
    func registroComSucesso() async throws {
        let agora = Date()
        let api = ApiClienteEmMemoria(relogio: RelogioFixo(agora: agora))
        let vaga = try #require(try await api.vagasAbertas().first)
        let turnoID = try #require(try await api.candidatar(vagaID: vaga.id).turnoID)

        let registro = RegistroDeEvento(
            evento: .vagaVista,
            vagaID: vaga.id,
            turnoID: turnoID,
            ocorridoEm: agora
        )

        let sucesso = try await api.registrarEvento(registro)
        #expect(sucesso == true)
        let registrados = await api.eventosRegistrados
        #expect(registrados.count == 1)
        #expect(registrados.first == registro)
    }

    @Test("ApiClienteEmMemoria recusa registrar_evento sem sessão ativa (401 nao_autenticado)")
    func recusaSemAutenticacao() async {
        let api = ApiClienteEmMemoria(cenario: .entrada)
        await #expect(throws: ErroDaApi(codigo: .naoAutenticado)) {
            try await api.registrarEvento(.appAberto)
        }
    }

    @Test("ApiClienteEmMemoria recusa instante de ocorrência no futuro (422 registro_no_futuro)")
    func recusaRegistroNoFuturo() async {
        let agora = Date()
        let api = ApiClienteEmMemoria(relogio: RelogioFixo(agora: agora))
        let instanteNoFuturo = agora.addingTimeInterval(3600)
        let registro = RegistroDeEvento(
            evento: .appAberto,
            ocorridoEm: instanteNoFuturo
        )

        await #expect(throws: ErroDaApi(codigo: .registroNoFuturo)) {
            try await api.registrarEvento(registro)
        }
    }

    @Test("ApiClienteEmMemoria recusa vaga_id inexistente (422 campo_invalido)")
    func recusaVagaInexistente() async {
        let api = ApiClienteEmMemoria()
        let vagaFantasma = UUID(uuidString: "00000000-0000-4000-8000-000000000099")!
        let registro = RegistroDeEvento(
            evento: .vagaVista,
            vagaID: vagaFantasma
        )

        let erro = await #expect(throws: ErroDaApi.self) {
            try await api.registrarEvento(registro)
        }
        #expect(erro?.codigo == .campoInvalido)
        #expect(erro?.detalhes == "vaga_id")
    }

    @Test("ApiClienteEmMemoria recusa turno_id inexistente (422 campo_invalido)")
    func recusaTurnoInexistente() async {
        let api = ApiClienteEmMemoria()
        let turnoFantasma = UUID(uuidString: "00000000-0000-4000-8000-000000000099")!
        let registro = RegistroDeEvento(
            evento: .checkinTentado,
            turnoID: turnoFantasma
        )

        let erro = await #expect(throws: ErroDaApi.self) {
            try await api.registrarEvento(registro)
        }
        #expect(erro?.codigo == .campoInvalido)
        #expect(erro?.detalhes == "turno_id")
    }

    // MARK: - RegistradorDeTelemetria (Resiliência RNF08 / RN15)

    @Test("RegistradorDeTelemetria despacha com sucesso")
    func registradorSucesso() async {
        let api = ApiClienteEmMemoria()
        let registrador = RegistradorDeTelemetria(api: api)

        let ok = await registrador.registrar(.appAberto)
        #expect(ok == true)
        let registrados = await api.eventosRegistrados
        #expect(registrados.count == 1)
        #expect(registrados.first?.evento == .appAberto)
    }

    @Test("RegistradorDeTelemetria silencia falhas de API e não quebra o fluxo")
    func registradorSilenciaFalhas() async {
        let api = ApiClienteEmMemoria(cenario: .entrada)
        let registrador = RegistradorDeTelemetria(api: api)

        // Não lança exceção mesmo que a API recuse
        let ok = await registrador.registrar(.appAberto)
        #expect(ok == false)
        let registrados = await api.eventosRegistrados
        #expect(registrados.isEmpty)
    }

    @Test("RegistradorDeTelemetria com disparo não bloqueante (fire-and-forget) não propaga exceção")
    func registradorDisparoNaoBloqueante() async throws {
        let api = ApiClienteEmMemoria()
        let registrador = RegistradorDeTelemetria(api: api)

        registrador.disparar(.cadastroConcluido)
        // Pequena espera cooperativa para dar tempo à Task desacoplada executar
        try await Task.sleep(nanoseconds: 50_000_000)

        let registrados = await api.eventosRegistrados
        #expect(registrados.contains(where: { $0.evento == .cadastroConcluido }))
    }

    // MARK: - Fiação dos 14 Eventos nas Telas / ViewModels (T-0017, RN15, RNF08)

    @Test("Evento 1: app_aberto é emitido pelo RegistradorDeTelemetria")
    func eventoAppAberto() async {
        let api = ApiClienteEmMemoria()
        let telemetria = RegistradorDeTelemetria(api: api)
        let ok = await telemetria.registrar(.appAberto)
        #expect(ok == true)
        let eventos = await api.eventosRegistrados
        #expect(eventos.count == 1)
        #expect(eventos.first?.evento == .appAberto)
        #expect(eventos.first?.vagaID == nil)
        #expect(eventos.first?.turnoID == nil)

        // Falha silenciosa com API em cenário de erro
        let apiErro = ApiClienteEmMemoria(cenario: .entrada)
        let telemetriaErro = RegistradorDeTelemetria(api: apiErro)
        let falhouSilencioso = await telemetriaErro.registrar(.appAberto)
        #expect(falhouSilencioso == false)
    }

    @Test("Partida do app (cena inativa -> ativa) emite app_aberto exatamente uma vez e não duplica")
    func partidaDoAppEmiteAppAbertoUmaVez() async {
        let api = ApiClienteEmMemoria()
        let telemetria = RegistradorDeTelemetria(api: api)

        // Simula partida: cena transiciona de .inactive para .active
        let faseInicial: ScenePhase = .inactive
        let faseAtiva: ScenePhase = .active

        #expect(TelemetriaCicloDeVida.deveRegistrarAbertura(de: faseInicial, para: faseAtiva) == true)
        if TelemetriaCicloDeVida.deveRegistrarAbertura(de: faseInicial, para: faseAtiva) {
            await telemetria.registrar(.appAberto)
        }

        let eventos1 = await api.eventosRegistrados
        #expect(eventos1.filter { $0.evento == .appAberto }.count == 1)

        // Re-render ou estado onde a cena continua ativa (.active -> .active)
        #expect(TelemetriaCicloDeVida.deveRegistrarAbertura(de: .active, para: .active) == false)
        if TelemetriaCicloDeVida.deveRegistrarAbertura(de: .active, para: .active) {
            await telemetria.registrar(.appAberto)
        }

        // Ida para background e retorno
        #expect(TelemetriaCicloDeVida.deveRegistrarAbertura(de: .active, para: .background) == false)
        #expect(TelemetriaCicloDeVida.deveRegistrarAbertura(de: .background, para: .active) == true)

        let eventosFinais = await api.eventosRegistrados
        #expect(eventosFinais.filter { $0.evento == .appAberto }.count == 1, "app_aberto não deve ter sido emitido novamente")
    }

    private func prepararTurno(api: ApiClienteEmMemoria) async throws -> Turno {
        if let turno = try await api.meusTurnos().first { return turno }
        let vaga = try #require(try await api.vagasAbertas().first)
        _ = try await api.candidatar(vagaID: vaga.id)
        return try #require(try await api.meusTurnos().first)
    }

    @Test("Evento 2: cadastro_concluido é emitido unicamente ao criar conta sem dados pessoais (RN15)")
    @MainActor
    func eventoCadastroConcluido() async throws {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let vmCadastro = CadastroViewModel(api: api, email: "novo@frila.app")
        vmCadastro.nome = "Profissional Teste"
        vmCadastro.telefone = "(61) 98765-4321"
        vmCadastro.nascimentoTexto = "01/01/1990"
        vmCadastro.maiorDeIdade = true
        vmCadastro.aceitouTermos = true

        let destino = await vmCadastro.criarConta()
        #expect(destino != nil)
        let eventos = await api.eventosRegistrados
        let evCadastro = eventos.first { $0.evento == .cadastroConcluido }
        #expect(evCadastro != nil)
        #expect(evCadastro?.vagaID == nil)
        #expect(evCadastro?.turnoID == nil)

        // Falha do registrador não quebra o fluxo
        let apiFalha = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let apiErro = ApiClienteEmMemoria(cenario: .entrada)
        let telemetriaFalha = RegistradorDeTelemetria(api: apiErro)
        let vmFalha = CadastroViewModel(api: apiFalha, email: "outro@frila.app", telemetria: telemetriaFalha)
        vmFalha.nome = "Profissional Teste 2"
        vmFalha.telefone = "(61) 98765-4322"
        vmFalha.nascimentoTexto = "01/01/1990"
        vmFalha.maiorDeIdade = true
        vmFalha.aceitouTermos = true
        let destinoSucessoMesmoComTelemetriaFalhando = await vmFalha.criarConta()
        #expect(destinoSucessoMesmoComTelemetriaFalhando != nil)
    }

    @Test("Onboarding completo (CadastroViewModel -> PerfilProfissionalViewModel) emite cadastro_concluido exatamente uma vez")
    @MainActor
    func onboardingCompletoEmiteCadastroConcluidoUmaVez() async throws {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let vmCadastro = CadastroViewModel(api: api, email: "novo@frila.app")
        vmCadastro.nome = "Profissional Teste"
        vmCadastro.telefone = "(61) 98765-4321"
        vmCadastro.nascimentoTexto = "01/01/1990"
        vmCadastro.maiorDeIdade = true
        vmCadastro.aceitouTermos = true

        let destino = await vmCadastro.criarConta()
        #expect(destino != nil)

        // Simula preenchimento e salvamento de perfil após criar conta no onboarding
        let funcoes = try await api.funcoes()
        let vmPerfil = PerfilProfissionalViewModel(api: api, modo: .criacao)
        vmPerfil.funcoesSelecionadas = Set([try #require(funcoes.first?.id)])
        let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: -15.78, longitude: -47.93)))
        vmPerfil.selecionarSugestao(item)
        let salvouPerfil = await vmPerfil.salvar()
        #expect(salvouPerfil == true)

        let eventos = await api.eventosRegistrados
        let cadastros = eventos.filter { $0.evento == .cadastroConcluido }
        #expect(cadastros.count == 1, "cadastro_concluido deve ser emitido exatamente 1 vez no onboarding completo")
    }

    @Test("CadastroViewModel com retry de criação não duplica cadastro_concluido")
    @MainActor
    func retryCadastroNaoDuplicaEvento() async throws {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        let vmCadastro = CadastroViewModel(api: api, email: "novo@frila.app")
        vmCadastro.nome = "Profissional Teste"
        vmCadastro.telefone = "(61) 98765-4321"
        vmCadastro.nascimentoTexto = "01/01/1990"
        vmCadastro.maiorDeIdade = true
        vmCadastro.aceitouTermos = true

        let destino1 = await vmCadastro.criarConta()
        #expect(destino1 != nil)

        // Segunda tentativa / retry na mesma instância do ViewModel
        _ = await vmCadastro.criarConta()

        let eventos = await api.eventosRegistrados
        let cadastros = eventos.filter { $0.evento == .cadastroConcluido }
        #expect(cadastros.count == 1, "cadastro_concluido não deve duplicar em retry")
    }

    @Test("CadastroEstabelecimentoViewModel não emite cadastro_concluido (unificado no CadastroViewModel)")
    @MainActor
    func cadastroEstabelecimentoNaoEmiteCadastroConcluido() async throws {
        let api = ApiClienteEmMemoria(cenario: .contratanteSemEstabelecimento)
        let vm = CadastroEstabelecimentoViewModel(api: api)
        vm.nome = "Bar do Teste"
        vm.atualizarDocumento("12345678000190")
        vm.endereco = "CLS 402 Bloco A"
        vm.regiaoAdministrativa = "Plano Piloto"
        vm.ponto = .init(latitude: -15.8, longitude: -47.9)

        await vm.salvar()
        #expect(vm.concluido == true)

        let eventos = await api.eventosRegistrados
        let cadastros = eventos.filter { $0.evento == .cadastroConcluido }
        #expect(cadastros.isEmpty, "Cadastro de estabelecimento não deve emitir cadastro_concluido diretamente")
    }

    @Test("Evento 3: permissao_push_negada é emitido quando o usuário recusa o push no modal")
    @MainActor
    func eventoPermissaoPushNegada() async {
        let api = ApiClienteEmMemoria()
        let permissaoSimulada = PermissaoDePushSimulada(estado: .naoPedida, resposta: .negada)
        let modelo = PermissaoDePushModelo(permissao: permissaoSimulada, telemetria: RegistradorDeTelemetria(api: api))

        await modelo.ativar()
        #expect(modelo.estado == .negada)
        let eventos = await api.eventosRegistrados
        #expect(eventos.contains { $0.evento == .permissaoPushNegada })

        // Falha na telemetria não altera o estado do modelo
        let apiErro = ApiClienteEmMemoria(cenario: .entrada)
        let modeloErro = PermissaoDePushModelo(permissao: permissaoSimulada, telemetria: RegistradorDeTelemetria(api: apiErro))
        await modeloErro.ativar()
        #expect(modeloErro.estado == .negada)
    }

    @Test("Evento 4: vaga_vista é emitido com vagaID e deduplica na mesma sessão")
    @MainActor
    func eventoVagaVista() async throws {
        let api = ApiClienteEmMemoria()
        let vm = FeedVagasViewModel(api: api)
        let vaga = try #require(try await api.vagasAbertas().first)

        await vm.registrarVagaVista(id: vaga.id)
        let eventos1 = await api.eventosRegistrados
        #expect(eventos1.filter { $0.evento == .vagaVista && $0.vagaID == vaga.id }.count == 1)

        // Deduplicação na mesma sessão
        await vm.registrarVagaVista(id: vaga.id)
        let eventos2 = await api.eventosRegistrados
        #expect(eventos2.filter { $0.evento == .vagaVista && $0.vagaID == vaga.id }.count == 1)

        // Falha na telemetria não afeta o ViewModel
        let apiErro = ApiClienteEmMemoria(cenario: .entrada)
        let vmErro = FeedVagasViewModel(api: api, telemetria: RegistradorDeTelemetria(api: apiErro))
        await vmErro.registrarVagaVista(id: vaga.id)
    }

    @Test("Evento 5: vaga_detalhe_aberto é emitido ao carregar detalhe da vaga e deduplica em recarga")
    @MainActor
    func eventoVagaDetalheAberto() async throws {
        let api = ApiClienteEmMemoria()
        let vagaLista = try #require(try await api.vagasAbertas().first)
        let vaga = try await api.detalheDaVaga(id: vagaLista.id)
        let vm = DetalheVagaViewModel(vagaID: vaga.id, api: api)

        await vm.carregar()
        let eventos1 = await api.eventosRegistrados
        #expect(eventos1.filter { $0.evento == .vagaDetalheAberto && $0.vagaID == vaga.id }.count == 1)

        // Recarga não duplica
        await vm.carregar()
        let eventos2 = await api.eventosRegistrados
        #expect(eventos2.filter { $0.evento == .vagaDetalheAberto && $0.vagaID == vaga.id }.count == 1)

        // Falha na telemetria não impede carregamento
        let apiErro = ApiClienteEmMemoria(cenario: .entrada)
        let vmErro = DetalheVagaViewModel(vagaID: vaga.id, api: api, telemetria: RegistradorDeTelemetria(api: apiErro))
        await vmErro.carregar()
        #expect(vmErro.estado == .carregado(vaga))
    }

    @Test("Evento 6: candidatura_enviada é emitido ao submeter candidatura com sucesso")
    @MainActor
    func eventoCandidaturaEnviada() async throws {
        let api = ApiClienteEmMemoria()
        let vagaLista = try #require(try await api.vagasAbertas().first)
        let vaga = try await api.detalheDaVaga(id: vagaLista.id)
        let vm = CandidaturaViewModel(vaga: vaga, api: api)

        await vm.candidatar()
        #expect(vm.estado != .ocioso)
        let eventos = await api.eventosRegistrados
        let ev = eventos.first { $0.evento == .candidaturaEnviada }
        #expect(ev != nil)
        #expect(ev?.vagaID == vaga.id)

        // Falha na telemetria não impede a conclusão da candidatura
        let api2 = ApiClienteEmMemoria()
        let vagaLista2 = try #require(try await api2.vagasAbertas().first)
        let vaga2 = try await api2.detalheDaVaga(id: vagaLista2.id)
        let apiErro = ApiClienteEmMemoria(cenario: .entrada)
        let vmErro = CandidaturaViewModel(vaga: vaga2, api: api2, telemetria: RegistradorDeTelemetria(api: apiErro))
        await vmErro.candidatar()
        if case .concluida = vmErro.estado {
            // Sucesso preservado
        } else {
            Issue.record("Candidatura deveria ter sido concluída com sucesso mesmo com falha na telemetria")
        }
    }

    @Test("Evento 7: candidatura_retirada é emitido com vagaID ao retirar candidatura pendente")
    @MainActor
    func eventoCandidaturaRetirada() async throws {
        let api = ApiClienteEmMemoria(cenario: .candidaturaPendente)
        let candidaturas = try await api.minhasCandidaturas()
        let cand = try #require(candidaturas.first)
        let vm = RetirarCandidaturaViewModel(candidaturaID: cand.id, api: api)

        await vm.retirar()
        #expect(vm.estado == .retirada)
        let eventos = await api.eventosRegistrados
        let ev = eventos.first { $0.evento == .candidaturaRetirada }
        #expect(ev != nil)
        #expect(ev?.vagaID == cand.vaga.id)

        // Falha na telemetria não bloqueia retirada
        let api2 = ApiClienteEmMemoria(cenario: .candidaturaPendente)
        let candidaturas2 = try await api2.minhasCandidaturas()
        let cand2 = try #require(candidaturas2.first)
        let apiErro = ApiClienteEmMemoria(cenario: .entrada)
        let vmErro = RetirarCandidaturaViewModel(candidaturaID: cand2.id, api: api2, telemetria: RegistradorDeTelemetria(api: apiErro))
        await vmErro.retirar()
        #expect(vmErro.estado == .retirada)
    }

    @Test("Evento 8: checkin_tentado é emitido antes da validação do GPS ao tocar em Fazer check-in")
    @MainActor
    func eventoCheckinTentado() async throws {
        let api = ApiClienteEmMemoria()
        let turno = try await prepararTurno(api: api)
        let leitor = LeitorDeLocalizacaoSimulado(resultado: .failure(.semSinal))
        let vm = PresencaDoTurnoViewModel(turno: turno, api: api, localizacao: leitor)

        await vm.iniciar(.checkin)
        let eventos = await api.eventosRegistrados
        let ev = eventos.first { $0.evento == .checkinTentado }
        #expect(ev != nil)
        #expect(ev?.turnoID == turno.id)

        // Falha na telemetria não altera o fluxo de tentativa
        let apiErro = ApiClienteEmMemoria(cenario: .entrada)
        let vmErro = PresencaDoTurnoViewModel(turno: turno, api: api, localizacao: leitor, telemetria: RegistradorDeTelemetria(api: apiErro))
        await vmErro.iniciar(.checkin)
        #expect(vmErro.ocupado == false)
    }

    @Test("Evento 9: checkin_concluido é emitido quando check-in é confirmado")
    @MainActor
    func eventoCheckinConcluido() async throws {
        let api = ApiClienteEmMemoria()
        let turno = try await prepararTurno(api: api)
        let ponto = try await api.detalheDaVaga(id: turno.vaga.id).ponto
        let leitor = LeitorDeLocalizacaoSimulado(
            permissao: .aoUsarPrecisa,
            resultado: .success(LeitorDeLocalizacaoSimulado.leitura(a: 20, de: ponto, precisaoMetros: 10))
        )
        let vm = PresencaDoTurnoViewModel(turno: turno, api: api, localizacao: leitor, pontoDaVaga: ponto)

        await vm.iniciar(.checkin)
        if case .registrado = vm.checkin {
            let eventos = await api.eventosRegistrados
            let ev = eventos.first { $0.evento == .checkinConcluido }
            #expect(ev != nil)
            #expect(ev?.turnoID == turno.id)
            #expect(ev?.ocorridoEm != nil)
        } else {
            Issue.record("Check-in deveria ter sido registrado")
        }
    }

    @Test("Evento 10: checkout_concluido é emitido quando checkout é confirmado")
    @MainActor
    func eventoCheckoutConcluido() async throws {
        let api = ApiClienteEmMemoria()
        let turno = try await prepararTurno(api: api)
        let ponto = try await api.detalheDaVaga(id: turno.vaga.id).ponto
        let leitor = LeitorDeLocalizacaoSimulado(
            permissao: .aoUsarPrecisa,
            resultado: .success(LeitorDeLocalizacaoSimulado.leitura(a: 20, de: ponto, precisaoMetros: 10))
        )
        let vm = PresencaDoTurnoViewModel(turno: turno, api: api, localizacao: leitor, pontoDaVaga: ponto)

        // Faz check-in primeiro
        await vm.iniciar(.checkin)
        // Faz checkout
        await vm.iniciar(.checkout)

        if case .registrado = vm.checkout {
            let eventos = await api.eventosRegistrados
            let ev = eventos.first { $0.evento == .checkoutConcluido }
            #expect(ev != nil)
            #expect(ev?.turnoID == turno.id)
            #expect(ev?.ocorridoEm != nil)
        } else {
            Issue.record("Checkout deveria ter sido registrado")
        }
    }

    @Test("Evento 11: avaliacao_enviada é emitido ao registrar avaliação")
    @MainActor
    func eventoAvaliacaoEnviada() async throws {
        let api = ApiClienteEmMemoria(cenario: .turnoEncerrado)
        let turno = try #require(try await api.meusTurnos().first)
        let conta = try await api.minhaConta()
        let vm = AvaliacaoTurnoViewModel(
            turnoID: turno.id,
            contaID: conta.id,
            turno: turno,
            api: api,
            armazenamento: ArmazenamentoAvaliacoesEmMemoria()
        )
        vm.resposta = true

        let sucesso = await vm.salvar()
        #expect(sucesso == true)
        let eventos = await api.eventosRegistrados
        let ev = eventos.first { $0.evento == .avaliacaoEnviada }
        #expect(ev != nil)
        #expect(ev?.turnoID == turno.id)

        // Falha na telemetria não impede avaliação
        let api2 = ApiClienteEmMemoria(cenario: .turnoEncerrado)
        let turno2 = try #require(try await api2.meusTurnos().first)
        let apiErro = ApiClienteEmMemoria(cenario: .entrada)
        let vmErro = AvaliacaoTurnoViewModel(
            turnoID: turno2.id,
            contaID: conta.id,
            turno: turno2,
            api: api2,
            armazenamento: ArmazenamentoAvaliacoesEmMemoria(),
            telemetria: RegistradorDeTelemetria(api: apiErro)
        )
        vmErro.resposta = true
        let sucessoErro = await vmErro.salvar()
        #expect(sucessoErro == true)
    }

    @Test("Evento 12: contato_aberto é emitido ao acionar abertura de contato com contraparte")
    @MainActor
    func eventoContatoAberto() async throws {
        let api = ApiClienteEmMemoria()
        let turno = try await prepararTurno(api: api)
        let vm = MeuTurnoViewModel(turno: turno, api: api)

        await vm.registrarContatoAberto()
        let eventos = await api.eventosRegistrados
        let ev = eventos.first { $0.evento == .contatoAberto }
        #expect(ev != nil)
        #expect(ev?.turnoID == turno.id)

        // Falha na telemetria não quebra
        let apiErro = ApiClienteEmMemoria(cenario: .entrada)
        let vmErro = MeuTurnoViewModel(turno: turno, api: api, telemetria: RegistradorDeTelemetria(api: apiErro))
        await vmErro.registrarContatoAberto()
    }

    @Test("Evento 13: acao_enfileirada_offline é emitido ao enfileirar no modo offline")
    @MainActor
    func eventoAcaoEnfileiradaOffline() async throws {
        let api = ApiClienteEmMemoria()
        let turno = try await prepararTurno(api: api)
        let fila = FilaDeAcoesMemoria()
        let telemetria = RegistradorDeTelemetria(api: api)
        let vmSemRede = CancelamentoViewModel(
            lado: .profissional,
            alvo: .posicao(id: turno.posicaoID, turnoID: turno.id),
            periodo: turno.vaga.periodo,
            fila: fila,
            executar: { _ in throw ErroDaApi(codigo: .semRede) },
            telemetria: telemetria
        )
        vmSemRede.motivo = MotivoDeCancelamento.saude
        await vmSemRede.confirmar()
        #expect(vmSemRede.estado == EstadoDoCancelamento.concluido(.naFila))

        let eventos = await api.eventosRegistrados
        let ev = eventos.first { $0.evento == .acaoEnfileiradaOffline }
        #expect(ev != nil)
        #expect(ev?.turnoID == turno.id)
    }

    @Test("Evento 14: atualizacao_obrigatoria_exibida é emitido ao bloquear versão desatualizada")
    @MainActor
    func eventoAtualizacaoObrigatoriaExibida() async {
        let api = ApiClienteEmMemoria()
        // versaoAtual 0.0.1 é menor que versaoMinima configurada no mock
        let vm = AtualizacaoObrigatoriaViewModel(api: api, versaoAtual: "0.0.1", telemetria: RegistradorDeTelemetria(api: api))

        await vm.verificar()
        if case .bloqueado = vm.estado {
            let eventos1 = await api.eventosRegistrados
            #expect(eventos1.filter { $0.evento == .atualizacaoObrigatoriaExibida }.count == 1)

            // Rechecagem não duplica
            await vm.verificar()
            let eventos2 = await api.eventosRegistrados
            #expect(eventos2.filter { $0.evento == .atualizacaoObrigatoriaExibida }.count == 1)
        } else {
            Issue.record("ViewModel deveria ter bloqueado a versão desatualizada")
        }

        // Falha na telemetria não impede bloqueio
        let apiErro = ApiClienteEmMemoria(cenario: .entrada)
        let vmErro = AtualizacaoObrigatoriaViewModel(api: api, versaoAtual: "0.0.1", telemetria: RegistradorDeTelemetria(api: apiErro))
        await vmErro.verificar()
        if case .bloqueado = vmErro.estado {
            // Sucesso no bloqueio preservado
        } else {
            Issue.record("Bloqueio deveria permanecer ativo")
        }
    }
}

private actor FilaDeAcoesMemoria: FilaDeAcoes {
    var itens: [AcaoPendente] = []
    func enfileirar(_ acao: AcaoPendente) throws { itens.append(acao) }
    func pendentes() throws -> [AcaoPendente] { itens }
    func remover(id: UUID) throws { itens.removeAll { $0.id == id } }
    func limpar() throws { itens.removeAll() }
    func recusar(_ acao: AcaoPendente, codigo: CodigoErroAPI) async throws { try remover(id: acao.id) }
    func recusadas() -> [AcaoRecusada] { [] }
    func resolverRecusas(_ acao: AcaoPendente) async throws {}
}
