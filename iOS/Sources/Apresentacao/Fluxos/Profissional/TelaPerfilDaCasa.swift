import FrilaDominio
import SwiftUI

/// T3b · Perfil da casa (Lote 5).
/// Visão simplificada da casa, acessível pela T3 ou T3c ao tocar no cabeçalho da casa.
public struct TelaPerfilDaCasa: View {
    @Environment(\.dismiss) private var dismiss
    private let nomeCasa: String
    private let reputacaoPercentual: Int
    private let endereco: String
    private let distanciaTexto: String
    private let turnosFeitos: Int
    private let ultimoTurnoDataCurta: String
    private let ultimoTurnoDataCompleta: String
    private let aoVoltar: (() -> Void)?

    public init(
        nomeCasa: String = "Bar do Porto",
        reputacaoPercentual: Int = 94,
        endereco: String = "CLS 405, Bloco B, Loja 30, Asa Sul",
        distanciaTexto: String = "1,8 km",
        turnosFeitos: Int = 2,
        ultimoTurnoDataCurta: String = "Sáb 07/11",
        ultimoTurnoDataCompleta: String = "Sábado 07/11",
        aoVoltar: (() -> Void)? = nil
    ) {
        self.nomeCasa = nomeCasa
        self.reputacaoPercentual = reputacaoPercentual
        self.endereco = endereco
        self.distanciaTexto = distanciaTexto
        self.turnosFeitos = turnosFeitos
        self.ultimoTurnoDataCurta = ultimoTurnoDataCurta
        self.ultimoTurnoDataCompleta = ultimoTurnoDataCompleta
        self.aoVoltar = aoVoltar
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                cabecalhoCasa

                dadosEndereco

                historicoCasa
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.top, FrilaEspaco.medio)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if let aoVoltar {
                        aoVoltar()
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.texto)
                        .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                }
                .accessibilityLabel(Text("Voltar", bundle: bundleApresentacao))
                .accessibilityIdentifier("perfil-casa-voltar")
            }
        }
        .accessibilityIdentifier("tela-perfil-casa")
    }

    private var cabecalhoCasa: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            HStack(spacing: FrilaEspaco.pequeno) {
                Text(verbatim: nomeCasa)
                    .font(FrilaTipo.tituloGrande)
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityAddTraits(.isHeader)

                Image(systemName: "checkmark.seal.fill")
                    .font(FrilaTipo.tituloDoDetalhe)
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityLabel(Text(verbatim: TextosLote4.casaVerificada))
                    .accessibilityIdentifier("perfil-casa-verificada")
            }

            Text(verbatim: TextosLote4.percentualTrabalhariamDeNovo(reputacaoPercentual))
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
        }
    }

    private var dadosEndereco: some View {
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
    }

    private var historicoCasa: some View {
        let textoAcessivel = TextosLote4.historicoTurnosCasa(quantidade: turnosFeitos, ultimo: ultimoTurnoDataCompleta)
        return Text(verbatim: TextosLote4.historicoTurnosCasa(quantidade: turnosFeitos, ultimo: ultimoTurnoDataCurta))
            .font(FrilaTipo.meta)
            .foregroundStyle(FrilaCor.textoSecundario)
            .accessibilityLabel(Text(verbatim: textoAcessivel))
            .accessibilityIdentifier("perfil-casa-historico")
    }
}
