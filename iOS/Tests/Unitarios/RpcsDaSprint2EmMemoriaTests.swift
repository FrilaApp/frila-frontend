import Foundation
import FrilaDados
import FrilaDominio
import Testing

/// Relógio que o teste avança: atraso, tolerância e falta dependem do instante.
private final class RelogioDeTeste: Relogio, @unchecked Sendable {
    private let trava = NSLock()
    private var _agora: Date
    init(_ agora: Date) { _agora = agora }
    var agora: Date { trava.withLock { _agora } }
    func avancar(para instante: Date) { trava.withLock { _agora = instante } }
}

private let hora: TimeInterval = 3_600
private let minuto: TimeInterval = 60
/// Sexta-feira, 15/01/2027, 05:00 em São Paulo.
private let agoraDoTeste = Date(timeIntervalSince1970: 1_800_000_000)

/// Uma vaga de quatro horas publicada pela casa da fixture, com um turno confirmado nela.
private struct Cena {
    let api: ApiClienteEmMemoria
    let relogio: RelogioDeTeste
    let casaID: UUID
    let vagaID: UUID
    let turnoID: UUID
    let posicaoID: UUID
    let inicio: Date

    var fim: Date { inicio.addingTimeInterval(4 * hora) }

    static func montar(
        emHoras horas: Double = 2, posicoes: Int = 1, cenario: ApiClienteEmMemoria.Cenario = .sucesso
    ) async throws -> Cena {
        let relogio = RelogioDeTeste(agoraDoTeste)
        let api = ApiClienteEmMemoria(cenario: cenario, relogio: relogio)
        let casa = try #require(try await api.meusEstabelecimentos().first)
        let funcao = try #require(try await api.funcoes().first)
        let inicio = agoraDoTeste.addingTimeInterval(horas * hora)
        let vagaID = try await api.publicarVaga(PublicacaoVaga(
            estabelecimentoID: casa.id, funcaoID: funcao.id,
            periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(4 * hora)),
            local: "CLS 405, Asa Sul, Brasília - DF", regiaoAdministrativa: "Plano Piloto",
            ponto: try Coordenada(latitude: -15.8121, longitude: -47.8997), valor: Dinheiro(centavos: 12000),
            posicoes: posicoes, inclusos: Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Marina", chave: UUID()
        )).vagaID
        let candidatura = try await api.candidatar(vagaID: vagaID)
        return Cena(
            api: api, relogio: relogio, casaID: casa.id, vagaID: vagaID,
            turnoID: try #require(candidatura.turnoID), posicaoID: try #require(candidatura.posicaoID), inicio: inicio
        )
    }

    func painel() async throws -> Painel {
        let periodo = try Periodo(inicio: agoraDoTeste.addingTimeInterval(-hora), fim: agoraDoTeste.addingTimeInterval(120 * hora))
        return try await api.painelEstabelecimento(id: casaID, periodo: periodo)
    }

    func vagaNoPainel() async throws -> VagaNoPainel {
        try #require(try await painel().vagas.first { $0.vaga.id == vagaID })
    }

    func posicaoNoPainel(_ id: UUID? = nil) async throws -> PosicaoNoPainel {
        try #require(try await vagaNoPainel().posicoes.first { $0.id == id ?? posicaoID })
    }

    /// O turno como `meusTurnos` o devolve. Como no backend, o de posição cancelada continua na lista.
    func turnoEmMeusTurnos() async throws -> Turno {
        try #require(try await api.meusTurnos().first { $0.id == turnoID })
    }

    /// Check-in sem localização, no início do turno: manual e pendente.
    func checkinManual() async throws {
        relogio.avancar(para: inicio)
        _ = try await api.fazerCheckin(turnoID: turnoID, distanciaMetros: nil, registradoEm: inicio)
    }
}

// MARK: - #19

