import FrilaDominio
import SwiftUI

/// Etapas do turno conforme a especificação do protótipo e DESIGN.md (T4, T8, T5, T7b).
public enum EtapaDoTurno: Int, CaseIterable, Sendable {
    case confirmado = 0
    case aCaminho = 1
    case presenca = 2
    case concluido = 3

    public var rotuloChave: LocalizedStringKey {
        switch self {
        case .confirmado: "Confirmado"
        case .aCaminho: "A caminho"
        case .presenca: "Presença"
        case .concluido: "Concluído"
        }
    }

    public var rotuloTexto: String {
        switch self {
        case .confirmado: String(localized: "Confirmado", bundle: bundleApresentacao)
        case .aCaminho: String(localized: "A caminho", bundle: bundleApresentacao)
        case .presenca: String(localized: "Presença", bundle: bundleApresentacao)
        case .concluido: String(localized: "Concluído", bundle: bundleApresentacao)
        }
    }
}

/// Linha de etapas do turno (T4, T8, T5, T7b): as quatro etapas do turno com marcadores de 12 px,
/// traço conector de 2 px e rótulos de 13 px. Em Dynamic Type acessível, vira vertical (ViewThatFits).
public struct LinhaDeEtapasDoTurno: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    public let etapaAtual: EtapaDoTurno
    public let etapasFeitas: Set<EtapaDoTurno>

    public init(etapaAtual: EtapaDoTurno, etapasFeitas: Set<EtapaDoTurno>? = nil) {
        self.etapaAtual = etapaAtual
        if let etapasFeitas {
            self.etapasFeitas = etapasFeitas
        } else {
            var feitas = Set<EtapaDoTurno>()
            for e in EtapaDoTurno.allCases where e.rawValue < etapaAtual.rawValue {
                feitas.insert(e)
            }
            self.etapasFeitas = feitas
        }
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontal
            vertical
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(String(localized: "Etapas do turno", bundle: bundleApresentacao)): \(descricaoAcessibilidade)"))
    }

    private var descricaoAcessibilidade: String {
        EtapaDoTurno.allCases.map { etapa in
            if etapa == etapaAtual {
                return "\(etapa.rotuloTexto) (\(String(localized: "Etapa atual: %@", bundle: bundleApresentacao)))"
            } else if etapasFeitas.contains(etapa) {
                return "\(etapa.rotuloTexto)"
            } else {
                return etapa.rotuloTexto
            }
        }.joined(separator: ", ")
    }

    private var horizontal: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(EtapaDoTurno.allCases, id: \.rawValue) { etapa in
                let ehAtual = etapa == etapaAtual
                let ehFeita = etapasFeitas.contains(etapa)
                let ehUltima = etapa == EtapaDoTurno.concluido

                VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                    HStack(spacing: 0) {
                        marcador(ehFeita: ehFeita, ehAtual: ehAtual)
                        if !ehUltima {
                            traco(ehFeita: ehFeita)
                        }
                    }
                    Text(etapa.rotuloChave, bundle: bundleApresentacao)
                        .font(ehAtual ? FrilaTipo.meta.weight(.semibold) : FrilaTipo.nota)
                        .foregroundStyle(ehAtual ? FrilaCor.texto : FrilaCor.textoSecundario)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                if !ehUltima {
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var vertical: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            ForEach(EtapaDoTurno.allCases, id: \.rawValue) { etapa in
                let ehAtual = etapa == etapaAtual
                let ehFeita = etapasFeitas.contains(etapa)

                HStack(spacing: FrilaEspaco.compacto) {
                    marcador(ehFeita: ehFeita, ehAtual: ehAtual)
                    Text(etapa.rotuloChave, bundle: bundleApresentacao)
                        .font(ehAtual ? FrilaTipo.meta.weight(.semibold) : FrilaTipo.nota)
                        .foregroundStyle(ehAtual ? FrilaCor.texto : FrilaCor.textoSecundario)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func marcador(ehFeita: Bool, ehAtual: Bool) -> some View {
        ZStack {
            if ehFeita || ehAtual {
                Circle()
                    .fill(FrilaCor.primaria)
                    .frame(width: 12, height: 12)
            } else {
                Circle()
                    .strokeBorder(FrilaCor.borda, lineWidth: 2)
                    .background(Circle().fill(FrilaCor.superficie))
                    .frame(width: 12, height: 12)
            }
        }
        .frame(width: 12, height: 12)
    }

    private func traco(ehFeita: Bool) -> some View {
        Rectangle()
            .fill(ehFeita ? FrilaCor.primaria : FrilaCor.borda)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, FrilaEspaco.fio)
    }
}

/// Card de status do turno da pele nova (T4, T8, T5, T7b): selo de status, casa, horário,
/// divisória e linha de etapas.
public struct CardDeStatusDoTurno: View {
    public let seloTexto: LocalizedStringKey
    public let seloEstilo: SeloDeStatus.Estilo
    public let seloIcone: String?
    public let casaNome: String
    public let apoioTexto: String?
    public let dataTexto: String
    public let horarioTexto: String
    public let etapaAtual: EtapaDoTurno
    public let etapasFeitas: Set<EtapaDoTurno>?

    public init(
        seloTexto: LocalizedStringKey,
        seloEstilo: SeloDeStatus.Estilo,
        seloIcone: String? = nil,
        casaNome: String,
        apoioTexto: String? = nil,
        dataTexto: String,
        horarioTexto: String,
        etapaAtual: EtapaDoTurno,
        etapasFeitas: Set<EtapaDoTurno>? = nil
    ) {
        self.seloTexto = seloTexto
        self.seloEstilo = seloEstilo
        self.seloIcone = seloIcone
        self.casaNome = casaNome
        self.apoioTexto = apoioTexto
        self.dataTexto = dataTexto
        self.horarioTexto = horarioTexto
        self.etapaAtual = etapaAtual
        self.etapasFeitas = etapasFeitas
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
            SeloDeStatus(seloTexto, estilo: seloEstilo, icone: seloIcone)

            Text(verbatim: casaNome)
                .font(FrilaTipo.tituloDoCartao)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)

            if let apoioTexto {
                Text(verbatim: apoioTexto)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: FrilaEspaco.minimo) {
                Text(verbatim: dataTexto)
                    .font(FrilaTipo.meta.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                Text(verbatim: horarioTexto)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.texto)
            }

            Rectangle()
                .fill(FrilaCor.borda)
                .frame(height: 1)
                .accessibilityHidden(true)

            LinhaDeEtapasDoTurno(etapaAtual: etapaAtual, etapasFeitas: etapasFeitas)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .contain)
    }
}

