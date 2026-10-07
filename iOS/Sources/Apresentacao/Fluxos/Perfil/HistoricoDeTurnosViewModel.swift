import Foundation
import FrilaDominio
import Observation

/// Histórico e exportação de turnos (cartão #23, US20, UC13), nos dois perfis. Sem
/// `estabelecimentoID`, o servidor usa os turnos de quem chama como profissional; o contratante
/// manda o do estabelecimento dele. O período é de dias de São Paulo, inteiros.
@MainActor @Observable
public final class HistoricoDeTurnosViewModel {
    public enum Atalho: CaseIterable, Sendable {
        case esteMes
        case mesPassado
        case intervalo
    }

    public enum Estado: Equatable, Sendable {
        case ocioso
        case carregando
        /// O 204: o período não tem turnos, e nada vai para o compartilhar (UC13, 1a).
        case semTurnos
        /// `repetivel` é falso quando tentar de novo não muda nada: sessão vencida ou sem permissão.
        case erro(mensagem: String, repetivel: Bool)

        public var ehErro: Bool {
            if case .erro = self { true } else { false }
        }
    }

    private let api: any ApiCliente
    private let estabelecimentoID: UUID?
    private let relogio: any Relogio
    private let diretorioTemporario: URL

    public private(set) var atalho: Atalho = .esteMes
    public private(set) var formato: FormatoExportacao = .csv
    /// Os dois seletores do intervalo livre. Cada um vale pelo dia de São Paulo em que cai.
    public private(set) var inicioEscolhido: Date
    public private(set) var fimEscolhido: Date
    public private(set) var estado: Estado = .ocioso
    public var mostrarFolhaCompartilhamento = false
    public private(set) var arquivoParaCompartilhar: URL?

    public init(
        api: any ApiCliente,
        estabelecimentoID: UUID? = nil,
        relogio: any Relogio = RelogioDoSistema(),
        diretorioTemporario: URL = FileManager.default.temporaryDirectory
    ) {
        self.api = api
        self.estabelecimentoID = estabelecimentoID
        self.relogio = relogio
        self.diretorioTemporario = diretorioTemporario
        let agora = relogio.agora
        fimEscolhido = agora
        inicioEscolhido = DataCivil.deSaoPaulo(agora).map { PeriodoDeExportacao.esteMes(hoje: $0).inicio } ?? agora
    }

    public var agora: Date { relogio.agora }

    public var estaCarregando: Bool { estado == .carregando }

    /// O período que vai para o servidor, ou nil para datas inválidas ou janela acima de 30 dias.
    /// O botão Exportar fica desabilitado enquanto for nil.
    public var periodo: PeriodoDeExportacao? {
        guard let periodo = periodoEscolhido, !periodo.excedeLimite else { return nil }
        return periodo
    }

    public var excedeLimite: Bool { periodoEscolhido?.excedeLimite == true }

    private var periodoEscolhido: PeriodoDeExportacao? {
        guard let hoje = DataCivil.deSaoPaulo(relogio.agora) else { return nil }
        switch atalho {
        case .esteMes:
            return .esteMes(hoje: hoje)
        case .mesPassado:
            return .mesPassado(hoje: hoje)
        case .intervalo:
            guard let de = DataCivil.deSaoPaulo(inicioEscolhido), let ate = DataCivil.deSaoPaulo(fimEscolhido),
                  ate <= hoje else { return nil }
            return try? PeriodoDeExportacao(de: de, ate: ate)
        }
    }

    public func escolher(_ atalho: Atalho) {
        self.atalho = atalho
        esquecerResultado()
    }

    public func escolher(formato: FormatoExportacao) {
        self.formato = formato
        esquecerResultado()
    }

    /// Mantém o início antes do fim: puxar o início para depois do fim leva o fim junto.
    public func escolher(inicio: Date) {
        inicioEscolhido = min(inicio, relogio.agora)
        if fimEscolhido < inicioEscolhido { fimEscolhido = inicioEscolhido }
        esquecerResultado()
    }

    /// O fim nunca passa de hoje; puxá-lo para antes do início leva o início junto.
    public func escolher(fim: Date) {
        fimEscolhido = min(fim, relogio.agora)
        if inicioEscolhido > fimEscolhido { inicioEscolhido = fimEscolhido }
        esquecerResultado()
    }

    public func exportar() async {
        guard !estaCarregando, let periodo else { return }
        let formato = formato
        limparArquivosAntigos()
        estado = .carregando
        do {
            let pedido = PedidoExportacaoTurnos(periodo: periodo, formato: formato, estabelecimentoID: estabelecimentoID)
            switch try await api.exportarTurnos(pedido) {
            case .semTurnos:
                estado = .semTurnos
            case let .arquivo(dados):
                arquivoParaCompartilhar = try gravar(dados, nome: Self.nomeDoArquivo(periodo: periodo, formato: formato))
                mostrarFolhaCompartilhamento = true
                estado = .ocioso
            }
        } catch let erro as ErroDaApi {
            estado = .erro(
                mensagem: erro.codigo == .intervaloMaximoExcedido ? TextosHistoricoDeTurnos.intervaloMaximoExcedido : MensagemDoErroAPI.texto(erro),
                repetivel: erro.codigo != .naoAutenticado && erro.codigo != .semPermissao && erro.codigo != .intervaloMaximoExcedido
            )
        } catch {
            // Só a gravação do arquivo temporário chega aqui; a API sempre lança `ErroDaApi`.
            estado = .erro(mensagem: MensagemDoErroAPI.texto(ErroDaApi(codigo: .desconhecido)), repetivel: true)
        }
    }

    public func atividadeCompartilhamentoConcluida(concluida: Bool) {
        guard concluida else { return }
        folhaCompartilhamentoFechada()
    }

    public func folhaCompartilhamentoFechada() {
        if let url = arquivoParaCompartilhar {
            try? FileManager.default.removeItem(at: url)
        }
        arquivoParaCompartilhar = nil
        mostrarFolhaCompartilhamento = false
    }

    /// `frila-turnos-AAAA-MM-DD_AAAA-MM-DD.csv` ou `.pdf`, com os dias de São Paulo do período.
    public static func nomeDoArquivo(periodo: PeriodoDeExportacao, formato: FormatoExportacao) -> String {
        "\(prefixo)\(periodo.de.contrato)_\(periodo.ate.contrato).\(formato.rawValue)"
    }

    private static let prefixo = "frila-turnos-"

    /// O aviso de "sem turnos" ou de erro fala do pedido anterior: mudou o pedido, ele sai.
    private func esquecerResultado() {
        switch estado {
        case .semTurnos, .erro: estado = .ocioso
        case .ocioso, .carregando: break
        }
    }

    private func limparArquivosAntigos() {
        guard let itens = try? FileManager.default.contentsOfDirectory(at: diretorioTemporario, includingPropertiesForKeys: nil) else {
            return
        }
        let extensoes = Set(FormatoExportacao.allCases.map(\.rawValue))
        for item in itens where item.lastPathComponent.hasPrefix(Self.prefixo) && extensoes.contains(item.pathExtension) {
            try? FileManager.default.removeItem(at: item)
        }
    }

    private func gravar(_ dados: Data, nome: String) throws -> URL {
        let url = diretorioTemporario.appendingPathComponent(nome)
        try? FileManager.default.removeItem(at: url)
        // Endereços, nomes e valores dos turnos: cifrado com o aparelho bloqueado, como o JSON de
        // "meus dados" (auditoria de 03/10/2026, A3).
        try dados.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
}