/// O dublê segue `confirmar_checkin_manual` (`20260926060100_exigir_conta_ativa_escrita.sql`),
/// `reabrir_por_atraso` (`20260928220000_alerta_de_atraso_e_reabrir_por_atraso.sql`) e o
/// `em_atraso` e os `checkins_pendentes` do painel (`20260930160000_avisar_a_caminho.sql`).
@Suite("Dublê: turno do contratante (#19)")
struct TurnoDoContratanteEmMemoriaTests {
    @Test("O check-in manual aparece no painel como pendente, com o turno na lista de pendentes")
    func checkinManualPendenteNoPainel() async throws {
        let cena = try await Cena.montar()
        #expect(try await cena.painel().checkinsPendentes.isEmpty)

        try await cena.checkinManual()

        #expect(try await cena.painel().checkinsPendentes == [cena.turnoID])
        #expect(try await cena.posicaoNoPainel().verificacao == .pendente)
    }

    @Test("Confirmar o check-in manual verifica a presença na hora e tira o turno dos pendentes")
    func confirmar() async throws {
        let cena = try await Cena.montar()
        try await cena.checkinManual()

        let registro = try await cena.api.confirmarCheckinManual(turnoID: cena.turnoID)

        #expect(registro == ResultadoRegistro(
            turnoID: cena.turnoID, tipo: .manual, verificacao: .verificado, registradoEm: cena.inicio, distanciaMetros: nil
        ))
        #expect(try await cena.painel().checkinsPendentes.isEmpty)
        #expect(try await cena.posicaoNoPainel().verificacao == .verificado)
    }

    @Test("Confirmar de novo devolve o mesmo registro")
    func confirmarDeNovo() async throws {
        let cena = try await Cena.montar()
        try await cena.checkinManual()
        let primeira = try await cena.api.confirmarCheckinManual(turnoID: cena.turnoID)
        cena.relogio.avancar(para: cena.inicio.addingTimeInterval(hora))
        #expect(try await cena.api.confirmarCheckinManual(turnoID: cena.turnoID) == primeira)
    }

    @Test("O check-out feito depois da confirmação sai com a presença verificada")
    func checkoutDepoisDaConfirmacao() async throws {
        let cena = try await Cena.montar()
        try await cena.checkinManual()
        _ = try await cena.api.confirmarCheckinManual(turnoID: cena.turnoID)
        cena.relogio.avancar(para: cena.fim)

        let saida = try await cena.api.fazerCheckout(turnoID: cena.turnoID, distanciaMetros: 20, registradoEm: cena.fim)

        #expect(saida.tipo == .manual)
        #expect(saida.verificacao == .verificado)
    }

    @Test("Sem check-in é checkin_pendente; check-in geolocalizado é checkin_ja_confirmado; turno que não existe é 404")
    func recusasDaConfirmacao() async throws {
        let cena = try await Cena.montar()
        await #expect(throws: ErroDaApi(codigo: .checkinPendente)) {
            try await cena.api.confirmarCheckinManual(turnoID: cena.turnoID)
        }
        await #expect(throws: ErroDaApi(codigo: .naoEncontrado)) {
            try await cena.api.confirmarCheckinManual(turnoID: UUID())
        }

        cena.relogio.avancar(para: cena.inicio)
        _ = try await cena.api.fazerCheckin(turnoID: cena.turnoID, distanciaMetros: 40, registradoEm: cena.inicio)
        await #expect(throws: ErroDaApi(codigo: .checkinJaConfirmado)) {
            try await cena.api.confirmarCheckinManual(turnoID: cena.turnoID)
        }
        #expect(try await cena.painel().checkinsPendentes.isEmpty)
    }

    @Test("A posição fica em atraso dos 15 minutos do início até o fim, e só sem check-in")
    func emAtraso() async throws {
        let cena = try await Cena.montar()
        #expect(try await !cena.posicaoNoPainel().emAtraso)

        cena.relogio.avancar(para: cena.inicio.addingTimeInterval(15 * minuto - 1))
        #expect(try await !cena.posicaoNoPainel().emAtraso)
        cena.relogio.avancar(para: cena.inicio.addingTimeInterval(15 * minuto))
        #expect(try await cena.posicaoNoPainel().emAtraso)
        cena.relogio.avancar(para: cena.fim)
        #expect(try await !cena.posicaoNoPainel().emAtraso)

        cena.relogio.avancar(para: cena.inicio.addingTimeInterval(20 * minuto))
        _ = try await cena.api.fazerCheckin(turnoID: cena.turnoID, distanciaMetros: nil, registradoEm: cena.relogio.agora)
        #expect(try await !cena.posicaoNoPainel().emAtraso)
    }

    @Test("Reabrir antes dos 15 minutos é reabertura_antes_da_tolerancia, e nada muda")
    func reabrirAntesDaTolerancia() async throws {
        let cena = try await Cena.montar()
        cena.relogio.avancar(para: cena.inicio.addingTimeInterval(15 * minuto - 1))

        await #expect(throws: ErroDaApi(codigo: .reaberturaAntesDaTolerancia)) {
            try await cena.api.reabrirPorAtraso(posicaoID: cena.posicaoID)
        }
        #expect(try await cena.posicaoNoPainel().estado == .confirmada)
    }

    @Test("Reabrir aos 15 minutos marca falta, cancela a posição e abre uma nova na mesma vaga")
    func reabrir() async throws {
        let cena = try await Cena.montar()
        cena.relogio.avancar(para: cena.inicio.addingTimeInterval(15 * minuto))

        let resultado = try await cena.api.reabrirPorAtraso(posicaoID: cena.posicaoID)

        #expect(resultado.posicaoID == cena.posicaoID)
        #expect(resultado.falta)
        #expect(resultado.reaberta)
        let nova = try #require(resultado.novaPosicaoID)
        #expect(nova != cena.posicaoID)

        let cancelada = try await cena.posicaoNoPainel()
        #expect(cancelada.estado == .cancelada)
        #expect(cancelada.verificacao == .naoVerificado)
        #expect(!cancelada.emAtraso)
        let aberta = try await cena.posicaoNoPainel(nova)
        #expect(aberta.estado == .aberta)
        #expect(aberta.profissional == nil)
        let vaga = try await cena.vagaNoPainel()
        #expect(vaga.estado == .publicada)
        #expect(vaga.posicoes.count == 2)
        // Como no backend, o turno de quem faltou continua em Meus turnos, já sem presença a provar.
        #expect(try await cena.turnoEmMeusTurnos().verificacao == .naoVerificado)
    }

    @Test("Reenviar a reabertura devolve o mesmo resultado, sem segunda posição")
    func reabrirDeNovo() async throws {
        let cena = try await Cena.montar()
        cena.relogio.avancar(para: cena.inicio.addingTimeInterval(20 * minuto))
        let primeira = try await cena.api.reabrirPorAtraso(posicaoID: cena.posicaoID)

        #expect(try await cena.api.reabrirPorAtraso(posicaoID: cena.posicaoID) == primeira)
        #expect(try await cena.vagaNoPainel().posicoes.count == 2)
    }

    @Test("A menos de uma hora do fim, reabrir marca a falta e não abre posição")
    func reabrirPertoDoFim() async throws {
        let cena = try await Cena.montar()
        cena.relogio.avancar(para: cena.fim.addingTimeInterval(-hora))

        let resultado = try await cena.api.reabrirPorAtraso(posicaoID: cena.posicaoID)

        #expect(resultado == ResultadoCancelamento(posicaoID: cena.posicaoID, falta: true, reaberta: false, novaPosicaoID: nil))
        #expect(try await cena.vagaNoPainel().posicoes.map(\.estado) == [.cancelada])
    }

    @Test("Com check-in feito, reabrir é posicao_nao_cancelavel, com o detalhe checkin_registrado")
    func reabrirComCheckin() async throws {
        let cena = try await Cena.montar()
        try await cena.checkinManual()
        cena.relogio.avancar(para: cena.inicio.addingTimeInterval(30 * minuto))

        await #expect(throws: ErroDaApi(codigo: .posicaoNaoCancelavel, detalhes: "checkin_registrado")) {
            try await cena.api.reabrirPorAtraso(posicaoID: cena.posicaoID)
        }
    }

    @Test("Posição de outra casa ou que não existe é sem_permissao; posição que não está confirmada, posicao_nao_cancelavel")
    func reabrirOutraPosicao() async throws {
        let cena = try await Cena.montar()
        cena.relogio.avancar(para: cena.inicio.addingTimeInterval(20 * minuto))
        await #expect(throws: ErroDaApi(codigo: .semPermissao)) {
            try await cena.api.reabrirPorAtraso(posicaoID: UUID())
        }

        let nova = try #require(try await cena.api.reabrirPorAtraso(posicaoID: cena.posicaoID).novaPosicaoID)
        await #expect(throws: ErroDaApi(codigo: .posicaoNaoCancelavel)) {
            try await cena.api.reabrirPorAtraso(posicaoID: nova)
        }
    }
}

