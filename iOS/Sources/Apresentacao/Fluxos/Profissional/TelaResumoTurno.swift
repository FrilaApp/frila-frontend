import FrilaDominio
import SwiftUI

/// T7b · Resumo do turno (#105, Lote 5).
/// Detalhe de um turno concluído acessado a partir do Histórico da T7.
public struct TelaResumoTurno: View {
    @Environment(\.dismiss) private var dismiss
    private let dataCurta: String
    private let dataCompleta: String
    private let nomeCasa: String
    private let horarioTexto: String
    private let valorFaturado: String
    private let funcao: String
    private let aoPedirSuporte: (() -> Void)?
    private let aoDenunciar: (() -> Void)?

    @State private var abrindoSuporte: Bool = false
    @State private var assuntoSuporte: String?

    public init(
        dataCurta: String = "Sáb 07/11",
        dataCompleta: String = "Sábado 07/11",
        nomeCasa: String = "Bar do Porto",
        horarioTexto: String = "18:00 às 00:00",
        valorFaturado: String = "R$ 220,00",
        funcao: String = "Bartender",
        aoPedirSuporte: (() -> Void)? = nil,
        aoDenunciar: (() -> Void)? = nil
    ) {
        self.dataCurta = dataCurta
        self.dataCompleta = dataCompleta
        self.nomeCasa = nomeCasa
        self.horarioTexto = horarioTexto
        self.valorFaturado = valorFaturado
        self.funcao = funcao
        self.aoPedirSuporte = aoPedirSuporte
        self.aoDenunciar = aoDenunciar
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                tituloView

                cardStatusConcluido

                linhaFuncao

                acoesDiscretas
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.top, FrilaEspaco.pequeno)
            .padding(.bottom, FrilaEspaco.enorme)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.texto)
                        .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                }
                .accessibilityLabel(Text("Voltar", bundle: bundleApresentacao))
                .accessibilityIdentifier("resumo-turno-voltar")
            }
        }
        .navigationDestination(isPresented: $abrindoSuporte) {
            TelaChatSuporte(
                seloTurno: TextosLote4.concluido,
                nomeCasa: nomeCasa,
                quandoTexto: dataCurta,
                horarioTexto: horarioTexto,
                assunto: assuntoSuporte
            )
        }
        .accessibilityIdentifier("tela-resumo-turno")
    }

    private var tituloView: some View {
        Text(verbatim: TextosLote4.seuTurnoFoi(dataCurta))
            .font(FrilaTipo.tituloGrande)
            .foregroundStyle(FrilaCor.texto)
            .accessibilityLabel(Text(verbatim: TextosLote4.seuTurnoFoi(dataCompleta)))
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("resumo-turno-titulo")
    }

    private var cardStatusConcluido: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
            Text(verbatim: TextosLote4.concluido)
                .font(FrilaTipo.chip)
                .foregroundStyle(FrilaCor.texto)
                .padding(.horizontal, FrilaEspaco.compacto)
                .padding(.vertical, FrilaEspaco.minimo)
                .background(Capsule().strokeBorder(FrilaCor.borda, lineWidth: 1))

            Text(verbatim: nomeCasa)
                .font(FrilaTipo.secao)
                .foregroundStyle(FrilaCor.texto)

            HStack(spacing: FrilaEspaco.compacto) {
                Text(verbatim: dataCurta)
                    .font(FrilaTipo.corpo.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityLabel(Text(verbatim: dataCompleta))

                Text(verbatim: horarioTexto)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }

            Rectangle()
                .fill(FrilaCor.divisoria)
                .frame(height: 1)

            linhaDeEtapas

            Rectangle()
                .fill(FrilaCor.divisoria)
                .frame(height: 1)

            HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.pequeno) {
                Text(verbatim: valorFaturado)
                    .font(FrilaTipo.tituloGrande)
                    .foregroundStyle(FrilaCor.texto)

                Text(verbatim: TextosLote4.faturados)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
        }
        .padding(FrilaEspaco.medio)
        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous)
                .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
        )
    }

    private var linhaDeEtapas: some View {
        let etapas = [
            TextosLote4.etapaConfirmado,
            TextosLote4.etapaACaminho,
            TextosLote4.etapaPresenca,
            TextosLote4.etapaConcluido
        ]

        return HStack(spacing: 0) {
            ForEach(Array(etapas.enumerated()), id: \.offset) { indice, etapa in
                HStack(spacing: FrilaEspaco.minimo) {
                    Circle()
                        .fill(FrilaCor.texto)
                        .frame(width: 8, height: 8)

                    Text(verbatim: etapa)
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.texto)
                }

                if indice < etapas.count - 1 {
                    Spacer(minLength: 4)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: TextosLote4.etapasDoTurno))
        .accessibilityIdentifier("resumo-turno-etapas")
    }

    private var linhaFuncao: some View {
        HStack(spacing: FrilaEspaco.compacto) {
            Image(systemName: "briefcase")
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            Text(verbatim: funcao)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
        }
    }

    private var acoesDiscretas: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
            Button {
                if let aoPedirSuporte {
                    aoPedirSuporte()
                } else {
                    assuntoSuporte = nil
                    abrindoSuporte = true
                }
            } label: {
                Text(verbatim: TextosLote4.pedirSuporte)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("resumo-turno-pedir-suporte")

            Button {
                if let aoDenunciar {
                    aoDenunciar()
                } else {
                    assuntoSuporte = TextosLote4.assuntoDenuncia
                    abrindoSuporte = true
                }
            } label: {
                Text(verbatim: TextosLote4.denunciarProblema)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("resumo-turno-denunciar")
        }
    }
}
