import Foundation
@testable import FrilaApresentacao
import FrilaDominio
import FrilaDados
import Testing

private final class CaixaCopia: @unchecked Sendable {
    var texto: String = ""
}

@MainActor
@Suite("Suporte no Turno: View Model e Montador de E-mail (#21)")
struct SuporteTurnoTests {

    private func criarContextoExemplo() -> ContextoSuporteTurno {
        let turnoID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let agora = Date(timeIntervalSince1970: 1775000000)
        let fim = agora.addingTimeInterval(4 * 3600)

        return ContextoSuporteTurno(
            turnoID: turnoID,
            funcao: "Garçom",
            contratante: "Bar do Lago",
            profissional: "Lucas Silva",
            inicio: agora,
            fim: fim,
            endereco: "CLS 405 Bloco C, Asa Sul, Brasília - DF"
        )
    }

    private func criarTurno(
        id: UUID = UUID(),
        funcao: String = "Cozinheiro",
        contraparte: String = "Restaurante Central",
        local: String = "CLN 202 Bloco B, Asa Norte"
    ) throws -> Turno {
        let inicio = Date(timeIntervalSince1970: 1775000000)
        let fim = inicio.addingTimeInterval(5 * 3600)
        let vaga = VagaResumo(
            id: UUID(),
            funcao: funcao,
            local: local,
            regiaoAdministrativa: "Plano Piloto",
            periodo: try Periodo(inicio: inicio, fim: fim),
            valor: Dinheiro(centavos: 18000)
        )
        let reputacao = Reputacao(positivas: 10, total: 10, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0)
        let perfilContraparte = PerfilPublico(
            id: UUID(),
            tipo: .estabelecimento,
            nome: contraparte,
            reputacao: reputacao
        )
        return Turno(
            id: id,
            posicaoID: UUID(),
            vaga: vaga,
            contraparte: perfilContraparte,
            contatoVisivelAte: fim,
            verificacao: .pendente,
            valorAcordado: Dinheiro(centavos: 18000),
            podeAvaliar: false
        )
    }

    @Test("Cenário 1: Contexto a partir de Turno (Profissional)")
    func contextoDoProfissional() throws {
        let turno = try criarTurno(
            funcao: "Cozinheiro",
            contraparte: "Restaurante Central",
            local: "CLN 202 Bloco B, Asa Norte"
        )

        let contexto = ContextoSuporteTurno(turno: turno, nomeProfissional: "Lucas")

        #expect(contexto.turnoID == turno.id)
        #expect(contexto.funcao == "Cozinheiro")
        #expect(contexto.contratante == "Restaurante Central")
        #expect(contexto.profissional == "Lucas")
        #expect(contexto.endereco == "CLN 202 Bloco B, Asa Norte")
        #expect(!contexto.horarioFormatado.isEmpty)
    }

    @Test("Cenário 2: Contexto a partir de TurnoAcompanhado (Contratante)")
    func contextoDoContratante() throws {
        let turnoID = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
        let inicio = Date(timeIntervalSince1970: 1775000000)
        let fim = inicio.addingTimeInterval(4 * 3600)
        let vaga = VagaResumo(
            id: UUID(),
            funcao: "Recepcionista",
            local: "Águas Claras Shopping",
            regiaoAdministrativa: "Águas Claras",
            periodo: try Periodo(inicio: inicio, fim: fim),
            valor: Dinheiro(centavos: 15000)
        )
        let reputacao = Reputacao(positivas: 5, total: 5, taxaComparecimento: 1.0, turnosConsiderados: 5, turnosRealizados: 5)
        let profissional = PerfilPublico(
            id: UUID(),
            tipo: .profissional,
            nome: "Ana Santos",
            reputacao: reputacao
        )
        let posicao = PosicaoNoPainel(
            id: UUID(),
            estado: .confirmada,
            profissional: profissional,
            turnoID: turnoID,
            verificacao: .verificado,
            emAtraso: false
        )
        let acompanhado = TurnoAcompanhado(vaga: vaga, posicao: posicao)

        let contexto = ContextoSuporteTurno(turnoAcompanhado: acompanhado, nomeContratante: "Boutique Flores")

        #expect(contexto.turnoID == turnoID)
        #expect(contexto.funcao == "Recepcionista")
        #expect(contexto.contratante == "Boutique Flores")
        #expect(contexto.profissional == "Ana Santos")
        #expect(contexto.endereco == "Águas Claras Shopping")
    }