// MARK: - #20

/// O dublê segue `cancelar_posicao` (`20260926060100_exigir_conta_ativa_escrita.sql`) e
/// `cancelar_vaga` (`20260925020000_cancelamentos.sql`). Quem cancela é a conta do dublê: com
/// perfil de profissional ele é o profissional da posição; com perfil de contratante, a casa.
@Suite("Dublê: cancelamento com motivo (#20)")
struct CancelamentoEmMemoriaTests {
    private let motivo = "Imprevisto de saúde"

    @Test("Profissional que cancela a menos de 24 horas leva falta, e a posição reabre")
    func profissionalEmCimaDaHora() async throws {
        let cena = try await Cena.montar(emHoras: 2)

        let resultado = try await cena.api.cancelarPosicao(id: cena.posicaoID, motivo: motivo)

        #expect(resultado.posicaoID == cena.posicaoID)
        #expect(resultado.falta)
        #expect(resultado.reaberta)
        let nova = try #require(resultado.novaPosicaoID)
        #expect(try await cena.posicaoNoPainel().estado == .cancelada)
        #expect(try await cena.posicaoNoPainel(nova).estado == .aberta)
        #expect(try await cena.vagaNoPainel().estado == .publicada)
        // `meus_turnos` não filtra pelo estado da posição: o turno cancelado continua na lista, e o
        // `Turno` do contrato não tem estado que o distinga, só a verificação.
        #expect(try await cena.turnoEmMeusTurnos().verificacao == .naoVerificado)
        // A posição nova volta para a vitrine.
        #expect(try await cena.api.vagasAbertas().contains { $0.id == cena.vagaID })
    }

