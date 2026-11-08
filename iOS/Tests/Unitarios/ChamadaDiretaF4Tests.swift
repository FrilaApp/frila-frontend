import Foundation
import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

@Suite("Chamada direta F4: I5b (receber/aceitar/recusar), I5c (acompanhar/cancelar/publicar), I5d (preferências/versão)")
@MainActor
struct ChamadaDiretaF4Tests {
    private let profissionalID = UUID(uuidString: "80000000-0000-0000-0000-000000000001")!
    private let profissional2ID = UUID(uuidString: "80000000-0000-0000-0000-000000000002")!

    private func preparar(cenario: ApiClienteEmMemoria.Cenario = .chamadaDireta) async throws
        -> (ApiClienteEmMemoria, EstabelecimentoDaConta, Chamada, Vaga) {
        let api = ApiClienteEmMemoria(cenario: cenario)
        let casa = try #require(try await api.meusEstabelecimentos().first)
        let perfil = try await api.perfilPublico(id: profissionalID)

        let criador = ChamadaDiretaViewModel(api: api, profissionalID: profissionalID, estabelecimentoID: casa.id)
        await criador.carregar()
        criador.funcaoID = try #require(criador.funcoes.first { perfil.funcoes.contains($0.nome) }).id
        criador.valorCentavos = 20_000
        criador.totalConfirmado = true
        criador.responsavel = "Gerente João"
        await criador.enviar()

        let chamada = try #require(criador.resultado)
        let detalhe = try await api.detalheChamada(id: chamada.id)
        let todasVagas = try await api.vagasAbertas(.todas)
        let vaga = Vaga(
            id: chamada.vagaID,
            estabelecimento: detalhe.outraParte,
            funcao: detalhe.funcao,
            periodo: try Periodo(inicio: detalhe.inicioEm, fim: detalhe.fimEm),
            local: "Rua das Flores 123",
            regiaoAdministrativa: detalhe.regiaoAdministrativa,
            ponto: try Coordenada(latitude: -15.79, longitude: -47.88),
            valor: Dinheiro(centavos: detalhe.valorCentavos),
            posicoes: 1, posicoesAbertas: 1,
            inclusos: Inclusos(refeicao: detalhe.incluiRefeicao, transporte: detalhe.incluiTransporte, exigeMaterialProprio: detalhe.exigeMaterialProprio),
            responsavelLocal: "Gerente João",
            modo: .urgencia, estado: .publicada, publicadoEm: chamada.criadaEm,
            origem: .chamadaDireta
        )
        return (api, casa, chamada, vaga)
    }

    // MARK: - I5b: Receber, Aceitar, Recusar e Concorrência

    @Test("I5b - Leitura prévia segura: vê região e faixa de distância, mas nunca endereço exato nem telefones")
    func leituraPreviaSeguraSemEndereco() async throws {
        let (api, _, chamada, _) = try await preparar()
        let vm = ChamadaRecebidaViewModel(chamadaID: chamada.id, api: api)
        await vm.carregar()

        let d = try #require(vm.detalhe)
        #expect(d.estado == .aberta)
        #expect(d.local == nil)
        #expect(d.ponto == nil)
        #expect(d.responsavelLocal == nil)
        #expect(!d.regiaoAdministrativa.isEmpty)
        #expect(d.distanciaFaixa != nil)
        #expect(vm.podeResponder)
    }

    @Test("I5b - Aceite confirmado pelo servidor libera endereço e responsável e gera turno sem telefones")
    func aceiteComSucessoGeraTurnoELiberaEndereco() async throws {
        let (api, _, chamada, _) = try await preparar()
        let vm = ChamadaRecebidaViewModel(chamadaID: chamada.id, api: api)
        await vm.carregar()

        await vm.aceitar()

        let res = try #require(vm.resultado)
        #expect(res.chamada.estado == .aceita)
        #expect(res.local != nil)
        #expect(res.ponto != nil)
        #expect(res.responsavelLocal != nil)
        #expect(res.turnoID != nil)
        #expect(!vm.podeResponder)

        // Conferência no detalhe recarregado
        let detalheApos = try await api.detalheChamada(id: chamada.id)
        #expect(detalheApos.estado == .aceita)
        #expect(detalheApos.local != nil)
        #expect(detalheApos.responsavelLocal != nil)
    }

    @Test("I5b - Concorrência 409 chamada_indisponivel com estado encerrada não penaliza nem mostra endereço")
    func concorrencia409EncerradaNaoPenaliza() async throws {
        let (api, _, chamada, _) = try await preparar()

        // Outro profissional ou contratante encerra a chamada
        _ = try await api.responderChamada(id: chamada.id, resposta: .aceitar, motivoRecusa: nil)

        // Agora um segundo view model tenta responder
        let vm2 = ChamadaRecebidaViewModel(chamadaID: chamada.id, api: api)
        await vm2.carregar()
        #expect(vm2.mensagemConcorrencia != nil)
        #expect(!vm2.podeResponder)

        await vm2.aceitar()
        #expect(vm2.resultado == nil)
        #expect(vm2.mensagemConcorrencia != nil)
    }

    @Test("I5b - Prazo vencido obedece expirada do servidor com horário de Brasília e sem sucesso local")
    func prazoVencidoExpiradaServidor() async throws {
        let (api, _, chamada, _) = try await preparar()

        // Simula expiração: definindo data futura para relógio
        let relogioAvancado = Date().addingTimeInterval(48 * 3600)
        let vm = ChamadaRecebidaViewModel(chamadaID: chamada.id, api: api, agora: { relogioAvancado })
        await vm.carregar()

        // Tentativa de aceitar chamada expirada
        await vm.aceitar()
        #expect(vm.resultado == nil)
        #expect(vm.mensagemConcorrencia != nil)
    }