    @Test("Cenário 3: Assunto estruturado com [Turno <uuid>]")
    func assuntoEmailPadronizado() {
        let contexto = criarContextoExemplo()
        let vm = SuporteTurnoViewModel(dados: contexto)

        let assuntoEsperado = "[Turno 11111111-2222-3333-4444-555555555555] Garçom"
        #expect(vm.assuntoEmail == assuntoEsperado)
        #expect(vm.assuntoEmail.hasPrefix("[Turno 11111111-2222-3333-4444-555555555555]"))
    }

    @Test("Cenário 4: Corpo do e-mail estruturado com dados completos e relato")
    func corpoEmailEstruturado() {
        let contexto = criarContextoExemplo()
        let vm = SuporteTurnoViewModel(
            dados: contexto,
            motivoInicial: .atrasoOuImprevisto,
            relatoInicial: "Houve um acidente na via e vou atrasar 20 minutos."
        )

        let corpo = vm.corpoEmail

        #expect(corpo.contains("11111111-2222-3333-4444-555555555555"))
        #expect(corpo.contains("Função: Garçom"))
        #expect(corpo.contains("Contratante: Bar do Lago"))
        #expect(corpo.contains("Profissional: Lucas Silva"))
        #expect(corpo.contains("Local: CLS 405 Bloco C, Asa Sul, Brasília - DF"))
        #expect(corpo.contains("Atraso ou imprevisto no comparecimento"))
        #expect(corpo.contains("Houve um acidente na via e vou atrasar 20 minutos."))
    }

    @Test("Cenário 5: Risco à segurança ativa alerta e números 190 e 180")
    func riscoSegurancaAtivaAlerta() {
        let contexto = criarContextoExemplo()
        let vm = SuporteTurnoViewModel(dados: contexto, motivoInicial: .problemaNoLocal)

        #expect(!vm.ehRiscoSeguranca)

        vm.motivo = .riscoSeguranca
        #expect(vm.ehRiscoSeguranca)

        vm.motivo = .outro
        #expect(!vm.ehRiscoSeguranca)
    }

    @Test("Cenário 6: URL mailto de fallback contém destinatário, assunto e corpo codificados")
    func urlMailtoFallback() {
        let contexto = criarContextoExemplo()
        let vm = SuporteTurnoViewModel(dados: contexto, emailDestino: "suportefrila@gmail.com")

        guard let url = vm.urlMailto else {
            Issue.record("A URL mailto deve ser gerada com sucesso")
            return
        }

        #expect(url.scheme == "mailto")
        #expect(url.path == "suportefrila@gmail.com")

        let componentes = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let assuntoParam = componentes?.queryItems?.first(where: { $0.name == "subject" })?.value
        let corpoParam = componentes?.queryItems?.first(where: { $0.name == "body" })?.value

        #expect(assuntoParam == vm.assuntoEmail)
        #expect(corpoParam == vm.corpoEmail)
    }

    @Test("Cenário 7: Copiar dados para a área de transferência com sucesso")
    func copiarDadosSuporte() {
        let contexto = criarContextoExemplo()
        let caixa = CaixaCopia()
        let vm = SuporteTurnoViewModel(
            dados: contexto,
            copiador: { texto in caixa.texto = texto }
        )

        #expect(!vm.copiadoComSucesso)
        vm.copiarDadosParaTransferencia()

        #expect(vm.copiadoComSucesso)
        #expect(caixa.texto.contains("Assunto: [Turno 11111111-2222-3333-4444-555555555555] Garçom"))
        #expect(caixa.texto.contains("Para: suporte@frila.app"))
        #expect(caixa.texto.contains(contexto.endereco))
    }

