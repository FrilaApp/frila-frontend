import Foundation
import FrilaDominio
import Observation

/// Check-in e check-out de um turno (#17, RF13, RN22). A localização é lida só no toque; o app mede
/// a distância até o ponto da vaga e manda só a distância, com o instante do toque. Sem GPS que
/// sirva, a saída é o registro manual. Sem rede, a ação entra na fila offline (#111).
@MainActor @Observable
public final class PresencaDoTurnoViewModel {
    public enum Registro: String, Equatable, Sendable {
        case checkin
        case checkout
    }

    /// Por que o GPS não serviu. Em todos os casos a tela oferece o registro manual.
    public enum MotivoSemGPS: Equatable, Sendable {
        case permissaoNegada
        case localizacaoAproximada
        /// Falha da leitura ou os 10 segundos esgotados sem posição.
        case semSinal
        case imprecisa
        /// Só no check-in: a mais de 200 m. O check-out não tem teto de distância.
        case longe(distanciaMetros: Int)
        /// A tela abriu sem rede e o ponto da vaga não chegou: não há o que medir.
        case enderecoIndisponivel
    }

    public enum Etapa: Equatable, Sendable {
        case parada
        /// Explicação antes do pedido de permissão do sistema.
        case explicando(Registro)
        case lendo(Registro)
        case enviando(Registro)
        case semGPS(Registro, MotivoSemGPS)
    }

    public struct RegistroFeito: Equatable, Sendable {
        public let instante: Date
        public let distanciaMetros: Int?
        /// Check-in sem prova do GPS: depende da confirmação do contratante.
        public let manual: Bool

        public init(instante: Date, distanciaMetros: Int?, manual: Bool) {
            self.instante = instante
            self.distanciaMetros = distanciaMetros
            self.manual = manual
        }
    }

    public enum Situacao: Equatable, Sendable {
        case naoFeito
        /// Guardado na fila deste aparelho; sobe quando a conexão voltar, com o instante do toque.
        case naFila(RegistroFeito)
        case registrado(RegistroFeito)
    }

    public let turno: Turno
    public private(set) var etapa: Etapa = .parada
    public private(set) var checkin: Situacao
    public private(set) var checkout: Situacao
    public private(set) var verificacao: Verificacao
    public private(set) var mensagemDeErro: String?

    private let api: any ApiCliente
    private let localizacao: any LeitorDeLocalizacao
    private let fila: (any FilaDeAcoes)?
    private let relogio: any Relogio
    private let aoRegistrar: @MainActor () -> Void
    private var pontoDaVaga: Coordenada?
    private var toque: Date?

    public init(
        turno: Turno,
        api: any ApiCliente,
        localizacao: any LeitorDeLocalizacao,
        fila: (any FilaDeAcoes)? = nil,
        relogio: any Relogio = RelogioDoSistema(),
        pontoDaVaga: Coordenada? = nil,
        aoRegistrar: @escaping @MainActor () -> Void = {}
    ) {
        self.turno = turno
        self.api = api
        self.localizacao = localizacao
        self.fila = fila
        self.relogio = relogio
        self.pontoDaVaga = pontoDaVaga
        self.aoRegistrar = aoRegistrar
        checkin = turno.checkin.map { .registrado(RegistroFeito(instante: $0.instante, distanciaMetros: $0.distanciaMetros, manual: $0.tipo == .manual)) } ?? .naoFeito
        checkout = turno.checkout.map { .registrado(RegistroFeito(instante: $0.instante, distanciaMetros: $0.distanciaMetros, manual: false)) } ?? .naoFeito
        verificacao = turno.verificacao
    }

    public var ocupado: Bool {
        switch etapa {
        case .lendo, .enviando: true
        case .parada, .explicando, .semGPS: false
        }
    }

    public var podeFazerCheckin: Bool { checkin == .naoFeito }

    /// O check-out vem depois do check-in, mesmo que o check-in ainda esteja na fila: a fila sai na
    /// ordem dos toques.
    public var podeFazerCheckout: Bool { checkin != .naoFeito && checkout == .naoFeito }

    /// Check-in manual já no servidor, à espera do contratante (`confirmar_checkin_manual`).
    public var aguardandoConfirmacao: Bool {
        guard case let .registrado(feito) = checkin else { return false }
        return feito.manual && verificacao == .pendente
    }

    /// O ponto vem do detalhe da vaga, que a tela do turno já carrega; `meus_turnos` não o traz.
    public func definir(pontoDaVaga: Coordenada) {
        self.pontoDaVaga = pontoDaVaga
    }

