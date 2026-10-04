import Foundation
import FrilaDominio

/// Dublê do contrato para previews, testes de UI e o esquema Frila-Local. Parte das fixtures do
/// contrato e guarda o que o app faz durante a sessão. Simula uma conta só: não cobra RN25 fora
/// dos cadastros de perfil, porque o fluxo de ponta a ponta atravessa os dois perfis.
public actor ApiClienteEmMemoria: ApiCliente {
    public enum Cenario: String, CaseIterable, Sendable {
        case sucesso = "success"
        case primeiroAcesso = "primeiro-acesso"
        case vagaPreenchida = "vaga-preenchida"
        case inelegivel
        case funcaoIncompativel = "funcao-incompativel"
        case semRede = "sem-rede"
        case contaSuspensa = "conta-suspensa"
        /// Só a lista de vagas falha, com `422 campo_invalido/limite`, um erro que `vagas_abertas` produz no
        /// backend e que não é falta de rede nem de ponto de referência (estado de erro do #104).
        case erroNaLista = "erro-na-lista"
        /// `candidatar` responde `409 vaga_encerrada` (vaga cancelada, encerrada ou já iniciada).
        case vagaEncerrada = "vaga-encerrada"
        /// `candidatar` responde `422 inelegivel/perfil_suspenso` (conta suspensa, #105).
        case inelegivelSuspenso = "inelegivel-suspenso"
        case codigoErrado = "codigo-errado"
        case codigoExpirado = "codigo-expirado"
        case menorDeIdade = "menor-de-idade"
        case contaExistente = "conta-existente"
        case semPerfilProfissional = "sem-perfil-profissional"
        /// Conta sem perfil: o primeiro envio falha sem rede, e a repetição cria o perfil.
        case erroCriacaoPerfilProfissional = "erro-criacao-perfil-profissional"
        case entrada = "entrada"
        case contratante = "contratante"
        /// Conta de contratante que ainda não cadastrou o estabelecimento: o fluxo começa no cadastro.
        case contratanteSemEstabelecimento = "contratante-sem-estabelecimento"
        case perfilProfissionalComErroDeRede = "perfil-profissional-com-erro-de-rede"
        /// A vaga foi criada, mas a primeira resposta se perdeu. A repetição precisa reutilizar a chave.
        case respostaPerdidaPublicacao = "resposta-perdida-publicacao"
        /// A vaga foi criada, mas o gateway devolve uma resposta inválida na primeira tentativa.
        case respostaInvalidaPublicacao = "resposta-invalida-publicacao"
        /// Painel com uma vaga vazia dentro da janela de alerta do contratante.
        case alertaVagaVazia = "alerta-vaga-vazia"
        /// Painel com uma posição confirmada para testar perfil público e contato liberado.
        case painelContratante = "painel-contratante"
        /// Painel sem vagas para conferir a orientação do primeiro acesso do contratante.
        case painelVazio = "painel-vazio"
        /// Conta de contratante com um turno em andamento cujo check-in manual espera a confirmação (#19).
        case checkinManualPendente = "checkin-manual-pendente"
        /// Conta de contratante com um turno que começou há 20 minutos e ainda não teve check-in (#19).
        case atrasoNoTurno = "atraso-no-turno"
        /// Configuração remota exige versão mínima superior à atual.
        case atualizacaoObrigatoria = "atualizacao-obrigatoria"
        /// Painel com uma vaga encerrada para testar o fluxo de republicação (#147).
        case vagaEncerradaContratante = "vaga-encerrada-contratante"
        /// Turno encerrado e verificado para avaliação de turno no fluxo natural (#22).
        case turnoEncerrado = "turno-encerrado"
        /// A lista funciona, mas avaliar falha sem rede para exercitar a fila real.
        case avaliacaoSemRede = "avaliacao-sem-rede"
        case turnoEncerradoVerificado = "turno-encerrado-verificado"
        case turnoCancelado = "turno-cancelado"
        case turnoCanceladoComFalta = "turno-cancelado-com-falta"
        case turnoCanceladoSemDetalhes = "turno-cancelado-sem-detalhes"
        case turnoCanceladoOutro = "turno-cancelado-outro"
        case turnoAvaliado = "turno-avaliado"
        /// Conta de contratante com uma vaga de seleção de uma posição e quatro candidatos pendentes (#10).
        case selecaoComCandidatos = "selecao-com-candidatos"
        /// Como `selecaoComCandidatos`, mas outro membro da casa ocupa a última posição antes: a
        /// primeira escolha responde `409 posicao_ja_preenchida`, e a releitura mostra quem ficou (RN19).
        case escolhaPerdeCorrida = "escolha-perde-corrida"
        /// Conta de contratante com a vaga de seleção que fechou sozinha 24 h antes do início, sem
        /// escolha: vaga `encerrada`, posição `cancelada` e candidaturas `expirada` (RN24).
        case selecaoEncerradaSemEscolha = "selecao-encerrada-sem-escolha"
        /// Conta de profissional, e a vaga da lista é de seleção: candidatar-se deixa a candidatura pendente.
        case vagaEmSelecao = "vaga-em-selecao"
        /// Conta de profissional que já tem candidatura pendente na vaga de seleção da lista.
        case candidaturaPendente = "candidatura-pendente"
        /// Como `candidaturaPendente`, mas a retirada não sai do aparelho: `retirar_candidatura` é sem rede.
        case retirarSemRede = "retirar-sem-rede"
        /// Conta de profissional que a casa escolheu na vaga de seleção: candidatura `aceita`, vaga
        /// `preenchida` e o turno em Meus turnos, com o contato da casa (critério 1 do #10).
        case candidaturaEscolhida = "candidatura-escolhida"
        /// Conta de profissional cuja candidatura foi aceita na vaga de seleção, mas o turno foi cancelado (#10).
        case candidaturaComTurnoCancelado = "candidatura-com-turno-cancelado"
        /// Conta de profissional que não foi escolhida: a casa encheu a vaga com outra pessoa, e a
        /// candidatura ficou `recusada`, sem turno (critério 1 do #10).
        case candidaturaRecusada = "candidatura-recusada"
        /// Conta de profissional cuja candidatura esperava quando a seleção fechou sozinha, 24 h
        /// antes do início: candidatura `expirada` e vaga `encerrada` (critério 2 do #10).
        case candidaturaExpirada = "candidatura-expirada"
        /// As duas exportações, a dos dados (#219) e a dos turnos (#23), falham sem rede.
        case exportarSemRede = "exportar-sem-rede"
        /// As duas exportações falham com erro do servidor.
        case exportarErroServidor = "exportar-erro-servidor"
        /// `/exportar-turnos` responde 204: o período não tem turnos (UC13, 1a).
        case exportarTurnosSemTurnos = "exportar-turnos-sem-turnos"
        /// Painel com check-in já confirmado (contrato 0.2.31).
        case checkinConfirmado = "checkin-confirmado"
        /// Painel com posição cancelada com motivo informado (contrato 0.2.31).
        case posicaoCanceladaComMotivo = "posicao-cancelada-com-motivo"
        /// Servidor anterior à 0.2.31: não manda os quatro campos opcionais do painel.
        case servidorAntigo = "servidor-antigo"
        /// Conta de profissional com um turno confirmado que começa em 10 h: cancelar conta como falta (#20, RN12).
        case turnoConfirmadoPerto = "turno-confirmado-perto"
        /// Como `turnoConfirmadoPerto`, mas o turno começa em 48 h: cancelar não afeta a taxa.
        case turnoConfirmadoLonge = "turno-confirmado-longe"
        /// Como `turnoConfirmadoLonge`, mas `cancelar_posicao` é sem rede: o cancelamento vai para a fila.
        case cancelarSemRede = "cancelar-sem-rede"
        /// Servidor de hoje no lado do profissional: turnos sem estado, avaliacao e cancelamento; candidaturas sem turno_id.
        case profissionalServidorAntigo = "profissional-servidor-antigo"
        #if DEBUG
        /// Painel com um turno encerrado e presença verificada para o ciclo de ponta a ponta (#64).
        case cicloContratanteTurnoConcluido = "ciclo-contratante-turno-concluido"
        #endif

        public var isServidorAntigo: Bool {
            self == .servidorAntigo || self == .profissionalServidorAntigo
        }

        /// Os cenários do modo seleção em que a conta é de quem contrata.
        var selecaoDoContratante: Bool {
            self == .selecaoComCandidatos || self == .escolhaPerdeCorrida || self == .selecaoEncerradaSemEscolha
        }

        /// Os cenários do modo seleção em que a conta é de profissional e já tem candidatura na vaga,
        /// com o estado em que ela começa.
        var candidaturaDaConta: EstadoCandidatura? {
            switch self {
            case .candidaturaPendente, .retirarSemRede: .pendente
            case .candidaturaEscolhida, .candidaturaComTurnoCancelado, .profissionalServidorAntigo: .aceita
            case .candidaturaRecusada: .recusada
            case .candidaturaExpirada: .expirada
            default: nil
            }
        }

        var daSelecao: Bool { selecaoDoContratante || self == .vagaEmSelecao || candidaturaDaConta != nil }

        var deTurnoCancelado: Bool {
            self == .turnoCancelado || self == .turnoCanceladoComFalta || self == .turnoCanceladoSemDetalhes || self == .turnoCanceladoOutro
        }

        /// Os cenários do profissional com um turno confirmado ainda por vir (#20).
        var deTurnoConfirmado: Bool {
            self == .turnoConfirmadoPerto || self == .turnoConfirmadoLonge || self == .cancelarSemRede
        }
    }

    /// Uma candidatura como o backend a guarda: de quem é, em que vaga e em que estado.
    private struct CandidaturaGuardada {
        let id: UUID
        let vagaID: UUID
        /// Quem se candidatou, como a casa o vê em `candidatos_da_vaga`.
        let profissional: PerfilPublico
        /// Da conta do dublê, e não de um candidato simulado: só estas saem em `minhasCandidaturas`.
        let daConta: Bool
        var estado: EstadoCandidatura
        var criadaEm: Date
        var turnoID: UUID? = nil
    }

    private var avaliacoes: [UUID: Avaliacao] = [:]

    private let cenario: Cenario
    private let relogio: any Relogio
    private let envelopes: [String: EnvelopeErroAPI]
    private let catalogo: [Funcao]
    private let configuracao: ConfiguracaoApp
    private let contatoDeExemplo: Contato
    private let perfilPublicoDeExemplo: PerfilPublico
    private var sessaoAtiva = false
    private var conta: Conta?
    private var perfilProfissional: PerfilProfissional?
    private var tentativasCriacaoPerfil = 0
    private var estabelecimentos: [Estabelecimento]
    private var vagas: [Vaga]
    private var turnos: [Turno] = []
    private var contatos: [UUID: Contato] = [:]
    /// As candidaturas da conta e as dos candidatos simulados (contrato 0.2.24). No modo seleção,
    /// reenviar devolve a mesma pendente; no modo urgência, cada confirmação guarda uma `aceita`.
    private var candidaturas: [CandidaturaGuardada] = []
    /// Os candidatos de `candidatos.json`, que os cenários de seleção põem na vaga.
    private let candidatosDeExemplo: [Candidato]
    /// De quem é o turno que a casa confirmou por escolha, quando não é o da conta do dublê. Esses
    /// turnos servem ao painel e às operações da casa, e ficam fora de `meusTurnos`.
    private var profissionaisEscolhidos: [UUID: PerfilPublico] = [:]
    /// Posições que o fechamento das 24 h cancelou ainda abertas, por vaga (RN24).
    private var posicoesFechadas: [UUID: [UUID]] = [:]
    /// No cenário `escolhaPerdeCorrida`, a outra escolha só chega antes uma vez.
    private var corridaJaPerdida = false
    /// Quantas vezes `candidatar` foi chamado: os testes de toque duplo leem isso.
    public private(set) var chamadasACandidatar = 0
    public private(set) var chamadasAEscolherCandidato = 0
    public private(set) var chamadasARetirarCandidatura = 0
    public private(set) var chamadasAVerificarCodigo = 0
    public private(set) var chamadasACriarConta = 0
    public private(set) var chamadasAPublicarVaga = 0
    public private(set) var chamadasAExportarMeusDados = 0
    /// O que chegou a `exportarTurnos`, na ordem: os testes conferem o período, o formato e o estabelecimento.
    public private(set) var pedidosDeExportacaoDeTurnos: [PedidoExportacaoTurnos] = []
    public private(set) var chavesPublicacaoRecebidas: [UUID] = []
    public private(set) var publicacoesRecebidas: [PublicacaoVaga] = []
    public private(set) var vagasCriadas = 0
    private var publicacoesPorChave: [UUID: VagaPublicada] = [:]
    /// Registros de presença gravados por turno, como o backend guarda: repetir devolve o gravado.
    private var checkins: [UUID: ResultadoRegistro] = [:]
    private var checkouts: [UUID: ResultadoRegistro] = [:]
    /// Turnos cuja posição foi cancelada. Continuam em `meusTurnos`, como no backend, que não
    /// filtra pelo estado da posição, e no painel, como posição `cancelada`. A posição cancelada
    /// não volta a ficar aberta (RN12).
    private var turnosCancelados: [Turno] = []
    /// Posições novas que um cancelamento ou uma reabertura abriu, por vaga: o painel as mostra com
    /// o id que a chamada devolveu, e a próxima candidatura ocupa a primeira.
    private var posicoesReabertas: [UUID: [UUID]] = [:]
    /// Ids das posições abertas que nenhum cancelamento abriu, por vaga. O painel os mostra, e a
    /// candidatura ou a escolha ocupa um deles: como no backend, a posição confirmada é uma que o
    /// painel já mostrava como aberta, e o id não muda de uma leitura para a outra.
    private var posicoesAbertasDoPainel: [UUID: [UUID]] = [:]
    /// O que `reabrir_por_atraso` devolveu por posição: reenviar devolve o mesmo.
    private var reaberturasPorAtraso: [UUID: ResultadoCancelamento] = [:]
    /// Quando o contratante confirmou o check-in manual (contrato 0.2.31).
    private var confirmacoesDeCheckin: [UUID: Date] = [:]
    /// Detalhe do cancelamento por posição (contrato 0.2.31).
    private var cancelamentosPorPosicao: [UUID: CancelamentoDaPosicao] = [:]
    private var denunciasPorChave: [UUID: Protocolo] = [:]
    private var bloqueios: [Alvo: Bloqueio] = [:]
    /// Só no cenário `contaSuspensa`.
    private var suspensao: Suspensao?
    /// A conta dona de cada token de push, como a tabela `dispositivo`: um dono por token.
    private var dispositivos: [String: UUID] = [:]
    /// O `vinculo_id` de cada token (contrato 0.2.30): novo quando o token entra ou troca de dono,
    /// o mesmo no registro repetido pela mesma conta, e fora quando `remover_dispositivo` o tira.
    private var vinculos: [String: UUID] = [:]

    public init(
        cenario: Cenario = .sucesso,
        relogio: any Relogio = RelogioDoSistema(),
        vagas: [Vaga]? = nil,
        sessaoAtivaInicial: Bool = false
    ) {
        self.cenario = cenario
        self.relogio = relogio
        self.sessaoAtiva = sessaoAtivaInicial
        do {
            envelopes = try FixturesDoContrato.erros()
            catalogo = try FixturesDoContrato.carregar("funcoes", como: [ContratoAPI.FuncaoDTO].self).map { $0.dominio() }
            configuracao = try FixturesDoContrato.carregar("configuracao-do-app", como: ContratoAPI.ConfiguracaoDoAppDTO.self).dominio()
            contatoDeExemplo = try FixturesDoContrato.carregar("contato", como: ContratoAPI.ContatoDTO.self).dominio()
            perfilPublicoDeExemplo = try FixturesDoContrato.carregar("perfil-publico", como: ContratoAPI.PerfilPublicoDTO.self).dominio()
            candidatosDeExemplo = try FixturesDoContrato.carregar("candidatos", como: [ContratoAPI.CandidatoDTO].self).map { $0.dominio() }
            let usuario = try FixturesDoContrato.carregar("usuario", como: ContratoAPI.UsuarioDTO.self).dominio()
            #if DEBUG
            let ehCicloContratante = cenario == .cicloContratanteTurnoConcluido
            #else
            let ehCicloContratante = false
            #endif
            if cenario == .primeiroAcesso || cenario == .entrada || cenario == .menorDeIdade || cenario == .codigoErrado || cenario == .codigoExpirado {
                conta = nil
                perfilProfissional = nil
            } else {
                if cenario == .contratante || cenario == .checkinManualPendente || cenario == .atrasoNoTurno || cenario == .painelContratante || cenario == .painelVazio || cenario == .alertaVagaVazia || cenario == .contratanteSemEstabelecimento || cenario == .vagaEncerradaContratante || cenario == .checkinConfirmado || cenario == .posicaoCanceladaComMotivo || cenario == .servidorAntigo || cenario.selecaoDoContratante || ehCicloContratante {
                    conta = Conta(
                        id: usuario.id,
                        perfil: .contratante,
                        nome: usuario.nome,
                        telefone: usuario.telefone,
                        email: usuario.email,
                        nascimento: usuario.nascimento,
                        estado: usuario.estado
                    )
                    perfilProfissional = nil
                } else {
                    conta = usuario
                    if cenario == .semPerfilProfissional || cenario == .erroCriacaoPerfilProfissional {
                        perfilProfissional = nil
                    } else {
                        perfilProfissional = try FixturesDoContrato.carregar("perfil-profissional", como: ContratoAPI.PerfilProfissionalDTO.self).dominio()
                    }
                }
            }
            if cenario == .funcaoIncompativel, let perfil = perfilProfissional {
                perfilProfissional = PerfilProfissional(
                    id: perfil.id, usuarioID: perfil.usuarioID,
                    funcoes: catalogo.filter { $0.nome == "Bartender" }, pontoBase: perfil.pontoBase,
                    disponibilidades: perfil.disponibilidades, reputacao: perfil.reputacao
                )
            }
            if cenario == .contaSuspensa, let ativa = conta {
                conta = Conta(
                    id: ativa.id, perfil: ativa.perfil, nome: ativa.nome, telefone: ativa.telefone, email: ativa.email,
                    nascimento: ativa.nascimento, estado: .suspensa
                )
                suspensao = Suspensao(
                    motivo: "Denúncia grave confirmada pela Equipe Frila",
                    desde: relogio.agora.addingTimeInterval(-2 * 24 * 60 * 60), contestacao: nil
                )
            }
            estabelecimentos = (conta == nil || cenario == .contratanteSemEstabelecimento) ? [] : [try FixturesDoContrato.carregar("estabelecimento", como: ContratoAPI.EstabelecimentoDTO.self).dominio()]
            if let vagas {
                self.vagas = vagas
            } else {
                let vaga = try FixturesDoContrato.carregar("vaga", como: ContratoAPI.VagaDTO.self).dominio()
                let ateInicio: TimeInterval = switch cenario {
                case .alertaVagaVazia: 2 * 60 * 60
                case .checkinManualPendente, .checkinConfirmado, .servidorAntigo, .posicaoCanceladaComMotivo: -10 * 60
                case .atrasoNoTurno: -20 * 60
                case .vagaEncerradaContratante: -10 * 60 * 60
                // Os dois lados das 24 h da RN12: a 10 h o cancelamento do profissional é falta; a 48 h, não.
                // A meia hora a mais segura o "10 h"/"48 h" do aviso (horas para baixo) durante o teste.
                case .turnoConfirmadoPerto: 10 * 60 * 60 + 30 * 60
                case .turnoConfirmadoLonge, .cancelarSemRede: 48 * 60 * 60 + 30 * 60
                #if DEBUG
                case .cicloContratanteTurnoConcluido: -10 * 60 * 60
                #endif
                // A vaga de seleção exige mais de 24 h (RN24); a que fechou sozinha já está dentro delas.
                case .selecaoEncerradaSemEscolha, .candidaturaExpirada: 20 * 60 * 60
                case .selecaoComCandidatos, .escolhaPerdeCorrida, .vagaEmSelecao, .candidaturaPendente, .retirarSemRede,
                     .candidaturaEscolhida, .candidaturaRecusada: 72 * 60 * 60
                default: 24 * 60 * 60
                }
                let baseVaga = (cenario == .vagaEncerradaContratante || ehCicloContratante) ? Self.copia(vaga, estado: .encerrada) : vaga
                self.vagas = [try Self.noFuturo(baseVaga, agora: relogio.agora, inicioEm: ateInicio)]
            }
            if cenario == .painelVazio || cenario == .contratanteSemEstabelecimento { self.vagas = [] }
            if cenario == .painelContratante || cenario == .checkinManualPendente || cenario == .atrasoNoTurno
                || cenario == .checkinConfirmado || cenario == .posicaoCanceladaComMotivo || cenario == .servidorAntigo || ehCicloContratante,
                let vaga = self.vagas.first {
                let turnoID = UUID(uuidString: "82000000-0000-0000-0000-000000000001")!
                let posicaoID = UUID(uuidString: "82000000-0000-0000-0000-000000000002")!
                let contato = Contato(
                    nome: perfilPublicoDeExemplo.nome,
                    telefone: contatoDeExemplo.telefone,
                    whatsappURL: contatoDeExemplo.whatsappURL,
                    visivelAte: vaga.periodo.fim.addingTimeInterval(7 * 24 * 60 * 60)
                )
                let turnoExemplo = Turno(
                    id: turnoID, posicaoID: posicaoID, vaga: vaga.resumo,
                    contraparte: perfilPublicoDeExemplo, contatoVisivelAte: contato.visivelAte,
                    verificacao: (cenario == .painelContratante || cenario == .checkinConfirmado || ehCicloContratante || cenario == .servidorAntigo) ? .verificado : .pendente,
                    valorAcordado: vaga.valor, podeAvaliar: false
                )
                if cenario == .posicaoCanceladaComMotivo {
                    turnos = []
                    turnosCancelados = [turnoExemplo]
                    cancelamentosPorPosicao[posicaoID] = CancelamentoDaPosicao(
                        causa: .profissional,
                        falta: true,
                        motivo: "Imprevisto de saúde e não poderei comparecer.",
                        canceladaEm: relogio.agora.addingTimeInterval(-30 * 60)
                    )
                } else {
                    turnos = [turnoExemplo]
                    contatos[turnoID] = contato
                    if cenario == .checkinManualPendente {
                        checkins[turnoID] = ResultadoRegistro(
                            turnoID: turnoID, tipo: .manual, verificacao: .pendente,
                            registradoEm: vaga.periodo.inicio.addingTimeInterval(-2 * 60), distanciaMetros: nil
                        )
                    } else if cenario == .checkinConfirmado || ehCicloContratante {
                        checkins[turnoID] = ResultadoRegistro(
                            turnoID: turnoID, tipo: .manual, verificacao: .verificado,
                            registradoEm: vaga.periodo.inicio.addingTimeInterval(-5 * 60), distanciaMetros: nil
                        )
                        confirmacoesDeCheckin[turnoID] = vaga.periodo.inicio.addingTimeInterval(2 * 60)
                        if ehCicloContratante {
                            checkouts[turnoID] = ResultadoRegistro(
                                turnoID: turnoID, tipo: .manual, verificacao: .verificado,
                                registradoEm: vaga.periodo.fim, distanciaMetros: nil
                            )
                        }
                    }
                }
                self.vagas[0] = Self.comPosicoesAbertas(max(0, vaga.posicoesAbertas - 1), em: vaga)
            }
            if cenario.daSelecao, let vaga = self.vagas.first {
                // Uma posição só: a escolha de um candidato enche a vaga e libera os outros.
                let selecao = Self.copia(vaga, posicoes: 1, posicoesAbertas: 1, modo: .selecao)
                self.vagas[0] = selecao
                let agora = relogio.agora
                if cenario.selecaoDoContratante {
                    // Por ordem de chegada, como `candidatos_da_vaga` os devolve. Os valores saem para
                    // variáveis locais: o `init` do ator não pode deixar o `self` entrar no fechamento.
                    let exemplos = candidatosDeExemplo
                    let estado: EstadoCandidatura = cenario == .selecaoEncerradaSemEscolha ? .expirada : .pendente
                    candidaturas = exemplos.enumerated().map { indice, candidato in
                        CandidaturaGuardada(
                            id: candidato.candidaturaID, vagaID: selecao.id, profissional: candidato.profissional, daConta: false,
                            estado: estado, criadaEm: agora.addingTimeInterval(TimeInterval(indice - exemplos.count) * 60 * 60)
                        )
                    }
                }
                if cenario == .selecaoEncerradaSemEscolha {
                    posicoesFechadas[selecao.id] = [UUID(uuidString: "83000000-0000-0000-0000-000000000001")!]
                    self.vagas[0] = Self.copia(selecao, posicoesAbertas: 0, estado: .encerrada)
                }
                if let estado = cenario.candidaturaDaConta {
                    let pendente = try FixturesDoContrato.carregar("candidatura-selecao", como: ContratoAPI.CandidaturaDTO.self).dominio()
                    candidaturas = [CandidaturaGuardada(
                        id: pendente.candidaturaID, vagaID: selecao.id, profissional: perfilPublicoDeExemplo, daConta: true,
                        estado: estado, criadaEm: agora.addingTimeInterval(-60 * 60)
                    )]
                    switch estado {
                    case .aceita:
                        // O que `escolher_candidato` deixa para quem foi escolhido: o turno, com o
                        // contato da casa liberado (RN10), e a vaga cheia.
                        let turnoID = UUID(uuidString: "84000000-0000-0000-0000-000000000001")!
                        let visivelAte = selecao.periodo.fim.addingTimeInterval(7 * 24 * 60 * 60)
                        turnos = [Turno(
                            id: turnoID, posicaoID: UUID(uuidString: "84000000-0000-0000-0000-000000000002")!, vaga: selecao.resumo,
                            contraparte: selecao.estabelecimento, contatoVisivelAte: visivelAte,
                            verificacao: .pendente, valorAcordado: selecao.valor, podeAvaliar: false
                        )]
                        contatos[turnoID] = Contato(
                            nome: selecao.estabelecimento.nome, telefone: contatoDeExemplo.telefone,
                            whatsappURL: contatoDeExemplo.whatsappURL, visivelAte: visivelAte
                        )
                        self.vagas[0] = Self.copia(selecao, posicoesAbertas: 0, estado: .preenchida)
                        if cenario == .candidaturaComTurnoCancelado {
                            candidaturas[0].turnoID = turnoID
                            let cancelamento = CancelamentoDoTurno(causa: .estabelecimento, falta: false, canceladaEm: relogio.agora)
                            turnosCancelados = turnos.map { t in
                                Turno(
                                    id: t.id, posicaoID: t.posicaoID, vaga: t.vaga, contraparte: t.contraparte,
                                    contatoVisivelAte: t.contatoVisivelAte, checkin: t.checkin, checkout: t.checkout,
                                    verificacao: t.verificacao, valorAcordado: t.valorAcordado, podeAvaliar: false,
                                    estado: .cancelada, avaliacaoInformada: true, cancelamento: cancelamento
                                )
                            }
                            turnos = []
                            contatos = [:]
                        }
                    case .recusada:
                        self.vagas[0] = Self.copia(selecao, posicoesAbertas: 0, estado: .preenchida)
                    case .expirada:
                        self.vagas[0] = Self.copia(selecao, posicoesAbertas: 0, estado: .encerrada)
                    case .pendente, .retirada:
                        break
                    }
                }
            }
            if (cenario == .turnoEncerrado || cenario == .avaliacaoSemRede || cenario == .turnoEncerradoVerificado || cenario == .turnoAvaliado || cenario.deTurnoCancelado || cenario == .profissionalServidorAntigo), let vaga = self.vagas.first {
                let turnoID = UUID(uuidString: "22000000-0000-0000-0000-000000000001")!
                let posicaoID = UUID(uuidString: "22000000-0000-0000-0000-000000000002")!
                let duracao: TimeInterval = 6 * 3600
                let fim = relogio.agora.addingTimeInterval(-2 * 3600)
                let inicio = fim.addingTimeInterval(-duracao)
                let periodo = try Periodo(inicio: inicio, fim: fim)
                let vagaPassadaID = (cenario == .profissionalServidorAntigo) ? UUID(uuidString: "20000000-0000-0000-0000-000000000001")! : vaga.id
                let resumo = VagaResumo(
                    id: vagaPassadaID,
                    funcao: vaga.funcao.nome,
                    local: vaga.local,
                    regiaoAdministrativa: vaga.regiaoAdministrativa,
                    periodo: periodo,
                    valor: vaga.valor
                )
                let visivelAte = fim.addingTimeInterval(7 * 24 * 60 * 60)
                let contato = Contato(
                    nome: vaga.estabelecimento.nome,
                    telefone: contatoDeExemplo.telefone,
                    whatsappURL: contatoDeExemplo.whatsappURL,
                    visivelAte: visivelAte
                )
                let checkinPresenca = Presenca(
                    instante: inicio,
                    tipo: .geolocalizado,
                    distanciaMetros: 45,
                    confirmadaEm: inicio
                )
                let checkoutPresenca = Presenca(
                    instante: fim,
                    tipo: .geolocalizado,
                    distanciaMetros: 50,
                    confirmadaEm: nil
                )
                let turnoEncerrado = Turno(
                    id: turnoID,
                    posicaoID: posicaoID,
                    vaga: resumo,
                    contraparte: vaga.estabelecimento,
                    contatoVisivelAte: visivelAte,
                    aCaminhoEm: inicio.addingTimeInterval(-30 * 60),
                    checkin: checkinPresenca,
                    checkout: checkoutPresenca,
                    verificacao: .verificado,
                    valorAcordado: vaga.valor,
                    podeAvaliar: true,
                    contato: contato
                )
                if cenario == .profissionalServidorAntigo {
                    turnos.append(turnoEncerrado)
                } else {
                    turnos = [turnoEncerrado]
                }
                contatos[turnoID] = contato
                checkins[turnoID] = ResultadoRegistro(
                    turnoID: turnoID,
                    tipo: .geolocalizado,
                    verificacao: .verificado,
                    registradoEm: inicio,
                    distanciaMetros: 45
                )
                checkouts[turnoID] = ResultadoRegistro(
                    turnoID: turnoID,
                    tipo: .geolocalizado,
                    verificacao: .verificado,
                    registradoEm: fim,
                    distanciaMetros: 50
                )
            }
            if cenario.deTurnoCancelado {
                let causa: CausaDoCancelamento = cenario == .turnoCanceladoComFalta ? .reaberturaPorAtraso : (cenario == .turnoCanceladoOutro ? .outro : .profissional)
                let cancelamento: CancelamentoDoTurno? = cenario == .turnoCanceladoSemDetalhes ? nil :
                    CancelamentoDoTurno(causa: causa, falta: cenario == .turnoCanceladoComFalta, canceladaEm: relogio.agora)
                turnosCancelados = turnos.map { t in
                    Turno(id: t.id, posicaoID: t.posicaoID, vaga: t.vaga, contraparte: t.contraparte,
                          contatoVisivelAte: t.contatoVisivelAte, checkin: t.checkin, checkout: t.checkout,
                          verificacao: t.verificacao, valorAcordado: t.valorAcordado, podeAvaliar: false,
                          estado: .cancelada, avaliacaoInformada: true, cancelamento: cancelamento)
                }
                turnos = []
                contatos = [:]
            }
            if cenario == .turnoAvaliado, let turno = turnos.first {
                avaliacoes[turno.id] = Avaliacao(turnoID: turno.id, resposta: false, criadaEm: relogio.agora)
            }
            if cenario.deTurnoConfirmado, let vaga = self.vagas.first {
                // O turno que a candidatura confirmou, com o contato da casa liberado (RN10). A vaga
                // perde uma posição aberta, como no backend; o cancelamento devolve uma nova (RN12).
                let turnoID = UUID(uuidString: "23000000-0000-0000-0000-000000000001")!
                let posicaoID = UUID(uuidString: "23000000-0000-0000-0000-000000000002")!
                let contato = Contato(
                    nome: vaga.estabelecimento.nome, telefone: contatoDeExemplo.telefone,
                    whatsappURL: contatoDeExemplo.whatsappURL, visivelAte: vaga.periodo.fim.addingTimeInterval(7 * 24 * 60 * 60)
                )
                turnos = [Turno(
                    id: turnoID, posicaoID: posicaoID, vaga: vaga.resumo, contraparte: vaga.estabelecimento,
                    contatoVisivelAte: contato.visivelAte, verificacao: .pendente, valorAcordado: vaga.valor,
                    podeAvaliar: false, contato: contato
                )]
                contatos[turnoID] = contato
                self.vagas[0] = Self.comPosicoesAbertas(max(0, vaga.posicoesAbertas - 1), em: vaga)
            }
        } catch {
            preconditionFailure("Fixture do contrato ilegível: \(error)")
        }
    }

    #if DEBUG
    /// Só em Debug (#96): o Release não lê argumentos de lançamento.
    public static func pelosArgumentos(_ argumentos: [String] = ProcessInfo.processInfo.arguments) -> ApiClienteEmMemoria {
        let semSessaoArgumento = argumentos.contains("-FRILA_ABRIR_CATALOGO") || argumentos.contains("-FRILA_ENTRADA")
        guard let indice = argumentos.firstIndex(of: "-FRILA_SCENARIO"), argumentos.indices.contains(indice + 1),
              let cenario = Cenario(rawValue: argumentos[indice + 1]) else {
            return ApiClienteEmMemoria(sessaoAtivaInicial: !semSessaoArgumento)
        }
        let cenariosSemSessao: Set<Cenario> = [.primeiroAcesso, .entrada, .menorDeIdade, .codigoErrado, .codigoExpirado]
        let sessaoAtiva = !semSessaoArgumento && !cenariosSemSessao.contains(cenario)
        if cenario == .semRede {
            DestinoGuardado.salvar(.profissional)
        } else if !sessaoAtiva {
            DestinoGuardado.limpar()
        }
        return ApiClienteEmMemoria(cenario: cenario, sessaoAtivaInicial: sessaoAtiva)
    }
    #endif

    // MARK: Entrada

    public func solicitarCodigo(email: String) async throws { try verificarRede() }

    public func verificarCodigo(email: String, codigo: String) async throws {
        chamadasAVerificarCodigo += 1
        await Task.yield()
        try verificarRede()
        if cenario == .codigoErrado || codigo == "000000" {
            throw ErroDaApi(codigo: .naoAutenticado, codigoOriginal: "codigo_invalido")
        }
        if cenario == .codigoExpirado || codigo == "999999" {
            throw ErroDaApi(codigo: .naoAutenticado, codigoOriginal: "otp_expired")
        }
        sessaoAtiva = true
    }

    public func possuiSessao() async -> Bool { sessaoAtiva }

    public func entrarDemonstracao(email: String, codigo: String) async throws {
        try verificarRede()
        guard !codigo.isEmpty else { throw erro("nao_encontrado") }
        if cenario == .codigoErrado || codigo == "000000" {
            throw erro("nao_encontrado")
        }
        if cenario == .codigoExpirado || codigo == "999999" {
            throw erro("nao_encontrado")
        }
        sessaoAtiva = true
    }

    // MARK: Conta e perfil

    public func minhaConta() async throws -> Conta {
        try verificarRede()
        guard let conta else { throw erro("nao_encontrado") }
        return conta
    }

    public func criarConta(_ cadastro: CadastroConta) async throws -> Conta {
        chamadasACriarConta += 1
        await Task.yield()
        try verificarRede()
        guard conta == nil && cenario != .contaExistente else { throw erro("conta_existente") }
        if cenario == .menorDeIdade {
            throw erro("menor_de_idade")
        }
        if let hoje = DataCivil.deSaoPaulo(relogio.agora),
           let aniversario18 = try? DataCivil(ano: cadastro.nascimento.ano + 18, mes: cadastro.nascimento.mes, dia: cadastro.nascimento.dia),
           aniversario18 > hoje {
            throw erro("menor_de_idade")
        }
        let nova = Conta(
            id: UUID(), perfil: cadastro.perfil, nome: cadastro.nome, telefone: cadastro.telefone,
            email: "voce@frila.app", nascimento: cadastro.nascimento, estado: .ativa
        )
        conta = nova
        return nova
    }

    public func criarPerfilProfissional(_ dados: DadosPerfilProfissional) async throws -> PerfilProfissional {
        tentativasCriacaoPerfil += 1
        if cenario == .erroCriacaoPerfilProfissional, tentativasCriacaoPerfil == 1 {
            throw ErroDaApi(codigo: .semRede)
        }
        try verificarFalhaGeral()
        let conta = try await minhaConta()
        guard conta.perfil == .profissional else { throw erro("perfil_incompativel") }
        guard perfilProfissional?.usuarioID != conta.id else { throw erro("perfil_ja_existe") }
        let perfil = PerfilProfissional(
            id: UUID(), usuarioID: conta.id, funcoes: try doCatalogo(dados.funcoes), pontoBase: dados.pontoBase,
            disponibilidades: dados.disponibilidades,
            reputacao: Reputacao(positivas: 0, total: 0, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0)
        )
        perfilProfissional = perfil
        return perfil
    }

    public func meuPerfilProfissional() async throws -> PerfilProfissional {
        try verificarRede()
        if cenario == .perfilProfissionalComErroDeRede {
            throw ErroDaApi(codigo: .semRede)
        }
        guard let perfilProfissional else { throw erro("nao_encontrado") }
        return perfilProfissional
    }

    public func atualizarPerfilProfissional(_ alteracao: AlteracaoPerfilProfissional) async throws -> PerfilProfissional {
        try verificarFalhaGeral()
        let atual = try await meuPerfilProfissional()
        let perfil = PerfilProfissional(
            id: atual.id, usuarioID: atual.usuarioID,
            funcoes: try alteracao.funcoes.map(doCatalogo) ?? atual.funcoes,
            pontoBase: alteracao.pontoBase ?? atual.pontoBase,
            disponibilidades: alteracao.disponibilidades ?? atual.disponibilidades,
            reputacao: atual.reputacao
        )
        perfilProfissional = perfil
        return perfil
    }

    // MARK: Estabelecimento

    public func cadastrarEstabelecimento(_ cadastro: CadastroEstabelecimento) async throws -> Estabelecimento {
        try verificarFalhaGeral()
        if let conta, conta.perfil == .profissional { throw erro("perfil_incompativel") }
        // Obrigatória desde o contrato 0.2.20; em branco é ausência, como no backend.
        let regiao = cadastro.regiaoAdministrativa.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !regiao.isEmpty else { throw erro("campo_obrigatorio", detalhes: "regiao_administrativa") }
        guard !estabelecimentos.contains(where: { $0.documento == cadastro.documento }) else { throw erro("documento_ja_cadastrado") }
        let novo = Estabelecimento(
            id: UUID(), nome: cadastro.nome, documento: cadastro.documento, tipo: cadastro.tipo,
            endereco: cadastro.endereco, regiaoAdministrativa: regiao, ponto: cadastro.ponto, papel: .administrador
        )
        estabelecimentos.append(novo)
        return novo
    }

    public func meusEstabelecimentos() async throws -> [EstabelecimentoDaConta] {
        try verificarFalhaGeral()
        return estabelecimentos.map { EstabelecimentoDaConta(id: $0.id, nome: $0.nome, papel: $0.papel, tipo: $0.tipo, reputacao: perfilDo($0).reputacao) }
    }

    public func painelEstabelecimento(id: UUID, periodo: Periodo) async throws -> Painel {
        try verificarFalhaGeral()
        guard estabelecimentos.contains(where: { $0.id == id }) else { throw erro("sem_permissao") }
        let agora = relogio.agora
        let daCasa = vagas.filter { $0.estabelecimento.id == id && $0.periodo.sobrepoe(periodo) }
        return Painel(
            estabelecimentoID: id,
            vagas: daCasa.map { vaga in
                // `em_atraso` do backend: confirmada, sem check-in, dos 15 minutos do início até o fim (D06).
                let atrasada = agora >= vaga.periodo.inicio.addingTimeInterval(Self.toleranciaDeAtraso) && agora < vaga.periodo.fim
                let confirmadas = turnos.filter { $0.vaga.id == vaga.id }.map { turno in
                    let registro = checkins[turno.id]
                    let checkinEm: Date?
                    let checkinTipo: TipoRegistro?
                    let checkinConfirmadoEm: Date?
                    if cenario == .servidorAntigo {
                        checkinEm = nil
                        checkinTipo = nil
                        checkinConfirmadoEm = nil
                    } else {
                        checkinEm = registro?.registradoEm ?? turno.checkin?.instante
                        checkinTipo = registro?.tipo ?? turno.checkin?.tipo
                        checkinConfirmadoEm = confirmacoesDeCheckin[turno.id] ?? turno.checkin?.confirmadaEm
                    }
                    return PosicaoNoPainel(
                        id: turno.posicaoID, estado: .confirmada, profissional: profissionalDo(turno), turnoID: turno.id,
                        verificacao: registro?.verificacao ?? turno.verificacao,
                        emAtraso: atrasada && registro == nil && turno.checkin == nil, aCaminhoEm: turno.aCaminhoEm,
                        checkinEm: checkinEm, checkinTipo: checkinTipo, checkinConfirmadoEm: checkinConfirmadoEm,
                        cancelamento: nil
                    )
                }
                let canceladas = turnosCancelados.filter { $0.vaga.id == vaga.id }.map { turno in
                    let registro = checkins[turno.id]
                    let checkinEm: Date?
                    let checkinTipo: TipoRegistro?
                    let checkinConfirmadoEm: Date?
                    let cancelamento: CancelamentoDaPosicao?
                    if cenario == .servidorAntigo {
                        checkinEm = nil
                        checkinTipo = nil
                        checkinConfirmadoEm = nil
                        cancelamento = nil
                    } else {
                        checkinEm = registro?.registradoEm ?? turno.checkin?.instante
                        checkinTipo = registro?.tipo ?? turno.checkin?.tipo
                        checkinConfirmadoEm = confirmacoesDeCheckin[turno.id] ?? turno.checkin?.confirmadaEm
                        cancelamento = cancelamentosPorPosicao[turno.posicaoID]
                    }
                    return PosicaoNoPainel(
                        id: turno.posicaoID, estado: .cancelada, profissional: profissionalDo(turno), turnoID: turno.id,
                        verificacao: turno.verificacao, emAtraso: false, aCaminhoEm: turno.aCaminhoEm,
                        checkinEm: checkinEm, checkinTipo: checkinTipo, checkinConfirmadoEm: checkinConfirmadoEm,
                        cancelamento: cancelamento
                    )
                }
                // A posição que o fechamento das 24 h cancelou aberta não tem profissional nem turno (RN24).
                let fechadas = (posicoesFechadas[vaga.id] ?? []).map { id in
                    PosicaoNoPainel(id: id, estado: .cancelada, profissional: nil, turnoID: nil, verificacao: nil, emAtraso: false)
                }
                let abertas = idsDasPosicoesAbertas(vaga).map { id in
                    PosicaoNoPainel(id: id, estado: .aberta, profissional: nil, turnoID: nil, verificacao: nil, emAtraso: false)
                }
                // `alerta_vaga_vazia` do backend: vaga publicada, com posição aberta, dentro da janela
                // crítica e antes do início. A janela do dublê é a padrão, de 3 horas.
                let vazia = vaga.estado == .publicada && vaga.posicoesAbertas > 0 && agora < vaga.periodo.inicio
                    && vaga.periodo.inicio.timeIntervalSince(agora) <= 3 * 60 * 60
                return VagaNoPainel(
                    vaga: vaga.resumo, modo: vaga.modo, estado: vaga.estado, oculta: vaga.oculta, alertaVagaVazia: vazia,
                    // Como `candidatos_pendentes` do backend: o candidato que a casa bloqueou não entra
                    // na conta, embora `candidatos_da_vaga` continue a listá-lo.
                    candidatosPendentes: candidaturas.count {
                        $0.vagaID == vaga.id && $0.estado == .pendente && bloqueios[Alvo($0.profissional)] == nil
                    },
                    posicoes: confirmadas + canceladas + fechadas + abertas
                )
            },
            // Check-in manual que ninguém da casa confirmou ainda, do mais antigo para o mais novo.
            checkinsPendentes: turnos
                .filter { turno in daCasa.contains { $0.id == turno.vaga.id } }
                .compactMap { checkins[$0.id] }
                .filter { $0.tipo == .manual && $0.verificacao == .pendente }
                .sorted { $0.registradoEm < $1.registradoEm }
                .map(\.turnoID)
        )
    }

    // MARK: Catálogo e vagas

    public func funcoes() async throws -> [Funcao] {
        try verificarFalhaGeral()
        return catalogo
    }

    public func publicarVaga(_ publicacao: PublicacaoVaga) async throws -> VagaPublicada {
        chamadasAPublicarVaga += 1
        chavesPublicacaoRecebidas.append(publicacao.chave)
        publicacoesRecebidas.append(publicacao)
        if let resposta = publicacoesPorChave[publicacao.chave] { return resposta }
        try verificarFalhaGeral()
        guard let estabelecimento = estabelecimentos.first(where: { $0.id == publicacao.estabelecimentoID }) else { throw erro("sem_permissao") }
        let regiao = publicacao.regiaoAdministrativa.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !regiao.isEmpty else { throw erro("campo_obrigatorio", detalhes: "regiao_administrativa") }
        guard let funcao = catalogo.first(where: { $0.id == publicacao.funcaoID }) else { throw erro("campo_invalido", detalhes: "funcao_id") }
        // RN24, contrato 0.2.24: o modo seleção fecha 24 h antes do início; com 24 h ou menos, a vaga nem entra.
        if publicacao.modo == .selecao, publicacao.periodo.inicio <= relogio.agora.addingTimeInterval(Self.antecedenciaDaSelecao) {
            throw erro("selecao_sem_antecedencia")
        }
        let vaga = Vaga(
            id: UUID(), estabelecimento: perfilDo(estabelecimento), funcao: funcao, periodo: publicacao.periodo,
            local: publicacao.local, regiaoAdministrativa: regiao, ponto: publicacao.ponto, valor: publicacao.valor, posicoes: publicacao.posicoes,
            posicoesAbertas: publicacao.posicoes, inclusos: publicacao.inclusos, responsavelLocal: publicacao.responsavelLocal,
            traje: publicacao.traje, participaRateio: publicacao.participaRateio, observacoes: publicacao.observacoes,
            modo: publicacao.modo, estado: .publicada, publicadoEm: relogio.agora
        )
        vagas.append(vaga)
        vagasCriadas += 1
        let resposta = VagaPublicada(vagaID: vaga.id, posicoes: (0..<publicacao.posicoes).map { _ in UUID() })
        publicacoesPorChave[publicacao.chave] = resposta
        if cenario == .respostaPerdidaPublicacao { throw ErroDaApi(codigo: .semRede) }
        if cenario == .respostaInvalidaPublicacao { throw ErroDaApi(codigo: .respostaInvalida) }
        return resposta
    }

    public func republicarVaga(id: UUID, periodo: Periodo, chave: UUID) async throws -> VagaPublicada {
        guard let original = vagas.first(where: { $0.id == id }) else { throw erro("nao_encontrado") }
        // Contrato 0.2.23: republicar não contorna a moderação.
        guard !original.oculta else { throw erro("vaga_oculta") }
        return try await publicarVaga(
            PublicacaoVaga(
                estabelecimentoID: original.estabelecimento.id, funcaoID: original.funcao.id, periodo: periodo,
                local: original.local, regiaoAdministrativa: original.regiaoAdministrativa, ponto: original.ponto,
                valor: original.valor, posicoes: original.posicoes,
                inclusos: original.inclusos, responsavelLocal: original.responsavelLocal, traje: original.traje,
                participaRateio: original.participaRateio, observacoes: original.observacoes, modo: original.modo, chave: chave
            )
        )
    }

    public func vagasAbertas(_ filtro: FiltroVagas) async throws -> [VagaNaLista] {
        try verificarFalhaGeral()
        if cenario == .erroNaLista { throw erro("campo_invalido", detalhes: "limite") }

        let limite = filtro.limite ?? 30
        let deslocamento = filtro.deslocamento ?? 0
        if limite < 1 || limite > 100 {
            throw erro("campo_invalido", detalhes: "limite")
        }
        if deslocamento < 0 {
            throw erro("campo_invalido", detalhes: "deslocamento")
        }

        let referencia = filtro.referencia ?? perfilProfissional?.pontoBase
        let agora = relogio.agora
        let ordenadas = vagas
            .filter { vaga in
                // Fora da vitrine: a vaga ocultada pela moderação (contrato 0.2.23) e a que já começou (0.2.19).
                guard vaga.estado == .publicada, !vaga.oculta, vaga.periodo.inicio > agora else { return false }
                // RF26: as partes de um bloqueio não se cruzam em lista, detalhe nem candidatura.
                guard !bloqueada(vaga) else { return false }
                if let funcaoID = filtro.funcaoID, vaga.funcao.id != funcaoID { return false }
                if let data = filtro.data, DataCivil.deSaoPaulo(vaga.periodo.inicio) != data { return false }
                return true
            }
            .map { vaga in
                let distancia = referencia.map { vaga.ponto.distancia(emMetrosDe: $0) / 1_000 } ?? 0
                return VagaNaLista(
                    id: vaga.id, funcao: vaga.funcao, estabelecimento: vaga.estabelecimento, periodo: vaga.periodo,
                    local: vaga.local, regiaoAdministrativa: vaga.regiaoAdministrativa, distanciaKm: distancia,
                    valor: vaga.valor, posicoesAbertas: vaga.posicoesAbertas, inclusos: vaga.inclusos, modo: vaga.modo
                )
            }
            .filter { vaga in filtro.distanciaMaximaKm.map { vaga.distanciaKm <= $0 } ?? true }
            .sorted {
                if $0.distanciaKm != $1.distanciaKm {
                    return $0.distanciaKm < $1.distanciaKm
                }
                return $0.id.uuidString < $1.id.uuidString
            }

        let inicio = min(deslocamento, ordenadas.count)
        let fim = min(inicio + limite, ordenadas.count)
        return Array(ordenadas[inicio..<fim])
    }

    public func detalheDaVaga(id: UUID) async throws -> Vaga {
        try verificarFalhaGeral()
        guard let vaga = vagas.first(where: { $0.id == id }), !bloqueada(vaga) else { throw erro("nao_encontrado") }
        // Contrato 0.2.23: a vaga ocultada só abre, com `oculta: true`, para quem ocupa posição ou tem
        // candidatura nela; para os demais é o mesmo 404 da vaga escondida por bloqueio.
        if vaga.oculta, !turnos.contains(where: { $0.vaga.id == id }), candidaturaDaConta(na: id) == nil {
            throw erro("nao_encontrado")
        }
        // Contrato 0.2.19: depois do início o detalhe continua respondendo, com o estado real e sem
        // nada para pegar. Não vira 404, para o toque numa notificação antiga abrir a vaga.
        guard vaga.periodo.inicio > relogio.agora else { return Self.copia(vaga, posicoesAbertas: 0) }
        return vaga
    }

    public func candidatar(vagaID: UUID) async throws -> ResultadoCandidatura {
        chamadasACandidatar += 1
        try verificarFalhaGeral()
        if cenario == .vagaPreenchida { throw erro("posicao_ja_preenchida") }
        if cenario == .vagaEncerrada { throw erro("vaga_encerrada") }
        if cenario == .inelegivel { throw erro("inelegivel", detalhes: "turno_sobreposto") }
        if cenario == .inelegivelSuspenso {
            // A suspensão acontece após a entrada, ao tentar se candidatar.
            if let ativa = conta {
                conta = Conta(id: ativa.id, perfil: ativa.perfil, nome: ativa.nome, telefone: ativa.telefone,
                              email: ativa.email, nascimento: ativa.nascimento, estado: .suspensa)
                suspensao = suspensao ?? Suspensao(motivo: "Denúncia grave confirmada pela Equipe Frila",
                                                  desde: relogio.agora, contestacao: nil)
            }
            throw erro("inelegivel", detalhes: "perfil_suspenso")
        }
        guard let indice = vagas.firstIndex(where: { $0.id == vagaID }) else { throw erro("nao_encontrado") }
        let vaga = vagas[indice]
        if cenario == .funcaoIncompativel,
           perfilProfissional?.funcoes.contains(where: { $0.id == vaga.funcao.id }) != true {
            throw erro("inelegivel", detalhes: "funcao_incompativel")
        }
        // Quem a casa já escolheu recebe o próprio turno de volta, antes de qualquer conferência do
        // estado da vaga, como no backend. Só na seleção: no modo urgência o dublê não devolve o mesmo.
        if vaga.modo == .selecao, !bloqueada(vaga), let minha = candidaturaDaConta(na: vagaID), minha.estado == .aceita,
           let turno = turnos.first(where: { $0.vaga.id == vagaID && profissionaisEscolhidos[$0.id] == nil }) {
            return ResultadoCandidatura(
                estado: .confirmada, candidaturaID: minha.id, posicaoID: turno.posicaoID, turnoID: turno.id, contato: contatos[turno.id]
            )
        }
        // Contrato 0.2.23: candidatura nova em vaga ocultada responde 404, como a escondida por bloqueio.
        guard !vaga.oculta, !bloqueada(vaga) else { throw erro("nao_encontrado") }
        // A vaga cancelada não existe mais para quem chega: `vaga_encerrada`, e não "alguém chegou antes".
        guard vaga.estado != .cancelada, vaga.estado != .encerrada else { throw erro("vaga_encerrada") }
        // Chegar depois da última posição é o funcionamento normal do modo urgência (RN19).
        guard vaga.estado != .preenchida, vaga.posicoesAbertas > 0 else { throw erro("posicao_ja_preenchida") }
        guard vaga.estado == .publicada else { throw erro("vaga_encerrada") }
        // Contrato 0.2.19: início já passado é vaga encerrada. A exceção do backend, a posição
        // reaberta por atraso, que aceita candidatura até 1 h antes do fim, o dublê não modela.
        let agora = relogio.agora
        guard vaga.periodo.inicio > agora else { throw erro("vaga_encerrada") }
        // Contrato 0.2.24: na vaga de seleção a candidatura fica pendente, sem posição, turno nem
        // contato, e a vaga não aceita candidatura a partir de 24 h antes do início (RN24).
        if vaga.modo == .selecao {
            guard agora < vaga.periodo.inicio.addingTimeInterval(-Self.antecedenciaDaSelecao) else { throw erro("vaga_encerrada") }
            let candidaturaID: UUID
            if let minha = candidaturas.firstIndex(where: { $0.vagaID == vagaID && $0.daConta }) {
                // Reenviar devolve a mesma pendente, sem mexer nela; a retirada volta a valer, com a
                // hora de agora, e é o caminho para desfazer a retirada.
                if candidaturas[minha].estado != .pendente {
                    candidaturas[minha].estado = .pendente
                    candidaturas[minha].criadaEm = agora
                }
                candidaturaID = candidaturas[minha].id
            } else {
                candidaturaID = UUID()
                candidaturas.append(CandidaturaGuardada(
                    id: candidaturaID, vagaID: vagaID, profissional: perfilPublicoDeExemplo, daConta: true, estado: .pendente, criadaEm: agora
                ))
            }
            return ResultadoCandidatura(estado: .pendente, candidaturaID: candidaturaID, posicaoID: nil, turnoID: nil, contato: nil)
        }

        let visivelAte = vaga.periodo.fim.addingTimeInterval(7 * 24 * 60 * 60)
        let contato = Contato(nome: vaga.estabelecimento.nome, telefone: contatoDeExemplo.telefone, whatsappURL: contatoDeExemplo.whatsappURL, visivelAte: visivelAte)
        // A posição que um cancelamento reabriu é ocupada com o id que o painel já mostrava.
        let posicaoID = ocuparPosicaoAberta(vagaID)
        let turno = Turno(
            id: UUID(), posicaoID: posicaoID, vaga: vaga.resumo, contraparte: vaga.estabelecimento, contatoVisivelAte: visivelAte,
            verificacao: .pendente, valorAcordado: vaga.valor, podeAvaliar: false
        )
        turnos.append(turno)
        contatos[turno.id] = contato
        vagas[indice] = Self.comPosicoesAbertas(vaga.posicoesAbertas - 1, em: vaga)
        // No modo urgência a candidatura já nasce aceita, e é assim que `minhas_candidaturas` a lista.
        let candidaturaID = UUID()
        candidaturas.append(CandidaturaGuardada(
            id: candidaturaID, vagaID: vagaID, profissional: perfilPublicoDeExemplo, daConta: true, estado: .aceita, criadaEm: agora,
            turnoID: turno.id
        ))
        return ResultadoCandidatura(estado: .confirmada, candidaturaID: candidaturaID, posicaoID: turno.posicaoID, turnoID: turno.id, contato: contato)
    }

    public func perfilPublico(id: UUID) async throws -> PerfilPublico {
        try verificarFalhaGeral()
        guard !bloqueios.keys.contains(where: { $0.id == id }) else { throw erro("nao_encontrado") }
        if id == perfilPublicoDeExemplo.id { return perfilPublicoDeExemplo }
        if let candidato = candidaturas.first(where: { $0.profissional.id == id }) { return candidato.profissional }
        guard let perfil = vagas.map(\.estabelecimento).first(where: { $0.id == id }) else { throw erro("nao_encontrado") }
        return perfil
    }

    // MARK: Modo seleção

    /// Segue `candidatos_da_vaga` do backend (`20260929234100_modo_selecao.sql`): vaga que não existe
    /// é `404`; a de outra casa, `403 sem_permissao`; só os pendentes, por ordem de chegada, e nunca
    /// pela reputação (RN06). Continua respondendo na vaga ocultada, fechada ou cheia.
    public func candidatosDaVaga(id: UUID) async throws -> [Candidato] {
        try verificarFalhaGeral()
        guard let vaga = vagas.first(where: { $0.id == id }) else { throw erro("nao_encontrado") }
        guard estabelecimentos.contains(where: { $0.id == vaga.estabelecimento.id }) else { throw erro("sem_permissao") }
        return candidaturas
            .filter { $0.vagaID == id && $0.estado == .pendente }
            .sorted { $0.criadaEm != $1.criadaEm ? $0.criadaEm < $1.criadaEm : $0.id.uuidString < $1.id.uuidString }
            .map { Candidato(candidaturaID: $0.id, profissional: $0.profissional, criadaEm: $0.criadaEm) }
    }

    /// Segue `escolher_candidato` do backend (`20260929234100_modo_selecao.sql`), na ordem das recusas
    /// dele: candidatura que não existe ou de outra casa é `403 sem_permissao`; a já escolhida, `409
    /// candidatura_indisponivel`; vaga ocultada, `422 vaga_oculta`; vaga cheia, `409
    /// posicao_ja_preenchida`, antes do estado da candidatura, que é o que ouve quem perde a corrida
    /// (RN19); vaga fechada pelas 24 h, cancelada ou encerrada, `409 vaga_encerrada`; candidatura
    /// retirada, recusada ou expirada, `409 candidatura_indisponivel`. A última posição escolhida
    /// enche a vaga e recusa quem ainda esperava. Não é idempotente: escolher de novo é o 409 da já
    /// escolhida. O `422 inelegivel` (`turno_sobreposto`, `perfil_suspenso`) só sai no cenário
    /// `inelegivel` e no `inelegivelSuspenso`.
    public func escolherCandidato(candidaturaID: UUID) async throws -> ResultadoConfirmacao {
        chamadasAEscolherCandidato += 1
        try verificarFalhaGeral()
        guard let indice = candidaturas.firstIndex(where: { $0.id == candidaturaID }),
              let daVaga = vagas.firstIndex(where: { $0.id == candidaturas[indice].vagaID }),
              estabelecimentos.contains(where: { $0.id == vagas[daVaga].estabelecimento.id }) else { throw erro("sem_permissao") }
        if cenario == .escolhaPerdeCorrida, !corridaJaPerdida {
            // Outro membro da casa escolheu outro candidato um instante antes, e a escolha dele vale.
            corridaJaPerdida = true
            if let outra = candidaturas.firstIndex(where: {
                $0.vagaID == vagas[daVaga].id && $0.estado == .pendente && $0.id != candidaturaID
            }) {
                _ = confirmarEscolha(candidatura: outra, vaga: daVaga)
            }
        }
        let vaga = vagas[daVaga]
        let candidatura = candidaturas[indice]
        guard vaga.modo == .selecao, candidatura.estado != .aceita else { throw erro("candidatura_indisponivel") }
        guard !vaga.oculta else { throw erro("vaga_oculta") }
        guard vaga.estado != .preenchida else { throw erro("posicao_ja_preenchida") }
        guard vaga.estado == .publicada, relogio.agora < vaga.periodo.inicio.addingTimeInterval(-Self.antecedenciaDaSelecao) else {
            throw erro("vaga_encerrada")
        }
        guard candidatura.estado == .pendente else { throw erro("candidatura_indisponivel") }
        if cenario == .inelegivelSuspenso { throw erro("inelegivel", detalhes: "perfil_suspenso") }
        if cenario == .inelegivel { throw erro("inelegivel", detalhes: "turno_sobreposto") }
        guard vaga.posicoesAbertas > 0 else { throw erro("posicao_ja_preenchida") }
        return confirmarEscolha(candidatura: indice, vaga: daVaga)
    }

    /// Segue `retirar_candidatura` do backend (`20260929234100_modo_selecao.sql`): a que não é de
    /// quem chama é `404`; a pendente passa a `retirada`; retirar de novo devolve a mesma; escolhida,
    /// recusada ou expirada é `409 candidatura_indisponivel`.
    public func retirarCandidatura(id: UUID) async throws -> Candidatura {
        chamadasARetirarCandidatura += 1
        try verificarFalhaGeral()
        if cenario == .retirarSemRede { throw ErroDaApi(codigo: .semRede) }
        guard let indice = candidaturas.firstIndex(where: { $0.id == id && $0.daConta }),
              let vaga = vagas.first(where: { $0.id == candidaturas[indice].vagaID }) else { throw erro("nao_encontrado") }
        switch candidaturas[indice].estado {
        case .pendente: candidaturas[indice].estado = .retirada
        case .retirada: break
        case .aceita, .recusada, .expirada: throw erro("candidatura_indisponivel")
        }
        return self.candidatura(candidaturas[indice], em: vaga)
    }

    /// Segue `minhas_candidaturas` do backend (`20260929234100_modo_selecao.sql`): da mais nova para
    /// a mais antiga, com o filtro opcional de estado. Só as da conta do dublê, nunca as dos
    /// candidatos simulados.
    public func minhasCandidaturas(estado: EstadoCandidatura?) async throws -> [Candidatura] {
        try verificarFalhaGeral()
        return candidaturas
            .filter { $0.daConta && (estado == nil || $0.estado == estado) }
            .sorted { $0.criadaEm != $1.criadaEm ? $0.criadaEm > $1.criadaEm : $0.id.uuidString < $1.id.uuidString }
            .compactMap { guardada in vagas.first { $0.id == guardada.vagaID }.map { self.candidatura(guardada, em: $0) } }
    }

    // MARK: Turno

    /// Como `meus_turnos` na 0.2.31, mantém cancelados e devolve o voto deste lado.
    public func meusTurnos() async throws -> [Turno] {
        try verificarFalhaGeral()
        let agora = relogio.agora
        let lista = cenario.isServidorAntigo ? turnos : (turnos + turnosCancelados)
        return lista.filter { profissionaisEscolhidos[$0.id] == nil }.map { t in
            let fimPassou = t.vaga.periodo.fim <= agora
            let estado: EstadoPosicao = t.cancelado ? .cancelada : (fimPassou && t.checkin != nil ? .cumprida : .confirmada)
            let avaliacao = avaliacoes[t.id]
            let pode = estado != .cancelada && t.verificacao == .verificado && fimPassou && avaliacao == nil
            if cenario.isServidorAntigo {
                return Turno(
                    id: t.id, posicaoID: t.posicaoID, vaga: t.vaga, contraparte: t.contraparte,
                    contatoVisivelAte: t.contatoVisivelAte, aCaminhoEm: t.aCaminhoEm,
                    checkin: t.checkin, checkout: t.checkout, verificacao: t.verificacao,
                    valorAcordado: t.valorAcordado, podeAvaliar: pode, contato: t.contato,
                    estado: nil, avaliacao: nil, avaliacaoInformada: nil, cancelamento: nil,
                    avaliacaoLidaEm: nil
                )
            }
            return Turno(
                id: t.id, posicaoID: t.posicaoID, vaga: t.vaga, contraparte: t.contraparte,
                contatoVisivelAte: t.contatoVisivelAte, aCaminhoEm: t.aCaminhoEm,
                checkin: t.checkin, checkout: t.checkout, verificacao: t.verificacao,
                valorAcordado: t.valorAcordado, podeAvaliar: pode, contato: t.contato,
                estado: estado, avaliacao: avaliacao, avaliacaoInformada: true, cancelamento: t.cancelamento,
                avaliacaoLidaEm: Date()
            )
        }
    }

    public func contatoDoTurno(id: UUID) async throws -> Contato {
        try verificarFalhaGeral()
        guard let turno = turnos.first(where: { $0.id == id }), let contato = contatos[id] else { throw erro("nao_encontrado") }
        // Contrato 0.2.9: com bloqueio entre as partes, o contato responde 404.
        guard bloqueios[Alvo(turno.contraparte)] == nil else { throw erro("nao_encontrado") }
        guard turno.contatoVisivel(em: relogio.agora) else { throw erro("contato_expirado") }
        return contato
    }

    /// Segue `avisar_a_caminho` do backend (`20260930160000_avisar_a_caminho.sql`): o aviso já
    /// gravado volta como está, antes de conferir a janela; a janela vai de 3 h antes até 15 min
    /// depois do início, com as duas bordas dentro; turno que não é de quem chama é `403 sem_permissao`.
    public func avisarACaminho(turnoID: UUID) async throws -> ResultadoACaminho {
        try verificarFalhaGeral()
        guard let indice = turnos.firstIndex(where: { $0.id == turnoID }) else { throw erro("sem_permissao") }
        let turno = turnos[indice]
        if let gravado = turno.aCaminhoEm { return ResultadoACaminho(turnoID: turnoID, aCaminhoEm: gravado) }
        let agora = relogio.agora
        let inicio = turno.vaga.periodo.inicio
        guard agora >= inicio.addingTimeInterval(-3 * 60 * 60), agora <= inicio.addingTimeInterval(15 * 60) else {
            throw erro("a_caminho_fora_da_janela")
        }
        turnos[indice] = turno.com(aCaminhoEm: agora)
        return ResultadoACaminho(turnoID: turnoID, aCaminhoEm: agora)
    }

    /// Segue `fazer_checkin` do backend (definição vigente em
    /// `20260925233000_notificacao_para_qualquer_conta.sql`): repetir devolve o registro gravado;
    /// até 200 m é `geolocalizado` e `verificado`, acima disso ou sem distância é `manual` e
    /// `pendente`, e o manual não guarda a distância.
    public func fazerCheckin(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        try verificarFalhaGeral()
        if turnosCancelados.contains(where: { $0.id == turnoID }) {
            throw erro("vaga_encerrada", detalhes: "posicao_cancelada")
        }
        guard turnos.contains(where: { $0.id == turnoID }) else { throw erro("nao_encontrado") }
        if let gravado = checkins[turnoID] { return gravado }
        try validarRegistro(distanciaMetros: distanciaMetros, registradoEm: registradoEm)
        let perto = distanciaMetros.map { $0 <= 200 } ?? false
        let registro = ResultadoRegistro(
            turnoID: turnoID, tipo: perto ? .geolocalizado : .manual, verificacao: perto ? .verificado : .pendente,
            registradoEm: registradoEm, distanciaMetros: perto ? distanciaMetros : nil
        )
        checkins[turnoID] = registro
        atualizarTurnoAposPresenca(turnoID: turnoID)
        return registro
    }

    /// Segue `fazer_checkout` do backend (`20260925000000_checkin_e_checkout.sql`): sem check-in é
    /// `409 checkin_pendente`; a distância não tem teto e é gravada como veio; repetir devolve o
    /// registro gravado. Tipo e verificação vêm do check-in gravado no dublê, que o
    /// `confirmarCheckinManual` atualiza, como a verificação atual do turno no backend.
    public func fazerCheckout(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        try verificarFalhaGeral()
        if turnosCancelados.contains(where: { $0.id == turnoID }) {
            throw erro("vaga_encerrada", detalhes: "posicao_cancelada")
        }
        guard turnos.contains(where: { $0.id == turnoID }) else { throw erro("nao_encontrado") }
        if let gravado = checkouts[turnoID] { return gravado }
        guard let checkin = checkins[turnoID] else { throw erro("checkin_pendente") }
        try validarRegistro(distanciaMetros: distanciaMetros, registradoEm: registradoEm)
        let registro = ResultadoRegistro(
            turnoID: turnoID, tipo: checkin.tipo, verificacao: checkin.verificacao,
            registradoEm: registradoEm, distanciaMetros: distanciaMetros
        )
        checkouts[turnoID] = registro
        atualizarTurnoAposPresenca(turnoID: turnoID)
        return registro
    }

    private func atualizarTurnoAposPresenca(turnoID: UUID) {
        guard let indice = turnos.firstIndex(where: { $0.id == turnoID }) else { return }
        let t = turnos[indice]
        let presencaCheckin = checkins[turnoID].map { c in
            Presenca(
                instante: c.registradoEm,
                tipo: c.tipo,
                distanciaMetros: c.distanciaMetros,
                confirmadaEm: c.verificacao == .verificado ? c.registradoEm : nil
            )
        } ?? t.checkin
        let presencaCheckout = checkouts[turnoID].map { o in
            Presenca(
                instante: o.registradoEm,
                tipo: o.tipo,
                distanciaMetros: o.distanciaMetros,
                confirmadaEm: nil
            )
        } ?? t.checkout
        let novaVerificacao = checkins[turnoID]?.verificacao ?? t.verificacao
        let fimPassou = t.vaga.periodo.fim <= relogio.agora
        let podeAvaliar = novaVerificacao == .verificado && fimPassou
        turnos[indice] = Turno(
            id: t.id,
            posicaoID: t.posicaoID,
            vaga: t.vaga,
            contraparte: t.contraparte,
            contatoVisivelAte: t.contatoVisivelAte,
            aCaminhoEm: t.aCaminhoEm,
            checkin: presencaCheckin,
            checkout: presencaCheckout,
            verificacao: novaVerificacao,
            valorAcordado: t.valorAcordado,
            podeAvaliar: podeAvaliar,
            contato: t.contato,
            estado: t.estado, avaliacao: t.avaliacao, avaliacaoInformada: t.avaliacaoInformada,
            cancelamento: t.cancelamento
        )
    }

    public func avaliar(turnoID: UUID, resposta: Bool) async throws -> Avaliacao {
        try verificarFalhaGeral()
        if cenario == .avaliacaoSemRede { throw ErroDaApi(codigo: .semRede) }
        guard turnos.contains(where: { $0.id == turnoID }) else { throw erro("nao_encontrado") }
        guard avaliacoes[turnoID] == nil else { throw erro("avaliacao_ja_registrada") }
        let avaliacao = Avaliacao(turnoID: turnoID, resposta: resposta, criadaEm: relogio.agora)
        avaliacoes[turnoID] = avaliacao
        return avaliacao
    }

    // MARK: Turno do contratante

    /// Segue `confirmar_checkin_manual` do backend (`20260926060100_exigir_conta_ativa_escrita.sql`):
    /// turno que não existe é `404`; sem check-in, `409 checkin_pendente`; check-in geolocalizado,
    /// `409 checkin_ja_confirmado`; o manual já confirmado volta como está. O `403` de quem não é
    /// membro da casa (inclusive o profissional do turno) não é modelado: o dublê simula uma conta só.
    public func confirmarCheckinManual(turnoID: UUID) async throws -> ResultadoRegistro {
        try verificarFalhaGeral()
        guard turnos.contains(where: { $0.id == turnoID }) else { throw erro("nao_encontrado") }
        guard let checkin = checkins[turnoID] else { throw erro("checkin_pendente") }
        guard checkin.tipo == .manual else { throw erro("checkin_ja_confirmado") }
        guard checkin.verificacao != .verificado else { return checkin }
        let confirmado = ResultadoRegistro(
            turnoID: turnoID, tipo: checkin.tipo, verificacao: .verificado,
            registradoEm: checkin.registradoEm, distanciaMetros: checkin.distanciaMetros
        )
        checkins[turnoID] = confirmado
        confirmacoesDeCheckin[turnoID] = relogio.agora
        // O check-out já gravado passa a responder com a verificação atual do turno.
        if let checkout = checkouts[turnoID] {
            checkouts[turnoID] = ResultadoRegistro(
                turnoID: turnoID, tipo: checkout.tipo, verificacao: .verificado,
                registradoEm: checkout.registradoEm, distanciaMetros: checkout.distanciaMetros
            )
        }
        atualizarTurnoAposPresenca(turnoID: turnoID)
        return confirmado
    }

    /// Segue `reabrir_por_atraso` do backend (`20260928220000_alerta_de_atraso_e_reabrir_por_atraso.sql`):
    /// posição que não existe ou de outra casa é `403 sem_permissao`; reenviar devolve o mesmo
    /// resultado; posição que não está confirmada é `409 posicao_nao_cancelavel`, e com check-in o
    /// mesmo código traz `checkin_registrado`; antes dos 15 minutos, `422
    /// reabertura_antes_da_tolerancia`; a menos de 1 h do fim, marca a falta e não abre posição.
    /// Diferença declarada: o backend conta os 15 minutos do início ou da confirmação, o que for
    /// mais tarde; o dublê não guarda a hora da confirmação e conta do início.
    public func reabrirPorAtraso(posicaoID: UUID) async throws -> ResultadoCancelamento {
        try verificarFalhaGeral()
        if let gravado = reaberturasPorAtraso[posicaoID] { return gravado }
        guard let indice = turnos.firstIndex(where: { $0.posicaoID == posicaoID }) else {
            throw erro(conhecidaSemTurno(posicaoID) ? "posicao_nao_cancelavel" : "sem_permissao")
        }
        let turno = turnos[indice]
        guard checkins[turno.id] == nil, turno.checkin == nil else { throw erro("posicao_nao_cancelavel", detalhes: "checkin_registrado") }
        let agora = relogio.agora
        guard agora >= turno.vaga.periodo.inicio.addingTimeInterval(Self.toleranciaDeAtraso) else {
            throw erro("reabertura_antes_da_tolerancia")
        }
        let resultado = cancelarTurno(
            em: indice, falta: true, reabrir: agora < turno.vaga.periodo.fim.addingTimeInterval(-60 * 60),
            causa: .reaberturaPorAtraso, motivo: nil
        )
        reaberturasPorAtraso[posicaoID] = resultado
        return resultado
    }

    // MARK: Cancelamento

    /// Segue `cancelar_posicao` do backend (`20260926060100_exigir_conta_ativa_escrita.sql` e
    /// `privado.cancelar_uma_posicao`): motivo com menos de 3 caracteres é `422 campo_obrigatorio`;
    /// posição que não existe, `404`; a que não está confirmada, `409 posicao_nao_cancelavel`; antes
    /// do início a vaga ganha uma posição nova, depois dele o turno fica descoberto. Quem cancela é
    /// a conta do dublê: com perfil de profissional é o profissional da posição, e a menos de 24 h
    /// do início leva falta; com perfil de contratante é a casa, sem falta. O filtro de termos da
    /// diretriz 1.2 (`422 campo_invalido`, `motivo`) não é modelado.
    public func cancelarPosicao(id: UUID, motivo: String) async throws -> ResultadoCancelamento {
        try verificarFalhaGeral()
        if cenario == .cancelarSemRede { throw ErroDaApi(codigo: .semRede) }
        try validarMotivo(motivo)
        guard let indice = turnos.firstIndex(where: { $0.posicaoID == id }) else {
            throw erro(conhecidaSemTurno(id) ? "posicao_nao_cancelavel" : "nao_encontrado")
        }
        let agora = relogio.agora
        let inicio = turnos[indice].vaga.periodo.inicio
        let peloProfissional = conta?.perfil == .profissional
        let causa: CausaDoCancelamento = peloProfissional ? .profissional : .estabelecimento
        return cancelarTurno(
            em: indice, falta: peloProfissional && inicio.timeIntervalSince(agora) < 24 * 60 * 60, reabrir: inicio > agora,
            causa: causa, motivo: motivo
        )
    }

    /// Segue `cancelar_vaga` do backend (`20260925020000_cancelamentos.sql`): vaga que não existe
    /// ou de outra casa é `404`; a já cancelada ou encerrada, `409 vaga_encerrada`; as posições
    /// confirmadas caem sem falta e sem reabertura, e as abertas, junto. O `422 perfil_incompativel`
    /// da conta de profissional não é modelado: o dublê não cobra RN25 fora dos cadastros.
    public func cancelarVaga(id: UUID, motivo: String) async throws -> VagaCancelada {
        try verificarFalhaGeral()
        try validarMotivo(motivo)
        guard let indice = vagas.firstIndex(where: { $0.id == id }),
              estabelecimentos.contains(where: { $0.id == vagas[indice].estabelecimento.id }) else { throw erro("nao_encontrado") }
        let vaga = vagas[indice]
        guard vaga.estado != .cancelada, vaga.estado != .encerrada else { throw erro("vaga_encerrada") }
        var confirmadas = 0
        while let turno = turnos.firstIndex(where: { $0.vaga.id == id }) {
            _ = cancelarTurno(em: turno, falta: false, reabrir: false, causa: .estabelecimento, motivo: motivo)
            confirmadas += 1
        }
        // Como no backend, as posições abertas passam a `cancelada` e continuam no painel.
        posicoesFechadas[id, default: []] += idsDasPosicoesAbertas(vaga)
        posicoesReabertas[id] = nil
        posicoesAbertasDoPainel[id] = nil
        expirarPendentes(da: id)
        vagas[indice] = Self.copia(vaga, posicoesAbertas: 0, estado: .cancelada)
        return VagaCancelada(vagaID: id, estado: .cancelada, posicoesCanceladas: vaga.posicoesAbertas + confirmadas)
    }

    // MARK: Confiança e direitos

    /// Segue `denunciar` do backend (`20260929100000_denunciar_e_bloquear.sql`): a chave decide antes
    /// de qualquer validação, e reenviar devolve o mesmo protocolo; relato em branco é `422
    /// campo_obrigatorio`, e com menos de 10 caracteres, `422 campo_invalido`; alvo que não existe e
    /// turno que não é das duas partes são `404`. Denunciar a si mesmo (`422 campo_invalido`,
    /// `alvo_id`) não é modelado: a conta única do dublê é também o profissional e a casa de exemplo.
    public func denunciar(_ denuncia: Denuncia) async throws -> Protocolo {
        try verificarFalhaGeral()
        if let gravado = denunciasPorChave[denuncia.chave] { return gravado }
        try validarRelato(denuncia.relato)
        guard existe(denuncia.alvo) else { throw erro("nao_encontrado") }
        if let turnoID = denuncia.turnoID {
            guard let turno = (turnos + turnosCancelados).first(where: { $0.id == turnoID }) else { throw erro("nao_encontrado") }
            let casa = vagas.first { $0.id == turno.vaga.id }?.estabelecimento.id
            guard [turno.contraparte.id, perfilPublicoDeExemplo.id, casa].contains(denuncia.alvo.id) else { throw erro("nao_encontrado") }
        }
        let protocolo = try novoProtocolo(.denuncia)
        denunciasPorChave[denuncia.chave] = protocolo
        return protocolo
    }

    /// Segue `bloquear` do backend (`20260929100000_denunciar_e_bloquear.sql`): alvo que não existe é
    /// `404`, e bloquear de novo devolve o bloqueio que já existe. A partir daí as vagas da casa
    /// bloqueada saem da lista, e detalhe, candidatura e contato respondem `404`. O `perfil_publico`
    /// também responde `404`, conforme o contrato 0.2.28. O alvo é do outro perfil: conta de profissional
    /// bloqueia estabelecimento, e conta de contratante, profissional; o contrário é `422
    /// campo_invalido`, com `alvo_tipo`, conferido antes de procurar o alvo.
    public func bloquear(_ alvo: Alvo) async throws -> Bloqueio {
        try verificarFalhaGeral()
        guard let perfil = conta?.perfil, (perfil == .profissional) == (alvo.tipo == .estabelecimento) else {
            throw erro("campo_invalido", detalhes: "alvo_tipo")
        }
        guard existe(alvo) else { throw erro("nao_encontrado") }
        if let gravado = bloqueios[alvo] { return gravado }
        let bloqueio = Bloqueio(alvo: alvo, criadoEm: relogio.agora)
        bloqueios[alvo] = bloqueio
        return bloqueio
    }

    /// Segue `situacao_da_conta` do backend (`20261001100000_suspensao_da_conta.sql`): responde
    /// também para a conta suspensa, que as outras operações recusam; sem conta é `401`.
    public func situacaoDaConta() async throws -> SituacaoDaConta {
        try verificarRede()
        guard let conta else { throw erro("nao_autenticado") }
        return SituacaoDaConta(estado: conta.estado, suspensao: suspensao)
    }

    /// Segue `contestar_suspensao` do backend (`20261001100000_suspensao_da_conta.sql`), na ordem
    /// dele: sem suspensão é `422 sem_suspensao_ativa`; relato em branco, `422 campo_obrigatorio`; com
    /// menos de 10 caracteres, `422 campo_invalido`; contestação já feita, `409 contestacao_ja_aberta`.
    /// No backend o 409 vale também para a contestação já resolvida, que `situacao_da_conta` não
    /// mostra; o dublê não resolve contestação, então nele as duas leituras coincidem.
    public func contestarSuspensao(relato: String) async throws -> Protocolo {
        try verificarRede()
        guard conta != nil else { throw erro("nao_autenticado") }
        guard let atual = suspensao else { throw erro("sem_suspensao_ativa") }
        try validarRelato(relato)
        guard atual.contestacao == nil else { throw erro("contestacao_ja_aberta") }
        let protocolo = try novoProtocolo(.contestacao)
        suspensao = Suspensao(motivo: atual.motivo, desde: atual.desde, contestacao: protocolo)
        return protocolo
    }

    private var erroExportarMeusDados: (any Error)?

    public func definirErroExportarMeusDados(_ erro: (any Error)?) {
        self.erroExportarMeusDados = erro
    }

    public func exportarMeusDados() async throws -> Data {
        chamadasAExportarMeusDados += 1
        await Task.yield()
        try verificarRede()

        if let erroExportarMeusDados {
            throw erroExportarMeusDados
        }

        if cenario == .exportarSemRede {
            throw ErroDaApi(codigo: .semRede)
        }
        if cenario == .exportarErroServidor {
            throw ErroDaApi(codigo: .desconhecido)
        }

        let agoraISO = ISO8601DateFormatter().string(from: relogio.agora)
        let jsonString = """
        {
          "gerado_em": "\(agoraISO)",
          "conta": {
            "id": "\(conta?.id.uuidString.lowercased() ?? "a0000000-0000-4000-8000-000000000001")",
            "perfil": "\(conta?.perfil.rawValue ?? "profissional")",
            "nome": "\(conta?.nome ?? "Ana")",
            "telefone": "\(conta?.telefone ?? "+5561999990001")",
            "email": "\(conta?.email ?? "ana@frila.test")",
            "nascimento": "\(conta?.nascimento.contrato ?? "1998-04-02")",
            "estado": "\(conta?.estado.rawValue ?? "ativa")"
          },
          "perfil_profissional": null,
          "estabelecimentos": [],
          "disponibilidade": [],
          "turnos": [],
          "avaliacoes_dadas": [],
          "avaliacoes_recebidas": [],
          "dispositivos": []
        }
        """
        guard let data = jsonString.data(using: .utf8) else {
            throw ErroDaApi(codigo: .desconhecido)
        }
        return data
    }

    /// Devolve o CSV ou o PDF de exemplo de `Resources/Fixtures`, que não muda com o período: quem
    /// confere se os valores batem com os turnos gravados é o backend, com seed. O estabelecimento
    /// que não é da conta responde 403, como no contrato.
    public func exportarTurnos(_ pedido: PedidoExportacaoTurnos) async throws -> ResultadoExportacaoTurnos {
        pedidosDeExportacaoDeTurnos.append(pedido)
        await Task.yield()
        try verificarRede()
        guard conta != nil else { throw erro("nao_autenticado") }
        if cenario == .exportarSemRede { throw ErroDaApi(codigo: .semRede) }
        if cenario == .exportarErroServidor { throw ErroDaApi(codigo: .desconhecido) }
        if let estabelecimentoID = pedido.estabelecimentoID, !estabelecimentos.contains(where: { $0.id == estabelecimentoID }) {
            throw erro("sem_permissao")
        }
        if cenario == .exportarTurnosSemTurnos { return .semTurnos }
        return .arquivo(try FixturesDoContrato.arquivo("exportar-turnos", extensao: pedido.formato.rawValue))
    }

    // MARK: Aplicativo e dispositivo

    public func configuracaoDoApp() async throws -> ConfiguracaoApp {
        try verificarRede()
        if cenario == .atualizacaoObrigatoria {
            return ConfiguracaoApp(versaoMinima: "99.0.0", versaoRecomendada: "99.0.0", mensagem: configuracao.mensagem, urlDaLoja: configuracao.urlDaLoja)
        }
        return configuracao
    }

    /// Segue `registrar_dispositivo` do backend (`20260926060100_exigir_conta_ativa_escrita.sql`): o
    /// token é único, e registrar o que era de outra conta troca o dono.
    public func registrarDispositivo(tokenFCM: String) async throws -> Dispositivo {
        try verificarRede()
        guard let conta else { throw erro("nao_autenticado") }
        let token = tokenFCM.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw erro("campo_obrigatorio", detalhes: "token_fcm") }
        guard token.count >= Self.tamanhoMinimoDoToken else { throw erro("campo_invalido", detalhes: "token_fcm") }
        if dispositivos[token] != conta.id || vinculos[token] == nil { vinculos[token] = UUID() }
        dispositivos[token] = conta.id
        return Dispositivo(plataforma: .ios, atualizadoEm: relogio.agora, vinculoID: vinculos[token])
    }

    /// Segue `remover_dispositivo` do backend (`20260926070000_ciclo_token_push.sql`): só tira o token
    /// da conta que chamou, e o token curto ou que não estava registrado não é erro.
    public func removerDispositivo(tokenFCM: String) async throws {
        try verificarRede()
        guard let conta else { throw erro("nao_autenticado") }
        let token = tokenFCM.trimmingCharacters(in: .whitespacesAndNewlines)
        if dispositivos[token] == conta.id {
            dispositivos[token] = nil
            vinculos[token] = nil
        }
    }

    /// A conta dona do token no servidor simulado. Fica fora da porta: serve aos testes.
    public func donoDoDispositivo(tokenFCM: String) -> UUID? { dispositivos[tokenFCM] }

    /// O `vinculo_id` do token no servidor simulado. Fica fora da porta: serve aos testes.
    public func vinculoDoDispositivo(tokenFCM: String) -> UUID? { vinculos[tokenFCM] }

    /// Simula o aparelho que já estava registrado para outra conta. Fica fora da porta: o dublê tem
    /// uma conta só, e a troca de conta no mesmo iPhone precisa da outra.
    public func registrarDispositivo(tokenFCM: String, deOutraConta contaID: UUID) {
        dispositivos[tokenFCM] = contaID
        vinculos[tokenFCM] = UUID()
    }

    public func sair(tokenFCM: String?) async {
        // Como no cliente real: tira o aparelho antes de encerrar a sessão, e a falha não segura a saída.
        if let tokenFCM { try? await removerDispositivo(tokenFCM: tokenFCM) }
        sessaoAtiva = false
        DestinoGuardado.limpar()
    }

    // MARK: Moderação

    /// Ocultar e reexibir uma vaga (contrato 0.2.23). Fica fora da porta `ApiCliente` de propósito:
    /// no backend é operação da Equipe Frila pela chave de serviço. Aqui serve aos testes e às prévias.
    public func moderar(vagaID: UUID, oculta: Bool) {
        guard let indice = vagas.firstIndex(where: { $0.id == vagaID }) else { return }
        vagas[indice] = Self.copia(vagas[indice], oculta: oculta)
    }

    // MARK: Modo seleção, fora da porta

    /// Outro profissional se candidata à vaga de seleção. Fica fora da porta `ApiCliente`: o dublê
    /// simula uma conta só, e os candidatos entre os quais a casa escolhe são de outras. Vale o que
    /// vale para `candidatar`: vaga de seleção, publicada e a mais de 24 h do início.
    @discardableResult
    public func receberCandidatura(vagaID: UUID, de profissional: PerfilPublico) throws -> UUID {
        guard let vaga = vagas.first(where: { $0.id == vagaID }), vaga.modo == .selecao else { throw erro("nao_encontrado") }
        guard vaga.estado != .preenchida else { throw erro("posicao_ja_preenchida") }
        let agora = relogio.agora
        guard vaga.estado == .publicada, agora < vaga.periodo.inicio.addingTimeInterval(-Self.antecedenciaDaSelecao) else {
            throw erro("vaga_encerrada")
        }
        let id = UUID()
        candidaturas.append(CandidaturaGuardada(
            id: id, vagaID: vagaID, profissional: profissional, daConta: false, estado: .pendente, criadaEm: agora
        ))
        return id
    }

    /// O fechamento automático de `privado.fechar_selecoes` (RN24), que no backend é um job a cada
    /// minuto e fica fora da API: a 24 h do início, a vaga de seleção ainda publicada fecha. As
    /// pendentes passam a `expirada`, as posições abertas a `cancelada`, e a vaga vai a `encerrada`
    /// quando ninguém foi escolhido, ou a `preenchida` quando alguma posição foi. Devolve quantas fechou.
    @discardableResult
    public func fecharSelecoes() -> Int {
        let agora = relogio.agora
        var fechadas = 0
        for indice in vagas.indices {
            let vaga = vagas[indice]
            guard vaga.modo == .selecao, vaga.estado == .publicada,
                  vaga.periodo.inicio.addingTimeInterval(-Self.antecedenciaDaSelecao) <= agora else { continue }
            expirarPendentes(da: vaga.id)
            posicoesFechadas[vaga.id, default: []] += idsDasPosicoesAbertas(vaga)
            posicoesReabertas[vaga.id] = nil
            posicoesAbertasDoPainel[vaga.id] = nil
            let escolhida = turnos.contains { $0.vaga.id == vaga.id }
            vagas[indice] = Self.copia(vaga, posicoesAbertas: 0, estado: escolhida ? .preenchida : .encerrada)
            fechadas += 1
        }
        return fechadas
    }

    // MARK: Apoio

    /// A escrita de `escolher_candidato` depois das recusas: confirma o candidato numa posição
    /// aberta, cria o turno e, se era a última posição, enche a vaga e recusa quem ainda esperava.
    private func confirmarEscolha(candidatura indice: Int, vaga daVaga: Int) -> ResultadoConfirmacao {
        let vaga = vagas[daVaga]
        let escolhida = candidaturas[indice]
        let visivelAte = vaga.periodo.fim.addingTimeInterval(7 * 24 * 60 * 60)
        // O que a casa recebe na resposta: o contato do profissional, liberado pela escolha (RN10).
        let contatoDoProfissional = Contato(
            nome: escolhida.profissional.nome, telefone: contatoDeExemplo.telefone, whatsappURL: contatoDeExemplo.whatsappURL,
            visivelAte: visivelAte
        )
        let posicaoID = ocuparPosicaoAberta(vaga.id)
        let turno = Turno(
            id: UUID(), posicaoID: posicaoID, vaga: vaga.resumo,
            contraparte: escolhida.daConta ? vaga.estabelecimento : escolhida.profissional, contatoVisivelAte: visivelAte,
            verificacao: .pendente, valorAcordado: vaga.valor, podeAvaliar: false
        )
        turnos.append(turno)
        if escolhida.daConta {
            // O turno é da conta do dublê, que o lê como profissional: o contato dele é o da casa.
            contatos[turno.id] = Contato(
                nome: vaga.estabelecimento.nome, telefone: contatoDeExemplo.telefone, whatsappURL: contatoDeExemplo.whatsappURL,
                visivelAte: visivelAte
            )
        } else {
            contatos[turno.id] = contatoDoProfissional
            profissionaisEscolhidos[turno.id] = escolhida.profissional
        }
        candidaturas[indice].estado = .aceita
        candidaturas[indice].turnoID = turno.id
        vagas[daVaga] = Self.comPosicoesAbertas(vaga.posicoesAbertas - 1, em: vaga)
        if vagas[daVaga].posicoesAbertas == 0 {
            for outra in candidaturas.indices where candidaturas[outra].vagaID == vaga.id && candidaturas[outra].estado == .pendente {
                candidaturas[outra].estado = .recusada
            }
        }
        return ResultadoConfirmacao(posicaoID: posicaoID, turnoID: turno.id, contato: contatoDoProfissional)
    }

    /// As posições abertas da vaga, primeiro as que um cancelamento abriu. Gera e guarda os ids
    /// que faltam, para o painel mostrar os mesmos a cada leitura.
    private func idsDasPosicoesAbertas(_ vaga: Vaga) -> [UUID] {
        let reabertas = posicoesReabertas[vaga.id] ?? []
        var outras = posicoesAbertasDoPainel[vaga.id] ?? []
        let faltam = max(0, vaga.posicoesAbertas - reabertas.count)
        if outras.count > faltam { outras.removeLast(outras.count - faltam) }
        while outras.count < faltam { outras.append(UUID()) }
        posicoesAbertasDoPainel[vaga.id] = outras
        return Array((reabertas + outras).prefix(vaga.posicoesAbertas))
    }

    /// Ocupa uma posição aberta da vaga: a reaberta primeiro, depois a que o painel já mostrava.
    private func ocuparPosicaoAberta(_ vagaID: UUID) -> UUID {
        if var reabertas = posicoesReabertas[vagaID], !reabertas.isEmpty {
            let id = reabertas.removeFirst()
            posicoesReabertas[vagaID] = reabertas
            return id
        }
        if var outras = posicoesAbertasDoPainel[vagaID], !outras.isEmpty {
            let id = outras.removeFirst()
            posicoesAbertasDoPainel[vagaID] = outras
            return id
        }
        return UUID()
    }

    /// O gatilho `vaga_fechada_expira_candidaturas` do backend: vaga cancelada ou encerrada expira
    /// as candidaturas que ainda esperavam.
    private func expirarPendentes(da vagaID: UUID) {
        for indice in candidaturas.indices where candidaturas[indice].vagaID == vagaID && candidaturas[indice].estado == .pendente {
            candidaturas[indice].estado = .expirada
        }
    }

    private func candidaturaDaConta(na vagaID: UUID) -> CandidaturaGuardada? {
        candidaturas.first { $0.vagaID == vagaID && $0.daConta }
    }

    /// O profissional que o painel mostra na posição: o candidato que a casa escolheu, ou o de exemplo.
    private func profissionalDo(_ turno: Turno) -> PerfilPublico {
        profissionaisEscolhidos[turno.id] ?? perfilPublicoDeExemplo
    }

    private func candidatura(_ guardada: CandidaturaGuardada, em vaga: Vaga) -> Candidatura {
        let turnoID = cenario.isServidorAntigo ? nil : guardada.turnoID
        return Candidatura(id: guardada.id, vaga: vaga.resumo, estado: guardada.estado, criadaEm: guardada.criadaEm, turnoID: turnoID)
    }

    /// O contrato pede `token_fcm` com pelo menos 20 caracteres.
    private static let tamanhoMinimoDoToken = 20

    /// RN24: a vaga de seleção fecha 24 horas antes do início.
    private static let antecedenciaDaSelecao: TimeInterval = 24 * 60 * 60

    /// D06: aos 15 minutos do início sem check-in a posição está em atraso e pode ser reaberta.
    private static let toleranciaDeAtraso: TimeInterval = 15 * 60

    /// O que `privado.cancelar_uma_posicao` faz: a posição cancelada guarda de quem era, e a vaga,
    /// quando reabre, ganha uma posição nova e volta a `publicada`.
    private func cancelarTurno(
        em indice: Int, falta: Bool, reabrir: Bool,
        causa: CausaDoCancelamento = .outro, motivo: String? = nil
    ) -> ResultadoCancelamento {
        let turno = turnos.remove(at: indice)
        let agora = relogio.agora
        cancelamentosPorPosicao[turno.posicaoID] = CancelamentoDaPosicao(
            causa: causa, falta: falta, motivo: motivo, canceladaEm: agora
        )
        // A presença que ainda esperava prova fica `nao_verificado`.
        let verificacao = checkins[turno.id]?.verificacao ?? turno.verificacao
        turnosCancelados.append(Turno(
            id: turno.id, posicaoID: turno.posicaoID, vaga: turno.vaga, contraparte: turno.contraparte,
            contatoVisivelAte: turno.contatoVisivelAte, aCaminhoEm: turno.aCaminhoEm, checkin: turno.checkin,
            checkout: turno.checkout, verificacao: verificacao == .pendente ? .naoVerificado : verificacao,
            valorAcordado: turno.valorAcordado, podeAvaliar: false,
            estado: .cancelada, avaliacao: avaliacoes[turno.id], avaliacaoInformada: true,
            cancelamento: CancelamentoDoTurno(causa: causa, falta: falta, canceladaEm: relogio.agora)
        ))
        contatos[turno.id] = nil
        var nova: UUID?
        if reabrir, let daVaga = vagas.firstIndex(where: { $0.id == turno.vaga.id }) {
            let vaga = vagas[daVaga]
            let id = UUID()
            nova = id
            posicoesReabertas[vaga.id, default: []].append(id)
            vagas[daVaga] = Self.copia(
                vaga, posicoesAbertas: vaga.posicoesAbertas + 1, estado: vaga.estado == .preenchida ? .publicada : vaga.estado
            )
        }
        return ResultadoCancelamento(posicaoID: turno.posicaoID, falta: falta, reaberta: nova != nil, novaPosicaoID: nova)
    }

    /// Posição que o dublê conhece e que não tem turno confirmado: já cancelada, ou aberta por uma reabertura.
    private func conhecidaSemTurno(_ posicaoID: UUID) -> Bool {
        turnosCancelados.contains { $0.posicaoID == posicaoID } || posicoesReabertas.values.contains { $0.contains(posicaoID) }
    }

    private func validarMotivo(_ motivo: String) throws {
        guard motivo.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 else { throw erro("campo_obrigatorio", detalhes: "motivo") }
    }

    private func validarRelato(_ relato: String) throws {
        let limpo = relato.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpo.isEmpty else { throw erro("campo_obrigatorio", detalhes: "relato") }
        guard limpo.count >= 10 else { throw erro("campo_invalido", detalhes: "relato") }
    }

    /// O profissional de exemplo, que o painel mostra nas posições, ou uma casa que o dublê conhece.
    private func existe(_ alvo: Alvo) -> Bool {
        switch alvo.tipo {
        case .profissional: alvo.id == perfilPublicoDeExemplo.id || candidaturas.contains { $0.profissional.id == alvo.id }
        case .estabelecimento: estabelecimentos.contains { $0.id == alvo.id } || vagas.contains { $0.estabelecimento.id == alvo.id }
        }
    }

    private func bloqueada(_ vaga: Vaga) -> Bool {
        bloqueios[Alvo(vaga.estabelecimento)] != nil
    }

    private func novoProtocolo(_ tipo: TipoDeProtocolo) throws -> Protocolo {
        let agora = relogio.agora
        guard let prazo = Self.prazoDeResposta(agora) else { throw ErroDaApi(codigo: .respostaInvalida) }
        return Protocolo(ocorrenciaID: UUID(), tipo: tipo, criadaEm: agora, prazoRespostaAte: prazo)
    }

    /// `privado.prazo_de_resposta` do backend: o quinto dia útil (segunda a sexta) contado do dia
    /// seguinte ao registro, no dia de São Paulo, sem calendário de feriados.
    private static func prazoDeResposta(_ instante: Date) -> DataCivil? {
        var calendario = Calendar(identifier: .gregorian)
        guard let fuso = TimeZone(identifier: "America/Sao_Paulo") else { return nil }
        calendario.timeZone = fuso
        var uteis = 0
        for dias in 1...14 {
            guard let dia = calendario.date(byAdding: .day, value: dias, to: instante) else { return nil }
            if calendario.isDateInWeekend(dia) { continue }
            uteis += 1
            if uteis == 5 { return DataCivil.deSaoPaulo(dia) }
        }
        return nil
    }

    /// O que os dois registros validam depois da idempotência, na ordem do backend
    /// (`privado.exigir_janela`). Diferenças declaradas: o backend tolera até 2 minutos no futuro
    /// e o dublê recusa qualquer instante no futuro; o backend é mais restritivo na janela do turno
    /// (`fora_da_janela` fora de início − 60 min até o fim), que o dublê não confere, então o
    /// dublê aceita registros que o backend recusaria; a exceção de janela da conta de
    /// demonstração também não é modelada.
    private func validarRegistro(distanciaMetros: Int?, registradoEm: Date) throws {
        guard registradoEm <= relogio.agora else { throw erro("registro_no_futuro") }
        if let distanciaMetros, distanciaMetros < 0 { throw erro("campo_invalido", detalhes: "distancia_m") }
    }

    private func doCatalogo(_ ids: [UUID]) throws -> [Funcao] {
        try ids.map { id in
            guard let funcao = catalogo.first(where: { $0.id == id }) else { throw erro("campo_invalido", detalhes: "funcoes") }
            return funcao
        }
    }

    private func perfilDo(_ estabelecimento: Estabelecimento) -> PerfilPublico {
        vagas.map(\.estabelecimento).first { $0.id == estabelecimento.id }
            ?? PerfilPublico(
                id: estabelecimento.id, tipo: .estabelecimento, nome: estabelecimento.nome,
                reputacao: Reputacao(positivas: 0, total: 0, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0)
            )
    }

    private func verificarRede() throws {
        if cenario == .semRede { throw ErroDaApi(codigo: .semRede) }
    }

    private func verificarFalhaGeral() throws {
        try verificarRede()
        if cenario == .contaSuspensa { throw erro("sem_permissao", detalhes: "conta_suspensa") }
    }

    /// Erro montado a partir do envelope em `erros.json`, como o cliente real recebe.
    private func erro(_ codigo: String, detalhes: String? = nil) -> ErroDaApi {
        let envelope = envelopes.values.first { $0.code == codigo && (detalhes == nil || $0.details == detalhes) } ?? envelopes[codigo]
        return DecodificadorErroAPI.mapear(codigo: envelope?.code ?? codigo, detalhes: detalhes ?? envelope?.details)
    }

    private static func noFuturo(_ vaga: Vaga, agora: Date, inicioEm: TimeInterval = 24 * 60 * 60) throws -> Vaga {
        let inicio = agora.addingTimeInterval(inicioEm)
        let periodo = try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(vaga.periodo.fim.timeIntervalSince(vaga.periodo.inicio)))
        return copia(vaga, periodo: periodo, publicadoEm: agora)
    }

    private static func comPosicoesAbertas(_ abertas: Int, em vaga: Vaga) -> Vaga {
        copia(vaga, posicoesAbertas: abertas, estado: abertas == 0 ? .preenchida : vaga.estado)
    }

    /// A vaga com o que o dublê muda nela; o que não vier fica como está.
    private static func copia(
        _ vaga: Vaga, periodo: Periodo? = nil, posicoes: Int? = nil, posicoesAbertas: Int? = nil, modo: ModoPreenchimento? = nil,
        estado: EstadoVaga? = nil, oculta: Bool? = nil, publicadoEm: Date? = nil
    ) -> Vaga {
        Vaga(
            id: vaga.id, estabelecimento: vaga.estabelecimento, funcao: vaga.funcao, periodo: periodo ?? vaga.periodo,
            local: vaga.local, regiaoAdministrativa: vaga.regiaoAdministrativa, ponto: vaga.ponto, distanciaKm: vaga.distanciaKm,
            valor: vaga.valor, posicoes: posicoes ?? vaga.posicoes, posicoesAbertas: posicoesAbertas ?? vaga.posicoesAbertas,
            inclusos: vaga.inclusos, responsavelLocal: vaga.responsavelLocal, traje: vaga.traje,
            participaRateio: vaga.participaRateio, observacoes: vaga.observacoes, modo: modo ?? vaga.modo,
            estado: estado ?? vaga.estado, oculta: oculta ?? vaga.oculta, publicadoEm: publicadoEm ?? vaga.publicadoEm
        )
    }
}