    @Test("Cenário 8: Fallback ao abrir e-mail nativo vs mailto")
    func fallbackAberturaEmail() {
        let contexto = criarContextoExemplo()

        // 8a: Com e-mail nativo configurado
        let vmNativo = SuporteTurnoViewModel(
            dados: contexto,
            verificadorPodeEnviarEmail: { true }
        )
        #expect(vmNativo.podeEnviarEmailNativo)
        #expect(!vmNativo.mostrandoCompositorNativo)

        vmNativo.abrirEmail()
        #expect(vmNativo.mostrandoCompositorNativo)

        // 8b: Sem e-mail nativo -> chama abridor de URL (mailto)
        var urlAberta: URL?
        let vmSemNativo = SuporteTurnoViewModel(
            dados: contexto,
            verificadorPodeEnviarEmail: { false }
        )
        #expect(!vmSemNativo.podeEnviarEmailNativo)

        vmSemNativo.abrirEmail(comAbridorURL: { url in urlAberta = url })
        #expect(!vmSemNativo.mostrandoCompositorNativo)
        #expect(urlAberta?.scheme == "mailto")
    }

    @Test("Compositor nativo concluído baixa a bandeira da folha: o botão de e-mail volta a abrir sem fechar a folha")
    func compositorConcluidoBaixaABandeira() {
        let vm = SuporteTurnoViewModel(dados: criarContextoExemplo(), verificadorPodeEnviarEmail: { true })
        vm.abrirEmail()
        #expect(vm.mostrandoCompositorNativo)
        vm.compositorConcluido()
        #expect(!vm.mostrandoCompositorNativo)
        vm.abrirEmail()
        #expect(vm.mostrandoCompositorNativo)
    }

    @Test("Quando a abertura do mailto falha por falta de cliente de e-mail, registra falha para aviso na tela")
    func falhaAoAbrirEmailRegistrada() {
        let vm = SuporteTurnoViewModel(
            dados: criarContextoExemplo(),
            verificadorPodeEnviarEmail: { false }
        )
        #expect(!vm.podeEnviarEmailNativo)
        #expect(!vm.falhaAoAbrirEmail)

        vm.abrirEmail(comAbridorComResultado: { _, completion in
            completion(false)
        })

        #expect(vm.falhaAoAbrirEmail)
        #expect(!vm.mostrandoCompositorNativo)
    }

    @Test("Quando a abertura do mailto é aceita pelo sistema, não registra falha de e-mail")
    func sucessoAoAbrirEmailNaoRegistraFalha() {
        let vm = SuporteTurnoViewModel(
            dados: criarContextoExemplo(),
            verificadorPodeEnviarEmail: { false }
        )
        vm.abrirEmail(comAbridorComResultado: { _, completion in
            completion(true)
        })

        #expect(!vm.falhaAoAbrirEmail)
    }

    // MARK: - Testes da RPC abrir_suporte (contrato 0.2.40)

    private final class ApiDeSuporteTeste: ApiClienteEncaminhador, @unchecked Sendable {
        var chamados: [(turnoID: UUID, categoria: CategoriaSuporte, chave: UUID)] = []
        var falha: ErroDaApi?
        var protocolosPorChave: [UUID: Protocolo] = [:]
        var contagemPorDia: Int = 0

        init(falha: ErroDaApi? = nil) {
            self.falha = falha
            super.init()
        }

        override func abrirSuporte(turnoID: UUID, categoria: CategoriaSuporte, chave: UUID) async throws -> Protocolo {
            if let falha { throw falha }
            if let gravado = protocolosPorChave[chave] { return gravado }
            if contagemPorDia >= 5 {
                throw ErroDaApi(codigo: .limiteExcedido)
            }
            contagemPorDia += 1
            chamados.append((turnoID, categoria, chave))
            let protocolo = Protocolo(
                ocorrenciaID: UUID(uuidString: "12345678-aaaa-bbbb-cccc-dddddddddddd")!,
                tipo: .suporte,
                criadaEm: Date(),
                prazoRespostaAte: try! DataCivil("2026-10-16")
            )
            protocolosPorChave[chave] = protocolo
            return protocolo
        }
    }

