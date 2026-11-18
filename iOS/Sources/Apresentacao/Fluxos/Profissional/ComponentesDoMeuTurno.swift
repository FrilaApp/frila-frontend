import SwiftUI

/// Textos do selo e da linha de etapas do turno. As chaves seguem o texto em pt-BR, como o resto do catálogo.
extension TextosDoProfissional.Turnos {
    static let etapaConfirmado = String(localized: "Confirmado", bundle: bundleApresentacao)
    static let etapaACaminho = String(localized: "A caminho", bundle: bundleApresentacao)
    static let etapaConcluido = String(localized: "Concluído", bundle: bundleApresentacao)
    /// O selo diz o fato ("Presença marcada"); a etapa da linha continua "Presença" (DESIGN.md, Selos de status).
    static let seloPresencaMarcada = String(localized: "Presença marcada", bundle: bundleApresentacao)
    static let etapasDoTurno = String(localized: "Etapas do turno", bundle: bundleApresentacao)
    static let etapaAtual = String(localized: "Etapa atual", bundle: bundleApresentacao)
    static let etapaFeita = String(localized: "Etapa feita", bundle: bundleApresentacao)
    static let etapaQueFalta = String(localized: "Etapa que falta", bundle: bundleApresentacao)
}

/// As quatro etapas do turno, na ordem em que acontecem (DESIGN.md do protótipo, "Linha de etapas").
enum EtapaDoTurno: Int, CaseIterable, Sendable {
    case confirmado, aCaminho, presenca, concluido

    var rotulo: String {
        switch self {
        case .confirmado: TextosDoProfissional.Turnos.etapaConfirmado
        case .aCaminho: TextosDoProfissional.Turnos.etapaACaminho
        case .presenca: TextosDoProfissional.Presenca.titulo
        case .concluido: TextosDoProfissional.Turnos.etapaConcluido
        }
    }

    /// A etapa em que o turno está: a mais adiantada que já aconteceu.
    static func atual(aCaminho: Bool, presenca: Bool, concluido: Bool) -> EtapaDoTurno {
        if concluido { return .concluido }
        if presenca { return .presenca }
        if aCaminho { return .aCaminho }
        return .confirmado
    }

    /// As etapas que de fato aconteceram. "A caminho" fica de fora quando a presença veio sem o aviso: a linha não a
    /// conta como feita.
    static func feitas(aCaminho: Bool, presenca: Bool, concluido: Bool) -> Set<EtapaDoTurno> {
        var feitas: Set<EtapaDoTurno> = [.confirmado]
        if aCaminho { feitas.insert(.aCaminho) }
        if presenca || concluido { feitas.insert(.presenca) }
        if concluido { feitas.insert(.concluido) }
        return feitas
    }

    /// O selo do card de status: o nome da etapa atual (a exceção é "Presença marcada").
    var selo: (titulo: String, estilo: SeloDeStatus.Estilo, icone: String?) {
        switch self {
        case .confirmado:
            return (TextosDoProfissional.Turnos.etapaConfirmado, .destaque, "checkmark")
        case .aCaminho:
            return (TextosDoProfissional.Turnos.etapaACaminho, .andamento, nil)
        case .presenca:
            return (TextosDoProfissional.Turnos.seloPresencaMarcada, .andamento, nil)
        case .concluido:
            return (TextosDoProfissional.Turnos.etapaConcluido, .contorno, nil)
        }
    }
}

/// Linha de etapas do card de status (T4, T8, T5, T7b): um marcador de 12 pt por etapa, ligado ao seguinte por um
/// traço de 2 pt. Feitas e atual: marcador cheio em tinta; o traço é tinta só até a etapa atual. Etapas que faltam:
/// marcador em contorno. A atual leva o rótulo em 600, e a leitura de tela diz qual é a atual. Com texto grande a
/// linha vira uma coluna, para o rótulo não cortar.
struct LinhaDeEtapas: View {
    let feitas: Set<EtapaDoTurno>
    let atual: EtapaDoTurno
    @Environment(\.dynamicTypeSize) private var tamanhoDoTexto
    @ScaledMetric(relativeTo: .footnote) private var marcador: CGFloat = 12

