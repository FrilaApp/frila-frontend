import Foundation
import MapKit
import SwiftUI
@testable import FrilaApresentacao
@testable import FrilaDados
@testable import FrilaDominio
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

    // MARK: - Fila offline de eventos (RNF08): guardar e reenviar

    private static let instante = Date(timeIntervalSince1970: 1_800_000_000)

    /// API com sessão, relógio fixo e registrador ligados à mesma fila em memória, dona = a conta da API.
    private func cenarioOffline(
        agora: Date = instante
    ) async throws -> (api: ApiClienteEmMemoria, fila: FilaDeTelemetriaEmMemoria, registrador: RegistradorDeTelemetria) {
        let api = ApiClienteEmMemoria(relogio: RelogioFixo(agora: agora))
        let fila = FilaDeTelemetriaEmMemoria(contaAtual: try await api.minhaConta().id)
        let registrador = RegistradorDeTelemetria(api: api, fila: fila, relogio: RelogioFixo(agora: agora))
        return (api, fila, registrador)
    }

    private func esperar(até condicao: @Sendable () async -> Bool) async {
        for _ in 0..<100 {
            if await condicao() { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    @Test("Falha de rede guarda o evento com a hora em que aconteceu")
    func redeCaidaGuardaEvento() async throws {
        let (api, fila, registrador) = try await cenarioOffline()
        await api.definirRedeCaida(true)
        let aconteceu = Self.instante.addingTimeInterval(-600)

        let ok = await registrador.registrar(.checkinConcluido, ocorridoEm: aconteceu)

        #expect(ok == false)
        let pendentes = try await fila.eventosPendentes()
        #expect(pendentes.count == 1)
        #expect(pendentes.first?.registro.evento == .checkinConcluido)
        #expect(pendentes.first?.registro.ocorridoEm == aconteceu)
        #expect(await api.eventosRegistrados.isEmpty)
    }

    @Test("Ação feita sem rede conta uma vez só: o evento guardado na hora, e nada a mais ao sincronizar")
    @MainActor
    func acaoOfflineContaUmaVez() async throws {
        let api = ApiClienteEmMemoria(cenario: .turnoConfirmadoLonge, relogio: RelogioFixo(agora: Self.instante))
        let turno = try #require(try await api.meusTurnos().first)
        let filaDeTelemetria = FilaDeTelemetriaEmMemoria(contaAtual: try await api.minhaConta().id)
        let registrador = RegistradorDeTelemetria(api: api, fila: filaDeTelemetria, relogio: RelogioFixo(agora: Self.instante))
        let filaDeAcoes = FilaDeAcoesMemoria()
        await api.definirRedeCaida(true)
        let vm = CancelamentoViewModel(
            lado: .profissional,
            alvo: .posicao(id: turno.posicaoID, turnoID: turno.id),
            periodo: turno.vaga.periodo,
            relogio: RelogioFixo(agora: Self.instante),
            fila: filaDeAcoes,
            executar: { _ in throw ErroDaApi(codigo: .semRede) },
            telemetria: registrador
        )
        vm.motivo = MotivoDeCancelamento.saude
        await vm.confirmar()
        #expect(vm.estado == EstadoDoCancelamento.concluido(.naFila))

        await api.definirRedeCaida(false)
        // O dublê tira da lista o turno cancelado e recusaria o `turno_id` depois: o evento guardado sai antes.
        await registrador.reenviar()
        await SincronizadorAcoes(fila: filaDeAcoes, api: api).sincronizar()
        await registrador.reenviar()

        #expect(try await filaDeAcoes.pendentes().isEmpty)
        let enfileiradas = await api.eventosRegistrados.filter { $0.evento == .acaoEnfileiradaOffline }
        #expect(enfileiradas.count == 1)
        #expect(enfileiradas.first?.turnoID == turno.id)
    }

    @Test("Evento sem hora própria é guardado com a hora de agora, não a da volta da rede")
    func eventoSemHoraRecebeAgora() async throws {
        let (api, fila, registrador) = try await cenarioOffline()
        await api.definirRedeCaida(true)

        await registrador.registrar(.acaoEnfileiradaOffline)

        let pendentes = try await fila.eventosPendentes()
        #expect(pendentes.first?.registro.ocorridoEm == Self.instante)
    }

    @Test("O reenvio preserva o ocorrido_em original e esvazia a fila")
    func reenvioPreservaOcorridoEm() async throws {
        let (api, fila, registrador) = try await cenarioOffline()
        await api.definirRedeCaida(true)
        let primeiro = Self.instante.addingTimeInterval(-7200)
        let segundo = Self.instante.addingTimeInterval(-3600)
        await registrador.registrar(.checkinConcluido, ocorridoEm: primeiro)
        await registrador.registrar(.checkoutConcluido, ocorridoEm: segundo)
        #expect(try await fila.eventosPendentes().count == 2)

        await api.definirRedeCaida(false)
        await registrador.reenviar()

        let enviados = await api.eventosRegistrados
        #expect(enviados.map(\.evento) == [.checkinConcluido, .checkoutConcluido])
        #expect(enviados.map(\.ocorridoEm) == [primeiro, segundo])
        #expect(try await fila.eventosPendentes().isEmpty)
    }

    @Test("Com a rede ainda caída o reenvio mantém tudo, na ordem")
    func reenvioSemRedeMantemFila() async throws {
        let (api, fila, registrador) = try await cenarioOffline()
        await api.definirRedeCaida(true)
        await registrador.registrar(.checkinConcluido)
        await registrador.registrar(.checkoutConcluido)

        await registrador.reenviar()

        #expect(try await fila.eventosPendentes().map(\.registro.evento) == [.checkinConcluido, .checkoutConcluido])
    }

    @Test("Um envio que dá certo esvazia o que ficou guardado")
    func envioBemSucedidoEsvaziaFila() async throws {
        let (api, fila, registrador) = try await cenarioOffline()
        await api.definirRedeCaida(true)
        await registrador.registrar(.checkinConcluido, ocorridoEm: Self.instante.addingTimeInterval(-60))
        await api.definirRedeCaida(false)

        let ok = await registrador.registrar(.appAberto)
        #expect(ok == true)

        await esperar { ((try? await fila.eventosPendentes().isEmpty) ?? false) }
        #expect(try await fila.eventosPendentes().isEmpty)
        #expect(await api.eventosRegistrados.map(\.evento).contains(.checkinConcluido))
    }

    @Test("Recusa 422 do servidor descarta o evento e não o guarda")
    func recusa422Descarta() async throws {
        let (api, fila, registrador) = try await cenarioOffline()

        // vaga_id que não existe no servidor: 422 campo_invalido, definitivo.
        let ok = await registrador.registrar(.vagaVista, vagaID: UUID())

        #expect(ok == false)
        #expect(try await fila.eventosPendentes().isEmpty)
        #expect(await api.eventosRegistrados.isEmpty)
    }

    @Test("No reenvio, o evento que o servidor recusa sai da fila sem travar os seguintes")
    func reenvioDescartaRecusadoEContinua() async throws {
        let (api, fila, registrador) = try await cenarioOffline()
        let conta = try await api.minhaConta().id
        await fila.inserir(EventoDeTelemetriaPendente(
            contaID: conta, registro: RegistroDeEvento(evento: .vagaVista, vagaID: UUID(), ocorridoEm: Self.instante),
            guardadoEm: Self.instante
        ))
        await fila.inserir(EventoDeTelemetriaPendente(
            contaID: conta, registro: RegistroDeEvento(evento: .appAberto, ocorridoEm: Self.instante),
            guardadoEm: Self.instante
        ))

        await registrador.reenviar()

        #expect(await api.eventosRegistrados.map(\.evento) == [.appAberto])
        #expect(try await fila.eventosPendentes().isEmpty)
    }

    @Test("Evento de outra conta não sai pelo login de quem entrou depois")
    func trocaDeContaNaoVaza() async throws {
        let (api, fila, registrador) = try await cenarioOffline()
        await fila.inserir(EventoDeTelemetriaPendente(
            contaID: UUID(), registro: RegistroDeEvento(evento: .checkinConcluido, ocorridoEm: Self.instante),
            guardadoEm: Self.instante
        ))

        await registrador.reenviar()

        #expect(await api.eventosRegistrados.isEmpty)
        #expect(try await fila.eventosPendentes().isEmpty)
    }

    @Test("Sem saber quem está logado nada é enviado e nada é perdido")
    func semContaConhecidaMantemFila() async throws {
        let (api, fila, registrador) = try await cenarioOffline()
        await fila.inserir(EventoDeTelemetriaPendente(
            contaID: try await api.minhaConta().id,
            registro: RegistroDeEvento(evento: .checkinConcluido, ocorridoEm: Self.instante), guardadoEm: Self.instante
        ))
        await api.definirRedeCaida(true)

        await registrador.reenviar()

        #expect(try await fila.eventosPendentes().count == 1)
        #expect(await api.eventosRegistrados.isEmpty)
    }

    @Test("Sem sessão local, o evento que falha não é guardado")
    func semDonoNaoGuarda() async throws {
        let api = ApiClienteEmMemoria(relogio: RelogioFixo(agora: Self.instante))
        let fila = FilaDeTelemetriaEmMemoria(contaAtual: nil)
        let registrador = RegistradorDeTelemetria(api: api, fila: fila, relogio: RelogioFixo(agora: Self.instante))
        await api.definirRedeCaida(true)

        await registrador.registrar(.checkinConcluido)

        #expect(try await fila.eventosPendentes().isEmpty)
    }

    @Test("A fila respeita o limite e descarta o evento mais antigo")
    func limiteDescartaOMaisAntigo() async throws {
        let (api, fila, registrador) = try await cenarioOffline()
        await api.definirRedeCaida(true)
        let total = RegistradorDeTelemetria.limiteDePendentes + 5

        for indice in 0..<total {
            await registrador.registrar(.appAberto, ocorridoEm: Self.instante.addingTimeInterval(Double(indice - total)))
        }

        let pendentes = try await fila.eventosPendentes()
        #expect(pendentes.count == RegistradorDeTelemetria.limiteDePendentes)
        // Sobraram os mais novos: os 5 primeiros saíram.
        #expect(pendentes.first?.registro.ocorridoEm == Self.instante.addingTimeInterval(Double(5 - total)))
        #expect(pendentes.last?.registro.ocorridoEm == Self.instante.addingTimeInterval(-1))
    }

    @Test("Evento mais velho que a idade máxima é descartado no reenvio")
    func idadeMaximaDescarta() async throws {
        let (api, fila, registrador) = try await cenarioOffline()
        let conta = try await api.minhaConta().id
        let velho = Self.instante.addingTimeInterval(-RegistradorDeTelemetria.idadeMaxima - 60)
        let recente = Self.instante.addingTimeInterval(-RegistradorDeTelemetria.idadeMaxima + 3600)
        await fila.inserir(EventoDeTelemetriaPendente(
            contaID: conta, registro: RegistroDeEvento(evento: .checkinConcluido, ocorridoEm: velho), guardadoEm: velho
        ))
        await fila.inserir(EventoDeTelemetriaPendente(
            contaID: conta, registro: RegistroDeEvento(evento: .checkoutConcluido, ocorridoEm: recente), guardadoEm: recente
        ))

        await registrador.reenviar()

        let enviados = await api.eventosRegistrados
        #expect(enviados.map(\.evento) == [.checkoutConcluido])
        #expect(enviados.first?.ocorridoEm == recente)
        #expect(try await fila.eventosPendentes().isEmpty)
    }

    @Test("Relógio adiantado: a data no futuro é limitada a agora, no envio direto e no guardado")
    func dataFuturaLimitadaAAgora() async throws {
        let (api, fila, registrador) = try await cenarioOffline()
        let futuro = Self.instante.addingTimeInterval(3600)

        // Direto: o servidor aceita porque a data foi limitada.
        let ok = await registrador.registrar(.checkinConcluido, ocorridoEm: futuro)
        #expect(ok == true)
        #expect(await api.eventosRegistrados.first?.ocorridoEm == Self.instante)

        // Guardado sem rede: sai com agora, não com o futuro.
        await api.definirRedeCaida(true)
        await registrador.registrar(.checkoutConcluido, ocorridoEm: futuro)
        #expect(try await fila.eventosPendentes().first?.registro.ocorridoEm == Self.instante)
    }

    @Test("Item guardado com data no futuro (relógio que voltou) sai limitado a agora")
    func reenvioLimitaDataFutura() async throws {
        let (api, fila, registrador) = try await cenarioOffline()
        let futuro = Self.instante.addingTimeInterval(7200)
        await fila.inserir(EventoDeTelemetriaPendente(
            contaID: try await api.minhaConta().id,
            registro: RegistroDeEvento(evento: .checkinConcluido, ocorridoEm: futuro), guardadoEm: Self.instante
        ))

        await registrador.reenviar()

        #expect(await api.eventosRegistrados.first?.ocorridoEm == Self.instante)
        #expect(try await fila.eventosPendentes().isEmpty)
    }

    @Test("Só guarda o que passa com o tempo: rede, servidor, sessão (401) e permissão (403); recusa 422/400 de formato não")
    func quaisErrosSaoGuardados() {
        let guarda: [CodigoErroAPI] = [.semRede, .desconhecido, .respostaInvalida, .limiteExcedido, .naoAutenticado, .semPermissao, .contaSuspensa]
        for codigo in guarda {
            #expect(RegistradorDeTelemetria.deveGuardar(depoisDe: ErroDaApi(codigo: codigo)))
        }
        let descarta: [CodigoErroAPI] = [.campoObrigatorio, .campoInvalido, .registroNoFuturo]
        for codigo in descarta {
            #expect(!RegistradorDeTelemetria.deveGuardar(depoisDe: ErroDaApi(codigo: codigo)))
        }
        #expect(!RegistradorDeTelemetria.deveGuardar(depoisDe: ErroDaApi(codigo: .campoInvalido, codigoOriginal: "400")))
        #expect(!RegistradorDeTelemetria.deveGuardar(depoisDe: ErroDaApi(codigo: .desconhecido, codigoOriginal: "http_400")))
        #expect(!RegistradorDeTelemetria.deveGuardar(depoisDe: ErroDaApi(codigo: .respostaInvalida, codigoOriginal: "http_400")))
        #expect(RegistradorDeTelemetria.deveGuardar(depoisDe: ErroDaApi(codigo: .respostaInvalida, codigoOriginal: "http_500")))
        #expect(RegistradorDeTelemetria.deveGuardar(depoisDe: ErroDaApi(codigo: .desconhecido, codigoOriginal: "http_503")))
        #expect(RegistradorDeTelemetria.deveGuardar(depoisDe: URLError(.notConnectedToInternet)))
        #expect(RegistradorDeTelemetria.deveGuardar(depoisDe: URLError(.timedOut)))
    }

    @Test("Erro 403 (semPermissao e contaSuspensa) preserva o evento na fila analítica de telemetria")
    func erro403PreservaFilaDeTelemetria() async throws {
        #expect(RegistradorDeTelemetria.deveGuardar(depoisDe: ErroDaApi(codigo: .semPermissao)))
        #expect(RegistradorDeTelemetria.deveGuardar(depoisDe: ErroDaApi(codigo: .contaSuspensa)))
    }

    @Test("Status HTTP transitórios (408 e 5xx) mapeados pela API preservam o evento na fila analítica de telemetria", arguments: [408, 500, 502, 503, 504])
    func statusHttpTransitoriosPreservamTelemetria(statusCode: Int) {
        let erroMapeado = DecodificadorErroAPI.mapear(statusCode: statusCode, dados: Data("Erro do gateway".utf8))
        #expect(RegistradorDeTelemetria.deveGuardar(depoisDe: erroMapeado))
    }

    @Test("Reenvio expurga evento recusado definitivamente com 422 e não bloqueia a fila")
    func reenvioExpurgaRecusa422ENaoBloqueiaFila() async throws {
        let (api, fila, registrador) = try await cenarioOffline()
        let conta = try await api.minhaConta().id

        // Evento 1: vaga_id inexistente faz api.registrarEvento lançar 422 campo_invalido
        let invalido = EventoDeTelemetriaPendente(
            contaID: conta,
            registro: RegistroDeEvento(evento: .checkinConcluido, vagaID: UUID(), ocorridoEm: Self.instante),
            guardadoEm: Self.instante
        )
        // Evento 2: válido, deve ser enviado com sucesso após o descarte do inválido
        let valido = EventoDeTelemetriaPendente(
            contaID: conta,
            registro: RegistroDeEvento(evento: .appAberto, ocorridoEm: Self.instante),
            guardadoEm: Self.instante
        )

        await fila.inserir(invalido)
        await fila.inserir(valido)

        await registrador.reenviar()

        // O evento inválido foi expurgado da fila
        let pendentes = try await fila.eventosPendentes()
        #expect(pendentes.isEmpty)

        // O evento válido foi enviado com sucesso
        let enviados = await api.eventosRegistrados
        #expect(enviados.count == 1)
        #expect(enviados.first?.evento == .appAberto)
    }

    @Test("Reenvio no SwiftData expurga EventoDeTelemetriaPersistido em caso de erro 4xx definitivo")
    func reenvioSwiftDataExpurgaErroDefinitivo() async throws {
        let container = try PersistenciaFrila.criarContainer(emMemoria: true)
        let armazenamento = ArmazenamentoSwiftData(modelContainer: container)
        let api = ApiClienteEmMemoria(relogio: RelogioFixo(agora: Self.instante))
        let conta = try await api.minhaConta().id
        try await armazenamento.salvar(sessao: SessaoUsuario(usuarioID: conta, perfil: .profissional))

        let registrador = RegistradorDeTelemetria(
            api: api,
            fila: armazenamento,
            relogio: RelogioFixo(agora: Self.instante)
        )

        // 1 evento inválido com vagaID inexistente (recusa 422 campo_invalido)
        try await armazenamento.guardar(
            RegistroDeEvento(evento: .checkinConcluido, vagaID: UUID(), ocorridoEm: Self.instante),
            em: Self.instante,
            limite: 10
        )
        // 1 evento válido
        try await armazenamento.guardar(
            RegistroDeEvento(evento: .appAberto, ocorridoEm: Self.instante),
            em: Self.instante,
            limite: 10
        )

        #expect(try await armazenamento.eventosPendentes().count == 2)

        await registrador.reenviar()

        // Ambos saíram do banco: o 422 por expurgo definitivo, o válido por envio bem-sucedido
        #expect(try await armazenamento.eventosPendentes().isEmpty)
        let enviados = await api.eventosRegistrados
        #expect(enviados.count == 1)
        #expect(enviados.first?.evento == .appAberto)
    }

    @Test("Reenvio com falha temporária de rede preserva toda a fila e não expurga")
    func reenvioComErroTemporarioPreservaFila() async throws {
        let (api, fila, registrador) = try await cenarioOffline()
        let conta = try await api.minhaConta().id

        let item1 = EventoDeTelemetriaPendente(
            contaID: conta,
            registro: RegistroDeEvento(evento: .appAberto, ocorridoEm: Self.instante),
            guardadoEm: Self.instante
        )
        let item2 = EventoDeTelemetriaPendente(
            contaID: conta,
            registro: RegistroDeEvento(evento: .checkinConcluido, ocorridoEm: Self.instante),
            guardadoEm: Self.instante
        )

        await fila.inserir(item1)
        await fila.inserir(item2)
        await api.definirRedeCaida(true)

        await registrador.reenviar()

        // Nenhum item expurgado
        let pendentes = try await fila.eventosPendentes()
        #expect(pendentes.count == 2)
        #expect(await api.eventosRegistrados.isEmpty)
    }

    @Test("O registrador sem fila mantém o comportamento antigo: falha de rede só devolve false")
    func semFilaNaoGuardaNada() async {
        let api = ApiClienteEmMemoria(cenario: .semRede)
        let registrador = RegistradorDeTelemetria(api: api, fila: nil)

        let ok = await registrador.registrar(.checkinConcluido)
        await registrador.reenviar()

        #expect(ok == false)
    }

    // MARK: - Fila persistida (SwiftData)

    @Test("A fila do SwiftData guarda para a conta da sessão e preserva a data")
    func swiftDataGuardaEPreserva() async throws {
        let armazenamento = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        let conta = UUID()
        try await armazenamento.salvar(sessao: SessaoUsuario(usuarioID: conta, perfil: .profissional))
        let registro = RegistroDeEvento(evento: .checkinConcluido, vagaID: UUID(), ocorridoEm: Self.instante.addingTimeInterval(-30))

        try await armazenamento.guardar(registro, em: Self.instante, limite: 10)

        let pendentes = try await armazenamento.eventosPendentes()
        #expect(pendentes.count == 1)
        #expect(pendentes.first?.contaID == conta)
        #expect(pendentes.first?.registro == registro)
        #expect(pendentes.first?.guardadoEm == Self.instante)
    }

    @Test("A fila do SwiftData não guarda sem sessão local")
    func swiftDataSemSessaoNaoGuarda() async throws {
        let armazenamento = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))

        try await armazenamento.guardar(RegistroDeEvento(evento: .appAberto), em: Self.instante, limite: 10)

        #expect(try await armazenamento.eventosPendentes().isEmpty)
    }

    @Test("A fila do SwiftData respeita o limite, remove por id e é apagada em limpar()")
    func swiftDataLimiteRemoverELimpar() async throws {
        let armazenamento = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        try await armazenamento.salvar(sessao: SessaoUsuario(usuarioID: UUID(), perfil: .contratante))
        for indice in 0..<5 {
            let guardadoEm = Self.instante.addingTimeInterval(Double(indice))
            try await armazenamento.guardar(RegistroDeEvento(evento: .appAberto, ocorridoEm: guardadoEm), em: guardadoEm, limite: 3)
        }

        let pendentes = try await armazenamento.eventosPendentes()
        #expect(pendentes.count == 3)
        #expect(pendentes.first?.guardadoEm == Self.instante.addingTimeInterval(2))

        try await armazenamento.remover(ids: [pendentes[0].id])
        #expect(try await armazenamento.eventosPendentes().count == 2)

        try await armazenamento.limpar()
        #expect(try await armazenamento.eventosPendentes().isEmpty)
    }

    @Test("A reserva do reenvio é exclusiva até ser liberada")
    func swiftDataReservaExclusiva() async throws {
        let armazenamento = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))

        #expect(await armazenamento.reservarReenvio() == true)
        #expect(await armazenamento.reservarReenvio() == false)
        await armazenamento.liberarReenvio()
        #expect(await armazenamento.reservarReenvio() == true)
    }
}