    @Test("Cenário 9: registrarEEnviar chama abrirSuporte e atualiza protocolo e assunto")
    func registrarEEnviarComSucesso() async throws {
        let contexto = criarContextoExemplo()
        let api = ApiDeSuporteTeste()

        var urlAberta: URL?
        let vm = SuporteTurnoViewModel(
            dados: contexto,
            api: api,
            motivoInicial: .outro,
            verificadorPodeEnviarEmail: { false }
        )

        #expect(vm.protocolo == nil)
        #expect(!vm.assuntoEmail.contains("[Frila Suporte #"))

        await vm.registrarEEnviar(abridorURL: { url in urlAberta = url })

        #expect(vm.protocolo != nil)
        guard let prot = vm.protocolo else { return }
        #expect(prot.tipo == .suporte)
        #expect(!prot.protocoloCurto.isEmpty)
        #expect(prot.protocoloCurto == "12345678")
        #expect(vm.assuntoEmail == "[Frila Suporte #12345678] \(contexto.funcao)")
        #expect(urlAberta?.absoluteString.contains("12345678") == true)
        #expect(vm.mensagemDeErro == nil)
        #expect(api.chamados.count == 1)
        #expect(api.chamados[0].turnoID == contexto.turnoID)
        #expect(api.chamados[0].categoria == .outro)
    }

    @Test("Cenário 10: registrarEEnviar com conta suspensa exibe mensagem amigável sem abrir e-mail")
    func registrarEEnviarComContaSuspensa() async throws {
        let contexto = criarContextoExemplo()
        let api = ApiDeSuporteTeste(falha: ErroDaApi(codigo: .semPermissao, detalhes: "conta_suspensa"))

        var urlAberta: URL?
        let vm = SuporteTurnoViewModel(
            dados: contexto,
            api: api,
            verificadorPodeEnviarEmail: { false }
        )

        await vm.registrarEEnviar(abridorURL: { url in urlAberta = url })

        #expect(vm.protocolo == nil)
        #expect(vm.mensagemDeErro == TextosDoSuporte.contaSuspensa)
        #expect(urlAberta == nil)
    }

    @Test("Cenário 11: registrarEEnviar após 5 chamados no mesmo dia acusa limite excedido")
    func registrarEEnviarLimiteExcedido() async throws {
        let contexto = criarContextoExemplo()
        let api = ApiDeSuporteTeste()

        for _ in 1...5 {
            _ = try await api.abrirSuporte(turnoID: contexto.turnoID, categoria: .outro, chave: UUID())
        }

        var urlAberta: URL?
        let vm = SuporteTurnoViewModel(
            dados: contexto,
            api: api,
            verificadorPodeEnviarEmail: { false }
        )

        await vm.registrarEEnviar(abridorURL: { url in urlAberta = url })

        #expect(vm.protocolo == nil)
        #expect(vm.mensagemDeErro == TextosDoSuporte.limiteExcedido)
        #expect(urlAberta == nil)
    }

    @Test("Cenário 12: Idempotência por chave reutiliza o mesmo protocolo")
    func idempotenciaDeChave() async throws {
        let contexto = criarContextoExemplo()
        let api = ApiDeSuporteTeste()

        let chaveFixa = UUID()
        let prot1 = try await api.abrirSuporte(turnoID: contexto.turnoID, categoria: .atraso, chave: chaveFixa)
        let prot2 = try await api.abrirSuporte(turnoID: contexto.turnoID, categoria: .atraso, chave: chaveFixa)

        #expect(prot1.ocorrenciaID == prot2.ocorrenciaID)
        #expect(prot1.protocoloCurto == prot2.protocoloCurto)
        #expect(api.chamados.count == 1)
    }
}

