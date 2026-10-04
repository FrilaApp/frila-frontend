import Foundation
import FrilaDominio
import Observation

public struct ItemCompartilhamento: Identifiable, Sendable {
    public var id: URL { url }
    public let url: URL

    public init(url: URL) {
        self.url = url
    }
}

@MainActor @Observable
public final class ExportarDadosViewModel {
    public enum Estado: Equatable, Sendable {
        case ocioso
        case carregando
        case erro(String)
    }

    private let api: any ApiCliente
    private let relogio: any Relogio
    private let diretorioTemporario: URL

    public private(set) var estado: Estado = .ocioso
    public var mostrarFolhaCompartilhamento = false
    public private(set) var arquivoParaCompartilhar: URL?

    public var estaCarregando: Bool {
        estado == .carregando
    }

    public var itemCompartilhamento: ItemCompartilhamento? {
        guard let arquivoParaCompartilhar else { return nil }
        return ItemCompartilhamento(url: arquivoParaCompartilhar)
    }

    public var mensagemErro: String? {
        if case let .erro(msg) = estado {
            return msg
        }
        return nil
    }

    public init(
        api: any ApiCliente,
        relogio: any Relogio = RelogioDoSistema(),
        diretorioTemporario: URL = FileManager.default.temporaryDirectory
    ) {
        self.api = api
        self.relogio = relogio
        self.diretorioTemporario = diretorioTemporario
    }

    public func exportarDados() async {
        guard !estaCarregando else { return }
        limparArquivosTemporariosAntigos()
        estado = .carregando

        do {
            let dados = try await api.exportarMeusDados()
            let urlTemporaria = try gravarArquivoTemporario(dados: dados)
            arquivoParaCompartilhar = urlTemporaria
            mostrarFolhaCompartilhamento = true
            estado = .ocioso
        } catch let erroApi as ErroDaApi {
            arquivoParaCompartilhar = nil
            mostrarFolhaCompartilhamento = false
            estado = .erro(MensagemDoErroAPI.texto(erroApi))
        } catch {
            arquivoParaCompartilhar = nil
            mostrarFolhaCompartilhamento = false
            estado = .erro(MensagemDoErroAPI.texto(ErroDaApi(codigo: .desconhecido)))
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

    private func limparArquivosTemporariosAntigos() {
        guard let itens = try? FileManager.default.contentsOfDirectory(at: diretorioTemporario, includingPropertiesForKeys: nil) else {
            return
        }
        for item in itens {
            if item.lastPathComponent.hasPrefix("frila-meus-dados-") && item.pathExtension == "json" {
                try? FileManager.default.removeItem(at: item)
            }
        }
    }

    private func gravarArquivoTemporario(dados: Data) throws -> URL {
        let formatador = DateFormatter()
        formatador.locale = FormatadorFrila.locale
        formatador.timeZone = FormatadorFrila.fuso
        formatador.dateFormat = "yyyy-MM-dd"
        let dataTexto = formatador.string(from: relogio.agora)
        let nomeArquivo = "frila-meus-dados-\(dataTexto).json"
        let urlArquivo = diretorioTemporario.appendingPathComponent(nomeArquivo)

        try? FileManager.default.removeItem(at: urlArquivo)
        // O arquivo reúne tudo o que o servidor sabe da pessoa. Fica cifrado com o aparelho bloqueado
        // (classe completa): a folha de compartilhar só o lê com o app na frente e o aparelho aberto.
        try dados.write(to: urlArquivo, options: [.atomic, .completeFileProtection])
        return urlArquivo
    }
}
