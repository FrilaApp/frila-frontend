import Foundation
import Testing

struct ReproContratanteNovoTests {
    @Test("Reprodução da causa raiz (build 0.4.0): o caminho do diretório Frila obtido por path() deve ser acessível no sistema de arquivos")
    func caminhoDoDiretorioFrilaDeveSerAcessivelNoSistemaDeArquivos() throws {
        let suporte = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let diretorio = suporte.appending(path: "Frila", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: diretorio, withIntermediateDirectories: true)

        // No build 0.4.0 (CacheSwiftData.swift:156), usava-se:
        // ofItemAtPath: diretorio.path()
        // O método URL.path() possui valor default percentEncoded: true no Foundation moderno.
        // Como o diretório 'Application Support' contém espaço, o caminho gerado contém '%20'
        // (.../Library/Application%20Support/Frila/).
        // As APIs do FileManager esperam caminhos literais do sistema de arquivos (POSIX raw path)
        // e não realizam decodificação de percent-encoding.
        //
        // Este teste verifica se o caminho obtido por diretorio.path() pode ser resolvido pelo sistema de arquivos.
        // Sob a implementação do build 0.4.0, a chamada attributesOfItem(atPath:) falha com CocoaError 260 / POSIX 2
        // ("No such file or directory"), comprovando a falha de persistência que tornava o armazenamento nulo.
        let caminhoUsadoNoBuild040 = diretorio.path()
        let atributos = try FileManager.default.attributesOfItem(atPath: caminhoUsadoNoBuild040)
        #expect(!atributos.isEmpty)
    }
}
