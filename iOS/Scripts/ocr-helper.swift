import Cocoa
import Vision

guard CommandLine.arguments.count > 1 else {
    fputs("Uso: ocr-helper <caminho_imagem>\n", stderr)
    exit(1)
}

let caminho = CommandLine.arguments[1]
let url = URL(fileURLWithPath: caminho)
guard let image = NSImage(contentsOf: url),
      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("Erro ao carregar imagem: \(caminho)\n", stderr)
    exit(1)
}

let request = VNRecognizeTextRequest { (request, error) in
    guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
    for observation in observations {
        if let topCandidate = observation.topCandidates(1).first {
            print(topCandidate.string)
        }
    }
}
request.recognitionLevel = .accurate

let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
do {
    try handler.perform([request])
} catch {
    fputs("Erro ao executar OCR: \(error.localizedDescription)\n", stderr)
    exit(1)
}