    @Test("Profissional que cancela com mais de 24 horas não leva falta")
    func profissionalComAntecedencia() async throws {
        let cena = try await Cena.montar(emHoras: 48)
        let resultado = try await cena.api.cancelarPosicao(id: cena.posicaoID, motivo: motivo)
        #expect(!resultado.falta)
        #expect(resultado.reaberta)
    }

    @Test("Cancelamento pelo contratante não gera falta para ninguém")
    func contratante() async throws {
        let cena = try await Cena.montar(emHoras: 2, cenario: .contratante)
        let resultado = try await cena.api.cancelarPosicao(id: cena.posicaoID, motivo: motivo)
        #expect(!resultado.falta)
        #expect(resultado.reaberta)
    }

    @Test("Depois do início a posição recusa cancelamento (0.2.35)")
    func depoisDoInicio() async throws {
        let cena = try await Cena.montar(emHoras: 2, cenario: .contratante)
        cena.relogio.avancar(para: cena.inicio.addingTimeInterval(20 * minuto))

        await #expect(throws: ErroDaApi(codigo: .posicaoNaoCancelavel)) {
            try await cena.api.cancelarPosicao(id: cena.posicaoID, motivo: motivo)
        }
        #expect(try await cena.posicaoNoPainel().estado == .confirmada)
    }

    @Test("Motivo com menos de 3 caracteres é campo_obrigatorio, com o campo no detalhe", arguments: ["", "  ", "ok", " ok "])
    func motivoCurto(motivo: String) async throws {
        let cena = try await Cena.montar()
        await #expect(throws: ErroDaApi(codigo: .campoObrigatorio, detalhes: "motivo")) {
            try await cena.api.cancelarPosicao(id: cena.posicaoID, motivo: motivo)
        }
        await #expect(throws: ErroDaApi(codigo: .campoObrigatorio, detalhes: "motivo")) {
            try await cena.api.cancelarVaga(id: cena.vagaID, motivo: motivo)
        }
        #expect(try await cena.posicaoNoPainel().estado == .confirmada)
    }

    @Test("Posição aberta é posicao_nao_cancelavel; reenvio pelo autor é sucesso; inexistente é nao_encontrado")
    func posicaoNaoCancelavel() async throws {
        let cena = try await Cena.montar()
        await #expect(throws: ErroDaApi(codigo: .naoEncontrado)) {
            try await cena.api.cancelarPosicao(id: UUID(), motivo: motivo)
        }

        let original = try await cena.api.cancelarPosicao(id: cena.posicaoID, motivo: motivo)
        let nova = try #require(original.novaPosicaoID)
        #expect(try await cena.api.cancelarPosicao(id: cena.posicaoID, motivo: motivo) == original)
        await #expect(throws: ErroDaApi(codigo: .posicaoNaoCancelavel)) {
            try await cena.api.cancelarPosicao(id: nova, motivo: motivo)
        }
    }

    @Test("Cancelar a vaga cancela as posições abertas e as confirmadas e tira a vaga da vitrine")
    func cancelarVaga() async throws {
        let cena = try await Cena.montar(emHoras: 48, posicoes: 3)

        let cancelada = try await cena.api.cancelarVaga(id: cena.vagaID, motivo: "O evento foi adiado")

        #expect(cancelada == VagaCancelada(vagaID: cena.vagaID, estado: .cancelada, posicoesCanceladas: 3))
        #expect(try await cena.vagaNoPainel().estado == .cancelada)
        #expect(try await cena.posicaoNoPainel().estado == .cancelada)
        #expect(try await !cena.api.vagasAbertas().contains { $0.id == cena.vagaID })
        #expect(try await cena.turnoEmMeusTurnos().verificacao == .naoVerificado)
        await #expect(throws: ErroDaApi(codigo: .vagaEncerrada)) { try await cena.api.candidatar(vagaID: cena.vagaID) }
    }

    @Test("Cancelar a vaga depois do início responde vaga_encerrada e mantém a presença")
    func cancelarVagaDepoisDoInicio() async throws {
        let cena = try await Cena.montar()
        cena.relogio.avancar(para: cena.inicio)
        _ = try await cena.api.fazerCheckin(turnoID: cena.turnoID, distanciaMetros: 40, registradoEm: cena.inicio)
        cena.relogio.avancar(para: cena.inicio.addingTimeInterval(hora))

        await #expect(throws: ErroDaApi(codigo: .vagaEncerrada)) {
            try await cena.api.cancelarVaga(id: cena.vagaID, motivo: motivo)
        }
        let posicao = try await cena.posicaoNoPainel()
        #expect(posicao.estado == .confirmada)
        #expect(posicao.verificacao == .verificado)
    }

    @Test("Posição com check-in feito e turno em andamento recusa cancelamento")
    func cancelarComCheckinFeito() async throws {
        let cena = try await Cena.montar(cenario: .contratante)
        try await cena.checkinManual()
        cena.relogio.avancar(para: cena.inicio.addingTimeInterval(hora))

        await #expect(throws: ErroDaApi(codigo: .posicaoNaoCancelavel)) {
            try await cena.api.cancelarPosicao(id: cena.posicaoID, motivo: motivo)
        }
        #expect(try await cena.posicaoNoPainel().verificacao == .pendente)
        #expect(try await !cena.painel().checkinsPendentes.isEmpty)
    }

    @Test("Vaga cancelada pelo mesmo autor devolve resultado original; inexistente é nao_encontrado")
    func cancelarVagaDeNovo() async throws {
        let cena = try await Cena.montar()
        await #expect(throws: ErroDaApi(codigo: .naoEncontrado)) {
            try await cena.api.cancelarVaga(id: UUID(), motivo: motivo)
        }
        let original = try await cena.api.cancelarVaga(id: cena.vagaID, motivo: motivo)
        #expect(try await cena.api.cancelarVaga(id: cena.vagaID, motivo: motivo) == original)
    }
}

