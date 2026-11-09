import FrilaDominio
import SwiftUI

/// Espaço reservado para ilustração no traço doodle (342×112, proporção 171/56),
/// decorativo, com borda tracejada em `borda` sobre superfície branca.
public struct DoodleEspacoReservado: View {
    public init() {}

    public var body: some View {
        RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous)
            .fill(FrilaCor.superficie)
            .aspectRatio(171.0 / 56.0, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous)
                    .strokeBorder(FrilaCor.borda, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            )
            .accessibilityHidden(true)
    }
}

/// Etapas canônicas do turno (Confirmado, A caminho, Presença, Concluído).
public enum EtapaDoTurno: Int, CaseIterable, Sendable {
    case confirmado = 0
    case aCaminho = 1
    case presenca = 2
    case concluido = 3

    public var rotulo: String {
        switch self {
        case .confirmado: return String(localized: "Confirmado", bundle: bundleApresentacao)
        case .aCaminho: return String(localized: "A caminho", bundle: bundleApresentacao)
        case .presenca: return String(localized: "Presença", bundle: bundleApresentacao)
        case .concluido: return String(localized: "Concluído", bundle: bundleApresentacao)
        }
    }
}

/// Linha de etapas do turno (DESIGN.md, Linha de etapas): quatro etapas em marcadores
/// de 12 pt ligados por traço de 2 pt, com rótulos de 13 pt. Feitas e atual em tinta;
/// futuras em borda-controle. A atual em tinta com peso 600.
public struct LinhaDeEtapas: View {
    public let etapaAtual: EtapaDoTurno

    public init(etapaAtual: EtapaDoTurno = .concluido) {
        self.etapaAtual = etapaAtual
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(EtapaDoTurno.allCases, id: \.self) { etapa in
                VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                    HStack(spacing: 0) {
                        Circle()
                            .fill(etapa.rawValue <= etapaAtual.rawValue ? FrilaCor.primaria : FrilaCor.superficie)
                            .overlay(
                                Circle().strokeBorder(
                                    etapa.rawValue <= etapaAtual.rawValue ? FrilaCor.primaria : FrilaCor.bordaDoCampo,
                                    lineWidth: 2
                                )
                            )
                            .frame(width: 12, height: 12)

                        if etapa != .concluido {
                            Rectangle()
                                .fill(etapa.rawValue < etapaAtual.rawValue ? FrilaCor.primaria : FrilaCor.borda)
                                .frame(height: 2)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    Text(verbatim: etapa.rotulo)
                        .font(FrilaTipo.nota.weight(etapa == etapaAtual ? .semibold : .regular))
                        .foregroundStyle(etapa == etapaAtual ? FrilaCor.texto : FrilaCor.textoSecundario)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .frame(maxWidth: etapa == .concluido ? nil : .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: etapaAtual.rotulo))
    }
}

/// Card de status do turno do protótipo (DESIGN.md#componentes): selo, nome da casa,
/// data e horário, divisória, linha de etapas, divisória e valor faturado em destaque.
public struct CardStatusTurno: View {
    public let selo: String
    public let estiloDoSelo: SeloDeStatus.Estilo
    public let nomeDaCasa: String
    public let dataTexto: String
    public let horarioTexto: String
    public let etapaAtual: EtapaDoTurno
    public let valorFormatado: String

    public init(
        selo: String? = nil,
        estiloDoSelo: SeloDeStatus.Estilo = .contorno,
        nomeDaCasa: String,
        dataTexto: String,
        horarioTexto: String,
        etapaAtual: EtapaDoTurno = .concluido,
        valorFormatado: String
    ) {
        self.selo = selo ?? String(localized: "Concluído", bundle: bundleApresentacao)
        self.estiloDoSelo = estiloDoSelo
        self.nomeDaCasa = nomeDaCasa
        self.dataTexto = dataTexto
        self.horarioTexto = horarioTexto
        self.etapaAtual = etapaAtual
        self.valorFormatado = valorFormatado
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            SeloDeStatus(verbatim: selo, estilo: estiloDoSelo)

            Text(verbatim: nomeDaCasa)
                .font(FrilaTipo.resumo)
                .foregroundStyle(FrilaCor.texto)
                .padding(.top, FrilaEspaco.minimo)

            HStack(spacing: FrilaEspaco.compacto) {
                Text(verbatim: dataTexto)
                    .font(FrilaTipo.rotuloSecundario)
                    .foregroundStyle(FrilaCor.texto)
                Text(verbatim: horarioTexto)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
            }
            .padding(.top, 2)

            Rectangle()
                .fill(FrilaCor.borda)
                .frame(height: 1)
                .padding(.vertical, FrilaEspaco.medio)

            LinhaDeEtapas(etapaAtual: etapaAtual)

            Rectangle()
                .fill(FrilaCor.borda)
                .frame(height: 1)
                .padding(.vertical, FrilaEspaco.medio)

            HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.minimo) {
                Text(verbatim: valorFormatado)
                    .font(FrilaTipo.valorEmDestaque)
                    .foregroundStyle(FrilaCor.texto)
                Text("faturados", bundle: bundleApresentacao)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
        }
        .padding(FrilaEspaco.medio)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous).strokeBorder(FrilaCor.borda, lineWidth: 1))
    }
}
