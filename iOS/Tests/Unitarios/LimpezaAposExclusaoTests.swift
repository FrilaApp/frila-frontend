import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

@MainActor
@Suite("Limpeza após exclusão de conta e dublê em memória (#50)")
struct LimpezaAposExclusaoTests {

    private func criarArmazenamentoLocal() throws -> ArmazenamentoSwiftData {
        let container = try PersistenciaFrila.criarContainer(emMemoria: true)
        return ArmazenamentoSwiftData(modelContainer: container)
    }

    private func criarUserDefaultsIsolado() -> (UserDefaults, String) {
        let nome = "LimpezaAposExclusaoTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: nome)!
        return (defaults, nome)
    }

    private func popularDadosLocais(no local: ArmazenamentoSwiftData, instante: Date, defaults: UserDefaults) async throws -> Turno {
        let inicio = instante.addingTimeInterval(3_600)
        let fim = inicio.addingTimeInterval(3_600)
        let resumo = VagaResumo(
            id: UUID(), funcao: "Garçom", local: "Asa Sul", regiaoAdministrativa: "Plano Piloto",
            periodo: try Periodo(inicio: inicio, fim: fim), valor: Dinheiro(centavos: 12_000)
        )
        let visivelAte = fim.addingTimeInterval(7 * 24 * 3_600)
        let contato = Contato(
            nome: "Bistrô",
            telefone: "+5561999990000",
            whatsappURL: URL(string: "https://wa.me/5561999990000")!,
            visivelAte: visivelAte
        )
        let turno = Turno(
            id: UUID(), posicaoID: UUID(), vaga: resumo,
            contraparte: PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: "Bistrô", reputacao: Reputacao(positivas: 1, total: 1, taxaComparecimento: 1, turnosConsiderados: 1, turnosRealizados: 1)),
            contatoVisivelAte: visivelAte, verificacao: .pendente, valorAcordado: resumo.valor, podeAvaliar: false,
            contato: contato
        )
        try await local.salvar(sessao: SessaoUsuario(usuarioID: UUID(), perfil: .profissional))
        try await local.salvar(turnos: [turno], em: instante)
        try await local.salvar(funcoes: [Funcao(id: UUID(), nome: "Garçom", categoria: "Restaurante")])
        try await local.enfileirar(AcaoPendente(tipo: .checkin, turnoID: turno.id, instanteDoToque: instante, chave: UUID(), distanciaMetros: 20))
        DestinoGuardado.salvar(.profissional, em: defaults)
        return turno
    }

    @Test("Limpeza: Sucesso na exclusão apaga cache, fila, destino guardado e encerra sessão (Critério 2)")
    func sucessoLimpaAparelho() async throws {
        let (defaults, suiteName) = criarUserDefaultsIsolado()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let local = try criarArmazenamentoLocal()
        let instante = Date(timeIntervalSince1970: 1_800_000_000)
        _ = try await popularDadosLocais(no: local, instante: instante, defaults: defaults)

        #expect(try await local.sessao() != nil)
        #expect(try await !local.turnosValidos(em: instante).isEmpty)
        #expect(try await !local.pendentes().isEmpty)
        #expect(DestinoGuardado.obter(de: defaults) == .profissional)

        let api = ApiClienteEmMemoria()
        let saida = SaidaDaConta(api: api, armazenamento: local, limparDestino: {
            if let defs = UserDefaults(suiteName: suiteName) {
                DestinoGuardado.limpar(em: defs)
            }
        })

        let resultado = try await saida.excluir()
        #expect(resultado.turnosCancelados >= 0)

        // Verificações de limpeza
        #expect(DestinoGuardado.obter(de: defaults) == nil)
        #expect(try await local.sessao() == nil)
        #expect(try await local.turnosValidos(em: instante).isEmpty)
        #expect(try await local.funcoes().isEmpty)
        #expect(try await local.pendentes().isEmpty)
        #expect(await !api.possuiSessao())
    }

    @Test("Cuidado crítico: Erro de rede na exclusão NÃO limpa cache, fila nem sessão")
    func erroDeRedeNaoLimpaAparelho() async throws {
        let (defaults, suiteName) = criarUserDefaultsIsolado()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let local = try criarArmazenamentoLocal()
        let instante = Date(timeIntervalSince1970: 1_800_000_000)
        _ = try await popularDadosLocais(no: local, instante: instante, defaults: defaults)

        let api = ApiClienteEmMemoria(cenario: .semRede)
        let saida = SaidaDaConta(api: api, armazenamento: local, limparDestino: {
            if let defs = UserDefaults(suiteName: suiteName) {
                DestinoGuardado.limpar(em: defs)
            }
        })

        do {
            _ = try await saida.excluir()
            Issue.record("Deveria ter lançado erro de rede")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .semRede)
        }

        // Nada pode ser apagado se o servidor não confirmou a exclusão!
        #expect(DestinoGuardado.obter(de: defaults) == .profissional)
        #expect(try await local.sessao() != nil)
        #expect(try await !local.turnosValidos(em: instante).isEmpty)
        #expect(try await !local.pendentes().isEmpty)
        #expect(try await !local.funcoes().isEmpty)
    }

    @Test("Cuidado crítico: Erro 409 administrador_unico NÃO limpa cache, fila nem sessão")
    func erroAdministradorUnicoNaoLimpaAparelho() async throws {
        let (defaults, suiteName) = criarUserDefaultsIsolado()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let local = try criarArmazenamentoLocal()
        let instante = Date(timeIntervalSince1970: 1_800_000_000)
        _ = try await popularDadosLocais(no: local, instante: instante, defaults: defaults)

        let api = ApiClienteEmMemoria()
        await api.configurarCenarioExclusao(.administradorUnico)
        let saida = SaidaDaConta(api: api, armazenamento: local, limparDestino: {
            if let defs = UserDefaults(suiteName: suiteName) {
                DestinoGuardado.limpar(em: defs)
            }
        })

        do {
            _ = try await saida.excluir()
            Issue.record("Deveria ter lançado erro de administrador_unico")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .administradorUnico)
        }

        // Nada pode ser apagado se o servidor recusou com conflito!
        #expect(DestinoGuardado.obter(de: defaults) == .profissional)
        #expect(try await local.sessao() != nil)
        #expect(try await !local.turnosValidos(em: instante).isEmpty)
        #expect(try await !local.pendentes().isEmpty)
    }

    @Test("Cuidado crítico: Erro 401 nao_autenticado NÃO limpa cache, fila nem sessão")
    func erro401NaoAutenticadoNaoLimpaAparelho() async throws {
        let (defaults, suiteName) = criarUserDefaultsIsolado()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let local = try criarArmazenamentoLocal()
        let instante = Date(timeIntervalSince1970: 1_800_000_000)
        _ = try await popularDadosLocais(no: local, instante: instante, defaults: defaults)

        let api = ApiClienteEmMemoria()
        await api.configurarCenarioExclusao(.naoAutenticado)
        let saida = SaidaDaConta(api: api, armazenamento: local, limparDestino: {
            if let defs = UserDefaults(suiteName: suiteName) {
                DestinoGuardado.limpar(em: defs)
            }
        })

        do {
            _ = try await saida.excluir()
            Issue.record("Deveria ter lançado erro de nao_autenticado")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .naoAutenticado)
        }

        // Com 401, nada pode ser apagado se a exclusão falhou na porta
        #expect(DestinoGuardado.obter(de: defaults) == .profissional)
        #expect(try await local.sessao() != nil)
        #expect(try await !local.turnosValidos(em: instante).isEmpty)
        #expect(try await !local.pendentes().isEmpty)
        #expect(try await !local.funcoes().isEmpty)
    }

    @Test("Cuidado crítico: Chamada direta com porta lançando 401 NÃO limpa cache nem fila")
    func portaCom401NaoLimpaAparelho() async throws {
        struct Porta401: ExclusaoDeContaPorta {
            func excluirConta() async throws -> ExclusaoDeConta {
                throw ErroDaApi(codigo: .naoAutenticado)
            }
        }

        let (defaults, suiteName) = criarUserDefaultsIsolado()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let local = try criarArmazenamentoLocal()
        let instante = Date(timeIntervalSince1970: 1_800_000_000)
        _ = try await popularDadosLocais(no: local, instante: instante, defaults: defaults)

        let api = ApiClienteEmMemoria()
        let saida = SaidaDaConta(api: api, armazenamento: local, limparDestino: {
            if let defs = UserDefaults(suiteName: suiteName) {
                DestinoGuardado.limpar(em: defs)
            }
        })

        do {
            _ = try await saida.excluir(porta: Porta401())
            Issue.record("Deveria ter lançado erro de nao_autenticado")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .naoAutenticado)
        }

        #expect(DestinoGuardado.obter(de: defaults) == .profissional)
        #expect(try await local.sessao() != nil)
        #expect(try await !local.turnosValidos(em: instante).isEmpty)
        #expect(try await !local.pendentes().isEmpty)
    }

    @Test("Dublê em memória: após exclusão, minhaConta responde como primeiro acesso (Critério 3)")
    func reentradaAposExclusaoComecaCadastroDoZero() async throws {
        let api = ApiClienteEmMemoria()

        // Antes da exclusão, a conta existe
        let contaAntes = try await api.minhaConta()
        #expect(!contaAntes.nome.isEmpty)

        // Exclui a conta
        let resultado = try await api.excluirConta()
        #expect(resultado.turnosCancelados >= 0)
        #expect(await !api.possuiSessao())

        // Chamada direta a minhaConta responde 404 nao_encontrado (primeiro acesso)
        do {
            _ = try await api.minhaConta()
            Issue.record("Deveria ter lançado nao_encontrado (primeiro acesso)")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .naoEncontrado)
        }

        // Entrar de novo com o mesmo e-mail (simula re-autenticação)
        try await api.verificarCodigo(email: contaAntes.email, codigo: "123456")
        #expect(await api.possuiSessao())

        // Destino da conta direciona para cadastro
        let destino = try await DestinoDaConta.avaliar(api: api)
        if case .cadastro = destino {
            // Sucesso: direcionado para cadastro!
        } else {
            Issue.record("Deveria ter direcionado para cadastro após exclusão, mas foi para \(destino)")
        }
    }

    @Test("Dublê em memória: cenário com turnos cancelados cancela turnos futuros")
    func dubleCenarioTurnosCancelados() async throws {
        let api = ApiClienteEmMemoria()
        await api.configurarCenarioExclusao(.comTurnosCancelados(4))

        let resultado = try await api.excluirConta()
        #expect(resultado.turnosCancelados == 4)
        #expect(try await api.meusTurnos().isEmpty)
    }

    @Test("Exclusão de conta: Keychain e cache limpos e recadastro do mesmo e-mail começa do zero (#ABN4rvmT)")
    func exclusaoLimpaKeychainCacheERecadastroComMesmoEmail() async throws {
        let servico = "com.frila.org.app.teste.exclusao.\(UUID().uuidString)"
        let keychain = SessaoNoKeychainDoAparelho(servico: servico)
        let chaveToken = "supabase.auth.token"
        defer { try? keychain.remove(key: chaveToken) }

        // 1. Grava sessão inicial no Keychain real isolado
        let tokenOriginal = Data("sessao-supabase-autenticada-1".utf8)
        try keychain.store(key: chaveToken, value: tokenOriginal)
        #expect(try keychain.retrieve(key: chaveToken) == tokenOriginal)

        // 2. Popula dados locais (SwiftData e UserDefaults de destino)
        let (defaults, suiteName) = criarUserDefaultsIsolado()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let local = try criarArmazenamentoLocal()
        let instante = Date(timeIntervalSince1970: 1_800_000_000)
        _ = try await popularDadosLocais(no: local, instante: instante, defaults: defaults)

        #expect(try await local.sessao() != nil)
        #expect(try await !local.turnosValidos(em: instante).isEmpty)
        #expect(try await !local.pendentes().isEmpty)
        #expect(DestinoGuardado.obter(de: defaults) == .profissional)

        // 3. Cliente da API com conta existente
        let api = ApiClienteEmMemoria()
        let contaAntes = try await api.minhaConta()
        let emailAntes = contaAntes.email
        #expect(!emailAntes.isEmpty)

        // 4. Fluxo de saída/exclusão integrando API, limpeza de dados locais e Keychain
        let saida = SaidaDaConta(
            api: api,
            armazenamento: local,
            limparDestino: {
                if let defs = UserDefaults(suiteName: suiteName) {
                    DestinoGuardado.limpar(em: defs)
                }
            }
        )

        let viewModel = ExclusaoDeContaViewModel(
            executarExclusao: {
                let resultado = try await saida.excluir()
                // Como no SupabaseApiCliente real via signOut: o item de sessão é removido do storage Keychain
                try keychain.remove(key: chaveToken)
                return resultado
            }
        )
        viewModel.confirmouConsequencias = true
        await viewModel.confirmarExclusao()
        #expect(viewModel.exclusaoConcluida)

        // 5. Verificações de limpeza completa: Keychain e cache vazios
        #expect(try keychain.retrieve(key: chaveToken) == nil, "Sessão no Keychain deve ser removida após exclusão")
        #expect(try await local.sessao() == nil, "Sessão no cache SwiftData deve ser removida")
        #expect(try await local.turnosValidos(em: instante).isEmpty, "Turnos em cache devem ser limpos")
        #expect(try await local.funcoes().isEmpty, "Funções em cache devem ser limpas")
        #expect(try await local.pendentes().isEmpty, "Fila de ações pendentes deve ser limpa")
        #expect(DestinoGuardado.obter(de: defaults) == nil, "Destino guardado deve ser limpo")
        #expect(await !api.possuiSessao(), "Sessão da API deve estar inativa")

        // 6. Confirma que a conta foi excluída no servidor (404 / nao_encontrado)
        do {
            _ = try await api.minhaConta()
            Issue.record("Deveria ter lançado nao_encontrado para conta excluída")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .naoEncontrado)
        }

        // 7. Recadastro com o mesmo e-mail inicia cadastro do zero
        try await api.verificarCodigo(email: emailAntes, codigo: "123456")
        #expect(await api.possuiSessao())

        let destino = try await DestinoDaConta.avaliar(api: api)
        if case .cadastro = destino {
            // Sucesso: direcionado para novo cadastro do zero com mesmo e-mail
        } else {
            Issue.record("Deveria ter direcionado para cadastro com o mesmo e-mail, mas retornou \(destino)")
        }

        // 8. O novo cadastro pode gravar nova sessão no Keychain limpo
        let novoToken = Data("sessao-supabase-nova-conta-recadastro".utf8)
        try keychain.store(key: chaveToken, value: novoToken)
        #expect(try keychain.retrieve(key: chaveToken) == novoToken)
    }

    @Test("Falha na exclusão (ex: administrador_unico) preserva Keychain e cache (#ABN4rvmT)")
    func falhaNaExclusaoPreservaKeychainECache() async throws {
        let servico = "com.frila.org.app.teste.exclusao.\(UUID().uuidString)"
        let keychain = SessaoNoKeychainDoAparelho(servico: servico)
        let chaveToken = "supabase.auth.token"
        defer { try? keychain.remove(key: chaveToken) }

        let tokenOriginal = Data("sessao-ativa-nao-pode-sumir".utf8)
        try keychain.store(key: chaveToken, value: tokenOriginal)

        let (defaults, suiteName) = criarUserDefaultsIsolado()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let local = try criarArmazenamentoLocal()
        let instante = Date(timeIntervalSince1970: 1_800_000_000)
        _ = try await popularDadosLocais(no: local, instante: instante, defaults: defaults)

        let api = ApiClienteEmMemoria()
        await api.configurarCenarioExclusao(.administradorUnico)

        let saida = SaidaDaConta(
            api: api,
            armazenamento: local,
            limparDestino: {
                if let defs = UserDefaults(suiteName: suiteName) {
                    DestinoGuardado.limpar(em: defs)
                }
            }
        )

        let viewModel = ExclusaoDeContaViewModel(
            executarExclusao: {
                let resultado = try await saida.excluir()
                try keychain.remove(key: chaveToken)
                return resultado
            }
        )
        viewModel.confirmouConsequencias = true
        await viewModel.confirmarExclusao()

        #expect(!viewModel.exclusaoConcluida)
        #expect(viewModel.mensagemErro != nil)

        // Com falha, nada deve ser limpo: Keychain e cache permanecem intactos
        #expect(try keychain.retrieve(key: chaveToken) == tokenOriginal, "Keychain não deve ser limpo se a exclusão falhar")
        #expect(try await local.sessao() != nil, "Sessão no cache deve ser preservada")
        #expect(try await !local.turnosValidos(em: instante).isEmpty, "Turnos em cache devem ser preservados")
        #expect(try await !local.pendentes().isEmpty, "Fila de pendentes deve ser preservada")
        #expect(DestinoGuardado.obter(de: defaults) == .profissional, "Destino guardado deve ser preservado")
    }
}