// MARK: - #39

/// O dublê segue `denunciar` e `bloquear` (`20260929100000_denunciar_e_bloquear.sql`).
@Suite("Dublê: denunciar e bloquear (#39)")
struct ConfiancaEmMemoriaTests {
    private let relato = "Chegou alterado e ameaçou a equipe da cozinha."

    /// O profissional que o painel do dublê mostra nas posições confirmadas.
    private func profissional(_ cena: Cena) async throws -> Alvo {
        Alvo(try #require(try await cena.posicaoNoPainel().profissional))
    }

    private func casa(_ cena: Cena) async throws -> Alvo {
        Alvo(try await cena.api.detalheDaVaga(id: cena.vagaID).estabelecimento)
    }

    @Test("A denúncia devolve o protocolo, com prazo de 5 dias úteis")
    func denunciar() async throws {
        let cena = try await Cena.montar()
        let denuncia = Denuncia(alvo: try await profissional(cena), turnoID: cena.turnoID, motivo: .riscoSeguranca, relato: relato, chave: UUID())

        let protocolo = try await cena.api.denunciar(denuncia)

        #expect(protocolo.tipo == .denuncia)
        #expect(protocolo.criadaEm == agoraDoTeste)
        // Registrada na sexta, 15/01/2027: segunda 18, terça 19, quarta 20, quinta 21 e sexta 22.
        #expect(protocolo.prazoRespostaAte == (try DataCivil("2027-01-22")))
    }

    @Test("O prazo conta do dia de São Paulo em que a denúncia foi registrada")
    func prazoNoFusoDeSaoPaulo() async throws {
        let cena = try await Cena.montar()
        // 02:00 UTC de sexta ainda é quinta, 14/01, 23:00 em São Paulo: o quinto dia útil é a quinta 21.
        let quintaANoite = agoraDoTeste.addingTimeInterval(-6 * hora)
        cena.relogio.avancar(para: quintaANoite)
        let denuncia = Denuncia(alvo: try await casa(cena), motivo: .outro, relato: relato, chave: UUID())
        #expect(try await cena.api.denunciar(denuncia).prazoRespostaAte == (try DataCivil("2027-01-21")))
    }

    @Test("Reenviar com a mesma chave devolve o mesmo protocolo; chave nova abre outro")
    func chaveDeIdempotencia() async throws {
        let cena = try await Cena.montar()
        let alvo = try await casa(cena)
        let chave = UUID()
        let primeira = try await cena.api.denunciar(Denuncia(alvo: alvo, motivo: .assedio, relato: relato, chave: chave))

        cena.relogio.avancar(para: agoraDoTeste.addingTimeInterval(hora))
        // A chave decide antes de qualquer validação: nem um relato curto muda o que já foi registrado.
        let reenviada = try await cena.api.denunciar(Denuncia(alvo: alvo, motivo: .outro, relato: "curto", chave: chave))
        #expect(reenviada == primeira)

        let outra = try await cena.api.denunciar(Denuncia(alvo: alvo, motivo: .assedio, relato: relato, chave: UUID()))
        #expect(outra.ocorrenciaID != primeira.ocorrenciaID)
    }

    @Test("Relato em branco é campo_obrigatorio; com menos de 10 caracteres, campo_invalido")
    func relato() async throws {
        let cena = try await Cena.montar()
        let alvo = try await casa(cena)
        await #expect(throws: ErroDaApi(codigo: .campoObrigatorio, detalhes: "relato")) {
            try await cena.api.denunciar(Denuncia(alvo: alvo, motivo: .outro, relato: "   ", chave: UUID()))
        }
        await #expect(throws: ErroDaApi(codigo: .campoInvalido, detalhes: "relato")) {
            try await cena.api.denunciar(Denuncia(alvo: alvo, motivo: .outro, relato: " nove car ", chave: UUID()))
        }
    }

    @Test("Alvo que não existe é 404, na denúncia e no bloqueio", arguments: [TipoPerfilPublico.profissional, .estabelecimento])
    func alvoQueNaoExiste(tipo: TipoPerfilPublico) async throws {
        // Quem bloqueia é do outro perfil: a casa bloqueia o profissional, e o profissional, a casa.
        let cena = try await Cena.montar(cenario: tipo == .profissional ? .contratante : .sucesso)
        let estranho = Alvo(tipo: tipo, id: UUID())
        await #expect(throws: ErroDaApi(codigo: .naoEncontrado)) {
            try await cena.api.denunciar(Denuncia(alvo: estranho, motivo: .outro, relato: relato, chave: UUID()))
        }
        await #expect(throws: ErroDaApi(codigo: .naoEncontrado)) { try await cena.api.bloquear(estranho) }
    }

    @Test("Bloquear alvo do mesmo perfil é campo_invalido em alvo_tipo, exista o alvo ou não")
    func bloquearMesmoPerfil() async throws {
        let profissional = try await Cena.montar()
        let colega = try await self.profissional(profissional)
        await #expect(throws: ErroDaApi(codigo: .campoInvalido, detalhes: "alvo_tipo")) { try await profissional.api.bloquear(colega) }
        await #expect(throws: ErroDaApi(codigo: .campoInvalido, detalhes: "alvo_tipo")) {
            try await profissional.api.bloquear(Alvo(tipo: .profissional, id: UUID()))
        }

        let contratante = try await Cena.montar(cenario: .contratante)
        let outraCasa = try await casa(contratante)
        await #expect(throws: ErroDaApi(codigo: .campoInvalido, detalhes: "alvo_tipo")) { try await contratante.api.bloquear(outraCasa) }
        // Nada foi bloqueado: a vaga da casa continua na lista.
        #expect(try await contratante.api.detalheDaVaga(id: contratante.vagaID).id == contratante.vagaID)
    }

    @Test("Turno que não é das duas partes é 404")
    func turnoDeOutros() async throws {
        let cena = try await Cena.montar()
        let alvo = try await casa(cena)
        await #expect(throws: ErroDaApi(codigo: .naoEncontrado)) {
            try await cena.api.denunciar(Denuncia(alvo: alvo, turnoID: UUID(), motivo: .outro, relato: relato, chave: UUID()))
        }
    }

    @Test("Bloquear é imediato, e bloquear de novo devolve o bloqueio que já existe")
    func bloquear() async throws {
        let cena = try await Cena.montar(cenario: .contratante)
        let alvo = try await profissional(cena)

        let bloqueio = try await cena.api.bloquear(alvo)
        #expect(bloqueio == Bloqueio(alvo: alvo, criadoEm: agoraDoTeste))

        cena.relogio.avancar(para: agoraDoTeste.addingTimeInterval(hora))
        #expect(try await cena.api.bloquear(alvo) == bloqueio)
    }

    @Test("Bloqueada a casa, as vagas dela somem da lista, e detalhe, candidatura e contato respondem 404")
    func efeitoDoBloqueio() async throws {
        let cena = try await Cena.montar(posicoes: 2)
        #expect(try await cena.api.vagasAbertas().contains { $0.id == cena.vagaID })

        _ = try await cena.api.bloquear(try await casa(cena))

        #expect(try await !cena.api.vagasAbertas().contains { $0.id == cena.vagaID })
        await #expect(throws: ErroDaApi(codigo: .naoEncontrado)) { try await cena.api.detalheDaVaga(id: cena.vagaID) }
        await #expect(throws: ErroDaApi(codigo: .naoEncontrado)) { try await cena.api.candidatar(vagaID: cena.vagaID) }
        await #expect(throws: ErroDaApi(codigo: .naoEncontrado)) { try await cena.api.contatoDoTurno(id: cena.turnoID) }
    }
}