// MARK: - Exclusão de Conta (Porta ExclusaoDeContaPorta)

public enum CenarioExclusaoConta: Sendable, Equatable {
    case padrao
    case comTurnosCancelados(Int)
    case administradorUnico
    case semRede
    case naoAutenticado
}

private actor ArmazenamentoCenarioExclusao {
    static let compartilhado = ArmazenamentoCenarioExclusao()
    private var cenarios: [ObjectIdentifier: CenarioExclusaoConta] = [:]

    func definir(_ cenario: CenarioExclusaoConta, para cliente: ApiClienteEmMemoria) {
        cenarios[ObjectIdentifier(cliente)] = cenario
    }

    func consumir(para cliente: ApiClienteEmMemoria) -> CenarioExclusaoConta {
        cenarios.removeValue(forKey: ObjectIdentifier(cliente)) ?? .padrao
    }

    func limpar() {
        cenarios.removeAll()
    }
}

extension ApiClienteEmMemoria: ExclusaoDeContaPorta {
    public func configurarCenarioExclusao(_ cenario: CenarioExclusaoConta) async {
        await ArmazenamentoCenarioExclusao.compartilhado.definir(cenario, para: self)
    }

    public func excluirConta() async throws -> ExclusaoDeConta {
        let configurado = await ArmazenamentoCenarioExclusao.compartilhado.consumir(para: self)

        let argumentos = ProcessInfo.processInfo.arguments
        let cenarioEfetivo: CenarioExclusaoConta
        if configurado != .padrao {
            cenarioEfetivo = configurado
        } else if argumentos.contains("-FRILA_EXCLUSAO_ADMIN_UNICO") {
            cenarioEfetivo = .administradorUnico
        } else if argumentos.contains("-FRILA_EXCLUSAO_SEM_REDE") {
            cenarioEfetivo = .semRede
        } else if argumentos.contains("-FRILA_EXCLUSAO_401") {
            cenarioEfetivo = .naoAutenticado
        } else if let idx = argumentos.firstIndex(of: "-FRILA_EXCLUSAO_TURNOS"), argumentos.indices.contains(idx + 1), let n = Int(argumentos[idx + 1]) {
            cenarioEfetivo = .comTurnosCancelados(n)
        } else {
            cenarioEfetivo = .padrao
        }

        if cenarioEfetivo == .semRede || cenario == .semRede {
            throw ErroDaApi(codigo: .semRede)
        }
        try verificarRede()

        if cenarioEfetivo == .naoAutenticado {
            throw ErroDaApi(codigo: .naoAutenticado, codigoOriginal: "nao_autenticado")
        }

        if cenarioEfetivo == .administradorUnico {
            throw ErroDaApi(codigo: .administradorUnico, codigoOriginal: "administrador_unico")
        }

        let cancelados: Int
        switch cenarioEfetivo {
        case let .comTurnosCancelados(quantidade):
            cancelados = quantidade
        default:
            cancelados = turnos.count
        }

        turnos.removeAll()
        conta = nil
        perfilProfissional = nil
        estabelecimentos = []
        sessaoAtiva = false
        DestinoGuardado.limpar()

        let agora = relogio.agora
        let dataLimite = DataCivil.deSaoPaulo(agora, somandoDias: 15) ?? (try! DataCivil("2026-10-16"))
        return ExclusaoDeConta(
            perfilRemovidoEm: agora,
            dadosApagadosAte: dataLimite,
            turnosCancelados: cancelados
        )
    }

    // MARK: - Suporte a cenários de teste da suspensão (#41)

    public func reativarConta() {
        if let contaAtual = conta {
            conta = Conta(
                id: contaAtual.id,
                perfil: contaAtual.perfil,
                nome: contaAtual.nome,
                telefone: contaAtual.telefone,
                email: contaAtual.email,
                nascimento: contaAtual.nascimento,
                estado: .ativa
            )
        }
        suspensao = nil
    }

    public func definirContestacaoExistente(protocolo: Protocolo? = nil) throws {
        guard let atual = suspensao else { throw erro("sem_suspensao_ativa") }
        let prot = try protocolo ?? novoProtocolo(.contestacao)
        suspensao = Suspensao(motivo: atual.motivo, desde: atual.desde, contestacao: prot)
    }
}

