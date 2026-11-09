import FrilaDominio
import SwiftUI

/// T3c · Vaga com candidatura (Lote 5).
/// Mostra a vaga à qual o profissional se candidatou, no estado "Aguardando a casa",
/// com a desistência sem penalidade a um toque.
public struct TelaVagaComCandidatura: View {
    @Environment(\.dismiss) private var dismiss
    private let nomeCasa: String
    private let reputacaoPercentual: Int
    private let funcao: String
    private let dataPorExtenso: String
    private let horarioTexto: String
    private let duracaoHoras: Int
    private let endereco: String
    private let distanciaTexto: String
    private let traje: String
    private let valorFormatado: String
    private let aoDesistir: (() -> Void)?
    private let aoAbrirPerfilCasa: (() -> Void)?

    @State private var abrindoPerfilCasa: Bool = false

    public init(
        nomeCasa: String = "BAR DO PORTO",
        reputacaoPercentual: Int = 94,
        funcao: String = "Bartender",
        dataPorExtenso: String = "Sábado, 21 de novembro de 2026",
        horarioInicio: String = "18:00",
        horarioFim: String = "00:00",
        duracaoHoras: Int = 6,
        endereco: String = "CLS 405, Bloco B, Loja 30, Asa Sul",
        distanciaTexto: String = "1,8 km",
        traje: String = "camisa preta e calça escura",
        valorFormatado: String = "R$ 220,00",
        aoDesistir: (() -> Void)? = nil,
        aoAbrirPerfilCasa: (() -> Void)? = nil
    ) {
        self.nomeCasa = nomeCasa
        self.reputacaoPercentual = reputacaoPercentual
        self.funcao = funcao
        self.dataPorExtenso = dataPorExtenso
        self.horarioTexto = TextosLote4.horarioEDuracao(inicio: horarioInicio, fim: horarioFim, duracaoHoras: duracaoHoras)
        self.duracaoHoras = duracaoHoras
        self.endereco = endereco
        self.distanciaTexto = distanciaTexto
        self.traje = traje
        self.valorFormatado = valorFormatado
        self.aoDesistir = aoDesistir
        self.aoAbrirPerfilCasa = aoAbrirPerfilCasa
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                cabecalhoCasaBotao

                faixaModoAguardando

                cartaoDetalhes

                botaoDesistir
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
                .accessibilityIdentifier("vaga-candidatura-voltar")
            }
        }
        .navigationDestination(isPresented: $abrindoPerfilCasa) {
            TelaPerfilDaCasa(
                nomeCasa: "Bar do Porto",
                reputacaoPercentual: reputacaoPercentual,
                endereco: endereco,
                distanciaTexto: distanciaTexto
            )
        }
        .accessibilityIdentifier("tela-vaga-candidatura")
    }

    private var cabecalhoCasaBotao: some View {
        Button {
            if let aoAbrirPerfilCasa {
                aoAbrirPerfilCasa()
            } else {
                abrindoPerfilCasa = true
            }
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                    HStack(spacing: FrilaEspaco.pequeno) {
                        Text(verbatim: nomeCasa)
                            .font(FrilaTipo.tituloGrande)
                            .foregroundStyle(FrilaCor.texto)

                        Image(systemName: "checkmark.seal.fill")
                            .font(FrilaTipo.tituloDoDetalhe)
                            .foregroundStyle(FrilaCor.texto)
                            .accessibilityLabel(Text(verbatim: TextosLote4.casaVerificada))

                        Image(systemName: "chevron.right")
                            .font(FrilaTipo.corpo)
                            .foregroundStyle(FrilaCor.textoSecundario)
                    }

                    Text(verbatim: TextosLote4.percentualTrabalhariamDeNovo(reputacaoPercentual))
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("vaga-candidatura-casa")
    }

    private var faixaModoAguardando: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosLote4.aguardandoCasa)
                .font(FrilaTipo.chip)
                .foregroundStyle(FrilaCor.texto)
                .padding(.horizontal, FrilaEspaco.compacto)
                .padding(.vertical, FrilaEspaco.minimo)
                .background(
                    Capsule().strokeBorder(FrilaCor.borda, lineWidth: 1)
                )

            Text(verbatim: TextosLote4.voceSeCandidatou)
                .font(FrilaTipo.secao)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)

            Text(verbatim: TextosLote4.apoioCandidatura)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, FrilaEspaco.pequeno)
    }

    private var cartaoDetalhes: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.faixa) {
            // Função
            HStack(spacing: FrilaEspaco.compacto) {
                Image(systemName: "briefcase")
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                Text(verbatim: funcao)
                    .font(FrilaTipo.corpo.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
            }

            // Data e Horário
            HStack(alignment: .top, spacing: FrilaEspaco.compacto) {
                Image(systemName: "calendar")
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                    Text(verbatim: dataPorExtenso)
                        .font(FrilaTipo.corpo.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)

                    Text(verbatim: horarioTexto)
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
            }

            // Mapa e Endereço
            miniaturaMapaView

            HStack(alignment: .top, spacing: FrilaEspaco.compacto) {
                Image(systemName: "mappin")
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                    Text(verbatim: endereco)
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.texto)

                    Text(verbatim: TextosLote4.distanciaPontoBase(distanciaTexto))
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
            }

            // Traje
            HStack(spacing: FrilaEspaco.compacto) {
                Image(systemName: "tshirt")
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                Text(verbatim: TextosLote4.trajeFormatado(traje))
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.texto)
            }

            Rectangle()
                .fill(FrilaCor.divisoria)
                .frame(height: 1)

            // Valores e inclusões
            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: valorFormatado)
                    .font(FrilaTipo.tituloGrande)
                    .foregroundStyle(FrilaCor.texto)

                Text(verbatim: TextosLote4.gorjetaDistribuida)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)

                Text(verbatim: TextosLote4.inclusoJantarTransporte)
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

    private var miniaturaMapaView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                .fill(FrilaCor.controle)
                .frame(height: 96)

            // Desenho ilustrativo de ruas e pinos
            Path { path in
                path.move(to: CGPoint(x: 0, y: 30))
                path.addLine(to: CGPoint(x: 320, y: 30))
                path.move(to: CGPoint(x: 0, y: 65))
                path.addLine(to: CGPoint(x: 320, y: 65))
                path.move(to: CGPoint(x: 80, y: 0))
                path.addLine(to: CGPoint(x: 80, y: 96))
                path.move(to: CGPoint(x: 230, y: 0))
                path.addLine(to: CGPoint(x: 230, y: 96))
            }
            .stroke(FrilaCor.borda, lineWidth: 2)

            // Ponto base
            Circle()
                .fill(FrilaCor.texto)
                .frame(width: 14, height: 14)
                .position(x: 80, y: 48)

            // Pino da casa
            Image(systemName: "mappin.circle.fill")
                .font(FrilaTipo.tituloDoDetalhe)
                .foregroundStyle(FrilaCor.marca)
                .position(x: 230, y: 44)
        }
        .frame(height: 96)
        .clipShape(RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
        .accessibilityHidden(true)
    }

    private var botaoDesistir: some View {
        Button {
            aoDesistir?()
            dismiss()
        } label: {
            Text(verbatim: TextosLote4.desistirSemPenalidade)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("vaga-candidatura-desistir")
    }
}