/// Miniatura do mapa esquemático da T4 e T8: traçado simples de ruas com ponto base e pino de destino.
public struct MiniaturaMapaVisual: View {
    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            Canvas { context, size in
                var ruas = Path()
                ruas.move(to: CGPoint(x: -10, y: size.height * 0.25))
                ruas.addLine(to: CGPoint(x: size.width + 10, y: size.height * 0.25))

                ruas.move(to: CGPoint(x: -10, y: size.height * 0.75))
                ruas.addLine(to: CGPoint(x: size.width + 10, y: size.height * 0.75))

                ruas.move(to: CGPoint(x: size.width * 0.22, y: -10))
                ruas.addLine(to: CGPoint(x: size.width * 0.22, y: size.height + 10))

                ruas.move(to: CGPoint(x: size.width * 0.78, y: -10))
                ruas.addLine(to: CGPoint(x: size.width * 0.78, y: size.height + 10))

                ruas.move(to: CGPoint(x: size.width * 0.42, y: -10))
                ruas.addLine(to: CGPoint(x: size.width * 0.58, y: size.height + 10))

                context.stroke(ruas, with: .color(FrilaCor.borda), lineWidth: 8)

                let basePt = CGPoint(x: size.width * 0.25, y: size.height * 0.5)
                let baseCirculo = Path(ellipseIn: CGRect(x: basePt.x - 7, y: basePt.y - 7, width: 14, height: 14))
                context.fill(baseCirculo, with: .color(FrilaCor.fundo))
                context.stroke(baseCirculo, with: .color(FrilaCor.primaria), lineWidth: 2)

                let destPt = CGPoint(x: size.width * 0.75, y: size.height * 0.38)
                let pinoCirculo = Path(ellipseIn: CGRect(x: destPt.x - 6, y: destPt.y - 6, width: 12, height: 12))
                context.fill(pinoCirculo, with: .color(FrilaCor.primaria))
            }
            .clipShape(RoundedRectangle(cornerRadius: FrilaGeometria.raioInterno, style: .continuous))
        }
        .frame(height: 96)
        .background(FrilaCor.fundo, in: RoundedRectangle(cornerRadius: FrilaGeometria.raioInterno, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// Seção "Como chegar" da T4 e T8.
public struct SecaoComoChegar: View {
    public let endereco: String
    public let distanciaTexto: String?
    public let urlMapas: URL?

    public init(endereco: String, distanciaTexto: String? = nil, urlMapas: URL? = nil) {
        self.endereco = endereco
        self.distanciaTexto = distanciaTexto
        self.urlMapas = urlMapas
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text("Como chegar", bundle: bundleApresentacao)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
                MiniaturaMapaVisual()

                HStack(alignment: .top, spacing: FrilaEspaco.pequeno) {
                    Image(systemName: "mappin")
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.texto)
                        .accessibilityHidden(true)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                        Text(verbatim: endereco)
                            .font(FrilaTipo.meta)
                            .foregroundStyle(FrilaCor.texto)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)

                        if let distanciaTexto {
                            HStack(spacing: FrilaEspaco.fio) {
                                Circle()
                                    .strokeBorder(FrilaCor.texto, lineWidth: 1.5)
                                    .frame(width: 10, height: 10)
                                Text(verbatim: "\(distanciaTexto) ")
                                    .font(FrilaTipo.meta)
                                    .foregroundStyle(FrilaCor.texto)
                                + Text("do seu ponto base", bundle: bundleApresentacao)
                                    .font(FrilaTipo.meta)
                                    .foregroundStyle(FrilaCor.textoSecundario)
                            }
                        }
                    }
                }

                if let urlMapas {
                    Link(destination: urlMapas) {
                        Text("Abrir no mapa", bundle: bundleApresentacao)
                            .font(FrilaTipo.rotuloSecundario)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
                            .foregroundStyle(FrilaCor.texto)
                            .background(FrilaCor.superficie, in: Capsule())
                            .overlay(Capsule().strokeBorder(FrilaCor.borda, lineWidth: 1))
                            .contentShape(Capsule())
                    }
                    .accessibilityIdentifier("botao-abrir-no-mapa")
                    .accessibilityHint(String(localized: "Abre o endereço no Apple Maps", bundle: bundleApresentacao))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartaoFrila()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

/// Seção "Orientações da casa" da T4 e T8.
public struct SecaoOrientaçõesDaCasa: View {
    public let observacoes: String?
    public let quemRecebe: String?
    public let traje: String?

    public init(observacoes: String? = nil, quemRecebe: String? = nil, traje: String? = nil) {
        self.observacoes = observacoes
        self.quemRecebe = quemRecebe
        self.traje = traje
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text("Orientações da casa", bundle: bundleApresentacao)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                linhaOrientacao(
                    icone: "door.left.hand.open",
                    texto: observacoes ?? String(localized: "Entre pela lateral do bloco.", bundle: bundleApresentacao)
                )
                linhaOrientacao(
                    icone: "person.fill",
                    texto: quemRecebe != nil
                        ? "\(String(localized: "Quem recebe você", bundle: bundleApresentacao)): \(quemRecebe!)."
                        : String(localized: "Procure o encarregado Marcos no balcão principal.", bundle: bundleApresentacao)
                )
                linhaOrientacao(
                    icone: "tshirt",
                    texto: traje ?? String(localized: "Vá de camisa preta e calça escura.", bundle: bundleApresentacao)
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartaoFrila()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private func linhaOrientacao(icone: String, texto: String) -> some View {
        HStack(alignment: .top, spacing: FrilaEspaco.pequeno) {
            Image(systemName: icone)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.texto)
                .frame(width: 20)
                .accessibilityHidden(true)
                .padding(.top, 2)
            Text(verbatim: texto)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Ações discretas no fim da rolagem (T4, T8, T7b): Cancelar turno, Sair do turno, Pedir suporte, Denunciar problema.
public struct AcoesDiscretasDoTurno: View {
    public let podeCancelar: Bool
    public let horarioComecou: Bool
    public let aoCancelar: () -> Void
    public let aoPedirSuporte: () -> Void
    public let aoDenunciar: () -> Void

    public init(
        podeCancelar: Bool,
        horarioComecou: Bool,
        aoCancelar: @escaping () -> Void,
        aoPedirSuporte: @escaping () -> Void,
        aoDenunciar: @escaping () -> Void
    ) {
        self.podeCancelar = podeCancelar
        self.horarioComecou = horarioComecou
        self.aoCancelar = aoCancelar
        self.aoPedirSuporte = aoPedirSuporte
        self.aoDenunciar = aoDenunciar
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            if podeCancelar {
                if horarioComecou {
                    Button(action: aoCancelar) {
                        Text("Sair do turno", bundle: bundleApresentacao)
                            .font(FrilaTipo.meta)
                            .underline()
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .frame(minHeight: FrilaMetrica.alvoMinimo)
                    }
                    .accessibilityIdentifier("sair-do-turno")
                } else {
                    Button(action: aoCancelar) {
                        Text("Cancelar turno", bundle: bundleApresentacao)
                            .font(FrilaTipo.meta)
                            .underline()
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .frame(minHeight: FrilaMetrica.alvoMinimo)
                    }
                    .accessibilityIdentifier("cancelar-turno")
                }
            }

            Button(action: aoPedirSuporte) {
                Text("Pedir suporte", bundle: bundleApresentacao)
                    .font(FrilaTipo.meta)
                    .underline()
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
            }
            .accessibilityIdentifier("botao-ajuda-turno")

            Button(action: aoDenunciar) {
                Text("Denunciar problema", bundle: bundleApresentacao)
                    .font(FrilaTipo.meta)
                    .underline()
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
            }
            .accessibilityIdentifier("denunciar-problema")
        }
        .padding(.top, FrilaEspaco.grande)
    }
}

/// Geometria e raios locais da pele nova para views do Lote 2.
public enum FrilaGeometria {
    public static let raioInterno: CGFloat = 20
}