/// Fila em memória com as mesmas regras da persistida: dono = conta atual, limite e reserva do reenvio.
private actor FilaDeTelemetriaEmMemoria: FilaDeTelemetria {
    private let contaAtual: UUID?
    private var itens: [EventoDeTelemetriaPendente] = []
    private var reservada = false

    init(contaAtual: UUID?) { self.contaAtual = contaAtual }

    /// Põe direto um item, como se tivesse sido guardado antes (de outra conta, velho, no futuro).
    func inserir(_ item: EventoDeTelemetriaPendente) { itens.append(item) }

    func guardar(_ registro: RegistroDeEvento, em instante: Date, limite: Int) throws {
        guard let contaAtual else { return }
        itens.append(EventoDeTelemetriaPendente(contaID: contaAtual, registro: registro, guardadoEm: instante))
        if itens.count > limite { itens.removeFirst(itens.count - limite) }
    }

    func eventosPendentes() throws -> [EventoDeTelemetriaPendente] { itens }
    func remover(ids: [UUID]) throws { itens.removeAll { ids.contains($0.id) } }
    func reservarReenvio() -> Bool {
        if reservada { return false }
        reservada = true
        return true
    }
    func liberarReenvio() { reservada = false }
    func limpar() throws { itens.removeAll() }
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