    var body: some View {
        Group {
            if tamanhoDoTexto >= .xxxLarge {
                emColuna
            } else {
                emLinha
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: TextosDoProfissional.Turnos.etapasDoTurno))
        .accessibilityIdentifier("linha-de-etapas")
    }

    private var emLinha: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(EtapaDoTurno.allCases, id: \.self) { etapa in
                VStack(spacing: FrilaEspaco.item) {
                    HStack(spacing: 0) {
                        traco(cheio: etapa.rawValue <= atual.rawValue, visivel: etapa != .confirmado)
                        ponto(etapa)
                        traco(cheio: etapa.rawValue < atual.rawValue, visivel: etapa != .concluido)
                    }
                    rotulo(etapa)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityValue(Text(verbatim: valorFalado(etapa)))
            }
        }
    }

    private var emColuna: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(EtapaDoTurno.allCases, id: \.self) { etapa in
                HStack(alignment: .top, spacing: FrilaEspaco.item) {
                    VStack(spacing: 0) {
                        ponto(etapa)
                        if etapa != .concluido {
                            Rectangle()
                                .fill(etapa.rawValue < atual.rawValue ? FrilaCor.texto : FrilaCor.borda)
                                .frame(width: 2, height: FrilaEspaco.bloco)
                                .accessibilityHidden(true)
                        }
                    }
                    rotulo(etapa)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityValue(Text(verbatim: valorFalado(etapa)))
            }
        }
    }

    private func traco(cheio: Bool, visivel: Bool) -> some View {
        Rectangle()
            .fill(cheio ? FrilaCor.texto : FrilaCor.borda)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .opacity(visivel ? 1 : 0)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func ponto(_ etapa: EtapaDoTurno) -> some View {
        if feitas.contains(etapa) || etapa == atual {
            Circle()
                .fill(FrilaCor.texto)
                .frame(width: marcador, height: marcador)
                .accessibilityHidden(true)
        } else {
            Circle()
                .strokeBorder(FrilaCor.bordaDoCampo, lineWidth: 2)
                .frame(width: marcador, height: marcador)
                .accessibilityHidden(true)
        }
    }

    private func rotulo(_ etapa: EtapaDoTurno) -> some View {
        Text(verbatim: etapa.rotulo)
            .font(FrilaTipo.legenda)
            .fontWeight(etapa == atual ? .semibold : .regular)
            .foregroundStyle(etapa == atual ? FrilaCor.texto : FrilaCor.textoSecundario)
            .lineLimit(tamanhoDoTexto >= .xxxLarge ? nil : 1)
            .minimumScaleFactor(0.75)
    }

    private func valorFalado(_ etapa: EtapaDoTurno) -> String {
        if etapa == atual { return TextosDoProfissional.Turnos.etapaAtual }
        return feitas.contains(etapa) ? TextosDoProfissional.Turnos.etapaFeita : TextosDoProfissional.Turnos.etapaQueFalta
    }
}

/// Bloco do detalhe do turno: o nome do grupo em rótulo de grupo (600, 15, `textoSecundario`), 16 pt acima do
/// conteúdo. Quem monta a tela põe o espaço de fora (24 entre blocos).
struct BlocoComRotuloDeGrupo<Conteudo: View>: View {
    private let rotulo: String
    private let conteudo: Conteudo

    init(_ rotulo: String, @ViewBuilder conteudo: () -> Conteudo) {
        self.rotulo = rotulo
        self.conteudo = conteudo()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            Text(verbatim: rotulo)
                .font(FrilaTipo.rotuloDeGrupo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            conteudo
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
