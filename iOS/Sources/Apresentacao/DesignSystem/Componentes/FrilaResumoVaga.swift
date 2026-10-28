import Foundation
import SwiftUI

/// Título de navegação contextual para a tela Detalhe da vaga (LOG-010).
/// Exibe a função e o estabelecimento separados por ponto médio em fonte de marca (Bricolage),
/// alinhado à esquerda. O comportamento ao rolar a tela será integrado no LOG-011.
public struct FrilaTituloNavegacaoVaga: View {
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    public let funcao: String
    public let estabelecimento: String
    public let visivel: Bool

    public init(funcao: String, estabelecimento: String, visivel: Bool) {
        self.funcao = funcao
        self.estabelecimento = estabelecimento
        self.visivel = visivel
    }

    public var body: some View {
        let titulo = "\(funcao) · \(estabelecimento)"
        HStack(spacing: 0) {
            Text(verbatim: titulo)
                .font(FrilaTypography.bricolage(size: 17, weight: .bold))
                .foregroundStyle(FrilaCor.texto)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(visivel ? 1 : 0)
        .animation(FrilaMovimento.animacao(.easeInOut(duration: 0.2), reduzir: reduzirMovimento), value: visivel)
        .accessibilityHidden(!visivel)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Prévia geométrica SwiftUI neutra e genérica que remete a mapa/região,
/// sem coordenadas falsas, sem snapshot MapKit e sem sugerir precisão geográfica (LOG-010).
private struct PreviaMapaGenerica: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: FrilaRaio.pequeno, style: .continuous)
                .fill(FrilaCor.controle)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.72))
                    path.addLine(to: CGPoint(x: w, y: h * 0.24))

                    path.move(to: CGPoint(x: w * 0.22, y: 0))
                    path.addLine(to: CGPoint(x: w * 0.52, y: h))

                    path.move(to: CGPoint(x: w * 0.54, y: 0))
                    path.addLine(to: CGPoint(x: w * 0.84, y: h))

                    path.move(to: CGPoint(x: 0, y: h * 0.44))
                    path.addLine(to: CGPoint(x: w, y: h * 0.52))
                }
                .stroke(FrilaCor.divisoria, lineWidth: 2)

                let ponto = CGPoint(x: w * 0.48, y: h * 0.42)
                Circle()
                    .fill(FrilaCor.marca.opacity(0.18))
                    .frame(width: 20, height: 20)
                    .position(ponto)

                Circle()
                    .fill(FrilaCor.marca)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(FrilaCor.fundo, lineWidth: 1.5))
                    .position(ponto)
            }
        }
        .frame(height: 72)
        .overlay(
            RoundedRectangle(cornerRadius: FrilaRaio.pequeno, style: .continuous)
                .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FrilaRaio.pequeno, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// Card consolidado com dados da vaga, lotação, contagem do turno e localização integrada (LOG-010).
/// Aplica zero-shadow, tokens semânticos do Frila e botão de mapa com alvo interativo mínimo de 44 pt.
public struct FrilaResumoVaga: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public let quando: String
    public let horario: String
    public let valor: String
    public let valorAcessibilidade: String
    public let local: String
    public let distancia: String?
    public let preenchidas: Int
    public let total: Int
    public let inicio: Date?
    public let fim: Date?
    public let abrirMapa: () -> Void

    public init(
        quando: String,
        horario: String,
        valor: String,
        valorAcessibilidade: String,
        local: String,
        distancia: String?,
        preenchidas: Int,
        total: Int,
        inicio: Date?,
        fim: Date?,
        abrirMapa: @escaping () -> Void
    ) {
        self.quando = quando
        self.horario = horario
        self.valor = valor
        self.valorAcessibilidade = valorAcessibilidade
        self.local = local
        self.distancia = distancia
        self.preenchidas = preenchidas
        self.total = total
        self.inicio = inicio
        self.fim = fim
        self.abrirMapa = abrirMapa
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                    blocoQuando
                    blocoHorario
                    blocoValor
                    blocoPosicoes
                }
            } else {
                Grid(alignment: .leading, horizontalSpacing: FrilaEspaco.medio, verticalSpacing: FrilaEspaco.medio) {
                    GridRow {
                        blocoQuando
                        blocoHorario
                    }
                    GridRow {
                        blocoValor
                        blocoPosicoes
                    }
                }
            }

            Rectangle()
                .fill(FrilaCor.divisoria)
                .frame(height: 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
                VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                    HStack(alignment: .top, spacing: FrilaEspaco.pequeno) {
                        Image(systemName: "mappin")
                            .font(FrilaTipo.corpo)
                            .foregroundStyle(FrilaCor.marca)
                            .frame(width: 16, height: 16)
                            .accessibilityHidden(true)
                        Text(verbatim: local)
                            .font(FrilaTipo.resumo)
                            .foregroundStyle(FrilaCor.texto)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let distancia, !distancia.isEmpty {
                        Text(verbatim: distancia)
                            .font(FrilaTipo.nota)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .padding(.leading, 24)
                    }
                }
                .accessibilityElement(children: .combine)

                PreviaMapaGenerica()

                Button(action: abrirMapa) {
                    HStack(spacing: FrilaEspaco.pequeno) {
                        Image(systemName: "map")
                            .font(FrilaTipo.nota)
                            .accessibilityHidden(true)
                        Text("Abrir no mapa", bundle: bundleApresentacao)
                            .font(FrilaTipo.botaoPadrao)
                    }
                    .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                    .foregroundStyle(FrilaCor.texto)
                    .background(FrilaCor.fundo, in: Capsule())
                    .overlay(Capsule().strokeBorder(FrilaCor.borda, lineWidth: 1))
                    .contentShape(Capsule())
                }
                .buttonStyle(.tatil)
                .accessibilityIdentifier("abrir-no-mapa")
            }
        }
        .padding(FrilaEspaco.medio)
        .background(FrilaCor.fundo, in: RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous)
                .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
        )
    }

    private var blocoQuando: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
            Text("Quando", bundle: bundleApresentacao)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
            Text(verbatim: quando)
                .font(FrilaTipo.resumo)
                .foregroundStyle(FrilaCor.texto)
        }
        .accessibilityElement(children: .combine)
    }

    private var blocoHorario: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
            Text("Horário", bundle: bundleApresentacao)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
            Text(verbatim: horario)
                .font(FrilaTipo.resumo)
                .foregroundStyle(FrilaCor.texto)
            FrilaContagemTurno(inicio: inicio, fim: fim)
        }
        .accessibilityElement(children: .combine)
    }

    private var blocoValor: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
            Text("Valor", bundle: bundleApresentacao)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
            Text(verbatim: valor)
                .font(FrilaTipo.resumo)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityLabel(Text(verbatim: valorAcessibilidade))
        }
        .accessibilityElement(children: .combine)
    }

    private var blocoPosicoes: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
            Text("Posições", bundle: bundleApresentacao)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
            FrilaLotacao(preenchidas: preenchidas, total: total)
        }
        .accessibilityElement(children: .combine)
    }
}