    /// O que ficou na fila num toque anterior volta a aparecer como pendente ao reabrir a tela.
    public func restaurarPendentes() async {
        guard let fila, let pendentes = try? await fila.pendentes() else { return }
        let recusadas = (try? await fila.recusadas(incluirReconhecidas: true)) ?? []
        let entradaSaiu = !pendentes.contains { $0.tipo == .checkin && $0.turnoID == turno.id }
        let saidaSaiu = !pendentes.contains { $0.tipo == .checkout && $0.turnoID == turno.id }
        // Ausência na fila não prova recusa: o servidor pode ter aceitado esse registro.
        if (entradaSaiu && estaNaFila(checkin)) || (saidaSaiu && estaNaFila(checkout)) {
            let atualizado = try? await api.meusTurnos().first { $0.id == turno.id }
            if let atualizado { verificacao = atualizado.verificacao }
            if entradaSaiu, case .naFila = checkin {
                if let registro = atualizado?.checkin {
                    checkin = .registrado(.init(instante: registro.instante, distanciaMetros: registro.distanciaMetros, manual: registro.tipo == .manual))
                } else if recusadas.contains(where: { $0.tipo == .checkin && $0.turnoID == turno.id }) {
                    checkin = .naoFeito
                }
            }
            if saidaSaiu, case .naFila = checkout {
                if let registro = atualizado?.checkout {
                    checkout = .registrado(.init(instante: registro.instante, distanciaMetros: registro.distanciaMetros, manual: false))
                } else if recusadas.contains(where: { $0.tipo == .checkout && $0.turnoID == turno.id }) {
                    checkout = .naoFeito
                }
            }
            // Sem leitura nem recusa confirmada, conserva a indicação local até poder conferir.
        }
        for acao in pendentes where acao.turnoID == turno.id {
            let feito = RegistroFeito(instante: acao.instanteDoToque, distanciaMetros: acao.distanciaMetros, manual: acao.distanciaMetros == nil)
            switch acao.tipo {
            case .checkin where checkin == .naoFeito: checkin = .naFila(feito)
            case .checkout where checkout == .naoFeito: checkout = .naFila(feito)
            default: break
            }
        }
    }

    private func estaNaFila(_ situacao: Situacao) -> Bool {
        if case .naFila = situacao { return true }
        return false
    }

    /// Toque em "Fazer check-in" ou "Fazer check-out". O instante do registro é o deste toque.
    public func iniciar(_ registro: Registro) async {
        guard !ocupado, pode(registro) else { return }
        mensagemDeErro = nil
        toque = relogio.agora
        // Ocupado antes do primeiro `await`: o segundo toque de um toque duplo para na guarda acima.
        etapa = .lendo(registro)
        if await localizacao.permissao() == .naoDeterminada {
            etapa = .explicando(registro)
        } else {
            await lerEEnviar(registro)
        }
    }

    /// Toque em "Continuar" na explicação: só aqui o sistema pergunta pela permissão "ao usar".
    public func continuarComPermissao() async {
        guard case let .explicando(registro) = etapa else { return }
        etapa = .lendo(registro)
        _ = await localizacao.pedirPermissao()
        await lerEEnviar(registro)
    }

    /// Nova tentativa pelo GPS depois de uma falha. É um toque novo, com instante novo.
    public func tentarGPSDeNovo() async {
        guard case let .semGPS(registro, _) = etapa else { return }
        etapa = .parada
        await iniciar(registro)
    }

    /// Check-in manual, ou saída sem localização: vai sem distância, com o instante deste toque.
    public func registrarSemGPS() async {
        guard case let .semGPS(registro, _) = etapa, pode(registro) else { return }
        mensagemDeErro = nil
        await enviar(registro, distanciaMetros: nil, toque: relogio.agora)
    }

    public func cancelar() {
        guard !ocupado else { return }
        etapa = .parada
    }

    private func pode(_ registro: Registro) -> Bool {
        switch registro {
        case .checkin: podeFazerCheckin
        case .checkout: podeFazerCheckout
        }
    }