// MARK: - #41

/// O dublê segue `situacao_da_conta` e `contestar_suspensao` (`20261001100000_suspensao_da_conta.sql`).
@Suite("Dublê: conta suspensa (#41)")
struct ContaSuspensaEmMemoriaTests {
    private let relato = "Não estive nesse turno; houve engano de pessoa."

    private func suspensa() -> (ApiClienteEmMemoria, RelogioDeTeste) {
        let relogio = RelogioDeTeste(agoraDoTeste)
        return (ApiClienteEmMemoria(cenario: .contaSuspensa, relogio: relogio), relogio)
    }

    @Test("Conta ativa não tem suspensão, e contestar é sem_suspensao_ativa")
    func contaAtiva() async throws {
        let api = ApiClienteEmMemoria()
        #expect(try await api.situacaoDaConta() == SituacaoDaConta(estado: .ativa, suspensao: nil))
        // A suspensão é conferida antes do relato.
        await #expect(throws: ErroDaApi(codigo: .semSuspensaoAtiva)) { try await api.contestarSuspensao(relato: "") }
    }

    @Test("Conta suspensa lê o motivo e a data da suspensão, mesmo com as outras operações recusadas")
    func contaSuspensa() async throws {
        let (api, _) = suspensa()
        await #expect(throws: ErroDaApi(codigo: .semPermissao, detalhes: "conta_suspensa")) { try await api.funcoes() }

        let situacao = try await api.situacaoDaConta()

        #expect(situacao.estado == .suspensa)
        let suspensao = try #require(situacao.suspensao)
        #expect(!suspensao.motivo.isEmpty)
        #expect(suspensao.desde < agoraDoTeste)
        #expect(suspensao.contestacao == nil)
        #expect(try await api.minhaConta().estado == .suspensa)
    }