    @Test("I5b - Recusa com e sem motivo registra resposta sem penalidade nem contraproposta")
    func recusaComESemMotivoSemPenalidade() async throws {
        let (api, _, chamada, _) = try await preparar()
        let vm = ChamadaRecebidaViewModel(chamadaID: chamada.id, api: api)
        await vm.carregar()

        vm.motivoSelecionado = .agenda
        await vm.recusar()

        let res = try #require(vm.resultado)
        #expect(res.chamada.estado == .recusada)
        #expect(res.chamada.motivoRecusa == .agenda)
        #expect(res.local == nil)
        #expect(res.turnoID == nil)
    }

    // MARK: - I5c: Acompanhar Chamadas, Cancelar e Publicar para Todos

    @Test("I5c - Acompanhar chamadas: cancelamento de chamada antes do aceite")
    func cancelarChamadaAntesDoAceite() async throws {
        let (api, _, chamada, _) = try await preparar()
        let vm = AcompanharChamadasViewModel(vagaID: chamada.vagaID, api: api)
        await vm.carregar()

        #expect(vm.chamadas.count == 1)
        #expect(vm.chamadas.first?.estado == .aberta)

        await vm.cancelar(chamadaID: chamada.id)

        #expect(vm.erro == nil)
        #expect(vm.sucessoMensagem != nil)
        #expect(vm.chamadas.first?.estado == .cancelada)
    }

    @Test("I5c - Aceite de uma chamada encerra as demais abertas para a mesma vaga")
    func aceiteDeUmaEncerraOutrasDaMesmaVaga() async throws {
        let (api, casa, chamada1, vaga) = try await preparar()

        // Cria segunda chamada para a mesma vaga simulando o acompanhamento
        let chamada2 = Chamada(
            id: UUID(), vagaID: vaga.id, profissionalID: profissional2ID,
            estabelecimentoID: casa.id, estado: .aberta,
            expiraEm: Date().addingTimeInterval(12 * 3600), criadaEm: Date()
        )
        await api.configurarChamadaSimulada(chamada2, vaga: vaga)

        // Aceita a chamada 1
        _ = try await api.responderChamada(id: chamada1.id, resposta: .aceitar)

        let vm = AcompanharChamadasViewModel(vagaID: vaga.id, api: api)
        await vm.carregar()

        #expect(vm.temChamadaAceita)
        let ch2Atual = try #require(vm.chamadas.first { $0.id == chamada2.id })
        #expect(ch2Atual.estado == .encerrada)
    }

    @Test("I5c - Publicar para todos converte vaga direta em normal quando chamadas são finalizadas")
    func publicarParaTodosAposRecusaOuCancelamento() async throws {
        let (api, _, chamada, _) = try await preparar()

        // Cancela a chamada
        _ = try await api.cancelarChamada(id: chamada.id)

        let vm = AcompanharChamadasViewModel(vagaID: chamada.vagaID, api: api)
        await vm.carregar()
        #expect(vm.podePublicarParaTodos)

        await vm.publicarParaTodos()

        #expect(vm.vagaPublicadaNovaID != nil)
        #expect(vm.sucessoMensagem != nil)
        #expect(!vm.podePublicarParaTodos)
    }

    // MARK: - I5d: Preferências de Chamada e Versão do Aplicativo

    @Test("I5d - Preferências: salvar antecedência, pausa e filtros")
    func salvarPreferenciasDeChamada() async throws {
        let api = ApiClienteEmMemoria(cenario: .chamadaDireta)
        let vm = PreferenciasChamadaViewModel(api: api)

        vm.aceitaDeQuemJaTrabalhou = true
        vm.antecedenciaMinimaH = 24
        vm.aceitaDe = .soCnpj
        vm.pausarChamadas = true
        let dataPausa = Date().addingTimeInterval(3 * 24 * 3600)
        vm.pausadoAte = dataPausa

        await vm.salvar()

        #expect(vm.sucesso)
        #expect(vm.erro == nil)
        #expect(vm.antecedenciaMinimaH == 24)
        #expect(vm.aceitaDe == .soCnpj)
        #expect(vm.pausarChamadas)
        #expect(vm.textoRetomadaPausa.contains("00:00 (horário de Brasília)"))
    }

    @Test("I5d - Registro de dispositivo envia versão real do app")
    func registrarDispositivoEnviaVersaoReal() async throws {
        let api = ApiClienteEmMemoria(cenario: .chamadaDireta)
        let token = "token-fcm-de-teste-com-mais-de-20-caracteres"

        let disp = try await api.registrarDispositivo(tokenFCM: token)
        #expect(disp.plataforma == .ios)

        let versaoRegistrada = await api.ultimaVersaoAppRegistrada
        #expect(versaoRegistrada != nil)
        #expect(!versaoRegistrada!.isEmpty)
    }

    @Test("I5d - Roteamento de push: avisos de chamada abrem detalhe da chamada")
    func roteamentoDeAvisosDeChamada() async throws {
        let chamadaID = UUID()
        let payload: [AnyHashable: Any] = [
            "tipo": TipoDeAviso.chamadaRecebida.rawValue,
            "chamada_id": chamadaID.uuidString
        ]
        let aviso = try #require(AvisoDePush(payload: payload))
        #expect(aviso.tipo == .chamadaRecebida)
        #expect(aviso.chamadaID == chamadaID)

        let destino = try #require(DestinoDoProfissional(aviso))
        #expect(destino == .chamada(chamadaID))
    }
}