    private func lerEEnviar(_ registro: Registro) async {
        guard let toque else { return }
        etapa = .lendo(registro)
        // Sem o ponto da vaga não há distância para medir: o GPS nem é ligado.
        guard let ponto = await pontoDaVagaOuBuscar() else {
            etapa = .semGPS(registro, .enderecoIndisponivel)
            return
        }
        var permissao = await localizacao.permissao()
        if permissao == .aoUsarAproximada {
            permissao = await localizacao.pedirPrecisaoTemporaria(chave: RegraDePresenca.chaveDaPrecisaoTemporaria)
        }
        switch permissao {
        case .naoDeterminada, .negada:
            etapa = .semGPS(registro, .permissaoNegada)
            return
        case .aoUsarAproximada:
            etapa = .semGPS(registro, .localizacaoAproximada)
            return
        case .aoUsarPrecisa:
            break
        }

        let leitura: LeituraDeLocalizacao
        do {
            leitura = try await localizacao.lerUmaVez(
                tempoLimite: RegraDePresenca.tempoLimiteDaLeitura,
                precisaoSuficienteMetros: RegraDePresenca.precisaoHorizontalMaximaMetros
            )
        } catch {
            etapa = .semGPS(registro, error == .permissaoNegada ? .permissaoNegada : .semSinal)
            return
        }
        guard leitura.precisaoHorizontalMetros <= RegraDePresenca.precisaoHorizontalMaximaMetros else {
            etapa = .semGPS(registro, .imprecisa)
            return
        }
        // A coordenada morre aqui: daqui em diante só existe a distância, inteira, em metros.
        let distancia = Int(leitura.coordenada.distancia(emMetrosDe: ponto).rounded())
        if registro == .checkin, distancia > RegraDePresenca.distanciaMaximaDoCheckinMetros {
            etapa = .semGPS(registro, .longe(distanciaMetros: distancia))
            return
        }
        await enviar(registro, distanciaMetros: distancia, toque: toque)
    }

    private func pontoDaVagaOuBuscar() async -> Coordenada? {
        if let pontoDaVaga { return pontoDaVaga }
        pontoDaVaga = try? await api.detalheDaVaga(id: turno.vaga.id).ponto
        return pontoDaVaga
    }

    private func enviar(_ registro: Registro, distanciaMetros: Int?, toque: Date) async {
        etapa = .enviando(registro)
        defer { etapa = .parada }
        do {
            let resultado = switch registro {
            case .checkin: try await api.fazerCheckin(turnoID: turno.id, distanciaMetros: distanciaMetros, registradoEm: toque)
            case .checkout: try await api.fazerCheckout(turnoID: turno.id, distanciaMetros: distanciaMetros, registradoEm: toque)
            }
            // O servidor é quem diz o que ficou gravado: reenviar devolve o registro anterior.
            let feito = RegistroFeito(instante: resultado.registradoEm, distanciaMetros: resultado.distanciaMetros, manual: resultado.tipo == .manual)
            switch registro {
            case .checkin: checkin = .registrado(feito)
            case .checkout: checkout = .registrado(RegistroFeito(instante: feito.instante, distanciaMetros: feito.distanciaMetros, manual: false))
            }
            verificacao = resultado.verificacao
            try? await fila?.resolverRecusas(AcaoPendente(
                tipo: registro == .checkin ? .checkin : .checkout, turnoID: turno.id,
                instanteDoToque: toque, chave: UUID()
            ))
            aoRegistrar()
        } catch let erro as ErroDaApi where erro.codigo == .semRede {
            await guardarNaFila(registro, distanciaMetros: distanciaMetros, toque: toque)
        } catch let erro as ErroDaApi {
            mensagemDeErro = Self.mensagem(erro)
        } catch {
            mensagemDeErro = TextosDoProfissional.Presenca.falhaAoEnviar
        }
    }

    private func guardarNaFila(_ registro: Registro, distanciaMetros: Int?, toque: Date) async {
        guard let fila else {
            mensagemDeErro = TextosDoProfissional.Lista.semConexaoMensagem
            return
        }
        let acao = AcaoPendente(
            tipo: registro == .checkin ? .checkin : .checkout,
            turnoID: turno.id,
            instanteDoToque: toque,
            chave: UUID(),
            distanciaMetros: distanciaMetros
        )
        do {
            try await fila.enfileirar(acao)
        } catch {
            mensagemDeErro = TextosDoProfissional.Presenca.falhaAoGuardar
            return
        }
        let feito = RegistroFeito(instante: toque, distanciaMetros: distanciaMetros, manual: distanciaMetros == nil)
        switch registro {
        case .checkin: checkin = .naFila(feito)
        case .checkout: checkout = .naFila(feito)
        }
    }

    private static func mensagem(_ erro: ErroDaApi) -> String {
        switch erro.codigo {
        case .foraDaJanela: TextosDoProfissional.Presenca.foraDaJanela
        case .registroNoFuturo: TextosDoProfissional.Presenca.relogioAdiantado
        default: MensagemDoErroAPI.texto(erro)
        }
    }
}