    @Test("A contestação devolve o protocolo e passa a aparecer na situação da conta")
    func contestar() async throws {
        let (api, _) = suspensa()

        let protocolo = try await api.contestarSuspensao(relato: relato)

        #expect(protocolo.tipo == .contestacao)
        #expect(protocolo.criadaEm == agoraDoTeste)
        #expect(protocolo.prazoRespostaAte == (try DataCivil("2027-01-22")))
        #expect(try await api.situacaoDaConta().suspensao?.contestacao == protocolo)
    }

    @Test("Com contestação em análise, contestar de novo é contestacao_ja_aberta")
    func contestarDeNovo() async throws {
        let (api, _) = suspensa()
        let protocolo = try await api.contestarSuspensao(relato: relato)
        await #expect(throws: ErroDaApi(codigo: .contestacaoJaAberta)) { try await api.contestarSuspensao(relato: relato) }
        #expect(try await api.situacaoDaConta().suspensao?.contestacao == protocolo)
    }

    @Test("Relato em branco é campo_obrigatorio; com menos de 10 caracteres, campo_invalido")
    func relatoDaContestacao() async throws {
        let (api, _) = suspensa()
        await #expect(throws: ErroDaApi(codigo: .campoObrigatorio, detalhes: "relato")) { try await api.contestarSuspensao(relato: "  ") }
        await #expect(throws: ErroDaApi(codigo: .campoInvalido, detalhes: "relato")) { try await api.contestarSuspensao(relato: "não fui") }
        #expect(try await api.situacaoDaConta().suspensao?.contestacao == nil)
    }

    @Test("Sem rede, a situação da conta e a contestação falham como sem_rede")
    func semRede() async throws {
        let api = ApiClienteEmMemoria(cenario: .semRede)
        await #expect(throws: ErroDaApi(codigo: .semRede)) { try await api.situacaoDaConta() }
        await #expect(throws: ErroDaApi(codigo: .semRede)) { try await api.contestarSuspensao(relato: relato) }
    }
}
