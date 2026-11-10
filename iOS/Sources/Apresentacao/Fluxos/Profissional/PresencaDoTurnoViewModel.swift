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
    /// A última permissão de localização que o app viu, para avisar antes do toque quando só a
    /// aproximada foi concedida. `nil` até a primeira leitura.
    public private(set) var permissaoDaLocalizacao: PermissaoDeLocalizacao?
    /// A chave `checkin_por_codigo` do servidor, já lida (`carregarRecursos`). Desligada, nada do código aparece.
    public private(set) var checkinPorCodigoLigado = false
    /// `codigo_disponivel` do último `fazer_checkin`; `nil` enquanto o app não o viu.
    public private(set) var codigoDisponivel: Bool?
    /// O caminho do código fechou para este turno (`codigo_bloqueado` `encerrado`): vale a confirmação manual da casa.
    public private(set) var caminhoDoCodigoEncerrado = false

    private let api: any ApiCliente
    private let localizacao: any LeitorDeLocalizacao
    private let fila: (any FilaDeAcoes)?
    private let relogio: any Relogio
    private let telemetria: RegistradorDeTelemetria?
    private let cache: CacheDeLeituras?
    private let aoRegistrar: @MainActor () -> Void
    /// Os recursos do servidor, lidos só na hora de montar o check-in com leitura de GPS. Os `sinais` do
    /// check-in por código só saem com `checkinPorCodigo` ligado (0.2.68); por padrão, desligado.
    private let recursos: @Sendable () async -> RecursosDoApp
    /// Os recursos, lidos uma vez por abertura da tela do turno (os `sinais` e as telas do código usam a mesma leitura).
    private var recursosLidos: RecursosDoApp?
    private var pontoDaVaga: Coordenada?
    private var toque: Date?
    private var jaEmitiuCheckinConcluido = false
    private var jaEmitiuCheckoutConcluido = false
    private var jaEmitiuEnfileiramento = false

    public init(
        turno: Turno,
        api: any ApiCliente,
        localizacao: any LeitorDeLocalizacao,
        fila: (any FilaDeAcoes)? = nil,
        relogio: any Relogio = RelogioDoSistema(),
        pontoDaVaga: Coordenada? = nil,
        aoRegistrar: @escaping @MainActor () -> Void = {},
        telemetria: RegistradorDeTelemetria? = nil,
        cache: CacheDeLeituras? = nil,
        recursos: @escaping @Sendable () async -> RecursosDoApp = { .desligados }
    ) {
        self.recursos = recursos
        self.cache = cache
        self.turno = turno
        self.api = api
        self.localizacao = localizacao
        self.fila = fila
        self.relogio = relogio
        self.pontoDaVaga = pontoDaVaga
        self.aoRegistrar = aoRegistrar
        self.telemetria = telemetria ?? RegistradorDeTelemetria(api: api)
        checkin = turno.checkin.map { .registrado(RegistroFeito(instante: $0.instante, distanciaMetros: $0.distanciaMetros, manual: $0.tipo == .manual)) } ?? .naoFeito
        checkout = turno.checkout.map { .registrado(RegistroFeito(instante: $0.instante, distanciaMetros: $0.distanciaMetros, manual: false)) } ?? .naoFeito
        verificacao = turno.verificacao
    }

    /// Lê a chave do servidor uma vez e a guarda: `checkin_por_codigo` liga os sinais e as telas do código.
    public func carregarRecursos() async {
        checkinPorCodigoLigado = await recursosDoApp().checkinPorCodigo
    }

    private func recursosDoApp() async -> RecursosDoApp {
        if let recursosLidos { return recursosLidos }
        let lidos = await recursos()
        recursosLidos = lidos
        return lidos
    }

    /// Check-in feito e ainda pendente, com a chave ligada e o caminho do código aberto: a tela oferece a
    /// leitura do código da casa, ao lado do aviso de que a casa também pode confirmar a chegada.
    public var podeLerOCodigo: Bool {
        guard checkinPorCodigoLigado, verificacao == .pendente, codigoDisponivel != false, !caminhoDoCodigoEncerrado else { return false }
        if case .registrado = checkin { return true }
        return false
    }

    /// A validação deu certo: a presença fica verificada pelo código, e a tela do turno é relida.
    public func aoValidarOCodigo(_ registro: ResultadoRegistro) {
        verificacao = registro.verificacao
        checkin = .registrado(RegistroFeito(instante: registro.registradoEm, distanciaMetros: nil, manual: false))
        aoRegistrar()
    }

    /// `checkin_ja_confirmado`: outra leitura ou a casa chegou antes. Relê o turno, que já vem verificado.
    public func aoJaVerificadoPeloCodigo() { aoRegistrar() }

    /// O caminho do código fechou: some a leitura, e fica a confirmação manual da casa.
    public func aoEncerrarOCaminhoDoCodigo() { caminhoDoCodigoEncerrado = true }

    /// A distância até o ponto da vaga, medida agora, para a validação do código. `nil` sem posição
    /// (permissão que não é a precisa, GPS sem sinal, ponto da vaga indisponível): o servidor valida e marca
    /// o turno de confiança baixa. A imprecisão da leitura não desconta, como no servidor.
    public func medirDistanciaParaOCodigo() async -> Int? {
        guard await localizacao.permissao() == .aoUsarPrecisa, let ponto = await pontoDaVagaOuBuscar() else { return nil }
        guard let leitura = try? await localizacao.lerUmaVez(
            tempoLimite: RegraDePresenca.tempoLimiteDaLeitura, precisaoSuficienteMetros: RegraDePresenca.precisaoHorizontalMaximaMetros
        ) else { return nil }
        return Int(leitura.coordenada.distancia(emMetrosDe: ponto).rounded())
    }

    /// A leitura do código deste turno, com a medição da distância ligada ao leitor de localização.
    public func criarValidacaoDoCodigo() -> ValidacaoDoCodigoViewModel {
        ValidacaoDoCodigoViewModel(turnoID: turno.id, api: api, medirDistancia: { [weak self] in await self?.medirDistanciaParaOCodigo() })
    }

    public var ocupado: Bool {
        switch etapa {
        case .lendo, .enviando: true
        case .parada, .explicando, .semGPS: false
        }
    }

    public var podeFazerCheckin: Bool {
        guard checkin == .naoFeito else { return false }
        let agora = relogio.agora
        let inicio = turno.vaga.periodo.inicio
        let fim = turno.vaga.periodo.fim
        return agora >= inicio.addingTimeInterval(-60 * 60) && agora <= fim
    }

    /// O check-in abre 60 minutos antes do início previsto do turno. Antes disso o botão fica
    /// desabilitado e a tela exibe aviso informativo (LOJA-M2).
    public var checkinAntecipadoDemais: Bool {
        checkin == .naoFeito && relogio.agora < turno.vaga.periodo.inicio.addingTimeInterval(-60 * 60)
    }

    /// O check-out vem depois do check-in, mesmo que o check-in ainda esteja na fila: a fila sai na
    /// ordem dos toques.
    public var podeFazerCheckout: Bool { checkin != .naoFeito && checkout == .naoFeito }

    /// Check-in manual já no servidor, à espera do contratante (`confirmar_checkin_manual`).
    public var aguardandoConfirmacao: Bool {
        guard case let .registrado(feito) = checkin else { return false }
        return feito.manual && verificacao == .pendente
    }

    /// Com a localização aproximada concedida, o app avisa antes do toque que vai pedir a precisa:
    /// sem ela não há como medir os 200 m do check-in (RN22, decisão A11 da PO).
    public var pedePrecisaoAntes: Bool {
        permissaoDaLocalizacao == .aoUsarAproximada && etapa == .parada && (podeFazerCheckin || podeFazerCheckout)
    }

    /// Relê a permissão do sistema. A tela chama ao abrir e quando o app volta dos Ajustes.
    public func atualizarPermissaoDaLocalizacao() async {
        permissaoDaLocalizacao = await localizacao.permissao()
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
        if registro == .checkin {
            await telemetria?.registrar(.checkinTentado, turnoID: turno.id)
        }
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
        permissaoDaLocalizacao = permissao
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
        await enviar(registro, distanciaMetros: distancia, toque: toque, leitura: leitura)
    }

    private func pontoDaVagaOuBuscar() async -> Coordenada? {
        if let pontoDaVaga { return pontoDaVaga }
        let api = self.api
        let vagaID = turno.vaga.id
        let buscar: @Sendable () async throws -> Vaga = { try await api.detalheDaVaga(id: vagaID) }
        let vaga = if let cache { try? await cache.detalhe(id: vagaID, buscar: buscar) } else { try? await buscar() }
        pontoDaVaga = vaga?.ponto
        return pontoDaVaga
    }

    /// Os sinais da leitura, só no check-in com leitura e com a chave `checkin_por_codigo` ligada. Sem a
    /// chave, nada é coletado nem enviado: o corpo do check-in é o de hoje.
    private func sinais(de leitura: LeituraDeLocalizacao?, para registro: Registro) async -> SinaisDoCheckin? {
        guard registro == .checkin, let leitura, await recursosDoApp().checkinPorCodigo else { return nil }
        return SinaisDoCheckin(leitura: leitura)
    }

    private func enviar(_ registro: Registro, distanciaMetros: Int?, toque: Date, leitura: LeituraDeLocalizacao? = nil) async {
        etapa = .enviando(registro)
        defer { etapa = .parada }
        do {
            let sinaisDoToque = await sinais(de: leitura, para: registro)
            let resultado = switch registro {
            case .checkin: try await api.fazerCheckin(turnoID: turno.id, distanciaMetros: distanciaMetros, registradoEm: toque, sinais: sinaisDoToque)
            case .checkout: try await api.fazerCheckout(turnoID: turno.id, distanciaMetros: distanciaMetros, registradoEm: toque)
            }
            // O servidor é quem diz o que ficou gravado: reenviar devolve o registro anterior.
            let feito = RegistroFeito(instante: resultado.registradoEm, distanciaMetros: resultado.distanciaMetros, manual: resultado.tipo == .manual)
            switch registro {
            case .checkin:
                checkin = .registrado(feito)
                codigoDisponivel = resultado.codigoDisponivel
                if !jaEmitiuCheckinConcluido {
                    jaEmitiuCheckinConcluido = true
                    await telemetria?.registrar(.checkinConcluido, turnoID: turno.id, ocorridoEm: feito.instante)
                }
            case .checkout:
                checkout = .registrado(RegistroFeito(instante: feito.instante, distanciaMetros: feito.distanciaMetros, manual: false))
                if !jaEmitiuCheckoutConcluido {
                    jaEmitiuCheckoutConcluido = true
                    await telemetria?.registrar(.checkoutConcluido, turnoID: turno.id, ocorridoEm: feito.instante)
                }
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
            if !jaEmitiuEnfileiramento {
                jaEmitiuEnfileiramento = true
                await telemetria?.registrar(.acaoEnfileiradaOffline, turnoID: turno.id, ocorridoEm: toque)
            }
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
